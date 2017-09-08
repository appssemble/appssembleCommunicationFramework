//
//  DataChannel.h
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 25/03/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimeSyncObject.h"
#import "DataChannelProtocol.h"


@interface DataChannel : NSObject<DataChannelProtocol>

// The addres of the ard server, if not set will use a default test one from Google
@property (nonatomic, strong) NSString *ardServerAddress;

// The addres of the STUN server, if not set will use a default test one from Google
@property (nonatomic, strong) NSString *stunServerAddress;

// The addres of the TURN server, if not set will use a default test one
@property (nonatomic, strong) NSString *turnServerAddress;

// The username and password of the TURN server
@property (nonatomic, strong) NSString *turnServerUsername;
@property (nonatomic, strong) NSString *turnServerPassword;


- (instancetype)initWithDelegate:(id<DataChannelDelegate>)delegate;


@end
