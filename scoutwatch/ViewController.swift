//
//  ViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class ViewController: UIViewController, WCSessionDelegate {
    private let APP_GROUP_ID = "group.de.dhe.scoutwatch"
    
    @IBOutlet weak var hostUriTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let defaults = NSUserDefaults(suiteName: APP_GROUP_ID)
        let hostUri = defaults?.stringForKey("hostUri")
        hostUriTextField.text = hostUri
        
        // Init communication to apple watch
        if WCSession.isSupported() {
            
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func editingChangedAction(sender: AnyObject) {
        
        let defaults = NSUserDefaults(suiteName: APP_GROUP_ID)
        defaults!.setValue(hostUriTextField.text, forKey: "hostUri")
        
        sendToWatch(hostUriTextField.text!)
    }
    
    private func sendToWatch(hostUri : String) {
        do {
            let applicationDict = ["hostUri": hostUri]
            try WCSession.defaultSession().updateApplicationContext(applicationDict)
        }
            
        catch {
            print(error)
        }
    }
}

