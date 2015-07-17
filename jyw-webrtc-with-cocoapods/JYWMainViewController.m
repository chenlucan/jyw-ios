
#import "JYWMainViewController.h"

#import "JYWMainView.h"

#import <WebRTC/RTCPeerConnection.h>
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCPair.h"
#import "RTCICECandidate.h"
#import "RTCSessionDescription.h"

#import <PubNub/PubNub.h>

@interface JYWMainViewController () <JYWMainViewDelegate, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate, PNObjectEventListener>

@property(nonatomic, strong) NSString *userID;
@property(nonatomic, strong) NSString *other_userID;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) NSMutableArray *messageQueue;

@property (nonatomic) PubNub *client;

@end

@implementation JYWMainViewController {
}

- (instancetype)init {
    if (self = [super init]) {
        self.userID = @"com.lucanchen.offerer";
        self.other_userID = @"com.lucanchen.answerer";
        PNConfiguration *configuration = [PNConfiguration configurationWithPublishKey:@"pub-c-540d3bfa-dd7a-4520-a9e4-907370d2ce37"
                                                                         subscribeKey:@"sub-c-3af2bc02-2b93-11e5-9bdb-0619f8945a4f"];
        self.client = [PubNub clientWithConfiguration:configuration];
        [self.client addListener:self];
        [self.client subscribeToChannels:@[@"webrtc-app"] withPresence:YES];
        
        [RTCPeerConnectionFactory initializeSSL];
        self.factory = [[RTCPeerConnectionFactory alloc] init];

        
        // Create peer connection.
        NSArray *optionalConstraints = @[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement"
                                                                value:@"true"]];
        RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                 optionalConstraints:optionalConstraints];
        
        NSURL *defaultSTUNServerURL = [NSURL URLWithString:@"stun:stun.l.google.com:19302"];
        RTCICEServer *server1 = [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                                         username:@""
                                                         password:@""];
        NSArray *ice_servers = @[server1];
        self.peerConnection = [self.factory peerConnectionWithICEServers:ice_servers constraints:constraints delegate:self];
        RTCMediaConstraints * media_constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@[] optionalConstraints:@[]];
        [self.peerConnection createOfferWithDelegate:self
                                         constraints:media_constraints];
    }
    return self;
}

- (void)loadView {
  JYWMainView *mainView = [[JYWMainView alloc] initWithFrame:CGRectZero];
  mainView.delegate = self;
  self.view = mainView;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Terminate any calls when we aren't active.
  [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - JYWMainViewDelegate

- (void)mainView:(JYWMainView *)mainView didInputRoom:(NSString *)room {
  if (!room.length) {
    return;
  }
  // Trim whitespaces.
  NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
  NSString *trimmedRoom = [room stringByTrimmingCharactersInSet:whitespaceSet];

  // Check that room name is valid.
  NSError *error = nil;
  NSRegularExpressionOptions options = NSRegularExpressionCaseInsensitive;
  NSRegularExpression *regex =
      [NSRegularExpression regularExpressionWithPattern:@"\\w+"
                                                options:options
                                                  error:&error];
  if (error) {
    [self showAlertWithMessage:error.localizedDescription];
    return;
  }
  NSRange matchRange =
      [regex rangeOfFirstMatchInString:trimmedRoom
                               options:0
                                 range:NSMakeRange(0, trimmedRoom.length)];
  if (matchRange.location == NSNotFound ||
      matchRange.length != trimmedRoom.length) {
    [self showAlertWithMessage:@"Invalid room name."];
    return;
  }
}

- (void)start {
    [self showAlertWithMessage:@"Received start request from JYWMainView"];

}

- (void)stop {
}

#pragma mark - RTCPeerConnectionDelegate
// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    
}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
    
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    
}

// New Ice candidate have been found.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    NSDictionary* dataDict = @{
        @"userID" : self.userID,
        @"candidate": @{
            @"sdpMLineIndex" : [NSNumber numberWithInteger:candidate.sdpMLineIndex],
            @"sdpMid"        : candidate.sdpMid,
            @"candidate"     : candidate.sdp
        }
    };
    [self.client publish:dataDict toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
        [self processPublishStatus:status];
    }];
    NSLog(@"sending icecandidate");
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
}

#pragma mark - RTCSessionDescriptionDelegate

// Called when creating a session.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error {
    NSLog(@"===========================error.code: %ld", error.code);
    [peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    if (sdp.description.length <= 700) {
        NSLog(@"==============================descrition less 700");
        
        NSDictionary *json = @{
                               @"type" : sdp.type,
                               @"sdp" : sdp.description
        };
//        NSData* data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
        
        NSDictionary *dataDict = @{
                                    @"userID":self.userID,
                                    @"fullPart":json
                                  };
        [self.client publish:dataDict toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
            [self processPublishStatus:status];
        }];
        return;
    }
    NSLog(@"==============================700 >>>> description");
    NSString* sdpPart1 = [sdp.description substringWithRange:NSMakeRange(0, 700)];
    NSString* sdpPart2 = [sdp.description substringWithRange:NSMakeRange(700, sdp.description.length-700)];

    NSDictionary *dataDict1 = @{
        @"userID":self.userID,
        @"firstPart":sdpPart1
    };
    NSDictionary *dataDict2 = @{
        @"userID":self.userID,
        @"firstPart":sdpPart2
    };
    
    NSData *data1 = [NSJSONSerialization dataWithJSONObject:dataDict1
        options:NSJSONWritingPrettyPrinted
        error:nil];
    
    NSData *data2 = [NSJSONSerialization dataWithJSONObject:dataDict2
        options:NSJSONWritingPrettyPrinted
        error:nil];
//    
//    NSString *dataStr1 = [[NSString alloc]initWithData:data1
//                                              encoding: NSUTF8StringEncoding];
//    
//    NSString *dataStr2 = [[NSString alloc]initWithData:data2
//                                              encoding: NSUTF8StringEncoding];
    [self.client publish:data1 toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
        
    }];
    [self.client publish:data2 toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
        
    }];
    NSLog(@"==========sending two parts offer");
}

// Called when setting a local or remote description.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    
}

#pragma mark - PNObjectEventListener

/**
 @brief  Notify listener about new message which arrived from one of remote data object's live feed
 on which client subscribed at this moment.
 
 @param client  Reference on \b PubNub client which triggered this callback method call.
 @param message Reference on \b PNResult instance which store message information in \c data
 property.
 
 @since 4.0
 */
- (void)client:(PubNub *)client didReceiveMessage:(PNMessageResult *)message {
    NSDictionary *msg = message.data.message;
    if (![msg objectForKey:@"userID"]) {
        NSLog(@"===============key userID is not present");
        return;
    }
    NSString *userID = msg[@"userID"];
    NSLog(@"==================received userID:%@", userID);
    if (![userID  isEqual: self.other_userID]) {
        NSLog(@"Ignoring this message, due to wrong userID: %@", userID);
        return;
    }
    if ([msg objectForKey:@"participant"] && msg[@"participant"]) {
        
    }
    if ([msg objectForKey:@"candidate"]) {
        NSDictionary *cand = msg[@"candidate"];
        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:cand[@"sdpMid"] index:(long)cand[@"sdpMLineIndex"] sdp:cand[@"candidate"]];
        [self.peerConnection addICECandidate:candidate];
        NSLog(@"=====================added iceCandidate");
    }
    if ([msg objectForKey:@"fullPart"]) {
        RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:@"answer"
                                                                     sdp:msg[@"fullPart"]];

        [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:sdp];
    }
    if ([msg objectForKey:@"firstPart"]) {
        
    }
    if ([msg objectForKey:@"secondPart"]) {
    
    }
    
    // Handle new message stored in message.data.message
    if (message.data.actualChannel) {
        
        // Message has been received on channel group stored in
        // message.data.subscribedChannel
    }
    else {
        
        // Message has been received on channel stored in
        // message.data.subscribedChannel
    }
    NSLog(@"Received message: %@ on channel %@ at %@", message.data.message,
          message.data.subscribedChannel, message.data.timetoken);
}

/**
 @brief  Notify listener about new presence events which arrived from one of remote data object's
 presence live feed on which client subscribed at this moment.
 
 @param client Reference on \b PubNub client which triggered this callback method call.
 @param event  Reference on \b PNResult instance which store presence event information in
 \c data property.
 
 @since 4.0
 */
- (void)client:(PubNub *)client didReceivePresenceEvent:(PNPresenceEventResult *)event {
    
    // Handle presence event event.data.presenceEvent (one of: join, leave, timeout,
    // state-change).
    if (event.data.actualChannel) {
        
        // Presence event has been received on channel group stored in
        // event.data.subscribedChannel
    }
    else {
        
        // Presence event has been received on channel stored in
        // event.data.subscribedChannel
    }
    NSLog(@"Did receive presence event: %@", event.data.presenceEvent);
    
}


///------------------------------------------------
/// @name Status change handler.
///------------------------------------------------

/**
 @brief      Notify listener about subscription state changes.
 @discussion This callback can fire when client tried to subscribe on channels for which it doesn't
 have access rights or when network went down and client unexpectedly disconnected.
 
 @param client Reference on \b PubNub client which triggered this callback method call.
 @param status  Reference on \b PNStatus instance which store subscriber state information.
 
 @since 4.0
 */
- (void)client:(PubNub *)client didReceiveStatus:(PNSubscribeStatus *)status {
    
    if (status.category == PNUnexpectedDisconnectCategory) {
        // This event happens when radio / connectivity is lost
    }
    
    else if (status.category == PNConnectedCategory) {
        
        // Connect event. You can do stuff like publish, and know you'll get it.
        // Or just use the connected event to confirm you are subscribed for
        // UI / internal notifications, etc
        
        [self.client publish:@"Hello from the PubNub Objective-C SDK" toChannel:@"my_channel"
              withCompletion:^(PNPublishStatus *status) {
                  
                  // Check whether request successfully completed or not.
                  if (!status.isError) {
                      
                      // Message successfully published to specified channel.
                  }
                  // Request processing failed.
                  else {
                      
                      // Handle message publish error. Check 'category' property to find out possible issue
                      // because of which request did fail.
                      //
                      // Request can be resent using: [status retry];
                  }
              }];
    }
    else if (status.category == PNReconnectedCategory) {
        
        // Happens as part of our regular operation. This event happens when
        // radio / connectivity is lost, then regained.
    }
    else if (status.category == PNDecryptionErrorCategory) {
        
        // Handle messsage decryption error. Probably client configured to
        // encrypt messages and on live data feed it received plain text.
    }
}

#pragma mark - Private

- (void)showAlertWithMessage:(NSString*)message {
  UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:nil
                                                      message:message
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
  [alertView show];
}

- (void)processPublishStatus:(PNPublishStatus *)status {
    switch(status.category) {
        case PNUnknownCategory:
            NSLog(@"================1");
            break;
            case PNAcknowledgmentCategory:
            NSLog(@"================2");
            break;
            
            case PNAccessDeniedCategory:
            NSLog(@"================3");
            break;
            
            case PNTimeoutCategory:
            NSLog(@"================4");
            break;
            
            case PNNetworkIssuesCategory:
            NSLog(@"================5");
            break;
            
            case PNConnectedCategory:
            NSLog(@"================6");
            break;
            
            case PNReconnectedCategory:
            NSLog(@"================7");
            break;
            
            case PNDisconnectedCategory:
            NSLog(@"================8");
            break;
            
            case PNUnexpectedDisconnectCategory:
            NSLog(@"================9");
            break;
            
            case PNCancelledCategory:
            NSLog(@"================10");
            break;
            
            case PNBadRequestCategory:
            NSLog(@"================11");
            break;
            
            case PNMalformedResponseCategory:
            NSLog(@"================12====description:%@", status.errorData);
            break;
            
            case PNDecryptionErrorCategory:
            NSLog(@"================13");
            break;
            
            case PNTLSConnectionFailedCategory:
            NSLog(@"================14");
            break;
            
            case PNTLSUntrustedCertificateCategory:
            NSLog(@"================15");
            break;

    }
    }

@end
