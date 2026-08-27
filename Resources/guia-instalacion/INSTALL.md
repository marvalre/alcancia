# Instalar Alcancía

Guía rápida para instalar la app en tu Mac. No necesitas saber programar.

## 1. Descarga el archivo

Descarga `Alcancia-1.0.0-arm64.zip` desde la sección
[Releases](https://github.com/marvalre/alcancia/releases) y ábrelo
haciendo doble clic para descomprimirlo. Vas a obtener `Alcancía.app`.

**Requiere macOS 14 (Sonoma) o más nuevo, en una Mac con Apple Silicon**
(M1 o más nueva). Si tu Mac es Intel, no va a abrir.

## 2. Muévela a Aplicaciones

Arrastra `Alcancía.app` a tu carpeta **Aplicaciones**.

## 3. Autorízala la primera vez

Como esta app no viene de la App Store ni de un desarrollador pagado de
Apple, macOS la bloquea la primera vez con este aviso. Es normal en
software de código abierto — significa que nadie le pagó $99 USD al año
a Apple por un certificado, no que algo esté mal.

![Aviso de macOS bloqueando la app](1-bloqueo-inicial.png)

Pulsa **Done** (no la borres) y sigue estos pasos:

1. Abre **Ajustes del Sistema → Privacidad y Seguridad**.
2. Baja hasta el final, a la sección **Security**. Ahí aparece
   *"Alcancía was blocked to protect your Mac"* con un botón
   **Open Anyway**.

   ![Sección de Seguridad con el botón Open Anyway](2-ajustes-seguridad.png)

3. Púlsalo. Te va a pedir confirmar una vez más — esta vez con un botón
   azul de **"Move to Trash"** arriba y **"Open Anyway"** abajo. Fíjate
   bien cuál tocas: el azul es el que borra la app.

   ![Confirmación final para abrir la app](3-abrir-de-todos-modos.png)

4. Confirma con tu contraseña o Touch ID si te lo pide.
5. Abre `Alcancía.app` otra vez (desde Aplicaciones o Spotlight). Ya
   funciona, y de aquí en adelante abre normal con doble clic.

## 4. Búscala en el lugar correcto

**No es una ventana ni tiene ícono en el Dock — es una app de barra de
menú.** Busca el cerdito arriba a la derecha, junto al wifi y la
batería.

![La app funcionando: captura rápida, categorías, historial](4-app-funcionando.png)

La primera vez, Alcancía te pregunta cuál es tu **saldo total hoy** y el
presupuesto del mes. Ese saldo es la base: ingresos y gastos se aplican a
partir de ahí, y el cierre de cada mes pasa al siguiente. Puedes omitir
este paso o corregir el saldo después desde **Ajustes**.

Para capturar un gasto sin tocar el mouse: **⌥⌘A** desde cualquier
parte del sistema. Puedes cambiar esa combinación en **Ajustes**.

Desde **Ajustes** también puedes exportar una copia completa en CSV,
JSON o Excel (`.xlsx`). Alcancía mantiene hasta cinco respaldos locales y
te guía para recuperar el último válido si detecta datos dañados.

## Permisos que te va a pedir

| Cuándo aparece | Para qué es |
|---|---|
| Al activar "Iniciar con el sistema" | Elementos de inicio — para que abra sola al prender la Mac |
| Al usar el atajo global | Ninguno — usa un atajo de teclado clásico (Carbon), no necesita permiso de Accesibilidad |

Todo se procesa **en tu Mac**. La única comunicación de red de Alcancía
es consultar el tipo de cambio del dólar cuando un movimiento en USD lo
necesita (`api.frankfurter.app`, pública, sin cuenta ni llave). No manda
tus movimientos a ningún lado — puedes comprobarlo leyendo el archivo
donde se guardan:

```bash
cat ~/Library/Application\ Support/Alcancia/data.json
```

## ¿Problemas?

- **"Alcancía no se puede abrir porque no se puede verificar"** →
  repite el paso 3.
- **No aparece nada en la barra de menú** → revisa en el Monitor de
  Actividad que "Alcancia" esté corriendo; si no, ábrela de nuevo desde
  Aplicaciones.
- **El atajo no responde** → prueba otra combinación en Ajustes; la app
  muestra si macOS no pudo registrarla porque otra aplicación ya la usa.
- **Alcancía detectó datos dañados** → no sobrescribe el original. Usa la
  pantalla de recuperación para restaurar el respaldo válido más reciente
  o exportar/conservar el archivo antes de decidir qué hacer.
