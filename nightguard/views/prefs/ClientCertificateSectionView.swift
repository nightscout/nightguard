import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ClientCertificateSectionView: View {
    @State private var certificateCommonName: String? = nil
    @State private var certificateExpiryDate: Date? = nil
    @State private var showFileImporter = false
    @State private var showPasswordPrompt = false
    @State private var password = ""
    @State private var pendingP12Data: Data?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showRemoveConfirmation = false
    @State private var showSuccess = false
    @State private var inlinePasswordError: String? = nil
    @State private var isPasswordVisible = false

    var body: some View {
        Section(
            header: Text(NSLocalizedString("Client Certificate", comment: "Client certificate section header")),
            footer: Text(NSLocalizedString("Only needed if your Nightscout provider gave you a certificate file. Most users can skip this.", comment: "Client certificate section footer"))
        ) {
            if let certificateCommonName = certificateCommonName {
                HStack {
                    Text(NSLocalizedString("Certificate", comment: "Client certificate name label"))
                    Spacer()
                    Text(certificateCommonName)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("Certificate: %@", comment: "Accessibility label for certificate name with value"), certificateCommonName))
                .accessibilityIdentifier("certificate_name_label")

                if let expiryDate = certificateExpiryDate {
                    HStack {
                        Text(NSLocalizedString("Expires", comment: "Certificate expiry date label"))
                        Spacer()
                        Text(expiryDate, style: .date)
                            .foregroundColor(expiryDate <= Date() ? .red : expiryDate <= Date().addingTimeInterval(30 * 24 * 60 * 60) ? .orange : .secondary)
                    }
                    if expiryDate <= Date() {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("Expired", comment: "Certificate expired indicator"))
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                Button(NSLocalizedString("Remove Certificate", comment: "Button to remove the client certificate"), role: .destructive) {
                    showRemoveConfirmation = true
                }
                .accessibilityHint(NSLocalizedString("Removes the certificate. Nightscout sync will stop until a new certificate is imported.", comment: "Accessibility hint for remove certificate button"))
                .accessibilityIdentifier("remove_certificate_button")
            } else {
                Button(NSLocalizedString("Import Certificate...", comment: "Button to import a client certificate")) {
                    if pendingP12Data != nil {
                        password = ""
                        inlinePasswordError = nil
                        showPasswordPrompt = true
                    } else {
                        showFileImporter = true
                    }
                }
                .accessibilityHint(NSLocalizedString("Select a PKCS#12 certificate file from your device", comment: "Accessibility hint for import certificate button"))
                .accessibilityIdentifier("import_certificate_button")
            }
            if showSuccess {
                Label(NSLocalizedString("Imported", comment: "Certificate imported success indicator"), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.mint)
                    .accessibilityLabel(NSLocalizedString("Certificate imported successfully", comment: "Accessibility label for import success"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: Self.p12ContentTypes) { result in
            switch result {
            case .success(let url):
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                if let data = try? Data(contentsOf: url) {
                    pendingP12Data = data
                    password = ""
                    inlinePasswordError = nil
                    showPasswordPrompt = true
                } else {
                    showError(NSLocalizedString("The selected file could not be read.", comment: "Client certificate file read error"))
                }
            case .failure(let error):
                showError(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showPasswordPrompt) {
            passwordPrompt
        }
        .confirmationDialog(NSLocalizedString("Remove Certificate?", comment: "Remove certificate confirmation title"), isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("Remove", comment: "Remove certificate confirm button"), role: .destructive) {
                ClientIdentityStore.removeIdentity()
                certificateCommonName = nil
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Nightscout sync will stop until you import a new certificate.", comment: "Remove certificate confirmation message"))
        }
        .alert(NSLocalizedString("Error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            certificateCommonName = ClientIdentityStore.getCommonName()
            certificateExpiryDate = ClientIdentityStore.getExpiryDate()
        }
    }

    private var passwordPrompt: some View {
        NavigationView {
            Form {
                Section(footer: Text(NSLocalizedString("Enter the password of the certificate file.", comment: "Client certificate password prompt footer"))) {
                    HStack {
                        if isPasswordVisible {
                            TextField(NSLocalizedString("Password", comment: "Client certificate password field"), text: $password)
                        } else {
                            SecureField(NSLocalizedString("Password", comment: "Client certificate password field"), text: $password)
                        }
                        Button(action: { isPasswordVisible.toggle() }) {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .onChange(of: password) { _ in inlinePasswordError = nil }
                    .accessibilityHint(NSLocalizedString("Enter the password that protects the certificate file", comment: "Accessibility hint for certificate password field"))
                    .accessibilityIdentifier("certificate_password_field")
                    if let inlinePasswordError = inlinePasswordError {
                        Label(inlinePasswordError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .accessibilityIdentifier("certificate_password_error")
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Certificate Password", comment: "Client certificate password prompt title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        password = ""
                        inlinePasswordError = nil
                        showPasswordPrompt = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Import", comment: "Button to confirm the certificate import")) {
                        importCertificate()
                    }
                }
            }
        }
    }

    private static let p12ContentTypes: [UTType] = {
        var types: [UTType] = [.pkcs12]
        if let pfxType = UTType(filenameExtension: "pfx") {
            types.append(pfxType)
        }
        return types
    }()

    private func importCertificate() {
        inlinePasswordError = nil
        guard let p12Data = pendingP12Data else {
            showPasswordPrompt = false
            return
        }

        do {
            try ClientIdentityStore.importIdentity(p12Data: p12Data, password: password)
            certificateCommonName = ClientIdentityStore.getCommonName()
            certificateExpiryDate = ClientIdentityStore.getExpiryDate()
            pendingP12Data = nil
            password = ""
            showPasswordPrompt = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccess = true
            }
            UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Certificate imported successfully", comment: "VoiceOver announcement for certificate import success"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSuccess = false
                }
            }
        } catch {
            if let certError = error as? ClientIdentityStore.ClientIdentityError,
               case .wrongPassword = certError {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                inlinePasswordError = error.localizedDescription
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                pendingP12Data = nil
                showPasswordPrompt = false
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
