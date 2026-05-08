#import "QuickTransferWifiConnectorPlugin.h"

#import <NetworkExtension/NetworkExtension.h>
#import <UIKit/UIKit.h>

@interface QuickTransferWifiConnectorPlugin ()

@property(nonatomic, copy, nullable) NSString *previousSSID;
@property(nonatomic, copy, nullable) NSString *deviceSSID;
@property(nonatomic, copy, nullable) NSString *lastObservedSSID;

- (void)prepareForDeviceWifiTransition:(FlutterMethodCall *)call result:(FlutterResult)result;
- (void)joinWifiNetwork:(FlutterMethodCall *)call result:(FlutterResult)result;
- (void)restorePreviousNetwork:(FlutterMethodCall *)call result:(FlutterResult)result;
- (void)openWifiSettingsWithResult:(FlutterResult)result;
- (void)capturePreviousSSIDExcluding:(NSString *)deviceSSID;
- (void)fetchCurrentSSIDWithCompletion:(void (^)(NSString * _Nullable ssid))completion;
- (void)waitForSSID:(NSString *)ssid
           deadline:(NSDate *)deadline
         completion:(void (^)(BOOL connected, NSString * _Nullable currentSSID))completion;

@end

@implementation QuickTransferWifiConnectorPlugin

static const NSTimeInterval kWifiAssociationTimeoutSeconds = 30.0;
static const NSTimeInterval kWifiAssociationPollIntervalSeconds = 0.75;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"quick_transfer_wifi_connector"
                                                                binaryMessenger:[registrar messenger]];
    QuickTransferWifiConnectorPlugin *instance = [[QuickTransferWifiConnectorPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"prepareForDeviceWifiTransition"]) {
        [self prepareForDeviceWifiTransition:call result:result];
        return;
    }
    if ([call.method isEqualToString:@"joinWifiNetwork"]) {
        [self joinWifiNetwork:call result:result];
        return;
    }
    if ([call.method isEqualToString:@"restorePreviousNetwork"]) {
        [self restorePreviousNetwork:call result:result];
        return;
    }
    if ([call.method isEqualToString:@"openWifiSettings"]) {
        [self openWifiSettingsWithResult:result];
        return;
    }
    result(FlutterMethodNotImplemented);
}

- (void)prepareForDeviceWifiTransition:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : nil;
    if (!arguments) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Arguments must be a map." details:nil]);
        return;
    }

    NSString *rawSsid = [arguments[@"deviceSsid"] isKindOfClass:[NSString class]] ? arguments[@"deviceSsid"] : @"";
    NSString *ssid = [rawSsid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self capturePreviousSSIDExcluding:ssid];
    self.deviceSSID = ssid;
    result(nil);
}

- (void)joinWifiNetwork:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : nil;
    if (!arguments) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Arguments must be a map." details:nil]);
        return;
    }

    NSString *rawSsid = [arguments[@"ssid"] isKindOfClass:[NSString class]] ? arguments[@"ssid"] : @"";
    NSString *ssid = [rawSsid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = [arguments[@"password"] isKindOfClass:[NSString class]] ? arguments[@"password"] : @"";
    BOOL joinOnce = [arguments[@"joinOnce"] respondsToSelector:@selector(boolValue)] ? [arguments[@"joinOnce"] boolValue] : YES;

    if (ssid.length == 0) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"SSID must not be empty." details:nil]);
        return;
    }

    if (password.length < 8 || password.length > 63) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                   message:@"WPA/WPA2 password must be 8 to 63 characters."
                                   details:nil]);
        return;
    }

    [self capturePreviousSSIDExcluding:ssid];
    self.deviceSSID = ssid;

    if (@available(iOS 11.0, *)) {
        void (^finishAfterAssociation)(NSString *) = ^(NSString *prefix) {
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:kWifiAssociationTimeoutSeconds];
            [self waitForSSID:ssid deadline:deadline completion:^(BOOL connected, NSString * _Nullable currentSSID) {
                if (connected) {
                    NSString *message = currentSSID.length > 0
                        ? [NSString stringWithFormat:@"%@ %@.", prefix, currentSSID]
                        : [NSString stringWithFormat:@"%@ %@.", prefix, ssid];
                    result(@{
                        @"status": @"connected",
                        @"message": message,
                        @"platform": @"ios"
                    });
                    return;
                }

                NSString *detail = currentSSID.length > 0
                    ? [NSString stringWithFormat:@" current=%@", currentSSID]
                    : @" current=<unknown>";
                result(@{
                    @"status": @"failed",
                    @"message": [NSString stringWithFormat:@"Timed out waiting for iOS to associate with %@.%@", ssid, detail],
                    @"platform": @"ios"
                });
            }];
        };

        [self fetchCurrentSSIDWithCompletion:^(NSString * _Nullable currentSSID) {
            if (currentSSID.length > 0 && [currentSSID isEqualToString:ssid]) {
                result(@{
                    @"status": @"connected",
                    @"message": [NSString stringWithFormat:@"Already connected to %@.", ssid],
                    @"platform": @"ios"
                });
                return;
            }

            NEHotspotConfiguration *configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:password isWEP:NO];
            configuration.joinOnce = joinOnce;
            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        NSInteger errorCode = error.code;
                        if (errorCode == NEHotspotConfigurationErrorAlreadyAssociated) {
                            finishAfterAssociation(@"Already associated with");
                            return;
                        }
                        if (errorCode == NEHotspotConfigurationErrorUserDenied) {
                            result(@{
                                @"status": @"userDenied",
                                @"message": @"User denied Wi-Fi configuration.",
                                @"platform": @"ios"
                            });
                            return;
                        }
                        result(@{
                            @"status": @"failed",
                            @"message": error.localizedDescription ?: @"",
                            @"platform": @"ios"
                        });
                        return;
                    }

                    finishAfterAssociation(@"Connected to");
                });
            }];
        }];
        return;
    }

    result(@{
        @"status": @"unavailable",
        @"message": @"iOS 11.0 or later is required.",
        @"platform": @"ios"
    });
}

- (void)openWifiSettingsWithResult:(FlutterResult)result {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (!url) {
        result(@NO);
        return;
    }
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL opened) {
        result(@(opened));
    }];
}

- (void)restorePreviousNetwork:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : nil;
    if (!arguments) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Arguments must be a map." details:nil]);
        return;
    }

    NSString *fallbackSsid = self.deviceSSID ?: @"";
    NSString *rawSsid = [arguments[@"deviceSsid"] isKindOfClass:[NSString class]] ? arguments[@"deviceSsid"] : fallbackSsid;
    NSString *ssid = [rawSsid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (@available(iOS 11.0, *)) {
        if (ssid.length > 0) {
            [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
        }

        NSString *message = self.previousSSID.length > 0
            ? [NSString stringWithFormat:@"已移除设备热点配置，系统将尝试恢复到之前的网络：%@", self.previousSSID]
            : @"已移除设备热点配置，系统将尝试恢复默认网络。";
        result(@{
            @"status": @"best_effort",
            @"message": message,
            @"platform": @"ios"
        });
        return;
    }

    result(@{
        @"status": @"unavailable",
        @"message": @"iOS 11.0 or later is required.",
        @"platform": @"ios"
    });
}

- (void)capturePreviousSSIDExcluding:(NSString *)deviceSSID {
    [self fetchCurrentSSIDWithCompletion:^(NSString * _Nullable ssid) {
        if (ssid.length == 0 || [ssid isEqualToString:deviceSSID]) {
            return;
        }

        self.previousSSID = ssid;
    }];
}

- (void)fetchCurrentSSIDWithCompletion:(void (^)(NSString * _Nullable ssid))completion {
    if (@available(iOS 14.0, *)) {
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            NSString *ssid = [currentNetwork.SSID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ssid.length > 0) {
                    self.lastObservedSSID = ssid;
                }
                completion(ssid.length > 0 ? ssid : nil);
            });
        }];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil);
    });
}

- (void)waitForSSID:(NSString *)ssid
           deadline:(NSDate *)deadline
         completion:(void (^)(BOOL connected, NSString * _Nullable currentSSID))completion {
    if (@available(iOS 14.0, *)) {
        [self fetchCurrentSSIDWithCompletion:^(NSString * _Nullable currentSSID) {
            if (currentSSID.length > 0 && [currentSSID isEqualToString:ssid]) {
                completion(YES, currentSSID);
                return;
            }

            if ([[NSDate date] compare:deadline] != NSOrderedAscending) {
                completion(NO, currentSSID != nil ? currentSSID : self.lastObservedSSID);
                return;
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWifiAssociationPollIntervalSeconds * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self waitForSSID:ssid deadline:deadline completion:completion];
            });
        }];
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        completion(YES, nil);
    });
}

@end
