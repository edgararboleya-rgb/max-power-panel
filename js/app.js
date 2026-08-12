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
  const TIPOS = {
    comercial:   { etiqueta: "Proyectos Comerciales",   icono: "🏢" },
    residencial: { etiqueta: "Proyectos Residenciales", icono: "🏠" },
    servicio:    { etiqueta: "Servicios",               icono: "🔧" }
  };
  const ESTADOS = {
    enviado:    { etiqueta: "Enviado" },
    aprobado:   { etiqueta: "Aprobado" },
    ejecucion:  { etiqueta: "En ejecución" },
    pausa:      { etiqueta: "En pausa" },
    completado: { etiqueta: "Completado" }
  };
  const DOT = { enviado: "navy", aprobado: "azul", ejecucion: "cyan", pausa: "amarillo", completado: "lima" };
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
    completado: "Terminados y cerrados"
  };
  const ORDEN_ETAPAS = ["ejecucion", "aprobado", "enviado", "pausa", "completado"];
  const ROL_ETIQUETA = { dueno: "Dueño", campo: "Campo", license: "License Holder" };
  // usuario corto → email de la cuenta
  const EMAILS = { edgar: "edgararboleya@mxpes.com" };

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
  const $vMat = $("vista-materiales"), $vCostos = $("vista-costos");
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
    return `<span class="chip"><span class="dot ${DOT[clave] || "navy"}"></span>${e.etiqueta}</span>`;
  };
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
    irHome();
  }

  function salirApp() {
    DB.salir();
    state = null;
    usuario = null;
    $app.hidden = true;
    $login.hidden = false;
  }
  $btnSalir.addEventListener("click", salirApp);

  async function recargar(abrirId) {
    try {
      state = await DB.cargarTodo();
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
    else if (!$vCostos.hidden) pintarCostos();
    else if (!$("vista-gastos").hidden) pintarGastos();
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
    $vCostos.hidden = vista !== "costos";
    $("vista-gastos").hidden = vista !== "gastos";
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
    $("btn-costos").hidden = !usuario.finanzas;
    $("btn-gastos").hidden = !usuario.finanzas;
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
    pintarInicioAvisos();
    pintarInicioEquipo();
  }

  // Franja "HOY": lo de hoy y mañana + los pendientes rojos (todos la ven)
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

    const maxPens = pens.slice(0, 3);
    const filasPen = maxPens.map(x => `
      <div class="hoy-item rojo">
        <span class="hoy-chip es-rojo">🔴</span>
        <span class="alcance-info">
          <span class="alcance-titulo">${esc(sinMontos(x.descripcion))}</span>
          <span class="alcance-estado">${esc(nombreProyecto(x.proyecto))}${x.autor ? " · " + esc(x.autor) : ""}</span>
        </span>
      </div>`).join("") +
      (pens.length > 3 ? `<div class="hoy-mas">+ ${pens.length - 3} pendientes más en el calendario</div>` : "");

    $("inicio-hoy").innerHTML = `
      <div class="inicio-card">
        <div class="inicio-card-titulo">📅 Hoy en Max Power</div>
        ${filasEv || ""}
        ${filasPen || ""}
        ${!evs.length ? `<div class="hoy-mas">Nada programado para hoy ni mañana.</div>` : ""}
      </div>`;
  }

  // Avisos del dueño: plata y proyectos que piden atención
  function pintarInicioAvisos() {
    if (!usuario.finanzas) { $("inicio-avisos").innerHTML = ""; return; }
    const avisos = [];
    // Materiales que el equipo pidió y siguen sin comprarse
    const porComprar = (state.materiales || []).filter(m => m.estado === "falta").length;
    if (porComprar)
      avisos.push({ accion: "materiales", icono: "🛒", texto: `${porComprar} material${porComprar > 1 ? "es" : ""} por comprar — toca para ver la lista` });
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
      btn.addEventListener("click", () =>
        btn.dataset.accion === "materiales" ? irMateriales() : irDetalle(btn.dataset.id));
    });
  }

  // ¿Quién reportó horas? (solo dueño)
  function pintarInicioEquipo() {
    if (!usuario.finanzas) { $("inicio-equipo").innerHTML = ""; return; }
    const equipo = (state.equipo || []).filter(u => u.rol !== "dueno");
    if (!equipo.length) { $("inicio-equipo").innerHTML = ""; return; }
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
      return `<div class="equipo-item">
          <span class="equipo-dot ${clase}"></span>
          <span class="alcance-info">
            <span class="alcance-titulo">${esc(u.nombre)}</span>
            <span class="alcance-estado">${texto}</span>
          </span>
        </div>`;
    }).join("");
    $("inicio-equipo").innerHTML = `
      <div class="inicio-card">
        <div class="inicio-card-titulo">⏱ Reporte de horas del equipo</div>
        ${filas}
      </div>`;
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
    const activos = lista.filter(p => p.estado !== "completado");
    const contratado = lista
      .filter(p => p.estado !== "completado" && typeof p.contrato === "number")
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
      if (n === 0 && (clave === "pausa" || clave === "completado")) return "";
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
    if (!$vDetalle.hidden) {
      proyectoActivo = null;
      if (tipoActivo && etapaActiva) { irLista(etapaActiva); return; }
      irHome();
      return;
    }
    if (!$vLista.hidden) { irEtapas(tipoActivo); return; }
    irHome();
  });

  function pintarLista(abrirId) {
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

    // Tocar la tarjeta abre la ficha del proyecto (su propia pantalla)
    $lista.querySelectorAll(".proyecto").forEach(card => {
      card.addEventListener("click", () => irDetalle(card.dataset.id));
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
  // Materiales comprados con precio anotado
  const gastoMateriales = pid => (state.materiales || [])
    .filter(m => m.proyecto === pid && m.estado === "comprado" && typeof m.precio === "number")
    .reduce((s, m) => s + m.precio, 0);
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
        <p>Define el costo por hora del equipo en <strong>💲 Costos del equipo</strong>
        (botón del inicio) y aquí verás la ganancia real de este proyecto.</p></div>`;
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
        ${r.url ? `<a class="doc-link" href="${esc(r.url)}" target="_blank" rel="noopener">📄 Ver</a>` : ""}
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
            <div class="proyecto-cliente">Cliente: <strong>${esc(p.cliente)}</strong> · vía ${esc(p.via)}</div>
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
    return `
      <article class="proyecto" data-id="${esc(p.id)}">
        ${cabeceraHTML(p, false)}
        ${avisoObraHTML(p)}
        ${avisoMaterialesHTML(p)}
        ${avisoFacturasHTML(p)}
        ${franjaDineroHTML(p)}
        ${proximoCobroHTML(p)}
        <div class="abrir-ficha">Ver proyecto completo <span class="cat-flecha">›</span></div>
      </article>`;
  }

  // FICHA completa: la pantalla dedicada a un solo proyecto
  function fichaProyectoHTML(p) {
    const linksDocs = (p.docs || [])
      .map(d => `<a class="doc-link" href="${esc(d.url)}" target="_blank" rel="noopener">📄 ${esc(d.titulo)}</a>`)
      .join("");
    // El dueño siempre ve la sección, con el botón para agregar más
    const docs = usuario.finanzas
      ? `<div class="detalle-seccion">
           <h3>Documentos en Drive</h3>
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
             <label>Enlace (pega aquí el link de Drive)
               <input name="url" type="url" required placeholder="https://drive.google.com/…" autocomplete="off">
             </label>
             <button type="submit" class="accion">Guardar documento</button>
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
        <a class="foto-enlace" data-ruta="${esc(f.ruta)}" target="_blank" rel="noopener">
          <img class="foto-mini" data-ruta="${esc(f.ruta)}" alt="${esc(f.nota || "Foto de obra")}" loading="lazy">
        </a>
        <figcaption class="foto-pie">${f.nota ? esc(sinMontos(f.nota)) + " · " : ""}${esc(f.autor)} ${esc(f.fecha)}</figcaption>
      </figure>`).join("");
    return `
      <div class="detalle-seccion">
        <h3>Fotos de obra</h3>
        ${items ? `<div class="fotos-grid">${items}</div>` : `<span class="sin-docs">Sin fotos todavía.</span>`}
        <button type="button" class="accion secundaria btn-agregar-foto">📸 Agregar foto</button>
        <form class="cal-form form-foto" hidden>
          <label>Foto (cámara o galería)
            <input name="archivo" type="file" accept="image/*" required>
          </label>
          <label>Nota (opcional)
            <input name="nota" type="text" placeholder="Ej: rough del segundo piso terminado" autocomplete="off">
          </label>
          <button type="submit" class="accion">⬆ Subir foto</button>
        </form>
      </div>`;
  }

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
    const btnDoc = $detalle.querySelector(".btn-agregar-doc");
    if (btnDoc) {
      const formDoc = $detalle.querySelector(".form-doc");
      btnDoc.addEventListener("click", () => { formDoc.hidden = !formDoc.hidden; });
      formDoc.addEventListener("submit", async e => {
        e.preventDefault();
        const d = new FormData(formDoc);
        const clase = d.get("clase") === "rfi" ? "rfi" : "doc";
        try {
          await DB.crearDocumento({
            proyecto_id: p.id,
            clase,
            titulo: (d.get("titulo") || "").toString().trim(),
            url: (d.get("url") || "").toString().trim(),
            estado: clase === "rfi" ? "Abierto" : null
          });
          await recargar();
          avisar(clase === "rfi" ? "RFI guardado ✓" : "Documento guardado ✓");
        } catch (err) {
          avisar("No se pudo guardar: " + err.message, true);
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

    // "+ Anotar trabajo externo" (solo dueño)
    const btnExt = $detalle.querySelector(".btn-agregar-ext");
    if (btnExt) {
      const formExt = $detalle.querySelector(".form-ext");
      btnExt.addEventListener("click", () => {
        formExt.hidden = !formExt.hidden;
        if (!formExt.hidden && !formExt.elements.fecha.value)
          formExt.elements.fecha.value = hoyISO();
      });
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
            costo: Number(d.get("costo"))
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
      formFoto.addEventListener("submit", async e => {
        e.preventDefault();
        const archivo = formFoto.elements.archivo.files[0];
        if (!archivo) return;
        const nota = (formFoto.elements.nota.value || "").trim() || null;
        const $btn = formFoto.querySelector('button[type="submit"]');
        $btn.disabled = true;
        $btn.textContent = "Subiendo…";
        try {
          // Si el navegador no puede achicarla, se sube tal cual
          const blob = await reducirImagen(archivo).catch(() => archivo);
          const ruta = await DB.subirFoto(p.id, blob, blob.type || archivo.type);
          await DB.crearFoto({ proyecto_id: p.id, ruta, nota });
          await recargar();
          avisar("Foto subida ✓");
        } catch (err) {
          avisar("No se pudo subir la foto: " + err.message, true);
          $btn.disabled = false;
          $btn.textContent = "⬆ Subir foto";
        }
      });
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

  function prepararHoras() {
    const f = $formHoras.elements.fecha;
    if (!f.value) f.value = new Date().toISOString().slice(0, 10);
    const activos = proyectos().filter(p => ["ejecucion", "aprobado", "pausa"].includes(p.estado));
    $formHoras.elements.proyecto.innerHTML = activos
      .map(p => `<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join("");
    pintarHistorialHoras();
  }

  function pintarHistorialHoras() {
    const mios = (state.registroHoras || []).filter(r => r.usuarioId === usuario.id);
    if (!mios.length) { $("horas-historial").innerHTML = ""; return; }

    const opcionesFase = $formHoras.elements.fase.innerHTML;
    const opcionesProyecto = r => proyectos()
      .filter(p => ["ejecucion", "aprobado", "pausa"].includes(p.estado) || p.id === r.proyecto)
      .map(p => `<option value="${esc(p.id)}"${p.id === r.proyecto ? " selected" : ""}>${esc(p.nombre)}</option>`)
      .join("");

    $("horas-historial").innerHTML =
      `<h3 class="historial-titulo">Mis reportes (toca ✎ para corregir)</h3>` +
      mios.slice(-10).reverse().map(r => {
        const p = proyectos().find(x => x.id === r.proyecto);
        return `<div class="alcance-item">
            <span class="alcance-tipo">${esc(r.horas)}h</span>
            <span class="alcance-info">
              <span class="alcance-titulo">${esc(p ? p.nombre : r.proyecto)}</span>
              <span class="alcance-estado">${esc(r.fecha)}${r.fase ? " · " + esc(r.fase) : ""}${r.notas ? " · " + esc(r.notas) : ""}</span>
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
      btn.addEventListener("click", () => {
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
      notas: (d.get("notas") || "").toString().trim() || null
    };
    try {
      await DB.reportarHoras(fila);
      if (pendiente) {
        await DB.crearPendiente({
          fecha: fila.fecha, proyecto_id: proyectoId, descripcion: pendiente
        });
      }
      $formHoras.elements.horas.value = "";
      $formHoras.elements.notas.value = "";
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

  function irMateriales() {
    mostrar("materiales", { kicker: "Compras", titulo: "Materiales", volver: true, nuevo: false });
    pintarMateriales();
  }
  $("btn-materiales").addEventListener("click", irMateriales);

  function pintarMateriales() {
    const mats = state.materiales || [];
    const faltan = mats.filter(m => m.estado === "falta");
    const comprados = mats.filter(m => m.estado === "comprado").slice(-10).reverse();
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
    const yaPasados = new Set(mats.map(m => m.origenPendiente).filter(Boolean));
    const sugeridos = pendientesAbiertos()
      .filter(x => REG_MATERIAL.test(x.descripcion) && !yaPasados.has(x.id));

    const opciones = proyectos()
      .filter(x => ["ejecucion", "aprobado", "pausa"].includes(x.estado))
      .map(x => `<option value="${esc(x.id)}">${esc(x.nombre)}</option>`).join("");

    $("materiales-panel").innerHTML = `
      <div class="cal-panel-card">
        <div class="cal-form-titulo">Por comprar (${faltan.length})</div>
        ${faltan.map(filaMat).join("") || `<p class="cal-sin-eventos">Nada pendiente de comprar. 👌</p>`}
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
        <form id="form-material" class="cal-form">
          <div class="cal-form-titulo">Agregar material</div>
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
    if (!activos.length) {
      $("gastos-panel").innerHTML = `<div class="inicio-card"><p class="cal-sin-eventos">No hay proyectos activos.</p></div>`;
      return;
    }
    const tarjetas = activos.map(p => {
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
    $("gastos-panel").innerHTML = tarjetas;

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
  // COSTOS DEL EQUIPO — solo el dueño
  // ============================================================
  function irCostos() {
    if (!usuario.finanzas) return;
    mostrar("costos", { kicker: "Solo dueño", titulo: "Costos del equipo", volver: true, nuevo: false });
    pintarCostos();
  }
  $("btn-costos").addEventListener("click", irCostos);

  function pintarCostos() {
    const costos = state.costos || {};
    const filas = Object.entries(state.nombrePorId).map(([id, nombre]) => `
      <label>${esc(nombre)} — costo por hora ($)
        <input name="c-${id}" type="number" min="0" step="0.5" inputmode="decimal"
          value="${costos[id] != null ? costos[id] : ""}" placeholder="Ej: 35">
      </label>`).join("");
    $("costos-panel").innerHTML = `
      <div class="cal-panel-card">
        <form id="form-costos" class="cal-form">
          <div class="cal-form-titulo">Costo por hora de cada trabajador</div>
          <p class="modal-nota">El costo completo para la empresa (salario + taxes + seguro).
          Solo tú ves esto — la base de datos lo protege igual que las finanzas.
          Con esto, cada proyecto te muestra su <strong>rentabilidad real</strong>.</p>
          ${filas}
          <button type="submit" class="accion">Guardar costos</button>
        </form>
      </div>`;
    $("form-costos").addEventListener("submit", async e => {
      e.preventDefault();
      const d = new FormData(e.target);
      try {
        for (const [id] of Object.entries(state.nombrePorId)) {
          const v = (d.get("c-" + id) || "").toString().trim();
          if (v !== "" && Number.isFinite(Number(v))) await DB.guardarCosto(id, Number(v));
        }
        await recargar();
        avisar("Costos guardados ✓ — ya puedes ver la rentabilidad en cada proyecto");
      } catch (err) {
        avisar("No se pudo guardar: " + err.message, true);
      }
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

  const MESES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];

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

  function pintarDiaPanel() {
    if (!calDiaSel) { $("cal-dia-panel").innerHTML = ""; return; }
    const [a, m, d] = calDiaSel.split("-").map(Number);
    const nombreDia = new Date(a, m - 1, d).toLocaleDateString("es-US", { weekday: "long", day: "numeric", month: "long" });

    const evsDia = eventosCal().filter(e => e.fecha === calDiaSel);
    const listaEvs = evsDia.length
      ? evsDia.map(e => {
          const p = e.proyecto ? proyectos().find(x => x.id === e.proyecto) : null;
          return `<div class="agenda-item${e.alerta ? " alerta" : ""}">
              <span class="agenda-hora">${esc(e.hora || "")}</span>
              <span class="agenda-info">
                <span class="agenda-titulo">${esc(sinMontos(e.titulo))}</span>
                ${p ? `<span class="agenda-lugar">🔧 ${esc(p.nombre)}</span>` : ""}
                ${e.nota ? `<span class="agenda-nota">${esc(sinMontos(e.nota))}</span>` : ""}
              </span>
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
          ${usuario.editar ? `<button class="accion secundaria btn-resolver" data-id="${p.id}">✓ Resuelto</button>` : ""}
        </div>`;
    }).join("");

    const opciones = proyectos()
      .filter(p => ["ejecucion", "aprobado", "pausa", "enviado"].includes(p.estado))
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
