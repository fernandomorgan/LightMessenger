//
//  FlashControl.swift
//  flash1
//
//  Created by Fernando Pereira on 8/6/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

import Foundation
import AVFoundation

/**
* Protocol works by flash of lights AND dark periods. A short flash/dark is a 0, a longer one a 1
* letters/numbers are encoded in 7bits, represented by alternate flashes and dark periods
* for example, a is 1100001
* this is be  a timeForOne either has a flash or a dark period followed by the same but in the reverse
* so every 7 bits is a word
* we have special times for start or end transmissions
*
* if the only transmission is a the letter "aZ", 1100001,1011010 we will have the following :
*
*  - flash of light with time == timeForStartOrEndOfTransmission
*  - bit 0: timeForOne dark   -- "a"
*  - bit 1: timeforOne light
*  - bit 2: timeForZero dark
*  - bit 3: timeForZero light
*  - bit 4: timeForZero dark
*  - bit 5: timeForZero light
*  - bit 6: timeforOne dark  ---- end of "a" (always 7 bits)
*  - bit 0: timeForOne light --- "Z"
*  - bit 1: timeForZero dark
*  - bit 2: timeforOne light
*  - bit 3: timeforOne dark
*  - bit 4: timeForZero light
*  - bit 5: timeforOne dark
*  - bit 6: timeForZero light ---- end of "Z" (always 7 bits)
*  - dark with time == timeForStartOrEndOfTransmission
*
*
* we both start and end transmission by sending a special (longer) flash signal
* this way, any light sent before is ignored
*
* TODO: error correction: we can do a simple checksum and if it fails, add a way to ask for the last bit to be repeated
*
*
*/

typealias voidCallbackForStatusMessageClosure = (message : String) -> Void

class FlashControl : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: Camera (both send and receive
    
    var backCamera: AVCaptureDevice?
    
    // MARK: AVFoundation for receive
    
    var captureSession: AVCaptureSession?
    let receiveDispatchQueue = dispatch_queue_create( "com.troezen.flash1", DISPATCH_QUEUE_SERIAL)
    private var _callbackBlock : voidCallbackForStatusMessageClosure?
    
    // MARK: timing rules for 0s 1s and start/end transmission
    
    let timeForZero: NSTimeInterval = 0.2
    let timeForOne: NSTimeInterval  = 0.4
    let timeForStartOrEndOfTransmission: NSTimeInterval = 1
    
    override init () {
        for device in AVCaptureDevice.devices() {
            if (device.hasMediaType(AVMediaTypeVideo)) {
                if(device.position == AVCaptureDevicePosition.Back) {
                    backCamera = device as? AVCaptureDevice
                    break
                }
            }
        }
        
        if backCamera == nil {
            print("We didn't find any camera in the back of the device :(")
        } else {
            if !backCamera!.hasTorch {
                print("The camera has no torch this isn't goint to work")
            }
        }        
        super.init()
    }
    
    // MARK: Sending Messages
    
    func sendAMessage(message: NSArray) {
        initializeSendingMessage()
        do {
            // signal start transmission
            try sendOneBit(timeForStartOrEndOfTransmission)
            for numberToSend in message {
                let str = String(numberToSend)
                for char in str.characters {
                    if char == "1" {
                        try sendOneBit(timeForOne)
                    } else {
                        try sendOneBit(timeForZero)
                    }
                }
            }
            // signal end transmission
            try sendOneBit(timeForStartOrEndOfTransmission)
        } catch {
            print("Something bad happened! Help! Help!")
        }
        
    }
    
    // controls if Bit is sent as light or dark period
    private var _bitSentAsLight = true
    
    private func initializeSendingMessage() {
        _bitSentAsLight = false
    }
    
    
    private func sendOneBit(timeToSend: NSTimeInterval) throws{
        
        guard  let camera: AVCaptureDevice = backCamera  else { return }
        
        if _bitSentAsLight {
            NSThread.sleepForTimeInterval(timeToSend)
        } else {
            // start
            try camera.lockForConfiguration()
            try camera.setTorchModeOnWithLevel(1.0)
            camera.unlockForConfiguration()
            
            NSThread.sleepForTimeInterval(timeToSend)
            
            // stop
            try camera.lockForConfiguration()
            camera.torchMode = AVCaptureTorchMode.Off
            camera.unlockForConfiguration()
        }
        
        _bitSentAsLight = !_bitSentAsLight
    }
    
    
    // Mark: Receiving Messages
    
    func startReceivingMessage(callback: voidCallbackForStatusMessageClosure?) {
        guard  let camera: AVCaptureDevice = backCamera  else { return }

        if callback != nil {
            _callbackBlock = callback
        }
        /*
        do {
            try camera.lockForConfiguration()
        } catch {}
        camera.activeVideoMinFrameDuration = CMTimeMake(10, 60)
        camera.activeVideoMaxFrameDuration = CMTimeMake(10, 60)
        camera.unlockForConfiguration()
        */
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPresetLow
        var videoCapture: AVCaptureDeviceInput?
        do {
            videoCapture = try AVCaptureDeviceInput(device: camera)
        } catch {
            print("Couldn't setup video capture")
        }
        captureSession?.addInput(videoCapture)
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        
        videoDataOutput.setSampleBufferDelegate(self, queue: receiveDispatchQueue)
        captureSession?.addOutput(videoDataOutput)
        
        resetMessageReceiving()
        captureSession?.startRunning()
        
    }
    
    func stopReceivingMessage() {
        endCapture()
    }
    
    private func endCapture() {
        
        captureSession?.stopRunning()
        
        _ascii7charBuffer = []
        _lastTimeStamp = kCMTimeZero
        _callbackBlock = nil
        
        let result = NSString(binaryCompose: _readBuffer as [AnyObject])
        print("We received \(result)")
        let userInfo = ["result": result]
        NSNotificationCenter.defaultCenter().postNotificationName("CAPTURE_RESULT", object:self, userInfo:userInfo)
    }
    
    // MARK: Capture Delegate
    
    private var _lastSampleReadWasBright = false
    private var _currentSampleBrightnessTime: Float64 = 0
    private var _readBuffer = NSMutableArray()
    private var _ascii7charBuffer:[Int] = []
    private var _lastTimeStamp = kCMTimeZero
    private var _messageHasStarted = false
    
    private func resetMessageReceiving() {
        _lastSampleReadWasBright = false
        _currentSampleBrightnessTime = 0
        _readBuffer = NSMutableArray()
        _ascii7charBuffer = []
        _lastTimeStamp = kCMTimeZero
        _messageHasStarted = false
    }
    
    private func logStatus (message: String) {
        
        if _callbackBlock != nil {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self._callbackBlock!(message: message)
            })
        }
        
        print(message)
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
        fromConnection connection: AVCaptureConnection!) {
            
            let isBright = getBrightness(sampleBuffer)
            
            let nrSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            let currentTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let presentationTimeStamp = CMTimeSubtract(currentTimeStamp, _lastTimeStamp);

            _lastTimeStamp = currentTimeStamp
            let seconds = CMTimeGetSeconds(presentationTimeStamp)
            
            func endWord () {
                var fullWord: String = ""
                for intVal in _ascii7charBuffer {
                    if intVal == 1 {
                        fullWord += "1"
                    } else {
                        fullWord += "0"
                    }
                }
                logStatus("Word: " +  fullWord)
                _readBuffer.addObject( NSString(string: fullWord) )
                _ascii7charBuffer = []
            }
            
            if  isBright != _lastSampleReadWasBright {
                
                // signal timeForStartOrEndOfTransmission controls start/end of messasges
                if _currentSampleBrightnessTime > timeForStartOrEndOfTransmission {
                    if _messageHasStarted {                        
                        endWord()
                        logStatus("Ending Message Receive")
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.endCapture()
                        })
                    // the message start is ALWAYS a flash, never a dark period
                    } else if isBright {
                        logStatus("Starting Message Receive")
                        _messageHasStarted = true
                    }
                }
                    
                if _messageHasStarted {
                    if _currentSampleBrightnessTime > timeForOne {
                        _ascii7charBuffer.append( 1 )
                    }
                        
                    else {
                        _ascii7charBuffer.append( 0 )
                    }
                    
                    if _ascii7charBuffer.count == 7 {
                        endWord()
                    }
                }
                _currentSampleBrightnessTime = 0
                _lastSampleReadWasBright = isBright
            }
            // no change in brightness, we just add time
            else {
                _currentSampleBrightnessTime += seconds
            }
    }
}




