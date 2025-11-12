//
//  MainView.swift
//  nightguard
//
//  SwiftUI conversion of MainViewController
//

import SwiftUI
import SpriteKit
import Combine

// MARK: - MainViewModel

class MainViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var bgValue: String = "---"
    @Published var bgColor: Color = .white
    @Published var deltaValue: String = "---"
    @Published var deltaArrows: String = "-"
    @Published var deltaColor: Color = .white
    @Published var timeValue: String = "--:--"
    @Published var lastUpdateValue: String = "0min"
    @Published var lastUpdateColor: Color = .white
    @Published var batteryValue: String = "100%"
    @Published var batteryColor: Color = .white
    @Published var reservoirValue: String = "---"
    @Published var cobValue: String = "0g"
    @Published var iobValue: String = "0.0U"
    @Published var cannulaAge: String = "CAGE --"
    @Published var sensorAge: String = "SAGE --"
    @Published var batteryAge: String = "BAGE --"
    @Published var activeProfile: String = "--"
    @Published var temporaryBasal: String = "TB --"
    @Published var temporaryTarget: String = "TT --"
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var showStatsPanelView: Bool = true
    @Published var showCareAndLoopData: Bool = true
    @Published var showActionsMenu: Bool = true
    @Published var slideToSnoozeHeight: CGFloat = 80
    @Published var snoozeButtonText: String = "snooze"

    // Current nightscout data
    @Published var currentNightscoutData: NightscoutData?

    // Chart scene
    var chartScene: ChartScene?

    // Timer
    private var timer: Timer?
    private let timeInterval: TimeInterval = 30.0

    // Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupObservers()
        loadInitialData()

        // Listen to alarm snoozing & play/stop alarm accordingly
        AlarmRule.onSnoozeTimestampChanged = { [weak self] in
            self?.evaluateAlarmActivationState()
        }
    }

    // MARK: - Setup
    private func setupObservers() {
        // Note: Alarm snoozing is handled via AlarmRule.onSnoozeTimestampChanged callback set in init()

        // Observe user defaults changes
        UserDefaultsRepository.showStats.observeChanges { [weak self] value in
            self?.showStatsPanelView = value
        }

        UserDefaultsRepository.showCareAndLoopData.observeChanges { [weak self] value in
            self?.showCareAndLoopData = value
        }

        AlarmRule.areAlertsGenerallyDisabled.observeChanges { [weak self] value in
            self?.showActionsMenu = !value
            self?.slideToSnoozeHeight = value ? 0 : 80
        }
    }

    private func loadInitialData() {
        showStatsPanelView = UserDefaultsRepository.showStats.value
        showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value
        showActionsMenu = !AlarmRule.areAlertsGenerallyDisabled.value
        slideToSnoozeHeight = AlarmRule.areAlertsGenerallyDisabled.value ? 0 : 80
        updateSnoozeButtonText()
    }

    // MARK: - Public Methods
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.doPeriodicUpdate(forceRepaint: false)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func doPeriodicUpdate(forceRepaint: Bool) {
        paintCurrentTime()
        loadAndPaintCurrentBgData()
        loadAndPaintChartData(forceRepaint: forceRepaint)
        loadAndPaintCareData()
        AppleHealthService.singleton.sync()
        updateSnoozeButtonText()
    }

    func evaluateAlarmActivationState() {
        if AlarmRule.isAlarmActivated() {
            AlarmSound.play()
        } else {
            if !AlarmSound.isTesting {
                AlarmSound.stop()
            }
        }
        updateSnoozeButtonText()
    }

    func updateSnoozeButtonText() {
        if AlarmRule.isSnoozed() {
            let remainingMinutes = AlarmRule.getRemainingSnoozeMinutes()
            snoozeButtonText = String(format: NSLocalizedString("Snoozed for %dmin", comment: ""), remainingMinutes)
        } else {
            snoozeButtonText = NSLocalizedString("snooze", comment: "")
        }
    }

    // MARK: - Private Methods
    private func paintCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeValue = formatter.string(from: Date())
    }

    private func loadAndPaintCurrentBgData() {
        let currentNightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData { [weak self] result in
            guard let self = self else { return }

            self.evaluateAlarmActivationState()

            if SharedUserDefaultsRepository.showBGOnAppBadge.value {
                UIApplication.shared.setCurrentBGValueOnAppBadge()
            }

            guard let result = result else { return }

            switch result {
            case .error(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ \(error.localizedDescription)"
                    self.showError = true
                }
            case .data(let newNightscoutData):
                DispatchQueue.main.async {
                    self.showError = false
                    self.paintCurrentBgData(currentNightscoutData: newNightscoutData)
                }
                WatchService.singleton.sendToWatchCurrentNightwatchData()
            }
        }

        evaluateAlarmActivationState()
        paintCurrentBgData(currentNightscoutData: currentNightscoutData)
    }

    private func paintCurrentBgData(currentNightscoutData: NightscoutData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Store the current data
            self.currentNightscoutData = currentNightscoutData

            if currentNightscoutData.sgv == "---" {
                self.bgValue = "---"
            } else {
                self.bgValue = UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv)
            }

            self.bgColor = Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv)))

            self.deltaValue = UnitsConverter.mgdlToDisplayUnitsWithSign("\(currentNightscoutData.bgdelta)")
            self.deltaArrows = currentNightscoutData.bgdeltaArrow
            self.deltaColor = Color(UIColorChanger.getDeltaLabelColor(UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.bgdelta)))

            self.lastUpdateValue = currentNightscoutData.timeString
            self.lastUpdateColor = Color(UIColorChanger.getTimeLabelColor(currentNightscoutData.time))

            self.batteryValue = currentNightscoutData.battery
            self.batteryColor = Color(UIColorChanger.getBatteryLabelColor(currentNightscoutData.battery))

            if !currentNightscoutData.iob.isEmpty {
                self.iobValue = currentNightscoutData.iob
            }
            if !currentNightscoutData.cob.isEmpty {
                self.cobValue = currentNightscoutData.cob
            }

            // Notify that data has been updated
            NotificationCenter.default.post(name: NSNotification.Name("NightscoutDataUpdated"), object: nil)
        }
    }

    private func loadAndPaintChartData(forceRepaint: Bool) {
        let _ = NightscoutCacheService.singleton.loadTodaysData { [weak self] result in
            guard let result = result, let self = self else { return }

            if case .data(let newTodaysData) = result {
                let cachedYesterdaysData = NightscoutCacheService.singleton.getYesterdaysBgData()
                self.paintChartData(todaysData: newTodaysData, yesterdaysData: cachedYesterdaysData)
            }
        }

        let _ = NightscoutCacheService.singleton.loadYesterdaysData { [weak self] result in
            guard let result = result, let self = self else { return }

            if case .data(let newYesterdaysData) = result {
                let cachedTodaysBgData = NightscoutCacheService.singleton.getTodaysBgData()
                self.paintChartData(todaysData: cachedTodaysBgData, yesterdaysData: newYesterdaysData)
            }
        }
    }

    private func paintChartData(todaysData: [BloodSugar], yesterdaysData: [BloodSugar]) {
        let todaysDataWithPrediction = todaysData + PredictionService.singleton.nextHourGapped

        chartScene?.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: CGFloat(maximumDeviceTextureWidth()),
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: true,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
        )
    }

    private func loadAndPaintCareData() {
        // Update care labels
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.sensorAge = self.convertToAge(
                prefix: "SAGE ",
                time: NightscoutCacheService.singleton.getSensorChangeTime()
            )

            self.cannulaAge = self.convertToAge(
                prefix: "CAGE ",
                time: NightscoutCacheService.singleton.getCannulaChangeTime()
            )

            self.batteryAge = self.convertToAge(
                prefix: "BAT ",
                time: NightscoutCacheService.singleton.getPumpBatteryChangeTime()
            )
        }

        let deviceStatusData = NightscoutCacheService.singleton.getDeviceStatusData { [weak self] result in
            self?.paintDeviceStatusData(deviceStatusData: result)
        }

        NightscoutService.singleton.readLatestTreatements { treatments in
            TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: treatments)
        }

        paintDeviceStatusData(deviceStatusData: deviceStatusData)
    }

    private func paintDeviceStatusData(deviceStatusData: DeviceStatusData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.reservoirValue = "R \(deviceStatusData.reservoirUnits)U"
            self.activeProfile = deviceStatusData.activePumpProfile.trimInfix(keepPrefixCharacterCount: 7, keepPostfixCharacterCount: 7)

            if deviceStatusData.temporaryBasalRate != "" &&
                deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes() > 0 {
                self.temporaryBasal = "TB \(deviceStatusData.temporaryBasalRate)% \(deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes())m"
            } else {
                self.temporaryBasal = "TB --"
            }

            NightscoutCacheService.singleton.getTemporaryTargetData() { temporaryTargetData in
                DispatchQueue.main.async {
                    if temporaryTargetData.activeUntilDate.remainingMinutes() > 0 {
                        self.temporaryTarget = "TT \(UnitsConverter.mgdlToDisplayUnits("\(temporaryTargetData.targetTop)")) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
                    } else {
                        self.temporaryTarget = "TT --"
                    }
                }
            }
        }
    }

    private func convertToAge(prefix: String, time: Date) -> String {
        let hours = Int(-time.timeIntervalSinceNow / 3600)
        return "\(prefix)\(hours)h"
    }

    private func maximumDeviceTextureWidth() -> Int {
        return 2048 // Default value, can be adjusted based on device
    }
}

// MARK: - ChartView (SpriteKit Wrapper)

struct ChartView: UIViewRepresentable {
    @ObservedObject var viewModel: MainViewModel
    let chartScene: ChartScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .black
        skView.presentScene(chartScene)

        // Add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))

        skView.addGestureRecognizer(panGesture)
        skView.addGestureRecognizer(pinchGesture)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Update if needed
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

// MARK: - BasicStatsPanelView (SwiftUI)

struct BasicStatsPanel: View {
    @State private var model: BasicStats? = BasicStats(period: .last24h)
    @State private var currentPeriod: BasicStats.Period = .last24h
    @State private var updateTrigger: UUID = UUID()

    var body: some View {
        HStack(spacing: 8) {
            A1cViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            GlucoseDistributionViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            ReadingsStatsViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            StatsPeriodSelectorViewRepresentable(
                model: model,
                onPeriodChange: { period in
                    currentPeriod = period
                    model = BasicStats(period: period)
                }
            )
            .aspectRatio(1, contentMode: .fit)

            Spacer()
        }
        .onAppear {
            updateModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NightscoutDataUpdated"))) { _ in
            updateModel()
        }
    }

    func updateModel() {
        if let currentModel = model, currentModel.isUpToDate {
            // Model is already up to date
        } else {
            // Recreate the model
            model = BasicStats(period: model?.period ?? .last24h)
            updateTrigger = UUID()
        }
    }
}

// MARK: - UIViewRepresentable Wrappers for Stats Child Views

struct A1cViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> A1cView {
        let view = A1cView()
        return view
    }

    func updateUIView(_ uiView: A1cView, context: Context) {
        uiView.model = model
    }
}

struct GlucoseDistributionViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> GlucoseDistributionView {
        let view = GlucoseDistributionView()
        return view
    }

    func updateUIView(_ uiView: GlucoseDistributionView, context: Context) {
        uiView.model = model
    }
}

struct ReadingsStatsViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> ReadingsStatsView {
        let view = ReadingsStatsView()
        return view
    }

    func updateUIView(_ uiView: ReadingsStatsView, context: Context) {
        uiView.model = model
    }
}

struct StatsPeriodSelectorViewRepresentable: UIViewRepresentable {
    let model: BasicStats?
    let onPeriodChange: (BasicStats.Period) -> Void

    func makeUIView(context: Context) -> StatsPeriodSelectorView {
        let view = StatsPeriodSelectorView()
        view.onPeriodChangeRequest = { period in
            onPeriodChange(period)
        }
        return view
    }

    func updateUIView(_ uiView: StatsPeriodSelectorView, context: Context) {
        uiView.model = model
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
                                .frame(maxWidth: .infinity, alignment: .trailing)

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

                                HStack(spacing: 0) {
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
                            .frame(minWidth: 100)
                        }
                        .padding(.horizontal, 8)

                        // Care data row
                        if viewModel.showCareAndLoopData {
                            HStack {
                                Text(viewModel.cannulaAge)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(viewModel.sensorAge)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(viewModel.batteryAge)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
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
                            BasicStatsPanel()
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
                    .frame(minHeight: 300, maxHeight: .infinity)
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
                // Calculate chart height based on available geometry
                let topSectionHeight: CGFloat = 200 // Estimated BG value section
                let careDataHeight: CGFloat = viewModel.showCareAndLoopData ? 50 : 0
                let statsPanelHeight: CGFloat = viewModel.showStatsPanelView ? 88 : 0
                let snoozeHeight: CGFloat = viewModel.slideToSnoozeHeight
                let spacing: CGFloat = 24

                let usedHeight = topSectionHeight + careDataHeight + statsPanelHeight + snoozeHeight + spacing
                let chartHeight = max(400, geometry.size.height - usedHeight)

                setupChart(height: chartHeight)
                viewModel.startTimer()
                viewModel.doPeriodicUpdate(forceRepaint: true)
            }
        }
        .statusBar(hidden: true)
        .onDisappear {
            viewModel.stopTimer()
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                // Switched back to Main tab - repaint chart with current bounds
                let cachedTodaysData = NightscoutCacheService.singleton.getTodaysBgData()
                let cachedYesterdaysData = NightscoutCacheService.singleton.getYesterdaysBgData()
                let todaysDataWithPrediction = cachedTodaysData + PredictionService.singleton.nextHourGapped

                chartScene?.paintChart(
                    [todaysDataWithPrediction, cachedYesterdaysData],
                    newCanvasWidth: CGFloat(chartScene?.canvasWidth ?? 1024),
                    maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
                    moveToLatestValue: false,
                    useContrastfulColors: false,
                    showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
                )
            }
        }
        .sheet(isPresented: $showNightscout) {
            NightscoutViewRepresentable()
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
            BedsideViewRepresentable(currentNightscoutData: viewModel.currentNightscoutData)
        }
    }

    private func calculateChartHeight(totalHeight: CGFloat) -> CGFloat {
        // Calculate heights of other UI components
        let topPadding: CGFloat = 8
        let bgValueSection: CGFloat = 130 // BG value row
        let careDataSection: CGFloat = viewModel.showCareAndLoopData ? 50 : 0
        let statsPanelSection: CGFloat = viewModel.showStatsPanelView ? 88 : 0 // 80 + spacing
        let snoozeSection: CGFloat = viewModel.slideToSnoozeHeight
        let spacing: CGFloat = 8 * 3 // VStack spacing between major sections

        let usedHeight = topPadding + bgValueSection + careDataSection + statsPanelSection + snoozeSection + spacing
        let chartHeight = max(200, totalHeight - usedHeight)

        return chartHeight
    }

    private func setupChart(height: CGFloat) {
        let scene = ChartScene(
            size: CGSize(width: UIScreen.main.bounds.width, height: height),
            newCanvasWidth: 1024,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
        )
        chartScene = scene
        viewModel.chartScene = scene
    }

    private func updateChartSceneSize(width: CGFloat, height: CGFloat) {
        let scene = ChartScene(
            size: CGSize(width: width, height: height),
            newCanvasWidth: 1024,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value
        )
        chartScene = scene
        viewModel.chartScene = scene
    }
}

// MARK: - Supporting Views

struct NightscoutViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let nightscoutInitialViewController = UIStoryboard(name: "Nightscout", bundle: Bundle.main).instantiateInitialViewController()!
        nightscoutInitialViewController.modalPresentationStyle = .fullScreen
        return nightscoutInitialViewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct BedsideViewRepresentable: UIViewControllerRepresentable {
    let currentNightscoutData: NightscoutData?

    func makeUIViewController(context: Context) -> BedsideViewController {
        let bedsideViewController = BedsideViewController.instantiate()
        bedsideViewController.modalPresentationStyle = .fullScreen
        bedsideViewController.currentNightscoutData = currentNightscoutData
        return bedsideViewController
    }

    func updateUIViewController(_ uiViewController: BedsideViewController, context: Context) {
        uiViewController.currentNightscoutData = currentNightscoutData
        uiViewController.updateAlarmInfo()
    }
}

struct SnoozePopupView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let navController = storyboard.instantiateViewController(withIdentifier: "snoozeAlarmNavigationController") as? UINavigationController {
                SnoozeAlarmRepresentable(navigationController: navController)
            }
        }
    }
}

struct SnoozeAlarmRepresentable: UIViewControllerRepresentable {
    let navigationController: UINavigationController

    func makeUIViewController(context: Context) -> UINavigationController {
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
