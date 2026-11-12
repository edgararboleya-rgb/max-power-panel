// ============================================================
// FACTURAS — el PDF y el envío de las facturas que se emiten desde la app
// (f10, capa c11: docs/conta/c11-emision.sql)
//
// Dónde se pega (3 minutos):
//   Supabase → Edge Functions → Deploy a new function → «Via Editor» →
//   nombre «facturas» → borrar el ejemplo y crear DOS archivos con lo de esta
//   carpeta: index.ts (este) y pdf.ts (el que pinta la factura) → Deploy,
//   con «Verify JWT» APAGADO, como las otras funciones de la contabilidad
//   (plaid, stripe, contador, notificar): la función comprueba ella misma la
//   sesión con Auth, el código del teléfono (aal2) y que sea el dueño, y
//   «salud» no enseña nada. Con la CLI:
//   supabase functions deploy facturas --no-verify-jwt.
//
// Secretos (Edge Functions → Secrets). Ninguno es nuevo si ya están los
// cobros en línea (stripe) y el cartero (correo):
//   RESEND_API_KEY      la del cartero (correo): manda el correo
//   STRIPE_SECRET_KEY   la llave RESTRINGIDA de los cobros en línea (rk_…):
//                       solo para dejar el enlace de pago de una factura
//                       SOLO por cuenta de banco (Payment Links: Write)
//   FACTURAS_REMITENTE  (opcional) quién manda, como en el cartero:
//                       «Nombre <correo@dominio-verificado-en-Resend>». Sin
//                       él, el nombre y el correo de la empresa que Edgar
//                       pone en Facturas → Ajustes.
//   FACTURAS_SITIO      (opcional) la dirección de la app, de donde salen el
//                       membrete del PDF (assets/lockup.png) y el del correo
//                       (assets/membrete-email.png). De fábrica, la de
//                       GitHub Pages de la app.
//   SUPABASE_URL y SUPABASE_ANON_KEY los pone Supabase solo.
//   …/functions/v1/facturas con {"accion":"salud"} dice qué falta sin
//   enseñar nada.
//
// Qué hace (Edgar, con su sesión de dueño y el código del teléfono, aal2):
//   · «pdf» {documento, sin_enlace?}: pinta el PDF de una factura EMITIDA
//     desde su contenido congelado (fn_emision_documento: contenido y
//     huella; nada más), en inglés (pdf.ts). Si la factura se puede pagar en
//     línea (fn_emision_pago.en_linea), antes deja listo su enlace de pago,
//     como lo pide la cabecera de c11 («El pago en línea»):
//       1. el enlace lo arma p1, por su camino de siempre: la función
//          «stripe» (crear_enlace, con la misma sesión): uno vivo por
//          factura, con_retencion = false, por los centavos que el LIBRO dice
//          que debe y con los metadatos de p1 sin tocar, de un solo uso. Si
//          p1 dice que el vivo quedó desfasado (cobra otra cosa), se pide
//          otro (reemplazar);
//       2. en Stripe se deja SOLO por cuenta de banco (POST
//          /v1/payment_links/{plink} con payment_method_types[0] =
//          us_bank_account) ANTES de imprimir la dirección: la función stripe
//          (sellada) lo crea con [us_bank_account, card] y la tarjeta está
//          APAGADA (decisión de Edgar del 12-nov: solo ACH por ahora; se
//          enciende cuando los cobros en línea sepan registrar el recargo
//          como ingreso, en una versión futura de p1). La factura no ofrece
//          tarjeta en ninguna parte (ni el PDF ni el correo): con el enlace
//          dice lo que la base manda en pago_en_linea.texto («Online payment
//          is by bank account (ACH) only.»);
//       3. se le vuelve a preguntar a la base (fn_emision_pago) y se exige
//          que ese enlace «vale» (activo, sin retención, por lo que el libro
//          debe hoy). Si algo falla, no se imprime ningún enlace: el error lo
//          dice y la pantalla ofrece hacer el PDF sin enlace (el «How to
//          pay» de la casa sigue).
//     Después sube el PDF al bucket privado «facturas» en
//     <año>/<número>/<número>-<sha256 corto>.pdf (cada versión distinta,
//     otro nombre: nada se pisa) y lo registra (fn_emision_pdf: ruta,
//     sha256, bytes, la huella del contenido y el enlace impreso, solo
//     us_bank_account; la base comprueba que el archivo está y mide eso). El
//     mismo contenido con el mismo enlace da el MISMO archivo (pdf.ts): se
//     reconoce y no se registra dos veces. Devuelve el PDF y una dirección
//     firmada de 10 minutos para verlo. Si ya entró un pago, el enlace cobra
//     lo que el libro debe HOY (menos que la factura): el PDF y el correo lo
//     dicen en grande («Balance due today», lo mismo que cobra Stripe) y lo
//     de la factura queda encima («Invoice amount due»). Si el «How to pay»
//     de la casa habla de un enlace y este PDF va sin él (la de la retención,
//     sin enlace a propósito, el pago en línea apagado), lo avisa (avisos).
//     Lo que el cliente cita al pagar sale abajo del «How to pay»: su número;
//     en la de la retención (serie propia MXP-R-AAAA-NNNN, que no es una
//     factura del libro), los números de las facturas cuya retención reclama
//     (contenido.referencias), y el correo dice que la libera.
//   · «enviar» {documento, para?, cc?, asunto?, mensaje?, sin_enlace?}: lo
//     de «pdf» y, con ese PDF adjunto, el correo por Resend como lo manda el
//     cartero: el remitente de la casa, COPIA A EDGAR (el correo de su
//     sesión) y responder-a la empresa; en inglés, con el membrete, el
//     resumen, el botón de pago (si hay enlace) y el «How to pay». Lo
//     registra en la factura (fn_emision_envio, con el id de Resend: el
//     mismo dos veces no entra dos veces). La tabla correos es del cartero
//     (otra sesión) y en producción el dueño no puede escribir en ella (solo
//     leer, 12-nov): no se toca; el registro de los envíos de una factura es
//     el suyo (emision_envios). Un reenvío es otro correo y otra fila.
//     Si el correo sale y el registro falla, el error trae el id de Resend
//     (datos.resend_id) para apuntarlo sin volver a mandarlo.
//   · «ver» {documento, pdf_id?}: una dirección firmada (10 min) del último
//     PDF (o del que se pida).
//   · «salud» (sin sesión): la versión y qué secretos faltan (sin valores).
//   Todo lo de la base va por la API (PostgREST y Storage) CON LA SESIÓN DE
//   EDGAR: nunca como service_role ni directo a la base. Las funciones de
//   c11 son SECURITY INVOKER con es_dueno() por dentro; Storage, con las
//   policies del bucket (solo el dueño sube y lee; nadie borra ni pisa).
//
// Errores ({ok:false, codigo, error, pista?, datos?}, el texto en llano):
//   SESION 401 · NO_DUENO 403 · MFA 403 (falta el código del teléfono) ·
//   FORMA 400 · ACCION 400 · CONFIG 500 (un secreto que falta) · SIN_C11
//   500 (la base no tiene c11) · los de la base tal cual (MX008, MX011,
//   22023…: 409; 42501: 403) · los de la función stripe tal cual · STRIPE_ACH
//   / STRIPE_PERMISO / STRIPE_CAIDO 502 · ENLACE 409 · STORAGE 502 · RESEND
//   502 · SIN_APUNTAR 500 (salió el correo y no quedó apuntado).
//
// Lo que NO hace: emitir, anular o cambiar una factura (eso es de la base,
// desde la pantalla); cobrar (Stripe y p1); tocar la función stripe, el
// cartero ni qb. Ninguna llave sale de aquí ni se escribe en ninguna parte.
//
// En el banco de pruebas (MXP_BANCO_PRUEBAS=1, SUPABASE_URL en 127.0.0.1 y
// fuera de Supabase; en Supabase nunca se cumple y, si alguien lo pone en
// Secrets, todo contesta 500 CONFIG): STRIPE_BASE_URL y RESEND_BASE_URL
// apuntan a los simulados, MXP_PUERTO sirve en 127.0.0.1 y las librerías
// del PDF se inyectan (usarLibreriasDePruebas). El archivo corre también en
// Node 22 (pruebas/conta/facturas-e2e.mjs: Node quita los tipos).
// ============================================================

// deno-lint-ignore-file no-explicit-any
import { pintarFactura, usd, dia, subtitulo, referenciaEn, listaEn, PDF_VERSION, type Librerias } from "./pdf.ts";

type Json = Record<string, any>;
const G = globalThis as any;
function env(k: string): string {
  const v = G.Deno?.env?.get?.(k) ?? G.process?.env?.[k];
  return typeof v === "string" ? v : "";
}

const VERSION = "facturas 2026-11-12.4";
const STRIPE_VERSION = "2026-09-30.endive"; // la misma que la función stripe
const SITIO_DE_FABRICA = "https://edgararboleya-rgb.github.io/max-power-panel/";
const MAX_CUERPO = 100_000;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---- la configuración (se lee en cada llamada: en las pruebas cambia) ----
interface Conf {
  url: string; apikey: string; resend: string; stripe: string; stripe_modo: string | null; remitente: string; sitio: string;
  stripe_base: string; resend_base: string; banco: boolean; banco_mal: string | null;
}
function esBancoDePruebas(): { vale: boolean; mal: string | null } {
  const pedido = env("MXP_BANCO_PRUEBAS") === "1";
  const local = /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/.test(env("SUPABASE_URL"));
  const enSupabase = G.EdgeRuntime !== undefined || env("SB_REGION") !== "";
  const vale = pedido && local && !enSupabase;
  return { vale, mal: pedido && !vale ? "MXP_BANCO_PRUEBAS no vale fuera del banco de pruebas: bórralo de Supabase → Edge Functions → Secrets." : null };
}
function llavePublica(req?: Request): string {
  if (env("SUPABASE_ANON_KEY")) return env("SUPABASE_ANON_KEY");
  const pub = env("SUPABASE_PUBLISHABLE_KEYS");
  if (pub) {
    try { const j = JSON.parse(pub); const v = typeof j === "string" ? j : j.default ?? Object.values(j)[0]; if (typeof v === "string" && v) return v; }
    catch { return pub.split(",")[0].trim(); }
  }
  return req?.headers.get("apikey") ?? "";
}
function conf(req?: Request): Conf {
  const b = esBancoDePruebas();
  const stripe = env("STRIPE_SECRET_KEY").trim();
  const sitio = (env("FACTURAS_SITIO") || SITIO_DE_FABRICA).replace(/\/?$/, "/");
  return {
    url: env("SUPABASE_URL").replace(/\/$/, ""), apikey: llavePublica(req), resend: env("RESEND_API_KEY").trim(), stripe,
    stripe_modo: /^rk_live_/.test(stripe) ? "real" : /^rk_test_/.test(stripe) ? "prueba" : null,
    remitente: env("FACTURAS_REMITENTE").trim(), sitio,
    stripe_base: (b.vale && env("STRIPE_BASE_URL") ? env("STRIPE_BASE_URL") : "https://api.stripe.com").replace(/\/$/, ""),
    resend_base: (b.vale && env("RESEND_BASE_URL") ? env("RESEND_BASE_URL") : "https://api.resend.com").replace(/\/$/, ""),
    banco: b.vale, banco_mal: b.mal,
  };
}

class Fallo extends Error {
  estado: number;
  codigo: string;
  pista?: string;
  datos?: Json;
  constructor(estado: number, mensaje: string, codigo: string, datos?: Json, pista?: string) {
    super(mensaje);
    this.estado = estado; this.codigo = codigo; this.datos = datos; this.pista = pista;
  }
}
const responder = (cuerpo: Json, estado = 200) =>
  new Response(JSON.stringify({ version: VERSION, ...cuerpo }), { status: estado, headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" } });
const obj = (v: unknown): Json => (v && typeof v === "object" && !Array.isArray(v) ? v as Json : {});
const mensajeDe = (e: unknown) => String((e as any)?.message ?? e);
// ninguna llave en lo que sale (por si un texto de fuera la repitiera)
const sinLlaves = (s: string) => s.replace(/\b(rk|sk|pk)_(live|test)_[A-Za-z0-9]+/g, "$1_$2_…").replace(/\bre_[A-Za-z0-9]{20,}/g, "re_…");
function cargaJwt(jwt: string): Json | null {
  try {
    const b = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b + "===".slice((b.length + 3) % 4)), (x) => x.charCodeAt(0))));
  } catch { return null; }
}
async function pedirFuera(url: string, init: RequestInit, ms = 25_000): Promise<Response> {
  const control = new AbortController();
  const reloj = setTimeout(() => control.abort(), ms);
  try { return await fetch(url, { ...init, signal: control.signal }); }
  finally { clearTimeout(reloj); }
}

// ---- la base, por la API, con la sesión de Edgar ----
async function api(c: Conf, jwt: string, ruta: string, init: { metodo?: string; cuerpo?: unknown; cabeceras?: Json } = {}): Promise<any> {
  let r: Response;
  try {
    r = await pedirFuera(`${c.url}/rest/v1/${ruta}`, {
      method: init.metodo ?? "GET",
      headers: { apikey: c.apikey, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json", ...(init.cabeceras ?? {}) },
      body: init.cuerpo === undefined ? undefined : JSON.stringify(init.cuerpo),
    });
  } catch (e) {
    throw new Fallo(502, `La base no contestó (${mensajeDe(e).slice(0, 120)}): no se hizo nada. Vuelve a intentarlo en un rato.`, "BASE");
  }
  const txt = await r.text();
  let j: any = null; try { j = txt ? JSON.parse(txt) : null; } catch { j = null; }
  if (r.ok) return j;
  const d = obj(j), cod = String(d.code ?? ""), msg = String(d.message ?? "");
  if (cod === "PGRST202" || cod === "PGRST205" || cod === "42883" || cod === "42P01") {
    throw new Fallo(500, "A la base le falta la facturación: pega docs/conta/c11-emision.sql en Supabase (SQL Editor → pegar → Run).", "SIN_C11");
  }
  if (cod === "MFA") throw new Fallo(403, "Falta el código del teléfono: entra otra vez con él.", "MFA");
  if (cod === "42501") throw new Fallo(403, msg && !/permission denied|row-level/i.test(msg) ? msg : "Las facturas las maneja solo Edgar (el dueño).", "42501");
  if (r.status === 401 || cod.startsWith("PGRST3")) throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.", "SESION");
  if (/^MX\d/.test(cod) || cod === "22023" || cod === "22007" || cod === "P0001") throw new Fallo(409, msg, cod, undefined, d.hint || undefined);
  throw new Fallo(502, `La base contestó ${r.status}${msg ? `: ${msg}` : ""}.`, cod || "BASE");
}
const rpc = (c: Conf, jwt: string, fn: string, args: Json) => api(c, jwt, `rpc/${fn}`, { metodo: "POST", cuerpo: args });

interface Yo { id: string; email: string | null }
async function quien(c: Conf, jwt: string): Promise<Yo> {
  let r: Response;
  try { r = await pedirFuera(`${c.url}/auth/v1/user`, { headers: { apikey: c.apikey, Authorization: `Bearer ${jwt}` } }, 15_000); }
  catch { throw new Fallo(502, "Supabase no contestó al mirar la sesión: vuelve a intentarlo en un rato.", "SESION"); }
  if (!r.ok) throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.", "SESION");
  const u = obj(await r.json().catch(() => ({})));
  if (typeof u.id !== "string") throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.", "SESION");
  // el JWT ya lo validó Auth: aquí solo se lee su nivel (s1: el código del teléfono)
  const carga = cargaJwt(jwt);
  if (carga?.aal !== "aal2" || (typeof carga?.sub === "string" && carga.sub !== u.id)) {
    throw new Fallo(403, "Falta el código del teléfono: entra otra vez con él (las facturas lo piden).", "MFA");
  }
  const p = await api(c, jwt, `perfiles?select=rol,activo&id=eq.${encodeURIComponent(u.id)}`);
  const perfil = Array.isArray(p) ? obj(p[0]) : {};
  if (perfil.rol !== "dueno" || perfil.activo === false) throw new Fallo(403, "Las facturas las manda solo Edgar (el dueño).", "NO_DUENO");
  return { id: u.id, email: typeof u.email === "string" && u.email ? u.email : null };
}

// ---- Storage (el bucket privado «facturas»), con la sesión ----
const rutaUrl = (ruta: string) => ruta.split("/").map(encodeURIComponent).join("/");
async function subir(c: Conf, jwt: string, ruta: string, bytes: Uint8Array): Promise<"subido" | "ya_estaba"> {
  let r: Response;
  try {
    r = await pedirFuera(`${c.url}/storage/v1/object/facturas/${rutaUrl(ruta)}`, {
      method: "POST",
      headers: { apikey: c.apikey, Authorization: `Bearer ${jwt}`, "Content-Type": "application/pdf", "x-upsert": "false", "cache-control": "no-cache" },
      body: bytes as unknown as BodyInit,
    });
  } catch (e) { throw new Fallo(502, `Storage no contestó al subir el PDF (${mensajeDe(e).slice(0, 80)}): no se registró nada.`, "STORAGE"); }
  if (r.ok) return "subido";
  const d = obj(await r.json().catch(() => ({})));
  const m = String(d.message ?? d.error ?? "");
  // el nombre lleva el sha256: si ya está, es este mismo archivo (la base mide su tamaño al registrarlo)
  if (r.status === 409 || String(d.statusCode) === "409" || /exist|duplicate/i.test(m)) return "ya_estaba";
  if (/bucket not found/i.test(m)) throw new Fallo(502, "No existe el bucket «facturas» en Storage: vuelve a pegar docs/conta/c11-emision.sql (lo crea).", "STORAGE");
  if (r.status === 403 || /row-level|policy|unauthorized/i.test(m)) throw new Fallo(502, "Storage no dejó subir al bucket «facturas»: sus policies (solo el dueño sube) no están; vuelve a pegar c11-emision.sql.", "STORAGE");
  throw new Fallo(502, `No se pudo subir el PDF a Storage (${r.status}${m ? `: ${m}` : ""}).`, "STORAGE");
}
async function firmar(c: Conf, jwt: string, ruta: string): Promise<string | null> {
  try {
    const r = await pedirFuera(`${c.url}/storage/v1/object/sign/facturas/${rutaUrl(ruta)}`, {
      method: "POST", headers: { apikey: c.apikey, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ expiresIn: 600 }),
    }, 15_000);
    if (!r.ok) return null;
    const j = obj(await r.json().catch(() => ({})));
    const f = j.signedURL ?? j.signedUrl;
    return typeof f === "string" ? (/^https?:/.test(f) ? f : `${c.url}/storage/v1${f.startsWith("/") ? "" : "/"}${f}`) : null;
  } catch { return null; }
}

// ---- el enlace de pago: p1 lo arma; aquí se deja solo por cuenta de banco ----
async function funcionStripe(c: Conf, jwt: string, cuerpo: Json): Promise<Json> {
  let r: Response;
  try {
    r = await pedirFuera(`${c.url}/functions/v1/stripe`, {
      method: "POST", headers: { apikey: c.apikey, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" }, body: JSON.stringify(cuerpo),
    }, 60_000);
  } catch (e) { throw new Fallo(502, `La función de los cobros en línea (stripe) no contestó (${mensajeDe(e).slice(0, 80)}).`, "STRIPE_CAIDO"); }
  if (r.status === 404) throw new Fallo(500, "La función de los cobros en línea (stripe) no está desplegada: sin ella no hay enlace de pago.", "CONFIG");
  const j = obj(await r.json().catch(() => ({})));
  if (!r.ok || j.ok === false) {
    throw new Fallo(r.status >= 500 ? 502 : 409, String(j.error ?? `La función stripe contestó ${r.status}.`), String(j.codigo ?? "STRIPE"), undefined, j.pista);
  }
  return j;
}
function formulario(o: Json, prefijo = ""): string[] {
  const out: string[] = [];
  for (const [k, v] of Object.entries(o)) {
    const nombre = prefijo ? `${prefijo}[${k}]` : k;
    if (v && typeof v === "object") out.push(...formulario(v as Json, nombre));
    else out.push(`${encodeURIComponent(nombre)}=${encodeURIComponent(String(v))}`);
  }
  return out;
}
async function stripePost(c: Conf, ruta: string, cuerpo: Json, idem: string): Promise<Json> {
  if (!c.stripe_modo) {
    throw new Fallo(500, /^sk_/.test(c.stripe) ? "Usa la llave RESTRINGIDA de Stripe (rk_…), no la secreta: cámbiala en Supabase → Edge Functions → Secrets."
      : "Falta STRIPE_SECRET_KEY (la llave restringida de los cobros en línea) en Supabase → Edge Functions → Secrets.", "CONFIG");
  }
  let r: Response;
  try {
    r = await pedirFuera(`${c.stripe_base}${ruta}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${c.stripe}`, "Stripe-Version": STRIPE_VERSION, "Idempotency-Key": idem, "Content-Type": "application/x-www-form-urlencoded" },
      body: formulario(cuerpo).join("&"),
    });
  } catch { throw new Fallo(502, "Stripe no contestó al dejar el enlace solo por cuenta de banco: no se imprimió ningún enlace. Vuelve a intentarlo en un rato.", "STRIPE_CAIDO"); }
  const j = obj(await r.json().catch(() => ({})));
  if (r.ok) return j;
  const e = obj(j.error), m = String(e.message ?? "");
  if (r.status === 401 || r.status === 403 || /permission|rak_/i.test(m)) {
    throw new Fallo(502, "A la llave de Stripe le falta el permiso de escribir Payment Links (Payment Links: Write): sin él no se puede dejar el enlace solo por cuenta de banco.", "STRIPE_PERMISO");
  }
  if (r.status >= 500 || r.status === 429) throw new Fallo(502, "Stripe no contestó bien al dejar el enlace solo por cuenta de banco: vuelve a intentarlo en un rato.", "STRIPE_CAIDO");
  throw new Fallo(502, `Stripe no dejó el enlace solo por cuenta de banco (${sinLlaves(m || String(r.status))}): no se imprimió ningún enlace.`, "STRIPE_ACH");
}
interface Enlace { enlace_id: string; url: string; metodos: string[]; monto: unknown }
async function enlaceAch(c: Conf, jwt: string, documento: string, numero: string, pago: Json): Promise<Enlace> {
  const pedir = (reemplazar: boolean) => funcionStripe(c, jwt, { accion: "crear_enlace", factura_id: pago.factura_id, con_retencion: false, ...(reemplazar ? { reemplazar: true } : {}) });
  let r = await pedir(false);
  // un enlace vivo que ya no cobra lo que el libro dice (o que cobra la retención): otro
  if (r.desfasado === true || obj(r.enlace).con_retencion === true) r = await pedir(true);
  const e = obj(r.enlace);
  if (typeof e.id !== "string" || typeof e.url !== "string" || typeof e.plink !== "string" || !/^plink_/.test(e.plink)) {
    throw new Fallo(502, "La función de los cobros en línea no devolvió el enlace entero (id, url, plink): no se imprimió ninguno.", "STRIPE_ENLACE");
  }
  const link = await stripePost(c, `/v1/payment_links/${encodeURIComponent(e.plink)}`, { payment_method_types: ["us_bank_account"] }, `mxp-facturas-ach-${e.plink}-${crypto.randomUUID()}`);
  const tipos = Array.isArray(link.payment_method_types) ? link.payment_method_types : null;
  if (!tipos || tipos.length !== 1 || tipos[0] !== "us_bank_account") {
    throw new Fallo(502, `Stripe dejó el enlace de la factura ${numero} con [${(tipos ?? []).join(", ")}], no solo por cuenta de banco: no se imprimió.`, "STRIPE_ACH");
  }
  if (link.active === false) throw new Fallo(409, `El enlace de la factura ${numero} ya no está activo en Stripe: vuelve a intentarlo (se pide uno nuevo).`, "ENLACE");
  const p2 = await rpc(c, jwt, "fn_emision_pago", { p_documento: documento });
  const v = obj(p2?.enlace);
  if (v.id !== e.id || v.url !== e.url || v.vale !== true) {
    throw new Fallo(409, `El enlace de pago de la factura ${numero} no quedó como la base lo pide (activo, sin la retención y por lo que el libro debe hoy): no se imprimió.`, "ENLACE");
  }
  // monto: lo que cobra (la base: lo que el libro debe hoy); se imprime, pero no va al registro (c11 lo apunta de la base)
  return { enlace_id: e.id, url: e.url, metodos: ["us_bank_account"], monto: v.monto };
}

// ---- las librerías del PDF y el membrete ----
let libsListas: Promise<Librerias> | null = null;
function librerias(): Promise<Librerias> {
  if (!libsListas) {
    libsListas = (async () => {
      // npm: solo en Deno (Supabase); en el banco sin Deno se inyectan
      const PDFLib = await import("npm:pdf-lib@1.17.1");
      let QRCode: any = null;
      try { const q: any = await import("npm:qrcode@1.5.4"); QRCode = q.default ?? q; } catch { QRCode = null; }
      return { PDFLib, QRCode };
    })();
    libsListas.catch(() => { libsListas = null; });
  }
  return libsListas;
}
export function usarLibreriasDePruebas(l: Librerias): void {
  if (!esBancoDePruebas().vale) throw new Error("usarLibreriasDePruebas es solo del banco de pruebas.");
  libsListas = Promise.resolve(l);
}
const membretes = new Map<string, Uint8Array | null>();
async function membrete(c: Conf): Promise<Uint8Array | null> {
  if (membretes.has(c.sitio)) return membretes.get(c.sitio) ?? null;
  let png: Uint8Array | null = null;
  try {
    const r = await pedirFuera(`${c.sitio}assets/lockup.png`, {}, 8_000);
    const b = new Uint8Array(await r.arrayBuffer());
    // solo un PNG de verdad (firma \x89PNG) y de tamaño razonable
    if (r.ok && b.length > 100 && b.length < 2_000_000 && b[0] === 0x89 && b[1] === 0x50) png = b;
  } catch { png = null; }
  // sin membrete no se recuerda el fallo: la próxima vez se vuelve a probar
  if (png) membretes.set(c.sitio, png);
  return png;
}
async function sha256Hex(b: Uint8Array): Promise<string> {
  const h = new Uint8Array(await crypto.subtle.digest("SHA-256", b as unknown as BufferSource));
  return [...h].map((x) => x.toString(16).padStart(2, "0")).join("");
}
function base64(b: Uint8Array): string {
  let s = "";
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
}

// ---- «pdf»: el enlace, el PDF, Storage y el registro ----
interface HechoPdf { doc: Json; pdf: Json; ya_estaba: boolean; enlace: Enlace | null; bytes: Uint8Array; avisos: string[] }
async function hacerPdf(c: Conf, jwt: string, documento: string, sinEnlace: boolean): Promise<HechoPdf> {
  const d = obj(await rpc(c, jwt, "fn_emision_documento", { p_documento: documento }));
  const dd = obj(d.documento), cont = obj(d.contenido), numero = String(dd.numero ?? "");
  if (dd.estado === "borrador") throw new Fallo(409, "Es un borrador: el PDF es de la factura emitida. Emítela primero.", "MX008");
  if (dd.estado === "anulada") throw new Fallo(409, `La factura ${numero} está anulada (nota de crédito ${dd.nota_credito ?? "—"}): ya no se le hace PDF ni se manda.`, "MX008");
  if (cont.v !== 1 || !numero || typeof d.huella !== "string") throw new Fallo(502, "La base no devolvió el contenido congelado de la factura: no se pintó nada.", "BASE");
  const avisos: string[] = [];
  let enlace: Enlace | null = null;
  if (cont.pago_en_linea?.ach) {
    const pago = obj(await rpc(c, jwt, "fn_emision_pago", { p_documento: documento }));
    if (sinEnlace) avisos.push("Va sin enlace de pago en línea: lo pediste así.");
    else if (pago.en_linea !== true) avisos.push(`Va sin enlace de pago en línea: ${pago.por_que_no ?? "la base no lo ofrece"}`);
    else enlace = await enlaceAch(c, jwt, documento, numero, pago);
  }
  // el «How to pay» es uno para todas (y en la factura emitida va congelado): si habla de un enlace y este PDF no lo lleva
  // (la de la retención, un PDF sin enlace, el pago en línea apagado), el cliente lo buscará: se avisa para las próximas
  if (!enlace && hablaDeEnlace(cont.como_pagar)) {
    avisos.push("El «How to pay» de esta factura habla de un enlace de pago y este PDF va sin él. Para las próximas, cámbialo en Facturas → Ajustes para que sirva con enlace y sin él: cuando una factura lo lleva, el PDF y el correo añaden solos el enlace, lo que cobra y su código QR.");
  }
  const libs = await librerias();
  const bytes = await pintarFactura(libs, cont, { pago: enlace ? { url: enlace.url, monto: enlace.monto } : null, logo: await membrete(c), huella: d.huella });
  const sha = await sha256Hex(bytes);
  const previo = (Array.isArray(d.pdfs) ? d.pdfs : []).find((p: Json) => p.sha256 === sha);
  if (previo) return { doc: d, pdf: previo, ya_estaba: true, enlace, bytes, avisos };
  const anio = /^(\d{4})-/.exec(String(cont.fecha ?? ""))?.[1] ?? numero.match(/(\d{4})/)?.[1] ?? "";
  const ruta = `${anio}/${numero}/${numero}-${sha.slice(0, 12)}.pdf`;
  await subir(c, jwt, ruta, bytes);
  const r = obj(await rpc(c, jwt, "fn_emision_pdf", {
    p_documento: documento,
    p_archivo: { ruta, sha256: sha, bytes: bytes.length, huella: d.huella, ...(enlace ? { pago: { enlace_id: enlace.enlace_id, url: enlace.url, metodos: enlace.metodos } } : {}) },
  }));
  return { doc: d, pdf: obj(r.pdf), ya_estaba: r.ya_estaba === true, enlace, bytes, avisos };
}

// ¿El «How to pay» de la casa habla de un enlace de pago (que una factura sin enlace no lleva)? Una ayuda, no una garantía
const HABLA_DE_ENLACE = /\b(link|links|click|button|stripe|qr)\b|\bpay(ing)? online\b|\bonline payment/i;
export const hablaDeEnlace = (s: unknown) => HABLA_DE_ENLACE.test(String(s ?? ""));

// ---- «enviar»: el correo, como el cartero ----
const CORREO = /^[^@\s,;<>"]+@[^@\s,;<>"]+\.[^@\s,;<>"]+$/;
function correos(v: unknown): string[] {
  const lista = Array.isArray(v) ? v : String(v ?? "").split(/[,;]/);
  return [...new Set(lista.map((x) => String(x).trim().toLowerCase()).filter(Boolean))];
}
const html = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (x) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[x] as string));
const conSaltos = (s: unknown) => html(s).replace(/\r?\n/g, "<br>");
export function cuerpoCorreo(cont: Json, enlace: { url: string; monto?: unknown } | null, mensaje: string | null, sitio: string): { html: string; texto: string } {
  const e = obj(cont.empresa), cl = obj(cont.cliente), t = obj(cont.totales), numero = String(cont.numero ?? "");
  const saludo = `Hello${cl.atencion || cl.nombre ? " " + (cl.atencion || cl.nombre) : ""},`;
  const intro = `Please find attached invoice ${numero} from ${e.nombre || "us"}${cont.obra?.nombre ? ` for ${cont.obra.nombre}` : ""}.`;
  // (la de la retención no es una factura del libro: reclama lo retenido de otras, y esas son las que el cliente cita al pagar)
  const refs = cont.forma === "retencion" && Array.isArray(cont.referencias) ? cont.referencias.map((x: unknown) => String(x ?? "").trim()).filter(Boolean) : [];
  const libera = refs.length ? `It releases the retainage withheld on invoice${refs.length > 1 ? "s" : ""} ${listaEn(refs)}.` : "";
  const cita = referenciaEn(cont);
  // lo que la base le dice al cliente del pago en línea (solo por cuenta de banco; la tarjeta no se le ofrece)
  const ach = String(cont.pago_en_linea?.texto ?? "").trim() || "Online payment is by bank account (ACH) only.";
  const vence = Number(cont.terminos?.dias) ? `${dia(cont.vence)} (${cont.terminos?.etiqueta ?? ""})` : "On receipt";
  // el botón dice lo que cobra el enlace (lo que el libro debe hoy). Si ya entró un pago, es menos que lo que pide la
  // factura: entonces, como en el PDF, la última fila (la grande) es «Balance due today» con lo que cobra el enlace, y lo
  // de la factura va encima como «Invoice amount due». Comparar dos textos no es sumar.
  const cobra = enlace ? usd(enlace.monto != null && String(enlace.monto).trim() !== "" ? enlace.monto : t.a_pagar) : "";
  const saldoHoy = !!enlace && cobra !== usd(t.a_pagar);
  const filas: Array<[string, string]> = [["Invoice", numero], ["Date", dia(cont.fecha)], ["Due", vence],
    ...(saldoHoy ? [["Invoice amount due", usd(t.a_pagar)], ["Balance due today", cobra]] as Array<[string, string]> : [["Amount due", usd(t.a_pagar)]] as Array<[string, string]>)];
  if (/[1-9]/.test(String(t.retencion ?? "")) && cont.forma !== "retencion") filas.splice(3, 0, ["Retainage held", `${usd(t.retencion)} (${t.retencion_pct}%)`]);
  const pie = [e.nombre, e.licencia, e.telefono, e.web].filter((x) => x && String(x).trim()).join(" · ");
  const saldo = saldoHoy ? "That is the balance due today: payments already received are deducted. " : "";
  const boton = enlace ? `<p style="margin:22px 0"><a href="${html(enlace.url)}" style="background:#2A5BD7;color:#ffffff;text-decoration:none;font-weight:700;padding:13px 22px;border-radius:12px;display:inline-block">Pay ${html(cobra)} by bank transfer</a></p>
    <p style="font-size:13px;color:#4D6A83;margin:0 0 18px">${html(saldo)}${html(ach)} It goes securely through Stripe; bank payments take a few business days to clear.</p>` : "";
  const cuerpo = `<!doctype html><html lang="en"><body style="margin:0;background:#E8F3FA;font-family:Helvetica,Arial,sans-serif;color:#0B2036">
<div style="max-width:600px;margin:0 auto;padding:24px 16px">
 <div style="background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #cfe0ee">
  <div style="border-top:4px solid #1B3C8C;padding:18px 24px 10px"><img src="${html(sitio)}assets/membrete-email.png" alt="${html(e.nombre || "")}" width="260" style="display:block;max-width:100%;height:auto;border:0"></div>
  <div style="height:3px;background:#B86A2E;margin:0 24px"></div>
  <div style="padding:20px 24px 8px;font-size:15px;line-height:1.55">
   <p style="margin:0 0 12px">${html(saludo)}</p>
   <p style="margin:0 0 14px">${html(intro)}${libera ? ` ${html(libera)}` : ""}</p>
   ${mensaje ? `<p style="margin:0 0 14px">${conSaltos(mensaje)}</p>` : ""}
   <table role="presentation" style="border-collapse:collapse;width:100%;font-size:14px;margin:6px 0 4px">
    ${filas.map(([a, b], i) => `<tr><td style="padding:7px 0;border-bottom:1px solid #cfe0ee;color:#4D6A83">${html(a)}</td><td style="padding:7px 0;border-bottom:1px solid #cfe0ee;text-align:right;${i === filas.length - 1 ? "font-weight:800;font-size:16px" : ""}">${html(b)}</td></tr>`).join("")}
   </table>
   ${boton}
   ${cont.como_pagar ? `<p style="font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:#8F4F1F;font-weight:800;margin:18px 0 4px">How to pay</p><p style="margin:0 0 16px;font-size:14px">${conSaltos(cont.como_pagar)}</p>` : ""}
   ${cita ? `<p style="margin:0 0 12px;font-size:13px;color:#4D6A83">${html(cita)}</p>` : ""}
   <p style="margin:0 0 18px;font-size:14px">Thank you for your business.</p>
  </div>
  <div style="padding:12px 24px 18px;font-size:12px;color:#4D6A83;border-top:1px solid #cfe0ee">${html(pie)}</div>
 </div>
</div></body></html>`;
  const texto = [saludo, "", intro + (libera ? " " + libera : ""), ...(mensaje ? ["", mensaje] : []), "", ...filas.map(([a, b]) => `${a}: ${b}`),
    ...(enlace ? ["", `Pay ${cobra} by bank transfer (ACH): ${enlace.url}`, ...(saldo ? [saldo.trim()] : []), ach] : []), ...(cont.como_pagar ? ["", "How to pay:", String(cont.como_pagar)] : []),
    ...(cita ? ["", cita] : []), "", "Thank you for your business.", "", pie].join("\n");
  return { html: cuerpo, texto };
}
async function enviar(c: Conf, jwt: string, yo: Yo, documento: string, cuerpo: Json): Promise<Json> {
  if (!c.resend) throw new Fallo(500, "Falta RESEND_API_KEY (la del cartero) en Supabase → Edge Functions → Secrets.", "CONFIG");
  const h = await hacerPdf(c, jwt, documento, cuerpo.sin_enlace === true);
  const cont = obj(h.doc.contenido), dd = obj(h.doc.documento), e = obj(cont.empresa), numero = String(dd.numero);
  const para = correos(cuerpo.para ?? cont.cliente?.correo);
  if (!para.length) throw new Fallo(400, "Falta a quién mandarla: la factura no trae el correo del cliente. Escríbelo (para).", "FORMA");
  const malos = para.filter((x) => !CORREO.test(x));
  if (malos.length) throw new Fallo(400, `«${malos.join(", ")}» no parece un correo.`, "FORMA");
  const cc = correos([...(yo.email ? [yo.email] : []), ...correos(cuerpo.cc)]).filter((x) => !para.includes(x));
  const ccMalos = cc.filter((x) => !CORREO.test(x));
  if (ccMalos.length) throw new Fallo(400, `«${ccMalos.join(", ")}» no parece un correo (copia).`, "FORMA");
  if (para.length + cc.length > 10) throw new Fallo(400, "Como mucho 10 direcciones entre para y copia.", "FORMA");
  const limpio = (s: unknown) => String(s ?? "").replace(/[<>"\r\n]/g, "").trim();
  const remitente = c.remitente || (e.correo && CORREO.test(String(e.correo).trim()) ? `${limpio(e.nombre) || "Invoices"} <${String(e.correo).trim()}>` : "");
  if (!remitente) throw new Fallo(500, "Falta quién manda el correo: pon el correo de la empresa en Facturas → Ajustes (de un dominio verificado en Resend) o FACTURAS_REMITENTE en Secrets.", "CONFIG");
  const asunto = limpio(cuerpo.asunto) || `Invoice ${numero} from ${limpio(e.nombre) || "us"}`;
  const mensaje = typeof cuerpo.mensaje === "string" && cuerpo.mensaje.trim() ? cuerpo.mensaje.trim().slice(0, 2000) : null;
  const { html: cuerpoHtml, texto } = cuerpoCorreo(cont, h.enlace, mensaje, c.sitio);
  const responderA = e.correo && CORREO.test(String(e.correo).trim()) ? String(e.correo).trim() : yo.email;
  const n = (Array.isArray(h.doc.envios) ? h.doc.envios.length : 0) + 1;
  let r: Response;
  try {
    r = await pedirFuera(`${c.resend_base}/emails`, {
      method: "POST",
      headers: { Authorization: `Bearer ${c.resend}`, "Content-Type": "application/json", "Idempotency-Key": `mxp-factura-${documento}-${n}-${String(h.pdf.sha256 ?? "").slice(0, 12)}` },
      body: JSON.stringify({
        from: remitente, to: para, ...(cc.length ? { cc } : {}), ...(responderA ? { reply_to: responderA } : {}), subject: asunto,
        html: cuerpoHtml, text: texto, attachments: [{ filename: `Invoice-${numero}.pdf`, content: base64(h.bytes) }],
        tags: [{ name: "tipo", value: "factura_app" }],
      }),
    });
  } catch { throw new Fallo(502, "El servicio de correo (Resend) no contestó: no salió nada. Vuelve a intentarlo en un rato.", "RESEND"); }
  const j = obj(await r.json().catch(() => ({})));
  if (!r.ok || typeof j.id !== "string") {
    const m = sinLlaves(String(j.message ?? j.error ?? r.status));
    throw new Fallo(502, r.status === 401 || r.status === 403 ? `Resend no aceptó la llave o el remitente (${m}): mira RESEND_API_KEY y que el dominio del remitente esté verificado.`
      : `El servicio de correo (Resend) no lo mandó: ${m}.`, "RESEND");
  }
  const avisos = [...h.avisos];
  let reg: Json;
  try {
    reg = obj(await rpc(c, jwt, "fn_emision_envio", { p_documento: documento, p_envio: { medio: "correo", para: para.join(", "), cc: cc.join(", ") || null, asunto, resend_id: j.id, pdf_id: h.pdf.id } }));
  } catch (err) {
    throw new Fallo(500, `El correo salió (Resend ${j.id}) pero no quedó apuntado en la factura: ${mensajeDe(err)} Toca «Apuntar el envío» (no se vuelve a mandar).`, "SIN_APUNTAR",
      { resend_id: j.id, para: para.join(", "), cc: cc.join(", ") || null, asunto, pdf_id: h.pdf.id });
  }
  return { documento, numero, envio: obj(reg.envio), reenvio: reg.reenvio === true, ya_estaba: reg.ya_estaba === true, resend_id: j.id, para: para.join(", "), cc: cc.join(", ") || null, asunto, pdf: h.pdf, enlace: h.enlace, avisos };
}

// ---- la puerta ----
function salud(c: Conf): Json {
  const falta: string[] = [];
  if (c.banco_mal) falta.push(c.banco_mal);
  if (!c.url) falta.push("SUPABASE_URL");
  if (!c.apikey) falta.push("SUPABASE_ANON_KEY");
  if (!c.resend) falta.push("RESEND_API_KEY (para mandar el correo)");
  if (!c.stripe_modo) falta.push("STRIPE_SECRET_KEY restringida (para el enlace de pago solo por cuenta de banco)");
  return { ok: true, funcion: "facturas", pdf: PDF_VERSION, resend: !!c.resend, stripe: c.stripe_modo, remitente: c.remitente ? "puesto" : "el de la empresa (Ajustes)", sitio: c.sitio, banco_de_pruebas: c.banco, falta };
}
export async function atender(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  try {
    if (req.method !== "POST") throw new Fallo(405, "Solo POST.", "FORMA");
    const crudo = await req.text();
    if (crudo.length > MAX_CUERPO) throw new Fallo(413, "El cuerpo es demasiado grande.", "FORMA");
    let cuerpo: Json;
    try { cuerpo = obj(JSON.parse(crudo || "{}")); } catch { throw new Fallo(400, "El cuerpo no es JSON.", "FORMA"); }
    const c = conf(req);
    const accion = String(cuerpo.accion ?? "");
    if (accion === "salud") return responder(salud(c));
    if (c.banco_mal) throw new Fallo(500, c.banco_mal, "CONFIG");
    if (!c.url || !c.apikey) throw new Fallo(500, "Falta SUPABASE_URL o SUPABASE_ANON_KEY en la función (los pone Supabase solo: vuelve a desplegarla).", "CONFIG");
    const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!jwt || jwt.split(".").length !== 3) throw new Fallo(401, "Entra con tu sesión.", "SESION");
    const yo = await quien(c, jwt);
    const documento = typeof cuerpo.documento === "string" && /^[0-9a-f-]{36}$/i.test(cuerpo.documento) ? cuerpo.documento : "";
    if (["pdf", "enviar", "ver"].includes(accion) && !documento) throw new Fallo(400, "Falta la factura (documento).", "FORMA");
    switch (accion) {
      case "pdf": {
        const h = await hacerPdf(c, jwt, documento, cuerpo.sin_enlace === true);
        const dd = obj(h.doc.documento);
        return responder({ ok: true, documento, numero: dd.numero, pdf: h.pdf, ya_estaba: h.ya_estaba, enlace: h.enlace, avisos: h.avisos,
          url: h.pdf.ruta ? await firmar(c, jwt, String(h.pdf.ruta)) : null });
      }
      case "enviar":
        return responder({ ok: true, ...(await enviar(c, jwt, yo, documento, cuerpo)) });
      case "ver": {
        const d = obj(await rpc(c, jwt, "fn_emision_documento", { p_documento: documento }));
        const pdfs: Json[] = Array.isArray(d.pdfs) ? d.pdfs : [];
        const p = typeof cuerpo.pdf_id === "string" ? pdfs.find((x) => x.id === cuerpo.pdf_id) : pdfs[pdfs.length - 1];
        if (!p) throw new Fallo(409, "Esa factura todavía no tiene PDF: hazlo primero.", "MX008");
        const url = await firmar(c, jwt, String(p.ruta));
        if (!url) throw new Fallo(502, "Storage no firmó el PDF: vuelve a intentarlo en un rato.", "STORAGE");
        return responder({ ok: true, documento, numero: obj(d.documento).numero, pdf: p, url });
      }
      default:
        throw new Fallo(400, `Acción desconocida: «${accion}». Las que hay: pdf, enviar, ver y salud.`, "ACCION");
    }
  } catch (e) {
    const f = e instanceof Fallo ? e : new Fallo(500, `Algo falló en la función de facturas: ${mensajeDe(e).slice(0, 200)}`, "FALLO");
    if (!(e instanceof Fallo)) console.error(`facturas: ${mensajeDe(e).slice(0, 300)}`);
    const cuerpo: Json = { ok: false, codigo: f.codigo, error: sinLlaves(f.message) };
    if (f.pista) cuerpo.pista = f.pista;
    if (f.datos) cuerpo.datos = f.datos;
    return responder(cuerpo, f.estado);
  }
}

// Para las pruebas: las piezas puras
export const _probar = { cuerpoCorreo, correos, formulario, subtitulo, esBancoDePruebas, hablaDeEnlace };

if (G.Deno?.serve) {
  const puerto = Number(env("MXP_PUERTO") || 0);
  if (puerto && esBancoDePruebas().vale) G.Deno.serve({ port: puerto, hostname: "127.0.0.1" }, atender);
  else G.Deno.serve(atender);
}
