//
//  BackgroundUrlSession.swift
//  nightguard
//
//  Created by Dirk Hermanns on 04.12.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation

class BackgroundUrlSessionWrapper {
    
    public static var urlSession : URLSession = URLSession.init()
    
    public static let singleton = BackgroundUrlSessionWrapper()
    
    private static let setup = SingletonSetupHelper()
    
    class func setup(delegate : URLSessionDelegate) {
        BackgroundUrlSessionWrapper.setup.delegate = delegate
    }
    
    private init() {
        
        let delegate = BackgroundUrlSessionWrapper.setup.delegate
        guard delegate != nil else {
            fatalError("Error - you must call setup before accessing BackgroundUrlSession.singleton")
        }
        
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "com.evans.pf.nightguard")
        BackgroundUrlSessionWrapper.urlSession = URLSession.init(configuration: backgroundConfiguration, delegate: delegate, delegateQueue: nil)
    }
}

private class SingletonSetupHelper {
    var delegate : URLSessionDelegate?
}
