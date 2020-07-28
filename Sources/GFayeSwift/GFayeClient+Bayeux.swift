//
//  GFayeClient+Bayuex.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//  Updated by Cindy Wong on 2019-06-25.
//  Copyright (c) 2019 Cindy Wong.
//

import Foundation
import SwiftyJSON
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (left?, right?):
        return left < right
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (left?, right?):
        return left > right
    default:
        return rhs < lhs
    }
}

// MARK: Bayuex Connection Type
public enum BayeuxConnection: String {
    case longPolling = "long-polling"
    case callbackPolling = "callback-polling"
    case iFrame = "iframe"
    case webSocket = "websocket"
    
    public static let allValues = [longPolling, callbackPolling, iFrame, webSocket]
}

// MARK: BayuexChannel Messages
public enum BayeuxChannel: String {
    case handshake = "/meta/handshake"
    case connect = "/meta/connect"
    case disconnect = "/meta/disconnect"
    case subscribe = "/meta/subscribe"
    case unsubscribe = "/meta/unsubscribe"
}

// MARK: Bayuex Parameters
public enum Bayeux: String {
    case channel
    case version
    case clientId
    case connectionType
    case data
    case subscription
    case id
    case minimumVersion
    case supportedConnectionTypes
    case successful
    case error
    case advice
    case ext
}

// MARK: Private Bayuex Methods
extension GFayeClient {

    /**
     Bayeux messages
     */
    // Bayeux handshake
    // "channel": "/meta/handshake",
    // "version": "1.0",
    // "minimumVersion": "1.0beta",
    // "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe", "websocket]
    func handshake(ext: [String:String] = [String:String]()) {
        handshake(allowedConnectionTypes: BayeuxConnection.allValues, ext: ext)
    }

    // Bayeux handshake
    // "channel": "/meta/handshake",
    // "version": "1.0",
    // "minimumVersion": "1.0beta",
    // "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe", "websocket]
    func handshake(allowedConnectionTypes: [BayeuxConnection], ext: [String:String] = [String:String]()) {
        writeOperationQueue.sync { [unowned self] in
            let connTypes = allowedConnectionTypes.map { $0.rawValue }

            var dict = [String: Any]()
            dict[Bayeux.channel.rawValue] = BayeuxChannel.handshake.rawValue
            dict[Bayeux.version.rawValue] = "1.0"
            dict[Bayeux.minimumVersion.rawValue] = "1.0beta"
            dict[Bayeux.supportedConnectionTypes.rawValue] = connTypes
            if !ext.isEmpty {
                dict[Bayeux.ext.rawValue] = ext
            }
            if let string = JSON(dict).rawString() {
                self.transport?.writeString(string)
            }
        }
    }

    // Bayeux connect
    // "channel": "/meta/connect",
    // "clientId": "Un1q31d3nt1f13r",
    // "connectionType": "long-polling"
    func connect(ext: [String:String] = [String:String]()) {
        writeOperationQueue.sync { [unowned self] in
            var dict: [String: Any] = [
                Bayeux.channel.rawValue: BayeuxChannel.connect.rawValue,
                Bayeux.clientId.rawValue: self.gFayeClientId!,
                Bayeux.connectionType.rawValue: BayeuxConnection.webSocket.rawValue,
                Bayeux.advice.rawValue: ["timeout": self.timeOut]
            ]
            if !ext.isEmpty {
                dict[Bayeux.ext.rawValue] = ext
            }
            if let string = JSON(dict).rawString() {
                self.transport?.writeString(string)
            }
        }
    }

    // Bayeux disconnect
    // "channel": "/meta/disconnect",
    // "clientId": "Un1q31d3nt1f13r"
    func disconnect(ext: [String:String] = [String:String]()) {
        writeOperationQueue.sync { [unowned self] in
            var dict: [String: Any] = [
                Bayeux.channel.rawValue: BayeuxChannel.disconnect.rawValue,
                Bayeux.clientId.rawValue: self.gFayeClientId!,
                Bayeux.connectionType.rawValue: BayeuxConnection.webSocket.rawValue
            ]
            if !ext.isEmpty {
                dict[Bayeux.ext.rawValue] = ext
            }
            if let string = JSON(dict).rawString() {
                self.transport?.writeString(string)
            }
        }
    }

    // Bayeux subscribe
    // "channel": "/meta/subscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    func subscribe(_ model: GFayeSubscriptionModel) {
        writeOperationQueue.sync { [unowned self] in
            do {
                let json = try model.jsonString()

                self.transport?.writeString(json)
                self.pendingSubscriptions.append(model)
            } catch GFayeSubscriptionModelError.conversationError {

            } catch GFayeSubscriptionModelError.clientIdNotValid
                where !(self.gFayeClientId?.isEmpty ?? true) {
                    let model = model
                    model.clientId = self.gFayeClientId
                    self.subscribe(model)
            } catch {

            }
        }
    }

    // Bayeux Unsubscribe
    // {
    // "channel": "/meta/unsubscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    // }
    func unsubscribe(_ channel: String, ext: [String:String] = [String:String]()) {
        writeOperationQueue.sync { [unowned self] in
            if let clientId = self.gFayeClientId {
                var dict: [String: Any] = [
                    Bayeux.channel.rawValue: BayeuxChannel.unsubscribe.rawValue,
                    Bayeux.clientId.rawValue: clientId,
                    Bayeux.subscription.rawValue: channel
                ]

                if !ext.isEmpty {
                    dict[Bayeux.ext.rawValue] = ext
                }
                
                if let string = JSON(dict).rawString() {
                    self.transport?.writeString(string)
                }
            }
        }
    }

    // Bayeux Publish
    // {
    // "channel": "/some/channel",
    // "clientId": "Un1q31d3nt1f13r",
    // "data": "some application string or JSON encoded object",
    // "id": "some unique message id"
    // }
    func publish(_ data: GFayeMessage, channel: String,ext: [String:String] = [String:String]()) {
        writeOperationQueue.sync { [weak self] in
            if let clientId = self?.gFayeClientId, let messageId = self?.nextMessageId(), self?.gFayeConnected == true {
                var dict: [String: Any] = [
                    Bayeux.channel.rawValue: channel,
                    Bayeux.clientId.rawValue: clientId,
                    Bayeux.id.rawValue: messageId,
                    Bayeux.data.rawValue: data
                ]
                if !ext.isEmpty {
                    dict[Bayeux.ext.rawValue] = ext
                }
                if let string = JSON(dict).rawString() {
                    print("Faye: Publish string: \(string)")
                    self?.transport?.writeString(string)
                }
            }
        }
    }
}
