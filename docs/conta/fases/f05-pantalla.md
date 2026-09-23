# Fase 5 · La primera pantalla
**Esqueleto en la semana 4 (12–18 oct) · pantallas en la semana 5 (19–25 oct)**
**🔵 AZUL el esqueleto (dentro de f04) · 🟢 VERDE las pantallas**

> Se solapa con las fases 4 y 6: el esqueleto no depende de que el balance
> cuadre, y el verde solo necesita las vistas. Ahí está la semana que se gana.

## Tú
Abrirla y decir qué falta.

## 🔵 Azul — se crea (`/effort max`) *(en la semana 4, con f04)*
El esqueleto de `js/conta.js` y **el patrón de falla ruidosa**: toda consulta
financiera declara cuántas filas esperaba, y cero donde debería haber datos
**detiene la pantalla** en vez de dibujar un cero. Es lo contrario del
`.catch(() => [])` que la app usa 48 veces — bien para la obra, veneno para la
contabilidad.

## 🟢 Verde — se trabaja encima (`/effort auto`)
- Balanza y P&L colgados del esqueleto, con el clic hasta el asiento y del
  asiento al recibo con su foto.
- **`conta.js` es solo-online**: si `navigator.onLine` es falso o la primera
  lectura falla por red, muestra «Sin señal» y no pinta nada (copiar
  `esFalloDeRed` y `llaveUnica`, que viven dentro del cierre de `app.js`).
- **Los montos se mandan a la base como texto** `"1234.56"`, tomados del input
  o de lo que devolvió Postgres, **nunca de una operación en JS**; para
  mostrar, `Intl.NumberFormat`.
- El botón de contabilidad se esconde por rol como `btn-levantamiento`
  (`app.js:433`); la protección de verdad es la base.
- Parche a `index.html` y `sw.js` (versión), una línea en `app.js`, y el parche
  de tres líneas a `db.js` (`_api/_leer/_rpc`) decidido en f02 y anotado en
  `PUBLICAR.md`.
- **Las pantallas con cifras no se publican hasta que la auditoría de la
  apertura (f04) amarre.**

## Entregable
`js/conta.js` · parches chicos a los compartidos, según `PUBLICAR.md`

## Terminó cuando
Ves tu P&L en el teléfono; si desconectas una tabla a propósito la pantalla
**te lo dice** en vez de enseñar ceros; y **un trabajador con su login no ve ni
el botón ni una fila**.
