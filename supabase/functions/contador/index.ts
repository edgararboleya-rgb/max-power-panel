// ============================================================
// CONTADOR — la IA que propone y nunca postea (c8, fase 7): la ráfaga que
// clasifica los cargos «sin ticket» de la bandeja del banco, y lo que Edgar
// aprueba («Así es»), corrige («Según yo») o rechaza («No es eso»)
//
// Dónde se pega (2 minutos):
//   Supabase → Edge Functions → Deploy a new function → «Via Editor» →
//   nombre «contador» → borrar el ejemplo y pegar este archivo entero →
//   Deploy, con «Verify JWT» («Enforce JWT verification») APAGADO, como
//   stripe, plaid y notificar: la función comprueba la sesión ella misma
//   (dueño activo y código del teléfono, aal2) y así ?paso=salud contesta
//   sin sesión qué falta.
//
// ANTES de desplegar, en Edge Functions → Secrets tiene que existir:
//   ANTHROPIC_API_KEY   una llave NUEVA de console.anthropic.com, solo para
//                       el contador (aparte de la del asistente: así el gasto
//                       contable se ve por separado). sk-ant-…
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY y SUPABASE_DB_URL los pone
//   Supabase solo. Sin la llave, todo lo que no gasta (estado, aprobar,
//   clasificar, rechazar, las reglas) sigue funcionando; «proponer» aplica
//   las reglas y para con CONFIG antes de pedirle nada a Anthropic.
//   NUNCA MXP_BANCO_PRUEBAS, MXP_DB_URL ni ANTHROPIC_BASE_URL: son del banco
//   de pruebas (abajo), y con ellos la función contesta 500 CONFIG.
//
// Qué hace: es la ÚNICA que habla con Anthropic (la llave no sale de aquí)
// y la ÚNICA puerta de la app a las fn_contador_* de c8-contador.sql.
//   · PROPONER (la ráfaga, «Proponer con la IA» en la Bandeja):
//       1. fn_contador_reglas_aplicar: lo que casa con una regla de Edgar
//          ya queda propuesto, gratis (Postgres contesta; la IA no se entera).
//       2. fn_contador_tope: con el tope del mes gastado (el de la app o el
//          del contador) o el contador apagado → {bloqueado: true, motivo},
//          sin gastar un token.
//       3. fn_contador_pendientes: los cargos que esperan (hasta el límite,
//          nunca más que max_por_rafaga) y el contexto: las cuentas
//          permitidas, las obras activas, las reglas y los últimos ejemplos
//          de Edgar.
//       4. fn_contador_lote_abrir, y la ráfaga a Anthropic: la PRIMERA
//          llamada sola (crea el caché del prefijo) y las demás de tres en
//          tres (leen el caché). Cada respuesta válida →
//          fn_contador_propuesta_guardar (la base la valida: si no pasa, no
//          se guarda y se cuenta «inválida»).
//       5. fn_contador_lote_cerrar con el uso sumado (tokens de entrada,
//          salida, caché creado y leído): la base calcula los centavos y los
//          anota en el gasto del mes.
//     Lo que la IA ve: UN prefijo fijo (las instrucciones + el plan de
//     cuentas permitido + las obras activas + las reglas + los ejemplos,
//     todo ordenado, sin fechas ni ids de ráfaga) con cache_control, y el
//     movimiento en el mensaje (fecha, monto, descripción, nota, cuenta del
//     banco, tipo: la base ya lo deja sin correos, teléfonos ni números de
//     cuenta). La respuesta viene forzada al esquema PROPUESTA_SCHEMA
//     (structured outputs). Modelo y esfuerzo los dice ia_config
//     (claude-opus-5-5, effort low): solo Opus y Fable, nunca Haiku ni
//     Sonnet, y NUNCA se cambia de modelo por una negativa (stop_reason
//     «refusal» = sin respuesta: se cuenta y no se guarda; sin fallbacks).
//     Un corte por max_tokens también es «sin respuesta»; un JSON que no es
//     JSON, «inválida»; un 429, 529 o 5xx se reintenta UNA vez tras 2 s y
//     después es «sin respuesta». Un 401 (la llave no vale) o un 400 (la
//     petición) corta la ráfaga, cierra el lote con su error y contesta 502
//     diciéndolo en llano. Si la primera ráfaga real contestara 400
//     (ANTHROPIC_PETICION), lo primero a mirar es la petición misma: el
//     esquema (tipos ["number", "null"] y description, que structured
//     outputs admite) y la versión de la API (abajo): el simulador del banco
//     de pruebas exige la forma del contrato, pero no valida el esquema como
//     la API de verdad.
//     max_tokens va en 4096: con Opus 5.5 el pensamiento adaptativo está
//     siempre encendido y CUENTA contra max_tokens aunque no se devuelva (el
//     skill claude-api lo documenta como la trampa de la migración); con
//     1024 una propuesta de cinco líneas con motivo y alternativas podía
//     cortarse («max_tokens» = sin respuesta, cobrada y sin nada que
//     guardar, y el mismo cargo volvía a mandarse en cada ráfaga). 4096 es
//     margen, no gasto: solo se paga lo que se usa.
//     LA RÁFAGA TIENE RELOJ (PRESUPUESTO_RAFAGA_MS, 2 minutos, para terminar
//     siempre antes del límite de Supabase y cerrar su lote): entre grupos
//     no se arranca otro si se acabó (lo que quedó espera a la siguiente
//     ráfaga: «sin_intentar», una nota, no un error), y una llamada en vuelo
//     se corta al llegar el plazo, sin reintento («sin respuesta», con su
//     motivo). UNA SOLA RÁFAGA A LA VEZ: la base no abre un lote mientras
//     otro siga abierto hace menos de cinco minutos (fn_contador_lote_abrir
//     → MX008 «ya hay una ráfaga en marcha», que aquí sale como 409 en
//     llano: dos «Proponer» a la vez —dos pestañas, dos aparatos— pagarían
//     dos veces los mismos cargos); si una ráfaga anterior se cortó sin
//     cerrar, la base la da por perdida (con su error) al abrir la siguiente.
//   · APROBAR, CLASIFICAR, RECHAZAR, CADUCAR, REGLA_ALTA y REGLA_BAJA van
//     directo a su fn_contador_*: el ÚNICO camino al libro es
//     fn_contador_clasificar → fn_banco_clasificar (c6), EN NOMBRE DEL
//     DUEÑO (la base lo hace, como p1). Esta función no toca el libro.
//   · ESTADO: v_contador_estado, el tope y lo que el control tiene en rojo
//     (fn_contador_resumen). SALUD (sin sesión): qué falta, sin enseñar
//     nada; y el modelo, el esfuerzo, la versión del prompt y el tope. Se
//     pide por GET ?paso=salud (el contrato) y también por POST {accion:
//     "salud"} (así lo pide la pantalla): las dos contestan lo mismo y
//     ninguna enseña nada del libro.
//
// A la base entra DIRECTO, como postgres, por SUPABASE_DB_URL (MXP_DB_URL
// manda solo en el banco de pruebas), cada llamada en su transacción.
// Ninguna fn_contador_* está en la API (c8-contador.sql): solo esta función,
// pg_cron y el SQL Editor las ejecutan (fn_desde_editor).
//
// Lo que NO está en el repositorio: ninguna llave. Solo en el banco de
// pruebas (esBancoDePruebas: MXP_BANCO_PRUEBAS=1 Y la base en 127.0.0.1 por
// MXP_DB_URL Y sin SUPABASE_DB_URL Y fuera de Supabase; en Supabase nunca se
// cumple, y si alguien pone MXP_BANCO_PRUEBAS en Secrets la función contesta
// 500 CONFIG y no hace nada): la sesión se lee sin verificar la firma,
// ANTHROPIC_BASE_URL apunta al Anthropic simulado (pruebas/conta/contador-
// simulado.mjs), MXP_PUERTO sirve en 127.0.0.1 y la base se puede inyectar
// (usarBaseDePruebas), y MXP_PRESUPUESTO_MS acorta el reloj de la ráfaga
// para probar el corte sin esperar dos minutos. El archivo también corre en
// Node 22 (las pruebas sin Deno, pruebas/conta/contador-e2e.mjs): por eso
// lee el entorno con env(), llama a Anthropic con fetch (sin el SDK) y carga
// npm:postgres y supabase-js dentro de abrirBase, solo en Deno.
// ============================================================

type Json = Record<string, unknown>;

// deno-lint-ignore no-explicit-any
const G = globalThis as any;
function env(k: string): string {
  const v = G.Deno?.env?.get?.(k) ?? G.process?.env?.[k];
  return typeof v === "string" ? v : "";
}

// La versión de la API de Anthropic que se manda en cada petición (la del
// contrato de la fase 7). La más nueva, 2026-10-21, solo cambia lo que esta
// función no usa (temperature, top_p, top_k, documentos en turnos del
// asistente): la petición de aquí es idéntica en las dos. (Si una ráfaga
// real contestara 400, mirar primero el esquema y esta constante: el
// simulador no valida como la API.)
const ANTHROPIC_VERSION = "2023-06-01";
// Lo que se le deja escribir. El JSON de una propuesta son unas decenas o
// cientos de tokens, pero con Opus 5.5 el pensamiento adaptativo va siempre
// encendido y cuenta contra max_tokens aunque no se devuelva: con 1024 una
// propuesta de cinco líneas con motivo y alternativas podía cortarse
// («max_tokens» = sin respuesta, cobrada y sin nada que guardar). 4096 es
// margen, no gasto: solo se paga lo que se usa. Si aun así se cortara, se
// sube aquí (el simulador y el e2e exigen 4096 como mínimo).
const MAX_TOKENS = 4096;
const A_LA_VEZ = 3;                 // después de la primera, las demás de tres en tres
const ESPERA_REINTENTO_MS = 2_000;  // 429, 529 o 5xx: un reintento, después sin respuesta
const TIEMPO_LLAMADA_MS = 90_000;   // una llamada a Anthropic que no contesta en esto, cayó
const PRESUPUESTO_RAFAGA_MS = 120_000; // el reloj de la ráfaga: lo que no entre espera a la siguiente, y una llamada en vuelo se corta al llegar
const MINIMO_LLAMADA_MS = 500;      // con menos que esto de reloj no se arranca una llamada (ni un reintento)
const MAX_CUERPO = 1_000_000;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// ---- Lo que se le dice a la IA (fijo: su sha256 es prompt_version) -----------
// En español, para que el motivo salga en español. Nada de fechas, ids ni
// nombres de persona: lo variable va en el mensaje, no aquí (así el prefijo
// es idéntico entre llamadas y cachea).
const INSTRUCCIONES = `Eres el contador de Max Power Electrical Solutions, Inc., un contratista eléctrico de Florida (una S-corp que trabaja por obras). Edgar, el dueño, te da UN movimiento de una cuenta del banco o de una tarjeta de la empresa —un cargo que la bandeja no supo explicar— y tú propones a qué cuenta o cuentas del plan va. Tú propones; Edgar aprueba con un toque. Nunca posteas nada.

Cómo contestas: solo con el JSON del esquema que se te pide (lineas, motivo, confianza, flags, alternativas), sin texto alrededor.

Las reglas:
1. LAS CUENTAS. Clasifica el movimiento en UNA línea (lo normal) o en varias (de 2 a 5, cada una con su monto en dólares, en positivo, que sumen el importe del movimiento al centavo; con una sola línea el monto va null). Usa solo los códigos del PLAN DE CUENTAS PERMITIDO de abajo, tal cual están escritos. Nunca inventes una cuenta ni uses una que no esté en la lista: si ninguna encaja, propón 7900 (Otros gastos) con confianza baja y dilo en el motivo.
2. LA OBRA. Si el comercio vende material, herramienta, equipo o consumibles de obra (un supply eléctrico, Home Depot, Lowe's, CES, Graybar, una ferretería) la cuenta es de costo (5xxx) y pide obra. No adivines la obra: deja proyecto_id en null y marca pide_obra. Pon un proyecto_id solo si la descripción o la nota del movimiento nombran sin duda una de las OBRAS ACTIVAS de abajo (usa su id, no su nombre). Una cuenta con «obra prohibida» nunca lleva proyecto_id.
3. LAS REGLAS FIJAS DE LA S-CORP, que no reinterpretas: (a) un pago al IRS por el impuesto sobre la renta de Edgar (IRS, USATAXPYMT) va a 3200 (distribuciones al accionista) con el flag irs: no es gasto de la empresa; el DOR de Florida (sales tax, RT-6) sí es de la empresa. (b) Un cargo personal en una cuenta de la empresa (streaming, supermercado, ropa, un restaurante en fin de semana, una transferencia a Edgar) va a 3200 con el flag personal, y 1130 (cuenta por cobrar al accionista) como alternativa si Edgar lo va a devolver. (c) El sueldo de Edgar y el de la cuadrilla entran solo por la nómina: nunca propongas un pago a una persona como sueldo (las cuentas de nómina no están en la lista); un Zelle o un cheque a una persona que trabaja en obras suele ser un subcontrato (5200, pide obra) y, si no se sabe, dilo con confianza baja.
4. LA CAPITALIZACIÓN. Una compra de 2,500.00 o más por unidad con vida de más de un año (un vehículo, una herramienta grande, equipo de cómputo, mejoras al local) es un activo fijo (15xx), no un gasto: propón la cuenta 15xx que corresponda y marca capitalizable. Edgar decide.
5. EL USE TAX. Una compra fuera de Florida o a un comercio que no cobra el impuesto de Florida (compras por internet, un proveedor de otro estado) y sin impuesto visible marca use_tax. No propongas ninguna línea por el impuesto: Edgar lo resuelve con el recibo.
6. LA CONFIANZA, entre 0 y 1: 0.9 o más solo cuando el comercio y la cuenta son evidentes, o hay una regla o un ejemplo de Edgar igual; de 0.5 a 0.8 cuando hay dos lecturas razonables (pon la otra en alternativas); menos de 0.5 cuando estás adivinando.
7. EL MOTIVO: UNA frase en español, en llano, para Edgar, que cite lo que viste en el movimiento (el comercio, el monto, la nota, la cuenta del banco) y, si la hay, la regla o el ejemplo suyo que seguiste. Sin inventar nada que el movimiento no diga.
8. LAS REGLAS Y LOS EJEMPLOS DE EDGAR mandan sobre tu criterio: si ese comercio ya fue a una cuenta, propón esa (y dilo en el motivo).
9. Los flags son solo estos cinco: capitalizable, use_tax, personal, irs y pide_obra; cada uno true o false.

El movimiento llega como JSON: fecha, monto (negativo = un cargo, lo que salió de la cuenta), descripcion (lo que escribió el banco), memo (la nota, si la hay), cuenta_banco (el código de la cuenta de la empresa: 1010 es el banco, 2100-… una tarjeta), cuenta_banco_nombre, tipo_banco (DEBIT, CHECK, FEE…) y desc_norm (la descripción normalizada).`;

// La forma exacta de la respuesta (structured outputs: output_config.format
// json_schema). Todo required y additionalProperties false, como pide la
// API; lo opcional va null (monto con una sola línea, proyecto_id sin
// obra) y se quita antes de dárselo a la base. Sin minimum/maximum ni
// minLength: la API no los admite; la base valida lo que importa.
const PROPUESTA_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["lineas", "motivo", "confianza", "flags", "alternativas"],
  properties: {
    lineas: {
      type: "array",
      description: "De 1 a 5 líneas: la cuenta (código del plan permitido), su monto en dólares si hay varias (null con una sola) y la obra (id) si la cuenta la pide y el movimiento la nombra (si no, null).",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["cuenta", "monto", "proyecto_id"],
        properties: {
          cuenta: { type: "string", description: "El código de la cuenta, tal cual está en el plan permitido (p. ej. 5100)." },
          monto: { type: ["number", "null"], description: "Dólares en positivo; solo con varias líneas (suman el movimiento al centavo). Null con una sola línea." },
          proyecto_id: { type: ["string", "null"], description: "El id de una obra activa, solo si el movimiento la nombra sin duda. Null si no." },
        },
      },
    },
    motivo: { type: "string", description: "Una frase en español que cita lo que viste en el movimiento y por qué esa cuenta." },
    confianza: { type: "number", description: "Entre 0 y 1." },
    flags: {
      type: "object",
      additionalProperties: false,
      required: ["capitalizable", "use_tax", "personal", "irs", "pide_obra"],
      properties: {
        capitalizable: { type: "boolean" },
        use_tax: { type: "boolean" },
        personal: { type: "boolean" },
        irs: { type: "boolean" },
        pide_obra: { type: "boolean" },
      },
    },
    alternativas: {
      type: "array",
      description: "Otras lecturas razonables (vacío si no hay): la cuenta y en una frase por qué.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["cuenta", "motivo"],
        properties: { cuenta: { type: "string" }, motivo: { type: "string" } },
      },
    },
  },
};

// La configuración se lee en cada llamada (el entorno no cambia en Supabase;
// en las pruebas sin Deno sí).
interface Conf {
  llave: string; base_url: string; db: string; supabase_url: string; service_key: string; banco_pruebas: boolean; banco_mal: string | null;
}
// ¿Es el banco de pruebas? TODO a la vez: MXP_BANCO_PRUEBAS=1, la base en
// 127.0.0.1 (MXP_DB_URL), sin SUPABASE_DB_URL y fuera de Supabase (sin
// EdgeRuntime ni SB_REGION). En producción nunca: lo que lo pida a medias es
// un error de configuración (mal), no un modo.
function esBancoDePruebas(): { vale: boolean; mal: string | null } {
  const pedido = env("MXP_BANCO_PRUEBAS") === "1";
  const local = /^postgres(ql)?:\/\/[^@]*@(127\.0\.0\.1|localhost)(:\d+)?\//.test(env("MXP_DB_URL"));
  const enSupabase = G.EdgeRuntime !== undefined || env("SB_REGION") !== "";
  const vale = pedido && local && env("SUPABASE_DB_URL") === "" && !enSupabase;
  const mal = pedido && !vale ? "MXP_BANCO_PRUEBAS no vale fuera del banco de pruebas: bórralo de Supabase → Edge Functions → Secrets."
    : env("MXP_DB_URL") && env("SUPABASE_DB_URL") ? "MXP_DB_URL es del banco de pruebas: bórralo de Supabase → Edge Functions → Secrets."
    : null;
  return { vale, mal };
}
function conf(): Conf {
  const b = esBancoDePruebas(); // SOLO el banco de pruebas
  const banco = b.vale;
  return {
    llave: env("ANTHROPIC_API_KEY").trim(),
    // (ANTHROPIC_BASE_URL: solo el simulador del banco de pruebas; en Supabase se ignora)
    base_url: (banco && env("ANTHROPIC_BASE_URL") ? env("ANTHROPIC_BASE_URL") : "https://api.anthropic.com").replace(/\/$/, ""),
    db: (banco ? env("MXP_DB_URL") : "") || env("SUPABASE_DB_URL"),
    supabase_url: env("SUPABASE_URL"), service_key: env("SUPABASE_SERVICE_ROLE_KEY"), banco_pruebas: banco, banco_mal: b.mal,
  };
}

// El reloj de la ráfaga: PRESUPUESTO_RAFAGA_MS, salvo en el banco de pruebas,
// donde MXP_PRESUPUESTO_MS lo acorta para probar el corte sin esperar dos
// minutos (en Supabase se ignora, como todo lo MXP_).
function presupuestoRafaga(c: Conf): number {
  const v = env("MXP_PRESUPUESTO_MS");
  return c.banco_pruebas && /^\d{3,7}$/.test(v) ? Number(v) : PRESUPUESTO_RAFAGA_MS;
}

class Fallo extends Error {
  estado: number;
  codigo?: string;
  detalle?: Json;
  pista?: string;
  constructor(estado: number, mensaje: string, codigo?: string, detalle?: Json, pista?: string) {
    super(mensaje);
    this.estado = estado;
    this.codigo = codigo;
    this.detalle = detalle;
    this.pista = pista;
  }
}

// ---- Ayudas ------------------------------------------------------------
function limpiar(o: Json): Json {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined && v !== null && v !== ""));
}
function responder(cuerpo: Json, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, "Content-Type": "application/json" } });
}
function dormir(ms: number): Promise<void> { return new Promise((r) => setTimeout(r, ms)); }
function texto(v: unknown): string | null { return typeof v === "string" && v.trim() ? v.trim() : null; }
function obj(v: unknown): Json { return v && typeof v === "object" && !Array.isArray(v) ? v as Json : {}; }
function arr(v: unknown): Json[] { return Array.isArray(v) ? v.filter((x) => x && typeof x === "object") as Json[] : []; }
function num(v: unknown): number | null { return typeof v === "number" && Number.isFinite(v) ? v : null; }
// Ninguna llave sale en un mensaje (Anthropic a veces repite un trozo).
function sinLlaves(s: string): string {
  return s.replace(/\bsk-ant-[A-Za-z0-9_-]{4,}/g, "[llave]");
}
function mensajeDe(e: unknown): string { return sinLlaves(e instanceof Error ? e.message : String(e)); }
function cargaJwt(jwt: string): Json | null {
  const partes = jwt.split(".");
  if (partes.length < 2) return null;
  try {
    const b64 = partes[1].replace(/-/g, "+").replace(/_/g, "/");
    const bytes = Uint8Array.from(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")), (c) => c.charCodeAt(0));
    const carga = JSON.parse(new TextDecoder().decode(bytes));
    return carga && typeof carga === "object" ? carga as Json : null;
  } catch { return null; }
}
const te = new TextEncoder();
async function sha256(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", te.encode(s));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
// prompt_version: el sha256 de las instrucciones (fijo mientras no cambien).
let versionLista: Promise<string> | null = null;
function versionDelPrompt(): Promise<string> {
  if (!versionLista) versionLista = sha256(INSTRUCCIONES);
  return versionLista;
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function uuidDe(v: unknown, que: string): string {
  if (typeof v !== "string" || !UUID.test(v.trim())) throw new Fallo(400, `Falta ${que} (su id).`, "FORMA");
  return v.trim().toLowerCase();
}

// ---- El prefijo (lo fijo) y la entrada (lo variable) --------------------------
// Una sección del prefijo: título, una línea por fila (en el orden en que la
// base las da: ya vienen ordenadas por código, nombre o patrón) o el texto
// de «no hay».
function seccion(titulo: string, filas: string[], vacio: string): string {
  return `${titulo}:\n${filas.length ? filas.join("\n") : vacio}`;
}
function lineasDeRegla(l: unknown): string {
  return arr(l).map((x) => `${x.cuenta ?? "?"}${x.parte !== undefined && x.parte !== null ? ` (${x.parte})` : ""}${x.proyecto_id ? ` · obra ${x.proyecto_id}` : ""}`).join(" + ");
}
// El prefijo entero: las instrucciones + el plan permitido + las obras +
// las reglas + los ejemplos. Determinista: el mismo contexto da los mismos
// bytes (su sha256 es prefijo_hash) y Anthropic lo sirve del caché a partir
// de la segunda llamada de la ráfaga.
function armarPrefijo(ctx: Json): string {
  const cuentas = arr(ctx.cuentas).map((c) =>
    `${c.codigo} · ${c.nombre} · ${c.tipo} · obra ${c.regla_obra ?? "opcional"}${c.etiqueta_fiscal ? ` · fiscal: ${c.etiqueta_fiscal}` : ""}`);
  const obras = arr(ctx.proyectos).map((p) => `${p.id} · ${p.nombre} · ${p.estado}`);
  const reglas = arr(ctx.reglas).map((r) =>
    `${r.nombre}: ${lineasDeRegla(r.lineas)} (patrón ${r.patron}${r.cuenta_banco ? `, solo en ${r.cuenta_banco}` : ""}${r.pide_obra === true ? ", pide obra" : ""})`);
  const ejemplos = arr(ctx.ejemplos).map((e) => `«${e.desc}» → ${e.cuenta}${e.proyecto_id ? ` · obra ${e.proyecto_id}` : ""}`);
  return [
    INSTRUCCIONES,
    seccion("PLAN DE CUENTAS PERMITIDO (código · nombre · tipo · obra obligatoria, opcional o prohibida)", cuentas, "ninguna: no propongas nada"),
    seccion("OBRAS ACTIVAS (id · nombre · estado)", obras, "ninguna"),
    seccion("REGLAS DE EDGAR (comercio: cuentas; patrón)", reglas, "ninguna todavía"),
    seccion("EJEMPLOS DE EDGAR (descripción del banco → cuenta[, obra]), los más recientes primero", ejemplos, "ninguno todavía"),
  ].join("\n\n");
}
// El movimiento tal cual se le da a la IA (y se congela en «entrada»): la
// base ya lo trae sin correos, teléfonos ni números de cuenta.
function armarEntrada(m: Json): Json {
  return {
    fecha: m.fecha ?? null, monto: m.monto ?? null, descripcion: m.descripcion ?? null, memo: m.memo ?? null,
    cuenta_banco: m.cuenta ?? null, cuenta_banco_nombre: m.cuenta_nombre ?? null, tipo_banco: m.tipo_banco ?? null, desc_norm: m.desc_norm ?? null,
  };
}

// ---- Anthropic -----------------------------------------------------------------
interface Uso { input: number; output: number; cache_creacion: number; cache_lectura: number }
const USO_CERO: Uso = { input: 0, output: 0, cache_creacion: 0, cache_lectura: 0 };
function usoDe(u: unknown): Uso {
  const o = obj(u);
  return { input: num(o.input_tokens) ?? 0, output: num(o.output_tokens) ?? 0,
           cache_creacion: num(o.cache_creation_input_tokens) ?? 0, cache_lectura: num(o.cache_read_input_tokens) ?? 0 };
}
function sumar(a: Uso, b: Uso): void { a.input += b.input; a.output += b.output; a.cache_creacion += b.cache_creacion; a.cache_lectura += b.cache_lectura; }
interface RespuestaIA {
  estado: "ok" | "sin_respuesta" | "invalida";
  motivo?: string;       // por qué no hay propuesta (refusal, max_tokens, caída, JSON roto)
  propuesta?: Json;      // la propuesta ya normalizada (lo null fuera), solo con «ok»
  salida?: Json;         // la respuesta cruda de Anthropic
  usage: Uso;
  intentos: number;
}
// La propuesta como la quiere la base: sin los null del esquema (monto con
// una sola línea, proyecto_id sin obra), los flags solo los que son true
// (pide_obra lo decide la base por las cuentas) y las alternativas solo si
// hay. No se reinterpreta nada: lo que no valga lo rechaza la base.
function normalizarPropuesta(p: Json): Json {
  const lineas = arr(p.lineas).map((l) => limpiar({
    cuenta: typeof l.cuenta === "string" ? l.cuenta.trim() : l.cuenta,
    monto: typeof l.monto === "number" || typeof l.monto === "string" ? l.monto : undefined,
    proyecto_id: typeof l.proyecto_id === "string" && l.proyecto_id.trim() ? l.proyecto_id.trim() : undefined,
  }));
  const flags = Object.fromEntries(Object.entries(obj(p.flags)).filter(([, v]) => v === true));
  const alternativas = arr(p.alternativas).filter((a) => typeof a.cuenta === "string" && a.cuenta.trim())
    .map((a) => ({ cuenta: (a.cuenta as string).trim(), motivo: typeof a.motivo === "string" ? a.motivo : "" }));
  const out: Json = { lineas, motivo: p.motivo, confianza: p.confianza, flags };
  if (alternativas.length) out.alternativas = alternativas;
  return out;
}
// Lo que contestó Anthropic, leído por tipo de bloque (la respuesta puede
// empezar con bloques «thinking» vacíos: nunca content[0] a ciegas) y por
// stop_reason ANTES de mirar el contenido: «refusal» es sin respuesta, y
// NUNCA otro modelo; «max_tokens» se cortó. Lo demás es el JSON del esquema.
function leerRespuesta(j: Json): RespuestaIA {
  const usage = usoDe(j.usage);
  if (j.stop_reason === "refusal") {
    const cat = texto(obj(j.stop_details).category);
    return { estado: "sin_respuesta", motivo: `la IA no quiso contestar (refusal${cat ? `: ${cat}` : ""}); no se cambia de modelo`, usage, salida: j, intentos: 1 };
  }
  if (j.stop_reason === "max_tokens") {
    return { estado: "sin_respuesta", motivo: `la respuesta se cortó (max_tokens ${MAX_TOKENS})`, usage, salida: j, intentos: 1 };
  }
  const txt = arr(j.content).filter((b) => b.type === "text").map((b) => typeof b.text === "string" ? b.text : "").join("");
  let p: unknown;
  try { p = JSON.parse(txt); } catch { return { estado: "invalida", motivo: "la IA no devolvió un JSON", usage, salida: j, intentos: 1 }; }
  if (!p || typeof p !== "object" || Array.isArray(p)) return { estado: "invalida", motivo: "la IA devolvió un JSON que no es la propuesta", usage, salida: j, intentos: 1 };
  return { estado: "ok", propuesta: normalizarPropuesta(p as Json), usage, salida: j, intentos: 1 };
}
// Un error de Anthropic que no se arregla reintentando: la llave, el modelo o
// la petición. Corta la ráfaga y se dice en llano.
function falloDeAnthropic(estado: number, j: Json): Fallo {
  const err = obj(j.error);
  const msg = sinLlaves(String(err.message ?? `HTTP ${estado}`)).slice(0, 400);
  if (estado === 401) return new Fallo(502, "La llave de Anthropic no vale (contestó 401): revisa ANTHROPIC_API_KEY en Supabase → Edge Functions → Secrets.", "ANTHROPIC_LLAVE");
  if (estado === 403) return new Fallo(502, `La llave de Anthropic no tiene permiso para esto (403): ${msg}`, "ANTHROPIC_PERMISO");
  if (estado === 404) return new Fallo(502, `Anthropic no conoce eso (404: ${msg}): revisa el modelo en ia_config (claude-opus-5-5).`, "ANTHROPIC_MODELO");
  if (estado === 400) return new Fallo(502, `Anthropic rechazó la petición (400): ${msg}`, "ANTHROPIC_PETICION");
  return new Fallo(502, `Anthropic contestó ${estado}: ${msg}`, `ANTHROPIC_${estado}`);
}
// UNA llamada a /v1/messages: el prefijo con cache_control, el movimiento en
// el mensaje, el esquema en output_config.format y el esfuerzo en
// output_config.effort. Sin thinking (Opus 5.5 lo trae adaptativo), sin
// tool_choice, sin fallbacks, sin stream. Un 429, 529 o 5xx (o no contestar
// en 90 s) se reintenta UNA vez tras 2 s y después es «sin respuesta». El
// plazo es el reloj de la ráfaga: con menos de medio segundo no se arranca
// una llamada (ni el reintento), y una en vuelo se corta al llegar, para que
// la función entera termine antes del límite de Supabase y cierre su lote.
async function llamarIA(c: Conf, modelo: string, effort: string, prefijo: string, mensaje: string, plazo: number): Promise<RespuestaIA> {
  const cuerpo = JSON.stringify({
    model: modelo,
    max_tokens: MAX_TOKENS,
    system: [{ type: "text", text: prefijo, cache_control: { type: "ephemeral" } }],
    messages: [{ role: "user", content: mensaje }],
    output_config: { effort, format: { type: "json_schema", schema: PROPUESTA_SCHEMA } },
  });
  const headers = { "x-api-key": c.llave, "anthropic-version": ANTHROPIC_VERSION, "content-type": "application/json" };
  let ultimo = "antes de llamar";
  for (let intento = 1; intento <= 2; intento++) {
    // el reloj de la ráfaga: sin tiempo para una llamada entera (y la espera del reintento), no se manda
    if (plazo - Date.now() < MINIMO_LLAMADA_MS + (intento > 1 ? ESPERA_REINTENTO_MS : 0)) {
      return { estado: "sin_respuesta", motivo: `se acabó el tiempo de la ráfaga (${ultimo}): este cargo espera a la siguiente`, usage: { ...USO_CERO }, intentos: intento - 1 };
    }
    if (intento > 1) await dormir(ESPERA_REINTENTO_MS);
    const ctl = new AbortController();
    const reloj = setTimeout(() => ctl.abort(), Math.max(1, Math.min(TIEMPO_LLAMADA_MS, plazo - Date.now())));
    let r: Response, crudo: string;
    try {
      r = await fetch(`${c.base_url}/v1/messages`, { method: "POST", headers, body: cuerpo, signal: ctl.signal });
      crudo = await r.text();
    } catch (e) {
      ultimo = e instanceof Error && e.name === "AbortError"
        ? (Date.now() >= plazo ? "la llamada en vuelo se cortó al llegar el plazo" : `${TIEMPO_LLAMADA_MS / 1000} s sin respuesta`)
        : "sin conexión";
      continue;
    } finally { clearTimeout(reloj); }
    let j: Json = {};
    try { j = obj(JSON.parse(crudo)); } catch { /* no era JSON */ }
    if (r.status === 429 || r.status === 529 || r.status >= 500) { ultimo = `HTTP ${r.status}`; continue; }
    if (!r.ok) throw falloDeAnthropic(r.status, j);
    return { ...leerRespuesta(j), intentos: intento };
  }
  return { estado: "sin_respuesta", motivo: `Anthropic no contestó (${ultimo}, dos veces)`, usage: { ...USO_CERO }, intentos: 2 };
}

// ---- La base -----------------------------------------------------------
// Directo a Postgres, como postgres: cada llamada en su transacción. Las
// fn_contador_* exigen eso (fn_desde_editor) y no están en la API.
interface Quien { id: string; rol: string; activo: boolean }
interface Base {
  rpc(fn: string, args: Json): Promise<unknown>;
  quien(jwt: string): Promise<Quien | null>;
}
// deno-lint-ignore no-explicit-any
function falloDeLaBase(e: any): Fallo {
  if (e instanceof Fallo) return e;
  const codigo = String(e?.code ?? "");
  const msg = String(e?.message ?? e);
  const estado = codigo === "42501" ? 403 : codigo.startsWith("MX") || codigo === "22023" || codigo === "22007" ? 409 : 500;
  return new Fallo(estado, msg, codigo || "BASE", undefined, typeof e?.hint === "string" && e.hint ? e.hint : undefined);
}
async function abrirBase(): Promise<Base> {
  const c = conf();
  // npm: solo en Deno (Supabase); en el banco sin Deno la base se inyecta
  const postgres = (await import("npm:postgres@3.4.5")).default;
  // el pooler de Supabase en modo transacción no admite sentencias preparadas
  const pooler = /pooler\.supabase\.com|:6543\//.test(c.db);
  const sql = postgres(c.db, { max: 2, idle_timeout: 20, connect_timeout: 10, prepare: !pooler, onnotice: () => {} });
  const sb = c.banco_pruebas ? null
    : (await import("npm:@supabase/supabase-js@2")).createClient(c.supabase_url, c.service_key, { auth: { persistSession: false, autoRefreshToken: false } });
  return {
    async rpc(fn, args) {
      const nombres = Object.keys(args);
      // los objetos y las listas van tal cual: postgres.js los vuelve JSON cuando la base dice que el parámetro es jsonb
      const valores = nombres.map((k) => args[k] === undefined ? null : args[k]);
      const llamada = `select ${fn}(${nombres.map((k, i) => `${k} => $${i + 1}`).join(", ")}) as r`;
      try {
        // deno-lint-ignore no-explicit-any
        return await sql.begin(async (t: any) => {
          await t.unsafe(`select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true)`);
          const filas = await t.unsafe(llamada, valores);
          return filas[0]?.r;
        });
      } catch (e) { throw falloDeLaBase(e); }
    },
    async quien(jwt) {
      let id: string | null = null;
      if (sb) {
        const { data, error } = await sb.auth.getUser(jwt);
        if (error || !data?.user) return null;
        id = data.user.id;
      } else {
        // SIN verificar la firma: solo en el banco de pruebas (ver la cabecera)
        const carga = cargaJwt(jwt);
        if (typeof carga?.sub === "string") id = carga.sub;
      }
      if (!id) return null;
      const filas = await sql`select rol, coalesce(activo, true) as activo from perfiles where id = ${id}::uuid`;
      return filas[0] ? { id, rol: String(filas[0].rol), activo: Boolean(filas[0].activo) } : null;
    },
  };
}
let baseLista: Promise<Base> | null = null;
function obtenerBase(): Promise<Base> {
  if (!baseLista) baseLista = abrirBase();
  return baseLista;
}
// Solo el banco de pruebas: la base de mentira (psql) de contador-e2e.mjs.
export function usarBaseDePruebas(b: Base): void {
  if (!esBancoDePruebas().vale) throw new Error("usarBaseDePruebas es solo del banco de pruebas (MXP_BANCO_PRUEBAS=1, la base en 127.0.0.1).");
  baseLista = Promise.resolve(b);
}

// ---- La ráfaga: proponer ---------------------------------------------------------
interface Conteo { ok: number; sin: number; inv: number; fatal: Fallo | null }
async function proponer(base: Base, c: Conf, dueno: string, cuerpo: Json): Promise<Json> {
  const t0 = Date.now();
  const presupuesto = presupuestoRafaga(c);
  const plazo = t0 + presupuesto;
  // 1. las reglas de Edgar (gratis)
  const reglas = obj(await base.rpc("fn_contador_reglas_aplicar", { p_dueno: dueno }));
  const nReglas = num(reglas.propuestas) ?? 0;
  const comun: Json = { reglas: nReglas, reglas_rotas: Array.isArray(reglas.reglas_rotas) && reglas.reglas_rotas.length ? reglas.reglas_rotas : undefined };
  // 2. el tope (la tercera regla de la IA): bloqueado = ni un token
  const tope = obj(await base.rpc("fn_contador_tope", {}));
  if (tope.bloqueado === true) {
    return limpiar({ ok: true, bloqueado: true, motivo: tope.motivo, ...comun, movimientos: 0, propuestas: 0, sin_respuesta: 0, invalidas: 0, centavos: 0, tope });
  }
  // 3. lo que espera y el contexto (la base recorta el límite a max_por_rafaga)
  const lim = typeof cuerpo.limite === "number" && Number.isInteger(cuerpo.limite) && cuerpo.limite > 0 ? cuerpo.limite
    : typeof cuerpo.limite === "string" && /^\d{1,3}$/.test(cuerpo.limite) && Number(cuerpo.limite) > 0 ? Number(cuerpo.limite) : null;
  const k = obj(await base.rpc("fn_contador_pendientes", { p_limite: lim }));
  const cfg = obj(k.config);
  const modelo = String(cfg.modelo ?? "");
  const effort = String(cfg.effort ?? "low");
  // (la base ya lo exige; aquí otra vez: ni Haiku ni Sonnet, en ninguna parte)
  if (!/^claude-(opus|fable)-/.test(modelo) || /haiku|sonnet/i.test(modelo)) {
    throw new Fallo(500, `El modelo de ia_config («${modelo}») no es Opus ni Fable: no se le pide nada a la IA.`, "CONFIG");
  }
  const movs = arr(k.movimientos);
  const ctx = obj(k.contexto);
  if (!movs.length) {
    return limpiar({ ok: true, bloqueado: false, ...comun, movimientos: 0, total: num(k.total) ?? 0, propuestas: 0, sin_respuesta: 0, invalidas: 0, centavos: 0,
                     tope: k.tope, nota: nReglas ? "todo lo que esperaba salió por regla" : "nada que proponer: ningún cargo espera" });
  }
  if (!c.llave) {
    throw new Fallo(500, "Falta ANTHROPIC_API_KEY en Supabase → Edge Functions → Secrets: la ráfaga no arranca (las reglas sí se aplicaron).", "CONFIG");
  }
  // 4. el lote y la ráfaga
  const prefijo = armarPrefijo(ctx);
  const [prompt_version, prefijo_hash] = await Promise.all([versionDelPrompt(), sha256(prefijo)]);
  const lote = String(await base.rpc("fn_contador_lote_abrir", {
    p_por: dueno, p_modelo: modelo, p_effort: effort, p_prompt_version: prompt_version, p_prefijo_hash: prefijo_hash, p_n: movs.length,
  }));
  const uso: Uso = { ...USO_CERO };
  const n: Conteo = { ok: 0, sin: 0, inv: 0, fatal: null };
  const detalle: Json[] = [];
  const errores: string[] = [];
  const notas: string[] = [];
  const obras = arr(ctx.proyectos).map((p) => ({ id: p.id, nombre: p.nombre }));
  const uno = async (m: Json) => {
    const mid = String(m.movimiento_id);
    const entradaMov = armarEntrada(m);
    let r: RespuestaIA;
    try { r = await llamarIA(c, modelo, effort, prefijo, JSON.stringify(entradaMov), plazo); }
    catch (e) {
      // la llave, el modelo o la petición: no tiene sentido seguir
      n.fatal = e instanceof Fallo ? e : new Fallo(502, mensajeDe(e), "ANTHROPIC");
      n.sin++;
      detalle.push({ movimiento_id: mid, estado: "sin_respuesta", motivo: n.fatal.message, codigo: n.fatal.codigo });
      return;
    }
    sumar(uso, r.usage);
    if (r.estado !== "ok" || !r.propuesta) {
      if (r.estado === "invalida") n.inv++; else n.sin++;
      detalle.push(limpiar({ movimiento_id: mid, estado: r.estado, motivo: r.motivo, intentos: r.intentos > 1 ? r.intentos : undefined }));
      return;
    }
    // LO VARIABLE, congelado tal cual se le dio (la base lo guarda sin datos personales)
    const entrada = { movimiento: entradaMov, obras, reglas_version: ctx.reglas_version ?? null, prefijo_hash, prompt_version };
    try {
      const g = obj(await base.rpc("fn_contador_propuesta_guardar", {
        p_movimiento: mid, p_lote: lote, p_entrada: entrada, p_salida: r.salida ?? null, p_propuesta: r.propuesta,
        p_modelo: modelo, p_effort: effort, p_prompt_version: prompt_version,
      }));
      if (g.error) {
        n.inv++;
        detalle.push(limpiar({ movimiento_id: mid, estado: "invalida", motivo: g.error, codigo: g.codigo, intentos: r.intentos > 1 ? r.intentos : undefined }));
      } else {
        n.ok++;
        detalle.push(limpiar({ movimiento_id: mid, estado: "pendiente", propuesta: g.propuesta, pide_obra: g.pide_obra === true,
                               confianza: num(r.propuesta.confianza), caducada: g.caducada, intentos: r.intentos > 1 ? r.intentos : undefined }));
      }
    } catch (e) {
      n.inv++;
      const msg = mensajeDe(e);
      errores.push(`${mid}: ${msg}`.slice(0, 300));
      detalle.push({ movimiento_id: mid, estado: "invalida", motivo: msg, codigo: e instanceof Fallo ? e.codigo : undefined });
    }
  };
  // la primera sola (crea el caché del prefijo); las demás, de tres en tres,
  // mientras quede reloj (lo que no entra no es un error: espera a la siguiente)
  await uno(movs[0]);
  for (let i = 1; i < movs.length && !n.fatal; i += A_LA_VEZ) {
    if (Date.now() > plazo) { notas.push(`se acabó el tiempo de la ráfaga (${Math.round(presupuesto / 1000)} s): ${movs.length - i} movimiento(s) esperan a la siguiente`); break; }
    await Promise.all(movs.slice(i, i + A_LA_VEZ).map(uno));
  }
  const sinIntentar = movs.length - n.ok - n.sin - n.inv;
  // 5. cerrar el lote con el uso sumado (la base calcula y anota los centavos)
  const error = n.fatal ? n.fatal.message : errores.length ? errores.slice(0, 3).join(" · ") : null;
  let cierre: Json = {};
  try { cierre = obj(await base.rpc("fn_contador_lote_cerrar", { p_lote: lote, p_usage: uso, p_error: error })); }
  catch (e) { errores.push(`cerrar el lote: ${mensajeDe(e)}`); }
  if (n.fatal && n.ok === 0) throw n.fatal;
  return limpiar({
    ok: true, bloqueado: false, lote, modelo, effort, prompt_version, prefijo_hash, ...comun,
    movimientos: movs.length, total: num(k.total) ?? movs.length, propuestas: n.ok, sin_respuesta: n.sin, invalidas: n.inv,
    sin_intentar: sinIntentar || undefined, centavos: num(cierre.centavos) ?? 0, usage: uso,
    cache: { creacion: uso.cache_creacion, lectura: uso.cache_lectura }, tope: cierre.tope ?? k.tope, detalle,
    errores: errores.length ? errores.slice(0, 20) : undefined, error: error ?? undefined, nota: notas.length ? notas.join(" · ") : undefined,
    presupuesto_ms: presupuesto, ms: Date.now() - t0,
  });
}

// ---- Salud: qué falta, sin enseñar nada -----------------------------------
// Sin sesión: lo que hay y lo que falta (la llave, la base, Supabase), el
// modelo y el esfuerzo de ia_config, la versión del prompt de ESTA función
// (y la última que la base vio) y el tope del mes. Nada más: lo que lleva
// datos del libro va en «estado», con sesión.
async function salud(resumen?: Json): Promise<Json> {
  const c = conf();
  const falta: string[] = [];
  if (!c.llave) falta.push("ANTHROPIC_API_KEY (la llave del contador, sk-ant-…: console.anthropic.com → API keys → Create key)");
  else if (!/^sk-ant-/.test(c.llave)) falta.push("ANTHROPIC_API_KEY no parece una llave de Anthropic (empiezan por sk-ant-)");
  if (!c.db) falta.push("SUPABASE_DB_URL (lo pone Supabase) o MXP_DB_URL");
  if (!c.banco_pruebas && !(c.supabase_url && c.service_key)) falta.push("SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (los pone Supabase)");
  if (c.banco_mal) falta.push(c.banco_mal);
  let base = false;
  let r: Json = {};
  if (c.db && !c.banco_mal) {
    try { r = resumen ?? obj(await (await obtenerBase()).rpc("fn_contador_resumen", {})); base = true; }
    catch (e) {
      const f = falloDeLaBase(e);
      falta.push(f.codigo === "42883" ? "docs/conta/c8-contador.sql no está pegado (no existe fn_contador_resumen)"
        : `la base no contestó (${f.codigo ?? "?"}): ${mensajeDe(f).slice(0, 200)}`);
    }
  }
  const cfg = obj(r.config), t = obj(r.tope);
  return {
    ok: true, llave: Boolean(c.llave), base, sesion: c.banco_pruebas || Boolean(c.supabase_url && c.service_key),
    modelo: cfg.modelo ?? null, effort: cfg.effort ?? null, activa: cfg.activa ?? null, max_por_rafaga: cfg.max_por_rafaga ?? null,
    prompt_version: await versionDelPrompt(), prompt_version_base: cfg.prompt_version ?? null, prefijo_hash_base: cfg.prefijo_hash ?? null,
    ultima_rafaga_el: cfg.ultima_rafaga_el ?? null, con_error: Boolean(cfg.ultimo_error),
    tope: base ? limpiar({ mes: t.mes, bloqueado: t.bloqueado, motivo: t.motivo, aviso: t.aviso, centavos_mes_total: t.centavos_mes_total, tope_global: t.tope_global,
                           centavos_mes_contador: t.centavos_mes_contador, tope_contador: t.tope_contador, restante_centavos: t.restante_centavos }) : null,
    version: ANTHROPIC_VERSION, max_tokens: MAX_TOKENS, banco_de_pruebas: c.banco_pruebas, falta,
  };
}

// ---- El servidor -------------------------------------------------------------
export async function atender(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  try {
    const url = new URL(req.url);
    if (Number(req.headers.get("content-length") ?? 0) > MAX_CUERPO) throw new Fallo(413, "El cuerpo es demasiado grande.", "FORMA");
    const crudo = req.method === "POST" ? await req.text() : "";
    if (crudo.length > MAX_CUERPO) throw new Fallo(413, "El cuerpo es demasiado grande.", "FORMA");
    let cuerpo: Json = {};
    if (crudo) { try { cuerpo = obj(JSON.parse(crudo)); } catch { throw new Fallo(400, "El cuerpo no es JSON.", "FORMA"); } }
    const accion = String(cuerpo.accion ?? url.searchParams.get("accion") ?? url.searchParams.get("paso") ?? "");
    if (accion === "salud") return responder(await salud());

    const c = conf();
    if (c.banco_mal) {
      console.error("contador: hay secretos del banco de pruebas en producción (MXP_BANCO_PRUEBAS o MXP_DB_URL)");
      throw new Fallo(500, c.banco_mal, "CONFIG");
    }
    if (!c.db || (!c.banco_pruebas && (!c.supabase_url || !c.service_key))) {
      console.error("contador: falta la base (SUPABASE_DB_URL) o Supabase (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)");
      throw new Fallo(500, "Falta configurar la función (la base o Supabase) en Supabase → Edge Functions → Secrets.", "CONFIG");
    }
    const base = await obtenerBase();

    // Edgar, con su sesión de dueño y el código del teléfono (TODO lo pide)
    const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!jwt) throw new Fallo(401, "Entra con tu sesión.", "SESION");
    const quien = await base.quien(jwt);
    if (!quien) throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.", "SESION");
    if (quien.rol !== "dueno" || !quien.activo) throw new Fallo(403, "El contador (las propuestas y las reglas) lo maneja solo Edgar (el dueño).", "NO_DUENO");
    // el JWT ya lo validó getUser: aquí solo se lee su aal (s1 frena PostgREST, no esta función)
    const carga = cargaJwt(jwt);
    if (carga?.aal !== "aal2" || (typeof carga?.sub === "string" && carga.sub !== quien.id)) {
      throw new Fallo(403, "Falta el código del teléfono: entra otra vez con él (el contador lo pide).", "MFA");
    }
    await base.rpc("fn_contador_dueno_fijar", { p_dueno: quien.id });
    const recordar = cuerpo.recordar === undefined || cuerpo.recordar === null ? true : cuerpo.recordar === true;
    const motivoDe = (que: string) => {
      const m = texto(cuerpo.motivo);
      if (!m || m.length < 3) throw new Fallo(400, `Falta el motivo: ${que}.`, "FORMA");
      return m;
    };

    switch (accion) {
      case "estado": {
        const r = obj(await base.rpc("fn_contador_resumen", {}));
        return responder({ ok: true, salud: await salud(r), estado: r.estado ?? null, tope: r.tope ?? null, control_rojo: r.control_rojo ?? [] });
      }
      case "proponer":
        return responder(await proponer(base, c, quien.id, cuerpo));
      case "aprobar": {
        const r = obj(await base.rpc("fn_contador_aprobar", {
          p_propuesta: uuidDe(cuerpo.propuesta, "la propuesta"), p_dueno: quien.id, p_proyecto_id: texto(cuerpo.proyecto_id), p_recordar: recordar,
        }));
        return responder({ ok: true, ...r });
      }
      case "clasificar": {
        if (!Array.isArray(cuerpo.lineas) || !cuerpo.lineas.length) throw new Fallo(400, "Faltan las líneas ([{cuenta, proyecto_id?, monto?}]).", "FORMA");
        const r = obj(await base.rpc("fn_contador_clasificar", {
          p_movimiento: uuidDe(cuerpo.movimiento, "el movimiento"), p_dueno: quien.id, p_lineas: cuerpo.lineas, p_motivo: texto(cuerpo.motivo),
          p_recordar: recordar, p_propuesta: typeof cuerpo.propuesta === "string" && cuerpo.propuesta ? uuidDe(cuerpo.propuesta, "la propuesta") : null,
        }));
        return responder({ ok: true, ...r });
      }
      case "rechazar": {
        // (sin motivo, la base pone el suyo: «No es eso (Edgar, desde la bandeja)»)
        const r = obj(await base.rpc("fn_contador_rechazar", { p_propuesta: uuidDe(cuerpo.propuesta, "la propuesta"), p_dueno: quien.id, p_motivo: texto(cuerpo.motivo) }));
        return responder({ ok: true, ...r });
      }
      case "caducar": {
        const r = obj(await base.rpc("fn_contador_caducar", {
          p_propuesta: uuidDe(cuerpo.propuesta, "la propuesta"), p_dueno: quien.id, p_motivo: motivoDe("cerrar una propuesta aprobada queda escrito"),
        }));
        return responder({ ok: true, ...r });
      }
      case "regla_alta": {
        const nombre = texto(cuerpo.nombre), patron = texto(cuerpo.patron);
        if (!nombre || !patron) throw new Fallo(400, "La regla lleva el nombre del comercio (nombre) y su patrón (patron).", "FORMA");
        if (!Array.isArray(cuerpo.lineas) || !cuerpo.lineas.length) throw new Fallo(400, "Faltan las líneas de la regla ([{cuenta, proyecto_id?, parte?}]).", "FORMA");
        const r = obj(await base.rpc("fn_contador_regla_alta", {
          p_dueno: quien.id, p_nombre: nombre, p_patron: patron, p_lineas: cuerpo.lineas, p_cuenta_banco: texto(cuerpo.cuenta_banco),
        }));
        return responder({ ok: true, regla: r });
      }
      case "regla_baja": {
        const r = obj(await base.rpc("fn_contador_regla_baja", {
          p_regla: uuidDe(cuerpo.regla, "la regla"), p_dueno: quien.id, p_motivo: motivoDe("queda escrito con la regla"),
        }));
        return responder({ ok: true, regla: r });
      }
      default:
        throw new Fallo(400, `Acción desconocida: «${accion}».`, "ACCION");
    }
  } catch (e) {
    const f = e instanceof Fallo ? e : falloDeLaBase(e);
    if (f.estado >= 500 && !(e instanceof Fallo)) console.error(`contador: ${mensajeDe(e).slice(0, 300)}`);
    return responder(limpiar({ ok: false, error: sinLlaves(f.message), codigo: f.codigo, pista: f.pista }), f.estado);
  }
}

// Para las pruebas (contador-e2e.mjs): las piezas puras.
export const _probar = {
  INSTRUCCIONES, PROPUESTA_SCHEMA, ANTHROPIC_VERSION, MAX_TOKENS, A_LA_VEZ, ESPERA_REINTENTO_MS, PRESUPUESTO_RAFAGA_MS, MINIMO_LLAMADA_MS,
  armarPrefijo, armarEntrada, normalizarPropuesta, leerRespuesta, usoDe, sha256, versionDelPrompt, salud, sinLlaves,
};

if (G.Deno?.serve) {
  const puerto = Number(env("MXP_PUERTO") || 0);
  if (puerto) G.Deno.serve({ port: puerto, hostname: "127.0.0.1" }, atender);
  else G.Deno.serve(atender);
}
