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

@available(watchOSApplicationExtension 6.0, *)
struct SnoozeModalView: View {

    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    
    var body: some View {
        ScrollView {
        VStack {
            if (AlarmRule.isSnoozed()) {
                Button("Stop Snoozing", action: {
                    AlarmRule.disableSnooze()
                    self.isPresented.toggle()
                })
                .background(Color.white)
                .foregroundColor(Color.black)
            }
            HStack {
                Button("5min", action: {
                    AlarmRule.snooze(5)
                    self.isPresented.toggle()
                })
                Button("10min", action: {
                    AlarmRule.snooze(10)
                    self.isPresented.toggle()
                })
            }
            HStack {
                Button("15min", action: {
                    AlarmRule.snooze(15)
                    self.isPresented.toggle()
                })
                Button("20min", action: {
                    AlarmRule.snooze(20)
                    self.isPresented.toggle()
                })
            }
            Button("30min", action: {
                AlarmRule.snooze(30)
                self.isPresented.toggle()
            })
            Button("45min", action: {
                AlarmRule.snooze(45)
                self.isPresented.toggle()
            })
            Button("1h", action: {
                AlarmRule.snooze(60)
                self.isPresented.toggle()
            })
            Button("2h", action: {
                AlarmRule.snooze(120)
                self.isPresented.toggle()
            })
            Button("3h", action: {
                AlarmRule.snooze(180)
                self.isPresented.toggle()
            })
            Button("6h", action: {
                AlarmRule.snooze(6*60)
                self.isPresented.toggle()
            })
            Button("1d", action: {
                AlarmRule.snooze(24*60)
                self.isPresented.toggle()
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
