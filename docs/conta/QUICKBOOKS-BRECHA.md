# Lo que nos falta frente a QuickBooks (y cómo lo cerramos) — fecha 26-oct-2026

**Para qué es este archivo.** Edgar preguntó qué más hace QuickBooks que nosotros
todavía no, de dónde van a salir los «módulos de pago» cuando QuickBooks se apague
el 1-ene-2027, cómo pagar por depósito directo sin nómina, qué pasa con el módulo
de construcción, y qué hay que sacar para los avisos por mensaje. Esto es la
respuesta completa, con precios vigentes a octubre de 2026 y su fuente al final.

**Cómo leerlo.** La sección 1 es el mapa: una fila por herramienta de QuickBooks.
Las secciones 2 a 5 desarrollan las cuatro brechas grandes. La 6 dice lo que no
vamos a hacer y por qué. La 7 es el orden: qué trámites arrancas ya y qué
construimos sin esperar. Todo lo marcado **▶** es tuyo.

**Tres cosas antes de empezar:**

1. **Las decisiones del plan no se tocan** (CONTA-PLAN §1): corte el 1-ene-2027,
   nómina en Gusto (la app no calcula ni presenta impuestos de nómina), apertura
   única al 30-sep, la IA propone y nunca postea, el dinero se suma en Postgres.
2. **Nada de esto cambia el calendario de las fases 7 a 15.** Lo nuevo entra
   donde ya había hueco (la factura de f10 necesita un «cómo pagar»; los pagos
   salientes pueden esperar a febrero, con f16, porque hoy ya pagas desde Chase
   y la app lo casa; enero queda para el arranque) o se come el colchón de la
   semana 12.
3. **Las cifras vienen de resultados de búsqueda**, no de las páginas oficiales
   (el entorno no pudo abrirlas). Cada precio lleva su fuente [n]. Lo que no
   tiene fuente fiable dice **dato por confirmar**. Antes de pagar algo,
   confírmalo en la pantalla del proveedor. **Revisión del 26-oct (Bari):** confirmadas contra sus páginas o fuentes oficiales: Chase ACH $2,50 / $0,15 y mismo día 1 % tope $25; Twilio brand $4,50, campaña $15 + $1,50/mes; Gusto cerró el plan «solo contratistas» a nuevos clientes el 1-oct-2026; umbral 1099 $2.000 para pagos de 2026; QuickBooks Plus $140 y Advanced $340 desde el 1-ago-2026; QuickBooks Payments 1 % sin tope para cuentas abiertas desde el 6-sep-2023 (las anteriores, tope $15 según Intuit); Stripe ACH 0,8 % con tope $5. Quedan **por confirmar** en la pantalla del proveedor: la fecha exacta desde la que Twilio exige las URL de Privacidad y Términos (su changelog [143]) y el día en que el IRS apaga FIRE (una fuente dice 19-nov-2026, otras fin de 2026 [92]).

---

## 1. El mapa en una tabla

Columna «Nosotros hoy»: *construido* (en producción o pegado), *planeado en fase X*
(está en `docs/conta/fases/`), *no estaba en el plan* (decisión nueva).

| QuickBooks | Nosotros hoy | Qué falta | ▶ Qué tienes que sacar tú |
|---|---|---|---|
| **Suscripción** Plus $140/mes (5 usuarios), Advanced $340/mes (25); subida del 1-ago-2026 [94][95]; Payments, Payroll, Time, Bill Pay y 1099 se cobran aparte | Construido: la app no cobra por usuario (CONTA-PLAN §8) | — | Nada. Es la referencia del ahorro |
| **Projects** (rentabilidad por obra; solo Plus/Advanced; estimado vs real solo Advanced) [97][98][99] | Construido: `proyectos`, `finanzas_proyecto`, `codigos_partida` (cost codes), dimensión obra + cost code en `asiento_lineas`, vistas `v_costo_por_obra`, `v_obras_dinero`, `v_balanza_obra` (c4) | Planeado f09 (9–15 nov): reparto de mano de obra y burden, costo estándar, estimado vs real por receta | Decidir cómo se compara (cost code, receta o ambos); fijar `burden_estandar_pct`; validar una obra que te sepas de memoria |
| **Estimates → Invoices** (aceptar en línea, pedir depósito; requiere Payments) [105][106] | Construido: estimador propio (`estimados`, `escenarios`, `catalogo_items`), propuestas con opciones y firma electrónica en el portal, `trg_co_firmado` crea el pendiente de facturar el depósito | No estaba en el plan: **cobrar el depósito en línea** desde la propuesta (sale solo con el procesador de §2) | Cuenta en Stripe (§2) |
| **Progress invoicing** (en todos los planes; sin SOV ni retención) [107] | Hoy: botón «Facturar» del hito → función `qb` → QuickBooks. Planeado f10 (16–22 nov): factura por hito, % y T&M con retención; vista previa hecha (`docs/conta/f10-factura-vista-previa.html`) | f10 completa (`c10-facturacion-wip.sql`) | Método de avance; serie de factura; acción de factura en la función `correo` |
| **Retainage** (nada nativo: cuenta + línea negativa a mano) [108] | Construido: cuentas 1120 y 2020 (c1), `fn_anticipo_aplicar` con retención, la retención en % se pregunta al facturar (v282) | Planeado f10: descontada sola en cada factura y liberada al cierre | Nada |
| **Products & Services, clases, campos** [96] | Construido: `catalogo_items` y ensambles del estimador, `codigos_partida`; la obra es la dimensión (no hacen falta clases) | Planeado f18: catálogo de servicios en la factura | Nada |
| **QuickBooks Time** Premium $20 + $10/usuario, Elite $40 + $12/usuario [109][110] | Construido: `horas` por obra, fase y CO; `fn_horas_aprobar`; conector `registrar_horas`, `importar_horas`, `reparto_horas_fase`; avisos por push | GPS y geocerca: no están en el plan y no son contabilidad | Nada |
| **Receipt capture** (foto, correo, OCR; sin obra ni cost code) [111] | Construido y mejor: `recibos` con foto, obra, CO y categoría que el puente lleva a su cuenta (c3); `cerebro` lee el recibo; `registrar_gasto`, `compra_sin_recibo`, `importar_gastos`. El cost code en el recibo todavía no existe: c3 lo leerá solo el día que la columna aparezca (f09) | No estaba: reenviar recibos a una dirección de correo; factura de proveedor por foto | Nada |
| **Bank feeds + reglas + sugerencias** [112] | Construido: Plaid con Chase y las dos Amex conectadas y sincronizando cada mañana (c7, 25-oct), código del teléfono activo (s1), `movimientos_banco`, `fn_banco_casar_todo`, `banco_descriptores`, bandeja (v283) | Construido (f07, 31-oct): reglas por comercio que la app aprende al aprobar (y que parten un movimiento), `ia_propuestas` con sello (entrada congelada, salida cruda, versión del prompt), función `contador`, y en la bandeja «Según la IA» / «Según yo» | Pegar c8, la llave nueva de Anthropic, desplegar `contador`; después aprobar la primera ráfaga |
| **Recordatorios y estados de cuenta** (3 recordatorios por correo; estados a mano; sin SMS) [113][114] | Planeado sin fase dueña: «estados de cuenta y recordatorios (f10, f16)» (CONTA-PLAN §6b) | Cadencia automática por correo (+ SMS cuando esté aprobado), estado de cuenta mensual (§5) | Lo de §5: 10DLC, dominio, políticas |
| **Pay now / QuickBooks Payments** ACH 1 % mín. $1 (sin tope en cuentas de Payments abiertas desde el 6-sep-2023; las anteriores conservan un tope de $15 según Intuit [46]), tarjeta 2,99 %, tecleada 3,5 %, instantáneo +1,75 % [43][55]; botón «Pay now», pago de varias facturas a la vez, Autopay [115] | **Nada propio**: `facturas.link_pago` existe en el esquema pero nada en el repo la lee ni la escribe (solo `qb`, cuyo código no está aquí, podría llenarla); el portal no tiene botón de pago; el único gancho contable es `fn_banco_cobrar` / `fn_banco_casar_con` con `comision` → 6130 | **No estaba en el plan**: procesador propio, enlace en la factura, webhook con su función puente en la base, cuenta puente y casado del payout (§2) | Abrir Stripe en noviembre (EIN, SSN, cuenta Chase, URL del negocio). Mirar la fecha de alta de tu cuenta de Payments y la comisión de un ACH grande en tu estado. Mirar `link_pago` en una factura real |
| **Facturas recurrentes + Autopay** [117] | Nada | No estaba; con Stripe el mandato ACH guardado lo resuelve (§2.4) | Nada extra |
| **Bills y Bill Pay** Basic 5 ACH gratis, Premium $15/mes (40 ACH), Elite $90/mes; cheque $1,50 [118][119] | Construido: CxP por proveedor en 2010, `fn_banco_pagar_proveedor`, `v_cxp_antiguedad`; la app casa lo que el banco ya pagó | **No estaba**: pagar desde la app (ACH/cheque), bills con vencimiento y aprobación (§3) | Activar ACH Payment Services en Chase; Melio opcional |
| **Contractor Payments** $25/mes, 20 contratistas, +$2 c/u, depósito al día siguiente [70]; el 1099 e-file solo es ilimitado con Contractor Payments, Payroll o Bill Pay Premium/Elite [120] | Planeado f12a (23–29 nov): W-9, COI y TIN en `proveedores` / `externos_equipo`, reporte 1099 | **No estaba**: el depósito directo en sí (§3) | W-9 y COI de cada sub; ACH de Chase |
| **Payroll** Core $50 + $6,50/empleado; Premium $88 + $10 [121][122] | Decidido: Gusto (f11, 30 nov–6 dic); `fn_banco_nomina` para el journal del proveedor viejo | Nada en la app: horas → Gusto → journal → libro | Contratar Gusto (pendiente desde la semana 5); export del diario |
| **Automated Sales Tax** (calcula, no presenta; e-file retirado en 2020) [123] | Construido: 7,5 % en el estimador; cuenta 2300 use tax; f07 propone use tax; f08 vista para el DR-15 | Nada más, salvo que el CPA diga «retail + instalación» | Confirmar con el CPA la Regla 12A-1.051 [124] (el surtax del condado va por el condado de entrega, con tope en los primeros $5.000 [125]) |
| **Mileage** (solo el admin principal; 72,5 ¢/milla 2026) [126][127] | Nada | No estaba; decisión aparte (la deducción de vehículo va al CPA, f17) | Decidir si lo quieres |
| **Reports** por plan [128] | Construido: 28 vistas (c4) y la pestaña Estados publicada el 26-oct (v286); pg_cron ya corre (la rutina de Plaid) | f08 cierre y export; f10 WIP; f17 paquete; f18 flujo proyectado | Nada |
| **Budgets** (por cuenta y año) | Columna «estimado» por obra desde `estimados` (f09) | No estaba: presupuesto anual de gastos generales (chico; f18) | Nada |
| **Audit log** (2 años) [129] | Construido y mejor: asientos inmutables (`fn_libro_inmutable`), hash encadenado (`fn_verificar_cadena`), sello de IA en `ia_propuestas` (f07), 7 años | — | Nada |
| **Accountant access** (2 asientos gratis) [96] | Previsto si lo decides: rol `contador` de solo lectura para el CPA (CONTA-PLAN §1; f05 aporte 19; se construye en f16, febrero) | f16 | Decidir si el CPA entra directo |
| **Apps aparte** Knowify $99–329/mes, Buildertrend ~$339–499, Jobber $99–149, Housecall Pro $149 [130][131][132][133] | Construido: la app de obra ya es eso (propuestas, firma, CO, portal, documentos, inspecciones, calendario) | f09 / f10 / f18 (§4) | Nada |
| **QuickBooks Checking / envelopes** 3,00 % APY solo en sobres [135][136] | Chase + reserva 1030 con transferencia semanal fija (f08) | Nada: no se cambia de banco | Programar la transferencia semanal a la reserva (monto del CPA) |
| **Multiusuario y permisos** (Plus: 5 usuarios, roles gruesos) [137][138] | Construido: RLS y `es_dueno()`; el equipo ya usa la app sin costo por asiento | rol `contador` (f16) | Nada |
| **App móvil** [139] | Construido: PWA instalada; push ya funciona (`notificar`) | — | Nada |
| **Extras de Advanced** (workflows, lote, Spreadsheet Sync, respaldo a un punto en el tiempo) [138] | Triggers y pg_cron (`fn_ronda`, f08); export CSV/PDF (f08); respaldo según el plan de Supabase | f08 | Confirmar el plan de Supabase (respaldos / PITR) |
| **Factura por SMS** (requiere Payments) [116] | Nada: cero SMS en el repo | **No estaba** (§5) | 10DLC, Privacidad y Términos, Twilio |

**Lo que se ve en la tabla:** el libro, el banco, el costo por obra y el rastro de
auditoría ya están o están en fase. Las cuatro brechas sin fase dueña son
**cobrar en línea**, **pagar desde la app**, **mensajes al cliente** y tres piezas
chicas de construcción. De eso van las secciones que siguen.

---

## 2. Cobrar a los clientes

### 2.1 De dónde salen los «módulos de pago»

QuickBooks Payments es el procesador de Intuit atado a QuickBooks Online: el botón
«Pay now» de la factura, el enlace de pago, Autopay y los depósitos al día
siguiente son servicios de Intuit, no una pieza que se pueda sacar y enchufar en
otra app. Sí existe «QuickBooks Money» (Payments sin suscripción a QBO, $0/mes)
[47], pero su API no avisa cuando el cliente paga (sin webhooks) [51][52], los
enlaces del entorno anterior dejan de aceptar pagos al cambiar la conexión [50] y
su app móvil se descontinuó el 17-nov-2025 [48]. **Conclusión: hace falta un
procesador propio.** La factura que emita la app el 2 de enero tiene que llevar
un enlace que no sea de QuickBooks.

### 2.2 Las opciones, comparadas (EE. UU., octubre 2026)

| Proveedor | Tarjeta en la factura | ACH (débito bancario) | Tarjeta tecleada | Depósito en Chase | Avisa a la app (API + webhook) | Enlace para el PDF |
|---|---|---|---|---|---|---|
| **Stripe** | 2,9 % + $0,30 (Payment Link) [1]; factura alojada desde 3,3 % + $0,30 [4][5] | **0,8 % con tope de $5**, liquida en 4 días hábiles; en 2 días al 1,2 % [2][3][6] | 3,4 % + $0,30 [5] | 2 días hábiles, gratis [7]; el primer depósito de una cuenta nueva tarda 7–14 días (terceros) [17] | Sí: webhooks de pago, disputa y depósito; informe de conciliación por depósito [12][13][14] | Sí |
| **Square** | 3,3 % + 30 ¢ (plan gratis); 2,9 % + 30 ¢ en Plus [19][24] | 1 % mín. $1 **sin tope** en gratis; tope $10 con Invoices Plus ($20 o $49/mes según la fuente: **dato por confirmar**) [19][25][26]; por API 1 % con tope $5, pero las facturas solo se cobran en la página de Square [20] | 3,5 % + 15 ¢ (terceros) [24] | Siguiente día hábil; ACH de factura 3–5 días [22][23] | Sí: Invoices API, webhooks de pago y depósito [21] | Sí |
| **Melio (cobrar)** | 2,9 % [27] | Gratis [27] | No aplica | 3 días hábiles [29] | **No**: la API es solo para pagar, en beta cerrada [28]; Xero compró Melio en oct-2025 [33] | Sí, sin aviso |
| **Plaid Transfer** | No procesa tarjetas | Precio no publicado; solo plan Custom con contrato de 12 meses [34][35] | No | Pasa por el Ledger de Plaid, 2–5 días [36] | Sí, con solicitud de originador aprobada | Hay que construirlo |
| **PayPal Invoicing** | 3,49 % + $0,49 (PayPal/Venmo); 2,99 % + $0,49 (tarjeta) [39] | No hay ACH barato | Dato por confirmar | Retención hasta 21 días a vendedores nuevos [40] | Sí [41] | Sí |
| **Venmo Business** | 1,9 % + $0,10 (terceros) [42] | No | No | 1–3 días | Solo vía PayPal | QR, no factura |
| **QuickBooks Money** | 2,99 % [43] | 1 % mín. $1; **sin tope** en cuentas de Payments abiertas desde el 6-sep-2023; las anteriores conservan un tope de $15 según Intuit [45][46][54]. ▶ Mira la fecha de alta de tu cuenta de Payments y la comisión de un ACH grande en tu estado | 3,5 % [43] | Siguiente día hábil antes de 3 pm PT [44] | API sin webhooks de pago [51][52] | Atado a QuickBooks |
| **Zelle (Chase Business)** | No | **Gratis** [57] | No | Inmediato | **No hay API**; se ve por Plaid como movimiento | QR / Zelle tag [58] |
| **Chase QuickAccept Invoicing** | 3,5 % + 10 ¢ [59]; 2,9 % + 25 ¢ en línea [60] | Zelle/cheque sin comisión | 3,5 % + 15 ¢ [60] | Mismo día, gratis [61] | **No** (sin API ni webhooks) | Sí |

**Otros cargos de Stripe que importan:** disputa de tarjeta $15 [1]; disputa ACH
$15 y ACH fallido $4 [11]; una disputa ACH de un cliente particular puede llegar
hasta 60 días después («no autorizado») y no se contesta por la red ACH [3][16].

**Ejemplo hipotético** (30 facturas al mes de $4.000, $120.000/mes; cifras de la
tabla, no datos reales de la empresa): Stripe con 70 % ACH y 30 % tarjeta ≈
$1.150/mes; Stripe todo ACH ≈ $150; QuickBooks todo tarjeta al 2,99 % ≈ $3.588;
QuickBooks o Square todo ACH al 1 % sin tope ≈ $1.200 (≈ $450 si tu cuenta de
Payments conserva el tope de $15); PayPal ≈ $4.200. **El
ahorro no está en la tarjeta (2,9 % contra 2,99 %): está en mover a los clientes
al ACH con tope de $5.** Una factura de $15.000 por ACH cuesta $5 en Stripe, $150
en Square gratis y ~$435 por tarjeta en cualquiera.

### 2.3 Recomendación

1. **Stripe como procesador principal.** ACH primero, tarjeta como segunda opción,
   en el mismo enlace y sin que el cliente abra cuenta. Es el único que junta ACH
   con tope, API completa, webhooks de pago y de depósito, informe de conciliación
   por depósito [13] y un ejemplo oficial de webhook para Supabase Edge Functions
   en Deno [15], que es justo lo que corre nuestra app.
2. **Zelle de Chase como vía gratis** para residenciales e importes medianos. Ya
   cae en la cuenta que lee Plaid; la bandeja lo propone contra la factura abierta
   y tú confirmas. Nunca como único medio para importes grandes: el límite que
   manda es el del banco del cliente (en personas, unos $2.000–5.000 al día según
   terceros; **dato por confirmar**) [58][66].
3. **Square es el plan B** si Stripe rechaza o retiene la cuenta: tiene lo mismo
   técnicamente, pero cuesta más en tarjeta (3,3 %) y en ACH (1 % sin tope en el
   plan gratis).
4. **No:** Plaid Transfer (contrato de 12 meses y hay que construir la página de
   pago), Melio para cobrar (no avisa), PayPal/Venmo como principal (caro y con
   retenciones), Chase QuickAccept (sin API), QuickBooks Money como puente (sin
   webhooks y atado a QuickBooks).
5. **Recargo por tarjeta en Florida:** el estatuto 501.0117 lo prohíbe pero fue
   anulado por el 11.º Circuito en 2015; en la práctica se permite **solo en
   tarjeta de crédito, nunca en débito ni ACH**, con tope del 3 % y aviso previo
   [68][69]. La vista previa de la factura ya dice «3 % processing fee». Más
   limpio: un precio y **descuento por ACH/Zelle**. (QuickBooks llega a permitir
   una «convenience fee» de $25 por pago ACH [56]; no es el camino.) ▶ Lo decides
   con el CPA.

### 2.4 El flujo en nuestra app

Lo que ya existe hace buena parte del trabajo. `fn_cobro_registrar` anota un cobro
contra la factura (Dr banco / Cr 1110) aunque el depósito todavía no haya llegado,
y entra a cualquier cuenta de banco 10xx (c3); `fn_banco_casar_con` con
`{cobro, comision}` casa un depósito con UN solo cobro y manda la comisión a 6130
«Cargos bancarios y comisiones de tarjeta»; la conciliación de c6 ya sabe de
partidas en tránsito. Lo que no existe: un depósito de Stripe junta varios cobros
netos de comisión, y para eso c6 no tiene camino (paso 4). Lo nuevo es el enlace,
el webhook con su función puente en la base, la cuenta puente y el casado del
payout (c10).

| Paso | Qué pasa | Dónde vive |
|---|---|---|
| 1. Factura | f10 emite la factura: número de `contadores`, PDF, envío por `correo`. Al emitirla, la Edge Function **nueva** `supabase/functions/cobros/` (enlace y webhook en una sola función con `?accion=`, de Contabilidad como `plaid/`; fila nueva en PUBLICAR.md y en CONTA-PLAN §2) pide a Stripe el enlace de pago (ACH + tarjeta, con el número de factura en los metadatos) y lo guarda en `facturas.link_pago`: la columna existe en el esquema pero nada en el repo la lee ni la escribe (solo `qb`, cuyo código no está aquí, podría llenarla: ▶ mírala en una factura real); desde f10 la llena nuestra función con el enlace de Stripe. El PDF lleva el botón y el QR «Pagar en línea» y, debajo, «Zelle: tag del negocio — pon el número de factura en el memo» (la vista previa ya lo trae) | Nuevo (f10, `cobros/`) |
| 2. Pago | El cliente paga sin cuenta. ACH se verifica al instante o con microdepósitos en ~2 días; Stripe guarda el mandato y lo manda por correo [3]. ACH no es firme hasta 4 días hábiles: mientras, la factura marca «pago en camino», sin asiento | Stripe |
| 3. Webhook | La misma función `cobros/` (`?accion=webhook`) con firma verificada (`constructEventAsync`, cuerpo crudo, `verify_jwt = false`, como el ejemplo de Supabase [15]), idempotente por id de evento. Pago confirmado → `fn_cobro_registrar` con medio tarjeta o ACH, referencia = id de Stripe, a la cuenta puente del paso 4. Disputa, reembolso o fallo → `fn_cobro_devolver` (reabre 1110) y aviso push a ti. El webhook no puede llamar a esas dos funciones directo: ejecutan `fn_puente_exigir_dueno()` (42501 «Esto lo hace solo Edgar») y su EXECUTE está revocado para service_role (c3 líneas 1548-1557 y 6046-6047) | Nuevo (c10): `fn_stripe_recibir(p_evento jsonb)` fuera de la API, con el patrón de `fn_plaid_recibir` (c7): fija `request.jwt.claims` al dueño mientras llama a `fn_cobro_registrar` / `fn_cobro_devolver` y lo quita; guarda el `event.id` en una tabla única para la idempotencia. La Edge Function entra a la base como postgres por `SUPABASE_DB_URL`, igual que `plaid/index.ts` |
| 4. Depósito | Stripe deposita el neto en Chase a los 2 días hábiles, y un depósito (payout) junta varios cobros del día. Lo que hoy existe no lo casa: `fn_banco_casar_con {cobro, comision}` casa un movimiento con UN solo cobro y exige que bruto − depósito = comisión de ese cobro (c6 11620-11626 y 12015-12020; c3: «un movimiento del banco casa con un solo cobro vigente»); la regla automática R2 solo suma exacta (c6 10596-10642), y `fn_banco_cobrar` con varias facturas registra un cobro NUEVO al llegar el depósito, que duplicaría los del webhook (MX008, c6 12299-12320). Por eso el webhook anota cada cobro con `fn_cobro_registrar` en una cuenta puente 10xx nueva, «Procesador de pagos — en tránsito» (c3 acepta cualquier cuenta de banco 10xx), y f10 añade UNA función nueva en c10 que casa el depósito de Chase con el conjunto de cobros del payout: Dr 1010 neto + Dr 6130 suma de comisiones / Cr puente bruto, con la lista de cobros e ids de Stripe en la procedencia; la suma de comisiones sale del informe de conciliación de Stripe por depósito [13]. El saldo de la puente debe quedar en cero tras cada payout y la ronda de f08 lo vigila. Plaid trae el depósito a `movimientos_banco` con descriptor STRIPE: c10 amplía la restricción `banco_descriptores_clave` con la clave `procesador` (patrón `STRIPE`), inserta su fila y enseña a `fn_banco_casar_todo`/la bandeja a proponer con ella el casado del payout; `fn_banco_descriptor` solo edita claves existentes (c6 líneas 1741-1767 y 14144) | Nuevo (c10) sobre c6 |
| 5. Zelle | Sin webhook. El movimiento «Zelle payment from NOMBRE» llega por Plaid; `fn_banco_cobrar` ya reconoce el medio `zelle` y propone la factura abierta del mismo importe; tú confirmas | c6 (hecho) |
| 6. Recurrentes | Contratos de mantenimiento: Stripe guarda el método con mandato ACH y la app (pg_cron → Edge Function) crea el cobro de cada ciclo. Con el tope de $5 el cobro recurrente por ACH sale casi gratis | Nuevo (después del corte) |
| 7. Depósito del estimado | La propuesta firmada en el portal puede llevar el mismo enlace para el anticipo; entra por `fn_anticipo_aplicar` como hoy | Nuevo (f10 o f18) |

**Dos cosas que no cambian:** «un depósito NUNCA va a ingreso» (c6, regla 3): el
depósito de Stripe se casa con cobros, nunca se clasifica a 4010. Y la casilla
`pagada` se retira en f15: desde enero la mantiene `cobros`.

**La cuenta puente no es opcional:** sin ella el libro no puede casar un depósito
con varios cobros. La otra vía sería ampliar `fn_banco_casar_con` a
`{cobros: [id…], comision}` (varios cobros ya anotados en 1010 + una comisión a
6130), pero deja 1010 inflado por el bruto hasta el payout y toca una función del
banco ya probada; la puente es el modelo habitual de cuenta de tránsito con un
procesador y da además que 1010 cuadre con Chase día a día. ▶ Lo que decides en
f10 es su código (10xx) y su nombre.

**Frontera de archivos:** el enlace va en el PDF y en el correo sin tocar
`cliente.html`. Un botón «Pagar» dentro del portal es de la sesión App Operativa
(PUBLICAR.md); se le pide, no se le parchea.

### 2.5 Migración desde QuickBooks Payments (nov-2026 → ene-2027)

1. **Noviembre: abrir Stripe ya**, no el 2 de enero. Stripe pone a cada cuenta
   un límite por transacción y por volumen semanal en débitos bancarios que sube
   con el historial [8]: una cuenta recién abierta puede no poder cobrar $20.000
   por ACH el primer mes. Haz 2–3 cobros reales chicos en noviembre para pasar la
   demora del primer depósito (7–14 días) y empezar el historial.
2. **Diciembre, los dos sistemas vivos** (como ya dice f10): las facturas nuevas
   salen de la app con enlace de Stripe + Zelle; las abiertas en QuickBooks
   **siguen cobrándose por su enlace de QuickBooks**. No canceles Payments hasta
   cobrar o reemitir la última factura abierta allí: al cambiar la conexión las
   solicitudes de pago del entorno anterior dejan de aceptar pagos [50], y
   cancelar Payments quita el botón de pago de todas las facturas [53].
3. **Clientes con tarjeta o ACH guardados en QuickBooks:** Intuit no transfiere
   esos datos [50]. Hay que mandarles el enlace de Stripe con la factura de
   diciembre para que vuelvan a autorizar antes del primer cobro de 2027.
4. **Enero 2027:** QuickBooks queda en solo lectura (plan: ene–mar); Payments se
   mantiene hasta ~31-ene para los rezagados y luego se cancela; cancelar QBO no
   cierra la cuenta de comerciante [49] y Payments se factura aparte: revisa el
   cobro de Intuit de febrero. Los depósitos de QuickBooks que aún lleguen a
   Chase se casan con `fn_banco_cobrar` contra las facturas de la apertura, como
   hoy. El 1099-K de 2026 lo emite Intuit; el de 2027, Stripe.

### 2.6 ▶ Pasos de alta en Stripe y lo que debes tener a mano

| Qué piden | Detalle | Fuente |
|---|---|---|
| EIN de la S-corp **y** SSN del dueño | Nombre legal exacto, fecha de nacimiento, dirección | [9] |
| Cuenta bancaria de EE. UU. a nombre de la empresa | La cuenta operativa de Chase (routing y número) | [9] |
| Una URL del negocio | Sitio, perfil social o app donde conste el nombre, los servicios, un contacto y la política de reembolsos/disputas. Si no hay web pública, sirve una página mínima (la misma de §5 para Privacidad y Términos) | [10] |
| Licencia EC13016045 | No la piden al abrir; tenla a mano si piden documentación en una revisión | [18] |
| Cuesta | $0 de alta y $0 al mes; solo comisiones por cobro | [1] |
| Plazo | Alta en línea el mismo día; primer depósito 7–14 días; límites de ACH suben con el historial | [8][17] |

---

## 3. Pagar por depósito directo (sin nómina)

### 3.1 Lo que hoy da QuickBooks

Contractor Payments: $25/mes, 20 contratistas incluidos (+$2 cada uno más),
depósito al día siguiente, el contratista llena solo su W-9 y su banco, y el
1099-NEC sale a fin de año [70]. Ese es el listón. QuickBooks Bill Pay (proveedores):
Basic gratis con 5 ACH al mes, Premium $15/mes con 40 ACH y 1099 ilimitado, Elite
$90/mes [118][119].

### 3.2 Las opciones (12 pagos al mes de ejemplo: 6 personas + 6 proveedores)

| Opción | Fijo | Por pago | Mes (12 pagos) | Llega en | Alta del que cobra | Avisa a la app | 1099 |
|---|---|---|---|---|---|---|---|
| **Chase ACH Payment Services** (ya está en tu cuenta) | $0 | $2,50 los primeros 10 del mes, $0,15 después; mismo día o RTP 1 % con tope $25 [62] (el mismo día admite hasta $1M por pago [87]) | ~$25 | Siguiente día hábil si se aprueba antes de 8 pm ET [62]; desde el 18-sep-2026 Nacha exige fondos a las 9 am del día de liquidación [86] | Tú cargas la cuenta del beneficiario una vez | **No hay API** [65]; la app lo ve por Plaid (webhook de transacciones) [38]; acepta **archivo NACHA** generado por la app [63][64] | Nosotros (IRIS gratis o Tax1099 $2,99/forma [91]) |
| **Zelle for Business (Chase)** | $0 | $0 [57] | $0 | Minutos | Correo o teléfono | No (Plaid) | Nosotros (Zelle no emite 1099-K) [67] |
| **Melio Go / Core** | $0 / $25 [27] | 5 ACH gratis y $0,50 extra / 20 gratis [27] | $3,50 / $25 | 3 días hábiles [29]; «fast» 1 % con tope que varía según la página ($30–75: **dato por confirmar**) [93] | Se autoinscribe por correo, sin cuenta [31] | No (API solo para partners) [32] | W-9 digital y e-file vía Tax1099 solo en Core o superior [30] |
| **Gusto** (lo vas a contratar para la nómina) | Simple $49/mes + $6 por persona pagada (terceros) [75]; el plan «solo contratistas» ($35 + $6) **cerró a nuevos clientes el 1-oct-2026** [71] | $0 | $36 extra por 6 contratistas, encima de la nómina | 4 días al empezar; 2 días tras ~15 días y una corrida buena; next-day después [73] | Se autoinscribe (W-9 + banco) | **No**: Gusto no da API a sus propios clientes [74] | **Incluido** (e-file federal y copia al contratista) [72] |
| BILL | Essentials $49/usuario/mes [76] | $0,59 por ACH; rápido $11,99 [76][77] | ~$56 | 2–4 días hábiles | Red BILL | Limitada a partners [78] | $2,99/forma [76] |
| Stripe Connect (solo pagar) | $2 por cuenta activa/mes [79] | 0,25 % + $0,25 [79] | ~$45 | 1–2 días **después** de fondear el saldo por ACH (5–6 días hábiles) [80] | Cada sub abre cuenta Express | Sí | $2,99/forma [81] |
| Plaid Transfer | Custom, 12 meses [34] | A cotizar | — | 1 día / mismo día | — | Sí | Nada. **Y no admite pagos sueltos a personas** [37] |
| Routable | Growth $1.250/mes [82] | No publicado | >$1.250 | Varias | Portal | Sí | Dato por confirmar |
| Mercury (segunda cuenta) | $0; 100 ACH gratis/mes [83] | $0 | $0 | 0–1 día | Tú lo creas o la API | **Sí** (API con cola de aprobación + webhooks) [84] | Nosotros |
| Relay (segunda cuenta) | Starter $0 [85] | ACH estándar $0; mismo día $5 [85] | $0 | 0–1 día | Tú | API: dato por confirmar | Nosotros |

### 3.3 Recomendación

**Riel principal: Chase ACH Payment Services, con la app de cerebro.** Para 3–8
personas y unos cuantos proveedores cuesta ~$20–27 al mes, el dinero llega al
siguiente día hábil, no pasa por el saldo de un tercero, y cada débito sale en
Chase con el nombre del beneficiario, que es lo que hace el casado casi solo. Lo
que Chase no da (W-9, autorización de depósito, lote, 1099, aviso) lo construye la
app, que es justo lo que un usuario de QuickBooks espera ver «dentro».

**Complementos, a tu elección:**
- **Gusto para los subs de verdad que cobran regular** (negocio propio, su
  licencia o su seguro, varios clientes). Como Gusto se contrata igual para la
  nómina (f11), pagar ahí a un contratista cuesta $6 el mes que se le paga, se
  inscribe solo y el 1099 sale incluido. Contra: 4 días al principio y la app
  solo ve el débito agregado de Gusto en Chase. No para proveedores. **Los
  ayudantes por hora fijos no van aquí**: f12 dice que van por la nómina de Gusto
  desde el 1-ene salvo que el CPA diga lo contrario (F.S. 440.10, §7.1 fila 8);
  hasta esa respuesta no se les abre pago 1099 en ningún riel.
- **Melio Go (gratis)** para el proveedor que manda factura y quiere elegir cheque
  o ACH sin que teclees su cuenta, o cuando quieras pagar con tarjeta (2,9 %) por
  flujo de caja. La app lo trata como riel externo y casa el débito de Melio.

**Descartar:** Plaid Transfer (no admite pagos sueltos a personas; contrato
anual), Routable (precio), BILL (por usuario y sin API para PyME), Stripe
Connect/Treasury (solo reevaluar en 2027 si Stripe cobra a los clientes y conviene
pagar a los subs desde ese saldo). **Mercury** es la única vía a un botón «Pagar»
real desde la app (como QuickBooks), pero implica una segunda cuenta operativa
fuera de Chase: queda como opción futura, no como recomendación.

### 3.4 El flujo en nuestra app

Regla que se respeta: **la app registra y casa lo que el banco hizo** (c6). El
dinero sale del libro una sola vez, cuando Chase lo mueve. Lo nuevo es la orden de
pago y el lote.

| Paso | Qué pasa | Dónde vive |
|---|---|---|
| 1. Alta del beneficiario (una vez) | Enlace seguro: el sub o proveedor rellena su **W-9** (nombre legal, tipo de entidad, TIN, dirección) y una **autorización de depósito directo** (routing, cuenta, tipo). Van a Storage privado; los campos son los de f12a (`tin` solo dueño por RLS, `w9_ruta`, `w9_recibido_el`, `coi_vence`, `coi_ruta`, `wc_exento`). La app marca «sujeto a 1099» (persona, LLC de un miembro, partnership: sí; corporación: no) y, si es persona por hora, solo tras la respuesta del CPA de f12. Tú copias el banco una vez como beneficiario en Chase (PPD persona / CCD empresa) | f12a + nuevo |
| 2. Origen | Horas aprobadas del sub (`trabajos_externos`, ya postea Dr 5200 / Cr 2010) o factura del proveedor (`recibos` a cuenta de proveedor → línea abierta de 2010). La app crea una **orden de pago** (tabla nueva: beneficiario, monto, partidas de 2010, método, fecha deseada) en estado «preparada» | Nuevo |
| 3. Lote | Cada día (pg_cron) las órdenes preparadas se agrupan en un **lote** con su archivo NACHA según la especificación de Chase [63][64] y un resumen en español. Tú lo subes y apruebas en Chase Business Online antes de las 8 pm ET (o lo tecleas si son 2–3 pagos). El lote pasa a «enviado»; sin asiento todavía | Nuevo |
| 4. Casado | Plaid trae el débito (nombre del beneficiario en el descriptor); la bandeja lo propone contra la orden enviada por monto, fecha ±3 días y nombre, y `fn_banco_pagar_proveedor` postea Dr 2010 / Cr 1010 como hoy. La comisión de Chase ($2,50 / $0,15 / 1 %) va a 6130 cuando aparece. Si en 5 días hábiles no casa, aviso push: posible devolución | c6 + regla nueva |
| 5. Zelle y Melio | Igual: el movimiento llega por Plaid y se casa con la orden (Melio sin nombre del beneficiario: por monto, fecha y lote) | c6 |
| 6. Freno de papeles | La orden no se prepara si falta W-9 o el COI está vencido (f12a trae los campos; el freno es nuevo). QuickBooks no hace esto | Nuevo (f12a) |
| 7. Aviso | Al beneficiario por correo o SMS cuando sale y cuando se confirma; a ti cuando un lote espera aprobación o un pago no casó (§5) | Nuevo |

### 3.5 El 1099 (lo que no cambia y lo que hay que saber)

- **La decisión del plan sigue:** el 1099 de 2026 sale de QuickBooks (es el libro
  de ese año), cruzado contra `trabajos_externos`, antes del **1-feb-2027** (el
  31-ene es domingo) [90]. La app produce el de 2027 en enero de 2028 (f12a).
- **Umbral nuevo:** $2.000 por beneficiario para pagos hechos desde el 1-ene-2026
  (antes $600); indexado desde 2027 [88][89]. El plan ya lo tiene en
  `conta_config('umbral_1099', 2000)`, confirmado cada diciembre con el CPA.
- **E-file obligatorio con 10 o más formularios en total** (W-2 + 1099) [88].
  Desde el año fiscal 2026 **IRIS es el único canal** del IRS (FIRE se retira a
  fin de 2026; una fuente dice el 19-nov-2026: **dato por confirmar**) y requiere
  pedir un código TCC con espera [92]. Como el de 2026 lo
  presenta QuickBooks, el TCC se necesita para enero de 2028: pídelo con calma
  en 2027, o usa Tax1099 a $2,99 por formulario [91] (Track1099, que nombra f12a:
  precio **dato por confirmar**).
- **Base caja** y se excluye lo pagado con tarjeta (lo reporta el procesador en
  1099-K) y a corporaciones. Zelle no reporta al IRS [67]: pagar por Zelle no
  quita la obligación. Sigue pidiendo W-9 a todos aunque no lleguen al umbral.

### 3.6 ▶ Pasos de alta

| Qué | Dónde | Costo | Plazo |
|---|---|---|---|
| Activar **ACH Payment Services** en Chase Business Online y cargar los beneficiarios | chase.com → Pay & transfer | $0 fijo [62] | Mismo día |
| Preguntar a tu banquero: **límite diario de ACH** de la cuenta (terceros citan ~$25.000 por defecto: **dato por confirmar**) [66]; si la **carga de archivo NACHA** está habilitada para Business Complete; formato exacto del descriptor del débito | Chase | $0 | Una llamada |
| Inscribir **Zelle for Business** con un correo o teléfono distinto del personal | App de Chase | $0 [58] | Minutos |
| **Gusto**: contratar (ya pendiente desde la semana 5); confirmar que el plan «solo contratistas» ya no existe y que el precio de Simple es $49 + $6 (terceros) | gusto.com | Ver tabla | Semanas (f11) |
| Opcional: **Melio Go** con la cuenta de Chase | melio.com | $0 [27] | Minutos |
| **W-9 y COI de cada sub** (ya pedido en f12a) | Tus subs | $0 | Para la semana 10 |

---

## 4. El módulo de construcción

### 4.1 Qué hace QuickBooks y qué compra la gente aparte

- **Projects** (solo Plus/Advanced): ingresos, gastos y horas por obra con margen,
  tarifa de costo por hora por empleado [97]. Sin cost codes ni fases en Plus; el
  estimado vs real exige Advanced [99][100]. Varios consultores dicen que se rompe
  con 8–10 obras activas.
- **Progress invoicing** en todos los planes, pero sin schedule of values, sin AIA
  G702/G703 y sin retención [107][108].
- **Novedad de agosto de 2026, solo en Advanced ($340/mes):** presupuestos por
  fase, estimado vs real, change orders que actualizan estimado, presupuesto y
  factura, WIP de sobre/sub-facturación y facturación «estilo AIA» [101][102]
  (en febrero se vendía como add-on de pago; en agosto quedó incluido con la
  subida a $340 [103]). Si
  además trae G702/G703 nativos, retención y certified payroll lo dice una sola
  fuente: **dato por confirmar** [104]. Ese es el nuevo listón a comparar.
- **Apps que se compran encima:** Knowify Core $99/mes anual (AIA, change orders)
  y Advanced $329 (job costing, WIP) [130]; Buildertrend ~$339–499/mes anual
  [131]; Jobber Connect $99 y Grow $149 [132]; Housecall Pro Essentials $149 [133];
  Intuit Enterprise Suite a cotización (~$7–8k/año según terceros) [134].

### 4.2 Qué tenemos ya

| Pieza | Estado |
|---|---|
| Obra como dimensión del libro: `proyecto_id` y `cost_code` en cada línea; `codigos_partida` | Construido (c2/c3) |
| Recibos, horas, trabajos externos y materiales que nacen marcados por obra, fase y CO desde el teléfono | Construido (app de obra) |
| Estimador propio con escenarios, burden cotizado, retención %, catálogo y ensambles | Construido (`estimados`, `escenarios`, `catalogo_items`) |
| Costo por obra en vivo: `v_costo_por_obra`, `v_obras_dinero`, `v_balanza_obra` (auxiliar = mayor) | Construido (c4) |
| Propuestas con opciones, firma electrónica, Change Order firmado que dispara el depósito, portal del cliente y del GC | Construido |
| Cuentas de construcción: 1120 y 2020 retención, 1200/2400 sub y sobre-facturación, 2410/5950 pérdida en contrato, 5011/5019 burden, 4040 órdenes de cambio | Construido (c1, 90 cuentas: no hacen falta cuentas nuevas) |
| Retención por cobrar al facturar (en % desde el botón Facturar) y `fn_anticipo_aplicar` | Construido |

### 4.3 Qué falta y en qué orden

| Orden | Fase | Qué entrega | ▶ Tuyo |
|---|---|---|---|
| 1 | **f09 Costo por obra** (9–15 nov) | El reparto de mano de obra y burden sobre horas aprobadas (una sola vez, aquí); costo estándar etiquetado «estándar, no real» hasta que llegue el journal de Gusto; estimado vs real por obra, por cuenta y por cost code (desde octubre); CO contra su estimado | Cómo se compara; `burden_estandar_pct`; validar una obra |
| 2 | **f10 WIP, retención y factura** (16–22 nov) | `alcances` con CO (propuesto/aprobado/rechazado) como precio del contrato; `costo_estimado_total_revisado` por obra y mes; vista `wip_schedule` (% avance, ingreso devengado, 1200/2400, utilidad estimada: el formato de la afianzadora); provisión por pérdida (5950/2410); retención descontada sola y liberada al cierre; la factura propia por hito, % y T&M; **+ el enlace de pago de §2** | Método de avance; revisar el costo a terminar en cada cierre |
| 3 | **f12a** (23–29 nov) | W-9, COI, TIN de subs; cédula de corte; **+ el freno «sin W-9/COI no se paga» y la autorización de depósito de §3** | W-9 y COI |
| 4 | **f18** (marzo 2027) | SOV AIA G702/G703 por renglón de `alcances`; catálogo de servicios en la factura; paquete del GC (COI y licencia desde `documentos_empresa`); flujo de caja proyectado desde CxC, CxP, nómina e hitos con fecha; el camino de vuelta al estimador (lo que aprende `catalogo_items` de una obra cerrada); `overheadReal()` desde 6000–7000 | — |

**Lo que no estaba en el plan y propongo dónde va:**
- **Lien waivers** (condicionales/incondicionales) al pagar a un sub: documento
  generado desde la orden de pago de §3, con la firma del portal. → f12a o f17.
- **Costos comprometidos** (PO o subcontrato firmado contra presupuesto): hoy
  `recibos.po_job` es el texto del PO de Home Depot. → f18, opcional, si lo pides.
- **Certified payroll WH-347 / prevailing wage:** solo si entras a obra pública.
  QuickBooks tampoco lo hace en Plus ni Advanced [104]. → fuera, salvo que cambie
  el tipo de obra.
- **Inventario perpetuo, multi-empresa, multi-moneda:** no (CONTA-PLAN §6b).

Con f09 y f10 la app ya supera a QuickBooks Plus en construcción (cost codes, WIP,
retención, CO ligado) y queda a la par de Advanced de agosto de 2026 por $0 de
suscripción; con f18 lo supera (SOV AIA, camino de vuelta al estimador, flujo
proyectado desde lo que se debe y lo que te deben).

---

## 5. Avisos por mensaje, correo y notificaciones

### 5.1 Lo que ya tienes

Las **notificaciones push al teléfono ya funcionan**: Edge Function `notificar`
(web-push con VAPID), tabla `push_suscripciones`, `fn_cartero` que las dispara
desde la base, `sw.js` y el manifest del PWA. En iPhone funcionan porque la app
está añadida a la pantalla de inicio (iOS 16.4+) [165]. Cuestan $0. Para los
avisos contables (pago recibido, depósito casado, factura vencida, lote por
aprobar) c8 llama `perform fn_cartero(jsonb_build_object('titulo', …, 'cuerpo', …,
'para', <dueño>))` desde sus triggers (SECURITY DEFINER: el EXECUTE de
`fn_cartero` es solo de service_role, e37 línea 199) y desde `fn_ronda()`:
`fn_cartero` y `notificar` ya aceptan título y cuerpo libres y no se tocan
(`fn_cartero` es de `docs/sql/`, MXP Planos; `notificar` no es de Contabilidad).
Es trabajo chico de f08 (su verde ya lo lista), no cero.

El correo ya sale por Resend: la función `correo` (fuera de este repo) lo usa con
la llave `RESEND_API_KEY` (js/db.js 1313). QuickBooks hoy manda la factura; desde
f10 la factura sale por esa misma función.

**Lo que no hay:** SMS, WhatsApp, recordatorios al cliente, aviso «pago recibido»
al cliente. Cero menciones en el repo. Es decisión nueva.

### 5.2 Qué canal para cada aviso

| Aviso | Para | Canal | Por qué |
|---|---|---|---|
| Pago recibido, depósito casado, factura vencida, lote de pagos por aprobar, mes sin cerrar | Tú | **Push (ya existe)**; SMS solo para lo crítico (pago grande, cheque rebotado) | Gratis e inmediato |
| Factura emitida con enlace de pago | Cliente | **Correo** (PDF + enlace) + **SMS corto** con el enlace | El correo lleva el papel; el SMS se lee |
| Recordatorio (vence en 3 días / vencida) | Cliente | Correo + SMS | Informativo: basta consentimiento simple [166] |
| Recibo de pago | Cliente | Correo (+ SMS opcional) | |
| Técnico en camino / visita | Cliente | SMS | Inmediatez |
| Propuesta lista / contrato para firmar | Cliente | Correo + SMS con enlace al portal | |
| Pago enviado / confirmado | Sub o proveedor | Correo o SMS | |

**Regla de oro:** ningún aviso lleva promoción. Un descuento dentro de un
recordatorio convierte todo el mensaje en marketing y exige consentimiento
escrito [166]. Para clientes no conviene push: tendrían que instalar el portal.

### 5.3 SMS: por qué no se puede «probar mandando»

Desde 2023 las operadoras exigen registrar la empresa (Brand) y el uso (Campaign)
en The Campaign Registry a través del proveedor; sin registro Twilio bloquea todo
SMS a EE. UU. desde un número normal (error 30034) [140]. Como S-corp con EIN **no
puedes usar la vía «Sole Proprietor»** (bloquea el envío) [170]: toca **Low-Volume
Standard Brand + campaña «Low Volume Mixed»**, sin vetado extra [141].

| Concepto | Costo | Fuente |
|---|---|---|
| Registro de Brand | $4,50 una vez | [145][146] |
| Vetado de campaña | $15 una vez (si la rechazan, se corrige sin pagar otra vez) | [145] |
| Campaña Low Volume Mixed | $1,50/mes | [147][148] |
| Número local 352 | $1,15/mes en Twilio; $1,10 en Telnyx | [153][148] |
| SMS saliente | Twilio $0,0083 por segmento; Telnyx $0,004; Plivo $0,0077; más recargo de operadora ~$0,004 | [153][154][148][155] |
| Límite de envío con Low-Volume | T-Mobile 2.000 segmentos/día por marca; sobra | [149] |
| **Total a 200 SMS/mes** | **≈ $5/mes en Twilio, ≈ $4 en Telnyx**; arranque $19,50 | cálculo |
| Alternativa: toll-free 8XX verificado | Verificación gratis (**dato por confirmar** en la página oficial) [152]; número $2,15/mes [153]; sin cuotas TCR; se ve menos local | [150][151] |
| Alternativa: AWS End User Messaging | $50 por activar campaña + $2/mes; más complejo | [156] |

**Requisito que manda el calendario:** desde el 30-jun-2026 toda campaña nueva
exige **URL pública de Política de Privacidad y de Términos y Condiciones**; sin
las dos se rechaza [143] (toll-free igual desde el 15-sep-2026 [150]). La
política actual del repo (`docs/PRIVACY-POLICY.md`, 16-oct-2026) dice que la app
no tiene usuarios consumidores y no menciona SMS; los Términos no existen. Hay
que redactarlos y publicarlos **antes** de registrar. Plazo total realista hasta
el primer SMS: **2–4 semanas** desde que entregas los papeles [141][144].

**Español:** con acentos o ñ el segmento baja de 160 a 70 caracteres (cada aviso
puede costar 2 segmentos): plantillas cortas o sin acentos. Twilio reconoce
STOP/HELP en inglés por defecto; **ALTO/AYUDA** se configuran en Advanced Opt-Out
[168]. Desde el 11-abr-2025 el cliente puede darse de baja «por cualquier medio
razonable» y hay que procesarla en 10 días hábiles [167]: la app guarda cada
consentimiento y cada baja con fecha, texto mostrado y origen [169].

**Recomendación: Twilio** (documentación, consola clara para que veas los
mensajes, opt-out en español). Telnyx es igual de válido y ahorra ~$1/mes [171].
**WhatsApp Business API queda para una fase 2**, solo si una parte importante de
tus clientes lo prefiere: exige verificación en Meta [157], plantillas aprobadas
una a una, número dedicado, y desde el 1-oct-2026 las respuestas de servicio ya no
son gratis (1.000/mes por número, luego $0,0034) [158]; el marketing a números de
EE. UU. está pausado por Meta desde abril de 2025 [159].

### 5.4 Correo transaccional

| Servicio | Gratis | Entrada | Fuente |
|---|---|---|---|
| **Resend** | 3.000/mes, tope 100/día | Pro $20/mes = 50.000 | [160] |
| Postmark | 100/mes | $15/mes = 10.000 | [161] |
| Amazon SES | Sandbox (solo destinatarios verificados) hasta pedir salida | $0,10 por 1.000 | [162] |
| SendGrid | Solo prueba 60 días | Essentials $19,95 = 50.000 | [163] |

**Resend ya es nuestro proveedor** (`correo` lo usa): no hay cuenta nueva, y se
llama con `fetch` desde Deno, sin SDK. ▶ Entrar al panel de Resend y confirmar
que **mxpes.com** —o el subdominio `avisos.mxpes.com` que proponemos— está
verificado con DKIM y SPF (el SPF se añade al registro que ya existe, no se crea
otro: dos SPF = fallo), y añadir DMARC en `p=none`. Gmail y Yahoo mandan a spam
sin SPF/DKIM [164]. El tope gratis de 3.000/mes y 100/día incluye lo que `correo`
ya manda; si los recordatorios lo acercan al tope, Pro $20/mes. Consejo: enviar
desde un subdominio (`avisos.mxpes.com`, remitente `facturas@avisos.mxpes.com`,
Reply-To `info@mxpes.com`) para no tocar el buzón actual.

### 5.5 Lo que hay que construir

1. Tabla de consentimientos (teléfono, fecha, texto exacto, origen, estado) ligada
   al cliente; casilla sin marcar en propuestas, contratos y portal.
2. Edge Function nueva `supabase/functions/mensajero/` (de Contabilidad, como
   `plaid/`; se añade la fila en PUBLICAR.md y en CONTA-PLAN §2) que lea una cola de
   avisos salientes (tipo, canal, destinatario, plantilla, estado) y llame a
   Twilio y a Resend, guardando ids y estados de entrega; webhook de Twilio para
   STOP/HELP.
3. Plantillas cortas, con «Max Power Electrical:» al frente y STOP al final en
   los recordatorios. A **clientes, solo en inglés** (regla del 30-oct, CONTA-PLAN
   §1 «Idioma»); al equipo y a los subs, en el idioma de cada uno.
4. Páginas públicas de Privacidad (actualizada: comunicaciones por SMS/correo; los
   datos móviles no se comparten para marketing) y Términos (nuevos).
5. Para tu push: los triggers y la ronda de c8 llaman a `fn_cartero` (f08);
   `fn_cartero` y `notificar` no se tocan.

### 5.6 ▶ Lo que tienes que sacar, en orden

| # | Qué | Para qué | Costo | Plazo |
|---|---|---|---|---|
| 1 | Carta del IRS con el EIN (CP 575, o pedir la 147C) y confirmar el **nombre legal exacto** y dirección (Twilio pide el nombre tal como está en la CP 575, no en el W-9) [142] | Brand 10DLC, toll-free, Stripe, Meta | $0 | 147C por teléfono: 1–2 semanas por correo |
| 2 | Decidir la **URL pública del negocio** donde cuelguen Privacidad, Términos y el texto de consentimiento (opt-in) (si no hay web, una página mínima) | Campaña 10DLC, Stripe | $0 | 1–2 días de trabajo técnico |
| 3 | Aprobar la **Política de Privacidad actualizada** y los **Términos** (los redactamos; tú firmas como dueño) | Obligatorio desde jun/sep-2026 | $0 | Mismo día |
| 4 | Abrir cuenta en **Twilio** con tarjeta de la empresa; comprar número local 352 | SMS | $1,15/mes + saldo ~$20 | 10 minutos |
| 5 | Registrar **Brand Low-Volume Standard** (nombre legal, EIN, dirección, web, representante: tú, cargo, info@mxpes.com, teléfono) y contestar el código en < 24 h | SMS | $4,50 | Minutos a 7+ días hábiles |
| 6 | Registrar **campaña Low Volume Mixed** (mensajes de ejemplo, cómo se da el consentimiento, URLs de Privacidad y Términos) | SMS | $15 + $1,50/mes | 5–10 días (hasta 2–3 semanas) |
| 6b | (Plan B o en paralelo) **Verificación toll-free** con los mismos datos | SMS | $0 (**dato por confirmar**) + $2,15/mes | 3–5 días a 2–4 semanas |
| 7 | Acceso al **DNS de mxpes.com** para SPF, DKIM y DMARC; comprobar en **Resend** (ya es el de `correo`) el dominio y los registros | Correo | $0 | Horas |
| 8 | Firmar el **texto de consentimiento** que irá en presupuestos, contratos y portal, y la regla de «sin promociones en los avisos» | TCPA/CTIA | $0 | Mismo día |
| 9 | (Fase 2, solo si lo pides) Meta Business Portfolio y verificación de empresa; número dedicado para WhatsApp | WhatsApp | $0 + $0,0034/msg + recargo del proveedor | 2–14 días |

**Costo total:** ~$19,50 una vez; ≈ $5/mes a 200 SMS; correo $0; push $0.

---

## 6. Lo que QuickBooks hace y nosotros no vamos a hacer (y por qué)

| Qué | Por qué no | Quién lo hace |
|---|---|---|
| **Calcular y presentar impuestos de nómina** (941, 940, W-2, RT-6, depósitos en EFTPS) | Decisión del plan (§1, f11): si retienes y no depositas a tiempo la multa te la cobran a ti personalmente; ningún ahorro de software vale eso | Gusto. Los W-2 y el 941 del Q4-2026 los emite el proveedor viejo: no cortar ese acceso hasta tenerlos |
| **Depósito directo de nómina** desde la app | Es parte de la nómina: vive en Gusto (W-4 y banco de cada empleado antes del 11-dic, f06) | Gusto |
| **Presentar el sales tax** | QuickBooks tampoco lo hace (e-file retirado en 2020) [123]. El DR-15 se llena a mano en floridarevenue.com con la vista de f08 | Tú, con la vista |
| **Cobrar sales tax en la factura** | Si contratas como mejora a bien inmueble (Regla 12A-1.051) el impuesto lo pagas al proveedor y es costo de 5100; no se cobra al cliente [124]. Solo cambia si el CPA dice «retail + instalación» (materiales con precio propio) | ▶ Confirmar con el CPA |
| **E-file del 1099 de 2026 desde la app** | Es el libro de QuickBooks ese año; sale de ahí antes del 1-feb-2027 (f12a) | QuickBooks |
| **Inventario perpetuo, multi-empresa, multi-moneda** | Explícito en el plan (§6b): un contratista con bodega simple (1300) | — |
| **QuickBooks Checking / Money / sobres al 3 %** | No se cambia de banco: Chase ya está conectado y la reserva de impuestos va en 1030 con transferencia semanal fija (f08) | Chase |
| **Plaid Transfer, Melio para cobrar, PayPal/Venmo como principal, Chase QuickAccept, QuickBooks Money como puente** | §2: contrato anual, sin aviso de pago, caro, sin API, atado a QuickBooks | Stripe + Zelle |
| **Pagar a subs desde Stripe Connect o una cuenta Mercury** | Hoy no: fondear tarda 5–6 días o exige segunda cuenta. Reevaluar en 2027 | Chase ACH |
| **WhatsApp** | Fase 2, solo si tus clientes lo piden; SMS llega a todos sin app | — |
| **Push a clientes** | Tendrían que instalar el portal; correo + SMS llega igual | — |
| **IA que postea sola, categorización de noche** | «Propone, nunca postea»; «cita o se calla»; tope mensual; no se dispara de noche (§4). Es lo que hace compatible IA con 100 % auditable | Tú apruebas en la bandeja |
| **Contador de día a día / Live Bookkeeping** (~$300–700/mes en Intuit, terceros) | Se elimina: tú cierras el mes; el CPA una vez al año con el paquete de f17 | Tú + CPA |
| **Certified payroll WH-347 / prevailing wage** | Solo obra pública; QuickBooks tampoco lo trae [104] | — salvo que cambie el tipo de obra |
| **Millaje automático, GPS de cuadrilla** | No es contabilidad; la deducción de vehículo es columna del CPA en f17. Si lo quieres, es decisión aparte | ▶ Decidir |
| **Préstamos de QuickBooks Capital** | No investigado; no es parte del libro | — |

---

## 7. Orden propuesto

**Principio:** lo que depende de un trámite tuyo arranca **esta semana**, porque
los plazos externos (Stripe 7–14 días al primer depósito y límites que suben con
historial; campaña SMS 2–4 semanas; Gusto) son más largos que lo que tardamos en
construir. Lo que no depende de nadie sigue el calendario de las fases.

### 7.1 ▶ Trámites que arrancas ya (sin esperar código)

| # | Trámite | Para qué | Costo | Plazo | Bloquea |
|---|---|---|---|---|---|
| 1 | Las pendientes de f07: dictar las reglas de los 35 comercios de Chase (y luego las de las Amex); llave nueva de Anthropic para `contador`; confirmar el plan de Supabase (respaldos) | La fase actual | $0 | Esta semana | f07, f08 |
| 2 | ✅ **Stripe abierto el 26-oct** (verificado; tarjetas y ACH activos; depósitos a la operativa). Falta: 2–3 cobros reales chicos en noviembre | Cobrar desde el 2 de enero con límites de ACH ya subidos | $0 fijo | Alta el mismo día; depósito 7–14 días | f10 (enlace en la factura) |
| 3 | **Carta EIN**, nombre legal exacto, URL pública, firmar Privacidad y Términos | SMS y Stripe | $0 | 1–2 semanas (147C si no tienes la CP 575) | Campaña 10DLC |
| 4 | **Twilio**: cuenta, número 352, Brand y campaña | SMS a clientes | $19,50 + ~$5/mes | 2–4 semanas tras el punto 3 | Recordatorios por SMS |
| 5 | **Resend** (ya es el de `correo`): comprobar el dominio y los registros + DNS de mxpes.com (SPF, DKIM, DMARC, subdominio) | Factura y recordatorios por correo desde la app | $0 | Horas | f10 (envío) |
| 6 | **Chase**: activar ACH Payment Services, preguntar límite diario, carga NACHA y descriptor; inscribir Zelle for Business | Pagar y cobrar sin comisión | $0 | Una llamada | Pagos salientes (febrero) |
| 7 | ✅ **Gusto contratado el 26-oct** (Simple, cada dos semanas, primera nómina 8-ene-2027). Falta: empleados con W-4 y banco antes del 11-dic; export del diario | f11 | $49 + $6/persona (terceros) | Semanas | f11 |
| 8 | **CPA**, una sola llamada con ocho preguntas: **¿se presentó el 2553 de la Inc. nueva?** (el IRS la tiene como C-corp, formulario 1120; si no, elección tardía con efecto desde la constitución); **cómo quedan en 2026 los ayudantes pagados por Zelle sin nómina**; Regla 12A-1.051 (sales tax); recargo 3 % en crédito o descuento por ACH; ¿el 1120-S va por caja o devengo?; qué ayudante por hora es empleado y no sub (F.S. 440.10) y si el que nombra f12a cobra por W-2 o 1099; el método libro de depreciación (f08/f12); el % de la utilidad para la reserva 1030 y el pago estimado del 15-ene-2027 (f06) | f06, f08, f10, f12a, f17 | $0–consulta | Antes del 16-nov | f10 |
| 9 | **W-9 y COI de cada sub** | f12a y el freno de pagos | $0 | Para la semana 10 | f12a |
| 10 | IRIS: pedir el TCC | 1099 de 2027 en enero de 2028 | $0 | Con calma, en 2027 | Nada antes de 2028 |

### 7.2 Lo que construimos, semana a semana

| Semana | Fase del plan | Lo nuevo de este documento que entra ahí |
|---|---|---|
| 26 oct–1 nov | **f07** Categorización y bandeja | Nada nuevo. Es la fase actual |
| 2–8 nov | **f08** Cierre de octubre, ronda, activos | Triggers y ronda de c8 que llaman a `fn_cartero` (push a ti: pago recibido, factura vencida, lote por aprobar); `fn_cartero` y `notificar` no se tocan. Costo cero |
| 9–15 nov | **f09** Costo por obra y burden | Nada nuevo |
| 16–22 nov | **f10** WIP, retención, factura | **El cobro en línea**: Edge Function `cobros/` que crea el enlace de Stripe al emitir y recibe el webhook; en c10 la función puente `fn_stripe_recibir` (fuera de la API, patrón de `fn_plaid_recibir`) que llama a `fn_cobro_registrar` / `fn_cobro_devolver` en nombre del dueño, la tabla de eventos para la idempotencia, la cuenta puente «Procesador de pagos — en tránsito», la clave `procesador` (STRIPE) en `banco_descriptores` (requiere ampliar su CHECK en c10) y la función que casa el payout con sus cobros; bloque «Cómo pagar» con QR y Zelle en el PDF. Envío por `correo` con Resend. Se prueba con el CLI de Stripe en modo test aunque la cuenta real esté en revisión |
| 23–29 nov | **f12a** W-9, COI, 1099 | **Alta del beneficiario**: W-9 + autorización de depósito en Storage privado; freno «sin W-9/COI no se paga» |
| 30 nov–6 dic | **f11** Nómina (Gusto) | Nada nuevo |
| 7–13 dic | **f12b + colchón** | **Mensajero**: cola de avisos, Resend (correo) y Twilio (SMS, si la campaña ya está aprobada), consentimientos, recordatorios de cobro con cadencia, estado de cuenta mensual. Si el colchón se come, los SMS pasan a enero: con push + correo se llega al corte |
| 14–27 dic | **Paralelo** | Facturas nuevas con enlace Stripe + Zelle; clientes con tarjeta guardada en QuickBooks reciben el enlace para volver a autorizar; QuickBooks Payments sigue para las facturas viejas |
| 28 dic–3 ene | **f15** Amarre | `qb` se apaga; la casilla `pagada` se retira; el 2 de enero se factura y se cobra desde la app |
| Enero 2027 | Cierre de diciembre; 1099 de 2026 desde QuickBooks | Nada nuevo: enero queda como lo deja el plan (arranque en vivo, cierre de diciembre, 1099 y W-2; f16). Solo trámite: cancelar QuickBooks Payments tras la última factura vieja cobrada (~31-ene) |
| Febrero | **f16** Contador de guardia | **Pagos salientes**: orden de pago, lote NACHA, casado por Plaid (o en marzo con f18). Recordatorios y estados de cuenta en la conversación del contador; rol `contador` para el CPA si lo decides |
| Marzo | **f17, f18** | SOV AIA, catálogo, paquete del GC, flujo de caja proyectado; cobros recurrentes con mandato ACH; reevaluar pagar a subs desde el saldo de Stripe; lien waivers; WhatsApp si lo piden |
| Abril | Ajustes del CPA → cancelar QuickBooks | Antes, exportar P&L y balance por mes de 2025–2026 |

### 7.3 Por qué este orden

- **Stripe primero y en noviembre** porque es lo único que no puede faltar el 2 de
  enero (la factura necesita un «cómo pagar» que no sea QuickBooks) y porque los
  límites de débito y la demora del primer depósito solo se curan con tiempo.
- **Los SMS después** porque el cuello de botella es externo (Privacidad, Términos,
  registro de 2–4 semanas) y porque el push a ti y el correo al cliente ya cubren
  el corte. Pero el trámite arranca ya, para que enero no empiece sin ellos.
- **Los pagos salientes después de enero** (febrero con f16, o marzo con f18)
  porque el libro ya registra y casa lo que Chase paga, el lote NACHA es
  comodidad y no requisito del corte, y enero está reservado al arranque en vivo
  (f16). Lo que sí entra antes es la parte de papeles (W-9, autorización,
  freno), porque f12a ya la trae.
- **El módulo de construcción sigue su calendario** (f09, f10, f18): es lo que
  justifica el proyecto y donde le ganamos a QuickBooks; no se le quita una
  semana para meter lo demás.

---

## Fuentes

Cobrar (Stripe):
1. https://stripe.com/pricing
2. https://stripe.com/payments/us-bank-payments
3. https://docs.stripe.com/payments/ach-direct-debit
4. https://support.stripe.com/questions/stripe-invoicing-pricing
5. https://support.stripe.com/questions/manually-entered-card-payments
6. https://support.stripe.com/questions/two-day-settlement-for-ach-direct-debit
7. https://support.stripe.com/questions/june-2024-pricing-update-for-instant-payouts-for-businesses-in-the-united-states
8. https://support.stripe.com/questions/bank-debits-transaction-size-and-weekly-volume-limits
9. https://support.stripe.com/questions/business-rep-owner-tax-id-requirements-for-us-companies
10. https://support.stripe.com/questions/do-i-have-to-have-a-business-website-to-sign-up-for-stripe
11. https://stripe.com/pricing/local-payment-methods
12. https://docs.stripe.com/webhooks
13. https://docs.stripe.com/reports/payout-reconciliation
14. https://docs.stripe.com/bank-reconciliation
15. https://supabase.com/docs/guides/functions/examples/stripe-webhooks
16. https://stripe.com/legal/ACH
17. https://www.whatpayment.com/en/guides/stripe-payout-schedule/
18. https://stripe.com/legal/restricted-businesses

Cobrar (Square, Melio, Plaid, PayPal, QuickBooks Payments, Chase, Florida):
19. https://squareup.com/us/en/payments/our-fees
20. https://developer.squareup.com/docs/payments-pricing
21. https://developer.squareup.com/docs/invoices-api/overview
22. https://squareup.com/help/us/en/article/3807-deposit-options-with-square
23. https://squareup.com/help/us/en/article/7399-accept-ach-invoice-payments
24. https://checkoutpage.com/blog/square-fees
25. https://fitsmallbusiness.com/square-invoice-review/
26. https://www.forbes.com/advisor/business/software/square-invoices-review/
27. https://meliopayments.com/pricing/
28. https://melio.com/api/
29. https://help.melio.com/hc/en-us/articles/4447358208018-When-will-my-payment-arrive
30. https://meliopayments.com/1099-and-w9-management/
31. https://meliopayments.com/business-expenses/contractors-and-freelancers/
32. https://meliopayments.com/partners/
33. https://melio.com/xero-melio-faq/
34. https://plaid.com/docs/account/billing/
35. https://plaid.com/docs/transfer/application/
36. https://plaid.com/docs/transfer/flow-of-funds/
37. https://plaid.com/docs/transfer/platform-payments/
38. https://plaid.com/docs/transactions/webhooks/
39. https://www.paypal.com/us/business/paypal-business-fees
40. https://www.paypal.com/us/cshelp/article/new-paypal-account-%E2%80%93-payments-on-hold-and-accessing-your-money-quicker-help848
41. https://developer.paypal.com/api/rest/webhooks/event-names
42. https://wealthvieu.com/banking/venmo/business-account/
43. https://quickbooks.intuit.com/payments/payment-rates
44. https://quickbooks.intuit.com/learn-support/en-us/help-article/receive-payments/find-quickbooks-payments-deposits-customer/L80Fh7CSV_US_en_US
45. https://quickbooks.intuit.com/learn-support/en-us/banking/the-bank-transfer-fee-says-it-s-1-max-10-per-transaction-does/00/1322307
46. https://quickbooks.intuit.com/community/banking-4/why-am-i-paying-1-unlimited-for-ach-transactions-when-it-used-to-be-10-dollars-capped-when-and-why-did-this-policy-change-22832
47. https://quickbooks.intuit.com/money/see-plans/
48. https://quickbooks.intuit.com/learn-support/en-us/help-article/money-movement/learn-common-call-drivers-quickbooks-money/L4QXvAmPh_US_en_US
49. https://quickbooks.intuit.com/learn-support/en-us/payments/if-i-cancel-my-quickbooks-subscription-in-order-to-start-new/00/538065
50. https://quickbooks.intuit.com/learn-support/en-us/help-article/set-payments/connect-quickbooks-payments-account-quickbooks/L8JhK7FBX_US_en_US
51. https://developer.intuit.com/app/developer/qbpayments/docs/learn/explore-the-quickbooks-payments-api
52. https://help.developer.intuit.com/s/question/0D54R00007MnHdGSAV/what-webhook-can-i-use-to-detect-failed-echecks-for-quickbooks-payments-api
53. https://help.noviams.com/articles/3375624890-how-to-remove-the-quickbooks-view-and-pay-button-from-invoices
54. https://www.givepayments.com/blog/quickbooks-payments-fees-2026/
55. https://quickbooks.intuit.com/learn-support/en-us/help-articles/instant-deposit-faqs/00/366788
56. https://peakadvisers.com/blog/quickbooks-new-25-ach-convenience-fee-explained/
57. https://www.chase.com/business/banking/services/collect-and-deposit
58. https://www.chase.com/business/support/banking/online-banking/zelle
59. https://www.chase.com/business/payments/invoicing
60. https://www.chase.com/business/payments
61. https://www.chase.com/business/payments/quickaccept
62. https://www.chase.com/business/banking/services/ach
63. https://www.chase.com/content/dam/chaseonline/en/demos/cbo/pdfs/cbo_nacha_filespecs.pdf
64. https://www.chase.com/content/dam/chaseonline/en/demos/cbo/pdfs/cbo_achfile_helpguide.pdf
65. https://chase.com/content/dam/chase-ux/documents/commercial-banking/chase-connect/cc_quickguide_third_party.pdf
66. https://www.nickel.com/bank-transfer-limits/chase
67. https://zellepay.com/faq/using-zelle
68. https://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0500-0599%2F0501%2FSections%2F0501.0117.html
69. https://merchantcostconsulting.com/lower-credit-card-processing-fees/florida-surcharge-laws/

Pagar (Contractor Payments, Gusto, BILL, Stripe Connect, Routable, Mercury, Relay, Nacha, IRS):
70. https://quickbooks.intuit.com/payroll/contractor-payments/
71. https://support.gusto.com/article/106621945100000/View-Gusto-s-plans-and-pricing-or-change-your-plan
72. https://gusto.com/product/payroll/efile-1099
73. https://support.gusto.com/article/999752211000000/direct-deposit-payment-speeds-in-gusto
74. https://docs.gusto.com/app-integrations/docs/introduction
75. https://casrai.org/guides/gusto-pricing
76. https://www.bill.com/product/pricing/
77. https://help.bill.com/direct/s/article/115005322726
78. https://developer.bill.com/v3/docs
79. https://stripe.com/connect/pricing
80. https://docs.stripe.com/connect/top-ups
81. https://stripe.com/connect/1099
82. https://www.routable.com/pricing/
83. https://mercury.com/api
84. https://docs.mercury.com/docs/send-money
85. https://relayfi.com/hc/en-us/articles/4402730597396-Sending-a-same-day-ACH/
86. https://www.nacha.org/rules/funds-availability-requirements-non-same-day-credit-entries
87. https://www.nacha.org/million
88. https://www.irs.gov/publications/p1099
89. https://www.irs.gov/instructions/i1099mec
90. https://www.tax1099.com/1099-deadline
91. https://www.tax1099.com/tax-1099-efile-pricing
92. https://www.greenbacktaxservices.com/blog/irs-fire-system/
93. https://go.meliopayments.com/instant-payments

QuickBooks Online (planes, herramientas, apps aparte):
94. https://www.lilachbullock.com/quickbooks-pricing/
95. https://www.certumsolutions.com/library/quickbooks-price-increase-august-2026
96. https://quickbooks.intuit.com/learn-support/en-us/help-article/intuit-subscriptions/learn-usage-limits-quickbooks-online/L6THMltE4_US_en_US
97. https://quickbooks.intuit.com/learn-support/en-us/help-article/regular-payroll/track-hourly-labor-costs-profitability-project/L9ZxBA4sn_US_en_US
98. https://quickbooks.intuit.com/community/other-questions-9/quickbooks-online-projects-80497
99. https://www.simprogroup.com/blog/quickbooks-job-costing-contractors
100. https://planyard.com/blog/can-quickbooks-online-do-construction-job-costing
101. https://quickbooks.intuit.com/r/product-update/whats-new-quickbooks-advanced-august-2026/
102. https://insightfulaccountant.com/accounting-tech/general-ledger/qbo-advanced-now-includes-construction-financial-capabilities/
103. https://clarionops.com/blog/quickbooks-construction-edition-do-you-still-need-a-separate-tool
104. https://constructioncoverage.com/software/accounting/quickbooks-for-contractors
105. https://quickbooks.intuit.com/estimates/
106. https://blog.insightfulaccountant.com/request-and-accept-deposits-on-estimates-in-quickbooks-online
107. https://www.nerdwallet.com/article/small-business/quickbooks-progress-invoicing
108. https://www.levelset.com/blog/recording-tracking-retainage-receivable-quickbooks-for-contractors/
109. https://get.clockit.io/reviews/quickbooks-time
110. https://quickbooks.intuit.com/time-tracking/geofencing/
111. https://quickbooks.intuit.com/learn-support/en-us/help-article/accounts-payable/email-receipts-bills-quickbooks-online/L7r2LAQ7C_US_en_US
112. https://kaufmanrossin.com/blog/quickbooks-online-tip-save-time-by-setting-up-rules-for-bank-feeds/
113. https://quickbooks.intuit.com/learn-support/en-us/help-article/invoicing/send-invoice-reminders-automatically-manually/L84cQjpxo_US_en_US
114. https://www.paidnice.com/blog/quickbooks-online-automatic-invoice-reminders
115. https://quickbooks.intuit.com/accounting/invoicing/
116. https://blog.insightfulaccountant.com/whats-new-in-qbo-invoices-via-text-message
117. https://quickbooks.intuit.com/learn-support/en-us/help-article/recurring-transactions/create-recurring-transactions-quickbooks-online/L3WoKX2R8_US_en_US
118. https://quickbooks.intuit.com/bill-pay/
119. https://fitsmallbusiness.com/quickbooks-bill-pay-review/
120. https://quickbooks.intuit.com/payroll/1099-efile/
121. https://fitsmallbusiness.com/quickbooks-payroll-core-vs-premium-vs-elite/
122. https://gusto.com/resources/guides/switch-payroll-providers/quickbooks-pricing
123. https://insightfulaccountant.com/accounting-tech/general-ledger/quickbooks-online-sales-tax-e-file-discontinued
124. https://www.law.cornell.edu/regulations/florida/Fla-Admin-Code-Ann-R-12A-1-051
125. https://floridarevenue.com/taxes/tips/documents/TIP_03A01-21.pdf
126. https://quickbooks.intuit.com/accounting/mileage/
127. https://www.irs.gov/newsroom/irs-sets-2026-business-standard-mileage-rate-at-725-cents-per-mile-up-25-cents
128. https://quickbooks.intuit.com/learn-support/global/reports/reports-included-in-your-quickbooks-online-subscription/00/381496
129. https://quickbooks.intuit.com/learn-support/en-us/help-articles/learn-about-the-audit-log/00/238833
130. https://knowify.com/pricing/
131. https://buildertrendpricing.com/
132. https://www.getjobber.com/pricing/
133. https://www.housecallpro.com/pricing/
134. https://www.certumsolutions.com/library/intuit-enterprise-suite-construction-edition-guide
135. https://quickbooks.intuit.com/business-banking/checking/
136. https://www.nerdwallet.com/business/banking/reviews/quickbooks-money
137. https://quickbooks.intuit.com/learn-support/en-us/set-up-users/user-types-in-quickbooks-online/01/186238
138. https://quickbooks.intuit.com/accounting/advanced-features/
139. https://quickbooks.intuit.com/learn-support/en-us/help-article/small-business-processes/quickbooks-online-app-overview/L4ejdjaRY_US_en_US

Avisos (SMS, WhatsApp, correo, push, consentimiento):
140. https://support.twilio.com/hc/en-us/articles/14910496447771-Shutdown-of-Unregistered-10DLC-Messaging
141. https://www.twilio.com/docs/messaging/compliance/a2p-10dlc/direct-standard-onboarding
142. https://www.twilio.com/docs/messaging/compliance/a2p-10dlc/collect-business-info
143. https://www.twilio.com/en-us/changelog/a2p-10dlc-campaign-registration-will-require-privacy-policy-and-
144. https://help.twilio.com/articles/26149060902555
145. https://www.telphiconsulting.com/blog/twilio-a2p-10dlc-cost
146. https://tuco.ai/a2p-10dlc
147. https://www.twilio.com/en-us/blog/new-requirements-for-a2p-10dlc-registrations
148. https://telnyx.com/resources/what-is-10dlc
149. https://developers.telnyx.com/docs/messaging/10dlc/10dlc-rate-limits
150. https://help.twilio.com/articles/13264118705051
151. https://signalmash.com/post/toll-free-verification-guide
152. https://help.gladly.com/docs/toll-free-number-verification-and-a2p-10dlc-registration-process
153. https://textbee.dev/blog/twilio-pricing-real-cost-breakdown
154. https://apidog.com/blog/twilio-sms-api-cost/
155. https://apidog.com/blog/plivo-sms-api-cost/
156. https://apibenchmarks.com/sms/aws-end-user-messaging-sns
157. https://docs.360dialog.com/docs/resources/meta-business-verification
158. https://www.dragapp.com/blog/whatsapp-business-api-pricing/
159. https://www.wati.io/en/blog/whatsapp-marketing-messages-us-2026/
160. https://automationatlas.io/answers/resend-pricing-explained-2026/
161. https://markrelay.com/research/site.postmarkapp.com-pricing
162. https://www.mailblast.io/blog/ses/amazon-ses-pricing
163. https://www.saaspricepulse.com/tools/sendgrid
164. https://generate.folderly.com/blog/gmail-yahoo-outlook-sender-requirements-2026
165. https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados
166. https://www.wipfli.com/insights/articles/tcpa-informational-text-messages-rules-and-requirements
167. https://manatt.com/insights/newsletters/tcpa-connect/fcc%e2%80%99s-revocation-rule-to-take-effect-april-2025
168. https://www.twilio.com/docs/messaging/tutorials/advanced-opt-out
169. https://www.idtexpress.com/blog/tcpa-compliance-for-sms-in-2026-the-complete-guide-for-us-businesses/
170. https://www.twilio.com/docs/messaging/compliance/a2p-10dlc/direct-sole-proprietor-registration-overview
171. https://bluereacher.com/compare/twilio-vs-telnyx

Archivos del repo en los que se apoya este documento (sin web): `docs/CONTA-PLAN.md`
(§1–3, §6–9); `docs/conta/fases/f06-banco.md`, `f07-categorizacion.md`,
`f08-cierre.md`, `f09-costo-por-obra.md`, `f10-facturacion-wip.md`, `f11-nomina.md`,
`f12-apertura-1099.md`, `f15-amarre.md`, `f16-contador-de-guardia.md`,
`f17-paquete-fiscal.md`, `f18-obra-flujo-caja.md`; `docs/conta/c1-plan-de-cuentas.sql`,
`c3-puentes.sql`, `c4-estados.sql`, `c6-banco.sql` (medios de `fn_banco_cobrar`,
`fn_banco_casar_con {cobro, comision}`, claves de `banco_descriptores`),
`c7-plaid.sql`; `docs/conta/f10-factura-vista-previa.html`; `docs/conta/ESQUEMA-REAL.md`;
`docs/PRIVACY-POLICY.md`; `docs/PUBLICAR.md`; `supabase/functions/notificar/index.ts`;
`supabase/functions/plaid/index.ts`; `docs/sql/e37-seguridad.sql` (`fn_cartero`);
`js/db.js` (`pedirCorreo`, RESEND_API_KEY); `docs/conta/fases/f05-pantalla.md`;
`sw.js`; `manifest.webmanifest`.
