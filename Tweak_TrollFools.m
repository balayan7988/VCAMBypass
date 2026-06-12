/*
 * VCAMBypass_TrollFools.m v1.0.2
 * TrollFools 专用：等待原版 VCAM.dylib 加载后再 hook，避免加载顺序导致未授权。
 * 用法：TrollFools 中只保留 原版 VCAM.dylib + VCAMBypass.dylib，不要注入 deb。
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static BOOL gInstalled = NO;
static int gRetryCount = 0;

static void VCBCallBlock(id block, id arg1, id arg2) {
    if (!block) return;
    @try { void (^b)(id, id) = (void (^)(id, id))block; b(arg1, arg2); return; } @catch (NSException *e) {}
    @try { void (^b)(id) = (void (^)(id))block; b(arg1); return; } @catch (NSException *e) {}
    @try { void (^b)(BOOL) = (void (^)(BOOL))block; b(YES); return; } @catch (NSException *e) {}
    @try { void (^b)(void) = (void (^)(void))block; b(); } @catch (NSException *e) {}
}

static NSDictionary *VCBFakeSuccess(NSString *action, NSString *kami) {
    return @{
        @"code": @200,
        @"status": @1,
        @"success": @YES,
        @"msg": @"success",
        @"message": @"success",
        @"action": action ?: @"verify",
        @"kami": kami ?: @"TROLL-BYPASS",
        @"vip": @1,
        @"valid": @1,
        @"data": @{
            @"code": @200,
            @"status": @1,
            @"success": @YES,
            @"valid": @1,
            @"vip": @1,
            @"is_vip": @1,
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
        NSDictionary *auth = VCBFakeSuccess(@"verify", @"TROLL-BYPASS");
        NSArray *keys = @[
            @"xnsp", @"VCamAuth", @"VCamVerify", @"VCamKami",
            @"isVerified", @"verified", @"kami_verified", @"auth_status",
            @"VCAM_AUTH", @"VCAM_VERIFY", @"kami", @"vip"
        ];
        for (NSString *k in keys) [ud setObject:auth forKey:k];
        [ud setBool:YES forKey:@"isVerified"];
        [ud setBool:YES forKey:@"verified"];
        [ud setBool:YES forKey:@"kami_verified"];
        [ud setBool:YES forKey:@"vip"];
        [ud setObject:@"TROLL-BYPASS" forKey:@"kami"];
        [ud synchronize];
    } @catch (NSException *e) {}
}

static void swizzleInst(Class cls, SEL sel, IMP newImp, IMP *origPtr) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[VCAMBypass] instance method missing: %@ %@", cls, NSStringFromSelector(sel)); return; }
    if (origPtr) *origPtr = method_getImplementation(m);
    method_setImplementation(m, newImp);
    NSLog(@"[VCAMBypass] hooked -[%@ %@]", cls, NSStringFromSelector(sel));
}

static void swizzleClass(Class cls, SEL sel, IMP newImp, IMP *origPtr) {
    Class meta = object_getClass(cls);
    Method m = class_getClassMethod(cls, sel);
    if (!m) { NSLog(@"[VCAMBypass] class method missing: %@ %@", cls, NSStringFromSelector(sel)); return; }
    if (origPtr) *origPtr = method_getImplementation(m);
    method_setImplementation(m, newImp);
    NSLog(@"[VCAMBypass] hooked +[%@ %@]", meta, NSStringFromSelector(sel));
}

// ---- VCamVerifyManager hooks ----
static id (*orig_sharedInstance)(id, SEL);
static id my_sharedInstance(id self, SEL _cmd) {
    VCBPersistAuthorized();
    id obj = orig_sharedInstance ? orig_sharedInstance(self, _cmd) : nil;
    return obj;
}

static id (*orig_getDeviceID)(id, SEL);
static id my_getDeviceID(id self, SEL _cmd) {
    id r = orig_getDeviceID ? orig_getDeviceID(self, _cmd) : nil;
    return r ?: @"TROLL-DEVICE";
}

static void (*orig_startVerifyProcess)(id, SEL);
static void my_startVerifyProcess(id self, SEL _cmd) {
    VCBPersistAuthorized();
    NSLog(@"[VCAMBypass] startVerifyProcess blocked");
}

static void (*orig_requestKamiVerify_completion)(id, SEL, id, id);
static void my_requestKamiVerify_completion(id self, SEL _cmd, id kami, id completion) {
    VCBPersistAuthorized();
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-BYPASS";
    NSLog(@"[VCAMBypass] requestKamiVerify bypass");
    VCBCallBlock(completion, VCBFakeSuccess(@"verify", k), nil);
}

static void (*orig_requestAPIWithAction_kami_isHeartbeat_completion)(id, SEL, id, id, BOOL, id);
static void my_requestAPIWithAction_kami_isHeartbeat_completion(id self, SEL _cmd, id action, id kami, BOOL hb, id completion) {
    VCBPersistAuthorized();
    NSString *a = [action isKindOfClass:NSString.class] ? action : (hb ? @"heartbeat" : @"verify");
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-BYPASS";
    NSLog(@"[VCAMBypass] requestAPI bypass action=%@ heartbeat=%d", a, hb);
    VCBCallBlock(completion, VCBFakeSuccess(a, k), nil);
}

static void (*orig_showKamiInputAlert_completion)(id, SEL, id, id);
static void my_showKamiInputAlert_completion(id self, SEL _cmd, id vc, id completion) {
    VCBPersistAuthorized();
    NSLog(@"[VCAMBypass] showKamiInputAlert bypass");
    VCBCallBlock(completion, @"TROLL-BYPASS", nil);
}

// ---- VCamMenuVC hooks ----
static void (*orig_verifyAndProceed)(id, SEL, id);
static void my_verifyAndProceed(id self, SEL _cmd, id completion) {
    VCBPersistAuthorized();
    NSLog(@"[VCAMBypass] verifyAndProceed bypass");
    VCBCallBlock(completion, @YES, nil);
}

static void (*orig_viewDidLoad)(id, SEL);
static void my_viewDidLoad(id self, SEL _cmd) {
    VCBPersistAuthorized();
    if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);
}

static void install_hooks_now(void);

static void retry_install(void) {
    if (gInstalled) return;
    if (gRetryCount++ > 120) {
        NSLog(@"[VCAMBypass] giving up: VCAM classes not loaded after retries");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        install_hooks_now();
    });
}

static void install_hooks_now(void) {
    if (gInstalled) return;

    Class verifyMgr = NSClassFromString(@"VCamVerifyManager");
    Class menuVC = NSClassFromString(@"VCamMenuVC");

    if (!verifyMgr) {
        NSLog(@"[VCAMBypass] waiting for VCamVerifyManager... retry=%d", gRetryCount);
        retry_install();
        return;
    }

    swizzleClass(verifyMgr, @selector(sharedInstance), (IMP)my_sharedInstance, (IMP *)&orig_sharedInstance);
    swizzleInst(verifyMgr, @selector(getDeviceID), (IMP)my_getDeviceID, (IMP *)&orig_getDeviceID);
    swizzleInst(verifyMgr, @selector(startVerifyProcess), (IMP)my_startVerifyProcess, (IMP *)&orig_startVerifyProcess);
    swizzleInst(verifyMgr, @selector(requestKamiVerify:completion:), (IMP)my_requestKamiVerify_completion, (IMP *)&orig_requestKamiVerify_completion);
    swizzleInst(verifyMgr, @selector(requestAPIWithAction:kami:isHeartbeat:completion:), (IMP)my_requestAPIWithAction_kami_isHeartbeat_completion, (IMP *)&orig_requestAPIWithAction_kami_isHeartbeat_completion);
    swizzleInst(verifyMgr, @selector(showKamiInputAlert:completion:), (IMP)my_showKamiInputAlert_completion, (IMP *)&orig_showKamiInputAlert_completion);

    if (menuVC) {
        swizzleInst(menuVC, NSSelectorFromString(@"verifyAndProceed:"), (IMP)my_verifyAndProceed, (IMP *)&orig_verifyAndProceed);
        swizzleInst(menuVC, @selector(viewDidLoad), (IMP)my_viewDidLoad, (IMP *)&orig_viewDidLoad);
    } else {
        NSLog(@"[VCAMBypass] VCamMenuVC not loaded yet; VerifyManager hooks installed anyway");
    }

    VCBPersistAuthorized();
    gInstalled = YES;
    NSLog(@"[VCAMBypass] hooks installed successfully after retry=%d", gRetryCount);
}

__attribute__((constructor))
static void entry(void) {
    @autoreleasepool {
        NSLog(@"[VCAMBypass] v1.0.2 loaded, delayed install enabled");
        dispatch_async(dispatch_get_main_queue(), ^{ install_hooks_now(); });
    }
}
