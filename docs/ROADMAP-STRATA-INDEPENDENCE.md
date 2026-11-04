# Roadmap — separación del código de Strata en BloomBox

**Estado:** planificación; las tareas de este documento no se consideran implementadas.  
**Rama de integración:** `refactor/bloombox-independent-core` — [PR #34](https://github.com/adri23rep-stack/BloomBox/pull/34) (borrador).  
**Regla:** trabajar y probar fuera de `main`; no fusionar ni publicar release sin aprobación del propietario.

## Objetivo y límite

Sustituir los componentes que todavía contengan implementación de autoría de Strata por código desarrollado para BloomBox, manteniendo el mismo comportamiento o mejorándolo. Conservar la configuración y los datos de los usuarios, JIT/RAM+, SideStore, GameBox, widgets, temas y carpetas. Solo **después** de una auditoría de procedencia y licencias, decidir si corresponde retirar **referencias promocionales** a Strata de los créditos visibles. Nunca eliminar avisos obligatorios de copyright/licencia ni reescribir el historial Git para ocultar el origen.

**Importante:** renombrar clases, mover archivos o cambiar comentarios no equivale a reemplazar su implementación. La similitud también puede proceder de LiveContainer u otro proyecto original, y debe clasificarse antes de atribuirla a Strata.

## Línea base (auditoría inicial, 3 de noviembre de 2026)

Se encontraron secuencias **exactamente iguales** al comparar archivos de Strata con los de la rama de refactorización. Son señales para investigar, no todavía una sentencia de autoría.

| Prioridad | Componente BloomBox | Referencia Strata | Mayor bloque consecutivo idéntico observado* |
|---|---|---|---|
| P0 | `Views/BloomBox/BloomBoxHomeScreen.swift` | `Views/LiveBoardHomeScreen.swift` | 32 líneas |
| P0 | `Views/BloomBox/BloomBoxGameBoxScreen.swift` | `Views/LiveBoardConsoleScreen.swift` | 51 líneas |
| P1 | `Views/BloomBox/BloomBoxControllerInput.swift` | `Views/LiveBoardControllerInput.swift` | 33 líneas |
| P1 | `Views/BloomBox/BloomBoxAppCustomization.swift` | `Views/LiveBoardAppCustomization.swift` | 26 líneas |

*Comparación textual con espacios normalizados, sobre archivos de Strata en `main` y BloomBox en la rama indicada en la fecha de la auditoría. Medición aproximada para priorizar; no equivale a un análisis de licencias ni a una medición de porcentaje de código ajeno.

## Etapas

### 0. Inventario, procedencia y fronteras de integración — P0

**Inventario técnico y diseño de fronteras: completados.** Evidencia y límites:
[auditoría](STRATA-PROVENANCE-AUDIT.md),
[manifiesto de 435 archivos](STRATA-PROVENANCE-MANIFEST.json),
[arquitectura para actualizar LiveContainer/SideStore](UPSTREAM-SEPARATION-ARCHITECTURE.md) y
[contratos independientes](../LiveContainerSwiftUI/Views/BloomBox/BloomBoxIntegrationContracts.swift).
Esto **no** significa que toda la autoría esté resuelta ni que BloomBox ya esté aislado en módulos: es la base técnica para ejecutar las fases siguientes.

- [x] Fijar SHA de referencia de BloomBox, Strata, LiveContainer y StikJIT.
- [x] Inventariar los 435 archivos de Git del snapshot: 263 fuentes, 29 recursos y 143 otros.
- [x] Registrar por separado la descarga directa de dependencias del build; identificar el acoplamiento embebido de LiveContainer/SideStore y las herramientas aún sin pin.
- [x] Comparar exactitud de archivos contra upstream y bloques de 17 pares de archivos modificados; documentar el antecedente LiveContainer de `LCAppBanner`.
- [x] Etiquetar evidencia B/E (confirmada por bytes vs pendiente); **no inventar** categoría de autoría D ni A en los elementos que no se pueden demostrar.
- [x] Dejar matriz de prioridades por componente con acciones, pruebas y links en la auditoría; identificar seis iconos idénticos a Strata, AppleMusic y 39 traducciones con nombre Strata.
- [x] Crear contratos host/signer sin dependencias, un listado de deuda de 40 archivos Swift y un guard para no añadir nuevo acoplamiento directo.
- [x] Fijar SHA-256 del IPA SideStore embebido y de dylibify; dejar las restauraciones seguras en `Scripts/bundled-dependencies.json`.
- [x] Agregar controles de frontera y pruebas de contratos al workflow de compilación.
- [ ] **Puerta de créditos/legalidad, no de inventario:** resolver la procedencia y derechos de todas las piezas **E** mediante comparación con historial y terceros; se revisa durante fases 1–4 y 7. No quitar créditos aún.
- [ ] **Puerta de release:** aprobar pruebas completas de CI y en iPhone iOS 27 de la build que vaya a fusionarse; fase 6.

**Salida de esta etapa:** mapa de origen y deuda verificable; política para que los cambios nuevos no mezclen UI con runtime o signer; integración congelada por hash; ruta de sincronización de upstream. **La independencia física será trabajo de las fases 1–4, no de esta auditoría.**

### 1. Home / escritorio — P0

**Extracción principal de código completada; validación final de dispositivo pendiente.**
- [x] Sustituir el menú, búsqueda, favoritos, categorías, renombrado, creación de carpetas y controles por componentes de BloomBox sin tipos internos de LiveContainer: `BloomBoxHomeContextMenu`, `BloomBoxHomeSearchPanel`, `BloomBoxHomeAppPolicy`, `BloomBoxHomeNameDialogs`, `BloomBoxHomeControlTile`.
- [x] Mantener los formatos guardados (`LiveBoardHomeLayout`, favoritos, categorías, widgets y wallpaper) y preservar los IDs históricos usados por carpetas y accesos directos.
- [x] Centralizar identidad, estado de ejecución/firma, iconos internos, red, visibilidad de apps ocultas e importación de tweaks y operaciones Mach-O en `LiveContainerHomeAdapter`; sacar las 32 referencias de `LCUtils.appGroupUserDefault` del Home hacia `LiveContainerPreferencesAdapter`.
- [x] Centralizar las acciones **abrir/JIT/gestionar/desinstalar** en `LiveContainerHomeActions`, mediante comandos portables `BloomBoxHomeGuestCommand` identificados por clave. Mantener la selección exacta de app si dos instalaciones tienen una clave heredada duplicada.
- [x] Conservar el aviso del catálogo de compatibilidad antes de abrir una app, el flujo especial del signer integrado y la confirmación al desinstalar apps compartidas.
- [x] Añadir checks de límites y de compatibilidad de datos, políticas de búsqueda y favoritos, indexación de apps, comandos del adaptador y pruebas integradas al workflow de GitHub.
- [x] Reducir la mayor secuencia textual compartida con el Home de Strata fijado de **32 a 10 líneas**; esto mide duplicación visible y **no demuestra por sí solo autoría original o ausencia de licencia**.
- [ ] Validar la **última** compilación Xcode, no una build de commits previos.
- [ ] Verificar en iPhone iOS 27 las carpetas, Dock, widgets, fondos, menús, JIT, arranque en frío, apertura de apps y desinstalación sin pérdida de datos (fase 6).
- [ ] Terminar la investigación de procedencia de bloques de estado/compatibilidad que aún coincidan con Strata y de otras vistas auxiliares del Home (fases 4 y 7).
- [ ] **Separación física completa (siguiente fase):** `BloomBoxHomeScreen` todavía recibe `LCAppModel` del host para mostrar imágenes y gestionar partes de la pantalla. Extraerlo del target de LiveContainer requerirá otro contrato de modelos e integración de dependencias; la capa de acciones y preferencias ya permite hacerlo sin modificar sus comportamientos.

**Salida lograda:** lógica de Home propia y acciones de runtime concentradas en adaptadores, preparada para actualizar el núcleo LiveContainer por partes. **No se declara BloomBox completamente libre de código Strata ni de dependencias LiveContainer hasta completar las auditorías y las pruebas.**

### 2. GameBox y modos de juego — P0
- [ ] Reimplementar bloques aún coincidentes de `BloomBoxGameBoxScreen.swift`, especialmente menús, portada, controles, selección, búsqueda y lanzamiento.
- [ ] Auditar `BloomBoxGameBoxLayout`, `BloomBoxGameBoxLibrary`, `BloomBoxLaunchAction`, orientación y modo Game.
- [ ] Mantener IDs, categorías, favoritos, portadas, modo horizontal y ajustes de launch existentes.
- [ ] Reproducir pruebas de apertura en frío, cambio de juego, modo mando, pantalla completa, JIT y RAM+; incluir Husk/MeloNX cuando estén disponibles.

**Salida:** GameBox migrado y funcional en dispositivo.

### 3. Controles y personalización — P1
- [ ] Sustituir coincidencias de `BloomBoxControllerInput.swift`, sin cambiar la conducta al conectar/desconectar el mando.
- [ ] Sustituir coincidencias de `BloomBoxAppCustomization.swift`; auditar iconos/caché, nombre personalizado, favoritos y menús.
- [ ] Verificar nombres e iconos previamente guardados, controles físicos y navegación sin mando.

**Salida:** módulos propios, compatibilidad conservada.

### 4. Segunda pasada por todo el proyecto — P1
- [ ] Auditar componentes visuales y de escritorio extraídos, helpers Obj-C/Swift, hooks, módulos JIT y RAM+, ShareExtension, widgets, app list, fuentes de temas y CI.
- [ ] Verificar que JIT y RAM+ no empaqueten código/binarios de Strata; registrar dependencias directas permitidas con su licencia.
- [ ] Revisar marcas, iconos, sonidos, fondos, imágenes y otros recursos; eliminar o reemplazar los que procedan de Strata **si existe una alternativa válida**.
- [ ] Corregir **39 metadatos de idiomas** que conservan `CFBundleName = Strata`, conservando los identificadores de compatibilidad.
- [ ] Mantener el origen legítimo de LiveContainer, SideStore, StikJIT, Husk, MeloNX y demás terceros con sus avisos.
- [ ] Inspeccionar también documentación y referencias históricas: diferenciar referencias de atribución/legalidad de etiquetas visibles al usuario.

**Salida:** inventario completo sin elementos A/E sin resolver.

### 5. Auditoría automatizada y controles CI — P0 para cierre
- [ ] Extender `Scripts/audit-bloombox-independent-launcher.py` con una lista **revisada** de bloques y archivos heredados, no solo símbolos `Strata*` o rutas antiguas.
- [ ] Bloquear que reaparezcan fragmentos retirados en archivos ejecutables; documentar falsas alarmas por claves guardadas, APIs y componentes upstream.
- [ ] Validar que IPA final incluya únicamente los recursos planeados; comprobar extensiones, SideStore, JIT, entitlements RAM+ y temas empaquetados.
- [ ] Ejecutar los tests de escritorio, migración, widgets, JIT/RAM+, GameBox, dependencia/recursos y compilación Xcode sobre el **último commit**, no sobre uno anterior.

**Salida:** CI en verde en HEAD, con informe de coincidencias/atribuciones y resultado reproducible.

### 6. Pruebas en iPhone iOS 27 — bloqueo antes de merge
- [ ] Instalar como actualización sin perder apps, contenedores, diseños, carpetas, widgets, fondos ni pairing.
- [ ] Probar instalación completamente nueva (Kirby Pink por defecto) y cambio manual a Yellow Bowser.
- [ ] Probar gestos/Home/GameBox, apertura de apps y juegos, mando, JIT con LocalDevVPN, RAM+ y flujo de reinstalación.
- [ ] Probar SideStore/firma, actividades de vencimiento, animaciones, GIF/vídeo y exportación/importación de temas.
- [ ] Registrar fallos, corregirlos en la rama y repetir la prueba de la build correspondiente.

**Salida:** aprobación explícita del propietario tras pruebas reales. Un archive exitoso no sustituye esta etapa.

### 7. Créditos y lanzamiento — último paso
- [ ] Revisar el inventario final, licencias y titulares de copyright con evidencia; identificar exactamente qué avisos siguen siendo obligatorios.
- [ ] Si ya no existe material de Strata que exija atribución, considerar quitar **solo** su mención promocional en README/interfaz; si todavía existe, conservar la atribución apropiada.
- [ ] **Conservar** avisos legales obligatorios, historial de procedencia y licencias de terceros. No afirmar autoría desde cero si el producto sigue siendo derivado.
- [ ] Actualizar `README.md`, `THIRD_PARTY_NOTICES.md` y la documentación con el resultado **real** de la auditoría; no editar para simular independencia.
- [ ] Revisar PR, obtener aprobación, fusionar a `main` y preparar release separado, solo cuando se solicite.

**Salida:** créditos precisos y jurídicamente compatibles; versión final validada.

## Orden recomendado de trabajo

`Inventario (0) → Home (1) → GameBox (2) → controles/personalización (3) → segunda pasada (4) → CI (5) → iPhone (6) → créditos/release (7)`.

Se permiten pruebas y mejoras de CI en paralelo, pero **no** se deben quitar los créditos antes de cerrar las etapas 0, 4 y 7. Para las reescrituras grandes, crear ramas/commits revisables de alcance acotado y abrir PRs de trabajo hacia la rama de integración sin tocar `main`.

## Fuera de alcance

- El wizard futuro de bienvenida y elección entre Kirby Pink/Yellow Bowser.
- Rediseños opcionales que no sean necesarios para reemplazar código heredado.
- Quitar compatibilidad de datos/identificadores históricos por razones estéticas.
- Borrar historial Git, avisos requeridos o créditos de otros proyectos.

## Tablero de seguimiento

| Etapa | Estado al crear este roadmap | Bloqueante de cierre |
|---|---|---|
| 0. Inventario y fronteras | Base técnica lista; atribución final pendiente | Fases 1–4: investigar los E; fase 7: decidir créditos |
| 1. Home | Componentes y adaptadores principales listos; build/dispositivo pendientes | Verificar en iPhone, continuar aislamiento del target y atribución |
| 2. GameBox | Pendiente | Sustituir y probar bloques coincidentes |
| 3. Controles y apariencia | Pendiente | Sustituir y probar bloques coincidentes |
| 4. Resto del repositorio | Pendiente | Auditoría completa |
| 5. CI | Pendiente | Tests y archive en HEAD |
| 6. iPhone iOS 27 | Pendiente | Prueba en dispositivo + aprobación |
| 7. Créditos | Bloqueado | Auditoría de autoría/licencias cerrada |

> Este es un plan técnico, no una conclusión legal. Las obligaciones exactas de avisos y licencias dependen del código efectivamente distribuido y de su procedencia.
