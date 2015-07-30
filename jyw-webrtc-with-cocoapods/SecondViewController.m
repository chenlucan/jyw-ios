//
//  SecondViewController.m
//  tabbed-sample
//
//  Created by Lucan Chen on 29/7/15.
//  Copyright (c) 2015 Dynasty. All rights reserved.
//

#import "SecondViewController.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

@interface SecondViewController () <FBSDKLoginButtonDelegate>

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"viewDidLoad from Second");
    FBSDKLoginButton *loginButton = [[FBSDKLoginButton alloc] init];
    loginButton.center = self.view.center;
//    loginButton.delegate = self;
    [self.view addSubview:loginButton];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - FBSDKLoginButtonDelegate
/*!
 @abstract Sent to the delegate when the button was used to login.
 @param loginButton the sender
 @param result The results of the login
 @param error The error (if any) from the login
 */
- (void)  loginButton:(FBSDKLoginButton *)loginButton
didCompleteWithResult:(FBSDKLoginManagerLoginResult *)result
                error:(NSError *)error {
    NSLog(@"loginButton didCompleteWithResult error--code:%ld", error.code);
    NSLog(@"loginButton didCompleteWithResult error--token:%@", result.token);
    NSLog(@"loginButton didCompleteWithResult error: granted %ld", [result.grantedPermissions count]);
    NSLog(@"loginButton didCompleteWithResult error: declined %ld", [result.declinedPermissions count]);
    NSLog(@"loginButton didCompleteWithResult error--currenttoken:%@", [FBSDKAccessToken currentAccessToken]);
    
    if (result.token) {
        NSLog(@"You are logged in");
    }
}

/*!
 @abstract Sent to the delegate when the button was used to logout.
 @param loginButton The button that was clicked.
 */
- (void)loginButtonDidLogOut:(FBSDKLoginButton *)loginButton {
    NSLog(@"loginButtonDidLogOut");
}


@end
