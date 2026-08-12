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
    else { pintarCategorias(); pintarResumen(); }
  }

  // ---------- Cambio de vista ----------
  function mostrar(vista, { kicker, titulo, volver, nuevo }) {
    $home.hidden = vista !== "home";
    $vEtapas.hidden = vista !== "etapas";
    $vLista.hidden = vista !== "lista";
    $vHoras.hidden = vista !== "horas";
    $vCal.hidden = vista !== "calendario";
    $vDetalle.hidden = vista !== "detalle";
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
    pintarCategorias();
    pintarResumen();
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
          ${rfisHTML(p)}
          ${fotosHTML(p)}
          ${accionesHTML(p)}
          ${facturasHTML(p)}
          ${docs}
          <div class="detalle-ref">Ref: ${esc(sinMontos(p.ref))}</div>
        </div>
      </article>`;
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
    $("horas-historial").innerHTML = mios.length
      ? `<h3 class="historial-titulo">Mis reportes</h3>` + mios.slice(-10).reverse()
          .map(r => {
            const p = proyectos().find(x => x.id === r.proyecto);
            return `<div class="alcance-item">
              <span class="alcance-tipo">${esc(r.horas)}h</span>
              <span class="alcance-info">
                <span class="alcance-titulo">${esc(p ? p.nombre : r.proyecto)}</span>
                <span class="alcance-estado">${esc(r.fecha)}${r.fase ? " · " + esc(r.fase) : ""}${r.notas ? " · " + esc(r.notas) : ""}</span>
              </span>
            </div>`;
          }).join("")
      : "";
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
    const evs = eventos();
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

    const evsDia = eventos().filter(e => e.fecha === calDiaSel);
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
