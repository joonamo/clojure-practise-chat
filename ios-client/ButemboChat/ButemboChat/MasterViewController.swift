//
//  MasterViewController.swift
//  ButemboChat
//  Contains channel list
//
//  Created by Joona Heinikoski on 28/01/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController, ServerEventListener {

    var detailViewController: DetailViewController? = nil
    var channels = [String]()
    var joinedChannels = [String]()

    // Setup view
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem
        
        editButtonItem.title = "Connect"
        navigationItem.title = "Channels"
        
        ServerConnection.sharedInstance.eventListeners.append(self)
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        // Setup pull to refresh
        refreshControl = UIRefreshControl()
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh channels")
        refreshControl?.addTarget(self, action: #selector(refreshChannels), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
    }
    
    // Insert new channel to view, makes sure channel diesn't already exist
    func insertNewChannel(channelName: String) {
        if !(channels.contains(channelName))
        {
            channels.insert(channelName, at: 0)
            let indexPath = IndexPath(row: 0, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
        }
    }
    
    // Adds a new channel and joins it, called when user presses plus button
    @objc
    func addChannel(_ sender: Any) {
        let alertController = UIAlertController(title: "Add Channel", message: "Channel name:", preferredStyle: UIAlertControllerStyle.alert)
        
        alertController.addTextField(configurationHandler: nil)
        
        let OKAction = UIAlertAction(title: "Join", style: UIAlertActionStyle.default) { (action) -> Void in
            let textfield = alertController.textFields![0]
            let text : String = textfield.text!
            if text.count > 0 {
                self.insertNewChannel(channelName: text)
                self.onJoinChannel(name: text)
            }
        }
        alertController.addAction(OKAction)
        
        let CancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel)
        alertController.addAction(CancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Ask user for server address, called when user presses connect
    func connectToServer(_ sender: Any?) {
        let alertController = UIAlertController(title: "Connect to server", message: "Server address:", preferredStyle: UIAlertControllerStyle.alert)
        
        alertController.addTextField(configurationHandler: nil)
        alertController.textFields![0].text = "localhost:10000/chat"
        
        let OKAction = UIAlertAction(title: "Connect", style: UIAlertActionStyle.default) { (action) -> Void in
            let textfield = alertController.textFields![0]
            let text : String = textfield.text!
            if text.count > 0 {
                ServerConnection.sharedInstance.doConnect(targetAddress: text)
            }
        }
        alertController.addAction(OKAction)
        
        let CancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel)
        alertController.addAction(CancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Asks user for new name
    func changeUserName(_ sender: Any?) {
        let alertController = UIAlertController(title: "Change name", message: "New name:", preferredStyle: UIAlertControllerStyle.alert)
        
        alertController.addTextField(configurationHandler: nil)
        
        let OKAction = UIAlertAction(title: "Change", style: UIAlertActionStyle.default) { (action) -> Void in
            let textfield = alertController.textFields![0]
            let text : String = textfield.text!
            if text.count > 0 {
                ServerConnection.sharedInstance.changeUserName(newName: text)
            }
        }
        alertController.addAction(OKAction)
        
        let CancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel)
        alertController.addAction(CancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Asks server connection to join channel and marks channel as joined
    func onJoinChannel(name: String)
    {
        ServerConnection.sharedInstance.joinChannel(channelName: name)
        self.joinedChannels.append(name)
        self.tableView.reloadData()
    }
    
    // Called after pull down to refresh, asks server connection to request latest channels info
    @objc
    func refreshChannels()
    {
        ServerConnection.sharedInstance.requestChannelsInfo()
    }
    
    // What happens when user clicks top left button. Either connect to server or change user name
    override func setEditing(_ editing: Bool, animated: Bool) {
        if (ServerConnection.sharedInstance.isConnected)
        {
            changeUserName(nil)
        }
        else
        {
            connectToServer(nil)
        }
    }
    
    // ServerEventListener protocol
    
    func onConnected() {
        editButtonItem.title = "Change Name"
        refreshChannels()
        
        if navigationItem.rightBarButtonItem == nil {
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addChannel(_:)))
            navigationItem.rightBarButtonItem = addButton
        }
    }
    
    func onDisconnected() {
        editButtonItem.title = "Connect"
    }
    
    func onWelcome(myId: String, myName: String) {
        if (myName == "new-user")
        {
            changeUserName(nil)
        }
    }
    
    func onChannelsInfo(info: [(name: String, userCount: Int)]) {
        for channel in info {
            insertNewChannel(channelName: channel.name)
        }
        refreshControl?.endRefreshing()
    }
    
    func onError(description: String) {}
    func onUserLeave(channel: String, userName: String, userId: String) {}
    func onUserRename(newName: String, oldName: String, userName: String, userId: String) {}
    func onMessage(channel: String, message: String, userName: String, userId: String) {}
    func onUserJoin(channel: String, userName: String, userId: String) {}
    func onChannelUsers(channel: String, users: [(name: String, id: String)]) {}
    
    // Boiler plate for UTableViewController
    
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Segues
    
    // What happens when user clicks on a channel
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = channels[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.channel = object
                // Channel can be "joined" multiple times, server doesn't mind
                onJoinChannel(name: object)
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channels.count
    }
    
    // Format cell
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        var object = channels[indexPath.row]
        if (joinedChannels.contains(object))
        {
            // Highlight joined channels
            object = String(format: "%@ - Joined", object)
        }
        cell.textLabel!.text = object
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // Editing disabled
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

    }
    
    // Editing disabled
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
}

