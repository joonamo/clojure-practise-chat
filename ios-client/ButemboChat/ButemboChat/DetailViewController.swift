//
//  DetailViewController.swift
//  ButemboChat
//  Contains chat interface
//
//  Created by Joona Heinikoski on 28/01/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIGestureRecognizerDelegate, ServerEventListener {
    
    var detailItem: String!
    var messages = [(message: String, userName: String, userId: String)]()
    var channel = "Unknown channel"
    var keyboardVisible = false
    
    @IBOutlet weak var bottomHeight: NSLayoutConstraint!
    @IBOutlet weak var messageField: UITextView!
    @IBOutlet weak var chatHistory: UITableView!
    
    @IBAction func sendButtonPressed(_ sender: Any) {
        if let message = messageField.text {
            ServerConnection.sharedInstance.sendMessage(targetChannel: channel, message: message)
            messageField.text = ""
        }
    }

    // Set up the view
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidShowNotification(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidShowNotification(notification:)), name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidHideNotification(notification:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        let swipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(DetailViewController.dismissKeyboard))
        swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.down
        swipeGestureRecognizer.delegate = self
        view.addGestureRecognizer(swipeGestureRecognizer)
        
        chatHistory.delegate = self
        chatHistory.dataSource = self
        chatHistory.register(UINib(nibName: "ChatCell", bundle: nil), forCellReuseIdentifier: "idCellChat")
        chatHistory.estimatedRowHeight = 90.0
        chatHistory.rowHeight = UITableViewAutomaticDimension
        
        navigationItem.title = channel
        
        // Register as server event lister
        ServerConnection.sharedInstance.eventListeners.append(self)
        
        // Get cached messages
        if ServerConnection.sharedInstance.channelMessages.keys.contains(channel) {
            for message in ServerConnection.sharedInstance.channelMessages[channel]! {
                messages.append(message)
            }
        }
    }

    // Handle keyboard appearing and changing size
    @objc
    func handleKeyboardDidShowNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let keyboardFrameBegin = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                let keyboardFrameEnd = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                let usedFrame = keyboardFrameEnd ?? keyboardFrameBegin
                bottomHeight.constant = usedFrame.size.height
                view.layoutIfNeeded()
                scrollToLastMessage()
            }
        }
        keyboardVisible = true
    }
    
    // Handle keyboard going away
    @objc
    func handleKeyboardDidHideNotification(notification: NSNotification) {
        bottomHeight.constant = 0
        view.layoutIfNeeded()
        scrollToLastMessage()
        keyboardVisible = false
    }
    
    @objc
    func dismissKeyboard() {
        if messageField.isFirstResponder {
            messageField.resignFirstResponder()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scrollToLastMessage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let index = ServerConnection.sharedInstance.eventListeners.index(where: { $0 === self as ServerEventListener}) {
            ServerConnection.sharedInstance.eventListeners.remove(at: index)
        }
    }
    
    // Handles adding new messages and scrolls down to display it
    func addMessage(message: String, userName: String, userId: String) {
        messages.append((message: message, userName: userName, userId: userId))
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatHistory.insertRows(at: [indexPath], with: .automatic)
        scrollToLastMessage()
    }
    
    func scrollToLastMessage() {
        if (messages.count > 0)
        {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            chatHistory.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    // Mark - Server event listener protocol
    func onUserLeave(channel: String, userName: String, userId: String) {
        if (channel == self.channel)
        {
            addMessage(message: String(format: "Left channel %@", channel), userName: userName, userId: userId)
        }
    }
    
    func onMessage(channel: String, message: String, userName: String, userId: String) {
        if (channel == self.channel)
        {
            addMessage(message: message, userName: userName, userId: userId)
        }
    }
    
    func onUserJoin(channel: String, userName: String, userId: String) {
        if (channel == self.channel)
        {
            addMessage(message: String(format: "Joined channel %@", channel), userName: userName, userId: userId)
        }
    }
    
    func onConnected() {}
    func onDisconnected() {}
    func onWelcome(myId: String, myName: String) {}
    func onError(description: String) {}
    func onUserRename(newName: String, oldName: String, userName: String, userId: String) {}
    func onChannelUsers(channel: String, users: [(name: String, id: String)]) {}
    func onChannelsInfo(info: [(name: String, userCount: Int)]) {}
    
    // MARK: UITableView Delegate and Datasource Methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath as IndexPath) as! MessageTableCellTableViewCell
        
        let message = messages[indexPath.row]
        cell.message?.text = message.message
        cell.sender?.text = message.userName
        
        return cell
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

