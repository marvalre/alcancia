# Alcancía fase 2 — requisitos

Fecha: 2026-08-26

Extiende `2026-08-26-control-de-gastos-design.md`. Formato compacto a
propósito: se ejecuta en cuatro despachos agrupados con una sola
revisión al final, no tarea por tarea.

La regla del diseño original sigue mandando sobre todo lo demás:

> **Registrar un gasto debe tomar menos de 3 segundos y no requerir
> soltar el teclado.**

## 1. Captura por atajo global

El cuello de botella real: hoy hay que soltar el mouse, subir a la barra
y hacer clic. Lo que toma más de dos pasos para iniciarse no se sostiene.

- Atajo global por defecto **⌥⌘A**, registrado con Carbon
  `RegisterEventHotKey` — funciona sin pedir permisos de accesibilidad,
  a diferencia de un monitor global de `NSEvent`.
- Abre una **ventanita flotante de captura**, no el panel de la barra.
  `MenuBarExtra` no se puede abrir por código desde SwiftUI, y
  reescribirlo a `NSStatusItem` a mano es un riesgo que no vale la pena;
  además una ventana mínima sirve mejor al objetivo de 3 segundos.
- Contenido: campo de monto (enfocado al aparecer), fila de categorías,
  concepto opcional. Enter guarda y cierra. Escape cierra sin guardar.
- `NSPanel` `.nonactivatingPanel`, centrada, nivel `.floating`. Se
  reutiliza el patrón ya probado en `DesktopPanelController`.
- El atajo se registra al arrancar la app y se libera al salir.

## 2. Gastos recurrentes

Adobe, Midjourney, ChatGPT, Figma: sangría mensual predecible que hoy
hay que teclear una por una cada mes. Es exactamente la captura que la
gente deja de hacer.

```swift
public struct RecurringExpense: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String            // "Adobe CC"
    public var amountMXN: Decimal
    public var category: ExpenseCategory
    public var isBusiness: Bool
}
```

- Se guardan en `AlcanciaData.recurringExpenses` (decodificado con
  `decodeIfPresent`, por defecto `[]`).
- **No se registran solas.** Cuando el mes en curso tiene recurrentes sin
  registrar, el panel muestra una banda: "4 suscripciones sin registrar
  este mes · Registrar". Un clic las crea todas con fecha de hoy.
- "Sin registrar" = no existe en el mes un movimiento cuyo `note`
  coincida exactamente con el `name` de la recurrente. Evita duplicados
  sin necesidad de otro campo.
- Se administran desde Ajustes: agregar, editar monto, borrar.

## 3. Gasto de negocio vs personal

- `Entry.isBusiness: Bool` — nuevo, `decodeIfPresent ?? false`.
- Interruptor en la captura rápida, recordado entre capturas igual que
  la categoría (`AlcanciaData.lastUsedIsBusiness`).
- El resumen del mes expone `totalBusinessMXN`, y el encabezado lo
  muestra cuando es mayor que cero: "de negocio: $X".
- No filtra ni divide la vista. Un solo número, para abril.

## 4. Empujón inicial del presupuesto

Sin presupuesto definido, el cerdito es un contorno vacío para siempre y
la metáfora central de la app está dormida. Un usuario nuevo no lo
descubre solo.

- Sin `monthlyBudgetMXN`, el encabezado muestra en su lugar un aviso
  accionable: "Define tu presupuesto mensual para que el cerdito
  funcione · Definir", que abre Ajustes dentro del mismo panel.

## 5. Gráficas y movimiento

Nativo, sin dependencias. **Swift Charts** viene con macOS 13+.

- **Tendencia mensual**: barras de los últimos 6 meses de gasto, con el
  mes en curso resaltado, en la pestaña "Por categoría" debajo del
  desglose. Requiere `MonthlySummary` por mes; agregar un cálculo de
  serie a `AlcanciaCore` (`SpendingTrend`), probado.
- **Movimiento**, todo con las primitivas nativas:
  - Los montos cambian con `.contentTransition(.numericText())` — el
    total rueda dígito por dígito en vez de saltar.
  - Las barras por categoría crecen con resorte al aparecer.
  - La barra de presupuesto anima su avance.
  - Al guardar un movimiento, un remate breve (el monto pulsa) que
    confirma sin robar tiempo.
- Nada de animación que retrase la captura. Si un efecto suma latencia
  percibida al flujo monto → Enter, se corta.

## Fuera de alcance

Exportar CSV, más monedas, conexión bancaria, categorías
personalizadas, presupuesto por categoría.

## Restricciones que siguen vigentes

- macOS 14+, SwiftUI, **sin dependencias externas**.
- Todo campo nuevo se decodifica con `decodeIfPresent` y un valor por
  defecto. Existe un `data.json` real del usuario que debe seguir
  cargando; las dos pruebas guardia no se tocan.
- Cero advertencias de compilación.
- **Ninguna ventana auxiliar desde el panel de la barra de menú.** Ni
  `confirmationDialog`, ni `sheet`, ni `alert`: el panel se cierra al
  perder el foco y se las lleva. Las ventanas del atajo y del escritorio
  son `NSPanel` propias, que es otra cosa.
