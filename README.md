# BloomBox 🌸

### Tu espacio de apps en iPhone, sin complicaciones.

**Instala, organiza, personaliza y abre tus apps desde un solo lugar.** BloomBox es un escritorio alternativo y contenedor de aplicaciones para iOS, con aspecto familiar, accesos directos y herramientas que buscan evitar menús técnicos innecesarios.

> **Nuestra meta:** facilitarle todo al usuario común: instalación de apps, uso de JIT, acceso a tweaks y personalización. Queremos que las funciones complejas trabajen por detrás y que nadie tenga que entender interfaces avanzadas para usar BloomBox.

[![Compilación](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml/badge.svg)](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml)
[![Licencia AGPL-3.0](https://img.shields.io/badge/licencia-AGPL--3.0-blue)](LICENSE)

## ✨ ¿Qué puedes hacer en BloomBox?

| Área | Qué incluye la versión actual |
| --- | --- |
| 🏠 **Escritorio familiar** | Inicio estilo iPhone, Dock, carpetas, biblioteca de apps, búsqueda, páginas y arrastrar iconos para ordenarlos. |
| 📲 **Instalar y administrar apps** | Accesos directos **SideStore** e **Instalar app** desde el escritorio; gestión de apps invitadas mediante LiveContainer. |
| 🎨 **Personalización** | Paneles Liquid Glass, temas claro/oscuro, estilos de iconos **Original, Oscuro, Cristal y Teñido**, colores e iconos de distintos tamaños. |
| 🌌 **Fondos con movimiento** | Fondos GIF o video MP4/MOV en bucle y sin sonido; controles de pausa, encuadre y oscurecimiento. |
| 🧩 **Widgets propios** | Reloj, fotos y notas en distintas páginas, con opciones para añadirlos, moverlos y quitarlos. |
| 📁 **Archivos** | Importar, buscar, previsualizar, crear carpetas, copiar, mover, renombrar, compartir y recuperar archivos de la papelera del espacio propio de BloomBox. |
| 🛠️ **Herramientas y tweaks** | Acceso a la sección de tweaks y a herramientas de administración, sin saturar la pantalla principal. Su disponibilidad y compatibilidad dependen de cada tweak. |
| ⚡ **JIT integrado (experimental)** | Asistente de emparejamiento en el iPhone y preparación de JIT para **apps invitadas**, utilizando LocalDevVPN. |
| ⏳ **Avisos de SideStore (experimental)** | Contador de caducidad en Isla Dinámica desde ocho horas antes, aviso a una hora y prueba manual de tres minutos. |

**Lo importante:** abrir una app, instalar algo o cambiar el fondo debe sentirse como una acción cotidiana, no como configurar una herramienta de desarrollo.

## 🧭 Nuestra filosofía: simple por fuera, potente por dentro

BloomBox se diseña en torno a cinco ideas:

1. **Un toque antes que diez menús.** Acciones como *Instalar app* y *SideStore* deben estar a la vista.
2. **JIT sin enredos.** Un flujo guiado que explique solo lo necesario; los diagnósticos y ajustes avanzados quedan para quien los necesite.
3. **Tweaks más accesibles.** Encontrar, gestionar y entender la compatibilidad de los tweaks sin obligar a navegar por opciones técnicas.
4. **Personalización sin romper nada.** Fondos animados, iconos, widgets, temas y páginas que puedas cambiar o revertir con facilidad.
5. **Cuidar tus apps y tus datos.** Distinguir *Quitar del inicio* de *Desinstalar*, conservar ajustes al actualizar y avisar antes de operaciones riesgosas.

El objetivo no es quitar posibilidades: **es hacerlas fáciles de usar**.

## 📱 Instalación

1. Entra a [GitHub Actions de BloomBox](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml).
2. Abre la compilación **BloomBox - Build** más reciente que aparezca como exitosa.
3. Descarga el artefacto **`BloomBox-SideStore-unsigned.ipa`**.
4. Instala y firma la IPA con SideStore, **conservando las extensiones** incluidas.

> **Antes de actualizar:** respalda tus datos. Si vienes de Manzana, intenta mantener el mismo identificador de app, equipo y cuenta de firma para evitar perder acceso a los datos existentes. La IPA de Actions **no viene firmada**.

## 🧪 Funciones experimentales y límites

- **JIT en el dispositivo:** existe un flujo de emparejamiento y preparación, pero **que la compilación sea exitosa no demuestra que JIT funcione en un iPhone real**. Se debe probar el emparejamiento, LocalDevVPN, la preparación y la ejecución de una app invitada por separado. No activa JIT para aplicaciones instaladas fuera de BloomBox. [Detalles](docs/Manzana-OnDevice-JIT.md).
- **Isla Dinámica:** la actividad de caducidad usa información compartida por SideStore; puede requerir permisos, extensiones conservadas y abrir BloomBox tras renovar. **No renueva ni firma apps automáticamente.** Su comportamiento real sigue en pruebas. [Detalles](docs/Manzana-SideStore-8h-LiveActivity.md).
- **Widgets:** por ahora son widgets propios de BloomBox. **No se pueden insertar directamente los widgets WidgetKit de cualquier app de terceros** ni colocarlos libremente en cada hueco entre iconos. [Detalles](docs/WIDGETS-PAGES-ICON-STYLES.md).
- **Archivos y apps:** BloomBox administra su propio espacio y las apps invitadas; **no sustituye la pantalla de inicio del sistema (SpringBoard)** ni ofrece acceso sin permisos a archivos o apps privadas de iOS. [Detalles](docs/MANZANA-FILES.md).
- **Fondos animados:** los videos se reproducen silenciados y la reproducción se pausa cuando corresponde para limitar consumo. [Detalles](docs/ANIMATED-WALLPAPERS.md).

## 🚀 Hacia dónde vamos

- **Instalación todavía más directa:** reunir importación, instalación, administración y actualizaciones en flujos claros.
- **JIT guiado:** comprobar requisitos, mostrar fallos entendibles y reducir pasos manuales cuando iOS lo permita.
- **Tweaks fáciles de manejar:** explicar requisitos y compatibilidad antes de aplicarlos y facilitar el regreso a una configuración estable.
- **Escritorio más flexible:** widgets en posiciones libres, mejores gestos, organización de páginas y más opciones visuales.
- **Una experiencia para todos:** velocidad, accesibilidad, mensajes sencillos y ajustes avanzados fuera del camino del usuario común.

Estas son **metas**, no funciones que deban considerarse terminadas.

## 🌱 Acerca del proyecto

BloomBox evolucionó de **Manzana** y ahora tiene [su propio repositorio](https://github.com/adri23rep-stack/BloomBox). Conserva bases y componentes derivados de [Strata](https://github.com/huzaifahshahid71-ops/Strata) y [LiveContainer](https://github.com/LiveContainer/LiveContainer), entre otros. No es una aplicación escrita completamente desde cero.

Algunos nombres internos siguen siendo `Manzana`, `Strata` o `LiveContainer` por compatibilidad con código, preferencias y datos anteriores; la aplicación se presenta como **BloomBox**. Consulta [la migración](BLOOMBOX_MIGRATION.md).

**Código abierto · [AGPL-3.0](LICENSE)**. Los componentes de terceros mantienen sus propias licencias; consulta los [créditos y avisos](THIRD_PARTY_NOTICES.md).

---

**BloomBox 🌸 — Menos configuración. Más disfrutar tu iPhone.**
