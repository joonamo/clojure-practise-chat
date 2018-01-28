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

class ServerConnection: WebSocketDelegate {
    static let sharedInstance = ServerConnection()
    
    var socket: WebSocket!
    var isConnected: Bool = false
    
    func DoConnect(targetAddress: String) {
        var request = URLRequest(url: URL(string: targetAddress)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket is connected")
        isConnected = true
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
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Received data: \(data.count)")
    }
    
    func joinChannel(channelName: String)
    {
        var payload: JSON = JSON()
        payload["target-channel"] = JSON(channelName)
        sendAction(action: "join-channel", payload: payload)
//        if isConnected {
//            socket.write(string: "{\"action\": \"join-channel\", \"payload\": }")
//        }
    }
    
    func sendAction(action: String, payload: JSON)
    {
        if (isConnected || true)
        {
            var data: JSON = JSON()
            data["action"] = JSON(action)
            data["payload"] = payload
            if let dataString = data.rawString() {
                print(String(format: "writing %@", dataString))
                //socket.write(string: dataString)
            }
            else
            {
                print("couldn't create json")
            }
        }
    }
}
