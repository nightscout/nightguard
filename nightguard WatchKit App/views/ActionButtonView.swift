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
                
            Button(action: {
                WKInterfaceDevice.current().play(.success)
                viewModel.cycleCrownMode()
            }) {
                VStack() {
                    Image(systemName: crownModeIcon)
                        .resizable()
                        .frame(width: getButtonSize(), height: getButtonSize())
                    Text(crownModeTitle)
                        .lineLimit(1)
                        .font(.system(size: 11))
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
                            .font(.system(size: 11))
                    }
                }
                .fullScreenCover(isPresented: self.$snoozeModalIsPresented, content: {
                    SnoozeModalView(
                        mainViewModel: viewModel,
                        isPresented: self.$snoozeModalIsPresented)
                })
            }
        })
        .focusable(false)
    }

    private var crownModeTitle: String {
        switch viewModel.crownMode {
        case .scroll:
            return NSLocalizedString("Crown Scrolls", comment: "Watch Action Button Menu")
        case .zoom:
            return NSLocalizedString("Crown Zooms", comment: "Watch Action Button Menu")
        case .select:
            return NSLocalizedString("Crown Selects", comment: "Watch Action Button Menu")
        }
    }

    private var crownModeIcon: String {
        switch viewModel.crownMode {
        case .scroll:
            return "arrow.left.and.right"
        case .zoom:
            return "plus.magnifyingglass"
        case .select:
            return "scope"
        }
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
