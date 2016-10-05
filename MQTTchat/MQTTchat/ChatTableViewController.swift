//
//  ChatTableViewController.swift
//  MQTTchat
//
//  Created by kenta on 2016/10/05.
//  Copyright © 2016年 sidepelican. All rights reserved.
//

import UIKit
import Moscapsule
import SlackTextViewController

class ChatTableViewController: SLKTextViewController {

    var username: String    = "amanda"
    var messages: [String]  = []
    
    // --------------------------------------------------------
    
    // init from Storyboard
    override class func tableViewStyle(for decoder: NSCoder) -> UITableViewStyle {
        return .plain
    }
    
    // MARK:- view life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView?.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "Cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
    }

    override func viewDidDisappear(_ animated: Bool) {
        
        
        super.viewDidDisappear(animated)
    }

    
    // MARK:- SLKTextViewController
    override func didPressRightButton(_ sender: Any?) {
        
        let message:String = self.textView.text
        self.messages.insert(message, at: 0)
        
        self.tableView?.reloadData()
    }
    
    
    // MARK:- TableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        
        // setup TableViewCell
        cell.textLabel!.text = self.messages[indexPath.row]
        
        // scrollView is inverted from SLKVC. so reinvert cells
        cell.transform = tableView.transform
        return cell
    }
    
}
