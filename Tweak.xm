#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void VCBCallCompletion(id completion, id response, id error) {
    if (!completion) return;

    void (^block2)(id, id) = nil;
    @try {
        block2 = (void (^)(id, id))completion;
        block2(response, error);
        return;
    } @catch (__unused NSException *e) {}

    void (^block1)(id) = nil;
    @try {
        block1 = (void (^)(id))completion;
        block1(response);
        return;
    } @catch (__unused NSException *e) {}

    void (^block0)(void) = nil;
    @try {
        block0 = (void (^)(void))completion;
        block0();
    } @catch (__unused NSException *e) {}
}

static NSDictionary *VCBSuccessPayload(NSString *action, NSString *kami, BOOL heartbeat) {
    NSString *now = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    return @{
        @"code": @200,
        @"status": @1,
        @"success": @YES,
        @"msg": @"success",
        @"message": @"success",
        @"action": action ?: @"verify",
        @"kami": kami ?: @"LOCAL-BYPASS",
        @"isHeartbeat": @(heartbeat),
        @"time": now,
        @"data": @{
            @"code": @200,
            @"status": @1,
            @"success": @YES,
            @"vip": @1,
            @"is_vip": @1,
            @"valid": @1,
            @"expire": @"2099-12-31 23:59:59",
            @"expire_time": @"2099-12-31 23:59:59",
            @"end_time": @"2099-12-31 23:59:59",
            @"remaining": @999999999
        }
    };
}

static void VCBPersistAuthorized(void) {
    @try {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDictionary *auth = @{
            @"code": @200,
            @"status": @1,
            @"success": @YES,
            @"vip": @1,
            @"valid": @1,
            @"kami": @"LOCAL-BYPASS",
            @"expire_time": @"2099-12-31 23:59:59"
        };
        NSArray *keys = @[
            @"xnsp", @"VCamAuth", @"VCamVerify", @"VCamKami",
            @"isVerified", @"verified", @"kami_verified", @"auth_status"
        ];
        for (NSString *k in keys) {
            [ud setObject:auth forKey:k];
        }
        [ud setBool:YES forKey:@"isVerified"];
        [ud setBool:YES forKey:@"verified"];
        [ud setObject:@"LOCAL-BYPASS" forKey:@"kami"];
        [ud synchronize];
    } @catch (__unused NSException *e) {}
}

%hook VCamVerifyManager

+ (id)sharedInstance {
    id obj = %orig;
    VCBPersistAuthorized();
    return obj;
}

- (void)startVerifyProcess {
    VCBPersistAuthorized();
    // Do not start the remote heartbeat timer.
    return;
}

- (id)getDeviceID {
    id orig = nil;
    @try { orig = %orig; } @catch (__unused NSException *e) {}
    if (orig) return orig;
    return @"LOCAL-DEVICE-ID";
}

- (void)requestKamiVerify:(id)kami completion:(id)completion {
    VCBPersistAuthorized();
    NSDictionary *payload = VCBSuccessPayload(@"verify", [kami isKindOfClass:NSString.class] ? kami : @"LOCAL-BYPASS", NO);
    VCBCallCompletion(completion, payload, nil);
}

- (void)requestAPIWithAction:(id)action kami:(id)kami isHeartbeat:(BOOL)isHeartbeat completion:(id)completion {
    VCBPersistAuthorized();
    NSString *act = [action isKindOfClass:NSString.class] ? action : (isHeartbeat ? @"heartbeat" : @"verify");
    NSString *card = [kami isKindOfClass:NSString.class] ? kami : @"LOCAL-BYPASS";
    NSDictionary *payload = VCBSuccessPayload(act, card, isHeartbeat);
    VCBCallCompletion(completion, payload, nil);
}

- (void)showKamiInputAlert:(id)vc completion:(id)completion {
    VCBPersistAuthorized();
    VCBCallCompletion(completion, @"LOCAL-BYPASS", nil);
}

%end

%hook VCamMenuVC

- (void)verifyAndProceed:(id)completion {
    VCBPersistAuthorized();
    VCBCallCompletion(completion, nil, nil);
}

- (void)viewDidLoad {
    VCBPersistAuthorized();
    %orig;
}

%end

%ctor {
    @autoreleasepool {
        VCBPersistAuthorized();
        NSLog(@"[VCAMBypass] loaded");
    }
}
