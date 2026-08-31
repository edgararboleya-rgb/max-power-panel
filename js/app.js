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
    enviado:     { etiqueta: "Enviado" },
    aprobado:    { etiqueta: "Aprobado" },
    ejecucion:   { etiqueta: "En ejecución" },
    pausa:       { etiqueta: "En pausa" },
    completado:  { etiqueta: "Completado" },
    no_aprobado: { etiqueta: "No aprobado" }
  };
  const DOT = { enviado: "navy", aprobado: "azul", ejecucion: "cyan", pausa: "amarillo", completado: "lima", no_aprobado: "rojo" };
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
    pausa: "Detenidos temporalmente",
    completado: "Terminados y cerrados",
    no_aprobado: "No salieron — fuera de las estadísticas"
  };
  const ORDEN_ETAPAS = ["ejecucion", "aprobado", "enviado", "pausa", "completado", "no_aprobado"];
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
      .filter(i => i.fecha && i.resultado === "programada")
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
    } catch (err) {
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

  // ---------- Cambio de vista ----------
  function mostrar(vista, { kicker, titulo, volver, nuevo }) {
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
    DB.cargarTodo()
      .then(s => {
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
      }).catch(() => {});
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

  function pintarInicioNotif() {
    const caja = $("inicio-notif");
    if (!caja) return;
    const soporta = "serviceWorker" in navigator && "PushManager" in window && location.protocol.startsWith("http");
    if (!usuario.finanzas || !soporta || (window.Notification && Notification.permission === "granted")) {
      caja.innerHTML = ""; return;
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
    if (!usuario.finanzas) { $("inicio-equipo").innerHTML = ""; return; }
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

  function pintarCategorias() {
    const lista = proyectos();
    $categorias.innerHTML = Object.entries(TIPOS).map(([clave, t]) => {
      const del = lista.filter(p => (p.tipo || "residencial") === clave);
      const activos = del.filter(p => p.estado !== "completado");
      const enObra = del.filter(p => p.estado === "ejecucion").length;
      const dineroLinea = usuario.finanzas
        ? `<div class="cat-dinero">${fmt(activos.filter(p => typeof p.contrato === "number").reduce((s, p) => s + p.contrato, 0))} contratado activo</div>`
        : "";
      return `
        <button class="categoria-card" data-tipo="${clave}">
          <div class="cat-icono">${t.icono}</div>
          <div class="cat-info">
            <div class="cat-nombre">${t.etiqueta}</div>
            <div class="cat-conteo">${activos.length} activos · ${enObra} en ejecución</div>
            ${dineroLinea}
          </div>
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
    const activos = lista.filter(p => p.estado !== "completado" && p.estado !== "no_aprobado");
    const contratado = lista
      .filter(p => !["completado", "no_aprobado"].includes(p.estado) && typeof p.contrato === "number")
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
    if (!usuario.finanzas || !p.hitos || !p.hitos.length) return "";
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
            title="Crea la factura en QuickBooks con las reglas de la casa">🧾</button>` : ""}
        </div>`;
    }).join("");
    const porCobrarTotal = p.hitos.filter(h => h.estado !== "cobrado").reduce((s, h) => s + h.monto, 0);
    return `
      <div class="detalle-seccion">
        <h3>Hitos de pago</h3>
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
        <button class="tarea-editar insp-borrar" title="Corregir el texto">✎</button>
        ${usuario.editar ? `<button class="tarea-borrar insp-borrar" title="Eliminar">🗑</button>` : ""}
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
          await recargar();
          avisar(estaHecha ? "Tarea devuelta a pendiente" : "Tarea completada ✓");
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
          await recargar();
          avisar(nueva === "urgente"
            ? "🔴 Urgente — sale en el inicio y avisa al equipo"
            : `Categoría: ${PRIO[nueva].icono} ${PRIO[nueva].etiqueta}`);
        } catch (err) { avisar("No se pudo: " + err.message, true); }
      });
    });
    raiz.querySelectorAll(".tarea-editar").forEach(btn => {
      btn.addEventListener("click", async () => {
        const { tipo, id, fila } = dato(btn);
        const actual = fila.querySelector(".tarea-texto").textContent;
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
          <span class="alcance-titulo">${esc(sinMontos(m.descripcion))}${m.cantidad ? ` <span class="mat-cant">— ${esc(m.cantidad)}</span>` : ""}</span>
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
    return `<select class="chip-select" data-id="${esc(p.id)}" title="Cambiar estado">
        ${opciones}
        <option disabled>──────</option>
        <option value="__eliminar">🗑 Eliminar proyecto…</option>
      </select>`;
  }

  async function cambiarEstadoDirecto(id, valor, selectEl) {
    const p = proyectos().find(x => x.id === id);
    if (!p) return;
    if (valor === "__eliminar") {
      selectEl.value = p.estado; // regresa el selector mientras confirmamos
      if (!confirm(`¿Eliminar "${p.nombre}" para siempre?\n\nSe borra el proyecto con sus finanzas, hitos, horas y pendientes. Esto no se puede deshacer.`)) return;
      try {
        await DB.eliminarProyecto(id);
        state.proyectos = state.proyectos.filter(x => x.id !== id);
        refrescarVistaProyecto();
        avisar(`"${p.nombre}" eliminado.`);
      } catch (err) {
        avisar("No se pudo eliminar: " + err.message, true);
      }
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

  function avisoFacturasHTML(p) {
    if (!usuario.finanzas) return "";
    const pend = facturasPendientes(p);
    return pend.length
      ? `<div class="aviso-pendiente">⚠ Factura sin pagar: ${pend.map(f => `#${esc(f.num)} ${fmt(f.monto)}`).join(", ")}</div>`
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
    return `
      <div class="proyecto-money">
        <div class="money-item"><div class="money-label">Contrato</div><div class="money-num contrato">${fmt(p.contrato)}</div></div>
        <div class="money-item"><div class="money-label">Cobrado</div><div class="money-num cobrado">${fmt(p.cobrado)}</div></div>
        <div class="money-item"><div class="money-label">Falta</div><div class="money-num falta">${fmt(falta)}</div></div>
      </div>
      ${barra}`;
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
        <button type="button" class="doc-cliente doc-portal${d.portal ? " on" : ""}" data-id="${d.id}" data-portal="${d.portal ? 1 : 0}"
          title="${d.portal ? "El cliente SÍ ve este documento — toca para ocultarlo" : "El cliente NO lo ve — toca para mostrárselo"}">${d.portal ? "👁 cliente" : "🚫 cliente"}</button>${(d.portal || p.portalCompleto) && docFirmable(d) ? `
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
           <p class="modal-nota">El cliente ve: etapa, checklist con su %, inspecciones, próximos días de trabajo y los documentos con 👁.
           Los RFI salen siempre; los CONTRATOS nunca salen (tienen precios) a menos que tú los marques.
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
        </div>
      </article>`;
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
          <button type="button" class="doc-cliente foto-cliente${f.portal ? " on" : ""}" data-id="${f.id}" data-portal="${f.portal ? 1 : 0}"
            title="${f.portal ? "El cliente SÍ ve esta foto" : "El cliente NO la ve"}">${f.portal ? "👁" : "🚫"}</button>
          <button type="button" class="doc-cliente foto-nota" data-id="${f.id}" data-nota="${esc(f.nota || "")}"
            title="Corregir la descripción de la foto">✎</button>` : (f.autorId === usuario.id ? `
          <button type="button" class="doc-cliente foto-nota" data-id="${f.id}" data-nota="${esc(f.nota || "")}"
            title="Corregir la descripción de tu foto">✎</button>` : "")}</figcaption>
      </figure>`).join("");
    return `
      <div class="detalle-seccion">
        <h3>Fotos de obra</h3>
        ${items ? `<div class="fotos-grid">${items}</div>` : `<span class="sin-docs">Sin fotos todavía.</span>`}
        <button type="button" class="accion secundaria btn-agregar-foto">📸 Agregar foto o video</button>
        <form class="cal-form form-foto" hidden>
          <label>Foto o video corto (cámara o galería)
            <input name="archivo" type="file" accept="image/*,video/mp4,video/quicktime,video/webm" required>
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
        const archivo = formFoto.elements.archivo.files[0];
        if (!archivo) return;
        const nota = (formFoto.elements.nota.value || "").trim() || null;
        const $btn = formFoto.querySelector('button[type="submit"]');
        $btn.disabled = true;
        $btn.textContent = "Subiendo…";
        try {
          // Algunos teléfonos mandan el video sin tipo: también se mira la extensión
          const esVid = (archivo.type || "").startsWith("video/") || /\.(mp4|mov|webm)$/i.test(archivo.name || "");
          if (esVid && archivo.size > 50 * 1024 * 1024) {
            avisar("Ese video es muy grande. Grábalo CORTO, como una inspección virtual (30-45 segundos, máx. 50 MB).", true);
            $btn.disabled = false;
            $btn.textContent = textoSubir();
            return;
          }
          // Foto: se achica antes de subir. Video: sube tal cual.
          const blob = esVid ? archivo : await reducirImagen(archivo).catch(() => archivo);
          const tipoSubida = blob.type || archivo.type || (esVid ? "video/mp4" : "image/jpeg");
          const ruta = await DB.subirFoto(p.id, blob, tipoSubida);
          await DB.crearFoto({ proyecto_id: p.id, ruta, nota });
          await recargar();
          avisar(esVid ? "Video subido ✓" : "Foto subida ✓");
        } catch (err) {
          avisar("No se pudo subir: " + err.message, true);
          $btn.disabled = false;
          $btn.textContent = textoSubir();
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
      }).catch(() => {});
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
      }).catch(() => {});
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
    const estado = d.get("estado") || "enviado";
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
      irLista(estado);
      avisar("Proyecto creado ✓");
    } catch (err) {
      avisar("No se pudo crear: " + err.message, true);
    }
  });

  // ============================================================
  // MIS HORAS — guarda directo en la nube
  // ============================================================
  function irHoras() {
    mostrar("horas", { kicker: "Reporte diario", titulo: "Mis horas", volver: true, nuevo: false });
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
    $formHoras.elements.proyecto.innerHTML = proyectosConTrabajo()
      .map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("");
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

  $formHoras.addEventListener("submit", async e => {
    e.preventDefault();
    const d = new FormData($formHoras);
    const proyectoId = d.get("proyecto");
    const pendiente = (d.get("pendiente") || "").toString().trim();
    const fila = {
      fecha: d.get("fecha"),
      proyecto_id: proyectoId,
      fase: d.get("fase"),
      horas: Number(d.get("horas")),
      notas: (d.get("notas") || "").toString().trim() || null,
      co: (d.get("co") || "").toString().trim() || null
    };
    if (fila.co === "__otro__") {
      const escrito = prompt("¿De cuál Change Order fue el trabajo? (Ej: CO #2)");
      if (escrito === null) return;
      fila.co = escrito.trim() || null;
    }
    try {
      await DB.reportarHoras(fila);
      if (pendiente) {
        await DB.crearPendiente({
          fecha: fila.fecha, proyecto_id: proyectoId, descripcion: pendiente,
          prioridad: d.get("urgente") ? "urgente" : "normal"
        });
      }
      $formHoras.elements.horas.value = "";
      $formHoras.elements.notas.value = "";
      $formHoras.elements.co.value = "";
      $formHoras.elements.pendiente.value = "";
      await recargar();
      avisar(pendiente ? "Horas y pendiente guardados ✓ (el pendiente queda en rojo)" : "Horas guardadas ✓");
    } catch (err) {
      avisar("No se pudo guardar: " + err.message, true);
    }
  });

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
          <span class="alcance-titulo">${esc(sinMontos(m.descripcion))}${m.cantidad ? ` <span class="mat-cant">— ${esc(m.cantidad)}</span>` : ""}</span>
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
        for (const m of items) texto += `• ${alSupply(m.descripcion)}${m.cantidad ? ` — ${alSupply(m.cantidad)}` : ""}\n`;
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
      }).catch(() => {});
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
        ${extGasto > 0 ? `<div class="rent-fila"><span>Ayuda externa</span><span>${fmt(extGasto)}</span></div>` : ""}`;
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

  async function recargarEstimador() {
    try {
      estData = await DB.cargarEstimador();
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

    const matItems = base.reduce((s, i) => s + n(i.cantidad) * n(i.precio), 0)
      + autos.reduce((s, i) => s + n(i.cantidad) * n(i.precio), 0) + mermaMat;
    const misc = matItems * miscPct;
    const matSubtotal = matItems + misc;
    const tax = matSubtotal * taxPct;
    // Markup: es de MATERIALES — va después del sales tax
    const markup = (matSubtotal + tax) * markupPct;
    const totalMaterial = matSubtotal + tax + markup;

    const horasBase = base.reduce((s, i) => s + n(i.cantidad) * n(i.horas), 0)
      + autos.reduce((s, i) => s + n(i.cantidad) * n(i.horas), 0) + mermaHoras;
    const horas = horasBase * (n(est.factor) || 1);
    const laborBase = horas * (n(esc.pct_foreman) * n(esc.foreman)
      + n(esc.pct_journeyman) * n(esc.journeyman) + n(esc.pct_helper) * n(esc.helper));
    const benefits = laborBase * n(esc.benefits);
    const totalLabor = laborBase + benefits;
    const prime = totalLabor + totalMaterial;
    const overhead = horas * ohHH;
    const profit = (prime + overhead) * profitPct;
    const bid = prime + overhead + profit;
    return { items: base, autos, mermaMat, mermaHoras, misc, esc, matSubtotal, tax,
             totalMaterial, horasBase, horas, laborBase, benefits, totalLabor,
             prime, overhead, profit, markup, bid,
             miscPct, taxPct, ohHH, profitPct, markupPct };
  }

  // Overhead real: gastos generales ÷ horas-hombre reales (últimos 90 días)
  function overheadReal() {
    const horas = estData.horasTodas || [];
    if (!horas.length) return null;
    const desde = new Date(); desde.setDate(desde.getDate() - 90);
    const iso = fechaISO(desde.getFullYear(), desde.getMonth(), desde.getDate());
    const total = horas.filter(h => h.fecha >= iso).reduce((s, h) => s + Number(h.horas || 0), 0);
    const hMes = total / 3;
    if (hMes < 40) return null; // muy poca historia todavía
    const gastos = (estData.generales || []).reduce((s, g) => s + Number(g.monto_mensual || 0), 0);
    if (!gastos) return null;
    return Math.round((gastos / hMes) * 100) / 100;
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
      <div class="cal-panel-card">
        <form id="form-nuevo-est" class="cal-form">
          <div class="cal-form-titulo">➕ Nuevo estimado</div>
          <label>¿Cómo vas a estimar este trabajo?
            <select name="modo">
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
      </div>`;

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
          // Servicio arranca en C (margen sano), como estima Edgar
          escenario: modoNuevo === "servicio" ? "C" : (d.get("escenario") || "B"),
          factor: 1,
          estado: "borrador",
          modo: modoNuevo,
          cable: "romex"
        });
        estimadoActivo = filasNueva[0].id;
        await recargarEstimador();
        avisar("Estimado creado ✓ — busca ítems del catálogo y ponles cantidad");
      } catch (err) { avisar("No se pudo crear: " + err.message, true); }
    });
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

  function pintarEstimadorEditor() {
    const est = (estData.estimados || []).find(x => x.id === estimadoActivo);
    if (!est) { estimadoActivo = null; pintarEstimadorLista(); return; }
    if (!est.estado) est.estado = "borrador";
    if (!est.modo) est.modo = "planos";
    const c = calcularEstimado(est);
    const soloLectura = est.estado !== "borrador";
    const r2 = v => Math.round(v * 100) / 100;
    const MODO_ETIQ = { planos: "📐 Por planos", remodelacion: "🏠 Remodelación", servicio: "🔧 Servicio" };

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

    const oReal = overheadReal();
    const bannerOverhead = usuario.finanzas && oReal
      && Math.abs(oReal - Number(c.esc.overhead_hh)) / Number(c.esc.overhead_hh) > 0.05
      ? `<div class="inicio-card avisos">
           <div class="aviso-texto" style="padding:.2rem 0">⚙ Tu overhead REAL (últimos 90 días) es
           <strong>${fmt(oReal)}/h-h</strong> — los escenarios usan ${fmt(c.esc.overhead_hh)}.
           <button class="accion secundaria" id="btn-overhead-real">Actualizar escenarios a ${fmt(oReal)}</button></div>
         </div>` : "";

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
      ${est.modo === "planos" && !soloLectura ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">📥 Takeoff de Bluebeam</div>
        <p class="modal-nota">En Bluebeam: Markups List → Export → CSV. Abre el archivo, copia todo y pégalo aquí.</p>
        <textarea id="takeoff-texto" rows="4" placeholder="Pega aquí el export…"
          style="width:100%;font:inherit;font-size:.8rem;padding:.55rem .7rem;border:1px solid var(--mp-line);border-radius:10px"></textarea>
        <button type="button" class="accion secundaria" id="btn-takeoff-analizar" style="margin-top:.45rem">🔎 Analizar</button>
        <div id="takeoff-preview"></div>
      </div>` : ""}
      ${est.modo !== "planos" && (ensDisponibles.length || !soloLectura) ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🧩 Ensambles — cuenta como piensas</div>
        ${filasEnsambles || `<p class="cal-sin-eventos">Los ensambles se siembran al correr el SQL v2.</p>`}
      </div>` : ""}
      ${cardFrecuentes}
      ${!soloLectura ? `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">🔎 Buscar en el catálogo (${(estData.catalogo || []).length})</div>
        <input id="est-buscar" type="text" placeholder="Ej: recessed, breaker gfci, 12/2…" autocomplete="off"
          style="width:100%;font:inherit;padding:.55rem .7rem;border:1px solid var(--mp-line);border-radius:10px">
        <div id="est-resultados"></div>
        <button type="button" class="accion secundaria" id="btn-cat-nuevo" style="margin-top:.45rem">➕ Crear ítem nuevo en el catálogo</button>
      </div>` : ""}
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Ítems (${c.items.length}${c.autos.length ? ` + ${c.autos.length} automáticos` : ""})</div>
        ${filasItems || `<p class="cal-sin-eventos">Agrega ensambles, pega el takeoff o busca en el catálogo.</p>`}
        ${filasAutos}
      </div>
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
        <div class="rent-fila"><span>Material (ítems${c.autos.length ? " + automáticos" : ""})</span><span>${fmt(r2(c.matSubtotal - c.misc - c.mermaMat))}</span></div>
        ${c.mermaMat > 0 ? `<div class="rent-fila"><span>+ Merma (cables ${Math.round((estData.config.merma_cable ?? .1) * 100)}% · tubería ${Math.round((estData.config.merma_tuberia ?? .05) * 100)}%)</span><span>${fmt(r2(c.mermaMat))}</span></div>` : ""}
        <div class="rent-fila"><span>+ Misceláneas (${pctTxt(c.miscPct)}${nnDist(est.misc_pct) ? " ✏" : " — tape, wirenuts, fijación"})${lapiz("misc_pct", "pct", c.miscPct, "Misceláneas — % del material")}</span><span>${fmt(r2(c.misc))}</span></div>
        <div class="rent-fila"><span>+ Sales tax (${pctTxt(c.taxPct)}${nnDist(est.tax_pct) ? " ✏" : ""})${lapiz("tax_pct", "pct", c.taxPct, "Sales tax — % del material")}</span><span>${fmt(r2(c.tax))}</span></div>
        ${c.markupPct > 0 ? `<div class="rent-fila"><span>+ Markup de materiales (${pctTxt(c.markupPct)}) ✏${lapiz("markup_pct", "pct", c.markupPct, "Markup de materiales — % sobre el material con tax")}</span><span>${fmt(r2(c.markup))}</span></div>`
          : !soloLectura ? `<div class="rent-fila"><span><button type="button" class="btn-formula insp-borrar" data-campo="markup_pct" data-tipo="pct" data-actual="0" data-nombre="Markup de materiales — % sobre el material con tax">+ Agregar markup de materiales</button></span><span></span></div>` : ""}
        <div class="rent-fila"><span>Horas de TODO el trabajo (${r2(c.horasBase)} × factor ${est.factor || 1})</span><span>${r2(c.horas)} h</span></div>
        <div class="rent-fila"><span>Labor + benefits (${Math.round(c.esc.benefits * 100)}%)</span><span>${fmt(r2(c.totalLabor))}</span></div>
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

    // --- overhead real ---
    const btnOver = $("btn-overhead-real");
    if (btnOver) btnOver.addEventListener("click", async () => {
      try {
        await DB.actualizarOverhead(oReal);
        await recargarEstimador();
        avisar(`Overhead actualizado a ${fmt(oReal)}/h-h en los 3 escenarios ✓`);
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

      celdas += `<button class="${clases}" data-fecha="${iso}">
          <span class="cal-num">${d}</span>
          ${evsDia.length ? `<span class="cal-marca">${evsDia.length}</span>` : ""}
          ${pensDia.length ? `<span class="cal-marca-roja">⚠</span>` : ""}
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
              ${usuario.finanzas ? `<button type="button" class="insp-borrar ev-borrar" data-id="${e.id}" title="Eliminar este evento">🗑</button>` : ""}
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

  // ---------- Arranque ----------
  if (DB.haySesion()) {
    // Sesión guardada: refrescar el token y entrar directo
    DB.refrescar()
      .then(arrancarApp)
      .catch(() => { DB.salir(); $login.hidden = false; });
  } else {
    $login.hidden = false;
  }
})();
