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
struct MainView: View {
    
    @State var crownValue = 0.0
    @State var oldCrownValue = 0.0
    
    // update the ui every 15 seconds:
    let timer = Timer.publish(every: 15, on: .current, in: .common).autoconnect()
    
    @ObservedObject var viewModel: MainViewModel
    
    init(mainViewModel: MainViewModel) {
        
        self.viewModel = mainViewModel
        
        updateUnits()
        viewModel.refreshData(forceRefresh: true, moveToLatestValue: true)
   }

    fileprivate func scrollChart() {
        if abs(oldCrownValue - crownValue) > 1000 {
            // the counter jumped from 0 to 1000 (or vice versa). Ignore this
            oldCrownValue = crownValue
            return
        }
        viewModel.skScene.moveChart(-1 * (oldCrownValue - crownValue))
        self.oldCrownValue = crownValue
    }
    
    fileprivate func zoomChart() {
        let rotationDelta = oldCrownValue - crownValue
        if abs(rotationDelta) > 1000 {
            // the counter jumped from 0 to 1000 (or vice versa). Ignore this
            oldCrownValue = crownValue
            return
        }
        self.oldCrownValue = crownValue
        viewModel.skScene.scale(1 + CGFloat(-1 * rotationDelta / 500), keepScale: true)
    }
    
    var body: some View {
        // TimelineView(EveryMinuteTimelineSchedule()) { context in
            VStack() {
                HStack(spacing: 5, content: {
                    Text(UnitsConverter.mgdlToDisplayUnits(
                            viewModel.nightscoutData?.sgv ?? "---"))
                        .foregroundColor(viewModel.sgvColor)
                        .font(.system(size: 50))
                        .scaledToFill()
                        .minimumScaleFactor(0.5)
                        .frame(height: 55, alignment: .topLeading)
                    VStack(alignment: .leading, content: {
                        Text(viewModel.nightscoutData?.bgdeltaString ?? "?")
                            .foregroundColor(viewModel.sgvDeltaColor)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Text(viewModel.nightscoutData?.bgdeltaArrow ?? "-")
                            .foregroundColor(viewModel.arrowColor)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Text(viewModel.nightscoutData?.timeString ?? "-")
                            .foregroundColor(viewModel.timeColor)
                            .font(.system(size: 12))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    })
                    ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center), content: {
                        if #available(watchOSApplicationExtension 7.0, *) {
                            if (viewModel.active == true) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 5, height: 5)
                            } else {
                                VStack(alignment: .trailing, spacing: nil, content: {
                                    HStack(){
                                        Text(viewModel.nightscoutData?.cob ?? "")
                                            .font(.system(size: 12))
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                        Text(viewModel.nightscoutData?.iob ?? "-")
                                            .font(.system(size: 12))
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                    }
                                    Text(viewModel.reservoir)
                                        .font(.system(size: 12))
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                    HStack(){
                                        Text(viewModel.nightscoutData?.battery ?? "-")
                                            .font(.system(size: 12))
                                            .foregroundColor(viewModel.uploaderBatteryColor)
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                    }
                                }).frame(minWidth: 0,
                                         maxWidth: .infinity,
                                         alignment: .bottomTrailing)
                            }
                        }
                    }).frame(maxWidth: .infinity)
                }).frame(minWidth: 0,
                         maxWidth: .infinity,
                         alignment: .topLeading)
                if viewModel.showCareAndLoopData {
                    HStack() {
                        Text(viewModel.cannulaAgeString ?? "?d ?h")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.cannulaAgeColor)
                            .frame(maxWidth: .infinity,
                                   alignment: .leading)
                        Text(viewModel.sensorAgeString ?? "?d ?h")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.sensorAgeColor)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                        Text(viewModel.batteryAgeString ?? "?d ?h")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.batteryAgeColor)
                            .frame(maxWidth: .infinity,
                                   alignment: .trailing)
                    }.frame(minWidth: 0,
                            maxWidth: .infinity)
                    HStack(spacing: 5) {
                        Text(viewModel.activeProfile)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .frame(idealWidth: 100, maxWidth: .infinity, alignment: .leading)
                        Text(viewModel.temporaryBasal)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .frame(idealWidth: 100, maxWidth: .infinity)
                        Text(viewModel.temporaryTarget)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 10))
                            .frame(idealWidth: 100, maxWidth: .infinity, alignment: .trailing)
                    }.frame(minWidth: 0,
                            maxWidth: .infinity)
                }
                VStack() {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom), content: {
                        if #available(watchOSApplicationExtension 7.0, *) {
                            SpriteView(scene: viewModel.skScene)
                                .focusable(true)
                                .digitalCrownRotation($crownValue, from: 0, through: 10000, by: 15, sensitivity: .high, isContinuous: true, isHapticFeedbackEnabled: true)
                                .onReceive(Just(crownValue)) { output in
                                    if viewModel.crownScrolls {
                                        scrollChart()
                                    } else {
                                        zoomChart()
                                    }
                                }
                        }
                        VStack() {
                            Text(viewModel.alarmRuleMessage)
                                .padding(15)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(
                                    Color(UIColor.nightguardRed()))
                        }
                    })
                }.frame(minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.bottom)
            .onAppear() {
                viewModel.refreshData(forceRefresh: false, moveToLatestValue: true)
                
                // Request Data from the main app
                // especially the baseUri if missing
                WatchSyncRequestMessage().send()
            }
            .onReceive(timer) { _ in
                viewModel.refreshData(forceRefresh: false, moveToLatestValue: false)
            }
        //}
    }
    
    fileprivate func updateUnits() {
        NightscoutService.singleton.readStatus { (result: NightscoutRequestResult<Units>) in
            
            switch result {
            case .data(let units):
                UserDefaultsRepository.units.value = units
            case .error(_):
                print("Unable to determine units on the watch. Using the synced values from the ios app.")
            }
        }
    }
}

@available(watchOSApplicationExtension 6.0.0, *)
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(mainViewModel: MainViewModel())
    }
}
