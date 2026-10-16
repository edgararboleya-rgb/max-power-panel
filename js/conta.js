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
// La conexión es la de js/db.js (MXP_DB._leer, MXP_DB._rpc).
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
    importe: null, ocupado: false
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
    } catch (err) { return pintarError(err, pintarBancos); }
    pintarBadge();
    main().innerHTML = importadorHTML(lista) + (S.importe ? importeHTML(S.importe) : "") +
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
