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
| `c4-volumen.sh` | Los estados y el tablero con un libro de verdad: la apertura por su balanza y 15 meses hechos **por los puentes** (facturas y cobros parciales, tickets con dos tarjetas, recibos a cuenta y su pago con partida, trabajos externos, la nómina semanal con retenciones, statements repartidos entre obras, gastos del banco y el pago de las tarjetas; 666 por mes ≈ 10.000 asientos, un año largo). Lee cada vista como la lee conta.js por PostgREST (`json_agg` de `select *`, el dueño, `authenticated` con los ajustes de ese rol que PostgREST aplica —el `jit = off` de c4— y el tope de 8 s de la API; cada vista con tope de 2 s) y `fn_estados_control` como cada pantalla (tope de 8 s), y falla si alguna pasa su tope o sale algo en rojo. Después corre `c4-pruebas.sql` y `c3-pruebas.sql` enteros sobre ese libro **mientras cuatro «teléfonos» suben un ticket cada 0,25 s y el Panel lee los bancos**, y otra vez c4-pruebas con los meses de 2026 ya cerrados (el estado de 2027): falla si alguna subida o lectura se corta por el tope de 8 s, o espera 8 s o más. Imprime la tabla de tiempos (la de la cabecera de `c4-estados.sql`). `./c4-volumen.sh [bd] [por_mes]` (200 ≈ 3.000 asientos); con `CONSERVAR=1` deja la base para mirarla. Tarda unos 10 minutos. |
| `c4-concurrencia.sh` | Lo que `c4-pruebas.sql` no puede probar en una sola sesión: la carga de la balanza de apertura y `fn_apertura` en dos sesiones a la vez (una espera a la otra por su candado: la recarga de una balanza que se está posteando la para su guarda, MX003, y el asiento y su papel dicen lo mismo), y dos `fn_apertura` a la vez con la misma balanza (una sola apertura viva). |
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
| 4 | `docs/conta/c4-estados.sql` | **45 filas**. Las seis primeras: `c4 · vistas` («28 vistas, todas security_invoker…»), `c4 · mapeo` («88 cuentas con su fila; sin fila: ninguna»), `c4 · apertura`, `c4 · jit` («el JIT está apagado para authenticated…»), `libro · triggers` y `libro · permisos`, todas en `true` **salvo `c4 · apertura`**, que sale en `false` con «todavía no: carga la balanza…» hasta que se postee la apertura (abajo, «Después de c4: la apertura y lo que se ve»). Es lo esperado. (`c4 · jit` en `false`: el pegado no pudo apagar el JIT para la app; su detalle trae la sentencia, que se pega como dueño.) Después, 39 filas `estados <período> · …` (el último mes con asientos, o la apertura si no hay): las 25 vistas con cuántas filas dieron («N filas») y los 14 cuadres («cuadra»; los últimos, «protecciones de c4», «efectivo del flujo = efectivo del balance» y «apertura en el libro»), **todas en `true` salvo «apertura en el libro»**, que hasta que se postee la apertura sale en `false` con «no hay apertura en el libro…» (lo esperado, como `c4 · apertura`). Una en `false` fuera de esas dos = parar y avisar. Si al pegarlo sale **MX000** con una lista de «vistas o funciones ajenas»: hay algo construido encima de las vistas de c4 que el pegado borraría; no se pegó nada, avisa. |
| 5 | Una línea: `select fn_puentes_correr();` | Un solo valor (jsonb) con `"desde": "2026-10-01"`, cuántos papeles quedaron en cada estado (`contabilizado`, `pendiente`, `espera`, `no_aplica`…) y **`"errores": 0`**. |
| 6 | Una línea: `select * from fn_puentes_verificar();` | Los **13 controles** de los puentes, **todos en `true`** (ahora también `sin_evaluar`). `bandeja` dice cuántos papeles esperan a Edgar; solo se pone en rojo si el libro rechazó alguno. |
| 7 | `docs/conta/c2-pruebas.sql` | La tabla `_pruebas`: **79 filas**, todas con `ok = true`. (Con la apertura de verdad ya en el libro, la **61** sale «omitida»: no es un fallo.) |
| 8 | `docs/conta/c3-pruebas.sql` | La tabla `_pruebas`: **117 filas**, todas con `ok = true` salvo la **45**, que en producción sale «omitida» (Supabase no deja borrar de Storage por SQL; se prueba en el banco). Si no hay ningún perfil activo que no sea el dueño, las pruebas «del equipo» salen con `ok` vacío (`null`) y `obtenido` = «omitida…»: no es un fallo. |
| 9 | `docs/conta/c4-pruebas.sql` | La tabla `_pruebas`: **89 filas**, todas con `ok = true`. **Córrelas recién pegado c4 y ANTES de postear la apertura de verdad**: con ella ya en el libro, las **29 a 36, 50, 51, 53, 56, 61, 62, 69, 73, 76, 81, 84 y 86** (las que postean una apertura de prueba) salen «omitida», y no es un fallo. Sin nadie del equipo activo, la **2** y la **38** salen «omitida»; la 38, 55, 56, 57, 58, 64, 77, 79, 80 y 82 también si la app estaba usando justo lo que tocan (esperan 2 s y se saltan). La **88** en rojo = el JIT sigue encendido para la app (ver el paso 4). Tardan unos 35 s (con el libro lleno, algo más de un minuto). |

- **El orden importa**: c2 necesita c1; c3 necesita c1 y c2; c4 necesita
  los tres. Las pruebas (7, 8 y 9) van siempre después de los cuatro: c2 y
  c3 tienen que seguir en verde con c4 pegado (lo están).
- **c2 y c3 ya están pegados en producción: vuelve a pegarlos (pasos 2 y
  3) antes de c4.** Cambió la forma de sus policies de lectura del dueño
  (`using ((select es_dueno()))`: Postgres pregunta una vez por consulta
  quién es, no una por fila). No tocan el libro ni lo que Edgar configuró;
  con 10.000 asientos el control del Panel baja de 6.4 s a 2.4 s. Sin
  volver a pegarlos todo funciona, más lento.
- **Las pruebas no dejan rastro**: cada ataque se hace dentro de una
  subtransacción que se deshace a sí misma. No escriben asientos, líneas,
  contadores, cobros, aprobaciones, bandeja ni secuencias (usan ids
  negativos); lo único que queda es la tabla temporal `_pruebas` y unas
  funciones `pg_temp.*` de ayuda, que mueren al cerrarse la sesión del
  editor. Tardan unos segundos (en el banco: c2 ≈ 1 s, c3 ≈ 4 s, c4 ≈
  35 s; con el libro lleno, 10.000 asientos: c3 ≈ 2 minutos y c4 algo más
  de 1 minuto). **Córrelas sin nadie usando la app, mejor de noche**:
  mientras una prueba corre tiene tomados el libro (el candado de la
  cadena de c2) y a veces la tabla `periodos` o `recibos`, y una subida de
  recibo espera. Con 10.000 asientos ninguna subtransacción de c4 lo tiene
  más de 2 o 3 s, y ninguna de c3 más de unos 7 s (la 39 y la 114, que
  barren el libro entero); medido con `c4-volumen.sh`, con cuatro
  teléfonos subiendo tickets: ninguna subida cortada. (Antes de la ronda 3
  de c4, c3-pruebas con el libro lleno tardaba 5 o 6 minutos, con pruebas
  de hasta 31 s, y se cortaban subidas.) La 38, 55, 56, 57, 58, 64, 77,
  79, 80 y 82 de c4 cambian un instante vistas o tablas de c4 (y se
  deshacen).
- **Si el editor no acepta un archivo tan grande** (`c3-puentes.sql` pesa
  ≈ 466 KB): se puede pegar en dos partes, desde el principio hasta la línea
  `-- ==== BLOQUE B ====` (sin ella), Run, y desde esa línea hasta el
  final, Run. Lo mismo `c2-libro.sql`. En el banco se prueban así con
  `archivo.sql:A` y `archivo.sql:B`. `c4-estados.sql` (≈ 474 KB, como c3)
  va entero.
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
   Income»** (la utilidad de enero a septiembre, en `haber` si es
   utilidad) **y la fila «TOTAL ASSETS»**; se apartan (no se suman) y
   `fn_apertura` no postea si el mapeo no da lo mismo (un mapeo al lado
   equivocado para con MX001 y la fila que lo explica). La retención por
   cobrar va por factura (como la cuenta por cobrar) y la retención por
   pagar (2020) con su proveedor.
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
#   → PRUEBAS total=79 ok=79 fallan=0 omitidas=0
#   → PRUEBAS total=117 ok=117 fallan=0 omitidas=0
#   → PRUEBAS total=89 ok=89 fallan=0 omitidas=0

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
verde: c2 con la 61 «omitida», c4 con la 29 a la 36, 50, 51, 53, 56, 61,
62, 69, 73, 76, 81, 84 y 86 «omitidas», nada en rojo. Y con datos de verdad
en el mes (un depósito normal que se parece a un cobro de prueba, la renta, un
pago de préstamo, una distribución, tickets de Home Depot, la balanza de
octubre cargada): las pruebas de c4 miden lo que cambia su escenario, no
el total del mes. El 25-sep se corrió así también, en 16 y en 17.6
(`c4-volumen.sh` corre c4-pruebas sobre 10.000 asientos con su apertura).

Para comprobar que las pruebas no dejan rastro, se saca una «foto» de la
base (cuántas filas y un md5 de cada tabla de `public`, `auth` y `storage`,
el `last_value` de cada secuencia, y las definiciones y permisos de
funciones, triggers, policies, vistas y columnas) antes y después de
correr `c2-pruebas.sql` y `c3-pruebas.sql`: las dos fotos tienen que ser
idénticas. La prueba final del 24-sep lo hizo así, también con asientos y
bandeja ya llenos (después de `fn_puentes_correr()`), y salieron iguales.

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
  tercera ronda de c4 (25-sep): c2-pruebas 79/79, c3-pruebas 117/117 y
  c4-pruebas 89/89 en 16 y en 17.6, con c4 pegado dos veces y encima de la
  versión anterior; los scripts del banco, y c4-volumen con cuatro
  teléfonos, c3-pruebas encima y 2026 abierto y cerrado, en los dos.
- **JIT**: el Postgres del banco trae el compilador JIT encendido (lo de
  fábrica). Con consultas grandes compila más de lo que corre (una vista
  del tablero leída como el editor, 16 s con JIT y 0,15 s sin él; la
  gráfica del Panel, 2,5 s con 10.000 asientos, casi todo compilando):
  `fn_estados_control` y `c4-pruebas.sql` lo apagan para sí (`set jit =
  off`), y `c4-estados.sql` lo apaga para la app: `alter role
  authenticated in database … set jit = off` (PostgREST aplica los
  ajustes del rol en cada consulta, como su tope de 8 s). Para eso el que
  pega tiene que ser dueño del rol o tener ADMIN sobre él: el `00-shim`
  del banco se lo da a `editor_sql` (en Supabase, el SQL Editor lo es).
  `c4-volumen.sh` lee las vistas como PostgREST, con esos ajustes.
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
