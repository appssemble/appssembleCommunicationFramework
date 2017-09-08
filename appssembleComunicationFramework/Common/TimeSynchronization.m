//
//  TimeSynchronization.m
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 07/04/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import "TimeSynchronization.h"
#import "NetAssociation.h"
#import "NSDate+Extension.h"

static NSString *const kTimeSyncAddress = @"time.apple.com";

@interface TimeSynchronization()<NetAssociationDelegate>

@property (strong, nonatomic) id<DataChannelProtocol> dataChannel;

@property (strong, nonatomic) NetAssociation *netAssociation;
@property (strong, nonatomic) NSTimer *timer;

@property (assign, nonatomic) union ntpTime startTime;
@property (assign, nonatomic) int seconds;

@end

@implementation TimeSynchronization

- (instancetype)initWithDataChannel:(id<DataChannelProtocol>)dataChannel {
    self = [super init];
    
    if (self) {
        self.dataChannel = dataChannel;
        self.netAssociation = [[NetAssociation alloc] initWithServerName:kTimeSyncAddress];
        self.netAssociation.delegate = self;
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
    
    self.startTime = [self.netAssociation sendTimeQuery];

    [self sendRequestToPeer];
    
    return self.startTime.floating;
}

- (void)startCountDownFromTimeObject:(TimeSyncObject *)object {
    self.seconds = object.seconds;
    
    union ntpTime time;
    time.floating = object.date;
    
    self.startTime = time;
    
    [self.netAssociation sendTimeQuery];
}

- (void)stopCountDown {
    [self stopTimer];
    
    [self.delegate timeSynchronizationHasFinished:self];
}

- (void)stopCountDownWithoutNotification {
    [self stopTimer];
}

#pragma mark - Net Association delegate

- (void)netAssociationHasFinishSync:(NetAssociation *)net {
    [self stopTimer];
    [self startTimer];
}

#pragma mark - Timer callback

- (void)timerFired:(NSTimer *)timer {
    [self calculateSecondsRemaining];
}

#pragma mark - Private methods

- (void)sendRequestToPeer {
    TimeSyncObject *obj = [TimeSyncObject new];
    obj.date = self.startTime.floating;
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
    union ntpTime currentTime = ntp_time_now();
    
    double difference = ntpDiffSeconds(&_startTime, &currentTime);
    difference -= self.netAssociation.offset;
    
    double timeRemaining = (double)self.seconds - difference;
    
    if (timeRemaining < 0) {
        [self stopTimer];
        [self.delegate timeSynchronizationHasFinished:self];
        
        return;
    }
    
    [self.delegate timeSynchronization:self timeRemaining:timeRemaining];
}


@end
