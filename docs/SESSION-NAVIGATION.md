# Strata: navegación de sesión Alpha 1

Base: huzaifahshahid71-ops/Strata c6efc2d0d1134e366f2c1d7401a6a5dd984b4b7f.
Estado: NO compilado con Xcode; NO probado en iPhone.

## Cambios
- Inicio iOS abre Shared Apps en multitarea interna, maximizadas.
- Inicio minimiza las ventanas y muestra el dock para recuperar apps.
- Apps abiertas permite abrir/cerrar cada contenedor mediante un menú actualizado.
- Cerrar usa la ruta manual y no dispara el reinicio automático.
- Barra arriba/abajo con posición persistente; permanece visible al plegar el dock.
- Mantener pulsado un icono del dock permite abrir/cerrar esa app.
- Autenticación antes de recuperar una ventana bloqueada desde la biblioteca.

## Límites
Se requiere convertir las apps a Shared App desde sus ajustes y desactivar Classic Mode.
No se migran datos automáticamente. SideStore conserva su ruta especial.
Cinematic y Big Picture conservan su política de lanzamiento.
No hay mezclador de audio, barra lateral nueva ni tarjetas con capturas.

## Validación
Los cinco archivos Swift/Objective-C modificados pasan análisis sintáctico con
tree-sitter. Esto NO valida tipos, enlaces ni APIs UIKit.
Tres pruebas del empaquetador pasan: ejecutable ausente, extensión ausente y
estructura Payload/extensiones/permisos del ejecutable.
YAML válido y git diff --check limpio.

## Compilación pendiente
Strata Session Preview se ejecuta al subir feature/session-navigation o manualmente.
Usa Xcode 26.2, restaura dependencias fijadas y genera un IPA SIN FIRMAR en Actions.
No publica releases ni pide certificados.
Este workflow genera la versión independiente; NO reconstruye todavía el IPA
combinado Strata + SideStore. No sustituir una instalación combinada con este
preview sin validar antes el empaquetado y preservar los datos.

## Pruebas pendientes en iPhone
1. Instalar la compilación firmada conservando las extensiones.
2. Abrir A, Inicio, abrir B, Inicio y recuperar A sin reiniciarla.
3. Cambiar la barra arriba/abajo; verificar contenido y toques.
4. Cerrar A y comprobar que B y el launcher siguen abiertos.
5. Cerrar manualmente con reinicio automático activado; no debe reaparecer.
6. Repetir Inicio/abrir rápidamente; revisar ventanas invisibles.
7. Revisar teclado, horizontal, cierre de la última app y errores de lanzamiento.

## Continuar
ZIP con código y session-navigation.patch. Clonar un fork del repositorio base,
crear feature/session-navigation, aplicar git apply al parche y confirmar/subir.
Inicializar los submódulos recursivamente. El ZIP NO contiene un IPA compilado.
