#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <libkern/OSByteOrder.h>
#import <sys/mman.h>
#import <dlfcn.h>
#import <unistd.h>
#import <errno.h>
#import "ProbeProtocol.h"

#ifndef MAP_JIT
#define MAP_JIT 0x800
#endif

typedef int (*CSFn)(pid_t, unsigned int, void*, size_t);
static uint32_t be32(const unsigned char* p) {
    uint32_t n=0; memcpy(&n,p,sizeof(n)); return OSSwapBigToHostInt32(n);
}
static NSDictionary *decodeXML(const unsigned char* p, size_t n) {
    if(n<8 || be32(p)!=0xfade7171u) return nil;
    uint32_t size=be32(p+4);
    if(size<8 || size>n) return nil;
    id v=[NSPropertyListSerialization propertyListWithData:[NSData dataWithBytes:p+8 length:size-8] options:0 format:NULL error:NULL];
    return [v isKindOfClass:[NSDictionary class]]?v:nil;
}
static NSDictionary *entitlements(void) {
    CSFn fn=(CSFn)dlsym(RTLD_DEFAULT,"csops");
    if(fn) {
        size_t n=131072; unsigned char *p=calloc(1,n);
        if(p) {
            NSDictionary *v=fn(getpid(),7,p,n)==0?decodeXML(p,n):nil;
            free(p);
            if(v) return v;
        }
    }
    // Fall back to the XML entitlement blob embedded in the signed executable.
    NSData *data=[NSData dataWithContentsOfFile:NSBundle.mainBundle.executablePath options:NSDataReadingMappedIfSafe error:NULL];
    if(data.length<sizeof(struct mach_header_64)) return nil;
    const unsigned char* b=data.bytes; const struct mach_header_64* h=(const void*)b;
    if(h->magic!=MH_MAGIC_64) return nil;
    size_t off=sizeof(struct mach_header_64);
    for(uint32_t i=0;i<h->ncmds;i++) {
        if(off>data.length || data.length-off<sizeof(struct load_command)) return nil;
        const struct load_command* cmd=(const void*)(b+off);
        if(cmd->cmdsize<sizeof(*cmd) || cmd->cmdsize>data.length-off) return nil;
        if(cmd->cmd==LC_CODE_SIGNATURE && cmd->cmdsize>=sizeof(struct linkedit_data_command)) {
            const struct linkedit_data_command* link=(const void*)cmd;
            if(link->dataoff>data.length || link->datasize>data.length-link->dataoff || link->datasize<12) return nil;
            const unsigned char* s=b+link->dataoff; size_t n=link->datasize;
            if(be32(s)!=0xfade0cc0u || be32(s+4)>n || be32(s+4)<12) return nil;
            uint32_t count=be32(s+8); n=be32(s+4);
            if(count>(n-12)/8) return nil;
            for(uint32_t j=0;j<count;j++) {
                uint32_t kind=be32(s+12+8*j), pos=be32(s+16+8*j);
                if(kind==5 && pos<n) {
                    NSDictionary *v=decodeXML(s+pos,n-pos);
                    if(v) return v;
                }
            }
            return nil;
        }
        off+=cmd->cmdsize;
    }
    return nil;
}
static NSNumber *signFlags(void) {
    CSFn fn=(CSFn)dlsym(RTLD_DEFAULT,"csops");
    uint32_t flags=0;
    return fn && fn(getpid(),0,&flags,sizeof(flags))==0?@(flags):nil;
}
static NSString *gb(uint64_t b) { return b?[NSString stringWithFormat:@"%.2f GB",(double)b/1073741824.0]:@"No disponible"; }

@interface ProbeController : UIViewController
@property(nonatomic,strong) UIStackView *stack;
@property(nonatomic,copy) NSString *result;
@property(nonatomic,copy) NSString *report;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSDate *started;
@property(nonatomic,assign) NSInteger phase;
@end

@implementation ProbeController
- (UILabel*)label:(NSString*)value font:(CGFloat)size color:(UIColor*)color {
    UILabel *v=[UILabel new];v.text=value;v.textColor=color;v.numberOfLines=0;
    v.font=[UIFont systemFontOfSize:size weight:size>15?UIFontWeightSemibold:UIFontWeightRegular];
    return v;
}
- (void)tile:(NSString*)title value:(NSString*)value detail:(NSString*)detail status:(NSInteger)state {
    UIView *bg=[UIView new];bg.backgroundColor=[UIColor colorWithRed:.11 green:.14 blue:.20 alpha:1];
    bg.layer.cornerRadius=16;
    UIStackView *v=[UIStackView new];v.axis=UILayoutConstraintAxisVertical;v.spacing=7;v.translatesAutoresizingMaskIntoConstraints=NO;
    [bg addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:bg.topAnchor constant:15],
        [v.leadingAnchor constraintEqualToAnchor:bg.leadingAnchor constant:16],
        [v.trailingAnchor constraintEqualToAnchor:bg.trailingAnchor constant:-16],
        [v.bottomAnchor constraintEqualToAnchor:bg.bottomAnchor constant:-15]
    ]];
    [v addArrangedSubview:[self label:title font:16 color:UIColor.whiteColor]];
    UIColor *c=state>0?[UIColor colorWithRed:.43 green:.95 blue:.70 alpha:1] :
        state<0?[UIColor colorWithRed:1 green:.50 blue:.47 alpha:1] :
        [UIColor colorWithRed:1 green:.78 blue:.40 alpha:1];
    [v addArrangedSubview:[self label:value font:18 color:c]];
    [v addArrangedSubview:[self label:detail font:13 color:[UIColor colorWithWhite:.78 alpha:1]]];
    [self.stack addArrangedSubview:bg];
}
- (void)button:(NSString*)name action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    b.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [b setTitle:name forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor=[UIColor colorWithRed:.26 green:.36 blue:.68 alpha:1];b.layer.cornerRadius=13;
    [b.heightAnchor constraintEqualToConstant:49].active=YES;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:b];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor colorWithRed:.055 green:.075 blue:.12 alpha:1];
    UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    self.stack=[UIStackView new];self.stack.axis=UILayoutConstraintAxisVertical;self.stack.spacing=12;
    self.stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [self.stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-25],
        [self.stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
        [self.stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [self.stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    NSString *stage=[NSUserDefaults.standardUserDefaults stringForKey:@"pendingJITStage"];
    self.phase=stage.length?-1:0;
    self.result=stage.length?[NSString stringWithFormat:@"La prueba anterior se interrumpió en: %@. Revisa StikDebug.",stage]:@"Aún no se ha probado el protocolo universal.";
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"pendingJITStage"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tick) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self rebuild];
}
- (void)dealloc { [self.timer invalidate];[[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)rebuild {
    for(UIView *v in self.stack.arrangedSubviews){[self.stack removeArrangedSubview:v];[v removeFromSuperview];}
    NSDictionary *e=entitlements();NSNumber *f=signFlags();uint32_t flags=f.unsignedIntValue;
    BOOL debug=f && (flags&0x10000000u);
    BOOL task=[e[@"get-task-allow"] boolValue] || (f && (flags&4));
    BOOL more=[e[@"com.apple.developer.kernel.increased-memory-limit"] boolValue];
    BOOL ext=[e[@"com.apple.developer.kernel.extended-virtual-addressing"] boolValue];
    BOOL allow=[e[@"com.apple.security.cs.allow-jit"] boolValue];

    errno=0;
    size_t size=(size_t)getpagesize();
    void* m=mmap(NULL,size,PROT_READ|PROT_WRITE|PROT_EXEC,MAP_PRIVATE|MAP_ANON|MAP_JIT,-1,0);
    BOOL mapped=m!=MAP_FAILED;int er=mapped?0:errno;
    if(mapped) munmap(m,size);

    [self.stack addArrangedSubview:[self label:@"JIT PROBE 1.1" font:30 color:UIColor.whiteColor]];
    [self.stack addArrangedSubview:[self label:@"Prueba iOS 26 / 27 · StikDebug universal.js" font:14 color:[UIColor colorWithWhite:.75 alpha:1]]];
    [self tile:@"JIT real" value:self.phase==3?@"CONFIRMADO":@"No confirmado" detail:self.phase==3?@"Ejecutó código ARM64 y devolvió 42.":@"Tener CS_DEBUGGED o MAP_JIT no basta en iOS 26/27." status:self.phase==3?1:0];
    NSString *phase=self.phase==3?@"Prueba superada":self.phase==2?@"Comprobando":self.phase==1?@"Esperando depurador":self.phase<0?@"Falló o se interrumpió":@"Pendiente";
    [self tile:@"Protocolo universal" value:phase detail:self.result?:@"" status:self.phase==3?1:self.phase<0?-1:0];
    [self tile:@"Firma: get-task-allow" value:e||f?(task?@"Presente":@"No habilitado"):@"No verificable" detail:@"Se necesita para que StikDebug pueda adjuntarse." status:e||f?(task?1:-1):0];
    [self tile:@"Get More RAM" value:e?(more?@"Presente":@"Ausente"):@"No verificable" detail:@"com.apple.developer.kernel.increased-memory-limit" status:e?(more?1:-1):0];
    [self tile:@"CS_DEBUGGED / MAP_JIT" value:[NSString stringWithFormat:@"%@ / %@",debug?@"Sí":@"No",mapped?@"Sí":@"No"] detail:[NSString stringWithFormat:@"MAP_JIT errno %d. Esto no es la prueba de ejecución.",er] status:0];
    [self tile:@"Otros permisos" value:e?@"Firma legible":@"Firma no disponible" detail:[NSString stringWithFormat:@"allow-jit: %@ · dirección extendida: %@",allow?@"sí":@"no",ext?@"sí":@"no"] status:0];
    typedef size_t (*AvailableMem)(void);
    AvailableMem mem=(AvailableMem)dlsym(RTLD_DEFAULT,"os_proc_available_memory");
    uint64_t available=mem?mem():0;
    uint64_t physical=NSProcessInfo.processInfo.physicalMemory;
    [self tile:@"Memoria" value:[NSString stringWithFormat:@"Disponible: %@",gb(available)] detail:[NSString stringWithFormat:@"Física: %@",gb(physical)] status:0];

    [self button:@"Iniciar StikDebug y probar JIT" action:@selector(requestJIT)];
    [self button:@"Copiar diagnóstico" action:@selector(copyReport)];
    [self button:@"Actualizar" action:@selector(rebuild)];
    [self.stack addArrangedSubview:[self label:@"Necesita StikDebug, Modo Desarrollador, pairing válido y LocalDevVPN. Puede cerrarse si el script universal no atiende el breakpoint. Solo evalúa el proceso de esta app." font:12 color:[UIColor colorWithWhite:.65 alpha:1]]];

    self.report=[NSString stringWithFormat:@"JIT Probe 1.1\niOS %@\nBundle %@\nPID %d\nProtocolo: %@\nFase: %ld\nCS_DEBUGGED: %@\nMAP_JIT: %@ (errno %d)\nget-task-allow: %@\ngetmoreram: %@\nallow-jit: %@\nextended-virtual-addressing: %@\nRAM física: %@\nRAM disponible: %@\nFirma leída: %@",
        UIDevice.currentDevice.systemVersion,NSBundle.mainBundle.bundleIdentifier?:@"?",getpid(),self.result?:@"",(long)self.phase,
        debug?@"sí":@"no",mapped?@"sí":@"no",er,task?@"sí":@"no",more?@"sí":@"no",allow?@"sí":@"no",ext?@"sí":@"no",gb(physical),gb(available),e?@"sí":@"no"];
}
- (void)dialog:(NSString*)title message:(NSString*)message {
    UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)copyReport { UIPasteboard.generalPasteboard.string=self.report;[self dialog:@"Copiado" message:@"Pega los resultados en el chat."]; }
- (void)requestJIT {
    if(self.phase==1 || self.phase==2){[self dialog:@"En curso" message:@"Ya se está esperando al depurador."];return;}
    if(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion<26) {
        [self dialog:@"Requiere iOS 26/27" message:@"Esta prueba está diseñada para el protocolo universal de iOS 26/27."];return;
    }
    NSDictionary *e=entitlements(); NSNumber *f=signFlags();
    BOOL task=[e[@"get-task-allow"] boolValue] || (f && (f.unsignedIntValue&4u));
    if((e||f) && !task) {
        [self dialog:@"Sin get-task-allow" message:@"La firma no permite la conexión del debugger. Revisa SideStore."];return;
    }
    if(getenv("LC_HOME_PATH")) {
        [self dialog:@"LiveContainer" message:@"Activa «Use LiveContainer's Bundle ID» en LiveContainer y prueba JIT en el anfitrión."];return;
    }
    if(![UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"stikdebug://enable-jit"]]) {
        [self dialog:@"Falta StikDebug" message:@"Instala StikDebug y prepara tu pairing y VPN."];return;
    }
    NSURLComponents *u=[NSURLComponents new];
    u.scheme=@"stikdebug";u.host=@"enable-jit";
    u.queryItems=@[
      [NSURLQueryItem queryItemWithName:@"bundle-id" value:NSBundle.mainBundle.bundleIdentifier?:@"org.nikaido.jitprobe"],
      [NSURLQueryItem queryItemWithName:@"pid" value:[NSString stringWithFormat:@"%d",getpid()]],
      [NSURLQueryItem queryItemWithName:@"script-name" value:@"universal.js"]
    ];
    self.phase=1;self.started=[NSDate date];self.result=@"StikDebug solicitado. Regresa a JIT Probe una vez preparado.";
    [NSUserDefaults.standardUserDefaults setObject:@"esperando StikDebug" forKey:@"pendingJITStage"];
    [self.timer invalidate];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self rebuild];
    [UIApplication.sharedApplication openURL:u.URL options:@{} completionHandler:^(BOOL opened) {
        if(!opened) {
            self.phase=-1; self.result=@"iOS no abrió StikDebug.";
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"pendingJITStage"];
            [self.timer invalidate]; [self rebuild];
        }
    }];
}
- (void)tick {
    if(self.phase!=1) return;
    if([NSDate.date timeIntervalSinceDate:self.started]>120) {
        self.phase=-1;self.result=@"Se agotó el tiempo. Revisa pairing, VPN, DDI y StikDebug.";
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"pendingJITStage"];
        [self.timer invalidate];[self rebuild];return;
    }
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    if(!ProbeDebuggerAttached()) return;
    self.phase=2;self.result=@"Depurador conectado. Enviando protocolo universal.";
    [NSUserDefaults.standardUserDefaults setObject:@"breakpoint universal / región RX y ejecución" forKey:@"pendingJITStage"];
    [self.timer invalidate];[self rebuild];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        BOOL passed=NO;NSString *result=ProbeRunUniversal(&passed);
        dispatch_async(dispatch_get_main_queue(),^{
            self.phase=passed?3:-1;self.result=result;
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"pendingJITStage"];
            [self rebuild];
            [self dialog:passed?@"JIT confirmado":@"Sin confirmar" message:result];
        });
    });
}
@end
@interface AppDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow* window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[ProbeController new];[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char** argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class)); } }
