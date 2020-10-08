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
struct ContentView: View {
    
    @State var crownValue = 0.1
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel) {
        
        self.viewModel = mainViewModel
        
        // Apple Watch 38mm
        var sceneHeight : CGFloat = 125.0
        
        let screenBounds = WKInterfaceDevice.current().screenBounds
        if (screenBounds.height >= 224.0) {
            // Apple Watch 44mm
            sceneHeight = 165.0
        }
        if (screenBounds.height >= 195.0) {
            // Apple Watch 42mm
            sceneHeight = 145.0
        }
   }

    var body: some View {
        VStack() {
            HStack(spacing: 5, content: {
                Text(UnitsConverter.mgdlToDisplayUnits(
                        viewModel.nightscoutData?.sgv ?? "---"))
                    .foregroundColor(viewModel.sgvColor)
                    .font(.system(size: 40))
                    .frame(alignment: .topLeading)
                VStack() {
                    Text(UnitsConverter.mgdlToDisplayUnits(
                            viewModel.nightscoutData?.bgdeltaString ?? "?"))
                        .foregroundColor(viewModel.sgvDeltaColor)
                        .font(.system(size: 12))
                    Text(viewModel.nightscoutData?.bgdeltaArrow ?? "-")
                        .foregroundColor(viewModel.arrowColor)
                        .font(.system(size: 12))
                    Text(viewModel.nightscoutData?.timeString ?? "-")
                        .foregroundColor(viewModel.timeColor)
                        .font(.system(size: 12))
                }
                VStack(alignment: .trailing, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
                    HStack(){
                        Text(viewModel.nightscoutData?.cob ?? "")
                            .font(.system(size: 12))
                        Text(viewModel.nightscoutData?.iob ?? "-")
                            .font(.system(size: 12))
                    }
                    Text(viewModel.nightscoutData?.battery ?? "-")
                        .font(.system(size: 12))
                }).frame(minWidth: 0,
                         maxWidth: .infinity,
                         alignment: .bottomTrailing)
            }).frame(minWidth: 0,
                     maxWidth: .infinity,
                     alignment: .topLeading)
            HStack() {
                Text(viewModel.cannulaAge ?? "?d ?h")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .leading)
                Text(viewModel.sensorAge ?? "?d ?h")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                Text(viewModel.reservoir)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                Text(viewModel.batteryAge ?? "?d ?h")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .trailing)
            }.frame(minWidth: 0,
                    maxWidth: .infinity)
            HStack(spacing: 5) {
                Text(viewModel.activeProfile)
                    .lineLimit(1)
                    .font(.system(size: 10))
                    .frame(idealWidth: 100, maxWidth: .infinity, alignment: .leading)
                Text(viewModel.temporaryBasal)
                    .lineLimit(1)
                    .font(.system(size: 10))
                    .frame(idealWidth: 100, maxWidth: .infinity)
                Text(viewModel.temporaryTarget)
                    .font(.system(size: 10))
                    .frame(idealWidth: 100, maxWidth: .infinity, alignment: .trailing)
            }.frame(minWidth: 0,
                    maxWidth: .infinity)
            VStack() {
                if #available(watchOSApplicationExtension 7.0, *) {
                    SpriteView(scene: viewModel.skScene!)
                } else {
                    // Fallback on earlier versions
                }
            }.frame(minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.bottom)
        .focusable(false)
        .digitalCrownRotation($crownValue, from: 0.1, through: 5.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
          .onAppear() {

          }.onReceive(Just(crownValue)) { output in
              print(output) // Here is the answer.
          }
    }
}

@available(watchOSApplicationExtension 6.0.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(mainViewModel: MainViewModel())
    }
}
