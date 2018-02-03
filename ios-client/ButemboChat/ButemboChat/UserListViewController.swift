//
//  UserListViewController.swift
//  ButemboChat
//
//  Created by Joona Heinikoski on 03/02/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import Foundation
import UIKit

let cellReuseIdentifier = "userCell"

class UserListViewController: UITableViewController, ServerEventListener {
    var channel = "Unknown Channel"
    var channelUsers = [String: String]()
    
    override func viewDidLoad() {
        ServerConnection.sharedInstance.eventListeners.append(self)
        super.viewDidLoad()
        setupBackButton()
        self.title = String(format: "%@ users", channel)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        setupChannelUsers(reload: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let index = ServerConnection.sharedInstance.eventListeners.index(where: { $0 === self as ServerEventListener}) {
            ServerConnection.sharedInstance.eventListeners.remove(at: index)
        }
    }
    
    func setupChannelUsers(reload: Bool) {
        if ServerConnection.sharedInstance.channelUsers.keys.contains(channel) {
            channelUsers = ServerConnection.sharedInstance.channelUsers[channel]!
        }
        if reload {
            self.tableView.reloadData()
        }
    }
    
    // Back button handling
    func setupBackButton() {
        let backButton = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(backButtonTapped))
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc
    func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // Tableview stuff
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) else {
            return UITableViewCell()
        }
        
        // Report users in any order the keys come out
        let object = channelUsers[Array(channelUsers.keys)[indexPath.row]]
        cell.textLabel!.text = object
        return cell
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channelUsers.count
    }
    
    // Server event listener protocol, mainly just reload on every case
    func onUserLeave(channel: String, userName: String, userId: String) {setupChannelUsers(reload: true)}
    func onUserRename(newName: String, oldName: String, userName: String, userId: String) {setupChannelUsers(reload: true)}
    func onUserJoin(channel: String, userName: String, userId: String) {setupChannelUsers(reload: true)}
    func onChannelUsers(channel: String, users: [String : String]) {setupChannelUsers(reload: true)}
    
    func onConnected() {}
    func onDisconnected() {}
    func onWelcome(myId: String, myName: String) {}
    func onError(description: String) {}
    func onChannelsInfo(info: [(name: String, userCount: Int)]) {}
    func onMessage(channel: String, message: String, userName: String, userId: String) {}
    
}
