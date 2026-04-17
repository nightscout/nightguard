//
//  CarPlaySceneDelegate.swift
//  nightguard
//

import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        handleConnect(interfaceController: interfaceController)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) {
        handleConnect(interfaceController: interfaceController)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        handleDisconnect()
    }
    
    @objc private func updateCarPlayUI() {
        #if MAIN_APP
        AppLogger.singleton.debug("CarPlay: updateCarPlayUI")
        #endif
        guard let interfaceController = interfaceController else {
            #if MAIN_APP
            AppLogger.singleton.warning("CarPlay: interfaceController is nil in updateCarPlayUI")
            #endif
            return
        }
        let template = createRootTemplate()
        interfaceController.setRootTemplate(template, animated: false) { success, error in
            #if MAIN_APP
            AppLogger.singleton.debug("CarPlay: update setRootTemplate success=\(success), error=\(String(describing: error))")
            #endif
        }
    }

    private func createRootTemplate() -> CPTemplate {
        if PurchaseManager.shared.isProAccessAvailable {
            return createListTemplate()
        }
        return createProRequiredTemplate()
    }

    private func createListTemplate() -> CPListTemplate {
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        
        let bgValue = UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)
        let arrow = nightscoutData.bgdeltaArrow
        let delta = UnitsConverter.mgdlToDisplayUnitsWithSign(nightscoutData.bgdeltaString)
        let units = UserDefaultsRepository.units.value.description
        
        // Status row: treat as information, not an action
        let bgItem = CPListItem(text: "\(bgValue) \(units)", detailText: "Delta \(delta) \(units) | \(arrow)")
        
        let snoozeItem = CPListItem(text: NSLocalizedString("Snooze 30m", comment: ""), detailText: NSLocalizedString("Snooze all alarms for 30 minutes", comment: ""))
        snoozeItem.setImage(UIImage(systemName: "zzz"))
        snoozeItem.handler = { _, completion in
            AlarmRule.snooze(30)
            completion()
        }
        
        let statusSection = CPListSection(
            items: [bgItem],
            header: NSLocalizedString("Glucose", comment: "CarPlay status section header"),
            sectionIndexTitle: nil
        )
        
        let actionsSection = CPListSection(
            items: [snoozeItem],
            header: NSLocalizedString("Actions", comment: "CarPlay actions section header"),
            sectionIndexTitle: nil
        )
        
        let template = CPListTemplate(title: "Nightguard", sections: [statusSection, actionsSection])
        return template
    }

    private func createProRequiredTemplate() -> CPListTemplate {
        let title = NSLocalizedString("Pro required", comment: "CarPlay Pro required title")
        let detail = NSLocalizedString("CarPlay is available with a Pro subscription.", comment: "CarPlay Pro required detail")
        let item = CPListItem(text: title, detailText: detail)
        let section = CPListSection(items: [item])
        let template = CPListTemplate(title: "Nightguard", sections: [section])
        return template
    }

    private func handleConnect(interfaceController: CPInterfaceController) {
        #if MAIN_APP
        AppLogger.singleton.debug("CarPlay: didConnect")
        #endif
        self.interfaceController = interfaceController

        let template = createRootTemplate()
        interfaceController.setRootTemplate(template, animated: true) { success, error in
            #if MAIN_APP
            AppLogger.singleton.debug("CarPlay: setRootTemplate success=\(success), error=\(String(describing: error))")
            #endif
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateCarPlayUI), name: NSNotification.Name("NightscoutDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCarPlayUI), name: NSNotification.Name("ProAccessStatusChanged"), object: nil)
    }

    private func handleDisconnect() {
        self.interfaceController = nil
        NotificationCenter.default.removeObserver(self)
    }
}

