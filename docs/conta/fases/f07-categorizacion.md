# Fase 7 · Categorización y la bandeja
**26 oct – 1 nov · 🔵 AZUL el motor, la bandeja y el esqueleto de `contador` · 🟢 VERDE la pantalla y el cliente · ▶ reglas para el viernes 23-oct; despliegas `contador`**

> Es el «Banking» de QuickBooks, hecho a tu medida. Y es donde nace la IA
> contable: aquí se implementa **propone y nunca postea**.

## Tú
1. Dictar las reglas que ya tienes en la cabeza, **para el viernes 23-oct**:
   este proveedor siempre va a esta cuenta, este rango de monto es esto otro.
2. Categorizar un mes real a mano para que agarre patrón.
3. ▶ **Una semana antes:** `supabase functions deploy contador`, con una llave
   **NUEVA** de Anthropic como secreto (separa el gasto contable del del
   estimador). El `effort`, el caché y el sello viven en esa función, no en el
   navegador.

## 🔵 Azul — se crea (`/effort max`)

- **El motor de reglas determinista**, con reglas que **parten un movimiento en
  varias líneas** (la cuota del vehículo: Dr 2520 + Dr 7100 / Cr 1010, con la
  función de f06).
- **La bandeja.** `contador_propuestas` (`id, accion, modelo, effort, prompt_version`
  —hash del texto del prompt que la función calcula al arrancar—, `entrada`
  jsonb con solo lo variable congelado + `prefijo_hash`/`reglas_version`,
  `salida` cruda, `estado` pendiente|aprobada|editada|rechazada,
  `aprobado_por, aprobado_el, asiento_id, lote_id`) e `contador_lotes` (`usage`,
  centavos, modelo, effort por petición). **La función inserta la fila ANTES de
  devolver la sugerencia**: si no se pudo guardar, no se muestra. `fn_aprobar`
  postea vía `fn_postear` y añade la FK `asientos.propuesta_id`.
- **El esqueleto de `supabase/functions/contador/index.ts`**: valida el JWT,
  comprueba `es_dueno()` por RPC **antes de gastar un token**, registra `usage`
  en `asistente_costo_mes` con `accion='contador_*'`, devuelve `prompt_version`
  y `usage` en cada respuesta.
- **Tres reglas fijas de S-corp que la IA no reinterpreta:** (a) todo pago al
  IRS por el impuesto sobre la renta de Edgar → **3200** (no incluye al DOR:
  sales tax y RT-6 sí son de la empresa); (b) todo cargo marcado personal →
  3200, o 1130 si lo devuelve; (c) el sueldo de Edgar solo entra por nómina
  (6000), nunca como transferencia.
- **Regla de capitalización:** compra ≥ $2.500 por unidad y vida > 1 año →
  propone alta en 15xx, Edgar aprueba.
- **Criterio de use tax:** compra sin impuesto visible → propone Dr 5100 /
  Cr 2300 por el 7,5 %, respetando el tope del surtax que `e13b` ya advierte.

## 🟢 Verde — se trabaja encima (`/effort auto`)
La pantalla, el editor de reglas, y el cliente en `conta.js` (copiando el
manejo de 401 y «Sin señal» de `pedirAlCerebro`, contra
`/functions/v1/contador`). Las llamadas a `claude-opus-5-5` con
`output_config: {effort: "low"}` **en ráfaga al abrir la bandeja** — esperando
la primera respuesta antes de disparar el resto, para que el caché exista. El
prefijo (plan de cuentas + reglas, ordenado y sin fechas) con `cache_control`,
y la comprobación de `cache_creation_input_tokens` /
`cache_read_input_tokens` guardada por lote. `stop_reason: "refusal"` —que
también ocurre en Opus— se trata como «sin respuesta»: **nunca un fallback a
otro modelo**. **Sin Batches en la v1.** Y el flag `impuesto_pagado`
(sí/no/desconocido) en `recibos`, leído en la lectura del recibo que ya existe.

## Entregable
`docs/conta/c7-reglas.sql` · `supabase/functions/contador/index.ts` · la pantalla

## Terminó cuando
Un mes de movimientos queda categorizado con menos de diez correcciones tuyas;
cada sugerencia que aceptaste dejó su sello en el asiento; y **abres un asiento
de origen IA y ves qué vio, qué contestó tal cual y con qué versión del prompt**.

## Lo construido (31-oct)

Pedido de Edgar: «como en QuickBooks: ellos me dan lo que creen que es cada
gasto; quiero al lado la clasificación según la IA y la clasificación según
yo, con la opción de decir *lo mismo que la IA*». Hecho con agentes en Fable
(la base, la función y la verificación desde cero, con esfuerzo máximo) y en
Opus 5.5 (la pantalla y la prueba de punta a punta), reparto acordado con
Edgar el 31-oct.

**Lo que cambió respecto a este documento.** El archivo se llama
`docs/conta/c8-contador.sql` (c7 ya era Plaid). Las reglas no las dicta Edgar
en una lista: **la app las aprende al aprobar** (cada «Así es» o «Clasificar»
con «Recordar para este comercio» marcado crea o actualiza la regla del
comercio: nombre limpio de números y ciudades —`THE HOME DEPOT 6341 OCALA FL`
→ `THE HOME DEPOT`—, patrón `^…` sobre `desc_norm`, las cuentas; nunca la
obra, que se pregunta cada vez cuando la cuenta la pide). Las reglas también
se pueden dar de alta a mano (`fn_contador_regla_alta`) y quitar desde
Conexiones y seguridad. El flag `impuesto_pagado` en `recibos` no entró en la
v1: el use tax queda como **aviso** («¿Use tax?») en la propuesta, y Edgar
decide; nada se postea automático.

**La base (`c8-contador.sql`, 2.400 líneas; `c8-pruebas.sql`, 25 pruebas).**
Las tablas se llaman `contador_*` y no `ia_*`: producción ya tenía una
`ia_propuestas` de la revisión diaria del cerebro de Planos, con otras
columnas, y el primer pegado chocó con ella (31-oct) sin dejar nada.
Cuatro tablas con RLS y una sola policy de lectura del dueño (`contador_config`,
`contador_reglas`, `contador_lotes`, `contador_propuestas`), 32 funciones `fn_contador_*`
(ninguna SECURITY DEFINER, ninguna ejecutable por la API: todo entra por la
función de borde como `postgres`) y las vistas `v_contador_estado`,
`v_contador_bandeja`, `v_contador_reglas`, `v_contador_cuentas` y
`v_contador_control` (cuadres 60–63 y alarmas 70–73). **El único camino al
libro es `fn_contador_clasificar`**, que llama a `fn_banco_clasificar` de c6
en nombre del dueño con el motivo «Propuesta de la IA #… aprobada por Edgar:
…» o «Clasificado por Edgar desde la bandeja (fase 7)»: la propuesta queda
`aprobada` si las líneas coinciden, `editada` si no, y guarda `asiento_id`,
`lineas_finales` y quién y cuándo. Las reglas fijas de la S-corp (IRS → 3200;
personal → 3200 o 1130; el sueldo de Edgar solo por nómina, la 6000 nunca se
propone), la capitalización (≥ $2.500 → «¿Activo fijo?») y el use tax van en
el prefijo que la IA recibe y como flags que la base valida. El gasto se anota
en `asistente_uso` (la tabla real de la app; `asistente_costo_mes` es su
vista) con `accion = 'contador_categorizar'`, en centavos:
`round((entrada×400 + caché escrita×500 + caché leída×20 + salida×2000) /
1.000.000)`. Dos topes: el propio de la IA contable (`contador_config.tope_mes_centavos`,
$30 al mes) y el global de la app (`asistente_ajustes.tope_mes_centavos`);
con cualquiera de los dos alcanzado, «Proponer» no gasta.

**La función (`supabase/functions/contador/index.ts`, un archivo).** El
esqueleto de `stripe/`: entra a la base como `postgres`, exige la sesión del
dueño en aal2 (salvo `?paso=salud`), nunca devuelve llaves. Acciones:
`salud`, `estado`, `proponer`, `aprobar`, `clasificar`, `rechazar`,
`caducar`, `regla_alta`, `regla_baja`. **Una sola ráfaga a la vez** (dos
pestañas → la segunda recibe «Ya hay una ráfaga en marcha… espera»; una
abierta hace más de 5 minutos se da por perdida y se cierra con su error); la
ráfaga tiene reloj (lo que no entra a tiempo se queda para la siguiente, sin
cortar la función ni poner la alarma en rojo). `proponer`: primero las reglas (sin IA), luego el
tope, luego la ráfaga a `claude-opus-5-5` con `output_config: {effort: "low",
format: json_schema}`, el prefijo (instrucciones + plan permitido + obras +
reglas + 30 ejemplos aprobados, ordenado y sin fechas) con `cache_control`,
**la primera llamada sola** para que el caché exista y después tres a la vez;
`max_tokens` 4096 (el pensamiento adaptativo cuenta contra el tope aunque no
se devuelva). `stop_reason: "refusal"` o un JSON que no vale → «sin
respuesta», se cuenta y no se guarda; **nunca otro modelo**. Cada propuesta
se guarda ANTES de enseñarse, con la entrada congelada (el movimiento, las
obras, la versión de las reglas, el hash del prefijo, la versión del prompt),
la salida cruda y el `usage`; el lote cierra con los tokens de caché creada y
leída. Lo que va a la IA no lleva correos (tampoco en la forma «JPEREZ MAIL COM» que
deja la normalización de c6), teléfonos ni números de cuenta; los hashes del
sello (versión del prompt, del prefijo y de las reglas) sí van íntegros.
Lo que la IA no contesta (rechazo, JSON roto, corte) se cuenta y vuelve a
intentarse en la ráfaga siguiente: acotado por el tope y por el botón.

**La pantalla (`js/conta.js`, `css/conta.css`).** En la Bandeja, una franja
«IA»: *n propuestas listas · m por proponer · este mes $x de $y* y «Proponer
con la IA (m)» (apagado sin el código del teléfono, con el tope o sin llave,
y dice por qué). En cada fila un chip: «IA · 5100 Material · 92 %», «Regla ·
WAWA» o «sin propuesta». Desplegada, dos columnas: **Según la IA** (líneas,
motivo en una frase, confianza, avisos «Pide obra» / «¿Activo fijo?» / «¿Use
tax?» / «Personal» / «IRS», quién propuso, el selector de obra si la cuenta la
pide, «✓ Así es» y «No es eso») y **Según yo** (buscador y selector de
cuenta por tipo, obra —obligatoria, opcional o prohibida según la cuenta—,
motivo, «Recordar para este comercio», «Clasificar», que dice «igual que la
IA» cuando coincide). En Conexiones y seguridad, la tarjeta «IA contable»:
llave, modelo, gasto del mes contra los dos topes, última ráfaga, las reglas
con «Quitar». Si c8 no está pegado, la bandeja sigue como antes.

**Pruebas.** `c8-pruebas.sql` 25/25 y las suites c2, c3, c6 y p1 en verde
con c8 puesto; `pruebas/conta/contador-e2e.mjs` (109 comprobaciones, con la
IA simulada de `contador-simulado.mjs`, en Node y en Deno, desde cero y sobre
una base hecha); `pruebas/conta/pantalla.js` 294 comprobaciones y capturas a
390, 820 y 1280; `e0` y `e13`. Una verificación desde cero (Fable) encima de
todo, y los arreglos que pidió.

**Cómo se instala** (la cabecera de `c8-contador.sql` lo trae): 1 pegar
`c8-contador.sql` (tabla final con «0 cuadres rojos»); 2 pegar
`c8-pruebas.sql` (25 en `true`); 3 llave NUEVA de Anthropic en Supabase →
Edge Functions → Secrets → `ANTHROPIC_API_KEY`; 4 la función `contador`
(Verify JWT apagado) y `…/contador?paso=salud`; 5 publicar la app y, en la
Bandeja, «Proponer con la IA». Para apagarla: `update contador_config set activa =
false where id = 1`. Recién pegado, la alarma 73 («la llave y la función»)
sale en rojo hasta la primera ráfaga: es la esperada.
