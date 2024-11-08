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
    
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel, isPresented: Binding<Bool>) {
        
        self.viewModel = mainViewModel
        self._isPresented = isPresented
    }

    var body: some View {
        ScrollView {
        VStack {
            if (AlarmRule.isSnoozed()) {
                Button(NSLocalizedString("Stop Snoozing", comment: "Snooze Menu Popup Button Text"), action: {
                    WKInterfaceDevice.current().play(.success)
                    AlarmRule.disableSnooze()
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                .background(Color.white)
                .foregroundColor(Color.black)
                .cornerRadius(25)
            }
            HStack {
                Button(NSLocalizedString("5min", comment: "Snooze Menu Popup Button 5min"), action: {
                    WKInterfaceDevice.current().play(.success)
                    AlarmRule.snooze(5)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                Button(NSLocalizedString("10min", comment: "Snooze Menu Popup Button 10min"), action: {
                    WKInterfaceDevice.current().play(.success)
                    AlarmRule.snooze(10)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
            }
            HStack {
                Button(NSLocalizedString("15min", comment: "Snooze Menu Popup Button 15min"), action: {
                    WKInterfaceDevice.current().play(.success)
                    AlarmRule.snooze(15)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
                Button(NSLocalizedString("20min", comment: "Snooze Menu Popup Button 20min"), action: {
                    WKInterfaceDevice.current().play(.success)
                    AlarmRule.snooze(20)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                    self.isPresented.toggle()
                })
            }
            Button(NSLocalizedString("30min", comment: "Snooze Menu Popup Button 30min"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(30)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("45min", comment: "Snooze Menu Popup Button 45min"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(45)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("1h", comment: "Snooze Menu Popup Button 1h"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(60)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("2h", comment: "Snooze Menu Popup Button 2h"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(120)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("3h", comment: "Snooze Menu Popup Button 3h"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(180)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("6h", comment: "Snooze Menu Popup Button 6h"), action: {
                WKInterfaceDevice.current().play(.success)
                AlarmRule.snooze(6*60)
                viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                self.isPresented.toggle()
            })
            Button(NSLocalizedString("1d", comment: "Snooze Menu Popup Button 1d"), action: {
                WKInterfaceDevice.current().play(.success)
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
