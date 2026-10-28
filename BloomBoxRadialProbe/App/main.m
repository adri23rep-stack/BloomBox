
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface RadialProbe : UIViewController <UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIControl *overlay;
@property(nonatomic,strong) UIView *cluster;
@property(nonatomic,strong) UILabel *state;
@property(nonatomic,strong) UIView *content;
@property(nonatomic,strong) UIView *fake;
@property(nonatomic,strong) UIScreenEdgePanGestureRecognizer *edge;
@property(nonatomic,strong) UIPanGestureRecognizer *zonePan;
@property(nonatomic,strong) UILabel *zoneLabel;
@property(nonatomic) BOOL compact;
@property(nonatomic) NSUInteger generation;
@end
@implementation RadialProbe

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (BOOL)prefersHomeIndicatorAutoHidden { return !self.overlay; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return self.overlay ? UIRectEdgeNone : UIRectEdgeBottom;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
- (UILabel *)text:(NSString *)value size:(CGFloat)size {
    UILabel *l = [UILabel new]; l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = value; l.textColor = UIColor.whiteColor;
    l.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter; return l;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:.025 green:.04 blue:.09 alpha:1];
    CAGradientLayer *gradient=[CAGradientLayer layer];
    gradient.colors=@[(id)[UIColor colorWithRed:.09 green:.17 blue:.29 alpha:1].CGColor,
                      (id)[UIColor colorWithRed:.02 green:.025 blue:.07 alpha:1].CGColor];
    gradient.frame=UIScreen.mainScreen.bounds;
    [self.view.layer insertSublayer:gradient atIndex:0];
    self.content=[UIView new]; self.content.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:self.content];
    [NSLayoutConstraint activateConstraints:@[
        [self.content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.content.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    UILabel *title=[self text:@"BloomBox · Radial Probe" size:29];
    UILabel *info=[self text:@"Prueba 1.1: abre el menú con el botón\no desliza desde la franja inferior.\nLuego probamos el gesto del sistema." size:16];
    self.state=[self text:@"PRUEBA 1.1 · EL MENÚ DEBE ABRIR" size:12];
    self.state.textColor=[UIColor colorWithRed:.63 green:.95 blue:1 alpha:1];
    UIView *demo=[UIView new]; demo.translatesAutoresizingMaskIntoConstraints=NO;
    demo.backgroundColor=[UIColor colorWithRed:.12 green:.17 blue:.28 alpha:1];
    demo.layer.cornerRadius=26; demo.layer.borderWidth=.8;
    demo.layer.borderColor=[UIColor colorWithWhite:1 alpha:.17].CGColor;
    UILabel *card=[self text:@"♪\n\nApp de prueba\n\nPrueba el menú, toca fuera\no espera 5 segundos." size:20];

    UIButton *openButton=[UIButton buttonWithType:UIButtonTypeSystem];
    openButton.translatesAutoresizingMaskIntoConstraints=NO;
    [openButton setTitle:@"ABRIR MENÚ CIRCULAR" forState:UIControlStateNormal];
    openButton.titleLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    openButton.tintColor=UIColor.whiteColor;
    openButton.backgroundColor=[UIColor colorWithRed:.25 green:.38 blue:.69 alpha:1];
    openButton.layer.cornerRadius=22;
    openButton.accessibilityLabel=@"Abrir menú circular de prueba";
    [openButton addTarget:self action:@selector(manualMenu) forControlEvents:UIControlEventTouchUpInside];
    UIView *gestureZone=[UIView new];
    gestureZone.translatesAutoresizingMaskIntoConstraints=NO;
    gestureZone.backgroundColor=[UIColor colorWithRed:.2 green:.26 blue:.39 alpha:.75];
    gestureZone.layer.cornerRadius=17;
    gestureZone.layer.borderWidth=.8;
    gestureZone.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3].CGColor;
    self.zoneLabel=[self text:@"↑  DESLIZA DESDE AQUÍ O TOCA" size:13];
    [gestureZone addSubview:self.zoneLabel];
    self.zonePan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(internalPan:)];
    self.zonePan.cancelsTouchesInView=NO;
    self.zonePan.delegate=self;
    [gestureZone addGestureRecognizer:self.zonePan];
    UITapGestureRecognizer *zoneTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(manualMenu)];
    zoneTap.cancelsTouchesInView=NO;
    [gestureZone addGestureRecognizer:zoneTap];
    [self.content addSubview:gestureZone];
    [self.content addSubview:openButton];
    [self.content addSubview:title]; [self.content addSubview:info];
    [self.content addSubview:demo]; [self.content addSubview:self.state];
    [demo addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:self.content.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:self.content.safeAreaLayoutGuide.topAnchor constant:55],
        [info.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:22],
        [info.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-22],
        [info.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:25],
        [demo.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:28],
        [demo.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-28],
        [demo.centerYAnchor constraintEqualToAnchor:self.content.centerYAnchor constant:40],
        [demo.heightAnchor constraintEqualToConstant:240],
        [card.centerYAnchor constraintEqualToAnchor:demo.centerYAnchor],
        [card.leadingAnchor constraintEqualToAnchor:demo.leadingAnchor constant:18],
        [card.trailingAnchor constraintEqualToAnchor:demo.trailingAnchor constant:-18],
        [openButton.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:32],
        [openButton.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-32],
        [openButton.heightAnchor constraintEqualToConstant:55],
        [openButton.bottomAnchor constraintEqualToAnchor:gestureZone.topAnchor constant:-17],
        [gestureZone.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:24],
        [gestureZone.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-24],
        [gestureZone.heightAnchor constraintEqualToConstant:50],
        [gestureZone.bottomAnchor constraintEqualToAnchor:self.content.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.zoneLabel.centerXAnchor constraintEqualToAnchor:gestureZone.centerXAnchor],
        [self.zoneLabel.centerYAnchor constraintEqualToAnchor:gestureZone.centerYAnchor],
        [self.state.bottomAnchor constraintEqualToAnchor:openButton.topAnchor constant:-16],
        [self.state.centerXAnchor constraintEqualToAnchor:self.content.centerXAnchor]
    ]];
    self.edge=[[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(edgeMoved:)];
    self.edge.edges=UIRectEdgeBottom;
    self.edge.cancelsTouchesInView=NO; self.edge.delegate=self;
    [self.view addGestureRecognizer:self.edge];
    UITapGestureRecognizer *fallback=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoTapped:)];
    fallback.numberOfTouchesRequired=2; fallback.numberOfTapsRequired=2;
    fallback.cancelsTouchesInView=NO; [self.view addGestureRecognizer:fallback];
    [self refreshSystem];
}
- (void)refreshSystem {
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
}
- (void)edgeMoved:(UIScreenEdgePanGestureRecognizer *)g {
    if (g.state==UIGestureRecognizerStateBegan) {
        [self notify:@"GESTO BORDE DETECTADO"];
        [self openMenu];
    }
}
- (void)twoTapped:(UITapGestureRecognizer *)g {
    if (g.state==UIGestureRecognizerStateRecognized) {
        [self notify:@"DOS DEDOS DETECTADOS"];
        [self openMenu];
    }
}

- (void)manualMenu {
    [self notify:@"TOQUE MANUAL DETECTADO"];
    [self openMenu];
}
- (void)internalPan:(UIPanGestureRecognizer *)pan {
    if (pan.state==UIGestureRecognizerStateChanged) {
        CGFloat delta=[pan translationInView:self.view].y;
        if (delta < -24 && !self.overlay) {
            [self notify:@"GESTO INTERIOR DETECTADO"];
            [self openMenu];
        }
    }
}
- (UIButton *)bubble:(NSString *)icon label:(NSString *)label diameter:(CGFloat)d action:(SEL)selector {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
    b.translatesAutoresizingMaskIntoConstraints=NO;
    b.accessibilityLabel=label; b.tintColor=UIColor.whiteColor;
    b.layer.cornerRadius=d/2; b.layer.borderWidth=.7;
    b.layer.borderColor=[UIColor colorWithWhite:1 alpha:.4].CGColor;
    b.layer.shadowColor=UIColor.blackColor.CGColor;
    b.layer.shadowOpacity=.25; b.layer.shadowRadius=12; b.layer.shadowOffset=CGSizeMake(0,5);
    UIVisualEffect *material=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    if (@available(iOS 26.0,*)) {
        UIGlassEffect *glass=[UIGlassEffect new]; glass.interactive=YES; material=glass;
    }
    UIVisualEffectView *blur=[[UIVisualEffectView alloc] initWithEffect:material];
    blur.frame=CGRectMake(0,0,d,d);
    blur.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    blur.layer.cornerRadius=d/2; blur.clipsToBounds=YES; blur.userInteractionEnabled=NO;
    [b insertSubview:blur atIndex:0];
    UIImageSymbolConfiguration *style=[UIImageSymbolConfiguration configurationWithPointSize:(d>85?31:25) weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:icon withConfiguration:style] forState:UIControlStateNormal];
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [b.widthAnchor constraintEqualToConstant:d],
        [b.heightAnchor constraintEqualToConstant:d]
    ]];
    return b;
}
- (void)openMenu {
    if (self.overlay) { [self resetTimer]; return; }
    UIControl *backdrop=[[UIControl alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor=UIColor.clearColor;
    [backdrop addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    self.overlay=backdrop; [self.view addSubview:backdrop];
    UIView *group=[UIView new]; group.translatesAutoresizingMaskIntoConstraints=NO;
    self.cluster=group; [backdrop addSubview:group];
    [NSLayoutConstraint activateConstraints:@[
        [group.widthAnchor constraintEqualToConstant:MIN(self.view.bounds.size.width-20,305)],
        [group.heightAnchor constraintEqualToConstant:275],
        [group.centerXAnchor constraintEqualToAnchor:backdrop.centerXAnchor],
        [group.bottomAnchor constraintEqualToAnchor:backdrop.safeAreaLayoutGuide.bottomAnchor constant:-23]
    ]];
    UIButton *home=[self bubble:@"house.fill" label:@"Inicio" diameter:72 action:@selector(homeAction)];
    UIButton *resize=[self bubble:@"arrow.up.left.and.arrow.down.right" label:@"Cambiar tamaño" diameter:72 action:@selector(resizeAction)];
    UIButton *apps=[self bubble:@"square.stack.3d.up.fill" label:@"Apps" diameter:72 action:@selector(appsAction)];
    UIButton *close=[self bubble:@"face.smiling" label:@"Ocultar menú" diameter:96 action:@selector(hideMenu)];
    for (UIView *b in @[home,resize,apps,close]) [group addSubview:b];
    [NSLayoutConstraint activateConstraints:@[
        [home.topAnchor constraintEqualToAnchor:group.topAnchor constant:2],
        [home.centerXAnchor constraintEqualToAnchor:group.centerXAnchor],
        [resize.centerXAnchor constraintEqualToAnchor:group.centerXAnchor constant:-98],
        [resize.topAnchor constraintEqualToAnchor:group.topAnchor constant:106],
        [apps.centerXAnchor constraintEqualToAnchor:group.centerXAnchor constant:98],
        [apps.topAnchor constraintEqualToAnchor:group.topAnchor constant:106],
        [close.centerXAnchor constraintEqualToAnchor:group.centerXAnchor],
        [close.bottomAnchor constraintEqualToAnchor:group.bottomAnchor constant:-1]
    ]];
    self.edge.enabled=NO; [self refreshSystem];
    backdrop.alpha=0; group.transform=CGAffineTransformMakeScale(.74,.74);
    [UIView animateWithDuration:.34 delay:0 usingSpringWithDamping:.73 initialSpringVelocity:.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        backdrop.alpha=1; group.transform=CGAffineTransformIdentity;
    } completion:nil];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self resetTimer];
}
- (void)resetTimer {
    NSUInteger token=++self.generation; __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if (weakSelf && weakSelf.generation==token) [weakSelf hideMenu];
    });
}
- (void)hideMenu {
    ++self.generation;
    UIControl *backdrop=self.overlay;
    if (!backdrop) return;
    self.overlay=nil; self.cluster=nil; self.edge.enabled=YES; [self refreshSystem];
    [UIView animateWithDuration:.18 animations:^{backdrop.alpha=0;backdrop.transform=CGAffineTransformMakeScale(.94,.94);} completion:^(__unused BOOL finished){[backdrop removeFromSuperview];}];
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
