//
//  TemporaryTargetView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 11.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation
import SwiftUI
import SpriteKit
import Combine

@available(watchOSApplicationExtension 6.0, *)
struct TemporaryTargetView: View {
    
    @Environment(\.presentationMode) var presentation
    @State var temporaryTargetModalIsPresented = false
    @State var cancelTemporaryTargetModalIsPresented = false
    
    static var localizedTemporaryTargetReasons = [
        NSLocalizedString("Activity", comment: "TT Reason Picker Activity"),
        NSLocalizedString("Too High", comment: "TT Reason Picker Too High"),
        NSLocalizedString("Too Low", comment: "TT Reason Picker Too Low"),
        NSLocalizedString("Meal Soon", comment: "TT Reason Picker Meal Soon")]
    static var userDefaultsToTemporaryTargetReasons : Dictionary<String, String> = [
        "Activity": NSLocalizedString("Activity", comment: "TT Reason Picker Activity"),
        "Too High": NSLocalizedString("Too High", comment: "TT Reason Picker Too High"),
        "Too Low": NSLocalizedString("Too Low", comment: "TT Reason Picker Too Low"),
        "Meal Soon": NSLocalizedString("Meal Soon", comment: "TT Reason Picker Meal Soon")]

    @State var selectedLocalizedTemporaryTargetReason : String
    
    var temporaryTargetDurations = [30, 60, 90, 120, 180, 360]
    @State var selectedTemporaryTargetDuration : Int

    init() {
        _selectedLocalizedTemporaryTargetReason =
            State(initialValue: TemporaryTargetView.userDefaultsToTemporaryTargetReasons[
                            UserDefaultsRepository.temporaryTargetReason.value] ?? "")
        _selectedTemporaryTargetDuration =
            State(initialValue: UserDefaultsRepository.temporaryTargetDuration.value)
    }
    
    var body: some View {
        VStack(content: {
            HStack(content: {
                if #available(watchOSApplicationExtension 7.0, *) {
                    Picker(selection: self.$selectedLocalizedTemporaryTargetReason, label: Text(
                            NSLocalizedString("Reason", comment: "Label for the Temporary Target Reason"))) {
                        
                        ForEach(TemporaryTargetView.localizedTemporaryTargetReasons, id: \.self) { temporaryTargetReason in
                            Text(temporaryTargetReason)
                                .font(.system(size: 14))
                        }
                    }
                    .onChange(of: selectedLocalizedTemporaryTargetReason) { _ in
                        UserDefaultsRepository.temporaryTargetReason.value =
                            TemporaryTargetView.userDefaultsToTemporaryTargetReasons.key(
                                from: $selectedLocalizedTemporaryTargetReason.wrappedValue) ?? ""
                    }
                    .frame(height: 45)
                }
                if #available(watchOSApplicationExtension 7.0, *) {
                    Picker(selection: self.$selectedTemporaryTargetDuration, label: Text(
                            NSLocalizedString("Duration", comment: "Label for Temporary Target Duration"))) {
                        
                        ForEach(temporaryTargetDurations, id: \.self) { temporaryTargetDuration in
                            Text("\(temporaryTargetDuration)")
                        }
                    }
                    .onChange(of: selectedTemporaryTargetDuration) { _ in
                        UserDefaultsRepository.temporaryTargetDuration.value =
                            $selectedTemporaryTargetDuration.wrappedValue 
                    }
                    .frame(width: 50, height: 45)
                } else {
                    // Fallback on earlier versions
                }
            }).padding(.bottom, 5)
            
            if #available(watchOSApplicationExtension 7.0, *) {
                Button(action: {
                    
                    // Take care that all selected values are in sync with the userdefaultsrepository
                    UserDefaultsRepository.temporaryTargetReason.value =
                        TemporaryTargetView.userDefaultsToTemporaryTargetReasons.key(
                            from: $selectedLocalizedTemporaryTargetReason.wrappedValue) ?? ""
                    
                    UserDefaultsRepository.temporaryTargetDuration.value =
                        $selectedTemporaryTargetDuration.wrappedValue
                    
                    UserDefaultsRepository.temporaryTargetAmount.value =
                        UserDefaultsRepository.getDefaultTemporaryTargetAmountForReason()
                    self.temporaryTargetModalIsPresented.toggle()
                }) {
                    Text(NSLocalizedString("Set Target", comment: "Button to activate the Temporary Target"))
                }
                .fullScreenCover(isPresented: self.$temporaryTargetModalIsPresented, content: {
                    ActivateTemporaryTargetPopupView(isPresented: self.$temporaryTargetModalIsPresented)
                })
                Button(action: {
                    
                    self.cancelTemporaryTargetModalIsPresented.toggle()
                }) {
                    Text(NSLocalizedString("Delete Target", comment: "Watch-Button to delete a current Temporary Target"))
                }.fullScreenCover(isPresented: self.$cancelTemporaryTargetModalIsPresented, content: {
                    CancelTemporaryTargetPopupView(isPresented: self.$cancelTemporaryTargetModalIsPresented)
                })
            }
        })
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

@available(watchOSApplicationExtension 6.0, *)
struct TemporaryTargetView_Previews: PreviewProvider {
    static var previews: some View {
        TemporaryTargetView()
    }
}
