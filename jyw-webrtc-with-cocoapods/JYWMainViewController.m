
#import "JYWMainViewController.h"

#import "JYWMainView.h"

#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCICECandidate.h>
#import <WebRTC/RTCICEServer.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCPair.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCPeerConnectionDelegate.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCSessionDescriptionDelegate.h>

#import <PubNub/PubNub.h>

#import <QBImagePickerController/QBImagePickerController.h>

@interface JYWMainViewController () <JYWMainViewDelegate, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate, PNObjectEventListener, RTCDataChannelDelegate, UINavigationControllerDelegate, QBImagePickerControllerDelegate>

@property(nonatomic, strong) NSString *userID;
@property(nonatomic, strong) NSString *other_userID;
@property(nonatomic, strong) NSString *firstPart;
@property(nonatomic, strong) NSString *secondPart;
@property(nonatomic, strong) NSMutableArray *messageQueue;
@property(nonatomic) BOOL offer_answer_done;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) RTCDataChannel *dataChannel;
@property (nonatomic, strong) QBImagePickerController *pickController;

@property (nonatomic) PubNub *client;

@end

@implementation JYWMainViewController {
}

- (instancetype)init {
    if (self = [super init]) {
        self.userID = @"com.lucanchen.offerer";
        self.other_userID = @"com.lucanchen.answerer";
        self.messageQueue = [[NSMutableArray alloc] init];
        self.offer_answer_done = NO;
        self.dataChannel = nil;
        
        PNConfiguration *configuration = [PNConfiguration configurationWithPublishKey:@"pub-c-540d3bfa-dd7a-4520-a9e4-907370d2ce37"
                                                                         subscribeKey:@"sub-c-3af2bc02-2b93-11e5-9bdb-0619f8945a4f"];
        self.client = [PubNub clientWithConfiguration:configuration];
        [self.client addListener:self];
        [self.client subscribeToChannels:@[@"webrtc-app"] withPresence:YES];
        
        [RTCPeerConnectionFactory initializeSSL];
        self.factory = [[RTCPeerConnectionFactory alloc] init];

        
        // Create peer connection.
        NSURL *url1 = [NSURL URLWithString:@"stun:stun.l.google.com:19302"];
        NSURL *url2 = [NSURL URLWithString:@"turn:turn.bistri.com:80"];
        NSURL *url3 = [NSURL URLWithString:@"turn:turn.anyfirewall.com:443?transport=tcp"];
        NSURL *url4 = [NSURL URLWithString:@"stun:stun.anyfirewall.com:3478"];
        
        RTCICEServer *server1 = [[RTCICEServer alloc] initWithURI:url1
                                                         username:@""
                                                         password:@""];
        RTCICEServer *server2 = [[RTCICEServer alloc] initWithURI:url2
                                                         username:@"homeo"
                                                         password:@"homeo"];
        RTCICEServer *server3 = [[RTCICEServer alloc] initWithURI:url3
                                                         username:@"webrtc"
                                                         password:@"webrtc"];
        RTCICEServer *server4 = [[RTCICEServer alloc] initWithURI:url4
                                                         username:@""
                                                         password:@""];

        NSArray *ice_servers = @[server1];
        self.peerConnection = [self.factory peerConnectionWithICEServers:ice_servers constraints:nil delegate:self];
        
        
        
        
        // createDataChannel
        // protocol: 'text/chat', preset: true, stream: 16
        // maxRetransmits:0 && ordered:false
        RTCDataChannelInit *init = [[RTCDataChannelInit alloc] init];
        init.protocol = @"text/chat";
        init.streamId = 16;
        init.maxRetransmits = 0;
        init.isOrdered = NO;
        //        self.dataChannel = [self.peerConnection createDataChannelWithLabel:@"sctp-channel" config:init];
        self.dataChannel = [self.peerConnection createDataChannelWithLabel:@"" config:nil];
        self.dataChannel.delegate = self;
        NSLog(@"self.dataChannel, %@", self.dataChannel.label);
        NSLog(@"self.dataChannel, %@", self.dataChannel.isReliable ? @"Yes" : @"No");
        NSLog(@"self.dataChannel, %@", self.dataChannel.isOrdered ? @"Yes" : @"No");
        NSLog(@"self.dataChannel, %ld", self.dataChannel.maxRetransmitTime);
        NSLog(@"self.dataChannel, %ld", self.dataChannel.maxRetransmits);
        NSLog(@"self.dataChannel, %@", self.dataChannel.protocol);
        NSLog(@"self.dataChannel, %@", self.dataChannel.isNegotiated ? @"Yes" : @"No");
        NSLog(@"self.dataChannel, %ld", self.dataChannel.streamId);
        NSLog(@"self.dataChannel, %d", self.dataChannel.state);
        NSLog(@"self.dataChannel, %ld", self.dataChannel.bufferedAmount);
        
        NSLog(@"================created DataChannel, state:%d", self.dataChannel.state);
        [self.peerConnection createOfferWithDelegate:self
                                         constraints:nil];
        
        self.pickController = nil;
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
    QBImagePickerController *imagePickerController = [QBImagePickerController new];
    imagePickerController.delegate = self;
    imagePickerController.allowsMultipleSelection = YES;
    imagePickerController.prompt = @"Select the photos you want to upload!";
    imagePickerController.showsNumberOfSelectedAssets = YES;
    
    self.pickController = imagePickerController;
    [self presentViewController:self.pickController animated:YES completion:NULL];
}

- (void)stop {
}

#pragma mark - RTCPeerConnectionDelegate
// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"peerConnection signalingStateChanged beginning");
    switch (stateChanged) {
        case RTCSignalingStable:
            NSLog(@"peerConnection signalingStateChanged stable");
            break;
        case RTCSignalingHaveLocalOffer:
            NSLog(@"peerConnection signalingStateChanged HavelLocalOffer");
            break;
        case RTCSignalingHaveLocalPrAnswer:
            NSLog(@"peerConnection signalingStateChanged HavelLocalPrAnswer");
            break;
        case RTCSignalingHaveRemoteOffer:
            NSLog(@"peerConnection signalingStateChanged HaveRemoteOffer");
            break;
        case RTCSignalingHaveRemotePrAnswer:
            NSLog(@"peerConnection signalingStateChanged HaveRemotePrAnswer");
            break;
        case RTCSignalingClosed:
            NSLog(@"peerConnection signalingStateChanged Closed");
            break;
        default:
            break;
    }

}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
    NSLog(@"peerConnection addedStream, %u=======%u========%u", peerConnection.signalingState, peerConnection.iceConnectionState, peerConnection.iceGatheringState);
    [peerConnection addStream:stream];
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    NSLog(@"peerConnection removedStream, %u=======%u========%u", peerConnection.signalingState, peerConnection.iceConnectionState, peerConnection.iceGatheringState);
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"peerConnection peerConnectionOnRenegotiationNeeded, %u=======%u========%u", peerConnection.signalingState, peerConnection.iceConnectionState, peerConnection.iceGatheringState);
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    NSLog(@"peerConnection iceConnectionChanged");
    switch (newState) {
        case RTCICEConnectionNew:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionNew");
            break;
        case RTCICEConnectionChecking:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionChecking");
            break;
        case RTCICEConnectionConnected:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionConnected");
            break;
        case RTCICEConnectionCompleted:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionCompleted");
            break;
        case RTCICEConnectionFailed:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionFailed");
            break;
        case RTCICEConnectionDisconnected:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionDisconnected");
            break;
        case RTCICEConnectionClosed:
            NSLog(@"peerConnection iceConnectionChanged RTCICEConnectionClosed");
            break;
        default:
            break;
    }
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    NSLog(@"peerConnection iceGatheringChanged");
    switch (newState) {
        case RTCICEGatheringNew:
            NSLog(@"peerConnection iceGatheringChanged RTCICEGatheringNew");
            break;
        case RTCICEGatheringGathering:
            NSLog(@"peerConnection iceGatheringChanged RTCICEGatheringGathering");
            break;
        case RTCICEGatheringComplete:
            NSLog(@"peerConnection iceGatheringChanged RTCICEGatheringComplete");
            break;
        default:
            break;
    }
}

// New Ice candidate have been found.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    NSLog(@"peerConnection gotICECandidate");
    NSDictionary* dataDict = @{
        @"userID" : self.userID,
        @"candidate": @{
            @"sdpMLineIndex" : [NSNumber numberWithInteger:candidate.sdpMLineIndex],
            @"sdpMid"        : candidate.sdpMid,
            @"candidate"     : candidate.sdp
        }
    };
    NSLog(@"==============gotICECandidate, %@======%@========%@", dataDict[@"candidate"][@"sdpMid"], dataDict[@"candidate"][@"sdpMLineIndex"], dataDict[@"candidate"][@"candidate"]);
    if (!self.offer_answer_done) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messageQueue addObject:dataDict];
        });
    } else {
        [self.client publish:dataDict toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
            [self processPublishStatus:status];
        }];
        NSLog(@"sending icecandidate");
    }
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
    NSLog(@"peerConnection didOpenDataChannel");
}

#pragma mark - RTCSessionDescriptionDelegate

// Called when creating a session.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error {
    NSLog(@"===========================error.code: %ld", error.code);
    [peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    if (sdp.description.length < 7000) {
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
    NSLog(@"==============================900 >>>> description, length %ld", sdp.description.length);
    NSString* sdpPart1 = [sdp.description substringWithRange:NSMakeRange(0, 900)];
    NSString* sdpPart2 = [sdp.description substringWithRange:NSMakeRange(900, sdp.description.length-900)];

    NSDictionary *dataDict1 = @{
        @"userID":self.userID,
        @"firstPart":sdpPart1
    };
    NSDictionary *dataDict2 = @{
        @"userID":self.userID,
        @"secondPart":sdpPart2
    };
    
//    NSData *data1 = [NSJSONSerialization dataWithJSONObject:dataDict1
//        options:NSJSONWritingPrettyPrinted
//        error:nil];
//    
//    NSData *data2 = [NSJSONSerialization dataWithJSONObject:dataDict2
//        options:NSJSONWritingPrettyPrinted
//        error:nil];
//
//    NSString *dataStr1 = [[NSString alloc]initWithData:data1
//                                              encoding: NSUTF8StringEncoding];
//    
//    NSString *dataStr2 = [[NSString alloc]initWithData:data2
//                                              encoding: NSUTF8StringEncoding];
    [self.client publish:dataDict1 toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
        
    }];
    [self.client publish:dataDict2 toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
        
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
    NSLog(@"=============PubNub didReceiveMessage 1");
    NSDictionary *msg = message.data.message;
    NSLog(@"=============PubNub didReceiveMessage 2: %@", msg);
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
        
        NSString *mid = cand[@"sdpMid"];
        NSString *sdp = cand[@"candidate"];
        NSNumber *num = cand[@"sdpMLineIndex"];
        NSInteger mLineIndex = [num integerValue];
        NSLog(@"received ice candidate %@====%ld====%@", mid, mLineIndex, sdp);
        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:mid index:mLineIndex sdp:sdp];
//        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:cand[@"sdpMid"] index:(long)cand[@"sdpMLineIndex"] sdp:cand[@"candidate"]];
        NSLog(@"created ice candidate: %@====%ld=====%@", candidate.sdpMid, candidate.sdpMLineIndex, candidate.sdp);
        [self.peerConnection addICECandidate:candidate];
        NSLog(@"=====================added iceCandidate");
    }
    if ([msg objectForKey:@"fullPart"]) {
        NSString *sdpStr = msg[@"fullPart"];
        
        NSError *jsonError;
        NSData *objectData = [sdpStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        if (jsonError) {
            NSLog(@"data to dict error, code: %ld", jsonError.code);
        } else {
            NSLog(@"data to dict success, json[type]: %@", json[@"type"]);
            NSLog(@"data to dict success, json[sdp]: %@",  json[@"sdp"]);
        }
        
        RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:json[@"type"]
                                                                             sdp:json[@"sdp"]];
        [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:sdp];
        self.offer_answer_done = YES;
        NSLog(@"==================offer_answer_done==========");
        
        for (NSDictionary *dataDict in self.messageQueue) {
            NSLog(@"===========sending each icecandidate");
            [self.client publish:dataDict toChannel:@"webrtc-app" withCompletion:^(PNPublishStatus *status) {
                [self processPublishStatus:status];
            }];
        }
        [self.messageQueue removeAllObjects];
    }
    if ([msg objectForKey:@"firstPart"]) {
        NSLog(@"==============received answer from firstPart");
        self.firstPart = msg[@"firstPart"];
        [self processAnswer];
    }
    if ([msg objectForKey:@"secondPart"]) {
        NSLog(@"==============received answer from secondPart");
        self.secondPart = msg[@"secondPart"];
        [self processAnswer];
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
    NSLog(@"=============PubNub didReceivePresenceEvent: %@", event.data.presenceEvent);
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
    NSLog(@"=============PubNub didReceiveStatus");
    
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

#pragma mark - RTCDataChannelDelegate
// Called when the data channel state has changed.
- (void)channelDidChangeState:(RTCDataChannel*)channel {
    NSLog(@"RTCDataChannel channelDidChangeState beginning");
    switch (channel.state) {
        case kRTCDataChannelStateConnecting:
            NSLog(@"channelDidChangeState connecting");
            break;
        case kRTCDataChannelStateOpen:
            NSLog(@"channelDidChangeState open");
            break;
        case kRTCDataChannelStateClosing:
            NSLog(@"channelDidChangeState closing");
            break;
        case kRTCDataChannelStateClosed:
            NSLog(@"channelDidChangeState closed");
            break;
        default:
            break;
    }
}

// Called when a data buffer was successfully received.
- (void)channel:(RTCDataChannel*)channel
didReceiveMessageWithBuffer:(RTCDataBuffer*)buffer{
    NSString* newStr = [[NSString alloc] initWithData:buffer.data encoding:NSUTF8StringEncoding];
    NSLog(@"RTCDataChannel didReceiveMessageWithBuffer: text: %@", newStr);
}

#pragma mark - QBImagePickerControllerDelegate
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets {
    PHImageManager *imgManager = [PHImageManager defaultManager];
    for (PHAsset *asset in assets) {
        // Do something with the asset
        [imgManager requestImageDataForAsset:asset options:nil resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            if ([info valueForKey:PHImageErrorKey] && info[PHImageErrorKey]) {
                NSLog(@"requestImageDataForAsset PHImageErrorKey");
                return;
            }
            NSLog(@"requestImageDataForAsset %ld", imageData.length);
            [self sendData:imageData];
        }];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}
- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)qb_imagePickerController:(QBImagePickerController *)imagePickerController shouldSelectAsset:(PHAsset *)asset {
    return YES;
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAsset:(PHAsset *)asset {
    
}
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didDeselectAsset:(PHAsset *)asset {
    
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

- (void) processAnswer {
    if (self.firstPart && self.secondPart) {
        
    } else {
        
    }
}

- (void) sendImg:(UIImage *)img {
    NSData *imgData = UIImageJPEGRepresentation(img, 1.0);
    
    UIImageView *imgv = [[UIImageView alloc] initWithFrame:CGRectMake(100, 100, 200, 200)];
    imgv.image = img;
    [self.view addSubview:imgv];
    
    [self sendData:imgData];
}

- (void) sendData:(NSData *)imgData {
    // max size we could send 66528 bytes
    // 8 bytes - length - NSUInteger
    // 1 byte  - type - currently only support '0 - File'
    // so payload is 66528 - 9 = 66519
    NSUInteger max = 66519;
    NSUInteger len = imgData.length;
    NSUInteger loop = len / max;
    if (len % max) {
        loop++;
    }
    NSLog(@"============loop:%ld======len:%ld=====max:%ld", loop, len, max);
    for (NSUInteger i = 1; i <= loop; ++i) {
        if (max * i < len) {
            // send max bytes
            NSData *package = [imgData subdataWithRange:NSMakeRange((i-1)*max, max)];
            [self send:package type:0 totalLength:len];
        } else {
            // last package to send
            NSData *package = [imgData subdataWithRange:NSMakeRange((i-1)*max, len - (i-1)*max)];
            [self send:package type:0 totalLength:len];
        }
    }
}

- (void) send: (NSData *)payload type: (char)type totalLength: (NSUInteger)totalLength {
    NSData *testData = [payload subdataWithRange:NSMakeRange(0, 2)];
    const unsigned char *dataBuffer = (const unsigned char *)[testData bytes];
    NSLog(@"==============first byte hex string: %ld====%ld",  (unsigned long)dataBuffer[0], (unsigned long)dataBuffer[1]);
    
    NSLog(@"=======payload length: %ld", payload.length);
    
    NSData *lenData = [NSData dataWithBytes:&totalLength length:sizeof(totalLength)];
    NSLog(@"========sizeof NSUInteger: %ld", sizeof(totalLength));
    NSLog(@"=======lenData length: %ld", lenData.length);
    
    NSData *typeData = [NSData dataWithBytes:&type length:sizeof(type)];
    NSLog(@"========sizeof char: %ld", sizeof(type));
    NSLog(@"=======typeData length: %ld", typeData.length);
    
    NSMutableData *payloadMutable = [lenData mutableCopy];
    
    [payloadMutable appendData:typeData];
    [payloadMutable appendData:payload];
    
    NSLog(@"=======final size: %ld", payloadMutable.length);
    
    RTCDataBuffer *imgBuf = [[RTCDataBuffer alloc] initWithData:payloadMutable isBinary:YES];
    [self.dataChannel sendData:imgBuf];
}
@end
