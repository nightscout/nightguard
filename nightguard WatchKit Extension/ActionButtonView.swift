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
    
    @State private var snoozeModalIsPresented = false
    
    init() {}

    var body: some View {
        VStack() {
            HStack(spacing: 5, content: {
                if #available(watchOSApplicationExtension 7.0, *) {
                    Button("Snooze", action: {
                        self.snoozeModalIsPresented.toggle()
                    }).fullScreenCover(isPresented: self.$snoozeModalIsPresented, content: {
                                        SnoozeModalView(isPresented: self.$snoozeModalIsPresented)
                    })
                }
                Button("Aktualisieren", action: {
                    print("Button")
                })
            })
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.bottom)
        .focusable(false)
    }
}

struct ActionButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(mainViewModel: MainViewModel())
    }
}
