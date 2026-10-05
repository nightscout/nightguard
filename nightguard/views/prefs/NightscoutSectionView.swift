//
//  NightscoutSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct NightscoutSectionView: View {
    private enum Field: Hashable {
        case url
        case token
    }

    @Binding var nightscoutURL: String
    @Binding var forceV1API: Bool
    @Binding var apiToken: String
    @Binding var isValidatingURL: Bool
    @Binding var urlErrorMessage: String
    
    var validateAndSaveURL: () -> Void

    @FocusState private var focusedField: Field?
    
    var body: some View {
        Section(
            header: Text("NIGHTSCOUT"),
            footer: Text("Enter the URL of your Nightscout server and an access token. The token normally needs the careportal role for Care actions.")
                .font(.footnote)
        ) {
            HStack {
                TextField("URL", text: $nightscoutURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($focusedField, equals: .url)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
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

            HStack {
                SecureField("API Token", text: $apiToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .token)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
                if !apiToken.isEmpty {
                    Button(action: {
                        apiToken = ""
                        validateAndSaveURL()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("clear_token_button")
                }
            }

            Toggle("Always use V1 API", isOn: $forceV1API)
                .accessibilityIdentifier("force_v1_api_toggle")
            Text("Loads glucose and treatments directly through V1, without V3 checks or sign-in. V2 remains enabled for IOB, COB and uploader battery.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !urlErrorMessage.isEmpty {
                Text("❌ \(urlErrorMessage)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .onChange(of: focusedField) { _, newField in
            if newField == nil {
                validateAndSaveURL()
            }
        }
    }
}
