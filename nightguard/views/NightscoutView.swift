//
//  NightscoutView.swift
//  nightguard
//
//  SwiftUI version of NightscoutViewController
//

import SwiftUI
import WebKit

struct NightscoutView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NightscoutViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                // WebView
                NightscoutWebView(viewModel: viewModel)
                    .opacity(viewModel.isLoaded ? 1.0 : 0.0)

                // Loading indicator
                if !viewModel.isLoaded {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(action: {
                            viewModel.reload()
                        }) {
                            Text(NSLocalizedString("Refresh", comment: "Refresh button"))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Button(action: {
                            dismiss()
                        }) {
                            Text(NSLocalizedString("Close", comment: "Close button"))
                                .foregroundColor(.white)
                                .bold()
                        }
                        .accessibilityIdentifier("closeButton")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ViewModel

class NightscoutViewModel: ObservableObject {
    @Published var isLoaded = false
    @Published var shouldReload = false

    var webView: WKWebView?

    func reload() {
        guard let webView = webView else { return }

        if webView.isLoading {
            webView.stopLoading()
        }

        guard let baseUri = URL(string: UserDefaultsRepository.baseUri.value) else { return }
        let request = URLRequest(url: baseUri)
        webView.load(request)
    }

    func didFinishLoading(url: URL?) {
        if !isLoaded {
            withAnimation(.easeIn(duration: 0.4)) {
                isLoaded = true
            }
        }

        // Disable scroll for main page, but enable it for all other: reports, profile, etc...
        if let webView = webView {
            let relativePath = url?.relativePath
            let isFixedPage = (relativePath == "/") || (relativePath?.hasSuffix(".html") == true)
            webView.scrollView.isScrollEnabled = !isFixedPage
        }
    }

    func didFailLoading() {
        isLoaded = true
    }
}

// MARK: - WebView Representable

struct NightscoutWebView: UIViewRepresentable {
    @ObservedObject var viewModel: NightscoutViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black

        // Store reference in view model
        viewModel.webView = webView

        // Load Nightscout
        if let baseUri = URL(string: UserDefaultsRepository.baseUri.value) {
            let request = URLRequest(url: baseUri)
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let viewModel: NightscoutViewModel

        init(viewModel: NightscoutViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                completionHandler(false)
                return
            }

            let alertCtrl = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

            alertCtrl.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })

            alertCtrl.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })

            rootViewController.present(alertCtrl, animated: true)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard navigationAction.request.url != nil else {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }

            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            NSLog("Nightscout navigation succeeded: \(String(describing: webView.url))")
            viewModel.didFinishLoading(url: webView.url)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NSLog("Nightscout navigation failed: \(error)")
            viewModel.didFailLoading()
        }
    }
}

#Preview {
    NightscoutView()
}
