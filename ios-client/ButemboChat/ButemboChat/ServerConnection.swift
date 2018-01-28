//
//  ServerConnection.swift
//  ButemboChat
//
//  Created by Joona Heinikoski on 28/01/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

protocol ServerEventListener {
    func onConnected() -> Void
    func onDisconnected() -> Void
    func onWelcome(myId: String, myName: String) -> Void
    func onError(description: String) -> Void
    func onUserLeave(channel: String, userName: String, userId: String) -> Void
    func onUserRename(newName: String, oldName: String, userName: String, userId: String) -> Void
    func onMessage(channel: String, message: String, userName: String, userId: String) -> Void
    func onUserJoin(channel: String, userName: String, userId: String) -> Void
    func onChannelUsers(channel: String, users: [(String, String)]) -> Void
    func onChannelsInfo(info: [(String, Int)]) -> Void
}

class ServerConnection: WebSocketDelegate {
    static let sharedInstance = ServerConnection()
    
    var socket: WebSocket!
    var isConnected: Bool = false
    
    var myId: String!
    
    // register your callbacks here!
    var eventListeners = [ServerEventListener]()
    
    func doConnect(targetAddress: String) {
        var request = URLRequest(url: URL(string: String(format: "ws://%@", targetAddress))!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket is connected")
        isConnected = true
        for listener in eventListeners
        {
            listener.onConnected()
        }
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let e = error as? WSError {
            print("websocket is disconnected: \(e.message)")
        } else if let e = error {
            print("websocket is disconnected: \(e.localizedDescription)")
        } else {
            print("websocket disconnected")
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("Received text: \(text)")
        if let dataFromString = text.data(using: .utf8, allowLossyConversion: false)
        {
            if let dataAsJson = try? JSON(data: dataFromString) {
                if (dataAsJson["type"].exists())
                {
                    if let responseType = dataAsJson["type"].string, let responsePayload : JSON = dataAsJson["payload"]{
                        switch responseType {
                        case "welcome": handleResponseWelcome(payload: responsePayload)
                        default: print(String(format: "Unknown response type: %@", responseType))
                        }
                        return
                    }
                }
            }
        }
        print ("failed to handle response")
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Received data: \(data.count)")
    }
    
    func handleResponseWelcome(payload : JSON)
    {
        if let receivedId = payload["user"]["id"].string, let receivedName = payload["user"]["name"].string {
            myId = receivedId
            for listener in eventListeners {
                listener.onWelcome(myId: receivedId, myName: receivedName)
            }
        }
    }
    
    func changeUserName(newName: String)
    {
        var payload: JSON = JSON()
        payload["new-name"] = JSON(newName)
        sendAction(action: "change-name", payload: payload)
    }
    
    func joinChannel(channelName: String)
    {
        var payload: JSON = JSON()
        payload["target-channel"] = JSON(channelName)
        sendAction(action: "join-channel", payload: payload)
    }
    
    func sendAction(action: String, payload: JSON)
    {
        if (isConnected)
        {
            var data: JSON = JSON()
            data["action"] = JSON(action)
            data["payload"] = payload
            if let dataString = data.rawString() {
                print(String(format: "writing %@", dataString))
                socket.write(string: dataString)
            }
            else
            {
                print("couldn't create json")
            }
        }
    }
}
