//
//  BedsideView.swift
//  nightguard
//
//  SwiftUI conversion of BedsideViewController
//

import SwiftUI

struct BedsideView: View {
    @Environment(\.dismiss) private var dismiss
    let currentNightscoutData: NightscoutData?

    @State private var currentTime: String = ""
    @State private var snoozeInfo: String?
    @State private var alertReason: String?
    @State private var alertColor: Color = .red

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Blood glucose value
                Text(bgValue)
                    .font(.system(size: 150, weight: .bold))
                    .foregroundColor(bgColor)
                    .minimumScaleFactor(0.5)

                // Delta and arrows
                HStack(spacing: 10) {
                    Text(deltaValue)
                        .font(.system(size: 50))
                        .foregroundColor(deltaColor)

                    Text(deltaArrows)
                        .font(.system(size: 50))
                        .foregroundColor(deltaColor)
                }

                // Last update time
                Text(lastUpdateValue)
                    .font(.system(size: 35))
                    .foregroundColor(lastUpdateColor)

                // Current time
                Text(currentTime)
                    .font(.system(size: 30))
                    .foregroundColor(.white)

                Spacer()

                // Snooze info
                if let snoozeInfo = snoozeInfo {
                    Text(snoozeInfo)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                }

                // Alert info
                if let alertReason = alertReason {
                    Text(alertReason)
                        .font(.system(size: 30))
                        .foregroundColor(alertColor)
                        .padding(.bottom, 20)
                }

                Spacer()
            }

            // Close button
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
                }
                Spacer()
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            updateCurrentTime()
            updateAlarmInfo()
        }
        .onReceive(timer) { _ in
            updateCurrentTime()
            updateAlarmInfo()
        }
    }

    // MARK: - Computed Properties

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

    private func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        currentTime = formatter.string(from: Date())
    }

    private func updateAlarmInfo() {
        var newSnoozeInfo: String?
        var newAlertReason: String?
        var newAlertColor: Color = .red
        var showAlertReason = true

        if AlarmRule.isSnoozed() {
            let remainingSnoozeMinutes = AlarmRule.getRemainingSnoozeMinutes()
            newSnoozeInfo = String(format: NSLocalizedString("Snoozed for %dmin", comment: "Snoozed Label in Bedside Controller"), remainingSnoozeMinutes)

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

        snoozeInfo = newSnoozeInfo
        alertReason = newAlertReason
        alertColor = newAlertColor
    }
}

// MARK: - Preview

struct BedsideView_Previews: PreviewProvider {
    static var previews: some View {
        BedsideView(currentNightscoutData: nil)
    }
}
