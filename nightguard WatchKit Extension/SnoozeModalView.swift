//
//  SnoozePopupView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 06.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import SwiftUI
import SpriteKit
import Combine

struct SnoozeModalView: View {
     @Environment(\.presentationMode) var presentationMode

    @Binding var isPresented: Bool
    
    var body: some View {
        ScrollView {
        VStack {
            Button("Stop Snoozing", action: {
                self.isPresented.toggle()
            })
            .background(Color.white)
            .foregroundColor(Color.black)
            HStack {
                Button("5min", action: {
                    
                })
                Button("10min", action: {
                    
                })
            }
            HStack {
                Button("15min", action: {
                    
                })
                Button("20min", action: {
                    
                })
            }
            Button("30min", action: {
                
            })
            Button("45min", action: {
                
            })
            Button("1h", action: {
                
            })
            Button("2h", action: {
                
            })
            Button("3h", action: {
                
            })
            Button("6h", action: {
                
            })
            Button("1d", action: {
                
            })
        }
        .focusable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
            presentationMode.wrappedValue.dismiss()
        }
        }}
}
