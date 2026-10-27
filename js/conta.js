// ============================================================
// Max Power — Contabilidad (f05/f06): la pantalla del banco.
//
// Lo que hace: enseña los saldos de los bancos y las tarjetas
// (v_banco_saldos), sube el archivo del banco (fn_banco_importar_ofx y
// después fn_banco_casar_todo hasta que diga «completo»), pinta la
// bandeja (v_banco_bandeja: un botón por cada opción que propone la
// base, con su motivo cuando lo pide) y concilia (fn_conciliar,
// v_conciliacion, v_conciliacion_partidas, fn_conciliacion_confirmar).
//
// Tres reglas (docs/conta/fases/f05-pantalla.md):
//   · Solo Edgar: la base lo exige (es_dueno()); la app solo esconde la
//     entrada al equipo. Nada de dinero se guarda en el teléfono.
//   · Solo con señal: sin señal no se pinta nada de memoria.
//   · Falla ruidosa: antes de pintar, fn_banco_control dice si cada vista
//     devuelve lo que las tablas tienen; si no, un rojo con el detalle y
//     la pantalla no pinta ceros.
// La conexión es la de js/db.js (MXP_DB._leer, MXP_DB._rpc; MXP_DB._funcion
// para la función de borde `plaid`: la conexión automática con el banco).
// Y los cobros en línea (p1: v_stripe_estado, v_stripe_control, v_stripe_facturas,
// v_stripe_pagos, v_stripe_payouts, v_stripe_avisos; la función de borde `stripe`
// con la sesión del dueño para todo lo que habla con Stripe).
// Y los estados financieros (c4: v_cortes, v_resultados, v_balance_general,
// v_balanza, v_mayor, v_libro, v_asiento_papel, v_flujo_caja, v_comparacion,
// v_comparacion_resumen; control fn_estados_control): solo lectura, cada
// cifra viene lista de la base y baja hasta su asiento y su papel.
// ============================================================

(function () {
  "use strict";

  const DB = window.MXP_DB;
  const $ = id => document.getElementById(id);
  const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
  const MES = ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
  const esc = s => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const num = v => (v == null || v === "") ? null : Number(v);
  const fmt = v => { const n = num(v); return n == null || Number.isNaN(n) ? "—" : money.format(n); };
  const fmtAbs = v => { const n = num(v); return n == null ? "—" : money.format(Math.abs(n)); };
  const partes = iso => String(iso || "").slice(0, 10).split("-").map(Number);
  const fecha = iso => { if (!iso) return "—"; const [, m, d] = partes(iso); return `${d} ${MES[m] || ""}`; };
  const fechaLarga = iso => { if (!iso) return "—"; const [a, m, d] = partes(iso); return `${d} ${MES[m] || ""} ${a}`; };
  // El día de hoy en Miami (la base cuenta los días con fn_fecha_miami)
  const hoyMiami = () => new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  const plural = (n, uno, varios) => `${n} ${Number(n) === 1 ? uno : varios}`;

  // ---------- Estado en memoria (nada se guarda en el teléfono) ----------
  const S = {
    pagina: "bancos",
    hooks: { titulo() {}, avisar() {} },
    saldos: null, cuentas: null, proyectos: null, bandeja: null,
    conc: null, concCuenta: null, movCuenta: null, movEstado: "", filtroCuenta: null,
    importe: null, ocupado: false,
    plaid: null, plaidErr: null, mfa: null,
    // Stripe (p1): la fila de v_stripe_estado, por qué no se leyó, la salud de la función, los depósitos asentados (para la bandeja) y la pestaña
    stripe: null, stripeErr: null, stripeSalud: null, stripePayouts: null, cobros: null,
    // Estados financieros: qué estado (sub), qué período, la bajada cuenta → asiento,
    // el método del flujo, la caché de v_cortes (con el día en que se leyó) y la serie contra el doble pintado
    est: { sub: "resultados", periodo: null, cuenta: null, asiento: null, metodo: "directo", cortes: null, cortesDia: null, todos: false, avisoHoy: false, serie: 0 }
  };
  const TITULOS = { bancos: "Bancos y tarjetas", bandeja: "Bandeja del banco", conciliar: "Conciliar", movimientos: "Movimientos", estados: "Estados financieros", cobros: "Cobros en línea" };
  const PESTANAS = { bancos: "Bancos y tarjetas", bandeja: "Bandeja", conciliar: "Conciliar", movimientos: "Movimientos", estados: "Estados", cobros: "Cobros en línea" };
  const KICKER = "Contabilidad · solo dueño";

  const raiz = () => $("conta-raiz");
  const main = () => $("ct-main");

  // ---------- El marco: pestañas arriba, la página debajo ----------
  function armar() {
    const r = raiz(); if (!r) return;
    r.innerHTML = `<nav class="ct-tabs" aria-label="Contabilidad">${Object.keys(PESTANAS).map(k =>
      `<button type="button" class="ct-tab" data-pag="${k}" aria-current="${k === S.pagina ? "page" : "false"}">${esc(PESTANAS[k])}${k === "bandeja" ? `<span class="ct-n" id="ct-n-bandeja" hidden></span>` : ""}</button>`).join("")}</nav>
      <div id="ct-main" class="ct-main"></div>`;
    r.querySelectorAll(".ct-tab").forEach(b => b.addEventListener("click", () => ir(b.dataset.pag)));
    pintarBadge();
  }
  function marcarPestana() {
    const r = raiz(); if (!r) return;
    r.querySelectorAll(".ct-tab").forEach(b => b.setAttribute("aria-current", b.dataset.pag === S.pagina ? "page" : "false"));
  }
  function pintarBadge() {
    const n = $("ct-n-bandeja"); if (!n) return;
    const total = S.bandeja ? S.bandeja.length
      : S.saldos ? S.saldos.reduce((s, c) => s + Number(c.pendientes || 0), 0) : null;
    n.hidden = !total;
    n.textContent = total || "";
  }
  function ir(pag, opciones = {}) {
    if (!PAGINAS[pag]) pag = "bancos";
    S.pagina = pag;
    S.conc = null;
    if (opciones.cuenta !== undefined) {
      if (pag === "bandeja") S.filtroCuenta = opciones.cuenta;
      if (pag === "conciliar") S.concCuenta = opciones.cuenta;
      if (pag === "movimientos") S.movCuenta = opciones.cuenta;
    }
    if (pag === "estados") {
      // la pestaña tocada sin más (o la app recién abierta) vuelve a leer v_cortes: un mes nuevo o un período cerrado se ven sin recargar
      if (!Object.keys(opciones).length) S.est.cortes = null;
      for (const k of ["sub", "periodo", "cuenta", "asiento", "metodo"]) if (opciones[k] !== undefined) S.est[k] = opciones[k];
      // cambiar de estado o de período vuelve a la raíz; ir a una cuenta cierra el asiento
      if (opciones.sub !== undefined || opciones.periodo !== undefined) { S.est.cuenta = null; S.est.asiento = null; }
      else if (opciones.cuenta !== undefined && opciones.asiento === undefined) S.est.asiento = null;
    }
    marcarPestana();
    S.hooks.titulo(KICKER, TITULOS[pag]);
    window.scrollTo(0, 0);
    return PAGINAS[pag]();
  }

  // ---------- Cargando, sin señal, errores y el rojo del control ----------
  function cargando(txt) {
    const m = main(); if (m) m.innerHTML = `<div class="ct-card ct-cargando">${esc(txt || "Cargando…")}</div>`;
  }
  function esFalloDeRed(err) {
    const m = String((err && err.message) || err || "");
    return (err instanceof TypeError) || /failed to fetch|load failed|networkerror|network request failed/i.test(m);
  }
  let reintentarPendiente = null;
  function sinSenal(reintentar) {
    reintentarPendiente = reintentar;
    main().innerHTML = `<div class="ct-card ct-rojo" role="alert"><h2>Sin señal</h2>
      <p>La contabilidad trabaja solo con señal: nada se guarda en el teléfono y nada se pinta de memoria. Cuando vuelva, toca «Reintentar».</p>
      <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-reintentar">Reintentar</button></div></div>`;
    $("ct-reintentar").addEventListener("click", reintentar);
  }
  window.addEventListener("online", () => {
    const v = $("vista-conta");
    if (v && !v.hidden && reintentarPendiente) { const f = reintentarPendiente; reintentarPendiente = null; f(); }
  });
  function errorControl(titulo, mal) { const e = new Error(titulo); e.control = mal || []; return e; }
  // `cont`: dónde pintar el rojo (por omisión toda la página; los estados lo pintan debajo de su barra)
  function pintarError(err, reintentar, titulo, cont) {
    if (esFalloDeRed(err) || !navigator.onLine) return sinSenal(reintentar);
    const filas = err.control ? err.control.map(f => `<tr><td>${esc(f.vista)}</td><td class="r ct-num">${f.filas == null ? "—" : esc(f.filas)}</td><td class="r ct-num">${f.esperadas == null ? "—" : esc(f.esperadas)}</td><td>${esc(f.detalle || "")}</td></tr>`).join("") : "";
    (cont || main()).innerHTML = `<div class="ct-card ct-rojo" role="alert">
      <h2>${esc(titulo || (err.control ? err.message : "La base no contestó bien"))}</h2>
      ${err.control ? `<p>La pantalla no pinta nada hasta que esto cuadre: pintar ceros sería mentir. ${err.control.length ? "Lo que no cuadra:" : ""}</p>
        ${filas ? `<div class="ct-tabla-env"><table class="ct-tabla"><thead><tr><th>Vista</th><th class="r">Trajo</th><th class="r">Debía</th><th>Detalle</th></tr></thead><tbody>${filas}</tbody></table></div>` : ""}`
        : `<p>${esc(err.message)}</p>${err.crudo && err.crudo !== err.message ? `<p class="ct-crudo">${esc(err.crudo)}</p>` : ""}`}
      <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-reintentar">Reintentar</button></div></div>`;
    $("ct-reintentar").addEventListener("click", reintentar);
  }

  // FALLA RUIDOSA: el control del banco, con las vistas que esta página va a
  // pintar. `conteos` es lo que la pantalla trajo de cada vista; si no es lo
  // que el control contó, también es rojo.
  async function controlar(vistas, conteos) {
    const filas = await DB._rpc("fn_banco_control", { p_periodo: "hoy", p_vistas: vistas });
    if (!Array.isArray(filas) || !filas.length) throw errorControl("El control del banco no devolvió ninguna fila", [{ vista: vistas.join(", "), detalle: "fn_banco_control('hoy', …) contestó vacío" }]);
    const mal = filas.filter(f => !f.ok).map(f => ({ vista: f.vista, filas: f.filas, esperadas: f.esperadas, detalle: f.detalle }));
    for (const vista of vistas) {
      const f = filas.find(x => x.vista === vista);
      if (!f) { mal.push({ vista, detalle: "el control no revisó esta vista" }); continue; }
      const n = conteos && conteos[vista];
      if (f.ok && n != null && Number(f.filas) !== Number(n)) {
        mal.push({ vista, filas: f.filas, esperadas: n, detalle: `la pantalla trajo ${n} fila(s) y el control contó ${f.filas}` });
      }
    }
    if (mal.length) throw errorControl("El control del banco no cuadra", mal);
    return filas;
  }

  // ---------- Lecturas que se repiten ----------
  const leerSaldos = async () => { S.saldos = await DB._leer("v_banco_saldos?select=*&order=tipo.asc,cuenta.asc"); return S.saldos; };
  const saldos = () => S.saldos ? Promise.resolve(S.saldos) : leerSaldos();
  const cuentas = async () => S.cuentas || (S.cuentas = await DB._leer("cuentas?select=codigo,nombre,tipo,regla_obra&imputable=eq.true&activa=eq.true&order=codigo.asc"));
  const proyectos = async () => S.proyectos || (S.proyectos = await DB._leer("proyectos?select=id,nombre,estado&order=nombre.asc"));
  const nombreCuenta = cod => { const c = (S.saldos || []).find(x => x.cuenta === cod) || (S.cuentas || []).find(x => x.codigo === cod); return c ? (c.cuenta_nombre || c.nombre) : cod; };

  const pill = (txt, clase) => `<span class="ct-pill${clase ? " " + clase : ""}">${esc(txt)}</span>`;
  const estadoPill = e => pill(({ abierta: "abierta", confirmada: "confirmada", anulada: "anulada" })[e] || e, ({ abierta: "warn", confirmada: "ok", anulada: "bad" })[e] || "");

  // ============================================================
  // BANCOS Y TARJETAS
  // ============================================================
  async function pintarBancos() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarBancos);
    let lista;
    try {
      lista = await leerSaldos();
      await controlar(["v_banco_saldos"], { v_banco_saldos: lista.length });
      if (!lista.length) throw errorControl("La base no devolvió ninguna cuenta de banco ni tarjeta", [{ vista: "v_banco_saldos", filas: 0, esperadas: "1 o más", detalle: "La empresa tiene Chase y las dos Amex. Si la vista no las trae, algo está mal (¿la sesión no es la del dueño?)." }]);
      await leerPlaid();
      await leerMfa();
      // los cobros en línea: la fila de su estado (fresca) y la salud de la función; si p1 no está, la tarjeta lo dice
      await leerStripe(true);
      if (S.stripe) await leerSalud();
    } catch (err) { return pintarError(err, pintarBancos); }
    pintarBadge();
    // la 1020 y la 1140 (Stripe) no se pintan como bancos; el control de arriba contó la lista entera
    const vis = visibles(lista);
    main().innerHTML = importadorHTML(vis) + (S.importe ? importeHTML(S.importe) : "") +
      mfaHTML(S.mfa) + plaidHTML(S.plaid || [], S.plaidErr) + stripeHTML(S.stripe, S.stripeErr, S.stripeSalud) +
      `<div class="ct-rejilla">${vis.map(cuentaHTML).join("")}</div>`;
    // el importador general
    $("ct-imp-btn").addEventListener("click", () => {
      const f = $("ct-imp-archivo").files[0];
      if (!f) { $("ct-imp-res").innerHTML = `<p class="ct-aviso bad">Elige primero el archivo.</p>`; return; }
      importar(f, $("ct-imp-cuenta").value || null, $("ct-imp-res"));
    });
    const cerrar = $("ct-imp-cerrar"); if (cerrar) cerrar.addEventListener("click", () => { S.importe = null; pintarBancos(); });
    // las tarjetas de cada cuenta
    main().querySelectorAll(".ct-cuenta").forEach(card => {
      const cuenta = card.dataset.cuenta;
      card.querySelectorAll("[data-ir]").forEach(b => b.addEventListener("click", () => ir(b.dataset.ir, { cuenta })));
      const inp = card.querySelector("input[type=file]");
      if (inp) inp.addEventListener("change", () => { if (inp.files[0]) importar(inp.files[0], cuenta, card.querySelector(".ct-cuenta-res")); });
    });
    wireMfa();
    wirePlaid();
    wireStripe();
  }

  function importadorHTML(lista) {
    return `<section class="ct-card ct-importar">
      <h2>Subir el archivo del banco o de la tarjeta</h2>
      <p class="ct-nota">El QFX (Quicken) que baja de Chase o de Amex. La cuenta la dice el archivo; el primer archivo de un banco necesita que la elijas aquí. El mismo archivo dos veces no entra dos veces, y lo que ya estaba no se repite.</p>
      <div class="ct-fila">
        <label class="ct-campo">Cuenta<select id="ct-imp-cuenta"><option value="">La que diga el archivo</option>${lista.map(c => `<option value="${esc(c.cuenta)}">${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
        <label class="ct-campo">Archivo<input id="ct-imp-archivo" type="file" accept=".qfx,.ofx,.qbo,.xml,.txt"></label>
        <button type="button" class="accion" id="ct-imp-btn">Subir y casar</button>
      </div>
      <div id="ct-imp-res"></div>
    </section>`;
  }
  function importeHTML(x) {
    const r = x.r, k = x.casar;
    const motivos = Object.entries(k.por_motivo || {}).filter(([, v]) => Number(v) > 0).map(([m, v]) => `${v} ${motivoLlano(m).toLowerCase()}`).join(", ");
    return `<section class="ct-card ct-ok-box">
      <div class="ct-cab"><h2>Entró ${esc(x.archivo)}</h2><button type="button" class="ct-x" id="ct-imp-cerrar" title="Cerrar">×</button></div>
      <p>${resumenImporte(r)}</p>
      <p><b>${plural(k.casados, "movimiento casó solo", "movimientos casaron solos")}</b>${k.rondas > 1 ? ` (en ${k.rondas} rondas)` : ""}; <b>${plural(k.pendientes, "espera", "esperan")}</b> en la bandeja${motivos ? ` (${motivos})` : ""}.</p>
      ${Array.isArray(r.avisos) && r.avisos.length ? `<ul class="ct-avisos">${r.avisos.map(a => `<li>${esc(typeof a === "string" ? a : (a.texto || JSON.stringify(a)))}</li>`).join("")}</ul>` : ""}
      ${k.pendientes ? `<div class="ct-acciones"><button type="button" class="accion" data-ir="bandeja" id="ct-imp-bandeja">Ir a la bandeja</button></div>` : ""}
    </section>`;
  }
  function resumenImporte(r) {
    if (!r) return "";
    const n = k => Number(r[k] || 0);
    return `${plural(n("filas_leidas"), "fila leída", "filas leídas")} (${r.formato || "archivo"}): ${n("filas_nuevas")} nueva(s), ${n("filas_repetidas")} repetida(s), ${n("filas_fuera")} fuera${n("antes_del_corte") ? `, ${n("antes_del_corte")} de antes del corte` : ""}. ` +
      (r.saldo != null ? `Saldo según el banco ${fmt(r.saldo)} al ${fechaLarga(r.saldo_al)}` : "El archivo no trae saldo") + (r.cuenta ? ` · cuenta ${esc(r.cuenta)}` : "") + ".";
  }

  function cuentaHTML(c) {
    const tarjeta = c.tipo === "tarjeta";
    const librosAl = c.saldo_libros_al == null ? null : (tarjeta ? -num(c.saldo_libros_al) : num(c.saldo_libros_al));
    const bancoCB = num(c.saldo_banco_como_banco);
    const dif = librosAl == null || bancoCB == null ? null : Math.round((librosAl - bancoCB) * 100) / 100;
    return `<article class="ct-card ct-cuenta${c.alarma ? " alarma" : ""}" data-cuenta="${esc(c.cuenta)}">
      <div class="ct-cab"><h2>${esc(c.cuenta_nombre)}</h2>${pill(`${tarjeta ? "Tarjeta" : "Banco"} · ${c.cuenta}`)}${c.activa === false ? pill("inactiva", "warn") : ""}</div>
      <div class="ct-kpis">
        <div class="ct-kpi"><span class="ct-lbl">${tarjeta ? "Deuda en libros" : "Saldo en libros"}</span><span class="ct-val ct-num">${fmt(c.saldo_libros_como_banco)}</span><span class="ct-sub">hoy</span></div>
        <div class="ct-kpi"><span class="ct-lbl">Según el banco</span><span class="ct-val ct-num">${c.saldo_banco == null ? "—" : fmt(bancoCB)}</span><span class="ct-sub">${c.saldo_banco_al ? "al " + fechaLarga(c.saldo_banco_al) : "sin archivo todavía"}</span></div>
      </div>
      <ul class="ct-datos">
        ${dif != null ? `<li>Al ${fecha(c.saldo_banco_al)} los libros decían <span class="ct-num">${fmt(librosAl)}</span>: ${dif === 0 ? `<span class="ct-ok-txt">igual que el banco</span>` : `diferencia <span class="ct-num">${fmt(dif)}</span>${c.pendientes ? " (lo pendiente la explica)" : ""}`}</li>` : ""}
        <li>Pendientes en la bandeja: <b>${c.pendientes}</b>${Number(c.pendientes) ? ` por <span class="ct-num">${fmt(c.pendientes_monto)}</span>, el más viejo del ${fecha(c.pendiente_mas_viejo)}` : ""}</li>
        <li>En tránsito: <b>${c.en_transito}</b></li>
        <li>Última conciliación: ${c.ultima_conciliacion ? `${fechaLarga(c.ultima_conciliacion)} ${estadoPill(c.ultima_conciliacion_estado)} diferencia <span class="ct-num">${fmt(c.ultima_conciliacion_diferencia)}</span>` : "ninguna"}</li>
        <li>${plural(c.dias_sin_conciliar, "día", "días")} sin conciliación confirmada${c.cubierto_hasta ? ` · archivos hasta el ${fechaLarga(c.cubierto_hasta)}` : ""}${c.ultimo_archivo ? ` · último: ${esc(c.ultimo_archivo)}` : ""}</li>
      </ul>
      ${c.alarma && c.alarma_texto ? `<p class="ct-aviso warn">${esc(c.alarma_texto)}</p>` : ""}
      <div class="ct-acciones">
        <button type="button" class="accion secundaria" data-ir="bandeja">Bandeja${Number(c.pendientes) ? ` (${c.pendientes})` : ""}</button>
        <button type="button" class="accion secundaria" data-ir="conciliar">Conciliar</button>
        <button type="button" class="accion secundaria" data-ir="movimientos">Movimientos</button>
        <label class="accion secundaria ct-subir">Subir su archivo<input type="file" accept=".qfx,.ofx,.qbo,.xml,.txt" hidden></label>
      </div>
      <div class="ct-cuenta-res"></div>
    </article>`;
  }

  // El archivo como texto. Los QFX vienen en ASCII; si dice CHARSET:1252 y el
  // UTF-8 dejó marcas de reemplazo, se lee como Windows-1252.
  async function leerArchivo(file) {
    const buf = await file.arrayBuffer();
    let texto = new TextDecoder("utf-8").decode(buf);
    if (/CHARSET:1252/i.test(texto) && texto.includes("�")) {
      try { texto = new TextDecoder("windows-1252").decode(buf); } catch { /* se queda el utf-8 */ }
    }
    return texto;
  }
  async function importar(file, cuenta, caja) {
    if (!file || S.ocupado) return;
    S.ocupado = true;
    caja.innerHTML = `<p class="ct-aviso">Subiendo ${esc(file.name)}…</p>`;
    try {
      const texto = await leerArchivo(file);
      if (!texto.trim()) throw new Error("El archivo está vacío.");
      const r = await DB._rpc("fn_banco_importar_ofx", { p_texto: texto, p_cuenta: cuenta || null, p_nombre: file.name });
      caja.innerHTML = `<p class="ct-aviso ok">${resumenImporte(r)} Casando…</p>`;
      const casar = await casarTodo(r && r.cuenta ? r.cuenta : cuenta);
      S.importe = { archivo: file.name, r: r || {}, casar };
      S.hooks.avisar(`Archivo subido: ${Number((r || {}).filas_nuevas || 0)} nuevo(s) · ${casar.casados} casaron solos · ${casar.pendientes} en la bandeja`);
      S.bandeja = null;
      await pintarBancos();
    } catch (err) {
      caja.innerHTML = `<p class="ct-aviso bad"><b>No entró.</b> ${esc(esFalloDeRed(err) ? "Sin señal: vuelve a intentarlo cuando la tengas (el archivo no subió)." : err.message)}</p>`;
    } finally { S.ocupado = false; }
  }
  // «Casar» hasta que la base diga que terminó (con meses atrasados corta por
  // reloj y devuelve completo: false; lo casado se queda y la siguiente
  // llamada sigue donde quedó).
  async function casarTodo(cuenta) {
    const total = { casados: 0, pendientes: 0, por_motivo: {}, por_regla: {}, rondas: 0, ms: 0 };
    for (let i = 0; i < 25; i++) {
      const r = (await DB._rpc("fn_banco_casar_todo", { p_cuenta: cuenta || null })) || {};
      total.rondas += 1;
      total.casados += Number(r.casados || 0);
      total.pendientes = Number(r.pendientes || 0);
      total.ms += Number(r.ms || 0);
      total.por_motivo = r.por_motivo || total.por_motivo;
      for (const [k, v] of Object.entries(r.por_regla || {})) total.por_regla[k] = (total.por_regla[k] || 0) + Number(v || 0);
      if (r.completo !== false) break;
    }
    return total;
  }

  // ============================================================
  // EL CÓDIGO DEL TELÉFONO (segundo factor, TOTP) — docs/conta/s1-mfa.sql y
  // MXP_DB.mfa (js/db.js). Se activa aquí una vez: Supabase Auth da el QR,
  // Edgar lo escanea con Contraseñas del iPhone y escribe los 6 dígitos; la
  // sesión pasa a aal2 y, desde entonces, entrar a la app pide el código.
  // «Conectar un banco» (Plaid) solo con el código activo y pasado.
  // ============================================================
  const mfaActivo = () => !!(S.mfa && !S.mfa.error && S.mfa.verificados.length && S.mfa.nivel === "aal2");
  async function leerMfa() {
    if (S.mfa) return S.mfa;
    if (!DB.mfa || typeof DB.mfa.factores !== "function") { S.mfa = { verificados: [], sinVerificar: [], nivel: null, error: new Error("js/db.js viejo: recarga la app") }; return S.mfa; }
    try {
      const fs = await DB.mfa.factores();
      S.mfa = { verificados: fs.filter(f => f.status === "verified"), sinVerificar: fs.filter(f => f.status !== "verified"), nivel: DB.mfa.nivel(), error: null };
    } catch (err) {
      if (esFalloDeRed(err)) throw err;
      S.mfa = { verificados: [], sinVerificar: [], nivel: DB.mfa.nivel(), error: err };
    }
    return S.mfa;
  }
  function mfaHTML(m) {
    if (!m) return "";
    const activo = m.verificados.length > 0;
    const estado = m.error ? pill("sin leer", "warn") : !activo ? pill("no activo", "warn") : m.nivel === "aal2" ? pill("activo", "ok") : pill("activo · esta sesión no lo pasó", "warn");
    return `<section class="ct-card ct-mfa" id="ct-mfa">
      <div class="ct-cab"><h2>El código del teléfono (segundo paso para entrar)</h2>${estado}</div>
      ${m.error
        ? `<p class="ct-nota">No se pudo leer el estado del código: ${esc(m.error.message)}. Si Supabase dice que el segundo factor está apagado, se enciende en Authentication → Multi-Factor Auth (TOTP).</p>`
        : activo
          ? `<p class="ct-nota">Al entrar a la app, después de la contraseña se piden los 6 dígitos de tu teléfono (${esc(m.verificados.map(f => f.friendly_name || "teléfono").join(", "))}). Es lo que protege tus bancos y lo que declaramos a Plaid.${m.nivel === "aal2" ? "" : " Esta sesión entró sin él: sal y vuelve a entrar con el código para conectar un banco."}</p>
             <div class="ct-acciones"><button type="button" class="accion secundaria chica" id="ct-mfa-quitar"${m.nivel === "aal2" ? "" : " disabled"}>Quitar el código</button></div>`
          : `<p class="ct-nota">Antes de conectar un banco de verdad, la entrada a la app lleva un segundo paso: los 6 dígitos que da Contraseñas del iPhone (o tu app de códigos). Se activa una sola vez, mejor desde la computadora: sale un código QR y lo escaneas con el teléfono.</p>
             <div class="ct-acciones"><button type="button" class="accion" id="ct-mfa-activar">Activar el código</button></div>`}
      <div class="ct-form" hidden></div>
      <div id="ct-mfa-res"></div>
    </section>`;
  }
  // El QR que da Supabase Auth: texto SVG (con su prólogo <?xml …?>) o un
  // data: URI sin codificar. Para la etiqueta <img> tiene que ir como data:
  // URI codificado («#» y «<» rompen un data: URI sin codificar).
  function qrSrc(qr) {
    if (!qr) return "";
    let svg = String(qr);
    if (/^data:image\/svg\+xml/i.test(svg)) {
      const coma = svg.indexOf(",");
      if (coma < 0) return svg;
      if (/base64/i.test(svg.slice(0, coma))) return svg;
      const cuerpo = svg.slice(coma + 1);
      try { svg = decodeURIComponent(cuerpo); } catch { svg = cuerpo; }
    }
    // Antes de <svg> solo puede haber prólogo xml, comentarios (SVGo pone
    // «<!-- Generated by SVGo -->») o doctype; cualquier otra cosa no es un QR.
    const donde = svg.search(/<svg[\s>]/i);
    if (donde < 0) return "";
    const antes = svg.slice(0, donde).replace(/<\?xml[^>]*\?>|<!--[\s\S]*?-->|<!DOCTYPE[^>]*>/gi, "");
    if (/\S/.test(antes)) return "";
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg.slice(donde).trim());
  }
  function wireMfa() {
    const card = $("ct-mfa"); if (!card) return;
    const act = $("ct-mfa-activar"); if (act) act.addEventListener("click", () => activarMfa(card));
    const qui = $("ct-mfa-quitar"); if (qui) qui.addEventListener("click", () => montarForma(card,
      formaHTML("Quitar el código: la entrada vuelve a ser solo con la contraseña y Plaid queda bloqueado hasta activarlo otra vez. ¿Seguro?", "", "Sí, quitarlo"),
      async () => {
        if (S.ocupado) return; S.ocupado = true;
        try {
          for (const f of S.mfa.verificados) await DB.mfa.quitar(f.id);
          S.hooks.avisar("Código quitado: la entrada vuelve a ser solo con la contraseña");
          S.mfa = null; await pintarBancos();
        } catch (err) { mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se quitó." : err.message); }
        finally { S.ocupado = false; }
      }));
  }
  async function activarMfa(card) {
    if (S.ocupado) return;
    if (!navigator.onLine) { $("ct-mfa-res").innerHTML = `<p class="ct-aviso bad">Sin señal: activar el código necesita internet.</p>`; return; }
    S.ocupado = true;
    const caja = $("ct-mfa-res");
    caja.innerHTML = `<p class="ct-aviso">Pidiendo el código QR a Supabase…</p>`;
    let e;
    try {
      // un intento anterior a medias se limpia primero (Supabase no deja dos con el mismo nombre)
      for (const f of (S.mfa && S.mfa.sinVerificar) || []) { try { await DB.mfa.quitar(f.id); } catch { /* sigue */ } }
      e = await DB.mfa.enrolar("Teléfono de Edgar");
      caja.innerHTML = "";
    } catch (err) {
      caja.innerHTML = `<p class="ct-aviso bad">No se pudo empezar: ${esc(esFalloDeRed(err) ? "sin señal." : err.message)}${/disabled|not enabled|mfa/i.test(err.message) ? " En Supabase: Authentication → Multi-Factor Auth → TOTP encendido." : ""}</p>`;
      S.ocupado = false; return;
    }
    S.ocupado = false;
    const f = card.querySelector(".ct-form");
    f.hidden = false;
    f.innerHTML = `<form class="ct-pide" novalidate>
      <p class="ct-form-t">1 · En el iPhone, abre <b>Contraseñas</b> → «+» → «Código de verificación» → escanea este código (o pega la clave de abajo).</p>
      <div class="ct-qr-fila">${qrSrc(e.qr) ? `<img class="ct-qr" alt="Código QR para la app de códigos" src="${esc(qrSrc(e.qr))}">` : ""}<div><p class="ct-nota">${qrSrc(e.qr) ? "Si no puedes escanear, escribe" : "El QR no llegó: escribe"} esta clave en Contraseñas:</p><div class="ct-clave">${esc(e.secreto || "")}</div></div></div>
      <p class="ct-form-t">2 · Escribe los 6 dígitos que te enseña el teléfono:</p>
      <label class="ct-campo">Código de 6 dígitos<input name="codigo" inputmode="numeric" autocomplete="one-time-code" maxlength="7" required></label>
      <div class="ct-acciones"><button class="accion" type="submit">Verificar y activar</button><button class="accion secundaria" type="button" data-cerrar>Cancelar</button></div>
    </form>`;
    f.querySelector("[data-cerrar]").addEventListener("click", async () => { f.hidden = true; f.innerHTML = ""; try { await DB.mfa.quitar(e.id); } catch { /* quedará como sin verificar y se limpia la próxima vez */ } S.mfa = null; });
    f.querySelector("form").addEventListener("submit", async ev => {
      ev.preventDefault();
      const codigo = String(new FormData(ev.target).get("codigo") || "").replace(/\s+/g, "");
      if (!/^\d{6}$/.test(codigo)) { mostrarErrorForma(card, "Son 6 dígitos, los que enseña el teléfono ahora mismo."); return; }
      if (S.ocupado) return; S.ocupado = true;
      ev.target.querySelectorAll("button").forEach(b => { b.disabled = true; });
      try {
        await DB.mfa.verificar(e.id, codigo);
        S.hooks.avisar("Código activado: desde ahora, al entrar se piden los 6 dígitos");
        S.mfa = null; await pintarBancos();
      } catch (err) {
        ev.target.querySelectorAll("button").forEach(b => { b.disabled = false; });
        mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se verificó." : /invalid|incorrect|expired|wrong|code/i.test(err.message) ? "Ese código no es válido: mira el teléfono y escribe los 6 dígitos nuevos." : err.message);
      } finally { S.ocupado = false; }
    });
    f.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }

  // ============================================================
  // LA CONEXIÓN AUTOMÁTICA (Plaid) — docs/conta/c7-plaid.sql y la función
  // de borde supabase/functions/plaid. La pantalla lee v_plaid_conexiones y
  // todo lo demás se lo pide a la función con la sesión del dueño (link_token,
  // canjear, fijar_cuenta, sincronizar, desconectar): ninguna función de c7
  // está en la API. Lo ÚNICO que se guarda en el navegador es el link token
  // de la ventana de Plaid mientras el banco redirige (OAuth, p. ej. Chase):
  // no es dinero ni una clave, y se borra al cerrar la ventana.
  // ============================================================
  const PRIVACIDAD = "https://github.com/edgararboleya-rgb/max-power-panel/blob/main/docs/PRIVACY-POLICY.md";
  const PLAID_LINK_JS = "https://cdn.plaid.com/link/v2/stable/link-initialize.js";
  const LLAVE_LINK = "mxp.plaid.link";
  const guardarLink = o => { try { sessionStorage.setItem(LLAVE_LINK, JSON.stringify(o)); } catch { /* sin almacenamiento: la vuelta del OAuth no se retoma */ } };
  const leerLink = () => { try { return JSON.parse(sessionStorage.getItem(LLAVE_LINK) || "null"); } catch { return null; } };
  const borrarLink = () => { try { sessionStorage.removeItem(LLAVE_LINK); } catch { /* nada */ } };
  const fechaHora = ts => {
    if (!ts) return "—";
    const d = new Date(ts); if (Number.isNaN(d.getTime())) return "—";
    const f = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false }).formatToParts(d);
    const g = k => (f.find(x => x.type === k) || {}).value || "";
    return `${fechaLarga(`${g("year")}-${g("month")}-${g("day")}`)} ${g("hour")}:${g("minute")}`;
  };

  async function leerPlaid() {
    if (S.plaid) return S.plaid;
    try { S.plaid = await DB._leer("v_plaid_conexiones?select=*&order=creado_el.asc"); S.plaidErr = null; }
    catch (err) { if (esFalloDeRed(err)) throw err; S.plaid = null; S.plaidErr = err; }
    return S.plaid;
  }
  function plaidHTML(cx, err) {
    const enlace = `<a href="${PRIVACIDAD}" target="_blank" rel="noopener">política de privacidad</a>`;
    if (err) {
      return `<section class="ct-card ct-plaid" id="ct-plaid"><div class="ct-cab"><h2>Conexión automática con el banco (Plaid)</h2>${pill("sin instalar", "warn")}</div>
        <p class="ct-nota">La base todavía no tiene la conexión con Plaid (docs/conta/c7-plaid.sql) o la vista no contestó: ${esc(err.message)}. Mientras tanto, los archivos del banco se suben arriba.</p></section>`;
    }
    const vivas = cx.filter(c => c.estado !== "desconectada");
    return `<section class="ct-card ct-plaid" id="ct-plaid">
      <div class="ct-cab"><h2>Conexión automática con el banco (Plaid)</h2>${pill(vivas.length ? plural(vivas.length, "banco conectado", "bancos conectados") : "sin conectar", vivas.length ? "ok" : "")}</div>
      <p class="ct-nota">Chase y las Amex mandan sus movimientos solos cada mañana, y entran igual que un archivo: casan lo que casa y el resto espera en la bandeja. El banco se conecta en la ventana segura de Plaid: la app nunca ve tu usuario ni tu clave del banco, y las llaves viven en la base, no en el teléfono. Qué se guarda y por cuánto tiempo, en la ${enlace}.</p>
      ${cx.length ? `<div class="ct-lista">${cx.map(conexionHTML).join("")}</div>` : ""}
      <div class="ct-acciones"><button type="button" class="accion" id="ct-plaid-conectar"${mfaActivo() ? "" : " disabled"}>Conectar un banco</button>${mfaActivo() ? "" : `<span class="ct-nota" style="margin:0">Primero activa el código del teléfono (arriba).</span>`}</div>
      <div id="ct-plaid-res"></div>
    </section>`;
  }
  function conexionHTML(c) {
    const est = c.estado === "activa" ? pill("activa", "ok") : c.estado === "error" ? pill("con error", "bad") : pill("desconectada", "");
    const sinFijar = Number(c.cuentas_sin_fijar) > 0;
    const r = c.ultimo_resultado || {};
    const viva = c.estado !== "desconectada";
    return `<article class="ct-conexion ${esc(c.estado)}" data-item="${esc(c.item_id)}">
      <div class="ct-cab"><h3>${esc(c.institucion || "Banco")}</h3>${est}${sinFijar ? pill(`${c.cuentas_sin_fijar} sin fijar`, "warn") : ""}</div>
      <ul class="ct-datos">
        <li>Última sincronización: ${c.ultimo_sync ? fechaHora(c.ultimo_sync) : "ninguna todavía"}${r.agregadas != null ? ` · ${r.agregadas} nueva(s), ${Number(r.modificadas || 0)} cambiada(s), ${Number(r.quitadas || 0)} quitada(s)${r.por_que ? ` (${esc(r.por_que)})` : ""}` : ""}</li>
        ${c.ultimo_error ? `<li class="bad-txt">Error: ${esc(c.ultimo_error)}</li>` : ""}
        ${c.desconectada_el ? `<li>Desconectada el ${fechaLarga(String(c.desconectada_el).slice(0, 10))}${c.desconectada_motivo ? `: ${esc(c.desconectada_motivo)}` : ""}</li>` : ""}
      </ul>
      ${viva ? `<p class="ct-nota">A qué cuenta del plan va cada cuenta del banco${sinFijar ? " (hasta fijarlas todas no se sincroniza nada)" : ""}:</p><div class="ct-cuentas-plaid">${(c.cuentas || []).map(a => cuentaPlaidHTML(a)).join("")}</div>` : ""}
      <div class="ct-acciones">
        ${viva ? `<button type="button" class="accion secundaria chica" data-plaid="sincronizar">Sincronizar ahora</button>` : ""}
        ${c.estado === "error" ? `<button type="button" class="accion secundaria chica" data-plaid="reconectar">Volver a conectar</button>` : ""}
        ${viva ? `<button type="button" class="accion secundaria chica" data-plaid="desconectar">Desconectar</button>` : ""}
      </div>
      <div class="ct-form" hidden></div>
      <div class="ct-conexion-res"></div>
    </article>`;
  }
  function cuentaPlaidHTML(a) {
    const credito = a.tipo === "credit", banco = a.tipo === "depository";
    const opciones = visibles(S.saldos).filter(s => credito ? s.tipo === "tarjeta" : banco ? s.tipo === "banco" : true);
    const que = credito ? "tarjeta de crédito" : (a.subtipo || a.tipo || "cuenta");
    return `<label class="ct-campo ct-cuenta-plaid">${esc(a.nombre || a.oficial || "Cuenta")}${a.mask ? ` ····${esc(a.mask)}` : ""} <small>(${esc(que)})</small>
      <select data-account="${esc(a.account_id)}"${a.cuenta ? "" : ' class="sin-fijar"'}>
        <option value=""${a.cuenta ? "" : " selected"}>— ¿a qué cuenta va? —</option>
        ${opciones.map(s => `<option value="${esc(s.cuenta)}"${a.cuenta === s.cuenta ? " selected" : ""}>${esc(s.cuenta)} · ${esc(s.cuenta_nombre)}</option>`).join("")}
        <option value="ignorar"${a.cuenta === "ignorar" ? " selected" : ""}>Ignorar (no es de la empresa)</option>
      </select>${a.propuesta && !a.cuenta ? `<small>${esc(a.propuesta)}</small>` : ""}</label>`;
  }
  function wirePlaid() {
    const btn = $("ct-plaid-conectar"); if (btn) btn.addEventListener("click", () => conectarPlaid(null));
    main().querySelectorAll(".ct-conexion").forEach(card => {
      const item = card.dataset.item;
      card.querySelectorAll("select[data-account]").forEach(sel => sel.addEventListener("change", async () => {
        if (!sel.value) return;
        const caja = card.querySelector(".ct-conexion-res");
        sel.disabled = true;
        try {
          const r = await DB._funcion("plaid", { accion: "fijar_cuenta", item_id: item, account_id: sel.dataset.account, cuenta: sel.value }, 30000);
          const faltan = Number(((r || {}).conexion || {}).cuentas_sin_fijar || 0);
          S.hooks.avisar(sel.value === "ignorar" ? `Esa cuenta se ignora${faltan ? ` · faltan ${faltan} por fijar` : ""}` : `Va a ${sel.value}${faltan ? ` · faltan ${faltan} por fijar` : " · lista para sincronizar"}`);
          S.plaid = null;
          await pintarBancos();
        } catch (err) {
          sel.disabled = false;
          caja.innerHTML = `<p class="ct-aviso bad">${esc(esFalloDeRed(err) ? "Sin señal: no se guardó." : err.message)}</p>`;
        }
      }));
      card.querySelectorAll("[data-plaid]").forEach(b => b.addEventListener("click", () => {
        const que = b.dataset.plaid;
        if (que === "sincronizar") return accionPlaid(card, { accion: "sincronizar", item_id: item }, resumenSync);
        if (que === "reconectar") return conectarPlaid(item);
        if (que === "desconectar") return montarForma(card, formaHTML("Desconectar este banco (queda escrito por qué; lo ya importado se queda en el libro)", campoHTML("p_motivo", null, null, "required"), "Desconectar"),
          v => accionPlaid(card, { accion: "desconectar", item_id: item, motivo: v.p_motivo }, () => "Banco desconectado"));
        return undefined;
      }));
    });
  }
  function resumenSync(r) {
    const imp = (((r || {}).conexion || {}).ultimo_resultado || {}).importado || [];
    const n = k => imp.reduce((s, x) => s + Number(x[k] || 0), 0);
    if (!imp.length) return "Sincronizado: nada nuevo en el banco";
    return `Sincronizado: ${plural(n("filas_nuevas"), "movimiento nuevo", "movimientos nuevos")}${n("duplicados_posibles") ? `, ${n("duplicados_posibles")} posible(s) duplicado(s)` : ""}${n("filas_repetidas") ? `, ${n("filas_repetidas")} ya estaba(n)` : ""}`;
  }
  async function accionPlaid(card, cuerpo, exito) {
    if (S.ocupado) return;
    S.ocupado = true;
    const caja = card.querySelector(".ct-conexion-res");
    card.querySelectorAll("button, select").forEach(b => { b.disabled = true; });
    caja.innerHTML = `<p class="ct-aviso">${cuerpo.accion === "sincronizar" ? "Pidiendo al banco…" : "Un momento…"}</p>`;
    try {
      const r = await DB._funcion("plaid", cuerpo, 120000);
      S.hooks.avisar(exito(r));
      S.plaid = null; S.saldos = null; S.bandeja = null;
      await pintarBancos();
    } catch (err) {
      card.querySelectorAll("button, select").forEach(b => { b.disabled = false; });
      const sinFijar = err.codigo === "SIN_FIJAR", reconectar = !!(err.datos && err.datos.hay_que_reconectar);
      caja.innerHTML = `<p class="ct-aviso ${sinFijar ? "warn" : "bad"}">${esc(esFalloDeRed(err) ? "Sin señal: no se hizo nada." : err.message)}${reconectar ? " El banco pide volver a conectar." : ""}</p>
        ${reconectar ? `<div class="ct-acciones"><button type="button" class="accion secundaria chica" id="ct-plaid-reconectar-ya">Volver a conectar</button></div>` : ""}`;
      const re = $("ct-plaid-reconectar-ya"); if (re) re.addEventListener("click", () => conectarPlaid(card.dataset.item));
    } finally { S.ocupado = false; }
  }
  function cargarPlaidLink() {
    if (window.Plaid) return Promise.resolve(window.Plaid);
    return new Promise((res, rej) => {
      const sc = document.createElement("script");
      sc.src = PLAID_LINK_JS; sc.async = true;
      sc.onload = () => window.Plaid ? res(window.Plaid) : rej(new Error("La ventana de Plaid no cargó."));
      sc.onerror = () => rej(new Error("No se pudo cargar la ventana de Plaid (cdn.plaid.com). ¿Hay señal?"));
      document.head.appendChild(sc);
    });
  }
  async function conectarPlaid(itemId) {
    const caja = $("ct-plaid-res"); if (!caja || S.ocupado) return;
    if (!navigator.onLine) { caja.innerHTML = `<p class="ct-aviso bad">Sin señal: la ventana de Plaid necesita internet.</p>`; return; }
    if (!mfaActivo()) { caja.innerHTML = `<p class="ct-aviso warn">Antes de conectar un banco, activa el código del teléfono (la tarjeta de arriba) y entra con él.</p>`; return; }
    S.ocupado = true;
    caja.innerHTML = `<p class="ct-aviso">Abriendo la ventana segura de Plaid…</p>`;
    try {
      const [Plaid, r] = await Promise.all([cargarPlaidLink(), DB._funcion("plaid", itemId ? { accion: "link_token", item_id: itemId } : { accion: "link_token" }, 30000)]);
      guardarLink({ token: r.link_token, item_id: itemId || null });
      caja.innerHTML = "";
      abrirLink(Plaid, r.link_token, itemId, null);
    } catch (err) {
      caja.innerHTML = `<p class="ct-aviso bad">${esc(esFalloDeRed(err) ? "Sin señal: inténtalo con internet." : err.message)}</p>`;
    } finally { S.ocupado = false; }
  }
  function abrirLink(Plaid, token, itemId, recibido) {
    const cfg = {
      token,
      onSuccess: (public_token, metadata) => { borrarLink(); if (itemId) reconectado(itemId); else canjear(public_token, metadata); },
      onExit: err => { borrarLink(); if (err) S.hooks.avisar(`Plaid: ${err.display_message || err.error_message || err.error_code || "la ventana se cerró con un error"}`, true); }
    };
    if (recibido) cfg.receivedRedirectUri = recibido;
    Plaid.create(cfg).open();
  }
  async function canjear(public_token, metadata) {
    const caja = $("ct-plaid-res"); if (caja) caja.innerHTML = `<p class="ct-aviso">Guardando la conexión…</p>`;
    try {
      const r = await DB._funcion("plaid", { accion: "canjear", public_token, metadata: metadata || {} }, 60000);
      const c = (r || {}).conexion || {};
      S.hooks.avisar(`${c.institucion || "Banco"} conectado${Number(c.cuentas_sin_fijar) ? ": di a qué cuenta del plan va cada cuenta" : ""}`);
      S.plaid = null;
      await pintarBancos();
    } catch (err) {
      if (caja) caja.innerHTML = `<p class="ct-aviso bad">No se guardó la conexión: ${esc(esFalloDeRed(err) ? "sin señal." : err.message)}</p>`;
    }
  }
  async function reconectado(itemId) {
    S.hooks.avisar("Banco reconectado: sincronizando…");
    S.plaid = null;
    await pintarBancos();
    const card = [...main().querySelectorAll(".ct-conexion")].find(x => x.dataset.item === itemId);
    if (card) accionPlaid(card, { accion: "sincronizar", item_id: itemId }, resumenSync);
  }
  // La vuelta del banco (OAuth): la URL trae ?oauth_state_id=… y la ventana de
  // Plaid se vuelve a abrir con el mismo link token para que termine.
  async function reanudarLink() {
    const q = new URLSearchParams(location.search);
    if (!q.get("oauth_state_id")) return;
    const recibido = location.href;
    const guardado = leerLink();
    try { history.replaceState(null, "", location.pathname + location.hash); } catch { /* nada */ }
    if (!guardado || !guardado.token) { S.hooks.avisar("El banco volvió sin su ventana de Plaid: toca «Conectar un banco» otra vez.", true); return; }
    try { abrirLink(await cargarPlaidLink(), guardado.token, guardado.item_id, recibido); }
    catch (err) { S.hooks.avisar(err.message, true); }
  }

  // ============================================================
  // LOS COBROS EN LÍNEA (Stripe) — docs/conta/p1-stripe.sql y la función de
  // borde supabase/functions/stripe. La pantalla solo LEE las vistas
  // v_stripe_* (estado, control, facturas, pagos, depósitos y avisos); todo lo
  // que mueve algo se lo pide a la función con la sesión del dueño (y su código
  // del teléfono: la función exige aal2 en cada acción): crear o desactivar un
  // enlace, decir a qué va un pago, casar un depósito, revisar con Stripe.
  // Ninguna función de p1 está en la API. Nada de dinero ni enlaces se guarda
  // en el teléfono. La 1020 (cobros en tránsito) y la 1140 (de paso) son de
  // Stripe: no se concilian ni se eligen a mano, así que no salen en las listas
  // de bancos (la base no cambia: el control sigue contando la lista entera).
  // ============================================================
  const esStripe = cod => !!cod && !!(S.stripe && S.stripe.estado) && (cod === S.stripe.estado.cuenta_puente || cod === S.stripe.estado.cuenta_paso);
  const visibles = lista => (lista || []).filter(c => !esStripe(c.cuenta));
  // una vista que no existe (p1 sin pegar): PostgREST contesta 404 PGRST205 (o 42P01)
  const sinInstalar = err => !!err && (err.status === 404 || ["PGRST205", "42P01"].includes(err.codigo));
  const MEDIO = { tarjeta: "Tarjeta", ach: "Cuenta de banco (ACH)", otro: "Otro medio" };
  const cent = v => Math.round((num(v) || 0) * 100);
  const diasEntre = (a, b) => Math.round((Date.parse(String(a).slice(0, 10)) - Date.parse(String(b).slice(0, 10))) / 86400000);

  // El estado de la conexión (una fila). `fresco` vuelve a leer; un error que no es de red queda en S.stripeErr
  // («sin instalar») y la página sigue; sin señal, se lanza.
  async function leerStripe(fresco) {
    if (!fresco && (S.stripe || S.stripeErr)) return S.stripe;
    try {
      const filas = await DB._leer("v_stripe_estado?select=*");
      if (!Array.isArray(filas) || filas.length !== 1) throw new Error("la vista v_stripe_estado no devolvió su fila (¿falta stripe_config o la sesión no es la del dueño?)");
      S.stripe = { estado: filas[0] }; S.stripeErr = null;
    } catch (err) { if (esFalloDeRed(err)) throw err; S.stripe = null; S.stripeErr = err; }
    return S.stripe;
  }
  // La salud de la función: solo booleanos y el modo (nunca una llave). Si no contesta, null.
  async function leerSalud() {
    try { S.stripeSalud = await DB._funcion("stripe", { accion: "salud" }, 15000); }
    catch { S.stripeSalud = null; }
    return S.stripeSalud;
  }

  // ---------- La tarjeta de Bancos y tarjetas ----------
  function stripeHTML(st, err, salud) {
    const cab = extra => `<div class="ct-cab"><h2>Cobros en línea (Stripe)</h2>${extra}</div>`;
    if (!st || !st.estado) {
      return `<section class="ct-card ct-stripe" id="ct-stripe">${cab(pill("sin instalar", "warn"))}
        <p class="ct-nota">La base todavía no tiene los cobros en línea (docs/conta/p1-stripe.sql) o la vista no contestó: ${esc(err ? err.message : "sin datos")}.</p></section>`;
    }
    const e = st.estado;
    const faltan = !salud ? [] : [
      !salud.llave && "la llave (STRIPE_SECRET_KEY)", salud.llave && salud.llave_restringida === false && "una llave RESTRINGIDA (rk_live_…), no la secreta",
      !salud.webhook && "el secreto del webhook (STRIPE_WEBHOOK_SECRET)", !salud.rutina && "el secreto de la rutina (STRIPE_RUTINA_SECRETO)", !salud.base && "la conexión con la base"
    ].filter(Boolean);
    const prueba = e.modo === "prueba" || (salud && salud.modo === "prueba");
    const pills = (!salud ? pill("la función no contestó", "warn") : faltan.length ? pill("falta configurar", "bad") : pill("conectado", "ok")) +
      (prueba ? pill("modo de prueba", "warn") : "") +
      (Number(e.cuadres_rojos) > 0 ? pill("no cuadra", "bad") : pill("cuadra", "ok")) +
      (Number(e.alarmas) > 0 ? pill(plural(e.alarmas, "alarma", "alarmas"), "warn") : "");
    const mfa = mfaActivo();
    return `<section class="ct-card ct-stripe" id="ct-stripe">${cab(pills)}
      <p class="ct-nota">Tus clientes pagan la factura con un enlace: desde su cuenta de banco (ACH) o con tarjeta. Cada pago confirmado entra solo al libro en la ${esc(e.cuenta_puente || "1020")} (${esc(e.cuenta_puente_nombre || "Stripe — cobros en tránsito")}), y cuando Stripe deposita en Chase el depósito casa solo con su asiento. Las llaves viven en Supabase, nunca en el teléfono.</p>
      ${!salud ? `<p class="ct-aviso warn">La función «stripe» no contestó: ¿está desplegada en Supabase → Edge Functions?</p>` : faltan.length ? `<p class="ct-aviso bad">Falta en Supabase → Edge Functions → Secrets: ${esc(faltan.join(", "))}.</p>` : ""}
      ${prueba && !e.acepta_prueba ? `<p class="ct-aviso warn">La función tiene una llave de prueba (rk_test_): no se registra nada. Pon la llave real (rk_live_) en STRIPE_SECRET_KEY.</p>` : ""}
      <ul class="ct-datos">
        <li>En Stripe, sin depositar: <span class="ct-num">${fmt(e.por_depositar)}</span> (${plural(Number(e.n_por_depositar || 0), "cobro", "cobros")})</li>
        <li>En camino por cuenta de banco: <span class="ct-num">${fmt(e.en_camino_monto)}</span> (${Number(e.en_camino_n || 0)})</li>
        <li>Último aviso de Stripe: ${e.ultimo_evento_el ? `${fechaHora(e.ultimo_evento_el)} (${esc(e.ultimo_evento_tipo || "")})` : "ninguno todavía"}</li>
        <li>Revisión automática: ${e.ultimo_barrido_el ? fechaHora(e.ultimo_barrido_el) : "todavía no ha corrido"}</li>
        ${e.ultimo_error ? `<li class="bad-txt">Último error: ${esc(e.ultimo_error)}${e.ultimo_error_el ? ` (${fechaHora(e.ultimo_error_el)})` : ""}</li>` : ""}
      </ul>
      <div class="ct-acciones">
        <button type="button" class="accion" id="ct-stripe-ver">Ver los cobros en línea</button>
        <button type="button" class="accion secundaria" id="ct-stripe-probar"${mfa ? "" : " disabled"}>Probar la llave</button>
        <button type="button" class="accion secundaria" id="ct-stripe-barrer"${mfa ? "" : " disabled"}>Revisar con Stripe ahora</button>
        ${mfa ? "" : `<span class="ct-nota" style="margin:0">Primero activa el código del teléfono (arriba).</span>`}
      </div>
      <div class="ct-stripe-res"></div>
    </section>`;
  }
  function permisosHTML(r) {
    const ps = Array.isArray(r && r.permisos) ? r.permisos : [];
    const malos = ps.filter(x => !x.ok);
    return `<p class="ct-aviso ${malos.length ? "warn" : "ok"}">${malos.length ? `La llave${r.restringida === false ? " no es restringida y" : ""} no llega a ${plural(malos.length, "recurso", "recursos")}.` : `La llave contesta en todo lo que la app usa${r && r.modo ? ` (modo ${esc(r.modo === "real" ? "real" : "de prueba")})` : ""}.`}</p>
      <ul class="ct-permisos">${ps.map(x => `<li class="${x.ok ? "ok" : "bad"}"><span aria-hidden="true">${x.ok ? "✓" : "✗"}</span> ${esc(x.recurso)}${x.ok ? "" : ` — Falta el permiso <span class="ct-num">${esc(x.rak || "?")}</span> en la llave restringida: edítala en Stripe → Developers → API keys.`}</li>`).join("")}</ul>`;
  }
  function wireStripe() {
    const card = $("ct-stripe"); if (!card) return;
    const ver = $("ct-stripe-ver"); if (ver) ver.addEventListener("click", () => ir("cobros"));
    const pr = $("ct-stripe-probar"); if (pr) pr.addEventListener("click", () => accionStripe(card, { accion: "probar_llave" }, r => (r && Array.isArray(r.permisos) && r.permisos.some(x => !x.ok)) ? "A la llave le falta algún permiso: mira la lista" : "La llave de Stripe contesta bien", { repintar: false, mostrar: permisosHTML }));
    const ba = $("ct-stripe-barrer"); if (ba) ba.addEventListener("click", () => accionStripe(card, { accion: "barrer" }, resumenBarrido));
  }
  const resumenBarrido = r => `Revisado con Stripe${r && r.resumen && r.resumen.incompleto ? ": quedó a medias, sigue sola en la próxima vuelta" : ""}`;

  // ---------- Una acción de la función (con la sesión del dueño) ----------
  // `cont`: la tarjeta (sus botones se apagan; el resultado o el error va en su .ct-stripe-res).
  // Después repinta la página en la que está (salvo repintar: false, que enseña el resultado con `mostrar`).
  const resStripe = cont => { let c = cont.querySelector(".ct-stripe-res"); if (!c) { c = document.createElement("div"); c.className = "ct-stripe-res"; cont.appendChild(c); } return c; };
  function errorStripeHTML(err, cuerpo) {
    if (esFalloDeRed(err) || !navigator.onLine) return `<p class="ct-aviso bad">Sin señal: no se hizo nada.</p>`;
    const d = err.datos || {};
    const rak = d.rak || (d.detalle && d.detalle.rak) || (String(err.message || "").match(/rak_[a-z_]+/) || [])[0] || "";
    if (err.codigo === "MFA") return `<p class="ct-aviso warn">Falta el código del teléfono: entra otra vez con él.</p>`;
    if (err.codigo === "STRIPE_PERMISO") return `<p class="ct-aviso bad">A la llave de Stripe le falta el permiso <span class="ct-num">${esc(rak || "?")}</span>. Añádelo en Stripe → Developers → API keys (la llave restringida) y vuelve a intentarlo.</p>`;
    if (err.codigo === "STRIPE_CAIDO") return `<p class="ct-aviso warn">${esc(cuerpo && cuerpo.accion === "crear_enlace" && err.message ? err.message : "Stripe no contestó: no se hizo nada. Inténtalo en un rato.")}</p>`;
    if (/^MX/i.test(String(err.codigo || "")) || err.estado === 409) return `<p class="ct-aviso warn">${esc(err.message)}</p>`;
    return `<p class="ct-aviso bad">${esc(err.message)}</p>`;
  }
  async function accionStripe(cont, cuerpo, exito, opciones = {}) {
    if (S.ocupado) return;
    const caja = resStripe(cont);
    if (!navigator.onLine) { caja.innerHTML = `<p class="ct-aviso bad">Sin señal: no se hizo nada.</p>`; return; }
    if (!mfaActivo()) { caja.innerHTML = `<p class="ct-aviso warn">Primero activa el código del teléfono (Bancos y tarjetas) y entra con él: los cobros en línea lo piden.</p>`; return; }
    S.ocupado = true;
    const apagados = [...cont.querySelectorAll("button, select, input, textarea")].filter(b => !b.disabled && !b.readOnly);
    apagados.forEach(b => { b.disabled = true; });
    caja.innerHTML = `<p class="ct-aviso">${cuerpo.accion === "barrer" ? "Revisando con Stripe…" : cuerpo.accion === "crear_enlace" ? "Creando el enlace en Stripe…" : "Un momento…"}</p>`;
    let r;
    try {
      r = await DB._funcion("stripe", cuerpo, 60000);
    } catch (err) {
      apagados.forEach(b => { b.disabled = false; });
      caja.innerHTML = errorStripeHTML(err, cuerpo);
      S.ocupado = false;
      if (typeof opciones.alFallar === "function") opciones.alFallar(err);
      return;
    }
    S.ocupado = false;
    S.hooks.avisar(exito(r));
    if (opciones.repintar === false) {
      apagados.forEach(b => { b.disabled = false; });
      caja.innerHTML = typeof opciones.mostrar === "function" ? opciones.mostrar(r) : "";
      return;
    }
    S.cobros = null; S.stripe = null; S.stripeErr = null; S.stripeSalud = null; S.saldos = null; S.bandeja = null;
    await (PAGINAS[S.pagina] || pintarCobros)();
  }

  // ---------- La bandeja: un depósito de Stripe no se registra como cobro ----------
  const depositoStripe = m => !!(S.stripe && S.stripe.estado) && num(m.monto) > 0 && /\bSTRIPE\b/i.test(`${m.descripcion || ""} ${m.memo || ""}`) &&
    String(m.fecha || "") >= String(S.stripe.estado.desde || "").slice(0, 10);
  const opcionDeCobro = o => !!o && (o.llamar === "fn_banco_cobrar" || (o.llamar === "fn_banco_casar_con" && !!(o.args && o.args.p_con && o.args.p_con.cobro)));
  // Deja en m.opciones la misma lista que pinta y que usa el clic: sin las que nombran la 1020 o la 1140, y en un depósito
  // de Stripe sin las de cobro; m._stripe = los depósitos de Stripe asentados con ese monto y su llegada a ±5 días.
  function prepararMov(m) {
    const dep = depositoStripe(m);
    m.opciones = (Array.isArray(m.opciones) ? m.opciones : []).filter(o => !(o && o.args && esStripe(o.args.p_cuenta)) && !(dep && opcionDeCobro(o)));
    m._esStripe = dep;
    m._stripe = dep ? (S.stripePayouts || []).filter(q => cent(q.monto) === cent(m.monto) && Math.abs(diasEntre(q.llegada, m.fecha)) <= 5) : [];
    return m;
  }

  // ---------- La pestaña «Cobros en línea» ----------
  // FALLA RUIDOSA: v_stripe_control. Un «cuadre» en false, o una vista que trajo otro número de filas que el que contó el
  // control (10, 11 y 12), es rojo y no se pinta nada. Las «alarmas» en false van en la caja amarilla de arriba.
  function controlStripe(control, conteos) {
    if (!Array.isArray(control) || !control.length) throw errorControl("El control de los cobros en línea no devolvió ninguna fila", [{ vista: "v_stripe_control", detalle: "la vista contestó vacía" }]);
    const mal = control.filter(f => f.nivel === "cuadre" && f.ok !== true).map(f => ({ vista: f.control, filas: f.filas, esperadas: f.esperadas, detalle: f.detalle }));
    for (const [vista, n] of Object.entries(conteos)) {
      const f = control.find(x => x.control === "vista: " + vista);
      if (!f) mal.push({ vista, detalle: "el control no revisó esta vista" });
      else if (f.ok === true && Number(f.filas) !== Number(n)) mal.push({ vista, filas: f.filas, esperadas: n, detalle: `la pantalla trajo ${n} fila(s) y el control contó ${f.filas}` });
    }
    if (mal.length) throw errorControl("Los cobros en línea no cuadran: no se pinta", mal);
    return control.filter(f => f.nivel === "alarma" && f.ok === false);
  }
  async function pintarCobros() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarCobros);
    let est, control, facturas, pagos, payouts, avisos, alarmas;
    try {
      [est, control, facturas, pagos, payouts, avisos] = await Promise.all([
        DB._leer("v_stripe_estado?select=*"),
        DB._leer("v_stripe_control?select=*&order=orden.asc"),
        DB._leer("v_stripe_facturas?select=*&order=fecha.asc,num.asc"),
        DB._leer("v_stripe_pagos?select=*&order=creado_el.desc"),
        DB._leer("v_stripe_payouts?select=*&order=llegada.desc"),
        DB._leer("v_stripe_avisos?select=*"),
        leerMfa(),
        // para las formas de «Decir a qué va» y «A qué cuenta va»; si no llegan, la forma lo dice
        proyectos().catch(e => { if (esFalloDeRed(e)) throw e; return null; }),
        cuentas().catch(e => { if (esFalloDeRed(e)) throw e; return null; }),
        saldos().catch(e => { if (esFalloDeRed(e)) throw e; return null; })
      ]);
      if (S.pagina !== "cobros") return;
      if (!Array.isArray(est) || est.length !== 1) throw errorControl("Los cobros en línea no devolvieron su estado", [{ vista: "v_stripe_estado", filas: Array.isArray(est) ? est.length : 0, esperadas: 1, detalle: "la fila de stripe_config no se ve (¿la sesión no es la del dueño?)" }]);
      alarmas = controlStripe(control, { v_stripe_facturas: facturas.length, v_stripe_pagos: pagos.length, v_stripe_payouts: payouts.length });
    } catch (err) {
      if (S.pagina !== "cobros") return;
      if (sinInstalar(err) && !esFalloDeRed(err)) {
        main().innerHTML = `<section class="ct-card ct-stripe" id="ct-cobros-sin"><div class="ct-cab"><h2>Cobros en línea (Stripe)</h2>${pill("sin instalar", "warn")}</div>
          <p class="ct-nota">Los cobros en línea no están instalados (docs/conta/p1-stripe.sql). Cuando se peguen en el SQL Editor, aquí salen las facturas por cobrar, los pagos y los depósitos de Stripe.</p></section>`;
        return;
      }
      return pintarError(err, pintarCobros);
    }
    S.stripe = { estado: est[0] }; S.stripeErr = null;
    S.cobros = { estado: est[0], facturas, pagos, payouts, avisos: avisos || [] };
    const e = est[0], mfa = mfaActivo();
    const porCobrar = facturas.filter(f => num(f.saldo_cxc) + num(f.saldo_retencion) > 0).length;
    const enCamino = pagos.filter(x => ["iniciado", "en_camino"].includes(x.estado)).length;
    const aChase = payouts.filter(x => ["en_camino", "asentado"].includes(x.estado_pantalla)).length;
    const sinMfa = mfa ? "" : `<p class="ct-aviso warn">Primero activa el código del teléfono (Bancos y tarjetas) y entra con él: crear enlaces y todo lo que habla con Stripe lo pide.</p>`;
    main().innerHTML = `<section class="ct-card ct-barra" id="ct-cobros-barra">
        <div class="ct-barra-txt"><b>${plural(porCobrar, "factura por cobrar", "facturas por cobrar")}</b> · ${plural(enCamino, "pago en camino", "pagos en camino")} · ${plural(aChase, "depósito esperando a Chase", "depósitos esperando a Chase")}</div>
        ${e.modo === "prueba" && !e.acepta_prueba ? `<p class="ct-aviso warn">La función tiene una llave de prueba (rk_test_): no se registra nada.</p>` : ""}
        ${sinMfa}
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-cobros-barrer"${mfa ? "" : " disabled"}>Revisar con Stripe ahora</button></div>
        <div class="ct-stripe-res"></div>
      </section>
      ${alarmas.length ? `<section class="ct-card ct-alarmas" id="ct-cobros-alarmas" role="status"><h2>Hay que mirar esto:</h2><ul class="ct-datos">${alarmas.map(a => `<li><b>${esc(String(a.control || "").replace(/^stripe: /, ""))}</b>${a.filas != null ? ` (${esc(a.filas)})` : ""}${a.detalle ? `: ${esc(a.detalle)}` : ""}</li>`).join("")}</ul></section>` : ""}
      ${(avisos || []).length ? `<section class="ct-card" id="ct-cobros-avisos"><h2>Avisos de Stripe</h2><ul class="ct-avisos-stripe">${avisos.map(avisoHTML).join("")}</ul></section>` : ""}
      <section class="ct-card" id="ct-cobros-facturas"><h2>Facturas por cobrar</h2>
        <p class="ct-nota">El saldo sale del libro (lo que la factura debe), no de la casilla «pagada». El enlace es de un solo uso y por ese saldo: el cliente elige cuenta de banco (ACH) o tarjeta.</p>
        ${facturas.length ? `<div class="ct-lista">${facturas.map(f => facturaCobroHTML(f, mfa)).join("")}</div>` : `<p class="ct-vacio">No hay facturas con saldo en el libro.</p>`}
      </section>
      <section class="ct-card" id="ct-cobros-pagos"><h2>Pagos en línea</h2>
        ${pagos.length ? `<div class="ct-lista">${pagos.map(x => pagoHTML(x, mfa)).join("")}</div>` : `<p class="ct-vacio">Todavía no hay pagos en línea.</p>`}
      </section>
      <section class="ct-card" id="ct-cobros-payouts"><h2>Depósitos de Stripe en Chase</h2>
        <p class="ct-nota">Stripe junta los cobros, descuenta sus comisiones y deposita el neto en Chase. Cada depósito deja dos asientos (sale de Stripe, llega a Chase) y casa solo con el movimiento «STRIPE» que trae Plaid.</p>
        ${payouts.length ? `<div class="ct-lista">${payouts.map(x => payoutHTML(x, mfa)).join("")}</div>` : `<p class="ct-vacio">Todavía no hay depósitos de Stripe.</p>`}
      </section>
      <p class="ct-nota ct-cobros-pie">La casilla «pagada» y QuickBooks los sigues llevando tú durante el paralelo: esta pantalla no los toca.</p>`;
    wireCobros();
  }

  function avisoHTML(a) {
    return `<li class="ct-aviso-stripe ${esc(a.nivel)}" data-aviso="${esc(a.id)}">
      <div class="ct-aviso-txt"><span>${esc(a.texto)}</span><small>${fechaHora(a.creado_el)}${Number(a.veces) > 1 ? ` · ${esc(a.veces)} veces, la última ${fechaHora(a.repetido_el)}` : ""}</small></div>
      <button type="button" class="accion secundaria chica" data-visto>Entendido</button></li>`;
  }

  function facturaCobroHTML(f, mfa) {
    const debe = num(f.saldo_cxc), ret = num(f.saldo_retencion);
    const activo = f.enlace_estado === "activo" && f.enlace_url;
    const creando = f.enlace_estado === "creando";
    const titulo = ["#" + (f.num || f.factura_id), f.obra, f.cliente].filter(Boolean).map(esc).join(" · ");
    let cuerpo;
    if (activo) {
      cuerpo = `<p class="ct-nota">Enlace por <span class="ct-num">${fmt(f.enlace_monto)}</span>${f.enlace_con_retencion ? " (con la retención)" : ""} · creado el ${fechaHora(f.enlace_creado_el)}</p>
        <div class="ct-enlace"><input class="ct-enlace-url" type="text" readonly value="${esc(f.enlace_url)}" aria-label="Enlace de pago de la factura ${esc(f.num || f.factura_id)}">
          <div class="ct-acciones"><button type="button" class="accion chica" data-copiar>Copiar</button>${typeof navigator.share === "function" ? `<button type="button" class="accion secundaria chica" data-enviar>Enviar</button>` : ""}<button type="button" class="accion secundaria chica" data-desactivar${mfa ? "" : " disabled"}>Desactivar</button></div></div>
        ${f.enlace_desfasado ? `<p class="ct-aviso warn">El enlace es por ${fmt(f.enlace_monto)} y la factura ahora debe ${fmt(debe + (f.enlace_con_retencion ? ret : 0))}: crea otro (el de ahora se desactiva).</p>
          <div class="ct-acciones"><button type="button" class="accion secundaria" data-crear="reemplazar"${mfa ? "" : " disabled"}>Crear otro enlace (desactiva el de ahora)</button></div>` : ""}`;
    } else if (creando) {
      cuerpo = `<p class="ct-aviso warn">El enlace se está creando en Stripe (desde el ${fechaHora(f.enlace_creado_el)}): si Stripe no contestó, se termina solo cuando vuelva.</p>
        <div class="ct-acciones"><button type="button" class="accion secundaria" data-crear${mfa ? "" : " disabled"}>Crear enlace de pago</button></div>`;
    } else if (Number(f.en_camino_n) > 0) {
      cuerpo = `<p class="ct-nota">Hay un pago por cuenta de banco de <span class="ct-num">${fmt(f.en_camino_monto)}</span> en camino: no se crea otro enlace hasta que se confirme o falle.</p>`;
    } else if (f.puede_enlace) {
      cuerpo = `<div class="ct-acciones"><button type="button" class="accion" data-crear${mfa ? "" : " disabled"}>Crear enlace de pago</button>${mfa ? "" : `<span class="ct-nota" style="margin:0">Primero activa el código del teléfono (Bancos y tarjetas).</span>`}</div>`;
    } else {
      cuerpo = `<p class="ct-nota">No se crea enlace: ${esc(f.por_que_no || "la base no lo permite")}.</p>`;
    }
    return `<article class="ct-cobro ct-factura" data-factura="${esc(f.factura_id)}">
      <div class="ct-cab"><h3>${titulo}</h3>${activo ? pill("enlace activo", "ok") : ""}${creando ? pill("creando el enlace", "warn") : ""}${Number(f.en_camino_n) > 0 ? pill("pago en camino", "cu") : ""}${f.pagada ? pill("pagada en la app", "warn") : ""}</div>
      <p class="ct-cobro-debe">Debe <span class="ct-num">${fmt(debe)}</span>${ret > 0 ? ` · retención <span class="ct-num">${fmt(ret)}</span>` : ""}${f.monto_factura != null ? ` <small>de una factura por ${fmt(f.monto_factura)}</small>` : ""}</p>
      ${cuerpo}
      <div class="ct-form" hidden></div>
      <div class="ct-stripe-res"></div>
    </article>`;
  }

  const ESTADO_PAGO = {
    iniciado: ["verificando la cuenta", "warn", () => "El cliente eligió pagar desde su banco y falta verificar la cuenta (hasta 10 días)."],
    en_camino: ["en camino", "cu", () => "El banco tarda unos 4 días hábiles. No entra al libro hasta que se confirme."],
    cobrado: ["cobrado", "ok", x => `En el libro${x.cobro_asiento ? ` (asiento ${x.cobro_asiento})` : ""}. Falta que Stripe lo deposite en Chase.`],
    en_payout: ["en el depósito de Stripe", "ok", x => `En el libro${x.cobro_asiento ? ` (asiento ${x.cobro_asiento})` : ""}. Stripe ya lo metió en un depósito: falta que llegue a Chase.`],
    depositado: ["depositado", "ok", x => `Llegó a Chase con el depósito del ${fechaLarga(x.deposito_fecha)}.`],
    devuelto: ["devuelto", "bad", () => "Se devolvió entero en Stripe (reembolso o disputa perdida): el cobro se devolvió en el libro y la factura vuelve a deber."],
    en_disputa: ["en disputa", "bad", x => `Stripe retiró el dinero y el cobro se devolvió en el libro. Responde en Stripe antes del ${fechaLarga(x.disputa_vence)}.${x.medio === "ach" ? " Las disputas por cuenta de banco no se pueden impugnar." : ""}`],
    fallido: ["falló", "bad", x => `${x.fallo || "El pago no se completó"}: no entró nada al libro.`],
    revisar: ["por resolver", "bad", x => `${x.revisar || "No se sabe a qué factura va"}. Hasta que digas a qué va, el depósito que lo lleva espera.`]
  };
  function pagoHTML(x, mfa) {
    const ep = ESTADO_PAGO[x.estado_pantalla] || [x.estado_pantalla || x.estado, ""];
    const texto = typeof ep[2] === "function" ? ep[2](x) : "";
    const pos = Array.isArray(x.payouts) ? x.payouts : [];
    return `<article class="ct-cobro ct-pago ${esc(x.estado_pantalla || "")}" data-pi="${esc(x.pi)}">
      <div class="ct-cab"><h3>${x.factura_num ? "#" + esc(x.factura_num) : "Sin factura"} · <span class="ct-num">${fmt(x.monto)}</span> · ${esc(MEDIO[x.medio] || x.medio || "")}</h3>${pill(ep[0], ep[1])}${num(x.reembolsado) > 0 && x.estado_pantalla !== "devuelto" ? pill("devuelto " + fmt(x.reembolsado), "warn") : ""}</div>
      ${texto ? `<p class="ct-nota">${esc(texto)}</p>` : ""}
      <ul class="ct-datos">
        ${x.obra ? `<li>Obra: ${esc(x.obra)}</li>` : ""}
        ${num(x.en_libro) !== num(x.monto) && !["iniciado", "en_camino", "fallido", "devuelto"].includes(x.estado_pantalla) ? `<li>En el libro: <span class="ct-num">${fmt(x.en_libro)}</span></li>` : ""}
        ${num(x.falta_depositar) !== 0 ? `<li>Falta depositar: <span class="ct-num">${fmt(x.falta_depositar)}</span></li>` : ""}
        ${pos.length ? `<li>Depósito${pos.length > 1 ? "s" : ""}: <span class="ct-num">${pos.map(esc).join(", ")}</span></li>` : ""}
        <li>${x.cobrado_el ? `Cobrado el ${fechaLarga(x.cobrado_el)} · ` : ""}hace ${plural(Number(x.dias || 0), "día", "días")} · <span class="ct-num ct-pi">${esc(x.pi)}</span></li>
      </ul>
      <div class="ct-acciones">
        ${x.estado === "revisar" ? `<button type="button" class="accion" data-resolver${mfa ? "" : " disabled"}>Decir a qué va</button>` : ""}
        ${x.estado_pantalla !== "depositado" ? `<button type="button" class="accion secundaria chica" data-mirar${mfa ? "" : " disabled"}>Volver a mirar en Stripe</button>` : ""}
      </div>
      <div class="ct-form" hidden></div>
      <div class="ct-stripe-res"></div>
    </article>`;
  }

  const ESTADO_PAYOUT = {
    en_camino: ["en camino a Chase", "cu"], esperando_composicion: ["esperando el detalle de Stripe", "warn"], esperando_cobros: ["espera: falta un cobro", "bad"],
    asentado: ["en el libro; falta que llegue a Chase", "warn"], casado: ["casado con Chase", "ok"], fallido: ["no llegó (falló)", "bad"], revisar: ["por revisar", "bad"]
  };
  const CLASE_LINEA = { pago: "cobro", vuelve: "vuelve de un depósito fallido", comision: "comisión", otro: "otro", propio: "el depósito" };
  function payoutHTML(x, mfa) {
    const ep = ESTADO_PAYOUT[x.estado_pantalla] || [x.estado_pantalla || x.estado, ""];
    const lineas = Array.isArray(x.lineas) ? x.lineas : [];
    const esperando = Array.isArray(x.esperando) ? x.esperando : [];
    const candidatos = Array.isArray(x.candidatos) ? x.candidatos : [];
    const sinCuenta = x.estado !== "asentado" ? lineas.filter(l => l.clase === "otro" && !l.cuenta) : [];
    const asientos = [x.asiento_salida_num && `${esc(x.asiento_salida_num)} (sale de Stripe)`, x.asiento_llegada_num && `${esc(x.asiento_llegada_num)} (llega a Chase)`, x.asiento_vuelta_num && `${esc(x.asiento_vuelta_num)} (vuelve a Stripe)`].filter(Boolean);
    const mirar = ["en_camino", "esperando_composicion", "esperando_cobros", "revisar"].includes(x.estado);
    const dis = mfa ? "" : " disabled";
    return `<article class="ct-cobro ct-payout ${esc(x.estado_pantalla || "")}" data-po="${esc(x.po)}">
      <div class="ct-cab"><h3>${fechaLarga(x.llegada)} · neto <span class="ct-num">${fmt(x.monto)}</span></h3>${pill(ep[0], ep[1])}${x.reversado ? pill("reversado a mano", "bad") : ""}</div>
      ${x.bruto != null ? `<p class="ct-nota">${plural(Number(x.n_pagos || 0), "cobro", "cobros")} por <span class="ct-num">${fmt(x.bruto)}</span> − comisiones <span class="ct-num">${fmt(x.comisiones)}</span> = <span class="ct-num">${fmt(x.monto)}</span></p>` : `<p class="ct-nota">Stripe todavía no dio el detalle de este depósito.</p>`}
      ${asientos.length ? `<p class="ct-nota">Asientos ${asientos.join(" y ")}</p>` : ""}
      ${x.estado_pantalla === "casado" ? `<p class="ct-aviso ok">Casó con «${esc(x.movimiento_descripcion || "")}» del ${fechaLarga(x.movimiento_fecha)} · ${x.casado_automatico ? "casó solo" : `casó: ${esc(x.casado_regla || "a mano")}`}</p>` : ""}
      ${x.estado_pantalla === "asentado" ? `<p class="ct-nota">${x.dias_sin_casar != null && Number(x.dias_sin_casar) > 0 ? `Lleva ${plural(Number(x.dias_sin_casar), "día", "días")} sin casar. ` : ""}${candidatos.length ? "Chase ya trajo un depósito que puede ser este:" : "Cuando Plaid traiga el depósito «STRIPE» de Chase, casa solo."}</p>` : ""}
      ${x.revisar ? `<p class="ct-aviso bad">${esc(x.revisar)}</p>` : ""}
      ${esperando.length ? `<ul class="ct-datos ct-esperando">${esperando.map(w => `<li>${w.pi ? `Cobro <span class="ct-num">${esc(w.pi)}</span>` : w.po ? `Depósito <span class="ct-num">${esc(w.po)}</span>` : w.txn ? `${esc(w.tipo || "movimiento")} <span class="ct-num">${fmt(w.monto)}</span>` : "Algo"}: ${esc(w.motivo || "")}</li>`).join("")}</ul>` : ""}
      ${x.estado === "fallido" ? `<p class="ct-nota">Stripe devolvió el dinero a tu saldo y lo manda con el siguiente depósito: revisa la cuenta de banco en Stripe.</p>` : ""}
      <div class="ct-acciones">
        ${candidatos.map(c => `<button type="button" class="accion" data-casar="${esc(c.id)}"${dis}>Casar con el depósito de Chase del ${fechaLarga(c.fecha)}</button>`).join("")}
        ${sinCuenta.map(l => `<button type="button" class="accion" data-linea="${esc(l.txn)}"${dis}>A qué cuenta va: ${esc(l.tipo)} ${fmt(l.monto)}</button>`).join("")}
        ${x.reversado ? `<button type="button" class="accion secundaria" data-rehacer${dis}>Volver a ponerlo</button>` : ""}
        ${mirar ? `<button type="button" class="accion secundaria chica" data-mirar${dis}>Volver a mirar en Stripe</button>` : ""}
      </div>
      ${lineas.length ? `<details class="ct-payout-det"><summary>El detalle de Stripe (${plural(lineas.length, "línea", "líneas")})</summary>
        <ul class="ct-payout-lineas">${lineas.map(l => `<li><span class="ct-pl-que">${esc(CLASE_LINEA[l.clase] || l.clase)}${l.factura_num ? ` · #${esc(l.factura_num)}` : ""}${l.cuenta ? ` · a ${esc(l.cuenta)}` : ""}<small class="ct-num">${esc(l.tipo)} · ${esc(l.txn)}</small></span><span class="ct-pl-m ct-num">${fmt(l.monto)}${num(l.comision) ? `<small>comisión ${fmt(l.comision)}</small>` : ""}</span></li>`).join("")}</ul></details>` : ""}
      <div class="ct-form" hidden></div>
      <div class="ct-stripe-res"></div>
    </article>`;
  }

  // las cuentas a las que puede ir dinero de Stripe «de fuera» o un movimiento que la app no conoce
  // (la base lo vuelve a comprobar con fn_stripe_cuenta_libre): ingreso, gasto, costo u otro, o pasivo; nunca banco, tarjeta, ni las de Stripe
  const cuentasLibres = () => (S.cuentas || []).filter(c => ["ingreso", "otro_ingreso", "gasto", "otro_gasto", "costo", "pasivo"].includes(c.tipo) && c.regla_obra !== "obligatoria" &&
    !esStripe(c.codigo) && !(S.saldos || []).some(s => s.cuenta === c.codigo));
  const opcionesCuentas = () => cuentasLibres().map(c => `<option value="${esc(c.codigo)}">${esc(c.codigo)} · ${esc(c.nombre)}</option>`).join("");

  function wireCobros() {
    const m = main();
    const barra = $("ct-cobros-barra");
    const ba = $("ct-cobros-barrer"); if (ba) ba.addEventListener("click", () => accionStripe(barra, { accion: "barrer" }, resumenBarrido));
    m.querySelectorAll(".ct-aviso-stripe").forEach(li => {
      li.querySelector("[data-visto]").addEventListener("click", () => accionStripe(li, { accion: "aviso_visto", aviso: Number(li.dataset.aviso) }, () => "Aviso visto"));
    });
    m.querySelectorAll(".ct-factura").forEach(card => {
      const f = S.cobros.facturas.find(x => String(x.factura_id) === card.dataset.factura); if (!f) return;
      card.querySelectorAll("[data-crear]").forEach(b => b.addEventListener("click", () => formaEnlace(card, f, b.dataset.crear === "reemplazar", false)));
      const cp = card.querySelector("[data-copiar]"); if (cp) cp.addEventListener("click", () => copiarEnlace(card));
      const en = card.querySelector("[data-enviar]"); if (en) en.addEventListener("click", () => {
        navigator.share({ title: `Factura ${f.num || f.factura_id} · Max Power Electrical Solutions`, text: `Enlace de pago de la factura ${f.num || f.factura_id}`, url: f.enlace_url }).catch(() => { /* lo cerró */ });
      });
      const de = card.querySelector("[data-desactivar]"); if (de) de.addEventListener("click", () => montarForma(card,
        formaHTML(`Desactivar el enlace de la #${esc(f.num || f.factura_id)}: quien lo abra verá que ya no está activo (queda escrito por qué)`, campoHTML("motivo", "Motivo", "textarea", "required"), "Desactivar"),
        v => accionStripe(card, { accion: "desactivar_enlace", enlace: f.enlace_id, motivo: v.motivo }, () => `Enlace de la #${f.num || f.factura_id} desactivado`)));
    });
    m.querySelectorAll(".ct-pago").forEach(card => {
      const x = S.cobros.pagos.find(y => y.pi === card.dataset.pi); if (!x) return;
      const re = card.querySelector("[data-resolver]"); if (re) re.addEventListener("click", () => formaResolver(card, x));
      const mi = card.querySelector("[data-mirar]"); if (mi) mi.addEventListener("click", () => accionStripe(card, { accion: "reprocesar", pi: x.pi }, () => "Vuelto a mirar en Stripe"));
    });
    m.querySelectorAll(".ct-payout").forEach(card => {
      const x = S.cobros.payouts.find(y => y.po === card.dataset.po); if (!x) return;
      card.querySelectorAll("[data-casar]").forEach(b => b.addEventListener("click", () => accionStripe(card, { accion: "casar_payout", po: x.po, movimiento_id: b.dataset.casar }, r => r && r.casado === false ? "No casó: mira la bandeja" : `Depósito ${x.po} casado con Chase`)));
      card.querySelectorAll("[data-linea]").forEach(b => b.addEventListener("click", () => {
        const l = (x.lineas || []).find(y => y.txn === b.dataset.linea) || { txn: b.dataset.linea };
        const ops = opcionesCuentas();
        montarForma(card, formaHTML(`¿A qué cuenta va ${esc(l.tipo || "este movimiento")} de ${fmt(l.monto)} (${esc(l.txn)})? Stripe lo trae en el depósito y la app no lo conoce.`,
          `<label class="ct-campo">Cuenta<select name="cuenta" required><option value="">Elige la cuenta…</option>${ops}</select></label>${campoHTML("motivo", "Motivo (queda escrito)", "textarea", "required")}`, "Guardar"),
          v => accionStripe(card, { accion: "resolver_linea", po: x.po, txn: l.txn, cuenta: v.cuenta, motivo: v.motivo }, () => `Va a ${v.cuenta}: el depósito se vuelve a mirar`));
      }));
      const rh = card.querySelector("[data-rehacer]"); if (rh) rh.addEventListener("click", () => accionStripe(card, { accion: "reprocesar", po: x.po, rehacer: true }, () => `Depósito ${x.po} puesto otra vez en el libro`));
      const mi = card.querySelector("[data-mirar]"); if (mi) mi.addEventListener("click", () => accionStripe(card, { accion: "reprocesar", po: x.po }, () => "Vuelto a mirar en Stripe"));
    });
  }

  // «Crear enlace de pago»: por el saldo del LIBRO (la función lo calcula; aquí nunca va un monto)
  function formaEnlace(card, f, reemplazar, forzarPagada) {
    const ret = num(f.saldo_retencion), debe = num(f.saldo_cxc);
    const pidePagada = !!f.pagada || forzarPagada;
    const campos = (ret > 0 ? `<label class="ct-casilla"><input type="checkbox" name="con_retencion" value="si"> Incluir la retención (${fmt(ret)})</label>` : "") +
      (pidePagada ? `<p class="ct-aviso warn">La casilla «pagada» dice que la #${esc(f.num || f.factura_id)} está pagada (QuickBooks), pero el libro dice que debe ${fmt(debe)}. Si el cliente ya pagó por otro lado, no mandes el enlace.</p>
        <label class="ct-casilla"><input type="checkbox" name="aunque_pagada" value="si" required data-falta="Falta confirmar que el cliente todavía la debe."> Sí: el cliente todavía la debe</label>` : "");
    montarForma(card, formaHTML(`Enlace de pago de la #${esc(f.num || f.factura_id)} por ${fmt(debe)} (un solo uso; el cliente elige cuenta de banco o tarjeta)${reemplazar ? ". El enlace de ahora se desactiva." : ""}`, campos, "Crear el enlace"), v => {
      const cuerpo = { accion: "crear_enlace", factura_id: Number(f.factura_id), con_retencion: v.con_retencion === "si" };
      if (v.aunque_pagada === "si") cuerpo.aunque_pagada = true;
      if (reemplazar) cuerpo.reemplazar = true;
      accionStripe(card, cuerpo, r => r && r.nuevo === false ? `La #${f.num || f.factura_id} ya tenía su enlace: es el mismo` : "Enlace creado: cópialo y mándaselo al cliente.", {
        // la base dice que la casilla «pagada» está marcada (la vista era vieja): se enseña la casilla de confirmar
        alFallar: err => { if (err && err.datos && err.datos.pista === "pagada_en_app" && !pidePagada) formaEnlace(card, f, reemplazar, true); }
      });
    });
  }

  // Copiar el enlace: el portapapeles del navegador; si no deja, seleccionar y copiar a la antigua
  async function copiarEnlace(card) {
    const inp = card.querySelector(".ct-enlace-url"); if (!inp) return;
    let bien = false;
    try { if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") { await navigator.clipboard.writeText(inp.value); bien = true; } } catch { /* respaldo */ }
    if (!bien) { try { inp.focus(); inp.select(); inp.setSelectionRange(0, inp.value.length); bien = document.execCommand("copy"); } catch { bien = false; } }
    if (bien) S.hooks.avisar("Enlace copiado: pégalo en el mensaje al cliente.");
    else { inp.focus(); inp.select(); S.hooks.avisar("No se pudo copiar solo: el enlace quedó seleccionado, cópialo tú.", true); }
  }

  // «Decir a qué va» un pago que no salió de un enlace de la app (o que su factura no aceptó)
  function formaResolver(card, x) {
    const facts = (S.cobros.facturas || []).filter(f => f.en_libro !== false);
    const obras = S.proyectos || [];
    const ops = opcionesCuentas();
    montarForma(card, formaHTML(`¿A qué va el pago ${esc(x.pi)} de ${fmt(x.monto)}? Queda escrito con tu motivo.`,
      `<label class="ct-campo">¿A qué va?<select name="que" required><option value="">Elige…</option><option value="factura">A la factura…</option><option value="obra">Anticipo de la obra…</option><option value="fuera">Es de antes de la app o ya está en el libro</option></select></label>
       <label class="ct-campo" data-si="factura" hidden>Factura<select name="factura_id"><option value="">Elige la factura…</option>${facts.map(f => `<option value="${esc(f.factura_id)}">#${esc(f.num || f.factura_id)}${f.obra ? ` · ${esc(f.obra)}` : ""} · debe ${fmt(num(f.saldo_cxc) + num(f.saldo_retencion))}</option>`).join("")}</select></label>
       <label class="ct-campo" data-si="obra" hidden>Obra<select name="proyecto_id"><option value="">Elige la obra…</option>${obras.map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("")}</select></label>
       <label class="ct-campo" data-si="fuera" hidden>Cuenta (ingreso, gasto, costo o pasivo)<select name="cuenta"><option value="">Elige la cuenta…</option>${ops}</select></label>
       ${campoHTML("motivo", "Motivo (queda escrito)", "textarea", "required")}`, "Guardar"), v => {
      const falta = { factura: ["factura_id", "la factura"], obra: ["proyecto_id", "la obra"], fuera: ["cuenta", "la cuenta"] }[v.que];
      if (falta && !v[falta[0]]) { mostrarErrorForma(card, `Falta ${falta[1]}.`); return; }
      const cuerpo = { accion: "resolver_pago", pi: x.pi, motivo: v.motivo };
      if (v.que === "factura") cuerpo.factura_id = Number(v.factura_id);
      else if (v.que === "obra") cuerpo.proyecto_id = v.proyecto_id;
      else cuerpo.fuera = { cuenta: v.cuenta };
      accionStripe(card, cuerpo, () => "Pago resuelto: entra al libro y su depósito se vuelve a mirar");
    });
    const f = card.querySelector(".ct-form");
    const sel = f.querySelector('select[name="que"]');
    sel.addEventListener("change", () => f.querySelectorAll("[data-si]").forEach(l => { l.hidden = l.dataset.si !== sel.value; }));
  }

  // ============================================================
  // LA BANDEJA
  // ============================================================
  const MOTIVOS = {
    sin_ticket: "Sin ticket", sin_propuesta: "Sin propuesta todavía", partida_apertura: "¿Partida del 30-sep?",
    interes_tarjeta: "Intereses de la tarjeta", cargo_banco: "Cargo del banco", intereses_banco: "Intereses del banco",
    posible_duplicado: "¿Duplicado?", quitada: "El banco la quitó", llego_su_ticket: "Llegó su ticket",
    cuota_prestamo: "Cuota de un préstamo", transferencia: "Entre cuentas propias", cobro: "Cobro de un cliente",
    deposito: "Depósito", nomina: "Nómina", retiro_cajero: "Retiro de cajero", dinero_de_edgar: "Dinero de Edgar",
    pago_proveedor: "Pago a un proveedor", dudosa: "Dudosa", cheque: "Cheque", devolucion: "Devolución"
  };
  const motivoLlano = m => MOTIVOS[m] || String(m || "").replace(/_/g, " ").replace(/^./, c => c.toUpperCase());
  const obraTexto = o => !o ? "" : typeof o === "string" ? o : (o.nombre || o.proyecto || o.id || "");

  async function pintarBandeja() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarBandeja);
    let filas;
    try {
      const [b] = await Promise.all([
        DB._leer("v_banco_bandeja?select=*&order=alarma.desc,fecha.asc,movimiento_id.asc"),
        saldos(), cuentas(), proyectos(), leerStripe(), leerMfa()
      ]);
      // los depósitos de Stripe ya en el libro y sin casar: el botón «Es el depósito de Stripe del …» (si no contesta, sin botón)
      S.stripePayouts = S.stripe ? await DB._leer("v_stripe_payouts?select=po,estado_pantalla,monto,llegada&estado_pantalla=eq.asentado").catch(e => { if (esFalloDeRed(e)) throw e; return []; }) : [];
      const hoy = hoyMiami();
      await controlar(["v_banco_bandeja"], { v_banco_bandeja: b.filter(f => String(f.fecha) <= hoy).length });
      if (!S.cuentas.length) throw errorControl("El plan de cuentas no se pudo leer", [{ vista: "cuentas", filas: 0, esperadas: "1 o más", detalle: "sin el plan no se puede clasificar nada" }]);
      filas = b;
    } catch (err) { return pintarError(err, pintarBandeja); }
    filas.forEach(prepararMov);
    S.bandeja = filas; pintarBadge();
    const conMovs = [...new Set(filas.map(f => f.cuenta))];
    if (S.filtroCuenta && !conMovs.includes(S.filtroCuenta)) S.filtroCuenta = null;
    const visibles = S.filtroCuenta ? filas.filter(f => f.cuenta === S.filtroCuenta) : filas;
    main().innerHTML = `<section class="ct-card ct-barra">
        <div class="ct-barra-txt">${filas.length ? `<b>${plural(filas.length, "movimiento del banco espera", "movimientos del banco esperan")}</b> tu respuesta. Lo que no contestes no entra al libro; nada se inventa.` : "<b>La bandeja está vacía.</b> Todo lo que trajo el banco tiene su papel en el libro."}</div>
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-casar">Casar otra vez</button></div>
        ${conMovs.length > 1 ? `<div class="ct-chips"><button type="button" class="ct-chip" data-filtro="" aria-pressed="${!S.filtroCuenta}">Todas</button>${conMovs.map(c => `<button type="button" class="ct-chip" data-filtro="${esc(c)}" aria-pressed="${S.filtroCuenta === c}">${esc(nombreCuenta(c))} (${filas.filter(f => f.cuenta === c).length})</button>`).join("")}</div>` : ""}
      </section>
      ${visibles.length ? `<div class="ct-lista">${visibles.map(movHTML).join("")}</div>` : ""}`;
    $("ct-casar").addEventListener("click", async () => {
      if (S.ocupado) return;
      S.ocupado = true; $("ct-casar").disabled = true; $("ct-casar").textContent = "Casando…";
      try { const k = await casarTodo(null); S.hooks.avisar(`${k.casados} casaron solos · ${k.pendientes} siguen en la bandeja`); S.saldos = null; }
      catch (err) { S.hooks.avisar("No se pudo casar: " + err.message, true); }
      finally { S.ocupado = false; }
      pintarBandeja();
    });
    main().querySelectorAll(".ct-chip").forEach(b => b.addEventListener("click", () => { S.filtroCuenta = b.dataset.filtro || null; pintarBandeja(); }));
    main().querySelectorAll(".ct-mov").forEach(card => {
      const m = filas.find(f => f.movimiento_id === card.dataset.id);
      card.querySelectorAll("[data-op]").forEach(b => b.addEventListener("click", () => abrirOpcion(card, m, (m.opciones || [])[Number(b.dataset.op)])));
      card.querySelector("[data-otra]").addEventListener("click", () => abrirOtra(card, m));
      card.querySelectorAll("[data-stripe-po]").forEach(b => b.addEventListener("click", () => accionStripe(card, { accion: "casar_payout", po: b.dataset.stripePo, movimiento_id: m.movimiento_id },
        r => r && r.casado === false ? "No casó: sigue en la bandeja" : `Casado con el depósito de Stripe ${b.dataset.stripePo}`)));
    });
  }

  function movHTML(m) {
    const neg = num(m.monto) < 0;
    const ops = Array.isArray(m.opciones) ? m.opciones : [];
    const obra = obraTexto(m.obra);
    return `<article class="ct-card ct-mov${m.alarma ? " alarma" : ""}" data-id="${esc(m.movimiento_id)}">
      <div class="ct-mov-cab">
        <div class="ct-mov-quien"><b>${esc(m.descripcion || "(sin descripción)")}</b>${m.memo ? `<small>${esc(m.memo)}</small>` : ""}</div>
        <div class="ct-monto ct-num ${neg ? "neg" : "pos"}">${neg ? "−" : "+"}${fmtAbs(m.monto)}</div>
      </div>
      <div class="ct-meta"><span>${fechaLarga(m.fecha)}</span><span>${esc(m.cuenta_nombre)}</span>${m.cheque ? `<span>cheque ${esc(m.cheque)}</span>` : ""}${m.tipo_banco ? `<span>${esc(m.tipo_banco)}</span>` : ""}<span>hace ${plural(m.dias, "día", "días")}</span>${pill(motivoLlano(m.motivo), m.motivo === "posible_duplicado" || m.motivo === "quitada" ? "warn" : "")}${m.alarma ? pill("más de 30 días", "bad") : ""}${obra ? pill("obra: " + obra) : ""}</div>
      <p class="ct-texto">${esc(m.texto)}</p>
      ${m._esStripe ? `<p class="ct-aviso warn ct-aviso-dep">Depósito de Stripe: casa solo con su depósito en «Cobros en línea». No lo registres aquí como cobro: entraría dos veces.</p>` : ""}
      ${m.posible_duplicado_de ? `<p class="ct-aviso warn">Se parece al del ${fecha(m.duplicado_fecha)} «${esc(m.duplicado_descripcion)}»${m.duplicado_origen ? ` (entró por ${esc(m.duplicado_origen)})` : ""}.</p>` : ""}
      <div class="ct-acciones">${(m._stripe || []).map(q => `<button type="button" class="accion" data-stripe-po="${esc(q.po)}">Es el depósito de Stripe del ${fechaLarga(q.llegada)}: casarlo</button>`).join("")}${ops.map((o, i) => `<button type="button" class="accion${i || (m._stripe || []).length ? " secundaria" : ""}" data-op="${i}">${esc(o.texto)}</button>`).join("")}
        <button type="button" class="accion secundaria ct-otra" data-otra>Otra cosa…</button></div>
      <div class="ct-form" hidden></div>
      ${m._esStripe ? `<div class="ct-stripe-res"></div>` : ""}
    </article>`;
  }

  // Los campos que una opción puede pedir (c6: pide / pide_motivo)
  const CAMPOS = {
    p_motivo: { tipo: "textarea", etiqueta: "Motivo (queda escrito en el libro)" },
    p_notas: { tipo: "textarea", etiqueta: "Por qué (queda en las notas del cobro)" },
    "p_partidas.motivo": { tipo: "textarea", etiqueta: "Motivo (queda escrito en el libro)" },
    p_capital: { tipo: "monto", etiqueta: "Capital, según el statement del prestamista" },
    p_interes: { tipo: "monto", etiqueta: "Interés, según el statement" }
  };
  function campoHTML(nombre, etiqueta, tipo, extra = "") {
    const c = CAMPOS[nombre] || {};
    const et = etiqueta || c.etiqueta || nombre, t = tipo || c.tipo || "texto";
    if (t === "textarea") return `<label class="ct-campo">${esc(et)}<textarea name="${esc(nombre)}" rows="2" ${extra}></textarea></label>`;
    if (t === "monto") return `<label class="ct-campo">${esc(et)}<input name="${esc(nombre)}" inputmode="decimal" placeholder="0.00" autocomplete="off" ${extra}></label>`;
    return `<label class="ct-campo">${esc(et)}<input name="${esc(nombre)}" autocomplete="off" ${extra}></label>`;
  }
  function formaHTML(titulo, campos, boton) {
    return `<form class="ct-pide" novalidate><p class="ct-form-t">${titulo}</p>${campos}<div class="ct-acciones"><button class="accion" type="submit">${esc(boton || "Confirmar")}</button><button class="accion secundaria" type="button" data-cerrar>Cancelar</button></div></form>`;
  }
  function montarForma(card, html, alEnviar) {
    const f = card.querySelector(".ct-form");
    f.hidden = false;
    f.innerHTML = html;
    f.querySelector("[data-cerrar]").addEventListener("click", () => { f.hidden = true; f.innerHTML = ""; });
    f.querySelector("form").addEventListener("submit", ev => {
      ev.preventDefault();
      const fd = new FormData(ev.target);
      const v = {}; for (const [k, val] of fd.entries()) v[k] = String(val).trim();
      const falta = [...ev.target.querySelectorAll("[required]")].find(el => el.type === "checkbox" ? !el.checked : !String(el.value || "").trim());
      if (falta) { mostrarErrorForma(card, falta.dataset.falta || ("Falta " + (falta.closest("label") ? falta.closest("label").firstChild.textContent.trim().toLowerCase() : "un dato") + ".")); return; }
      alEnviar(v);
    });
    f.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }
  function mostrarErrorForma(card, msg) {
    const f = card.querySelector(".ct-form");
    f.hidden = false;
    const viejo = f.querySelector(".ct-error"); if (viejo) viejo.remove();
    f.insertAdjacentHTML("beforeend", `<p class="ct-aviso bad ct-error">${esc(msg)}</p>`);
  }

  // Un botón de la propuesta: llama tal cual, o pide antes lo que la base dice
  function abrirOpcion(card, m, o) {
    if (!o || !o.llamar) return;
    const pide = [...new Set((Array.isArray(o.pide) ? o.pide : []).concat(o.pide_motivo && !(Array.isArray(o.pide) && o.pide.length) ? ["p_motivo"] : []))];
    if (!pide.length) return llamar(card, m, o.llamar, { ...(o.args || {}) });
    montarForma(card, formaHTML(esc(o.texto), pide.map(p => campoHTML(p, null, null, "required")), "Confirmar"), v => {
      const args = { ...(o.args || {}) };
      for (const p of pide) {
        if (p === "p_partidas.motivo") {
          const prev = args.p_partidas;
          args.p_partidas = { motivo: v[p], partidas: Array.isArray(prev) ? prev : (prev && prev.partidas) || null };
        } else args[p] = v[p];
      }
      llamar(card, m, o.llamar, args);
    });
  }

  // «Otra cosa…»: lo que la base acepta aunque no lo haya propuesto
  function abrirOtra(card, m) {
    const f = card.querySelector(".ct-form");
    f.hidden = false;
    f.innerHTML = `<div class="ct-otra-menu"><p class="ct-form-t">¿Qué es este movimiento?</p><div class="ct-acciones">
      <button type="button" class="accion secundaria" data-que="clasificar">Un gasto o un costo: clasificarlo a una cuenta</button>
      <button type="button" class="accion secundaria" data-que="transferencia">Dinero entre cuentas propias</button>
      <button type="button" class="accion secundaria" data-que="partida">Una partida en tránsito del 30-sep</button>
      <button type="button" class="accion secundaria" data-que="asiento">Ya está en el libro: casarlo con su asiento</button>
      <button type="button" class="accion secundaria" data-que="ignorar">No es del libro: ignorarlo</button>
      <button type="button" class="accion secundaria" data-cerrar>Cancelar</button></div></div>`;
    f.querySelector("[data-cerrar]").addEventListener("click", () => { f.hidden = true; f.innerHTML = ""; });
    f.querySelectorAll("[data-que]").forEach(b => b.addEventListener("click", () => formaOtra(card, m, b.dataset.que)));
  }
  const grupoCuenta = t => ({ activo: "Activo", pasivo: "Pasivo", capital: "Capital", ingreso: "Ingresos", costo: "Costo de obra", gasto: "Gastos", otro_ingreso: "Otros ingresos", otro_gasto: "Otros gastos" })[t] || t;
  async function formaOtra(card, m, que) {
    if (que === "clasificar") {
      const orden = ["costo", "gasto", "otro_gasto", "activo", "pasivo", "capital", "otro_ingreso", "ingreso"];
      const grupos = orden.map(t => {
        const cs = (S.cuentas || []).filter(c => c.tipo === t && !esStripe(c.codigo));
        return cs.length ? `<optgroup label="${esc(grupoCuenta(t))}">${cs.map(c => `<option value="${esc(c.codigo)}">${esc(c.codigo)} · ${esc(c.nombre)}${c.regla_obra === "obligatoria" ? " (pide obra)" : ""}</option>`).join("")}</optgroup>` : "";
      }).join("");
      const activos = (S.proyectos || []).filter(p => ["ejecucion", "aprobado", "pausa"].includes(p.estado));
      const otros = (S.proyectos || []).filter(p => !["ejecucion", "aprobado", "pausa"].includes(p.estado));
      const opts = ps => ps.map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("");
      montarForma(card, formaHTML("Clasificar a una cuenta del libro",
        `<label class="ct-campo">Cuenta<select name="cuenta" required><option value="">Elige la cuenta…</option>${grupos}</select></label>
         <label class="ct-campo">Obra (si la cuenta la pide)<select name="proyecto"><option value="">Sin obra</option>${activos.length ? `<optgroup label="En marcha">${opts(activos)}</optgroup>` : ""}${otros.length ? `<optgroup label="Las demás">${opts(otros)}</optgroup>` : ""}</select></label>
         ${campoHTML("memo", "Memo (opcional)", "texto")}
         ${campoHTML("p_motivo", "Motivo (si la base lo pide; queda escrito en el libro)", "textarea")}`, "Clasificar"), v => {
        const linea = { cuenta: v.cuenta };
        if (v.proyecto) linea.proyecto_id = v.proyecto;
        if (v.memo) linea.memo = v.memo;
        llamar(card, m, "fn_banco_clasificar", { p_movimiento: m.movimiento_id, p_lineas: [linea], p_motivo: v.p_motivo || null });
      });
    } else if (que === "transferencia") {
      const otras = visibles(S.saldos).filter(c => c.cuenta !== m.cuenta);
      montarForma(card, formaHTML("Dinero entre cuentas propias (sin gasto): el otro lado casará solo cuando llegue",
        `<label class="ct-campo">${num(m.monto) < 0 ? "Hacia" : "Desde"} la cuenta<select name="cuenta" required><option value="">Elige la cuenta…</option>${otras.map(c => `<option value="${esc(c.cuenta)}">${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
         ${campoHTML("p_motivo", "Motivo (si la base lo pide; queda escrito)", "textarea")}`, "Confirmar la transferencia"), v => {
        llamar(card, m, "fn_banco_transferencia", { p_movimiento: m.movimiento_id, p_cuenta: v.cuenta, p_motivo: v.p_motivo || null });
      });
    } else if (que === "partida") {
      const f = card.querySelector(".ct-form");
      f.innerHTML = `<p class="ct-aviso">Buscando las partidas en tránsito del 30-sep de ${esc(m.cuenta_nombre)}…</p>`;
      let partidas = [];
      try {
        const ap = await DB._leer(`v_conciliacion?select=conciliacion_id&cuenta=eq.${encodeURIComponent(m.cuenta)}&tipo=eq.apertura`);
        if (ap.length) partidas = await DB._leer(`v_conciliacion_partidas?select=partida_id,fecha,monto,descripcion,clase&conciliacion_id=eq.${ap[0].conciliacion_id}&grupo=eq.en_libros_no_en_banco&resuelta_en=is.null&resuelta_por_movimiento=is.null&order=fecha.asc`);
      } catch (err) { mostrarErrorForma(card, err.message); return; }
      if (!partidas.length) { f.innerHTML = `<p class="ct-aviso warn">Esta cuenta no tiene partidas del 30-sep sin resolver.</p><div class="ct-acciones"><button type="button" class="accion secundaria" data-cerrar>Cerrar</button></div>`; f.querySelector("[data-cerrar]").addEventListener("click", () => { f.hidden = true; f.innerHTML = ""; }); return; }
      montarForma(card, formaHTML("Casar con una partida en tránsito de la conciliación de apertura (lo que QuickBooks tenía al 30-sep)",
        `<label class="ct-campo">Partida<select name="partida" required><option value="">Elige la partida…</option>${partidas.map(p => `<option value="${esc(p.partida_id)}">${fechaLarga(p.fecha)} · ${fmt(p.monto)} · ${esc(p.descripcion || p.clase)}</option>`).join("")}</select></label>
         ${campoHTML("p_motivo", "Motivo (si la base lo pide: dos partidas iguales, una parte…)", "textarea")}`, "Casar"), v => {
        llamar(card, m, "fn_banco_casar_con", { p_movimiento: m.movimiento_id, p_con: { partida_apertura: v.partida }, p_motivo: v.p_motivo || null });
      });
    } else if (que === "asiento") {
      montarForma(card, formaHTML("Casar con un asiento que ya está en el libro",
        `${campoHTML("asiento", "Número del asiento (2026-000012)", "texto", "required")}
         ${campoHTML("p_motivo", "Motivo (si la base lo pide)", "textarea")}`, "Casar"), v => {
        llamar(card, m, "fn_banco_casar_con", { p_movimiento: m.movimiento_id, p_con: { asiento: v.asiento }, p_motivo: v.p_motivo || null });
      });
    } else if (que === "ignorar") {
      montarForma(card, formaHTML("Ignorarlo: no es del libro (queda registrado que lo dijiste, con tu motivo)",
        campoHTML("p_motivo", null, null, "required"), "Ignorar"), v => {
        llamar(card, m, "fn_banco_ignorar", { p_movimiento: m.movimiento_id, p_motivo: v.p_motivo });
      });
    }
  }

  const ESTADO_LLANO = { casado: "casado", ignorado: "ignorado", en_transito: "en tránsito", pendiente: "sigue pendiente", duplicado: "duplicado" };
  function resumenHecho(r) {
    const est = r && r.estado ? ESTADO_LLANO[r.estado] || r.estado : "";
    return `Hecho${est ? ": " + est : ""}${r && r.asiento ? " · asiento " + r.asiento : ""}${r && r.reverso ? " · se reversó " + r.reverso : ""}`;
  }
  async function llamar(card, m, fn, args) {
    if (S.ocupado) return;
    S.ocupado = true;
    card.classList.add("ocupado");
    card.querySelectorAll("button").forEach(b => { b.disabled = true; });
    try {
      const r = await DB._rpc(fn, args);
      S.hooks.avisar(resumenHecho(r));
      S.saldos = null;
      await pintarBandeja();
    } catch (err) {
      card.classList.remove("ocupado");
      card.querySelectorAll("button").forEach(b => { b.disabled = false; });
      mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se guardó. Vuelve a intentarlo con señal." : err.message);
    } finally { S.ocupado = false; }
  }

  // ============================================================
  // CONCILIAR
  // ============================================================
  const ultimoDiaMesAnterior = () => { const h = hoyMiami(); const [a, m] = partes(h); const d = new Date(Date.UTC(a, m - 1, 0)); return d.toISOString().slice(0, 10); };

  async function pintarConciliar() {
    if (S.conc) return pintarConciliacion(S.conc);
    cargando();
    if (!navigator.onLine) return sinSenal(pintarConciliar);
    let lista;
    try {
      const [l] = await Promise.all([DB._leer("v_conciliacion?select=*&order=fecha_corte.desc,cuenta.asc"), saldos(), leerStripe()]);
      const hoy = hoyMiami(), desde = hoy.slice(0, 8) + "01";
      await controlar(["v_conciliacion"], { v_conciliacion: l.filter(c => String(c.fecha_corte) >= desde && String(c.fecha_corte) <= hoy).length });
      lista = l;
    } catch (err) { return pintarError(err, pintarConciliar); }
    const sal = visibles(S.saldos); // la 1020 y la 1140 no se concilian: no tienen estado de cuenta (las vigila el control de Stripe)
    const def = sal.find(c => c.cuenta === S.concCuenta) || sal[0];
    const fechaDef = c => c && c.saldo_banco_al ? String(c.saldo_banco_al) : ultimoDiaMesAnterior();
    const saldoDef = c => c && c.saldo_banco != null ? String(c.saldo_banco_como_banco) : "";
    main().innerHTML = `<section class="ct-card">
        <h2>Conciliar una cuenta con su statement</h2>
        <p class="ct-nota">Sube antes el archivo del statement (en Bancos y tarjetas). Aquí van la fecha de corte y el saldo final tal como lo dice el statement (en una tarjeta, lo que debes, en positivo). Cuadra cuando libros = banco + lo que está en libros y no en el banco − lo que está en el banco y no en libros.</p>
        <form id="ct-conc-form" class="ct-pide" novalidate>
          <div class="ct-fila">
            <label class="ct-campo">Cuenta<select name="cuenta">${sal.map(c => `<option value="${esc(c.cuenta)}"${def && c.cuenta === def.cuenta ? " selected" : ""}>${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
            <label class="ct-campo">Fecha de corte<input name="fecha" type="date" required value="${esc(fechaDef(def))}"></label>
            <label class="ct-campo">Saldo final del statement<input name="saldo" inputmode="decimal" placeholder="14,675.12" autocomplete="off" value="${esc(saldoDef(def))}"></label>
            <button type="submit" class="accion">Calcular</button>
          </div>
        </form>
        <div id="ct-conc-aviso"></div>
      </section>
      <section class="ct-card"><h2>Conciliaciones</h2>
        ${lista.length ? `<div class="ct-tabla-env"><table class="ct-tabla"><thead><tr><th>Cuenta</th><th>Corte</th><th>Tipo</th><th>Estado</th><th class="r">Statement</th><th class="r">Libros</th><th class="r">Diferencia</th><th></th></tr></thead><tbody>
          ${lista.map(c => `<tr><td>${esc(c.cuenta_nombre)}<br><small>${esc(c.cuenta)}</small></td><td>${fechaLarga(c.fecha_corte)}</td><td>${esc(c.tipo)}</td><td>${estadoPill(c.estado)}</td><td class="r ct-num">${fmt(c.saldo_statement)}</td><td class="r ct-num">${fmt(c.saldo_libros)}</td><td class="r ct-num ${num(c.diferencia) === 0 ? "ok-txt" : num(c.diferencia) == null ? "" : "bad-txt"}">${fmt(c.diferencia)}</td><td><button type="button" class="accion secundaria chica" data-conc="${esc(c.conciliacion_id)}">Abrir</button></td></tr>`).join("")}
        </tbody></table></div>` : `<p class="ct-nota">Todavía no hay ninguna.</p>`}
      </section>`;
    const form = $("ct-conc-form");
    form.cuenta.addEventListener("change", () => { const c = sal.find(x => x.cuenta === form.cuenta.value); S.concCuenta = form.cuenta.value; form.fecha.value = fechaDef(c); form.saldo.value = saldoDef(c); });
    form.addEventListener("submit", async ev => {
      ev.preventDefault();
      if (S.ocupado) return;
      const aviso = $("ct-conc-aviso");
      if (!form.fecha.value) { aviso.innerHTML = `<p class="ct-aviso bad">Falta la fecha de corte.</p>`; return; }
      S.ocupado = true;
      aviso.innerHTML = `<p class="ct-aviso">Calculando…</p>`;
      try {
        const r = await DB._rpc("fn_conciliar", { p_cuenta: form.cuenta.value, p_fecha_corte: form.fecha.value, p_saldo_statement: form.saldo.value.trim() || null });
        S.concCuenta = form.cuenta.value;
        S.ocupado = false;
        if (!r || !r.conciliacion) throw new Error("La base no devolvió la conciliación.");
        S.conc = r.conciliacion;
        return pintarConciliacion(S.conc);
      } catch (err) {
        aviso.innerHTML = `<p class="ct-aviso bad">${esc(esFalloDeRed(err) ? "Sin señal: no se calculó." : err.message)}</p>`;
      } finally { S.ocupado = false; }
    });
    main().querySelectorAll("[data-conc]").forEach(b => b.addEventListener("click", () => { S.conc = b.dataset.conc; pintarConciliacion(S.conc); }));
  }

  async function pintarConciliacion(id) {
    cargando();
    if (!navigator.onLine) return sinSenal(() => pintarConciliacion(id));
    let c, partidas;
    try {
      const [cs, ps] = await Promise.all([
        DB._leer(`v_conciliacion?select=*&conciliacion_id=eq.${encodeURIComponent(id)}`),
        DB._leer(`v_conciliacion_partidas?select=*&conciliacion_id=eq.${encodeURIComponent(id)}&order=grupo.asc,fecha.asc,orden.asc`)
      ]);
      await controlar(["v_conciliacion", "v_conciliacion_partidas"]);
      if (!Array.isArray(cs) || cs.length !== 1) throw errorControl("La conciliación no apareció", [{ vista: "v_conciliacion", filas: Array.isArray(cs) ? cs.length : 0, esperadas: 1, detalle: id }]);
      c = cs[0]; partidas = ps;
    } catch (err) { return pintarError(err, () => pintarConciliacion(id)); }
    S.hooks.titulo(KICKER, `Conciliación · ${c.cuenta_nombre}`);
    const tarjeta = (S.saldos || []).some(x => x.cuenta === c.cuenta && x.tipo === "tarjeta");
    const grupo = g => partidas.filter(p => p.grupo === g);
    const libroNo = grupo("en_libros_no_en_banco"), bancoNo = grupo("en_banco_no_en_libros"), casados = grupo("casado");
    const dif = num(c.diferencia);
    const partidaHTML = p => `<li class="ct-partida${p.alarma ? " alarma" : ""}"><span class="ct-partida-f">${fechaLarga(p.fecha)}</span><span class="ct-partida-d"><b>${esc(p.descripcion || "")}</b>${p.cheque ? ` · cheque ${esc(p.cheque)}` : ""}${p.asiento_numero ? ` · asiento ${esc(p.asiento_numero)}` : ""}${p.clase ? ` ${pill(String(p.clase).replace(/_/g, " "), p.clase === "error" ? "bad" : "")}` : ""}${p.alarma ? pill(`${p.dias} días`, "bad") : ""}${p.explicacion ? `<small>${esc(p.explicacion)}</small>` : ""}${p.motivo && p.grupo !== "casado" ? `<small>Motivo: ${esc(p.motivo)}</small>` : ""}</span><span class="ct-partida-m ct-num">${fmt(p.monto)}</span></li>`;
    main().innerHTML = `<section class="ct-card">
        <div class="ct-cab"><h2>${esc(c.cuenta_nombre)} · corte ${fechaLarga(c.fecha_corte)}</h2>${estadoPill(c.estado)}${pill(c.tipo)}</div>
        <div class="ct-kpis cuatro">
          <div class="ct-kpi"><span class="ct-lbl">Libros al corte</span><span class="ct-val ct-num">${fmt(c.saldo_libros)}</span></div>
          <div class="ct-kpi"><span class="ct-lbl">Statement</span><span class="ct-val ct-num">${c.saldo_statement == null ? "falta" : fmt(c.saldo_statement)}</span><span class="ct-sub">${c.saldo_banco == null ? "" : `con el signo del libro: ${fmt(c.saldo_banco)}`}</span></div>
          <div class="ct-kpi"><span class="ct-lbl">En libros, no en el banco</span><span class="ct-val ct-num">${fmt(num(c.depositos_transito) - num(c.cargos_circulacion))}</span><span class="ct-sub">${fmt(c.depositos_transito)} − ${fmt(c.cargos_circulacion)} · ${plural(c.n_transito, "partida", "partidas")}</span></div>
          <div class="ct-kpi"><span class="ct-lbl">Diferencia</span><span class="ct-val ct-num ${dif === 0 ? "ok-txt" : dif == null ? "" : "bad-txt"}">${fmt(c.diferencia)}</span><span class="ct-sub">${plural(c.n_sin_casar, "movimiento sin casar", "movimientos sin casar")}</span></div>
        </div>
        <p class="ct-nota ct-num">${esc(c.identidad || "")}</p>
        ${c.estado === "abierta" && c.falta ? `<p class="ct-aviso warn">${esc(c.falta)}</p>` : ""}
        ${c.estado === "confirmada" ? `<p class="ct-nota">Confirmada el ${c.confirmada_el ? fechaLarga(String(c.confirmada_el).slice(0, 10)) : "—"}${c.reabierta_el ? ` · se reabrió el ${fechaLarga(String(c.reabierta_el).slice(0, 10))}: ${esc(c.reabierta_motivo || "")}` : ""}</p>` : ""}
        <div class="ct-acciones">
          ${c.lista_para_confirmar ? `<button type="button" class="accion" id="ct-conf">Confirmar la conciliación</button>` : ""}
          ${c.estado === "abierta" ? `<button type="button" class="accion secundaria" id="ct-recalc">Recalcular</button><button type="button" class="accion secundaria" id="ct-saldo">Cambiar el saldo del statement</button>` : ""}
          ${c.estado === "confirmada" && c.tipo === "normal" ? `<button type="button" class="accion secundaria" id="ct-reabrir">Reabrir (con su motivo)</button>` : ""}
          <button type="button" class="accion secundaria" id="ct-volver-lista">← Todas las conciliaciones</button>
        </div>
        <div class="ct-form" hidden></div>
      </section>
      <section class="ct-card"><h2>En el banco y no en libros · ${bancoNo.length}</h2>
        ${bancoNo.length ? `<p class="ct-nota">Movimientos del banco sin su papel en el libro: se resuelven en la bandeja.</p><ul class="ct-partidas">${bancoNo.map(partidaHTML).join("")}</ul><div class="ct-acciones"><button type="button" class="accion" id="ct-a-bandeja">Resolverlos en la bandeja</button></div>` : `<p class="ct-nota">Nada: todo lo que trajo el banco hasta el corte tiene su papel.</p>`}
      </section>
      <section class="ct-card"><h2>En libros y no en el banco · ${libroNo.length}</h2>
        ${libroNo.length ? `<p class="ct-nota">${tarjeta ? "Pagos y cargos que el libro ya tiene y el statement todavía no trae." : "Depósitos en tránsito y cheques en circulación: el libro ya los tiene y el banco todavía no."}</p><ul class="ct-partidas">${libroNo.map(partidaHTML).join("")}</ul>` : `<p class="ct-nota">Nada pendiente del lado del libro.</p>`}
      </section>
      <details class="ct-card ct-detalles"><summary>Casados en este tramo · ${casados.length}</summary>
        ${casados.length ? `<ul class="ct-partidas">${casados.map(partidaHTML).join("")}</ul>` : `<p class="ct-nota">Ninguno.</p>`}
      </details>`;
    const card = main().querySelector(".ct-card");
    $("ct-volver-lista").addEventListener("click", () => { S.conc = null; S.hooks.titulo(KICKER, TITULOS.conciliar); pintarConciliar(); });
    const ab = $("ct-a-bandeja"); if (ab) ab.addEventListener("click", () => ir("bandeja", { cuenta: c.cuenta }));
    const accion = async (fn, args, exito) => {
      if (S.ocupado) return;
      S.ocupado = true;
      card.querySelectorAll("button").forEach(b => { b.disabled = true; });
      try {
        const r = await DB._rpc(fn, args);
        S.hooks.avisar(exito(r));
        S.saldos = null;
        await pintarConciliacion(id);
      } catch (err) {
        card.querySelectorAll("button").forEach(b => { b.disabled = false; });
        mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se guardó." : err.message);
      } finally { S.ocupado = false; }
    };
    const conf = $("ct-conf"); if (conf) conf.addEventListener("click", () => accion("fn_conciliacion_confirmar", { p_conciliacion: id }, r => `Conciliación confirmada${r && Array.isArray(r.alarmas) && r.alarmas.length ? ` · ${r.alarmas.length} partida(s) con alarma` : ""}`));
    const rec = $("ct-recalc"); if (rec) rec.addEventListener("click", () => accion("fn_conciliar", { p_cuenta: c.cuenta, p_fecha_corte: c.fecha_corte, p_saldo_statement: null }, () => "Recalculada"));
    const sal = $("ct-saldo"); if (sal) sal.addEventListener("click", () => montarForma(card, formaHTML("El saldo final del statement, tal como lo dice", campoHTML("saldo", tarjeta ? "Saldo (lo que debes, en positivo)" : "Saldo final", "monto", "required"), "Guardar y recalcular"), v => accion("fn_conciliar", { p_cuenta: c.cuenta, p_fecha_corte: c.fecha_corte, p_saldo_statement: v.saldo }, () => "Saldo guardado y recalculada")));
    const re = $("ct-reabrir"); if (re) re.addEventListener("click", () => montarForma(card, formaHTML("Reabrir la conciliación (queda escrito por qué)", campoHTML("p_motivo", null, null, "required"), "Reabrir"), v => accion("fn_conciliacion_reabrir", { p_conciliacion: id, p_motivo: v.p_motivo }, () => "Reabierta")));
  }

  // ============================================================
  // MOVIMIENTOS (lo que el banco trajo, con su estado)
  // ============================================================
  const ESTADO_MOV = { pendiente: ["pendiente", "warn"], casado: ["casado", "ok"], en_transito: ["en tránsito", ""], ignorado: ["ignorado", ""], duplicado: ["duplicado", "warn"], clasificado: ["clasificado", "ok"] };
  async function pintarMovimientos() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarMovimientos);
    let filas;
    try {
      await saldos();
      await leerStripe();
      const vis = visibles(S.saldos);
      if (!S.movCuenta || !vis.some(c => c.cuenta === S.movCuenta)) S.movCuenta = vis.length ? vis[0].cuenta : null;
      const est = S.movEstado ? `&estado=eq.${encodeURIComponent(S.movEstado)}` : "";
      filas = S.movCuenta ? await DB._leer(`v_banco_movimientos?select=movimiento_id,fecha,monto,descripcion,memo,cheque,tipo_banco,estado,estado_motivo,casado_clase,casado_regla,casado_auto,asiento_numero,papel_tabla,papel_id,archivo,propuesta_motivo&cuenta=eq.${encodeURIComponent(S.movCuenta)}${est}&order=fecha.desc,movimiento_id.asc&limit=300`) : [];
      await controlar(["v_banco_movimientos"]);
    } catch (err) { return pintarError(err, pintarMovimientos); }
    const estados = Object.keys(ESTADO_MOV);
    main().innerHTML = `<section class="ct-card ct-barra">
        <div class="ct-fila">
          <label class="ct-campo">Cuenta<select id="ct-mov-cuenta">${visibles(S.saldos).map(c => `<option value="${esc(c.cuenta)}"${c.cuenta === S.movCuenta ? " selected" : ""}>${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
          <label class="ct-campo">Estado<select id="ct-mov-estado"><option value="">Todos</option>${estados.map(e => `<option value="${e}"${e === S.movEstado ? " selected" : ""}>${ESTADO_MOV[e][0]}</option>`).join("")}</select></label>
        </div>
        <p class="ct-nota">${plural(filas.length, "movimiento", "movimientos")}${filas.length >= 300 ? " (los 300 más recientes)" : ""}. Cada uno con lo que la base decidió y el asiento con que casó.</p>
      </section>
      ${filas.length ? `<section class="ct-card"><div class="ct-tabla-env"><table class="ct-tabla"><thead><tr><th>Fecha</th><th>Descripción</th><th class="r">Monto</th><th>Estado</th><th>Cómo</th><th>Asiento</th></tr></thead><tbody>
        ${filas.map(m => { const e = ESTADO_MOV[m.estado] || [m.estado, ""]; return `<tr><td>${fechaLarga(m.fecha)}</td><td><b>${esc(m.descripcion || "")}</b>${m.memo ? `<br><small>${esc(m.memo)}</small>` : ""}${m.cheque ? `<br><small>cheque ${esc(m.cheque)}</small>` : ""}</td><td class="r ct-num ${num(m.monto) < 0 ? "neg" : "pos"}">${fmt(m.monto)}</td><td>${pill(e[0], e[1])}</td><td><small>${esc(m.estado === "pendiente" ? motivoLlano(m.propuesta_motivo) : [m.casado_regla || m.casado_clase || "", m.casado_auto === true ? "solo" : m.casado_auto === false ? "Edgar" : "", m.estado_motivo || ""].filter(Boolean).join(" · "))}</small></td><td class="ct-num"><small>${esc(m.asiento_numero || "")}${m.papel_tabla ? `<br>${esc(m.papel_tabla)} ${esc(m.papel_id || "")}` : ""}</small></td></tr>`; }).join("")}
      </tbody></table></div></section>` : `<section class="ct-card ct-vacio">Nada con ese filtro.</section>`}`;
    $("ct-mov-cuenta").addEventListener("change", ev => { S.movCuenta = ev.target.value; pintarMovimientos(); });
    $("ct-mov-estado").addEventListener("change", ev => { S.movEstado = ev.target.value; pintarMovimientos(); });
  }

  // ============================================================
  // ESTADOS FINANCIEROS (c4: docs/conta/c4-estados.sql) — solo lectura.
  // Resultados, balance, balanza → mayor → asiento → papel, flujo de caja y
  // la comparación con QuickBooks. Ninguna cifra se calcula aquí: vienen
  // listas de la base con su signo (cifra, mes, variacion, acumulado…) y la
  // pantalla solo las formatea. Antes de pintar cada estado, fn_estados_control
  // dice si sus vistas cuadran con el libro; con el tope por reloj («Sigue»)
  // se vuelve a pedir lo que faltó, y ok = null nunca es verde.
  // ============================================================
  const MES_LARGO = ["", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
  const cap = s => { s = String(s || ""); return s.charAt(0).toUpperCase() + s.slice(1); };
  const minus = s => { s = String(s || ""); return s.charAt(0).toLowerCase() + s.slice(1); };
  const MENOS = "−"; // el menos tipográfico: nunca el guion ni paréntesis
  const fmtNeg = v => { const n = num(v); return n == null || Number.isNaN(n) ? "—" : money.format(n).replace("-", MENOS); };
  const fmtSigno = v => { const n = num(v); if (n == null || Number.isNaN(n)) return "—"; return n > 0 ? "+" + money.format(n) : n < 0 ? MENOS + money.format(Math.abs(n)) : money.format(0); };
  const fmtPct = v => { const n = num(v); if (n == null || Number.isNaN(n)) return "—"; return `${n > 0 ? "+" : n < 0 ? MENOS : ""}${Math.abs(n).toFixed(1)} %`; };
  // un 0.00 que la vista devolvió se atenúa (es dato, no vacío); un NULL siempre va «—»
  const cero = v => num(v) === 0 ? " ct-cero" : "";
  const UMBRAL_CENTAVOS = "1.00"; // comparación para pintar «Centavos», no una suma
  const FAVORABLE_MAS = { ingresos: true, otros_ingresos: true, totales: true, costo: false, gastos: false, otros_gastos: false };
  const CAMINO = { mano: "a mano", puente: "puente", ia: "IA aprobada", reverso: "reverso", reverso_automatico: "reverso automático" };
  const TIPO_AS = { apertura: "apertura", ajuste_cpa: "ajuste del CPA" };
  const ICO = {
    check: '<svg class="ct-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8.5l3 3 7-7"/></svg>',
    arriba: '<svg class="ct-ico ct-var-ico" viewBox="0 0 10 10" aria-hidden="true"><path d="M1 8l4-6 4 6z"/></svg>',
    abajo: '<svg class="ct-ico ct-var-ico" viewBox="0 0 10 10" aria-hidden="true"><path d="M1 2l4 6 4-6z"/></svg>',
    nota: '<svg class="ct-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2h6l3 3v9H4z M6 8h5M6 11h5"/></svg>',
    aprox: '<svg class="ct-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6c2-2 4-2 6 0s4 2 6 0M2 10c2-2 4-2 6 0s4 2 6 0"/></svg>',
    alerta: '<svg class="ct-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 2v7M8 12v1"/></svg>',
    equis: '<svg class="ct-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 3l10 10M13 3L3 13"/></svg>'
  };
  const pillIco = (ico, txt, clase) => `<span class="ct-pill${clase ? " " + clase : ""}">${ico}${esc(txt)}</span>`;
  const SUBS = { resultados: "Resultados", balance: "Balance", balanza: "Balanza", flujo: "Flujo de caja", comparacion: "Contra QuickBooks" };
  const H2 = { resultados: "Estado de resultados", balance: "Balance general", balanza: "Balanza de comprobación", flujo: "Flujo de caja", comparacion: "Comparación con QuickBooks" };
  const VISTAS_SUB = { resultados: ["v_resultados", "v_balance_general"], balance: ["v_balance_general"], balanza: ["v_balanza"], flujo: ["v_flujo_caja"], comparacion: ["v_comparacion", "v_comparacion_resumen"] };
  // dónde se intercalan los totales del balance (seccion_orden fijos de c4: pasivo desde 400, capital desde 600)
  const CIERRA = { total_activo: 400, total_pasivo: 600 };

  const nombrePeriodo = c => {
    if (!c) return "";
    if (c.tipo === "hoy") return "Hoy";
    if (c.tipo === "anio") return `Año ${c.anio}`;
    const [a, m] = partes(c.desde);
    return `${cap(MES_LARGO[m] || "")} ${a}${c.tipo === "apertura" ? " · apertura" : ""}`;
  };
  const nombrePeriodoMin = c => minus(nombrePeriodo(c));
  function rangoTexto(c, alCorte) {
    if (!c) return "";
    const [a, m, d] = partes(c.corte);
    if (c.tipo === "hoy") return `Al día de hoy, ${fechaLarga(c.corte)} · lo que va del mes`;
    if (c.tipo === "apertura" || alCorte) return `Al ${d} de ${MES_LARGO[m] || ""} de ${a}`;
    if (c.tipo === "anio") return `Del 1 de enero al 31 de diciembre de ${a}`;
    const [, , d0] = partes(c.desde);
    return `Del ${d0} al ${d} de ${MES_LARGO[m] || ""} de ${a}`;
  }
  const cortePill = c => c && c.estado === "cerrado" ? pill("Cerrado", "ok") : pill("Abierto");
  const diaSiguiente = iso => { const [a, m, d] = partes(iso); return new Date(Date.UTC(a, m - 1, d + 1)).toISOString().slice(0, 10); };
  const nOrd = v => { const n = Number(v); return v == null || Number.isNaN(n) ? Number.MAX_SAFE_INTEGER : n; };
  const porClaves = (filas, claves) => [...filas].sort((x, y) => { for (const k of claves) { const d = nOrd(x[k]) - nOrd(y[k]); if (d) return d; } return 0; });

  const P = () => encodeURIComponent(S.est.periodo);
  const cuerpo = () => $("ct-est-cuerpo");
  // sigue viva esta pintada: nadie pidió otra cosa después (serie) y la pestaña sigue en pantalla
  const vivo = mia => mia === S.est.serie && S.pagina === "estados" && !!cuerpo();
  const cargandoEn = txt => { const c = cuerpo(); if (c) c.innerHTML = `<div class="ct-card ct-cargando">${esc(txt || "Cargando…")}</div>`; };
  const vacioHTML = (txt, fuente) => `<p class="ct-vacio">${esc(txt)}</p><p class="ct-nota">Dato: ${esc(fuente)}</p>`;
  const notaFuente = (vistas, corte) => `Fuente: ${vistas.join(" · ")} · controlada con fn_estados_control · ${nombrePeriodo(corte)}`;
  const chipsOcupados = si => { const b = $("ct-est-barra"); if (b) b.setAttribute("aria-busy", si ? "true" : "false"); };
  const ctxN = txt => { const n = $("ct-est-ctx-n"); if (n) n.textContent = txt || ""; };
  const cabHTML = (h2, extra) => `<div class="ct-cab"><h2>${esc(h2)}</h2>${pillIco(ICO.check, "Controlado", "ok")}${extra || ""}</div>`;
  const kpiHTML = (lbl, val, sub) => `<div class="ct-kpi"><span class="ct-lbl">${esc(lbl)}</span><span class="ct-val ct-num">${val}</span>${sub ? `<span class="ct-sub">${sub}</span>` : ""}</div>`;
  const cuentaBtn = (cuenta, nombre) => `<button type="button" class="ct-cuenta-btn" data-cuenta="${esc(cuenta)}"><span class="ct-num">${esc(cuenta)}</span> ${esc(nombre || "")}</button>`;
  const asientoBtn = (id, numero) => `<button type="button" class="ct-asiento-btn ct-num" data-asiento="${esc(id)}">${esc(numero || "ver")}</button>`;
  function engancharBotones() {
    const c = cuerpo(); if (!c) return;
    c.querySelectorAll(".ct-cuenta-btn").forEach(b => b.addEventListener("click", () => ir("estados", { cuenta: b.dataset.cuenta })));
    c.querySelectorAll(".ct-asiento-btn").forEach(b => b.addEventListener("click", () => { S.est.asiento = b.dataset.asiento; pintarEstados(); }));
    const v = $("ct-est-volver"); if (v) v.addEventListener("click", () => { if (S.est.asiento) S.est.asiento = null; else S.est.cuenta = null; pintarEstados(); });
  }

  // FALLA RUIDOSA de los estados: fn_estados_control con las vistas de la
  // tarjeta. Tope por reloj (3 s desde la API): lo que vuelve con ok = null y
  // «Sigue: …» no está revisado, se vuelve a pedir (hasta 6 llamadas). Las
  // filas extra (cuadres entre vistas, protecciones de c4, apertura) que
  // vengan en false también son rojo.
  async function controlarEstados(periodo, vistas) {
    const todas = new Map();
    let pendientes = vistas.slice();
    for (let vuelta = 0; vuelta < 6 && pendientes.length; vuelta++) {
      const filas = await DB._rpc("fn_estados_control", { p_periodo: periodo, p_vistas: pendientes });
      if (!Array.isArray(filas) || !filas.length) throw errorControl("El control de los estados no devolvió ninguna fila", [{ vista: pendientes.join(", "), detalle: `fn_estados_control('${periodo}', …) contestó vacío` }]);
      for (const f of filas) if (f.ok !== null || !todas.has(f.vista)) todas.set(f.vista, f);
      pendientes = pendientes.filter(v => { const f = todas.get(v); return !f || f.ok === null; });
    }
    const lista = [...todas.values()];
    const mal = lista.filter(f => f.ok !== true && f.ok !== null).map(f => ({ vista: f.vista, filas: f.filas, esperadas: f.esperadas, detalle: f.detalle }));
    for (const v of vistas) {
      const f = todas.get(v);
      if (!f) mal.push({ vista: v, detalle: "el control no revisó esta vista" });
      else if (f.ok === null) mal.push({ vista: v, filas: f.filas, esperadas: f.esperadas, detalle: "el control no alcanzó a revisar esta vista en 6 llamadas (tope por reloj): no se pinta" });
    }
    if (mal.length) throw errorControl("El control de los estados no cuadra", mal);
    return lista;
  }
  // Lo que la pantalla trajo de cada vista contra lo que el control contó
  // (solo vale para las vistas leídas enteras con periodo=eq.; nunca el
  // mayor por cuenta ni el asiento por id).
  function cotejar(ctrl, conteos) {
    const mal = [];
    for (const v of Object.keys(conteos)) {
      const f = ctrl.find(x => x.vista === v), n = conteos[v];
      if (f && n != null && Number(f.filas) !== Number(n)) mal.push({ vista: v, filas: f.filas, esperadas: n, detalle: `la pantalla trajo ${n} fila(s) y el control contó ${f.filas}` });
    }
    if (mal.length) throw errorControl("El control de los estados no cuadra", mal);
  }
  function pintarErrorEst(err) {
    const reintentar = () => { S.est.cortes = null; pintarEstados(); };
    const titulo = err.codigo === "42501" ? "Contabilidad es solo del dueño"
      : (err.control && err.control.some(f => /apertura en el libro/.test(f.vista || ""))) ? "Falta la apertura en el libro" : undefined;
    chipsOcupados(false);
    pintarError(err, reintentar, titulo, cuerpo());
  }

  // ---------- la barra: qué estado, qué período ----------
  const enBalance = () => S.est.sub === "balance" && !S.est.cuenta && !S.est.asiento;
  function periodosOfrecidos(cortes) {
    const hoy = hoyMiami();
    const base = cortes.filter(c => ["mes", "apertura", "anio"].includes(c.tipo));
    const visibles = base.filter(c => S.est.todos || String(c.desde) <= hoy || c.periodo === S.est.periodo);
    const filaHoy = enBalance() ? cortes.find(c => c.tipo === "hoy") : null;
    return { lista: (filaHoy ? [filaHoy] : []).concat(visibles), escondidos: base.length - visibles.length };
  }
  // el mes que contiene hoy; si no, el mes más reciente ya empezado
  function mesPorRegla(cortes) {
    const hoy = hoyMiami();
    const meses = cortes.filter(c => c.tipo === "mes" && String(c.desde) <= hoy).sort((x, y) => String(y.desde).localeCompare(String(x.desde)));
    return meses.find(c => String(c.corte) >= hoy) || meses[0] || null;
  }
  function resolverPeriodo() {
    const cortes = S.est.cortes;
    if (S.est.periodo === "hoy" && !enBalance()) { S.est.periodo = null; S.est.avisoHoy = true; }
    const { lista } = periodosOfrecidos(cortes);
    if (!lista.some(c => c.periodo === S.est.periodo)) {
      const m = mesPorRegla(cortes);
      S.est.periodo = m ? m.periodo : (lista[0] || cortes[0]).periodo;
    }
    return cortes.find(c => c.periodo === S.est.periodo) || cortes[0];
  }
  function barraHTML(cortes, corte) {
    const { lista, escondidos } = periodosOfrecidos(cortes);
    return `<section class="ct-card ct-est-barra" id="ct-est-barra" aria-busy="false">
      <div class="ct-chips ct-est-subs" aria-label="Qué estado">${Object.keys(SUBS).map(k => `<button type="button" class="ct-chip" data-sub="${k}" aria-pressed="${k === S.est.sub ? "true" : "false"}">${esc(SUBS[k])}</button>`).join("")}</div>
      <div class="ct-chips ct-est-periodos" id="ct-est-periodos" aria-label="Qué período">${lista.map(c => `<button type="button" class="ct-chip chica" data-periodo="${esc(c.periodo)}" aria-pressed="${c.periodo === S.est.periodo ? "true" : "false"}">${esc(nombrePeriodo(c))}</button>`).join("")}${escondidos > 0 || S.est.todos ? `<button type="button" class="ct-chip chica" id="ct-est-mas">${S.est.todos ? "Menos períodos" : "Más períodos"}</button>` : ""}</div>
      <p class="ct-est-ctx" id="ct-est-ctx"><span class="ct-num">${esc(rangoTexto(corte, enBalance()))}</span><span id="ct-est-ctx-n" class="ct-num"></span> ${cortePill(corte)}${S.est.avisoHoy ? `<span class="ct-sub">«Hoy» solo vale para el balance: se enseña el mes completo.</span>` : ""}</p>
    </section>`;
  }
  function engancharBarra() {
    const b = $("ct-est-barra"); if (!b) return;
    b.querySelectorAll("[data-sub]").forEach(x => x.addEventListener("click", () => ir("estados", { sub: x.dataset.sub })));
    b.querySelectorAll("[data-periodo]").forEach(x => x.addEventListener("click", () => ir("estados", { periodo: x.dataset.periodo })));
    const mas = $("ct-est-mas"); if (mas) mas.addEventListener("click", () => { S.est.todos = !S.est.todos; pintarEstados(); });
    b.querySelectorAll('.ct-chips [aria-pressed="true"]').forEach(x => { if (typeof x.scrollIntoView === "function") x.scrollIntoView({ inline: "nearest", block: "nearest" }); });
    chipsOcupados(true);
  }

  async function pintarEstados() {
    const mia = ++S.est.serie;
    if (!navigator.onLine) return sinSenal(pintarEstados);
    // la caché de v_cortes vale un día: la fila 'hoy' trae la fecha de Miami, y el control y el balance de «hoy» ya corren con el día real
    if (S.est.cortes && S.est.cortesDia !== hoyMiami()) S.est.cortes = null;
    if (!S.est.cortes) {
      cargando("Controlando con la base…");
      try {
        const c = await DB._leer("v_cortes?select=periodo,tipo,anio,desde,corte,estado,paralelo&order=desde.desc,tipo.asc");
        if (mia !== S.est.serie) return;
        if (!Array.isArray(c) || !c.length) {
          // El equipo recibe [] con 200 de toda vista: el control dice si es «solo dueño» (42501) o si de verdad no hay períodos
          await controlarEstados("hoy", ["v_cortes"]);
          throw errorControl("La base no tiene períodos", [{ vista: "v_cortes", filas: 0, esperadas: "1 o más", detalle: "v_cortes no devolvió ningún período: el libro no está abierto todavía (c2 siembra los períodos). Nada que pintar." }]);
        }
        S.est.cortes = c; S.est.cortesDia = hoyMiami();
      } catch (err) {
        if (mia !== S.est.serie) return;
        return pintarError(err, () => { S.est.cortes = null; pintarEstados(); }, err.codigo === "42501" ? "Contabilidad es solo del dueño" : undefined);
      }
    }
    if (mia !== S.est.serie || S.pagina !== "estados") return;
    const corte = resolverPeriodo();
    if (!S.est.cuenta && !S.est.asiento) S.hooks.titulo(KICKER, TITULOS.estados);
    main().innerHTML = barraHTML(S.est.cortes, corte) + `<div id="ct-est-cuerpo"></div>`;
    engancharBarra();
    S.est.avisoHoy = false;
    if (S.est.asiento) return pintarAsiento(S.est.asiento, corte, mia);
    if (S.est.cuenta) return pintarMayor(S.est.cuenta, corte, mia);
    const pinta = ({ resultados: pintarResultados, balance: pintarBalance, balanza: pintarBalanza, flujo: pintarFlujo, comparacion: pintarComparacion })[S.est.sub] || pintarResultados;
    return pinta(corte, mia);
  }

  // ---------- Estado de resultados ----------
  function varHTML(f) {
    const v = num(f.variacion);
    const hay = v != null && !Number.isNaN(v) && v !== 0;
    const ico = hay ? (v > 0 ? ICO.arriba : ICO.abajo) : "";
    const clase = hay ? (((v > 0) === !!FAVORABLE_MAS[f.seccion]) ? " fav" : " desfav") : "";
    return `<span class="ct-var${clase}">${ico}${fmtSigno(f.variacion)}</span>${f.variacion_pct == null ? "" : `<small class="ct-sub ct-num">${fmtPct(f.variacion_pct)}</small>`}`;
  }
  async function pintarResultados(corte, mia) {
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let ctrl, filas;
    try {
      [ctrl, filas] = await Promise.all([
        controlarEstados(periodo, VISTAS_SUB.resultados),
        DB._leer(`v_resultados?select=nivel,seccion,seccion_orden,linea,linea_orden,orden,cuenta,etiqueta_es,mes,mes_anterior,variacion,variacion_pct,acumulado,acumulado_desde,posteriores,acumulado_ajustado,asientos,desde,hasta,anio,periodo_tipo&periodo=eq.${P()}&order=seccion_orden.asc,linea_orden.asc,orden.asc`)
      ]);
      if (!vivo(mia)) return;
      cotejar(ctrl, { v_resultados: filas.length });
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    const anio = corte.tipo === "anio";
    if (!filas.length) {
      const ap = S.est.cortes.find(c => c.tipo === "apertura");
      const txt = corte.tipo === "apertura" ? `La apertura no tiene estado de resultados: es la foto del ${fechaLarga(corte.corte)}, no un mes.`
        : `${nombrePeriodo(corte)} no tiene asientos de resultados en el libro.${ap && Number(corte.anio) === Number(ap.anio) ? ` Los ingresos y gastos de enero a ${MES_LARGO[partes(ap.corte)[1]] || ""} están en QuickBooks; el libro empieza el ${fechaLarga(diaSiguiente(ap.corte))}.` : ""}`;
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-resultados">${cabHTML(H2.resultados)}${vacioHTML(txt, "v_resultados")}</section>`;
      return;
    }
    const total = l => filas.find(f => f.nivel === "total" && f.linea === l);
    const secIng = filas.find(f => f.nivel === "seccion" && f.seccion === "ingresos");
    const neta = total("utilidad_neta"), bruta = total("utilidad_bruta");
    const conAjustes = filas.some(f => num(f.acumulado_ajustado) !== num(f.acumulado));
    const sinAnterior = filas.every(f => f.mes_anterior == null);
    const colMes = anio ? "Año" : "Mes", colAnt = anio ? "Año anterior" : "Mes anterior";
    const celda = (v, col) => `<td class="r ct-num${cero(v)}" data-col="${col}">${fmtNeg(v)}</td>`;
    const cifras = f => `${celda(f.mes, colMes)}${celda(f.mes_anterior, colAnt)}<td class="r ct-num" data-col="Variación">${varHTML(f)}</td>${celda(f.acumulado, "Acumulado")}${conAjustes ? celda(f.acumulado_ajustado, "Con ajustes") : ""}`;
    const nCols = conAjustes ? 6 : 5;
    // clave de orden del estado: los totales se intercalan por linea_orden (250 bruta, 350 operación, 600 neta)
    const bloques = filas.filter(f => f.nivel === "seccion").map(f => ({ clave: nOrd(f.seccion_orden), f, tipo: "seccion" }))
      .concat(filas.filter(f => f.nivel === "total").map(f => ({ clave: nOrd(f.linea_orden), f, tipo: "total" })))
      .sort((x, y) => x.clave - y.clave);
    const tabla = bloques.map(b => {
      if (b.tipo === "total") {
        const perdida = b.f.linea === "utilidad_neta" && num(b.f.mes) < 0;
        return `<tr class="ct-total${b.f.linea === "utilidad_neta" ? " ct-neto" : ""}"><td>${esc(perdida ? "Pérdida neta" : b.f.etiqueta_es)}</td>${cifras(b.f)}</tr>`;
      }
      const sec = b.f;
      const hijas = porClaves(filas.filter(f => f.seccion === sec.seccion && (f.nivel === "linea" || f.nivel === "cuenta")).map(f => ({ ...f, _n: f.nivel === "linea" ? 0 : 1 })), ["linea_orden", "_n", "orden"]);
      const conLinea = new Set(hijas.filter(f => f.nivel === "linea").map(f => f.linea));
      return `<tr class="ct-sec"><td colspan="${nCols}">${esc(sec.etiqueta_es)}</td></tr>` +
        hijas.map(f => f.nivel === "linea"
          ? `<tr class="ct-linea"><td>${esc(f.etiqueta_es)}</td>${cifras(f)}</tr>`
          : `<tr class="ct-fila-cuenta${conLinea.has(f.linea) ? " hondo" : ""}"><td>${cuentaBtn(f.cuenta, f.etiqueta_es)}</td>${cifras(f)}</tr>`).join("") +
        `<tr class="ct-subtotal"><td>Total ${esc(minus(sec.etiqueta_es))}</td>${cifras(sec)}</tr>`;
    }).join("");
    const c56 = ctrl.find(f => f.vista === "cuadre: resultado del estado = resultado del balance");
    const franja = c56 && c56.ok === true ? `<div class="ct-cuadre">${ICO.check} Cuadra · la utilidad neta es la misma que trae el balance</div>` : "";
    const notas = [];
    if (sinAnterior) {
      if (anio) notas.push("Sin año anterior en el libro.");
      else { const [a, m] = partes(corte.desde); const mp = m === 1 ? 12 : m - 1, ap = m === 1 ? a - 1 : a; const desdeLibro = (neta || filas[0]).acumulado_desde; notas.push(`Sin mes anterior en el libro: ${MES_LARGO[mp]} de ${ap} está en QuickBooks (el libro empieza el ${fechaLarga(desdeLibro)}).`); }
    }
    if (!conAjustes) notas.push("Sin ajustes posteriores del CPA en este período.");
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-resultados">${cabHTML(H2.resultados)}${franja}
      <div class="ct-kpis cuatro">
        ${kpiHTML(anio ? "Ingresos del año" : "Ingresos del mes", fmtNeg(secIng && secIng.mes))}
        ${kpiHTML("Utilidad bruta", fmtNeg(bruta && bruta.mes))}
        ${kpiHTML(neta && num(neta.mes) < 0 ? "Pérdida neta" : "Utilidad neta", fmtNeg(neta && neta.mes))}
        ${kpiHTML("Acumulado del año", fmtNeg(neta && neta.acumulado), neta && neta.acumulado_desde ? `desde el ${fechaLarga(neta.acumulado_desde)}` : "")}
      </div>
      <div class="ct-tabla-env"><table class="ct-tabla ct-est-tabla"><thead><tr><th>Cuenta</th><th class="r">${colMes}</th><th class="r">${colAnt}</th><th class="r">Variación</th><th class="r">Acumulado</th>${conAjustes ? `<th class="r">Con ajustes</th>` : ""}</tr></thead><tbody>${tabla}</tbody></table></div>
      ${notas.map(n => `<p class="ct-nota">${esc(n)}</p>`).join("")}
      <p class="ct-nota">${esc(notaFuente(["v_resultados", "v_balance_general (el cuadre)"], corte))}</p>
    </section>`;
    engancharBotones();
  }

  // ---------- Balance general ----------
  async function pintarBalance(corte, mia) {
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let ctrl, filas;
    try {
      [ctrl, filas] = await Promise.all([
        controlarEstados(periodo, VISTAS_SUB.balance),
        DB._leer(`v_balance_general?select=nivel,seccion,seccion_orden,linea,linea_orden,orden,cuenta,componente,etiqueta_es,saldo,cifra,saldo_ajustado,cifra_ajustada,asientos,cuadra,corte,periodo_tipo&periodo=eq.${P()}&order=seccion_orden.asc,linea_orden.asc,orden.asc`)
      ]);
      if (!vivo(mia)) return;
      cotejar(ctrl, { v_balance_general: filas.length });
      if (filas.length) {
        const q = filas.find(f => f.nivel === "total" && f.linea === "cuadra");
        if (!q || q.cuadra !== true) throw errorControl("El balance no cuadra", [{ vista: "v_balance_general", filas: q ? fmtNeg(q.cifra) : "—", esperadas: "$0.00", detalle: q ? `Activo menos pasivo y capital da ${fmtNeg(q.cifra)} (ajustado ${fmtNeg(q.cifra_ajustada)}): no se pinta un balance descuadrado.` : "La vista no trajo la fila 'cuadra'." }]);
      }
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    if (!filas.length) {
      const ap = S.est.cortes.find(c => c.tipo === "apertura");
      const [a, m, d] = ap ? partes(ap.corte) : [];
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-balance">${cabHTML(H2.balance)}${vacioHTML(`El libro todavía no tiene la apertura. El balance sale cuando se postee la balanza de QuickBooks${ap ? ` al ${d} de ${MES_LARGO[m] || ""} de ${a}` : " de la apertura"}.`, "v_balance_general")}</section>`;
      return;
    }
    const total = l => filas.find(f => f.nivel === "total" && f.linea === l);
    const q = total("cuadra"), ta = total("total_activo"), tp = total("total_pasivo"), tc = total("total_capital"), tpc = total("pasivo_mas_capital");
    const efectivo = filas.find(f => f.nivel === "linea" && f.linea === "efectivo");
    const hoy = corte.tipo === "hoy";
    const conAjustes = filas.some(f => num(f.cifra_ajustada) !== num(f.cifra));
    if (q && q.asientos != null) ctxN(` · ${plural(q.asientos, "asiento", "asientos")} al corte`); // v_balance_general cuenta todo el libro hasta el corte
    const celda = f => `<td class="r ct-num${cero(f.cifra)}" data-col="Al corte">${fmtNeg(f.cifra)}</td>${conAjustes ? `<td class="r ct-num${cero(f.cifra_ajustada)}" data-col="Con ajustes">${fmtNeg(f.cifra_ajustada)}</td>` : ""}`;
    const nCols = conAjustes ? 3 : 2;
    const totalTR = (f, neto) => f ? `<tr class="ct-total${neto ? " ct-neto" : ""}"><td>${esc(f.etiqueta_es)}</td>${celda(f)}</tr>` : "";
    const secciones = porClaves(filas.filter(f => f.nivel === "seccion" && nOrd(f.seccion_orden) < 9000), ["seccion_orden"]);
    const pintado = {};
    let tabla = "";
    for (const sec of secciones) {
      for (const k of Object.keys(CIERRA)) if (!pintado[k] && nOrd(sec.seccion_orden) >= CIERRA[k]) { tabla += totalTR(total(k)); pintado[k] = true; }
      const det = filas.filter(f => f.seccion === sec.seccion && ["linea", "cuenta", "componente"].includes(f.nivel));
      const lineas = porClaves([...new Map(det.map(f => [f.linea, { linea: f.linea, linea_orden: f.linea_orden }])).values()], ["linea_orden"]);
      tabla += `<tr class="ct-sec"><td colspan="${nCols}">${esc(sec.etiqueta_es)}</td></tr>`;
      for (const l of lineas) {
        const fl = det.find(f => f.nivel === "linea" && f.linea === l.linea);
        if (fl) tabla += `<tr class="ct-linea"><td>${esc(fl.etiqueta_es)}</td>${celda(fl)}</tr>`;
        for (const f of porClaves(det.filter(f => f.linea === l.linea && f.nivel !== "linea"), ["orden"])) {
          tabla += f.nivel === "cuenta"
            ? `<tr class="ct-fila-cuenta${fl ? " hondo" : ""}"><td>${cuentaBtn(f.cuenta, f.etiqueta_es)}</td>${celda(f)}</tr>`
            : `<tr class="ct-componente"><td>${esc(f.etiqueta_es)}</td>${celda(f)}</tr>`;
        }
      }
      // el subtotal de la sección, salvo que sea la misma fila que un total que viene enseguida («Capital» → «Total capital»)
      const etSub = `Total ${minus(sec.etiqueta_es)}`;
      if (!filas.some(f => f.nivel === "total" && String(f.etiqueta_es || "").toLowerCase() === etSub.toLowerCase())) tabla += `<tr class="ct-subtotal"><td>${esc(etSub)}</td>${celda(sec)}</tr>`;
    }
    for (const k of Object.keys(CIERRA)) if (!pintado[k]) tabla += totalTR(total(k));
    tabla += totalTR(tc) + totalTR(tpc, true);
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-balance">${cabHTML(H2.balance)}
      <div class="ct-cuadre">${ICO.check} Cuadra · activo ${fmtNeg(ta && ta.cifra)} ${MENOS} pasivo ${fmtNeg(tp && tp.cifra)} ${MENOS} capital ${fmtNeg(tc && tc.cifra)} = ${fmtNeg(q.cifra)}</div>
      <div class="ct-kpis cuatro">
        ${kpiHTML("Activo", fmtNeg(ta && ta.cifra), `al ${fechaLarga(corte.corte)}`)}
        ${kpiHTML("Pasivo", fmtNeg(tp && tp.cifra))}
        ${kpiHTML("Capital", fmtNeg(tc && tc.cifra))}
        ${kpiHTML("Efectivo", fmtNeg(efectivo && efectivo.cifra), efectivo ? "" : "sin renglón de efectivo")}
      </div>
      <div class="ct-tabla-env"><table class="ct-tabla angosta"><thead><tr><th>Renglón</th><th class="r">Al corte</th>${conAjustes ? `<th class="r">Con ajustes</th>` : ""}</tr></thead><tbody>${tabla}</tbody></table></div>
      ${conAjustes ? "" : `<p class="ct-nota">${hoy ? "Con ajustes del CPA no aplica a “hoy”." : "Sin ajustes posteriores del CPA en este período."}</p>`}
      <p class="ct-nota">${esc(notaFuente(VISTAS_SUB.balance, corte))}</p>
    </section>`;
    engancharBotones();
  }

  // ---------- Balanza de comprobación ----------
  async function pintarBalanza(corte, mia) {
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let ctrl, filas;
    try {
      [ctrl, filas] = await Promise.all([
        controlarEstados(periodo, VISTAS_SUB.balanza),
        DB._leer(`v_balanza?select=nivel,orden,cuenta,cuenta_nombre,componente,etiqueta_es,estado,seccion,linea,saldo_inicial,debe,haber,saldo_final,saldo_en_su_lado,asientos,cuadra,desde,hasta,periodo_tipo&periodo=eq.${P()}&order=orden.asc`)
      ]);
      if (!vivo(mia)) return;
      cotejar(ctrl, { v_balanza: filas.length });
      if (filas.length) {
        const t = filas.find(f => f.nivel === "total");
        if (!t || t.cuadra !== true) throw errorControl("La balanza no cuadra", [{ vista: "v_balanza", filas: t ? `${fmtNeg(t.debe)} / ${fmtNeg(t.haber)}` : "—", esperadas: "debe = haber, saldos 0", detalle: t ? `Saldo inicial ${fmtNeg(t.saldo_inicial)}, debe ${fmtNeg(t.debe)}, haber ${fmtNeg(t.haber)}, saldo final ${fmtNeg(t.saldo_final)}.` : "La vista no trajo la fila 'total'." }]);
      }
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    if (!filas.length) {
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-balanza">${cabHTML(H2.balanza)}${vacioHTML(`Ningún asiento en ${nombrePeriodoMin(corte)}.`, "v_balanza")}</section>`;
      return;
    }
    const t = filas.find(f => f.nivel === "total");
    if (t.asientos != null) ctxN(` · ${plural(t.asientos, "asiento", "asientos")} del período`); // v_balanza cuenta los fechados en el período
    const celda = (v, col, extra) => `<td class="r ct-num${extra || ""}${cero(v)}" data-col="${col}">${fmtNeg(v)}</td>`;
    const cifras = f => celda(f.saldo_inicial, "Saldo inicial") + celda(f.debe, "Debe") + celda(f.haber, "Haber") + celda(f.saldo_final, "Saldo final") + celda(f.saldo_en_su_lado, "En su lado", " ct-lado");
    const tabla = porClaves(filas, ["orden"]).map(f => f.nivel === "total" ? `<tr class="ct-total ct-neto"><td>${esc(f.etiqueta_es || "Totales")}</td>${cifras(f)}</tr>`
      : f.nivel === "componente" ? `<tr class="ct-componente"><td>${esc(f.etiqueta_es)}</td>${cifras(f)}</tr>`
      : `<tr class="ct-fila-cuenta"><td>${cuentaBtn(f.cuenta, f.cuenta_nombre || f.etiqueta_es)}</td>${cifras(f)}</tr>`).join("");
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-balanza">${cabHTML(H2.balanza)}
      <div class="ct-cuadre">${ICO.check} Cuadra · debe ${fmtNeg(t.debe)} = haber ${fmtNeg(t.haber)} · saldo final ${fmtNeg(t.saldo_final)}</div>
      <div class="ct-kpis">
        ${kpiHTML("Movimiento del período", fmtNeg(t.debe), "debe = haber")}
        ${kpiHTML("Asientos", esc(t.asientos == null ? "—" : t.asientos))}
      </div>
      <div class="ct-tabla-env"><table class="ct-tabla ancha"><thead><tr><th>Cuenta</th><th class="r">Saldo inicial</th><th class="r">Debe</th><th class="r">Haber</th><th class="r">Saldo final</th><th class="r">En su lado</th></tr></thead><tbody>${tabla}</tbody></table></div>
      <p class="ct-nota">Saldo final = inicial + debe − haber, calculado por la base. “En su lado” es el saldo como se lee en su estado (una contra-cuenta sale negativa). Toca una cuenta para ver su mayor.</p>
      <p class="ct-nota">${esc(notaFuente(VISTAS_SUB.balanza, corte))}</p>
    </section>`;
    engancharBotones();
  }

  // ---------- El mayor de una cuenta (saldo corrido por la base) ----------
  async function pintarMayor(cuenta, corte, mia) {
    S.hooks.titulo(KICKER, `Mayor · ${cuenta}`);
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    const fp = corte.tipo === "anio" ? `&anio=eq.${encodeURIComponent(corte.anio)}` : `&periodo=eq.${P()}`;
    let filas, b, ajeno;
    try {
      const [, m, bs] = await Promise.all([
        controlarEstados(periodo, ["v_mayor"]),
        DB._leer(`v_mayor?select=asiento_id,numero,orden,fecha,descripcion,memo,camino,tipo,origen_tabla,monto,debe,haber,saldo,saldo_en_su_lado,reversado,proyecto_id,cadena_pos,ejercicio,cuenta_nombre,saldo_normal&cuenta=eq.${encodeURIComponent(cuenta)}${fp}&order=fecha.asc,cadena_pos.asc,orden.asc`),
        DB._leer(`v_balanza?select=cuenta,cuenta_nombre,estado,saldo_inicial,debe,haber,saldo_final,saldo_en_su_lado,asientos&periodo=eq.${P()}&cuenta=eq.${encodeURIComponent(cuenta)}`)
      ]);
      if (!vivo(mia)) return;
      filas = m; b = Array.isArray(bs) && bs.length ? bs[0] : null;
      // un ajuste del CPA de otro ejercicio se lista aquí pero corre con el saldo de su año (v_mayor particiona por ejercicio)
      ajeno = filas.some(f => f.tipo === "ajuste_cpa" && Number(f.ejercicio) !== Number(corte.anio));
      const ultima = filas[filas.length - 1];
      if (b && ultima && num(ultima.saldo) !== num(b.saldo_final) && !ajeno) {
        throw errorControl("El mayor no termina donde dice la balanza", [{ vista: "v_mayor", filas: fmtNeg(ultima.saldo), esperadas: fmtNeg(b.saldo_final), detalle: `cuenta ${cuenta} · ${nombrePeriodo(corte)}` }]);
      }
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    const nombre = b ? b.cuenta_nombre : filas[0] ? filas[0].cuenta_nombre : nombreCuenta(cuenta);
    S.hooks.titulo(KICKER, `Mayor · ${cuenta} ${nombre}`);
    // v_balanza guarda el saldo inicial con signo debe − haber; la columna va «en su lado» (como v_mayor.saldo_en_su_lado), así que
    // se le aplica el lado de la cuenta: lo dice v_mayor (saldo_normal) y, sin movimientos, el signo de saldo_en_su_lado contra saldo_final
    const lado = filas[0] ? (filas[0].saldo_normal === "haber" ? -1 : 1)
      : (b && num(b.saldo_final) && num(b.saldo_en_su_lado)) ? Math.sign(num(b.saldo_en_su_lado)) * Math.sign(num(b.saldo_final)) : 1;
    const trae = b && b.saldo_inicial != null ? fmtNeg((num(b.saldo_inicial) * lado) || 0) : null;
    const volver = `<div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-est-volver">‹ ${esc(SUBS[S.est.sub] || "Estados")}</button></div>`;
    if (!filas.length) {
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-mayor">${cabHTML(`${cuenta} · ${nombre}`)}${vacioHTML(`La cuenta ${cuenta} no tiene movimientos en ${nombrePeriodoMin(corte)}. Saldo que trae: ${trae || "sin saldo anterior"}.`, "v_mayor")}${volver}</section>`;
      engancharBotones();
      return;
    }
    const ultima = filas[filas.length - 1];
    // sin fila en la balanza (una cuenta de resultados cuyas únicas líneas son ajustes del CPA de otro ejercicio), el saldo corrido no es el de este período
    const sinBalanza = !b && ajeno;
    const aviso = b && num(ultima.saldo) !== num(b.saldo_final)
      ? `<p class="ct-aviso warn">El mayor termina en ${fmtNeg(ultima.saldo)} y la balanza dice ${fmtNeg(b.saldo_final)}: un ajuste del CPA de otro ejercicio se lista aquí pero corre con el saldo de su año.</p>`
      : sinBalanza ? `<p class="ct-aviso warn">La balanza de ${esc(nombrePeriodoMin(corte))} no trae la cuenta ${esc(cuenta)}: sus líneas son ajustes del CPA de otro ejercicio y corren con el saldo de su año, no con el de este período.</p>` : "";
    const alCorte = sinBalanza ? "—" : fmtNeg(b ? b.saldo_en_su_lado : ultima.saldo_en_su_lado);
    const celda = (v, col) => `<td class="r ct-num${cero(v)}" data-col="${col}">${fmtNeg(v)}</td>`;
    // sin colspan ni columna pegajosa: en el teléfono la tabla se apila (fecha, asiento y descripción arriba; debe, haber y saldo debajo)
    const tabla = `<tr class="ct-trae"><td>Saldo que trae</td><td class="r ct-num" data-col="Debe">—</td><td class="r ct-num" data-col="Haber">—</td><td class="r ct-num ct-lado" data-col="Saldo">${trae || "—"}</td></tr>` +
      filas.map(f => `<tr><td><span class="ct-num">${fechaLarga(f.fecha)}</span> ${asientoBtn(f.asiento_id, f.numero)} ${esc(f.descripcion || "")}${f.reversado ? ` ${pill("reversado", "warn")}` : ""}<small>${[f.memo, CAMINO[f.camino] || f.camino, f.proyecto_id].filter(Boolean).map(esc).join(" · ")}</small></td>${celda(f.debe, "Debe")}${celda(f.haber, "Haber")}<td class="r ct-num ct-lado" data-col="Saldo">${fmtNeg(f.saldo_en_su_lado)}</td></tr>`).join("") +
      `<tr class="ct-total ct-neto"><td>Saldo al ${fecha(corte.corte)}</td><td></td><td></td><td class="r ct-num ct-lado" data-col="Saldo">${alCorte}</td></tr>`;
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-mayor">${cabHTML(`${cuenta} · ${nombre}`)}${aviso}
      <div class="ct-kpis tres">
        ${kpiHTML("Saldo que trae", trae || "—", trae ? "en su lado" : "sin saldo anterior")}
        ${kpiHTML(`Saldo al ${fecha(corte.corte)}`, alCorte, sinBalanza ? "sin fila en la balanza" : "en su lado")}
        ${kpiHTML("Asientos", esc(b && b.asientos != null ? b.asientos : new Set(filas.map(f => f.asiento_id)).size))}
      </div>
      <div class="ct-tabla-env"><table class="ct-tabla ct-est-tabla tres"><thead><tr><th>Movimiento</th><th class="r">Debe</th><th class="r">Haber</th><th class="r">Saldo</th></tr></thead><tbody>${tabla}</tbody></table></div>
      <p class="ct-nota">Fuente: v_mayor (saldo corrido por la base) · v_balanza para lo que trae · fn_estados_control · ${esc(nombrePeriodo(corte))}. Toca un asiento para verlo con sus líneas y su papel.</p>
      ${volver}
    </section>`;
    engancharBotones();
  }

  // ---------- Un asiento con sus líneas y su papel ----------
  async function pintarAsiento(id, corte, mia) {
    S.hooks.titulo(KICKER, "Asiento");
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let lineas, papel, url = null, errFoto = null;
    try {
      const [, ls, ps] = await Promise.all([
        controlarEstados(periodo, ["v_libro", "v_asiento_papel"]),
        DB._leer(`v_libro?select=asiento_id,numero,orden,fecha,periodo,tipo,camino,descripcion,motivo,reversa_a,sustituye_a,origen_tabla,origen_id,documento_ruta,cuenta,cuenta_nombre,debe,haber,monto,memo,proyecto_id,cost_code,tercero_tipo,tercero_id,partida_tabla,partida_id&asiento_id=eq.${encodeURIComponent(id)}&order=orden.asc`),
        DB._leer(`v_asiento_papel?select=*&asiento_id=eq.${encodeURIComponent(id)}`),
        proyectos().catch(() => null) // el nombre de la obra de cada línea; si no llega, se enseña el id
      ]);
      if (!vivo(mia)) return;
      if (!Array.isArray(ls) || ls.length < 2) throw errorControl("El asiento no apareció entero", [{ vista: "v_libro", filas: Array.isArray(ls) ? ls.length : 0, esperadas: "2 o más", detalle: id }]);
      if (!Array.isArray(ps) || ps.length !== 1) throw errorControl("El papel del asiento no apareció", [{ vista: "v_asiento_papel", filas: Array.isArray(ps) ? ps.length : 0, esperadas: 1, detalle: id }]);
      lineas = ls; papel = ps[0];
      if (papel.papel_ruta && papel.origen_tabla === "recibos" && typeof DB.firmarFotos === "function") {
        try { url = (await DB.firmarFotos([papel.papel_ruta]))[papel.papel_ruta] || null; if (!url) errFoto = new Error("la base no firmó la ruta"); }
        catch (e) { errFoto = e; } // la foto es lo último: si Storage no contesta, el asiento y su papel se pintan igual, con el aviso
        if (!vivo(mia)) return;
      }
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    const a = lineas[0];
    S.hooks.titulo(KICKER, `Asiento ${a.numero}`);
    const obra = pid => { const p = (S.proyectos || []).find(x => x.id === pid); return p ? p.nombre : (pid || ""); };
    const celda = (v, col) => `<td class="r ct-num${cero(v)}" data-col="${col}">${fmtNeg(v)}</td>`;
    // en el teléfono la tabla se apila: la cuenta arriba, la obra en su renglón y debe | haber debajo (data-col pone las etiquetas)
    const tabla = lineas.map(l => { const o = obra(l.proyecto_id); return `<tr><td>${cuentaBtn(l.cuenta, l.cuenta_nombre)}<small>${[l.memo, l.tercero_tipo || l.tercero_id ? `${l.tercero_tipo || ""} ${l.tercero_id || ""}`.trim() : "", l.cost_code].filter(Boolean).map(esc).join(" · ")}</small></td><td class="ct-obra"${o ? ` data-col="Obra"` : ""}>${esc(o)}</td>${celda(l.debe, "Debe")}${celda(l.haber, "Haber")}</tr>`; }).join("");
    const camino = CAMINO[a.camino] || a.camino || "";
    const ruta = papel.papel_ruta || "";
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-asiento">
      <div class="ct-cab"><h2>Asiento <span class="ct-num">${esc(a.numero)}</span> · ${fechaLarga(a.fecha)}</h2>${pillIco(ICO.check, "Controlado", "ok")}${pill(camino)}${TIPO_AS[a.tipo] ? pill(TIPO_AS[a.tipo]) : ""}${papel.reversado ? pill("Reversado", "warn") : ""}</div>
      <p class="ct-texto">${esc(a.descripcion || "")}</p>
      ${a.motivo ? `<p class="ct-nota">Motivo: ${esc(a.motivo)}</p>` : ""}
      ${a.reversa_a ? `<p class="ct-nota">Reversa al asiento ${asientoBtn(a.reversa_a, "ver")}</p>` : ""}
      <div class="ct-tabla-env"><table class="ct-tabla ct-est-tabla"><thead><tr><th>Cuenta</th><th>Obra</th><th class="r">Debe</th><th class="r">Haber</th></tr></thead><tbody>${tabla}</tbody></table></div>
      <p class="ct-nota">${plural(lineas.length, "línea", "líneas")} · la base solo acepta asientos con debe = haber (candado de c2).</p>
      <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-est-volver">‹ ${S.est.cuenta ? `Mayor ${esc(S.est.cuenta)}` : esc(SUBS[S.est.sub] || "Estados")}</button></div>
    </section>
    <section class="ct-card ct-noche" id="ct-est-papel">
      <p class="ct-noche-lbl">Papel</p>
      <p class="ct-noche-txt">${esc(papel.papel || "")}</p>
      <p class="ct-noche-meta">Camino: ${esc(camino)} · <span class="ct-num">${fechaLarga(a.fecha)}</span>${papel.origen_tabla ? ` · ${esc(papel.origen_tabla)} <span class="ct-num">${esc(papel.origen_id || "")}</span>` : ""}</p>
      ${papel.papel_existe === false ? `<p class="ct-aviso bad">El papel de este asiento ya no está: rastro roto.</p>` : ""}
      ${url ? `<a class="accion secundaria ct-noche-btn" id="ct-est-papel-foto" href="${esc(url)}" target="_blank" rel="noopener">Ver la foto del recibo</a>` : ""}
      ${errFoto ? `<p class="ct-aviso warn">La foto no se pudo abrir ahora (${esFalloDeRed(errFoto) ? "sin señal hacia Storage" : esc(errFoto.message)}). Ruta: <span class="ct-num">${esc(ruta)}</span></p>` : ""}
      ${ruta.startsWith("docs/") ? `<p class="ct-noche-meta">Documento: <span class="ct-num">${esc(ruta)}</span></p>` : ""}
      ${!ruta && papel.origen_tabla ? `<p class="ct-noche-meta">Se ve en la app: ${esc(papel.origen_tabla)} ${esc(papel.origen_id || "")}</p>` : ""}
    </section>
    <p class="ct-nota">Fuente: v_libro · v_asiento_papel · fn_estados_control</p>`;
    engancharBotones();
  }

  // ---------- Flujo de caja (los dos métodos vienen en la misma vista) ----------
  async function pintarFlujo(corte, mia) {
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let ctrl, filas;
    try {
      [ctrl, filas] = await Promise.all([
        controlarEstados(periodo, VISTAS_SUB.flujo),
        DB._leer(`v_flujo_caja?select=metodo,nivel,seccion,seccion_orden,linea,linea_orden,etiqueta_es,importe,asientos,cuadra,desde,hasta,periodo_tipo&periodo=eq.${P()}&order=metodo.asc,seccion_orden.asc,linea_orden.asc`)
      ]);
      if (!vivo(mia)) return;
      cotejar(ctrl, { v_flujo_caja: filas.length });
      const malos = filas.filter(f => f.nivel === "control" && f.cuadra !== true);
      if (malos.length) throw errorControl("El flujo de caja no cuadra", malos.map(c => ({ vista: `v_flujo_caja · ${c.metodo} · ${c.linea}`, filas: fmtNeg(c.importe), esperadas: "$0.00", detalle: c.etiqueta_es })));
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    if (!filas.length) {
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-flujo">${cabHTML(H2.flujo)}${vacioHTML(corte.tipo === "apertura" ? `La apertura no es un flujo: es la foto del ${fechaLarga(corte.corte)}.` : `Sin movimientos de dinero en ${nombrePeriodoMin(corte)}: ni entró ni salió efectivo.`, "v_flujo_caja")}</section>`;
      return;
    }
    const fin = filas.find(f => f.nivel === "total" && f.linea === "efectivo_final");
    if (fin && fin.asientos != null) ctxN(` · ${plural(fin.asientos, "asiento", "asientos")} con dinero`); // v_flujo_caja cuenta solo los que tocan efectivo
    pintarFlujoTarjeta(filas, corte);
  }
  function pintarFlujoTarjeta(filas, corte) {
    if (!["directo", "indirecto"].includes(S.est.metodo)) S.est.metodo = "directo";
    const m = filas.filter(f => f.metodo === S.est.metodo);
    const total = l => m.find(f => f.nivel === "total" && f.linea === l);
    const ini = total("efectivo_inicial"), cam = total("cambio"), fin = total("efectivo_final");
    const subIni = ini && /\(/.test(ini.etiqueta_es || "") ? esc(ini.etiqueta_es.slice(ini.etiqueta_es.indexOf("(") + 1).replace(/\)\s*$/, "")) : "";
    const celda = v => `<td class="r ct-num${cero(v)}" data-col="Importe">${fmtSigno(v)}</td>`;
    let tabla = "";
    for (const sec of porClaves(m.filter(f => f.nivel === "seccion" && nOrd(f.seccion_orden) < 9000), ["seccion_orden"])) {
      const lineas = porClaves(m.filter(f => f.nivel === "linea" && f.seccion === sec.seccion && f.linea !== f.seccion), ["linea_orden"]);
      const revela = sec.importe == null; // sin_dinero: se revela, no suma
      if (!lineas.length) { tabla += `<tr class="ct-subtotal"><td>${esc(sec.etiqueta_es)}</td>${revela ? `<td class="r ct-num">—</td>` : celda(sec.importe)}</tr>`; continue; }
      tabla += `<tr class="ct-sec"><td colspan="2">${esc(sec.etiqueta_es)}</td></tr>` +
        lineas.map(f => `<tr${revela ? ` class="ct-componente"` : ""}><td>${esc(f.etiqueta_es)}</td>${celda(f.importe)}</tr>`).join("") +
        (revela ? "" : `<tr class="ct-subtotal"><td>Total ${esc(minus(sec.etiqueta_es))}</td>${celda(sec.importe)}</tr>`);
    }
    for (const t of porClaves(m.filter(f => f.nivel === "total"), ["linea_orden"])) tabla += `<tr class="ct-total${t.linea === "efectivo_final" ? " ct-neto" : ""}"><td>${esc(t.etiqueta_es)}</td>${t.linea === "cambio" ? celda(t.importe) : `<td class="r ct-num${cero(t.importe)}" data-col="Importe">${fmtNeg(t.importe)}</td>`}</tr>`;
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-flujo">${cabHTML(H2.flujo)}
      <div class="ct-cuadre">${ICO.check} Cuadra · cambio en el efectivo ${fmtSigno(cam && cam.importe)} = efectivo al final ${fmtNeg(fin && fin.importe)} ${MENOS} al inicio ${fmtNeg(ini && ini.importe)} · igual por los dos métodos</div>
      <div class="ct-chips ct-est-metodos" aria-label="Método">${["directo", "indirecto"].map(k => `<button type="button" class="ct-chip chica" data-metodo="${k}" aria-pressed="${k === S.est.metodo ? "true" : "false"}">${cap(k)}</button>`).join("")}</div>
      <div class="ct-kpis tres">
        ${kpiHTML("Efectivo al inicio", fmtNeg(ini && ini.importe), subIni)}
        ${kpiHTML("Cambio en el efectivo", fmtSigno(cam && cam.importe))}
        ${kpiHTML("Efectivo al final", fmtNeg(fin && fin.importe))}
      </div>
      <div class="ct-tabla-env"><table class="ct-tabla angosta"><thead><tr><th>Renglón</th><th class="r">Importe</th></tr></thead><tbody>${tabla}</tbody></table></div>
      <p class="ct-nota">Positivo = dinero que entra; negativo, que sale. Un 0.00 es un renglón sin movimiento, no un vacío.</p>
      <p class="ct-nota">Fuente: v_flujo_caja (método ${esc(S.est.metodo)}) · controlada con fn_estados_control · ${esc(nombrePeriodo(corte))}</p>
    </section>`;
    cuerpo().querySelectorAll("[data-metodo]").forEach(b => b.addEventListener("click", () => { S.est.metodo = b.dataset.metodo; pintarFlujoTarjeta(filas, corte); }));
  }

  // ---------- Comparación con QuickBooks ----------
  function estadoComparacion(f) {
    if (f.nivel === "sin_mapeo") return pillIco(ICO.equis, "Sin mapeo", "bad");
    if (f.ok === true) return num(f.diferencia) === 0 ? pillIco(ICO.check, "Igual", "ok") : pillIco(ICO.nota, "Explicada", "ok") + `<small class="ct-sub">explicada: ${esc((f.clases || []).join(", "))}</small>`;
    if (Math.abs(num(f.sin_explicar) || 0) < Number(UMBRAL_CENTAVOS)) return pillIco(ICO.aprox, "Centavos", "warn");
    return pillIco(ICO.alerta, "Por explicar", "cu");
  }
  async function pintarComparacion(corte, mia) {
    cargandoEn("Controlando con la base…");
    const periodo = S.est.periodo;
    let ctrl, resumen, filas;
    try {
      [ctrl, resumen, filas] = await Promise.all([
        controlarEstados(periodo, VISTAS_SUB.comparacion),
        DB._leer(`v_comparacion_resumen?select=*&periodo=eq.${P()}`),
        DB._leer(`v_comparacion?select=nivel,orden,cuenta,cuenta_nombre,estado,cuenta_qb,cuentas_qb,libro,arrastre_apertura,posteriores,comparable,qb,diferencia,explicada,sin_explicar,ok,clases,anotadas,asientos,al,documento&periodo=eq.${P()}&order=orden.asc`)
      ]);
      if (!vivo(mia)) return;
      cotejar(ctrl, { v_comparacion: filas.length, v_comparacion_resumen: resumen.length });
    } catch (err) { if (!vivo(mia)) return; return pintarErrorEst(err); }
    chipsOcupados(false);
    if (!filas.length && !resumen.length) {
      // cuándo terminó la marcha en paralelo lo dice v_cortes (paralelo es por período): el último corte con paralelo, sin constantes de año
      const fin = S.est.cortes.filter(c => c.paralelo === true && c.tipo !== "hoy").map(c => String(c.corte)).sort().pop();
      const txt = corte.paralelo === false ? `La marcha en paralelo con QuickBooks terminó${fin ? ` el ${fechaLarga(fin)}` : ""}: la comparación queda para los períodos ${fin ? "hasta esa fecha" : "que marcharon en paralelo"}.`
        : `Todavía no hay balanza de QuickBooks para ${nombrePeriodoMin(corte)}. Cuando el contador cierre el mes y la mandes, la comparación sale aquí cuenta por cuenta.`;
      cuerpo().innerHTML = `<section class="ct-card" id="ct-est-comparacion">${cabHTML(H2.comparacion)}${vacioHTML(txt, "comparacion_qb → v_comparacion")}<p class="ct-nota">La balanza se carga desde el SQL Editor (fn_comparacion_qb_cargar).</p></section>`;
      return;
    }
    const r = resumen[0] || {};
    const anio = corte.tipo === "anio";
    // cuentas_mal cuenta también lo sin mapeo (la vista le pone ok = false): aquí se separan para no leer un problema dos veces
    const nMal = Math.max(0, Number(r.cuentas_mal || 0) - Number(r.sin_mapeo || 0));
    const franja = r.ok === true
      ? `<div class="ct-cuadre">${ICO.check} ${esc(nombrePeriodo(corte))} cuadra con QuickBooks: ${esc(r.cuentas_ok)} cuentas iguales, nada por explicar.</div>`
      : `<div class="ct-cuadre volt">${ICO.alerta} ${nMal} ${nMal === 1 ? "cuenta" : "cuentas"} con diferencia · ${fmtNeg(r.sin_explicar)} sin explicar${Number(r.sin_mapeo) ? ` · ${esc(r.sin_mapeo)} sin mapeo` : ""}</div>`;
    const conArrastre = filas.some(f => num(f.arrastre_apertura) !== 0 && f.arrastre_apertura != null), conPost = filas.some(f => num(f.posteriores) !== 0 && f.posteriores != null);
    const celda = (v, col) => `<td class="r ct-num${cero(v)}" data-col="${col}">${fmtNeg(v)}</td>`;
    const tabla = porClaves(filas, ["orden"]).map(f => {
      const sinMapeo = f.nivel === "sin_mapeo";
      const porExplicar = !sinMapeo && f.ok !== true && Math.abs(num(f.sin_explicar) || 0) >= Number(UMBRAL_CENTAVOS);
      const cuenta = sinMapeo ? `<b>${esc(f.cuenta_qb || "")}</b><small>sin cuenta del plan</small>` : `${cuentaBtn(f.cuenta, f.cuenta_nombre)}${Array.isArray(f.cuentas_qb) && f.cuentas_qb.length ? `<small>${esc(f.cuentas_qb.join(" · "))}</small>` : ""}`;
      return `<tr class="${sinMapeo ? "ct-sinmapeo" : porExplicar ? "ct-porexplicar" : ""}"><td>${cuenta}</td>${conArrastre ? celda(f.arrastre_apertura, "Arrastre apertura") : ""}${conPost ? celda(f.posteriores, "Posteriores") : ""}${celda(f.comparable, "Libro")}${celda(f.qb, "QuickBooks")}${celda(f.diferencia, "Diferencia")}${celda(f.sin_explicar, "Sin explicar")}<td data-col="Estado">${estadoComparacion(f)}</td></tr>`;
    }).join("");
    const doc = filas[0] || {};
    cuerpo().innerHTML = `<section class="ct-card" id="ct-est-comparacion">${cabHTML(H2.comparacion)}${franja}
      <div class="ct-kpis cuatro">
        ${kpiHTML("Cuentas iguales", `${esc(r.cuentas_ok == null ? "—" : r.cuentas_ok)} de ${esc(r.cuentas == null ? "—" : r.cuentas)}`)}
        ${kpiHTML("Sin explicar", fmtNeg(r.sin_explicar))}
        ${kpiHTML(anio ? "Utilidad del año · libro" : "Utilidad del mes · libro", fmtNeg(r.utilidad_mes_libro), r.utilidad_mes_libro == null ? "sin mes anterior con balanza" : "")}
        ${kpiHTML(anio ? "Utilidad del año · QuickBooks" : "Utilidad del mes · QuickBooks", fmtNeg(r.utilidad_mes_qb), `acumulado del año: libro ${fmtNeg(r.utilidad_libro)} · QB ${fmtNeg(r.utilidad_qb)} · diferencia ${fmtSigno(r.utilidad_diferencia)}`)}
      </div>
      ${filas.length ? `<div class="ct-tabla-env"><table class="ct-tabla ct-est-tabla"><thead><tr><th>Cuenta</th>${conArrastre ? `<th class="r">Arrastre apertura</th>` : ""}${conPost ? `<th class="r">Posteriores</th>` : ""}<th class="r">Libro</th><th class="r">QuickBooks</th><th class="r">Diferencia</th><th class="r">Sin explicar</th><th>Estado</th></tr></thead><tbody>${tabla}</tbody></table></div>` : `<p class="ct-vacio">La balanza de QuickBooks no trae ninguna cuenta con saldo.</p>`}
      <p class="ct-nota">Libro = lo del libro más lo que la apertura traía de enero a septiembre, como lo acumula QuickBooks; signo debe − haber “como QuickBooks”: pasivos, capital e ingresos en negativo.</p>
      ${doc.al || doc.documento ? `<p class="ct-nota">Balanza de QuickBooks al ${fechaLarga(doc.al)} · documento <span class="ct-num">${esc(doc.documento || "")}</span></p>` : ""}
      <p class="ct-nota">Las diferencias se explican desde el SQL Editor (fn_diferencia_anotar).</p>
      <p class="ct-nota">${esc(notaFuente(VISTAS_SUB.comparacion, corte))}</p>
    </section>`;
    engancharBotones();
  }

  const PAGINAS = { bancos: pintarBancos, bandeja: pintarBandeja, conciliar: pintarConciliar, movimientos: pintarMovimientos, estados: pintarEstados, cobros: pintarCobros };

  // ---------- Lo que la app llama ----------
  window.MXP_CONTA = {
    // abrir({ titulo(kicker, titulo), avisar(msg, esError) }): pinta la pantalla en #conta-raiz
    abrir(hooks) {
      S.hooks = Object.assign({ titulo() {}, avisar() {} }, hooks || {});
      if (!DB || typeof DB._rpc !== "function" || typeof DB._leer !== "function") {
        const r = raiz();
        if (r) r.innerHTML = `<div class="ct-card ct-rojo" role="alert"><h2>Falta la conexión</h2><p>js/db.js no trae _leer y _rpc: recarga la app (si sigue, la versión de db.js es vieja).</p></div>`;
        return;
      }
      armar();
      ir(S.pagina);
      reanudarLink();
    },
    // «←» de la app: true si la pantalla tenía algo que cerrar (la conciliación abierta, el asiento o el mayor de los estados)
    atras() {
      if (S.conc) { S.conc = null; S.hooks.titulo(KICKER, TITULOS.conciliar); pintarConciliar(); return true; }
      // la bajada de los estados: asiento → mayor → el estado
      if (S.pagina === "estados" && S.est.asiento) { S.est.asiento = null; pintarEstados(); return true; }
      if (S.pagina === "estados" && S.est.cuenta) { S.est.cuenta = null; pintarEstados(); return true; }
      return false;
    },
    ir,
    _estado: S
  };
})();
