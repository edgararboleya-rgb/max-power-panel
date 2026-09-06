// ============================================================
// Max Power — Panel de Proyectos (aplicación real)
//
// Los datos viven en la base de datos en la nube (Supabase) y
// se comparten al instante entre todo el equipo. La conexión
// está en js/db.js; aquí vive la interfaz.
//
// Roles (los decide la base de datos, no la pantalla):
//   dueño  → ve finanzas y edita todo
//   campo / license → proyectos, fases, horas y pendientes,
//                     sin un solo dato de dinero
// ============================================================

(function () {
  "use strict";

  const DB = window.MXP_DB;

  // ---------- Constantes de la app ----------
  // Íconos eléctricos dibujados a medida: trazo con el gradiente firma
  // y nodos de circuito — la marca "electricidad + tecnología"
  const GRAD = (id) => `<defs><linearGradient id="${id}" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="#1B3C8C"/><stop offset=".45" stop-color="#2A5BD7"/>
    <stop offset=".78" stop-color="#22E8E0"/><stop offset="1" stop-color="#8CF06A"/>
  </linearGradient></defs>`;
  const ICONO_SVG = {
    comercial: `<svg viewBox="0 0 48 48" aria-hidden="true">${GRAD("g-com")}
      <g fill="none" stroke="url(#g-com)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
        <path d="M8 42V16h14v26"/><path d="M22 42V8h18v34"/><path d="M4 42h40"/>
        <path d="M27 14h3M34 14h3M27 21h3M34 21h3M27 28h3M34 28h3M12 22h4M12 29h4"/>
        <path d="M14 42v-6h5v6"/>
      </g>
      <circle cx="41" cy="7" r="2.4" fill="#22E8E0"/></svg>`,
    residencial: `<svg viewBox="0 0 48 48" aria-hidden="true">${GRAD("g-res")}
      <g fill="none" stroke="url(#g-res)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
        <path d="M6 25 24 9l18 16"/><path d="M11 23v19h26V23"/>
      </g>
      <path d="M26 21l-8 11h6l-4 9 11-13h-6l4-7z" fill="#22E8E0"/></svg>`,
    servicio: `<svg viewBox="0 0 48 48" aria-hidden="true">${GRAD("g-ser")}
      <path d="M24 4l16 9v20l-16 9-16-9V13z" fill="none" stroke="url(#g-ser)"
        stroke-width="2.4" stroke-linejoin="round"/>
      <path d="M27 13l-10 14h7l-5 12 13-15h-7l5-11z" fill="#22E8E0"/></svg>`
  };
  const TIPOS = {
    comercial:   { etiqueta: "Proyectos Comerciales",   icono: ICONO_SVG.comercial },
    residencial: { etiqueta: "Proyectos Residenciales", icono: ICONO_SVG.residencial },
    servicio:    { etiqueta: "Servicios",               icono: ICONO_SVG.servicio }
  };
  const ESTADOS = {
    estimando:   { etiqueta: "Estimando" },
    enviado:     { etiqueta: "Enviado" },
    aprobado:    { etiqueta: "Aprobado" },
    ejecucion:   { etiqueta: "En ejecución" },
    pausa:       { etiqueta: "En pausa" },
    completado:  { etiqueta: "Completado" },
    no_aprobado: { etiqueta: "No aprobado" }
  };
  const DOT = { estimando: "gris", enviado: "navy", aprobado: "azul", ejecucion: "cyan", pausa: "amarillo", completado: "lima", no_aprobado: "rojo" };
  const FASES = [
    { clave: "mobilizacion", etiqueta: "Inicio / Movilización" },
    { clave: "rough",        etiqueta: "Rough-in" },
    { clave: "insp-rough",   etiqueta: "Inspección de rough" },
    { clave: "trim",         etiqueta: "Trim / Terminación" },
    { clave: "insp-final",   etiqueta: "Inspección final" }
  ];
  const DESC_ETAPA = {
    ejecucion: "Obras activas con fases en curso",
    aprobado: "Aceptados, pendientes de arrancar",
    enviado: "Propuestas esperando respuesta",
    estimando: "Cotizándose — todavía sin precio enviado",
    pausa: "Detenidos temporalmente",
    completado: "Terminados y cerrados",
    no_aprobado: "No salieron — fuera de las estadísticas"
  };
  const ORDEN_ETAPAS = ["ejecucion", "aprobado", "enviado", "estimando", "pausa", "completado", "no_aprobado"];
  const ROL_ETIQUETA = { dueno: "Dueño", campo: "Campo", license: "License Holder" };
  // usuario corto → email de la cuenta
  const EMAILS = {
    edgar: "edgararboleya@mxpes.com",
    flavia: "flavia.mestre28@gmail.com"
  };

  // El service worker recibe las notificaciones aunque la app esté cerrada
  if ("serviceWorker" in navigator && location.protocol.startsWith("http")) {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }

  // ---------- Estado en memoria ----------
  let state = null;    // lo que devuelve DB.cargarTodo()
  let usuario = null;  // { nombre, rol, finanzas, editar }
  let tipoActivo = null;
  let etapaActiva = null;
  let proyectoActivo = null;  // id del proyecto abierto en su propia pantalla
  let textoBusqueda = "";
  let calAno, calMes, calDiaSel;

  const $ = id => document.getElementById(id);
  const $login = $("vista-login");
  const $app = $("vista-app");
  const $home = $("vista-home"), $vEtapas = $("vista-etapas"), $vLista = $("vista-lista");
  const $vHoras = $("vista-horas"), $vCal = $("vista-calendario");
  const $vDetalle = $("vista-detalle"), $detalle = $("detalle");
  const $vMat = $("vista-materiales");
  const $categorias = $("categorias"), $resumen = $("resumen");
  const $etapas = $("etapas"), $lista = $("lista"), $buscador = $("buscador");
  const $kicker = $("kicker"), $titulo = $("titulo-vista");
  const $btnVolver = $("btn-volver"), $btnNuevo = $("btn-nuevo"), $btnSalir = $("btn-salir");
  const $usuarioChip = $("usuario-chip");
  const $modal = $("modal-nuevo"), $formNuevo = $("form-nuevo");
  const $formLogin = $("form-login"), $loginError = $("login-error");
  const $formHoras = $("form-horas"), $btnHoras = $("btn-horas"), $btnCal = $("btn-calendario");

  for (const id of ["logo", "logo-login"]) {
    const el = $(id);
    if (el && window.MAXPOWER_LOGO) el.src = window.MAXPOWER_LOGO;
    // En pantalla grande va el icono de 512 px (nítido); el de 200 px se ve blando
    if (el && window.matchMedia && window.matchMedia("(min-width: 1024px)").matches) el.src = "assets/icon-512.png";
  }

  const dinero = new Intl.NumberFormat("en-US", {
    style: "currency", currency: "USD", minimumFractionDigits: 2
  });
  const fmt = n => (n === null || n === undefined ? "—" : dinero.format(n));
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const sinMontos = t => (usuario && usuario.finanzas)
    ? t : String(t ?? "").replace(/\$\s?[\d][\d,.]*/g, "$•••");
  const facturasPendientes = p => (p.facturas || []).filter(f => !f.pagada);
  const chipHTML = clave => {
    const e = ESTADOS[clave] || { etiqueta: clave };
    return `<span class="chip"><span class="dot ${DOT[clave] || "navy"}"></span>${esc(e.etiqueta)}</span>`;
  };
  // Solo enlaces reales: nada de esquemas raros (javascript:, data:) en los href
  const urlSegura = u => (/^https?:\/\//i.test(String(u || "").trim()) ? String(u).trim() : "");
  // Idioma de la interfaz: las fechas se pintan en el idioma elegido
  const EN_APP = localStorage.getItem("mxp_idioma") === "en";
  const LOCALE = EN_APP ? "en-US" : "es-US";
  const proyectos = () => (state ? state.proyectos : []);
  const eventos = () => (state ? state.eventos : []);
  // El calendario junta los eventos con las inspecciones programadas
  const eventosCal = () => eventos().concat(
    (state ? state.inspecciones || [] : [])
      // Las que salieron de un evento del calendario NO se repiten: ese
      // evento ya está en la lista con su hora, su gente y su nota
      .filter(i => i.fecha && i.resultado === "programada" && !i.eventoId)
      .map(i => ({
        id: "insp-" + i.id, fecha: i.fecha, hora: "",
        titulo: `🏛 Inspección ${i.tipo}`, proyecto: i.proyecto,
        nota: i.jurisdiccion ? "Jurisdicción: " + i.jurisdiccion : "",
        alerta: true
      })));
  const pendientesTodos = () => (state ? state.pendientes : []);
  const pendientesAbiertos = pid =>
    pendientesTodos().filter(p => !p.resuelto && (!pid || p.proyecto === pid));

  // ---------- Avisos de error / carga ----------
  function avisar(msg, esError) {
    let $t = $("toast");
    if (!$t) {
      $t = document.createElement("div");
      $t.id = "toast";
      document.body.appendChild($t);
    }
    $t.textContent = msg;
    $t.className = esError ? "toast error" : "toast";
    $t.hidden = false;
    clearTimeout($t._timer);
    $t._timer = setTimeout(() => { $t.hidden = true; }, 5000);
  }

  // ============================================================
  // ENTRADA — usuario y contraseña contra la base de datos
  // ============================================================
  $formLogin.addEventListener("submit", async e => {
    e.preventDefault();
    const d = new FormData($formLogin);
    const u = (d.get("usuario") || "").toString().trim().toLowerCase();
    const clave = (d.get("clave") || "").toString();
    const email = u.includes("@") ? u : (EMAILS[u] || `${u}@mxpes.com`);
    const $btn = $formLogin.querySelector(".btn-entrar");
    $btn.disabled = true;
    $btn.textContent = "Entrando…";
    try {
      await DB.entrar(email, clave);
      $loginError.hidden = true;
      $formLogin.reset();
      await arrancarApp();
    } catch (err) {
      $loginError.textContent = /invalid/i.test(err.message)
        ? "Usuario o contraseña incorrectos."
        : "No se pudo conectar: " + err.message;
      $loginError.hidden = false;
    } finally {
      $btn.disabled = false;
      $btn.textContent = "Entrar";
    }
  });

  async function arrancarApp() {
    $login.hidden = true;
    $app.hidden = false;
    $usuarioChip.textContent = "Cargando…";
    try {
      state = await DB.cargarTodo();
      quitarSinSenal();
      enviarColaHoras(); // por si quedó algún reporte esperando señal
    } catch (err) {
      if (esFalloDeRed(err)) {
        // Sin señal: la sesión NO se toca, solo se ofrece reintentar
        pantallaSinSenal(arrancarApp);
        return;
      }
      // Mismo criterio: solo se cierra la sesión si el token de verdad no
      // vale. Si es el servidor el que está mal, se ofrece reintentar.
      if (!esSesionMuerta(err)) {
        avisar("El servidor no contestó bien: " + err.message, true);
        pantallaSinSenal(arrancarApp);
        return;
      }
      avisar("Error cargando los datos: " + err.message, true);
      salirApp();
      return;
    }
    const perfil = state.perfil;
    if (!perfil) {
      avisar("Tu cuenta no tiene perfil asignado. Avísale a Edgar.", true);
      salirApp();
      return;
    }
    usuario = {
      id: perfil.id,
      nombre: perfil.nombre,
      rol: ROL_ETIQUETA[perfil.rol] || perfil.rol,
      finanzas: perfil.rol === "dueno",
      editar: perfil.rol === "dueno"
    };
    $usuarioChip.textContent = usuario.nombre;
    $("btn-chat").hidden = false;
    $("btn-asistente").hidden = false;
    arrancarChat();
    irHome();
  }

  function salirApp() {
    DB.salir();
    state = null;
    usuario = null;
    $("btn-chat").hidden = true;
    $("btn-asistente").hidden = true;
    if (chatTimer) { clearInterval(chatTimer); chatTimer = null; }
    $app.hidden = true;
    $login.hidden = false;
  }
  $btnSalir.addEventListener("click", salirApp);

  let recargaTurno = 0; // si hay dos recargas en vuelo, solo manda la última
  let vistaMarcada = false; // una sola marca de "estuve en la app" por sesión
  async function recargar(abrirId) {
    const turno = ++recargaTurno;
    if (!vistaMarcada) { vistaMarcada = true; DB.estuve(); }
    try {
      const nuevo = await DB.cargarTodo();
      if (turno !== recargaTurno) return;
      state = nuevo;
    } catch (err) {
      avisar("Error actualizando: " + err.message, true);
      return;
    }
    // Re-pinta la vista activa
    if (!$vDetalle.hidden) pintarDetalle();
    else if (!$vLista.hidden) pintarLista(abrirId);
    else if (!$vEtapas.hidden) pintarEtapas();
    else if (!$vCal.hidden) pintarCalendario();
    else if (!$vHoras.hidden) prepararHoras();
    else if (!$vMat.hidden) pintarMateriales();
    else if (!$("vista-checklist").hidden) pintarChecklist();
    else if (!$("vista-gastos").hidden) pintarGastos();
    else if (!$("vista-chat").hidden) refrescarChat(false);
    else if (!$("vista-asistente").hidden) { /* la conversación no se toca al recargar */ }
    else { pintarInicio(); pintarCategorias(); pintarResumen(); }
  }

  // ¿El error fue por falta de señal, o porque el servidor de verdad dijo que no?
  // Importa mucho: si es falta de señal NO se borra la sesión. Antes bastaba
  // abrir la app una vez en un ático para quedar deslogueado y tener que
  // teclear la contraseña en plena obra.
  // ¿El servidor dijo de verdad que la sesión no vale? Solo 400 y 401 lo
// dicen. Cualquier otra cosa (500, 502, 503, o ninguna respuesta) es que
// el servidor está mal, y por eso NO se puede cerrar la sesión de nadie.
function esSesionMuerta(err) {
  return !!err && (err.status === 400 || err.status === 401);
}

function esFalloDeRed(err) {
    const m = String((err && err.message) || err || "");
    return (err instanceof TypeError)
      || /failed to fetch|load failed|networkerror|network request failed|sin conexi|offline/i.test(m);
  }

  // Pantalla de "sin señal" con botón de reintentar, sin perder la sesión
  function pantallaSinSenal(reintentar) {
    let caja = document.getElementById("sin-senal");
    if (!caja) {
      caja = document.createElement("div");
      caja.id = "sin-senal";
      caja.className = "sin-senal";
      document.body.appendChild(caja);
    }
    caja.innerHTML = `
      <div class="sin-senal-caja">
        <div class="sin-senal-icono">📶</div>
        <h3>Sin señal</h3>
        <p>No se pudo conectar. Tu sesión sigue guardada — no hace falta volver a entrar.</p>
        <button type="button" class="accion" id="sin-senal-btn">Reintentar</button>
      </div>`;
    caja.hidden = false;
    document.getElementById("sin-senal-btn").addEventListener("click", () => {
      caja.hidden = true;
      reintentar();
    });
  }
  function quitarSinSenal() {
    const c = document.getElementById("sin-senal");
    if (c) c.hidden = true;
  }

  // ---------- Versión nueva publicada → recargar solo ----------
  // El casco (sw.js) toma el control en cuanto se instala; aquí la página se
  // recarga una sola vez para no seguir con los archivos viejos en pantalla.
  if ("serviceWorker" in navigator) {
    let habiaCasco = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (habiaCasco) { habiaCasco = false; location.reload(); }
      else habiaCasco = true;
    });
  }

  // ---------- Menú lateral (pantalla grande) ----------
  // Copia las losetas del inicio a una columna fija a la izquierda. Tocar una
  // entrada dispara la loseta original, así no hay dos caminos de código.
  const LATERAL_HOME_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11 12 4l9 7"/><path d="M5 10v10h5v-6h4v6h5V10"/></svg>';
  const LATERAL_PROY_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="8" height="7" rx="2"/><rect x="13" y="4" width="8" height="7" rx="2"/><rect x="3" y="13" width="8" height="7" rx="2"/><rect x="13" y="13" width="8" height="7" rx="2"/></svg>';
  let lateralVista = "home";
  function armarLateral() {
    const nav = $("lateral");
    if (!nav) return;
    const losetas = [...document.querySelectorAll(".botones-rapidos .btn-horas")];
    nav.innerHTML = `
      <button class="lat-item" data-lat="home">${LATERAL_HOME_SVG}<span>Inicio</span></button>
      <button class="lat-item" data-lat="proyectos">${LATERAL_PROY_SVG}<span>Proyectos</span></button>
      <div class="lat-sep"></div>` +
      losetas.map(b => `<button class="lat-item" data-lat="${b.id}"${b.hidden ? " hidden" : ""}>${b.querySelector(".tile-ico").innerHTML}<span>${esc(b.querySelector(".tile-txt").textContent)}</span></button>`).join("");
    nav.querySelectorAll(".lat-item").forEach(it => it.addEventListener("click", () => {
      const k = it.dataset.lat;
      if (k === "home") { irHome(); return; }
      if (k === "proyectos") { irHome(); const c = document.querySelector("#categorias [data-tipo]"); if (c) c.scrollIntoView({ behavior: "smooth", block: "start" }); return; }
      const orig = $(k); if (orig) orig.click();
    }));
    pintarLateral();
  }
  function pintarLateral() {
    const nav = $("lateral"); if (!nav) return;
    const activo = { home: "home", etapas: "proyectos", lista: "proyectos", detalle: "proyectos",
      horas: "btn-horas", calendario: "btn-calendario", checklist: "btn-checklist", materiales: "btn-materiales",
      gastos: "btn-gastos", estimador: "btn-estimador", levantamiento: "btn-levantamiento",
      propuesta: "btn-estimador", cierre: "btn-estimador", alcance: "proyectos" }[lateralVista] || "";
    nav.querySelectorAll(".lat-item").forEach(it => {
      it.classList.toggle("activo", it.dataset.lat === activo);
      const orig = it.dataset.lat.startsWith("btn-") ? $(it.dataset.lat) : null;
      if (orig) it.hidden = orig.hidden;   // el equipo no ve las losetas del dueño
    });
  }

  // ---------- Cambio de vista ----------
  function mostrar(vista, { kicker, titulo, volver, nuevo }) {
    lateralVista = vista;
    pintarLateral();
    $home.hidden = vista !== "home";
    $vEtapas.hidden = vista !== "etapas";
    $vLista.hidden = vista !== "lista";
    $vHoras.hidden = vista !== "horas";
    $vCal.hidden = vista !== "calendario";
    $vDetalle.hidden = vista !== "detalle";
    $vMat.hidden = vista !== "materiales";
    $("vista-checklist").hidden = vista !== "checklist";
    $("vista-gastos").hidden = vista !== "gastos";
    $("vista-estimador").hidden = vista !== "estimador";
    $("vista-levantamiento").hidden = vista !== "levantamiento";
    $("vista-propuesta").hidden = vista !== "propuesta";
    $("vista-cierre").hidden = vista !== "cierre";
    $("vista-alcance").hidden = vista !== "alcance";
    $("vista-chat").hidden = vista !== "chat";
    $("vista-asistente").hidden = vista !== "asistente";
    $kicker.textContent = kicker;
    $titulo.textContent = titulo;
    $btnVolver.hidden = !volver;
    $btnNuevo.hidden = !(nuevo && usuario && usuario.editar);
    window.scrollTo(0, 0);
  }

  // ============================================================
  // NIVEL 1 · HOME
  // ============================================================
  function irHome() {
    tipoActivo = null;
    etapaActiva = null;
    mostrar("home", { kicker: "Panel de proyectos", titulo: "Categorías", volver: false, nuevo: true });
    $("btn-gastos").hidden = !usuario.finanzas;
    $("btn-estimador").hidden = !usuario.finanzas;
    $("btn-levantamiento").hidden = !usuario.finanzas;
    armarLateral();   // después de decidir qué losetas ve este usuario
    pintarInicio();
    pintarCategorias();
    pintarResumen();
    refrescarInicio();
  }

  // Refresco silencioso: al volver al inicio, trae los datos frescos
  // de la nube y repinta (así nunca se queda un aviso viejo)
  let refrescandoInicio = false;
  function refrescarInicio() {
    if (refrescandoInicio) return;
    refrescandoInicio = true;
    // Mismo turno que recargar(): si mientras bajaban los datos hubo una
    // recarga más nueva, esta se descarta en vez de pisar lo fresco con lo viejo
    const turno = ++recargaTurno;
    DB.cargarTodo()
      .then(s => {
        if (turno !== recargaTurno) return;
        state = s;
        if (!$home.hidden) { pintarInicio(); pintarCategorias(); pintarResumen(); }
      })
      .catch(() => {})
      .finally(() => { refrescandoInicio = false; });
  }

  // ---------- El inicio inteligente ----------
  const hoyISO = () => {
    const h = new Date();
    return fechaISO(h.getFullYear(), h.getMonth(), h.getDate());
  };
  const diasDesde = iso => {
    if (!iso) return null;
    const [a, m, d] = String(iso).slice(0, 10).split("-").map(Number);
    return Math.floor((new Date() - new Date(a, m - 1, d)) / 86400000);
  };
  const nombreProyecto = id => {
    const p = proyectos().find(x => x.id === id);
    return p ? p.nombre : "";
  };

  function pintarInicio() {
    pintarInicioHoy();
    pintarInicioUrgentes();
    pintarInicioAvisos();
    pintarInicioEquipo();
    pintarInicioEmpresa();
    pintarInicioNotif();
  }


  // ---------- 📋 Licencia y seguros + 📖 guía rápida del código ----------
  // Guía de CAMPO: los números que se usan en la obra, con su artículo.
  // Base: NEC 2023 (FBC 8ª ed). Para casos raros, confirmar en NFPA LiNK.
  const NEC_SECCIONES = [
    { t: "🔌 Cable Romex (NM) — amperaje máximo", art: "310.16 (col. 60°C)", filas: [
      ["#14", "15 A"], ["#12", "20 A"], ["#10", "30 A"], ["#8", "40 A"], ["#6", "55 A"]] },
    { t: "🧵 THHN en tubería — amperaje (75°C)", art: "310.16", filas: [
      ["#12", "25 A"], ["#10", "35 A"], ["#8", "50 A"], ["#6", "65 A"], ["#4", "85 A"],
      ["#2", "115 A"], ["#1/0", "150 A"], ["#2/0", "175 A"], ["#4/0", "230 A"]] },
    { t: "🏠 Servicio o feeder de vivienda — calibre", art: "310.12", filas: [
      ["100 A", "#4 cobre · #2 aluminio"], ["125 A", "#2 cobre · #1/0 aluminio"],
      ["150 A", "#1 cobre · #2/0 aluminio"], ["200 A", "#2/0 cobre · #4/0 aluminio"]] },
    { t: "⛏ Zanjas — profundidad mínima", art: "300.5 (tabla)", filas: [
      ["PVC", '18"'], ["Cable directo (UF)", '24"'], ["Tubería metálica rígida", '6"'],
      ["Bajo driveway de vivienda", '18"'], ["Circuito 120V 20A con GFCI", '12"']] },
    { t: "🌍 Tierra — varillas y calibres", art: "250.53 · 250.66 · 250.122", filas: [
      ["Varillas", "2 de 8 ft (salvo que UNA mida <25Ω) · sepáralas 6 ft o más"],
      ["Cable a las varillas (GEC)", "nunca se exige más grueso que #6 cobre"],
      ["Tierra del equipo (EGC)", "breaker 15A→#14 · 20A→#12 · 30-60A→#10 · 100A→#8 · 200A→#6"]] },
    { t: "🚗 Cargadores EV — breaker y cable", art: "Art. 625 (carga continua ×125%)", filas: [
      ["Cargador de 32 A", "breaker 40 A · #8"],
      ["Cargador de 40 A", "breaker 50 A · #6"],
      ["Cargador de 48 A", "breaker 60 A · #6 THHN en tubería (Romex #6 NO llega)"],
      ["Receptáculo 14-50R", "lleva GFCI (NEC 2023)"]] },
    { t: "⚡ GFCI en vivienda (NEC 2023)", art: "210.8(A)", filas: [
      ["Va en", "baños · TODA la cocina · garaje · exterior · sótano · laundry · a 6 ft de cualquier fregadero"]] },
    { t: "🔥 AFCI", art: "210.12", filas: [
      ["Va en", "casi todos los circuitos 120V 15/20A de vivienda (cuartos, salas, cocina, laundry)"]] },
    { t: "🔲 Tomacorrientes — distancias", art: "210.52", filas: [
      ["Paredes", "ninguna a más de 6 ft de una toma (cada 12 ft)"],
      ["Countertop", 'todo tramo de 12" o más lleva toma · ninguna a más de 24" '],
      ["Baño", "a máximo 3 ft del lavamanos · circuito de 20 A dedicado"]] },
    { t: "🗄 Frente al panel — espacio libre", art: "110.26 · 240.24", filas: [
      ["Fondo", '36"'], ["Ancho", '30"'], ["Alto libre", "6.5 ft"],
      ["Breaker más alto", "máx 6 ft 7 in del piso"]] },
    { t: "📦 Box fill — pulgadas cúbicas por cable", art: "314.16", filas: [
      ["#14", "2.0 in³"], ["#12", "2.25 in³"], ["#10", "2.5 in³"],
      ["Dispositivo (toma/switch)", "cuenta DOBLE"], ["Tierras", "todas juntas = 1 (la mayor)"],
      ['Caja 4" sq × 2-1/8"', "30.3 in³"]] },
  ];
  function pintarInicioEmpresa() {
    const docs = state.docsEmpresa || [];
    const hoy = hoyISO();
    const filaDoc = d => {
      let chip = "";
      if (d.vence) {
        const dias = Math.round((Date.parse(d.vence) - Date.parse(hoy)) / 86400000);
        chip = dias < 0 ? `<span class="recibo-chip devolucion">VENCIDO ${esc(d.vence)}</span>`
          : dias <= 30 ? `<span class="recibo-chip devolucion">vence en ${dias} días</span>`
          : `<span class="recibo-chip leido">vence ${esc(d.vence)}</span>`;
      }
      const enlace = d.ruta
        ? `<a class="doc-link emp-ver" data-ruta="${esc(d.ruta)}" target="_blank" rel="noopener">📄 Ver</a>`
        : d.url ? `<a class="doc-link" href="${esc(d.url)}" target="_blank" rel="noopener">📄 Ver</a>`
        : `<span class="alcance-estado">sin archivo todavía</span>`;
      return `<div class="mat-item">
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(EN_APP ? (d.tituloEn || d.titulo) : d.titulo)}</span>
        </span>
        ${chip} ${enlace}
        ${usuario.editar ? `<button class="insp-borrar emp-borrar" data-id="${d.id}" title="Eliminar">🗑</button>` : ""}
      </div>`;
    };
    const formDueno = usuario.editar ? `
      <form class="cal-form" id="form-doc-empresa">
        <div class="modal-fila">
          <label>Documento
            <input name="titulo" type="text" required placeholder="Ej: COI actualizado 2027" autocomplete="off">
          </label>
          <label>Vence (opcional)
            <input name="vence" type="date">
          </label>
        </div>
        <label>Archivo PDF
          <input name="archivo" type="file" accept="application/pdf" required>
        </label>
        <button type="submit" class="accion secundaria">⬆ Subir documento de la empresa</button>
      </form>` : "";
    $("inicio-empresa").innerHTML = `
      <div class="inicio-card">
        <div class="inicio-card-titulo">📋 Licencia y seguros</div>
        ${docs.map(filaDoc).join("") || `<p class="cal-sin-eventos">Sin documentos todavía.</p>`}
        ${formDueno}
      </div>
      <div class="inicio-card">
        <details class="chk-det">
          <summary class="inicio-card-titulo" style="cursor:pointer">📖 Código eléctrico — guía de campo (NEC 2023)</summary>
          <p class="modal-nota">Los números que se usan en la obra, con su artículo al lado.
          El texto oficial se confirma en <a class="doc-link" href="https://link.nfpa.org" target="_blank" rel="noopener">NFPA LiNK</a>
          (Florida: FBC 8ª edición, base NEC 2023). Detectores de humo: FBC-R R314 / NFPA 72, no NEC.
          Para un caso raro o una discusión con un inspector: pregúntale a Claude y te da el artículo exacto con la frase textual.</p>
          ${NEC_SECCIONES.map(sec => `
          <details class="chk-det" style="margin:.3rem 0">
            <summary style="cursor:pointer"><strong>${esc(sec.t)}</strong> <span class="recibo-chip leido">NEC ${esc(sec.art)}</span></summary>
            ${sec.filas.map(f => `<div class="mat-item">
              <span class="alcance-info"><span class="alcance-titulo">${esc(f[0])}</span></span>
              <span class="alcance-estado" style="text-align:right"><strong>${esc(f[1])}</strong></span>
            </div>`).join("")}
          </details>`).join("")}
        </details>
      </div>
      ${(state.jurisdicciones || []).length ? `
      <div class="inicio-card">
        <details class="chk-det">
          <summary class="inicio-card-titulo" style="cursor:pointer">🏛 Permisos por jurisdicción</summary>
          <p class="modal-nota">Cómo se saca el permiso en cada condado donde trabajamos. Dime lo que aprendas en cada uno y lo voy anotando.</p>
          ${state.jurisdicciones.map(j => `<div class="mat-item">
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(j.condado)}</span>
              ${j.notas ? `<span class="alcance-estado">${esc(j.notas)}</span>` : ""}
              ${j.contacto ? `<span class="alcance-estado">☎ ${esc(j.contacto)}</span>` : ""}
            </span>
            ${j.portalUrl ? `<a class="doc-link" href="${esc(j.portalUrl)}" target="_blank" rel="noopener">🌐 Portal</a>` : ""}
          </div>`).join("")}
        </details>
      </div>` : ""}`;
    // enlaces firmados para los PDFs de la empresa
    const rutas = [...$("inicio-empresa").querySelectorAll(".emp-ver")].map(a => a.dataset.ruta);
    if (rutas.length) {
      DB.firmarFotos(rutas).then(firmas => {
        $("inicio-empresa").querySelectorAll(".emp-ver").forEach(a => {
          if (firmas[a.dataset.ruta]) a.href = firmas[a.dataset.ruta];
        });
      }).catch(() => avisar("No se pudieron cargar los documentos de la empresa — revisa la señal.", true));
    }
    $("inicio-empresa").querySelectorAll(".emp-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este documento de la empresa?")) return;
        try { await DB.eliminarDocEmpresa(btn.dataset.id); await recargar(); avisar("Documento eliminado ✓"); }
        catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    const formE = $("form-doc-empresa");
    if (formE) formE.addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(formE);
      const archivo = formE.elements.archivo.files[0];
      if (!archivo) return;
      const $btn = formE.querySelector('button[type="submit"]');
      $btn.disabled = true; $btn.textContent = "Subiendo…";
      try {
        const ruta = await DB.subirDocumento("empresa", archivo, "docs-equipo");
        await DB.crearDocEmpresa({
          titulo: (d.get("titulo") || "").toString().trim(),
          titulo_en: (d.get("titulo") || "").toString().trim(),
          ruta, vence: d.get("vence") || null, orden: 99
        });
        await recargar();
        avisar("Documento de la empresa guardado ✓ — el equipo y los portales ya lo ven");
      } catch (err) {
        avisar("No se pudo subir: " + err.message, true);
        $btn.disabled = false; $btn.textContent = "⬆ Subir documento de la empresa";
      }
    });
  }

  // ---------- Notificaciones al teléfono (dueño y Flavia) ----------
  const VAPID_PUBLICA = "BFz8YFTrRLK43nXpdA1bRjOks94y4Z2kNGWHiLn3Y9D1FYM12sJt6Zn1DODXLJaLpiGzxZRgn-1mzBJr43pWlD8";
  const b64aBytes = s => {
    const raw = atob((s + "=".repeat((4 - s.length % 4) % 4)).replace(/-/g, "+").replace(/_/g, "/"));
    return Uint8Array.from(raw, c => c.charCodeAt(0));
  };

  // ¿La base ya tiene el candado que le quita los montos a los avisos?
  // Se pregunta una sola vez por sesión. null = todavía no se sabe.
  let avisosSeguros = null;
  function pintarInicioNotif() {
    const caja = $("inicio-notif");
    if (!caja) return;
    const soporta = "serviceWorker" in navigator && "PushManager" in window && location.protocol.startsWith("http");
    // Los avisos son para TODOS, no solo para el dueño: Jian y Osbel también
    // tienen que enterarse de un 🔴 urgente o de un mensaje del chat.
    if (!soporta || (window.Notification && Notification.permission === "granted")) {
      caja.innerHTML = ""; return;
    }
    // CANDADO: al equipo NO se le ofrece encender los avisos hasta que la
    // base tenga puesto el filtro que le quita los montos al aviso. Si no,
    // un 🔴 urgente o un mensaje del chat con un precio adentro se les
    // pinta en la pantalla de bloqueo, saltándose todo el filtro de la app.
    if (!usuario.finanzas) {
      if (avisosSeguros === false) { caja.innerHTML = ""; return; }
      if (avisosSeguros === null) {
        caja.innerHTML = "";
        DB.avisosSinDinero().then(ok => {
          avisosSeguros = ok;
          if (ok) pintarInicioNotif();
        }).catch(() => { avisosSeguros = false; });
        return;
      }
    }
    caja.innerHTML = `
      <div class="inicio-card">
        <div class="aviso-texto" style="padding:.2rem 0">🔔 Este teléfono todavía no recibe avisos de la app.
          <button class="accion secundaria" id="btn-notif-activar">Activar notificaciones</button>
        </div>
      </div>`;
    $("btn-notif-activar").addEventListener("click", activarNotificaciones);
  }

  async function activarNotificaciones() {
    try {
      const esIphone = /iPhone|iPad/.test(navigator.userAgent);
      const instalada = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone;
      if (esIphone && !instalada) {
        avisar("En iPhone: primero agrega la app a la pantalla de inicio y ábrela desde el icono del rayo", true);
        return;
      }
      const reg = await navigator.serviceWorker.ready;
      const permiso = await Notification.requestPermission();
      if (permiso !== "granted") { avisar("Sin permiso — se puede activar después desde Ajustes del teléfono", true); return; }
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: b64aBytes(VAPID_PUBLICA)
      });
      const j = sub.toJSON();
      await DB.guardarSuscripcion({ endpoint: sub.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth });
      avisar("🔔 Notificaciones activadas en este teléfono ✓");
      pintarInicioNotif();
    } catch (err) { avisar("No se pudo activar: " + err.message, true); }
  }

  // Franja "HOY": lo de hoy y mañana (los pendientes viven en 🔥 Urgentes)
  function pintarInicioHoy() {
    const hoy = hoyISO();
    const man = (() => {
      const t = new Date();
      t.setDate(t.getDate() + 1);
      return fechaISO(t.getFullYear(), t.getMonth(), t.getDate());
    })();
    const evs = eventosCal()
      .filter(e => e.fecha === hoy || e.fecha === man)
      .sort((a, b) => a.fecha.localeCompare(b.fecha));
    const pens = pendientesAbiertos();
    if (!evs.length && !pens.length) { $("inicio-hoy").innerHTML = ""; return; }

    const filasEv = evs.map(e => `
      <div class="hoy-item${e.alerta ? " alerta" : ""}">
        <span class="hoy-chip ${e.fecha === hoy ? "es-hoy" : "es-man"}">${e.fecha === hoy ? "HOY" : "MAÑANA"}</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(e.titulo))}${e.hora ? ` · ${esc(e.hora)}` : ""}</span>
          ${e.proyecto ? `<span class="alcance-estado">🔧 ${esc(nombreProyecto(e.proyecto))}</span>` : ""}
        </span>
      </div>`).join("");

    // Los pendientes ya no van aquí: tienen su tarjeta 🔥 Urgentes y el Checklist
    const filasPen = "";

    $("inicio-hoy").innerHTML = `
      <div class="inicio-card">
        <div class="inicio-card-titulo">📅 Hoy en Max Power</div>
        ${filasEv || ""}
        ${filasPen || ""}
        ${!evs.length ? `<div class="hoy-mas">Nada programado para hoy ni mañana.</div>` : ""}
      </div>`;

  }

  // 🔴 URGENTES: lo que se categorizó urgente en cualquier checklist.
  //    Lo ve TODO el equipo, y se palomea desde aquí mismo.
  function pintarInicioUrgentes() {
    const caja = $("inicio-urgentes");
    if (!caja) return;
    const urgentes = urgentesTodos();
    const pendientesTotal = pendientesAbiertos().length;
    if (!urgentes.length && !pendientesTotal) { caja.innerHTML = ""; return; }

    caja.innerHTML = `
      <div class="inicio-card${urgentes.length ? " avisos" : ""}">
        <div class="inicio-card-titulo">${urgentes.length
          ? `🔴 Lo urgente ahora (${urgentes.length})`
          : "✅ Nada urgente ahora mismo"}</div>
        ${urgentes.map(filaTarea).join("")}
        <div class="hoy-mas">
          <button type="button" class="accion secundaria" id="btn-ir-checklist-inicio">
            ✅ Abrir el checklist completo
          </button>
        </div>
      </div>`;

    $("btn-ir-checklist-inicio").addEventListener("click", () => irChecklist());
    engancharTareas(caja, pintarInicio);
  }

  // Corregir el texto de un pendiente rojo (lo usan el inicio y el calendario)
  async function editarPendiente(id, repintar) {
    const pen = pendientesTodos().find(x => String(x.id) === String(id));
    if (!pen) return;
    const nuevo = prompt("Corrige el texto del pendiente:", pen.descripcion);
    if (nuevo === null) return; // canceló
    const limpio = nuevo.trim();
    if (!limpio || limpio === pen.descripcion) return;
    try {
      await DB.cambiarPendiente(id, { descripcion: limpio });
      pen.descripcion = limpio;
      repintar();
      avisar("Pendiente corregido ✓");
    } catch (err) {
      avisar("No se pudo corregir: " + err.message, true);
    }
  }

  // Avisos del dueño: plata y proyectos que piden atención
  function pintarInicioAvisos() {
    if (!usuario.finanzas) { $("inicio-avisos").innerHTML = ""; return; }
    const avisos = [];
    // 🚀 Proyectos con cosas pendientes para arrancar (materiales + gestiones)
    for (const p of proyectos()) {
      if (!["aprobado", "ejecucion"].includes(p.estado)) continue;
      const fa = faltaArranque(p.id);
      if (fa.materiales + fa.gestiones === 0) continue;
      const partes = [];
      if (fa.materiales) partes.push(`${fa.materiales} material${fa.materiales > 1 ? "es" : ""}`);
      if (fa.gestiones) partes.push(`${fa.gestiones} gestión${fa.gestiones > 1 ? "es" : ""}`);
      avisos.push({ accion: "arranque", id: p.id, icono: "🚀", texto: `${p.nombre} — ${partes.join(" y ")} para arrancar` });
    }
    // Materiales generales (sin proyecto) que siguen sin comprarse
    const porComprarGral = (state.materiales || []).filter(m => m.estado === "falta" && !m.proyecto).length;
    if (porComprarGral)
      avisos.push({ accion: "materiales", icono: "🛒", texto: `${porComprarGral} material${porComprarGral > 1 ? "es" : ""} general${porComprarGral > 1 ? "es" : ""} por comprar` });
    // 💵 Trabajo TERMINADO con dinero sin cobrar: si nunca se emitió factura,
    // ningún otro aviso lo ve. Es el dinero que se olvida para siempre.
    for (const p of proyectos()) {
      if (p.estado !== "completado") continue;
      if (typeof p.contrato !== "number" || typeof p.cobrado !== "number") continue;
      const falta = p.contrato - p.cobrado;
      if (falta > 1)
        avisos.push({ id: p.id, icono: "💵", texto: `${p.nombre} está TERMINADO y quedan ${fmt(falta)} sin cobrar` });
    }
    // 📋 Aprobado sin monto de contrato: no se puede facturar ni medir el margen
    for (const p of proyectos()) {
      if (p.estado !== "aprobado") continue;
      if (typeof p.contrato === "number" && p.contrato > 0) continue;
      avisos.push({ id: p.id, icono: "📋", texto: `${p.nombre} está aprobado SIN monto de contrato — ponle el precio para poder facturar` });
    }
    for (const p of proyectos()) {
      for (const f of facturasPendientes(p)) {
        const dias = diasDesde(f.fechaISO);
        if (dias !== null && dias >= 30)
          avisos.push({ id: p.id, icono: "💵", texto: `Factura #${f.num} de ${p.nombre} lleva ${dias} días sin pagar (${fmt(f.monto)})` });
      }
      if (p.estado === "enviado") {
        const dias = diasDesde(p.actualizado);
        if (dias !== null && dias >= 21)
          avisos.push({ id: p.id, icono: "⏳", texto: `${p.nombre}: propuesta sin movimiento hace ${dias} días — revívela o márcala perdida` });
      }
      if (p.estado === "ejecucion" && p.horas && p.horas.estimadas > 0) {
        const razon = p.horas.reales / p.horas.estimadas;
        if (razon > 1)
          avisos.push({ id: p.id, icono: "⏱", texto: `${p.nombre}: ${p.horas.reales}h trabajadas de ${p.horas.estimadas}h estimadas — se está comiendo el margen` });
        else if (razon >= 0.8)
          avisos.push({ id: p.id, icono: "⏱", texto: `${p.nombre}: el labor va al ${Math.round(razon * 100)}% de lo estimado (${p.horas.reales}h de ${p.horas.estimadas}h) — vigílalo` });
      }
      if (["ejecucion", "aprobado", "pausa"].includes(p.estado)
          && p.presupuestoMateriales > 0) {
        const gasto = gastoMateriales(p.id);
        const razon = gasto / p.presupuestoMateriales;
        if (razon > 1)
          avisos.push({ id: p.id, icono: "🛒", texto: `${p.nombre}: materiales PASADOS del presupuesto — ${fmt(gasto)} de ${fmt(p.presupuestoMateriales)}` });
        else if (razon >= 0.8)
          avisos.push({ id: p.id, icono: "🛒", texto: `${p.nombre}: materiales al ${Math.round(razon * 100)}% del presupuesto (${fmt(gasto)} de ${fmt(p.presupuestoMateriales)})` });
      }
    }
    if (!avisos.length) { $("inicio-avisos").innerHTML = ""; return; }
    $("inicio-avisos").innerHTML = `
      <div class="inicio-card avisos">
        <div class="inicio-card-titulo">⚠ Avisos</div>
        ${avisos.map(a => `
          <button class="aviso-linea" data-id="${esc(a.id || "")}" data-accion="${esc(a.accion || "")}">
            <span>${a.icono}</span>
            <span class="aviso-texto">${esc(a.texto)}</span>
            <span class="cat-flecha">›</span>
          </button>`).join("")}
      </div>`;
    $("inicio-avisos").querySelectorAll(".aviso-linea").forEach(btn => {
      btn.addEventListener("click", () => {
        if (btn.dataset.accion === "materiales") irMateriales();
        else if (btn.dataset.accion === "arranque") irMateriales(btn.dataset.id);
        else irDetalle(btn.dataset.id);
      });
    });
  }

  // ¿Quién reportó horas? (solo dueño)
  function pintarInicioEquipo() {
    if (!usuario.finanzas) {
      // El equipo no ve el semáforo de todos, pero SÍ tiene que ver el suyo:
      // si hoy no reportó, se le recuerda con un botón que abre el formulario.
      const hoy = hoyISO();
      const yaReporto = (state.registroHoras || [])
        .some(r => r.usuarioId === usuario.id && r.fecha === hoy);
      $("inicio-equipo").innerHTML = yaReporto ? `
        <div class="inicio-card">
          <div class="inicio-card-titulo">⏱ Tus horas de hoy</div>
          <p class="modal-nota" style="margin:.2rem 0">✅ Ya reportaste hoy. Gracias.</p>
        </div>` : `
        <div class="inicio-card falta-horas">
          <div class="inicio-card-titulo">⏱ Todavía no reportaste tus horas de hoy</div>
          <p class="modal-nota" style="margin:.2rem 0 .5rem">Repórtalas antes de irte — después se olvidan.</p>
          <button type="button" class="accion" id="btn-reportar-ya">Reportar mis horas</button>
        </div>`;
      const b = document.getElementById("btn-reportar-ya");
      if (b) b.addEventListener("click", irHoras);
      return;
    }
    // Solo los de campo ACTIVOS: Gustavo (license) no reporta horas de obra
    const equipo = (state.equipo || []).filter(u => u.rol === "campo" && u.activo);
    if (!equipo.length) { $("inicio-equipo").innerHTML = ""; return; }
    // 📊 Capacidad: cuántos días de los próximos 7 tiene cada quien agendados
    const hoy = hoyISO();
    const tope = new Date(Date.parse(hoy) + 7 * 86400000).toISOString().slice(0, 10);
    const diasPersona = {};
    let sinAsignar = 0;
    for (const e of (state.eventos || [])) {
      if (e.fecha < hoy || e.fecha > tope || e.estadoEv === "cancelado") continue;
      if (!e.asignados || !e.asignados.length) { sinAsignar++; continue; }
      for (const n of e.asignados) {
        diasPersona[n] = diasPersona[n] || new Set();
        diasPersona[n].add(e.fecha);
      }
    }
    const capacidad = Object.keys(diasPersona).length || sinAsignar
      ? `<p class="modal-nota" style="margin:.2rem 0 .5rem">📊 Próximos 7 días: ${
          Object.entries(diasPersona).map(([n, s]) => `${esc(n)} ${s.size} día${s.size === 1 ? "" : "s"}`).join(" · ") || "nadie agendado"
        }${sinAsignar ? ` · ${sinAsignar} evento${sinAsignar === 1 ? "" : "s"} sin asignar` : ""}</p>`
      : "";
    const filas = equipo.map(u => {
      const mios = (state.registroHoras || []).filter(r => r.usuarioId === u.id);
      const ultima = mios.length ? mios[mios.length - 1].fecha : null;
      const dias = diasDesde(ultima);
      let clase = "gris", texto = "sin reportes todavía";
      if (dias !== null) {
        if (dias <= 1) { clase = "verde"; texto = dias === 0 ? "reportó hoy ✓" : "reportó ayer ✓"; }
        else if (dias <= 3) { clase = "amarillo"; texto = `hace ${dias} días`; }
        else { clase = "rojo"; texto = `hace ${dias} días sin reportar`; }
      }
      // Los últimos 14 días de esta persona, para revisar sin ir proyecto por proyecto
      const desde = (() => { const d = new Date(); d.setDate(d.getDate() - 14);
        return fechaISO(d.getFullYear(), d.getMonth(), d.getDate()); })();
      const recientes = mios.filter(r => r.fecha >= desde).slice().reverse();
      const reportes = recientes.map(r => `
        <div class="eq-reporte${r.correccion === "pedida" ? " eq-pide" : ""}" data-id="${r.id}">
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(r.fecha)} · ${esc(nombreProyecto(r.proyecto) || "—")} · <strong>${esc(r.horas)} h</strong>${r.co ? " · 🧾 " + esc(r.co) : ""}</span>
            <span class="alcance-estado">${esc(r.fase || "")}${r.notas ? " — " + esc(r.notas) : ""}</span>
            ${r.correccion === "pedida" ? `<span class="alcance-estado">✏️ <strong>Pide permiso para corregir este reporte</strong></span>` : ""}
            ${r.correccion === "aprobada" ? `<span class="alcance-estado">✅ Permiso dado — esperando su corrección</span>` : ""}
          </span>
          ${r.correccion === "pedida" ? `<button class="accion eq-rep-permiso" title="Darle permiso">✓ Dar permiso</button>` : ""}
          <button class="eq-rep-editar insp-borrar" title="Corregir horas o notas">✎</button>
          <button class="eq-rep-borrar insp-borrar" title="Eliminar reporte">🗑</button>
        </div>`).join("");
      // Totales de la semana, para pagar sin ir contando reporte por reporte
      const lunesDe = d => { const x = new Date(d); const dia = (x.getDay() + 6) % 7; x.setDate(x.getDate() - dia); return fechaISO(x.getFullYear(), x.getMonth(), x.getDate()); };
      const hoyD = new Date();
      const lunEsta = lunesDe(hoyD);
      const lunPasada = (() => { const x = new Date(hoyD); x.setDate(x.getDate() - 7); return lunesDe(x); })();
      const sumar = (desde, hasta) => mios
        .filter(r => r.fecha >= desde && (!hasta || r.fecha < hasta))
        .reduce((t, r) => t + Number(r.horas || 0), 0);
      const hEsta = Math.round(sumar(lunEsta, null) * 10) / 10;
      const hPasada = Math.round(sumar(lunPasada, lunEsta) * 10) / 10;
      const semanas = `<div class="eq-semanas">Esta semana: <strong>${hEsta} h</strong> · Semana pasada: <strong>${hPasada} h</strong></div>`;
      const pendDe = (state.pendientes || [])
        .filter(x => x.autorId === u.id && !x.resuelto).slice(-5).reverse();
      const pendHTML = pendDe.length ? `
        <div class="eq-pend-titulo">Pendientes que reportó (se manejan en el ✅ Checklist):</div>
        ${pendDe.map(x => `<div class="eq-pend">• ${esc(x.descripcion)} <span class="tarea-meta">${esc(nombreProyecto(x.proyecto) || "General")} · ${esc(x.fecha)}</span></div>`).join("")}` : "";
      return `<details class="equipo-det" data-uid="${esc(u.id)}">
          <summary class="equipo-item">
            <span class="equipo-dot ${clase}"></span>
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(u.nombre)}</span>
              <span class="alcance-estado">${texto}${u.ultimaVista ? ` · 📱 en la app: ${esc(String(u.ultimaVista).slice(0, 10))}` : ""} · toca para ver sus reportes</span>
              ${semanas}
            </span>
          </summary>
          <div class="equipo-reportes">
            ${reportes || `<p class="cal-sin-eventos">Sin reportes en los últimos 14 días.</p>`}
            ${pendHTML}
          </div>
        </details>`;
    }).join("");
    $("inicio-equipo").innerHTML = `
      <div class="inicio-card">
        <div class="inicio-card-titulo">⏱ Reporte de horas del equipo</div>
        ${capacidad}
        ${filas}
      </div>`;

    $("inicio-equipo").querySelectorAll(".eq-rep-permiso").forEach(btn => {
      btn.addEventListener("click", async e => {
        e.preventDefault();
        try {
          await DB.cambiarHoras(btn.closest(".eq-reporte").dataset.id, { correccion_estado: "aprobada" });
          await recargar();
          avisar("Permiso dado ✓ — le llegó el aviso al teléfono");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    // Corregir o eliminar un reporte desde aquí mismo (permiso real del dueño)
    $("inicio-equipo").querySelectorAll(".eq-rep-editar").forEach(btn => {
      btn.addEventListener("click", async e => {
        e.preventDefault();
        const id = btn.closest(".eq-reporte").dataset.id;
        const rep = (state.registroHoras || []).find(r => String(r.id) === String(id));
        if (!rep) return;
        const h = prompt("Horas trabajadas:", rep.horas);
        if (h === null) return;
        const horasNum = Number(String(h).replace(",", "."));
        if (!Number.isFinite(horasNum) || horasNum < 0 || horasNum > 24) {
          avisar("Ese número de horas no es válido — no se cambió nada.", true);
          return;
        }
        const notas = prompt("Notas (qué se hizo):", rep.notas || "");
        if (notas === null) return;
        const cambios = { horas: horasNum, notas: notas.trim() };
        // Si el trabajador se equivocó de proyecto, aquí se mueve (queda constancia)
        if (confirm("¿Quieres MOVER este reporte a OTRO proyecto?\n\nAceptar = elegir el proyecto correcto.\nCancelar = dejarlo donde está.")) {
          const lista = proyectosConTrabajo();
          const menu = lista.map((x, i) => `${i + 1}. ${x.nombre}`).join("\n");
          const n = prompt("Escribe el NÚMERO del proyecto correcto:\n\n" + menu);
          if (n !== null) {
            const elegido = lista[Number(String(n).trim()) - 1];
            if (!elegido) { avisar("Ese número no está en la lista — no se movió nada.", true); return; }
            if (elegido.id !== rep.proyecto) {
              cambios.proyecto_id = elegido.id;
              cambios.notas = (cambios.notas ? cambios.notas + "\n\n" : "") +
                `[Corregido por Edgar el ${hoyISO()}: se movió de ${nombreProyecto(rep.proyecto) || rep.proyecto} a ${elegido.nombre}.]`;
            }
          }
        }
        try {
          await DB.cambiarHoras(id, cambios);
          await recargar();
          avisar(cambios.proyecto_id ? "Reporte corregido y movido de proyecto ✓" : "Reporte corregido ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("inicio-equipo").querySelectorAll(".eq-rep-borrar").forEach(btn => {
      btn.addEventListener("click", async e => {
        e.preventDefault();
        if (!confirm("¿Eliminar este reporte de horas?")) return;
        try {
          await DB.eliminarHoras(btn.closest(".eq-reporte").dataset.id);
          await recargar();
          avisar("Reporte eliminado ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
  }

  // Lo que NO cuenta como dinero contratado: terminado, perdido, o todavía
  // cotizándose. Mismo criterio en las tarjetas y en el resumen.
  const SIN_CONTRATO = ["completado", "no_aprobado", "estimando"];

  function pintarCategorias() {
    const lista = proyectos();
    $categorias.innerHTML = Object.entries(TIPOS).map(([clave, t]) => {
      const del = lista.filter(p => (p.tipo || "residencial") === clave);
      const activos = del.filter(p => !SIN_CONTRATO.includes(p.estado));
      const enObra = del.filter(p => p.estado === "ejecucion").length;
      const dineroLinea = usuario.finanzas
        ? `<div class="cat-dinero">${fmt(activos.filter(p => typeof p.contrato === "number").reduce((s, p) => s + p.contrato, 0))} contratado activo</div>`
        : "";
      // El desglose por etapa: llena el hueco de la derecha con lo que de
      // verdad quieres saber de un vistazo, sin abrir la categoría.
      const desglose = ORDEN_ETAPAS.map(et => {
        const n = del.filter(p => p.estado === et).length;
        if (!n) return "";
        return `<span class="cat-etapa"><span class="dot ${DOT[et]}"></span>
          <b>${n}</b> ${esc(ESTADOS[et].etiqueta)}</span>`;
      }).filter(Boolean).join("");
      return `
        <button class="categoria-card" data-tipo="${clave}">
          <div class="cat-icono">${t.icono}</div>
          <div class="cat-info">
            <div class="cat-nombre">${t.etiqueta}</div>
            <div class="cat-conteo">${activos.length} activos · ${enObra} en ejecución</div>
            ${dineroLinea}
          </div>
          <div class="cat-etapas">${desglose || `<span class="cat-etapa vacia">Todavía no hay proyectos</span>`}</div>
          <div class="cat-flecha">›</div>
        </button>`;
    }).join("");
    $categorias.querySelectorAll(".categoria-card").forEach(btn => {
      btn.addEventListener("click", () => irEtapas(btn.dataset.tipo));
    });
  }

  function pintarResumen() {
    if (!usuario.finanzas) { $resumen.innerHTML = ""; return; }
    const lista = proyectos();
    // Los "no aprobados" no cuentan: ni como activos ni en el dinero contratado
    const activos = lista.filter(p => !SIN_CONTRATO.includes(p.estado));
    const contratado = lista
      .filter(p => !SIN_CONTRATO.includes(p.estado) && typeof p.contrato === "number")
      .reduce((s, p) => s + p.contrato, 0);
    const cobrado = lista
      .filter(p => typeof p.cobrado === "number")
      .reduce((s, p) => s + p.cobrado, 0);
    const porCobrar = lista
      .filter(p => typeof p.contrato === "number" && typeof p.cobrado === "number")
      .filter(p => ["ejecucion", "aprobado"].includes(p.estado))
      .reduce((s, p) => s + (p.contrato - p.cobrado), 0);
    const pendFact = lista.flatMap(facturasPendientes);
    const pendTotal = pendFact.reduce((s, f) => s + f.monto, 0);

    $resumen.innerHTML = `
      <div class="resumen-card"><div class="valor">${activos.length}</div><div class="etiqueta">Proyectos activos</div></div>
      <div class="resumen-card"><div class="valor">${fmt(contratado)}</div><div class="etiqueta">Contratado activo</div></div>
      <div class="resumen-card"><div class="valor">${fmt(cobrado)}</div><div class="etiqueta">Cobrado a la fecha</div></div>
      <div class="resumen-card"><div class="valor">${fmt(porCobrar)}</div><div class="etiqueta">Por cobrar</div></div>
      <div class="resumen-card${pendFact.length ? " alerta" : ""}">
        <div class="valor">${fmt(pendTotal)}</div>
        <div class="etiqueta">${pendFact.length ? `Facturado sin pagar (${pendFact.length})` : "Facturas sin pagar"}</div>
      </div>`;
  }

  // ============================================================
  // NIVEL 2 · ETAPAS
  // ============================================================
  function irEtapas(tipo) {
    tipoActivo = tipo;
    etapaActiva = null;
    mostrar("etapas", { kicker: "Categorías", titulo: TIPOS[tipo].etiqueta, volver: true, nuevo: true });
    pintarEtapas();
  }

  function pintarEtapas() {
    const del = proyectos().filter(p => (p.tipo || "residencial") === tipoActivo);
    $etapas.innerHTML = ORDEN_ETAPAS.map(clave => {
      const n = del.filter(p => p.estado === clave).length;
      if (n === 0 && (clave === "pausa" || clave === "completado" || clave === "no_aprobado")) return "";
      const e = ESTADOS[clave];
      return `
        <button class="etapa-card" data-etapa="${clave}">
          <span class="etapa-num">${n}</span>
          <span class="etapa-info">
            <span class="etapa-nombre"><span class="dot ${DOT[clave]}"></span>${e.etiqueta}</span>
            <span class="etapa-desc">${DESC_ETAPA[clave]}</span>
          </span>
          <span class="etapa-flecha">›</span>
        </button>`;
    }).join("");
    $etapas.querySelectorAll(".etapa-card").forEach(btn => {
      btn.addEventListener("click", () => irLista(btn.dataset.etapa));
    });
  }

  // ============================================================
  // NIVEL 3 · LISTA
  // ============================================================
  function irLista(etapa) {
    etapaActiva = etapa;
    textoBusqueda = "";
    $buscador.value = "";
    mostrar("lista", {
      kicker: TIPOS[tipoActivo].etiqueta,
      titulo: ESTADOS[etapa].etiqueta,
      volver: true,
      nuevo: true
    });
    pintarLista();
  }

  $btnVolver.addEventListener("click", () => {
    if (!$("vista-asistente").hidden) { irHome(); return; }
    if (!$("vista-chat").hidden) {
      if (chatConv) { irChat(null); return; }
      irHome();
      return;
    }
    if (!$("vista-estimador").hidden) {
      if (estimadoActivo) { estimadoActivo = null; pintarEstimador(); return; }
      irHome();
      return;
    }
    if (!$("vista-alcance").hidden) {
      alcRecoger();
      if (alcFicha > 0) { alcFicha -= 1; pintarAlcance(); return; }
      const proy = alcActivo ? alcActivo.proyecto.id : null;
      alcActivo = null;
      if (proy) irDetalle(proy); else irHome();
      return;
    }
    if (!$("vista-cierre").hidden) {
      const est = cierrePropuesta ? cierrePropuesta.propuesta.estimado_id : null;
      cierrePropuesta = null;
      if (est) irEstimador(est); else irHome();
      return;
    }
    if (!$("vista-propuesta").hidden) {
      const id = propActiva ? propActiva.estimado.id : null;
      propActiva = null;
      if (id) irEstimador(id); else irHome();
      return;
    }
    if (!$("vista-levantamiento").hidden) {
      if (levActivo && levCuartoAbierto) { levCuartoAbierto = null; pintarLevantamiento(); return; }
      if (levActivo) { levSubir(); levActivo = null; irLevLista(); return; }
      irHome();
      return;
    }
    if (!$vDetalle.hidden) {
      proyectoActivo = null;
      if (tipoActivo && etapaActiva) { irLista(etapaActiva); return; }
      irHome();
      return;
    }
    if (!$vLista.hidden) { irEtapas(tipoActivo); return; }
    irHome();
  });

  const listaAbiertos = new Set(); // qué proyectos dejó abiertos (acordeón)
  function pintarLista(abrirId) {
    if (abrirId) listaAbiertos.add(abrirId);
    const texto = textoBusqueda.trim().toLowerCase();
    const visibles = proyectos().filter(p => {
      const pasaTipo = (p.tipo || "residencial") === tipoActivo;
      const pasaEtapa = p.estado === etapaActiva;
      const pasaTexto = !texto ||
        [p.nombre, p.cliente, p.direccion, p.via, p.ref]
          .join(" ").toLowerCase().includes(texto);
      return pasaTipo && pasaEtapa && pasaTexto;
    });

    $lista.innerHTML = visibles.length
      ? visibles.map(tarjetaResumenHTML).join("")
      : `<div class="sin-resultados">No hay proyectos aquí.</div>`;

    // Acordeón como el checklist: tocar el nombre abre/cierra la tarjeta
    $lista.querySelectorAll(".proy-det").forEach(det => {
      det.addEventListener("toggle", () => {
        if (det.open) listaAbiertos.add(det.dataset.id);
        else listaAbiertos.delete(det.dataset.id);
      });
    });
    // "Ver proyecto completo" abre la ficha
    $lista.querySelectorAll(".abrir-ficha").forEach(btn => {
      btn.addEventListener("click", () => irDetalle(btn.closest(".proy-det").dataset.id));
    });
  }

  $buscador.addEventListener("input", () => {
    textoBusqueda = $buscador.value;
    pintarLista();
  });

  // ---------- Piezas de la tarjeta ----------
  function stepperHTML(p) {
    if (p.estado !== "ejecucion") return "";
    const idx = Math.max(0, FASES.findIndex(f => f.clave === p.fase));
    const pasos = FASES.map((f, i) => `
      <div class="paso${i < idx ? " hecho" : ""}${i === idx ? " actual" : ""}">
        <div class="paso-punto">${i < idx ? "✓" : i + 1}</div>
        <div class="paso-nombre">${f.etiqueta}</div>
      </div>`).join(`<div class="paso-linea"></div>`);
    return `<div class="detalle-seccion"><h3>Fase de obra</h3><div class="stepper">${pasos}</div></div>`;
  }

  function horasHTML(p) {
    if (!p.horas) return "";
    const h = p.horas;
    const pct = h.estimadas > 0 ? Math.min(100, Math.round((h.reales / h.estimadas) * 100)) : 0;
    const indice = h.estimadas > 0 ? h.reales / h.estimadas : null;
    const restantes = Math.max(0, h.estimadas - h.reales);
    const color = indice === null ? "" : indice <= 1 ? "ok" : indice <= 1.15 ? "warn" : "bad";
    return `
      <div class="detalle-seccion">
        <h3>Horas — plan vs. real</h3>
        <div class="horas-linea">
          <span class="horas-num ${color}">${h.reales} h</span>
          <span class="horas-de">de ${h.estimadas} h estimadas</span>
          ${p.estado !== "completado" ? `<span class="horas-restan">quedan ${Math.round(restantes * 10) / 10} h</span>` : ""}
        </div>
        <div class="barra horas-barra"><div class="barra-relleno ${color}" style="width:${pct}%"></div></div>
        ${registroHorasHTML(p)}
      </div>`;
  }

  function registroHorasHTML(p) {
    const reg = (state.registroHoras || [])
      .filter(r => r.proyecto === p.id).slice(-5).reverse();
    if (!reg.length) return "";
    return `<div class="horas-registro">` + reg.map(r =>
      `<div class="alcance-item">
        <span class="alcance-tipo">${esc(r.horas)}h</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(r.trabajador)}${r.fase ? " · " + esc(r.fase) : ""}</span>
          <span class="alcance-estado">${esc(r.fecha)}${r.notas ? " · " + esc(sinMontos(r.notas)) : ""}</span>
        </span>
      </div>`).join("") + `</div>`;
  }

  function desgloseHTML(p) {
    if (!p.alcances || !p.alcances.length) return "";
    if (!usuario.finanzas) {
      const items = p.alcances.map(a => `
        <div class="alcance-item">
          <span class="alcance-tipo">${esc(a.tipo || "SOW")}</span>
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(sinMontos(a.titulo))}</span>
            <span class="alcance-estado">${esc(sinMontos(a.estado || ""))}</span>
          </span>
        </div>`).join("");
      return `<div class="detalle-seccion"><h3>Alcances del proyecto</h3>${items}</div>`;
    }
    const filas = p.alcances.map(a => {
      const pct = (typeof a.monto === "number" && a.monto > 0 && typeof a.cobrado === "number")
        ? ` <span class="pct">(${Math.round((a.cobrado / a.monto) * 100)}%)</span>` : "";
      const monto = a.monto < 0 ? `<span class="neg">–${fmt(Math.abs(a.monto))}</span>` : fmt(a.monto);
      return `<tr>
          <td><strong>${esc(a.titulo)}</strong><br><span class="alcance-ref">${esc(a.ref || "")} · ${esc(a.estado || "")}</span></td>
          <td class="r">${monto}</td>
          <td class="r">${a.cobrado === null || a.cobrado === undefined ? "—" : fmt(a.cobrado) + pct}</td>
        </tr>`;
    }).join("");
    const totalCobrado = p.alcances.reduce((s, a) => s + (a.cobrado || 0), 0);
    return `
      <div class="detalle-seccion">
        <h3>Desglose del contrato</h3>
        <div class="tabla-envoltura">
          <table class="facturas desglose">
            <thead><tr><th>Alcance</th><th class="r">Monto</th><th class="r">Cobrado</th></tr></thead>
            <tbody>
              ${filas}
              <tr class="total"><td>Precio total del contrato</td><td class="r">${fmt(p.contrato)}</td><td class="r">${fmt(totalCobrado)}</td></tr>
            </tbody>
          </table>
        </div>
      </div>`;
  }

  function proximoHito(p) {
    if (!p.hitos || p.estado === "completado") return null;
    return p.hitos.find(h => h.estado !== "cobrado") || null;
  }

  function proximoCobroHTML(p) {
    if (!usuario.finanzas) return "";
    const h = proximoHito(p);
    if (!h) return "";
    const nota = h.estado === "facturado" ? " · ya facturado, sin pagar" : "";
    return `<div class="proximo-cobro">➡ Próximo cobro: <strong>${fmt(h.monto)}</strong> — ${esc((h.condicion || "").toLowerCase())}${nota}</div>`;
  }

  function hitosHTML(p) {
    if (!usuario.finanzas) return "";
    // Una obra con contrato y SIN hitos es dinero que no se puede facturar
    // con el botón 🧾 y que no sale en ningún aviso. Antes esta sección
    // simplemente no aparecía y el hueco quedaba invisible.
    if (!p.hitos || !p.hitos.length) {
      if (typeof p.contrato !== "number" || p.contrato <= 0) return "";
      return `
        <div class="detalle-seccion">
          <h3>Hitos de pago</h3>
          <div class="rent-humo">⚠ Este proyecto tiene contrato de ${fmt(p.contrato)} pero
          <strong>ningún hito de pago</strong>. Así no se puede facturar con el botón 🧾 ni
          avisa cuando toca cobrar. Cópialos del SOW (normalmente 35/45/20 o 50/50).</div>
        </div>`;
    }
    const siguiente = proximoHito(p);
    // El texto de la factura sale armado con las reglas de la casa:
    // Due on receipt, referencia del proyecto y condición del hito.
    const textoFactura = h => [
      `${h.titulo} — ${p.nombre}`,
      p.direccion ? `Job address: ${p.direccion}` : "",
      [p.ref ? `Per Proposal ${p.ref}.` : "", h.condicion || ""].filter(Boolean).join(" "),
      `Amount: ${fmt(h.monto)}`,
      "Terms: Due on receipt"
    ].filter(Boolean).join("\n");
    const filas = p.hitos.map(h => {
      const esSiguiente = h === siguiente;
      const icono = h.estado === "cobrado" ? "✓" : h.estado === "facturado" ? "⚠" : "○";
      const claseFila = h.estado === "cobrado" ? "hito-cobrado" : esSiguiente ? "hito-siguiente" : "hito-pendiente";
      return `<div class="hito ${claseFila}">
          <span class="hito-icono">${icono}</span>
          <span class="hito-info">
            <span class="hito-titulo">${esc(h.titulo)}${esSiguiente ? ' <span class="hito-chip">PRÓXIMO</span>' : ""}</span>
            <span class="hito-cond">${esc(h.condicion || "")}${h.estado === "facturado" ? " · facturado, sin pagar" : ""}</span>
          </span>
          <span class="hito-monto">${fmt(h.monto)}</span>
          ${h.estado !== "cobrado" && usuario.editar ? `<button type="button" class="insp-borrar hito-facturar"
            data-texto="${esc(textoFactura(h))}" data-hito="${esc(h.id)}" data-proyecto="${esc(p.id)}"
            title="Crea la factura en QuickBooks con las reglas de la casa">🧾</button>
          <button type="button" class="chip-cobrar hito-cobrado" data-hito="${esc(h.id)}" data-titulo="${esc(h.titulo)}" data-monto="${h.monto}"
            title="Ya entró el dinero de este hito — marcarlo COBRADO">💵</button>` : ""}
        </div>`;
    }).join("");
    const porCobrarTotal = p.hitos.filter(h => h.estado !== "cobrado").reduce((s, h) => s + h.monto, 0);
    // ¿Los hitos suman lo mismo que el contrato? Si no, uno de los dos está
    // mal — y el que manda es el SOW firmado.
    const sumaHitos = p.hitos.reduce((s, h) => s + h.monto, 0);
    const desfase = (typeof p.contrato === "number" && p.contrato > 0)
      ? Math.round((p.contrato - sumaHitos) * 100) / 100 : 0;
    const avisoDesfase = Math.abs(desfase) >= 0.02
      ? `<div class="rent-humo">⚠ Los hitos suman ${fmt(sumaHitos)} y el contrato dice ${fmt(p.contrato)} —
         ${desfase > 0 ? `faltan ${fmt(desfase)} por repartir` : `sobran ${fmt(-desfase)}`}.
         Compáralo con el SOW firmado: manda el SOW.</div>`
      : "";
    return `
      <div class="detalle-seccion">
        <h3>Hitos de pago</h3>
        ${avisoDesfase}
        ${filas}
        <div class="hito hito-total">
          <span class="hito-icono"></span>
          <span class="hito-info"><span class="hito-titulo">Total por cobrar</span></span>
          <span class="hito-monto">${fmt(porCobrarTotal)}</span>
        </div>
        <div class="modal-botones">
          <a class="accion secundaria" target="_blank" rel="noopener" href="https://qbo.intuit.com/app/invoice">🧾 Nueva factura en QuickBooks</a>
          <a class="accion secundaria" target="_blank" rel="noopener" href="https://qbo.intuit.com/app/estimate">📄 Nuevo estimado en QuickBooks</a>
        </div>
      </div>`;
  }

  // ---------- Ayudantes de gastos (los usan la ficha, el inicio y 📊 Gastos) ----------
  // Mano de obra real de un proyecto: horas reportadas × costo de cada
  // trabajador (las horas de antes de la app van al costo promedio)
  function costoManoDeObra(p) {
    const costos = state.costos || {};
    const tasas = Object.values(costos);
    if (!tasas.length) return null;
    const promedio = tasas.reduce((s, x) => s + x, 0) / tasas.length;
    const reg = (state.registroHoras || []).filter(r => r.proyecto === p.id);
    const horasReg = reg.reduce((s, r) => s + r.horas, 0);
    const costoReg = reg.reduce((s, r) =>
      s + r.horas * (costos[r.usuarioId] != null ? costos[r.usuarioId] : promedio), 0);
    const horasBase = p.horas ? Math.max(0, p.horas.reales - horasReg) : 0;
    return {
      promedio,
      horas: Math.round((horasReg + horasBase) * 10) / 10,
      costo: costoReg + horasBase * promedio,
      presupuesto: p.horas && p.horas.estimadas > 0 ? p.horas.estimadas * promedio : null
    };
  }
  // Materiales comprados con precio anotado + recibos con total
  const gastoMateriales = pid =>
    (state.materiales || [])
      .filter(m => m.proyecto === pid && m.estado === "comprado" && typeof m.precio === "number")
      .reduce((s, m) => s + m.precio, 0) +
    (state.recibos || [])
      .filter(r => r.proyecto === pid && typeof r.total === "number" && r.estado !== "anulado")
      .reduce((s, r) => s + r.total, 0);
  // Lo que falta para arrancar un proyecto (materiales + gestiones)
  const faltaArranque = pid => ({
    materiales: (state.materiales || []).filter(m => m.proyecto === pid && m.estado === "falta").length,
    gestiones: (state.gestiones || []).filter(g => g.proyecto === pid && !g.hecha).length
  });
  // Ayuda externa (contratados por día o por ajuste)
  const gastoExternos = pid => (state.externos || [])
    .filter(x => x.proyecto === pid)
    .reduce((s, x) => s + x.costo, 0);

  // Barrita de "cuánto llevo del presupuesto" (verde <80% / amarillo / rojo)
  function barraGasto(gastado, presupuesto) {
    if (!presupuesto || presupuesto <= 0) return "";
    const pct = Math.round((gastado / presupuesto) * 100);
    const clase = pct < 80 ? "ok" : pct <= 100 ? "warn" : "bad";
    return `<div class="gasto-sub ${clase}">${pct}% del presupuesto (${fmt(presupuesto)})</div>
      <div class="barra horas-barra"><div class="barra-relleno ${clase}" style="width:${Math.min(100, pct)}%"></div></div>`;
  }

  // Rentabilidad y gastos: contrato − labor − materiales (SOLO el dueño)
  // El margen solo vale lo que valen los números que lo alimentan. Si de un
  // presupuesto de material de $8,000 solo hay $750 en recibos cargados, ese
  // "margen del 62%" es humo: falta meter las compras. Esto lo dice claro en
  // vez de dejar que Edgar tome decisiones con un número inventado.
  function avisoMargenFlojo(p, matGasto, matPresu, mo) {
    const faltas = [];
    if (matPresu > 0) {
      const cubierto = Math.round((matGasto / matPresu) * 100);
      if (cubierto < 60) {
        faltas.push(`solo hay recibos por el ${cubierto}% del material presupuestado (${fmt(matGasto)} de ${fmt(matPresu)})`);
      }
    } else if (matGasto <= 0) {
      faltas.push("no hay ni una compra de material cargada");
    }
    if (mo && mo.horas <= 0) faltas.push("no hay horas reportadas");
    if (!faltas.length) return "";
    return `<div class="rent-humo">⚠ Este margen todavía no es real: ${faltas.join(" y ")}.
      Mientras falten compras por cargar, el margen sale más alto de lo que es.</div>`;
  }

  function rentabilidadHTML(p) {
    if (!usuario.finanzas || typeof p.contrato !== "number" || p.contrato <= 0) return "";
    const mo = costoManoDeObra(p);
    if (!mo) {
      return `<div class="detalle-seccion"><h3>Rentabilidad y gastos</h3>
        <p>Define el costo por hora del equipo en <strong>📊 Gastos → 💲 Costos del equipo</strong>
        y aquí verás la ganancia real de este proyecto.</p></div>`;
    }
    const matGasto = gastoMateriales(p.id);
    const matPresu = p.presupuestoMateriales;
    const extGasto = gastoExternos(p.id);
    if (mo.horas <= 0 && matGasto <= 0 && extGasto <= 0) {
      return `<div class="detalle-seccion"><h3>Rentabilidad y gastos</h3>
        <p>Todavía no hay horas ni compras registradas en este proyecto.</p></div>`;
    }
    const margen = p.contrato - mo.costo - matGasto - extGasto;
    const pct = Math.round((margen / p.contrato) * 100);
    const clase = pct >= 50 ? "ok" : pct >= 30 ? "warn" : "bad";
    return `
      <div class="detalle-seccion">
        <h3>Rentabilidad y gastos</h3>
        <div class="rent-fila"><span>Contrato</span><span>${fmt(p.contrato)}</span></div>
        <div class="rent-fila"><span>Mano de obra (${mo.horas} h)</span><span>−${fmt(mo.costo)}</span></div>
        ${barraGasto(mo.costo, mo.presupuesto)}
        <div class="rent-fila"><span>Materiales comprados</span><span>−${fmt(matGasto)}</span></div>
        ${barraGasto(matGasto, matPresu)}
        ${extGasto > 0 ? `<div class="rent-fila"><span>Ayuda externa</span><span>−${fmt(extGasto)}</span></div>` : ""}
        <div class="rent-fila rent-total ${clase}"><span>Margen real</span><span>${fmt(margen)} (${pct}%)</span></div>
        <div class="barra horas-barra"><div class="barra-relleno ${clase}" style="width:${Math.max(0, Math.min(100, pct))}%"></div></div>
        ${avisoMargenFlojo(p, matGasto, matPresu, mo)}
        <p class="rent-nota">Sale de las horas reportadas × el costo de cada trabajador, más los
        materiales comprados con precio. El presupuesto de materiales se define en 📊 Gastos.</p>
      </div>`;
  }

  // Avance de obra: % de cumplimiento según los puntos del alcance
  function avanceObra(pid) {
    const tareas = tareasDe(pid);
    if (!tareas.length) return null;
    const hechos = tareas.filter(t => t.hecha).length;
    return { hechos, total: tareas.length, pct: Math.round((hechos / tareas.length) * 100) };
  }

  // ============================================================
  // CHECKLIST — UNA lista de tareas por proyecto, la ve todo el equipo.
  // Nace del alcance del trabajo y crece con lo que sale en la obra.
  // Cada tarea lleva su categoría: 🔴 Urgente · 🟡 Intermedio · ⚪ Puede esperar.
  // Lo urgente sale en el inicio de todos y avisa al teléfono.
  // ============================================================
  const PRIO = {
    urgente: { etiqueta: "Urgente",       icono: "🔴", orden: 0 },
    normal:  { etiqueta: "Intermedio",    icono: "🟡", orden: 1 },
    espera:  { etiqueta: "Puede esperar", icono: "⚪", orden: 2 }
  };
  const prioDe = v => (PRIO[v] ? v : "normal");

  let filtroChecklist = "";
  const chkAbiertos = new Set();

  function irChecklist(proyectoId) {
    filtroChecklist = proyectoId || "";
    if (proyectoId) chkAbiertos.add(proyectoId);
    mostrar("checklist", { kicker: "Trabajo por hacer", titulo: "Checklist", volver: true, nuevo: false });
    pintarChecklist();
  }

  // UNA SOLA lista por proyecto. Por dentro son dos orígenes (el alcance
  // sembrado y lo que sale en la obra); por fuera es una lista de tareas
  // igualitas: se palomean, se categorizan y cualquiera agrega.
  function tareasDe(pid) {
    const haceQuince = (() => {
      const d = new Date(); d.setDate(d.getDate() - 15);
      return fechaISO(d.getFullYear(), d.getMonth(), d.getDate());
    })();
    const delAlcance = (state.puntos || [])
      .filter(x => x.proyecto === pid)
      .map(x => ({
        tipo: "punto", id: x.id, texto: x.texto, hecha: x.hecho,
        prioridad: prioDe(x.prioridad), origen: "alcance",
        autor: "", fecha: "", orden: x.orden || 0
      }));
    const delCampo = (state.pendientes || [])
      .filter(x => x.proyecto === pid && (!x.resuelto || (x.fecha || "") >= haceQuince))
      .map(x => ({
        tipo: "pend", id: x.id, texto: x.descripcion, hecha: x.resuelto,
        prioridad: prioDe(x.prioridad), origen: "obra",
        autor: x.autor, fecha: x.fecha, orden: 900
      }));
    // Lo urgente primero, después lo intermedio, lo que puede esperar,
    // y lo completado al fondo
    return delAlcance.concat(delCampo).sort((a, b) =>
      (a.hecha - b.hecha) || (PRIO[a.prioridad].orden - PRIO[b.prioridad].orden) || (a.orden - b.orden));
  }

  // Todas las tareas urgentes sin hacer (de todos los proyectos + generales)
  function urgentesTodos() {
    const dePro = proyectosConTrabajo(["enviado"])
      .flatMap(p => tareasDe(p.id).filter(t => t.prioridad === "urgente" && !t.hecha)
        .map(t => ({ ...t, proyecto: p.id, proyectoNombre: p.nombre })));
    const generales = (state.pendientes || [])
      .filter(x => !x.proyecto && !x.resuelto && x.prioridad === "urgente")
      .map(x => ({ tipo: "pend", id: x.id, texto: x.descripcion, hecha: false,
                   prioridad: "urgente", autor: x.autor, proyecto: null, proyectoNombre: "General" }));
    return dePro.concat(generales);
  }

  // Una fila del checklist: palomita · texto · categoría · ✎ · 🗑
  function filaTarea(t) {
    const p = prioDe(t.prioridad);
    const meta = [t.proyectoNombre ? "🔧 " + t.proyectoNombre : "", t.autor || "", t.fecha || ""]
      .filter(Boolean).join(" · ");
    const selector = `
      <select class="tarea-prio ${p}" title="Categoría de la tarea">
        ${Object.entries(PRIO).map(([v, c]) =>
          `<option value="${v}"${v === p ? " selected" : ""}>${c.icono} ${c.etiqueta}</option>`).join("")}
      </select>`;
    return `
      <div class="tarea prio-${p}${t.hecha ? " hecha" : ""}" data-tipo="${t.tipo}" data-id="${t.id}">
        <button class="tarea-check" title="${t.hecha ? "Devolver a pendiente" : "Marcar completada"}">${t.hecha ? "✅" : "⬜"}</button>
        <span class="tarea-info">
          <span class="tarea-texto">${esc(sinMontos(t.texto))}</span>
          ${meta ? `<span class="tarea-meta">${esc(meta)}</span>` : ""}
        </span>
        ${t.hecha ? "" : selector}
        ${usuario.editar ? `<button class="tarea-editar insp-borrar" title="Corregir el texto">✎</button>
        <button class="tarea-borrar insp-borrar" title="Eliminar">🗑</button>` : ""}
      </div>`;
  }

  function pintarChecklist() {
    // Obras activas siempre (aunque estén vacías, para poder sembrarlas);
    // propuestas enviadas solo si ya tienen tareas — que no hagan ruido.
    const fichas = proyectosConTrabajo(["enviado"])
      .map(p => ({ p, tareas: tareasDe(p.id) }))
      .filter(x => x.tareas.length || ["ejecucion", "aprobado", "pausa"].includes(x.p.estado));

    // El panelito para agregar: escondido hasta tocar "+ Agregar una nueva"
    const formNueva = pid => `
      <button type="button" class="btn-nueva-tarea">+ Agregar una nueva</button>
      <form class="cal-form form-tarea" data-id="${esc(pid || "")}" hidden>
        <label>Descripción
          <input name="texto" type="text" required placeholder="Ej: arreglar el layout de las luces" autocomplete="off">
        </label>
        <label>Categoría
          <select name="prioridad">
            <option value="normal">🟡 Intermedio</option>
            <option value="urgente">🔴 Urgente</option>
            <option value="espera">⚪ Puede esperar</option>
          </select>
        </label>
        <button type="submit" class="accion">Agregar ✓</button>
      </form>`;

    // Cada proyecto es una ficha cerrada: solo el nombre y su resumen.
    // La tocas y se abre con toda su lista.
    const tarjeta = (titulo, pid, tareas) => {
      const clave = pid || "generales";
      const faltan = tareas.filter(t => !t.hecha);
      const urg = faltan.filter(t => t.prioridad === "urgente").length;
      const pct = tareas.length ? Math.round(((tareas.length - faltan.length) / tareas.length) * 100) : 0;
      const chip = !tareas.length ? "sin tareas"
        : !faltan.length ? "✅ al día"
        : `${faltan.length} por hacer${urg ? ` · ${urg} 🔴` : ""}`;
      return `
        <details class="chk-det${urg ? " con-urgentes" : ""}" data-id="${esc(clave)}"${chkAbiertos.has(clave) ? " open" : ""}>
          <summary>
            <span class="chk-nombre">${esc(titulo)}</span>
            <span class="chk-avance">${chip}</span>
          </summary>
          <div class="chk-cuerpo">
            ${tareas.length ? `<div class="barra horas-barra"><div class="barra-relleno ${pct >= 100 ? "ok" : ""}" style="width:${pct}%"></div></div>` : ""}
            ${tareas.map(filaTarea).join("") || `<p class="cal-sin-eventos">Sin tareas todavía — agrega la primera.</p>`}
            ${formNueva(pid)}
            ${pid ? `<button type="button" class="chk-ficha" data-id="${esc(pid)}">📂 Ver la ficha del proyecto</button>` : ""}
          </div>
        </details>`;
    };

    const generales = (state.pendientes || [])
      .filter(x => !x.proyecto && !x.resuelto)
      .map(x => ({ tipo: "pend", id: x.id, texto: x.descripcion, hecha: false,
                   prioridad: prioDe(x.prioridad), autor: x.autor, fecha: x.fecha, orden: 0 }))
      .sort((a, b) => PRIO[a.prioridad].orden - PRIO[b.prioridad].orden);

    $("checklist-panel").innerHTML = `
      ${tarjeta("📌 Generales (sin proyecto)", "", generales)}
      ${fichas.map(x => tarjeta(x.p.nombre, x.p.id, x.tareas)).join("")
        || `<p class="cal-sin-eventos">Nada pendiente por aquí. 👌</p>`}`;

    // Recordar qué fichas quedaron abiertas entre repintadas
    $("checklist-panel").querySelectorAll(".chk-det").forEach(det => {
      det.addEventListener("toggle", () => {
        if (det.open) chkAbiertos.add(det.dataset.id);
        else chkAbiertos.delete(det.dataset.id);
      });
    });
    $("checklist-panel").querySelectorAll(".chk-ficha").forEach(b =>
      b.addEventListener("click", () => irDetalle(b.dataset.id)));
    $("checklist-panel").querySelectorAll(".btn-nueva-tarea").forEach(b =>
      b.addEventListener("click", () => {
        const f = b.nextElementSibling;
        f.hidden = !f.hidden;
        if (!f.hidden) f.querySelector("input[name=texto]").focus();
      }));
    engancharTareas($("checklist-panel"), pintarChecklist);

    $("checklist-panel").querySelectorAll(".form-tarea").forEach(f => {
      f.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(f);
        const texto = (d.get("texto") || "").toString().trim();
        if (!texto) return;
        try {
          await DB.crearPendiente({
            fecha: hoyISO(), proyecto_id: f.dataset.id || null,
            descripcion: texto, prioridad: prioDe(d.get("prioridad"))
          });
          await recargar();
          avisar("Tarea agregada ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
  }

  // Los botones de cada tarea, sirven en el checklist y en el inicio
  function engancharTareas(raiz, repintar) {
    const dato = el => {
      const fila = el.closest(".tarea");
      return { tipo: fila.dataset.tipo, id: fila.dataset.id, fila };
    };
    raiz.querySelectorAll(".tarea-check").forEach(btn => {
      btn.addEventListener("click", async () => {
        const { tipo, id, fila } = dato(btn);
        const estaHecha = fila.classList.contains("hecha");
        try {
          if (tipo === "punto") await DB.cambiarPunto(id, { hecho: !estaHecha });
          else if (estaHecha) await DB.reabrirPendiente(id);
          else await DB.resolverPendiente(id);
          // Ya quedó guardado en la nube: se marca en pantalla al instante y la
          // recarga completa va por detrás. Antes cada palomita bajaba las 28
          // tablas y con mala señal congelaba el teléfono varios segundos.
          fila.classList.toggle("hecha");
          avisar(estaHecha ? "Tarea devuelta a pendiente" : "Tarea completada ✓");
          recargar();
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    raiz.querySelectorAll(".tarea-prio").forEach(sel => {
      sel.addEventListener("change", async () => {
        const { tipo, id } = dato(sel);
        const nueva = prioDe(sel.value);
        try {
          if (tipo === "punto") await DB.cambiarPunto(id, { prioridad: nueva });
          else await DB.cambiarPendiente(id, { prioridad: nueva });
          // Igual que la palomita: se pinta al instante con el estado que ya
          // está en memoria y la base entera se vuelve a bajar por detrás.
          // Con "await recargar()" cada cambio de categoría se comía 28
          // tablas y en la obra se sentía como si la app se hubiera colgado.
          const lista = tipo === "punto" ? (state.puntos || []) : (state.pendientes || []);
          const enEstado = lista.find(x => String(x.id) === String(id));
          if (enEstado) enEstado.prioridad = nueva;
          recargar();
          avisar(nueva === "urgente"
            ? "🔴 Urgente — sale en el inicio y avisa al equipo"
            : `Categoría: ${PRIO[nueva].icono} ${PRIO[nueva].etiqueta}`);
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    raiz.querySelectorAll(".tarea-editar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const { tipo, id, fila } = dato(btn);
        // El texto de la PANTALLA va con los montos tachados ($•••). Si se usara
        // ese, al corregir una palabra se perdería el precio real para siempre.
        // Por eso se busca el texto de verdad en el estado.
        const enEstado = tipo === "punto"
          ? (state.puntos || []).find(x => String(x.id) === String(id))
          : (state.pendientes || []).find(x => String(x.id) === String(id));
        const actual = enEstado
          ? (tipo === "punto" ? enEstado.texto : enEstado.descripcion)
          : fila.querySelector(".tarea-texto").textContent;
        const nuevo = prompt("Corrige el texto de la tarea:", actual);
        if (nuevo === null) return;
        const limpio = nuevo.trim();
        if (!limpio || limpio === actual) return;
        try {
          if (tipo === "punto") await DB.cambiarPunto(id, { texto: limpio });
          else await DB.cambiarPendiente(id, { descripcion: limpio });
          await recargar();
          avisar("Tarea corregida ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    raiz.querySelectorAll(".tarea-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const { tipo, id } = dato(btn);
        if (!confirm("¿Eliminar esta tarea?")) return;
        try {
          if (tipo === "punto") await DB.eliminarPunto(id);
          else await DB.eliminarPendiente(id);
          await recargar();
          avisar("Tarea eliminada ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
  }

  // ============================================================
  // 💬 CHAT DEL EQUIPO — grupo y mensajes privados, dentro de la app.
  // Grupo: lo ven todos. Privado: solo tú y esa persona (lo garantiza
  // la base de datos, no la pantalla). Cada mensaje avisa al teléfono.
  // ============================================================
  let chatConv = null;       // null = lista de conversaciones · "grupo" · uid de la otra persona
  let chatMensajes = [];
  let chatLecturas = {};
  let chatTimer = null;
  let chatBadgeTimer = null;

  // ¿A qué conversación pertenece un mensaje, visto desde mi cuenta?
  function convDe(m) {
    if (!m.destinatario_id) return "grupo";
    return m.autor_id === usuario.id ? m.destinatario_id : m.autor_id;
  }

  let chatCargaEnVuelo = null; // dos timers no piden lo mismo dos veces a la vez
  function cargarChat() {
    if (!chatCargaEnVuelo) {
      chatCargaEnVuelo = (async () => {
        const [ms, lect] = await Promise.all([DB.leerMensajes(), DB.leerLecturas()]);
        chatMensajes = (ms || []).slice().sort((a, b) =>
          String(a.creado || "").localeCompare(String(b.creado || "")) || (a.id - b.id));
        chatLecturas = Object.fromEntries((lect || []).map(l => [l.conv, l.visto]));
      })().finally(() => { chatCargaEnVuelo = null; });
    }
    return chatCargaEnVuelo;
  }

  const noLeidos = conv => {
    const visto = Date.parse(chatLecturas[conv] || "") || 0;
    return chatMensajes.filter(m =>
      convDe(m) === conv && m.autor_id !== usuario.id && (Date.parse(m.creado || "") || 0) > visto).length;
  };

  function pintarChatBadge() {
    const badge = $("chat-badge");
    if (!badge || !usuario) return;
    const enGrupoB = !state || !state.perfil || state.perfil.en_grupo !== false;
    const convs = new Set([...(enGrupoB ? ["grupo"] : []), ...chatMensajes.filter(m => m.destinatario_id).map(convDe)]);
    let total = 0;
    convs.forEach(c => { total += noLeidos(c); });
    badge.hidden = !total;
    badge.textContent = total > 9 ? "9+" : String(total);
  }

  // Al entrar: contar lo no leído para el numerito, y revisarlo cada minuto
  function arrancarChat() {
    cargarChat().then(pintarChatBadge).catch(() => {});
    if (chatBadgeTimer) clearInterval(chatBadgeTimer);
    chatBadgeTimer = setInterval(() => {
      if (!usuario || document.hidden) return;
      cargarChat().then(pintarChatBadge).catch(() => {});
    }, 60000);
  }

  async function irChat(conv) {
    chatConv = conv || null;
    mostrar("chat", { kicker: "Equipo Max Power", titulo: "💬 Mensajes", volver: true, nuevo: false });
    $("chat-panel").innerHTML = '<p class="cal-sin-eventos">Cargando…</p>';
    try {
      await refrescarChat(true);
    } catch {
      $("chat-panel").innerHTML = '<p class="cal-sin-eventos">No se pudo cargar el chat — revisa la señal. ' +
        '<button type="button" class="accion secundaria" id="chat-reintentar">Reintentar</button></p>';
      $("chat-reintentar").addEventListener("click", () => irChat(chatConv));
      return;
    }
    if (chatTimer) clearInterval(chatTimer);
    // Mientras el chat esté abierto, se refresca solo cada 6 segundos
    chatTimer = setInterval(() => {
      if ($("vista-chat").hidden) { clearInterval(chatTimer); chatTimer = null; return; }
      refrescarChat(false).catch(() => {});
    }, 6000);
  }

  async function refrescarChat(completo) {
    await cargarChat();
    if (chatConv && noLeidos(chatConv)) {
      DB.marcarLeido(chatConv).catch(() => {});
      chatLecturas[chatConv] = new Date().toISOString();
    }
    if (completo || !$("chat-hilo")) pintarChat();
    else if (chatConv) {
      // Solo se actualizan las burbujas: lo que estés escribiendo no se toca
      const hilo = $("chat-hilo");
      const abajo = hilo.scrollHeight - hilo.scrollTop - hilo.clientHeight < 80;
      hilo.innerHTML = burbujasHTML();
      if (abajo) hilo.scrollTop = hilo.scrollHeight;
    } else pintarChat();
    pintarChatBadge();
  }

  const horaCorta = iso => {
    if (!iso) return "";
    const d = new Date(iso);
    return d.toLocaleTimeString(LOCALE, { hour: "numeric", minute: "2-digit" });
  };
  const diaCorto = iso => {
    if (!iso) return "";
    const d = new Date(iso);
    return d.toLocaleDateString(LOCALE, { weekday: "short", day: "numeric", month: "short" });
  };

  function burbujasHTML() {
    const del = chatMensajes.filter(m => convDe(m) === chatConv);
    if (!del.length) return '<p class="cal-sin-eventos">Todavía no hay mensajes — escribe el primero.</p>';
    let ultimoDia = "";
    return del.map(m => {
      const mio = m.autor_id === usuario.id;
      const dia = String(m.creado || "").slice(0, 10);
      const sep = dia && dia !== ultimoDia
        ? '<div class="chat-dia">' + esc(diaCorto(m.creado)) + '</div>' : "";
      ultimoDia = dia || ultimoDia;
      const quien = !mio && chatConv === "grupo"
        ? '<span class="burbuja-quien">' + esc(state.nombrePorId[m.autor_id] || "") + '</span>' : "";
      return sep + '<div class="burbuja' + (mio ? " mia" : "") + '">' + quien
        + '<span class="burbuja-texto">' + esc(m.texto) + '</span>'
        + '<span class="burbuja-hora">' + horaCorta(m.creado) + '</span></div>';
    }).join("");
  }

  function pintarChat() {
    const panel = $("chat-panel");
    const equipo = (state.equipo || []).filter(u => u.activo && u.id !== usuario.id);

    const enGrupo = !state.perfil || state.perfil.en_grupo !== false;

    // ---- Lista de conversaciones ----
    if (!chatConv) {
      const fila = (clave, icono, nombre, sub) => {
        const n = noLeidos(clave);
        const ult = chatMensajes.filter(m => convDe(m) === clave).slice(-1)[0];
        const prev = ult ? (ult.autor_id === usuario.id ? "Tú: " : "") + ult.texto : sub;
        return '<button class="chat-conv" data-conv="' + esc(clave) + '">'
          + '<span class="chat-conv-icono">' + icono + '</span>'
          + '<span class="chat-conv-info"><span class="chat-conv-nombre">' + esc(nombre) + '</span>'
          + '<span class="chat-conv-prev">' + esc(String(prev).slice(0, 60)) + '</span></span>'
          + (n ? '<span class="chat-no-leidos">' + (n > 9 ? "9+" : n) + '</span>' : "")
          + '</button>';
      };
      panel.innerHTML = '<div class="cal-panel-card chat-lista">'
        + (enGrupo ? fila("grupo", "👥", "Grupo Max Power", "Mensajes para el equipo de obra") : "")
        + equipo.map(u => fila(u.id, "👤", u.nombre, "Mensaje privado — solo lo ven ustedes dos")).join("")
        + '</div>';
      panel.querySelectorAll(".chat-conv").forEach(b =>
        b.addEventListener("click", () => irChat(b.dataset.conv)));
      return;
    }

    // ---- Una conversación abierta ----
    const nombre = chatConv === "grupo" ? "👥 Grupo Max Power"
      : "👤 " + (state.nombrePorId[chatConv] || "Privado");
    panel.innerHTML = '<div class="cal-panel-card chat-caja">'
      + '<div class="chat-cabeza"><button id="chat-atras" class="btn-volver" title="Conversaciones">‹</button>'
      + '<span class="chat-titulo">' + esc(nombre) + '</span>'
      + (chatConv !== "grupo" ? '<span class="chat-priv">🔒 privado</span>' : "")
      + '</div>'
      + '<div id="chat-hilo" class="chat-hilo" data-no-i18n>' + burbujasHTML() + '</div>'
      + '<form id="chat-form" class="chat-form">'
      + '<input name="texto" type="text" placeholder="Escribe un mensaje…" autocomplete="off" maxlength="500">'
      + '<button type="submit" class="chat-enviar" title="Enviar">➤</button>'
      + '</form></div>';

    const hilo = $("chat-hilo");
    hilo.scrollTop = hilo.scrollHeight;
    $("chat-atras").addEventListener("click", () => irChat(null));
    $("chat-form").addEventListener("submit", async e => {
      e.preventDefault();
      const caja = e.target.elements.texto;
      const texto = caja.value.trim();
      if (!texto) return;
      caja.value = "";
      try {
        await DB.enviarMensaje(texto, chatConv === "grupo" ? null : chatConv);
        await refrescarChat(false);
        hilo.scrollTop = hilo.scrollHeight;
      } catch (err) { avisar("No se pudo enviar: " + err.message, true); caja.value = texto; }
    });
  }

  // ============================================================
  // 🤖 EL ASISTENTE — el chat con el cerebro de la compañía
  // Cada persona tiene su propia conversación. El servidor decide qué
  // puede ver cada quien según su token: el equipo nunca recibe dinero.
  // ============================================================
  let asisMsgs = [];
  let asisPensando = false;

  function asisLlave() { return "mxp_asistente_" + (DB.uid() || "x"); }
  function asisCargar() {
    try { asisMsgs = JSON.parse(localStorage.getItem(asisLlave())) || []; }
    catch { asisMsgs = []; }
  }
  function asisGuardar() {
    // Se guardan los últimos 40 para que no crezca sin fin
    try { localStorage.setItem(asisLlave(), JSON.stringify(asisMsgs.slice(-40))); } catch { /* lleno */ }
  }

  const ASIS_SUGERENCIAS_DUENO = [
    "¿Cómo va el dinero de Mirabella?",
    "¿Qué facturas llevan más días sin cobrar?",
    "¿Qué se me está olvidando esta semana?",
  ];
  const ASIS_SUGERENCIAS_EQUIPO = [
    "¿Cómo reporto mis horas de un Change Order?",
    "¿Qué tengo agendado esta semana?",
    "¿Qué calibre lleva un breaker de 50 amperes?",
  ];

  function irAsistente() {
    mostrar("asistente", { kicker: "Max Power", titulo: "🤖 Asistente", volver: true, nuevo: false });
    if (!asisMsgs.length) asisCargar();
    pintarAsistente();
  }

  function pintarAsistente() {
    const sugerencias = usuario.finanzas ? ASIS_SUGERENCIAS_DUENO : ASIS_SUGERENCIAS_EQUIPO;
    const burbujas = asisMsgs.map(m => `
      <div class="burbuja${m.rol === "user" ? " mia" : ""}">
        <span class="burbuja-quien">${m.rol === "user" ? esc(usuario.nombre.split(" ")[0]) : "🤖 Asistente"}</span>
        <span class="burbuja-texto">${esc(m.texto)}</span>
      </div>`).join("");

    $("asistente-panel").innerHTML = `
      <div class="cal-panel-card chat-caja">
        <div class="chat-cabeza">
          <span class="chat-titulo">🤖 Asistente de Max Power</span>
          <span class="chat-priv">${usuario.finanzas ? "ve todo" : "sin dinero"}</span>
        </div>
        <p class="modal-nota" style="margin:.1rem 0 .4rem">
          ${usuario.finanzas
            ? "Pregúntale por tus proyectos, el dinero, las horas o el calendario. También puedes dictarle para que guarde gastos, horas o materiales."
            : "Pregúntale cómo hacer algo en la app, o dile tus horas y el material que falta para que él lo anote. De dinero no sabe nada — eso lo lleva Edgar."}
        </p>
        <div class="chat-hilo" id="asis-hilo">
          ${burbujas || `<p class="cal-sin-eventos">Escríbele abajo. Está para ayudarte.</p>`}
          ${asisPensando ? `<div class="burbuja"><span class="burbuja-texto">✍️ pensando…</span></div>` : ""}
        </div>
        ${!asisMsgs.length ? `<div class="chat-sugerencias">
          ${sugerencias.map(x => `<button type="button" class="asis-sug">${esc(x)}</button>`).join("")}
        </div>` : ""}
        <form class="chat-form" id="asis-form" autocomplete="off">
          <input id="asis-texto" type="text" placeholder="Escribe tu pregunta…" ${asisPensando ? "disabled" : ""}>
          <button type="submit" class="chat-enviar" title="Enviar" ${asisPensando ? "disabled" : ""}>➤</button>
        </form>
        ${asisMsgs.length ? `<button type="button" class="accion secundaria" id="asis-limpiar" style="margin-top:.4rem">🧹 Empezar de nuevo</button>` : ""}
      </div>`;

    const hilo = $("asis-hilo");
    if (hilo) hilo.scrollTop = hilo.scrollHeight;

    $("asis-form").addEventListener("submit", e => {
      e.preventDefault();
      const t = $("asis-texto").value.trim();
      if (t) asisEnviar(t);
    });
    $("asistente-panel").querySelectorAll(".asis-sug").forEach(b => {
      b.addEventListener("click", () => asisEnviar(b.textContent));
    });
    const limpiar = $("asis-limpiar");
    if (limpiar) limpiar.addEventListener("click", () => {
      if (!confirm("¿Borrar esta conversación y empezar de nuevo?")) return;
      asisMsgs = []; asisGuardar(); pintarAsistente();
    });
    const caja = $("asis-texto");
    if (caja && !asisPensando) caja.focus();
  }

  async function asisEnviar(texto) {
    if (asisPensando) return;
    asisMsgs.push({ rol: "user", texto });
    asisPensando = true;
    asisGuardar();
    pintarAsistente();
    try {
      const r = await DB.preguntarAsistente(asisMsgs);
      if (r && r.respuesta) asisMsgs.push({ rol: "assistant", texto: r.respuesta });
      else if (r && r.error === "sin_llave") asisMsgs.push({ rol: "assistant", texto: "Todavía no me han conectado la llave del asistente. Edgar tiene que ponerla en Supabase (ANTHROPIC_API_KEY)." });
      else asisMsgs.push({ rol: "assistant", texto: "No pude contestar eso. Inténtalo otra vez en un momento." });
    } catch (err) {
      asisMsgs.push({ rol: "assistant", texto: "No hay conexión con el asistente ahora mismo. " + err.message });
    }
    asisPensando = false;
    asisGuardar();
    pintarAsistente();
  }

  $("btn-asistente").addEventListener("click", irAsistente);
  $("btn-chat").addEventListener("click", () => irChat(chatConv));

  // 🚀 Arranque: lo que falta para empezar (mismos registros que 🛒)
  function arranqueHTML(p) {
    if (!["enviado", "aprobado", "ejecucion", "pausa"].includes(p.estado)) return "";
    const matsFalta = (state.materiales || []).filter(m => m.proyecto === p.id && m.estado === "falta");
    const gests = (state.gestiones || []).filter(g => g.proyecto === p.id && !g.hecha);
    if (!matsFalta.length && !gests.length) return "";
    const filasM = matsFalta.map(m => `
      <div class="mat-item falta">
        <span class="mat-icono">🛒</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(m.descripcion))}${m.cantidad ? ` <span class="mat-cant">— ${esc(sinMontos(m.cantidad))}</span>` : ""}</span>
          <span class="alcance-estado">material por comprar</span>
        </span>
      </div>`).join("");
    const filasG = gests.map(g => `
      <div class="mat-item falta">
        <span class="mat-icono">📌</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(g.descripcion))}</span>
          <span class="alcance-estado">gestión pendiente · ${esc(g.autor)}</span>
        </span>
        ${usuario.editar ? `<button class="accion btn-gestion-hecha-ficha" data-id="${g.id}">✓ Hecha</button>` : ""}
      </div>`).join("");
    return `
      <div class="detalle-seccion">
        <h3>🚀 Arranque — lo que falta para empezar</h3>
        ${filasM}${filasG}
        <button type="button" class="accion secundaria btn-ir-materiales" data-id="${esc(p.id)}">Ver en Materiales ›</button>
      </div>`;
  }

  // Ayuda externa: contratados puntuales sin cuenta en la app (SOLO dueño)
  function externosHTML(p) {
    if (!usuario.finanzas) return "";
    const lista = (state.externos || []).filter(x => x.proyecto === p.id);
    const filas = lista.map(x => `
      <div class="alcance-item">
        <span class="alcance-tipo">${x.tipo === "horas" && x.horas ? esc(x.horas) + "h" : "AJUSTE"}</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(x.descripcion)}</span>
          <span class="alcance-estado">${x.fecha ? fechaBonita(x.fecha) : ""}</span>
        </span>
        <span class="mat-precio">${fmt(x.costo)}</span>
        <button type="button" class="insp-borrar btn-ext-borrar" data-id="${x.id}" title="Eliminar">🗑</button>
      </div>`).join("");
    return `
      <div class="detalle-seccion">
        <h3>Ayuda externa (por día o por ajuste)</h3>
        ${filas || `<span class="sin-docs">Sin trabajos externos anotados.</span>`}
        <button type="button" class="accion secundaria btn-agregar-ext">+ Anotar trabajo externo</button>
        <form class="cal-form form-ext" hidden>
          ${(state.ayudantes || []).filter(a => a.activo).length ? `
          <label>Ayudante de tu nómina (opcional — usa su tarifa sola)
            <select name="ayudante">
              <option value="">— Escribir libre —</option>
              ${(state.ayudantes || []).filter(a => a.activo).map(a =>
                `<option value="${a.id}" data-nombre="${esc(a.nombre)}" data-tarifa="${a.costoHora}">${esc(a.nombre)} — ${fmt(a.costoHora)}/h</option>`).join("")}
            </select>
          </label>` : ""}
          <label>Quién / qué hizo
            <input name="descripcion" type="text" required placeholder="Ej: Pedro — ayudante, demolición 2 días" autocomplete="off">
          </label>
          <div class="modal-fila">
            <label>Tipo
              <select name="tipo">
                <option value="ajuste">Por ajuste (precio cerrado)</option>
                <option value="horas">Por horas / por día</option>
              </select>
            </label>
            <label>Fecha
              <input name="fecha" type="date">
            </label>
          </div>
          <div class="modal-fila">
            <label>Horas (si fue por horas)
              <input name="horas" type="number" min="0" step="0.5" placeholder="Ej: 16">
            </label>
            <label>Costo total ($)
              <input name="costo" type="number" min="0" step="0.01" inputmode="decimal" required placeholder="Ej: 300">
            </label>
          </div>
          <p class="modal-nota">Esto entra como gasto del proyecto y se resta del margen.
          El trabajador NO necesita cuenta en la app.</p>
          <button type="submit" class="accion">Guardar</button>
        </form>
      </div>`;
  }

  function rfisHTML(p) {
    if (!p.rfis || !p.rfis.length) return "";
    const items = p.rfis.map(r => `
      <div class="alcance-item">
        <span class="alcance-tipo rfi">RFI</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(r.titulo))}</span>
          <span class="alcance-estado">${esc(r.estado || "")}</span>
        </span>
        ${r.ruta ? `<a class="doc-link" href="#" data-docruta="${esc(r.ruta)}" target="_blank" rel="noopener">📄 Ver</a>`
          : urlSegura(r.url) ? `<a class="doc-link" href="${esc(urlSegura(r.url))}" target="_blank" rel="noopener">📄 Ver</a>` : ""}
      </div>`).join("");
    return `<div class="detalle-seccion"><h3>RFIs</h3>${items}</div>`;
  }

  function facturasHTML(p) {
    if (!usuario.finanzas || !p.facturas || !p.facturas.length) return "";
    const filas = p.facturas.map(f => `<tr>
        <td>#${esc(f.num)}</td>
        <td>${esc(f.fecha)}</td>
        <td class="r">${fmt(f.monto)}</td>
        <td class="r"><span class="f-estado ${f.pagada ? "pagada" : "pendiente"}">${f.pagada ? "PAGADA" : "PENDIENTE"}</span></td>
      </tr>`).join("");
    const total = p.facturas.reduce((s, f) => s + f.monto, 0);
    return `
      <div class="detalle-seccion">
        <h3>Facturas (QuickBooks)</h3>
        <div class="tabla-envoltura">
          <table class="facturas">
            <thead><tr><th>Nº</th><th>Fecha</th><th class="r">Monto</th><th class="r">Estado</th></tr></thead>
            <tbody>
              ${filas}
              <tr class="total"><td colspan="2">Total facturado</td><td class="r">${fmt(total)}</td><td></td></tr>
            </tbody>
          </table>
        </div>
      </div>`;
  }

  // Selector de estado con flechita — SOLO el dueño.
  // Permite poner cualquier estado directamente, y hasta eliminar.
  function selectorEstadoHTML(p) {
    const opciones = Object.entries(ESTADOS)
      .map(([clave, e]) =>
        `<option value="${clave}"${clave === p.estado ? " selected" : ""}>${e.etiqueta}</option>`)
      .join("");
    // Eliminar YA NO vive aquí: con el dedo, la rueda del selector pasaba
    // por encima de esa opción. Ahora está abajo del todo en la ficha,
    // en su propia "zona de peligro".
    return `<select class="chip-select" data-id="${esc(p.id)}" title="Cambiar estado">
        ${opciones}
      </select>`;
  }

  async function cambiarEstadoDirecto(id, valor, selectEl) {
    const p = proyectos().find(x => x.id === id);
    if (!p) return;
    // Por si quedara un selector viejo en pantalla con la opción de borrar
    if (valor === "__eliminar") {
      selectEl.value = p.estado;
      await eliminarProyectoConPalabra(id);
      return;
    }
    const cambios = { estado: valor };
    if (valor === "ejecucion" && !p.fase) cambios.fase = "mobilizacion";
    try {
      await DB.cambiarProyecto(id, cambios);
      p.estado = valor;
      if (cambios.fase) p.fase = cambios.fase;
      refrescarVistaProyecto(id);
      avisar(`Estado: ${ESTADOS[valor].etiqueta} ✓`);
    } catch (err) {
      selectEl.value = p.estado;
      avisar("No se pudo cambiar: " + err.message, true);
    }
  }

  function accionesHTML(p) {
    if (!usuario.editar) return "";
    const b = [];
    if (p.estado === "enviado")
      b.push(`<button class="accion" data-accion="aprobar" data-id="${esc(p.id)}">✓ Marcar aprobado</button>`);
    if (p.estado === "aprobado")
      b.push(`<button class="accion" data-accion="iniciar" data-id="${esc(p.id)}">▶ Iniciar ejecución</button>`);
    if (p.estado === "ejecucion") {
      const idx = Math.max(0, FASES.findIndex(f => f.clave === p.fase));
      if (idx > 0)
        b.push(`<button class="accion secundaria" data-accion="fase-atras" data-id="${esc(p.id)}">◀ Fase anterior</button>`);
      if (idx < FASES.length - 1)
        b.push(`<button class="accion" data-accion="fase-adelante" data-id="${esc(p.id)}">Fase siguiente ▶</button>`);
      else
        b.push(`<button class="accion" data-accion="completar" data-id="${esc(p.id)}">✓ Marcar completado</button>`);
      b.push(`<button class="accion secundaria" data-accion="pausar" data-id="${esc(p.id)}">⏸ Pausar</button>`);
    }
    if (p.estado === "pausa")
      b.push(`<button class="accion" data-accion="iniciar" data-id="${esc(p.id)}">▶ Reanudar ejecución</button>`);
    if (p.estado === "completado")
      b.push(`<button class="accion secundaria" data-accion="reabrir" data-id="${esc(p.id)}">↩ Reabrir (a ejecución)</button>`);
    // Escribir el alcance: solo el dueño, y en las obras que todavía no se hicieron
    if (usuario.finanzas && ["estimando", "enviado", "aprobado"].includes(p.estado)) {
      // En Estimando es EL siguiente paso: va primero y en azul
      const sinSow = !p.ref || /por definir/i.test(p.ref);
      const btn = `<button class="accion${p.estado === "estimando" || sinSow ? "" : " secundaria"}" data-accion="alcance" data-id="${esc(p.id)}">Escribir el alcance</button>`;
      if (p.estado === "estimando") b.unshift(btn); else b.push(btn);
    }
    return b.length
      ? `<div class="detalle-seccion"><h3>Acciones</h3><div class="acciones">${b.join("")}</div></div>`
      : "";
  }

  // Piezas que comparten la tarjeta resumida y la ficha completa
  function cabeceraHTML(p, conSelector) {
    const fase = p.estado === "ejecucion" ? FASES.find(f => f.clave === p.fase) : null;
    const miniFase = fase ? `<span class="mini-fase">${fase.etiqueta}</span>` : "";
    return `
      <div class="proyecto-head">
        <div class="proyecto-titulo">
          <div>
            <h2>${esc(p.nombre)}</h2>
            <div class="proyecto-dir">📍 ${esc(p.direccion)}</div>
            <div class="proyecto-cliente">Cliente: <strong>${esc(p.cliente)}</strong> · vía ${esc(p.via)}${p.origen ? ` · 🧲 ${esc(p.origen)}` : ""}</div>
          </div>
          <div class="chips-col">
            ${conSelector && usuario.editar ? selectorEstadoHTML(p) : chipHTML(p.estado)}
            ${miniFase}
          </div>
        </div>
      </div>`;
  }

  function avisoObraHTML(p) {
    const pensObra = pendientesAbiertos(p.id);
    return pensObra.length
      ? `<div class="aviso-obra">🔴 ${pensObra.map(x => `${esc(sinMontos(x.descripcion))} <span class="aviso-obra-autor">(${esc(x.autor || "")}, ${esc(x.fecha)})</span>`).join(" · ")}</div>`
      : "";
  }

  // Aviso rojo si el proyecto tiene materiales por comprar
  function avisoMaterialesHTML(p) {
    const n = (state.materiales || [])
      .filter(m => m.proyecto === p.id && m.estado === "falta").length;
    return n
      ? `<div class="aviso-obra">🛒 Verificar lista de materiales — ${n} por comprar</div>`
      : "";
  }

  // Sube la casilla "cobrado" del proyecto cuando entra dinero. Pregunta
  // siempre y enseña el antes y el después: esa casilla la lleva Edgar a
  // mano y ahí está el descuadre que encontró la auditoría.
  async function sumarACobrado(p, monto, deQue) {
    if (!p || !monto || typeof p.contrato !== "number") return;
    const antes = typeof p.cobrado === "number" ? p.cobrado : 0;
    const despues = Math.round((antes + monto) * 100) / 100;
    if (!confirm(
      `¿Le sumo ${fmt(monto)} de ${deQue} a lo cobrado del proyecto?\n\n` +
      `Cobrado ahora: ${fmt(antes)}\nQuedaría en: ${fmt(despues)}\n\n` +
      `(Si ese dinero ya estaba contado, dile que NO.)`)) return;
    await DB.cambiarFinanzas(p.id, { cobrado: despues });
  }

  function avisoFacturasHTML(p) {
    if (!usuario.finanzas) return "";
    const pend = facturasPendientes(p);
    return pend.length
      ? `<div class="aviso-pendiente">⚠ Factura sin pagar: ${pend.map(f => `#${esc(f.num)} ${fmt(f.monto)}${f.id && usuario.editar ? `
          <button type="button" class="chip-cobrar factura-pagada" data-id="${f.id}" data-num="${esc(f.num)}" data-monto="${f.monto}"
            title="Marcarla como COBRADA — es lo que cuadra el dinero de la app con el banco">✓ cobrada</button>` : ""}`).join(", ")}</div>`
      : "";
  }

  function franjaDineroHTML(p) {
    if (!usuario.finanzas) return "";
    const falta = (typeof p.contrato === "number" && typeof p.cobrado === "number")
      ? p.contrato - p.cobrado : null;
    const pct = (typeof p.contrato === "number" && typeof p.cobrado === "number" && p.contrato > 0)
      ? Math.round((p.cobrado / p.contrato) * 100) : null;
    const barra = pct === null ? "" :
      `<div class="barra"><div class="barra-relleno" style="width:${Math.min(pct, 100)}%"></div></div>
       <div class="barra-texto">${pct}% cobrado</div>`;
    // ¿"Cobrado" cuadra con las facturas que están marcadas pagadas?
    // Son dos casillas distintas que nadie mantenía juntas — de ahí salió
    // el descuadre que encontró la auditoría.
    const pagadas = (p.facturas || [])
      .filter(f => f.pagada && String(f.num) !== "1110")
      .reduce((s, f) => s + (Number(f.monto) || 0), 0);
    // OJO con los ABONOS: una factura puede estar cobrada a medias (Mirabella
    // tiene $10,106 abonados sobre una de $17,513). La app no guarda abonos,
    // así que "cobrado" puede ser mayor que las facturas pagadas sin que eso
    // sea un error. Solo se avisa cuando de verdad no cuadra:
    //   · cobrado por DEBAJO de lo que ya está pagado → falta contar dinero
    //   · cobrado por ENCIMA de TODAS las facturas juntas → ese dinero no
    //     tiene ninguna factura detrás
    const todas = (p.facturas || [])
      .filter(f => String(f.num) !== "1110")
      .reduce((s, f) => s + (Number(f.monto) || 0), 0);
    const cob = typeof p.cobrado === "number" ? p.cobrado : null;
    let avisoCobrado = "";
    if (cob !== null && p.facturas && p.facturas.length) {
      if (cob < pagadas - 0.02) {
        avisoCobrado = `<div class="rent-humo">⚠ "Cobrado" dice ${fmt(cob)} pero las facturas ya marcadas cobradas suman ${fmt(pagadas)} —
          faltan ${fmt(Math.round((pagadas - cob) * 100) / 100)} por contar.</div>`;
      } else if (cob > todas + 0.02) {
        avisoCobrado = `<div class="rent-humo">⚠ "Cobrado" dice ${fmt(cob)} y todas las facturas de este proyecto juntas suman ${fmt(todas)} —
          sobran ${fmt(Math.round((cob - todas) * 100) / 100)} sin ninguna factura detrás.</div>`;
      }
    }
    return `
      <div class="proyecto-money">
        <div class="money-item"><div class="money-label">Contrato</div><div class="money-num contrato">${fmt(p.contrato)}</div></div>
        <div class="money-item"><div class="money-label">Cobrado</div><div class="money-num cobrado">${fmt(p.cobrado)}</div></div>
        <div class="money-item"><div class="money-label">Falta</div><div class="money-num falta">${fmt(falta)}</div></div>
      </div>
      ${barra}
      ${avisoCobrado}`;
  }

  // Tarjeta RESUMIDA de la lista: al tocarla se abre la ficha
  function tarjetaResumenHTML(p) {
    const av = avanceObra(p.id);
    const urg = (state.pendientes || []).some(x =>
      x.proyecto === p.id && !x.resuelto && x.prioridad === "urgente");
    const resumen = av && p.estado !== "completado" ? `${av.pct}%` : "";
    return `
      <details class="chk-det proy-det${urg ? " con-urgentes" : ""}" data-id="${esc(p.id)}"${listaAbiertos.has(p.id) ? " open" : ""}>
        <summary>
          <span class="chk-nombre">${esc(p.nombre)}</span>
          <span class="chk-avance">${urg ? "🔴 " : ""}${resumen}</span>
        </summary>
        <div class="chk-cuerpo">
          <article class="proyecto" data-id="${esc(p.id)}">
            ${cabeceraHTML(p, false)}
            ${avisoObraHTML(p)}
            ${avisoMaterialesHTML(p)}
            ${avisoFacturasHTML(p)}
            ${franjaDineroHTML(p)}
            ${proximoCobroHTML(p)}
            ${av && p.estado !== "completado"
              ? `<div class="avance-mini">🔧 Avance de obra: <strong>${av.pct}%</strong> (${av.hechos} de ${av.total} puntos)</div>`
              : ""}
            <div class="abrir-ficha">Ver proyecto completo <span class="cat-flecha">›</span></div>
          </article>
        </div>
      </details>`;
  }

  // FICHA completa: la pantalla dedicada a un solo proyecto
  function fichaProyectoHTML(p) {
    const linksDocs = (p.docs || [])
      .map(d => `<span class="doc-fila"><a class="doc-link" ${d.ruta ? `href="#" data-docruta="${esc(d.ruta)}"` : `href="${esc(urlSegura(d.url) || "#")}"`} target="_blank" rel="noopener">📄 ${esc(d.titulo)}${d.ruta ? "" : ` <span class="doc-drive-tag">Drive</span>`}</a>${d.id ? `
        ${p.portalCompleto ? `<span class="cl-chip-aprobado" title="Luz verde encendida: con acceso completo el cliente ve TODOS los documentos, estén marcados o no">🟢 lo ve</span>` : `
        <button type="button" class="doc-cliente doc-portal${d.portal ? " on" : ""}" data-id="${d.id}" data-portal="${d.portal ? 1 : 0}"
          title="${d.portal ? "El cliente SÍ ve este documento — toca para ocultarlo" : "El cliente NO lo ve — toca para mostrárselo"}">${d.portal ? "👁 cliente" : "🚫 cliente"}</button>`}${(d.portal || p.portalCompleto) && docFirmable(d) ? `
        ${!d.firmadoEl && d.vistoEl ? `<span class="cl-chip-aprobado">👁 visto ${esc(d.vistoEl)}</span>` : ""}
        ${d.firmadoEl ? `<span class="cl-chip-aprobado">🖊 firmó ${esc(d.firmaNombre || "")} · ${esc(d.firmadoEl)}</span>` : `
        <button type="button" class="doc-cliente${d.pideFirma ? " on" : ""} doc-firma" data-id="${d.id}" data-pide="${d.pideFirma ? 1 : 0}"
          title="${d.pideFirma ? "Le está pidiendo FIRMA al cliente (nombre + firma con el dedo) — toca para quitarla" : "Pedirle al cliente que lo FIRME (nombre + firma con el dedo, queda de respaldo)"}">🖊 firma</button>`}
        ${d.contrafirmaEl ? `<span class="cl-chip-aprobado">✒️ contrafirmado ${esc(d.contrafirmaEl)}</span>`
          : (usuario.finanzas && (d.pideFirma || d.firmadoEl)) ? `
        <button type="button" class="doc-cliente doc-contrafirma" data-id="${d.id}" data-titulo="${esc(d.titulo)}"
          title="Firmarlo tú también: tu firma sale en el certificado junto a la del cliente">✒️ firmar yo</button>` : ""}
        ${d.aprobadoEl ? `<span class="cl-chip-aprobado">✔ aprobó ${esc(d.aprobadoEl)}</span>` : (d.firmadoEl || d.pideFirma) ? "" : `
        <button type="button" class="doc-cliente${d.pideAprobacion ? " on" : ""} doc-aprobacion" data-id="${d.id}" data-pide="${d.pideAprobacion ? 1 : 0}"
          title="${d.pideAprobacion ? "Le está pidiendo aprobación al cliente — toca para quitarla" : "Pedirle al cliente que lo apruebe con un toque"}">✍️ aprobación</button>`}` : ""}` : ""}</span>`)
      .join("");
    // El dueño siempre ve la sección, con el botón para agregar más
    const docs = usuario.finanzas
      ? `<div class="detalle-seccion">
           <h3>Documentos</h3>
           ${p.portalCompleto ? `<div class="aviso-luzverde">🟢 Luz verde encendida: el cliente ve <strong>todos</strong> estos documentos, aunque no estén marcados 👁. Lo que subas aquí se le publica solo.</div>` : ""}
           <div class="detalle-docs">${linksDocs || `<span class="sin-docs">Este proyecto no tiene documentos todavía.</span>`}</div>
           <button type="button" class="accion secundaria btn-agregar-doc">+ Agregar documento</button>
           <form class="cal-form form-doc" hidden>
             <div class="modal-fila">
               <label>Tipo
                 <select name="clase">
                   <option value="doc">Documento</option>
                   <option value="rfi">RFI</option>
                 </select>
               </label>
               <label>Título
                 <input name="titulo" type="text" required placeholder="Ej: SOW firmado" autocomplete="off">
               </label>
             </div>
             <label>Archivo PDF (recomendado — vive en la app, sin permisos de Drive)
               <input name="archivo" type="file" accept="application/pdf">
             </label>
             <label>… o pega un enlace de Drive
               <input name="url" type="url" placeholder="https://drive.google.com/…" autocomplete="off">
             </label>
             <button type="submit" class="accion">Guardar documento</button>
           </form>
         </div>
         <div class="detalle-seccion">
           <h3>🌐 Portal del cliente</h3>
           <p class="modal-nota">${p.portalCompleto
             ? `🟢 <strong>Luz verde encendida:</strong> el cliente ve TODOS los documentos —contratos y Change Orders incluidos—,
                todas las fotos y todos los videos, estén marcados 👁 o no. Lo que subas a este proyecto se le publica solo.`
             : `El cliente ve: etapa, checklist con su %, inspecciones, próximos días de trabajo y los documentos con 👁.
                Los RFI salen siempre; los CONTRATOS nunca salen (tienen precios) a menos que tú los marques.`}
           El dinero solo sale si tú prendes el botón 💵 — pensado para clientes directos, no para trabajos vía contratista.</p>
           ${(state.visitasPortal || {})[p.id] ? `
           <p class="modal-nota">👀 Última visita del cliente: <strong>${esc(String(state.visitasPortal[p.id]).slice(0, 16).replace("T", " "))}</strong> (hora universal)</p>` : `
           <p class="modal-nota">👀 El cliente todavía no ha abierto su portal.</p>`}
           ${p.portalToken ? `
           <div class="modal-botones">
             <p class="modal-nota">✉️ Email del cliente: <strong>${esc(p.clienteEmail || "sin anotar")}</strong>
               <button type="button" class="insp-borrar" id="btn-cliente-email" data-id="${esc(p.id)}" data-email="${esc(p.clienteEmail || "")}"
                 title="Anotar o corregir el email (para mandarle su copia firmada y avisos)">✎</button></p>
             <button type="button" class="accion secundaria" id="btn-portal-copiar" data-token="${esc(p.portalToken)}">🔗 Copiar el link del cliente</button>
             <button type="button" class="accion secundaria" id="btn-portal-regenerar">♻ Regenerar la llave</button>
             <button type="button" class="doc-cliente${p.portalDinero ? " on" : ""}" id="btn-portal-dinero"
               title="${p.portalDinero ? "El cliente SÍ ve su contrato, pagos y facturas — toca para ocultarlos" : "El cliente NO ve dinero — toca para mostrarle su contrato, pagos y facturas"}">${p.portalDinero ? "💵 dinero: SÍ lo ve" : "💵 dinero: NO lo ve"}</button>
             <button type="button" class="doc-cliente${p.portalCompleto ? " on" : ""}" id="btn-portal-completo"
               title="${p.portalCompleto ? "Luz verde: el cliente ve TODOS los documentos, fotos y videos — toca para volver al modo uno-a-uno" : "Toca para darle luz verde: verá TODOS los documentos (contratos y CO), fotos y videos sin marcarlos uno a uno"}">${p.portalCompleto ? "🟢 acceso completo: SÍ" : "⚪ acceso completo: NO"}</button>
           </div>` : `<p class="cal-sin-eventos">Corre el SQL del portal para crearle la llave a este proyecto.</p>`}
           <h4 class="portal-sub">🛋 Decisiones del cliente ("te toca a ti")</h4>
           ${(state.decisiones || []).filter(d => d.proyecto === p.id).map(d => `
             <div class="eq-reporte${d.hecha ? "" : " eq-pide"}" data-id="${d.id}">
               <span class="alcance-info">
                 <span class="alcance-titulo">${d.hecha ? "✅ " : "🛋 "}${esc(d.texto)}</span>
                 ${d.fechaLimite && !d.hecha ? `<span class="alcance-estado">⏰ la necesitamos antes del ${esc(d.fechaLimite)}</span>` : ""}
               </span>
               ${!d.hecha ? `<button type="button" class="insp-borrar btn-dec-hecha" data-id="${d.id}" title="Marcar decidida">✓</button>` : ""}
               <button type="button" class="insp-borrar btn-dec-borrar" data-id="${d.id}" title="Eliminar">🗑</button>
             </div>`).join("") || `<p class="cal-sin-eventos">Sin decisiones pendientes del cliente.</p>`}
           <form class="cal-form" id="form-decision">
             <div class="modal-fila">
               <label>Qué necesita decidir el cliente
                 <input name="texto" type="text" required placeholder="Ej: elegir el fixture del comedor" autocomplete="off">
               </label>
               <label>Para cuándo (opcional)
                 <input name="fecha" type="date">
               </label>
             </div>
             <button type="submit" class="accion secundaria">+ Agregar decisión</button>
           </form>
         </div>`
      : "";

    return `
      <article class="proyecto ficha abierto" data-id="${esc(p.id)}">
        ${cabeceraHTML(p, true)}
        ${avisoObraHTML(p)}
        ${avisoMaterialesHTML(p)}
        ${avisoFacturasHTML(p)}
        ${franjaDineroHTML(p)}
        ${proximoCobroHTML(p)}
        <div class="proyecto-detalle">
          <div class="detalle-seccion"><h3>Situación</h3><p>${esc(sinMontos(p.estadoDetalle))}</p></div>
          <div class="detalle-seccion"><h3>Próxima acción</h3><p>${esc(sinMontos(p.proximaAccion))}</p></div>
          ${eventosProyectoHTML(p)}
          ${arranqueHTML(p)}
          ${stepperHTML(p)}
          ${horasHTML(p)}
          ${desgloseHTML(p)}
          ${hitosHTML(p)}
          ${rentabilidadHTML(p)}
          ${externosHTML(p)}
          ${rfisHTML(p)}
          ${inspeccionesHTML(p)}
          ${fotosHTML(p)}
          ${accionesHTML(p)}
          ${facturasHTML(p)}
          ${docs}
          <div class="detalle-ref">Ref: ${esc(sinMontos(p.ref))}</div>
          ${zonaPeligroHTML(p)}
        </div>
      </article>`;
  }

  // Zona de peligro: lo único que no se puede deshacer, abajo del todo,
  // lejos de cualquier cosa que se toque a diario.
  function zonaPeligroHTML(p) {
    if (!usuario.finanzas) return "";
    return `
      <div class="detalle-seccion zona-peligro">
        <h3>Zona de peligro</h3>
        <p class="rent-nota">Eliminar este proyecto borra también sus finanzas, hitos,
        facturas, horas del equipo, fotos, documentos y pendientes. No hay papelera.</p>
        <button type="button" class="accion btn-eliminar-proyecto" data-id="${esc(p.id)}">🗑 Eliminar este proyecto</button>
      </div>`;
  }

  // Borrar arrastra 13 tablas en cascada y NO hay papelera: hay que escribir
  // la palabra a propósito, no basta con un "OK".
  async function eliminarProyectoConPalabra(id) {
    const p = proyectos().find(x => x.id === id);
    if (!p) return;
    const escrito = prompt(
      `⚠️ Vas a ELIMINAR "${p.nombre}" para siempre.\n\n` +
      `Se borran también sus finanzas, hitos, facturas, horas del equipo, fotos, ` +
      `documentos y pendientes. Esto NO se puede deshacer.\n\n` +
      `Si es lo que quieres, escribe ELIMINAR (en mayúsculas):`);
    if (escrito === null) return;
    if (escrito.trim().toUpperCase() !== "ELIMINAR") {
      avisar("No se eliminó nada — no escribiste ELIMINAR.");
      return;
    }
    try {
      await DB.eliminarProyecto(id);
      state.proyectos = state.proyectos.filter(x => x.id !== id);
      refrescarVistaProyecto();
      avisar(`"${p.nombre}" eliminado.`);
    } catch (err) {
      avisar("No se pudo eliminar: " + err.message, true);
    }
  }

  // Permisos e inspecciones: todos las ven; el dueño las maneja
  const RES_INSP = {
    programada: { etiqueta: "Programada", icono: "○", clase: "insp-prog" },
    paso:       { etiqueta: "Pasó",       icono: "✓", clase: "insp-paso" },
    fallo:      { etiqueta: "Falló",      icono: "✗", clase: "insp-fallo" }
  };
  const MES_CORTO = ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
  const fechaBonita = iso => {
    if (!iso) return "";
    const [a, m, d] = String(iso).split("-").map(Number);
    return `${d} ${MES_CORTO[m] || ""} ${a}`;
  };

  function inspeccionesHTML(p) {
    const lista = (state.inspecciones || []).filter(i => i.proyecto === p.id);
    const filas = lista.map(i => {
      const r = RES_INSP[i.resultado] || RES_INSP.programada;
      const detalles = [
        i.fecha ? "📅 " + fechaBonita(i.fecha) : "",
        i.permiso ? "Permiso " + esc(i.permiso) : "",
        i.jurisdiccion ? esc(i.jurisdiccion) : "",
        i.notas ? esc(sinMontos(i.notas)) : ""
      ].filter(Boolean).join(" · ");
      const control = usuario.editar
        ? `<select class="insp-resultado" data-id="${i.id}" title="Cambiar resultado">
             ${Object.entries(RES_INSP).map(([clave, x]) =>
               `<option value="${clave}"${clave === i.resultado ? " selected" : ""}>${x.etiqueta}</option>`).join("")}
           </select>
           <button type="button" class="insp-borrar btn-insp-borrar" data-id="${i.id}" data-tipo="${esc(i.tipo)}" title="Eliminar inspección">🗑</button>`
        : `<span class="insp-chip ${r.clase}">${r.etiqueta}</span>`;
      return `<div class="insp-item ${r.clase}">
          <span class="insp-icono">${r.icono}</span>
          <span class="alcance-info">
            <span class="alcance-titulo">Inspección ${esc(i.tipo)}</span>
            <span class="alcance-estado">${detalles}</span>
          </span>
          ${control}
        </div>`;
    }).join("");

    const form = usuario.editar
      ? `<button type="button" class="accion secundaria btn-agregar-insp">+ Agregar inspección</button>
         <form class="cal-form form-insp" hidden>
           <div class="modal-fila">
             <label>Tipo
               <select name="tipo">
                 <option value="Rough">Rough</option>
                 <option value="Underground">Underground</option>
                 <option value="Servicio / Panel">Servicio / Panel</option>
                 <option value="Final">Final</option>
                 <option value="Otra">Otra</option>
               </select>
             </label>
             <label>Fecha (si ya está programada)
               <input name="fecha" type="date">
             </label>
           </div>
           <div class="modal-fila">
             <label>Nº de permiso
               <input name="permiso" type="text" placeholder="Ej: ELE2026-01234" autocomplete="off">
             </label>
             <label>Jurisdicción
               <input name="jurisdiccion" type="text" placeholder="Ej: City of Tampa" autocomplete="off">
             </label>
           </div>
           <label>Notas (opcional)
             <input name="notas" type="text" placeholder="Ej: llamar al inspector antes de las 8am" autocomplete="off">
           </label>
           <button type="submit" class="accion">Guardar inspección</button>
         </form>`
      : "";

    if (!filas && !form) return "";
    return `
      <div class="detalle-seccion">
        <h3>Permisos e inspecciones</h3>
        ${filas || `<span class="sin-docs">Sin inspecciones anotadas todavía.</span>`}
        ${form}
      </div>`;
  }

  // Fotos de obra: las ve y las sube TODO el equipo
  function fotosHTML(p) {
    const fotos = (state.fotos || []).filter(f => f.proyecto === p.id);
    const items = fotos.map(f => `
      <figure class="foto-item">
        ${esVideo(f.ruta) ? `
        <video class="foto-mini foto-video" data-ruta="${esc(f.ruta)}" controls preload="metadata" playsinline></video>` : `
        <a class="foto-enlace" data-ruta="${esc(f.ruta)}" target="_blank" rel="noopener">
          <img class="foto-mini" data-ruta="${esc(f.ruta)}" alt="${esc(f.nota || "Foto de obra")}" loading="lazy">
        </a>`}
        <figcaption class="foto-pie">${f.nota ? esc(sinMontos(f.nota)) + " · " : ""}${esc(f.autor)} ${esc(f.fecha)}${usuario.finanzas ? `
          ${p.portalCompleto ? `
          <span class="cl-chip-aprobado" title="Luz verde encendida: con acceso completo el cliente ve TODAS las fotos, estén marcadas o no">🟢 la ve</span>` : `
          <button type="button" class="doc-cliente foto-cliente${f.portal ? " on" : ""}" data-id="${f.id}" data-portal="${f.portal ? 1 : 0}"
            title="${f.portal ? "El cliente SÍ ve esta foto" : "El cliente NO la ve"}">${f.portal ? "👁" : "🚫"}</button>`}
          <button type="button" class="doc-cliente foto-nota" data-id="${f.id}" data-nota="${esc(f.nota || "")}"
            title="Corregir la descripción de la foto">✎</button>` : (f.autorId === usuario.id ? `
          <button type="button" class="doc-cliente foto-nota" data-id="${f.id}" data-nota="${esc(f.nota || "")}"
            title="Corregir la descripción de tu foto">✎</button>` : "")}</figcaption>
      </figure>`).join("");
    return `
      <div class="detalle-seccion">
        <h3>Fotos de obra</h3>
        ${p.portalCompleto ? `<div class="aviso-luzverde">🟢 Luz verde encendida: el cliente ve <strong>todas</strong> estas fotos, aunque no estén marcadas 👁.</div>` : ""}
        ${items ? `<div class="fotos-grid">${items}</div>` : `<span class="sin-docs">Sin fotos todavía.</span>`}
        <button type="button" class="accion secundaria btn-agregar-foto">📸 Agregar foto o video</button>
        <form class="cal-form form-foto" hidden>
          <label>Foto o video corto (cámara o galería)
            <input name="archivo" type="file" accept="image/*,video/mp4,video/quicktime,video/webm" multiple required>
          </label>
          <label>Nota (opcional)
            <input name="nota" type="text" placeholder="Ej: rough del segundo piso terminado" autocomplete="off">
          </label>
          <button type="submit" class="accion">⬆ Subir foto</button>
        </form>
      </div>`;
  }

  // ¿La ruta es de un video corto (inspección virtual)?
  const esVideo = ruta => /\.(mp4|mov|webm)$/i.test(String(ruta || ""));

  // Solo los SOW y los Change Orders se firman o aprueban;
  // el resto (planos, RFIs...) es consultivo — solo se lee
  const docFirmable = d => /\bsow\b|scope\s*of\s*work|change\s*order|\bco\b|propuesta|contrato|acknowledgment/i.test(String(d.titulo || ""));

  // Achica la foto antes de subirla (los teléfonos sacan fotos enormes)
  async function reducirImagen(archivo) {
    const imagen = await createImageBitmap(archivo);
    const escala = Math.min(1, 1600 / Math.max(imagen.width, imagen.height));
    const lienzo = document.createElement("canvas");
    lienzo.width = Math.round(imagen.width * escala);
    lienzo.height = Math.round(imagen.height * escala);
    lienzo.getContext("2d").drawImage(imagen, 0, 0, lienzo.width, lienzo.height);
    return new Promise((res, rej) =>
      lienzo.toBlob(b => b ? res(b) : rej(new Error("No se pudo procesar")), "image/jpeg", 0.82));
  }

  // ============================================================
  // NIVEL 4 · FICHA DEL PROYECTO (una pantalla para él solo)
  // ============================================================
  function irDetalle(id) {
    const p = proyectos().find(x => x.id === id);
    if (!p) return;
    proyectoActivo = id;
    pintarDetalle();
  }

  function pintarDetalle() {
    const p = proyectos().find(x => x.id === proyectoActivo);
    if (!p) {
      // El proyecto ya no existe (p. ej. se eliminó): volver a la lista
      proyectoActivo = null;
      if (tipoActivo && etapaActiva) irLista(etapaActiva); else irHome();
      return;
    }
    mostrar("detalle", {
      kicker: `${TIPOS[p.tipo] ? TIPOS[p.tipo].etiqueta : ""} · ${ESTADOS[p.estado] ? ESTADOS[p.estado].etiqueta : p.estado}`,
      titulo: p.nombre,
      volver: true,
      nuevo: false
    });
    $detalle.innerHTML = fichaProyectoHTML(p);

    $detalle.querySelectorAll(".accion").forEach(btn => {
      if (btn.dataset.accion)
        btn.addEventListener("click", () => ejecutarAccion(btn.dataset.accion, btn.dataset.id));
    });
    $detalle.querySelectorAll(".chip-select").forEach(sel => {
      sel.addEventListener("change", () => cambiarEstadoDirecto(sel.dataset.id, sel.value, sel));
    });
    $detalle.querySelectorAll(".btn-eliminar-proyecto").forEach(btn => {
      btn.addEventListener("click", () => eliminarProyectoConPalabra(btn.dataset.id));
    });

    // "+ Agregar documento" (solo aparece para el dueño)
    // Portal del cliente: copiar link, regenerar llave, y el 👁 por documento
    const btnEmailCli = $detalle.querySelector("#btn-cliente-email");
    if (btnEmailCli) btnEmailCli.addEventListener("click", async () => {
      const nuevo = prompt("Email del cliente (para mandarle su copia firmada y avisos):", btnEmailCli.dataset.email || "");
      if (nuevo === null) return;
      try {
        await DB.cambiarProyecto(btnEmailCli.dataset.id, { cliente_email: nuevo.trim() || null });
        await recargar(btnEmailCli.dataset.id);
        avisar("✉️ Email del cliente guardado");
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });
    const btnPortalCopiar = $detalle.querySelector("#btn-portal-copiar");
    if (btnPortalCopiar) btnPortalCopiar.addEventListener("click", async () => {
      const base = location.origin + location.pathname.replace(/index\.html?$/, "");
      const link = base + "cliente.html?t=" + btnPortalCopiar.dataset.token;
      try {
        await navigator.clipboard.writeText(link);
        avisar("Link del cliente copiado ✓ — pégalo en WhatsApp");
      } catch {
        prompt("Copia el link del cliente:", link);
      }
    });
    const btnPortalCompleto = $detalle.querySelector("#btn-portal-completo");
    if (btnPortalCompleto) btnPortalCompleto.addEventListener("click", async () => {
      const p = proyectos().find(x => x.id === proyectoActivo);
      if (!p) return;
      if (!p.portalCompleto && !confirm(
        "🟢 ¿Darle a este cliente ACCESO COMPLETO a su proyecto?\n\n" +
        "Verá TODOS los documentos (contratos y change orders incluidos, con sus precios) " +
        "y TODAS las fotos y videos — sin tener que marcarlos uno a uno.\n\n" +
        "Las horas del equipo y las compras de materiales NUNCA salen en el portal.\n" +
        "Solo para clientes directos.")) return;
      try {
        await DB.cambiarProyecto(proyectoActivo, { portal_completo: !p.portalCompleto });
        await recargar();
        avisar(!p.portalCompleto ? "🟢 Luz verde — el cliente ve todo su proyecto" : "De vuelta al modo uno-a-uno (solo lo marcado con 👁)");
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });
    const btnPortalDinero = $detalle.querySelector("#btn-portal-dinero");
    if (btnPortalDinero) btnPortalDinero.addEventListener("click", async () => {
      const p = proyectos().find(x => x.id === proyectoActivo);
      if (!p) return;
      if (!p.portalDinero && !confirm(
        "¿Mostrarle a este cliente su contrato, pagos y facturas en el portal?\n\n" +
        "Solo para proyectos donde tratas DIRECTO con el cliente. " +
        "Si el trabajo va a través de un contratista (Wisdom u otro), déjalo apagado.")) return;
      try {
        await DB.cambiarProyecto(proyectoActivo, { portal_dinero: !p.portalDinero });
        await recargar();
        avisar(!p.portalDinero ? "💵 El cliente ahora VE su contrato y pagos" : "El dinero quedó oculto para el cliente");
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });
    const btnPortalRegen = $detalle.querySelector("#btn-portal-regenerar");
    if (btnPortalRegen) btnPortalRegen.addEventListener("click", async () => {
      if (!confirm("¿Regenerar la llave? El link viejo dejará de funcionar y tendrás que mandarle el nuevo al cliente.")) return;
      const nueva = crypto.randomUUID
        ? crypto.randomUUID().replace(/-/g, "")
        : [...crypto.getRandomValues(new Uint8Array(16))].map(b => b.toString(16).padStart(2, "0")).join("");
      try {
        await DB.cambiarLlavePortal(proyectoActivo, nueva);
        await recargar();
        avisar("Llave nueva ✓ — copia el link otra vez");
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });
    // OJO (arreglado 31-ago): antes este selector era ".doc-cliente:not(...)" y
    // agarraba TAMBIÉN el ✎ de la nota de las fotos. Como la foto y el documento
    // pueden compartir el mismo id, corregir la nota de una foto publicaba un
    // contrato en el portal del cliente. Ahora solo engancha el botón del 👁.
    $detalle.querySelectorAll(".doc-portal").forEach(btn => {
      btn.addEventListener("click", async () => {
        const visible = btn.dataset.portal === "1";
        try {
          await DB.cambiarDocumento(btn.dataset.id, { portal: !visible });
          await recargar();
          avisar(!visible ? "👁 El cliente ahora VE este documento — OJO: en Drive debe estar compartido como 'cualquiera con el enlace' para que pueda abrirlo" : "🚫 Documento oculto para el cliente");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $detalle.querySelectorAll(".doc-firma").forEach(btn => {
      btn.addEventListener("click", async () => {
        const pide = btn.dataset.pide === "1";
        try {
          await DB.cambiarDocumento(btn.dataset.id, { pide_firma: !pide });
          await recargar();
          avisar(!pide ? "🖊 El cliente verá 'Revisar y firmar' en su portal" : "Petición de firma quitada");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    // ✒️ La contrafirma de Edgar: queda registrada y el certificado del PDF
    // sellado muestra las dos firmas (si el cliente firma después, sale ya;
    // el documento queda "firmado por las dos partes" en el portal)
    $detalle.querySelectorAll(".doc-contrafirma").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm(`Vas a firmar "${btn.dataset.titulo}" como:\n\nEdgar Arboleya\nMax Power Electrical Solutions Inc. (EC13016045)\n\nTu firma saldrá en el certificado junto a la del cliente. ¿Firmar?`)) return;
        try {
          await DB.cambiarDocumento(btn.dataset.id, {
            contrafirma_nombre: "Edgar Arboleya",
            contrafirma_el: new Date().toISOString()
          });
          await recargar();
          avisar("✒️ Contrafirmado — tu firma saldrá en el certificado");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $detalle.querySelectorAll(".doc-aprobacion").forEach(btn => {
      btn.addEventListener("click", async () => {
        const pide = btn.dataset.pide === "1";
        try {
          await DB.cambiarDocumento(btn.dataset.id, { pide_aprobacion: !pide });
          await recargar();
          avisar(!pide ? "✍️ El cliente verá el botón de aprobar" : "Aprobación quitada");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    // 🧾 Facturar un hito: crea la factura DIRECTO en QuickBooks.
    // Si la conexión API aún no está montada, plan B: copia el texto y abre QB.
    $detalle.querySelectorAll(".hito-facturar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const planB = async () => {
          const texto = btn.dataset.texto;
          try {
            await navigator.clipboard.writeText(texto);
            avisar("QB directo aún no conectado — texto copiado ✓, pégalo en la factura");
          } catch { prompt("Cópialo y pégalo en QuickBooks:", texto); }
          window.open("https://qbo.intuit.com/app/invoice", "_blank", "noopener");
        };
        if (!confirm("¿Crear esta factura en QuickBooks?")) return;
        btn.disabled = true; btn.textContent = "⏳";
        try {
          const r = await fetch("https://zeogjvwcmstmkwxjvykz.supabase.co/functions/v1/qb", {
            method: "POST",
            headers: { "Content-Type": "application/json", Authorization: `Bearer ${DB.tokenSesion()}` },
            body: JSON.stringify({ accion: "factura", proyecto_id: btn.dataset.proyecto, hito_id: Number(btn.dataset.hito) })
          });
          const d = await r.json().catch(() => ({}));
          if (r.ok && d.ok) {
            avisar(`Factura ${d.doc ? "#" + d.doc + " " : ""}creada en QuickBooks ✓`);
            if (d.link) window.open(d.link, "_blank", "noopener");
            await recargar();
            return;
          }
          if (d.error === "sin_conexion" || r.status === 404) { await planB(); }
          else avisar("QuickBooks dijo: " + (d.detalle || d.error || "error"), true);
        } catch { await planB(); }
        btn.disabled = false; btn.textContent = "🧾";
      });
    });
    // 💵 Marcar un HITO como cobrado — y ofrecer sumarlo a "cobrado" del
    // proyecto, que es la casilla que hace cuadrar la app con el banco.
    // Se pregunta a propósito: la casilla la lleva Edgar a mano y no se
    // le pisa sin permiso.
    $detalle.querySelectorAll(".hito-cobrado").forEach(btn => {
      btn.addEventListener("click", async () => {
        const monto = Number(btn.dataset.monto) || 0;
        if (!confirm(`¿Ya entró el dinero de "${btn.dataset.titulo}" (${fmt(monto)})?`)) return;
        const p = proyectoPorId(proyectoActivo);
        btn.disabled = true;
        try {
          await DB.cambiarHito(btn.dataset.hito, { estado: "cobrado" });
          await sumarACobrado(p, monto, `el hito "${btn.dataset.titulo}"`);
          await recargar();
          avisar("💵 Hito marcado cobrado ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); btn.disabled = false; }
      });
    });

    // ✓ Marcar una FACTURA como cobrada
    $detalle.querySelectorAll(".factura-pagada").forEach(btn => {
      btn.addEventListener("click", async () => {
        const monto = Number(btn.dataset.monto) || 0;
        if (!confirm(`¿Se cobró la factura #${btn.dataset.num} (${fmt(monto)})?`)) return;
        const p = proyectoPorId(proyectoActivo);
        btn.disabled = true;
        try {
          await DB.cambiarFactura(btn.dataset.id, { pagada: true });
          await sumarACobrado(p, monto, `la factura #${btn.dataset.num}`);
          await recargar();
          avisar("✓ Factura marcada cobrada");
        } catch (err) { avisar("No se pudo: " + err.message, true); btn.disabled = false; }
      });
    });

    $detalle.querySelectorAll(".foto-nota").forEach(btn => {
      btn.addEventListener("click", async () => {
        const nota = prompt("Descripción de la foto (o video):", btn.dataset.nota || "");
        if (nota === null) return;
        try {
          await DB.cambiarFoto(btn.dataset.id, { nota: nota.trim() || null });
          await recargar();
          avisar("Descripción corregida ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $detalle.querySelectorAll(".foto-cliente").forEach(btn => {
      btn.addEventListener("click", async () => {
        const visible = btn.dataset.portal === "1";
        try {
          await DB.cambiarFoto(btn.dataset.id, { portal: !visible });
          await recargar();
          avisar(!visible ? "👁 El cliente ahora VE esta foto" : "🚫 Foto oculta para el cliente");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    const formDec = $detalle.querySelector("#form-decision");
    if (formDec) formDec.addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(formDec);
      const texto = (d.get("texto") || "").toString().trim();
      if (!texto) return;
      try {
        await DB.crearDecision({ proyecto_id: proyectoActivo, texto, fecha_limite: d.get("fecha") || null });
        await recargar();
        avisar("Decisión agregada ✓ — el cliente la verá en su portal");
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });
    $detalle.querySelectorAll(".btn-dec-hecha").forEach(btn =>
      btn.addEventListener("click", async () => {
        try {
          await DB.cambiarDecision(btn.dataset.id, { hecha: true, hecha_el: new Date().toISOString() });
          await recargar();
          avisar("Decisión marcada ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      }));
    $detalle.querySelectorAll(".btn-dec-borrar").forEach(btn =>
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar esta decisión?")) return;
        try {
          await DB.eliminarDecision(btn.dataset.id);
          await recargar();
          avisar("Decisión eliminada ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      }));

    const btnDoc = $detalle.querySelector(".btn-agregar-doc");
    if (btnDoc) {
      const formDoc = $detalle.querySelector(".form-doc");
      btnDoc.addEventListener("click", () => { formDoc.hidden = !formDoc.hidden; });
      formDoc.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(formDoc);
        const clase = d.get("clase") === "rfi" ? "rfi" : "doc";
        const titulo = (d.get("titulo") || "").toString().trim();
        const archivo = formDoc.elements.archivo.files[0] || null;
        const url = (d.get("url") || "").toString().trim();
        if (!archivo && !url) {
          avisar("Ponle el archivo PDF o pega el enlace de Drive.", true);
          return;
        }
        if (archivo && archivo.size > 20 * 1024 * 1024) {
          avisar("Ese PDF pasa de 20 MB — comprímelo o usa el enlace de Drive.", true);
          return;
        }
        const $btnDoc = formDoc.querySelector('button[type="submit"]');
        $btnDoc.disabled = true;
        try {
          let ruta = null;
          if (archivo) {
            // Contratos/SOW/CO → cajón solo-dueño; planos y RFIs → cajón del equipo
            const prefijo = (clase === "rfi" || !docFirmable({ titulo })) ? "docs-equipo" : "docs";
            $btnDoc.textContent = "Subiendo…";
            ruta = await DB.subirDocumento(p.id, archivo, prefijo);
          }
          await DB.crearDocumento({
            proyecto_id: p.id,
            clase,
            titulo,
            url: url || null,
            ruta,
            estado: clase === "rfi" ? "Abierto" : null
          });
          await recargar();
          avisar(clase === "rfi" ? "RFI guardado ✓" : "Documento guardado ✓");
        } catch (err) {
          avisar("No se pudo guardar: " + err.message, true);
          $btnDoc.disabled = false;
          $btnDoc.textContent = "Guardar documento";
        }
      });
    }

    // "+ Agregar inspección" y cambio de resultado (solo dueño)
    const btnInsp = $detalle.querySelector(".btn-agregar-insp");
    if (btnInsp) {
      const formInsp = $detalle.querySelector(".form-insp");
      btnInsp.addEventListener("click", () => { formInsp.hidden = !formInsp.hidden; });
      formInsp.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(formInsp);
        try {
          await DB.crearInspeccion({
            proyecto_id: p.id,
            tipo: d.get("tipo"),
            fecha: d.get("fecha") || null,
            permiso: (d.get("permiso") || "").toString().trim() || null,
            jurisdiccion: (d.get("jurisdiccion") || "").toString().trim() || null,
            notas: (d.get("notas") || "").toString().trim() || null,
            resultado: "programada"
          });
          await recargar();
          avisar("Inspección guardada ✓" + (d.get("fecha") ? " — ya aparece en el calendario" : ""));
        } catch (err) {
          avisar("No se pudo guardar: " + err.message, true);
        }
      });
    }
    $detalle.querySelectorAll(".insp-resultado").forEach(sel => {
      sel.addEventListener("change", async () => {
        try {
          await DB.cambiarInspeccion(sel.dataset.id, { resultado: sel.value });
          await recargar();
          if (sel.value === "paso") {
            const h = proximoHito(p);
            avisar(usuario.finanzas && h
              ? `Inspección pasada ✓ — recuerda facturar: ${fmt(h.monto)} (${h.titulo})`
              : "Inspección pasada ✓");
          } else if (sel.value === "fallo") {
            avisar("Inspección fallida anotada — programa la reinspección.", true);
          } else {
            avisar("Resultado actualizado ✓");
          }
        } catch (err) {
          avisar("No se pudo cambiar: " + err.message, true);
        }
      });
    });

    // 🗑 Eliminar inspección (solo dueño, con confirmación)
    $detalle.querySelectorAll(".btn-insp-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm(`¿Eliminar la inspección ${btn.dataset.tipo}?\n\nÚsalo solo si se anotó por error. Esto no se puede deshacer.`)) return;
        try {
          await DB.eliminarInspeccion(btn.dataset.id);
          await recargar();
          avisar("Inspección eliminada ✓");
        } catch (err) {
          avisar("No se pudo eliminar: " + err.message, true);
        }
      });
    });

    // 🚀 Arranque: marcar gestión hecha o saltar a Materiales
    $detalle.querySelectorAll(".btn-gestion-hecha-ficha").forEach(btn => {
      btn.addEventListener("click", async () => {
        try {
          await DB.cambiarGestion(btn.dataset.id, { hecha: true });
          await recargar();
          avisar("Gestión hecha ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    const btnIrMat = $detalle.querySelector(".btn-ir-materiales");
    if (btnIrMat) btnIrMat.addEventListener("click", () => irMateriales(btnIrMat.dataset.id));

    // "+ Anotar trabajo externo" (solo dueño)
    const btnExt = $detalle.querySelector(".btn-agregar-ext");
    if (btnExt) {
      const formExt = $detalle.querySelector(".form-ext");
      btnExt.addEventListener("click", () => {
        formExt.hidden = !formExt.hidden;
        if (!formExt.hidden && !formExt.elements.fecha.value)
          formExt.elements.fecha.value = hoyISO();
      });
      // Al elegir un ayudante de la nómina: nombre y costo se llenan solos
      const selAyud = formExt.elements.ayudante;
      const calcularAyudante = () => {
        if (!selAyud || !selAyud.value) return;
        const op = selAyud.selectedOptions[0];
        formExt.elements.descripcion.value = op.dataset.nombre;
        formExt.elements.tipo.value = "horas";
        const h = Number(formExt.elements.horas.value);
        if (h > 0) formExt.elements.costo.value =
          Math.round(h * Number(op.dataset.tarifa) * 100) / 100;
      };
      if (selAyud) {
        selAyud.addEventListener("change", calcularAyudante);
        formExt.elements.horas.addEventListener("input", calcularAyudante);
      }
      formExt.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(formExt);
        const horasTxt = (d.get("horas") || "").toString().trim();
        try {
          await DB.crearExterno({
            proyecto_id: p.id,
            descripcion: (d.get("descripcion") || "").toString().trim(),
            fecha: d.get("fecha") || null,
            tipo: d.get("tipo") === "horas" ? "horas" : "ajuste",
            horas: horasTxt !== "" && Number.isFinite(Number(horasTxt)) ? Number(horasTxt) : null,
            costo: Number(d.get("costo")),
            ...(d.get("ayudante") ? { externo_id: Number(d.get("ayudante")) } : {})
          });
          await recargar();
          avisar("Trabajo externo anotado ✓ — ya cuenta como gasto del proyecto");
        } catch (err) { avisar("No se pudo anotar: " + err.message, true); }
      });
    }
    $detalle.querySelectorAll(".btn-ext-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este trabajo externo?")) return;
        try {
          await DB.eliminarExterno(btn.dataset.id);
          await recargar();
          avisar("Trabajo externo eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });

    // "📸 Agregar foto" (todo el equipo puede)
    const btnFoto = $detalle.querySelector(".btn-agregar-foto");
    if (btnFoto) {
      const formFoto = $detalle.querySelector(".form-foto");
      btnFoto.addEventListener("click", () => { formFoto.hidden = !formFoto.hidden; });
      // El botón dice "foto" o "video" según lo que se escoja
      const botonSubir = formFoto.querySelector('button[type="submit"]');
      const textoSubir = () => {
        const a = formFoto.elements.archivo.files[0];
        return a && (a.type || "").startsWith("video/") ? "⬆ Subir video" : "⬆ Subir foto";
      };
      formFoto.elements.archivo.addEventListener("change", () => { botonSubir.textContent = textoSubir(); });
      formFoto.addEventListener("submit", async e => {
        e.preventDefault();
        const archivos = [...formFoto.elements.archivo.files];
        if (!archivos.length) return;
        const nota = (formFoto.elements.nota.value || "").trim() || null;
        const $btn = formFoto.querySelector('button[type="submit"]');
        $btn.disabled = true;
        // Se pueden escoger VARIAS fotos de una vez: todas van con la misma nota.
        // Si una falla se CORTA ahí (break), pero las que ya subieron se
        // guardan y se pintan: antes se salía con return y las de antes
        // parecían perdidas, con el botón trabado y el formulario abierto.
        let subidas = 0;
        for (const archivo of archivos) {
          $btn.textContent = archivos.length > 1 ? `Subiendo ${subidas + 1} de ${archivos.length}…` : "Subiendo…";
          try {
            // Algunos teléfonos mandan el video sin tipo: también se mira la extensión
            const esVid = (archivo.type || "").startsWith("video/") || /\.(mp4|mov|webm)$/i.test(archivo.name || "");
            if (esVid && archivo.size > 50 * 1024 * 1024) {
              avisar("Ese video es muy grande. Grábalo CORTO, como una inspección virtual (30-45 segundos, máx. 50 MB).", true);
              break;
            }
            // Foto: se achica antes de subir. Video: sube tal cual.
            const blob = esVid ? archivo : await reducirImagen(archivo).catch(() => archivo);
            const tipoSubida = blob.type || archivo.type || (esVid ? "video/mp4" : "image/jpeg");
            const ruta = await DB.subirFoto(p.id, blob, tipoSubida);
            await DB.crearFoto({ proyecto_id: p.id, ruta, nota });
            subidas++;
          } catch (err) {
            avisar("No se pudo subir: " + err.message, true);
            break;
          }
        }
        $btn.disabled = false;
        $btn.textContent = textoSubir();
        // Una sola recarga al final, no una por foto
        if (subidas) {
          await recargar();
          avisar(subidas === archivos.length
            ? (subidas > 1 ? `${subidas} archivos subidos ✓` : "Subido ✓")
            : `${subidas} de ${archivos.length} subidos ✓ — los demás se quedaron, inténtalo otra vez.`);
        }
      });
    }

    // Documentos que viven en la app: pedir sus enlaces firmados
    const rutasDocs = [...$detalle.querySelectorAll("[data-docruta]")].map(a => a.dataset.docruta);
    if (rutasDocs.length) {
      DB.firmarFotos(rutasDocs).then(mapa => {
        $detalle.querySelectorAll("[data-docruta]").forEach(a => {
          if (mapa[a.dataset.docruta]) a.href = mapa[a.dataset.docruta];
        });
      }).catch(() => avisar("No se pudieron cargar los documentos — revisa la señal.", true));
    }

    // Pedir los enlaces temporales de las fotos y pintarlas
    const rutas = [...$detalle.querySelectorAll(".foto-mini")].map(i => i.dataset.ruta);
    if (rutas.length) {
      DB.firmarFotos(rutas).then(mapa => {
        $detalle.querySelectorAll(".foto-mini").forEach(img => {
          if (mapa[img.dataset.ruta]) img.src = mapa[img.dataset.ruta];
        });
        $detalle.querySelectorAll(".foto-enlace").forEach(a => {
          if (mapa[a.dataset.ruta]) a.href = mapa[a.dataset.ruta];
        });
        // Fallo a medias: unas cargan y otras se quedan en blanco. Antes no
        // se decía nada y parecía que las fotos se habían perdido.
        if (mapa.__faltan) {
          avisar(`${mapa.__faltan} ${mapa.__faltan === 1 ? "foto no cargó" : "fotos no cargaron"} — vuelve a entrar al proyecto en un momento.`, true);
        }
      }).catch(() => avisar("No se pudieron cargar las fotos — revisa la señal y vuelve a entrar al proyecto.", true));
    }
  }

  // Re-pinta la pantalla correcta después de guardar un cambio
  function refrescarVistaProyecto(id) {
    if (!$vDetalle.hidden) pintarDetalle();
    else pintarLista(id);
  }

  // ---------- Acciones del pipeline (escriben en la nube) ----------
  async function ejecutarAccion(accion, id) {
    if (!usuario.editar) return;
    const p = proyectos().find(x => x.id === id);
    if (!p) return;
    if (accion === "alcance") { irAlcance(id); return; }
    const idx = Math.max(0, FASES.findIndex(f => f.clave === p.fase));
    let cambios = null;
    switch (accion) {
      case "aprobar":       cambios = { estado: "aprobado" }; break;
      case "iniciar":       cambios = { estado: "ejecucion", fase: p.fase || "mobilizacion" }; break;
      case "pausar":        cambios = { estado: "pausa" }; break;
      case "completar":     cambios = { estado: "completado" }; break;
      case "reabrir":       cambios = { estado: "ejecucion", fase: p.fase || "insp-final" }; break;
      case "fase-adelante": cambios = { fase: FASES[Math.min(idx + 1, FASES.length - 1)].clave }; break;
      case "fase-atras":    cambios = { fase: FASES[Math.max(idx - 1, 0)].clave }; break;
    }
    if (!cambios) return;
    try {
      await DB.cambiarProyecto(id, cambios);
      Object.assign(p, { estado: cambios.estado || p.estado, fase: cambios.fase || p.fase });
      refrescarVistaProyecto(id);
    } catch (err) {
      avisar("No se pudo guardar: " + err.message, true);
    }
  }

  // ---------- Crear proyecto nuevo ----------
  $btnNuevo.addEventListener("click", () => {
    if (!usuario.editar) return;
    if (tipoActivo) $formNuevo.elements.tipo.value = tipoActivo;
    if (etapaActiva && ["enviado", "aprobado", "ejecucion"].includes(etapaActiva))
      $formNuevo.elements.estado.value = etapaActiva;
    $modal.showModal();
  });
  $("btn-cancelar").addEventListener("click", () => { $formNuevo.reset(); $modal.close(); });

  $formNuevo.addEventListener("submit", async e => {
    e.preventDefault();
    const d = new FormData($formNuevo);
    const nombre = (d.get("nombre") || "").toString().trim();
    if (!nombre) return;
    const contratoTxt = (d.get("contrato") || "").toString().replace(/[$,\s]/g, "");
    const contrato = contratoTxt ? Number(contratoTxt) : null;
    if (contratoTxt && !Number.isFinite(contrato)) {
      avisar("El monto del contrato no es un número válido — revísalo.", true);
      return;
    }
    const estado = d.get("estado") || "estimando";
    const tipo = d.get("tipo") || "residencial";
    const id = nombre.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
      .slice(0, 30) + "-" + Math.random().toString(36).slice(2, 6);
    const fila = {
      id, tipo, nombre,
      direccion: (d.get("direccion") || "Por confirmar").toString().trim() || "Por confirmar",
      cliente: (d.get("cliente") || "Por confirmar").toString().trim() || "Por confirmar",
      via: (d.get("via") || "Directo").toString().trim() || "Directo",
      estado,
      fase: estado === "ejecucion" ? "mobilizacion" : null,
      estado_detalle: (d.get("notas") || "Proyecto creado desde el panel").toString().trim() || "Proyecto creado desde el panel",
      proxima_accion: "Definir la próxima acción.",
      ref: (d.get("ref") || "Por definir").toString().trim() || "Por definir"
    };
    try {
      await DB.crearProyecto(fila);
      if (Number.isFinite(contrato) && contrato !== null)
        await DB.crearFinanzas({ proyecto_id: id, contrato, cobrado: 0 });
      $formNuevo.reset();
      $modal.close();
      tipoActivo = tipo;
      await recargar();
      // Directo a la ficha: desde ahí sigue el flujo (escribir el alcance)
      irDetalle(id);
      avisar(estado === "estimando" ? "Proyecto creado ✓ — ahora toca «Escribir el alcance»" : "Proyecto creado ✓");
    } catch (err) {
      avisar("No se pudo crear: " + err.message, true);
    }
  });

  // ============================================================
  // MIS HORAS — guarda directo en la nube
  // ============================================================
  function irHoras() {
    mostrar("horas", { kicker: "Reporte diario", titulo: "Mis horas", volver: true, nuevo: false });
    // Al ENTRAR siempre se pone la fecha de hoy. Antes, si la pantalla se
    // había quedado abierta de ayer, el reporte se guardaba con la fecha vieja.
    $formHoras.elements.fecha.value = hoyISO();
    prepararHoras();
  }
  $btnHoras.addEventListener("click", irHoras);

  // Proyectos donde se puede reportar o asociar trabajo: los activos MÁS los
  // que aún tengan pendientes rojos abiertos (trabajos atípicos como Danzig,
  // que están cobrados pero les queda trabajo vivo).
  function proyectosConTrabajo(extraEstados) {
    const conPendiente = new Set(pendientesAbiertos().map(p => p.proyecto).filter(Boolean));
    return proyectos().filter(p =>
      ["ejecucion", "aprobado", "pausa"].includes(p.estado)
      || conPendiente.has(p.id)
      || (extraEstados && extraEstados.includes(p.estado)));
  }

  // Número de Change Order dentro de un título: "Change Order #1…",
  // "CO-001 Kitchen Circuits", "MXP-CO-2026-…-01" → 1
  function numeroCO(titulo) {
    const m = /change\s*order\s*[#\-]?\s*0*(\d+)|\bco[\s#\-]*0*(\d+)\b/i.exec(titulo || "");
    return m ? Number(m[1] || m[2]) : null;
  }
  const esDocContrato = t => /\bsow\b|scope\s*of\s*work|propuesta|contrato/i.test(t || "");
  const esDocAparte = t => /\bplano\b|\brfi\b|site\s*plan|acknowledgment|licencia|insurance/i.test(t || "");
  // La flechita del reporte de horas: muestra los documentos REALES del
  // proyecto elegido, con su nombre y numeración completos — el contrato
  // base con su título ("SOW firmado", "SOW 410 Sterling v7"…) y cada
  // Change Order con el suyo ("Change Order #1 — Cat6 data pathway
  // (MXP-CO-2026-0816-DICKE-01)"). Nada de "contrato normal" a secas.
  function llenarCOHoras() {
    const sel = $formHoras.elements.co;
    if (!sel || sel.tagName !== "SELECT") return;
    const pid = $formHoras.elements.proyecto.value;
    const docs = (state.titulosDocs || [])
      .filter(t => t.proyecto === pid && !esDocAparte(t.titulo));
    // Contratos base: todos los SOW / propuestas del proyecto, con su nombre
    const contratos = docs.filter(t => esDocContrato(t.titulo) && numeroCO(t.titulo) === null);
    // Change Orders: agrupados por número; si hay varios documentos del
    // mismo CO (ej. el original y el firmado) gana el título con la
    // numeración MXP, o el más descriptivo
    const porCO = {};
    for (const t of docs) {
      const n = numeroCO(t.titulo);
      if (n === null) continue;
      const actual = porCO[n];
      if (!actual || (/MXP-/i.test(t.titulo) && !/MXP-/i.test(actual)) ||
          (/MXP-/i.test(t.titulo) === /MXP-/i.test(actual) && t.titulo.length > actual.length)) {
        porCO[n] = t.titulo;
      }
    }
    const opcionesBase = contratos.length
      ? contratos.map(t => `<option value="">📄 Contrato — ${esc(t.titulo)}</option>`).join("")
      : `<option value="">📄 Contrato base (sin SOW subido aún)</option>`;
    const opcionesCO = Object.keys(porCO).map(Number).sort((a, b) => a - b)
      .map(n => `<option value="${esc("CO #" + n)}">🧾 CO #${n} — ${esc(porCO[n])}</option>`).join("");
    sel.innerHTML = opcionesBase + opcionesCO +
      `<option value="__otro__">✍️ Otro (escribirlo)</option>`;
  }
  function prepararHoras() {
    const f = $formHoras.elements.fecha;
    if (!f.value) f.value = hoyISO(); // fecha LOCAL: por la noche no salta a mañana
    const sel = $formHoras.elements.proyecto;
    // No perder lo que la persona ya eligió al repintar la lista. Y si no hay
    // nada elegido, arrancar en el proyecto de su ÚLTIMO reporte, que casi
    // siempre es donde sigue trabajando (antes salía el primero alfabético).
    const antes = sel.value;
    const mios = (state.registroHoras || []).filter(r => r.usuarioId === usuario.id);
    const ultimo = mios.length ? mios[mios.length - 1].proyecto : "";
    const lista = proyectosConTrabajo();
    sel.innerHTML = lista.map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("");
    const querido = antes || ultimo;
    if (querido && lista.some(p => p.id === querido)) sel.value = querido;
    llenarCOHoras();
    pintarHistorialHoras();
  }
  $formHoras.elements.proyecto.addEventListener("change", llenarCOHoras);

  function pintarHistorialHoras() {
    const mios = (state.registroHoras || []).filter(r => r.usuarioId === usuario.id);
    if (!mios.length) { $("horas-historial").innerHTML = ""; return; }

    const opcionesFase = $formHoras.elements.fase.innerHTML;
    const opcionesProyecto = r => {
      const base = proyectosConTrabajo();
      const lista = base.some(p => p.id === r.proyecto) ? base
        : base.concat(proyectos().filter(p => p.id === r.proyecto));
      return lista
        .map(p => `<option value="${esc(p.id)}"${p.id === r.proyecto ? " selected" : ""}>${esc(p.nombre)}</option>`)
        .join("");
    };

    $("horas-historial").innerHTML =
      `<h3 class="historial-titulo">Mis reportes (toca ✎ para corregir)</h3>` +
      mios.slice(-10).reverse().map(r => {
        const p = proyectos().find(x => x.id === r.proyecto);
        return `<div class="alcance-item">
            <span class="alcance-tipo">${esc(r.horas)}h</span>
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(p ? p.nombre : r.proyecto)}</span>
              <span class="alcance-estado">${esc(r.fecha)}${r.fase ? " · " + esc(r.fase) : ""}${r.co ? " · 🧾 " + esc(r.co) : ""}${r.notas ? " · " + esc(r.notas) : ""}</span>
            </span>
            <button type="button" class="insp-borrar btn-horas-editar" data-id="${r.id}" title="Corregir o eliminar">✎</button>
          </div>
          <form class="cal-form form-horas-editar" data-id="${r.id}" data-fase="${esc(r.fase)}" hidden>
            <div class="modal-fila">
              <label>Fecha
                <input name="fecha" type="date" value="${esc(r.fecha)}" required>
              </label>
              <label>Horas
                <input name="horas" type="number" min="0.5" max="16" step="0.5" value="${esc(r.horas)}" required>
              </label>
            </div>
            <label>Proyecto
              <select name="proyecto">${opcionesProyecto(r)}</select>
            </label>
            <label>Fase / tipo de trabajo
              <select name="fase">${opcionesFase}</select>
            </label>
            <label>Change Order (opcional — vacío = contrato normal)
              <input name="co" type="text" value="${esc(r.co || "")}" placeholder="Ej: CO #1" autocomplete="off">
            </label>
            <label>Notas (aquí puedes agregar lo que te faltó)
              <input name="notas" type="text" value="${esc(r.notas || "")}" autocomplete="off">
            </label>
            <div class="modal-botones">
              <button type="button" class="accion secundaria btn-horas-borrar" data-id="${r.id}">🗑 Eliminar</button>
              <button type="submit" class="accion">Guardar cambios</button>
            </div>
          </form>`;
      }).join("");

    // Dejar cada selector de fase en la fase que tenía el reporte
    $("horas-historial").querySelectorAll(".form-horas-editar").forEach(form => {
      const sel = form.elements.fase;
      const faseActual = form.dataset.fase;
      if (faseActual) {
        sel.value = faseActual;
        if (sel.value !== faseActual) {
          sel.insertAdjacentHTML("afterbegin",
            `<option value="${esc(faseActual)}" selected>${esc(faseActual)}</option>`);
          sel.value = faseActual;
        }
      }
    });

    $("horas-historial").querySelectorAll(".btn-horas-editar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const rep = (state.registroHoras || []).find(r => String(r.id) === String(btn.dataset.id));
        // El equipo necesita el permiso de Edgar antes de corregir
        if (!usuario.editar && rep) {
          if (rep.correccion === "pedida") {
            avisar("⏳ Ya le pediste permiso a Edgar — te avisamos al teléfono cuando apruebe");
            return;
          }
          if (rep.correccion !== "aprobada") {
            if (!confirm("Para corregir este reporte necesitas el permiso de Edgar. ¿Se lo pedimos ahora?")) return;
            try {
              await DB.cambiarHoras(rep.id, { correccion_estado: "pedida" });
              await recargar();
              avisar("Permiso pedido ✓ — a Edgar le llegó el aviso al teléfono");
            } catch (err) { avisar("No se pudo: " + err.message, true); }
            return;
          }
        }
        const form = $("horas-historial")
          .querySelector(`.form-horas-editar[data-id="${btn.dataset.id}"]`);
        if (form) form.hidden = !form.hidden;
      });
    });
    $("horas-historial").querySelectorAll(".form-horas-editar").forEach(form => {
      form.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(form);
        try {
          await DB.cambiarHoras(form.dataset.id, {
            fecha: d.get("fecha"),
            horas: Number(d.get("horas")),
            proyecto_id: d.get("proyecto"),
            fase: d.get("fase"),
            co: (d.get("co") || "").toString().trim() || null,
            notas: (d.get("notas") || "").toString().trim() || null
          });
          await recargar();
          avisar("Reporte corregido ✓");
        } catch (err) { avisar("No se pudo corregir: " + err.message, true); }
      });
    });
    $("horas-historial").querySelectorAll(".btn-horas-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este reporte de horas?\n\nÚsalo solo si se reportó por error.")) return;
        try {
          await DB.eliminarHoras(btn.dataset.id);
          await recargar();
          avisar("Reporte eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });
  }

  // Candado contra el doble toque: mientras un reporte está saliendo, el
  // botón no responde. Y cada reporte lleva una llave única (llave_cliente):
  // si el mismo reporte llega dos veces (reintento de la cola, doble toque
  // que se coló), la base rechaza el segundo en vez de duplicar las horas.
  let guardandoHoras = false;
  $formHoras.addEventListener("submit", async e => {
    e.preventDefault();
    if (guardandoHoras) return;
    guardandoHoras = true;
    const btnHoras = $formHoras.querySelector('button[type="submit"]');
    if (btnHoras) btnHoras.disabled = true;
    try {
    const d = new FormData($formHoras);
    const proyectoId = d.get("proyecto");
    const pendiente = (d.get("pendiente") || "").toString().trim();
    const fila = {
      fecha: d.get("fecha"),
      proyecto_id: proyectoId,
      fase: d.get("fase"),
      horas: Number(d.get("horas")),
      notas: (d.get("notas") || "").toString().trim() || null,
      co: (d.get("co") || "").toString().trim() || null,
      llave_cliente: llaveUnica()
    };
    if (fila.co === "__otro__") {
      const escrito = prompt("¿De cuál Change Order fue el trabajo? (Ej: CO #2)");
      if (escrito === null) return;
      fila.co = escrito.trim() || null;
    }
    // Dos banderas: si las horas SÍ entraron y lo que se cayó fue el
    // pendiente, no se puede volver a mandar todo — se duplicarían las
    // horas de ese día. Se guarda solo lo que faltó.
    let horasOk = false, pendOk = false;
    try {
      await DB.reportarHoras(fila);
      horasOk = true;
      if (pendiente) {
        await DB.crearPendiente({
          fecha: fila.fecha, proyecto_id: proyectoId, descripcion: pendiente,
          prioridad: d.get("urgente") ? "urgente" : "normal"
        });
        pendOk = true;
      }
      $formHoras.elements.horas.value = "";
      $formHoras.elements.notas.value = "";
      $formHoras.elements.co.value = "";
      $formHoras.elements.pendiente.value = "";
      await recargar();
      avisar(pendiente ? "Horas y pendiente guardados ✓ (el pendiente queda en rojo)" : "Horas guardadas ✓");
    } catch (err) {
      if (esFalloDeRed(err)) {
        // Sin señal: el reporte NO se pierde. Se guarda en el teléfono y se
        // manda solo cuando vuelva la señal o al abrir la app otra vez.
        guardarHorasPendientes({
          fila: horasOk ? null : fila,
          pendiente: (pendiente && !pendOk) ? pendiente : null,
          proyecto_id: proyectoId, fecha: fila.fecha,
          urgente: !!d.get("urgente"),
        });
        $formHoras.elements.horas.value = "";
        $formHoras.elements.notas.value = "";
        $formHoras.elements.co.value = "";
        $formHoras.elements.pendiente.value = "";
        avisar("📶 Sin señal — tu reporte quedó guardado en el teléfono y se manda solo cuando vuelva la señal.");
        return;
      }
      if (err && err.status === 409) {
        // La llave única dijo "ese reporte ya está": no se duplicó nada.
        $formHoras.elements.horas.value = "";
        avisar("Ese reporte ya estaba guardado ✓");
        await recargar();
        return;
      }
      avisar("No se pudo guardar: " + err.message, true);
    }
    } finally {
      guardandoHoras = false;
      if (btnHoras) btnHoras.disabled = false;
    }
  });

  // ---------- Reportes de horas que quedaron esperando señal ----------
  const LLAVE_COLA = "mxp_horas_pendientes";
  function llaveUnica() {
    try { return crypto.randomUUID(); }
    catch { return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10); }
  }
  function colaHoras() {
    try { return JSON.parse(localStorage.getItem(LLAVE_COLA)) || []; } catch { return []; }
  }
  function guardarHorasPendientes(item) {
    if (!item || (!item.fila && !item.pendiente)) return; // ya entró todo
    const cola = colaHoras();
    cola.push(item);
    try { localStorage.setItem(LLAVE_COLA, JSON.stringify(cola)); } catch { /* lleno */ }
  }
  let enviandoCola = false;
  async function enviarColaHoras() {
    if (enviandoCola || !DB.haySesion()) return;
    const cola = colaHoras();
    if (!cola.length) return;
    enviandoCola = true;
    const quedan = [];
    let mandados = 0;
    for (const item of cola) {
      if (!item || (!item.fila && !item.pendiente)) continue; // ya estaba todo dentro
      // Mismo cuidado que arriba: si en el reintento entran las horas pero
      // se cae el pendiente, solo se vuelve a guardar el pendiente.
      let hOk = !item.fila, pOk = !item.pendiente;
      try {
        if (item.fila) { await DB.reportarHoras(item.fila); hOk = true; }
        if (item.pendiente) {
          await DB.crearPendiente({
            fecha: item.fecha || (item.fila && item.fila.fecha),
            proyecto_id: item.proyecto_id || (item.fila && item.fila.proyecto_id),
            descripcion: item.pendiente, prioridad: item.urgente ? "urgente" : "normal"
          });
          pOk = true;
        }
        mandados++;
      } catch (err) {
        const st = err && err.status;
        if (st === 409) { mandados++; continue; } // ya estaba dentro: la llave única lo paró
        if (esFalloDeRed(err) || st === 401 || (st >= 500 && st < 600)) {
          // Sin señal, sesión vencida o servidor caído: se queda en la cola.
          // (Antes un 500 de Supabase tiraba el reporte a la basura en silencio.)
          const resto = { ...item, fila: hOk ? null : item.fila, pendiente: pOk ? null : item.pendiente };
          if (resto.fila || resto.pendiente) quedan.push(resto);
        }
        // 400/403: el servidor lo rechazó de verdad; se descarta para no reintentar para siempre
      }
    }
    try { localStorage.setItem(LLAVE_COLA, JSON.stringify(quedan)); } catch { /* lleno */ }
    enviandoCola = false;
    if (mandados) {
      avisar(mandados === 1 ? "Se mandó el reporte que estaba esperando señal ✓"
        : `Se mandaron ${mandados} reportes que estaban esperando señal ✓`);
      recargar();
    }
  }
  window.addEventListener("online", enviarColaHoras);

  // ============================================================
  // MATERIALES — lista de compras de toda la empresa
  // ============================================================
  // Palabras que hacen que un pendiente "suene a material"
  const REG_MATERIAL = /falt|material|cable|wire|breaker|conduit|emt|romex|tubo|caja|toma|receptacle|luminaria|fixture|comprar|alambre|panel/i;

  let filtroMateriales = "";  // "" = todos los proyectos
  function irMateriales(proyectoId) {
    filtroMateriales = proyectoId || "";
    mostrar("materiales", { kicker: "Compras y arranque", titulo: "Materiales", volver: true, nuevo: false });
    pintarMateriales();
  }
  $("btn-materiales").addEventListener("click", () => irMateriales());
  $("btn-checklist").addEventListener("click", () => irChecklist());

  function pintarMateriales() {
    const pasaFiltro = x => !filtroMateriales || x.proyecto === filtroMateriales;
    const mats = (state.materiales || []).filter(pasaFiltro);
    const faltan = mats.filter(m => m.estado === "falta");
    const comprados = mats.filter(m => m.estado === "comprado").slice(-10).reverse();
    const gestAbiertas = (state.gestiones || []).filter(g => !g.hecha && pasaFiltro(g));
    // Compras dictadas por voz que faltan por completar: sin foto o sin proyecto
    const recibosPendientes = (state.recibos || [])
      .filter(r => r.estado !== "anulado" && (r.estado === "sin_foto" || !r.proyecto));
    const idsPendientes = new Set(recibosPendientes.map(r => r.id));
    const recibosVista = (state.recibos || [])
      .filter(r => pasaFiltro(r) && !idsPendientes.has(r.id)).slice(-8).reverse();
    const nombreProy = id => {
      const p = proyectos().find(x => x.id === id);
      return p ? p.nombre : "General";
    };
    // Opciones de proyecto para el formulario de edición: los activos
    // más el proyecto actual del material (aunque ya esté completado)
    const opcionesEditar = m => {
      const activos = proyectos().filter(x =>
        ["ejecucion", "aprobado", "pausa"].includes(x.estado) || x.id === m.proyecto);
      return `<option value=""${!m.proyecto ? " selected" : ""}>— General —</option>` +
        activos.map(x =>
          `<option value="${esc(x.id)}"${x.id === m.proyecto ? " selected" : ""}>${esc(x.nombre)}</option>`).join("");
    };

    const filaMat = m => `
      <div class="mat-item ${m.estado}">
        <span class="mat-icono">${m.estado === "falta" ? "🔴" : "✓"}</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(m.descripcion))}${m.cantidad ? ` <span class="mat-cant">— ${esc(sinMontos(m.cantidad))}</span>` : ""}</span>
          <span class="alcance-estado">${esc(nombreProy(m.proyecto))} · ${esc(m.autor)} ${esc(m.fecha)}</span>
        </span>
        ${usuario.finanzas && m.estado === "comprado" && typeof m.precio === "number" ? `<span class="mat-precio">${fmt(m.precio)}</span>` : ""}
        ${usuario.editar && m.estado === "falta" ? `<button class="accion btn-mat-comprado" data-id="${m.id}">✓ Comprado</button>` : ""}
        ${usuario.editar ? `<button class="insp-borrar btn-mat-editar" data-id="${m.id}" title="Modificar o eliminar">✎</button>` : ""}
      </div>
      ${usuario.editar ? `
      <form class="cal-form form-mat-editar" data-id="${m.id}" hidden>
        <label>Material (corrige el nombre si te equivocaste)
          <input name="descripcion" type="text" required value="${esc(m.descripcion)}" autocomplete="off">
        </label>
        <div class="modal-fila">
          <label>Cantidad
            <input name="cantidad" type="text" value="${esc(m.cantidad)}" autocomplete="off">
          </label>
          <label>Proyecto (cámbialo si era de otro)
            <select name="proyecto">${opcionesEditar(m)}</select>
          </label>
        </div>
        ${usuario.finanzas ? `
        <label>Precio pagado ($) — para el control de gastos
          <input name="precio" type="number" min="0" step="0.01" inputmode="decimal"
            value="${typeof m.precio === "number" ? m.precio : ""}" placeholder="Ej: 45.99">
        </label>` : ""}
        <div class="modal-botones">
          <button type="button" class="accion secundaria btn-mat-eliminar" data-id="${m.id}">🗑 Eliminar</button>
          <button type="submit" class="accion">Guardar cambios</button>
        </div>
      </form>` : ""}`;

    // Pendientes de obra abiertos que suenan a material (y que no
    // hayan sido pasados ya a la lista)
    const yaPasados = new Set((state.materiales || []).map(m => m.origenPendiente).filter(Boolean));
    const sugeridos = pendientesAbiertos()
      .filter(x => REG_MATERIAL.test(x.descripcion) && !yaPasados.has(x.id) && pasaFiltro(x));

    const activosLista = proyectosConTrabajo();
    const opciones = activosLista
      .map(x => `<option value="${esc(x.id)}">${esc(x.nombre)}</option>`).join("");
    const opcionesFiltro = `<option value=""${!filtroMateriales ? " selected" : ""}>Todos los proyectos</option>` +
      activosLista.map(x =>
        `<option value="${esc(x.id)}"${x.id === filtroMateriales ? " selected" : ""}>${esc(x.nombre)}</option>`).join("");

    const RES_RECIBO = { por_leer: "POR LEER", leido: "LEÍDO", conciliado: "CONCILIADO ✓", sin_foto: "FALTA FOTO 📷", anulado: "ANULADO" };
    const esDevolucionRecibo = r =>
      (typeof r.total === "number" && r.total < 0) || /DEVOLUCI/i.test(r.notas || "");
    const filaRecibo = r => `
      <div class="mat-item recibo-${esc(r.estado)}">
        <span class="recibo-chip ${esc(r.estado)}">${esc(RES_RECIBO[r.estado] || r.estado)}</span>
        ${esDevolucionRecibo(r) ? `<span class="recibo-chip devolucion">↩ DEVOLUCIÓN</span>` : ""}
        ${r.co ? `<span class="recibo-chip leido">🧾 ${esc(r.co)}</span>` : ""}
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(r.proveedor || "Recibo")}${r.notas ? ` <span class="mat-cant">— ${esc(sinMontos(r.notas))}</span>` : ""}</span>
          <span class="alcance-estado">${r.proyecto ? esc(nombreProy(r.proyecto)) : "⚠ Sin proyecto"} · ${esc(r.autor)} ${esc(r.fecha)}</span>
        </span>
        ${!r.proyecto && usuario.editar ? `<button class="insp-borrar btn-recibo-asignar" data-id="${r.id}"
          title="Asignarle proyecto a esta compra">📌</button>` : ""}
        ${usuario.finanzas && typeof r.total === "number" ? `<span class="mat-precio">${fmt(r.total)}</span>` : ""}
        ${r.ruta ? `<a class="doc-link recibo-ver" data-ruta="${esc(r.ruta)}" target="_blank" rel="noopener">📄 Ver</a>` : ""}
        ${usuario.finanzas ? `<button class="insp-borrar btn-recibo-total" data-id="${r.id}"
          data-total="${typeof r.total === "number" ? r.total : ""}" data-proveedor="${esc(r.proveedor || "")}" data-notas="${esc(r.notas || "")}"
          title="Corregir total, proveedor o descripción">✎</button>` : ""}
        ${usuario.editar ? `<button class="insp-borrar btn-recibo-foto" data-id="${r.id}" data-proyecto="${esc(r.proyecto || "general")}" data-estado="${esc(r.estado)}"
          title="${r.ruta ? "Cambiar la foto del recibo" : "Ponerle la foto del recibo"}">📷</button>` : ""}
        ${usuario.editar ? `<button class="insp-borrar btn-recibo-borrar" data-id="${r.id}" title="Eliminar">🗑</button>` : ""}
      </div>`;

    $("materiales-panel").innerHTML = `
      <div class="cal-panel-card mat-filtro">
        <label>Ver
          <select id="filtro-mat">${opcionesFiltro}</select>
        </label>
      </div>
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Por comprar (${faltan.length})
          ${faltan.length ? `<button type="button" class="accion secundaria" id="btn-mat-supply" style="margin-left:.4rem">📤 Enviar al supply</button>` : ""}
        </div>
        ${faltan.map(filaMat).join("") || `<p class="cal-sin-eventos">Nada pendiente de comprar. 👌</p>`}
      </div>
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🚀 Gestiones de arranque (${gestAbiertas.length})</div>
        ${gestAbiertas.map(g => `
          <div class="mat-item falta">
            <span class="mat-icono">📌</span>
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(sinMontos(g.descripcion))}</span>
              <span class="alcance-estado">${esc(nombreProy(g.proyecto))} · ${esc(g.autor)} ${esc(g.fecha)}</span>
            </span>
            ${usuario.editar ? `<button class="accion btn-gestion-hecha" data-id="${g.id}">✓ Hecha</button>
            <button class="insp-borrar btn-gestion-borrar" data-id="${g.id}" title="Eliminar">🗑</button>` : ""}
          </div>`).join("") || `<p class="cal-sin-eventos">Sin gestiones pendientes.</p>`}
        <form id="form-gestion" class="cal-form">
          <div class="modal-fila">
            <label>Proyecto
              <select name="proyecto">
                <option value="">— General —</option>
                ${opciones}
              </select>
            </label>
            <label>Gestión (qué hay que hacer)
              <input name="descripcion" type="text" required placeholder="Ej: rentar la zanjadora" autocomplete="off">
            </label>
          </div>
          <button type="submit" class="accion secundaria">+ Agregar gestión</button>
        </form>
      </div>
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🧾 Compras y recibos</div>
        <button type="button" class="accion secundaria btn-importar-recibo">🛒 Registrar compra</button>
        <div id="compra-modos" class="modal-fila" hidden style="margin-top:.45rem">
          <button type="button" class="accion secundaria btn-compra-foto">📷 Con foto del recibo</button>
          <button type="button" class="accion secundaria btn-compra-mano">✍️ Sin recibo — anotar a mano</button>
        </div>
        <form id="form-compra-mano" class="cal-form" hidden>
          <div class="modal-fila">
            <label>Proyecto
              <select name="proyecto">
                <option value="">— General —</option>
                ${opciones}
              </select>
            </label>
            <label>Tipo
              <select name="tipo">
                <option value="compra">🛒 Compra</option>
                <option value="devolucion">↩ Devolución (resta del gasto)</option>
              </select>
            </label>
          </div>
          <label>¿Dónde se compró?
            <input name="proveedor" type="text" placeholder="Ej: Home Depot, CES, Ferguson…" autocomplete="off">
          </label>
          <label>¿Qué se compró? (los materiales)
            <input name="notas" type="text" required placeholder="Ej: 3 rollos 12/2, caja de breakers, 10 straps" autocomplete="off">
          </label>
          ${usuario.finanzas ? `
          <label>Total ($)
            <input name="total" type="number" min="0" step="0.01" inputmode="decimal" placeholder="Ej: 128.40">
          </label>` : `<p class="modal-nota">Edgar le pone el total después con el ✎.</p>`}
          <label>¿Es de un Change Order? (opcional)
            <input name="co" type="text" placeholder="Ej: CO #1" autocomplete="off">
          </label>
          <button type="submit" class="accion">✓ Registrar la compra</button>
        </form>
        <form id="form-recibo" class="cal-form" hidden>
          <label>Foto del recibo (cámara o galería)
            <input name="archivo" type="file" accept="image/*" required>
          </label>
          <div class="modal-fila">
            <label>Proyecto
              <select name="proyecto">
                <option value="">— General —</option>
                ${opciones}
              </select>
            </label>
            <label>Tipo de ticket
              <select name="tipo">
                <option value="compra">🛒 Compra</option>
                <option value="devolucion">↩ Devolución (resta del gasto)</option>
              </select>
            </label>
          </div>
          ${usuario.finanzas ? `
          <div class="modal-fila">
            <label>Total ($) — o déjalo vacío y la rutina lo lee de la foto
              <input name="total" type="number" min="0" step="0.01" inputmode="decimal" placeholder="Ej: 342.18">
            </label>
            <label>Proveedor (opcional)
              <input name="proveedor" type="text" placeholder="Ej: Home Depot" autocomplete="off">
            </label>
          </div>` : ""}
          <label>Nota (opcional)
            <input name="notas" type="text" placeholder="Ej: compra del rough" autocomplete="off">
          </label>
          <label>¿Es de un Change Order? (opcional)
            <input name="co" type="text" placeholder="Ej: CO #1" autocomplete="off">
          </label>
          <button type="submit" class="accion">⬆ Subir recibo</button>
        </form>
        ${recibosPendientes.length ? `
        <div class="cal-form-titulo" style="margin-top:10px">📥 Por completar (${recibosPendientes.length}) — compras dictadas por voz</div>
        <p class="cal-sin-eventos" style="margin:2px 0 6px">Ponles la foto del recibo con 📷 o el proyecto con 📌.</p>
        ${recibosPendientes.map(filaRecibo).join("")}
        <div class="cal-form-titulo" style="margin-top:10px">Últimas compras</div>` : ""}
        ${recibosVista.map(filaRecibo).join("") || `<p class="cal-sin-eventos">Sin recibos todavía.</p>`}
      </div>
      ${sugeridos.length ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🔴 Pendientes de obra que suenan a material</div>
        ${sugeridos.map(s => `
          <div class="pendiente-item">
            <span class="pendiente-icono">⚠</span>
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(sinMontos(s.descripcion))}</span>
              <span class="alcance-estado">${esc(nombreProy(s.proyecto))} · ${esc(s.autor)} ${esc(s.fecha)}</span>
            </span>
            <button class="accion secundaria btn-mat-pasar" data-id="${s.id}">→ Pasar a la lista</button>
          </div>`).join("")}
      </div>` : ""}
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Agregar material
          <button type="button" class="accion secundaria" id="btn-mat-modo" style="margin-left:.4rem">📝 Lista rápida — varios de un golpe</button>
        </div>
        <form id="form-material" class="cal-form">
          <label>Proyecto
            <select name="proyecto">
              <option value="">— General (no es de un proyecto) —</option>
              ${opciones}
            </select>
          </label>
          <div class="modal-fila">
            <label>Material
              <input name="descripcion" type="text" required placeholder="Ej: cable 14/2" autocomplete="off">
            </label>
            <label>Cantidad (opcional)
              <input name="cantidad" type="text" placeholder="Ej: 2 rollos" autocomplete="off">
            </label>
          </div>
          <button type="submit" class="accion">Agregar a la lista</button>
        </form>
        <form id="form-mat-lista" class="cal-form" hidden>
          <label>Proyecto (para toda la lista)
            <select name="proyecto">
              <option value="">— General (no es de un proyecto) —</option>
              ${opciones}
            </select>
          </label>
          <label>Un material por línea — la cantidad va al final, después de una coma
            <textarea name="lista" rows="7" required
              placeholder="cable 14/2, 2 rollos&#10;breaker 20A x5&#10;2 cajas de wirenuts&#10;cinta negra"
              style="width:100%;font:inherit;font-size:.85rem;padding:.55rem .7rem;border:1px solid var(--mp-line);border-radius:10px"></textarea>
          </label>
          <div class="modal-fila">
            <button type="button" class="accion secundaria" id="btn-mat-importar">📄 Importar nota (.txt)</button>
            <button type="submit" class="accion">✓ Agregar toda la lista</button>
          </div>
          <input id="mat-archivo" type="file" accept=".txt,text/plain" hidden>
        </form>
      </div>
      ${comprados.length ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Comprados recientes</div>
        ${comprados.map(filaMat).join("")}
      </div>` : ""}`;

    $("form-material").addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(e.target);
      try {
        await DB.crearMaterial({
          proyecto_id: d.get("proyecto") || null,
          descripcion: (d.get("descripcion") || "").toString().trim(),
          cantidad: (d.get("cantidad") || "").toString().trim() || null
        });
        await recargar();
        avisar("Material agregado ✓");
      } catch (err) {
        avisar("No se pudo agregar: " + err.message, true);
      }
    });

    // Cambiar entre "de uno en uno" y "lista rápida"
    $("btn-mat-modo").addEventListener("click", () => {
      const aLista = $("form-mat-lista").hidden;
      $("form-mat-lista").hidden = !aLista;
      $("form-material").hidden = aLista;
      $("btn-mat-modo").textContent = aLista ? "✏ Mejor de uno en uno" : "📝 Lista rápida — varios de un golpe";
    });

    // Desglosa una línea de texto libre en { material, cantidad }.
    // Entiende: "cable 14/2, 2 rollos" · "breaker 20A x5" · "toma doble (10)"
    // · "2 rollos de cable 14/2" · guiones, viñetas y numeración de notas.
    const desglosarLinea = l => {
      l = l.trim()
        .replace(/^[-•*·]\s*/, "")        // viñetas: - • *
        .replace(/^\d+[.)]\s+/, "");      // numeración: "1. " o "2) "
      if (!l) return null;
      let m = l.match(/^(.+),\s*([^,]+)$/);                 // "material, cantidad"
      if (m) return { descripcion: m[1].trim(), cantidad: m[2].trim() };
      m = l.match(/^(.+?)\s*[xX]\s*(\d+(?:\.\d+)?)$/);      // "material x5"
      if (m) return { descripcion: m[1].trim(), cantidad: m[2] };
      m = l.match(/^(.+?)\s*\((\d+(?:\.\d+)?)\)$/);         // "material (10)"
      if (m) return { descripcion: m[1].trim(), cantidad: m[2] };
      m = l.match(/^(\d+\s*(?:rollos?|cajas?|piezas?|pcs|uds?|unidades|pies|ft|galones?|tubos?|sticks?|paquetes?|bolsas?))\s+(?:de\s+)?(.+)$/i);
      if (m) return { descripcion: m[2].trim(), cantidad: m[1].trim() }; // "2 rollos de cable"
      return { descripcion: l, cantidad: null };
    };

    // Lista rápida: una línea por material (escrita o importada de una nota)
    $("form-mat-lista").addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(e.target);
      const proyecto = d.get("proyecto") || null;
      const filas = (d.get("lista") || "").toString()
        .split("\n").map(desglosarLinea).filter(Boolean);
      if (!filas.length) return;
      try {
        for (const f of filas) {
          await DB.crearMaterial({
            proyecto_id: proyecto,
            descripcion: f.descripcion,
            cantidad: f.cantidad
          });
        }
        await recargar();
        avisar(`${filas.length} materiales agregados ✓`);
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });

    // Importar una nota .txt: la vuelca en la caja para revisar antes de agregar
    $("btn-mat-importar").addEventListener("click", () => $("mat-archivo").click());
    $("mat-archivo").addEventListener("change", () => {
      const archivo = $("mat-archivo").files[0];
      if (!archivo) return;
      const lector = new FileReader();
      lector.onload = () => {
        const caja = $("form-mat-lista").querySelector("[name=lista]");
        const texto = String(lector.result || "").trim();
        caja.value = caja.value.trim() ? caja.value.trim() + "\n" + texto : texto;
        $("mat-archivo").value = "";
        avisar("Nota importada ✓ — revísala, elige el proyecto y dale a Agregar");
      };
      lector.readAsText(archivo);
    });

    // Glosario español → inglés de supply (se aplica solo al exportar;
    // dentro de la app todo se queda como Edgar lo escribió)
    const GLOSARIO_SUPPLY = [
      [/\bcinta negra\b/gi, "black electrical tape"],
      [/\bcinta\b/gi, "tape"],
      [/\btoma doble\b/gi, "duplex receptacle"],
      [/\btomacorrientes?\b/gi, "receptacle"],
      [/\btomas?\b/gi, "receptacle"],
      [/\binterruptor sencillo\b/gi, "single-pole switch"],
      [/\binterruptor(es)?\b/gi, "switch"],
      [/\bapagador(es)?\b/gi, "switch"],
      [/\bvarillas? de tierra\b/gi, "ground rod"],
      [/\btierra\b/gi, "ground"],
      [/\bcemento pvc\b/gi, "PVC cement"],
      [/\blimpiador\b/gi, "PVC primer"],
      [/\bcuerda de jalar\b/gi, "pull string"],
      [/\bgu[ií]a de pescar\b/gi, "fish tape"],
      [/\bradio largo\b/gi, "long-radius"],
      [/\bnoventas?\b/gi, "90° sweep elbow"],
      [/\bcodos? est[aá]ndar(es)?\b/gi, "standard elbow"],
      [/\bcodos?\b/gi, "elbow"],
      [/\bconector \/ adaptador macho\b/gi, "male adapter (MA)"],
      [/\badaptador(es)? macho\b/gi, "male adapter (MA)"],
      [/\bconector(es)?\b/gi, "connector"],
      [/\babrazaderas?\b/gi, "clamp"],
      [/\bgrapas?\b/gi, "staples"],
      [/\banclas?\b/gi, "anchors"],
      [/\btornillos?\b/gi, "screws"],
      [/\btuercas de resorte\b/gi, "spring nuts"],
      [/\bluminarias?\b/gi, "light fixture"],
      [/\bluces\b/gi, "lights"],
      [/\bbombillos?\b/gi, "bulb"],
      [/\babanicos?\b/gi, "ceiling fan"],
      [/\btableros?\b/gi, "panel"],
      [/\btapas?\b/gi, "cover"],
      [/\bplacas?\b/gi, "plate"],
      [/\bcable (\d+\/\d+)\s*mc\b/gi, "$1 MC cable"],
      [/\bcable (\d+\/\d+)/gi, "$1 Romex (NM-B)"],
      [/\bcables?\b/gi, "wire"],
      [/\balambres?\b/gi, "wire"],
      [/\btubos? el[eé]ctricos?\b/gi, "conduit"],
      [/\btubo\b/gi, "conduit"],
      [/\btuber[ií]a\b/gi, "conduit"],
      [/\btramos de\b/gi, "lengths of"],
      [/\brollos?\b/gi, m => (/s$/i.test(m) ? "rolls" : "roll")],
      [/\bcajas\b/gi, "boxes"],
      [/\bcaja\b/gi, "box"],
      [/\bpiezas?\b/gi, "pcs"],
      [/\bunidades\b/gi, "units"],
      [/\bpies\b/gi, "ft"],
      [/\bgalones?\b/gi, "gal"],
      [/\bpaquetes?\b/gi, "pack"],
      [/\bbolsas?\b/gi, "bag"],
      [/\bd[ií]as?\b/gi, "day"],
      [/\brenta:\s*/gi, "RENTAL: "],
      [/\brevisar si falta\b/gi, "if missing (check our stock first)"],
      [/\bojo\b/gi, "NOTE"],
      [/\bno sirve\b/gi, "does NOT work"],
      // — frases y vocabulario general de las notas —
      [/\bqueda corto\b/gi, "comes up short"],
      [/\bsi va directo a (la )?pared\b/gi, "if mounted directly to the wall"],
      [/\bmeterla al armar la corrida\b/gi, "pull it in while assembling the run"],
      [/\bsellar (la )?entrada al?\b/gi, "seal the entry at"],
      [/\bdefinir si\b/gi, "decide:"],
      [/\btuercas? de resorte\b/gi, "spring nuts"],
      [/\bcanal(es)?\b/gi, "channel"],
      [/\bprofundidad\b/gi, "depth"],
      [/\bancho\b/gi, "width"],
      [/\bpared(es)?\b/gi, "wall"],
      [/\btechos?\b/gi, "ceiling"],
      [/\bpisos?\b/gi, "floor"],
      [/\bgarajes?\b/gi, "garage"],
      [/\bzanjas?\b/gi, "trench"],
      [/\bespacios\b/gi, "spaces"],
      [/\best[aá]ndar(es)?\b/gi, "standard"],
      [/\bdirecto\b/gi, "directly"],
      [/\bm[ií]nimo\b/gi, "minimum"],
      [/\bm[aá]ximo\b/gi, "maximum"],
      [/\bpanel exterior\b/gi, "outdoor panel"],
      [/\bexterior(es)?\b/gi, "outdoor"],
      [/\binterior(es)?\b/gi, "indoor"],
      [/\borugas?\b/gi, "tracked"],
      [/\btarifas?\b/gi, "rate"],
      [/\balcanza\b/gi, "is enough"],
      [/\blunes\b/gi, "Monday"], [/\bmartes\b/gi, "Tuesday"], [/\bmi[eé]rcoles\b/gi, "Wednesday"],
      [/\bjueves\b/gi, "Thursday"], [/\bviernes\b/gi, "Friday"], [/\bs[aá]bado\b/gi, "Saturday"],
      // — palabritas de unión (van al final, en minúscula, para no romper siglas) —
      [/\bdel\b/g, "of the"],
      [/\bde\b/g, "of"],
      [/\bel\b/g, "the"], [/\bla\b/g, "the"], [/\blos\b/g, "the"], [/\blas\b/g, "the"],
      [/\bcon\b/g, "with"], [/\bsin\b/g, "without"],
      [/\bpara\b/g, "for"], [/\bhasta\b/g, "up to"],
      [/\bsi\b/g, "if"], [/\bo\b/g, "or"], [/\bu\b/g, "or"], [/\by\b/g, "and"], [/\bva\b/g, "goes"],
    ];
    const alSupply = s => GLOSARIO_SUPPLY.reduce(
      (t, [re, rep]) => t.replace(re, rep), String(s || ""));

    // Exportar la lista "Por comprar" para mandarla al supply (sale en inglés)
    const btnSupply = $("btn-mat-supply");
    if (btnSupply) btnSupply.addEventListener("click", async () => {
      const porProy = {};
      faltan.forEach(m => { (porProy[m.proyecto || ""] = porProy[m.proyecto || ""] || []).push(m); });
      const hoy = new Date();
      let texto = `MATERIAL LIST — Max Power Electrical Solutions Inc.\n`
        + `${String(hoy.getMonth() + 1).padStart(2, "0")}/${String(hoy.getDate()).padStart(2, "0")}/${hoy.getFullYear()} · FL EC #EC13016045\n`;
      for (const [pid, items] of Object.entries(porProy)) {
        texto += `\n${pid ? "JOB: " + nombreProy(pid).toUpperCase() : "GENERAL / SHOP"}\n`;
        // sinMontos también aquí: la pantalla 🛒 Materiales la abre todo el
        // equipo y este botón arma un texto que se manda por WhatsApp. Era
        // el último sitio por donde un precio escrito en la cantidad
        // ("1 día (~$280)") se le podía escapar a Jian o a Osbel.
        // Para el dueño, sinMontos devuelve el texto tal cual.
        for (const m of items) texto += `• ${alSupply(sinMontos(m.descripcion))}${m.cantidad ? ` — ${alSupply(sinMontos(m.cantidad))}` : ""}\n`;
      }
      if (navigator.share) {
        try { await navigator.share({ title: "Lista de materiales", text: texto }); return; }
        catch (err) { if (err && err.name === "AbortError") return; }
      }
      try {
        await navigator.clipboard.writeText(texto);
        avisar("Lista copiada ✓ — pégala en el texto o correo al supply");
      } catch (err) {
        const ta = document.createElement("textarea");
        ta.value = texto; document.body.appendChild(ta);
        ta.select(); document.execCommand("copy"); ta.remove();
        avisar("Lista copiada ✓ — pégala en el texto o correo al supply");
      }
    });
    $("materiales-panel").querySelectorAll(".btn-mat-comprado").forEach(btn => {
      btn.addEventListener("click", async () => {
        // Al comprar, se anota el precio para el control de gastos
        const respuesta = prompt("¿Cuánto costó? (solo el número, ej: 45.99)\n\nDéjalo vacío si no quieres anotar el precio ahora — lo puedes poner después con el ✎.");
        if (respuesta === null) return; // canceló
        const limpio = respuesta.replace(/[$,\s]/g, "");
        const precio = limpio ? Number(limpio) : null;
        if (limpio && !Number.isFinite(precio)) { avisar("Ese precio no se entendió — solo el número, ej: 45.99", true); return; }
        try {
          await DB.cambiarMaterial(btn.dataset.id, { estado: "comprado", precio });
          await recargar();
          avisar(precio !== null ? `Comprado ✓ — ${fmt(precio)} anotado al proyecto` : "Marcado como comprado ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    // ✎ abre/cierra el formulario de corrección de ese material
    $("materiales-panel").querySelectorAll(".btn-mat-editar").forEach(btn => {
      btn.addEventListener("click", () => {
        const form = $("materiales-panel")
          .querySelector(`.form-mat-editar[data-id="${btn.dataset.id}"]`);
        if (form) form.hidden = !form.hidden;
      });
    });
    $("materiales-panel").querySelectorAll(".form-mat-editar").forEach(form => {
      form.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(form);
        const cambios = {
          descripcion: (d.get("descripcion") || "").toString().trim(),
          cantidad: (d.get("cantidad") || "").toString().trim() || null,
          proyecto_id: d.get("proyecto") || null
        };
        if (usuario.finanzas) {
          const precioTxt = (d.get("precio") || "").toString().trim();
          cambios.precio = precioTxt !== "" && Number.isFinite(Number(precioTxt)) ? Number(precioTxt) : null;
        }
        try {
          await DB.cambiarMaterial(form.dataset.id, cambios);
          await recargar();
          avisar("Material corregido ✓");
        } catch (err) { avisar("No se pudo corregir: " + err.message, true); }
      });
    });
    $("materiales-panel").querySelectorAll(".btn-mat-eliminar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este material de la lista?\n\nÚsalo si se anotó por error o su trabajo ya no existe.")) return;
        try {
          await DB.eliminarMaterial(btn.dataset.id);
          await recargar();
          avisar("Material eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });
    $("materiales-panel").querySelectorAll(".btn-mat-pasar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const pen = pendientesTodos().find(x => String(x.id) === String(btn.dataset.id));
        if (!pen) return;
        try {
          await DB.crearMaterial({
            proyecto_id: pen.proyecto || null,
            descripcion: pen.descripcion,
            origen_pendiente: pen.id
          });
          await recargar();
          avisar("Pasado a la lista de compras ✓ (el pendiente sigue rojo hasta resolverse en obra)");
        } catch (err) { avisar("No se pudo pasar: " + err.message, true); }
      });
    });

    // Filtro por proyecto
    $("filtro-mat").addEventListener("change", e => {
      filtroMateriales = e.target.value;
      pintarMateriales();
    });

    // Gestiones de arranque
    $("form-gestion").addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(e.target);
      try {
        await DB.crearGestion({
          proyecto_id: d.get("proyecto") || null,
          descripcion: (d.get("descripcion") || "").toString().trim()
        });
        await recargar();
        avisar("Gestión anotada ✓");
      } catch (err) { avisar("No se pudo anotar: " + err.message, true); }
    });
    $("materiales-panel").querySelectorAll(".btn-gestion-hecha").forEach(btn => {
      btn.addEventListener("click", async () => {
        try {
          await DB.cambiarGestion(btn.dataset.id, { hecha: true });
          await recargar();
          avisar("Gestión hecha ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("materiales-panel").querySelectorAll(".btn-gestion-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar esta gestión?")) return;
        try {
          await DB.eliminarGestion(btn.dataset.id);
          await recargar();
          avisar("Gestión eliminada ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });

    // Registrar compra: con foto o a mano
    const btnRecibo = $("materiales-panel").querySelector(".btn-importar-recibo");
    const formRecibo = $("form-recibo");
    const formMano = $("form-compra-mano");
    const modos = $("compra-modos");
    btnRecibo.addEventListener("click", () => {
      modos.hidden = !modos.hidden;
      if (modos.hidden) { formRecibo.hidden = true; formMano.hidden = true; }
    });
    $("materiales-panel").querySelector(".btn-compra-foto").addEventListener("click", () => {
      formRecibo.hidden = false; formMano.hidden = true;
    });
    $("materiales-panel").querySelector(".btn-compra-mano").addEventListener("click", () => {
      formMano.hidden = false; formRecibo.hidden = true;
    });
    formMano.addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(formMano);
      const esDevolucion = d.get("tipo") === "devolucion";
      let notas = (d.get("notas") || "").toString().trim();
      if (esDevolucion) notas = "DEVOLUCIÓN" + (notas ? " — " + notas : "");
      const fila = {
        proyecto_id: d.get("proyecto") || null,
        ruta: null,
        notas: notas || null,
        proveedor: (d.get("proveedor") || "").toString().trim() || null,
        co: (d.get("co") || "").toString().trim() || null
      };
      const totalTxt = (d.get("total") || "").toString().trim();
      if (usuario.finanzas && totalTxt !== "" && Number.isFinite(Number(totalTxt))) {
        fila.total = esDevolucion ? -Math.abs(Number(totalTxt)) : Number(totalTxt);
        fila.estado = "leido";
      }
      try {
        await DB.crearRecibo(fila);
        await recargar();
        avisar(fila.total !== undefined
          ? `Compra registrada ✓ — ${fmt(fila.total)} anotado al proyecto`
          : "Compra registrada ✓ — Edgar le pone el total con el ✎");
      } catch (err) { avisar("No se pudo registrar: " + err.message, true); }
    });
    formRecibo.addEventListener("submit", async e => {
      e.preventDefault();
      const archivo = formRecibo.elements.archivo.files[0];
      if (!archivo) return;
      const d = new FormData(formRecibo);
      const $btn = formRecibo.querySelector('button[type="submit"]');
      $btn.disabled = true;
      $btn.textContent = "Subiendo…";
      try {
        const blob = await reducirImagen(archivo).catch(() => archivo);
        const pid = d.get("proyecto") || "general";
        const ruta = await DB.subirFoto(pid, blob, blob.type || archivo.type, "recibos");
        const esDevolucion = d.get("tipo") === "devolucion";
        let notasRecibo = (d.get("notas") || "").toString().trim();
        // La marca DEVOLUCIÓN viaja en las notas: la ve la rutina y la ve la lista
        if (esDevolucion) notasRecibo = "DEVOLUCIÓN" + (notasRecibo ? " — " + notasRecibo : "");
        const fila = {
          proyecto_id: d.get("proyecto") || null,
          ruta,
          notas: notasRecibo || null,
          co: (d.get("co") || "").toString().trim() || null
        };
        if (usuario.finanzas) {
          const totalTxt = (d.get("total") || "").toString().trim();
          if (totalTxt !== "" && Number.isFinite(Number(totalTxt))) {
            // Una devolución siempre entra en negativo: resta sola en Rentabilidad
            fila.total = esDevolucion ? -Math.abs(Number(totalTxt)) : Number(totalTxt);
            fila.estado = "leido";
          }
          const prov = (d.get("proveedor") || "").toString().trim();
          if (prov) fila.proveedor = prov;
        }
        await DB.crearRecibo(fila);
        await recargar();
        avisar(fila.total !== undefined
          ? `Recibo subido ✓ — ${fmt(fila.total)} anotado al proyecto`
          : "Recibo subido ✓ — la rutina le pondrá el total al leerlo (12pm/6pm)");
      } catch (err) {
        avisar("No se pudo subir el recibo: " + err.message, true);
        $btn.disabled = false;
        $btn.textContent = "⬆ Subir recibo";
      }
    });
    $("materiales-panel").querySelectorAll(".btn-recibo-total").forEach(btn => {
      btn.addEventListener("click", async () => {
        // Se corrigen las tres cosas, una por una (cancelar en cualquiera = no cambia nada)
        const respuesta = prompt("Total del recibo (solo el número, ej: 342.18).\nDEVOLUCIÓN va con signo menos (ej: -45.99).\nDéjalo igual para no cambiarlo:", btn.dataset.total || "");
        if (respuesta === null) return;
        const proveedor = prompt("¿Dónde se compró? (proveedor):", btn.dataset.proveedor || "");
        if (proveedor === null) return;
        const notas = prompt("Descripción (qué se compró / nota):", btn.dataset.notas || "");
        if (notas === null) return;
        const cambios = { proveedor: proveedor.trim() || null, notas: notas.trim() || null };
        const limpio = respuesta.replace(/[$,\s]/g, "");
        if (limpio) {
          const total = Number(limpio);
          if (!Number.isFinite(total)) { avisar("Ese total no se entendió — no se cambió nada", true); return; }
          cambios.total = total;
          cambios.estado = "leido";
        }
        try {
          await DB.cambiarRecibo(btn.dataset.id, cambios);
          await recargar();
          avisar("Recibo corregido ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    // 📷 Ponerle (o cambiarle) la foto a un recibo ya anotado — el respaldo
    $("materiales-panel").querySelectorAll(".btn-recibo-foto").forEach(btn => {
      btn.addEventListener("click", () => {
        const input = document.createElement("input");
        input.type = "file";
        input.accept = "image/*";
        input.addEventListener("change", async () => {
          const archivo = input.files[0];
          if (!archivo) return;
          btn.disabled = true;
          btn.textContent = "⏳";
          try {
            const blob = await reducirImagen(archivo).catch(() => archivo);
            const ruta = await DB.subirFoto(btn.dataset.proyecto || "general", blob, blob.type || archivo.type, "recibos");
            const cambios = { ruta };
            if (btn.dataset.estado === "sin_foto") cambios.estado = "leido";
            await DB.cambiarRecibo(btn.dataset.id, cambios);
            await recargar();
            avisar("Foto del recibo guardada ✓");
          } catch (err) {
            avisar("No se pudo subir la foto: " + err.message, true);
            btn.disabled = false;
            btn.textContent = "📷";
          }
        });
        input.click();
      });
    });
    // 📌 Asignarle proyecto a una compra dictada por voz que quedó "sin proyecto"
    $("materiales-panel").querySelectorAll(".btn-recibo-asignar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const opciones = proyectos().filter(x => ["ejecucion", "aprobado", "pausa"].includes(x.estado));
        if (!opciones.length) { avisar("No hay proyectos activos para asignar.", true); return; }
        const menu = opciones.map((x, i) => `${i + 1}. ${x.nombre}`).join("\n");
        const resp = prompt("¿A qué proyecto va esta compra?\n\n" + menu + "\n\nEscribe el número:");
        if (!resp) return;
        const idx = parseInt(resp, 10) - 1;
        if (isNaN(idx) || !opciones[idx]) { avisar("Número inválido.", true); return; }
        try {
          await DB.cambiarRecibo(btn.dataset.id, { proyecto_id: opciones[idx].id });
          await recargar();
          avisar(`Compra asignada a ${opciones[idx].nombre} ✓`);
        } catch (err) { avisar("No se pudo asignar: " + err.message, true); }
      });
    });
    $("materiales-panel").querySelectorAll(".btn-recibo-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este recibo?")) return;
        try {
          await DB.eliminarRecibo(btn.dataset.id);
          await recargar();
          avisar("Recibo eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });
    // Enlaces firmados para ver las fotos de los recibos
    const rutasRecibos = [...$("materiales-panel").querySelectorAll(".recibo-ver")].map(a => a.dataset.ruta);
    if (rutasRecibos.length) {
      DB.firmarFotos(rutasRecibos).then(mapa => {
        $("materiales-panel").querySelectorAll(".recibo-ver").forEach(a => {
          if (mapa[a.dataset.ruta]) a.href = mapa[a.dataset.ruta];
        });
      }).catch(() => avisar("No se pudieron cargar las fotos de los recibos — revisa la señal.", true));
    }
  }

  // ============================================================
  // 📊 CONTROL DE GASTOS — solo el dueño
  // ============================================================
  function irGastos() {
    if (!usuario.finanzas) return;
    mostrar("gastos", { kicker: "Solo dueño", titulo: "Control de gastos", volver: true, nuevo: false });
    pintarGastos();
  }
  $("btn-gastos").addEventListener("click", irGastos);

  function pintarGastos() {
    const activos = proyectos()
      .filter(p => ["ejecucion", "aprobado", "pausa"].includes(p.estado));
    const tarjetas = activos.length === 0
      ? `<div class="inicio-card"><p class="cal-sin-eventos">No hay proyectos activos.</p></div>`
      : activos.map(p => {
      const mo = costoManoDeObra(p);
      const matGasto = gastoMateriales(p.id);
      const matPresu = p.presupuestoMateriales;
      const lineaMO = mo && mo.horas > 0
        ? `<div class="rent-fila"><span>Mano de obra (${mo.horas} h)</span><span>${fmt(mo.costo)}</span></div>
           ${barraGasto(mo.costo, mo.presupuesto) || `<div class="gasto-sub">sin horas estimadas para comparar</div>`}`
        : `<div class="gasto-sub">sin horas registradas${mo ? "" : " · define 💲 Costos del equipo"}</div>`;
      const extGasto = gastoExternos(p.id);
      const lineaMat = `
        <div class="rent-fila"><span>Materiales comprados</span><span>${fmt(matGasto)}</span></div>
        ${barraGasto(matGasto, matPresu) || `<div class="gasto-sub">sin presupuesto de materiales — ponlo aquí abajo</div>`}
        ${extGasto > 0 ? `<div class="rent-fila"><span>Ayuda externa</span><span>${fmt(extGasto)}</span></div>` : ""}
        ${avisoMargenFlojo(p, matGasto, matPresu, mo)}`;
      return `
        <div class="inicio-card gasto-card">
          <button class="gasto-nombre" data-id="${esc(p.id)}">${esc(p.nombre)} <span class="cat-flecha">›</span></button>
          ${lineaMO}
          ${lineaMat}
          <div class="gasto-presu-fila">
            <label>Presupuesto de materiales ($)
              <input class="inp-presu" data-id="${esc(p.id)}" type="number" min="0" step="1"
                inputmode="decimal" value="${matPresu != null ? matPresu : ""}" placeholder="Ej: 2500">
            </label>
            <button class="accion secundaria btn-presu" data-id="${esc(p.id)}">💾 Guardar</button>
          </div>
        </div>`;
    }).join("");

    // 💲 Costos del equipo: gaveta plegada al fondo (se toca 2 veces al año).
    // Gustavo (license holder) NO aparece: su pago es gasto general, no de obra.
    const costos = state.costos || {};
    const equipoCostos = (state.equipo || []).filter(u => u.rol !== "license" && u.activo);
    const filasCostos = equipoCostos.map(u => `
      <label>${esc(u.nombre)} — costo por hora ($)
        <input name="c-${u.id}" type="number" min="0" step="0.5" inputmode="decimal"
          value="${costos[u.id] != null ? costos[u.id] : ""}" placeholder="Ej: 35">
      </label>`).join("");
    // Manejo del equipo: marcar inactivo al que se va (la historia queda)
    const filasEquipo = (state.equipo || [])
      .filter(u => u.rol !== "dueno")
      .map(u => `
        <div class="equipo-item">
          <span class="equipo-dot ${u.activo ? "verde" : "gris"}"></span>
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(u.nombre)}</span>
            <span class="alcance-estado">${u.rol === "license" ? "License Holder" : "Campo"}${u.activo ? "" : " · INACTIVO"}</span>
          </span>
          <button class="accion secundaria btn-perfil-activo" data-id="${esc(u.id)}" data-activo="${u.activo ? "1" : ""}">
            ${u.activo ? "Marcar inactivo" : "Reactivar"}
          </button>
        </div>`).join("");
    const gaveta = `
      <div class="inicio-card">
        <details class="costos-gaveta">
          <summary>💲 Costos del equipo <span class="gaveta-nota">(toca para abrir — solo se ajusta cuando cambia un salario)</span></summary>
          <form id="form-costos" class="cal-form">
            <p class="modal-nota">El costo completo por hora para la empresa (salario + taxes + seguro).
            Con esto cada proyecto calcula su rentabilidad solo.</p>
            ${filasCostos}
            <button type="submit" class="accion">Guardar costos</button>
          </form>
        </details>
      </div>
      <div class="inicio-card">
        <details class="costos-gaveta">
          <summary>🧰 Ayudantes externos <span class="gaveta-nota">(gente puntual con tarifa — sin cuenta en la app, solo tú los ves)</span></summary>
          ${(state.ayudantes || []).map(a => {
            const gastado = (state.externos || [])
              .filter(x => x.ayudante === a.id)
              .reduce((s, x) => s + (Number(x.costo) || 0), 0);
            return `
            <div class="equipo-item">
              <span class="equipo-dot ${a.activo ? "verde" : "gris"}"></span>
              <span class="alcance-info">
                <span class="alcance-titulo">${esc(a.nombre)} — ${fmt(a.costoHora)}/h</span>
                <span class="alcance-estado">${gastado ? `lleva ${fmt(gastado)} pagado en proyectos` : "sin trabajos anotados todavía"}${a.activo ? "" : " · INACTIVO"}</span>
              </span>
              <button class="insp-borrar btn-ayud-tarifa" data-id="${a.id}" data-nombre="${esc(a.nombre)}" data-tarifa="${a.costoHora}" title="Cambiar tarifa">✎</button>
              <button class="accion secundaria btn-ayud-activo" data-id="${a.id}" data-activo="${a.activo ? "1" : ""}">
                ${a.activo ? "Inactivo" : "Reactivar"}
              </button>
            </div>`;
          }).join("") || `<p class="cal-sin-eventos">Sin ayudantes todavía — agrega el primero aquí abajo.</p>`}
          <form id="form-ayudante" class="cal-form">
            <div class="modal-fila">
              <label>Nombre del ayudante
                <input name="nombre" type="text" required placeholder="Ej: Pedro" autocomplete="off">
              </label>
              <label>Tarifa por hora ($)
                <input name="tarifa" type="number" min="1" step="0.5" inputmode="decimal" required placeholder="Ej: 50">
              </label>
            </div>
            <p class="modal-nota">Luego le anotas sus horas en cada proyecto (ficha → Ayuda externa):
            eliges su nombre, pones las horas y el costo se calcula solo con esta tarifa.</p>
            <button type="submit" class="accion secundaria">+ Agregar ayudante</button>
          </form>
        </details>
      </div>
      <div class="inicio-card">
        <details class="costos-gaveta">
          <summary>👥 Equipo <span class="gaveta-nota">(marcar inactivo al que se va — su historia queda)</span></summary>
          ${filasEquipo}
          <p class="modal-nota" style="margin-top:0.5rem">Para <strong>agregar</strong> un trabajador nuevo con acceso a la app,
          pídeselo a Claude — te da los 3 pasos del panel de Supabase (2 minutos).
          Si es alguien puntual sin acceso, usa "Ayuda externa" en el proyecto o la
          nómina de <strong>🧰 Ayudantes externos</strong> aquí arriba.</p>
        </details>
      </div>`;

    $("gastos-panel").innerHTML = tarjetas + gaveta;

    $("form-costos").addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(e.target);
      try {
        for (const u of equipoCostos) {
          const v = (d.get("c-" + u.id) || "").toString().trim();
          if (v !== "" && Number.isFinite(Number(v))) await DB.guardarCosto(u.id, Number(v));
        }
        await recargar();
        avisar("Costos guardados ✓ — la rentabilidad ya usa los números nuevos");
      } catch (err) {
        avisar("No se pudo guardar: " + err.message, true);
      }
    });
    $("gastos-panel").querySelectorAll(".btn-perfil-activo").forEach(btn => {
      btn.addEventListener("click", async () => {
        const activar = !btn.dataset.activo;
        if (!activar && !confirm("¿Marcar a esta persona como inactiva?\n\nDesaparece de las listas y semáforos, pero sus horas e historia quedan intactas. Se puede reactivar cuando quieras.")) return;
        try {
          await DB.cambiarPerfil(btn.dataset.id, { activo: activar });
          await recargar();
          avisar(activar ? "Reactivado ✓" : "Marcado como inactivo ✓ (su historia queda)");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });

    // 🧰 Nómina de ayudantes externos (solo etiqueta + tarifa, sin cuenta)
    const formAyud = $("form-ayudante");
    if (formAyud) formAyud.addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(formAyud);
      try {
        await DB.crearAyudante({
          nombre: (d.get("nombre") || "").toString().trim(),
          costo_hora: Number(d.get("tarifa"))
        });
        await recargar();
        avisar("Ayudante agregado ✓ — ya puedes anotarle horas en cualquier proyecto");
      } catch (err) { avisar("No se pudo agregar: " + err.message, true); }
    });
    $("gastos-panel").querySelectorAll(".btn-ayud-tarifa").forEach(btn => {
      btn.addEventListener("click", async () => {
        const resp = prompt(`Tarifa por hora de ${btn.dataset.nombre} ($):`, btn.dataset.tarifa);
        if (resp === null) return;
        const tarifa = Number(resp.replace(/[$,\s]/g, ""));
        if (!Number.isFinite(tarifa) || tarifa <= 0) { avisar("Esa tarifa no se entendió", true); return; }
        try {
          await DB.cambiarAyudante(btn.dataset.id, { costo_hora: tarifa });
          await recargar();
          avisar("Tarifa actualizada ✓ (los trabajos ya anotados no cambian)");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("gastos-panel").querySelectorAll(".btn-ayud-activo").forEach(btn => {
      btn.addEventListener("click", async () => {
        try {
          await DB.cambiarAyudante(btn.dataset.id, { activo: !btn.dataset.activo });
          await recargar();
          avisar(btn.dataset.activo ? "Ayudante inactivo ✓ (su historia queda)" : "Ayudante reactivado ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });

    $("gastos-panel").querySelectorAll(".gasto-nombre").forEach(btn => {
      btn.addEventListener("click", () => irDetalle(btn.dataset.id));
    });
    $("gastos-panel").querySelectorAll(".btn-presu").forEach(btn => {
      btn.addEventListener("click", async () => {
        const inp = $("gastos-panel").querySelector(`.inp-presu[data-id="${btn.dataset.id}"]`);
        const v = (inp.value || "").trim();
        const monto = v === "" ? null : Number(v);
        if (v !== "" && !Number.isFinite(monto)) { avisar("Ese monto no se entendió", true); return; }
        try {
          await DB.guardarPresupuesto(btn.dataset.id, monto);
          await recargar();
          avisar("Presupuesto guardado ✓");
        } catch (err) { avisar("No se pudo guardar: " + err.message, true); }
      });
    });
  }

  // ============================================================
  // 🧮 EL ESTIMADOR — solo el dueño (la receta secreta de Edgar)
  // Réplica exacta de la fórmula del Excel: catálogo maestro,
  // escenarios A/B/C, benefits, tax, overhead por hora-hombre y profit.
  // ============================================================
  let estData = null;        // { catalogo, escenarios, estimados, items }
  let estimadoActivo = null; // id del estimado abierto
  let colaEnsambles = Promise.resolve(); // fila india de los clics +/- de ensambles
  let frecuentesExpandido = false;       // "Ver más" de ⭐ Lo que más usas

  function irEstimador(abrirId) {
    if (!usuario.finanzas) return;
    mostrar("estimador", { kicker: "Solo dueño", titulo: "Estimador", volver: true, nuevo: false });
    estimadoActivo = abrirId || null;
    $("estimador-panel").innerHTML = `<div class="inicio-card"><p class="cal-sin-eventos">Cargando el estimador…</p></div>`;
    recargarEstimador();
  }
  $("btn-estimador").addEventListener("click", () => irEstimador());
  $("btn-levantamiento").addEventListener("click", () => irLevLista());

  async function recargarEstimador() {
    try {
      estData = await DB.cargarEstimador();
      DB.cargarPropuestas().then(d => { propData = d; }).catch(() => { propData = propData || { propuestas: [], opciones: [] }; });
    } catch (err) {
      $("estimador-panel").innerHTML = `<div class="inicio-card"><p class="cal-sin-eventos">` +
        `No se pudo cargar el estimador — revisa la señal. ` +
        `<button type="button" class="accion secundaria" id="est-reintentar">Reintentar</button></p></div>`;
      $("est-reintentar").addEventListener("click", recargarEstimador);
      avisar("No se pudo cargar el estimador: " + err.message, true);
      return;
    }
    pintarEstimador();
  }

  // ---------- Motor v2: ítems + ensambles + automáticos ----------
  const normTxt = s => String(s || "").replace(/\s+/g, " ").trim().toUpperCase();
  const buscaCatalogo = frag => (estData.catalogo || [])
    .find(c => normTxt(c.item).includes(normTxt(frag)));
  const catalogoExacto = nombre => (estData.catalogo || [])
    .find(c => normTxt(c.item) === normTxt(nombre));
  const ES_LINEAL_CABLE = n => /ROMEX|MC\b|THHN|THW|MCM|SPEAKER WIRE|CAT ?[56]/.test(n) && !/CONNECTOR|STAPLE|SNAP/.test(n);
  const ES_TUBERIA = n => /CONDUIT/.test(n);

  // Lo que la app carga sola en modo PLANOS (lo que NO se mide en el plano)
  function autosPlanos(base, cable, cfg) {
    const autos = {};
    const add = (cat, qty, motivo) => {
      if (!cat || qty <= 0) return;
      const k = cat.item;
      (autos[k] = autos[k] || { item: cat.item, unidad: cat.unidad, precio: cat.precio,
        horas: cat.horas_unidad, cantidad: 0, auto: motivo }).cantidad += qty;
    };
    for (const it of base) {
      const nom = normTxt(it.item);
      const qty = Number(it.cantidad) || 0;
      const mTub = nom.match(/^([\d/ -]+")\s*(EMT|PVC)/);
      if (mTub && ES_TUBERIA(nom)) {
        const talla = mTub[1].trim(), tipo = mTub[2];
        const corridas = Math.max(1, Math.ceil(qty / (cfg.corrida_ft || 25)));
        add(buscaCatalogo(`${talla} ${tipo} COUPLING`), Math.max(0, Math.ceil(qty / 10) - corridas), "fittings");
        add(buscaCatalogo(`${talla} ${tipo} CONNECTOR`), corridas * 2, "fittings");
        if (tipo === "EMT") {
          const straps = Math.ceil(qty / (cfg.strap_ft || 8)) + corridas;
          add(buscaCatalogo(`${talla} EMT STRAP`), straps, "fijación");
          add(buscaCatalogo("TAPCON"), straps * (cfg.tapcon_por_strap || 2), "fijación");
        }
      }
      if (/ROMEX/.test(nom) && ES_LINEAL_CABLE(nom)) {
        const pies = normTxt(it.unidad) === "MLF" ? qty * 1000 : qty;
        add(buscaCatalogo("ROMEX STAPLES"), Math.ceil(pies / 4), "fijación");
      }
    }
    // Conectores por cada luminaria/dispositivo, según el cable del trabajo
    const luminarias = base.filter(i => {
      const cat = catalogoExacto(i.item);
      return (cat && cat.seccion === "LIGHTING FIXTURES")
        || /RECESSED|FIXTURE|PENDANT|SCONCE|CHANDELIER|CEILING FAN/.test(normTxt(i.item));
    }).reduce((s, i) => s + (Number(i.cantidad) || 0), 0);
    if (luminarias > 0) {
      if (cable !== "mc") add(buscaCatalogo("NM CABLE CONNECTOR"), Math.round(luminarias * (cable === "mixto" ? 0.5 : 1)), "conectores");
      if (cable !== "romex") add(buscaCatalogo("MC SNAP-IN CONNECTOR"), Math.round(luminarias * (cable === "mixto" ? 0.5 : 1)), "conectores");
    }
    return Object.values(autos);
  }

  // Pies de cable promedio que trae un ensamble (su componente lineal)
  function piesPromedioEnsamble(ensambleId) {
    const cable = (estData.ensambleItems || [])
      .filter(x => x.ensamble_id === ensambleId)
      .find(x => ES_LINEAL_CABLE(normTxt(x.item)));
    if (!cable) return null;
    const cat = catalogoExacto(cable.item) || {};
    return normTxt(cat.unidad) === "MLF" ? Number(cable.cantidad) * 1000 : Number(cable.cantidad);
  }

  // Explosión de UN ensamble en sus componentes (cantidad = cuántas unidades)
  function itemsDeEnsamble(ensambleId, cantidad, pies) {
    const ens = (estData.ensambles || []).find(x => x.id === ensambleId);
    // Circuitos específicos: si Edgar midió los pies, mandan los suyos
    const piesMedidos = ens && ens.pies_editable && Number(pies) > 0 ? Number(pies) : null;
    const piesProm = piesMedidos ? piesPromedioEnsamble(ensambleId) : null;
    return (estData.ensambleItems || [])
      .filter(x => x.ensamble_id === ensambleId)
      .map(cmp => {
        const cat = catalogoExacto(cmp.item) || {};
        let porUnidad = Number(cmp.cantidad);
        if (piesMedidos && piesProm) {
          const nom = normTxt(cmp.item);
          if (ES_LINEAL_CABLE(nom))
            porUnidad = normTxt(cat.unidad) === "MLF" ? piesMedidos / 1000 : piesMedidos;
          else if (/STAPLE/.test(nom))
            porUnidad = Math.ceil(porUnidad * (piesMedidos / piesProm));
        }
        return { item: cmp.item, unidad: cat.unidad, precio: cat.precio || 0,
                 horas: cat.horas_unidad || 0,
                 cantidad: porUnidad * Number(cantidad),
                 deEnsamble: ens ? ens.nombre : "" };
      });
  }

  // Ítems del estimado: manuales/takeoff + explosión de ensambles
  function itemsDelEstimado(est) {
    const manual = (estData.items || []).filter(i => i.estimado_id === est.id);
    const porEnsamble = (estData.estEnsambles || [])
      .filter(ee => ee.estimado_id === est.id && Number(ee.cantidad) > 0)
      .flatMap(ee => itemsDeEnsamble(ee.ensamble_id, Number(ee.cantidad), ee.pies));
    return manual.concat(porEnsamble);
  }

  // La fórmula Max Power (motor del Excel) + automáticos del v2
  function calcularEstimado(est, itemsOverride) {
    const cfg = estData.config || {};
    const base = itemsOverride || itemsDelEstimado(est);
    const esc = (estData.escenarios || []).find(e => e.id === est.escenario)
      || { foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5,
           pct_helper: .3, benefits: .25, tax_material: .07, overhead_hh: 30.19, profit: .12 };
    const n = v => Number(v) || 0;

    const rapido = est.modo === "rapido";
    const autos = (est.modo || "planos") === "planos"
      ? autosPlanos(base, est.cable || "romex", cfg) : [];

    // Merma sobre lo lineal (solo en modo planos: los pies que TÚ mediste)
    let mermaMat = 0, mermaHoras = 0;
    if ((est.modo || "planos") === "planos") {
      for (const it of base) {
        const nom = normTxt(it.item);
        const pct = ES_LINEAL_CABLE(nom) ? (cfg.merma_cable ?? 0.10)
          : ES_TUBERIA(nom) ? (cfg.merma_tuberia ?? 0.05) : 0;
        if (pct > 0) {
          mermaMat += n(it.cantidad) * n(it.precio) * pct;
          mermaHoras += n(it.cantidad) * n(it.horas) * pct;
        }
      }
    }

    // Ajustes del propio estimado: si el dueño editó un % en el resumen,
    // ese manda; si está vacío, se usa el del escenario/configuración.
    const nn = v => (v === null || v === undefined || v === "" ? null : Number(v));
    const miscPct = nn(est.misc_pct) ?? (cfg.misc_pct ?? 0.03);
    const taxPct = nn(est.tax_pct) ?? n(esc.tax_material);
    const ohHH = nn(est.overhead_hh) ?? n(esc.overhead_hh);
    const profitPct = nn(est.profit_pct) ?? n(esc.profit);
    const markupPct = nn(est.markup_pct) ?? 0;

    // Modo ⚡ Rápido: el material son las líneas que Edgar escribió (o un
    // total), no los ítems del catálogo
    const lineasMat = rapido && Array.isArray(est.lineas_material) ? est.lineas_material : [];
    const matItems = rapido
      ? lineasMat.reduce((s, l) => s + n(l.monto), 0)
      : base.reduce((s, i) => s + n(i.cantidad) * n(i.precio), 0)
        + autos.reduce((s, i) => s + n(i.cantidad) * n(i.precio), 0) + mermaMat;
    const misc = matItems * miscPct;
    const matSubtotal = matItems + misc;
    const tax = matSubtotal * taxPct;
    // Markup: es de MATERIALES — va después del sales tax
    const markup = (matSubtotal + tax) * markupPct;
    const totalMaterial = matSubtotal + tax + markup;

    // Modo ⚡ Rápido: las horas son las que Edgar decidió, punto
    const horasBase = rapido
      ? n(est.horas_directas)
      : base.reduce((s, i) => s + n(i.cantidad) * n(i.horas), 0)
        + autos.reduce((s, i) => s + n(i.cantidad) * n(i.horas), 0) + mermaHoras;
    const horas = horasBase * (n(est.factor) || 1);
    // La cuadrilla: la propia del estimado (Custom) > la del escenario > las 3 de siempre
    const mezcla = cuadrillaDe(est, esc);
    const tarifaMezclada = mezcla.reduce((s, m) => s + n(m.pct) * n(m.tarifa), 0);
    const laborBase = horas * tarifaMezclada;
    const benefitsPct = nn(est.benefits_pct) ?? n(esc.benefits);
    const benefits = laborBase * benefitsPct;
    const totalLabor = laborBase + benefits;
    const prime = totalLabor + totalMaterial;
    const overhead = horas * ohHH;
    const profit = (prime + overhead) * profitPct;
    const bid = prime + overhead + profit;
    return { items: base, autos, mermaMat, mermaHoras, misc, esc, matSubtotal, tax,
             totalMaterial, horasBase, horas, laborBase, benefits, totalLabor,
             prime, overhead, profit, markup, bid,
             miscPct, taxPct, ohHH, profitPct, markupPct,
             mezcla, tarifaMezclada, benefitsPct, lineasMat,
             // $ por hora cargado: el precio final entre las horas (todo adentro)
             tarifaCargada: horas > 0 ? bid / horas : 0 };
  }

  // La cuadrilla de un estimado, siempre como lista [{rol, tarifa, pct}]
  // pct va en fracción (0.2 = 20%)
  function cuadrillaDe(est, esc) {
    const limpia = arr => (Array.isArray(arr) ? arr : [])
      .filter(m => m && (Number(m.tarifa) || Number(m.pct)))
      .map(m => ({ rol: String(m.rol || "").slice(0, 30), tarifa: Number(m.tarifa) || 0, pct: Number(m.pct) || 0 }));
    if (est && Array.isArray(est.mezcla) && limpia(est.mezcla).length) return limpia(est.mezcla);
    if (esc && Array.isArray(esc.mezcla) && limpia(esc.mezcla).length) return limpia(esc.mezcla);
    return [
      { rol: "Foreman",    tarifa: Number(esc.foreman) || 0,    pct: Number(esc.pct_foreman) || 0 },
      { rol: "Journeyman", tarifa: Number(esc.journeyman) || 0, pct: Number(esc.pct_journeyman) || 0 },
      { rol: "Helper",     tarifa: Number(esc.helper) || 0,     pct: Number(esc.pct_helper) || 0 },
    ];
  }
  // ¿Este estimado tiene algo personalizado por encima de su escenario?
  function esCustom(est) {
    const hay = v => !(v === null || v === undefined || v === "");
    return (Array.isArray(est.mezcla) && est.mezcla.length > 0)
      || hay(est.benefits_pct) || hay(est.profit_pct) || hay(est.markup_pct)
      || hay(est.misc_pct) || hay(est.overhead_hh);
  }

  // Overhead por hora = gastos generales del mes ÷ horas facturables del mes.
  //
  // La versión vieja dividía SIEMPRE entre 3 las horas de los últimos 90 días.
  // Como el módulo de horas empezó a usarse en agosto, junio y julio estaban
  // vacíos: repartía tres meses de gastos entre un mes de horas y sacaba
  // $109.77/hora en vez de los ~$30 de verdad. Pulsar el botón habría casi
  // doblado el precio de cada oferta.
  //
  // Ahora: manda lo que Edgar declare (horas facturables al mes). Si no lo ha
  // puesto, se mira el historial contando SOLO los meses completos que de
  // verdad tienen horas apuntadas, y se dice si el dato es de fiar o no.
  // Devuelve el desglose entero para poder enseñar la división en pantalla.
  function overheadReal() {
    const gastos = (estData.generales || []).reduce((s, g) => s + Number(g.monto_mensual || 0), 0);
    if (!gastos) return null;
    const redondear = v => Math.round(v * 100) / 100;

    // 1) Lo que dice el dueño, si lo dijo
    const puestas = Number((estData.config || {}).horas_mes) || 0;
    if (puestas >= 40) {
      return { valor: redondear(gastos / puestas), gastos, horasMes: puestas,
               fuente: "puestas", meses: 0, fiable: true };
    }

    // 2) Si no, el historial — solo meses COMPLETOS y con horas dentro
    const horas = estData.horasTodas || [];
    if (!horas.length) return null;
    const hoy = new Date();
    const mesActual = fechaISO(hoy.getFullYear(), hoy.getMonth(), 1).slice(0, 7);
    const desde = new Date(); desde.setDate(desde.getDate() - 180);
    const iso = fechaISO(desde.getFullYear(), desde.getMonth(), desde.getDate());
    const porMes = new Map();
    for (const h of horas) {
      if (!h.fecha || h.fecha < iso) continue;
      const m = h.fecha.slice(0, 7);
      if (m >= mesActual) continue;          // el mes en curso va a medias: no cuenta
      porMes.set(m, (porMes.get(m) || 0) + Number(h.horas || 0));
    }
    const meses = [...porMes.values()].filter(v => v > 0);
    if (!meses.length) return null;
    const horasMes = meses.reduce((a, b) => a + b, 0) / meses.length;
    // De fiar solo con tres meses cerrados y un volumen creíble para el taller
    const fiable = meses.length >= 3 && horasMes >= 150;
    return { valor: redondear(gastos / horasMes), gastos, horasMes: Math.round(horasMes),
             fuente: "historial", meses: meses.length, fiable };
  }

  function pintarEstimador() {
    if (!estData) return;
    if (!estimadoActivo) { pintarEstimadorLista(); return; }
    pintarEstimadorEditor();
  }

  function pintarEstimadorLista() {
    const filas = (estData.estimados || []).map(e => {
      const c = calcularEstimado(e);
      const chip = e.estado === "convertido" ? "insp-paso" : e.estado === "congelado" ? "leido" : "por_leer";
      const etiqueta = e.estado === "convertido" ? "CONVERTIDO ✓" : e.estado === "congelado" ? "CONGELADO" : "BORRADOR";
      return `
        <div class="mat-item">
          <span class="recibo-chip ${chip}">${etiqueta}</span>
          <span class="alcance-info est-abrir" data-id="${e.id}" style="cursor:pointer">
            <span class="alcance-titulo">${esc(e.nombre)}</span>
            <span class="alcance-estado">${esc(e.cliente || "")}${e.sqft ? ` · ${esc(e.sqft)} sqft` : ""} · escenario ${esc(e.escenario)}</span>
          </span>
          <span class="mat-precio">${fmt(Math.round(c.bid * 100) / 100)}</span>
          ${e.estado !== "convertido" ? `<button class="insp-borrar btn-est-borrar" data-id="${e.id}" title="Eliminar">🗑</button>` : ""}
        </div>`;
    }).join("");

    $("estimador-panel").innerHTML = `
      <div class="cal-panel-card lev-atajo">
        <button type="button" class="accion" id="est-a-levantamiento">Levantamiento en sitio</button>
        <p class="lev-nota">Estás en la casa: cuenta lo que ves y la app arma el estimado sola.</p>
      </div>
      <div class="cal-panel-card">
        <form id="form-nuevo-est" class="cal-form">
          <div class="cal-form-titulo">➕ Nuevo estimado</div>
          <label>¿Cómo vas a estimar este trabajo?
            <select name="modo">
              <option value="rapido">⚡ Rápido — horas y material, como el Excel</option>
              <option value="planos">📐 Por planos (takeoff de Bluebeam)</option>
              <option value="remodelacion">🏠 Remodelación (levantamiento, por ensambles)</option>
              <option value="servicio">🔧 Servicio (rápido, plantillas)</option>
            </select>
          </label>
          <label>Nombre del trabajo
            <input name="nombre" type="text" required placeholder="Ej: Casa García — Rewire" autocomplete="off">
          </label>
          <div class="modal-fila">
            <label>Cliente
              <input name="cliente" type="text" placeholder="Ej: Juan García" autocomplete="off">
            </label>
            <label>Tipo
              <select name="tipo">
                <option value="Residential">Residencial</option>
                <option value="Commercial">Comercial</option>
              </select>
            </label>
          </div>
          <div class="modal-fila">
            <label>Sq Ft (opcional)
              <input name="sqft" type="number" min="0" placeholder="Ej: 2200">
            </label>
            <label>Escenario
              <select name="escenario">
                ${(estData.escenarios || []).map(x =>
                  `<option value="${esc(x.id)}"${x.id === "B" ? " selected" : ""}>${esc(x.id)} — ${esc(x.nombre || "")}</option>`).join("")}
              </select>
            </label>
          </div>
          <button type="submit" class="accion">Crear estimado</button>
        </form>
      </div>
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Mis estimados (${(estData.estimados || []).length})</div>
        ${filas || `<p class="cal-sin-eventos">Todavía no hay estimados. Crea el primero arriba.</p>`}
      </div>
      ${usuario.finanzas ? escenariosHTML() : ""}`;
    if (usuario.finanzas) engancharEscenarios();

    $("form-nuevo-est").addEventListener("submit", async ev => {
      ev.preventDefault();
      const d = new FormData(ev.target);
      try {
        const modoNuevo = d.get("modo") || "planos";
        const filasNueva = await DB.crearEstimado({
          nombre: (d.get("nombre") || "").toString().trim(),
          cliente: (d.get("cliente") || "").toString().trim() || null,
          tipo: d.get("tipo") || "Residential",
          sqft: d.get("sqft") ? Number(d.get("sqft")) : null,
          // Servicio arranca en C (margen sano); Rápido arranca en A, que es
          // con el que Edgar cerró Cocina Rachel
          escenario: modoNuevo === "servicio" ? "C" : modoNuevo === "rapido" ? "A" : (d.get("escenario") || "B"),
          factor: 1,
          estado: "borrador",
          modo: modoNuevo,
          cable: "romex"
        });
        estimadoActivo = filasNueva[0].id;
        await recargarEstimador();
        avisar(modoNuevo === "rapido" ? "Estimado creado ✓ — pon las horas y el material" : "Estimado creado ✓ — busca ítems del catálogo y ponles cantidad");
      } catch (err) { avisar("No se pudo crear: " + err.message, true); }
    });
    $("est-a-levantamiento").addEventListener("click", () => irLevLista());
    $("estimador-panel").querySelectorAll(".est-abrir").forEach(el => {
      el.addEventListener("click", () => { estimadoActivo = Number(el.dataset.id); pintarEstimador(); });
    });
    $("estimador-panel").querySelectorAll(".btn-est-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este estimado con todos sus ítems?")) return;
        try {
          await DB.eliminarEstimado(btn.dataset.id);
          await recargarEstimador();
          avisar("Estimado eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });
  }

  let takeoffPreview = null;  // filas analizadas del takeoff pendientes de aplicar

  // Analiza el CSV exportado de Bluebeam (Markups List → Export)
  function analizarTakeoff(texto) {
    const lineas = texto.split(/\r?\n/).filter(l => l.trim());
    if (!lineas.length) return [];
    const sep = (lineas[0].match(/\t/g) || []).length >= 2 ? "\t" : ",";
    const parsear = l => {
      const celdas = []; let cur = "", dentro = false;
      for (const ch of l) {
        if (ch === '"') dentro = !dentro;
        else if (ch === sep && !dentro) { celdas.push(cur); cur = ""; }
        else cur += ch;
      }
      celdas.push(cur);
      return celdas.map(c => c.trim());
    };
    const filas = lineas.map(parsear);
    let encabezado = filas.findIndex(f => f.some(c => /^subject$/i.test(c)));
    if (encabezado < 0) encabezado = 0;
    const cols = filas[encabezado].map(c => c.toLowerCase());
    const idx = nombre => cols.findIndex(c => c === nombre);
    const iSubj = idx("subject"), iCode = idx("item code"),
      iComments = idx("comments"), iCount = cols.findIndex(c => /^(count|#? ?of units)$/.test(c)),
      iLen = cols.findIndex(c => /^(length|measurement)$/.test(c)),
      iWire = cols.findIndex(c => c.includes("total wire")),
      iSize = idx("size"), iCableCu = idx("cable cu"), iCableAl = idx("cable al");
    const num = v => {
      const n = Number(String(v || "").replace(/[^\d.\-]/g, ""));
      return Number.isFinite(n) ? n : 0;
    };
    const agrupadas = {};
    for (let r = encabezado + 1; r < filas.length; r++) {
      const f = filas[r];
      const subject = (iSubj >= 0 ? f[iSubj] : f[0] || "").trim();
      if (!subject) continue;
      let qty = 0;
      if (iComments >= 0 && num(f[iComments]) > 0) qty = num(f[iComments]);
      else if (iCount >= 0 && num(f[iCount]) > 0) qty = num(f[iCount]);
      else if (iLen >= 0 && num(f[iLen]) > 0) qty = num(f[iLen]);
      else qty = 1;
      const clave = subject + "|" + (iSize >= 0 ? f[iSize] || "" : "");
      (agrupadas[clave] = agrupadas[clave] || {
        subject, size: iSize >= 0 ? (f[iSize] || "").trim() : "",
        code: iCode >= 0 ? (f[iCode] || "").trim() : "", qty: 0, wireLF: 0,
        cable: ((iCableCu >= 0 && f[iCableCu]) || (iCableAl >= 0 && f[iCableAl]) || "").trim()
      }).qty += qty;
      if (iWire >= 0) agrupadas[clave].wireLF += num(f[iWire]);
    }
    return Object.values(agrupadas);
  }

  // Empareja una fila del takeoff con el catálogo (código → alias → nombre)
  function emparejarTakeoff(fila) {
    const cat = estData.catalogo || [];
    if (fila.code) {
      const porCodigo = cat.find(c => String(c.orden) === String(fila.code).replace(/\D/g, ""));
      if (porCodigo) return { item: porCodigo, factor: 1, via: "código" };
    }
    const nombreCompleto = fila.size ? `${fila.size} ${fila.subject}` : fila.subject;
    const al = (estData.alias || []).find(a =>
      normTxt(a.alias) === normTxt(nombreCompleto) || normTxt(a.alias) === normTxt(fila.subject));
    if (al) {
      const item = catalogoExacto(al.item) || buscaCatalogo(al.item);
      if (item) return { item, factor: Number(al.factor) || 1, via: "alias" };
    }
    const exacto = catalogoExacto(nombreCompleto) || catalogoExacto(fila.subject);
    if (exacto) return { item: exacto, factor: 1, via: "nombre" };
    return null;
  }

  function sugerenciasCatalogo(texto, n) {
    const palabras = normTxt(texto).split(" ").filter(w => w.length > 1);
    return (estData.catalogo || [])
      .map(c => ({ c, p: palabras.filter(w => normTxt(c.item).includes(w)).length }))
      .filter(x => x.p > 0)
      .sort((a, b) => b.p - a.p)
      .slice(0, n || 5)
      .map(x => x.c);
  }

  // El texto de la propuesta (SOW) que sale del estimado
  function textoPropuesta(est, c) {
    const r2 = v => Math.round(v * 100) / 100;
    const bid = r2(c.bid);
    const hoyTxt = new Date().toLocaleDateString(LOCALE, { day: "numeric", month: "long", year: "numeric" });
    const lineas = [];
    const ensDelEst = (estData.estEnsambles || []).filter(e => e.estimado_id === est.id && Number(e.cantidad) > 0);
    if (ensDelEst.length) {
      for (const ee of ensDelEst) {
        const ens = (estData.ensambles || []).find(x => x.id === ee.ensamble_id);
        if (ens) lineas.push(`• ${ens.nombre} — cantidad: ${ee.cantidad}`);
      }
    } else {
      const porSeccion = {};
      for (const it of c.items) {
        const cat = catalogoExacto(it.item);
        const s = (cat && cat.seccion) || "GENERAL";
        (porSeccion[s] = porSeccion[s] || []).push(it);
      }
      for (const [s, its] of Object.entries(porSeccion)) {
        lineas.push(`• ${s}: ${its.slice(0, 4).map(i => `${i.cantidad} ${i.item}`).join(", ")}${its.length > 4 ? "…" : ""}`);
      }
    }
    const m1 = r2(bid * 0.35), m2 = r2(bid * 0.4), m3 = r2(bid - m1 - m2);
    return `MAX POWER ELECTRICAL SOLUTIONS, INC.
FL EC License #EC13016045 · mxpes.com
PROPUESTA — ${est.nombre}
Cliente: ${est.cliente || ""} · Fecha: ${hoyTxt}

ALCANCE DEL TRABAJO:
${lineas.join("\n")}

Incluye mano de obra, materiales, misceláneas y supervisión según el alcance.
No incluye trabajos no listados; cambios se manejan por Change Order.

PRECIO TOTAL (LUMP SUM): ${fmt(bid)}${est.sqft ? `  (${fmt(r2(bid / est.sqft))}/sqft)` : ""}

FORMA DE PAGO:
• Milestone 1 — 35% a la aceptación (movilización): ${fmt(m1)}
• Milestone 2 — 40% al completar el avance principal: ${fmt(m2)}
• Milestone 3 — 25% al pasar inspección final: ${fmt(m3)}

Propuesta válida por 15 días. Gracias por la oportunidad.
Power done right the first time. ⚡`;
  }

  // ============================================================
  // ⚡ ESTIMADO RÁPIDO — horas + material, como la hoja de Excel de Edgar
  // Tres casillas y un resultado. Escenario A/B/C o uno propio (Custom):
  // cuadrilla, beneficios, profit y markup se pueden tocar aquí mismo.
  // ============================================================
  function panelRapidoHTML(est, c, soloLectura) {
    const r2 = v => Math.round(v * 100) / 100;
    const pct = v => Math.round((Number(v) || 0) * 1000) / 10;   // 0.2 → 20
    const lineas = Array.isArray(est.lineas_material) ? est.lineas_material : [];
    const custom = esCustom(est);
    const escs = estData.escenarios || [];

    // Los cuatro precios lado a lado: A, B, C puros y el Custom de este estimado
    const puro = id => calcularEstimado({ ...est, escenario: id, mezcla: null, benefits_pct: null,
      profit_pct: null, markup_pct: null, misc_pct: null, overhead_hh: null });
    const comparacion = escs.map(e => ({ id: e.id, nombre: e.nombre, c: puro(e.id), activo: !custom && est.escenario === e.id }));
    if (custom) comparacion.push({ id: "custom", nombre: "Custom", c, activo: true });

    const filasMat = lineas.map((l, i) => `
      <div class="rap-linea">
        <span class="rap-desc">${esc(l.desc || "Material")}</span>
        <span class="rap-monto">${fmt(r2(Number(l.monto) || 0))}</span>
        ${!soloLectura ? `<button type="button" class="insp-borrar rap-mat-editar" data-i="${i}" title="Editar">✎</button>
        <button type="button" class="insp-borrar rap-mat-borrar" data-i="${i}" title="Quitar">🗑</button>` : ""}
      </div>`).join("");

    const filasCuadrilla = c.mezcla.map((m, i) => `
      <div class="rap-rol">
        <input class="rap-rol-nombre" data-i="${i}" type="text" value="${esc(m.rol)}" placeholder="Rol" ${soloLectura ? "disabled" : ""}>
        <span class="rap-signo">$</span>
        <input class="rap-rol-tarifa" data-i="${i}" type="number" min="0" step="0.5" inputmode="decimal" value="${esc(m.tarifa)}" ${soloLectura ? "disabled" : ""}>
        <span class="rap-signo">/h ·</span>
        <input class="rap-rol-pct" data-i="${i}" type="number" min="0" max="100" step="1" inputmode="numeric" value="${esc(pct(m.pct))}" ${soloLectura ? "disabled" : ""}>
        <span class="rap-signo">%</span>
        ${!soloLectura && c.mezcla.length > 1 ? `<button type="button" class="insp-borrar rap-rol-quitar" data-i="${i}" title="Quitar rol">🗑</button>` : ""}
      </div>`).join("");
    const sumaPct = Math.round(c.mezcla.reduce((t, m) => t + (Number(m.pct) || 0), 0) * 1000) / 10;

    return `
      <div class="cal-panel-card rap-card">
        <div class="cal-form-titulo">⚡ Horas y material</div>
        <div class="modal-fila">
          <label class="mat-filtro-label">Horas de todo el trabajo
            <input id="rap-horas" type="number" min="0" step="0.5" inputmode="decimal" value="${esc(est.horas_directas ?? "")}" placeholder="Ej: 90" ${soloLectura ? "disabled" : ""}>
          </label>
          <label class="mat-filtro-label">Factor de productividad
            <input id="rap-factor" type="number" min="0.5" max="2" step="0.05" value="${esc(est.factor || 1)}" ${soloLectura ? "disabled" : ""}>
          </label>
        </div>
        <div class="rap-sub">Material — ${fmt(r2(c.lineasMat.reduce((t, l) => t + (Number(l.monto) || 0), 0)))}
          ${!soloLectura ? `<button type="button" class="accion secundaria rap-mat-agregar">+ Agregar línea</button>` : ""}</div>
        ${filasMat || `<p class="cal-sin-eventos">Pon el material: un total, o varias líneas (breakers, cable, luminarias…).</p>`}
        <p class="rent-nota">Al material se le suma el ${pctTxtR(c.miscPct)} de misceláneas y el ${pctTxtR(c.taxPct)} de tax. El markup es opcional, abajo.</p>
      </div>

      <div class="cal-panel-card rap-card">
        <div class="cal-form-titulo">Escenario
          ${custom ? `<span class="recibo-chip por_leer">CUSTOM ✏</span>` : `<span class="recibo-chip leido">${esc(est.escenario)} — ${esc((escs.find(e => e.id === est.escenario) || {}).nombre || "")}</span>`}
        </div>
        <div class="rap-tabs">
          ${escs.map(e => `<button type="button" class="rap-tab${!custom && est.escenario === e.id ? " on" : ""}" data-esc="${esc(e.id)}" ${soloLectura ? "disabled" : ""}>${esc(e.id)} · ${esc(e.nombre || "")}</button>`).join("")}
          ${custom ? `<button type="button" class="rap-tab on" disabled>Custom</button>` : ""}
        </div>
        <p class="rent-nota">Toca A, B o C para usar ese escenario tal cual. Si cambias cualquier número de abajo, este estimado pasa a <strong>Custom</strong> (los escenarios no se tocan; para eso está ⚙ Escenarios en la lista).</p>

        <div class="rap-sub">Cuadrilla — quién trabaja y qué parte de las horas</div>
        ${filasCuadrilla}
        <div class="rap-suma ${Math.abs(sumaPct - 100) < 0.6 ? "ok" : "mal"}">Suma: ${sumaPct}% ${Math.abs(sumaPct - 100) < 0.6 ? "✓" : "— tiene que dar 100%"}
          ${!soloLectura ? `<button type="button" class="accion secundaria rap-rol-agregar">+ Agregar rol</button>` : ""}</div>
        <div class="rent-fila"><span>Tarifa mezclada</span><span>${fmt(r2(c.tarifaMezclada))} / h</span></div>

        <div class="modal-fila" style="margin-top:.5rem">
          <label class="mat-filtro-label">Beneficios sobre el labor (%)
            <input id="rap-benefits" type="number" min="0" max="100" step="0.5" inputmode="decimal" value="${esc(pct(c.benefitsPct))}" ${soloLectura ? "disabled" : ""}>
          </label>
          <label class="mat-filtro-label">Profit (%)
            <input id="rap-profit" type="number" min="0" max="100" step="0.5" inputmode="decimal" value="${esc(pct(c.profitPct))}" ${soloLectura ? "disabled" : ""}>
          </label>
        </div>
        <div class="modal-fila">
          <label class="mat-filtro-label">Markup de materiales (%) — opcional
            <input id="rap-markup" type="number" min="0" max="100" step="0.5" inputmode="decimal" value="${esc(pct(c.markupPct))}" ${soloLectura ? "disabled" : ""}>
          </label>
          <label class="mat-filtro-label">Overhead ($ por hora) — fijo por ahora
            <input type="number" value="${esc(r2(c.ohHH))}" disabled>
          </label>
        </div>
      </div>

      <div class="cal-panel-card rap-card">
        <div class="cal-form-titulo">Los escenarios lado a lado</div>
        <div class="rap-comp">
          ${comparacion.map(x => `
          <div class="rap-comp-col${x.activo ? " on" : ""}">
            <div class="rap-comp-nombre">${esc(x.id === "custom" ? "Custom" : x.id)}<br><small>${esc(x.nombre || "")}</small></div>
            <div class="rap-comp-bid">${fmt(r2(x.c.bid))}</div>
            <div class="rap-comp-det">
              <div><span>Labor</span><span>${fmt(r2(x.c.totalLabor))}</span></div>
              <div><span>Material</span><span>${fmt(r2(x.c.totalMaterial))}</span></div>
              <div><span>Overhead</span><span>${fmt(r2(x.c.overhead))}</span></div>
              <div><span>Profit</span><span>${fmt(r2(x.c.profit))}</span></div>
              <div><span>$/h cargado</span><span>${x.c.horas > 0 ? fmt(r2(x.c.bid / x.c.horas)) : "—"}</span></div>
            </div>
          </div>`).join("")}
        </div>
        <p class="rent-nota">El $/h cargado es el precio final dividido entre las horas: lo que cobras por cada hora con todo adentro.</p>
      </div>`;
  }
  const pctTxtR = v => (Math.round((Number(v) || 0) * 1000) / 10) + "%";

  function engancharRapido(est, soloLectura) {
    if (soloLectura) return;
    const guardar = async (cambios, aviso) => {
      try {
        await DB.cambiarEstimado(est.id, cambios);
        await recargarEstimador();
        if (aviso) avisar(aviso);
      } catch (err) { avisar("No se pudo guardar: " + err.message, true); }
    };
    const num = el => { const v = Number(String(el.value).replace(/[,$%\s]/g, "")); return Number.isFinite(v) ? v : null; };

    const h = $("rap-horas");
    if (h) h.addEventListener("change", () => { const v = num(h); if (v !== null && v >= 0) guardar({ horas_directas: v }); });
    const f = $("rap-factor");
    if (f) f.addEventListener("change", () => { const v = num(f); if (v && v > 0) guardar({ factor: v }); });

    // Material: líneas sueltas
    const lineas = () => (Array.isArray(est.lineas_material) ? est.lineas_material : []).map(l => ({ ...l }));
    document.querySelectorAll(".rap-mat-agregar").forEach(b => b.addEventListener("click", () => {
      const desc = prompt("¿Qué material? (o escribe 'Material' para un total)", lineas().length ? "" : "Material");
      if (desc === null) return;
      const m = prompt(`¿Cuánto cuesta "${desc || "Material"}"? (sin tax)`);
      if (m === null) return;
      const monto = Number(String(m).replace(/[,$\s]/g, ""));
      if (!Number.isFinite(monto) || monto < 0) { avisar("Monto no válido", true); return; }
      guardar({ lineas_material: [...lineas(), { desc: (desc || "Material").trim().slice(0, 80), monto }] }, "Material agregado ✓");
    }));
    document.querySelectorAll(".rap-mat-editar").forEach(b => b.addEventListener("click", () => {
      const arr = lineas(); const i = Number(b.dataset.i); const l = arr[i]; if (!l) return;
      const desc = prompt("Descripción:", l.desc || "Material"); if (desc === null) return;
      const m = prompt("Monto (sin tax):", l.monto); if (m === null) return;
      const monto = Number(String(m).replace(/[,$\s]/g, ""));
      if (!Number.isFinite(monto) || monto < 0) { avisar("Monto no válido", true); return; }
      arr[i] = { desc: (desc || "Material").trim().slice(0, 80), monto };
      guardar({ lineas_material: arr }, "Material corregido ✓");
    }));
    document.querySelectorAll(".rap-mat-borrar").forEach(b => b.addEventListener("click", () => {
      const arr = lineas(); arr.splice(Number(b.dataset.i), 1);
      guardar({ lineas_material: arr }, "Línea quitada ✓");
    }));

    // Escenario puro: se borran las personalizaciones y se usa A/B/C tal cual
    document.querySelectorAll(".rap-tab[data-esc]").forEach(b => b.addEventListener("click", () => {
      guardar({ escenario: b.dataset.esc, mezcla: null, benefits_pct: null, profit_pct: null,
                markup_pct: null, misc_pct: null, overhead_hh: null }, `Escenario ${b.dataset.esc} ✓`);
    }));

    // Cuadrilla editable: cualquier cambio la guarda como propia (Custom)
    const escAct = (estData.escenarios || []).find(e => e.id === est.escenario) || {};
    const leerCuadrilla = () => {
      const nombres = [...document.querySelectorAll(".rap-rol-nombre")];
      return nombres.map((n, i) => ({
        rol: (n.value || "").trim().slice(0, 30) || `Rol ${i + 1}`,
        tarifa: Number(document.querySelector(`.rap-rol-tarifa[data-i="${i}"]`).value) || 0,
        pct: (Number(document.querySelector(`.rap-rol-pct[data-i="${i}"]`).value) || 0) / 100,
      }));
    };
    document.querySelectorAll(".rap-rol-nombre, .rap-rol-tarifa, .rap-rol-pct").forEach(el =>
      el.addEventListener("change", () => guardar({ mezcla: leerCuadrilla() })));
    document.querySelectorAll(".rap-rol-agregar").forEach(b => b.addEventListener("click", () => {
      const rol = prompt("Nombre del rol nuevo (Ej: Apprentice):", "Apprentice"); if (rol === null) return;
      const t = prompt(`Tarifa por hora de ${rol} ($):`, "20"); if (t === null) return;
      const arr = cuadrillaDe(est, escAct);
      arr.push({ rol: rol.trim().slice(0, 30) || "Rol", tarifa: Number(t) || 0, pct: 0 });
      guardar({ mezcla: arr }, "Rol agregado — ahora reparte los % para que sumen 100");
    }));
    document.querySelectorAll(".rap-rol-quitar").forEach(b => b.addEventListener("click", () => {
      const arr = cuadrillaDe(est, escAct); arr.splice(Number(b.dataset.i), 1);
      guardar({ mezcla: arr }, "Rol quitado — revisa que los % sumen 100");
    }));

    const pctCampo = (id, campo) => {
      const el = $(id); if (!el) return;
      el.addEventListener("change", () => { const v = num(el); if (v !== null && v >= 0) guardar({ [campo]: v / 100 }); });
    };
    pctCampo("rap-benefits", "benefits_pct");
    pctCampo("rap-profit", "profit_pct");
    pctCampo("rap-markup", "markup_pct");
  }

  // ⚙ Escenarios A/B/C: tarifas, cuadrilla, beneficios y profit se editan
  // aquí y valen para TODOS los estimados nuevos (cuando entra un cuarto
  // trabajador, por ejemplo). El overhead se toca desde el aviso de overhead
  // real, no aquí.
  function escenariosHTML() {
    const escs = estData.escenarios || [];
    const pct = v => Math.round((Number(v) || 0) * 1000) / 10;
    return `
      <details class="cal-panel-card">
        <summary class="cal-form-titulo" style="cursor:pointer">⚙ Escenarios A / B / C — tarifas y cuadrilla</summary>
        <p class="rent-nota">Estos números son los de la casa: cada estimado nuevo arranca con ellos. Cámbialos cuando cambie tu gente o tus costos.</p>
        ${escs.map(e => {
          const cu = cuadrillaDe({}, e);
          return `
          <div class="esc-card" data-esc="${esc(e.id)}">
            <div class="esc-titulo">${esc(e.id)} — <input class="esc-nombre" type="text" value="${esc(e.nombre || "")}" placeholder="Nombre"></div>
            ${cu.map((m, i) => `
            <div class="rap-rol">
              <input class="esc-rol-nombre" data-i="${i}" type="text" value="${esc(m.rol)}">
              <span class="rap-signo">$</span><input class="esc-rol-tarifa" data-i="${i}" type="number" min="0" step="0.5" inputmode="decimal" value="${esc(m.tarifa)}">
              <span class="rap-signo">/h ·</span><input class="esc-rol-pct" data-i="${i}" type="number" min="0" max="100" step="1" inputmode="numeric" value="${esc(pct(m.pct))}"><span class="rap-signo">%</span>
              ${cu.length > 1 ? `<button type="button" class="insp-borrar esc-rol-quitar" data-i="${i}" title="Quitar rol">🗑</button>` : ""}
            </div>`).join("")}
            <div class="modal-fila">
              <label class="mat-filtro-label">Beneficios (%)<input class="esc-benefits" type="number" min="0" max="100" step="0.5" value="${esc(pct(e.benefits))}"></label>
              <label class="mat-filtro-label">Profit (%)<input class="esc-profit" type="number" min="0" max="100" step="0.5" value="${esc(pct(e.profit))}"></label>
            </div>
            <div class="modal-botones">
              <button type="button" class="accion secundaria esc-rol-agregar">+ Agregar rol</button>
              <button type="button" class="accion esc-guardar">💾 Guardar ${esc(e.id)}</button>
            </div>
          </div>`;
        }).join("")}
      </details>`;
  }

  function engancharEscenarios() {
    document.querySelectorAll(".esc-card").forEach(card => {
      const id = card.dataset.esc;
      const leer = () => {
        const nombres = [...card.querySelectorAll(".esc-rol-nombre")];
        const mezcla = nombres.map((n, i) => ({
          rol: (n.value || "").trim().slice(0, 30) || `Rol ${i + 1}`,
          tarifa: Number(card.querySelector(`.esc-rol-tarifa[data-i="${i}"]`).value) || 0,
          pct: (Number(card.querySelector(`.esc-rol-pct[data-i="${i}"]`).value) || 0) / 100,
        }));
        return {
          nombre: (card.querySelector(".esc-nombre").value || "").trim().slice(0, 40),
          mezcla,
          // Las tres columnas de siempre se mantienen con los tres primeros
          // roles, para que lo viejo (y la rutina) siga entendiendo el escenario
          foreman: mezcla[0] ? mezcla[0].tarifa : 0, pct_foreman: mezcla[0] ? mezcla[0].pct : 0,
          journeyman: mezcla[1] ? mezcla[1].tarifa : 0, pct_journeyman: mezcla[1] ? mezcla[1].pct : 0,
          helper: mezcla[2] ? mezcla[2].tarifa : 0, pct_helper: mezcla[2] ? mezcla[2].pct : 0,
          benefits: (Number(card.querySelector(".esc-benefits").value) || 0) / 100,
          profit: (Number(card.querySelector(".esc-profit").value) || 0) / 100,
        };
      };
      card.querySelector(".esc-guardar").addEventListener("click", async () => {
        const datos = leer();
        const suma = Math.round(datos.mezcla.reduce((t, m) => t + m.pct, 0) * 1000) / 10;
        if (Math.abs(suma - 100) >= 0.6) { avisar(`Los % de la cuadrilla suman ${suma}% — tienen que dar 100%`, true); return; }
        try {
          try {
            await DB.cambiarEscenario(id, datos);
          } catch (err) {
            // Si todavía no se pegó el SQL del modo rápido, la columna "mezcla"
            // no existe: se guardan las tres tarifas de siempre y se avisa.
            if (!/mezcla/i.test(String((err && err.crudo) || (err && err.message) || ""))) throw err;
            const { mezcla, ...sinMezcla } = datos;
            await DB.cambiarEscenario(id, sinMezcla);
            if (mezcla.length > 3) avisar("Se guardaron los 3 primeros roles. Para más de 3, pega el SQL del modo rápido.", true);
          }
          await recargarEstimador();
          avisar(`Escenario ${id} guardado ✓ — vale para los estimados nuevos`);
        } catch (err) { avisar("No se pudo guardar: " + err.message, true); }
      });
      card.querySelector(".esc-rol-agregar").addEventListener("click", () => {
        const fila = document.createElement("div");
        fila.className = "rap-rol";
        const i = card.querySelectorAll(".esc-rol-nombre").length;
        fila.innerHTML = `<input class="esc-rol-nombre" data-i="${i}" type="text" value="" placeholder="Rol nuevo">
          <span class="rap-signo">$</span><input class="esc-rol-tarifa" data-i="${i}" type="number" min="0" step="0.5" value="20">
          <span class="rap-signo">/h ·</span><input class="esc-rol-pct" data-i="${i}" type="number" min="0" max="100" step="1" value="0"><span class="rap-signo">%</span>`;
        card.querySelector(".modal-fila").before(fila);
      });
      card.querySelectorAll(".esc-rol-quitar").forEach(b => b.addEventListener("click", () => {
        b.closest(".rap-rol").remove();
        // reindexar
        card.querySelectorAll(".rap-rol").forEach((fila, i) => fila.querySelectorAll("input").forEach(inp => inp.dataset.i = i));
      }));
    });
  }

  // Las propuestas ya guardadas de un estimado, con su atajo a Preparar cierre
  function propuestasDelEstimado(estimadoId) {
    const lista = ((propData && propData.propuestas) || []).filter(p => p.estimado_id === estimadoId);
    if (!lista.length) return "";
    return `<div class="cierre-props">` + lista.map(p => {
      const ops = ((propData && propData.opciones) || []).filter(o => o.propuesta_id === p.id);
      const vence = p.valida_hasta || "";
      const vencida = vence && vence < new Date().toISOString().slice(0, 10);
      return `
        <div class="mat-item">
          <span class="recibo-chip ${p.estado === "firmada" ? "insp-paso" : vencida ? "por_leer" : "leido"}">${p.estado === "firmada" ? "FIRMADA ✓" : vencida ? "VENCIDA" : "PROPUESTA"}</span>
          <span class="alcance-info">
            <span class="alcance-titulo">${ops.length} ${ops.length === 1 ? "opción" : "opciones"}${ops.length ? " · " + ops.map(o => o.letra).join("/") : ""}</span>
            <span class="alcance-estado">${vence ? "vale hasta " + esc(vence) : "sin fecha de validez"}</span>
          </span>
          <button class="accion secundaria btn-cierre" data-id="${p.id}">Preparar cierre</button>
        </div>`;
    }).join("") + `</div>`;
  }

  function pintarEstimadorEditor() {
    const est = (estData.estimados || []).find(x => x.id === estimadoActivo);
    if (!est) { estimadoActivo = null; pintarEstimadorLista(); return; }
    if (!est.estado) est.estado = "borrador";
    if (!est.modo) est.modo = "planos";
    const c = calcularEstimado(est);
    const soloLectura = est.estado !== "borrador";
    const r2 = v => Math.round(v * 100) / 100;
    const MODO_ETIQ = { planos: "📐 Por planos", remodelacion: "🏠 Remodelación", servicio: "🔧 Servicio", rapido: "⚡ Rápido" };
    const esRapido = est.modo === "rapido";

    const filasItems = c.items.map(i => `
      <div class="mat-item">
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(i.item)}${i.deEnsamble ? ` <span class="mat-cant">— de: ${esc(i.deEnsamble)}</span>` : ""}</span>
          <span class="alcance-estado">${esc(r2(Number(i.cantidad)))} ${esc(i.unidad || "")} × ${fmt(i.precio)} · ${r2(Number(i.cantidad) * Number(i.horas))} h</span>
        </span>
        <span class="mat-precio">${fmt(r2(Number(i.cantidad) * Number(i.precio)))}</span>
        ${!soloLectura && i.id ? `<button class="insp-borrar btn-item-qty" data-id="${i.id}" data-qty="${esc(i.cantidad)}" title="Cambiar cantidad">✎</button>
        <button class="insp-borrar btn-item-borrar" data-id="${i.id}" title="Quitar">🗑</button>` : ""}
      </div>`).join("");

    const filasAutos = c.autos.map(a => `
      <div class="mat-item auto-item">
        <span class="recibo-chip leido">AUTO</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(a.item)}</span>
          <span class="alcance-estado">${esc(r2(a.cantidad))} ${esc(a.unidad || "")} · ${esc(a.auto)}</span>
        </span>
        <span class="mat-precio">${fmt(r2(a.cantidad * a.precio))}</span>
      </div>`).join("");

    // Ensambles del estimado (modos remodelación / servicio)
    const modoEns = est.modo === "servicio" ? "servicio" : "remodelacion";
    const ensDisponibles = (estData.ensambles || []).filter(e => e.modo === modoEns);
    const ensDelEst = (estData.estEnsambles || []).filter(e => e.estimado_id === est.id);
    const filasEnsambles = ensDisponibles.map(ens => {
      const enEst = ensDelEst.find(e => e.ensamble_id === ens.id);
      const qty = enEst ? Number(enEst.cantidad) : 0;
      const prom = ens.pies_editable ? piesPromedioEnsamble(ens.id) : null;
      // Precio de venta por unidad de este ensamble (misma fórmula completa)
      const compsUnit = itemsDeEnsamble(ens.id, 1, enEst ? enEst.pies : null);
      const precioUnit = compsUnit.length ? calcularEstimado(est, compsUnit).bid : 0;
      const lineaPrecio = precioUnit
        ? `<span class="alcance-estado">≈ <strong>${fmt(Math.round(precioUnit * 100) / 100)}</strong> por unidad (escenario ${esc(est.escenario)})</span>` : "";
      const piesLinea = ens.pies_editable && qty > 0
        ? `<span class="alcance-estado">📏 ${enEst && Number(enEst.pies) > 0
            ? `<strong>${Number(enEst.pies)} ft medidos</strong>`
            : `${prom || "?"} ft (promedio)`} por circuito${!soloLectura
            ? ` <button class="accion secundaria btn-ens-pies" data-eid="${enEst.id}" data-prom="${prom || ""}" style="padding:.05rem .45rem">✎ pies</button>` : ""}</span>`
        : "";
      return `
        <div class="mat-item${qty > 0 ? "" : " ens-cero"}">
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(ens.nombre)}</span>
            ${ens.descripcion ? `<span class="alcance-estado">${esc(ens.descripcion)}</span>` : ""}
            ${lineaPrecio}
            ${piesLinea}
          </span>
          ${!soloLectura ? `
          <div class="ens-contador">
            <button class="accion secundaria btn-ens-menos" data-ens="${ens.id}" ${qty <= 0 ? "disabled" : ""}>−</button>
            <input class="ens-qty-input" type="number" min="0" step="1" inputmode="numeric"
              value="${qty}" data-ens="${ens.id}" title="Escribe la cantidad directa">
            <button class="accion btn-ens-mas" data-ens="${ens.id}">+</button>
          </div>` : `<span class="ens-qty">${qty}</span>`}
        </div>`;
    }).join("");

    // ⭐ Lo que más usas: historial real de todos tus estimados.
    // Cada vez que agregas un ítem (buscado, takeoff o creado), cuenta aquí.
    const usoPorItem = {};
    (estData.items || []).forEach(it => {
      const k = (it.item || "").trim();
      if (!k) return;
      if (!usoPorItem[k]) usoPorItem[k] = { item: it.item, unidad: it.unidad, precio: it.precio, horas: it.horas, veces: 0 };
      usoPorItem[k].veces++;
    });
    const frecuentes = Object.values(usoPorItem)
      .sort((a, b) => b.veces - a.veces || a.item.localeCompare(b.item));
    const filaFrecuente = f => {
      const cat = (estData.catalogo || []).find(x => x.item === f.item);
      return `
        <div class="mat-item est-frec" data-item="${esc(f.item)}" style="cursor:pointer">
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(f.item)}</span>
            <span class="alcance-estado">usado ${f.veces} ${f.veces === 1 ? "vez" : "veces"} · ${esc((cat || f).unidad || "")} · ${fmt(Number((cat || f).precio) || 0)}</span>
          </span>
          <span class="cat-flecha">＋</span>
        </div>`;
    };
    const topFrec = frecuentes.slice(0, frecuentesExpandido ? 40 : 6);
    const cardFrecuentes = !soloLectura && frecuentes.length ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">⭐ Lo que más usas <span class="chk-avance">se llena solo con tu historial</span></div>
        ${topFrec.map(filaFrecuente).join("")}
        ${frecuentes.length > 6 ? `
          <button type="button" class="accion secundaria" id="btn-frec-mas" style="margin-top:.45rem">
            ${frecuentesExpandido ? "Ver menos" : `Ver más (${frecuentes.length - 6} más)`}
          </button>` : ""}
      </div>` : "";

    // Ayudantes del resumen editable
    const pctTxt = v => (Math.round(v * 1000) / 10) + "%";
    const nnDist = v => !(v === null || v === undefined || v === "");
    const lapiz = (campo, tipo, actual, nombre) => soloLectura ? "" :
      `<button type="button" class="btn-formula insp-borrar" title="Editar" data-campo="${campo}" data-tipo="${tipo}" data-actual="${actual}" data-nombre="${esc(nombre)}">✎</button>`;

    // Aviso del overhead: SIEMPRE enseña la división entera (cuánto se gasta al
    // mes ÷ cuántas horas al mes), nunca solo el resultado. Y el botón de
    // actualizar los escenarios solo aparece cuando el dato es de fiar.
    const oReal = overheadReal();
    const ohEsc = Number(c.esc.overhead_hh);
    const difiere = oReal && ohEsc && Math.abs(oReal.valor - ohEsc) / ohEsc > 0.05;
    const horasAhora = ohEsc ? Math.round(oReal ? oReal.gastos / ohEsc : 0) : 0;
    const bannerOverhead = !(usuario.finanzas && oReal && difiere) ? "" :
      `<div class="inicio-card avisos">
         <div class="aviso-texto" style="padding:.2rem 0">
           <strong>⚙ El overhead por hora</strong><br>
           Tus gastos generales son <strong>${fmt(oReal.gastos)} al mes</strong>.
           ${oReal.fuente === "puestas"
             ? `Repartidos entre las <strong>${oReal.horasMes} horas al mes</strong> que pusiste,
                salen <strong>${fmt(oReal.valor)} por hora</strong>.`
             : `Con las horas apuntadas en la app (<strong>${oReal.horasMes} al mes</strong>,
                de ${oReal.meses} ${oReal.meses === 1 ? "mes cerrado" : "meses cerrados"}),
                saldrían <strong>${fmt(oReal.valor)} por hora</strong>.`}
           Los escenarios usan <strong>${fmt(ohEsc)}</strong>, que supone
           <strong>${horasAhora} horas facturables al mes</strong>.
           ${oReal.fiable ? "" : `<br><br>⚠ <strong>Este número todavía no es de fiar.</strong>
             ${oReal.meses < 3
               ? `Solo hay ${oReal.meses} ${oReal.meses === 1 ? "mes cerrado" : "meses cerrados"} con horas apuntadas.`
               : "Se apuntan menos horas de las que se trabajan."}
             Mientras el equipo no reporte todo, escribe tú abajo las horas facturables
             que de verdad hacen al mes entre todos.`}
           <div class="modal-fila" style="margin-top:.6rem;gap:.5rem;align-items:flex-end">
             <label class="mat-filtro-label" style="flex:0 1 15rem">Horas facturables al mes
               <input type="number" id="oh-horas-mes" min="40" max="2000" step="10"
                      value="${(estData.config || {}).horas_mes || horasAhora || ""}"
                      placeholder="Ej: 280">
             </label>
             <button type="button" class="accion secundaria" id="btn-oh-horas">Guardar y recalcular</button>
           </div>
           ${oReal.fiable ? `<button type="button" class="accion secundaria" id="btn-overhead-real"
              style="margin-top:.5rem">Poner ${fmt(oReal.valor)} en los tres escenarios</button>` : ""}
         </div>
       </div>`;

    $("estimador-panel").innerHTML = `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">${esc(est.nombre)}
          <span class="recibo-chip ${est.estado === "convertido" ? "insp-paso" : est.estado === "congelado" ? "leido" : "por_leer"}">${esc(est.estado.toUpperCase())}</span>
          <span class="recibo-chip leido">${MODO_ETIQ[est.modo]}</span>
        </div>
        <div class="alcance-estado">${esc(est.cliente || "")}${est.sqft ? ` · ${esc(est.sqft)} sqft` : ""}</div>
        <div class="modal-fila" style="margin-top:.6rem">
          <label class="mat-filtro-label">Escenario
            <select id="est-escenario" ${soloLectura ? "disabled" : ""}>
              ${(estData.escenarios || []).map(x =>
                `<option value="${esc(x.id)}"${x.id === est.escenario ? " selected" : ""}>${esc(x.id)} — ${esc(x.nombre || "")}</option>`).join("")}
            </select>
          </label>
          <label class="mat-filtro-label">Factor de productividad
            <input id="est-factor" type="number" min="0.5" max="2" step="0.05" value="${esc(est.factor || 1)}" ${soloLectura ? "disabled" : ""}>
          </label>
        </div>
        ${est.modo === "planos" ? `
        <label class="mat-filtro-label" style="margin-top:.5rem;display:block">Cableado del trabajo (para los conectores automáticos)
          <select id="est-cable" ${soloLectura ? "disabled" : ""}>
            <option value="romex"${est.cable === "romex" ? " selected" : ""}>Romex (NM)</option>
            <option value="mc"${est.cable === "mc" ? " selected" : ""}>MC</option>
            <option value="mixto"${est.cable === "mixto" ? " selected" : ""}>Mixto</option>
          </select>
        </label>` : ""}
      </div>
      ${bannerOverhead}
      ${esRapido ? panelRapidoHTML(est, c, soloLectura) : ""}
      ${est.modo === "planos" && !soloLectura ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">📥 Takeoff de Bluebeam</div>
        <p class="modal-nota">En Bluebeam: Markups List → Export → CSV. Abre el archivo, copia todo y pégalo aquí.</p>
        <textarea id="takeoff-texto" rows="4" placeholder="Pega aquí el export…"
          style="width:100%;font:inherit;font-size:.8rem;padding:.55rem .7rem;border:1px solid var(--mp-line);border-radius:10px"></textarea>
        <button type="button" class="accion secundaria" id="btn-takeoff-analizar" style="margin-top:.45rem">🔎 Analizar</button>
        <div id="takeoff-preview"></div>
      </div>` : ""}
      ${!esRapido && est.modo !== "planos" && (ensDisponibles.length || !soloLectura) ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🧩 Ensambles — cuenta como piensas</div>
        ${filasEnsambles || `<p class="cal-sin-eventos">Los ensambles se siembran al correr el SQL v2.</p>`}
      </div>` : ""}
      ${esRapido ? "" : cardFrecuentes}
      ${!soloLectura && !esRapido ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🔎 Buscar en el catálogo (${(estData.catalogo || []).length})</div>
        <input id="est-buscar" type="text" placeholder="Ej: recessed, breaker gfci, 12/2…" autocomplete="off"
          style="width:100%;font:inherit;padding:.55rem .7rem;border:1px solid var(--mp-line);border-radius:10px">
        <div id="est-resultados"></div>
        <button type="button" class="accion secundaria" id="btn-cat-nuevo" style="margin-top:.45rem">➕ Crear ítem nuevo en el catálogo</button>
      </div>` : ""}
      ${esRapido ? "" : `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Ítems (${c.items.length}${c.autos.length ? ` + ${c.autos.length} automáticos` : ""})</div>
        ${filasItems || `<p class="cal-sin-eventos">Agrega ensambles, pega el takeoff o busca en el catálogo.</p>`}
        ${filasAutos}
      </div>`}
      <div class="cal-panel-card">
        <div class="cal-form-titulo">💵 Resumen — fórmula Max Power
          ${!soloLectura ? `<span class="chk-avance">toca ✎ para jugar con los números</span>` : ""}</div>
        ${!soloLectura ? `
        <div class="modal-fila" style="margin-bottom:.4rem">
          <label class="mat-filtro-label">Escenario
            <select id="res-escenario">
              ${(estData.escenarios || []).map(x =>
                `<option value="${esc(x.id)}"${x.id === est.escenario ? " selected" : ""}>${esc(x.id)} — ${esc(x.nombre || "")}</option>`).join("")}
            </select>
          </label>
          <label class="mat-filtro-label">Factor de productividad
            <input id="res-factor" type="number" min="0.5" max="2" step="0.05" value="${esc(est.factor || 1)}">
          </label>
        </div>` : ""}
        <div class="rent-fila"><span>${esRapido ? `Material (${c.lineasMat.length} línea${c.lineasMat.length === 1 ? "" : "s"})` : `Material (ítems${c.autos.length ? " + automáticos" : ""})`}</span><span>${fmt(r2(c.matSubtotal - c.misc - c.mermaMat))}</span></div>
        ${c.mermaMat > 0 ? `<div class="rent-fila"><span>+ Merma (cables ${Math.round((estData.config.merma_cable ?? .1) * 100)}% · tubería ${Math.round((estData.config.merma_tuberia ?? .05) * 100)}%)</span><span>${fmt(r2(c.mermaMat))}</span></div>` : ""}
        <div class="rent-fila"><span>+ Misceláneas (${pctTxt(c.miscPct)}${nnDist(est.misc_pct) ? " ✏" : " — tape, wirenuts, fijación"})${lapiz("misc_pct", "pct", c.miscPct, "Misceláneas — % del material")}</span><span>${fmt(r2(c.misc))}</span></div>
        <div class="rent-fila"><span>+ Sales tax (${pctTxt(c.taxPct)}${nnDist(est.tax_pct) ? " ✏" : ""})${lapiz("tax_pct", "pct", c.taxPct, "Sales tax — % del material")}</span><span>${fmt(r2(c.tax))}</span></div>
        ${c.markupPct > 0 ? `<div class="rent-fila"><span>+ Markup de materiales (${pctTxt(c.markupPct)}) ✏${lapiz("markup_pct", "pct", c.markupPct, "Markup de materiales — % sobre el material con tax")}</span><span>${fmt(r2(c.markup))}</span></div>`
          : !soloLectura ? `<div class="rent-fila"><span><button type="button" class="btn-formula insp-borrar" data-campo="markup_pct" data-tipo="pct" data-actual="0" data-nombre="Markup de materiales — % sobre el material con tax">+ Agregar markup de materiales</button></span><span></span></div>` : ""}
        <div class="rent-fila"><span>Horas de TODO el trabajo (${r2(c.horasBase)} × factor ${est.factor || 1})</span><span>${r2(c.horas)} h</span></div>
        <div class="rent-fila"><span>Labor (${r2(c.horas)} h × ${fmt(r2(c.tarifaMezclada))} cuadrilla)</span><span>${fmt(r2(c.laborBase))}</span></div>
        <div class="rent-fila"><span>+ Beneficios sobre el labor (${pctTxt(c.benefitsPct)}${nnDist(est.benefits_pct) ? " ✏" : ""})${lapiz("benefits_pct", "pct", c.benefitsPct, "Beneficios — % sobre el labor")}</span><span>${fmt(r2(c.benefits))}</span></div>
        <div class="rent-fila"><span>+ Overhead (${r2(c.horas)} h × ${fmt(c.ohHH)}${nnDist(est.overhead_hh) ? " ✏" : ""})${lapiz("overhead_hh", "monto", c.ohHH, "Overhead — $ por hora-hombre")}</span><span>${fmt(r2(c.overhead))}</span></div>
        <div class="rent-fila"><span>+ Profit (${pctTxt(c.profitPct)}${nnDist(est.profit_pct) ? " ✏" : ""})${lapiz("profit_pct", "pct", c.profitPct, "Profit — % sobre costo + overhead")}</span><span>${fmt(r2(c.profit))}</span></div>
        <div class="rent-fila rent-total ok"><span>🎯 PRECIO DE LA PROPUESTA</span><span>${fmt(r2(c.bid))}</span></div>
        ${est.sqft ? `<p class="rent-nota">${fmt(r2(c.bid / est.sqft))} por sq ft</p>` : ""}
      </div>
      <div class="cal-panel-card acciones">
        <button class="accion secundaria" id="btn-est-propuesta">📄 Generar propuesta</button>
        ${est.estado === "borrador" ? `<button class="accion secundaria" id="btn-est-congelar">🔒 Congelar</button>` : ""}
        ${est.estado === "congelado" ? `<button class="accion secundaria" id="btn-est-descongelar">🔓 Volver a borrador</button>` : ""}
        ${est.estado !== "convertido" ? `<button class="accion" id="btn-est-convertir">🚀 Convertir en proyecto</button>` : ""}
        <button class="accion secundaria" id="btn-est-propuesta">Armar propuesta para el cliente</button>
        ${propuestasDelEstimado(est.id)}
      </div>
      <div id="propuesta-caja"></div>`;

    // --- cabecera ---
    // Resumen editable: escenario y factor también se cambian desde abajo
    const selEscRes = $("res-escenario"), inpFactorRes = $("res-factor");
    if (selEscRes) selEscRes.addEventListener("change", async () => {
      await DB.cambiarEstimado(est.id, { escenario: selEscRes.value }).catch(() => {});
      await recargarEstimador();
    });
    if (inpFactorRes) inpFactorRes.addEventListener("change", async () => {
      const v = Number(inpFactorRes.value) || 1;
      await DB.cambiarEstimado(est.id, { factor: v }).catch(() => {});
      await recargarEstimador();
    });
    // Los lápices de la fórmula: editar, poner en 0, o vaciar para volver al escenario
    document.querySelectorAll(".btn-formula").forEach(btn => {
      btn.addEventListener("click", async () => {
        const { campo, tipo, actual, nombre } = btn.dataset;
        const esPct = tipo === "pct";
        const mostrado = esPct ? String(Math.round(Number(actual) * 1000) / 10) : String(actual);
        const resp = prompt(
          `${nombre}\n\nEscribe ${esPct ? "el %" : "el monto en $"} (0 = quitarlo · vacío = volver al valor del escenario):`,
          mostrado);
        if (resp === null) return;
        const limpio = resp.replace(/[%$,\s]/g, "");
        let valor;
        if (limpio === "") valor = null;
        else {
          const num = Number(limpio);
          if (!Number.isFinite(num) || num < 0) { avisar("Valor no válido", true); return; }
          valor = esPct ? num / 100 : num;
        }
        try {
          await DB.cambiarEstimado(est.id, { [campo]: valor });
          await recargarEstimador();
          avisar(valor === null ? "De vuelta al valor del escenario ✓" : "Fórmula ajustada ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });

    if (esRapido) engancharRapido(est, soloLectura);

    const selEsc = $("est-escenario"), inpFactor = $("est-factor"), selCable = $("est-cable");
    if (selEsc && !soloLectura) selEsc.addEventListener("change", async () => {
      await DB.cambiarEstimado(est.id, { escenario: selEsc.value }).catch(() => {});
      await recargarEstimador();
    });
    if (inpFactor && !soloLectura) inpFactor.addEventListener("change", async () => {
      const v = Number(inpFactor.value);
      if (!Number.isFinite(v) || v <= 0) return;
      await DB.cambiarEstimado(est.id, { factor: v }).catch(() => {});
      await recargarEstimador();
    });
    if (selCable && !soloLectura) selCable.addEventListener("change", async () => {
      await DB.cambiarEstimado(est.id, { cable: selCable.value }).catch(() => {});
      await recargarEstimador();
    });

    // --- overhead: las horas facturables al mes que declara el dueño ---
    const btnOhHoras = $("btn-oh-horas");
    if (btnOhHoras) btnOhHoras.addEventListener("click", async () => {
      const v = Number($("oh-horas-mes").value);
      if (!(v >= 40 && v <= 2000)) {
        avisar("Pon las horas facturables de todo el equipo en un mes (entre 40 y 2000).", true);
        return;
      }
      try {
        await DB.guardarConfig("horas_mes", v);
        await recargarEstimador();
        const g = (estData.generales || []).reduce((s, x) => s + Number(x.monto_mensual || 0), 0);
        avisar(`Guardado: ${v} horas al mes → ${fmt(Math.round((g / v) * 100) / 100)} por hora de overhead ✓`);
      } catch (err) { avisar("No se pudo guardar: " + err.message, true); }
    });

    // --- overhead: llevar el número calculado a los tres escenarios ---
    // Se avisa ANTES con lo que le pasaría a este mismo estimado, porque
    // cambiar el overhead mueve el precio de todas las ofertas de golpe.
    const btnOver = $("btn-overhead-real");
    if (btnOver) btnOver.addEventListener("click", async () => {
      const antes = c.bid;
      const despues = calcularEstimado({ ...est, overhead_hh: oReal.valor }).bid;
      const ok = confirm(
        `Esto cambia el overhead de ${fmt(ohEsc)} a ${fmt(oReal.valor)} por hora en los tres escenarios.\n\n` +
        `Este estimado pasaría de ${fmt(Math.round(antes * 100) / 100)} a ${fmt(Math.round(despues * 100) / 100)}.\n\n` +
        `Afecta a TODAS las ofertas nuevas. ¿Seguro?`);
      if (!ok) return;
      try {
        await DB.actualizarOverhead(oReal.valor);
        await recargarEstimador();
        avisar(`Overhead puesto en ${fmt(oReal.valor)} por hora en los tres escenarios ✓`);
      } catch (err) { avisar("No se pudo: " + err.message, true); }
    });

    // --- takeoff ---
    const btnAna = $("btn-takeoff-analizar");
    if (btnAna) btnAna.addEventListener("click", () => {
      const texto = $("takeoff-texto").value;
      takeoffPreview = analizarTakeoff(texto).map(f => ({ ...f, match: emparejarTakeoff(f), decision: null }));
      pintarTakeoffPreview(est);
    });

    // --- ensambles +/- ---
    // Los clics van en fila india (cada uno espera al anterior) para que un
    // doble clic rápido nunca cree contadores duplicados; y si un duplicado
    // viejo existiera, se une solo (auto-cura) antes de sumar o restar.
    // delta = sumar/restar; objetivo = poner ESTA cantidad exacta (numerito editable)
    async function ajustarEnsamble(ensId, delta, objetivo) {
      const filas = (estData.estEnsambles || [])
        .filter(e => e.estimado_id === est.id && e.ensamble_id === ensId);
      let fila = filas[0];
      if (filas.length > 1) {
        const total = filas.reduce((s, f) => s + Number(f.cantidad), 0);
        await DB.cambiarEnsambleQty(fila.id, total);
        for (const f of filas.slice(1)) await DB.quitarEnsamble(f.id);
        fila = { ...fila, cantidad: total };
      }
      const actual = fila ? Number(fila.cantidad) : 0;
      const nueva = objetivo !== undefined ? objetivo : actual + delta;
      if (nueva === actual) return;
      if (!fila) {
        if (nueva <= 0) return;
        const cuerpo = { estimado_id: est.id, ensamble_id: ensId, cantidad: nueva };
        const ens = ensDisponibles.find(e => e.id === ensId);
        if (ens && ens.pies_editable) {
          const prom = piesPromedioEnsamble(ens.id);
          const resp = prompt(`¿Cuántos pies de cable hasta el panel?\n(Deja vacío para usar el promedio de ${prom || "?"} ft)`);
          const pies = Number((resp || "").replace(/[^\d.]/g, ""));
          if (pies > 0) cuerpo.pies = pies;
        }
        await DB.ponerEnsamble(cuerpo);
      } else if (nueva <= 0) await DB.quitarEnsamble(fila.id);
      else await DB.cambiarEnsambleQty(fila.id, nueva);
    }
    const enFilaEnsamble = op => {
      colaEnsambles = colaEnsambles
        .then(async () => { await op(); await recargarEstimador(); })
        .catch(err => avisar("No se pudo: " + err.message, true));
    };
    $("estimador-panel").querySelectorAll(".btn-ens-mas").forEach(btn => {
      btn.addEventListener("click", () =>
        enFilaEnsamble(() => ajustarEnsamble(Number(btn.dataset.ens), +1)));
    });
    $("estimador-panel").querySelectorAll(".btn-ens-menos").forEach(btn => {
      btn.addEventListener("click", () =>
        enFilaEnsamble(() => ajustarEnsamble(Number(btn.dataset.ens), -1)));
    });
    // El numerito del medio: escribe la cantidad y listo (Enter o salir del campo)
    $("estimador-panel").querySelectorAll(".ens-qty-input").forEach(inp => {
      inp.addEventListener("change", () => {
        const v = Math.max(0, Math.round(Number(inp.value) || 0));
        enFilaEnsamble(() => ajustarEnsamble(Number(inp.dataset.ens), 0, v));
      });
    });
    $("estimador-panel").querySelectorAll(".btn-ens-pies").forEach(btn => {
      btn.addEventListener("click", () => {
        const resp = prompt(`Pies de cable medidos hasta el panel:\n(Deja vacío para volver al promedio de ${btn.dataset.prom || "?"} ft)`);
        if (resp === null) return;
        const pies = Number(resp.replace(/[^\d.]/g, ""));
        enFilaEnsamble(() => DB.cambiarEnsamblePies(Number(btn.dataset.eid), pies > 0 ? pies : null));
      });
    });

    // Cajita de cantidad EN LA MISMA FILA (nada de ventanitas del navegador,
    // que en el teléfono a veces se tragan el primer intento)
    const abrirCantidad = (fila, alConfirmar) => {
      const ya = fila.querySelector(".est-qty-mini");
      if (ya) { ya.querySelector("input").focus(); return; }
      const flecha = fila.querySelector(".cat-flecha");
      if (flecha) flecha.hidden = true;
      const caja = document.createElement("span");
      caja.className = "est-qty-mini";
      caja.innerHTML = `<input type="number" min="0.01" step="any" inputmode="decimal" placeholder="cant.">
        <button type="button" class="accion" title="Agregar">✓</button>`;
      fila.appendChild(caja);
      const inp = caja.querySelector("input");
      const ok = async () => {
        const cantidad = Number(inp.value.replace(/[,\s]/g, ""));
        if (!Number.isFinite(cantidad) || cantidad <= 0) { avisar("Ponle la cantidad", true); inp.focus(); return; }
        await alConfirmar(cantidad);
      };
      caja.querySelector("button").addEventListener("click", e => { e.stopPropagation(); ok(); });
      inp.addEventListener("click", e => e.stopPropagation());
      inp.addEventListener("keydown", e => { if (e.key === "Enter") { e.preventDefault(); ok(); } });
      inp.focus();
    };
    const agregarDelCatalogo = async (nombre, unidad, precio, horas, cantidad) => {
      try {
        await DB.crearItemEstimado({
          estimado_id: est.id, item: nombre, unidad, precio, horas, cantidad,
          orden: c.items.length + 1
        });
        await recargarEstimador();
        avisar(`${cantidad} × ${nombre} agregado ✓`);
      } catch (err) { avisar("No se pudo agregar: " + err.message, true); }
    };

    // --- búsqueda del catálogo + crear ítem ---
    const inpBuscar = $("est-buscar");
    if (inpBuscar) inpBuscar.addEventListener("input", () => {
      const q = inpBuscar.value.trim().toLowerCase();
      // Busca por palabras sueltas ("outlet gfci" encuentra "GFCI OUTLET WR")
      // y muestra TODOS los que coincidan — la lista tiene su propio scroll.
      const palabras = q.split(/\s+/).filter(Boolean);
      const res = q.length < 2 ? [] : (estData.catalogo || [])
        .filter(i => {
          const texto = (i.item + " " + (i.seccion || "")).toLowerCase();
          return palabras.every(p => texto.includes(p));
        })
        .sort((a, b) => {
          const ta = a.item.toLowerCase(), tb = b.item.toLowerCase();
          return (ta.indexOf(palabras[0]) - tb.indexOf(palabras[0])) || ta.localeCompare(tb);
        });
      $("est-resultados").innerHTML = (q.length >= 2
        ? `<p class="modal-nota" style="margin:.4rem 0 .3rem">${res.length
            ? `${res.length} resultado${res.length === 1 ? "" : "s"}`
            : "Nada con ese nombre — prueba otra palabra o crea el ítem nuevo aquí abajo."}</p>` : "")
        + res.map(i => `
        <div class="mat-item est-res" data-id="${i.id}" style="cursor:pointer">
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(i.item)}</span>
            <span class="alcance-estado">${esc(i.seccion || "")} · ${esc(i.unidad || "")} · ${fmt(i.precio)} · ${esc(i.horas_unidad)} h/u</span>
          </span>
          <span class="cat-flecha">＋</span>
        </div>`).join("");
      $("est-resultados").querySelectorAll(".est-res").forEach(el => {
        el.addEventListener("click", () => {
          const item = (estData.catalogo || []).find(x => String(x.id) === el.dataset.id);
          if (!item) return;
          abrirCantidad(el, cantidad =>
            agregarDelCatalogo(item.item, item.unidad, item.precio, item.horas_unidad, cantidad));
        });
      });
    });
    // --- ⭐ frecuentes: agregar con un toque + "Ver más" ---
    document.querySelectorAll(".est-frec").forEach(el => {
      el.addEventListener("click", () => {
        const nombre = el.dataset.item;
        const cat = (estData.catalogo || []).find(x => x.item === nombre);
        const hist = (estData.items || []).find(x => x.item === nombre);
        const base = cat || hist;
        if (!base) return;
        abrirCantidad(el, cantidad => agregarDelCatalogo(
          nombre, base.unidad, Number(base.precio) || 0,
          Number(cat ? cat.horas_unidad : hist.horas) || 0, cantidad));
      });
    });
    const btnFrecMas = $("btn-frec-mas");
    if (btnFrecMas) btnFrecMas.addEventListener("click", () => {
      frecuentesExpandido = !frecuentesExpandido;
      pintarEstimador();
    });

    const btnCatNuevo = $("btn-cat-nuevo");
    if (btnCatNuevo) btnCatNuevo.addEventListener("click", async () => {
      const nombre = prompt("Nombre del ítem nuevo (como quieres verlo en el catálogo):");
      if (!nombre || !nombre.trim()) return;
      const precio = Number((prompt("Precio por unidad ($):") || "").replace(/[$,\s]/g, ""));
      const horas = Number((prompt("Horas de labor por unidad (ej: 0.5):") || "").replace(/[,\s]/g, ""));
      const unidad = prompt("Unidad (E, LF, MLF…):", "E") || "E";
      if (!Number.isFinite(precio) || !Number.isFinite(horas)) { avisar("Precio u horas no válidos", true); return; }
      try {
        await DB.crearItemCatalogo({ seccion: "MISCELLANEOUS", item: nombre.trim().toUpperCase(),
          unidad: unidad.trim(), precio, horas_unidad: horas, orden: 3000 });
        await recargarEstimador();
        avisar("Ítem creado en el catálogo ✓ — búscalo y agrégalo");
      } catch (err) { avisar("No se pudo crear: " + err.message, true); }
    });

    // --- items qty / quitar ---
    $("estimador-panel").querySelectorAll(".btn-item-qty").forEach(btn => {
      btn.addEventListener("click", async () => {
        const qty = prompt("Nueva cantidad:", btn.dataset.qty);
        if (qty === null) return;
        const cantidad = Number(qty.replace(/[,\s]/g, ""));
        if (!Number.isFinite(cantidad) || cantidad <= 0) { avisar("Cantidad no válida", true); return; }
        try { await DB.cambiarItemEstimado(btn.dataset.id, { cantidad }); await recargarEstimador(); }
        catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("estimador-panel").querySelectorAll(".btn-item-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        try { await DB.eliminarItemEstimado(btn.dataset.id); await recargarEstimador(); }
        catch (err) { avisar("No se pudo quitar: " + err.message, true); }
      });
    });

    // --- propuesta / congelar / convertir ---
    $("btn-est-propuesta").addEventListener("click", () => {
      $("propuesta-caja").innerHTML = `
        <div class="cal-panel-card">
          <div class="cal-form-titulo">📄 Propuesta lista para copiar</div>
          <textarea id="propuesta-texto" rows="16" readonly
            style="width:100%;font-family:ui-monospace,monospace;font-size:.78rem;padding:.6rem;border:1px solid var(--mp-line);border-radius:10px">${esc(textoPropuesta(est, c))}</textarea>
          <button class="accion" id="btn-copiar-propuesta" style="margin-top:.45rem">📋 Copiar</button>
        </div>`;
      $("btn-copiar-propuesta").addEventListener("click", async () => {
        try { await navigator.clipboard.writeText($("propuesta-texto").value); avisar("Propuesta copiada ✓"); }
        catch { $("propuesta-texto").select(); document.execCommand("copy"); avisar("Propuesta copiada ✓"); }
      });
      $("propuesta-caja").scrollIntoView({ behavior: "smooth" });
    });
    const btnCong = $("btn-est-congelar"), btnDesc = $("btn-est-descongelar");
    if (btnCong) btnCong.addEventListener("click", async () => {
      await DB.cambiarEstimado(est.id, { estado: "congelado" }).catch(() => {});
      await recargarEstimador();
      avisar("Estimado congelado 🔒 — los precios quedan fijos");
    });
    if (btnDesc) btnDesc.addEventListener("click", async () => {
      await DB.cambiarEstimado(est.id, { estado: "borrador" }).catch(() => {});
      await recargarEstimador();
    });
    const btnProp = $("btn-est-propuesta");
    if (btnProp) btnProp.addEventListener("click", () => irPropuesta(est.id));
    $("estimador-panel").querySelectorAll(".btn-cierre").forEach(b => {
      b.addEventListener("click", () => irCierre(Number(b.dataset.id)));
    });

    const btnConv = $("btn-est-convertir");
    if (btnConv) btnConv.addEventListener("click", async () => {
      if (!confirm(`¿Convertir "${est.nombre}" en proyecto?\n\nSe crea con contrato ${fmt(r2(c.bid))}, horas estimadas, presupuesto de materiales, 3 hitos de pago y su alcance por puntos.`)) return;
      const idNuevo = est.nombre.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
        .slice(0, 30) + "-" + Math.random().toString(36).slice(2, 6);
      const bid = r2(c.bid);
      try {
        await DB.crearProyecto({
          id: idNuevo,
          tipo: est.tipo === "Commercial" ? "comercial" : "residencial",
          nombre: est.nombre,
          direccion: est.direccion || "Por confirmar",
          cliente: est.cliente || "Por confirmar",
          via: "Directo",
          estado: "enviado",
          estado_detalle: "Creado desde el Estimador — propuesta por enviar.",
          proxima_accion: "Enviar la propuesta al cliente.",
          ref: `EST-${est.id}`,
          horas_estimadas: r2(c.horas)
        });
        await DB.crearFinanzas({ proyecto_id: idNuevo, contrato: bid, cobrado: 0, presupuesto_materiales: r2(c.totalMaterial) });
        const m1 = r2(bid * 0.35), m2 = r2(bid * 0.40);
        await DB.crearHito({ proyecto_id: idNuevo, titulo: "Milestone 1 — 35% movilización", condicion: "Al aceptar / movilización", monto: m1, estado: "pendiente", orden: 1 });
        await DB.crearHito({ proyecto_id: idNuevo, titulo: "Milestone 2 — 40% avance", condicion: "Rough / avance principal completo", monto: m2, estado: "pendiente", orden: 2 });
        await DB.crearHito({ proyecto_id: idNuevo, titulo: "Milestone 3 — 25% final", condicion: "Al pasar inspección final", monto: r2(bid - m1 - m2), estado: "pendiente", orden: 3 });
        // El alcance por puntos nace de los ensambles (o secciones)
        const ensDelEst2 = (estData.estEnsambles || []).filter(e => e.estimado_id === est.id && Number(e.cantidad) > 0);
        let ordenP = 1;
        if (ensDelEst2.length) {
          for (const ee of ensDelEst2) {
            const ens = (estData.ensambles || []).find(x => x.id === ee.ensamble_id);
            if (ens) await DB.crearPunto({ proyecto_id: idNuevo, texto: `${ens.nombre} (${ee.cantidad})`, orden: ordenP++ });
          }
        } else {
          const secciones = [...new Set(c.items.map(i => (catalogoExacto(i.item) || {}).seccion).filter(Boolean))];
          for (const s of secciones.slice(0, 8))
            await DB.crearPunto({ proyecto_id: idNuevo, texto: `Completar ${s.toLowerCase()}`, orden: ordenP++ });
        }
        await DB.crearPunto({ proyecto_id: idNuevo, texto: "Inspección final aprobada", orden: ordenP });
        await DB.cambiarEstimado(est.id, { estado: "convertido" });
        await recargar();
        avisar(`Proyecto creado ✓ — contrato ${fmt(bid)} con hitos, presupuestos y alcance`);
        irDetalle(idNuevo);
      } catch (err) { avisar("No se pudo convertir: " + err.message, true); }
    });
  }

  // Vista previa del takeoff: OK / SIN MAPEO con decisiones
  function pintarTakeoffPreview(est) {
    if (!takeoffPreview) return;
    const filas = takeoffPreview.map((f, ix) => {
      if (f.match) {
        return `<div class="mat-item">
          <span class="recibo-chip conciliado">OK</span>
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(f.subject)}${f.size ? " · " + esc(f.size) : ""}</span>
            <span class="alcance-estado">→ ${esc(f.match.item.item)} · ${Math.round(f.qty * f.match.factor * 1000) / 1000} ${esc(f.match.item.unidad || "")} (por ${f.match.via})</span>
          </span>
        </div>`;
      }
      const sugs = sugerenciasCatalogo(f.size ? `${f.size} ${f.subject}` : f.subject, 5);
      return `<div class="mat-item recibo-por_leer">
        <span class="recibo-chip por_leer">SIN MAPEO</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(f.subject)}${f.size ? " · " + esc(f.size) : ""} — cant. ${esc(f.qty)}</span>
          <select class="takeoff-decision" data-ix="${ix}" style="font:inherit;font-size:.78rem;margin-top:.25rem;max-width:100%">
            <option value="">— elige qué hacer —</option>
            ${sugs.map(s => `<option value="cat:${s.id}">≈ ${esc(s.item)}</option>`).join("")}
            <option value="nuevo">➕ Crear como ítem nuevo</option>
            <option value="omitir">Omitir esta línea</option>
          </select>
        </span>
      </div>`;
    }).join("");
    $("takeoff-preview").innerHTML = `
      ${filas || `<p class="cal-sin-eventos">No encontré líneas — revisa que pegaste el CSV completo con encabezados.</p>`}
      ${takeoffPreview.length ? `<button class="accion" id="btn-takeoff-aplicar" style="margin-top:.5rem">✓ Aplicar al estimado</button>` : ""}`;

    $("takeoff-preview").querySelectorAll(".takeoff-decision").forEach(sel => {
      sel.addEventListener("change", () => {
        takeoffPreview[Number(sel.dataset.ix)].decision = sel.value || null;
      });
    });
    const btnAplicar = $("btn-takeoff-aplicar");
    if (btnAplicar) btnAplicar.addEventListener("click", async () => {
      let puestos = 0, omitidos = 0, aprendidos = 0;
      try {
        for (const f of takeoffPreview) {
          let cat = null, factor = 1;
          if (f.match) { cat = f.match.item; factor = f.match.factor; }
          else if (f.decision && f.decision.startsWith("cat:")) {
            cat = (estData.catalogo || []).find(x => String(x.id) === f.decision.slice(4));
          } else if (f.decision === "nuevo") {
            const precio = Number((prompt(`Precio por unidad de "${f.subject}" ($):`) || "0").replace(/[$,\s]/g, "")) || 0;
            const horas = Number((prompt(`Horas por unidad de "${f.subject}":`) || "0").replace(/[,\s]/g, "")) || 0;
            const creado = await DB.crearItemCatalogo({ seccion: "MISCELLANEOUS",
              item: f.subject.toUpperCase(), unidad: "E", precio, horas_unidad: horas, orden: 3000 });
            cat = creado[0];
          } else { omitidos++; continue; }
          if (!cat) { omitidos++; continue; }
          // La app aprende tu decisión: la próxima vez este tool sale OK solo
          if (!f.match) {
            try {
              await DB.crearAlias({ alias: f.size ? `${f.size} ${f.subject}` : f.subject,
                item: cat.item, factor: 1, nota: "aprendido al aplicar takeoff" });
              aprendidos++;
            } catch (e) { /* si no se pudo guardar el alias, el ítem entra igual */ }
          }
          await DB.crearItemEstimado({
            estimado_id: est.id, item: cat.item, unidad: cat.unidad,
            precio: cat.precio, horas: cat.horas_unidad,
            cantidad: Math.round(f.qty * factor * 1000) / 1000,
            orden: 100, origen: "takeoff"
          });
          puestos++;
        }
        takeoffPreview = null;
        await recargarEstimador();
        avisar(`Takeoff aplicado ✓ — ${puestos} líneas al estimado${aprendidos ? `, ${aprendidos} mapeos aprendidos` : ""}${omitidos ? `, ${omitidos} omitidas` : ""}`);
      } catch (err) { avisar("No se pudo aplicar: " + err.message, true); }
    });
  }

  // ============================================================
  // CALENDARIO
  // ============================================================
  function fechaISO(a, m, d) {
    return `${a}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  }

  function irCalendario() {
    mostrar("calendario", { kicker: "Programación", titulo: "Calendario", volver: true, nuevo: false });
    const hoy = new Date();
    if (calAno === undefined) { calAno = hoy.getFullYear(); calMes = hoy.getMonth(); }
    if (!calDiaSel) calDiaSel = fechaISO(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
    pintarCalendario();
  }
  $btnCal.addEventListener("click", irCalendario);
  $("cal-prev").addEventListener("click", () => { calMes--; if (calMes < 0) { calMes = 11; calAno--; } pintarCalendario(); });
  $("cal-next").addEventListener("click", () => { calMes++; if (calMes > 11) { calMes = 0; calAno++; } pintarCalendario(); });

  const MESES = EN_APP
    ? ["January","February","March","April","May","June","July","August","September","October","November","December"]
    : ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];

  function pintarCalendario() {
    $("cal-mes").textContent = `${MESES[calMes]} ${calAno}`;
    const hoy = new Date();
    const hoyISO = fechaISO(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
    const evs = eventosCal();
    const pens = pendientesAbiertos();

    const primerDia = new Date(calAno, calMes, 1);
    const diasEnMes = new Date(calAno, calMes + 1, 0).getDate();
    const offset = (primerDia.getDay() + 6) % 7;

    let celdas = "";
    for (let i = 0; i < offset; i++) celdas += `<div class="cal-dia vacio-celda"></div>`;
    for (let d = 1; d <= diasEnMes; d++) {
      const iso = fechaISO(calAno, calMes, d);
      const dow = new Date(calAno, calMes, d).getDay();
      const evsDia = evs.filter(e => e.fecha === iso);
      const pensDia = pens.filter(p => p.fecha === iso);
      const esHoy = iso === hoyISO;
      const esFuturoLaboral = iso >= hoyISO && dow !== 0 && dow !== 6;

      let clases = "cal-dia";
      if (dow === 0) clases += " domingo";
      if (esHoy) clases += " hoy";
      if (evsDia.length) clases += " con-trabajo";
      else if (esFuturoLaboral) clases += " sin-programar";
      if (pensDia.length) clases += " con-pendiente";
      if (iso === calDiaSel) clases += " seleccionado";

      // En pantalla grande la celda enseña QUÉ hay ese día, no solo cuántos.
      const titulos = evsDia.slice(0, 3).map(e => {
        const quien = (e.asignados || []).map(x => String(x).split(" ")[0]).join(", ");
        const corto = String(e.titulo || "").replace(/^[^—-]*[—-]\s*/, "").trim() || String(e.titulo || "");
        return `<span class="cal-ev" title="${esc(e.titulo || "")}${quien ? " · " + esc(quien) : ""}">${esc(corto)}</span>`;
      }).join("");
      const masEv = evsDia.length > 3 ? `<span class="cal-ev mas">+${evsDia.length - 3} más</span>` : "";
      const pensTxt = pensDia.length
        ? `<span class="cal-ev pend">${pensDia.length} pendiente${pensDia.length > 1 ? "s" : ""}</span>` : "";
      celdas += `<button class="${clases}" data-fecha="${iso}">
          <span class="cal-num">${d}</span>
          ${evsDia.length ? `<span class="cal-marca">${evsDia.length}</span>` : ""}
          ${pensDia.length ? `<span class="cal-marca-roja">⚠</span>` : ""}
          <span class="cal-dia-lista">${titulos}${masEv}${pensTxt}</span>
        </button>`;
    }
    $("cal-grid").innerHTML = celdas;
    $("cal-grid").querySelectorAll(".cal-dia[data-fecha]").forEach(btn => {
      btn.addEventListener("click", () => { calDiaSel = btn.dataset.fecha; pintarCalendario(); });
    });
    pintarDiaPanel();
  }

  // 📅 Los próximos días de trabajo de ESTE proyecto, dentro de su ficha
  function eventosProyectoHTML(p) {
    const hoy = hoyISO();
    const evs = eventosCal()
      .filter(e => e.proyecto === p.id && e.fecha >= hoy && e.estadoEv !== "cancelado")
      .sort((a, b) => a.fecha.localeCompare(b.fecha))
      .slice(0, 6);
    if (!evs.length) return "";
    return `
      <div class="detalle-seccion">
        <h3>📅 Próximos días de trabajo</h3>
        ${evs.map(e => `<div class="agenda-item">
          <span class="agenda-hora">${esc(e.fecha.slice(5))} ${esc(e.hora || "")}</span>
          <span class="agenda-info">
            <span class="agenda-titulo">${esc(sinMontos(e.titulo))}</span>
            ${e.asignados && e.asignados.length ? `<span class="agenda-lugar">👤 ${esc(e.asignados.join(", "))}</span>` : ""}
            ${e.ubicacion ? `<span class="agenda-lugar">📍 ${esc(e.ubicacion)}</span>` : ""}
          </span>
        </div>`).join("")}
      </div>`;
  }
  function pintarDiaPanel() {
    if (!calDiaSel) { $("cal-dia-panel").innerHTML = ""; return; }
    const [a, m, d] = calDiaSel.split("-").map(Number);
    const nombreDia = new Date(a, m - 1, d).toLocaleDateString(LOCALE, { weekday: "long", day: "numeric", month: "long" });

    const evsDia = eventosCal().filter(e => e.fecha === calDiaSel);
    const listaEvs = evsDia.length
      ? evsDia.map(e => {
          const p = e.proyecto ? proyectos().find(x => x.id === e.proyecto) : null;
          return `<div class="agenda-item${e.alerta ? " alerta" : ""}${e.estadoEv === "cancelado" ? " ev-cancelado" : ""}">
              <span class="agenda-hora">${esc(e.hora || "")}</span>
              <span class="agenda-info">
                <span class="agenda-titulo"${e.estadoEv === "cancelado" ? ' style="text-decoration:line-through;opacity:.6"' : ""}>${esc(sinMontos(e.titulo))}${e.estadoEv === "hecho" ? " ✓" : ""}${e.estadoEv === "cancelado" ? " (cancelado)" : ""}</span>
                ${p ? `<span class="agenda-lugar">🔧 ${esc(p.nombre)}</span>` : ""}
                ${e.asignados && e.asignados.length ? `<span class="agenda-lugar">👤 ${esc(e.asignados.join(", "))}</span>` : ""}
                ${e.ubicacion ? `<span class="agenda-lugar">📍 ${esc(e.ubicacion)}</span>` : ""}
                ${e.nota ? `<span class="agenda-nota">${esc(sinMontos(e.nota))}</span>` : ""}
              </span>
              ${usuario.editar && e.estadoEv === "programado" && !String(e.id).startsWith("insp-") ? `
              <button type="button" class="chip-cobrar ev-cerrar" data-id="${e.id}" data-estado="hecho" title="Se hizo — cerrar este día">✓</button>
              <button type="button" class="insp-borrar ev-cerrar" data-id="${e.id}" data-estado="cancelado" title="No se hizo — cancelarlo">✗</button>` : ""}
              ${usuario.editar && e.estadoEv !== "programado" && !String(e.id).startsWith("insp-") ? `
              <button type="button" class="insp-borrar ev-cerrar" data-id="${e.id}" data-estado="programado" title="Volver a dejarlo abierto">↩</button>` : ""}
              ${usuario.finanzas && !String(e.id).startsWith("insp-") ? `<button type="button" class="insp-borrar ev-borrar" data-id="${e.id}" title="Eliminar este evento">🗑</button>` : ""}
            </div>`;
        }).join("")
      : `<p class="cal-sin-eventos">Nada programado este día.</p>`;

    const pensDia = pendientesAbiertos().filter(p => p.fecha === calDiaSel);
    const listaPens = pensDia.map(p => {
      const pr = proyectos().find(x => x.id === p.proyecto);
      return `<div class="pendiente-item">
          <span class="pendiente-icono">⚠</span>
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(sinMontos(p.descripcion))}</span>
            <span class="alcance-estado">${pr ? esc(pr.nombre) + " · " : ""}${esc(p.autor || "")}</span>
          </span>
          ${usuario.editar ? `<button class="insp-borrar btn-pen-editar" data-id="${p.id}" title="Corregir el texto">✎</button>
          <button class="accion secundaria btn-resolver" data-id="${p.id}">✓ Resuelto</button>` : ""}
        </div>`;
    }).join("");

    const opciones = proyectosConTrabajo(["enviado"])
      .map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("");

    $("cal-dia-panel").innerHTML = `
      <div class="cal-panel-card">
        <div class="cal-panel-fecha">${esc(nombreDia)}</div>
        ${listaEvs}
        ${listaPens}
        <form id="form-evento" class="cal-form">
          <div class="cal-form-titulo">Agregar a este día</div>
          <label>Proyecto / trabajo
            <select name="proyecto">
              <option value="">— General (no es de un proyecto) —</option>
              ${opciones}
            </select>
          </label>
          <div class="modal-fila">
            <label>Hora (opcional)
              <input name="hora" type="time">
            </label>
            <label>Tipo
              <select name="tipoEntrada">
                <option value="evento">Evento / visita</option>
                <option value="pendiente">⚠ Pendiente / bloqueo</option>
              </select>
            </label>
          </div>
          <label>Descripción
            <input name="descripcion" type="text" required placeholder="Ej: inspección de rough / faltó cable 14/2" autocomplete="off">
          </label>
          <button type="submit" class="accion">Guardar</button>
        </form>
      </div>`;

    // ✓ / ✗ Cerrar el día. El calendario nunca se cerraba: 48 eventos ya
    // pasados seguían "programados" y nadie sabía qué se hizo de verdad.
    $("cal-dia-panel").querySelectorAll(".ev-cerrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const dice = { hecho: "✓ Día cerrado como HECHO", cancelado: "✗ Día marcado como que NO se hizo", programado: "↩ Vuelve a estar abierto" };
        try {
          await DB.cambiarEvento(btn.dataset.id, { estado: btn.dataset.estado });
          await recargar();
          pintarCalendario();
          avisar(dice[btn.dataset.estado] || "Listo ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("cal-dia-panel").querySelectorAll(".ev-borrar").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este evento del calendario?")) return;
        try {
          await DB.eliminarEvento(btn.dataset.id);
          await recargar();
          avisar("Evento eliminado ✓");
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    $("cal-dia-panel").querySelectorAll(".btn-pen-editar").forEach(btn => {
      btn.addEventListener("click", () => editarPendiente(btn.dataset.id, pintarCalendario));
    });
    $("cal-dia-panel").querySelectorAll(".btn-resolver").forEach(btn => {
      btn.addEventListener("click", async () => {
        try {
          await DB.resolverPendiente(btn.dataset.id);
          const pen = pendientesTodos().find(x => String(x.id) === String(btn.dataset.id));
          if (pen) pen.resuelto = true;
          pintarCalendario();
          avisar("Pendiente resuelto ✓");
        } catch (err) {
          avisar("No se pudo resolver: " + err.message, true);
        }
      });
    });

    $("cal-dia-panel").querySelector("#form-evento").addEventListener("submit", async e => {
      e.preventDefault();
      const f = new FormData(e.target);
      const esPendiente = f.get("tipoEntrada") === "pendiente";
      const proyectoId = f.get("proyecto") || null;
      const descripcion = (f.get("descripcion") || "").toString().trim();
      if (!descripcion) return;
      let hora = (f.get("hora") || "").toString();
      if (hora) {
        const [hh, mm] = hora.split(":").map(Number);
        hora = `${((hh + 11) % 12) + 1}:${String(mm).padStart(2, "0")} ${hh < 12 ? "AM" : "PM"}`;
      }
      try {
        if (esPendiente) {
          await DB.crearPendiente({ fecha: calDiaSel, proyecto_id: proyectoId, descripcion });
        } else {
          await DB.crearEvento({
            fecha: calDiaSel, hora: hora || null, titulo: descripcion,
            proyecto_id: proyectoId, nota: "Agregado por " + usuario.nombre
          });
        }
        await recargar();
        avisar(esPendiente ? "Pendiente guardado ✓ (en rojo hasta resolverse)" : "Evento guardado ✓");
      } catch (err) {
        avisar("No se pudo guardar: " + err.message, true);
      }
    });
  }



  // ============================================================
  // 📄 ARMAR PROPUESTA — el cierre en la mesa de la cocina (solo dueño)
  //
  // De un estimado salen hasta tres OPCIONES DE ALCANCE (qué trabajo se
  // hace), nunca opciones de margen: el precio de las tres se calcula con
  // el MISMO escenario interno. Las tarifas, las horas, los beneficios y
  // el profit no salen de aquí ni por asomo.
  //
  // Cada opción añade lo anterior: A = lo esencial · B = A + extras 1 ·
  // C = B + extras 2. Así la diferencia se ve de un vistazo.
  // ============================================================
  let propData = null;      // { propuestas, opciones, textos, pendientes }
  let propActiva = null;    // el borrador que se está armando, en memoria

  const PROP_REPARTOS = [
    { id: "50/50",    etiqueta: "50 / 50",       pcts: [50, 50] },
    { id: "40/40/20", etiqueta: "40 / 40 / 20",  pcts: [40, 40, 20] },
    { id: "35/40/25", etiqueta: "35 / 40 / 25",  pcts: [35, 40, 25] }
  ];
  const PROP_BLOQUES = [
    { id: "base", etiqueta: "Lo esencial",   letra: "A" },
    { id: "x1",   etiqueta: "Extras 1",      letra: "B" },
    { id: "x2",   etiqueta: "Extras 2",      letra: "C" },
    { id: "fuera", etiqueta: "Fuera",        letra: "—" }
  ];

  // Reparte un total en porcentajes SIN perder ni ganar un centavo:
  // el último hito absorbe el redondeo. Un contrato cuyos hitos no suman
  // el total es fuga de dinero y vergüenza legal.
  function repartirAlCentavo(total, pcts) {
    const cents = Math.round(Number(total) * 100);
    const montos = [];
    let usado = 0;
    pcts.forEach((p, i) => {
      if (i === pcts.length - 1) { montos.push((cents - usado) / 100); return; }
      const c = Math.round(cents * (Number(p) / 100));
      usado += c;
      montos.push(c / 100);
    });
    return montos;
  }

  function irPropuesta(estimadoId) {
    if (!usuario.finanzas) return;
    const est = (estData.estimados || []).find(e => e.id === estimadoId);
    if (!est) { avisar("No encuentro ese estimado", true); return; }
    mostrar("propuesta", { kicker: "Solo dueño", titulo: "Armar propuesta", volver: true, nuevo: false });
    const items = itemsDelEstimado(est);
    propActiva = {
      estimado: est,
      items: items.map((it, i) => ({ ...it, _i: i, bloque: "base" })),
      reparto: "40/40/20",
      pcts: [40, 40, 20],
      dias: 15,
      recomendada: "B",
      titulos: { A: "Lo esencial", B: "La recomendada", C: "Completa" },
      proyecto_id: null,
      email: "", tel: ""
    };
    // Si el estimado ya se convirtió en proyecto, se hereda lo que se sepa
    const proy = proyectos().find(p => (p.nombre || "").trim() === (est.nombre || "").trim());
    if (proy) {
      propActiva.proyecto_id = proy.id;
      propActiva.email = proy.cliente_email || "";
      propActiva.tel = proy.cliente_tel || "";
    }
    pintarPropuesta();
  }

  // Los ítems de cada opción: cada letra ARRASTRA lo anterior
  function propItemsDe(letra) {
    const cuales = letra === "A" ? ["base"] : letra === "B" ? ["base", "x1"] : ["base", "x1", "x2"];
    return propActiva.items.filter(it => cuales.indexOf(it.bloque) >= 0);
  }
  // ¿Qué letras tienen sentido? A siempre; B y C solo si su bloque tiene algo.
  function propLetras() {
    const hay = b => propActiva.items.some(it => it.bloque === b);
    const l = ["A"];
    if (hay("x1")) l.push("B");
    if (hay("x1") && hay("x2")) l.push("C");
    return l;
  }
  function propPrecio(letra) {
    const items = propItemsDe(letra);
    if (!items.length) return 0;
    return Math.round(calcularEstimado(propActiva.estimado, items).bid * 100) / 100;
  }

  function pintarPropuesta() {
    const p = propActiva;
    if (!p) return;
    const letras = propLetras();
    const filas = p.items.map(it => `
      <div class="prop-item">
        <span class="prop-item-txt">
          <span class="prop-item-nom">${esc(it.item)}</span>
          <span class="prop-item-sub">${esc(it.cantidad)} ${esc(it.unidad || "")}</span>
        </span>
        <span class="prop-bloques" data-i="${it._i}">
          ${PROP_BLOQUES.map(b => `<button type="button" class="prop-bq${it.bloque === b.id ? " puesto" : ""}" data-b="${b.id}" title="${esc(b.etiqueta)}">${b.letra}</button>`).join("")}
        </span>
      </div>`).join("");

    const tarjetas = letras.map(l => {
      const precio = propPrecio(l);
      const montos = repartirAlCentavo(precio, p.pcts);
      const suma = Math.round(montos.reduce((s, m) => s + m, 0) * 100) / 100;
      const cuadra = Math.abs(suma - precio) < 0.005;
      return `
        <div class="prop-tarjeta${p.recomendada === l ? " recomendada" : ""}">
          <div class="prop-tarjeta-cab">
            <input class="prop-titulo" data-l="${l}" type="text" value="${esc(p.titulos[l] || "")}">
            <button type="button" class="prop-estrella${p.recomendada === l ? " puesto" : ""}" data-l="${l}" title="La que recomiendas">★</button>
          </div>
          <div class="prop-precio">${fmt(precio)}</div>
          <div class="prop-hoy">hoy aparta ${fmt(montos[0])}</div>
          <div class="prop-hitos">
            ${montos.map((m, i) => `<span>${p.pcts[i]}% · ${fmt(m)}${i === 0 ? " (depósito)" : ""}</span>`).join("")}
          </div>
          <div class="prop-cuadra ${cuadra ? "ok" : "mal"}">${cuadra ? "cuadra al centavo ✓" : "⚠ no cuadra"}</div>
          <div class="prop-cuenta">${propItemsDe(l).length} partidas${l !== "A" ? " · además de lo anterior" : ""}</div>
        </div>`;
    }).join("");

    const lista = proyectos().filter(x => x.estado !== "completado");
    $("propuesta-panel").innerHTML = `
      <div class="cal-panel-card">
        <div class="lev-titulo">${levIco("resumen")} ${esc(p.estimado.nombre)}</div>
        <p class="lev-nota">Reparte las partidas en bloques. <b>A</b> es lo esencial; <b>B</b> añade los extras 1; <b>C</b> añade los extras 2. Lo que pongas en <b>—</b> se queda fuera de todas.</p>
        ${filas || `<p class="cal-sin-eventos">Este estimado no tiene partidas.</p>`}
      </div>

      <div class="cal-panel-card">
        <div class="lev-lab">Cómo se paga <i>— editable, no es camisa de fuerza</i></div>
        <div class="lev-chips" data-campo="reparto">
          ${PROP_REPARTOS.map(r => `<button type="button" class="lev-chip${p.reparto === r.id ? " puesto" : ""}" data-valor="${r.id}">${r.etiqueta}</button>`).join("")}
        </div>
        <div class="prop-pcts">
          ${p.pcts.map((v, i) => `
            <label>Pago ${i + 1}${i === 0 ? " (depósito)" : ""}
              <input class="prop-pct" data-i="${i}" type="number" inputmode="decimal" min="0" max="100" step="0.5" value="${v}">
            </label>`).join("")}
          <button type="button" class="accion secundaria" id="prop-menos" ${p.pcts.length <= 2 ? "disabled" : ""}>− pago</button>
          <button type="button" class="accion secundaria" id="prop-mas" ${p.pcts.length >= 5 ? "disabled" : ""}>＋ pago</button>
        </div>
        <div class="prop-suma ${Math.abs(p.pcts.reduce((s, v) => s + Number(v), 0) - 100) < 0.001 ? "ok" : "mal"}">
          Suman ${p.pcts.reduce((s, v) => s + Number(v), 0)}%${Math.abs(p.pcts.reduce((s, v) => s + Number(v), 0) - 100) < 0.001 ? " ✓" : " — tienen que sumar 100"}
        </div>
      </div>

      <div class="cal-panel-card">
        <div class="lev-lab">Las opciones que verá el cliente</div>
        <div class="prop-tarjetas">${tarjetas}</div>
      </div>

      <div class="cal-panel-card">
        <div class="lev-lab">La obra y el cliente</div>
        <label>¿A qué proyecto pertenece?
          <select id="prop-proyecto">
            <option value="">— elige el proyecto —</option>
            ${lista.map(x => `<option value="${esc(x.id)}"${p.proyecto_id === x.id ? " selected" : ""}>${esc(x.nombre)}</option>`).join("")}
          </select>
        </label>
        <div class="modal-fila">
          <label>Correo del cliente
            <input id="prop-email" type="email" value="${esc(p.email)}" placeholder="para mandarle la copia" autocomplete="off">
          </label>
          <label>Teléfono del cliente
            <input id="prop-tel" type="tel" value="${esc(p.tel)}" placeholder="para mandarle el enlace" autocomplete="off">
          </label>
        </div>
        <label>La propuesta vale
          <select id="prop-dias">
            ${[7, 15, 30, 45, 60].map(d => `<option value="${d}"${p.dias === d ? " selected" : ""}>${d} días</option>`).join("")}
          </select>
        </label>
        <button type="button" class="accion" id="prop-guardar" style="margin-top:.8rem">Guardar la propuesta</button>
        <p class="lev-nota">Se guarda con las opciones congeladas: si después retocas el estimado, esta propuesta no se mueve.</p>
      </div>`;

    engancharPropuesta();
  }

  function engancharPropuesta() {
    const p = propActiva;
    // Bloques de cada partida
    $("propuesta-panel").querySelectorAll(".prop-bloques").forEach(caja => {
      caja.querySelectorAll(".prop-bq").forEach(b => {
        b.addEventListener("click", () => {
          const it = p.items.find(x => x._i === Number(caja.dataset.i));
          if (it) it.bloque = b.dataset.b;
          pintarPropuesta();
        });
      });
    });
    // Reparto
    $("propuesta-panel").querySelectorAll('.lev-chips[data-campo="reparto"] .lev-chip').forEach(b => {
      b.addEventListener("click", () => {
        const r = PROP_REPARTOS.find(x => x.id === b.dataset.valor);
        if (r) { p.reparto = r.id; p.pcts = r.pcts.slice(); }
        pintarPropuesta();
      });
    });
    $("propuesta-panel").querySelectorAll(".prop-pct").forEach(el => {
      el.addEventListener("change", () => {
        p.pcts[Number(el.dataset.i)] = Number(el.value) || 0;
        p.reparto = "a mano";
        pintarPropuesta();
      });
    });
    $("prop-mas").addEventListener("click", () => { p.pcts.push(0); p.reparto = "a mano"; pintarPropuesta(); });
    $("prop-menos").addEventListener("click", () => { p.pcts.pop(); p.reparto = "a mano"; pintarPropuesta(); });
    // Tarjetas
    $("propuesta-panel").querySelectorAll(".prop-titulo").forEach(el => {
      el.addEventListener("change", () => { p.titulos[el.dataset.l] = el.value; });
    });
    $("propuesta-panel").querySelectorAll(".prop-estrella").forEach(b => {
      b.addEventListener("click", () => { p.recomendada = b.dataset.l; pintarPropuesta(); });
    });
    // Obra y cliente
    $("prop-proyecto").addEventListener("change", e => {
      p.proyecto_id = e.target.value || null;
      const proy = proyectos().find(x => x.id === p.proyecto_id);
      if (proy) {
        if (!p.email) { p.email = proy.cliente_email || ""; }
        if (!p.tel) { p.tel = proy.cliente_tel || ""; }
        pintarPropuesta();
      }
    });
    $("prop-email").addEventListener("change", e => { p.email = e.target.value.trim(); });
    $("prop-tel").addEventListener("change", e => { p.tel = e.target.value.trim(); });
    $("prop-dias").addEventListener("change", e => { p.dias = Number(e.target.value); });
    $("prop-guardar").addEventListener("click", guardarPropuesta);
  }

  async function guardarPropuesta() {
    const p = propActiva;
    const letras = propLetras();
    const sumaPct = p.pcts.reduce((s, v) => s + Number(v), 0);
    if (Math.abs(sumaPct - 100) > 0.001) { avisar("Los pagos tienen que sumar 100%", true); return; }
    if (!p.proyecto_id) { avisar("Elige a qué proyecto pertenece", true); return; }
    if (!propItemsDe("A").length) { avisar("La opción A no puede quedar vacía", true); return; }

    const btn = $("prop-guardar");
    btn.disabled = true; btn.textContent = "Guardando…";
    try {
      const hasta = new Date();
      hasta.setDate(hasta.getDate() + p.dias);
      const creada = await DB.crearPropuesta({
        proyecto_id: p.proyecto_id,
        estimado_id: p.estimado.id,
        estado: "borrador",
        escenario: p.estimado.escenario,
        valida_hasta: hasta.toISOString().slice(0, 10)
      });
      const propuestaId = creada[0].id;

      const filas = letras.map((l, i) => {
        const items = propItemsDe(l);
        const precio = propPrecio(l);
        const montos = repartirAlCentavo(precio, p.pcts);
        return {
          propuesta_id: propuestaId,
          letra: l,
          titulo: p.titulos[l] || l,
          // Copia CONGELADA: si mañana se retoca el estimado, esto no se mueve
          alcance: items.map(it => ({ item: it.item, cantidad: it.cantidad, unidad: it.unidad })),
          no_incluye: [],
          precio,
          hitos_plan: montos.map((m, j) => ({
            titulo: `Pago ${j + 1}${j === 0 ? " — depósito" : ""}`,
            monto: m, pct: p.pcts[j], es_deposito: j === 0
          })),
          recomendada: p.recomendada === l,
          orden: i
        };
      });
      await DB.crearOpciones(filas);

      // El correo y el teléfono viven en el proyecto (la tabla de clientes
      // llega en otra tanda); solo se escriben si Edgar puso algo.
      const cambios = {};
      if (p.email) cambios.cliente_email = p.email;
      if (p.tel) cambios.cliente_tel = p.tel;
      if (Object.keys(cambios).length) await DB.cambiarProyecto(p.proyecto_id, cambios);

      await recargarEstimador();
      avisar(`Propuesta guardada con ${filas.length} ${filas.length === 1 ? "opción" : "opciones"} ✓`);
      propActiva = null;
      irEstimador(p.estimado.id);
    } catch (err) {
      avisar("No se pudo guardar: " + err.message, true);
      btn.disabled = false; btn.textContent = "Guardar la propuesta";
    }
  }


  // ============================================================
  // 📑 PREPARAR CIERRE — llenar la plantilla del SOW (solo dueño)
  //
  // La plantilla de Edgar manda. Aquí NO se escribe el contrato: se
  // rellenan los huecos numéricos que hoy saca a mano (cliente, fechas,
  // totales, opciones y la tabla de pagos), y se le devuelve el HTML
  // listo para que él lo termine de redactar y lo convierta a PDF con
  // WeasyPrint, igual que siempre.
  //
  // La plantilla vive en el teléfono de Edgar (la elige una vez y se
  // guarda en el navegador), no en el repositorio público: lleva sus
  // condiciones comerciales dentro.
  // ============================================================
  const LLAVE_PLANTILLA = "mxp_plantilla_sow";
  let cierrePropuesta = null;   // { propuesta, opciones, proyecto }
  let cierreDatos = null;       // lo que Edgar teclea en esta pantalla

  function plantillaGuardada() {
    try { return localStorage.getItem(LLAVE_PLANTILLA) || null; } catch { return null; }
  }
  function guardarPlantilla(txt) {
    try { localStorage.setItem(LLAVE_PLANTILLA, txt); return true; } catch { return false; }
  }

  // Fecha de Florida, sin depender del reloj del teléfono si viaja
  function hoyFlorida() {
    const f = new Date(new Date().toLocaleString("en-US", { timeZone: "America/New_York" }));
    return f;
  }
  const dosDig = n => String(n).padStart(2, "0");
  const fechaLarga = f => f.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });

  // Los tres días hábiles para cancelar: de lunes a SÁBADO (el sábado
  // cuenta), saltando domingos. Los feriados los confirma el abogado;
  // hasta entonces se cuentan como hábiles y la app lo dice.
  function tresDiasHabiles(desde) {
    const f = new Date(desde.getTime());
    let contados = 0;
    while (contados < 3) {
      f.setDate(f.getDate() + 1);
      if (f.getDay() !== 0) contados++;   // 0 = domingo
    }
    return f;
  }

  function irCierre(propuestaId) {
    if (!usuario.finanzas) return;
    const p = (propData.propuestas || []).find(x => x.id === propuestaId);
    if (!p) { avisar("No encuentro esa propuesta", true); return; }
    const ops = (propData.opciones || []).filter(o => o.propuesta_id === p.id)
      .sort((a, b) => (a.orden || 0) - (b.orden || 0));
    const proy = proyectos().find(x => x.id === p.proyecto_id) || {};
    cierrePropuesta = { propuesta: p, opciones: ops, proyecto: proy };
    // La ciudad sale de la dirección si se puede; si no, la escribe él
    const ciudad = (proy.direccion || "").split(",")[1];
    cierreDatos = {
      client: proy.cliente || "", client2: "", contactos: proy.cliente || "",
      homeowner: "", proyecto_en: proy.nombre || "",
      ciudad: (ciudad || "").trim(), base: ops.length ? ops[0].letra : "A"
    };
    mostrar("cierre", { kicker: "Solo dueño", titulo: "Preparar cierre", volver: true, nuevo: false });
    pintarCierre();
  }

  function pintarCierre() {
    const c = cierrePropuesta, d = cierreDatos;
    if (!c) return;
    const hay = !!plantillaGuardada();
    const ops = c.opciones;
    const base = ops.find(o => o.letra === d.base) || ops[0] || {};
    const hitos = (base.hitos_plan || []);
    const extras = ops.filter(o => o.letra !== d.base);

    $("cierre-panel").innerHTML = `
      <div class="cal-panel-card">
        <div class="lev-titulo">${levIco("resumen")} ${esc(c.proyecto.nombre || c.propuesta.proyecto_id)}</div>
        <p class="lev-nota">Esto llena los huecos de tu plantilla. El texto del alcance y las condiciones los escribes tú como siempre.</p>
        ${hay ? `<div class="lev-auto">✓ Plantilla guardada en este teléfono. <button type="button" class="lev-btn-ico" id="cierre-otra" title="Cambiar">${levIco("papelera", 17)}</button></div>`
              : `<div class="lev-roja">
                   <div class="lev-roja-t">Falta la plantilla</div>
                   <p>Elige una vez el archivo <b>SOW_Template_v3.html</b>. Se guarda en este teléfono y no hace falta volver a buscarlo.</p>
                   <input type="file" id="cierre-archivo" accept=".html,text/html">
                 </div>`}
      </div>

      <div class="cal-panel-card">
        <div class="lev-lab">Quién firma</div>
        <label>Cliente (quien paga y firma)
          <input class="cierre-in" data-c="client" type="text" value="${esc(d.client)}" placeholder="Ej: Heather &amp; Lee">
        </label>
        <label>Segundo firmante <i>— déjalo vacío si solo firma uno</i>
          <input class="cierre-in" data-c="client2" type="text" value="${esc(d.client2)}" placeholder="El otro dueño de la casa">
        </label>
        <div class="modal-fila">
          <label>Atención / contacto
            <input class="cierre-in" data-c="contactos" type="text" value="${esc(d.contactos)}">
          </label>
          <label>Dueño de la casa <i>— solo si NO es el cliente</i>
            <input class="cierre-in" data-c="homeowner" type="text" value="${esc(d.homeowner)}">
          </label>
        </div>
        <div class="modal-fila">
          <label>Nombre del proyecto (en inglés)
            <input class="cierre-in" data-c="proyecto_en" type="text" value="${esc(d.proyecto_en)}">
          </label>
          <label>Jurisdicción (ciudad)
            <input class="cierre-in" data-c="ciudad" type="text" value="${esc(d.ciudad)}" placeholder="Ej: St. Petersburg">
          </label>
        </div>
      </div>

      <div class="cal-panel-card">
        <div class="lev-lab">Qué va como contrato base</div>
        <div class="lev-chips" data-campo="base">
          ${ops.map(o => `<button type="button" class="lev-chip${d.base === o.letra ? " puesto" : ""}" data-valor="${o.letra}">${esc(o.letra)} · ${esc(o.titulo)} · ${fmt(o.precio)}</button>`).join("")}
        </div>
        <p class="lev-nota">Lo que elijas es el <b>total</b> del contrato. Las demás salen como opciones que el cliente puede añadir.</p>
        <div class="cierre-cuadro">
          <div><span>Total del contrato</span><b>${fmt(base.precio || 0)}</b></div>
          ${extras.map(o => `<div><span>Opción ${esc(o.letra)} — ${esc(o.titulo)}</span><b>${fmt(o.precio - (base.precio || 0))}</b></div>`).join("")}
          ${hitos.map((h, i) => `<div><span>Pago ${i + 1}${h.es_deposito ? " (depósito)" : ""} — ${h.pct}%</span><b>${fmt(h.monto)}</b></div>`).join("")}
        </div>
        ${hitos.length && hitos[0].pct > 10 ? `<p class="lev-nota">El depósito es el ${hitos[0].pct}% (más del 10%): el contrato lleva la cláusula 9.16 con los plazos de permiso y arranque que exige la ley.</p>` : ""}
      </div>

      <div class="cal-panel-card">
        <button type="button" class="accion" id="cierre-armar"${hay ? "" : " disabled"}>Armar el contrato</button>
        <p class="lev-nota">Te baja el HTML con los huecos llenos. Lo terminas de escribir, lo pasas a PDF con WeasyPrint y lo subes al proyecto.</p>
        <div id="cierre-faltan"></div>
      </div>`;
    engancharCierre();
  }

  function engancharCierre() {
    const d = cierreDatos;
    $("cierre-panel").querySelectorAll(".cierre-in").forEach(el => {
      el.addEventListener("change", () => { d[el.dataset.c] = el.value.trim(); });
    });
    $("cierre-panel").querySelectorAll('.lev-chips[data-campo="base"] .lev-chip').forEach(b => {
      b.addEventListener("click", () => { d.base = b.dataset.valor; pintarCierre(); });
    });
    const arch = $("cierre-archivo");
    if (arch) arch.addEventListener("change", async () => {
      const f = arch.files && arch.files[0];
      if (!f) return;
      const txt = await f.text();
      if (txt.indexOf("{{CLIENT}}") < 0) { avisar("Ese archivo no parece la plantilla del SOW", true); return; }
      if (!guardarPlantilla(txt)) { avisar("No cupo en el teléfono. Borra fotos o usa otro navegador.", true); return; }
      avisar("Plantilla guardada ✓ — no hace falta volver a buscarla");
      pintarCierre();
    });
    const otra = $("cierre-otra");
    if (otra) otra.addEventListener("click", () => {
      if (!confirm("¿Quitar la plantilla guardada y elegir otra?")) return;
      try { localStorage.removeItem(LLAVE_PLANTILLA); } catch { /* nada */ }
      pintarCierre();
    });
    const btn = $("cierre-armar");
    if (btn) btn.addEventListener("click", armarContrato);
  }

  // Llena la plantilla. Los huecos de REDACCIÓN se quedan tal cual, a la
  // vista, para que Edgar sepa qué le falta escribir.
  function armarContrato() {
    const plantilla = plantillaGuardada();
    if (!plantilla) { avisar("Falta la plantilla", true); return; }
    const c = cierrePropuesta, d = cierreDatos;
    const ops = c.opciones;
    const base = ops.find(o => o.letra === d.base) || ops[0];
    if (!base) { avisar("Esa propuesta no tiene opciones", true); return; }
    const extras = ops.filter(o => o.letra !== d.base);
    const hitos = base.hitos_plan || [];
    const hoy = hoyFlorida();
    const vence = c.propuesta.valida_hasta
      ? new Date(c.propuesta.valida_hasta + "T12:00:00")
      : new Date(hoy.getTime() + 15 * 864e5);
    const dinero = v => Number(v || 0).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const nombreCorto = (c.propuesta.proyecto_id || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 12);

    let t = plantilla;
    // Los porcentajes de {{%}} van en orden: uno por cada pago
    let i = 0;
    t = t.replace(/\{\{%\}\}/g, () => {
      const h = hitos[i++];
      return h ? String(h.pct) + "%" : "{{%}}";
    });
    const cambios = {
      CLIENT: d.client, CLIENT_2: d.client2 || d.client,
      CONTACTOS: d.contactos || d.client,
      HOMEOWNER: d.homeowner || d.client,
      PROYECTO_EN_INGLES: d.proyecto_en,
      DIRECCION: c.proyecto.direccion || "",
      FECHA: fechaLarga(hoy),
      AAAA: String(hoy.getFullYear()),
      MMDD: dosDig(hoy.getMonth() + 1) + dosDig(hoy.getDate()),
      NOMBRE: nombreCorto,
      VENCE_30_DIAS: fechaLarga(vence),
      CIUDAD: d.ciudad,
      TOTAL: dinero(base.precio),
      PCT_DEPOSITO: hitos.length ? String(hitos[0].pct) : "",
      ADDON_A: extras[0] ? extras[0].titulo : "",
      MONTO_A: extras[0] ? dinero(extras[0].precio - base.precio) : "",
      ADDON_B: extras[1] ? extras[1].titulo : "",
      MONTO_B: extras[1] ? dinero(extras[1].precio - base.precio) : "",
      // La línea "Accepted:" del contrato: un solo alcance y un solo precio.
      OPCION_ACEPTADA: `Option ${base.letra} — ${base.titulo}`,
      TOTAL_ACEPTADO: dinero(base.precio)
    };
    hitos.forEach((h, n) => { cambios["M" + (n + 1)] = dinero(h.monto); });
    Object.entries(cambios).forEach(([k, v]) => {
      if (v === "" || v === undefined || v === null) return;
      t = t.split("{{" + k + "}}").join(String(v));
    });

    // Qué huecos quedan (los de redacción, y los que llena el portal al firmar)
    const delPortal = [];   // el portal ya no rellena huecos del cuerpo
    const quedan = [...new Set((t.match(/\{\{[^}]{1,45}\}\}/g) || []))]
      .map(x => x.slice(2, -2))
      .filter(x => delPortal.indexOf(x) < 0);

    const nombreArchivo = `MXP-${cambios.AAAA}-${cambios.MMDD}-${nombreCorto || "SOW"}.html`;
    const blob = new Blob([t], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = nombreArchivo;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);

    const limite = tresDiasHabiles(hoy);
    $("cierre-faltan").innerHTML = `
      <div class="lev-auto" style="margin-top:.7rem">
        ✓ Bajado <b>${esc(nombreArchivo)}</b> · propuesta ${esc("MXP-" + cambios.AAAA + "-" + cambios.MMDD + "-" + nombreCorto)} · vale hasta ${esc(cambios.VENCE_30_DIAS)}
      </div>
      ${quedan.length ? `<div class="lev-lab" style="margin-top:.6rem">Te falta escribir ${quedan.length} ${quedan.length === 1 ? "hueco" : "huecos"}</div>
        <ul class="lev-noincluye">${quedan.map(x => `<li>${esc(x)}</li>`).join("")}</ul>`
        : `<p class="lev-nota">No quedó ningún hueco de redacción.</p>`}
      <p class="lev-nota">Si el cliente firmara hoy, podría cancelar hasta la medianoche del <b>${esc(fechaLarga(limite))}</b> (tres días hábiles, contando el sábado). El formulario de cancelación con la fecha exacta lo genera el portal al firmar. Los feriados los confirma el abogado.</p>`;
    avisar("Contrato armado ✓ — revísalo y pásalo a PDF");
  }


  // ============================================================
  // ESCRIBIR EL ALCANCE — de la hoja dictada al contrato armado
  //
  // Tres fichas: la hoja · la revisión · el contrato.
  // El dinero lo calcula siempre la app (js/alcance.js); el asistente solo
  // redacta prosa en inglés y nunca ve un dólar.
  // Solo el dueño: la pantalla se abre con usuario.finanzas y todo lo que
  // guarda vive dentro de 'propuestas', que ya lleva el candado es_dueno().
  // ============================================================
  let alcActivo = null;   // { proyecto, propuesta, texto, leido, decision, cuenta, salida, admin }
  let alcFicha = 0;       // 0 = la hoja · 1 = la revisión · 2 = el contrato
  let alcPlantilla = null;
  let alcArreglos = {};   // id del botón → el arreglo que aplica

  const ALC_FICHAS = [{ etiqueta: "La hoja" }, { etiqueta: "Revisión" }, { etiqueta: "Contrato" }];

  // El formato en blanco, para copiarlo al portapapeles y llevarlo a Notas
  const ALC_FORMATO = [
    "Cliente: ", "Dirección: ", "Ciudad: ", "Proyecto: ", "Firma: sí", "Permiso: nosotros", "",
    "Hoy", "", "Cambia", "", "Falta", "",
    "Alcance", "1. ", "   - ", "2. ", "   - ", "",
    "No incluye", "- ", "",
    "Precio: ", "", "Pagos: 40/40/20", "",
    "Condiciones",
    "Fotos del panel: ", "Circuitos existentes: ", "240V: ", "Reubicar: ", "Isla: ", "Abrir: ",
    "Fixtures del cliente: ", "Fixtures nuestros: ", "Excavación: ",
    "Listo antes del rough: ", "Acceso: ", "Fases: ", "Áreas: ", "No tocamos: ", "No excluir: ", "",
    "Código", "", "Notas", ""
  ].join("\n");

  async function irAlcance(proyectoId, propuestaId) {
    if (!usuario.finanzas) return;
    const proy = proyectos().find(p => p.id === proyectoId);
    if (!proy) { avisar("No encuentro ese proyecto", true); return; }
    // Las propuestas solo se cargan al abrir el estimador; si se entra directo
    // desde la ficha del proyecto, se traen aquí.
    if (!propData || !propData.propuestas) {
      try { propData = await DB.cargarPropuestas(); } catch { propData = { propuestas: [], opciones: [] }; }
    }
    // Un mismo cliente puede tener DOS trabajos en la misma casa (el panel y el
    // rewire completo). Son dos alcances del MISMO proyecto, no dos proyectos.
    const variantes = alcVariantesDe(proyectoId);
    const prop = propuestaId ? variantes.find(p => p.id === propuestaId) : (variantes[0] || null);
    alcAbrir(proy, prop, variantes);
    mostrar("alcance", { kicker: proy.nombre, titulo: "Escribir el alcance", volver: true });
    pintarAlcance();
  }

  // Las variantes de un proyecto, la más nueva primero
  function alcVariantesDe(proyectoId) {
    return ((propData && propData.propuestas) || [])
      .filter(p => p.proyecto_id === proyectoId)
      .sort((a, b) => String(b.creado || "").localeCompare(String(a.creado || "")));
  }

  // Deja lista una variante en memoria (sin repintar)
  function alcAbrir(proy, prop, variantes) {
    alcActivo = {
      proyecto: proy, propuesta: prop || null,
      variantes: variantes || alcVariantesDe(proy.id),
      texto: (prop && prop.alcance_md) || (prop ? "" : alcGuardadaLocal(proy.id)) || "",
      leido: null, validado: null, cuenta: null, decision: null,
      salida: (prop && prop.alcance_en) || null,
      huella: (prop && prop.alcance_huella) || null,
      // lo que Edgar ya explicó ("eso no es un precio, es el año"): se respeta
      perdonadas: (prop && prop.alcance_decisiones && prop.alcance_decisiones.perdonadas) || (prop ? [] : alcPerdonLocal(proy.id)),
      respuestas: {}, contrato: null
    };
    alcFicha = 0;
    if (alcActivo.texto.trim()) { try { alcCalcular(); } catch { /* la hoja vieja puede estar a medias */ } }
  }

  // Cómo se llama cada variante en las fichas de arriba
  function alcTituloDe(prop) {
    const L = prop && prop.alcance_leido;
    if (L && L.datos && L.datos.proyecto) return String(L.datos.proyecto);
    const ops = ((propData && propData.opciones) || []).filter(o => o.propuesta_id === (prop || {}).id);
    const base = ops.find(o => o.letra === "A") || ops[0];
    if (base && base.titulo) return String(base.titulo);
    return "Sin nombre todavía";
  }
  const ALC_ESTADOS = { borrador: "borrador", enviada: "enviada", firmada: "FIRMADA",
                        vencida: "vencida", cambio_pedido: "cambio pedido",
                        no_elegida: "no elegida" };

  // Cambiar de variante sin perder lo escrito en la que estaba abierta
  function alcCambiarVariante(id) {
    alcRecoger();
    const prop = alcActivo.variantes.find(p => String(p.id) === String(id));
    if (!prop) return;
    alcAbrir(alcActivo.proyecto, prop, alcActivo.variantes);
    pintarAlcance();
  }

  // Un alcance nuevo del MISMO proyecto (el segundo trabajo de la misma casa)
  function alcNuevaVariante() {
    alcRecoger();
    alcAbrir(alcActivo.proyecto, null, alcActivo.variantes);
    alcActivo.texto = "";
    pintarAlcance();
    avisar("Alcance nuevo. Pega la hoja y guárdalo: quedará como otra variante de este proyecto.");
  }

  // Lo escrito se guarda solo en el teléfono, para no perderlo sin señal
  const alcLlaveLocal = id => "mxp_alcance_" + id;
  function alcGuardarLocal(id, txt) { try { localStorage.setItem(alcLlaveLocal(id), txt); } catch { /* nada */ } }
  function alcGuardadaLocal(id) { try { return localStorage.getItem(alcLlaveLocal(id)); } catch { return null; } }
  function alcPerdonLocal(id, lista) {
    try {
      if (lista) { localStorage.setItem(alcLlaveLocal(id) + "_perdon", JSON.stringify(lista)); return lista; }
      return JSON.parse(localStorage.getItem(alcLlaveLocal(id) + "_perdon") || "[]");
    } catch { return lista || []; }
  }

  function pintarAlcance() {
    const A = alcActivo;
    if (!A) return;
    const fichas = ALC_FICHAS.map((f, i) => `
      <div class="paso${i < alcFicha ? " hecho" : ""}${i === alcFicha ? " actual" : ""}" data-alcficha="${i}">
        <div class="paso-punto">${i < alcFicha ? "✓" : i + 1}</div>
        <div class="paso-nombre">${esc(f.etiqueta)}</div>
      </div>`).join(`<div class="paso-linea"></div>`);
    let cuerpo = "";
    if (alcFicha === 0) cuerpo = alcFichaHoja();
    else if (alcFicha === 1) cuerpo = alcFichaRevision();
    else cuerpo = alcFichaContrato();
    $("alcance-panel").innerHTML = alcBarraVariantes() +
      `<div class="pasos lev-pasos">${fichas}</div><div class="lev-cuerpo">${cuerpo}</div>`;
    alcEnganchar();
  }

  // Las variantes del proyecto: SOW A, SOW B… Cada una con su hoja y su estado.
  function alcBarraVariantes() {
    const A = alcActivo;
    const V = A.variantes || [];
    const abierta = A.propuesta ? String(A.propuesta.id) : "nueva";
    const letras = "ABCDEFGH";
    // el orden de las letras es el de creación: la primera que se hizo es la A
    const porEdad = V.slice().sort((a, b) => String(a.creado || "").localeCompare(String(b.creado || "")));
    const letraDe = id => letras[porEdad.findIndex(p => p.id === id)] || "?";
    const usd = c => "$" + Alcance.dinero(c);
    const precioDe = prop => {
      const ops = ((propData && propData.opciones) || []).filter(o => o.propuesta_id === prop.id && !o.es_addon);
      if (ops.length) return usd(Math.round(Number(ops[0].precio || 0) * 100));
      const L = prop.alcance_leido;
      return L && L.precio ? usd(L.precio) : "";
    };
    const tarjetas = porEdad.map(p => {
      let est = ALC_ESTADOS[p.estado] || p.estado || "";
      if (p.opcion_elegida_id && p.estado !== "firmada") est = "ELEGIDA por el cliente";
      const firmada = p.estado === "firmada";
      return `<button class="alc-var${String(p.id) === abierta ? " abierta" : ""}${firmada ? " firmada" : ""}" data-variante="${p.id}">
        <span class="alc-var-letra">SOW ${letraDe(p.id)}</span>
        <span class="alc-var-nombre">${esc(alcTituloDe(p))}</span>
        <span class="alc-var-pie">${esc(est)}${precioDe(p) ? " · " + precioDe(p) : ""}</span>
      </button>`;
    }).join("");
    const nueva = `<button class="alc-var nueva${abierta === "nueva" ? " abierta" : ""}" data-variante="nueva">
        <span class="alc-var-letra">+</span>
        <span class="alc-var-nombre">Otro alcance</span>
        <span class="alc-var-pie">del mismo proyecto</span>
      </button>`;
    if (!V.length && abierta === "nueva") return "";   // proyecto nuevo: sin barra, no estorba
    return `<div class="alc-variantes">${tarjetas}${nueva}</div>` +
      (V.length > 1 ? `<p class="lev-nota" style="margin:.1rem 0 .6rem">Este proyecto tiene ${V.length} alcances. Estás en el que está marcado; toca otro para verlo entero.</p>` : "");
  }

  // ---------------------------------------------------------- FICHA 1: la hoja
  function alcFichaHoja() {
    const A = alcActivo;
    const L = A.leido;
    let salida = `<div class="alc-dos"><div class="alc-izq">
      <p class="lev-nota">Pega aquí el alcance como te salga: dictado, un SOW viejo, o la hoja
      con sus títulos. Si viene suelto, toca <b>Ordenar</b> y el asistente lo acomoda delante de ti.
      Después <b>Leer</b>: la app saca el dinero con sus propias cuentas y te lo enseña.</p>
      <textarea id="alc-texto" class="alc-texto" rows="16" placeholder="Pega aquí, o toca «Importar un archivo»">${esc(A.texto)}</textarea>
      <p class="lev-nota" id="alc-arrastra">También puedes arrastrar el archivo encima del cuadro.</p>
      <input type="file" id="alc-archivo" accept=".md,.txt,.markdown,.text,text/plain,text/markdown" hidden>
      <div class="alc-botones">
        <button class="accion" id="alc-importar">Importar un archivo</button>
        <button class="accion secundaria" id="alc-copiar-formato">Copiar el formato en blanco</button>
        <button class="accion secundaria" id="alc-ordenar">Ordenar</button>
        <button class="accion" id="alc-leer">Leer</button>
      </div></div><div class="alc-der">`;

    if (!L) return salida + `<p class="lev-nota">Cuando toques «Leer», aquí sale lo que la app entendió.</p></div></div>`;

    const V = A.validado;
    // "línea 17" es un botón: te lleva a ese renglón en el cuadro y lo deja
    // marcado. Debajo va el renglón tal cual, para ver qué le molestó a la app.
    const txtLineas = String(A.texto || "").replace(/\r/g, "").split("\n");
    const chip = n => n ? `<button class="alc-linea" data-ira="${n}" title="Llévame a ese renglón">línea ${n}</button> ` : "";
    const cita = n => { const t = n ? (txtLineas[n - 1] || "").trim() : "";
      return t ? `<div class="alc-cita" data-ira="${n}">${esc(t.length > 120 ? t.slice(0, 120) + "…" : t)}</div>` : ""; };
    // Los botones de arreglar: uno por cada arreglo que trae el error
    const botonesDe = (arreglos, sufijo) => (arreglos || []).map((a, k) => {
      const id = `${sufijo}-${k}`;
      alcArreglos[id] = a;
      if (a.pide === "monto" || a.pide === "texto")
        return `<span class="alc-fix"><input class="alc-libre alc-fix-in" data-fix-in="${id}" placeholder="${a.pide === "monto" ? "1,850.00" : "escríbelo"}" inputmode="${a.pide === "monto" ? "decimal" : "text"}">
                <button class="alc-op" data-fix="${id}">${esc(a.etiqueta)}</button></span>`;
      if (a.pide === "renglon")
        return `<span class="alc-fix"><select class="alc-libre alc-fix-in" data-fix-in="${id}">${L.items.map(it => `<option value="${it.n}">${it.n}. ${esc(it.titulo.slice(0, 40))}</option>`).join("")}</select>
                <button class="alc-op" data-fix="${id}">${esc(a.etiqueta)}</button></span>`;
      return `<button class="alc-op${a.auto ? " alc-auto" : ""}" data-fix="${id}">${esc(a.etiqueta)}</button>`;
    }).join("");
    // Debajo de lo que se puede dejar como está: Edgar explica en una línea por qué
    // está bien así, la app lo apunta y no lo vuelve a marcar.
    const explicame = (e, sufijo) => {
      if (!e.perdonable || !e.linea) return "";
      const id = `${sufijo}-x`;
      alcArreglos[id] = { tipo: "dejar_asi", linea: e.linea };
      return `<div class="alc-explica"><input class="alc-libre alc-fix-in" data-fix-in="${id}" placeholder="o explícame por qué está bien así (ej.: es el año de la casa)">
              <button class="alc-op" data-fix="${id}">Déjalo así</button></div>`;
    };
    alcArreglos = {};
    if ((A.arreglados || []).length) {
      salida += `<div class="alc-verde"><b>Arreglado:</b><ul>` +
        A.arreglados.map(x => `<li>${esc(x)}</li>`).join("") + `</ul></div>`;
    } else if ((A.perdonadas || []).some(x => x && x.nota)) {
      salida += `<div class="alc-verde"><b>Lo que ya me explicaste (lo respeto):</b><ul>` +
        A.perdonadas.filter(x => x && x.nota).map(x => `<li>«${esc(String(x.texto).slice(0, 50))}» — ${esc(x.nota)}</li>`).join("") + `</ul></div>`;
    }
    const hayAuto = [...V.errores, ...L.avisos].some(e => (e.arreglos || []).some(a => a.auto));
    if (V.errores.length) {
      salida += `<div class="alc-rojo"><b>Hay que arreglar esto antes de seguir:</b>
        ${hayAuto ? `<button class="accion" id="alc-arreglar-todo" style="margin:.4rem 0 .2rem">Arreglar todo lo que pueda solo</button>` : ""}<ul>` +
        V.errores.map((e, i) => `<li>${chip(e.linea)}${esc(e.texto)}${cita(e.linea)}<div class="alc-fixes">${botonesDe(e.arreglos, "e" + i)}</div>${explicame(e, "e" + i)}</li>`).join("") +
        `</ul></div>`;
    }
    const dudas = L.avisos.filter(a => !a.informativo), hechos = L.avisos.filter(a => a.informativo);
    if (dudas.length) {
      salida += `<div class="alc-ambar"><b>Esto no me cuadra del todo (no te frena):</b><ul>` +
        dudas.map((a, i) => `<li>${chip(a.linea)}${esc(a.texto)}${cita(a.linea)}<div class="alc-fixes">${botonesDe(a.arreglos, "a" + i).replace(/<button[^>]*>Eso no es dinero, déjalo<\/button>/, "")}</div>${explicame(a, "a" + i)}</li>`).join("") +
        `</ul></div>`;
    }
    if (hechos.length) {
      salida += `<div class="alc-gris"><b>Lo que quité porque la plantilla ya lo trae — no tienes que hacer nada:</b><ul>` +
        hechos.map(a => `<li>${esc(a.texto)}</li>`).join("") + `</ul></div>`;
    }
    if (V.preguntas.length) {
      salida += `<div class="alc-preguntas"><b>Contéstame esto:</b>` + V.preguntas.map((p, i) => {
        const ya = A.respuestas[p.clave];
        const botones = (p.opciones || []).map((o, k) =>
          `<button class="alc-op${ya === (o.valor !== undefined ? JSON.stringify(o.valor) : o.etiqueta) ? " elegida" : ""}"
            data-preg="${p.clave}" data-val="${esc(o.valor !== undefined ? JSON.stringify(o.valor) : o.etiqueta)}">${esc(o.etiqueta)}</button>`).join("");
        if (p.arreglo) {
          const id = "p" + i; alcArreglos[id] = p.arreglo;
          const alts = (p.alternativas || []).map((al, k) => { const aid = `p${i}x${k}`; alcArreglos[aid] = al.arreglo;
            return `<button class="alc-op" data-fix="${aid}">${esc(al.etiqueta)}</button>`; }).join("");
          return `<div class="alc-pregunta"><p>${chip(p.linea)}${esc(p.texto)}</p>${cita(p.linea)}
            <div class="alc-fix"><input class="alc-libre alc-fix-in" data-fix-in="${id}" placeholder="tu respuesta">
            <button class="alc-op" data-fix="${id}">Poner la respuesta</button>${alts}</div></div>`;
        }
        return `<div class="alc-pregunta"><p>${chip(p.linea)}${esc(p.texto)}</p>${cita(p.linea)}
          <div>${botones}${p.libre || (p.opciones || []).some(o => o.libre) ? `<input class="alc-libre" data-preg="${p.clave}" value="${esc(ya && ya[0] !== "[" && ya[0] !== '"' ? ya : "")}" placeholder="escríbelo">` : ""}</div></div>`;
      }).join("") + `</div>`;
    }

    // La tarjeta "Lo que entendí": aquí Edgar ve el dinero cuadrado
    const cta = A.cuenta, dec = A.decision;
    const d = L.datos;
    const usd = c => "$" + Alcance.dinero(c);
    const encendidas = Alcance.ORDEN_9.filter(k => dec.clausulas[k]);
    salida += `
      <div class="alc-entendi">
        <h3>Lo que entendí</h3>
        <div class="alc-rejilla">
          <div><span>Cliente</span><b>${esc(d.cliente || "—")}</b></div>
          <div><span>Tipo</span><b>${dec.esGC ? "por contratista general" : "directo con el dueño"}</b></div>
          <div><span>Documento</span><b>${dec.conFirma ? "propuesta con firma" : "alcance ligero"}</b></div>
          <div><span>Permiso</span><b>${dec.bloques.PERMISO_MXP ? "lo sacamos nosotros" : dec.bloques.PERMISO_CLIENTE ? "lo saca el cliente" : "no hace falta"}</b></div>
          <div><span>Ciudad</span><b>${esc(d.ciudad || "—")}</b></div>
          <div><span>Vale</span><b>${(() => { const n = Alcance.leerVence(d.vence, hoyFlorida()); const f = new Date(hoyFlorida().getTime()); f.setDate(f.getDate() + n);
            return `${n} días (hasta ${esc(f.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" }))})`; })()}</b></div>
        </div>
        <p class="alc-sub"><b>${L.items.length}</b> ${L.items.length === 1 ? "renglón" : "renglones"} · <b>${L.no_incluye.length}</b> ${L.no_incluye.length === 1 ? "exclusión propia" : "exclusiones propias"}</p>
        <ol class="alc-lista">${L.items.map(i => `<li>${esc(i.titulo)} <span class="alc-gris">(${i.detalles.length} ${i.detalles.length === 1 ? "detalle" : "detalles"})</span></li>`).join("")}</ol>
        <table class="alc-dinero">
          <tr><th>Precio base</th><th class="r">${usd(cta.base)}</th></tr>
          ${cta.hitos.map(h => `<tr><td>Pago ${h.n} — ${h.pct}%${h.es_deposito ? " (depósito)" : ""}</td><td class="r">${usd(h.centavos)}</td></tr>`).join("")}
          ${cta.addons.map(a => `<tr class="alc-addon"><td>Añadido ${a.letra} — ${esc(a.titulo)}</td><td class="r">${usd(a.centavos)}</td></tr>`).join("")}
          ${cta.addons.length ? `<tr class="alc-total"><td>Si el cliente lo toma todo</td><td class="r">${usd(cta.total_con_todo)}</td></tr>` : ""}
        </table>
        ${cta.addons.length ? `<p class="lev-nota">El cliente puede tomar los añadidos que quiera, sueltos o juntos. Los pagos se recalculan sobre lo que acepte.</p>` : ""}
        <p class="alc-sub">Cláusulas que van a salir:</p>
        <div class="alc-chips">${encendidas.map(k => `<span class="alc-chip" title="${esc(dec.motivos[k] || "va siempre")}">${esc(k.replace(/_/g, " "))}</span>`).join("")}</div>
        <p class="lev-nota">${esc(alcPorQue(dec))}</p>
      </div>
      <div class="alc-botones alc-cierra-dos">
        ${Alcance.pareceIngles(L) === false
          ? `<button class="accion" id="alc-redactar"${V.errores.length ? " disabled" : ""}>Pasarlo a inglés con el asistente</button>
             <button class="accion secundaria" id="alc-directo"${V.errores.length ? " disabled" : ""}>Usarlo tal cual</button>`
          : `<button class="accion" id="alc-directo"${V.errores.length ? " disabled" : ""}>Revisar y armar</button>`}
        <button class="accion secundaria" id="alc-guardar">${A.propuesta ? "Guardar los cambios" : "Guardar este alcance"}</button>
      </div>
      ${Alcance.pareceIngles(L) === false ? `<p class="lev-nota">Esto parece español y el contrato sale en inglés. Lo normal es pedirle al chat el alcance ya en inglés e importarlo; si no, el asistente lo pasa.</p>` : ""}
      </div></div>`;
    return salida;
  }

  function alcPorQue(dec) {
    const t = [];
    Object.entries(dec.motivos).forEach(([k, m]) => { if (dec.clausulas[k]) t.push(k.replace(/_/g, " ") + " " + m); });
    return t.length ? "Por qué: " + t.join(" · ") + "." : "Solo salen las cláusulas que van siempre.";
  }

  // ------------------------------------------------------ FICHA 2: la revisión
  function alcFichaRevision() {
    const A = alcActivo;
    if (!A.salida) return `<p class="lev-nota">Todavía no hay nada que revisar. Vuelve a la hoja y toca «Revisar y armar».</p>`;
    const L = A.leido, S = A.salida, directo = !!S.directo;
    const par = (clave, etiqueta, original, obj) => {
      if (!obj || !obj.en) return "";
      return `<div class="alc-par${directo ? " alc-par-solo" : ""}">
        <div class="alc-es"><span>${esc(etiqueta)}</span>${directo ? "" : esc(original || "")}</div>
        <div class="alc-en"><textarea data-campo="${esc(clave)}" rows="${Math.max(2, Math.ceil(obj.en.length / 90))}">${esc(obj.en)}</textarea></div>
      </div>`;
    };
    let s = directo
      ? `<p class="lev-nota">Esto es lo que va al contrato, trozo a trozo, tal como lo escribiste. Si cambias algo aquí, se guarda tal cual; si prefieres, vuelve a la hoja y corrígelo allí.</p>`
      : `<p class="lev-nota">A la izquierda lo que tú escribiste, a la derecha el inglés que sale al cliente.
      Cámbialo si hace falta: lo que corrijas se guarda tal cual.</p>`;
    s += par("proyecto_en", "Nombre del trabajo", L.datos.proyecto, S.proyecto_en);
    s += par("resumen_del_trabajo", "De qué va", L.datos.proyecto, S.resumen_del_trabajo);
    s += par("que_hay_hoy", "Hoy", L.hoy, S.que_hay_hoy);
    s += par("que_cambia", "Cambia", L.cambia, S.que_cambia);
    s += par("que_faltaba", "Falta", L.falta, S.que_faltaba);
    (S.items || []).forEach((it, k) => {
      const o = L.items[k] || {};
      s += par(`items.${k}.titulo`, `Renglón ${k + 1} — título`, o.titulo, it.titulo);
      s += par(`items.${k}.descripcion`, `Renglón ${k + 1} — detalles`, (o.detalles || []).join(" · "), it.descripcion);
    });
    (S.no_incluye || []).forEach((x, k) => {
      s += par(`no_incluye.${k}.titulo`, `No incluye ${k + 1}`, (L.no_incluye[k] || {}).texto, x.titulo);
      s += par(`no_incluye.${k}.texto`, "", (L.no_incluye[k] || {}).texto, x.texto);
    });
    (S.opciones || []).forEach((x, k) => {
      const o = L.opciones[k] || {};
      s += par(`opciones.${k}.titulo`, `Añadido ${String.fromCharCode(66 + k)} — $${Alcance.dinero(o.centavos || 0)}`, o.titulo, x.titulo);
      s += par(`opciones.${k}.descripcion`, `Añadido ${String.fromCharCode(66 + k)} — detalles`, (o.detalles || []).join(" · "), x.descripcion);
    });
    s += par("resumen_corrido", "Resumen del precio", "", S.resumen_corrido);
    s += par("areas_incluidas", "Áreas", (L.condiciones.areas || {}).valor, S.areas_incluidas);
    s += par("lo_que_no_tocas", "No tocamos", (L.condiciones.no_tocamos || {}).valor, S.lo_que_no_tocas);
    s += par("que_tiene_que_estar_listo", "Listo antes del rough", (L.condiciones.listo_rough || {}).valor, S.que_tiene_que_estar_listo);
    s += par("lista_de_fases", "Fases", (L.condiciones.fases || {}).valor, S.lista_de_fases);
    s += par("acceso", "Acceso", (L.condiciones.acceso || {}).valor, S.acceso);
    s += par("cuales_fixtures", "Fixtures del cliente", (L.condiciones.fixtures_cliente || {}).valor, S.cuales_fixtures);
    s += par("fixtures_mxp", "Fixtures nuestros", (L.condiciones.fixtures_mxp || {}).valor, S.fixtures_mxp);
    s += par("aberturas", "Aberturas", (L.condiciones.abrir || {}).valor, S.aberturas);

    if ((S.dudas || []).length)
      s += `<div class="alc-rojo"><b>El asistente tiene dudas:</b><ul>` +
        S.dudas.map(d => `<li>${esc(d.pregunta || d.que_dice || "")}</li>`).join("") + `</ul></div>`;
    if ((S.sugerencias || []).length)
      s += `<div class="alc-ambar"><b>Te avisa de esto:</b><ul>` +
        S.sugerencias.map(x => `<li>${esc(x.motivo || "")}</li>`).join("") + `</ul></div>`;

    s += `<div class="alc-botones">
      ${directo ? `<button class="accion secundaria" data-alcficha="0">Volver a la hoja</button>` : `<button class="accion secundaria" id="alc-reredactar">Redactar de nuevo</button>`}
      <button class="accion" id="alc-a-contrato">Armar el contrato</button></div>`;
    return s;
  }

  // ------------------------------------------------------ FICHA 3: el contrato
  function alcFichaContrato() {
    const A = alcActivo;
    if (!A.contrato) return `<p class="lev-nota">Toca «Armar el contrato» en la revisión.</p>`;
    const C = A.contrato;
    const nums = Object.entries(C.numeroClausulas || {});
    return `
      <div class="alc-entendi">
        <h3>Contrato armado</h3>
        <p class="alc-sub">${esc(C.archivo)}</p>
        ${C.problemas.length
          ? `<div class="alc-rojo"><b>No lo bajé: hay algo que revisar.</b><ul>${C.problemas.map(p => `<li>${esc(p.texto)}</li>`).join("")}</ul></div>`
          : `<p class="lev-nota">Pasó el repaso: no quedó ningún hueco y cada monto del papel es uno de los que calculé yo.</p>`}
        <p class="alc-sub">La sección 9 quedó así:</p>
        <div class="alc-chips">${nums.map(([k, n]) => `<span class="alc-chip">9.${n} ${esc(k.replace(/_/g, " "))}</span>`).join("")}</div>
        <p class="lev-nota">Si el cliente firmara hoy, podría cancelar hasta la medianoche del
          <b>${esc(fechaLarga(tresDiasHabiles(hoyFlorida())))}</b> (tres días hábiles, contando el sábado).
          El formulario con la fecha exacta lo genera el portal al firmar.</p>
      </div>
      <div class="alc-botones">
        ${C.problemas.length ? "" : `<button class="accion" id="alc-imprimir">Imprimir a PDF</button>
        <button class="accion secundaria" id="alc-bajar">Bajar el contrato (.html)</button>`}
        <button class="accion secundaria" id="alc-guardar">Guardar en la propuesta</button>
      </div>
      ${C.problemas.length ? "" : (() => {
        // ¿este alcance ya tiene su contrato en el portal esperando firma?
        const enPortal = A.subido || ((A.proyecto.docs || []).find(d => A.propuesta && d.propuestaId === A.propuesta.id && d.pideFirma && !d.firmadoEl) || null);
        if (enPortal) return `
      <div class="alc-entendi alc-listo" style="margin-top:.9rem">
        <h3>Ya está en el portal del cliente ✓</h3>
        <p class="lev-nota">${esc((enPortal.titulo || "El contrato"))} está subido y esperando la firma. Mándale el enlace al cliente:
          desde la ficha del proyecto, o con el botón de abajo.</p>
        <div class="alc-botones">
          <button class="accion" id="alc-enviar-email">Mandar por email</button>
          <button class="accion secundaria" id="alc-enviar-texto">Mandar por texto</button>
          <button class="accion secundaria" id="alc-copiar-enlace">Copiar el enlace</button>
        </div>
        <p class="lev-nota">${A.proyecto.cliente_email ? `Email del cliente: <b>${esc(A.proyecto.cliente_email)}</b>.` : "El proyecto no tiene email del cliente: al tocar «Mandar por email» te lo pido y lo guardo."}
          Se abre tu correo (o tus mensajes) con el texto y el enlace ya escritos; solo tienes que darle a enviar.</p>
        <div class="alc-botones alc-cierra-dos"><button class="accion" id="alc-terminado">Terminado — mandar la invitación e ir al proyecto</button></div>
        <p class="lev-nota">Al tocar «Terminado», la app le manda sola al cliente el email de invitación a su portal
          (con el enlace y las opciones que haya) desde info@mxpes.com, y lo apunta en el proyecto.
          ${A.proyecto.portal_invitado_el ? `Ya se le mandó una el ${esc(String(A.proyecto.portal_invitado_el).slice(0, 10))}; si tocas otra vez, se le manda de nuevo.` : ""}</p>
        <p class="lev-nota">Si cambiaste algo y quieres subir otra versión, dímelo: hay que retirar la anterior primero para que el cliente no vea dos.</p>
      </div>`;
        return `
      <div class="alc-entendi" style="margin-top:.9rem">
        <h3>Mandárselo al cliente</h3>
        <p class="lev-nota">1) Toca <b>Imprimir a PDF</b>: se abre el contrato con la ventana de imprimir.
          Elige <b>Guardar como PDF</b> (marca «Background graphics» si te lo ofrece) y guárdalo.
          2) Toca <b>Subir el PDF al portal</b> y elige ese archivo: queda enlazado a este alcance
          y le sale al cliente en su portal para elegirlo y firmarlo.</p>
        <div class="alc-botones">
          <input type="file" id="alc-pdf" accept="application/pdf" style="display:none">
          <button class="accion" id="alc-al-portal"${A.propuesta ? "" : " disabled"}>Subir el PDF al portal</button>
        </div>
        ${A.propuesta ? "" : `<p class="lev-nota">Guarda primero el alcance.</p>`}
      </div>`; })()}`;
  }

  // ------------------------------------------------------------- los engancHES
  function alcEnganchar() {
    document.querySelectorAll("[data-variante]").forEach(b =>
      b.addEventListener("click", () => {
        if (b.dataset.variante === "nueva") alcNuevaVariante();
        else alcCambiarVariante(b.dataset.variante);
      }));
    document.querySelectorAll("[data-alcficha]").forEach(b =>
      b.addEventListener("click", () => { alcRecoger(); alcFicha = Number(b.dataset.alcficha); pintarAlcance(); }));

    const caja = $("alc-texto");
    if (caja) caja.addEventListener("input", () => {
      alcActivo.texto = caja.value;
      alcGuardarLocal(alcActivo.proyecto.id, caja.value);
    });

    const bCopiar = $("alc-copiar-formato");
    if (bCopiar) bCopiar.addEventListener("click", async () => {
      try { await navigator.clipboard.writeText(ALC_FORMATO); avisar("Formato copiado ✓ — pégalo en Notas"); }
      catch { if (caja && !caja.value.trim()) { caja.value = ALC_FORMATO; alcActivo.texto = ALC_FORMATO; }
              avisar("Te lo puse en el cuadro"); }
    });

    // Importar un archivo: abre los archivos del teléfono y lo mete en el cuadro
    const bImp = $("alc-importar"), fArch = $("alc-archivo");
    if (bImp && fArch) {
      bImp.addEventListener("click", () => fArch.click());
      fArch.addEventListener("change", () => {
        const f = fArch.files && fArch.files[0];
        if (f) alcCargarArchivo(f);
        fArch.value = "";
      });
    }
    // …o se suelta encima del cuadro
    if (caja) {
      ["dragenter", "dragover"].forEach(ev => caja.addEventListener(ev, e => {
        e.preventDefault(); caja.classList.add("alc-soltar");
      }));
      ["dragleave", "drop"].forEach(ev => caja.addEventListener(ev, e => {
        e.preventDefault(); caja.classList.remove("alc-soltar");
      }));
      caja.addEventListener("drop", e => {
        const f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
        if (f) alcCargarArchivo(f);
      });
    }

    const bOrdenar = $("alc-ordenar");
    if (bOrdenar) bOrdenar.addEventListener("click", alcOrdenar);
    const bLeer = $("alc-leer");
    if (bLeer) bLeer.addEventListener("click", alcLeer);

    document.querySelectorAll("[data-preg]").forEach(el => {
      const guardar = valor => {
        alcActivo.respuestas[el.dataset.preg] = valor;
        alcAplicarRespuestas();
        pintarAlcance();
      };
      if (el.tagName === "INPUT") el.addEventListener("change", () => guardar(el.value));
      else el.addEventListener("click", () => guardar(el.dataset.val));
    });

    document.querySelectorAll("[data-ira]").forEach(b => b.addEventListener("click", () => alcIrALinea(b.dataset.ira)));
    document.querySelectorAll("[data-fix]").forEach(b => b.addEventListener("click", () => {
      const a = alcArreglos[b.dataset.fix]; if (!a) return;
      const inp = document.querySelector(`[data-fix-in="${b.dataset.fix}"]`);
      alcArreglar(a, inp ? inp.value : undefined);
    }));
    const bTodo = $("alc-arreglar-todo");
    if (bTodo) bTodo.addEventListener("click", () => {
      const A = alcActivo;
      const r = Alcance.arreglarTodo(A.texto, { perdonadas: A.perdonadas || [] });
      if (!r.hechos.length) { avisar("No había nada que pudiera arreglar solo", true); return; }
      A.texto = r.texto; alcGuardarLocal(A.proyecto.id, A.texto);
      A.arreglados = [...(A.arreglados || []), ...r.hechos];
      alcCalcular(); pintarAlcance();
      avisar(`Arreglé ${r.hechos.length} ${r.hechos.length === 1 ? "cosa" : "cosas"} ✓`);
    });
    const bRed = $("alc-redactar");
    if (bRed) bRed.addEventListener("click", alcRedactar);
    const bDir = $("alc-directo");
    if (bDir) bDir.addEventListener("click", alcDirecto);
    const bRe = $("alc-reredactar");
    if (bRe) bRe.addEventListener("click", () => { if (confirm("Se pierden las correcciones que hiciste a mano. ¿Sigo?")) alcRedactar(); });
    const bArmar = $("alc-a-contrato");
    if (bArmar) bArmar.addEventListener("click", alcArmar);
    const bBajar = $("alc-bajar");
    if (bBajar) bBajar.addEventListener("click", alcBajar);
    const bImpr = $("alc-imprimir");
    if (bImpr) bImpr.addEventListener("click", alcImprimir);
    // Mandarle el portal al cliente: se abre el correo o los mensajes con todo escrito
    const alcMensaje = async () => {
      const llave = await DB.llavePortal(alcActivo.proyecto.id);
      const url = `https://edgararboleya-rgb.github.io/max-power-panel/cliente.html?t=${llave}`;
      const nombre = String(alcActivo.leido && alcActivo.leido.datos.cliente || alcActivo.proyecto.cliente || "").split(/\s+/)[0] || "";
      const cuantos = (alcActivo.variantes || []).filter(v => v.alcance_estado === "armado" || v.estado === "enviada").length;
      const cuerpo = `Hi ${nombre},\n\nYour proposal from Max Power Electrical Solutions is ready in your client portal:\n${url}\n\n` +
        (cuantos > 1 ? `There are ${cuantos} scope options; pick the one you want, review it and sign at the bottom.` : `Open the link, review the Scope of Work and sign at the bottom.`) +
        `\nAfter signing you have three business days to cancel at no cost.\n\nIf you have any questions, call or text me at (305) 967-9311.\n\nEdgar Arboleya\nMax Power Electrical Solutions, Inc.\nFL EC13016045`;
      return { url, asunto: `Your proposal — ${alcActivo.proyecto.nombre}`, cuerpo };
    };
    const bMail = $("alc-enviar-email");
    if (bMail) bMail.addEventListener("click", async () => {
      try {
        let email = alcActivo.proyecto.cliente_email || "";
        if (!email) {
          const nuevo = prompt("Email del cliente:", "");
          if (nuevo === null) return;
          email = nuevo.trim();
          if (email) { try { await DB.cambiarProyecto(alcActivo.proyecto.id, { cliente_email: email }); alcActivo.proyecto.cliente_email = email; } catch { /* se manda igual */ } }
        }
        const m = await alcMensaje();
        location.href = `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(m.asunto)}&body=${encodeURIComponent(m.cuerpo)}`;
        avisar("Se abre tu correo con el mensaje listo: dale a enviar");
      } catch (e) { avisar("No pude preparar el email: " + e.message, true); }
    });
    const bSms = $("alc-enviar-texto");
    if (bSms) bSms.addEventListener("click", async () => {
      try {
        const tel = String(alcActivo.proyecto.cliente_tel || (String(alcActivo.proyecto.cliente || "").match(/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/) || [""])[0]).replace(/[^\d+]/g, "");
        const m = await alcMensaje();
        const corto = `Hi ${m.cuerpo.split(",")[0].replace(/^Hi\s*/, "")}, your proposal from Max Power is ready in your client portal: ${m.url} — open it, review the scope and sign at the bottom. Edgar, (305) 967-9311`;
        location.href = `sms:${tel}${/iPhone|iPad/.test(navigator.userAgent) ? "&" : "?"}body=${encodeURIComponent(corto)}`;
        avisar(tel ? "Se abren tus mensajes con el texto listo" : "Se abren tus mensajes: pon el número del cliente");
      } catch (e) { avisar("No pude preparar el texto: " + e.message, true); }
    });
    const bFin = $("alc-terminado");
    if (bFin) bFin.addEventListener("click", async () => {
      const id = alcActivo.proyecto.id;
      let email = alcActivo.proyecto.cliente_email || "";
      if (!email) {
        const nuevo = prompt("Email del cliente para mandarle la invitación al portal:", "");
        if (nuevo === null) return;
        email = nuevo.trim();
        if (email) { try { await DB.cambiarProyecto(id, { cliente_email: email }); alcActivo.proyecto.cliente_email = email; } catch { /* se manda igual */ } }
      }
      bFin.disabled = true; bFin.textContent = "Mandando la invitación…";
      let mensaje = "Listo ✓ — el contrato está en el portal del cliente";
      if (email) {
        try {
          const r = await DB.pedirCorreo("invitar_portal", { proyecto_id: id, para: email });
          mensaje = `Invitación enviada a ${r.para} ✓`;
        } catch (e) {
          // el correo no salió: se dice claro, pero el contrato sigue en el portal
          alert("El contrato está en el portal, pero el email no salió:\n" + e.message + "\n\nPuedes mandarle el enlace con «Mandar por email» o «Copiar el enlace».");
          bFin.disabled = false; bFin.textContent = "Terminado — mandar la invitación e ir al proyecto";
          return;
        }
      }
      try { await recargar(id); } catch { /* con lo que hay */ }
      alcActivo = null;
      irDetalle(id);
      avisar(mensaje);
    });
    const bEnlace = $("alc-copiar-enlace");
    if (bEnlace) bEnlace.addEventListener("click", async () => {
      try { const llave = await DB.llavePortal(alcActivo.proyecto.id);
            const url = `https://edgararboleya-rgb.github.io/max-power-panel/cliente.html?t=${llave}`;
            try { await navigator.clipboard.writeText(url); avisar("Enlace copiado ✓ — pégaselo al cliente"); }
            catch { avisar("El enlace del cliente: " + url); } }
      catch (e) { avisar("No pude sacar el enlace: " + e.message, true); }
    });
    const bGuardar = $("alc-guardar");
    if (bGuardar) bGuardar.addEventListener("click", alcGuardarNube);
    const bPortal = $("alc-al-portal");
    if (bPortal) bPortal.addEventListener("click", () => $("alc-pdf").click());
    const inPdf = $("alc-pdf");
    if (inPdf) inPdf.addEventListener("change", () => { if (inPdf.files[0]) alcSubirAlPortal(inPdf.files[0]); });
  }

  // Lleva el cuadro al renglón N y lo deja seleccionado, para que Edgar vea
  // exactamente de qué línea le estamos hablando.
  let alcEspejo = null;
  function alcIrALinea(n) {
    const caja = $("alc-texto"); if (!caja) return;
    const lineas = caja.value.replace(/\r/g, "").split("\n");
    const i = Math.max(0, Math.min(lineas.length - 1, Number(n) - 1));
    let ini = 0; for (let k = 0; k < i; k++) ini += lineas[k].length + 1;
    const fin = ini + lineas[i].length;
    // Un espejo invisible con la misma letra y el mismo ancho mide a qué altura
    // cae el renglón aunque las líneas largas se partan en dos.
    if (!alcEspejo) { alcEspejo = document.createElement("div"); alcEspejo.setAttribute("aria-hidden", "true"); document.body.appendChild(alcEspejo); }
    const cs = getComputedStyle(caja);
    Object.assign(alcEspejo.style, { position: "absolute", visibility: "hidden", left: "-9999px", top: "0",
      whiteSpace: "pre-wrap", wordWrap: "break-word", overflowWrap: "break-word", boxSizing: cs.boxSizing,
      width: caja.clientWidth + "px", padding: cs.padding, border: "0", font: cs.font, lineHeight: cs.lineHeight, letterSpacing: cs.letterSpacing });
    alcEspejo.textContent = lineas.slice(0, i).join("\n") + (i ? "\n" : "") + "x";
    const arriba = alcEspejo.offsetHeight - parseFloat(cs.lineHeight || "20");
    caja.scrollTop = Math.max(0, arriba - caja.clientHeight / 3);
    caja.focus({ preventScroll: true });
    caja.setSelectionRange(ini, fin);
    // en el teléfono el cuadro puede haber quedado arriba: traerlo a la vista
    const r = caja.getBoundingClientRect();
    if (r.top < 0 || r.bottom > innerHeight) caja.scrollIntoView({ block: "center", behavior: "smooth" });
  }

  // Lee el archivo que Edgar escogió y lo pone en el cuadro. Solo texto: si es
  // un PDF o un Word, se lo decimos en llano en vez de meter caracteres raros.
  function alcCargarArchivo(f) {
    const nombre = String(f.name || "");
    if (/\.(pdf|docx?|pages|rtf|odt)$/i.test(nombre)) {
      avisar("Ese archivo no es de texto. Guárdalo como .txt o .md y vuelve a intentarlo.", true);
      return;
    }
    if (f.size > 400000) { avisar("Ese archivo es muy grande para una hoja de alcance", true); return; }
    const lector = new FileReader();
    lector.onload = () => {
      const txt = String(lector.result || "").replace(/\r/g, "");
      if (!txt.trim()) { avisar("El archivo está vacío", true); return; }
      const caja = $("alc-texto");
      const habia = caja && caja.value.trim();
      if (habia && !confirm("Ya hay algo escrito en el cuadro. ¿Lo reemplazo con el archivo?")) return;
      alcActivo.texto = txt;
      if (caja) caja.value = txt;
      alcGuardarLocal(alcActivo.proyecto.id, txt);
      alcActivo.leido = null; alcActivo.respuestas = {};
      pintarAlcance();
      avisar(`Cargado «${nombre}» ✓ — ahora toca Leer`);
    };
    lector.onerror = () => avisar("No pude abrir ese archivo", true);
    lector.readAsText(f, "utf-8");
  }

  // Recoge las correcciones en inglés antes de cambiar de ficha
  function alcRecoger() {
    if (alcFicha !== 1 || !alcActivo || !alcActivo.salida) return;
    document.querySelectorAll("[data-campo]").forEach(t => {
      const partes = t.dataset.campo.split(".");
      let obj = alcActivo.salida;
      for (let i = 0; i < partes.length - 1; i++) obj = obj[partes[i]];
      const ultimo = partes[partes.length - 1];
      if (obj && obj[ultimo]) obj[ultimo].en = t.value;
    });
  }

  // Las respuestas de los botones se escriben EN LA HOJA, a la vista de Edgar
  function alcAplicarRespuestas() {
    const A = alcActivo, R = A.respuestas;
    let txt = A.texto;
    const ponDato = (clave, valor) => {
      const re = new RegExp("^\\s*" + clave + "\\s*:.*$", "im");
      if (re.test(txt)) txt = txt.replace(re, clave + ": " + valor);
      else txt = clave + ": " + valor + "\n" + txt;
    };
    const ponCond = (clave, valor) => {
      const re = new RegExp("^\\s*" + clave + "\\s*:.*$", "im");
      if (re.test(txt)) txt = txt.replace(re, clave + ": " + valor);
      else if (/^\s*Condiciones\s*$/im.test(txt)) txt = txt.replace(/^(\s*Condiciones\s*)$/im, "$1\n" + clave + ": " + valor);
      else txt += "\n\nCondiciones\n" + clave + ": " + valor;
    };
    if (R.fotos_panel) ponCond("Fotos del panel", R.fotos_panel);
    if (R.circuitos_exist) ponCond("Circuitos existentes", R.circuitos_exist);
    if (R.ciudad && R.ciudad !== "Otra") ponDato("Ciudad", R.ciudad);
    if (R.pagos) { try { ponDato("Pagos", JSON.parse(R.pagos).join("/")); } catch { ponDato("Pagos", R.pagos); } }
    if (R.cliente) ponDato("Cliente", R.cliente);
    if (R.direccion) ponDato("Dirección", R.direccion);
    if (R.dos_firmas === "Sí, firman las dos") {
      const m = txt.match(/^\s*Cliente\s*:\s*(.+)$/im);
      if (m) {
        const partes = m[1].split(/\s+(?:y|&|and)\s+/i);
        if (partes.length === 2) { ponDato("Cliente", partes[0].trim()); ponDato("Segundo firmante", partes[1].trim()); }
      }
    }
    if (R.no_excluir_panel === "panel" || R.no_excluir_afci === "afci") {
      const quiere = [R.no_excluir_panel, R.no_excluir_afci].filter(x => x && x !== "null");
      const m = txt.match(/^\s*No excluir\s*:\s*(.*)$/im);
      const ya = m ? m[1].split(",").map(s => s.trim()).filter(Boolean) : [];
      ponCond("No excluir", [...new Set([...ya, ...quiere])].join(", "));
    }
    if (txt !== A.texto) { A.texto = txt; alcGuardarLocal(A.proyecto.id, txt); }
    alcCalcular();
  }

  // Un arreglo concreto, con el valor que Edgar haya escrito si hacía falta
  function alcArreglar(a, valor) {
    const A = alcActivo;
    const r = Alcance.aplicarArreglo(A.texto, a, valor);
    if (r.error) { avisar(r.error, true); return; }
    if (r.perdona) { A.perdonadas = [...(A.perdonadas || []), r.perdona]; alcPerdonLocal(A.proyecto.id, A.perdonadas); }
    A.texto = r.texto; alcGuardarLocal(A.proyecto.id, A.texto);
    A.arreglados = [...(A.arreglados || []), r.explicacion];
    alcCalcular(); pintarAlcance();
  }

  function alcCalcular() {
    const A = alcActivo;
    A.leido = Alcance.leerAlcance(A.texto, { perdonadas: A.perdonadas || [] });
    A.validado = Alcance.validarAlcance(A.leido);
    A.cuenta = Alcance.cuentas(A.leido);
    A.decision = Alcance.decidirInterruptores(A.leido, A.cuenta);
  }

  function alcLeer() {
    const A = alcActivo;
    A.texto = $("alc-texto").value;
    alcGuardarLocal(A.proyecto.id, A.texto);
    if (!A.texto.trim()) { avisar("Pega primero la hoja", true); return; }
    A.respuestas = {}; A.arreglados = [];
    A.perdonadas = A.perdonadas || [];
    alcCalcular();
    pintarAlcance();
    if (!A.validado.errores.length && !A.validado.preguntas.length) avisar("Leído ✓ — revisa el dinero y redacta");
  }

  async function alcOrdenar() {
    const A = alcActivo;
    A.texto = $("alc-texto").value;
    if (!A.texto.trim()) { avisar("Pega primero el texto", true); return; }
    const btn = $("alc-ordenar");
    btn.disabled = true; btn.textContent = "Ordenando…";
    try {
      const r = await DB.pedirAlCerebro("ordenar", { texto: A.texto });
      if (r && r.error) throw new Error(alcErrorEnLlano(r));
      if (!r || !r.hoja) throw new Error("El asistente no devolvió la hoja");
      A.texto = r.hoja;
      alcGuardarLocal(A.proyecto.id, A.texto);
      alcCalcular();
      pintarAlcance();
      avisar("Ordenado ✓ — míralo antes de seguir" + ((r.perdidas || []).length ? `; ${r.perdidas.length} cosas no supo colocarlas` : ""));
    } catch (e) {
      avisar(e.message, true);
      btn.disabled = false; btn.textContent = "Ordenar";
    }
  }

  async function alcRedactar() {
    const A = alcActivo;
    alcCalcular();
    if (A.validado.errores.length) { avisar("Arregla primero lo que está en rojo", true); return; }
    const enc = Alcance.prepararEncargo(A.leido, A.decision);
    if (!enc.limpio) { avisar("Hay dinero en el texto que va al asistente. No lo mando.", true); return; }
    const btn = $("alc-redactar");
    if (btn) { btn.disabled = true; btn.textContent = "Redactando… no cierres"; }
    try {
      const r = await DB.pedirAlCerebro("alcance", { encargo: enc.texto });
      if (r && r.error) throw new Error(alcErrorEnLlano(r));
      const S = r && r.salida;
      if (!S) throw new Error("El asistente no devolvió la redacción");
      if ((r.rechazados || []).length)
        avisar(`El asistente escribió algo prohibido en ${r.rechazados.length} ${r.rechazados.length === 1 ? "trozo" : "trozos"}; míralos en rojo`, true);
      const rev = Alcance.validarSalida(A.leido, S);
      if (!rev.sirve) { avisar("El asistente devolvió algo que no puedo usar: " + rev.rojos[0].texto, true);
                        if (btn) { btn.disabled = false; btn.textContent = "Redactar en inglés"; } return; }
      A.salida = S; A.uso = r.uso || null;
      A.huella = await alcHuella(A.texto);
      alcFicha = 1;
      pintarAlcance();
      avisar("Redactado ✓ — revísalo trozo a trozo");
    } catch (e) {
      avisar(e.message, true);
      if (btn) { btn.disabled = false; btn.textContent = "Redactar en inglés"; }
    }
  }

  // El camino corto: la hoja ya viene en inglés y pasa al contrato tal cual,
  // sin asistente y sin esperar. Lo que Edgar corrija en la revisión se queda.
  async function alcDirecto() {
    const A = alcActivo;
    A.texto = $("alc-texto") ? $("alc-texto").value : A.texto;
    alcCalcular();
    if (A.validado.errores.length) { avisar("Arregla primero lo que está en rojo", true); return; }
    const S = Alcance.redactarDirecto(A.leido);
    const rev = Alcance.validarSalida(A.leido, S);
    if (!rev.sirve) { avisar(rev.rojos[0].texto, true); return; }
    A.salida = S; A.uso = null;
    A.huella = await alcHuella(A.texto);
    alcFicha = 1;
    pintarAlcance();
    avisar("Listo ✓ — revísalo y arma el contrato");
  }

  // Lo que devuelve el cerebro cuando algo no va, dicho en llano
  function alcErrorEnLlano(r) {
    const e = String(r.error || "");
    if (e === "no_autorizado") return "Esto solo lo puede usar el dueño";
    if (e === "sin_llave") return "Al asistente le falta su llave en la nube";
    if (e === "dinero_en_el_encargo") return "Hay dinero en el texto que iba al asistente; no se mandó";
    if (e === "monto_inventado") return "El asistente metió un monto que no estaba en tu texto. No lo acepto: " + (r.detalle || "");
    if (e === "sin_hoja" || e === "sin_salida") return "El asistente no devolvió nada útil. Vuelve a intentarlo";
    if (e === "sin_texto" || e === "sin_encargo") return "No hay texto que mandar";
    return "El asistente falló: " + (r.detalle || e);
  }

  async function alcHuella(txt) {
    try {
      const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(txt));
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, "0")).join("");
    } catch { return null; }
  }

  async function alcArmar() {
    const A = alcActivo;
    alcRecoger();
    alcCalcular();
    try {
      if (!alcPlantilla) { avisar("Bajando la plantilla…"); alcPlantilla = await DB.plantillaSOW(); }
      if (!Alcance.marcasEmparejadas(alcPlantilla)) throw new Error("La plantilla de la app tiene una marca coja");
      const T = Alcance.armarTodo(A.leido, A.salida, {
        fecha: hoyFlorida(), proyecto_id: A.proyecto.id,
        direccion: A.proyecto.direccion, nec: A.leido.codigo });
      const out = Alcance.rellenarPlantilla(alcPlantilla, {
        bloques: T.decision.bloques, clausulas: T.decision.clausulas, huecos: T.huecos,
        items: T.items, no_incluye: T.no_incluye, addons: T.addons, hitos: T.hitos });
      // un $ que Edgar explicó y dejó adrede no es un monto inventado
      const perdonados = (A.perdonadas || []).flatMap(x => (String((x && x.texto) || x || "").match(/\$\s?\d[\d,]*(?:\.\d{2})?/g) || []).map(m => m.replace(/[$\s]/g, "")));
      const B = Alcance.barridoFinal(out.html, [...T.montosPermitidos, ...perdonados]);
      A.contrato = { html: out.html, numeroClausulas: out.numeroClausulas,
                     archivo: T.archivo, problemas: B.problemas, cuenta: T.cuenta };
      alcFicha = 2;
      pintarAlcance();
      if (B.problemas.length) avisar("Armado, pero hay algo que revisar", true);
      else avisar("Contrato armado ✓");
    } catch (e) { avisar(e.message, true); }
  }

  // Abre el contrato en una pestaña y lanza la ventana de imprimir: con «Guardar
  // como PDF» sale el archivo listo para el portal, sin bajar ni abrir nada.
  function alcImprimir() {
    const C = alcActivo.contrato;
    const nombre = String(C.archivo || "contrato").replace(/\.html?$/i, "");
    // el título manda el nombre que el navegador propone al guardar el PDF
    const html = /<title>[^<]*<\/title>/i.test(C.html)
      ? C.html.replace(/<title>[^<]*<\/title>/i, `<title>${esc(nombre)}</title>`)
      : C.html.replace(/<head[^>]*>/i, m => `${m}<title>${esc(nombre)}</title>`);
    const w = window.open("", "_blank");
    if (!w) { avisar("El navegador bloqueó la ventana. Permite ventanas emergentes para la app y vuelve a tocar.", true); return; }
    w.document.open(); w.document.write(html); w.document.close();
    const imprimir = () => { try { w.focus(); w.print(); } catch { /* nada */ } };
    if (w.document.readyState === "complete") setTimeout(imprimir, 400);
    else w.addEventListener("load", () => setTimeout(imprimir, 400));
    avisar("Elige «Guardar como PDF» y guárdalo; después súbelo al portal");
  }

  function alcBajar() {
    const C = alcActivo.contrato;
    const blob = new Blob([C.html], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = C.archivo;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
    avisar("Bajado ✓ — pásalo a PDF y súbelo al portal");
  }

  // El contrato en PDF al portal del cliente: se guarda en el almacén, se
  // anota como documento que pide firma y se enlaza a ESTE alcance, para que
  // el portal sepa qué SOW es y no deje firmar el que no eligió.
  async function alcSubirAlPortal(archivo) {
    const A = alcActivo;
    if (!A.propuesta) { avisar("Guarda primero el alcance", true); return; }
    const btn = $("alc-al-portal");
    btn.disabled = true; btn.textContent = "Subiendo…";
    try {
      const ruta = await DB.subirDocumento(A.proyecto.id, archivo, "docs");
      const letra = String.fromCharCode(65 + Math.max(0, (A.variantes || []).findIndex(v => v.id === A.propuesta.id)));
      const titulo = `SOW ${letra} — ${(A.leido && A.leido.datos.proyecto) || A.proyecto.nombre}`.slice(0, 90);
      await DB.crearDocumento({
        proyecto_id: A.proyecto.id, clase: "doc", titulo, ruta,
        portal: true, pide_firma: true, pide_aprobacion: false,
        propuesta_id: A.propuesta.id,
        valida_hasta: A.propuesta.valida_hasta || null
      });
      if (A.propuesta.estado === "borrador")
        await DB.cambiarPropuesta(A.propuesta.id, { estado: "enviada" });
      const llave = await DB.llavePortal(A.proyecto.id);
      try { propData = await DB.cargarPropuestas(); } catch { /* se queda la de antes */ }
      A.variantes = alcVariantesDe(A.proyecto.id);
      const fresca = A.variantes.find(v => v.id === A.propuesta.id);
      if (fresca) A.propuesta = fresca;
      A.subido = { titulo };
      pintarAlcance();
      const url = `https://edgararboleya-rgb.github.io/max-power-panel/cliente.html?t=${llave}`;
      try { await navigator.clipboard.writeText(url); avisar("Subido ✓ — el enlace del cliente quedó copiado"); }
      catch { avisar("Subido ✓ — el enlace del cliente: " + url); }
    } catch (e) {
      if (e.crudo && /23505|ux_un_contrato_vivo/.test(String(e.crudo)) || /ya estaba guardado/.test(e.message)) {
        A.subido = { titulo: "El contrato" }; pintarAlcance();
        avisar("Este alcance ya tiene su contrato en el portal esperando firma. No hace falta subirlo otra vez.", true); return;
      }
      avisar("No se pudo subir: " + e.message, true);
      btn.disabled = false; btn.textContent = "Subir el PDF al portal";
    }
  }

  async function alcGuardarNube() {
    const A = alcActivo;
    const btn = $("alc-guardar");
    btn.disabled = true; btn.textContent = "Guardando…";
    try {
      alcRecoger();
      alcCalcular();
      const cta = A.cuenta, dec = A.decision, L = A.leido, d = L.datos;
      const campos = {
        alcance_md: A.texto,
        alcance_huella: A.huella || null,
        alcance_leido: { datos: d, items: L.items, no_incluye: L.no_incluye,
                         condiciones: L.condiciones, codigo: L.codigo,
                         precio: cta.base, pcts: cta.pcts },
        alcance_en: A.salida || null,
        alcance_decisiones: { bloques: dec.bloques, clausulas: dec.clausulas, nec: L.codigo, perdonadas: A.perdonadas || [] },
        alcance_estado: A.contrato ? "armado" : (A.salida ? "redactado" : "leido"),
        reparto_pct: cta.pcts,
        uso_modelo: A.uso || null
      };
      if (A.contrato) { campos.armado_el = new Date().toISOString(); campos.archivo = A.contrato.archivo; }

      // El email y el teléfono del cliente, si vienen en la hoja, se guardan en el
      // proyecto desde el principio (sirven para mandarle el portal y su copia firmada)
      try {
        const cambiosProy = {};
        if (d.email && /@/.test(d.email) && !A.proyecto.cliente_email) cambiosProy.cliente_email = d.email.trim();
        if (d.telefono && /\d{7}/.test(d.telefono.replace(/\D/g, "")) && !A.proyecto.cliente_tel) cambiosProy.cliente_tel = d.telefono.trim();
        if (Object.keys(cambiosProy).length) { await DB.cambiarProyecto(A.proyecto.id, cambiosProy); Object.assign(A.proyecto, cambiosProy); }
      } catch { /* no frena el guardado del alcance */ }
      if (A.propuesta) {
        await DB.guardarAlcance(A.propuesta.id, campos);
      } else {
        const hasta = new Date(hoyFlorida().getTime());
        hasta.setDate(hasta.getDate() + Alcance.leerVence(d.vence, hoyFlorida()));
        const creada = await DB.crearPropuesta({
          proyecto_id: A.proyecto.id, estado: "borrador",
          valida_hasta: hasta.toISOString().slice(0, 10), ...campos });
        A.propuesta = creada[0];
        const filas = [{
          propuesta_id: A.propuesta.id, letra: "A", es_addon: false,
          titulo: (A.salida && A.salida.proyecto_en && A.salida.proyecto_en.en) || d.proyecto || "Base",
          alcance: L.items.map(i => ({ titulo: i.titulo, detalles: i.detalles })),
          no_incluye: L.no_incluye.map(x => x.texto),
          precio: cta.base / 100, orden: 0,
          hitos_plan: cta.hitos.map(h => ({ titulo: `Pago ${h.n}`, monto: h.centavos / 100,
                                            pct: h.pct, es_deposito: h.es_deposito }))
        }].concat(cta.addons.map((a, k) => ({
          propuesta_id: A.propuesta.id, letra: a.letra, es_addon: true,
          titulo: ((A.salida && A.salida.opciones && A.salida.opciones[k] && A.salida.opciones[k].titulo &&
                    A.salida.opciones[k].titulo.en) || a.titulo),
          alcance: (L.opciones[k] || {}).detalles || [], no_incluye: [],
          precio: a.centavos / 100, hitos_plan: [], orden: k + 1
        })));
        await DB.crearOpciones(filas);
        const cambios = {};
        if (d.cliente && !A.proyecto.cliente) cambios.cliente = d.cliente;
        if (Object.keys(cambios).length) await DB.cambiarProyecto(A.proyecto.id, cambios);
      }
      // El número de propuesta y el valor del contrato los pone el alcance en la
      // ficha del proyecto, para que Edgar no los teclee dos veces.
      try {
        if (A.contrato && (!A.proyecto.ref || /por definir/i.test(A.proyecto.ref))) {
          const ref = A.contrato.archivo.replace(/\.html$/i, "");
          await DB.cambiarProyecto(A.proyecto.id, { ref }); A.proyecto.ref = ref;
        }
        if (!(Number(A.proyecto.contrato) > 0)) { await DB.ponerContrato(A.proyecto.id, cta.base / 100); A.proyecto.contrato = cta.base / 100; }
      } catch { /* la propuesta ya quedó guardada; la ficha se cuadra en la próxima recarga */ }
      // Las propuestas se recargan para que la barra de arriba enseñe la
      // variante nueva (o el precio nuevo de la que se acaba de guardar)
      try { propData = await DB.cargarPropuestas(); } catch { /* se queda la de antes */ }
      A.variantes = alcVariantesDe(A.proyecto.id);
      if (A.propuesta) {
        const fresca = A.variantes.find(p => p.id === A.propuesta.id);
        if (fresca) A.propuesta = fresca;
      }
      pintarAlcance();
      avisar(A.variantes.length > 1
        ? `Guardado ✓ — este proyecto tiene ${A.variantes.length} alcances`
        : "Guardado en la propuesta ✓");
    } catch (err) {
      avisar("No se pudo guardar: " + err.message, true);
      btn.disabled = false; btn.textContent = "Guardar en la propuesta";
    }
  }

  // ============================================================
  // 📋 EL LEVANTAMIENTO EN SITIO — solo el dueño
  //
  // Seis fichas: la casa · el panel · los cuartos · las condiciones ·
  // las medidas · el resumen. Se puede salir y volver: lo escrito se
  // guarda solo, primero en el teléfono y después en la nube.
  //
  // Nada de esto lo ve el equipo de campo: las tres tablas de la base
  // llevan el candado es_dueno(), y además la pantalla solo se abre
  // con usuario.finanzas.
  // ============================================================
  let levData = null;   // { levantamientos, cuartos } de la nube
  let levActivo = null; // el levantamiento abierto, en memoria
  let levFicha = 0;     // 0..5
  let levGuardando = false, levSucio = false, levTimer = null, levSinSenal = false;

  const LEV_FICHAS = [
    { etiqueta: "La casa" }, { etiqueta: "Panel" }, { etiqueta: "Cuartos" },
    { etiqueta: "Se ve" }, { etiqueta: "Medidas" }, { etiqueta: "Resumen" }
  ];


  // ---------- Iconos de línea (mismo trazo que las losetas del inicio) ----------
  const LEV_SVG = {
    // cuartos
    cocina:    '<path d="M4 10h16"/><path d="M6 10V6.5A2.5 2.5 0 0 1 8.5 4h7A2.5 2.5 0 0 1 18 6.5V10"/><path d="M5 10v7a3 3 0 0 0 3 3h8a3 3 0 0 0 3-3v-7"/><path d="M10 14v2M14 14v2"/>',
    bano:      '<path d="M8 4a3 3 0 0 1 6 0v2"/><path d="M14 6h1.5a1 1 0 0 1 0 2H12a1 1 0 0 1 0-2z"/><path d="M13 11v1.5M15.5 10.5l.8 1.3M10.5 10.5l-.8 1.3"/><path d="M4 16h16M6 16l1 4h10l1-4"/>',
    recamara:  '<path d="M3 18v-8M3 13h18v5"/><path d="M3 13V9a2 2 0 0 1 2-2h5a3 3 0 0 1 3 3v3"/><circle cx="6.5" cy="10" r="1.2"/>',
    sala:      '<path d="M5 11V8a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v3"/><path d="M3 13a2 2 0 0 1 4 0v1h10v-1a2 2 0 0 1 4 0v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M6 18v2M18 18v2"/>',
    pasillo:   '<rect x="6" y="3.5" width="12" height="17" rx="1.5"/><path d="M14.5 12h.01"/><path d="M3 20.5h18"/>',
    exterior:  '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4"/>',
    garaje:    '<path d="M5 13.5 6.6 9a2 2 0 0 1 1.9-1.4h7a2 2 0 0 1 1.9 1.4l1.6 4.5"/><rect x="3.5" y="13.5" width="17" height="4.5" rx="1.6"/><circle cx="7.8" cy="20" r="1.3"/><circle cx="16.2" cy="20" r="1.3"/>',
    otro:      '<path d="M3.5 8 12 3.5 20.5 8 12 12.5z"/><path d="M3.5 8v8L12 20.5l8.5-4.5V8"/><path d="M12 12.5v8"/>',
    // lo que se cuenta
    enchufe:   '<rect x="5.5" y="3.5" width="13" height="17" rx="3.5"/><path d="M9.8 9v2.6M14.2 9v2.6"/><path d="M12 16.2v.01"/>',
    gfci:      '<rect x="5.5" y="3.5" width="13" height="17" rx="3.5"/><path d="M9.8 8v2M14.2 8v2"/><path d="M9.5 14.5h5v2.5h-5z"/>',
    estufa:    '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1.8"/><circle cx="15" cy="9" r="1.8"/><circle cx="9" cy="15" r="1.8"/><circle cx="15" cy="15" r="1.8"/>',
    secadora:  '<rect x="4.5" y="3.5" width="15" height="17" rx="3"/><circle cx="12" cy="13" r="4.5"/><path d="M7.5 6.5h.01M10 6.5h.01"/>',
    interruptor:'<rect x="7" y="3.5" width="10" height="17" rx="2.5"/><rect x="10.2" y="8" width="3.6" height="5" rx="1"/>',
    tresvias:  '<rect x="7" y="3.5" width="10" height="17" rx="2.5"/><path d="M12 8.5v3M12 15.2v.01"/>',
    dimmer:    '<rect x="7" y="3.5" width="10" height="17" rx="2.5"/><circle cx="12" cy="12" r="2.8"/><path d="M12 12V9.8"/>',
    empotrada: '<path d="M4 6.5h16"/><path d="M8.2 6.5a3.8 3.8 0 0 0 7.6 0"/><path d="M12 14.5v2M8.5 13l-1.2 1.6M15.5 13l1.2 1.6"/>',
    colgante:  '<path d="M12 3v6"/><path d="M7.5 13a4.5 4.5 0 0 1 9 0z"/><path d="M12 16v1.2"/><path d="M9 20h6"/>',
    techoluz:  '<path d="M4 8h16"/><path d="M7 8a5 5 0 0 0 10 0"/><path d="M12 16.5v2M7.8 15l-1.3 1.7M16.2 15l1.3 1.7"/>',
    ventilador:'<circle cx="12" cy="12" r="2"/><path d="M12 10c0-3.5 1.6-5.5 4-5.5 1.8 0 2.6 1.6 1.4 2.9C16 8.9 14 10 12 10z"/><path d="M10.3 13c-3 1.8-5.6 1.6-6.8-.5-.9-1.6.3-2.9 2-2.6 2 .3 3.6 1.4 4.8 3.1z"/><path d="M13.7 13c3 1.8 3.9 4.2 2.7 6.3-.9 1.6-2.7 1.3-3.3-.4-.7-1.9-.5-3.9.6-5.9z"/>',
    sconce:    '<path d="M17 3.5v17"/><path d="M12 8.5a4.5 4.5 0 0 0-4.5 4.5h9"/><path d="M9.5 16.5l-1 1.8M12 16.5v2"/>',
    vanidad:   '<rect x="4" y="9" width="16" height="4.5" rx="2.2"/><circle cx="8" cy="17.5" r="1.1"/><circle cx="12" cy="17.5" r="1.1"/><circle cx="16" cy="17.5" r="1.1"/><path d="M12 9V5"/>',
    reflector: '<path d="M6 14.5 3.8 18l3.4 2 2-3.6"/><rect x="6.2" y="9.2" width="7" height="6" rx="1.8" transform="rotate(30 9.7 12.2)"/><path d="M14.5 8l4-4.2M16.5 11l4.5-1.6M15.7 9.5l4.3-3"/>',
    extractor: '<rect x="3.5" y="3.5" width="17" height="17" rx="3"/><circle cx="12" cy="12" r="1.6"/><path d="M12 10.4c0-2.4 1-3.9 2.7-3.9 1.3 0 1.8 1.2.9 2.1-.9.9-2.2 1.6-3.6 1.8z"/><path d="M10.6 13c-2.1 1.2-3.9 1-4.7-.4-.6-1.1.2-2 1.4-1.8 1.4.2 2.4.9 3.3 2.2z"/><path d="M13.2 13.4c2.1 1.2 2.7 2.9 1.9 4.3-.6 1.1-1.9.9-2.3-.3-.5-1.3-.4-2.6.4-4z"/>',
    tira:      '<path d="M3 12c3-3.5 6 3.5 9 0s6 3.5 9 0"/><path d="M6 16.5h.01M10 16.5h.01M14 16.5h.01M18 16.5h.01"/>',
    humo:      '<circle cx="12" cy="12" r="7.5"/><circle cx="12" cy="12" r="2.2"/><path d="M12 6.8v1.4M15.7 8.3l-1 1M8.3 8.3l1 1"/>',
    datos:     '<rect x="6" y="4" width="12" height="13" rx="2"/><path d="M9 7.5v2M12 7.5v2M15 7.5v2"/><path d="M9.5 17v3h5v-3"/>',
    sensor:    '<path d="M7 20a5 5 0 0 1 10 0z"/><circle cx="12" cy="10" r="3"/><path d="M5.5 8.5a7.5 7.5 0 0 1 13 0"/><path d="M3.2 6.5a10.5 10.5 0 0 1 17.6 0"/>',
    inalambrico:'<path d="M12 18.5v.01"/><path d="M8.8 15.2a4.5 4.5 0 0 1 6.4 0"/><path d="M6 12.4a8.5 8.5 0 0 1 12 0"/><path d="M3.2 9.5a12.5 12.5 0 0 1 17.6 0"/>',
    // las fichas
    casa:      '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/><path d="M9.5 20v-5h5v5"/>',
    panel:     '<path d="M13 2.5 5 13.5h6L11 21.5l8-11h-6z"/>',
    cuartos:   '<rect x="3.5" y="3.5" width="17" height="17" rx="2.5"/><path d="M12 3.5v17M3.5 12H12"/>',
    ojo:       '<path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>',
    medidas:   '<path d="m4 17 13-13 3 3-13 13H4z"/><path d="m8.5 12.5 1.5 1.5M11.5 9.5l1.5 1.5M14.5 6.5 16 8"/>',
    resumen:   '<path d="M7 3.5h7l4 4v13H7z"/><path d="M14 3.5V8h4"/><path d="M9.5 12h5M9.5 15.5h5"/>',
    papelera:  '<path d="M4.5 6.5h15"/><path d="M8 6.5V5a1.5 1.5 0 0 1 1.5-1.5h5A1.5 1.5 0 0 1 16 5v1.5"/><path d="M6.5 6.5 7.3 19a2 2 0 0 0 2 1.9h5.4a2 2 0 0 0 2-1.9l.8-12.5"/><path d="M10 10.5v6M14 10.5v6"/>',
    lista:     '<path d="M8.5 5.5H19M8.5 12H19M8.5 18.5H19"/><path d="M4.5 5.5h.01M4.5 12h.01M4.5 18.5h.01"/>'
  };
  function levIco(nombre, ancho) {
    const dibujo = LEV_SVG[nombre] || LEV_SVG.otro;
    return `<span class="lev-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"` +
      ` stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"${ancho ? ` style="width:${ancho}px;height:${ancho}px"` : ""}>${dibujo}</svg></span>`;
  }

  // Lo que se puede contar. La 'clave' es la del recetario de la base:
  // clave + "." + acción. Si una acción no tiene receta, no se ofrece.
  const LEV_CONTADORES = {
    toma:              { etiqueta: "Tomas",                  icono: "enchufe" },
    toma_gfci:         { etiqueta: "Tomas GFCI",             icono: "gfci" },
    toma_gfci_wr:      { etiqueta: "GFCI de intemperie",     icono: "gfci" },
    toma_240_estufa:   { etiqueta: "Toma 240V estufa",       icono: "estufa" },
    toma_240_secadora: { etiqueta: "Toma 240V secadora",     icono: "secadora" },
    switch:            { etiqueta: "Interruptores",          icono: "interruptor" },
    switch3:           { etiqueta: "De tres vías",           icono: "tresvias" },
    dimmer:            { etiqueta: "Dimmers",                icono: "dimmer" },
    recessed:          { etiqueta: "Empotradas",             icono: "empotrada" },
    colgante:          { etiqueta: "Colgantes",              icono: "colgante" },
    techo:             { etiqueta: "Luz de techo",           icono: "techoluz" },
    ventilador:        { etiqueta: "Ventilador de techo",    icono: "ventilador" },
    sconce:            { etiqueta: "Sconce de pared",        icono: "sconce" },
    vanidad:           { etiqueta: "Luz de vanidad",         icono: "vanidad" },
    flood:             { etiqueta: "Reflector exterior",     icono: "reflector" },
    extractor:         { etiqueta: "Extractor de baño",      icono: "extractor" },
    bajo_gabinete:     { etiqueta: "Bajo gabinete",          icono: "tira", pies: true },
    tira:              { etiqueta: "Tira LED",               icono: "tira", pies: true },
    humo:              { etiqueta: "Detector de humo",       icono: "humo" },
    humo_co:           { etiqueta: "Detector humo/CO",       icono: "humo" },
    datos:             { etiqueta: "Toma de datos",          icono: "datos" },
    sensor:            { etiqueta: "Sensor de movimiento",   icono: "sensor" },
    caseta_dimmer:     { etiqueta: "Dimmer Caséta",          icono: "inalambrico" },
    caseta_switch:     { etiqueta: "Switch Caséta",          icono: "inalambrico" },
    caseta_pico:       { etiqueta: "Pico Caséta",            icono: "inalambrico" },
    caseta_hub:        { etiqueta: "Hub Caséta",             icono: "inalambrico" }
  };

  // Cada clase de cuarto trae puestos los contadores que casi siempre hacen
  // falta. Lo que sobra se quita; lo que falta se añade con "＋ otra cosa".
  const LEV_CLASES = {
    cocina:   { etiqueta: "Cocina",             icono: "cocina", trae: ["toma", "toma_gfci", "switch", "recessed", "colgante", "bajo_gabinete"] },
    bano:     { etiqueta: "Baño",               icono: "bano", trae: ["toma_gfci", "switch", "vanidad", "recessed", "extractor"] },
    recamara: { etiqueta: "Recámara",           icono: "recamara", trae: ["toma", "switch", "ventilador", "humo"] },
    sala:     { etiqueta: "Sala / comedor",     icono: "sala", trae: ["toma", "switch", "recessed", "techo"] },
    pasillo:  { etiqueta: "Pasillo / lavandería", icono: "pasillo", trae: ["toma", "switch", "techo", "humo"] },
    exterior: { etiqueta: "Exterior",           icono: "exterior", trae: ["toma_gfci_wr", "sconce", "flood"] },
    garaje:   { etiqueta: "Garaje",             icono: "garaje", trae: ["toma", "toma_gfci", "techo", "toma_240_secadora"] },
    otro:     { etiqueta: "Otro",               icono: "otro", trae: ["toma", "switch", "techo"] }
  };

  const LEV_ACCIONES = {
    nueva:   { etiqueta: "NUEVA",    ayuda: "no existe, se pone desde cero" },
    cambiar: { etiqueta: "CAMBIAR",  ayuda: "existe y se reemplaza (la demolición va dentro)" },
    queda:   { etiqueta: "SE QUEDA", ayuda: "existe y no se toca — cero horas, pero queda apuntado" },
    quitar:  { etiqueta: "QUITAR",   ayuda: "se retira y no se repone" }
  };

  // Las marcas de panel para las que no se consiguen breakers.
  const LEV_MARCAS_MALAS = ["Federal Pacific", "Zinsco", "Challenger", "Pushmatic", "Wadsworth"];
  const LEV_MARCAS = ["Square D QO", "Square D Homeline", "Eaton", "Siemens", "GE", "Murray", "ITE"]
    .concat(LEV_MARCAS_MALAS).concat(["No se lee"]);

  const LEV_CIRCUITOS = [
    { clave: "circuito.luz15",        etiqueta: "Iluminación 15A" },
    { clave: "circuito.tomas20",      etiqueta: "Tomas 20A" },
    { clave: "circuito.tomas20afci",  etiqueta: "Tomas 20A con AFCI/GFCI" },
    { clave: "circuito.secadora30",   etiqueta: "Secadora 30A" },
    { clave: "circuito.estufa50",     etiqueta: "Estufa 50A" },
    { clave: "circuito.aire30",       etiqueta: "Aire 30A" },
    { clave: "circuito.calentador30", etiqueta: "Calentador 30A" }
  ];

  // Cubo B — velocidad. Mueve el factor, no añade renglones.
  const LEV_VELOCIDAD = [
    { id: "listones", etiqueta: "Pared de yeso sobre listones", suma: 0.15 },
    { id: "bloque",   etiqueta: "Pared o techo de bloque",      suma: 0.20 },
    { id: "atico",    etiqueta: "Ático de gatear o lleno de aislamiento", suma: 0.10 },
    { id: "crawl",    etiqueta: "Crawl space bajo",             suma: 0.10 },
    { id: "alto",     etiqueta: "Techo de más de 10 pies",      suma: 0.08 },
    { id: "operando", etiqueta: "Hay que dejar la casa operando cada noche", suma: 0.08 }
  ];

  // Cubo C — banderas rojas. Cero horas: van al bloque NO INCLUYE.
  const LEV_BANDERAS = [
    "Casa anterior a 1978 (plomo)",
    "Casa anterior a 1985 (asbesto)",
    "Hay trabajo de la compañía eléctrica",
    "Servicio trifásico o de más de 400 A",
    "Humedad o madera podrida donde va el panel",
    "El panel no se pudo abrir",
    "Panel en closet o sin espacio delante",
    "Reglas de asociación de vecinos",
    "Sin acceso al ático o al crawl space",
    "Techo de teja o metal"
  ];

  const LEV_CALIBRES = [
    { id: "14_2", etiqueta: "14/2" }, { id: "12_2", etiqueta: "12/2" },
    { id: "12_3", etiqueta: "12/3" }, { id: "10_2", etiqueta: "10/2" },
    { id: "10_3", etiqueta: "10/3" }, { id: "6_3",  etiqueta: "6/3" }
  ];

  // ---------- Guardado: primero el teléfono, después la nube ----------
  const levLlaveLocal = l => "mxp_lev_" + l.llave_cliente;
  function levGuardarLocal(l) {
    try { localStorage.setItem(levLlaveLocal(l), JSON.stringify(l)); } catch { /* teléfono lleno */ }
  }
  function levBorrarLocal(l) {
    try { localStorage.removeItem(levLlaveLocal(l)); } catch { /* nada */ }
  }
  function levLeerLocales() {
    const fuera = [];
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k && k.indexOf("mxp_lev_") === 0) {
          try { fuera.push(JSON.parse(localStorage.getItem(k))); } catch { /* rota */ }
        }
      }
    } catch { /* nada */ }
    return fuera.filter(Boolean);
  }

  // Se toca algo → se guarda en el teléfono al instante y en la nube
  // un segundo después (para no mandar una petición por cada toque).
  function levTocado(repintar) {
    if (!levActivo) return;
    levActivo.actualizado = new Date().toISOString();
    levGuardarLocal(levActivo);
    levSucio = true;
    clearTimeout(levTimer);
    levTimer = setTimeout(levSubir, 1200);
    if (repintar !== false) pintarLevantamiento();
  }

  async function levSubir() {
    if (!levActivo || levGuardando || !levSucio) return;
    levGuardando = true;
    const copia = JSON.parse(JSON.stringify(levActivo));
    levSucio = false;
    try {
      const filas = await DB.guardarLevantamiento({
        llave_cliente: copia.llave_cliente,
        estimado_id: copia.estimado_id || null,
        proyecto_id: copia.proyecto_id || null,
        nombre: copia.nombre,
        cliente: copia.cliente || null,
        direccion: copia.direccion || null,
        sqft: copia.sqft || null,
        tipo: copia.tipo || "residencial",
        panel: copia.panel || {},
        condiciones: copia.condiciones || {},
        medidas: copia.medidas || {},
        decisiones: copia.decisiones || {},
        circuitos: copia.circuitos || [],
        factor: levFactor(copia),
        estado: copia.estado || "abierto"
      });
      const id = filas && filas[0] ? filas[0].id : copia.id;
      if (id && levActivo && levActivo.llave_cliente === copia.llave_cliente) levActivo.id = id;
      // Los cuartos van uno a uno, con su propia llave: así dos teléfonos
      // no se pisan y reenviar lo mismo no duplica.
      for (const c of (copia.cuartos || [])) {
        const guardado = await DB.guardarCuarto({
          levantamiento_id: id,
          llave_cliente: c.llave_cliente,
          nombre: c.nombre,
          clase: c.clase,
          estado: c.estado || "empezado",
          conteos: c.conteos || [],
          nota: c.nota || null,
          orden: c.orden || 0
        });
        if (guardado && guardado[0] && levActivo) {
          const vivo = (levActivo.cuartos || []).find(x => x.llave_cliente === c.llave_cliente);
          if (vivo) vivo.id = guardado[0].id;
        }
      }
      levSinSenal = false;
      levGuardarLocal(levActivo);
    } catch (err) {
      // Sin señal o error: lo apuntado NO se pierde, se queda en el teléfono
      levSucio = true;
      levSinSenal = true;
      if (err && err.status && err.status !== 0) console.warn("[levantamiento]", err.crudo || err.message);
    } finally {
      levGuardando = false;
      const barra = document.getElementById("lev-senal");
      if (barra) barra.hidden = !levSinSenal;
    }
  }

  // ---------- Abrir y crear ----------
  function levNuevo(base) {
    const hoy = new Date();
    return {
      llave_cliente: llaveUnica(),
      id: null, estimado_id: null, proyecto_id: (base && base.proyecto_id) || null,
      nombre: (base && base.nombre) || "Levantamiento " + hoy.toLocaleDateString("es-US"),
      cliente: (base && base.cliente) || "", direccion: (base && base.direccion) || "",
      sqft: null, tipo: "residencial",
      panel: {}, condiciones: { velocidad: [], banderas: [] }, medidas: {},
      decisiones: {}, circuitos: [], cuartos: [], estado: "abierto",
      creado: hoy.toISOString(), actualizado: hoy.toISOString()
    };
  }

  function irLevantamiento(llave) {
    if (!usuario.finanzas) return;
    mostrar("levantamiento", { kicker: "Solo dueño", titulo: "Levantamiento", volver: true, nuevo: false });
    levFicha = 0;
    if (llave) {
      const local = levLeerLocales().find(x => x.llave_cliente === llave);
      // El teléfono manda, la nube copia: si están los dos, gana el del teléfono
      levActivo = local || levDesdeNube(llave) || levNuevo();
    } else {
      levActivo = levNuevo();
      levGuardarLocal(levActivo);
    }
    pintarLevantamiento();
    if (!llave) levTocado(false);
  }

  function levDesdeNube(llave) {
    if (!levData) return null;
    const l = (levData.levantamientos || []).find(x => x.llave_cliente === llave);
    if (!l) return null;
    return {
      ...l,
      condiciones: l.condiciones || { velocidad: [], banderas: [] },
      panel: l.panel || {}, medidas: l.medidas || {}, decisiones: l.decisiones || {},
      circuitos: l.circuitos || [],
      cuartos: (levData.cuartos || []).filter(c => c.levantamiento_id === l.id)
        .map(c => ({ ...c, conteos: c.conteos || [] }))
        .sort((a, b) => (a.orden || 0) - (b.orden || 0))
    };
  }

  // ---------- Las cuentas ----------
  function levRecetasDe(clave) {
    return (estData && estData.recetas ? estData.recetas : []).filter(r => r.clave === clave);
  }
  function levAccionesDe(base) {
    const hay = new Set((estData && estData.recetas ? estData.recetas : [])
      .filter(r => r.clave.indexOf(base + ".") === 0)
      .map(r => r.clave.slice(base.length + 1)));
    // SE QUEDA siempre se puede: son cero horas, solo queda apuntado
    const orden = ["nueva", "cambiar", "queda", "quitar"];
    return orden.filter(a => a === "queda" || hay.has(a) || (a === "nueva" && hay.has("pies")));
  }
  const levItemCat = id => (estData && estData.catalogo ? estData.catalogo : []).find(c => c.id === id);

  // El factor: 1 + el mayor + la mitad de los demás, con tope 1.30
  function levFactor(l) {
    const marcados = ((l.condiciones || {}).velocidad || [])
      .map(id => (LEV_VELOCIDAD.find(v => v.id === id) || {}).suma || 0)
      .sort((a, b) => b - a);
    if (!marcados.length) return 1;
    const suma = marcados[0] + marcados.slice(1).reduce((s, v) => s + v, 0) / 2;
    return Math.min(1.30, Math.round((1 + suma) * 100) / 100);
  }

  // ¿Se cambia el panel? Sale solo de la marca.
  const levPanelCondenado = l => LEV_MARCAS_MALAS.indexOf((l.panel || {}).marca) >= 0;
  // ¿Panel lleno? Con 2 espacios libres o menos hace falta sub-panel.
  function levNecesitaSubpanel(l) {
    const libres = (l.panel || {}).libres;
    return !levPanelCondenado(l) && libres !== undefined && libres !== null && Number(libres) <= 2;
  }

  // Cuántos circuitos hay que reconectar al panel nuevo. Sale de la ficha del
  // panel: los espacios que tiene menos los que están libres. Si no se sabe,
  // se usa lo que Edgar puso en A1 o el número de circuitos nuevos.
  function levReconectar(l) {
    const p = l.panel || {};
    const total = Number(p.espacios || 0), libres = Number(p.libres || 0);
    if (total && total > libres) return total - libres;
    const c = l.condiciones || {};
    return Number(c.a1 || 0) || (l.circuitos || []).reduce((s, x) => s + Number(x.n || 0), 0) || 1;
  }

  // Cuántos cuartos y cuántos quedaron sin contar
  const levCuartosContados = l => (l.cuartos || []).filter(c => c.estado === "contado");
  const levCuartosAMedias  = l => (l.cuartos || []).filter(c => c.estado !== "contado");

  // Los tres precios que la app NO se inventa
  function levPreciosQueFaltan(l) {
    const faltan = [];
    const d = l.decisiones || {};
    if (levPanelCondenado(l) && !Number(d.panel)) faltan.push("el panel nuevo de 200A");
    if (levNecesitaSubpanel(l) && !Number(d.subpanel)) faltan.push("el sub-panel de 100A");
    if ((l.condiciones || {}).a8 && !Number(d.meter)) faltan.push("la base del medidor");
    return faltan;
  }

  // ---------- De levantamiento a renglones del estimado ----------
  // Devuelve [{ catalogo_item_id, cantidad, de }] ya sumado por partida.
  function levRenglones(l) {
    const bolsa = new Map();
    const meter = (claveReceta, veces, de) => {
      if (!veces) return;
      levRecetasDe(claveReceta).forEach(r => {
        const cant = Number(r.cantidad || 1) * veces;
        if (!cant) return;
        const previo = bolsa.get(r.catalogo_item_id) || { catalogo_item_id: r.catalogo_item_id, cantidad: 0, de: [] };
        previo.cantidad += cant;
        if (previo.de.indexOf(de) < 0) previo.de.push(de);
        bolsa.set(r.catalogo_item_id, previo);
      });
    };

    // 1) los cuartos
    (l.cuartos || []).forEach(c => {
      (c.conteos || []).forEach(t => {
        const n = Number(t.n || 0);
        if (!n || t.accion === "queda") return;             // SE QUEDA no cobra
        const def = LEV_CONTADORES[t.clave] || {};
        const suf = def.pies ? "pies" : t.accion;
        meter(t.clave + "." + suf, n, c.nombre);
      });
    });

    // 2) los circuitos
    (l.circuitos || []).forEach(x => meter(x.clave, Number(x.n || 0), "circuitos"));

    // 3) las condiciones del cubo A
    const c = l.condiciones || {};
    const cuartos = (l.cuartos || []).length;
    // A1 se apaga sola si se cambia el panel: al reconectar el panel nuevo
    // ya se identifica cada circuito.
    if (!levPanelCondenado(l)) meter("cond.a1", Number(c.a1 || 0), "rastrear circuitos");
    const bolsasA2 = { pocos: 3, bastantes: 8, muchos: 15 };
    meter("cond.a2", bolsasA2[c.a2] || 0, "empalmes viejos");
    meter("cond.a3", Number(c.a3 || 0), "abrir pared o techo");
    meter("cond.a4", Number(c.a4 || 0), "sacar cable viejo");
    meter("cond.a5", Number(c.a5 || 0), "sacar tubería vieja");
    if (levPanelCondenado(l)) meter("cond.a6", 1, "panel condenado");
    if (levNecesitaSubpanel(l)) meter("cond.a7", 1, "sub-panel");
    if (c.a8) meter("cond.a8", 1, "medidor");
    if (cuartos) meter("cond.a9", cuartos, "casa habitada");
    meter("cond.a10", Number(c.a10 || 0), "correcciones de inspección");
    meter("cond.a11", Number(c.a11 || 0), "escombro");
    if ((c.a12 || "si") === "si") meter("cond.a12", 1, "permiso");
    meter("cond.a13", Number(c.a13 || 0), "botar luminarias");

    // 4) el cable de más, solo cuando una corrida pasa de 100 pies
    const m = l.medidas || {};
    if (m.corrida_pies && m.corrida_calibre) meter("cable." + m.corrida_calibre, Number(m.corrida_pies), "corrida larga");

    // Los circuitos que hay que reconectar al panel nuevo van a media hora
    // cada uno. La receta ya metió UNO; aquí se añaden los que faltan.
    // El número sale solo: espacios del panel menos espacios libres.
    if (levPanelCondenado(l) || levNecesitaSubpanel(l)) {
      const extra = levReconectar(l) - 1;
      if (extra > 0) {
        const receta = levRecetasDe(levPanelCondenado(l) ? "cond.a6" : "cond.a7")
          .find(r => (levItemCat(r.catalogo_item_id) || {}).item === "Panel Termination (per circuit)");
        if (receta) {
          const previo = bolsa.get(receta.catalogo_item_id);
          if (previo) previo.cantidad += extra;
        }
      }
    }
    return [...bolsa.values()];
  }

  // Las horas y el precio que se ven en el resumen
  function levTotales(l) {
    const renglones = levRenglones(l);
    let horas = 0, material = 0;
    renglones.forEach(r => {
      const cat = levItemCat(r.catalogo_item_id);
      if (!cat) return;
      horas    += Number(cat.horas_unidad || 0) * r.cantidad;
      material += Number(cat.precio || 0) * r.cantidad;
    });
    const factor = levFactor(l);
    const d = l.decisiones || {};
    const aMano = Number(d.panel || 0) + Number(d.subpanel || 0) + Number(d.meter || 0);
    return {
      renglones: renglones.length,
      horas: Math.round(horas * factor * 10) / 10,
      material: Math.round((material + aMano) * 100) / 100,
      factor
    };
  }

  // ============================================================
  // Las pantallas del levantamiento
  // ============================================================
  function pintarLevantamiento() {
    if (!levActivo) { pintarLevLista(); return; }
    const l = levActivo;
    const barra = LEV_FICHAS.map((f, i) => `
      <div class="paso${i < levFicha ? " hecho" : ""}${i === levFicha ? " actual" : ""}" data-ficha="${i}">
        <div class="paso-punto">${i < levFicha ? "✓" : i + 1}</div>
        <div class="paso-nombre">${f.etiqueta}</div>
      </div>`).join(`<div class="paso-linea"></div>`);

    const cuerpo = [levFicha1, levFicha2, levFicha3, levFicha4, levFicha5, levFicha6][levFicha](l);

    $("levantamiento-panel").innerHTML = `
      <div id="lev-senal" class="lev-senal"${levSinSenal ? "" : " hidden"}>Sin señal — se está guardando en el teléfono</div>
      <div class="pasos lev-pasos">${barra}</div>
      <div class="cal-panel-card lev-cuerpo">${cuerpo}</div>
      <div class="lev-pie">
        <button type="button" class="accion secundaria" id="lev-atras"${levFicha === 0 ? " disabled" : ""}>← Atrás</button>
        <button type="button" class="accion" id="lev-siguiente"${levFicha === 5 ? " disabled" : ""}>Siguiente →</button>
      </div>`;

    $("levantamiento-panel").querySelectorAll(".paso").forEach(el => {
      el.addEventListener("click", () => { levFicha = Number(el.dataset.ficha); pintarLevantamiento(); });
    });
    $("lev-atras").addEventListener("click", () => { if (levFicha > 0) { levFicha--; pintarLevantamiento(); } });
    $("lev-siguiente").addEventListener("click", () => { if (levFicha < 5) { levFicha++; pintarLevantamiento(); } });
    [levEnganchar1, levEnganchar2, levEnganchar3, levEnganchar4, levEnganchar5, levEnganchar6][levFicha](l);
  }

  // Guarda un campo simple sin repintar toda la pantalla (no se pierde el foco)
  function levCampo(sel, aplicar) {
    $("levantamiento-panel").querySelectorAll(sel).forEach(el => {
      el.addEventListener("change", () => { aplicar(el); levTocado(false); });
    });
  }
  // Fichas de escoger una opción (chips)
  function levChips(nombre, valor, opciones, extra) {
    return `<div class="lev-chips" data-campo="${nombre}">` + opciones.map(o => {
      const v = typeof o === "string" ? o : o.id;
      const t = typeof o === "string" ? o : o.etiqueta;
      const malo = extra === "marcas" && LEV_MARCAS_MALAS.indexOf(v) >= 0;
      return `<button type="button" class="lev-chip${String(valor) === String(v) ? " puesto" : ""}${malo ? " malo" : ""}" data-valor="${esc(v)}">${esc(t)}</button>`;
    }).join("") + `</div>`;
  }
  function engancharChips(campo, guardar) {
    $("levantamiento-panel").querySelectorAll(`.lev-chips[data-campo="${campo}"] .lev-chip`).forEach(b => {
      b.addEventListener("click", () => { guardar(b.dataset.valor); levTocado(); });
    });
  }
  // Un contador con − y +, separados, y el número grande en medio
  function levContador(id, etiqueta, n, sufijo) {
    return `
      <div class="lev-cont" data-cont="${esc(id)}">
        <span class="lev-cont-txt">${etiqueta}</span>
        <span class="lev-cont-mandos">
          <button type="button" class="lev-cont-btn" data-paso="-1">−</button>
          <span class="lev-cont-n">${n || 0}${sufijo ? `<i>${sufijo}</i>` : ""}</span>
          <button type="button" class="lev-cont-btn" data-paso="1">＋</button>
        </span>
      </div>`;
  }
  function engancharContadores(leer, escribir) {
    $("levantamiento-panel").querySelectorAll(".lev-cont").forEach(fila => {
      const id = fila.dataset.cont;
      fila.querySelectorAll(".lev-cont-btn").forEach(b => {
        b.addEventListener("click", () => {
          const paso = Number(b.dataset.paso) * (fila.dataset.salto ? Number(fila.dataset.salto) : 1);
          escribir(id, Math.max(0, Number(leer(id) || 0) + paso));
          levTocado();
        });
      });
    });
  }

  // ---------- Ficha 1 · La casa ----------
  function levFicha1(l) {
    return `
      <div class="lev-titulo">${levIco("casa")} La casa</div>
      <label>Nombre del trabajo
        <input class="lev-in" data-c="nombre" type="text" value="${esc(l.nombre || "")}" placeholder="Ej: Casa García — Rewire">
      </label>
      <label>Cliente
        <input class="lev-in" data-c="cliente" type="text" value="${esc(l.cliente || "")}" placeholder="Ej: Juan García">
      </label>
      <label>Dirección
        <input class="lev-in" data-c="direccion" type="text" value="${esc(l.direccion || "")}" placeholder="Calle, ciudad">
      </label>
      <div class="modal-fila">
        <label>Pies cuadrados
          <input class="lev-in" data-c="sqft" type="number" inputmode="numeric" min="0" value="${l.sqft || ""}" placeholder="Ej: 1800">
        </label>
        <label>Tipo
          <select class="lev-in" data-c="tipo">
            <option value="residencial"${l.tipo !== "comercial" ? " selected" : ""}>Residencial</option>
            <option value="comercial"${l.tipo === "comercial" ? " selected" : ""}>Comercial</option>
          </select>
        </label>
      </div>
      <p class="lev-nota">Se guarda solo. Puedes salir y volver cuando quieras.</p>`;
  }
  function levEnganchar1() {
    levCampo(".lev-in", el => {
      const c = el.dataset.c;
      levActivo[c] = c === "sqft" ? (el.value ? Number(el.value) : null) : el.value;
    });
  }

  // ---------- Ficha 2 · El panel ----------
  function levFicha2(l) {
    const p = l.panel || {};
    const alerta = levPanelCondenado(l) ? `
      <div class="lev-roja">
        <div class="lev-roja-t">Panel ${esc(p.marca)} — condenado</div>
        <p>No se puede reutilizar: no se consiguen breakers para él. La cotización tiene que llevar panel nuevo.</p>
        <p>Te dejé puestas <b>9 horas</b> (demoler el viejo y montar el nuevo) más <b>media hora por cada circuito</b> que haya que reconectar — ahora mismo <b>${levReconectar(l)}</b>.</p>
        <label style="display:block">Lo que falta es el precio del panel. Ponlo tú:
          <input class="lev-precio" data-d="panel" type="number" inputmode="decimal" min="0" step="0.01" value="${(l.decisiones || {}).panel || ""}" placeholder="$">
        </label>
      </div>` : "";
    const alertaSub = levNecesitaSubpanel(l) ? `
      <div class="lev-roja">
        <div class="lev-roja-t">El panel está lleno</div>
        <p>Con ${esc(p.libres)} espacios libres no caben los circuitos nuevos: hace falta un sub-panel de 100A.</p>
        <label style="display:block">El precio del sub-panel:
          <input class="lev-precio" data-d="subpanel" type="number" inputmode="decimal" min="0" step="0.01" value="${(l.decisiones || {}).subpanel || ""}" placeholder="$">
        </label>
      </div>` : "";
    return `
      <div class="lev-titulo">${levIco("panel")} El panel</div>
      <div class="lev-campo"><span class="lev-lab">Marca</span>${levChips("marca", p.marca, LEV_MARCAS, "marcas")}</div>
      ${alerta}
      <div class="lev-campo"><span class="lev-lab">Amperaje</span>${levChips("amperaje", p.amperaje, ["60", "100", "125", "150", "200", "400", "No se sabe"])}</div>
      <div class="lev-campo"><span class="lev-lab">Espacios que tiene</span>${levChips("espacios", p.espacios, ["12", "20", "24", "30", "40", "42"])}</div>
      <div class="lev-campo">
        <span class="lev-lab">Espacios libres <i>— lo que ves, no lo que hay que calcular</i></span>
        ${levContador("libres", "Espacios libres", p.libres)}
      </div>
      ${alertaSub}
      <div class="lev-campo"><span class="lev-lab">Tipo</span>${levChips("tipo", p.tipo, [
        { id: "main", etiqueta: "Main breaker" }, { id: "mlo", etiqueta: "Main lug (sub-panel)" }, { id: "combo", etiqueta: "Combo con medidor" }])}</div>
      <div class="lev-campo"><span class="lev-lab">Acometida</span>${levChips("acometida", p.acometida, [
        { id: "aerea", etiqueta: "Aérea" }, { id: "subterranea", etiqueta: "Subterránea" }])}</div>
      <div class="lev-campo"><span class="lev-lab">Dónde está</span>${levChips("donde", p.donde, [
        "Garaje", "Exterior", "Pasillo", "Lavandería", "Closet", "Otro"])}</div>
      <div class="lev-campo"><span class="lev-lab">¿Cabe pararse delante? <i>— 36″ de fondo, artículo 110.26</i></span>${levChips("delante", p.delante, [
        { id: "si", etiqueta: "Sí" }, { id: "no", etiqueta: "No — sin espacio" }])}</div>
      <div class="lev-campo"><span class="lev-lab">¿Hay directorio de circuitos?</span>${levChips("directorio", p.directorio, [
        { id: "si", etiqueta: "Sí" }, { id: "medias", etiqueta: "A medias" }, { id: "no", etiqueta: "No" }])}</div>
      <label>No lo pude abrir — ¿por qué?
        <input class="lev-panel-txt" data-p="no_abri" type="text" value="${esc(p.no_abri || "")}" placeholder="Déjalo vacío si sí lo abriste">
      </label>
      <p class="lev-nota">Si escribes algo aquí, sale como bandera roja y como línea de «no incluye».</p>`;
  }
  function levEnganchar2(l) {
    ["marca", "amperaje", "espacios", "tipo", "acometida", "donde", "delante", "directorio"].forEach(campo => {
      engancharChips(campo, v => {
        l.panel = l.panel || {};
        l.panel[campo] = l.panel[campo] === v ? null : v;   // volver a tocar lo quita
      });
    });
    engancharContadores(() => (l.panel || {}).libres, (id, v) => { l.panel = l.panel || {}; l.panel.libres = v; });
    levCampo(".lev-panel-txt", el => { l.panel = l.panel || {}; l.panel[el.dataset.p] = el.value; });
    levCampo(".lev-precio", el => { l.decisiones = l.decisiones || {}; l.decisiones[el.dataset.d] = el.value ? Number(el.value) : null; });
  }

  // ---------- Ficha 3 · Los cuartos ----------
  let levCuartoAbierto = null;   // llave_cliente del cuarto que se está contando

  function levFicha3(l) {
    if (levCuartoAbierto) {
      const c = (l.cuartos || []).find(x => x.llave_cliente === levCuartoAbierto);
      if (c) return levCuartoHTML(c);
      levCuartoAbierto = null;
    }
    const filas = (l.cuartos || []).map(c => {
      const luz = c.estado === "contado" ? "verde" : (c.conteos || []).some(t => Number(t.n) > 0) ? "ambar" : "blanca";
      const total = (c.conteos || []).reduce((s, t) => s + Number(t.n || 0), 0);
      return `
        <div class="mat-item">
          <span class="lev-luz ${luz}"></span>
          <span class="alcance-info lev-abrir-cuarto" data-k="${esc(c.llave_cliente)}" style="cursor:pointer">
            <span class="alcance-titulo">${esc(c.nombre)}</span>
            <span class="alcance-estado">${esc((LEV_CLASES[c.clase] || {}).etiqueta || c.clase)}${total ? ` · ${total} cosas contadas` : " · sin contar"}</span>
          </span>
          <button class="lev-btn-ico lev-borrar-cuarto" data-k="${esc(c.llave_cliente)}" title="Quitar">${levIco("papelera", 19)}</button>
        </div>`;
    }).join("");
    return `
      <div class="lev-titulo">${levIco("cuartos")} Los cuartos (${(l.cuartos || []).length})</div>
      ${filas || `<p class="cal-sin-eventos">Todavía no hay cuartos. Añade el primero abajo.</p>`}
      <div class="lev-lab" style="margin-top:.9rem">＋ Añadir cuarto</div>
      <div class="lev-clases">
        ${Object.entries(LEV_CLASES).map(([id, k]) =>
          `<button type="button" class="lev-clase" data-clase="${id}">${levIco(k.icono, 24)}${esc(k.etiqueta)}</button>`).join("")}
      </div>
      <p class="lev-nota">Cada clase trae puestos los contadores que casi siempre hacen falta. Lo que sobre se quita.</p>`;
  }

  function levCuartoHTML(c) {
    const filas = (c.conteos || []).map(t => {
      const def = LEV_CONTADORES[t.clave] || { etiqueta: t.clave, icono: "otro" };
      const acciones = def.pies ? [] : levAccionesDe(t.clave);
      return `
        <div class="lev-conteo">
          ${levContador(t.clave, levIco(def.icono) + esc(def.etiqueta), t.n, def.pies ? "pies" : "")}
          ${acciones.length ? `
            <div class="lev-acciones" data-clave="${esc(t.clave)}">
              ${acciones.map(a => `<button type="button" class="lev-acc${(t.accion || "nueva") === a ? " puesto" : ""}" data-acc="${a}" title="${esc(LEV_ACCIONES[a].ayuda)}">${LEV_ACCIONES[a].etiqueta}</button>`).join("")}
            </div>` : ""}
          <button type="button" class="lev-quitar-conteo" data-clave="${esc(t.clave)}" title="Quitar este contador">✕</button>
        </div>`;
    }).join("");
    const sobran = Object.keys(LEV_CONTADORES).filter(k => !(c.conteos || []).some(t => t.clave === k));
    return `
      <div class="lev-volver-cuarto"><button type="button" class="accion secundaria" id="lev-cerrar-cuarto">← Todos los cuartos</button></div>
      <label class="lev-titulo" style="display:flex">${levIco(c.clase in LEV_CLASES ? c.clase : "otro", 22)}
        <input class="lev-cuarto-nombre" type="text" value="${esc(c.nombre)}" style="font:inherit;width:70%;border:none;background:transparent;color:inherit">
      </label>
      ${filas}
      <details class="lev-mas">
        <summary>＋ otra cosa</summary>
        <div class="lev-clases">
          ${sobran.map(k => `<button type="button" class="lev-add-conteo" data-clave="${k}">${levIco(LEV_CONTADORES[k].icono, 24)}${esc(LEV_CONTADORES[k].etiqueta)}</button>`).join("")}
        </div>
      </details>
      <label>Nota del cuarto
        <input class="lev-cuarto-nota" type="text" value="${esc(c.nota || "")}" placeholder="Lo que haga falta recordar">
      </label>
      <button type="button" class="accion ${c.estado === "contado" ? "secundaria" : ""}" id="lev-contado">
        ${c.estado === "contado" ? "Contado ✓ — tocar para reabrir" : "✓ Cuarto contado"}
      </button>`;
  }

  function levEnganchar3(l) {
    if (levCuartoAbierto) {
      const c = (l.cuartos || []).find(x => x.llave_cliente === levCuartoAbierto);
      if (!c) return;
      $("lev-cerrar-cuarto").addEventListener("click", () => { levCuartoAbierto = null; pintarLevantamiento(); });
      engancharContadores(
        clave => (c.conteos.find(t => t.clave === clave) || {}).n,
        (clave, v) => {
          const t = c.conteos.find(x => x.clave === clave);
          if (t) t.n = v;
          if (c.estado === "contado") c.estado = "empezado";  // si se retoca, vuelve a 🟡
        });
      $("levantamiento-panel").querySelectorAll(".lev-acciones").forEach(caja => {
        caja.querySelectorAll(".lev-acc").forEach(b => {
          b.addEventListener("click", () => {
            const t = c.conteos.find(x => x.clave === caja.dataset.clave);
            if (t) t.accion = b.dataset.acc;
            levTocado();
          });
        });
      });
      $("levantamiento-panel").querySelectorAll(".lev-quitar-conteo").forEach(b => {
        b.addEventListener("click", () => {
          c.conteos = c.conteos.filter(t => t.clave !== b.dataset.clave);
          levTocado();
        });
      });
      $("levantamiento-panel").querySelectorAll(".lev-add-conteo").forEach(b => {
        b.addEventListener("click", () => {
          if (!c.conteos.some(t => t.clave === b.dataset.clave)) {
            c.conteos.push({ clave: b.dataset.clave, n: 0, accion: "nueva" });
          }
          levTocado();
        });
      });
      const nom = $("levantamiento-panel").querySelector(".lev-cuarto-nombre");
      if (nom) nom.addEventListener("change", () => { c.nombre = nom.value.trim() || c.nombre; levTocado(false); });
      const nota = $("levantamiento-panel").querySelector(".lev-cuarto-nota");
      if (nota) nota.addEventListener("change", () => { c.nota = nota.value; levTocado(false); });
      $("lev-contado").addEventListener("click", () => {
        c.estado = c.estado === "contado" ? "empezado" : "contado";
        if (c.estado === "contado") levCuartoAbierto = null;
        levTocado();
      });
      return;
    }
    $("levantamiento-panel").querySelectorAll(".lev-abrir-cuarto").forEach(el => {
      el.addEventListener("click", () => { levCuartoAbierto = el.dataset.k; pintarLevantamiento(); });
    });
    $("levantamiento-panel").querySelectorAll(".lev-borrar-cuarto").forEach(b => {
      b.addEventListener("click", async () => {
        const c = (l.cuartos || []).find(x => x.llave_cliente === b.dataset.k);
        if (!c || !confirm(`¿Quitar «${c.nombre}» con todo lo contado?`)) return;
        l.cuartos = l.cuartos.filter(x => x.llave_cliente !== b.dataset.k);
        if (c.id) { try { await DB.eliminarCuarto(c.id); } catch { /* se va con el levantamiento */ } }
        levTocado();
      });
    });
    $("levantamiento-panel").querySelectorAll(".lev-clase").forEach(b => {
      b.addEventListener("click", () => {
        const clase = b.dataset.clase, def = LEV_CLASES[clase];
        const cuantos = (l.cuartos || []).filter(x => x.clase === clase).length;
        const cuarto = {
          llave_cliente: llaveUnica(), id: null, clase,
          nombre: def.etiqueta + (cuantos ? " " + (cuantos + 1) : ""),
          estado: "empezado", nota: null, orden: (l.cuartos || []).length,
          conteos: def.trae.map(k => ({ clave: k, n: 0, accion: "nueva" }))
        };
        l.cuartos = (l.cuartos || []).concat([cuarto]);
        levCuartoAbierto = cuarto.llave_cliente;
        levTocado();
      });
    });
  }

  // ---------- Ficha 4 · Las condiciones ----------
  function levFicha4(l) {
    const c = l.condiciones || (l.condiciones = { velocidad: [], banderas: [] });
    const auto = [];
    if (levPanelCondenado(l)) auto.push(`Panel condenado — panel nuevo de 200A y ${levReconectar(l)} reconexiones`);
    if (levNecesitaSubpanel(l)) auto.push("Panel lleno — sub-panel de 100A");
    if ((l.cuartos || []).length) auto.push(`Casa habitada — protección en ${(l.cuartos || []).length} cuartos`);
    return `
      <div class="lev-titulo">${levIco("ojo")} Lo que se ve</div>
      ${auto.length ? `<div class="lev-auto">✓ Puesto solo: ${auto.map(esc).join(" · ")}</div>` : ""}

      <div class="lev-lab">Trabajo que antes no existía</div>
      ${levPanelCondenado(l) ? `<p class="lev-nota">Rastrear circuitos se apagó solo: al reconectar el panel nuevo ya se identifica cada circuito.</p>`
        : levContador("a1", levIco("panel") + "Rastrear circuitos <i>— solo los que toca el trabajo</i>", c.a1)}
      <div class="lev-campo"><span class="lev-lab">Empalmes viejos o cajas sin tapa</span>${levChips("a2", c.a2, [
        { id: "", etiqueta: "Ninguno" }, { id: "pocos", etiqueta: "Pocos (3)" },
        { id: "bastantes", etiqueta: "Bastantes (8)" }, { id: "muchos", etiqueta: "Muchos (15)" }])}</div>
      ${levContador("a3", levIco("cuartos") + "Aberturas en pared o techo", c.a3)}
      <div class="lev-campo"><span class="lev-lab">Sacar cable viejo</span>${levChips("a4", c.a4, [
        { id: "0", etiqueta: "Nada" }, { id: "50", etiqueta: "50 pies" }, { id: "100", etiqueta: "100" },
        { id: "200", etiqueta: "200" }, { id: "400", etiqueta: "400" }])}</div>
      <div class="lev-cont" data-cont="a5" data-salto="10">
        <span class="lev-cont-txt">Sacar tubería vieja</span>
        <span class="lev-cont-mandos">
          <button type="button" class="lev-cont-btn" data-paso="-1">−</button>
          <span class="lev-cont-n">${c.a5 || 0}<i>pies</i></span>
          <button type="button" class="lev-cont-btn" data-paso="1">＋</button>
        </span>
      </div>
      <div class="lev-campo"><span class="lev-lab">¿Hay que tocar el medidor?</span>${levChips("a8", c.a8 ? "si" : "no", [
        { id: "no", etiqueta: "No" }, { id: "si", etiqueta: "Sí" }])}</div>
      ${c.a8 ? `<div class="lev-roja">
        <div class="lev-roja-t">Falta el precio de la base del medidor</div>
        <label style="display:block">Ponlo tú:<input class="lev-precio" data-d="meter" type="number" inputmode="decimal" min="0" step="0.01" value="${(l.decisiones || {}).meter || ""}" placeholder="$"></label>
      </div>` : ""}
      ${levContador("a10", levIco("resumen") + "Viajes a corregir trabajo de otro", c.a10)}
      ${levContador("a11", levIco("garaje") + "Viajes de escombro", c.a11)}
      ${levContador("a13", levIco("techoluz") + "Luminarias que se botan y no se reponen", c.a13)}
      <div class="lev-campo"><span class="lev-lab">Permiso</span>${levChips("a12", c.a12 || "si", [
        { id: "si", etiqueta: "Sí, lo sacamos" }, { id: "no", etiqueta: "No hace falta" }, { id: "gc", etiqueta: "Lo saca el GC" }])}</div>

      <div class="lev-lab" style="margin-top:1rem">Lo que hace que el mismo trabajo tarde más</div>
      <div class="lev-casillas">
        ${LEV_VELOCIDAD.map(v => `
          <label class="lev-casilla"><input type="checkbox" class="lev-vel" data-id="${v.id}"${(c.velocidad || []).indexOf(v.id) >= 0 ? " checked" : ""}> ${esc(v.etiqueta)} <i>+${v.suma}</i></label>`).join("")}
      </div>
      <p class="lev-nota">Factor ahora mismo: <b>${levFactor(l)}</b> (el mayor más la mitad de los demás, con tope 1.30).</p>

      <div class="lev-lab" style="margin-top:1rem">Banderas rojas <i>— cero horas: van al bloque «no incluye»</i></div>
      <div class="lev-casillas">
        ${LEV_BANDERAS.map((b, i) => `
          <label class="lev-casilla"><input type="checkbox" class="lev-ban" data-i="${i}"${(c.banderas || []).indexOf(b) >= 0 ? " checked" : ""}> ${esc(b)}</label>`).join("")}
      </div>`;
  }
  function levEnganchar4(l) {
    const c = l.condiciones;
    engancharContadores(id => c[id], (id, v) => { c[id] = v; });
    engancharChips("a2", v => { c.a2 = v || null; });
    engancharChips("a4", v => { c.a4 = Number(v) || 0; });
    engancharChips("a8", v => { c.a8 = v === "si"; });
    engancharChips("a12", v => { c.a12 = v; });
    levCampo(".lev-precio", el => { l.decisiones = l.decisiones || {}; l.decisiones[el.dataset.d] = el.value ? Number(el.value) : null; });
    $("levantamiento-panel").querySelectorAll(".lev-vel").forEach(el => {
      el.addEventListener("change", () => {
        c.velocidad = (c.velocidad || []).filter(x => x !== el.dataset.id);
        if (el.checked) c.velocidad.push(el.dataset.id);
        levTocado();
      });
    });
    $("levantamiento-panel").querySelectorAll(".lev-ban").forEach(el => {
      el.addEventListener("change", () => {
        const texto = LEV_BANDERAS[Number(el.dataset.i)];
        c.banderas = (c.banderas || []).filter(x => x !== texto);
        if (el.checked) c.banderas.push(texto);
        levTocado(false);
      });
    });
  }

  // ---------- Ficha 5 · Las medidas ----------
  function levFicha5(l) {
    const m = l.medidas || (l.medidas = {});
    const c = l.condiciones || {};
    return `
      <div class="lev-titulo">${levIco("medidas")} Las medidas</div>
      <label>Pies cuadrados
        <input class="lev-med" data-m="sqft" type="number" inputmode="numeric" min="0" value="${l.sqft || ""}" placeholder="Ej: 1800">
      </label>
      <div class="lev-campo"><span class="lev-lab">Alto del techo</span>${levChips("alto", m.alto, ["8", "9", "10", "12", "Más"])}</div>
      <div class="lev-campo"><span class="lev-lab">¿Alguna corrida se pasa de 100 pies?</span>${levChips("corrida", m.corrida_pies ? "si" : "no", [
        { id: "no", etiqueta: "No" }, { id: "si", etiqueta: "Sí" }])}</div>
      ${m.corrida_pies !== undefined && m.corrida_pies !== null ? `
        <div class="lev-cont" data-cont="corrida_pies" data-salto="10">
          <span class="lev-cont-txt">Pies de más</span>
          <span class="lev-cont-mandos">
            <button type="button" class="lev-cont-btn" data-paso="-1">−</button>
            <span class="lev-cont-n">${m.corrida_pies || 0}<i>pies</i></span>
            <button type="button" class="lev-cont-btn" data-paso="1">＋</button>
          </span>
        </div>
        <div class="lev-campo"><span class="lev-lab">De qué calibre</span>${levChips("calibre", m.corrida_calibre, LEV_CALIBRES)}</div>
        <p class="lev-nota">El cable del circuito ya viene dentro de la partida del circuito. Aquí solo va lo que <b>pasa</b> de los 100 pies.</p>` : ""}
      ${c.a8 ? `<div class="lev-cont" data-cont="panel_medidor" data-salto="5">
          <span class="lev-cont-txt">Del panel al medidor</span>
          <span class="lev-cont-mandos">
            <button type="button" class="lev-cont-btn" data-paso="-1">−</button>
            <span class="lev-cont-n">${m.panel_medidor || 0}<i>pies</i></span>
            <button type="button" class="lev-cont-btn" data-paso="1">＋</button>
          </span>
        </div>` : ""}`;
  }
  function levEnganchar5(l) {
    const m = l.medidas;
    levCampo(".lev-med", el => { l.sqft = el.value ? Number(el.value) : null; });
    engancharChips("alto", v => { m.alto = m.alto === v ? null : v; });
    engancharChips("corrida", v => {
      if (v === "si") { if (m.corrida_pies === undefined || m.corrida_pies === null) m.corrida_pies = 0; }
      else { m.corrida_pies = null; m.corrida_calibre = null; }
    });
    engancharChips("calibre", v => { m.corrida_calibre = v; });
    engancharContadores(id => m[id], (id, v) => { m[id] = v; });
  }

  // ---------- Ficha 6 · El resumen ----------
  function levFicha6(l) {
    const t = levTotales(l);
    const faltan = levPreciosQueFaltan(l);
    const aMedias = levCuartosAMedias(l);
    const banderas = ((l.condiciones || {}).banderas || []).slice();
    if ((l.panel || {}).no_abri) banderas.push("El panel no se pudo abrir: " + l.panel.no_abri);
    aMedias.forEach(c => banderas.push("Faltó contar: " + c.nombre));

    const porCuarto = (l.cuartos || []).map(c => {
      const cosas = (c.conteos || []).filter(x => Number(x.n) > 0);
      if (!cosas.length) return "";
      return `<div class="lev-res-fila"><b>${esc(c.nombre)}</b> ${cosas.map(x =>
        `${x.n} ${esc((LEV_CONTADORES[x.clave] || {}).etiqueta || x.clave).toLowerCase()}${x.accion && x.accion !== "nueva" ? ` (${LEV_ACCIONES[x.accion].etiqueta.toLowerCase()})` : ""}`).join(", ")}</div>`;
    }).join("");

    const circuitos = (l.circuitos || []).filter(x => Number(x.n) > 0);

    return `
      <div class="lev-titulo">${levIco("resumen")} El resumen</div>
      ${faltan.length ? `<div class="lev-roja"><div class="lev-roja-t">Le falta un precio</div>
        <p>Falta ${faltan.map(esc).join(" y ")}. Puedes convertir igual: el estimado sale marcado.</p></div>` : ""}
      <div class="lev-res-caja">
        <div class="lev-res-n"><b>${t.renglones}</b><span>partidas</span></div>
        <div class="lev-res-n"><b>${t.horas}</b><span>horas</span></div>
        <div class="lev-res-n"><b>${fmt(t.material)}</b><span>material</span></div>
        <div class="lev-res-n"><b>${t.factor}</b><span>factor</span></div>
      </div>
      ${porCuarto || `<p class="cal-sin-eventos">Todavía no hay nada contado.</p>`}
      ${circuitos.length ? `<div class="lev-res-fila"><b>Circuitos</b> ${circuitos.map(x =>
        `${x.n} × ${esc((LEV_CIRCUITOS.find(y => y.clave === x.clave) || {}).etiqueta || x.clave)}`).join(", ")}</div>` : ""}
      ${banderas.length ? `<div class="lev-lab" style="margin-top:.8rem">No incluye</div>
        <ul class="lev-noincluye">${banderas.map(b => `<li>${esc(b)}</li>`).join("")}</ul>` : ""}

      <div class="lev-lab" style="margin-top:1rem">Circuitos nuevos</div>
      ${LEV_CIRCUITOS.map(x => levContador(x.clave, esc(x.etiqueta),
          ((l.circuitos || []).find(y => y.clave === x.clave) || {}).n)).join("")}

      <button type="button" class="accion" id="lev-a-estimado" style="margin-top:1rem">Pasar al estimado →</button>
      <p class="lev-nota" id="lev-a-estimado-nota">Se crea el estimado con todos estos renglones. Lo que añadas a mano después no se toca al reconvertir.</p>
      <button type="button" class="accion secundaria" id="lev-a-alcance">Añadir al alcance de un proyecto</button>`;
  }

  function levEnganchar6(l) {
    engancharContadores(
      clave => ((l.circuitos || []).find(y => y.clave === clave) || {}).n,
      (clave, v) => {
        l.circuitos = (l.circuitos || []).filter(y => y.clave !== clave);
        if (v > 0) l.circuitos.push({ clave, n: v });
      });
    const btn = $("lev-a-estimado");
    if (!estData || !estData.recetas || !estData.recetas.length) {
      btn.disabled = true;
      $("lev-a-estimado-nota").textContent = "Necesita señal para poner precio. Lo apuntado no se pierde.";
    } else {
      btn.addEventListener("click", () => levAEstimado(l, btn));
    }
    $("lev-a-alcance").addEventListener("click", () => levAAlcance(l));
  }

  // ---------- Pasar al estimado ----------
  async function levAEstimado(l, btn) {
    const renglones = levRenglones(l);
    if (!renglones.length) { avisar("Todavía no hay nada contado", true); return; }
    btn.disabled = true;
    const textoViejo = btn.textContent;
    btn.textContent = "Pasando…";
    try {
      let estimadoId = l.estimado_id;
      const existe = estimadoId && (estData.estimados || []).some(e => e.id === estimadoId);
      if (!existe) {
        // Primera vez: se crea el estimado con el factor del levantamiento
        const creado = await DB.crearEstimado({
          nombre: l.nombre, cliente: l.cliente || null, direccion: l.direccion || null,
          tipo: l.tipo === "comercial" ? "Commercial" : "Residential",
          sqft: l.sqft || null, escenario: "B", factor: levFactor(l),
          estado: "borrador", modo: "remodelacion", cable: "romex"
        });
        estimadoId = creado[0].id;
      } else {
        // Al reconvertir NO se toca el factor, ni el cliente, ni los sqft:
        // si Edgar los movió mirando el precio, mandan ellos.
        await DB.borrarItemsDeLevantamiento(estimadoId);
      }
      const filas = [];
      let orden = 1000;   // detrás de lo que Edgar puso a mano
      renglones.forEach(r => {
        const cat = levItemCat(r.catalogo_item_id);
        if (!cat) return;
        const cantidad = Math.round(r.cantidad * 100) / 100;
        if (!cantidad) return;
        filas.push({
          estimado_id: estimadoId, item: cat.item, unidad: cat.unidad || "EA",
          precio: Number(cat.precio || 0), horas: Number(cat.horas_unidad || 0),
          cantidad, orden: orden++, origen: "levantamiento"
        });
      });
      // Los tres precios que Edgar tecleó a mano entran como su propio renglón
      const d = l.decisiones || {};
      const aMano = [
        { precio: Number(d.panel || 0),    item: "PANEL 200A MLO — precio puesto a mano" },
        { precio: Number(d.subpanel || 0), item: "PANEL 100A MLO — precio puesto a mano" },
        { precio: Number(d.meter || 0),    item: "METER CAN — precio puesto a mano" }
      ];
      aMano.forEach(x => {
        if (!x.precio) return;
        filas.push({ estimado_id: estimadoId, item: x.item, unidad: "EA", precio: x.precio,
                     horas: 0, cantidad: 1, orden: orden++, origen: "levantamiento" });
      });
      await DB.crearItemsEstimado(filas);            // una sola petición, no treinta y cinco
      l.estimado_id = estimadoId;
      l.estado = "convertido";
      levTocado(false);
      await levSubir();
      const faltan = levPreciosQueFaltan(l);
      avisar(faltan.length
        ? `Estimado listo con ${filas.length} renglones — le falta ${faltan.join(" y ")}`
        : `Estimado listo con ${filas.length} renglones ✓`);
      levActivo = null;
      irEstimador(estimadoId);
    } catch (err) {
      avisar("No se pudo pasar al estimado: " + err.message, true);
      btn.disabled = false;
      btn.textContent = textoViejo;
    }
  }

  // ---------- Pasar al alcance de trabajo ----------
  async function levAAlcance(l) {
    const lista = proyectos().filter(p => p.estado !== "completado");
    if (!lista.length) { avisar("No hay proyectos abiertos donde ponerlo", true); return; }
    const nombres = lista.map((p, i) => `${i + 1}. ${p.nombre}`).join("\n");
    const eleccion = prompt("¿A qué proyecto le pongo el alcance?\n\n" + nombres, "1");
    if (eleccion === null) return;
    const p = lista[Number(eleccion) - 1];
    if (!p) { avisar("Ese número no es de la lista", true); return; }

    const textos = [];
    levCuartosContados(l).forEach(c => {
      const cosas = (c.conteos || []).filter(x => Number(x.n) > 0 && x.accion !== "queda");
      if (!cosas.length) return;
      textos.push(`${c.nombre}: ` + cosas.map(x =>
        `${x.n} ${((LEV_CONTADORES[x.clave] || {}).etiqueta || x.clave).toLowerCase()}`).join(", "));
    });
    (l.circuitos || []).filter(x => Number(x.n) > 0).forEach(x => {
      textos.push(`${x.n} circuito${x.n > 1 ? "s" : ""} nuevo${x.n > 1 ? "s" : ""} de ${
        (LEV_CIRCUITOS.find(y => y.clave === x.clave) || {}).etiqueta || x.clave}`);
    });
    if (levPanelCondenado(l)) textos.push(`Reemplazo del panel ${l.panel.marca} por uno nuevo de 200A`);
    if (levNecesitaSubpanel(l)) textos.push("Instalación de un sub-panel de 100A");
    const c4 = l.condiciones || {};
    if (Number(c4.a4)) textos.push(`Retirada de ${c4.a4} pies de cableado en desuso`);
    if (c4.a8) textos.push("Trabajo en la base del medidor");

    const yaEstan = new Set(((state && state.puntos) ? state.puntos : [])
      .filter(x => x.proyecto === p.id).map(x => x.texto));
    const nuevos = textos.filter(t => !yaEstan.has(t));
    if (!nuevos.length) { avisar("Todo eso ya estaba en el alcance de ese proyecto"); return; }
    if (!confirm(`Se van a añadir ${nuevos.length} puntos al alcance de ${p.nombre}. ¿Sigo?`)) return;

    try {
      // TODOS con prioridad 'normal'. La base tiene un disparador que ante
      // 'urgente' manda un aviso al teléfono de TODO el equipo, y esto es
      // el alcance de una obra que puede no estar vendida todavía.
      const base = ((state && state.puntos) ? state.puntos : []).filter(x => x.proyecto === p.id).length;
      await DB.crearPuntos(nuevos.map((texto, i) => ({
        proyecto_id: p.id, texto, hecho: false, orden: base + i, prioridad: "normal"
      })));
      l.proyecto_id = p.id;
      levTocado(false);
      await recargar();
      avisar(`${nuevos.length} puntos añadidos al alcance de ${p.nombre} ✓`);
    } catch (err) { avisar("No se pudo guardar el alcance: " + err.message, true); }
  }

  // ---------- La lista de levantamientos ----------
  function pintarLevLista() {
    const locales = levLeerLocales();
    const deNube = (levData && levData.levantamientos) ? levData.levantamientos : [];
    const todos = deNube.slice();
    locales.forEach(x => { if (!todos.some(y => y.llave_cliente === x.llave_cliente)) todos.push(x); });
    const filas = todos.map(x => {
      const cuartos = (levData && levData.cuartos ? levData.cuartos : []).filter(c => c.levantamiento_id === x.id).length
        || (x.cuartos || []).length;
      return `
        <div class="mat-item">
          <span class="recibo-chip ${x.estado === "convertido" ? "insp-paso" : "por_leer"}">${x.estado === "convertido" ? "CONVERTIDO ✓" : "ABIERTO"}</span>
          <span class="alcance-info lev-abrir" data-k="${esc(x.llave_cliente)}" style="cursor:pointer">
            <span class="alcance-titulo">${esc(x.nombre)}</span>
            <span class="alcance-estado">${esc(x.cliente || "sin cliente")} · ${cuartos} cuarto${cuartos === 1 ? "" : "s"}</span>
          </span>
          <button class="lev-btn-ico lev-borrar" data-k="${esc(x.llave_cliente)}" data-id="${x.id || ""}" title="Eliminar">${levIco("papelera", 19)}</button>
        </div>`;
    }).join("");
    $("levantamiento-panel").innerHTML = `
      <div class="cal-panel-card">
        <button type="button" class="accion" id="lev-crear">Empezar un levantamiento</button>
        <p class="lev-nota">Seis fichas: la casa, el panel, los cuartos, lo que se ve, cuatro medidas y el resumen. Se guarda solo, aunque no haya señal.</p>
      </div>
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Mis levantamientos (${todos.length})</div>
        ${filas || `<p class="cal-sin-eventos">Todavía no hay ninguno.</p>`}
      </div>`;
    $("lev-crear").addEventListener("click", () => irLevantamiento());
    $("levantamiento-panel").querySelectorAll(".lev-abrir").forEach(el => {
      el.addEventListener("click", () => irLevantamiento(el.dataset.k));
    });
    $("levantamiento-panel").querySelectorAll(".lev-borrar").forEach(b => {
      b.addEventListener("click", async () => {
        if (!confirm("¿Eliminar este levantamiento con todos sus cuartos?")) return;
        try {
          if (b.dataset.id) await DB.eliminarLevantamiento(Number(b.dataset.id));
          const x = todos.find(y => y.llave_cliente === b.dataset.k);
          if (x) levBorrarLocal(x);
          await recargarLevantamientos();
          avisar("Levantamiento eliminado ✓");
        } catch (err) { avisar("No se pudo eliminar: " + err.message, true); }
      });
    });
  }

  function irLevLista() {
    if (!usuario.finanzas) return;
    mostrar("levantamiento", { kicker: "Solo dueño", titulo: "Levantamientos", volver: true, nuevo: false });
    levActivo = null; levCuartoAbierto = null;
    $("levantamiento-panel").innerHTML = `<div class="inicio-card"><p class="cal-sin-eventos">Cargando…</p></div>`;
    recargarLevantamientos();
  }

  async function recargarLevantamientos() {
    try { levData = await DB.cargarLevantamientos(); }
    catch { levData = levData || { levantamientos: [], cuartos: [] }; levSinSenal = true; }
    if (!estData) { try { estData = await DB.cargarEstimador(); } catch { /* sin señal: se apunta igual */ } }
    if (!levActivo) pintarLevLista();
  }

  // ---------- Arranque ----------
  if (DB.haySesion()) {
    // Sesión guardada: refrescar el token y entrar directo
    const arrancarConSesion = () => DB.refrescar()
      .then(arrancarApp)
      .catch(err => {
        if (esFalloDeRed(err)) {
          // Sin señal al abrir: la sesión se queda guardada
          pantallaSinSenal(arrancarConSesion);
          return;
        }
        // Solo se borra la sesión si el servidor dijo que el token NO sirve.
        // Si contestó 500 o no contestó, la sesión se queda y se ofrece
        // reintentar: un Supabase caído no puede dejar al equipo fuera.
        if (esSesionMuerta(err)) { DB.salir(); $login.hidden = false; }
        else pantallaSinSenal(arrancarConSesion);
      });
    arrancarConSesion();
  } else {
    $login.hidden = false;
  }

  // Si el teléfono recupera la señal, se reintenta solo
  window.addEventListener("online", () => {
    const c = document.getElementById("sin-senal");
    if (c && !c.hidden) { c.hidden = true; if (DB.haySesion()) arrancarApp(); }
  });
})();
