# La contabilidad dentro de la app — el plan

**Para qué existe este archivo:** para que cualquier sesión que trabaje la
contabilidad lea **este archivo y su orden de trabajo**, y ya sepa todo. Sin
volver a explorar el repositorio entero. Eso es lo que hace que esto salga
barato en crédito.

**Las órdenes de trabajo están en `docs/conta/fases/`**, una por fase: qué trae
Edgar, qué crea el azul, qué trabaja el verde, cuál es el entregable y cómo se
sabe que terminó.

| | | | |
|---|---|---|---|
| [f01 Plan de cuentas](conta/fases/f01-plan-de-cuentas.md) | [f02 El libro](conta/fases/f02-el-libro.md) | [f03 Puentes](conta/fases/f03-puentes.md) | [f04 Estados](conta/fases/f04-estados.md) |
| [f05 Pantalla](conta/fases/f05-pantalla.md) | [f06 Banco](conta/fases/f06-banco.md) | [f07 Categorización](conta/fases/f07-categorizacion.md) | [f08 Cierre](conta/fases/f08-cierre.md) |
| [f09 Costo por obra](conta/fases/f09-costo-por-obra.md) | [f10 Facturación y WIP](conta/fases/f10-facturacion-wip.md) | [f11 Nómina](conta/fases/f11-nomina.md) | [f12 Cédula y 1099](conta/fases/f12-apertura-1099.md) |
| [f13–14 Paralelo](conta/fases/f13-14-paralelo.md) | [f15 Amarre](conta/fases/f15-amarre.md) | [f16 Contador de guardia](conta/fases/f16-contador-de-guardia.md) | [f17 Paquete fiscal](conta/fases/f17-paquete-fiscal.md) |
| [f18 Obra y flujo de caja](conta/fases/f18-obra-flujo-caja.md) | | | |

---

## El verde y el azul — cuánto piensa el modelo en cada paso

Desde el 23-sep-2026 los dos colores son **el mismo modelo, Claude Opus 5.5**,
a distinto esfuerzo. Opus 5.5 salió el 22-sep y en los benchmarks públicos
iguala o supera a Fable 5.1 a un 40 % de su precio.

| | Qué es | Cómo se pone | Para qué |
|---|---|---|---|
| 🔵 **AZUL** | Opus 5.5 a esfuerzo **máximo** | `/effort max` | **Crea lo delicado.** El diseño, la estructura, el criterio, lo que si sale torcido contamina todo lo que venga después. |
| 🟢 **VERDE** | Opus 5.5 al esfuerzo **normal** | `/effort auto` | **Trabaja encima de lo que el azul ya dejó hecho.** Repetir el patrón, extender, pulir, probar, pegar. |
| ⬆ **ESCALADA** | Claude Fable 5.1 | `/model claude-fable-5-1` | Solo si una fase azul salió y el resultado **no convence**. Se rehace con el mismo contexto. Es lo que recomienda Anthropic: Opus 5.5 primero; Fable cuando `xhigh`/`max` se queda corto. |
| ▶ | — | — | **Necesita a Edgar.** Decidir, pegar, contratar, auditar, dar el visto bueno. |

Precios por millón de tokens: Opus 5.5 **$4 / $20** (caché $0,20) · Fable 5.1
$10 / $50. **Ya no hay que cambiar de modelo a media fase**: solo el esfuerzo.

Casi toda fase lleva los dos: **el azul crea el primero, el verde hace los
otros nueve**. Pensar al máximo se paga en el diseño; en el relleno, no.

La sesión avisa **«esta parte va en azul»** o **«ahora pásate a verde»** antes
de cada bloque, y espera a que Edgar cambie el esfuerzo.

> **El color dice qué modelo escribe en la sesión.** Qué modelo corre *dentro
> de la app* está en el punto 4 y es otra decisión; el aviso «cámbiate a
> verde» nunca se refiere a eso.

### Antes de abrir muchos agentes, se avisa

Un abanico de agentes (`Workflow`) **hereda el modelo de la sesión** y lo
multiplica por el número de agentes. El 21-sep una auditoría de 203 agentes
salió en Fable porque la sesión estaba en Fable. Con Opus 5.5 en los dos
colores ese riesgo baja mucho, pero la regla se queda.

**Regla: antes de abrir un abanico, la sesión dice cuántos agentes y en qué
modelo. Edgar decide.** No es «minimizar Fable» — si el trabajo pide azul, va
en azul. Es «sin sorpresas».

**Regla número uno de este plan:** si vas a empezar una sesión, di
*«hagamos la Fase N»*. No digas *«sigue con la contabilidad»*. La diferencia
en crédito entre una cosa y la otra es de tres a cinco veces.

Escrito el 20 de septiembre de 2026. Corregido el 21 tras la auditoría
adversarial (93 hallazgos, 57 confirmados, 9 bloqueantes).

---

## 1. Qué se decidió (esto no se vuelve a discutir)

| Decisión | Qué se resolvió |
|---|---|
| **Empresa** | Una sola: Max Power Electrical Solutions, Inc. MXP MEP queda fuera. |
| **Día del cambio** | **1 de enero de 2027.** Los libros nuevos arrancan con el año fiscal nuevo. |
| **Nómina** | Gusto o Check. La app **no** calcula ni presenta impuestos de nómina. La app pone el puente: horas → nómina, y nómina → repartida por obra. |
| **Impuestos** | El CPA una vez al año. La app le entrega el paquete: balanza, mayor, activos y depreciación, 1099-NEC de subs. |
| **Contador de día a día** | Se elimina. Edgar hace el cierre mensual. |
| **Base** | Devengado para los libros; el CPA decide qué presenta. |
| **Moneda** | Todo en `numeric` de Postgres. **Nunca** se suma dinero en JavaScript. |
| **Auditabilidad** | **100 %.** Ante contador, IRS, banco y seguro. Ver punto 3. |
| **La IA dentro de la app** | Sí, con límite claro: **propone, nunca postea.** Ver punto 4. |
| **Mano de obra** | La **ÚNICA** fuente de dólares de 5000/5010 es el journal del proveedor de nómina. `horas` no postea dinero: aporta la clave de reparto (horas aprobadas por empleado, obra y período). Antes de que exista el proveedor, el costo por obra se enseña como **estándar** (tarifa × `burden_estandar_pct`), etiquetado así. |
| **Burden** | Lo real sale del journal (impuestos patronales), de la prima de WC en 1410 amortizada y de su ajuste de auditoría, y de las pólizas en 6200. `benefits_detalle` de `escenarios` es **lo que se cotiza al cliente**: solo alimenta la columna «estimado» de la Fase 9 y se recalibra desde el real. GL nunca está en el burden y en 6200 a la vez. |
| **Apertura** | Una sola, al **30 de septiembre de 2026**, desde la balanza de QuickBooks (PDF como documento origen), cargada en la Fase 4. No se recarga al 30-nov ni al 31-dic: se cuadra y se ajustan solo los errores. Los libros oficiales de 2026 siguen siendo QuickBooks; octubre–diciembre en la app son el paralelo, con período marcado `paralelo`. Los ajustes del CPA de 2026 entran en abril de 2027 como `ajuste_cpa`. **El corte del 1 de enero no se mueve.** |
| **Sales tax** | ▶ Edgar confirma con el CPA: si Max Power contrata como mejora a bien inmueble (Regla 12A-1.051), el impuesto pagado al proveedor es costo de 5100; no se cobra ni se separa en la factura. 2300 queda para use tax de compras sin impuesto de Florida y ventas al detalle. |
| **Documentos fuente** | Un recibo, hora, factura o proyecto contabilizado no se edita en monto/fecha/obra ni se borra: se reversa y se crea otro. Se guardan al menos **7 años** desde la presentación; los de activos fijos, la vida del activo + 3. |
| **Quién lee los libros** | Solo el dueño (`es_dueno()`) y, si Edgar lo decide, un rol `contador` de solo lectura para el CPA. El equipo, nada. Lo protege la base, no la pantalla. |

---

## 2. Dónde vive el código nuevo

En `PUBLICAR.md` hay dos sesiones escribiendo el mismo repositorio, con dueños
por archivo. La contabilidad **no pelea con nadie** porque va en archivos
nuevos:

| Archivo | Quién |
|---|---|
| `js/conta.js` | **Nuevo. Solo contabilidad.** Nadie más lo toca. |
| `docs/conta/*.sql` | **Nuevo.** No se mete en `docs/sql/`, que es de MXP Planos. |
| `supabase/functions/contador/index.ts` | **Nuevo. La IA contable.** Hermana de `cerebro` (que es de Planos y **no vive en este repo**): no se parchea `cerebro`. 🔵 el esqueleto en la Fase 7; 🟢 las acciones. ▶ Edgar despliega (`supabase functions deploy contador`) con una llave **nueva** de Anthropic como secreto. |
| `docs/conta/OPERACION.md`, `docs/conta/MAPA-DATOS.md` | Nuevos. El manual del 2 de enero y el mapa de datos generado desde `pg_description`. |
| `docs/CONTA-PLAN.md` y `docs/conta/fases/` | Este plan y sus órdenes de trabajo. La memoria del proyecto. |
| `js/app.js`, `js/db.js`, `index.html`, `sw.js` | **Compartidos.** Solo parches chicos. Los previstos: la línea que carga `conta.js`, el botón por rol, `_api/_leer/_rpc` al final de `MXP_DB` (tres líneas, anotadas en PUBLICAR.md), `llave_cliente` en `formMano`/`formRecibo`, y el desvío de 🧾 y de los enlaces a QBO al camino nuevo (Fase 10). **Nada más.** |

Motivo técnico además del social: `js/app.js` pesa 783 KB. Una sesión que lo
abre gasta crédito solo en leerlo. Con la contabilidad aparte, no hay que
abrirlo nunca.

---

## 3. Auditabilidad — la regla que manda sobre todas las demás

Estos libros los tiene que poder abrir un contador, el IRS, el banco o la
aseguradora y **entenderlos sin que nadie se los explique**.

1. **El asiento no se borra ni se edita.** Se corrige con `fn_reversar`, que
   enlaza el reverso al original (`reversa_a`, único, con motivo) y lo fecha
   en el primer período abierto. Ni `asiento_lineas` ni la cabecera `asientos`
   aceptan `update` ni `delete`: lo impide **un trigger**, que frena a todos
   los roles, incluido `postgres` desde el SQL Editor y `fn_postear`. Un
   reverso no se reversa: la re-corrección es un asiento nuevo.
2. **Todo número llega a su papel.** Del estado financiero al asiento, del
   asiento al recibo con su foto, o a la factura, o al reporte de horas
   aprobado. Sin saltos.
3. **Cada asiento dice de dónde salió**: quién, cuándo, desde qué documento y
   por qué camino (a mano, puente automático, o propuesta de la IA aprobada).
4. **Lo que tocó la IA se ve que lo tocó la IA.** Cada asiento nacido de una
   sugerencia lleva el sello: qué modelo, qué versión del prompt, qué entrada
   vio, qué contestó literalmente, quién lo aprobó y cuándo. Un auditor jamás
   debe encontrar una línea cuyo origen no esté claro. **Esto es lo que hace
   compatible «IA en todo» con «100 % auditable».**
5. **El período cerrado se cierra de verdad.** Después del cierre nadie
   escribe ahí — ni Edgar, ni un puente, ni la IA.
6. **Lo que no se puede impedir, se detecta.** Cada asiento lleva un hash
   encadenado al anterior; la ronda nocturna verifica la cadena, que los
   triggers y policies siguen habilitados, y que cada mes cerrado da la misma
   balanza que se exportó. El export mensual lleva el hash del mayor y sale
   por correo (sello de tiempo del servidor); los doce hashes del año van en
   el paquete del CPA. En una empresa de una persona el control no es solo «no
   puede»: es **«si lo hace, se nota»**.

---

## 4. El cerebro contable — qué hace el código y qué hace la IA

Sí va IA dentro de la app, sobre una función propia, **`contador`**, hermana
de `cerebro` (que es de Planos y no vive en este repo). Con una frontera que
no se cruza:

> **Lo que se puede contestar con una resta, lo contesta la base de datos.
> Nunca la IA.**

### Lo determinista — código, corre siempre, no opina

| Control | Qué vigila |
|---|---|
| Cuadre | Debe = haber. Restricción de base. Un asiento descuadrado **no entra**. |
| Conciliación bancaria | Saldo del estado + depósitos en tránsito − cheques y cargos en circulación = saldo en libros, con las partidas guardadas por cierre y enlazadas a su asiento. Detiene el cierre **solo una diferencia no explicada**; una partida de más de 30 días es alarma con nota. Lo mismo cada tarjeta contra su statement a su fecha de corte, cada 25xx contra el statement del prestamista, y el 2010 de cada proveedor contra el statement del supply. |
| Auxiliar = mayor | Suma de 5xxx por obra en el auxiliar = suma de 5xxx en el mayor. La diferencia detiene el cierre. |
| Lectura vacía | Toda consulta financiera declara cuántas filas esperaba. Cero donde debería haber datos **no dibuja la pantalla**, la detiene. Ese es el arreglo del estado financiero en cero — es código, no IA. |
| Período | Nadie escribe en un mes cerrado. |
| Integridad | Triggers y policies habilitados, cadena de hashes íntegra, balanza de cada mes cerrado igual a la exportada. |
| Ronda nocturna | `pg_cron` → `fn_ronda()` en SQL puro → `ronda_resultados`. **La IA no se dispara de noche**: cuando Edgar abre la app y hay rojo, ofrece «que el contador lo explique». |

### La IA — el analista de guardia

- **Explica el descuadre.** El código dice *«faltan $1.240»*. La IA dice *«el
  recibo de CED del 12 entró dos veces, el segundo con otro número de
  transacción»*, y **propone** el asiento de reverso.
- **Concilia** lo que la regla no casó, y deja en la bandeja solo eso.
- **Categoriza** lo que la regla no alcanza, y aprende de las correcciones.
- **Huele lo raro.** *«El material de esta obra va 40 % arriba de tu
  estimador, y el 80 % entró en tres días.»*
- **Contesta en llano** y **redacta** la nota del cierre y el resumen del CPA.

### Las tres reglas de la IA

1. **Propone, nunca postea.** Todo entra a una bandeja de pendientes. Edgar
   aprueba. Un toque, pero el toque existe.
2. **Cita o se calla.** Sin el asiento, el recibo o el movimiento que lo
   sostenga, no se muestra.
3. **Tiene tope de gasto.** Se cuelga del `asistente_costo_mes` y del
   `tope_mes_centavos` que la app **ya tiene montados**, con fila propia por
   acción (`contador_*`).

### Qué modelo usa la app por dentro

**Solo Opus y Fable. Ni Haiku ni Sonnet, en ninguna parte.** Decisión de
Edgar: prefiere pagar más y que sea de verdad inteligente. Lo mecánico mal
hecho es justamente lo que ensucia un libro.

| Tarea | Modelo | Esfuerzo |
|---|---|---|
| Categorizar movimientos, casar recibo con gasto | `claude-opus-5-5` | `low` |
| Leer un recibo, resumir el mes, redactar la nota del cierre | `claude-opus-5-5` | `medium` (su normal) |
| **El auditor**, explicar un descuadre, proponer el reverso, oler lo raro, conversar | `claude-opus-5-5` | `xhigh` / `max` |

Si en la Fase 16 el auditor a `max` se queda corto en casos reales, esa acción
concreta sube a `claude-fable-5-1` — la misma regla de escalada que en las
sesiones. **Ojo:** el esfuerzo por defecto de Opus 5.5 es `medium`, no `high`;
se fija siempre explícito.

### Cómo se paga eso sin que se dispare

El esfuerzo es el lever, **no el modelo**.

1. **`output_config: {effort: "low"}`** en lo repetitivo. Mismo modelo, mucho
   menos gasto. El `effort` va **dentro** de `output_config`.
2. **Prefijo cacheado.** El plan de cuentas y las reglas van primero y fijos,
   con `cache_control`; lo variable al final. Solo cachea si el prefijo pasa
   de 512 tokens y las llamadas van a menos de 5 minutos entre sí: se
   categoriza **en ráfaga al abrir la bandeja**, esperando la primera
   respuesta antes de disparar el resto. La primera debe devolver
   `cache_creation_input_tokens > 0` y las siguientes
   `cache_read_input_tokens > 0`; ambos se guardan por lote.
3. **Batches queda para después del corte** (Fase 18), si el gasto lo
   justifica: es asíncrono a 24 h y exige guardar el lote, sondearlo y
   recogerlo, por centavos al mes. En la v1 todo va en vivo a `low`.
4. **La frontera de arriba es el ahorro más grande de todos.** Cada pregunta
   que contesta Postgres es una llamada que no se paga.
5. **Tope duro** en `asistente_costo_mes` / `tope_mes_centavos`.

---

## 5. Lo que se puede romper, y con qué se tapa

### 5.1 El peligro real: la app falla callada

`js/db.js` tiene **48 veces** el patrón `.catch(() => [])`. Para la app de obra
está bien pensado. Para contabilidad **es veneno**: una lectura que falla
devuelve lista vacía, y el estado de resultados enseña una cuenta en cero sin
avisar.

**Tapa:** `js/conta.js` nunca usa ese patrón. Si una lectura falla, la pantalla
se niega a dibujar y dice cuál falló.

### 5.2 Doble posteo desde el banco

El banco manda el movimiento pendiente y después el confirmado, y en varios
bancos **cambia el identificador**.

**Tapa:** llave de idempotencia por movimiento, **y entre archivos** (la salida
del banco y el abono de la tarjeta son el mismo dinero).

### 5.3 Asiento descuadrado por fallo a media escritura

**Tapa:** el posteo va por función de Postgres (una transacción), con
restricción que rechaza el lote si debe ≠ haber.

### 5.4 Fecha de frontera

Un cargo del 31 de diciembre a las 7 pm de Miami es 1 de enero en UTC.

**Tapa:** `fn_fecha_miami(t)` = `(t at time zone 'America/New_York')::date`,
calculada en SQL. Nunca derivada de un timestamp de pantalla.

### 5.5 Dependencias que no controlas

Supabase, el conector del banco, y las sesiones que escriben este código.

**Tapa:** el importador de CSV/OFX se queda **para siempre** como camino de
respaldo, aunque el conector automático funcione.

### 5.6 La defensa que vale por todas: el export mensual

Cada cierre genera CSV desde las vistas (con procedencia y sello) y PDF, los
guarda en un bucket privado `cierres/AAAA-MM/`, se descargan con URL firmada y
se mandan por correo a Edgar con adjuntos por la función `correo` que ya
existe: Gmail los guarda y cualquiera los abre sin Supabase. El mayor lleva el
hash del mes. Google Drive por OAuth es un proyecto aparte y queda como v2
opcional (Fase 18).

**Legible no es restaurable:** ▶ Edgar confirma el plan de Supabase (respaldos
diarios / PITR); si es gratuito, un `pg_dump` automatizado a Storage cada
semana. La restauración se prueba una vez, con `pg_restore` en un proyecto
vacío, en la Fase 15.

### 5.7 Sin señal

La app es PWA. `conta.js` es **solo-online**: sin señal muestra «Sin señal» y
no pinta nada. `recibos` gana `llave_cliente` única como ya la tienen `horas`
(409 = ya estaba). Un documento que llega a un mes cerrado no se rechaza ni
reabre el mes: se postea con `fecha_contable = greatest(fecha_documento,
primer día del período abierto)` y una nota en la procedencia. **Nada anterior
a la apertura del 30-sep-2026 postea por puente**: eso ya está en QuickBooks.

---

## 6. El calendario

🔵 **azul = Opus 5.5 `/effort max`, crea** · 🟢 **verde = Opus 5.5 `/effort auto`, trabaja encima** · ▶ **necesita a Edgar**

| # | Semana | Fase | 🔵 Lo que se crea (azul) | 🟢 Lo que se trabaja encima (verde) |
|---|---|---|---|---|
| 1 | 21–27 sep | 1 Plan de cuentas | Estructura, DDL de `cuentas`, dimensiones, cuentas nuevas, bloque 0. ▶ Reaccionas al borrador y decides los cost codes. | Los INSERT y los 20 `cost_codes` en `c1`. ▶ Pegar y devolver el bloque 0. |
| 2 | 28 sep–4 oct | 2 El libro | Tablas, `fn_postear` (cuadre, número, escala, SQLSTATE, hash), triggers de inmutabilidad y período, RLS de lectura, `fn_reversar`, fecha Miami. | `c2-pruebas.sql`: las nueve pruebas que lo atacan. ▶ Pegar. |
| 3 | 5–11 oct | 3 Puentes, cobros y CxP | El contrato (idempotencia, papel intocable, tardíos, apertura como puente), `facturas` con su ciclo de vida, el modelo de cobros y de CxP, horas aprobadas como clave de reparto. ▶ **Mapeo y reconocimiento para el viernes 2-oct.** | `recibos` y `trabajos_externos` → gasto, vista de horas, backfill desde el 1-oct, llave en recibos. |
| 4 | 12–18 oct | 4 Estados + esqueleto de 5 | Mapeo a los estados (ES/EN), vista de comparación contra QuickBooks y tabla de diferencias, auxiliar = mayor, esqueleto de `conta.js` con falla ruidosa. | Vistas, balanza, clic al asiento, carga de la **apertura al 30-sep**. ▶ Balanza de QuickBooks al 30-sep + statements de septiembre; **auditas la apertura**. |
| 5 | 19–25 oct | 5 Pantallas + 6 Banco | Idempotencia entre archivos, conciliación con partidas, transferencias, casado de cobros y pagos a proveedor, préstamos. | Pantallas sobre el esqueleto; un lector por banco y tarjeta; aplicación de cobros y pagos. ▶ Archivos del banco para el viernes 16-oct; **arranca el alta en Gusto**. |
| 6 | 26 oct–1 nov | 7 Categorización | Motor de reglas, bandeja con sello completo, esqueleto de `contador`, reglas de S-corp, capitalización y use tax. | Pantalla, editor, cliente, Opus a `low` en ráfaga con caché. ▶ Reglas para el viernes 23-oct; **despliegas `contador`**. |
| 7 | 2–8 nov | 8 Cierre y alarmas | Cierre, ronda con pg_cron, activos fijos, regla de ajustes post-cierre, criterio de OPERACION.md. | Export a Storage + correo, DR-15, avisos, historial. ▶ pg_cron, plan de Supabase, acción de `correo`; **cierras octubre**. |
| 8 | 9–15 nov | 9 Costo por obra | El motor, **el reparto de mano de obra y burden** (una sola vez, aquí), costo estándar, burden aplicado. ▶ Decides cómo se compara. | Pantallas y reportes. ▶ Validas contra una obra que te sepas de memoria. |
| 9 | 16–22 nov | 10 WIP, retención y factura | WIP sobre `alcances`, estimado revisado, provisión por pérdida, retención, **el retiro de `qb`**. ▶ Método de avance. | Plantilla básica, PDF y envío, `crearAlcance`, desvío de 🧾. |
| 10 | 23–29 nov *(Thanksgiving)* | 12a W-9, COI y 1099 | La cédula de corte y el criterio del pago reportable. | Campos de W-9/COI, reporte 1099 con datos parciales, `activos_fijos` cargada. ▶ W-9 y COI de cada sub. |
| 11 | 30 nov–6 dic | 11 Nómina | El asiento real de la corrida y el modelo de `nomina_corridas`/`nomina_reparto`. | Lector del diario del proveedor, reparto por horas aprobadas, corrida de prueba. ▶ **Gusto contratado**, export del diario. |
| 12 | 7–13 dic | 12b Cuadre al 30-nov · **colchón** | — | Cuadre contra la balanza de QuickBooks al 30-nov y cédula de corte cuadrada. Lo que se haya corrido. ▶ Balanza al 30-nov y statements de noviembre. |
| 13–14 | 14–27 dic | Paralelo | Solo la diferencia que se resista, con la regla de escalada. | Las diferencias de rutina, cada una en la tabla de diferencias. ▶ Diciembre en los dos sistemas. |
| 15 | 28 dic–3 ene | Amarre | — | Apagar `qb`, retirar la casilla manual, OPERACION.md, prueba de restauración. ▶ Visto bueno → **1 de enero de 2027: en vivo.** |

### Después del corte

| # | Cuándo | 🔵 Lo que se crea (azul) | 🟢 Lo que se trabaja encima (verde) |
|---|---|---|---|
| — | enero 2027 | — | **En vivo.** Semana del 18-ene: cuadre contra la balanza preliminar de QuickBooks al 31-dic con statements de diciembre, un solo asiento de ajuste por las diferencias de error, cierre de 2026-12 y del período de apertura. ▶ **1099 de 2026 desde QuickBooks** cruzado contra `trabajos_externos`, antes del **1 de febrero** (el 31-ene es domingo). ▶ Los W-2 y el 941 del Q4 los emite quien llevó la nómina en 2026: **no cortar ese acceso hasta tenerlos**. |
| 16 | febrero 2027 | El analista sobre el contrato de la IA de f07. | Extiende la bandeja de f07 a reverso, conciliación y alerta; la conversación. |
| 17 | marzo 2027 | — | La maquinaria del paquete fiscal (primera entrega real: 2028). |
| 18 | marzo 2027 | El camino de vuelta al estimador y el contrato del flujo de caja. | Catálogo, SOV AIA, paquete del GC, flujo de caja proyectado. |

- ▶ **Ene–mar 2027:** QuickBooks vivo en solo lectura; el CPA cierra 2026 desde
  ahí. ~$300 de seguro barato. Antes de cancelarlo, exportar P&L y balance por
  mes de 2025–2026.
- ▶ **~Abril 2027:** el CPA entrega 2026 → sus ajustes entran fechados en abril
  con `tipo='ajuste_cpa'`, `afecta_periodo='2026-12'` y la declaración como
  documento → **entonces, y no antes, se cancela QuickBooks**.

### Qué traes y para cuándo

| Semana | Para el viernes anterior (bloquea la sesión) | Durante la semana |
|---|---|---|
| 1 | — | Reaccionas al borrador, decides cost codes, pegas, devuelves el bloque 0 |
| 2 | — | Pegas `c2-libro.sql` y `c2-pruebas.sql`; decides la fecha del reverso |
| 3 | **Mapeo de gasto a cuenta y reconocimiento de ingreso (2-oct)** | Confirmas si los supplies son a cuenta abierta; revisas una muestra |
| 4 | **Septiembre cerrado en QuickBooks; balanza al 30-sep en PDF y CSV; statements de septiembre de supplies, tarjetas y préstamos (9-oct)** | **Auditas la apertura** |
| 5 | **CSV/OFX de cada cuenta y tarjeta (16-oct)** | **Arrancas el alta en Gusto**; pides API de producción |
| 6 | **Reglas dictadas (23-oct)**; `contador` desplegada con llave nueva | Categorizas un mes a mano |
| 7 | pg_cron habilitado; plan de Supabase confirmado; adjuntos en `correo` | **Cierras octubre en la app** |
| 8 | — | Decides cómo se compara; fijas `burden_estandar_pct`; **validas una obra** |
| 9 | — | Método de avance; costo estimado a terminar por obra; factura en `correo` |
| 10 | W-9 y COI de cada sub | Método de depreciación con el CPA; Gustavo W-2 o 1099 |
| 11 | **Gusto contratado, llaves y export del diario** | Resumen vs empleado por empleado; fechas de pago ≤ 31-dic / ≥ 4-ene |
| 12 | Balanza de QuickBooks al 30-nov y statements de noviembre | Cuadre al 30-nov |
| 13–14 | — | **Diciembre en los dos sistemas** |
| 15 | — | Visto bueno |

---

## 7. Cómo gastar poco crédito

1. **Una fase por sesión, dicha por número.** «Hagamos la Fase 4.»
2. **Archivos nuevos**, para no abrir `app.js` nunca.
3. **SQL primero.** Si lo puede hacer una vista de Postgres, no se escribe en
   JavaScript.
4. **Este archivo y su `fNN` son la memoria.** La sesión lee eso, no el repo.
5. **Dos sesiones por semana, no cinco.** Cada sesión paga un costo fijo de
   orientarse.
6. **No pidas «revisa todo».** Pide el paso que sigue.
7. **El azul se paga en el diseño, no en el relleno.** `/effort max` crea el
   primer puente; `/effort auto` hace los otros tres con el mismo molde.
8. **Dentro de la app también: Opus 5.5, y Fable solo como escalada** (punto 4). Lo que se regula
   es el **esfuerzo**, no el modelo — `effort: low` en lo repetitivo, prefijo
   cacheado en ráfaga. Batches, después del corte si el gasto lo justifica.
9. **Antes de un abanico de agentes, se avisa.** Ver la cabecera.

---

## 8. Dónde le ganamos a QuickBooks

1. **Costo por obra en vivo, no al cierre.** Las horas y los recibos ya entran
   marcados por proyecto desde la obra.
2. **Estimado contra real, al nivel de la receta.** Esto no lo hace ningún
   programa comprado, porque ninguno tiene tu estimador. El circuito cerrado
   —que la obra cerrada corrija al estimador— es el premio del proyecto
   (Fase 9 lo diseña, Fase 18 lo construye).
3. **WIP y sobre/sub-facturación.** QuickBooks no lo trae. Es lo primero que
   pide un banco o una afianzadora.
4. **Burden real.** Del journal de nómina, no de una tasa pareja.
5. **Flujo de caja desde lo que se debe y lo que te deben, no desde el
   histórico.** Cuando CxC y CxP lleven vencimiento y la nómina su calendario
   (Fase 18), se proyecta desde `cobros`, las líneas abiertas de 2010 y
   `hitos` con fecha esperada. QuickBooks adivina mirando el pasado.
6. **Retención bien modelada.** En QuickBooks es un parche.
7. **Facturación que sabe de obra.** Por hito y por porcentaje de avance,
   schedule of values estilo AIA, retención descontada sola, y el paquete que
   el GC exige desde `documentos_empresa`.
8. **Sin costo por usuario.** Tu cuadrilla ya usa la app.

---

## 9. Dónde vamos

🔵 azul = `/effort max` · 🟢 verde = `/effort auto` · ⬆ escalada a Fable si no convence · ▶ necesita a Edgar

- [ ] Fase 1 · Plan de cuentas — 🔵🟢 ▶ reaccionas al borrador y decides los cost codes
- [ ] Fase 2 · El libro — 🔵🟢 ▶ pegas
- [ ] Fase 3 · Puentes, cobros y CxP — 🔵🟢 ▶ el mapeo es tuyo
- [ ] Fase 4 · Estados y apertura al 30-sep — 🔵🟢 ▶ auditas la apertura
- [ ] Fase 5 · Primera pantalla (solapada con 4 y 6) — 🔵🟢
- [ ] Fase 6 · Banco, tarjetas, cobros y pagos — 🔵🟢 ▶ mandas los archivos; arrancas Gusto
- [ ] Fase 7 · Categorización y la bandeja — 🔵🟢 ▶ dictas las reglas; despliegas `contador`
- [ ] Fase 8 · Cierre, ronda y activos fijos — 🔵🟢 ▶ pg_cron; cierras octubre
- [ ] Fase 9 · Costo por obra + reparto de burden — 🔵🟢 ▶ decides y validas
- [ ] Fase 10 · WIP, retención, factura y retiro de `qb` — 🔵🟢 ▶ método de avance
- [ ] Fase 12a · W-9, COI y 1099 — 🔵🟢 ▶ W-9 y COI
- [ ] Fase 11 · Puente de nómina — 🔵🟢 ▶ **Gusto contratado (trámite desde la semana 5)**
- [ ] Fase 12b · Cuadre al 30-nov y cédula de corte — 🟢 ▶ balanza al 30-nov
- [ ] Fases 13–14 · Marcha en paralelo — 🔵🟢 ▶ casi todo tuyo
- [ ] Fase 15 · Amarre — 🟢 ▶ visto bueno → **1 de enero en vivo**
- [ ] Enero · cierre de diciembre, 1099 de 2026 desde QuickBooks, W-2 del proveedor viejo — 🟢 ▶
- [ ] Fase 16 · El contador de guardia — 🔵🟢 (febrero)
- [ ] Fase 17 · Paquete fiscal — 🟢 (marzo)
- [ ] Fase 18 · Obra, flujo de caja y camino de vuelta — 🔵🟢 (marzo)
- [ ] Abril · ajustes del CPA → cancelar QuickBooks — ▶
