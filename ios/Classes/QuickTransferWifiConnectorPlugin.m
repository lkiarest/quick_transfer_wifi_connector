#import "QuickTransferWifiConnectorPlugin.h"

#import <NetworkExtension/NetworkExtension.h>
#import <UIKit/UIKit.h>

@implementation QuickTransferWifiConnectorPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"quick_transfer_wifi_connector"
                                                                binaryMessenger:[registrar messenger]];
    QuickTransferWifiConnectorPlugin *instance = [[QuickTransferWifiConnectorPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"joinWifiNetwork"]) {
        [self joinWifiNetwork:call result:result];
        return;
    }
    if ([call.method isEqualToString:@"openWifiSettings"]) {
        [self openWifiSettingsWithResult:result];
        return;
    }
    result(FlutterMethodNotImplemented);
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

    if (@available(iOS 11.0, *)) {
        NEHotspotConfiguration *configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:password isWEP:NO];
        configuration.joinOnce = joinOnce;
        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSInteger errorCode = error.code;
                    if (errorCode == NEHotspotConfigurationErrorAlreadyAssociated) {
                        result(@{
                            @"status": @"connected",
                            @"message": [NSString stringWithFormat:@"Already connected to %@.", ssid],
                            @"platform": @"ios"
                        });
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

                result(@{
                    @"status": @"connected",
                    @"message": [NSString stringWithFormat:@"Wi-Fi configuration applied for %@.", ssid],
                    @"platform": @"ios"
                });
            });
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

@end
