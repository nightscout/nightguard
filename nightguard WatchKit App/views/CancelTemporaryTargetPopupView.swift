//
//  CancelTemporaryTargetPopupView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 11.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import SwiftUI
import SpriteKit
import Combine

struct CancelTemporaryTargetPopupView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var isPresented: Bool

    var body: some View {
        VStack() {
            Text(
                NSLocalizedString("Do you want to cancel an active temporary target?", comment: "Cancel Target Popup Text"))
            HStack() {
                Button(action: {
                    
                    WKInterfaceDevice.current().play(.success)
                    
                    NightscoutService.singleton.deleteTemporaryTarget(
                        resultHandler: {(error: String?) in
                            
                            /* TODO show error message
                            if (error != nil) {
                                self.displayErrorMessagePopup(message: error!)
                            } else {
                                UIApplication.shared.showMain()
                            }*/
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
