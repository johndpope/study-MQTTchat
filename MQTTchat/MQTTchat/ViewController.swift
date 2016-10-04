//
//  ViewController.swift
//  MQTTchat
//
//  Created by kenta on 2016/10/02.
//  Copyright © 2016年 sidepelican. All rights reserved.
//

import UIKit
import Moscapsule

class ViewController: UIViewController {
    
    @IBOutlet weak var messageLabel: UILabel!
    
    lazy var mqttClient: MQTTClient = {
        
        let mqttConfig = MQTTConfig(clientId: "testId", host: Const.host, port: Const.port, keepAlive: 60)
        mqttConfig.onMessageCallback = { mqttMessage in
            DispatchQueue.main.sync {
                self.messageLabel.text = mqttMessage.payloadString
            }
        }
        return MQTT.newConnection(mqttConfig)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mqttClient.subscribe("orz", qos: 2)
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func testSendButtonTapped(_ sender: AnyObject) {

        mqttClient.publishString("test message", topic: "orz", qos: 2, retain: false)
    }

}

