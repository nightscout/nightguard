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
                                loadAndPaintChart()
                            }
                        ))
                        .toggleStyle(.button)
                        .tint(daysToDisplay[index] ? .blue : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))

                // Chart view
                if let scene = chartScene {
                    SpriteKitChartView(scene: scene, size: $chartSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.black
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.black)
            .onAppear {
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
        guard let scene = chartScene else { return }

        var filteredDays: [[BloodSugar]] = []

        for (index, shouldDisplay) in daysToDisplay.enumerated() {
            if shouldDisplay {
                if let day = StatisticsRepository.singleton.readDay(index) {
                    filteredDays.append(day)
                } else {
                    // Load data asynchronously
                    NightscoutService.singleton.readDay(index) { nrOfDay, bgValues in
                        let normalizedBgValues = setDayMonthYearTo01011971(bgValues)
                        StatisticsRepository.singleton.saveDay(nrOfDay, bloodSugarArray: normalizedBgValues)
                        loadAndPaintChart()
                    }
                    filteredDays.append([])
                }
            } else {
                filteredDays.append([])
            }
        }

        paintChart(scene: scene, days: filteredDays)
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

    private func setDayMonthYearTo01011971(_ bgValues: [BloodSugar]) -> [BloodSugar] {
        var normalizedBgValues: [BloodSugar] = []
        let calendar = Calendar.current

        for bgValue in bgValues {
            let time = Date(timeIntervalSince1970: bgValue.timestamp / 1000)
            var components = calendar.dateComponents([.hour, .minute, .second], from: time)
            components.setValue(1971, for: .year)

            if let normalizedTime = calendar.date(from: components) {
                let normalizedBgValue = BloodSugar(
                    value: bgValue.value,
                    timestamp: normalizedTime.timeIntervalSince1970 * 1000,
                    isMeteredBloodGlucoseValue: bgValue.isMeteredBloodGlucoseValue,
                    arrow: bgValue.arrow
                )
                normalizedBgValues.insert(normalizedBgValue, at: 0)
            }
        }

        return normalizedBgValues
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
