//
//  OffDataChannel.h
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 17/06/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimeSyncObject.h"
#import "DataChannelProtocol.h"


@interface OffDataChannel : NSObject<DataChannelProtocol>

- (instancetype)initWithDelegate:(id<DataChannelDelegate>)delegate;

@end
