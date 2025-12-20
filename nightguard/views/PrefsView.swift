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

    private let dimScreenOptions = [0, 1, 2, 3, 4, 5, 10, 15]

    var body: some View {
        NavigationView {
            Form {
                // Nightscout section
                Section(
                    header: Text("NIGHTSCOUT"),
                    footer: Text("Enter the URI to your Nightscout Server here. E.g. 'https://nightscout?token=mytoken'. For the 'Care' actions to work you generally need to provide the security token here!")
                        .font(.footnote)
                ) {
                    HStack {
                        TextField("URL", text: $nightscoutURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onSubmit {
                                validateAndSaveURL()
                            }

                        if isValidatingURL {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }

                    if !urlErrorMessage.isEmpty {
                        Text("❌ \(urlErrorMessage)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Units section
                Section(
                    footer: Text("If enabled, you will override your Units-Setting of your nightscout backend. Usually you can disable this. Nightguard will determine the correct Units on its own.")
                        .font(.footnote)
                ) {
                    Toggle("Manually set Units", isOn: $manuallySetUnits)
                        .onChange(of: manuallySetUnits) { newValue in
                            UserDefaultsRepository.manuallySetUnits.value = newValue
                            validateAndSaveURL()
                        }

                    if manuallySetUnits {
                        Picker("Use the following Units", selection: $selectedUnits) {
                            ForEach([Units.mgdl, Units.mmol], id: \.self) { unit in
                                Text(unit.description).tag(unit)
                            }
                        }
                        .onChange(of: selectedUnits) { newValue in
                            UserDefaultsRepository.units.value = newValue
                            validateAndSaveURL()
                        }
                    }
                }

                // Screen section
                Section(
                    footer: Text("Keeping the screen active is of paramount importance if using the app as a night guard. We suggest leaving it ALWAYS ON.")
                        .font(.footnote)
                ) {
                    Toggle("Keep the Screen Active", isOn: $keepScreenActive)
                        .onChange(of: keepScreenActive) { newValue in
                            if newValue {
                                SharedUserDefaultsRepository.screenlockSwitchState.value = newValue
                            } else {
                                showKeepScreenActiveAlert = true
                            }
                        }

                    if keepScreenActive {
                        Picker("Dim Screen When Idle", selection: $dimScreenWhenIdle) {
                            ForEach(dimScreenOptions, id: \.self) { option in
                                Text(dimScreenLabel(for: option)).tag(option)
                            }
                        }
                        .onChange(of: dimScreenWhenIdle) { newValue in
                            UserDefaultsRepository.dimScreenWhenIdle.value = newValue
                        }
                    }
                }

                // Display options section
                Section {
                    Toggle("Show Statistics", isOn: $showStats)
                        .onChange(of: showStats) { newValue in
                            UserDefaultsRepository.showStats.value = newValue
                        }

                    Toggle("Show Care/Loop Data", isOn: $showCareAndLoopData)
                        .onChange(of: showCareAndLoopData) { newValue in
                            UserDefaultsRepository.showCareAndLoopData.value = newValue
                        }

                    Toggle("Show Yesterdays BGs", isOn: $showYesterdaysBgs)
                        .onChange(of: showYesterdaysBgs) { newValue in
                            UserDefaultsRepository.showYesterdaysBgs.value = newValue
                        }

                    Toggle("Check BG every minute", isOn: $checkBGEveryMinute)
                        .onChange(of: checkBGEveryMinute) { newValue in
                            UserDefaultsRepository.checkBGEveryMinute.value = newValue
                        }

                    Toggle("Show BG on App Badge", isOn: $showBGOnAppBadge)
                        .onChange(of: showBGOnAppBadge) { newValue in
                            SharedUserDefaultsRepository.showBGOnAppBadge.value = newValue
                        }

                    Toggle("Synchronize with Apple Health", isOn: $appleHealthSync)
                        .onChange(of: appleHealthSync) { newValue in
                            if AppleHealthService.singleton.isAuthorized() {
                                showAppleHealthAlert = true
                                appleHealthSync = true
                            } else {
                                AppleHealthService.singleton.requestAuthorization()
                            }
                        }
                }

                // Version section
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
        }
    }

    // MARK: - Helper Methods

    private func dimScreenLabel(for minutes: Int) -> String {
        switch minutes {
        case 0:
            return NSLocalizedString("Never", comment: "Option")
        case 1:
            return NSLocalizedString("1 Minute", comment: "Option")
        default:
            return "\(minutes) " + NSLocalizedString("Minutes", comment: "Option")
        }
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
