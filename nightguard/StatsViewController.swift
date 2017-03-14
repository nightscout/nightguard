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
    
    var chartScene = ChartScene(size: CGSize(width: 320, height: 280))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        chartSpriteKitView.autoresizingMask = [
            .FlexibleHeight,
            .FlexibleWidth]
    }
    
    override func viewWillAppear(animated: Bool) {

        paintSelectedDays()
    }
    
    override func viewDidAppear(animated: Bool) {
        
        // force the display into horizontal orientation
        let value = UIInterfaceOrientation.LandscapeRight.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
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
    
    private func setDayMonthYearTo01011971(bgValues : [BloodSugar]) -> [BloodSugar] {
        
        var normalizedBgValues : [BloodSugar] = []
        let calendar = NSCalendar.currentCalendar()
        let unitFlags: NSCalendarUnit = [.Hour, .Minute, .Second]
        
        for bgValue in bgValues {
            
            let time = NSDate(timeIntervalSince1970: bgValue.timestamp / 1000)
            let components = calendar.components(unitFlags, fromDate: time)
            components.setValue(1971, forComponent: .Year)
            let normalizedTimeWithYear1971 = calendar.dateFromComponents(components)
            
            normalizedBgValues.insert(
                BloodSugar.init(value: bgValue.value, timestamp: (normalizedTimeWithYear1971?.timeIntervalSince1970)! * 1000), atIndex: 0)
        }
        
        return normalizedBgValues
    }
    
    private func paintChart(days : [[BloodSugar]]) {
        
        dispatch_async(dispatch_get_main_queue(), {
            self.chartScene.paintChart(days, canvasWidth: self.chartSpriteKitView.bounds.width, maxYDisplayValue: 250)
        })
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Landscape
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    private func updateChartScene(size : CGSize) {
        // Initialize the ChartScene
        chartScene = ChartScene(size: size)
        let skView = chartSpriteKitView as! SKView
        skView.presentScene(chartScene)
        paintSelectedDays()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        updateChartScene(size)
    }
}
