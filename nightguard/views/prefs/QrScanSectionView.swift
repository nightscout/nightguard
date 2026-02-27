//
//  QrScanSectionView.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import SwiftUI

struct QrScanSectionView: View {
    
    // view for displaying QR code scan button and making callback with endpoint

    @Binding var nightscoutURL: String
    var onURLScanned: () -> Void

    @State private var showQRScanner = false

    var body: some View {
        Section {
            Button {
                showQRScanner = true
            } label: {
                Label(NSLocalizedString("Scan QR code", comment: "QR code scan button title"), systemImage: "qrcode.viewfinder")
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerViewRepresentable { scannedCode in
                showQRScanner = false

                let endpoint = extractEndpoint(from: scannedCode)

                guard !endpoint.isEmpty else {
                    return
                }

                nightscoutURL = endpoint
                onURLScanned()
            }
        }
    }
}
