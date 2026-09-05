/* ============================================================================
   ALCANCE — de la hoja que escribe Edgar al contrato armado
   ============================================================================
   Todo lo de este archivo son funciones puras: entra texto, sale un objeto.
   No tocan la pantalla ni la base, para poder probarlas en local con Node.

   El camino es siempre el mismo:
     leerAlcance(texto)              → lo que dice la hoja
     validarAlcance(leido)           → errores en rojo y preguntas con botones
     cuentas(leido)                  → el dinero, al centavo (nunca lo toca el modelo)
     prepararEncargo(leido)          → lo único que se le manda al asistente
     validarSalida(encargo, salida)  → lo que devolvió, revisado
     decidirInterruptores(leido)     → qué bloques y qué cláusulas van
     rellenarPlantilla(...)          → el HTML final
     barridoFinal(html, montos)      → el último candado antes de bajarlo
   ============================================================================ */
(function (raiz) {
  "use strict";

  // ---------------------------------------------------------------- utilidades
  const sinAcentos = s => s.normalize("NFD").replace(/[̀-ͯ]/g, "");
  const norma = s => sinAcentos(String(s || "").toLowerCase())
    .replace(/^#+\s*/, "").replace(/\s*:\s*$/, "").replace(/\s+/g, " ").trim();

  const centavos = n => Math.round(Number(n) * 100);
  const dinero = c => (c / 100).toLocaleString("en-US",
    { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  // ---------------------------------------------------------- títulos y alias
  const SECCIONES = {
    datos:      ["datos", "trabajo"],
    hoy:        ["hoy", "lo que hay", "existente", "existing"],
    cambia:     ["cambia", "que cambia", "nuevo", "new layout"],
    falta:      ["falta", "lo que falta", "sin datos", "falta informacion", "basis"],
    alcance:    ["alcance", "incluye", "scope", "included"],
    no_incluye: ["no incluye", "excluye", "exclusiones", "not included", "fuera"],
    opciones:   ["opciones", "opcionales", "extras", "add-ons", "addons"],
    condiciones:["condiciones", "clausulas", "interruptores"],
    codigo:     ["codigo", "nec", "code"],
    notas:      ["notas", "nota", "para mi"]
  };
  const TITULO_DE = {};
  Object.entries(SECCIONES).forEach(([k, alias]) => alias.forEach(a => { TITULO_DE[a] = k; }));

  // Claves "Nombre: valor" de la cabecera
  const CLAVES_DATOS = {
    cliente:            ["cliente", "client"],
    segundo_firmante:   ["segundo firmante", "segunda firma", "firman", "second signer"],
    atencion:           ["atencion", "attention", "contacto"],
    dueno:              ["dueno de la casa", "dueno", "homeowner", "propietario"],
    direccion:          ["direccion", "address"],
    ciudad:             ["ciudad", "jurisdiccion", "city"],
    proyecto:           ["proyecto", "nombre del trabajo", "project"],
    firma:              ["firma", "con firma"],
    permiso:            ["permiso", "permit"],
    planos:             ["planos", "drawings"],
    ingenieria:         ["ingenieria", "engineering", "load calc"],
    utility:            ["utility", "compania electrica"],
    layout:             ["layout", "aprobacion de layout"],
    vence:              ["vence", "vigencia", "vale", "valid"]
  };
  // Claves de dinero, que van en su propia sección
  const CLAVES_DINERO = { precio: ["precio", "total", "precio base", "price"],
                          pagos:  ["pagos", "hitos", "milestones", "cobros"] };

  // Claves de Condiciones
  const CLAVES_COND = {
    fotos_panel:        ["fotos del panel", "fotos de panel", "foto del panel", "panel photos"],
    circuitos_exist:    ["circuitos existentes", "circuitos existente", "existing circuits"],
    v240:               ["240v", "240", "circuito de 240", "reuso 240"],
    reubicar:           ["reubicar", "mover equipo", "relocate"],
    isla:               ["isla", "peninsula", "island"],
    abrir:              ["abrir", "aberturas", "abrir paredes", "abrir techo"],
    fixtures_cliente:   ["fixtures del cliente", "lamparas del cliente", "owner fixtures"],
    fixtures_mxp:       ["fixtures nuestros", "fixtures nuestras", "lamparas nuestras", "nuestros fixtures"],
    excavacion:         ["excavacion", "zanja", "bajo losa", "subsuelo"],
    listo_rough:        ["listo antes del rough", "listo para rough", "listo rough"],
    acceso:             ["acceso", "access"],
    fases:              ["fases", "phases"],
    areas:              ["areas", "areas incluidas", "donde trabajo"],
    no_tocamos:         ["no tocamos", "no tocas", "fuera de area"],
    no_excluir:         ["no excluir", "si hacemos", "quitar exclusion"]
  };
  const buscaClave = (tabla, nombre) => {
    const n = norma(nombre);
    for (const [k, alias] of Object.entries(tabla)) if (alias.includes(n)) return k;
    return null;
  };
  // Parecido de letras, para "¿querías decir…?"
  function parecido(a, b) {
    a = norma(a); b = norma(b);
    if (a === b) return 1;
    const m = a.length, n = b.length;
    const d = Array.from({ length: m + 1 }, (_, i) => [i, ...Array(n).fill(0)]);
    for (let j = 0; j <= n; j++) d[0][j] = j;
    for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++)
      d[i][j] = Math.min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + (a[i-1] === b[j-1] ? 0 : 1));
    return 1 - d[m][n] / Math.max(m, n);
  }
  function sugerir(tabla, nombre) {
    let mejor = null, punt = 0;
    for (const [k, alias] of Object.entries(tabla)) for (const a of alias) {
      const p = parecido(nombre, a);
      if (p > punt) { punt = p; mejor = a; }
    }
    return punt >= 0.72 ? mejor : null;
  }

  // ------------------------------------------------------------------- dinero
  // Devuelve { centavos } · { pregunta } si la coma es dudosa · null si no hay
  function leerMonto(texto) {
    const s = String(texto || "").trim();
    const m = s.match(/\$?\s*(\d[\d,]*(?:\.\d+)?)/);
    if (!m) return null;
    const crudo = m[1];
    // coma seguida de 1 o 2 dígitos: no se adivina, se pregunta
    const dudosa = crudo.match(/,(\d{1,2})(?!\d)/);
    if (dudosa) {
      const comoMiles = Number(crudo.replace(/,/g, "") + "0".repeat(3 - dudosa[1].length));
      const comoCentavos = Number(crudo.replace(",", "."));
      return { pregunta: true, crudo, opciones: [comoMiles, comoCentavos] };
    }
    const n = Number(crudo.replace(/,/g, ""));
    if (!isFinite(n)) return null;
    return { centavos: centavos(n) };
  }
  // ¿esta línea lleva dinero? (12/2, 20A, #6, 50 ft NO son dinero)
  function pareceDinero(linea) {
    const s = String(linea);
    if (/\$\s*\d/.test(s)) return true;
    if (/\b\d{1,3}(,\d{3})+(\.\d{2})?\b/.test(s)) return true;
    if (/\b\d+\.\d{2}\b/.test(s) && !/\b\d+\/\d+\b/.test(s)) return true;
    if (/\b(dolares|dollars|usd)\b/i.test(sinAcentos(s))) return true;
    return false;
  }

  // Reparte un total entre porcentajes, al centavo. El último absorbe el resto.
  function repartir(totalCentavos, pcts) {
    const partes = pcts.map(p => Math.round(totalCentavos * p / 100));
    const suma = partes.reduce((a, b) => a + b, 0);
    partes[partes.length - 1] += totalCentavos - suma;
    return partes;
  }

  // ================================================================ EL LECTOR
  function leerAlcance(texto) {
    const lineas = String(texto || "").replace(/\r/g, "").split("\n");
    const R = {
      datos: {}, hoy: "", cambia: "", falta: "", items: [], no_incluye: [],
      precio: null, pagos: null, opciones: [], condiciones: {}, codigo: [],
      notas: "", errores: [], avisos: [], preguntas: [], lineas
    };
    let sec = "datos", itemActual = null, opcionActual = null;
    const parrafo = { hoy: [], cambia: [], falta: [], notas: [] };

    const err = (i, texto, extra) => R.errores.push(Object.assign({ linea: i + 1, texto }, extra || {}));

    lineas.forEach((cruda, i) => {
      const linea = cruda.trim();
      if (!linea || linea.startsWith("//") || linea.startsWith(">") || linea.startsWith("<!--")) return;

      // ¿es un título de sección?
      const posible = TITULO_DE[norma(linea)];
      if (posible) { sec = posible; itemActual = null; opcionActual = null; return; }

      // ¿es "Nombre: valor"?
      const mNV = linea.match(/^([^:]{2,42}):\s*(.*)$/);
      const nombre = mNV ? norma(mNV[1]) : null;
      const valor  = mNV ? mNV[2].trim() : null;

      // --- Precio y Pagos, estén donde estén (son títulos con valor en la misma línea)
      if (mNV && buscaClave(CLAVES_DINERO, nombre) === "precio") {
        const m = leerMonto(valor);
        if (!m) err(i, "No entiendo el precio. Escríbelo así: 16,498.24");
        else if (m.pregunta) R.preguntas.push({ clave: "precio", linea: i + 1,
          texto: `¿El precio es $${m.opciones[0].toLocaleString("en-US")} o $${m.opciones[1].toFixed(2)}?`,
          opciones: m.opciones.map(v => ({ etiqueta: "$" + v.toLocaleString("en-US", {minimumFractionDigits:2}), valor: centavos(v) })) });
        else if (R.precio) err(i, "Hay dos precios. Solo va uno: el precio base sin opciones.");
        else R.precio = { centavos: m.centavos, linea: i + 1 };
        return;
      }
      if (mNV && buscaClave(CLAVES_DINERO, nombre) === "pagos") {
        R.pagos = leerPagos(valor, i + 1, err);
        sec = "pagos_detalle";
        return;
      }

      switch (sec) {
        case "datos": {
          if (!mNV) { const s = sugerir(SECCIONES, linea);
            R.avisos.push({ linea: i + 1, texto: s ? `"${linea}" no es un título que conozca. ¿Querías decir "${s}"?`
                                                   : `No sé dónde poner "${linea}".`, sugerencia: s });
            return; }
          const k = buscaClave(CLAVES_DATOS, nombre);
          if (k) { R.datos[k] = valor; }
          else { const s = sugerir(CLAVES_DATOS, mNV[1]);
                 R.avisos.push({ linea: i + 1, texto: s ? `No conozco "${mNV[1].trim()}". ¿Querías decir "${s}"?`
                                                        : `No conozco el dato "${mNV[1].trim()}".`, sugerencia: s }); }
          break;
        }
        case "hoy": case "cambia": case "falta": case "notas":
          if (sec !== "notas" && pareceDinero(linea))
            err(i, `Hay un precio en esta línea y aquí no van precios. El dinero solo va en Precio, Pagos y Opciones.`,
                { botones: ["Quitarlo", "Es una opción", "Volver al texto"] });
          parrafo[sec].push(linea.replace(/^[-*•]\s*/, ""));
          break;

        case "alcance": {
          if (pareceDinero(linea)) {
            err(i, "Hay un precio dentro del Alcance. El dinero solo va en Precio, Pagos y Opciones.",
                { botones: ["Quitarlo", "Es una opción", "Volver al texto"] });
            return;
          }
          const esDetalle = /^[-*•]/.test(linea);
          if (esDetalle) {
            if (!itemActual) { err(i, "Este detalle no tiene renglón encima. Ponle un título al renglón."); return; }
            itemActual.detalles.push(linea.replace(/^[-*•]\s*/, "")); itemActual.lineas.push(i + 1);
          } else {
            const mn = linea.match(/^(\d+)[.)\-]\s*(.+)$/);
            itemActual = { n: R.items.length + 1, escrito: mn ? Number(mn[1]) : null,
                           titulo: mn ? mn[2].trim() : linea, detalles: [], lineas: [i + 1] };
            R.items.push(itemActual);
          }
          break;
        }
        case "no_incluye": {
          if (pareceDinero(linea)) { err(i, "Hay un precio en No incluye. El dinero solo va en Precio, Pagos y Opciones.",
              { botones: ["Quitarlo", "Es una opción", "Volver al texto"] }); return; }
          R.no_incluye.push({ texto: linea.replace(/^[-*•]\s*/, ""), linea: i + 1 });
          break;
        }
        case "opciones": {
          const esDetalle = /^[-*•]/.test(linea);
          if (esDetalle) {
            if (opcionActual) opcionActual.detalles.push(linea.replace(/^[-*•]\s*/, ""));
            else err(i, "Este detalle no tiene opción encima.");
            break;
          }
          const mn = linea.match(/^(?:(\d+)[.)\-]\s*)?(.+)$/);
          let resto = mn[2].trim();
          // el precio va al final, tras ":" o "—" o "-"
          const mp = resto.match(/^(.*?)[\s]*[—–:-][\s]*(\$?\s*[\d.,]+)\s*$/);
          let precio = null, titulo = resto;
          if (mp) { titulo = mp[1].trim(); precio = leerMonto(mp[2]); }
          if (!precio) {
            err(i, `La opción "${titulo.slice(0, 40)}" no tiene precio. Los añadidos van con monto, o no van.`);
            opcionActual = null; break;
          }
          if (precio.pregunta) {
            R.preguntas.push({ clave: "opcion_" + (R.opciones.length + 1), linea: i + 1,
              texto: `¿La opción "${titulo.slice(0,30)}" cuesta $${precio.opciones[0].toLocaleString("en-US")} o $${precio.opciones[1].toFixed(2)}?`,
              opciones: precio.opciones.map(v => ({ etiqueta: "$" + v.toLocaleString("en-US", {minimumFractionDigits:2}), valor: centavos(v) })) });
            precio = { centavos: centavos(precio.opciones[0]), dudoso: true };
          } else if (precio.centavos < 10000) {
            R.preguntas.push({ clave: "opcion_" + (R.opciones.length + 1), linea: i + 1,
              texto: `¿La opción "${titulo.slice(0,30)}" cuesta $${dinero(precio.centavos)}? Parece poco.`,
              opciones: [{ etiqueta: "Sí, ese es el precio", valor: precio.centavos }, { etiqueta: "No, lo corrijo", valor: null }] });
          }
          opcionActual = { n: R.opciones.length + 1, titulo, centavos: precio.centavos, detalles: [], linea: i + 1 };
          R.opciones.push(opcionActual);
          break;
        }
        case "pagos_detalle": {
          // líneas sueltas debajo de "Pagos:" — una por pago
          const mp = linea.match(/^(\d{1,3})\s*%\s*(.*)$/);
          if (mp) { R.pagos = R.pagos || { pcts: [], disparadores: [], lineas: [] };
                    R.pagos.pcts.push(Number(mp[1]));
                    R.pagos.disparadores.push(mp[2].trim() || null);
                    R.pagos.lineas.push(i + 1); }
          else { sec = "condiciones"; /* se cayó a Condiciones sin título */ }
          if (mp) break;
          /* falls through */
        }
        case "condiciones": {
          if (!mNV) { R.avisos.push({ linea: i + 1, texto: `No sé dónde poner "${linea.slice(0,45)}" dentro de Condiciones.` }); break; }
          const k = buscaClave(CLAVES_COND, nombre);
          if (k) R.condiciones[k] = { valor, linea: i + 1 };
          else { const s = sugerir(CLAVES_COND, mNV[1]);
                 R.avisos.push({ linea: i + 1, texto: s ? `No conozco "${mNV[1].trim()}". ¿Querías decir "${s}"?`
                                                        : `No conozco la condición "${mNV[1].trim()}".`, sugerencia: s }); }
          break;
        }
        case "codigo": {
          linea.split(/[,;]/).forEach(a => { const v = a.trim();
            if (!v) return;
            if (/^\d{3}(\.\d+([A-Za-z()0-9]*)?)?$/.test(v)) R.codigo.push(v);
            else err(i, `"${v}" no tiene forma de artículo. Escribe 210, 210.8 o 406.4(D).`); });
          break;
        }
      }
    });

    R.hoy = parrafo.hoy.join(" ");
    R.cambia = parrafo.cambia.join(" ");
    R.falta = parrafo.falta.join(" ");
    R.notas = parrafo.notas.join("\n");
    R.items.forEach((it, k) => { it.n = k + 1; });
    return R;
  }

  // "40/40/20" o "40% al firmar, 40% rough, 20% final"
  function leerPagos(valor, linea, err) {
    const P = { pcts: [], disparadores: [], lineas: [linea] };
    const corto = String(valor || "").match(/^\s*(\d{1,3})\s*[\/\-\s]\s*(\d{1,3})(?:\s*[\/\-\s]\s*(\d{1,3}))?(?:\s*[\/\-\s]\s*(\d{1,3}))?\s*$/);
    if (corto) { for (let k = 1; k < corto.length; k++) if (corto[k] !== undefined) { P.pcts.push(Number(corto[k])); P.disparadores.push(null); } return P; }
    String(valor || "").split(/[,;]| y /).forEach(t => {
      const m = t.match(/(\d{1,3})\s*%\s*(.*)/);
      if (m) { P.pcts.push(Number(m[1])); P.disparadores.push((m[2] || "").trim() || null); }
    });
    return P;
  }

  // ============================================================ LA VALIDACIÓN
  function validarAlcance(L) {
    const errores = L.errores.slice(), preguntas = L.preguntas.slice();
    const D = L.datos, conFirma = norma(D.firma || "si") !== "no";

    if (!D.cliente) preguntas.push({ clave: "cliente", texto: "¿Quién es el cliente (quien paga y firma)?", libre: true });
    if (!D.direccion) preguntas.push({ clave: "direccion", texto: "¿Cuál es la dirección de la obra?", libre: true });
    if (!L.items.length) errores.push({ texto: "La sección Alcance está vacía. Sin ella no hay contrato." });
    if (!L.precio) errores.push({ texto: "Falta el precio base en Precio." });

    // los renglones, numerados seguidos si Edgar los numeró
    const escritos = L.items.filter(i => i.escrito !== null).map(i => i.escrito);
    if (escritos.length && escritos.some((v, k) => v !== k + 1))
      errores.push({ texto: `Los renglones del Alcance tienen que ir 1, 2, 3 seguidos. Escribiste: ${escritos.join(", ")}.` });

    // dos firmantes
    if (D.cliente && !D.segundo_firmante && /\s(y|&|and)\s/i.test(D.cliente))
      preguntas.push({ clave: "dos_firmas", texto: `"${D.cliente}" ¿son dos personas que firman las dos?`,
        opciones: [{ etiqueta: "Sí, firman las dos" }, { etiqueta: "No, es un solo firmante" }] });

    // ciudad
    if (!D.ciudad && D.direccion) {
      const trozo = String(D.direccion).split(",")[1];
      preguntas.push({ clave: "ciudad", texto: `¿La jurisdicción del permiso es ${(trozo || "").trim()}?`,
        opciones: [{ etiqueta: "Sí", valor: (trozo || "").trim() }, { etiqueta: "Otra", libre: true }] });
    }

    // pagos
    if (conFirma) {
      if (!L.pagos || !L.pagos.pcts.length)
        preguntas.push({ clave: "pagos", texto: "¿Cómo se cobra?",
          opciones: [{ etiqueta: "40/40/20", valor: [40,40,20] }, { etiqueta: "50/50", valor: [50,50] },
                     { etiqueta: "35/40/25", valor: [35,40,25] }] });
      else {
        const suma = L.pagos.pcts.reduce((a, b) => a + b, 0);
        if (suma !== 100) errores.push({ texto: `Los pagos suman ${suma}%. Tienen que sumar 100 exacto.`, linea: L.pagos.lineas[0] });
        if (L.pagos.pcts[0] === 0) errores.push({ texto: "El primer pago es el depósito y no puede ser 0%." });
        if (L.pagos.pcts.some(p => !Number.isInteger(p))) errores.push({ texto: "Los pagos van en porcentajes enteros." });
      }
    }

    // las dos condiciones que más protegen
    const C = L.condiciones;
    const si_no = v => { const n = norma(v && v.valor); return n === "si" || n === "yes" ? true : (n === "no" ? false : null); };
    if (si_no(C.fotos_panel) === null)
      preguntas.push({ clave: "fotos_panel", texto: "¿Tienes fotos o documentación del panel?",
        opciones: [{ etiqueta: "Sí las tengo", valor: "si" }, { etiqueta: "No las tengo", valor: "no" }] });
    if (si_no(C.circuitos_exist) === null)
      preguntas.push({ clave: "circuitos_exist", texto: "¿Este trabajo extiende o modifica circuitos que ya existen?",
        opciones: [{ etiqueta: "Sí", valor: "si" }, { etiqueta: "No", valor: "no" }] });

    if (si_no(C.fotos_panel) === false && !L.falta)
      errores.push({ texto: "Dijiste que no tienes fotos del panel: escribe en «Falta» qué te faltó al cotizar." });

    // opciones
    if (L.opciones.length > 4) errores.push({ texto: "Caben hasta cuatro opciones." });

    // renglones referidos que no existen
    [["v240","240V"],["reubicar","Reubicar"],["isla","Isla"],["abrir","Abrir"]].forEach(([k, etiqueta]) => {
      const v = C[k]; if (!v || !v.valor) return;
      const m = String(v.valor).match(/rengl[oó]n(?:es)?\s+([\d,\sy]+)/i);
      if (!m) return;
      m[1].split(/[,\sy]+/).filter(Boolean).forEach(x => {
        const n = Number(x);
        if (n && n > L.items.length) errores.push({ linea: v.linea,
          texto: `${etiqueta} dice renglón ${n} pero solo hay ${L.items.length} renglones en el Alcance.` });
      });
    });
    if (C.v240 && C.v240.valor && !/#\s*\d+|awg/i.test(C.v240.valor))
      errores.push({ linea: C.v240.linea, texto: "240V necesita tres datos: equipo, renglón y calibre. Ejemplo: «estufa, renglón 2, hasta #8»." });

    // el Alcance habla de panel y la exclusión sigue puesta
    const noExcluir = norma((C.no_excluir || {}).valor || "");
    const textoAlcance = norma(L.items.map(i => i.titulo + " " + i.detalles.join(" ")).join(" "));
    [["panel", "panel"], ["afci", "afci"]].forEach(([palabra, clave]) => {
      if (textoAlcance.includes(palabra) && !noExcluir.includes(clave))
        preguntas.push({ clave: "no_excluir_" + clave,
          texto: `Tu alcance habla de ${palabra} y la sección 3 lo sigue excluyendo. ¿Quito esa exclusión?`,
          opciones: [{ etiqueta: "Sí, quítala", valor: clave }, { etiqueta: "No, déjala", valor: null }] });
    });

    return { errores, preguntas, puedeSeguir: errores.length === 0 };
  }

  // ================================================================ EL DINERO
  const DISPARADORES = {
    3: ["Deposit upon acceptance — material order{{, permit submittal}} and mobilization",
        "Rough-in complete and rough inspection passed",
        "Trim-out complete, final inspection passed, all circuits energized"],
    2: ["Deposit upon acceptance — material order{{, permit submittal}} and mobilization",
        "Substantial completion — final inspection passed, all circuits energized"],
    1: ["Upon completion of the work"]
  };

  function cuentas(L) {
    const base = L.precio ? L.precio.centavos : 0;
    const pcts = (L.pagos && L.pagos.pcts.length) ? L.pagos.pcts.slice() : [];
    const montos = pcts.length ? repartir(base, pcts) : [];
    const addons = L.opciones.map((o, k) => ({
      letra: String.fromCharCode(66 + k), titulo: o.titulo, centavos: o.centavos }));
    return {
      base, pcts, montos,
      hitos: pcts.map((p, k) => ({
        n: k + 1, pct: p, centavos: montos[k], es_deposito: k === 0,
        disparador: (L.pagos.disparadores[k]) || (DISPARADORES[pcts.length] || [])[k] || null })),
      addons,
      total_con_todo: base + addons.reduce((a, b) => a + b.centavos, 0),
      pct_deposito: pcts.length ? pcts[0] : null,
      deposito_mayor_10: pcts.length ? (montos[0] * 10 > base) : false
    };
  }

  // ================================================== QUÉ VA Y QUÉ NO (la tabla)
  function decidirInterruptores(L, D) {
    const d = L.datos, C = L.condiciones, cuenta = D || cuentas(L);
    const hay = v => !!(v && String(v).trim() && norma(v) !== "no");
    const si_no = v => { const n = norma(v && v.valor); return n === "si" || n === "yes" ? true : (n === "no" ? false : null); };
    const conFirma = norma(d.firma || "si") !== "no";
    const esGC = hay(d.dueno);
    const permiso = norma(d.permiso || "") || "nosotros";   // regla de la casa
    const layout = norma(d.layout || "si") !== "no";
    const noExcluir = norma((C.no_excluir || {}).valor || "");

    const bloques = {
      VARIANTE_B: conFirma, VARIANTE_A: !conFirma,
      ATTENTION: hay(d.atencion), HOMEOWNER: esGC, GC: esGC,
      PLANOS: hay(d.planos),
      QUE_HAY_HOY: !!L.hoy, QUE_CAMBIA: !!L.cambia, FALTA: !!L.falta,
      INGENIERIA: hay(d.ingenieria),
      FIXTURES_CLIENTE: hay((C.fixtures_cliente || {}).valor),
      PERMISO_CLIENTE: permiso === "cliente",
      PERMISO_MXP: permiso === "nosotros",
      PERMISO_NINGUNO: permiso.indexOf("no hace falta") === 0 || permiso === "ninguno",
      ADDONS: L.opciones.length > 0,
      UTILITY: hay(d.utility),
      LAYOUT: layout, NO_LAYOUT: !layout,
      CLIENT_2: hay(d.segundo_firmante) || esGC,
      EXCL_PANEL: !noExcluir.includes("panel"),
      EXCL_AFCI: !noExcluir.includes("afci"),
      EXCL_GABINETES: !noExcluir.includes("gabinete"),
      EXCL_DRYWALL: !noExcluir.includes("drywall"),
      EXCL_LOWVOLT: !noExcluir.includes("low-voltage") && !noExcluir.includes("low voltage"),
      EXCL_APARATOS: !noExcluir.includes("aparato"),
      EXCL_FUERA_AREAS: !noExcluir.includes("fuera-de-area") && !noExcluir.includes("fuera de area"),
      EXCL_AHJ: !noExcluir.includes("inspector") && !noExcluir.includes("ahj")
    };

    const clausulas = {
      garantia: true, existentes: true, sitio: true, edicion: true,
      cambios: true, limite: true, seguro: true, cancelacion_tardia: true,
      panel_sin_fotos: si_no(C.fotos_panel) === false,
      afci: si_no(C.circuitos_exist) === true,
      reuso_240: hay((C.v240 || {}).valor),
      reubicar: hay((C.reubicar || {}).valor),
      isla: hay((C.isla || {}).valor),
      aberturas: hay((C.abrir || {}).valor),
      fixtures_cliente: bloques.FIXTURES_CLIENTE,
      fixtures_mxp: hay((C.fixtures_mxp || {}).valor),
      subsuelo: hay((C.excavacion || {}).valor),
      planos_permiso: bloques.PLANOS,
      deposito: conFirma && cuenta.deposito_mayor_10
    };
    // con SOW ligero no hay sección 9
    if (!conFirma) Object.keys(clausulas).forEach(k => { clausulas[k] = false; });

    const motivos = {
      panel_sin_fotos: "porque pusiste «Fotos del panel: no»",
      afci: "porque pusiste «Circuitos existentes: sí»",
      reuso_240: "porque pusiste «240V»", reubicar: "porque pusiste «Reubicar»",
      isla: "porque pusiste «Isla»", aberturas: "porque pusiste «Abrir»",
      fixtures_cliente: "porque las lámparas las pone el cliente",
      fixtures_mxp: "porque las lámparas las pones tú",
      subsuelo: "porque hay excavación o trabajo bajo losa",
      planos_permiso: "porque entregas planos",
      deposito: "porque el depósito pasa del 10% del precio"
    };
    return { bloques, clausulas, motivos, permiso, esGC, conFirma };
  }

  // =============================================== EL ENCARGO PARA EL ASISTENTE
  function prepararEncargo(L, dec) {
    const d = L.datos, C = L.condiciones;
    const dec2 = dec || decidirInterruptores(L);
    const filas = [];
    const pon = (etiqueta, texto) => { if (texto && String(texto).trim()) filas.push(`${etiqueta}: ${texto}`); };

    filas.push(`MODO: ${dec2.esGC ? "GC" : "directo"}   FIRMA: ${dec2.conFirma ? "si" : "no"}   PERMISO: ${dec2.permiso}`);
    const encendidas = Object.entries(dec2.clausulas).filter(([, v]) => v).map(([k]) => k);
    filas.push("CLAUSULAS ENCENDIDAS: " + encendidas.join(", "));
    pon("PROYECTO (traducir el titulo)", d.proyecto);
    pon("HOY", L.hoy); pon("CAMBIA", L.cambia); pon("FALTA", L.falta);
    pon("INGENIERIA", d.ingenieria); pon("PLANOS", d.planos); pon("UTILITY", d.utility);
    L.items.forEach(it => {
      filas.push(`RENGLON ${it.n} · titulo: ${it.titulo}`);
      it.detalles.forEach(x => filas.push(`RENGLON ${it.n} · detalle: ${x}`));
    });
    L.no_incluye.forEach((x, k) => filas.push(`NO INCLUYE ${k + 1}: ${x.texto}`));
    L.opciones.forEach(o => {
      filas.push(`OPCION ${o.n} · titulo: ${o.titulo}`);
      o.detalles.forEach(x => filas.push(`OPCION ${o.n} · detalle: ${x}`));
    });
    (L.pagos ? L.pagos.disparadores : []).forEach((x, k) => { if (x) filas.push(`PAGO ${k + 1} · disparador: ${x}`); });
    [["listo_rough","LISTO PARA ROUGH"],["acceso","ACCESO"],["fases","FASES"],
     ["areas","AREAS INCLUIDAS"],["no_tocamos","NO TOCAMOS"],
     ["fixtures_cliente","FIXTURES DEL CLIENTE"],["fixtures_mxp","FIXTURES NUESTROS"],
     ["abrir","ABRIR"],["v240","240V"],["reubicar","REUBICAR"]].forEach(([k, etiqueta]) => {
      if (C[k] && C[k].valor) pon(etiqueta, C[k].valor);
    });

    const texto = filas.join("\n");
    // candado: ni un dólar puede salir de aquí
    const sucias = texto.split("\n").filter(pareceDinero);
    return { texto, limpio: sucias.length === 0, sucias };
  }

  // ==================================================== REVISAR LO QUE DEVOLVIÓ
  // Lo que el asistente NO puede escribir nunca: dinero, porcentajes, artículos del
  // código, números de cláusula y marcas de plantilla. (Palabras como "warranty" sí
  // puede escribirlas: salen de las exclusiones que escribe Edgar.)
  const PROHIBIDAS = /\$|\b\d{1,3}(,\d{3})+\b|\bpercent\b|%|\bArticle\s+\d|\bNEC\b|\bNFPA\b|\bSection\s+9\b|\bStatute\b|\{\{/i;
  function validarSalida(L, S) {
    const rojos = [], amarillos = [];
    const mira = (clave, obj) => {
      if (!obj || !obj.en) return;
      if (PROHIBIDAS.test(obj.en)) rojos.push({ clave, texto: "El asistente escribió algo que no puede escribir. Se descarta y se vuelve a redactar solo esto." });
      if (!obj.de || !obj.de.length) amarillos.push({ clave, texto: "Este texto no dice de qué línea sale." });
    };
    ["proyecto_en","resumen_del_trabajo","que_hay_hoy","que_cambia","que_faltaba",
     "load_calc_y_planos","planos","resumen_corrido","areas_incluidas","lo_que_no_tocas",
     "que_tiene_que_estar_listo","lista_de_fases","acceso","cuales_fixtures","fixtures_mxp",
     "aberturas"].forEach(k => mira(k, S[k]));
    (S.items || []).forEach((it, k) => { mira(`items.${k}.titulo`, it.titulo); mira(`items.${k}.descripcion`, it.descripcion); });
    (S.no_incluye || []).forEach((x, k) => { mira(`no_incluye.${k}.titulo`, x.titulo); mira(`no_incluye.${k}.texto`, x.texto); });
    (S.opciones || []).forEach((x, k) => { mira(`opciones.${k}.titulo`, x.titulo); mira(`opciones.${k}.descripcion`, x.descripcion); });

    if ((S.items || []).length !== L.items.length)
      rojos.push({ clave: "items", texto: `El asistente devolvió ${(S.items||[]).length} renglones y tú escribiste ${L.items.length}. Se descarta.` });
    if ((S.opciones || []).length !== L.opciones.length)
      rojos.push({ clave: "opciones", texto: `Devolvió ${(S.opciones||[]).length} opciones y hay ${L.opciones.length}.` });
    return { rojos, amarillos, sirve: rojos.length === 0 };
  }

  // ============================================================ LA PLANTILLA
  function marcasEmparejadas(html) {
    const pares = [["@si ", "@/si"], ["@fila ", "@/fila"], ["@clausula ", "@/clausula"], ["@ver ", "@/ver"]];
    return pares.every(([a, c]) => {
      const na = (html.match(new RegExp("<!--" + a.trim() + "\\s", "g")) || []).length;
      const nc = (html.match(new RegExp("<!--" + c + "-->", "g")) || []).length;
      return na === nc && na > 0;
    });
  }

  // Corta el trozo entre <!--@X nombre--> y su <!--@/X--> respetando anidados
  function bloque(html, tipo, desde) {
    const abre = new RegExp("<!--@" + tipo + " ([^>]+?)-->", "g");
    abre.lastIndex = desde || 0;
    const m = abre.exec(html);
    if (!m) return null;
    const cierra = "<!--@/" + tipo + "-->", abreTxt = "<!--@" + tipo + " ";
    let i = m.index + m[0].length, nivel = 1;
    while (nivel > 0) {
      const c = html.indexOf(cierra, i), a = html.indexOf(abreTxt, i);
      if (c < 0) return null;
      if (a >= 0 && a < c) { nivel++; i = a + abreTxt.length; }
      else { nivel--; i = c + cierra.length; }
    }
    return { nombre: m[1].trim(), ini: m.index, dentroIni: m.index + m[0].length,
             dentroFin: i - cierra.length, fin: i };
  }

  function aplicarSi(html, bloques) {
    let b, guarda = 0;
    while ((b = bloque(html, "si")) && guarda++ < 500) {
      const vale = !!bloques[b.nombre];
      html = html.slice(0, b.ini) + (vale ? html.slice(b.dentroIni, b.dentroFin) : "") + html.slice(b.fin);
    }
    return html;
  }

  function repetirFila(html, nombre, filas) {
    let desde = 0, b;
    while ((b = bloque(html, "fila", desde))) {
      if (b.nombre !== nombre) { desde = b.fin; continue; }
      const patron = html.slice(b.dentroIni, b.dentroFin);
      const salida = filas.map(f => {
        let x = patron;
        Object.entries(f).forEach(([k, v]) => { x = x.split("{{" + k + "}}").join(String(v)); });
        return x;
      }).join("");
      return html.slice(0, b.ini) + salida + html.slice(b.fin);
    }
    return html;
  }

  const ORDEN_9 = ["garantia","existentes","panel_sin_fotos","afci","sitio","reuso_240","reubicar",
                   "isla","edicion","aberturas","fixtures_cliente","fixtures_mxp","subsuelo",
                   "planos_permiso","cambios","limite","seguro","deposito","cancelacion_tardia"];

  function aplicarClausulas(html, clausulas) {
    const numero = {};
    let n = 0;
    ORDEN_9.forEach(k => { if (clausulas[k]) numero[k] = ++n; });
    let b, guarda = 0;
    while ((b = bloque(html, "clausula")) && guarda++ < 200) {
      const vive = !!clausulas[b.nombre];
      let dentro = html.slice(b.dentroIni, b.dentroFin);
      if (vive) dentro = dentro.split("{{N9}}").join(String(numero[b.nombre]));
      html = html.slice(0, b.ini) + (vive ? dentro : "") + html.slice(b.fin);
    }
    // referencias cruzadas
    let v, guarda2 = 0;
    while ((v = bloque(html, "ver")) && guarda2++ < 200) {
      const claves = v.nombre.split(",").map(s => s.trim());
      const vivas = claves.filter(k => k.startsWith("~") || numero[k]);
      let texto = "";
      if (vivas.length) {
        const nums = vivas.map(k => k.startsWith("~") ? k.slice(1) : "9." + numero[k]);
        texto = "See Section" + (nums.length > 1 ? "s " : " ") +
                (nums.length > 1 ? nums.slice(0, -1).join(", ") + " and " + nums[nums.length - 1] : nums[0]);
      }
      let fin = v.fin;
      if (!texto && html[fin] === ".") fin++;                  // se lleva el punto
      let antes = html.slice(0, v.ini);
      if (!texto) antes = antes.replace(/\s+$/, "");
      html = antes + texto + html.slice(fin);
    }
    return { html, numero };
  }

  function rellenarPlantilla(plantilla, datos) {
    // datos: { bloques, clausulas, huecos, items, no_incluye, addons, hitos }
    let h = plantilla;
    h = aplicarSi(h, datos.bloques);
    h = repetirFila(h, "ITEM", datos.items || []);
    h = repetirFila(h, "NO_INCLUYE", datos.no_incluye || []);
    h = repetirFila(h, "ADDON", datos.addons || []);
    h = repetirFila(h, "HITO", datos.hitos || []);
    const r = aplicarClausulas(h, datos.clausulas);
    h = r.html;
    Object.entries(datos.huecos || {}).forEach(([k, v]) => {
      if (v === null || v === undefined || v === "") return;
      h = h.split("{{" + k + "}}").join(String(v));
    });
    // si no hay segunda firma, la tabla pasa a dos columnas
    if (!datos.bloques.CLIENT_2) h = h.split('class="sig-wrap tres"').join('class="sig-wrap dos"');
    return { html: h, numeroClausulas: r.numero };
  }

  // ====================================================== EL ÚLTIMO CANDADO
  const FIJOS = ["350.00", "2.99", "1.5", "2,500", "18", "10", "30", "90", "713"];
  function barridoFinal(html, montosPermitidos) {
    const problemas = [];
    // los comentarios HTML no se imprimen: lo que haya ahí dentro no cuenta
    const visible = html.replace(/<!--[\s\S]*?-->/g, " ");
    const huecos = [...new Set((visible.match(/\{\{[^}]{1,45}\}\}/g) || []))];
    const delPortal = ["{{OPCION_ACEPTADA}}", "{{TOTAL_ACEPTADO}}", "{{FECHA_TRANSACCION}}", "{{FECHA_LIMITE_CANCELAR}}"];
    const quedan = huecos.filter(x => delPortal.indexOf(x) < 0);
    if (quedan.length) problemas.push({ tipo: "hueco", texto: "Quedaron huecos sin llenar: " + quedan.join(", ") });
    if (/<!--@/.test(html)) problemas.push({ tipo: "marca", texto: "Quedó una marca de la plantilla sin resolver." });
    if (/FALTA:/.test(visible)) problemas.push({ tipo: "falta", texto: "Quedó algo marcado como FALTA." });

    const permitidos = new Set([...(montosPermitidos || []), ...FIJOS]);
    const texto = visible.replace(/<style[\s\S]*?<\/style>/g, "").replace(/<[^>]+>/g, " ")
                         .replace(/data:[^\s"']+/g, " ");
    const montos = texto.match(/\$\s?\d{1,3}(?:,\d{3})*(?:\.\d{2})?/g) || [];
    montos.forEach(m => {
      const limpio = m.replace(/[$\s]/g, "");
      if (!permitidos.has(limpio)) problemas.push({ tipo: "monto", texto: `El contrato tiene ${m}, que no lo calculé yo.` });
    });
    return { problemas, sirve: problemas.length === 0 };
  }

  // ============================================ JUNTARLO TODO PARA LA PLANTILLA
  // L = lo leído · S = lo que redactó el asistente (ya revisado por Edgar)
  // admin = { fecha (Date), proyecto_id, direccion, ciudad }
  function armarTodo(L, S, admin) {
    const d = L.datos, C = L.condiciones;
    const cta = cuentas(L);
    const dec = decidirInterruptores(L, cta);
    const hoy = admin.fecha || new Date();
    const dosDig = n => String(n).padStart(2, "0");
    const fechaLarga = f => f.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
    const vence = new Date(hoy.getTime());
    vence.setDate(vence.getDate() + (Number(d.vence) || 15));
    const nombreCorto = String(admin.proyecto_id || d.cliente || "SOW")
      .toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 12);

    // el renglón al que apunta cada cláusula
    const renglon = clave => {
      const v = C[clave]; if (!v || !v.valor) return "";
      const m = String(v.valor).match(/rengl[oó]n(?:es)?\s+([\d,\sy]+)/i);
      if (!m) return "";
      const nums = m[1].split(/[,\sy]+/).filter(Boolean);
      return nums.length > 1 ? nums.slice(0, -1).join(", ") + " and 2." + nums[nums.length - 1] : nums[0];
    };
    const EQUIPOS = { estufa: "range", horno: "oven", secadora: "dryer", "a/c": "A/C", ac: "A/C",
                      fridge: "refrigerator", refrigerador: "refrigerator", nevera: "refrigerator",
                      lavaplatos: "dishwasher", microondas: "microwave", disposal: "disposal",
                      calentador: "water heater" };
    const equipoEn = clave => {
      const v = C[clave]; if (!v || !v.valor) return "";
      const primera = norma(String(v.valor).split(",")[0]);
      for (const [es, en] of Object.entries(EQUIPOS)) if (primera.includes(es)) return en;
      return primera;
    };
    const calibre = () => {
      const v = C.v240; if (!v || !v.valor) return "";
      const m = String(v.valor).match(/#\s*(\d+)|(\d+)\s*awg/i);
      return m ? "#" + (m[1] || m[2]) + " copper" : "";
    };

    const nHitos = cta.hitos.length;
    const finObra = /trim/i.test(String((C.fases || {}).valor || "")) ? "completion of the trim-out"
                                                                     : "completion of the work";
    const huecos = {
      CLIENT: d.cliente || "", CLIENT_2: d.segundo_firmante || (dec.esGC ? d.dueno : ""),
      CONTACTOS: d.atencion || "", HOMEOWNER: dec.esGC ? d.dueno : (d.cliente || ""),
      PROYECTO_EN_INGLES: (S.proyecto_en && S.proyecto_en.en) || d.proyecto || "",
      DIRECCION: admin.direccion || d.direccion || "",
      CIUDAD: d.ciudad || admin.ciudad || "",
      FECHA: fechaLarga(hoy), AAAA: String(hoy.getFullYear()),
      MMDD: dosDig(hoy.getMonth() + 1) + dosDig(hoy.getDate()),
      NOMBRE: nombreCorto, VENCE_30_DIAS: fechaLarga(vence),
      PLANOS: (S.planos && S.planos.en) || d.planos || "",
      RESUMEN_DEL_TRABAJO: (S.resumen_del_trabajo && S.resumen_del_trabajo.en) || "",
      QUE_HAY_HOY: (S.que_hay_hoy && S.que_hay_hoy.en) || "",
      QUE_CAMBIA: (S.que_cambia && S.que_cambia.en) || "",
      QUE_FALTABA: (S.que_faltaba && S.que_faltaba.en) || "",
      LOAD_CALC_Y_PLANOS: (S.load_calc_y_planos && S.load_calc_y_planos.en) || "",
      N_CIERRE: String(L.items.length + 1 + cta.addons.filter((a, k) =>
        (S.opciones || [])[k] && S.opciones[k].descripcion && S.opciones[k].descripcion.en).length),
      CUALES: (S.cuales_fixtures && S.cuales_fixtures.en) || "",
      AREAS_INCLUIDAS: (S.areas_incluidas && S.areas_incluidas.en) || "",
      LO_QUE_NO_TOCAS: (S.lo_que_no_tocas && S.lo_que_no_tocas.en) || "",
      ARTICULOS_NEC_QUE_APLICAN: (admin.nec || L.codigo).map(a => "Article " + a).join(", "),
      RESUMEN_CORRIDO_DE_TODO_EL_ALCANCE: (S.resumen_corrido && S.resumen_corrido.en) || "",
      TOTAL: dinero(cta.base),
      N_ULTIMO: String(nHitos), FIN_OBRA: finObra,
      QUE_TIENE_QUE_ESTAR_LISTO: (S.que_tiene_que_estar_listo && S.que_tiene_que_estar_listo.en) || "",
      N_FASES: String(String((C.fases || {}).valor || "").split("/").filter(x => x.trim()).length || 1),
      LISTA_DE_FASES: (S.lista_de_fases && S.lista_de_fases.en) || "",
      UTILITY: (S.utility && S.utility.quien && S.utility.quien.en) || "",
      QUE_HACE: (S.utility && S.utility.que_hace && S.utility.que_hace.en) || "",
      ACCESO: (S.acceso && S.acceso.en) || "",
      EQUIPO_240: equipoEn("v240"), ITEM_240: renglon("v240"), CALIBRE: calibre(),
      EQUIPO_REUBICAR: equipoEn("reubicar"), ITEM_REUBICAR: renglon("reubicar"),
      ITEM_ISLA: renglon("isla"), ITEMS_ABRIR: renglon("abrir"),
      ABERTURAS: (S.aberturas && S.aberturas.en) || "",
      FIXTURES: (S.fixtures_mxp && S.fixtures_mxp.en) || "",
      M_DEPOSITO: cta.montos.length ? dinero(cta.montos[0]) : "",
      PCT_DEPOSITO: cta.pct_deposito === null ? "" : String(cta.pct_deposito)
    };

    const items = (S.items || []).map((it, k) => ({
      N_ITEM: k + 1, TITULO: (it.titulo && it.titulo.en) || "", DESCRIPCION: (it.descripcion && it.descripcion.en) || "" }));
    // Un añadido con detalles (un rewire, un subpanel) merece su propio párrafo en la
    // sección 2, marcado como opcional, y no solo una línea en la tabla de precios.
    cta.addons.forEach((a, k) => {
      const o = (S.opciones || [])[k] || {};
      const desc = (o.descripcion && o.descripcion.en) || "";
      if (!desc) return;
      items.push({
        N_ITEM: items.length + 1,
        TITULO: `Optional Add-On ${a.letra} \u2014 ${(o.titulo && o.titulo.en) || a.titulo}`,
        DESCRIPCION: desc + ` Not included in the lump sum; priced separately in Section 5 and performed only if the Owner authorizes Option ${a.letra}.`
      });
    });
    const no_incluye = (S.no_incluye || []).map(x => ({
      TITULO_EXCL: (x.titulo && x.titulo.en) || "", TEXTO_EXCL: (x.texto && x.texto.en) || "" }));
    const addons = cta.addons.map((a, k) => ({
      LETRA: a.letra, MONTO: dinero(a.centavos),
      ADDON: ((S.opciones || [])[k] && S.opciones[k].titulo && S.opciones[k].titulo.en) || a.titulo }));
    const hitos = cta.hitos.map(h => ({
      N_HITO: h.n, PCT: h.pct, MONTO: dinero(h.centavos),
      DISPARADOR: String(h.disparador || "").replace("{{, permit submittal}}",
        dec.bloques.PERMISO_MXP ? ", permit submittal" : "") }));

    const montosPermitidos = [dinero(cta.base), ...cta.addons.map(a => dinero(a.centavos)),
                              ...cta.hitos.map(h => dinero(h.centavos))];
    return { cuenta: cta, decision: dec, huecos, items, no_incluye, addons, hitos, montosPermitidos,
             archivo: `MXP-${huecos.AAAA}-${huecos.MMDD}-${nombreCorto}.html` };
  }

  // ------------------------------------------------------------------ export
  const API = { leerAlcance, validarAlcance, cuentas, repartir, leerMonto, pareceDinero,
                decidirInterruptores, prepararEncargo, validarSalida,
                rellenarPlantilla, aplicarSi, repetirFila, aplicarClausulas,
                barridoFinal, marcasEmparejadas, armarTodo, DISPARADORES, ORDEN_9, dinero, centavos, norma };
  if (typeof module !== "undefined" && module.exports) module.exports = API;
  raiz.Alcance = API;
})(typeof globalThis !== "undefined" ? globalThis : this);
