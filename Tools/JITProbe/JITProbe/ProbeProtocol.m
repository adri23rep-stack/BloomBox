#import "ProbeProtocol.h"
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <stdint.h>
#import <string.h>
#import <unistd.h>

typedef int (*CSOpsFn)(pid_t, unsigned int, void *, size_t);
BOOL ProbeDebuggerAttached(void) {
    CSOpsFn cs=(CSOpsFn)dlsym(RTLD_DEFAULT,"csops");
    uint32_t flags=0;
    return cs && cs(getpid(),0,&flags,sizeof(flags))==0 && (flags & 0x10000000u)!=0;
}

// ABI used by StikDebug's universal.js: x16 = operation,
// x0/x1 = arguments; brk #0xf00d is handled by the debugger.
#if defined(__aarch64__)
__attribute__((noinline,optnone,naked))
static void JIT26Detach(void) {
    __asm__("mov x16, #0\n"
            "brk #0xf00d\n"
            "ret\n");
}
__attribute__((noinline,optnone,naked))
static void* JIT26PrepareRegion(void* address, size_t length) {
    __asm__("mov x16, #1\n"
            "brk #0xf00d\n"
            "ret\n");
}
#endif

NSString *ProbeRunUniversal(BOOL *success) {
    if(success) *success=NO;
#if !defined(__aarch64__)
    return @"Solo compatible con ARM64.";
#else
    if(!ProbeDebuggerAttached()) return @"No hay depurador conectado. No se lanzó BRK.";
    vm_size_t n=(vm_size_t)getpagesize();
    void* rx=JIT26PrepareRegion(NULL,(size_t)n);
    if(!rx) {
        JIT26Detach();
        return @"El script respondió sin entregar memoria RX.";
    }

    vm_address_t rw=0;
    vm_prot_t cur=VM_PROT_NONE, max=VM_PROT_NONE;
    kern_return_t err=vm_remap(mach_task_self(),&rw,n,0,VM_FLAGS_ANYWHERE,
                                 mach_task_self(),(vm_address_t)rx,FALSE,
                                 &cur,&max,VM_INHERIT_NONE);
    if(err!=KERN_SUCCESS) {
        JIT26Detach();
        vm_deallocate(mach_task_self(),(vm_address_t)rx,n);
        return [NSString stringWithFormat:@"RX preparado pero vm_remap falló (%d).",err];
    }

    err=vm_protect(mach_task_self(),rw,n,FALSE,VM_PROT_READ|VM_PROT_WRITE);
    if(err!=KERN_SUCCESS) {
        JIT26Detach();
        vm_deallocate(mach_task_self(),rw,n);
        vm_deallocate(mach_task_self(),(vm_address_t)rx,n);
        return [NSString stringWithFormat:@"RX recibido pero alias RW bloqueado (%d).",err];
    }

    // ARM64: mov w0,#42 ; ret. Write via RW alias, execute via RX alias.
    uint32_t program[]={0x52800540u, 0xd65f03c0u};
    memcpy((void *)rw,program,sizeof(program));
    sys_icache_invalidate(rx,sizeof(program));
    JIT26Detach(); // Calls the universal script's x16=0 breakpoint.
    int value=((int (*)(void))rx)();
    vm_deallocate(mach_task_self(),rw,n);
    vm_deallocate(mach_task_self(),(vm_address_t)rx,n);
    if(success) *success=(value==42);
    return value==42 ?
        @"CONFIRMADO: debugger, región RX, alias RW y ejecución ARM64 (42)." :
        [NSString stringWithFormat:@"Se ejecutó, pero devolvió %d y no 42.",value];
#endif
}
