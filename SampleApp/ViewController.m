//
//  ViewController.m
//  SampleApp
//
//  Created by voiceloco.
//  Copyright © 2018년 voiceloco. All rights reserved.
//

#import <CallKit/CallKit.h>
#import <PushKit/PushKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "ViewController.h"

#import <VLVoice/VLVoice.h>


static NSString *const kAppId = <#INPUT YOUR APP ID#>;
static NSString *const kAppKey = <#INPUT YOUR APP KEY#>;
static NSString *const kDevRestURL = @"http://116.122.36.39:3300/api/v1.0";

@interface ViewController () <PKPushRegistryDelegate, CXProviderDelegate, UITextFieldDelegate, VLCallDelegate, VLNotificationDelegate>

// IBOutlet property
@property (strong, nonatomic) IBOutlet UITextField *calleeAccountField;
@property (strong, nonatomic) IBOutlet UITextField *callerAccountField;

@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *button;
@property (strong, nonatomic) IBOutlet UISwitch *muteSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *speakerSwitch;

// push property
@property (nonatomic, strong) PKPushRegistry *voipRegistry;

// callkit property
@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) CXCallController *callKitCallController;

// voiceloco sdk property
@property (strong, nonatomic) VLCall *call;
@property (strong, nonatomic) VLCallInvite *callInvite;

// token property
@property (nonatomic, strong) NSData *deviceToken;
@property (nonatomic, strong) NSString *accessToken;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    [VLVoice setLogLevel:VLLogLevelDebug];
    
    // ui
    _calleeAccountField.delegate = self;
    _callerAccountField.delegate = self;
    
    // prepare push token
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.voipRegistry.delegate = self;
    self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    // prepare callkit
    [self configureCallKit];
    
    // set App id
    [VLVoice setAppId:kAppId];
    
    // prepare login
//    [self loadUserCredentials];
}

/*
- (void)loadUserCredentials
{
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"calleeAccount"]) {
        [_calleeAccountField setText:[[NSUserDefaults standardUserDefaults] objectForKey:@"calleeAccount"]];
    }

    if([[NSUserDefaults standardUserDefaults] objectForKey:@"callerAccount"]) {
        [_callerAccountField setText:[[NSUserDefaults standardUserDefaults] objectForKey:@"callerAccount"]];
    }
}

- (void) saveUserCredentials
{
    [[NSUserDefaults standardUserDefaults] setObject:_calleeAccountField.text forKey:@"calleeAccount"];
    [[NSUserDefaults standardUserDefaults] setObject:_callerAccountField.text forKey:@"callerAccount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
*/

- (IBAction)onCallButtonClick:(id)sender
{
    if(_call) {
        [_call disconnect];

    } else {
        if([_calleeAccountField.text length] > 0) {
            if (_accessToken == nil) {
                // 최초 실행시에는 token을 바로 받지 못하기때문에 버튼을 누를 때 받아온 다음 전화를 건다
                [self getAccessToken:^(NSString *accessToken) {
                    _accessToken = accessToken;
                    NSLog(@"accesToken : %@", accessToken);
                    
                    [VLVoice registerWithUserId:_callerAccountField.text
                                    AccessToken:accessToken
                                    deviceToken:_deviceToken
                                     completion:^(NSError *error) {
                                         if (error) {
                                             
                                         } else {
                                             NSLog(@"call to : %@", _calleeAccountField.text);
                                             
                                             [self reportOutgoingCallWithCalleeAccount:_calleeAccountField.text];
                                             
//                                             [self saveUserCredentials];
                                         }
                                     }];
                }];
                return;
            }
            
            NSLog(@"call to : %@", _calleeAccountField.text);

            [self reportOutgoingCallWithCalleeAccount:_calleeAccountField.text];

//            [self saveUserCredentials];
        }
    }
}

- (IBAction)onMuteSwitchClick:(id)sender {
    if(_call) {
        _call.muted = _muteSwitch.on;
    }
}

- (IBAction)onSpeakerSwitchClick:(id)sender {
    [self toggleAudioRoute:_speakerSwitch.on];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void)getAccessToken:(void (^)(NSString *accessToken))completionHandler
{
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    NSString *restURL = [NSString stringWithFormat:@"%@/apps/%@/users", kDevRestURL, kAppId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:restURL]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:10.f];
    [request setHTTPMethod:@"POST"];
    
    NSError *error;
    NSDictionary *jsonInfo  = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               _callerAccountField.text, @"userId",
                               nil];
    NSData *jsonData        = [NSJSONSerialization dataWithJSONObject:jsonInfo options:NSJSONWritingPrettyPrinted error:&error];
    NSString *inputParam    = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSData *requestBody     = [inputParam dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:requestBody];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:kAppkey forHTTPHeaderField:@"Api-Key"];
    
    // process response data.
    NSURLSessionTask *task = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (response != nil) {
            NSDictionary *header = [(NSHTTPURLResponse *)response allHeaderFields];
            completionHandler(header[@"Authorization"]);
        } else {
            NSLog(@"error : %@", [error localizedDescription]);
        }
    }];
    
    [task resume];
}

#pragma mark - AVAudioSession
- (void)toggleAudioRoute:(BOOL)toSpeaker {
    NSError *error = nil;
    if (toSpeaker) {
        if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
            NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
        }
    } else {
        if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
            NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
        }
    }
}

#pragma mark - CallKit
- (void)configureCallKit {
    NSString *localizedName                 = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
    CXProviderConfiguration *configuration  = [[CXProviderConfiguration alloc] initWithLocalizedName:localizedName];
    configuration.maximumCallGroups         = 1;
    configuration.maximumCallsPerCallGroup  = 1;
//    UIImage *callkitIcon                    = [UIImage imageNamed:@"icon"];
//    configuration.iconTemplateImageData = UIImagePNGRepresentation(callkitIcon);
    
    _callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
    [_callKitProvider setDelegate:self queue:nil];
    
    _callKitCallController = [[CXCallController alloc] init];
}

- (void) reportIncomingCallInvite:(VLCallInvite *)callInvite
{
    CXHandle *callHandle            = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:callInvite.caller];
    
    CXCallUpdate *callUpdate        = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle         = callHandle;
    callUpdate.supportsDTMF         = YES;
    callUpdate.supportsHolding      = YES;
    callUpdate.supportsGrouping     = NO;
    callUpdate.supportsUngrouping   = NO;
    callUpdate.hasVideo             = NO;
    
    [_callKitProvider reportNewIncomingCallWithUUID:callInvite.uuid update:callUpdate completion:^(NSError *error) {
        if (!error) {
            NSLog(@"Incoming call successfully reported.");
        } else {
            NSLog(@"Failed to report incoming call successfully: %@.", [error localizedDescription]);
            [_callKitProvider invalidate];
        }
    }];
}

- (void) reportOutgoingCallWithCalleeAccount:(NSString *)account
{
    NSLog(@"reportOutgoingCallWithCalleeAccount : %@", account);
    NSUUID *uuid = [NSUUID UUID];
    
    // Start Action
    CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:account];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:handle];
    startCallAction.contactIdentifier = account;
    startCallAction.video = NO;
    
    // Add transaction
    CXTransaction *transaction    = [[CXTransaction alloc] init];
    [transaction addAction:startCallAction];
    
    [_callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@", [error localizedDescription]);
        } else {
            NSLog(@"StartCallAction transaction request successful");
            
            CXCallUpdate *callUpdate        = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle         = handle;
            callUpdate.supportsDTMF         = YES;
            callUpdate.supportsHolding      = YES;
            callUpdate.supportsGrouping     = NO;
            callUpdate.supportsUngrouping   = NO;
            callUpdate.hasVideo             = NO;
            
            [_callKitProvider reportCallWithUUID:uuid updated:callUpdate];
        }
    }];
}

- (void)performEndCallActionWithUUID:(NSUUID *)uuid {
    if (uuid == nil) {
        return;
    }
    
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    
    [_callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"EndCallAction transaction request successful");
        }
    }];
}

- (void)performVoiceCallWithUUID:(NSUUID *)uuid
                          client:(NSString *)client
                      completion:(void(^)(BOOL success))completionHandler {

}

- (void)performAnswerVoiceCallWithUUID:(NSUUID *)uuid
                            completion:(void(^)(BOOL success))completionHandler {
    [VLVoice configureAudioSession];
    _call = [_callInvite acceptWithDelegate:self];
    _callInvite = nil;
    
    completionHandler(YES);
}

#pragma mark - PKPushRegistryDelegate
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    NSLog(@"pushRegistry:didUpdatePushCredentials:forType:");
    
    if ([type isEqualToString:PKPushTypeVoIP]) {
        if([_callerAccountField.text isEqualToString:@""]) {
            // 로그인 할 유저 id를 모르면 푸시토큰만 먼저 저장
            _deviceToken = credentials.token;
            return;
        }
        
        // get access token at app launch
        NSString *userId = _callerAccountField.text;
        [self getAccessToken:^(NSString *accessToken) {
            _accessToken = accessToken;
            
            [VLVoice registerWithUserId:userId
                            AccessToken:accessToken
                            deviceToken:credentials.token
                             completion:^(NSError * _Nullable error) {
                                 if (error) {
                                     NSLog(@"%@", [error localizedDescription]);
                                 } else {
                                     NSLog(@"access token register complete.");
                                 }
                             }];
        }];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    NSLog(@"pushRegistry:didInvalidatePushTokenForType:");
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
    NSLog(@"pushRegistry:didReceiveIncomingPushWithPayload:forType:");
    if ([type isEqualToString:PKPushTypeVoIP]) {
        [VLVoice handleNotification:payload.dictionaryPayload
                           delegate:self];
    }
}

#pragma mark - VLCallDelegate
- (void)callDidConnect:(nonnull VLCall *)call
{
    NSLog(@"VLCallDelegate callDidConnect");
    
    _call = call;
    
    [_callKitProvider reportOutgoingCallWithUUID:call.uuid connectedAtDate:[NSDate date]];
    
    [_button setTitle:@"End Call" forState:UIControlStateNormal];
    
    [self updateCallState];
}

- (void)call:(VLCall *)call didFailToConnectWithError:(NSError *)error
{
    NSLog(@"VLCallDelegate didFailToConnectWithError");
    
    [_button setTitle:@"Call" forState:UIControlStateNormal];
    
    [self performEndCallActionWithUUID:_call.uuid];
    
    _call = nil;
    
    [self updateCallState];
}

- (void)call:(VLCall *)call didDisconnectWithError:(NSError *)error
{
    NSLog(@"VLCallDelegate didDisconnectWithError");
    
    if (error) {
        
    } else {
        [self performEndCallActionWithUUID:_call.uuid];
    }
    
    [_button setTitle:@"Call" forState:UIControlStateNormal];
    
    _call = nil;
    
    [self updateCallState];
}

- (void)updateCallState
{
    NSLog(@"VLCallDelegate updateCallState");
    
    if(_call) {
        if(_call.state == VLCallStateConnecting) {
            _statusLabel.text = @"Status : Connecting";
            
        } else if(_call.state == VLCallStateConnected) {
            _statusLabel.text = @"Status : Connected";
            
        } else if(_call.state == VLCallStateDisconnected) {
            _statusLabel.text = @"Status : Disconnected";
        }
    } else {
        _statusLabel.text = @"Status : idle";
    }
}

#pragma mark - VLNotificationDelegate
- (void)callInviteReceived:(nonnull VLCallInvite *)callInvite
{
    if (callInvite.state == VLCallInviteStatePending) {
        [self handleCallInviteReceived:callInvite];
    } else if (callInvite.state == VLCallInviteStateCanceled) {
        [self handleCallInviteCanceled:callInvite];
    }
}

- (void)handleCallInviteReceived:(VLCallInvite *)callInvite {
    NSLog(@"callInviteReceived:");
    
    if (self.callInvite && self.callInvite == VLCallInviteStatePending) {
        NSLog(@"Already a pending incoming call invite.");
        NSLog(@"  >> Ignoring call from %@", callInvite.caller);
        return;
    } else if (self.call) {
        NSLog(@"Already an active call.");
        NSLog(@"  >> Ignoring call from %@", callInvite.caller);
        return;
    }
    
    _callInvite = callInvite;
    
    [self reportIncomingCallInvite:callInvite];
}

- (void)handleCallInviteCanceled:(VLCallInvite *)callInvite {
    NSLog(@"callInviteCanceled:");
    
    [self performEndCallActionWithUUID:callInvite.uuid];
    
    _callInvite = nil;
}

- (void)notificationError:(NSError *)error {
    NSLog(@"notificationError: %@", [error localizedDescription]);
}

#pragma mark - CXProviderDelegate
- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"providerDidReset:");
}

- (void)providerDidBegin:(CXProvider *)provider {
    NSLog(@"providerDidBegin:");
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"provider:didActivateAudioSession:");
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"provider:didDeactivateAudioSession:");
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    NSLog(@"provider:timedOutPerformingAction:");
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"provider:performStartCallAction:");
    
    [_callKitProvider reportOutgoingCallWithUUID:action.callUUID startedConnectingAtDate:[NSDate date]];
    
    _call = [VLVoice makeACallWithParams:@{@"callee" : _calleeAccountField.text,
                                           @"caller" : _callerAccountField.text}
                                    uuid:action.callUUID
                                delegate:self];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    NSLog(@"provider:performAnswerCallAction:");
    
    [self performAnswerVoiceCallWithUUID:action.callUUID completion:^(BOOL success) {
        if (success) {
            [action fulfill];
        } else {
            [action fail];
        }
    }];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSLog(@"provider:performEndCallAction:");
    
    if (_callInvite && _callInvite.state == VLCallInviteStatePending) {
        [_callInvite reject];
        _callInvite = nil;
    }
    
    if (_call) {
        [_call disconnect];
    }
    
    [action fulfill];
}

@end
