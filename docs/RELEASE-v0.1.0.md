# Manzana v0.1.0 — Primera release 🍎

**Primera versión experimental de Manzana**, un escritorio alternativo inspirado en iPhone que funciona **dentro de LiveContainer/SideStore**, sin modificar el SpringBoard del sistema.

## Novedades
- **Biblioteca de apps (nueva):** desliza a la última página del Home. Tiene búsqueda, categorías con mosaicos estilo iOS, sugerencias, apps añadidas recientemente y acceso a todas las aplicaciones invitadas de LiveContainer visibles en su biblioteca. Incluye accesos SideStore e «Instalar app».
- **Home personalizable:** páginas, carpetas, Dock, fondo propio, iconos personalizados, modos claro/oscuro e iconos grandes.
- **Modo edición iPhone:** pulsación larga en el fondo, temblor de iconos, opción (−), reorganización y botón Listo. Las animaciones respetan Reducir movimiento.
- **Vista de páginas Liquid Glass:** miniaturas translúcidas con iconos y widgets animados, mostrar/ocultar, crear o eliminar páginas preservando los iconos.
- **Dock mejorado:** arrastrar directamente, reordenar y sustituir una app cuando está completo sin perder ningún icono.
- **SideStore y LiveContainer:** accesos movibles y protegidos contra borrado, importación IPA/TIPA con porcentaje de progreso y apertura de aplicaciones invitadas.
- **Menú de cada app:** iniciar, JIT, renombrar, cambiar icono, mover a carpetas/páginas, gestionar en LiveContainer, quitar solo del Home y **desinstalar con confirmación** las apps privadas.
- **Conservación de datos:** desinstalar desde Home conserva contenedores de datos por defecto. Las apps compartidas se gestionan primero desde sus ajustes.
- **Correcciones acumuladas:** botón (+) verde en drag, controles intermitentes de ajustes, bugs al eliminar páginas y apps nuevas colocadas en páginas ocultas.

## Instalación
1. Descarga **Manzana-v0.1.0-SideStore-unsigned.ipa** de los assets de esta release.
2. Firma e instala con **SideStore** conforme a tu configuración. El IPA está **sin firmar**.
3. Antes de reemplazar una instalación anterior, conserva un respaldo del contenedor de datos si contiene información importante.

**Limitaciones:** Manzana no reemplaza el escritorio real de iOS ni muestra automáticamente todas las apps del iPhone; la Biblioteca sólo incluye las aplicaciones invitadas disponibles para LiveContainer y los accesos propios de Manzana. Las categorías automáticas son aproximaciones basadas en nombre/identificador o la categoría asignada. La compatibilidad con LiveContainer en segundo plano, sesiones múltiples y permisos de iOS sigue limitada por la plataforma.

**Estado:** alpha/pre-release; compilación validada por GitHub Actions (iOS arm64 con Xcode 26.2) y empaquetado SideStore verificado automáticamente. La Biblioteca nueva aún requiere validación física en iPhone antes de considerarse completamente estable.

Repositorio: https://github.com/adri23rep-stack/Manzana
