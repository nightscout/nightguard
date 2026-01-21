//
//  PrefsView.swift
//  nightguard
//
//  SwiftUI version of PrefsViewController
//

import SwiftUI
import WidgetKit

struct PrefsView: View {
    @State private var nightscoutURL = UserDefaultsRepository.baseUri.value
    @State private var manuallySetUnits = UserDefaultsRepository.manuallySetUnits.value
    @State private var selectedUnits = UserDefaultsRepository.units.value
    @State private var keepScreenActive = SharedUserDefaultsRepository.screenlockSwitchState.value
    @State private var dimScreenWhenIdle = UserDefaultsRepository.dimScreenWhenIdle.value
    @State private var showStats = UserDefaultsRepository.showStats.value
    @State private var showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value
    @State private var showYesterdaysBgs = UserDefaultsRepository.showYesterdaysBgs.value
    @State private var checkBGEveryMinute = UserDefaultsRepository.checkBGEveryMinute.value
    @State private var showBGOnAppBadge = SharedUserDefaultsRepository.showBGOnAppBadge.value
    @State private var appleHealthSync = AppleHealthService.singleton.isAuthorized()

    @State private var showKeepScreenActiveAlert = false
    @State private var showAppleHealthAlert = false
    @State private var showURLErrorAlert = false
    @State private var urlErrorMessage = ""
    @State private var isValidatingURL = false
    @State private var showAppTour = false

    @ObservedObject var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                NightscoutSectionView(
                    nightscoutURL: $nightscoutURL,
                    isValidatingURL: $isValidatingURL,
                    urlErrorMessage: $urlErrorMessage,
                    validateAndSaveURL: validateAndSaveURL
                )
                
                UnitsSectionView(
                    manuallySetUnits: $manuallySetUnits,
                    selectedUnits: $selectedUnits,
                    onUnitsChanged: validateAndSaveURL
                )
                
                ScreenSectionView(
                    keepScreenActive: $keepScreenActive,
                    dimScreenWhenIdle: $dimScreenWhenIdle,
                    showKeepScreenActiveAlert: $showKeepScreenActiveAlert
                )
                
                DisplayOptionsSectionView(
                    showStats: $showStats,
                    showCareAndLoopData: $showCareAndLoopData,
                    showYesterdaysBgs: $showYesterdaysBgs,
                    checkBGEveryMinute: $checkBGEveryMinute,
                    showBGOnAppBadge: $showBGOnAppBadge,
                    appleHealthSync: $appleHealthSync,
                    showAppleHealthAlert: $showAppleHealthAlert
                )
                
                ProFeaturesSectionView(purchaseManager: purchaseManager)
                
                Section {
                    HStack {
                        Spacer()
                        Button("Start App Tour") {
                            showAppTour = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadCurrentValues()
            }
            .alert("ARE YOU SURE?", isPresented: $showKeepScreenActiveAlert) {
                Button("No", role: .cancel) {
                    keepScreenActive = true
                }
                Button("Yes", role: .destructive) {
                    SharedUserDefaultsRepository.screenlockSwitchState.value = false
                }
            } message: {
                Text("Keep this switch ON to disable the screenlock and prevent the app to get stopped!")
            }
            .alert("Synchronize with Apple Health", isPresented: $showAppleHealthAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Revoke access in Apple Health")
            }
            .alert("Error", isPresented: $showURLErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(urlErrorMessage)
            }
            .sheet(isPresented: $showAppTour, onDismiss: {
                loadCurrentValues()
            }) {
                AppTourView(isPresented: $showAppTour)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Helper Methods
    
    private func loadCurrentValues() {
        nightscoutURL = UserDefaultsRepository.baseUri.value
        manuallySetUnits = UserDefaultsRepository.manuallySetUnits.value
        selectedUnits = UserDefaultsRepository.units.value
        keepScreenActive = SharedUserDefaultsRepository.screenlockSwitchState.value
        dimScreenWhenIdle = UserDefaultsRepository.dimScreenWhenIdle.value
        showStats = UserDefaultsRepository.showStats.value
        showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value
        showYesterdaysBgs = UserDefaultsRepository.showYesterdaysBgs.value
        checkBGEveryMinute = UserDefaultsRepository.checkBGEveryMinute.value
        showBGOnAppBadge = SharedUserDefaultsRepository.showBGOnAppBadge.value
        appleHealthSync = AppleHealthService.singleton.isAuthorized()
    }

    private func versionString() -> String {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "V\(versionNumber).\(buildNumber)"
    }

    private func validateAndSaveURL() {
        var urlString = nightscoutURL.trimmingCharacters(in: .whitespaces)

        // Add protocol if missing
        if !urlString.isEmpty && (urlString.contains("/") || urlString.contains(".") || urlString.contains(":")) && !urlString.contains("http") {
            urlString = "https://" + urlString
            nightscoutURL = urlString
        }

        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            return
        }

        isValidatingURL = true
        urlErrorMessage = ""

        UserDefaultsRepository.baseUri.value = url.absoluteString

        // Reset cache and data
        NightscoutCacheService.singleton.resetCache()
        NightscoutDataRepository.singleton.storeTodaysBgData([])
        NightscoutDataRepository.singleton.storeYesterdaysBgData([])
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(NightscoutData())

        retrieveAndStoreNightscoutUnits { error in
            isValidatingURL = false

            if let error = error {
                urlErrorMessage = error.localizedDescription
            } else {
                urlErrorMessage = ""
                addUriToHistory(url: url.absoluteString)
            }
        }
    }

    private func retrieveAndStoreNightscoutUnits(completion: @escaping (Error?) -> Void) {
        if UserDefaultsRepository.manuallySetUnits.value {
            completion(nil)
            return
        }

        NightscoutService.singleton.readStatus { (result: NightscoutRequestResult<Units>) in
            switch result {
            case .data(let units):
                DispatchQueue.main.async {
                    UserDefaultsRepository.units.value = units
                    selectedUnits = units
                }
                completion(nil)
            case .error(let error):
                completion(error)
            }
        }
    }

    private func addUriToHistory(url: String) {
        guard !url.isEmpty else { return }

        var nightscoutUris = UserDefaultsRepository.nightscoutUris.value
        if !nightscoutUris.contains(url) {
            nightscoutUris.insert(url, at: 0)

            // Limit to 5 URIs
            while nightscoutUris.count > 5 {
                nightscoutUris.removeLast()
            }

            UserDefaultsRepository.nightscoutUris.value = nightscoutUris
        }
    }
}

#Preview {
    PrefsView()
}
