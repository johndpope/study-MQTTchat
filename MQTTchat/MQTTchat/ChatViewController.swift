//
//  ChatViewController.swift
//  MQTTchat
//
//  Created by kenta on 2016/10/08.
//  Copyright © 2016年 sidepelican. All rights reserved.
//

import UIKit
import Moscapsule
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {

    var messages = [JSQMessage]()
    
    let topic = "/chat/message"
    let keepAlive: Int32 = 60*5
    var mqttClient: MQTTClient!
    
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
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 接続を確立
        mqttClient = {
            
            let mqttConfig = MQTTConfig(clientId: self.senderId, host: Const.host, port: Const.port, keepAlive: keepAlive)
            mqttConfig.onMessageCallback = { mqttMessage in
                DispatchQueue.main.sync {
                    do {
                        
                        let mes = try ChatMessage(protobuf: mqttMessage.payload)
                        self.receiveMessage(text: mes.message, senderId: mes.senderId, senderDisplayName: mes.name, date: Date(timeIntervalSince1970: TimeInterval(mes.timestamp)))
                        
                    } catch {}
                }
            }
            mqttConfig.onDisconnectCallback = { _ in
                self.receiveMessage(text: "切断されました", senderId: "system", senderDisplayName: "system", date: Date())
            }
            return MQTT.newConnection(mqttConfig)
        }()
        
        // メッセージの受信を開始
        mqttClient.subscribe(topic, qos: 2)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        // サーバとの接続を切断
        mqttClient.disconnect()
        
        super.viewDidDisappear(animated)
    }
    
    // MARK:- 
    func receiveMessage(text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        // 効果音の再生
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        // メッセージの追加
        let message = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        self.messages.append(message!)
        self.finishReceivingMessage()
    }

    // MARK:- JSQMessagesViewController method overrides
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        // 全体にメッセージを送信
        do {
            let mes = ChatMessage(timestamp: Int64(date.timeIntervalSince1970), senderId: senderId, name: senderDisplayName, message: text)
            let payloadData = try mes.serializeProtobuf()
            mqttClient.publish(payloadData, topic: topic, qos: 2, retain: false)
        }
        catch {}
        self.finishSendingMessage()
    }

    override func didPressAccessoryButton(_ sender: UIButton!) {
        
        
    }
    
    // MARK:- JSQMessages CollectionView DataSource
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
