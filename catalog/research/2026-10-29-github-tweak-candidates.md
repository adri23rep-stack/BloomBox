# Candidatos de GitHub para BloomBox Tweak Store — 29/10/2026

> **Investigación; NO publicadas en `catalog/tweaks.json`.** No se ha probado ninguno en el iPhone del usuario con iOS 27 ni en BloomBox. El repositorio original y las URL de sus autores se conservan. La presencia de `.dylib` y de hash SHA-256 en GitHub **no implica** compatibilidad ni auditoría de seguridad. No agregar entradas instalables hasta seleccionar la app destino, revisar dependencias/licencias y probar en un contenedor desechable.

## Candidatos con lanzamientos verificables

### 1) MarketplaceAdBlock — candidato para primera prueba limitada
- **Autor y fuente original:** [adamsardo/MarketplaceAdBlock](https://github.com/adamsardo/MarketplaceAdBlock).
- **Qué hace:** oculta anuncios en la sección Marketplace de Facebook.
- **Destino:** Facebook para iOS. El autor menciona pruebas en Facebook 584.0.0 y iOS 27.2 beta mediante inyección a un IPA; **BloomBox no verificado**.
- **Release:** [v1.0.0](https://github.com/adamsardo/MarketplaceAdBlock/releases/tag/v1.0.0), 21/10/2026.
- **Archivo normal:** `MarketplaceAdBlock.dylib`, 95 696 bytes.
- **SHA-256 de GitHub Release:** `f8c264e8f423034cc4edea4c4dd7d55f100465b20c62a0d61596bf50d805d3b7`.
- **URL del asset:** https://github.com/adamsardo/MarketplaceAdBlock/releases/download/v1.0.0/MarketplaceAdBlock.dylib
- **Observaciones:** versión de Facebook crítica; evitar variante debug. No se encontró licencia declarada en metadatos de GitHub; revisar atribución y permiso antes de redistribuir; usar siempre el asset original. `alertLevel: 0` si se incorpora.

### 2) AIUpscaleTweak — interesante para juegos, requiere definir destino
- **Autor y fuente original:** [trail-b1az3r/Upscale](https://github.com/trail-b1az3r/Upscale), licencia MIT.
- **Qué hace:** upscaling espacial con MetalFX de un juego renderizado con Metal; no es superresolución basada en red neuronal. Puede consumir GPU, memoria y batería.
- **Release:** [v0.0.4](https://github.com/trail-b1az3r/Upscale/releases/tag/v0.0.4), 31/07/2026.
- **Archivo:** `AIUpscaleTweak.dylib`, 113 632 bytes.
- **SHA-256 de GitHub Release:** `c244397f7aa58c015954ba825f6551ceeb146f77b4d6b9702001b8f7e966ccba`.
- **URL del asset:** https://github.com/trail-b1az3r/Upscale/releases/download/v0.0.4/AIUpscaleTweak.dylib
- **Observaciones:** documentación describe instalación con LiveContainer, pero no prueba específica en BloomBox ni iPhone 14 Pro. La Tweak Store actual exige una app destino por bundle ID; no publicar un tweak global sin selector por app. `alertLevel: 0`.

### 3) Isaac External Item Descriptions — excelente integración LiveContainer, pero formato especial
- **Autor y fuente original:** [emp0ry/IsaacExternalItemDescriptionsiOS](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS), MIT.
- **Qué hace:** muestra descripciones de objetos y contenido en The Binding of Isaac: Repentance para iOS.
- **Release:** [v1.1.2](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/releases/tag/v1.1.2), 22/10/2026.
- **Archivos:** `IsaacExternalItemDescriptions.dylib` (648 592 bytes; SHA-256 `2c2f2b3c1d312e9e8834ef6e4fd8dce728fdbe44b540522178ca0ef1b7b91a75`); pero la **instalación LiveContainer recomendada** utiliza `IsaacExternalItemDescriptions-LiveContainer.framework.zip` (SHA-256 `507d5537ac0db4e47a1de36e7dbac66a4a68dfefc8cfd506e0ff65de192df7e1`).
- **Observaciones:** la tienda genérica actual solo instala `.dylib`; extender a frameworks ZIP/recursos y hacer pruebas en el ejecutable exacto; el autor documenta limitación a Repentance 1.7.9b.J754. No distribuir IPA del juego.

### 4) InstaPlus — requiere parche adicional para sideload
- **Autor y fuente original:** [eYushaa/InstaPlus](https://github.com/eYushaa/InstaPlus), licencia personalizada BY-NC; revisar términos.
- **Destino:** Instagram para iOS.
- **Release:** [V1.0.2-1](https://github.com/eYushaa/InstaPlus/releases/tag/V1.0.2-1), 16/09/2026.
- **Archivo:** `InstaPlus.dylib`, 901 344 bytes, SHA-256 `50b7bc820391ba30fdd64979e56d113d90b5356803ebdb29f5e214f0c2c58861`.
- **Observaciones:** documentación del autor exige la función *Sideload Spoofer* en Sideloadly; no se ha verificado que funcione dentro de BloomBox. Tiene funciones que requieren servidor adicional; no asumir independencia de red. Mantener fuera del catálogo instalable por ahora.

### 5) iOS-App-Dylib-Patches — repositorio de código para parches de compatibilidad
- **Autor y fuente:** [msx98/iOS-App-Dylib-Patches](https://github.com/msx98/iOS-App-Dylib-Patches).
- **Qué contiene:** parches específicamente destinados a apps ejecutadas dentro de LiveContainer (por ejemplo, soluciones de entitlements y despliegue de dylibs), compilables vía CMake.
- **Observaciones:** no se encontró *latest release* binario en GitHub, y el flujo documenta `NetworkLoader` por socket local. **No añadir NetworkLoader remoto como tweak de tienda** ni abrir descargas ejecutables automáticas. Revisar cada parche concreto y su código, compilar y publicar un release firmado/revisado separado, con permiso y licencia comprobados.

## No recomendados para el catálogo instalable actual

- [KohlerVG/FnMacTweak](https://github.com/KohlerVG/FnMacTweak): enfocado a Fortnite iOS en **Mac con Apple Silicon**, no a iPhone (aunque publique `.dylib`).
- [9nT0/GlossyGlass](https://github.com/9nT0/GlossyGlass): visualmente interesante y menciona LiveContainer, pero el último release consultado contiene `0_DylibLoaderVer1-2-0.dylib`, no el `GlossyGlass.dylib` principal descrito como build de Actions; confirmar procedencia, posibles descargas adicionales y compatibilidad antes de incluirlo.
- [faroukbmiled/RyukGram](https://github.com/faroukbmiled/RyukGram): empaquetado de varias bibliotecas y bundles; el repositorio indica código cerrado por ahora y requisitos por versiones de Instagram. La tienda actual no gestiona su distribución integral.

## Requisitos antes de publicar una nueva ficha

1. Confirmar nombre del **autor real**, repositorio y licencia; enlazar `officialSourceURL` al proyecto original y `downloadURL` al asset auténtico.
2. Comprobar la arquitectura y SHA-256 del asset; registrar versión y filename fijo; no publicar scripts de ejecución remota.
3. Identificar `bundleID` y versiones de la app soportada, incluyendo si la IPA reescribe su Bundle ID.
4. Probar en modo privado/compartido según corresponda, verificar que el juego abre y que su información y nube se mantienen.
5. Publicar inicialmente con nivel **0 (opcional/no probado)**, sin afirmar compatibilidad hasta probarla. Preferir estado "En revisión" como un listado separado hasta que BloomBox admita fichas no instalables.

**Resultado:** búsqueda y metadatos documentados sin alterar la tienda pública, `main` ni las IPAs instaladas.
