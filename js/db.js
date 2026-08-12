// ============================================================
// Max Power — Conexión a la base de datos (Supabase)
// Habla con la nube usando fetch puro: autenticación (GoTrue)
// y datos (PostgREST). Sin librerías externas.
// ============================================================

(function () {
  "use strict";

  const SB = window.MAXPOWER_SUPABASE;

  // ---------- Sesión ----------
  function sesionGuardada() {
    try { return JSON.parse(localStorage.getItem("mxp_sesion")) || null; }
    catch { return null; }
  }
  function guardarSesion(s) {
    if (s) localStorage.setItem("mxp_sesion", JSON.stringify(s));
    else localStorage.removeItem("mxp_sesion");
  }

  let sesion = sesionGuardada();
  let temporizadorRefresco = null;

  function programarRefresco() {
    if (temporizadorRefresco) clearTimeout(temporizadorRefresco);
    if (!sesion || !sesion.expires_in) return;
    // Refrescar 2 minutos antes de que caduque el token
    const ms = Math.max(30, (sesion.expires_in - 120)) * 1000;
    temporizadorRefresco = setTimeout(() => { refrescar().catch(() => {}); }, ms);
  }

  async function autenticar(cuerpo, tipo) {
    const r = await fetch(`${SB.url}/auth/v1/token?grant_type=${tipo}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: SB.key },
      body: JSON.stringify(cuerpo)
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) {
      const msg = data.error_description || data.msg || data.message || "Error de autenticación";
      throw new Error(msg);
    }
    sesion = data;
    guardarSesion(sesion);
    programarRefresco();
    return sesion;
  }

  async function entrar(email, clave) {
    return autenticar({ email, password: clave }, "password");
  }

  async function refrescar() {
    if (!sesion || !sesion.refresh_token) throw new Error("Sin sesión");
    return autenticar({ refresh_token: sesion.refresh_token }, "refresh_token");
  }

  function salir() {
    sesion = null;
    guardarSesion(null);
    if (temporizadorRefresco) clearTimeout(temporizadorRefresco);
  }

  function uid() {
    return sesion && sesion.user ? sesion.user.id : null;
  }

  // ---------- Datos (PostgREST) ----------
  async function api(ruta, opciones = {}, reintento = true) {
    const r = await fetch(`${SB.url}/rest/v1/${ruta}`, {
      method: opciones.metodo || "GET",
      headers: {
        apikey: SB.key,
        Authorization: `Bearer ${sesion ? sesion.access_token : SB.key}`,
        "Content-Type": "application/json",
        Prefer: opciones.metodo && opciones.metodo !== "GET"
          ? "return=representation" : "count=none",
        ...(opciones.headers || {})
      },
      body: opciones.cuerpo ? JSON.stringify(opciones.cuerpo) : undefined
    });
    if (r.status === 401 && reintento && sesion) {
      // Token caducado: refrescar una vez y repetir
      await refrescar();
      return api(ruta, opciones, false);
    }
    if (!r.ok) {
      const data = await r.json().catch(() => ({}));
      throw new Error(data.message || data.hint || `Error ${r.status} en ${ruta}`);
    }
    if (r.status === 204) return null;
    return r.json();
  }

  const leer = ruta => api(ruta);
  const insertar = (tabla, fila) => api(tabla, { metodo: "POST", cuerpo: fila });
  const actualizar = (ruta, cambios) => api(ruta, { metodo: "PATCH", cuerpo: cambios });

  // ---------- Carga completa según el rol ----------
  async function cargarTodo() {
    const [perfiles, proyectos, finanzas, alcances, alcancesEquipo,
           hitos, facturas, horas, eventos, pendientes, documentos] =
      await Promise.all([
        leer("perfiles?select=id,nombre,rol"),
        leer("proyectos?select=*&order=nombre"),
        leer("finanzas_proyecto?select=*").catch(() => []),
        leer("alcances?select=*&order=orden").catch(() => []),
        leer("alcances_equipo?select=*&order=orden").catch(() => []),
        leer("hitos?select=*&order=orden").catch(() => []),
        leer("facturas?select=*&order=fecha").catch(() => []),
        leer("horas?select=*&order=fecha"),
        leer("eventos?select=*&order=fecha"),
        leer("pendientes?select=*&order=fecha"),
        leer("documentos?select=*").catch(() => [])
      ]);

    const nombrePorId = Object.fromEntries(perfiles.map(p => [p.id, p.nombre]));
    const miPerfil = perfiles.find(p => p.id === uid()) || null;
    const esDueno = miPerfil && miPerfil.rol === "dueno";
    const finPorProyecto = Object.fromEntries(finanzas.map(f => [f.proyecto_id, f]));
    const listaAlcances = esDueno ? alcances : alcancesEquipo;

    const agrupar = (filas, clave) => {
      const m = {};
      for (const f of filas) (m[f[clave]] = m[f[clave]] || []).push(f);
      return m;
    };
    const alcPor = agrupar(listaAlcances, "proyecto_id");
    const hitPor = agrupar(hitos, "proyecto_id");
    const facPor = agrupar(facturas, "proyecto_id");
    const horPor = agrupar(horas, "proyecto_id");
    const docPor = agrupar(documentos, "proyecto_id");

    const MES = ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
    const fechaCorta = iso => {
      if (!iso) return "";
      const [a, m, d] = String(iso).split("-").map(Number);
      return `${d} ${MES[m] || ""}`;
    };

    const lista = proyectos.map(p => {
      const fin = finPorProyecto[p.id] || {};
      const horasProyecto = (horPor[p.id] || []);
      const reales = (Number(p.horas_reales_base) || 0) +
        horasProyecto.reduce((s, h) => s + Number(h.horas || 0), 0);
      const docs = (docPor[p.id] || []);
      return {
        id: p.id,
        tipo: p.tipo,
        nombre: p.nombre,
        direccion: p.direccion || "Por confirmar",
        cliente: p.cliente || "Por confirmar",
        via: p.via || "—",
        estado: p.estado,
        fase: p.fase || undefined,
        estadoDetalle: p.estado_detalle || "",
        proximaAccion: p.proxima_accion || "",
        ref: p.ref || "—",
        contrato: fin.contrato !== undefined && fin.contrato !== null ? Number(fin.contrato) : null,
        cobrado: fin.cobrado !== undefined && fin.cobrado !== null ? Number(fin.cobrado) : null,
        alcances: (alcPor[p.id] || []).map(a => ({
          tipo: a.tipo, titulo: a.titulo, ref: a.ref,
          monto: a.monto !== undefined && a.monto !== null ? Number(a.monto) : undefined,
          cobrado: a.cobrado !== undefined && a.cobrado !== null ? Number(a.cobrado) : null,
          estado: a.estado
        })),
        hitos: (hitPor[p.id] || []).map(h => ({
          titulo: h.titulo, condicion: h.condicion,
          monto: Number(h.monto), estado: h.estado
        })),
        facturas: (facPor[p.id] || []).map(f => ({
          num: f.num, fecha: fechaCorta(f.fecha),
          monto: Number(f.monto), pagada: !!f.pagada
        })),
        docs: docs.filter(d => d.clase === "doc").map(d => ({ titulo: d.titulo, url: d.url })),
        rfis: docs.filter(d => d.clase === "rfi").map(d => ({ titulo: d.titulo, estado: d.estado, url: d.url })),
        horas: (Number(p.horas_estimadas) > 0 || reales > 0)
          ? { estimadas: Number(p.horas_estimadas) || 0, reales: Math.round(reales * 10) / 10 }
          : null
      };
    });

    return {
      perfil: miPerfil,
      nombrePorId,
      proyectos: lista,
      eventos: eventos.map(e => ({
        id: e.id, fecha: e.fecha, hora: e.hora || "", titulo: e.titulo,
        proyecto: e.proyecto_id, nota: e.nota || "", alerta: !!e.alerta
      })),
      pendientes: pendientes.map(p => ({
        id: p.id, fecha: p.fecha, proyecto: p.proyecto_id,
        descripcion: p.descripcion, autor: nombrePorId[p.autor_id] || "",
        resuelto: !!p.resuelto
      })),
      registroHoras: horas.map(h => ({
        id: h.id, fecha: h.fecha, usuarioId: h.usuario_id,
        trabajador: nombrePorId[h.usuario_id] || "",
        proyecto: h.proyecto_id, fase: h.fase || "",
        horas: Number(h.horas), notas: h.notas || ""
      }))
    };
  }

  // API pública para app.js
  window.MXP_DB = {
    haySesion: () => !!sesion,
    uid,
    entrar,
    refrescar,
    salir,
    cargarTodo,
    // Escrituras
    cambiarProyecto: (id, cambios) => actualizar(`proyectos?id=eq.${encodeURIComponent(id)}`, cambios),
    eliminarProyecto: id => api(`proyectos?id=eq.${encodeURIComponent(id)}`, { metodo: "DELETE" }),
    crearProyecto: fila => insertar("proyectos", fila),
    crearFinanzas: fila => insertar("finanzas_proyecto", fila),
    reportarHoras: fila => insertar("horas", { ...fila, usuario_id: uid() }),
    crearDocumento: fila => insertar("documentos", fila),
    crearEvento: fila => insertar("eventos", { ...fila, autor_id: uid() }),
    crearPendiente: fila => insertar("pendientes", { ...fila, autor_id: uid() }),
    resolverPendiente: id => actualizar(`pendientes?id=eq.${id}`,
      { resuelto: true, resuelto_por: uid(), resuelto_el: new Date().toISOString() })
  };
})();
