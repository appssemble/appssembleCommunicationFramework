//
//  NSDate+Extension.m
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 08/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import "NSDate+Extension.h"

@implementation NSDate(Extension)

+ (NSDate *)dateFromString:(NSString *)string {
    NSDate *date = [[self formater] dateFromString:string];
    
    return date;
}

+ (NSString *)stringFromDate:(NSDate *)date {
    NSString *value = [[self formater] stringFromDate:date];
    
    return value;
}

#pragma mark - Private

+ (NSDateFormatter *)formater {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterFullStyle;
    formatter.dateFormat = @"y-MM-dd H:m:ss.SSSS";
    
    return formatter;
}

@end
