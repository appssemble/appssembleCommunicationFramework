# appssemble Communication Framework

iOS communication framework based on multipeer connectivity and WebRTC. It provides real time communication and time synchronization. It uses libjingle, WebRTC, SocketRocket, ntp and the MultiplayerConnectivity Framework. It provides 2 types of communication, via RTC and by using muliplayer connectivity in the local network.

## Getting Started

These instructions will help you get a copy of the project up and running on your local machine for development and testing purposes.

### Installing

In order to use the library you can direct download it, build it and use it in your projects, or you can use Cocoa Pods.

In order to install it via Pods, add the following to your pod file

```
pod 'appssembleCommunicationFramework'
```

Because of the fact that this framework uses the WebRTC library which is not bitcode compatible, you need to disable the bitcode for it in your pods project. This can be acomplished like in the example below:

```
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if target.name == "appssembleCommunicationFramework"
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        end
    end
end
```

This should be added at the end of the Podfile.

## Usage

### DataChannel 

This provides data communication and time sync over WebRTC, it works by default for testing purposes no need to configure a server address, neither a STUN and TURN server, however, if someone uses this in production for other purposes other than development the server addresses should be provided.

```
// The addres of the ard server, if not set will use a default test one from Google
@property (nonatomic, strong) NSString *ardServerAddress;

// The addres of the STUN server, if not set will use a default test one from Google
@property (nonatomic, strong) NSString *stunServerAddress;

// The addres of the TURN server, if not set will use a default test one
@property (nonatomic, strong) NSString *turnServerAddress;

// The username and password of the TURN server
@property (nonatomic, strong) NSString *turnServerUsername;
@property (nonatomic, strong) NSString *turnServerPassword;
```

In order to make it work with a custom server not the Google one, https://github.com/webrtc/apprtc needs to be configured on a server.

### OffDataChannel

This type of channel provides communication and time sync using the multipeer conevtivity framework.

### TimeSynchronization

```
// Delegate
@property (weak, nonatomic) id<TimeSynchronizationDelegate> delegate;

/** Starts the synchronization for the given seconds
 @param seconds - must be equal higher then 5
 @return date - the current date used for synchronization,
    nil if the given seconds is lower then 5
 */
- (uint64_t)startSynchronizationWithPeerForSeconds:(int)seconds;

// Starts a count down from an TimeSyncObject, this is called when receiving an object via a communication channel
- (void)startCountDownFromTimeObject:(TimeSyncObject *)object;

// Stops the count down
- (void)stopCountDown;
- (void)stopCountDownWithoutNotification;
```

The time synchronization object can be allocated using eithe one of the communication channels presented before (DataChannel/ OffDataChannel)

### Interfaces

Both DataChannel and OffDataChannel provide the same interface

```
Delegates for callbacks
@property (nonatomic, readonly) DataChannelClientState state;

@property (nonatomic, weak) id<DataChannelDelegate> delegate;
@property (nonatomic, weak) id<DataChannelTimeSyncDelegate> timeSyncDelegate;

// Connects to a communication room using the provided id, basically this should be the same ID used on the two devices which need to communicate
- (void)connectToRoomWithId:(NSString *)roomId;

// Sends a message to the room its currently connected to
- (void)sendMessage:(NSString *)message;

// Disconnects
- (void)disconnect;

// Starts a time syncronization by sending a time sync object
- (void)sendTimeSyncMessage:(TimeSyncObject *)object;
```

## Contributing

Any pull requests are welcomed.

## Authors

* **appssemble**  - [appssemble](http://www.appssemble.com)


## License

This project is licensed under the WTFPL License. (Which means you can do whatever you're pleased with the code🤘)

## Acknowledgments

* libWebRTC
* libjingle
* Gavin Eadie - time synchronization
* SRWebSocket
