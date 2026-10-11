//
//  BedsideView.swift
//  nightguard
//
//  SwiftUI conversion of BedsideViewController
//

import SwiftUI
import Combine

struct BedsideView: View {
    @Environment(\.dismiss) private var dismiss
    let currentNightscoutData: NightscoutData?
    @ObservedObject var viewModel: MainViewModel

    @State private var showSnoozePopup = false
    @State private var currentTime: String = ""
    @State private var alertReason: String?
    @State private var alertColor: Color = .red

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 8) {
                    GeometryReader { contentGeometry in
                        if isLandscape(size: geometry.size) {
                            landscapeContent(size: contentGeometry.size)
                        } else {
                            portraitContent(size: contentGeometry.size)
                        }
                    }
                    .padding(.top, 64)

                    if viewModel.showSnoozeSlider {
                        SlideToSnooze(snoozeText: $viewModel.snoozeButtonText, lowPredictionText: $viewModel.lowPredictionText) {
                            showSnoozePopup = true
                        }
                        .frame(height: 80)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier("bedsideSnoozeSlider")
                    }
                }

                closeButtonOverlay
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            AppDelegate.updateOrientationLock(.all)
            updateCurrentTime()
            updateAlarmInfo()
        }
        .onReceive(timer) { _ in
            updateCurrentTime()
            updateAlarmInfo()
        }
        .sheet(isPresented: $showSnoozePopup, onDismiss: updateAlarmInfo) {
            SnoozePopupView()
        }
    }

    // MARK: - Computed Properties

    private func portraitContent(size: CGSize) -> some View {
        let scale = min(1, max(0.35, size.height / 650))

        return VStack(spacing: 20 * scale) {
            Spacer(minLength: 0)

            Text(bgValue)
                .font(.system(size: 190 * scale, weight: .bold))
                .foregroundColor(bgColor)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            deltaStack(fontSize: 74 * scale, spacing: 12 * scale)

            Text(lastUpdateValue)
                .font(.system(size: 50 * scale))
                .foregroundColor(lastUpdateColor)

            Text(currentTime)
                .font(.system(size: 46 * scale))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            if let alertReason = alertReason {
                Text(alertReason)
                    .font(.system(size: 44 * scale))
                    .foregroundColor(alertColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 20 * scale)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var closeButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image("close")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(UIColor.darkGray.withAlphaComponent(0.3)))
                        .clipShape(Circle())
                }
                .padding()
                .accessibilityIdentifier("fullscreenCloseButton")
            }
            Spacer()
        }
    }

    private var bgValue: String {
        guard let data = currentNightscoutData else { return "---" }
        return UnitsConverter.mgdlToDisplayUnits(data.sgv)
    }

    private var bgColor: Color {
        guard let data = currentNightscoutData else { return .white }
        return Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(data.sgv)))
    }

    private var deltaValue: String {
        guard let data = currentNightscoutData else { return "---" }
        return UnitsConverter.mgdlToDisplayUnitsWithSign("\(data.bgdelta)")
    }

    private var deltaArrows: String {
        return currentNightscoutData?.bgdeltaArrow ?? "-"
    }

    private var deltaColor: Color {
        guard let data = currentNightscoutData else { return .white }
        if let displayDelta = Float(UnitsConverter.mgdlToDisplayUnitsWithSign(data.bgdeltaString)) {
            return Color(UIColorChanger.getDeltaLabelColor(UnitsConverter.mgdlToDisplayUnits(displayDelta)))
        }
        return .white
    }

    private var lastUpdateValue: String {
        return currentNightscoutData?.timeString ?? "--:--"
    }

    private var lastUpdateColor: Color {
        guard let data = currentNightscoutData else { return .white }
        return Color(UIColorChanger.getTimeLabelColor(data.time))
    }

    // MARK: - Private Methods

    @ViewBuilder
    private func landscapeContent(size: CGSize) -> some View {
        let scale = min(1, max(0.35, size.height / 400))
        let infoColumnWidth = min(max(size.width * 0.24, 210), 290)
        let horizontalPadding: CGFloat = 24
        let interColumnSpacing: CGFloat = 24
        let bgFontSize = min(size.height * 0.96, (size.width - infoColumnWidth - (horizontalPadding * 2) - interColumnSpacing) * 0.92)

        HStack(spacing: interColumnSpacing) {
            Text(bgValue)
                .font(.system(size: max(bgFontSize, 100), weight: .bold))
                .foregroundColor(bgColor)
                .minimumScaleFactor(0.22)
                .lineLimit(1)
            .frame(maxHeight: .infinity, alignment: .center)
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 14 * scale) {
                Spacer(minLength: 0)

                deltaStack(fontSize: 72 * scale, spacing: 12 * scale)

                Text(lastUpdateValue)
                    .font(.system(size: 46 * scale, weight: .medium))
                    .foregroundColor(lastUpdateColor)

                Text(currentTime)
                    .font(.system(size: 42 * scale))
                    .foregroundColor(.white)

                if let alertReason = alertReason {
                    Text(alertReason)
                        .font(.system(size: 38 * scale, weight: .medium))
                        .foregroundColor(alertColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 0)
            }
            .frame(width: infoColumnWidth)
            .frame(maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12 * scale)
    }

    private func deltaStack(fontSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Text(deltaValue)
                .font(.system(size: fontSize))
                .foregroundColor(deltaColor)

            Text(deltaArrows)
                .font(.system(size: fontSize))
                .foregroundColor(deltaColor)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private func isLandscape(size: CGSize) -> Bool {
        size.width > size.height
    }

    private func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        currentTime = formatter.string(from: Date())
    }

    private func updateAlarmInfo() {
        viewModel.updateSnoozeButtonText()
        var newAlertReason: String?
        var newAlertColor: Color = .red
        var showAlertReason = true

        if AlarmRule.isSnoozed() {
            let remainingSnoozeMinutes = AlarmRule.getRemainingSnoozeMinutes()

            // Show alert reason message if less than 5 minutes of snoozing (to be prepared!)
            showAlertReason = remainingSnoozeMinutes < 5
        }

        if showAlertReason {
            newAlertReason = AlarmRule.getAlarmActivationReason(ignoreSnooze: true)
            if newAlertReason == nil {
                if AlarmRule.isLowPredictionEnabled.value {
                    // No alarm, but maybe we'll show a low prediction warning...
                    if let minutesToLow = PredictionService.singleton.minutesTo(low: AlarmRule.alertIfBelowValue.value), minutesToLow > 0 {
                        newAlertReason = String(format: NSLocalizedString("Low Predicted in %dmin", comment: "Low Predicted Label in Bedside Controller"), minutesToLow)
                        newAlertColor = .yellow
                    }
                }
            }
        }

        alertReason = newAlertReason
        alertColor = newAlertColor
    }
}

// MARK: - Preview

struct BedsideView_Previews: PreviewProvider {
    static var previews: some View {
        BedsideView(currentNightscoutData: nil, viewModel: MainViewModel())
    }
}
