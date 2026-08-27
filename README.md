# Alcancía

Control de gastos personal que vive en la barra de menú de macOS. Todo
local, sin cuenta, sin nube.

## La regla que manda sobre el diseño

La gente no abandona las apps de gastos por falta de disciplina, sino por
la fricción de capturar. Seis campos y tres menús para un café de $60 es
un mal trato, y se siente para el día nueve. Por eso aquí anotar un gasto
es: **⌥⌘A, escribes el monto, Enter.** Sin tocar el mouse. El campo ya
viene enfocado y la categoría es la última que usaste.

Cualquier función que rompa esa regla se corta, por útil que parezca.

## Qué hace

- **Vive en la barra de menú**, sin ícono en el Dock. El cerdito arranca
  lleno cada mes y se vacía conforme gastas — un vistazo responde "¿cómo
  voy?" sin abrir nada ni leer un número.
- **Atajo global configurable** que abre una ventanita mínima de captura
  desde donde estés. Enter guarda, Escape cancela.
- **Saldo real que continúa entre meses.** En el primer arranque indicas
  cuánto dinero tienes hoy. El cierre de un mes es automáticamente la
  apertura del siguiente, y puedes corregir el saldo total desde Ajustes
  si olvidaste o registraste mal algún movimiento.
- **Presupuesto por mes.** La app te dice cuánto llevas, cuánto queda, y
  se pone roja si te pasas. Cambiar el presupuesto de septiembre no
  modifica agosto.
- **Cuánto puedes gastar por día** con lo que queda del mes. Convierte un
  saldo abstracto en una decisión que puedes tomar en la taquería.
- **Ocho categorías** con emoji, a un clic: comida, súper, transporte,
  casa, software, ocio, salud, otro.
- **Gastos recurrentes.** Defines tus suscripciones una vez; cada mes la
  app te avisa cuáles faltan por registrar. Puedes anotarlas todas de un
  clic u omitir una sólo durante ese mes. Nunca las registra sola y cada
  recurrente conserva una identidad propia para evitar duplicados.
- **Negocio o personal** por movimiento, para separar lo deducible.
- **Vista por mes** con navegación hacia atrás, desglose por categoría, y
  una gráfica de los últimos seis meses.
- **Historial editable**, con búsqueda, filtros por tipo, categoría y
  negocio/personal, además de deshacer después de editar o borrar.
- **Ingresos** también, con conversión automática USD→MXN al capturar
  (tipo de cambio en vivo, con respaldo del último conocido si no hay
  internet).
- **Panel flotante** opcional en el escritorio, arrastrable, que recuerda
  dónde lo dejaste. Un clic en él abre la captura rápida.
- **Iniciar con el sistema**, opcional.
- **Exportación completa** a CSV, JSON y Excel (`.xlsx`) desde Ajustes.
- **Copias de seguridad y recuperación local.** Cada guardado conserva
  hasta cinco respaldos. Si el archivo principal se daña, Alcancía carga
  el respaldo válido más reciente; si ninguno sirve, preserva el archivo
  original y muestra una pantalla de recuperación antes de permitir más
  cambios.

## Sobre el widget

Un widget de verdad de macOS (WidgetKit) necesita una extensión de app y
un App Group para compartir los datos, y eso requiere cuenta de
desarrollador de Apple. Esta máquina no tiene ningún certificado de firma,
así que ese camino está cerrado hoy. El panel flotante del escritorio da
la misma vista siempre visible sin ningún trámite, y además se puede usar
para capturar. La lógica vive separada en `AlcanciaCore`, así que el
widget real se puede agregar después sin rehacer nada.

## Una restricción que se gana su lugar

**Ninguna ventana auxiliar desde el panel de la barra de menú** — ni
`confirmationDialog`, ni `sheet`, ni `alert`. El panel de `MenuBarExtra`
se cierra en cuanto pierde el foco, y se llevaría el diálogo con él: el
usuario ve la confirmación, le pica, y todo desaparece sin borrar nada.
Pasó de verdad. Por eso las confirmaciones son en línea y Ajustes se abre
dentro del mismo panel.

## Privacidad — y cómo comprobarla

Tus movimientos nunca salen de tu Mac. No hay cuenta, no hay servidor, no
hay telemetría, y no hay forma de que alguien más los vea.

El archivo principal se guarda como texto y puedes abrirlo tú mismo:

```bash
cat ~/Library/Application\ Support/Alcancia/data.json
```

La única comunicación de red de la app es consultar el tipo de cambio
USD→MXN en `api.frankfurter.app` (API pública y gratuita, sin llave), y
sólo cuando capturas o editas un movimiento en dólares que necesita una
tasa. No manda tus movimientos: sólo pregunta cuánto vale el dólar. Si
no tienes internet, usa el último tipo de cambio válido que guardó; si no
existe uno, no inventa una conversión y te pide una tasa manual.

No tienes que creerme: es la única URL en el código, y la puedes ver aquí:

```bash
grep -rn "https://" Sources/
```

## Estructura

```
alcancia/
  Package.swift
  Sources/
    AlcanciaCore/   # modelo, presupuesto, resumen mensual, tendencia,
                     # recurrentes, tipo de cambio — sin UI, con pruebas
    Alcancia/        # la app SwiftUI: barra de menú, captura por atajo,
                     # panel de escritorio
  Tests/
    AlcanciaCoreTests/
  build_app.sh       # empaqueta Alcancía.app firmado ad-hoc
```

## Instalación

**Requisitos:** macOS 14 (Sonoma) o más nuevo, en una Mac con Apple
Silicon.

> Guía paso a paso con capturas de pantalla (y video):
> [`Resources/guia-instalacion/INSTALL.md`](Resources/guia-instalacion/INSTALL.md)

### Opción A — descargar la app ya compilada

Bájala de la sección [Releases](https://github.com/marvalre/alcancia/releases),
descomprime, y arrástrala a Aplicaciones. La primera vez macOS la va a
bloquear porque está firmada ad-hoc y no con un certificado de Apple (esos
cuestan $99 USD al año). Se quita así, una sola vez:

```bash
xattr -dr com.apple.quarantine "/Applications/Alcancía.app"
open "/Applications/Alcancía.app"
```

### Opción B — compilarla tú

Necesitas Xcode o las Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/marvalre/alcancia.git
cd alcancia
./build_app.sh
open "Alcancía.app"
```

El script compila en modo release, arma el bundle y lo firma ad-hoc para
que Gatekeeper la deje correr localmente.

### Al abrirla

**No busques una ventana ni un ícono en el Dock: no los tiene.** Es una
app de barra de menú. Busca el cerdito arriba a la derecha, junto al wifi
y la batería.

La primera vez, Alcancía te pide el **saldo total que tienes hoy** y el
presupuesto del mes. Puedes omitirlo y configurarlo después en Ajustes.
El saldo admite cero o deuda y se puede corregir en cualquier momento.

En **Ajustes** también puedes cambiar el atajo global, exportar todos tus
datos en CSV, JSON o Excel y consultar las opciones de recuperación.

## Desarrollo

```bash
swift build          # compilar
swift test           # suite completa de AlcanciaCore
swift run Alcancia   # correr sin empaquetar
```

`AlcanciaCore` no importa SwiftUI: todo el cálculo de dinero, meses,
presupuesto y tendencias vive ahí y se prueba por línea de comandos. La
capa de SwiftUI no lleva pruebas automatizadas — se verifica abriendo la
app.

## Licencia

MIT. Haz lo que quieras con ella.
