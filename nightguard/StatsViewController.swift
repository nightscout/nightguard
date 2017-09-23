//
//  StatsViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 23.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity
import SpriteKit

class StatsViewController: UIViewController {
    
    @IBOutlet weak var chartSpriteKitView: UIView!
    
    var chartScene = ChartScene(size: CGSize(width: 320, height: 280), newCanvasWidth: 1024)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        chartSpriteKitView.autoresizingMask = [
//            .FlexibleHeight,
//            .FlexibleWidth]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateChartScene(CGSize(width: chartSpriteKitView.bounds.width, height: chartSpriteKitView.bounds.height))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // force the display into horizontal orientation
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        
        chartScene.size = CGSize(width: chartSpriteKitView.bounds.width, height: chartSpriteKitView.bounds.height)
        
        paintSelectedDays()
    }
    
    func paintSelectedDays() {
        
        let daysToBeDisplayed = UserDefaultsRepository.readDaysToBeDisplayed()
        
        var i : Int = 0
        var filteredDays : [[BloodSugar]] = []
        
        for dayToBeDisplayed in daysToBeDisplayed {
            
            if dayToBeDisplayed {
                if let day = StatisticsRepository.singleton.readDay(i) {
                    filteredDays.append(day)
                } else {
                    NightscoutService.singleton.readDay(i, callbackHandler: {(nrOfDay, bgValues) -> Void in
                        
                        // store all values for an identical day/month/year
                        // so that all values are displayed in an overlay mode
                        let normalizedBgValues = self.setDayMonthYearTo01011971(bgValues)
                        StatisticsRepository.singleton.saveDay(nrOfDay, bloodSugarArray: normalizedBgValues)
                        self.paintSelectedDays()
                    })

                    filteredDays.append([])
                }
            } else {
                filteredDays.append([])
            }
            i = i + 1
        }
        
        paintChart(filteredDays)
    }
    
    fileprivate func paintChart(_ days : [[BloodSugar]]) {
        
        DispatchQueue.main.async {
            self.chartScene.paintChart(days,
                    newCanvasWidth: min(self.maximumDeviceTextureWidth(),
                    self.chartSpriteKitView.bounds.width),
                    maxYDisplayValue: 300,
                    moveToLatestValue: false)
        }
    }
    
    fileprivate func setDayMonthYearTo01011971(_ bgValues : [BloodSugar]) -> [BloodSugar] {
        
        var normalizedBgValues : [BloodSugar] = []
        let calendar = Calendar.current
        
        for bgValue in bgValues {
            
            let time = Date(timeIntervalSince1970: bgValue.timestamp / 1000)
            var components = calendar.dateComponents([.hour, .minute, .second], from: time)
            components.setValue(1971, for: .year)
            let normalizedTimeWithYear1971 = calendar.date(from: components)
            
            normalizedBgValues.insert(
                BloodSugar.init(value: bgValue.value, timestamp: (normalizedTimeWithYear1971?.timeIntervalSince1970)! * 1000), at: 0)
        }
        
        return normalizedBgValues
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.landscape
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    fileprivate func updateChartScene(_ size : CGSize) {
        
        if chartSpriteKitView != nil {
            // Initialize the ChartScene
            chartScene = ChartScene(size: size, newCanvasWidth: min(self.maximumDeviceTextureWidth(), size.width))
            let skView = chartSpriteKitView as! SKView
            skView.presentScene(chartScene)
            paintSelectedDays()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        updateChartScene(size)
    }
}
