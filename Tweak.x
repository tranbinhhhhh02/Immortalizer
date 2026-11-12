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

// Thay phần chạy nền của Immortalizer, giữ nguyên skin
%hook FloatingButtonWindow
- (void)startPlayingSilentAudio { [[IPAKeepAlive shared] start]; }
- (void)stopPlayingSilentAudio  { [[IPAKeepAlive shared] stop]; }
%end
