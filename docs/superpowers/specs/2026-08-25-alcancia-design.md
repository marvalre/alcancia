# Alcancía — diseño

Fecha: 2026-08-25

## Propósito

App de macOS que vive únicamente en la barra de menú (sin icono en el
Dock) para llevar el registro del dinero ganado. El usuario agrega
montos conforme los va ganando; la app mantiene un contador acumulado
guardado localmente. Opcionalmente puede definir una meta, y en ese
caso la app muestra el progreso hacia la meta en vez de solo el total.

## Alcance

- Solo macOS (14+), app nativa SwiftUI, sin backend ni cuenta de
  usuario.
- Todo el almacenamiento es local (archivo JSON en Application
  Support). No hay sincronización entre dispositivos.
- Montos en pesos mexicanos (MXN) como moneda principal. El usuario
  puede registrar una entrada en dólares (USD); la app la convierte a
  MXN usando un tipo de cambio obtenido de internet en el momento de
  agregar la entrada.

## Arquitectura

Mismo patrón que los otros proyectos del repo (`bitacora/`, `ojo/`):
paquete Swift Package Manager con dos targets principales.

```
alcancia/
  Package.swift                (swift-tools-version 5.10, macOS(.v14))
  Sources/
    AlcanciaCore/               <- lógica pura, sin UI, testeable
      Entry.swift
      AlcanciaStore.swift
      ExchangeRateService.swift
      GoalProgress.swift
    Alcancia/                   <- app SwiftUI
      AlcanciaApp.swift
      MenuBarView.swift
      AddEntryView.swift
      HistoryView.swift
      SettingsView.swift
  Tests/
    AlcanciaCoreTests/
      AlcanciaStoreTests.swift
      ExchangeRateServiceTests.swift
      GoalProgressTests.swift
  build_app.sh                  <- empaqueta a Alcancía.app (ad-hoc signed)
  README.md
```

- `AlcanciaCore` no importa SwiftUI; contiene los modelos, la
  persistencia y los cálculos, para poder probarlos con
  `swift test` sin levantar la UI.
- La app ejecutable usa `MenuBarExtra` con `.menuBarExtraStyle(.window)`,
  igual que Bitácora.
- Empaquetado con `build_app.sh` copiando el binario release a
  `Alcancía.app/Contents/MacOS`, generando `Info.plist` con
  `LSUIElement = true` (no aparece en el Dock ni en Cmd+Tab) y firma
  ad-hoc (`codesign --force --deep --sign -`).

## Modelo de datos

```swift
enum Currency: String, Codable { case mxn, usd }

struct Entry: Identifiable, Codable {
    let id: UUID
    var amount: Decimal          // monto tal como lo escribió el usuario
    var currency: Currency
    var amountInMXN: Decimal     // monto ya convertido, lo que se suma al total
    var exchangeRateUsed: Double? // solo si currency == .usd
    var date: Date
}

struct AlcanciaData: Codable {
    var goalMXN: Decimal?
    var entries: [Entry]
    var lastKnownUSDMXNRate: Double?
    var lastKnownRateDate: Date?
    var launchAtLogin: Bool
}
```

Persistencia: JSON (Codable) en
`~/Library/Application Support/Alcancia/data.json`, escritura atómica
(escribir a archivo temporal y hacer `replaceItemAt`), carga al
iniciar. `AlcanciaStore` es un `ObservableObject` que expone
`data: AlcanciaData` y los métodos `addEntry`, `deleteEntry`,
`setGoal`, `clearGoal`, `resetAll`.

Total acumulado = suma de `amountInMXN` de todas las entradas
(calculado, no se guarda por separado, para evitar inconsistencias).

## Tipo de cambio (USD → MXN)

- Servicio `ExchangeRateService` que consulta la API pública y
  gratuita `https://api.frankfurter.app/latest?from=USD&to=MXN` (sin
  API key) cuando el usuario agrega una entrada en USD.
- Si la consulta tiene éxito: se usa esa tasa, y se guarda como
  `lastKnownUSDMXNRate` / `lastKnownRateDate` para futuros respaldos.
- Si falla (sin internet, timeout, error de red):
  - Si hay una tasa guardada previamente, se usa esa y se muestra un
    aviso discreto ("tipo de cambio del <fecha>, sin conexión").
  - Si nunca hubo una tasa guardada, se le pide al usuario que
    escriba manualmente el tipo de cambio para esa entrada.
- El tipo de cambio usado en cada entrada se guarda junto con la
  entrada (`exchangeRateUsed`) para que el historial sea consistente
  aunque el tipo de cambio cambie después.

## Interfaz

**Icono de la barra de menú**: texto compacto en vez de solo un
símbolo — muestra el total acumulado formateado (`$3,240`) si no hay
meta, o el porcentaje de avance (`32%`) si hay meta definida.

**Popover principal** (click en el icono):
- Total acumulado en grande.
- Si hay meta: barra de progreso + texto "$3,240 de $10,000".
- Fila para agregar: campo numérico + selector segmentado MXN/USD +
  botón "Agregar" (también responde a Enter).
- Historial debajo, lista desplazable: fecha, monto original con su
  moneda, y el monto convertido a MXN si aplica. Deslizar o botón para
  borrar una entrada, con confirmación.
- Icono de engrane → abre ajustes.

**Ajustes** (sheet o vista secundaria dentro del popover):
- Definir / editar / quitar la meta (campo numérico en MXN).
- Ver el tipo de cambio actual guardado y su fecha.
- Interruptor "Iniciar con el sistema" usando `SMAppService.mainApp`
  (macOS 13+).
- Botón "Borrar todo el historial" con confirmación (no borra la
  meta ni la preferencia de inicio automático).

## Manejo de errores

- Entrada con texto no numérico o vacío: botón "Agregar" deshabilitado.
- Fallo de red al pedir tipo de cambio: ver sección de tipo de cambio
  arriba (usa respaldo o pide el dato manualmente).
- Fallo al leer/escribir el JSON local (archivo corrupto): se
  respalda el archivo corrupto con sufijo `.corrupt-<timestamp>` y se
  arranca con datos vacíos, sin tronar la app.

## Pruebas

`swift test` sobre `AlcanciaCoreTests`:
- `AlcanciaStoreTests`: agregar entradas en MXN y USD actualiza el
  total correctamente; borrar una entrada la resta del total; el
  total se recalcula sumando entradas (no se corrompe con ediciones
  repetidas); persistencia (guardar y volver a cargar produce los
  mismos datos).
- `ExchangeRateServiceTests`: uso de la tasa guardada cuando la red
  falla; formato de la fecha del respaldo.
- `GoalProgressTests`: cálculo de porcentaje con y sin meta definida,
  incluyendo el caso de superar el 100%.

No hay pruebas de UI automatizadas (igual que en `bitacora/` y
`ojo/`); la verificación de la interfaz se hace manualmente
compilando y abriendo la app.
