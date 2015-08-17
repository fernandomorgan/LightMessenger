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
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var sendOrReceive: UISegmentedControl!
    @IBOutlet weak var textMsgLabel: UILabel!
    
    private var _isReceiving = false
    private var _isSending = false
    
    private var _sendingOperQueue: NSOperationQueue?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "gotResult:", name:"CAPTURE_RESULT", object: nil)
        updateStateWithSendingOrReceiving(true)
        statusMsg.text = "Ready"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changeSendingOrReceiving(sender: AnyObject) {
        guard let segment:UISegmentedControl!  = sender as? UISegmentedControl else {return}
        updateStateWithSendingOrReceiving(segment!.selectedSegmentIndex == 0)
    }
    
    private func updateStateWithSendingOrReceiving (isSendingSelected: Bool){        
        receiveButton.hidden = isSendingSelected 
        sendButton.hidden  = !isSendingSelected
        message.hidden = !isSendingSelected
        textMsgLabel.hidden = !isSendingSelected
    }
    
    private func updateStateWithSending( sending: Bool ) {
        _isSending = sending
        sendButton.hidden  = _isSending
        statusMsg.text = _isSending ? "Sending" : "Ready"
        sendOrReceive.hidden = _isSending
    }
    
    private func updateStateWithReceiving( receiving: Bool ) {
        _isReceiving = receiving
        statusMsg.text = _isReceiving ? "Waiting for Start of Message" : "Ready"
        receiveButton.setTitle(_isReceiving ? "Cancel" : "Receive", forState: UIControlState.Normal)
        sendOrReceive.hidden = _isReceiving
    }

    @IBAction func sendMessage(sender: AnyObject) {
        message.resignFirstResponder()
        
        guard message.text!.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 else {return}
        
        if _sendingOperQueue == nil {
            _sendingOperQueue = NSOperationQueue()
            _sendingOperQueue!.maxConcurrentOperationCount = 1
        }
        
        updateStateWithSending(true)
        
        let arrDec = message.text!.decomposeStringInBinary();
        print("Array of Decs=\(arrDec)")
        let testStr = NSString(binaryCompose: arrDec)
        print("Reverse Translation: \(testStr)")
        assert( testStr.isEqualToString(message.text!) )
        
        let sendingOper = NSBlockOperation(block: { () -> Void in
            self.flashMessages.sendAMessage(arrDec, updateStatus:{ (message:String)->Void in
                self.statusMsg.text = message
            })
        })
        sendingOper.completionBlock = { ()->Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.updateStateWithSending(false)
                })
        }
        
        _sendingOperQueue?.addOperation(sendingOper)
    }
    
    @IBAction func receiveMessage(sender: AnyObject) {
        
        if !_isReceiving {
            let statusCallback : voidCallbackForStatusMessageClosure = { (message:String)->Void in
                self.statusMsg.text = message
            }
            updateStateWithReceiving(true)
            
            flashMessages.startReceivingMessage(statusCallback)
        } else {
            stoppedReceiving()
        }
    }
    
    private func stoppedReceiving() {
        updateStateWithReceiving(false)
        flashMessages.stopReceivingMessage()
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

