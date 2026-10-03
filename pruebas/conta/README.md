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
| 5 | `docs/conta/c6-banco.sql` | **7 filas, todas en `true`**: cuatro `c6 · …` —`tablas` («13 tablas, con la RLS encendida y solo su policy de lectura del dueño»), `vistas` («8 vistas, todas security_invoker, solo SELECT para authenticated»), `funciones de la app` («21 funciones que llama conta.js (anon ninguna); el resto, sin grant a la API») y `en el reparto de c2`— y tres del control del banco a hoy: `banco · v_banco_saldos` («N filas»: una por banco y tarjeta), `banco · cuadre: protecciones del banco` y `banco · cuadre: c2, c3 y c4 al día` (las dos, «bien»). Una en `false` = parar y avisar. Si sale **MX000** («c6-banco NO se aplicó, no se tocó nada…»): falta c2, c3 o c4, o alguno es de antes de esta entrega (c2 o c4 con su marca por debajo de 2026100201, c3 por debajo de 2026092601), y dice cuál volver a pegar; o las huellas del libro no son las del último pegado (el control `triggers` de c2 en rojo); o `es_dueno()` cambió desde que se pegó c2 (el candado que dice quién ve los libros y el banco: el control `permisos` en rojo): se mira eso antes, y si el cambio es bueno se vuelve a pegar c2 y después c6. Si sale **55P03** («lock timeout»): la pantalla del banco estaba leyendo; no se pegó nada: ciérrala y vuelve a pegarlo. |
| 6 | Una línea: `select fn_puentes_correr();` | Un solo valor (jsonb) con `"desde": "2026-10-01"`, cuántos papeles quedaron en cada estado (`contabilizado`, `pendiente`, `espera`, `no_aplica`…) y **`"errores": 0`**. |
| 7 | Una línea: `select * from fn_puentes_verificar();` | Los **13 controles** de los puentes, **todos en `true`** (ahora también `sin_evaluar`). `bandeja` dice cuántos papeles esperan a Edgar; solo se pone en rojo si el libro rechazó alguno. |
| 8 | `docs/conta/c2-pruebas.sql` | La tabla `_pruebas`: **83 filas**, todas con `ok = true` (también quedan en `pruebas.c2_resultado`). (La **83**, de la ronda 4 de c6, mide con una función de prueba de unos 4 MB que el control «permisos» ya no relee lo que c4 y c6 sellaron: unos segundos más; sin c6 sale «omitida».) (Con la apertura de verdad ya en el libro, la **61** sale «omitida»; y en cuanto se **cierre el período de la apertura** (`2026-09-APERTURA`, antes que octubre), también la **37** y la **48**, que prueban lo de la apertura abierta. No es un fallo.) |
| 9 | `docs/conta/c3-pruebas.sql` | La tabla `_pruebas`: **120 filas** (también en `pruebas.c3_resultado`), todas con `ok = true` salvo la **45**, que en producción sale «omitida» (Supabase no deja borrar de Storage por SQL; se prueba en el banco). Con la apertura de verdad ya en el libro, la **115** y la **117** (las que postean una apertura de prueba) también salen «omitida»: no es un fallo. Si no hay ningún perfil activo que no sea el dueño, las pruebas «del equipo» salen con `ok` vacío (`null`) y `obtenido` = «omitida…»: no es un fallo. Las seis del devengo (**28, 57, 67, 74, 77 y 99**) devengan en el primer mes abierto **sin journal de nómina**: con la nómina de octubre a diciembre ya en el libro (paso 3 de «Después de c6») corren en el primero que no lo tenga; si todos los meses abiertos ya lo tienen, salen «omitida» y lo dicen (con journal, el devengo estándar se niega: MX008, la regla de c3); y también si ese mes pasa del tope de fecha de c2 (con la nómina semanal, el mes en curso con su primer journal y el anterior todavía abierto: el mes del devengo sería el de después, y no se puede postear todavía), con la **120** diciendo el tope. No es un fallo. |
| 10 | `docs/conta/c4-pruebas.sql` | La tabla `_pruebas`: **113 filas**, todas con `ok = true` (la **112** y la **113** son las de la ronda 4 de c6: el tope por reloj del control y lo que c6 selló; corren sin el tope por reloj, `c4.control_tope = 0` al empezar, y se devuelve al final). **Córrelas recién pegado c4 y ANTES de postear la apertura de verdad**: con ella ya en el libro, las **29 a 36, 50, 51, 53, 56, 61, 62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107** (las que postean una apertura de prueba) salen «omitida», y no es un fallo. Sin nadie del equipo activo, la **2** y la **38** salen «omitida»; la 38, 55, 56, 57, 58, 64, 77, 79, 80, 82, 89, 101, 103, 109, 111 y 113 también si la app estaba usando justo lo que tocan (esperan 2 s y se saltan), y la **113** sin c6. La **109** (el privilegio MAINTAIN) es de Postgres 17: en producción corre; en el banco con 16 sale «omitida». La **88** en rojo = el JIT sigue encendido para la app (ver el paso 4). La **45** finge «hoy» a mitad de mes (el reloj fingido solo va hacia adelante): corre en el primer mes abierto cuyo día 15 no ha pasado, y sale «omitida» solo si no hay ninguno (antes salía «omitida» del día 16 hasta cerrar el primer mes abierto). Con el banco de c6 ya en uso (asientos del banco en el mes, la caja chica fondeada con un retiro, la nómina de octubre, un ticket de la segunda obra con la apertura todavía sin postear) siguen en verde: la **17** cuenta la caja chica en el efectivo final, la **26** y la **53** miran solo lo de su escenario y la **39** le da fondos al banco antes de medir. Tardan entre 50 s y 80 s en el banco (27-sep; el 25-sep, 40 s; el 3-oct, con las 113, 35 s en 16 y 38 s en 17.6: la máquina del banco varía); **en producción (instancia chica) 5 min 47 s, y el SQL Editor se cansa antes y enseña un error de red: la corrida sigue en el servidor hasta el final.** Espera unos 6 minutos y lee el resultado con `select * from pruebas.c4_resultado order by n;` (la misma tabla, con la hora de la corrida). |
| 11 | `docs/conta/c6-pruebas.sql` | La tabla `_pruebas`: **134 filas** (la 101 a la 134 son las de la ronda 4: de la 101 a la 117, el casado y la bandeja; de la 118 a la 128, la entrada —el importador y los lotes— y la seguridad; de la 129 a la 133, la apertura y el primer mes; la 134, el tiempo en producción), todas con `ok = true` (también quedan en `pruebas.c6_resultado`, con la hora de la corrida). Usa cuentas de prueba propias (el banco 1098, la reserva 1097 y dos tarjetas ····9996 y ····9995) que se deshacen con cada prueba: ni tus movimientos ni tu apertura se cruzan con ellas, y con el banco ya en uso (lo casado y lo clasificado de verdad, la caja chica fondeada desde el banco, la póliza de QuickBooks con su `saldo_corte`) sigue en verde: cada prueba mide lo que hace su escenario. Pueden salir «omitida» (y no es un fallo): la **10** sin dos días del mes sin visitas en el calendario (o sin `eventos` o sin una segunda obra), y la **96** sin tres días seguidos sin visitas; la **22**, la **46** y la **88** cuando octubre ya está cerrado (prueban la amortización del primer mes) **o cuando ya amortizaste un mes posterior con octubre abierto** (la marcha en paralelo: amortizar octubre entonces se niega, MX008, y es la regla), y la **64**, la **92** y la **99** también (prueban la primera semana y el primer mes después del corte); la **30**, la **63**, la **64**, la **92**, la **99**, la **107**, la **109**, la **110**, la **116** y la **120** si el período de la apertura está cerrado sin asiento de apertura; la **107**, la **109**, la **110** y la **116** cuando el mes abierto más antiguo ya no es el primero después del corte (como la 99), y la **109** también **en cuanto la apertura de verdad esté posteada** (prueba lo de antes de conciliarla, con una apertura de prueba que lleva el banco 1098); la **129** y la **130** (los Undeposited Funds y los préstamos contra la apertura: postean una apertura de prueba con `fn_apertura`) en cuanto la apertura de verdad esté posteada o con la apertura cerrada; la **34** sin nadie del equipo activo; la **47**, la **88**, la **89**, la **95**, la **99**, la **101** y la **133** sin el mes siguiente abierto; la **72** y la **91** sin la tabla `horas`; la **36**, la **37**, la **47**, la **48**, la **67**, la **71**, la **72**, la **73**, la **91**, la **97**, la **118**, la **121**, la **126**, la **131** y la **133** si la app estaba usando lo que tocan (esperan 2 s y se saltan). La **61** (va la última) comprueba que nada quedó. Tardan unos 20 s en el banco (19 s en 16.13 y 20 s en 17.6 el 3-oct, con las 134 —con las 128, 17 s y 18 s—; con el año de Edgar encima —`c6-volumen.sh` con 200 por mes y 2.500 movimientos—, 26 s; con un año de banco encima —666 por mes y 9.990 movimientos—, 32 s en 16 y 38 s en 17.6 el 3-oct, después de lo fijo de cada «Casar» del grupo 4 —antes, de 39 a 42 s según la corrida—; el 2-oct, con 117, 35 s; el 27-sep, con 100, 32 s y 38 s; en producción, calcula tres o cuatro minutos: c4-pruebas tarda allí diez veces lo del banco); si el SQL Editor se cansa, `select * from pruebas.c6_resultado order by n;`. |

- **Esta entrega (la ronda 4 de c6, 3-oct): vuelve a pegar c2 (paso 2) y
  c4 (paso 4), en ese orden, ANTES de c6 (paso 5); c1 y c3 no cambian.**
  c2 y c4 traen su marca nueva (2026100201) y lo del tiempo en producción
  (abajo, «La ronda 4 de c6, grupo 4»): el control de cada pantalla de
  cifras con un tope por reloj (lo que no cabe sale «Sigue» y conta.js lo
  vuelve a pedir) y sin releer en cada pantalla lo que c6 sella. No tocan
  el libro ni lo que Edgar configuró; c2 enseña sus 10 controles en
  `true` y c4 sus 9 filas, como siempre. c6 pegado sin ellos para con
  MX000 y dice qué volver a pegar (c2-libro.sql y c4-estados.sql), sin
  tocar nada. Después, las cuatro suites (pasos 8 a 11), cada una sola:
  83, 120, 113 y 134 filas.
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
- **c2, c3 y c4 ya están pegados en producción: vuelve a pegarlos (pasos 2,
  3 y 4) antes de c6.** Traen, cada uno, un cambio pequeño para el banco
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
  `archivo.sql:A` y `archivo.sql:B`. `c4-estados.sql` (≈ 650 KB) y
  `c6-banco.sql` (≈ 1 MB con la ronda 4; la de producción, 2026092704,
  ≈ 770 KB, ya entró así) van enteros: cada uno es una transacción, y
  su primera sentencia (el lock_timeout) vale para todo el pegado.
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
   diferencia a capital o a interés); el ticket repartido entre obras que
   llega después de clasificar, «Es su ticket (repartido)». El dinero a o
   desde la cuenta personal de Edgar (el banco nombra «CHK ...7781») sale
   como distribución o préstamo del accionista; una transferencia a una
   cuenta propia, ahí, pide su motivo. Mientras la apertura de un banco no
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
   al fin de cada mes ya terminado y sin cerrar; un cuadre suelto, por su
   nombre:
   `fn_banco_control('hoy', array['cuadre: prepagados'])`) y, de vez en
   cuando, `select * from fn_banco_verificar();` (relee cada archivo fila
   por fila y recalcula las conciliaciones confirmadas en las que algo pudo
   cambiar; de una cuenta: `fn_banco_verificar(array['1010'])`).

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

**Qué se pega**: solo `c6-banco.sql` (paso 5) y después `c6-pruebas.sql`
(paso 11). c2, c3 y c4 no cambian (siguen sus marcas: c2 2026092701, c3 y
c4 2026092601): no hay que volver a pegarlos ni correr sus suites por esto.
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

**Qué se pega**: lo mismo que el grupo 1 (es la misma entrega y la misma
marca, **2026100201**): solo `c6-banco.sql` (paso 5) y después
`c6-pruebas.sql` (paso 11); c2, c3 y c4 no cambian. c6-pruebas, **128
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

**Qué se pega**: lo mismo que los grupos 1 y 2 (es la misma entrega y la
misma marca, **2026100201**): `c6-banco.sql` (paso 5; enseña sus **7 filas
en `true`**, las de siempre) y después `c6-pruebas.sql` (paso 11): **133
filas en verde**, con las «omitidas» de la lista del paso 11. c2, c3 y c4
no cambian (no se vuelven a pegar). De las pruebas cambió también
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
#   → PRUEBAS total=134 ok=134 fallan=0 omitidas=0

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
# dos veces (en la ronda 4 cambian c2 y c4, grupo 4; c1 y c3 no); las
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
c6 con la 109, la 129 y la 130 «omitidas» (postean una apertura de
prueba; su prueba 30 usa entonces la apertura de verdad), nada en
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
