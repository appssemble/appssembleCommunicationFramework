#import "DataChannel.h"

#import "ARDMessageResponse.h"
#import "ARDRegisterResponse.h"
#import "ARDSignalingMessage.h"
#import "ARDUtilities.h"
#import "ARDWebSocketChannel.h"
#import "RTCICECandidate+JSON.h"
#import "RTCICEServer+JSON.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescription+JSON.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCDataChannel.h"


#define dataChannelSyncMessagePrefix @"##DataSync##"
#define dataChannelName @"CommunicationFrameworkDataChannel"

static NSString *kARDRoomServerRegisterFormat   = @"%@/join/%@";
static NSString *kARDRoomServerMessageFormat    = @"%@/message/%@/%@";
static NSString *kARDRoomServerByeFormat        = @"%@/leave/%@/%@";

static NSString *kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger kARDAppClientErrorUnknown = -1;
static NSInteger kARDAppClientErrorRoomFull = -2;
static NSInteger kARDAppClientErrorCreateSDP = -3;
static NSInteger kARDAppClientErrorSetSDP = -4;
static NSInteger kARDAppClientErrorNetwork = -5;
static NSInteger kARDAppClientErrorInvalidClient = -6;
static NSInteger kARDAppClientErrorInvalidRoom = -7;

@interface DataChannel () <ARDWebSocketChannelDelegate, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate, RTCDataChannelDelegate>

@property (nonatomic, strong) ARDWebSocketChannel *channel;
@property (nonatomic, strong) RTCPeerConnection *peerConnection;
@property (nonatomic, strong) RTCPeerConnectionFactory *factory;
@property (nonatomic, strong) NSMutableArray *messageQueue;

@property(nonatomic, assign) BOOL isTurnComplete;
@property(nonatomic, assign) BOOL hasReceivedSdp;
@property(nonatomic, readonly) BOOL isRegisteredWithRoomServer;

@property(nonatomic, strong) NSString *roomId;
@property(nonatomic, strong) NSString *clientId;
@property(nonatomic, assign) BOOL isInitiator;

@property(nonatomic, strong) NSMutableArray *iceServers;
@property(nonatomic, strong) NSURL *webSocketURL;
@property(nonatomic, strong) NSURL *webSocketRestURL;

@property (strong, nonatomic) RTCDataChannel *dataChannel;

@end

@implementation DataChannel

@synthesize state = _state;
@synthesize timeSyncDelegate = _timeSyncDelegate;
@synthesize delegate = _delegate;

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(id<DataChannelDelegate>)delegae {
    if (self = [super init]) {
        self.delegate = delegae;
        self.factory = [[RTCPeerConnectionFactory alloc] init];
        self.messageQueue = [NSMutableArray array];
        self.iceServers = [NSMutableArray arrayWithObjects:[self defaultSTUNServer], [self defaultTURNServer], nil];
        
        self.ardServerAddress = @"https://apprtc.appspot.com";
        
        self.turnServerAddress = @"turn:numb.viagenie.ca";
        self.stunServerAddress = @"stun:stun.l.google.com:19302";
        
        self.turnServerUsername = @"office@appssemble.com";
        self.turnServerPassword = @"qwertyuio1";
    }
    
    return self;
}

- (void)dealloc {
    [self disconnect];
}

- (void)startDataChannel {
    // Data channel configs
    
    RTCDataChannelInit *dataInit = [[RTCDataChannelInit alloc] init];
    dataInit.isNegotiated = YES;
    dataInit.isOrdered = YES;
    dataInit.maxRetransmits = 30;
    dataInit.maxRetransmitTimeMs = 30000;
    dataInit.streamId = 1;
    
    self.dataChannel = [self.peerConnection createDataChannelWithLabel:dataChannelName config:dataInit];
    self.dataChannel.delegate = self;
}

#pragma mark - Data channel delegate

// Called when the data channel state has changed.
- (void)channelDidChangeState:(RTCDataChannel*)channel {
    NSString *dataChannelState = nil;
    
    switch (channel.state) {
        case kRTCDataChannelStateClosed:
            dataChannelState = @"Data channel closed";
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateDisconnected];
            break;
        case kRTCDataChannelStateOpen:
            dataChannelState = @"Open";
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateConnected];
        case kRTCDataChannelStateClosing:
            dataChannelState = @"Closing";
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateDisconnected];
        case kRTCDataChannelStateConnecting:
            dataChannelState = @"Connecting";
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateConnected];
            
        default:
            break;
    }
    
    if (dataChannelState != nil) {
        NSLog(@"Data channel has changed state to: %@", dataChannelState);
    }
}

// Called when a data buffer was successfully received.
- (void)channel:(RTCDataChannel*)channel didReceiveMessageWithBuffer:(RTCDataBuffer*)buffer {
    NSString *receivedData;
    NSString *dataType;

    if(buffer.isBinary) {
        dataType = @"binary";
        NSLog(@"Binary data not implemented!");
    } else {
        dataType = @"string";
        receivedData = [[NSString alloc] initWithData:buffer.data encoding:NSUTF8StringEncoding];
    }
    
    NSLog(@"Received string: %@", receivedData);
    
    if ([self isMessageDateSyncMessage:receivedData]) {
        [self recievedTimeSyncMessage:receivedData];
    } else {
        [self.delegate dataChannel:self didRecieveString:receivedData];
    }
}

#pragma mark - Public methods

- (void)sendMessage:(NSString *)message {
    [self sendStringOnDataChannel:message];
}

- (void)connectToRoomWithId:(NSString *)roomId {
    NSParameterAssert(roomId.length);
    NSParameterAssert(self.state == kDataChannelClientStateDisconnected);
    self.state = kDataChannelClientStateConnecting;
    
    __weak DataChannel *weakSelf = self;
    
    // Register with room server.
    [self registerWithRoomServerForRoomId:roomId
                        completionHandler:^(ARDRegisterResponse *response) {
                            DataChannel *strongSelf = weakSelf;
                            
                            // If register has failed report an error
                            if (!response || response.result != kARDRegisterResultTypeSuccess) {
                                NSLog(@"Failed to register with room server. Result:%d",
                                      (int)response.result);
                                
                                [strongSelf disconnect];
                                NSDictionary *userInfo = @{
                                                           NSLocalizedDescriptionKey: @"Room is full.",
                                                           };
                                NSError *error =
                                [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                           code:kARDAppClientErrorRoomFull
                                                       userInfo:userInfo];
                                [strongSelf.delegate dataChannel:strongSelf didError:error];
                                return;
                            }
                            
                            // Is registered with the room server
                            NSLog(@"Registered with room server.");
                            
                            strongSelf.roomId = response.roomId;
                            strongSelf.clientId = response.clientId;
                            strongSelf.isInitiator = response.isInitiator;
                            
                            // Add messages in message queu
                            for (ARDSignalingMessage *message in response.messages) {
                                if (message.type == kARDSignalingMessageTypeOffer ||
                                    message.type == kARDSignalingMessageTypeAnswer) {
                                    strongSelf.hasReceivedSdp = YES;
                                    [strongSelf.messageQueue insertObject:message atIndex:0];
                                } else {
                                    [strongSelf.messageQueue addObject:message];
                                }
                            }
                            
                            // Set the URLS and start the colider and signaling
                            strongSelf.webSocketURL = response.webSocketURL;
                            strongSelf.webSocketRestURL = response.webSocketRestURL;
                            
                            [strongSelf registerWithColliderIfReady];
                            [strongSelf startSignalingIfReady];
                        }];
}

- (void)disconnect {
    // If already disconnected do nothing
    if (self.state == kDataChannelClientStateDisconnected) {
        return;
    }
    
    // If register, undregister
    if (self.isRegisteredWithRoomServer) {
        [self unregisterWithRoomServer];
    }
    
    // If already exists a communication channel, and we are connected
    // send a bye message
    if (self.channel) {
        if (self.channel.state == kARDWebSocketChannelStateRegistered) {
            // Tell the other client we're hanging up.
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            NSData *byeData = [byeMessage JSONData];
            [self.channel sendData:byeData];
        }
        // Disconnect from collider.
        self.channel = nil;
    }
    
    // Reset all the values
    self.clientId = nil;
    self.roomId = nil;
    self.isInitiator = NO;
    self.hasReceivedSdp = NO;
    self.messageQueue = [NSMutableArray array];
    self.peerConnection = nil;
    self.state = kDataChannelClientStateDisconnected;
}

// Send a time synchronization message
- (void)sendTimeSyncMessage:(TimeSyncObject *)object {
    NSString *serializedObject = object.toJSONString;
    NSString *message = [dataChannelSyncMessagePrefix stringByAppendingString:serializedObject];
    
    [self sendMessage:message];
}

#pragma mark - ARDWebSocketChannelDelegate

- (void)channel:(ARDWebSocketChannel *)channel didReceiveMessage:(ARDSignalingMessage *)message {
    switch (message.type) {
        case kARDSignalingMessageTypeOffer:
        case kARDSignalingMessageTypeAnswer:
            // If has recieved an answer, put it first in the message queue
            self.hasReceivedSdp = YES;
            [self.messageQueue insertObject:message atIndex:0];
            break;
        case kARDSignalingMessageTypeCandidate:
            // Add the candidate
            [self.messageQueue addObject:message];
            break;
        case kARDSignalingMessageTypeBye:
            // Process directlly the message as its a bye message, meaning the clinet has disconnected
            [self processSignalingMessage:message];
            return;
    }
    
    // Process the messages
    [self drainMessageQueueIfReady];
}

- (void)channel:(ARDWebSocketChannel *)channel didChangeState:(ARDWebSocketChannelState)state {
    switch (state) {
        case kARDWebSocketChannelStateOpen:
            break;
        case kARDWebSocketChannelStateRegistered:
            break;
        case kARDWebSocketChannelStateClosed:
        case kARDWebSocketChannelStateError:
            // If the web socket channel has closed or there is an error, disconnect
            [self disconnect];
            break;
    }
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %d", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    NSString *state;

    switch(newState) {
        case RTCICEConnectionNew:
            state = @"new";
            break;
        case RTCICEConnectionChecking:
            state = @"checking";
            break;
        case RTCICEConnectionClosed:
            state = @"closed";
            break;
        case RTCICEConnectionCompleted:
            state = @"completed";
            break;
        case RTCICEConnectionConnected:
            state = @"connected";
            [self.delegate dataChannel:self didChangeState:kDataChannelClientStateConnected];
            break;
        case RTCICEConnectionDisconnected:
            state = @"disconnected";
            break;
        case RTCICEConnectionFailed:
            state = @"failed";
            break;
        case RTCICEConnectionMax:
            state = @"max";
            break;
    }
    
    NSLog(@"ICE connection state changed: %@", state);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    NSString *state;
    
    switch(newState) {
        case RTCICEGatheringNew:
            state = @"new";
            break;
        case RTCICEGatheringGathering:
            state = @"gathering";
            break;
        case RTCICEGatheringComplete:
            state = @"complete";
            break;
    }
    
    NSLog(@"ICE gathering state changed: %@", state);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateMessage *message =  [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
    NSLog(@"added streem");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    NSLog(@"Data channel was open");
}

#pragma mark - Answer/Offer methods

- (void)createLocalOffer {
    [self.peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];
}

- (void)createAnswer {
    [self.peerConnection createAnswerWithDelegate:self constraints:[self defaultPeerConnectionConstraints]];
}

- (void)setRemoteOffer:(RTCSessionDescription *)sd {
    [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:sd];
}

#pragma mark - RTCSessionDescriptionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Report an error
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
            [self disconnect];
            
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorCreateSDP
                                   userInfo:userInfo];
            
            [self.delegate dataChannel:self didError:sdpError];
            return;
        }
        
        // Set the local description and send a message
        [self.peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sdp];
        
        ARDSessionDescriptionMessage *message = [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
            [self.delegate dataChannel:self didError:sdpError];
            return;
        }
        
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!self.isInitiator && !self.peerConnection.localDescription) {
            [self createAnswer];
            
        }
    });
}

#pragma mark - Private methods

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

// Sends a string on the data channel
- (void)sendStringOnDataChannel:(NSString *)value {
    NSString *string = value;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    [self sendDataOnDataChannel:data isBinary:NO];
}

// Sends data on the data channel
- (void)sendDataOnDataChannel:(NSData *)data isBinary:(BOOL)isBinary {
    RTCDataChannel *channel = self.dataChannel;
    
    @try
    {
        [channel sendData:[[RTCDataBuffer alloc] initWithData:data isBinary:isBinary]];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception could not send data!!");
    }
}

- (BOOL)isRegisteredWithRoomServer {
    return self.clientId.length;
}

- (void)startSignalingIfReady {
   // if (!self.isTurnComplete ||
    if (!self.isRegisteredWithRoomServer) {
        return;
    }
    self.state = kDataChannelClientStateConnected;
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    self.peerConnection = [self.factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
    
    [self startDataChannelFlow];
}

- (void)startDataChannelFlow {
    [self startDataChannel];
    
    if (self.isInitiator) {
        [self sendOffer];
    } else {
        [self waitForAnswer];
    }
}

- (void)sendOffer {
    [self createLocalOffer];
}

- (void)waitForAnswer {
    [self drainMessageQueueIfReady];
}

- (void)drainMessageQueueIfReady {
    if (!self.peerConnection || !self.hasReceivedSdp) {
        return;
    }
    
    for (ARDSignalingMessage *message in _messageQueue) {
        [self processSignalingMessage:message];
    }
    
    [self.messageQueue removeAllObjects];
}

- (void)processSignalingMessage:(ARDSignalingMessage *)message {
    NSParameterAssert(self.peerConnection ||
                      message.type == kARDSignalingMessageTypeBye);
    
    switch (message.type) {
        case kARDSignalingMessageTypeOffer:
        case kARDSignalingMessageTypeAnswer: {
            ARDSessionDescriptionMessage *sdpMessage = (ARDSessionDescriptionMessage *)message;
            
            RTCSessionDescription *description = sdpMessage.sessionDescription;
            
            [self setRemoteOffer:description];
            break;
        }
            
        case kARDSignalingMessageTypeCandidate: {
            ARDICECandidateMessage *candidateMessage = (ARDICECandidateMessage *)message;
            
            [self.peerConnection addICECandidate:candidateMessage.candidate];
            break;
        }
        case kARDSignalingMessageTypeBye:
            // Other client disconnected.
            [self disconnect];
            break;
    }
}

- (void)sendSignalingMessage:(ARDSignalingMessage *)message {
    if (self.isInitiator) {
        [self sendSignalingMessageToRoomServer:message completionHandler:nil];
    } else {
        [self sendSignalingMessageToCollider:message];
    }
}

#pragma mark - Room server methods

- (void)registerWithRoomServerForRoomId:(NSString *)roomId
                      completionHandler:(void (^)(ARDRegisterResponse *))completionHandler {
    NSString *urlString =
    [NSString stringWithFormat:kARDRoomServerRegisterFormat, self.ardServerAddress, roomId];
    NSURL *roomURL = [NSURL URLWithString:urlString];
    NSLog(@"Registering with room server.");
    __weak DataChannel *weakSelf = self;
    [NSURLConnection sendAsyncPostToURL:roomURL
                               withData:nil
                      completionHandler:^(BOOL succeeded, NSData *data) {
                          DataChannel *strongSelf = weakSelf;
                          
                          if (!succeeded) {
                              NSError *error = [self roomServerNetworkError];
                              
                              [strongSelf.delegate dataChannel:strongSelf didError:error];
                              completionHandler(nil);
                              
                              return;
                          }
                          
                          ARDRegisterResponse *response = [ARDRegisterResponse responseFromJSONData:data];
                          completionHandler(response);
                      }];
}

- (void)sendSignalingMessageToRoomServer:(ARDSignalingMessage *)message
                       completionHandler:(void (^)(ARDMessageResponse *))completionHandler {
    NSData *data = [message JSONData];
    NSString *urlString = [NSString stringWithFormat:kARDRoomServerMessageFormat, self.ardServerAddress, self.roomId, self.clientId];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSLog(@"C->RS POST: %@", message);
    
    __weak DataChannel *weakSelf = self;
    
    [NSURLConnection sendAsyncPostToURL:url
                               withData:data
                      completionHandler:^(BOOL succeeded, NSData *data) {
                          DataChannel *strongSelf = weakSelf;
                          if (!succeeded) {
                              NSError *error = [self roomServerNetworkError];
                              [strongSelf.delegate dataChannel:strongSelf didError:error];
                              return;
                          }
                          
                          ARDMessageResponse *response = [ARDMessageResponse responseFromJSONData:data];
                         
                          NSError *error = nil;
                          switch (response.result) {
                              case kARDMessageResultTypeSuccess:
                                  break;
                              case kARDMessageResultTypeUnknown:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorUnknown
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Unknown error.",
                                                                    }];
                              case kARDMessageResultTypeInvalidClient:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorInvalidClient
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Invalid client.",
                                                                    }];
                                  break;
                              case kARDMessageResultTypeInvalidRoom:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorInvalidRoom
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Invalid room.",
                                                                    }];
                                  break;
                          };
                          
                          if (error) {
                              [strongSelf.delegate dataChannel:strongSelf didError:error];
                          }
                          
                          if (completionHandler) {
                              completionHandler(response);
                          }
                      }];
}

- (void)unregisterWithRoomServer {
    NSString *urlString =
    [NSString stringWithFormat:kARDRoomServerByeFormat, self.ardServerAddress, self.roomId, self.clientId];
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"C->RS: BYE");
    //Make sure to do a POST
    [NSURLConnection sendAsyncPostToURL:url withData:nil completionHandler:^(BOOL succeeded, NSData *data) {
        if (succeeded) {
            NSLog(@"Unregistered from room server.");
        } else {
            NSLog(@"Failed to unregister from room server.");
        }
    }];
}

- (NSError *)roomServerNetworkError {
    NSError *error =
    [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                               code:kARDAppClientErrorNetwork
                           userInfo:@{
                                      NSLocalizedDescriptionKey: @"Room server network error",
                                      }];
    return error;
}

#pragma mark - Collider methods

- (void)registerWithColliderIfReady {
    if (!self.isRegisteredWithRoomServer) {
        return;
    }
    // Open WebSocket connection.
    self.channel = [[ARDWebSocketChannel alloc] initWithURL:self.webSocketURL
                                     restURL:self.webSocketRestURL
                                    delegate:self];
    
    [self.channel registerForRoomId:self.roomId clientId:self.clientId];
}

- (void)sendSignalingMessageToCollider:(ARDSignalingMessage *)message {
    NSData *data = [message JSONData];
    [self.channel sendData:data];
}

#pragma mark - Configurations

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    return [self defaultPeerConnectionConstraints];
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
                                      ];
    
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"],
                                     [[RTCPair alloc] initWithKey:@"RtpDataChannels" value:@"false"]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCICEServer *)defaultSTUNServer {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:self.stunServerAddress];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
}

- (RTCICEServer *)defaultTURNServer {
    NSURL *turn = [NSURL URLWithString:self.turnServerAddress];
    return [[RTCICEServer alloc] initWithURI:turn
                                    username:self.turnServerUsername
                                    password:self.turnServerPassword];
}

#pragma mark - Overwritten

- (void)setState:(DataChannelClientState)state {
    if (_state == state) {
        return;
    }
    _state = state;
    
    [self.delegate dataChannel:self didChangeState:self.state];
}

- (void)setIsInitiator:(BOOL)isInitiator {
    _isInitiator = isInitiator;
    
    [self.delegate dataChannel:self isInitiator:isInitiator];
}


@end
