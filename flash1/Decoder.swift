//
//  Decoder.swift
//  flash1
//
//  Created by Fernando Pereira on 8/11/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

import Foundation

class Decoder {
    
    private let decoderQueue: dispatch_queue_t
    private var capturedFrames: [(CMTime,Bool)]
    private var _callbackBlock : voidCallbackForStatusMessageClosure?
    
    init () {
        decoderQueue = dispatch_queue_create("com.troezen.decoderQueue", DISPATCH_QUEUE_SERIAL)
        capturedFrames = []
    }
    
    // MARK: setup
    
    func setCallbackBlock( cb : voidCallbackForStatusMessageClosure ) {
        _callbackBlock = cb
    }
    
    func reset() {
        dispatch_async(decoderQueue, { () -> Void in
            self._lastTimeStamp = kCMTimeZero
            self._lastSampleReadWasBright = false
            self._bitsBuffer = []
            self._ascii7charBuffer = []
            self._inMessage = false
            self._message = ""
            self.capturedFrames = []
        })
    }
    
    // MARK: addFrames
    
    func addFrame(time: CMTime, _ bright: Bool ) {
        dispatch_async(decoderQueue, { () -> Void in
            self.capturedFrames.append((time,bright))
            if bright != self._lastSampleReadWasBright {
                self.checkFramesForBits()
            }
        })
    }
    
    // MARK: check frames
    
    private var _lastSampleReadWasBright = false
    private var _lastTimeStamp = kCMTimeZero
    private var _bitsBuffer:[Bool] = []
    private var _ascii7charBuffer:[String] = []
    private var _inMessage = false
    private var _message : String = ""
    
    private func checkFramesForBits() {
        
        var modeTimeInSeconds: Float64 = 0;
        
        while capturedFrames.count > 0 {
            var secondsInThisFrame: Float64 = 0
            
            if _lastTimeStamp != kCMTimeZero {
                let presentationTimeStamp = CMTimeSubtract(capturedFrames[0].0, _lastTimeStamp);
                secondsInThisFrame = CMTimeGetSeconds(presentationTimeStamp)
            }
            _lastTimeStamp = capturedFrames[0].0
            
            if _lastSampleReadWasBright == capturedFrames[0].1 {
                modeTimeInSeconds += secondsInThisFrame
            } else {
                if modeTimeInSeconds > 0 {
                    print("Found isBright == \(_lastSampleReadWasBright) duration:\(modeTimeInSeconds)")
                    addBit(modeTimeInSeconds)
                    modeTimeInSeconds = 0
                }
                _lastSampleReadWasBright = capturedFrames[0].1
            }
            capturedFrames.removeFirst()
        }
    }
    
    // MARK: bits
    
    private func addBit(seconds: Float64) {
        
        if seconds > (timeForStartOrEndOfTransmission - errorMarginTime) {
            if _inMessage {
                print("End of Message")
                endMessage()
            } else {
                updateUI("Beginning of Message")
            }
            _inMessage = !_inMessage
            return
        }
        
        if seconds < (timeForZero + errorMarginTime) {
            _bitsBuffer.append(false)
        } else {
            _bitsBuffer.append(true)
        }
        
        if _bitsBuffer.count == 7 {
            var fullWord: String = ""
            for boolVal in _bitsBuffer {
                fullWord += (boolVal ? "1" : "0")
            }
            
            let intWord: Int32? = Int32(fullWord)            
            if intWord != nil  {
                let letterOrDigitValue = binary_decimal(intWord!)
                if letterOrDigitValue <= 127 {
                    
                    let stringValue = NSString(format: "%c", letterOrDigitValue) as String
                    print("Found letter:\(stringValue) binary:\(intWord!) - fullWord:\(fullWord)")
                    _message += String(stringValue)
                    _bitsBuffer.removeAll()
                    
                    updateUI("Received:" + _message)
                    
                } else {
                    // we couldn't get an ASCII char from the 7 bits, there might have been an error, remove 1st bit and try later
                    _bitsBuffer.removeFirst()
                }
            }
        }
    }
    
    private func updateUI (message: String) {
        print(message)
        if _callbackBlock != nil {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self._callbackBlock!(message: message)
            })
        }
    }
    
    private func endMessage() {
        print("We received \(_message)")
        let userInfo = ["result": self._message]
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            NSNotificationCenter.defaultCenter().postNotificationName("CAPTURE_RESULT", object:self, userInfo:userInfo)
        })        
        reset()
    }
}