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

  // ---------- Fotos (Supabase Storage, almacén privado) ----------
  // carpeta opcional: "recibos" guarda la foto en recibos/<proyecto>/...
  async function subirFoto(proyectoId, blob, tipo, carpeta) {
    const ruta = `${carpeta ? carpeta + "/" : ""}${proyectoId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.jpg`;
    const r = await fetch(`${SB.url}/storage/v1/object/fotos/${ruta}`, {
      method: "POST",
      headers: {
        apikey: SB.key,
        Authorization: `Bearer ${sesion ? sesion.access_token : SB.key}`,
        "Content-Type": tipo || "image/jpeg"
      },
      body: blob
    });
    if (!r.ok) {
      const data = await r.json().catch(() => ({}));
      throw new Error(data.message || `No se pudo subir la foto (${r.status})`);
    }
    return ruta;
  }

  // Convierte las rutas guardadas en enlaces temporales (1 hora)
  async function firmarFotos(rutas) {
    if (!rutas || !rutas.length) return {};
    const r = await fetch(`${SB.url}/storage/v1/object/sign/fotos`, {
      method: "POST",
      headers: {
        apikey: SB.key,
        Authorization: `Bearer ${sesion ? sesion.access_token : SB.key}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ expiresIn: 3600, paths: rutas })
    });
    if (!r.ok) return {};
    const lista = await r.json().catch(() => []);
    const mapa = {};
    for (const item of lista) {
      const firma = item.signedURL || item.signedUrl;
      if (item.path && firma) mapa[item.path] = `${SB.url}/storage/v1${firma}`;
    }
    return mapa;
  }

  // ---------- Carga completa según el rol ----------
  async function cargarTodo() {
    const [perfiles, proyectos, finanzas, alcances, alcancesEquipo,
           hitos, facturas, horas, eventos, pendientes, documentos, fotos,
           inspecciones, materiales, materialesEquipo, costos, externos,
           gestiones, recibos, recibosEquipo, alcancePuntos] =
      await Promise.all([
        leer("perfiles?select=*"),
        leer("proyectos?select=*&order=nombre"),
        leer("finanzas_proyecto?select=*").catch(() => []),
        leer("alcances?select=*&order=orden").catch(() => []),
        leer("alcances_equipo?select=*&order=orden").catch(() => []),
        leer("hitos?select=*&order=orden").catch(() => []),
        leer("facturas?select=*&order=fecha").catch(() => []),
        leer("horas?select=*&order=fecha"),
        leer("eventos?select=*&order=fecha"),
        leer("pendientes?select=*&order=fecha"),
        leer("documentos?select=*").catch(() => []),
        // Estas tablas pueden no existir todavía: la app sigue andando
        leer("fotos?select=*&order=creado").catch(() => []),
        leer("inspecciones?select=*&order=fecha").catch(() => []),
        leer("materiales?select=*&order=creado").catch(() => []),
        leer("materiales_equipo?select=*&order=creado").catch(() => []),
        leer("costos_equipo?select=*").catch(() => []),
        leer("trabajos_externos?select=*&order=fecha").catch(() => []),
        leer("gestiones?select=*&order=creado").catch(() => []),
        leer("recibos?select=*&order=creado").catch(() => []),
        leer("recibos_equipo?select=*&order=creado").catch(() => []),
        leer("alcance_puntos?select=*&order=orden").catch(() => [])
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
        actualizado: p.actualizado ? String(p.actualizado).slice(0, 10) : "",
        contrato: fin.contrato !== undefined && fin.contrato !== null ? Number(fin.contrato) : null,
        cobrado: fin.cobrado !== undefined && fin.cobrado !== null ? Number(fin.cobrado) : null,
        presupuestoMateriales: fin.presupuesto_materiales !== undefined && fin.presupuesto_materiales !== null
          ? Number(fin.presupuesto_materiales) : null,
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
          num: f.num, fecha: fechaCorta(f.fecha), fechaISO: f.fecha || "",
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
      equipo: perfiles.map(u => ({
        id: u.id, nombre: u.nombre, rol: u.rol,
        activo: u.activo !== false
      })),
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
      })),
      fotos: fotos.map(f => ({
        id: f.id, proyecto: f.proyecto_id, ruta: f.ruta,
        nota: f.nota || "", autor: nombrePorId[f.autor_id] || "",
        fecha: f.creado ? String(f.creado).slice(0, 10) : ""
      })),
      inspecciones: inspecciones.map(i => ({
        id: i.id, proyecto: i.proyecto_id, permiso: i.permiso || "",
        jurisdiccion: i.jurisdiccion || "", tipo: i.tipo,
        fecha: i.fecha || "", resultado: i.resultado || "programada",
        notas: i.notas || ""
      })),
      // El dueño lee la tabla completa (con precios); al equipo la
      // base de datos le devuelve vacío y usa la versión sin precios
      materiales: (materiales.length ? materiales : materialesEquipo).map(m => ({
        id: m.id, proyecto: m.proyecto_id, descripcion: m.descripcion,
        cantidad: m.cantidad || "", estado: m.estado || "falta",
        origenPendiente: m.origen_pendiente || null,
        precio: m.precio !== undefined && m.precio !== null ? Number(m.precio) : null,
        autor: nombrePorId[m.autor_id] || "",
        fecha: m.creado ? String(m.creado).slice(0, 10) : ""
      })),
      costos: Object.fromEntries(costos.map(c => [c.usuario_id, Number(c.costo_hora)])),
      externos: externos.map(x => ({
        id: x.id, proyecto: x.proyecto_id, descripcion: x.descripcion,
        fecha: x.fecha || "", tipo: x.tipo || "ajuste",
        horas: x.horas !== undefined && x.horas !== null ? Number(x.horas) : null,
        costo: Number(x.costo)
      })),
      gestiones: gestiones.map(g => ({
        id: g.id, proyecto: g.proyecto_id, descripcion: g.descripcion,
        hecha: !!g.hecha, autor: nombrePorId[g.autor_id] || "",
        fecha: g.creado ? String(g.creado).slice(0, 10) : ""
      })),
      // El dueño lee la tabla completa (con totales); el equipo la versión sin dinero
      recibos: (recibos.length ? recibos : recibosEquipo).map(r => ({
        id: r.id, proyecto: r.proyecto_id, ruta: r.ruta || "",
        total: r.total !== undefined && r.total !== null ? Number(r.total) : null,
        proveedor: r.proveedor || "", notas: r.notas || "",
        estado: r.estado || "por_leer", autor: nombrePorId[r.autor_id] || "",
        fecha: r.creado ? String(r.creado).slice(0, 10) : ""
      })),
      puntos: alcancePuntos.map(a => ({
        id: a.id, proyecto: a.proyecto_id, texto: a.texto,
        hecho: !!a.hecho, orden: a.orden || 0
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
    cambiarHoras: (id, cambios) => actualizar(`horas?id=eq.${id}`, cambios),
    eliminarHoras: id => api(`horas?id=eq.${id}`, { metodo: "DELETE" }),
    crearExterno: fila => insertar("trabajos_externos", fila),
    eliminarExterno: id => api(`trabajos_externos?id=eq.${id}`, { metodo: "DELETE" }),
    crearGestion: fila => insertar("gestiones", { ...fila, autor_id: uid() }),
    cambiarGestion: (id, cambios) => actualizar(`gestiones?id=eq.${id}`, cambios),
    eliminarGestion: id => api(`gestiones?id=eq.${id}`, { metodo: "DELETE" }),
    // ---------- Estimador (solo dueño; se carga aparte, no pesa el arranque) ----------
    cargarEstimador: async () => {
      const [catalogo, escenarios, estimados, items,
             alias, config, generales, ensambles, ensambleItems, estEnsambles, horasTodas] =
        await Promise.all([
          leer("catalogo_items?select=*&order=orden").catch(() => []),
          leer("escenarios?select=*&order=id").catch(() => []),
          leer("estimados?select=*&order=creado.desc").catch(() => []),
          leer("estimado_items?select=*&order=orden").catch(() => []),
          leer("alias_takeoff?select=*").catch(() => []),
          leer("config_estimador?select=*").catch(() => []),
          leer("gastos_generales?select=*").catch(() => []),
          leer("ensambles?select=*&order=orden").catch(() => []),
          leer("ensamble_items?select=*").catch(() => []),
          leer("estimado_ensambles?select=*").catch(() => []),
          leer("horas?select=fecha,horas").catch(() => [])
        ]);
      return { catalogo, escenarios, estimados, items, alias,
               config: Object.fromEntries(config.map(c => [c.clave, Number(c.valor)])),
               generales, ensambles, ensambleItems, estEnsambles, horasTodas };
    },
    crearAlias: fila => insertar("alias_takeoff", fila),
    guardarConfig: (clave, valor) => api("config_estimador", {
      metodo: "POST", cuerpo: { clave, valor },
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    ponerEnsamble: fila => insertar("estimado_ensambles", fila),
    cambiarEnsambleQty: (id, cantidad) => actualizar(`estimado_ensambles?id=eq.${id}`, { cantidad }),
    cambiarEnsamblePies: (id, pies) => actualizar(`estimado_ensambles?id=eq.${id}`, { pies }),
    quitarEnsamble: id => api(`estimado_ensambles?id=eq.${id}`, { metodo: "DELETE" }),
    crearItemCatalogo: fila => insertar("catalogo_items", fila),
    actualizarOverhead: valor => actualizar("escenarios?id=in.(A,B,C)", { overhead_hh: valor }),
    crearEstimado: fila => insertar("estimados", fila),
    cambiarEstimado: (id, cambios) => actualizar(`estimados?id=eq.${id}`, cambios),
    eliminarEstimado: id => api(`estimados?id=eq.${id}`, { metodo: "DELETE" }),
    crearItemEstimado: fila => insertar("estimado_items", fila),
    cambiarItemEstimado: (id, cambios) => actualizar(`estimado_items?id=eq.${id}`, cambios),
    eliminarItemEstimado: id => api(`estimado_items?id=eq.${id}`, { metodo: "DELETE" }),
    crearHito: fila => insertar("hitos", fila),
    cambiarPerfil: (id, cambios) => actualizar(`perfiles?id=eq.${id}`, cambios),
    crearPunto: fila => insertar("alcance_puntos", fila),
    cambiarPunto: (id, cambios) => actualizar(`alcance_puntos?id=eq.${id}`, cambios),
    eliminarPunto: id => api(`alcance_puntos?id=eq.${id}`, { metodo: "DELETE" }),
    crearRecibo: fila => insertar("recibos", { ...fila, autor_id: uid() }),
    cambiarRecibo: (id, cambios) => actualizar(`recibos?id=eq.${id}`, cambios),
    eliminarRecibo: id => api(`recibos?id=eq.${id}`, { metodo: "DELETE" }),
    crearDocumento: fila => insertar("documentos", fila),
    subirFoto,
    firmarFotos,
    crearFoto: fila => insertar("fotos", { ...fila, autor_id: uid() }),
    crearInspeccion: fila => insertar("inspecciones", fila),
    cambiarInspeccion: (id, cambios) => actualizar(`inspecciones?id=eq.${id}`, cambios),
    eliminarInspeccion: id => api(`inspecciones?id=eq.${id}`, { metodo: "DELETE" }),
    crearMaterial: fila => insertar("materiales", { ...fila, autor_id: uid() }),
    cambiarMaterial: (id, cambios) => actualizar(`materiales?id=eq.${id}`, cambios),
    eliminarMaterial: id => api(`materiales?id=eq.${id}`, { metodo: "DELETE" }),
    // Guarda (o actualiza) el presupuesto de materiales de un proyecto
    guardarPresupuesto: (proyectoId, monto) => api("finanzas_proyecto", {
      metodo: "POST",
      cuerpo: { proyecto_id: proyectoId, presupuesto_materiales: monto },
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    // Guarda (o actualiza) el costo por hora de un trabajador
    guardarCosto: (usuarioId, costoHora) => api("costos_equipo", {
      metodo: "POST",
      cuerpo: { usuario_id: usuarioId, costo_hora: costoHora },
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    crearEvento: fila => insertar("eventos", { ...fila, autor_id: uid() }),
    crearPendiente: fila => insertar("pendientes", { ...fila, autor_id: uid() }),
    cambiarPendiente: (id, cambios) => actualizar(`pendientes?id=eq.${id}`, cambios),
    resolverPendiente: id => actualizar(`pendientes?id=eq.${id}`,
      { resuelto: true, resuelto_por: uid(), resuelto_el: new Date().toISOString() })
  };
})();
