//
//  QRScannerViewRepresentable.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import SwiftUI

// Show the QR code scanner and return the result

struct QRScannerViewRepresentable: UIViewControllerRepresentable {

    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerViewRepresentable

        init(_ parent: QRScannerViewRepresentable) {
            self.parent = parent
        }

        func didScanQRCode(_ code: String) {
            parent.onScan(code)
        }

        func didFailScanning(error: Error) {
            print("Scan error:", error)
        }
    }
}
