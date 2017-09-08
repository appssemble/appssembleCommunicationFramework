//
//  TimeSyncObject.m
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 08/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import "TimeSyncObject.h"
#import "NSDate+Extension.h"

static NSString *const kTimeSyncDateKey = @"date";
static NSString *const kTimeSyncSecondsKey = @"seconds";

@implementation TimeSyncObject

+ (TimeSyncObject *)fromJSONString:(NSString *)string {
    
    NSError *error;
    
    NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:objectData
                                                       options:NSJSONReadingMutableContainers
                                                         error:&error];
    
    if (!jsonDictionary) {
        NSLog(@"Got an error: %@", error);
    } else {
        TimeSyncObject *obj = [TimeSyncObject new];
        
        NSNumber *date = jsonDictionary[kTimeSyncDateKey];
        NSNumber *seconds = jsonDictionary[kTimeSyncSecondsKey];
        
        obj.date = date.unsignedLongLongValue;
        obj.seconds = seconds.intValue;
        
        return obj;
    }
    
    return nil;
}

- (NSString *)toJSONString {

    NSDictionary *values = @{kTimeSyncDateKey:[NSNumber numberWithUnsignedLongLong:self.date],
                             kTimeSyncSecondsKey:@(self.seconds)};
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:values
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    if (!jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        return jsonString;
    }
    
    return nil;
}


@end
