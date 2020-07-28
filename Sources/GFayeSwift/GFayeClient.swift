//
//  GFayeClient.swift
//  GFayeSwift
//
//  Created by Haris Amin on 8/31/14.
//  Copyright (c) 2014 Haris Amin. All rights reserved.
//
//  Updated by Cindy Wong on 2019-06-25.
//  Copyright (c) 2019 Cindy Wong.
//

import Foundation

// MARK: Subscription State
public enum GFayeSubscriptionState {
    case pending(GFayeSubscriptionModel)
    case subscribed(GFayeSubscriptionModel)
    case queued(GFayeSubscriptionModel)
    case subscribingTo(GFayeSubscriptionModel)
    case unknown(GFayeSubscriptionModel?)
}

// MARK: Type Aliases
public typealias ChannelSubscriptionBlock = (GFayeMessage) -> Void

// MARK: GFayeClient
open class GFayeClient: TransportDelegate {
    open var gFayeURLString: String {
        didSet {
            if let transport = self.transport {
                transport.urlString = gFayeURLString
            }
        }
    }

    open var gFayeClientId: String?
    open weak var delegate: GFayeClientDelegate?

    var transport: WebsocketTransport?
    open var transportHeaders: [String: String]? = nil {
        didSet {
            if let transport = self.transport {
                transport.headers = self.transportHeaders
            }
        }
    }

    open internal(set) var gFayeConnected: Bool? {
        didSet {
            if gFayeConnected == false {
                unsubscribeAllSubscriptions()
            }
        }
    }

    var connectionInitiated: Bool?
    var messageNumber: UInt32 = 0

    var queuedSubscriptions = [GFayeSubscriptionModel]()
    var pendingSubscriptions = [GFayeSubscriptionModel]()
    var openSubscriptions = [GFayeSubscriptionModel]()

    var channelSubscriptionBlocks = [String: ChannelSubscriptionBlock]()

    var connectionTypes = [BayeuxConnection]()
    
    lazy var pendingSubscriptionSchedule: Timer = {
        return Timer.scheduledTimer(
            timeInterval: 45,
            target: self,
            selector: #selector(pendingSubscriptionsAction(_:)),
            userInfo: nil,
            repeats: true
        )
    }()

    /// Default in 10 seconds
    let timeOut: Int

    let readOperationQueue = DispatchQueue(label: "com.ckpwong.gfayeclient.read", attributes: [])
    let writeOperationQueue = DispatchQueue(
        label: "com.ckpwong.gfayeclient.write",
        attributes: DispatchQueue.Attributes.concurrent)
    let queuedSubsLockQueue = DispatchQueue(label: "com.ckpwong.gfayeclient.queuedSubscriptionsLockQueue")
    let pendingSubsLockQueue = DispatchQueue(label: "com.ckpwong.gfayeclient.pendingSubscriptionsLockQueue")
    let openSubsLockQueue = DispatchQueue(label: "com.ckpwong.gfayeclient.openSubscriptionsLockQueue")

    // MARK: Init
    public init(aGFayeURLString: String, channel: String? = nil, timeoutAdvice: Int=10000, connectionTypes:[BayeuxConnection] = BayeuxConnection.allValues) {
        self.gFayeURLString = aGFayeURLString
        self.gFayeConnected = false
        self.timeOut = timeoutAdvice

        self.transport = WebsocketTransport(url: aGFayeURLString)
        self.transport!.headers = self.transportHeaders
        self.transport!.delegate = self
        self.connectionTypes = connectionTypes

        if let channel = channel {
            self.queuedSubscriptions.append(GFayeSubscriptionModel(subscription: channel, clientId: gFayeClientId))
        }
    }

    public convenience init(aGFayeURLString: String, channel: String, channelBlock:@escaping ChannelSubscriptionBlock) {
        self.init(aGFayeURLString: aGFayeURLString, channel: channel)
        self.channelSubscriptionBlocks[channel] = channelBlock
    }

    deinit {
        pendingSubscriptionSchedule.invalidate()
    }

    // MARK: Client
    open func connectToServer() {
        if self.connectionInitiated != true {
            self.transport?.openConnection()
            self.connectionInitiated = true
        } else {
            print("GFaye: Connection established")
        }
    }

    open func disconnectFromServer(ext: [String:String] = [String:String]()) {
        unsubscribeAllSubscriptions()

        self.disconnect(ext: ext)
    }

    open func sendMessage(_ messageDict: GFayeMessage, channel: String, ext: [String:String] = [String:String]()) {
        self.publish(messageDict, channel: channel, ext: ext)
    }

    open func sendPing(_ data: Data, completion: (() -> Void)?) {
        writeOperationQueue.async { [unowned self] in
            self.transport?.sendPing(data, completion: completion)
        }
    }

    open func subscribeToChannel(
        _ model: GFayeSubscriptionModel,
        ext: [String:String] = [String:String](),
        block: ChannelSubscriptionBlock?=nil)
        -> GFayeSubscriptionState {
        guard !self.isSubscribedToChannel(model.subscription) else {
            return .subscribed(model)
        }

        guard !self.pendingSubscriptions.contains(where: { $0 == model }) else {
            return .pending(model)
        }

        if let block = block {
            self.channelSubscriptionBlocks[model.subscription] = block
        }

        if self.gFayeConnected == false {
            self.queuedSubscriptions.append(model)

            return .queued(model)
        }

        self.subscribe(model)

        return .subscribingTo(model)
    }

    open func subscribeToChannel(_ channel: String, ext: [String:String] = [String:String](), block: ChannelSubscriptionBlock?=nil) -> GFayeSubscriptionState {
        return subscribeToChannel(
            GFayeSubscriptionModel(subscription: channel, clientId: gFayeClientId),
            ext: ext,
            block: block
        )
    }

    open func unsubscribeFromChannel(_ channel: String, ext: [String:String] = [String:String]()) {
        _ = removeChannelFromQueuedSubscriptions(channel)

        self.unsubscribe(channel, ext: ext)
        self.channelSubscriptionBlocks[channel] = nil

        _ = removeChannelFromOpenSubscriptions(channel)
        _ = removeChannelFromPendingSubscriptions(channel)
    }
}
