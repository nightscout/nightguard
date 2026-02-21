//
//  DurationView.swift
//  nightguard
//
//  SwiftUI version of DurationViewController
//

import SwiftUI

struct DurationView: View {
    @Binding var selectedTab: TabIdentifier

    @State private var cannulaChangeDate = NightscoutCacheService.singleton.getCannulaChangeTime()
    @State private var sensorChangeDate = NightscoutCacheService.singleton.getSensorChangeTime()
    @State private var batteryChangeDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
    @ObservedObject private var alarmService = AlarmNotificationService.singleton
    @ObservedObject var purchaseManager = PurchaseManager.shared

    @State private var showCannulaConfirmation = false
    @State private var showSensorConfirmation = false
    @State private var showBatteryConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showProPromotion = false

    var body: some View {
        NavigationView {
            Form {
                // Cannula section
                Section(
                    header: Text(NSLocalizedString("Cannula", comment: "Cannula Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your cannula. This will be displayed on the main screen as CAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Cannula Change Date"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Cannula change date", comment: "Label for Cannula Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $cannulaChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Cannula Change Date")) {
                            cannulaChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Cannula Change Date")) {
                            showCannulaConfirmation = true
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                }

                // Sensor section
                Section(
                    header: Text(NSLocalizedString("Sensor", comment: "Sensor Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your sensor. This will be displayed on the main screen as SAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Sensor"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Sensor change date", comment: "Label for Sensor Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $sensorChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Sensor Change Date")) {
                            sensorChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Sensor Change Date")) {
                            showSensorConfirmation = true
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                }

                // Battery section
                Section(
                    header: Text(NSLocalizedString("Battery", comment: "Battery Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your pump battery. This will be displayed on the main screen as BAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Battery"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Battery change date", comment: "Label for Battery Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $batteryChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Battery Change Date")) {
                            batteryChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Battery Change Date")) {
                            showBatteryConfirmation = true
                        }
                        .foregroundColor(.white)
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                }

                // Alert Notifications section
                Section(
                    footer: Text(NSLocalizedString("DurationNotificationDescription", comment: "Footer for Duration notifications"))
                        .font(.footnote)
                ) {
                    HStack {
                        Toggle(NSLocalizedString("Duration Notifications", comment: "Label for Duration Notifications toggle"), isOn: Binding(
                            get: { alarmService.publishedEnabled },
                            set: { alarmService.enabled = $0 }
                        ))
                        .disabled(!purchaseManager.isProAccessAvailable)
                        
                        if purchaseManager.isProAccessAvailable {
                            Text("PRO")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.nightguardAccent)
                                .cornerRadius(4)
                        } else {
                            Text("PRO")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                    }
                    
                    if !purchaseManager.isProAccessAvailable {
                        Button(action: {
                            showProPromotion = true
                        }) {
                            Text(NSLocalizedString("Unlock Pro Version", comment: "Unlock Pro Version Button"))
                        }
                    }
                }

                NavigationLink(destination: AgeAlertsView()) {
                    Text(NSLocalizedString("Disposables Age Warnings", comment: "Disposables Age Warnings menu item"))
                }
            }
            .accentColor(Color.nightguardAccent)
            .navigationTitle(NSLocalizedString("Duration", comment: "Duration tab"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cannulaChangeDate = NightscoutCacheService.singleton.getCannulaChangeTime()
                sensorChangeDate = NightscoutCacheService.singleton.getSensorChangeTime()
                batteryChangeDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
                
                checkAndShowProPromotion()
            }
            .sheet(isPresented: $showProPromotion) {
                ProPromotionView(
                    onRemindLater: {
                        UserDefaultsRepository.proPromotionLastSeen.value = Date()
                    }
                )
            }
            .alert(NSLocalizedString("Modify Cannula Change Date", comment: "Modify Cannula Change Date Popup Title"), isPresented: $showCannulaConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveCannulaChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), cannulaChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Modify Sensor Change Date", comment: "Modify Sensor Change Date Popup Title"), isPresented: $showSensorConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveSensorChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), sensorChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Modify Battery Change Date", comment: "Modify Battery Change Date Popup Title"), isPresented: $showBatteryConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveBatteryChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), batteryChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Error", comment: "Popup Error Message Title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("OK", comment: "Popup OK-Button"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Helper Methods

    private func saveCannulaChangeDate() {
        NightscoutService.singleton.createCannulaChangeTreatment(changeDate: cannulaChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: cannulaChangeDate)
                AlarmNotificationService.singleton.scheduleCannulaNotification(changeDate: cannulaChangeDate)
                playSuccessFeedback()
                selectedTab = .main
            }
        }
    }

    private func saveSensorChangeDate() {
        NightscoutService.singleton.createSensorChangeTreatment(changeDate: sensorChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeSensorChangeTime(sensorChangeTime: sensorChangeDate)
                AlarmNotificationService.singleton.scheduleSensorNotification(changeDate: sensorChangeDate)
                playSuccessFeedback()
                selectedTab = .main
            }
        }
    }

    private func saveBatteryChangeDate() {
        NightscoutService.singleton.createBatteryChangeTreatment(changeDate: batteryChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeBatteryChangeTime(batteryChangeTime: batteryChangeDate)
                AlarmNotificationService.singleton.scheduleBatteryNotification(changeDate: batteryChangeDate)
                playSuccessFeedback()
                selectedTab = .main
            }
        }
    }

    private func playSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func checkAndShowProPromotion() {
        if purchaseManager.isProAccessAvailable {
            return
        }
        
        /*let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        
        // If user said "Not now" for this version, don't show.
        if UserDefaultsRepository.proPromotionNotNowVersion.value == versionNumber {
            return
        }*/
        
        // If user said "Remind me later", check if 7 days have passed.
        let lastSeen = UserDefaultsRepository.proPromotionLastSeen.value
        let sevenDaysAgo = Calendar.current.date(byAdding: .minute, value: -7, to: Date()) ?? Date()
        
        if lastSeen > sevenDaysAgo && lastSeen != .distantPast {
            return
        }
        
        // Show after a short delay to ensure view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showProPromotion = true
            UserDefaultsRepository.proPromotionLastSeen.value = Date()
        }
    }
}

#Preview {
    DurationView(selectedTab: .constant(.duration))
}
