# Banco de pruebas local de la contabilidad

Un Postgres local que se comporta como el Supabase de producción en lo que
importa para los libros: roles, RLS, privilegios por defecto, `auth.uid()` y
las tablas y triggers reales. Aquí se prueban los `docs/conta/c*.sql` **antes**
de que Edgar los pegue. **Nunca** se conecta a `*.supabase.co`.

| Archivo | Qué es |
|---|---|
| `00-shim-supabase.sql` | Lo que Supabase trae de fábrica: roles `anon`, `authenticated`, `service_role` y `editor_sql`; esquemas `auth`, `extensions` (pgcrypto, uuid-ossp) y `net` (stub); privilegios por defecto. Lo corre el superusuario. |
| `01-replica-esquema.sql` | Las 21 tablas que tocan los libros, con columnas **idénticas** a producción (generadas desde `esquema-columnas-23sep.json`), `es_dueno()`, `es_activo()`, los triggers existentes, RLS con las policies reales y la vista `recibos_equipo`. |
| `02-semilla.sql` | Datos de prueba con ids fijos (abajo), con valores que producción admite. |
| `02b-restricciones-produccion.sql` | Lo que producción tiene y el banco no tenía, leído el 24-sep: las `id` GENERATED ALWAYS de 13 tablas, los CHECK de valores (recibos: 7 categorías y 5 formas de pago; horas: más de 0 y hasta 16), el UNIQUE de facturas y las llaves foráneas. `correr.sh` lo carga después de la semilla. |
| `c0-banco-pruebas.sql` | El banco se prueba a sí mismo: 18 comprobaciones. **También es el molde** para los `c*-pruebas.sql`. |
| `correr.sh` | Crea una base, carga 00-01-02 y los archivos que le pases. |
| `c2-concurrencia.sh` | Lo que `c2-pruebas.sql` no puede probar en una sola sesión: varias sesiones a la vez contra el libro (cierres con posteos en vuelo, ráfagas, una línea tardía, un cierre en repeatable read). La mitad de los posteos confirma como la app (rol `authenticated`). |
| `c2-pegado.sh` | Lo que pasa AL PEGAR: el bloque A solo, el B encima de datos sucios, las pruebas antes que el libro, volver a pegar c1 y c2, la 7200. |
| `03-storage-simulacro.sql` | Un Storage mínimo (`storage.objects` con RLS y las policies de hoy según ESQUEMA-REAL). **Solo del banco**: con él, la prueba 45 de `c3-pruebas.sql` (el papel no se borra) corre de verdad; sin él sale «omitida». Se pasa ANTES de c3. |
| `c3-concurrencia.sh` | Lo que `c3-pruebas.sql` no puede probar en una sola sesión: el mismo recibo corregido desde dos teléfonos, el backfill mientras alguien guarda, diez recibos a la vez, dos backfills a la vez, dos cobros a la vez a la misma factura (también con su número escrito de otra forma: « 951», «+951»), un cobro mientras se anula la factura, dos anticipos a la vez y dos lecturas del mismo ticket que confirman juntas (entra una; la otra espera como duplicado). Cada sesión confirma (los puentes son diferidos). Sus recibos llevan `creado` de octubre: el reloj del banco es de antes del corte, y un recibo subido antes del corte no entra al libro. |
| `c3-pegado.sh` | Lo que pasa al VOLVER a pegar c3-puentes.sql con las reglas ya tocadas por Edgar: dos pegados seguidos, y otro después de retirar una cuenta que un valor de arranque usaba (la 5600, con su regla ya en la 5500) y de darle a un papel la cuenta que otro tenía de arranque. No se cae, y lo que Edgar puso se queda. Y una base que ya tenía dos recibos con la misma foto antes de c3: anulado el repetido, el siguiente pegado crea `recibos_ruta_unica`, y con él dos subidas a la vez con la misma foto dejan entrar una. |
| `c4-volumen.sh` | Los estados y el tablero con un libro de verdad: la apertura por su balanza y 15 meses hechos **por los puentes** (facturas y cobros parciales, tickets con dos tarjetas, recibos a cuenta y su pago con partida, trabajos externos, la nómina semanal con retenciones, statements repartidos entre obras, gastos del banco y el pago de las tarjetas; 666 por mes ≈ 10.000 asientos, un año largo), con depósitos de verdad que se parecen a los cobros de las pruebas y «hoy» fingido al 20-dic-2027 (solo la hora de ahora cae ese día: cualquier otra fecha es la suya). Lee cada vista como la lee conta.js por PostgREST (`json_agg` de `select *`, el dueño, `authenticated` con los ajustes de ese rol que PostgREST aplica —el `jit = off` de c4— y el tope de 8 s de la API; cada vista con tope de 2 s) y `fn_estados_control` como cada pantalla (tope de 8 s), y falla si alguna pasa su tope o sale algo en rojo. Después corre `c4-pruebas.sql` y `c3-pruebas.sql` enteros sobre ese libro **mientras cuatro «teléfonos» suben un ticket cada 0,25 s y el Panel lee los bancos**, y otra vez c4-pruebas con los meses de 2026 ya cerrados y un ajuste del CPA a diciembre fechado en febrero (el estado de 2027): falla si alguna subida o lectura se corta por el tope de 8 s, espera 8 s o más, o si un ticket subido se queda sin su asiento (en la bandeja porque una prueba le cruzó los candados). También el control con TODAS las vistas como desde el SQL Editor (tope de 60 s) y **vuelve a pegar `c4-estados.sql` sobre el libro lleno**: lo que tarda y lo que tarda su resumen corto del final (tope de 2 s: es lo que el pegado tiene tomadas las vistas al terminar). Imprime la tabla de tiempos (la de la cabecera de `c4-estados.sql`). `./c4-volumen.sh [bd] [por_mes]` (200 ≈ 3.000 asientos; 1332 ≈ 20.000); con `CONSERVAR=1` deja la base para mirarla. Tarda unos 10 minutos. |
| `c4-concurrencia.sh` | Lo que `c4-pruebas.sql` no puede probar en una sola sesión: la carga de la balanza de apertura y `fn_apertura` en dos sesiones a la vez (una espera a la otra por su candado: la recarga de una balanza que se está posteando la para su guarda, MX003, y el asiento y su papel dicen lo mismo), y dos `fn_apertura` a la vez con la misma balanza (una sola apertura viva). Y **volver a pegar c4 con el tablero leyendo** (una lectura larga del dueño, el pegado medio segundo después y otra lectura mientras espera): el pegado se rinde con 55P03 en menos de 3 s, nadie muere por 40P01, las dos lecturas terminan con sus cifras, y pegado otra vez sin nadie leyendo entra. |
| `c3-volumen.sh` | Lo que pasa con MUCHOS papeles: 3.000 recibos en el libro (un año largo de la cuadrilla), 1.200 facturas, 1.100 cobros y 600 trabajos externos, y la app pidiendo «reintentar puente» (`fn_puentes_correr`) y los controles (`fn_puentes_verificar`) como `authenticated`, con el tope de la API de Supabase (`statement_timeout` de 8 s): terminan, y lo que no cambió (recibos, facturas, cobros, trabajos externos) no se vuelve a planear. Imprime cuánto tardó cada cosa. `./c3-volumen.sh [bd] [recibos]`. |
| `generar-tablas.py`, `esquema-columnas-23sep.json` | Para regenerar las tablas de 01 si se vuelve a leer el esquema. |

## 0. Para Edgar: qué se pega en Supabase, en qué orden y qué debe salir

Todo va en el **SQL Editor** de Supabase (Dashboard → SQL Editor → New
query). Cada archivo se abre, se copia **entero**, se pega en una pestaña
vacía y se le da **Run**. El editor manda todo lo pegado de una vez: si algo
falla, sale el error en rojo y **no queda nada** de ese archivo; se avisa, se
arregla y se vuelve a pegar entero. Pegar un archivo dos veces no hace daño
(no duplica nada ni borra lo que Edgar ya tocó).

Las líneas `NOTICE: … does not exist, skipping` o `… already exists,
skipping` que pueda enseñar el editor **no son errores**: es el archivo
comprobando si algo ya estaba.

| Paso | Qué se pega | Qué debe verse al final |
|---|---|---|
| 1 | `docs/conta/c1-plan-de-cuentas.sql` | Una tabla con el plan de cuentas: **88 filas** (`codigo`, `nombre`, `tipo`, `saldo`, `imputable`, `activa`, `obra`, `cost_code`, `etiqueta_fiscal`), de la 1000 a la 9000. |
| 2 | `docs/conta/c2-libro.sql` | Los **10 controles** del libro (`fn_verificar_cadena`), **todos con `ok = true`**: `hash`, `enlace`, `numeracion`, `contadores`, `cuadre`, `reversos`, `periodos`, `triggers`, `cuentas` (dice `"cuentas": 88`) y `permisos`. Uno en `false` = parar y avisar. |
| 3 | `docs/conta/c3-puentes.sql` | **23 filas**: los 10 `libro · …` y 13 `puentes · …`. Todas en `true` **salvo `puentes · sin_evaluar`**, que la primera vez sale en `false` con la lista de papeles que el puente todavía no miró y `"arreglo": "select fn_puentes_correr();"`. Es lo esperado. `puentes · reglas` sale en `true` y dice cuántas reglas siguen en borrador (`en_borrador`): esas no postean hasta que Edgar las confirme. `puentes · papel` en producción sí mira Storage (en el banco dice «no aplica»). |
| 4 | `docs/conta/c4-estados.sql` | **9 filas**, cortas a propósito. Cinco `c4 · …`: `vistas` («28 vistas, todas security_invoker…»), `mapeo` («88 cuentas con su fila; sin fila: ninguna»), `apertura`, `jit` («el JIT está apagado para authenticated…») y `c2 y c3 al día` («c2-libro.sql y c3-puentes.sql son de la versión que c4 necesita…»). Y cuatro `estados <período> · …` (el último mes con asientos, o la apertura si no hay): `v_estados_mapeo` («88 filas») y los tres cuadres que mira siempre: `mapeo completo`, `protecciones de c4` y `apertura en el libro`. Todas en `true` **salvo `c4 · apertura` y «apertura en el libro»**, que salen en `false` («todavía no: carga la balanza…», «no hay apertura en el libro…») hasta que se postee la apertura (abajo, «Después de c4: la apertura y lo que se ve»). Es lo esperado. (`c4 · jit` en `false`: el pegado no pudo apagar el JIT para la app; su detalle trae la sentencia, que se pega como dueño. `c4 · c2 y c3 al día` en `false`: dice qué volver a pegar, c2 y después c3.) Una en `false` fuera de esas = parar y avisar. Si al pegarlo sale **MX000** con una lista de «vistas o funciones ajenas»: hay algo construido encima de las vistas de c4 que el pegado borraría; no se pegó nada, avisa. Si sale **55P03** («canceling statement due to lock timeout»): el tablero estaba leyendo; no se pegó nada: **cierra el tablero y vuelve a pegarlo**. Después, en otra pestaña, el control entero: `select * from fn_verificar_cadena();` (los 10 en `true`: c4 no toca el libro) y `select * from fn_estados_control('<el último mes>');` (todo en `true`, salvo «apertura en el libro» hasta la apertura). |
| 5 | Una línea: `select fn_puentes_correr();` | Un solo valor (jsonb) con `"desde": "2026-10-01"`, cuántos papeles quedaron en cada estado (`contabilizado`, `pendiente`, `espera`, `no_aplica`…) y **`"errores": 0`**. |
| 6 | Una línea: `select * from fn_puentes_verificar();` | Los **13 controles** de los puentes, **todos en `true`** (ahora también `sin_evaluar`). `bandeja` dice cuántos papeles esperan a Edgar; solo se pone en rojo si el libro rechazó alguno. |
| 7 | `docs/conta/c2-pruebas.sql` | La tabla `_pruebas`: **80 filas**, todas con `ok = true` (también quedan en `pruebas.c2_resultado`). (Con la apertura de verdad ya en el libro, la **61** sale «omitida»: no es un fallo.) |
| 8 | `docs/conta/c3-pruebas.sql` | La tabla `_pruebas`: **118 filas** (también en `pruebas.c3_resultado`), todas con `ok = true` salvo la **45**, que en producción sale «omitida» (Supabase no deja borrar de Storage por SQL; se prueba en el banco). Con la apertura de verdad ya en el libro, la **115** y la **117** (las que postean una apertura de prueba) también salen «omitida»: no es un fallo. Si no hay ningún perfil activo que no sea el dueño, las pruebas «del equipo» salen con `ok` vacío (`null`) y `obtenido` = «omitida…»: no es un fallo. |
| 9 | `docs/conta/c4-pruebas.sql` | La tabla `_pruebas`: **110 filas**, todas con `ok = true`. **Córrelas recién pegado c4 y ANTES de postear la apertura de verdad**: con ella ya en el libro, las **29 a 36, 50, 51, 53, 56, 61, 62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107** (las que postean una apertura de prueba) salen «omitida», y no es un fallo. Sin nadie del equipo activo, la **2** y la **38** salen «omitida»; la 38, 55, 56, 57, 58, 64, 77, 79, 80, 82, 89, 101, 103 y 109 también si la app estaba usando justo lo que tocan (esperan 2 s y se saltan). La **109** (el privilegio MAINTAIN) es de Postgres 17: en producción corre; en el banco con 16 sale «omitida». La **88** en rojo = el JIT sigue encendido para la app (ver el paso 4). Tardan unos 40 s en el banco; **en producción (instancia chica) 5 min 47 s, y el SQL Editor se cansa antes y enseña un error de red: la corrida sigue en el servidor hasta el final.** Espera unos 6 minutos y lee el resultado con `select * from pruebas.c4_resultado order by n;` (la misma tabla, con la hora de la corrida). |

- **Las pruebas dejan su resultado en el esquema `pruebas`** (`c2_resultado`,
  `c3_resultado`, `c4_resultado`: la última corrida, con su hora), fuera de
  la API (PostgREST no expone ese esquema; anon, authenticated y
  service_role no pueden usarlo). Es para cuando el SQL Editor deja de
  esperar mientras la corrida sigue en el servidor: enseña **«Error: Failed
  to fetch (api.supabase.com)»** y 0 filas, y no es un error de la prueba.
  Pasó el 26-sep con c4-pruebas en producción, dos veces: 5 min 47 s la
  primera (sin la tabla: el resultado se perdió) y 7 min la segunda (14:40
  UTC, 110/110 leídos de `pruebas.c4_resultado`); el banco tarda 40 s. El
  proyecto está en el plan **Free** (instancia chica, CPU compartida, y ese
  día con el cartel «Exceeding usage limits»): con la contabilidad dentro
  hace falta el plan Pro, y las pruebas largas se corren igual, leyendo la
  tabla al terminar. No es parte del libro; se borra con
  `drop schema pruebas cascade` cuando ya no haga falta.
- **El orden importa**: c2 necesita c1; c3 necesita c1 y c2; c4 necesita
  los tres. Las pruebas (7, 8 y 9) van siempre después de los cuatro: c2 y
  c3 tienen que seguir en verde con c4 pegado (lo están).
- **c2 y c3 ya están pegados en producción: vuelve a pegarlos (pasos 2 y
  3) antes de c4.** Cambió la forma de sus policies de lectura del dueño
  (`using ((select es_dueno()))`: Postgres pregunta una vez por consulta
  quién es, no una por fila). No tocan el libro ni lo que Edgar configuró;
  con 10.000 asientos el control del Panel baja de 6.4 s a 2.4 s. Y traen
  arreglos de verdad (en la cuarta ronda de c4: el control «permisos» de
  c2 ve la función SECURITY DEFINER ajena que lee el libro con un join de
  coma o un comentario en medio; c3 ya no dice «está dos veces» de una
  factura que la apertura trae con más por cobrar que su monto) y la
  MARCA de su versión (`fn_libro_version`, `fn_puente_version`). Sin
  volverlos a pegar NO basta: c2-pruebas y c3-pruebas salen en rojo, y c4
  lo dice (`c4 · c2 y c3 al día` en `false` al pegarlo, y «protecciones
  de c4» en rojo en cada control, con qué volver a pegar).
- **Pega c4 con el tablero cerrado.** El pegado rehace las vistas y las
  toma un instante enteras; con una pantalla leyendo, Postgres cortaba a
  uno de los dos (40P01, «deadlock detected»). Ahora el pegado espera un
  candado como mucho medio segundo: si el tablero lo tiene, para con
  **55P03** («lock timeout»), no se pega nada y no se corta a nadie; se
  cierra el tablero y se vuelve a pegar (`c4-concurrencia.sh`, vuelta 4).
- **Las pruebas no dejan rastro**: cada ataque se hace dentro de una
  subtransacción que se deshace a sí misma. No escriben asientos, líneas,
  contadores, cobros, aprobaciones, bandeja ni secuencias (usan ids
  negativos); lo único que queda es la tabla temporal `_pruebas` y unas
  funciones `pg_temp.*` de ayuda, que mueren al cerrarse la sesión del
  editor. Tardan unos segundos (en el banco: c2 ≈ 3 s, c3 ≈ 5 s, c4 ≈
  40 s; con el libro lleno, 10.000 asientos: c3 y c4 cerca de dos
  minutos cada una). **Córrelas sin nadie usando la app, mejor de noche**:
  mientras una prueba corre tiene tomados el libro (el candado de la
  cadena de c2), los candados de los recibos y a veces la tabla
  `periodos` o `recibos`, y una subida de recibo espera. Los pide en el
  orden de la app (los de los recibos, `periodos` y la cadena), así que
  la subida espera pero no se cruza con ella: antes, una prueba que ya
  había posteado pedía después el candado de su recibo, y con un teléfono
  subiendo a la vez Postgres cortaba a uno de los dos (40P01) y el puente
  dejaba ese recibo en la bandeja (el de la prueba, que salía en rojo, o
  el de verdad, sin asiento hasta «reintentar»). Con 10.000 asientos
  ninguna subtransacción de c4 tiene el libro más de unos 3 s, y ninguna
  de c3 más de unos 5 s; medido con `c4-volumen.sh`, con cuatro teléfonos
  subiendo tickets: ninguna subida cortada ni sin su asiento, y la que más
  esperó, 3,4 s mientras corría c4-pruebas y 6,5 s mientras corría
  c3-pruebas. (Antes de la ronda 3 de c4, c3-pruebas con el libro lleno
  tardaba 5 o 6 minutos, con pruebas de hasta 31 s, y se cortaban
  subidas.) La 38, 55, 56, 57, 58, 64, 77, 79, 80, 82, 89, 101, 103 y 109
  de c4 cambian un instante vistas, tablas o funciones de c4, del libro o
  de c3 (y se deshacen).
- **Si el editor no acepta un archivo tan grande** (`c3-puentes.sql` pesa
  ≈ 470 KB): se puede pegar en dos partes, desde el principio hasta la línea
  `-- ==== BLOQUE B ====` (sin ella), Run, y desde esa línea hasta el
  final, Run. Lo mismo `c2-libro.sql`. En el banco se prueban así con
  `archivo.sql:A` y `archivo.sql:B`. `c4-estados.sql` (≈ 650 KB) va
  entero: es una transacción, y su primera sentencia (el lock_timeout)
  vale para todo el pegado.
- **Re-correr la suite en producción** (después de cualquier cambio, o
  cuando se quiera comprobar): pegar otra vez `c2-pruebas.sql`,
  `c3-pruebas.sql` y `c4-pruebas.sql` (pasos 7, 8 y 9), cada una en su
  pestaña. Y para ver el estado del libro sin tocar nada:
  `select * from fn_verificar_cadena();`,
  `select * from fn_puentes_verificar();` y
  `select * from fn_estados_control('2026-10');` (cualquier período, o
  `'hoy'`: el corte del Panel).

### Después de c4: la apertura y lo que se ve

La apertura se hace **una vez**, cuando llegue la balanza de QuickBooks al
30-sep (f04), después de correr `c4-pruebas.sql`. Los pasos, con sus
ejemplos, están en la cabecera de `c4-estados.sql` («LA APERTURA, PASO A
PASO»); en corto:

1. `select fn_apertura_balanza_cargar('docs/apertura/balanza-2026-09-30.csv', '[…]');`
   — dice si cuadra y qué nombres de QuickBooks no tienen mapeo. La lista
   lleva también **su control, del Balance Sheet al 30-sep: la fila «Net
   Income»** (la utilidad de enero a septiembre), **la fila «TOTAL
   ASSETS» y la fila «Total Liabilities»** (y, si se quiere, «Total
   Equity» y «TOTAL LIABILITIES AND EQUITY»); se apartan (no se suman) y
   `fn_apertura` no postea si el mapeo no da lo mismo (un mapeo al lado
   equivocado —de resultados al balance, o una deuda a capital— para con
   MX001 y la fila que lo explica; sin «Total Liabilities», MX001 pide
   que se añada). En esas filas la cifra va como la enseña el Balance
   Sheet, en `saldo` (su única columna): Net Income en positivo es
   utilidad; los totales, en positivo. (O en `debe` / `haber`: la
   utilidad, el pasivo y el capital en `haber`; el activo en `debe`.) La
   retención por cobrar va por factura (como la cuenta por cobrar) y la
   retención por pagar (2020) con su proveedor.
2. `select fn_apertura_mapeo_qb('<nombre en QuickBooks>', '<cuenta>');` por
   cada nombre, y `fn_apertura_mapeo_trabajo('<Cliente:Obra>', '<obra>')`
   por cada Customer:Job.
3. `select * from fn_apertura_revisar('docs/apertura/…');` — el asiento que
   se va a postear, renglón por renglón, y cada fila de QuickBooks con la
   cuenta del plan a la que va y su tipo (activo, costo…); para en el
   primer problema.
4. `select fn_apertura('2026-09-30', 'docs/apertura/…');` — lo postea. Otra
   vez con la misma balanza y el mismo mapeo no hace nada; con otra, o con
   un mapeo corregido, dice qué cambia y no toca nada (con un motivo, la
   sustituye). Las cuentas por cobrar van por factura (`factura_num`: su
   número de QuickBooks); las por pagar, por proveedor, con la fecha de
   cada factura si se tiene (`fecha_documento`, `vence`). La fila TOTAL del
   reporte se aparta sola.
5. `select * from v_comparacion where periodo = '2026-09-APERTURA';` —
   **todas las filas con `ok = true`** (la retención partida a 1120 ya
   viene explicada), y `select * from fn_estados_control('2026-09-APERTURA');`
   **todo en `true`** (también «apertura en el libro»). Al volver a pegar
   c4, `c4 · apertura` sale en `true` («asiento 2026-0000NN con
   docs/apertura/…»). Mientras la apertura siga abierta, se puede deshacer
   con `fn_reversar` y volver a postear (mientras tanto, «apertura en el
   libro» sale en rojo en todo período: la pantalla no pinta); cerrada, lo
   que falte va con un ajuste a la apertura (c2).

Lo que se puede mirar desde el SQL Editor (lo mismo que pintará conta.js,
f05; cada fila trae en `bajar` de dónde sale cada cifra):

```sql
select * from v_balanza          where periodo = '2026-10';   -- la balanza (el total en cero)
select * from v_balance_general  where periodo = 'hoy';       -- activo = pasivo + capital
select * from v_resultados       where periodo = '2026-10';   -- el mes, el anterior y el año
select * from v_flujo_caja       where periodo = '2026-10';   -- directo e indirecto
select * from v_cxc_antiguedad   where periodo = 'hoy';       -- lo que se cobra, por antigüedad
select * from v_obras_dinero     where periodo = 'hoy';       -- el dinero de cada obra
select * from fn_estados_control('hoy');                       -- el control del Panel (todo en true)
select * from v_libro where asiento_id = '<id>';              -- las líneas de un asiento
select * from v_asiento_papel where asiento_id = '<id>';      -- y su papel (la foto, la factura…)
-- La comparación contra QuickBooks es la de la última balanza cargada del
-- período; una anterior (la de una quincena), pidiéndola por su documento:
set c4.comparar_documento = 'docs/qb/balanza-2026-12-15.csv';
select * from v_comparacion where periodo = '2026-12';       -- esa versión, a su fecha (al)
reset c4.comparar_documento;                                  -- otra vez la última
-- Cargar la balanza de QuickBooks de un mes (vale la más reciente de su
-- tipo; si desplaza a otra, lo avisa), el complemento por obra (el «Profit
-- and Loss by Customer», tipo 'por_obra': no desplaza a la balanza), y
-- retirar una carga equivocada con su motivo (queda el rastro y vuelve a
-- valer la anterior de su tipo):
select fn_comparacion_qb_cargar('2026-10', 'docs/qb/balanza-2026-10.csv', '[…]');
select fn_comparacion_qb_cargar('2026-10', 'docs/qb/pl-por-obra-2026-10.csv', '[…]', false, null, 'por_obra');
select fn_comparacion_qb_retirar('2026-10', 'docs/qb/pl-por-obra-2026-10.csv', 'Es el P&L por obra, no la balanza');
```

## 0b. La prueba final en el banco, de cero

Lo mismo que el paso 1–7 de arriba, sin tocar producción. Tarda segundos:

```bash
cd /home/user/max-power-panel/pruebas/conta
D=../../docs/conta

# De cero: las cuatro entregas, los puentes corridos (como el paso 5) y las
# tres suites (sin Storage: 45 y 90 de c3 salen «omitida»; con
# 03-storage-simulacro.sql delante salen en verde).
echo 'select fn_puentes_correr(); select * from fn_puentes_verificar();' > /tmp/puentes_mio.sql
./correr.sh final_mia 03-storage-simulacro.sql $D/c1-plan-de-cuentas.sql $D/c2-libro.sql \
                      $D/c3-puentes.sql $D/c4-estados.sql /tmp/puentes_mio.sql \
                      $D/c2-pruebas.sql $D/c3-pruebas.sql $D/c4-pruebas.sql
#   → PRUEBAS total=80 ok=80 fallan=0 omitidas=0
#   → PRUEBAS total=118 ok=118 fallan=0 omitidas=0
#   → PRUEBAS total=110 ok=110 fallan=0 omitidas=0   (en 17.6; en 16, ok=109
#     omitidas=1: la 109, MAINTAIN, es de Postgres 17)

# Idempotencia: sobre la MISMA base, volver a pegar c1, c2, c3 y c4 (dos
# veces) y las pruebas otra vez; tiene que seguir todo en verde.
for i in 1 2; do for f in c1-plan-de-cuentas c2-libro c3-puentes c4-estados; do
  PGPASSWORD=editor_sql psql -X -q -h 127.0.0.1 -U editor_sql -d final_mia \
    -v ON_ERROR_STOP=1 -1 -o /dev/null -f $D/$f.sql || echo "FALLÓ $f"
done; done

# Varias sesiones, volver a pegar con reglas tocadas, y volumen:
./c2-pegado.sh final_c2p; ./c3-pegado.sh final_c3p
./c2-concurrencia.sh final_c2c; ./c3-concurrencia.sh final_c3c; ./c4-concurrencia.sh final_c4c
./c3-volumen.sh final_c3v 3000
./c4-volumen.sh final_c4v             # ≈ 10.000 asientos por los puentes (unos 10 minutos)

./correr.sh --borrar final_mia
```

Con la apertura de verdad ya posteada (una balanza, su mapeo y
`fn_apertura`, confirmados antes de las suites) tiene que salir igual de
verde: c2 con la 61 «omitida», c3 con la 115 y la 117 «omitidas» (más la
45 en producción), c4 con la 29 a la 36, 50, 51, 53, 56, 61,
62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107 «omitidas»,
nada en rojo. Y con datos de verdad en el mes (un depósito normal que se
parece a un cobro de prueba, la renta, un pago de préstamo, una
distribución, tickets de Home Depot, la balanza de octubre cargada): las
pruebas de c4 miden lo que cambia su escenario, no el total del mes. El 25-sep se corrió así también, en 16 y en 17.6
(`c4-volumen.sh` corre c4-pruebas sobre 10.000 asientos con su apertura).

Para comprobar que las pruebas no dejan rastro, se saca una «foto» de la
base (cuántas filas y un md5 de cada tabla de `public`, `auth` y `storage`,
el `last_value` de cada secuencia, y las definiciones y permisos de
funciones, triggers, policies, vistas y columnas) antes y después de
correr `c2-pruebas.sql`, `c3-pruebas.sql` y `c4-pruebas.sql`: las fotos
tienen que ser idénticas. La prueba final del 24-sep lo hizo así, también
con asientos y bandeja ya llenos (después de `fn_puentes_correr()`), y
salieron iguales. La del 25-sep (con c4) también, en 16 y en 17.6, en tres
estados de la base: recién pegados c1–c4, con `fn_puentes_correr()` ya
corrido, y con la apertura de verdad posteada; la foto tenía además las
restricciones, índices, comentarios, ajustes de los roles
(`rolconfig`, `pg_db_role_setting`), privilegios por defecto y miembros
de roles. Las tres suites seguidas: foto igual antes y después de cada una.
Al VOLVER a pegar c1–c4 encima, lo único que cambia es lo que tiene que
cambiar: la hora del sello en el comentario de `fn_libro_huellas()` y de
`fn_estados_huellas()` («selladas por el último pegado, el … (Miami)») y
los oid de las vistas de c4 (el pegado las rehace); filas, secuencias,
definiciones y permisos, iguales.

## 1. Arrancar el cluster

Postgres 16 ya está instalado. Como root:

```bash
pg_ctlcluster 16 main start      # arranca (si ya está arriba, avisa y no pasa nada)
pg_lsclusters                    # debe decir "online" en 5432
```

Si no existiera el cluster: `pg_createcluster 16 main --start`.

`correr.sh` entra como superusuario por el socket local (`runuser -u postgres
-- psql`) y como `editor_sql` por TCP a `127.0.0.1:5432` con contraseña
`editor_sql` (la `pg_hba.conf` de Ubuntu ya pide scram en 127.0.0.1: no hay
que tocarla).

## 2. Correr

```bash
cd /home/user/max-power-panel/pruebas/conta

# Solo el banco, para comprobar que imita bien (18/18 ok):
./correr.sh banco_mio c0-banco-pruebas.sql

# Lo que se va a entregar, y luego sus pruebas:
./correr.sh c2_agente ../../docs/conta/c1-plan-de-cuentas.sql \
                      ../../docs/conta/c2-libro.sql \
                      ../../docs/conta/c2-pruebas.sql

# Rojo primero: solo el bloque A (tablas), las pruebas deben fallar
# por el código esperado; luego el bloque B (invariantes) y en verde.
./correr.sh c2_rojo  ../../docs/conta/c2-libro.sql:A ../../docs/conta/c2-pruebas.sql
./correr.sh c2_verde ../../docs/conta/c2-libro.sql:A ../../docs/conta/c2-libro.sql:B ../../docs/conta/c2-pruebas.sql

# ¿Idempotente? Pégalo dos veces:
./correr.sh c2_dos ../../docs/conta/c2-libro.sql ../../docs/conta/c2-libro.sql

# Los puentes (c3), encima del libro, con el Storage de mentira y las dos
# suites (c2-pruebas también tiene que seguir en verde con c3 pegado):
./correr.sh c3_agente 03-storage-simulacro.sql ../../docs/conta/c1-plan-de-cuentas.sql \
                      ../../docs/conta/c2-libro.sql ../../docs/conta/c3-puentes.sql \
                      ../../docs/conta/c3-puentes.sql \
                      ../../docs/conta/c2-pruebas.sql ../../docs/conta/c3-pruebas.sql
# Rojo de c3: solo su bloque A (tablas, reglas, funciones mínimas):
./correr.sh c3_rojo 03-storage-simulacro.sql ../../docs/conta/c1-plan-de-cuentas.sql \
                    ../../docs/conta/c2-libro.sql ../../docs/conta/c3-puentes.sql:A ../../docs/conta/c3-pruebas.sql
# Varias sesiones a la vez contra los puentes (crea y borra su base):
./c3-concurrencia.sh c3_conc_mia
# Volver a pegar c3 con las reglas ya tocadas (crea y borra su base):
./c3-pegado.sh c3_pegado_mio
# Muchos papeles, con el tope de 8 s de la API (crea y borra su base):
./c3-volumen.sh c3_volumen_mio 3000

# Los estados (c4), encima de los puentes, con las tres suites (c2 y c3
# tienen que seguir en verde con c4 pegado), y c4 pegado dos veces:
./correr.sh c4_agente 03-storage-simulacro.sql ../../docs/conta/c1-plan-de-cuentas.sql \
                      ../../docs/conta/c2-libro.sql ../../docs/conta/c3-puentes.sql \
                      ../../docs/conta/c4-estados.sql ../../docs/conta/c4-estados.sql \
                      ../../docs/conta/c2-pruebas.sql ../../docs/conta/c3-pruebas.sql \
                      ../../docs/conta/c4-pruebas.sql
# Dos sesiones a la vez con la apertura (crea y borra su base):
./c4-concurrencia.sh c4_conc_mia
# Los estados con un libro de verdad, como los lee la app, y c4-pruebas
# encima con un teléfono subiendo tickets (crea y borra su base):
./c4-volumen.sh c4_volumen_mio

# Al terminar, borra TU base:
./correr.sh --borrar banco_mio
```

- **Una base por agente**, con nombre propio (minúsculas, dígitos y `_`).
  `correr.sh` la borra y la crea de cero cada vez; los roles son del cluster y
  se comparten (el script aguanta que varios agentes corran a la vez).
- Cada archivo se carga como `editor_sql`, con `ON_ERROR_STOP=1` y **en una
  sola transacción** (`psql -1`), como el SQL Editor, que manda todo lo pegado
  en una petición: si una sentencia falla no queda nada, y `now()` vale lo
  mismo en todo el archivo. `BANCO_SIN_TRANSACCION=1 ./correr.sh …` lo carga
  sentencia a sentencia.
- `archivo.sql:A` carga hasta la línea `-- ==== BLOQUE B ====` (sin ella);
  `archivo.sql:B`, desde ella hasta el final.
- Para los `c*-pruebas.sql` calla la salida propia del archivo y enseña la
  tabla `_pruebas` legible y la línea
  `PRUEBAS total=N ok=N fallan=N omitidas=N`.
  Avisa si la última sentencia no es `select * from _pruebas order by n;`.
- Avisa si un archivo trae metacomandos de psql (`\i`, `\set`…): en el SQL
  Editor no existen.
- Salida: `0` todo bien · `1` alguna prueba falla · `2` un archivo abortó con
  error de SQL · `64` uso incorrecto.

## 3. Datos sembrados

| Quién | uuid | rol | activo |
|---|---|---|---|
| Edgar | `00000000-0000-4000-a000-000000000001` | `dueno` | sí |
| Gustavo (el «equipo») | `00000000-0000-4000-a000-000000000002` | `campo` | sí |
| Pedro | `00000000-0000-4000-a000-000000000003` | `campo` | **no** |

- Obras: `casa-perez-k3m9` (residencial) y `oficina-nch-7xq2` (comercial).
- Los 20 `codigos_partida`. **Reales** (salen en `catalogo_items.codigo` y en
  los docs): 01-DEMO, 03-UG, 05-PANEL, 06-FEED, 07-GND, 08-ROUGH, 09-COND,
  10-DEV, 11-LIGHT, 13-LV, 15-GEN, 20-MISC. **Inventados** con el mismo
  formato: 02-TEMP, 04-SERV, 12-FA, 14-HVAC, 16-SOLAR, 17-EV, 18-SITE,
  19-PERMIT. Nombres y `categoria` son del banco.
- Recibos 1–9: `por_leer` con y sin total, `leido` con tarjeta / `Account` /
  `APPLE PAY ??` / sin `metodo_pago`, uno con total de 4 decimales y `tax`
  nulo, `anulado` con y sin total, y el 9 fechado en **septiembre**.
- Facturas 1–4: 1101 pagada, 1102 y 1103 abiertas, 1098 de **septiembre** y pagada.
- Horas 1–7: del dueño y del equipo; la 4 con `correccion_estado = 'aprobada'`;
  la 6 y la 7 en **septiembre** (la 7 de Pedro, cuando trabajaba).
- También: `costos_equipo`, `externos_equipo`, `trabajos_externos` (uno de
  septiembre), `hitos`, `finanzas_proyecto`, `materiales` (el 2 ya marcado
  `comprado` por el recibo 2), `pendientes`, `asistente_ajustes`, `asistente_uso`.

## 4. Suplantar a un usuario a mano

```bash
PGPASSWORD=editor_sql psql -h 127.0.0.1 -U editor_sql -d banco_mio
```

```sql
begin;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select auth.uid(), es_dueno(), es_activo();
select count(*) from facturas;          -- 0: RLS
select * from recibos_equipo;            -- la vista sin montos
rollback;                                -- vuelve a editor_sql y deshace todo
```

`anon`: `'{"role":"anon"}'` y `set local role anon`. Service role:
`set local role service_role` (se salta RLS, como la edge function).

## 5. El molde de un `c*-pruebas.sql`

Mira `c0-banco-pruebas.sql`. Cada ataque:

```sql
do $$
declare v_obt text;
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', <uuid>, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    -- … el ataque; el resultado se guarda en v_obt …
    raise exception using errcode = 'MXT00';          -- deshace todo lo escrito
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate;               -- o el SQLSTATE esperado
  end;
  insert into _pruebas values (n, 'qué', 'esperado', v_obt, v_obt = 'esperado');
end $$;
```

Las variables de plpgsql no se deshacen con la subtransacción: por eso el
resultado sobrevive al `MXT00`. Al salir del `begin … end` interno ya se es
otra vez el editor, que puede escribir en `_pruebas`.

## 5b. El reloj fingido

Un período se cierra cuando ya terminó (hora de Miami, `fn_fecha_miami`), y
las pruebas cierran meses que todavía no terminan. Dos formas, las dos sin
tocar `docs/conta/c2-libro.sql`:

- **En `c2-pruebas.sql`**: dentro de la subtransacción de la prueba,
  `pg_temp.mx_fingir_hoy(fecha)` rehace `fn_fecha_miami` con
  `greatest(hoy de verdad, fecha)`; el `MXT00` la deshace. Mientras dura, el
  control `triggers` sale en rojo por esa función (por eso esas pruebas miran
  solo el control que prueban). `pg_temp.mx_cerrar_hasta(periodo)` finge el
  día siguiente, pone el asiento de apertura si falta y cierra en orden.
- **En `c3-pruebas.sql`**: lo mismo, con `pg_temp.c3_fingir_hoy(fecha)` y
  `pg_temp.c3_cerrar_hasta(periodo)` (la prueba toma antes
  `lock table public.periodos in exclusive mode`).
- **En `c2-concurrencia.sh`** (varias sesiones: lo fingido tiene que estar
  confirmado): carga una COPIA de `c2-libro.sql` con `fn_fecha_miami` en
  `greatest(hoy, '2027-01-15')`, y sus huellas se sellan con esa copia. La
  base es de usar y tirar.

## 6. Lo que el banco NO imita

- **Llaves foráneas, unique y CHECK**: desde el 24-sep sí están, las de
  producción (`02b-restricciones-produccion.sql`). Antes no estaban, y por
  eso la primera corrida de `c3-pruebas.sql` en producción falló en 72
  pruebas (categorías y formas de pago inventadas, ids escritos en tablas
  GENERATED ALWAYS) sin haber probado nada: si producción cambia sus
  restricciones, se vuelven a leer y se actualiza ese archivo.
- **Policies SUPUESTAS** (marcadas en 01): `contratistas`, `gastos_generales`,
  `catalogo_items`, `escenarios`, `estimados`, `asistente_ajustes` (solo
  dueño) y `pendientes` (el equipo lee, crea y resuelve). Las demás son las
  reales.
- **Triggers con cuerpo inventado o vacío**: `fn_cartero` (stub),
  `fn_avisar_horas` y `fn_avisa_correccion` (llaman al stub),
  `fn_nto_al_apuntar_horas` (no-op). **No existen**: los de `proyectos`
  (llave de portal, NTO), `trg_perfil_inactivo`, `trg_co_firmado`.
- **Vistas**: solo `recibos_equipo` (real) y `asistente_costo_mes`
  (aproximada). No están `proyectos_equipo`, `materiales_equipo`,
  `alcances_equipo`, `documentos_equipo`.
- **Tablas**: solo las 21 que tocan los libros; las otras ~44 de producción no.
- **Storage** (`storage.objects` y sus policies) no existe, salvo que se
  cargue `03-storage-simulacro.sql`: una tabla y tres policies supuestas
  (sus nombres reales no se leyeron). No hay archivos ni la API de Storage:
  borrar es un `delete` en la tabla, con RLS.
- **PostgREST** no existe: no hay `/rest/v1/rpc`, ni conversión de errores a
  HTTP, ni `Prefer: return=representation`. «anon puede ejecutar la función»
  se prueba con `has_function_privilege` y `set role anon`, no con HTTP.
- **`net.http_post`** no manda nada (devuelve 0). La firma es la de pg_net
  (`url, body, params, headers, timeout_milliseconds`): las llamadas con
  nombre funcionan; una llamada posicional `(url, headers, body)` se aceptaría
  pero con los argumentos cruzados.
- **Versión**: el banco es Postgres **16.13**; producción es **17.6**. Evita
  sintaxis solo de 17 (p. ej. `json_table`, `merge … returning`) y ojo con
  diferencias finas del planificador. Para probar en la versión de
  producción, `./pg17.sh` monta un Postgres **17.6** en el puerto 5433 y
  cualquier script corre allí con `PGPORT=5433`. El 24-sep se corrió así
  todo: c2-pruebas 78/78, c3-pruebas 113/113 (con Storage), pegado,
  concurrencia y volumen, en verde en 16 y en 17. El 25-sep, con c4:
  c2-pruebas 78/78, c3-pruebas 113/113 y c4-pruebas 39/39 en 16 y en 17,
  también con c1–c4 pegados dos veces encima y con la apertura de verdad
  ya posteada; y c4-volumen con 3.000 y 10.000 asientos en los dos. Y en
  la segunda ronda de c4 (25-sep): c2-pruebas 79/79, c3-pruebas 114/114 y
  c4-pruebas 68/68 en 16 y en 17.6, con c4 pegado dos veces y encima de la
  versión anterior; c4-concurrencia y c4-volumen (10.000 asientos por los
  puentes, con c4-pruebas encima y un teléfono) en los dos. Y en la
  tercera ronda de c4, con sus correcciones (25-sep): c2-pruebas 79/79,
  c3-pruebas 117/117 y c4-pruebas 91/91 en 16 y en 17.6, también con c1–c4
  pegados dos veces más y con c3 y c4 pegados encima de sus versiones
  anteriores (la de la ronda 2 y la instantánea 0718d99); los scripts del
  banco (pegado y concurrencia de c2, c3 y c4, c3-volumen), y c4-volumen
  con cuatro teléfonos, c3-pruebas encima y 2026 abierto y cerrado (con
  un ajuste del CPA a diciembre), en los dos. Y en la cuarta ronda de c4
  (25-sep): c2-pruebas 80/80, c3-pruebas 118/118 y c4-pruebas 110/110 en
  17.6 (en 16, 109 y la 109 «omitida»: MAINTAIN es de 17), también con
  c1–c4 pegados dos veces más y encima de las versiones de la ronda 3
  (también c4 nuevo antes que c2 y c3 nuevos: su fila «c2 y c3 al día»
  sale en false hasta volver a pegarlos); los scripts del banco (pegado
  y concurrencia de c2, c3 y c4 —con la vuelta 4, pegar c4 con el
  tablero leyendo—, c3-volumen) y c4-volumen con 10.000 asientos, en los
  dos; y `SOLO_MEDIR=1 ./c4-volumen.sh bd 1332` (20.553 asientos) en 17.6:
  todo bajo su tope, el control del Panel en 6,7 s.
- **La prueba final de c4, de cero (25-sep, noche)**, con los archivos de
  la cuarta ronda, en 16.13 y en 17.6:
  - Carga completa (`03-storage-simulacro`, c1, c2, c3, c4 y las tres
    suites): c2-pruebas 80/80, c3-pruebas 118/118, c4-pruebas 110/110 en
    17.6 y 109 + la 109 «omitida» en 16. El pegado de c4 enseña sus 9
    filas, todas en true salvo `c4 · apertura` y «apertura en el libro».
  - Idempotencia: c1, c2, c3 y c4 pegados dos veces más sobre la misma
    base, y las suites otra vez: iguales. Y como en producción: c1 + c2 y
    c3 de producción (los del 24-sep, 16c37fa) con el puente corrido, y
    encima c2, c3 y c4 nuevos; lo mismo con el c4 del diseñador (16c37fa)
    ya pegado, con la instantánea de la ronda 3 (0718d99, c2, c3 y c4), y
    con c4 nuevo pegado ANTES que c2 y c3 nuevos (sale «c2 y c3 al día»
    en false y «protecciones de c4» en rojo, diciendo qué volver a pegar;
    pegados c2 y c3, todo en verde). Las tres suites en verde en los
    cuatro casos, en 16 y en 17.6.
  - Sin rastro: la foto (arriba) igual antes y después de cada suite, en
    los tres estados de la base, en 16 y en 17.6. Con la apertura de
    verdad: c2 79 + la 61 omitida, c3 116 + la 115 y la 117 omitidas, c4
    83 + las 27 de la lista (16: 82 + 28, con la 109), nada en rojo.
  - Scripts del banco, en los dos: c2-pegado (18 ok), c3-pegado (14),
    c2-concurrencia (12), c3-concurrencia (34), c4-concurrencia (17),
    c3-volumen con 3.000 recibos (reintentar 1,5 s / 1,8 s; controles
    2,1 s / 2,2 s), c4-volumen con 10.333 asientos (ninguna vista por
    encima de 0,65 s; el control del Panel 3,4 s en 16 y 3,7 s en 17.6;
    todas las vistas 4,8 s / 5,8 s; volver a pegar c4 sobre el libro
    lleno 0,7 s / 0,8 s; con cuatro teléfonos subiendo, la subida más
    lenta 5,4 s / 6,3 s mientras corre c3-pruebas y 3,2 s como mucho
    mientras corre c4-pruebas; nada en rojo). c0-banco-pruebas 18/18.
    Sin Storage, c3-pruebas da 116 + la 45 y la 90 omitidas.
- **JIT**: el Postgres del banco trae el compilador JIT encendido (lo de
  fábrica). Con consultas grandes compila más de lo que corre (una vista
  del tablero leída como el editor, 16 s con JIT y 0,15 s sin él; la
  gráfica del Panel, 2,5 s con 10.000 asientos, casi todo compilando):
  `fn_estados_control` y `c4-pruebas.sql` lo apagan para sí (`set jit =
  off`), y `c4-estados.sql` lo apaga para la app: `alter role
  authenticated set jit = off`, para el rol ENTERO (PostgREST aplica en
  cada consulta los ajustes del rol que lee de `pg_roles.rolconfig`, que
  son los de todas las bases —uno puesto `in database …` no lo ve—, como su
  tope de 8 s; y `notify pgrst, 'reload config'` se los hace releer). La
  versión anterior lo ponía `in database …`: la prueba 88 y `c4 · jit`
  salían en verde y PostgREST seguía compilando. Para eso el que pega tiene
  que ser dueño del rol o tener ADMIN sobre él: el `00-shim` del banco se lo
  da a `editor_sql` (en Supabase, el SQL Editor lo es: es lo mismo que su
  statement_timeout). En el banco queda puesto para todo el cluster (el
  rol es del cluster), sin daño. `c4-volumen.sh` lee las vistas como
  PostgREST, con esos ajustes y solo esos.
- **pg_cron** no está (tampoco en producción hasta la Fase 8).
- El rol `editor_sql` no es superusuario y tiene `BYPASSRLS`, `CREATEROLE` y
  `CREATEDB`, que es como entendemos al `postgres` de Supabase (no se
  comprobó en producción; para las tablas que él mismo crea da igual: el
  dueño de una tabla ya se salta RLS). No existen los esquemas internos de
  Supabase (`supabase_functions`, `realtime`, `vault`…) ni `supabase_admin`.
- Los privilegios por defecto aplican a lo que **`editor_sql`** crea en
  `public`. Lo que cree el superusuario no los recibe: carga siempre como
  `editor_sql` (que es lo que hace `correr.sh`).
- **Que el SQL Editor corra lo pegado en una sola transacción** es como
  entendemos su funcionamiento (una petición con varias sentencias); el
  banco lo imita con `psql -1`. Si algún día no fuera así, corre también con
  `BANCO_SIN_TRANSACCION=1`.
