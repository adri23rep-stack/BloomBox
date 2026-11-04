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

Se contaron archivos con extensiones `.swift`, `.h`, `.m`, `.mm`, `.c`, `.cpp`, `.rs`, `.py`, `.sh`, `.js` y `.ts` en el commit de BloomBox fijado.

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
