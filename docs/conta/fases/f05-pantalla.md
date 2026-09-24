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

## Vista previa (24-sep) y el cambio de rumbo de esta fase
La primera vista previa (bandeja + balanza + resultados + libro en pestañas)
le pareció a Edgar demasiado básica: **quiere un tablero al estilo
QuickBooks**, con el menú a la izquierda. La segunda versión,
`docs/conta/f05-vista-previa.html`, es la referencia de diseño de esta fase:

- **Panel** (lo primero que se abre): efectivo con su tendencia, por cobrar
  con antigüedad, por pagar con vencimientos, utilidad del mes contra
  QuickBooks; flujo de caja de 6 meses y los próximos 30 días; la bandeja; en
  qué se gasta; bancos y tarjetas con su conciliación; dinero por obra
  (contrato, facturado, cobrado, costo real contra estimado, margen); el
  contador (IA); la reserva de impuestos.
- **Menú izquierdo** (cajón en el teléfono): Panel · Bandeja · Estados
  financieros (Resultados, Balance general, Flujo de caja, Balanza y libro)
  · Dinero (Bancos y tarjetas, Por cobrar, Por pagar) · Operación
  (Proyectos, Gastos, Nómina, Impuestos) · Control (Contador IA, Cierre).
- Cada cifra baja al asiento y del asiento al papel con su foto.

**Qué cambia en el plan.** El motor (c1, c2, c3) alimenta cada uno de esos
paneles sin cambios: el tablero lee el mismo libro. Lo que hay que ordenar:
- **f04** define, además de los estados, las **vistas de lectura del tablero**
  (saldos de banco y tarjeta, antigüedad de CxC y CxP, gasto por categoría y
  por proveedor, costo por obra, flujo de caja real por mes) con su
  «esperaba N filas».
- **f05** construye el Panel, el menú y las pantallas de lectura que ya tienen
  datos en su fecha (Bandeja, Resultados, Balance, Balanza y libro, Por
  cobrar, Por pagar, Gastos, Proyectos). Bancos y Flujo de caja se llenan con
  f06; Nómina con f11; Impuestos con f08/f12/f17; el Contador con f16. Hasta
  entonces, cada panel dice de dónde vendrá su dato y no pinta ceros.
- Las cifras no se publican hasta que la apertura amarre (f04), igual.
- Estimado: la fase crece de una semana a dos (el esqueleto azul no cambia;
  crece el verde). Se absorbe con el buffer de la semana 12.

Gráficas con la paleta validada para daltonismo (dos series: azul y verde;
antigüedad en una rampa azul ordinal), tooltips al pasar, tablas para lo que
es tabla.
