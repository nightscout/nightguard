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
    
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel, isPresented: Binding<Bool>) {
        
        self.viewModel = mainViewModel
        self._isPresented = isPresented
    }

    var body: some View {
        ScrollView {
        VStack {
            if (AlarmRule.isSnoozed()) {
                Button("Stop Snoozing", action: {
                    AlarmRule.disableSnooze()
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                .background(Color.white)
                .foregroundColor(Color.black)
            }
            HStack {
                Button("5min", action: {
                    AlarmRule.snooze(5)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                Button("10min", action: {
                    AlarmRule.snooze(10)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
            }
            HStack {
                Button("15min", action: {
                    AlarmRule.snooze(15)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                Button("20min", action: {
                    AlarmRule.snooze(20)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
            }
            Button("30min", action: {
                AlarmRule.snooze(30)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("45min", action: {
                AlarmRule.snooze(45)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("1h", action: {
                AlarmRule.snooze(60)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("2h", action: {
                AlarmRule.snooze(120)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("3h", action: {
                AlarmRule.snooze(180)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("6h", action: {
                AlarmRule.snooze(6*60)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button("1d", action: {
                AlarmRule.snooze(24*60)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
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
