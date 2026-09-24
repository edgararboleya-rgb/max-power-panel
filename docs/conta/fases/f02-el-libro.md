# Fase 2 · El libro
**28 sep – 4 oct · 🔵 AZUL los invariantes · 🟢 VERDE las pruebas · ▶ pegar el SQL**

> Los invariantes. Si esto queda bien, ningún libro se corrompe después; si
> queda mal, no hay pantalla que lo salve. **Todo lo de abajo tiene que entrar
> en la semana 2: sobre un libro inmutable no se puede meter después.**

## Tú
Pegar `c2-libro.sql` y luego `c2-pruebas.sql`, y confirmar que corrieron.
Decidir la regla de fecha del reverso.

## 🔵 Azul — se crea (`/effort max`)

- `asientos`, `asiento_lineas`, `periodos`, `contadores`. (`cuentas` viene con
  su DDL de f01; aquí: código inmutable, no se borra con movimientos, se
  inactiva.)
- `asiento_lineas` con `proyecto_id`, `cost_code` (FK a `cost_codes`), `co`
  text copiado tal cual del origen (la FK a `alcances` llega en f10), `fase`
  opcional, y `monto numeric(14,2) not null check (monto <> 0)`.
- **`fn_postear(lineas jsonb)`**: una transacción; lee cada monto con
  `(l->>'monto')::numeric` y rechaza si `scale(...) > 2` (MX005); rechaza
  debe ≠ haber (MX001); asigna `asientos.numero` desde `contadores (serie,
  ultimo)` con `select … for update` **después** de validar, por año
  (`2027-000001`, único); exige `proyecto_id` y `cost_code` en 5xxx,
  `proyecto_id` en 4xxx y nulo en 6xxx (MX006); `es_dueno()` para los caminos
  `mano` e `IA aprobada`; el camino `puente` corre por trigger/cron SECURITY
  DEFINER con `set search_path = public`, sin `auth.uid()`, y lo deja escrito
  en la procedencia; calcula `asientos.hash = sha256(hash_anterior || numero
  || fecha || líneas ordenadas)` bajo advisory lock; `fn_verificar_cadena()`.
- **Inmutabilidad en TRIGGERS, no en policies.** `before update or delete` en
  `asiento_lineas` **y en `asientos`** (`raise exception … errcode 'MX003'`);
  la cabecera no admite ninguna excepción. Más
  `revoke update, delete, truncate on asientos, asiento_lineas from anon,
  authenticated, service_role`. *Una policy no frena a `postgres` desde el SQL
  Editor ni a `fn_postear`; un trigger sí.*
- **Bloqueo de período** como `before insert` en `asientos` que consulta
  `periodos.estado` (MX002): frena también a `fn_postear`, al service role y a
  Edgar. `periodos` lleva `paralelo boolean` (octubre–diciembre 2026) y el año
  es un período propio.
- **Quién lee** — bloque fijo por tabla, obligatorio en todo `docs/conta/c*.sql`:
  ```sql
  alter table X enable row level security;
  revoke all on X from anon;
  create policy X_dueno on X for select using (es_dueno());
  ```
  Sin policy de insert/update/delete para `authenticated`: todo entra por
  `fn_postear`. Vistas con `security_invoker = true`. Se reutiliza la
  `es_dueno()` que ya existe, no se inventa otro candado. Rol `contador` de
  solo lectura para el CPA: ▶ decisión de Edgar, opcional.
- **Reverso**: `asientos.reversa_a uuid references asientos unique`,
  `motivo text not null` cuando `reversa_a` no es nulo; **un asiento con
  `reversa_a` no se reversa**; `fn_reversar` es la única vía y genera las
  líneas espejo desde la base; fecha del reverso = `greatest(fecha_original,
  inicio del período abierto más antiguo)` (▶ Edgar confirma la regla).
  `asientos.reversible boolean`: si es `true`, `fn_postear` genera y postea el
  reverso fechado el día 1 del mes siguiente en la misma transacción, con
  `camino = 'reverso automático'`.
- **Procedencia** con el sello del punto 3 del plan, y `asientos.propuesta_id`
  reservado (nulo salvo `origen='ia'`; la FK a `ia_propuestas` se añade en f07).
- **Fecha**: `fn_fecha_miami(t timestamptz) returns date stable` =
  `(t at time zone 'America/New_York')::date` — Miami no tiene zona propia y
  `'EST'` no cambia con el verano. `asientos.fecha_contable date not null
  default fn_fecha_miami(now())`; los puentes la calculan en SQL; `conta.js`
  la manda como texto `YYYY-MM-DD` solo en asientos manuales.
- **Errores con nombre**: SQLSTATE `MX001` descuadre · `MX002` período cerrado
  · `MX003` inmutable · `MX004` cuenta inactiva · `MX005` escala · `MX006`
  dimensión. `conta.js` los traduce mirando `e.codigo` **antes** de que
  `enCristiano` los pise (un 23514 hoy le diría a Edgar «pega un SQL»).
  `fn_estado(periodo)` devuelve `filas`, `total_debe`, `total_haber`, `cuadra`
  como fila de control.
- **Cómo habla `conta.js` con la base** (decidido aquí, implementado en f05):
  tres líneas al final de `MXP_DB` — `_api: api`, `_leer: leer`,
  `_rpc: (fn, cuerpo) => api("rpc/" + fn, { metodo: "POST", cuerpo })` —
  anotadas en `PUBLICAR.md` como parche de la sesión de contabilidad.

## 🟢 Verde — se trabaja encima (`/effort auto`)

Las pruebas van en **`docs/conta/c2-pruebas.sql`**, que Edgar pega después de
`c2-libro.sql`: son invariantes de Postgres con roles reales, y Playwright
«sin tocar la nube» solo probaría un simulacro.

Un bloque `do $$ … exception when sqlstate 'MX001' then … end $$` por ataque,
fijando `request.jwt.claims` con `set_config(…, true)` y `set local role
authenticated` con el uid de un perfil de equipo y con el de Edgar; resultados
en una tabla temporal y el `select` final como última sentencia (el SQL Editor
no muestra `raise notice`); lo que escribe de verdad va en transacción con
`rollback` antes del `select`.

**Los nueve ataques:** descuadre por un centavo · mes cerrado desde
`fn_postear` **y desde `postgres`** · `update` a líneas y a la cabecera
(cambiar la fecha a un mes cerrado) · `delete` · `set local timezone = 'UTC'` y
`fn_fecha_miami('2026-12-31 19:00-05')` = `2026-12-31` · token de equipo lee 0
filas de `asientos` y `fn_postear` falla · reversar dos veces → rechazado ·
reversar un reverso → rechazado · reverso en período cerrado cae en el abierto
· bueno, descuadrado, bueno → números 1 y 2 sin hueco · monto con tres
decimales → MX005.

**Rojo primero:** `c2-libro.sql` va en dos bloques (tablas; luego invariantes)
y el script corre entre los dos y debe fallar **por el código esperado**, no
por «relation does not exist».

`pruebas/conta-libro.js` queda solo para lo puro del navegador (traducción de
MX00x, formato de montos).

## Entregable
`docs/conta/c2-libro.sql` · `docs/conta/c2-pruebas.sql` · `pruebas/conta-libro.js`

## Terminó cuando
Las pruebas de `c2-pruebas.sql` pasan en rojo primero y en verde después,
pegadas por Edgar en Supabase. Un asiento descuadrado no entra, **un trabajador
no lee una línea**, y lo demuestras.

## Desbloquea
Todo lo demás.

## Lo construido (24-sep) — versión candidata, sin pegar
- `docs/conta/c2-libro.sql` (A: tablas y mínimas para el rojo; B: controles) y
  `docs/conta/c2-pruebas.sql` (**78 pruebas**, no dejan rastro). No hizo falta
  `pruebas/conta-libro.js`: las pruebas son SQL y corren en el SQL Editor.
- Tres rondas de ataque con cuatro lentes (invariantes, seguridad, contable,
  operación): 27, 14 y 11 hallazgos, cada uno reproducido en base limpia y
  corregido con su prueba.
- `fn_verificar_cadena()`: 10 controles (hash, enlace, numeración, contadores,
  cuadre, reversos, períodos, triggers, cuentas, permisos).
- Banco de pruebas en `pruebas/conta/` (imita Supabase: roles, RLS, privilegios
  por defecto, SQL Editor en una transacción). Verde en Postgres 16 y en
  **17.6**, la versión de producción (`pg17.sh`).
- Orden de pegado y qué debe verse: `pruebas/conta/README.md` §0.
