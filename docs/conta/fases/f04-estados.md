# Fase 4 · Los estados financieros y la apertura
**12 – 18 oct · 🔵 AZUL el mapeo, la comparación y el esqueleto de `conta.js` · 🟢 VERDE vistas y apertura · ▶ TÚ AUDITAS LA APERTURA**

> La primera prueba de verdad del proyecto — y ahora es cruzable.

## Tú

1. **Para el viernes 9-oct:** que el contador tenga **septiembre cerrado en
   QuickBooks**; la balanza al 30-sep en PDF y CSV; los statements de
   septiembre de cada supply, tarjeta y préstamo; la lista de facturas
   abiertas con su retención por obra (la app la tiene).
2. **Auditar la apertura contra la balanza de QuickBooks, cuenta por cuenta.**
   Si no amarra, no se pasa a la Fase 5. Esto no se negocia. Las diferencias de
   criterio (retención partida a 1120, lo que QuickBooks no modela) quedan
   escritas en la tabla de diferencias.

## 🔵 Azul — se crea (`/effort max`)

El mapeo del mayor a los estados (signos, contra-activos, arrastre: 3900 = 3900
de apertura + resultados de ejercicios cerrados; 3200 de ejercicios cerrados se
pliega a 3900 o se muestra aparte, según el CPA), con etiquetas ES/EN.

**La vista de comparación contra QuickBooks** (balanza importada contra balanza
del app, por cuenta y, si Edgar lleva Customer:Job, por obra) y **la tabla de
diferencias** con clasificación puente/mapeo/criterio y campo de explicación:
las reusan f08, f12, f13-14 y el cierre de enero. Más la vista «auxiliar por
obra = mayor» (5xxx).

Y **el esqueleto de `js/conta.js`** con el patrón de falla ruidosa:
`fn_estado(periodo)` como fila de control; si `cuadra = false` o `filas = 0`
donde el período tiene asientos, la pantalla se niega a pintar y dice cuál.

## 🟢 Verde — se trabaja encima (`/effort auto`)

`c4-estados.sql` como vistas; balanza, comparativos mes contra mes, el clic de
cualquier cifra hasta el asiento.

**La carga del asiento de apertura al 30-sep**: balance únicamente (los
resultados enero–septiembre de 2026 son de QuickBooks), documento = la balanza
en PDF, con dimensión donde hay cédula; 15xx y 1590 como totales hasta que
exista `activos_fijos` (f08); las partidas en tránsito al 30-sep como
conciliación de apertura (f06).

## Entregable
`docs/conta/c4-estados.sql` — todo como vistas. Postgres hace la matemática.

## Terminó cuando

1. Con asientos sintéticos: balanza en cero, activo = pasivo + capital +
   resultado del ejercicio, y un descuadre no entra.
2. El asiento de apertura **cuadra contra la balanza de QuickBooks al 30-sep**
   cuenta por cuenta, con las diferencias de criterio escritas.
3. Las cuentas que alimentan los puentes (4xxx desde `facturas`, 5100 desde
   `recibos`, 5200 desde `trabajos_externos`) del 1 al 15 de octubre suman lo
   mismo en el libro que en las tablas origen, SQL contra SQL.
4. El clic de cualquier cifra llega al asiento.

> La «misma utilidad que QuickBooks» se prueba en la **Fase 8** con octubre
> completo; la auditoría entera, en las Fases 13–14. En la semana 4 todavía no
> hay banco, ni nómina, ni categorización: pedirla aquí era una puerta que
> nadie podía cruzar.

## Lo construido (25-sep) — versión candidata, sin pegar
- `docs/conta/c4-estados.sql` (todo como vistas, 28) y `docs/conta/c4-pruebas.sql`
  (**110 pruebas**; la 109 solo corre en Postgres 17). Balanza (con arrastre y
  «por cerrar»), mayor con saldo corrido y clic al papel, balance general (activo −
  pasivo − capital = 0, 3900 = apertura + años cerrados, 3200 aparte o plegado por
  configuración), resultados (mes, mes anterior, variación, acumulado, ajustes del
  CPA), flujo de caja directo e indirecto (los dos = cambio del efectivo), las
  vistas del tablero (saldos de dinero, antigüedad de CxC y CxP con vencimientos,
  gasto por categoría y proveedor, costo y dinero por obra, flujo real por mes),
  `fn_estados_control` (lo esperado se cuenta desde el libro, no desde las
  vistas), la apertura desde la balanza de QuickBooks (`apertura_balanza_qb`,
  `apertura_mapeo_qb`, `fn_apertura_plan`, `fn_apertura_revisar`, `fn_apertura`:
  1110 por factura, 1120 por obra, 2010 por proveedor, resultado ene–sep a 3900,
  diferencias de criterio anotadas solas) y la comparación por mes
  (`comparacion_qb`, `v_comparacion`, `v_comparacion_obra`, `diferencias`).
- Bloque A del §6b: diseño + 3 rondas de ataque (45, 29 y 24 hallazgos, todos
  verificados; 86 corregidos, 5 rechazados con motivo). Prueba final de cero en
  Postgres 16 y 17.6: c2 80/80, c3 118/118, c4 110/110; idempotente; sin rastro;
  pegado, concurrencia y volumen (10.000 asientos: la vista más lenta 0,63 s) en
  verde. Repetido a mano el 25-sep con el mismo resultado.
- **c2 y c3 cambian (mínimo) y se vuelven a pegar antes de c4:** las policies de
  lectura pasan a `using ((select es_dueno()))` (una llamada por consulta, no por
  fila: las vistas bajan de 0,4–1,7 s a 0,1–0,4 s), marca de versión en su texto
  (c4 la lee al pegarse y avisa si c2 o c3 están viejos), y unos ajustes chicos
  del ataque a c4 (ver sus cabeceras «CAMBIOS PARA c4»). El camino de
  actualización desde la versión de producción se probó en el banco.
- Para conta.js: `fn_estados_control` se llama con la lista de vistas de la
  pantalla (`p_vistas`), no con las 24 de golpe (con 10.000 asientos pasa del
  tope de 8 s de la API).
- Dudas para Edgar y el CPA (del diseñador): la retención en QuickBooks (¿cuenta
  aparte o dentro de A/R?), Undeposited Funds → 1010 como depósito en tránsito,
  las tarjetas que traiga la balanza (dar de alta antes en c1), plegar 3200 al
  cerrar el año, una vista que sume ene–sep de QuickBooks + oct–dic del libro
  para la declaración de 2026, contrato y presupuesto al lado o dentro de
  `v_obras_dinero`.
- **En producción (26-sep):** c2, c3 y c4 pegados por Edgar en ese orden
  (13:50–13:52 UTC), todos en `true`; c2-pruebas y c3-pruebas corridas en el
  editor (sin error); c4-pruebas **110/110 en producción** (leídas de
  `pruebas.c4_resultado`, corrida de las 14:40 UTC, 7 minutos: el SQL Editor
  enseña «Failed to fetch» antes de que termine, y por eso las suites dejan
  ahora su resultado en el esquema `pruebas`). Sin rastro: 0 asientos,
  contadores en 0, ningún periodo cerrado, cadena 10/10, puentes 13/13,
  estados con el único rojo esperado («apertura en el libro»). Pendiente:
  que Edgar corra las versiones nuevas de c2-pruebas y c3-pruebas para que
  su resultado quede registrado, y la apertura real cuando llegue la
  balanza de QuickBooks al 30-sep.

