#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* ================================================================
   VCAMBypass — TrollFools 专用版
   ================================================================
   用法：只把这个 dylib 用 TrollFools 注入到目标 App
   不需要同时注入原版 VCAM.dylib！
   这个补丁 hook 的是 VCAM 原版 dylib 里的验证类，不是替换它。

   原版 VCAM.dylib 应已通过 TrollFools 注入过一次，
   然后单独再用 TrollFools 注入这个 VCAMBypass.dylib。
   或者如果你还没注入原版：先注入原版 VCAM.dylib，再注入这个。
   ================================================================ */

static void VCBCallBlock(id block, id arg1, id arg2) {
    if (!block) return;
    // Try (id response, id error) signature
    @try {
        void (^b)(id, id) = (void (^)(id, id))block;
        b(arg1, arg2);
        return;
    } @catch (NSException *e) {}
    // Try (id response) signature
    @try {
        void (^b)(id) = (void (^)(id))block;
        b(arg1);
        return;
    } @catch (NSException *e) {}
    // Try (void) signature
    @try {
        void (^b)(void) = (void (^)(void))block;
        b();
    } @catch (NSException *e) {}
}

static NSDictionary *fakeSuccess(NSString *action, NSString *kami) {
    return @{
        @"code": @200,
        @"status": @1,
        @"success": @YES,
        @"msg": @"success",
        @"action": action ?: @"verify",
        @"kami": kami ?: @"TROLL-BYPASS",
        @"data": @{
            @"code": @200,
            @"status": @1,
            @"valid": @1,
            @"vip": @1,
            @"expire_time": @"2099-12-31 23:59:59",
            @"remaining": @999999999
        }
    };
}

/* ---------------------------------------------------------------
   Hook VCamVerifyManager (验证管理器)
   --------------------------------------------------------------- */
static void (*orig_startVerifyProcess)(id, SEL);
static void my_startVerifyProcess(id self, SEL _cmd) {
    // 不启动心跳，也不做任何事
    return;
}

static id (*orig_getDeviceID)(id, SEL);
static id my_getDeviceID(id self, SEL _cmd) {
    return @"TROLL-DEVICE";
}

static void (*orig_requestKamiVerify_completion)(id, SEL, id, id);
static void my_requestKamiVerify_completion(id self, SEL _cmd, id kami, id completion) {
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-KEY";
    VCBCallBlock(completion, fakeSuccess(@"verify", k), nil);
}

static void (*orig_requestAPIWithAction_kami_isHeartbeat_completion)(id, SEL, id, id, BOOL, id);
static void my_requestAPIWithAction_kami_isHeartbeat_completion(id self, SEL _cmd, id action, id kami, BOOL hb, id completion) {
    NSString *a = [action isKindOfClass:NSString.class] ? action : @"verify";
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-KEY";
    VCBCallBlock(completion, fakeSuccess(a, k), nil);
}

static void (*orig_showKamiInputAlert_completion)(id, SEL, id, id);
static void my_showKamiInputAlert_completion(id self, SEL _cmd, id vc, id completion) {
    VCBCallBlock(completion, @"TROLL-KEY", nil);
}

/* ---------------------------------------------------------------
   安装 hooks（ObjC method swizzling，不依赖 Substrate）
   --------------------------------------------------------------- */
static void swizzle(Class cls, SEL sel, IMP newImp, IMP *origPtr) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    *origPtr = method_getImplementation(m);
    method_setImplementation(m, newImp);
}

__attribute__((constructor))
static void install_hooks(void) {
    @autoreleasepool {
        Class verifyMgr = NSClassFromString(@"VCamVerifyManager");
        if (!verifyMgr) {
            NSLog(@"[VCAMBypass] VCamVerifyManager not found — VCAM.dylib not loaded?");
            return;
        }

        swizzle(verifyMgr, NSSelectorFromString(@"startVerifyProcess"),
                (IMP)my_startVerifyProcess, (IMP *)&orig_startVerifyProcess);

        swizzle(verifyMgr, NSSelectorFromString(@"getDeviceID"),
                (IMP)my_getDeviceID, (IMP *)&orig_getDeviceID);

        swizzle(verifyMgr, NSSelectorFromString(@"requestKamiVerify:completion:"),
                (IMP)my_requestKamiVerify_completion, (IMP *)&orig_requestKamiVerify_completion);

        swizzle(verifyMgr, NSSelectorFromString(@"requestAPIWithAction:kami:isHeartbeat:completion:"),
                (IMP)my_requestAPIWithAction_kami_isHeartbeat_completion, (IMP *)&orig_requestAPIWithAction_kami_isHeartbeat_completion);

        swizzle(verifyMgr, NSSelectorFromString(@"showKamiInputAlert:completion:"),
                (IMP)my_showKamiInputAlert_completion, (IMP *)&orig_showKamiInputAlert_completion);

        NSLog(@"[VCAMBypass] hooks installed successfully");
    }
}
