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
                TourPage(imageName: "Main", title: "Welcome to Nightguard", description: "See your current glucose level, trend, and device status at a glance.")
                    .tag(0)
                
                TourPage(imageName: "Alarm", title: "Smart Alarms", description: "Manage your glucose alarms and snoozing options. Receive customizable alerts when values are out of range.")
                    .tag(1)
                
                TourPage(imageName: "Care", title: "Care Portal", description: "Log treatments, carb entries, and temporary targets directly from the app.")
                    .tag(2)
                
                TourPage(imageName: "clock.arrow.circlepath", title: "Duration", description: "Visualize the duration of your insulin on board (IOB) and carbs on board (COB).")
                    .tag(3)
                
                TourPage(imageName: "Stats", title: "Statistics", description: "View detailed statistics and reports of your glucose history to analyze trends.")
                    .tag(4)
                
                ConfigurationTourPage(isPresented: $isPresented)
                    .tag(5)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(selectedPage == 5 ? "Close" : "Skip") {
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
        .accentColor(.white)
    }
}

struct TourPage: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            if imageName.contains(".") {
                // System Image
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 160, height: 160)
                    )
            } else {
                // Asset Image
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                    )
            }
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .foregroundColor(.gray)
            
            Spacer()
            Spacer()
        }
        .padding()
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
                    
                    Text("Setup Nightscout")
                        .font(.headline)
                    
                    Text("Enter your Nightscout URL and API Token to get started.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(header: Text("NIGHTSCOUT URL")) {
                ZStack(alignment: .leading) {
                    if nightscoutURL.isEmpty {
                        Text("https://your-site.herokuapp.com")
                            .foregroundColor(Color(UIColor.placeholderText))
                    }
                    TextField("", text: $nightscoutURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            
            Section(header: HStack {
                Text("API TOKEN")
                Spacer()
                Link(destination: URL(string: "https://nightscout.github.io/nightscout/security/#roles")!) {
                    HStack(spacing: 2) {
                        Text("Help")
                        Image(systemName: "questionmark.circle")
                    }
                }
            }, footer: Text("The Token needs to have the \"careportal\" role.") + (nightscoutURL.isEmpty ? Text("") : Text("\nRESULTING URL: \(previewURL)").font(.caption).foregroundColor(.secondary))) {
                ZStack(alignment: .leading) {
                    if apiToken.isEmpty {
                        Text("e.g. update-b4d85ed628a3e34f")
                            .foregroundColor(Color(UIColor.placeholderText))
                    }
                    TextField("", text: $apiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            
            Section {
                VStack(spacing: 0) {
                    Button(action: saveAndFinish) {
                        HStack {
                            Spacer()
                            Text("Save & Start")
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
                            Text("Enter later")
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
    }
}

struct AppTourView_Previews: PreviewProvider {
    static var previews: some View {
        AppTourView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}
