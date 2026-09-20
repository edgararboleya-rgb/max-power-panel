# Fase 5 · La primera pantalla
**19 – 25 oct · 🔵 AZUL el esqueleto · 🟢 VERDE las pantallas**

## Tú
Abrirla y decir qué falta.

## 🔵 Fable
El esqueleto de `js/conta.js` y **el patrón de falla ruidosa**: toda consulta
financiera declara cuántas filas esperaba, y cero donde debería haber datos
**detiene la pantalla** en vez de dibujar un cero. Es lo contrario del
`.catch(() => [])` que la app usa 48 veces — bien para la obra, veneno para
la contabilidad.

## 🟢 Opus
Balanza y P&L colgados de ese esqueleto, con el clic hasta el asiento y del
asiento al recibo con su foto. Parche mínimo a `index.html` y `sw.js`
(subir versión) y una línea en `app.js`.

## Entregable
`js/conta.js` · parches chicos a los compartidos, según `PUBLICAR.md`

## Terminó cuando
Ves tu P&L en el teléfono, y si desconectas una tabla a propósito la pantalla
**te lo dice** en vez de enseñar ceros.
