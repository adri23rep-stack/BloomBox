#import <UIKit/UIKit.h>

@interface DebDemoDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation DebDemoDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *viewController = [UIViewController new];
    viewController.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.14 alpha:1];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"BloomBox .deb Test";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:28];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [viewController.view addSubview:title];
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectZero];
    status.tag = 9090;
    status.text = @"SIN TWEAK\nImporta BloomBoxDebProbe.deb en BloomBox.";
    status.numberOfLines = 0;
    status.textColor = UIColor.systemOrangeColor;
    status.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    status.textAlignment = NSTextAlignmentCenter;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [viewController.view addSubview:status];
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:viewController.view.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:viewController.view.centerYAnchor constant:-55],
        [status.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:22],
        [status.leadingAnchor constraintEqualToAnchor:viewController.view.leadingAnchor constant:20],
        [status.trailingAnchor constraintEqualToAnchor:viewController.view.trailingAnchor constant:-20]
    ]];
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(DebDemoDelegate.class));
    }
}
