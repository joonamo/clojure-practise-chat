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

protocol ServerEventListener: class {
    func onConnected() -> Void
    func onDisconnected() -> Void
    func onWelcome(myId: String, myName: String) -> Void
    func onError(description: String) -> Void
    func onUserLeave(channel: String, userName: String, userId: String) -> Void
    func onUserRename(newName: String, oldName: String, userName: String, userId: String) -> Void
    func onMessage(channel: String, message: String, userName: String, userId: String) -> Void
    func onUserJoin(channel: String, userName: String, userId: String) -> Void
    func onChannelUsers(channel: String, users: [(name: String, id: String)]) -> Void
    func onChannelsInfo(info: [(name: String, userCount: Int)]) -> Void
}

class ServerConnection: WebSocketDelegate {
    // Static instance for use anywhere
    static let sharedInstance = ServerConnection()
    
    var socket: WebSocket!
    var isConnected: Bool = false
    
    var myId: String!
    
    // Cache all incoming messages. This wouldn't work in real app, but good enough for demo
    var channelMessages = [String: [(message: String, userName: String, userId: String)]]()
    
    // register your interest here!
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
                        case "message": handleResponseMessage(payload: responsePayload)
                        case "user-join": handleResponseUserJoin(payload: responsePayload)
                        case "user-leave": handleResponseUserLeave(payload: responsePayload)
                        case "user-rename": handleUserRename(payload: responsePayload)
                        case "channel-users": handleChannelUsers(payload: responsePayload)
                        case "channels-info": handleChannelsInfo(payload: responsePayload)
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
    
    func handleResponseMessage(payload : JSON)
    {
        if let channel = payload["channel"].string, let userName = payload["user"]["name"].string,
            let userId = payload["user"]["id"].string, let message = payload["message"].string {
            for listener in eventListeners {
                listener.onMessage(channel: channel, message: message, userName: userName, userId: userId)
            }
            
            // Add this channel to cached messages if not available
            if !channelMessages.keys.contains(channel) {
                channelMessages[channel] = [(message: String, userName: String, userId: String)]()
            }
            channelMessages[channel]?.append((message: message, userName: userName, userId: userId))
        }
    }
    
    func handleResponseUserJoin(payload: JSON)
    {
        if let channel = payload["channel"].string, let userName = payload["user"]["name"].string,
            let userId = payload["user"]["id"].string {
            for listener in eventListeners {
                listener.onUserJoin(channel: channel, userName: userName, userId: userId)
            }
        }
    }
    
    func handleResponseUserLeave(payload: JSON)
    {
        if let channel = payload["channel"].string, let userName = payload["user"]["name"].string,
            let userId = payload["user"]["id"].string {
            for listener in eventListeners {
                listener.onUserLeave(channel: channel, userName: userName, userId: userId)
            }
        }
    }
    
    func handleUserRename(payload: JSON)
    {
        if let oldName = payload["old-name"].string, let newName = payload["new-name"].string,
            let userId = payload["user"]["id"].string {
            for listener in eventListeners {
                listener.onUserRename(newName: newName, oldName: oldName, userName: oldName, userId: userId)
            }
        }
    }
    
    func handleChannelUsers(payload: JSON)
    {
        if let channel = payload["channel"].string, let users = payload["users"].array {
            var nativeUsers = [(name: String, id: String)]()
            for user in users {
                if let name = user["name"].string, let id = user["id"].string {
                    nativeUsers.append((name: name, id: id))
                }
            }
            for listener in eventListeners {
                listener.onChannelUsers(channel: channel, users: nativeUsers)
            }
        }
    }
    
    func handleChannelsInfo(payload: JSON)
    {
        if let channels = payload["info"].array {
            var nativeChannels = [(name: String, userCount: Int)]()
            for channel in channels {
                if let name = channel["name"].string, let userCount = channel["user-count"].int {
                    nativeChannels.append((name: name, userCount: userCount))
                }
            }
            for listener in eventListeners {
                listener.onChannelsInfo(info: nativeChannels)
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
    
    func sendMessage(targetChannel: String, message: String)
    {
        var payload: JSON = JSON()
        payload["target-channel"] = JSON(targetChannel)
        payload["message"] = JSON(message)
        sendAction(action: "send-message", payload: payload)
    }
    
    func requestChannelsInfo()
    {
        let payload: JSON = JSON()
        sendAction(action: "get-channels-info", payload: payload)
    }
    
    func requestChannelUsers(targetChannel: String)
    {
        var payload: JSON = JSON()
        payload["target-channel"] = JSON(targetChannel)
        sendAction(action: "get-channel-users", payload: payload)
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
