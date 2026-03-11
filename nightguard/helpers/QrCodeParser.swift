//
//  QrCodeParser.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import Foundation

// Parse a Nightscout QR code and return the first endpoint string

func extractEndpoint(from qrString: String) -> String {
    guard let data = qrString.data(using: .utf8) else {
        return ""
    }

    guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ""
    }

    let container = jsonObject["rest"] ?? jsonObject["nslite"]

    guard let containerDict = container as? [String: Any] else {
        return ""
    }

    guard let endpoints = containerDict["endpoint"] as? [String],
          let firstEndpoint = endpoints.first else {
        return ""
    }

    return firstEndpoint
}
