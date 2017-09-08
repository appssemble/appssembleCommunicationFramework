//
//  NSDate+Extension.h
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 08/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate(Extension)

+ (NSDate *)dateFromString:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date;

@end
