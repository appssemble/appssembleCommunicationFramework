//
//  TimeSynchronization.h
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 07/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataChannel.h"

@class TimeSynchronization;
@protocol TimeSynchronizationDelegate <NSObject>

- (void)timeSynchronization:(TimeSynchronization *)sync timeRemaining:(double)seconds;
- (void)timeSynchronizationHasFinished:(TimeSynchronization *)sync;

@end

@interface TimeSynchronization : NSObject

@property (weak, nonatomic) id<TimeSynchronizationDelegate> delegate;

- (instancetype)initWithDataChannel:(id<DataChannelProtocol>)dataChannel;

/** Starts the synchronization for the given seconds
 @param seconds - must be equal higher then 5
 @return date - the current date used for synchronization,
    nil if the given seconds is lower then 5
 */
- (uint64_t)startSynchronizationWithPeerForSeconds:(int)seconds;

- (void)startCountDownFromTimeObject:(TimeSyncObject *)object;

- (void)stopCountDown;
- (void)stopCountDownWithoutNotification;

@end
