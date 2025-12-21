//
//  SnoozePopupView.swift
//  nightguard
//
//  SwiftUI version of SnoozeAlarmViewController
//

import SwiftUI
import WidgetKit

struct SnoozePopupView: View {
    @Environment(\.dismiss) var dismiss

    private let snoozeOptions: [(label: String, minutes: Int)] = [
        ("5", 5),
        ("10", 10),
        ("15", 15),
        ("20", 20),
        ("30", 30),
        ("45", 45),
        ("1h", 60),
        ("2h", 120),
        ("3h", 180),
        ("6h", 360),
        ("12h", 720),
        ("24h", 1440)
    ]

    private var isSnoozed: Bool {
        AlarmRule.isSnoozed()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Title
                    Text(NSLocalizedString("Snooze Alarms for", comment: "Snooze popup title"))
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 30)

                    // Snooze buttons grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(snoozeOptions, id: \.minutes) { option in
                            Button(action: {
                                snoozeMinutes(option.minutes)
                            }) {
                                Text(option.label)
                                    .font(.system(size: deviceFontSize, weight: .regular))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Stop Snoozing button (only visible if snoozed)
                    if isSnoozed {
                        Button(action: {
                            stopSnoozing()
                        }) {
                            Text(NSLocalizedString("Stop Snoozing", comment: "Stop Snoozing button"))
                                .font(.system(size: stopSnoozingFontSize, weight: .medium))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: buttonHeight)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismissPopup()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Device-specific sizes

    private var deviceFontSize: CGFloat {
        switch UIScreen.main.bounds.height {
        case ..<568: return 28  // iPhone 4
        case ..<667: return 32  // iPhone 5
        default: return 36       // iPhone 6 and larger
        }
    }

    private var stopSnoozingFontSize: CGFloat {
        switch UIScreen.main.bounds.height {
        case ..<568: return 24  // iPhone 4
        case ..<667: return 28  // iPhone 5
        default: return 32       // iPhone 6 and larger
        }
    }

    private var buttonHeight: CGFloat {
        switch UIScreen.main.bounds.height {
        case ..<568: return 42  // iPhone 4
        case ..<667: return 56  // iPhone 5
        default: return 70       // iPhone 6 and larger
        }
    }

    // MARK: - Actions

    private func snoozeMinutes(_ minutes: Int) {
        AlarmRule.snooze(minutes)
        AlarmSound.stop()
        AlarmSound.unmuteVolume()
        dismiss()
    }

    private func stopSnoozing() {
        AlarmSound.unmuteVolume()
        AlarmRule.disableSnooze()
        dismiss()
    }

    private func dismissPopup() {
        AlarmSound.unmuteVolume()
        dismiss()
    }
}

#Preview {
    SnoozePopupView()
}
