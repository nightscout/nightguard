//
//  UIViewController+Extensions.swift
//  nightguard
//
//  Created by Florian Preknya on 2/11/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func showAlert(title: String, message: String, showOnceKey: String? = nil, okHandler: (() -> Void)? = nil) {
        
        if let showOnceKey = showOnceKey {
            guard !UserDefaults.standard.bool(forKey: showOnceKey) else {
                return
            }
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default, handler: { _ in okHandler?() })
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
        
        if let showOnceKey = showOnceKey {
            UserDefaults.standard.set(true, forKey: showOnceKey)
        }
    }
    
    func showYesNoAlert(title: String, message: String, showOnceKey: String? = nil, yesHandler: (() -> Void)? = nil, noHandler: (() -> Void)? = nil) {
        
        if let showOnceKey = showOnceKey {
            guard !UserDefaults.standard.bool(forKey: showOnceKey) else {
                return
            }
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionYes = UIAlertAction(title: "Yes", style: .default, handler: { _ in yesHandler?() })
        alertController.addAction(actionYes)
        let actionNo = UIAlertAction(title: "No", style: .default, handler: { _ in noHandler?() })
        alertController.addAction(actionNo)
        present(alertController, animated: true, completion: nil)
        
        if let showOnceKey = showOnceKey {
            UserDefaults.standard.set(true, forKey: showOnceKey)
        }
    }

}

// snoozing capability from any controller
extension UIViewController {
    
    func showSnoozePopup() {
        
        // stop the alarm immediatly here not to disturb others
        AlarmSound.muteVolume()
        
        // create the snooze popup view
        let snoozeAlarmNavigationController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(
            withIdentifier: "snoozeAlarmNavigationController")
        self.present(snoozeAlarmNavigationController, animated: true, completion: nil)
        
        // For safety reasons: Unmute sound after 1 minute
        // This prevents an unlimited snooze if the snooze button was touched accidentally.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: {
            AlarmSound.unmuteVolume()
        })
    }
    
    func handleQuickSnooze(option: QuickSnoozeOption) {
        switch option {
        case .doNothing:
            break
        case .showSnoozePopup:
            showSnoozePopup()
        case .snoozeOneMinute:
            AlarmRule.snooze(1)
        case .snoozeFiveMinutes:
            AlarmRule.snooze(5)
        case .snoozeTenMinutes:
            AlarmRule.snooze(10)
        }
    }
}
