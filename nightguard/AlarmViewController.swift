//
//  AlarmViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/2/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class AlarmViewController: CustomFormViewController {
    
    var aboveSliderRow: SliderRow!
    var belowSliderRow: SliderRow!

    let noDataAlarmOptions = [15, 20, 25, 30, 35, 40, 45].map { "\($0) Minutes" }
    let lowPredictionAlarmOptions = [5, 10, 15, 20, 25, 30].map { "\($0) Minutes" }
    
    fileprivate let MAX_ALERT_ABOVE_VALUE : Float = 280
    fileprivate let MIN_ALERT_ABOVE_VALUE : Float = 80
    
    fileprivate let MAX_ALERT_BELOW_VALUE : Float = 200
    fileprivate let MIN_ALERT_BELOW_VALUE : Float = 50
    
    fileprivate let SNAP_INCREMENT : Float = 10 // or change it to 5?
    
    fileprivate var units = UserDefaultsRepository.units.value
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if units != UserDefaultsRepository.units.value {
            
            // reconstruct the form if units were changed from last appearance
            UIView.performWithoutAnimation {
                form.removeAll()
                constructForm()
            }
            
            units = UserDefaultsRepository.units.value
        } else {
            
            // refresh just the slider values
            updateSliderRowsFromUserDefaultsValues()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func constructForm() {
        
         aboveSliderRow = createSliderRow(initialValue: AlarmRule.alertIfAboveValue.value, minimumValue: MIN_ALERT_ABOVE_VALUE, maximumValue: MAX_ALERT_ABOVE_VALUE)
        aboveSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
        
        belowSliderRow = createSliderRow(initialValue: AlarmRule.alertIfBelowValue.value, minimumValue: MIN_ALERT_BELOW_VALUE, maximumValue: MAX_ALERT_BELOW_VALUE)
        belowSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
 
        
        form +++ Section(header: "High BG Alert", footer: "Alert when the blood glucose raises above this value.") <<< aboveSliderRow
        
        form +++ Section(header: "Low BG Alert", footer: "Alert when the blood glucose drops below this value.") <<< belowSliderRow
    }
    
    @objc func onSliderValueChanged(slider: UISlider, event: UIEvent) {
        guard let touchEvent = event.allTouches?.first else { return }
        
        // modify UserDefaultsValue ONLY when slider value change events ended
        switch touchEvent.phase {
        case .ended:
            if slider === aboveSliderRow.cell.slider {
                
                guard let value = aboveSliderRow.value else { return }
                let mgdlValue = UnitsConverter.toMgdl(value)
                
                guard mgdlValue > UserDefaultsRepository.lowerBound.value else {
                    alertInvalidChange(message: "High BG value should be above low BG value!")
                    updateSliderRowsFromUserDefaultsValues()
                    return
                }
                
                print("Changed above slider to \(mgdlValue) \(UserDefaultsRepository.units.value.description)")
                UserDefaultsRepository.upperBound.value = mgdlValue
                
            } else if slider === belowSliderRow.cell.slider {
                
                guard let value = belowSliderRow.value else { return }
                let mgdlValue = UnitsConverter.toMgdl(value)
                
                guard mgdlValue < UserDefaultsRepository.upperBound.value else {
                    alertInvalidChange(message: "Low BG value should be below high BG value!")
                    updateSliderRowsFromUserDefaultsValues()
                    return
                }

                print("Changed below slider to \(mgdlValue) \(UserDefaultsRepository.units.value.description)")
                UserDefaultsRepository.lowerBound.value = mgdlValue
            }
            
        default:
            break
        }
    }
    
    private func createSliderRow(initialValue: Float, minimumValue: Float, maximumValue: Float) -> SliderRow {
        
        return SliderRow() { row in
            row.value = Float(UnitsConverter.toDisplayUnits("\(initialValue)"))!
            }.cellSetup { [weak self] cell, row in
                guard let self = self else { return }
                //                    row.shouldHideValue = true
                
                let minimumValue = Float(UnitsConverter.toDisplayUnits("\(minimumValue)"))!
                let maximumValue = Float(UnitsConverter.toDisplayUnits("\(maximumValue)"))!
                let snapIncrement = (UserDefaultsRepository.units.value == .mgdl) ? self.SNAP_INCREMENT : 0.1
                
                let steps = (maximumValue - minimumValue) / snapIncrement
                row.steps = UInt(steps.rounded())
                cell.slider.minimumValue = minimumValue
                cell.slider.maximumValue = maximumValue
                cell.tintColor = UIColor.white
                row.displayValueFor = { value in
                    guard let value = value else { return "" }
                    let units = UserDefaultsRepository.units.value.description
                    return String("\(value.cleanValue) \(units)")
                }
                
                // fixed width for value label
                let widthConstraint = NSLayoutConstraint(item: cell.valueLabel, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 96)
                cell.valueLabel.addConstraints([widthConstraint])
        }
    }
    
    private func alertInvalidChange(message: String) {
        let alertController = UIAlertController(title: "Invalid change", message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }
    
    private func updateSliderRowsFromUserDefaultsValues() {
        aboveSliderRow.value = Float(UnitsConverter.toDisplayUnits("\(AlarmRule.alertIfAboveValue.value)"))!
        aboveSliderRow.updateCell()
        belowSliderRow.value = Float(UnitsConverter.toDisplayUnits("\(AlarmRule.alertIfBelowValue.value)"))!
        belowSliderRow.updateCell()
    }
}
