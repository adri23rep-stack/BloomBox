
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// Standalone BloomBox radial-menu usability test. No system-gesture deferral.
// Glass is clipped to its own circular control, not resized by autoresizing masks.
@interface RadialProbe : UIViewController
@property(nonatomic,strong) UIControl *overlay;
@property(nonatomic,strong) UIView *cluster;
@property(nonatomic,strong) UIButton *orb;
@property(nonatomic,strong) UILabel *state;
@property(nonatomic,strong) UIView *content;
@property(nonatomic,strong) UIView *fake;
@property(nonatomic) BOOL compact;
@property(nonatomic) NSUInteger generation;
@end
@implementation RadialProbe

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (BOOL)prefersHomeIndicatorAutoHidden { return NO; }

- (UILabel *)text:(NSString *)value size:(CGFloat)size {
    UILabel *l = [UILabel new];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = value;
    l.textColor = UIColor.whiteColor;
    l.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:.025 green:.04 blue:.09 alpha:1];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[UIColor colorWithRed:.11 green:.21 blue:.37 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.02 green:.035 blue:.09 alpha:1].CGColor
    ];
    gradient.startPoint = CGPointMake(.3,0);
    gradient.endPoint = CGPointMake(.7,1);
    gradient.frame = UIScreen.mainScreen.bounds;
    [self.view.layer insertSublayer:gradient atIndex:0];

    self.content = [UIView new];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.content];
    [NSLayoutConstraint activateConstraints:@[
        [self.content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.content.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UILabel *title = [self text:@"BloomBox" size:35];
    title.font = [UIFont systemFontOfSize:35 weight:UIFontWeightBold];
    UILabel *subtitle = [self text:@"Radial Probe 1.2" size:15];
    subtitle.textColor = [UIColor colorWithWhite:.74 alpha:1];
    UILabel *instruction = [self text:@"Toca la bolita de cristal de abajo.\nEl menú aparecerá sin ningún gesto." size:18];
    self.state = [self text:@"PANTALLA LIBRE · MENÚ CERRADO" size:12];
    self.state.textColor = [UIColor colorWithRed:.66 green:.9 blue:1 alpha:1];
    UIView *demo = [UIView new];
    demo.translatesAutoresizingMaskIntoConstraints = NO;
    demo.backgroundColor = [UIColor colorWithRed:.12 green:.17 blue:.27 alpha:.8];
    demo.layer.cornerRadius = 24;
    demo.layer.borderWidth = .75;
    demo.layer.borderColor = [UIColor colorWithWhite:1 alpha:.17].CGColor;
    UILabel *sample = [self text:@"♫\n\nContenido de prueba\n\nEl menú no debe tapar la app\nmientras está cerrado." size:19];
    [self.content addSubview:title];
    [self.content addSubview:subtitle];
    [self.content addSubview:instruction];
    [self.content addSubview:demo];
    [self.content addSubview:self.state];
    [demo addSubview:sample];
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:self.content.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:self.content.safeAreaLayoutGuide.topAnchor constant:60],
        [subtitle.centerXAnchor constraintEqualToAnchor:title.centerXAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [instruction.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:30],
        [instruction.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-30],
        [instruction.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:27],
        [demo.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:26],
        [demo.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-26],
        [demo.centerYAnchor constraintEqualToAnchor:self.content.centerYAnchor constant:10],
        [demo.heightAnchor constraintEqualToConstant:220],
        [sample.leadingAnchor constraintEqualToAnchor:demo.leadingAnchor constant:18],
        [sample.trailingAnchor constraintEqualToAnchor:demo.trailingAnchor constant:-18],
        [sample.centerYAnchor constraintEqualToAnchor:demo.centerYAnchor],
        [self.state.centerXAnchor constraintEqualToAnchor:self.content.centerXAnchor],
        [self.state.bottomAnchor constraintEqualToAnchor:self.content.safeAreaLayoutGuide.bottomAnchor constant:-104]
    ]];

    // Only this single compact control remains above the running app.
    self.orb = [self bubble:@"circle.grid.2x2.fill" label:@"Abrir controles de BloomBox" diameter:58 action:@selector(toggleMenu)];
    [self.view addSubview:self.orb];
    [NSLayoutConstraint activateConstraints:@[
        [self.orb.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.orb.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-6]
    ]];
}

- (UIButton *)bubble:(NSString *)icon label:(NSString *)label diameter:(CGFloat)diameter action:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = label;
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:.09];
    button.layer.cornerRadius = diameter * .5;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:.37].CGColor;

    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    if (@available(iOS 26.0,*)) {
        UIGlassEffect *glass = [UIGlassEffect new];
        glass.interactive = NO;
        effect = glass;
    }
    UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
    glassView.translatesAutoresizingMaskIntoConstraints = NO;
    glassView.userInteractionEnabled = NO;
    glassView.layer.cornerRadius = diameter * .5;
    glassView.layer.masksToBounds = YES;
    [button addSubview:glassView];
    [NSLayoutConstraint activateConstraints:@[
        [glassView.topAnchor constraintEqualToAnchor:button.topAnchor],
        [glassView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
        [glassView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [glassView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor]
    ]];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:diameter > 80 ? 28 : 24
                                                        weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:icon withConfiguration:config];
    UIImageView *image = [[UIImageView alloc] initWithImage:symbol];
    image.translatesAutoresizingMaskIntoConstraints = NO;
    image.tintColor = UIColor.whiteColor;
    image.contentMode = UIViewContentModeScaleAspectFit;
    image.userInteractionEnabled = NO;
    [button addSubview:image];
    [NSLayoutConstraint activateConstraints:@[
        [image.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [image.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [image.widthAnchor constraintLessThanOrEqualToConstant:diameter*.45],
        [image.heightAnchor constraintLessThanOrEqualToConstant:diameter*.45]
    ]];

    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:diameter],
        [button.heightAnchor constraintEqualToConstant:diameter]
    ]];
    return button;
}

- (void)toggleMenu {
    if (self.overlay) [self hideMenu];
    else [self openMenu];
}

- (void)openMenu {
    if (self.overlay) return;
    [self.view layoutIfNeeded];

    UIControl *background = [[UIControl alloc] initWithFrame:self.view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    background.backgroundColor = UIColor.clearColor;
    [background addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    self.overlay = background;
    [self.view insertSubview:background belowSubview:self.orb];

    UIView *cluster = [UIView new];
    cluster.translatesAutoresizingMaskIntoConstraints = NO;
    self.cluster = cluster;
    cluster.backgroundColor = UIColor.clearColor;
    [background addSubview:cluster];
    [NSLayoutConstraint activateConstraints:@[
        [cluster.centerXAnchor constraintEqualToAnchor:self.orb.centerXAnchor],
        [cluster.bottomAnchor constraintEqualToAnchor:self.orb.topAnchor constant:-6],
        [cluster.widthAnchor constraintEqualToConstant:290],
        [cluster.heightAnchor constraintEqualToConstant:252]
    ]];

    UIButton *home = [self bubble:@"house.fill" label:@"Inicio simulado" diameter:68 action:@selector(homeAction)];
    UIButton *window = [self bubble:@"arrow.up.left.and.arrow.down.right" label:@"Cambiar tamaño simulado" diameter:68 action:@selector(resizeAction)];
    UIButton *apps = [self bubble:@"square.stack.3d.up.fill" label:@"Apps simuladas" diameter:68 action:@selector(appsAction)];
    UIButton *close = [self bubble:@"face.smiling" label:@"Cerrar menú" diameter:86 action:@selector(hideMenu)];
    for (UIButton *b in @[home,window,apps,close]) {
        [cluster addSubview:b];
    }
    [NSLayoutConstraint activateConstraints:@[
        [home.centerXAnchor constraintEqualToAnchor:cluster.centerXAnchor],
        [home.topAnchor constraintEqualToAnchor:cluster.topAnchor constant:1],
        [window.centerXAnchor constraintEqualToAnchor:cluster.centerXAnchor constant:-98],
        [window.topAnchor constraintEqualToAnchor:cluster.topAnchor constant:97],
        [apps.centerXAnchor constraintEqualToAnchor:cluster.centerXAnchor constant:98],
        [apps.topAnchor constraintEqualToAnchor:cluster.topAnchor constant:97],
        [close.centerXAnchor constraintEqualToAnchor:cluster.centerXAnchor],
        [close.bottomAnchor constraintEqualToAnchor:cluster.bottomAnchor]
    ]];

    self.state.text = @"MENÚ ABIERTO · TOCA FUERA PARA CERRAR";
    self.orb.accessibilityLabel = @"Cerrar controles de BloomBox";
    background.alpha = 0;
    cluster.transform = CGAffineTransformMakeScale(.85,.85);
    [UIView animateWithDuration:.29 delay:0 usingSpringWithDamping:.8
          initialSpringVelocity:.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        background.alpha=1;
        cluster.transform=CGAffineTransformIdentity;
    } completion:nil];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self resetTimer];
}

- (void)resetTimer {
    NSUInteger token = ++self.generation;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (weakSelf && weakSelf.generation == token) [weakSelf hideMenu];
    });
}

- (void)hideMenu {
    ++self.generation;
    UIControl *background = self.overlay;
    if (!background) return;
    self.overlay = nil;
    self.cluster = nil;
    self.orb.accessibilityLabel = @"Abrir controles de BloomBox";
    self.state.text = @"PANTALLA LIBRE · MENÚ CERRADO";
    [UIView animateWithDuration:.18 animations:^{
        background.alpha=0;
    } completion:^(__unused BOOL done) {
        [background removeFromSuperview];
    }];
}
- (void)notify:(NSString *)text {
    self.state.text=text;
    self.state.textColor=[UIColor colorWithRed:.67 green:1 blue:.76 alpha:1];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
}
- (void)homeAction {
    [self hideMenu]; [self notify:@"INICIO · FUNCIONA"];
    [self mock:@"⌂" title:@"Escritorio BloomBox" detail:@"Acción simulada. El botón de BloomBox real regresaría al launcher."];
}
- (void)appsAction {
    [self hideMenu]; [self notify:@"APPS · FUNCIONA"];
    [self mock:@"▣" title:@"Apps abiertas" detail:@"Música · Explorador · Probe\n\nAcción simulada. Aquí iría el selector real."];
}
- (void)resizeAction {
    [self hideMenu]; self.compact=!self.compact;
    [self notify:self.compact?@"VENTANA · FUNCIONA":@"PANTALLA COMPLETA · FUNCIONA"];
    [UIView animateWithDuration:.28 animations:^{
        self.content.transform=self.compact?CGAffineTransformMakeScale(.8,.8):CGAffineTransformIdentity;
    }];
}
- (void)mock:(NSString *)icon title:(NSString *)title detail:(NSString *)desc {
    [self.fake removeFromSuperview];
    UIView *panel=[UIView new]; panel.translatesAutoresizingMaskIntoConstraints=NO;
    panel.backgroundColor=[UIColor colorWithRed:.10 green:.14 blue:.24 alpha:.98];
    panel.layer.cornerRadius=30; panel.layer.borderWidth=1;
    panel.layer.borderColor=[UIColor colorWithWhite:1 alpha:.2].CGColor;
    [self.view addSubview:panel]; self.fake=panel;
    UILabel *symbol=[self text:icon size:55];
    UILabel *heading=[self text:title size:23];
    UILabel *info=[self text:desc size:15];
    UIButton *back=[UIButton buttonWithType:UIButtonTypeSystem];
    [back setTitle:@"Regresar a la prueba" forState:UIControlStateNormal];
    back.translatesAutoresizingMaskIntoConstraints=NO;
    back.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    back.tintColor=UIColor.whiteColor; back.backgroundColor=[UIColor colorWithRed:.25 green:.37 blue:.58 alpha:1];
    back.layer.cornerRadius=16;
    [back addTarget:self action:@selector(closeFake) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *v in @[symbol,heading,info,back]) [panel addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.widthAnchor constraintEqualToConstant:MIN(320,self.view.bounds.size.width-42)],
        [panel.heightAnchor constraintEqualToConstant:335],
        [symbol.topAnchor constraintEqualToAnchor:panel.topAnchor constant:27],
        [symbol.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [heading.topAnchor constraintEqualToAnchor:symbol.bottomAnchor constant:12],
        [heading.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [info.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:17],
        [info.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [info.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],
        [back.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],
        [back.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22],
        [back.heightAnchor constraintEqualToConstant:46],
        [back.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20]
    ]];
    panel.alpha=0; panel.transform=CGAffineTransformMakeScale(.86,.86);
    [UIView animateWithDuration:.25 animations:^{ panel.alpha=1;panel.transform=CGAffineTransformIdentity;}];
}
- (void)closeFake {
    UIView *panel=self.fake;self.fake=nil;
    [UIView animateWithDuration:.2 animations:^{panel.alpha=0;} completion:^(__unused BOOL finished){[panel removeFromSuperview];}];
}
@end

@interface BBProbeScene : UIResponder <UIWindowSceneDelegate>
@property(strong,nonatomic) UIWindow *window;
@end
@implementation BBProbeScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController=[RadialProbe new];
    [self.window makeKeyAndVisible];
}
@end

@interface BBProbeDelegate : UIResponder <UIApplicationDelegate>
@property(strong,nonatomic) UIWindow *window;
@end
@implementation BBProbeDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)opts {
    // LiveContainer launchers vary in how they forward UIKit scenes.
    // Provide a legacy fallback window; UIWindowScene will replace it if connected.
    if (!self.window) {
        self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.rootViewController=[RadialProbe new];
        [self.window makeKeyAndVisible];
    }
    return YES;
}
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)opts {
    UISceneConfiguration *config=[[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:session.role];
    config.delegateClass=[BBProbeScene class];
    return config;
}
@end
int main(int argc,char **argv) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass([BBProbeDelegate class])); }
}
