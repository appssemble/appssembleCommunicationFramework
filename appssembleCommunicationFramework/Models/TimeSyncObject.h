//
//  TimeSyncObject.h
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 08/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TimeSyncObject : NSObject

@property (assign, nonatomic) unsigned long long date;
@property (assign, nonatomic) int seconds;

+ (TimeSyncObject *)fromJSONString:(NSString *)string;

- (NSString *)toJSONString;


@end
