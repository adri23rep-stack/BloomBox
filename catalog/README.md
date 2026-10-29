# BloomBox — Tienda remota (prototipo de catálogo)

> Estado: catálogo en rama independiente. La nueva versión experimental de BloomBox lee `tweaks.json` en directo, descarga archivos `.dylib`, verifica el SHA-256 y genera alertas antes de abrir apps. **Sin pruebas de usuario en el iPhone todavía; no fusionar a main hasta verificarlas.**

## Arquitectura

Dos catálogos JSON mantenidos en la rama separada `store-catalog`, no en `main`:

- Apps: https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/apps.json
- Tweaks: https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/tweaks.json

Modificar este branch no cambia el ejecutable de BloomBox ni dispara su build de `main`. La interfaz de Tweak Store consulta `tweaks.json` por HTTPS, valida el esquema y cada entrada, conserva la última lista verificada y ofrece sincronización al abrirla o al pulsar Actualizar. Antes de iniciar una app desde el escritorio sincroniza si el catálogo está desactualizado. Si falla Internet, conserva la última lista válida; no ofrece datos desconocidos como si estuvieran verificados.

## Explorar tweaks de terceros (catálogo v2)

La versión experimental incorpora dos vistas en **Tweak Store**:

- **Mis apps:** solo los tweaks aplicables a apps y versiones instaladas.
- **Explorar:** todas las fichas del catálogo, incluidas las de juegos aún no instalados. Si no hay app compatible, solo se muestra información y un enlace al proyecto original, sin instalar nada.

Los clientes anteriores siguen leyendo [`catalog/tweaks.json`](./tweaks.json) (schema 1; SambaFix únicamente). El cliente nuevo utiliza [`catalog/tweaks-v2.json`](./tweaks-v2.json) con `schemaVersion: 2`, por lo que los nuevos campos no rompen versiones anteriores. Actualizar listados no vuelve a compilar ninguna de las dos versiones.

Las entradas nuevas de GitHub muestran **«Uso bajo tu propio riesgo · No verificado en BloomBox»**. `useAtOwnRisk: true` exige confirmación explícita antes de instalar un tweak de terceros cuando existe un instalador compatible. `listingOnly: true` muestra un proyecto solo para consulta y deshabilita la instalación automática cuando faltan formatos, recursos, requisitos especiales o un ejecutable verificado. La advertencia no debe ocultar incompatibilidades conocidas. Las fichas originales de SambaFix siguen como estaban, con prioridad nivel 3.

**Proyectos publicados para exploración** (29 de octubre de 2026): MarketplaceAdBlock (un único `.dylib` con instalador experimental y confirmación), Isaac External Item Descriptions (LiveContainer requiere framework ZIP), AIUpscaleTweak (hace falta elegir app compatible), InstaPlus (requiere Sideload Spoofer) y iOS-App-Dylib-Patches (repositorio fuente sin binario universal). No se ha verificado ninguno en el iPhone del usuario. No redistribuir binarios sin revisar licencias; se enlazan los releases originales.

## Tienda de apps

1. Mostrar fichas con desarrollador, versión, changelog, compatibilidad e hipervínculo a la publicación original. Nunca espejar IPAs ajenas.
2. Para GitHub Releases, resolver el último release **no prerelease** y seleccionar el archivo IPA aprobado por el editor. Para Forgejo Releases, consultar la API compatible cuando esté disponible y comprobar el repositorio/asset oficial. Si el API falla, mostrar **Abrir lanzamiento oficial**, no inventar una URL.
3. Antes de instalar, comprobar HTTPS, dominio oficial o redirecciones explícitamente permitidas, tamaño razonable, formato ZIP IPA, `Payload/*.app/Info.plist`, identificador esperado y hash SHA-256 (cuando haya un hash previamente aprobado).
4. Entregar el archivo descargado al `installIpaFile` que ya existe en `LCAppListView.swift`. Reutilizar la interfaz de progreso actual y su motor de firmado. Guardar los datos previos y ofrecer instalar/actualizar sin sobrescribirlos automáticamente.
5. Registrar la versión real leyendo `CFBundleShortVersionString` y `CFBundleVersion`. **No asumir** que apps con extensiones propias, permisos especiales o elevada RAM funcionarán dentro del contenedor.
6. Permitir agregar fuentes AltStore existentes aprovechando `LCAltStoreSourcesView.swift`, sin darles automáticamente el sello de verificadas.

MeloNX: fuente actual https://starforgejo.dev/projects/MeloNX/releases. La ficha puede mostrarse ya; el enlace binario directo debe resolverse dinámicamente y validarse antes de habilitar instalación rápida. MeloCafe: https://github.com/stossy11/MeloCafe/releases; se confirmó `MeloCafe.ipa` para release `1.0`. La publicación puede cambiar en adelante.

## App Store remota (cliente experimental)

La rama experimental de BloomBox contiene una pantalla propia **App Store** con icono en el escritorio y biblioteca. Su fuente independiente es [`catalog/apps.json`](./apps.json), para que podamos añadir fichas sin recompilar la IPA. Ofrece **Destacadas**, **Explorar**, búsqueda, autor, categoría, página oficial, releases y una vía a la pestaña de **Fuentes AltStore**. Muestra la fecha de última sincronización, conserva la última copia válida sin conexión y evita caché de GitHub en renovaciones.

Las fichas separan *descarga del archivo original* y *compatibilidad con el host*. Un asset puede existir y tener SHA-256 comprobado sin que esté probado dentro de BloomBox. Actualmente:
- **MeloCafe** tiene un asset `MeloCafe.ipa` en GitHub Releases v1.0, SHA-256 `e87c6faa44746fab019deba31a1d58757c449b7ddbd5bd0673e20a9f09be89e3`. Se ofrece **instalación experimental** dentro de BloomBox con consentimiento explícito, comprobación del hash por bloques y el instalador existente (incluido su diálogo de reemplazo). No garantiza JIT ni compatibilidad.
- **MeloNX** conserva su enlace oficial externo. No se ofrece botón de instalación sin una IPA de origen y hash verificables.
- **Delta**, **UTM SE** y **StikDebug** son fichas de consulta con enlaces originales. **StikDebug** requiere instalación como app real de iOS, no como invitada; no ofrecerla en el instalador de huéspedes.

La tienda no distribuye apps ajenas, no ejecuta código del JSON y **nunca instala nada automáticamente**. Para habilitar un botón de instalación local, la ficha requiere `installMode: "guest"`, `sourceVerified: true`, una URL HTTPS de GitHub Releases cuyo nombre termine en `.ipa`, y un SHA-256 de 64 caracteres. Antes de modificar datos el instalador comprueba que el archivo recibido coincida con el SHA-256. Los demás elementos mantienen enlaces de visita y advertencias de riesgo.

### Colección de ports GalaxyPad / PadMint (29 oct. 2026)

La pestaña **Ports** del cliente experimental filtra `category: "ports"`. Se añadieron **18 proyectos** oficiales de la comunidad [chrissotraidis](https://github.com/chrissotraidis): GalaxyPad, KartPad, BlueWake, SunPad, MeleePad, GoldenPad, HarkinianPad, MaskPad, PaperPad, BellPad, StarshipPad, SpaghettiPad, CTRPad, BallPad, BrawlerPad, BarrelPad, F0X y HaloPad.

Se verificaron repositorios y últimas etiquetas de GitHub. Son fichas de **consulta externa**: `installMode: "external"`, `directDownloadURL: null`, y `buildTool` apunta al [PadMint original](https://github.com/chrissotraidis/padmint), sin replicar contenido de juegos ni ofrecer una IPA precompilada. Los releases de KartPad, BlueWake, SunPad y MeleePad incluyen paquetes de iOS **incompletos** (sin código del juego), útiles únicamente para PadMint; nunca anunciarlos como apps jugables listas. El resto incluye recetas de compilación y suma de comprobación. Solo usar archivos de juegos obtenidos legalmente por el usuario. Los proyectos no se han verificado dentro de BloomBox.

El PadMint de escritorio ofrece compilación personal en Mac o, para los proyectos compatibles, GitHub Cloud Build desde otros sistemas. No instalarlo como app invitada en iPhone. Las URL enlazan al repositorio original y a la etiqueta de release exacta, no a discos, ROM, copias protegidas ni assets ajenos.

**No mezclar con la tienda de tweaks ni con la App Store de Apple:** se trata de una lista comunitaria de aplicaciones que pueden importarse al contenedor. No añade derechos de firma, JIT ni permisos que iOS no concede.

## Tweak Store: cómo publicar nuevos tweaks sin recompilar BloomBox

Modifica únicamente `catalog/tweaks.json` en la rama `store-catalog`. Los campos mínimos para una nueva entrada en `tweakEntries` son `id`, `name`, `version`, `developer`, `description`, `downloadURL` (GitHub Releases oficial, HTTPS, archivo .dylib), `sha256` (calculado del binario publicado), `fileType: "dylib"`, `fileName` (estable entre versiones), y `supportedApps` (con `bundleID` y versiones compatibles opcionales). Nunca almacenes el binario dentro de BloomBox ni incrustes enlaces inventados.

### Créditos y enlaces del autor

Cada entrada debe incluir `developer` con el nombre real del autor, equipo o proyecto que publicó el tweak. El campo opcional `officialSourceURL` apunta por **HTTPS** al repositorio de código original o al sitio oficial del desarrollador. La Tweak Store muestra **Desarrollado por** y un enlace visible (**Ver repositorio** o **Sitio oficial**), separados del enlace de descarga de la biblioteca. El enlace de créditos nunca se utiliza para descargar ni ejecutar código. No se debe atribuir un tweak al catálogo o a BloomBox si fue creado por terceros; conserva siempre la atribución y las licencias de origen.

El campo `alertLevel` gobierna los avisos de compatibilidad:

- `3` **máximo**: antes de abrir una app afectada, si no está instalada **y activa** la corrección, muestra un recuadro con `alertMessage`, y opciones **Instalar corrección**, **Abrir de todas formas** y **Cancelar**. No bloquea la apertura para siempre.
- `2` importante y `1` informativo: visibles en la tienda, sin aviso obligatorio al iniciar en esta versión.
- `0` o ausente: tweak opcional y silencioso.

**Samba de Amigo** está registrado con `bundleID: "com.sega.samba.app"`, `alertLevel: 3`, `SambaFix.dylib`. El UUID de sus contenedores de datos **no** aparece en el catálogo: el parche se asigna a su instalación de app y su carpeta de tweaks.


### Iconos de la App Store

Cada ficha puede añadir `appStoreID` (identificador numérico público de la App Store) y, si existe un enlace directo verificable, `appIconURL` (HTTPS en `*.mzstatic.com`). BloomBox consulta la API pública de búsqueda de iTunes para obtener `artworkUrl512` cuando solo conoce `appStoreID`, o por `bundleID` si no hay ID. Si el juego ya no está listado o falla la red, muestra el icono local del paquete instalado sin impedir el uso de la tienda. El identificador del juego es independiente de los UUID de sus contenedores de datos. Para Samba de Amigo (Apple Arcade, ficha archivada), se registró `appStoreID: 1641321225` en la única ficha oficial de SambaFix (nivel 3). Usa esta imagen únicamente como representación de la app y respeta las condiciones de uso de materiales de Apple.

### Alta de un nuevo tweak

1. Verifica el origen y permisos del desarrollador, y prueba el archivo en tu propio dispositivo.
2. Sube el `.dylib` a GitHub Releases en su repositorio oficial. Calcula su SHA-256 exacto.
3. Añade una ficha JSON en `tweakEntries` con `supportedApps`, `fileName` y `alertLevel` elegido, revisa el JSON y confirma en `store-catalog`.
4. Abre Tweak Store y pulsa **Actualizar**: el cliente experimental muestra nuevas fichas sin actualizar la IPA. Los avisos de nivel 3 también se consultan desde el catálogo al iniciar apps.
5. Si eliminas la entrada del JSON, dejará de anunciarse, pero no borra un tweak ya instalado del iPhone.

Por ahora acepta únicamente bibliotecas `arm64 .dylib` individuales desde `github.com/<owner>/<repo>/releases/download/<tag>/<file>.dylib`, con extensión, tamaño y digest validados. Los ZIP/frameworks/scripts no están permitidos en el instalador genérico. Las apps solo se comparan por su Bundle ID original o la carpeta de instalación; los UUID de datos son independientes. Un tweak se aplica al app seleccionado, no a otros juegos.

No permitas que el catálogo ejecute JavaScript, comandos, scripts u operaciones de shell. Los tweaks son código nativo con acceso a datos del invitado: autoriza la instalación manualmente y revisa las aportaciones de terceros antes de publicar su URL y SHA. No marques un tweak como verificado solo porque haya compilado.

## JIT y compatibilidad con iOS 26/27

La tienda **no habilita JIT automáticamente**. iOS 26/27 TXM/SPTM necesita un motor que implemente el protocolo universal de regiones ejecutables; añadir `universal.js` a una app incompatible no lo arregla.

Para huéspedes dentro de BloomBox usar una ficha de diagnóstico: método recomendado por el creador, script recomendado (si confirmado), `get-task-allow` del proceso correcto, PID del `LiveProcess`, archivo de pairing/DDI, estado TXM y resultado real de la prueba. El JIT integrado en una app invitada normalmente **no puede lanzar su propia extensión auxiliar** desde LiveContainer; la integración debe permanecer en BloomBox o usar StikDebug externo. No mostrar “compatible” hasta verificar en dispositivo.

MeloCafe indica `universal.js` en su release. MeloNX documenta StikDebug como requisito para iOS 26, pero el script exacto en BloomBox sigue sin verificar.

## Próximo trabajo en el cliente

- La mini Tweak Store aparece como un icono de app en el escritorio de la rama experimental, con soporte para fichas remotas.
- Catálogo HTTPS con validación, último caché correcto y actualización manual/periódica: implementado en rama experimental.
- Resolver releases oficiales y compartir descarga con el instalador.
- Instalación de `.dylib` ARM64 con SHA-256 y consentimiento: implementada en rama experimental. Falta prueba real y revisión de seguridad.
- Diagnóstico de JIT por proceso y matriz de compatibilidad probada.

La tienda de **apps/IPAs** continúa como diseño, no implementada; la **tienda de tweaks** ya tiene lector e instalador remoto en la rama experimental, no en main. La primera IPA que contenga el motor genérico requiere una compilación única; los cambios futuros del catálogo JSON no.
