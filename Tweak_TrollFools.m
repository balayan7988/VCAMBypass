/*
 * VCAMBypass_TrollFools.m
 *
 * TrollFools 用法：
 *   1. 先注入原版 VCAM.dylib（保留所有功能）
 *   2. 再注入这个 VCAMBypass.dylib（只绕过验证）
 *
 * 编译：
 *   clang -arch arm64 -dynamiclib -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
 *     -framework Foundation -framework UIKit -fobjc-arc \
 *     -install_name @rpath/VCAMBypass.dylib -o VCAMBypass.dylib VCAMBypass_TrollFools.m
 *   ldid -S VCAMBypass.dylib
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 工具函数 ----------

static void VCBCallBlock(id block, id arg1, id arg2) {
    if (!block) return;
    // 试 (id, id) 签名
    @try { void (^b)(id, id) = (void (^)(id, id))block; b(arg1, arg2); return; } @catch (NSException *e) {}
    // 试 (id) 签名
    @try { void (^b)(id) = (void (^)(id))block; b(arg1); return; } @catch (NSException *e) {}
    // 试 (void) 签名
    @try { void (^b)(void) = (void (^)(void))block; b(); } @catch (NSException *e) {}
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
            @"code": @200, @"status": @1, @"valid": @1, @"vip": @1,
            @"expire_time": @"2099-12-31 23:59:59",
            @"remaining": @999999999
        }
    };
}

// ---------- Hook 方法 ----------

static id (*orig_getDeviceID)(id, SEL);
static id my_getDeviceID(id self, SEL _cmd) {
    id result = orig_getDeviceID ? orig_getDeviceID(self, _cmd) : @"TROLL-DEVICE";
    NSLog(@"[VCAMBypass] getDeviceID -> %@", result);
    return result;
}

static void (*orig_startVerifyProcess)(id, SEL);
static void my_startVerifyProcess(id self, SEL _cmd) {
    NSLog(@"[VCAMBypass] startVerifyProcess -> NOP (heartbeat disabled)");
    // 不调用 orig，直接 NOP 掉心跳
}

static void (*orig_requestKamiVerify_completion)(id, SEL, id, id);
static void my_requestKamiVerify_completion(id self, SEL _cmd, id kami, id completion) {
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-KEY";
    NSLog(@"[VCAMBypass] requestKamiVerify: bypassing with kami=%@", k);
    VCBCallBlock(completion, fakeSuccess(@"verify", k), nil);
}

static void (*orig_requestAPIWithAction_kami_isHeartbeat_completion)(id, SEL, id, id, BOOL, id);
static void my_requestAPIWithAction_kami_isHeartbeat_completion(id self, SEL _cmd, id action, id kami, BOOL hb, id completion) {
    NSString *a = [action isKindOfClass:NSString.class] ? action : @"verify";
    NSString *k = [kami isKindOfClass:NSString.class] ? kami : @"TROLL-KEY";
    NSLog(@"[VCAMBypass] requestAPI action=%@ heartbeat=%d bypassing", a, hb);
    VCBCallBlock(completion, fakeSuccess(a, k), nil);
}

static void (*orig_showKamiInputAlert_completion)(id, SEL, id, id);
static void my_showKamiInputAlert_completion(id self, SEL _cmd, id vc, id completion) {
    NSLog(@"[VCAMBypass] showKamiInputAlert -> bypassing");
    VCBCallBlock(completion, @"TROLL-KEY", nil);
}

// ---------- Method Swizzle ----------

static void swizzle(Class cls, SEL sel, IMP newImp, IMP *origPtr) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        NSLog(@"[VCAMBypass] WARNING: method %s not found on %@", sel_getName(sel), cls);
        return;
    }
    if (origPtr) *origPtr = method_getImplementation(m);
    method_setImplementation(m, newImp);
    NSLog(@"[VCAMBypass] hooked %@", NSStringFromSelector(sel));
}

// ---------- 安装入口 ----------

__attribute__((constructor))
static void install_hooks(void) {
    @autoreleasepool {
        NSLog(@"[VCAMBypass] === initializing ===");

        Class verifyMgr = NSClassFromString(@"VCamVerifyManager");
        if (!verifyMgr) {
            NSLog(@"[VCAMBypass] CRITICAL: VCamVerifyManager class not found. "
                  "Is VCAM.dylib loaded before this dylib?");
            return;
        }

        swizzle(verifyMgr, @selector(getDeviceID),
                (IMP)my_getDeviceID, (IMP *)&orig_getDeviceID);

        swizzle(verifyMgr, @selector(startVerifyProcess),
                (IMP)my_startVerifyProcess, (IMP *)&orig_startVerifyProcess);

        swizzle(verifyMgr, @selector(requestKamiVerify:completion:),
                (IMP)my_requestKamiVerify_completion, (IMP *)&orig_requestKamiVerify_completion);

        swizzle(verifyMgr, @selector(requestAPIWithAction:kami:isHeartbeat:completion:),
                (IMP)my_requestAPIWithAction_kami_isHeartbeat_completion,
                (IMP *)&orig_requestAPIWithAction_kami_isHeartbeat_completion);

        swizzle(verifyMgr, @selector(showKamiInputAlert:completion:),
                (IMP)my_showKamiInputAlert_completion, (IMP *)&orig_showKamiInputAlert_completion);

        NSLog(@"[VCAMBypass] === %d hooks installed ===", 5);
    }
}
