// Keep alive (kiểu IPATweaksPlus) thay phần chạy nền của ImmortalizerJailed.
// Giữ nguyên UI/skin của ImmortalizerJailed (FloatingButtonWindow).
// Dylib này chỉ hook 2 method âm thanh của nó, KHÔNG thay UI.
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SilentAudio.h"

@interface IPAKeepAlive : NSObject
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@property (nonatomic, assign) BOOL running;
+ (instancetype)shared;
- (void)start;
- (void)stop;
@end

@implementation IPAKeepAlive
+ (instancetype)shared {
    static IPAKeepAlive *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [IPAKeepAlive new]; s.bgTask = UIBackgroundTaskInvalid; [s observe]; });
    return s;
}
- (void)observe {
    NSNotificationCenter *c = NSNotificationCenter.defaultCenter;
    [c addObserver:self selector:@selector(recover:) name:AVAudioSessionInterruptionNotification object:nil];
    [c addObserver:self selector:@selector(recover:) name:AVAudioSessionRouteChangeNotification object:nil];
    [c addObserver:self selector:@selector(rebuild:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [c addObserver:self selector:@selector(recover:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (BOOL)buildPlayer {
    NSData *d = [[NSData alloc] initWithBase64EncodedString:kIPASilentWavBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!d) return NO;
    NSError *e = nil;
    self.player = [[AVAudioPlayer alloc] initWithData:d error:&e];
    if (e || !self.player) return NO;
    self.player.numberOfLoops = -1;
    self.player.volume = 0.0;
    [self.player prepareToPlay];
    return YES;
}
- (void)start {
    if (self.running && self.player.isPlaying) return;
    NSError *e = nil;
    AVAudioSession *s = AVAudioSession.sharedInstance;
    [s setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&e];
    [s setActive:YES error:&e];
    if (!self.player && ![self buildPlayer]) return;
    [self.player play];
    self.running = YES;
    if (self.bgTask == UIBackgroundTaskInvalid) {
        self.bgTask = [UIApplication.sharedApplication beginBackgroundTaskWithName:@"imj.keepalive" expirationHandler:^{
            [UIApplication.sharedApplication endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
        }];
    }
}
- (void)stop {
    self.running = NO;
    [self.player stop];
    if (self.bgTask != UIBackgroundTaskInvalid) {
        [UIApplication.sharedApplication endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }
}
- (void)recover:(NSNotification *)n {
    if (!self.running) return;
    dispatch_async(dispatch_get_main_queue(), ^{ self.running = NO; [self start]; });
}
- (void)rebuild:(NSNotification *)n {
    self.player = nil;
    [self recover:n];
}
@end

// Hook bằng ObjC runtime (không cần Substrate nên chạy được trên IPA jailed)
#import <objc/runtime.h>

static BOOL gHooked = NO;

static void hookIMJ(void) {
    Class cls = objc_getClass("FloatingButtonWindow");
    if (!cls) return;
    Method m1 = class_getInstanceMethod(cls, NSSelectorFromString(@"startPlayingSilentAudio"));
    Method m2 = class_getInstanceMethod(cls, NSSelectorFromString(@"stopPlayingSilentAudio"));
    if (!m1 || !m2) return;
    method_setImplementation(m1, imp_implementationWithBlock(^(id self_) { [[IPAKeepAlive shared] start]; }));
    method_setImplementation(m2, imp_implementationWithBlock(^(id self_) { [[IPAKeepAlive shared] stop]; }));
    gHooked = YES;
}

static void tryHook(int n) {
    hookIMJ();
    if (gHooked) return;
    if (n >= 30) {
        // Không tìm thấy class của Immortalizer: tự bật keep-alive luôn
        [[IPAKeepAlive shared] start];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ tryHook(n + 1); });
}

__attribute__((constructor)) static void init_keepalive(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ tryHook(0); });
}
