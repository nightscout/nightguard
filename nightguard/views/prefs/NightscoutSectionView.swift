//
//  NightscoutSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct NightscoutSectionView: View {
    @Binding var nightscoutURL: String
    @Binding var isValidatingURL: Bool
    @Binding var urlErrorMessage: String
    
    var validateAndSaveURL: () -> Void
    
    var body: some View {
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
                if !nightscoutURL.isEmpty {
                    Button(action: {
                        nightscoutURL = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("clear_url_button")
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
    }
}
