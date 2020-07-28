//
//  GFayeClient+Transport.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//  Updated by Cindy Wong on 2019-06-25.
//  Copyright (c) 2019 Cindy Wong.
//

import Foundation

// MARK: Transport Delegate
extension GFayeClient {
    public func didConnect() {
        self.connectionInitiated = false
        self.handshake(allowedConnectionTypes: connectionTypes)
    }

    public func didDisconnect(_ error: Error?) {
        self.delegate?.disconnectedFromServer(self)
        self.connectionInitiated = false
        self.gFayeConnected = false
    }

    public func didFailConnection(_ error: Error?) {
        self.delegate?.connectionFailed(self)
        self.connectionInitiated = false
        self.gFayeConnected = false
    }

    public func didWriteError(_ error: Error?) {
        self.delegate?.fayeClientError(self, error: error ?? GFayeSocketError.transportWrite)
    }

    public func didReceiveMessage(_ text: String) {
        self.receive(text)
    }

    public func didReceivePong() {
        self.delegate?.pongReceived(self)
    }
}
