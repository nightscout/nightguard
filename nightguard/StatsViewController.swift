//
//  StatsViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 23.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class StatsViewController: UIViewController {
    
    @IBOutlet weak var chartImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        let value = UIInterfaceOrientation.LandscapeLeft.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
        
        NightscoutService.singleton.readLast4DaysChartData { (days : [[BloodSugar]]) in
            self.paintChart(days)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
         
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Landscape
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    private func paintChart(days : [[BloodSugar]]) {
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(chartImageView.frame.size.width),
            canvasHeight: Int(chartImageView.frame.size.height));
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        guard let chartImage = chartPainter.drawImage(
            UnitsConverter.toDisplayUnits(days),
            upperBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfAboveValue")),
            lowerBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfBelowValue"))
            ) else {
                return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.chartImageView.image = chartImage
        })
    }
}