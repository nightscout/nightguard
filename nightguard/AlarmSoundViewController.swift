//
//  AlarmSoundViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 30.05.21.
//  Copyright © 2021 private. All rights reserved.
//

import UIKit
import Eureka

class AlarmSoundViewController: CustomFormViewController {
    
    private var selectableSection: SelectableSection<ListCheckRow<Int>>!
    private var alarmSoundURLRow: URLRow!
    private var isPlaying = false
    
    override func constructForm() {
        
        alarmSoundURLRow = URLRow() { row in
                row.title = NSLocalizedString("URL", comment: "Title for URL")
                row.placeholder = "http://url.to/my/free/mp3/file.mp3"
                row.placeholderColor = UIColor.gray
                row.value = URL(string: UserDefaultsRepository.alarmSoundUri.value)
                //row.add(rule: alarmSoundURLRule)
                row.validationOptions = .validatesOnDemand
            }.onChange { [weak self] row in
                guard let urlString = row.value?.absoluteString, !urlString.isEmpty else { return }
                if let updatedUrlString = self?.addProtocolPartIfMissing(urlString), let updatedUrl = URL(string: updatedUrlString) {
                    row.value = updatedUrl
                    row.updateCell()
                }
            }.onCellHighlightChanged { [weak self] (cell, row) in
                if row.isHighlighted == false {
                    
                    // editing finished
//                    guard row.validate().isEmpty else { return }
                    guard let value = row.value else { return }
                    self?.alarmSoundURLChanged(value)
                }
            }.onRowValidationChanged { cell, row in
                
                guard let rowIndex = row.indexPath?.row else {
                    return
                }
                guard let section = row.section else {
                    return
                }
                while section.count > rowIndex + 1 && row.section?[rowIndex  + 1] is LabelRow {
                    section.remove(at: rowIndex + 1)
                }
                if !row.isValid {
                    for (index, validationMsg) in row.validationErrors.map({ $0.msg }).enumerated() {
                        let labelRow = LabelRow() {
                            let title = "❌ \(validationMsg)"
                            $0.title = title
                            $0.cellUpdate { cell, _ in
                                cell.textLabel?.textColor = UIColor.nightguardRed()
                            }
                            $0.cellSetup { cell, row in
                                cell.textLabel?.numberOfLines = 0
                            }
                            let rows = CGFloat(title.count / 50) + 1 // we condiser 80 characters are on a line
                            $0.cell.height = { 30 * rows }
                        }
                        let insertionRow = row.indexPath!.row + index + 1
                        row.section?.insert(labelRow, at: insertionRow)
                    }
                }
            }.cellUpdate{ cell, row in
                cell.textField.clearButtonMode = .whileEditing
                cell.textField.tintColor = .white
            }
                
        form +++ Section(header: "", footer: NSLocalizedString("If activated, a user defined alarm sound will be used.", comment: "Footer in Custom Alarm Sound settings"))
            <<< SwitchRow("CustomAlarmSoundSwitch") { row in
                row.title = NSLocalizedString("Custom Alarm Sound", comment: "Title in Custom Alarm Sound settings")
                row.value = AlarmSound.playCustomAlarmSound.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmSound.playCustomAlarmSound.value = value
            }
            
            +++ Section() { header in
                    header.hidden = "$CustomAlarmSoundSwitch == false"
                }
            <<< alarmSoundURLRow
        
            <<< ButtonRow() { row in
                }.cellUpdate { cell, row in
                    if self.isPlaying {
                        cell.textLabel?.text = NSLocalizedString("Stop Alert", comment: "Stop alert button")
                        cell.textLabel?.textColor = UIColor.nightguardRed()
                    } else {
                        cell.textLabel?.text = NSLocalizedString("Test Alert", comment: "Test alert button")
                        cell.textLabel?.textColor = UIColor(netHex: 0x007AFF)  // default tint color - blue
                    }
                }.onCellSelection { cell, row in
                    AlarmSound.isTesting = true
                    if self.isPlaying {
                        self.isPlaying = false
                        AlarmSound.stop()
                    } else {
                        self.isPlaying = true
                        AlarmSound.play()
                    }
                    
                    row.updateCell()
            }
    }
        
    private func alarmSoundURLChanged(_ url: URL) {
        
        AlarmSound.alarmSoundUri = url.absoluteString
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    private func addProtocolPartIfMissing(_ uri : String) -> String? {
        
        if (uri.contains("/") || uri.contains(".") || uri.contains(":"))
            && !uri.contains("http") {
            
            return "https://" + uri
        }
        
        return nil
    }
}
