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
struct AddCarbsPopupView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool

    var body: some View {
        VStack() {
            Text(
                String(format: NSLocalizedString("Do you want to add %dg of carbs?", comment: "Add carbs popup modal text"), UserDefaultsRepository.carbs.value))
            HStack() {
                Button(action: {
                    
                    WKInterfaceDevice.current().play(.success)
                    
                    NightscoutService.singleton.createCarbsCorrection(carbs: UserDefaultsRepository.carbs.value,
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
