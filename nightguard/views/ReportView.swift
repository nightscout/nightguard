import SwiftUI
import PDFKit
import UIKit

private struct ReportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ReportView: View {
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var settings = ReportSettings.load()
    @State private var includeBirthDate = ReportSettings.load().birthDate != nil
    @State private var birthDateDraft = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var showingPromotion = false
    @State private var reportFile: ReportFile?
    @State private var temporaryReportURL: URL?
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var progress = 0.0
    @State private var provider: ReportDataProvider?
    @State private var exportID = UUID()

    var body: some View {
        NavigationView {
            Form {
                if !purchaseManager.hasProFeatureAccess {
                    Section {
                        Label(NSLocalizedString("PDF reports with Pro", comment: "Report teaser"), systemImage: "doc.richtext")
                            .font(.headline)
                        Text(NSLocalizedString("Create and share PDF summaries of glucose and treatment history for personal reference.", comment: "Report teaser"))
                        Button(NSLocalizedString("Unlock Pro Version", comment: "Subscription button")) {
                            showingPromotion = true
                        }
                    }
                } else {
                    Section(header: Text(NSLocalizedString("Personal information", comment: "Report"))) {
                        TextField(NSLocalizedString("Name", comment: "Report"), text: binding(\.name))
                        Toggle(NSLocalizedString("Include date of birth", comment: "Report"), isOn: Binding(
                            get: { includeBirthDate },
                            set: {
                                includeBirthDate = $0
                                if !$0 { settings.birthDate = nil; settings.save() }
                            }
                        ))
                        if includeBirthDate {
                            DatePicker(NSLocalizedString("Date of birth", comment: "Report"), selection: Binding(
                                get: { settings.birthDate ?? birthDateDraft },
                                set: { birthDateDraft = $0; settings.birthDate = $0; settings.save() }
                            ), in: ...Date(), displayedComponents: .date)
                        }
                        TextField(NSLocalizedString("Diabetes since", comment: "Report"), text: binding(\.diabetesSince))
                        TextField(NSLocalizedString("Insulin", comment: "Report"), text: binding(\.insulin))
                    }
                    Section(header: Text(NSLocalizedString("Period", comment: "Report"))) {
                        Picker(NSLocalizedString("Export period", comment: "Report"), selection: Binding(
                            get: { settings.period }, set: { settings.period = $0; settings.save() }
                        )) {
                            ForEach(ReportPeriod.allCases) { period in
                                Text(period.title).tag(period.rawValue)
                            }
                        }
                        Text(ReportRequest(settings: settings).rangeText)
                            .foregroundColor(.secondary)
                        Text(String(format: NSLocalizedString("Range: %@–%@ %@", comment: "Report"),
                                    ReportRequest(settings: settings).displayGlucose(Double(UserDefaultsRepository.lowerBound.value)),
                                    ReportRequest(settings: settings).displayGlucose(Double(UserDefaultsRepository.upperBound.value)),
                                    ReportRequest(settings: settings).glucoseUnit))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Section {
                        Button(action: createReport) {
                            Label(NSLocalizedString("Create PDF report", comment: "Report action"), systemImage: "doc.richtext")
                        }
                        .disabled(isCreating)
                        if isCreating {
                            ProgressView(value: progress)
                            Button(NSLocalizedString("Cancel", comment: "Report action")) {
                                provider?.cancel()
                                provider = nil
                                exportID = UUID()
                                isCreating = false
                            }
                        }
                    } footer: {
                        Text(NSLocalizedString("The PDF stays on this device until you choose where to share or save it.", comment: "Report privacy"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Report", comment: "Report tab"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingPromotion) { ProPromotionView(initialPromotion: .pro, showsRemindLater: false) }
        .sheet(item: $reportFile, onDismiss: cleanupFile) { file in
            ReportPreviewView(url: file.url)
        }
        .alert(NSLocalizedString("Report unavailable", comment: "Report error"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func binding(_ keyPath: WritableKeyPath<ReportSettings, String>) -> Binding<String> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0; settings.save() })
    }

    private func createReport() {
        guard purchaseManager.hasProFeatureAccess else { showingPromotion = true; return }
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            errorMessage = NSLocalizedString("Configure Nightscout in Preferences before creating a report.", comment: "Report error")
            return
        }
        isCreating = true
        progress = 0
        let operationID = UUID()
        exportID = operationID
        let loader = ReportDataProvider()
        provider = loader
        loader.load(settings: settings, progress: { value in
            DispatchQueue.main.async { if self.isCreating && self.exportID == operationID { self.progress = value * 0.85 } }
        }) { result in
            guard self.isCreating && self.exportID == operationID else { return }
            self.provider = nil
            switch result {
            case .failure(let error):
                self.isCreating = false
                self.errorMessage = error.localizedDescription
            case .success(let loaded):
                let (request, data) = loaded
                guard !data.readings.filter({ !$0.isMeter }).isEmpty else {
                    self.isCreating = false
                    self.errorMessage = NSLocalizedString("No glucose data was found for the selected period.", comment: "Report error")
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let analysis = ReportCalculator.calculate(data, request: request)
                    let output = Result { try ReportPDFRenderer().render(request: request, analysis: analysis) }
                    DispatchQueue.main.async {
                        guard self.isCreating && self.exportID == operationID else {
                            if case .success(let url) = output { self.removeTemporaryReport(at: url) }
                            return
                        }
                        self.isCreating = false
                        switch output {
                        case .success(let url):
                            if self.purchaseManager.hasProFeatureAccess {
                                self.progress = 1
                                self.temporaryReportURL = url
                                self.reportFile = ReportFile(url: url)
                            } else {
                                self.removeTemporaryReport(at: url)
                                self.showingPromotion = true
                            }
                        case .failure(let error): self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func cleanupFile() {
        if let url = temporaryReportURL { removeTemporaryReport(at: url) }
        temporaryReportURL = nil
    }

    private func removeTemporaryReport(at url: URL) {
        let folder = url.deletingLastPathComponent()
        guard folder.lastPathComponent.hasPrefix("NightguardReport-") else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}

private struct ReportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    let url: URL
    @State private var showingShare = false

    var body: some View {
        NavigationView {
            PDFPreview(url: url)
                .navigationTitle(NSLocalizedString("PDF report", comment: "Report preview"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(NSLocalizedString("Done", comment: "Report preview")) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showingShare = true } label: {
                            Label(NSLocalizedString("Share PDF", comment: "Report action"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(!purchaseManager.hasProFeatureAccess)
                    }
                }
                .sheet(isPresented: $showingShare) { ReportShareSheet(url: url) }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}

private struct ReportShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}
