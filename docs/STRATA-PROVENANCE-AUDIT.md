# Auditoría de procedencia — BloomBox / Strata (etapa 0)

**Estado:** inventario inicial reproducible, **no** conclusión sobre titularidad o licencias.  
**Fecha de referencia:** 3 de noviembre de 2026.  
**Rama de trabajo:** `refactor/bloombox-independent-core` ([PR #34](https://github.com/adri23rep-stack/BloomBox/pull/34)).  
**Inventario por archivo y SHA:** [STRATA-PROVENANCE-MANIFEST.json](STRATA-PROVENANCE-MANIFEST.json).  
**Roadmap:** [ROADMAP-STRATA-INDEPENDENCE.md](ROADMAP-STRATA-INDEPENDENCE.md).

## Referencias inmutables (evidencia)

| Repositorio | Commit revisado | Función |
|---|---|---|
| [BloomBox](https://github.com/adri23rep-stack/BloomBox/tree/1bb6c8434507f23398ade875d05c27dac92f022f) | `1bb6c8434507f23398ade875d05c27dac92f022f` | Rama de refactor al iniciar etapa 0 |
| [Strata](https://github.com/huzaifahshahid71-ops/Strata/tree/9b9c86324395e484c4078e1d2883cc49b4a17dad) | `9b9c86324395e484c4078e1d2883cc49b4a17dad` | Strata 2.0 / código candidato |
| [LiveContainer](https://github.com/LiveContainer/LiveContainer/tree/bdc07ed9d0fce19f79db78a4a1015d67d4312597) | `bdc07ed9d0fce19f79db78a4a1015d67d4312597` | Base upstream documentada |
| [StikJIT](https://github.com/StikDebug/StikJIT/tree/32287268fa5824f9edce4cb359f5833ce0cf7b00) | `32287268fa5824f9edce4cb359f5833ce0cf7b00` | Código JIT upstream fijado |
| Manzana | Referencia histórica citada en `BLOOMBOX_MIGRATION.md`; repositorio independiente no recuperable en la conexión actual | Pendiente de verificar a partir del historial Git accesible |

Los árboles de Git de los cuatro repositorios accesibles se consultaron completos, sin truncamiento. Las coincidencias **exactas** se obtuvieron por SHA de blob de Git, incluso cuando el nombre/ruta cambió. Para módulos modificados o renombrados se realizó una segunda comparación de líneas normalizando espacios; esto **no** es prueba de autoría.

## 0A. Inventario de archivos de código

El inventario se amplió luego a **435 archivos rastreados en Git**, descritos por grupo abajo. Se contaron archivos con extensiones `.swift`, `.h`, `.m`, `.mm`, `.c`, `.cpp`, `.rs`, `.py`, `.sh`, `.js` y `.ts` en el commit de BloomBox fijado.

| Resultado | Cantidad | Clasificación preliminar |
|---|---:|---|
| Idénticos al LiveContainer fijado | **111** | **B** — misma implementación upstream, conservar avisos LiveContainer |
| Idénticos al StikJIT fijado, no al LiveContainer | **13** | **B** — misma implementación upstream de StikJIT, conservar sus avisos |
| Idénticos a Strata, sin coincidencia exacta con esos dos upstream | **2** | **E** — procedencia y licencia aún por resolver |
| No idénticos a ninguno de los tres (pueden estar modificados o ser nuevos) | **137** | **E** — requieren análisis de bloques e historial, **no** son automáticamente originales de BloomBox |
| **Total** | **263** | |

Del total, **125** son idénticos también a Strata, pero **110** de esos ya son idénticos a la base de LiveContainer, y otros **13** corresponden directamente a StikJIT. Los dos restantes son los casos de coincidencia exacta pendientes. **No se deben reescribir 123 archivos de terceros por el mero hecho de aparecer también en Strata.**

### Dos coincidencias exactas aún sin origen confirmado

1. `LiveContainerSwiftUI/Views/AppList/LCAppBanner/LCAppBannerViewController.swift` (13.316 bytes). Se encuentra byte por byte en Strata; no coincide con los commits de LiveContainer ni StikJIT usados en esta revisión. **Verificar autoría y posibilidad de otras versiones upstream**, luego mantener atribución adecuada o reimplementar.
2. `Tests/layout-tests/main.swift` (1.709 bytes). Prueba idéntica a Strata en el snapshot. Puede necesitar sustitución de pruebas/revisión de procedencia; no afecta por sí misma al ejecutable.

**Nota:** algunas diferencias con el LiveContainer fijado pueden ser cambios upstream de otras versiones, no necesariamente código original de Strata.

### Coincidencias de implementación en archivos modificados

Comparación directa de 17 pares de archivos correspondientes de Strata → BloomBox. Valor: mayor secuencia de líneas consecutivas idénticas encontrada, con espacios normalizados. No sumar estas cifras ni interpretarlas como porcentaje de código copiado.

| Módulo (Strata → BloomBox) | Bloque idéntico máx. | Clasificación preliminar y acción |
|---|---:|---|
| `LiveBoardHomeScreen` → `BloomBoxHomeScreen` | 32 | **E / P0**: menús de apps, favoritos, búsqueda y estado del Home |
| `LiveBoardConsoleScreen` → `BloomBoxGameBoxScreen` | 51 | **E / P0**: interacciones, menús, detalles de juegos |
| `LiveBoardControllerInput` → `BloomBoxControllerInput` | 37 | **E / P1**: entradas y foco del mando |
| `LiveBoardAppCustomization` → `BloomBoxAppCustomization` | 32 | **E / P1**: personalización de apps |
| `LiveBoardHomeLayout` → `BloomBoxHomeLayout` | Sin bloques de ≥8 líneas en este escaneo | **D/E**: motor nuevo; verificar historial; preservar datos |
| `LiveBoardConsoleLayout` → `BloomBoxGameBoxLayout` | 30 | **C/E**: mayoría estructura de ajustes persistidos, examinar lógica restante |
| `LiveBoardModeLibrary` → `BloomBoxGameBoxLibrary` | 11 | **E**: funciones de categorías |
| `LiveBoardIconStore` → `BloomBoxIconStore` | Sin bloques ≥8 | **D/E**: verificar historial |
| `LiveBoardIconEdges` → `BloomBoxIconEdges` | 24 | **E**: tratamiento gráfico de iconos |
| `LiveBoardOrientation` → `BloomBoxOrientation` | 10 | **C/E**: valores de orientación y lógica |
| `LiveBoardLaunchAction` → `BloomBoxLaunchAction` | Sin bloques ≥8 | **D/E**: verificar historial y semántica |
| `LiveBoardNavigationAudio` → `BloomBoxNavigationAudio` | 18 | **E**: generación de audio, no archivos de terceros |
| `LiveBoardBuiltInJIT` → `BloomBoxJITCoordinator` | 10 | **C/E**: comprobar protocolo común, JIT puente y procedencia |
| `LiveBoardJITSetup` → `BloomBoxJITSetup` | 13 | **E**: pantalla de preparación |
| `LiveBoardHomeWidgets` → `BloomBoxWidgetViews` | Sin bloques ≥8 | **D/E**: verificar historial |
| `LiveBoard` → `BloomBoxLauncherRoot` | 8 | **C/E**: configuración guardada de modos |
| `LiveBoardArtworkStore` → `BloomBoxArtworkLibrary` | Sin bloques ≥8 | **D/E**: verificar historial |

`C` significa coincidencia que podría ser **solo formato de datos/API**, no autoría de implementación; `D/E` indica potencial BloomBox propio, todavía no certificado. Los bloques de 8–10 líneas pueden ser SwiftUI genérico y requieren revisión humana. **No** se ha completado aún una comparación de bloques contra todas las versiones de LiveContainer, Manzana y demás upstream.

**Ejemplos para revisión manual:**
- [Home de Strata (líneas 359–390)](https://github.com/huzaifahshahid71-ops/Strata/blob/9b9c86324395e484c4078e1d2883cc49b4a17dad/LiveContainerSwiftUI/Views/LiveBoardHomeScreen.swift#L359-L390) ↔ [Home de BloomBox (2376–2407)](https://github.com/adri23rep-stack/BloomBox/blob/1bb6c8434507f23398ade875d05c27dac92f022f/LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift#L2376-L2407).
- [GameBox precedente (Strata, 439–489)](https://github.com/huzaifahshahid71-ops/Strata/blob/9b9c86324395e484c4078e1d2883cc49b4a17dad/LiveContainerSwiftUI/Views/LiveBoardConsoleScreen.swift#L439-L489) ↔ [BloomBox GameBox (957–1007)](https://github.com/adri23rep-stack/BloomBox/blob/1bb6c8434507f23398ade875d05c27dac92f022f/LiveContainerSwiftUI/Views/BloomBox/BloomBoxGameBoxScreen.swift#L957-L1007).

### Seguimiento: LCAppBanner tiene antecedente upstream en LiveContainer

- La coincidencia exacta BloomBox ↔ Strata de `LiveContainerSwiftUI/Views/AppList/LCAppBanner/LCAppBannerViewController.swift` **no implica autoría original de Strata**. El [historial de LiveContainer](https://github.com/LiveContainer/LiveContainer/commits/main/LiveContainerSwiftUI/Views/AppList/LCAppBanner/LCAppBannerViewController.swift) registra una reescritura previa el **1 de agosto de 2026** ([commit `3a9d2186`](https://github.com/LiveContainer/LiveContainer/commit/3a9d2186a09e9bb4315b2de295073ef3806d8ac4)).
- Al comparar el archivo completo de Strata 2.0 (361 líneas) contra esa versión de LiveContainer (382 líneas), apareció un bloque de **251 líneas consecutivas idénticas**, tras normalizar espacios. **Es evidencia fuerte de procedencia LiveContainer**, pero hay diferencias fuera del bloque y aún faltan las decisiones A/B/C/D/E sobre esas diferencias.
- Se mantiene su clase de inventario `E_STRATA_EXACT_ORIGIN_PENDING` porque el manifiesto mide coincidencia **byte por byte con las revisiones fijadas**, no conclusiones de autoría. No cambiar la clase para aparentar una coincidencia exacta con la base LiveContainer que no existe.
- Siguiente verificación: revisar en Git las diferencias de 2026-08-01 a 2026-10-22; aislar cualquier implementación realmente exclusiva de Strata, sin quitar la atribución a LiveContainer.

## 0B. Multimedia, iconos y otros recursos

Se inventariaron **29** archivos de extensiones de imagen, animación, audio, vídeo, tipografías y `.bbtheme`:

| Comparación exacta | Cantidad | Estado |
|---|---:|---|
| LiveContainer | 13 | **B**, no son evidencia de autoría exclusiva de Strata |
| Strata, no LiveContainer ni StikJIT | 7 | **E**, revisar derechos, uso y empaquetado |
| Ninguno de esos upstream | 9 | **E**, incluyen recursos propios nuevos y requieren documentar autoría |

Los **7** recursos con coincidencia exacta pendiente son **seis rutas del icono/AppIcon** que comparten un solo contenido visual y `Resources/Assets.xcassets/LiveBoardByeTunes.imageset/AppleMusic.jpg`. La fuente de Strata decía que su icono estaba adaptado de arte proporcionado por su propio dueño: **no basta con que BloomBox lo regenere durante CI para suponer que el archivo almacenado en el repositorio sea nuestro**. Determinar si se empaqueta y sustituir cualquier arte que no tengamos permiso para distribuir. La imagen Apple Music es otro asunto de derechos de terceros, no un crédito automático a Strata.

Los temas **Kirby Pink** y **Yellow Bowser** proporcionados por el propietario se conservan; las obras y personajes que representen siguen sujetos a los derechos de sus respectivos titulares.

También quedan pendientes de revisar rutas, nombres y licencias de: submódulos, fuentes de código de distribución, archivos de metadatos, ejecutables descargados en el build y recursos que no están en estas extensiones. **El recuento anterior no equivale al inventario completo de binarios.**

## 0B-bis. Otros archivos rastreados por Git

El inventario se amplió para cubrir los **435 archivos** que figuran como blobs en el árbol de Git del commit fijado, no solo código y multimedia. Además de los 263 archivos de código y 29 de multimedia, hay **143 archivos** de configuración, licencias, metadatos, traducciones y similares:

| Coincidencia byte por byte | Otros archivos |
|---|---:|
| LiveContainer | 49 |
| StikJIT | 4 |
| Strata, sin coincidencia exacta con esos dos upstream | 46 |
| Ninguno de esos upstream | 44 |
| **Total** | **143** |

**Hallazgo concreto de marca:** 39 archivos localizados `Resources/*.lproj/InfoPlist.strings`, todos con el mismo SHA `4348e566996021f3defe49951bc64bfb06083cb1`, son listas de propiedades binarias con `CFBundleName = Strata`. Están en el repositorio de BloomBox y coinciden con Strata; el nombre puede seguir apareciendo según el empaquetado y el idioma. Antes de la entrega final, sustituir el **valor de marca** por BloomBox en las traducciones pertinentes, verificando la IPA y sin tocar claves de almacenamiento o bundle IDs que protegen datos. **No se ha modificado este material en la etapa 0.**

Otras coincidencias en esta categoría incluyen metadatos/licencias de LiveExec32 (upstream LiveContainer), `Vendor/StikJIT/UPSTREAM.txt`, licencias de idevice, una configuración de ShareExtension y un workflow de AltStore. No atribuir a Strata códigos o licencias de terceros por haberlos heredado de su repositorio.

**Límite de esta cobertura:** 435 archivos **versionados en Git**, no submódulos completos, archivos binarios descargados durante CI ni todos los elementos contenidos en la IPA construida. Esos necesitan auditoría del artefacto final.

## 0C. Etiquetas de procedencia (A–E)

- **A — Strata original confirmado:** requiere prueba de commits o comparación upstream adicional; **ningún archivo declarado A de forma definitiva** en esta primera pasada.
- **B — Upstream confirmado:** coincidencia exacta con LiveContainer o StikJIT. Mantener licencias y avisos del proyecto titular.
- **C — Contrato de compatibilidad:** claves guardadas, bundle IDs, estructura de `Codable`, constantes del protocolo y APIs. Preservar aunque contengan nombres antiguos.
- **D — BloomBox propio confirmado:** acreditar con historial de commits/fuente original; no clasificar como D únicamente porque un hash no coincide.
- **E — Pendiente:** todos los elementos potencialmente modificados, derivados, propios o de terceros cuya procedencia no se haya demostrado.

El nombre `Strata` en un respaldo, una ruta de importación anterior o una mención histórica **no** demuestra que se ejecute código de Strata. Borrar esos identificadores puede destruir compatibilidad.

## 0D. Pruebas mínimas que deben preceder a las reescrituras

La rama ya tiene suites para las áreas que se van a tocar: Home layout y navegación, App Library, widgets, Theme Store/medios, iconos, GameBox, JIT/pareado, RAM+, instalación y SideStore. La build #370 compiló en su commit anterior; **no certifica** commits más recientes ni el funcionamiento en iPhone.

Antes de la etapa 1:
- [ ] Registrar una IPA de referencia con commit y pruebas reales de iOS 27 (actualizar sin perder datos).
- [ ] Guardar respaldos locales de ajustes del Home, GameBox, carpetas y widgets, sin credenciales ni claves en GitHub.
- [ ] Añadir pruebas específicas de los menús/gestos que se vayan a reimplementar y conservar el esquema de preferencias.
- [ ] Mantener las comprobaciones de RAM+/JIT y empaquetado.
- [ ] Resolver procedencia **A/B/C/D/E** con evidencia, sin borrar todavía avisos legales.

## Pendientes explícitos para cerrar la etapa 0

1. Rastrear versiones y commits de Strata, LiveContainer y Manzana para distinguir autoría de bloques parcialmente idénticos.
2. Investigar los **dos** archivos de código exactos sin upstream identificado y los **siete** recursos idénticos a Strata.
3. Clasificar las fuentes modificadas en la matriz, revisar los módulos de terceros y binarios que no entran en el inventario de extensiones.
4. Fijar pruebas/registros pre-reescritura para las funciones P0.
5. Validar la evidencia antes de afirmar que Strata ya no tiene material protegido en BloomBox.

**Conservar `LICENSE`, `THIRD_PARTY_NOTICES.md` y la historia Git.** Solo al concluir esta auditoría y la sustitución de código se podrá decidir qué crédito visible sobra, sin borrar avisos obligatorios.

## 0E. Cierre técnico y entrega a las siguientes fases (3 nov 2026)

**Terminada la base de la etapa 0**: manifiesto con los 435 archivos Git del
snapshot, referencias por SHA, comparación binaria y por bloques, límites de
compatibilidad, riesgos pendientes, contratos neutrales y regla de CI para
reducir el acoplamiento. **No** se ha declarado independencia total ni se han
retirado créditos. Las decisiones sobre autoría original de los elementos E
siguen siendo tarea de las fases 1–4 y revisión final de licencias.

### Matriz de riesgo y propiedad técnica

| Grupo | Elementos en snapshot | Dueño o procedencia demostrada | Acción pendiente |
|---|---:|---|---|
| Coincide exactamente con LiveContainer | 173 | B — LiveContainer en la revisión fijada | Mantener avisos; actualizar por versión/adapter |
| Coincide con StikJIT (no LC) | 17 | B — StikJIT en la revisión fijada | Mantener avisos y SHA upstream |
| Coincide con Strata pero no con esas dos revisiones | 55 | E — **no** prueba de autoría de Strata | Revisar: 2 fuentes, 7 recursos, 46 metadatos/otros (39 traducciones con marca) |
| Sin coincidencia exacta | 190 | E — pueden ser modificaciones o material propio/de terceros | Auditar módulos parcialmente heredados y su historial antes de declarar D |
| **Total** | **435** | | |

**Importante:** son coincidencias con snapshots, no una evaluación de si un
archivo es compilado, redistribuido o de quién son los derechos. Ejemplo:
`LCAppBannerViewController.swift` coincide con Strata pero contiene un tramo
de 251 líneas idénticas a LiveContainer de agosto de 2026, anterior a Strata.
La procedencia de sus diferencias queda abierta.

### Seams preparados para actualización independiente

- [Arquitectura y flujo por dependencia](UPSTREAM-SEPARATION-ARCHITECTURE.md):
  UI BloomBox → contratos propios → adaptadores LiveContainer/SideStore.
- `BloomBoxIntegrationContracts.swift` define las solicitudes de invitadas y
  firma, sin importar ningún modelo host ni exponer tokens de sesión.
- `Scripts/upstream-boundaries.json` registra **40 fuentes antiguas**
  permitidas temporalmente; cualquier **archivo nuevo** de UI con dependencia
  directa a modelos LC o al signer falla el guard de CI.
- `Scripts/bundled-dependencies.json` ahora fija el SHA-256 de
  `SideStore.ipa` y `dylibify`; el empaquetado no vuelve a ejecutar wget de
  una nightly mutable. Un cambio del IPA sin actualización consciente del hash
  detiene la preparación.
- Compilación de contratos comprobada fuera de Xcode; nueva validación CI
  integrada. El archive actual y las pruebas en el iPhone siguen pendientes.

### Puertas que no se han aprobado

1. Las 55 coincidencias E con Strata, las 190 E no idénticas y los bloques
   parcialmente idénticos **no** pueden etiquetarse como BloomBox original
   sin revisar su procedencia. `Manzana` no está accesible como repositorio
   separado en esta conexión; usar historial y fuentes alternativas.
2. Los iconos originales, imagen Apple Music y las 39 traducciones con
   `CFBundleName = Strata` siguen pendientes de limpieza, sin tocar IDs de
   datos o bundle hasta probar migración.
3. LiveContainer y SideStore **continúan acoplados físicamente** en el Xcode
   target y el IPA actuales; los contratos todavía no tienen adaptadores
   de producción. Eso se implementará incrementalmente en fases posteriores.
4. Un paso verde de CI no valida un upgrade en iOS 27, JIT, RAM+, firma,
   contenedores ni pérdida de datos. Tampoco autoriza retirar avisos legales.

La meta de la etapa 0 era poder empezar la reescritura con un mapa verificable
y con fronteras nuevas; **esa base está lista**, pero no se debe confundir
con la eliminación efectiva de todo código heredado de Strata.
