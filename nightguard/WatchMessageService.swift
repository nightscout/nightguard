//
//  WatchMessageService.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import WatchConnectivity

/// Service for sending/receiving watch messages in an easy way from both the phone or watch. Sending can be one way or a request/response, and receiving supose registering the types of message handlers for the type of messages that are waited on that device. Type-safe messages, of course!
class WatchMessageService: NSObject {
    
    static let singleton = WatchMessageService()
    
    // send a message to paired device
    func send(message: WatchMessage, replyHandler: (([String : Any]) -> Void)? = nil) {
        var dictionary = message.dictionary
        dictionary["_type"] = String(describing: type(of: message))
        sendOrTransmit(dictionary, replyHandler: replyHandler)
    }
    
    // send a request to paired device (and receive a response)
    func send<T: WatchMessage>(request: WatchMessage, responseHandler: @escaping (T) -> Void) {
        send(message: request) { dictionary in
            guard let responseType = dictionary["_type"] as? String, responseType == String(describing: type(of: T.self)) else {
                print("Wrong response type")
                return
            }
            
            if let response = T(dictionary: dictionary) {
                responseHandler(response)
            }
        }
    }
    
    // define a message handler for a given type of message (code to execute when that message is received on current device)
    func onMessage<T: WatchMessage>(handler: @escaping (T) -> Void) {
        self.messageHandlers.append(
            WatchMessageHandlerImpl<T>(handler: handler)
        )
    }
    
    // define a request handler: for a given type of request, respond with a response message
    func onRequest<T: WatchMessage>(handler: @escaping (T) -> WatchMessage?) {
        self.requestHandlers.append(
            WatchRequestHandlerImpl<T>(handler: handler)
        )
    }
    
    private override init() {
        super.init()
    }
    
    private func received(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        
        if let replyHandler = replyHandler {
            for requestHandler in requestHandlers {
                let (handled, responseMessage) = requestHandler.handle(dictionary: message)
                if handled {
                    if let responseMessage = responseMessage {
                        var dictionary = responseMessage.dictionary
                        dictionary["_type"] = String(describing: type(of: responseMessage))
                        replyHandler(dictionary)
                    }
                    return
                }
            }
        }
        
        // iterate through the message handlers until one of them handles it
        let _ = messageHandlers.firstIndex(where: { $0.handle(dictionary: message) })
    }
    
    private func sendOrTransmit(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        
        guard WCSession.isSupported() else {
            
            // no paired device!
            return
        }
        
        if #available(iOS 9.3, watchOSApplicationExtension 2.2, *) {
            guard WCSession.default.activationState == .activated else {
                
                // paired device is not active, cannot continue!
                return
            }
        }
        
        // send message if paired device is reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
                print(error)
                
                // transmit message on failure
                try? WCSession.default.updateApplicationContext(message)
            })
        } else {
            
            // otherwise, transmit application context
            try? WCSession.default.updateApplicationContext(message)
        }
    }
    
    private var messageHandlers: [WatchMessageHandler] = []
    private var requestHandlers: [WatchRequestHandler] = []
}

extension WatchMessageService: WCSessionDelegate {
    
    // This method gets called when the watch requests the baseUri from the Nightscout Backend
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message (with reply handler): \(message)")
        received(message, replyHandler: replyHandler)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message: \(message)")
        received(message)
    }
    
    @available(watchOSApplicationExtension 2.2, *)
//    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//        #if os(watchOS)
        received(session.receivedApplicationContext)
//        #endif
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        received(applicationContext)
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        received(userInfo)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    #endif
}


private protocol WatchMessageHandler {
    func handle(dictionary: [String : Any]) -> Bool
}

private class WatchMessageHandlerImpl<T: WatchMessage>: WatchMessageHandler {
    
    typealias WatchMessageType = T
    typealias HandlerType = (WatchMessageType) -> Void
    let handler: HandlerType
    
    init(handler: @escaping HandlerType) {
        self.handler = handler
        print(String(describing: WatchMessageType.self))
    }
    
    func handle(dictionary: [String : Any]) -> Bool {
        
        guard let type = dictionary["_type"] as? String, type == String(describing: WatchMessageType.self) else {
            
            // message not recognized!
            return false
        }
        
        if let message = WatchMessageType(dictionary: dictionary) {
            dispatchOnMain { [weak self] in
                self?.handler(message)
            }
        }
        
        return true
    }
}

private protocol WatchRequestHandler {
    func handle(dictionary: [String : Any]) -> (Bool, WatchMessage?)
}

private class WatchRequestHandlerImpl<T: WatchMessage>: WatchRequestHandler {
    
    typealias WatchMessageType = T
    typealias HandlerType = (WatchMessageType) -> WatchMessage?
    let handler: HandlerType
    
    init(handler: @escaping HandlerType) {
        self.handler = handler
        print(String(describing: WatchMessageType.self))
    }
    
    func handle(dictionary: [String : Any]) -> (Bool, WatchMessage?) {
        
        guard let type = dictionary["_type"] as? String, type == String(describing: WatchMessageType.self) else {
            
            // message not recognized!
            return (false, nil)
        }
        
        if let message = WatchMessageType(dictionary: dictionary) {
            return (true, handler(message))
        }
        
        return (true, nil)
    }
}
