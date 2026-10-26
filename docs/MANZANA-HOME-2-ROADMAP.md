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
