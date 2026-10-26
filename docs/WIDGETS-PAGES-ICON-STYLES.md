# Widgets por página y estilos de iconos

Base: `feature/glass-only-library-pages`, d2b1949. Rama: `feature/widgets-pages-icon-style`.

- En edición, Añadir widget usa la página abierta. Reloj, Fotos y Notas pueden estar en varias páginas.
- Mantener pulsado un widget permite moverlo a otra página o quitarlo. Las páginas con widgets se desplazan verticalmente; los widgets aparecen encima de la cuadrícula existente, sin mover ni borrar iconos.
- Al borrar una página, sus widgets pasan a una página restante y se actualizan los índices. Se conserva una instancia de cada tipo por página. Las notas y la foto se comparten entre instancias.
- Personalizar abre un panel de cristal con Original, Oscuro, Cristal, Teñido, tamaño de iconos, modos claro/oscuro/automático y color/intensidad del tinte.
- Oscuro solicita el recurso oscuro cuando la app lo incluye. Cristal y Teñido son tratamientos visuales de la imagen; no extraen las capas originales del icono ni equivalen al motor privado de iOS. Los archivos originales no se modifican.
- La vista de páginas anima las tarjetas completas; las miniaturas internas permanecen quietas. Reducir movimiento desactiva el temblor.

Validación: pruebas de empaquetado, archivos y distribución del Home en Actions; casos nuevos de conservación de widgets al eliminar la primera, intermedia y última página. Requiere prueba visual en iPhone antes de fusionar.

Pendiente: colocar widgets libremente entre huecos de iconos, tamaños por widget y widgets originales de apps de terceros. No se incluye soporte WidgetKit externo en esta entrega.
