//
//  DetailViewController.swift
//  ButemboChat
//
//  Created by Joona Heinikoski on 28/01/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIGestureRecognizerDelegate {
    
    

    @IBOutlet weak var bottomHeight: NSLayoutConstraint!
    @IBOutlet weak var messageField: UITextView!
    @IBOutlet weak var chatHistory: UITableView!
    
    @IBAction func sendButtonPressed(_ sender: Any) {
        if let message = messageField.text {
            messages.append(message)
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            chatHistory.insertRows(at: [indexPath], with: .automatic)
            messageField.text = ""
        }
    }
    
    var messages = [String]()
    var channel = "Unknown channel"

    func configureView() {
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
    }
    
    @objc
    func handleKeyboardDidShowNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let keyboardFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                bottomHeight.constant = keyboardFrame.size.height + 40
                view.layoutIfNeeded()
            }
        }
    }
    
    @objc
    func handleKeyboardDidHideNotification(notification: NSNotification) {
        bottomHeight.constant = 0
        view.layoutIfNeeded()
    }
    
    @objc
    func dismissKeyboard() {
        if messageField.isFirstResponder {
            messageField.resignFirstResponder()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var detailItem: String? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    // MARK: UITableView Delegate and Datasource Methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath as IndexPath) as! MessageTableCellTableViewCell
        
        cell.message?.text = messages[indexPath.row]
        cell.sender?.text = "Unknown user:"
        
        return cell
    }

}

