# Alcancía — confianza financiera y portabilidad

Fecha: 2026-08-27

## Propósito

Convertir Alcancía en un registro financiero local confiable sin romper su
regla principal: capturar un gasto común debe seguir tomando menos de tres
segundos. El cambio agrega saldo real con continuidad entre meses,
persistencia recuperable, presupuestos históricos correctos, edición,
búsqueda, recurrentes robustos y exportación CSV, JSON y Excel.

## Decisiones aprobadas

- El saldo inicial representa el dinero total que el usuario tiene hoy.
- El primer inicio muestra un onboarding para capturar saldo y presupuesto;
  se puede posponer para no bloquear el registro de gastos.
- Corregir el saldo crea un ajuste fechado en vez de reescribir el pasado.
- El cierre de un mes es automáticamente la apertura del siguiente.
- Los archivos existentes deben migrar sin perder movimientos.
- Todo permanece local y sin telemetría.
- Excel debe ser un `.xlsx` nativo, no un CSV renombrado.

## Modelo financiero

### Ajustes de saldo

`BalanceAdjustment` contiene `id`, `amountMXN`, `date` y una nota opcional.
Su monto es el saldo total declarado en ese instante, no una diferencia.
Para calcular el saldo en una fecha se toma el ajuste más reciente anterior o
igual a esa fecha y se suman ingresos y restan gastos posteriores al ajuste.
Los movimientos anteriores quedan en el historial pero no se cuentan dos
veces.

Sin ajustes, `balanceMXN` conserva el comportamiento anterior (ingresos menos
gastos) para que la migración no cambie cifras silenciosamente. Al crear el
primer ajuste, el saldo pasa a estar anclado en el valor declarado.

El saldo de apertura de un mes se calcula al primer instante del mes. El saldo
de cierre se calcula al primer instante del mes siguiente. No se persisten
snapshots mensuales: editar o borrar un movimiento histórico recalcula todos
los cierres posteriores.

### Presupuesto por mes

Los presupuestos se guardan por una clave estable `YYYY-MM`, calculada con el
calendario gregoriano. El campo legado `monthlyBudgetMXN` se mantiene sólo
para decodificación y migra al mes corriente al cargar. Cambiar un presupuesto
no modifica meses anteriores.

### Recurrentes

Cada movimiento generado por una plantilla guarda `recurringExpenseID` y
`recurringPeriod`. Las omisiones se guardan como pares plantilla/periodo.
La nota deja de usarse como identidad. Dos plantillas pueden compartir nombre
y una captura manual no oculta una suscripción pendiente.

## Persistencia y recuperación

- `AlcanciaData` incorpora `schemaVersion` y decodificación tolerante para
  todos los campos nuevos.
- Cada mutación construye el nuevo estado, intenta guardarlo y sólo entonces
  lo publica en la UI.
- Los métodos mutadores devuelven éxito/error observable.
- Antes de reemplazar `data.json` se mantienen hasta cinco copias rotativas.
- Una carga corrupta conserva el original, intenta el respaldo más reciente y
  expone un estado de recuperación a la interfaz.
- Nunca se inicia silenciosamente con datos vacíos si existe un archivo que no
  pudo decodificarse.
- Los logs usan `Logger` y no incluyen montos, conceptos ni notas.

## Captura y tipo de cambio

- Core rechaza montos no positivos y tasas no positivas o no finitas.
- USD sin tasa explícita o cache válida devuelve error; nunca usa tasa 1.
- La respuesta remota debe ser HTTP 2xx y contener una tasa positiva y finita.
- La captura crea un valor inmutable antes del `await`; mientras resuelve la
  tasa sus controles quedan deshabilitados.
- El parser monetario acepta los separadores de `Locale.current` y los
  formatos habituales de `es_MX` sin convertir `12,50` en `1250`.

## Operación

- El historial permite editar monto, tipo, moneda, categoría, concepto,
  fecha y negocio/personal.
- Cada mutación registra una acción reversible en memoria; “Deshacer” revierte
  la última acción de la sesión y persiste el resultado.
- Búsqueda por concepto y filtros por tipo, categoría y negocio/personal se
  aplican al mes visible.
- El atajo global conserva ⌥⌘A como predeterminado, ofrece combinaciones
  predefinidas y muestra un error si Carbon no puede registrarlo.

## Exportación

La interfaz usa `NSSavePanel`; el exportador no conoce AppKit.

- CSV: movimientos de un rango/mes, UTF-8 con encabezados en español.
- JSON: `AlcanciaData` completo, importable y con fechas ISO-8601.
- Excel `.xlsx`: libro OOXML válido con fuente Arial y cuatro hojas:
  `Movimientos`, `Resumen mensual`, `Ajustes de saldo`, `Recurrentes`.
  Los totales de resumen usan fórmulas compatibles con Excel tradicional.

La generación se prueba como bytes y además se abre con `openpyxl` en una
prueba de integración del artefacto de muestra.

## Interfaz y accesibilidad

- Onboarding inicial: saldo actual, presupuesto del mes y explicación del
  atajo. Puede posponerse.
- Ajustes incorpora saldo actual, “Ajustar saldo”, presupuesto del mes,
  respaldo/recuperación, atajo y exportación.
- Botones de icono reciben etiquetas y pistas accesibles.
- El panel flotante es un `Button` semántico y se recoloca dentro de una
  pantalla visible si cambia la configuración de monitores.
- La gráfica expone mes y monto a VoiceOver.

## Pruebas y compatibilidad

- macOS 14+, Swift tools 5.10, sin dependencias de terceros.
- TDD para cálculos, migraciones, persistencia, parser y exportadores.
- Las pruebas existentes deben continuar pasando.
- Compilaciones debug, release y strict-concurrency deben quedar limpias.
- No se leen ni modifican datos reales durante las pruebas; toda persistencia
  usa directorios temporales.

