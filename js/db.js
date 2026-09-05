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
      // Se lleva el código HTTP pegado al error: 400/401 es "la contraseña o
      // el token no sirven" (hay que volver a entrar); 500, 502 o 503 es
      // "el servidor está caído" y NO se puede borrar la sesión por eso —
      // en la obra deja al equipo fuera sin poder reportar.
      const e = new Error(msg);
      e.status = r.status;
      throw e;
    }
    sesion = data;
    guardarSesion(sesion);
    programarRefresco();
    return sesion;
  }

  async function entrar(email, clave) {
    return autenticar({ email, password: clave }, "password");
  }

  let refrescoEnVuelo = null; // 20 lecturas a la vez = UN solo refresco
  function refrescar() {
    if (!refrescoEnVuelo) {
      refrescoEnVuelo = (async () => {
        if (!sesion || !sesion.refresh_token) throw new Error("Sin sesión");
        return autenticar({ refresh_token: sesion.refresh_token }, "refresh_token");
      })().finally(() => { refrescoEnVuelo = null; });
    }
    return refrescoEnVuelo;
  }

  function salir() {
    sesion = null;
    guardarSesion(null);
    if (temporizadorRefresco) clearTimeout(temporizadorRefresco);
  }

  function uid() {
    return sesion && sesion.user ? sesion.user.id : null;
  }

  // ---------- Traducir los errores de la base a español de taller ----------
  // Postgres contesta con códigos y frases en inglés que no le dicen nada a
  // nadie ("violates check constraint estimados_modo_check"). Aquí se
  // convierten en una frase que dice QUÉ pasó y QUÉ hay que hacer.
  function enCristiano(data, crudo) {
    const cod = String((data && data.code) || "");
    const txt = String(crudo || "");
    const falta = "A la base todavía le falta el último SQL. Pégalo en Supabase " +
                  "(SQL Editor → pegar → Run) y vuelve a intentarlo.";

    // Falta una columna o una tabla que la app ya usa = SQL sin pegar
    if (cod === "42703" || cod === "42P01" || cod === "PGRST204" || cod === "PGRST205") return falta;

    // Un candado de la base rechazó el valor
    if (cod === "23514") {
      if (/modo/i.test(txt)) {
        return "El modo ⚡ Rápido todavía no está dado de alta en la base. " + falta;
      }
      return "La base no aceptó uno de los datos porque se sale de lo permitido. " + falta;
    }
    if (cod === "23505") return "Eso ya estaba guardado; no se apuntó dos veces.";
    if (cod === "23503") return "Eso apunta a algo que ya no existe (un proyecto o un hito borrado).";
    if (cod === "23502") return "Falta un dato obligatorio para poder guardar.";
    if (cod === "42501") return "Tu usuario no tiene permiso para hacer eso.";
    if (cod === "22P02" || cod === "22003") return "Uno de los números no es válido.";
    if (cod === "PGRST301" || cod === "PGRST303") return "Se venció la sesión. Vuelve a entrar.";
    return crudo;
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
      const crudo = data.message || data.hint || `Error ${r.status} en ${ruta}`;
      // El error se traduce AQUÍ, en un solo sitio, para que ninguna pantalla
      // de la app le enseñe jerga de base de datos a nadie. El texto original
      // queda en e.crudo y en la consola, por si hay que mirarlo.
      const e = new Error(enCristiano(data, crudo));
      e.status = r.status;
      e.codigo = data.code || null;
      e.crudo = crudo;
      if (typeof console !== "undefined") console.warn("[base]", data.code || r.status, crudo, "·", ruta);
      throw e;
    }
    if (r.status === 204) return null;
    // Safari se atraganta con respuestas vacías (201 sin cuerpo): parsear con cuidado
    const texto = await r.text();
    return texto ? JSON.parse(texto) : null;
  }

  // La base entrega máximo 1,000 filas por petición: leer() pagina hasta traerlo todo
  const leer = async ruta => {
    const todo = [];
    for (let desde = 0; ; desde += 1000) {
      const pagina = await api(ruta, { headers: { Range: `${desde}-${desde + 999}` } });
      if (!Array.isArray(pagina)) return pagina;
      todo.push(...pagina);
      if (pagina.length < 1000) return todo;
    }
  };
  const insertar = (tabla, fila) => api(tabla, { metodo: "POST", cuerpo: fila });
  const actualizar = (ruta, cambios) => api(ruta, { metodo: "PATCH", cuerpo: cambios });

  // ---------- Fotos (Supabase Storage, almacén privado) ----------
  // carpeta opcional: "recibos" guarda la foto en recibos/<proyecto>/...
  async function subirFoto(proyectoId, blob, tipo, carpeta, reintento = true) {
    // La extensión sigue al tipo: los videos cortos suben como .mp4/.mov/.webm
    const ext = /mp4/i.test(tipo || "") ? "mp4" : /quicktime|\bmov\b/i.test(tipo || "") ? "mov" : /webm/i.test(tipo || "") ? "webm" : "jpg";
    const ruta = `${carpeta ? carpeta + "/" : ""}${proyectoId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
    const r = await fetch(`${SB.url}/storage/v1/object/fotos/${ruta}`, {
      method: "POST",
      headers: {
        apikey: SB.key,
        Authorization: `Bearer ${sesion ? sesion.access_token : SB.key}`,
        "Content-Type": tipo || "image/jpeg"
      },
      body: blob
    });
    if (r.status === 401 && reintento && sesion) {
      // Token caducado a media subida: refrescar y volver a intentar
      await refrescar();
      return subirFoto(proyectoId, blob, tipo, carpeta, false);
    }
    if (!r.ok) {
      const data = await r.json().catch(() => ({}));
      throw new Error(data.message || `No se pudo subir la foto (${r.status})`);
    }
    return ruta;
  }

  // Sube un PDF al almacén de la app (documentos del portal, sin Drive)
  // prefijo: "docs" = contratos/SOW/CO (solo dueño) · "docs-equipo" = planos/RFIs
  async function subirDocumento(proyectoId, blob, prefijo, reintento = true) {
    const ruta = `${prefijo}/${proyectoId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.pdf`;
    const r = await fetch(`${SB.url}/storage/v1/object/fotos/${ruta}`, {
      method: "POST",
      headers: {
        apikey: SB.key,
        Authorization: `Bearer ${sesion ? sesion.access_token : SB.key}`,
        "Content-Type": "application/pdf"
      },
      body: blob
    });
    if (r.status === 401 && reintento && sesion) {
      await refrescar();
      return subirDocumento(proyectoId, blob, prefijo, false);
    }
    if (!r.ok) {
      const data = await r.json().catch(() => ({}));
      throw new Error(data.message || `No se pudo subir el documento (${r.status})`);
    }
    return ruta;
  }

  // Convierte las rutas guardadas en enlaces temporales (1 hora)
  async function firmarFotos(rutas, reintento = true) {
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
    if (r.status === 401 && reintento && sesion) {
      await refrescar();
      return firmarFotos(rutas, false);
    }
    // Antes devolvía {} en silencio: las fotos salían en blanco sin explicación.
    // Ahora lanza, y quien lo llama decide qué avisar.
    if (!r.ok) throw new Error("No se pudieron cargar las imágenes (" + r.status + ")");
    const lista = await r.json().catch(() => []);
    const mapa = {};
    for (const item of lista) {
      const firma = item.signedURL || item.signedUrl;
      if (item.path && firma) mapa[item.path] = `${SB.url}/storage/v1${firma}`;
    }
    // Fallo PARCIAL: el servidor contestó bien pero no firmó todo. Antes esas
    // fotos salían como marcos vacíos y nadie sabía si faltaban o si era la
    // señal. Se deja apuntado cuántas faltaron para poder avisarlo.
    const faltan = rutas.filter(x => !mapa[x]).length;
    if (faltan) Object.defineProperty(mapa, "__faltan", { value: faltan, enumerable: false });
    return mapa;
  }

  // ---------- Carga completa según el rol ----------
  async function cargarTodo() {
    const [perfiles, proyectos, proyectosEquipo, finanzas, alcances, alcancesEquipo,
           hitos, facturas, horas, eventos, pendientes, documentos, fotos,
           inspecciones, materiales, materialesEquipo, costos, externos,
           gestiones, recibos, recibosEquipo, alcancePuntos, ayudantes, decisiones,
           llavesPortal, visitasPortal, docsEmpresa, titulosDocs, jurisdicciones] =
      await Promise.all([
        leer("perfiles?select=*"),
        // El dueño lee la tabla completa; al equipo la base le devuelve vacío
        // y usa la vista sin montos (misma regla que materiales y alcances)
        leer("proyectos?select=*&order=nombre").catch(() => []),
        leer("proyectos_equipo?select=*&order=nombre").catch(() => []),
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
        leer("alcance_puntos?select=*&order=orden").catch(() => []),
        leer("externos_equipo?select=*&order=nombre").catch(() => []),
        leer("decisiones_cliente?select=*&order=creado").catch(() => []),
        // Llaves del portal: solo el dueño recibe filas (RLS); si la tabla
        // no existe todavía, la app sigue andando
        leer("portal_llaves?select=*").catch(() => []),
        // Visitas del portal (solo el dueño recibe filas)
        leer("portal_visitas?select=proyecto_id,cuando&order=cuando.desc&limit=300").catch(() => []),
        // Documentos de la empresa (licencia y seguros) — todos los ven
        leer("documentos_empresa?select=*&order=orden,id").catch(() => []),
        // Solo títulos de documentos (para elegir el CO en el reporte de horas)
        leer("documentos_equipo?select=proyecto_id,titulo").catch(() => []),
        // Permisos por jurisdicción (todos leen; el dueño edita)
        leer("jurisdicciones?select=*&order=condado").catch(() => [])
      ]);

    const llavePorProyecto = Object.fromEntries((llavesPortal || []).map(l => [l.proyecto_id, l.token]));
    // Última visita del cliente por proyecto (vienen ordenadas de la más nueva)
    const visitaPorProyecto = {};
    (visitasPortal || []).forEach(v => {
      if (!visitaPorProyecto[v.proyecto_id]) visitaPorProyecto[v.proyecto_id] = v.cuando;
    });
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

    // Si la base no devolvió proyectos (el equipo no puede leer la tabla
    // completa), se usa la vista sin montos. La app se pinta igual.
    const proyectosFuente = (proyectos && proyectos.length) ? proyectos : (proyectosEquipo || []);

    const lista = proyectosFuente.map(p => {
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
        portalToken: llavePorProyecto[p.id] || p.portal_token || null,
        portalDinero: p.portal_dinero === true,
        portalCompleto: p.portal_completo === true,
        cliente: p.cliente || "Por confirmar",
        via: p.via || "—",
        origen: p.origen || "",
        clienteEmail: p.cliente_email || "",
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
          id: h.id, titulo: h.titulo, condicion: h.condicion,
          monto: Number(h.monto), estado: h.estado
        })),
        facturas: (facPor[p.id] || []).map(f => ({
          id: f.id, num: f.num, fecha: fechaCorta(f.fecha), fechaISO: f.fecha || "",
          monto: Number(f.monto), pagada: !!f.pagada
        })),
        docs: docs.filter(d => d.clase === "doc").map(d => ({ id: d.id, titulo: d.titulo, url: d.url, ruta: d.ruta || "", portal: !!d.portal,
          pideAprobacion: !!d.pide_aprobacion, aprobadoEl: d.aprobado_el ? String(d.aprobado_el).slice(0, 10) : "",
          pideFirma: !!d.pide_firma, firmadoEl: d.firmado_el ? String(d.firmado_el).slice(0, 10) : "", firmaNombre: d.firma_nombre || "",
          vistoEl: d.visto_el ? String(d.visto_el).slice(0, 10) : "",
          contrafirmaEl: d.contrafirma_el ? String(d.contrafirma_el).slice(0, 10) : "" })),
        rfis: docs.filter(d => d.clase === "rfi").map(d => ({ id: d.id, titulo: d.titulo, estado: d.estado, url: d.url, ruta: d.ruta || "" })),
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
        activo: u.activo !== false,
        ultimaVista: u.ultima_vista || ""
      })),
      proyectos: lista,
      // Regla de la casa: el equipo ve los eventos generales y LOS SUYOS;
      // los eventos asignados a otra persona no le aparecen.
      eventos: eventos
        .filter(e => esDueno || !e.asignados || !e.asignados.length || e.asignados.includes(uid()))
        .map(e => ({
          id: e.id, fecha: e.fecha, hora: e.hora || "", titulo: e.titulo,
          proyecto: e.proyecto_id, nota: e.nota || "", alerta: !!e.alerta,
          asignados: (e.asignados || []).map(a => nombrePorId[a] || "").filter(Boolean),
          ubicacion: e.ubicacion || "", estadoEv: e.estado || "programado"
        })),
      pendientes: pendientes.map(p => ({
        id: p.id, fecha: p.fecha, proyecto: p.proyecto_id,
        descripcion: p.descripcion, autor: nombrePorId[p.autor_id] || "",
        autorId: p.autor_id || null,
        prioridad: p.prioridad || "normal",
        resuelto: !!p.resuelto
      })),
      registroHoras: horas.map(h => ({
        id: h.id, fecha: h.fecha, usuarioId: h.usuario_id,
        trabajador: nombrePorId[h.usuario_id] || "",
        proyecto: h.proyecto_id, fase: h.fase || "",
        horas: Number(h.horas), notas: h.notas || "",
        co: h.co || null,
        correccion: h.correccion_estado || null
      })),
      visitasPortal: visitaPorProyecto,
      titulosDocs: (titulosDocs || []).map(t => ({ proyecto: t.proyecto_id, titulo: t.titulo || "" })),
      jurisdicciones: (jurisdicciones || []).map(j => ({
        id: j.id, condado: j.condado, notas: j.notas || "", portalUrl: j.portal_url || "", contacto: j.contacto || "" })),
      docsEmpresa: (docsEmpresa || []).map(d => ({
        id: d.id, titulo: d.titulo, tituloEn: d.titulo_en || "",
        ruta: d.ruta || "", url: d.url || "", vence: d.vence || "" })),
      fotos: fotos.map(f => ({
        id: f.id, proyecto: f.proyecto_id, ruta: f.ruta,
        nota: f.nota || "", autor: nombrePorId[f.autor_id] || "",
        autorId: f.autor_id,
        fecha: f.creado ? String(f.creado).slice(0, 10) : "",
        portal: !!f.portal
      })),
      decisiones: (decisiones || []).map(d => ({
        id: d.id, proyecto: d.proyecto_id, texto: d.texto,
        fechaLimite: d.fecha_limite || "", hecha: !!d.hecha
      })),
      inspecciones: inspecciones.map(i => ({
        id: i.id, proyecto: i.proyecto_id, permiso: i.permiso || "",
        jurisdiccion: i.jurisdiccion || "", tipo: i.tipo,
        fecha: i.fecha || "", resultado: i.resultado || "programada",
        notas: i.notas || "",
        // Si la inspección nació de un evento del calendario, el evento ya
        // está en la lista: no hay que pintarla otra vez
        eventoId: i.evento_id || null
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
        costo: Number(x.costo),
        ayudante: x.externo_id || null
      })),
      // Nómina de ayudantes externos (solo dueño): nombre + tarifa, sin cuenta en la app
      ayudantes: ayudantes.map(a => ({
        id: a.id, nombre: a.nombre, costoHora: Number(a.costo_hora), activo: a.activo !== false
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
        co: r.co || null, categoria: r.categoria || "material",
        estado: r.estado || "por_leer", autor: nombrePorId[r.autor_id] || "",
        fecha: r.fecha || (r.creado ? String(r.creado).slice(0, 10) : "")
      })),
      puntos: alcancePuntos.map(a => ({
        id: a.id, proyecto: a.proyecto_id, texto: a.texto,
        hecho: !!a.hecho, orden: a.orden || 0,
        prioridad: a.prioridad || "normal"
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
    // Marca "estuve en la app" (última vista del que llama; falla en silencio
    // si la función SQL aún no existe)
    estuve: () => api("rpc/fn_estuve", { metodo: "POST", cuerpo: {} }).catch(() => {}),
    cambiarLlavePortal: (proyectoId, token) => api("portal_llaves?on_conflict=proyecto_id", {
      metodo: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=representation" },
      cuerpo: { proyecto_id: proyectoId, token }
    }),
    cambiarDocumento: (id, cambios) => actualizar(`documentos?id=eq.${id}`, cambios),
    cambiarFoto: (id, cambios) => actualizar(`fotos?id=eq.${id}`, cambios),
    crearDecision: fila => insertar("decisiones_cliente", fila),
    cambiarDecision: (id, cambios) => actualizar(`decisiones_cliente?id=eq.${id}`, cambios),
    eliminarDecision: id => api(`decisiones_cliente?id=eq.${id}`, { metodo: "DELETE" }),
    eliminarProyecto: id => api(`proyectos?id=eq.${encodeURIComponent(id)}`, { metodo: "DELETE" }),
    crearProyecto: fila => insertar("proyectos", fila),
    crearFinanzas: fila => insertar("finanzas_proyecto", fila),
    reportarHoras: async fila => {
      try { return await insertar("horas", { ...fila, usuario_id: uid() }); }
      catch (e) {
        // Si la base todavía no tiene la columna llave_cliente (SQL sin pegar),
        // se manda sin ella para que las horas nunca dejen de entrar.
        if (fila && fila.llave_cliente && e && e.status !== 409 && /llave_cliente/i.test(String((e && e.crudo) || (e && e.message) || ""))) {
          const { llave_cliente, ...sin } = fila;
          return insertar("horas", { ...sin, usuario_id: uid() });
        }
        throw e;
      }
    },
    cambiarHoras: (id, cambios) => actualizar(`horas?id=eq.${id}`, cambios),
    eliminarHoras: id => api(`horas?id=eq.${id}`, { metodo: "DELETE" }),
    crearExterno: fila => insertar("trabajos_externos", fila),
    eliminarExterno: id => api(`trabajos_externos?id=eq.${id}`, { metodo: "DELETE" }),
    crearAyudante: fila => insertar("externos_equipo", fila),
    cambiarAyudante: (id, cambios) => actualizar(`externos_equipo?id=eq.${id}`, cambios),
    // Registrar este teléfono para notificaciones (upsert por endpoint)
    guardarSuscripcion: fila => api("push_suscripciones?on_conflict=endpoint", {
      metodo: "POST", cuerpo: { ...fila, usuario_id: uid() },
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" }
    }),
    // 💬 Chat del equipo
    miUid: () => uid(),
    leerMensajes: () => leer("mensajes?select=*&order=creado"),
    enviarMensaje: (texto, destinatarioId) =>
      insertar("mensajes", { texto, destinatario_id: destinatarioId || null, autor_id: uid() }),
    leerLecturas: () => leer(`chat_lecturas?select=*&usuario_id=eq.${uid()}`),
    marcarLeido: conv => api("chat_lecturas?on_conflict=usuario_id,conv", {
      metodo: "POST",
      cuerpo: { usuario_id: uid(), conv, visto: new Date().toISOString() },
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" }
    }),
    crearGestion: fila => insertar("gestiones", { ...fila, autor_id: uid() }),
    cambiarGestion: (id, cambios) => actualizar(`gestiones?id=eq.${id}`, cambios),
    eliminarGestion: id => api(`gestiones?id=eq.${id}`, { metodo: "DELETE" }),
    // ---------- Estimador (solo dueño; se carga aparte, no pesa el arranque) ----------
    cargarEstimador: async () => {
      const [catalogo, escenarios, estimados, items,
             alias, config, generales, ensambles, ensambleItems, estEnsambles, horasTodas,
             recetas] =
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
          leer("horas?select=fecha,horas").catch(() => []),
          leer("lev_recetas?select=*").catch(() => [])
        ]);
      return { catalogo, escenarios, estimados, items, alias,
               config: Object.fromEntries(config.map(c => [c.clave, Number(c.valor)])),
               generales, ensambles, ensambleItems, estEnsambles, horasTodas, recetas };
    },

    // ---------- Propuestas y cierre en la mesa (solo dueño) ----------
    // Las tres tablas llevan precios dentro y el candado es_dueno() de la base
    // ya deja fuera al equipo de campo.
    cargarPropuestas: async () => {
      const [propuestas, opciones, textos, pendientes] = await Promise.all([
        leer("propuestas?select=*&order=creado.desc").catch(() => []),
        leer("propuesta_opciones?select=*&order=orden").catch(() => []),
        leer("textos_legales?select=*&vigente=is.true&order=clave").catch(() => []),
        leer("cobros_pendientes?select=*&resuelto=is.false&order=creado.desc").catch(() => [])
      ]);
      return { propuestas, opciones, textos, pendientes };
    },
    crearPropuesta: fila => insertar("propuestas", fila),
    cambiarPropuesta: (id, cambios) => actualizar(`propuestas?id=eq.${id}`, cambios),
    eliminarPropuesta: id => api(`propuestas?id=eq.${id}`, { metodo: "DELETE" }),
    // Las opciones van en una sola petición, no una por una
    crearOpciones: filas => (filas.length ? insertar("propuesta_opciones", filas) : Promise.resolve([])),
    borrarOpciones: propuestaId => api(`propuesta_opciones?propuesta_id=eq.${propuestaId}`, { metodo: "DELETE" }),
    // ---------- La hoja de alcance ----------
    // Todo lo del alcance vive dentro de la propuesta, así que hereda su candado.
    guardarAlcance: (id, campos) => actualizar(`propuestas?id=eq.${id}`, campos),

    // La plantilla oficial vive en el almacén de la app, no en el teléfono:
    // así Edgar no tiene que elegir ningún archivo y todos usan la misma.
    plantillaSOW: async () => {
      const firma = await firmarFotos(["plantillas/SOW_Template_v3.1.html"]);
      const url = firma["plantillas/SOW_Template_v3.1.html"];
      if (!url) throw new Error("No encuentro la plantilla oficial en la app");
      const r = await fetch(url);
      if (!r.ok) throw new Error("No se pudo bajar la plantilla (" + r.status + ")");
      return r.text();
    },

    // La llave del portal: si el proyecto ya tenía una, se respeta (no se
    // le cambia el enlace al cliente por debajo).
    llavePortal: async proyectoId => {
      const hay = await leer(`portal_llaves?select=*&proyecto_id=eq.${encodeURIComponent(proyectoId)}`).catch(() => []);
      if (hay && hay.length) return hay[0].token;
      const token = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now())).replace(/-/g, "");
      await api("portal_llaves?on_conflict=proyecto_id", {
        metodo: "POST", cuerpo: { proyecto_id: proyectoId, token },
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" }
      });
      return token;
    },

    // ---------- Levantamiento en sitio (solo dueño) ----------
    // Las tres tablas llevan precios dentro, así que el candado de la base
    // (es_dueno) ya deja fuera al equipo de campo. Aquí no hace falta filtrar.
    cargarLevantamientos: async () => {
      const [levantamientos, cuartos] = await Promise.all([
        leer("levantamientos?select=*&order=creado.desc").catch(() => []),
        leer("lev_cuartos?select=*&order=orden").catch(() => [])
      ]);
      return { levantamientos, cuartos };
    },
    // Sube el levantamiento entero por su llave_cliente: si ya estaba, se
    // actualiza; nunca se duplica. El teléfono manda, la nube copia.
    guardarLevantamiento: fila => api("levantamientos?on_conflict=llave_cliente", {
      metodo: "POST",
      cuerpo: { ...fila, autor_id: uid() },
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    cambiarLevantamiento: (id, cambios) => actualizar(`levantamientos?id=eq.${id}`, cambios),
    eliminarLevantamiento: id => api(`levantamientos?id=eq.${id}`, { metodo: "DELETE" }),
    guardarCuarto: fila => api("lev_cuartos?on_conflict=llave_cliente", {
      metodo: "POST",
      cuerpo: fila,
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    eliminarCuarto: id => api(`lev_cuartos?id=eq.${id}`, { metodo: "DELETE" }),
    // Los renglones del estimado que vinieron del levantamiento se borran
    // y se rehacen; los que Edgar puso a mano (origen 'manual') no se tocan.
    borrarItemsDeLevantamiento: estimadoId =>
      api(`estimado_items?estimado_id=eq.${estimadoId}&origen=eq.levantamiento`, { metodo: "DELETE" }),
    // Una sola petición con todos los renglones, no treinta y cinco seguidas
    crearItemsEstimado: filas => (filas.length ? insertar("estimado_items", filas) : Promise.resolve([])),
    crearPuntos: filas => (filas.length ? insertar("alcance_puntos", filas) : Promise.resolve([])),
    // No hay borrado de puntos por lote a propósito: 'alcance_puntos' no tiene
    // columna de origen, así que borrar por texto podría llevarse puntos que
    // Edgar escribió a mano. Al reconvertir, la app salta los que ya están.
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
    // Editar un escenario (tarifas, cuadrilla, beneficios, profit) — solo el dueño
    cambiarEscenario: (id, cambios) => actualizar(`escenarios?id=eq.${encodeURIComponent(id)}`, cambios),
    crearEstimado: fila => insertar("estimados", fila),
    cambiarEstimado: (id, cambios) => actualizar(`estimados?id=eq.${id}`, cambios),
    eliminarEstimado: id => api(`estimados?id=eq.${id}`, { metodo: "DELETE" }),
    crearItemEstimado: fila => insertar("estimado_items", fila),
    cambiarItemEstimado: (id, cambios) => actualizar(`estimado_items?id=eq.${id}`, cambios),
    eliminarItemEstimado: id => api(`estimado_items?id=eq.${id}`, { metodo: "DELETE" }),
    crearHito: fila => insertar("hitos", fila),
    // Marcar un hito cobrado / facturado / pendiente sin tocar SQL
    cambiarHito: (id, cambios) => actualizar(`hitos?id=eq.${id}`, cambios),
    // Marcar una factura pagada (o devolverla a sin pagar) sin tocar SQL
    cambiarFactura: (id, cambios) => actualizar(`facturas?id=eq.${id}`, cambios),
    cambiarPerfil: (id, cambios) => actualizar(`perfiles?id=eq.${id}`, cambios),
    crearPunto: fila => insertar("alcance_puntos", fila),
    cambiarPunto: (id, cambios) => actualizar(`alcance_puntos?id=eq.${id}`, cambios),
    eliminarPunto: id => api(`alcance_puntos?id=eq.${id}`, { metodo: "DELETE" }),
    crearRecibo: fila => insertar("recibos", { ...fila, autor_id: uid() }),
    cambiarRecibo: (id, cambios) => actualizar(`recibos?id=eq.${id}`, cambios),
    eliminarRecibo: id => api(`recibos?id=eq.${id}`, { metodo: "DELETE" }),
    crearDocumento: fila => insertar("documentos", fila),
    subirDocumento,
    tokenSesion: () => (sesion ? sesion.access_token : null),
    // 🤖 El asistente: manda la conversación al cerebro con el token del
    // usuario. El cerebro mira ese token para saber quién pregunta y qué
    // puede ver (el equipo nunca recibe dinero).
    async preguntarAsistente(mensajes) {
      if (!sesion) throw new Error("Sin sesión");
      const r = await fetch(`${SB.url}/functions/v1/cerebro?accion=asistente`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${sesion.access_token}` },
        body: JSON.stringify({ mensajes })
      });
      if (r.status === 401) {
        // el token pudo haber caducado: se refresca y se reintenta una vez
        await refrescar();
        const r2 = await fetch(`${SB.url}/functions/v1/cerebro?accion=asistente`, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${sesion.access_token}` },
          body: JSON.stringify({ mensajes })
        });
        if (!r2.ok) throw new Error("No se pudo conectar con el asistente");
        return r2.json();
      }
      if (!r.ok) throw new Error("El asistente no respondió (" + r.status + ")");
      return r.json();
    },
    // La hoja de alcance: el cerebro la ordena (accion=ordenar) o la redacta
    // en inglés (accion=alcance). Va con el token del usuario, como el asistente.
    async pedirAlCerebro(accion, cuerpo) {
      if (!sesion) throw new Error("Sin sesión");
      const tirar = async () => fetch(`${SB.url}/functions/v1/cerebro?accion=${accion}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${sesion.access_token}` },
        body: JSON.stringify(cuerpo)
      });
      let r = await tirar();
      if (r.status === 401) { await refrescar(); r = await tirar(); }
      if (r.status === 404 || r.status === 405)
        throw new Error("Esta parte del asistente todavía no está subida a la nube");
      if (!r.ok) throw new Error("El asistente no respondió (" + r.status + ")");
      return r.json();
    },
    crearDocEmpresa: fila => insertar("documentos_empresa", fila),
    cambiarDocEmpresa: (id, cambios) => actualizar(`documentos_empresa?id=eq.${id}`, cambios),
    eliminarDocEmpresa: id => api(`documentos_empresa?id=eq.${id}`, { metodo: "DELETE" }),
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
    // ¿Está puesto el candado que le quita los montos a los avisos del
    // teléfono? La función es_activo() nace en el mismo SQL que ese
    // candado, así que si contesta, el candado está. Si no, mejor no
    // dejar que el equipo encienda los avisos todavía.
    avisosSinDinero: () => api("rpc/es_activo", { metodo: "POST", cuerpo: {} })
      .then(() => true).catch(() => false),
    // Cambia una casilla de finanzas del proyecto (por ejemplo "cobrado",
    // que es la que cuadra la app con el banco)
    cambiarFinanzas: (proyectoId, cambios) =>
      actualizar(`finanzas_proyecto?proyecto_id=eq.${encodeURIComponent(proyectoId)}`, cambios),
    // Guarda (o actualiza) el costo por hora de un trabajador
    guardarCosto: (usuarioId, costoHora) => api("costos_equipo", {
      metodo: "POST",
      cuerpo: { usuario_id: usuarioId, costo_hora: costoHora },
      headers: { Prefer: "resolution=merge-duplicates,return=representation" }
    }),
    crearEvento: fila => insertar("eventos", { ...fila, autor_id: uid() }),
    eliminarEvento: id => api(`eventos?id=eq.${id}`, { metodo: "DELETE" }),
    // Cerrar un día del calendario: hecho, cancelado o de vuelta a programado
    cambiarEvento: (id, cambios) => actualizar(`eventos?id=eq.${id}`, cambios),
    crearPendiente: fila => insertar("pendientes", { ...fila, autor_id: uid() }),
    cambiarPendiente: (id, cambios) => actualizar(`pendientes?id=eq.${id}`, cambios),
    resolverPendiente: id => actualizar(`pendientes?id=eq.${id}`,
      { resuelto: true, resuelto_por: uid(), resuelto_el: new Date().toISOString() }),
    reabrirPendiente: id => actualizar(`pendientes?id=eq.${id}`,
      { resuelto: false, resuelto_por: null, resuelto_el: null }),
    eliminarPendiente: id => api(`pendientes?id=eq.${id}`, { metodo: "DELETE" })
  };
})();
