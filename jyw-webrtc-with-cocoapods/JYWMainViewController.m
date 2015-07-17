
#import "JYWMainViewController.h"

#import "JYWMainView.h"

#import "SRWebSocket.h"

#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCPair.h"
#import "RTCICECandidate.h"
#import "RTCSessionDescription.h"

@interface JYWMainViewController () <JYWMainViewDelegate, SRWebSocketDelegate, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>

@property(nonatomic, strong) NSString *userID;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) NSMutableArray *messageQueue;
@property(nonatomic, strong) SRWebSocket *socket;

@end

@implementation JYWMainViewController {
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *urlString = @"ws://localhost:8080";
//        NSString *urlString = @"wss://echo.websocket.org";
//        NSString *urlString = @"wss://pubsub.pubnub.com/demo/demo/webrtc-app";

//        NSURL *url  = [[NSURL alloc] initWithString:@"wss://pubsub.pubnub.com/demo/demo/webrtc-app"];
//        self.socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:url]];
//        self.socket.delegate = self;
        
        self.socket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:urlString]];
        self.socket.delegate = self;
        [self.socket open];
        
        [RTCPeerConnectionFactory initializeSSL];
        self.factory = [[RTCPeerConnectionFactory alloc] init];

        
        // Create peer connection.
        NSArray *optionalConstraints = @[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement"
                                                                value:@"true"]];
        RTCMediaConstraints* constraints =
        [[RTCMediaConstraints alloc]
         initWithMandatoryConstraints:nil
         optionalConstraints:optionalConstraints];
        
//        RTCConfiguration *config = [[RTCConfiguration alloc] init];
//        config.iceServers = _iceServers;
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
//    [_client connectToRoomWithId:@"comlucanchen" options:nil];
    [self showAlertWithMessage:@"Received start request from JYWMainView"];
//        [self.socket open];
}

- (void)stop {
//    [_client disconnect];
    [self.socket close];
}

#pragma mark - SRWebSocketDelegate

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSString *messageString = message;
    NSData *messageData = [messageString dataUsingEncoding:NSUTF8StringEncoding];
    id jsonObject = [NSJSONSerialization JSONObjectWithData:messageData
                                                    options:0
                                                      error:nil];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Unexpected message: %@", jsonObject);
        [self showAlertWithMessage:@"Unexpected message"];
        return;
    }
    NSDictionary *wssMessage = jsonObject;
    NSString *userID = wssMessage[@"userID"];
    if(wssMessage[@"userID"] == userID || wssMessage[@"userID"] !=@"com.lucanchen.answerer") return;
    
//    if (errorString.length) {
//        NSLog(@"WSS error: %@", errorString);
//        [self showAlertWithMessage:@"WSS error"];
//        return;
//    }
    if ([wssMessage objectForKey:@"firstPart"] || [wssMessage objectForKey:@"secondPart"]) {
        
    }
    if ([wssMessage objectForKey:@"candidate"]) {
        NSString *mid   = wssMessage[@"candidate"][@"sdpMid"];
        NSInteger index = wssMessage[@"candidate"][@"sdpMLineIndex"];
        NSString *sdp   = wssMessage[@"candidate"][@"sdp"];
        
        RTCICECandidate *rtc_candidate = [[RTCICECandidate alloc] initWithMid:mid
                    index: index
                      sdp:sdp];
        
        [self.peerConnection addICECandidate:rtc_candidate];
    }
    [self showAlertWithMessage:@"Received paload"];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self showAlertWithMessage:@"Delegate: webSocketDidOpen"];
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self showAlertWithMessage:@"Delegate: webSocket didFailWithError"];
    NSLog(@"=======%ld====%@", (long)error.code, error.description);
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self showAlertWithMessage:@"Delegate: webSocket didCloseWithCode"];
}
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    [self showAlertWithMessage:@"Delegate: webSocket didReceivePong"];
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
        @"userID" : @"com.lucanchen.offerer",
        @"candidate": @{
            @"sdpMLineIndex" : [NSNumber numberWithInteger:candidate.sdpMLineIndex],
            @"sdpMid"        : candidate.sdpMid,
            @"candidate"     : candidate.sdp
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject: dataDict
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    
    [self.socket send:data];
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
    
}

#pragma mark - RTCSessionDescriptionDelegate

// Called when creating a session.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    [peerConnection setLocalDescriptionWithDelegate:self
sessionDescription:sdp];
    if (sdp.description.length <= 700) {
        NSLog(@"==============================descrition less 700");
        return;
    }
    NSString* sdpPart1 = [sdp.description substringWithRange:NSMakeRange(0, 700)];
    NSString* sdpPart2 = [sdp.description substringWithRange:NSMakeRange(700, sdp.description.length-700)];

    NSDictionary *dataDict1 = @{
        @"userID":@"com.lucanchen.offerer",
        @"firstPart":sdpPart1
    };
    NSDictionary *dataDict2 = @{
        @"userID":@"com.lucanchen.offerer",
        @"firstPart":sdpPart2
    };
    
    NSData *data1 = [NSJSONSerialization dataWithJSONObject:dataDict1
        options:NSJSONWritingPrettyPrinted
        error:nil];
    
    NSData *data2 = [NSJSONSerialization dataWithJSONObject:dataDict2
        options:NSJSONWritingPrettyPrinted
        error:nil];
    
    NSString *dataStr1 = [[NSString alloc]initWithData:data1
                                              encoding: NSUTF8StringEncoding];
    
    NSString *dataStr2 = [[NSString alloc]initWithData:data2
                                              encoding: NSUTF8StringEncoding];
    [self.socket send:dataStr1];
    [self.socket send:dataStr2];
}

// Called when setting a local or remote description.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    
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

@end
