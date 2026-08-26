# Alcancía

Una app nativa de barra de menú para macOS que lleva el registro del
dinero que vas ganando. Todo local, sin cuenta, sin nube — mismo
espíritu que Bitácora y Ojo en este repo.

## Qué hace

- **Vive en la barra de menú** (sin ícono en el Dock). El ícono
  muestra el total acumulado en pesos, o el porcentaje de avance si
  definiste una meta.
- **Agregar dinero ganado**: escribes un monto en pesos o dólares; si
  es en dólares, se convierte automáticamente a pesos usando el tipo
  de cambio del momento (o el último guardado si no hay internet).
- **Meta opcional**: si defines una meta en pesos, ves una barra de
  progreso y el porcentaje en el ícono. Sin meta, solo ves el total.
- **Historial**: cada entrada queda con su fecha; puedes borrar
  alguna si te equivocaste.
- **Ajustes**: definir/quitar la meta, ver el tipo de cambio guardado,
  borrar todo el historial, e iniciar automáticamente con el sistema.

## Cómo se guarda

Todo en un archivo JSON local en
`~/Library/Application Support/Alcancia/data.json`. Sin telemetría,
sin red — salvo la consulta pública y gratuita del tipo de cambio
USD→MXN (api.frankfurter.app) cuando agregas una entrada en dólares.

## Estructura

```
alcancia/
  Package.swift
  Sources/
    AlcanciaCore/   # modelos, persistencia, tipo de cambio, meta —
                     # sin UI, 100% testeado con `swift test`
    Alcancia/        # la app SwiftUI (MenuBarExtra)
  Tests/
    AlcanciaCoreTests/
  build_app.sh       # empaqueta Alcancía.app firmado ad-hoc
```

## Cómo correrla

Compilarla y empaquetarla:

```bash
cd alcancia
./build_app.sh
open "Alcancía.app"
```

O moverla a `/Applications` para tenerla siempre a mano:

```bash
mv "Alcancía.app" /Applications/
```

Para correr solo los tests:

```bash
swift test
```

Para correr sin empaquetar, mientras desarrollas:

```bash
swift run Alcancia
```
