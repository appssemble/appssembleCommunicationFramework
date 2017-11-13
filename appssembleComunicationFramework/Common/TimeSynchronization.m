//
//  TimeSynchronization.m
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 07/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import "TimeSynchronization.h"
#import "NSDate+Extension.h"
#import "NHNetworkClock.h"
#import "NSDate+NetworkClock.h"

@interface TimeSynchronization()

@property (strong, nonatomic) id<DataChannelProtocol> dataChannel;

@property (strong, nonatomic) NSTimer *timer;

@property (assign, nonatomic) NSDate *startTime;
@property (assign, nonatomic) int seconds;
@property (strong, nonatomic) NSLock *syncLock;

@end

@implementation TimeSynchronization

- (instancetype)initWithDataChannel:(id<DataChannelProtocol>)dataChannel {
    self = [super init];
    
    if (self) {
        self.dataChannel = dataChannel;
        [[NHNetworkClock sharedNetworkClock] synchronize];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timeSyncHasFinished) name:kNHNetworkTimeSyncCompleteNotification object:nil];
        
        self.syncLock = [[NSLock alloc] init];
    }
    
    return self;
}

#pragma mark - Public methods

- (uint64_t)startSynchronizationWithPeerForSeconds:(int)seconds {
    if (seconds < 5) {
        return 0;
    }

    self.seconds = seconds;
    [self stopTimer];
    
    if ([[NHNetworkClock sharedNetworkClock] isSynchronized]) {
        self.startTime = [NSDate networkDate];
    } else {
        [self.syncLock lock];
        [[NHNetworkClock sharedNetworkClock] synchronize];
        
        [self.syncLock lock];
        self.startTime = [NSDate networkDate];
        [self.syncLock unlock];
    }

    [self startCountDown];
    
    [self sendRequestToPeer];
    
    return self.startTime.timeIntervalSince1970;
}

- (void)startCountDownFromTimeObject:(TimeSyncObject *)object {
    self.seconds = object.seconds;
    
    self.startTime = [NSDate dateWithTimeIntervalSince1970:object.date];
    
    if (![[NHNetworkClock sharedNetworkClock] isSynchronized]) {
        [self.syncLock lock];
        [[NHNetworkClock sharedNetworkClock] synchronize];
        
        [self.syncLock lock];
        [self.syncLock unlock];
    }
    
    [self startCountDown];
}

- (void)stopCountDown {
    [self stopTimer];
    
    [self.delegate timeSynchronizationHasFinished:self];
}

- (void)stopCountDownWithoutNotification {
    [self stopTimer];
}

#pragma mark - Net Association delegate

- (void)timeSyncHasFinished {
    NSLog(@"Finished");
    
    [self.syncLock unlock];
}

#pragma mark - Timer callback

- (void)timerFired:(NSTimer *)timer {
    [self calculateSecondsRemaining];
}

#pragma mark - Private methods

- (void)startCountDown {
    [self stopTimer];
    [self startTimer];
}

- (void)sendRequestToPeer {
    TimeSyncObject *obj = [TimeSyncObject new];
    obj.date = self.startTime.timeIntervalSince1970;
    obj.seconds = self.seconds;
    
    NSString *json = [obj toJSONString];
    
    TimeSyncObject *other = [TimeSyncObject fromJSONString:json];
    
    [self.dataChannel sendTimeSyncMessage:other];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
}

- (void)calculateSecondsRemaining {
    NSDate *currentDate = [NSDate date];
    
    double timeRemaining = [currentDate timeIntervalSinceDate:self.startTime];
    
    if (timeRemaining < 0) {
        [self stopTimer];
        [self.delegate timeSynchronizationHasFinished:self];
        
        return;
    }
    
    [self.delegate timeSynchronization:self timeRemaining:timeRemaining];
}


@end
