//
//  CarPlaySceneDelegate.swift
//  nightguard
//

import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        print("CarPlay: didConnect")
        self.interfaceController = interfaceController
        
        let template = createListTemplate()
        interfaceController.setRootTemplate(template, animated: true) { success, error in
            print("CarPlay: setRootTemplate success=\(success), error=\(String(describing: error))")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateCarPlayUI), name: NSNotification.Name("NightscoutDataUpdated"), object: nil)
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateCarPlayUI() {
        print("CarPlay: updateCarPlayUI")
        guard let interfaceController = interfaceController else { 
            print("CarPlay: interfaceController is nil in updateCarPlayUI")
            return 
        }
        let template = createListTemplate()
        interfaceController.setRootTemplate(template, animated: false) { success, error in
            print("CarPlay: update setRootTemplate success=\(success), error=\(String(describing: error))")
        }
    }
    
    private func createListTemplate() -> CPListTemplate {
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        
        let bgValue = nightscoutData.sgv
        let arrow = nightscoutData.bgdeltaArrow
        let delta = nightscoutData.bgdelta
        
        let bgItem = CPListItem(text: "\(bgValue) \(arrow)", detailText: "\(delta) mg/dL")
        bgItem.setImage(UIImage(systemName: "drop.fill"))
        
        let snoozeItem = CPListItem(text: NSLocalizedString("Snooze 30m", comment: ""), detailText: NSLocalizedString("Snooze all alarms for 30 minutes", comment: ""))
        snoozeItem.setImage(UIImage(systemName: "zzz"))
        snoozeItem.handler = { _, completion in
            AlarmRule.snooze(30)
            completion()
        }
        
        let section = CPListSection(items: [bgItem, snoozeItem])
        let template = CPListTemplate(title: "Nightguard", sections: [section])
        return template
    }
}
