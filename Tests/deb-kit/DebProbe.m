#import <UIKit/UIKit.h>

// Deliberately has no dependency on jailbreak frameworks or CydiaSubstrate.
// It proves that BloomBox extracted and injected the actual .dylib from a .deb.
static void markInjected(void) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) {
        for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
            if (!candidate.hidden && candidate.rootViewController) { window = candidate; break; }
        }
    }
    UIView *root = window.rootViewController.view;
    if (!root) return;
    UILabel *status = (UILabel *)[root viewWithTag:9090];
    if ([status isKindOfClass:UILabel.class]) {
        status.text = @"✅ TWEAK .DEB CARGADO\nLa librería se está ejecutando.";
        status.textColor = UIColor.systemGreenColor;
    }
    if ([root viewWithTag:9091]) return;
    UILabel *banner = [[UILabel alloc] initWithFrame:CGRectZero];
    banner.tag = 9091;
    banner.text = @"BloomBox .deb ✓";
    banner.backgroundColor = [UIColor colorWithRed:0.12 green:0.55 blue:0.36 alpha:0.95];
    banner.textColor = UIColor.whiteColor;
    banner.font = [UIFont boldSystemFontOfSize:16];
    banner.textAlignment = NSTextAlignmentCenter;
    banner.layer.cornerRadius = 12;
    banner.layer.masksToBounds = YES;
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:banner];
    [NSLayoutConstraint activateConstraints:@[
        [banner.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:15],
        [banner.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [banner.widthAnchor constraintEqualToConstant:200],
        [banner.heightAnchor constraintEqualToConstant:42]
    ]];
}

__attribute__((constructor))
static void debProbeInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:NSOperationQueue.mainQueue
                                                      usingBlock:^(__unused NSNotification *notification) {
            markInjected();
        }];
        markInjected();
    });
}
