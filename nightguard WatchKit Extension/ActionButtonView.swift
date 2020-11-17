//
//  ContentView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 08.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import SwiftUI
import SpriteKit
import Combine

@available(watchOSApplicationExtension 6.0, *)
struct ActionButtonView: View {
    
    @State var snoozeModalIsPresented = false
    @Environment(\.presentationMode) var presentation
    
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel) {
        
        self.viewModel = mainViewModel
    }

    var body: some View {
        VStack(content: {
            HStack(spacing: 5, content: {
                
                if viewModel.crownScrolls {
                    Button(action: {
                        WKInterfaceDevice.current().play(.success)
                        viewModel.toggleCrownScrolls()
                    }) {
                        VStack() {
                            Image(systemName: "rectangle.portrait.arrowtriangle.2.outward")
                                .resizable()
                                .frame(width: 30, height:30)
                            Text("Crown Scrolls")
                                .lineLimit(1)
                                .font(.system(size: 10))
                        }
                    }
                } else {
                    Button(action: {
                        WKInterfaceDevice.current().play(.success)
                        viewModel.toggleCrownScrolls()
                    }) {
                        VStack() {
                            Image(systemName: "plus.magnifyingglass")
                                .resizable()
                                .frame(width: 30, height:30)
                            Text("Crown Zooms")
                                .lineLimit(1)
                                .font(.system(size: 10))
                        }
                    }
                }
                Button(action: {
                    WKInterfaceDevice.current().play(.success)
                    viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
                }) {
                    VStack() {
                        Image(systemName: "arrow.clockwise")
                            .resizable()
                            .frame(width: 30, height:30)
                        Text("Aktualisieren")
                            .lineLimit(1)
                            .font(.system(size: 10))
                    }
                }
            })
            if #available(watchOSApplicationExtension 7.0, *) {
                Button(action: {
                    self.snoozeModalIsPresented.toggle()
                }) {
                    VStack() {
                        Image(systemName: "moon.zzz")
                            .resizable()
                            .frame(width: 30, height:30)
                        Text("Snooze")
                            .font(.system(size: 10))
                    }
                }
                .fullScreenCover(isPresented: self.$snoozeModalIsPresented, content: {
                    SnoozeModalView(
                        mainViewModel: viewModel,
                        isPresented: self.$snoozeModalIsPresented)
                })
            }
            Spacer()
        })
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .focusable(false)
    }
}

@available(watchOSApplicationExtension 6.0, *)
struct ActionButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ActionButtonView(mainViewModel: MainViewModel())
    }
}
