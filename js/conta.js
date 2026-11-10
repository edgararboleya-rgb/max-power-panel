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
// Y la IA contable (c8, fase 7: v_contador_estado, v_contador_bandeja,
// v_contador_control, v_contador_cuentas, v_contador_reglas; la función de
// borde `contador` con la sesión del dueño para proponer, aprobar, clasificar,
// rechazar y quitar reglas): la IA propone en la bandeja y Edgar decide.
// Desde la 7b (31-oct) también propone la obra, con las pistas que calcula la
// base (v_contador_bandeja: obra_propuesta_id, obra_confianza, obra_motivo,
// pistas_resumen), y Edgar la confirma o la cambia. Y desde la 7c (31-oct,
// tarde) las propuestas salen solas (al abrir la Bandeja la pantalla encadena
// las ráfagas; la rutina de la base propone cada mañana y cada tarde), solo
// una obra «fuerte» (≥ 80 %) sale elegida, las demás se eligen de un toque
// entre las de sus pistas (obras_top), y el marcador del mes dice cuánto
// acierta de verdad.
// Y el cierre del mes (c9, fase 8: v_cierre_estado, v_cierres, v_ronda_ultima,
// v_activos_fijos, v_reserva_impuestos, v_dr15_mes; fn_cierre_revisar,
// fn_cierre_cerrar, fn_cierre_export y las de activos, reserva y ajustes): la
// revisión de lo que detiene, el cierre con la confirmación escrita, el
// export al bucket privado «cierres» con su huella, la ronda de cada mañana
// (sus rojos van a «Qué atender»), los activos fijos, la reserva de
// impuestos, el DR-15 y el historial. La cabecera de su sección lo cuenta.
// Y la mano de obra y el costo por obra (c10, fase 9: v_jornal_pendientes,
// v_jornal_repartos, v_jornal_personas, v_jornal_control, v_margen_obra,
// v_margen_control, jornal_config; fn_jornal_propuesta, fn_jornal_aplicar,
// fn_jornal_deshacer, fn_jornal_persona, fn_jornal_config, fn_margen_obra):
// el Zelle a un ayudante sale en la Bandeja como «Mano de obra · persona»,
// repartido por sus horas entre las obras, y la página «Costo por obra» pone
// el estimado contra el real de cada obra, con la mano de obra real y la
// estándar separadas. La cabecera de su sección lo cuenta.
//
// Cómo está organizada (v290, «que se parezca a un programa de contabilidad»):
// una portada («Resumen») con las cifras y lo que hay que atender, y una
// página por tarea: Bancos y tarjetas, Bandeja (el bank feed), Conciliar,
// Movimientos, Estados financieros, Cierre del mes (desde la fase 8), Cobros
// en línea y Conexiones y seguridad
// (el código del teléfono, Plaid y la conexión con Stripe). En el teléfono y
// el iPad las pestañas van arriba; en la computadora las enseña el lateral de
// la app (js/app.js) con MXP_CONTA.paginas() y los hooks pagina() y volver().
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
    pagina: "resumen",
    hooks: { titulo() {}, avisar() {}, pagina() {}, volver() {} },
    saldos: null, cuentas: null, proyectos: null, bandeja: null,
    conc: null, concCuenta: null, movCuenta: null, movEstado: "", filtroCuenta: null,
    importe: null, impAbierto: false, ocupado: false,
    // la bandeja como bank feed: qué se busca, qué motivo, en qué orden, si se agrupa por comercio y qué fila está desplegada
    bj: { q: "", motivo: "", orden: "fecha_asc", agrupar: false, abierta: null, soloJr: false },
    plaid: null, plaidErr: null, mfa: null,
    // Stripe (p1): la fila de v_stripe_estado, por qué no se leyó, la salud de la función, los depósitos asentados (para la bandeja) y la pestaña
    stripe: null, stripeErr: null, stripeSalud: null, stripePayouts: null, cobros: null,
    // la IA contable (c8): lo de la bandeja (estado, propuestas, control, cuentas, salud), lo de Conexiones (con las reglas)
    // y el movimiento cuyo «Según yo» se enfoca después de «No es eso»
    ia: null, iaCx: null, iaCxErr: null, iaFoco: null,
    // (7c) la cadena de ráfagas que propone sola (una a la vez) y lo que recuerda la automática: si Edgar la paró y qué esperaba al terminar
    cadena: null, iaSola: { parada: false, memo: null },
    // Estados financieros: qué estado (sub), qué período, la bajada cuenta → asiento,
    // el método del flujo, la caché de v_cortes (con el día en que se leyó) y la serie contra el doble pintado
    est: { sub: "resultados", periodo: null, cuenta: null, asiento: null, metodo: "directo", cortes: null, cortesDia: null, todos: false, avisoHoy: false, serie: 0 },
    // El cierre del mes (c9): qué apartado (sub), qué período se mira, las filas de v_cierre_estado, la serie contra el doble pintado,
    // el último error del cierre para explicarlo una vez (MX010), qué período se está exportando, el error de su export,
    // y las notas que la base devolvió (la baja de un activo, la depreciación del mes) para enseñarlas tras repintar
    cie: { sub: "cierre", periodo: null, estado: null, serie: 0, error: null, exportando: null, exportErr: {}, notas: {} },
    // (fase 9) el jornal en la Bandeja: si c10 está pegado, los pagos que reconoce (movimiento → su reparto normalizado, el
    // de v_jornal_pendientes o el que Edgar pidió con otras fechas), lo que dijo «No es mano de obra» (solo en memoria), las
    // personas (para el alta desde un movimiento), la configuración, su control y el error si no contestó
    jr: { instalado: false, pend: new Map(), no: new Set(), personas: null, cfg: null, control: null, err: null },
    // «Costo por obra»: qué apartado, qué obra abierta, lo que se baja a sus asientos, el buscador, el filtro y la serie
    obras: { sub: "obras", sel: null, bajar: null, q: "", filtro: "activas", serie: 0, piezas: [] }
  };
  // Las páginas, en el orden del menú. TITULOS va en el membrete de la app y en el lateral; PESTANAS, corto, en las pestañas del teléfono
  // (fase 8) «Cierre del mes» va después de los estados: es lo último del mes, con lo de arriba ya hecho
  // (fase 9) «Costo por obra» va junto a los estados: es el otro informe que sale del libro
  const ORDEN = ["resumen", "bancos", "bandeja", "conciliar", "movimientos", "estados", "obras", "cierre", "cobros", "conexiones"];
  const TITULOS = { resumen: "Resumen", bancos: "Bancos y tarjetas", bandeja: "Bandeja", conciliar: "Conciliar", movimientos: "Movimientos", estados: "Estados financieros", obras: "Costo por obra", cierre: "Cierre del mes", cobros: "Cobros en línea", conexiones: "Conexiones y seguridad" };
  const PESTANAS = { resumen: "Resumen", bancos: "Bancos", bandeja: "Bandeja", conciliar: "Conciliar", movimientos: "Movimientos", estados: "Estados", obras: "Obras", cierre: "Cierre", cobros: "Cobros", conexiones: "Conexiones" };
  // el icono de cada página, del mismo trazo que los del menú de la app (24 × 24, línea de 1.8)
  const svgMenu = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
  const ICONOS = {
    resumen: svgMenu('<rect x="3" y="3" width="8" height="10" rx="2"/><rect x="13" y="3" width="8" height="6" rx="2"/><rect x="13" y="11" width="8" height="10" rx="2"/><rect x="3" y="15" width="8" height="6" rx="2"/>'),
    bancos: svgMenu('<rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10.5h18M7 15.5h4"/>'),
    bandeja: svgMenu('<path d="M3 13l2.5-7h13L21 13v5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M3 13h5l1.5 2.5h5L16 13h5"/>'),
    conciliar: svgMenu('<path d="M4 7h7M4 12h7M4 17h7"/><path d="M14 12.5l2.5 2.5L21 10"/>'),
    movimientos: svgMenu('<path d="M4 8h14M15 5l3 3-3 3"/><path d="M20 16H6M9 13l-3 3 3 3"/>'),
    estados: svgMenu('<path d="M5 3h9l5 5v13H5z"/><path d="M14 3v5h5"/><path d="M8.5 17v-3M12 17v-6M15.5 17v-4"/>'),
    obras: svgMenu('<path d="M3 11l9-7 9 7"/><path d="M5 9.5V20h14V9.5"/><path d="M9.5 20v-5.5h5V20"/>'),
    cierre: svgMenu('<rect x="4" y="10.5" width="16" height="10.5" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/><path d="M12 14.5v2.5"/>'),
    cobros: svgMenu('<circle cx="12" cy="12" r="9"/><path d="M12 6.5v11M9.5 9.5h3.5a1.75 1.75 0 0 1 0 3.5h-2a1.75 1.75 0 0 0 0 3.5H15"/>'),
    conexiones: svgMenu('<path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z"/><path d="M9.5 12l2 2 3.5-3.5"/>')
  };
  const KICKER = "Contabilidad · solo dueño";

  const raiz = () => $("conta-raiz");
  const main = () => $("ct-main");

  // ---------- El marco: pestañas arriba (teléfono e iPad; en la computadora las esconde el CSS y las enseña el lateral), la página debajo ----------
  function armar() {
    const r = raiz(); if (!r) return;
    r.innerHTML = `<nav class="ct-tabs" aria-label="Contabilidad">${ORDEN.map(k =>
      `<button type="button" class="ct-tab" data-pag="${k}" aria-current="${k === S.pagina ? "page" : "false"}">${ICONOS[k]}<span>${esc(PESTANAS[k])}</span>${k === "bandeja" ? `<span class="ct-n" id="ct-n-bandeja" hidden></span>` : ""}</button>`).join("")}</nav>
      <div id="ct-main" class="ct-main"></div>`;
    r.querySelectorAll(".ct-tab").forEach(b => b.addEventListener("click", () => ir(b.dataset.pag)));
    pintarBadge();
  }
  function marcarPestana() {
    const r = raiz(); if (!r) return;
    r.querySelectorAll(".ct-tab").forEach(b => {
      const activa = b.dataset.pag === S.pagina;
      b.setAttribute("aria-current", activa ? "page" : "false");
      // con nueve pestañas la activa puede quedar fuera del borde del teléfono: se trae al centro de la tira
      // (con «nearest» el tope de la tira volvía a alinear la anterior y dejaba la activa cortada por el borde)
      if (activa && typeof b.scrollIntoView === "function") b.scrollIntoView({ inline: "center", block: "nearest" });
    });
  }
  // «←» de la app: solo cuando hay algo interno que cerrar (una conciliación abierta, el mayor o el asiento de los estados). Se avisa en cada pintada
  const hayAtras = () => !!S.conc || (S.pagina === "estados" && !!(S.est.cuenta || S.est.asiento)) || (S.pagina === "obras" && !!(S.obras.sel || S.obras.bajar));
  const marcarVolver = () => S.hooks.volver(hayAtras());
  // La cabecera común de cada página: una línea con sus cifras (o lo que explica la página), los selectores si los hay y la acción principal a la derecha.
  // El título no se repite: ya lo pone la barra de la app (hooks.titulo); queda como aria-label de la cabecera
  const cabPagina = (titulo, sub, acciones, controles) => `<header class="ct-pag-cab" aria-label="${esc(titulo)}">
      <div class="ct-pag-t">${sub ? `<p class="ct-pag-sub">${sub}</p>` : ""}</div>
      ${controles ? `<div class="ct-pag-ctl">${controles}</div>` : ""}
      ${acciones ? `<div class="ct-pag-acc">${acciones}</div>` : ""}
    </header>`;
  // Los textos largos que explican una página se pliegan: quien ya sabe no los lee cada vez
  const ayudaHTML = (html, resumen) => `<details class="ct-ayuda"><summary>${esc(resumen || "¿Qué es esto?")}</summary><div class="ct-ayuda-txt">${html}</div></details>`;
  // volver a pintar la página en la que se está (después de una acción que cambió algo)
  const repintar = () => (PAGINAS[S.pagina] || pintarResumen)();
  // el contador de la bandeja: en su pestaña (teléfono e iPad) y en su subtítulo del lateral de la app (computadora; #lat-conta-badge lo arma app.js)
  function pintarBadge() {
    const total = S.bandeja ? S.bandeja.length
      : S.saldos ? S.saldos.reduce((s, c) => s + Number(c.pendientes || 0), 0) : null;
    for (const n of [$("ct-n-bandeja"), $("lat-conta-badge")]) {
      if (!n) continue;
      n.hidden = !total;
      n.textContent = total || "";
    }
  }
  function ir(pag, opciones = {}) {
    if (!PAGINAS[pag]) pag = "resumen";
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
    // el cierre: qué apartado y qué período (sin opciones, el último que se miró)
    if (pag === "cierre") for (const k of ["sub", "periodo"]) if (opciones[k] !== undefined) S.cie[k] = opciones[k];
    // (fase 9) el costo por obra: qué apartado y qué obra; la pestaña tocada sin más vuelve a la lista (lo bajado se cierra)
    if (pag === "obras") {
      for (const k of ["sub", "sel"]) if (opciones[k] !== undefined) S.obras[k] = opciones[k];
      if (opciones.sel === undefined) S.obras.sel = null;
      S.obras.bajar = null;
    }
    marcarPestana();
    S.hooks.titulo(KICKER, TITULOS[pag]);
    S.hooks.pagina(pag);
    marcarVolver();
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
    const filas = await controlBanco(vistas);
    const mal = evaluarControl(filas, vistas, conteos);
    if (mal.length) throw errorControl("El control del banco no cuadra", mal);
    return filas;
  }
  async function controlBanco(vistas) {
    const filas = await DB._rpc("fn_banco_control", { p_periodo: "hoy", p_vistas: vistas });
    if (!Array.isArray(filas) || !filas.length) throw errorControl("El control del banco no devolvió ninguna fila", [{ vista: vistas.join(", "), detalle: "fn_banco_control('hoy', …) contestó vacío" }]);
    return filas;
  }
  // lo que no cuadra de lo que contestó el control: las filas en falso, las vistas que no revisó y los conteos que no coinciden con lo que trajo la pantalla
  function evaluarControl(filas, vistas, conteos) {
    const mal = filas.filter(f => !f.ok).map(f => ({ vista: f.vista, filas: f.filas, esperadas: f.esperadas, detalle: f.detalle }));
    for (const vista of vistas) {
      const f = filas.find(x => x.vista === vista);
      if (!f) { mal.push({ vista, detalle: "el control no revisó esta vista" }); continue; }
      const n = conteos && conteos[vista];
      if (f.ok && n != null && Number(f.filas) !== Number(n)) {
        mal.push({ vista, filas: f.filas, esperadas: n, detalle: `la pantalla trajo ${n} fila(s) y el control contó ${f.filas}` });
      }
    }
    return mal;
  }

  // ---------- Lecturas que se repiten ----------
  const leerSaldos = async () => { S.saldos = await DB._leer("v_banco_saldos?select=*&order=tipo.asc,cuenta.asc"); return S.saldos; };
  const saldos = () => S.saldos ? Promise.resolve(S.saldos) : leerSaldos();
  const cuentas = async () => S.cuentas || (S.cuentas = await DB._leer("cuentas?select=codigo,nombre,tipo,regla_obra&imputable=eq.true&activa=eq.true&order=codigo.asc"));
  const leerProyectos = async () => (S.proyectos = await DB._leer("proyectos?select=id,nombre,estado&order=nombre.asc"));
  const proyectos = async () => S.proyectos || leerProyectos();
  const nombreCuenta = cod => { const c = (S.saldos || []).find(x => x.cuenta === cod) || (S.cuentas || []).find(x => x.codigo === cod); return c ? (c.cuenta_nombre || c.nombre) : cod; };

  const pill = (txt, clase) => `<span class="ct-pill${clase ? " " + clase : ""}">${esc(txt)}</span>`;
  const estadoPill = e => pill(({ abierta: "abierta", confirmada: "confirmada", anulada: "anulada" })[e] || e, ({ abierta: "warn", confirmada: "ok", anulada: "bad" })[e] || "");

  // ============================================================
  // RESUMEN: la portada. Fichas con las cifras (cada una lleva a su página) y
  // «Qué atender» con las alarmas. Todo pasa por el control antes de pintar:
  // fn_banco_control con las cuatro vistas del banco (v_banco_saldos manda: si
  // no cuadra, la portada es roja; las otras tres solo se listan para atender),
  // fn_estados_control para el mes en curso (si no cuadra, la ficha lo dice y
  // no pinta cifras: el rojo con el detalle está en Estados).
  // ============================================================
  const suma = (lista, k) => lista.reduce((s, c) => s + (num(c[k]) || 0), 0);
  const diasDesde = iso => iso ? diasEntre(hoyMiami(), iso) : null;
  const PAGINA_VISTA = { v_banco_saldos: "bancos", v_banco_bandeja: "bandeja", v_conciliacion: "conciliar", v_banco_movimientos: "movimientos" };
  async function pintarResumen() {
    cargando("Controlando con la base…");
    if (!navigator.onLine) return sinSenal(pintarResumen);
    let lista, suaves, mes, stripeCtl = [], iaCtl = [], ronda = [], jornal = null;
    try {
      lista = await leerSaldos();
      const vistas = Object.keys(PAGINA_VISTA);
      const mal = evaluarControl(await controlBanco(vistas), vistas, { v_banco_saldos: lista.length });
      // la lista de saldos es lo que la portada pinta: si su control no cuadra (o falla un cuadre general), rojo; lo demás se lista
      const duro = mal.filter(m => m.vista === "v_banco_saldos" || !vistas.includes(m.vista));
      if (duro.length) throw errorControl("El control del banco no cuadra", duro);
      suaves = mal.filter(m => !duro.includes(m));
      if (!lista.length) throw errorControl("La base no devolvió ninguna cuenta de banco ni tarjeta", [{ vista: "v_banco_saldos", filas: 0, esperadas: "1 o más", detalle: "La empresa tiene Chase y las dos Amex. Si la vista no las trae, algo está mal (¿la sesión no es la del dueño?)." }]);
      // las conexiones, frescas: la portada es donde se mira si algo pide atención
      S.mfa = null; await leerMfa();
      S.plaid = null; await leerPlaid();
      await leerStripe(true);
      if (S.stripe) stripeCtl = await DB._leer("v_stripe_control?select=*&order=orden.asc").catch(e => { if (esFalloDeRed(e)) throw e; return []; });
      // el control de la IA contable (c8); sin c8 (o si no contesta) no hay nada que atender de ella
      iaCtl = await DB._leer("v_contador_control?select=*&order=orden.asc").catch(e => { if (esFalloDeRed(e)) throw e; return []; });
      // la ronda de cada mañana (c9): sus rojos van a «Qué atender»; sin c9 (o si no contesta) no hay nada que atender de ella
      ronda = await DB._leer("v_ronda_ultima?select=*&order=periodo.asc,orden.asc").catch(e => { if (esFalloDeRed(e)) throw e; return []; });
      // (fase 9) los pagos de mano de obra que esperan reparto y los rojos del jornal y del margen (c10; sin c10, nada)
      jornal = await leerJornalResumen();
      mes = await leerMes();
    } catch (err) { return pintarError(err, pintarResumen); }
    if (S.pagina !== "resumen") return;
    pintarBadge();
    const vis = visibles(lista);
    const bancos = vis.filter(c => c.tipo === "banco"), tarjetas = vis.filter(c => c.tipo === "tarjeta"), conBanco = bancos.filter(c => c.saldo_banco != null);
    const pend = suma(vis, "pendientes");
    const viejo = vis.map(c => c.pendiente_mas_viejo).filter(Boolean).sort()[0] || null;
    const diasViejo = diasDesde(viejo);
    const bandejaRoja = diasViejo != null && diasViejo > 30;
    const e = S.stripe && S.stripe.estado;
    const ficha = (k, lbl, val, sub, clase) => `<button type="button" class="ct-ficha${clase ? " " + clase : ""}" data-ir="${k}"><span class="ct-lbl">${esc(lbl)}</span><span class="ct-val ct-num">${val}</span><span class="ct-sub">${sub || ""}</span></button>`;
    const perdida = mes && !mes.vacio && !mes.err && num(mes.resultado) < 0;
    const fichaMes = mes.vacio ? ficha("estados", "Este mes", "—", esc(mes.vacio))
      : mes.err ? ficha("estados", "Este mes", "—", "el control de los estados no cuadra: el detalle está en Estados", "bad")
      : `<button type="button" class="ct-ficha ct-ficha-mes" data-ir="estados"><span class="ct-lbl">Este mes · ${esc(nombrePeriodo(mes.corte))}</span>
          <span class="ct-mes-filas"><span>Ingresos<b class="ct-num">${fmtNeg(mes.ingresos)}</b></span><span>Costo y gastos<b class="ct-num">${fmtNeg(mes.gastos)}</b></span><span>${perdida ? "Pérdida" : "Resultado"}<b class="ct-num ${perdida ? "bad-txt" : "ok-txt"}">${fmtNeg(mes.resultado)}</b></span></span>
          <span class="ct-sub">lo que va del mes en el libro, de v_resultados</span></button>`;
    const fichas = `<div class="ct-fichas">
      ${ficha("bancos", "Bancos", fmt(suma(bancos, "saldo_libros_como_banco")), `en libros · ${conBanco.length ? `según el banco <span class="ct-num">${fmt(suma(conBanco, "saldo_banco_como_banco"))}</span>${conBanco.length < bancos.length ? ` (${conBanco.length} de ${bancos.length} con archivo)` : ""}` : "sin archivo del banco todavía"}`)}
      ${ficha("bancos", "Tarjetas", fmt(suma(tarjetas, "saldo_libros_como_banco")), `lo que se debe · ${plural(tarjetas.length, "tarjeta", "tarjetas")}`)}
      ${ficha("bandeja", "Bandeja", esc(String(pend)), pend ? `${pend === 1 ? "espera" : "esperan"} · el más viejo del ${fecha(viejo)}${bandejaRoja ? ` · ${plural(diasViejo, "día", "días")}` : ""}` : "nada espera", bandejaRoja ? "bad" : "")}
      ${ficha("cobros", "Cobros en línea", e ? fmt(e.por_depositar) : "—", e ? `en Stripe sin depositar · en camino <span class="ct-num">${fmt(e.en_camino_monto)}</span>` : "sin instalar")}
      ${fichaMes}
    </div>`;
    // qué atender: cada alarma con el botón a su página
    const atender = [];
    for (const c of vis) if (c.alarma && c.alarma_texto) atender.push({ txt: `${c.cuenta_nombre}: ${c.alarma_texto}`, ir: "bancos" });
    if (bandejaRoja) atender.push({ txt: `${plural(vis.filter(c => (diasDesde(c.pendiente_mas_viejo) || 0) > 30).length, "cuenta tiene", "cuentas tienen")} movimientos de más de 30 días en la bandeja (el más viejo del ${fechaLarga(viejo)}).`, ir: "bandeja" });
    for (const m of suaves) atender.push({ txt: `El control del banco no cuadra en ${m.vista}: ${PESTANAS[PAGINA_VISTA[m.vista]]} se pone en rojo hasta que cuadre.`, det: m.detalle, ir: PAGINA_VISTA[m.vista] });
    if (!mfaActivo()) atender.push({ txt: S.mfa && S.mfa.verificados.length ? "El código del teléfono está activo pero esta sesión entró sin él: sal y vuelve a entrar con el código para conectar bancos y mover cobros." : "El código del teléfono (segundo paso para entrar) no está activo: sin él no se conecta ningún banco ni se tocan los cobros en línea.", ir: "conexiones" });
    for (const c of S.plaid || []) {
      if (c.estado === "error") atender.push({ txt: `${c.institucion || "Un banco"} (Plaid) pide volver a conectar.`, det: c.ultimo_error, ir: "conexiones" });
      else if (c.estado === "activa" && Number(c.cuentas_sin_fijar) > 0) atender.push({ txt: `${c.institucion || "Un banco"}: ${plural(c.cuentas_sin_fijar, "cuenta del banco sin fijar", "cuentas del banco sin fijar")} a una cuenta del plan (hasta fijarlas no se sincroniza nada).`, ir: "conexiones" });
    }
    for (const f of stripeCtl) {
      if (f.nivel === "alarma" && f.ok === false) atender.push({ txt: ALARMA_STRIPE[f.orden] || String(f.control || "").replace(/^stripe: /, ""), det: f.detalle, ir: "cobros" });
      else if (f.nivel === "cuadre" && f.ok !== true) atender.push({ txt: `Los cobros en línea no cuadran (${String(f.control || "").replace(/^stripe: /, "")}): la página lo explica y no pinta hasta que cuadre.`, det: f.detalle, ir: "cobros" });
    }
    for (const f of Array.isArray(iaCtl) ? iaCtl : []) {
      const a = ALARMA_IA[f.orden];
      if (f.nivel === "alarma" && f.ok === false) atender.push({ txt: a ? a[0] : String(f.control || "").replace(/^ia: /, ""), det: f.detalle, ir: a ? a[1] : "bandeja" });
      // (7b) una obra propuesta que se cerró después: la Bandeja sigue pintando la IA y la propuesta dice qué hacer
      else if (f.nivel === "cuadre" && f.ok !== true && CUADRES_IA_A_LA_VISTA.includes(Number(f.orden))) atender.push({ txt: `${plural(nOk(f.filas) || 1, "propuesta de la IA trae una obra que ya no está activa", "propuestas de la IA traen una obra que ya no está activa")}: en la Bandeja, elige otra obra al aprobarla o di «No es eso».`, det: f.detalle, ir: "bandeja" });
      else if (f.nivel === "cuadre" && f.ok !== true) atender.push({ txt: `La IA contable no cuadra (${String(f.control || "").replace(/^(ia|vista): /, "")}): la Bandeja no pinta sus propuestas hasta que cuadre.`, det: f.detalle, ir: "bandeja" });
    }
    // (fase 8) lo que la ronda de la mañana dejó en rojo: lo que detiene el cierre primero; tres a la vista y el resto en Cierre del mes
    const rojosRonda = rojosDeRonda(ronda);
    for (const f of rojosRonda.slice(0, 3)) atender.push({ txt: `${rondaDe(f.fecha)}${f.periodo ? ` · ${nombrePer(f.periodo)}` : ""}: ${controlTxt(f.control)}${f.nivel === "detiene" ? " (detiene el cierre)" : ""}.`, det: f.detalle, ir: "cierre", sub: "cierre" });
    if (rojosRonda.length > 3) atender.push({ txt: `…y ${plural(rojosRonda.length - 3, "rojo más", "rojos más")} de la ronda: la lista entera está en Cierre del mes.`, ir: "cierre", sub: "cierre" });
    // (fase 9) la mano de obra: los pagos que esperan su reparto por horas y los rojos de sus controles
    for (const a of atenderJornal(jornal)) atender.push(a);
    main().innerHTML = cabPagina("Resumen", `${plural(vis.length, "cuenta", "cuentas")} · ${pend ? `<b>${plural(pend, "movimiento espera", "movimientos esperan")}</b> en la bandeja` : "la bandeja está al día"} · hoy, ${fechaLarga(hoyMiami())}`) + fichas +
      `<section class="ct-card ct-atender${atender.length ? "" : " ok"}" id="ct-atender"><h2>Qué atender</h2>
        ${atender.length ? `<ul class="ct-atn-lista">${atender.map(a => `<li class="ct-atn"><div class="ct-atn-txt">${esc(a.txt)}${a.det ? `<small>${esc(a.det)}</small>` : ""}</div><button type="button" class="accion secundaria chica" data-ir="${a.ir}"${a.sub ? ` data-ir-sub="${esc(a.sub)}"` : ""}>${esc(PESTANAS[a.ir])}</button></li>`).join("")}</ul>`
          : `<p class="ct-nota">Nada urgente: lo que espera en la bandeja no pasa de 30 días, las cuentas no tienen alarmas y las conexiones están bien.</p>`}
      </section>`;
    main().querySelectorAll("[data-ir]").forEach(b => b.addEventListener("click", () => ir(b.dataset.ir, b.dataset.irSub ? { sub: b.dataset.irSub } : {})));
  }
  // El mes en curso para la portada: v_cortes dice qué período es, fn_estados_control lo controla y v_resultados trae las secciones.
  // Devuelve { corte, ingresos, gastos, resultado } o { vacio } en llano, o { err } si el control no cuadra (sin señal, se lanza).
  async function leerMes() {
    const cortes = await leerCortes();
    const corte = cortes.length ? mesPorRegla(cortes) : null;
    if (!corte) return { corte: null, vacio: cortes.length ? "El libro no tiene abierto el mes de hoy." : "El libro no tiene períodos todavía." };
    try {
      const [ctrl, f] = await Promise.all([
        controlarEstados(corte.periodo, ["v_resultados"]),
        DB._leer(`v_resultados?select=nivel,seccion,linea,etiqueta_es,mes&periodo=eq.${encodeURIComponent(corte.periodo)}`)
      ]);
      cotejar(ctrl, { v_resultados: f.length });
      if (!f.length) return { corte, vacio: `${nombrePeriodo(corte)} no tiene asientos de resultados todavía.` };
      const ing = f.find(x => x.nivel === "seccion" && x.seccion === "ingresos"), neta = f.find(x => x.nivel === "total" && x.linea === "utilidad_neta");
      // una sola cifra de «costo y gastos»: la suma de las secciones que no son ingresos (costo, gastos, otros gastos); cada una entera está en Estados
      const gastos = f.filter(x => x.nivel === "seccion" && FAVORABLE_MAS[x.seccion] === false).reduce((s, x) => s + (num(x.mes) || 0), 0);
      return { corte, ingresos: ing ? num(ing.mes) : null, gastos, resultado: neta ? num(neta.mes) : null };
    } catch (err) {
      if (esFalloDeRed(err) || !err.control) throw err;
      return { corte, err };
    }
  }

  // ============================================================
  // BANCOS Y TARJETAS: primero las cuentas; el importador general, plegado,
  // detrás de «Importar un estado de cuenta». El código del teléfono, Plaid y
  // la conexión con Stripe viven en «Conexiones y seguridad».
  // ============================================================
  async function pintarBancos() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarBancos);
    let lista;
    try {
      lista = await leerSaldos();
      await controlar(["v_banco_saldos"], { v_banco_saldos: lista.length });
      if (!lista.length) throw errorControl("La base no devolvió ninguna cuenta de banco ni tarjeta", [{ vista: "v_banco_saldos", filas: 0, esperadas: "1 o más", detalle: "La empresa tiene Chase y las dos Amex. Si la vista no las trae, algo está mal (¿la sesión no es la del dueño?)." }]);
      await leerStripe(); // para saber cuáles son la 1020 y la 1140 (no se pintan como bancos)
    } catch (err) { return pintarError(err, pintarBancos); }
    if (S.pagina !== "bancos") return;
    pintarBadge();
    // la 1020 y la 1140 (Stripe) no se pintan como bancos; el control de arriba contó la lista entera
    const vis = visibles(lista);
    const pend = suma(vis, "pendientes"), alarmas = vis.filter(c => c.alarma).length;
    main().innerHTML = cabPagina("Bancos y tarjetas",
        `${plural(vis.filter(c => c.tipo === "banco").length, "banco", "bancos")} · ${plural(vis.filter(c => c.tipo === "tarjeta").length, "tarjeta", "tarjetas")} · ${pend ? `<b>${plural(pend, "movimiento espera", "movimientos esperan")}</b> en la bandeja` : "la bandeja está al día"}${alarmas ? ` · <span class="bad-txt">${plural(alarmas, "cuenta con alarma", "cuentas con alarma")}</span>` : ""}`,
        `<button type="button" class="accion${S.impAbierto ? " secundaria" : ""}" id="ct-imp-abrir" aria-expanded="${S.impAbierto ? "true" : "false"}" aria-controls="ct-importar">Importar un estado de cuenta</button>`) +
      importadorHTML(vis) + (S.importe ? importeHTML(S.importe) : "") +
      `<div class="ct-rejilla">${vis.map(cuentaHTML).join("")}</div>`;
    // el importador general: plegado hasta que se pide
    $("ct-imp-abrir").addEventListener("click", () => {
      S.impAbierto = !S.impAbierto;
      $("ct-importar").hidden = !S.impAbierto;
      $("ct-imp-abrir").setAttribute("aria-expanded", S.impAbierto ? "true" : "false");
      $("ct-imp-abrir").classList.toggle("secundaria", S.impAbierto);
      if (S.impAbierto) $("ct-imp-cuenta").focus();
    });
    $("ct-imp-plegar").addEventListener("click", () => { S.impAbierto = false; $("ct-importar").hidden = true; $("ct-imp-abrir").setAttribute("aria-expanded", "false"); $("ct-imp-abrir").classList.remove("secundaria"); });
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
    return `<section class="ct-card ct-importar" id="ct-importar"${S.impAbierto ? "" : " hidden"}>
      <div class="ct-cab"><h2>Importar un estado de cuenta</h2><button type="button" class="ct-x" id="ct-imp-plegar" title="Plegar">×</button></div>
      ${ayudaHTML(`<p class="ct-nota">El QFX (Quicken) que baja de Chase o de Amex. La cuenta la dice el archivo; el primer archivo de un banco necesita que la elijas aquí. El mismo archivo dos veces no entra dos veces, y lo que ya estaba no se repite. Cada tarjeta de cuenta también tiene su «Subir su archivo».</p>`)}
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
      <div class="ct-cab"><h2>${esc(c.cuenta_nombre)}</h2>${pill(`${tarjeta ? "Tarjeta" : "Banco"} · ${c.cuenta}`)}${c.activa === false ? pill("inactiva", "warn") : ""}${Number(c.pendientes) ? pill(`${c.pendientes} en la bandeja`, c.alarma ? "bad" : "warn") : ""}</div>
      <div class="ct-kpis">
        <div class="ct-kpi"><span class="ct-lbl">${tarjeta ? "Deuda en libros" : "Saldo en libros"}</span><span class="ct-val ct-num">${fmt(c.saldo_libros_como_banco)}</span><span class="ct-sub">hoy</span></div>
        <div class="ct-kpi"><span class="ct-lbl">Según el banco</span><span class="ct-val ct-num">${c.saldo_banco == null ? "—" : fmt(bancoCB)}</span><span class="ct-sub">${c.saldo_banco_al ? "al " + fechaLarga(c.saldo_banco_al) : "sin archivo todavía"}</span></div>
      </div>
      ${dif != null ? `<p class="ct-dif">Al ${fecha(c.saldo_banco_al)} los libros decían <span class="ct-num">${fmt(librosAl)}</span>: ${dif === 0 ? `<span class="ct-ok-txt">igual que el banco</span>` : `diferencia <span class="ct-num">${fmt(dif)}</span>${c.pendientes ? " (lo pendiente la explica)" : ""}`}</p>` : ""}
      <dl class="ct-ficha-datos">
        <div><dt>Pendientes en la bandeja</dt><dd><b>${c.pendientes}</b>${Number(c.pendientes) ? ` · <span class="ct-num">${fmt(c.pendientes_monto)}</span> · el más viejo del ${fecha(c.pendiente_mas_viejo)}` : ""}</dd></div>
        <div><dt>En tránsito</dt><dd><b>${c.en_transito}</b></dd></div>
        <div><dt>Última conciliación</dt><dd>${c.ultima_conciliacion ? `${fechaLarga(c.ultima_conciliacion)} ${estadoPill(c.ultima_conciliacion_estado)} diferencia <span class="ct-num">${fmt(c.ultima_conciliacion_diferencia)}</span>` : "ninguna"}</dd></div>
        <div><dt>Sin conciliación confirmada</dt><dd>${plural(c.dias_sin_conciliar, "día", "días")}${c.cubierto_hasta ? ` · archivos hasta el ${fechaLarga(c.cubierto_hasta)}` : ""}${c.ultimo_archivo ? ` · último: ${esc(c.ultimo_archivo)}` : ""}</dd></div>
      </dl>
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
      // (7c) lo que entró y espera propuesta: la IA lo propone sola, sin esperar a la rutina de la tarde
      proponerTrasImportar();
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
          S.mfa = null; await repintar();
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
        S.mfa = null; await repintar();
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
        <p class="ct-nota">La base todavía no tiene la conexión con Plaid (docs/conta/c7-plaid.sql) o la vista no contestó: ${esc(err.message)}. Mientras tanto, los archivos del banco se suben en Bancos y tarjetas.</p></section>`;
    }
    const vivas = cx.filter(c => c.estado !== "desconectada");
    return `<section class="ct-card ct-plaid" id="ct-plaid">
      <div class="ct-cab"><h2>Conexión automática con el banco (Plaid)</h2>${pill(vivas.length ? plural(vivas.length, "banco conectado", "bancos conectados") : "sin conectar", vivas.length ? "ok" : "")}</div>
      ${ayudaHTML(`<p class="ct-nota">Chase y las Amex mandan sus movimientos solos cada mañana, y entran igual que un archivo: casan lo que casa y el resto espera en la bandeja. El banco se conecta en la ventana segura de Plaid: la app nunca ve tu usuario ni tu clave del banco, y las llaves viven en la base, no en el teléfono. Qué se guarda y por cuánto tiempo, en la ${enlace}.</p>`)}
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
          await repintar();
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
      await repintar();
      // (7c) lo que trajo el banco y espera propuesta: la IA lo propone sola, como después de subir un archivo
      if (cuerpo.accion === "sincronizar") proponerTrasImportar();
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
    if (!mfaActivo()) { caja.innerHTML = `<p class="ct-aviso warn">Antes de conectar un banco, activa el código del teléfono (arriba, en Conexiones y seguridad) y entra con él.</p>`; return; }
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
      await repintar();
    } catch (err) {
      if (caja) caja.innerHTML = `<p class="ct-aviso bad">No se guardó la conexión: ${esc(esFalloDeRed(err) ? "sin señal." : err.message)}</p>`;
    }
  }
  async function reconectado(itemId) {
    S.hooks.avisar("Banco reconectado: sincronizando…");
    S.plaid = null;
    await repintar();
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

  // ---------- La tarjeta de Conexiones y seguridad ----------
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
      ${ayudaHTML(`<p class="ct-nota">Tus clientes pagan la factura con un enlace: desde su cuenta de banco (ACH) o con tarjeta. Cada pago confirmado entra solo al libro en la ${esc(e.cuenta_puente || "1020")} (${esc(e.cuenta_puente_nombre || "Stripe — cobros en tránsito")}), y cuando Stripe deposita en Chase el depósito casa solo con su asiento. Las llaves viven en Supabase, nunca en el teléfono.</p>`)}
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
      <ul class="ct-permisos">${ps.map(x => `<li class="${x.ok ? "ok" : "bad"}"><span aria-hidden="true">${x.ok ? "✓" : "✗"}</span> ${esc(x.recurso)}${x.ok ? "" : ` — Falta el permiso ${x.panel ? `«${esc(x.panel)}» (<span class="ct-num">${esc(x.rak || "?")}</span>)` : `<span class="ct-num">${esc(x.rak || "?")}</span>`} en la llave restringida: edítala en Stripe → Developers → API keys.`}</li>`).join("")}</ul>`;
  }
  function wireStripe() {
    const card = $("ct-stripe"); if (!card) return;
    const ver = $("ct-stripe-ver"); if (ver) ver.addEventListener("click", () => ir("cobros"));
    const pr = $("ct-stripe-probar"); if (pr) pr.addEventListener("click", () => accionStripe(card, { accion: "probar_llave" }, r => (r && Array.isArray(r.permisos) && r.permisos.some(x => !x.ok)) ? "A la llave le falta algún permiso: mira la lista" : "La llave de Stripe contesta bien", { repintar: false, mostrar: permisosHTML }));
    const ba = $("ct-stripe-barrer"); if (ba) ba.addEventListener("click", () => accionStripe(card, { accion: "barrer" }, resumenBarrido));
  }
  const resumenBarrido = r => `Revisado con Stripe${r && r.resumen && r.resumen.incompleto ? ": quedó a medias, sigue sola en la próxima vuelta" : ""}`;

  // ============================================================
  // CONEXIONES Y SEGURIDAD: el código del teléfono, la conexión automática
  // (Plaid) y la conexión con Stripe con su salud. Lo que antes iba arriba de
  // Bancos y tarjetas. La vuelta del banco (OAuth de Plaid) cae aquí.
  // ============================================================
  async function pintarConexiones() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarConexiones);
    try {
      const lista = await leerSaldos(); // a qué cuenta del plan va cada cuenta del banco (Plaid) se elige entre estas
      await controlar(["v_banco_saldos"], { v_banco_saldos: lista.length });
      await leerMfa();
      await leerPlaid();
      // la fila de Stripe (fresca) y la salud de la función; si p1 no está, la tarjeta lo dice
      await leerStripe(true);
      if (S.stripe) await leerSalud();
      // la IA contable (c8): su estado, sus reglas y la salud de su función; sin c8, la tarjeta lo dice
      await leerContadorCx();
    } catch (err) { return pintarError(err, pintarConexiones); }
    if (S.pagina !== "conexiones") return;
    const m = S.mfa, vivas = (S.plaid || []).filter(c => c.estado !== "desconectada");
    const sub = [
      mfaActivo() ? "código del teléfono activo" : m && !m.error && m.verificados.length ? "código del teléfono activo, esta sesión sin él" : "código del teléfono no activo",
      S.plaidErr ? "Plaid sin instalar" : vivas.length ? plural(vivas.length, "banco conectado", "bancos conectados") : "ningún banco conectado",
      S.stripe ? "Stripe conectado" : "Stripe sin instalar",
      !S.iaCx ? "IA contable sin instalar" : `IA contable con ${plural((S.iaCx.reglas || []).filter(r => r.activa).length, "regla", "reglas")}`
    ].join(" · ");
    main().innerHTML = cabPagina("Conexiones y seguridad", sub) + mfaHTML(S.mfa) + plaidHTML(S.plaid || [], S.plaidErr) + stripeHTML(S.stripe, S.stripeErr, S.stripeSalud) + iaCardHTML(S.iaCx, S.iaCxErr);
    wireMfa();
    wirePlaid();
    wireStripe();
    wireIACx();
  }

  // ---------- Una acción de una función de borde (con la sesión del dueño y su código del teléfono) ----------
  // `nombre`: la función (stripe, contador). `cont`: el contenedor: sus controles se apagan mientras corre y el resultado o el
  // error van en su caja (`res`: la primera de esa clase dentro de él; si no hay, se crea al final). `exito(r)` da el aviso (o
  // [aviso, esError]). Después vacía lo leído (`limpiar`) y repinta la página en la que está, salvo repintar: false, que enseña
  // el resultado con `mostrar`. `boton` gira mientras espera; `pide`, para quién es el código del teléfono en el aviso.
  const resCaja = (cont, clase) => { let c = cont.querySelector("." + clase); if (!c) { c = document.createElement("div"); c.className = clase; cont.appendChild(c); } return c; };
  async function accionFuncion(nombre, cont, cuerpo, exito, opciones = {}) {
    const o = Object.assign({ res: "ct-stripe-res", ms: 60000, espera: "Un momento…", pide: "lo pide", girar: false, boton: null,
      errorHTML: err => `<p class="ct-aviso bad">${esc(err.message)}</p>`, limpiar() {} }, opciones);
    if (S.ocupado) return;
    const caja = resCaja(cont, o.res);
    if (!navigator.onLine) { caja.innerHTML = `<p class="ct-aviso bad">Sin señal: no se hizo nada.</p>`; return; }
    if (!mfaActivo()) { caja.innerHTML = `<p class="ct-aviso warn">Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: ${esc(o.pide)}.</p>`; return; }
    S.ocupado = true;
    const apagados = [...cont.querySelectorAll("button, select, input, textarea")].filter(b => !b.disabled && !b.readOnly);
    apagados.forEach(b => { b.disabled = true; });
    if (o.boton) { o.boton.classList.add("ct-girando"); o.boton.setAttribute("aria-busy", "true"); }
    caja.innerHTML = `<p class="ct-aviso${o.girar ? " ct-espera" : ""}" role="status">${esc(o.espera)}</p>`;
    let r;
    try {
      r = await DB._funcion(nombre, cuerpo, o.ms);
    } catch (err) {
      apagados.forEach(b => { b.disabled = false; });
      if (o.boton) { o.boton.classList.remove("ct-girando"); o.boton.removeAttribute("aria-busy"); }
      caja.innerHTML = o.errorHTML(err, cuerpo);
      S.ocupado = false;
      if (typeof o.alFallar === "function") o.alFallar(err);
      return;
    }
    S.ocupado = false;
    const aviso = exito(r);
    S.hooks.avisar(...(Array.isArray(aviso) ? aviso : [aviso]));
    if (o.repintar === false) {
      apagados.forEach(b => { b.disabled = false; });
      if (o.boton) { o.boton.classList.remove("ct-girando"); o.boton.removeAttribute("aria-busy"); }
      caja.innerHTML = typeof o.mostrar === "function" ? o.mostrar(r) : "";
      return;
    }
    o.limpiar();
    await (PAGINAS[S.pagina] || pintarResumen)();
  }
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
  // Lo que habla con Stripe: su caja (.ct-stripe-res), sus errores en llano y, después, todo lo de Stripe se vuelve a leer
  function accionStripe(cont, cuerpo, exito, opciones = {}) {
    return accionFuncion("stripe", cont, cuerpo, exito, Object.assign({
      res: "ct-stripe-res", pide: "los cobros en línea lo piden", errorHTML: errorStripeHTML,
      espera: cuerpo.accion === "barrer" ? "Revisando con Stripe…" : cuerpo.accion === "crear_enlace" ? "Creando el enlace en Stripe…" : "Un momento…",
      limpiar: () => { S.cobros = null; S.stripe = null; S.stripeErr = null; S.stripeSalud = null; S.saldos = null; S.bandeja = null; }
    }, opciones));
  }

  // ---------- La bandeja: un depósito de Stripe no se registra como cobro ----------
  const depositoStripe = m => !!(S.stripe && S.stripe.estado) && num(m.monto) > 0 && /\bSTRIPE\b/i.test(`${m.descripcion || ""} ${m.memo || ""}`) &&
    String(m.fecha || "") >= String(S.stripe.estado.desde || "").slice(0, 10);
  const opcionDeCobro = o => !!o && (o.llamar === "fn_banco_cobrar" || (o.llamar === "fn_banco_casar_con" && !!(o.args && o.args.p_con && o.args.p_con.cobro)));
  // Deja en m.opciones la misma lista que pinta y que usa el clic: sin las que nombran la 1020 o la 1140. Un depósito de
  // Stripe (desde que están los cobros en línea) NO se resuelve aquí: sin ninguna opción de c6 (cobro, préstamo,
  // aportación, transferencia…), sin «Otra cosa…» y con el texto de p1; solo «Es el depósito de Stripe del …: casarlo»
  // (m._stripe = los depósitos asentados con ese monto y su llegada a ±5 días). Uno que Edgar sacó de la app («Ya está
  // en el libro», m._stripeFuera) se lleva aquí como antes.
  const TEXTO_DEP = "Dinero que llega de Stripe: los cobros en línea de tus clientes, menos sus comisiones.";
  function prepararMov(m) {
    let dep = depositoStripe(m);
    const cerca = q => cent(q.monto) === cent(m.monto) && Math.abs(diasEntre(q.llegada, m.fecha)) <= 5;
    m._stripeFuera = dep ? (S.stripePayouts || []).find(q => q.estado_pantalla === "fuera" && cerca(q)) || null : null;
    if (m._stripeFuera) dep = false;
    m.opciones = (Array.isArray(m.opciones) ? m.opciones : []).filter(o => !(o && o.args && esStripe(o.args.p_cuenta)) && !(dep && opcionDeCobro(o)));
    if (dep) { m.opciones = []; m.texto = TEXTO_DEP; }
    m._esStripe = dep;
    m._stripe = dep ? (S.stripePayouts || []).filter(q => q.estado_pantalla === "asentado" && cerca(q)) : [];
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
    const sinMfa = mfa ? "" : `<p class="ct-aviso warn">Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: crear enlaces y todo lo que habla con Stripe lo pide.</p>`;
    // la cabecera con las cifras y «Revisar con Stripe ahora»; debajo, los avisos de la página y donde cae el resultado de la revisión
    main().innerHTML = `<div id="ct-cobros-top">${cabPagina("Cobros en línea",
        `<b>${plural(porCobrar, "factura por cobrar", "facturas por cobrar")}</b> · ${plural(enCamino, "pago en camino", "pagos en camino")} · ${plural(aChase, "depósito esperando a Chase", "depósitos esperando a Chase")}`,
        `<button type="button" class="accion secundaria" id="ct-cobros-barrer"${mfa ? "" : " disabled"}>Revisar con Stripe ahora</button>`)}
        <div id="ct-cobros-barra" class="ct-pag-avisos">${e.modo === "prueba" && !e.acepta_prueba ? `<p class="ct-aviso warn">La función tiene una llave de prueba (rk_test_): no se registra nada.</p>` : ""}${sinMfa}<div class="ct-stripe-res"></div></div>
      </div>
      ${alarmas.length ? `<section class="ct-card ct-alarmas" id="ct-cobros-alarmas" role="status"><h2>Hay que mirar esto:</h2><ul class="ct-datos">${alarmas.map(a => `<li><b>${esc(ALARMA_STRIPE[a.orden] || String(a.control || "").replace(/^stripe: /, ""))}</b>${a.detalle ? `<small>${a.filas != null ? `${esc(a.filas)}: ` : ""}${esc(a.detalle)}</small>` : ""}</li>`).join("")}</ul></section>` : ""}
      ${(avisos || []).length ? `<section class="ct-card" id="ct-cobros-avisos"><h2>Avisos de Stripe</h2><ul class="ct-avisos-stripe">${avisos.map(avisoHTML).join("")}</ul></section>` : ""}
      <section class="ct-card" id="ct-cobros-facturas"><h2>Facturas por cobrar</h2>
        ${ayudaHTML(`<p class="ct-nota">El saldo sale del libro (lo que la factura debe), no de la casilla «pagada». El enlace es de un solo uso y por ese saldo: el cliente elige cuenta de banco (ACH) o tarjeta.</p>`)}
        ${facturas.length ? `<div class="ct-lista">${facturas.map(f => facturaCobroHTML(f, mfa)).join("")}</div>` : `<p class="ct-vacio">No hay facturas con saldo en el libro.</p>`}
      </section>
      <section class="ct-card" id="ct-cobros-pagos"><h2>Pagos en línea</h2>
        ${pagos.length ? `<div class="ct-lista">${pagos.map(x => pagoHTML(x, mfa)).join("")}</div>` : `<p class="ct-vacio">Todavía no hay pagos en línea.</p>`}
      </section>
      <section class="ct-card" id="ct-cobros-payouts"><h2>Depósitos de Stripe en Chase</h2>
        ${ayudaHTML(`<p class="ct-nota">Stripe junta los cobros, descuenta sus comisiones y deposita el neto en Chase. Cada depósito deja dos asientos (sale de Stripe, llega a Chase) y casa solo con el movimiento «STRIPE» que trae Plaid.</p>`)}
        ${payouts.length ? `<div class="ct-lista">${payouts.map(x => payoutHTML(x, mfa)).join("")}</div>` : `<p class="ct-vacio">Todavía no hay depósitos de Stripe.</p>`}
      </section>
      <p class="ct-nota ct-cobros-pie">La casilla «pagada» y QuickBooks los sigues llevando tú durante el paralelo: esta pantalla no los toca.</p>`;
    wireCobros();
  }

  // Las alarmas en llano: lo que pasa y qué hacer (el control dice la condición que se cumple cuando todo va bien)
  const ALARMA_STRIPE = {
    22: "Cobros de Stripe que llevan días sin depositarse en Chase: mira en Stripe → Balances si hay un depósito retenido.",
    24: "Stripe dice que depositó y el depósito no está en el libro: toca «Revisar con Stripe ahora».",
    26: "Depósitos de Stripe en el libro que no casan con Chase: mira si Plaid trajo el depósito «STRIPE» o cásalo abajo.",
    29: "Avisos de Stripe sin procesar: toca «Revisar con Stripe ahora».",
    30: "Pagos que no sé a qué factura van: «Decir a qué va» en cada uno, abajo.",
    31: "Pagos por cuenta de banco que tardan demasiado: míralos en Stripe.",
    32: "La revisión automática no corre desde hace más de 2 horas: mira que STRIPE_RUTINA_SECRETO sea el que enseñó p1-stripe.sql y que la función «stripe» esté desplegada.",
    35: "Enlaces vivos que ya no sirven (factura anulada, o ya debe menos): la revisión automática los desactiva; si no, desactívalos tú.",
    38: "Depósitos de Stripe que esperan o están por revisar desde hace días: ábrelos abajo.",
    39: "La función tiene una llave de prueba (rk_test_): no se registra nada. Pon la real (rk_live_) en STRIPE_SECRET_KEY."
  };
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
      cuerpo = `<div class="ct-acciones"><button type="button" class="accion" data-crear${mfa ? "" : " disabled"}>Crear enlace de pago</button>${mfa ? "" : `<span class="ct-nota" style="margin:0">Primero activa el código del teléfono (Conexiones y seguridad).</span>`}</div>`;
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
    en_disputa: ["en disputa", "bad", x => `Stripe retiró el dinero y el cobro se devolvió en el libro. ${x.disputa_vence ? `Responde en Stripe antes del ${fechaLarga(x.disputa_vence)}.` : "Stripe no da plazo para responderla (no admite respuesta)."}${x.medio === "ach" ? " Las disputas por cuenta de banco no se pueden impugnar." : ""}`],
    fallido: ["falló", "bad", x => `${x.fallo || "El pago no se completó"}: no entró nada al libro.`],
    revisar: ["por resolver", "bad", x => `${x.revisar || "No se sabe a qué factura va"}. Hasta que digas a qué va, el depósito que lo lleva espera.`],
    fuera: ["fuera de la app", "cu", () => "Su depósito se sacó de la app («Ya está en el libro»): este pago no entra al libro por aquí."]
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
    asentado: ["en el libro; falta que llegue a Chase", "warn"], casado: ["casado con Chase", "ok"], fallido: ["no llegó (falló)", "bad"], revisar: ["por revisar", "bad"],
    fuera: ["fuera de la app", "cu"]
  };
  // los movimientos del saldo de Stripe en llano (la base guarda el código)
  const TIPO_BT = {
    reserve_transaction: "Stripe retuvo (o soltó) una reserva", reserved_funds: "Stripe retuvo (o soltó) una reserva", adjustment: "un ajuste de Stripe",
    tax_fee: "impuesto sobre las comisiones de Stripe", stripe_fee: "un cargo de Stripe", application_fee: "una comisión de una aplicación",
    climate_order_purchase: "una contribución de Stripe Climate", topup: "dinero que se puso en el saldo de Stripe", transfer: "una transferencia de Stripe"
  };
  const tipoBT = t => TIPO_BT[t] || t || "un movimiento";
  const CLASE_LINEA = { pago: "cobro", vuelve: "vuelve de un depósito fallido", comision: "comisión", otro: "otro", propio: "el depósito" };
  function payoutHTML(x, mfa) {
    const ep = ESTADO_PAYOUT[x.estado_pantalla] || [x.estado_pantalla || x.estado, ""];
    const lineas = Array.isArray(x.lineas) ? x.lineas : [];
    const esperando = Array.isArray(x.esperando) ? x.esperando : [];
    const candidatos = Array.isArray(x.candidatos) ? x.candidatos : [];
    // (y lo que volvió de un depósito que no es de la app: la base lo pide en «esperando»)
    const pideCuenta = new Set(esperando.filter(w => w.txn && /a qué cuenta va/.test(w.motivo || "")).map(w => w.txn));
    const sinCuenta = x.estado !== "asentado" ? lineas.filter(l => !l.cuenta && (l.clase === "otro" || pideCuenta.has(l.txn))) : [];
    const asientos = [x.asiento_salida_num && `${esc(x.asiento_salida_num)} (sale de Stripe)`, x.asiento_llegada_num && `${esc(x.asiento_llegada_num)} (llega a Chase)`, x.asiento_vuelta_num && `${esc(x.asiento_vuelta_num)} (vuelve a Stripe)`].filter(Boolean);
    const mirar = ["en_camino", "esperando_composicion", "esperando_cobros", "revisar"].includes(x.estado);
    // «Ya está en el libro»: solo sin asientos y mientras espera o está por revisar
    const sacar = ["esperando_composicion", "esperando_cobros", "revisar"].includes(x.estado) && !asientos.length;
    const dis = mfa ? "" : " disabled";
    return `<article class="ct-cobro ct-payout ${esc(x.estado_pantalla || "")}" data-po="${esc(x.po)}">
      <div class="ct-cab"><h3>${fechaLarga(x.llegada)} · neto <span class="ct-num">${fmt(x.monto)}</span></h3>${pill(ep[0], ep[1])}${x.reversado ? pill("reversado a mano", "bad") : ""}</div>
      ${x.bruto != null ? `<p class="ct-nota">${plural(Number(x.n_pagos || 0), "cobro", "cobros")} por <span class="ct-num">${fmt(x.bruto)}</span> − comisiones <span class="ct-num">${fmt(x.comisiones)}</span> = <span class="ct-num">${fmt(x.monto)}</span></p>`
        : lineas.length ? `<p class="ct-nota">Stripe ya dio el detalle de este depósito${x.estado === "esperando_cobros" ? "; falta un cobro que la app no tiene: lo pide sola" : ""}.</p>`
        : x.estado === "fuera" ? "" : `<p class="ct-nota">Stripe todavía no dio el detalle de este depósito.</p>`}
      ${x.estado === "fuera" ? `<p class="ct-nota">Fuera de la app${x.fuera_motivo ? ` (${esc(x.fuera_motivo)})` : ""}: no se asienta nada; su movimiento de Chase se lleva en la bandeja, como antes.</p>` : ""}
      ${asientos.length ? `<p class="ct-nota">Asientos ${asientos.join(" y ")}</p>` : ""}
      ${x.estado_pantalla === "casado" ? `<p class="ct-aviso ok">Casó con «${esc(x.movimiento_descripcion || "")}» del ${fechaLarga(x.movimiento_fecha)} · ${x.casado_automatico ? "casó solo" : `casó: ${esc(x.casado_regla || "a mano")}`}</p>` : ""}
      ${x.estado_pantalla === "asentado" ? `<p class="ct-nota">${x.dias_sin_casar != null && Number(x.dias_sin_casar) > 0 ? `Lleva ${plural(Number(x.dias_sin_casar), "día", "días")} sin casar. ` : ""}${x.reversado ? "Alguien reversó su asiento a mano: toca «Volver a ponerlo» para que case con Chase." : candidatos.length ? "Chase ya trajo un depósito que puede ser este:" : "Cuando Plaid traiga el depósito «STRIPE» de Chase, casa solo."}</p>` : ""}
      ${x.revisar ? `<p class="ct-aviso bad">${esc(x.revisar)}</p>` : ""}
      ${esperando.length ? `<ul class="ct-datos ct-esperando">${esperando.map(w => `<li>${w.pi ? `Cobro <span class="ct-num">${esc(w.pi)}</span>` : w.po ? `Depósito <span class="ct-num">${esc(w.po)}</span>` : w.txn ? `${esc(tipoBT(w.tipo))} <span class="ct-num">${fmt(w.monto)}</span>` : w.bandeja ? "El depósito de Chase" : "Algo"}: ${esc(w.motivo || "")}</li>`).join("")}</ul>` : ""}
      ${sacar ? `<p class="ct-nota">Si el dinero de este depósito ya está en el libro (es de antes de instalar los cobros en línea, lo registraste en la bandeja o lo trae la apertura), sácalo de la app: «Ya está en el libro».</p>` : ""}
      ${x.estado === "fallido" ? `<p class="ct-nota">Stripe devolvió el dinero a tu saldo y lo manda con el siguiente depósito: revisa la cuenta de banco en Stripe.</p>` : ""}
      <div class="ct-acciones">
        ${candidatos.map(c => `<button type="button" class="accion" data-casar="${esc(c.id)}"${dis}>Casar con el depósito de Chase del ${fechaLarga(c.fecha)}</button>`).join("")}
        ${sinCuenta.map(l => `<button type="button" class="accion" data-linea="${esc(l.txn)}"${dis}>A qué cuenta va: ${esc(tipoBT(l.tipo))} ${fmt(l.monto)}</button>`).join("")}
        ${sacar ? `<button type="button" class="accion secundaria" data-fuera${dis}>Ya está en el libro</button>` : ""}
        ${x.reversado ? `<button type="button" class="accion secundaria" data-rehacer${dis}>Volver a ponerlo</button>` : ""}
        ${mirar ? `<button type="button" class="accion secundaria chica" data-mirar${dis}>Volver a mirar en Stripe</button>` : ""}
      </div>
      ${lineas.length ? `<details class="ct-payout-det"><summary>El detalle de Stripe (${plural(lineas.length, "línea", "líneas")})</summary>
        <ul class="ct-payout-lineas">${lineas.map(l => `<li><span class="ct-pl-que">${esc(l.clase === "otro" ? tipoBT(l.tipo) : CLASE_LINEA[l.clase] || l.clase)}${l.factura_num ? ` · #${esc(l.factura_num)}` : ""}${l.cuenta ? ` · a ${esc(l.cuenta)}` : ""}<small class="ct-num">${esc(l.tipo)} · ${esc(l.txn)}</small></span><span class="ct-pl-m ct-num">${fmt(l.monto)}${num(l.comision) ? `<small>comisión ${fmt(l.comision)}</small>` : ""}</span></li>`).join("")}</ul></details>` : ""}
      <div class="ct-form" hidden></div>
      <div class="ct-stripe-res"></div>
    </article>`;
  }

  // las cuentas a las que puede ir dinero de Stripe «de fuera» o un movimiento que la app no conoce
  // (la base lo vuelve a comprobar con fn_stripe_cuenta_libre): ingreso, gasto, costo u otro, pasivo, o un activo que no es
  // un banco (una reserva de Stripe); nunca banco, tarjeta, cobrar a clientes, ni las de Stripe
  const cuentasLibres = () => (S.cuentas || []).filter(c => ["ingreso", "otro_ingreso", "gasto", "otro_gasto", "costo", "pasivo", "activo"].includes(c.tipo) && c.regla_obra !== "obligatoria" &&
    !esStripe(c.codigo) && !(S.saldos || []).some(s => s.cuenta === c.codigo) && !(c.tipo === "activo" && (/^10/.test(String(c.codigo)) || ["1110", "1120"].includes(String(c.codigo)))));
  const opcionesCuentas = () => cuentasLibres().map(c => `<option value="${esc(c.codigo)}">${esc(c.codigo)} · ${esc(c.nombre)}</option>`).join("");

  function wireCobros() {
    const m = main();
    const barra = $("ct-cobros-top"); // la cabecera y sus avisos: el botón se apaga mientras corre y el resultado cae debajo
    const ba = $("ct-cobros-barrer"); if (ba) ba.addEventListener("click", () => accionStripe(barra, { accion: "barrer" }, resumenBarrido));
    m.querySelectorAll(".ct-aviso-stripe").forEach(li => {
      li.querySelector("[data-visto]").addEventListener("click", () => accionStripe(li, { accion: "aviso_visto", aviso: Number(li.dataset.aviso) }, () => "Aviso visto"));
    });
    m.querySelectorAll(".ct-factura").forEach(card => {
      const f = S.cobros.facturas.find(x => String(x.factura_id) === card.dataset.factura); if (!f) return;
      card.querySelectorAll("[data-crear]").forEach(b => b.addEventListener("click", () => formaEnlace(card, f, b.dataset.crear === "reemplazar", false)));
      const cp = card.querySelector("[data-copiar]"); if (cp) cp.addEventListener("click", () => copiarEnlace(card));
      const en = card.querySelector("[data-enviar]"); if (en) en.addEventListener("click", () => {
        navigator.share({ title: `Invoice ${f.num || f.factura_id} · Max Power Electrical Solutions, Inc.`, text: `Payment link for invoice ${f.num || f.factura_id} — Max Power Electrical Solutions, Inc.`, url: f.enlace_url }).catch(() => { /* lo cerró */ });
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
        montarForma(card, formaHTML(`¿A qué cuenta va ${esc(tipoBT(l.tipo))} de ${fmt(l.monto)} (${esc(l.tipo || "")} · ${esc(l.txn)})? Stripe lo trae en el depósito y la app no lo conoce.`,
          `<label class="ct-campo">Cuenta<select name="cuenta" required><option value="">Elige la cuenta…</option>${ops}</select></label>${campoHTML("motivo", "Motivo (queda escrito)", "textarea", "required")}`, "Guardar"),
          v => accionStripe(card, { accion: "resolver_linea", po: x.po, txn: l.txn, cuenta: v.cuenta, motivo: v.motivo }, () => `Va a ${v.cuenta}: el depósito se vuelve a mirar`));
      }));
      const fu = card.querySelector("[data-fuera]"); if (fu) fu.addEventListener("click", () => montarForma(card,
        formaHTML(`Sacar de la app el depósito ${esc(x.po)} de ${fmt(x.monto)}: su dinero ya está en el libro (de antes de instalar los cobros en línea, la bandeja o la apertura). No se asienta nada y su movimiento de Chase se lleva en la bandeja.`,
          campoHTML("motivo", "Por qué ya está en el libro (queda escrito)", "textarea", "required"), "Ya está en el libro"),
        v => accionStripe(card, { accion: "payout_fuera", po: x.po, motivo: v.motivo }, () => `Depósito ${x.po} fuera de la app: llévalo en la bandeja`)));
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
      `<label class="ct-campo">¿A qué va?<select name="que" required><option value="">Elige…</option><option value="factura">A la factura…</option><option value="obra">Anticipo de la obra…</option><option value="fuera">Va a otra cuenta (no es de una factura)</option></select></label>
       <label class="ct-campo" data-si="factura" hidden>Factura<select name="factura_id"><option value="">Elige la factura…</option>${facts.map(f => `<option value="${esc(f.factura_id)}">#${esc(f.num || f.factura_id)}${f.obra ? ` · ${esc(f.obra)}` : ""} · debe ${fmt(num(f.saldo_cxc) + num(f.saldo_retencion))}</option>`).join("")}</select></label>
       <label class="ct-campo" data-si="obra" hidden>Obra<select name="proyecto_id"><option value="">Elige la obra…</option>${obras.map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("")}</select></label>
       <label class="ct-campo" data-si="fuera" hidden>Cuenta (ingreso, gasto, costo, pasivo o un activo que no es banco)<select name="cuenta"><option value="">Elige la cuenta…</option>${ops}</select></label>
       <p class="ct-nota" data-si="fuera" hidden>Si el dinero ya está en el libro (lo registraste en la bandeja, o lo trae la apertura), no lo pongas en otra cuenta: estaría dos veces. Sácalo con «Ya está en el libro» en su depósito, abajo.</p>
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
  // LA BANDEJA (el bank feed): lo que el banco trajo y espera respuesta.
  // Cabecera con las cifras, barra de herramientas (buscar, motivo, orden,
  // agrupar por comercio) y filas compactas que se despliegan de una en una
  // al detalle con sus botones. La lectura y el control son los de siempre;
  // la barra solo filtra lo ya leído, sin volver a la base.
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

  // Las herramientas del bank feed: buscar sin acentos, el comercio detrás de una descripción y los órdenes
  const sinAcentos = s => String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  // el comercio: la descripción en mayúsculas, sin fechas ni números (el banco pega al nombre el día o el número de la operación)
  const comercioDe = d => String(d || "").toUpperCase().replace(/\d{1,2}[/.-]\d{1,2}([/.-]\d{2,4})?/g, " ").replace(/[#*]?\d[\d.,-]*/g, " ").replace(/\s+/g, " ").trim() || "(sin descripción)";
  const ORDENES = { fecha_asc: "Más viejos primero", fecha_desc: "Más nuevos primero", monto_desc: "Monto: de mayor a menor", monto_asc: "Monto: de menor a mayor" };
  const sumaMonto = ms => ms.reduce((s, m) => s + (num(m.monto) || 0), 0);

  async function pintarBandeja() {
    cargando();
    if (!navigator.onLine) return sinSenal(pintarBandeja);
    let filas;
    try {
      const [b] = await Promise.all([
        DB._leer("v_banco_bandeja?select=*&order=alarma.desc,fecha.asc,movimiento_id.asc"),
        // (las obras, frescas: la IA propone una y la pantalla la preselecciona solo si sigue activa; una nueva sale en el selector)
        saldos(), cuentas(), leerProyectos(), leerStripe(), leerMfa()
      ]);
      // los depósitos de Stripe ya en el libro y sin casar: el botón «Es el depósito de Stripe del …» (si no contesta, sin botón)
      // (y los que Edgar sacó de la app: esos se llevan aquí como antes)
      // y lo de la IA contable (c8): sin c8, null y la bandeja sigue como antes
      // y (fase 9) los pagos de mano de obra que c10 reconoce: sin c10, ninguno y la bandeja sigue como antes
      [S.stripePayouts, S.ia] = await Promise.all([
        S.stripe ? DB._leer("v_stripe_payouts?select=po,estado_pantalla,monto,llegada,fuera_motivo&estado_pantalla=in.(asentado,fuera)").catch(e => { if (esFalloDeRed(e)) throw e; return []; }) : [],
        leerContador(),
        leerJornalBandeja()
      ]);
      const hoy = hoyMiami();
      await controlar(["v_banco_bandeja"], { v_banco_bandeja: b.filter(f => String(f.fecha) <= hoy).length });
      if (!S.cuentas.length) throw errorControl("El plan de cuentas no se pudo leer", [{ vista: "cuentas", filas: 0, esperadas: "1 o más", detalle: "sin el plan no se puede clasificar nada" }]);
      filas = b;
    } catch (err) { return pintarError(err, pintarBandeja); }
    if (S.pagina !== "bandeja") return;
    filas.forEach(prepararMov);
    S.bandeja = filas; pintarBadge();
    // (7c) lo que dijo la última cadena ya se avisó: la franja nueva no lo repite (una en marcha sigue enseñando su avance)
    if (S.cadena && !S.cadena.activa) S.cadena = null;
    const conMovs = [...new Set(filas.map(f => f.cuenta))];
    if (S.filtroCuenta && !conMovs.includes(S.filtroCuenta)) S.filtroCuenta = null;
    // la fila desplegada sigue desplegada al repintar si sigue en la lista
    if (S.bj.abierta && !filas.some(f => f.movimiento_id === S.bj.abierta)) S.bj.abierta = null;
    const motivos = [...new Set(filas.map(f => f.motivo).filter(Boolean))].sort((a, b) => motivoLlano(a).localeCompare(motivoLlano(b)));
    if (S.bj.motivo && !motivos.includes(S.bj.motivo)) S.bj.motivo = "";
    const viejos = filas.filter(f => f.alarma).length;
    main().innerHTML = cabPagina("Bandeja",
        filas.length ? `<b>${plural(filas.length, "movimiento del banco espera", "movimientos del banco esperan")}</b> tu respuesta por <span class="ct-num">${fmt(sumaMonto(filas))}</span>${viejos ? ` · <span class="bad-txt">${plural(viejos, "lleva", "llevan")} más de 30 días</span>` : ""}. Lo que no contestes no entra al libro; nada se inventa.` : "<b>La bandeja está vacía.</b> Todo lo que trajo el banco tiene su papel en el libro.",
        `<button type="button" class="accion secundaria" id="ct-casar">Casar otra vez</button>`) +
      (S.ia ? franjaIAHTML(S.ia) : "") + franjaJornalHTML(filas) +
      (filas.length ? `<section class="ct-card ct-herr" id="ct-bj-herr">
        <div class="ct-herr-fila">
          <label class="ct-campo ct-buscar">Buscar<input id="ct-bj-buscar" type="search" placeholder="Descripción, memo o monto" value="${esc(S.bj.q)}" autocomplete="off"></label>
          <label class="ct-campo">Motivo<select id="ct-bj-motivo"><option value="">Todos</option>${motivos.map(m => `<option value="${esc(m)}"${m === S.bj.motivo ? " selected" : ""}>${esc(motivoLlano(m))} (${filas.filter(f => f.motivo === m).length})</option>`).join("")}</select></label>
          <label class="ct-campo">Orden<select id="ct-bj-orden">${Object.keys(ORDENES).map(k => `<option value="${k}"${k === S.bj.orden ? " selected" : ""}>${ORDENES[k]}</option>`).join("")}</select></label>
          <label class="ct-casilla ct-agrupar"><input type="checkbox" id="ct-bj-agrupar"${S.bj.agrupar ? " checked" : ""}> Agrupar por comercio</label>
        </div>
        ${conMovs.length > 1 ? `<div class="ct-chips">${chipsCuentaHTML(filas, conMovs)}</div>` : ""}
        <p class="ct-sub ct-bj-n" id="ct-bj-n"></p>
      </section>` : "") +
      `<div id="ct-bj-lista"></div>`;
    $("ct-casar").addEventListener("click", async () => {
      if (S.ocupado) return;
      S.ocupado = true; $("ct-casar").disabled = true; $("ct-casar").textContent = "Casando…";
      try { const k = await casarTodo(null); S.hooks.avisar(`${k.casados} casaron solos · ${k.pendientes} siguen en la bandeja`); S.saldos = null; }
      catch (err) { S.hooks.avisar("No se pudo casar: " + err.message, true); }
      finally { S.ocupado = false; }
      pintarBandeja();
    });
    // «Proponer ahora» y «Parar» (la franja: la cadena la repinta sola, sin repintar la página)
    wireFranja();
    // (fase 9) «Ver solo la mano de obra» de su franja
    const verJr = $("ct-jr-ver"); if (verJr) verJr.addEventListener("click", () => { S.bj.motivo = ""; S.bj.q = ""; S.filtroCuenta = null; S.bj.soloJr = !S.bj.soloJr; pintarBandeja(); });
    main().querySelectorAll("#ct-jr-franja [data-ir]").forEach(x => x.addEventListener("click", () => ir(x.dataset.ir, x.dataset.irSub ? { sub: x.dataset.irSub } : {})));
    // la barra solo filtra lo ya leído: no vuelve a la base y el buscador no pierde el foco
    const herr = (id, ev, f) => { const el = $(id); if (el) el.addEventListener(ev, f); };
    herr("ct-bj-buscar", "input", ev => { S.bj.q = ev.target.value; pintarListaBandeja(); });
    herr("ct-bj-motivo", "change", ev => { S.bj.motivo = ev.target.value; pintarListaBandeja(); });
    herr("ct-bj-orden", "change", ev => { S.bj.orden = ev.target.value; pintarListaBandeja(); });
    herr("ct-bj-agrupar", "change", ev => { S.bj.agrupar = ev.target.checked; pintarListaBandeja(); });
    main().querySelectorAll(".ct-chip[data-filtro]").forEach(b => b.addEventListener("click", () => {
      S.filtroCuenta = b.dataset.filtro || null;
      main().querySelectorAll(".ct-chip[data-filtro]").forEach(x => x.setAttribute("aria-pressed", String((x.dataset.filtro || null) === S.filtroCuenta)));
      pintarListaBandeja();
    }));
    pintarListaBandeja();
    // (7c) LAS PROPUESTAS SALEN SOLAS: si algo nuevo espera y nada lo frena, la cadena arranca sin que Edgar toque nada
    if (S.ia && puedeSola() && nuevosIA().length) cadenaIA("sola");
  }
  const chipsCuentaHTML = (filas, conMovs) => `<button type="button" class="ct-chip" data-filtro="" aria-pressed="${!S.filtroCuenta}">Todas</button>` +
    conMovs.map(c => `<button type="button" class="ct-chip" data-filtro="${esc(c)}" aria-pressed="${S.filtroCuenta === c}">${esc(nombreCuenta(c))} (${filas.filter(f => f.cuenta === c).length})</button>`).join("");

  // lo que la barra deja ver, en el orden pedido («más viejos primero» es el de la base: las alarmas delante y luego la fecha)
  function filtrarBandeja() {
    const q = sinAcentos(S.bj.q).trim(), qMonto = q.replace(/[$,\s]/g, "");
    let lista = S.bandeja || [];
    if (S.bj.soloJr) lista = lista.filter(f => !!jrDe(f));
    if (S.filtroCuenta) lista = lista.filter(f => f.cuenta === S.filtroCuenta);
    if (S.bj.motivo) lista = lista.filter(f => f.motivo === S.bj.motivo);
    if (q) lista = lista.filter(f => sinAcentos(`${f.descripcion || ""} ${f.memo || ""} ${f.cheque || ""}`).includes(q) || (qMonto && Math.abs(num(f.monto) || 0).toFixed(2).includes(qMonto)));
    const k = S.bj.orden, abs = m => Math.abs(num(m.monto) || 0);
    if (k === "fecha_desc") lista = [...lista].sort((a, b) => String(b.fecha).localeCompare(String(a.fecha)));
    else if (k === "monto_desc") lista = [...lista].sort((a, b) => abs(b) - abs(a));
    else if (k === "monto_asc") lista = [...lista].sort((a, b) => abs(a) - abs(b));
    return lista;
  }
  function pintarListaBandeja() {
    const cont = $("ct-bj-lista"); if (!cont) return;
    const lista = filtrarBandeja(), total = (S.bandeja || []).length;
    const n = $("ct-bj-n"); if (n) n.textContent = lista.length === total ? "" : `${lista.length} de ${plural(total, "movimiento", "movimientos")}`;
    if (!lista.length) { cont.innerHTML = total ? `<section class="ct-card ct-vacio">Nada con ese filtro${S.bj.q ? ` («${esc(S.bj.q)}»)` : ""}.</section>` : ""; return; }
    // la cabecera de columnas (solo la computadora la enseña) dice lo que hay debajo: las del movimiento o, agrupado, las del comercio
    const cab = S.bj.agrupar
      ? `<div class="ct-feed-cab" aria-hidden="true"><span>Comercio</span><span>Movimientos</span><span class="r">Total</span><span></span></div>`
      : `<div class="ct-feed-cab" aria-hidden="true"><span>Fecha</span><span>Descripción</span><span>Cuenta</span><span>Motivo</span><span class="r">Monto</span><span></span></div>`;
    let cuerpo;
    if (S.bj.agrupar) {
      const grupos = new Map();
      for (const m of lista) { const k = comercioDe(m.descripcion); if (!grupos.has(k)) grupos.set(k, []); grupos.get(k).push(m); }
      cuerpo = [...grupos.entries()].sort((a, b) => b[1].length - a[1].length || Math.abs(sumaMonto(b[1])) - Math.abs(sumaMonto(a[1]))).map(([k, ms]) => grupoHTML(k, ms)).join("");
    } else cuerpo = lista.map(movHTML).join("");
    cont.innerHTML = `<section class="ct-card ct-feed${S.bj.agrupar ? " agrupada" : ""}">${cab}${cuerpo}</section>`;
    cont.querySelectorAll(".ct-mov").forEach(card => wireMov(card, lista.find(f => f.movimiento_id === card.dataset.id)));
    // después de «No es eso» el movimiento sigue en la bandeja: su «Según yo» queda a la vista con la cuenta enfocada
    if (S.iaFoco) {
      const card = [...cont.querySelectorAll(".ct-mov")].find(c => c.dataset.id === S.iaFoco), sel = card && card.querySelector("[data-ia-cuenta]");
      S.iaFoco = null;
      if (sel) { sel.focus({ preventScroll: true }); const yo = card.querySelector(".ct-ia-mia"); if (yo && typeof yo.scrollIntoView === "function") yo.scrollIntoView({ behavior: "smooth", block: "nearest" }); }
    }
  }
  // los botones de una fila (al pintar la lista, o al repintar solo esa fila cuando la cadena le trae su propuesta)
  function wireMov(card, m) {
    card.querySelector(".ct-mov-fila").addEventListener("click", () => desplegar(card.dataset.id === S.bj.abierta ? null : card.dataset.id));
    card.querySelectorAll("[data-op]").forEach(b => b.addEventListener("click", () => abrirOpcion(card, m, (m.opciones || [])[Number(b.dataset.op)])));
    const ot = card.querySelector("[data-otra]"); if (ot) ot.addEventListener("click", () => abrirOtra(card, m));
    card.querySelectorAll("[data-stripe-po]").forEach(b => b.addEventListener("click", () => accionStripe(card, { accion: "casar_payout", po: b.dataset.stripePo, movimiento_id: m.movimiento_id },
      r => r && r.casado === false ? "No casó: sigue en la bandeja" : `Casado con el depósito de Stripe ${b.dataset.stripePo}`)));
    // (fase 9) la tarjeta de la mano de obra, o el enlace «Repartir por sus horas» de un pago a una persona
    if (card.dataset.jr) { wireJornal(card, m); return; }
    wireRepartirLink(card, m);
    wireIA(card, m);
  }
  // (7c) la cadena trae propuestas: se repinta SOLO cada fila cuya propuesta cambió (su chip aparece, su «Según la IA» se llena).
  // La lista, su orden, el desplazamiento y la fila que Edgar tiene a medias (eligió o escribió algo, abrió «Otra cosa…», tiene
  // el foco dentro) no se tocan: lo suyo se queda y su propuesta nueva sale en la próxima pintada. Proponer no cambia lo que el
  // banco trajo (v_banco_bandeja), así que las filas son las mismas; si la IA dejó de cuadrar, la lista entera, sin la IA
  // (sin propuesta pendiente, la fila también cambia cuando la cadena empieza o acaba: su «Proponer ahora» se apaga o vuelve)
  const claveIA = m => {
    // (fase 9) la tarjeta de la mano de obra no enseña la IA: la cadena nunca la repinta
    if (jrDe(m)) return "jr";
    const f = iaFilaDe(m), corre = S.cadena && S.cadena.activa ? ":c" : "";
    return !iaViva() ? "x" : f && f.estado === "pendiente" ? `${f.propuesta_id}:pendiente` : `${f ? `${f.propuesta_id}:${f.estado}` : "-"}${corre}`;
  };
  function refrescarFilasIA() {
    const cont = $("ct-bj-lista"); if (!cont) return;
    if (!iaViva()) { pintarListaBandeja(); return; }
    cont.querySelectorAll(".ct-mov").forEach(card => {
      const m = (S.bandeja || []).find(f => f.movimiento_id === card.dataset.id);
      if (!m || card.dataset.ia === claveIA(m)) return;
      const det = card.querySelector(".ct-mov-det"), forma = card.querySelector(".ct-form");
      if (card.dataset.tocada === "1" || (det && det.contains(document.activeElement)) || (forma && !forma.hidden)) return;
      const t = document.createElement("template"); t.innerHTML = movHTML(m).trim();
      const nueva = t.content.firstElementChild;
      card.replaceWith(nueva); wireMov(nueva, m);
    });
  }
  // una sola fila desplegada: la tocada se abre (su grupo también) y la anterior se cierra, sin repintar la lista
  function desplegar(id) {
    S.bj.abierta = id;
    let abierta = null;
    main().querySelectorAll(".ct-mov").forEach(card => {
      const si = !!id && card.dataset.id === id;
      card.classList.toggle("abierta", si);
      card.querySelector(".ct-mov-fila").setAttribute("aria-expanded", si ? "true" : "false");
      card.querySelector(".ct-mov-det").hidden = !si;
      if (si) abierta = card;
    });
    if (abierta) {
      const g = abierta.closest("details"); if (g) g.open = true;
      if (typeof abierta.scrollIntoView === "function") abierta.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }
  function grupoHTML(k, ms) {
    const cuentas = [...new Set(ms.map(m => m.cuenta_nombre))], total = sumaMonto(ms);
    const abierto = ms.some(m => m.movimiento_id === S.bj.abierta);
    return `<details class="ct-grupo" data-grupo="${esc(k)}"${abierto ? " open" : ""}><summary class="ct-grupo-cab">
        <span class="ct-g-desc"><b>${esc(k)}</b><small>${esc(cuentas.join(" · "))}</small></span>
        <span class="ct-g-n">${plural(ms.length, "movimiento", "movimientos")}${ms.some(m => m.alarma) ? ` ${pill("más de 30 días", "bad")}` : ""}</span>
        <span class="ct-g-monto ct-num ${total < 0 ? "neg" : "pos"}">${total < 0 ? "−" : "+"}${fmtAbs(total)}</span>
        <span class="ct-f-chev" aria-hidden="true"></span>
      </summary><div class="ct-grupo-filas">${ms.map(movHTML).join("")}</div></details>`;
  }

  // Una fila del feed: la cabecera compacta (un botón, accesible) y debajo el detalle plegado con el texto, los avisos y los botones de siempre.
  // El <article class="ct-mov" data-id> sigue siendo el contenedor del movimiento: abrirOpcion, abrirOtra y montarForma buscan en él su .ct-form
  function movHTML(m) {
    const neg = num(m.monto) < 0;
    const ops = Array.isArray(m.opciones) ? m.opciones : [];
    const obra = obraTexto(m.obra);
    const abierta = m.movimiento_id === S.bj.abierta;
    const id = esc(m.movimiento_id);
    // (fase 9) un pago a una persona que cobra por horas: la tarjeta de la mano de obra en lugar de las opciones de siempre
    const jr = jrDe(m);
    return `<article class="ct-mov${m.alarma ? " alarma" : ""}${abierta ? " abierta" : ""}${jr ? " ct-mov-jr" : ""}" data-id="${id}" data-ia="${esc(claveIA(m))}"${jr ? ` data-jr="1"` : ""}>
      <button type="button" class="ct-mov-fila" aria-expanded="${abierta ? "true" : "false"}" aria-controls="ct-det-${id}">
        <span class="ct-f-main">
          <span class="ct-f-desc" title="${esc(m.descripcion || "")}"><b>${esc(m.descripcion || "(sin descripción)")}</b>${m.memo ? `<small>${esc(m.memo)}</small>` : ""}</span>
          <span class="ct-f-monto ct-num ${neg ? "neg" : "pos"}">${neg ? "−" : "+"}${fmtAbs(m.monto)}</span>
          <span class="ct-f-chev" aria-hidden="true"></span>
        </span>
        <span class="ct-f-meta">
          <span class="ct-f-fecha ct-num">${fechaLarga(m.fecha)}</span>
          <span class="ct-f-cuenta">${esc(m.cuenta_nombre)}</span>
          <span class="ct-f-motivo">${jr ? `${pill(`Mano de obra · ${jr.persona}`, "cu")}${jr.puede ? "" : pill(jr.corto || "Falta algo", "warn")}` : `${pill(motivoLlano(m.motivo), m.motivo === "posible_duplicado" || m.motivo === "quitada" ? "warn" : "")}${chipIA(m)}`}${m.alarma ? pill("más de 30 días", "bad") : ""}${m._esStripe ? pill("Stripe", "cu") : ""}</span>
        </span>
      </button>
      <div class="ct-mov-det" id="ct-det-${id}"${abierta ? "" : " hidden"}>
        <div class="ct-meta"><span>hace ${plural(m.dias, "día", "días")}</span>${m.cheque ? `<span>cheque ${esc(m.cheque)}</span>` : ""}${m.tipo_banco ? `<span>${esc(m.tipo_banco)}</span>` : ""}${m.origen ? `<span>entró por ${esc(m.origen)}</span>` : ""}${obra ? pill("obra: " + obra) : ""}</div>
        ${jr ? jornalHTML(m, jr) : `<p class="ct-texto">${esc(m.texto)}</p>${repartirLinkHTML(m)}`}
        ${jr ? "" : `${m._esStripe ? `<p class="ct-aviso warn ct-aviso-dep">Depósito de Stripe: casa solo con su depósito en «Cobros en línea» (cuando Stripe mande su detalle${(m._stripe || []).length ? ", o con «Es el depósito…» aquí abajo" : ""}). No lo clasifiques ni lo registres aquí: el dinero entraría dos veces. Si es de antes de instalar los cobros en línea, sácalo allí con «Ya está en el libro» y vuelve aquí.</p>` : ""}
        ${m._stripeFuera ? `<p class="ct-aviso ct-aviso-dep">Depósito de Stripe de fuera de la app (${esc(m._stripeFuera.fuera_motivo || "ya está en el libro")}): regístralo aquí como siempre.</p>` : ""}
        ${m.posible_duplicado_de ? `<p class="ct-aviso warn">Se parece al del ${fecha(m.duplicado_fecha)} «${esc(m.duplicado_descripcion)}»${m.duplicado_origen ? ` (entró por ${esc(m.duplicado_origen)})` : ""}.</p>` : ""}
        ${iaBloqueHTML(m)}
        <div class="ct-acciones">${(m._stripe || []).map(q => `<button type="button" class="accion" data-stripe-po="${esc(q.po)}">Es el depósito de Stripe del ${fechaLarga(q.llegada)}: casarlo</button>`).join("")}${ops.map((o, i) => `<button type="button" class="accion${i || (m._stripe || []).length ? " secundaria" : ""}" data-op="${i}">${esc(o.texto)}</button>`).join("")}
          ${m._esStripe ? "" : `<button type="button" class="accion secundaria ct-otra" data-otra>Otra cosa…</button>`}</div>
        <div class="ct-form" hidden></div>
        ${m._esStripe ? `<div class="ct-stripe-res"></div>` : ""}`}
      </div>
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
    const apagados = [...card.querySelectorAll("button")].filter(b => !b.disabled);
    apagados.forEach(b => { b.disabled = true; });
    try {
      const r = await DB._rpc(fn, args);
      S.hooks.avisar(resumenHecho(r));
      S.saldos = null;
      await pintarBandeja();
    } catch (err) {
      card.classList.remove("ocupado");
      apagados.forEach(b => { b.disabled = false; });
      mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se guardó. Vuelve a intentarlo con señal." : err.message);
    } finally { S.ocupado = false; }
  }

  // ============================================================
  // LA MANO DE OBRA EN LA BANDEJA (c10, fase 9) — docs/conta/c10-costo-obra.sql
  //
  // Edgar paga a sus ayudantes por Zelle: el lunes, la semana anterior; el
  // viernes, la semana en curso. Ese Zelle no es de una obra: es su semana,
  // repartida entre las obras donde estuvo. La base lo reconoce (la persona
  // dada de alta y su patrón contra la descripción del banco: la lista es
  // v_jornal_pendientes) y lo reparte por SUS HORAS al centavo; la pantalla
  // solo lo enseña y manda lo que Edgar vio:
  //   · LA TARJETA «Mano de obra · persona» sale en lugar de las opciones de
  //     siempre (y sin la IA: su propuesta lleva una obra, y esto son varias).
  //     Arriba el período con tres botones de un toque (Semana anterior,
  //     Esta semana, Otras fechas): cada uno vuelve a pedir la propuesta
  //     (fn_jornal_propuesta) con esas fechas. Debajo la tabla del reparto
  //     (obra, su CO si lo hay, horas y dólares; el total ES el pago, y se
  //     dice), lo sin obra con su cuenta (o el campo para decirla UNA vez,
  //     que guarda fn_jornal_config), «sale a $X la hora (su tarifa: $Y)» en
  //     ámbar si la base avisa, y cada aviso de la base tal cual.
  //   · «ASÍ ES» pide el código del teléfono y manda fn_jornal_aplicar con
  //     las fechas y la HUELLA (visto) de lo que se ve: la base aprueba esas
  //     horas y registra el pago repartido en una transacción. Si las horas
  //     cambiaron entre que Edgar miró y tocó (MX011) no se hizo nada: se
  //     recalcula y se le enseña otra vez, dicho. Si el banco (c6) frena con
  //     «…dilo en el motivo», sale el campo del motivo y se reintenta con la
  //     MISMA huella. Si la IA (c8) tenía una propuesta abierta para ese pago,
  //     se rechaza por la función de borde «contador» (la base lo pide así).
  //   · SIN HORAS en esas fechas: lo dice, deja cambiar las fechas o «No es
  //     mano de obra», que devuelve la tarjeta de siempre (en memoria: al
  //     volver a abrir la app, la base lo vuelve a reconocer).
  //   · En un pago normal por Zelle (o Venmo, Cash App, PayPal) a alguien que
  //     la base no reconoce: un enlace discreto «Repartir por sus horas» para
  //     darlo de alta eligiéndolo de la cuadrilla (fn_jornal_persona con el
  //     movimiento: la base saca el patrón de su descripción).
  // Sin c10 pegado (las vistas no existen) la bandeja sigue como antes. Si
  // contesta con otro error, la franja lo dice en rojo: nunca se calla.
  // ============================================================
  const faltaC10 = err => !!err && (err.status === 404 || ["PGRST205", "PGRST202", "42P01", "42883"].includes(String(err.codigo || "")));
  // los avisos que no dejan aplicar (los demás son para saber, no frenan)
  const AVISOS_FRENAN = ["sin_horas", "falta_cuenta_sin_obra", "cuenta_mal", "posible_duplicado", "reparto_suelto"];
  const nHoras = v => { const n = num(v); return n == null || Number.isNaN(n) ? "—" : n.toLocaleString("en-US", { maximumFractionDigits: 2 }); };
  const horasTxt = v => `${nHoras(v)} h`;
  const cent2 = v => Math.round((num(v) || 0) * 100);
  const jrDe = m => (S.jr.instalado && m && !S.jr.no.has(m.movimiento_id) && S.jr.pend.get(m.movimiento_id)) || null;
  // el lunes y el domingo de la semana de una fecha, y de la anterior (la regla de la base: lunes a domingo)
  const diaMas = (iso, n) => { const [a, m, d] = partes(iso); return new Date(Date.UTC(a, m - 1, d + n)).toISOString().slice(0, 10); };
  function semanasDe(iso) {
    const [a, m, d] = partes(iso), dow = (new Date(Date.UTC(a, m - 1, d)).getUTCDay() + 6) % 7, lunes = diaMas(iso, -dow);
    return { esta: [lunes, diaMas(lunes, 6)], anterior: [diaMas(lunes, -7), diaMas(lunes, -1)] };
  }
  const rangoCorto = (de, a) => `${fecha(de)} – ${fecha(a)}`;

  // Una fila de v_jornal_pendientes (plana) o una respuesta de fn_jornal_propuesta (con movimiento, persona y periodo
  // anidados), con la misma forma para pintar. `mano`: la pidió Edgar con otras fechas (se conserva al repintar la bandeja)
  function normalJr(x, deVista) {
    const lineas = Array.isArray(x.lineas) ? x.lineas : [];
    const avisos = Array.isArray(x.avisos) ? x.avisos : [];
    const mov = deVista ? null : (x.movimiento || {}), per = deVista ? null : (x.periodo || {}), per0 = deVista ? null : (x.persona || {});
    const monto = Math.abs(num(deVista ? x.monto : mov.monto) || 0);
    const enObras = lineas.reduce((s, l) => s + cent2(l.monto), 0);
    let sinObra = null;
    if (!deVista && x.sin_obra) sinObra = { horas: num(x.sin_obra.horas), monto: num(x.sin_obra.monto), cuenta: x.sin_obra.cuenta || null, falta: !!x.sin_obra.falta_cuenta };
    // la vista no trae la parte sin obra: son sus horas y lo que falta para el pago (la base reparte el pago entero)
    else if (deVista && num(x.horas_sin_obra) > 0) sinObra = { horas: num(x.horas_sin_obra), monto: (Math.round(monto * 100) - enObras) / 100, cuenta: (S.jr.cfg && S.jr.cfg.cuenta_sin_obra) || null, falta: avisos.some(a => a.codigo === "falta_cuenta_sin_obra") };
    const frena = avisos.find(a => AVISOS_FRENAN.includes(a.codigo));
    return {
      mov: deVista ? x.movimiento_id : mov.id, monto, mano: !deVista,
      persona: deVista ? x.persona : per0.nombre, usuario: deVista ? x.usuario_id : per0.usuario_id,
      tarifa: num(deVista ? x.tarifa : (x.tarifa_equipo != null ? x.tarifa_equipo : per0.tarifa)),
      desde: String(deVista ? x.desde : per.desde).slice(0, 10), hasta: String(deVista ? x.hasta : per.hasta).slice(0, 10),
      texto: deVista ? x.periodo_texto : per.texto, opcionesPer: deVista ? null : (Array.isArray(per.opciones) ? per.opciones : null),
      horas: num(x.horas), reportes: num(x.reportes), obras: num(x.obras), lineas, sinObra,
      tarifaSale: num(x.tarifa_sale), avisos, puede: x.puede_aplicar === true, porQue: x.por_que || null, visto: x.visto || "",
      propuestaIA: x.propuesta_ia || null, incluir: !!(x.opciones && x.opciones.incluir_cubiertas), cubiertas: deVista ? null : (x.cubiertas || null),
      corto: (frena || avisos[0] || {}).corto || null, nota: null
    };
  }
  // los pagos que la base reconoce, su configuración y su control (sin c10: nada; otro error: la franja lo dice en rojo)
  async function leerJornalBandeja() {
    S.jr.err = null;
    try {
      const [filas, cfg, ctl] = await Promise.all([
        DB._leer("v_jornal_pendientes?select=*&order=fecha.asc,movimiento_id.asc"),
        DB._leer("jornal_config?select=*"),
        DB._leer("v_jornal_control?select=*&order=orden.asc")
      ]);
      S.jr.instalado = true; S.jr.cfg = (cfg || [])[0] || null; S.jr.control = Array.isArray(ctl) ? ctl : [];
      const antes = S.jr.pend; S.jr.pend = new Map();
      // lo que Edgar pidió con otras fechas se queda mientras el pago siga esperando (su huella la vuelve a mirar la base al aplicar)
      for (const f of filas) { const prev = antes.get(f.movimiento_id); S.jr.pend.set(f.movimiento_id, prev && prev.mano ? prev : normalJr(f, true)); }
      for (const id of [...S.jr.no]) if (!S.jr.pend.has(id)) S.jr.no.delete(id);
    } catch (err) {
      if (esFalloDeRed(err)) throw err;
      S.jr.instalado = false; S.jr.pend = new Map(); S.jr.control = null;
      if (!faltaC10(err)) S.jr.err = err;
    }
  }
  // La franja de la mano de obra, arriba de la bandeja: cuántos pagos esperan su reparto, sus cuadres en rojo, o que no contestó
  function franjaJornalHTML(filas) {
    if (S.jr.err) return `<section class="ct-card ct-jr-franja" role="alert"><p class="ct-aviso bad">El reparto de la mano de obra no contestó: ${esc(S.jr.err.message)}. Hasta que conteste, los pagos a la cuadrilla salen como movimientos normales: si son por horas, no los clasifiques a mano todavía.</p></section>`;
    if (!S.jr.instalado) return "";
    const suyos = (filas || []).filter(f => jrDe(f)), rojos = (S.jr.control || []).filter(f => f.nivel === "cuadre" && f.ok !== true);
    if (!suyos.length && !rojos.length && !S.bj.soloJr) return "";
    const total = suyos.reduce((s, f) => s + Math.abs(num(f.monto) || 0), 0);
    return `<section class="ct-card ct-jr-franja" id="ct-jr-franja">
      <div class="ct-jr-franja-fila"><p>${suyos.length ? `<b>${plural(suyos.length, "pago de mano de obra espera", "pagos de mano de obra esperan")}</b> su reparto por horas · <span class="ct-num">${fmt(total)}</span>` : "Ningún pago de mano de obra espera su reparto."}</p>
        ${suyos.length || S.bj.soloJr ? `<button type="button" class="accion secundaria chica" id="ct-jr-ver" aria-pressed="${S.bj.soloJr ? "true" : "false"}">${S.bj.soloJr ? "Ver todos" : "Ver solo esos"}</button>` : ""}</div>
      ${rojos.map(f => `<p class="ct-aviso bad">${esc(cap(String(f.cuadre || "").replace(/^jornal: /, "")))}: ${esc(f.detalle || "no cuadra")} <button type="button" class="ct-jr-link" data-ir="obras" data-ir-sub="repartos">Ver los repartos</button></p>`).join("")}
    </section>`;
  }

  // ---------- la tarjeta ----------
  function jornalHTML(m, jr) {
    const sem = semanasDe(m.fecha);
    const cual = jr.desde === sem.anterior[0] && jr.hasta === sem.anterior[1] ? "anterior" : jr.desde === sem.esta[0] && jr.hasta === sem.esta[1] ? "esta" : "otras";
    // las horas de cada semana, si la propuesta las trajo (la de la vista no las trae)
    const horasDe = ([de, a]) => { const o = (jr.opcionesPer || []).find(x => String(x.desde).slice(0, 10) === de && String(x.hasta).slice(0, 10) === a); return o ? ` · ${horasTxt(o.horas)}` : ""; };
    const chip = (k, txt, r) => `<button type="button" class="ct-chip ct-jr-chip" data-jr-per="${k}" aria-pressed="${cual === k ? "true" : "false"}">${esc(txt)}${r ? `<small class="ct-num">${esc(rangoCorto(r[0], r[1]))}${esc(horasDe(r))}</small>` : ""}</button>`;
    const tarifaLejos = jr.avisos.some(a => a.codigo === "tarifa_lejos");
    const sinHoras = jr.avisos.some(a => a.codigo === "sin_horas") || !(num(jr.horas) > 0);
    const hayCubiertas = jr.avisos.some(a => a.codigo === "horas_cubiertas") || jr.incluir;
    const falta = !!(jr.sinObra && jr.sinObra.falta) || jr.avisos.some(a => a.codigo === "falta_cuenta_sin_obra");
    const total = jr.lineas.reduce((s, l) => s + cent2(l.monto), 0) + (jr.sinObra ? cent2(jr.sinObra.monto) : 0);
    const cuadra = total === Math.round(jr.monto * 100);
    const filasT = jr.lineas.map(l => `<tr><td class="ct-jr-obra">${esc(l.obra || l.proyecto_id || "")}${l.co ? `<small>${esc(l.co)}</small>` : ""}${["completado", "cancelado"].includes(l.obra_estado) ? ` ${pill(l.obra_estado === "cancelado" ? "cancelada" : "terminada", "warn")}` : ""}</td><td class="r ct-num" data-col="Horas">${horasTxt(l.horas)}</td><td class="r ct-num" data-col="Dólares">${fmt(l.monto)}</td></tr>`).join("") +
      (jr.sinObra ? `<tr class="ct-jr-sinobra"><td class="ct-jr-obra">Sin obra<small>${jr.sinObra.cuenta ? `va a ${esc(jr.sinObra.cuenta)} ${esc(nombreCuenta(jr.sinObra.cuenta) === jr.sinObra.cuenta ? "" : nombreCuenta(jr.sinObra.cuenta))}` : "falta decir a qué cuenta va"}</small></td><td class="r ct-num" data-col="Horas">${horasTxt(jr.sinObra.horas)}</td><td class="r ct-num" data-col="Dólares">${fmt(jr.sinObra.monto)}</td></tr>` : "");
    const tabla = jr.lineas.length || jr.sinObra ? `<div class="ct-jr-tabla-env"><table class="ct-jr-tabla"><thead><tr><th>Obra</th><th class="r">Horas</th><th class="r">Dólares</th></tr></thead>
        <tbody>${filasT}</tbody>
        <tfoot><tr><td>Total${num(jr.obras) ? ` · ${plural(jr.obras, "obra", "obras")}` : ""}</td><td class="r ct-num" data-col="Horas">${horasTxt(jr.horas)}</td><td class="r ct-num" data-col="Dólares">${fmt(total / 100)}</td></tr></tfoot></table></div>
      <p class="ct-jr-cuadra ${cuadra ? "ok-txt" : "bad-txt"}">${cuadra ? `El total es el pago: ${fmt(jr.monto)}.` : `El reparto suma ${fmt(total / 100)} y el pago es ${fmt(jr.monto)}: no cuadra, no lo aceptes y avisa.`}</p>` : "";
    const tarifa = jr.tarifaSale != null ? `<p class="ct-jr-tarifa${tarifaLejos ? " lejos" : ""}">Sale a <b class="ct-num">${fmt(jr.tarifaSale)} la hora</b> (${jr.tarifa != null ? `su tarifa: <span class="ct-num">${fmt(jr.tarifa)}</span>` : "sin tarifa en Costos del equipo"})</p>` : "";
    // el porqué de lo que frena, si no es ya uno de los avisos
    const porQue = !jr.puede && jr.porQue && !jr.avisos.some(a => a.texto === jr.porQue) ? `<p class="ct-aviso warn">${esc(jr.porQue)}</p>` : "";
    const sinCodigo = !mfaActivo();
    return `<div class="ct-jr" data-jr-bloque>
      <div class="ct-jr-cab"><h3>Mano de obra · ${esc(jr.persona)}</h3>${jr.tarifa != null ? `<span class="ct-sub">tarifa ${fmt(jr.tarifa)}/h</span>` : ""}</div>
      ${jr.nota ? `<p class="ct-aviso warn ct-jr-nota" role="status">${esc(jr.nota)}</p>` : ""}
      <p class="ct-jr-que">Pago de <b class="ct-num">${fmt(jr.monto)}</b> repartido por sus horas ${esc(jr.texto || rangoCorto(jr.desde, jr.hasta))}${num(jr.reportes) ? ` (${plural(jr.reportes, "reporte", "reportes")})` : ""}.</p>
      <div class="ct-chips ct-jr-pers" role="group" aria-label="Qué fechas paga">${chip("anterior", "Semana anterior", sem.anterior)}${chip("esta", "Esta semana", sem.esta)}${chip("otras", "Otras fechas", null)}</div>
      <form class="ct-jr-fechas" data-jr-fechas novalidate${cual === "otras" ? "" : " hidden"}>
        <label class="ct-campo">Desde<input type="date" name="desde" value="${esc(jr.desde)}" required></label>
        <label class="ct-campo">Hasta<input type="date" name="hasta" value="${esc(jr.hasta)}" required></label>
        <div class="ct-acciones"><button type="submit" class="accion secundaria">Repartir con estas fechas</button></div>
      </form>
      ${sinHoras ? `<p class="ct-jr-vacio">Sin horas reportadas ${esc(jr.texto || "en esas fechas")}: elige otras fechas arriba o, si este pago no es por horas, «No es mano de obra».</p>` : tabla}
      ${sinHoras ? "" : tarifa}
      ${jr.avisos.length ? `<ul class="ct-jr-avisos">${jr.avisos.map(a => `<li class="ct-aviso ${AVISOS_FRENAN.includes(a.codigo) ? "warn" : a.codigo === "tarifa_lejos" ? "warn" : ""}" data-aviso="${esc(a.codigo)}">${esc(a.texto || a.corto)}</li>`).join("")}</ul>` : ""}
      ${porQue}
      ${hayCubiertas ? `<label class="ct-casilla ct-jr-cubiertas"><input type="checkbox" data-jr-cubiertas${jr.incluir ? " checked" : ""}> Es otro pago de las mismas horas: repartirlo también por las que ya tienen pago</label>` : ""}
      ${falta ? `<form class="ct-jr-cuenta" data-jr-cuenta novalidate><p class="ct-form-t">¿A qué cuenta va la mano de obra sin obra?</p>
          <p class="ct-nota">Se dice una vez y vale para todos los pagos. Mientras el CPA no decida una cuenta propia, lo provisional es 7900 Otros gastos; o ponles su obra a esas horas en Horas y vuelve a mirar.</p>
          <label class="ct-campo">Cuenta<select name="cuenta" required><option value="">Elige la cuenta…</option>${opcionesSinObra("")}</select></label>
          <div class="ct-acciones"><button type="submit" class="accion secundaria">Guardar la cuenta</button></div></form>` : ""}
      <label class="ct-campo ct-jr-motivo" hidden>Motivo (lo pide el banco; queda escrito en el libro)<textarea name="jr_motivo" rows="2"></textarea></label>
      <div class="ct-acciones">
        <button type="button" class="accion" data-jr-asi${jr.puede && !sinCodigo && cuadra ? "" : " disabled"}>✓ Así es: repartir ${fmt(jr.monto)}</button>
        <button type="button" class="accion secundaria" data-jr-no>No es mano de obra</button>
        ${jr.avisos.some(a => a.codigo === "reparto_suelto") ? `<button type="button" class="accion secundaria" data-ir="obras" data-ir-sub="repartos">Ver los repartos</button>` : ""}
      </div>
      ${sinCodigo ? `<p class="ct-nota">«Así es» registra en el libro: pide entrar con el código del teléfono (Conexiones y seguridad).</p>` : ""}
      <div class="ct-jr-res"></div>
    </div>`;
  }
  // las cuentas que admite lo sin obra (la base vuelve a validar): costo o gasto sin obra obligatoria, nunca nómina (50xx) ni sueldo
  function opcionesSinObra(sel) {
    return (S.cuentas || []).filter(c => ["costo", "gasto", "otro_gasto"].includes(c.tipo) && c.regla_obra !== "obligatoria" && !/^50/.test(c.codigo) && !["6000", "6005"].includes(c.codigo))
      .map(c => `<option value="${esc(c.codigo)}"${c.codigo === sel ? " selected" : ""}>${esc(c.codigo)} · ${esc(c.nombre)}${c.codigo === "7900" ? " (lo provisional)" : ""}</option>`).join("");
  }
  // repintar solo esta fila (desplegada), con lo que haya ahora en S.jr
  function reemplazarFila(m) {
    S.bj.abierta = m.movimiento_id;
    const viejo = [...document.querySelectorAll("#ct-bj-lista .ct-mov")].find(c => c.dataset.id === m.movimiento_id); if (!viejo) return null;
    const t = document.createElement("template"); t.innerHTML = movHTML(m).trim();
    const nueva = t.content.firstElementChild; viejo.replaceWith(nueva); wireMov(nueva, m);
    return nueva;
  }
  const resJr = card => card.querySelector(".ct-jr-res") || resCaja(card, "ct-jr-res");
  function errorJr(card, err) {
    const r = resJr(card);
    if (esFalloDeRed(err) || !navigator.onLine) { r.innerHTML = `<p class="ct-aviso bad">Sin señal: no se hizo nada. Vuelve a intentarlo con señal.</p>`; return; }
    if (err.codigo === "MFA" || err.mfa) { r.innerHTML = `<p class="ct-aviso warn">Falta el código del teléfono: sal y vuelve a entrar con él.</p>`; return; }
    r.innerHTML = `<p class="ct-aviso ${/^(MX|22023|42501)/.test(String(err.codigo || "")) ? "warn" : "bad"} ct-error">${esc(err.message)}</p>`;
  }
  function wireJornal(card, m) {
    const bl = card.querySelector("[data-jr-bloque]"); if (!bl) return;
    const jr = jrDe(m); if (!jr) return;
    const sem = semanasDe(m.fecha), fechas = bl.querySelector("[data-jr-fechas]");
    const opc = () => (jr.incluir ? { incluir_cubiertas: true } : {});
    bl.querySelectorAll("[data-jr-per]").forEach(b => b.addEventListener("click", () => {
      const k = b.dataset.jrPer;
      if (k === "otras") { fechas.hidden = false; bl.querySelectorAll("[data-jr-per]").forEach(x => x.setAttribute("aria-pressed", String(x === b))); fechas.querySelector("input").focus(); return; }
      const [de, a] = k === "esta" ? sem.esta : sem.anterior;
      recalcJr(card, m, de, a, opc());
    }));
    fechas.addEventListener("submit", ev => {
      ev.preventDefault();
      const de = fechas.desde.value, a = fechas.hasta.value;
      if (!de || !a) { resJr(card).innerHTML = `<p class="ct-aviso warn ct-error">Pon las dos fechas: desde y hasta.</p>`; return; }
      if (de > a) { resJr(card).innerHTML = `<p class="ct-aviso warn ct-error">Las fechas están al revés: «desde» va antes que «hasta».</p>`; return; }
      recalcJr(card, m, de, a, opc());
    });
    const cub = bl.querySelector("[data-jr-cubiertas]");
    if (cub) cub.addEventListener("change", () => recalcJr(card, m, jr.desde, jr.hasta, cub.checked ? { incluir_cubiertas: true } : {}));
    const fc = bl.querySelector("[data-jr-cuenta]");
    if (fc) fc.addEventListener("submit", async ev => {
      ev.preventDefault();
      const cuenta = fc.cuenta.value;
      if (!cuenta) { resJr(card).innerHTML = `<p class="ct-aviso warn ct-error">Elige la cuenta.</p>`; fc.cuenta.focus(); return; }
      if (S.ocupado) return;
      S.ocupado = true; card.classList.add("ocupado");
      try { S.jr.cfg = await DB._rpc("fn_jornal_config", { p: { cuenta_sin_obra: cuenta } }); }
      catch (err) { S.ocupado = false; card.classList.remove("ocupado"); errorJr(card, err); return; }
      S.ocupado = false;
      S.hooks.avisar(`La mano de obra sin obra va a ${cuenta} desde ahora`);
      recalcJr(card, m, jr.desde, jr.hasta, opc());
    });
    bl.querySelector("[data-jr-no]").addEventListener("click", () => { S.jr.no.add(m.movimiento_id); reemplazarFila(m); });
    bl.querySelectorAll("[data-ir]").forEach(b => b.addEventListener("click", () => ir(b.dataset.ir, b.dataset.irSub ? { sub: b.dataset.irSub } : {})));
    const asi = bl.querySelector("[data-jr-asi]");
    asi.addEventListener("click", () => {
      const mot = bl.querySelector(".ct-jr-motivo");
      if (mot && !mot.hidden) {
        const t = String(mot.querySelector("textarea").value || "").trim();
        if (!t) { resJr(card).innerHTML = `<p class="ct-aviso warn ct-error">Escribe el motivo: el banco lo pide para registrarlo.</p>`; mot.querySelector("textarea").focus(); return; }
        return aplicarJr(card, m, t);
      }
      aplicarJr(card, m, null);
    });
  }
  // Las mismas fechas u otras: la base vuelve a calcular el reparto (y su huella) y se repinta la tarjeta. `nota`: por qué se recalculó
  async function recalcJr(card, m, desde, hasta, opciones, nota) {
    if (S.ocupado) return;
    if (!navigator.onLine) { resJr(card).innerHTML = `<p class="ct-aviso bad">Sin señal: no se recalculó nada.</p>`; return; }
    S.ocupado = true; card.classList.add("ocupado");
    resJr(card).innerHTML = `<p class="ct-aviso" role="status">Repartiendo con sus horas…</p>`;
    let p;
    try { p = await DB._rpc("fn_jornal_propuesta", { p_movimiento: m.movimiento_id, p_desde: desde, p_hasta: hasta, p_opciones: opciones || {} }); }
    catch (err) { S.ocupado = false; card.classList.remove("ocupado"); errorJr(card, err); return; }
    S.ocupado = false;
    if (!p || p.reconocido !== true) {
      S.jr.pend.delete(m.movimiento_id);
      S.hooks.avisar(p && p.por_que ? p.por_que : "Este pago ya no se reconoce como mano de obra: sale como un movimiento normal", true);
      reemplazarFila(m); return;
    }
    const jr = normalJr(p, false); jr.nota = nota || null;
    S.jr.pend.set(m.movimiento_id, jr);
    reemplazarFila(m);
  }
  // «Así es»: las fechas y la huella de lo que Edgar ve; el motivo solo si el banco lo pidió
  async function aplicarJr(card, m, motivo) {
    const jr = jrDe(m); if (!jr || S.ocupado) return;
    if (!navigator.onLine) { resJr(card).innerHTML = `<p class="ct-aviso bad">Sin señal: no se hizo nada.</p>`; return; }
    if (!mfaActivo()) { resJr(card).innerHTML = `<p class="ct-aviso warn">Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: registrar un pago repartido lo pide.</p>`; return; }
    if (!jr.puede) { resJr(card).innerHTML = `<p class="ct-aviso warn">${esc(jr.porQue || "La base no deja repartir este pago así: mira los avisos.")}</p>`; return; }
    const opciones = {};
    if (jr.incluir) opciones.incluir_cubiertas = true;
    if (motivo) opciones.motivo = motivo;
    S.ocupado = true;
    const apagados = [...card.querySelectorAll("button, input, select, textarea")].filter(b => !b.disabled);
    apagados.forEach(b => { b.disabled = true; });
    resJr(card).innerHTML = `<p class="ct-aviso ct-espera" role="status">Aprobando sus horas y registrándolo en el libro…</p>`;
    let r;
    try { r = await DB._rpc("fn_jornal_aplicar", { p_movimiento: m.movimiento_id, p_desde: jr.desde, p_hasta: jr.hasta, p_visto: jr.visto, p_opciones: opciones }); }
    catch (err) {
      S.ocupado = false; apagados.forEach(b => { b.disabled = false; });
      // las horas cambiaron entre que miró y que tocó: no se hizo nada; se recalcula y se le enseña otra vez
      if (err.codigo === "MX011") return recalcJr(card, m, jr.desde, jr.hasta, jr.incluir ? { incluir_cubiertas: true } : {},
        "Las horas cambiaron entre que miraste y que tocaste (alguien reportó, cambió o borró horas): no se aprobó ni se registró nada. Esto es lo de ahora: míralo y vuelve a tocar «Así es».");
      // el banco (c6) frena hasta que Edgar diga por qué: el campo del motivo y otra vez «Así es», con la misma huella
      if (/dilo en el motivo/i.test(String(err.message || ""))) {
        const mot = card.querySelector(".ct-jr-motivo"); if (mot) mot.hidden = false;
        resJr(card).innerHTML = `<p class="ct-aviso warn">${esc(err.message)}</p><p class="ct-nota">Si de verdad es su pago por horas, escribe el motivo arriba y vuelve a tocar «Así es».</p>`;
        if (mot) mot.querySelector("textarea").focus();
        return;
      }
      errorJr(card, err); return;
    }
    S.ocupado = false;
    // la IA (c8) tenía una propuesta abierta para este pago: se rechaza por su función (c8 no la cierra sola)
    let iaAbierta = false;
    if (r && r.propuesta_ia) {
      try { await DB._funcion("contador", { accion: "rechazar", propuesta: r.propuesta_ia, motivo: "Es mano de obra: se repartió por sus horas" }, 30000); }
      catch (e) { iaAbierta = true; }
    }
    const asiento = r && r.asiento ? r.asiento.numero : "";
    S.hooks.avisar(`${r && r.nota ? r.nota : `Repartido${asiento ? ` · asiento ${asiento}` : ""}`}${r && r.tardio ? ` ${r.tardio}` : ""}${iaAbierta ? " · Ojo: la propuesta de la IA para este pago sigue abierta; recházala en la Bandeja." : ""}`, iaAbierta);
    S.jr.pend.delete(m.movimiento_id); S.saldos = null;
    await pintarBandeja();
  }

  // ---------- «Repartir por sus horas» en un pago normal a una persona ----------
  const PAGO_PERSONA = /\b(zelle|venmo|cash ?app|paypal)\b/i;
  const pagoAPersona = m => S.jr.instalado && num(m.monto) < 0 && !m._esStripe && PAGO_PERSONA.test(`${m.descripcion || ""} ${m.memo || ""}`);
  function repartirLinkHTML(m) {
    if (!pagoAPersona(m)) return "";
    // «No es mano de obra» se puede deshacer aquí mismo
    if (S.jr.no.has(m.movimiento_id) && S.jr.pend.has(m.movimiento_id)) return `<p class="ct-jr-enlace"><button type="button" class="ct-jr-link" data-jr-volver>Sí es mano de obra: repartir por sus horas</button></p>`;
    return `<p class="ct-jr-enlace"><button type="button" class="ct-jr-link" data-jr-alta>Repartir por sus horas</button> <span class="ct-sub">si es lo que cobra alguien de la cuadrilla por sus horas</span></p>`;
  }
  const patronLlano = p => String(p || "").replace(/\\[mMyb]/g, "").replace(/\s+/g, " ").trim();
  function wireRepartirLink(card, m) {
    const v = card.querySelector("[data-jr-volver]");
    if (v) v.addEventListener("click", () => { S.jr.no.delete(m.movimiento_id); reemplazarFila(m); });
    const a = card.querySelector("[data-jr-alta]"); if (!a) return;
    a.addEventListener("click", async () => {
      const f = card.querySelector(".ct-form"); f.hidden = false;
      f.innerHTML = `<p class="ct-aviso" role="status">Buscando la cuadrilla…</p>`;
      try { S.jr.personas = await DB._leer("v_jornal_personas?select=*&order=nombre.asc"); }
      catch (err) { mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se pudo leer la cuadrilla." : err.message); return; }
      const sin = S.jr.personas.filter(p => !p.registrada), bajas = S.jr.personas.filter(p => p.registrada && !p.activa);
      if (!sin.length && !bajas.length) {
        f.innerHTML = `<p class="ct-aviso warn">Toda la cuadrilla con horas en los últimos 90 días ya cobra por horas (o no hay nadie más). Si este pago es de alguien de ellos, el banco lo escribe distinto: cambia su patrón en Costo por obra → Personas.</p>
          <div class="ct-acciones"><button type="button" class="accion secundaria" data-ir="obras" data-ir-sub="personas">Ir a Personas</button><button type="button" class="accion secundaria" data-cerrar>Cerrar</button></div>`;
        f.querySelector("[data-ir]").addEventListener("click", () => ir("obras", { sub: "personas" }));
        f.querySelector("[data-cerrar]").addEventListener("click", () => { f.hidden = true; f.innerHTML = ""; });
        return;
      }
      const op = p => `<option value="${esc(p.usuario_id)}">${esc(p.nombre)}${num(p.horas_90_dias) ? ` · ${horasTxt(p.horas_90_dias)} en 90 días` : ""}</option>`;
      montarForma(card, formaHTML("¿De quién es este pago? Desde ahora sus pagos se reparten por sus horas",
        `<label class="ct-campo">Persona de la cuadrilla<select name="usuario" required><option value="">Elige la persona…</option>${sin.length ? `<optgroup label="Con horas, sin dar de alta">${sin.map(op).join("")}</optgroup>` : ""}${bajas.length ? `<optgroup label="Dadas de baja">${bajas.map(op).join("")}</optgroup>` : ""}</select></label>
         <p class="ct-nota">La base saca de este pago («${esc(m.descripcion || "")}») cómo lo escribe el banco, y con eso reconoce sus pagos de aquí en adelante.</p>`, "Repartir por sus horas"), v => {
        accionAlta(card, { usuario_id: v.usuario, movimiento_id: m.movimiento_id, activa: true });
      });
    });
  }
  async function accionAlta(card, p) {
    if (S.ocupado) return;
    if (!navigator.onLine) { mostrarErrorForma(card, "Sin señal: no se dio de alta."); return; }
    S.ocupado = true; card.classList.add("ocupado");
    let r;
    try { r = await DB._rpc("fn_jornal_persona", { p }); }
    catch (err) { S.ocupado = false; card.classList.remove("ocupado"); mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se dio de alta." : err.message); return; }
    S.ocupado = false;
    S.hooks.avisar(r && r.nota_alta ? r.nota_alta : `${(r && r.nombre) || "La persona"}: sus pagos se reparten por sus horas`);
    S.jr.no.delete(p.movimiento_id);
    await pintarBandeja();
  }

  // ---------- «Qué atender» del Resumen ----------
  async function leerJornalResumen() {
    try {
      const [pend, jc, mc] = await Promise.all([
        DB._leer("v_jornal_pendientes?select=movimiento_id,monto,persona"),
        DB._leer("v_jornal_control?select=*&order=orden.asc"),
        DB._leer("v_margen_control?select=*&order=orden.asc")
      ]);
      return { pend: pend || [], jc: jc || [], mc: mc || [] };
    } catch (err) {
      if (esFalloDeRed(err)) throw err;
      return faltaC10(err) ? null : { err };
    }
  }
  function atenderJornal(j) {
    if (!j) return [];
    if (j.err) return [{ txt: "La mano de obra y el costo por obra no contestaron: los pagos a la cuadrilla no se pueden repartir hasta que contesten.", det: j.err.message, ir: "obras" }];
    const a = [];
    if (j.pend.length) a.push({ txt: `${plural(j.pend.length, "pago de mano de obra espera", "pagos de mano de obra esperan")} su reparto por horas (${fmt(j.pend.reduce((s, f) => s + Math.abs(num(f.monto) || 0), 0))}): en la Bandeja, cada uno con su semana y sus obras.`, ir: "bandeja" });
    for (const f of j.jc) if (f.ok !== true) a.push({ txt: `Mano de obra: ${String(f.cuadre || "").replace(/^jornal: /, "")}${f.nivel === "cuadre" ? " (no cuadra)" : ""}.`, det: f.detalle, ir: "obras", sub: "repartos" });
    for (const f of j.mc) if (f.ok !== true) a.push({ txt: `Costo por obra: ${String(f.cuadre || "").replace(/^margen: /, "")}${f.nivel === "cuadre" ? " (no cuadra: la página no pinta cifras hasta que cuadre)" : ""}.`, det: f.detalle, ir: "obras", sub: "obras" });
    return a;
  }

  // ============================================================
  // LA IA CONTABLE (c8, fase 7) — docs/conta/c8-contador.sql y la función de
  // borde supabase/functions/contador. La IA PROPONE, NUNCA POSTEA. La
  // pantalla lee v_contador_estado (la franja de la bandeja y la tarjeta de
  // Conexiones), v_contador_bandeja (la propuesta de cada movimiento: la
  // pendiente o la última), v_contador_control (sus cuadres: uno en rojo y no
  // se pinta nada de la IA; sus alarmas van a «Qué atender»),
  // v_contador_cuentas (las cuentas que se pueden elegir en «Según yo»: las
  // decide la base, no esta pantalla) y v_contador_reglas (Conexiones). Lo
  // que mueve algo (proponer, «Así es», «No es eso», «Clasificar», quitar una
  // regla) se lo pide a la función con la sesión del dueño y su código del
  // teléfono: ninguna fn_contador_* está en la API y el único camino al libro
  // es fn_contador_clasificar → fn_banco_clasificar (c6), con su motivo.
  // Sin c8 pegado (las vistas no existen) la bandeja sigue como antes: sin
  // franja, sin chips y sin columnas, igual que hace con Stripe.
  //
  // LA OBRA (7b, 31-oct). La base calcula las pistas de cada cargo (las horas
  // de la cuadrilla por obra esos días, los tickets del mismo comercio, lo
  // que Edgar eligió antes para ese comercio, los materiales recientes) y la
  // IA, con ellas, propone la obra con su confianza y su porqué; sin pistas
  // claras no la adivina. La pantalla la enseña en «Según la IA» («Obra:
  // Calla Terrace · 78 %» y el motivo; sin obra, el resumen de las pistas en
  // gris), en el chip de la fila y elegida en el selector de la obra, que
  // sale siempre que una cuenta de la propuesta admite obra (obligatoria u
  // opcional); y en «Según yo» en cuanto la cuenta elegida la admite. «Así
  // es» manda la obra del selector: la misma, «aprobada»; otra, «editada».
  // Nada entra al libro sin el toque de Edgar, y las reglas no guardan la
  // obra (la siguiente vez la dicen otra vez las pistas). Una obra propuesta
  // que se cerró después (el cuadre 64) no tapa la IA: la propuesta lo dice,
  // no se preselecciona y «Así es» pide otra (o «No es eso»).
  //
  // LA 7c (31-oct, tarde: «que cada partida al lado ya tenga su propuesta» y
  // «no me sirve que solo estés seguro un 55 %»). Tres cambios aquí:
  //   · LAS PROPUESTAS SALEN SOLAS: al pintar la Bandeja (y al terminar de
  //     subir un archivo o de sincronizar con Plaid) la pantalla pide la
  //     ráfaga sola y encadena la siguiente mientras la función diga que
  //     quedan (la cadena, más abajo); «Proponer ahora» queda para pedirla a
  //     mano y el interruptor de Conexiones la apaga. La rutina de la base
  //     (pg_cron → la función, por la mañana tras el banco y por la tarde)
  //     hace lo mismo sin la app abierta.
  //   · LA OBRA, CALIBRADA: con lo medido en producción (las horas y los
  //     tickets solos aciertan cuatro de cada diez) solo una obra FUERTE
  //     (obra_fuerte de la base, o su confianza ≥ 80 %) sale elegida y va en
  //     el chip. Con una débil, sin obra o si la cuenta la pide: «¿De qué
  //     obra?» con hasta tres botones grandes (obras_top: la obra y su pista
  //     corta) y «Otra obra…» con el selector de siempre; nada elegido, un
  //     toque elige. Si la IA se inclinó por una débil, su botón lo dice («la
  //     IA se inclina por esta (60 %)») pero no va elegida. El chip de la fila
  //     dice «¿obra?» en ámbar mientras falte elegirla.
  //   · EL MARCADOR HONESTO: «Este mes: cuenta 18 de 20 · obra 7 de 10
  //     acertadas (3 elegiste tú)» (v_contador_estado) y la rutina (cuándo
  //     corre, la última, su error) en la franja y en Conexiones; su alarma
  //     (la 74) en «Qué atender».
  // Con la base de la 7b (sin obras_top, obra_fuerte, rutina ni marcador) la
  // pantalla sigue: la obra fuerte por su confianza, el selector sin botones,
  // y ni marcador ni rutina.
  // ============================================================
  const MOTIVOS_IA = ["sin_ticket", "dudosa"]; // los que mira la IA (los mismos que fn_contador_candidatos)
  // Los flags de la propuesta en llano: la IA señala y Edgar decide (en la v1 nada de esto se postea solo)
  const FLAGS_IA = {
    capitalizable: ["¿Activo fijo?", "warn", "Pasa de $2,500 y dura más de un año: puede ser un activo fijo. Decides tú."],
    use_tax: ["¿Use tax?", "warn", "Parece una compra sin el impuesto de Florida: puede deber use tax. No se postea nada solo."],
    personal: ["Personal", "cu", "Parece personal: en la S-corp va a 3200 (distribución) o a 1130 (cuenta por cobrar al accionista), nunca a gasto."],
    irs: ["IRS", "cu", "Un pago al IRS: en la S-corp va a 3200 (distribución), nunca a gasto."],
    pide_obra: ["Pide obra", "warn", "La cuenta pide la obra y las pistas (las horas de la cuadrilla, los tickets de este comercio, lo que elegiste antes) no apuntan a una sola: elígela tú. La IA no la adivina."]
  };
  // las obras a las que se carga un gasto: las firmadas que siguen vivas (las mismas que c8 le enseña a la IA; = FIRMADO de js/app.js)
  const OBRAS_ACTIVAS = ["aprobado", "ejecucion", "pausa"];
  const usdCent = c => fmt((Number(c) || 0) / 100);
  const pctConf = v => `${Math.round((num(v) || 0) * 100)} %`;
  const claseConf = v => num(v) >= 0.8 ? "ok" : num(v) >= 0.5 ? "warn" : "";
  const nOk = v => Number(v || 0);
  // la IA se pinta solo si c8 está, contestó y su control cuadra
  const iaViva = () => !!(S.ia && S.ia.estado && !S.ia.err && !S.ia.rojo.length);
  const iaFilaDe = m => (iaViva() && S.ia.bandeja.get(m.movimiento_id)) || null;
  const iaPendiente = m => { const f = iaFilaDe(m); return f && f.estado === "pendiente" ? f : null; };
  // a qué movimientos les toca: los sin ticket (o dudosos) y cualquiera con una propuesta viva; nunca un depósito de Stripe
  const iaMira = m => iaViva() && !m._esStripe && (MOTIVOS_IA.includes(m.motivo) || !!iaPendiente(m));
  const cuentaIA = cod => ((S.ia && S.ia.cuentas) || []).find(c => c.codigo === cod) || null;
  const lineasTexto = f => f.resumen || (Array.isArray(f.lineas) ? f.lineas : []).map(l => `${l.cuenta} ${l.cuenta_nombre || ""}`.trim()).join(" + ");
  const obrasActivas = () => (S.proyectos || []).filter(p => OBRAS_ACTIVAS.includes(p.estado));
  // las opciones del selector de la obra: `vacio` (null: sin opción vacía) y las obras activas; `sel` queda elegida
  const opcionesObra = (vacio, sel) => `${vacio == null ? "" : `<option value="">${esc(vacio)}</option>`}${obrasActivas().map(p => `<option value="${esc(p.id)}"${p.id === sel ? " selected" : ""}>${esc(p.nombre)}</option>`).join("")}`;
  // (7c) «fuerte»: la obra que se puede dar por buena de un toque (≥ 80 %, el mismo umbral que fn_contador_obra_fuerte). La base
  // lo deja en la propuesta (obra_fuerte); una de antes de la 7c no lo trae y manda su confianza. Con la regla de antes, una
  // obra por horas y tickets ya salía elegida con 0,60, y en producción esas pistas solas aciertan cuatro de cada diez
  const OBRA_FUERTE = 0.8;
  // (7b) la obra que trae la propuesta (la de la IA, o la candidata de las pistas en una propuesta por regla), o null:
  // {id, nombre, confianza, motivo, activa, estado, fuerte}. «activa», según las obras que la bandeja leyó al pintarse (frescas)
  const obraPropuesta = f => {
    if (!f || !f.obra_propuesta_id) return null;
    const p = (S.proyectos || []).find(x => x.id === f.obra_propuesta_id);
    return { id: f.obra_propuesta_id, nombre: f.obra_propuesta || (p && p.nombre) || f.obra_propuesta_id, confianza: num(f.obra_confianza), motivo: f.obra_motivo || "",
      activa: !!p && OBRAS_ACTIVAS.includes(p.estado), estado: p ? p.estado : null, fuerte: f.obra_fuerte === true || num(f.obra_confianza) >= OBRA_FUERTE };
  };
  // la regla de la obra de una cuenta (obligatoria, opcional o prohibida): la de v_contador_cuentas o, si no está ahí, la del plan
  const reglaObra = cod => ((cuentaIA(cod) || (S.cuentas || []).find(c => c.codigo === cod)) || {}).regla_obra || null;
  const admiteObra = cod => ["obligatoria", "opcional"].includes(reglaObra(cod));
  // ¿alguna cuenta de la propuesta admite obra? Entonces «Según la IA» trae el selector: lo que Edgar deja ahí es lo que entra
  // (fn_contador_aprobar pone la obra que le mandan en toda línea cuya cuenta la admite, nunca en una de obra prohibida)
  const llevaObra = f => (Array.isArray(f.lineas) ? f.lineas : []).some(l => admiteObra(l.cuenta));
  // con qué obra sale elegido el selector: la propuesta, si sigue activa y es fuerte (7c: una débil se enseña, pero la eliges
  // tú); sin ella, la única obra activa que traen las líneas (una regla con su obra); si no, ninguna. Con una elegida no hay
  // opción vacía: «Así es» con el selector vacío aprobaría la obra de la propuesta igual (la base no quita una obra); dejarlo
  // sin obra es «Según yo»
  function obraInicial(f) {
    const ob = obraPropuesta(f);
    if (ob) return ob.activa && ob.fuerte ? ob.id : "";
    const ids = [...new Set((Array.isArray(f.lineas) ? f.lineas : []).map(l => l.proyecto_id).filter(Boolean))];
    return ids.length === 1 && obrasActivas().some(p => p.id === ids[0]) ? ids[0] : "";
  }
  // ¿«Así es» necesita que se elija la obra? Si la cuenta la pide y no viene, si la que propuso la IA ya no está activa o
  // (7c) si es débil: sus líneas la traen (la base la copia) y «Así es» sin elegir la metería sin que Edgar la haya dicho
  const obraFalta = f => { const ob = obraPropuesta(f); return pideObraIA(f) || (!!ob && (!ob.activa || !ob.fuerte) && llevaObra(f)); };
  // (7c) las obras para elegir de un toque: hasta tres de las pistas (obras_top de v_contador_bandeja, por puntos, cada una con
  // su pista corta en llano), solo las que siguen activas; si la IA se inclinó por una débil que no está entre ellas, entra en
  // el lugar de la tercera. Sin pistas (o con una base de antes de la 7c), ninguna: queda el selector de siempre
  function obrasChip(f, ob) {
    const vivas = obrasActivas(), vistas = new Set(), ops = [];
    for (const o of Array.isArray(f.obras_top) ? f.obras_top : []) {
      const p = o && vivas.find(x => x.id === o.proyecto_id);
      if (!p || vistas.has(p.id)) continue;
      vistas.add(p.id); ops.push({ id: p.id, nombre: p.nombre, pista: String(o.pista || "") });
    }
    const inclina = ob && ob.activa && !ob.fuerte ? ob : null;
    if (inclina && !vistas.has(inclina.id)) ops.splice(Math.min(ops.length, 2), ops.length, { id: inclina.id, nombre: inclina.nombre, pista: "" });
    return ops.slice(0, 3).map(o => ({ ...o, ia: !!inclina && o.id === inclina.id }));
  }
  // el texto de «Así es»: con la obra elegida, su nombre
  const textoAsi = (falta, nombre) => nombre ? `✓ Así es · ${nombre}` : falta ? "✓ Así es (elige antes la obra)" : "✓ Así es";
  // el resumen de las pistas que vio la base (fn_contador_pistas_obra), en llano
  const pistasTexto = r => r === "sin pistas" ? "Pistas: ninguna obra tiene horas de la cuadrilla, tickets de este comercio ni materiales cerca de esta fecha." : `Pistas: ${r}`;

  // FALLA RUIDOSA de la IA: un «cuadre» en false, o una vista que trajo otro número de filas que el que contó el control
  // (10 y 11), y no se pinta nada de la IA (la bandeja sigue con c6). Devuelve lo que no cuadra; vacío = cuadra.
  // Salvo el 64 (7b: una propuesta pendiente trae una obra que ya no está activa): lo que la vista pinta es verdad y el
  // remedio está en la propia propuesta (elegir otra obra al aprobarla, o «No es eso»), que lo dice y no deja entrar esa obra
  // por un toque. Tapar la IA dejaría a Edgar sin el selector que el detalle del cuadre le pide usar.
  const CUADRES_IA_A_LA_VISTA = [64];
  const obrasCerradasDe = ctl => (Array.isArray(ctl) ? ctl : []).filter(f => f.nivel === "cuadre" && f.ok !== true && CUADRES_IA_A_LA_VISTA.includes(Number(f.orden)));
  const nCerradas = ia => ((ia && ia.obrasCerradas) || []).reduce((s, f) => s + (nOk(f.filas) || 1), 0);
  function controlContador(control, conteos) {
    if (!Array.isArray(control) || !control.length) return [{ vista: "v_contador_control", detalle: "la vista contestó vacía" }];
    const mal = control.filter(f => f.nivel === "cuadre" && f.ok !== true && !CUADRES_IA_A_LA_VISTA.includes(Number(f.orden))).map(f => ({ vista: f.control, filas: f.filas, esperadas: f.esperadas, detalle: f.detalle }));
    for (const [vista, n] of Object.entries(conteos)) {
      const f = control.find(x => x.control === "vista: " + vista);
      if (!f) mal.push({ vista, detalle: "el control no revisó esta vista" });
      else if (f.ok === true && Number(f.filas) !== Number(n)) mal.push({ vista, filas: f.filas, esperadas: n, detalle: `la pantalla trajo ${n} fila(s) y el control contó ${f.filas}` });
    }
    return mal;
  }
  // La salud de la función: solo booleanos, el modelo y la versión de las instrucciones (nunca una llave). Si no contesta, el error.
  // Ni la falta de señal tumba la página aquí: lo de antes ya se leyó con señal y la función puede estar sin desplegar.
  async function saludContador() {
    try { return { salud: await DB._funcion("contador", { accion: "salud" }, 15000), saludErr: null }; }
    catch (err) { return { salud: null, saludErr: err }; }
  }
  // Lo de la IA para la bandeja: null sin c8; { err } si una vista no contestó; si no, el estado, la propuesta de cada movimiento,
  // el control (con `rojo`: lo que no cuadra), las cuentas que se pueden elegir y la salud de la función (solo con el código
  // del teléfono: sin él no se puede tocar nada y no hace falta preguntarle). Sin señal, se lanza. `previa` ({ salud, saludErr }):
  // la salud que ya se tiene (7c: la cadena relee la IA después de cada ráfaga y la función acaba de contestar: no se le pregunta)
  async function leerContador(previa) {
    let est, bj, ctl, cts;
    try {
      [est, bj, ctl, cts] = await Promise.all([
        DB._leer("v_contador_estado?select=*"),
        DB._leer("v_contador_bandeja?select=*&order=creado_el.asc"),
        DB._leer("v_contador_control?select=*&order=orden.asc"),
        DB._leer("v_contador_cuentas?select=codigo,nombre,tipo,regla_obra&order=codigo.asc")
      ]);
    } catch (err) {
      if (esFalloDeRed(err)) throw err;
      return sinInstalar(err) ? null : { err, rojo: [] };
    }
    const rojo = controlContador(ctl, { v_contador_bandeja: bj.length });
    if (!Array.isArray(est) || est.length !== 1) rojo.push({ vista: "v_contador_estado", filas: Array.isArray(est) ? est.length : 0, esperadas: 1, detalle: "no devolvió su fila (¿falta contador_config o la sesión no es la del dueño?)" });
    const ia = { estado: (est || [])[0] || null, bandeja: new Map(bj.map(f => [f.movimiento_id, f])), control: ctl, cuentas: cts || [], rojo, salud: null, saludErr: null,
      // (7b) el 64 en rojo: la franja lo avisa y cada propuesta con la obra cerrada lo dice
      obrasCerradas: obrasCerradasDe(ctl) };
    if (!rojo.length && mfaActivo()) Object.assign(ia, previa && previa.salud ? { salud: previa.salud, saludErr: null } : await saludContador());
    return ia;
  }

  // Por qué «Proponer ahora» no se puede tocar (ni la cadena arrancar sola) ahora ({ txt, clase }), o null si se puede
  const TOPE_IA = {
    apagado: () => "El contador está apagado (contador_config.activa = false): se enciende desde el SQL Editor.",
    "tope de la app": e => `La IA de la app llegó a su tope del mes (${usdCent(e.tope_global)}): no se propone nada hasta el mes que viene.`,
    "tope del contador": e => `La IA contable llegó a su tope del mes (${usdCent(e.tope_mes_centavos)}): no se propone nada hasta el mes que viene.`
  };
  function frenoIA(ia) {
    const e = ia.estado;
    if (!mfaActivo()) return { txt: "Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: la IA contable lo pide.", clase: "warn" };
    if (e.bloqueado) return { txt: (TOPE_IA[e.bloqueado_motivo] || (() => "La IA está parada este mes."))(e), clase: "warn" };
    if (!ia.salud) return { txt: `La función «contador» no contestó${ia.saludErr && ia.saludErr.message ? ` (${ia.saludErr.message})` : ""}: ¿está desplegada en Supabase → Edge Functions?`, clase: "warn" };
    if (ia.salud.llave === false) return { txt: "Falta la llave de Anthropic: ponla en Supabase → Edge Functions → Secrets (ANTHROPIC_API_KEY).", clase: "bad" };
    if (ia.salud.base === false) return { txt: `La función «contador» no llega a la base${faltaIA(ia.salud) ? `: ${faltaIA(ia.salud)}` : ": mira sus registros en Supabase"}.`, clase: "bad" };
    if (!nOk(e.pendientes_sin_propuesta)) return { txt: "Nada por proponer: cada cargo sin ticket ya tiene su propuesta.", clase: "" };
    return null;
  }
  // lo que la salud dice que falta configurar (la función lo da en llano y sin llaves), en una línea
  const faltaIA = s => s && Array.isArray(s.falta) && s.falta.length ? s.falta.map(String).join("; ") : "";
  const pillIA = () => `<span class="ct-pill ia">IA</span>`;
  // La franja de la bandeja: lo que hay listo, lo que falta, el gasto del mes y «Proponer ahora»; (7c) mientras la cadena propone
  // sola, su avance con «Parar» (y al terminar, lo que hizo); al pie, el marcador del mes y la rutina. Si la IA no cuadra, el rojo
  // con el detalle.
  function franjaIAHTML(ia) {
    if (ia.err) return `<section class="ct-card ct-ia-franja mal" id="ct-ia-franja" role="status"><div class="ct-ia-f-txt">${pillIA()}<span>La IA contable no contestó (${esc(ia.err.message)}): la bandeja sigue igual sin ella.</span></div></section>`;
    if (ia.rojo.length) {
      return `<section class="ct-card ct-ia-franja mal" id="ct-ia-franja" role="alert"><div class="ct-ia-f-txt">${pillIA()}<span><b>La IA contable no cuadra: no se pinta ninguna propuesta</b> hasta que cuadre (pintarlas sería mentir). Mientras tanto, «Otra cosa…» sigue en cada movimiento.</span></div>
        <ul class="ct-datos ct-ia-rojo">${ia.rojo.map(m => `<li><b>${esc(m.vista)}</b>${m.filas != null || m.esperadas != null ? ` (trajo ${esc(m.filas == null ? "—" : m.filas)}, debía ${esc(m.esperadas == null ? "—" : m.esperadas)})` : ""}${m.detalle ? `: ${esc(m.detalle)}` : ""}</li>`).join("")}</ul></section>`;
    }
    const e = ia.estado, freno = frenoIA(ia), falta = nOk(e.pendientes_sin_propuesta), listas = nOk(e.propuestas_pendientes), conObra = nOk(e.propuestas_con_obra);
    const cerradas = nCerradas(ia), c = S.cadena, corre = !!(c && c.activa);
    return `<section class="ct-card ct-ia-franja" id="ct-ia-franja">
      <div class="ct-ia-f-txt">${pillIA()}<span id="ct-ia-cifras"><b>${plural(listas, "propuesta lista", "propuestas listas")}</b>${conObra ? ` (${conObra} con obra)` : ""} · ${falta} por proponer · este mes <span class="ct-num">${usdCent(e.centavos_mes_contador)}</span> de <span class="ct-num">${usdCent(e.tope_mes_centavos)}</span></span>${e.aviso && !e.bloqueado ? pill(`cerca del tope (${nOk(e.aviso_pct)} %)`, "warn") : ""}</div>
      <div class="ct-ia-f-acc"><button type="button" class="accion" id="ct-ia-proponer" data-proponer${freno || corre ? " disabled" : ""}${corre ? ` aria-busy="true"` : ""}>Proponer ahora (${falta})</button></div>
      ${corre ? cadenaHTML(c) : ""}
      ${freno && !corre ? `<p class="ct-ia-freno${freno.clase ? " " + freno.clase : ""}">${esc(freno.txt)}</p>` : ""}
      ${cerradas ? `<p class="ct-ia-freno warn" id="ct-ia-cerradas">${esc(plural(cerradas, "propuesta trae una obra que ya no está activa (se cerró después de proponerla)", "propuestas traen una obra que ya no está activa (se cerraron después de proponerlas)"))}: ábrela y elige otra obra al aprobarla, o di «No es eso».</p>` : ""}
      ${pieFranja(e)}
      <div class="ct-ia-res">${c && !corre && c.fin ? `<p class="ct-aviso ${c.fin.clase}" role="status">${esc(c.fin.txt)}</p>` : ""}</div>
    </section>`;
  }
  // (7c) el avance de la cadena: «Proponiendo… 40 de 172 · $0.35» con «Parar» (lo que ya pidió a la IA termina y se guarda)
  const cadenaHTML = c => `<div class="ct-ia-cadena" id="ct-ia-cadena" role="status" aria-live="polite">
      <p class="ct-ia-avance ct-espera">${esc(c.parar ? "Parando: termina la ráfaga que ya está en marcha (lo que proponga se guarda)…"
        : c.esperando ? "Otra ráfaga está en marcha (¿la rutina, otra pestaña?): espero 5 s y vuelvo a probar…"
        : `Proponiendo… ${c.hechas} de ${Math.max(c.total, c.hechas)} · ${usdCent(c.centavos)}`)}</p>
      <button type="button" class="accion secundaria chica" id="ct-ia-parar"${c.parar ? " disabled" : ""}>Parar</button>
    </div>`;
  // (7c) el pie de la franja: el marcador del mes, la rutina y, con el interruptor apagado, que la Bandeja ya no propone sola
  function pieFranja(e) {
    const marc = marcadorIA(e), rut = rutinaIA(e, true);
    const partes = [marc ? esc(marc) : "", rut ? `<span class="ct-ia-rut${rut.clase ? " " + rut.clase : ""}">${esc(rut.txt)}</span>` : "",
      solaEncendida() ? "" : `<span class="ct-ia-rut warn">no propone sola al abrir la Bandeja (su interruptor, en Conexiones, está apagado)</span>`].filter(Boolean);
    return partes.length ? `<p class="ct-ia-f-pie" id="ct-ia-pie">${partes.join(" · ")}</p>` : "";
  }
  // (7c) EL MARCADOR HONESTO DEL MES (v_contador_estado): de lo que entró este mes por la IA o por una regla, en cuántas acertó
  // la cuenta (entró tal cual) y en cuántas la cambiaste; de las obras, cuántas acertó, cuántas corregiste y cuántas eligió
  // Edgar porque la IA no propuso ninguna (cuentan como no acertadas: la IA no la supo). null con una base de antes de la 7c
  function marcadorIA(e) {
    if (!e || !("cuenta_acertadas_mes" in e)) return null;
    const ca = nOk(e.cuenta_acertadas_mes), cc = nOk(e.cuenta_cambiadas_mes), oa = nOk(e.obra_acertadas_mes), oc = nOk(e.obra_cambiadas_mes), oe = nOk(e.obra_elegidas_mes);
    if (!ca && !cc) return "Este mes: todavía no has decidido ninguna propuesta de la IA";
    const extra = [oc ? `${oc} corregiste` : "", oe ? `${oe} elegiste tú` : ""].filter(Boolean).join(", ");
    return `Este mes: cuenta ${ca} de ${ca + cc}${oa + oc + oe ? ` · obra ${oa} de ${oa + oc + oe}` : ""} acertadas${extra ? ` (${extra})` : ""}`;
  }
  // (7c) LA RUTINA: pg_cron la programa en UTC (c8: «25 11 * * *», después del banco de Plaid a las 11:00, y «0 21 * * *»), así
  // que en Miami es 6:25 y las 4 de la tarde en invierno y 7:25 y las 5 en verano: se calcula para hoy en vez de escribirla fija
  const RUTINA_UTC = [[11, 25], [21, 0]];
  const horaMiami = (h, m) => {
    const d = new Date(); d.setUTCHours(h, m, 0, 0);
    const p = new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York", hour: "numeric", minute: "2-digit", hourCycle: "h23" }).formatToParts(d);
    const g = k => Number((p.find(x => x.type === k) || {}).value || 0);
    return [g("hour"), g("minute")];
  };
  const hhmm = ([h, m]) => `${h}:${String(m).padStart(2, "0")}`;
  const deLaTarde = ([h, m]) => h >= 12 ? `a las ${h === 12 ? 12 : h - 12}${m ? `:${String(m).padStart(2, "0")}` : ""} de la tarde` : `a las ${hhmm([h, m])}`;
  // «hoy 6:26», «ayer 17:01» o «29 oct 17:01» (hora de Miami)
  const cuandoMiami = ts => {
    const d = new Date(ts); if (!ts || Number.isNaN(d.getTime())) return "—";
    const dia = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
    const p = new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York", hour: "numeric", minute: "2-digit", hourCycle: "h23" }).formatToParts(d);
    const g = k => Number((p.find(x => x.type === k) || {}).value || 0);
    const dif = diasEntre(hoyMiami(), dia);
    return `${dif === 0 ? "hoy" : dif === 1 ? "ayer" : fecha(dia)} ${hhmm([g("hour"), g("minute")])}`;
  };
  // cómo va la rutina ({ txt, clase }; `corto`, para el pie de la franja), o null con una base de antes de la 7c. Lo mismo que
  // mira la alarma 74: con error, o más de 36 horas sin correr (desde la última, o desde que se instaló) con cargos esperando
  function rutinaIA(e, corto) {
    if (!e || !("rutina_activa" in e)) return null;
    if (e.rutina_activa === false) return { txt: corto ? "la rutina está apagada" : "La rutina está apagada (contador_config.rutina_activa = false): la IA propone cuando abres la Bandeja o tocas «Proponer ahora».", clase: "warn" };
    const [man, tar] = RUTINA_UTC.map(([h, m]) => horaMiami(h, m));
    const cuando = `Propone sola cada mañana tras el banco (${hhmm(man)}) y ${deLaTarde(tar)}`;
    const ult = e.rutina_ultima_el, desde = ult || e.rutina_desde;
    const vieja = !!desde && Date.now() - Date.parse(desde) > 36 * 3600e3 && nOk(e.pendientes_sin_propuesta) > 0;
    if (e.rutina_ultimo_error) return { txt: corto ? `la rutina de ${cuandoMiami(ult)} terminó con error (en Conexiones)` : `${cuando} · última: ${cuandoMiami(ult)} · con error: ${e.rutina_ultimo_error}`, clase: "bad" };
    if (!ult) return { txt: corto ? `la rutina no ha corrido todavía${vieja ? " (y ya debía)" : ""}` : `${cuando} · todavía no ha corrido${vieja ? ` y ya debía (instalada el ${fechaHora(e.rutina_desde)}): mira «Qué atender»` : ""}`, clase: vieja ? "warn" : "" };
    return { txt: corto ? `la rutina: ${cuandoMiami(ult)}, ${vieja ? "hace más de 36 horas" : "bien"}` : `${cuando} · última: ${cuandoMiami(ult)} · ${vieja ? "hace más de 36 horas: mira «Qué atender»" : "bien"}`, clase: vieja ? "warn" : "ok" };
  }

  // El chip de la fila compacta: «IA · 5100 Material · 92 %», «Regla · WAWA» o «sin propuesta». (7b) La obra va entre la cuenta y
  // la confianza; (7c) SOLO si es fuerte: «IA · 5100 Material · Dicke · 85 %». Si falta elegirla (débil, sin obra y la cuenta la
  // pide, o cerrada), «¿obra?» en ámbar: lo que queda por decir antes de «Así es»
  function chipIA(m) {
    if (!iaMira(m)) return "";
    const f = iaPendiente(m);
    if (!f) return `<span class="ct-pill ct-ia-chip nada">sin propuesta</span>`;
    // (el porcentaje es el de la propuesta, como siempre; el de la obra va en «Según la IA» y al pasar por encima)
    const ob = obraPropuesta(f), obra = ob && ob.activa && ob.fuerte ? ob : null, falta = !obra && obraFalta(f);
    const tObra = obra ? ` · Obra: ${obra.nombre}${obra.confianza != null ? ` (${pctConf(obra.confianza)})` : ""}${obra.motivo ? `: ${obra.motivo}` : ""}`
      : ob && ob.activa ? ` · ¿Obra? La IA se inclina por ${ob.nombre}${ob.confianza != null ? ` (${pctConf(ob.confianza)})` : ""}, sin seguridad: elígela tú` : falta ? " · ¿Obra? Elígela tú" : "";
    // (el separador va en su propio span: en la computadora la obra baja a su renglón dentro del chip y el «·» sobra)
    const chipObra = obra ? `<span class="ct-ia-chip-o"><span class="ct-ia-sep"> · </span>${esc(obra.nombre)}</span>`
      : falta ? `<span class="ct-ia-chip-f"><span class="ct-ia-sep"> · </span>¿obra?</span>` : "";
    if (f.fuente === "regla") return obra || falta ? `<span class="ct-pill ct-ia-chip regla${obra ? " con-obra" : " falta"}" title="${esc(lineasTexto(f) + tObra)}"><span class="ct-ia-chip-q">Regla · ${esc(f.regla_nombre || "")}</span>${chipObra}</span>`
      : `<span class="ct-pill ct-ia-chip regla" title="${esc(lineasTexto(f))}">Regla · ${esc(f.regla_nombre || "")}</span>`;
    // (si no cabe se recorta con «…» la obra; la cuenta, solo si ni así cabe; la confianza y el «¿obra?» siempre se ven)
    return `<span class="ct-pill ct-ia-chip ia${obra ? " con-obra" : ""}${falta ? " falta" : ""}" title="${esc((f.motivo || "") + tObra)}"><span class="ct-ia-chip-q">IA · ${esc(lineasTexto(f))}</span>${chipObra}<span class="ct-ia-chip-p"> · ${pctConf(f.confianza)}</span></span>`;
  }

  // El bloque del detalle desplegado: «Según la IA» y «Según yo», en dos columnas (una debajo de otra en el teléfono)
  function iaBloqueHTML(m) {
    if (!iaMira(m)) return "";
    const f = iaFilaDe(m), viva = f && f.estado === "pendiente" ? f : null;
    return `<div class="ct-ia" data-ia>
      <section class="ct-ia-col ct-ia-suya" aria-label="Según la IA"><h3 class="ct-ia-h">Según la IA</h3>${viva ? propuestaIAHTML(viva) : sinPropuestaHTML(f)}</section>
      <section class="ct-ia-col ct-ia-mia" aria-label="Según yo"><h3 class="ct-ia-h">Según yo</h3>${segunYoHTML()}</section>
      ${mfaActivo() ? "" : `<p class="ct-aviso warn ct-ia-sin">Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: «Así es», «No es eso» y «Clasificar» lo piden. Mientras tanto, «Otra cosa…» sigue abajo.</p>`}
      <div class="ct-ia-res"></div>
    </div>`;
  }
  // ¿«Así es» pide la obra? Lo que mira fn_contador_aprobar: alguna línea con una cuenta de obra obligatoria y sin obra (la vista
  // lo dice en cada línea); solo si las líneas no lo traen, el flag de la propuesta
  function pideObraIA(f) {
    const ls = Array.isArray(f.lineas) ? f.lineas : [];
    return ls.some(l => typeof l.pide_obra === "boolean") ? ls.some(l => l.pide_obra === true) : !!f.pide_obra;
  }
  // (7b) «Obra: Calla Terrace · 78 %» y debajo su porqué (las pistas que citó); si la obra se cerró después de proponerla, lo dice
  const obraIAHTML = ob => `<div class="ct-ia-obra${ob.activa ? "" : " cerrada"}" data-ia-obra-prop>
      <p class="ct-ia-obra-t">Obra: <b>${esc(ob.nombre)}</b>${ob.confianza != null ? ` · <span class="ct-ia-obra-p ${claseConf(ob.confianza)}">${pctConf(ob.confianza)}</span>` : ""}</p>
      ${ob.motivo ? `<p class="ct-ia-obra-m">${esc(cap(ob.motivo))}</p>` : ""}
      ${ob.activa ? "" : `<p class="ct-ia-obra-mal">Ya no está activa (${esc(ob.estado || "no existe")}): elige otra obra para aprobarla, o di «No es eso».</p>`}
    </div>`;
  function propuestaIAHTML(f) {
    const lineas = Array.isArray(f.lineas) ? f.lineas : [], varias = lineas.length > 1;
    const flags = Object.keys(FLAGS_IA).filter(k => k === "pide_obra" ? pideObraIA(f) : !!(f.flags && f.flags[k] === true));
    const pide = pideObraIA(f), dis = mfaActivo() ? "" : " disabled";
    const alt = Array.isArray(f.alternativas) ? f.alternativas.filter(a => a && a.cuenta) : [];
    // (7b) la obra: la propuesta con su confianza y su porqué (sin ella, las pistas en gris), y el selector si alguna cuenta la admite.
    // (7c) Elegida solo si es fuerte; si no (débil, sin obra, la cuenta la pide), «¿De qué obra?» con las obras de sus pistas para
    // elegir de un toque y «Otra obra…» con el selector, nada elegido
    const ob = obraPropuesta(f), conObra = llevaObra(f), ini = conObra ? obraInicial(f) : "", falta = obraFalta(f);
    const debil = !!ob && ob.activa && !ob.fuerte, ops = conObra && !ini ? obrasChip(f, ob) : [];
    const nIni = ini ? (obrasActivas().find(p => p.id === ini) || {}).nombre || "" : "";
    const etiqueta = ob && !ob.activa ? `¿De qué obra? (la que propuso la IA, ${ob.nombre}, ya no está activa)` : debil ? `¿De qué obra? (la IA se inclina por ${ob.nombre}, sin seguridad)`
      : ob ? `¿De qué obra? (la IA propone ${ob.nombre})` : pide ? "¿De qué obra? (la cuenta la pide)" : ini ? "¿De qué obra? (la trae la propuesta)" : "¿De qué obra? (opcional)";
    const vacia = ini ? null : ob && !ob.activa ? "Elige otra obra…" : pide || debil ? "Elige la obra…" : "Sin obra";
    const selector = `<label class="ct-campo ct-ia-obra-sel"${ops.length ? " hidden" : ""}>${esc(etiqueta)}<select data-ia-obra>${opcionesObra(vacia, ini)}</select></label>`;
    return `<ul class="ct-ia-lineas">${lineas.map(l => `<li><span class="ct-num">${esc(l.cuenta)}</span> ${esc(l.cuenta_nombre || "")}${l.obra && !(ob && l.proyecto_id === ob.id) ? `<small>obra: ${esc(l.obra)}</small>` : l.pide_obra ? `<small>falta la obra</small>` : ""}${varias && l.monto != null ? `<span class="ct-num ct-ia-m">${fmt(l.monto)}</span>` : ""}</li>`).join("")}</ul>
      ${f.motivo ? `<p class="ct-ia-motivo">${esc(f.motivo)}</p>` : ""}
      ${ob && !debil ? obraIAHTML(ob) : debil && conObra ? obraDebilHTML(ob) : conObra && f.pistas_resumen && !ops.length ? `<p class="ct-ia-pistas">${esc(pistasTexto(f.pistas_resumen))}</p>` : ""}
      <div class="ct-ia-pills">${pill(`${pctConf(f.confianza)} de confianza`, "ct-conf " + claseConf(f.confianza))}${flags.map(k => `<span class="ct-pill ${FLAGS_IA[k][1]}" title="${esc(FLAGS_IA[k][2])}" data-flag="${k}">${esc(FLAGS_IA[k][0])}</span>`).join("")}</div>
      ${alt.length ? `<p class="ct-ia-alt">Otras posibilidades: ${alt.map(a => `<span class="ct-num">${esc(a.cuenta)}</span>${a.motivo ? ` (${esc(a.motivo)})` : ""}`).join(" · ")}</p>` : ""}
      <p class="ct-ia-fuente">${f.fuente === "regla" ? `Regla: ${esc(f.regla_nombre || "")}` : f.fuente === "edgar" ? "La dijiste tú" : `Propuso ${esc(f.modelo || "la IA")}`}${f.creado_el ? ` · ${fechaHora(f.creado_el)}` : ""}</p>
      ${conObra ? `${ops.length ? obrasChipHTML(ops, ob, pide) : ""}${selector}
        <p class="ct-ia-obra-cambio" data-ia-obra-cambio hidden>Con otra obra entra la tuya y la propuesta queda «editada».</p>` : ""}
      <div class="ct-acciones"><button type="button" class="accion" data-ia-asi${dis}>${esc(textoAsi(falta, nIni))}</button><button type="button" class="accion secundaria" data-ia-no${dis}>No es eso</button></div>
      <p class="ct-nota ct-ia-pie">${conObra ? "«Así es» lo registra en el libro con esas líneas y la obra elegida, y recuerda la cuenta para este comercio (la obra no: la próxima vez la dicen sus pistas)."
        : "«Así es» lo registra en el libro con esas líneas y lo recuerda para este comercio."}</p>`;
  }
  // (7c) la obra DÉBIL por la que se inclina la IA: se dice con su porqué, pero no va elegida (eliges tú abajo)
  const obraDebilHTML = ob => `<div class="ct-ia-obra debil" data-ia-obra-prop>
      <p class="ct-ia-obra-t">La IA se inclina por <b>${esc(ob.nombre)}</b>${ob.confianza != null ? ` · <span class="ct-ia-obra-p ${claseConf(ob.confianza)}">${pctConf(ob.confianza)}</span>` : ""}, pero no está segura: elige tú.</p>
      ${ob.motivo ? `<p class="ct-ia-obra-m">${esc(cap(ob.motivo))}</p>` : ""}
    </div>`;
  // (7c) «¿De qué obra?»: un botón grande por obra (su nombre y su pista corta), «Otra obra…» y nada elegido. Un toque elige; el
  // selector de debajo (escondido hasta «Otra obra…») es lo que «Así es» manda, así que los dos caminos dicen lo mismo
  const obrasChipHTML = (ops, ob, pide) => `<div class="ct-ia-obra-elegir" data-ia-obra-elegir>
      <p class="ct-ia-obra-q">¿De qué obra?<small>${pide ? "la cuenta la pide: toca la que es" : ob && ob.activa ? "la IA no está segura: toca la que es" : ob ? "la que propuso ya no está activa: toca otra" : "toca la que es (o déjala sin obra)"}</small></p>
      <div class="ct-ia-obra-ops" role="group" aria-label="¿De qué obra?">${ops.map(o => `<button type="button" class="ct-ia-obra-op${o.ia ? " ia" : ""}" data-ia-obra-op="${esc(o.id)}" aria-pressed="false">
          <span class="ct-ia-obra-op-n">${esc(o.nombre)}</span>${o.pista ? `<span class="ct-ia-obra-op-p">${esc(o.pista)}</span>` : ""}${o.ia ? `<span class="ct-ia-obra-op-ia">la IA se inclina por esta (${pctConf(ob.confianza)})</span>` : ""}</button>`).join("")}
        <button type="button" class="ct-ia-obra-op otra" data-ia-obra-otra aria-expanded="false">Otra obra…</button></div>
    </div>`;
  function sinPropuestaHTML(f) {
    const freno = frenoIA(S.ia), falta = nOk(S.ia.estado.pendientes_sin_propuesta), corre = !!(S.cadena && S.cadena.activa);
    const antes = !f ? (corre ? "La IA está proponiendo (la franja de arriba dice por dónde va): este cargo llega en su turno." : "La IA no ha propuesto nada todavía.")
      : f.estado === "rechazada" ? `Rechazaste la propuesta (${lineasTexto(f)})${f.motivo_edgar ? `: «${f.motivo_edgar}»` : ""}. La IA puede proponer otra en la próxima ráfaga, o clasifícalo tú.`
      : f.estado === "caducada" ? `La propuesta anterior caducó${f.nota ? ` (${f.nota})` : ""}: la IA no ha propuesto otra todavía.`
      : `Ya se clasificó una vez${f.asiento ? ` (asiento ${f.asiento})` : ""} y el movimiento volvió a la bandeja: clasifícalo otra vez.`;
    return `<p class="ct-ia-vacia">${esc(antes)}</p>
      <div class="ct-acciones"><button type="button" class="accion secundaria" data-proponer${freno || corre ? " disabled" : ""}>Proponer ahora (${falta})</button></div>
      ${freno && mfaActivo() ? `<p class="ct-nota">${esc(freno.txt)}</p>` : ""}`;
  }
  // Las cuentas que se pueden elegir (v_contador_cuentas), agrupadas por tipo; `filtro` las acota (el buscador: lo que se busca
  // es otra cuenta, así que la elegida antes sale si no casa) y `sel` queda elegida si sigue en la lista
  const ORDEN_TIPOS_IA = ["costo", "gasto", "otro_gasto", "activo", "pasivo", "capital"];
  function opcionesCuentaIA(filtro, sel) {
    const q = sinAcentos(filtro).trim();
    const cs = ((S.ia && S.ia.cuentas) || []).filter(c => !q || sinAcentos(`${c.codigo} ${c.nombre}`).includes(q));
    const grupos = ORDEN_TIPOS_IA.concat([...new Set(cs.map(c => c.tipo))].filter(t => !ORDEN_TIPOS_IA.includes(t))).map(t => {
      const g = cs.filter(c => c.tipo === t);
      return g.length ? `<optgroup label="${esc(grupoCuenta(t))}">${g.map(c => `<option value="${esc(c.codigo)}"${c.codigo === sel ? " selected" : ""}>${esc(c.codigo)} · ${esc(c.nombre)}${c.regla_obra === "obligatoria" ? " (pide obra)" : ""}</option>`).join("")}</optgroup>` : "";
    }).join("");
    return `<option value="">${cs.length || !q ? "Elige la cuenta…" : "Ninguna cuenta con eso"}</option>${grupos}`;
  }
  function segunYoHTML() {
    const dis = mfaActivo() ? "" : " disabled";
    return `<form class="ct-ia-yo" novalidate>
      ${(S.ia.cuentas || []).length > 12 ? `<label class="ct-campo ct-ia-buscar">Buscar la cuenta<input type="search" data-ia-buscar placeholder="Código o nombre" autocomplete="off"></label>` : ""}
      <label class="ct-campo">Cuenta<select name="ia_cuenta" data-ia-cuenta>${opcionesCuentaIA("", "")}</select></label>
      <label class="ct-campo" data-ia-obra-campo><span data-ia-obra-et>Obra (si la cuenta la pide)</span><select name="ia_obra" data-ia-obra-yo>${opcionesObra("Sin obra")}</select></label>
      <label class="ct-campo">Motivo (opcional; queda escrito en el libro)<textarea name="ia_motivo" rows="2"></textarea></label>
      <label class="ct-casilla"><input type="checkbox" name="ia_recordar" checked> Recordar para este comercio</label>
      <div class="ct-acciones"><button type="submit" class="accion" data-ia-clasificar${dis}>Clasificar</button></div>
    </form>`;
  }
  // ¿lo elegido es lo mismo que propuso la IA? La misma regla que fn_contador_clasificar (aprobada o editada): una línea, la misma
  // cuenta y la misma obra, o la propuesta no la traía y su flag decía que la pedía
  function igualQueIA(viva, cuenta, obra) {
    const ls = viva && Array.isArray(viva.lineas) ? viva.lineas : [];
    if (ls.length !== 1 || !cuenta || ls[0].cuenta !== cuenta) return false;
    return (ls[0].proyecto_id || "") === (obra || "") || (!ls[0].proyecto_id && viva.pide_obra === true);
  }

  // Los botones del bloque de un movimiento (lo llama pintarListaBandeja con cada tarjeta)
  function wireIA(card, m) {
    const bl = card.querySelector("[data-ia]"); if (!bl) return;
    const viva = iaPendiente(m);
    // «Según la IA»: «Así es» (con la obra si la pide) y «No es eso»
    const asi = bl.querySelector("[data-ia-asi]"), no = bl.querySelector("[data-ia-no]"), obraIA = bl.querySelector("[data-ia-obra]");
    // (7b) la obra de la propuesta (con la que sale el selector, o la cerrada) y si «Así es» necesita que se elija
    const ob = viva ? obraPropuesta(viva) : null, falta = viva ? obraFalta(viva) : false;
    const deLaIA = viva && obraIA ? obraInicial(viva) || (ob ? ob.id : "") : "", cambio = bl.querySelector("[data-ia-obra-cambio]");
    // (7c) «¿De qué obra?»: los botones de las obras y «Otra obra…» (que despliega el selector); el selector manda
    const elegir = bl.querySelector("[data-ia-obra-elegir]"), ops = elegir ? [...elegir.querySelectorAll("[data-ia-obra-op]")] : [];
    const otra = elegir ? elegir.querySelector("[data-ia-obra-otra]") : null, campoSel = bl.querySelector(".ct-ia-obra-sel");
    if (obraIA && asi) obraIA.addEventListener("change", () => {
      const p = obrasActivas().find(x => x.id === obraIA.value);
      asi.textContent = textoAsi(falta, p ? p.nombre : "");
      // otra obra que la de la propuesta: entra la de Edgar y la base deja la propuesta «editada»
      if (cambio) cambio.hidden = !deLaIA || !obraIA.value || obraIA.value === deLaIA;
      ops.forEach(b => b.setAttribute("aria-pressed", String(!!obraIA.value && b.dataset.iaObraOp === obraIA.value)));
      limpiarErrorIA(bl);
    });
    // un toque elige esa obra (otro toque en la misma la suelta); el selector toma el valor y avisa como si se hubiera elegido en él
    if (obraIA) ops.forEach(b => b.addEventListener("click", () => {
      obraIA.value = b.getAttribute("aria-pressed") === "true" ? "" : b.dataset.iaObraOp;
      obraIA.dispatchEvent(new Event("change"));
    }));
    if (otra && campoSel && obraIA) otra.addEventListener("click", () => {
      campoSel.hidden = !campoSel.hidden;
      otra.setAttribute("aria-expanded", String(!campoSel.hidden));
      if (!campoSel.hidden) obraIA.focus();
    });
    // (7c) la fila que Edgar empezó a decidir no se repinta debajo de su dedo cuando la cadena trae más propuestas
    const tocar = () => { card.dataset.tocada = "1"; };
    bl.addEventListener("input", tocar); bl.addEventListener("change", tocar);
    ops.concat(otra ? [otra] : []).forEach(b => b.addEventListener("click", tocar));
    if (asi && viva) asi.addEventListener("click", () => {
      if (obraIA && !obraIA.value && falta) {
        errorIA(bl, ob && !ob.activa ? `Elige otra obra: la que propuso la IA (${ob.nombre}) ya no está activa.`
          : ob && !ob.fuerte ? `Elige antes la obra: la IA se inclina por ${ob.nombre}${ob.confianza != null ? ` (${pctConf(ob.confianza)})` : ""}, pero no está segura. Toca la que es.`
          : "Elige antes la obra: la cuenta de la propuesta la pide.");
        (ops[0] && campoSel && campoSel.hidden ? ops[0] : obraIA).focus(); return;
      }
      // lo que queda en el selector es lo que entra (en toda línea cuya cuenta admite obra); vacío, las líneas como vienen
      const cuerpo = { accion: "aprobar", propuesta: viva.propuesta_id, recordar: true };
      if (obraIA && obraIA.value) cuerpo.proyecto_id = obraIA.value;
      accionIA(bl, cuerpo, r => resumenClasificado(r, true), { boton: asi, espera: "Registrándolo en el libro…" });
    });
    if (no && viva) no.addEventListener("click", () => accionIA(bl, { accion: "rechazar", propuesta: viva.propuesta_id, motivo: "No es eso (Edgar, desde la bandeja)" },
      () => { S.iaFoco = m.movimiento_id; return "Propuesta rechazada: dilo tú en «Según yo»"; }, { boton: no }));
    bl.querySelectorAll("[data-proponer]").forEach(b => b.addEventListener("click", () => cadenaIA("manual")));
    // «Según yo»: la cuenta (con su buscador), la obra según lo que pide la cuenta, el motivo, recordar y «Clasificar»
    const form = bl.querySelector(".ct-ia-yo"); if (!form) return;
    const sel = form.querySelector("[data-ia-cuenta]"), obra = form.querySelector("[data-ia-obra-yo]"), et = form.querySelector("[data-ia-obra-et]");
    const btn = form.querySelector("[data-ia-clasificar]"), buscar = form.querySelector("[data-ia-buscar]");
    // (7b) la obra que propone la IA queda elegida en cuanto la cuenta elegida la admite, mientras no toques tú la obra
    const obraYo = viva ? obraInicial(viva) : "";
    let obraTocada = false;
    const ajustar = () => {
      const c = cuentaIA(sel.value), r = c ? c.regla_obra : null;
      obra.disabled = r === "prohibida";
      if (r === "prohibida") obra.value = "";
      else if (obraYo && !obraTocada && (r === "obligatoria" || r === "opcional") && [...obra.options].some(o => o.value === obraYo)) obra.value = obraYo;
      obra.required = r === "obligatoria";
      et.textContent = r === "obligatoria" ? "Obra (esta cuenta la pide)" : r === "prohibida" ? "Obra (esta cuenta no lleva obra)" : r === "opcional" ? "Obra (opcional)" : "Obra (si la cuenta la pide)";
      btn.textContent = igualQueIA(viva, sel.value, obra.value) ? "Clasificar (igual que la IA)" : "Clasificar";
    };
    sel.addEventListener("change", () => { ajustar(); limpiarErrorIA(bl); });
    obra.addEventListener("change", () => { obraTocada = true; ajustar(); limpiarErrorIA(bl); });
    if (form.ia_motivo) form.ia_motivo.addEventListener("input", () => limpiarErrorIA(bl));
    if (buscar) buscar.addEventListener("input", () => {
      sel.innerHTML = opcionesCuentaIA(buscar.value, sel.value);
      // una sola cuenta con lo escrito: queda elegida
      const ops = [...sel.querySelectorAll("option")].filter(o => o.value);
      if (ops.length === 1 && buscar.value.trim()) sel.value = ops[0].value;
      ajustar();
    });
    ajustar();
    form.addEventListener("submit", ev => {
      ev.preventDefault();
      const cuenta = sel.value, c = cuentaIA(cuenta), pid = obra.disabled ? "" : obra.value;
      if (!cuenta) { errorIA(bl, "Falta la cuenta."); sel.focus(); return; }
      if (c && c.regla_obra === "obligatoria" && !pid) { errorIA(bl, `La ${c.codigo} (${c.nombre}) pide la obra: elígela.`); obra.focus(); return; }
      const motivo = String(form.ia_motivo.value || "").trim();
      accionIA(bl, { accion: "clasificar", movimiento: m.movimiento_id, lineas: [{ cuenta, proyecto_id: pid || null }], motivo: motivo || null, recordar: !!form.ia_recordar.checked },
        r => resumenClasificado(r, false), { boton: btn, espera: "Registrándolo en el libro…" });
    });
  }
  function errorIA(bl, msg) { const c = resCaja(bl, "ct-ia-res"); c.innerHTML = `<p class="ct-aviso bad ct-error">${esc(msg)}</p>`; }
  // Solo el aviso de validación («falta la cuenta», «elige la obra») se va al corregir; la respuesta de la función se queda.
  function limpiarErrorIA(bl) { const c = bl.querySelector(".ct-ia-res"); if (c && c.querySelector(".ct-error")) c.innerHTML = ""; }
  // lo que dijo la base al clasificar (fn_contador_clasificar): aprobada o editada, el asiento y la regla que aprendió.
  // `porAsi`: vino de «Así es» (si no, de «Clasificar», que la base marca «aprobada» cuando coincide con la propuesta)
  function resumenClasificado(r, porAsi) {
    const x = r || {}, g = x.regla && x.regla.regla ? x.regla : null;
    // (7b) «Así es» con otra obra que la propuesta: la base la deja «editada»
    const que = porAsi ? (x.estado === "editada" ? "Así es, con tu obra: en el libro" : "Así es: en el libro") : x.estado === "editada" ? "Clasificado (cambiaste la propuesta)" : x.fuente && x.fuente !== "edgar" ? "Clasificado (igual que la IA)" : "Clasificado";
    return `${que}${x.asiento ? ` · asiento ${x.asiento}` : ""}${g ? ` · ${g.nueva ? "regla nueva" : g.cambio ? "regla cambiada" : "regla"} «${g.nombre}»` : ""}`;
  }
  const resumenRafaga = r => {
    const x = r || {};
    if (x.bloqueado) return [`La IA no propuso nada: ${x.motivo || "llegó al tope del mes"}`, true];
    const txt = `${plural(nOk(x.propuestas), "propuesta", "propuestas")}${nOk(x.con_obra) ? ` (${nOk(x.con_obra)} con obra)` : ""} · ${nOk(x.reglas)} por regla · ${nOk(x.sin_respuesta)} sin respuesta${nOk(x.invalidas) ? ` · ${nOk(x.invalidas)} inválida(s)` : ""} · ${usdCent(x.centavos)}`;
    // (la función dice el porqué de lo que no salió: un 529 dos veces, un rechazo de la IA… se cuenta y no se esconde)
    return x.error ? [`${txt} · ojo: ${String(x.error).slice(0, 140)}`, !nOk(x.propuestas) && !nOk(x.reglas)] : txt;
  };
  // ---------- (7c) LAS PROPUESTAS SALEN SOLAS: la cadena de ráfagas ----------
  // «Que cada partida al lado ya tenga su propuesta, sin darle a un botón.» Al pintar la Bandeja (y al terminar de subir un
  // archivo del banco o de sincronizar con Plaid), si hay cargos sin propuesta y nada lo frena (frenoIA: la IA activa y sin
  // tope, la llave y la función sanas, la sesión con el código del teléfono), la pantalla pide la ráfaga SOLA ({accion:
  // "proponer"}: primero las reglas, sin gastar; luego la IA, con su tope y su máximo por ráfaga) y, mientras la función diga
  // que quedan (quedan > 0), la siguiente. Es lo mismo que hace la rutina de la base cada mañana y cada tarde, con la app
  // abierta: lo que entra a media tarde no espera a la noche. Las reglas que la sostienen:
  //   · UNA cadena a la vez (S.cadena): repintar la Bandeja, volver a ella o tocar «Proponer ahora» con una en marcha no
  //     arranca otra. La base tampoco abre dos ráfagas (MX008 «ráfaga en marcha»: la de la rutina, otra pestaña): se
  //     esperan 5 s y se reintenta UNA vez; si sigue, la cadena se para y lo dice.
  //   · No tapa la Bandeja: mientras propone, Edgar aprueba o clasifica (S.ocupado es de cada acción, no de la cadena). Cada
  //     ráfaga relee lo de la IA (v_contador_estado, la bandeja de la IA y su control) y repinta la franja y las filas —los
  //     chips aparecen—, salvo la fila que Edgar tiene a medias y salvo mientras corre una acción suya (ella repinta al acabar).
  //   · Se para sola: sin quedan en la respuesta (la función de la 7b: una ráfaga, como antes), con quedan = 0, si la función
  //     dice que no sigue (sigue: false) o una ráfaga no avanza (ni una propuesta nueva, o quedan los mismos: la IA no contesta
  //     esos cargos y no se insiste), con el tope,
  //     con un error (se dice en la franja) o con «Parar» (la ráfaga en vuelo termina en la función y lo suyo se guarda).
  //   · No vuelve a arrancar sola por lo mismo: al terminar recuerda qué cargos seguían esperando (S.iaSola.memo) y solo
  //     arranca otra vez si llega uno nuevo; un «No es eso» no hace que la IA proponga otra al instante (lo dices tú en
  //     «Según yo»). «Parar» apaga lo automático hasta que se abra la app otra vez o se toque «Proponer ahora».
  //   · El interruptor «Proponer sola al abrir la Bandeja» (Conexiones) es una preferencia de este aparato (localStorage,
  //     encendido por defecto): ni dinero ni nada del libro.
  // NUNCA postea: la cadena solo pide «proponer»; lo que entra al libro sigue siendo el toque de Edgar.
  const LLAVE_SOLA = "mxp.contador.sola";
  const solaEncendida = () => { try { return localStorage.getItem(LLAVE_SOLA) !== "0"; } catch { return true; } };
  const guardarSola = si => { try { localStorage.setItem(LLAVE_SOLA, si ? "1" : "0"); } catch { /* sin almacenamiento: vuelve a encendido al recargar */ } };
  const MAX_RAFAGAS = 40;          // por si acaso (40 × 20 = 800 cargos): la cadena acaba mucho antes por quedan o por no avanzar
  const ESPERA_EN_MARCHA = 5000;   // MX008 «ráfaga en marcha»: lo que se espera antes del único reintento
  const dormir = ms => new Promise(r => setTimeout(r, ms));
  const enMarcha = err => !!err && (err.codigo === "MX008" || err.estado === 409) && /en marcha/i.test(String(err.message || ""));
  // los cargos que esperan propuesta según lo que pintó la bandeja (los de los motivos de la IA sin propuesta pendiente)
  const candidatosIA = () => (S.bandeja || []).filter(m => !m._esStripe && MOTIVOS_IA.includes(m.motivo) && !iaPendiente(m));
  // los NUEVOS: ni rechazados por Edgar («No es eso»: lo dice él) ni los que ya esperaban cuando terminó la última cadena (si
  // esa corrió fuera de la Bandeja —tras un archivo o Plaid— no sabe cuáles eran: solo cuántos, y con los mismos no arranca)
  const nuevosIA = () => {
    const memo = S.iaSola.memo;
    if (memo && !memo.ids && nOk(S.ia && S.ia.estado && S.ia.estado.pendientes_sin_propuesta) === memo.n) return [];
    return candidatosIA().filter(m => {
      const f = S.ia && S.ia.bandeja.get(m.movimiento_id);
      return !(f && f.estado === "rechazada") && !(memo && memo.ids && memo.ids.has(m.movimiento_id));
    });
  };
  const puedeSola = () => solaEncendida() && !S.iaSola.parada && !(S.cadena && S.cadena.activa) && iaViva() && !frenoIA(S.ia);
  // después de subir un archivo o de sincronizar: lo de la IA, fresco, y la cadena si algo nuevo espera (sin señal o sin c8, nada)
  async function proponerTrasImportar() {
    if (!solaEncendida() || S.iaSola.parada || (S.cadena && S.cadena.activa) || !mfaActivo() || !navigator.onLine) return;
    try {
      const ia = await leerContador();
      if (!ia || ia.err) return;
      S.ia = ia;
      const n = nOk(ia.estado && ia.estado.pendientes_sin_propuesta);
      if (puedeSola() && !(S.iaSola.memo && S.iaSola.memo.n === n)) await cadenaIA("importe");
    } catch { /* sin señal: la rutina de la tarde o la próxima vez que se abra la Bandeja */ }
  }
  // `origen`: "sola" (al pintar la Bandeja), "importe" (tras un archivo o Plaid) o "manual" («Proponer ahora»)
  async function cadenaIA(origen) {
    if ((S.cadena && S.cadena.activa) || !iaViva() || frenoIA(S.ia)) return;
    if (origen === "manual") S.iaSola.parada = false;
    const c = S.cadena = { activa: true, origen, parar: false, esperando: false, total: nOk(S.ia.estado.pendientes_sin_propuesta), hechas: 0, quedan: null,
      rafagas: 0, propuestas: 0, conObra: 0, reglas: 0, sinResp: 0, invalidas: 0, centavos: 0, bloqueado: null, frenada: null, error: null, atascada: false, avisos: [], fin: null };
    pintarCadena(false);
    let antes = null;
    try {
      while (c.rafagas < MAX_RAFAGAS && !c.parar) {
        const r = await rafagaIA(c);
        if (!r) break; // «Parar» mientras esperaba el reintento
        c.rafagas += 1;
        if (r.bloqueado) {
          // (las reglas van antes que el tope y pudieron dejar propuestas: se cuentan y se relee)
          c.bloqueado = r.motivo || "llegó al tope del mes"; c.reglas += nOk(r.reglas); c.hechas += nOk(r.reglas);
          await refrescarIA(); break;
        }
        const avance = nOk(r.propuestas) + nOk(r.reglas);
        c.propuestas += nOk(r.propuestas); c.conObra += nOk(r.con_obra); c.reglas += nOk(r.reglas); c.sinResp += nOk(r.sin_respuesta);
        c.invalidas += nOk(r.invalidas); c.centavos += nOk(r.centavos); c.hechas += avance;
        if (r.error) c.avisos.push(String(r.error));
        c.quedan = r.quedan == null ? null : nOk(r.quedan);
        c.total = Math.max(c.total, c.hechas + (c.quedan || 0));
        // (lo releído, no S.ia: una acción de Edgar que termina a la vez lo vacía un momento para releerlo ella)
        const ia = await refrescarIA();
        if (c.quedan == null || c.quedan === 0 || c.parar) break;
        // la función dice si tiene sentido otra ahora («sigue»: quedan y esta dejó alguna propuesta); sin él, lo mismo a mano: que
        // haya avanzado y queden menos. Si no, la base volvería a dar los mismos cargos y se pediría sin fin lo que la IA no contesta
        if (r.sigue === false || !avance || (antes != null && c.quedan >= antes)) { c.atascada = true; break; }
        antes = c.quedan;
        // la IA dejó de cuadrar (la franja lo pinta en rojo) o algo la frena entre ráfagas (el tope, el código del teléfono): se para y lo dice
        if (!ia || ia.err || ia.rojo.length) { c.frenada = "la IA contable dejó de cuadrar (el detalle, arriba)"; break; }
        const fr = frenoIA(ia);
        if (fr) { if (nOk(ia.estado.pendientes_sin_propuesta)) c.frenada = fr.txt; break; }
        pintarCadena(true);
      }
    } catch (err) {
      c.error = err;
      // (una ráfaga que falla pudo dejar propuestas por regla antes de fallar: se relee lo que haya; sin señal, se queda lo de antes)
      try { await refrescarIA(); } catch { /* sin señal */ }
    }
    c.activa = false;
    S.iaSola.memo = { ids: S.bandeja ? new Set(candidatosIA().map(m => m.movimiento_id)) : null, n: nOk(S.ia && S.ia.estado && S.ia.estado.pendientes_sin_propuesta) };
    if (c.parar) S.iaSola.parada = true;
    c.fin = finCadena(c);
    S.hooks.avisar(...avisoCadena(c));
    pintarCadena(true);
  }
  // una ráfaga; MX008 «ráfaga en marcha» espera y reintenta una vez (null si se paró mientras esperaba)
  async function rafagaIA(c) {
    for (let intento = 0; ; intento++) {
      try { return await DB._funcion("contador", { accion: "proponer" }, 180000); }
      catch (err) {
        if (!enMarcha(err) || intento > 0 || c.parar) throw err;
        c.esperando = true; pintarCadena(false);
        await dormir(ESPERA_EN_MARCHA);
        c.esperando = false;
        if (c.parar) return null;
        pintarCadena(false);
      }
    }
  }
  // lo de la IA, fresco, después de una ráfaga (la salud no se vuelve a preguntar: la función acaba de contestar). Sin señal, lanza
  async function refrescarIA() {
    const ia = await leerContador(S.ia && S.ia.salud ? { salud: S.ia.salud } : null);
    if (ia) S.ia = ia;
    return ia;
  }
  // la franja (y, con `filas`, las filas cuya propuesta cambió) con lo último: solo con la Bandeja a la vista, y las filas no
  // mientras corre una acción de Edgar (ella repinta la página al terminar, con todo fresco)
  function pintarCadena(filas) {
    if (S.pagina !== "bandeja" || !S.ia || !$("ct-ia-franja")) return;
    const vieja = $("ct-ia-franja");
    vieja.outerHTML = franjaIAHTML(S.ia);
    wireFranja();
    if (filas && !S.ocupado) refrescarFilasIA();
  }
  // «Proponer ahora» (la cadena, a mano) y «Parar» (la ráfaga en vuelo termina en la función; no se pide otra)
  function wireFranja() {
    const pro = $("ct-ia-proponer"); if (pro) pro.addEventListener("click", () => cadenaIA("manual"));
    const pa = $("ct-ia-parar"); if (pa) pa.addEventListener("click", () => { if (S.cadena && S.cadena.activa) { S.cadena.parar = true; pintarCadena(false); } });
  }
  const errorLlano = err => esFalloDeRed(err) || !navigator.onLine ? "sin señal (o la función «contador» no contestó)" : err.codigo === "MFA" ? "falta el código del teléfono: entra otra vez con él" : String(err.message || err);
  // lo que hizo la cadena, para el aviso: con una ráfaga, el mismo que antes («1 propuesta · 0 por regla · 0 sin respuesta · $0.12»)
  function avisoCadena(c) {
    const r = resumenRafaga({ propuestas: c.propuestas, con_obra: c.conObra, reglas: c.reglas, sin_respuesta: c.sinResp, invalidas: c.invalidas, centavos: c.centavos, error: c.avisos[0] || null });
    const [txt0, mal] = Array.isArray(r) ? r : [r, false];
    const txt = c.rafagas > 1 ? `${c.rafagas} ráfagas: ${txt0}` : txt0;
    if (c.error) return [`La IA se paró: ${errorLlano(c.error)}${c.hechas ? ` (antes, ${txt})` : ""}`, true];
    if (c.bloqueado) return c.hechas ? [`${txt} · y se paró: ${c.bloqueado}`, true] : [`La IA no propuso nada: ${c.bloqueado}`, true];
    if (c.frenada) return [`${txt} · y se paró: ${c.frenada}`, true];
    if (c.parar) return [`Paraste la IA: ${txt}`, false];
    return [txt, mal];
  }
  // lo que queda dicho en la franja hasta la próxima pintada ({ txt, clase })
  function finCadena(c) {
    const hecho = `${plural(c.propuestas, "propuesta", "propuestas")}${c.conObra ? ` (${c.conObra} con obra)` : ""}${c.reglas ? ` y ${c.reglas} por regla` : ""} · ${usdCent(c.centavos)}`;
    if (c.error) return { txt: `La IA se paró: ${errorLlano(c.error)}.${c.hechas ? ` Antes dejó ${hecho}.` : ""} Vuelve a tocar «Proponer ahora» cuando quieras.`, clase: "bad" };
    if (c.bloqueado) return { txt: `La IA se paró: ${c.bloqueado}.${c.hechas ? ` Antes dejó ${hecho}.` : ""}`, clase: "warn" };
    if (c.frenada) return { txt: `La IA se paró: ${c.frenada.replace(/[.:]$/, "")}. Antes dejó ${hecho}.`, clase: "warn" };
    if (c.parar) return { txt: `Paraste la IA (dejó ${hecho}): no vuelve a proponer sola hasta que abras la app otra vez o toques «Proponer ahora».`, clase: "warn" };
    if (c.atascada) return { txt: `Listo: ${hecho}. ${plural(c.quedan, "cargo sigue", "cargos siguen")} sin propuesta (la IA no los contestó${c.avisos[0] ? `: ${String(c.avisos[0]).slice(0, 120)}` : ""}): clasifícalos tú o vuelve a probar más tarde.`, clase: "warn" };
    return { txt: `Listo: ${hecho}${c.sinResp ? ` · ${c.sinResp} sin respuesta` : ""}.`, clase: "ok" };
  }
  // Los errores de la función contador en llano
  function errorContadorHTML(err) {
    if (esFalloDeRed(err) || !navigator.onLine) return `<p class="ct-aviso bad">Sin señal (o la función «contador» no contestó): no se hizo nada.</p>`;
    if (err.codigo === "MFA") return `<p class="ct-aviso warn">Falta el código del teléfono: entra otra vez con él.</p>`;
    const pista = err.datos && err.datos.pista;
    if (pista === "elige la obra" || /elige la obra/i.test(err.message || "")) return `<p class="ct-aviso warn">${esc(err.message)}</p>`;
    if (/^MX/i.test(String(err.codigo || "")) || err.estado === 409) return `<p class="ct-aviso warn">${esc(err.message)}</p>`;
    return `<p class="ct-aviso bad">${esc(err.message)}</p>`;
  }
  const limpiarIA = () => { S.ia = null; S.iaCx = null; S.iaCxErr = null; S.saldos = null; S.bandeja = null; };
  function accionIA(cont, cuerpo, exito, opciones = {}) {
    return accionFuncion("contador", cont, cuerpo, exito, Object.assign({ res: "ct-ia-res", pide: "la IA contable lo pide", errorHTML: errorContadorHTML, limpiar: limpiarIA, ms: 60000 }, opciones));
  }

  // ---------- La tarjeta de Conexiones y seguridad: el estado, «Probar» y las reglas con «Quitar» ----------
  async function leerContadorCx() {
    try {
      const [est, reglas, ctl] = await Promise.all([
        DB._leer("v_contador_estado?select=*"),
        DB._leer("v_contador_reglas?select=id,nombre,patron,cuenta_banco,cuentas_texto,pide_obra,activa,origen,veces,ultima_vez,creada_el,pendientes&order=activa.desc,nombre.asc"),
        DB._leer("v_contador_control?select=*&order=orden.asc")
      ]);
      const rojo = controlContador(ctl, { v_contador_reglas: reglas.length });
      if (!Array.isArray(est) || est.length !== 1) rojo.push({ vista: "v_contador_estado", filas: Array.isArray(est) ? est.length : 0, esperadas: 1, detalle: "no devolvió su fila (¿falta contador_config o la sesión no es la del dueño?)" });
      S.iaCx = { estado: (est || [])[0] || null, reglas, control: ctl, rojo, salud: null, saludErr: null, obrasCerradas: obrasCerradasDe(ctl) };
      if (mfaActivo()) Object.assign(S.iaCx, await saludContador());
      S.iaCxErr = null;
    } catch (err) { if (esFalloDeRed(err)) throw err; S.iaCx = null; S.iaCxErr = err; }
    return S.iaCx;
  }
  const saludIAHTML = r => {
    const x = r || {};
    const mal = [x.llave === false && "falta la llave de Anthropic (ANTHROPIC_API_KEY)", x.base === false && "no llega a la base"].filter(Boolean);
    return `<p class="ct-aviso ${mal.length ? "bad" : "ok"}">${mal.length ? `La función «contador» contesta, pero ${esc(mal.join(" y "))}.` : "La función «contador» contesta: tiene la llave y llega a la base."}${x.modelo ? ` Modelo ${esc(x.modelo)}${x.effort ? ` (esfuerzo ${esc(x.effort)})` : ""}.` : ""}${faltaIA(x) ? ` Falta: ${esc(faltaIA(x))}.` : ""}</p>`;
  };
  function iaCardHTML(ia, err) {
    const cab = extra => `<div class="ct-cab"><h2>IA contable (fase 7)</h2>${extra}</div>`;
    if (!ia) {
      const falta = !err || sinInstalar(err);
      return `<section class="ct-card ct-ia-card" id="ct-ia">${cab(pill(falta ? "sin instalar" : "no contestó", "warn"))}
        <p class="ct-nota">${falta ? "La base todavía no tiene la IA contable (docs/conta/c8-contador.sql). Cuando se pegue, la Bandeja propone la cuenta de cada cargo sin ticket y aquí se ven su gasto y sus reglas." : `La vista no contestó: ${esc(err.message)}.`}</p></section>`;
    }
    const e = ia.estado || {}, mfa = mfaActivo(), s = ia.salud, rut = rutinaIA(e, false), marc = marcadorIA(e);
    const pills = (!mfa ? pill("sin el código del teléfono", "warn") : !s ? pill("la función no contestó", "warn") : s.llave === false ? pill("falta la llave", "bad") : s.base === false ? pill("sin base", "bad") : pill("conectada", "ok")) +
      (ia.rojo.length ? pill("no cuadra", "bad") : pill("cuadra", "ok")) + (nCerradas(ia) ? pill(plural(nCerradas(ia), "obra propuesta cerrada", "obras propuestas cerradas"), "warn") : "") +
      (e.activa === false ? pill("apagada", "warn") : "") +
      (e.bloqueado && e.activa !== false ? pill("en el tope", "warn") : "") + (nOk(e.alarmas) > 0 ? pill(plural(e.alarmas, "alarma", "alarmas"), "warn") : "") +
      // (7c) la rutina que propone sola, si su última corrida falló
      (rut && rut.clase === "bad" ? pill("rutina con error", "bad") : "");
    const activas = (ia.reglas || []).filter(r => r.activa), bajas = (ia.reglas || []).length - activas.length;
    const dis = mfa ? "" : " disabled";
    const reglas = ia.rojo.length ? "" : `<h3 class="ct-ia-h3">Reglas del contador · ${activas.length}</h3>
      ${activas.length ? `<ul class="ct-ia-reglas">${activas.map(r => `<li class="ct-ia-regla" data-regla="${esc(r.id)}">
          <div class="ct-ia-regla-fila"><div class="ct-ia-regla-txt"><b>${esc(r.nombre)}</b> → ${esc(r.cuentas_texto || "")}${r.pide_obra ? ` ${pill("pide obra", "warn")}` : ""}
            <small>${plural(nOk(r.veces), "vez", "veces")}${r.ultima_vez ? ` · la última el ${fechaLarga(String(r.ultima_vez).slice(0, 10))}` : ""} · ${r.origen === "edgar" ? "la dictaste tú" : "aprendida al aprobar"}${r.cuenta_banco ? ` · solo en ${esc(r.cuenta_banco)}` : ""}</small></div>
            <button type="button" class="accion secundaria chica" data-quitar${dis}>Quitar</button></div>
          <div class="ct-form" hidden></div><div class="ct-ia-res"></div></li>`).join("")}</ul>`
        : `<p class="ct-vacio">Todavía no hay reglas: nacen en la Bandeja, al decir «Así es» o «Clasificar» con «Recordar para este comercio».</p>`}
      ${bajas ? `<p class="ct-nota">${plural(bajas, "regla dada de baja", "reglas dadas de baja")} (quedan escritas con su motivo).</p>` : ""}`;
    return `<section class="ct-card ct-ia-card" id="ct-ia">${cab(pills)}
      ${ayudaHTML(`<p class="ct-nota">La IA mira cada cargo sin ticket y propone a qué cuenta va, con el motivo de lo que vio: propone, nunca postea. Lo que dice una regla del comercio entra sin gastar IA; nada entra al libro hasta que dices «Así es» o lo clasificas tú. Tiene un tope de gasto al mes, y la llave vive en Supabase, nunca en el teléfono.</p>
        <p class="ct-nota">También propone la obra cuando las pistas que calcula la base (las horas de la cuadrilla esos días, los tickets del mismo comercio, lo que elegiste antes, los materiales recientes) apuntan a una sola; sin pistas claras no la adivina. A la IA no le llega ningún nombre de persona ni nota: solo totales por obra. Las reglas recuerdan la cuenta, nunca la obra.</p>
        <p class="ct-nota">Propone sola: al abrir la Bandeja (si el interruptor de abajo está encendido) y con la rutina de la base, cada mañana después del banco y cada tarde. Solo una obra con 80 % o más sale elegida; con menos, la Bandeja te enseña las obras de sus pistas y eliges de un toque. «Este mes» cuenta lo que entró por la IA o por una regla: acertada es lo que entró tal cual lo propuso; «elegiste tú», la obra que la IA no supo y pusiste tú.</p>`)}
      ${ia.rojo.length ? `<p class="ct-aviso bad">La IA contable no cuadra: ${esc(ia.rojo.map(m => `${m.vista}${m.detalle ? ` (${m.detalle})` : ""}`).join("; "))}.</p>` : ""}
      ${mfa && !s ? `<p class="ct-aviso warn">La función «contador» no contestó: ¿está desplegada en Supabase → Edge Functions (con «Verify JWT» apagado)?</p>`
        : s && (s.llave === false || faltaIA(s)) ? `<p class="ct-aviso bad">Falta en Supabase → Edge Functions → Secrets: ${esc(faltaIA(s) || "la llave de Anthropic (ANTHROPIC_API_KEY)")}.</p>` : ""}
      ${mfa && s && s.rutina === false ? `<p class="ct-aviso warn" id="ct-ia-sin-secreto">Falta el secreto de la rutina en Supabase → Edge Functions → Secrets: CONTADOR_RUTINA_SECRETO (el valor que enseña docs/conta/c8-contador.sql al pegarlo, en la fila «contador_rutina_secreto»); sin él la rutina de la base no propone sola por la mañana y por la tarde (la Bandeja sí propone al abrirla).</p>` : ""}
      <ul class="ct-datos">
        <li>Llave de Anthropic: ${!mfa ? "sin saber (sin el código del teléfono no se le pregunta a la función)" : !s ? "sin saber (la función no contestó)" : s.llave ? "puesta" : `<span class="bad-txt">falta</span>`}</li>
        <li>Modelo: <span class="ct-num">${esc(e.modelo || "—")}</span>${e.effort ? ` (esfuerzo ${esc(e.effort)})` : ""} · como mucho ${plural(nOk(e.max_por_rafaga), "cargo", "cargos")} por ráfaga</li>
        <li>Este mes: la IA contable lleva <span class="ct-num">${usdCent(e.centavos_mes_contador)}</span> de <span class="ct-num">${usdCent(e.tope_mes_centavos)}</span>; toda la IA de la app, <span class="ct-num">${usdCent(e.centavos_mes_total)}</span> de <span class="ct-num">${usdCent(e.tope_global)}</span></li>
        <li>Última ráfaga: ${e.ultima_rafaga_el ? fechaHora(e.ultima_rafaga_el) : "ninguna todavía"}${e.ultimo_lote_centavos != null ? ` (${usdCent(e.ultimo_lote_centavos)})` : ""}</li>
        ${e.ultimo_error ? `<li class="bad-txt">Último error: ${esc(e.ultimo_error)}${e.ultimo_error_el ? ` (${fechaHora(e.ultimo_error_el)})` : ""}</li>` : ""}
        <li>Propuestas: ${plural(nOk(e.propuestas_pendientes), "espera", "esperan")} en la bandeja${nOk(e.propuestas_con_obra) ? ` (${nOk(e.propuestas_con_obra)} con obra)` : ""} · ${nOk(e.aprobadas_total)} en el libro · ${plural(nOk(e.rechazadas_total), "rechazada", "rechazadas")}</li>
        ${marc ? `<li id="ct-ia-marcador">${esc(marc)}</li>` : ""}
        ${rut ? `<li id="ct-ia-rutina"${rut.clase === "bad" ? ` class="bad-txt"` : rut.clase === "warn" ? ` class="ct-ia-rut warn"` : ""}>${esc(rut.txt)}</li>` : ""}
      </ul>
      <label class="ct-casilla ct-ia-sola"><input type="checkbox" id="ct-ia-sola"${solaEncendida() ? " checked" : ""}> Proponer sola al abrir la Bandeja</label>
      <p class="ct-nota ct-ia-sola-nota">Se guarda solo en este aparato (es una preferencia, no un dato del libro). Apagado, la Bandeja espera a que toques «Proponer ahora»; la rutina de la base sigue igual.</p>
      <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-ia-probar"${dis}>Probar</button><button type="button" class="accion secundaria" id="ct-ia-bandeja">Ver la bandeja</button>${mfa ? "" : `<span class="ct-nota" style="margin:0">Primero activa el código del teléfono (arriba).</span>`}</div>
      <div class="ct-ia-res"></div>
      ${reglas}
    </section>`;
  }
  function wireIACx() {
    const card = $("ct-ia"); if (!card || !S.iaCx) return;
    const pr = $("ct-ia-probar"); if (pr) pr.addEventListener("click", () => accionIA(card, { accion: "salud" },
      r => r && r.llave === false ? ["La función contesta, pero le falta la llave de Anthropic", true] : "La IA contable contesta bien", { repintar: false, mostrar: saludIAHTML, ms: 15000 }));
    const vb = $("ct-ia-bandeja"); if (vb) vb.addEventListener("click", () => ir("bandeja"));
    // (7c) el interruptor «Proponer sola al abrir la Bandeja»: encenderlo también deshace un «Parar» de esta sesión
    const so = $("ct-ia-sola"); if (so) so.addEventListener("change", () => {
      guardarSola(so.checked);
      if (so.checked) S.iaSola.parada = false;
      S.hooks.avisar(so.checked ? "La Bandeja propone sola al abrirla" : "La Bandeja ya no propone sola: toca «Proponer ahora» cuando quieras");
    });
    card.querySelectorAll(".ct-ia-regla").forEach(li => {
      const r = (S.iaCx.reglas || []).find(x => String(x.id) === li.dataset.regla); if (!r) return;
      const q = li.querySelector("[data-quitar]"); if (q) q.addEventListener("click", () => montarForma(li,
        formaHTML(`Quitar la regla «${esc(r.nombre)}» (→ ${esc(r.cuentas_texto || "")}): los cargos de este comercio vuelven a pasar por la IA. Nada se borra: queda escrita con tu motivo.`,
          campoHTML("motivo", "Motivo (queda escrito con la regla)", "textarea", "required"), "Quitar la regla"),
        v => accionIA(li, { accion: "regla_baja", regla: r.id, motivo: v.motivo }, () => `Regla «${r.nombre}» quitada`)));
    });
  }
  // Las alarmas de la IA en llano para «Qué atender» (el control dice la condición que se cumple cuando todo va bien) y a qué página llevan
  const ALARMA_IA = {
    70: ["La IA contable llegó al tope de gasto del mes: no propone nada hasta el mes que viene.", "conexiones"],
    71: ["Propuestas de la IA que esperan más de 7 días: di «Así es» o «No es eso» en la Bandeja.", "bandeja"],
    72: ["La última ráfaga de la IA terminó con error: mira el detalle y toca «Probar» en Conexiones.", "conexiones"],
    73: ["La IA contable no ha propuesto nada nunca y hay cargos esperando: abre la Bandeja (propone sola) o toca «Proponer ahora».", "bandeja"],
    // (7c) la rutina de la base (pg_cron → la función) falló o lleva más de 36 horas sin correr con cargos esperando
    74: ["La rutina que propone sola (cada mañana tras el banco y cada tarde) no está corriendo bien: mira el detalle y la tarjeta de la IA en Conexiones.", "conexiones"]
  };

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
    const abiertas = lista.filter(c => c.estado === "abierta").length, confirmadas = lista.filter(c => c.estado === "confirmada").length;
    main().innerHTML = cabPagina("Conciliar", lista.length ? `${plural(lista.length, "conciliación", "conciliaciones")} · ${plural(abiertas, "abierta", "abiertas")} · ${plural(confirmadas, "confirmada", "confirmadas")}` : "Todavía no hay ninguna conciliación: la primera se calcula aquí abajo.") +
      `<section class="ct-card">
        <h2>Conciliar una cuenta con su statement</h2>
        ${ayudaHTML(`<p class="ct-nota">Sube antes el archivo del statement (en Bancos y tarjetas). Aquí van la fecha de corte y el saldo final tal como lo dice el statement (en una tarjeta, lo que debes, en positivo). Cuadra cuando libros = banco + lo que está en libros y no en el banco − lo que está en el banco y no en libros.</p>`)}
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
    marcarVolver();
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
    main().innerHTML = cabPagina(`Conciliación · ${c.cuenta_nombre}`, `corte ${fechaLarga(c.fecha_corte)} · ${estadoPill(c.estado)} ${pill(c.tipo)}`,
        `<button type="button" class="accion secundaria" id="ct-volver-lista">Todas las conciliaciones</button>`) +   // sin flecha: el «←» de la barra de la app ya cierra esta conciliación
      `<section class="ct-card">
        <div class="ct-cab"><h2>Libros contra statement</h2></div>
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
    marcarVolver();
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
    if (S.pagina !== "movimientos") return;
    const estados = Object.keys(ESTADO_MOV);
    // la cabecera lleva los selectores; la tabla es densa en la computadora y en el teléfono se apila en dos líneas (data-col pone las etiquetas)
    main().innerHTML = cabPagina("Movimientos",
        `${plural(filas.length, "movimiento", "movimientos")}${filas.length >= 300 ? " (los 300 más recientes)" : ""} de ${esc(nombreCuenta(S.movCuenta))}${S.movEstado && ESTADO_MOV[S.movEstado] ? ` · ${esc(ESTADO_MOV[S.movEstado][0])}` : ""} · cada uno con lo que la base decidió y el asiento con que casó`, "",
        `<label class="ct-campo">Cuenta<select id="ct-mov-cuenta">${visibles(S.saldos).map(c => `<option value="${esc(c.cuenta)}"${c.cuenta === S.movCuenta ? " selected" : ""}>${esc(c.cuenta)} · ${esc(c.cuenta_nombre)}</option>`).join("")}</select></label>
         <label class="ct-campo">Estado<select id="ct-mov-estado"><option value="">Todos</option>${estados.map(e => `<option value="${e}"${e === S.movEstado ? " selected" : ""}>${ESTADO_MOV[e][0]}</option>`).join("")}</select></label>`) +
      (filas.length ? `<section class="ct-card ct-densa"><div class="ct-tabla-env"><table class="ct-tabla ct-mov-tabla"><thead><tr><th>Fecha</th><th>Descripción</th><th class="r">Monto</th><th>Estado</th><th>Cómo</th><th>Asiento</th></tr></thead><tbody>
        ${filas.map(m => { const e = ESTADO_MOV[m.estado] || [m.estado, ""]; return `<tr><td class="ct-c-fecha ct-num">${fechaLarga(m.fecha)}</td><td class="ct-c-desc"><b>${esc(m.descripcion || "")}</b>${m.memo ? `<small>${esc(m.memo)}</small>` : ""}${m.cheque ? `<small>cheque ${esc(m.cheque)}</small>` : ""}</td><td class="r ct-num ct-c-monto ${num(m.monto) < 0 ? "neg" : "pos"}">${fmt(m.monto)}</td><td class="ct-c-estado">${pill(e[0], e[1])}</td><td class="ct-c-como" data-col="Cómo"><small>${esc(m.estado === "pendiente" ? motivoLlano(m.propuesta_motivo) : [m.casado_regla || m.casado_clase || "", m.casado_auto === true ? "solo" : m.casado_auto === false ? "Edgar" : "", m.estado_motivo || ""].filter(Boolean).join(" · "))}</small></td><td class="ct-num ct-c-asiento"${m.asiento_numero || m.papel_tabla ? ` data-col="Asiento"` : ""}><small>${esc(m.asiento_numero || "")}${m.papel_tabla ? `<br>${esc(m.papel_tabla)} ${esc(m.papel_id || "")}` : ""}</small></td></tr>`; }).join("")}
      </tbody></table></div></section>` : `<section class="ct-card ct-vacio">Nada con ese filtro.</section>`);
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

  // v_cortes, con caché de un día: la fila 'hoy' trae la fecha de Miami, y el control y el balance de «hoy» ya corren con el día real.
  // Vacío se devuelve vacío (quien llama decide si es rojo o un «todavía no hay períodos» en llano) y no se guarda
  async function leerCortes() {
    if (S.est.cortes && S.est.cortesDia !== hoyMiami()) S.est.cortes = null;
    if (S.est.cortes) return S.est.cortes;
    const c = await DB._leer("v_cortes?select=periodo,tipo,anio,desde,corte,estado,paralelo&order=desde.desc,tipo.asc");
    if (!Array.isArray(c) || !c.length) return [];
    S.est.cortes = c; S.est.cortesDia = hoyMiami();
    return c;
  }
  async function pintarEstados() {
    const mia = ++S.est.serie;
    if (!navigator.onLine) return sinSenal(pintarEstados);
    if (S.est.cortes && S.est.cortesDia !== hoyMiami()) S.est.cortes = null;
    if (!S.est.cortes) {
      cargando("Controlando con la base…");
      try {
        const c = await leerCortes();
        if (mia !== S.est.serie) return;
        if (!c.length) {
          // El equipo recibe [] con 200 de toda vista: el control dice si es «solo dueño» (42501) o si de verdad no hay períodos
          await controlarEstados("hoy", ["v_cortes"]);
          throw errorControl("La base no tiene períodos", [{ vista: "v_cortes", filas: 0, esperadas: "1 o más", detalle: "v_cortes no devolvió ningún período: el libro no está abierto todavía (c2 siembra los períodos). Nada que pintar." }]);
        }
      } catch (err) {
        if (mia !== S.est.serie) return;
        return pintarError(err, () => { S.est.cortes = null; pintarEstados(); }, err.codigo === "42501" ? "Contabilidad es solo del dueño" : undefined);
      }
    }
    if (mia !== S.est.serie || S.pagina !== "estados") return;
    const corte = resolverPeriodo();
    if (!S.est.cuenta && !S.est.asiento) S.hooks.titulo(KICKER, TITULOS.estados);
    main().innerHTML = cabPagina("Estados financieros", "Cada cifra viene lista de la base y se controla antes de pintarse. Toca una cuenta para bajar a su mayor y a cada asiento.") +
      barraHTML(S.est.cortes, corte) + `<div id="ct-est-cuerpo"></div>`;
    engancharBarra();
    marcarVolver();
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

  // ============================================================
  // EL CIERRE DEL MES (c9, fase 8) — docs/conta/c9-cierre.sql y
  // docs/conta/OPERACION.md. Una página con seis apartados (chips, como
  // los de Estados): el cierre, los activos fijos, la reserva de
  // impuestos, el DR-15, el historial y los ajustes. Manda la base:
  //   · LA REVISIÓN. Al abrir, la pantalla pide fn_cierre_revisar del
  //     período que toca (el «siguiente» de v_cierre_estado, o el que Edgar
  //     eligió en la lista) y pinta su lista fija: lo que DETIENE arriba, en
  //     rojo, cada uno con su detalle en llano, «qué hacer» y el botón a la
  //     página que lo arregla (ir_a); los avisos aparte; lo que está en
  //     verde, plegado. Después vuelve a leer v_cierre_estado, que enseña la
  //     foto que la base acaba de guardar: si sus «detienen» y «avisos» no
  //     son los de la lista, rojo (falla ruidosa) y no hay botón de cerrar.
  //   · CERRAR. El botón («Cerrar octubre 2026») está apagado mientras algo
  //     detiene, mientras el período no termina y sin el código del teléfono
  //     (como lo que no se deshace en el resto de la contabilidad). Al
  //     tocarlo se abre la confirmación fuerte: Edgar escribe la frase exacta
  //     que dice la base (v_cierre_estado.confirmacion: «CERRAR OCTUBRE
  //     2026», «CERRAR LA APERTURA»); mal escrita, el botón sigue apagado y
  //     no se manda nada. fn_cierre_cerrar vuelve a revisar con el libro
  //     quieto: si algo entró mientras tanto, MX010 con su lista, y la
  //     pantalla lo explica en llano y vuelve a revisar.
  //   · EL EXPORT, en el navegador, justo después de cerrar (y «Volver a
  //     exportar» para un período cerrado sin export): el mayor del período
  //     en CSV, por cuenta, con su saldo corrido, su procedencia, el sello de
  //     la IA y el papel (v_mayor); la balanza que la base guardó al cerrar
  //     (fn_cierre_balanza); los estados (v_resultados, v_balance_general y
  //     la balanza) en una página lista para imprimir a PDF (el camino de
  //     imprimir de la app); y un README con la huella del mayor (de
  //     cierres) y el sha256 de cada archivo (Web Crypto), con la receta
  //     para comprobarla sin la app. ANTES de subir nada la pantalla
  //     recalcula la huella del mayor con las líneas que bajó: si no da la
  //     que la base guardó al cerrar, no exporta (un CSV que no da la huella
  //     no prueba nada). Todo va al bucket privado «cierres», carpeta
  //     <periodo>/<fecha-hora de Miami>/ (por la API nada se pisa ni se
  //     borra: cada export, su carpeta), y se registra con fn_cierre_export.
  //     «Descargar» firma las rutas (una hora, como las fotos). El correo
  //     con adjuntos llega después (la función «correo» no vive en este
  //     repo): la pantalla lo dice.
  //   · LA RONDA de cada mañana (fn_ronda por pg_cron, sin IA): su última
  //     corrida (v_ronda_ultima) aquí entera; sus rojos, en «Qué atender»
  //     del Resumen con un botón a esta página.
  //   · ACTIVOS (v_activos_fijos; fn_activo_alta, fn_activo_baja,
  //     fn_depreciacion_plan y fn_depreciacion_mes cuando falta el asiento
  //     del mes), RESERVA (v_reserva_impuestos y reserva_estimados;
  //     fn_cierre_config con el %, fn_reserva_estimado_marcar/anular), DR-15
  //     (v_dr15_mes: lo que aún no se sabe, dicho), HISTORIAL (v_cierres) y
  //     AJUSTES (cierre_config; fn_cierre_config).
  // Sin c9 pegado (las vistas no existen) la página lo dice en llano; el
  // Resumen sigue igual. Ninguna cifra se calcula aquí: vienen listas.
  // ============================================================
  // (los chips cortos: en el teléfono deslizan, y «Reserva de impuestos» tapaba los de después)
  const SUBS_CIE = { cierre: "El cierre", activos: "Activos fijos", reserva: "Reserva", dr15: "DR-15", historial: "Historial", ajustes: "Ajustes" };
  const enc = encodeURIComponent;
  const cieCuerpo = () => $("ct-cie-cuerpo");
  // sigue viva esta pintada (nadie pidió otra cosa después y la página sigue en pantalla)
  const vivaCie = mia => mia === S.cie.serie && S.pagina === "cierre" && !!cieCuerpo();
  const cargandoCie = txt => { const c = cieCuerpo(); if (c) c.innerHTML = `<div class="ct-card ct-cargando">${esc(txt || "Cargando…")}</div>`; };
  // la línea de la cabecera: se escribe cuando el apartado ya leyó lo suyo
  const subCie = html => { const s = main() && main().querySelector(".ct-pag-sub"); if (s) s.innerHTML = html; };
  // un período en palabras desde su código (la ronda solo trae el código)
  function nombrePer(p) {
    const s = String(p || "");
    if (/APERTURA$/i.test(s)) return "la apertura";
    const m = /^(\d{4})-(\d{2})$/.exec(s);
    if (m) return `${MES_LARGO[Number(m[2])] || m[2]} de ${m[1]}`;
    return /^\d{4}$/.test(s) ? `el año ${s}` : s;
  }
  // el nombre de un control como lo escribe la base («ia: la llave…»), con su mayúscula (y «IA», no «Ia»)
  const controlTxt = c => cap(String(c || "").replace(/^ia:/i, "IA:"));
  const rondaDe = f => f && String(f).slice(0, 10) === hoyMiami() ? "La ronda de hoy" : `La ronda del ${fecha(f)}`;
  // como la base: un control está en rojo si su ok es «distinto de true» (un nulo no es verde)
  const rojo = x => x.ok !== true;
  // los rojos de una corrida de la ronda: lo que detiene primero, después por su orden
  const rojosDeRonda = filas => (Array.isArray(filas) ? filas : []).filter(rojo)
    .sort((a, b) => (a.nivel === "detiene" ? 0 : 1) - (b.nivel === "detiene" ? 0 : 1) || Number(a.orden) - Number(b.orden));
  // «CERRAR OCTUBRE 2026» → «Cerrar octubre 2026» (el texto del botón es la misma frase que se pide escribir)
  const botonCerrarTxt = r => cap(String(r.confirmacion || "").toLowerCase());
  const montoTxt = s => String(s == null ? "" : s).replace(/[$,%\s]/g, "");
  const kb = n => { const b = Number(n) || 0; return b < 1024 ? `${b.toLocaleString("en-US")} bytes` : `${(b / 1024).toLocaleString("en-US", { maximumFractionDigits: 1 })} KB`; };
  // la carpeta de cada export: la fecha y la hora de Miami (2026-11-07_143205)
  function selloMiami() {
    const f = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false }).formatToParts(new Date());
    const g = k => (f.find(x => x.type === k) || {}).value || "00";
    return `${g("year")}-${g("month")}-${g("day")}_${g("hour") === "24" ? "00" : g("hour")}${g("minute")}${g("second")}`;
  }

  // ---------- La base, Storage y la huella ----------
  // Sin c9 pegado: PostgREST no encuentra la vista o la función
  const faltaC9 = err => ["PGRST205", "PGRST202", "42P01", "42883"].includes(String((err && err.codigo) || ""));
  const INGLES = /\b(permission denied|violates|invalid input|does not exist|null value|duplicate key|constraint)\b/i;
  // Las funciones de c9 por PostgREST (POST /rest/v1/rpc/…) con la sesión del dueño: lo mismo que DB._rpc, pero el error
  // trae también la pista de la base (hint), que DB._rpc no guarda: fn_cierre_cerrar dice ahí la frase exacta (22023) y cómo
  // pedir la lista entera (MX010). Sin la configuración de Supabase o sin sesión, el camino de siempre (sin pista).
  const SBC = () => window.MAXPOWER_SUPABASE || {};
  const tokenCie = () => (typeof DB.tokenSesion === "function" ? DB.tokenSesion() : null);
  async function rpcCie(fn, args, reintento = true) {
    const sb = SBC(), tok = tokenCie();
    if (!sb.url || !tok) return DB._rpc(fn, args);
    const r = await fetch(`${sb.url}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: { apikey: sb.key, Authorization: `Bearer ${tok}`, "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(args || {})
    });
    if (r.status === 401 && reintento && typeof DB.refrescar === "function") { await DB.refrescar(); return rpcCie(fn, args, false); }
    const txt = await r.text();
    let j = null; try { j = txt ? JSON.parse(txt) : null; } catch { j = null; }
    if (!r.ok) {
      const d = j && typeof j === "object" ? j : {};
      const codigo = String(d.code || ""), m = String(d.message || "");
      const e = new Error(faltaC9({ codigo }) ? "A la base le falta el cierre: pega docs/conta/c9-cierre.sql en Supabase (SQL Editor → pegar → Run) y vuelve a intentarlo."
        : codigo === "MFA" ? "Falta el código del teléfono: sal y vuelve a entrar con él."
        : codigo === "42501" && (!m || INGLES.test(m)) ? "Esto lo hace solo Edgar (el dueño): la base no se lo deja a esta sesión."
        : m || `La base contestó ${r.status} a ${fn}.`);
      Object.assign(e, { codigo: codigo || null, pista: d.hint || null, detalles: d.details || null, status: r.status, crudo: m || null });
      if (codigo === "MFA") { try { window.dispatchEvent(new CustomEvent("mxp:mfa")); } catch { /* nada */ } }
      throw e;
    }
    return j;
  }
  // Storage, el bucket privado «cierres» (c9 lo crea con sus policies: solo el dueño sube y lee; nadie borra ni pisa por la
  // API). js/db.js solo sabe del bucket «fotos»: aquí, el mismo fetch con la misma sesión
  const rutaUrl = ruta => String(ruta).split("/").map(enc).join("/");
  async function subirCierre(ruta, bytes, tipo, reintento = true) {
    const sb = SBC(), tok = tokenCie();
    if (!sb.url || !tok) throw new Error("Sin sesión: vuelve a entrar a la app.");
    const r = await fetch(`${sb.url}/storage/v1/object/cierres/${rutaUrl(ruta)}`, {
      method: "POST",
      headers: { apikey: sb.key, Authorization: `Bearer ${tok}`, "Content-Type": tipo, "x-upsert": "false" },
      body: bytes
    });
    if (r.status === 401 && reintento && typeof DB.refrescar === "function") { await DB.refrescar(); return subirCierre(ruta, bytes, tipo, false); }
    if (!r.ok) {
      const d = await r.json().catch(() => ({}));
      const m = String(d.message || d.error || "");
      throw new Error(r.status === 409 || /exist|duplicate/i.test(m) ? `«${ruta}» ya estaba en el bucket «cierres» (ahí nada se pisa): vuelve a exportar; cada export usa su carpeta.`
        : /bucket not found/i.test(m) ? "No existe el bucket «cierres» en Storage: vuelve a pegar docs/conta/c9-cierre.sql (lo crea) o créalo privado en Storage."
        : r.status === 403 || /row-level|policy|unauthorized/i.test(m) ? "Storage no dejó subir al bucket «cierres»: sus policies (solo el dueño sube) no están, o esta sesión no es la del dueño. Vuelve a pegar c9-cierre.sql."
        : `No se pudo subir ${ruta} al bucket «cierres» (${r.status}${m ? `: ${m}` : ""}).`);
    }
  }
  // Las rutas firmadas para bajar (una hora, como las fotos): { ruta → URL }
  async function firmarCierre(rutas, reintento = true) {
    const sb = SBC(), tok = tokenCie();
    if (!sb.url || !tok) throw new Error("Sin sesión: vuelve a entrar a la app.");
    const r = await fetch(`${sb.url}/storage/v1/object/sign/cierres`, {
      method: "POST",
      headers: { apikey: sb.key, Authorization: `Bearer ${tok}`, "Content-Type": "application/json" },
      body: JSON.stringify({ expiresIn: 3600, paths: rutas })
    });
    if (r.status === 401 && reintento && typeof DB.refrescar === "function") { await DB.refrescar(); return firmarCierre(rutas, false); }
    if (!r.ok) throw new Error(`Storage no firmó los archivos del cierre (${r.status}): vuelve a intentarlo en un rato.`);
    const lista = await r.json().catch(() => []);
    const mapa = {};
    for (const it of Array.isArray(lista) ? lista : []) { const f = it.signedURL || it.signedUrl; if (it.path && f && !it.error) mapa[it.path] = `${sb.url}/storage/v1${f}`; }
    return mapa;
  }
  // La huella: sha256 en hexadecimal minúsculo (Web Crypto; pide https, que la app ya tiene)
  async function sha256Hex(datos) {
    if (!(window.crypto && crypto.subtle && typeof crypto.subtle.digest === "function")) throw new Error("Este navegador no deja calcular la huella (sha256): abre la app por https y vuelve a intentarlo. No se exportó nada.");
    const bytes = typeof datos === "string" ? new TextEncoder().encode(datos) : datos;
    const h = await crypto.subtle.digest("SHA-256", bytes);
    return [...new Uint8Array(h)].map(b => b.toString(16).padStart(2, "0")).join("");
  }

  // ---------- Los archivos del export ----------
  const dos = v => { const n = num(v); return n == null || Number.isNaN(n) ? "" : n.toFixed(2); };
  const csvCampo = v => { const s = v == null ? "" : String(v); return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
  // CSV para Excel: UTF-8 con su marca (los acentos salen bien) y fin de línea de Windows
  const csv = filas => "﻿" + filas.map(f => f.map(csvCampo).join(",")).join("\r\n") + "\r\n";
  // el orden del libro (fecha, posición en la cadena, línea): el de fn_cierre_hash_mayor
  const ordenLibro = lineas => [...lineas].sort((x, y) => String(x.fecha).localeCompare(String(y.fecha)) || nOrd(x.cadena_pos) - nOrd(y.cadena_pos) || nOrd(x.orden) - nOrd(y.orden));
  // El texto de la huella del mayor, el mismo que arma la base al cerrar (fn_cierre_hash_mayor): por línea
  // «numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo» (el monto con sus dos decimales y su signo, como numeric(14,2)
  // en texto; vacío lo que es nulo), en el orden del libro, unidas por salto de línea (sin uno al final)
  const textoHashMayor = lineas => ordenLibro(lineas).map(l => [l.numero, String(l.fecha).slice(0, 10), l.orden, l.cuenta, dos(l.monto), l.proyecto_id || "", l.cost_code || "", l.memo || ""].join("|")).join("\n");
  const CAB_MAYOR = ["cuenta", "cuenta_nombre", "fecha", "numero", "orden", "cadena_pos", "descripcion", "memo", "debe", "haber", "monto", "saldo_corrido",
    "proyecto_id", "cost_code", "procedencia", "sello_ia", "origen_tabla", "origen_id", "documento_ruta", "tipo", "afecta_periodo", "reversado"];
  // El mayor: por cuenta y, dentro, en el orden del libro, con el saldo corrido de la cuenta del lado en que crece (v_mayor)
  function csvMayor(lineas) {
    const filas = [...lineas].sort((x, y) => String(x.cuenta).localeCompare(String(y.cuenta)) || String(x.fecha).localeCompare(String(y.fecha)) || nOrd(x.cadena_pos) - nOrd(y.cadena_pos) || nOrd(x.orden) - nOrd(y.orden));
    return csv([CAB_MAYOR].concat(filas.map(l => [l.cuenta, l.cuenta_nombre, String(l.fecha).slice(0, 10), l.numero, l.orden, l.cadena_pos, l.descripcion, l.memo,
      dos(l.debe), dos(l.haber), dos(l.monto), dos(l.saldo_en_su_lado), l.proyecto_id, l.cost_code, CAMINO[l.camino] || l.camino,
      l.camino === "ia" ? "IA (aprobada por Edgar)" : "", l.origen_tabla, l.origen_id, l.documento_ruta, TIPO_AS[l.tipo] || l.tipo, l.afecta_periodo, l.reversado ? "sí" : ""])));
  }
  // la balanza en centavos (sin errores de coma flotante): lo que se suma para el total y para ver que cuadra
  function sumasBalanza(bza) {
    const c = k => bza.reduce((s, b) => s + Math.round((num(b[k]) || 0) * 100), 0);
    return { inicial: c("inicial"), debe: c("debe"), haber: c("haber"), final: c("final") };
  }
  function csvBalanza(bza, nombres) {
    const t = sumasBalanza(bza), c = v => (v / 100).toFixed(2);
    return csv([["cuenta", "cuenta_nombre", "saldo_inicial", "debe", "haber", "saldo_final"]]
      .concat(bza.map(b => [b.cuenta, nombres[b.cuenta] || "", dos(b.inicial), dos(b.debe), dos(b.haber), dos(b.final)]))
      .concat([["TOTAL", "debe = haber; los saldos suman 0", c(t.inicial), c(t.debe), c(t.haber), c(t.final)]]));
  }
  // Los estados del período en una página para imprimir («Guardar como PDF»): resultados, balance y balanza, con la huella.
  // Un archivo suelto (sin la app): los colores son los de «Cobre y luz» escritos, no sus variables.
  function estadosDoc(d) {
    const c = d.cierre || {};
    const fila = (f, cifras) => `<tr class="n-${esc(f.nivel || "cuenta")}"><td>${esc(f.etiqueta_es || f.cuenta || "")}</td>${cifras.map(v => `<td class="r">${v}</td>`).join("")}</tr>`;
    const res = d.res.length ? `<table><thead><tr><th>Concepto</th><th class="r">Período</th><th class="r">Acumulado del año</th></tr></thead><tbody>${d.res.map(f => fila(f, [fmtNeg(f.mes), fmtNeg(f.acumulado)])).join("")}</tbody></table>`
      : `<p>${d.periodo.endsWith("APERTURA") ? "La apertura no tiene estado de resultados: es la foto del 30-sep." : "Sin asientos de resultados en el período."}</p>`;
    const bal = d.bal.length ? `<table><tbody>${d.bal.map(f => fila(f, [f.nivel === "total" && f.linea === "cuadra" ? (f.cuadra === true ? "cuadra" : fmtNeg(f.cifra)) : fmtNeg(f.cifra)])).join("")}</tbody></table>` : "<p>Sin balance general para el período.</p>";
    const bza = `<table><thead><tr><th>Cuenta</th><th class="r">Saldo inicial</th><th class="r">Debe</th><th class="r">Haber</th><th class="r">Saldo final</th></tr></thead><tbody>${d.bza.map(b => `<tr><td>${esc(b.cuenta)} ${esc(d.nombres[b.cuenta] || "")}</td><td class="r">${fmtNeg(b.inicial)}</td><td class="r">${fmtNeg(b.debe)}</td><td class="r">${fmtNeg(b.haber)}</td><td class="r">${fmtNeg(b.final)}</td></tr>`).join("")}</tbody></table>`;
    return `<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Estados ${esc(d.periodo)} · Max Power</title>
<style>
body{font-family:system-ui,-apple-system,"Segoe UI",sans-serif;color:#0B2036;margin:24px;font-size:13px;line-height:1.45}
h1{font-size:20px;margin:0 0 4px}h2{font-size:15px;margin:22px 0 6px;color:#8F4F1F}p{margin:2px 0;color:#4D6A83}
table{border-collapse:collapse;width:100%;max-width:780px}td,th{padding:4px 6px;border-bottom:1px solid #cfe0ee;text-align:left;vertical-align:top}
th{font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:#8F4F1F}.r{text-align:right;font-family:ui-monospace,Menlo,monospace;white-space:nowrap}
tr.n-seccion td,tr.n-total td,tr.n-linea td{font-weight:700}tr.n-cuenta td:first-child{padding-left:18px}tr.n-componente td:first-child{padding-left:30px;color:#4D6A83}
.huella{font-family:ui-monospace,Menlo,monospace;word-break:break-all;color:#0B2036}@media print{body{margin:0}h2{break-after:avoid}tr{break-inside:avoid}}
</style></head><body>
<h1>Max Power · estados de ${esc(d.nombre)}</h1>
<p>Cerrado el ${esc(fechaHora(c.cerrado_el))} (hora de Miami)${c.cerrado_por_nombre ? ` por ${esc(c.cerrado_por_nombre)}` : ""} · ${esc(plural(c.asientos || 0, "asiento", "asientos"))} · ${esc(plural(c.lineas || 0, "línea", "líneas"))}</p>
<p>Huella del mayor (sha256): <span class="huella">${esc(c.hash_mayor || "")}</span></p>
<h2>Estado de resultados</h2>${res}
<h2>Balance general</h2>${bal}
<h2>Balanza de comprobación</h2>${bza}
<p style="margin-top:18px">Generado el ${esc(d.generado)} desde la app (Contabilidad → Cierre del mes). Las cifras vienen de la base: v_resultados, v_balance_general y la balanza que se guardó al cerrar (fn_cierre_balanza).</p>
</body></html>
`;
  }
  // El README del export: la huella del mayor, el sha256 de cada archivo y cómo comprobarla sin la app
  function leemeTxt(d, carpeta, subidos) {
    const c = d.cierre, p = d.periodo, L = [];
    L.push(`MAX POWER · CIERRE DE ${d.nombre.toUpperCase()} (${p})`, "");
    L.push(`Cerrado el ${fechaHora(c.cerrado_el)} (hora de Miami)${c.cerrado_por_nombre ? ` por ${c.cerrado_por_nombre}` : ""}, desde la app (Contabilidad → Cierre del mes).`);
    L.push(`Exportado el ${d.generado} a la carpeta cierres/${carpeta} del almacén privado de la app (Supabase Storage).`);
    L.push(`${plural(c.asientos || 0, "asiento", "asientos")} y ${plural(c.lineas || 0, "línea", "líneas")} en el período.`, "");
    L.push("HUELLA DEL MAYOR (sha256, la que la base guardó al cerrar):", c.hash_mayor, "");
    if (c.cadena_al_cerrar) L.push("Huella de la cadena del libro al cerrar (c2):", c.cadena_al_cerrar, "");
    L.push("ARCHIVOS (el sha256 de cada uno, tal como se subió):");
    for (const s of subidos) L.push(`${s.sha256}  ${s.ruta.split("/").pop()}  (${s.bytes} bytes)`);
    L.push("(Este README no se lista a sí mismo: su huella queda registrada en la base, en cierres.export_archivos.)", "");
    L.push("QUÉ ES CADA ARCHIVO:");
    L.push(`- mayor-${p}.csv: cada línea del libro del período, por cuenta, con el saldo corrido de la cuenta (saldo_corrido, del lado en que crece), su procedencia (puente, a mano, IA aprobada, reverso), el sello de la IA y el papel que la respalda (origen_tabla, origen_id, documento_ruta).`);
    L.push(`- balanza-${p}.csv: la balanza que la base guardó al cerrar: saldo inicial, debe, haber y saldo final por cuenta. La ronda de cada mañana la vuelve a calcular y la compara.`);
    L.push(`- estados-${p}.html: el estado de resultados, el balance general y la balanza, listos para imprimir (ábrelo, «Imprimir» y «Guardar como PDF»).`, "");
    L.push("CÓMO SE COMPRUEBA LA HUELLA DEL MAYOR SIN LA APP:");
    L.push("1. Abre el CSV del mayor y ordena sus líneas por fecha, cadena_pos y orden (de menor a mayor).");
    L.push("2. De cada línea escribe numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo (el monto con dos decimales y su signo; un campo vacío queda vacío).");
    L.push("3. Une las líneas con un salto de línea (sin salto al final) y saca el sha256 del texto en UTF-8 (en la Mac: shasum -a 256). Tiene que dar la huella de arriba.");
    L.push("Si da otra, ese CSV no es el del cierre.", "");
    L.push("Un período cerrado no se reabre: lo que llegue tarde entra al primer día del mes abierto; un error se corrige con un reverso en el mes abierto; un ajuste del CPA va al mes abierto diciendo qué mes corrige (docs/conta/OPERACION.md).");
    L.push("El correo con estos archivos adjuntos llega después: la función «correo» todavía no tiene esa acción.");
    return L.join("\r\n") + "\r\n";
  }
  // Lo que el export y la impresión necesitan del cierre (todo de la base): la fila de v_cierres, la balanza guardada, los
  // estados del período y los nombres de las cuentas; con conMayor, también el mayor del período (v_mayor)
  async function datosCierre(periodo, conMayor) {
    const P = enc(periodo);
    const [cs, bza, res, bal, cu, mayor] = await Promise.all([
      DB._leer(`v_cierres?select=*&periodo=eq.${P}`),
      rpcCie("fn_cierre_balanza", { p_periodo: periodo }),
      DB._leer(`v_resultados?select=nivel,seccion,linea,cuenta,etiqueta_es,mes,acumulado,seccion_orden,linea_orden,orden&periodo=eq.${P}&order=seccion_orden.asc,linea_orden.asc,orden.asc`),
      DB._leer(`v_balance_general?select=nivel,seccion,linea,cuenta,etiqueta_es,cifra,cuadra,seccion_orden,linea_orden,orden&periodo=eq.${P}&order=seccion_orden.asc,linea_orden.asc,orden.asc`),
      DB._leer("cuentas?select=codigo,nombre&order=codigo.asc").catch(e => { if (esFalloDeRed(e)) throw e; return []; }),
      conMayor ? DB._leer(`v_mayor?select=asiento_id,numero,orden,fecha,periodo,tipo,afecta_periodo,camino,descripcion,memo,origen_tabla,origen_id,documento_ruta,cadena_pos,cuenta,cuenta_nombre,monto,debe,haber,saldo_en_su_lado,proyecto_id,cost_code,reversado&periodo=eq.${P}&order=fecha.asc,cadena_pos.asc,orden.asc`) : null
    ]);
    const cierre = Array.isArray(cs) ? cs[0] : null;
    if (!cierre) throw new Error(`${cap(nombrePer(periodo))} no está cerrado desde la app: solo se exporta un período cerrado (ciérralo primero).`);
    if (!Array.isArray(bza)) throw errorControl("La balanza del cierre no llegó", [{ vista: "fn_cierre_balanza", filas: "—", esperadas: "una lista", detalle: `fn_cierre_balanza('${periodo}') no devolvió la lista de cuentas` }]);
    const nombres = {};
    for (const c of Array.isArray(cu) ? cu : []) nombres[c.codigo] = c.nombre;
    for (const l of Array.isArray(mayor) ? mayor : []) if (l.cuenta_nombre && !nombres[l.cuenta]) nombres[l.cuenta] = l.cuenta_nombre;
    // el nombre como lo dice la base («la apertura (30-sep-2026)», «octubre de 2026»)
    const fe = (S.cie.estado || []).find(r => r.periodo === periodo);
    return { periodo, nombre: (fe && fe.nombre) || nombrePer(periodo), cierre, bza, res: res || [], bal: bal || [], nombres, mayor, generado: fechaHora(new Date().toISOString()) };
  }
  const pasosHTML = pasos => `<ul class="ct-cie-pasos">${pasos.map((p, i) => `<li class="${p.clase || (i === pasos.length - 1 ? "ct-espera" : "")}">${esc(p.txt)}</li>`).join("")}</ul>`;

  // EL EXPORT (repetible): baja lo del cierre, comprueba la huella del mayor y que la balanza cuadra, arma los archivos,
  // los sube a <periodo>/<fecha-hora>/ con su sha256 y los registra (fn_cierre_export). El avance se ve en #ct-cie-export.
  async function exportar(periodo) {
    if (S.ocupado) return;
    if (!navigator.onLine) { S.cie.exportErr[periodo] = "Sin señal: no se exportó nada. Con señal, «Volver a exportar»."; if (S.pagina === "cierre") await pintarCierre(); return; }
    if (!mfaActivo()) { S.cie.exportErr[periodo] = "Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: el export lo pide."; if (S.pagina === "cierre") await pintarCierre(); return; }
    S.ocupado = true; S.cie.exportando = periodo; delete S.cie.exportErr[periodo];
    const pasos = [];
    const pinta = () => { const c = $("ct-cie-export"); if (c && S.cie.periodo === periodo) c.innerHTML = pasosHTML(pasos); };
    const paso = (txt, clase) => { pasos.push({ txt, clase }); pinta(); };
    const listo = (txt) => { pasos.pop(); paso(txt, "ok"); };
    let r = null, carpeta = "";
    try {
      paso("Bajando el mayor, la balanza y los estados del cierre…");
      const d = await datosCierre(periodo, true);
      const huella = await sha256Hex(textoHashMayor(d.mayor));
      if (huella !== d.cierre.hash_mayor) {
        throw new Error(`El mayor que bajó (${plural(d.mayor.length, "línea", "líneas")}; al cerrar eran ${d.cierre.lineas}) no da la huella que la base guardó al cerrar (${String(d.cierre.hash_mayor).slice(0, 12)}…; aquí sale ${huella.slice(0, 12)}…). No se exportó nada: un CSV que no da la huella no prueba nada. Vuelve a intentarlo; si sigue, avisa (algo cambió en el libro o en la vista v_mayor).`);
      }
      listo(`La huella del mayor coincide con la del cierre (${plural(d.mayor.length, "línea", "líneas")})`);
      const q = sumasBalanza(d.bza);
      if (q.debe !== q.haber || q.final !== 0) throw new Error(`La balanza del cierre no cuadra (debe ${fmt(q.debe / 100)}, haber ${fmt(q.haber / 100)}, saldos ${fmt(q.final / 100)}): no se exportó nada. Avisa: esto no debería pasar nunca.`);
      carpeta = `${periodo}/${selloMiami()}/`;
      const archivos = [
        { nombre: `mayor-${periodo}.csv`, tipo: "text/csv", texto: csvMayor(d.mayor) },
        { nombre: `balanza-${periodo}.csv`, tipo: "text/csv", texto: csvBalanza(d.bza, d.nombres) },
        { nombre: `estados-${periodo}.html`, tipo: "text/html", texto: estadosDoc(d) }
      ];
      const subidos = [];
      const subir = async a => {
        const bytes = new TextEncoder().encode(a.texto);
        const sha = await sha256Hex(bytes);
        paso(`Subiendo ${a.nombre}…`);
        await subirCierre(carpeta + a.nombre, bytes, `${a.tipo}; charset=utf-8`);
        subidos.push({ ruta: carpeta + a.nombre, sha256: sha, bytes: bytes.length, tipo: a.tipo });
        listo(`${a.nombre} · ${kb(bytes.length)} · sha256 ${sha.slice(0, 12)}…`);
      };
      for (const a of archivos) await subir(a);
      // el README va al final: lleva el sha256 de los demás
      await subir({ nombre: `README-${periodo}.txt`, tipo: "text/plain", texto: leemeTxt(d, carpeta, subidos) });
      paso("Registrando el export en la base…");
      r = await rpcCie("fn_cierre_export", { p_periodo: periodo, p_archivos: subidos });
      listo("Registrado en la base");
    } catch (err) {
      S.cie.exportErr[periodo] = esFalloDeRed(err) || !navigator.onLine
        ? "Se cortó la señal a medias: lo que alcanzó a subir queda en el bucket (no estorba), pero el export no se registró. Con señal, «Volver a exportar»."
        : err.control ? `${err.message}: ${err.control.map(f => f.detalle).filter(Boolean).join(" · ")}` : err.message;
    } finally { S.ocupado = false; S.cie.exportando = null; }
    if (r) S.hooks.avisar(`Exportado: ${plural(r.archivos, "archivo", "archivos")} en el bucket «cierres» (${carpeta})${Number(r.veces) > 1 ? ` · ${r.veces}.ª vez` : ""}`);
    else S.hooks.avisar("El export no terminó: el detalle está en Cierre del mes", true);
    if (S.pagina === "cierre") await pintarCierre();
  }
  // «Volver a exportar» desde cualquier apartado: el avance se ve en «El cierre», con el período elegido
  async function exportarDesde(periodo) {
    if (S.ocupado) return;
    S.cie.sub = "cierre"; S.cie.periodo = periodo; S.cie.exportando = periodo;
    await pintarCierre();
    S.cie.exportando = null;
    await exportar(periodo);
  }
  // «Descargar el cierre»: los archivos del último export, firmados (valen una hora)
  async function descargar(periodo) {
    const caja = main() && main().querySelector(`[data-cie-descarga="${periodo}"]`);
    if (!caja) return;
    if (!navigator.onLine) { caja.innerHTML = `<p class="ct-aviso bad">Sin señal: no se firmó nada.</p>`; return; }
    caja.innerHTML = `<p class="ct-aviso ct-espera" role="status">Firmando los archivos (valen una hora)…</p>`;
    try {
      const cs = await DB._leer(`v_cierres?select=periodo,export_archivos&periodo=eq.${enc(periodo)}`);
      const arch = cs[0] && Array.isArray(cs[0].export_archivos) ? cs[0].export_archivos : [];
      if (!arch.length) throw new Error("Este cierre no tiene ningún export registrado: «Volver a exportar».");
      const mapa = await firmarCierre(arch.map(a => a.ruta));
      const faltan = arch.filter(a => !mapa[a.ruta]);
      caja.innerHTML = `<ul class="ct-cie-archivos">${arch.map(a => {
        const n = String(a.ruta).split("/").pop(), u = mapa[a.ruta];
        return `<li>${u ? `<a class="ct-cie-archivo" href="${esc(`${u}${u.includes("?") ? "&" : "?"}download=${enc(n)}`)}" target="_blank" rel="noopener" download="${esc(n)}">${esc(n)}</a>` : `<span class="ct-cie-archivo">${esc(n)}</span>`}<small>${kb(a.bytes)} · sha256 <span class="ct-num">${esc(String(a.sha256 || "").slice(0, 16))}…</span></small></li>`;
      }).join("")}</ul>
        ${faltan.length ? `<p class="ct-aviso warn">Storage no firmó ${plural(faltan.length, "archivo", "archivos")} (${esc(faltan.map(a => String(a.ruta).split("/").pop()).join(", "))}): ¿se borró a mano del bucket? El registro sigue en la base; «Volver a exportar» desde el historial lo rehace.</p>` : ""}
        <p class="ct-nota">Los enlaces valen una hora. La huella completa de cada archivo está en su README.</p>`;
    } catch (err) { caja.innerHTML = `<p class="ct-aviso bad">${esc(esFalloDeRed(err) ? "Sin señal: no se firmó nada." : err.message)}</p>`; }
  }
  // Los estados por el camino de imprimir de la app: una ventana con la página y la ventana de imprimir («Guardar como PDF»).
  // La ventana se abre en el mismo toque (si no, el navegador la bloquea) y se llena cuando llegan las cifras
  async function imprimirEstados(periodo) {
    const w = window.open("", "_blank");
    if (!w) { S.hooks.avisar("El navegador bloqueó la ventana. Permite ventanas emergentes para la app y vuelve a tocar.", true); return; }
    try { w.document.write(`<p style="font-family:system-ui,sans-serif">Preparando los estados de ${esc(nombrePer(periodo))}…</p>`); } catch { /* nada */ }
    try {
      const d = await datosCierre(periodo, false);
      w.document.open(); w.document.write(estadosDoc(d)); w.document.close();
      const imprimir = () => { try { w.focus(); w.print(); } catch { /* nada */ } };
      if (w.document.readyState === "complete") setTimeout(imprimir, 400);
      else w.addEventListener("load", () => setTimeout(imprimir, 400));
      S.hooks.avisar("Elige «Guardar como PDF» y guárdalo con el cierre");
    } catch (err) {
      try { w.close(); } catch { /* nada */ }
      S.hooks.avisar(esFalloDeRed(err) ? "Sin señal: no se armaron los estados." : err.message, true);
    }
  }

  // ---------- El marco de la página: la cabecera, los chips y el cuerpo ----------
  async function pintarCierre() {
    const mia = ++S.cie.serie;
    if (!navigator.onLine) return sinSenal(pintarCierre);
    if (!SUBS_CIE[S.cie.sub]) S.cie.sub = "cierre";
    S.hooks.titulo(KICKER, TITULOS.cierre);
    main().innerHTML = cabPagina(TITULOS.cierre, "Leyendo con la base…") +
      `<section class="ct-card ct-cie-barra"><div class="ct-chips ct-cie-subs" aria-label="Qué parte del cierre">${Object.keys(SUBS_CIE).map(k =>
        `<button type="button" class="ct-chip" data-cie-sub="${k}" aria-pressed="${k === S.cie.sub ? "true" : "false"}">${esc(SUBS_CIE[k])}</button>`).join("")}</div></section>
      <div id="ct-cie-cuerpo" class="ct-cie-cuerpo"></div>`;
    main().querySelectorAll("[data-cie-sub]").forEach(b => b.addEventListener("click", () => { if (!S.ocupado) ir("cierre", { sub: b.dataset.cieSub }); }));
    const act = main().querySelector('[data-cie-sub][aria-pressed="true"]');
    if (act && typeof act.scrollIntoView === "function") act.scrollIntoView({ inline: "nearest", block: "nearest" });
    marcarVolver();
    const pinta = { cierre: pintarCieCierre, activos: pintarCieActivos, reserva: pintarCieReserva, dr15: pintarCieDr15, historial: pintarCieHistorial, ajustes: pintarCieAjustes }[S.cie.sub];
    return pinta(mia);
  }
  function pintarErrorCie(err, reintentar) {
    const c = cieCuerpo(); if (!c) return;
    if (faltaC9(err) && !esFalloDeRed(err)) {
      c.innerHTML = `<section class="ct-card ct-rojo" role="alert"><h2>Falta el cierre en la base</h2>
        <p>Esta página lee lo que deja <span class="ct-num">docs/conta/c9-cierre.sql</span>, y la base todavía no lo tiene. Pégalo entero en Supabase (SQL Editor → pegar → Run), después de c1 a c8: al final sale una tabla que dice qué detiene hoy el cierre. Después vuelve aquí.</p>
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-reintentar">Reintentar</button></div></section>`;
      $("ct-reintentar").addEventListener("click", reintentar);
      return;
    }
    pintarError(err, reintentar, err.codigo === "42501" ? "Contabilidad es solo del dueño" : undefined, c);
  }
  async function leerCieEstado() {
    const filas = await DB._leer("v_cierre_estado?select=*&order=desde.asc,tipo.asc");
    if (!Array.isArray(filas) || !filas.length) throw errorControl("La base no devolvió ningún período del cierre", [{ vista: "v_cierre_estado", filas: 0, esperadas: "1 o más", detalle: "La apertura y cada mes salen aquí. Vacía: la sesión no es la del dueño (el equipo ve las vistas vacías) o el libro no tiene períodos." }]);
    S.cie.estado = filas;
    return filas;
  }
  // a qué página lleva un control (ir_a de la base). «cierre» se queda aquí: los activos, la reserva, el historial; el 10
  // (los anteriores sin cerrar) lleva al período que toca
  const PAG_IR = ["bandeja", "conciliar", "movimientos", "estados", "cobros", "conexiones"];
  function destinoCie(x, sig) {
    if (PAG_IR.includes(x.ir_a)) return { txt: PESTANAS[x.ir_a], attr: `data-ir="${x.ir_a}"` };
    if (x.ir_a !== "cierre") return null;
    const o = Number(x.orden);
    if (o === 90 || o === 92 || o === 210) return { txt: "Activos fijos", attr: `data-cie-ir="activos"` };
    if (o === 220 || o === 222) return { txt: "Reserva", attr: `data-cie-ir="reserva"` };
    if (o >= 200 && o < 210) return { txt: "Historial", attr: `data-cie-ir="historial"` };
    if (o === 10 && sig && sig.periodo !== S.cie.periodo) return { txt: cap(sig.nombre), attr: `data-cie-per="${esc(sig.periodo)}"` };
    return null;
  }
  // Un control de la revisión (o de la ronda, con su período y su nivel): qué, el detalle en llano, qué hacer y su botón
  function itemCieHTML(x, sig, opciones = {}) {
    const d = opciones.solo ? null : destinoCie(x, sig);
    const clase = !rojo(x) ? "ok" : x.nivel === "detiene" ? "detiene" : "aviso";
    const etiquetas = opciones.ronda ? `${pill(x.nivel === "detiene" ? "detiene" : "aviso", x.nivel === "detiene" ? "bad" : "warn")}${x.periodo ? ` <span class="ct-cie-item-p">${esc(nombrePer(x.periodo))}</span>` : ""}` : "";
    return `<li class="ct-cie-item ${clase}" data-orden="${esc(x.orden)}">
        <div class="ct-cie-item-txt"><p class="ct-cie-item-t">${etiquetas ? `${etiquetas} ` : ""}${esc(controlTxt(x.control))}</p>
          ${x.detalle ? `<p class="ct-cie-item-d">${esc(x.detalle)}</p>` : ""}
          ${x.que_hacer ? `<p class="ct-cie-item-h">${rojo(x) ? "<b>Qué hacer:</b> " : ""}${esc(x.que_hacer)}</p>` : ""}</div>
        ${d && rojo(x) ? `<button type="button" class="accion secundaria chica" ${d.attr}>${esc(d.txt)}</button>` : ""}
      </li>`;
  }
  // los botones de dentro del cuerpo: otra página (ir_a), otro apartado, otro período, exportar, descargar, imprimir
  function wireCie(c) {
    c.querySelectorAll("[data-ir]").forEach(b => b.addEventListener("click", () => ir(b.dataset.ir)));
    c.querySelectorAll("[data-cie-ir]").forEach(b => b.addEventListener("click", () => ir("cierre", { sub: b.dataset.cieIr })));
    c.querySelectorAll("[data-cie-per]").forEach(b => b.addEventListener("click", () => ir("cierre", { sub: "cierre", periodo: b.dataset.ciePer })));
    c.querySelectorAll("[data-cie-exportar]").forEach(b => b.addEventListener("click", () => exportarDesde(b.dataset.cieExportar)));
    c.querySelectorAll("[data-cie-descargar]").forEach(b => b.addEventListener("click", () => descargar(b.dataset.cieDescargar)));
    c.querySelectorAll("[data-cie-imprimir]").forEach(b => b.addEventListener("click", () => imprimirEstados(b.dataset.cieImprimir)));
  }
  // Una acción de la página (RPC con la sesión del dueño): los controles de la tarjeta se apagan, el error va a su forma
  // y, si salió, el aviso y se vuelve a pintar el apartado
  async function accionCie(card, fn, args, exito) {
    if (S.ocupado) return;
    if (!navigator.onLine) { mostrarErrorForma(card, "Sin señal: no se hizo nada."); return; }
    S.ocupado = true;
    const apagados = [...card.querySelectorAll("button, input, select, textarea")].filter(b => !b.disabled);
    apagados.forEach(b => { b.disabled = true; });
    let r;
    try { r = await rpcCie(fn, args); }
    catch (err) {
      apagados.forEach(b => { b.disabled = false; });
      S.ocupado = false;
      mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se guardó. Vuelve a intentarlo con señal." : err.message);
      return;
    }
    S.ocupado = false;
    const aviso = exito(r);
    if (aviso) S.hooks.avisar(...(Array.isArray(aviso) ? aviso : [aviso]));
    if (S.pagina === "cierre") await pintarCierre();
  }

  // ---------- «El cierre»: los períodos, la revisión del que toca, cerrar, el export y la ronda ----------
  async function pintarCieCierre(mia) {
    cargandoCie("Revisando con la base: el banco, las conciliaciones, el libro, los estados…");
    const errPrevio = S.cie.error; S.cie.error = null; // el MX010 se explica una vez, en la pintada que sigue al intento
    let filas, fila, rev = null, cierre = null, ronda = null;
    try {
      filas = await leerCieEstado();
      if (!vivaCie(mia)) return;
      const sig0 = filas.find(r => r.siguiente) || null;
      fila = filas.find(r => r.periodo === S.cie.periodo) || sig0 || filas.filter(r => r.estado === "cerrado").pop() || filas[0];
      S.cie.periodo = fila.periodo;
      if (fila.estado === "cerrado") {
        // un período cerrado por c2 fuera de la app no tiene fila en cierres: se dice
        const cs = await DB._leer(`v_cierres?select=*&periodo=eq.${enc(fila.periodo)}`);
        cierre = Array.isArray(cs) && cs.length ? cs[0] : null;
      } else {
        rev = await rpcCie("fn_cierre_revisar", { p_periodo: fila.periodo });
        if (!vivaCie(mia)) return;
        if (!Array.isArray(rev) || !rev.length) throw errorControl("La revisión no devolvió nada", [{ vista: "fn_cierre_revisar", filas: 0, esperadas: "la lista de controles", detalle: `fn_cierre_revisar('${fila.periodo}') contestó vacío: sin la lista no se sabe qué detiene el cierre.` }]);
        // FALLA RUIDOSA: la foto que la base acaba de guardar (v_cierre_estado) dice lo mismo que la lista que trajo la pantalla
        filas = await leerCieEstado();
        fila = filas.find(r => r.periodo === S.cie.periodo);
        const det = rev.filter(x => x.nivel === "detiene" && rojo(x)).length, avi = rev.filter(x => x.nivel === "aviso" && rojo(x)).length;
        if (!fila || Number(fila.detienen) !== det || Number(fila.avisos) !== avi) {
          throw errorControl("La revisión guardada no coincide con la que acaba de correr", [{ vista: "v_cierre_estado", filas: fila ? `${fila.detienen} / ${fila.avisos}` : "—", esperadas: `${det} / ${avi}`,
            detalle: "Lo que detiene / los avisos. v_cierre_estado enseña la foto que fn_cierre_revisar acaba de guardar: si no dicen lo mismo, no se pinta el botón de cerrar." }]);
        }
      }
      ronda = await DB._leer("v_ronda_ultima?select=*&order=periodo.asc,orden.asc").catch(e => { if (esFalloDeRed(e)) throw e; return null; });
      await leerMfa();
    } catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    const sig = filas.find(r => r.siguiente) || null;
    const hoy = hoyMiami();
    subCie(!sig ? "No queda ningún período abierto por cerrar."
      : !sig.terminado ? `El siguiente es <b>${esc(sig.nombre)}</b>: termina el ${fechaLarga(sig.hasta)}`
      : `Toca cerrar <b>${esc(sig.nombre)}</b> · ${sig.revisado_el == null ? "sin revisar todavía" : Number(sig.detienen) ? `<span class="bad-txt">${plural(sig.detienen, "cosa lo detiene", "cosas lo detienen")}</span>` : "nada lo detiene"}${sig.revisado_el == null ? "" : ` · ${plural(Number(sig.avisos) || 0, "aviso", "avisos")}`}`);
    // los períodos: los cerrados, los ya empezados y el que toca (los meses de más adelante no)
    const vis = filas.filter(r => r.estado === "cerrado" || String(r.desde) <= hoy || r.siguiente || r.periodo === fila.periodo);
    const c = cieCuerpo();
    c.innerHTML = `<section class="ct-card ct-cie-periodos" id="ct-cie-periodos">
        <div class="ct-cab"><h2>Los períodos</h2></div>
        <div class="ct-cie-pers">${vis.map(periodoCieHTML).join("")}</div>
        ${ayudaHTML(`<p class="ct-nota">Se cierra en orden: primero la apertura (el 30-sep, lo que trajo QuickBooks) y después cada mes, cuando ya terminó. Un período cerrado no se reabre nunca: lo que llegue tarde entra al mes abierto (docs/conta/OPERACION.md, la regla A). Toca un período para ver su revisión o su cierre.</p>`, "¿Cómo va esto?")}
      </section>` +
      (fila.estado === "cerrado" ? cerradoHTML(fila, cierre) : revisionHTML(fila, rev, sig, errPrevio) + avisosHTML(rev, sig)) +
      rondaHTML(ronda);
    c.querySelectorAll("[data-cie-periodo]").forEach(b => b.addEventListener("click", () => { if (S.ocupado) return; S.cie.periodo = b.dataset.ciePeriodo; pintarCierre(); }));
    wireCie(c);
    const cerrar = $("ct-cie-cerrar");
    if (cerrar) cerrar.addEventListener("click", () => abrirConfirmacion($("ct-cie-rev"), fila));
    const otra = $("ct-cie-revisar");
    if (otra) otra.addEventListener("click", () => { if (!S.ocupado) pintarCierre(); });
  }
  function periodoCieHTML(r) {
    const sel = r.periodo === S.cie.periodo;
    const estado = r.estado === "cerrado" ? pill("Cerrado", "ok") : r.siguiente && r.terminado ? pill("Toca cerrar", "warn") : !r.terminado ? pill("En curso") : pill("Abierto");
    const det = r.estado === "cerrado"
      ? (r.cerrado_el ? `cerrado el ${esc(fechaHora(r.cerrado_el))}${r.cerrado_por_nombre ? ` por ${esc(r.cerrado_por_nombre)}` : ""} · ${r.exportado ? "exportado" : `<span class="bad-txt">sin exportar</span>`}` : "cerrado fuera de la app")
      : !r.terminado ? `termina el ${fechaLarga(r.hasta)}`
      : r.revisado_el == null ? "sin revisar todavía"
      : `${Number(r.detienen) ? `<span class="bad-txt">${plural(r.detienen, "cosa lo detiene", "cosas lo detienen")}</span>` : "nada lo detiene"} · ${plural(Number(r.avisos) || 0, "aviso", "avisos")}`;
    return `<button type="button" class="ct-cie-per${sel ? " sel" : ""}" data-cie-periodo="${esc(r.periodo)}" aria-pressed="${sel ? "true" : "false"}">
        <span class="ct-cie-per-n">${esc(cap(r.nombre))}</span>${estado}<span class="ct-cie-per-d">${det}</span></button>`;
  }
  // MX010: «No se cierra octubre de 2026: 4 cosa(s) lo detienen. 10) orden: …: … → … 40) banco: …» → la frase y su lista
  function partirMX010(msg) {
    const s = String(msg || "");
    const m = /^([\s\S]*?lo detienen\.)\s*([\s\S]*)$/.exec(s);
    if (!m) return { frase: s, items: [] };
    const items = m[2].split(/\s+(?=\d{1,3}\) )/).map(t => t.trim()).filter(Boolean).map(t => {
      const k = /^(\d{1,3})\) ([\s\S]*)$/.exec(t);
      if (!k) return { orden: null, que: t, hacer: null };
      const [que, ...resto] = k[2].split(" → ");
      return { orden: Number(k[1]), que, hacer: resto.join(" → ") || null };
    });
    return { frase: m[1], items };
  }
  const errorCierreHTML = e => `<div class="ct-aviso bad ct-cie-error" id="ct-cie-error" role="alert">
      <p><b>No se cerró.</b> ${esc(e.frase)}</p>
      ${e.items.length ? `<ul class="ct-cie-error-l">${e.items.map(i => `<li>${i.orden != null ? `<span class="ct-num">${esc(i.orden)})</span> ` : ""}${esc(i.que)}${i.hacer ? `<br><b>Qué hacer:</b> ${esc(i.hacer)}` : ""}</li>`).join("")}</ul>` : ""}
      <p>La base vuelve a revisar en el momento de cerrar, con el libro quieto, y esto entró o cambió después de la revisión que tenías a la vista. No se cerró nada ni cambió nada; la lista de abajo ya está al día.</p>
    </div>`;
  function revisionHTML(fila, rev, sig, err) {
    const det = rev.filter(x => x.nivel === "detiene" && rojo(x));
    const frenan = rev.filter(x => x.nivel === "detiene").length;
    const mfa = mfaActivo();
    const puede = fila.estado === "abierto" && fila.terminado && !det.length && mfa;
    const porque = !fila.terminado ? `${cap(fila.nombre)} termina el ${fechaLarga(fila.hasta)}: se cierra a partir del día siguiente.`
      : det.length ? `Se enciende cuando no quede nada en rojo arriba (${plural(det.length, "cosa", "cosas")}).`
      : !mfa ? "Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: cerrar lo pide, como todo lo que no se deshace."
      : `Al tocarlo se pide escribir «${fila.confirmacion}»: un cierre no se deshace.`;
    return `<section class="ct-card ct-cie-rev${det.length ? " rojo" : ""}" id="ct-cie-rev">
        <div class="ct-cab"><h2>${esc(cap(fila.nombre))} · lo que detiene el cierre</h2>${det.length ? pill(plural(det.length, "cosa", "cosas"), "bad") : pill("nada", "ok")}</div>
        <p class="ct-nota">Revisado ${esc(fechaHora(fila.revisado_el))}, con ${plural(rev.length, "control", "controles")} de la base: ${plural(frenan, "frena", "frenan")} el cierre si está${frenan === 1 ? "" : "n"} en rojo; los demás solo avisan. <button type="button" class="ct-cie-link" id="ct-cie-revisar">Volver a revisar</button></p>
        ${err ? errorCierreHTML(err) : ""}
        ${det.length ? `<ul class="ct-cie-lista">${det.map(x => itemCieHTML(x, sig)).join("")}</ul>`
          : `<p class="ct-aviso ok">Nada detiene el cierre de ${esc(fila.nombre)}: ${frenan === 1 ? "el control que frena está" : `los ${frenan} controles que frenan están`} en verde.</p>`}
        <div class="ct-cie-cerrar">
          <button type="button" class="accion ct-cie-peligro" id="ct-cie-cerrar"${puede ? "" : " disabled"} aria-describedby="ct-cie-porque">${esc(botonCerrarTxt(fila))}</button>
          <p class="ct-nota" id="ct-cie-porque">${esc(porque)}</p>
        </div>
        <div class="ct-form" hidden></div>
      </section>`;
  }
  function avisosHTML(rev, sig) {
    const av = rev.filter(x => x.nivel === "aviso" && rojo(x)), verdes = rev.filter(x => !rojo(x));
    return `<section class="ct-card ct-cie-avisos" id="ct-cie-avisos">
        <div class="ct-cab"><h2>Avisos</h2>${av.length ? pill(String(av.length), "warn") : pill("ninguno", "ok")}</div>
        <p class="ct-nota">No frenan el cierre, pero conviene mirarlos antes (o decirle al CPA por qué quedan).</p>
        ${av.length ? `<ul class="ct-cie-lista">${av.map(x => itemCieHTML(x, sig)).join("")}</ul>` : ""}
        <details class="ct-cie-verdes"><summary>En verde · ${verdes.length}</summary><ul class="ct-cie-lista">${verdes.map(x => itemCieHTML(x, sig)).join("")}</ul></details>
      </section>`;
  }
  function cerradoHTML(fila, c) {
    if (!c) return `<section class="ct-card ct-cie-rev" id="ct-cie-rev"><div class="ct-cab"><h2>${esc(cap(fila.nombre))}</h2>${pill("Cerrado", "ok")}</div>
        <p class="ct-nota">Se cerró fuera de la app (con fn_cerrar_periodo, en el SQL Editor): la base no guardó su revisión, ni la huella del mayor, ni su balanza, y no tiene export. Está cerrado igual: nadie escribe ahí.</p></section>`;
    const avisos = (Array.isArray(c.revision) ? c.revision : []).filter(x => x.nivel === "aviso" && rojo(x));
    return `<section class="ct-card ct-cie-rev ct-cie-cerrado" id="ct-cie-rev">
        <div class="ct-cab"><h2>${esc(cap(fila.nombre))}</h2>${pill("Cerrado", "ok")}</div>
        <p class="ct-nota">Cerrado el ${esc(fechaHora(c.cerrado_el))}${c.cerrado_por_nombre ? ` por ${esc(c.cerrado_por_nombre)}` : ""} · ${plural(c.asientos || 0, "asiento", "asientos")} · ${plural(c.lineas || 0, "línea", "líneas")}. Nadie vuelve a escribir ahí: lo que llegue tarde entra al mes abierto.</p>
        <p class="ct-cie-huella"><span class="ct-lbl">Huella del mayor (sha256)</span><span class="ct-num">${esc(c.hash_mayor)}</span></p>
        <div class="ct-cie-export" id="ct-cie-export" role="status">${S.cie.exportando === fila.periodo ? pasosHTML([{ txt: "Exportando…" }]) : exportadoHTML(c, S.cie.exportErr[fila.periodo])}</div>
        ${avisos.length ? `<details class="ct-cie-verdes"><summary>Se cerró con ${plural(avisos.length, "aviso", "avisos")}</summary><ul class="ct-cie-lista">${avisos.map(x => itemCieHTML(x, null, { solo: true })).join("")}</ul></details>` : ""}
      </section>`;
  }
  // El export de un período cerrado: lo registrado (con «Descargar» e «Imprimir») o «Volver a exportar», y el correo que falta
  function exportadoHTML(c, err) {
    const arch = Array.isArray(c.export_archivos) ? c.export_archivos : [];
    const correo = `<p class="ct-nota">El correo con estos archivos adjuntos llega después: la función «correo» todavía no tiene esa acción. Mientras tanto, «Descargar el cierre» y guárdalos (o mándaselos al CPA).</p>`;
    if (!c.exportado) {
      return `${err ? `<p class="ct-aviso bad ct-cie-export-err">${esc(err)}</p>` : `<p class="ct-aviso warn">Sin exportar: el mayor, la balanza y los estados todavía no están en el archivo privado «cierres».</p>`}
        <div class="ct-acciones"><button type="button" class="accion" data-cie-exportar="${esc(c.periodo)}">Volver a exportar</button><button type="button" class="accion secundaria" data-cie-imprimir="${esc(c.periodo)}">Imprimir los estados (PDF)</button></div>`;
    }
    return `<p class="ct-aviso ok">Exportado el ${esc(fechaHora(c.exportado_el))}${c.exportado_por_nombre ? ` por ${esc(c.exportado_por_nombre)}` : ""} · ${plural(arch.length, "archivo", "archivos")} en <span class="ct-num">cierres/${esc(c.export_ruta || "")}</span>${Number(c.exports_anteriores) ? ` · ${plural(c.exports_anteriores, "export anterior", "exports anteriores")} en su historial` : ""}.</p>
      ${err ? `<p class="ct-aviso bad ct-cie-export-err">${esc(err)}</p>` : ""}
      <div class="ct-acciones"><button type="button" class="accion" data-cie-descargar="${esc(c.periodo)}">Descargar el cierre</button><button type="button" class="accion secundaria" data-cie-imprimir="${esc(c.periodo)}">Imprimir los estados (PDF)</button></div>
      <div class="ct-cie-descarga" data-cie-descarga="${esc(c.periodo)}"></div>
      ${correo}`;
  }
  function rondaHTML(ronda) {
    if (ronda == null) return "";
    const cab = `<div class="ct-cab"><h2>La ronda de cada mañana</h2>`;
    if (!ronda.length) return `<section class="ct-card ct-cie-ronda" id="ct-cie-ronda">${cab}${pill("no ha corrido")}</div>
        <p class="ct-nota">Todavía no ha corrido. La base la corre sola cada mañana a las 6:45 (7:45 en verano), después del banco y del contador, cuando pg_cron está encendido en Supabase (Database → Extensions). Revisa el período que toca cerrar, que los meses cerrados sigan iguales, 1590 y la reserva, y avisa al teléfono de cada rojo nuevo. La IA no corre de noche.</p></section>`;
    const u = ronda[0], rojos = rojosDeRonda(ronda);
    const per = (ronda.find(x => x.periodo) || {}).periodo;
    return `<section class="ct-card ct-cie-ronda${rojos.length ? " rojo" : ""}" id="ct-cie-ronda">${cab}${rojos.length ? pill(plural(rojos.length, "rojo", "rojos"), Number(u.detienen) ? "bad" : "warn") : pill("todo en verde", "ok")}</div>
        <p class="ct-nota">Corrió el ${esc(fechaHora(u.corrida_el))}${per ? ` · revisó ${esc(nombrePer(per))}` : ""} · ${plural(Number(u.filas) || ronda.length, "control", "controles")}: ${plural(Number(u.detienen) || 0, "detiene", "detienen")} y ${plural(Number(u.avisos) || 0, "aviso", "avisos")} en rojo${Number(u.avisados) ? ` · ${plural(u.avisados, "aviso nuevo", "avisos nuevos")} al teléfono` : ""}.</p>
        ${rojos.length ? `<ul class="ct-cie-lista">${rojos.map(x => itemCieHTML(x, null, { ronda: true })).join("")}</ul>` : `<p class="ct-aviso ok">La última ronda no encontró nada en rojo.</p>`}
      </section>`;
  }
  // La confirmación fuerte: la frase exacta, escrita; el botón (rojo) se enciende solo cuando coincide
  function abrirConfirmacion(card, fila) {
    if (!card || S.ocupado) return;
    const f = card.querySelector(".ct-form");
    f.hidden = false;
    f.innerHTML = `<form class="ct-pide ct-cie-confirma" novalidate>
        <p class="ct-form-t">${esc(cap(fila.nombre))}: cerrarlo no se deshace</p>
        <ul class="ct-cie-conse">
          <li>Nadie vuelve a escribir en ${esc(fila.nombre)}: ni la app ni el SQL Editor. La base lo impide.</li>
          <li>Lo que llegue tarde entra al primer día del mes abierto; un error se corrige con un reverso en el mes abierto; un ajuste del CPA va al mes abierto diciendo qué mes corrige.</li>
          <li>Al cerrar, la app exporta el mayor, la balanza y los estados al archivo privado «cierres», con su huella.</li>
        </ul>
        <label class="ct-campo">Para confirmarlo, escribe <span class="ct-num ct-cie-frase">${esc(fila.confirmacion)}</span><input name="confirmo" autocomplete="off" autocapitalize="characters" autocorrect="off" spellcheck="false"></label>
        <div class="ct-acciones"><button class="accion ct-cie-peligro" type="submit" id="ct-cie-confirmar" disabled>${esc(botonCerrarTxt(fila))} para siempre</button><button class="accion secundaria" type="button" data-cerrar>Cancelar</button></div>
      </form>`;
    const form = f.querySelector("form"), inp = form.querySelector('[name="confirmo"]'), btn = $("ct-cie-confirmar");
    inp.addEventListener("input", () => { btn.disabled = inp.value.trim() !== fila.confirmacion; const e = f.querySelector(".ct-error"); if (e) e.remove(); });
    f.querySelector("[data-cerrar]").addEventListener("click", () => { f.hidden = true; f.innerHTML = ""; });
    form.addEventListener("submit", ev => { ev.preventDefault(); cerrarPeriodo(card, fila, inp.value); });
    f.scrollIntoView({ behavior: "smooth", block: "nearest" });
    inp.focus();
  }
  // CERRAR: la frase exacta (mal escrita no se manda nada), fn_cierre_cerrar y, si salió, el export
  async function cerrarPeriodo(card, fila, confirmo) {
    if (S.ocupado) return;
    if (!navigator.onLine) { mostrarErrorForma(card, "Sin señal: no se cerró nada."); return; }
    if (!mfaActivo()) { mostrarErrorForma(card, "Primero activa el código del teléfono (Conexiones y seguridad) y entra con él: cerrar lo pide."); return; }
    const frase = String(confirmo || "").trim();
    if (frase !== fila.confirmacion) { mostrarErrorForma(card, `Escribe exactamente «${fila.confirmacion}», en mayúsculas, como está: un cierre no se deshace y por eso se pide escrito. No se mandó nada.`); return; }
    S.ocupado = true;
    const apagados = [...card.querySelectorAll("button, input")].filter(b => !b.disabled);
    apagados.forEach(b => { b.disabled = true; });
    const btn = $("ct-cie-confirmar");
    if (btn) { btn.classList.add("ct-girando"); btn.setAttribute("aria-busy", "true"); }
    let r;
    try { r = await rpcCie("fn_cierre_cerrar", { p_periodo: fila.periodo, p_confirmo: frase }); }
    catch (err) {
      S.ocupado = false;
      apagados.forEach(b => { b.disabled = false; });
      if (btn) { btn.classList.remove("ct-girando"); btn.removeAttribute("aria-busy"); }
      // (la pista de MX010 es la consulta para el SQL Editor: aquí la lista ya va debajo, así que no se enseña)
      if (err.codigo === "MX010") { S.cie.error = partirMX010(err.message); S.hooks.avisar("No se cerró: algo lo detiene", true); return pintarCierre(); }
      mostrarErrorForma(card, esFalloDeRed(err) ? "Se cortó la señal: no se sabe si se cerró. Vuelve a abrir el cierre con señal: si salió, el período sale «Cerrado»; si no, sigue abierto."
        : `${err.message}${err.codigo === "22023" && err.pista && !String(err.message).includes(err.pista) ? ` (Escribe: ${err.pista})` : ""}`);
      return;
    }
    S.ocupado = false;
    S.hooks.avisar(`${cap(r && r.nombre ? r.nombre : fila.nombre)}: cerrado · huella del mayor ${String((r && r.hash_mayor) || "").slice(0, 12)}…`);
    S.cie.periodo = (r && r.periodo) || fila.periodo;
    // el período cambió de estado: los estados y la portada lo vuelven a leer
    S.est.cortes = null; S.saldos = null;
    // el export, justo después de cerrar
    await exportarDesde(S.cie.periodo);
  }

  // ---------- Activos fijos ----------
  async function pintarCieActivos(mia) {
    cargandoCie("Leyendo los activos fijos…");
    let activos, filas, cfg = null, mesDep = null, plan = [];
    try {
      [activos, filas] = await Promise.all([DB._leer("v_activos_fijos?select=*&order=fecha_servicio.asc,creado.asc"), leerCieEstado(), cuentas()]);
      cfg = (await DB._leer("cierre_config?select=metodo_depreciacion").catch(e => { if (esFalloDeRed(e)) throw e; return []; }))[0] || null;
      // el mes que toca depreciar: el más viejo abierto que ya terminó (la depreciación se fecha el último día)
      mesDep = filas.find(r => r.tipo === "mes" && r.estado === "abierto" && r.terminado) || null;
      if (mesDep && activos.length) plan = await rpcCie("fn_depreciacion_plan", { p_periodo: mesDep.periodo });
    } catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    const vivos = activos.filter(a => a.estado === "activo");
    const porId = new Map(activos.map(a => [a.id, a]));
    // lo que falta del mes: lo que el plan depreciaría en activos cuyo último mes posteado es anterior
    const falta = mesDep ? (Array.isArray(plan) ? plan : []).filter(x => num(x.monto) > 0 && String((porId.get(x.activo_id) || {}).ultimo_periodo || "") < mesDep.periodo) : [];
    subCie(activos.length && !vivos.length ? `Ningún activo en uso · ${plural(activos.length, "dado de baja", "dados de baja")}`
      : activos.length ? `${plural(vivos.length, "activo", "activos")} en uso · valor en libros <span class="ct-num">${fmt(suma(vivos, "valor_libros"))}</span> · depreciación al mes <span class="ct-num">${fmt(suma(vivos.filter(a => !a.terminado), "cuota_mensual"))}</span>`
      : "Todavía no hay activos fijos: se cargan con la cédula del CPA.");
    const notaDep = S.cie.notas.dep; S.cie.notas.dep = null;
    const depHTML = !mesDep || !activos.length ? "" : falta.length
      ? `<div class="ct-aviso warn ct-af-dep"><p>Falta la depreciación de ${esc(mesDep.nombre)}: <b class="ct-num">${fmt(suma(falta, "monto"))}</b> en ${plural(falta.length, "activo", "activos")} (Dr 6950 / Cr 1590, fechada el ${fechaLarga(mesDep.hasta)}). Sin ella el cierre no pasa.</p>
          <div class="ct-acciones"><button type="button" class="accion" id="ct-af-depreciar">Depreciar ${esc(mesDep.nombre)}</button></div></div>`
      : vivos.length ? `<p class="ct-aviso ok">La depreciación de ${esc(mesDep.nombre)} ya está en el libro.</p>` : "";
    const filasHTML = activos.map(a => `<tr class="ct-af${a.estado === "baja" ? " baja" : ""}" data-id="${esc(a.id)}">
        <td class="ct-cie-c1"><b>${esc(a.descripcion)}</b><small>${[a.placa_serie, `${a.cuenta} ${a.cuenta_nombre || ""}`.trim(), a.metodo === "manual" ? `${fmt(a.monto_mensual)} fijos al mes` : `línea recta, ${plural(a.vida_meses, "mes", "meses")}`].filter(Boolean).map(esc).join(" · ")}</small>
          ${a.estado === "baja" ? `<small class="bad-txt">Dado de baja el ${fechaLarga(a.baja_fecha)}: ${esc(a.baja_motivo)}</small>${a.baja_asiento_id ? "" : `<small class="ct-af-falta">${esc(S.cie.notas[a.id] || "Hasta que apuntes el asiento de la baja (Dr 1590 por lo acumulado, Cr la cuenta del activo por el costo, 4920 por la diferencia), 1590 sigue contando este activo.")}</small>`}` : ""}</td>
        <td data-col="En servicio">${fechaLarga(a.fecha_servicio)}</td>
        <td class="r ct-num" data-col="Costo">${fmt(a.costo)}</td>
        <td class="r ct-num" data-col="Acumulada">${fmt(a.acumulada)}<small>${plural(Number(a.meses_posteados) || 0, "mes", "meses")} en el libro</small></td>
        <td class="r ct-num" data-col="Valor en libros"><b>${fmt(a.valor_libros)}</b></td>
        <td class="r ct-num" data-col="Al mes">${a.terminado ? "terminado" : fmt(a.cuota_mensual)}</td>
        <td class="ct-af-acc">${a.estado === "activo" ? `<button type="button" class="accion secundaria chica" data-af-baja="${esc(a.id)}">Dar de baja</button>` : pill("baja", "warn")}</td>
      </tr>`).join("");
    cieCuerpo().innerHTML = `<section class="ct-card ct-cie-activos" id="ct-cie-activos">
        <div class="ct-cab"><h2>Activos fijos</h2>${pill(plural(activos.length, "activo", "activos"))}</div>
        ${ayudaHTML(`<p class="ct-nota">Camionetas, herramienta grande, equipo de cómputo, mejoras: lo que dura más de un año y se deprecia mes a mes (Dr 6950 / Cr 1590). La base postea la depreciación del mes con un toque (aquí) y el cierre no pasa sin ella. Una baja o una venta deja el activo fuera de la depreciación; su asiento (Dr 1590, Cr la cuenta del activo, 4920 la diferencia) va a mano. El método lo decide el CPA (Ajustes).</p>`)}
        ${notaDep ? `<p class="ct-aviso ok">${esc(notaDep)}</p>` : ""}
        ${depHTML}
        ${activos.length ? `<div class="ct-tabla-env"><table class="ct-tabla ct-cie-tabla ct-af-tabla"><thead><tr><th>Activo</th><th>En servicio</th><th class="r">Costo</th><th class="r">Acumulada</th><th class="r">Valor en libros</th><th class="r">Al mes</th><th></th></tr></thead><tbody>${filasHTML}</tbody></table></div>`
          : `<p class="ct-vacio ct-af-vacio">Todavía no hay activos fijos. Se cargan con la cédula del CPA (la de 2025 más las altas de 2026), cada uno con la depreciación que ya traía en QuickBooks al 30-sep: así 1590 cuadra con ellos. Hasta entonces el cierre lo da en verde: 1590 trae lo de QuickBooks.</p>`}
        <div class="ct-acciones"><button type="button" class="accion${activos.length ? " secundaria" : ""}" id="ct-af-alta">Dar de alta un activo</button></div>
        <div class="ct-form" hidden></div>
      </section>`;
    const card = $("ct-cie-activos");
    const dep = $("ct-af-depreciar");
    if (dep) dep.addEventListener("click", () => accionCie(card, "fn_depreciacion_mes", { p_periodo: mesDep.periodo }, r => {
      S.cie.notas.dep = r && r.nota ? r.nota : null;
      return r && r.ya_estaba ? "Ya estaba posteada: no se duplicó" : `Depreciación de ${mesDep.nombre} posteada${r && r.asiento ? ` · asiento ${r.asiento.numero}` : ""}`;
    }));
    $("ct-af-alta").addEventListener("click", () => formaAlta(card, cfg));
    card.querySelectorAll("[data-af-baja]").forEach(b => b.addEventListener("click", () => {
      const a = porId.get(b.dataset.afBaja); if (!a) return;
      montarForma(card, formaHTML(esc(`Dar de baja «${a.descripcion}» (venta, robo o ya no sirve)`),
        `<div class="ct-fila"><label class="ct-campo">Fecha de la baja<input name="fecha" type="date" required value="${esc(hoyMiami())}"></label>
         ${campoHTML("motivo", "Motivo (queda escrito)", "textarea", 'required data-falta="Falta el motivo de la baja (se vendió, se robó, ya no sirve…)."')}</div>`, "Dar de baja"),
        v => accionCie(card, "fn_activo_baja", { p_id: a.id, p_fecha: v.fecha, p_motivo: v.motivo }, r => { if (r && r.nota) S.cie.notas[a.id] = r.nota; return `Baja: ${a.descripcion}`; }));
    }));
  }
  function formaAlta(card, cfg) {
    const de15 = (S.cuentas || []).filter(c => /^15\d\d/.test(c.codigo) && c.codigo !== "1590");
    const metodo = (cfg && cfg.metodo_depreciacion) || "linea_recta";
    montarForma(card, formaHTML("Dar de alta un activo fijo (de la cédula del CPA o una compra nueva)",
      `<div class="ct-fila">
        ${campoHTML("descripcion", "Qué es", "texto", 'required placeholder="Camioneta Ford F-150 2024" data-falta="Falta qué es el activo: «Camioneta Ford F-150 2024», «Taladro magnético»."')}
        ${campoHTML("placa_serie", "Placa o serie (opcional)", "texto")}
        <label class="ct-campo">Cuenta<select name="cuenta" required data-falta="Falta la cuenta del activo (1510 vehículos, 1520 herramienta, 1530 cómputo, 1540 mejoras)."><option value="">Elige la cuenta…</option>${de15.map(c => `<option value="${esc(c.codigo)}">${esc(c.codigo)} · ${esc(c.nombre)}</option>`).join("")}</select></label>
        <label class="ct-campo">En servicio desde<input name="fecha_servicio" type="date" required data-falta="Falta desde cuándo está en servicio."></label>
        ${campoHTML("costo", "Costo", "monto", 'required data-falta="Falta el costo del activo."')}
        ${campoHTML("residual", "Residual (lo que valdrá al final)", "monto")}
        <label class="ct-campo">Método<select name="metodo"><option value="linea_recta"${metodo === "linea_recta" ? " selected" : ""}>Línea recta (por vida en meses)</option><option value="manual"${metodo === "manual" ? " selected" : ""}>Un monto fijo al mes</option></select></label>
        ${campoHTML("vida_meses", "Vida en meses (línea recta)", "texto", 'inputmode="numeric" placeholder="60"')}
        ${campoHTML("monto_mensual", "Monto al mes (monto fijo)", "monto")}
        ${campoHTML("dep_acumulada_inicial", "Depreciación que ya traía (QuickBooks al 30-sep)", "monto")}
        ${campoHTML("notas", "Notas (opcional)", "texto")}
      </div>`, "Dar de alta"), v => {
      const p = { descripcion: v.descripcion, cuenta: v.cuenta, fecha_servicio: v.fecha_servicio, costo: montoTxt(v.costo), metodo: v.metodo || metodo };
      if (v.placa_serie) p.placa_serie = v.placa_serie;
      if (montoTxt(v.residual)) p.residual = montoTxt(v.residual);
      if (p.metodo === "linea_recta" && v.vida_meses) p.vida_meses = /^\d+$/.test(v.vida_meses) ? Number(v.vida_meses) : v.vida_meses;
      if (p.metodo === "manual" && montoTxt(v.monto_mensual)) p.monto_mensual = montoTxt(v.monto_mensual);
      if (montoTxt(v.dep_acumulada_inicial)) p.dep_acumulada_inicial = montoTxt(v.dep_acumulada_inicial);
      if (v.notas) p.notas = v.notas;
      accionCie(card, "fn_activo_alta", { p }, r => `Alta: ${r && r.descripcion ? r.descripcion : v.descripcion}${r && r.cuota_mensual != null ? ` · ${fmt(r.cuota_mensual)} al mes` : ""}`);
    });
  }

  // ---------- La reserva de impuestos (1030) ----------
  async function pintarCieReserva(mia) {
    cargandoCie("Calculando la reserva con la base…");
    let res, est;
    try {
      const [rs, es] = await Promise.all([
        DB._leer("v_reserva_impuestos?select=*"),
        DB._leer("reserva_estimados?select=id,fecha,monto,anio_fiscal,nota,asiento_id,anulado_el,anulado_motivo&order=fecha.desc")
      ]);
      if (!Array.isArray(rs) || rs.length !== 1) throw errorControl("La reserva no devolvió su fila", [{ vista: "v_reserva_impuestos", filas: Array.isArray(rs) ? rs.length : 0, esperadas: 1, detalle: "La vista es UNA fila, la de hoy. Vacía: la sesión no es la del dueño." }]);
      res = rs[0]; est = Array.isArray(es) ? es : [];
      // FALLA RUIDOSA: lo que la vista resta como «ya pagado» es la suma de los estimados vivos del año que trajo la pantalla
      const vivos = est.filter(e => !e.anulado_el && Number(e.anio_fiscal) === Number(res.anio));
      const cent = v => Math.round((num(v) || 0) * 100);
      if (vivos.reduce((s, e) => s + cent(e.monto), 0) !== cent(res.estimados_pagados) || vivos.length !== Number(res.estimados_n || 0)) {
        throw errorControl("Los estimados no cuadran con la reserva", [{ vista: "v_reserva_impuestos", filas: `${res.estimados_n} · ${fmt(res.estimados_pagados)}`, esperadas: `${vivos.length} · ${fmt(vivos.reduce((s, e) => s + cent(e.monto), 0) / 100)}`, detalle: `Los estimados pagados de ${res.anio}: lo que resta la vista contra la lista de reserva_estimados. No se pinta una cifra que no cuadra.` }]);
      }
    } catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    const pct = num(res.reserva_pct), dif = num(res.diferencia);
    const [tit, clase] = pct == null ? ["Falta el % que fije el CPA", "warn"]
      : dif > 0 ? [`Transfiere ${fmt(dif)} a la reserva (1030)`, "warn"]
      : dif < 0 ? [`Sobra ${fmt(-dif)} en la reserva (1030)`, "ok"]
      : ["La reserva (1030) está al día", "ok"];
    subCie(`${esc(tit)} · próximo estimado el ${fechaLarga(res.proximo_estimado)}`);
    const vivos = est.filter(e => !e.anulado_el), anulados = est.filter(e => e.anulado_el);
    const estHTML = e => `<li class="ct-res-est${e.anulado_el ? " anulado" : ""}" data-id="${esc(e.id)}"><div class="ct-cie-item-txt"><p class="ct-cie-item-t"><span class="ct-num">${fechaLarga(e.fecha)}</span> · <b class="ct-num">${fmt(e.monto)}</b> · año fiscal ${esc(e.anio_fiscal)}</p>${e.nota ? `<p class="ct-cie-item-d">${esc(e.nota)}</p>` : ""}${e.anulado_el ? `<p class="ct-cie-item-d">Anulado: ${esc(e.anulado_motivo || "")}</p>` : ""}</div>${e.anulado_el ? pill("anulado") : `<button type="button" class="accion secundaria chica" data-res-anular="${esc(e.id)}">Anular</button>`}</li>`;
    cieCuerpo().innerHTML = `<section class="ct-card ct-cie-reserva" id="ct-cie-reserva">
        <div class="ct-cab"><h2>Reserva de impuestos</h2>${pct == null ? pill("falta el %", "warn") : pill(`${pct} % del CPA`)}</div>
        <p class="ct-res-titular ${clase}">${esc(tit)}</p>
        <p class="ct-nota">${esc(res.mensaje || "")}</p>
        <div class="ct-kpis cuatro">
          ${kpiHTML(`Utilidad de ${res.anio} a la fecha`, fmtNeg(res.utilidad_anio), "del libro, con la regla de ejercicio")}
          ${kpiHTML("% del CPA", pct == null ? "falta" : `${esc(pct)} %`, pct == null ? "lo fija el CPA" : `objetivo ${fmt(res.objetivo)}`)}
          ${kpiHTML("Estimados ya pagados", fmt(res.estimados_pagados), plural(Number(res.estimados_n) || 0, "pago marcado", "pagos marcados"))}
          ${kpiHTML("Reserva (1030)", fmt(res.saldo_1030), res.objetivo_1030 == null ? "sin objetivo todavía" : `debería tener ${fmt(res.objetivo_1030)}`)}
        </div>
        <div class="ct-res-prox${res.estimado_en_15_dias ? " cerca" : ""}">
          <p><b>Próximo estimado:</b> <span class="ct-num">${fechaLarga(res.proximo_estimado)}</span> · ${plural(Number(res.dias_para_estimado) || 0, "día", "días")}</p>
          ${res.estimado_en_15_dias ? `<p class="ct-aviso warn">Vence en ${plural(Number(res.dias_para_estimado) || 0, "día", "días")}${res.monto_sugerido != null ? `: el monto sugerido es <b class="ct-num">${fmt(res.monto_sugerido)}</b>` : ""}. Confírmalo con el CPA antes de pagar.</p>` : ""}
          <p class="ct-nota">${esc(res.nota || "")}</p>
        </div>
        <div class="ct-acciones"><button type="button" class="accion${pct == null ? "" : " secundaria"}" id="ct-res-pct">${pct == null ? "Guardar el % del CPA" : "Cambiar el %"}</button><button type="button" class="accion secundaria" id="ct-res-marcar">Marcar un pago como estimado</button></div>
        <div class="ct-form" hidden></div>
      </section>
      <section class="ct-card ct-cie-estimados" id="ct-cie-estimados">
        <div class="ct-cab"><h2>Estimados pagados</h2>${pill(plural(vivos.length, "pago", "pagos"))}</div>
        ${vivos.length ? `<ul class="ct-cie-lista">${vivos.map(estHTML).join("")}</ul>` : `<p class="ct-nota">Ninguno marcado todavía. Un pago al IRS entra al libro como Dr 3200 / Cr banco (la IA lo propone así); aquí se marca como estimado para que la reserva lo reste y vaya en el paquete del CPA.</p>`}
        ${anulados.length ? `<details class="ct-cie-verdes"><summary>Anulados · ${anulados.length}</summary><ul class="ct-cie-lista">${anulados.map(estHTML).join("")}</ul></details>` : ""}
        <div class="ct-form" hidden></div>
      </section>`;
    const card = $("ct-cie-reserva"), cardEst = $("ct-cie-estimados");
    $("ct-res-pct").addEventListener("click", () => montarForma(card, formaHTML("El % de la utilidad que se reserva para impuestos (lo fija el CPA)",
      campoHTML("pct", "Porcentaje", "texto", `inputmode="decimal" required placeholder="25" value="${pct == null ? "" : esc(pct)}" data-falta="Falta el % (por ejemplo 25)."`), "Guardar"), v => {
      const n = Number(montoTxt(v.pct));
      if (!Number.isFinite(n)) { mostrarErrorForma(card, "Escribe el % como número: 25, o 27.5."); return; }
      accionCie(card, "fn_cierre_config", { p: { reserva_pct: n } }, r => `Guardado: la reserva es el ${r && r.reserva_pct != null ? r.reserva_pct : n} % de la utilidad`);
    }));
    $("ct-res-marcar").addEventListener("click", () => montarForma(card, formaHTML("Marcar un pago al IRS como impuesto estimado (su asiento carga a 3200)",
      `<div class="ct-fila">${campoHTML("numero", "Número del asiento del pago", "texto", 'required placeholder="2026-000005" data-falta="Falta el número del asiento del pago (2026-000005)."')}
       ${campoHTML("nota", "Nota (opcional)", "texto", 'placeholder="Q3 2026, IRS"')}
       ${campoHTML("anio", "Año fiscal (si no es el de su fecha)", "texto", 'inputmode="numeric"')}</div>`, "Marcar como estimado"), async v => {
      if (S.ocupado) return;
      let as;
      try { as = await DB._leer(`asientos?select=id,numero&numero=eq.${enc(v.numero)}`); }
      catch (err) { mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se marcó nada." : err.message); return; }
      if (!Array.isArray(as) || !as.length) { mostrarErrorForma(card, `No hay ningún asiento con el número «${v.numero}». Búscalo en el mayor de 3200 (Estados → Balanza → 3200).`); return; }
      const args = { p_asiento: as[0].id };
      if (v.nota) args.p_nota = v.nota;
      if (v.anio) args.p_anio_fiscal = /^\d{4}$/.test(v.anio) ? Number(v.anio) : v.anio;
      accionCie(card, "fn_reserva_estimado_marcar", args, r => `Estimado marcado: ${r && r.asiento_numero ? r.asiento_numero : v.numero} · ${fmt(r && r.monto)}${r && r.anio_fiscal ? ` (año fiscal ${r.anio_fiscal})` : ""}`);
    }));
    cardEst.querySelectorAll("[data-res-anular]").forEach(b => b.addEventListener("click", () => {
      const e = est.find(x => x.id === b.dataset.resAnular); if (!e) return;
      montarForma(cardEst, formaHTML(esc(`Anular el estimado del ${fechaLarga(e.fecha)} por ${fmt(e.monto)} (queda, con su motivo)`),
        campoHTML("motivo", "Motivo", "textarea", 'required data-falta="Falta por qué se anula (por ejemplo: no era un estimado, era el pago del 1120-S)."'), "Anular"),
        v => accionCie(cardEst, "fn_reserva_estimado_anular", { p_id: e.id, p_motivo: v.motivo }, () => "Estimado anulado"));
    }));
  }

  // ---------- DR-15 (Florida): lo que la base ya sabe y lo que no ----------
  async function pintarCieDr15(mia) {
    cargandoCie("Leyendo el DR-15…");
    let filas;
    try { filas = await DB._leer("v_dr15_mes?select=*&order=desde.desc"); }
    catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    const hoy = hoyMiami();
    const vis = (Array.isArray(filas) ? filas : []).filter(f => String(f.desde) <= hoy);
    subCie(`${plural(vis.length, "mes", "meses")} · el use tax de las compras sin el impuesto de Florida; el lado de las ventas llega con las facturas`);
    const nose = `<span class="ct-cie-nose">aún no se sabe</span>`;
    const val = v => v == null ? nose : fmt(v);
    cieCuerpo().innerHTML = `<section class="ct-card ct-cie-dr15" id="ct-cie-dr15">
        <div class="ct-cab"><h2>DR-15 por mes</h2></div>
        ${vis.length ? `<div class="ct-tabla-env"><table class="ct-tabla ct-cie-tabla ct-dr15-tabla"><thead><tr><th>Mes</th><th class="r">Compras con use tax</th><th class="r">Use tax cargado (2300)</th><th class="r">Pagado al DOR</th><th class="r">Saldo de 2300</th><th class="r">Ventas gravables</th><th class="r">Sales tax cobrado</th></tr></thead><tbody>
          ${vis.map(f => `<tr data-periodo="${esc(f.periodo)}"><td class="ct-cie-c1"><b>${esc(cap(nombrePer(f.periodo)))}</b></td>
            <td class="r ct-num" data-col="Compras con use tax">${f.compras_use_tax_n == null ? nose : `${fmt(f.compras_use_tax_base)}<small>${plural(f.compras_use_tax_n, "compra", "compras")}</small>`}</td>
            <td class="r ct-num" data-col="Use tax cargado (2300)">${val(f.use_tax_cargado_2300)}</td>
            <td class="r ct-num" data-col="Pagado al DOR">${val(f.use_tax_pagado_2300)}</td>
            <td class="r ct-num" data-col="Saldo de 2300">${val(f.use_tax_saldo_2300)}</td>
            <td class="r" data-col="Ventas gravables">${val(f.ventas_gravables)}</td>
            <td class="r" data-col="Sales tax cobrado">${val(f.sales_tax_cobrado)}</td></tr>`).join("")}
        </tbody></table></div>` : `<p class="ct-vacio">Todavía no hay meses en el libro.</p>`}
        ${vis.length && vis[0].nota ? `<p class="ct-nota">${esc(vis[0].nota)}</p>` : ""}
        <p class="ct-nota">«Aún no se sabe» no es un cero: es lo que la app todavía no separa. Hasta entonces, las ventas del DR-15 salen de las facturas, a mano.</p>
      </section>`;
  }

  // ---------- Historial de cierres ----------
  async function pintarCieHistorial(mia) {
    cargandoCie("Leyendo el historial de cierres…");
    let filas;
    try { filas = await DB._leer("v_cierres?select=*&order=cerrado_el.desc"); }
    catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    filas = Array.isArray(filas) ? filas : [];
    subCie(filas.length ? `${plural(filas.length, "período cerrado", "períodos cerrados")} desde la app · ${plural(filas.filter(f => f.exportado).length, "exportado", "exportados")}` : "Todavía no se ha cerrado ningún período desde la app.");
    cieCuerpo().innerHTML = `<section class="ct-card ct-cie-historial" id="ct-cie-historial">
        <div class="ct-cab"><h2>Historial de cierres</h2></div>
        ${filas.length ? `<ul class="ct-hist-lista">${filas.map(c => `<li class="ct-hist" data-periodo="${esc(c.periodo)}">
            <div class="ct-hist-cab"><b>${esc(cap(nombrePer(c.periodo)))}</b>${pill("Cerrado", "ok")}${c.exportado ? pill("exportado", "ok") : pill("sin exportar", "warn")}</div>
            <p class="ct-nota">Cerrado el ${esc(fechaHora(c.cerrado_el))}${c.cerrado_por_nombre ? ` por ${esc(c.cerrado_por_nombre)}` : ""} · ${plural(c.asientos || 0, "asiento", "asientos")} · ${plural(Number(c.avisos) || 0, "aviso", "avisos")} al cerrar</p>
            <p class="ct-nota">Huella del mayor <span class="ct-num" title="${esc(c.hash_mayor)}">${esc(String(c.hash_mayor || "").slice(0, 12))}…</span>${c.exportado ? ` · exportado el ${esc(fechaHora(c.exportado_el))} a <span class="ct-num">cierres/${esc(c.export_ruta || "")}</span> (${plural(Array.isArray(c.export_archivos) ? c.export_archivos.length : 0, "archivo", "archivos")}${Number(c.exports_anteriores) ? `, ${plural(c.exports_anteriores, "export anterior", "exports anteriores")}` : ""})` : ""}</p>
            <div class="ct-acciones">${c.exportado ? `<button type="button" class="accion secundaria chica" data-cie-descargar="${esc(c.periodo)}">Descargar</button>` : `<button type="button" class="accion chica" data-cie-exportar="${esc(c.periodo)}">Volver a exportar</button>`}<button type="button" class="accion secundaria chica" data-cie-imprimir="${esc(c.periodo)}">Imprimir los estados</button><button type="button" class="accion secundaria chica" data-cie-per="${esc(c.periodo)}">Ver el cierre</button></div>
            <div class="ct-cie-descarga" data-cie-descarga="${esc(c.periodo)}"></div>
          </li>`).join("")}</ul>` : `<p class="ct-vacio">Todavía no se ha cerrado ningún período desde la app. El primero es la apertura (el 30-sep), después octubre.</p>`}
      </section>`;
    wireCie(cieCuerpo());
  }

  // ---------- Ajustes del cierre (cierre_config) ----------
  async function pintarCieAjustes(mia) {
    cargandoCie("Leyendo los ajustes del cierre…");
    let cfg;
    try {
      const c = await DB._leer("cierre_config?select=*");
      if (!Array.isArray(c) || !c.length) throw errorControl("Los ajustes del cierre no aparecieron", [{ vista: "cierre_config", filas: 0, esperadas: 1, detalle: "c9 siembra una fila (id = 1) al pegarse. Vacía: la sesión no es la del dueño." }]);
      cfg = c[0];
    } catch (err) { if (!vivaCie(mia)) return; return pintarErrorCie(err, pintarCierre); }
    if (!vivaCie(mia)) return;
    subCie(`La ronda ${cfg.ronda_activa ? "corre cada mañana" : "<b>está apagada</b>"} · avisos al teléfono ${cfg.aviso_push ? "sí" : "no"} · reserva ${cfg.reserva_pct == null ? "sin %" : `${esc(cfg.reserva_pct)} %`}`);
    cieCuerpo().innerHTML = `<section class="ct-card ct-cie-ajustes" id="ct-cie-ajustes">
        <div class="ct-cab"><h2>Ajustes del cierre</h2></div>
        <form class="ct-pide" id="ct-cie-ajustes-form" novalidate>
          <label class="ct-casilla"><input type="checkbox" name="ronda_activa"${cfg.ronda_activa ? " checked" : ""}> La ronda revisa el cierre cada mañana (6:45; 7:45 en verano)</label>
          <label class="ct-casilla"><input type="checkbox" name="aviso_push"${cfg.aviso_push ? " checked" : ""}> Avisarme al teléfono cuando algo nuevo se ponga en rojo</label>
          <div class="ct-fila">
            <label class="ct-campo">% de la reserva de impuestos (lo fija el CPA)<input name="reserva_pct" inputmode="decimal" placeholder="25" value="${cfg.reserva_pct == null ? "" : esc(cfg.reserva_pct)}"></label>
            <label class="ct-campo">Método libro de depreciación (lo decide el CPA)<select name="metodo_depreciacion"><option value="linea_recta"${cfg.metodo_depreciacion === "linea_recta" ? " selected" : ""}>Línea recta</option><option value="manual"${cfg.metodo_depreciacion === "manual" ? " selected" : ""}>Un monto fijo al mes</option></select></label>
          </div>
          <div class="ct-acciones"><button type="submit" class="accion">Guardar los ajustes</button></div>
        </form>
        <p class="ct-nota">Cambiados el ${esc(fechaHora(cfg.actualizado))}. El % vacío lo quita (la reserva vuelve a decir que falta). El método vale para las altas nuevas: cada activo guarda el suyo.</p>
        <div class="ct-form" hidden></div>
      </section>`;
    const card = $("ct-cie-ajustes"), form = $("ct-cie-ajustes-form");
    form.addEventListener("submit", ev => {
      ev.preventDefault();
      const e0 = card.querySelector(".ct-form .ct-error"); if (e0) e0.remove();
      const p = {};
      if (form.ronda_activa.checked !== !!cfg.ronda_activa) p.ronda_activa = form.ronda_activa.checked;
      if (form.aviso_push.checked !== !!cfg.aviso_push) p.aviso_push = form.aviso_push.checked;
      const t = montoTxt(form.reserva_pct.value);
      const pct = t === "" ? null : Number(t);
      if (t !== "" && !Number.isFinite(pct)) { mostrarErrorForma(card, "Escribe el % como número: 25, o 27.5 (vacío lo quita)."); return; }
      if ((pct == null ? null : pct) !== (cfg.reserva_pct == null ? null : num(cfg.reserva_pct))) p.reserva_pct = pct;
      if (form.metodo_depreciacion.value !== cfg.metodo_depreciacion) p.metodo_depreciacion = form.metodo_depreciacion.value;
      if (!Object.keys(p).length) { mostrarErrorForma(card, "No cambiaste nada."); return; }
      accionCie(card, "fn_cierre_config", { p }, () => "Ajustes del cierre guardados");
    });
  }

  // ============================================================
  // COSTO POR OBRA (c10, fase 9) — docs/conta/c10-costo-obra.sql
  //
  // «La fase que justifica todo el proyecto»: cada obra con lo que de verdad
  // costó contra lo que se estimó. Tres apartados:
  //   · OBRAS: arriba, lo que falta por configurar (el % de burden estándar y
  //     la cuenta de la mano de obra sin obra, con su campo y su porqué en
  //     una frase; fn_jornal_config). Debajo la lista (v_margen_obra: buscar,
  //     activas / terminadas) con el contrato, el costo real, el margen y una
  //     señal contra el estimado. Al tocar una, su detalle (fn_margen_obra):
  //     estimado contra real por concepto, con la mano de obra REAL (pagada y
  //     repartida) y la ESTÁNDAR (horas sin pago × tarifa × burden) en filas
  //     aparte y la segunda con su etiqueta «estándar, no real»; la
  //     cobertura («16.5 h con pago real, 16 h a estándar»), las horas
  //     estimadas contra las reales, por cuenta, los CO aparte, por fase, por
  //     cost code (o su vacío dicho en llano), quién trabajó y los repartos.
  //     Cada número del real trae su «bajar» (la llave de c4: los pedazos de
  //     v_libro que lo suman): tocarlo enseña esas líneas con su asiento, que
  //     se abre en Estados; si lo que baja no suma la cifra, se dice en rojo.
  //   · REPARTOS: el historial (v_jornal_repartos) con «Deshacer» (motivo
  //     obligatorio y el código del teléfono; fn_jornal_deshacer reversa el
  //     asiento y el pago vuelve a la Bandeja).
  //   · PERSONAS: quién cobra por horas (v_jornal_personas): alta con su
  //     patrón, cambiar el patrón, baja y volver a dar de alta.
  // FALLA RUIDOSA: antes de pintar una cifra, v_margen_control; un cuadre en
  // rojo y la página no pinta números (el rojo con el detalle); sus avisos
  // salen arriba. Sin c10 pegado, la página lo dice en llano. Ninguna cifra
  // se calcula aquí: vienen listas de la base.
  // ============================================================
  const SUBS_OB = { obras: "Obras", repartos: "Repartos", personas: "Personas" };
  const obCuerpo = () => $("ct-ob-cuerpo");
  const vivaOb = mia => mia === S.obras.serie && S.pagina === "obras" && !!obCuerpo();
  const subOb = html => { const s = main() && main().querySelector(".ct-pag-sub"); if (s) s.innerHTML = html; };
  const OBRA_TERMINADA = ["completado", "cancelado", "cerrado", "terminado"];
  const ESTADO_OBRA = { estimando: "estimando", enviado: "enviado", aprobado: "aprobada", ejecucion: "en ejecución", pausa: "en pausa", completado: "terminada", cancelado: "cancelada" };
  const terminada = o => OBRA_TERMINADA.includes(o.estado) || !!o.completado_el;
  const pctTxt = v => { const n = num(v); return n == null || Number.isNaN(n) ? "—" : `${n.toLocaleString("en-US", { maximumFractionDigits: 1 })} %`; };

  async function pintarObras() {
    const mia = ++S.obras.serie;
    if (!navigator.onLine) return sinSenal(pintarObras);
    if (!SUBS_OB[S.obras.sub]) S.obras.sub = "obras";
    main().innerHTML = cabPagina(TITULOS.obras, "Leyendo con la base…") +
      `<section class="ct-card ct-ob-barra"><div class="ct-chips ct-ob-subs" aria-label="Qué parte">${Object.keys(SUBS_OB).map(k =>
        `<button type="button" class="ct-chip" data-ob-sub="${k}" aria-pressed="${k === S.obras.sub ? "true" : "false"}">${esc(SUBS_OB[k])}</button>`).join("")}</div></section>
      <div id="ct-ob-cuerpo" class="ct-ob-cuerpo"><div class="ct-card ct-cargando">Cargando…</div></div>`;
    main().querySelectorAll("[data-ob-sub]").forEach(b => b.addEventListener("click", () => { if (!S.ocupado) ir("obras", { sub: b.dataset.obSub }); }));
    marcarVolver();
    if (S.obras.sub === "repartos") return pintarObRepartos(mia);
    if (S.obras.sub === "personas") return pintarObPersonas(mia);
    if (S.obras.sel) return pintarObra(S.obras.sel, mia);
    return pintarObLista(mia);
  }
  function errorOb(err, reintentar) {
    const c = obCuerpo(); if (!c) return;
    if (faltaC10(err) && !esFalloDeRed(err)) {
      c.innerHTML = `<section class="ct-card ct-rojo" role="alert"><h2>Falta el costo por obra en la base</h2>
        <p>Esta página lee lo que deja <span class="ct-num">docs/conta/c10-costo-obra.sql</span>, y la base todavía no lo tiene. Pégalo entero en Supabase (SQL Editor → pegar → Run), después de c1 a c9. Después vuelve aquí.</p>
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-reintentar">Reintentar</button></div></section>`;
      $("ct-reintentar").addEventListener("click", reintentar);
      return;
    }
    pintarError(err, reintentar, err.codigo === "42501" ? "Contabilidad es solo del dueño" : undefined, c);
  }
  // FALLA RUIDOSA: los cuadres del margen en verde antes de pintar una cifra (sus avisos se devuelven para enseñarlos)
  async function controlMargen() {
    const ctl = await DB._leer("v_margen_control?select=*&order=orden.asc");
    if (!Array.isArray(ctl) || !ctl.length) throw errorControl("El control del costo por obra no devolvió nada", [{ vista: "control del margen", filas: 0, esperadas: "6", detalle: "Vacío: la sesión no es la del dueño (el equipo no ve nada de esto) o a la base le falta c10." }]);
    const rojos = ctl.filter(f => f.nivel === "cuadre" && f.ok !== true);
    if (rojos.length) throw errorControl("El costo por obra no cuadra", rojos.map(f => ({ vista: cap(String(f.cuadre || "").replace(/^margen: /, "")), filas: null, esperadas: null, detalle: f.detalle })));
    return ctl.filter(f => f.ok !== true);
  }
  const avisosCtlHTML = avisos => avisos.length ? `<section class="ct-card"><ul class="ct-jr-avisos">${avisos.map(f => `<li class="ct-aviso warn">${esc(cap(String(f.cuadre || "").replace(/^(margen|jornal): /, "")))}: ${esc(f.detalle || "")}</li>`).join("")}</ul></section>` : "";
  // Una acción de la página (RPC con la sesión del dueño): la tarjeta se apaga, el error va a su forma; si salió, aviso y repintar
  async function accionOb(card, fn, args, exito) {
    if (S.ocupado) return;
    if (!navigator.onLine) { mostrarErrorForma(card, "Sin señal: no se hizo nada."); return; }
    S.ocupado = true;
    const apagados = [...card.querySelectorAll("button, input, select, textarea")].filter(b => !b.disabled);
    apagados.forEach(b => { b.disabled = true; });
    let r;
    try { r = await DB._rpc(fn, args); }
    catch (err) {
      apagados.forEach(b => { b.disabled = false; });
      S.ocupado = false;
      mostrarErrorForma(card, esFalloDeRed(err) ? "Sin señal: no se guardó. Vuelve a intentarlo con señal." : err.codigo === "MFA" ? "Falta el código del teléfono: sal y vuelve a entrar con él." : err.message);
      return;
    }
    S.ocupado = false;
    const aviso = exito(r);
    if (aviso) S.hooks.avisar(...(Array.isArray(aviso) ? aviso : [aviso]));
    if (S.pagina === "obras") await pintarObras();
  }
  // Una tabla que en el teléfono se apila (cada celda con su etiqueta): cols [{ t, r?, c? }], filas = celdas en HTML ya escapado
  const tablaOb = (cols, filas, clase) => `<div class="ct-ob-tabla-env"><table class="ct-tabla ct-ob-tabla${clase ? " " + clase : ""}"><thead><tr>${cols.map(c => `<th${c.r ? ` class="r"` : ""}>${esc(c.t)}</th>`).join("")}</tr></thead>
    <tbody>${filas.map(f => `<tr${f.clase ? ` class="${f.clase}"` : ""}>${f.celdas.map((v, i) => `<td${cols[i].r ? ` class="r ct-num"` : ""}${i ? ` data-col="${esc(cols[i].t)}"` : ` class="ct-ob-c1"`}>${v}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;

  // ---------- Obras: lo que falta por configurar y la lista ----------
  async function pintarObLista(mia) {
    let avisos, filas, cfg;
    try {
      [avisos, filas, cfg] = await Promise.all([
        controlMargen(),
        DB._leer("v_margen_obra?select=*&order=obra.asc"),
        DB._leer("jornal_config?select=*").then(c => (c || [])[0] || null),
        cuentas()
      ]);
      if (!vivaOb(mia)) return;
      if (!cfg) throw errorControl("La configuración del jornal no apareció", [{ vista: "configuración", filas: 0, esperadas: 1, detalle: "c10 siembra su fila al pegarse: si no está, la sesión no es la del dueño o c10 no se pegó entero." }]);
    } catch (err) { if (!vivaOb(mia)) return; return errorOb(err, pintarObras); }
    S.jr.cfg = cfg;
    const act = filas.filter(o => !terminada(o)), ter = filas.filter(terminada);
    const sinRep = filas.reduce((s, o) => s + (num(o.pagos_sin_repartir) || 0), 0);
    subOb(`${plural(filas.length, "obra", "obras")} · costo real <span class="ct-num">${fmt(filas.reduce((s, o) => s + (num(o.costo_real) || 0), 0))}</span>${sinRep ? ` · <span class="bad-txt">${plural(sinRep, "pago de mano de obra sin repartir", "pagos de mano de obra sin repartir")}</span>` : ""}`);
    if (!["activas", "terminadas", "todas"].includes(S.obras.filtro)) S.obras.filtro = "activas";
    obCuerpo().innerHTML = configHTML(cfg) + avisosCtlHTML(avisos) +
      `<section class="ct-card ct-ob-lista" id="ct-ob-lista">
        <div class="ct-herr-fila"><label class="ct-campo ct-buscar">Buscar<input id="ct-ob-buscar" type="search" placeholder="Obra o cliente" value="${esc(S.obras.q)}" autocomplete="off"></label></div>
        <div class="ct-chips" aria-label="Qué obras">${[["activas", "Activas", act.length], ["terminadas", "Terminadas", ter.length], ["todas", "Todas", filas.length]].map(([k, t, n]) =>
          `<button type="button" class="ct-chip" data-ob-filtro="${k}" aria-pressed="${S.obras.filtro === k ? "true" : "false"}">${t} (${n})</button>`).join("")}</div>
        <div class="ct-ob-cab" aria-hidden="true"><span>Obra</span><span class="r">Contrato</span><span class="r">Costo real</span><span class="r">Margen</span><span>Contra el estimado</span></div>
        <div id="ct-ob-filas" class="ct-ob-filas"></div>
        ${ayudaHTML(`<p class="ct-nota">El costo real es lo que el libro tiene con esa obra desde el 1-oct (lo de antes está en QuickBooks: esa obra sale «parcial»). La mano de obra real es lo pagado y repartido por horas; la de las horas que aún no tienen pago va aparte como «estándar, no real», y se suma solo para comparar con el estimado. El margen es lo facturado menos el costo real.</p>`, "¿De dónde sale cada número?")}
      </section>`;
    wireConfig(cfg);
    const pintaFilas = () => {
      const q = sinAcentos(S.obras.q).trim();
      let l = S.obras.filtro === "activas" ? act : S.obras.filtro === "terminadas" ? ter : filas;
      if (q) l = l.filter(o => sinAcentos(`${o.obra || ""} ${o.cliente || ""} ${o.proyecto_id || ""}`).includes(q));
      $("ct-ob-filas").innerHTML = l.length ? l.map(obraFilaHTML).join("") : `<p class="ct-vacio">${q ? `Ninguna obra con «${esc(S.obras.q)}».` : S.obras.filtro === "terminadas" ? "Ninguna obra terminada todavía." : "Ninguna obra activa."}</p>`;
      $("ct-ob-filas").querySelectorAll("[data-ob]").forEach(b => b.addEventListener("click", () => { S.obras.sel = b.dataset.ob; S.obras.bajar = null; window.scrollTo(0, 0); pintarObras(); }));
    };
    $("ct-ob-buscar").addEventListener("input", ev => { S.obras.q = ev.target.value; pintaFilas(); });
    obCuerpo().querySelectorAll("[data-ob-filtro]").forEach(b => b.addEventListener("click", () => {
      S.obras.filtro = b.dataset.obFiltro;
      obCuerpo().querySelectorAll("[data-ob-filtro]").forEach(x => x.setAttribute("aria-pressed", String(x === b)));
      pintaFilas();
    }));
    pintaFilas();
  }
  // la señal contra el estimado: lo que sobra o lo que se pasa (costo real + estándar contra el costo estimado)
  function senalOb(o) {
    if (num(o.costo_estimado) == null) return pill("sin estimado");
    const d = num(o.diferencia), usado = num(o.costo_estimado) ? (num(o.costo_con_estandar) || 0) / num(o.costo_estimado) : 0;
    if (d < 0) return pill(`se pasa ${fmtAbs(d)}`, "bad");
    if (usado > 0.9) return pill(`cerca: sobran ${fmt(d)}`, "warn");
    return pill(`dentro: sobran ${fmt(d)}`, "ok");
  }
  function obraFilaHTML(o) {
    const est = num(o.mano_obra_estandar);
    return `<button type="button" class="ct-ob-fila" data-ob="${esc(o.proyecto_id)}">
      <span class="ct-ob-n"><b>${esc(o.obra || o.proyecto_id)}</b><small>${esc([o.cliente, ESTADO_OBRA[o.estado] || o.estado].filter(Boolean).join(" · "))}</small>${o.parcial ? pill("parcial", "warn") : ""}</span>
      <span class="ct-ob-v r" data-col="Contrato"><span class="ct-num">${fmt(o.contrato)}</span></span>
      <span class="ct-ob-v r" data-col="Costo real"><span class="ct-num">${fmt(o.costo_real)}</span>${est ? `<small>+ <span class="ct-num">${fmt(est)}</span> estándar</small>` : ""}</span>
      <span class="ct-ob-v r" data-col="Margen"><span class="ct-num ${num(o.margen_real) < 0 ? "bad-txt" : ""}">${pctTxt(o.margen_real_pct)}</span>${o.margen_real != null ? `<small class="ct-num">${fmtNeg(o.margen_real)}</small>` : ""}</span>
      <span class="ct-ob-senal" data-col="Contra el estimado">${senalOb(o)}</span>
    </button>`;
  }
  // Lo que falta por configurar (o, ya puesto, plegado como «Ajustes»): el burden estándar y la cuenta de lo sin obra
  function configHTML(cfg) {
    const faltaB = cfg.burden_estandar_pct == null, faltaC = !cfg.cuenta_sin_obra, falta = faltaB || faltaC;
    const campos = `<form class="ct-pide" id="ct-ob-config-form" novalidate>
        <label class="ct-campo">Burden estándar (%)${faltaB ? ` ${pill("falta", "warn")}` : ""}<input name="burden" inputmode="decimal" placeholder="por ejemplo 18" value="${cfg.burden_estandar_pct == null ? "" : esc(num(cfg.burden_estandar_pct))}" autocomplete="off">
          <span class="ct-sub">Lo que cuesta de más cada hora sobre la tarifa (impuestos, seguro, herramienta): con él se calcula la mano de obra estándar de las horas que aún no tienen pago. Si no aplica, pon 0.</span></label>
        <label class="ct-campo">Cuenta de la mano de obra sin obra${faltaC ? ` ${pill("falta", "warn")}` : ""}<select name="cuenta_sin_obra"><option value="">Sin decir todavía</option>${opcionesSinObra(cfg.cuenta_sin_obra || "")}</select>
          <span class="ct-sub">A dónde va lo que se paga por horas que no tienen obra (taller, compras, recados). Mientras el CPA no decida otra, 7900 Otros gastos.</span></label>
        <div class="ct-acciones"><button type="submit" class="accion${falta ? "" : " secundaria"}">Guardar</button></div>
      </form><div class="ct-form" hidden></div>`;
    return falta ? `<section class="ct-card ct-ob-config falta" id="ct-ob-config"><h2>Lo que falta por configurar</h2>${campos}</section>`
      : `<section class="ct-card ct-ob-config" id="ct-ob-config"><details><summary>Ajustes del costo: burden estándar ${pctTxt(cfg.burden_estandar_pct)} · lo sin obra a ${esc(cfg.cuenta_sin_obra)}</summary>${campos}</details></section>`;
  }
  function wireConfig(cfg) {
    const card = $("ct-ob-config"), form = $("ct-ob-config-form"); if (!form) return;
    form.addEventListener("submit", ev => {
      ev.preventDefault();
      const p = {}, t = montoTxt(form.burden.value);
      const b = t === "" ? null : Number(t);
      if (t !== "" && (!Number.isFinite(b) || b < 0 || b > 100)) { mostrarErrorForma(card, "El burden va de 0 a 100: escribe solo el número (18, o 22.5); vacío lo quita."); return; }
      if (b !== (cfg.burden_estandar_pct == null ? null : num(cfg.burden_estandar_pct))) p.burden_estandar_pct = b;
      const c = form.cuenta_sin_obra.value || null;
      if (c !== (cfg.cuenta_sin_obra || null)) p.cuenta_sin_obra = c;
      if (!Object.keys(p).length) { mostrarErrorForma(card, "No cambiaste nada."); return; }
      accionOb(card, "fn_jornal_config", { p }, () => "Ajustes del costo guardados");
    });
  }

  // ---------- Una obra: estimado contra real ----------
  async function pintarObra(id, mia) {
    let avisos, d;
    try {
      [avisos, d] = await Promise.all([controlMargen(), DB._rpc("fn_margen_obra", { p_proyecto: id })]);
      if (!vivaOb(mia)) return;
      if (!d || !d.obra) throw errorControl("La obra no apareció", [{ vista: "costo de la obra", filas: 0, esperadas: 1, detalle: `La base no devolvió la obra ${id}.` }]);
    } catch (err) { if (!vivaOb(mia)) return; return errorOb(err, pintarObras); }
    const o = d.obra;
    S.hooks.titulo(KICKER, `Costo · ${o.obra || id}`);
    if (S.obras.bajar) return pintarBajar(o, S.obras.bajar, mia);
    subOb(`<b>${esc(o.obra || id)}</b>${o.cliente ? ` · ${esc(o.cliente)}` : ""} · ${esc(ESTADO_OBRA[o.estado] || o.estado || "")}`);
    S.obras.piezas = [];
    // cada número del real que baja: su botón guarda el índice de la pieza
    const bajarBtn = (valor, bajar, titulo, signo) => {
      if (valor == null) return `<span class="ct-num">—</span>`;
      if (!Array.isArray(bajar) || !bajar.length) return `<span class="ct-num">${fmtNeg(valor)}</span>`;
      const i = S.obras.piezas.push({ titulo, valor: num(valor), bajar }) - 1;
      return `<button type="button" class="ct-ob-bajar ct-num" data-bajar="${i}" title="Ver sus asientos">${fmtNeg(valor)}</button>`;
    };
    const conceptos = Array.isArray(d.conceptos) ? d.conceptos : [];
    const difTxt = v => v == null ? "—" : `<span class="${num(v) < 0 ? "bad-txt" : "ok-txt"}">${fmtSigno(v)}</span>`;
    const filasC = conceptos.map(c => {
      const est = c.concepto === "mano_obra_estandar";
      const et = `${esc(c.etiqueta || c.concepto)}${est ? ` ${pill("estándar, no real", "warn")}` : ""}${c.concepto === "mano_obra_real" ? ` ${pill("real", "ok")}` : ""}${c.nota ? `<small>${esc(c.nota)}</small>` : ""}${c.concepto === "mano_obra_real" && (num(c.jornales) || num(c.nomina)) ? `<small>jornales <span class="ct-num">${fmt(c.jornales)}</span> · nómina <span class="ct-num">${fmt(c.nomina)}</span>${c.horas != null ? ` · ${horasTxt(c.horas)}` : ""}</small>` : ""}${est && c.horas != null ? `<small>${horasTxt(c.horas)}${c.burden_estandar_pct != null ? ` · burden ${pctTxt(c.burden_estandar_pct)}` : ""}</small>` : ""}`;
      return { clase: `ct-ob-${c.nivel || "concepto"}${est ? " ct-ob-est" : ""}`, celdas: [et, c.estimado == null ? "—" : fmtNeg(c.estimado), bajarBtn(c.real, c.bajar, c.etiqueta || c.concepto),
        c.estandar == null ? "—" : `<span class="ct-ob-estnum">${fmtNeg(c.estandar)}</span>`, c.nivel === "detalle" || c.concepto === "ingreso" ? "—" : difTxt(c.diferencia)] };
    });
    // el margen, estimado y real (la base los da; aquí solo se ponen juntos)
    filasC.push({ clase: "ct-ob-margen", celdas: ["Margen", `${fmtNeg(o.margen_estimado)}<small>${pctTxt(o.margen_estimado_pct)}</small>`, `${fmtNeg(o.margen_real)}<small>${pctTxt(o.margen_real_pct)}</small>`, "—", "—"] });
    const cob = `<p class="ct-ob-cobertura"><b class="ct-num">${horasTxt(o.horas_con_pago_real)}</b> con pago real · <b class="ct-num">${horasTxt(o.horas_estandar)}</b> a estándar${num(o.horas_dueno) ? ` · ${horasTxt(o.horas_dueno)} del dueño (van aparte)` : ""}${num(o.horas_antes_libro) ? ` · ${horasTxt(o.horas_antes_libro)} de antes del libro (en QuickBooks)` : ""}${num(o.horas_sin_aprobar) ? ` · ${horasTxt(o.horas_sin_aprobar)} sin aprobar` : ""}</p>`;
    const he = num(o.horas_estimadas), hr = num(o.horas_reales) || 0, uso = he ? Math.round(hr / he * 100) : null;
    const horasEst = `<div class="ct-ob-horas"><p><b class="ct-num">${horasTxt(hr)}</b> reales${he ? ` de <b class="ct-num">${horasTxt(he)}</b> estimadas (${uso} %)` : " · sin horas estimadas"}${num(o.horas_co) ? ` · ${horasTxt(o.horas_co)} de CO` : ""}${o.tarifa_estimada != null ? ` · tarifa estimada <span class="ct-num">${fmt(o.tarifa_estimada)}</span>/h (escenario ${esc(o.escenario || "—")})` : ""}</p>
      ${he ? `<div class="ct-ob-barra-h${uso > 100 ? " pasa" : ""}" role="img" aria-label="${uso} % de las horas estimadas"><span style="width:${Math.min(uso, 100)}%"></span></div>` : ""}</div>`;
    const parcial = o.parcial ? `<p class="ct-aviso warn"><b>Parcial:</b> ${esc(o.parcial_por || "la obra ya andaba antes del libro")}. Lo de antes del ${fechaLarga(o.libro_desde)} está en QuickBooks: este costo no es el de toda la obra.</p>` : "";
    const avisosO = (Array.isArray(d.avisos) ? d.avisos : Array.isArray(o.avisos) ? o.avisos : []).map(t => `<li class="ct-aviso warn">${esc(t)}</li>`).join("");
    const porCuenta = (d.por_cuenta || []).map(c => ({ celdas: [`<span class="ct-num">${esc(c.cuenta)}</span> ${esc(c.nombre || "")}${c.jornal ? ` ${pill("jornales", "cu")}` : ""}`, bajarBtn(c.real, c.bajar, `${c.cuenta} ${c.nombre || ""}${c.jornal ? " · jornales" : ""}`), esc(c.asientos == null ? "—" : c.asientos)] }));
    const porCo = (d.por_co || []).map(c => ({ celdas: [`${esc(c.etiqueta || c.co || "Base")}${c.alcance != null ? `<small>estimado del CO <span class="ct-num">${fmt(typeof c.alcance === "object" ? c.alcance.monto : c.alcance)}</span></small>` : ""}`, horasTxt(c.horas), fmt(c.mano_obra_real),
      num(c.mano_obra_estandar) ? `<span class="ct-ob-estnum">${fmt(c.mano_obra_estandar)}</span>` : fmt(c.mano_obra_estandar), fmt(c.material_real), fmt(c.costo_real), fmt(c.ingreso_libro)] }));
    const porFase = (d.por_fase || []).map(f => ({ celdas: [esc(f.etiqueta || f.fase || "Sin fase"), horasTxt(f.horas), horasTxt(f.horas_con_pago_real), fmt(f.mano_obra_real), horasTxt(f.horas_estandar),
      num(f.mano_obra_estandar) ? `<span class="ct-ob-estnum">${fmt(f.mano_obra_estandar)}</span>` : fmt(f.mano_obra_estandar)] }));
    const cc = d.por_cost_code || {};
    const ccHTML = cc.hay && Array.isArray(cc.filas) && cc.filas.length
      ? tablaOb([{ t: "Código" }, { t: "Horas", r: true }, { t: "Real", r: true }, { t: "Estimado", r: true }], cc.filas.map(f => ({ celdas: [`${esc(f.cost_code || f.codigo || "")}${f.etiqueta || f.nombre ? `<small>${esc(f.etiqueta || f.nombre)}</small>` : ""}`, f.horas == null ? "—" : horasTxt(f.horas), fmt(f.real != null ? f.real : f.costo_real), f.estimado == null ? "—" : fmt(f.estimado)] })))
      : `<p class="ct-vacio ct-ob-sincc">${esc(cc.nota || "Todavía no hay nada capturado con código en esta obra: se compara por obra y por cuenta.")}</p>`;
    const cober = (d.cobertura || []).map(p => ({ celdas: [`${esc(p.persona || "")}${p.es_dueno ? ` ${pill("dueño: va aparte")}` : ""}${p.tarifa != null ? `<small>tarifa <span class="ct-num">${fmt(p.tarifa)}</span>/h</small>` : ""}`, horasTxt(p.horas), horasTxt(p.horas_con_pago_real), fmt(p.pagado),
      horasTxt(p.horas_estandar), p.estandar == null ? "—" : `<span class="ct-ob-estnum">${fmt(p.estandar)}</span>`, horasTxt(p.horas_sin_aprobar)] }));
    const reps = (d.repartos || []).map(r => ({ clase: r.estado === "deshecho" ? "ct-ob-deshecho" : "", celdas: [`${fechaLarga(r.fecha_pago)} · ${esc(r.persona || "")}${r.estado === "deshecho" ? ` ${pill("deshecho", "warn")}` : ""}<small>${esc(rangoCorto(r.desde, r.hasta))} · pago de <span class="ct-num">${fmt(r.monto)}</span> por ${horasTxt(r.horas)}</small>`,
      horasTxt(r.horas_obra), fmt(r.monto_obra), r.asiento_id ? asientoBtn(r.asiento_id, r.asiento) : esc(r.asiento || "—")] }));
    const seccion = (t, html, extra) => `<section class="ct-card ct-ob-sec"${extra || ""}><h2>${esc(t)}</h2>${html}</section>`;
    obCuerpo().innerHTML = `<section class="ct-card ct-ob-det" id="ct-ob-det">
        <div class="ct-cab"><h2>${esc(o.obra || id)}</h2>${pill(ESTADO_OBRA[o.estado] || o.estado || "—", terminada(o) ? "" : "ok")}${o.parcial ? pill("parcial", "warn") : ""}</div>
        <p class="ct-nota">${esc([o.cliente, o.tipo].filter(Boolean).join(" · "))}${o.libro_desde ? ` · en el libro desde el ${fechaLarga(o.libro_desde)}` : ""}</p>
        <div class="ct-kpis cuatro">
          ${kpiHTML("Contrato", fmt(o.contrato))}
          ${kpiHTML("Facturado", fmt(o.ingreso_libro), "en el libro")}
          ${kpiHTML("Costo real", fmt(o.costo_real), num(o.mano_obra_estandar) ? `+ ${fmt(o.mano_obra_estandar)} estándar` : "pagado y en el libro")}
          ${kpiHTML("Margen real", pctTxt(o.margen_real_pct), o.margen_real == null ? "" : fmtNeg(o.margen_real))}
        </div>
        ${parcial}${cob}${horasEst}
        ${avisosO ? `<ul class="ct-jr-avisos">${avisosO}</ul>` : ""}
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-ob-volver">‹ Todas las obras</button></div>
      </section>` + avisosCtlHTML(avisos) +
      seccion("Estimado contra real", `${tablaOb([{ t: "Concepto" }, { t: "Estimado", r: true }, { t: "Real", r: true }, { t: "Estándar", r: true }, { t: "Diferencia", r: true }], filasC, "ct-ob-conceptos")}
        <p class="ct-nota">La mano de obra real es lo pagado y repartido; la estándar son las horas que aún no tienen pago, a la tarifa del equipo con el burden: <b>no está en el libro</b> y solo se suma para comparar. La diferencia es lo estimado menos lo gastado: en verde lo que sobra, en rojo lo que se pasa. Toca un número del real para ver sus asientos.</p>`, ` id="ct-ob-conceptos"`) +
      seccion("Por cuenta", porCuenta.length ? tablaOb([{ t: "Cuenta" }, { t: "Real", r: true }, { t: "Asientos", r: true }], porCuenta) : `<p class="ct-vacio">Ningún costo en el libro con esta obra todavía.</p>`, ` id="ct-ob-cuentas"`) +
      seccion("Base y CO, aparte", porCo.length ? tablaOb([{ t: "Base o CO" }, { t: "Horas", r: true }, { t: "Mano de obra real", r: true }, { t: "Estándar", r: true }, { t: "Material", r: true }, { t: "Costo real", r: true }, { t: "Facturado", r: true }], porCo) : `<p class="ct-vacio">Sin horas ni costos con CO.</p>`, ` id="ct-ob-co"`) +
      seccion("Por fase", porFase.length ? tablaOb([{ t: "Fase" }, { t: "Horas", r: true }, { t: "Con pago real", r: true }, { t: "Mano de obra real", r: true }, { t: "A estándar", r: true }, { t: "Estándar", r: true }], porFase) : `<p class="ct-vacio">Sin horas reportadas con fase.</p>`, ` id="ct-ob-fase"`) +
      seccion("Por cost code", ccHTML, ` id="ct-ob-cc"`) +
      seccion("Quién trabajó", cober.length ? tablaOb([{ t: "Persona" }, { t: "Horas", r: true }, { t: "Con pago real", r: true }, { t: "Pagado", r: true }, { t: "A estándar", r: true }, { t: "Estándar", r: true }, { t: "Sin aprobar", r: true }], cober) : `<p class="ct-vacio">Nadie ha reportado horas en esta obra.</p>`, ` id="ct-ob-quien"`) +
      seccion("Pagos repartidos a esta obra", reps.length ? tablaOb([{ t: "Pago" }, { t: "Horas aquí", r: true }, { t: "Le tocó", r: true }, { t: "Asiento", r: true }], reps) : `<p class="ct-vacio">Todavía ningún pago de mano de obra repartido a esta obra.</p>`, ` id="ct-ob-repartos"`);
    $("ct-ob-volver").addEventListener("click", () => { S.obras.sel = null; pintarObras(); });
    obCuerpo().querySelectorAll("[data-bajar]").forEach(b => b.addEventListener("click", () => { S.obras.bajar = S.obras.piezas[Number(b.dataset.bajar)]; window.scrollTo(0, 0); pintarObras(); }));
    obCuerpo().querySelectorAll(".ct-asiento-btn").forEach(b => b.addEventListener("click", () => ir("estados", { cuenta: null, asiento: b.dataset.asiento })));
  }
  // La consulta de un pedazo de «bajar» (la llave de c4): solo v_libro, con sus filtros (cuenta, obra, asientos que entran o no)
  function consultaBajar(pz) {
    const f = (pz && pz.filtros) || {}, lista = v => (Array.isArray(v) ? v : [v]).map(x => enc(String(x))).join(",");
    const q = ["select=asiento_id,numero,orden,fecha,descripcion,memo,cuenta,cuenta_nombre,monto,proyecto_id"];
    if (f.cuenta != null) q.push(Array.isArray(f.cuenta) ? `cuenta=in.(${lista(f.cuenta)})` : `cuenta=eq.${enc(f.cuenta)}`);
    if (f.proyecto_id != null) q.push(`proyecto_id=eq.${enc(f.proyecto_id)}`);
    if (f.asiento_id != null) q.push(Array.isArray(f.asiento_id) ? `asiento_id=in.(${lista(f.asiento_id)})` : `asiento_id=eq.${enc(f.asiento_id)}`);
    if (Array.isArray(f.asiento_id_no) && f.asiento_id_no.length) q.push(`asiento_id=not.in.(${lista(f.asiento_id_no)})`);
    q.push("order=fecha.asc,numero.asc,orden.asc");
    return `v_libro?${q.join("&")}`;
  }
  // Lo que suma un número del real: sus líneas del libro, cada una con su asiento (se abre en Estados). Si no suman la cifra, rojo
  async function pintarBajar(o, b, mia) {
    cargandoOb();
    let lineas = [];
    try {
      const piezas = (b.bajar || []).filter(pz => (pz.vista || "v_libro") === "v_libro");
      if (piezas.length !== (b.bajar || []).length) throw errorControl("No se puede bajar a esta cifra", [{ vista: "bajar", detalle: "La base pidió leer algo que no es el libro: no se lee." }]);
      const res = await Promise.all(piezas.map(pz => DB._leer(consultaBajar(pz)).then(ls => ls.map(l => ({ ...l, _signo: Number(pz.signo) === -1 ? -1 : 1 })))));
      if (!vivaOb(mia)) return;
      lineas = res.flat();
    } catch (err) { if (!vivaOb(mia)) return; return errorOb(err, pintarObras); }
    const suma = lineas.reduce((s, l) => s + cent2(l.monto) * l._signo, 0);
    const cuadra = suma === Math.round((b.valor || 0) * 100);
    subOb(`<b>${esc(o.obra || o.proyecto_id)}</b> · ${esc(b.titulo)} · <span class="ct-num">${fmtNeg(b.valor)}</span>`);
    const filas = lineas.map(l => ({ celdas: [`<span class="ct-num">${fechaLarga(l.fecha)}</span> ${asientoBtn(l.asiento_id, l.numero)} ${esc(l.descripcion || "")}${l.memo ? `<small>${esc(l.memo)}</small>` : ""}`, `<span class="ct-num">${esc(l.cuenta)}</span> ${esc(l.cuenta_nombre || "")}`, fmtNeg(cent2(l.monto) * l._signo / 100)] }));
    obCuerpo().innerHTML = `<section class="ct-card ct-ob-bajada" id="ct-ob-bajada">
        <div class="ct-cab"><h2>${esc(b.titulo)} · ${esc(o.obra || "")}</h2></div>
        ${cuadra ? `<p class="ct-aviso ok">${plural(lineas.length, "línea del libro suma", "líneas del libro suman")} <b class="ct-num">${fmtNeg(suma / 100)}</b>: lo mismo que la cifra.</p>`
          : `<p class="ct-aviso bad" role="alert">Lo que baja suma <b class="ct-num">${fmtNeg(suma / 100)}</b> y la cifra dice <b class="ct-num">${fmtNeg(b.valor)}</b>: no cuadra. No te fíes de esta cifra y avisa.</p>`}
        ${filas.length ? tablaOb([{ t: "Asiento" }, { t: "Cuenta" }, { t: "Monto", r: true }], filas) : `<p class="ct-vacio">Ninguna línea del libro.</p>`}
        <p class="ct-nota">Toca un asiento para verlo entero, con su papel, en Estados.</p>
        <div class="ct-acciones"><button type="button" class="accion secundaria" id="ct-ob-volver">‹ ${esc(o.obra || "La obra")}</button></div>
      </section>`;
    $("ct-ob-volver").addEventListener("click", () => { S.obras.bajar = null; pintarObras(); });
    obCuerpo().querySelectorAll(".ct-asiento-btn").forEach(x => x.addEventListener("click", () => ir("estados", { cuenta: null, asiento: x.dataset.asiento })));
  }
  const cargandoOb = txt => { const c = obCuerpo(); if (c) c.innerHTML = `<div class="ct-card ct-cargando">${esc(txt || "Cargando…")}</div>`; };

  // ---------- Repartos: el historial con «Deshacer» ----------
  async function pintarObRepartos(mia) {
    let filas, ctl;
    try {
      [filas, ctl] = await Promise.all([
        DB._leer("v_jornal_repartos?select=*&order=creado_el.desc"),
        DB._leer("v_jornal_control?select=*&order=orden.asc"),
        leerMfa()
      ]);
      if (!vivaOb(mia)) return;
    } catch (err) { if (!vivaOb(mia)) return; return errorOb(err, pintarObras); }
    const vivos = filas.filter(r => r.estado === "aplicado");
    subOb(`${plural(vivos.length, "pago repartido", "pagos repartidos")} · <span class="ct-num">${fmt(vivos.reduce((s, r) => s + (num(r.monto) || 0), 0))}</span>${filas.length > vivos.length ? ` · ${plural(filas.length - vivos.length, "deshecho", "deshechos")}` : ""}`);
    const rojos = (ctl || []).filter(f => f.ok !== true);
    obCuerpo().innerHTML = (rojos.length ? `<section class="ct-card"><ul class="ct-jr-avisos">${rojos.map(f => `<li class="ct-aviso ${f.nivel === "cuadre" ? "bad" : "warn"}">${esc(cap(String(f.cuadre || "").replace(/^jornal: /, "")))}: ${esc(f.detalle || "")}</li>`).join("")}</ul></section>` : "") +
      (filas.length ? `<div class="ct-ob-reps">${filas.map(repartoHTML).join("")}</div>` : `<section class="ct-card ct-vacio">Todavía ningún pago repartido por horas. Salen en la Bandeja como «Mano de obra».</section>`);
    obCuerpo().querySelectorAll(".ct-rep").forEach(card => {
      const r = filas.find(x => x.reparto_id === card.dataset.reparto);
      card.querySelectorAll(".ct-asiento-btn").forEach(b => b.addEventListener("click", () => ir("estados", { cuenta: null, asiento: b.dataset.asiento })));
      const d = card.querySelector("[data-deshacer]"); if (!d) return;
      d.addEventListener("click", () => {
        if (!mfaActivo()) { mostrarErrorForma(card, "Deshacer un reparto toca el libro: primero activa el código del teléfono (Conexiones y seguridad) y entra con él."); return; }
        montarForma(card, formaHTML(`Deshacer el reparto de ${esc(fmt(r.monto))} de ${esc(r.persona)}: el asiento ${esc(r.asiento || "")} se reversa (no se borra) y el pago vuelve a la Bandeja. Sus horas siguen aprobadas.`,
          campoHTML("motivo", "Por qué (queda escrito)", "textarea", "required"), "Deshacer el reparto"), v => {
          if (String(v.motivo || "").length < 3) { mostrarErrorForma(card, "Di por qué en unas palabras (al menos tres letras)."); return; }
          accionOb(card, "fn_jornal_deshacer", { p_reparto: r.reparto_id, p_motivo: v.motivo }, x => x && x.nota ? x.nota : "Reparto deshecho");
        });
      });
    });
  }
  function repartoHTML(r) {
    const suelto = r.estado === "aplicado" && r.asiento_vivo === false;
    const lineas = Array.isArray(r.lineas) ? r.lineas : [];
    return `<article class="ct-card ct-rep${r.estado === "deshecho" ? " deshecho" : ""}${suelto ? " suelto" : ""}" data-reparto="${esc(r.reparto_id)}">
      <div class="ct-cab"><h2>${esc(r.persona || "")} · <span class="ct-num">${fmt(r.monto)}</span></h2>${r.estado === "deshecho" ? pill("deshecho", "warn") : suelto ? pill("pago suelto", "bad") : pill("aplicado", "ok")}</div>
      <p class="ct-nota">Pago del ${fechaLarga(r.fecha_pago)} · ${esc(r.periodo_texto || rangoCorto(r.desde, r.hasta))} · ${horasTxt(r.horas)}${r.tarifa_sale != null ? ` · sale a <span class="ct-num">${fmt(r.tarifa_sale)}</span>/h` : ""} · ${plural(num(r.obras) || 0, "obra", "obras")}${r.asiento_id ? ` · asiento ${asientoBtn(r.asiento_id, r.asiento)}` : ""}</p>
      ${suelto ? `<p class="ct-aviso bad">El pago se des-casó en la Bandeja y este reparto quedó sin su asiento: ciérralo con «Deshacer» (no toca el libro) y vuelve a repartirlo allí.</p>` : ""}
      ${r.estado === "deshecho" ? `<p class="ct-aviso warn">Deshecho el ${esc(fechaHora(r.deshecho_el))}${r.deshecho_por_nombre ? ` por ${esc(r.deshecho_por_nombre)}` : ""}: «${esc(r.deshecho_motivo || "")}»${r.reverso ? ` · reverso ${r.reverso_id ? asientoBtn(r.reverso_id, r.reverso) : esc(r.reverso)}` : ""}.</p>` : ""}
      ${lineas.length ? `<details class="ct-rep-det"><summary>Cómo se repartió (${plural(lineas.length, "línea", "líneas")})</summary>${tablaOb([{ t: "Obra" }, { t: "Horas", r: true }, { t: "Dólares", r: true }],
        lineas.map(l => ({ celdas: [`${esc(l.obra || (l.proyecto_id ? l.proyecto_id : "Sin obra"))}${l.co ? `<small>${esc(l.co)}</small>` : ""}<small>a ${esc(l.cuenta || "")}</small>`, horasTxt(l.horas), fmt(l.monto)] })))}</details>` : ""}
      <p class="ct-sub">Repartido el ${esc(fechaHora(r.creado_el))}${r.creado_por_nombre ? ` por ${esc(r.creado_por_nombre)}` : ""}${num(r.horas_aprobadas) ? ` · ${plural(r.horas_aprobadas, "reporte de horas aprobado", "reportes de horas aprobados")}` : ""}</p>
      ${r.estado === "aplicado" ? `<div class="ct-acciones"><button type="button" class="accion secundaria" data-deshacer>Deshacer</button></div>` : ""}
      <div class="ct-form" hidden></div>
    </article>`;
  }

  // ---------- Personas: quién cobra por horas ----------
  async function pintarObPersonas(mia) {
    let filas;
    try {
      filas = await DB._leer("v_jornal_personas?select=*&order=registrada.desc,nombre.asc");
      if (!vivaOb(mia)) return;
    } catch (err) { if (!vivaOb(mia)) return; return errorOb(err, pintarObras); }
    const act = filas.filter(p => p.registrada && p.activa);
    subOb(`${plural(act.length, "persona cobra", "personas cobran")} por horas${filas.some(p => !p.registrada) ? ` · ${plural(filas.filter(p => !p.registrada).length, "con horas sin dar de alta", "con horas sin dar de alta")}` : ""}`);
    obCuerpo().innerHTML = filas.length ? `<div class="ct-ob-pers">${filas.map(personaHTML).join("")}</div>
        ${ayudaHTML(`<p class="ct-nota">Dar de alta a alguien dice: «sus pagos por Zelle se reparten por sus horas». La base lo reconoce por cómo escribe el banco su nombre en la descripción (el patrón). Si el banco lo escribe distinto, cambia el patrón; si deja de cobrar así, dalo de baja (lo ya repartido se queda).</p>`, "¿Cómo funciona?")}`
      : `<section class="ct-card ct-vacio">Nadie de la cuadrilla tiene horas en los últimos 90 días.</section>`;
    obCuerpo().querySelectorAll(".ct-per").forEach(card => {
      const p = filas.find(x => x.usuario_id === card.dataset.usuario);
      const patron = (titulo, boton) => montarForma(card, formaHTML(titulo,
        `${campoHTML("patron", "Cómo lo escribe el banco (por ejemplo, su nombre y apellido)", "texto", `required value="${esc(patronLlano(p.patron))}"`)}
         <p class="ct-nota">Las palabras que trae la descripción del Zelle. Que no sean tan comunes que casen con cualquier pago.</p>`, boton),
        v => accionOb(card, "fn_jornal_persona", { p: { usuario_id: p.usuario_id, patron: v.patron, activa: true } }, x => x && x.nota_alta ? x.nota_alta : `${p.nombre}: guardado`));
      const alta = card.querySelector("[data-per-alta]"); if (alta) alta.addEventListener("click", () => patron(`Dar de alta a ${esc(p.nombre)}: sus pagos se reparten por sus horas`, "Dar de alta"));
      const pat = card.querySelector("[data-per-patron]"); if (pat) pat.addEventListener("click", () => patron(`El patrón de ${esc(p.nombre)}`, "Guardar el patrón"));
      const baja = card.querySelector("[data-per-baja]"); if (baja) baja.addEventListener("click", () => accionOb(card, "fn_jornal_persona", { p: { usuario_id: p.usuario_id, activa: false } }, () => `${p.nombre}: dado de baja (lo ya repartido se queda)`));
      const vuelve = card.querySelector("[data-per-vuelve]"); if (vuelve) vuelve.addEventListener("click", () => accionOb(card, "fn_jornal_persona", { p: { usuario_id: p.usuario_id, activa: true } }, () => `${p.nombre}: otra vez cobra por horas`));
    });
  }
  function personaHTML(p) {
    const estado = !p.registrada ? pill("sin dar de alta", "warn") : p.activa ? pill("cobra por horas", "ok") : pill("de baja");
    return `<article class="ct-card ct-per" data-usuario="${esc(p.usuario_id)}">
      <div class="ct-cab"><h2>${esc(p.nombre || "")}</h2>${estado}</div>
      <p class="ct-nota">${p.registrada && p.patron ? `Se reconoce por «<b>${esc(patronLlano(p.patron))}</b>» · ` : ""}${p.tarifa != null ? `tarifa <span class="ct-num">${fmt(p.tarifa)}</span>/h` : "sin tarifa en Costos del equipo"}${p.cuenta ? ` · va a ${esc(p.cuenta)}` : ""}${num(p.horas_90_dias) ? ` · ${horasTxt(p.horas_90_dias)} en 90 días` : ""}${num(p.horas_sin_pago) ? ` · ${horasTxt(p.horas_sin_pago)} sin pago` : ""}</p>
      ${p.registrada ? `<p class="ct-sub">${num(p.pagos_pendientes) ? `<b>${plural(p.pagos_pendientes, "pago espera", "pagos esperan")}</b> en la Bandeja (<span class="ct-num">${fmt(p.pagos_pendientes_monto)}</span>) · ` : ""}${plural(num(p.repartos) || 0, "pago repartido", "pagos repartidos")} · <span class="ct-num">${fmt(p.repartido)}</span>${p.ultimo_reparto ? ` · el último el ${esc(fechaHora(p.ultimo_reparto))}` : ""}</p>` : ""}
      ${p.nota ? `<p class="ct-nota">${esc(p.nota)}</p>` : ""}
      <div class="ct-acciones">${!p.registrada ? `<button type="button" class="accion" data-per-alta>Dar de alta</button>`
        : p.activa ? `<button type="button" class="accion secundaria" data-per-patron>Cambiar el patrón</button><button type="button" class="accion secundaria" data-per-baja>Dar de baja</button>`
        : `<button type="button" class="accion secundaria" data-per-vuelve>Volver a dar de alta</button>`}</div>
      <div class="ct-form" hidden></div>
    </article>`;
  }

  const PAGINAS = { resumen: pintarResumen, bancos: pintarBancos, bandeja: pintarBandeja, conciliar: pintarConciliar, movimientos: pintarMovimientos, estados: pintarEstados, obras: pintarObras, cierre: pintarCierre, cobros: pintarCobros, conexiones: pintarConexiones };

  // ---------- Lo que la app llama (el contrato con js/app.js) ----------
  window.MXP_CONTA = {
    // paginas(): la lista ordenada de páginas [{ k, nombre, svg }] para el lateral de la app
    paginas: () => ORDEN.map(k => ({ k, nombre: TITULOS[k], svg: ICONOS[k] })),
    // abrir({ titulo(kicker, titulo), avisar(msg, esError), pagina(k), volver(visible) }, pagina?): pinta la pantalla en #conta-raiz;
    // con `pagina` abre esa, si no la última (o «resumen»). pagina(k) se llama en cada cambio de página y volver(v) en cada pintada
    abrir(hooks, pagina) {
      S.hooks = Object.assign({ titulo() {}, avisar() {}, pagina() {}, volver() {} }, hooks || {});
      if (!DB || typeof DB._rpc !== "function" || typeof DB._leer !== "function") {
        const r = raiz();
        if (r) r.innerHTML = `<div class="ct-card ct-rojo" role="alert"><h2>Falta la conexión</h2><p>js/db.js no trae _leer y _rpc: recarga la app (si sigue, la versión de db.js es vieja).</p></div>`;
        return;
      }
      armar();
      // la vuelta del banco (OAuth de Plaid) abre Conexiones y seguridad, donde vive su tarjeta
      const vuelta = !!new URLSearchParams(location.search).get("oauth_state_id");
      ir(vuelta ? "conexiones" : PAGINAS[pagina] ? pagina : S.pagina);
      if (vuelta) reanudarLink();
    },
    // «←» de la app: true si la pantalla tenía algo que cerrar (la conciliación abierta, el asiento o el mayor de los estados)
    atras() {
      if (S.conc) { S.conc = null; S.hooks.titulo(KICKER, TITULOS.conciliar); pintarConciliar(); return true; }
      // la bajada de los estados: asiento → mayor → el estado
      if (S.pagina === "estados" && S.est.asiento) { S.est.asiento = null; pintarEstados(); return true; }
      if (S.pagina === "estados" && S.est.cuenta) { S.est.cuenta = null; pintarEstados(); return true; }
      // (fase 9) el costo por obra: lo bajado a los asientos → la obra → la lista
      if (S.pagina === "obras" && S.obras.bajar) { S.obras.bajar = null; pintarObras(); return true; }
      if (S.pagina === "obras" && S.obras.sel) { S.obras.sel = null; pintarObras(); return true; }
      return false;
    },
    ir,
    _estado: S
  };
})();
