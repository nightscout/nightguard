//
//  BackgroundUrlSession.swift
//  nightguard
//
//  Created by Dirk Hermanns on 04.12.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation

class BackgroundUrlSessionWrapper {
    
    private static var optionalUrlSession : URLSession? = nil
    public var urlSession : URLSession!
    
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
        
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "de.my-wan.dhe.nightguard")
        urlSession = URLSession.init(configuration: backgroundConfiguration, delegate: delegate, delegateQueue: nil)
    }
    
    func start(_ request: URLRequest) {
         urlSession.downloadTask(with: request).resume()
    }
}

private class SingletonSetupHelper {
    var delegate : URLSessionDelegate?
}
