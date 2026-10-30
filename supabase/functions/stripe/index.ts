// ============================================================
// STRIPE — los cobros en línea (p1): enlaces de pago, avisos de Stripe y
// los depósitos de Stripe a Chase
//
// Dónde se pega (2 minutos):
//   Supabase → Edge Functions → Deploy a new function → «Via Editor» →
//   nombre «stripe» → borrar el ejemplo y pegar este archivo entero →
//   Deploy, con «Verify JWT» («Enforce JWT verification») APAGADO, como
//   plaid y notificar: Stripe y la rutina no traen sesión. El aviso de
//   Stripe se protege con su firma, la rutina con su secreto y lo de Edgar
//   con su sesión, que esta función comprueba ella misma (dueño y código
//   del teléfono, aal2).
//
// ANTES de desplegar, en Edge Functions → Secrets tienen que existir:
//   STRIPE_SECRET_KEY      la llave RESTRINGIDA de Stripe (rk_live_…). Una
//                          llave secreta (sk_…) se rechaza: la función solo
//                          necesita escribir Payment Links y leer lo demás.
//   STRIPE_WEBHOOK_SECRET  el «Signing secret» del endpoint (whsec_…)
//   STRIPE_RUTINA_SECRETO  el que enseña p1-stripe.sql al pegarlo (Vault:
//                          stripe_rutina_secreto)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY y SUPABASE_DB_URL los pone
//   Supabase solo. Si falta algo obligatorio contesta 500 y no hace nada;
//   …/functions/v1/stripe?paso=salud dice QUÉ falta sin enseñar nada.
//
// Qué hace: es la ÚNICA que habla con Stripe (la llave no sale de aquí).
//   · Stripe avisa (cabecera Stripe-Signature): se verifica la firma
//     (HMAC-SHA256 del cuerpo CRUDO con el whsec, 5 minutos de tolerancia,
//     comparación en tiempo constante), se GUARDA el aviso en la base
//     (fn_stripe_evento_guardar) y se contesta 200. Después se pide a
//     Stripe el objeto VIVO (el pago, el depósito) y la base aplica el
//     estado de hoy (fn_stripe_pago_sincronizar, fn_stripe_payout_
//     sincronizar). Lo que falla queda «reintentar» o «revisar» en la base,
//     y la rutina lo recoge: nada se pierde en silencio y nada entra dos
//     veces (Stripe repite y desordena los avisos).
//   · La rutina (pg_cron cada 15 min → fn_stripe_programado → pg_net, con
//     la cabecera x-mxp-rutina): «barrer» lo pendiente, lo que Stripe no
//     entregó, los depósitos por casar y los enlaces por terminar o revisar.
//   · Edgar, con su sesión de dueño en aal2: estado, probar_llave,
//     crear_enlace, desactivar_enlace, resolver_pago, resolver_linea,
//     payout_fuera («Ya está en el libro»), casar_payout, reprocesar,
//     aviso_visto y barrer.
//   Cada llamada a Stripe lleva Stripe-Version fija y cada POST su
//   Idempotency-Key. Nada de la API de Stripe se ejecuta desde la app.
//
// A la base entra DIRECTO, como postgres, por SUPABASE_DB_URL (MXP_DB_URL
// manda si existe), cada llamada en su transacción. Ninguna fn_stripe_* está
// en la API (p1-stripe.sql): solo esta función, pg_cron y el SQL Editor las
// ejecutan. Lo que registran en el libro lo registran EN NOMBRE DEL DUEÑO
// (la base lo hace, como fn_plaid_recibir).
//
// Lo que NO está en el repositorio: ninguna llave. Solo en el banco de
// pruebas (esBancoDePruebas: MXP_BANCO_PRUEBAS=1 Y la base en 127.0.0.1 por
// MXP_DB_URL Y sin SUPABASE_DB_URL Y fuera de Supabase; en Supabase nunca se
// cumple, y si alguien pone MXP_BANCO_PRUEBAS en Secrets la función contesta
// 500 CONFIG y no hace nada): la sesión se lee sin verificar la firma,
// STRIPE_BASE_URL apunta al Stripe simulado (pruebas/conta/stripe-
// simulado.mjs), MXP_PUERTO sirve en 127.0.0.1 y la base se puede inyectar
// (usarBaseDePruebas). El archivo también corre en
// Node 22 (las pruebas sin Deno): por eso lee el entorno con env() y carga
// npm:postgres y supabase-js dentro de abrirBase.
// ============================================================

type Json = Record<string, unknown>;

// deno-lint-ignore no-explicit-any
const G = globalThis as any;
function env(k: string): string {
  const v = G.Deno?.env?.get?.(k) ?? G.process?.env?.[k];
  return typeof v === "string" ? v : "";
}

const STRIPE_VERSION = "2026-09-30.endive";
const TOLERANCIA = 300; // segundos, como stripe-node
const MAX_CUERPO = 1_000_000;
const PRESUPUESTO_BARRIDO_MS = 45_000;
const EVENTOS = [
  "checkout.session.completed", "checkout.session.async_payment_succeeded", "checkout.session.async_payment_failed",
  "payment_intent.processing", "payment_intent.succeeded", "payment_intent.payment_failed", "payment_intent.canceled",
  "charge.refunded", "refund.created", "refund.updated", "refund.failed",
  "charge.dispute.created", "charge.dispute.funds_withdrawn", "charge.dispute.funds_reinstated", "charge.dispute.closed",
  "payout.paid", "payout.failed", "payout.canceled", "payout.reconciliation_completed", "payment_link.updated",
];
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-mxp-rutina, stripe-signature",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
// Lo que ve el CLIENTE va solo en inglés (regla de Edgar, 30-oct: todo lo que
// ve un cliente —facturas, scope of work, pagos— sale en inglés).
const EMPRESA = "Max Power Electrical Solutions, Inc.";
const GRACIAS = "Thank you — we received your payment for invoice %N. "
  + "Bank account (ACH) payments take a few business days to clear.";
const INACTIVO = `This payment link is no longer active. Please contact ${EMPRESA} for a new one.`;

// La configuración se lee en cada llamada (el entorno no cambia en Supabase;
// en las pruebas sin Deno sí).
interface Conf {
  llave: string; whsec: string; rutina: string; modo: "real" | "prueba" | null; base_url: string; db: string;
  supabase_url: string; service_key: string; banco_pruebas: boolean; banco_mal: string | null;
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
  const llave = env("STRIPE_SECRET_KEY").trim();
  return {
    llave, whsec: env("STRIPE_WEBHOOK_SECRET").trim(), rutina: env("STRIPE_RUTINA_SECRETO").trim(),
    modo: /^rk_live_/.test(llave) ? "real" : /^rk_test_/.test(llave) ? "prueba" : null,
    base_url: (banco && env("STRIPE_BASE_URL") ? env("STRIPE_BASE_URL") : "https://api.stripe.com").replace(/\/$/, ""),
    db: (banco ? env("MXP_DB_URL") : "") || env("SUPABASE_DB_URL"),
    supabase_url: env("SUPABASE_URL"), service_key: env("SUPABASE_SERVICE_ROLE_KEY"), banco_pruebas: banco, banco_mal: b.mal,
  };
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
// Compara sin delatar por el tiempo cuántos caracteres acertó quien prueba.
function igual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
const MIAMI = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" });
function diaMiami(unix: unknown): string | null {
  return typeof unix === "number" && Number.isFinite(unix) ? MIAMI.format(new Date(unix * 1000)) : null;
}
// La llegada de un depósito: Stripe la da a medianoche UTC; su día es el UTC.
function diaUTC(unix: unknown): string | null {
  return typeof unix === "number" && Number.isFinite(unix) ? new Date(unix * 1000).toISOString().slice(0, 10) : null;
}
function limpiar(o: Json): Json {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined && v !== null && v !== ""));
}
function responder(cuerpo: Json, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, "Content-Type": "application/json" } });
}
function dormir(ms: number): Promise<void> { return new Promise((r) => setTimeout(r, ms)); }
function texto(v: unknown): string | null { return typeof v === "string" && v ? v : null; }
// Un campo expandible de Stripe: el id, venga como texto o como objeto.
function idDe(v: unknown): string | null {
  if (typeof v === "string" && v) return v;
  if (v && typeof v === "object" && typeof (v as Json).id === "string") return (v as Json).id as string;
  return null;
}
function obj(v: unknown): Json { return v && typeof v === "object" && !Array.isArray(v) ? v as Json : {}; }
function arr(v: unknown): Json[] { return Array.isArray(v) ? v.filter((x) => x && typeof x === "object") as Json[] : []; }
function num(v: unknown): number | null { return typeof v === "number" && Number.isFinite(v) ? v : null; }
// Ninguna llave sale en un mensaje (Stripe a veces repite un trozo).
function sinLlaves(s: string): string {
  return s.replace(/\b(rk|sk|pk)_(live|test)_[A-Za-z0-9*]+/g, "[llave]").replace(/\bwhsec_[A-Za-z0-9]+/g, "[secreto]");
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

// ---- La firma de Stripe ---------------------------------------------------
// Como stripe-node (Webhooks.ts): «t=…,v1=…[,v1=…]», HMAC-SHA256 en hex de
// `${t}.${cuerpo crudo}` con el whsec COMPLETO como llave; basta una v1; v0
// se ignora. Aquí la tolerancia se mira en los dos sentidos.
const te = new TextEncoder();
function hexABytes(h: string) {
  if (!/^[0-9a-f]{64}$/i.test(h)) return null;
  const b = new Uint8Array(new ArrayBuffer(32));
  for (let i = 0; i < 32; i++) b[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return b;
}
async function verificarFirma(crudo: string, cabecera: string | null, secreto: string, ahora = Math.floor(Date.now() / 1000)):
  Promise<{ ok: boolean; motivo?: string; t?: number }> {
  let t: number | null = null;
  const v1: string[] = [];
  for (const parte of (cabecera ?? "").split(",")) {
    const i = parte.indexOf("=");
    if (i < 0) continue;
    const k = parte.slice(0, i).trim(), v = parte.slice(i + 1).trim();
    if (k === "t") t = /^\d{1,12}$/.test(v) ? Number(v) : null;
    else if (k === "v1") v1.push(v);
  }
  if (t === null || !v1.length) return { ok: false, motivo: "cabecera mal formada" };
  if (Math.abs(ahora - t) > TOLERANCIA) return { ok: false, motivo: "fuera de tolerancia (más de 5 minutos)" };
  if (!secreto) return { ok: false, motivo: "sin secreto" };
  const llave = await crypto.subtle.importKey("raw", te.encode(secreto), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const datos = te.encode(`${t}.${crudo}`);
  for (const h of v1) {
    const f = hexABytes(h);
    // crypto.subtle.verify compara en tiempo constante
    if (f && await crypto.subtle.verify("HMAC", llave, f, datos)) return { ok: true, t };
  }
  return { ok: false, motivo: "ninguna firma v1 coincide" };
}

// ---- Stripe -----------------------------------------------------------------
// form-urlencoded con corchetes: a[b][0][c]=…; las llaves de cada objeto en
// orden (el mismo pedido da el mismo cuerpo: la Idempotency-Key lo exige).
function formulario(o: unknown, pre = "", out: [string, string][] = []): [string, string][] {
  if (o === undefined || o === null) return out;
  if (Array.isArray(o)) { o.forEach((v, i) => formulario(v, `${pre}[${i}]`, out)); return out; }
  if (typeof o === "object") {
    for (const k of Object.keys(o as Json).sort()) formulario((o as Json)[k], pre ? `${pre}[${k}]` : k, out);
    return out;
  }
  if (pre) out.push([pre, typeof o === "boolean" ? (o ? "true" : "false") : String(o)]);
  return out;
}
function falloDeStripe(estado: number, j: Json, ruta: string): Fallo {
  const err = obj(j.error);
  const msg = sinLlaves(String(err.message ?? `HTTP ${estado}`)).slice(0, 400);
  const rak = msg.match(/rak_[a-z_]+/)?.[0];
  const donde = ruta.split("?")[0];
  if (estado === 401) {
    return new Fallo(502, `La llave de Stripe no vale (Stripe contestó 401 en ${donde}): revisa STRIPE_SECRET_KEY en Supabase → Edge Functions → Secrets.`, "STRIPE_LLAVE");
  }
  if (estado === 403 || rak) {
    return new Fallo(502, `A la llave de Stripe le falta un permiso: ${rak ?? "(Stripe no dijo cuál)"} (${donde}). Actívalo en Stripe → Developers → API keys.`,
                     "STRIPE_PERMISO", limpiar({ rak }));
  }
  if (estado === 404 && err.code === "resource_missing") return new Fallo(502, `Stripe no conoce eso (${donde}): ${msg}`, "STRIPE_NO_EXISTE");
  if (err.type === "idempotency_error") return new Fallo(502, `Stripe rechazó la repetición del pedido (${donde}): ${msg}`, "STRIPE_IDEMPOTENCIA");
  return new Fallo(502, `Stripe ${donde}: ${msg}`, `STRIPE_${String(err.code ?? estado).toUpperCase()}`);
}
async function stripe(metodo: "GET" | "POST", ruta: string, params: Json = {}, idem?: string): Promise<Json> {
  const c = conf();
  const cuerpo = new URLSearchParams(formulario(params)).toString();
  let url = c.base_url + ruta;
  if (metodo === "GET" && cuerpo) url += (ruta.includes("?") ? "&" : "?") + cuerpo;
  const headers: Record<string, string> = { "Authorization": `Bearer ${c.llave}`, "Stripe-Version": STRIPE_VERSION };
  if (metodo === "POST") {
    if (!idem) throw new Fallo(500, "Un POST a Stripe sin Idempotency-Key no se manda.", "CONFIG");
    headers["Idempotency-Key"] = idem;
    headers["Content-Type"] = "application/x-www-form-urlencoded";
  }
  const esperas = c.banco_pruebas ? [20, 60, 120] : [400, 1200, 3600];
  const caido = (por: string) => new Fallo(503, `Stripe no contestó (${ruta.split("?")[0]}: ${por}).`, "STRIPE_CAIDO");
  let ultimo = caido("sin intento");
  for (let intento = 0; intento <= esperas.length; intento++) {
    if (intento > 0) await dormir(esperas[intento - 1]);
    const ctl = new AbortController();
    const reloj = setTimeout(() => ctl.abort(), 20_000);
    let r: Response, crudo: string;
    try {
      r = await fetch(url, { method: metodo, headers, body: metodo === "POST" ? cuerpo : undefined, signal: ctl.signal });
      crudo = await r.text();
    } catch (e) {
      ultimo = caido(e instanceof Error && e.name === "AbortError" ? "20 s sin respuesta" : "sin conexión");
      continue;
    } finally { clearTimeout(reloj); }
    let j: Json = {};
    try { j = JSON.parse(crudo); } catch { /* no era JSON */ }
    if (r.ok) return j;
    const debe = r.headers.get("stripe-should-retry");
    if ((r.status === 429 || r.status >= 500 || debe === "true") && debe !== "false") { ultimo = caido(`HTTP ${r.status}`); continue; }
    throw falloDeStripe(r.status, j, ruta);
  }
  throw ultimo;
}
// Una lista entera de Stripe (starting_after mientras has_more; 50 páginas tope).
async function lista(ruta: string, params: Json = {}): Promise<Json[]> {
  const todo: Json[] = [];
  let despues: string | null = null;
  for (let pagina = 0; pagina < 50; pagina++) {
    const r = await stripe("GET", ruta, despues ? { ...params, starting_after: despues } : params);
    const datos = arr(r.data);
    todo.push(...datos);
    if (!r.has_more || !datos.length) break;
    despues = idDe(datos[datos.length - 1]);
    if (!despues) break;
  }
  return todo;
}

// ---- La base -----------------------------------------------------------
// Directo a Postgres, como postgres: cada llamada en su transacción. Las
// fn_stripe_* exigen eso (fn_desde_editor) y no están en la API.
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
      // los objetos van tal cual: postgres.js los vuelve JSON cuando la base dice que el parámetro es jsonb
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
// Solo el banco de pruebas: la base de mentira (psql) de stripe-e2e.mjs.
export function usarBaseDePruebas(b: Base): void {
  if (!esBancoDePruebas().vale) throw new Error("usarBaseDePruebas es solo del banco de pruebas (MXP_BANCO_PRUEBAS=1, la base en 127.0.0.1).");
  baseLista = Promise.resolve(b);
}

// ---- Lo que se le da a la base -------------------------------------------
// Pistas que trae el aviso (la sesión de pago) y que el pago no dice.
interface Pistas { sesion?: string | null; plink?: string | null; sesion_completa?: boolean; fechaExito?: string | null; disputa?: boolean }
function medioDe(tipo: unknown): string | null {
  return tipo === "card" ? "tarjeta" : tipo === "us_bank_account" ? "ach" : typeof tipo === "string" && tipo ? "otro" : null;
}
const META = ["mxp", "enlace", "factura_id", "factura", "retencion"];
// La foto de un pago (centavos), en la forma de fn_stripe_pago_sincronizar.
function armarFotoPago(pi: Json, cargos: Json[], reembolsos: Json[], disputas: Json[], pistas: Pistas, vistoEl: string): Json {
  const meta = obj(pi.metadata);
  const lpe = obj(pi.last_payment_error);
  const fotosCargo = cargos.map((c) => {
    const bt = obj(c.balance_transaction);
    return limpiar({
      id: c.id, estado: c.status, medio: medioDe(obj(c.payment_method_details).type), bt: idDe(c.balance_transaction),
      bt_fallo: idDe(c.failure_balance_transaction), creado: num(c.created), monto: num(c.amount), disputado: c.disputed === true,
      disponible: num(bt.available_on),
    });
  });
  const ultimo = fotosCargo.find((c) => c.id === idDe(pi.latest_charge)) ?? fotosCargo[fotosCargo.length - 1];
  const accion = obj(pi.next_action);
  const medio = (ultimo?.medio as string | undefined)
    ?? medioDe(lpe.payment_method_type)
    ?? (accion.type === "verify_with_microdeposits" ? "ach" : null);
  return {
    pi: pi.id, visto_el: vistoEl, estado: pi.status, monto: num(pi.amount) ?? 0, recibido: num(pi.amount_received) ?? 0,
    moneda: typeof pi.currency === "string" ? pi.currency : "usd", livemode: pi.livemode === true, creado: num(pi.created),
    metadata: Object.fromEntries(META.filter((k) => typeof meta[k] === "string").map((k) => [k, meta[k]])),
    plink: pistas.plink ?? null, sesion: pistas.sesion ?? null, sesion_completa: pistas.sesion_completa === true,
    medio, cargo: idDe(pi.latest_charge), fecha_exito: pistas.fechaExito ?? null,
    cargos: fotosCargo,
    reembolsos: reembolsos.map((r) => ({
      id: r.id, monto: num(r.amount) ?? 0, estado: r.status, creado: num(r.created), bt: idDe(r.balance_transaction),
      bt_fallo: idDe(r.failure_balance_transaction), motivo_fallo: texto(r.failure_reason),
    })),
    disputas: disputas.map((d) => limpiar({
      id: d.id, monto: num(d.amount) ?? 0, estado: d.status, motivo: texto(d.reason), vence: num(obj(d.evidence_details).due_by),
      bts: arr(d.balance_transactions).map((b) => ({ id: b.id, categoria: b.reporting_category, monto: num(b.amount) ?? 0, comision: num(b.fee) ?? 0, creado: num(b.created) })),
    })),
    // (el código: el del banco si lo hay —insufficient_funds, account_closed…—; la base lo dice en llano)
    ultimo_error: pi.last_payment_error ? limpiar({
      codigo: lpe.decline_code ?? texto(cargos.find((c) => c.id === idDe(pi.latest_charge))?.failure_code) ?? lpe.code,
      mensaje: texto(lpe.message) }) : null,
    cancelacion: texto(pi.cancellation_reason),
  };
}
// La foto de un depósito, en la forma de fn_stripe_payout_sincronizar.
function armarFotoPayout(po: Json, vistoEl: string): Json {
  return {
    po: po.id, visto_el: vistoEl, estado: po.status, monto: num(po.amount) ?? 0, moneda: typeof po.currency === "string" ? po.currency : "usd",
    llegada: diaUTC(po.arrival_date), automatico: po.automatic !== false, metodo: typeof po.method === "string" ? po.method : "standard",
    conciliacion: texto(po.reconciliation_status), bt_propio: idDe(po.balance_transaction), bt_fallo: idDe(po.failure_balance_transaction),
    fallo_codigo: texto(po.failure_code), creado: num(po.created),
  };
}
// El pago de una balance transaction: el de su origen (cargo, reembolso o
// disputa); los depósitos y las comisiones sueltas no tienen.
function piDeFuente(fuente: unknown): string | null {
  const f = obj(fuente);
  const pi = idDe(f.payment_intent);
  if (pi) return pi;
  const cargo = obj(f.charge);
  return idDe(cargo.payment_intent);
}
function armarLineas(bts: Json[]): Json[] {
  return bts.map((b) => limpiar({
    txn: b.id, tipo: b.type, categoria: texto(b.reporting_category), monto: num(b.amount) ?? 0, comision: num(b.fee) ?? 0,
    neto: num(b.net), fuente: idDe(b.source), pi: piDeFuente(b.source), creado: num(b.created), disponible: num(b.available_on),
  }));
}

// ---- Sincronizar un pago y un depósito -----------------------------------
async function syncPago(base: Base, pi: string, pistas: Pistas, evento: string | null): Promise<Json> {
  const vistoEl = new Date().toISOString(); // ANTES de pedir: una foto vieja no toca nada
  const p = await stripe("GET", `/v1/payment_intents/${encodeURIComponent(pi)}`);
  const cargos = await lista("/v1/charges", { payment_intent: pi, limit: 100, expand: ["data.balance_transaction"] });
  const reembolsos = await lista("/v1/refunds", { payment_intent: pi, limit: 100 });
  const disputas = (pistas.disputa || cargos.some((c) => c.disputed === true))
    ? await lista("/v1/disputes", { payment_intent: pi, limit: 100 }) : [];
  const meta = obj(p.metadata);
  const pist = { ...pistas };
  if (!pist.plink && !(meta.mxp === "p1" && typeof meta.enlace === "string")) {
    // un pago sin nuestros metadatos: ¿salió de un enlace? (su sesión lo dice)
    try {
      const s = (await stripe("GET", "/v1/checkout/sessions", { payment_intent: pi, limit: 1 })).data as Json[] | undefined;
      const s0 = s?.[0];
      if (s0) { pist.plink = idDe(s0.payment_link); pist.sesion = pist.sesion ?? idDe(s0); pist.sesion_completa = pist.sesion_completa || s0.status === "complete"; }
    } catch (e) { if (e instanceof Fallo && e.codigo === "STRIPE_CAIDO") throw e; }
  }
  const foto = armarFotoPago(p, cargos, reembolsos, disputas, pist, vistoEl);
  return await base.rpc("fn_stripe_pago_sincronizar", { p_foto: foto, p_evento: evento }) as Json;
}
function resumenPago(r: Json): Json {
  return limpiar({ estado: r.estado, antes: r.antes, objetivo: r.objetivo, en_libro: r.en_libro, cambios: Array.isArray(r.cambios) ? r.cambios.length : undefined,
                   ignorado: r.ignorado, viejo: r.viejo });
}
async function syncPayout(base: Base, po: string, evento: string | null, rehacer = false, hondo = 0): Promise<Json> {
  const vistoEl = new Date().toISOString();
  const p = await stripe("GET", `/v1/payouts/${encodeURIComponent(po)}`);
  const foto = armarFotoPayout(p, vistoEl);
  // Primero sin la composición (si ya la tiene, o ya está asentado, no hace falta pedirla)
  let r = await base.rpc("fn_stripe_payout_sincronizar", { p_foto: foto, p_lineas: null, p_evento: evento, p_rehacer: rehacer }) as Json;
  const componible = p.automatic !== false && (p.status === "failed" || p.status === "canceled" || (p.status === "paid" && p.reconciliation_status === "completed"));
  if (componible && (r.estado === "esperando_composicion" || (r.estado === "revisar" && /sin el detalle/.test(String(r.revisar ?? ""))))) {
    const bts = await lista("/v1/balance_transactions", { payout: po, limit: 100, expand: ["data.source"] });
    r = await base.rpc("fn_stripe_payout_sincronizar", { p_foto: foto, p_lineas: armarLineas(bts), p_evento: evento, p_rehacer: false }) as Json;
  }
  const notas: string[] = [];
  if (r.estado === "esperando_cobros" && Array.isArray(r.esperando) && hondo < 1) {
    // los pagos que le faltan al libro (un aviso perdido, un reembolso nuevo): se piden, y otra vez
    for (const x of r.esperando as Json[]) {
      try {
        if (typeof x.pi === "string") await syncPago(base, x.pi, {}, evento);
        else if (typeof x.po === "string") await syncPayout(base, x.po, evento, false, hondo + 1);
      } catch (e) { notas.push(`${x.pi ?? x.po}: ${mensajeDe(e)}`); }
    }
    r = await base.rpc("fn_stripe_payout_sincronizar", { p_foto: foto, p_lineas: null, p_evento: evento, p_rehacer: false }) as Json;
  }
  let casado: Json | undefined;
  if (r.estado === "asentado") {
    // en SU transacción (c6 toma el candado del casado antes que la cadena)
    try { casado = await base.rpc("fn_stripe_payout_casar", { p_po: po, p_movimiento: null }) as Json; }
    catch (e) { notas.push(`casar: ${mensajeDe(e)}`); }
  }
  return limpiar({ ...r, casado, notas: notas.length ? notas : undefined });
}
function resumenPayout(r: Json): Json {
  return limpiar({ estado: r.estado, antes: r.antes, revisar: r.revisar, esperando: r.esperando, casado: obj(r.casado).casado, ignorado: r.ignorado, viejo: r.viejo });
}

// ---- Los avisos de Stripe -------------------------------------------------
interface Evento { id: string; tipo: string; created: number; livemode: boolean; objeto: Json; previos?: Json; api_version?: string | null }
function deStripe(ev: Json): Evento {
  const data = obj(ev.data);
  return { id: String(ev.id), tipo: String(ev.type), created: num(ev.created) ?? 0, livemode: ev.livemode === true,
           objeto: obj(data.object), previos: data.previous_attributes ? obj(data.previous_attributes) : undefined,
           api_version: texto(ev.api_version) };
}
async function guardar(base: Base, ev: Evento, por: string): Promise<Json> {
  // (la versión con que Stripe mandó el aviso: la del endpoint; la base avisa si no es la que espera)
  return await base.rpc("fn_stripe_evento_guardar", {
    p_evento: { id: ev.id, tipo: ev.tipo, livemode: ev.livemode, api_version: ev.api_version ?? null, created: ev.created, objeto: ev.objeto, previos: ev.previos ?? null },
    p_por: por, p_modo: conf().modo,
  }) as Json;
}
async function procesarEvento(base: Base, ev: Evento): Promise<{ estado: "hecho" | "ignorado"; resumen: Json }> {
  const o = ev.objeto, t = ev.tipo;
  try {
    if (t.startsWith("checkout.session.")) {
      const pi = idDe(o.payment_intent);
      if (!pi) return { estado: "ignorado", resumen: { motivo: "la sesión no tiene pago" } };
      const exito = (t === "checkout.session.completed" && o.payment_status === "paid") || t === "checkout.session.async_payment_succeeded";
      const r = await syncPago(base, pi, { sesion: idDe(o), plink: idDe(o.payment_link), sesion_completa: o.status === "complete",
                                            fechaExito: exito ? diaMiami(ev.created) : null }, ev.id);
      return { estado: "hecho", resumen: { pi, ...resumenPago(r) } };
    }
    if (t.startsWith("payment_intent.")) {
      const pi = idDe(o);
      if (!pi) return { estado: "ignorado", resumen: { motivo: "sin pago" } };
      const r = await syncPago(base, pi, { fechaExito: t === "payment_intent.succeeded" ? diaMiami(ev.created) : null }, ev.id);
      return { estado: "hecho", resumen: { pi, ...resumenPago(r) } };
    }
    if (t.startsWith("charge.") || t.startsWith("refund.")) {
      let pi = idDe(o.payment_intent);
      if (!pi && idDe(o.charge)) pi = idDe((await stripe("GET", `/v1/charges/${encodeURIComponent(idDe(o.charge) as string)}`)).payment_intent);
      if (!pi) return { estado: "ignorado", resumen: { motivo: "sin pago" } };
      const r = await syncPago(base, pi, { disputa: t.startsWith("charge.dispute.") }, ev.id);
      return { estado: "hecho", resumen: { pi, ...resumenPago(r) } };
    }
    if (t.startsWith("payout.")) {
      const po = idDe(o);
      if (!po) return { estado: "ignorado", resumen: { motivo: "sin depósito" } };
      const r = await syncPayout(base, po, ev.id);
      return { estado: "hecho", resumen: { po, ...resumenPayout(r) } };
    }
    if (t === "payment_link.updated") {
      const plink = idDe(o);
      if (!plink || o.active !== false) return { estado: "ignorado", resumen: { motivo: "el enlace sigue activo" } };
      const cs = obj(obj(o.restrictions).completed_sessions);
      const usado = typeof cs.count === "number" && typeof cs.limit === "number" && cs.count >= cs.limit;
      const r = await base.rpc("fn_stripe_enlace_desactivado", { p_plink: plink, p_motivo: "desactivado en Stripe", p_por: "stripe", p_usado: usado }) as Json;
      return { estado: r.ignorado ? "ignorado" : "hecho", resumen: { plink, estado: r.estado ?? null } };
    }
    return { estado: "ignorado", resumen: { motivo: `aviso que la app no usa (${t})` } };
  } catch (e) {
    // un objeto que Stripe no conoce (un aviso de prueba del panel, algo borrado)
    if (e instanceof Fallo && e.codigo === "STRIPE_NO_EXISTE") return { estado: "ignorado", resumen: { motivo: e.message } };
    throw e;
  }
}
const TRANSITORIOS = new Set(["40001", "40P01", "55P03", "57014", "STRIPE_CAIDO", "BASE"]);
function esTransitorio(e: unknown): boolean {
  if (!(e instanceof Fallo)) return true;
  if (TRANSITORIOS.has(e.codigo ?? "")) return true;
  if (e.codigo === "MX002" && /no se abri/i.test(e.message)) return true;
  return e.estado >= 500 && !(e.codigo ?? "").startsWith("STRIPE_");
}
async function procesarYcerrar(base: Base, ev: Evento): Promise<Json> {
  try {
    const r = await procesarEvento(base, ev);
    const c = await base.rpc("fn_stripe_evento_cerrar", { p_id: ev.id, p_estado: r.estado, p_resultado: r.resumen, p_error: null, p_codigo: null }) as Json;
    return { evento: ev.id, tipo: ev.tipo, estado: c?.estado ?? r.estado, resultado: r.resumen };
  } catch (e) {
    const estado = esTransitorio(e) ? "reintentar" : "revisar";
    const codigo = e instanceof Fallo ? e.codigo ?? null : null;
    const msg = mensajeDe(e);
    try {
      const c = await base.rpc("fn_stripe_evento_cerrar", { p_id: ev.id, p_estado: estado, p_resultado: null, p_error: msg, p_codigo: codigo }) as Json;
      return { evento: ev.id, tipo: ev.tipo, estado: c?.estado ?? estado, error: msg, codigo };
    } catch (e2) {
      // queda «recibido»: la rutina lo recoge
      console.error(`stripe: no se pudo cerrar el aviso ${ev.id} (${codigo ?? "?"}): ${mensajeDe(e2).slice(0, 200)}`);
      return { evento: ev.id, tipo: ev.tipo, estado: "recibido", error: msg, codigo };
    }
  }
}

// ---- Los enlaces de pago ---------------------------------------------------
function cargaEnlace(p: Json): Json {
  const num = String(p.factura_num);
  const meta = obj(p.metadata);
  const ret = p.con_retencion === true;
  return {
    line_items: [{
      price_data: { currency: "usd", unit_amount: Number(p.centavos),
                    product_data: { name: `Invoice ${num} · ${EMPRESA}${ret ? " (incl. retainage)" : ""}` } },
      quantity: 1,
    }],
    // el orden («ACH primero») no se impone en Payment Links: Stripe ordena; esto solo restringe
    payment_method_types: ["us_bank_account", "card"],
    restrictions: { completed_sessions: { limit: 1 } },
    metadata: meta,
    payment_intent_data: { metadata: meta, description: `Invoice ${num} — ${EMPRESA}` },
    after_completion: { type: "hosted_confirmation", hosted_confirmation: { custom_message: GRACIAS.replaceAll("%N", num) } },
    inactive_message: INACTIVO,
  };
}
function usadoDe(link: Json): boolean {
  const cs = obj(obj(link.restrictions).completed_sessions);
  return typeof cs.count === "number" && typeof cs.limit === "number" && cs.count >= cs.limit;
}
async function crearEnStripe(base: Base, p: Json): Promise<{ link: Json; fila: Json }> {
  const link = await stripe("POST", "/v1/payment_links", cargaEnlace(p), String(p.idempotencia));
  const fila = await base.rpc("fn_stripe_enlace_creado", {
    p_enlace: p.enlace, p_link: { id: link.id, url: link.url, livemode: link.livemode, active: link.active, metadata: link.metadata },
  }) as Json;
  return { link, fila };
}
async function desactivarEnStripe(base: Base, enlaceId: string, plink: string, motivo: string, por: string): Promise<Json> {
  const link = await stripe("POST", `/v1/payment_links/${encodeURIComponent(plink)}`, { active: false }, `mxp-baja-${enlaceId}`);
  return await base.rpc("fn_stripe_enlace_desactivado", { p_plink: plink, p_motivo: motivo, p_por: por, p_usado: usadoDe(link) }) as Json;
}
async function crearEnlace(base: Base, dueno: string, cuerpo: Json): Promise<Response> {
  const fid = typeof cuerpo.factura_id === "number" ? cuerpo.factura_id
    : typeof cuerpo.factura_id === "string" && /^-?\d{1,18}$/.test(cuerpo.factura_id) ? Number(cuerpo.factura_id) : NaN;
  if (!Number.isSafeInteger(fid)) throw new Fallo(400, "Falta la factura (factura_id).", "FORMA");
  const reemplazar = cuerpo.reemplazar === true;
  for (let vuelta = 0; vuelta < 3; vuelta++) {
    const p = await base.rpc("fn_stripe_enlace_preparar", {
      p_factura: fid, p_dueno: dueno, p_modo: conf().modo, p_con_retencion: cuerpo.con_retencion === true,
      p_aunque_pagada: cuerpo.aunque_pagada === true, p_reemplazar: reemplazar,
    }) as Json;
    if (p.accion === "listo") return responder({ ok: true, nuevo: false, enlace: p.enlace, desfasado: p.desfasado === true });
    if (p.accion === "desactivar") {
      await desactivarEnStripe(base, String(p.enlace), String(p.plink), String(p.motivo ?? "reemplazado por uno nuevo"), "pantalla");
      continue; // la vuelta siguiente lo crea
    }
    if (p.accion !== "crear") throw new Fallo(500, `La base pidió algo que no sé hacer: «${p.accion}».`);
    try {
      const { link, fila } = await crearEnStripe(base, p);
      return responder({
        ok: true, nuevo: true,
        enlace: { id: p.enlace, url: link.url, plink: link.id, monto: p.monto, con_retencion: p.con_retencion === true, creado_el: new Date().toISOString() },
        factura: fila ?? null,
      });
    } catch (e) {
      if (e instanceof Fallo && e.codigo === "STRIPE_CAIDO") {
        throw new Fallo(502, "Stripe no contestó: el enlace se termina de crear solo cuando vuelva (o toca otra vez «Crear enlace»).", "STRIPE_CAIDO");
      }
      if (e instanceof Fallo && e.codigo?.startsWith("STRIPE_")) {
        try { await base.rpc("fn_stripe_enlace_fallo", { p_enlace: p.enlace, p_error: e.message }); } catch { /* se informa el original */ }
        throw new Fallo(502, e.message, e.codigo, e.detalle);
      }
      throw e;
    }
  }
  throw new Fallo(409, "No pude dejar un solo enlace vivo para esa factura: vuelve a intentarlo.", "MX008");
}

// ---- La rutina: barrer -------------------------------------------------------
async function barrer(base: Base, por: "barrido" | "pantalla"): Promise<Json> {
  const t0 = Date.now();
  const resumen: Json = {};
  const errores: string[] = [];
  let incompleto = false;
  const tiempo = () => { if (Date.now() - t0 > PRESUPUESTO_BARRIDO_MS) { incompleto = true; return false; } return true; };
  const anotar = (donde: string, e: unknown) => errores.push(`${donde}: ${mensajeDe(e).slice(0, 300)}`);
  let k: Json = {};
  try { k = await base.rpc("fn_stripe_pendientes", { p_limite: 50 }) as Json; }
  catch (e) { throw falloDeLaBase(e); }
  const completo = k.completo_toca === true;
  // 1. los avisos guardados que faltan por procesar
  let n = 0;
  for (const e of arr(k.eventos)) {
    if (!tiempo()) break;
    const datos = obj(e.datos);
    const r = await procesarYcerrar(base, { id: String(e.id), tipo: String(e.tipo), created: num(e.created) ?? 0, livemode: e.livemode === true,
                                            objeto: obj(datos.objeto), previos: datos.previos ? obj(datos.previos) : undefined });
    if (r.estado === "hecho" || r.estado === "ignorado") n++;
    else if (r.error) errores.push(`${e.id}: ${r.error}`);
  }
  resumen.eventos = n;
  // 2. cada hora: lo que Stripe no entregó, los depósitos y los enlaces activos
  if (completo && tiempo()) {
    try {
      const evs = await lista("/v1/events", { types: EVENTOS, created: { gte: k.eventos_desde }, delivery_success: false, limit: 100 });
      let m = 0;
      for (const ev of evs) {
        if (!tiempo()) break;
        const e = deStripe(ev);
        const g = await guardar(base, e, "barrido");
        if (g.estado === "recibido" || g.estado === "reintentar") { await procesarYcerrar(base, e); m++; }
      }
      resumen.no_entregados = m;
    } catch (e) { anotar("avisos no entregados", e); }
    try {
      const pos = await lista("/v1/payouts", { created: { gte: k.payouts_desde }, limit: 100 });
      let m = 0;
      for (const p of pos) {
        if (!tiempo()) break;
        if (!["paid", "failed", "canceled"].includes(String(p.status))) continue;
        try { await syncPayout(base, String(p.id), null); m++; } catch (e) { anotar(String(p.id), e); }
      }
      resumen.depositos_vistos = m;
    } catch (e) { anotar("depósitos", e); }
    let m = 0;
    for (const en of arr(k.enlaces_activos)) {
      if (!tiempo()) break;
      try {
        const link = await stripe("GET", `/v1/payment_links/${encodeURIComponent(String(en.plink))}`);
        const cs = obj(obj(link.restrictions).completed_sessions);
        if (typeof cs.count === "number" && cs.count > 0) {
          // pagado sin aviso: sus sesiones dicen el pago
          for (const s of await lista("/v1/checkout/sessions", { payment_link: en.plink, limit: 10 })) {
            const pi = idDe(s.payment_intent);
            if (pi) { await syncPago(base, pi, { sesion: idDe(s), plink: String(en.plink), sesion_completa: s.status === "complete" }, null); m++; }
          }
        }
        if (link.active === false) {
          await base.rpc("fn_stripe_enlace_desactivado", { p_plink: en.plink, p_motivo: "desactivado en Stripe", p_por: "stripe", p_usado: usadoDe(link) });
        }
      } catch (e) { anotar(String(en.plink), e); }
    }
    resumen.enlaces_mirados = m;
  }
  // 3. los enlaces que Stripe dio por usados y cuyo pago no llegó (sus
  //    avisos van detrás o se perdieron): sus sesiones dicen el pago
  n = 0;
  for (const en of arr(k.enlaces_usados)) {
    if (!tiempo()) break;
    try {
      for (const s of await lista("/v1/checkout/sessions", { payment_link: en.plink, limit: 10 })) {
        const pi = idDe(s.payment_intent);
        if (pi) { await syncPago(base, pi, { sesion: idDe(s), plink: String(en.plink), sesion_completa: s.status === "complete" }, null); n++; }
      }
    } catch (e) { anotar(`usado ${en.plink}`, e); }
  }
  resumen.enlaces_usados = n;
  // 3b. los pagos por volver a pedir
  n = 0;
  for (const pi of Array.isArray(k.pagos) ? k.pagos as string[] : []) {
    if (!tiempo()) break;
    try { await syncPago(base, pi, {}, null); n++; } catch (e) { anotar(pi, e); }
  }
  resumen.pagos = n;
  // 4. los depósitos sin terminar
  n = 0;
  for (const po of Array.isArray(k.payouts) ? k.payouts as string[] : []) {
    if (!tiempo()) break;
    try { await syncPayout(base, po, null); n++; } catch (e) { anotar(po, e); }
  }
  resumen.depositos = n;
  // 5. los asentados sin casar (Plaid ya trajo el depósito, o no)
  n = 0;
  for (const po of Array.isArray(k.casar) ? k.casar as string[] : []) {
    if (!tiempo()) break;
    try { const r = await base.rpc("fn_stripe_payout_casar", { p_po: po, p_movimiento: null }) as Json; if (r.casado) n++; } catch (e) { anotar(`casar ${po}`, e); }
  }
  resumen.casados = n;
  // 6. los enlaces que se quedaron a medias (Stripe no contestó)
  n = 0;
  for (const en of arr(k.enlaces_creando)) {
    if (!tiempo()) break;
    try {
      const creado = Date.parse(String(en.creado_el));
      if (Date.now() - creado < 23 * 3600_000) {
        await crearEnStripe(base, { ...en, enlace: en.id }); // la MISMA Idempotency-Key: Stripe da el mismo enlace
      } else {
        const hallado = (await lista("/v1/payment_links", { limit: 100 })).find((l) => obj(l.metadata).enlace === en.id);
        if (hallado) await base.rpc("fn_stripe_enlace_creado", { p_enlace: en.id, p_link: { id: hallado.id, url: hallado.url, livemode: hallado.livemode, metadata: hallado.metadata } });
        else await base.rpc("fn_stripe_enlace_fallo", { p_enlace: en.id, p_error: "Stripe no lo creó (se quedó a medias más de 23 horas)" });
      }
      n++;
    } catch (e) { anotar(`enlace ${en.id}`, e); }
  }
  resumen.enlaces_terminados = n;
  // 7. los enlaces vivos que ya no sirven (factura anulada, ya debe menos, un pago en camino)
  n = 0;
  for (const en of arr(k.enlaces_revisar)) {
    if (!tiempo()) break;
    try { await desactivarEnStripe(base, String(en.id), String(en.plink), String(en.motivo), "rutina"); n++; } catch (e) { anotar(`baja ${en.id}`, e); }
  }
  resumen.enlaces_desactivados = n;
  resumen.completo = completo;
  resumen.incompleto = incompleto;
  resumen.por = por;
  if (errores.length) resumen.errores = errores.slice(0, 20);
  try { await base.rpc("fn_stripe_barrido_anotar", { p_resultado: resumen, p_completo: completo && !incompleto }); }
  catch (e) { anotar("anotar", e); }
  return resumen;
}

// ---- Probar la llave ------------------------------------------------------
// Las MISMAS peticiones que la función hace de verdad (con sus expand: el
// del depósito pide el origen de cada movimiento, que es otro permiso), y
// el nombre del permiso en el panel de Stripe.
const RECURSOS: [string, string, Json, string][] = [
  ["Payment Links", "/v1/payment_links", { limit: 1 }, "Payment Links: Write"],
  ["Checkout Sessions", "/v1/checkout/sessions", { limit: 1 }, "Checkout Sessions: Read"],
  ["PaymentIntents", "/v1/payment_intents", { limit: 1 }, "PaymentIntents: Read"],
  ["Charges (con su movimiento del saldo)", "/v1/charges", { limit: 1, expand: ["data.balance_transaction"] }, "Charges: Read"],
  ["Refunds", "/v1/refunds", { limit: 1 }, "Refunds: Read"],
  ["Disputes", "/v1/disputes", { limit: 1 }, "Disputes: Read"],
  ["Payouts", "/v1/payouts", { limit: 1 }, "Payouts: Read"],
  ["Balance", "/v1/balance", {}, "Balance: Read"],
  ["Balance transactions (con su origen)", "/v1/balance_transactions", { limit: 1, expand: ["data.source"] }, "Balance transaction sources: Read"],
  ["Events", "/v1/events", { limit: 1 }, "Events: Read"],
];
const PANEL: Record<string, string> = {
  rak_payment_link_write: "Payment Links: Write", rak_payment_link_read: "Payment Links: Read",
  rak_checkout_session_read: "Checkout Sessions: Read", rak_payment_intent_read: "PaymentIntents: Read",
  rak_charge_read: "Charges: Read", rak_refund_read: "Refunds: Read", rak_dispute_read: "Disputes: Read",
  rak_payout_read: "Payouts: Read", rak_balance_read: "Balance: Read",
  rak_balance_transaction_source_read: "Balance transaction sources: Read", rak_event_read: "Events: Read",
  rak_product_write: "Products: Write", rak_price_write: "Prices: Write",
};
async function probarLlave(): Promise<Json> {
  const permisos: Json[] = [];
  let caidos = 0;
  for (const [recurso, ruta, params, panel] of RECURSOS) {
    try { await stripe("GET", ruta, params); permisos.push({ recurso, ruta, ok: true }); }
    catch (e) {
      const f = e instanceof Fallo ? e : new Fallo(500, mensajeDe(e));
      if (f.codigo === "STRIPE_CAIDO") caidos++;
      const rak = typeof f.detalle?.rak === "string" ? f.detalle.rak : undefined;
      permisos.push(limpiar({ recurso, ruta, ok: false, codigo: f.codigo, rak, panel: (rak && PANEL[rak]) || panel, error: f.message }));
    }
  }
  if (caidos === RECURSOS.length) throw new Fallo(503, "Stripe no contestó: no se pudo probar la llave. Inténtalo en un rato.", "STRIPE_CAIDO");
  const c = conf();
  return { ok: true, todos: permisos.every((p) => p.ok), modo: c.modo, restringida: /^rk_/.test(c.llave), permisos,
           nota: "La escritura de Payment Links se prueba al crear el primer enlace." };
}

// ---- Salud: qué falta, sin enseñar nada -----------------------------------
function salud(): Json {
  const c = conf();
  const falta: string[] = [];
  if (!c.llave) falta.push("STRIPE_SECRET_KEY (la llave restringida rk_live_…)");
  else if (!c.modo) falta.push("STRIPE_SECRET_KEY tiene que ser una llave RESTRINGIDA (rk_live_…), no la secreta");
  if (!c.whsec.startsWith("whsec_")) falta.push("STRIPE_WEBHOOK_SECRET (el «Signing secret» del endpoint, whsec_…)");
  if (c.rutina.length < 32) falta.push("STRIPE_RUTINA_SECRETO (el que enseña p1-stripe.sql)");
  if (!c.db) falta.push("SUPABASE_DB_URL (lo pone Supabase) o MXP_DB_URL");
  if (!c.banco_pruebas && !(c.supabase_url && c.service_key)) falta.push("SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (los pone Supabase)");
  if (c.banco_mal) falta.push(c.banco_mal);
  return {
    ok: true, modo: c.modo, llave: Boolean(c.llave), llave_restringida: /^rk_(live|test)_/.test(c.llave), webhook: c.whsec.startsWith("whsec_"),
    rutina: c.rutina.length >= 32, base: Boolean(c.db), sesion: c.banco_pruebas || Boolean(c.supabase_url && c.service_key),
    version: STRIPE_VERSION, banco_de_pruebas: c.banco_pruebas, falta,
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
    const firma = req.headers.get("stripe-signature");
    let cuerpo: Json = {};
    if (firma === null && crudo) { try { cuerpo = obj(JSON.parse(crudo)); } catch { throw new Fallo(400, "El cuerpo no es JSON.", "FORMA"); } }
    const accion = String(cuerpo.accion ?? url.searchParams.get("accion") ?? url.searchParams.get("paso") ?? "");
    if (firma === null && accion === "salud") return responder(salud());

    const c = conf();
    if (c.banco_mal) {
      console.error("stripe: hay secretos del banco de pruebas en producción (MXP_BANCO_PRUEBAS o MXP_DB_URL)");
      throw new Fallo(500, c.banco_mal, "CONFIG");
    }
    if (!c.modo || !c.whsec || !c.db || (!c.banco_pruebas && (!c.supabase_url || !c.service_key))) {
      console.error("stripe: falta configurar la función (STRIPE_SECRET_KEY restringida, STRIPE_WEBHOOK_SECRET o la base) en Edge Functions → Secrets");
      throw new Fallo(500, /^sk_/.test(c.llave) ? "Usa una llave RESTRINGIDA (rk_live_…), no la secreta: cámbiala en Supabase → Edge Functions → Secrets."
        : "Falta configurar la función (STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET o la base) en Supabase → Edge Functions → Secrets.", "CONFIG");
    }

    // 1. Stripe avisa: la firma, guardar, 200; procesar después
    if (firma !== null) {
      const v = await verificarFirma(crudo, firma, c.whsec);
      if (!v.ok) return responder({ ok: false, codigo: "FIRMA", error: `La firma de Stripe no vale: ${v.motivo}.` }, 400);
      let ev: Json;
      try { ev = obj(JSON.parse(crudo)); } catch { throw new Fallo(400, "El aviso de Stripe no es JSON.", "FORMA"); }
      if (ev.object !== "event" || typeof ev.id !== "string" || !/^evt_/.test(ev.id) || typeof ev.type !== "string") {
        throw new Fallo(400, "Eso no es un aviso de Stripe (event, evt_…).", "FORMA");
      }
      const e = deStripe(ev);
      const base = await obtenerBase();
      let g: Json;
      try { g = await guardar(base, e, "webhook"); }
      catch (err) {
        const f = falloDeLaBase(err);
        // la forma mala no se arregla reintentando; lo demás sí (Stripe vuelve a mandarlo)
        if (f.estado === 409) throw new Fallo(400, f.message, f.codigo);
        console.error(`stripe: no se pudo guardar el aviso ${e.id} (${f.codigo ?? "?"})`);
        throw new Fallo(500, "La base no guardó el aviso: Stripe lo vuelve a mandar.", f.codigo);
      }
      if (g.estado === "hecho" || g.estado === "ignorado") return responder({ ok: true, repetido: g.nuevo !== true, estado: g.estado });
      const tarea = procesarYcerrar(base, e);
      if (G.EdgeRuntime?.waitUntil && !c.banco_pruebas) {
        G.EdgeRuntime.waitUntil(tarea);
        return responder({ ok: true, recibido: true, repetido: g.nuevo !== true });
      }
      const r = await tarea;
      return responder({ ok: true, recibido: true, repetido: g.nuevo !== true, ...r });
    }

    const base = await obtenerBase();
    // 2. La rutina (pg_cron → pg_net), con su secreto
    const rutina = req.headers.get("x-mxp-rutina");
    if (rutina !== null) {
      if (c.rutina.length < 32 || !igual(rutina, c.rutina)) throw new Fallo(401, "no autorizado", "RUTINA");
      if (accion !== "barrer") throw new Fallo(400, "La rutina solo sabe «barrer».", "ACCION");
      return responder({ ok: true, resumen: await barrer(base, "barrido") });
    }

    // 3. Edgar, con su sesión de dueño y el código del teléfono
    const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!jwt) throw new Fallo(401, "Entra con tu sesión.", "SESION");
    const quien = await base.quien(jwt);
    if (!quien) throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.", "SESION");
    if (quien.rol !== "dueno" || !quien.activo) throw new Fallo(403, "Los cobros en línea los maneja solo Edgar (el dueño).", "NO_DUENO");
    // el JWT ya lo validó getUser: aquí solo se lee su aal (s1 frena PostgREST, no esta función)
    const carga = cargaJwt(jwt);
    if (carga?.aal !== "aal2" || (typeof carga?.sub === "string" && carga.sub !== quien.id)) {
      throw new Fallo(403, "Falta el código del teléfono: entra otra vez con él (los cobros en línea lo piden).", "MFA");
    }
    await base.rpc("fn_stripe_dueno_fijar", { p_dueno: quien.id });
    const motivoDe = () => {
      const m = typeof cuerpo.motivo === "string" ? cuerpo.motivo.trim() : "";
      if (!m) throw new Fallo(400, "Falta el motivo: queda escrito.", "FORMA");
      return m;
    };

    switch (accion) {
      case "estado":
        return responder({ ok: true, salud: salud(), resumen: await base.rpc("fn_stripe_resumen", {}) });
      case "probar_llave":
        return responder(await probarLlave());
      case "crear_enlace":
        return await crearEnlace(base, quien.id, cuerpo);
      case "desactivar_enlace": {
        const id = typeof cuerpo.enlace === "string" ? cuerpo.enlace : "";
        if (!id) throw new Fallo(400, "Falta el enlace.", "FORMA");
        const motivo = motivoDe();
        const e = await base.rpc("fn_stripe_enlace", { p_enlace: id }) as Json;
        const r = await desactivarEnStripe(base, id, String(e.plink), motivo, "pantalla");
        return responder({ ok: true, enlace: r });
      }
      case "resolver_pago": {
        const pi = typeof cuerpo.pi === "string" ? cuerpo.pi : "";
        if (!pi) throw new Fallo(400, "Falta el pago (pi).", "FORMA");
        const decision: Json = cuerpo.factura_id !== undefined ? { factura_id: String(cuerpo.factura_id) }
          : cuerpo.proyecto_id !== undefined ? { proyecto_id: String(cuerpo.proyecto_id) }
          : cuerpo.fuera !== undefined ? { fuera: { cuenta: String(obj(cuerpo.fuera).cuenta ?? "") } } : {};
        if (!Object.keys(decision).length) throw new Fallo(400, "A qué va: una factura (factura_id), una obra (proyecto_id) o fuera:{cuenta}.", "FORMA");
        const r = await base.rpc("fn_stripe_pago_resolver", { p_pi: pi, p_decision: decision, p_motivo: motivoDe(), p_dueno: quien.id }) as Json;
        const payouts: Json[] = [];
        for (const po of Array.isArray(r.payouts) ? r.payouts as string[] : []) {
          try { payouts.push({ po, ...resumenPayout(await syncPayout(base, po, null)) }); }
          catch (e) { payouts.push({ po, error: mensajeDe(e) }); }
        }
        return responder({ ok: true, pago: r.pago ?? null, estado: obj(r.resultado).estado ?? null, payouts });
      }
      case "resolver_linea": {
        const po = typeof cuerpo.po === "string" ? cuerpo.po : "", txn = typeof cuerpo.txn === "string" ? cuerpo.txn : "";
        const cuenta = typeof cuerpo.cuenta === "string" ? cuerpo.cuenta.trim() : "";
        if (!po || !txn || !cuenta) throw new Fallo(400, "Faltan el depósito (po), la línea (txn) o la cuenta.", "FORMA");
        await base.rpc("fn_stripe_payout_linea_resolver", { p_po: po, p_txn: txn, p_cuenta: cuenta, p_motivo: motivoDe(), p_dueno: quien.id });
        const r = await syncPayout(base, po, null);
        return responder({ ok: true, estado: r.estado ?? null, payout: r.payout ?? null, casado: r.casado ?? null });
      }
      case "payout_fuera": {
        // «Ya está en el libro»: el depósito no es de la app (sin asientos; su movimiento de Chase va por la bandeja)
        const po = typeof cuerpo.po === "string" ? cuerpo.po : "";
        if (!po) throw new Fallo(400, "Falta el depósito (po).", "FORMA");
        const r = await base.rpc("fn_stripe_payout_fuera", { p_po: po, p_motivo: motivoDe(), p_dueno: quien.id }) as Json;
        return responder({ ok: true, estado: r.estado ?? null, payout: r.payout ?? null, pagos: r.pagos ?? 0 });
      }
      case "casar_payout": {
        const po = typeof cuerpo.po === "string" ? cuerpo.po : "";
        if (!po) throw new Fallo(400, "Falta el depósito (po).", "FORMA");
        const mov = typeof cuerpo.movimiento_id === "string" && cuerpo.movimiento_id ? cuerpo.movimiento_id : null;
        const r = await base.rpc("fn_stripe_payout_casar", { p_po: po, p_movimiento: mov }) as Json;
        return responder({ ok: true, ...r });
      }
      case "reprocesar": {
        if (typeof cuerpo.evento === "string" && cuerpo.evento) {
          const e = deStripe(await stripe("GET", `/v1/events/${encodeURIComponent(cuerpo.evento)}`));
          await guardar(base, e, "pantalla");
          return responder({ ok: true, evento: await procesarYcerrar(base, e) });
        }
        if (typeof cuerpo.pi === "string" && cuerpo.pi) {
          const r = await syncPago(base, cuerpo.pi, {}, null);
          return responder({ ok: true, estado: r.estado ?? null, pago: r.pago ?? null, cambios: r.cambios ?? [] });
        }
        if (typeof cuerpo.po === "string" && cuerpo.po) {
          const r = await syncPayout(base, cuerpo.po, null, cuerpo.rehacer === true);
          return responder({ ok: true, estado: r.estado ?? null, payout: r.payout ?? null, asientos: r.asientos ?? null, casado: r.casado ?? null, notas: r.notas ?? [] });
        }
        throw new Fallo(400, "Qué vuelvo a mirar: evento, pi o po.", "FORMA");
      }
      case "aviso_visto": {
        const id = typeof cuerpo.aviso === "number" ? cuerpo.aviso : typeof cuerpo.aviso === "string" && /^\d+$/.test(cuerpo.aviso) ? Number(cuerpo.aviso) : NaN;
        if (!Number.isSafeInteger(id)) throw new Fallo(400, "Falta el aviso.", "FORMA");
        return responder({ ok: true, aviso: await base.rpc("fn_stripe_aviso_visto", { p_aviso: id, p_dueno: quien.id }) });
      }
      case "barrer":
        return responder({ ok: true, resumen: await barrer(base, "pantalla") });
      default:
        throw new Fallo(400, `Acción desconocida: «${accion}».`, "ACCION");
    }
  } catch (e) {
    const f = e instanceof Fallo ? e : falloDeLaBase(e);
    if (f.estado >= 500 && !(e instanceof Fallo)) console.error(`stripe: ${mensajeDe(e).slice(0, 300)}`);
    return responder(limpiar({ ok: false, error: sinLlaves(f.message), codigo: f.codigo, pista: f.pista, rak: f.detalle?.rak }), f.estado);
  }
}

// Para las pruebas (stripe-e2e.mjs): las piezas puras.
export const _probar = { verificarFirma, formulario, armarFotoPago, armarFotoPayout, armarLineas, cargaEnlace, salud, diaUTC, diaMiami };

if (G.Deno?.serve) {
  const puerto = Number(env("MXP_PUERTO") || 0);
  if (puerto) G.Deno.serve({ port: puerto, hostname: "127.0.0.1" }, atender);
  else G.Deno.serve(atender);
}
