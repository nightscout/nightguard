//
//  MainView.swift
//  nightguard
//
//  SwiftUI conversion of MainViewController
//

import SwiftUI
import SpriteKit
import Combine

// MARK: - ChartView (SpriteKit Wrapper)

struct ChartView: UIViewRepresentable {
    let viewModel: MainViewModel
    let chartScene: ChartScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .black
        skView.isUserInteractionEnabled = true
        skView.presentScene(chartScene)

        // Add gesture recognizers once
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))

        skView.addGestureRecognizer(panGesture)
        skView.addGestureRecognizer(pinchGesture)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Re-present the scene if it detached (happens after tab switches)
        if uiView.scene == nil || chartScene.view != uiView {
            uiView.presentScene(chartScene)

            // After presenting, trigger an immediate repaint if we're visible
            DispatchQueue.main.async {
                if self.viewModel.isVisible {
                    self.viewModel.repaintChartWithCurrentData()
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(chartScene: chartScene)
    }

    class Coordinator: NSObject {
        let chartScene: ChartScene
        var oldXTranslation: CGFloat = 0

        init(chartScene: ChartScene) {
            self.chartScene = chartScene
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            if recognizer.state == .began {
                oldXTranslation = 0
                chartScene.stopSwipeAction()
            }

            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            chartScene.draggedByATouch(translation.x - oldXTranslation)
            oldXTranslation = translation.x

            if recognizer.state == .ended {
                let velocity = recognizer.velocity(in: view)
                if abs(velocity.x) > 100 {
                    chartScene.swipeChart(velocity.x)
                }
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            if recognizer.state == .ended {
                chartScene.scale(recognizer.scale, keepScale: true)
            } else {
                chartScene.scale(recognizer.scale, keepScale: false)
            }
        }
    }
}

// MARK: - SlideToSnooze Wrapper

struct SlideToSnooze: UIViewRepresentable {
    @Binding var snoozeText: String
    var onSnooze: () -> Void

    func makeUIView(context: Context) -> SlideToSnoozeView {
        let view = SlideToSnoozeView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: SlideToSnoozeView, context: Context) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 27),
            .paragraphStyle: style
        ]

        let title = NSMutableAttributedString(string: snoozeText, attributes: titleAttributes)
        uiView.setAttributedTitle(title: title)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSnooze: onSnooze)
    }

    class Coordinator: NSObject, SlideToSnoozeDelegate {
        var onSnooze: () -> Void

        init(onSnooze: @escaping () -> Void) {
            self.onSnooze = onSnooze
        }

        func slideToSnoozeDelegateDidFinish(_ sender: SlideToSnoozeView) {
            onSnooze()
        }
    }
}

// MARK: - MainView

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showNightscout = false
    @State private var showFullscreenMonitor = false
    @State private var showSnoozePopup = false
    @State private var showActionsMenuPopup = false
    @State private var chartScene: ChartScene?
    @Environment(\.selectedTab) private var selectedTab

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top section with BG data
                    VStack(spacing: 5) {
                        // Main BG value row
                        HStack(alignment: .center) {
                            // BG Value
                            Text(viewModel.bgValue)
                                .font(.system(size: 120))
                                .foregroundColor(viewModel.bgColor)
                                .minimumScaleFactor(0.5)

                            // Delta and time info
                            VStack(alignment: .leading, spacing: 0) {
                                Text(viewModel.deltaValue)
                                    .font(.system(size: 25))
                                    .foregroundColor(viewModel.deltaColor)

                                Text(viewModel.deltaArrows)
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(viewModel.deltaColor)

                                Text(viewModel.lastUpdateValue)
                                    .font(.system(size: 25))
                                    .foregroundColor(viewModel.lastUpdateColor)
                            }

                            Spacer(minLength: 10)

                            // Battery, IOB, COB, Reservoir
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(viewModel.timeValue)
                                    .font(.system(size: 19))
                                    .foregroundColor(.white)

                                HStack(spacing: 8) {
                                    Text(viewModel.cobValue)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)

                                    Text(viewModel.iobValue)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                }

                                Text(viewModel.reservoirValue)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)

                                Text(viewModel.batteryValue)
                                    .font(.system(size: 15))
                                    .foregroundColor(viewModel.batteryColor)
                            }
                        }
                        .padding(.horizontal, 8)

                        // Care data row
                        if viewModel.showCareAndLoopData {
                            HStack {
                                Text(viewModel.cannulaAgeString ?? "C --")
                                    .font(.system(size: 15))
                                    .foregroundColor(viewModel.cannulaAgeColor)
                                Spacer()
                                Text(viewModel.sensorAgeString ?? "S --")
                                    .font(.system(size: 15))
                                    .foregroundColor(viewModel.sensorAgeColor)
                                Spacer()
                                Text(viewModel.batteryAgeString ?? "B --")
                                    .font(.system(size: 15))
                                    .foregroundColor(viewModel.batteryAgeColor)
                            }
                            .padding(.horizontal, 8)

                            HStack {
                                Text(viewModel.activeProfile)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(viewModel.temporaryBasal)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(viewModel.temporaryTarget)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                        }

                        // Stats panel
                        if viewModel.showStatsPanelView {
                            BasicStatsPanelViewSwiftUI()
                                .frame(height: 80)
                        }
                    }
                    .padding(.bottom, 8)

                    // Chart - expands to fill remaining space
                    ZStack {
                        if let scene = chartScene {
                            ChartView(viewModel: viewModel, chartScene: scene)
                        }

                        // Error message overlay
                        if viewModel.showError {
                            Text(viewModel.errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.white.opacity(0.75))
                                .cornerRadius(4)
                                .padding(.top, 8)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .frame(minHeight: 150, maxHeight: .infinity)
                    .padding(.bottom, 8)

                    // Slide to snooze
                    ZStack {
                        if viewModel.showActionsMenu {
                            SlideToSnooze(snoozeText: $viewModel.snoozeButtonText) {
                                showSnoozePopup = true
                            }
                            .frame(height: viewModel.slideToSnoozeHeight)

                            // Actions menu button
                            HStack {
                                Spacer()
                                Button(action: {
                                    showActionsMenuPopup = true
                                }) {
                                    Image("Action")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 48, height: 48)
                                .background(Color(UIColor.darkGray.withAlphaComponent(0.3)))
                                .clipShape(Circle())
                                .padding(.trailing, 8)
                                .accessibilityIdentifier("actionsMenuButton")
                                .onLongPressGesture {
                                    showNightscout = true
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)

                }
            }
            .onAppear {
                // Only setup chart if it hasn't been created yet
                // This prevents recreating the chart on tab switches
                if chartScene == nil {
                    // Calculate chart height based on available geometry
                    let chartHeight = calculateChartHeight(totalHeight: geometry.size.height)

                    setupChart(height: chartHeight)
                }

                viewModel.isVisible = true

                // Start timer - it will fire immediately and handle all initialization
                viewModel.startTimer(forceRepaint: true)
            }
        }
        .statusBar(hidden: true)
        .onDisappear {
            viewModel.isVisible = false
            viewModel.stopTimer()
        }
        .onChange(of: selectedTab) { newTab in
            viewModel.handleVisibilityChange(isVisible: newTab == .main)
        }
        .sheet(isPresented: $showNightscout) {
            NightscoutView()
        }
        .sheet(isPresented: $showSnoozePopup) {
            SnoozePopupView()
        }
        .confirmationDialog("Actions", isPresented: $showActionsMenuPopup, titleVisibility: .hidden) {
            Button(NSLocalizedString("Open your Nightscout site", comment: "Link to NS site")) {
                showNightscout = true
            }
            Button(NSLocalizedString("Fullscreen monitor", comment: "Fullscreen monitor")) {
                showFullscreenMonitor = true
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showFullscreenMonitor) {
            BedsideView(currentNightscoutData: viewModel.nightscoutData)
        }
    }

    private func calculateChartHeight(totalHeight: CGFloat) -> CGFloat {
        // Calculate heights of other UI components
        let topSectionHeight: CGFloat = 200 // Estimated BG value section
        let careDataHeight: CGFloat = viewModel.showCareAndLoopData ? 50 : 0
        let statsPanelHeight: CGFloat = viewModel.showStatsPanelView ? 88 : 0
        let snoozeHeight: CGFloat = viewModel.slideToSnoozeHeight
        let spacing: CGFloat = 24

        let usedHeight = topSectionHeight + careDataHeight + statsPanelHeight + snoozeHeight + spacing
        let chartHeight = max(150, totalHeight - usedHeight)

        return chartHeight
    }

    private func setupChart(height: CGFloat) {
        let scene = ChartScene(
            size: CGSize(width: UIScreen.main.bounds.width, height: height),
            newCanvasWidth: 2048,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
        )
        chartScene = scene
        viewModel.skScene = scene
    }

    private func updateChartSceneSize(width: CGFloat, height: CGFloat) {
        let scene = ChartScene(
            size: CGSize(width: width, height: height),
            newCanvasWidth: 2048,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
        )
        chartScene = scene
        viewModel.skScene = scene
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
