//
//  AlarmSoundViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 30.05.21.
//  Copyright © 2021 private. All rights reserved.
//

import UIKit
import Eureka
import MobileCoreServices
import UniformTypeIdentifiers

class AlarmSoundViewController: CustomFormViewController, UIDocumentPickerDelegate {
    
    private var selectableSection: SelectableSection<ListCheckRow<Int>>!
    private var isPlaying = false
    
    override func constructForm() {
                
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
            
            <<< TextRow() { row in
                    row.tag = "alarmNameRow"
                    row.title = NSLocalizedString("Alarm Name", comment: "Title for Alarm Name")
                row.value = AlarmSound.customName.value
                    //row.baseCell.isUserInteractionEnabled = false
                }
        
            <<< ButtonRow() { row in
                }.cellUpdate { cell, row in
                    cell.textLabel?.text = NSLocalizedString("Pick Custom Alarm Sound", comment: "Button Pick Custom Alarm Sound")
                    cell.textLabel?.textColor = UIColor(netHex: 0x007AFF)  // default tint color - blue
                }.onCellSelection { cell, row in
                    if #available(iOS 14.0, *) {
                        let documentPickerController = UIDocumentPickerViewController(
                            forOpeningContentTypes: [.mp3, .wav])
                        documentPickerController.delegate = self
                        self.present(documentPickerController, animated: true, completion: nil)
                    }
                }
            
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
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        guard let customSoundUrl = urls.first else {
            return
        }
        
        // create a local copy
        let documentsDirectoryURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // lets create your destination file url
        let localUrl = documentsDirectoryURL.appendingPathComponent("customAlarmSound.mp3")
        
        do {
            try? FileManager.default.removeItem(at: localUrl)
            // Call this to get access to the icloud files:
            customSoundUrl.startAccessingSecurityScopedResource()
            try FileManager.default.copyItem(at: customSoundUrl, to: localUrl)
            
            AlarmSound.alarmSoundUri.value = localUrl.absoluteString
            if let filename = customSoundUrl.pathComponents.last {
                AlarmSound.customName.value = filename
                if let row : TextRow = form.rowBy(tag: "alarmNameRow") {
                    row.value = filename
                    row.updateCell()
                }
            }
        } catch (let writeError) {
             print("error writing file \(localUrl) : \(writeError)")
        }
    }
}
