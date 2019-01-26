//
//  NightscoutViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 12/21/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit
import WebKit

class NightscoutViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var webView: WKWebView!
    private var loaded = false
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptEnabled = true
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        
//        edgesForExtendedLayout = []
        
        self.view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo:  self.view.trailingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        webView.heightAnchor.constraint(equalTo: self.view.heightAnchor).isActive = true
        
        // hide the webview until it is fully loaded
        webView.alpha = 0.0
        activityIndicator.startAnimating()
        loadNightscout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        return false
//        switch action {
//        case #selector(UIResponderStandardEditActions.copy(_:)),
//            #selector(UIResponderStandardEditActions.cut(_:)),
//            #selector(UIResponderStandardEditActions.paste(_:)):
//            return false
//        default:
//            return super.canPerformAction(action, withSender: sender)
//        }
    }

    @IBAction func onRefresh(_ sender: UIBarButtonItem) {
        loadNightscout()
    }
    
    @IBAction func onClose(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func loadNightscout() {
        
        if webView.isLoading {
            webView.stopLoading()
        }
        
        guard let baseUri = URL(string: UserDefaultsRepository.readBaseUri()) else { return }
        
        let myRequest = URLRequest(url: baseUri)
        webView.load(myRequest)
    }
}

// MARK:- WKUIDelegate implementation
extension NightscoutViewController: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        
        let alertCtrl = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        
        alertCtrl.addAction(UIAlertAction(title: "OK", style: .default) { action in
            completionHandler(true)
        })

        alertCtrl.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            completionHandler(false)
        })
        
        present(alertCtrl, animated: true)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let _ = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
     
        decisionHandler(.allow)
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        
        guard let url = request.url else {
            return false
        }
        
        NSLog("Should start: \(url.absoluteString)")
        return true
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        
        return nil
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("Nightscout navigation succeeded: \(webView.url)")
        
        if !loaded {
            
            // make visible page on first load
            UIView.animate(withDuration: 0.4, delay: 0.2, options: [], animations: { [weak self] in
                self?.webView.alpha = 1.0
                self?.activityIndicator.alpha = 0.0
                }, completion: { [weak self] (finished: Bool) -> Void in
                    self?.activityIndicator.stopAnimating()
            })
            
            loaded = true
        }
        
        // disable scroll for main page, but enable it for all other: reports, profile, etc...
        let relativePath = webView.url?.relativePath
        let isFixedPage = (relativePath == "/") || (relativePath?.hasSuffix(".html") == true)
        webView.scrollView.isScrollEnabled = !isFixedPage
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("Nightscout navigation failed: \(error)")
        self.activityIndicator.stopAnimating()
        self.activityIndicator.alpha = 0.0
        self.webView.alpha = 1.0
    }
}
