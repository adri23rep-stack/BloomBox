# 🍎 Manzana Home 2.0 — Roadmap

**Objetivo:** imitar el escritorio de iPhone dentro de LiveContainer: su ritmo, edición, gestos, aspecto y personalización. No sustituye SpringBoard ni permite acceder a apps fuera de la sesión. Sin Takopi Explorer.

**Base:** `fix/iphone-home-stage1-build` (compiló correctamente con Xcode 26.2 y paquete SideStore). Cada sesión va en una rama independiente, CI + prueba física antes de fusionar. `main` se conserva.

## Sesión 1 — Gestos y modo edición
- [ ] Pulsación larga en espacio vacío del Home activa la edición sin abrir menús.
- [ ] Feedback táctil y entrada/salida animada; temblor de iconos y carpetas, también en Dock. Respetar Reducir movimiento.
- [ ] Botón (−) en esquina de cada icono/carpeta en páginas y Dock.
- [ ] El botón abre opciones claras: quitar solo del escritorio o administrar/desinstalar la app invitada desde su pantalla de gestión, sin borrar datos directamente.
- [ ] Botón **Listo** termina edición, y siguen funcionando arrastrar, soltar, carpetas, búsqueda y navegación.
- [ ] Compilación arm64 + empaquetado SideStore; prueba en iPhone sin interferir con long-press de iconos.

## Revisión obligatoria antes de la sesión 2

**Estado:** Sesión 1 compilada en GitHub Actions, pero **todavía en prueba del iPhone**. No se considera terminada ni debe fusionarse hasta revisar los puntos siguientes.

### Bugs reportados

- [ ] **BUG-001 · Alta prioridad · Acceso a SideStore** — El usuario reportó que desaparecieron o quedaron inaccesibles las opciones para entrar a SideStore desde el escritorio de Manzana. **Pendiente reproducir y ubicar la causa**; no se debe asumir que se borró SideStore. Resultado esperado: llegar a SideStore y a la gestión de apps sin perder el escritorio ni las opciones que ya funcionaban.
- [ ] **BUG-002 · Interfaz de arrastre · Prioridad media** — Al tomar/arrastrar una app en el escritorio aparece un **símbolo verde (+)** superpuesto al icono (captura del usuario). Se solicita **quitar ese indicador** para que arrastrar/reordenar se vea como el Home original del iPhone. Mantener funcionando drag & drop, sin marcador verde de copia. **Pendiente investigar y corregir junto a los demás bugs; no modificar código todavía.**

- [ ] **BUG-003 · Gestión de páginas · Prioridad alta** — El escritorio permite **crear páginas nuevas, pero no eliminarlas**. Debería permitir borrar páginas vacías de forma intuitiva, sin mover ni perder iconos inesperadamente. Las páginas no vacías deben requerir tratamiento seguro de su contenido (reubicar o confirmar) antes de borrarse.
- [ ] **BUG-004 · Controles intermitentes · Prioridad alta** — En la pantalla **«Escritorio»** (captura adjunta por el usuario), las tarjetas **Interface, Sources, Tweaks, Wallpaper, Apps, Settings y JIT** algunas veces responden al toque y otras no. Investigar posibles conflictos de presentación de hojas, navegación, hit-testing o gestos; asegurar respuesta consistente y acceso funcional a SideStore/LiveContainer.

### Mejoras y revisión de la sesión 1

- [ ] **MEJ-001 · Accesos claros** — Mantener un acceso visible y sencillo a SideStore, a apps instaladas y a ajustes de LiveContainer, sin saturar el Home estilo iPhone. Antes de rediseñarlos, validar con el usuario dónde quiere cada entrada.
- [ ] **MEJ-002 · Edición natural** — Probar pulsación larga sobre espacio vacío, entrada al temblor, botones (−) de iconos y carpetas y salida con «Listo»; ajustar respuesta y animaciones según las pruebas en el dispositivo.
- [ ] **MEJ-003 · No perder funciones** — Verificar arrastrar y ordenar iconos, Dock, carpetas, búsqueda, apertura de apps, regreso al launcher y persistencia del diseño después de cerrar/reabrir.
- [ ] **MEJ-004 · Borrado seguro** — Distinguir «Quitar de inicio» de «Desinstalar»; pedir confirmación antes de cualquier operación destructiva y no tocar datos de SideStore accidentalmente.
- [ ] **MEJ-005 · Accesibilidad y fluidez** — Probar modo claro/oscuro, Reduce Motion, vibración, animaciones y que los gestos del escritorio no bloqueen los menús o los toques normales.

- [ ] **MEJ-006 · Animación al quitar iconos** — Al tocar (−) y confirmar «Quitar del inicio», el icono debe **encogerse/desaparecer con una animación** tipo iPhone, respetando Reducir movimiento, mientras el resto de la cuadrícula se reorganiza de manera fluida.
- [ ] **MEJ-007 · Acceso directo fijo a SideStore** — Añadir un **icono que parezca una app «SideStore»** en el escritorio y que abra SideStore/la vía de entrada compatible. Debe ser **movible entre posiciones/páginas y dock, pero imposible de borrar u ocultar**; no crear una app nueva real y no cambiar el bundle instalado.
- [ ] **MEJ-008 · Acceso directo a instalar apps** — Añadir otro **icono tipo app «Instalar app»** que abra directamente la instalación/importación de apps de LiveContainer. Es un **acceso directo dentro de Manzana**, no una app instalada independiente, y debe conservar la navegación de regreso.
- [ ] **MEJ-009 · Compatibilidad de páginas** — Incorporar una opción coherente para gestionar y eliminar páginas desde la propia edición, alineada a la futura Sesión 4. Priorizar al menos la eliminación segura de páginas vacías antes de la Sesión 2.

### Criterios para avanzar
- [ ] SideStore y administración de apps vuelven a ser accesibles.
- [ ] El usuario confirma en iPhone que los gestos y controles de edición funcionan.
- [ ] Ninguna función previa se pierde; compilación de IPA combinado y comprobación de extensiones correctas.
- [ ] El usuario da el visto bueno a la sesión 1.

**Nota de alcance:** Esto es una lista de seguimiento, no una confirmación de que las mejoras ya estén programadas ni implementadas. **No modificar código** hasta revisar las pruebas y decidir los ajustes.

## Sesión 2 — Menú flotante de edición
- [ ] Abrir menú translúcido de la esquina con **Añadir widget**, **Personalizar**, **Editar fondo**, **Editar páginas**.
- [ ] Animación, desenfoque, modo claro/oscuro, accesibilidad y acciones funcionales.

## Sesión 3 — Personalización avanzada
- [ ] Panel estilo iOS: **Predeterminado**, **Oscuro**, **Transparente (Clear)**, **Teñido (Tinted)**.
- [ ] Color/intensidad para iconos teñidos, claro/oscuro/automático y tamaño estándar/grande.
- [ ] Vista previa inmediata sin destruir iconos personalizados ni imágenes originales.

## Sesión 4 — Páginas y fondos
- [ ] Vista general de páginas; ocultar/mostrar, reordenar, agregar y conservar la distribución.
- [ ] Fondos con selección, ajustes de encuadre/desenfoque y transiciones compatibles con apps normales.

## Sesión 5 — Widgets y pulido
- [ ] Galería de widgets internos, tamaños y colocación junto a iconos.
- [ ] Integración de reloj, fotos y notas, drag/drop y fluidificar UI.
- [ ] Revisar memoria, rendimiento, VoiceOver, haptics y Reduce Motion.

### Entrega por sesión
1. Rama y PR en borrador, sin tocar `main`.
2. GitHub Actions valida compilación iOS y genera IPA sin firmar + SideStore combinado.
3. Pruebas en iPhone antes de integrar. Rechazar cambios que rompan invitados, firma o extensiones.

*Nota:* «100 % idéntico» es la referencia visual y de interacción; hay funciones privadas del SpringBoard que una app normal no puede reproducir literalmente.
