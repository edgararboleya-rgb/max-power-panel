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
Edge Functions → Secrets → `ANTHROPIC_API_KEY_CONTADOR` (si no existe, la función usa la
`ANTHROPIC_API_KEY` que ya tiene la app; el gasto se separa igual en
`asistente_uso`); 4 la función `contador`
(Verify JWT apagado) y `…/contador?paso=salud`; 5 publicar la app y, en la
Bandeja, «Proponer con la IA». Para apagarla: `update contador_config set activa =
false where id = 1`. Recién pegado, la alarma 73 («la llave y la función»)
sale en rojo hasta la primera ráfaga: es la esperada.

## La obra (7b, 31-oct)

Pedido de Edgar, al ver «Pide obra» en un cargo de CES: «¿no puedes tú
vincularlo con una obra directamente, que tienes esa información?». Sí: la
app ya sabe dónde estuvo la cuadrilla, de qué comercio son los tickets de
cada obra y qué eligió Edgar antes. Hecho con el mismo reparto (Fable con
esfuerzo máximo en la base, la función, la verificación y los arreglos; Opus
5.5 en la pantalla y el e2e).

**Las pistas (`fn_contador_pistas_obra`).** Por cada obra activa (aprobado,
ejecución o pausa), alrededor de la fecha del cargo: las horas de la
cuadrilla esos días (±3) y en el mes (30 días), los tickets del mismo
comercio en 180 días (`fn_contador_mismo_comercio`: «HOME DEPOT» casa con
«THE HOME DEPOT» y con los alias de c3, no con una palabra suelta), las veces
que Edgar eligió esa obra para ese comercio y los materiales de su lista
apuntados esos días. Puntos: horas cerca ×2, horas del mes ×0,2, tickets ×6,
elecciones ×10, materiales ×1. **Candidata** solo si suma 8 o más y llega a
una vez y media la segunda (el doble dejaba sin candidata compras claras:
7 tickets de CES a una obra contra 1 a la otra); confianza `min(0,9, p1/(p1+p2+4))` y un motivo en llano («la
cuadrilla reportó 24 h en Casa Pérez esos días; 2 compras anteriores de CES
fueron a esa obra»). A la IA no le llega ninguna persona, nota ni ruta: solo
el nombre de la obra y cinco totales. Sin pistas claras, «pide obra» como
antes: la IA no adivina.

**Qué cambia.** La IA recibe `pistas_obra` con el cargo y contesta `obra =
{proyecto_id, confianza, motivo} | null` (esquema `anyOf` objeto/nulo); la
base lo comprueba (obra activa, forma válida, cuenta que admite obra) y lo
copia a las líneas; una obra cerrada o inventada se descarta con nota y la
propuesta sigue sin obra. Las reglas por comercio **siguen sin guardar la
obra**, pero al aplicarse toman la candidata de las pistas (la de la última
vez pesa 10 puntos). «Así es» aprueba con la obra del selector: la propuesta
→ `aprobada`; otra → `editada` con la de Edgar. Una obra que se cierra
después de proponerla: el cuadre **64** la nombra (en la propuesta y en las
líneas), la Bandeja no la preselecciona, y `fn_contador_aprobar` la frena con
MX008 «elige otra o di No es eso» aunque se mande a propósito; es el único
cuadre que no tapa la franja de la IA, porque el remedio está en la propia
propuesta. Columnas nuevas en `v_contador_bandeja` (`obra_propuesta_id`,
`obra_propuesta`, `obra_confianza`, `obra_motivo`, `pistas_resumen`),
`propuestas_con_obra` en `v_contador_estado`, la columna
`contador_propuestas.pistas`, y tres índices de lectura `contador_*_idx` en
`horas`, `recibos` y `materiales` (lo único que c8 toca de la app; con 10.000
horas y 2.000 tickets las 20 llamadas de una ráfaga tardan 0,3 s).

**La pantalla.** El chip dice «IA · 5100 Material · Calla Terrace · 85 %»
(«Regla · LOWE S · Casa Pérez»); en «Según la IA», «Obra: Calla Terrace ·
78 %» con su porqué, o las pistas en gris si no apuntan a una sola; el
selector sale siempre que una cuenta de la propuesta admite obra, ya
elegido, y el botón dice «✓ Así es · Calla Terrace»; en «Según yo» la obra
propuesta queda elegida en cuanto la cuenta la admite. La franja: «9
propuestas listas (3 con obra)».

**Pruebas.** `c8-pruebas.sql` **32/32** (la 23 ya pasa también con las reglas
reales de producción: cada prueba que aplica reglas aparca antes las
anteriores a la transacción); `contador-e2e.mjs` **130/130** en Node y en
Deno (E2E-110 a E2E-128, incluida la obra que se cierra después); c6
163/163 con c8 encima y la bandeja cargada; `pantalla.js` **321** (la base
de mentira copia las reglas de obra de c1: 6300 y 6400 prohibidas, 5300
obligatoria, 1420 opcional); `e0`, `e13`. Verificación desde cero (Fable)
y sus hallazgos corregidos y probados.

**Cómo se instala la 7b**: 1 volver a pegar `c8-contador.sql` (idempotente,
encima del de la mañana; «0 cuadres rojos»); 2 pegar `c8-pruebas.sql` (32 en
`true`); 3 redesplegar la función `contador` con el `index.ts` nuevo (Verify
JWT apagado) y mirar `?paso=salud`; 4 publicar (v294). La versión del prompt
cambia, así que la primera ráfaga vuelve a escribir el caché (centavos de
más, una vez). Si esa primera ráfaga contestara `ANTHROPIC_PETICION` (400),
la cabecera de `index.ts` dice qué mirar: el esquema de `obra`.

## Las propuestas solas y la obra en un toque (7c, 31-oct)

Pedido de Edgar, con el cargo de CES todavía pidiendo la obra: «en el de
CES no me sirve que solo estés seguro un 55 por ciento, tenemos que estar
más seguros y que la IA funcione mejor, y que no tengamos que darle a un
botón para que me dé su propuesta: que cada partida al lado ya tenga
automáticamente su propuesta». Mismo reparto que la 7b (Fable con esfuerzo
máximo en la base, la función, la verificación y los arreglos; Opus 5.5 en
la pantalla y el e2e).

**Primero se midió, con los 57 tickets reales que ya tienen obra.** La
primera obra por puntos acierta 22 de 57; la candidata (una vez y media la
segunda) sale en 30 y acierta 13; con el doble, 26 y 12; solo los tickets
del comercio, 12 de 44; solo las horas, 19 de 47. Es decir: las horas y los
tickets, solos, aciertan cuatro de cada diez veces (la cuadrilla trabaja en
dos o tres obras la misma semana y todas compran en CES y en Home Depot).
Por eso la confianza ya no sale de los puntos: se **calibra** con lo que de
verdad distingue una obra. 0,45 de base (horas y tickets nada más); 0,60 si
Edgar eligió esa obra una vez con ese comercio y ninguna otra; 0,65 si las
tres o más compras anteriores del comercio fueron todas a esa obra; 0,70 si
es la única obra con pistas esos días; **0,80** si la eligió dos veces (y el
doble que cualquier otra); 0,90 con tres. **Fuerte** es 0,80 o más
(`fn_contador_obra_fuerte`, la única fuente del umbral: la base lo guarda
en `flags.obra_fuerte` y `v_contador_bandeja.obra_fuerte`, la pantalla lo
lee y las instrucciones a la IA lo dicen igual). Solo una obra fuerte sale
preseleccionada y solo una candidata fuerte la toma una regla; nada débil
entra solo. Con una obra débil o sin ella, la Bandeja pregunta **«¿De qué
obra?»** con hasta tres botones (`obras_top`: las obras de las pistas con su
pista en llano, «21 h esos días · 2 tickets de CES · la elegiste 1 vez con
CES») y «Otra obra…»; el chip de la fila dice «¿obra?» en ámbar. Así el
cargo de CES se resuelve de un toque hoy y, a la segunda vez que Edgar
elija esa obra con CES, la IA la trae sola con 80 %. A la IA le llega
además, por obra, la **fase** (la más frecuente de las horas de ±7 días; si
no, la de la ficha) y hasta ocho **materiales** de su lista (los comprados
primero, tapados por `fn_contador_sin_datos`; nunca el precio, quién lo
apuntó ni su ticket), y el comercio; sus instrucciones llevan lo medido
(«con horas y tickets nada más, 0,6 como mucho; con evidencia fuerte, 0,8 o
más; si dos obras se parecen, null»).

**Las propuestas salen solas.** (1) La Bandeja propone al abrirla: una
cadena de ráfagas de `max_por_rafaga` mientras la función diga `sigue` (y
`quedan` baje), con la franja «Proponiendo… 40 de 172 · $0.35» y «Parar»;
«Proponer ahora (n)» lanza la misma cadena a mano; también arranca tras
importar un QFX o «Sincronizar ahora» de Plaid; solo con algo nuevo (lo que
Edgar rechazó o lo que ya esperaba al terminar la última cadena no la
dispara otra vez) y nunca dos cadenas a la vez; el interruptor «Proponer
sola al abrir la Bandeja» vive en Conexiones. (2) La **rutina de la base**,
copiada de la de Plaid (c7): pg_cron llama a `fn_contador_programado()` a
las 11:25 UTC (tras el banco de las 11:00) y a las 21:00 UTC; si hay
candidatos y el contador no está apagado ni en el tope, pg_net hace POST a
`contador_config.funcion_url` con `{accion: proponer_todo, origen: rutina}`
y la cabecera `x-mxp-rutina` (el secreto nace en Vault al pegar,
`contador_rutina_secreto`; Edgar copia su valor —lo enseña el final del
pegado— a Edge Functions → Secrets → `CONTADOR_RUTINA_SECRETO`). La función,
con esa cabecera y sin sesión, **solo** sabe `proponer_todo` (cualquier otra
acción, 403; otro secreto, 401; sin secreto en Secrets, 500 en llano y
`salud.rutina = false`, que Conexiones avisa): encadena ráfagas hasta 110 s
en nombre del dueño de `contador_config`, nunca postea, y al terminar
`fn_contador_rutina_marcar(ok, error)`. La alarma **74** («ia: la rutina»)
sale en rojo si la última corrida terminó con error o lleva más de 36 horas
sin correr (o nunca desde que se instaló) con cargos esperando; Conexiones
y el pie de la franja dicen cómo va («Propone sola cada mañana tras el banco
(7:25) y a las 5 de la tarde · última: hoy 7:26 · bien», con las horas de
Miami calculadas para hoy: pg_cron va en UTC).

**El marcador honesto.** `v_contador_estado` cuenta el mes (por
`aprobado_el`, hora de Miami) sobre las propuestas de la IA o de una regla
que entraron: `cuenta_acertadas_mes` (entró la cuenta que traían),
`cuenta_cambiadas_mes`, `obra_acertadas_mes`, `obra_cambiadas_mes` y
`obra_elegidas_mes` (no traían obra y Edgar la puso). La pantalla: «Este
mes: cuenta 18 de 20 · obra 7 de 11 acertadas (1 corregiste, 3 elegiste
tú)», sin maquillar. `fn_contador_pegado` pasa a 12 filas (la rutina, pg_cron
y el valor del secreto para copiarlo).

**Pruebas.** `c8-pruebas.sql` **38/38** (33 fase y materiales, 34 la
calibración caso por caso, 35 `obras_top` y `obra_fuerte`, 36
`fn_contador_programado` con el shim de pg_net, 37 `fn_contador_rutina_marcar`
y la 74, 38 el marcador), limpia y con la bandeja como producción (dos
veces); c6 163/163; `contador-e2e.mjs` **143/143** desde cero en Node y en
Deno (140 sobre una base hecha; E2E-129 a E2E-139: `quedan`/`sigue`,
`obras_top`, la regla que solo toma lo fuerte, los materiales a la IA sin
nada personal, el marcador, la puerta de la rutina, `fn_contador_programado`
reproducido contra la función, la 74), `pantalla.js` **369** (46 nuevas «IA
7c»: la cadena sola, «Parar», el interruptor, MX008, los botones de obra, el
chip «¿obra?», el marcador, la rutina, el teléfono y el iPad), `e0` 34,
`e13` 42, `deno check` y `deno lint` limpios. Rendimiento con 10.000 horas,
2.000 tickets y 2.000 materiales: las 20 pistas de una ráfaga, 0,7 s.
Verificación desde cero (Fable): 0 hallazgos graves y 8 menores, corregidos
los que valían (las horas de la rutina calculadas en vez de fijas, el
botón se llama «Proponer ahora», la ráfaga que abre un lote y corta sin
guardar cuenta como ráfaga) y documentados los que son a propósito (la
candidata es la primera por puntos y lo elegido solo la hace fuerte cuando
las horas apuntan a la misma obra; una descripción de material con un
nombre escrito a mano pasa tal cual; «Así es» con obra débil lo exige la
pantalla, no la base).

**Cómo se instala la 7c**: 1 volver a pegar `c8-contador.sql` (encima del
7b; al final enseña el secreto de la rutina); 2 copiar ese valor a Supabase
→ Edge Functions → Secrets → `CONTADOR_RUTINA_SECRETO`, y comprobar en
Database → Extensions que `pg_cron` y `pg_net` están habilitados (las dos
tareas `mxp-contador-manana` y `mxp-contador-tarde` se programan al pegar);
3 pegar `c8-pruebas.sql` (38 en `true`); 4 redesplegar la función `contador`
(Verify JWT apagado) y mirar `?paso=salud` (`rutina: true`); 5 publicar
(v296). Las propuestas pendientes siguen como están (una de la 7b sale débil
y pide el toque); la versión del prompt cambia y la primera ráfaga vuelve a
escribir el caché.
