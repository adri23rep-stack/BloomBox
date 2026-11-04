# Manzana Files · continuación experimental

Archivos de Manzana es un espacio de documentos propio dentro de la app.
No explora archivos privados de otras apps, el sistema de iOS ni certificados de SideStore.

## Acciones disponibles
- Importar archivos desde la hoja del sistema.
- Crear carpetas, ver archivos con Quick Look, renombrar, compartir y enviar a la papelera.
- Mantén presionado un archivo o una carpeta: **Mover a carpeta** / **Copiar a carpeta**.
- En el selector, entra a las carpetas y elige **Mover aquí** o **Copiar aquí**.
- Nombres repetidos reciben un sufijo como `(2)` sin sobrescribir.
- No se permite trasladar una carpeta dentro de sí misma o sus subcarpetas.
- La papelera queda fuera del selector; los archivos de la papelera solo se restauran desde su menú.
- Mover a la carpeta actual no hace cambios. Copiar a la actual genera una copia con nombre distinto.

## Pruebas
- Prueba local con Swift 6.2.1 del almacenamiento: importación, colisiones, renombrado, carpetas, movimiento, copia, límites de rutas, papelera y restauración: **correcta**.
- La compilación iOS se configura en `.github/workflows/session-preview.yml` para esta rama. Su resultado debe comprobarse en GitHub Actions antes de dar por validado el IPA.
- No se han probado estas funciones en un iPhone real.

## Prueba rápida en iPhone
1. Abre Escritorio Manzana → Archivos.
2. Importa dos archivos con el mismo nombre y verifica que existan ambos.
3. Crea una carpeta `Pruebas` y usa **Mover a carpeta** para trasladar uno.
4. Usa **Copiar a carpeta** para conservar el original y crear otra copia.
5. Comprueba el visor, la exportación y la papelera.
6. Vuelve al launcher: la sesión de apps invitadas no debería cerrarse por usar Archivos.

## Advertencias
El IPA de GitHub Actions es **sin firmar**. Para instalarlo utiliza SideStore con la misma identidad y conserva las extensiones cuando la instalación sea compatible. Haz una copia de datos importantes antes de cambiar de versión. No mezcles datos o runtimes de otras apps y no fusiones esta rama hasta comprobar el comportamiento físico.
