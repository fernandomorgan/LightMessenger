//
//  Utilities.m
//  flash1
//
//  Created by Fernando Pereira on 8/6/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

// Based on
//  CFMagicEvents.m
//  Copyright (c) 2013 Cédric Floury
// https://github.com/zuckerbreizh/CFMagicEventsDemo

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define NUMBER_OF_FRAME_PER_S 5
#define BRIGHTNESS_THRESHOLD 70
#define MIN_BRIGHTNESS_THRESHOLD 10

static int  _lastTotalBrightnessValue = 0;


int calculateLevelOfBrightness (int pCurrentBrightness)
{
    return (pCurrentBrightness*100) /_lastTotalBrightnessValue;
}


BOOL getBrightness(CMSampleBufferRef sampleBuffer)
{
    BOOL rc = YES;
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
        UInt8 *base = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        
        //  calculate average brightness in a simple way
        
        size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width            = CVPixelBufferGetWidth(imageBuffer);
        size_t height           = CVPixelBufferGetHeight(imageBuffer);
        UInt32 totalBrightness  = 0;
        
        for (UInt8 *rowStart = base; height; rowStart += bytesPerRow, height --)
        {
            size_t columnCount = width;
            for (UInt8 *p = rowStart; columnCount; p += 4, columnCount --)
            {
                UInt32 value = (p[0] + p[1] + p[2]);
                totalBrightness += value;
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        if(_lastTotalBrightnessValue==0) _lastTotalBrightnessValue = totalBrightness;
        
        if ( calculateLevelOfBrightness(totalBrightness) < BRIGHTNESS_THRESHOLD )
        {
            if(calculateLevelOfBrightness(totalBrightness)>MIN_BRIGHTNESS_THRESHOLD)
            {
                rc = NO;
            }
            else //Mobile phone is probably on a table (too dark - camera obturated)
            {
                rc = YES;
            }
        }
        else{
            _lastTotalBrightnessValue = totalBrightness;
            rc = YES;
        }
    }
    return rc;
}

