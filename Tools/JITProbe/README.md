# JIT Probe 1.1 — iOS 26/27

Aplicación independiente para SideStore. **No modifica BloomBox ni su rama principal**.

### Diagnósticos
- Firma real del proceso: get-task-allow, increased-memory-limit (Get More RAM), allow-jit, extended-virtual-addressing.
- CS_DEBUGGED, MAP_JIT y memoria disponible.
- Prueba iOS 26/27 mediante **StikDebug + universal.js** (protocolo BRK #0xf00d).
- Una vez conectado, solicita región RX de 16 KiB, mapea alias RW con vm_remap, genera código ARM64, ejecuta y exige resultado 42 antes de declarar JIT confirmado.
- Registra la última etapa si iOS cierra la app, y permite copiar el diagnóstico.

### Requisitos
1. Instala el archivo .ipa **sin firmar** con SideStore, que aplica la firma del dispositivo.
2. Instala StikDebug. Necesitas pairing válido, Developer Mode, LocalDevVPN y DDI preparado cuando corresponda.
3. Abre JIT Probe y toca **Iniciar StikDebug y probar JIT**. En StikDebug, inicia la sesión `universal.js` y regresa a JIT Probe.
4. Si sale **JIT confirmado**, se ejecutaron instrucciones ARM64 en memoria preparada. En caso contrario, copia el diagnóstico y revisa el log de StikDebug.

**Limitaciones:** Si CS_DEBUGGED está habilitado pero el script universal no escucha el breakpoint, la app puede cerrarse. No consideramos debugger unido = JIT funcionando. El diagnóstico es solo para **este proceso**, no para otras apps. No obtiene permisos o JIT por sí misma. Si usas LiveContainer, la opción del bundle anfitrión debe estar activada; Built-in StikJIT no funciona allí. El estado TXM/SPTM es relevante en iOS 26/27.

Protocolo de referencia: https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md
