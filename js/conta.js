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
    plaid: null, plaidErr: null, mfa: null
  };
  const TITULOS = { bancos: "Bancos y tarjetas", bandeja: "Bandeja del banco", conciliar: "Conciliar", movimientos: "Movimientos" };
  const PESTANAS = { bancos: "Bancos y tarjetas", bandeja: "Bandeja", conciliar: "Conciliar", movimientos: "Movimientos" };
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
  function pintarError(err, reintentar, titulo) {
    if (esFalloDeRed(err) || !navigator.onLine) return sinSenal(reintentar);
    const filas = err.control ? err.control.map(f => `<tr><td>${esc(f.vista)}</td><td class="r ct-num">${f.filas == null ? "—" : esc(f.filas)}</td><td class="r ct-num">${f.esperadas == null ? "—" : esc(f.esperadas)}</td><td>${esc(f.detalle || "")}</td></tr>`).join("") : "";
    main().innerHTML = `<div class="ct-card ct-rojo" role="alert">
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
    } catch (err) { return pintarError(err, pintarBancos); }
    pintarBadge();
    main().innerHTML = importadorHTML(lista) + (S.importe ? importeHTML(S.importe) : "") +
      mfaHTML(S.mfa) + plaidHTML(S.plaid || [], S.plaidErr) +
      `<div class="ct-rejilla">${lista.map(cuentaHTML).join("")}</div>`;
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
    const opciones = (S.saldos || []).filter(s => credito ? s.tipo === "tarjeta" : banco ? s.tipo === "banco" : true);
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
        saldos(), cuentas(), proyectos()
      ]);
      const hoy = hoyMiami();
      await controlar(["v_banco_bandeja"], { v_banco_bandeja: b.filter(f => String(f.fecha) <= hoy).length });
      if (!S.cuentas.length) throw errorControl("El plan de cuentas no se pudo leer", [{ vista: "cuentas", filas: 0, esperadas: "1 o más", detalle: "sin el plan no se puede clasificar nada" }]);
      filas = b;
    } catch (err) { return pintarError(err, pintarBandeja); }
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
      ${m.posible_duplicado_de ? `<p class="ct-aviso warn">Se parece al del ${fecha(m.duplicado_fecha)} «${esc(m.duplicado_descripcion)}»${m.duplicado_origen ? ` (entró por ${esc(m.duplicado_origen)})` : ""}.</p>` : ""}
      <div class="ct-acciones">${ops.map((o, i) => `<button type="button" class="accion${i ? " secundaria" : ""}" data-op="${i}">${esc(o.texto)}</button>`).join("")}
        <button type="button" class="accion secundaria ct-otra" data-otra>Otra cosa…</button></div>
      <div class="ct-form" hidden></div>
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
      const falta = [...ev.target.querySelectorAll("[required]")].find(el => !String(el.value || "").trim());
      if (falta) { mostrarErrorForma(card, "Falta " + (falta.closest("label") ? falta.closest("label").firstChild.textContent.trim().toLowerCase() : "un dato") + "."); return; }
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
        const cs = (S.cuentas || []).filter(c => c.tipo === t);
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
      const otras = (S.saldos || []).filter(c => c.cuenta !== m.cuenta);
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
      const [l] = await Promise.all([DB._leer("v_conciliacion?select=*&order=fecha_corte.desc,cuenta.asc"), saldos()]);
      const hoy = hoyMiami(), desde = hoy.slice(0, 8) + "01";
      await controlar(["v_conciliacion"], { v_conciliacion: l.filter(c => String(c.fecha_corte) >= desde && String(c.fecha_corte) <= hoy).length });
      lista = l;
    } catch (err) { return pintarError(err, pintarConciliar); }
    const sal = S.saldos;
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
      if (!S.movCuenta || !S.saldos.some(c => c.cuenta === S.movCuenta)) S.movCuenta = S.saldos.length ? S.saldos[0].cuenta : null;
      const est = S.movEstado ? `&estado=eq.${encodeURIComponent(S.movEstado)}` : "";
      filas = S.movCuenta ? await DB._leer(`v_banco_movimientos?select=movimiento_id,fecha,monto,descripcion,memo,cheque,tipo_banco,estado,estado_motivo,casado_clase,casado_regla,casado_auto,asiento_numero,papel_tabla,papel_id,archivo,propuesta_motivo&cuenta=eq.${encodeURIComponent(S.movCuenta)}${est}&order=fecha.desc,movimiento_id.asc&limit=300`) : [];
      await controlar(["v_banco_movimientos"]);
    } catch (err) { return pintarError(err, pintarMovimientos); }
    const estados = Object.keys(ESTADO_MOV);
    main().innerHTML = `<section class="ct-card ct-barra">
        <div class="ct-fila">
          <label class="ct-campo">Cuenta<select id="ct-mov-cuenta">${S.saldos.map(c => `<option value="${esc(c.cuenta)}"${c.cuenta === S.movCuenta ? " selected" : ""}>${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
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

  const PAGINAS = { bancos: pintarBancos, bandeja: pintarBandeja, conciliar: pintarConciliar, movimientos: pintarMovimientos };

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
    // «←» de la app: true si la pantalla tenía algo que cerrar (la conciliación abierta)
    atras() {
      if (S.conc) { S.conc = null; S.hooks.titulo(KICKER, TITULOS.conciliar); pintarConciliar(); return true; }
      return false;
    },
    ir,
    _estado: S
  };
})();
