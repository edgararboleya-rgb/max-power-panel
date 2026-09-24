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
| `c3-volumen.sh` | Lo que pasa con MUCHOS papeles: 3.000 recibos en el libro (un año largo de la cuadrilla) y la app pidiendo «reintentar puente» (`fn_puentes_correr`) y los controles (`fn_puentes_verificar`) como `authenticated`, con el tope de la API de Supabase (`statement_timeout` de 8 s): terminan, y lo que no cambió no se vuelve a planear. Imprime cuánto tardó cada cosa. `./c3-volumen.sh [bd] [recibos]`. |
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
| 1 | `docs/conta/c1-plan-de-cuentas.sql` | Una tabla con el plan de cuentas: **85 filas** (`codigo`, `nombre`, `tipo`, `saldo`, `imputable`, `activa`, `obra`, `cost_code`, `etiqueta_fiscal`), de la 1000 a la 9000. |
| 2 | `docs/conta/c2-libro.sql` | Los **10 controles** del libro (`fn_verificar_cadena`), **todos con `ok = true`**: `hash`, `enlace`, `numeracion`, `contadores`, `cuadre`, `reversos`, `periodos`, `triggers`, `cuentas` (dice `"cuentas": 85`) y `permisos`. Uno en `false` = parar y avisar. |
| 3 | `docs/conta/c3-puentes.sql` | **23 filas**: los 10 `libro · …` y 13 `puentes · …`. Todas en `true` **salvo `puentes · sin_evaluar`**, que la primera vez sale en `false` con la lista de papeles que el puente todavía no miró y `"arreglo": "select fn_puentes_correr();"`. Es lo esperado. `puentes · reglas` sale en `true` y dice cuántas reglas siguen en borrador (`en_borrador`): esas no postean hasta que Edgar las confirme. `puentes · papel` en producción sí mira Storage (en el banco dice «no aplica»). |
| 4 | Una línea: `select fn_puentes_correr();` | Un solo valor (jsonb) con `"desde": "2026-10-01"`, cuántos papeles quedaron en cada estado (`contabilizado`, `pendiente`, `espera`, `no_aplica`…) y **`"errores": 0`**. |
| 5 | Una línea: `select * from fn_puentes_verificar();` | Los **13 controles** de los puentes, **todos en `true`** (ahora también `sin_evaluar`). `bandeja` dice cuántos papeles esperan a Edgar; solo se pone en rojo si el libro rechazó alguno. |
| 6 | `docs/conta/c2-pruebas.sql` | La tabla `_pruebas`: **78 filas**, todas con `ok = true`. |
| 7 | `docs/conta/c3-pruebas.sql` | La tabla `_pruebas`: **112 filas**, todas con `ok = true` salvo la **45**, que en producción sale «omitida» (Supabase no deja borrar de Storage por SQL; se prueba en el banco). Si no hay ningún perfil activo que no sea el dueño, las pruebas «del equipo» salen con `ok` vacío (`null`) y `obtenido` = «omitida…»: no es un fallo. |

- **El orden importa**: c2 necesita c1; c3 necesita c1 y c2. Las pruebas
  (6 y 7) van siempre después de los tres.
- **Las pruebas no dejan rastro**: cada ataque se hace dentro de una
  subtransacción que se deshace a sí misma. No escriben asientos, líneas,
  contadores, cobros, aprobaciones, bandeja ni secuencias (usan ids
  negativos); lo único que queda es la tabla temporal `_pruebas` y unas
  funciones `pg_temp.*` de ayuda, que mueren al cerrarse la sesión del
  editor. Tardan unos segundos (en el banco: c2 ≈ 1 s, c3 ≈ 3 s). Mejor
  correrlas cuando nadie esté subiendo recibos: por un instante bloquean
  la tabla `periodos`.
- **Si el editor no acepta un archivo tan grande** (`c3-puentes.sql` pesa
  ≈ 466 KB): se puede pegar en dos partes, desde el principio hasta la línea
  `-- ==== BLOQUE B ====` (sin ella), Run, y desde esa línea hasta el
  final, Run. Lo mismo `c2-libro.sql`. En el banco se prueban así con
  `archivo.sql:A` y `archivo.sql:B`.
- **Re-correr la suite en producción** (después de cualquier cambio, o
  cuando se quiera comprobar): pegar otra vez `c2-pruebas.sql` y luego
  `c3-pruebas.sql` (pasos 6 y 7), cada una en su pestaña. Y para ver el
  estado del libro sin tocar nada: `select * from fn_verificar_cadena();` y
  `select * from fn_puentes_verificar();`.

## 0b. La prueba final en el banco, de cero

Lo mismo que el paso 1–7 de arriba, sin tocar producción. Tarda segundos:

```bash
cd /home/user/max-power-panel/pruebas/conta
D=../../docs/conta

# De cero: las tres entregas y las dos suites (sin Storage: 45 y 90 salen
# «omitida»; con 03-storage-simulacro.sql delante salen en verde).
./correr.sh final_mia $D/c1-plan-de-cuentas.sql $D/c2-libro.sql $D/c3-puentes.sql \
                      $D/c2-pruebas.sql $D/c3-pruebas.sql
#   → PRUEBAS total=78 ok=78 fallan=0 omitidas=0
#   → PRUEBAS total=112 ok=110 fallan=0 omitidas=2

# Idempotencia: sobre la MISMA base, volver a pegar c1, c2 y c3 (dos veces)
# y las pruebas otra vez; tiene que seguir todo en verde.
for i in 1 2; do for f in c1-plan-de-cuentas c2-libro c3-puentes; do
  PGPASSWORD=editor_sql psql -X -q -h 127.0.0.1 -U editor_sql -d final_mia \
    -v ON_ERROR_STOP=1 -1 -o /dev/null -f $D/$f.sql || echo "FALLÓ $f"
done; done

# Varias sesiones, volver a pegar con reglas tocadas, y volumen:
./c2-pegado.sh final_c2p; ./c3-pegado.sh final_c3p
./c2-concurrencia.sh final_c2c; ./c3-concurrencia.sh final_c3c
./c3-volumen.sh final_c3v 3000

./correr.sh --borrar final_mia
```

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
  todo: c2-pruebas 78/78, c3-pruebas 112/112 (con Storage), pegado,
  concurrencia y volumen, en verde en 16 y en 17.
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
