//
//  BasicStatsPanelView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/10/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class BasicStatsPanelView: XibLoadedView {
    
    var model: BasicStats? {
        didSet {
            glucoseDistributionView.model = model
            a1cView.model = model
            readingsStatsView.model = model
            periodSelectorView.model = model
        }
    }
        
    @IBOutlet weak var glucoseDistributionView: GlucoseDistributionView!
    @IBOutlet weak var a1cView: A1cView!
    @IBOutlet weak var readingsStatsView: ReadingsStatsView!
    @IBOutlet weak var periodSelectorView: StatsPeriodSelectorView!
    
    override func commonInit() {
        super.commonInit()
        
        periodSelectorView.onPeriodChangeRequest = { period in
            self.model = BasicStats(period: period)
        }
        
        defer {
            self.model = BasicStats(period: .last24h)
        }
    }
    
    func updateModel() {
        self.model = BasicStats(period: self.model?.period ?? .last24h)
    }
}

