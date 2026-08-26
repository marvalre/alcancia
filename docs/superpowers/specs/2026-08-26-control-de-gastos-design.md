# Alcancía como app de control de gastos — diseño

Fecha: 2026-08-26

Reemplaza el enfoque del diseño original
(`2026-08-25-alcancia-design.md`), que rastreaba solo dinero ganado
contra una meta de ahorro. La app conserva su forma (barra de menú,
almacenamiento local, cerdito) pero cambia su centro de gravedad al
control de gastos.

## Por qué este rediseño

La investigación sobre apps de gastos apunta a una sola causa de
fracaso: **la fricción de captura**. La mayoría de la gente que empieza
a registrar gastos lo abandona dentro del primer mes, y casi nunca por
falta de motivación — es que capturar toma demasiado. Seis campos y tres
menús desplegables para un café de $60 es un mal trato, y se siente para
el día nueve. Los comportamientos que requieren más de dos pasos para
iniciarse no se sostienen.

El contrapeso: la captura manual produce **más** cambio de
comportamiento que la importación automática, porque escribir el monto
obliga a una pausa de dos segundos en la que notas lo que acabas de
hacer. Ese es el mecanismo que hace que sirva.

De ahí la única regla de diseño que manda sobre todas las demás:

> **Registrar un gasto debe tomar menos de 3 segundos y no requerir
> soltar el teclado.**

Cualquier función que viole esa regla se corta, por útil que parezca.
Una app de barra de menú es el vehículo ideal: ya está a un clic de
distancia desde cualquier lado.

## Qué es la app

Un control de gastos personal, local, que vive en la barra de menú.

- **Presupuesto mensual.** Defines cuánto te permites gastar al mes. Es
  el número central de la app.
- **El cerdito muestra lo que te queda.** Arranca lleno cada mes y se va
  vaciando conforme gastas. Un vistazo a la barra de menú responde "¿cómo
  voy este mes?" sin abrir nada ni leer un número.
- **Captura en tres segundos.** Clic al cerdito → el campo de monto ya
  está enfocado → escribes el monto → Enter. Listo. La categoría es la
  última que usaste; cambiarla es un clic opcional.
- **Categorías.** Ocho fijas, con emoji, elegibles con un clic.
- **Vista del mes.** Cuánto llevas gastado, contra el presupuesto,
  desglosado por categoría, con navegación entre meses.
- **Ingresos siguen existiendo**, como movimiento secundario, con la
  conversión USD→MXN que ya funciona. No afectan el presupuesto ni el
  cerdito: el presupuesto es sobre gasto.

## Alcance

- Solo macOS 14+, SwiftUI, sin dependencias externas.
- Todo local en `~/Library/Application Support/Alcancia/data.json`.
- Moneda base MXN; los movimientos en USD se convierten al capturarlos
  (comportamiento existente, sin cambios).

## Modelo de datos

```swift
public enum EntryKind: String, Codable { case expense, income }

public enum ExpenseCategory: String, Codable, CaseIterable {
    // No se llama `Category` a secas porque `objc/runtime.h` ya declara
    // su propio typedef `Category`, y el nombre corto queda ambiguo en
    // cualquier archivo que importe SwiftUI y AlcanciaCore a la vez.
    case comida, mercado, transporte, casa, software, ocio, salud, otro
    // Cada una expone `emoji` y `label` en español.
}

public struct Entry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amount: Decimal          // como lo escribió el usuario
    public var currency: Currency
    public var amountInMXN: Decimal     // convertido, lo que cuenta
    public var exchangeRateUsed: Double?
    public var date: Date
    public var kind: EntryKind          // NUEVO
    public var category: ExpenseCategory?      // NUEVO — nil en ingresos
    public var note: String?            // NUEVO — concepto libre, corto
}

public struct AlcanciaData: Codable {
    public var monthlyBudgetMXN: Decimal?   // NUEVO — reemplaza goalMXN
    public var entries: [Entry]
    public var lastKnownUSDMXNRate: Double?
    public var lastKnownRateDate: Date?
    public var launchAtLogin: Bool
    public var lastUsedCategory: ExpenseCategory?  // NUEVO — para captura rápida
    public var showsDesktopPanel: Bool      // NUEVO
    public var desktopPanelOrigin: [Double]? // NUEVO — [x, y] recordado
}
```

### Migración de archivos existentes — requisito crítico

Un `data.json` escrito por la versión anterior no tiene `kind`,
`category`, `note`, `monthlyBudgetMXN`, `lastUsedCategory`,
`showsDesktopPanel` ni `desktopPanelOrigin`. Si el decodificador falla
con esos archivos, `AlcanciaStore.load` los trata como corruptos, los
mueve a un respaldo y arranca vacío — al usuario le parece que **la app
le borró su dinero**.

Por lo tanto:

- `Entry` y `AlcanciaData` implementan `init(from decoder:)` explícito
  usando `decodeIfPresent` con valor por defecto para **todo** campo
  agregado después de la primera versión.
- Los movimientos existentes se leen como `kind: .income` — la versión
  anterior solo registraba dinero ganado — con `category: nil` y
  `note: nil`.
- `goalMXN` desaparece de la estructura. `JSONDecoder` ignora las llaves
  que sobran, así que los archivos viejos siguen cargando; lo único que
  se pierde es el valor de la meta de ahorro, que ya no tiene lugar en
  esta versión.
- Esto se prueba con un test que decodifica una cadena JSON con el
  formato viejo, literal, y verifica que los movimientos sobreviven.

Regla permanente para el futuro: **todo campo nuevo se decodifica con
`decodeIfPresent` y un valor por defecto.** No hay excepción.

## Presupuesto y cerdito

`BudgetProgress` (reemplaza a `GoalProgress`) es un cálculo puro:

```swift
public struct BudgetProgress {
    public init(spentMXN: Decimal, budgetMXN: Decimal?)
    public var remainingMXN: Decimal?   // puede ser negativa (te pasaste)
    public var fractionRemaining: Double? // 0...1, para el cerdito
    public var isOverBudget: Bool
    public var percentSpentText: String?
}
```

- `fractionRemaining` = `(presupuesto − gastado) / presupuesto`,
  **acotada a 0...1 por ambos extremos**. Sin presupuesto devuelve `nil`.
- El cerdito de la barra de menú recibe esa fracción: lleno al inicio del
  mes, vacío cuando se acabó. Sin presupuesto queda como contorno.
- Si te pasaste del presupuesto, `fractionRemaining` es 0 (cerdito
  vacío) y `isOverBudget` es true, que la interfaz muestra en rojo.

`PiggyBankIcon` no cambia: ya recibe una fracción opcional y se rellena
con ella. Solo cambia lo que esa fracción significa.

Los cálculos de `BudgetProgress` deben acotar antes de convertir a
`Int` — el defecto que ya se corrigió una vez en `GoalProgress`, donde
un presupuesto absurdamente chico desbordaba `Int` y tiraba la app en un
ciclo de arranque.

## Resumen mensual

`MonthlySummary` es un cálculo puro sobre una lista de movimientos:

```swift
public struct MonthlySummary {
    public init(entries: [Entry], month: Date, calendar: Calendar = .current)
    public var totalSpentMXN: Decimal
    public var totalIncomeMXN: Decimal
    public var byCategory: [CategoryTotal]  // ordenado de mayor a menor,
                                            // solo categorías con gasto
    public var entriesInMonth: [Entry]      // más reciente primero
}

public struct CategoryTotal { let category: ExpenseCategory; let amountMXN: Decimal;
                              let fractionOfTotal: Double }
```

Vive en `AlcanciaCore`, sin dependencia de la interfaz, y se prueba
directo: meses con y sin movimientos, movimientos en el límite del mes
(último instante del mes anterior, primer instante del siguiente), y que
los ingresos no contaminen el total gastado.

## Interfaz

**Ícono de la barra de menú:** el cerdito, relleno según lo que queda
del presupuesto. Sin texto, sin signo de pesos.

**Popover (360 × 540), en este orden:**

1. **Cabecera del mes.** `‹ Agosto 2026 ›` para navegar. Debajo:
   "Gastaste $4,320 de $8,000" con barra de progreso. Si te pasaste, en
   rojo: "Te pasaste por $320".
2. **Captura rápida.** Campo de monto **enfocado automáticamente al
   abrir el popover** — esta es la pieza que hace o rompe la app.
   Escribes el monto, Enter, guardado. A la derecha, un selector
   `Gasto / Ingreso` (arranca en Gasto) y el selector MXN/USD existente.
   Debajo, campo opcional de concepto.
3. **Fila de categorías.** Ocho emojis en fila; el activo se resalta.
   Arranca en la última categoría usada. Un clic la cambia. Enter guarda
   con la que esté activa.
4. **Selector de vista.** `Movimientos` | `Por categoría`.
   - *Movimientos*: lista del mes — emoji, concepto, fecha, monto con
     signo (− gasto, + ingreso); el gasto va en el color normal del
     texto y el ingreso en verde, porque en una app de gastos casi toda
     fila es un gasto y pintarlas todas de rojo no aporta señal. Botón
     de borrar con confirmación.
   - *Por categoría*: una fila por categoría con gasto — emoji, nombre,
     monto, y una barra proporcional al total del mes.
5. **Pie.** Engrane (ajustes) y Salir.

**Ajustes:** presupuesto mensual, tipo de cambio guardado, iniciar con
el sistema, mostrar panel de escritorio, borrar todo el historial (con
confirmación).

La navegación entre meses solo cambia lo que se muestra; la captura
rápida siempre registra en la fecha de hoy, sin importar qué mes estés
viendo. Es lo que espera cualquiera que abra la app para anotar un gasto
que acaba de hacer.

## Panel de escritorio

Responde a la pregunta de "¿y que también sea widget?". Un widget real
de macOS (WidgetKit) necesita una extensión de app y, para leer los
datos, un App Group — que requiere cuenta de desarrollador de Apple y
migrar el proyecto a Xcode. Esta máquina no tiene ningún certificado de
firma, así que ese camino está cerrado hoy.

Lo que sí funciona sin trámite y da la misma sensación: un `NSPanel`
flotante, sin bordes, que muestra el cerdito y lo que queda del
presupuesto.

- Nivel `.statusBar`, sin barra de título, fondo translúcido, esquinas
  redondeadas.
- Se prende y apaga desde Ajustes.
- Arrastrable; recuerda su posición en `desktopPanelOrigin` y la
  restaura al abrir.
- No aparece en el Dock ni en Cmd+Tab (la app ya es `LSUIElement`).
- Clic en el panel abre el popover de la barra de menú.

Si algún día hay cuenta de desarrollador, el widget real se puede
agregar sin rehacer nada: toda la lógica ya vive en `AlcanciaCore`,
separada de la presentación.

## Estructura de archivos

```
Sources/
  AlcanciaCore/
    Entry.swift              (Entry, Currency, EntryKind — decodificación tolerante)
    ExpenseCategory.swift    (NUEVO — enum con emoji y etiqueta)
    BudgetProgress.swift     (NUEVO — reemplaza GoalProgress.swift)
    MonthlySummary.swift     (NUEVO — totales del mes y desglose)
    AlcanciaStore.swift      (presupuesto, categorías, consultas por mes)
    ExchangeRateService.swift (sin cambios)
  Alcancia/
    AlcanciaAppMain.swift    (cerdito según presupuesto restante)
    MenuBarView.swift        (recompuesto)
    MonthHeaderView.swift    (NUEVO — navegación de mes + barra de presupuesto)
    QuickAddView.swift       (reemplaza AddEntryView — enfoque automático)
    CategoryRowView.swift    (NUEVO — fila de emojis)
    CategoryBreakdownView.swift (NUEVO — desglose)
    HistoryView.swift        (categoría, concepto, signo y color)
    SettingsView.swift       (presupuesto en vez de meta, panel de escritorio)
    DesktopPanelController.swift (NUEVO — NSPanel flotante)
    DesktopPanelView.swift   (NUEVO — contenido del panel)
    PiggyBankIcon.swift      (sin cambios)
    LoginItemManager.swift   (sin cambios)
```

## Pruebas

Sobre `AlcanciaCore`, con `swift test`:

- **Migración** (la más importante): un `data.json` con el formato viejo,
  escrito literal en el test, se decodifica sin perder movimientos, y
  esos movimientos quedan como ingresos sin categoría.
- **`MonthlySummary`**: totales de gasto e ingreso separados; desglose por
  categoría ordenado de mayor a menor; movimientos en el borde exacto del
  mes; mes vacío.
- **`BudgetProgress`**: sin presupuesto; a la mitad; presupuesto agotado
  exacto; pasado del presupuesto (fracción 0, `isOverBudget`); presupuesto
  absurdamente pequeño que no debe desbordar ni tirar la app.
- **`AlcanciaStore`**: agregar gasto e ingreso afecta los totales
  correctos; `lastUsedCategory` se recuerda; borrar un movimiento;
  persistencia de ida y vuelta; archivo corrupto no tira la app.

Las vistas de SwiftUI no llevan pruebas automatizadas, igual que en
`bitacora/` y `ojo/`. Se verifican compilando y abriendo la app.

## Lo que queda fuera a propósito

Sin categorías personalizadas, sin gastos recurrentes, sin importar
estados de cuenta, sin gráficas de tendencia, sin exportar, sin
sincronización, sin múltiples cuentas. Cada una de esas agrega campos al
momento de captura o pantallas que mantener, y ninguna se gana su lugar
antes de saber que la app se usa a diario.
