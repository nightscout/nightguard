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
struct CarbsView: View {
    
    @Environment(\.presentationMode) var presentation
    @State var carbsModalIsPresented = false

    var carbs = ["1g", "2g", "3g", "4g", "5g", "6g", "7g", "8g", "9g", "10g", "15g", "20g", "25g", "30g", "35g", "40g", "45g", "50g", "55g", "60g", "65g", "70g", "75g", "80g", "85g", "90g", "95g", "100g"]
    @State var selectedCarbs : String

    init() {
        _selectedCarbs =
            State(initialValue: String(describing: UserDefaultsRepository.carbs.value))
    }
    
    var body: some View {
        VStack(content: {
            HStack(content: {
                if #available(watchOSApplicationExtension 7.0, *) {
                    Picker(selection: self.$selectedCarbs, label: Text(
                            NSLocalizedString("Enter consumed Carbs", comment: "Section to enter Carbs"))) {
                        
                        ForEach(carbs, id: \.self) { carbs in
                            Text(carbs)
                                .font(.system(size: 14))
                        }
                    }
                    .onChange(of: selectedCarbs) { _ in
                        UserDefaultsRepository.carbs.value =
                            convertCarbsToInt(carbsString: selectedCarbs)
                    }
                    .frame(height: 50)
                }
            }).padding(.bottom, 10)
            
            if #available(watchOSApplicationExtension 7.0, *) {
                Button(action: {
                    
                    self.carbsModalIsPresented.toggle()
                }) {
                    Text(NSLocalizedString("Add Carbs", comment: "Button to add consumed Carbs"))
                }.fullScreenCover(isPresented: self.$carbsModalIsPresented, content: {
                    AddCarbsPopupView(isPresented: self.$carbsModalIsPresented)
                })
            }
        })
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .focusable(false)
    }
    
    fileprivate func convertCarbsToInt(carbsString : String) -> Int {
        return Int(carbsString.removing(charactersOf: "g")) ?? 5
    }
}

@available(watchOSApplicationExtension 6.0, *)
struct CarbsView_Previews: PreviewProvider {
    static var previews: some View {
        CarbsView()
    }
}
