//
//  DetailViewController.swift
//  ButemboChat
//
//  Created by Joona Heinikoski on 28/01/2018.
//  Copyright © 2018 Joona Heinikoski. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController, UITableViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var bottomHeight: NSLayoutConstraint!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var chatHistory: UITableView!
    
    @IBAction func sendButtonPressed(_ sender: Any) {
    }
    
    var serverConnection: ServerConnection!
    var messages = [Any]()
    var channel = "Unknown channel"

    func configureView() {
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidShowNotification(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidShowNotification(notification:)), name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleKeyboardDidHideNotification(notification:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        let swipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(DetailViewController.dismissKeyboard))
        swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.down
        swipeGestureRecognizer.delegate = self
        view.addGestureRecognizer(swipeGestureRecognizer)
    }
    
    @objc
    func handleKeyboardDidShowNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let keyboardFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                bottomHeight.constant = keyboardFrame.size.height + 20
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
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    
//    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCellWithIdentifier("idCellChat", forIndexPath: indexPath) as! ChatCell
//        
//        return cell
//    }


}

