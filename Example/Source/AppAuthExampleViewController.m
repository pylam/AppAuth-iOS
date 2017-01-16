/*! @file AppAuthExampleViewController.m
    @brief AppAuth iOS SDK Example
    @copyright
        Copyright 2015 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import "AppAuthExampleViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AppAuth.h"
#import "AppDelegate.h"

/*! @brief The OIDC issuer from which the configuration will be discovered.
 */
static NSString *const kIssuer = @"https://accounts.google.com";

/*! @brief The OAuth client ID.
    @discussion For Google, register your client at
        https://console.developers.google.com/apis/credentials?project=_
        The client should be registered with the "iOS" type.
 */
static NSString *const kClientID =
    @"637758811211-jhuddp7ubcn9bedev15ds8ncrvenh9ud.apps.googleusercontent.com";

/*! @brief The OAuth redirect URI for the client @c kClientID.
    @discussion With Google, the scheme of the redirect URI is the reverse DNS notation of the
        client ID. This scheme must be registered as a scheme in the project's Info
        property list ("CFBundleURLTypes" plist key). Any path component will work, we use
        'oauthredirect' here to help disambiguate from any other use of this scheme.
 */
static NSString *const kRedirectURI =
    @"com.googleusercontent.apps.637758811211-jhuddp7ubcn9bedev15ds8ncrvenh9ud:/oauthredirect";

/*! @brief NSCoding key for the authState property.
 */
static NSString *const kAppAuthExampleAuthStateKey = @"authState";

@interface AppAuthExampleViewController () <OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate>
@end

@implementation AppAuthExampleViewController

- (void)viewDidLoad {
  [super viewDidLoad];

#if !defined(NS_BLOCK_ASSERTIONS)

  // NOTE:
  //
  // To run this sample, you need to register your own iOS client at
  // https://console.developers.google.com/apis/credentials?project=_ and update three configuration
  // points in the sample: kClientID and kRedirectURI constants in AppAuthExampleViewController.m
  // and the URI scheme in Info.plist (URL Types -> Item 0 -> URL Schemes -> Item 0).
  // Full instructions: https://github.com/openid/AppAuth-iOS/blob/master/Example/README.md

  NSAssert(![kClientID isEqualToString:@"YOUR_CLIENT.apps.googleusercontent.com"],
           @"Update kClientID with your own client ID. "
            "Instructions: https://github.com/openid/AppAuth-iOS/blob/master/Example/README.md");

  NSAssert(![kRedirectURI isEqualToString:@"com.googleusercontent.apps.YOUR_CLIENT:/oauthredirect"],
           @"Update kRedirectURI with your own redirect URI. "
            "Instructions: https://github.com/openid/AppAuth-iOS/blob/master/Example/README.md");

  // verifies that the custom URI scheme has been updated in the Info.plist
  NSArray __unused* urlTypes =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
  NSAssert([urlTypes count] > 0, @"No custom URI scheme has been configured for the project.");
  NSArray *urlSchemes =
      [(NSDictionary *)[urlTypes objectAtIndex:0] objectForKey:@"CFBundleURLSchemes"];
  NSAssert([urlSchemes count] > 0, @"No custom URI scheme has been configured for the project.");
  NSString *urlScheme = [urlSchemes objectAtIndex:0];

  NSAssert(![urlScheme isEqualToString:@"com.googleusercontent.apps.YOUR_CLIENT"],
           @"Configure the URI scheme in Info.plist (URL Types -> Item 0 -> URL Schemes -> Item 0) "
            "with the scheme of your redirect URI. Full instructions: "
            "https://github.com/openid/AppAuth-iOS/blob/master/Example/README.md");

#endif // !defined(NS_BLOCK_ASSERTIONS)

  _logTextView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
  _logTextView.layer.borderWidth = 1.0f;
  _logTextView.alwaysBounceVertical = true;
  _logTextView.textContainer.lineBreakMode = NSLineBreakByCharWrapping;
  _logTextView.text = @"";

  [self loadState];
  [self updateUI];
}

/*! @brief Saves the @c OIDAuthState to @c NSUSerDefaults.
 */
- (void)saveState {
  // for production usage consider using the OS Keychain instead
  NSData *archivedAuthState = [ NSKeyedArchiver archivedDataWithRootObject:_authState];
  [[NSUserDefaults standardUserDefaults] setObject:archivedAuthState
                                            forKey:kAppAuthExampleAuthStateKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

/*! @brief Loads the @c OIDAuthState from @c NSUSerDefaults.
 */
- (void)loadState {
  // loads OIDAuthState from NSUSerDefaults
  NSData *archivedAuthState =
      [[NSUserDefaults standardUserDefaults] objectForKey:kAppAuthExampleAuthStateKey];
  OIDAuthState *authState = [NSKeyedUnarchiver unarchiveObjectWithData:archivedAuthState];
  [self setAuthState:authState];
}

- (void)setAuthState:(nullable OIDAuthState *)authState {
  if (_authState == authState) {
    return;
  }
  _authState = authState;
  _authState.stateChangeDelegate = self;
  [self stateChanged];
}

/*! @brief Refreshes UI, typically called after the auth state changed.
 */
- (void)updateUI {
  _userinfoButton.enabled = [_authState isAuthorized];
  _clearAuthStateButton.enabled = _authState != nil;
  _codeExchangeButton.enabled = _authState.lastAuthorizationResponse.authorizationCode
                                && !_authState.lastTokenResponse;
  // dynamically changes authorize button text depending on authorized state
  if (!_authState) {
    [_authAutoButton setTitle:@"Authorize" forState:UIControlStateNormal];
    [_authAutoButton setTitle:@"Authorize" forState:UIControlStateHighlighted];
    [_authManual setTitle:@"Authorize (Manual)" forState:UIControlStateNormal];
    [_authManual setTitle:@"Authorize (Manual)" forState:UIControlStateHighlighted];
  } else {
    [_authAutoButton setTitle:@"Re-authorize" forState:UIControlStateNormal];
    [_authAutoButton setTitle:@"Re-authorize" forState:UIControlStateHighlighted];
    [_authManual setTitle:@"Re-authorize (Manual)" forState:UIControlStateNormal];
    [_authManual setTitle:@"Re-authorize (Manual)" forState:UIControlStateHighlighted];
  }
}

- (void)stateChanged {
  [self saveState];
  [self updateUI];
}

- (void)didChangeState:(OIDAuthState *)state {
  [self stateChanged];
}

- (void)authState:(OIDAuthState *)state didEncounterAuthorizationError:(nonnull NSError *)error {
  [self logMessage:@"Received authorization error: %@", error];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

- (IBAction)authWithAutoCodeExchange:(nullable id)sender {
  NSURL *issuer = [NSURL URLWithString:kIssuer];
  NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];

  [self logMessage:@"Fetching configuration for issuer: %@", issuer];

  // discovers endpoints
  [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
      completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {

    if (!configuration) {
      [self logMessage:@"Error retrieving discovery document: %@", [error localizedDescription]];
      [self setAuthState:nil];
      return;
    }

    [self logMessage:@"Got configuration: %@", configuration];

    // builds authentication request
    OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:kClientID
                                                        scopes:@[OIDScopeOpenID, OIDScopeProfile]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
    // performs authentication request
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self logMessage:@"Initiating authorization request with scope: %@", request.scope];

    appDelegate.currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
            presentingViewController:self
                            callback:^(OIDAuthState *_Nullable authState,
                                       NSError *_Nullable error) {
      if (authState) {
        [self setAuthState:authState];
        [self logMessage:@"Got authorization tokens. Access token: %@",
                         authState.lastTokenResponse.accessToken];
      } else {
        [self logMessage:@"Authorization error: %@", [error localizedDescription]];
        [self setAuthState:nil];
      }
    }];
  }];
}

- (IBAction)authNoCodeExchange:(nullable id)sender {
  NSURL *issuer = [NSURL URLWithString:kIssuer];
  NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];

  [self logMessage:@"Fetching configuration for issuer: %@", issuer];

  // discovers endpoints
  [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
      completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {

    if (!configuration) {
      [self logMessage:@"Error retrieving discovery document: %@", [error localizedDescription]];
      return;
    }

    [self logMessage:@"Got configuration: %@", configuration];

    // builds authentication request
    OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:kClientID
                                                        scopes:@[OIDScopeOpenID, OIDScopeProfile]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
    // performs authentication request
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self logMessage:@"Initiating authorization request %@", request];
    appDelegate.currentAuthorizationFlow =
        [OIDAuthorizationService presentAuthorizationRequest:request
            presentingViewController:self
                            callback:^(OIDAuthorizationResponse *_Nullable authorizationResponse,
                                       NSError *_Nullable error) {

      if (authorizationResponse) {
        OIDAuthState *authState =
            [[OIDAuthState alloc] initWithAuthorizationResponse:authorizationResponse];
        [self setAuthState:authState];

        [self logMessage:@"Authorization response with code: %@",
                         authorizationResponse.authorizationCode];
        // could just call [self tokenExchange:nil] directly, but will let the user initiate it.
      } else {
        [self logMessage:@"Authorization error: %@", [error localizedDescription]];
      }
    }];
  }];
}

- (IBAction)codeExchange:(nullable id)sender {
  // performs code exchange request
  OIDTokenRequest *tokenExchangeRequest =
      [_authState.lastAuthorizationResponse tokenExchangeRequest];

  [self logMessage:@"Performing authorization code exchange with request [%@]",
                   tokenExchangeRequest];

  [OIDAuthorizationService performTokenRequest:tokenExchangeRequest
                                      callback:^(OIDTokenResponse *_Nullable tokenResponse,
                                                 NSError *_Nullable error) {

    if (!tokenResponse) {
      [self logMessage:@"Token exchange error: %@", [error localizedDescription]];
    } else {
      [self logMessage:@"Received token response with accessToken: %@", tokenResponse.accessToken];
    }

    [_authState updateWithTokenResponse:tokenResponse error:error];
  }];
}

- (IBAction)clearAuthState:(nullable id)sender {
  [self setAuthState:nil];
}

- (IBAction)clearLog:(nullable id)sender {
  _logTextView.text = @"";
}

- (IBAction)userinfo:(nullable id)sender {
  NSURL *userinfoEndpoint =
      _authState.lastAuthorizationResponse.request.configuration.discoveryDocument.userinfoEndpoint;
  if (!userinfoEndpoint) {
    [self logMessage:@"Userinfo endpoint not declared in discovery document"];
    return;
  }
  NSString *currentAccessToken = _authState.lastTokenResponse.accessToken;

  [self logMessage:@"Performing userinfo request"];

  [_authState performActionWithFreshTokens:^(NSString *_Nonnull accessToken,
                                             NSString *_Nonnull idToken,
                                             NSError *_Nullable error) {
    if (error) {
      [self logMessage:@"Error fetching fresh tokens: %@", [error localizedDescription]];
      return;
    }

    // log whether a token refresh occurred
    if (![currentAccessToken isEqual:accessToken]) {
      [self logMessage:@"Access token was refreshed automatically (%@ to %@)",
                         currentAccessToken,
                         accessToken];
    } else {
      [self logMessage:@"Access token was fresh and not updated [%@]", accessToken];
    }

    // creates request to the userinfo endpoint, with access token in the Authorization header
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:userinfoEndpoint];
    NSString *authorizationHeaderValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [request addValue:authorizationHeaderValue forHTTPHeaderField:@"Authorization"];

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:nil
                                                     delegateQueue:nil];

    // performs HTTP request
    NSURLSessionDataTask *postDataTask =
        [session dataTaskWithRequest:request
                   completionHandler:^(NSData *_Nullable data,
                                       NSURLResponse *_Nullable response,
                                       NSError *_Nullable error) {
      dispatch_async(dispatch_get_main_queue(), ^() {
        if (error) {
          [self logMessage:@"HTTP request failed %@", error];
          return;
        }
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
          [self logMessage:@"Non-HTTP response"];
          return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        id jsonDictionaryOrArray =
            [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];

        if (httpResponse.statusCode != 200) {
          // server replied with an error
          NSString *responseText = [[NSString alloc] initWithData:data
                                                         encoding:NSUTF8StringEncoding];
          if (httpResponse.statusCode == 401) {
            // "401 Unauthorized" generally indicates there is an issue with the authorization
            // grant. Puts OIDAuthState into an error state.
            NSError *oauthError =
                [OIDErrorUtilities resourceServerAuthorizationErrorWithCode:0
                                                              errorResponse:jsonDictionaryOrArray
                                                            underlyingError:error];
            [_authState updateWithAuthorizationError:oauthError];
            // log error
            [self logMessage:@"Authorization Error (%@). Response: %@", oauthError, responseText];
          } else {
            [self logMessage:@"HTTP: %d. Response: %@",
                             (int)httpResponse.statusCode,
                             responseText];
          }
          return;
        }

        // success response
        [self logMessage:@"Success: %@", jsonDictionaryOrArray];
      });
    }];

    [postDataTask resume];
  }];
}

/*! @brief Logs a message to stdout and the textfield.
    @param format The format string and arguments.
 */
- (void)logMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
  // gets message as string
  va_list argp;
  va_start(argp, format);
  NSString *log = [[NSString alloc] initWithFormat:format arguments:argp];
  va_end(argp);

  // outputs to stdout
  NSLog(@"%@", log);

  // appends to output log
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.dateFormat = @"hh:mm:ss";
  NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
  _logTextView.text = [NSString stringWithFormat:@"%@%@%@: %@",
                                                 _logTextView.text,
                                                 ([_logTextView.text length] > 0) ? @"\n" : @"",
                                                 dateString,
                                                 log];
}

@end
