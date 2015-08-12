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
    
    private var _sendingOperQueue: NSOperationQueue?
    
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
        
        if _sendingOperQueue == nil {
            _sendingOperQueue = NSOperationQueue()
            _sendingOperQueue!.maxConcurrentOperationCount = 1
        }
        
        let sendButton = sender as! UIButton
        
        sendButton.hidden = true
        statusMsg.text = "Sending"
        let arrDec = message.text!.decomposeStringInBinary();
        print("Array of Decs=\(arrDec)")
        let testStr = NSString(binaryCompose: arrDec)
        print("Reverse Translation: \(testStr)")
        assert( testStr.isEqualToString(message.text!) )
        
        _sendingOperQueue?.addOperationWithBlock({ () -> Void in
            self.flashMessages.sendAMessage(arrDec, completion: {()->Void in
                self.statusMsg.text = "Ready"
                sendButton.hidden = false
            })
        })
    }
    
    @IBAction func receiveMessage(sender: AnyObject) {
        
        if !_isReceiving {
            let statusCallback : voidCallbackForStatusMessageClosure = { (message:String)->Void in
                self.statusMsg.text = message
            }
            statusMsg.text = "Waiting for Start of Message"
            _isReceiving = true
            receiveButton.setTitle("Cancel", forState: UIControlState.Normal)
            flashMessages.startReceivingMessage(statusCallback)
        } else {
            stoppedReceiving()
        }
    }
    
    private func stoppedReceiving() {
        
        _isReceiving = false
        receiveButton.setTitle("Receive", forState: UIControlState.Normal)
        flashMessages.stopReceivingMessage()
        statusMsg.text = "Ready"
    }
    
    @objc private func gotResult(notification: NSNotification){
        //Take Action on Notification
        print("Got result: \(notification)")
        
        let tmp: [NSObject : AnyObject] = notification.userInfo!
        if let result = tmp["result"] as? String {
            
            let alert = UIAlertController(title: "Received", message: result, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            
        }
        stoppedReceiving()
    }
    
}

