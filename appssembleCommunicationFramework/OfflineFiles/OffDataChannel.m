//
//  OffDataChannel.m
//  CommunicationFramework
//
//  Created by Dobrean Dragos on 17/06/2017.
//  Copyright © 2017 Appssemble. All rights reserved.
//

#import "OffDataChannel.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

#define dataChannelSyncMessagePrefix @"##DataSync##"

@interface OffDataChannel()<MCNearbyServiceAdvertiserDelegate, MCSessionDelegate, MCNearbyServiceBrowserDelegate>

@property (strong, nonatomic) NSString *roomID;
@property (strong, nonatomic) MCPeerID *localPeerID;

@property (strong, nonatomic) MCNearbyServiceAdvertiser *advertiser;
@property (strong, nonatomic) MCNearbyServiceBrowser *browser;

@property (strong, nonatomic) MCSession *session;

@property (strong, nonatomic) NSMutableArray<MCPeerID *> *peers;

@end

@implementation OffDataChannel

@synthesize state = _state;
@synthesize timeSyncDelegate = _timeSyncDelegate;
@synthesize delegate = _delegate;

- (instancetype)initWithDelegate:(id<DataChannelDelegate>)delegate {
    self = [super init];
    if (self) {
        self.peers = [[NSMutableArray alloc] init];
        self.delegate = delegate;
    }
    
    return self;
}

- (void)connectToRoomWithId:(NSString *)roomId {
    self.roomID = roomId;

    self.localPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    
    
    self.session = [[MCSession alloc] initWithPeer:self.localPeerID
                                  securityIdentity:nil
                              encryptionPreference:MCEncryptionNone];
    self.session.delegate = self;
    
    [self startAdvertising];
    [self startBrowsing];
    
    NSLog(@"Should connect");
}


- (void)sendMessage:(NSString *)message {
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    if (![self.session sendData:data
                        toPeers:self.session.connectedPeers
                       withMode:MCSessionSendDataReliable
                          error:&error]) {
        NSLog(@"[Error] %@", error);
    }
}

- (void)disconnect {
    [self.session disconnect];
}

- (void)sendTimeSyncMessage:(TimeSyncObject *)object {
    NSString *serializedObject = object.toJSONString;
    NSString *message = [dataChannelSyncMessagePrefix stringByAppendingString:serializedObject];
    
    [self sendMessage:message];
}

#pragma mark - Advertise protocol

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context
 invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
    
    // Reject invitations from self
    if ([peerID.displayName isEqualToString:self.localPeerID.displayName]) {
        invitationHandler(NO, nil);
        
        return;
    }
    
    [self.peers removeAllObjects];
    [self.peers addObject:peerID];
    

    
    invitationHandler(YES, self.session);
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    NSLog(@"Did not start advertising");
}

#pragma mark - Browser delegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    
    
    if (![peerID.displayName isEqualToString:self.localPeerID.displayName]) {
        // Create a new session

        [self.browser invitePeer:peerID toSession:self.session withContext:nil timeout:10];
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    [self.delegate dataChannel:self didChangeState:kDataChannelClientStateDisconnected];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    NSLog(@"Could not start browse for peers");
}

#pragma mark - Session delegate

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSString *message =
    [[NSString alloc] initWithData:data
                          encoding:NSUTF8StringEncoding];

    [self receivedString:message];
}


- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID {
    
    NSLog(@"Has recieved stream with name %@, from peer: %@", streamName, peerID.displayName);
}

- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress {
 
    NSLog(@"Has recieved resource with name %@, from peer: %@", resourceName, peerID.displayName);
}

- (void)                    session:(MCSession *)session
 didFinishReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                              atURL:(NSURL *)localURL
                          withError:(nullable NSError *)error {
    
    NSLog(@"Did finish receiving resource with name %@, from peer: %@", resourceName, peerID.displayName);
    
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    NSLog(@"DLD Did change state");
    NSLog(@"State: %ld", (long)state);
    
    switch (state) {
        case MCSessionStateConnected: {
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateConnected];
            
            MCPeerID *otherPeer = self.session.connectedPeers.lastObject;
            
            BOOL initiator = [self.localPeerID.displayName compare:otherPeer.displayName options:NSCaseInsensitiveSearch] == NSOrderedAscending;
            
            [self.delegate dataChannel:self isInitiator:initiator];
            
            break;
        }
        case MCSessionStateConnecting:
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateConnecting];
            break;
            
        case MCSessionStateNotConnected:
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateDisconnected];
            break;
    }
}

#pragma mark - Private methods

- (void)startBrowsing {
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.roomID];
    self.browser.delegate = self;
    
    [self.browser startBrowsingForPeers];
}

- (void)startAdvertising {
    self.advertiser =
    [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID
                                      discoveryInfo:nil
                                        serviceType:self.roomID];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    
    
}

- (void)receivedString:(NSString *)string {
    if ([self isMessageDateSyncMessage:string]) {
        [self recievedTimeSyncMessage:string];
    } else {
        [self.delegate dataChannel:self didRecieveString:string];
    }
}

// Checks if the recieved message is a time sync message
- (BOOL)isMessageDateSyncMessage:(NSString *)value {
    if ([value hasPrefix:dataChannelSyncMessagePrefix]) {
        return YES;
    }
    
    return NO;
}

// If recieved a time sync message, call the delegate with its value
- (void)recievedTimeSyncMessage:(NSString *)value {
    NSString *serializedObject = [value stringByReplacingOccurrencesOfString:dataChannelSyncMessagePrefix withString:@""];
    
    TimeSyncObject *object = [TimeSyncObject fromJSONString:serializedObject];
    
    [self.timeSyncDelegate dataChannel:self didRecieveSyncObject:object];
}

@end
