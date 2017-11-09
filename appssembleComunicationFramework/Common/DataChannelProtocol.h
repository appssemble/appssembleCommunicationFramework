//
//  DataChannelProtocol.h
//  appssembleComunicationFramework
//
//  Created by Dobrean Dragos on 08/09/2017.
//  Copyright © 2017 appssemble. All rights reserved.
//

typedef NS_ENUM(NSInteger, DataChannelClientState) {
    // The connection is closing
    kDataChannelClientStateClosing,
    // Disconnected from servers.
    kDataChannelClientStateDisconnected,
    // Connecting to servers.
    kDataChannelClientStateConnecting,
    // Connected to servers.
    kDataChannelClientStateConnected,
};

@protocol DataChannelProtocol;
@protocol DataChannelDelegate <NSObject>

- (void)dataChannel:(id<DataChannelProtocol>)client didChangeState:(DataChannelClientState)state;
- (void)dataChannel:(id<DataChannelProtocol>)client didRecieveString:(NSString *)value;
- (void)dataChannel:(id<DataChannelProtocol>)client didError:(NSError *)error;
- (void)dataChannel:(id<DataChannelProtocol>)client isInitiator:(BOOL)initiator;

@end

@protocol DataChannelTimeSyncDelegate <NSObject>

- (void)dataChannel:(id<DataChannelProtocol>)client didRecieveSyncObject:(TimeSyncObject *)object;

@end

@protocol DataChannelProtocol <NSObject>

@property (nonatomic, readonly) DataChannelClientState state;

@property (nonatomic, weak) id<DataChannelDelegate> delegate;
@property (nonatomic, weak) id<DataChannelTimeSyncDelegate> timeSyncDelegate;

- (void)connectToRoomWithId:(NSString *)roomId;
- (void)sendMessage:(NSString *)message;
- (void)disconnect;

- (void)sendTimeSyncMessage:(TimeSyncObject *)object;

@end

