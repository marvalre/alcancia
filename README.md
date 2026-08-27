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
- **Atajo global ⌥⌘A** que abre una ventanita mínima de captura desde
  donde estés. Enter guarda, Escape cancela.
- **Presupuesto mensual.** La app te dice cuánto llevas, cuánto queda, y
  se pone roja si te pasas.
- **Cuánto puedes gastar por día** con lo que queda del mes. Convierte un
  saldo abstracto en una decisión que puedes tomar en la taquería.
- **Ocho categorías** con emoji, a un clic: comida, súper, transporte,
  casa, software, ocio, salud, otro.
- **Gastos recurrentes.** Defines tus suscripciones una vez; cada mes la
  app te avisa cuáles faltan por registrar y las anota todas de un clic.
  Nunca las registra sola, para que no aparezcan duplicados.
- **Negocio o personal** por movimiento, para separar lo deducible.
- **Vista por mes** con navegación hacia atrás, desglose por categoría, y
  una gráfica de los últimos seis meses.
- **Ingresos** también, con conversión automática USD→MXN al capturar
  (tipo de cambio en vivo, con respaldo del último conocido si no hay
  internet).
- **Panel flotante** opcional en el escritorio, arrastrable, que recuerda
  dónde lo dejaste. Un clic en él abre la captura rápida.
- **Iniciar con el sistema**, opcional.

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

## Cómo se guarda

Un JSON local en `~/Library/Application Support/Alcancia/data.json`. Sin
telemetría. La única llamada de red es la consulta pública y gratuita del
tipo de cambio USD→MXN (api.frankfurter.app) cuando capturas en dólares.

Los archivos de versiones anteriores se abren sin perder nada: cada campo
nuevo se decodifica con valor por defecto, y los movimientos viejos se
leen como ingresos. Hay dos pruebas dedicadas a eso, porque un fallo ahí
se ve como "la app me borró el dinero".

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

## Cómo correrla

```bash
cd alcancia
./build_app.sh
open "Alcancía.app"
```

Para tenerla siempre a la mano:

```bash
mv "Alcancía.app" /Applications/
```

Pruebas:

```bash
swift test
```

## Compartirla con alguien

Está firmada ad-hoc, no con un certificado de Apple, así que en otra Mac
macOS la bloquea al abrirla. De ese lado hay que quitar la marca de
cuarentena una sola vez:

```bash
xattr -dr com.apple.quarantine "/Applications/Alcancía.app"
```

Mándala por AirDrop y no por WhatsApp: WhatsApp recomprime y se come los
permisos de ejecución, y entonces la app "no se puede abrir" sin decir por
qué. El binario es arm64, así que necesita una Mac con Apple Silicon.
