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

struct ActionButtonView: View {
    
    @State var snoozeModalIsPresented = false
    @Environment(\.presentationMode) var presentation
    
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel) {
        
        self.viewModel = mainViewModel
    }

    var body: some View {
        VStack(content: {
                
            if viewModel.crownScrolls {
                Button(action: {
                    WKInterfaceDevice.current().play(.success)
                    viewModel.toggleCrownScrolls()
                }) {
                    VStack() {
                        Image(systemName: "rectangle.portrait.arrowtriangle.2.outward")
                            .resizable()
                            .frame(width: getButtonSize(), height: getButtonSize())
                        Text(NSLocalizedString("Crown Scrolls", comment: "Watch Action Button Menu"))
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
                            .frame(width: getButtonSize(), height: getButtonSize())
                        Text(NSLocalizedString("Crown Zooms", comment: "Watch Action Button Menu"))
                            .lineLimit(1)
                            .font(.system(size: 10))
                    }
                }
            }
            if #available(watchOSApplicationExtension 7.0, *) {
                Button(action: {
                    self.snoozeModalIsPresented.toggle()
                }) {
                    VStack() {
                        Image(systemName: "moon.zzz")
                            .resizable()
                            .frame(width: getButtonSize(), height: getButtonSize())
                        Text(NSLocalizedString("Snooze", comment: "Watch Action Button Menu"))
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
    
// Function to determine button size based on the device screen size
func getButtonSize() -> CGFloat {
    let screenSize = WKInterfaceDevice.current().screenBounds.size
    if screenSize.width <= 136 { // 38mm or 40mm watch
        return 20
    } else { // 45mm or larger watch
        return 30
    }
}

struct ActionButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ActionButtonView(mainViewModel: MainViewModel())
    }
}
