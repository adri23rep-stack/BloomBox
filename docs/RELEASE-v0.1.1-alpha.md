# 🍎 Manzana v0.1.1-alpha — Widgets, iconos y fondos animados

**Nueva compilación experimental para SideStore**, tomada de la ejecución correcta de GitHub Actions [#40302143478](https://github.com/adri23rep-stack/Manzana/actions/runs/40302143478), rama `feature/animated-wallpapers`.

### Cambios incluidos
- Widgets internos de Reloj, Fotos y Notas en páginas distintas; mover, quitar y conservar al eliminar páginas.
- Editor visual de iconos: Original, Oscuro, Cristal y Teñido, tamaño y tinte configurables.
- Vista de páginas Liquid Glass con animación de las tarjetas completas.
- Fondos animados: GIF y video MP4/MOV importados desde Archivos, reproducción en bucle y sin audio; pausa, encuadre y oscurecimiento.
- Respetar «Reducir movimiento»; detener el fondo al dejar Manzana en segundo plano.

### Instalación
1. Descarga `Manzana-v0.1.1-alpha-SideStore-unsigned.ipa`.
2. Firma la IPA mediante SideStore. **No está firmada**.
3. Conserva respaldos y la identidad de firma si actualizas una instalación existente.

### Límites y validación
- El build iOS, pruebas de lógica y verificación del paquete SideStore pasaron en Actions. **Pendiente validación visual y de rendimiento en iPhone físico**.
- Widgets de otras apps (WidgetKit), colocación libre de widgets entre iconos y tamaños individuales aún no están disponibles.
- GIF limitados a 500 cuadros (escalados para cuidar memoria); video/GIF hasta 200 MB. Importa desde Archivos, no directamente desde Fotos.
- No reemplaza SpringBoard, no habilita acceso a apps arbitrarias fuera de LiveContainer ni elimina límites del sistema.
- La IPA corresponde al commit compilado `a9c2bd0af9713e3dc2e4f89de1cdaff4aefa014a`; los cambios posteriores en documentación no alteran el binario.

Esta versión se publica por separado de v0.1.0 para conservar el Release inicial sin sobrescribirlo.
