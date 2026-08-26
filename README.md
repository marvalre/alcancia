# Alcancía

Control de gastos personal que vive en la barra de menú de macOS. Todo
local, sin cuenta, sin nube.

## La regla que manda sobre el diseño

La razón por la que la gente abandona las apps de gastos no es la falta
de disciplina: es la fricción de capturar. Seis campos y tres menús para
un café de $60 es un mal trato, y se siente para el día nueve. Por eso
aquí registrar un gasto es: clic al cerdito, escribir el monto, Enter.
El campo ya viene enfocado y la categoría es la última que usaste.

## Qué hace

- **Vive en la barra de menú** (sin ícono en el Dock). El ícono es un
  cerdito que **arranca lleno cada mes y se vacía conforme gastas** — un
  vistazo responde "¿cómo voy?" sin abrir nada.
- **Presupuesto mensual.** Defines cuánto te permites gastar; la app te
  dice cuánto llevas y cuánto te queda, y se pone roja si te pasas.
- **Ocho categorías** con emoji, a un clic: comida, súper, transporte,
  casa, software, ocio, salud, otro.
- **Concepto libre** opcional en cada movimiento ("Uber", "Adobe").
- **Vista por mes** con navegación hacia atrás, y desglose de en qué se
  te fue el dinero.
- **Ingresos** también, con conversión automática USD→MXN al capturar
  (tipo de cambio en vivo, con respaldo del último conocido si no hay
  internet).
- **Panel flotante** opcional en el escritorio, arrastrable, que recuerda
  dónde lo dejaste.
- **Iniciar con el sistema**, opcional.

## Sobre el widget

Un widget de verdad de macOS (WidgetKit) necesita una extensión de app y
un App Group para compartir los datos, y eso requiere cuenta de
desarrollador de Apple. Mientras no la haya, el panel flotante del
escritorio da la misma vista siempre visible sin ningún trámite. La
lógica vive separada en `AlcanciaCore`, así que el widget real se puede
agregar después sin rehacer nada.

## Cómo se guarda

Un JSON local en `~/Library/Application Support/Alcancia/data.json`. Sin
telemetría. La única llamada de red es la consulta pública y gratuita del
tipo de cambio USD→MXN (api.frankfurter.app) cuando capturas en dólares.

Los archivos de versiones anteriores se abren sin perder nada: cada campo
nuevo se decodifica con valor por defecto, y los movimientos viejos se
leen como ingresos.

## Estructura

```
alcancia/
  Package.swift
  Sources/
    AlcanciaCore/   # modelo, presupuesto, resumen mensual, tipo de cambio —
                     # sin UI, cubierto por pruebas
    Alcancia/        # la app SwiftUI (MenuBarExtra + panel flotante)
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
