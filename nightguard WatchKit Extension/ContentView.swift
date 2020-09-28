//
//  ContentView.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 08.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    
    var bgLabel: String = "---"
    var deltaLabel: String = "-"
    var deltaArrowLabel: String = "-"
    var timeLabel: String = "0min"
    var reservoirLabel: String = "0U"
    var batteryLabel: String = "100%"
    var cobLabel: String = "0g"
    var iobLabel: String = "1U"
    var errorLabel: String = ""
    
    var rawbgLabel: String = ""
    var noiseLabel: String = ""
    
    var cannulaAgeLabel: String = "0d 0h"
    var sensorAgeLabel: String = "0d 0h"
    var batteryAgeLabel: String = "0d 0h"
    
    var activeProfileLabel: String = "---"
    var temporaryBasalLabel: String = "--"
    var temporaryTargetLabel: String = "--"
    
    let chartScene: SKScene
    
    init() {
        
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
        
        chartScene = ChartScene(size: CGSize(width: screenBounds.width, height: sceneHeight),
                                newCanvasWidth: screenBounds.width * 6, useContrastfulColors: false)
    }

    var body: some View {
        VStack() {
            HStack(alignment: .bottom, spacing: 10, content: {
                VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
                    Text(bgLabel)
                        .font(.system(size: 46))
                })
                VStack() {
                    Text(deltaLabel)
                        .font(.system(size: 12))
                    Text(deltaArrowLabel)
                        .font(.system(size: 12))
                    Text(timeLabel)
                        .font(.system(size: 12))
                }
                VStack() {
                    HStack(){
                        Text(cobLabel)
                        Text(iobLabel)
                    }
                    Text(batteryLabel)
                }.frame(minWidth: 0,
                         maxWidth: .infinity,
                         alignment: .bottomTrailing)
            }).frame(minWidth: 0,
                     maxWidth: .infinity,
                     alignment: .topLeading)
            HStack() {
                Text(cannulaAgeLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .leading)
                Text(sensorAgeLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                Text(reservoirLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                Text(batteryAgeLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .trailing)
            }.frame(minWidth: 0,
                    maxWidth: .infinity)
            HStack() {
                Text(activeProfileLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .leading)
                Text(temporaryBasalLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                Text(temporaryTargetLabel)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity,
                           alignment: .trailing)
            }.frame(minWidth: 0,
                    maxWidth: .infinity)
            VStack() {
                SpriteView(scene: chartScene)
            }.frame(minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
