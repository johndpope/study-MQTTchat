//
//  ChatViewController.swift
//  MQTTchat
//
//  Created by kenta on 2016/10/08.
//  Copyright © 2016年 sidepelican. All rights reserved.
//

import UIKit
import Moscapsule
import SwiftyDrop
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {

    private var prevMessageSize = 0
    var messages = [JSQMessage]()
    
    let topic = "/chat/message"
    var mqttClient: MQTTClient?
    
    // MARK:- view life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.backgroundColor = UIColor(red: 131.0/255.0, green: 161.0/255.0, blue: 201.0/255.0, alpha: 1.0)
        
        // 自分のIDと名前を設定
        self.senderId = UIDevice.current.identifierForVendor?.uuidString
        self.senderDisplayName = UIDevice.current.name
        
        // ユーザアイコンサイズの設定
        self.collectionView?.collectionViewLayout.incomingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height:kJSQMessagesCollectionViewAvatarSizeDefault )
        self.collectionView?.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero // 自分のアイコンは表示しない
        
        // 最新のメッセージを受信したときに自動スクロールを行うか
        self.automaticallyScrollsToMostRecentMessage = true
        
        // 表示の更新間隔を設定 // INFO: 同時に複数メッセージを受信したときに重くなるため
        Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { timer in
            
            if self.prevMessageSize < self.messages.count {
                self.prevMessageSize = self.messages.count
                
                // 効果音の再生
                JSQSystemSoundPlayer.jsq_playMessageSentSound()
                
                // 表示の更新
                self.finishReceivingMessage()
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // サーバに接続
        self.setupMqttConnection()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        // サーバとの接続を切断
        mqttClient?.disconnect()
        
        super.viewDidDisappear(animated)
    }
    
    // MARK:-
    func setupMqttConnection() {
     
        // 接続を確立
        mqttClient = {
            
            let mqttConfig = MQTTConfig(clientId: self.senderId, host: Const.host, port: Const.port, keepAlive: 40)
            mqttConfig.onMessageCallback = { mqttMessage in
                
                if let mes = try? ChatMessage(protobuf: mqttMessage.payload) {
                    self.receiveMessage(text: mes.message, senderId: mes.senderId, senderDisplayName: mes.name, date: Date(timeIntervalSince1970: TimeInterval(mes.timestamp)))
                } else {
                    self.receiveMessage(text: String(describing: mqttMessage.payload), senderId: "unknown", senderDisplayName: "不明なメッセージ", date: Date())
                }
            }
            
            mqttConfig.onConnectCallback = { _ in
                
                DispatchQueue.main.async {
                    Drop.down("接続されました", state: .success)
                }
            }
            
            mqttConfig.onDisconnectCallback = { _ in

                DispatchQueue.main.async {
                    Drop.down("切断されました", state: .error)
                }
                self.mqttClient = nil
            }
            return MQTT.newConnection(mqttConfig)
        }()
        
        // メッセージの受信を開始
        mqttClient?.subscribe(topic, qos: 2)
    }
    
    func receiveMessage(text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        // メッセージの追加
        let message = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        self.messages.append(message!)
    }
}

// MARK:- JSQMessagesViewController
extension ChatViewController {
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        // 全体にメッセージを送信
        let mes = ChatMessage(timestamp: Int64(date.timeIntervalSince1970), senderId: senderId, name: senderDisplayName, message: text)
        let payloadData = try! mes.serializeProtobuf()
        mqttClient?.publish(payloadData, topic: topic, qos: 2, retain: false)
    
        self.finishSendingMessage()
    }

    override func didPressAccessoryButton(_ sender: UIButton!) {
        
        // do nothing
    }
}


// MARK:- JSQMessages CollectionView DataSource
extension ChatViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return self.messages[indexPath.item]
    }

    // 吹き出しのデザイン
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        
        let incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor.white)
        let outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor(red: 133.0/255.0, green: 226.0/255.0, blue: 73.0/255.0, alpha: 1.0))
        
        return self.messages[indexPath.item].senderId == self.senderId ? outgoingBubble : incomingBubble
    }
    
    // アバター画像
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        
        return JSQMessagesAvatarImageFactory.avatarImage(with: UIImage.jsq_defaultPlay(), diameter: 64)
    }
    
    // 時間ラベル
    override func collectionView(_ collectionView: JSQMessagesCollectionView, attributedTextForCellTopLabelAt indexPath: IndexPath) -> NSAttributedString? {
    
        if (indexPath.item % 5 == 0) {
            let message = self.messages[indexPath.item]
            
            let displayTimeString = JSQMessagesTimestampFormatter.shared().timestamp(for: message.date)!
            return NSAttributedString(string: displayTimeString, attributes: [NSForegroundColorAttributeName: UIColor.white])
        }
        
        return nil
    }
    
    // 名前ラベル
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString? {
        let message = messages[indexPath.item]
        if message.senderId == self.senderId {
            return nil
        }
        
        return NSAttributedString(string: message.senderDisplayName, attributes: [NSForegroundColorAttributeName: UIColor.white])
    }
    
    // 時間ラベルのための高さを調節
    override func collectionView(_ collectionView: JSQMessagesCollectionView, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout, heightForCellTopLabelAt indexPath: IndexPath) -> CGFloat {

        if indexPath.item % 5 == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        
        return 0.0
    }
    
    // 名前ラベルのための高さを調節
    override func collectionView(_ collectionView: JSQMessagesCollectionView, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout, heightForMessageBubbleTopLabelAt indexPath: IndexPath) -> CGFloat {
        
        let currentMessage = self.messages[indexPath.item]
        
        if currentMessage.senderId == self.senderId {
            return 0.0
        }
        
        if indexPath.item - 1 > 0 {
            let previousMessage = self.messages[indexPath.item - 1]
            if previousMessage.senderId == currentMessage.senderId {
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    // セルの修飾
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        cell.textView.textColor = UIColor.black
        return cell
    }
}
