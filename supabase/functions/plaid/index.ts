// ============================================================
// PLAID — la conexión automática con el banco y las tarjetas (f06 azul)
//
// Dónde se pega (2 minutos):
//   Supabase → Edge Functions → Deploy a new function → nombre «plaid»
//   → pegar este archivo entero → Deploy, con «Verify JWT» APAGADO (como
//   notificar y las demás: la función comprueba la sesión ella misma, y
//   Plaid y la rutina no traen sesión).
//
// ANTES de desplegar, en Edge Functions → Secrets tienen que existir:
//   PLAID_CLIENT_ID, PLAID_SECRET   las llaves del panel de Plaid
//   PLAID_ENV                       sandbox (pruebas) o production
//   PLAID_RUTINA_SECRETO            el que enseña c7-plaid.sql al pegarlo
//                                   (vault: plaid_rutina_secreto)
//   PLAID_REDIRECT_URI              https://edgararboleya-rgb.github.io/max-power-panel/
//                                   (la misma que en Plaid → Team Settings →
//                                   API → Allowed redirect URIs)
//   SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.
// Si falta algo obligatorio, contesta 500 y no hace nada.
//
// Qué hace: es la ÚNICA que habla con Plaid (las llaves no salen de aquí).
//   · Con la sesión del dueño (Authorization: Bearer …, rol «dueno» en
//     perfiles): link_token (abre Plaid Link en la pantalla), canjear (el
//     public_token por el access_token, que va a Vault por
//     fn_plaid_item_alta), fijar_cuenta (a qué cuenta del plan va cada
//     cuenta del banco), sincronizar, desconectar (/item/remove y el token
//     fuera de Vault), estado.
//   · Con el secreto de la rutina (cabecera x-mxp-rutina): sincronizar_todo,
//     lo que dispara pg_cron a las 6 de la mañana (fn_plaid_programado).
//   · Lo que manda Plaid (webhook, cuerpo con webhook_type): una novedad de
//     transacciones sincroniza esa conexión; un error del banco se anota.
//     No se verifica la firma del webhook: lo único que provoca es una
//     sincronización con nuestras llaves, nada entra del cuerpo.
//   · Sincronizar = /transactions/sync desde el cursor guardado, un lote por
//     cuenta del plan (origen "plaid": la base voltea el signo), y
//     fn_plaid_recibir lo mete al libro EN NOMBRE DEL DUEÑO y casa. Todo o
//     nada: si algo no entra, el cursor no avanza y mañana se vuelve a
//     pedir lo mismo. Con una cuenta de Plaid sin fijar (a qué cuenta del
//     plan va) NO se pide nada a Plaid: el cursor no se consume (SIN_FIJAR).
//
// A la base entra DIRECTO, como postgres, por SUPABASE_DB_URL (Supabase se lo
// da a toda función sin configurar nada; si hiciera falta otra, MXP_DB_URL
// manda). Ninguna función de c7 está en la API: ni la app ni service_role
// las ejecutan, solo esta función (c7-plaid.sql, v2). La sesión del dueño se
// comprueba con Supabase Auth (getUser) y su perfil (rol «dueno»).
//
// Lo que NO está en el repositorio: ninguna llave. En el banco de pruebas
// (MXP_BANCO_PRUEBAS=1, con MXP_DB_URL al Postgres local y PLAID_BASE_URL al
// Plaid simulado) la sesión se lee sin verificar la firma: ESO SOLO PASA con
// MXP_BANCO_PRUEBAS=1, que en Supabase no existe.
// ============================================================
import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

const PLAID_CLIENT_ID = Deno.env.get("PLAID_CLIENT_ID") ?? "";
const PLAID_SECRET = Deno.env.get("PLAID_SECRET") ?? "";
const PLAID_ENV = (Deno.env.get("PLAID_ENV") ?? "sandbox").toLowerCase();
const PLAID_BASE = (Deno.env.get("PLAID_BASE_URL") ?? `https://${PLAID_ENV}.plaid.com`).replace(/\/$/, "");
const RUTINA_SECRETO = Deno.env.get("PLAID_RUTINA_SECRETO") ?? "";
const REDIRECT_URI = Deno.env.get("PLAID_REDIRECT_URI") ?? "";
const WEBHOOK_URL = Deno.env.get("PLAID_WEBHOOK_URL") ?? "";
const DIAS = Math.min(730, Math.max(1, Number(Deno.env.get("PLAID_DIAS") ?? 90) || 90));
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const DB_URL = Deno.env.get("MXP_DB_URL") ?? Deno.env.get("SUPABASE_DB_URL") ?? "";
const BANCO_PRUEBAS = Deno.env.get("MXP_BANCO_PRUEBAS") === "1"; // SOLO el banco de pruebas
const PUERTO = Number(Deno.env.get("MXP_PUERTO") ?? 0);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-mxp-rutina",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const RECONECTAR = new Set(["ITEM_LOGIN_REQUIRED", "PENDING_EXPIRATION", "INVALID_ACCESS_TOKEN", "ITEM_NOT_FOUND", "ITEM_LOCKED", "USER_PERMISSION_REVOKED", "ACCESS_NOT_GRANTED"]);

class Fallo extends Error {
  constructor(public estado: number, mensaje: string, public codigo?: string, public detalle?: unknown) { super(mensaje); }
}

// Compara sin delatar por el tiempo cuántos caracteres acertó quien prueba.
function igual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
function fechaMiami(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}
function limpiar(o: Json): Json {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined && v !== null && v !== ""));
}
function responder(cuerpo: Json, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, "Content-Type": "application/json" } });
}

// ---- Plaid -------------------------------------------------------------
async function plaid(ruta: string, cuerpo: Json): Promise<Json> {
  const r = await fetch(PLAID_BASE + ruta, {
    method: "POST",
    headers: { "Content-Type": "application/json", "PLAID-CLIENT-ID": PLAID_CLIENT_ID, "PLAID-SECRET": PLAID_SECRET, "Plaid-Version": "2020-09-14" },
    body: JSON.stringify(cuerpo),
  });
  const texto = await r.text();
  let j: Json = {};
  try { j = JSON.parse(texto); } catch { /* no era JSON */ }
  if (!r.ok) {
    const codigo = String(j.error_code ?? `PLAID_${r.status}`);
    throw new Fallo(502, `Plaid ${ruta}: ${codigo} — ${j.error_message ?? texto.slice(0, 200)}`, codigo, j);
  }
  return j;
}

// ---- La base -----------------------------------------------------------
// Directo a Postgres, como postgres (o como el dueño del banco de pruebas):
// cada llamada en su transacción. Las fn_plaid_* exigen eso (fn_desde_editor)
// y no están en la API.
interface Quien { id: string; rol: string; activo: boolean }
interface Base {
  rpc(fn: string, args: Json): Promise<unknown>;
  quien(jwt: string): Promise<Quien | null>;
}
// deno-lint-ignore no-explicit-any
function falloDeLaBase(e: any): Fallo {
  const codigo = String(e?.code ?? "");
  const msg = String(e?.message ?? e);
  const estado = codigo === "42501" ? 403 : codigo.startsWith("MX") || codigo === "22023" ? 409 : 500;
  return new Fallo(estado, msg, codigo || undefined);
}
async function abrirBase(): Promise<Base> {
  const postgres = (await import("npm:postgres@3.4.5")).default;
  // el pooler de Supabase en modo transacción no admite sentencias preparadas
  const pooler = /pooler\.supabase\.com|:6543\//.test(DB_URL);
  const sql = postgres(DB_URL, { max: 2, idle_timeout: 20, connect_timeout: 10, prepare: !pooler, onnotice: () => {} });
  const sb = BANCO_PRUEBAS ? null : createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  return {
    async rpc(fn, args) {
      const nombres = Object.keys(args);
      // los objetos van tal cual: postgres.js los vuelve JSON cuando la base dice que el parámetro es jsonb
      const valores = nombres.map((k) => args[k]);
      const llamada = `select ${fn}(${nombres.map((k, i) => `${k} => $${i + 1}`).join(", ")}) as r`;
      try {
        return await sql.begin(async (t) => {
          await t.unsafe(`select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true)`);
          const filas = await t.unsafe(llamada, valores as never[]);
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
        const partes = jwt.split(".");
        if (partes.length < 2) return null;
        try {
          const b64 = partes[1].replace(/-/g, "+").replace(/_/g, "/");
          const carga = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")), (c) => c.charCodeAt(0))));
          if (typeof carga.sub === "string") id = carga.sub;
        } catch { return null; }
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

// ---- Lo que Plaid trae, en la forma de fn_banco_importar_filas -----------
function fila(t: Json): Json {
  const monto = Number(t.amount);
  const codigo = String(t.transaction_code ?? "").toLowerCase();
  const tipo = codigo === "interest" ? "INT"
    : codigo === "cheque" ? "CHECK"
    : codigo === "transfer" ? "XFER"
    : codigo === "payment" || codigo === "bill payment" ? "PAYMENT"
    : codigo === "atm" ? "ATM"
    : codigo === "bank charge" ? "FEE"
    : codigo === "direct debit" || codigo === "standing order" ? "DIRECTDEBIT"
    : codigo === "cash" ? "CASH"
    : monto > 0 ? "DEBIT" : "CREDIT";
  const nombre = String(t.original_description || t.name || t.merchant_name || "");
  const comercio = typeof t.merchant_name === "string" && t.merchant_name && t.merchant_name !== nombre ? t.merchant_name : undefined;
  return limpiar({
    id: t.transaction_id, fecha: t.date, fecha_transaccion: t.authorized_date ?? undefined,
    plaid_monto: monto.toFixed(2), descripcion: nombre, memo: comercio, tipo, cheque: t.check_number ?? undefined,
    pendiente: Boolean(t.pending),
  });
}
interface Grupo { cx: Json; filas: Json[]; quitadas: string[] }
function lote(g: Grupo, institucion: string, saldos: Json, hoy: string): Json {
  const cuenta = String(g.cx.cuenta), mask = String(g.cx.mask ?? "");
  const s = saldos[cuenta] as Json | undefined;
  return limpiar({
    origen: "plaid", cuenta, ultimos4: /^\d{4,}$/.test(mask) ? mask.slice(-4) : undefined, confirmo_cuenta: true,
    nombre: `Plaid · ${institucion}${mask ? ` ····${mask.slice(-4)}` : ""} · ${hoy}`,
    plaid_saldo: typeof s?.saldo === "number" ? (s.saldo as number).toFixed(2) : undefined, saldo_al: typeof s?.saldo === "number" ? hoy : undefined,
    filas: g.filas, quitadas: g.quitadas,
  });
}

// ---- Sincronizar una conexión -------------------------------------------
async function sincronizar(base: Base, cx: Json, porQue: string): Promise<Json> {
  const item_id = String(cx.item_id);
  const cuentas = (cx.cuentas as Json[] | undefined) ?? [];
  const sinFijar = cuentas.filter((c) => c.cuenta == null).map((c) => `····${c.mask ?? "?"}`);
  if (sinFijar.length) {
    // no se pide nada a Plaid: lo que el cursor consumiera de esas cuentas no volvería
    return { ok: false, item_id, codigo: "SIN_FIJAR", sin_fijar: sinFijar,
             error: `Falta decir a qué cuenta del plan va ${sinFijar.join(", ")} (o «ignorar»). Hasta entonces no se sincroniza.` };
  }
  try {
    const token = String(await base.rpc("fn_plaid_token", { p_item_id: item_id }));
    let cursor = typeof cx.cursor === "string" ? cx.cursor : "";
    const added: Json[] = [], modified: Json[] = [], removed: Json[] = [];
    let paginas = 0, cuentasPlaid: Json[] = [];
    for (;;) {
      const r = await plaid("/transactions/sync", { access_token: token, cursor, count: 500, options: { include_original_description: true } });
      added.push(...((r.added as Json[]) ?? []));
      modified.push(...((r.modified as Json[]) ?? []));
      removed.push(...((r.removed as Json[]) ?? []));
      if (Array.isArray(r.accounts)) cuentasPlaid = r.accounts as Json[];
      cursor = String(r.next_cursor ?? cursor);
      paginas++;
      if (!r.has_more || paginas >= 40) break;
    }
    const hoy = fechaMiami();
    const institucion = String(cx.institucion ?? "banco");
    const mapa = new Map<string, Json>();
    for (const c of cuentas) mapa.set(String(c.account_id), c);
    const grupos = new Map<string, Grupo>();
    const grupo = (account_id: string): Grupo | null => {
      const c = mapa.get(account_id);
      if (!c || c.cuenta == null || c.cuenta === "ignorar") return null;
      let g = grupos.get(account_id);
      if (!g) { g = { cx: c, filas: [], quitadas: [] }; grupos.set(account_id, g); }
      return g;
    };
    for (const t of [...added, ...modified]) grupo(String(t.account_id))?.filas.push(fila(t));
    for (const q of removed) grupo(String(q.account_id))?.quitadas.push(String(q.transaction_id));
    const saldos: Json = {};
    for (const a of cuentasPlaid) {
      const c = mapa.get(String(a.account_id));
      const b = (a.balances as Json | undefined) ?? {};
      if (c?.cuenta && c.cuenta !== "ignorar") saldos[String(c.cuenta)] = limpiar({ saldo: b.current, disponible: b.available, mask: a.mask, al: hoy });
    }
    const lotes = [...grupos.values()].filter((g) => g.filas.length || g.quitadas.length).map((g) => lote(g, institucion, saldos, hoy));
    const resumen = await base.rpc("fn_plaid_recibir", {
      p_item_id: item_id, p_lotes: lotes, p_cursor: cursor,
      p_resultado: { por_que: porQue, paginas, agregadas: added.length, modificadas: modified.length, quitadas: removed.length, saldos },
    }) as Json;
    return { ok: true, item_id, conexion: resumen, agregadas: added.length, modificadas: modified.length, quitadas: removed.length, lotes: lotes.length, paginas };
  } catch (e) {
    const codigo = e instanceof Fallo ? e.codigo : undefined;
    const msg = e instanceof Error ? e.message : String(e);
    try { await base.rpc("fn_plaid_error", { p_item_id: item_id, p_error: msg }); }
    catch (e2) { console.error(`plaid: no se pudo anotar el error de ${item_id}:`, e2 instanceof Error ? e2.message : e2); }
    return { ok: false, item_id, codigo, error: msg, hay_que_reconectar: codigo ? RECONECTAR.has(codigo) : false };
  }
}
async function sincronizarTodo(base: Base, porQue: string): Promise<Json> {
  const lista = (await base.rpc("fn_plaid_activas", {})) as Json[];
  const resultados: Json[] = [];
  for (const cx of lista) resultados.push(await sincronizar(base, cx, porQue));
  return { ok: true, conexiones: resultados.length, resultados };
}

// ---- Lo que manda Plaid (webhook) ----------------------------------------
async function webhook(base: Base, w: Json): Promise<Json> {
  const tipo = String(w.webhook_type ?? ""), codigo = String(w.webhook_code ?? ""), item_id = typeof w.item_id === "string" ? w.item_id : "";
  if (!item_id) return { ok: true, ignorado: "sin item_id" };
  let cx: Json;
  try { cx = (await base.rpc("fn_plaid_conexion", { p_item_id: item_id })) as Json; } catch { return { ok: true, ignorado: "conexión desconocida" }; }
  if (cx.estado === "desconectada") return { ok: true, ignorado: "desconectada" };
  if (tipo === "TRANSACTIONS" && ["SYNC_UPDATES_AVAILABLE", "DEFAULT_UPDATE", "INITIAL_UPDATE", "HISTORICAL_UPDATE"].includes(codigo)) {
    return await sincronizar(base, cx, `webhook ${codigo}`);
  }
  if (tipo === "ITEM" && (codigo === "ERROR" || codigo === "PENDING_EXPIRATION" || codigo === "USER_PERMISSION_REVOKED")) {
    const err = (w.error as Json | undefined) ?? {};
    const texto = codigo === "ERROR" ? `${err.error_code ?? "ERROR"}: ${err.error_message ?? "el banco avisa un error"}` : `${codigo}: hay que volver a conectar el banco`;
    await base.rpc("fn_plaid_error", { p_item_id: item_id, p_error: texto });
    return { ok: true, anotado: texto };
  }
  return { ok: true, ignorado: `${tipo}/${codigo}` };
}

// ---- El servidor -----------------------------------------------------------
async function atender(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = new URL(req.url);
    let cuerpo: Json = {};
    if (req.method !== "GET") { try { cuerpo = await req.json(); } catch { /* cuerpo vacío */ } }
    const accion = String(cuerpo.accion ?? url.searchParams.get("accion") ?? url.searchParams.get("paso") ?? "");
    if (accion === "salud") {
      return responder({ ok: true, entorno: PLAID_ENV, llaves: Boolean(PLAID_CLIENT_ID && PLAID_SECRET), rutina: RUTINA_SECRETO.length >= 32,
                         redirect: Boolean(REDIRECT_URI), base: Boolean(DB_URL), sesion: BANCO_PRUEBAS || Boolean(SUPABASE_URL && SERVICE_KEY),
                         banco_de_pruebas: BANCO_PRUEBAS });
    }
    if (!PLAID_CLIENT_ID || !PLAID_SECRET || !DB_URL || (!BANCO_PRUEBAS && (!SUPABASE_URL || !SERVICE_KEY))) {
      console.error("plaid: faltan PLAID_CLIENT_ID / PLAID_SECRET o la base (SUPABASE_DB_URL / MXP_DB_URL) (Edge Functions → Secrets)");
      throw new Fallo(500, "Falta configurar la función (las llaves de Plaid o la base) en Supabase → Edge Functions → Secrets.");
    }
    const base = await obtenerBase();

    // 1. Plaid avisa (webhook): no trae sesión
    if (typeof cuerpo.webhook_type === "string") return responder(await webhook(base, cuerpo));

    // 2. La rutina de la mañana (pg_cron → pg_net), con su secreto
    const rutina = req.headers.get("x-mxp-rutina");
    if (rutina !== null) {
      if (RUTINA_SECRETO.length < 32 || !igual(rutina, RUTINA_SECRETO)) throw new Fallo(401, "no autorizado");
      if (accion !== "sincronizar_todo") throw new Fallo(400, "La rutina solo sabe «sincronizar_todo».");
      return responder(await sincronizarTodo(base, "rutina"));
    }

    // 3. El dueño, con su sesión
    const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!jwt) throw new Fallo(401, "Entra con tu sesión (falta Authorization).");
    const quien = await base.quien(jwt);
    if (!quien) throw new Fallo(401, "La sesión no vale o venció. Vuelve a entrar.");
    if (quien.rol !== "dueno" || !quien.activo) throw new Fallo(403, "La conexión con el banco la maneja solo Edgar (el dueño).");

    switch (accion) {
      case "estado": {
        const conexiones = await base.rpc("fn_plaid_activas", {});
        return responder({ ok: true, entorno: PLAID_ENV, redirect: Boolean(REDIRECT_URI), conexiones });
      }
      case "link_token": {
        const item_id = typeof cuerpo.item_id === "string" ? cuerpo.item_id : "";
        const pedido: Json = {
          client_name: "Max Power Panel", language: "es", country_codes: ["US"],
          user: { client_user_id: quien.id },
          webhook: WEBHOOK_URL || (SUPABASE_URL ? `${SUPABASE_URL}/functions/v1/plaid` : `${url.origin}${url.pathname}`),
        };
        if (REDIRECT_URI) pedido.redirect_uri = REDIRECT_URI;
        if (item_id) pedido.access_token = await base.rpc("fn_plaid_token", { p_item_id: item_id }); // modo «volver a conectar»
        else { pedido.products = ["transactions"]; pedido.transactions = { days_requested: DIAS }; }
        const r = await plaid("/link/token/create", pedido);
        return responder({ ok: true, link_token: r.link_token, expiration: r.expiration, reconexion: Boolean(item_id) });
      }
      case "canjear": {
        const public_token = typeof cuerpo.public_token === "string" ? cuerpo.public_token : "";
        if (!public_token) throw new Fallo(400, "Falta el public_token que devuelve Plaid Link.");
        const meta = (cuerpo.metadata as Json | undefined) ?? {};
        const metaInst = (meta.institution as Json | undefined) ?? {};
        const ex = await plaid("/item/public_token/exchange", { public_token });
        const access_token = String(ex.access_token), item_id = String(ex.item_id);
        try {
          const acc = await plaid("/accounts/get", { access_token });
          const item = (acc.item as Json | undefined) ?? {};
          const institucion_id = (typeof metaInst.institution_id === "string" && metaInst.institution_id) || (typeof item.institution_id === "string" ? item.institution_id : null);
          let institucion = typeof metaInst.name === "string" && metaInst.name ? metaInst.name : null;
          if (!institucion && institucion_id) {
            try { institucion = String(((await plaid("/institutions/get_by_id", { institution_id: institucion_id, country_codes: ["US"] })).institution as Json)?.name ?? ""); } catch { /* sin nombre */ }
          }
          const lista = ((acc.accounts as Json[]) ?? []).map((a) => limpiar({ account_id: a.account_id, mask: a.mask, nombre: a.name, oficial: a.official_name, tipo: a.type, subtipo: a.subtype }));
          const res = await base.rpc("fn_plaid_item_alta", { p_item_id: item_id, p_access_token: access_token, p_institucion_id: institucion_id, p_institucion: institucion || null, p_cuentas: lista, p_dueno: quien.id });
          return responder({ ok: true, conexion: res });
        } catch (e) {
          // el token ya existe en Plaid y no quedó guardado: se quita allá para no dejar una conexión huérfana
          try { await plaid("/item/remove", { access_token }); } catch { /* se informa el error original */ }
          throw e;
        }
      }
      case "fijar_cuenta": {
        const item_id = typeof cuerpo.item_id === "string" ? cuerpo.item_id : "";
        const account_id = typeof cuerpo.account_id === "string" ? cuerpo.account_id : "";
        const cuenta = typeof cuerpo.cuenta === "string" ? cuerpo.cuenta.trim() : "";
        if (!item_id || !account_id || !cuenta) throw new Fallo(400, "Faltan la conexión, la cuenta de Plaid o la cuenta del plan.");
        const res = await base.rpc("fn_plaid_cuenta_fijar", { p_item_id: item_id, p_account_id: account_id, p_cuenta: cuenta });
        return responder({ ok: true, conexion: res });
      }
      case "sincronizar": {
        const item_id = typeof cuerpo.item_id === "string" ? cuerpo.item_id : "";
        if (!item_id) throw new Fallo(400, "Falta el item_id de la conexión.");
        const cx = (await base.rpc("fn_plaid_conexion", { p_item_id: item_id })) as Json;
        if (cx.estado === "desconectada") throw new Fallo(409, "Esa conexión está desconectada: conéctala otra vez.", "MX008");
        const r = await sincronizar(base, cx, "pantalla");
        return responder(r, r.ok ? 200 : r.codigo === "SIN_FIJAR" ? 409 : 502);
      }
      case "sincronizar_todo":
        return responder(await sincronizarTodo(base, "pantalla"));
      case "desconectar": {
        const item_id = typeof cuerpo.item_id === "string" ? cuerpo.item_id : "";
        if (!item_id) throw new Fallo(400, "Falta el item_id de la conexión.");
        let aviso: string | undefined;
        try {
          const token = String(await base.rpc("fn_plaid_token", { p_item_id: item_id }));
          await plaid("/item/remove", { access_token: token });
        } catch (e) { aviso = `Plaid no pudo quitar la conexión (${e instanceof Error ? e.message : e}); queda desconectada aquí de todos modos.`; }
        const res = await base.rpc("fn_plaid_desconectar", { p_item_id: item_id, p_motivo: typeof cuerpo.motivo === "string" && cuerpo.motivo ? cuerpo.motivo : "desde la pantalla" });
        return responder(limpiar({ ok: true, conexion: res, aviso }));
      }
      default:
        throw new Fallo(400, `Acción desconocida: «${accion}».`);
    }
  } catch (e) {
    if (e instanceof Fallo) return responder(limpiar({ ok: false, error: e.message, codigo: e.codigo }), e.estado);
    console.error("plaid:", e);
    return responder({ ok: false, error: e instanceof Error ? e.message : String(e) }, 500);
  }
}

if (PUERTO) Deno.serve({ port: PUERTO, hostname: "127.0.0.1" }, atender);
else Deno.serve(atender);
