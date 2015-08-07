//
//  ViewController.swift
//  flash1
//
//  Created by Fernando Pereira on 8/6/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: Camera Control

    var flashMessages = FlashControl()
    
    // MARK: UI Stuff
    
    @IBOutlet weak var message: UITextField!
    @IBOutlet weak var statusMsg: UILabel!
    @IBOutlet weak var receiveButton: UIButton!
    
    private var _isReceiving = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "gotResult:", name:"CAPTURE_RESULT", object: nil)
        
        statusMsg.text = "Ready"

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func sendMessage(sender: AnyObject) {
        message.resignFirstResponder()
        
        guard message.text!.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 else {return}
        
        statusMsg.text = "Sending"
        let arrDec = message.text!.decomposeStringInBinary();
        print("Array of Decs=\(arrDec)")
        let testStr = NSString(binaryCompose: arrDec)
        print("Reverse Translation: \(testStr)")
        assert( testStr.isEqualToString(message.text!) )
        
        flashMessages.sendAMessage(arrDec)
        statusMsg.text = "Ready"
    }
    
    @IBAction func receiveMessage(sender: AnyObject) {
        
        if !_isReceiving {
            let statusCallback : voidCallbackForStatusMessageClosure = { (message:String)->Void in
                self.statusMsg.text = message
            }
            statusMsg.text = "Receiving"
            _isReceiving = true
            receiveButton.setTitle("Cancel", forState: UIControlState.Normal)
            flashMessages.startReceivingMessage(statusCallback)
        } else {
            flashMessages.stopReceivingMessage()
            statusMsg.text = "Ready"
            stoppedReceiving()
        }
    }
    
    private func stoppedReceiving() {
        
        _isReceiving = false
        receiveButton.setTitle("Receive", forState: UIControlState.Normal)
    }
    
    @objc private func gotResult(notification: NSNotification){
        //Take Action on Notification
        print("Got result: \(notification)")
        
        let tmp: [NSObject : AnyObject] = notification.userInfo!
        if let result : NSString = tmp["result"] as? NSString {
            
            message.text = "Result: " + (result as String)
        }
        statusMsg.text = "Finished Receiving - Ready"
        stoppedReceiving()
    }
    
}

