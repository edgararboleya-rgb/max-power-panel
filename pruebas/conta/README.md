# Banco de pruebas local de la contabilidad

Un Postgres local que se comporta como el Supabase de producción en lo que
importa para los libros: roles, RLS, privilegios por defecto, `auth.uid()` y
las tablas y triggers reales. Aquí se prueban los `docs/conta/c*.sql` **antes**
de que Edgar los pegue. **Nunca** se conecta a `*.supabase.co`.

| Archivo | Qué es |
|---|---|
| `00-shim-supabase.sql` | Lo que Supabase trae de fábrica: roles `anon`, `authenticated`, `service_role` y `editor_sql`; esquemas `auth`, `extensions` (pgcrypto, uuid-ossp) y `net` (stub); privilegios por defecto. Lo corre el superusuario. |
| `01-replica-esquema.sql` | Las 22 tablas que tocan los libros (con `eventos`, el calendario, que la bandeja del banco de c6 lee), con columnas **idénticas** a producción (generadas desde `esquema-columnas-23sep.json`), `es_dueno()`, `es_activo()`, los triggers existentes, RLS con las policies reales y la vista `recibos_equipo`. |
| `02-semilla.sql` | Datos de prueba con ids fijos (abajo), con valores que producción admite. |
| `02b-restricciones-produccion.sql` | Lo que producción tiene y el banco no tenía, leído el 24-sep: las `id` GENERATED ALWAYS de 13 tablas, los CHECK de valores (recibos: 7 categorías y 5 formas de pago; horas: más de 0 y hasta 16), el UNIQUE de facturas y las llaves foráneas. `correr.sh` lo carga después de la semilla. |
| `c0-banco-pruebas.sql` | El banco se prueba a sí mismo: 18 comprobaciones. **También es el molde** para los `c*-pruebas.sql`. |
| `correr.sh` | Crea una base, carga 00-01-02 y los archivos que le pases. |
| `c2-concurrencia.sh` | Lo que `c2-pruebas.sql` no puede probar en una sola sesión: varias sesiones a la vez contra el libro (cierres con posteos en vuelo, ráfagas, una línea tardía, un cierre en repeatable read). La mitad de los posteos confirma como la app (rol `authenticated`). |
| `c2-pegado.sh` | Lo que pasa AL PEGAR: el bloque A solo, el B encima de datos sucios, las pruebas antes que el libro, volver a pegar c1 y c2, la 7200. |
| `03-storage-simulacro.sql` | Un Storage mínimo (`storage.objects` con RLS y las policies de hoy según ESQUEMA-REAL). **Solo del banco**: con él, la prueba 45 de `c3-pruebas.sql` (el papel no se borra) corre de verdad; sin él sale «omitida». Se pasa ANTES de c3. |
| `c3-concurrencia.sh` | Lo que `c3-pruebas.sql` no puede probar en una sola sesión: el mismo recibo corregido desde dos teléfonos, el backfill mientras alguien guarda, diez recibos a la vez, dos backfills a la vez, dos cobros a la vez a la misma factura (también con su número escrito de otra forma: « 951», «+951»), un cobro mientras se anula la factura, dos anticipos a la vez y dos lecturas del mismo ticket que confirman juntas (entra una; la otra espera como duplicado). Cada sesión confirma (los puentes son diferidos). Sus recibos llevan `creado` de octubre: el reloj del banco es de antes del corte, y un recibo subido antes del corte no entra al libro. |
| `c3-pegado.sh` | Lo que pasa al VOLVER a pegar c3-puentes.sql con las reglas ya tocadas por Edgar: dos pegados seguidos, y otro después de retirar una cuenta que un valor de arranque usaba (la 5600, con su regla ya en la 5500) y de darle a un papel la cuenta que otro tenía de arranque. No se cae, y lo que Edgar puso se queda. Y una base que ya tenía dos recibos con la misma foto antes de c3: anulado el repetido, el siguiente pegado crea `recibos_ruta_unica`, y con él dos subidas a la vez con la misma foto dejan entrar una. |
| `c4-volumen.sh` | Los estados y el tablero con un libro de verdad: la apertura por su balanza y 15 meses hechos **por los puentes** (facturas y cobros parciales, tickets con dos tarjetas, recibos a cuenta y su pago con partida, trabajos externos, la nómina semanal con retenciones, statements repartidos entre obras, gastos del banco y el pago de las tarjetas; 666 por mes ≈ 10.000 asientos, un año largo), con depósitos de verdad que se parecen a los cobros de las pruebas y «hoy» fingido al 20-dic-2027 (solo la hora de ahora cae ese día: cualquier otra fecha es la suya). Lee cada vista como la lee conta.js por PostgREST (`json_agg` de `select *`, el dueño, `authenticated` con los ajustes de ese rol que PostgREST aplica —el `jit = off` de c4— y el tope de 8 s de la API; cada vista con tope de 0,8 s con el volumen de Edgar —200 por mes o menos: los 8 s de la API a la velocidad del banco, que es unas diez veces más rápido que producción— y de 2 s con el libro de esfuerzo, y un aviso sin fallar de las que pasan de 0,2 s y 0,8 s) y `fn_estados_control` como cada pantalla: en una llamada, sin su tope por reloj (tope 8 s), y **como en producción** (ronda 4 de c6): con su tope por reloj en 300 ms (los 3 s de la API), pidiendo otra vez lo que sale «Sigue» como conta.js, cada llamada no más de 0,8 s y la pantalla en seis llamadas o menos (se exige con 250 por mes o menos; con más, el tiempo se informa); y falla si alguna pasa su tope o sale algo en rojo. Después corre `c4-pruebas.sql` y `c3-pruebas.sql` enteros sobre ese libro **mientras cuatro «teléfonos» suben un ticket cada 0,25 s y el Panel lee los bancos**, y otra vez c4-pruebas con los meses de 2026 ya cerrados y un ajuste del CPA a diciembre fechado en febrero (el estado de 2027): falla si alguna subida o lectura se corta por el tope de 8 s, espera 8 s o más, o si un ticket subido se queda sin su asiento (en la bandeja porque una prueba le cruzó los candados). También el control con TODAS las vistas como desde el SQL Editor (tope de 60 s) y **vuelve a pegar `c4-estados.sql` sobre el libro lleno**: lo que tarda y lo que tarda su resumen corto del final (tope de 2 s: es lo que el pegado tiene tomadas las vistas al terminar). Imprime la tabla de tiempos (la de la cabecera de `c4-estados.sql`). `./c4-volumen.sh [bd] [por_mes]` (200 ≈ 3.000 asientos; 1332 ≈ 20.000); con `CONSERVAR=1` deja la base para mirarla. Tarda unos 10 minutos. |
| `c4-concurrencia.sh` | Lo que `c4-pruebas.sql` no puede probar en una sola sesión: la carga de la balanza de apertura y `fn_apertura` en dos sesiones a la vez (una espera a la otra por su candado: la recarga de una balanza que se está posteando la para su guarda, MX003, y el asiento y su papel dicen lo mismo), y dos `fn_apertura` a la vez con la misma balanza (una sola apertura viva). Y **volver a pegar c4 con el tablero leyendo** (una lectura larga del dueño, el pegado medio segundo después y otra lectura mientras espera): el pegado se rinde con 55P03 en menos de 3 s, nadie muere por 40P01, las dos lecturas terminan con sus cifras, y pegado otra vez sin nadie leyendo entra. |
| `c3-volumen.sh` | Lo que pasa con MUCHOS papeles: 3.000 recibos en el libro (un año largo de la cuadrilla), 1.200 facturas, 1.100 cobros y 600 trabajos externos, y la app pidiendo «reintentar puente» (`fn_puentes_correr`) y los controles (`fn_puentes_verificar`) como `authenticated`, con el tope de la API de Supabase (`statement_timeout` de 8 s): terminan, y lo que no cambió (recibos, facturas, cobros, trabajos externos) no se vuelve a planear. Imprime cuánto tardó cada cosa. `./c3-volumen.sh [bd] [recibos]`. |
| `c6-concurrencia.sh` | Lo que `c6-pruebas.sql` no puede probar en una sola sesión: el mismo archivo del banco subido en dos sesiones a la vez (la segunda espera y lo ve: «ya estaba»; sus movimientos entran una vez), dos archivos que se solapan a la vez (lo repetido entra una vez y el segundo lo cuenta), el mismo movimiento resuelto desde dos pestañas (uno casa; el otro espera y recibe MX008), dos «casar» a la vez (ninguna línea del libro casada dos veces), importar y casar mientras cuatro «teléfonos» suben tickets (nadie espera 8 s ni muere por 40P01; cada ticket con su asiento) y volver a pegar c6 con la bandeja leyendo (se rinde con 55P03 en menos de 3 s, o entra; nadie muere). Cada sesión como la app (el dueño, `authenticated` con los ajustes de ese rol, tope de 8 s). `./c6-concurrencia.sh [bd]`; con `CONSERVAR=1` deja la base. |
| `c6-volumen.sh` | El banco con un año de verdad: el libro de `c4-volumen.sh` (≈ 10.000 asientos) y 12 meses de estados de cuenta de Chase y las dos Amex (≈ 10.000 movimientos, 36 archivos QFX, cada uno con su saldo). Mes por mes, como Edgar: importa, casa (como conta.js: otra vez si el motor dice `"completo": false`), resuelve la bandeja (una llamada por movimiento) y concilia y confirma las tres cuentas; los últimos tres meses se atrasa y la bandeja crece. Mide cada llamada con el tope de 8 s de la API, cada vista del banco con 2 s, `fn_banco_control` como cada pantalla, las pantallas de cifras de c4 con el banco en uso **como en producción** (ronda 4 de c6: como en `c4-volumen.sh`, el tope por reloj en 300 ms y cada llamada no más de 0,8 s), la conciliación con la bandeja atrasada, casar otra vez sin nada nuevo con la bandeja atrasada (tope 2 s: lo que no cambió no se rehace), el re-pegado de c6, `fn_banco_verificar` (dos veces) y `c6-pruebas.sql` entera sobre ese año de banco: sola, en menos de 40 s y en verde; y otra vez con cuatro «teléfonos» subiendo tickets (ninguna subida cortada ni de 8 s o más). Al final, los meses 13 y 14 importados sin casar: «Cuadrar» (`fn_conciliar`) con un mes y con dos, no más de 4 s cada una, y casar con ellos en tres llamadas o menos (cada una no más de 8 s). Imprime la tabla de tiempos (la de la cabecera de `c6-banco.sql`). `AL_DIA=0` = un año entero sin resolver nada (≈ 5.000 pendientes); `MOVS=2500` (y `200` por mes) = el año de Edgar (por defecto, 10.000 movimientos); `PLANTILLA=<bd>` copia el libro de una base que dejó `CONSERVAR=1 SOLO_MEDIR=1 ./c4-volumen.sh <bd> 666` (sin rehacerlo). Tarda unos 10 minutos (5 o 6 con plantilla). |
| `c6-en-uso.sh` | Las cuatro suites con el banco YA EN USO, como en producción después de «Después de c6»: la póliza que venía de QuickBooks con su `saldo_corte`, la nómina de octubre del proveedor anterior con su journal (`fn_banco_nomina`) y un ticket de verdad de CED de la segunda obra, con la apertura todavía sin postear; después c2-, c3-, c4- y c6-pruebas, cada una en su sesión: ninguna en rojo (y las seis del devengo de c3 corren, en el primer mes sin journal). Y **noviembre en uso con octubre abierto** (la marcha en paralelo): la primera nómina semanal de noviembre con su journal, y octubre y noviembre amortizados; c3- y c6-pruebas otra vez: ninguna en rojo (las del devengo salen «omitida» por el tope de fecha de c2, y la 22, la 46 y la 88 de c6 porque noviembre ya está amortizado). Antes de la ronda 2 de c6 salían en rojo seis de c3, la 39 y la 53 de c4 y la 46 de c6; antes de la ronda 3, con noviembre en uso, seis de c3 (MX002) y la 22 y la 46 de c6 (MX008). `./c6-en-uso.sh [bd]`; con `CONSERVAR=1` deja la base. |
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
| 5 | `docs/conta/c6-banco.sql` (≈ 1,3 MB). **Si el editor no lo deja pegar entero, sus dos partes**, cada una en su pestaña y con su Run: primero `docs/conta/c6-banco-parte1.sql` y después `docs/conta/c6-banco-parte2.sql` (ronda 4d; abajo, «Si el editor no acepta un archivo tan grande») | **Con las dos partes**: la parte 1 enseña **una fila**, `c6 · parte 1 de 2`, en `true` («Pegada la parte 1 de c6-banco.sql (marca 2026100303). Ahora pega c6-banco-parte2.sql…»), y la parte 2, las 7 filas de abajo: lo mismo que el archivo entero. La parte 2 sin la parte 1 de esta misma versión para con **MX000** («c6-banco (parte 2 de 2) NO se aplicó, no se tocó nada: antes va la parte 1 de esta misma versión…»): pega la 1 y después la 2. Entre las dos el banco queda a medias (su control lo dice en rojo): no uses la app del banco hasta pegar la 2. Cada parte se puede pegar otra vez, como el archivo entero. **Entero, o con la parte 2: 7 filas, todas en `true`**: cuatro `c6 · …` —`tablas` («14 tablas, con la RLS encendida y solo su policy de lectura del dueño»: desde la ronda 4b, también `banco_cuentas_personales`, las cuentas personales de Edgar dadas de alta), `vistas` («8 vistas, todas security_invoker, solo SELECT para authenticated»), `funciones de la app` («21 funciones que llama conta.js (anon ninguna); el resto, sin grant a la API») y `en el reparto de c2`— y tres del control del banco a hoy: `banco · v_banco_saldos` («N filas»: una por banco y tarjeta), `banco · cuadre: protecciones del banco` y `banco · cuadre: c2, c3 y c4 al día` (las dos, «bien»). Una en `false` = parar y avisar. Si sale **MX000** («c6-banco NO se aplicó, no se tocó nada…»; con las dos partes lo dice la parte 1): falta c2, c3 o c4, o alguno es de antes de esta entrega (c2 o c4 con su marca por debajo de 2026100201, c3 por debajo de 2026092601), y dice cuál volver a pegar; o las huellas del libro no son las del último pegado (el control `triggers` de c2 en rojo); o `es_dueno()` cambió desde que se pegó c2 (el candado que dice quién ve los libros y el banco: el control `permisos` en rojo): se mira eso antes, y si el cambio es bueno se vuelve a pegar c2 y después c6. Si sale **55P03** («lock timeout»): la pantalla del banco estaba leyendo; no se pegó nada: ciérrala y vuelve a pegarlo (con las dos partes, la que paró: si fue la 2, la 1 ya está y basta la 2). |
| 6 | Una línea: `select fn_puentes_correr();` | Un solo valor (jsonb) con `"desde": "2026-10-01"`, cuántos papeles quedaron en cada estado (`contabilizado`, `pendiente`, `espera`, `no_aplica`…) y **`"errores": 0`**. |
| 7 | Una línea: `select * from fn_puentes_verificar();` | Los **13 controles** de los puentes, **todos en `true`** (ahora también `sin_evaluar`). `bandeja` dice cuántos papeles esperan a Edgar; solo se pone en rojo si el libro rechazó alguno. |
| 8 | `docs/conta/c2-pruebas.sql` | La tabla `_pruebas`: **83 filas**, todas con `ok = true` (también quedan en `pruebas.c2_resultado`). (La **83**, de la ronda 4 de c6, mide con una función de prueba de unos 4 MB que el control «permisos» ya no relee lo que c4 y c6 sellaron: unos segundos más; sin c6 sale «omitida».) (Con la apertura de verdad ya en el libro, la **61** sale «omitida»; y en cuanto se **cierre el período de la apertura** (`2026-09-APERTURA`, antes que octubre), también la **37** y la **48**, que prueban lo de la apertura abierta. No es un fallo.) |
| 9 | `docs/conta/c3-pruebas.sql` | La tabla `_pruebas`: **120 filas** (también en `pruebas.c3_resultado`), todas con `ok = true` salvo la **45**, que en producción sale «omitida» (Supabase no deja borrar de Storage por SQL; se prueba en el banco). Con la apertura de verdad ya en el libro, la **115** y la **117** (las que postean una apertura de prueba) también salen «omitida»: no es un fallo. Si no hay ningún perfil activo que no sea el dueño, las pruebas «del equipo» salen con `ok` vacío (`null`) y `obtenido` = «omitida…»: no es un fallo. Las seis del devengo (**28, 57, 67, 74, 77 y 99**) devengan en el primer mes abierto **sin journal de nómina**: con la nómina de octubre a diciembre ya en el libro (paso 3 de «Después de c6») corren en el primero que no lo tenga; si todos los meses abiertos ya lo tienen, salen «omitida» y lo dicen (con journal, el devengo estándar se niega: MX008, la regla de c3); y también si ese mes pasa del tope de fecha de c2 (con la nómina semanal, el mes en curso con su primer journal y el anterior todavía abierto: el mes del devengo sería el de después, y no se puede postear todavía), con la **120** diciendo el tope. No es un fallo. |
| 10 | `docs/conta/c4-pruebas.sql` | La tabla `_pruebas`: **113 filas**, todas con `ok = true` (la **112** y la **113** son las de la ronda 4 de c6: el tope por reloj del control y lo que c6 selló; corren sin el tope por reloj, `c4.control_tope = 0` al empezar, y se devuelve al final). **Córrelas recién pegado c4 y ANTES de postear la apertura de verdad**: con ella ya en el libro, las **29 a 36, 50, 51, 53, 56, 61, 62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107** (las que postean una apertura de prueba) salen «omitida», y no es un fallo. Sin nadie del equipo activo, la **2** y la **38** salen «omitida»; la 38, 55, 56, 57, 58, 64, 77, 79, 80, 82, 89, 101, 103, 109, 111 y 113 también si la app estaba usando justo lo que tocan (esperan 2 s y se saltan), y la **113** sin c6. La **109** (el privilegio MAINTAIN) es de Postgres 17: en producción corre; en el banco con 16 sale «omitida». La **88** en rojo = el JIT sigue encendido para la app (ver el paso 4). La **45** finge «hoy» a mitad de mes (el reloj fingido solo va hacia adelante): corre en el primer mes abierto cuyo día 15 no ha pasado, y sale «omitida» solo si no hay ninguno (antes salía «omitida» del día 16 hasta cerrar el primer mes abierto). Con el banco de c6 ya en uso (asientos del banco en el mes, la caja chica fondeada con un retiro, la nómina de octubre, un ticket de la segunda obra con la apertura todavía sin postear) siguen en verde: la **17** cuenta la caja chica en el efectivo final, la **26** y la **53** miran solo lo de su escenario y la **39** le da fondos al banco antes de medir. Tardan entre 50 s y 80 s en el banco (27-sep; el 25-sep, 40 s; el 3-oct, con las 113, 35 s en 16 y 38 s en 17.6: la máquina del banco varía); **en producción (instancia chica) 5 min 47 s, y el SQL Editor se cansa antes y enseña un error de red: la corrida sigue en el servidor hasta el final.** Espera unos 6 minutos y lee el resultado con `select * from pruebas.c4_resultado order by n;` (la misma tabla, con la hora de la corrida). |
| 11 | `docs/conta/c6-pruebas.sql` | La tabla `_pruebas`: **161 filas** (la 101 a la 134 son las de la ronda 4: de la 101 a la 117, el casado y la bandeja; de la 118 a la 128, la entrada —el importador y los lotes— y la seguridad; de la 129 a la 133, la apertura y el primer mes; la 134, el tiempo en producción; de la 135 a la 142, las de la ronda 4b: el dinero al patrimonio del accionista y tu cuenta personal, la reserva y la tarjeta nuevas antes de su primer estado de cuenta, la conciliación del mes sin la de apertura y el anticipo de una obra; de la 143 a la 153, las de la ronda 4c: quién es el otro lado de una transferencia —R3 y lo que se junta a mano, «Desde …» con tu cuenta personal dada de alta, el depósito que nombra una cuenta de la empresa, la transferencia que nombra a alguien sin número, la línea de crédito dada de alta por su número, el orden de los botones, el pase a tu cuenta personal con tu aportación ya clasificada, la baja de la personal—, «TO CHK ...7781», que no es un cheque, y la marca de la versión en la firma de cada propuesta; de la 154 a la 161, las de la ronda 4d: **EL CONTROL** —la 154: lo casado cuyo banco y cuyo libro se contradicen sin su motivo escrito sale en rojo en `fn_banco_control` y en `fn_banco_verificar`, su conciliación no se confirma, y lo coherente no sale—, R1 con un asiento escrito a mano, el cobro que c3 registra con su movimiento, lo que EL CRITERIO no leía —los 4 últimos de tu tarjeta personal, la tarjeta de otro emisor, el cheque, el nombre «1007» de QuickBooks—, el duplicado que trae el número, la partida de la apertura con lo que llega de tu cuenta personal, la línea de crédito dada de alta después y los botones de antes), todas con `ok = true` (también quedan en `pruebas.c6_resultado`, con la hora de la corrida). Usa cuentas de prueba propias (el banco 1098, la reserva 1097 y dos tarjetas ····9996 y ····9995) que se deshacen con cada prueba: ni tus movimientos ni tu apertura se cruzan con ellas, y con el banco ya en uso (lo casado y lo clasificado de verdad, la caja chica fondeada desde el banco, la póliza de QuickBooks con su `saldo_corte`) sigue en verde: cada prueba mide lo que hace su escenario. Si de verdad diste de alta uno de los números que usan las pruebas (tu cuenta personal ····7781, el número de la reserva ····1097 con su lote vacío, o ····1098, ····8896, ····5555), cada prueba lo aparta dentro de ella y vuelve como estaba al deshacerse (ronda 4c; antes salían 38 en rojo, MX004); solo un estado de cuenta de verdad de una cuenta de la empresa que termine como una de prueba las pondría en rojo (MX004: avisa). Pueden salir «omitida» (y no es un fallo): la **10** sin dos días del mes sin visitas en el calendario (o sin `eventos` o sin una segunda obra), y la **96** sin tres días seguidos sin visitas; la **22**, la **46** y la **88** cuando octubre ya está cerrado (prueban la amortización del primer mes) **o cuando ya amortizaste un mes posterior con octubre abierto** (la marcha en paralelo: amortizar octubre entonces se niega, MX008, y es la regla), y la **64**, la **92** y la **99** también (prueban la primera semana y el primer mes después del corte); la **30**, la **63**, la **64**, la **92**, la **99**, la **107**, la **109**, la **110**, la **116**, la **120**, la **140**, la **144**, la **145**, la **146**, la **148** y de la **154** a la **161** si el período de la apertura está cerrado sin asiento de apertura; la **107**, la **109**, la **110**, la **116** y la **140** cuando el mes abierto más antiguo ya no es el primero después del corte (como la 99), y la **109** y la **140** también **en cuanto la apertura de verdad esté posteada** (prueban lo de antes de conciliarla, con una apertura de prueba que lleva el banco 1098); la **129** y la **130** (los Undeposited Funds y los préstamos contra la apertura: postean una apertura de prueba con `fn_apertura`) en cuanto la apertura de verdad esté posteada o con la apertura cerrada; la **34** sin nadie del equipo activo; la **47**, la **88**, la **89**, la **95**, la **99**, la **101** y la **133** sin el mes siguiente abierto; la **72** y la **91** sin la tabla `horas`; la **36**, la **37**, la **47**, la **48**, la **67**, la **71**, la **72**, la **73**, la **91**, la **97**, la **118**, la **121**, la **126**, la **131** y la **133** si la app estaba usando lo que tocan (esperan 2 s y se saltan), y la **153** si alguien cambiaba a la vez la función de la marca del banco (cambia `fn_banco_version` un instante y se deshace). La **61** (va la última) comprueba que nada quedó. Tardan unos 22 s en el banco (20,2 s en 16.13 y 22,2 s en 17.6 el 3-oct, con las 161 de la ronda 4d; con las 153 de la 4c, 19,4 s y 19,9 s; con las 142 de la 4b, 17 s y 18,5 s —con las 134, 19 s y 20 s; con las 128, 17 s y 18 s—; con el año de Edgar encima —`c6-volumen.sh` con 200 por mes y 2.500 movimientos—, 27 s en 17.6 con la 4b; con un año de banco encima —666 por mes y 9.990 movimientos—, 33,7 s en 16 y 36,8 s en 17.6 el 3-oct con la 4d —en otra corrida ese día, 36,0 s y 38,4 s— (la de la 4c, ese día en la misma máquina, 38,5 s en 17.6: lo que añaden las 8 nuevas, unos 2,5 s, lo devuelve la revisión con cuentas, que ya no pide los cuadres del control); con la 4c, 34,5 s y 37,5 s —con la 4b, 32 s y 35,5 s; ese día, sobre la misma base del año, la de la 4b tardaba de 36,4 a 38,1 s en 17.6 y la de la 4c de 38,7 a 41,2 s en copias hechas aparte: el banco de pruebas varía de una corrida a otra; lo que añade la 4c son sus 11 pruebas, unos 2 s—; el día de la 4b, la de la ronda 4 tardaba de 41 a 42 s en 17.6: el banco de pruebas iba más lento que cuando la midió la ronda 4 (38 s), y la 4b le quitó a c6 lo que más pesaba en cada «Casar» y en cada control; el 2-oct, con 117, 35 s; el 27-sep, con 100, 32 s y 38 s; en producción, calcula tres o cuatro minutos: c4-pruebas tarda allí diez veces lo del banco); si el SQL Editor se cansa, `select * from pruebas.c6_resultado order by n;`. |

- **Esta entrega (la ronda 4, la 4b, la 4c y la 4d de c6, 3-oct).**
  **Encima de lo de producción (d80c9de): vuelve a pegar c2 (paso 2), c4
  (paso 4) y c6 (paso 5: el archivo entero o sus dos partes), en ese
  orden; c1 y c3 no cambian. Si ya pegaste la 4c (9849564): solo c6 (paso
  5)**; c2 y c4 no cambian desde la ronda 4. c2 y c4 son los de la ronda 4
  (su marca 2026100201: lo del tiempo en producción, abajo, «La ronda 4 de
  c6, grupo 4»: el control de cada pantalla de cifras con un tope por
  reloj —lo que no cabe sale «Sigue» y conta.js lo vuelve a pedir— y sin
  releer en cada pantalla lo que c6 sella). c6 trae la ronda 4 entera, la
  4b (el dinero del banco no va al patrimonio del accionista —2900, 3100,
  3200, 1130— sin su motivo escrito, salvo de o a una cuenta personal de
  Edgar que él dé de alta, y ningún botón de la bandeja pulsado tal cual
  deja el control en rojo), la 4c (EL CRITERIO del otro lado: una sola
  respuesta, en todos los caminos, a «¿quién es el otro lado de este
  movimiento?») y la 4d (marca 2026100303, abajo, «La ronda 4d de c6»):
  **EL CONTROL**. Cualquier movimiento casado cuyo banco y cuyo libro se
  contradicen sin su motivo escrito —lo casara quien lo casara: «Casar»,
  un botón, un asiento escrito a mano, el cobro que la app registró con
  su movimiento— sale en rojo en el control del banco («cuadre: el otro
  lado de cada casado», que dice cuál y cómo arreglarlo) y en
  `fn_banco_verificar`, y la conciliación de su mes no se confirma hasta
  arreglarlo. Y arregla lo que encontró la prueba final de la 4c (§6): un
  **asiento escrito a mano** y el **cobro que c3 registra con su
  movimiento** ya no casan solos con un movimiento del banco que dice
  venir de otro lado (tu cuenta personal, otra cuenta de la empresa, un
  número que no se conoce); y los menores (los 4 últimos de tu tarjeta
  personal, la tarjeta de otro emisor, un cheque como «la otra mitad»,
  la partida en tránsito de la apertura, Plaid y el QFX del mismo
  movimiento, el nombre «1007» de QuickBooks, el lote vacío que ahora sí
  rehace lo pendiente, los botones de antes). El remedio de mientras («no
  anotes a mano lo que el banco va a traer») ya no hace falta: R1 mira EL
  CRITERIO, y lo que se cuele por otro camino lo dice el control.
  **c6-banco.sql pesa ahora ≈ 1,3 MB**: si el SQL Editor no lo deja pegar
  entero, sus dos partes (paso 5), en orden. Lo que debe verse: c2, sus
  10 controles en `true`; c4, sus 9 filas (en `false` solo «c4 · apertura»
  y «apertura en el libro» mientras no esté la apertura); c6, sus **7
  filas en `true`** (`c6 · tablas` dice «14 tablas»: la 4d no añade
  tablas ni vistas ni cambia lo que llama conta.js; con las dos partes, la
  1 enseña una fila, «c6 · parte 1 de 2», y la 2 las 7). Ninguno toca el
  libro ni lo que Edgar configuró; c6 pegado sin los c2 y c4 de la ronda 4
  para con MX000 y dice qué volver a pegar (c2-libro.sql y
  c4-estados.sql), sin tocar nada. Después, las cuatro suites (pasos 8 a
  11), cada una sola: **83, 120, 113 y 161 filas**. Y en seguida, **antes
  de tocar la bandeja, «Casar»** (`select fn_banco_casar_todo();`): el
  primer «Casar» después del pegado rehace las propuestas de todo lo
  pendiente (con mucho pendiente dice `"completo": false` y se corre otra
  vez). Hasta ese «Casar», lo pendiente no enseña sus botones de antes: su
  texto dice que se corra «Casar» (ronda 4d; antes, un botón que ya no
  valía decía MX008 al pulsarlo). **Y después, el control del banco, una
  vez** (`select * from fn_banco_control('hoy') where not ok;`): si sale
  en rojo «cuadre: el otro lado de cada casado», es algo que una versión
  anterior casó y que se contradice (pegar la 4d no des-casa nada solo);
  qué hacer con cada uno, en el paso 1 de «Después de c6» («Lo casado que
  se contradice»). Después, lo fijo del banco (paso 1 de «Después de
  c6»): da de alta tu cuenta personal (`select
  fn_banco_cuenta_personal('<sus 4 últimos>', 'Chase personal');`) y,
  cuando se abra la reserva, su número; la línea de crédito y cada
  préstamo, también por su número. La prueba final de la ronda 4 (3-oct;
  en §6) encontró dos cosas de la bandeja del banco, que arregló la 4b; la
  de la 4b, siete más, que arregló la 4c; la de la 4c, dos caminos que
  todavía juntaban solos dos lados que se contradicen (y unos menores),
  que arregla la 4d, con EL CONTROL detrás por si algo se cuela.
- **Lo que encontró la prueba final de la 4d (4-oct; §6), y qué hacer
  mientras llega su arreglo.** Todo lo de arriba se comprobó tal cual (de
  cero, con el entero y con las dos partes; encima de d80c9de y de
  9849564 con el banco en uso; idempotente; sin rastro), y EL CONTROL ve
  lo que la 4c dejaba casar solo. Pero hay caminos que EL CONTROL todavía
  no mira (importantes), y hasta su arreglo:
  - **La cuota de un préstamo registrada ANTES que el banco** (con el
    statement del prestamista): mientras espera su cargo, **cualquier
    retiro de Chase a 10 días o menos de su fecha** —el pago de la Amex, el
    pase a la reserva, un cheque, una compra, un pase a tu cuenta
    personal— sale en la bandeja con los botones de la cuota como únicos
    —«Es la cuota de … (la diferencia a capital)» y, si es más que la
    cuota, «(… a interés)»—, sin pedir motivo; pulsado,
    ese retiro queda como la cuota, con un motivo escrito solo, y EL
    CONTROL no lo ve. Mientras: registra la cuota con SU cargo (el botón
    «Cuota de …» del cargo del prestamista), no antes; y si ya está
    registrada, ese botón solo en el cargo del prestamista.
  - **Un cheque devuelto registrado desde la pantalla de cobros**
    (`fn_cobro_devolver`), con un movimiento que no es el del rebote o sin
    movimiento: casa solo con un retiro de ese monto (un pase a tu cuenta
    personal, por ejemplo), la factura vuelve a quedar por cobrar y EL
    CONTROL no mira las devoluciones. Mientras: el rebote, desde la
    bandeja del banco con su movimiento («RETURNED ITEM…»,
    `fn_banco_devolver`); y con `select fecha, monto, descripcion,
    casado_regla from movimientos_banco where casado_clase = 'devolucion';`
    mira que cada uno sea de verdad un rebote.
  - **Un ticket de la débito** casa solo con un pase de Chase del mismo
    monto que llegue ANTES que la compra (con Plaid, o con un QFX bajado a
    mitad de mes) aunque el pase nombre la reserva por su número, y EL
    CONTROL no mira los tickets. Con el QFX del mes entero no casa solo,
    pero el único botón de ese pase es «Confirmar cruce con recibo …», sin
    pedir motivo. Mientras: el QFX de Chase del mes entero, y un ticket
    solo con la compra de su comercio («HOME DEPOT …»), nunca con un pase
    («ONLINE TRANSFER …»).
  - Menores: el número de un préstamo de vehículo dado de alta a 2520 con
    el saldo en 2530 (como lo trae QuickBooks) pone cada cuota en rojo en
    EL CONTROL (es el mismo préstamo): dalo de alta a la cuenta que tiene
    el saldo, o escribe su motivo; y un pase confirmado desde la cuenta
    que recibe («Desde 1010») queda con un motivo escrito solo si el otro
    lado llega con fecha anterior (EL CONTROL ya no lo mirará).
- **Una suite a la vez.** Dos suites corriendo a la vez en la misma base se
  cruzan sus candados: el 27-sep, con c4-pruebas y c6-pruebas lanzadas con
  tres minutos de diferencia, salieron en rojo la 92 de c4 y la 49 de c6
  (40P01, «deadlock detected», entre las dos transacciones) y la 33 de c6
  (55P03 en su TRUNCATE), y «omitida» la 89 y parte de la 103 de c4. No es
  un defecto de las pruebas ni del libro: se espera a que el editor termine
  una (o a que su tabla `pruebas.cN_resultado` tenga la corrida nueva) antes
  de lanzar la siguiente, y se repite la que salió así.
- **Las pruebas dejan su resultado en el esquema `pruebas`** (`c2_resultado`,
  `c3_resultado`, `c4_resultado`, `c6_resultado`: la última corrida, con su hora), fuera de
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
  los tres; c6 (el banco) necesita los cuatro. Las pruebas (8 a 11) van
  siempre después de los cinco: c2, c3 y c4 tienen que seguir en verde con
  c6 pegado (lo están).
- *(Historia: la primera entrega de c6, ya pegada en producción el 27-sep;
  lo que se pega HOY es el punto de arriba, «Esta entrega».)* **c2, c3 y c4
  ya estaban pegados en producción: se volvieron a pegar (pasos 2, 3 y 4)
  antes de c6.** Traían, cada uno, un cambio pequeño para el banco
  («CAMBIOS PARA c6» en su cabecera) y su marca nueva (c2 2026092701, c3
  y c4 2026092601): c2 conoce las funciones del banco en su reparto y en
  sus huellas (su control `permisos` las vigila), `fn_reversar` sobre un
  asiento del banco dice el camino bueno (des-casar) y su sellador ya no
  bendice un `es_dueno()` cambiado cuando resella una fase (c3, c6): el
  candado lo fija solo el pegado de c2; c3 deja soltar el movimiento de
  un cobro solo con la marca de `fn_banco_descasar`; c4 lee en
  `v_asiento_papel` el papel de los asientos del banco (`v_papel_fases`).
  No tocan el libro ni lo que Edgar configuró. Sin volverlos a pegar, c6
  para con MX000 y dice cuál falta; y c2-, c3- y c4-pruebas cuentan sus
  pruebas nuevas (la 81 y la 82, la 119 y la 111).
- **Pega c6 con la pantalla del banco cerrada.** Como c4: el pegado espera
  un candado como mucho medio segundo; si alguien está leyendo el banco,
  para con **55P03** sin pegar nada y sin cortar a nadie
  (`c6-concurrencia.sh`, vuelta 6). Se cierra y se vuelve a pegar.
- *(Historia: la entrega de c4, ya pegada en producción el 26-sep.)* **c2 y
  c3 ya estaban pegados en producción: se volvieron a pegar (pasos 2 y 3)
  antes de c4.** Cambió la forma de sus policies de lectura del dueño
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
  editor. Tardan unos segundos (en el banco, el 27-sep: c2 5 a 15 s, c3 ≈
  5 s, c4 50 a 80 s, c6 16 a 20 s; con el libro lleno, 10.000 asientos: c3 y c4 cerca de
  dos minutos cada una; c6, con un año de banco encima, unos 30 s:
  `c6-volumen.sh` la corre sola, en menos de 40 s, y otra vez con cuatro
  teléfonos subiendo tickets: ninguna subida espera más de unos 3 s). c6-pruebas pide primero el candado del casado
  (el del banco) y después los de los recibos, en el orden de la app.
  **Córrelas sin nadie usando la app, mejor de noche**:
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
  subidas.) La 38, 55, 56, 57, 58, 64, 77, 79, 80, 82, 89, 101, 103, 109 y
  113 de c4 cambian un instante vistas, tablas o funciones de c4, del libro,
  de c3 o del banco (y se deshacen).
- **Si el editor no acepta un archivo tan grande** (`c3-puentes.sql` pesa
  ≈ 470 KB): se puede pegar en dos partes, desde el principio hasta la línea
  `-- ==== BLOQUE B ====` (sin ella), Run, y desde esa línea hasta el
  final, Run. Lo mismo `c2-libro.sql`. En el banco se prueban así con
  `archivo.sql:A` y `archivo.sql:B`. `c4-estados.sql` (≈ 690 KB; ya
  entró así en producción) y `c6-pruebas.sql` (≈ 650 KB) van enteros:
  cada uno es una transacción, y su primera sentencia (el lock_timeout)
  vale para todo el pegado. **`c6-banco.sql` pesa ≈ 1,3 MB** con la 4d
  (la de producción, 2026092704, ≈ 770 KB, entró entera): si el editor no
  lo deja pegar (o protesta por su tamaño, o se queda colgado al
  pegarlo), van sus **dos partes**, `c6-banco-parte1.sql` (≈ 630 KB) y
  `c6-banco-parte2.sql` (≈ 580 KB), en ese orden y cada una con su Run
  (paso 5). Probar primero el entero no cuesta nada: si el editor lo
  rechaza, no se pegó nada. Las partes no se cortan a mano: las genera
  `python3 pruebas/conta/partir-c6.py` desde el archivo entero (que sigue
  siendo la fuente, con su historia; `--comprobar` dice si las partes son
  las de hoy), entre dos sentencias; cada una es su transacción con su
  lock_timeout; la parte 2 comprueba que la parte 1 de su misma marca ya
  está (si no, MX000 sin tocar nada) y termina con el resumen de siempre;
  y las dos juntas dejan la base igual que el entero (`c6-partes.sh` lo
  comprueba con la foto del catálogo).
- **Re-correr la suite en producción** (después de cualquier cambio, o
  cuando se quiera comprobar): pegar otra vez `c2-pruebas.sql`,
  `c3-pruebas.sql`, `c4-pruebas.sql` y `c6-pruebas.sql` (pasos 8 a 11),
  cada una en su pestaña. Y para ver el estado del libro sin tocar nada:
  `select * from fn_verificar_cadena();`,
  `select * from fn_puentes_verificar();`,
  `select * from fn_estados_control('2026-10');` (cualquier período, o
  `'hoy'`: el corte del Panel), `select * from fn_banco_control('hoy');`
  y, la revisión entera del banco (relee los archivos y recalcula las
  conciliaciones confirmadas), `select * from fn_banco_verificar();`.

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

### Después de c6: el banco, mes por mes

Mientras no esté la pantalla del banco en la app, todo se hace desde el SQL
Editor con las mismas funciones que llamará conta.js (el editor cuenta como
Edgar). Los detalles y los ejemplos, en la cabecera de `c6-banco.sql`; en
corto:

1. **Lo fijo, una vez.** Las tarjetas ya están en c3 (`fn_tarjeta_alta`).
   El nombre de verdad de Edgar en el descriptor de su Zelle
   (`select fn_banco_descriptor('zelle_edgar', '<patrón>');`), cada
   préstamo (`fn_prestamo_guardar`, con su statement al 30-sep) y cada
   seguro o fianza pagados por adelantado (`fn_prepagado_guardar`; la
   póliza que ya venía de QuickBooks dice su `saldo_corte`: lo que tenía
   en 1410 al 30-sep, el número de la balanza, no un cálculo).
   El `saldo_inicial` de un préstamo es el del statement del prestamista,
   no el de QuickBooks (que parte las cuotas con su propia tabla). Si la
   apertura trae otra cosa en las cuentas de los préstamos (2520/2530),
   `fn_prestamo_guardar` lo dice en su `aviso` y el cuadre de préstamos
   (`select * from fn_banco_control('hoy', array['cuadre: préstamos']);`)
   nombra la diferencia («la apertura (QuickBooks) trae … y los
   statements … suman …»): con todos los préstamos ya registrados, se
   corrige la apertura —abierta, la balanza corregida y `fn_apertura` con
   su motivo; cerrada, un ajuste a la apertura (`fn_postear` con `tipo`
   `ajuste_cpa`, `afecta_periodo` `2026-09-APERTURA` y su motivo, contra
   3900)—. Sin la apertura posteada todavía, el cuadre sale en rojo y lo
   dice: los préstamos de antes del corte entran con ella.
   **Tu cuenta personal** (la de Chase u otra a la que pasas dinero de la
   empresa, o desde la que le metes), una vez, desde el SQL Editor:
   `select fn_banco_cuenta_personal('<sus 4 últimos>', 'Chase personal de Edgar');`
   (los 4 últimos como los nombra el banco: «ONLINE TRANSFER TO CHK
   ...7781» es `'7781'`; se da de baja con
   `select fn_banco_cuenta_personal('7781', null, false, '<por qué>');`).
   Con ella dada de alta, el dinero a o desde ella se propone como lo que
   es —una distribución (3200), un préstamo al accionista (1130) o lo que
   la empresa te devuelve (2900); al revés, un préstamo tuyo (2900), una
   aportación (3100)— y sus botones entran sin motivo. Sin darla de alta,
   la bandeja no la supone tuya: sale «cuenta_desconocida» y cada botón
   pide su motivo escrito, también «Es la transferencia con …» cuando otra
   cuenta propia tiene un movimiento por lo mismo; y R3 no la junta sola
   con nada (ronda 4c). Darla de alta, o de baja, rehace en ese momento la
   propuesta de lo pendiente que la nombra. (Tu tarjeta personal dada de
   alta en 2900 para tus tickets ya cuenta como personal.) Un número de la
   empresa no se da de alta como personal (MX004).
   **La reserva (1030), cuando se abra**, y cualquier cuenta nueva de la
   empresa antes de su primer estado de cuenta: se da de alta su número
   una vez, desde el SQL Editor, antes de subir el estado de cuenta de
   Chase que traiga el primer pase a ella:
   `select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "<sus 4 últimos>", "confirmo_cuenta": true, "nombre": "1030: su número", "filas": []}');`
   (no pone nada en rojo). Si ya había pendiente algo que nombra ese número
   (un estado de cuenta subido antes), el lote vacío rehace en ese momento
   su propuesta y lo dice («Rehecha la propuesta de N movimiento(s)
   pendiente(s) de otras cuentas que nombran ····…»; ronda 4d: antes había
   que correr «Casar» después, y hasta entonces un botón viejo decía MX008
   al pulsarlo). Con el número dado de alta, el pase sale «A 1030», sin motivo, y casa solo con
   su otro lado cuando se suba el de la reserva. Sin darlo de alta, la
   bandeja no lo supone tuyo ni de la empresa: «cuenta_desconocida», todo
   con su motivo, y el texto dice cómo darlo de alta (la reserva, o una
   tarjeta nueva con `fn_tarjeta_alta`). (Hasta la ronda 4b, ese número se tomaba por tu
   cuenta personal y el primer botón del pase era «Para Edgar (su cuenta
   ····…): distribución · 3200», sin motivo.) Si un pase se tomó por otra
   cosa antes de llegar la reserva, al llegar su estado de cuenta la
   bandeja lo dice («otro_lado_clasificado»): se des-casa aquel, con su
   motivo, y los dos casan solos.
   **La línea de crédito (2510) y cada préstamo (2520, 2530)** (ronda
   4c): su número se da de alta igual, con el lote vacío a su cuenta
   (`"cuenta": "2510"`, sus 4 últimos como los nombra Chase). No traen
   estado de cuenta (no salen en `v_banco_saldos` ni se concilian), pero
   con el número dado de alta el pase de Chase a o desde ella sale
   «deuda_propia» —un pago a la línea, o su desembolso—, sin motivo (sus
   intereses o un cargo, aparte, a su gasto), y la cuota de un préstamo
   registrado sale como siempre. Un desembolso por lo mismo que una
   factura tiene abierto pide su motivo (la regla de un depósito que
   explica una factura), y su texto lo dice («con su motivo»). Un
   desembolso va entero a su deuda (los intereses van en lo que se le
   paga): a un gasto, solo con su motivo (ronda 4d). Sin darlo de alta,
   «cuenta_desconocida», todo con su motivo. Un número que ya es de otra
   cuenta, de una tarjeta o de tu cuenta personal no se da de alta otra
   vez (MX004). Como con la reserva, darlo de alta rehace en ese momento
   la propuesta de lo pendiente que lo nombra. (Prueba final de la 4d,
   4-oct: el número de un préstamo de vehículo, dalo de alta a la cuenta
   que **tiene su saldo** —si la apertura de QuickBooks lo trae todo en
   2530, a 2530—: dado de alta a 2520 con el saldo en 2530, cada cuota
   —el botón «Cuota de …», sin motivo— sale en rojo en EL CONTROL («el
   banco dice …, que es 2520, y el libro dice … 2530», aunque es el mismo
   préstamo) y su conciliación no se confirma hasta escribir su motivo.)
   **Lo casado que se contradice (EL CONTROL, ronda 4d): una vez después
   del primer «Casar», y cada vez que el control lo diga.** El control del
   banco mira cada movimiento casado: si lo que dice el banco del otro
   lado (tu cuenta personal, una cuenta de la empresa por su número, un
   número que no se conoce, alguien sin número, la tarjeta de otro emisor,
   un cheque) y lo que dice su asiento (una transferencia con otra cuenta
   propia, una deuda, tu patrimonio, el cobro de una factura, una partida
   de la apertura, un gasto) se contradicen, y no tiene su motivo escrito,
   sale en rojo:

   ```sql
   select * from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']);
   ```

   (también con todo, `fn_banco_control('hoy')`, y en la revisión entera,
   `fn_banco_verificar()`: «el otro lado de cada casado»). Su detalle dice
   cuántos y cuáles: la cuenta, la fecha, el monto, la descripción, el
   `movimiento` y su `casado`, qué dice el banco y qué dice el libro. Lo
   que una versión anterior casó así sale también (pegar la 4d no des-casa
   nada solo: lo decides tú). Con cada uno:
   - **si de verdad no era ese dinero, des-cásalo** con su motivo
     (`select fn_banco_descasar('<movimiento>', '<por qué>');`) y corre
     «Casar»: la bandeja lo propone como lo que es (tu distribución, tu
     aportación, el pago de tu tarjeta, el pase de verdad). De un pase o un
     pago que R3 juntó salen las dos mitades: **des-casa primero el
     retiro** (el lado que sale, el que puso el asiento), que suelta las
     dos; si des-casas antes el depósito, se suelta solo él, y el retiro
     queda «en_transito» con su asiento: des-cásalo también (la bandeja
     del depósito lo propone, «Des-casar el retiro …», con su motivo). Si
     era el cobro de una factura que la app registró con ese depósito (su
     `clase` dice `cobro`) y no lo es, des-casarlo suelta el depósito pero
     el cobro sigue vigente, con su asiento: anúlalo con su motivo
     (`select fn_cobro_anular('<cobro>', '<por qué>');`; el cobro, en la
     pantalla de cobros o con `select id, fecha, monto, referencia from
     cobros where estado = 'vigente' order by fecha desc;`), y después
     «Casar»; si no, la conciliación lo dice (un cobro en libros sin su
     movimiento del banco). Si un asiento escrito a mano no fue (el pase
     que el banco dice que vino de otro lado), revérsalo con su motivo
     (`select fn_reversar('<asiento>', '<por qué>');`). Si su mes ya tiene
     la conciliación confirmada, des-casarlo dice cuál reabrir antes
     (`fn_conciliacion_reabrir`, con su motivo; la última primero), y
     después se vuelve a conciliar;
   - **si es correcto así** (lo sabes tú: el cliente te pagó a ti y lo
     pasaste a la empresa, la tarjeta se pagó desde tu cuenta a sabiendas…),
     **escribe su motivo**, una vez:
     `select fn_banco_casar_con('<movimiento>', '{"casado": "<su casado>"}', '<por qué es correcto>');`
     (sin motivo, 22023; dos veces, MX008: ya lo tiene). No cambia ninguna
     cifra ni toca su conciliación: queda su motivo, con su rastro, y sale
     del rojo.

   Mientras quede uno en rojo, la conciliación de su cuenta y su mes no se
   confirma (`fn_conciliacion_confirmar` dice cuál y cómo arreglarlo, como
   el control). Sin filas en rojo, nada que hacer. (Probado encima de la 4c
   con el banco en uso, en 16 y en 17.6, con el archivo entero y con sus
   dos partes: un pase a la reserva escrito a mano que R1 casó con lo que
   llegó de tu cuenta personal, el cobro de la #1103 que la app registró
   con el pase de Chase, y una aportación escrita a mano casada con el
   cheque de un cliente. El control dice los tres; la conciliación de
   noviembre de la reserva, confirmada con la 4c, se reabre y no se vuelve
   a confirmar hasta arreglarlos; des-casados los dos primeros —el pase a
   mano reversado, el cobro anulado, y «Casar»: tu préstamo, sin motivo, y
   «Desde 1010»— y escrito el motivo del tercero, el control en verde y la
   conciliación confirmada otra vez.) Esto sustituye la
   consulta de «Lo ya casado por la 4b» de la 4c: EL CONTROL mira todo lo
   casado, por cualquier camino.
2. **La conciliación de apertura (30-sep)**, con la conciliación de
   QuickBooks de esa fecha, una por cuenta:
   `select fn_conciliacion_apertura('1010', '<saldo del statement>', '[<cheques y depósitos en tránsito>]');`
   y `select fn_conciliacion_confirmar('<su id>');`. En octubre, cada
   cheque de esa lista casa solo cuando el banco lo cobra.
   Si QuickBooks tenía **Undeposited Funds** (cobros recibidos y sin
   depositar al 30-sep) y su mapeo los lleva al banco, la conciliación de
   QuickBooks del banco no los trae (allí son otra cuenta): van en la
   lista como depósitos en tránsito, uno por depósito, con su fecha y su
   monto (`{"fecha": "2026-09-29", "monto": "3500.00", "descripcion":
   "Undeposited Funds: …"}`), y en octubre casan solos con su depósito.
   Si no cuadra, el `falta` de la conciliación lo dice: nombra el registro
   del banco en QuickBooks y lo demás que la apertura puso en esa cuenta.
   Uno que no se va a depositar nunca (un saldo viejo): su partida con
   `"clase": "error"` y su motivo, y un ajuste a la apertura.
   Sin ella confirmada, la conciliación del mes (paso 4) no cuadra por lo
   que QuickBooks tenía en tránsito, y su `falta` lo dice: «falta la
   conciliación de apertura de 1010…» (o «no está confirmada», con lo que
   le falta), no «algo del banco no está» (ronda 4b).
3. **Cada mes, cada cuenta**: el QFX entero entre `$ofx$` y `$ofx$`, y casar:

   ```sql
   select fn_banco_importar_ofx($ofx$<el archivo, tal cual>$ofx$, '1010', 'chase-2026-10.qfx');
   select fn_banco_casar_todo();          -- si dice "completo": false, otra vez
   select * from v_banco_bandeja;         -- lo que espera: su propuesta y sus opciones
   ```

   Cada opción de la bandeja dice qué función llamar y con qué (confirmar
   un cruce, registrar el cobro de un depósito, un pago a proveedor, una
   transferencia, clasificar lo que no tiene papel…). Un depósito nunca va
   a ingreso; lo que ya entró por su ticket se casa, no se clasifica. Si
   el ticket de un cargo YA clasificado llega después, la bandeja lo dice
   («llego_su_ticket»): se cambia la clasificación por el ticket
   (`fn_banco_casar_con(<movimiento>, '{"recibo": <id>}')`) o se dice que
   es otra compra (`fn_banco_duplicado(<movimiento>, false, '<motivo>')`).
   También con el mes ya cerrado y su conciliación confirmada: el cambio
   entra sin reabrirla (la clasificación se reversa el día 1 del mes
   abierto, con el ticket, y la conciliación sigue diciendo lo mismo); si
   la cambiaría (con el mes abierto, un ticket con fecha de después del
   corte), dice cuál reabrir. Si el ticket ya está subido pero ESPERA en
   la bandeja de los puentes (c3: sin obra, sin los 4 últimos de la
   tarjeta, su regla en borrador…), la bandeja del banco lo dice
   («ticket_en_bandeja», con el recibo y lo que espera): se resuelve allí
   (`select * from puentes_bandeja;`) y el cargo casa solo; clasificarlo
   pide motivo (el gasto entraría dos veces).
   La nómina del proveedor anterior (octubre a diciembre, antes de Gusto
   y f11) entra con su journal, también la que solo lleva el sueldo de
   Edgar (6000/6005, con lo retenido):
   `select fn_banco_nomina('<movimiento>', '[<las líneas del journal sin la del banco>]');`.
   Una tarjeta se puede decir por su código corto (`'2013'`) en importar,
   casar, conciliar y la apertura.
   Un cargo que se parece a un ticket con OTRO total (el ticket leído sin
   el tax) sale «otro_total»: se corrige el total del recibo en la app y
   casa solo (clasificarlo pide motivo). Un depósito de QuickBooks
   Payments o Stripe, neto de su comisión, se cobra por el bruto con
   `{"comision": "29.30"}` en la lista de `fn_banco_cobrar` (la bandeja lo
   propone). El cheque que rebota de un depósito de varios cheques tiene
   su botón (`fn_banco_devolver` con la aplicación de la factura que
   rebotó): el cobro se devuelve y lo demás se registra otra vez ese día.
   Los lotes de Plaid traen su saldo en `plaid_saldo` (tal cual lo da
   Plaid; la base lo voltea en una tarjeta).
   (Ronda 4) El PRIMER estado de cuenta de un banco entra con su aviso
   (el número y el banco que dice el archivo): si entró a la cuenta que no
   era, se retira antes de seguir, desde el SQL Editor,
   `select fn_banco_archivo_retirar('<id del archivo>', '<por qué>');`
   (sus movimientos quedan ignorados, con rastro; lo que se casó con
   ellos se deshace), y se vuelve a subir a la suya. Un depósito que no
   cuadra al centavo con un cobro ya anotado lo propone primero («neto de
   su comisión» o «corrígelo», con su motivo); la cuota del préstamo ya
   registrada que el banco cobra por otro monto, también («es ella»: la
   diferencia a capital o a interés; **ojo, prueba final de la 4d**: con
   una cuota registrada que espera su cargo, ese botón sale en TODO retiro
   de su banco a 10 días o menos —también el pago de la Amex, el pase a la
   reserva o a tu cuenta personal, un cheque—, sin pedir motivo, y pulsado
   deja un motivo escrito solo que EL CONTROL toma por el tuyo: púlsalo
   solo en el cargo del prestamista, o registra la cuota con su cargo y no
   antes); el ticket repartido entre obras que
   llega después de clasificar, «Es su ticket (repartido)». El dinero a o
   desde tu cuenta personal dada de alta (paso 1; el banco nombra «CHK
   ...7781») sale como distribución o préstamo del accionista, sin
   motivo, y el control sigue en verde aunque haya una factura abierta del
   mismo monto (el asiento dice de qué cuenta personal viene); una
   transferencia a una cuenta propia, ahí, pide su motivo. (Ronda 4b) Lo
   que va al patrimonio del accionista sin esa cuenta dada de alta (el
   «para mí» del cajero, el Zelle de Edgar, un número que no se conoce)
   pide su motivo escrito: `fn_banco_clasificar(<movimiento>, <sus
   líneas>, '<por qué>')`. Un depósito que explica una factura abierta o
   un cobro anotado de su monto no se clasifica ni entra como anticipo de
   una obra sin su porqué. (Ronda 4c) Un pase que el banco nombra por un
   nombre y no por su número («ONLINE TRANSFER TO EDGAR M PERSONAL») sale
   «otro_lado_nombrado»: la bandeja no lo supone ni de una cuenta de la
   empresa ni tuyo, y sus botones (las cuentas propias, el patrimonio)
   piden su motivo; si nombra a un proveedor, su pago, como siempre. Un
   depósito que nombra el número de una cuenta de la empresa («FROM CHK
   ...4392») es su transferencia: «Desde 1010» primero y sin motivo; el
   cobro de una factura, solo con su motivo, aunque el estado de cuenta de
   la reserva llegue antes que el de Chase. Dos lados que se contradicen
   (uno nombra tu cuenta personal, un número que no se conoce u otra
   cuenta) no casan solos; la bandeja ofrece juntarlos con su motivo, o
   des-casar el que puso la transferencia. (Ronda 4d) Lo mismo con un
   asiento escrito a mano (R1: «Confirmar cruce con …» pide su motivo si el
   banco dice otro lado) y con el cobro que la app registró con su
   movimiento («cobro_que_lo_nombra»: es su cobro, con su motivo; o no lo
   es, y se anula ese cobro). Mientras la apertura de un banco no
   esté conciliada, un cheque o un depósito de los primeros 30 días lo
   avisa en su propuesta: con la apertura ya posteada, clasificarlo o
   cobrarlo pide motivo (puede ser de septiembre).
   (Para conta.js: después de importar un archivo, `fn_banco_casar_todo`
   con su cuenta y su primera fecha — `p_cuenta`, `p_desde` — mira solo
   eso; sin ellos también vale: lo que no cambió no se rehace.)
4. **Conciliar y confirmar** cada cuenta a su fecha de corte (una tarjeta,
   la de su statement):

   ```sql
   select fn_conciliar('1010', '2026-10-31', '25,310.44');   -- el saldo final del statement
   select * from v_conciliacion_partidas where cuenta = '1010' and fecha_corte = '2026-10-31';
   select fn_conciliacion_confirmar('<id de la conciliación>'); -- solo con diferencia 0.00 y nada sin casar
   ```

   Si el saldo que escribes no es el que trae el archivo del banco ese día
   (`n_pide_motivo`), no se confirma hasta decir por qué, con el documento
   que lo respalda (desde el SQL Editor):
   `select fn_conciliacion_saldo('<id>', '<por qué>', '<el statement>');`.
   Lo mismo una partida de la apertura que no llegó: su motivo con
   `fn_conciliacion_partida` (pasa sola a los meses siguientes mientras
   siga en tránsito). Una conciliación hecha con la fecha mal escrita no
   se crea si va detrás de la última confirmada; una ABIERTA hecha por
   error se quita desde el SQL Editor:
   `select fn_conciliacion_anular('<id>', '<por qué>');`. Reabrir va en
   orden: la última confirmada primero.

5. **Antes de cerrar el mes**: **cada cuenta, hasta el último día del
   mes.** El statement de una tarjeta corta a mitad de mes (la Blue el 7,
   la Gold el 22): lo del corte al 31 se baja como actividad reciente (el
   QFX de la tarjeta hasta ese día; el statement siguiente trae lo mismo y
   no se duplica). Terminado el mes, el control entero (sin pedir vistas),
   `select * from fn_banco_control('2026-10') where not ok;`, dice en
   «cuadre: cada cuenta hasta el fin del mes» cuál no llega, y
   `v_banco_saldos` lo enseña en `cubierto_hasta`, `mes_sin_cubrir` y su
   alarma. No frena el cierre (ni ninguna pantalla): lo que no entre antes
   de cerrar entra el mes siguiente como tardío. Las cuotas de los
   préstamos casan con su movimiento (`fn_prestamo_cuota`) y
   `select fn_prepagados_amortizar('2026-10');` postea lo del mes. Una
   póliza ya amortizada que hay que corregir (otra cuenta de gasto, otra
   obra) se registra como la que la sustituye:
   `select fn_prepagado_guardar('{"sustituye": "<id de la vieja>", "cuenta_gasto": "5015"}');`
   (lo amortizado de la vieja vuelve en el mes abierto y la nueva lo
   amortiza desde su inicio); una cancelada de verdad, con su fecha y lo
   que devolvió la aseguradora:
   `select fn_prepagado_guardar('{"id": "<id>", "estado": "cancelado", "cancelado_al": "2026-12-15", "devuelto": "9000.00"}');`
   y el depósito de la aseguradora, clasificado a 1410.
6. **El control**: `select * from fn_banco_control('hoy');` (todo en
   `true`; con todo —sin pedir vistas— dice también si cada cuenta llega
   al fin de cada mes ya terminado y sin cerrar, y —ronda 4d— si algo
   casado se contradice, «cuadre: el otro lado de cada casado», con qué
   hacer en el paso 1; un cuadre suelto, por su nombre:
   `fn_banco_control('hoy', array['cuadre: prepagados'])`) y, de vez en
   cuando, `select * from fn_banco_verificar();` (relee cada archivo fila
   por fila y recalcula las conciliaciones confirmadas en las que algo pudo
   cambiar; de una cuenta: `fn_banco_verificar(array['1010'])`, sin los
   cuadres del control, que miran todo el banco: ronda 4d).

### La ronda 2 de c6 (27-sep): lo que no se hizo, y por qué

Los 26 hallazgos confirmados se arreglaron (cada uno con su prueba; la
lista, en la cabecera de `c6-banco.sql`, «LA RONDA 2 DE CORRECCIONES»),
salvo tres partes, a propósito:

- **La cuenta ya escogida para la luz y el seguro (6110/6200)** que
  sugería el arreglo del hallazgo de AUTOPAY. Lo que rompía las reglas sí
  se arregló (AUTOPAY ya no casa solo como pago de la tarjeta, las
  devoluciones van contra el costo de su ticket, la transferencia pide
  motivo): el cargo de la luz sale «sin ticket» con su camino
  (`fn_banco_clasificar`) y espera a Edgar. Escoger la cuenta por el
  nombre del comercio es el motor de reglas de f07 (las reglas que Edgar
  dicta: «este proveedor siempre va a esta cuenta»); hacerlo aquí por
  palabras sueltas propondría cuentas sin papel detrás.
- **Poner en rojo el reparto corriente / largo plazo de un préstamo
  (2520/2530) que no dice lo mismo que `v_prestamos`**. La cuota ya baja
  la cuenta que tiene el saldo y el cuadre 55 pone en rojo una cuenta de
  préstamo deudora (lo que el balance enseñaba mal). La reclasificación
  de la porción corriente es un asiento de cierre (f08): exigirla cada mes
  dejaría el control en rojo entre cierres, y Edgar aprendería a no
  mirarlo.
- **La función de trigger ajena en el control `permisos` de c2 y en las
  protecciones de c4.** El hallazgo era del banco: el cuadre 90 de c6 ya
  la ve. c2 y c4 tienen el mismo alcance desde antes (lo dijo la
  verificación: se arregla cuando se vuelvan a tocar); meterla en c2 pide
  conocer las funciones de trigger de c3 que ya leen el libro (los
  puentes, `fn_proyectos_con_libro`) para no pintar rojo en producción,
  con su prueba propia: un cambio de alcance de c2, no uno mínimo.
  c4-estados.sql no se toca en esta ronda.

### La ronda 3 de c6 (27-sep): lo que no se hizo, y por qué

Los 21 hallazgos confirmados (el 7 y el 17 son el mismo: el saldo de
Plaid) se arreglaron, cada uno con su prueba (la lista, en la cabecera de
`c6-banco.sql`, «LA RONDA 3 DE CORRECCIONES»; las pruebas, de la 83 a la
100 de c6-pruebas, la 120 de c3-pruebas y la segunda vuelta de
`c6-en-uso.sh`). Lo que se hizo distinto de lo que sugería el hallazgo, a
propósito:

- **El cheque que rebota de un depósito de varios no es una devolución
  PARCIAL en c3.** `fn_cobro_devolver` devuelve cobros enteros, y hacerla
  parcial pedía cambiar su tabla (una devolución por cobro) y su puente:
  no es un cambio mínimo. c6 lo resuelve con lo que c3 ya da: devuelve el
  cobro entero en la fecha del banco y registra otra vez, ese mismo día,
  lo que no rebotó (un cobro nuevo, con sus aplicaciones); el movimiento
  casa con las dos líneas. El libro queda bien (la factura del cheque
  rebotado por cobrar, la otra cobrada, el mes del depósito sin tocar); la
  factura que no rebotó aparece cobrada otra vez el día de la devolución.
  Un cobro que lleva un anticipo no se parte solo: lo dice y da el camino.
- **La guarda de clasificar sigue para el cheque o el ACH SIN nombre** que
  la bandeja propone como abono a un proveedor (la prueba 76 de la ronda
  2: clasificado a la obra, el material contaba dos veces). Lo que nombra
  a otro (la luz, el seguro, un Zelle a una persona) ya no sale como
  abono y se clasifica sin motivo.
- **La firma de las propuestas de los DEPÓSITOS sigue mirando todas las
  facturas abiertas**, y la de los cargos del banco, todas las cuotas. Un
  depósito puede ser una PARTE de cualquier factura abierta mayor que él
  (y ahora una factura cobrada con tarjeta, neta de su comisión): una
  factura nueva sí puede cambiar su propuesta. Los préstamos cambian una
  vez al mes. Lo que rehacía todo con cada ticket (la 2010 en la firma de
  todos los cargos) ya no.
- **El ticket de otro total que llega DESPUÉS de clasificar** solo se
  marca («llego_su_ticket», el cuadre 57, posible duplicado en la
  conciliación) si el banco nombra su comercio; antes de clasificar
  también basta con que el monto no se separe más de un 12 %. Después de
  clasificar, lo que queda es un ticket libre: si no se le parece por el
  nombre, la conciliación lo pide igual (un ticket de más de 10 días sin
  su cargo pide su motivo).
- **Un cargo con varios tickets de otro total propone los tres que más
  se le parecen** (el monto más cercano primero), no todos: con 300
  tickets libres de Home Depot, cada cargo de Home Depot sin ticket se
  parecía a decenas, y la bandeja (y su firma) los llevaba todos. Con 1.500
  cargos y 300 tickets libres en una tarjeta, «Casar» sin nada nuevo tarda
  0,6 s en 17.6 (el primero, con las 1.500 propuestas, 2,5 s).
- **La obra con visitas a varias obras esos días no se propone**: la
  bandeja dice cuáles y qué día («elige la obra»).
- **La póliza que sustituye a otra va en la misma cuenta del activo**
  (1410 o 1420): el dinero de la póliza está ahí; moverlo de cuenta es un
  asiento, no una sustitución.
- **Las pruebas de prepagados (22, 46 y 88) salen «omitida»** cuando ya se
  amortizó un mes posterior al primero abierto, en vez de amortizar el
  último: sus cifras son las del primer mes después del corte.

### La ronda 4 de c6, grupo 1 (2-oct): el casado y la bandeja

**Qué se pega** *(esto era así ANTES del grupo 4, que cambió c2 y c4: lo
que se pega de la ronda 4 entera es lo del grupo 4, más abajo —c2, c4 y
c6, en ese orden— y lo que dice «Esta entrega» en §0)*: solo
`c6-banco.sql` (paso 5) y después `c6-pruebas.sql` (paso 11). c2, c3 y c4
no cambiaban (sus marcas eran c2 2026092701, c3 y c4 2026092601).
El pegado de c6 enseña sus **7 filas en `true`** (las de siempre) y su
marca pasa a **2026100201**; c6-pruebas, **117 filas en verde** (con las
«omitidas» de la lista del paso 11). Encima del c6 de producción
(2026092704) con el banco ya en uso entra sin tocar nada de lo guardado:
añade `conciliaciones.falta` y las columnas `retirado_*` de
`archivos_banco` (solo si faltan), cambia el sha256 único de los archivos
por uno de los vivos (hoy son todos) y rehace dos funciones internas. Las
propuestas cuyo texto cambió se rehacen en el siguiente «Casar».

Los 17 hallazgos se arreglaron, cada uno con su prueba (de la 101 a la
117; la lista y el porqué, en la cabecera de `c6-banco.sql`, «LA RONDA 4
DE CORRECCIONES»). El del primer estado de cuenta subido a la cuenta
equivocada es el mismo que el del grupo del importador: se arregló aquí
una vez (la 111, con `fn_banco_archivo_retirar`). Lo que se hizo distinto
de lo que sugería el hallazgo, a propósito:

- **La transferencia de fin de mes (101)** toma la segunda rama de la
  decisión de la ronda 3: si fecharla al día siguiente de la confirmada
  deja partido el estado de cuenta del otro lado, no se postea sola y se
  dice qué reabrir. Para una tarjeta sin conciliaciones todavía, su corte
  es el «hasta» de su archivo (el banco lo cobra días después del corte:
  descargar el archivo hasta unos días más lo resuelve sin reabrir nada).
- **Lo trabajado antes de conciliar la apertura (109)**: el aviso sale
  siempre en los primeros 30 días; pedir motivo, solo con la apertura ya
  posteada y la cuenta en ella. Hoy, sin la balanza, pedirlo haría escribir
  un motivo a cada cheque de octubre; lo que se clasifique así, la
  conciliación de apertura lo nombra después y frena.
- **La cuenta personal de Edgar (113)** se reconoce porque su número no es
  de ningún estado de cuenta ni tarjeta de la empresa, sin un descriptor
  nuevo: una cuenta propia que todavía no subió su estado de cuenta (la
  reserva) sale también como «personal» hasta subirlo, y la transferencia
  a ella se hace con su motivo (la prueba 16 lo dice).
- **Los intereses que solo el MEMO llama así (116)**: la guarda de 4910 mira
  NAME y MEMO, como la propuesta (el MEMO también lo escribe el banco), en
  vez de marcar el botón «pide motivo».
- **«Línea 1» (117)**: el error de c2 se dice con el número de Edgar en vez
  de repetir aquí las reglas de c2 (obra, cost code, cuenta activa): así
  no pueden separarse.

### La ronda 4 de c6, grupo 2 (3-oct): la entrada (el importador y los lotes) y la seguridad

**Qué se pega** *(antes del grupo 4; para la ronda entera, ver el grupo
4)*: lo mismo que el grupo 1 (es la misma entrega y la misma
marca, **2026100201**): solo `c6-banco.sql` (paso 5) y después
`c6-pruebas.sql` (paso 11); c2, c3 y c4 no cambiaban. c6-pruebas, **128
filas en verde** (con las «omitidas» de la lista del paso 11). Encima del
c6 de producción (2026092704) con el banco en uso entra sin tocar nada de
lo guardado: añade un índice (las marcas «quitada:») y tres funciones
internas, y las propuestas que se rehagan llevan su `firma_g` (las de
antes siguen como están). Una conciliación ya confirmada con el saldo de
un lote que contradecía al OFX de su día, sin motivo, saldría en rojo en
el cuadre 54 (era el agujero): se reabre y se confirma con su motivo.

Los 12 hallazgos: 11 se arreglaron, cada uno con su prueba (de la 118 a la
128, y la 63, que ahora prueba también cobrar y pagar al proveedor; la
lista y el porqué, en la cabecera de `c6-banco.sql`, «Y LA ENTRADA … Y LA
SEGURIDAD»). El del primer QFX subido a la cuenta equivocada es el mismo
que el del grupo 1: ya estaba arreglado (la 111). Lo que se hizo distinto
de lo que sugería el hallazgo, a propósito:

- **Clasificar rehace la propuesta (119)**, como «Casar» ese movimiento,
  en vez de decir «corre Casar»: sin motivo escrito, cuando no la tiene o
  cuando cambió lo que mira (la propuesta guarda ahora su `firma_g`: lo
  que se cobra y las facturas, los proveedores y lo que se les debe, los
  préstamos, los descriptores). Al día no la rehace: rehacerla siempre
  costaba, con un año de banco, 0,2 s más en cada clic (en c6-volumen, la
  llamada media de la bandeja pasaba de 0,06 a 0,23 s). Con motivo
  escrito no mira la propuesta (ningún freno que la lee aplica), y lo
  que casaría con él, su ticket de otro total, la cuota y la apertura se
  miran en el momento de todos modos.
- **El número de la Gold (123)**: QuickBooks la nombra «Amex Gold
  (1007)»; si su QFX trae ese número, entra a 2100-2013 sin darlo de alta,
  porque la apertura ya lo dice (`apertura_mapeo_qb`). Una tarjeta nueva de
  la empresa (la reposición de una perdida, una adicional) se da de alta
  una vez con `fn_tarjeta_alta`, como dice el error.
- **El saldo de un lote frente al OFX del mismo día (118)** no cuenta para
  el cruce (solo se avisa); sin OFX ese día, dos lotes que no coinciden
  piden motivo, como dos OFX.
- **Lo quitado (127, 128)**: el contrato del lote es `"quitadas": [ids]`
  (lo que la sincronización de Plaid devuelve en «removed»), y el `DELETE`
  del OFX hace lo mismo. Lo pendiente se ignora solo (no fue, y no toca el
  libro); lo casado no se des-casa solo —des-casar reversa un asiento, y eso
  lo decide Edgar—: lo dicen la bandeja (con su botón) y el cuadre 51.
- **El tope de la comisión (122)** es el que ya usaban la propuesta y
  `fn_banco_casar_con` (un 3.5 % más 0.30 de cada factura), no un 10 %; por
  encima pide motivo, no lo prohíbe. Y, como sugería la verificación, un
  depósito que no nombra a ningún procesador de tarjetas (un Zelle de
  970.70 contra una factura de 1,000.00) también pide motivo para llevar
  la diferencia a comisión: la bandeja propone primero la parte de la
  factura (el pago parcial).
- **La función de borde de Plaid** (cuando llegue) manda `saldo_al` con el
  saldo (sin él, 22023) y, si Plaid da la moneda (`iso_currency_code`), la
  manda en `"moneda"`: otra que USD no entra (MX009).

### La ronda 4 de c6, grupo 3 (3-oct): la apertura y el primer mes

**Qué se pega** *(antes del grupo 4; para la ronda entera, ver el grupo
4)*: lo mismo que los grupos 1 y 2 (es la misma entrega y la
misma marca, **2026100201**): `c6-banco.sql` (paso 5; enseña sus **7 filas
en `true`**, las de siempre) y después `c6-pruebas.sql` (paso 11): **133
filas en verde**, con las «omitidas» de la lista del paso 11. c2, c3 y c4
no cambiaban (hasta el grupo 4). De las pruebas cambió también
`c4-pruebas.sql` (solo su prueba 45): conviene correrla otra vez (paso
10, **111 filas**), ya sin la 45 «omitida» después del día 15. Encima del
c6 de producción (2026092704) con el banco en uso entra sin tocar nada de
lo guardado: una función interna nueva (`fn_banco_apertura_filas`), dos
columnas más al final de `v_banco_saldos` (`cubierto_hasta` y
`mes_sin_cubrir`) y una nota en el casado de `v_conciliacion_partidas`;
las propuestas de los cargos con un ticket esperando en c3 se rehacen en
el siguiente «Casar».

Los 6 hallazgos: cinco se arreglaron en c6, cada uno con su prueba (de la
129 a la 133; la lista y el porqué, en la cabecera de `c6-banco.sql`, «Y
LA APERTURA Y EL PRIMER MES»), y el sexto era este README (las «omitidas»
de c2 con la apertura cerrada y la 45 de c4-pruebas, que ahora corre en el
primer mes abierto cuyo día 15 no ha pasado). Lo que se hizo distinto de
lo que sugería el hallazgo, a propósito:

- **Cada cuenta hasta el fin del mes (131)** es un cuadre del control
  entero (`fn_banco_control('2026-10')`, sin pedir vistas) y una alarma de
  `v_banco_saldos`, no un freno: ninguna pantalla deja de pintar y cerrar
  el mes no lo mira; se mira antes de cerrar (paso 5 de «Después de c6»).
  Lo que un mes así deja fuera no se anota solo como «puente» (lo dijo la
  verificación): entra el mes siguiente, tardío.
- **El ticket de un cargo clasificado que llega con el mes cerrado (133)**
  se cambia sin reabrir solo si la conciliación confirmada sigue diciendo
  lo mismo (lo comprueba el cambio mismo: sus partidas y su saldo en
  libros); si la cambiaría, pide reabrirla, como antes.
- **El ticket que espera en la bandeja de los puentes (132)** no necesita
  un «paso 0» en el README (la verificación): la bandeja del banco lo dice
  sola. Se busca por su monto (o uno del mismo comercio a 12 % o menos) en
  la ventana de la compra y, si trae los 4 últimos, por su tarjeta; solo el
  comercio o solo un monto parecido no bastan (la bandeja de c3 es de
  todas las cuentas: un ticket de Shell de 60.00 no es el cargo de 64.20 de
  la ferretería).
- **No se cambió el mensaje de c2** sobre el ajuste del CPA a una apertura
  todavía abierta (el hallazgo de los préstamos lo dejaba opcional):
  obligaría a volver a pegar c2 —y a resellar c3, c4 y c6 y correr sus
  cuatro suites— por un texto; el cuadre de préstamos y el aviso de
  `fn_prestamo_guardar` ya dicen el camino bueno (paso 1 de «Después de
  c6»). Va con el próximo cambio de c2.

### La ronda 4 de c6, grupo 4 (3-oct): el tiempo en producción

**Qué se pega**, en este orden: `c2-libro.sql` (paso 2: sus **10
controles en `true`**), `c4-estados.sql` (paso 4: sus **9 filas**, las de
siempre: en `false` solo «c4 · apertura» y «apertura en el libro»
mientras no esté la apertura) y `c6-banco.sql` (paso 5: sus **7 filas en
`true`**). c1 y c3 no cambian. Después las cuatro suites, cada una sola:
**83, 120, 113 y 134 filas** en verde. c6 pegado antes que c2 y c4 para
con MX000 y dice cuáles volver a pegar, sin tocar nada. Nada de lo
guardado cambia: probado encima de producción (d80c9de) con el banco en
uso, en 16 y en 17.6 (la foto de movimientos, propuestas, casados,
conciliaciones, partidas, historial, archivos, asientos, saldos, el mapeo
de c4, los períodos, las cuentas y los puentes, igual antes y después del
pegado, después de casar otra vez y después de las cuatro suites).

La razón: **producción es unas diez veces más lenta que este banco**
(c4-pruebas: 5 min 47 s allí, 40 s aquí) y la API corta cada llamada a
los 8 s (57014). Lo que aquí tarda 0,8 s, allí no cabe. Los 2 hallazgos,
los dos arreglados, cada uno con su prueba:

- **Las cuatro vueltas de lo ajeno (R1).** Con c6 pegado, «protecciones
  de c4» (en el control de cada pantalla de cifras) y el control
  `permisos` de c2 leían en cada llamada el texto de las cien funciones
  internas del banco (1,2 MB), vuelta tras vuelta: cuatro, porque dos del
  banco leen tablas de c4 a propósito y `fn_banco_control` nombraba
  funciones de c4 con su paréntesis en sus mensajes. Ahora lo que c6 selló
  (y c4, para c2) y no cambió no se relee —se lee la huella, como ya se
  hacía con lo de c2—, las candidatas se juntan una vez y c6 ya no nombra
  funciones de c4 así. Lo ajeno de c4 pasó de 230-260 ms a 20-35 ms por
  pantalla; `permisos`, de 190-340 ms a unos 50. Pruebas: la **113** de
  c4-pruebas y la **83** de c2-pruebas (con una función «del banco» de
  4 MB: sellada, no se lee; se mide la proporción) y la **134** de
  c6-pruebas (ningún nombre de c4 con su paréntesis en el banco).
- **El control del Panel con un año de verdad (R2).** Con el volumen de
  Edgar (unos 200 papeles por mes) y un año de banco, el control del Panel
  (9 vistas) tardaba de 1,1 a 1,8 s en el banco: de 11 a 18 s en
  producción. Ahora (a) cuesta la mitad: 0,7-0,8 s en una llamada (lo que
  el libro espera sin subconsultas por línea; las huellas de las vistas
  por su árbol guardado; la gráfica del Panel, el dinero por obra y el
  flujo de inversión sin recorrer el libro de más; mismas filas y cifras
  en las 27 vistas); y (b) tiene un **tope por reloj**: desde la API cada
  llamada se da 3 s; lo que no cabe sale con `ok` nulo y «Sigue: …» (con
  la llamada que lo pide) y no se pinta hasta que otra llamada lo
  controle. Con el año de Edgar y el banco en uso, el Panel sale en tres
  o cuatro llamadas, la más lenta de 0,5 s en el banco (unos 5 s en
  producción); 'hoy' y los estados, en dos. Prueba: la **112** de
  c4-pruebas. Y `c4-volumen.sh` y `c6-volumen.sh` miden ahora así, como
  en producción (el tope por reloj en 300 ms, cada llamada no más de
  0,8 s, la pantalla en seis llamadas o menos), y lo exigen con el
  volumen de Edgar.

**De paso** (lo encontró la corrida final de `c4-volumen.sh`, con los
teléfonos y el Panel leyendo mientras corre c4-pruebas): la **89** de
c4-pruebas pedía los dos candados del libro (los asientos y sus líneas)
esperando con el primero ya tomado; una lectura del Panel que ya tenía las
líneas y esperaba los asientos quedaba cruzada con ella, y Postgres
cortaba la lectura de la app (40P01). Ahora los pide juntos y sin esperar
(reintenta cada 0,1 s, unos 2 s, y si no, «omitida»). Y la **80** mira
también una vista de c4 cambiada (sus huellas se toman ahora de su árbol
guardado).

**Y lo fijo de cada «Casar», en c6** (lo encontró la corrida de
`c6-volumen.sh` con 666 por mes: c6-pruebas sola, con un año de banco
encima, tardaba de 41,9 a 42,2 s en 17.6, y su tope es 40 s; no por lo de
este grupo —con el c2 y el c4 de antes tardaba lo mismo—, sino porque la
suite casa más de doscientas veces). El contexto de las facturas buscaba
las cuentas de cobro cuatro veces por cada línea de las facturas
(Postgres metía su consulta dentro de la otra: ahora se lee una vez); la
firma de las propuestas y el estado de la apertura de cada cuenta
buscaban el asiento de apertura recorriendo el libro (ahora en el período
de la apertura, el único donde c2 lo deja vivir: lo encuentra su índice);
y los cargos a los que «llegó su ticket» se buscaban leyendo cada
movimiento del banco (ahora por su cuenta). Las mismas respuestas: la
firma de las propuestas sale igual (pegado encima del de antes con 2.313
pendientes, «Casar» no rehízo ninguna). c6-pruebas sola, ahora: 38,1 s en
17.6 y 32,4 s en 16; con cuatro teléfonos, 43,2 s y 37,1 s. Y
`c6-volumen.sh` y `c4-volumen.sh` miran el error en toda la salida de
cada llamada: con `VERBOSITY=verbose` la última línea de un error es
«LOCATION: …», y miraban solo esa (un error —un 57014 del tope— pasaba
por una respuesta; con `AL_DIA=12`, la conciliación del último mes, ya
confirmada, salía «medida»: ahora se dice que ya está confirmada).

**Para conta.js** (cuando se escriba, f05): una fila con `ok` nulo y el
detalle «Sigue: …» quiere decir «esta vista no se controló todavía»: no se
pinta, y se vuelve a llamar a `fn_estados_control` con la lista de esas
filas (la trae el detalle) hasta que no quede ninguna. Lo que ya salió en
`true` se puede pintar mientras tanto. Nulo nunca es verde.

Lo que se hizo distinto de lo que sugería el hallazgo, a propósito:

- **0,2 s por vista como tope de `c4-volumen.sh`**: queda como aviso, no
  como fallo. Leídas como las lee PostgREST (con su conexión), con el
  volumen de Edgar, de cuatro a siete vistas tardan de 0,20 a 0,30 s en
  el banco según la corrida (`v_costo_por_obra`, la gráfica del Panel con
  todos los meses, `v_flujo_caja`, `v_gasto_por_proveedor`, a veces el
  balance y el gasto por categoría): de 2 a 3 s en producción, lejos de
  los 8 s. El tope que falla es 0,8 s (los 8 s de la API a la
  velocidad del banco), y el script dice cuáles pasan de 0,2 s. Con el
  libro de esfuerzo (666 por mes, tres veces lo de Edgar) el tope de las
  vistas sigue en 2 s y lo de producción se informa sin fallar: a ese
  volumen el Panel ya pide más de lo que el tope por reloj deja hacer en
  pocas llamadas (ver «LO QUE QUEDA ABIERTO» en `c4-estados.sql`).
- **El tope por reloj es de 3 s, no de 7**: pasado el tope todavía termina
  la vista que estaba corriendo (y el estado de resultados si el balance
  ya se controló: su cuadre los compara en la misma llamada), y después
  los cuadres y las protecciones: hasta 0,3 s más en el banco, unos 3 s en
  producción. 3 + 3 + la red caben en 8 s. Con 4 s, la pantalla del año
  llegaba a 0,76 s en el banco. Cada llamada controla al menos una vista:
  siempre avanza.
- **Lo que c6 selló no se relee, pero sigue contando**: para c4 y c2 las
  funciones selladas son, desde el principio, de las que pueden leer sus
  tablas (o escribir el libro), así que una SECURITY DEFINER ajena que las
  llama sale en rojo igual que antes (la 113 y la 83 lo prueban); y una
  sellada que cambió, o que se volvió SECURITY DEFINER, ya no es la
  sellada y se lee como cualquiera.
- **Sin caché de las protecciones** (una huella del catálogo para no
  recalcular): con lo sellado fuera, lo ajeno cuesta 20-35 ms, y un caché
  podía no ver un cambio.
- **Queda abierto** (no era de estos hallazgos): `fn_verificar_cadena`,
  que la app puede llamar, recalcula la cadena entera en su control
  `hash`: 0,45 s en el banco con unos 4.000 asientos (unos 4,5 s en
  producción), y crece con el libro. Con el ritmo de Edgar, se mira antes
  de unos 7.000 asientos (un verificado por mes cerrado, f08).

### La ronda 4b de c6 (3-oct): lo que encontró la prueba final

**Qué se pega**, en este orden, encima de lo de producción (d80c9de):
`c2-libro.sql` (paso 2: sus **10 controles en `true`**), `c4-estados.sql`
(paso 4: sus **9 filas**, en `false` solo «c4 · apertura» y «apertura en el
libro» mientras no esté la apertura) y `c6-banco.sql` (paso 5: sus **7
filas en `true`**, con «14 tablas»). c2 y c4 son los de la ronda 4 (marca
2026100201); la 4b solo cambia c6 (marca 2026100301) y c6-pruebas. c1 y c3
no cambian. Después las cuatro suites, cada una sola: **83, 120, 113 y 142
filas** en verde. Nada de lo guardado cambia de cifra (probado encima de
producción con el banco en uso, en 16 y en 17.6: ver §6).

La prueba final de la ronda 4 encontró dos cosas importantes de la bandeja
del banco, una menor y una observación. Las cuatro se arreglaron con un
mismo **principio**, en todos los caminos: el dinero del banco que va al
**patrimonio del accionista** (1130 préstamo al accionista, 2900 préstamo
del accionista, 3100 aportación, 3200 distribución, el capital) **nunca
entra con un botón sin su motivo escrito ni casa solo**, salvo cuando el
otro lado es una cuenta personal de Edgar que él dio de alta a propósito;
**un número que no se conoce no es personal** (la reserva recién abierta,
una tarjeta nueva, la línea de crédito, un préstamo, una cuenta de ahorro
en otro banco): se reconoce como de la empresa o se pregunta; y **ningún
botón de la bandeja pulsado tal cual deja el control en rojo**: si el
control lo marcaría, el botón pide su motivo o no se ofrece.

- **El depósito desde la cuenta personal del mismo monto que una factura
  (importante).** El depósito «ONLINE TRANSFER FROM CHK ...7781» por lo
  mismo que una factura abierta salía «transferencia_personal» con «De
  Edgar…: préstamo del accionista · 2900» y «Aportación · 3100» sin pedir
  motivo; pulsado tal cual, «cuadre: depósitos nunca a ingreso» salía en
  rojo («lo explica la factura #1101»). Ahora la cuenta personal se da de
  alta (`fn_banco_cuenta_personal`, desde el SQL Editor; la tabla nueva
  `banco_cuentas_personales`, con su guarda, su historial y el cuadre 53
  vigilándola): dada de alta, sus botones entran sin motivo y el control
  sigue en verde (su asiento lo dice); sin darla de alta, sale
  «cuenta_desconocida» y todo pide su motivo (el 2900 tal cual es MX008;
  con su motivo, entra en verde). Pruebas: la **135** (x13b y x13c de la
  prueba final), la **136** (el registro) y la **113** (ahora con la
  cuenta dada de alta).
- **El primer pase a la reserva recién abierta (importante).** Antes de su
  primer estado de cuenta, su número no era de nadie y se tomaba por la
  cuenta personal: el primer botón era «Para Edgar (su cuenta ····1097):
  distribución · 3200», sin motivo, el control en verde, y cuando llegaba
  la reserva su +5,000 proponía «Desde 1010» sin decir que el pase se
  había tomado por una distribución. Ahora es «cuenta_desconocida» (las
  cuentas propias primero, todo con su motivo, y el texto dice cómo dar de
  alta el número); el número dado de alta antes con un lote vacío
  (`"confirmo_cuenta": true`, paso 1 de «Después de c6»: ya no es un
  remedio provisional, es el camino) hace del pase «A 1030», sin motivo,
  y casa solo al llegar la reserva; y si el pase se clasificó antes (con su
  motivo), la reserva sale «otro_lado_clasificado»: su primer botón
  des-casa aquel y los dos casan solos. `fn_banco_numero_de` reconoce
  también el número con que QuickBooks trae la cuenta en el mapeo de la
  apertura. Pruebas: la **137** (x14, x15 y x16), la **138** (la cola de
  x14) y la **16** (espera ahora «cuenta_desconocida»).
- **La conciliación del mes sin la de apertura (menor).** Octubre sin la
  conciliación de apertura confirmada decía «la diferencia es 1950.00: algo
  del banco no está (…)»; ahora dice que falta la de apertura (o que no
  está confirmada, y qué le falta). Prueba: la **140**.
- **El anticipo de una obra (observación H08).** `fn_banco_cobrar` no
  registra un anticipo sin su porqué en las notas si el depósito lo
  explica un cobro anotado o una factura de su monto, o el lote de un
  procesador (dos o tres facturas por su bruto que caben en sus
  comisiones). Prueba: la **141**.
- **Los demás caminos del principio** (la **139**, la **142** y la **121**):
  la tarjeta nueva antes de su primer statement («CARD ENDING IN 5555»)
  se pregunta (salvo que la Gold traiga un pago recibido por lo mismo: R3
  los junta solos; lo encontró la prueba final de la 4b, §6, y lo arregla
  la 4c), y dada de alta (`fn_tarjeta_alta`) se propone sin motivo;
  tu tarjeta personal en 2900 es patrimonio (2900 ya no es una «tarjeta
  propia»: ni «A 2900» como transferencia ni clasificar a 2900 rechazado);
  «Para mí · 3200» del cajero y el Zelle de Edgar piden su motivo;
  clasificar al patrimonio sin motivo es MX008 salvo desde o hacia la
  personal dada de alta; la devolución con la débito (o cualquier
  clasificación) de un depósito que explica una factura pide su motivo;
  R3 no junta solo lo de una personal dada de alta, ni dos lados que
  nombran el mismo número (pero sí junta un número que no se conoce con
  otra cuenta propia de número conocido, y «la otra mitad de la
  transferencia» que deja «Desde 1010» casa sola la de una personal dada de
  alta: la prueba final de la 4b, §6; los arregla la 4c); R7 y los
  descriptores no llevan nada solo al
  patrimonio; un préstamo no vive en 2900; y la 121 pone una cuenta
  personal por fuera de su función (el cuadre 53 la dice). La **119**
  clasifica ahora su depósito al desembolso de la línea de crédito (2510).

**De paso, el tiempo**: la duda de cada cuenta en la bandeja
(`fn_banco_transferencia_dudosa`) se calculaba tres veces por cuenta, en
sql, planeada en cada llamada: la propuesta del pago de una tarjeta tardaba
100 ms. Ahora el otro lado se lee una vez (`fn_banco_otro_lado`, en
plpgsql) y la propuesta tarda 3 ms; «Casar» de un pago de tarjeta, 51 ms
(antes 75). Y c6-pruebas con un año de banco encima (`c6-volumen.sh`)
pasaba de su tope de 40 s: 41,7 s y 42,0 s sola. No era solo por las 8
nuevas: ese día el banco de pruebas iba un 8 % más lento que cuando midió
la ronda 4, y la suite de la ronda 4, sobre la misma base, ya tardaba de
41,3 a 41,5 s. Lo que pesaba (medido): las funciones «language sql» de c6
se vuelven a leer y a planear en cada consulta que las llama (el 17 % del
tiempo de la suite) y el control del banco (`fn_banco_control`, 64
llamadas) buscaba lo ajeno pasando el texto de las 3.600 funciones del
sistema por una expresión regular en cada llamada. Ahora las siete de c6
que más se llaman van en plpgsql (el tipo de cada cuenta, el contexto, la
firma, el pool), el contexto deja fuera las partidas ya saldadas de 2010,
el control mira el esquema antes que el texto (su base, de 54 a 32 ms) y
`pg_temp.c6_montar` no reescribe los diez descriptores en cada prueba
cuando ya están así. Las mismas respuestas: comparados antes y después
sobre el año de banco, el tipo de cada cuenta, el contexto, la firma, el
pool y el control entero salen iguales. c6-pruebas, con las 142: 18,5 s
en 17.6 (antes 22,2 s) y 17,4 s en 16; con un año de banco encima,
35,5 s sola y 40,3 s con cuatro teléfonos en 17.6, y 32,3 s y 35,7 s en
16.

**Lo que se vio y no se tocó**: `fn_banco_cheque_num` lee «TO CHK
...7781» como el cheque 7781 (CHK también es «checking»); en los primeros
30 días, con la apertura sin conciliar, esa transferencia lleva el aviso
de la apertura como un cheque. No pone nada al patrimonio ni en rojo;
cambiarlo cambia cómo se leen los cheques, y queda para otra ronda (la
4c lo arregla sin cambiar cómo se leen los cheques de verdad: abajo). Y la
«falta» de la conciliación de apertura, con dos o más partidas que el
banco trajo y se casaron con otra cosa, las nombra en el orden en que
salen: dos corridas iguales pueden decirlas en otro orden (la H09 lo
enseña). No cambia qué frena ni qué dice.

### La ronda 4c de c6 (3-oct): el criterio del otro lado

**Qué se pega.** Encima de la 4b (594054b): solo `c6-banco.sql` (paso 5:
sus **7 filas en `true`**, «14 tablas»). Encima de lo de producción
(d80c9de): `c2-libro.sql`, `c4-estados.sql` y `c6-banco.sql`, en ese
orden (c2 y c4 son los de la ronda 4, marca 2026100201; c1 y c3 no
cambian). La marca de c6 es ahora 2026100302. Después las cuatro suites,
cada una sola: **83, 120, 113 y 153 filas** en verde. No cambia ninguna
tabla, vista ni función de la app, y nada de lo guardado cambia de cifra
(probado encima de las dos, con el banco en uso, en 16 y en 17.6: §6). El
primer «Casar» después del pegado rehace las propuestas de lo pendiente;
lo ya casado no se toca (si vienes de la 4b: «Lo ya casado por la 4b», en
el paso 1 de «Después de c6»).

La prueba final de la 4b atacó el principio con un arnés que pulsa tal
cual cada botón de la bandeja, y encontró siete cosas (§6, de la (a) a la
(g)) con una causa común: cada camino se contestaba a medias «¿quién es el
otro lado de este movimiento?». Ahora la respuesta es una, **EL CRITERIO**
(`fn_banco_otro_lado`; su contrato, en la cabecera de c6), y todos los
caminos la usan igual: R3 y R1 en «Casar», los botones «A …» y «Desde …»,
`fn_banco_transferencia`, `fn_banco_casar_con`, `fn_banco_cobrar`,
`fn_banco_clasificar` y la bandeja. El otro lado es **una cuenta de la
empresa por su número** (un banco, una tarjeta, o la línea de crédito o un
préstamo dados de alta por su número), **una cuenta de la empresa sin
número** (el banco dice que es entre cuentas propias y no nombra a nadie),
**tu cuenta personal dada de alta**, **un número que no se conoce**, o
**un tercero** (un cliente, un proveedor, una compra; o alguien que el
banco nombra sin número: «TO EDGAR M PERSONAL»). Dos mitades **se
contradicen** si una dice tu cuenta personal, un número que no se conoce,
otra cuenta de la empresa o a alguien sin número: se juntan solo con su
motivo escrito, y la bandeja lo pide. **Casan solas** solo si no se
contradicen y las dos lo confirman.

- **(a) R3 y lo que se junta a mano (importante).** R3 juntaba solo el pase
  a ····7781 (que nada reconocía) con el depósito de la reserva que decía
  venir de ····4392, o el pago de Chase a una tarjeta ····5555 con el pago
  recibido en la Gold: tu dinero, como un pase de la empresa, y el pase de
  verdad, después, «en tránsito» para siempre. Ya no; y juntarlos a mano
  («Es la transferencia con …», `fn_banco_casar_con` con `{"movimiento":
  …}`) pide su motivo. Pruebas: la **143** y la **144**.
- **(b) «Desde …» con tu cuenta personal dada de alta (importante).**
  «Desde 1010» en un depósito de la reserva que nombra a alguien («FROM
  EDGAR M MARTINEZ») no pedía motivo, y en la misma llamada (o al llegar
  Chase) su línea casaba sola con el pase de Chase a tu cuenta personal:
  tu distribución, como un pase 1010 → 1030 (igual con el pago a tu
  tarjeta personal y el pago recibido en la Gold). Ahora «Desde 1010» ahí
  pide su motivo, y la línea de una transferencia casa sola solo si el que
  llega y el que la puso lo confirman; si se contradicen, la bandeja
  propone juntarlos con su motivo o des-casar el que la puso, y
  `fn_banco_clasificar` dice por qué no se clasifica. Prueba: la **145**.
- **(c) El depósito que nombra una cuenta de la empresa (importante).**
  Con la reserva antes que Chase, su depósito «FROM CHK ...4392» salía
  «deposito_parcial» con «Parte de la factura #1103» primero y sin motivo:
  pulsado, la factura quedaba cobrada con dinero de Chase. Ahora es su
  transferencia («Desde 1010» primero, sin motivo); el cobro, la factura o
  una devolución, con su motivo; R1 y R2 no lo casan solos con un cobro, y
  `fn_banco_cobrar` sin notas o `fn_banco_casar_con` con un cobro sin
  motivo son MX008. Prueba: la **146**.
- **(d) La transferencia que nombra a alguien sin número (menor).** «ONLINE
  TRANSFER TO EDGAR M PERSONAL» es «otro_lado_nombrado» (nuevo): sus
  cuentas propias y el patrimonio, todo con su motivo; ya no «A 1030» sin
  motivo ni «A 2100-…» que fallaban. Prueba: la **147**.
- **(e) La línea de crédito y los préstamos, por su número (menor).** El
  lote vacío a 2510, 2520 o 2530 da de alta su número (antes MX004, aunque
  la bandeja lo aconsejaba), y su dinero es «deuda_propia» (nuevo): un
  pago a esa cuenta o su desembolso, sin motivo; clasificar sin motivo la
  deja ir a ella (y a un gasto, sus intereses), a otra cosa con su motivo.
  Prueba: la **148**.
- **(f) El orden de un depósito de un número que no se conoce (menor).**
  Primero las cuentas propias, después el patrimonio, todo con su motivo,
  y las facturas detrás (lo que dice la cabecera). Prueba: la **149**.
- **(g) El pase a tu cuenta personal con tu aportación ya clasificada
  (menor).** Con el depósito de la reserva desde «EDGAR M MARTINEZ» ya
  clasificado a 3100, el pase de Chase a tu cuenta personal dada de alta
  decía que se des-casara la aportación; ahora es
  «transferencia_personal», con su 3200 sin motivo. Prueba: la **150**.
- **La baja de tu cuenta personal (la observación).** Darla de baja (o de
  alta) rehace en ese momento la propuesta de lo pendiente que la nombra:
  sus botones al patrimonio piden su motivo sin esperar al «Casar».
  Prueba: la **151**.
- **«TO CHK ...7781» no es un cheque, y «Lo que falta».**
  `fn_banco_cheque_num` (y el pool, el motor y la conciliación) ya no lee
  la cuenta de cheques que nombra una transferencia («TO CHK ...7781»,
  «FROM CHK ...4392») como el cheque 7781; los cheques de verdad se leen
  igual («CHECK 1042», «CHK #1043», «CHECK # 1044»), y esas transferencias
  ya no llevan el aviso de la apertura de un cheque. Y confirmar una
  conciliación que no cuadra dice «Lo que falta: …» (antes, «falta la
  diferencia es …»). Prueba: la **152**.
- **Un pegado nuevo rehace lo pendiente.** La marca de la versión va en la
  firma de cada propuesta: el primer «Casar» después del pegado las rehace
  todas (y clasificar sin motivo rehace la suya). Antes dependía de que el
  pegado cambiara la forma de la firma, y esta ronda no la cambia: encima
  de la 4b se habrían quedado sus botones («Desde 1010» sin motivo), que
  pulsados ya fallan. Prueba: la **153**.

**El tiempo**: EL CRITERIO se pide solo donde hace falta (lo que puede ser
dinero entre cuentas) y va en plpgsql: 0,15 ms por movimiento. c6-pruebas,
con las 153: 19,9 s en 17.6 y 19,4 s en 16; con un año de banco
(`c6-volumen.sh`, 9.990 movimientos), 37,5 s en 17.6 y 34,5 s en 16, bajo
su tope de 40 s. Las 11 nuevas suman unos 2 s; por llamada, «Casar», el
contexto y la firma tardan lo mismo que en la 4b (medido el 3-oct sobre la
misma base del año).

**Lo que no se hizo, y por qué**: que un banco que nunca trajo su estado de
cuenta pida motivo también en el pago recibido en una tarjeta («Desde
1030» en la Gold con la reserva sin abrir). Rompía lo bueno del primer
mes: la Amex llega antes que Chase y «Desde 1010» es la respuesta, sin
motivo (la 85). Se queda como en la 4b: solo entre dos bancos.

**Lo que encontró su prueba final** (3-oct, §6): todo lo de la 4b y de
la ronda 4 ya no se reproduce, y los dos caminos de actualización entran
limpios; pero EL CRITERIO no llega a dos caminos que juntan solos dos
lados que se contradicen (importante): la línea de un **asiento escrito a
mano** en una cuenta del banco (R1, clase «asiento»: un pase a la reserva
anotado con `fn_postear` casa solo con el depósito que viene de tu cuenta
personal dada de alta, o con el retiro de Chase a ella; dos aportaciones
anotadas a mano, con el pase desde la reserva por su número y con un
depósito por lo que una factura tiene abierto) y el **cobro que c3
registra con su movimiento** («R2 el cobro dice este movimiento» con el
depósito de la reserva que viene de Chase; y al llegar Chase, «A 1030»
sin motivo deja la reserva con el doble en libros, en tránsito, sin nada
en rojo). Y menores (los 4 últimos sueltos de tu tarjeta personal, el
pago de una tarjeta de otro emisor, un cheque como «la otra mitad», la
partida en tránsito de la apertura, Plaid y el QFX del mismo movimiento,
el nombre «1007» de QuickBooks, el lote vacío que no rehace lo pendiente,
los botones de antes hasta el primer «Casar»). Los arregla la 4d (abajo).

### La ronda 4d de c6 (3-oct): el control

**Qué se pega.** Encima de la 4c (9849564): solo `c6-banco.sql`, o sus
dos partes (paso 5: sus **7 filas en `true`**, «14 tablas»). Encima de lo
de producción (d80c9de): `c2-libro.sql`, `c4-estados.sql` y
`c6-banco.sql` (o sus dos partes), en ese orden (c2 y c4 son los de la
ronda 4, marca 2026100201; c1 y c3 no cambian). La marca de c6 es ahora
2026100303. Después las cuatro suites, cada una sola: **83, 120, 113 y
161 filas** en verde. Una columna nueva al final de `banco_casados`
(`otro_lado`: lo que decía el banco al casarlo); ninguna tabla, vista ni
función de la app nueva (`v_banco_bandeja` cambia por dentro, no sus
columnas), y nada de lo guardado cambia de cifra (probado encima de las
dos, con el banco en uso, en 16 y en 17.6: §6). Lo ya casado no se
des-casa solo: EL CONTROL lo mira, y lo que se contradice sale en rojo
con qué hacer (paso 1 de «Después de c6», «Lo casado que se
contradice»).

La prueba final de la 4c atacó EL CRITERIO por los caminos que no pasan
por la bandeja (sus escenarios L01 a L17 y L02b, §6) y encontró que cada
camino casaba a su manera: un asiento escrito a mano, el cobro que c3
registra con su movimiento, una partida de la apertura, un duplicado dicho
«es el mismo»… y lo que se colaba quedaba casado **y en verde**. Ahora,
además del freno de cada camino, hay **un control que lo mira todo
después**, y la conciliación no se confirma con algo así dentro. EL
CRITERIO tiene ahora dos lados: lo que dice el banco del otro lado (la
4c) y lo que dice el libro (el asiento con el que casó: otra cuenta
propia, una deuda, el patrimonio, el cobro de un cliente, una partida de
la apertura, u otra cosa). **Se contradicen** si el libro dice una cuenta
propia o una deuda y el banco nombra otra cuenta de la empresa, tu
cuenta personal, un número que no se conoce, a alguien sin número, la
tarjeta de otro emisor o un cheque; si el libro dice un cobro o una
partida de QuickBooks y el banco nombra una cuenta de la empresa o tu
cuenta personal; si el libro dice el patrimonio y el banco no nombra tu
cuenta personal dada de alta (EL PRINCIPIO de la 4b); o si el libro dice
otra cosa y el banco nombra una cuenta de la empresa (salvo los intereses
de una deuda que se le paga). Lo coherente no: tu cuenta personal contra
2900, 3100, 3200 o 1130; un cliente contra su cobro («REMOTE ONLINE
DEPOSIT» es el cheque de un cliente); el prestamista contra su deuda.

- **EL CONTROL (importante).** Cualquier casado vivo cuyo banco y cuyo
  libro se contradicen sin su motivo escrito —lo casara quien lo casara—
  sale en rojo en `fn_banco_control` («cuadre: el otro lado de cada
  casado», con `v_banco_movimientos` o `v_banco_bandeja`, o pedido por su
  nombre: «esperaba 0», cuántos y cuáles, con cómo arreglarlo) y en
  `fn_banco_verificar` («el otro lado de cada casado»); y la conciliación
  de su cuenta y su mes no se confirma (dice cuál y cómo). Se arregla
  des-casándolo o, si es correcto así, escribiendo su motivo
  (`fn_banco_casar_con` con `{"casado": …}`, nuevo). Lo casado con tu
  cuenta personal cuando lo era no se pone en rojo si después la das de
  baja. Con la 4c, los mismos casos (el estado final de nueve escenarios
  de su prueba final, y un pago recibido en una tarjeta casado a mano con
  una distribución) dejaban el control entero en verde y la conciliación
  se confirmaba. Prueba: la **154**.
- **R1 con un asiento escrito a mano (importante).** El cruce exacto casaba
  solo cualquier asiento del libro: el pase a mano 1010 → 1030 con el
  dinero que el banco decía venir de tu cuenta personal, el pago a mano de
  la Gold con el pago a una ····5555 que nadie conocía, una aportación a
  mano con el cheque de un cliente. Ahora casa solo si EL CRITERIO contra
  ese asiento no se contradice y el banco lo confirma; si no, se propone,
  y «Confirmar cruce con …» pide su motivo (también `fn_banco_casar_con`
  con esas líneas o ese asiento). Un cobro, una cuota, un ticket o una
  devolución casan como antes. Prueba: la **155**.
- **El cobro que c3 registra con su movimiento (importante).**
  `fn_cobro_registrar` con `"movimiento_id"` casaba solo («R2 el cobro
  dice este movimiento») aunque el depósito dijera que venía de una cuenta
  de la empresa: el pase de Chase quedaba como el cobro de una factura.
  Ahora se propone («cobro_que_lo_nombra»: es su cobro, con su motivo; o
  no lo es: anular ese cobro, con su motivo). Mientras ese cobro siga
  vigente, el depósito no se postea otra vez ni lo junta otra regla, y el
  otro lado del pase propone anular ese cobro en vez de un «A …» que
  fallaría; «otro_lado_clasificado» mira también lo casado como cobro.
  Prueba: la **156**.
- **Lo que EL CRITERIO no leía (menores).** Los 4 últimos sueltos de tu
  tarjeta personal dada de alta en 2900 («AMEX EPAYMENT ACH PMT 7776»: tu
  cuenta personal); el emisor de la tarjeta que se paga (las de la
  empresa son Amex: el pago a una de CHASE es un tercero, y R3 no lo junta
  con el pago recibido en la Gold); un cheque, que nunca es la otra mitad
  de una transferencia; y el nombre de QuickBooks que es solo cifras
  («1007», la Gold) no es el número de esa cuenta. Prueba: la **157**.
- **El duplicado que trae el número (menor).** Lo que trae el QFX con el
  nombre entero vale para el movimiento que Plaid trajo cortado; «Es el
  mismo» contra un original casado con otra cosa pide su motivo, y con el
  original pendiente rehace ya su propuesta. Prueba: la **158**.
- **La partida de la apertura y tu cuenta personal (menor).** La regla de
  la apertura no casa sola una partida en tránsito (el cheque de un
  cliente del 30-sep) con lo que llega de una cuenta de la empresa o de tu
  cuenta personal; sus botones van al final y piden su motivo. Prueba: la
  **159**.
- **La línea de crédito dada de alta después (menores).** El lote vacío
  rehace ya las propuestas de lo pendiente de otras cuentas que nombran
  ese número (antes había que correr «Casar»); el desembolso que una
  factura abierta explica dice «con su motivo»; y un desembolso va entero
  a su deuda (a un gasto, con su motivo). Prueba: la **160**.
- **Los botones de antes, la dirección y el orden (menores).** Cada
  propuesta lleva la marca de la versión que la hizo, y la bandeja no
  enseña los botones de una de otra versión hasta el siguiente «Casar»
  (su texto lo dice); «Es la transferencia con …» solo en su dirección (el
  dinero no llega antes de salir); lo que falta en la conciliación de
  apertura, en un orden fijo. Prueba: la **161**.
- **Un «Ojo» vacío (lo encontró la verificación de esta ronda).** El aviso
  nuevo del duplicado («Ojo: si es el mismo, aquel está mal casado: .») y
  el de `fn_banco_clasificar` cuando la transferencia que lo espera no
  dice otra cosa («Ojo: . Si no es este dinero…», de la 4c) salían
  siempre, vacíos; ahora solo cuando se contradicen (lo enseñaban los
  repros de la ronda 4). Prueba: la **158**, ampliada.
- **El archivo partido.** `c6-banco.sql` pasa del 1,2 MB:
  `pruebas/conta/partir-c6.py` lo parte en `c6-banco-parte1.sql` y
  `c6-banco-parte2.sql` (menos de 650.000 bytes cada una; entre dos
  sentencias, al empezar la sección 5; sin la cabecera de la historia).
  La parte 2 sin la 1 de su marca para con MX000 sin tocar nada; las dos
  juntas dejan la base igual que el entero (`c6-partes.sh`: la foto del
  catálogo, 1.230 objetos), y cada una se puede pegar otra vez. El
  archivo entero sigue siendo la fuente.

**El tiempo**: EL CONTROL solo mira lo que puede contradecirse (lo que el
banco da por transferencia o por el pago de una tarjeta, lo casado con tu
cuenta personal, o un asiento con otra cuenta propia o el patrimonio
enfrente). c6-pruebas, con las 161: 22,2 s en 17.6 y 20,2 s en 16 (de cero); con un
año de banco (`c6-volumen.sh`, 9.990 movimientos), 36,8 s en 17.6 y 33,7 s
en 16, bajo su tope de 40 s (en otra corrida ese día, 38,4 s y 36,0 s; la
de la 4c, ese día en la misma máquina, 38,5 s en 17.6; la 4d daba 41,1 s hasta que `fn_banco_verificar` con
cuentas pedidas dejó de pedir los cuadres del control, que miran todo el
banco: un cuarto de segundo por llamada, y c6-pruebas la llama nueve
veces; siguen en la revisión entera y en `fn_banco_control`). El control
de cada pantalla del banco, con ese año (17.6 y 16): la bandeja 0,42 s y
0,36 s, la conciliación 0,32 s y 0,26 s, todo 0,59 s y 0,50 s, «hoy»
0,50 s y 0,44 s; la revisión entera, `fn_banco_verificar()`, 3,1 s y
2,9 s.

**Lo que no se hizo, y por qué**: que «REMOTE» sea una palabra del banco
(para que «REMOTE ONLINE DEPOSIT» no nombre a nadie): R3 juntaría ese
depósito con una transferencia como si fuera entre cuentas propias, y no
hace falta (contra el libro es un tercero, el cheque de un cliente:
coherente con su cobro, contradictorio con el patrimonio). Y des-casar
solo, al pegar, lo que una versión anterior casó y ahora se contradice:
lo decides tú (EL CONTROL lo dice, con su arreglo).

**Lo que encontró su prueba final** (4-oct, §6): lo que encontró la de la
4c ya no se reproduce (L01 a L17 y L02b; y la ronda 4, la 4b y su arnés,
tampoco), los dos caminos de actualización entran limpios, con el entero y
con las dos partes, y EL CONTROL dice lo que la 4c dejaba casar solo. Pero
EL CONTROL no mira tres clases de casado que sí pueden contradecirse, y un
motivo escrito solo lo apaga (importante):
- **Las devoluciones** (`fn_cobro_devolver` de c3, con grant a la app): con
  el movimiento de un pase a tu cuenta personal, «R9 la devolución dice
  este movimiento» lo casa solo; sin movimiento, R1 («R9 devolución = su
  línea del banco») casa solo el primer retiro de ese monto, también un
  pase a tu cuenta personal. La factura vuelve a quedar por cobrar, tu
  distribución no está, y el control y la conciliación del mes en verde
  (R- mira EL CRITERIO solo en un cobro, R1 no lo mira en una devolución
  ni en un ticket, y el control no mira «devolucion»). Es la variante del
  cobro con su movimiento (L03) que el arreglo no cubrió.
- **La cuota de otro monto** (la propuesta de la ronda 4, prueba 104): con
  una cuota registrada antes que el banco, todo retiro de su banco a 10
  días o menos (≥ su interés) sale «cuota_prestamo» con sus botones («la
  diferencia a capital» y, si cobró más que la cuota, «a interés») como
  ÚNICAS opciones y sin «pide_motivo» —el pago de la Amex, el pase a la
  reserva por su número, un cheque, una compra, el pase a tu cuenta
  personal: el paso de la cuota va antes que el de las transferencias— y
  `fn_banco_casar_con` con `{"cuota", "diferencia"}` escribe en el casado
  un motivo automático («La cuota del … con el cargo del banco: la
  diferencia … a capital»), que EL CONTROL toma por el tuyo: el pase a tu
  cuenta personal queda como la cuota de la F-150 (2530 y 7100), en verde.
- **Los tickets** (R1 «tarjeta o débito = recibo»): con Plaid, o un QFX
  bajado a mitad de mes, un pase de Chase a la reserva (por su número) que
  llega antes que la compra con la débito casa solo con el ticket del
  mismo monto (EL CRITERIO contra el libro dice que se contradicen), y el
  control no mira los tickets; la compra de verdad llega después «sin
  ticket» (clasificada, el gasto dos veces). Con el QFX del mes entero (el
  pase y la compra juntos) no casa solo, pero el único botón del pase es
  «Confirmar cruce con recibo …», sin «pide_motivo», y pulsado queda igual.
- **Un motivo automático** también en `fn_banco_transferencia_rehacer`: el
  lado que ya estaba casado (un «Desde 1010» en la reserva) se vuelve a
  casar con «La otra mitad de la transferencia llegó con fecha …» como su
  motivo cuando el otro lado llega con fecha anterior; después, el QFX del
  mismo movimiento con el número de tu cuenta personal entra con «Es el
  mismo» sin motivo (el casado «ya lo tiene») y EL CONTROL no lo ve
  (menor hoy: hace falta Plaid).
Y menores: el número de un préstamo de vehículo dado de alta a 2520 con
su saldo en 2530 (lo que trae QuickBooks, y lo que pide el README: «a su
cuenta») pone cada cuota en rojo (falso: la propuesta reconoce las dos
cuentas del préstamo, EL CRITERIO solo una; el botón «Cuota de …», sin
«pide_motivo», deja el control en rojo); R2 con varios cobros casa solo el
depósito de tu cuenta personal (solo mira las cuentas de la empresa; EL
CONTROL sí lo pone en rojo); y un depósito «Online Transfer from SAV»
(Plaid, sin número) por lo que una factura tiene abierto ofrece primero la
factura, sin motivo. Lo de mientras, en §0 («Esta entrega»).

## 0b. La prueba final en el banco, de cero

Lo mismo que los pasos 1 a 11 de arriba, sin tocar producción. Tarda segundos:

```bash
cd /home/user/max-power-panel/pruebas/conta
D=../../docs/conta

# De cero: las cinco entregas, los puentes corridos (como el paso 6) y las
# cuatro suites (sin Storage: 45 y 90 de c3 salen «omitida»; con
# 03-storage-simulacro.sql delante salen en verde).
./correr.sh final_mia 03-storage-simulacro.sql $D/c1-plan-de-cuentas.sql $D/c2-libro.sql \
                      $D/c3-puentes.sql $D/c4-estados.sql $D/c6-banco.sql 05-puentes-correr.sql \
                      $D/c2-pruebas.sql $D/c3-pruebas.sql $D/c4-pruebas.sql $D/c6-pruebas.sql
#   → PRUEBAS total=83 ok=83 fallan=0 omitidas=0
#   → PRUEBAS total=120 ok=120 fallan=0 omitidas=0
#   → PRUEBAS total=113 ok=113 fallan=0 omitidas=0   (en 17.6; en 16, ok=112
#     omitidas=1: la 109, MAINTAIN, es de Postgres 17)
#   → PRUEBAS total=161 ok=161 fallan=0 omitidas=0
# (Con las dos partes de c6 en vez del entero —$D/c6-banco-parte1.sql
# $D/c6-banco-parte2.sql, en ese orden—, lo mismo.)

# Idempotencia: sobre la MISMA base, volver a pegar c1, c2, c3, c4 y c6
# (dos veces) y las pruebas otra vez; tiene que seguir todo en verde.
for i in 1 2; do for f in c1-plan-de-cuentas c2-libro c3-puentes c4-estados c6-banco; do
  PGPASSWORD=editor_sql psql -X -q -h 127.0.0.1 -U editor_sql -d final_mia \
    -v ON_ERROR_STOP=1 -1 -o /dev/null -f $D/$f.sql || echo "FALLÓ $f"
done; done

# El camino de producción: c1–c6 como están pegados HOY (d80c9de: c6 con
# su marca 2026092704), con el banco en uso (un mes de Chase importado,
# casado, clasificado y su conciliación confirmada, la póliza, la nómina,
# un ticket de CED), y encima, como Edgar, c2 y c4 nuevos y el c6 nuevo
# dos veces (en la ronda 4 cambian c2 y c4, grupo 4; en la 4b, la 4c y la
# 4d solo c6; c1 y c3 no); las
# cuatro suites en verde, cada una sola. La foto de los movimientos, los
# casados, las conciliaciones, el historial, los saldos, el mapeo de c4,
# los períodos y los puentes, igual antes y después del pegado.
P=/tmp/prod_mia; mkdir -p $P
for f in c1-plan-de-cuentas c2-libro c3-puentes c4-estados c6-banco; do
  git show d80c9de:docs/conta/$f.sql > $P/$f.sql; done
./correr.sh final_prod 03-storage-simulacro.sql $P/c1-plan-de-cuentas.sql $P/c2-libro.sql \
            $P/c3-puentes.sql $P/c4-estados.sql $P/c6-banco.sql 05-puentes-correr.sql
#   (aquí, el banco en uso, como Edgar: cada pestaña en su transacción)
for f in $D/c2-libro.sql $D/c4-estados.sql $D/c6-banco.sql $D/c6-banco.sql \
         $D/c2-pruebas.sql $D/c3-pruebas.sql $D/c4-pruebas.sql $D/c6-pruebas.sql; do
  PGPASSWORD=editor_sql psql -X -q -h 127.0.0.1 -U editor_sql -d final_prod \
    -v ON_ERROR_STOP=1 -1 -o /dev/null -f $f || echo "FALLÓ $f"
done   # (los resultados, en pruebas.c2_resultado … c6_resultado)
# Y el c6 nuevo pegado solo sobre c2 y c4 de producción: para con MX000 y
# dice qué volver a pegar (c2-libro.sql y c4-estados.sql), sin tocar nada.
# Encima de la 4c (9849564: c2 y c4 ya son los de la ronda 4), lo mismo con
# git show 9849564:… y solo el c6 nuevo (dos veces) y las cuatro suites;
# después, «Casar» y EL CONTROL (paso 1 de «Después de c6», «Lo casado que
# se contradice»). Con la cuenta personal y la reserva dadas de alta antes
# de las suites, c6-pruebas sigue en verde (ronda 4c). Los dos caminos,
# también con las dos partes de c6 en vez del entero (ronda 4d).

# El archivo entero y sus dos partes (ronda 4d): las dos partes dejan la
# base igual que el entero (la foto del catálogo: funciones, tablas,
# índices, policies, triggers y huellas), la parte 2 sola para con MX000
# sin tocar nada, cada parte dos veces no cambia nada, y c6-pruebas en
# verde encima (crea y borra sus bases; con PLANTILLA=<bd>, de una base
# que ya tiene el banco: la de producción simulada, con la versión
# anterior y sus datos):
./c6-partes.sh final_c6p
python3 partir-c6.py --comprobar     # ¿las partes son las de c6-banco.sql de hoy?

# Varias sesiones, volver a pegar con reglas tocadas, y volumen:
./c2-pegado.sh final_c2p; ./c3-pegado.sh final_c3p
./c2-concurrencia.sh final_c2c; ./c3-concurrencia.sh final_c3c; ./c4-concurrencia.sh final_c4c
./c6-concurrencia.sh final_c6c
./c6-en-uso.sh final_c6u              # las cuatro suites con octubre en uso (y noviembre)
./c3-volumen.sh final_c3v 3000
./c4-volumen.sh final_c4v             # ≈ 10.000 asientos por los puentes (unos 10 minutos)
./c6-volumen.sh final_c6v             # y un año de estados de cuenta encima (unos 10 minutos)
# El año de Edgar (unos 200 papeles por mes y 2.500 movimientos), donde lo
# de producción se exige (ronda 4 de c6): cada pantalla de cifras, con el
# tope por reloj, en llamadas de 0,8 s o menos (8 s en producción).
CONSERVAR=1 SOLO_MEDIR=1 ./c4-volumen.sh final_c4e 200
PLANTILLA=final_c4e MOVS=2500 AL_DIA=12 ./c6-volumen.sh final_c6e 200
./correr.sh --borrar final_c4e

./correr.sh --borrar final_mia
```

Con la apertura de verdad ya posteada (una balanza, su mapeo y
`fn_apertura`, confirmados antes de las suites) tiene que salir igual de
verde: c2 con la 61 «omitida» (y, con la apertura ya cerrada, la 37 y la
48), c3 con la 115 y la 117 «omitidas» (más la
45 en producción), c4 con la 29 a la 36, 50, 51, 53, 56, 61,
62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107 «omitidas»,
c6 con la 109, la 129, la 130 y la 140 «omitidas» (postean una apertura
de prueba; su prueba 30 usa entonces la apertura de verdad), nada en
rojo. Y con el reloj del servidor después del día 15 del primer mes
abierto (3-oct: un cluster 17.6 bajo libfaketime, `FAKETIME=+17d`), las
cuatro suites también en verde: la 45 de c4 corre en noviembre (antes
salía «omitida»). Y con datos de verdad en el mes (un depósito normal que se
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
La del 26-sep (con c6) también, en 16 y en 17.6: c6-pruebas termina con
su propia foto (la 61: el libro, los papeles, el banco y su historial, las
reglas, los contadores, las secuencias, los eventos y las huellas de c2 y
del banco), igual a la del principio.
Al VOLVER a pegar c1–c4 (y c6) encima, lo único que cambia es lo que tiene
que cambiar: la hora del sello en el comentario de `fn_libro_huellas()`,
de `fn_estados_huellas()` y de `fn_banco_huellas()` («selladas por el
último pegado, el … (Miami)») y los oid de las vistas de c4 (el pegado las
rehace). Desde la ronda 4 de c6 (grupo 4) cambia también el CUERPO de
`fn_estados_huellas()`: las huellas de las vistas se toman de su árbol
guardado (`pg_rewrite`), que lleva esos oid, y el pegado las vuelve a
sellar (comprobado el 3-oct: es la única definición que cambia). Filas,
secuencias, las demás definiciones y los permisos, iguales.

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

# El banco (c6), encima de los estados, con las cuatro suites (c2, c3 y c4
# tienen que seguir en verde con c6 pegado), y c6 pegado dos veces:
./correr.sh c6_agente 03-storage-simulacro.sql ../../docs/conta/c1-plan-de-cuentas.sql \
                      ../../docs/conta/c2-libro.sql ../../docs/conta/c3-puentes.sql \
                      ../../docs/conta/c4-estados.sql ../../docs/conta/c6-banco.sql \
                      ../../docs/conta/c6-banco.sql ../../docs/conta/c2-pruebas.sql \
                      ../../docs/conta/c3-pruebas.sql ../../docs/conta/c4-pruebas.sql \
                      ../../docs/conta/c6-pruebas.sql
# Varias sesiones a la vez contra el banco (crea y borra su base):
./c6-concurrencia.sh c6_conc_mia
# Las cuatro suites con octubre ya en uso: la póliza de QuickBooks con su
# saldo al 30-sep, la nómina de octubre con su journal y un ticket de la
# segunda obra, con la apertura todavía sin postear (crea y borra su base):
./c6-en-uso.sh c6_en_uso_mio
# Un año de estados de cuenta sobre el libro de c4-volumen, como Edgar
# (crea y borra su base; con PLANTILLA=<bd> copia un libro ya hecho):
./c6-volumen.sh c6_volumen_mio

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
- **La prueba final de c6, de cero (27-sep, tarde)**, con los archivos de
  la ronda 3 de c6 (c6-banco marca 2026092704; c2 2026092701; c3 y c4
  2026092601), en 16.13 y en 17.6:
  - Carga completa (`03-storage-simulacro`, c1, c2, c3, c4, c6,
    `05-puentes-correr` y las cuatro suites): c2-pruebas 82/82, c3-pruebas
    120/120, c4-pruebas 111/111 en 17.6 (110 + la 109 «omitida» en 16) y
    c6-pruebas 100/100. El pegado de c6 enseña sus 7 filas, todas en true
    («13 tablas», «8 vistas», «21 funciones», el reparto de c2, «2 filas»
    en `v_banco_saldos`, y las dos protecciones «bien»); el de c4, sus 9
    con `c4 · apertura` y «apertura en el libro» en false (lo esperado).
    c6-pruebas sola: 15,9 s en 16 y 19,4 s en 17.6 (con un año de banco,
    en `c6-volumen.sh`: 31,5 s y 38,0 s).
  - Idempotencia: c1, c2, c3, c4 y c6 pegados dos veces más sobre la misma
    base y las cuatro suites otra vez: iguales. La foto antes y después de
    los dos pegados solo cambia la hora del sello en el comentario de
    `fn_libro_huellas()`, `fn_estados_huellas()` y `fn_banco_huellas()`.
    Y c6 de hoy encima del c6 del diseñador (marca 2026092601) y encima de
    los de las rondas 2 y 3 (2026092701 y 2026092703): entra, sus 7 filas
    en true y las suites en verde. Y el camino de producción (arriba, 0b):
    c1–c4 del 26-sep con sus suites de entonces (80/80, 118/118, 110/110;
    109 + 1 en 16), encima c2, c3, c4 nuevos, c6 y el puente, y las cuatro
    suites de hoy: 82, 120, 111 (110 + 1) y 100, todas en verde. c6 pegado
    directamente sobre c2–c4 de producción, sobre c1 solo, o sobre un c4
    sin marca: para con MX000 y dice qué volver a pegar.
  - Sin rastro: la foto de la base (filas y md5 de cada tabla de `public`,
    `auth`, `storage`, `extensions` y `net`, secuencias, funciones con su
    cuerpo, permisos y ajustes, triggers, policies, vistas, columnas,
    restricciones, índices, comentarios, roles y sus ajustes, privilegios
    por defecto) igual antes y después de cada una de las cuatro suites,
    en 16 y en 17.6, en la base recargada y en la del camino de
    producción. Lo único que queda es el esquema `pruebas` con
    `c2_resultado` … `c6_resultado`.
  - Scripts del banco, en los dos: c0-banco-pruebas 18/18, c2-pegado (18
    ok), c3-pegado (14), c2-concurrencia (12), c3-concurrencia (34),
    c4-concurrencia (17), c6-concurrencia (24; importar y casar dos veces
    1,3 s, 29 subidas, la más lenta 0,38 s), c6-en-uso (las cuatro suites
    con octubre en uso y otra vez con noviembre: nada en rojo),
    c3-volumen con 3.000 recibos (reintentar 1,4 s / 1,8 s; controles
    1,9 s / 2,1 s), c4-volumen con 10.333 asientos (ninguna vista por
    encima de 0,72 s; el control del Panel 3,3 s en 16 y 4,0 s en 17.6;
    con cuatro teléfonos, la subida más lenta 5,4 s / 7,5 s mientras corre
    c3-pruebas —cerca del tope de 8 s en 17.6, con los dos clusters
    midiendo a la vez— y 3,4 s / 4,2 s mientras corre c4-pruebas) y
    c6-volumen (9.990 movimientos, 36 archivos: casar como mucho 2,4 s
    por mes y 3,1 s con los meses 13 y 14 juntos, la bandeja 0,5 s,
    conciliar 0,6 s, `fn_banco_control` 0,5 s, el
    re-pegado de c6 2,0 s / 2,7 s, `fn_banco_verificar` 3,2 s / 3,6 s,
    «Cuadrar» con dos meses sin casar 1,1 s; c6-pruebas con cuatro
    teléfonos 38,1 s / 42,4 s, la subida más lenta 2,5 s / 3,0 s). Todos en
    verde.
- **La prueba final de la ronda 4 de c6, grupo 1 (2-oct)**, con c6-banco
  marca 2026100201 (c2, c3 y c4 sin cambios), en 16.13 y en 17.6:
  carga completa y las cuatro suites: c2-pruebas 82/82, c3-pruebas 120/120,
  c4-pruebas 111/111 en 17.6 (110 + la 109 «omitida» en 16) y c6-pruebas
  117/117 (16 s y 17 s). Las 17 nuevas, contra el c6 de producción
  (2026092704), salen las 17 en rojo. El camino de producción (0b): c1–c6
  de d80c9de con el banco en uso (un mes de Chase importado, casado,
  clasificado, el pago a CED y la conciliación de 1010 confirmada) y el c6
  nuevo pegado dos veces encima: sin error, sus 7 filas en true, la foto
  de movimientos, propuestas, casados, conciliaciones, partidas, historial,
  archivos, asientos y saldos igual antes y después (y después de casar
  otra vez), y las cuatro suites, cada una sola, en verde. c6-en-uso (con
  octubre y con noviembre en uso) y c6-concurrencia (24) en verde en los
  dos; c6-volumen en 17.6 en verde (casar como mucho 2,8 s por mes,
  c6-pruebas sola 34,7 s con la 109 «omitida»: ese libro trae su apertura).
- **La prueba final de la ronda 4 de c6, grupo 2 (3-oct)**, con c6-banco
  marca 2026100201 (la misma del grupo 1; c2, c3 y c4 sin cambios), en
  16.13 y en 17.6: carga completa y las cuatro suites: c2-pruebas 82/82,
  c3-pruebas 120/120, c4-pruebas 111/111 en 17.6 (110 + la 109 «omitida»
  en 16) y c6-pruebas 128/128 (17 s y 18 s). Las 11 nuevas (118 a 128),
  contra el c6 del grupo 1, salen en rojo. El camino de producción (0b):
  c1–c6 de d80c9de con el banco en uso (un mes de Chase importado, casado,
  clasificado, el pago a CED y la conciliación de 1010 confirmada; y
  además la Gold con su QFX, un lote de Plaid con un posible duplicado ya
  dicho, una compra clasificada, otra que espera y un descriptor ajustado
  por Edgar) y el c6 nuevo pegado dos veces encima: sin error, sus 7
  filas en true, la foto igual antes y después del pegado; al casar otra
  vez cambia solo la propuesta del único pendiente (se rehace una vez:
  la firma de las propuestas cambió en la ronda 4; el mismo motivo,
  «sin_ticket»), y las cuatro suites, cada una sola, en verde, con la
  foto igual después. c6-en-uso (octubre y noviembre en uso) y
  c6-concurrencia (24; 32 subidas, la más lenta 0,15 s) en verde en los
  dos. c6-volumen en 17.6 en verde: la llamada media de la bandeja de
  0,05 a 0,07 s (como con el grupo 1; rehaciendo siempre la propuesta al
  clasificar eran 0,23 s), casar como mucho de 1,9 a 2,8 s según la
  corrida, fn_banco_verificar 3,0 s, c6-pruebas sola 38,4 s y con cuatro
  teléfonos 43,9 s (la subida más lenta, 2,3 s). En esa base, clasificar
  sin motivo un cargo con la propuesta al día tarda 33 ms; con la
  propuesta vieja (la rehace), 219 ms.
- **La prueba final de la ronda 4 de c6, grupo 4 (3-oct)**, con c2-libro
  y c4-estados marca 2026100201 (c3 sin cambios, 2026092601) y c6-banco
  2026100201, en 16.13 y en 17.6: de cero, las cuatro suites, cada una
  sola: c2-pruebas 83/83 (3,4 s y 3,8 s), c3-pruebas 120/120, c4-pruebas
  113/113 en 17.6 (112 + la 109 «omitida» en 16; 36,6 s y 40,7 s) y
  c6-pruebas 134/134 (19 s y 20 s); y otra vez después de pegar c1, c2,
  c3, c4 y c6 dos veces más encima, igual. Las nuevas, contra lo de
  antes, en rojo: la 113 de c4 y la 83 de c2 (con una función «del banco»
  de 4 MB sellada por c6, el control tardaba lo mismo que sin sellarla:
  la releía), la 112 de c4 (ningún «Sigue» con el tope) y la 134 de c6
  (fn_banco_control nombraba funciones de c4 con su paréntesis). El
  camino de producción
  (0b), en los dos: c1–c6 de d80c9de con el banco en uso; el c6 nuevo
  pegado solo sobre c2 y c4 de producción para con MX000 nombrando
  c2-libro.sql y c4-estados.sql, sin tocar nada (la foto igual); después
  c2 (sus 10 controles en true), c4 (9 filas: en false solo las dos de la
  apertura, que no está) y c6 dos veces (7 filas en true); las marcas,
  2026100201; la foto igual después del pegado, de casar otra vez (sin
  rehacer ninguna propuesta) y de las cuatro suites, cada una sola y en
  verde. El c6 nuevo pegado encima del de antes con un año de banco
  (2.313 pendientes): la firma de las propuestas, igual, y «Casar» no
  rehízo ninguna. Scripts del banco, en los dos: c0-banco-pruebas 18/18,
  c2-pegado (18 ok), c3-pegado (14), c2-concurrencia (12),
  c3-concurrencia (34), c4-concurrencia (17), c6-concurrencia (24;
  importar y casar dos veces 0,9 s, 32 y 33 subidas, la más lenta
  0,14 s),
  c6-en-uso (las cuatro suites con octubre en uso y otra vez c3- y
  c6-pruebas con noviembre: nada en rojo) y c3-volumen con 3.000 recibos;
  c4-volumen con 10.333 asientos (ver «ÍNDICES Y TIEMPOS» en
  c4-estados.sql: nada en rojo, el control del Panel en una llamada
  1,6 s y 1,9 s, y como en producción —se informa— en siete a nueve
  llamadas), c6-volumen con 9.990 movimientos (c6-pruebas sola 32,4 s y
  38,1 s, bajo su tope de 40 s; con cuatro teléfonos 37,1 s y 43,2 s, la
  subida más lenta 2,1 s y 2,5 s) y, con el año de Edgar (200 papeles por
  mes y 2.473 movimientos, en 17.6), c4-volumen y c6-volumen exigiendo lo
  de producción: cada pantalla de cifras en llamadas de 0,6 s o menos
  (el Panel en cuatro, 'hoy' y los estados en dos). Todos en verde.
- **La prueba final de la ronda 4 de c6, entera (3-oct)**, después de los
  cuatro grupos de correctores, con los archivos del commit 9669f18 (c2 y
  c4 marca 2026100201, c3 2026092601, c6 2026100201), en 16.13 y en 17.6:
  - De cero (la carga completa de §0b): c2-pruebas 83/83 (3,8 s en 17.6 y
    3,3 s en 16), c3-pruebas 120/120 (4,0 s y 3,7 s), c4-pruebas 113/113
    en 17.6 (36,5 s; en 16, 112 y la 109 «omitida», 33,2 s) y c6-pruebas
    134/134 (21,6 s y 17,3 s). Con el reloj del servidor al 20-oct (un
    cluster 17.6 bajo libfaketime, `FAKETIME=+17d`): 83, 120, 113 (la 45
    corre) y 134, en verde.
  - Los 37 hallazgos de la ronda, cada repro tal cual contra los archivos
    de hoy (en 16 y en 17.6 salen iguales, salvo los ids): en 36 el defecto
    ya no sale y su prueba nueva está en verde. El del primer QFX subido a
    la cuenta equivocada del grupo del importador se rechazó por ser el
    mismo que el del grupo 1 (la 111): su camino de vuelta
    (`fn_banco_archivo_retirar` y otra vez a la suya) se probó de punta a
    punta. Las partes rechazadas a propósito siguen como dicen sus
    secciones (el mensaje de c2 sobre el ajuste a la apertura abierta,
    ningún «puente» anotado solo, el aviso de 0,2 s por vista). El Panel
    con un año real, medido como en producción: de 3 a 4 llamadas, la más
    lenta de 0,47 a 0,52 s; una sola llamada sin el tope por reloj tarda
    todavía de 0,84 a 0,90 s en el banco (unos 9 s allí): el tope por reloj
    es lo que lo hace caber, y conta.js tiene que volver a pedir lo que
    sale «Sigue».
  - Encontró dos cosas nuevas, las dos de la bandeja del banco, que no
    tocan nada de lo ya guardado (quedaron para c6 y las arregló la 4b:
    §0, «La ronda 4b de c6»): (a) un depósito de
    la cuenta personal de Edgar del mismo monto que una factura abierta:
    sus botones «préstamo del accionista · 2900» y «Aportación · 3100»
    (grupo 1) no piden motivo, y después el cuadre «depósitos nunca a
    ingreso» (grupo 2) sale en rojo diciendo que lo explica la factura;
    con el motivo escrito, en verde. (b) El primer pase de Chase a la
    reserva antes de subir el primer estado de cuenta de la reserva: su
    número no es todavía de la empresa, sale como dinero a la cuenta
    personal de Edgar y su primer botón es «distribución · 3200», sin
    motivo; pulsado, ningún control lo ve, y el abono de la reserva queda
    después «transferencia de un lado». Con el número de la reserva dado
    de alta antes (un lote vacío con `confirmo_cuenta`), el pase sale
    «A 1030» y casa solo con su otro lado; ese alta no pone nada en rojo.
  - Idempotencia: c1, c2, c3, c4 y c6 pegados dos veces más sobre la misma
    base y las cuatro suites otra vez, cada una sola (17.6: 3,7 s, 4,3 s,
    37,2 s y 19,7 s; 16: 3,5 s, 3,9 s, 34,0 s y 17,3 s), en verde. La foto
    antes y después de los dos pegados solo cambia el comentario de
    `fn_libro_huellas()`, `fn_estados_huellas()` y `fn_banco_huellas()` y
    el cuerpo de `fn_estados_huellas()` (ver §0b).
  - El camino de producción (§0b), en los dos: c1–c6 de d80c9de (marcas
    2026092701, 2026092601, 2026092601 y 2026092704) con el banco en uso:
    la póliza de QuickBooks, la nómina de octubre con su journal, un ticket
    de CED, las dos Amex, el Chase de octubre con seis movimientos y la
    Gold de octubre, la bandeja resuelta, un des-casado con la comisión de
    R7, las conciliaciones de 1010 y de la Gold confirmadas y un pendiente
    de noviembre. El c6 nuevo pegado antes que c2 y c4 para con MX000
    nombrando c2-libro.sql y c4-estados.sql, y la foto y el catálogo
    quedan iguales. Después, como Edgar: c2 (sus 10 controles en true),
    c4 (sus 9 filas; en false solo las dos de la apertura, que no está) y
    c6 (sus 7 filas en true), de 0,2 a 0,6 s cada uno, y c6 otra vez; las
    marcas, 2026100201, 2026092601, 2026100201 y 2026100201. La foto de lo
    guardado, igual después del pegado; al casar otra vez solo cambia la
    propuesta del pendiente (se rehace una vez); las cuatro suites, cada
    una sola y en verde (17.6: 3,9 s, 4,7 s, 38,3 s y 20,4 s; 16: 3,3 s,
    4,0 s, 33,7 s y 18,2 s), con la foto igual después de cada una.
  - Sin rastro: la foto de la base (arriba) igual antes y después de cada
    suite, en la base recargada y en la del camino de producción; lo único
    que queda es el esquema `pruebas`. Las 21 funciones del banco que
    llama la app, solo para el dueño (el equipo lee 0 filas; anon no
    entra); las tablas con su RLS y solo su policy de lectura; las vistas,
    security_invoker.
  - Scripts del banco, en 16 y en 17.6, todos en verde: c0-banco-pruebas
    18/18, c2-pegado (18 ok), c3-pegado (14), c2-concurrencia (12),
    c3-concurrencia (34), c4-concurrencia (17), c6-concurrencia (24;
    importar y casar dos veces 1,0 s; 33 y 34 subidas, la más lenta 0,2 s),
    c6-en-uso (las cuatro suites con octubre en uso, y c3- y c6-pruebas
    otra vez con noviembre: 113 + 7 y 131 + 3 «omitidas», nada en rojo),
    c3-volumen con 3.000 recibos (reintentar 1,3 s y 1,1 s; controles
    1,5 s y 1,4 s), c4-volumen con 10.333 asientos (las vistas, 0,54 s y
    0,46 s como mucho; el Panel en una llamada, 1,8 s y 1,7 s; como en
    producción —se informa: es tres veces lo de Edgar— el Panel no terminó
    en 9 llamadas en 17.6 y tardó 7 en 16, y 'hoy' y los estados llegan a
    llamadas de 0,85 s y 0,92 s; con cuatro teléfonos, la subida más lenta
    2,3 s y 2,0 s mientras corre c4-pruebas y 4,9 s y 4,3 s mientras corre
    c3-pruebas) y c6-volumen con 9.990 movimientos (casar como mucho 2,1 s
    y 2,0 s por mes, la bandeja 0,38 s, `fn_banco_verificar` 3,0 s y
    2,7 s, c6-pruebas sola 38,5 s y 32,1 s —bajo su tope de 40 s— y con
    cuatro teléfonos 43,0 s y 38,1 s, la subida más lenta 2,5 s y 2,1 s;
    los meses 13 y 14 sin casar, «Cuadrar» 0,85 s y casar 2,9 s como
    mucho). Con el año de Edgar en 17.6 (200 papeles por mes y 2.473
    movimientos), lo de producción exigido: c4-volumen (3.167 asientos; el
    Panel en 4 llamadas, la más lenta 0,56 s; 'hoy' en 3 y los estados y el
    año en 2, 0,58 s como mucho) y c6-volumen (casar 0,73 s por mes como
    mucho, la bandeja 0,16 s, el Panel con el banco en uso en 4 llamadas
    de 0,53 s como mucho, c6-pruebas sola 25,7 s y con cuatro teléfonos
    31,1 s).
  - Lo ajeno (R1), en 17.6 con la base recién pegada: el Panel, 431-451 ms
    sin c6 y 445-489 ms con c6; 'hoy', 190-196 ms y 200-212 ms;
    `fn_verificar_cadena`, 70 ms y 85-95 ms; c4-pruebas con cuatro
    teléfonos a 800 ms: ninguna subida cortada (antes de la ronda, 11).
- **La prueba de la ronda 4b de c6 (3-oct)**, con c6-banco marca
  2026100301 (c2 y c4, los de la ronda 4, 2026100201; c3 sin cambios,
  2026092601), en 16.13 y en 17.6:
  - De cero, las cuatro suites: c2-pruebas 83/83, c3-pruebas 120/120,
    c4-pruebas 113/113 en 17.6 (112 + la 109 «omitida» en 16) y
    c6-pruebas 142/142. Contra el c6 de la ronda 4 salen en rojo las 8
    nuevas (135 a 142) y la 16, la 113 y la 119 (lo que esperan cambió a
    propósito). Idempotencia: c1–c6 pegados dos veces más y las cuatro
    suites otra vez, cada una sola (17.6: 3,9 s, 4,2 s, 37,6 s y 19,1 s;
    16: 3,3 s, 3,9 s, 35,2 s y 17,4 s), en verde; la foto antes y después
    de los pegados cambia solo lo de siempre (el comentario de las tres
    huellas y el cuerpo de `fn_estados_huellas()`) y ninguna suite la
    cambia.
  - Los 35 repros de la prueba final de la ronda 4 (h01–h17, e01–e12,
    p01–p06) y sus extras (x01–x16, y las variantes de la 4b), en los dos:
    ningún defecto vuelve. Contra la prueba final cambia solo lo que la 4b
    cambia a propósito: la H13 y la x13b (los botones 2900 y 3100 del
    depósito desde ····7781 pulsados tal cual, MX008; con su motivo
    entran y el control sigue en verde), la x07, la x12 y la x14
    («cuenta_desconocida» en vez de «transferencia_personal»; en la x14,
    al llegar el estado de cuenta de la reserva, los dos lados casan solos
    como transferencia), la H08 (el anticipo sin notas, MX008: «lo
    explican las facturas #2008 y #2009 cobradas con tarjeta…»), la H09
    (la «falta» de octubre dice que falta la conciliación de apertura) y
    la H16 (los botones del Zelle de Edgar dicen «(con su motivo)»). Los
    de 16 y 17.6, iguales, salvo el orden de las partidas en la «falta» de
    la apertura de la H09, que no es fijo (§0, «Lo que se vio y no se
    tocó»).
  - c6-en-uso (octubre y noviembre en uso; 17.6: 4,3 s, 5,4 s, 39,2 s y
    18,9 s; 16: 3,5 s, 4,2 s, 36,9 s y 17,5 s; noviembre, 113 + 7 y
    139 + 3 «omitidas») y c6-concurrencia (24; 32 subidas, la más lenta
    0,17 s y 0,18 s), en verde en los dos.
  - c6-volumen (666 por mes, 9.990 movimientos), en verde en los dos:
    casar como mucho 2,15 s y 2,0 s por mes, la bandeja 0,36 s y 0,37 s,
    `fn_banco_verificar` 3,1 s y 2,9 s, c6-pruebas sola 35,5 s y 32,3 s y
    con cuatro teléfonos 40,3 s y 35,7 s (la subida más lenta, 2,4 s y
    2,0 s). Antes de lo del tiempo de la 4b (§0, «La ronda 4b»), en 17.6,
    sola: 41,7 s y 42,0 s, por encima de su tope (la de la ronda 4, ese
    día y sobre la misma base, de 41,3 a 41,5 s). El año de Edgar en 17.6
    (200 por mes y 2.500 movimientos): casar 0,82 s por mes como mucho, la
    bandeja 0,15 s, el Panel con el banco en uso en 4 llamadas de 0,48 s
    como mucho (a hoy, 2 de 0,49 s; los estados, 2 de 0,53 s), c6-pruebas
    sola 27,2 s y con cuatro teléfonos 33,4 s.
  - El camino de producción (§0b), en los dos: c1–c6 de d80c9de (marcas
    2026092701, 2026092601, 2026092601 y 2026092704) con el banco en uso
    (la póliza, la nómina de octubre con su journal, un ticket de CED, las
    dos Amex, el Chase de octubre y la Gold, la bandeja resuelta, un
    des-casado con la comisión de R7, las conciliaciones de 1010 y de la
    Gold confirmadas y un pendiente de noviembre). El c6 nuevo pegado
    antes que c2 y c4 para con MX000 y la foto y el catálogo quedan
    iguales; después, como Edgar, c2 (sus 10 controles en true), c4 (sus 9
    filas; en false solo las dos de la apertura) y c6 (sus 7 filas en
    true, «14 tablas»), de 0,2 a 0,6 s cada uno, y c6 otra vez (7 en
    true); las marcas, 2026100201, 2026092601, 2026100201 y 2026100301. La
    foto de lo guardado, igual después del pegado; al casar otra vez solo
    cambia la propuesta del pendiente (se rehace una vez: su firma cambió;
    el mismo motivo, «sin_ticket»); las cuatro suites, cada una sola y en
    verde (17.6: 4,2 s, 4,5 s, 38,8 s y 19,5 s; 16: 3,7 s, 4,1 s, 36,4 s y
    17,8 s), con la foto igual después de cada una. El control, con ese
    banco y sin la apertura, en rojo solo por «prepagados» (lo esperado,
    como en la ronda 4).
- **La prueba final de la ronda 4b de c6, entera (3-oct)**, de cero, con
  los archivos de la entrega (c6-banco.sql y c6-pruebas.sql de la 4b,
  marca 2026100301; c2 y c4 2026100201; c3 2026092601; sin commit encima
  de 9d0c387), en 16.13 y en 17.6:
  - De cero (la carga completa de §0b): c2-pruebas 83/83 (4,2 s en 17.6 y
    3,6 s en 16), c3-pruebas 120/120 (4,6 s y 4,2 s), c4-pruebas 113/113
    en 17.6 (38,6 s; en 16, 112 y la 109 «omitida», 35,1 s) y c6-pruebas
    142/142 (18,8 s y 17,3 s). Los resúmenes del pegado, como dice §0
    (c6: 7 filas en true, «14 tablas»).
  - Los repros de la ronda 4 (h01–h17, e01–e12, p01–p06; la R01, ninguna
    función de c6 nombra una de c4 con su paréntesis), sus extras
    (x01–x16) y lo que encontró su prueba final ((1) el depósito desde la
    personal del monto de una factura, x13b y x13c; (2) el primer pase a la
    reserva antes de su estado de cuenta, x14, x15 y x16; (3) la «falta» de
    octubre sin la conciliación de apertura; (4) el anticipo de la H08):
    ninguno reproduce, en 16 y en 17.6 (salidas iguales salvo los ids). La
    del primer QFX subido a la cuenta equivocada del grupo del importador
    sigue rechazada (es la H11). Lo que la 4b vio y no tocó sigue así:
    «TO CHK ...7781» se lee como el cheque 7781 (con la apertura posteada
    sin conciliar, un pase de los primeros 30 días pide motivo en todos sus
    botones), y la «falta» de la conciliación de apertura nombra sus
    partidas en un orden que no es fijo (la H09 salió en otro orden).
  - **El ataque al principio** (en `scratchpad/ronda4/final-4b/atq`: un
    arnés pulsa cada botón sin «pide_motivo» tal cual, en una subtransacción
    que se deshace, y mira si falla, si deja una línea al patrimonio sin
    motivo ni cuenta personal, y si pone un cuadre en rojo). **Aguanta**:
    ningún botón pulsado tal cual pone el control en rojo; la cuenta
    personal dada de alta (también por Plaid, con los montos al revés) da
    sus botones al patrimonio sin motivo y el control en verde aunque haya
    una factura del mismo monto; un número que no se conoce (la reserva sin
    alta, una tarjeta nueva, la línea de crédito, una cuenta de otro banco)
    sale «cuenta_desconocida» y sus botones al patrimonio piden motivo; los
    intereses y la devolución con la débito del monto de una factura piden
    motivo; el cajero y el Zelle de Edgar, también; dar de baja la cuenta
    personal frena en vivo (MX008) los botones viejos hasta el siguiente
    «Casar», que los rehace; y en sus guardas: dar de alta como personal
    un número de la empresa (MX004), sin nombre o sin motivo de baja, subir
    el estado de cuenta de la personal (OFX, Plaid, lote confirmado: MX004),
    la nómina con 3200 sin motivo, un préstamo en 1130, 2900 o 3100 y un
    descriptor al patrimonio, la tabla por fuera de su función (MX003), su
    policy (solo lectura del dueño; el equipo lee 0, anon no entra) y
    `fn_banco_cuenta_personal` sin grant a la app. **Encontró** (iguales en
    16 y en 17.6; lo de R3 de la (a), la (c) y la (d) pasaban ya con la
    ronda 4 —el c6 de 23cb777, con los mismos pasos—; la (b), la (e), la
    (f) y la (g) son de lo que trae la 4b —la cuenta personal dada de alta,
    el texto de «cuenta_desconocida», su cabecera, «otro_lado_clasificado»—;
    la 4b no cubre ninguna):
    (a) **importante**: R3 junta solo un lado que nombra un número que no
    se conoce con el movimiento de otra cuenta propia cuyo número sí se
    conoce y es otro —«TO CHK ...7781» con el depósito de la reserva
    ····1097 (y al llegar el pase de verdad, «A 1030» sin motivo deja la
    reserva con 2,000.00 en tránsito para siempre), «CARD ENDING IN 5555»
    con el pago recibido de la Gold ····2013, «FROM CHK ...7781» en la
    reserva con el pase de Chase—; si no los junta, el botón «Es la
    transferencia con …» no pide motivo, ni `fn_banco_casar_con`
    `{"movimiento"}`; (b) **importante**: aun con la cuenta (o la tarjeta)
    personal dada de alta, «Desde 1010» —sin motivo— en el depósito de la
    reserva o en el pago recibido de la Gold casa solo, en la misma llamada
    («R3 la otra mitad de la transferencia»), el pase de Chase a la cuenta o
    tarjeta personal, que «Es la transferencia con 1010 …» pedía con
    motivo; y al revés (la reserva antes que Chase: «Desde 1010» es su
    único botón), al llegar Chase su pase a la personal casa solo al
    «Casar» con el asiento de «Desde 1010» (la consulta del paso 1 de
    «Después de c6» lo enseña); (c) **importante**: con el estado de
    cuenta de la reserva antes que el de Chase, su depósito «FROM CHK
    ...4392» (Chase, conocido) sale «deposito_parcial» con «Parte de la
    factura #…» primero y sin motivo, y «Desde 1010» al final; pulsado el
    primero, la factura queda
    cobrada con dinero de Chase y el pase de Chase después, «A 1030», sin
    motivo; (d) menor: un pase nombrado por su nombre («TO EDGAR M
    PERSONAL») ofrece «A 2100-2009» y «A 2100-2013» sin «pide_motivo», y
    pulsados fallan (MX008); (e) menor: la línea de crédito no se puede dar
    de alta (el lote vacío a 2510, MX004), aunque el texto de
    «cuenta_desconocida» lo proponga; (f) menor: la cabecera de c6 dice
    que en «cuenta_desconocida» van «primero las cuentas propias», y en un
    depósito van al final, detrás del patrimonio y de las facturas (las
    cuentas propias y el patrimonio, con su motivo); y (g) menor: con el
    depósito de la reserva («FROM EDGAR M MARTINEZ») ya clasificado a 3100
    con su motivo, el pase de Chase a la cuenta personal dada de alta sale
    «otro_lado_clasificado» («Des-casar el depósito … es el otro lado de
    esta transferencia» y «A 1030», los dos con motivo) y no ofrece su
    distribución (3200); a mano, `fn_banco_clasificar` a 3200 entra sin
    motivo y el control sigue en verde. Y una observación: dada
    de baja la cuenta personal, la bandeja enseña sus botones viejos sin
    motivo hasta el siguiente «Casar»; pulsados, MX008 (el principio se mira
    en vivo). Ninguno toca lo guardado ni pone el control en rojo;
    quedaron para c6 y los arregla la 4c (§0, «La ronda 4c de c6»; los
    remedios de mientras ya no están en «Después de c6»).
  - Idempotencia: c1, c2, c3, c4 y c6 pegados dos veces más sobre la misma
    base (0,1 a 0,6 s cada uno) y las cuatro suites otra vez, cada una sola
    (17.6: 3,9 s, 4,6 s, 37,8 s y 19,6 s; 16: 3,4 s, 3,8 s, 34,7 s y
    17,3 s), en verde; la foto cambia solo lo de siempre (el comentario de
    las tres huellas y el cuerpo de `fn_estados_huellas()`).
  - El camino de producción (§0b), en los dos: c1–c6 de d80c9de con el
    banco en uso (lo de la ronda 4, más dos pases de noviembre con la
    cuenta personal sin dar de alta y uno a la reserva sin su número: la
    versión de producción los propone «A 1030», «A 2100-…» y «Desde 1030»
    sin motivo). El c6 nuevo antes que c2 y c4 para con MX000 sin tocar
    nada; después c2 (10 en true), c4 (9; en false solo las dos de la
    apertura) y c6 (7 en true, «14 tablas»), de 0,2 a 0,6 s, y c6 otra vez;
    las marcas, 2026100201, 2026092601, 2026100201 y 2026100301; la foto de
    lo guardado, igual después del pegado; el primer «Casar» solo cambia la
    propuesta de lo pendiente (los tres pases, ahora «cuenta_desconocida»
    con todo con motivo); las cuatro suites, cada una sola y en verde (17.6:
    4,1 s, 4,3 s, 38,5 s y 18,1 s; 16: 3,6 s, 3,9 s, 35,5 s y 17,9 s), con la
    foto igual después de cada una. Después, lo de «Después de c6»: la
    cuenta personal dada de alta (sus pases, «transferencia_personal») y el
    número de la reserva con su lote vacío («A 1030» sin motivo). El
    control, sin la apertura, en rojo solo por «prepagados».
  - Sin rastro: la foto de la base igual antes y después de cada suite, en
    la base de cero y en la del camino de producción.
  - Scripts, en 16 y en 17.6, en verde: c2-pegado (18 ok),
    c4-concurrencia (17), c6-concurrencia (24; importar y casar dos veces
    1,1 s, la subida más lenta 0,19 s en 17.6 y 0,17 s en 16) y c6-en-uso
    (21; octubre: 4,0 s, 4,7 s, 38,6 s y 18,7 s en 17.6; noviembre, 113 + 7
    y 139 + 3 «omitidas»). En 17.6, c3-volumen con 3.000 recibos (reintentar 1,5 s,
    controles 1,8 s) y c4-volumen con 10.333 asientos (las vistas, 0,51 s
    como mucho; el Panel en una llamada 2,1 s; como en producción —se
    informa: tres veces lo de Edgar— el Panel no terminó en 9 llamadas, y
    'hoy', los estados y el año llegan a llamadas de 0,88 s, 0,97 s y
    1,06 s; c4-pruebas 83,8 s con 2026 abierto y 90,0 s cerrado, c3-pruebas
    98,2 s, la subida más lenta 3,5 s y 5,0 s; medido con el ataque
    corriendo a ratos). c6-volumen con la plantilla del libro (9.990
    movimientos), 17.6 y 16: casar 1,95 s por mes como mucho, la bandeja
    0,37 s y 0,36 s, conciliar 0,38 s, el control 0,52 s y 0,46 s,
    `fn_banco_verificar` 3,1 s y 2,9 s, volver a pegar c6 2,0 s y 1,6 s,
    **c6-pruebas sola 36,0 s y 30,5 s (bajo su tope de 40 s)** y con cuatro
    teléfonos 40,7 s y 34,5 s (la subida más lenta 2,6 s y 2,0 s); los
    meses 13 y 14 sin casar, «Cuadrar» 1,0 s y 0,9 s y casar 2,9 s y 2,7 s.
    El año de Edgar en 17.6 (200 papeles por mes, 3.167 asientos y 2.473
    movimientos), lo de producción exigido: el Panel en 4 llamadas (la más
    lenta 0,46 s), 'hoy', los estados y el año en 2 (0,50 s como mucho);
    con el banco en uso, el Panel en 4 llamadas de 0,49 s como mucho; casar
    0,79 s por mes como mucho, la bandeja 0,13 s, el control 0,30 s,
    c6-pruebas sola 25,1 s y con cuatro teléfonos 29,7 s. Lo ajeno (R01),
    en 17.6 con la base recién pegada, sin c6 y con c6: el Panel, de 400 a
    494 ms y de 432 a 504 ms; 'hoy', de 190 a 196 ms y de 217 a 221 ms;
    `fn_verificar_cadena`, de 69 a 76 ms y de 88 a 97 ms.
- **La ronda 4c de c6 (3-oct)**, con c6-banco marca 2026100302 (c2 y c4,
  2026100201; c3, 2026092601; sin commit, encima de 594054b), en 16.13 y
  en 17.6:
  - De cero (la carga completa de §0b), con los archivos de la entrega:
    c2-pruebas 83/83, c3-pruebas 120/120 (4,4 s en 17.6 y 4,1 s en 16),
    c4-pruebas 113/113 en 17.6 (37,3 s; en 16, 112 y la 109 «omitida»,
    38,6 s) y c6-pruebas 153/153 (19,9 s en 17.6 y 19,4 s en 16). Los resúmenes del pegado, como dice §0 (c6: 7 filas en
    true, «14 tablas»). Contra el c6 de la 4b (594054b) salen en rojo las
    11 nuevas (143 a 153) y las 142 de antes siguen en verde.
  - **El arnés de la prueba final de la 4b, como puerta**
    (`scratchpad/ronda4/final-4b/atq`, con sus plantillas rehechas con la
    carga de hoy, y siete escenarios nuevos, K1 a K7, uno por camino
    tocado: «Desde 1010» con su motivo y la personal dada de alta; la
    línea de crédito 2510 dada de alta y su «Casar»; un préstamo 2520 por
    su número; la tarjeta personal; R2 con un cobro anotado y el depósito
    de una cuenta propia; R3 con «DEPOSIT» y con «TO SAVINGS» / «FROM
    CHECKING»; el cheque que no es cheque y el aviso de la apertura): en
    los 28 escenarios, ningún botón ofrecido sin «pide_motivo», pulsado
    tal cual, falla, pone un cuadre en rojo o lleva dinero al patrimonio
    sin motivo (al patrimonio, solo con la cuenta personal dada de alta:
    9 botones en A, 6 en I y 3 en K1); R3 solo junta lo que los dos lados
    confirman (el pase a ····1097 con el depósito que nombra ····4392,
    «DEPOSIT» con el pase que lo nombra, «TO SAVINGS» con «FROM
    CHECKING»). Lo que encontró la prueba final de la 4b ya no se
    reproduce: C, C3 y C4 (R3 no los junta: pendientes, y juntarlos a mano
    pide motivo); C2 (MX008 sin motivo, con él entra); C2t, C2u y C3s
    («Desde 1010» pide motivo, y con él, el pase a la personal no casa
    solo: la bandeja propone juntarlos con su motivo o des-casar); H y H2
    (el depósito «FROM CHK ...4392» es su transferencia: «Desde 1010»
    primero, la factura con motivo; cobrarlo tal cual, MX008; al llegar
    Chase, R3 casa los dos); F («otro_lado_nombrado», sin botones que
    fallen); E (la línea de crédito se da de alta por su número:
    «deuda_propia»); C2v («transferencia_personal», con su 3200 tal cual);
    G (la baja rehace las propuestas). Salidas iguales en 16 y en 17.6.
  - Los repros de la ronda 4 (h01–h17, e01–e12, p01–p06), sus extras
    (x01–x16) y lo que encontró la prueba final de la 4b ((1) x13b y x13c
    —que pulsan «el botón 1» por su lugar, y el primero es ahora «Desde
    1030» con su motivo: x13d los busca por su cuenta: el 2900 tal cual,
    MX008, y con su motivo entra y el control sigue en verde—, (2) x14 a
    x16, (3) la «falta» de octubre, (4) el anticipo de la H08): ninguno
    reproduce, en 16 y en 17.6. Contra la 4b cambia solo lo buscado: «Lo
    que falta: …», el orden de un depósito de un número que no se conoce
    («Desde 1030» primero), un pase que no es el pago de una tarjeta ya no
    ofrece «A 2100-…», y la firma de las propuestas.
  - Idempotencia: c1–c6 pegados dos veces más sobre la base de cero (0,1 a
    0,6 s cada uno) y las cuatro suites otra vez, cada una sola (17.6: 4,0
    s, 4,1 s, 39,1 s y 20,9 s; 16: 3,4 s, 4,0 s, 34,4 s y 17,7 s), en
    verde; la foto cambia solo lo de siempre (el comentario de las tres
    huellas y el cuerpo de `fn_estados_huellas()`) y ninguna suite la
    cambia.
  - **El camino de producción desde d80c9de** (§0b), en los dos: c1–c6 de
    d80c9de con el banco en uso (lo de la 4b). El c6 nuevo antes que c2 y
    c4 para con MX000 sin tocar nada (foto y catálogo iguales); después c2
    (0,2 a 0,3 s), c4 (0,5 a 0,6 s) y c6 (0,5 a 0,6 s; sus 7 filas en
    true, «14 tablas»), y c6 otra vez; las marcas, 2026100201, 2026092601,
    2026100201 y 2026100302; la foto de lo guardado, igual; el primer
    «Casar» rehace solo las propuestas de lo pendiente; las cuatro suites,
    cada una sola y en verde (17.6: 4,0 s, 5,6 s, 40,4 s y 21,8 s; 16: 3,6
    s, 4,0 s, 35,2 s y 18,7 s), con la foto igual después de cada una.
    Después, lo de «Después de c6»: la cuenta personal («Rehecha la
    propuesta de 2 movimiento(s) pendiente(s) que la nombran»: sus dos
    pases, «transferencia_personal») y el número de la reserva («A 1030»
    sin motivo). La consulta de «Lo ya casado por la 4b», sin filas. El
    control, sin la apertura, en rojo solo por «prepagados» (como en la 4b).
  - **Encima de la 4b (594054b), con el banco en uso** (en los dos): lo de
    arriba más la cuenta personal ····7781 y el número de la reserva
    ····1097 dados de alta como decía su README, la reserva de noviembre
    (el pase de Chase por su número, que R3 casa; dos depósitos «FROM
    EDGAR M MARTINEZ»), «Desde 1010» pulsado en uno —y, al llegar Chase,
    su pase a la personal casado solo, «R3 la otra mitad»— y el pago a una
    tarjeta ····5555 que R3 casó con el pago recibido de la Gold; las
    conciliaciones de octubre de 1010 y de la Gold, confirmadas. Solo c6
    (0,5 s; sus 7 filas en true); la foto de lo guardado, igual; el primer
    «Casar» rehace las 4 propuestas pendientes (el otro depósito «FROM EDGAR
    M MARTINEZ», «otro_lado_nombrado», todo con su motivo); la consulta de
    «Lo ya casado por la 4b» da 3 filas (el pase a la personal y las dos
    mitades del pago a ····5555; el pase por su número, no); las cuatro
    suites en verde (17.6: 3,9 s, 4,3 s, 38,5 s y 21,3 s; 16: 3,5 s, 4,1 s,
    34,8 s y 20,8 s) con la foto igual; c6 otra vez, igual. Y el remedio
    del README: des-casar las filas una a una (dos llamadas: la otra mitad
    del pago se suelta con ella), el botón «Des-casar el depósito …: no es
    el otro lado de este» que la bandeja da al pase, su 3100 con motivo y
    el 3200 del pase tal cual: la consulta, sin filas, y el control como
    antes. **Lo encontró esta prueba** (y se arregló en c6-pruebas): con
    la personal ····7781 y la reserva ····1097 dadas de alta, 38 pruebas
    salían en rojo (MX004: son números de las pruebas); `c6_montar` los
    aparta ahora dentro de cada prueba. Y que la firma no llevaba la marca
    de la versión (la 153).
  - Sin rastro: la foto de la base igual antes y después de cada suite, en
    la base de cero y en las de los dos caminos de actualización.
  - Scripts, en 16 y en 17.6, en verde: c6-en-uso (21 ok; octubre: 4,2 s,
    4,6 s, 42,7 s y 20,7 s en 17.6 y 3,4 s, 5,1 s, 34,4 s y 18,5 s en 16;
    noviembre, 113 + 7 y 150 + 3 «omitidas»), c6-concurrencia (24 ok;
    importar y casar dos veces 1,0 s y 1,2 s, la subida más lenta 0,17 s y
    0,22 s) y c6-volumen con la plantilla del libro (9.990 movimientos):
    casar 2,2 s y 2,5 s por mes como mucho, la bandeja 0,41 s, conciliar
    0,43 s y 0,34 s, `fn_banco_verificar` 3,1 s y 2,9 s, volver a pegar
    c6 1,9 s y 1,6 s, **c6-pruebas sola 37,5 s en 17.6 y 34,5 s en 16
    (bajo su tope de 40 s)** y con cuatro teléfonos 44,5 s y 39,7 s (la
    subida más lenta 2,4 s y 2,1 s). Ese día la de la 4b, sobre la misma
    base del año en 17.6, tardaba de 36,4 a 38,1 s: lo que añade la 4c son
    sus 11 pruebas (2,1 s, medidas una a una); por llamada, «Casar», el
    contexto y la firma tardan lo mismo que en la 4b. El banco de pruebas
    varía de una corrida a otra: en copias de esa base hechas aparte
    (frías, o calientes después de otra corrida), la de la 4c dio de 38,7
    a 41,2 s en 17.6, y la de la 4b de 36,4 a 38,1 s; la medida de
    `c6-volumen.sh` es la de la base caliente y asentada (37,5 s; la
    primera vez, con la 144 de antes, 38,0 s).
- **La prueba final de la ronda 4c de c6, entera (3-oct)**, de cero, con
  los archivos de la entrega (c6-banco.sql, marca 2026100302, y
  c6-pruebas.sql de la 4c; c2 y c4 2026100201; c3 2026092601; sin commit,
  encima de 74ad44f), en 16.13 y en 17.6:
  - De cero (la carga completa de §0b): c2-pruebas 83/83 (4,3 s en 17.6 y
    3,5 s en 16), c3-pruebas 120/120 (4,5 s y 3,9 s), c4-pruebas 113/113
    en 17.6 (38,7 s; en 16, 112 y la 109 «omitida», 34,2 s) y c6-pruebas
    153/153 (20,3 s y 18,3 s). Los resúmenes del pegado, como dice §0 (c6:
    7 filas en true, «14 tablas»).
  - Los repros de la ronda 4 (h01–h17, e01–e12, p01–p06), sus extras
    (x01–x16; x13b y x13c pulsan «el botón 1» por su lugar, y x13d los
    busca por su cuenta), lo que encontró la prueba final de la 4b (de la
    (1) a la (4)) y el arnés de la 4b, con sus 21 escenarios y los K1 a K7
    del corrector: ninguno reproduce, en 16 y en 17.6. Salidas iguales a
    las del corrector salvo la hora del aviso «Este archivo ya entró el
    …», el orden de las partidas de la falta de la apertura (la H09: sin
    orden fijo, ya dicho) y una huella. En el arnés, ningún botón ofrecido
    sin «pide_motivo», pulsado tal cual, falla, pone un cuadre en rojo o
    lleva dinero al patrimonio sin motivo (al patrimonio, solo con la
    cuenta personal dada de alta: 9 botones en A, 6 en I y 3 en K1). La
    del primer QFX en la cuenta equivocada del grupo sigue rechazada (es la
    H11), y lo que rechazó el corrector sigue igual: en el pago recibido de
    la Gold, «Desde 1030» sin motivo y el primero con la reserva sin abrir
    (pulsado, 1030, sin estado de cuenta, queda en negativo y nada lo dice
    hasta que la reserva traiga el suyo), y en un depósito que nombra a una
    persona sin número, sus facturas sin motivo.
  - **El ataque a EL CRITERIO** (en `scratchpad/ronda4/final-4c/atq`, de
    L01 a L17 y L02b: el arnés de la 4b y un auditor que mira EL CRITERIO
    en cada transferencia casada que queda guardada y busca dinero del
    banco al patrimonio sin motivo ni cuenta personal). **Aguanta**: R3 no
    junta nada que se contradiga —montos redondos repetidos el mismo día a
    la reserva y a tu cuenta personal, el orden al revés, el otro lado
    bueno y uno que lo contradice llegando juntos (empate: se propone)—, y
    el «DEPOSIT» a secas, solo con el pase que lo nombra; juntar a mano lo
    que se contradice pide motivo, y des-casado, «Casar» no lo vuelve a
    juntar; tu cuenta personal dada de alta, de baja y de alta otra vez
    rehace sus botones en cada paso, con el control en verde; la tarjeta
    personal del mismo emisor que las de la empresa, nombrada «CARD ENDING
    …», es personal; la línea de crédito y un préstamo por su número
    («deuda_propia»; un número repetido, MX004 en los tres sentidos); un
    depósito desde una cuenta propia por su número con facturas abiertas o
    cobros que lo suman: «Desde …» primero, lo demás con motivo, y R2 no lo
    junta con los cobros. **Encontró** (iguales en 16 y en 17.6; ninguno
    pone el control en rojo):
    (1) **importante**: R1 casa sola la línea de un **asiento escrito a
    mano** (`fn_postear` desde el SQL Editor: clase «asiento») sin mirar
    EL CRITERIO. Un pase a la reserva anotado a mano (Dr 1030 / Cr 1010,
    2,000.00) casa solo con el depósito de la reserva que el banco dice
    que viene de tu cuenta personal dada de alta («ONLINE TRANSFER FROM
    CHK ...7781»), y con el retiro de Chase a ella («TO CHK ...7781»); un
    pago de la Gold anotado a mano, con el pago de Chase a una tarjeta
    ····5555 que no se conoce; dos aportaciones tuyas anotadas a mano (Dr
    1010 / Cr 3100), con el pase desde la reserva por su número («FROM SAV
    ...1097»: el dinero de la reserva, como tu aportación) y con un
    depósito por lo que la factura #1101 tiene abierto (la factura sigue
    abierta). Todos «R1 cruce exacto con el libro», solos; y sin el número
    dado de alta, el botón «Confirmar cruce con asiento …» no pide motivo
    (L02, L02b, L16).
    (2) **importante**: el **cobro que c3 registra con su movimiento**
    (`fn_cobro_registrar` con `"movimiento_id"`, con grant a la app) casa
    solo, «R2 el cobro dice este movimiento», aunque el depósito de la
    reserva diga que viene de Chase por su número (lo que la 4c frena en
    `fn_banco_cobrar` y en `fn_banco_casar_con`); al llegar Chase, su
    pase sale «A 1030» sin motivo y es su único botón, y pulsado, 1030
    queda con 4,000.00 en libros y 2,000.00 en el banco (el pase, «en
    tránsito»), con el control en verde: la (c) de la 4b por otro camino
    (L03). La consulta de «Lo ya casado por la 4b» lo enseña.
    (3) **menores**: (3a) tu tarjeta personal dada de alta, nombrada por
    sus 4 últimos sueltos («AMEX EPAYMENT ACH PMT 1006»), no cuenta (los
    sueltos solo se leen de las tarjetas de la empresa) y R3 junta ese
    pago con el pago recibido de la Gold por lo mismo (L06); (3b) el pago
    de una tarjeta de otro emisor («CHASE CREDIT CRD AUTOPAY», «BANK OF
    AMERICA CREDIT CARD BILL PAYMENT»; las de la empresa son Amex) sale
    «entre cuentas propias» y R3 lo junta con un pago recibido de la Gold
    del mismo monto en su ventana (L13); (3c) con «Desde 1010» en la
    reserva («FROM CHK ...4392»), un cheque de Chase por lo mismo tres días
    antes casa solo como «R3 la otra mitad» (la regla del «DEPOSIT» a
    secas vale también para un cheque; L14); (3d) la partida en tránsito
    de la conciliación de apertura (el cheque de un cliente) casa sola, la
    primera semana, con un depósito que el banco dice que viene de tu
    cuenta personal dada de alta (L17); (3e) Plaid con el nombre corto
    («Online Transfer to CHK», sin número) da «A 1030» sin motivo, y el
    QFX del mismo movimiento, con el número de tu cuenta personal, entra
    como «posible_duplicado» y «Es el mismo (no entra)» lo descarta sin
    decir que contradice lo casado (L10); (3f) el nombre de QuickBooks de
    la Gold («1007») hace de ····1007 un número de la Gold: una cuenta
    ····1007 de otro sale «propia», y una personal ····1007 no se podría
    dar de alta (MX004; L15); (3g) dar de alta un número con el lote vacío
    (la reserva, la línea de crédito) no rehace lo pendiente que lo nombra
    —la cuenta personal sí—: hasta el siguiente «Casar», sus botones
    viejos («Factura #…», sin motivo) dicen MX008 (L01); (3h) el
    desembolso de la línea de crédito por lo que una factura tiene abierto
    pide motivo (bien), pero su texto dice primero «sin motivo» (L01b), y
    clasificado a un gasto entra sin motivo (L12); (3i) a un depósito del
    3-nov se le ofrece «Es la transferencia con 1010 del 9-nov», un retiro
    posterior (L08); (3j) después del pegado, hasta el primer «Casar», la
    bandeja enseña los botones de antes, y pulsados dicen MX008 sin tocar
    nada (encima de 594054b, el «Desde 1010» sin motivo de la 4b; encima
    de d80c9de, sus «A 1030» y «A 2100-…»); (3k) en «Lo ya casado por la
    4b», des-casar primero el depósito de un par que R3 juntó suelta solo
    ese: el retiro (el que puso el asiento) queda «en_transito» y sale de
    la consulta, y el README decía que se soltaban los dos. (3j) y (3k), y
    el «Casar» después del lote vacío, ya los dicen §0 y «Después de c6»;
    lo demás queda para c6.
  - Idempotencia: c1–c6 pegados dos veces más sobre la base de cero (0,1 a
    0,6 s cada uno) y las cuatro suites otra vez, cada una sola (17.6: 3,7
    s, 4,3 s, 37,5 s y 20,8 s; 16: 3,5 s, 3,9 s, 34,6 s y 18,4 s), en
    verde; la foto cambia solo lo de siempre (el comentario de las tres
    huellas y el cuerpo de `fn_estados_huellas()`), y ninguna suite la
    cambia.
  - **El camino de producción desde d80c9de** (§0b), en los dos: c1–c6 de
    d80c9de con el banco en uso (lo de la 4b: octubre de Chase y de la
    Gold casado, clasificado y conciliado, la póliza, la nómina, un ticket
    de CED, y noviembre con pases a tu cuenta personal sin dar de alta y a
    la reserva sin su número). El c6 nuevo antes que c2 y c4 para con
    MX000 (nombra c2-libro.sql y c4-estados.sql) sin tocar nada (foto y
    catálogo iguales); después c2 (0,2 s; sus 10 en true), c4 (0,5 a 0,6
    s; 9, en false solo las dos de la apertura) y c6 (0,5 s; 7 en true,
    «14 tablas»), y c6 otra vez; las marcas, 2026100201, 2026092601,
    2026100201 y 2026100302; la foto de lo guardado, igual; el primer
    «Casar» rehace solo las propuestas de los 4 pendientes; las cuatro
    suites, cada una sola y en verde (17.6: 4,0 s, 4,3 s, 38,6 s y 20,1 s;
    16: 3,5 s, 4,0 s, 34,6 s y 18,1 s), con la foto igual después de cada
    una. Después, lo de «Después de c6»: la cuenta personal (sus dos pases,
    «transferencia_personal») y el número de la reserva («A 1030» sin
    motivo). La consulta de «Lo ya casado por la 4b», sin filas. El
    control, sin la apertura, en rojo solo por «prepagados» (el escenario,
    como en la 4b).
  - **Encima de la 4b (594054b), con el banco en uso** (en los dos): lo de
    arriba, la cuenta personal ····7781 y el número de la reserva ····1097
    dados de alta como decía su README, lo que la 4b casaba solo y se
    contradice (el pase a la personal con el «Desde 1010» de la reserva; el
    pago a ····5555 con el pago recibido de la Gold) y otro pago a ····5555
    de 720 que la Gold trae un día antes que Chase. Solo c6 (0,5 s; 7 en
    true); la foto de lo guardado, igual; antes del primer «Casar», el
    «Desde 1010» sin motivo de la 4b dice MX008 (3j); «Casar» rehace las 4
    propuestas pendientes; la consulta de «Lo ya casado por la 4b» da 5
    filas (el pase a la personal y las dos mitades de los dos pagos a
    ····5555); las cuatro suites en verde (17.6: 3,9 s, 4,4 s, 36,7 s y
    21,0 s; 16: 3,5 s, 3,8 s, 33,0 s y 18,5 s) con la foto igual; c6 otra
    vez, igual. El remedio, una fila cada vez: el pase a la personal y el
    pago de 640 (su retiro suelta las dos mitades), bien; del de 720 la
    primera fila es el depósito de la Gold, y des-casarlo soltó solo ese
    (3k); des-casado después el retiro, los dos pendientes. El control,
    solo «prepagados».
  - Sin rastro: la foto de la base igual antes y después de cada suite, en
    la base de cero y en las de los dos caminos de actualización.
  - Scripts, en 16 y en 17.6, en verde: c6-en-uso (21 ok; octubre: 3,9 s,
    5,1 s, 37,8 s y 19,3 s en 17.6 y 3,5 s, 4,9 s, 34,6 s y 17,9 s en 16;
    noviembre, 113 + 7 y 150 + 3 «omitidas»), c6-concurrencia (24 ok;
    importar y casar dos veces 1,0 s y 0,9 s, la subida más lenta 0,14 s
    y 0,16 s), c2-pegado (18 ok) y c4-concurrencia (17 ok). En 17.6,
    c3-volumen con 3.000 recibos (reintentar 1,3 s, controles 1,6 s) y
    c4-volumen con 10.333 asientos (las vistas, 0,51 s como mucho; el
    Panel en una llamada 2,0 s; como en producción —se informa— el Panel
    no terminó en 9 llamadas, y 'hoy', los estados y el año llegan a
    llamadas de 0,97 s, 0,92 s y 0,95 s; c4-pruebas 77,0 s con 2026
    abierto y 88,0 s cerrado, c3-pruebas 96,5 s; con cuatro teléfonos, la
    subida más lenta 2,2 s, 5,0 s y 2,4 s). c6-volumen con la plantilla
    del libro (9.990 movimientos), 17.6 y 16: casar 2,9 s y 2,0 s por mes
    como mucho, la llamada más lenta de la bandeja 0,37 s y 0,32 s,
    conciliar 0,39 s y 0,38 s, el control 0,55 s y 0,45 s,
    `fn_banco_verificar` 3,2 s y 2,8 s, volver a pegar c6 2,0 s y 1,5 s,
    **c6-pruebas sola 37,5 s y 32,8 s (bajo su tope de 40 s)** y con
    cuatro teléfonos 42,6 s y 36,7 s (la subida más lenta 2,4 s y 2,1 s);
    los meses 13 y 14 sin casar, «Cuadrar» de 0,6 a 0,9 s y casar 2,8 s y
    2,6 s.
- **La ronda 4d de c6 (3-oct)**, con c6-banco marca 2026100303 (c2 y c4,
  2026100201; c3, 2026092601; sin commit, encima de 9849564), en 16.13 y
  en 17.6, con el archivo entero y con sus dos partes:
  - De cero (la carga completa de §0b): c2-pruebas 83/83, c3-pruebas
    120/120, c4-pruebas 113/113 en 17.6 (en 16, 112 y la 109 «omitida») y
    c6-pruebas 161/161 (22,2 s en 17.6 y 20,2 s en 16); con las dos partes de
    c6 en vez del entero, lo mismo (22,4 s y 20,6 s). Los resúmenes del
    pegado, como dice §0 (c6: 7 filas en true, «14 tablas»; la parte 1, su
    fila «c6 · parte 1 de 2»). Contra la 4c (9849564; durante la ronda, la
    154 a la 161 sin su comprobación de la marca) salen en rojo las ocho
    nuevas; la 154 dice lo que pasaba: con los diez casados que se
    contradicen, el control entero en verde y la conciliación confirmada.
  - **Las dos partes** (`c6-partes.sh`, en los dos): la foto del catálogo
    de la base con las dos partes es la del archivo entero (1.230 objetos:
    cada función con su definición, sus permisos y su search_path, tablas,
    vistas, índices, policies, triggers, comentarios, las huellas del
    banco y de c2); la parte 2 sola para con MX000 y la base no cambia;
    cada parte otra vez, la foto igual; c6-pruebas encima, 161/161.
  - Los repros de la ronda 4 (h01–h17, e01–e12, p01–p06), sus extras
    (x01–x16, x13b, x13c y x13d) y lo que encontró la prueba final de la
    4b (de la (1) a la (4)): ninguno reproduce, en 16 y en 17.6, salidas
    iguales en los dos. Contra la 4c cambia solo lo buscado: el control y
    la revisión traen su fila nueva («el otro lado de cada casado»), la
    revisión con cuentas pedidas ya no trae los cuadres del control, la
    firma de las propuestas (lleva la marca), el orden de lo que falta en
    la conciliación de apertura (la H09) y la huella del banco; y en la h02
    —un cobro de 1,000.00 al que se le pone a mano el movimiento de su
    depósito neto, 970.70, en una transacción que se deshace— la propuesta
    es ahora «cobro_que_lo_nombra» (antes «deposito_parcial»): sin el
    botón de su comisión, que se puede pedir con `fn_banco_casar_con` y
    `"comision"` (por el camino de c3 el cobro y el movimiento son del
    mismo monto). **Lo encontró esta verificación** (la e07, y se arregló):
    el aviso nuevo del duplicado salía siempre, vacío («Ojo: si es el
    mismo, aquel está mal casado: .»), y el de `fn_banco_clasificar` de la
    4c también («Ojo: . Si no es este dinero…»): `format` con un argumento
    nulo da '' y no nulo. Ahora solo cuando se contradicen (la 158,
    ampliada: con el c6 de antes del arreglo sale en rojo).
  - **El arnés** (el de la prueba final de la 4b, sus 21 escenarios; los
    K1 a K7 de la 4c; y los L01 a L17 y L02b de la prueba final de la 4c,
    en `scratchpad/ronda4/corregir-4d/atq`), en los dos, salidas iguales:
    ningún botón ofrecido sin «pide_motivo», pulsado tal cual, falla, pone
    un cuadre en rojo o lleva dinero al patrimonio sin motivo (al
    patrimonio, solo con la cuenta personal dada de alta: 9 en A, 6 en I,
    3 en K1, 6 en L05, L06 y L08, 3 en L11); el auditor (EL CRITERIO sobre
    lo guardado al final) no encuentra nada, y el control, nada en rojo.
    Lo que encontró la prueba final de la 4c ya no se reproduce: L02, L02b
    y L16 (R1 no casa solo el asiento escrito a mano: se propone, y
    confirmarlo pide motivo), L03 (el cobro de c3 con su movimiento:
    «cobro_que_lo_nombra»; el pase de Chase propone anular ese cobro, sin
    «A 1030»), L06, L13 y L14 (la tarjeta personal por sus 4 últimos, el
    emisor, el cheque: R3 no los junta), L17 (la partida de la apertura no
    casa sola con lo de la personal), L10 (el duplicado con el número:
    «Es el mismo» pide motivo), L15, L01, L01b, L12, L08 y los botones de
    antes.
  - Idempotencia: c1–c6 —el entero y sus dos partes— pegados dos veces
    más sobre la base de cero (de 0,1 a 0,6 s cada uno) y las cuatro
    suites otra vez, cada una sola, en verde (17.6: 3,8 s, 4,3 s, 37,3 s y
    23,2 s; 16: 3,5 s, 4,1 s, 34,7 s y 20,3 s); la foto cambia solo lo de
    siempre (el comentario de las tres huellas y el cuerpo de
    `fn_estados_huellas()`), y ninguna suite la cambia.
  - **El camino de producción desde d80c9de** (§0b), en los dos, con el
    entero y con las partes: c1–c6 de d80c9de con el banco en uso (lo de
    la 4b). El c6 nuevo antes que c2 y c4 —el entero o su parte 1— para
    con MX000 y nombra c2-libro.sql y c4-estados.sql; la parte 2 sola, con
    MX000 («antes va la parte 1 de esta misma versión»); sin tocar nada
    (foto y catálogo iguales). Después c2 (0,2 s), c4 (0,5 a 0,6 s) y c6
    (0,5 a 0,6 s; sus 7 filas en true), y c6 otra vez; las marcas,
    2026100201, 2026092601, 2026100201 y 2026100303; la foto de lo
    guardado, igual; el primer «Casar» rehace solo las propuestas de lo
    pendiente; **EL CONTROL, en verde** (nada de lo que d80c9de casó se
    contradice: la aportación clasificada con su motivo, tampoco); las
    cuatro suites, cada una sola y en verde (17.6: 4,1 s, 4,7 s, 37,4 s y 23,3 s; 16: 3,5 s, 4,3 s, 35,2 s y 20,4 s), con la foto igual
    después de cada una; el catálogo, igual después del segundo pegado.
    Después, lo de «Después de c6» (la cuenta personal, el número de la
    reserva, «Casar»). El control, sin la apertura, en rojo solo por
    «prepagados» (como en la 4c).
  - **Encima de la 4c (9849564), con el banco en uso** (en los dos, con el
    entero y con las partes): lo de arriba más la cuenta personal ····7781
    y el número de la reserva ····1097 dados de alta, la reserva de
    noviembre, y lo que la 4c dejaba casar solo: un pase a la reserva
    escrito a mano (`fn_postear`) que R1 casó con lo que llegó de la
    personal, el cobro de la #1103 que la app registró con el pase de
    Chase («R2 el cobro dice este movimiento») y una aportación escrita a
    mano casada con el cheque de un cliente; la conciliación de noviembre
    de la reserva, confirmada con la 4c. Solo c6 (0,5 a 0,6 s; sus 7
    filas en true; la parte 2 sola, MX000); la foto de lo guardado,
    igual; **EL CONTROL dice los tres** («esperaba 0… y hay 3», cada uno
    con su movimiento, su casado, qué dice el banco y qué dice el libro);
    las cuatro suites en verde con ellos en la base (17.6: 4,1 s, 4,6 s, 39,1 s y 23,2 s; 16: 3,5 s, 4,1 s, 34,3 s y 21,0 s). El remedio
    del README, paso a paso: des-casar dentro de la conciliación
    confirmada dice cuál reabrir; reabierta, confirmarla otra vez no se
    deja («Lo que falta: 2 movimiento(s) casado(s) donde … se
    contradicen»); el pase a mano, des-casado y reversado, y «Casar»: tu
    préstamo (2900), sin motivo; el cobro, des-casado —queda vigente, sin
    su movimiento— y anulado, y «Casar»: «Desde 1010», sin motivo; la
    aportación, su motivo escrito (`{"casado": …}`). El control en verde,
    la revisión entera también, y la conciliación confirmada otra vez.
  - Sin rastro: la foto de la base igual antes y después de cada suite, en
    la base de cero y en las de los dos caminos de actualización.
  - Scripts, en 16 y en 17.6, en verde: c6-en-uso (21 ok; octubre: 4,0 s,
    4,3 s, 38,7 s y 21,7 s en 17.6 y 3,6 s, 4,1 s, 34,3 s y 19,0 s en 16;
    noviembre, 113 + 7 y 158 + 3 «omitidas»), c6-concurrencia (24 ok;
    importar y casar dos veces 1,1 s y 1,0 s, la subida más lenta 0,16 s
    y 0,18 s) y c6-volumen con la plantilla del libro (9.990 movimientos):
    casar 3,2 s y 2,3 s por mes como mucho, la llamada más lenta de la
    bandeja 0,41 s y 0,31 s, conciliar 0,45 s y 0,35 s, confirmar 0,46 s y
    0,39 s (27 confirmadas), el control 0,59 s y 0,50 s,
    `fn_banco_verificar` 3,1 s y 2,9 s, volver a pegar c6 2,0 s y 1,6 s,
    **c6-pruebas sola 36,8 s y 33,7 s (bajo su tope de 40 s)** y con
    cuatro teléfonos 43,5 s y 38,8 s (la subida más lenta 2,4 s y 1,9 s);
    los meses 13 y 14 sin casar, «Cuadrar» de 0,7 a 0,9 s y casar 4,0 s y
    3,6 s. En otra corrida ese día (antes de ampliar la 158), 38,4 s y
    36,0 s sola, y 43,9 s y 40,7 s con los teléfonos. Ese día, la de la 4c en la misma máquina y con la misma
    plantilla, en 17.6: 38,5 s sola y 44,5 s con los teléfonos. La 4d, la
    primera vez, 41,1 s (en rojo): `fn_banco_verificar` con cuentas pedidas
    pedía los cuadres del control, que miran todo el banco (un cuarto de
    segundo por llamada; c6-pruebas la llama nueve veces); ya no, y la 39
    se los pide al control.
- **La prueba final de la 4d (4-oct)**, con c6-banco marca 2026100303 (c2 y
  c4, 2026100201; c3, 2026092601), en 16.13 y en 17.6, con el archivo entero
  y con sus dos partes. El contenedor se reinició cuando le quedaban los
  scripts de las partes y el resumen; esos los terminó la sesión a mano.
  - De cero: c2-pruebas 83/83, c3-pruebas 120/120, c4-pruebas 113/113 (en
    16, 112 y la 109 «omitida») y c6-pruebas 161/161; con las dos partes de
    c6, lo mismo. La parte 2 sola para con MX000 y no toca nada.
  - Los repros de la ronda 4, sus extras, los (1)-(4) de la 4b y los
    escenarios A–I, K1–K7, L01–L17 y L02b (`ataques/`): ninguno reproduce;
    al final de cada uno el cuadre 59 y `fn_banco_verificar` en verde.
  - Idempotente (c1–c6 dos veces más y las suites otra vez) y sin rastro.
  - La actualización con el banco en uso, desde d80c9de (c2, c4 y c6, el
    entero y las partes) y desde 9849564 (solo c6): foto igual, resúmenes
    en true, suites en verde. EL CONTROL ve exactamente los tres casados
    que la 4c dejaba casar solos y se contradicen, y el remedio de §0 los
    limpia; uno dentro de una conciliación confirmada se arregla
    escribiendo su motivo.
  - Scripts, en verde en los dos: c6-en-uso, c6-concurrencia, c2-pegado,
    c4-concurrencia, c6-volumen (c6-pruebas sola con un año de banco:
    37,4 s en 17.6 y 32,6 s en 16; con cuatro teléfonos, 40,7 s y 37,9 s)
    y `c6-partes.sh` (las partes dejan la base igual que el entero;
    c6-pruebas encima, 161/161); en 17.6, c3-volumen y c4-volumen (666 por
    mes: nada en rojo).
  - El ataque a EL CONTROL (escenarios M de `ataques/`) encontró caminos que
    el control todavía no mira: la cuota de un préstamo registrada antes que
    el banco (M02, M03), el cheque devuelto registrado desde cobros con un
    movimiento ajeno o sin movimiento (M01, M01b), un pase por número casado
    solo con el ticket de una compra de la débito cuando llega antes que
    ella (M05; con Plaid o un QFX a media semana) y el motivo automático de
    rehacer una transferencia (M10); y tres menores (M04, M06, M08). Lo de
    mientras, en §0 («Lo que encontró la prueba final de la 4d»).
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
