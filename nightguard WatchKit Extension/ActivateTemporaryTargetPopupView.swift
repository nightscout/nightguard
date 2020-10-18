//
//  ActivateTemporaryTargetView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 11.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import SwiftUI
import SpriteKit
import Combine

@available(watchOSApplicationExtension 6.0, *)
struct ActivateTemporaryTargetPopupView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool

    var body: some View {
        VStack() {
            Text(
                String(format: NSLocalizedString("Do you want to set a temporary target for %d minutes?", comment: "Set Target Message Text"), UserDefaultsRepository.temporaryTargetDuration.value) +
                    "\n (\(UnitsConverter.mgdlToDisplayUnits(Float(UserDefaultsRepository.temporaryTargetAmount.value))) \(UserDefaultsRepository.units.value.description))")
            HStack() {
                Button(action: {
                    
                    WKInterfaceDevice.current().play(.success)
                    
                    NightscoutService.singleton.createTemporaryTarget(
                        reason: UserDefaultsRepository.temporaryTargetReason.value,
                        target: UserDefaultsRepository.temporaryTargetAmount.value,
                        durationInMinutes: UserDefaultsRepository.temporaryTargetDuration.value,
                        resultHandler: {(error: String?) in
                            
                        // TODO: Show the result
                    })
                    isPresented = false
                }) {
                    Text(NSLocalizedString("Accept", comment: "Popup Accept-Button"))
                        .font(.system(size: 12))
                }
                Button(action: {
                    isPresented = false
                }) {
                    Text(NSLocalizedString("Decline", comment: "Popup Decline-Button"))
                        .font(.system(size: 12))
                }
            }
            Spacer()
        }
    }
}
