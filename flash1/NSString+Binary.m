//
//  NSString+Binary.m
//  flash1
//
//  Created by Fernando Pereira on 8/6/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

#import "NSString+Binary.h"

@implementation NSString (Binary)


- (NSArray*) decomposeStringInBinary
{
    NSMutableArray* array = [NSMutableArray new];
    unichar buffer[self.length + 1];
    [self getCharacters:buffer range:NSMakeRange(0, self.length)];

    for (int i = 0; i<self.length;i++) {
        int charVal = buffer[i];
        
        if ( charVal > 127 ) {
            NSLog(@"Sorry, only ASCII for now - all others will be filtered");
            continue;
        }
        
        NSUInteger binary = decimal_binary(charVal);
        
        NSString* str = [NSString stringWithFormat:@"%07tu", binary];
        [array addObject: str];
    }
    
    return array;
}


+ (NSString*) stringWithBinaryCompose:(NSArray*) binary
{
    char buffer[binary.count];
    char* pBuffer = buffer;
    
    for (NSString* charVal in binary) {
        NSScanner* scanner = [NSScanner scannerWithString:charVal];
        NSInteger intVal = 0;
        if ( [scanner scanInteger:&intVal] ) {
            int charFromBinary = binary_decimal(charVal.intValue);
            *pBuffer++ = charFromBinary;
        }
        else {
            NSLog(@"Error scanning binary values - aborting ");
            return nil;
        }
    }
    *pBuffer = 0;
    NSString* result = [NSString stringWithUTF8String:buffer];
    return result;
}


// http://www.programiz.com/c-programming/examples/binary-decimal-convert

int decimal_binary(int n)  /* Function to convert decimal to binary.*/
{
    int rem, i=1, binary=0;
    while (n!=0)
    {
        rem=n%2;
        n/=2;
        binary+=rem*i;
        i*=10;
    }
    return binary;
}

int binary_decimal(int n) /* Function to convert binary to decimal.*/
{
    int decimal=0, i=0, rem;
    while (n!=0)
    {
        rem = n%10;
        n/=10;
        decimal += rem*pow(2,i);
        ++i;
    }
    return decimal;
}

@end
