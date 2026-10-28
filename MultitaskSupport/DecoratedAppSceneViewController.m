#import "DecoratedAppSceneViewController.h"
#import "ResizeHandleView.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "AppSceneViewController.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import "PiPManager.h"
#import "VirtualWindowsHostView.h"
#import "../LiveContainer/Localization.h"
#import "utils.h"

@interface DecoratedAppSceneViewController()
@property(nonatomic) NSArray* activatedVerticalConstraints;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) int pid;
@property(nonatomic) CGRect originalFrame;
@property(nonatomic) UIBarButtonItem *maximizeButton;
@property(nonatomic) bool isAppTerminationRequested;
@property(nonatomic, strong) UIControl *immersiveMenuBackdrop;
@property(nonatomic, strong) UIButton *immersiveMenuHandle;
@property(nonatomic, strong) UIView *immersiveMenuCluster;
@property(nonatomic, strong) NSArray<UIButton *> *immersiveMenuButtons;
@property(nonatomic) NSUInteger immersiveMenuGeneration;
@property(nonatomic, strong) UIView *immersiveHandleMark;
@property(nonatomic, strong) NSLayoutConstraint *immersiveHandleCenterX;
@property(nonatomic, strong) NSLayoutConstraint *immersiveHandleCenterY;
@property(nonatomic, strong) NSLayoutConstraint *immersiveHandleWidth;
@property(nonatomic, strong) NSLayoutConstraint *immersiveHandleHeight;
@property(nonatomic) NSInteger immersiveHandleEdge; // 0 bottom, 1 right, 2 top, 3 left
@property(nonatomic) CGFloat immersiveHandleFraction;
@property(nonatomic) BOOL immersiveHandleDragging;
@property(nonatomic) CGPoint immersiveHandleTouchOffset;
@end

@implementation DecoratedAppSceneViewController
- (instancetype)initWindowName:(NSString*)windowName bundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID rootVC:(UIViewController*)rootVC {
    return [self initWindowName:windowName bundleId:bundleId dataUUID:dataUUID rootVC:rootVC fullScreen:NO];
}
- (instancetype)initWindowName:(NSString*)windowName bundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID rootVC:(UIViewController*)rootVC fullScreen:(BOOL)fullScreen {
    self = [super initWithNibName:nil bundle:nil];
    self.view = [[UIStackView alloc] initWithFrame:self.view.frame];
    [MultitaskDockManager.shared.windowHostingView addSubview:self.view];
    [rootVC addChildViewController:self];
    
    _dataUUID = dataUUID;
    _scaleRatio = 1.0;
    _isMaximized = fullScreen || [NSUserDefaults.lcUserDefaults boolForKey:@"LCLaunchMultitaskMaximized"];
    _appSceneVC = [[AppSceneViewController alloc] initWithBundleId:bundleId dataUUID:dataUUID delegate:self];
    self.title = windowName;
    [self setupDecoratedView];
    [self setupImmersiveMenuControls];
    
    [MultitaskDockManager.shared addRunningApp:windowName appUUID:dataUUID view:self.view];
    
    NSArray *menuItems = @[
        [UIAction actionWithTitle:@"lc.multitask.copyPid".loc image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = @(self.appSceneVC.pid).stringValue;
        }],
        [UIAction actionWithTitle:@"lc.multitask.enablePip".loc image:[UIImage systemImageNamed:@"pip.enter"] identifier:nil handler:^(UIAction * _Nonnull action) {
            if ([PiPManager.shared isPiPWithVC:self.appSceneVC]) {
                [PiPManager.shared stopPiP];
            } else {
                [PiPManager.shared startPiPWithVC:self.appSceneVC];
            }
        }],
        [UICustomViewMenuElement elementWithViewProvider:^UIView *(UICustomViewMenuElement *element) {
            return [self scaleSliderViewWithTitle:@"lc.multitask.scale".loc min:0.5 max:2.0 value:self.scaleRatio stepInterval:0.01];
        }]
    ];
    

    __weak typeof(self) weakSelf = self;
    [self.navigationItem setTitleMenuProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions){
        if(!weakSelf.appSceneVC.isAppRunning) {
            return [UIMenu menuWithTitle:NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", nil) children:@[]];
        } else {
            NSString *pidText = [NSString stringWithFormat:@"PID: %d", weakSelf.pid];
            return [UIMenu menuWithTitle:pidText children:menuItems];
        }
    }];
    
    UIImage *minimizeImage = [UIImage systemImageNamed:@"house.fill"];
    UIImageConfiguration *minimizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
    minimizeImage = [minimizeImage imageWithConfiguration:minimizeConfig];
    UIBarButtonItem *minimizeButton = [[UIBarButtonItem alloc] initWithImage:minimizeImage style:UIBarButtonItemStylePlain target:self action:@selector(returnToLauncher)];
    minimizeButton.tintColor = [UIColor labelColor];
    
    NSString *maximizeImageName = _isMaximized ? @"arrow.down.right.and.arrow.up.left.circle" : @"arrow.up.left.and.arrow.down.right.circle";
    UIImage *maximizeImage = [UIImage systemImageNamed:maximizeImageName];
    UIImageConfiguration *maximizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
    maximizeImage = [maximizeImage imageWithConfiguration:maximizeConfig];
    self.maximizeButton = [[UIBarButtonItem alloc] initWithImage:maximizeImage style:UIBarButtonItemStylePlain target:self action:@selector(maximizeWindow)];
    self.maximizeButton.tintColor = [UIColor systemGreenColor];
    
    UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle"];
    UIImageConfiguration *closeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
    closeImage = [closeImage imageWithConfiguration:closeConfig];
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:closeImage style:UIBarButtonItemStylePlain target:self action:@selector(closeWindow)];
    closeButton.tintColor = [UIColor systemRedColor];
    
    minimizeButton.accessibilityLabel = @"Inicio";
    closeButton.accessibilityLabel = @"Cerrar esta app";
    UIBarButtonItem *appsButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.stack.fill"]
        style:UIBarButtonItemStylePlain target:nil action:nil];
    appsButton.menu = [MultitaskDockManager.shared sessionMenu];
    appsButton.accessibilityLabel = @"Apps abiertas y posición de la barra";
    NSArray *barButtonItems = @[minimizeButton, appsButton, closeButton];
    if([NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"]) {
        // resize handle overlaps the close button, so put the buttons on the left
        self.navigationItem.leftBarButtonItems = barButtonItems;
    } else {
        self.navigationItem.rightBarButtonItems = barButtonItems;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-8.0 rightMargin:-4.0];
    });

    return self;
}


// MARK: - Approved BloomBox Radial Probe 1.5 controls
// These controls are attached to the real guest window, not a demo app.
// A small tap target works without interfering with iOS Home gestures.
- (BOOL)immersiveMenuEnabled {
    id setting = [NSUserDefaults.lcSharedDefaults objectForKey:@"LCImmersiveRadialMenu"];
    return setting == nil ? YES : [setting boolValue];
}

- (void)setupImmersiveMenuControls {
    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults;
    // First launch defaults below the Dynamic Island, away from the Home gesture.
    NSInteger edge = [defaults objectForKey:@"LCImmersiveHandleEdge"] ? [defaults integerForKey:@"LCImmersiveHandleEdge"] : 2;
    self.immersiveHandleEdge = MAX(0, MIN(3, edge));
    self.immersiveHandleFraction = [defaults objectForKey:@"LCImmersiveHandleFraction"]
        ? MIN(1.0, MAX(0.0, [defaults doubleForKey:@"LCImmersiveHandleFraction"])) : .5;

    UIButton *handle = [UIButton buttonWithType:UIButtonTypeCustom];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.accessibilityLabel = @"Mostrar controles de BloomBox. Mantén presionado para mover la barrita.";
    handle.backgroundColor = UIColor.clearColor;
    [handle addTarget:self action:@selector(toggleImmersiveMenu) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *drag = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragImmersiveHandle:)];
    drag.minimumPressDuration = .38;
    drag.allowableMovement = 16;
    drag.cancelsTouchesInView = YES;
    [handle addGestureRecognizer:drag];
    self.immersiveMenuHandle = handle;

    UIView *mark = [UIView new];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.backgroundColor = [UIColor colorWithWhite:1 alpha:.58];
    mark.layer.cornerRadius = 3.5;
    mark.userInteractionEnabled = NO;
    self.immersiveHandleMark = mark;
    [handle addSubview:mark];
    [self.view addSubview:handle];

    self.immersiveHandleCenterX = [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
    self.immersiveHandleCenterY = [handle.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
    self.immersiveHandleWidth = [handle.widthAnchor constraintEqualToConstant:86];
    self.immersiveHandleHeight = [handle.heightAnchor constraintEqualToConstant:48];
    [NSLayoutConstraint activateConstraints:@[
        self.immersiveHandleCenterX, self.immersiveHandleCenterY,
        self.immersiveHandleWidth, self.immersiveHandleHeight,
        [mark.centerXAnchor constraintEqualToAnchor:handle.centerXAnchor],
        [mark.centerYAnchor constraintEqualToAnchor:handle.centerYAnchor constant:-4],
        [mark.widthAnchor constraintEqualToConstant:38],
        [mark.heightAnchor constraintEqualToConstant:7]
    ]];
    [self positionImmersiveHandleAnimated:NO];
    [self updateImmersiveMenuVisibility];
}

- (CGFloat)immersiveClamp:(CGFloat)value minimum:(CGFloat)min maximum:(CGFloat)max {
    return MAX(min, MIN(MAX(min, max), value));
}

- (CGPoint)immersiveHandleTarget {
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) return CGPointZero;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat horizontalRoom = MAX(100.0, width - safe.left - safe.right);
    CGFloat edgeX = MIN(105.0, horizontalRoom * .28);
    CGFloat minX = safe.left + edgeX;
    CGFloat maxX = MAX(minX, width - safe.right - edgeX);
    CGFloat minY = MIN(safe.top + 105.0, height * .40);
    CGFloat maxY = MAX(minY, height - safe.bottom - 105.0);
    CGFloat fraction = [self immersiveClamp:self.immersiveHandleFraction minimum:0 maximum:1];

    switch (self.immersiveHandleEdge) {
        case 1: return CGPointMake(width - safe.right - 24, minY + (maxY - minY) * fraction);
        case 2: return CGPointMake(minX + (maxX - minX) * fraction, safe.top + 38);
        case 3: return CGPointMake(safe.left + 24, minY + (maxY - minY) * fraction);
        default: return CGPointMake(minX + (maxX - minX) * fraction, height - 24);
    }
}

- (void)positionImmersiveHandleAnimated:(BOOL)animated {
    if (!self.immersiveMenuHandle || self.immersiveHandleDragging || CGRectIsEmpty(self.view.bounds)) return;
    CGPoint point = [self immersiveHandleTarget];
    BOOL side = self.immersiveHandleEdge == 1 || self.immersiveHandleEdge == 3;
    CGFloat offsetX = point.x - CGRectGetMidX(self.view.bounds);
    CGFloat offsetY = point.y - CGRectGetMidY(self.view.bounds);
    if (fabs(self.immersiveHandleCenterX.constant - offsetX) < .1 &&
        fabs(self.immersiveHandleCenterY.constant - offsetY) < .1 &&
        fabs(self.immersiveHandleWidth.constant - (side ? 48 : 86)) < .1) return;
    void (^updates)(void) = ^{
        self.immersiveHandleCenterX.constant = offsetX;
        self.immersiveHandleCenterY.constant = offsetY;
        self.immersiveHandleWidth.constant = side ? 48 : 86;
        self.immersiveHandleHeight.constant = side ? 86 : 48;
        self.immersiveHandleMark.transform = side ? CGAffineTransformMakeRotation(M_PI_2) : CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:.35 delay:0 usingSpringWithDamping:.76
              initialSpringVelocity:.4 options:UIViewAnimationOptionCurveEaseOut
                         animations:updates completion:nil];
    } else {
        updates();
    }
}

- (void)dragImmersiveHandle:(UILongPressGestureRecognizer *)gesture {
    if (!self.isMaximized || ![self immersiveMenuEnabled] || self.view.hidden) return;
    CGPoint touch = [gesture locationInView:self.view];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self hideImmersiveMenuImmediately];
        [self.view layoutIfNeeded];
        self.immersiveHandleDragging = YES;
        self.immersiveHandleTouchOffset = CGPointMake(self.immersiveMenuHandle.center.x - touch.x,
                                                      self.immersiveMenuHandle.center.y - touch.y);
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    } else if (gesture.state == UIGestureRecognizerStateChanged && self.immersiveHandleDragging) {
        CGFloat halfWidth = self.immersiveHandleWidth.constant * .5;
        CGFloat halfHeight = self.immersiveHandleHeight.constant * .5;
        UIEdgeInsets safe = self.view.safeAreaInsets;
        CGFloat x = [self immersiveClamp:(touch.x + self.immersiveHandleTouchOffset.x)
                                minimum:safe.left + halfWidth
                                maximum:self.view.bounds.size.width - safe.right - halfWidth];
        CGFloat y = [self immersiveClamp:(touch.y + self.immersiveHandleTouchOffset.y)
                                minimum:MAX(halfHeight, self.view.safeAreaInsets.top)
                                maximum:self.view.bounds.size.height - halfHeight];
        self.immersiveHandleCenterX.constant = x - CGRectGetMidX(self.view.bounds);
        self.immersiveHandleCenterY.constant = y - CGRectGetMidY(self.view.bounds);
        // Only the small tappable bar moves; no dock or overlay obscures a game.
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled ||
               gesture.state == UIGestureRecognizerStateFailed) {
        if (!self.immersiveHandleDragging) return;
        // Read the live drag position before allowing layout to snap the handle.
        CGPoint point = CGPointMake(CGRectGetMidX(self.view.bounds) + self.immersiveHandleCenterX.constant,
                                    CGRectGetMidY(self.view.bounds) + self.immersiveHandleCenterY.constant);
        self.immersiveHandleDragging = NO;
        CGSize size = self.view.bounds.size;
        CGFloat safeTop = self.view.safeAreaInsets.top;
        CGFloat distances[] = { size.height - point.y,
                                size.width - self.view.safeAreaInsets.right - point.x,
                                MAX(0, point.y - safeTop),
                                point.x - self.view.safeAreaInsets.left };
        NSInteger closest = 0;
        for (NSInteger edge = 1; edge < 4; edge++) {
            if (distances[edge] < distances[closest]) closest = edge;
        }
        self.immersiveHandleEdge = closest;

        CGFloat low, high, position;
        if (closest == 0 || closest == 2) {
            UIEdgeInsets safe = self.view.safeAreaInsets;
            CGFloat horizontalRoom = MAX(100.0, size.width - safe.left - safe.right);
            CGFloat edgeX = MIN(105.0, horizontalRoom * .28);
            low = safe.left + edgeX;
            high = size.width - safe.right - edgeX;
            position = point.x;
        } else {
            low = MIN(safeTop + 105.0, size.height * .40);
            high = MAX(low, size.height - self.view.safeAreaInsets.bottom - 105.0);
            position = point.y;
        }
        self.immersiveHandleFraction = high > low
            ? [self immersiveClamp:(position - low) / (high - low) minimum:0 maximum:1] : .5;
        [NSUserDefaults.lcSharedDefaults setInteger:closest forKey:@"LCImmersiveHandleEdge"];
        [NSUserDefaults.lcSharedDefaults setDouble:self.immersiveHandleFraction forKey:@"LCImmersiveHandleFraction"];
        [self positionImmersiveHandleAnimated:YES];
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self positionImmersiveHandleAnimated:NO];
}

- (void)updateImmersiveMenuVisibility {
    BOOL enabled = self.isMaximized && [self immersiveMenuEnabled];
    if (!enabled && self.immersiveMenuBackdrop) [self hideImmersiveMenuImmediately];
    self.immersiveMenuHandle.hidden = !enabled;
    if (enabled && self.immersiveMenuHandle != nil) {
        [self positionImmersiveHandleAnimated:NO];
        [self.view bringSubviewToFront:self.immersiveMenuHandle];
    }
}

- (UIButton *)immersiveBubble:(NSString *)symbol diameter:(CGFloat)diameter
                        label:(NSString *)label action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = label;
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = diameter / 2.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = .85;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:.29].CGColor;

    UIVisualEffect *material = nil;
    if (@available(iOS 26.0, *)) {
        // Clear glass is installed after the buttons enter the view hierarchy.
        material = nil;
    } else {
        material = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:material];
    glassView.translatesAutoresizingMaskIntoConstraints = NO;
    glassView.tag = 7415;
    glassView.layer.cornerRadius = diameter / 2.0;
    glassView.layer.masksToBounds = YES;
    glassView.userInteractionEnabled = NO;
    [button addSubview:glassView];
    [NSLayoutConstraint activateConstraints:@[
        [glassView.topAnchor constraintEqualToAnchor:button.topAnchor],
        [glassView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
        [glassView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [glassView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor]
    ]];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
    UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:config]];
    image.translatesAutoresizingMaskIntoConstraints = NO;
    image.tintColor = UIColor.labelColor;
    image.contentMode = UIViewContentModeScaleAspectFit;
    image.userInteractionEnabled = NO;
    [glassView.contentView addSubview:image];
    [NSLayoutConstraint activateConstraints:@[
        [image.centerXAnchor constraintEqualToAnchor:glassView.contentView.centerXAnchor],
        [image.centerYAnchor constraintEqualToAnchor:glassView.contentView.centerYAnchor],
        [image.widthAnchor constraintLessThanOrEqualToConstant:diameter * .46],
        [image.heightAnchor constraintLessThanOrEqualToConstant:diameter * .46]
    ]];
    if (action != NULL) [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:diameter],
        [button.heightAnchor constraintEqualToConstant:diameter]
    ]];
    return button;
}

- (void)activateImmersiveGlass:(UIView *)container {
    if (@available(iOS 26.0, *)) {
        for (UIView *child in container.subviews) {
            if ([child isKindOfClass:UIVisualEffectView.class]) {
                UIVisualEffectView *v = (UIVisualEffectView *)child;
                if (v.tag == 7415 && v.effect == nil) {
                    UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
                    glass.interactive = YES;
                    v.effect = glass;
                }
                continue;
            }
            [self activateImmersiveGlass:child];
        }
    }
}

- (void)toggleImmersiveMenu {
    if (self.immersiveMenuBackdrop) [self hideImmersiveMenu];
    else [self showImmersiveMenu];
}

- (void)showImmersiveMenu {
    if (!self.isMaximized || ![self immersiveMenuEnabled] || self.view.hidden || !self.immersiveMenuHandle) return;
    if (self.immersiveMenuBackdrop) {
        [self scheduleImmersiveMenuDismissal];
        return;
    }
    [self.view layoutIfNeeded];
    UIControl *backdrop = [[UIControl alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor = UIColor.clearColor;
    [backdrop addTarget:self action:@selector(hideImmersiveMenu) forControlEvents:UIControlEventTouchUpInside];
    self.immersiveMenuBackdrop = backdrop;
    [self.view insertSubview:backdrop belowSubview:self.immersiveMenuHandle];

    // Host buttons fan toward the inside of the screen from the selected edge.
    // Buttons belong directly to the backdrop, so tapping elsewhere dismisses it.
    UIView *cluster = backdrop;
    self.immersiveMenuCluster = cluster;
    UIButton *home = [self immersiveBubble:@"house.fill" diameter:60 label:@"Escritorio de BloomBox" action:@selector(immersiveGoHome)];
    UIButton *resize = [self immersiveBubble:@"arrow.up.left.and.arrow.down.right" diameter:62 label:@"Cambiar tamaño" action:@selector(immersiveRestoreWindow)];
    UIButton *apps = [self immersiveBubble:@"square.stack.3d.up.fill" diameter:62 label:@"Apps abiertas" action:NULL];
    apps.menu = [MultitaskDockManager.shared sessionMenu];
    apps.showsMenuAsPrimaryAction = YES;

    self.immersiveMenuButtons = @[home, resize, apps];
    CGPoint handle = [backdrop convertPoint:self.immersiveMenuHandle.center fromView:self.view];
    CGFloat maxX = CGRectGetWidth(backdrop.bounds);
    CGFloat maxY = CGRectGetHeight(backdrop.bounds);
    UIEdgeInsets insets = self.view.safeAreaInsets;
    for (NSUInteger i = 0; i < self.immersiveMenuButtons.count; i++) {
        UIButton *button = self.immersiveMenuButtons[i];
        CGFloat dx = 0, dy = 0;
        switch (self.immersiveHandleEdge) {
            case 1: // Right edge, fan toward the left
                dx = i == 0 ? -148 : -78;
                dy = i == 0 ? 0 : (i == 1 ? -66 : 66);
                break;
            case 2: // Top edge, fan downward
                dx = i == 0 ? 0 : (i == 1 ? -66 : 66);
                dy = i == 0 ? 148 : 78;
                break;
            case 3: // Left edge, fan toward the right
                dx = i == 0 ? 148 : 78;
                dy = i == 0 ? 0 : (i == 1 ? -66 : 66);
                break;
            default: // Bottom edge, fan upward
                dx = i == 0 ? 0 : (i == 1 ? -66 : 66);
                dy = i == 0 ? -148 : -78;
                break;
        }
        CGFloat centerX = [self immersiveClamp:handle.x + dx
                                          minimum:insets.left + 34 maximum:maxX - insets.right - 34];
        CGFloat centerY = [self immersiveClamp:handle.y + dy minimum:insets.top + 34 maximum:maxY - insets.bottom - 34];
        [backdrop addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.centerXAnchor constraintEqualToAnchor:backdrop.leadingAnchor constant:centerX],
            [button.centerYAnchor constraintEqualToAnchor:backdrop.topAnchor constant:centerY]
        ]];
    }
    [backdrop layoutIfNeeded];
    [self activateImmersiveGlass:backdrop];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    CGPoint origin = [backdrop convertPoint:self.immersiveMenuHandle.center fromView:self.view];
    for (UIButton *button in self.immersiveMenuButtons) {
        CGAffineTransform birth = CGAffineTransformMakeScale(.14, .14);
        birth.tx = origin.x - button.center.x;
        birth.ty = origin.y - button.center.y;
        button.transform = birth;
        button.userInteractionEnabled = NO;
    }
    [self.immersiveMenuButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, BOOL *stop) {
        [UIView animateWithDuration:reduceMotion ? .18 : .46
                              delay:reduceMotion ? 0 : index * .055
             usingSpringWithDamping:reduceMotion ? 1.0 : .62
              initialSpringVelocity:reduceMotion ? 0 : .78
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{ button.transform = CGAffineTransformIdentity; }
                         completion:^(__unused BOOL finished) {
            if (self.immersiveMenuBackdrop == backdrop) button.userInteractionEnabled = YES;
        }];
    }];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self scheduleImmersiveMenuDismissal];
}

- (void)scheduleImmersiveMenuDismissal {
    NSUInteger generation = ++self.immersiveMenuGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf && weakSelf.immersiveMenuGeneration == generation) [weakSelf hideImmersiveMenu];
    });
}

- (void)hideImmersiveMenuImmediately {
    ++self.immersiveMenuGeneration;
    UIControl *backdrop = self.immersiveMenuBackdrop;
    self.immersiveMenuBackdrop = nil;
    self.immersiveMenuCluster = nil;
    self.immersiveMenuButtons = nil;
    [backdrop removeFromSuperview];
}

- (void)hideImmersiveMenu {
    ++self.immersiveMenuGeneration;
    UIControl *backdrop = self.immersiveMenuBackdrop;
    if (!backdrop) return;
    self.immersiveMenuBackdrop = nil;
    backdrop.userInteractionEnabled = NO;
    UIView *cluster = self.immersiveMenuCluster;
    NSArray<UIButton *> *buttons = [self.immersiveMenuButtons copy];
    self.immersiveMenuCluster = nil;
    self.immersiveMenuButtons = nil;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    CGPoint origin = [backdrop convertPoint:self.immersiveMenuHandle.center fromView:self.view];
    [buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, BOOL *stop) {
        CGAffineTransform inverse = CGAffineTransformMakeScale(.13, .13);
        inverse.tx = origin.x - button.center.x;
        inverse.ty = origin.y - button.center.y;
        [UIView animateWithDuration:reduceMotion ? .12 : .21
                              delay:reduceMotion ? 0 : (buttons.count - 1 - index) * .025
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{ button.transform = inverse; }
                         completion:nil];
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((reduceMotion ? .13 : .29) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [backdrop removeFromSuperview]; });
}

- (void)immersiveGoHome {
    [self hideImmersiveMenuImmediately];
    [self returnToLauncher];
}

- (void)immersiveRestoreWindow {
    [self hideImmersiveMenuImmediately];
    if (self.isMaximized) [self maximizeWindow];
}

- (void)setupDecoratedView {
    CGFloat navBarHeight = 44;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(UIApp.statusBarOrientation);
    CGRect frame = CGRectMake(0, 0, isLandscape ? 480 : 320, (isLandscape ? 320 : 480) + navBarHeight);
    CGPoint rootViewCenter = self.view.superview.center;
    frame.origin = CGPointMake(rootViewCenter.x - frame.size.width / 2, rootViewCenter.y - frame.size.height / 2);
    
    if(_isMaximized) {
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        // save origin as normalized coordinates
        frame.origin.x /= maxFrame.size.width;
        frame.origin.y /= maxFrame.size.height;
        self.originalFrame = frame;
    } else {
        self.view.frame = frame;
    }
    
    // Navigation bar
    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, navBarHeight)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:self.title];
    navigationBar.items = @[navigationItem];

    // Keep the host controls light and translucent over dark or light guest apps.
    UINavigationBarAppearance *glassAppearance = [[UINavigationBarAppearance alloc] init];
    [glassAppearance configureWithTransparentBackground];
    glassAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    glassAppearance.backgroundColor = [UIColor systemBackgroundColor];
    glassAppearance.backgroundColor = [glassAppearance.backgroundColor colorWithAlphaComponent:0.25];
    glassAppearance.shadowColor = [UIColor clearColor];
    navigationBar.standardAppearance = glassAppearance;
    navigationBar.scrollEdgeAppearance = glassAppearance;
    navigationBar.compactAppearance = glassAppearance;

    self.view.axis = UILayoutConstraintAxisVertical;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.layer.cornerRadius = 10;
    self.view.layer.masksToBounds = YES;

    self.navigationBar = navigationBar;
    self.navigationItem = navigationBar.items.firstObject;
    if (!self.navigationBar.superview) {
        [self.view addArrangedSubview:self.navigationBar];
    }
    
    CGRect contentFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - navBarHeight);
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if([NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"]) {
        [self.view insertArrangedSubview:fixedPositionContentView atIndex:0];
    } else {
        [self.view addArrangedSubview:fixedPositionContentView];
    }
    [self.view sendSubviewToBack:fixedPositionContentView];
    
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.anchorPoint = self.contentView.layer.position = CGPointMake(0, 0);
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [fixedPositionContentView addSubview:self.contentView];
    
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [self.navigationBar addGestureRecognizer:moveGesture];

    // Resize handle (idea stolen from Notes debugging window)
    UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - navBarHeight, self.view.frame.size.height - navBarHeight, navBarHeight, navBarHeight)];
    self.resizeHandle.alpha = _isMaximized ? 0.0 : 1.0;
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.view addSubview:self.resizeHandle];
    
    self.view.layer.borderWidth = _isMaximized ? 0.0 : 1.0;
    self.view.layer.borderColor = UIColor.secondarySystemBackgroundColor.CGColor;
    
    [self addChildViewController:_appSceneVC];
    [self.view insertSubview:_appSceneVC.view atIndex:0];
    _appSceneVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self updateVerticalConstraints];
    [NSLayoutConstraint activateConstraints:@[
        [_appSceneVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_appSceneVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    
    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults;

    [defaults addObserver:self forKeyPath:@"LCMultitaskBottomWindowBar" options:NSKeyValueObservingOptionNew context:NULL];
    [self updateOriginalFrame];
}


// Stolen from UIKitester
- (UIView *)scaleSliderViewWithTitle:(NSString *)title min:(CGFloat)minValue max:(CGFloat)maxValue value:(CGFloat)initialValue stepInterval:(CGFloat)step {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.exclusiveTouch = YES;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 0.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:10.0],
        [stackView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8.0],
        [stackView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16.0],
        [stackView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16.0]
    ]];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont boldSystemFontOfSize:12.0];
    [stackView addArrangedSubview:label];
    
    _UIPrototypingMenuSlider *slider = [[_UIPrototypingMenuSlider alloc] init];
    slider.minimumValue = minValue;
    slider.maximumValue = maxValue;
    slider.value = initialValue;
    slider.stepSize = step;
    
    NSLayoutConstraint *sliderHeight = [slider.heightAnchor constraintEqualToConstant:40.0];
    sliderHeight.active = YES;
    
    [stackView addArrangedSubview:slider];
    
    [slider addTarget:self action:@selector(scaleSliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    return containerView;
}

- (void)scaleSliderChanged:(_UIPrototypingMenuSlider *)slider {
    self.scaleRatio = slider.value;
    self.appSceneVC.scaleRatio = _scaleRatio;
    if(self.appSceneVC.usesHostingControllerAPI) {
        self.appSceneVC.contentView.transform = CGAffineTransformMakeScale(_scaleRatio, _scaleRatio);
    } else {
        self.appSceneVC.contentView.layer.sublayerTransform = CATransform3DMakeScale(_scaleRatio, _scaleRatio, 1.0);
    }
    __weak typeof(self) weakSelf = self;
    [self.appSceneVC updateFrameWithSettingsBlock:^(UIMutableApplicationSceneSettings *settings) {
        if(weakSelf.isMaximized) {
            [weakSelf updateMaximizedSafeAreaWithSettings:settings];
        } else {
            // it seems some apps don't honor these settings so we don't cover the top of the app
            settings.peripheryInsets = UIEdgeInsetsZero;
            settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
        }
    }];
}

- (void)returnToLauncher {
    [MultitaskDockManager.shared minimizeAllWindowsExcept:nil];
    [MultitaskDockManager.shared showSessionDock];
}

- (void)closeWindow {
    [self hideImmersiveMenu];
    _isAppTerminationRequested = true;
    if([_appSceneVC isAppRunning]) {
        [_appSceneVC terminate];
    } else {
        [self appSceneVCAppDidExit:self.appSceneVC];
    }
}

- (void)minimizeWindow {
    [self hideImmersiveMenu];
    if (self.view.hidden) return;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
        self.view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        if (!finished) return;
        self.view.hidden = YES;
        self.view.transform = CGAffineTransformIdentity;
        [self.view.superview sendSubviewToBack:self.view];
    }];
}

- (void)minimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.hidden = YES;
    }];
}

- (void)unminimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.hidden = NO;
        self.view.alpha = 1;
    } completion:nil];
}

- (void)maximizeWindow {
    [self hideImmersiveMenu];
    void (^updateSettingsBlock)(UIMutableApplicationSceneSettings *settings);
    
    [self.view layoutIfNeeded];
    if (self.isMaximized) {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateWindowedFrameWithSettings:settings];
        };
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.view.layer.borderWidth = 1;
            self.resizeHandle.alpha = 1;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.isMaximized = NO;
            [self updateVerticalConstraints];
            [self updateImmersiveMenuVisibility];
            UIImage *maximizeImage = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle"];
            UIImageConfiguration *maximizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [maximizeImage imageWithConfiguration:maximizeConfig];
        }];
    } else {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateMaximizedFrameWithSettings:settings];
        };
        [self updateOriginalFrame];
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.isMaximized = YES;
            [self updateVerticalConstraints];
            
            self.view.layer.borderWidth = 0;
            self.resizeHandle.alpha = 0;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            UIImage *restoreImage = [UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left.circle"];
            UIImageConfiguration *restoreConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [restoreImage imageWithConfiguration:restoreConfig];
            [self updateImmersiveMenuVisibility];
        }];
    }
}

- (void)appSceneVCAppDidExit:(AppSceneViewController*)vc {
    [self hideImmersiveMenu];
    BOOL skipTerminationScreen = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCSkipTerminatedScreen"];
    BOOL isManual = _isAppTerminationRequested;
    if(isManual || skipTerminationScreen) {
        
        MultitaskDockManager *dock = [MultitaskDockManager shared];
        [dock removeRunningApp:self.dataUUID];
        
        self.view.layer.masksToBounds = NO;
        [UIView transitionWithView:self.view duration:0.4 options:UIViewAnimationOptionTransitionCurlUp animations:^{
            self.view.hidden = YES;
        } completion:^(BOOL b){
            [self.view removeFromSuperview];
        }];
        
        if(skipTerminationScreen) {
            [MultitaskRelaunchManager scheduleRelaunchIfNeededWithBundleId:self.appSceneVC.bundleId dataUUID:self.dataUUID isManualTermination:isManual];
        }
    } else {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.text = NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", @"");
        label.textAlignment = NSTextAlignmentCenter;
        [self.view insertSubview:label atIndex:0];
    }
}

- (void)appSceneVC:(AppSceneViewController*)vc didInitializeWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(error) {
            [vc appTerminationCleanUp];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"lc.common.error".loc message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.ok".loc style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.copy".loc style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = error.localizedDescription;
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            self.pid = vc.pid;
            [self updateOriginalFrame];
            if (self.pidAvailableHandler) {
                self.pidAvailableHandler(@(self.pid), nil);
            }
        }
    });
}

- (void)appSceneVCWillActivateScene:(AppSceneViewController *)vc {
    // Set up initial settings such as frame, safe area, etc
    [self appSceneVC:vc didUpdateFromSettings:vc.presenter.scene.settings.mutableCopy transitionContext:nil lifecycleActionType:0];
}

- (void)appSceneVC:(AppSceneViewController*)vc didUpdateFromSettings:(UIMutableApplicationSceneSettings *)baseSettings transitionContext:(id)newContext lifecycleActionType:(uint32_t)actionType {
    [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.userInterfaceStyle = baseSettings.userInterfaceStyle;
        settings.interfaceOrientation = baseSettings.interfaceOrientation;
        settings.deviceOrientation = baseSettings.deviceOrientation;
        settings.foreground = YES;
        
        if(self.isMaximized) {
            [self updateMaximizedFrameWithSettings:settings];
        } else {
            [self updateWindowedFrameWithSettings:settings];
        }
        CGRect newFrame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - self.navigationBar.frame.size.height/self.scaleRatio);
        
        if(UIInterfaceOrientationIsLandscape(baseSettings.interfaceOrientation)) {
            settings.frame = CGRectMake(0, 0, newFrame.size.height, newFrame.size.width);
        } else {
            settings.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
        }
    }];
}

- (void)adjustNavigationBarButtonSpacingWithNegativeSpacing:(CGFloat)spacing rightMargin:(CGFloat)margin {
    if (!self.navigationBar) return;
    [self findAndAdjustButtonBarStackView:self.navigationBar withSpacing:spacing rightMargin:margin];
}

- (void)findAndAdjustButtonBarStackView:(UIView *)view withSpacing:(CGFloat)spacing rightMargin:(CGFloat)margin {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"_UIButtonBarStackView")]) {
            if ([subview respondsToSelector:@selector(setSpacing:)]) {
                [(_UIButtonBarStackView *)subview setSpacing:spacing];
            }
            
            if (subview.superview) {
                for (NSLayoutConstraint *constraint in subview.superview.constraints) {
                    if ((constraint.firstItem == subview && constraint.firstAttribute == NSLayoutAttributeTrailing) ||
                        (constraint.secondItem == subview && constraint.secondAttribute == NSLayoutAttributeTrailing)) {
                        constraint.constant = (constraint.firstItem == subview) ? -margin : margin;
                        break;
                    }
                }
                
                [subview setNeedsLayout];
                [subview.superview setNeedsLayout];
            }
            
            return;
        }
        
        [self findAndAdjustButtonBarStackView:subview withSpacing:spacing rightMargin:margin];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [change[NSKeyValueChangeNewKey] boolValue];
        if(bottomWindowBar) {
            self.navigationItem.leftBarButtonItems = self.navigationItem.rightBarButtonItems;
            self.navigationItem.rightBarButtonItems = nil;
            [self.view addArrangedSubview:self.navigationBar];
        } else {
            self.navigationItem.rightBarButtonItems = self.navigationItem.leftBarButtonItems;
            self.navigationItem.leftBarButtonItems = nil;
            [self.view insertArrangedSubview:self.navigationBar atIndex:0];
        }
        
        [self updateVerticalConstraints];
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-8.0 rightMargin:-4.0];
        
        if(_isMaximized) {
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [self updateMaximizedFrameWithSettings:settings];
            }];
        }
        [self.view layoutIfNeeded];
    }];
}

- (void)moveWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];

    self.view.center = CGPointMake(self.view.center.x + point.x, self.view.center.y + point.y);
    [self updateOriginalFrame];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];

    CGRect frame = self.view.frame;
    frame.size.width = MAX(50, frame.size.width + point.x);
    frame.size.height = MAX(50, frame.size.height + point.y);
    self.view.frame = frame;
    [self updateOriginalFrame];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    // FIXME: how to bring view to front when touching the passthrough view?
    [self.view.superview bringSubviewToFront:self.view];
}

- (void)updateVerticalConstraints {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
        // Immersive mode keeps the hosted app edge-to-edge; a swipe opens the radial menu.
        BOOL hideWindowBar = self.isMaximized && [self immersiveMenuEnabled];
        CGFloat navBarHeight = hideWindowBar ? 0 : 44;
        self.navigationBar.alpha = hideWindowBar ? 0 : 1;
        self.navigationBar.hidden = hideWindowBar;
        
        // Update safe area insets
        if(self.isMaximized) {
            self.appSceneVC.shouldSkipDebounceOnce = YES;
            __weak typeof(self) weakSelf = self;
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [weakSelf updateMaximizedFrameWithSettings:settings];
            }];
        }
        
        [NSLayoutConstraint deactivateConstraints:self.activatedVerticalConstraints];
        if(bottomWindowBar) {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-navBarHeight],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        } else {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:navBarHeight],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        }
        [NSLayoutConstraint activateConstraints:self.activatedVerticalConstraints];

        [self.view layoutIfNeeded];
        [self updateImmersiveMenuVisibility];
    }];
}

- (UIEdgeInsets)updateMaximizedSafeAreaWithSettings:(UIMutableApplicationSceneSettings *)settings {
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    if(self.navigationBar.hidden) {
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets = UIEdgeInsetsZero;
    } else if(bottomWindowBar) {
        // allow the control bar to overlap the bottom safe area
        safeAreaInsets.bottom = 0;
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets.top = safeAreaInsets.left = safeAreaInsets.right = 0;
    } else {
        settings.peripheryInsets = UIEdgeInsetsMake(0, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right);
        safeAreaInsets.bottom = safeAreaInsets.left = safeAreaInsets.right = 0;
    }
    
    // scale peripheryInsets to match the scale ratio
    settings.peripheryInsets = UIEdgeInsetsMake(settings.peripheryInsets.top/_scaleRatio, settings.peripheryInsets.left/_scaleRatio, settings.peripheryInsets.bottom/_scaleRatio, settings.peripheryInsets.right/_scaleRatio);
    if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        UIInterfaceOrientation currentOrientation = UIApp.statusBarOrientation;
        if(UIInterfaceOrientationIsLandscape(currentOrientation)) {
            safeAreaInsets.top = 0;
        }
        settings.safeAreaInsetsPortrait = LCUIEdgeInsetsRotateToOrientation(settings.peripheryInsets, currentOrientation);

    } else {
        settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.top, settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right);
    }
    
    safeAreaInsets.bottom = 0;
    return safeAreaInsets;
}

- (void)updateMaximizedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, [self updateMaximizedSafeAreaWithSettings:settings]);
    self.view.frame = maxFrame;
}

- (void)updateWindowedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, safeAreaInsets);
    settings.peripheryInsets = UIEdgeInsetsZero;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
    
    CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
    CGPoint center = self.view.center;
    CGRect frame = CGRectZero;
    frame.size.width = MIN(newFrame.size.width, maxFrame.size.width);
    frame.size.height = MIN(newFrame.size.height, maxFrame.size.height);
    CGFloat oobOffset = MAX(30, frame.size.width - 30);
    frame.origin.x = MAX(maxFrame.origin.x - oobOffset, MIN(CGRectGetMaxX(maxFrame) - frame.size.width + oobOffset, center.x - frame.size.width / 2));
    frame.origin.y = MAX(maxFrame.origin.y, MIN(center.y - frame.size.height / 2, CGRectGetMaxY(maxFrame) - frame.size.height));
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = frame;
    }];
}

- (void)updateOriginalFrame {
    if(_isMaximized) return;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
    // save origin as normalized coordinates
    self.originalFrame = CGRectMake(self.view.frame.origin.x / maxFrame.size.width, self.view.frame.origin.y / maxFrame.size.height, self.view.frame.size.width, self.view.frame.size.height);
}

@end
