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

## Guía de diseño (25-sep): el lienzo «Cobre y luz» de Edgar
Edgar hizo en Claude Design un lienzo con la dirección visual de **todas** las
apps de Max Power y tres pantallas de Contabilidad. **No se construye ahora**:
es la guía para cuando toque el acabado de esta fase (y la de f06, f08). El
lienzo vive en https://claude.ai/artifact/7MJhSoqkucdRcRwuALGkQ4 (tipo Design;
sus tableros son archivos `project/*.dc.html`, se leen con la herramienta
Artifact, `action: read` + `path`). Tres páginas: «Propuesta: Cobre y luz»,
«App de Contabilidad (Cuentas)» y «Proceso (versiones anteriores)».

### La idea
**«El cobre es el oficio; la luz es la tecnología.»** El cobre entra como los
cables de la interfaz y como acento; la luz (el gradiente de 96° de la web)
corre por esos cables. Los componentes salen del trabajo real de un
electricista, no de una app genérica. Contabilidad es la **variante Cobre:
misma familia, otro color de mando** (el botón que manda es cobre, no el
gradiente de luz).

### Tokens (los de mxpes.com + el cobre)
| Nombre | Valor | Uso |
|---|---|---|
| ink / ink-2 | `#0b2036` / `#4d6a83` | texto y cifras / texto secundario |
| navy / blue | `#1B3C8C` / `#2A5BD7` | botón sólido en claro / etiquetas, enlaces, foco, serie «entradas» |
| cyan / lime / yellow | `#22E8E0` / `#8CF06A` / `#EFE22E` | solo sobre oscuro: barra, chispa, puntos / estado OK (texto OK `#1E8E4E`) / dinero y pendientes (relleno, texto ink) |
| grad 96° | `#1B3C8C → #2A5BD7 → #22E8E0 → #8CF06A → #EFE22E` | la «luz»: filo de tarjetas, un botón por pantalla en la app operativa |
| **cobre** | `#8F4F1F` (oscuro) · `#B86A2E` · `#C8783A` (medio) · `#E3A06A` (claro) · `#F2C27E` · `#FFE6B0` | cables (`linear-gradient(180deg,#E3A06A,#B86A2E 55%,#8F4F1F)`), etiquetas de sección (`#8F4F1F`, 12 px, 800, tracking .1em), iconos del oficio, anillo del botón secundario, **botón de mando de Contabilidad** (`linear-gradient(96deg,#8F4F1F,#C8783A 55%,#E3A06A)`, texto blanco), serie «salidas» |
| noche | `#071A2E` barra · `#0B1F47`/`#163B8F` tarjeta noche | barra superior, menú lateral, «tarjeta noche» (una por pantalla, con los símbolos ANSI de MX Planos como textura casi invisible) |
| fondo operativo | `#f4f9fd → #e3eef8` con tres auras (cian arriba-izq., azul der., lima abajo) | app de campo y portal |
| **fondo Contabilidad** | `#fbf9f5 → #eee9e1` (papel cálido) con aura cobre; borde `#d9d2c7`; tarjeta blanca | la variante Cobre |
| volt | `#fffce6 → #fff3b3`, borde `#efdc7c`, texto `#5A4300` | lo pendiente y las diferencias |
| tinta / línea (web) | `#d6e7f1`, `#cfe0ee` | bordes y divisores en la operativa |

Letra: **Manrope** (Google Fonts) para todo, `font-variant-numeric: tabular-nums`;
**JetBrains Mono 500/600 para cifras de dinero, fechas, números de cuenta,
permiso, factura y descripciones del banco** (se leen como dato y se copian sin
errores). 800 solo en títulos de pantalla, 700 tarjetas, 600 etiquetas. Cuerpo
17 px (interlínea 1,5), campos y botones 16–17 px con 52–56 px de alto, mínimo
13 px; etiquetas en frase, no en mayúsculas salvo las de sección. Radios: 10
botones, 16–18 tarjetas; sombra suave, nunca bordes duros.

### Reglas para todas las pantallas
- **Una acción principal por pantalla**, abajo y a lo ancho; el «botón vivo»:
  A · Pulso (gradiente quieto con una chispa que lo recorre cada 3 s; al pasar
  el dedo corre más rápido; al terminar se pone verde `#1E8E4E` con check y
  texto nuevo) para la acción principal; B · Anillo (navy sólido con una
  chispa cobre-cian-amarilla girando por el borde) para la secundaria. En
  Contabilidad el Pulso es cobre.
- **Estado = color + texto + icono, nunca solo color.** Solo el estado activo
  late; los demás quietos. Tocar ≥ 44 px. Contraste 4,5:1.
- **Oscuro solo en la barra, el menú lateral, la tarjeta noche y el modo
  noche** (~20 % de la pantalla). Mezcla de tarjetas (noche, volt, blanca,
  tintada): ni todo blanco ni todo oscuro.
- **Hilo con chispa**: bajo la barra, un cable de cobre de 4–6 px con un pulso
  de luz cada 3 s.
- **Etapas como circuito**: nodos encendidos (cian→lima con halo) para lo
  hecho, nodo blanco con borde cian latiendo para lo actual, nodo con borde
  cobre para lo que falta; segmentos de cobre «sin corriente» entre medias.
- **Avance como tablero de breakers** (impares a la izquierda, pares a la
  derecha, barras de cobre al centro, MAIN arriba): en la operativa y el portal.
- Iconos del oficio (breaker, panel, toma, conduit, generador, EV,
  inspección), inline SVG de trazo, nunca emoji.
- «El campo nunca ve dinero» (la app operativa); Contabilidad es «solo Edgar».
- Menú de la app operativa: **3 pestañas abajo** (Hoy · Proyectos · Más),
  recomendada sobre 4.

### Las tres pantallas de Contabilidad
**C1 · Inicio de Cuentas (computadora, 1440×1000)** — menú lateral de 220 px en
`#071A2E` con **borde derecho de cobre de 6 px**, logo «max power» en gradiente
cobre claro + «CUENTAS»; entradas: Inicio · Bancos y tarjetas · Flujo de caja ·
Gastos y categorías · Facturas y cobros · Proyectos (económico) · Estados
financieros · Plan de cuentas y asientos · Cierre de mes; pie «FY 2026 · solo
Edgar». Arriba: etiqueta «INICIO · SEPTIEMBRE 2026», H1 **«Cómo está el
dinero»**, chips Mes / Trimestre / Año, y el botón cobre «Clasificar N
movimientos». Cuatro tarjetas KPI (banco operativo con borde izquierdo cobre,
tarjeta de crédito, por cobrar, por pagar), cifras en mono de 26 px con una
línea de contexto («Conciliado al 31 ago · 37 sin clasificar», «Corte 3 oct ·
autopay activo», «7 facturas · 2 con más de 30 días», «próximo: 30 sep»).
Flujo de caja de 6 meses en barras (entradas azul, salidas cobre) con tres
lecturas debajo: neto de 6 meses, mes más flojo, **cobertura de caja en
semanas de gasto promedio**. Estado de resultados del mes en mini
(Ingresos, materiales, contract labor, utilidad bruta con %, gastos, seguros y
fees, **utilidad neta con % sobre una regla cobre de 2 px**) y chips «P&L
completo · Balance general · Exportar PDF». Gastos por categoría en barras
horizontales con un párrafo de **análisis** en palabras. Proyectos, solo lo
económico (contrato, cobrado, gastado, margen, estado) con «Margen bajo» en
amarillo cuando cae bajo el escenario C del estimador.

**C2 · Clasificar el banco (teléfono, 390×844)** — barra noche con contador
«12 / 37» en mono, cable de cobre, barra de progreso azul→cian. «Una a la
vez. Enter o el botón grande acepta la propuesta.» Tarjeta noche con la fecha
y la cuenta en mono cobre, pastilla «Gasto», **el monto enorme (44 px)**, la
descripción del banco en mono y la regla que aplicó («Regla: Home Depot →
Materiales. Falta saber de qué proyecto.»). Tarjeta blanca «¿De qué proyecto?»
con chips (la obra con visita ese día ya elegida, «Sin proyecto»); «si tomas
foto del recibo, lo adjunta a la PO del proyecto». Abajo: botón cobre Pulso
«Materiales · Barona» (58 px), «Otra cuenta» (anillo) y «Foto del recibo»
(blanco), y el enlace «Saltar · lo veo en la computadora».

**C3 · Cuadrar el mes (iPad, 1180×820)** — barra noche con Proyectos ·
Calendario · **Dinero** · Planos y «AGOSTO 2026 · CHASE ····4412» en mono.
H1 «Agosto: banco contra libros» y el circuito **Importar ✓ → Clasificar ✓ →
Cuadrar · 3 por resolver (late) → Cerrar**. Dos tarjetas lado a lado: «Banco ·
estado de cuenta» (N movimientos) y «Libros · lo que registraste» (N
asientos); cada fila: fecha mono, descripción, monto mono, marcador (check
cian-lima = casado, anillo cobre = sin pareja, amarillo = distinto); las
diferencias en fila volt con su explicación («En el banco, no en libros: falta
clasificar», «Monto distinto: banco −[A], libros −[B]», «Probable: recibo sin
el tax o pago parcial», «Sin asiento · toca para clasificar y cuadra solo»).
Abajo, tarjeta volt «Diferencia [MONTO] · 3 movimientos por resolver… Cuando
la diferencia llega a $0.00 la etapa se enciende y se puede cerrar el mes. Lo
cerrado queda bloqueado; reabrir deja rastro» y el botón cobre apagado «Cerrar
agosto · faltan 3».

### Cómo encaja con lo construido (para el que haga el acabado)
- El lienzo es **acabado**, no estructura: la estructura sigue siendo el
  tablero de la vista previa (arriba) y las vistas de c4. El menú de C1 y el
  de la vista previa casi coinciden; se funden en f05 (C1 no tiene Bandeja ni
  Contador IA; la vista previa no tiene «Plan de cuentas y asientos» aparte).
- C3 es la conciliación de f06 (saldo del banco + partidas en tránsito = saldo
  en libros; la diferencia a $0.00 enciende «Cerrar»); «lo cerrado queda
  bloqueado; reabrir deja rastro» ya es el candado de periodos de c2. C2 es
  la bandeja del banco de f06/f07: propone por regla (`mapeo_*`), propone la
  obra con visita ese día, y la foto del recibo entra por el puente de recibos
  de c3, no por otra vía.
- Las cifras de las tres pantallas son **datos de ejemplo** del lienzo: las
  tarjetas reales son Chase débito ····9420 (1010), Amex Business Gold
  ····2013 y Blue ····2009 (2100-x); no hay Chase Ink. «Chase Chk 4392» es el
  número de cuenta en QuickBooks.
- «Margen = (cobrado − gastado) ÷ contrato» es una definición de caja para el
  tablero; la de f09/f10 es (ingreso − costo) ÷ ingreso, y las dos pueden
  convivir con nombre distinto. Se decide en f09, no en el acabado.
- «Cobertura de caja en semanas» y «mes más flojo» salen de `v_saldos_dinero`
  y `v_flujo_real_por_mes` (c4) más el gasto promedio: una vista o un cálculo
  del esqueleto, con su «esperaba N filas». El chip «Trimestre» necesita que
  `v_resultados` acepte un rango, no solo mes y acumulado (f04, chico).
- Gráficas: la paleta validada de la vista previa (azul / verde, rampa azul
  ordinal) se sustituye por la del lienzo (**entradas azul `#2A5BD7`, salidas
  cobre `#C8783A`**; categorías: azul, cobre, teal `#0FA39A`, morado
  `#8A6BD1`, oro `#B08A00`), validando contraste y daltonismo antes (dataviz).

### Aportes funcionales al lienzo (26-sep)
Edgar: el lienzo es la dirección visual, no el 100 %; lo funcional se puede
sumar. Estos son los aportes desde lo que ya hacen c2, c3 y c4 y lo que piden
f06–f12 y f16–f17. Se deciden en el acabado; ninguno cambia los motores.

**Inicio (C1)**
1. **Cada cifra es una puerta.** Cifra → líneas del libro que la forman →
   papel (foto del ticket, factura, línea del banco) → quién, cuándo y desde
   qué puente entró. Y un indicador de integridad siempre visible («libro:
   cadena íntegra · controles 10/10 · verificado el …»); si un control falla,
   la pantalla lo dice en rojo en vez de pintar ceros (falla ruidosa).
2. **Lo pendiente de todo tipo, no solo el banco:** banco sin clasificar,
   papeles que no entraron al libro (`puentes_bandeja`), tickets sin foto,
   facturas vencidas, diferencias con QuickBooks (en el paralelo), ajustes del
   CPA por aprobar. Un solo lugar con contadores; el botón cobre lleva ahí.
3. **Estado de los meses:** cuáles están cerrados (candado de c2), cuál está
   abierto y qué le falta para cerrar (la lista del punto 15).
4. **Por cobrar separa la retención (1120) y muestra los anticipos de
   clientes como pasivo**, no como cobro; por pagar separa tarjetas (con su
   fecha de corte) de proveedores (2010) con vencimientos.
5. **Reserva de impuestos (1030):** saldo, lo que debería haber según el % del
   CPA sobre la utilidad acumulada, el faltante y la próxima transferencia.
   Y caja chica (1050) con su saldo y último arqueo.
6. **Flujo de caja sin transferencias propias:** el pago de la Amex y el pase
   a la reserva no son salidas. Y «próximos 30 días»: cobros por vencimiento,
   tarjetas por pagar, proveedores, nómina, reserva → caja proyectada.
7. **Proyectos, lo económico completo:** contrato (base + COs firmados),
   **facturado**, cobrado, retención retenida, costo real contra el estimado
   (escenario C), margen; y **«por facturar»: hitos cumplidos en la app
   operativa sin factura emitida** (lo que QuickBooks no hace).
8. **Durante oct–dic, «contra QuickBooks»** (`v_comparacion`): diferencias del
   mes y las anotadas; desaparece al corte.
9. **Inicio compacto en el teléfono** (Edgar quiere ver su P&L ahí), además
   de la pantalla de clasificar.

**Clasificar el banco (C2)**
10. **Primero casar, después clasificar.** La línea del banco se cruza con lo
    que ya está en el libro: el ticket con foto que entró por c3, el cobro de
    una factura, el pago de la tarjeta (transferencia), la nómina de Gusto.
    «HOME DEPOT −$312.40» → «casa con el ticket #123 de Barona (foto), 24-sep»
    → botón **«Confirmar cruce»**. Clasificarlo otra vez como Materiales lo
    mete dos veces. Solo sin ticket: «¿de qué es?» y pide la foto (que entra
    por el puente de recibos, una sola vía).
11. **Opciones por naturaleza, no por cuenta:** cruce con ticket · pago a
    proveedor (cuenta abierta 2010) · pago de tarjeta o transferencia entre
    cuentas · cobro de una factura (elegir cuál; **un depósito nunca va a
    ingreso**) · anticipo de cliente · retiro para Edgar (3200) · caja chica
    (1050) · contratista (1099, con W-9 en `proveedores`) · aporte de Edgar
    (3100) · préstamo. La categoría de gasto solo aparece sin ticket.
12. **Aceptar en bloque lo seguro:** «aceptar 24 cruces exactos» (monto,
    tarjeta, fecha ±3 días); una a una solo las dudosas. Y **deshacer la
    última** (reverso con rastro, `fn_reversar`).
13. **Repartir una línea entre obras** (c3 ya lo permite por foto y obra) y
    **crear regla al corregir** («¿siempre así para HOME DEPOT #6345?») con
    quién y cuándo; las reglas visibles y editables, y nunca postean solas.
14. **Solo con señal:** sin red, la pantalla lo dice y no encola (evita el
    asiento doble). La fecha del banco y la del ticket pueden diferir: mostrar
    las dos cuando no coinciden.

**Cuadrar el mes (C3)**
15. **Conciliación de verdad, no igualdad** (f06): saldo del statement +
    depósitos en tránsito − cargos en circulación = saldo en libros. Hace
    falta **«dejar en tránsito»** con motivo (cheque emitido y no cobrado,
    depósito del 31); esas partidas pasan al mes siguiente y no impiden
    cerrar. Sin esto no se cierra ningún mes con un cheque en la calle.
16. **El statement como ancla:** Edgar escribe el saldo final del statement (o
    adjunta el PDF) y la app lo cruza con lo importado por OFX/Plaid; quedan
    cuenta, mes, saldo, archivo, quién y cuándo (`conciliaciones`). Las
    tarjetas se concilian a su **fecha de corte**, no a fin de mes.
17. **Tres grupos, no dos columnas paralelas:** casados (plegados), solo en el
    banco, solo en libros. Con 112 contra 110 las columnas se desalinean.
18. **«Cerrar el mes» con lista previa:** todas las cuentas conciliadas,
    bandeja vacía o excepciones aceptadas, tickets sin foto resueltos,
    depreciación, prepagados y nómina posteados, transferencia a la reserva
    hecha o ajustada, cadena y controles en verde, comparación con QuickBooks
    revisada. Al cerrar: candado, quién y cuándo, y **el paquete del mes en
    PDF inmutable** (balanza, resultados, balance, conciliaciones) para el
    CPA, el banco o la aseguradora. Reabrir con motivo deja rastro.

**Transversal**
19. **Acceso para el CPA:** solo lectura, proponer ajustes que Edgar aprueba,
    exportar (libro mayor en CSV, balanza, paquete anual de f17), sin el
    login de Edgar. Hoy todo es `es_dueno()`; pide un rol de lectura en las
    policies (chico, en f16).
20. **Avisos:** corte de tarjeta, factura con 30+ días (recordar al cliente
    desde el portal), mes sin cerrar el día 10, estimado de impuestos
    (15-ene), lo sin clasificar el viernes.
21. **El texto de «análisis» (IA, f16) nunca es fuente de una cifra:** va
    marcado como generado y cada frase enlaza a los números que la sostienen.
22. **Pantalla «Acerca del libro»:** versiones pegadas de c1–c4 (sus marcas),
    cadena, controles y últimas verificaciones: el certificado para el auditor.

