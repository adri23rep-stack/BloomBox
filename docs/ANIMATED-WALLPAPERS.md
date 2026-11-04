# Fondos animados

Rama: `feature/animated-wallpapers`, sobre widgets por página y estilos de iconos.

En Wallpaper > Importar video o GIF (Archivos), seleccionar MP4/MOV compatible o GIF. Los videos se reproducen en loop y silenciados. Los GIF conservan sus tiempos por cuadro. Controles: pausar, mostrar completo/rellenar y oscurecer. Reducir movimiento detiene la animación; salir de la app pausa la reproducción.

Se copia y valida el archivo antes de activar el fondo; una importación fallida conserva el anterior. Hasta 200 MB por archivo; GIF de hasta 500 cuadros, reducidos a un máximo de 720 px y un presupuesto conservador de 48 MB de píxeles decodificados. Solo se conserva el último fondo animado importado. No se modifica el archivo original.

Pruebas automatizadas: tiempos de un GIF de dos cuadros, copia persistente, rechazo de GIF corrupto y conservación del fondo anterior; compilación iOS y verificación de SideStore. La fluidez, encuadre y consumo requieren prueba física en iPhone. No importa directamente desde Fotos: guardar el video/GIF en Archivos primero.
