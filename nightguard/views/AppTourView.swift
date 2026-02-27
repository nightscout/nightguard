//
//  AppTourView.swift
//  nightguard
//
//  Created for App Tour Feature.
//

import SwiftUI

struct AppTourView: View {
    @Binding var isPresented: Bool
    var startOnConfiguration: Bool = false
    @State private var selectedPage = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedPage) {
                TourPage(imageName: "TourScreenshot_Main", title: NSLocalizedString("Welcome to Nightguard", comment: ""), description: NSLocalizedString("See your current glucose level, trend, and device status at a glance.", comment: ""))
                    .tag(0)
                
                TourPage(imageName: "TourScreenshot_Alarm", title: NSLocalizedString("Smart Alarms", comment: ""), description: NSLocalizedString("Manage your glucose alarms and snoozing options. Receive customizable alerts when values are out of range.", comment: ""))
                    .tag(1)
                
                TourPage(imageName: "TourScreenshot_Care", title: NSLocalizedString("Care Portal", comment: ""), description: NSLocalizedString("Log treatments, carb entries, and temporary targets directly from the app.", comment: ""))
                    .tag(2)
                
                TourPage(imageName: "TourScreenshot_Duration", title: NSLocalizedString("Duration", comment: ""), description: NSLocalizedString("Visualize the duration of your insulin on board (IOB) and carbs on board (COB).", comment: ""))
                    .tag(3)
                
                TourPage(imageName: "iPhone 17-07-stats", title: NSLocalizedString("Statistics", comment: ""), description: NSLocalizedString("View detailed statistics and reports of your glucose history to analyze trends.", comment: ""), isLandscape: true)
                    .tag(4)
                
                ConfigurationTourPage(isPresented: $isPresented)
                    .tag(5)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(selectedPage == 5 ? NSLocalizedString("Close", comment: "") : NSLocalizedString("Skip", comment: "")) {
                        if selectedPage < 5 {
                            withAnimation {
                                selectedPage = 5
                            }
                        } else {
                            // Just close, will show again next time
                            isPresented = false
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if startOnConfiguration {
                    selectedPage = 5
                }
            }
        }
        .accentColor(Color.nightguardAccent)
    }
}

struct TourPage: View {
    let imageName: String
    let title: String
    let description: String
    var isLandscape: Bool = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.horizontal, isLandscape ? -40 : 20)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .foregroundColor(.gray)
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal)
    }
}

struct ConfigurationTourPage: View {
    @Binding var isPresented: Bool
    @State private var nightscoutURL: String = ""
    @State private var apiToken: String = ""
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image("Prefs")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                        )
                    
                    Text(NSLocalizedString("Setup Nightscout", comment: ""))
                        .font(.headline)
                    
                    Text(NSLocalizedString("Enter your Nightscout URL and API Token to get started.", comment: ""))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(header: Text(NSLocalizedString("NIGHTSCOUT URL", comment: ""))) {
                HStack {
                    TextField("your-site.herokuapp.com", text: $nightscoutURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if !nightscoutURL.isEmpty {
                        Button(action: {
                            nightscoutURL = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            QrScanSectionView(
                nightscoutURL: $nightscoutURL,
                onURLScanned: saveAndFinish
            )
            
            Section(
                header: HStack {
                    Text(NSLocalizedString("API TOKEN", comment: ""))
                    Spacer()
                    Link(destination: URL(string: "https://nightscout.github.io/nightscout/security/#roles")!) {
                        HStack(spacing: 2) {
                            Text(NSLocalizedString("Help", comment: ""))
                            Image(systemName: "questionmark.circle")
                        }
                    }
                },
                footer: Text(NSLocalizedString("The Token needs to have the \"careportal\" role.", comment: "")) + (nightscoutURL.isEmpty ? Text("") : (Text("\n") + Text(String(format: NSLocalizedString("RESULTING URL: %@", comment: ""), previewURL)).font(.caption).foregroundColor(.secondary)))
            ) {
                HStack {
                    TextField("e.g. update-b4d85ed628a3e34f", text: $apiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if !apiToken.isEmpty {
                        Button(action: {
                            apiToken = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Section {
                VStack(spacing: 0) {
                    Button(action: saveAndFinish) {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("Save & Start", comment: ""))
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .foregroundColor(nightscoutURL.isEmpty ? .gray : .accentColor)
                    .disabled(nightscoutURL.isEmpty)
                    
                    Divider()
                    
                    Button(action: {
                        UserDefaultsRepository.appTourSeen.value = true
                        isPresented = false
                    }) {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("Enter later", comment: ""))
                            Spacer()
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets())
            }
        }
        .onAppear {
            loadExistingSettings()
        }
    }
    
    private func loadExistingSettings() {
        let currentFullURL = UserDefaultsRepository.baseUri.value.trimmingCharacters(in: .whitespaces)
        guard !currentFullURL.isEmpty else { return }
        
        if let components = URLComponents(string: currentFullURL) {
            // Extract token
            if let queryItems = components.queryItems, let tokenItem = queryItems.first(where: { $0.name == "token" }) {
                apiToken = tokenItem.value ?? ""
            }
            
            // Construct base URL (remove token)
            var newComponents = components
            if let queryItems = components.queryItems {
                let otherItems = queryItems.filter { $0.name != "token" }
                if !otherItems.isEmpty {
                    newComponents.queryItems = otherItems
                } else {
                    newComponents.query = nil
                }
            }
            
            if let baseURL = newComponents.url?.absoluteString {
                 nightscoutURL = baseURL
            } else {
                 nightscoutURL = currentFullURL
            }
        } else {
            nightscoutURL = currentFullURL
        }
    }
    
    private var previewURL: String {
        var finalURL = nightscoutURL.trimmingCharacters(in: .whitespaces)
        
        // Add protocol if missing
        if !finalURL.isEmpty && !finalURL.contains("://") {
            finalURL = "https://" + finalURL
        }
        
        // Add token if provided
        let token = apiToken.trimmingCharacters(in: .whitespaces)
        if !token.isEmpty {
            if finalURL.contains("?") {
                finalURL += "&token=" + token
            } else {
                finalURL += "?token=" + token
            }
        }
        return finalURL
    }
    
    private func saveAndFinish() {
        var finalURL = nightscoutURL.trimmingCharacters(in: .whitespaces)
        
        // Add protocol if missing
        if !finalURL.isEmpty && !finalURL.contains("://") {
            finalURL = "https://" + finalURL
        }
        
        // Add token if provided
        let token = apiToken.trimmingCharacters(in: .whitespaces)
        if !token.isEmpty {
            if finalURL.contains("?") {
                finalURL += "&token=" + token
            } else {
                finalURL += "?token=" + token
            }
        }
        
        // Save to UserDefaultsRepository
        UserDefaultsRepository.baseUri.value = finalURL
        
        // Reset cache and data to ensure clean start
        NightscoutCacheService.singleton.resetCache()
        NightscoutDataRepository.singleton.storeTodaysBgData([])
        NightscoutDataRepository.singleton.storeYesterdaysBgData([])
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(NightscoutData())
        
        // Mark tour as seen
        UserDefaultsRepository.appTourSeen.value = true
        isPresented = false
        
        DeviceRegistrationService.shared.configurationDidUpdate()
    }
}

struct AppTourView_Previews: PreviewProvider {
    static var previews: some View {
        AppTourView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}
