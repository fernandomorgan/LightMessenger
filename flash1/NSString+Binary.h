//
//  NSString+Binary.h
//  flash1
//
//  Created by Fernando Pereira on 8/6/15.
//  Copyright © 2015 Autokrator LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Binary)

- (NSArray*) decomposeStringInBinary;
+ (NSString*) stringWithBinaryCompose:(NSArray*) binary;

@end
