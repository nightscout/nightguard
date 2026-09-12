//
//  StatsView.swift
//  nightguard
//
//  SwiftUI version of StatsViewController
//

import SwiftUI
import SpriteKit

struct StatsView: View {
    @State private var daysToDisplay: [Bool] = UserDefaultsRepository.daysToBeDisplayed.value
    @State private var chartScene: ChartScene?
    @State private var chartSize: CGSize = .zero
    @State private var loadingTracker = StatisticsDayLoadingTracker()
    @State private var dayErrors: [Int: String] = [:]

    // The combined five-day statistics request may wake a remote Nightscout
    // instance from sleep and may need several pages for one-minute data.
    // Keep this aligned with the V3 client's normal read timeout.
    private static let statisticsReadTimeout: TimeInterval = 20

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Day selection toggles
                HStack(spacing: 20) {
                    ForEach(0..<5) { index in
                        Toggle("D\(index + 1)", isOn: Binding(
                            get: { daysToDisplay[index] },
                            set: { newValue in
                                daysToDisplay[index] = newValue
                                UserDefaultsRepository.daysToBeDisplayed.value = daysToDisplay
                                if newValue {
                                    loadingTracker.allowRetry(index)
                                }
                                loadAndPaintChart()
                            }
                        ))
                        .toggleStyle(.button)
                        .tint(daysToDisplay[index] ? Color.nightguardAccent : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))

                ZStack {
                    // Chart view
                    if let scene = chartScene {
                        SpriteKitChartView(scene: scene, size: $chartSize)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Color.black
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if let failure = dayErrors.sorted(by: { $0.key < $1.key }).first {
                        VStack(spacing: 12) {
                            Text("Statistics unavailable")
                                .font(.headline)
                            Text("D\(failure.key + 1): \(failure.value)")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                retryFailedDays()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                    } else if !loadingTracker.loadingDays.isEmpty {
                        ProgressView("Loading statistics…")
                            .padding()
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .background(Color.black)
            .onAppear {
                loadingTracker.allowRetryForFailedDays()
                let size = CGSize(width: geometry.size.width, height: geometry.size.height - 50)
                setupChart(size: size)
                chartSize = size
                daysToDisplay = UserDefaultsRepository.daysToBeDisplayed.value
            }
            .onChange(of: geometry.size) { newSize in
                let size = CGSize(width: newSize.width, height: newSize.height - 50)
                setupChart(size: size)
                chartSize = size
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: false)
    }

    private func setupChart(size: CGSize) {
        let maxWidth = min(maximumDeviceTextureWidth(), size.width)
        chartScene = ChartScene(size: size, newCanvasWidth: maxWidth, useContrastfulColors: true, showYesterdaysBgs: true)
        loadAndPaintChart()
    }

    private func loadAndPaintChart() {
        guard let scene = chartScene else {
            AppLogger.singleton.error("StatsView: cannot load statistics because the chart scene is not initialized", category: .nightscout)
            return
        }

        let selectedDayIndexes = daysToDisplay.enumerated().compactMap { $0.element ? $0.offset : nil }
        let cacheLastSave = StatisticsRepository.singleton.lastSave?.description ?? "none"
        AppLogger.singleton.info(
            "StatsView: loading selected days=\(selectedDayIndexes), cacheLastSave=\(cacheLastSave), chartSize=\(chartSize.width)x\(chartSize.height)",
            category: .nightscout
        )

        var cachedDays = Array(repeating: [BloodSugar](), count: 5)
        var missingDays: [Int] = []
        for index in 0..<5 {
            if let day = StatisticsRepository.singleton.readDay(index) {
                cachedDays[index] = day
                AppLogger.singleton.debug(
                    "StatsView: day \(index) served from cache with \(day.count) value(s)",
                    category: .nightscout
                )
            } else {
                missingDays.append(index)
            }
        }

        if !missingDays.isEmpty {
            var startedDays: [Int] = []
            for index in 0..<5 where loadingTracker.beginLoading(index) {
                startedDays.append(index)
            }

            if !startedDays.isEmpty {
                AppLogger.singleton.info(
                    "StatsView: starting combined V3-only request for days=0...4 missing=\(missingDays), timeout=\(Int(Self.statisticsReadTimeout))s, baseURLConfigured=\(!UserDefaultsRepository.baseUri.value.isEmpty)",
                    category: .nightscout
                )
                NightscoutService.singleton.readStatisticsDays(
                    dayCount: 5,
                    v3Only: true,
                    timeout: Self.statisticsReadTimeout
                ) { result in
                    switch result {
                    case .data(let days):
                        for index in 0..<5 {
                            let bgValues = index < days.count ? days[index] : []
                            let normalizedBgValues = StatisticsRepository.normalizeForChart(bgValues)
                            AppLogger.singleton.info(
                                "StatsView: combined response day \(index) raw=\(bgValues.count), normalized=\(normalizedBgValues.count)",
                                category: .nightscout
                            )
                            guard normalizedBgValues.count > 1 else {
                                loadingTracker.finishLoading(index, succeeded: false)
                                if daysToDisplay[index] {
                                    dayErrors[index] = normalizedBgValues.isEmpty
                                        ? "No glucose readings were returned for this day."
                                        : "At least two glucose readings are needed to draw this chart."
                                }
                                AppLogger.singleton.error(
                                    "StatsView: day \(index) cannot be drawn because only \(normalizedBgValues.count) normalized value(s) were returned from the combined response",
                                    category: .nightscout
                                )
                                continue
                            }
                            loadingTracker.finishLoading(index, succeeded: true)
                            dayErrors.removeValue(forKey: index)
                            StatisticsRepository.singleton.saveDay(index, bloodSugarArray: normalizedBgValues)
                        }
                        loadAndPaintChart()
                    case .error(let error):
                        for index in 0..<5 {
                            loadingTracker.finishLoading(index, succeeded: false)
                            if daysToDisplay[index] {
                                dayErrors[index] = error.localizedDescription
                            }
                        }
                        AppLogger.singleton.error(
                            "StatsView: combined statistics request failed type=\(String(reflecting: type(of: error))) description=\(error.localizedDescription)",
                            category: .nightscout
                        )
                        loadAndPaintChart()
                    }
                }
            } else {
                AppLogger.singleton.debug(
                    "StatsView: combined statistics request is already running or waiting for retry; missing=\(missingDays)",
                    category: .nightscout
                )
            }
        }

        let filteredDays = cachedDays.enumerated().map { index, day in
            daysToDisplay[index] ? day : []
        }

        paintChart(scene: scene, days: filteredDays)
    }

    private func retryFailedDays() {
        loadingTracker.allowRetryForFailedDays()
        dayErrors.removeAll()
        loadAndPaintChart()
    }

    private func paintChart(scene: ChartScene, days: [[BloodSugar]]) {
        DispatchQueue.main.async {
            let maxWidth = min(maximumDeviceTextureWidth(), chartSize.width)
            scene.paintChart(
                days,
                newCanvasWidth: maxWidth,
                maxYDisplayValue: 300,
                moveToLatestValue: false,
                useContrastfulColors: true,
                showYesterdaysBgs: true
            )
        }
    }

    private func maximumDeviceTextureWidth() -> CGFloat {
        return UIScreen.main.bounds.width * UIScreen.main.scale
    }
}

// SpriteKit view wrapper
struct SpriteKitChartView: UIViewRepresentable {
    let scene: ChartScene
    @Binding var size: CGSize

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.backgroundColor = .black
        return skView
    }

    func updateUIView(_ skView: SKView, context: Context) {
        if skView.scene !== scene {
            skView.presentScene(scene)
        }
        scene.size = size
    }
}

#Preview {
    StatsView()
}
