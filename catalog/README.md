# BloomBox — Tienda remota (prototipo de catálogo)

> Estado: **solo catálogo remoto y diseño**, todavía no está conectado a la interfaz instalada de BloomBox. No publicar en main sin terminar el importador, las validaciones y las pruebas en iOS 27.

## Arquitectura

Dos catálogos JSON mantenidos en la rama separada `store-catalog`, no en `main`:

- Apps: https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/apps.json
- Tweaks: https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/tweaks.json

Modificar este branch no cambia el ejecutable de BloomBox ni dispara su build de `main`. La futura interfaz consultará estos JSON por HTTPS, conservará la última copia válida, mostrará la fecha de sincronización, hará actualización manual y revalidación periódica con ETag. Todo catálogo entrante debe validar esquema, tamaño máximo y URLs antes de sustituir el caché.

## Tienda de apps

1. Mostrar fichas con desarrollador, versión, changelog, compatibilidad e hipervínculo a la publicación original. Nunca espejar IPAs ajenas.
2. Para GitHub Releases, resolver el último release **no prerelease** y seleccionar el archivo IPA aprobado por el editor. Para Forgejo Releases, consultar la API compatible cuando esté disponible y comprobar el repositorio/asset oficial. Si el API falla, mostrar **Abrir lanzamiento oficial**, no inventar una URL.
3. Antes de instalar, comprobar HTTPS, dominio oficial o redirecciones explícitamente permitidas, tamaño razonable, formato ZIP IPA, `Payload/*.app/Info.plist`, identificador esperado y hash SHA-256 (cuando haya un hash previamente aprobado).
4. Entregar el archivo descargado al `installIpaFile` que ya existe en `LCAppListView.swift`. Reutilizar la interfaz de progreso actual y su motor de firmado. Guardar los datos previos y ofrecer instalar/actualizar sin sobrescribirlos automáticamente.
5. Registrar la versión real leyendo `CFBundleShortVersionString` y `CFBundleVersion`. **No asumir** que apps con extensiones propias, permisos especiales o elevada RAM funcionarán dentro del contenedor.
6. Permitir agregar fuentes AltStore existentes aprovechando `LCAltStoreSourcesView.swift`, sin darles automáticamente el sello de verificadas.

MeloNX: fuente actual https://starforgejo.dev/projects/MeloNX/releases. La ficha puede mostrarse ya; el enlace binario directo debe resolverse dinámicamente y validarse antes de habilitar instalación rápida. MeloCafe: https://github.com/stossy11/MeloCafe/releases; se confirmó `MeloCafe.ipa` para release `1.0`. La publicación puede cambiar en adelante.

## Tienda de tweaks

Catálogo independiente con entradas moderadas y revisadas. Aceptar `.dylib` y `.framework`, más archivos ZIP que contengan únicamente esos formatos. Validar versión exacta o rango del app destino, iOS, arquitectura, dependencias e incompatibilidades. El bundle ID **se verifica contra el IPA real**; no inferirlo del nombre visible.

Cada versión debe tener:
- Autor y URL originales, versión, formato y SHA-256 validado.
- `supportedApps` con `bundleID`, `minVersion`, `maxVersion`; restricciones de iOS.
- Estado probado/no probado y changelog.
- Instalación **solo en carpeta de tweaks de la app seleccionada**, sin usar Global Tweaks por defecto.
- Respaldo previo, firma del tweak, opción desactivar, revertir versión y recuperar si el invitado falla.

No cargar scripts remotos ni ejecutar órdenes enviadas por JSON. Los tweaks son código nativo que puede acceder a los datos del invitado; deben mostrarse con una advertencia clara y autorización explícita antes de instalar. La lista de tweaks arranca vacía hasta la revisión de las primeras versiones concretas.

## JIT y compatibilidad con iOS 26/27

La tienda **no habilita JIT automáticamente**. iOS 26/27 TXM/SPTM necesita un motor que implemente el protocolo universal de regiones ejecutables; añadir `universal.js` a una app incompatible no lo arregla.

Para huéspedes dentro de BloomBox usar una ficha de diagnóstico: método recomendado por el creador, script recomendado (si confirmado), `get-task-allow` del proceso correcto, PID del `LiveProcess`, archivo de pairing/DDI, estado TXM y resultado real de la prueba. El JIT integrado en una app invitada normalmente **no puede lanzar su propia extensión auxiliar** desde LiveContainer; la integración debe permanecer en BloomBox o usar StikDebug externo. No mostrar “compatible” hasta verificar en dispositivo.

MeloCafe indica `universal.js` en su release. MeloNX documenta StikDebug como requisito para iOS 26, pero el script exacto en BloomBox sigue sin verificar.

## Próximo trabajo en el cliente

- Añadir una pantalla `BloomBox Store` con pestañas **Apps** / **Tweaks** (o dos accesos directos), reutilizando el diseño Liquid Glass.
- Cliente de catálogo HTTPS con validación, caché, versión de esquema y consulta periódica.
- Resolver releases oficiales y compartir descarga con el instalador.
- Comprobaciones de seguridad, autorizaciones y filtros de tweaks antes de instalar.
- Diagnóstico de JIT por proceso y matriz de compatibilidad probada.

Este prototipo no instala todavía nuevas apps/tweaks: solo deja listo el origen remoto de sus listados para que la tienda de futuras builds pueda sincronizarse sin actualizar BloomBox.
