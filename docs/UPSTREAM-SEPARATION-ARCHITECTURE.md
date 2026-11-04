# Arquitectura para actualizar LiveContainer y SideStore sin reescribir BloomBox

**Rama:** `refactor/bloombox-independent-core`, [PR #34](https://github.com/adri23rep-stack/BloomBox/pull/34).  
**Estado:** contratos y controles iniciales implementados; la extracción física de los módulos **todavía no se ha hecho**.

## Objetivo

Mantener BloomBox como **producto independiente en su interfaz y lógica propia**, mientras que LiveContainer se actualiza como motor de apps invitadas y SideStore como servicio de firma/instalación. Cada actualización futura debe limitar, en condiciones normales, los cambios a un adaptador, su versión fijada y sus pruebas, sin copiar manualmente todo el código upstream dentro del launcher.

**No garantiza cero cambios:** una actualización upstream que rompa un contrato, iOS, el formato de datos o la firma todavía puede necesitar un adaptador nuevo.

## Situación real (3 nov 2026)

| Dueño funcional | Código o recurso existente | Acoplamiento actual |
|---|---|---|
| BloomBox | `LiveContainerSwiftUI/Views/BloomBox/*.swift`, `BloomBoxThemeStore.swift`, políticas RAM+/JIT y UI | Está compilado dentro del framework de interfaz de LiveContainer. Varias vistas llaman directamente `LCAppModel`, `LCUtils` o helpers del runtime |
| LiveContainer | `LiveContainer/`, `LiveContainerShared/`, `LiveProcess/`, `LiveContainerSwiftUI/Models/`, `LiveContainerSwiftUI/Utilities/`, `TweakLoader/` | Provee carga y ejecución de invitados, contenedores y hooks; **no se puede reemplazar solo por cambiar un IPA** |
| SideStore integrado | `SideStoreSupport/`, `.github/sidelc/`, IPA de `LiveContainer/SideStore` incorporado con `dylibify` | Firma/renueva con extensiones y esquemas de URL; comparte identidad y proceso con el host actual |
| Dependencias externas | StikJIT, Husk pairing, LiveExec32, OpenSSL y otras | Sus licencias y compatibilidad se gestionan por separado; no son código original de Strata solo por aparecer en su fork |

Una copia de `docs/LiveContainer-Upstream.md` es documentación upstream, no una frontera arquitectónica. `THIRD_PARTY_NOTICES.md` y Git history **no** se eliminan.

## Diseño objetivo

```text
BloomBox UI / GameBox / Home / Themes / Widgets
                 |
        BloomBox Core (modelos propios, datos persistidos)
                 |
      BloomBoxIntegrationContracts (sin tipos LC/SideStore)
           /                         \
LiveContainerAdapter           SideStoreAdapter
           |                         |
LiveContainer runtime          SideStore (embedded, luego opcional externo)
   - invitadas y contenedores   - firma y renovación
   - JIT preflight              - aprobación/estado, sin exportar credenciales
```

**Los contratos ya están en** `LiveContainerSwiftUI/Views/BloomBox/BloomBoxIntegrationContracts.swift`:
- `BloomBoxGuestDescriptor`, `BloomBoxLaunchRequest`, `BloomBoxGuestHost`: la UI usa claves propias; solo el adaptador convierte a `LCAppModel` e invoca `runApp`.
- `BloomBoxRefreshRequest`, `BloomBoxRefreshState`, `BloomBoxSigningService`: la UI pide renovar y observa el resultado; SideStore gestiona sesión, firma y credenciales.
- `BloomBoxIntegrationProtocol.majorVersion = 1`: punto de control para compatibilidad y futura negociación de capacidades.

**Adaptadores en uso por el Home:** `Views/BloomBoxAdapters/LiveContainerHomeAdapter.swift` centraliza identidad, estado, iconos del signer, bloqueo de red, visibilidad de invitados y **la importación de tweaks con manejo de Mach-O**. `LiveContainerPreferencesAdapter.swift` conserva los datos de app group, sustituyendo **32 accesos directos** en el Home. `LiveContainerHomeActions.swift` convierte las solicitudes portables `BloomBoxHomeGuestCommand` (`open/JIT/manage/uninstall`) a los callbacks de LiveContainer **sin mover ni sustituir los avisos de compatibilidad o confirmaciones de desinstalación**. El mapa distingue incluso selecciones con claves duplicadas.

**El lanzamiento real y la firma todavía dependen del host** y aún no están migrados al contrato asíncrono `BloomBoxGuestHost` / `BloomBoxSigningService`; sí están concentradas las acciones del Home en la capa adaptadora. La compilación actual sigue integrando el runtime, la interfaz y SideStore en un mismo producto.

El motivo de mantener ese puente temporal es no arriesgar JIT, RAM+, firmas o datos guardados mientras se instala y prueba cada tramo en iOS 27.

### Separación física futura (siguiente fase, no etapa 0)

1. Extraer `BloomBoxCore` (Home layout, widgets, GameBox metadata, temas, JIT/RAM+ políticas puras) como módulo Swift independiente sin importar modelos LC.
2. Hacer que la UI y los módulos BloomBox dependan **solo** de contratos propios. Inyectar un `LiveContainerAdapter` desde el punto de arranque del host. Conservar Swift aliases temporales para compatibilidad.
3. Mantener un árbol upstream **identificable y actualizable** de LiveContainer (preferiblemente un fork sincronizable o un `git subtree` fijado por commit). Colocar las personalizaciones BloomBox fuera de ese árbol, en adaptadores/overlay y en módulos propios.
4. Convertir `SideStoreSupport` y las adaptaciones para el paquete SideStore en un adaptador aislado. Mientras el producto distribuya SideStore integrado, fijar el IPA y su SHA-256.
5. Soportar en una fase posterior **dos modos**: SideStore integrado (compatibilidad con instalaciones actuales) y SideStore como app externa oficial, si el protocolo disponible, los App Groups y el firmado lo permiten. No prometer que iOS autoriza comunicación arbitraria entre apps.
6. Mover el código de presentación al target propio de BloomBox; mantener LiveContainer como motor. Cambiar gradualmente el proyecto Xcode y ejecutar un test de instalación por cada paso.

### Límites que protegen los datos

No renombrar sin migración probada:
- `LiveBoardHomeLayout`, `BloomBoxPlacedWidgetsV2`, `ManzanaMotionWallpaper`, `LiveBoardFavorites`, `LiveBoardCategories` y los ID persistidos.
- Bundle ID del host, ID de guest, App Groups, keychain groups, contenedores, IDs de extensiones y perfiles de firma.
- Contratos de pairing/JIT, entitlements RAM+, y sesiones SideStore. **Nunca subir credenciales, llaves o archivos de pairing a CI.**

Un motor actualizado debe poder **leer los datos guardados por la versión anterior**. Las migraciones de formato deben tener prueba ida/vuelta y respaldo antes de cambiar el formato.

## Actualización independiente por componente

### LiveContainer

1. Crear rama `deps/livecontainer-<fecha>` **desde la rama de integración actual**, sin tocar main.
2. Elegir commit/tag upstream, registrar su SHA y revisar cambios que afecten runtime, `LCAppModel`, `runApp`, `LiveProcess`, entitlements y vistas.
3. Actualizar el árbol upstream fijado y, de ser necesario, **solo el adaptador**; evitar tocar `BloomBoxCore` y Home/GameBox salvo cambio de contrato.
4. Ejecutar pruebas de datos guardados, lanzamiento, varias ventanas, JIT, RAM+, RAM+ reinstalación, apps ocultas y contenedores.
5. Compilar IPA y probar en dispositivo; revisar PR y fusionar **a la rama de integración** al aprobar.

### SideStore

1. Crear rama `deps/sidestore-<fecha>` desde la rama de integración.
2. Elegir release/commit de la integración correcta (hoy usa el fork `LiveContainer/SideStore`, **no** el IPA genérico de `SideStore/SideStore`). Registrar URL, versión, fecha, SHA-256 y cambios de identidad/extensiones.
3. Cambiar exclusivamente la entrada `tmp/SideStore.ipa` en `Scripts/bundled-dependencies.json`; ejecutar `Scripts/fetch-bundled-dependencies.py`.
4. La build **rechaza** un IPA distinto si el hash ya no coincide. `.github/build_github.sh` utiliza únicamente el IPA previamente verificado. La herramienta `dylibify` también tiene hash fijado.
5. Revalidar inicio de sesión, renovación, instalación sobre una versión existente, intents/widgets, App Groups, certificados, extensiones, Live Activity y RAM+ firmado.
6. Aprobar el PR antes de tocar la rama de integración. Para cambiar a SideStore externo, hacer una migración separada y reversible.

**Pines iniciales documentados en GitHub:**
- `LiveContainer/SideStore` nightly `SideStore.ipa` — SHA-256 `f9d2d9af51285dcbdece08c51aadc02e8a2d756da6ca8dfca16724c801ae2fcd` (GitHub release asset consultado, actualizado 17 oct 2026).
- `LiveContainer/dylibify` 1.0 — SHA-256 `6d23f6a2fc4d8442f87caa1161aebe6ecaafd0e8c41ce205da007efb04fc82c7`.
- StikJIT idevice y LiveExec32 mantienen sus hashes existentes.

La fecha de una nightly **no equivale a versión estable**; el SHA identifica el archivo. Todavía existen otras herramientas de compilación no fijadas, por ejemplo `brew install ldid`: se inventarían y gestionarán antes de reclamar builds totalmente reproducibles.

## Reglas automáticas añadidas

- `Scripts/upstream-boundaries.json` registra la deuda actual: **40 archivos Swift heredados** bajo BloomBox que ya existían al iniciar esta protección.
- `Tests/upstream-boundaries-tests/test_boundaries.py` impide que **un archivo de UI nuevo** llame directamente tipos/herramientas internas de LiveContainer/SideStore; debe utilizar modelos del contrato y un adaptador.
- El mismo control exige un SHA-256 explícito para cada binario listado, prohíbe descargas directas de SideStore/dylibify en el empaquetador, y verifica la presencia de contratos y restore verificado.
- `Tests/integration-contracts/main.swift` comprueba que los mensajes de la frontera puedan codificarse/decodificarse sin LiveContainer ni SideStore.
- Estos controles corren en `.github/workflows/build.yml`, antes del archive. `Tests/home-adapter-tests/test_adapter.py` añade una comprobación de que los accesos de host retirados no vuelvan al archivo principal del Home.

**Límite del guard:** los 40 archivos heredados siguen pudiendo usar el runtime; esta lista no limpia su código. El objetivo es reducir gradualmente el listado hasta cero durante las fases 1–4 y mover llamadas host/signer a los adaptadores. Los archivos existentes no se declaran independientes solo por estar en el listado.

## Qué falta para conseguir separación real

- Conectar los comandos ya implementados del Home en `LiveContainerHomeActions` al futuro contrato asíncrono `BloomBoxGuestHost` sin alterar advertencias JIT/tweaks; crear el adaptador de firmado `SideStoreAdapter` y sus pruebas. El Home ya encapsula consultas, firma/ejecución observable, acciones y filesystem de tweaks, pero sigue compilando en el target del host.
- Migrar progresivamente todas las vistas BloomBox al contrato, reducir a cero las excepciones y separar el Xcode target.
- Sincronizar por commit el código upstream de LiveContainer en una carpeta/fork mantenible (hoy hay una copia con modificaciones históricas).
- Aislar el build del SideStore integrado, y después estudiar una app SideStore externa (si el sistema y la integración lo admiten).
- Comparar y probar upstream por separado en CI y iPhone. `main` y releases quedan intactos.

## Procedencia y créditos

La separación técnica no demuestra ausencia de código derivado. Los hallazgos de `docs/STRATA-PROVENANCE-AUDIT.md` todavía requieren resolver recursos históricos, módulos modificados y licencias. Aunque se retire toda dependencia **ejecutable**, no borrar avisos de copyright de material aún distribuido, ni el historial Git. Los créditos visibles solo se revisan tras la auditoría final.
