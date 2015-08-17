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
typealias voidCallbackForEndClosure = () -> Void

// MARK: timing rules for 0s 1s and start/end transmission

let timeForZero: NSTimeInterval = 0.5
let timeForOne: NSTimeInterval  = 1.2
let timeForStartOrEndOfTransmission: NSTimeInterval = 2
let errorMarginTime: NSTimeInterval = 0.3

// DECODER Class initialization
var decoder = Decoder()

class FlashControl : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: Camera (both send and receive
    
    var backCamera: AVCaptureDevice?
    
    // MARK: AVFoundation for receive
    
    var captureSession: AVCaptureSession?
    let receiveDispatchQueue = dispatch_queue_create("com.troezen.flash1", DISPATCH_QUEUE_SERIAL)
    
    // MARK: Sending lifecycle
    
    private var _cancelSend = false
    
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
    
    func sendAMessage(message: NSArray, updateStatus:voidCallbackForStatusMessageClosure?) {
        
        _cancelSend = false
        initializeSendingMessage()
        do {
            if _cancelSend {
                return
            }
            // signal start transmission
            if updateStatus != nil {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    updateStatus!(message: "Starting Transmission")
                })
            }
            try sendOneBit(timeForStartOrEndOfTransmission)
            for numberToSend in message {
                let str = String(numberToSend)
                if updateStatus != nil {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        updateStatus!(message: "Sending " + str)
                    })
                }
                
                for char in str.characters {
                    if char == "1" {
                        try sendOneBit(timeForOne)
                    } else {
                        try sendOneBit(timeForZero)
                    }
                }
            }
            // signal end transmission
            if updateStatus != nil {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    updateStatus!(message: "Ending Transmission")
                })
            }
            try sendOneBit(timeForStartOrEndOfTransmission)
        } catch {
            print("Something bad happened! Help! Help!")
        }
    }
    
    func cancelMessage() {
        _cancelSend = true
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
            //camera.unlockForConfiguration()
            
            NSThread.sleepForTimeInterval(timeToSend)
            
            // stop
            //try camera.lockForConfiguration()
            camera.torchMode = AVCaptureTorchMode.Off
            camera.unlockForConfiguration()
        }
        _bitSentAsLight = !_bitSentAsLight
    }
    
    
    // Mark: Receiving Messages
    
    func startReceivingMessage(callback: voidCallbackForStatusMessageClosure?) {
        guard  let camera: AVCaptureDevice = backCamera  else { return }

        if callback != nil {
            decoder.setCallbackBlock( callback! )
        }
        setBestFrameRate()
        
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
        captureSession?.startRunning()
    }
    
    func stopReceivingMessage() {
        captureSession?.stopRunning()
        decoder.reset()
    }
    
    // MARK: Capture Delegate
    func captureOutput(captureOutput: AVCaptureOutput!,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
        fromConnection connection: AVCaptureConnection!) {
            let isBright = getBrightness(sampleBuffer)
            let currentTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let nrSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            if nrSamples != 1 {
                print("Not handling samples > 1 - nrSamples=\(nrSamples)")
            }                
            decoder.addFrame(currentTimeStamp, isBright)
    }
    
    private func setBestFrameRate() {
        guard  let camera: AVCaptureDevice = backCamera  else { return }
        
        var bestFormat:AVCaptureDeviceFormat?
        var bestFrameRate: AVFrameRateRange?
        
        for formatObj in camera.formats {
            let format = formatObj as! AVCaptureDeviceFormat
            for rangeObj in format.videoSupportedFrameRateRanges {
                let range = rangeObj as! AVFrameRateRange
                if bestFrameRate == nil || range.maxFrameRate > bestFrameRate?.maxFrameRate {
                    bestFrameRate = range
                    bestFormat = format
                }
            }
        }
        
        if bestFormat != nil && bestFrameRate != nil {
            do {
                try camera.lockForConfiguration()
                camera.activeFormat = bestFormat
                camera.activeVideoMinFrameDuration = (bestFrameRate?.minFrameDuration)!
                camera.activeVideoMaxFrameDuration = (bestFrameRate?.maxFrameDuration)!
                camera.unlockForConfiguration()
            } catch {
                print("Error trying to set the camera to best frame rate")
            }
        }
    }
}
