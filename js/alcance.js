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
    hoy:        ["hoy", "lo que hay", "existente", "existing", "existing conditions", "today", "what exists",
                 "project objective and background", "project objective", "objective and background", "background",
                 "project background", "site conditions", "existing site conditions", "overview", "project overview", "general"],
    cambia:     ["cambia", "que cambia", "nuevo", "new layout", "changes", "what changes", "new", "proposed layout", "proposed work", "new work"],
    falta:      ["falta", "lo que falta", "sin datos", "falta informacion", "basis", "basis of information", "missing", "unknowns", "not verified"],
    alcance:    ["alcance", "incluye", "scope", "included", "scope of work", "work included", "scope of work included", "work to be performed", "description of work"],
    no_incluye: ["no incluye", "excluye", "exclusiones", "not included", "fuera", "exclusions", "excluded", "not in scope",
                 "scope of work not included", "work not included", "not included in this proposal", "exclusions and clarifications"],
    opciones:   ["opciones", "opcionales", "extras", "add-ons", "addons", "options", "optional add-ons", "optional", "optional add ons", "alternates"],
    precio_detalle: ["price", "pricing", "contract price", "lump sum price", "proposal price", "investment", "price and optional add-ons", "price and payment", "cost"],
    pagos_detalle:  ["payment schedule", "payments", "payment terms", "payment milestones", "schedule of payments", "milestones", "payment"],
    // Lo que el chat escribe y la plantilla ya trae: se salta sin ruido
    // v3.4: lo que la hoja trae de cronograma (7), sección 8 propia y cláusulas (9) YA NO se bota:
    // se lee, se quita lo que la plantilla ya trae y el resto va al contrato tal cual.
    programa:   ["schedule", "timeline", "schedule and coordination", "schedule coordination", "scheduling", "project schedule"],
    pre:        ["pre construction", "pre construction verification", "layout approval", "device layout approval", "circuit identification"],
    terminos:   ["warranty", "terms", "terms and conditions", "general terms", "general conditions", "warranty terms and legal protections",
                 "warranty and terms", "terms and legal protections", "legal protections", "general provisions"],
    ignorar:    ["acceptance", "signature", "signatures", "authorization", "permits and inspections", "permit and inspections", "permitting",
                 "inspections", "contractor", "prepared by", "contact", "legal", "insurance", "change orders", "limitations", "disclaimer"],
    condiciones:["condiciones", "clausulas", "interruptores", "conditions", "assumptions", "assumptions and conditions", "clarifications", "assumptions and clarifications"],
    codigo:     ["codigo", "nec", "code", "applicable code", "applicable codes", "code compliance", "codes", "code references",
                 "applicable codes and standards", "codes and standards", "code and standards", "applicable code and standards", "code requirements"],
    notas:      ["notas", "nota", "para mi", "notes", "note", "internal notes"]
  };
  const TITULO_DE = {};
  Object.entries(SECCIONES).forEach(([k, alias]) => alias.forEach(a => { TITULO_DE[normaTitulo(a)] = k; }));
  // "## 3. Scope of Work — NOT Included:" → "scope of work not included"
  function normaTitulo(t) {
    return norma(String(t || "")
      .replace(/^#+\s*/, "").replace(/^(?:section\s+)?(?:\d+(?:\.\d+)*|[A-Z])[.)]?\s+/, "")
      .replace(/&/g, " and ").replace(/[—–\-:/()]+/g, " ").replace(/\s+/g, " ").trim());
  }
  function seccionDe(linea) {
    const n = normaTitulo(linea);
    if (!n || n.length > 90 || /\bproposal\b/.test(n)) return null;
    if (TITULO_DE[n]) return TITULO_DE[n];
    // sin coincidencia exacta: por las palabras que mandan
    if (/\b(not included|excluded|exclusions?)\b/.test(n)) return "no_incluye";
    if (/\b(optional add ons?|add ons?|options)\b/.test(n)) return "opciones";
    if (/\bpayment/.test(n)) return "pagos_detalle";
    if (/\b(pric(e|ing)|lump sum|investment)\b/.test(n)) return "precio_detalle";
    if (/\bscope of work\b/.test(n)) return "alcance";
    if (/\b(background|objective|existing conditions?)\b/.test(n)) return "hoy";
    if (/\b(pre construction|layout approval|circuit identification|verification before)/.test(n)) return "pre";
    if (/\b(schedule|timeline|coordination)\b/.test(n)) return "programa";
    if (/\b(warranty|terms|legal protections|general conditions)\b/.test(n) && !/\b(acceptance|signature)\b/.test(n)) return "terminos";
    if (/\b(acceptance|signature|permit|inspection|insurance|change order|legal|lien|cancel|consent|notice)/.test(n)) return "ignorar";
    return null;
  }

  // Claves "Nombre: valor" de la cabecera
  const CLAVES_DATOS = {
    cliente:            ["cliente", "client", "customer", "owner", "property owner", "prepared for", "client name"],
    segundo_firmante:   ["segundo firmante", "segunda firma", "firman", "second signer"],
    atencion:           ["atencion", "attention", "contacto", "attn", "contact", "project coordinator", "coordinator", "project manager", "site contact", "gc contact", "attention to"],
    email:              ["email", "e-mail", "correo", "client email", "customer email", "mail"],
    telefono:           ["telefono", "tel", "phone", "cell", "celular", "mobile", "client phone", "customer phone"],
    dueno:              ["dueno de la casa", "dueno", "homeowner", "propietario"],
    // v3.5: el contratista general con el que se contrata (el «Contractor» de la plantilla es Max Power: se ignora)
    contratista:        ["general contractor", "gc", "contractor", "contratista", "contratista general", "subcontract to", "contractor name"],
    // v3.5: el número que trae la hoja manda (antes se ignoraba y la app inventaba otro)
    numero_propuesta:   ["proposal #", "proposal no", "proposal number", "proposal no.", "document no", "document no.", "document number",
                         "numero de propuesta", "propuesta no", "propuesta #", "sow no", "sow #", "reference no", "ref no"],
    // v3.2: quién contrata y qué clase de propiedad es. Deciden si el contrato lleva
    // las páginas de consumidor (aviso de gravámenes y derecho a cancelar en 3 días).
    contrato_con:       ["contrato con", "contract with", "contracting party"],
    propiedad:          ["propiedad", "property", "property type", "tipo de propiedad"],
    direccion:          ["direccion", "address", "job address", "site address", "property address", "project address", "job site", "site"],
    ciudad:             ["ciudad", "jurisdiccion", "city", "jurisdiction", "ahj", "permit jurisdiction", "authority having jurisdiction"],
    proyecto:           ["proyecto", "nombre del trabajo", "project", "project name", "job", "job name", "work", "scope title"],
    firma:              ["firma", "con firma", "signature", "signed"],
    permiso:            ["permiso", "permit"],
    planos:             ["planos", "drawings"],
    ingenieria:         ["ingenieria", "engineering", "load calc"],
    utility:            ["utility", "compania electrica"],
    layout:             ["layout", "aprobacion de layout"],
    vence:              ["vence", "vigencia", "vale", "valid", "expires", "valid for", "valid through", "valid until", "proposal valid", "expiration", "expiration date", "offer valid"],
    // v3.6: la zona de inundación (7.x Flood elevation cuando es AE / VE / AO / AH)
    flood_zona:         ["flood zone", "fema zone", "fema flood zone", "zona de inundacion", "zona fema", "flood"],
    flood_bfe:          ["bfe", "base flood elevation", "design flood elevation"],
    flood_ec:           ["elevation certificate", "ec date", "elevation certificate date", "certificado de elevacion"],
    flood_lag:          ["lag", "lowest adjacent grade"]
  };
  // Datos de la cabecera del chat que no hacen falta (la plantilla los pone sola)
  const CLAVES_IGNORAR = ["prepared by", "preparado por", "proposal", "date", "proposal date",
                          "license", "licencia", "contractor", "company", "field", "value", "item",
                          "description", "milestone", "amount", "trigger", "no", "#", "rev", "revision", "version", "page"];
  // Líneas del membrete del chat: se saltan sin decir nada
  const MEMBRETE = /max power electrical|EC13016045|967-9311|mxpes\.com|licensed\s*[•·|]\s*insured|^scope of work\s*(&|and)\s*proposal$|^proposal$|^electrical proposal$/i;
  // Claves de dinero, que van en su propia sección
  const CLAVES_DINERO = { precio: ["precio", "total", "precio base", "price", "contract price", "base price", "lump sum"],
                          pagos:  ["pagos", "hitos", "milestones", "cobros", "payments", "payment schedule", "payment"] };

  // Claves de Condiciones
  const CLAVES_COND = {
    fotos_panel:        ["fotos del panel", "fotos de panel", "foto del panel", "panel photos"],
    circuitos_exist:    ["circuitos existentes", "circuitos existente", "existing circuits"],
    v240:               ["240v", "240", "circuito de 240", "reuso 240"],
    reubicar:           ["reubicar", "mover equipo", "relocate"],
    isla:               ["isla", "peninsula", "island"],
    abrir:              ["abrir", "aberturas", "abrir paredes", "abrir techo", "openings", "open walls", "open ceiling"],
    fixtures_cliente:   ["fixtures del cliente", "lamparas del cliente", "owner fixtures", "client fixtures", "fixtures by owner"],
    fixtures_mxp:       ["fixtures nuestros", "fixtures nuestras", "lamparas nuestras", "nuestros fixtures", "our fixtures", "fixtures by max power", "contractor fixtures"],
    excavacion:         ["excavacion", "zanja", "bajo losa", "subsuelo", "excavation", "trench"],
    listo_rough:        ["listo antes del rough", "listo para rough", "listo rough", "ready before rough", "ready for rough"],
    acceso:             ["acceso", "access"],
    fases:              ["fases", "phases"],
    areas:              ["areas", "areas incluidas", "donde trabajo", "work areas", "areas included"],
    no_tocamos:         ["no tocamos", "no tocas", "fuera de area", "not touched", "off limits"],
    no_excluir:         ["no excluir", "si hacemos", "quitar exclusion", "do not exclude", "remove exclusion"],
    // v3.7 (tanda 1): qué clase de trabajo es, escrito a mano; manda sobre las listas de palabras del alcance
    tipo_trabajo:       ["tipo de trabajo", "tipo trabajo", "work type", "job type", "type of work", "clase de trabajo"]
  };
  // «Tipo de trabajo: …» se guarda con un valor de la lista: service (exterior: poste, bomba, pozo…), remodel (dentro
  // de una vivienda), new (obra nueva), planos, rapido, mezcla (las dos cosas: no se apaga ninguna exclusión). Lo que
  // no se entiende se queda tal cual, en minúsculas, y no apaga nada.
  function normalizarTipoTrabajo(v) {
    const n = norma(v);
    if (!n) return "";
    if (/\b(mezcla|mixed|both|las dos|ambos|ambas)\b/.test(n)) return "mezcla";
    if (/\b(service|servicio|exterior|outdoor|outside|poste|pole|bomba|pump|pozo|well|riego|irrigation|site)\b/.test(n)) return "service";
    if (/\b(remodel|remodelacion|remodelling|remodeling|interior|vivienda|casa|house|home|residential interior|indoor|inside)\b/.test(n)) return "remodel";
    if (/\b(new|nuevo|nueva|new construction|obra nueva|ground up)\b/.test(n)) return "new";
    if (/\b(planos|plans|drawings|blueprints?)\b/.test(n)) return "planos";
    if (/\b(rapido|quick|fast|small|pequeno|menor)\b/.test(n)) return "rapido";
    return n;
  }
  const buscaClave = (tabla, nombre) => {
    const n = norma(String(nombre || "").replace(/^#+\s*/, "").replace(/^\d+(?:\.\d+)*[.)]?\s+/, "").replace(/\s*[#:]\s*$/, ""));
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
  // Lo que va pegado detrás de un número y lo convierte en MEDIDA, no en dinero:
  // "1,300 sq ft", "2,000 watts", "1,500 lbs". Con esto el año 1926 y los pies
  // cuadrados dejan de parecer precios.
  const UNIDAD_TRAS = new RegExp("^\\s*(?:sq\\.?\\s*(?:ft|feet|foot|m)|square\\s*(?:feet|foot|ft|meters?)|sqft|sf|ft|feet|foot|linear\\s*(?:feet|ft)|pies|pie|in\\.?|inch(?:es)?|yd|yards?|mm|cm|km|mi|miles?|millas?" +
    "|amp(?:s|erios?|eres?)?|volt(?:s|ios?)?|watt?s?|kw|kva|hp|lbs?|libras?|kg|gal(?:s|ones|lons)?|awg|mcm|kcmil|btu|seer|ton(?:s|eladas?)?|psi|rpm" +
    "|circuitos?|circuits?|luces|lights?|lamparas?|fixtures?|outlets?|tomas?|receptaculos?|switch(?:es)?|apagadores?|breakers?|espacios?|spaces?|polos?|poles?" +
    "|unidades?|units?|piezas?|pcs?|hrs?|horas?|hours?|dias?|days?|anos?|years?|sq|cu|%|\u00b0)\\b", "i");
  // Palabras que confirman que sí se está hablando de dinero
  const PALABRA_DINERO = /\b(precio|price|total|costo|coste|cost|cuesta|charge|fee|dep[o\u00f3]sito|deposit|d[o\u00f3]lares|dollars|usd|cada uno|c\/u|each|extra|adicional)\b/i;

  // ¿esta línea lleva dinero?  Devuelve null, o { trozo, seguro }
  //   seguro = true  → lleva $ o la palabra dólares: es dinero sin discusión
  //   seguro = false → tiene forma de dinero pero podría ser una medida o un año
  // (12/2, 20A, #6, 50 ft, 1,300 sq ft y el año 1926 NO son dinero)
  function hayDinero(linea) {
    const s = String(linea);
    const conSigno = s.match(/\$\s*\d[\d,]*(?:\.\d{1,2})?/);
    if (conSigno) return { trozo: conSigno[0].replace(/\s+/g, ""), seguro: true };
    const conPalabra = /\b(dolares|dollars|usd)\b/i.test(sinAcentos(s));
    const rx = /\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2}(?!\d)/g;
    let m;
    while ((m = rx.exec(s))) {
      const antes = s.slice(0, m.index), despues = s.slice(m.index + m[0].length);
      if (/[#\/\-\d.]$/.test(antes)) continue;              // #2/0, 12/2, 210.8
      if (/^\(/.test(despues)) continue;                    // 680.26(B)(2): artículo del código
      if (/^\d{3}\.\d{1,3}$/.test(m[0]) && (/\b(nec|nfpa|section|sections|sec|art|article|articles|and|or|to|through|§)\.?\s*$/i.test(antes)
          || /^\s*(,|and|or|through|to)\s+\d{3}\.\d/.test(despues))) continue;   // NEC 680.26, 250.24 and 408.36
      if (UNIDAD_TRAS.test(despues)) continue;             // 1,300 sq ft
      if (/^\s*[\/\-]\s*\d/.test(despues)) continue;        // 1,000-2,000 de rango raro
      return { trozo: m[0], seguro: conPalabra || PALABRA_DINERO.test(s) };
    }
    if (conPalabra) { const n = s.match(/\d[\d,]*(?:\.\d+)?/); if (n) return { trozo: n[0], seguro: true }; }
    return null;
  }
  // Sí/no, para donde solo hace falta saber si hay dinero de verdad
  function pareceDinero(linea) { const d = hayDinero(linea); return !!(d && d.seguro); }

  // Reparte un total entre porcentajes, al centavo. El último absorbe el resto.
  function repartir(totalCentavos, pcts) {
    const partes = pcts.map(p => Math.round(totalCentavos * p / 100));
    const suma = partes.reduce((a, b) => a + b, 0);
    partes[partes.length - 1] += totalCentavos - suma;
    return partes;
  }

  // ================================================================ EL LECTOR
  function leerAlcance(texto, opciones) {
    const lineas = String(texto || "").replace(/\r/g, "").split("\n");
    // Líneas donde Edgar ya dijo "eso no es dinero" (se guardan por su texto,
    // no por el número de línea, para que aguanten si el texto se mueve)
    const perdonadas = new Set(((opciones || {}).perdonadas || []).map(x => norma(typeof x === "string" ? x : (x && x.texto) || "")));
    // v3.7 (tanda 1): las PISTAS de la lectura inteligente, una por número de línea ({ 44: { rol: "renglon_titulo", … } }).
    // Con pistas (lectura activa) el lector NO adivina: donde hay pista manda la pista; donde no la hay, la línea hereda
    // la sección vigente y se lee con las reglas de siempre. Los títulos ya no se reconocen por su forma (seccionDe /
    // pareceTitulo se apagan): la sección solo cambia por una pista «seccion» o por una línea «Clave: valor» que la app
    // misma reconoce (Precio:, Pagos:). Sin pistas, todo esto no existe y el lector es idéntico al de siempre.
    const pistas = (opciones || {}).pistas || {};
    // solo los papeles de la lista; una pista con un papel inventado no vale y la línea la leen las reglas.
    // La lectura está activa si hay al menos una pista válida (una lectura sin nada útil = leer con las reglas)
    const activa = Object.keys(pistas).some(n => Number(n) >= 1 && Number(n) <= lineas.length && pistas[n] && typeof pistas[n] === "object" && ROLES_PISTA.has(pistas[n].rol));
    const pistaDe = n => (activa && pistas[n] && typeof pistas[n] === "object" && ROLES_PISTA.has(pistas[n].rol)) ? pistas[n] : null;
    // una línea física que sigue a otra (texto de PDF partido) se pega con un espacio a la de arriba antes de leer
    let lineasLeer = lineas;
    if (activa) {
      lineasLeer = lineas.slice();
      Object.keys(pistas).map(Number).filter(n => n >= 1 && n <= lineas.length).sort((a, b) => a - b).forEach(n => {
        const p = pistaDe(n);
        if (!p || p.rol !== "continua" || !Number.isInteger(p.de) || p.de < 1 || p.de >= n) return;
        lineasLeer[p.de - 1] = (lineasLeer[p.de - 1] + " " + lineasLeer[n - 1].replace(/\*\*|__|`/g, "").trim()).trim();
        lineasLeer[n - 1] = "";
      });
    }
    const R = {
      datos: {}, hoy: "", cambia: "", falta: "", items: [], no_incluye: [],
      programa: [], pre: [], pre_intro: "", pre_titulo: "", terminos: [], pagos_propios: [],
      precio: null, pagos: null, opciones: [], condiciones: {}, codigo: [], codigo_grupos: [], codigo_otros: [], codigo_detalle: [],
      notas: "", errores: [], avisos: [], preguntas: [], lineas,
      // en qué línea se reconoció cada título de sección y cada dato de cabecera (lo usa lecturaDeReglas)
      titulos: [], datos_linea: {}, con_pistas: activa
    };
    let sec = "datos", itemActual = null, opcionActual = null;
    const parrafo = { hoy: [], cambia: [], falta: [], notas: [] };

    const err = (i, texto, extra) => R.errores.push(Object.assign({ linea: i + 1, texto }, extra || {}));
    const estaPerdonada = linea => perdonadas.has(norma(linea));
    R.ignoradas = [];
    // Un dato de la cabecera («Clave: valor» que la app reconoce), con sus limpiezas de siempre
    const ponDato = (k, valor, i) => {
      let v = valor;
      if (k === "ciudad") {
        // "Pinellas County, Florida — permit held by General Contractor" → la ciudad limpia y el permiso lo saca el GC
        const mPerm = v.match(/\s*[—–\-(,;]*\s*(?:the\s+)?(?:electrical\s+|building\s+)?permit\b[^)]*?(?:held|pulled|obtained|secured|issued|applied)\s+(?:by|to|under)\s+[^)]*$/i);
        if (mPerm) { const nota = v.slice(mPerm.index); v = v.slice(0, mPerm.index); if (!R.datos.permiso) R.datos.permiso = /max power|us\b|contractor max/i.test(nota) && !/general contractor|\bgc\b/i.test(nota) ? "nosotros" : "GC"; }
        // v3.6: el campo es texto libre y sale tal cual en la cabecera; para la prosa se usa la forma corta
        v = v.replace(/[\s,;—–-]+$/, "").replace(/\s{2,}/g, " ").trim();
        R.datos.ciudad_corta = v.split(/\s+[—–-]\s+|\s*\(/)[0].replace(/,?\s*(?:FL|Florida)\.?\s*$/i, "").replace(/,\s*$/, "").trim();
      }
      if (k === "contratista" && /max power|arboleya|EC13016045/i.test(v)) v = "";
      if (v) { R.datos[k] = v; R.datos_linea[k] = i + 1; }
    };
    // Pone una condición si Edgar no la escribió a mano (lo escrito a mano manda)
    const C_set = (k, valor, i) => { if (R.condiciones[k] || !valor) return false; R.condiciones[k] = { valor: String(valor).trim().replace(/[.,;]$/, ""), linea: i + 1, pescada: true }; return true; };
    // De las secciones que ya trae la plantilla (7, 9) se rescatan los datos que sí son de este trabajo
    const pescar = (linea, i) => {
      let m;
      if ((m = linea.match(/pricing assumes\s+(.+?)\s+when max power mobilizes/i))) C_set("listo_rough", m[1], i);
      else if ((m = linea.match(/performed in\s+\S+\s*(?:\(\d+\))?\s*phases?, and one \(1\) mobilization is included for each:\s*(.+?)\.\s/i))) C_set("fases", partirFases(m[1]).join(" / "), i);
      // cualquier otra forma de decir las movilizaciones: "…three (3) phases/mobilizations: (1) …; (2) …; and (3) …"
      else if ((m = linea.match(/\b(?:phases?|mobilizations?)\b[^:]{0,80}:\s*(.+?)\.?\s*$/i)) && /\(\d\)|;|\band\b/.test(m[1]) && partirFases(m[1]).length >= 2) C_set("fases", partirFases(m[1]).join(" / "), i);
      else if ((m = linea.match(/pricing assumes\s+(.+?)\s+(?:are|is) accessible/i))) C_set("acceso", m[1], i);
      else if ((m = linea.match(/(?:section 2\.(\d+)[^.]*?)?leaves openings in the existing\s+(.+?)\./i))) C_set("abrir", m[2] + (m[1] ? ", renglón " + m[1] : ""), i);
      // "Owner Signature — Lee G. Borders Jr." → el segundo firmante
      (linea.match(/signature\s*[—–-]\s*([^|]+?)(?=\s*\||$)/gi) || []).forEach(x => {
        const nombre = x.replace(/^.*?signature\s*[—–-]\s*/i, "").trim();
        if (nombre && !/arboleya|max power/i.test(nombre) && nombre !== R.datos.cliente && !R.datos.segundo_firmante && R.datos.cliente) R.datos.segundo_firmante = nombre;
      });
    };

    // Un número donde no van números. Si lleva $ es un error rojo; si solo lo
    // parece (podría ser una medida o un año) es un aviso ámbar que no bloquea
    // y trae el botón "eso no es dinero".
    const avisaDinero = (i, linea, donde) => {
      const d = hayDinero(linea);
      if (!d || perdonadas.has(norma(linea))) return false;
      // v3.7 (tanda 1): quitar un monto NUNCA es automático, ni con $ («$500 allowance» lo decide Edgar con un toque)
      const arreglos = [{ tipo: "quitar_dinero", etiqueta: `Quitar ${d.trozo} y dejar el texto`, linea: i + 1, valor: d.trozo, auto: false },
                        { tipo: "quitar_linea", etiqueta: "Quitar la línea entera", linea: i + 1 }];
      if (d.seguro) {
        err(i, `Hay un precio (${d.trozo}) en ${donde}. El dinero solo va en Precio, Pagos y Opciones.`, { trozo: d.trozo, arreglos, perdonable: true });
        return true;
      }
      arreglos.push({ tipo: "no_es_dinero", etiqueta: "Eso no es dinero, déjalo", linea: i + 1, valor: linea });
      R.avisos.push({ linea: i + 1, trozo: d.trozo, arreglos, perdonable: true,
                      texto: `Vi «${d.trozo}» en ${donde} y me pareció un precio. Si es una medida, una cantidad o un año, dímelo y lo dejo como está.` });
      return false;
    };
    // Las preguntas que el chat deja dentro de la hoja: {{FALTA: ¿…?}}
    R.faltas = [];
    lineas.forEach((cruda, i) => {
      const m = cruda.match(/\{\{FALTA:?\s*([^}]*)\}\}/i);
      if (m) R.faltas.push({ linea: i + 1, pregunta: (m[1] || "").trim() || "Aquí el chat dejó algo por contestar",
                             soloMarca: cruda.replace(m[0], "").replace(/^[\s\-*•\d.)]+/, "").trim() === "" });
    });

    // Una sección que el chat escribe y la plantilla ya trae (Warranty, Terms…):
    // se salta entera y se avisa UNA vez, no línea por línea.
    const ignoradas = [];
    // Una fila de tabla "| Milestone | Trigger | % | Amount |" con solo cabeceras
    const esCabeceraTabla = celdas => celdas.every(c => CLAVES_IGNORAR.includes(norma(c)) || /^[-:\s]*$/.test(c));

    // Entrar en una sección: por el título reconocido (sin pistas) o por la pista «seccion» (con pistas)
    const entrarSeccion = (posible, linea, i) => {
      if (posible === "ignorar") ignoradas.push({ linea: i + 1, titulo: linea.replace(/:$/, "") });
      if (posible === "pre" && !R.pre_titulo) {
        // "8 PRE-CONSTRUCTION CIRCUIT IDENTIFICATION — MANDATORY BEFORE DEMOLITION" → en Title Case
        const tt = linea.replace(/^(?:section\s+)?\d+[.)]?\s+/i, "").replace(/:$/, "").trim();
        R.pre_titulo = tt === tt.toUpperCase() ? tt.toLowerCase().replace(/(^|[\s—–-])([a-z])/g, (m, a, b) => a + b.toUpperCase()) : tt;
      }
      // v3.6 r2: en «1 PROJECT OBJECTIVE & BACKGROUND» el primer párrafo suelto es el overview (regla B4)
      if (posible === "hoy") R._objetivo = /\b(objective|background|overview|summary|purpose)\b/.test(normaTitulo(linea));
      R.titulos.push({ linea: i + 1, seccion: posible });
      sec = posible; itemActual = null; opcionActual = null;
    };
    // A qué sección manda cada papel de pista (una línea con pista de renglón está en el Alcance, aunque el modelo
    // no haya señalado el título). «dato» y «precio» no cambian la sección: se leen donde estén.
    const seccionDePista = p => {
      if (!p) return null;
      if (p.rol === "propia") return ["programa", "pre", "terminos"].includes(p.seccion) ? p.seccion : null;
      if (p.rol === "parrafo") return ({ hoy: "hoy", cambia: "cambia", falta: "falta", notas: "notas", resumen: "hoy", pre_intro: "pre" })[p.destino] || null;
      if (p.rol === "dato" || p.rol === "precio") return null;
      return SEC_DE_ROL[p.rol] || null;
    };

    lineasLeer.forEach((cruda, i) => {
      // un .md del chat puede traer **negritas**, `código`, tablas y rayas: se lee como texto llano
      let linea = cruda.replace(/\*\*|__|`/g, "").trim();
      if (!linea || linea.startsWith("//") || linea.startsWith(">") || linea.startsWith("<!--")) return;
      if (/^[-*_=]{3,}$/.test(linea)) return;                       // ---
      if (/^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$/.test(linea)) return;   // |---|---|
      let esTitulo = /^#{1,6}\s/.test(linea);
      if (/^\|.*\|$/.test(linea) || (linea.split("|").length >= 3)) {   // fila de tabla
        const celdas = linea.replace(/^\||\|$/g, "").split("|").map(c => c.trim()).filter(Boolean);
        if (!celdas.length || esCabeceraTabla(celdas)) return;
        if (celdas.length === 1) linea = celdas[0];
        else if (celdas.length === 2) linea = celdas[0].replace(/:$/, "") + ": " + celdas[1];
        else linea = celdas.join(" | ");
      }
      if (esTitulo) linea = linea.replace(/^#+\s*/, "");

      // la pista de esta línea, si la lectura inteligente está activa
      let pista = pistaDe(i + 1);
      // una «sobrante» solo se calla si la app la confirma con sus propias reglas; si no, se lee como si no tuviera pista
      if (pista && pista.rol === "sobrante") { if (esSobranteConfirmada(cruda)) return; pista = null; }
      if (pista && pista.rol === "continua") return;   // ya se pegó a la línea de arriba
      if (pista && pista.rol === "seccion") {
        if (Object.prototype.hasOwnProperty.call(SECCIONES, String(pista.seccion))) { entrarSeccion(pista.seccion, linea, i); return; }
        // el lector dice «aquí empieza una sección» pero con un nombre que no existe: cuál es, lo deciden las reglas
        const posible = seccionDe(linea);
        if (posible) { entrarSeccion(posible, linea, i); return; }
        pista = null;
      }
      if (!activa) {
        // ¿es un título de sección? ("## 2. Scope of Work", "Hoy", "3) Not included:")
        const posible = seccionDe(linea);
        const pareceTitulo = esTitulo || /^(?:\d+[.)]\s+)?[^.:,]{2,45}:?$/.test(linea);
        if (posible && (pareceTitulo || esTitulo)) { entrarSeccion(posible, linea, i); return; }
      } else if (pista) {
        // el papel de la línea lo pone la pista: si su sección no es la vigente, se entra en ella sin adivinar
        const sp = seccionDePista(pista);
        if (sp && sp !== sec) { sec = sp; itemActual = null; opcionActual = null; }
      }
      if (sec === "ignorar") { pescar(linea, i); return; }
      // v3.7: el membrete son líneas cortas; un párrafo largo con verbo («Max Power Electrical Solutions, Inc. will furnish…») es texto de la hoja
      if (MEMBRETE.test(linea) && (linea.length < 80 || !/\s(will|shall|is|are|includes?|provides?|covers?|furnish(es)?)\s/i.test(linea))) return;   // el membrete del chat
      if (esTitulo && sec !== "alcance" && sec !== "opciones") linea = linea.replace(/^\d+(?:\.\d+)*[.)]?\s+/, "");

      // ¿es "Nombre: valor"?
      const mNV = linea.match(/^([^:]{2,42}):\s*(.*)$/);
      const nombre = mNV ? norma(mNV[1]) : null;
      const valor  = mNV ? mNV[2].trim() : null;
      // datos del membrete que no hacen falta (Prepared By, Proposal #, Date…)
      if (mNV && (sec === "datos" || sec === "ignorar") && CLAVES_IGNORAR.includes(norma(mNV[1].replace(/\s*#\s*$/, "")))) return;

      // --- Con pista «precio» sobre una línea que no es «Precio: valor» (la fila «TOTAL — LUMP SUM | $…» de la
      // tabla de Price): la línea ya pasó el juez (un monto seguro y palabra de precio); el número lo lee la app
      if (pista && pista.rol === "precio" && !(mNV && buscaClave(CLAVES_DINERO, nombre) === "precio")) {
        const d = hayDinero(linea); const m = d ? leerMonto(d.trozo) : null;
        if (m && !m.pregunta) {
          if (!R.precio) R.precio = { centavos: m.centavos, linea: i + 1 };
          else if (R.precio.centavos !== m.centavos) err(i, "Hay dos precios. Solo va uno: el precio base sin opciones.",
                      { arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar este segundo precio", linea: i + 1, auto: false }] });
        }
        return;
      }
      // --- Con pista «dato»: si la línea es «Clave: valor» que la app reconoce, se lee como dato esté donde esté.
      // Si no lo es, la pista solo vale para los datos que NO deciden la matriz legal (email, teléfono, dirección…);
      // cliente, dueño, contratista, contrato con, propiedad, firma y permiso entran ÚNICAMENTE escritos «Clave: valor».
      if (pista && pista.rol === "dato") {
        const k = mNV ? buscaClave(CLAVES_DATOS, nombre) : null;
        if (k) { ponDato(k, valor, i); return; }
        if (Object.prototype.hasOwnProperty.call(CLAVES_DATOS, String(pista.clave)) && !MATRIZ_LEGAL.includes(pista.clave) && !Object.prototype.hasOwnProperty.call(R.datos, pista.clave)) {
          const v = String(pista.cita || linea).trim();
          if (v) { R.datos[pista.clave] = v; R.datos_linea[pista.clave] = i + 1; }
          return;
        }
        // la app no reconoce la línea como dato: se lee con las reglas de la sección vigente
      }

      // --- Con lectura activa, una línea «Clave: valor» SIN pista cuya clave es una condición que la app reconoce
      // (la acaba de escribir la app con un botón, o el lector no la señaló) se lee como condición esté donde esté.
      // Solo líneas sueltas, no viñetas ni renglones numerados («- Access: …» dentro del Alcance sigue siendo detalle).
      if (activa && !pista && mNV && !/^[-*•]|^\d+[.)]/.test(linea)) {
        const kc = buscaClave(CLAVES_COND, nombre);
        if (kc) {
          avisaDinero(i, linea, "Condiciones");
          if (kc === "tipo_trabajo") R.condiciones.tipo_trabajo = { valor: normalizarTipoTrabajo(valor), crudo: valor, linea: i + 1 };
          else R.condiciones[kc] = { valor, linea: i + 1 };
          return;
        }
      }
      // --- Precio y Pagos, estén donde estén (son títulos con valor en la misma línea)
      // con lectura activa, una línea «Total: 12 fixtures» que el lector marcó como exclusión NO es el precio: manda la pista
      if (mNV && buscaClave(CLAVES_DINERO, nombre) === "precio" && !(pista && pista.rol !== "precio")) {
        const m = leerMonto(valor);
        if (!m) err(i, "No entiendo el precio. Escríbelo así: 16,498.24",
                    { arreglos: [{ tipo: "poner_precio_base", etiqueta: "Escribir el precio", pide: "monto" }] });
        else if (m.pregunta) R.preguntas.push({ clave: "precio", linea: i + 1,
          texto: `¿El precio es $${m.opciones[0].toLocaleString("en-US")} o $${m.opciones[1].toFixed(2)}?`,
          opciones: m.opciones.map(v => ({ etiqueta: "$" + v.toLocaleString("en-US", {minimumFractionDigits:2}), valor: centavos(v) })) });
        else if (R.precio && R.precio.centavos === m.centavos) return;   // el total repetido en la tabla
        else if (R.precio) err(i, "Hay dos precios. Solo va uno: el precio base sin opciones.",
                    { arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar este segundo precio", linea: i + 1, auto: false }] });
        else R.precio = { centavos: m.centavos, linea: i + 1 };
        return;
      }
      if (mNV && buscaClave(CLAVES_DINERO, nombre) === "pagos" && !(pista && !/^pago_/.test(pista.rol))) {
        R.pagos = leerPagos(valor, i + 1, err);
        sec = "pagos_detalle";
        return;
      }
      if (sec === "precio_detalle") {
        // dentro de "Price": la línea con total/lump sum/price y un monto es el precio
        const d = hayDinero(linea);
        if (d && !R.precio && /\b(total|lump sum|price|contract|amount|investment|cost)\b/i.test(linea)) {
          const m = leerMonto(d.trozo);
          if (m && !m.pregunta) { R.precio = { centavos: m.centavos, linea: i + 1 }; return; }
        }
        if (d && R.precio && leerMonto(d.trozo) && leerMonto(d.trozo).centavos !== R.precio.centavos)
          R.avisos.push({ linea: i + 1, perdonable: true, texto: `En Price hay otro monto (${d.trozo}) además del precio. Lo dejo fuera del contrato.`,
                                            arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1 }] });
        return;   // el resto de Price ("includes labor, materials…") ya lo dice la plantilla
      }

      switch (sec) {
        case "datos": {
          if (!mNV) { const s = sugerir(SECCIONES, linea);
            if (estaPerdonada(linea)) break;
            R.avisos.push({ linea: i + 1, perdonable: true, texto: s ? `"${linea}" no es un título que conozca. ¿Querías decir "${s}"?`
                                                   : `No sé dónde poner "${linea.slice(0, 60)}". Parece un comentario del chat.`,
                            sugerencia: s,
                            arreglos: s ? [{ tipo: "corregir_titulo", etiqueta: `Cambiar a "${s}"`, linea: i + 1, valor: s, auto: true }]
                                        : [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1, auto: true }] });
            return; }
          const k = buscaClave(CLAVES_DATOS, nombre);
          if (k) ponDato(k, valor, i);
          else { const s = sugerir(CLAVES_DATOS, mNV[1]);
                 if (estaPerdonada(linea)) break;
                 R.avisos.push({ linea: i + 1, perdonable: true, texto: s ? `No conozco "${mNV[1].trim()}". ¿Querías decir "${s}"?`
                                                        : `No conozco el dato "${mNV[1].trim()}".`, sugerencia: s,
                                 arreglos: s ? [{ tipo: "corregir_clave", etiqueta: `Cambiar a "${s}"`, linea: i + 1, valor: s, auto: true }]
                                             // una frase entera, una viñeta o un {{FALTA}} delante de "Cliente:" es
                                             // un comentario del chat: se quita solo. Un dato corto y raro
                                             // ("Telefono: …") se deja y se pregunta.
                                             : [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1,
                                                  auto: /^[-*•]/.test(linea) || /\{\{FALTA/i.test(linea) || mNV[1].trim().split(/\s+/).length > 3 }] }); }
          break;
        }
        case "hoy": case "cambia": case "falta": case "notas": {
          let destino = sec, texto = linea.replace(/^[-*•]\s*/, "").replace(/^\d+\.\d+[.)]?\s+/, "");
          // "This Scope of Work covers X at <dirección>." → es el resumen, no una condición
          const mRes = sec === "hoy" && texto.match(/^this scope of work covers\s+(.+?)(?:\s+at\s+[^.]*\d[^.]*)?\.?$/i);
          const esOverview = sec === "hoy" && !R.datos.overview && !/^[-*•]/.test(linea) &&
            (/^this scope of work covers\b/i.test(texto) ||
             (R._objetivo && !parrafo.hoy.length && texto.length > 60 && !/^(existing|site|basis|information|new layout|proposed|changes|service|parties)\b/i.test(texto)));
          if (esOverview) {
            // v3.7: si el párrafo define «Contractor» como otra empresa choca con el texto legal (ahí Contractor es Max Power):
            // se guarda como referencia (sirve para leer el flood, la fecha del certificado…) y la sección 1 la arma la app
            if (/\(\s*["\u201c]contractor["\u201d]\s*\)/i.test(texto) && !/max power[^()]{0,120}\(\s*["\u201c]contractor["\u201d]\s*\)/i.test(texto)) {
              R.datos.overview_hoja = texto.trim();
              R.avisos.push({ linea: i + 1, informativo: true, texto: "El párrafo de la sección 1 llama «Contractor» a otra empresa; en el contrato «Contractor» es Max Power. La sección 1 la armo yo con lo que sé, y ese párrafo queda de referencia." });
              break;
            }
            // v3.6: el párrafo entero es el «overview» y va al contrato tal cual (no se rearma con los títulos)
            R.datos.overview = texto.trim();
            if (mRes) R.datos.resumen = mRes[1].trim().replace(/\s+at\s+\d{2,}[^]*$/i, "").replace(/[.,]$/, "");
            break;
          }
          // "Existing conditions. …" / "Basis of information. …" / "New layout. …" delante del párrafo
          const mEt = texto.match(/^(existing conditions?|site conditions?|basis of information|information basis|new layout|proposed layout|changes)[.:]\s+(.+)$/i);
          if (mEt) { const e = norma(mEt[1]); destino = /basis|information/.test(e) ? "falta" : /layout|change/.test(e) ? "cambia" : "hoy"; texto = mEt[2]; }
          if (destino === "falta") texto = texto.replace(/^this proposal is prepared from the on-site walkthrough and the direction provided by the client\.\s*/i, "");
          if (destino !== "notas") avisaDinero(i, linea, "esta línea");
          parrafo[destino].push(texto);
          break;
        }

        case "alcance": {
          if (avisaDinero(i, linea, "el Alcance")) return;
          // con pista, el papel de la línea lo pone la pista (renglón, detalle o grupo), no la viñeta ni el largo
          const esDetalle = pista ? pista.rol === "renglon_detalle" : /^[-*•]/.test(linea);
          // "2.3 Shed circuit. Furnish and install…"  ·  "### 2.1 Whole-house rewire"  ·  "1. Título"
          // La numeración de la hoja puede venir de tres maneras y las tres se leen:
          //   plana        1. / 2. / 3.
          //   por sección  2.1 / 2.2 … 3.1 / 3.2   (o 2.3.1)   → el ÚLTIMO número es el del renglón
          //   por grupos   "Kitchen:" y debajo 1., 2., 3.; "Pool:" y otra vez 1., 2.
          // El número del renglón en el contrato lo pone el orden en que están; lo escrito solo
          // sirve para leer bien. Un encabezado corto seguido de renglones numerados es un grupo.
          const siguienteLinea = () => { for (let k = i + 1; k < lineasLeer.length; k++) { const t = lineasLeer[k].replace(/\*\*|__|`/g, "").trim(); if (t) return t; } return ""; };
          const mJer = linea.match(/^(\d+(?:\.\d+)+)[.)]?\s+(.+)$/);           // 2.3 · 2.3.1
          const mCrudo = linea.match(/^(\d+)[.)]?\s+(.+)$/);                     // 3 Pool · 3. Pool
          let mSub = mJer ? [linea, mJer[1].split(".").pop(), mJer[2]] : mCrudo;
          const conPunto = /^\d+(?:\.\d+)*[.)]\s/.test(linea) || !!mJer;
          // "3 GFCI receptacles at the island" es una cantidad, no el número del renglón. Un número
          // SIN punto ni paréntesis detrás solo cuenta como numeración si la lista va así desde el
          // primer renglón (1 Kitchen / 2 Island…); si los demás llevan punto, se queda como texto.
          if (mSub && !mJer && !conPunto && !(R.items.length === 0 ? Number(mSub[1]) === 1 : R._sinPunto === true)) mSub = null;
          if (mSub && !esDetalle) R._sinPunto = !conPunto;
          // con pista «grupo»: es un encabezado («3 Pool», «Kitchen:»), no un renglón
          if (pista && pista.rol === "grupo") { R._grupo = linea.replace(/^\d+(?:\.\d+)*[.)]?\s+/, "").replace(/:$/, "").trim(); R._sinPunto = undefined; return; }
          // Encabezado de grupo: "3 Pool" / "3. Pool" / "Pool:" / "POOL" corto y sin descripción,
          // con un renglón numerado debajo. No es un renglón del contrato: se recuerda como grupo.
          if (!esDetalle && !pista) {
            const sig = siguienteLinea();
            const sigNumerado = /^\d+(?:\.\d+)*[.)]?\s+\S/.test(sig);
            const corto = linea.replace(/^\d+(?:\.\d+)*[.)]?\s+/, "").replace(/:$/, "").trim();
            const pareceGrupo = corto.length <= 40 && !/[.;]\s|\s(and|with|per|for|at)\s/i.test(corto) &&
              (/:$/.test(linea) || (corto === corto.toUpperCase() && /[A-Z]{3}/.test(corto)) || (mCrudo && !mJer && sigNumerado && /^\d+\.\d+/.test(sig)));
            if (pareceGrupo && sigNumerado && !mJer) { R._grupo = corto; R._sinPunto = undefined; return; }
          }
          // la serie: para validar que dentro de cada sección/grupo la numeración va seguida
          const serie = mJer ? mJer[1].split(".").slice(0, -1).join(".") : (R._grupo || null);
          const mn = !esDetalle && (mSub || null);
          const nuevoRenglon = (titulo, resto, escrito) => {
            // el lector dice que este renglón es el cierre (pruebas, etiquetado, limpieza) que la plantilla ya trae:
            // se deja como renglón y sale en ámbar con botón; sin toque, se queda (nada desaparece en silencio)
            if (pista && pista.rol === "renglon_titulo" && pista.cierre && !/^testing\s*(and|&)\s*close\s*-?out|^closeout|^testing and commissioning/i.test(titulo)) {
              R.avisos.push({ linea: i + 1, perdonable: true, origen: "ia", texto: `El lector dice que «${titulo.slice(0, 40)}» es el cierre del trabajo (pruebas y entrega), que la plantilla ya trae como último punto. Lo dejo como renglón; si sobra, quítalo.`,
                arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitarlo, ya lo trae la plantilla", linea: i + 1, auto: false, origen: "ia" },
                           { tipo: "dejar_asi", etiqueta: "Es un renglón, déjalo", linea: i + 1, auto: false, origen: "ia" }] });
            }
            // "Testing and closeout" ya lo trae la plantilla como último punto: no se duplica
            else if (/^testing\s*(and|&)\s*close\s*-?out|^closeout|^testing and commissioning/i.test(titulo)) {
              R.avisos.push({ linea: i + 1, informativo: true, texto: `«${titulo.slice(0, 40)}» ya lo trae la plantilla como último punto del alcance; no lo repito.` });
              itemActual = { fantasma: true, detalles: [], lineas: [] }; return;
            }
            itemActual = { n: R.items.length + 1, escrito, grupo: R._grupo || null, serie, titulo: titulo.replace(/[.:]$/, "").trim(), detalles: [], lineas: [i + 1] };
            if (resto) itemActual.detalles.push(resto);
            R.items.push(itemActual);
          };
          if (esDetalle) {
            // con pista, el detalle va al renglón cuyo título está en la línea «de» (el orden de la lectura puede no
            // coincidir con el del lector si el juez tiró un renglón); sin pista, al de arriba
            let it = itemActual;
            if (pista && pista.de && !(itemActual && itemActual.lineas && itemActual.lineas[0] === pista.de)) it = R.items.find(x => x.lineas[0] === pista.de) || itemActual;
            if (!it) { err(i, "Este detalle no tiene renglón encima. Ponle un título al renglón.",
                { arreglos: [{ tipo: "hacer_titulo", etiqueta: "Convertirlo en renglón", linea: i + 1, auto: true },
                             { tipo: "quitar_linea", etiqueta: "Quitar la línea", linea: i + 1 }] }); return; }
            if (it.fantasma) return;
            it.detalles.push(linea.replace(/^[-*•]\s*/, "")); it.lineas.push(i + 1);
          } else if (pista && pista.rol === "renglon_titulo") {
            // el título sale de la cita del lector (comprobada por el juez) y el resto es la línea menos el título;
            // sin cita, el corte de siempre («Título. Descripción…»). El número escrito lo saca la app con su regla.
            const entera = linea.replace(/^[-*•]\s*/, "").trim();
            const cl = limpiarLinea(pista.cita_titulo || "").limpia;
            // si la cita empieza por la cantidad («1 GFCI receptacle at the island»), ese «1» es cantidad, no numeración
            const conCantidad = !!(mn && cl && limpiarLinea(entera).limpia.startsWith(cl) && !limpiarLinea(mn[2].trim()).limpia.startsWith(cl));
            const texto = mn && !conCantidad ? mn[2].trim() : entera;
            const lim = limpiarLinea(texto);
            const pos = cl ? lim.limpia.indexOf(cl) : -1;
            let titulo, resto;
            if (pos >= 0 && cl.length >= 3) {
              const a = lim.mapa[pos], b = lim.mapa[pos + cl.length - 1] + 1;
              titulo = texto.slice(a, b);
              resto = (texto.slice(0, a) + " " + texto.slice(b)).replace(/^[\s.:;—–-]+/, "").replace(/\s{2,}/g, " ").trim();
            } else {
              const corte = (mn || esTitulo) ? texto.match(/^(.{3,70}?)(?:\.\s+|\s+[—–]\s+|:\s+)(.{15,})$/) : null;
              titulo = corte ? corte[1] : texto; resto = corte ? corte[2].trim() : "";
            }
            nuevoRenglon(titulo, resto, mn && !conCantidad ? Number(mn[1]) : null);
          } else if (mn || esTitulo) {
            const texto = mn ? mn[2].trim() : linea.trim();
            // título corto y descripción en la misma línea: "Shed circuit. Furnish and install…"
            const corte = texto.match(/^(.{3,70}?)(?:\.\s+|\s+[—–]\s+|:\s+)(.{15,})$/);
            const titulo = corte ? corte[1] : texto, resto = corte ? corte[2].trim() : "";
            nuevoRenglon(titulo, resto, mn ? Number(mn[1]) : null);
          } else if (itemActual && !itemActual.fantasma && linea.length > 60) {
            // un párrafo debajo del título: es la descripción del renglón
            itemActual.detalles.push(linea); itemActual.lineas.push(i + 1);
          } else if (itemActual && itemActual.fantasma) {
            return;
          } else if (!itemActual && linea.length > 80) {
            // un párrafo suelto antes del primer renglón: es texto de la plantilla ("All materials… furnished by Max Power")
            if (!/furnished by max power|unless expressly noted|furnished by others|furnished by the owner/i.test(linea) && !estaPerdonada(linea))
              R.avisos.push({ linea: i + 1, perdonable: true, texto: `Esto está en el Alcance pero no es un renglón: «${linea.slice(0, 60)}…». Lo dejo fuera.`,
                              arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1 }] });
            return;
          } else {
            nuevoRenglon(linea, "", null);
          }
          break;
        }
        case "no_incluye": {
          if (avisaDinero(i, linea, "No incluye")) return;
          const tx = linea.replace(/^[-*•]\s*/, "").replace(/^\d+(?:\.\d+)*[.)]?\s+/, "");
          // Las exclusiones que la plantilla ya trae (permiso, fixtures, drywall, low-voltage, aparatos,
          // fuera de áreas, correcciones del inspector) no se repiten; de algunas se pesca un dato.
          const mFuera = tx.match(/^any work outside\s+(.+?)\s+expressly described in section 2(?:\s*[—–-]+\s*including\s+(.+?)\s*[—–-]+)?/i);
          if (mFuera) {
            if (!C_set("areas", mFuera[1], i)) {} if (mFuera[2]) C_set("no_tocamos", mFuera[2], i);
            R.fijasQuitadas = (R.fijasQuitadas || 0) + 1; return;
          }
          const mFix = tx.match(/^decorative light fixtures?[.:]\s+(.+?)\s+(?:are|is) furnished by the owner/i);
          if (mFix) { C_set("fixtures_cliente", mFix[1].charAt(0).toUpperCase() + mFix[1].slice(1), i); R.fijasQuitadas = (R.fijasQuitadas || 0) + 1; return; }
          // v3.4: low-voltage y correcciones del inspector NO se quitan: si la hoja trae su versión
          // (más específica: telemetría, flotadores…), manda la de la hoja y la genérica se apaga sola.
          const fija = tx.match(/^(permit(?:s|ting)?\b[^.:]{0,80}[.:]|permit application|electrical panel work|arc-fault|cabinet and under-cabinet|drywall, ceiling patching|appliances, gas piping)/i);
          if (fija) {
            R.fijasQuitadas = (R.fijasQuitadas || 0) + 1;
            R.fijasVistas = R.fijasVistas || new Set(); R.fijasVistas.add(norma(fija[1]).split(/[ ,.:]/)[0]);
            return;
          }
          const mNeg = cruda.match(/^\s*[-*•]?\s*\*\*(.+?)\*\*[.:]?\s*(.*)$/);
          R.no_incluye.push({ texto: tx, linea: i + 1, titulo: mNeg ? mNeg[1].replace(/[.:]$/, "").trim() : null, cuerpo: mNeg ? mNeg[2].trim() : null });
          break;
        }
        case "opciones": {
          const esDetalle = /^[-*•]/.test(linea);
          if (esDetalle) {
            if (opcionActual) opcionActual.detalles.push(linea.replace(/^[-*•]\s*/, ""));
            else err(i, "Este detalle no tiene opción encima.",
                { arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar la línea", linea: i + 1, auto: true }] });
            break;
          }
          const mn = linea.match(/^(?:(\d+)[.)\-]\s*)?(.+)$/);
          let resto = mn[2].trim();
          // el precio va al final, tras ":" o "—" o "-"
          const mp = resto.match(/^(.*?)[\s]*[—–:-][\s]*(\$?\s*[\d.,]+)\s*$/);
          let precio = null, titulo = resto;
          if (mp) { titulo = mp[1].trim(); precio = leerMonto(mp[2]); }
          if (!precio) {
            err(i, `La opción "${titulo.slice(0, 40)}" no tiene precio. Los añadidos van con monto, o no van.`,
                { arreglos: [{ tipo: "poner_precio", etiqueta: "Ponerle precio", linea: i + 1, pide: "monto" },
                             { tipo: "quitar_linea", etiqueta: "Quitar esta opción", linea: i + 1, conDetalles: true }] });
            // sus detalles se quedan pegados a ella (no se sueltan ni se borran)
            opcionActual = { n: R.opciones.length + 1, titulo, centavos: 0, sinPrecio: true, detalles: [], linea: i + 1 };
            break;
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
          // líneas sueltas debajo de "Pagos:" — una por pago, con el % donde esté:
          // "40% al firmar" · "1 | Deposit upon acceptance | 40% | $6,599.30" · "Milestone 1 (40%): Deposit…"
          const sinVineta = linea.replace(/^[-*•]\s*/, "");
          const esHito = /^(?:milestone|pago|payment|hito|\d)/i.test(sinVineta) || /\$\s?\d/.test(sinVineta);
          const mpct = esHito ? sinVineta.match(/(?<![\d.])(\d{1,3})\s*%/) : null;
          if (mpct && R.pagos && R.pagos.corto) break;   // "Pagos: 50/50" ya lo dijo; esto es explicación
          // Un párrafo con título en negrita debajo de la tabla ("**Basis of the deposit.** …") es una
          // condición de pago propia de este trabajo: va al contrato. Las que la plantilla ya trae, no.
          const mNegP = !mpct && cruda.match(/^\s*\*\*(.+?)\*\*[.:]?\s*(.{20,})$/);
          if (mNegP) {
            if (!/inspection delay|late payment|invoices are due|basis of information/i.test(mNegP[1]) && !hayDinero(mNegP[2]))
              R.pagos_propios.push({ titulo: mNegP[1].replace(/[.:]$/, "").trim(), texto: mNegP[2].trim(), linea: i + 1 });
            break;
          }
          // con pista «pago_propia» sin negritas: el título es la cita del lector y el texto, el resto de la línea
          if (pista && pista.rol === "pago_propia" && !mpct) {
            const cl = String(pista.cita_titulo || "").trim(), pos = cl ? sinVineta.indexOf(cl) : -1;
            const titulo = pos >= 0 ? cl : sinVineta.split(/[.:]\s+/)[0];
            const cuerpo = pos >= 0 ? sinVineta.slice(pos + cl.length) : sinVineta.slice(titulo.length);
            const txt = cuerpo.replace(/^[\s.:—–-]+/, "").trim();
            if (titulo && txt && !hayDinero(txt)) R.pagos_propios.push({ titulo: titulo.replace(/[.:]$/, "").trim(), texto: txt, linea: i + 1 });
            break;
          }
          if (pista && pista.rol === "pago_nota") break;   // retención, recargo…: no es un hito y la plantilla ya lo trae
          if (!mpct && /^(invoices are due|invoicing and payment|late payment)/i.test(sinVineta)) break;   // la plantilla ya lo trae
          if (mpct) {
            R.pagos = R.pagos || { pcts: [], disparadores: [], lineas: [] };
            R.pagos.pcts.push(Number(mpct[1]));
            const disp = sinVineta.replace(/\$\s?\d[\d,]*(?:\.\d{2})?/g, "").replace(/\(?\d{1,3}\s*%\)?/, "")
              .replace(/^(?:milestone|pago|payment|hito)?\s*\d+\s*[.):|—–-]?\s*/i, "").replace(/\s*\|\s*/g, " ").replace(/[—–:|-]\s*$/, "").replace(/^\s*[—–:|-]\s*/, "").replace(/\s{2,}/g, " ").trim();
            R.pagos.disparadores.push(disp || null);
            R.pagos.lineas.push(i + 1);
            break;
          }
          // Una línea sin porcentaje ni dinero debajo de Pagos («6.2 Retainage. None.»): las reglas entienden que se
          // acabaron los pagos y lo que sigue son Condiciones sin título. Se sale con break (H13: antes caía al caso de
          // abajo, donde R.condiciones no es una lista, y el lector reventaba). Con lectura activa la sección no salta
          // sola: solo cambia por pista.
          if (!activa && !hayDinero(sinVineta) && !/\bpayment|\binvoice|\bdue\b/i.test(sinVineta)) { sec = "condiciones"; break; }
          break;
        }
        case "programa": case "pre": case "terminos": {
          // "7.2 Equipment lead time. The equipment…" → { n: "7.2", titulo, texto }
          pescar(linea, i);
          const dest = R[sec];
          const mp = linea.match(/^(\d+(?:\.\d+)?)[.)]?\s+(.+)$/);
          let mt;
          const esBullet = /^[-*•]/.test(linea), ultimo = dest[dest.length - 1];
          // una viñeta debajo de una cláusula numerada («7.4 Mobilizations.» y debajo «- (1) underground…») sigue a esa cláusula
          const sigueAlNumerado = esBullet && !!ultimo && !!ultimo.n && !ultimo.sinTitulo;
          const esFirma = /_{4,}|\bdate:\s*_/i.test(linea);
          if (mp && (/\./.test(mp[1]) || esTitulo)) {
            const cuerpo = mp[2].trim();
            const corte = cuerpo.match(/^(.{3,90}?)(?:\.\s+|:\s+)(.+)$/);
            dest.push({ n: mp[1], titulo: (corte ? corte[1] : cuerpo).replace(/[.:]$/, "").trim(),
                        texto: corte ? corte[2].trim() : "", linea: i + 1 });
          } else if (!sigueAlNumerado && !esFirma && (sec !== "pre" || dest.length)
                     && (mt = linea.replace(/^[-*•]\s*/, "").match(/^(?!(?:this|the|all|no|any|a|an|if|should|it|max power|contractor|client|owner|pricing|work)\b)([A-Z][^.:]{2,40}?)[.:]\s+(.{20,})$/i))) {
            // "Sequence: demo → underground → …" sin número (con o sin viñeta): es un párrafo propio, no se bota
            dest.push({ n: "", titulo: mt[1].trim(), texto: mt[2].trim(), linea: i + 1 });
          } else if (esBullet && !sigueAlNumerado && !esFirma && sec !== "pre") {
            // v3.7: un punto suelto sin título en la 7 o la 9 es una condición propia de este trabajo. El título sale del
            // texto (regla B1: lo que hay antes de « — » o de «(», o la primera frase; nunca cortado por conteo de palabras).
            // Lo que la plantilla ya trae (movilizaciones, flood, garantía…) lo quita clasificarPropias.
            const cuerpo = linea.replace(/^[-*•]\s*/, "").trim();
            const mRaya = cuerpo.match(/^(.{3,60}?)\s+[—–]\s+(.+)$/);
            const mPar = cuerpo.match(/^([A-Z][^.(:]{2,40}?)\s+\((.+)$/);
            const mFrase = cuerpo.match(/^(.{3,}?[^.\d])\.\s+(.+)$/);
            const t = mRaya ? { titulo: mRaya[1], texto: mRaya[2] } : mPar ? { titulo: mPar[1], texto: cuerpo }
                    : mFrase ? { titulo: mFrase[1], texto: mFrase[2] } : { titulo: cuerpo.replace(/\.$/, ""), texto: "" };
            dest.push({ n: "", titulo: t.titulo.trim(), texto: t.texto.trim(), linea: i + 1, sinTitulo: true });
          } else if (pista && pista.rol === "propia" && pista.cita_titulo && !esFirma && linea.replace(/^[-*•]\s*/, "").includes(String(pista.cita_titulo).trim())) {
            // con pista «propia» y cita de título en una línea que las reglas habrían pegado a la cláusula de arriba:
            // es una cláusula propia; el título es la cita y el texto, el resto de la línea
            const cuerpo = linea.replace(/^[-*•]\s*/, "").trim(), cl = String(pista.cita_titulo).trim(), pos = cuerpo.indexOf(cl);
            const mNum = cuerpo.match(/^(\d+(?:\.\d+)?)[.)]?\s+/);
            dest.push({ n: mNum ? mNum[1] : "", titulo: cl.replace(/[.:]$/, "").trim(),
                        texto: (cuerpo.slice(0, pos).replace(/^(\d+(?:\.\d+)?)[.)]?\s+/, "") + " " + cuerpo.slice(pos + cl.length)).replace(/^[\s.:—–-]+/, "").replace(/\s{2,}/g, " ").trim(),
                        linea: i + 1, sinTitulo: !mNum });
          } else if (dest.length) {
            dest[dest.length - 1].texto = (dest[dest.length - 1].texto + " " + linea.replace(/^[-*•]\s*/, "")).trim();
          } else if (sec === "pre") {
            R.pre_intro = (R.pre_intro + " " + linea).trim();
          }
          break;
        }
        case "condiciones": {
          if (!mNV) { R.avisos.push({ linea: i + 1, texto: `No sé dónde poner "${linea.slice(0,45)}" dentro de Condiciones.`,
                                       arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1 }] }); break; }
          // el dinero tampoco va en Condiciones (perdonable, como en el resto de la hoja); la condición se lee igual
          avisaDinero(i, linea, "Condiciones");
          const k = buscaClave(CLAVES_COND, nombre);
          if (k === "tipo_trabajo") {
            // «Tipo de trabajo: exterior» escrito a mano manda sobre las listas de palabras de decidirInterruptores
            R.condiciones.tipo_trabajo = { valor: normalizarTipoTrabajo(valor), crudo: valor, linea: i + 1 };
          }
          else if (k) R.condiciones[k] = { valor, linea: i + 1 };
          else { const s = sugerir(CLAVES_COND, mNV[1]);
                 R.avisos.push({ linea: i + 1, texto: s ? `No conozco "${mNV[1].trim()}". ¿Querías decir "${s}"?`
                                                        : `No conozco la condición "${mNV[1].trim()}".`, sugerencia: s,
                                 arreglos: s ? [{ tipo: "corregir_clave", etiqueta: `Cambiar a "${s}"`, linea: i + 1, valor: s, auto: true }]
                                             : [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1 }] }); }
          break;
        }
        case "codigo": {
          // La sección Código puede venir de tres maneras y las tres se leen sin frenar:
          //   una lista        210.8, 210.12, 406.4(D)
          //   con su código    "NEC 210.8(A)(3), 210.52(C)" · "Articles 110 (…), 210 and 250" · "NFPA 70 Article 100"
          //   agrupada por tema  "General and distribution" / "Floodplain" (título corto) y debajo los artículos
          // Otros códigos (Florida Building Code, Statutes, ASCE, IRC…) son prosa: se guardan aparte y la
          // plantilla ya trae la frase general. Nada de esto es un error rojo: como mucho, un aviso perdonable.
          const ART = "\\d{3}(?:\\.\\d+)?(?:\\([A-Za-z0-9]+\\))*";
          // el grupo en el que estamos (título corto de arriba); sin título, un grupo sin nombre
          const grupoActual = () => { if (!R._codGrupo) { R._codGrupo = { grupo: "", articulos: [], otros: [] }; R.codigo_detalle.push(R._codGrupo); } return R._codGrupo; };
          const agregar = a => { if (!a) return; if (!R.codigo.includes(a)) R.codigo.push(a); const g = grupoActual(); if (!g.articulos.includes(a)) g.articulos.push(a); };
          const articulosDe = txt => (txt.match(/\d+(?:\.\d+)?(?:\([A-Za-z0-9]+\))*/g) || [])
            .filter(t => /^\d{3}(?:\D|$)/.test(t));               // tres cifras enteras: 210, 250.24(C); no 2023 ni 70
          const rxArt = new RegExp("articles?\\s+((?:" + ART + "(?:\\s*\\([^)]*\\))?(?:\\s*,\\s*|\\s+and\\s+|\\s*&\\s*)?)+)", "gi");
          let mArt, hayArt = false;
          while ((mArt = rxArt.exec(linea))) { hayArt = true; (mArt[1].match(new RegExp(ART, "g")) || []).forEach(agregar); }
          // "NEC 210.8(A)(3), 210.52(C)(1) and 406.4(D)" — con el nombre del código delante
          if (/\b(nec|nfpa\s*70)\b/i.test(linea)) {
            const arts = articulosDe(linea.replace(/\b(nfpa\s*70|20\d\d)\b/gi, " "));
            if (!arts.length && /all work|in accordance with|as adopted|performed under/i.test(linea)) break;   // la frase general: la plantilla ya la trae
            const esNota = linea.replace(/^[-*•]\s*/, "").length > 90 || /\bnote\b|assum|limits|requires|this proposal/i.test(linea);
            if (esNota) { const otro = linea.replace(/^[-*•]\s*/, ""); R.codigo_otros.push(otro); grupoActual().otros.push(otro); arts.forEach(a => { if (!R.codigo.includes(a)) R.codigo.push(a); }); break; }
            if (arts.length) { hayArt = true; arts.forEach(agregar); } else break;
          }
          if (hayArt) break;
          // otros códigos y la prosa general: se guardan aparte, no son artículos del NEC
          if (/\b(florida building code|fbc|building code|statutes?|chapter|asce|irc|iecc|osha|ieee|ul\s*\d|edition|as adopted|jurisdiction|ahj)\b/i.test(linea) || /\bnfpa\s*(?!70\b)\d+/i.test(linea)) {
            const otro = linea.replace(/^[-*•]\s*/, ""); R.codigo_otros.push(otro); grupoActual().otros.push(otro); break;
          }
          // una lista suelta: 210.8, 210.12, art 250, 406.4(D)
          const trozos = linea.replace(/^[-*•]\s*/, "").split(/[,;]/).map(t => t.trim()).filter(Boolean);
          const sueltos = trozos.map(v => v.match(/^(?:art(?:[ií]culo|icle|\.)?\s*)?(\d{3}(?:\.\d+)?(?:\([A-Za-z0-9]+\))*)\s*(?:\(.*\))?$/i));
          if (sueltos.some(Boolean)) {
            sueltos.forEach((m, k) => { if (m) agregar(m[1]);
              else if (!estaPerdonada(trozos[k])) R.avisos.push({ linea: i + 1, perdonable: true, texto: `En Código no entendí «${trozos[k].slice(0, 45)}» como artículo; lo dejo fuera.`,
                                       arreglos: [{ tipo: "quitar_trozo", etiqueta: `Quitar "${trozos[k].slice(0, 30)}"`, linea: i + 1, valor: trozos[k] }] }); });
            break;
          }
          // un título corto sin números agrupa los artículos de abajo ("General and distribution", "Floodplain")
          const limpio = linea.replace(/^[-*•]\s*/, "").replace(/^#+\s*/, "").replace(/[:.]$/, "").trim();
          if (!/\d/.test(limpio)) {
            if (limpio.length <= 60) { R.codigo_grupos.push(limpio); R._codGrupo = { grupo: limpio, articulos: [], otros: [] }; R.codigo_detalle.push(R._codGrupo); }
            else { R.codigo_otros.push(limpio); grupoActual().otros.push(limpio); }
            break;
          }
          if (limpio.length > 60) { R.codigo_otros.push(limpio); grupoActual().otros.push(limpio); break; }   // una nota larga: es prosa del código, va tal cual
          if (!estaPerdonada(linea)) R.avisos.push({ linea: i + 1, perdonable: true, texto: `En Código no entendí «${limpio.slice(0, 45)}» como artículo; lo dejo fuera.`,
                                                    arreglos: [{ tipo: "quitar_linea", etiqueta: "Quitar esta línea", linea: i + 1 }] });
          break;
        }
      }
    });

    R.ignoradas = ignoradas;
    // El chat entregó el §3 entero (se vieron ≥3 exclusiones fijas): las fijas que NO puso
    // (panel, AFCI, gabinetes) es porque el trabajo las incluye → se apagan solas.
    if (R.fijasVistas && R.fijasVistas.size >= 3 && !R.condiciones.no_excluir) {
      const faltan = [];
      if (!R.fijasVistas.has("electrical")) faltan.push("panel");
      if (!R.fijasVistas.has("arc")) faltan.push("afci");
      if (!R.fijasVistas.has("cabinet")) faltan.push("gabinetes");
      if (faltan.length) R.condiciones.no_excluir = { valor: faltan.join(", "), linea: 0, pescada: true };
    }
    if (R.fijasQuitadas)
      R.avisos.push({ linea: 0, informativo: true, texto: `En No incluye venían ${R.fijasQuitadas} exclusiones que la plantilla ya trae (permiso, fixtures, drywall…); las quité para no repetirlas.` });
    if (ignoradas.length)
      R.avisos.push({ linea: 0, informativo: true, texto: `Del archivo solo se usan las secciones 1 a 6. Me salté ${ignoradas.map(x => "«" + x.titulo + "»").join(", ")}: eso lo pone la plantilla del contrato con su texto legal.` });
    R.hoy = parrafo.hoy.join(" ");
    R.cambia = parrafo.cambia.join(" ");
    R.falta = parrafo.falta.join(" ");
    R.notas = parrafo.notas.join("\n");
    R.items.forEach((it, k) => { it.n = k + 1; });
    // v3.7: el disparador del hito 2. Si es el genérico «upon completion of rough-in» y el trabajo tiene fase bajo tierra /
    // bonding antes, la app lo pone sola (los montos no cambian) y lo dice; si Edgar escribió otra cosa, solo se le propone.
    if (R.pagos && (R.pagos.disparadores || []).length >= 2) {
      const d1 = norma(R.pagos.disparadores[1] || "");
      const generico = /^(upon |on |at )?(the )?(completion of )?rough-?in( complete(d)?)?( and rough(-in)? inspection passed)?$/.test(d1);
      const txtA = norma(R.items.map(it => it.titulo + " " + (it.detalles || []).join(" ")).join(" "));
      const fases = partirFases(((R.condiciones || {}).fases || {}).valor || "");
      const temprana = fases.some(f => /underground|bonding|trench|slab/i.test(f)) || /\b(underground|bonding grid|equipotential|trench)\b/.test(txtA);
      if (generico && temprana) {
        const f0 = (fases[0] && /underground|bonding|trench|slab/i.test(fases[0]) ? fases[0]
                   : (/\b(pool|equipotential|spa)\b/.test(txtA) ? "underground raceways and pool equipotential bonding" : "underground raceways and bonding")).replace(/\s+and\s+/g, ", ");
        const propuesto = `upon completion of ${f0} and rough-in`;
        const lineaH2 = (R.pagos.lineas || [])[1];
        R.pagos.auto2 = { antes: R.pagos.disparadores[1], despues: propuesto };
        R.pagos.disparadores[1] = propuesto;
        R.avisos.push({ linea: lineaH2 || 0, informativo: true,
          texto: `Hito 2: esto no es un rough-in de interior (hay trabajo bajo tierra / bonding antes), así que lo puse «${propuesto}». Los montos no cambian. Si lo quieres de otra manera, escríbelo en Pagos y así se queda.`,
          arreglos: lineaH2 ? [{ tipo: "cambiar_disparador", etiqueta: "Dejarlo escrito así en la hoja", linea: lineaH2, valor: propuesto, automatico: true }] : [] });
      }
    }
    // v3.6: el flood se lee de toda la hoja (menos las Notas, que son de Edgar)
    R.flood = extraerFlood([R.hoy, R.cambia, R.falta, ...(R.codigo_otros || []), ...(R.terminos || []).map(t => t.titulo + ". " + t.texto),
      ...R.items.map(it => it.titulo + " " + (it.detalles || []).join(" ")),
      ...(R.programa || []).map(t => t.titulo + ". " + t.texto), ...(R.pre || []).map(t => t.titulo + ". " + t.texto),
      ...(R.no_incluye || []).map(x => x.texto), Object.values(R.datos).filter(v => typeof v === "string").join(" ")].join(" "));
    // v3.7: lo que la hoja trae en 7 / 9 y la plantilla ya pone (movilizaciones, flood, garantía, validez…) se quita sin ruido, una vez
    {
      const q = clasificarPropias(R).quitadas || [];
      if (q.length) R.avisos.push({ linea: 0, informativo: true,
        texto: `De las secciones 7 y 9 de la hoja quité ${q.length} ${q.length === 1 ? "punto que la plantilla ya trae" : "puntos que la plantilla ya trae"} (${q.map(x => "«" + x.slice(0, 40) + "»").join(", ")}); lo demás va al contrato tal cual.` });
    }
    // La numeración escrita no manda: el orden de los renglones es el que vale. Si va seguida
    // (plana, o 1, 2, 3 dentro de cada grupo/sección) no se dice nada; si no, se avisa sin frenar.
    const conNum = R.items.filter(i => i.escrito !== null);
    if (conNum.length) {
      let esperado = 1, serieAnt = conNum[0].serie, ok = true;
      conNum.forEach(it => { if (it.serie !== serieAnt) { serieAnt = it.serie; esperado = 1; } if (it.escrito !== esperado) ok = false; esperado = it.escrito + 1; });
      if (!ok) R.avisos.push({ informativo: true,
        texto: `Los renglones del Alcance venían numerados ${conNum.map(i => i.escrito).join(", ")}; los tomo en el orden en que están (1 a ${R.items.length}) y el contrato los numera solo. Tu hoja no cambia.`,
        arreglos: [{ tipo: "renumerar", etiqueta: "Numerarlos seguidos en la hoja", auto: false }] });
    }
    return R;
  }

  // "(1) demolition, equipment set and rough-in; and (2) startup, testing" → ["demolition, …", "startup, …"]
  function partirFases(txt) {
    const t = String(txt || "").trim().replace(/\.$/, "");
    if (!t) return [];
    if (/\(\d+\)/.test(t)) return t.split(/\s*;?\s*(?:and\s+)?\(\d+\)\s*/).map(x => x.trim().replace(/[;,]$/, "")).filter(Boolean);
    if (t.includes(";")) return t.split(/\s*;\s*(?:and\s+)?/).map(x => x.trim()).filter(Boolean);
    if (t.includes(" / ")) return t.split(" / ").map(x => x.trim()).filter(Boolean);
    return t.split(/,\s*(?:and\s+)?|\s+and\s+/).map(x => x.trim()).filter(Boolean);
  }

  // ---------------------------------------------------------------- v3.4: lo propio de la hoja
  // De las cláusulas (9.x) y el cronograma (7.x) que trae la hoja, cuáles ya las pone la
  // plantilla (se quitan, manda la versión revisada por el abogado) y cuáles son de ESTE
  // trabajo (van al contrato tal cual, renumeradas).
  const PLANTILLA_9 = [
    [/workmanship|warrant/i, "garantia"], [/existing and concealed|concealed condition/i, "existentes"],
    [/code upgrades?|ahj requirement/i, "ahj_upgrades"],
    [/existing circuits|site condition/i, "sitio"], [/code edition/i, "edicion"],
    [/change orders?|entire agreement/i, "cambios"], [/limitation of liability/i, "limite"],
    [/insurance/i, "seguro"], [/deposit|start of work/i, "deposito"], [/cancellation/i, "cancelacion"],
    [/retainage/i, "retainage"], [/notice to owner|releases? of lien|lien rights?/i, "nto_releases"],
    [/arc.?fault|afci/i, "afci"], [/openings|patching/i, "aberturas"],
    // v3.7: lo que la plantilla trae fuera de la 9 (la 7.x Flood, la fecha de validez, la licencia del membrete)
    [/\bflood\b|base flood elevation|\bbfe\b/i, "flood"], [/proposal is valid|valid for \d+ days|valid through/i, "validez"],
    [/florida license|license ec\d+/i, "validez"]
  ];
  const PLANTILLA_7 = [
    [/^permit\b/i, "7.1"], [/layout approval|verification before|pre-construction/i, "7.2"],
    [/site condition|pricing assumes/i, "7.3"], [/mobilization/i, "7.4"],
    [/material handling|materials? (that must be|furnished by others)[^.]{0,80}(handl|salvag|stor|reinstall)/i, "7.5"], [/utility coordination/i, "7.6"],
    [/\bflood\b|base flood elevation|\bbfe\b/i, "flood"]
  ];
  function clasificarPropias(L) {
    const propias = [], programa = [], pre = (L.pre || []).slice(), mapa = {}, quitadas = [];
    // un punto sin título propio se reconoce por su primera frase; uno con título, por el título
    const cara = t => t.titulo + (t.sinTitulo ? " " + String(t.texto || "").slice(0, 160) : "");
    const busca = (lista, t) => lista.find(([re]) => re.test(cara(t)));
    (L.terminos || []).forEach(t => {
      // en la 9 solo se compara con la 9 («Permit type and sealed plans» no es la 7.1 Permit)
      const f9 = busca(PLANTILLA_9, t);
      if (f9) { mapa[t.n] = { clave: f9[1] }; quitadas.push(t.titulo); }
      else { mapa[t.n] = { propia: propias.length }; propias.push(t); }
    });
    (L.programa || []).forEach(t => {
      const f7 = busca(PLANTILLA_7, t), f9 = f7 ? null : busca(PLANTILLA_9, t);
      if (f7) { mapa[t.n] = { fija7: f7[1] }; quitadas.push(t.titulo); }
      else if (f9) { mapa[t.n] = { clave: f9[1] }; quitadas.push(t.titulo); }
      else { mapa[t.n] = { extra7: programa.length }; programa.push(t); }
    });
    return { propias, programa, pre, mapa, quitadas };
  }
  // Cambia "See Sections 8 and 9.3" por los números que tienen en el contrato armado; lo
  // que no existe en el contrato se quita con su frase entera, no se deja colgando.
  function renumerarRefs(texto, traducir) {
    let t = String(texto || "");
    const NUMS = "(\\d+(?:\\.\\d+)?(?:\\s*(?:,|and|&)\\s*\\d+(?:\\.\\d+)?)*)";
    const resolver = (grupo) => {
      const nums = grupo.match(/\d+(?:\.\d+)?/g) || [];
      const nuevos = nums.map(n => traducir(n));
      return nuevos.some(x => x === null) ? null : nuevos;
    };
    // Los números ya traducidos se marcan (\u0001) para que la pasada siguiente no los vuelva a traducir
    const marca = r => r.map(x => "\u0001" + x + "\u0001");
    const frase = r => `See Section${r.length > 1 ? "s" : ""} ${unir(marca(r))}`;
    // 0) "(see 3.2)" a secas: la numeración propia de la hoja → la del contrato
    t = t.replace(/\s*\(\s*see\s+(\d+\.\d+)\s*\)/gi, (m, g) => { const r = resolver(g); return r ? " (see Section " + unir(marca(r)) + ")" : ""; });
    // 1) frases enteras que remiten: "(see Section 9.5)" · "— see Sections 8 and 9.3" · "See Section 9.9 regarding sealed plans."
    t = t.replace(new RegExp("\\s*\\(\\s*see\\s+sections?\\s+" + NUMS + "\\s*\\)", "gi"),
      (m, g) => { const r = resolver(g); return r ? " (" + frase(r).replace(/^See/, "see") + ")" : ""; });
    t = t.replace(new RegExp("\\s*[\u2014\u2013-]\\s*see\\s+sections?\\s+" + NUMS, "gi"),
      (m, g) => { const r = resolver(g); return r ? " \u2014 " + frase(r).replace(/^See/, "see") : ""; });
    t = t.replace(new RegExp("(^|[.;]\\s+)see\\s+sections?\\s+" + NUMS + "([^.;]*[.;]?)", "gi"),
      (m, pre, g, resto) => { const r = resolver(g); return r ? pre + frase(r) + resto : pre; });
    // 2) menciones sueltas ("described in Section 7.4"): se renumeran; si no existe, se deja como está
    t = t.replace(new RegExp("\\b(sections?)\\s+" + NUMS, "gi"),
      (m, pal, g) => { const r = resolver(g); return r ? pal + " " + unir(marca(r)) : m; });
    return t.replace(/\u0001/g, "").replace(/\s{2,}/g, " ").replace(/\s+([.;,])/g, "$1").replace(/\.\s*\./g, ".").trim();
  }
  const unir = arr => arr.length <= 1 ? arr.join("") : arr.slice(0, -1).join(", ") + " and " + arr[arr.length - 1];

  // "40/40/20" o "40% al firmar, 40% rough, 20% final"
  function leerPagos(valor, linea, err) {
    const P = { pcts: [], disparadores: [], lineas: [linea] };
    const corto = String(valor || "").match(/^\s*(\d{1,3})\s*[\/\-\s]\s*(\d{1,3})(?:\s*[\/\-\s]\s*(\d{1,3}))?(?:\s*[\/\-\s]\s*(\d{1,3}))?\s*$/);
    if (corto) { for (let k = 1; k < corto.length; k++) if (corto[k] !== undefined) { P.pcts.push(Number(corto[k])); P.disparadores.push(null); } P.corto = true; return P; }
    String(valor || "").split(/[,;]| y /).forEach(t => {
      const m = t.match(/(\d{1,3})\s*%\s*(.*)/);
      if (m) { P.pcts.push(Number(m[1])); P.disparadores.push((m[2] || "").trim() || null); }
    });
    return P;
  }

  // «Fotos del panel: sí» · "si" con comillas · «yes, 12 photos» · «no photos» → true / false; lo demás, null (se pregunta)
  function siNo(v) {
    const n = norma(String((v && v.valor) || "").replace(/["'«»“”‘’]/g, ""));
    if (/^(si|yes)\b/.test(n)) return true;
    if (/^no\b/.test(n)) return false;
    return null;
  }
  // Baja la primera letra para meter un título dentro de una frase, sin tocar las siglas: GFCI, AFCI, NEC, LED, HVAC,
  // EV, AC, DC, kW, kVA, A (amperios), V (voltios) y cualquier palabra en mayúsculas o con mayúscula por dentro
  const SIGLAS = /^(?:GFCI|AFCI|NEC|LED|HVAC|EV|AC|DC|kW|kVA)\b|^[AV](?=\/|\d|$)|^[A-Z][A-Z0-9]|^[A-Z][a-z]*[A-Z]/;
  const minus = t => { t = String(t || ""); return SIGLAS.test(t) ? t : t.charAt(0).toLowerCase() + t.slice(1); };

  // ============================================================ LA VALIDACIÓN
  function validarAlcance(L) {
    const errores = L.errores.slice(), preguntas = L.preguntas.slice();
    const D = L.datos, conFirma = leerFirma(D.firma);

    if (!D.cliente) preguntas.push({ clave: "cliente", texto: "¿Quién es el cliente (quien paga y firma)?", libre: true });
    if (!D.direccion) preguntas.push({ clave: "direccion", texto: "¿Cuál es la dirección de la obra?", libre: true });
    // v3.6 r2: la obra está en zona de inundación pero la hoja no dice la zona ni el BFE → se pregunta (va a la 7.x Flood elevation)
    {
      // v3.7: la 7.x Flood sale con los datos del certificado; si falta la zona o el BFE se pregunta UNA vez y la
      // respuesta queda escrita en la hoja («Flood zone: …»). Es dato de contrato: sin él la cláusula sale coja.
      const F = L.flood || {};
      const zonaD = norma(D.flood_zona || "").match(/\b(ae|ve|ao|ah|a|v)\b/);
      const zona = F.zona || (zonaD ? zonaD[1].toUpperCase() : "");
      const bfe = D.flood_bfe || F.bfe;
      if ((F.senales || zona) && !(zona && bfe))
        preguntas.push({ clave: "flood_zona", libre: true,
          texto: zona ? `La obra está en zona ${zona} pero no encuentro el BFE del certificado de elevación. Escríbelo así: ${zona}, BFE 11.0 / 12.0 ft NAVD 88, EC 12/23/2014, LAG 6.7 ft`
                      : "La obra está en zona de inundación (la hoja habla del certificado de elevación / FBC 1612). ¿Qué zona FEMA y qué BFE dice el certificado? Escríbelo así: AE, BFE 11.0 / 12.0 ft NAVD 88, EC 12/23/2014, LAG 6.7 ft" });
    }
    // Cada {{FALTA: pregunta}} que dejó el chat es una pregunta para Edgar
    (L.faltas || []).forEach(f => preguntas.push({
      clave: "falta_" + f.linea, linea: f.linea, texto: f.pregunta, libre: true,
      arreglo: { tipo: "responder_marca", linea: f.linea },
      alternativas: [{ etiqueta: f.soloMarca ? "Quitar esa línea" : "Quitar la pregunta",
                       arreglo: { tipo: f.soloMarca ? "quitar_linea" : "quitar_marca", linea: f.linea } }]
    }));
    if (!L.items.length) errores.push({ texto: "La sección Alcance está vacía. Sin ella no hay contrato." });
    if (!L.precio) errores.push({ texto: "Falta el precio base en Precio.",
      arreglos: [{ tipo: "poner_precio_base", etiqueta: "Escribir el precio", pide: "monto" }] });



    // v3.5: con contratista, en el papel el cliente es el contratista y la persona pasa a dueño
    const gcN = String(D.contratista || D.gc_nombre || "").trim();
    if (gcN && D.cliente && norma(D.cliente) !== norma(gcN) && !norma(D.cliente).includes(norma(gcN).split(" ")[0]))
      L.avisos.push({ informativo: true, texto: `Contrato con ${gcN}: en el papel el cliente es ${gcN} (paga y firma) y ${D.cliente} queda como dueño de la propiedad (Homeowner).` });
    // v3.5: una fase bajo tierra semanas antes del rough-in y el segundo pago al terminar el rough-in: es dinero en la calle
    {
      const fases = partirFases(((L.condiciones || {}).fases || {}).valor || "");
      const txtA = norma(L.items.map(it => it.titulo + " " + it.detalles.join(" ")).join(" "));
      const disp = ((L.pagos || {}).disparadores || []).map(x => norma(x || ""));
      const temprana = fases.some(f => /underground|bonding|trench|slab/i.test(f)) || /\b(underground|bonding grid|equipotential|trench)\b/.test(txtA);
      if (temprana && disp.length >= 2 && /rough/.test(disp[1] || "") && !disp.some(x => /bonding|underground|trench|slab/.test(x))) {
        // no es un rough-in de interior: el trabajo bajo tierra y el bonding van antes. La app propone el disparador;
        // Edgar lo pone con un toque (el dinero no cambia solo).
        const f0 = (fases[0] && /underground|bonding|trench|slab/i.test(fases[0]) ? fases[0] : "underground raceways and pool equipotential bonding").replace(/\s+and\s+/g, ", ");
        const propuesto = `upon completion of ${f0} and rough-in`;
        const lineaH2 = ((L.pagos || {}).lineas || [])[1];
        L.avisos.push({ texto: `Esto no es un rough-in de interior: hay trabajo bajo tierra / bonding antes. El pago 2 dice «${(L.pagos.disparadores[1] || "").slice(0, 50)}»; lo natural es «${propuesto}» (los montos no cambian). Si prefieres un hito aparte al aprobar el bonding (40/30/20/10), escríbelo en Pagos.`,
          arreglos: lineaH2 ? [{ tipo: "cambiar_disparador", etiqueta: "Poner ese disparador en el hito 2", linea: lineaH2, valor: propuesto }] : [] });
      }
    }
    // contrato con el contratista sin el nombre del dueño: no frena; firma solo el contratista
    if ((norma(D.contrato_con || "") === "gc" || gcN) && !L.avisos.some(a => /firma solo el contratista/.test(a.texto)))
      L.avisos.push({ informativo: true, texto: "Contrato con el contratista: firma solo el contratista (representante autorizado). El dueño de la propiedad queda como referencia (Homeowner) y firma el Layout Approval de la sección 8, no el SOW." });
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
        const arreglosPagos = [{ tipo: "poner_pagos", etiqueta: "40/40/20", valor: "40/40/20" },
                               { tipo: "poner_pagos", etiqueta: "50/50", valor: "50/50" },
                               { tipo: "poner_pagos", etiqueta: "35/40/25", valor: "35/40/25" }];
        if (suma !== 100) errores.push({ texto: `Los pagos suman ${suma}%. Tienen que sumar 100 exacto.`, linea: L.pagos.lineas[0], arreglos: arreglosPagos });
        if (L.pagos.pcts[0] === 0) errores.push({ texto: "El primer pago es el depósito y no puede ser 0%.", arreglos: arreglosPagos });
        if (L.pagos.pcts.some(p => !Number.isInteger(p))) errores.push({ texto: "Los pagos van en porcentajes enteros.", arreglos: arreglosPagos });
      }
    }

    // las dos condiciones que más protegen
    const C = L.condiciones;
    const si_no = siNo;
    if (si_no(C.fotos_panel) === null)
      preguntas.push({ clave: "fotos_panel", texto: "¿Tienes fotos o documentación del panel?",
        opciones: [{ etiqueta: "Sí las tengo", valor: "si" }, { etiqueta: "No las tengo", valor: "no" }] });
    if (si_no(C.circuitos_exist) === null)
      preguntas.push({ clave: "circuitos_exist", texto: "¿Este trabajo extiende o modifica circuitos que ya existen?",
        opciones: [{ etiqueta: "Sí", valor: "si" }, { etiqueta: "No", valor: "no" }] });

    if (si_no(C.fotos_panel) === false && !L.falta)
      errores.push({ texto: "Dijiste que no tienes fotos del panel: escribe en «Falta» qué te faltó al cotizar.",
        arreglos: [{ tipo: "poner_falta", etiqueta: "Escribirlo", pide: "texto" },
                   { tipo: "poner_falta", etiqueta: "Poner «sin fotos ni documentación del panel»", valor: "Sin fotos ni documentación del panel al cotizar", auto: true }] });

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
          texto: `${etiqueta} dice renglón ${n} pero solo hay ${L.items.length} renglones en el Alcance.`,
          arreglos: [{ tipo: "cambiar_renglon", etiqueta: "Elegir el renglón", linea: v.linea, pide: "renglon", valor: n }] });
      });
    });
    if (C.v240 && C.v240.valor && !/#\s*\d+|awg/i.test(C.v240.valor))
      errores.push({ linea: C.v240.linea, texto: "240V necesita tres datos: equipo, renglón y calibre. Ejemplo: «estufa, renglón 2, hasta #8».",
        arreglos: [{ tipo: "poner_calibre", etiqueta: "Calibre máximo (#8, #6…)", linea: C.v240.linea, pide: "texto" }] });

    // el Alcance habla de panel y la exclusión sigue puesta
    const noExcluir = norma((C.no_excluir || {}).valor || "");
    const textoAlcance = norma(L.items.map(i => i.titulo + " " + i.detalles.join(" ")).join(" "));
    // (el panel ya no se pregunta: si el alcance habla de panel, la exclusión se apaga sola desde la v3.4)
    [["afci", "afci"]].forEach(([palabra, clave]) => {
      if (textoAlcance.includes(palabra) && !noExcluir.includes(clave))
        preguntas.push({ clave: "no_excluir_" + clave,
          texto: `Tu alcance habla de ${palabra} y la sección 3 lo sigue excluyendo. ¿Quito esa exclusión?`,
          opciones: [{ etiqueta: "Sí, quítala", valor: clave }, { etiqueta: "No, déjala", valor: null }] });
    });

    return { errores, preguntas, puedeSeguir: errores.length === 0 };
  }

  // ============================================================ LOS ARREGLOS
  // Cada error trae uno o más arreglos. Aquí se aplican SOBRE EL TEXTO de la
  // hoja, a la vista de Edgar, y se cuenta en llano qué se cambió.
  function aplicarArreglo(texto, a, valor) {
    const lineas = String(texto || "").replace(/\r/g, "").split("\n");
    const i = (a.linea || 0) - 1;
    const hay = i >= 0 && i < lineas.length;
    const antes = hay ? lineas[i] : "";
    const v = valor !== undefined && valor !== null ? String(valor).trim() : (a.valor !== undefined ? String(a.valor) : "");
    let explicacion = "";
    const quitarLinea = (idx, conDetalles) => {
      let n = 1;
      if (conDetalles) while (idx + n < lineas.length && /^\s*[-*•]/.test(lineas[idx + n])) n++;
      lineas.splice(idx, n);
      return n;
    };
    switch (a.tipo) {
      case "quitar_dinero": {
        if (!hay) return { error: "esa línea ya no existe" };
        // Si el error dijo qué trozo le molestó, se quita ESE y no otro número
        const trozo = String(a.valor || "").trim();
        const escapa = t => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const rxTrozo = trozo ? new RegExp("\\(?\\s*(?:aprox\\.?|approx\\.?|precio|price|total|cost[oe]?)?\\s*:?\\s*\\$?\\s*" + escapa(trozo.replace(/^\$/, "")) + "\\s*(?:d[oó]lares|dollars|usd)?\\s*\\)?", "i")
                             : /\(?\s*(?:aprox\.?|approx\.?|precio|price|total|cost[oe]?)?\s*:?\s*\$?\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})?\s*(?:d[oó]lares|dollars|usd)?\s*\)?/i;
        const sin = antes.replace(rxTrozo, " ")
                          .replace(/\s{2,}/g, " ").replace(/\s+([,.;:])/g, "$1").replace(/[—–-]\s*$/, "").trim();
        const quitado = trozo || (antes.match(/\$?\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})?/) || [""])[0].trim();
        if (!sin || /^[-*•]\s*$/.test(sin)) { quitarLinea(i); explicacion = `línea ${a.linea}: solo tenía el precio (${quitado}); la quité`; }
        else { lineas[i] = sin; explicacion = `línea ${a.linea}: quité ${quitado} y dejé «${sin.replace(/^[-*•]\s*/, "").slice(0, 60)}»`; }
        break;
      }
      case "no_es_dinero": case "dejar_asi": {
        if (!hay) return { error: "esa línea ya no existe" };
        const nota = String(valor || "").trim();
        return { texto: lineas.join("\n"), perdona: { texto: antes.trim(), nota },
                 explicacion: nota ? `línea ${a.linea}: tú dices «${nota.slice(0, 80)}» — de acuerdo, la dejo como está`
                                   : `línea ${a.linea}: apuntado, «${antes.trim().slice(0, 60)}» se queda como está` };
      }
      case "quitar_linea": {
        if (!hay) return { error: "esa línea ya no existe" };
        const n = quitarLinea(i, !!a.conDetalles);
        explicacion = `línea ${a.linea}: quité «${antes.trim().slice(0, 60)}»` + (n > 1 ? ` y sus ${n - 1} detalles` : "");
        break;
      }
      case "quitar_marca": {
        if (!hay) return { error: "esa línea ya no existe" };
        const sin = antes.replace(/\s*\{\{FALTA:?[^}]*\}\}\s*/i, " ").replace(/\s{2,}/g, " ").trim();
        if (!sin.replace(/^[-*•\d.)\s]+/, "")) { quitarLinea(i); explicacion = `línea ${a.linea}: quité la pregunta del chat (la línea quedaba vacía)`; }
        else { lineas[i] = sin; explicacion = `línea ${a.linea}: quité la pregunta del chat y dejé «${sin.slice(0, 60)}»`; }
        break;
      }
      case "responder_marca": {
        if (!hay) return { error: "esa línea ya no existe" };
        if (!v) return { error: "escribe la respuesta" };
        lineas[i] = antes.replace(/\{\{FALTA:?[^}]*\}\}/i, v);
        explicacion = `línea ${a.linea}: puse tu respuesta «${v.slice(0, 60)}»`;
        break;
      }
      case "cambiar_disparador": {
        // en una fila de tabla "| Milestone 2 — 40% | Upon completion of rough-in | $7,380.00 |" cambia la celda del disparador;
        // en una línea suelta, el texto después del porcentaje
        if (!hay) return { error: "no encuentro la línea del hito" };
        const actual = (antes.split("|").length >= 4 ? antes.split("|")[2] : (antes.match(/\d{1,3}\s*%\)?\s*[:—–-]?\s*(.+?)(\s*\$\s?[\d,.]+)?\s*$/) || [])[1] || "").trim();
        const nuevo = /^[a-z]/.test(actual) ? v.charAt(0).toLowerCase() + v.slice(1) : v.charAt(0).toUpperCase() + v.slice(1);
        const celdas = antes.split("|");
        if (celdas.length >= 4) { celdas[2] = " " + nuevo + " "; lineas[i] = celdas.join("|"); }
        else lineas[i] = antes.replace(/(\d{1,3}\s*%\)?\s*[:—–-]?\s*)(.+?)(\s*\$\s?[\d,.]+)?\s*$/, (m, a, b, c) => a + nuevo + (c || ""));
        explicacion = `puse el disparador del hito 2: ${nuevo}`;
        break;
      }
      case "quitar_trozo": {
        if (!hay) return { error: "esa línea ya no existe" };
        lineas[i] = antes.split(",").map(s => s.trim()).filter(s => s && s !== v).join(", ");
        explicacion = `línea ${a.linea}: quité «${v}»`;
        break;
      }
      case "hacer_titulo": {
        if (!hay) return { error: "esa línea ya no existe" };
        lineas[i] = antes.replace(/^\s*[-*•]\s*/, "");
        explicacion = `línea ${a.linea}: lo convertí en renglón con título`;
        break;
      }
      case "poner_precio": {
        if (!hay) return { error: "esa línea ya no existe" };
        const m = leerMonto(v);
        if (!m || m.pregunta) return { error: "escribe el precio así: 1,850.00" };
        lineas[i] = antes.replace(/\s*[—–:-]\s*\$?\s*$/, "") + " — $" + dinero(m.centavos);
        explicacion = `línea ${a.linea}: le puse $${dinero(m.centavos)}`;
        break;
      }
      case "poner_precio_base": {
        const m = leerMonto(v);
        if (!m || m.pregunta) return { error: "escribe el precio así: 16,498.24" };
        const k = lineas.findIndex(l => /^\s*(precio|total|precio base|price)\s*:/i.test(l));
        if (k >= 0) lineas[k] = "Precio: " + dinero(m.centavos);
        else { const j = lineas.findIndex(l => /^\s*(pagos|opciones|condiciones)\s*:?\s*$/i.test(l));
               lineas.splice(j >= 0 ? j : lineas.length, 0, "Precio: " + dinero(m.centavos), ""); }
        explicacion = `Precio: $${dinero(m.centavos)}`;
        // Las filas de pagos que venían en blanco ("$ _[TBD]_") se rellenan con
        // el reparto por porcentaje, y la fila TOTAL con el precio.
        const TBD = /\$?\s*_*\[?\s*TBD\s*\]?_*/i;
        const conPct = [], total = [];
        lineas.forEach((l, idx) => {
          if (!TBD.test(l)) return;
          if (/(?<![\d.])\d{1,3}\s*%/.test(l)) conPct.push(idx);
          else if (/\btotal\b/i.test(l)) total.push(idx);
        });
        if (conPct.length) {
          const pcts = conPct.map(idx => Number(lineas[idx].match(/(?<![\d.])(\d{1,3})\s*%/)[1]));
          if (pcts.reduce((a, b) => a + b, 0) === 100) {
            const montos = repartir(m.centavos, pcts);
            conPct.forEach((idx, q) => { lineas[idx] = lineas[idx].replace(TBD, "$" + dinero(montos[q])); });
            total.forEach(idx => { lineas[idx] = lineas[idx].replace(TBD, "$" + dinero(m.centavos)); });
            explicacion += ` · rellené ${conPct.length} pagos en blanco (${pcts.join("/")})`;
          }
        } else if (total.length) {
          total.forEach(idx => { lineas[idx] = lineas[idx].replace(TBD, "$" + dinero(m.centavos)); });
        }
        break;
      }
      case "poner_pagos": {
        const k = lineas.findIndex(l => /^\s*(pagos|hitos|milestones|cobros)\s*:/i.test(l));
        if (k >= 0) {
          lineas[k] = "Pagos: " + v;
          // las líneas sueltas de "40% …" que había debajo se van
          while (k + 1 < lineas.length && /^\s*\d{1,3}\s*%/.test(lineas[k + 1])) lineas.splice(k + 1, 1);
        } else {
          const j = lineas.findIndex(l => /^\s*(opciones|condiciones)\s*:?\s*$/i.test(l));
          lineas.splice(j >= 0 ? j : lineas.length, 0, "Pagos: " + v, "");
        }
        explicacion = `Pagos: ${v}`;
        break;
      }
      case "poner_calibre": {
        if (!hay) return { error: "esa línea ya no existe" };
        const c = v.match(/\d+/);
        if (!c) return { error: "escribe el calibre: #8, #6…" };
        lineas[i] = antes.replace(/\s*$/, "") + ", hasta #" + c[0];
        explicacion = `línea ${a.linea}: añadí «hasta #${c[0]}»`;
        break;
      }
      case "cambiar_renglon": {
        if (!hay) return { error: "esa línea ya no existe" };
        const n = Number(v);
        if (!n) return { error: "elige el renglón" };
        lineas[i] = /rengl[oó]n(?:es)?\s+[\d,\sy]+/i.test(antes)
          ? antes.replace(/rengl[oó]n(?:es)?\s+[\d,\sy]+/i, "renglón " + n)
          : antes.replace(/\s*$/, "") + ", renglón " + n;
        explicacion = `línea ${a.linea}: ahora apunta al renglón ${n}`;
        break;
      }
      case "poner_falta": {
        if (!v) return { error: "escribe qué te faltó" };
        const k = lineas.findIndex(l => /^\s*#*\s*(falta|lo que falta|sin datos|falta informacion|falta información)\s*:?\s*$/i.test(l));
        if (k >= 0) lineas.splice(k + 1, 0, v);
        else { const j = lineas.findIndex(l => /^\s*#*\s*(alcance|incluye|scope)\s*:?\s*$/i.test(l));
               lineas.splice(j >= 0 ? j : lineas.length, 0, "Falta", v, ""); }
        explicacion = `Falta: «${v.slice(0, 60)}»`;
        break;
      }
      case "corregir_titulo": {
        if (!hay) return { error: "esa línea ya no existe" };
        lineas[i] = v.charAt(0).toUpperCase() + v.slice(1);
        explicacion = `línea ${a.linea}: «${antes.trim().slice(0, 30)}» → «${lineas[i]}»`;
        break;
      }
      case "corregir_clave": {
        if (!hay) return { error: "esa línea ya no existe" };
        const resto = antes.slice(antes.indexOf(":") + 1);
        lineas[i] = v.charAt(0).toUpperCase() + v.slice(1) + ":" + resto;
        explicacion = `línea ${a.linea}: «${antes.split(":")[0].trim()}» → «${v}»`;
        break;
      }
      case "renumerar": {
        const L = leerAlcance(lineas.join("\n"));
        L.items.forEach((it, k) => { const j = it.lineas[0] - 1;
          lineas[j] = lineas[j].replace(/^(\s*)(?:\d+(?:\.\d+)*[.)\-]?\s+)?/, "$1" + (k + 1) + ". "); });
        explicacion = `numeré los ${L.items.length} renglones seguidos`;
        break;
      }
      // v3.7 (tanda 1): los botones de «¿qué es esta línea?» (una línea sin sitio, o una que el lector quiso dejar fuera)
      case "es_renglon": {
        // una línea suelta pasa a ser renglón del Alcance: sin viñeta ni numeración vieja; si no está dentro del
        // Alcance, se lleva al final de esa sección (y si no hay Alcance, se crea)
        if (!hay) return { error: "esa línea ya no existe" };
        const L = leerAlcance(lineas.join("\n"));
        const secDe = n => { let s = "datos"; (L.titulos || []).forEach(t => { if (t.linea <= n) s = t.seccion; }); return s; };
        let nueva = antes.replace(/^\s*[-*•]\s*/, "").replace(/^\s*\d+(?:\.\d+)*[.)]\s+/, "").trim();
        // una línea larga sin número la leerían las reglas como descripción del renglón de arriba: se numera
        if (nueva.length > 60) nueva = (L.items.length + 1) + ". " + nueva;
        if (secDe(a.linea) === "alcance") { lineas[i] = nueva; explicacion = `línea ${a.linea}: ahora es un renglón del Alcance`; break; }
        lineas.splice(i, 1);
        const k = (L.titulos || []).findIndex(t => t.seccion === "alcance");
        if (k >= 0) {
          const sig = L.titulos[k + 1];
          let idx = sig ? sig.linea - 1 : lineas.length;
          if (sig && i < sig.linea - 1) idx--;
          while (idx > L.titulos[k].linea && !String(lineas[idx - 1] || "").trim()) idx--;   // antes de las líneas en blanco del final
          lineas.splice(idx, 0, nueva);
        } else {
          const j = lineas.findIndex(l => /^\s*#*\s*(precio|pagos|opciones|condiciones|price|payments?|options)\s*:?/i.test(l));
          lineas.splice(j >= 0 ? j : lineas.length, 0, "Alcance", nueva, "");
        }
        explicacion = `línea ${a.linea}: la llevé al Alcance como renglón («${nueva.slice(0, 50)}»)`;
        break;
      }
      case "es_detalle_de": {
        // una línea pasa a ser detalle («- ») del renglón que se diga (valor = número del renglón); sin número, del de arriba
        if (!hay) return { error: "esa línea ya no existe" };
        const nueva = "- " + antes.replace(/^\s*[-*•]\s*/, "").replace(/^\s*\d+(?:\.\d+)*[.)]\s+/, "").trim();
        const n = Number(v || a.renglon || 0);
        if (!n) { lineas[i] = nueva; explicacion = `línea ${a.linea}: ahora es detalle del renglón de arriba`; break; }
        const L = leerAlcance(lineas.join("\n"));
        const it = L.items[n - 1];
        if (!it) return { error: `no hay renglón ${n} en el Alcance` };
        const ultima = Math.max(...it.lineas);
        if (i === ultima - 1) return { error: "esa línea es el propio renglón" };
        lineas.splice(i, 1);
        lineas.splice(i < ultima - 1 ? ultima - 1 : ultima, 0, nueva);
        explicacion = `línea ${a.linea}: ahora es detalle del renglón ${n} («${it.titulo.slice(0, 40)}»)`;
        break;
      }
      case "cambiar_condicion": {
        // cambia el valor de una condición «Clave: valor» (por línea, o por clave si la línea no se sabe; si no existe, se escribe)
        if (!v) return { error: "escribe el valor" };
        if (hay && /^\s*[^:]{2,42}:/.test(antes)) {
          const mAnt = antes.match(/^(\s*[^:]{2,42}:\s*)(.*)$/);
          const nuevo = a.anadir && mAnt[2].trim() ? mAnt[2].trim().replace(/[.;]$/, "") + ", " + v : v;
          lineas[i] = mAnt[1] + nuevo;
          explicacion = `línea ${a.linea}: «${antes.split(":")[0].trim()}» ahora dice «${nuevo.slice(0, 60)}»`;
          break;
        }
        const clave = a.clave;
        if (!(typeof clave === "string" && Object.prototype.hasOwnProperty.call(CLAVES_COND, clave))) return { error: "no sé qué condición cambiar" };
        const L = leerAlcance(lineas.join("\n"));
        const c = L.condiciones[clave];
        const etiqueta = CLAVES_COND[clave][0].charAt(0).toUpperCase() + CLAVES_COND[clave][0].slice(1);
        if (c && c.linea) {
          const j = c.linea - 1, mAnt = lineas[j].match(/^(\s*[^:]{2,42}:\s*)(.*)$/);
          const nuevo = a.anadir && mAnt && mAnt[2].trim() ? mAnt[2].trim().replace(/[.;]$/, "") + ", " + v : v;
          lineas[j] = (mAnt ? mAnt[1] : etiqueta + ": ") + nuevo;
          explicacion = `línea ${c.linea}: «${etiqueta}» ahora dice «${nuevo.slice(0, 60)}»`;
        } else {
          const k = lineas.findIndex(l => /^\s*#*\s*(?:\d+[.)]?\s+)?(condiciones|clausulas|cláusulas|conditions|assumptions)\s*:?\s*$/i.test(l));
          if (k >= 0) lineas.splice(k + 1, 0, etiqueta + ": " + v);
          else { const j = lineas.findIndex(l => /^\s*#*\s*(codigo|código|code|notas|notes)\s*:?\s*$/i.test(l));
                 lineas.splice(j >= 0 ? j : lineas.length, 0, "Condiciones", etiqueta + ": " + v, ""); }
          explicacion = `escribí «${etiqueta}: ${v.slice(0, 60)}» en Condiciones`;
        }
        break;
      }
      default: return { error: "no sé hacer ese arreglo" };
    }
    return { texto: lineas.join("\n"), explicacion };
  }

  // Aplica, uno por uno y releyendo cada vez, todos los arreglos que no
  // necesitan a Edgar. Devuelve el texto final y la lista de lo hecho.
  function arreglarTodo(texto, opciones) {
    const hechos = [];
    let t = String(texto || "");
    for (let vuelta = 0; vuelta < 80; vuelta++) {
      const L = leerAlcance(t, opciones), V = validarAlcance(L);
      // los arreglos que vienen del lector inteligente (origen: "ia") nunca se aplican solos: siempre con un toque de Edgar
      const cand = [...V.errores, ...L.avisos].map(e => (e.arreglos || []).find(a => a.auto && a.origen !== "ia")).filter(Boolean);
      if (!cand.length) break;
      // de abajo hacia arriba, para que los números de línea no se muevan
      cand.sort((x, y) => (y.linea || 0) - (x.linea || 0));
      const r = aplicarArreglo(t, cand[0]);
      if (r.error) break;
      t = r.texto; hechos.push(r.explicacion);
    }
    return { texto: t, hechos };
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
  // "Permiso: nosotros" · "Permiso: cliente" · "Permiso: no hace falta" — y también lo
  // que escriba Ordenar o Edgar a su manera ("lo saca Max Power", "by the Client"…)
  function leerPermiso(v) {
    const n = norma(v || "");
    if (!n) return "nosotros";
    if (/no hace falta|no permit|not required|ninguno|sin permiso|no aplica/.test(n)) return "ninguno";
    if (/\b(cliente|client|gc|owner|dueno|contratista)\b/.test(n) && !/max power|nosotros/.test(n)) return "cliente";
    return "nosotros";
  }
  // v3.6: la zona de inundación y sus números se leen de cualquier parte de la hoja (sección 1, 4, 7 o 9),
  // no solo de la cabecera: "Zone AE", "BFE 11.0 / 12.0 ft NAVD 88", "Elevation Certificate dated 12/23/2014",
  // "lowest adjacent grade 6.7 ft"
  function extraerFlood(txt) {
    const t = String(txt || "").replace(/\s+/g, " ");
    const F = {};
    const z = t.match(/\b(?:flood\s+|fema\s+)?zone\s*[:\-]?\s*(AE|VE|AO|AH|A|V)\b(?![a-z])/i) || t.match(/\bzona\s*[:\-]?\s*(AE|VE|AO|AH)\b/i);
    if (z) F.zona = z[1].toUpperCase();
    // v3.7: «Base Flood Elevation + 1 ft» / «freeboard BFE + 1 ft» es el margen, no la cota. La cota de verdad trae
    // decimales (11.0), un par (11.0 / 12.0), NAVD 88 o al menos dos pies; entre varias se queda la más completa.
    const rxB = /\b(?:BFE|base flood elevation)\b([^\d]{0,20})(\d+(?:\.\d+)?(?:\s*\/\s*\d+(?:\.\d+)?)?)\s*(?:ft|feet|')?\s*(NAVD\s*88|NGVD\s*29)?/gi;
    let mb, mejor = null;
    while ((mb = rxB.exec(t))) {
      if (/\+|\bplus\b|\bfreeboard\b|\babove\b|\bthan\b|\bhigher\b|\blower\b|\bcertificate\b|\bfirm\b/i.test(mb[1])) continue;   // «BFE is higher than the 2014 certificate»
      const val = mb[2], navd = mb[3];
      if (!navd && /^(19|20)\d{2}$/.test(val)) continue;                                   // un año, no una cota
      if (!(navd || /[.\/]/.test(val) || Number(val) >= 2)) continue;
      const peso = (navd ? 2 : 0) + (/[.\/]/.test(val) ? 1 : 0);
      if (!mejor || peso > mejor.peso) mejor = { val, navd, peso };
    }
    if (mejor) F.bfe = mejor.val.replace(/\s*\/\s*/, " / ") + " ft" + (mejor.navd ? " " + mejor.navd.toUpperCase().replace(/\s+/, " ") : "");
    const e = t.match(/elevation certificate\b[^.;]{0,60}?\b(\d{1,2}\/\d{1,2}\/\d{2,4})/i) || t.match(/\b(\d{1,2}\/\d{1,2}\/\d{2,4})\b[^.;]{0,40}elevation certificate/i)
           || t.match(/\bEC\s*[:=]?\s*(\d{1,2}\/\d{1,2}\/\d{2,4})/) || t.match(/\b((?:19|20)\d{2})\s+elevation certificate/i) || t.match(/elevation certificate\b[^.;]{0,40}?\b((?:19|20)\d{2})\b/i);
    if (e) F.ec = e[1];
    const g = t.match(/lowest adjacent grade\b\s*(?:\(LAG\))?[^\d]{0,12}(\d+(?:\.\d+)?)\s*(?:ft|feet|')?/i) || t.match(/\bLAG\s*[:=]?\s*(\d+(?:\.\d+)?)\s*(?:ft|feet|')?/);
    if (g) F.lag = g[1] + " ft";
    // señales de que la propiedad está en zona de inundación aunque nadie diga la zona
    F.senales = /\b(floodplain|flood zone|flood-zone|elevation certificate|fbc 1612|asce 24|base flood elevation|design flood elevation|\bbfe\b|firm panel|nfip)\b/i.test(t);
    return F;
  }
  // Junta nombres de contacto sin repetir: «Roberto Prata / Kevin Haseney» + «Roberto Prata» → los dos, una vez
  function juntarNombres(...vs) {
    const vistos = new Set(), salida = [];
    vs.forEach(v => String(v || "").split(/\s*[\/,;|]\s*|\s+(?:y|and|&)\s+/i).map(x => x.trim()).filter(Boolean).forEach(n => {
      const k = norma(n); if (!vistos.has(k)) { vistos.add(k); salida.push(n); } }));
    return salida.join(" / ");
  }
  // v3.5: si la hoja no dice «Permiso:», se lee de lo que sí dice (jurisdicción, exclusiones, cronograma)
  function inferirPermiso(L, esGC) {
    const d = L.datos || {};
    if (d.permiso) return leerPermiso(d.permiso);
    const txt = norma([d.ciudad || "", ...(L.no_incluye || []).map(x => x.texto), ...(L.programa || []).map(t => t.titulo + " " + t.texto), L.hoy || ""].join(" "));
    if (/permit[^.]{0,60}(held|pulled|obtained|secured|issued|applied)\s+(by|to|under)\s+(the\s+)?(general contractor|gc|client|owner|others)|under\s+(the\s+)?(general\s+)?(contractor|gc)\s*.?s\s+(building\s+|master\s+)?permit|(general contractor|gc)\s*.?s\s+(building\s+|master\s+|electrical\s+)?permit|permit[^.]{0,30}by the (general contractor|gc|client|owner)/.test(txt)) return "cliente";
    if (/no permit (is )?(required|needed)|does not require a permit|permit not required/.test(txt)) return "ninguno";
    return "nosotros";
  }
  const leerFirma = v => !/^(no|sin firma|alcance|ligero|scope of work)$/.test(norma(v || "si")) && !/^no\b/.test(norma(v || "si"));
  function leerVence(v, hoy) {
    const s = String(v || "").trim();
    if (!s) return 15;
    const n = s.match(/^\s*(\d{1,3})\s*(d[ií]as?|days?)?\s*$/i);
    if (n) return Math.max(1, Number(n[1]));
    const f = new Date(s);
    if (!isNaN(f.getTime())) {
      const base = hoy || new Date();
      const dias = Math.round((f.getTime() - base.getTime()) / 864e5);
      if (dias >= 1 && dias <= 365) return dias;
    }
    return 15;
  }

  function decidirInterruptores(L, D) {
    const d = L.datos, C = L.condiciones, cuenta = D || cuentas(L);
    const hay = v => !!(v && String(v).trim() && norma(v) !== "no");
    const si_no = siNo;
    const conFirma = leerFirma(d.firma);
    // Es un subcontrato con un contratista cuando la hoja trae un dueño de la
    // propiedad distinto del cliente, o cuando la app dice que el contrato es
    // con la empresa (proyectos.contratista_modo = 'contrato').
    // v3.5: también cuando la hoja (o la app, gc_nombre) dice con qué contratista se contrata
    const gcNombre = String(d.contratista || d.gc_nombre || "").trim();
    const esGC = hay(d.dueno) || norma(d.contrato_con || "") === "gc" || hay(gcNombre);
    // Con contratista: el cliente del contrato es el contratista; la persona que la hoja llama «Client»
    // (si no es el contratista) es el dueño de la propiedad.
    const duenoEfectivo = hay(d.dueno) ? d.dueno
      : (esGC && hay(gcNombre) && hay(d.cliente) && norma(d.cliente) !== norma(gcNombre) && !norma(d.cliente).includes(norma(gcNombre).split(" ")[0]) ? d.cliente : "");
    const clienteEfectivo = esGC && hay(gcNombre) ? gcNombre : (d.cliente || "");
    // Propiedad comercial: la 9.16 del depósito (F.S. 489.126) mira la propiedad,
    // no quién paga. Si la hoja no dice nada, se trata como residencial: dejar la
    // cláusula de más nunca hace daño; quitarla cuando tocaba, sí.
    // v3.3 (7-sep, Wimauma): la propiedad comercial tampoco es «consumidor»:
    //   · 713.015 (aviso de gravámenes) solo lo exige la ley en viviendas de hasta 4 unidades;
    //   · 501.021 / 16 CFR 429 (tres días para cancelar) son de una venta a un CONSUMIDOR
    //     (uso personal, familiar o del hogar), no de un campo de pelota ni de una tienda;
    //   · 489.126 (9.16 del depósito) habla de propiedad RESIDENCIAL.
    const esComercial = /comercial|commercial/.test(norma(d.propiedad || d.property || ""));
    const esConsumidor = !esGC && !esComercial;
    const permiso = inferirPermiso(L, esGC);   // regla de la casa: si nadie dice nada, lo sacamos nosotros
    const noExcluir = norma((C.no_excluir || {}).valor || "");
    // v3.4: el contrato se ajusta a lo que DICE el alcance, no a una cocina genérica.
    const textoAlcance = norma([d.proyecto || "", ...L.items.map(it => it.titulo + " " + it.detalles.join(" "))].join(" "));
    const textoExcl = norma((L.no_incluye || []).map(x => x.texto).join(" "));
    const hayPanel = /\b(panel|panelboard|sub-?panel|load center|service entrance|service equipment|main breaker|main disconnect|meter)\b/.test(textoAlcance);
    // Interior de una casa (cocina, cuartos, ático…) contra servicio exterior (poste, pozo, bomba…).
    // "control cabinet" no es "cabinet lighting": las palabras se miran con cuidado.
    // v3.5: una cocina EXTERIOR (outdoor kitchen, pavilion, lanai, pool deck) no es el interior de una casa:
    // sin gabinetes, sin drywall, sin ático. Solo cuenta como interior si además hay cuartos de verdad.
    const venueExterior = /\b(outdoor kitchen|summer kitchen|pavilion|lanai|patio|pool deck|pool shell|pool equipment|dock|pergola|gazebo|screen enclosure)\b/.test(textoAlcance);
    const interiorFuerte = /\b(bath|bathroom|bedrooms?|living room|family room|dining room|closet|garage|laundry|hallway|attic|crawl space)\b/.test(textoAlcance);
    const interiorSuave = /\b(kitchen|dining|recessed|drywall|under-cabinet|cabinet lighting|kitchen cabinets?|island)\b/.test(textoAlcance);
    let interior = interiorFuerte || (interiorSuave && !venueExterior);
    let exterior = venueExterior || /\b(pole|service entrance|well|pump|irrigation|parking lot|site lighting|transformer|feeder|wellhead|underground|trench)\b/.test(textoAlcance);
    // v3.7 (tanda 1): «Tipo de trabajo: …» escrito a mano en Condiciones manda sobre las listas de palabras:
    //   service → servicio exterior aunque el alcance diga «garage»: sin gabinetes, drywall, aparatos ni AFCI
    //   remodel → dentro de una vivienda: las exclusiones de casa se quedan
    //   mezcla  → las dos cosas: no se apaga ninguna exclusión
    const tipoTrabajo = String((C.tipo_trabajo || {}).valor || "");
    if (tipoTrabajo === "service") { interior = false; exterior = true; }
    else if (tipoTrabajo === "remodel" || tipoTrabajo === "mezcla") { interior = true; }
    const exteriorServicio = exterior && !interior;
    const residencialInterior = !esComercial && interior;
    const sinAfci = esComercial || tipoTrabajo === "service";
    const yaExcluye = re => re.test(textoExcl);
    const hayItemPermiso = /\bpermit/.test(textoAlcance);
    const hayCierre = L.items.some(it => /^(testing|startup|closeout|commissioning)\b|\b(closeout|close-out|commissioning)\b/i.test(it.titulo));
    const propio = clasificarPropias(L);
    const preProprio = propio.pre.length > 0;
    // v3.5: las fases (movilizaciones) — las de la hoja; si no las dice, se deducen del alcance:
    // trabajo bajo tierra / bonding antes de la losa = una salida aparte antes del rough-in
    const fasesHoja = partirFases((C.fases || {}).valor || "");
    const hayBajoTierra = /\b(underground|trench|trenching|bonding grid|equipotential|under the slab|slab|pool)\b/.test(textoAlcance);
    const fases = fasesHoja.length ? fasesHoja : (hayBajoTierra ? ["underground raceways and bonding", "rough-in", "trim-out"] : []);
    const fasesDeducidas = !fasesHoja.length && fases.length > 0;
    // v3.5: la sección 4 por grupos (como la trae la hoja) o la línea genérica
    const codigoPropio = (L.codigo_detalle || []).some(g => g.grupo || g.otros.length);
    // v3.6: 7.x Flood elevation cuando la propiedad está en zona AE / VE / AO / AH y la hoja no trae su propia cláusula
    const zonaTxt = norma(d.flood_zona || (L.flood || {}).zona || "").match(/\b(ae|ve|ao|ah|a|v)\b/);
    const mZona = zonaTxt ? [zonaTxt[0], zonaTxt[1]] : null;
    // v3.7: con zona conocida, o con señales claras de zona de inundación (floodplain, FBC 1612, ASCE 24, certificado de
    // elevación) sale la 7.x Flood de la plantilla, que lleva los datos del certificado (regla B9 del revisor). Si la hoja
    // trae su propia frase de flood, clasificarPropias la quita para no repetir y sus números se leen igual.
    const flood = !!mZona || !!(L.flood || {}).senales;
    const layout = !preProprio && norma(d.layout || "si") !== "no";

    const bloques = {
      VARIANTE_B: conFirma, VARIANTE_A: !conFirma,
      ATTENTION: hay(d.atencion), HOMEOWNER: esGC, GC: esGC,
      // v3.2: CONSUMIDOR enciende todo lo que solo vale en un contrato directo con el
      // dueño de una casa: el aviso de gravámenes (713.015) y los tres días para cancelar.
      CONSUMIDOR: esConsumidor,
      PLANOS: hay(d.planos),
      QUE_HAY_HOY: !!L.hoy, QUE_CAMBIA: !!L.cambia, FALTA: !!L.falta,
      INGENIERIA: hay(d.ingenieria),
      FIXTURES_CLIENTE: hay((C.fixtures_cliente || {}).valor),
      PERMISO_CLIENTE: permiso === "cliente",
      PERMISO_MXP: permiso === "nosotros",
      PERMISO_NINGUNO: permiso === "ninguno",
      ADDONS: L.opciones.length > 0,
      UTILITY: hay(d.utility),
      LAYOUT: layout, NO_LAYOUT: !layout && !preProprio,
      // v3.4: la hoja trae su propia sección 8, su cronograma, sus cláusulas o sus condiciones de pago
      PRE_PROPIO: preProprio,
      PROGRAMA_PROPIO: propio.programa.length > 0,
      PAGOS_PROPIOS: (L.pagos_propios || []).length > 0,
      CIERRE_GENERICO: !hayCierre,          // el "Testing and closeout" de la plantilla solo si la hoja no trae el suyo
      SIN_ITEM_PERMISO: !hayItemPermiso,    // el bullet del permiso en §3 sobra si el permiso ya es un renglón del §2
      // Segunda firma: dos dueños en la escritura, o el dueño debajo del contratista (solo si se sabe su nombre;
      // sin nombre no se deja una línea con hueco: firma solo el contratista)
      // v3.6 (regla de la casa): con contratista, el dueño NO firma el SOW (es referencia; firma el Layout Approval
      // de la sección 8). La segunda firma solo existe con dos dueños en la escritura.
      CLIENT_2: hay(d.segundo_firmante),
      CODIGO_PROPIO: codigoPropio, CODIGO_GENERICO: !codigoPropio,
      FLOOD: flood,
      // Exclusiones: solo las que tienen sentido en ESTE trabajo
      EXCL_PANEL: !noExcluir.includes("panel") && !hayPanel,
      EXCL_AFCI: !noExcluir.includes("afci") && !sinAfci,
      EXCL_GABINETES: !noExcluir.includes("gabinete") && residencialInterior,
      EXCL_DRYWALL: !noExcluir.includes("drywall") && interior,
      EXCL_LOWVOLT: !noExcluir.includes("low-voltage") && !noExcluir.includes("low voltage") && !yaExcluye(/low.?voltage|data|telemetry/),
      EXCL_APARATOS: !noExcluir.includes("aparato") && residencialInterior,
      EXCL_FUERA_AREAS: !noExcluir.includes("fuera-de-area") && !noExcluir.includes("fuera de area") && !yaExcluye(/outside the areas|any work outside/),
      EXCL_AHJ: !noExcluir.includes("inspector") && !noExcluir.includes("ahj") && !yaExcluye(/authority having jurisdiction|\bahj\b/)
    };

    const clausulas = {
      garantia: true, existentes: true, sitio: true, edicion: true,
      cambios: true, limite: true, seguro: true,
      // v3.5 (regla de Edgar del 2-sep): las correcciones al sistema EXISTENTE que pida el inspector
      // no van incluidas, y si el cliente no las autoriza, la aprobación final queda en suspenso
      ahj_upgrades: true,
      cancelacion_tardia: esConsumidor,   // habla de los tres días del consumidor
      cancelacion_gc: !esConsumidor,      // la misma política, sin los tres días (GC o propiedad comercial)
      retainage: esGC,
      nto_releases: esGC,
      panel_sin_fotos: si_no(C.fotos_panel) === false,
      afci: si_no(C.circuitos_exist) === true && !sinAfci,   // AFCI es de vivienda (NEC 210.12); no en comercial ni en servicio exterior
      reuso_240: hay((C.v240 || {}).valor),
      reubicar: hay((C.reubicar || {}).valor),
      isla: hay((C.isla || {}).valor),
      aberturas: hay((C.abrir || {}).valor),
      fixtures_cliente: bloques.FIXTURES_CLIENTE,
      fixtures_mxp: hay((C.fixtures_mxp || {}).valor),
      subsuelo: hay((C.excavacion || {}).valor),
      planos_permiso: bloques.PLANOS,
      // v3.4: las cláusulas propias de la hoja (las que la plantilla no trae)
      propias: propio.propias.length > 0,
      // 9.16 (F.S. 489.126): la ley mira la PROPIEDAD, no quién paga. Va siempre en
      // residencial; en un subcontrato sobre propiedad comercial, no.
      deposito: conFirma && cuenta.deposito_mayor_10 && !esComercial
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
      deposito: "porque el depósito pasa del 10% del precio",
      retainage: "porque el contrato es con un contratista (GC)",
      nto_releases: "porque el contrato es con un contratista (GC): el Notice to Owner y los releases",
      cancelacion_gc: esGC
        ? "porque el contrato es con un contratista: no corren los tres días del consumidor"
        : "porque la propiedad es comercial: no es una venta a un consumidor (F.S. 501.021), no corren los tres días"
    };
    motivos.propias = "porque la hoja trae condiciones propias de este trabajo: " + propio.propias.map(p => p.titulo).join(" · ");
    return { bloques, clausulas, motivos, permiso, esGC, esComercial, esConsumidor, conFirma,
             perfil: { hayPanel, interior, exteriorServicio, residencialInterior, venueExterior, tipo_trabajo: tipoTrabajo || null }, propio,
             gcNombre, clienteEfectivo, duenoEfectivo, permiso, fases, fasesDeducidas, flood, zona: mZona ? mZona[1].toUpperCase() : "" };
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

  // ================================================ EL INGLÉS TAL CUAL (directo)
  // Si la hoja ya viene en inglés (el chat la escribió así), no hace falta el
  // asistente: el texto de Edgar pasa al contrato tal cual, línea por línea.
  // Devuelve la misma forma que devolvería el cerebro, para que el resto no cambie.
  const EN_PALABRAS = /\b(the|and|with|from|for|new|existing|install|replace|panel|circuit|will|not|is|are|to|of|in|at|on|by|be|all)\b/gi;
  const ES_PALABRAS = /\b(el|la|los|las|de|del|con|para|por|un|una|que|se|es|son|nuevo|nueva|existente|cambiar|poner|instalar|panel|circuito|no|y|en|al)\b/gi;
  function pareceIngles(L) {
    const t = [L.hoy, L.cambia, L.falta, ...L.items.flatMap(i => [i.titulo, ...i.detalles]),
               ...L.no_incluye.map(x => x.texto)].join(" ");
    if (t.trim().length < 20) return null;   // no hay texto para saberlo
    const en = (t.match(EN_PALABRAS) || []).length, es = (t.match(ES_PALABRAS) || []).length;
    return en >= es * 1.5;
  }
  function redactarDirecto(L) {
    const d = L.datos, C = L.condiciones;
    const limpia = t => String(t || "").replace(/\s{2,}/g, " ").trim();   // las referencias las renumera armarTodo
    const frase = t => { t = limpia(t); return t && !/[.!?:]$/.test(t) ? t + "." : t; };
    const parrafo = t => String(t || "").split("\n").map(x => x.trim()).filter(Boolean).map(frase).join(" ");
    const de = n => ({ de: n ? [n] : [] });
    const con = (texto, linea) => { const t = String(texto || "").trim(); return t ? Object.assign({ en: t }, de(linea)) : null; };
    const lista = arr => arr.length <= 1 ? arr.join("") : arr.slice(0, -1).join(", ") + " and " + arr[arr.length - 1];
    const titulos = L.items.map(i => i.titulo.trim().replace(/[.:]$/, ""));
    const S = {
      directo: true,
      proyecto_en: con(d.proyecto, L.lineas.findIndex(x => /^\s*(proyecto|project)\s*:/i.test(x)) + 1),
      resumen_del_trabajo: con(d.resumen || (titulos.length ? "the electrical work described in Section 2: " + lista(titulos.map(minus)) : d.proyecto), 0),
      que_hay_hoy: con(parrafo(L.hoy), 0), que_cambia: con(parrafo(L.cambia), 0), que_faltaba: con(parrafo(L.falta), 0),
      load_calc_y_planos: con(frase(d.ingenieria), 0), planos: con(d.planos, 0),
      items: L.items.map(it => ({ titulo: con(limpia(it.titulo).replace(/[.:]$/, ""), it.lineas[0]),
                                  descripcion: con(it.detalles.map(frase).join(" ") || frase(it.titulo), it.lineas[0]) })),
      no_incluye: L.no_incluye.map(x => {
        if (x.titulo) return { titulo: con(limpia(x.titulo), x.linea), texto: con(x.cuerpo ? frase(x.cuerpo.charAt(0).toUpperCase() + x.cuerpo.slice(1)) : "", x.linea) || { en: "", de: [x.linea] } };
        // "Título. texto" · "Título: texto" · "Título — texto"; si no hay corte natural, la frase entera es el
        // título (sin repetirla como texto); solo si es muy larga se parte en las primeras palabras y EL RESTO
        // v3.6 (regla B1 del revisor): el título es hasta el primer « — » o «:»; si no hay, la primera frase
        // entera hasta el punto; si tampoco, la frase completa. NUNCA se corta por conteo de palabras.
        const cap = t => t.charAt(0).toUpperCase() + t.slice(1);
        const m = x.texto.match(/^(.{3,140}?)\s+[—–]\s+(.+)$/) || x.texto.match(/^([^:]{3,140}?):\s+(.+)$/)
               || x.texto.match(/^(.{3,220}?[^.\s]\.)\s+([A-Z(].*)$/);
        if (m) return { titulo: con(limpia(m[1].replace(/\.$/, "")), x.linea), texto: con(frase(cap(m[2])), x.linea) };
        return { titulo: con(limpia(x.texto.replace(/[.;]$/, "")), x.linea), texto: { en: "", de: [x.linea] } };
      }),
      opciones: L.opciones.map(o => ({ titulo: con(o.titulo, o.linea), descripcion: con(o.detalles.map(frase).join(" "), o.linea) })),
      resumen_corrido: con(lista(titulos.map(minus)), 0),
      areas_incluidas: con((C.areas || {}).valor, (C.areas || {}).linea),
      lo_que_no_tocas: con((C.no_tocamos || {}).valor, (C.no_tocamos || {}).linea),
      que_tiene_que_estar_listo: con((C.listo_rough || {}).valor, (C.listo_rough || {}).linea),
      lista_de_fases: con((C.fases || {}).valor, (C.fases || {}).linea),
      acceso: con((C.acceso || {}).valor, (C.acceso || {}).linea),
      cuales_fixtures: con((C.fixtures_cliente || {}).valor, (C.fixtures_cliente || {}).linea),
      fixtures_mxp: con((C.fixtures_mxp || {}).valor, (C.fixtures_mxp || {}).linea),
      aberturas: con(String((C.abrir || {}).valor || "").replace(/,?\s*rengl[oó]n(?:es)?\s+[\d,\sy]+/i, "").trim(), (C.abrir || {}).linea),
      utility: d.utility ? { quien: con(d.utility.split(/\s+(?:to|para|:)\s+/)[0], 0), que_hace: con(d.utility.split(/\s+(?:to|para|:)\s+/).slice(1).join(" "), 0) } : null,
      dudas: [], sugerencias: []
    };
    Object.keys(S).forEach(k => { if (S[k] === null) delete S[k]; });
    return S;
  }

  // ==================================================== REVISAR LO QUE DEVOLVIÓ
  // Lo que el asistente NO puede escribir nunca: dinero, porcentajes, artículos del
  // código, números de cláusula y marcas de plantilla. (Palabras como "warranty" sí
  // puede escribirlas: salen de las exclusiones que escribe Edgar.)
  const PROHIBIDAS = /\$|\b\d{1,3}(,\d{3})+\b|\bpercent\b|%|\bArticle\s+\d|\bNEC\b|\bNFPA\b|\bSection\s+9\b|\bStatute\b|\{\{/i;
  const PROHIBIDAS_DIRECTO = /\$|\{\{/;
  function validarSalida(L, S) {
    const rojos = [], amarillos = [];
    const rx = S && S.directo ? PROHIBIDAS_DIRECTO : PROHIBIDAS;
    const mira = (clave, obj) => {
      if (!obj || !obj.en) return;
      if (rx.test(obj.en)) rojos.push({ clave, texto: S && S.directo ? `En «${obj.en.slice(0, 50)}» hay un $ o una marca que no puede ir en el contrato.`
                                                                  : "El asistente escribió algo que no puede escribir. Se descarta y se vuelve a redactar solo esto." });
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
    // v3.7 (tanda 1): las exclusiones también se cuentan (una que sobre o falte cambia el contrato)
    if ((S.no_incluye || []).length !== (L.no_incluye || []).length)
      rojos.push({ clave: "no_incluye", texto: `Devolvió ${(S.no_incluye||[]).length} exclusiones y en tu hoja hay ${(L.no_incluye || []).length}. Se descarta.` });
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

  const ORDEN_9 = ["garantia","existentes","ahj_upgrades","panel_sin_fotos","afci","sitio","reuso_240","reubicar",
                   "isla","edicion","aberturas","fixtures_cliente","fixtures_mxp","subsuelo",
                   "planos_permiso","propias","cambios","retainage","nto_releases","limite","seguro",
                   "deposito","cancelacion_tardia","cancelacion_gc"];

  // El número que le toca a cada cláusula de la sección 9. Las propias de la hoja ocupan
  // tantos números seguidos como sean, después de las técnicas y antes de las legales.
  function numerarClausulas(clausulas, nPropias) {
    const numero = {};
    let n = 0;
    ORDEN_9.forEach(k => {
      if (!clausulas[k]) return;
      if (k === "propias") { numero.propias = n + 1; n += Math.max(1, nPropias || 0); }
      else numero[k] = ++n;
    });
    return numero;
  }

  function aplicarClausulas(html, clausulas, nPropias) {
    // solo se numeran las cláusulas que ESTA plantilla trae: una plantilla vieja no deja saltos
    const enPlantilla = new Set((html.match(/<!--@clausula ([a-z_0-9]+)-->/g) || []).map(m => m.replace(/<!--@clausula |-->/g, "")));
    const presentes = {}; Object.keys(clausulas || {}).forEach(k => { presentes[k] = clausulas[k] && (enPlantilla.has(k) || k === "propias"); });
    const numero = numerarClausulas(presentes, nPropias);
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
      if (texto && /\bsee\s+$/i.test(antes)) texto = texto.replace(/^See /, "");   // "— see Section 3", no "see See"
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
    // v3.4: lo propio de la hoja
    h = repetirFila(h, "CLAUSULA_PROPIA", datos.propias || []);
    h = repetirFila(h, "PARRAFO_7", datos.programa || []);
    h = repetirFila(h, "PARRAFO_8", datos.pre || []);
    h = repetirFila(h, "PARRAFO_6", datos.pagos || []);
    h = repetirFila(h, "CODIGO_GRUPO", datos.codigo_grupos || []);
    const r = aplicarClausulas(h, datos.clausulas, (datos.propias || []).length);
    h = r.html;
    // Un hueco vacío se queda para que el barrido lo cante; salvo los sufijos opcionales, que vacíos se borran
    const OPCIONALES = new Set(["FIRMA_REP", "TITULO_DEPOSITO"]);
    Object.entries(datos.huecos || {}).forEach(([k, v]) => {
      if (v === null || v === undefined || (v === "" && !OPCIONALES.has(k))) return;
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
    // Ningún hueco puede quedar: el portal no edita el PDF. Los dos del
    // formulario de cancelación viven en la página que genera el portal aparte.
    const quedan = [...new Set((visible.match(/\{\{[^}]{1,45}\}\}/g) || []))];
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
    vence.setDate(vence.getDate() + leerVence(d.vence, hoy));
    // v3.5: el número de propuesta que trae la hoja manda; si no, el nombre corto sale del proyecto
    // sin el prefijo MXP-AAAA-MMDD- ni la cola aleatoria (antes salía «MXP20260909W»)
    const mNum = String(d.numero_propuesta || "").trim().match(/^MXP-(\d{4})-(\d{4})-([A-Z0-9][A-Z0-9-]*)$/i);
    // regla B5 del revisor: MXP-AAAA-MMDD-CLIENTE, con el apellido (persona) o la primera palabra (empresa); nunca el id interno
    const esEmpresa = t => /\b(llc|inc|corp|co\.|company|construction|renovation|renovations|services|builders?|group|contracting|design|homes)\b/i.test(t);
    const corto = t => { const pal = String(t || "").replace(/[(),.]/g, " ").trim().split(/\s+/).filter(Boolean); if (!pal.length) return "";
      return (esEmpresa(t) ? pal[0] : pal[pal.length - 1]).toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 12); };
    const baseNombre = (dec.esGC && dec.duenoEfectivo) || d.cliente || d.proyecto || "SOW";
    const nombreCorto = mNum ? mNum[3].toUpperCase() : (corto(baseNombre) || "SOW");

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
    // v3.4: las fases tal como las diga la hoja ("(1) …; and (2) …") o Edgar ("rough / trim")
    const fases = partirFases((S.lista_de_fases && S.lista_de_fases.en) || (C.fases || {}).valor || "").length
      ? partirFases((S.lista_de_fases && S.lista_de_fases.en) || (C.fases || {}).valor || "") : (dec.fases || []);
    const finObra = /trim/i.test(String((C.fases || {}).valor || "")) ? "completion of the trim-out"
                                                                     : "completion of the work";
    const dueno = dec.duenoEfectivo || "";
    const huecos = {
      CLIENT: dec.clienteEfectivo || d.cliente || "", CLIENT_2: d.segundo_firmante || (dec.esGC ? dueno : ""),
      // con contratista: su contacto de siempre y el coordinador de esta obra, los dos ("Roberto Prata / Kevin Haseney")
      CONTACTOS: juntarNombres(d.gc_contacto, d.atencion),
      HOMEOWNER: dec.esGC ? (dueno || "the property owner") : (d.cliente || ""),
      ETIQUETA_FIRMA_2: "Client Signature",
      FIRMA_REP: dec.esGC ? " (Authorized Representative)" : "",
      // v3.6: la jurisdicción tal cual en la cabecera; la forma corta en la prosa
      JURISDICCION: d.ciudad || admin.ciudad || "",
      // v3.6: las letras de la cláusula del depósito van seguidas (la (c) del consumidor solo si es consumidor)
      L_D: dec.bloques.CONSUMIDOR ? "d" : "c", L_E: dec.bloques.CONSUMIDOR ? "e" : "d",
      L_F: dec.bloques.CONSUMIDOR ? "f" : "e", L_G: dec.bloques.CONSUMIDOR ? "g" : "f",
      TITULO_DEPOSITO: dec.bloques.PERMISO_MXP ? ", permits" : "",
      PROYECTO_EN_INGLES: (S.proyecto_en && S.proyecto_en.en) || d.proyecto || "",
      DIRECCION: admin.direccion || d.direccion || "",
      CIUDAD: d.ciudad_corta || d.ciudad || admin.ciudad || "",
      FECHA: fechaLarga(hoy), AAAA: mNum ? mNum[1] : String(hoy.getFullYear()),
      MMDD: mNum ? mNum[2] : dosDig(hoy.getMonth() + 1) + dosDig(hoy.getDate()),
      NOMBRE: nombreCorto, VENCE_30_DIAS: fechaLarga(vence),
      PLANOS: (S.planos && S.planos.en) || d.planos || "",
      RESUMEN_DEL_TRABAJO: (S.resumen_del_trabajo && S.resumen_del_trabajo.en) || "",
      // v3.6 (regla B4): el primer párrafo de la sección 1 es el de la hoja tal cual; si no hay, una frase simple
      // Sin párrafo de objetivo en la hoja, la app lo arma con lo que sabe: el proyecto, la dirección, con quién se
      // contrata y los renglones del §2 (Edgar, 10-sep: «la sección uno se refiere a todo menos a los objetivos»)
      OVERVIEW: d.overview || (() => {
        const proy = String(d.proyecto || "").split(/\s+[—–]\s+/)[0].trim();
        const que = proy ? `the ${proy}` : "this project";
        const donde = admin.direccion || d.direccion || "the Property";
        const conQuien = dec.esGC && dec.gcNombre ? `, performed by Max Power as electrical subcontractor to ${dec.gcNombre}`
                       : (dec.clienteEfectivo || d.cliente) ? ` for ${dec.clienteEfectivo || d.cliente}` : "";
        // los renglones de trabajo; los de responsabilidad («Furnished by Owner / Contractor») van en una frase aparte
        const esResp = t => /^(furnished|provided|supplied|materials?|equipment) (by|furnished|provided)/i.test(t) || /\bfurnished by\b/i.test(t);
        const trabajo = L.items.filter(it => !esResp(it.titulo)).map(it => minus(it.titulo.replace(/[.:]$/, "").trim()));
        const resp = L.items.filter(it => esResp(it.titulo));
        const lista = trabajo.length <= 1 ? trabajo.join("") : trabajo.slice(0, -1).join(", ") + " and " + trabajo[trabajo.length - 1];
        const nums = resp.map(it => "2." + it.n);
        const secs = nums.length <= 1 ? nums.join("") : nums.slice(0, -1).join(", ") + " and " + nums[nums.length - 1];
        const nota = resp.length ? ` Items ${resp.map(it => it.titulo.replace(/[.:]$/, "").trim().replace(/^[A-Z]/, c => c.toLowerCase())).join(" and ")} are stated in ${nums.length > 1 ? "Sections" : "Section"} ${secs}.` : "";
        return `This Scope of Work covers the electrical work for ${que} at ${donde}${conQuien}${lista ? ": " + lista : ", as described in Section 2"}.${nota}`;
      })(),
      QUE_HAY_HOY: (S.que_hay_hoy && S.que_hay_hoy.en) || "",
      QUE_CAMBIA: (S.que_cambia && S.que_cambia.en) || "",
      QUE_FALTABA: (S.que_faltaba && S.que_faltaba.en) || "",
      LOAD_CALC_Y_PLANOS: (S.load_calc_y_planos && S.load_calc_y_planos.en) || "",
      N_CIERRE: String(L.items.length + 1 + cta.addons.filter((a, k) =>
        (S.opciones || [])[k] && S.opciones[k].descripcion && S.opciones[k].descripcion.en).length),
      CUALES: (S.cuales_fixtures && S.cuales_fixtures.en) || "",
      // Si Edgar no marcó Áreas / No tocamos / Listo / Fases / Acceso, van los textos
      // de siempre: la plantilla no puede quedar con huecos.
      AREAS_INCLUIDAS: (S.areas_incluidas && S.areas_incluidas.en) || "the areas",
      LO_QUE_NO_TOCAS: (S.lo_que_no_tocas && S.lo_que_no_tocas.en) || "any room, structure or equipment not listed there",
      // un número entero es un artículo (Article 210); con punto es una sección (Section 680.22)
      ARTICULOS_NEC_QUE_APLICAN: (admin.nec || L.codigo).map(a => (/\./.test(a) ? "Section " : "Article ") + a).join(", "),
      RESUMEN_CORRIDO_DE_TODO_EL_ALCANCE: (S.resumen_corrido && S.resumen_corrido.en) || "",
      TOTAL: dinero(cta.base),
      N_ULTIMO: String(nHitos), FIN_OBRA: finObra,
      QUE_TIENE_QUE_ESTAR_LISTO: (S.que_tiene_que_estar_listo && S.que_tiene_que_estar_listo.en) || "the work areas are accessible and ready for electrical rough-in",
      N_FASES: String(fases.length || 2),
      LISTA_INSPECCIONES: fases.some(f => /underground|bonding|trench|slab/i.test(f)) ? "underground, bonding, rough-in and final" : "rough-in and final",
      LISTA_DE_FASES: fases.length ? (fases.length > 2 || fases.some(f => f.includes(","))
        ? fases.map((f, k) => `(${k + 1}) ${f}`).join("; ").replace(/; (\(\d+\) [^;]+)$/, "; and $1")
        : fases.join(" and ")) : "rough-in and trim-out",
      UTILITY: (S.utility && S.utility.quien && S.utility.quien.en) || "",
      QUE_HACE: (S.utility && S.utility.que_hace && S.utility.que_hace.en) || "",
      ACCESO: (S.acceso && S.acceso.en) || (dec.perfil && dec.perfil.exteriorServicio && !dec.perfil.venueExterior
        ? "access to the pole, the equipment locations and the existing raceways"
        : dec.perfil && !dec.perfil.interior
          ? "access to the work areas, the trench routes and the equipment locations"
          : "access to the attic, crawl space and wall cavities from the accessible side"),
      EQUIPO_240: equipoEn("v240"), ITEM_240: renglon("v240"), CALIBRE: calibre(),
      EQUIPO_REUBICAR: equipoEn("reubicar"), ITEM_REUBICAR: renglon("reubicar"),
      ITEM_ISLA: renglon("isla"), ITEMS_ABRIR: renglon("abrir"),
      ABERTURAS: (S.aberturas && S.aberturas.en) || "",
      FIXTURES: (S.fixtures_mxp && S.fixtures_mxp.en) || "",
      M_DEPOSITO: cta.montos.length ? dinero(cta.montos[0]) : "",
      PCT_DEPOSITO: cta.pct_deposito === null ? "" : String(cta.pct_deposito),
      // Un PDF no se puede editar por dentro: el portal NO puede escribir en el
      // contrato qué eligió el cliente. Así que el cuerpo remite al certificado
      // que el portal añade al firmar, y ahí va el precio de verdad.
      // Sin añadidos no hay nada que elegir: el precio aceptado es el de la propuesta.
      OPCION_ACEPTADA: cta.addons.length ? "as selected by the Client in the signing portal"
                                         : "Base scope as described in Sections 1\u20134 (no optional add-ons)",
      TOTAL_ACEPTADO: cta.addons.length ? "the amount stated on the Acceptance Certificate attached to this document"
                                        : "$" + dinero(cta.base)
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

    // ── v3.4: lo propio de la hoja, numerado como queda en el contrato ──
    const propio = dec.propio || clasificarPropias(L);
    const numero = numerarClausulas(dec.clausulas, propio.propias.length);
    const base7 = (dec.bloques.UTILITY ? 6 : 5) + (dec.bloques.FLOOD ? 1 : 0);
    huecos.N_FLOOD = String(dec.bloques.UTILITY ? 7 : 6);
    {
      const F = L.flood || {};
      const ecV = d.flood_ec || F.ec, bfeV = d.flood_bfe || F.bfe, lagV = d.flood_lag || F.lag;
      const ec = ecV ? ` dated ${ecV}` : "";
      const detalles = [dec.zona ? `Zone ${dec.zona}` : "", bfeV ? `BFE ${bfeV}` : ""].filter(Boolean).join(", ")
        + (lagV ? `; lowest adjacent grade ${lagV}` : "");
      huecos.FLOOD_BASE = `Pricing is based on the Base Flood Elevation shown on the FEMA Elevation Certificate for the Property${ec}${detalles ? " (" + detalles + ")" : " furnished by the Client"}.`;
    }
    // v3.5: los renglones de la hoja con su numeración propia (2.3 / 3.2) → su número en el contrato (2.n)
    const mapaItems = {};
    L.items.forEach(it => { if (it.escrito !== null && it.escrito !== undefined) {
      mapaItems[(it.serie ? it.serie + "." : "") + it.escrito] = "2." + it.n;
      if (!it.serie) mapaItems["2." + it.escrito] = "2." + it.n; } });
    const traducir = n => {
      const s = String(n);
      if (mapaItems[s]) return mapaItems[s];
      if (/^[1-6]$/.test(s) || /^[2-6]\.\d+$/.test(s)) return s;            // secciones que no cambian
      const m = propio.mapa[s];
      if (s === "8") return dec.bloques.PRE_PROPIO || dec.bloques.LAYOUT ? "8" : null;
      if (s === "7") return "7";
      if (!m) return null;
      if (m.clave === "flood" || m.fija7 === "flood") return dec.bloques.FLOOD ? "7." + huecos.N_FLOOD : null;
      if (m.clave === "validez") return null;
      if (m.clave) { const k = m.clave === "cancelacion" ? (dec.clausulas.cancelacion_gc ? "cancelacion_gc" : "cancelacion_tardia") : m.clave;
                     return numero[k] ? "9." + numero[k] : null; }
      if (m.propia !== undefined) return "9." + (numero.propias + m.propia);
      if (m.fija7) return m.fija7 === "7.6" && !dec.bloques.UTILITY ? null : m.fija7;
      if (m.extra7 !== undefined) return "7." + (base7 + 1 + m.extra7);
      return null;
    };
    const refs = t => renumerarRefs(t, traducir);
    items.forEach(it => { it.TITULO = refs(it.TITULO); it.DESCRIPCION = refs(it.DESCRIPCION); });
    no_incluye.forEach(x => { x.TITULO_EXCL = refs(x.TITULO_EXCL); x.TEXTO_EXCL = refs(x.TEXTO_EXCL); });
    ["QUE_HAY_HOY", "QUE_CAMBIA", "QUE_FALTABA", "RESUMEN_DEL_TRABAJO", "LO_QUE_NO_TOCAS", "QUE_TIENE_QUE_ESTAR_LISTO", "OVERVIEW"]
      .forEach(k => { huecos[k] = refs(huecos[k]); });
    // "Basis of information": la frase de entrada solo si la hoja no la trae, y la remisión a 9.x con número
    if (huecos.QUE_FALTABA) {
      if (!/^this proposal is prepared/i.test(huecos.QUE_FALTABA))
        huecos.QUE_FALTABA = "This proposal is prepared from the on-site walkthrough and the direction provided by the Client. " + huecos.QUE_FALTABA;
      if (!/see section/i.test(huecos.QUE_FALTABA) && numero.existentes)
        huecos.QUE_FALTABA = huecos.QUE_FALTABA.replace(/\.?$/, "") + " \u2014 see Section 9." + numero.existentes + ".";
    }
    // v3.7: el texto de una cláusula empieza con mayúscula («Sequence: hardscape demolition…» → «Hardscape demolition…»)
    const mayus = t => String(t || "").replace(/^([a-z])/, c => c.toUpperCase());
    const propias = propio.propias.map((p, k) => ({ NUM: "9." + (numero.propias + k), TITULO: refs(p.titulo), TEXTO: mayus(refs(p.texto)) }));
    const programa = propio.programa.map((p, k) => ({ NUM: "7." + (base7 + 1 + k), TITULO: refs(p.titulo), TEXTO: mayus(refs(p.texto)) }));
    const pre = propio.pre.map((p, k) => ({ NUM: "8." + (k + 1), TITULO: refs(p.titulo), TEXTO: mayus(refs(p.texto)) }));
    const pagos = (L.pagos_propios || []).map(p => ({ TITULO: refs(p.titulo), TEXTO: mayus(refs(p.texto)) }));
    // v3.5: la sección 4 como la trae la hoja: por grupos, con sus artículos y sus notas
    const codigo_grupos = (L.codigo_detalle || []).map(g => {
      const arts = g.articulos.length ? "NEC " + unir(g.articulos) : "";
      const notas = g.otros.map(o => o.replace(/\s+$/, "").replace(/([^.!?])$/, "$1.")).join(" ");
      return { GRUPO: g.grupo || "Applicable articles", ARTICULOS: [arts ? arts + "." : "", notas].filter(Boolean).join(" ") };
    }).filter(g => g.ARTICULOS);
    huecos.TITULO_8 = dec.bloques.PRE_PROPIO ? (L.pre_titulo || "Pre-Construction Verification \u2014 Mandatory Before Work Begins") : "";
    huecos.INTRO_8 = dec.bloques.PRE_PROPIO ? refs(L.pre_intro || "This requirement is mandatory and non-negotiable.") : "";

    const montosPermitidos = [dinero(cta.base), ...cta.addons.map(a => dinero(a.centavos)),
                              ...cta.hitos.map(h => dinero(h.centavos))];
    return { cuenta: cta, decision: dec, huecos, items, no_incluye, addons, hitos, montosPermitidos,
             propias, programa, pre, pagos, numero, codigo_grupos,
             archivo: `MXP-${huecos.AAAA}-${huecos.MMDD}-${nombreCorto}.html` };
  }

  // ------------------------------------------------------------------ export

  // ============================================================ v3.7 · EL JUEZ Y LAS PISTAS (tanda 1 del pliego del lector con IA)
  // Todo lo de aquí es puro: sin red, sin llaves, probado en Node. La IA (cuando llegue, tanda 2) devuelve una
  // «lectura» (qué es cada línea, con número y cita literal); la app la COMPRUEBA (verificarLectura), la convierte
  // en pistas (pistasDe) y leerAlcance las consume. Sin pistas, leerAlcance es idéntico al de siempre.

  // ---- El dinero se tapa con UNA regla (esta cadena se copia letra por letra en el cerebro) ----
  const RX_DINERO_TAPAR = "\\$\\s?\\d[\\d,]*(?:\\.\\d{1,2})?|\\b(?:dollars|usd|d[oó]lares)\\b\\s*\\d[\\d,]*(?:\\.\\d+)?|\\d[\\d,]*(?:\\.\\d+)?\\s*\\b(?:dollars|usd|d[oó]lares)\\b|\\d{1,3}(?:,\\d{3})+(?:\\.\\d{2})?|\\d+\\.\\d{2}";
  // Un candidato es dinero salvo por su contexto: 250.24(C), #2/0, 12/2, 1.5 %, 210.8 y 2.10 se quedan
  function contextoDinero(s, ini, fin) {
    const t = s.slice(ini, fin), antes = s.slice(0, ini), despues = s.slice(fin);
    if (/^\$/.test(t) || /dollars|usd|d[oó]lares/i.test(t)) return true;
    if (/[\d.#\/\-]$/.test(antes)) return false;
    if (/^[)%\d(]/.test(despues) || /^\.\d/.test(despues) || /^\s*%/.test(despues)) return false;
    return true;
  }
  function tramosDinero(s) {
    const rx = new RegExp(RX_DINERO_TAPAR, "gi"), out = []; let m;
    while ((m = rx.exec(s))) { if (contextoDinero(s, m.index, m.index + m[0].length)) out.push([m.index, m.index + m[0].length]); }
    return out;
  }
  const esMontoTapable = s => tramosDinero(String(s || "")).length > 0;
  const taparTramo = t => t.replace(/\d/g, "#");
  // Tapa el dinero de la hoja entera, conservando $ y comas y el largo. lineasDinero: números de línea que las reglas
  // ya saben que son Precio / Pagos / Opciones: ahí se tapa además todo número de tres cifras o con decimales (no los %).
  function taparDinero(texto, lineasDinero) {
    const set = new Set(lineasDinero || []);
    let tapados = 0;
    const lineas = String(texto || "").replace(/\r/g, "").split("\n").map((l, i) => {
      let s = l;
      const tramos = tramosDinero(s);
      for (let k = tramos.length - 1; k >= 0; k--) { const [a, b] = tramos[k]; s = s.slice(0, a) + taparTramo(s.slice(a, b)) + s.slice(b); tapados++; }
      if (set.has(i + 1)) s = s.replace(/\d[\d,]*(?:\.\d+)?/g, (n, off) => {
        if (/^\s*%/.test(s.slice(off + n.length)) || /[#$]$/.test(s.slice(0, off))) return n;
        if (n.replace(/\D/g, "").length >= 3 || /\./.test(n)) { tapados++; return taparTramo(n); }
        return n;
      });
      return s;
    });
    return { texto: lineas.join("\n"), tapados };
  }
  // Lo que el modelo escribe (motivos) pasa la MISMA regla estricta; si hay dinero, la lectura entera se tira
  const traeDineroEstricto = s => tramosDinero(String(s || "")).some(([a, b]) => /^\$|\d{1,3}(?:,\d{3})+|dollars|usd|d[oó]lares/i.test(String(s).slice(a, b)));

  // ---- Una sola limpieza, con tabla de posiciones (lo que ve el modelo ↔ la línea original) ----
  function limpiarLinea(cruda) {
    const src = String(cruda || ""), out = [], mapa = [];
    for (let i = 0; i < src.length; i++) {
      const c = src[i], d = src[i + 1];
      if ((c === "*" && d === "*") || (c === "_" && d === "_")) { i++; continue; }
      if (c === "`") continue;
      let r = c;
      if (c === "“" || c === "”" || c === "„") r = "\"";
      else if (c === "‘" || c === "’") r = "'";
      else if (c === "—" || c === "–") r = "-";
      else if (/\s/.test(c)) r = " ";
      if (r === " " && (out.length === 0 || out[out.length - 1] === " ")) continue;
      out.push(r); mapa.push(i);
    }
    while (out.length && out[out.length - 1] === " ") { out.pop(); mapa.pop(); }
    return { limpia: out.join(""), mapa };
  }
  // La hoja como la ve el modelo: cada línea limpia y tapada, numerada desde 1
  function hojaParaElLector(texto, L) {
    const dineroEn = new Set();
    if (L) {
      if (L.precio && L.precio.linea) dineroEn.add(L.precio.linea);
      ((L.pagos || {}).lineas || []).forEach(n => dineroEn.add(n));
      (L.opciones || []).forEach(o => { if (o.linea) dineroEn.add(o.linea); });
    }
    const tapada = taparDinero(texto, [...dineroEn]);
    const originales = String(texto || "").replace(/\r/g, "").split("\n");
    // t = lo que ve el modelo (limpia y tapada); tapada = la línea tapada sin limpiar; original = la línea de Edgar tal cual
    // (el juez mira el dinero de verdad en la original: la tapada no tiene cifras)
    const lineas = tapada.texto.split("\n").map((l, i) => { const c = limpiarLinea(l); return { n: i + 1, t: c.limpia, mapa: c.mapa, tapada: l, original: originales[i] !== undefined ? originales[i] : l }; });
    return { lineas, tapados: tapada.tapados };
  }

  // Lo ÚNICO que puede viajar a la nube: número y texto limpio y tapado de cada línea. Ni original ni tapada ni mapa.
  function paraLaNube(hoja) {
    return ((hoja && Array.isArray(hoja.lineas)) ? hoja.lineas : []).map(l => ({ n: l.n, t: String(l.t || "") }));
  }

  // ---- La cita tiene que ser literal (o casi: la subcadena común más larga cubre ≥ 80 %) ----
  function subcadenaComun(a, b) {
    let mejor = 0; const prev = new Array(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) { let diag = 0; for (let j = 1; j <= b.length; j++) { const tmp = prev[j]; prev[j] = a[i - 1] === b[j - 1] ? diag + 1 : 0; if (prev[j] > mejor) mejor = prev[j]; diag = tmp; } }
    return mejor;
  }
  function citaEnLinea(linea, cita) {
    if (cita === null || cita === undefined || cita === "") return { ok: true, exacta: true };
    const c = String(cita).trim(), l = String(linea || "");
    if (!c) return { ok: true, exacta: true };
    if (l.includes(c)) return { ok: true, exacta: true };
    const ci = l.toLowerCase().indexOf(c.toLowerCase());
    if (ci >= 0) return { ok: true, exacta: false, cita: l.slice(ci, ci + c.length) };
    const comun = subcadenaComun(l, c);
    return comun >= Math.ceil(c.length * 0.8) ? { ok: true, exacta: false } : { ok: false };
  }

  const MATRIZ_LEGAL = ["cliente", "dueno", "contratista", "contrato_con", "propiedad", "firma", "permiso"];
  const SECCIONES_VALIDAS = Object.keys(SECCIONES);
  const TIPOS_AVISO = ["seccion_repetida", "parrafo_repetido", "renglon_repetido", "cierre_duplicado", "remision_inexistente", "conteo_incoherente",
    "texto_de_otro_trabajo", "exclusion_contradice_alcance", "propiedad_comercial", "contrato_con_contratista", "firmante_es_empresa", "dato_pendiente",
    "condicion_en_prosa", "renglon_para_condicion", "titulo_leido_como", "linea_dudosa", "cantidad_no_numeracion", "numeracion_no_seguida",
    "dinero_fuera_de_sitio", "dos_precios", "codigo_no_nec", "clausula_ya_en_plantilla", "lengua_mezclada", "detalle_sin_renglon"];
  // ¿La app reconoce esta línea como «Clave: valor» con esa clave? (la única puerta para los datos de la matriz legal)
  function claveDeLinea(lineaLimpia) {
    const mNV = String(lineaLimpia || "").match(/^([^:]{2,42}):\s*(.*)$/);
    if (!mNV) return null;
    const celdas = String(lineaLimpia).replace(/^\||\|$/g, "").split("|").map(c => c.trim()).filter(Boolean);
    const k = buscaClave(CLAVES_DATOS, norma(mNV[1])) || buscaClave(CLAVES_COND, norma(mNV[1]));
    return k ? { clave: k, valor: mNV[2].trim(), celdas } : null;
  }
  function esSobranteConfirmada(linea) {
    const l = String(linea || "").trim();
    if (!l || l.startsWith("//") || l.startsWith(">") || l.startsWith("<!--")) return true;
    if (/^[-*_=]{3,}$/.test(l)) return true;
    if (/^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$/.test(l)) return true;
    if (MEMBRETE.test(l)) return true;
    if (/^\|.*\|$/.test(l)) { const celdas = l.replace(/^\||\|$/g, "").split("|").map(c => c.trim()).filter(Boolean); if (!celdas.length || celdas.every(c => CLAVES_IGNORAR.includes(norma(c)) || /^[-:\s]*$/.test(c))) return true; }
    return false;
  }

  // ---- El juez: la lectura del modelo se comprueba pieza a pieza; lo que no cuadra se tira, nunca todo o nada (salvo dos casos) ----
  // El juez nunca revienta: una lectura rota se rechaza entera («lectura_invalida») y la hoja se lee con las reglas
  function verificarLectura(lineas, lectura, L_reglas) {
    try { return verificarLecturaCruda(lineas, lectura, L_reglas); }
    catch (e) { return { error: "lectura_invalida", motivo: "no se pudo leer la lectura: " + String((e && e.message) || e).slice(0, 80) }; }
  }
  function verificarLecturaCruda(lineas, lectura, L_reglas) {
    const tiradas = [], degradados = [], avisos_app = [];
    lineas = Array.isArray(lineas) ? lineas : [];
    const N = lineas.length, txt = n => (lineas[n - 1] || {}).t || "";
    const lineaOk = n => Number.isInteger(n) && n >= 1 && n <= N;
    if (!lectura || typeof lectura !== "object" || Array.isArray(lectura)) return { error: "lectura_invalida", motivo: "no es un molde" };
    if (Number.isInteger(lectura.lineas_total) && lectura.lineas_total !== N) return { error: "lectura_invalida", motivo: `dice ${lectura.lineas_total} líneas y la hoja tiene ${N}` };
    const L = JSON.parse(JSON.stringify(lectura));
    // Lo que venga torcido (null dentro de una lista, un texto donde iba una lista, un número donde iba un objeto)
    // se sanea ANTES de mirar nada: cada pieza rara se tira, la lectura no se cae entera por una pieza.
    const objs = x => Array.isArray(x) ? x.filter(o => o && typeof o === "object" && !Array.isArray(o)) : [];
    const obj = x => (x && typeof x === "object" && !Array.isArray(x)) ? x : null;
    ["secciones", "datos", "renglones", "exclusiones", "opciones", "condiciones", "codigo", "parrafos", "grupos", "sobrantes", "avisos", "remisiones"].forEach(k => { L[k] = objs(L[k]); });
    L.renglones.forEach(r => { r.detalles = objs(r.detalles); });
    L.opciones.forEach(o => { o.detalles = objs(o.detalles); });
    L.precio = obj(L.precio);
    L.pagos = obj(L.pagos); if (L.pagos) { L.pagos.filas = objs(L.pagos.filas); L.pagos.propias = objs(L.pagos.propias); L.pagos.notas = objs(L.pagos.notas); }
    L.propias = obj(L.propias) || {}; ["programa", "pre", "terminos"].forEach(k => { L.propias[k] = objs(L.propias[k]); });
    L.hechos = obj(L.hechos) || {}; L.hechos.incluye = objs(L.hechos.incluye);
    L.avisos.forEach(a => { a.lineas = (Array.isArray(a.lineas) ? a.lineas : []).filter(Number.isInteger); a.propuesta = obj(a.propuesta); });
    // 7) dinero en el texto libre del modelo: la lectura entera se rechaza
    const motivos = [...L.avisos.map(a => a.motivo), ...L.sobrantes.map(s => s.porque)].filter(x => typeof x === "string");
    if (motivos.some(traeDineroEstricto)) return { error: "dinero_en_la_lectura", motivo: "el lector escribió un monto" };
    const lista = k => Array.isArray(L[k]) ? L[k] : (L[k] = []);
    const tirar = (pieza, l, causa) => { tiradas.push({ pieza, l, causa }); return false; };
    const validaLineas = (o, pieza) => {
      if (!lineaOk(o.l)) return tirar(pieza, o.l, "línea fuera de la hoja");
      if (o.l_hasta !== undefined && o.l_hasta !== null && (!lineaOk(o.l_hasta) || o.l_hasta < o.l)) { o.l_hasta = null; }
      return true;
    };
    const validaCita = (o, campo, pieza) => {
      const v = o[campo]; if (v === null || v === undefined || v === "") { o[campo] = null; return true; }
      if (typeof v !== "string" || v.length > 300) return tirar(pieza, o.l, "cita que no es texto corto");
      const r = citaEnLinea(txt(o.l), v);
      if (!r.ok) return tirar(pieza, o.l, `cita que no está en la línea: «${String(v).slice(0, 40)}»`);
      if (r.cita) o[campo] = r.cita;
      return true;
    };
    // 3) una sola casa por línea, en este orden
    const casa = new Map();
    const reclama = (l, pieza, hasta) => { for (let n = l; n <= (hasta || l); n++) { if (casa.has(n)) return false; } for (let n = l; n <= (hasta || l); n++) casa.set(n, pieza); return true; };
    L.secciones = lista("secciones").filter(s => validaLineas(s, "seccion") && SECCIONES_VALIDAS.includes(s.seccion) && validaCita(s, "titulo_cita", "seccion") && (reclama(s.l, "seccion") || tirar("seccion", s.l, "dos casas")));
    // precio: la línea tiene que tener forma de precio (un monto seguro y una palabra de precio), y no ser fila de pagos
    if (L.precio && typeof L.precio === "object") {
      const orig = (lineas[L.precio.l - 1] || {}).original || "";
      const d = hayDinero(orig);
      const formaPrecio = lineaOk(L.precio.l) && d && d.seguro && !/\d{1,3}\s*%/.test(orig)
        && (PALABRA_DINERO.test(orig) || /\b(lump sum|contract price|base price|investment)\b/i.test(orig) || !!claveDeLinea(txt(L.precio.l)));
      if (!formaPrecio || !reclama(L.precio.l, "precio")) { tirar("precio", L.precio.l, "la línea no tiene forma de precio"); L.precio = null; }
    } else L.precio = null;
    if (L.pagos && typeof L.pagos === "object") {
      L.pagos.filas = (L.pagos.filas || []).filter(f => validaLineas(f, "pago_fila") && /\d{1,3}\s*%/.test((lineas[f.l - 1] || {}).original || "") && (reclama(f.l, "pago_fila") || tirar("pago_fila", f.l, "dos casas")));
      L.pagos.propias = (L.pagos.propias || []).filter(p => validaLineas(p, "pago_propia") && validaCita(p, "cita_titulo", "pago_propia") && (reclama(p.l, "pago_propia") || tirar("pago_propia", p.l, "dos casas")));
      L.pagos.notas = (L.pagos.notas || []).filter(p => validaLineas(p, "pago_nota") && (reclama(p.l, "pago_nota") || tirar("pago_nota", p.l, "dos casas")));
      if (!L.pagos.filas.length && !L.pagos.propias.length && !L.pagos.notas.length) L.pagos = null;
    } else L.pagos = null;
    // 4) datos: los de la matriz legal solo si la app reconoce «Clave: valor»; si no, se degradan a hecho
    L.hechos = L.hechos && typeof L.hechos === "object" ? L.hechos : {};
    L.datos = lista("datos").filter(d => {
      if (!validaLineas(d, "dato") || !validaCita(d, "cita", "dato")) return false;
      if (!Object.keys(CLAVES_DATOS).includes(d.clave)) return tirar("dato", d.l, `clave desconocida ${d.clave}`);
      const rec = claveDeLinea(txt(d.l));
      if (MATRIZ_LEGAL.includes(d.clave) && !(rec && rec.clave === d.clave)) {
        degradados.push({ clave: d.clave, l: d.l, cita: d.cita });
        if (d.clave === "contratista" && !(L.hechos.contrato_con && L.hechos.contrato_con.l)) L.hechos.contrato_con = { valor: "gc", l: d.l, cita: d.cita };
        if (d.clave === "dueno" && !(L.hechos.dueno && L.hechos.dueno.l)) L.hechos.dueno = { l: d.l, cita: d.cita };
        if (d.clave === "propiedad") L.hechos.propiedad = { valor: /comercial|commercial/i.test(String(d.cita || txt(d.l))) ? "comercial" : "no_se", l: d.l, cita: d.cita };
        if (d.clave === "firma") L.hechos.firma = { valor: "no_se", l: d.l, cita: d.cita };
        if (d.clave === "permiso") L.hechos.permiso = { valor: "no_se", l: d.l, cita: d.cita };
        return false;
      }
      d.pendiente = !!d.pendiente;
      return reclama(d.l, "dato") || tirar("dato", d.l, "dos casas");
    });
    L.renglones = lista("renglones").filter(r => {
      if (!validaLineas(r, "renglon") || !validaCita(r, "cita_titulo", "renglon")) return false;
      if (!reclama(r.l, "renglon", r.l_hasta)) return tirar("renglon", r.l, "dos casas");
      r.detalles = (r.detalles || []).filter(d => validaLineas(d, "detalle") && validaCita(d, "cita", "detalle") && (reclama(d.l, "detalle", d.l_hasta) || tirar("detalle", d.l, "dos casas")));
      r.grupo_l = lineaOk(r.grupo_l) ? r.grupo_l : null;
      r.cierre = !!r.cierre;
      return true;
    });
    L.exclusiones = lista("exclusiones").filter(x => validaLineas(x, "exclusion") && validaCita(x, "cita_titulo", "exclusion") && (reclama(x.l, "exclusion", x.l_hasta) || tirar("exclusion", x.l, "dos casas")));
    L.opciones = lista("opciones").filter((o, k) => {
      if (k >= 4) return tirar("opcion", o.l, "más de cuatro opciones");
      if (!validaLineas(o, "opcion")) return false;
      const orig = (lineas[o.l - 1] || {}).original || "";
      const d = hayDinero(orig);
      if (!(d && d.seguro)) return tirar("opcion", o.l, "la opción no trae un precio al final");
      if (!reclama(o.l, "opcion")) return tirar("opcion", o.l, "dos casas");
      o.detalles = (o.detalles || []).filter(x => validaLineas(x, "opcion_detalle") && validaCita(x, "cita", "opcion_detalle") && (reclama(x.l, "opcion_detalle") || tirar("opcion_detalle", x.l, "dos casas")));
      return true;
    });
    // condiciones: la explícita la calcula la app; la de prosa es referencia (pregunta), no casa
    L.condiciones = lista("condiciones").filter(c => {
      if (!validaLineas(c, "condicion") || !validaCita(c, "cita", "condicion")) return false;
      if (!Object.keys(CLAVES_COND).includes(c.clave) && c.clave !== "tipo_trabajo") return tirar("condicion", c.l, `condición desconocida ${c.clave}`);
      const rec = claveDeLinea(txt(c.l));
      c.explicita = !!(rec && rec.clave === c.clave);
      if (c.explicita && !reclama(c.l, "condicion")) return tirar("condicion", c.l, "dos casas");
      return true;
    });
    L.codigo = lista("codigo").filter(c => validaLineas(c, "codigo") && (reclama(c.l, "codigo") || tirar("codigo", c.l, "dos casas")));
    L.propias = L.propias && typeof L.propias === "object" ? L.propias : {};
    ["programa", "pre", "terminos"].forEach(k => {
      L.propias[k] = (Array.isArray(L.propias[k]) ? L.propias[k] : []).filter(p => validaLineas(p, "propia") && validaCita(p, "cita_titulo", "propia") && (reclama(p.l, "propia", p.l_hasta) || tirar("propia", p.l, "dos casas")));
    });
    L.parrafos = lista("parrafos").filter(p => validaLineas(p, "parrafo") && ["hoy", "cambia", "falta", "notas", "resumen", "pre_intro"].includes(p.destino) && validaCita(p, "cita", "parrafo") && (reclama(p.l, "parrafo", p.l_hasta) || tirar("parrafo", p.l, "dos casas")));
    L.grupos = lista("grupos").filter(g => validaLineas(g, "grupo") && validaCita(g, "cita", "grupo") && (reclama(g.l, "grupo") || tirar("grupo", g.l, "dos casas")));
    // 6) sobrantes: solo se callan las que la app confirma; las demás, ámbar y se conservan
    L.sobrantes = lista("sobrantes").filter(s => {
      if (!validaLineas(s, "sobrante")) return false;
      const hasta = s.l_hasta || s.l;
      for (let n = s.l; n <= hasta; n++) {
        if (casa.has(n)) continue;
        if (esSobranteConfirmada((lineas[n - 1] || {}).original)) { casa.set(n, "sobrante"); continue; }
        avisos_app.push({ tipo: "sobrante_no_confirmada", l: n, texto: txt(n), porque: s.porque || "no_se" });
      }
      return true;
    });
    // 6 bis) candado 14 «nada desaparece en silencio»: lo que las reglas leen como renglón, detalle, exclusión u opción
    // tiene que seguir siéndolo en la lectura. Si el lector lo puso en otro sitio (un párrafo de notas, una cláusula,
    // un dato…) o en ninguno, mandan las reglas: la pieza ajena se quita, la línea vuelve a su papel y sale en ámbar.
    if (L_reglas && typeof L_reglas === "object" && !Array.isArray(L_reglas)) {
      const esperado = [];
      objs(L_reglas.items).forEach(it => { const ls = Array.isArray(it.lineas) ? it.lineas : []; if (lineaOk(ls[0])) { esperado.push([ls[0], "renglon", ls[0]]); ls.slice(1).forEach(l => { if (lineaOk(l)) esperado.push([l, "detalle", ls[0]]); }); } });
      objs(L_reglas.no_incluye).forEach(x => { if (lineaOk(x.linea)) esperado.push([x.linea, "exclusion", null]); });
      objs(L_reglas.opciones).forEach(o => { if (lineaOk(o.linea)) esperado.push([o.linea, "opcion", null]); });
      const ACEPTA = { renglon: ["renglon", "detalle", "grupo", "exclusion", "opcion", "opcion_detalle"], detalle: ["detalle", "renglon", "grupo", "exclusion", "opcion", "opcion_detalle"],
                       exclusion: ["exclusion", "renglon", "detalle", "opcion", "opcion_detalle"], opcion: ["opcion", "opcion_detalle", "renglon", "exclusion"] };
      const fuera = n => o => !(o && (o.l === n || (Number.isInteger(o.l_hasta) && o.l <= n && n <= o.l_hasta)));
      const desalojar = n => {
        ["datos", "condiciones", "codigo", "parrafos", "grupos", "sobrantes"].forEach(k => { L[k] = L[k].filter(fuera(n)); });
        ["programa", "pre", "terminos"].forEach(k => { L.propias[k] = L.propias[k].filter(fuera(n)); });
        if (L.pagos) { L.pagos.notas = L.pagos.notas.filter(fuera(n)); L.pagos.propias = L.pagos.propias.filter(fuera(n)); }
        L.renglones.forEach(r => { r.detalles = r.detalles.filter(fuera(n)); });
        L.opciones.forEach(o => { o.detalles = o.detalles.filter(fuera(n)); });
        casa.delete(n);
      };
      esperado.forEach(([n, papel, titulo]) => {
        const tiene = casa.get(n);
        if (tiene && ACEPTA[papel].includes(tiene)) return;
        if (avisos_app.some(a => a.tipo === "sobrante_no_confirmada" && a.l === n)) return;   // ya está en ámbar por sobrante
        // un detalle cuyo título quedó sin casa (sobrante en ámbar, o sin pista) se queda sin casa también: las reglas
        // leen título y detalles juntos, y el aviso del título ya lo cubre
        if (papel === "detalle" && !casa.has(titulo)) return;
        desalojar(n);
        if (papel === "detalle") {
          const r = L.renglones.find(x => x.l === titulo);
          if (r) r.detalles.push({ l: n, cita: null, de_reglas: true });
          else L.renglones.push({ l: n, cita_titulo: null, detalles: [], grupo_l: null, cierre: false, de_reglas: true });
        }
        else if (papel === "renglon") L.renglones.push({ l: n, cita_titulo: null, detalles: [], grupo_l: null, cierre: false, de_reglas: true });
        else if (papel === "exclusion") L.exclusiones.push({ l: n, cita_titulo: null, de_reglas: true });
        else L.opciones.push({ l: n, detalles: [], de_reglas: true });
        casa.set(n, papel);
        avisos_app.push({ tipo: "renglon_movido", l: n, texto: txt(n), papel, puesto: tiene || "ninguna" });
      });
    }
    // cobertura: toda línea con contenido tiene casa; las que no, sin_casa (las lee la regla y se pregunta)
    const sin_casa = [];
    for (let n = 1; n <= N; n++) { if (!casa.has(n) && !esSobranteConfirmada((lineas[n - 1] || {}).original)) sin_casa.push(n); }
    // 8) conteos
    L.renglones.sort((a, b) => a.l - b.l).forEach((r, k) => { r.orden = k + 1; });
    L.exclusiones.sort((a, b) => a.l - b.l).forEach((x, k) => { x.orden = k + 1; });
    // 10) hechos: sin línea y cita verificadas, no_se
    const HECHOS = ["contrato_con", "propiedad", "tipo_trabajo", "firma", "permiso"];
    HECHOS.forEach(k => {
      const h = L.hechos[k];
      if (!h || typeof h !== "object") { L.hechos[k] = { valor: "no_se", l: null, cita: null }; return; }
      if (h.valor && h.valor !== "no_se") { if (!lineaOk(h.l) || !citaEnLinea(txt(h.l), h.cita).ok) { h.valor = "no_se"; h.l = null; h.cita = null; } }
    });
    ["dueno", "segundo_firmante"].forEach(k => { const h = L.hechos[k]; if (!h || !lineaOk(h.l) || !citaEnLinea(txt(h.l), h.cita).ok) L.hechos[k] = { l: null, cita: null }; });
    L.hechos.incluye = (Array.isArray(L.hechos.incluye) ? L.hechos.incluye : []).filter(x => lineaOk(x.l) && citaEnLinea(txt(x.l), x.cita).ok);
    // 11) avisos: tipos de la lista, líneas reales, valor_cita verificada, motivo corto; como mucho 12
    // el tope va ANTES de cotejar citas (una lectura con cien avisos no puede costar segundos en el teléfono)
    L.avisos = lista("avisos").slice(0, 24).filter(a => {
      if (!TIPOS_AVISO.includes(a.tipo)) return tirar("aviso", null, `tipo desconocido ${a.tipo}`);
      a.lineas = (Array.isArray(a.lineas) ? a.lineas : []).filter(lineaOk).slice(0, 20);
      if (!a.lineas.length) return tirar("aviso", null, `${a.tipo} sin líneas`);
      a.motivo = String(a.motivo || "").slice(0, 200);
      a.certeza = a.certeza === "segura" ? "segura" : "probable";
      if (a.cita !== undefined && a.cita !== null && (typeof a.cita !== "string" || a.cita.length > 300)) return tirar("aviso", a.lineas[0], "cita del aviso que no es texto corto");
      if (a.cita && !a.lineas.some(l => citaEnLinea(txt(l), a.cita).ok)) return tirar("aviso", a.lineas[0], "cita del aviso que no está");
      if (a.propuesta && typeof a.propuesta === "object") {
        const pr = a.propuesta;
        // la clave de una propuesta tiene que ser una clave de verdad (no «constructor» ni cosas raras)
        if (pr.clave !== undefined && pr.clave !== null && !(typeof pr.clave === "string" && /^[a-z_0-9]{1,40}$/.test(pr.clave))) a.propuesta = null;
        else if (pr.accion === "poner_condicion" && !(pr.clave && Object.prototype.hasOwnProperty.call(CLAVES_COND, pr.clave))) a.propuesta = null;
        else if (pr.accion === "poner_dato" && !(pr.clave && Object.prototype.hasOwnProperty.call(CLAVES_DATOS, pr.clave))) a.propuesta = null;
        else if (pr.valor_cita !== undefined && pr.valor_cita !== null && (typeof pr.valor_cita !== "string" || pr.valor_cita.length > 300)) a.propuesta = null;
        else if (pr.valor_cita && !(lineaOk(pr.valor_l) && citaEnLinea(txt(pr.valor_l), pr.valor_cita).ok)) a.propuesta = null;
      } else a.propuesta = null;
      return true;
    }).slice(0, 12);
    L.remisiones = lista("remisiones").filter(r => validaLineas(r, "remision") && citaEnLinea(txt(r.l), r.cita).ok);
    return { lectura_limpia: L, tiradas, sin_casa, degradados, avisos_app };
  }

  // ---- De la lectura comprobada a una pista por línea ----
  const SEC_DE_ROL = { dato: "datos", grupo: "alcance", renglon_titulo: "alcance", renglon_detalle: "alcance", exclusion: "no_incluye",
    precio: "precio_detalle", pago_fila: "pagos_detalle", pago_propia: "pagos_detalle", pago_nota: "pagos_detalle",
    opcion: "opciones", opcion_detalle: "opciones", condicion: "condiciones", codigo: "codigo" };
  const ROLES_PISTA = new Set([...Object.keys(SEC_DE_ROL), "seccion", "continua", "sobrante", "propia", "parrafo"]);
  function pistasDe(L) {
    const P = {};
    L = (L && typeof L === "object" && !Array.isArray(L)) ? L : {};
    const A = x => Array.isArray(x) ? x.filter(o => o && typeof o === "object" && !Array.isArray(o)) : [];
    const pon = (l, p) => { if (Number.isInteger(l) && l >= 1 && !P[l]) P[l] = p; };
    // un tramo (l … l_hasta) nunca pasa de 2,000 líneas: una hoja no tiene más, y un número loco no cuelga el teléfono
    const hasta = o => (Number.isInteger(o.l_hasta) && o.l_hasta > o.l) ? Math.min(o.l_hasta, o.l + 2000) : o.l;
    const continua = (o, rol) => { if (Number.isInteger(o.l)) for (let n = o.l + 1; n <= hasta(o); n++) pon(n, { rol: "continua", de: o.l }); };
    const pr0 = (L.propias && typeof L.propias === "object") ? L.propias : {};
    L = Object.assign({}, L, { secciones: A(L.secciones), datos: A(L.datos), renglones: A(L.renglones).map(r => Object.assign({}, r, { detalles: A(r.detalles) })),
      exclusiones: A(L.exclusiones), opciones: A(L.opciones).map(o => Object.assign({}, o, { detalles: A(o.detalles) })), condiciones: A(L.condiciones), codigo: A(L.codigo),
      parrafos: A(L.parrafos), grupos: A(L.grupos), sobrantes: A(L.sobrantes),
      precio: (L.precio && typeof L.precio === "object" && Number.isInteger(L.precio.l)) ? L.precio : null,
      pagos: (L.pagos && typeof L.pagos === "object") ? { filas: A(L.pagos.filas), propias: A(L.pagos.propias), notas: A(L.pagos.notas) } : null,
      propias: { programa: A(pr0.programa), pre: A(pr0.pre), terminos: A(pr0.terminos) } });
    (L.secciones || []).forEach(s => pon(s.l, { rol: "seccion", seccion: s.seccion }));
    if (L.precio) pon(L.precio.l, { rol: "precio" });
    if (L.pagos) { (L.pagos.filas || []).forEach(f => pon(f.l, { rol: "pago_fila", orden: f.orden })); (L.pagos.propias || []).forEach(p => pon(p.l, { rol: "pago_propia", cita_titulo: p.cita_titulo })); (L.pagos.notas || []).forEach(p => pon(p.l, { rol: "pago_nota" })); }
    (L.datos || []).forEach(d => pon(d.l, { rol: "dato", clave: d.clave, cita: d.cita, pendiente: !!d.pendiente }));
    (L.renglones || []).forEach(r => { pon(r.l, { rol: "renglon_titulo", orden: r.orden, cita_titulo: r.cita_titulo, grupo_l: r.grupo_l, cierre: !!r.cierre, hasta: r.l_hasta || r.l }); continua(r); (r.detalles || []).forEach(d => { pon(d.l, { rol: "renglon_detalle", orden: r.orden, de: r.l, cita: d.cita }); continua(d); }); });
    (L.exclusiones || []).forEach(x => { pon(x.l, { rol: "exclusion", orden: x.orden, cita_titulo: x.cita_titulo }); continua(x); });
    (L.opciones || []).forEach(o => { pon(o.l, { rol: "opcion", orden: o.orden }); (o.detalles || []).forEach(d => pon(d.l, { rol: "opcion_detalle", orden: o.orden })); });
    (L.condiciones || []).forEach(c => { if (c.explicita) pon(c.l, { rol: "condicion", clave: c.clave }); });
    (L.codigo || []).forEach(c => pon(c.l, { rol: "codigo" }));
    const pr = L.propias || {};
    ["programa", "pre", "terminos"].forEach(k => (pr[k] || []).forEach(p => { pon(p.l, { rol: "propia", seccion: k, cita_titulo: p.cita_titulo }); continua(p); }));
    (L.parrafos || []).forEach(p => { pon(p.l, { rol: "parrafo", destino: p.destino, cita: p.cita }); continua(p); });
    (L.grupos || []).forEach(g => pon(g.l, { rol: "grupo", cita: g.cita }));
    (L.sobrantes || []).forEach(s => { if (!Number.isInteger(s.l)) return; for (let n = s.l; n <= hasta(s); n++) pon(n, { rol: "sobrante", porque: s.porque }); });
    return P;
  }
  // Las pistas viven pegadas al TEXTO de la línea, no a su número: al tocar un botón que escribe en la hoja se realinean
  function guardarPistas(texto, pistas) {
    return String(texto || "").replace(/\r/g, "").split("\n").map((l, i) => ({ texto: limpiarLinea(l).limpia, pista: pistas[i + 1] || null }));
  }
  function alinearLectura(textoNuevo, guardadas) {
    guardadas = Array.isArray(guardadas) ? guardadas.filter(g => g && typeof g === "object") : [];
    const usadas = new Set(), pistas = {}, huerfanas = [];
    const lineas = String(textoNuevo || "").replace(/\r/g, "").split("\n");
    let perdidas = 0, con = 0;
    lineas.forEach((l, i) => {
      const t = limpiarLinea(l).limpia; if (!t) return;
      let k = guardadas.findIndex((g, j) => !usadas.has(j) && g.texto === t);
      if (k < 0) k = guardadas.findIndex((g, j) => !usadas.has(j) && g.texto && norma(g.texto) === norma(t));
      if (k >= 0) { usadas.add(k); if (guardadas[k].pista) { pistas[i + 1] = guardadas[k].pista; con++; } }
      else if (!claveDeLinea(t) && !esSobranteConfirmada(l)) huerfanas.push(i + 1);
    });
    guardadas.forEach((g, j) => { if (g.pista && !usadas.has(j)) perdidas++; });
    const total = guardadas.filter(g => g.pista).length || 1;
    return { pistas, huerfanas, perdidas, proporcionPerdida: perdidas / total };
  }

  // ---- Cuánto de rara viene una hoja (para decidir si vale la pena pedir la lectura inteligente) ----
  function rareza(L, V) {
    let puntos = 0; const porque = [];
    const errores = (V || validarAlcance(L)).errores || [];
    if (errores.length) { puntos += 2; porque.push(`${errores.length} rojo(s)`); }
    if ((L.ignoradas || []).length >= 2) { puntos += 1; porque.push("secciones que no reconozco"); }
    const lineasTabla = (L.lineas || []).filter(l => /^\|.*\|$/.test(String(l).trim())).length;
    if (lineasTabla >= 3 && L.items.length < 3) { puntos += 1; porque.push("tablas donde esperaba renglones"); }
    if (!L.precio && (L.lineas || []).some(l => /\$\s?\d/.test(l))) { puntos += 1; porque.push("hay $ pero no leí el precio"); }
    if (!L.pagos && (L.lineas || []).some(l => /\bdeposit\b/i.test(l))) { puntos += 1; porque.push("habla de depósito y no leí los pagos"); }
    if ((L.lineas || []).length >= 120 && L.items.length < 3) { puntos += 2; porque.push("hoja larga con pocos renglones"); }
    return { puntos, rara: puntos >= 2, porque };
  }

  // ---- Una lectura hecha con las reglas de siempre (para probar el juez sin nube, y para enseñar «Cómo leí tu hoja») ----
  function lecturaDeReglas(texto, L) {
    L = L || leerAlcance(texto);
    const lineas = String(texto || "").replace(/\r/g, "").split("\n");
    const limpia = n => limpiarLinea(lineas[n - 1] || "").limpia;
    const lect = { formato: "hoja_casa", idioma: pareceIngles(L) ? "en" : (pareceIngles(L) === null ? "mezcla" : "es"), lineas_total: lineas.length, secciones: [], datos: [], parrafos: [], grupos: [],
      renglones: [], exclusiones: [], precio: null, pagos: null, opciones: [], condiciones: [], codigo: [], jurisdiccion_l: null,
      propias: { programa: [], pre: [], terminos: [], pre_titulo_l: null }, remisiones: [], hechos: {}, avisos: [], sobrantes: [] };
    // los títulos de sección: los que el lector reconoció de verdad (con su línea), no una segunda adivinanza
    (L.titulos || []).forEach(t => lect.secciones.push({ l: t.linea, seccion: t.seccion, titulo_cita: null }));
    L.items.forEach(it => {
      const titulo = limpia(it.lineas[0]).includes(it.titulo) ? it.titulo : null;
      lect.renglones.push({ orden: it.n, l: it.lineas[0], l_hasta: null, cita_titulo: titulo, grupo_l: null,
        detalles: it.lineas.slice(1).map(l => ({ l, l_hasta: null, cita: null })), cierre: false });
    });
    L.no_incluye.forEach((x, k) => lect.exclusiones.push({ orden: k + 1, l: x.linea, l_hasta: null, cita_titulo: x.titulo && limpia(x.linea).includes(x.titulo) ? x.titulo : null, ya_en_plantilla: "ninguna" }));
    if (L.precio && L.precio.linea) lect.precio = { l: L.precio.linea };
    if (L.pagos && L.pagos.lineas && L.pagos.lineas.length) lect.pagos = { forma: L.pagos.corto ? "corta" : "filas", filas: L.pagos.corto ? [] : L.pagos.lineas.map((l, k) => ({ orden: k + 1, l })), propias: (L.pagos_propios || []).map(p => ({ l: p.linea, cita_titulo: p.titulo })), notas: [] };
    L.opciones.forEach(o => lect.opciones.push({ orden: o.n, l: o.linea, detalles: [] }));
    Object.entries(L.condiciones || {}).forEach(([k, v]) => { if (v && v.linea && !v.pescada) lect.condiciones.push({ clave: k, l: v.linea, cita: null }); });
    ["programa", "pre", "terminos"].forEach(k => (L[k] || []).forEach(p => { if (p.linea) lect.propias[k].push({ l: p.linea, l_hasta: null, numero: p.n || null, cita_titulo: limpia(p.linea).includes(p.titulo) ? p.titulo : null, parece_de_plantilla: null }); }));
    // datos de cabecera: los que el lector leyó de una línea «Clave: valor» (la cita es solo el valor, si está literal)
    Object.entries(L.datos_linea || {}).forEach(([k, l]) => {
      if (!CLAVES_DATOS[k] || !l) return;
      const rec = claveDeLinea(limpia(l));
      lect.datos.push({ clave: k, l, cita: rec && rec.valor && limpia(l).includes(rec.valor) ? rec.valor : null, pendiente: false });
    });
    lect.datos.sort((a, b) => a.l - b.l);
    return lect;
  }

  // ---- De los avisos del lector (ya pasados por el juez) a lo que ve Edgar en pantalla: ámbar o gris, con la línea y la
  // cita literal como prueba, y botones que NUNCA se aplican solos (auto: false, origen: "ia"). Aguanta una lectura
  // envenenada: lo que no cuadra (tipo raro, línea fuera de la hoja, cita que no está, dinero en el texto) se tira.
  const TEXTOS_AVISO = {
    seccion_repetida: "La hoja trae dos veces la misma sección", parrafo_repetido: "Este párrafo está repetido",
    renglon_repetido: "Este renglón parece repetido", cierre_duplicado: "Este cierre (pruebas, inspección, limpieza) ya lo trae la plantilla",
    remision_inexistente: "Esta línea remite a una cláusula que no está en la hoja", conteo_incoherente: "El número que dice no cuadra con lo que lista",
    texto_de_otro_trabajo: "Esta línea parece de otro tipo de trabajo", exclusion_contradice_alcance: "Esta exclusión choca con algo que el Alcance sí incluye",
    propiedad_comercial: "Parece una propiedad comercial", contrato_con_contratista: "Parece un contrato con un contratista",
    firmante_es_empresa: "El cliente es una empresa: hace falta saber quién firma", dato_pendiente: "Este dato parece pendiente de confirmar",
    condicion_en_prosa: "La hoja dice en prosa algo que va en Condiciones", renglon_para_condicion: "Esta condición apunta a un renglón",
    titulo_leido_como: "Este título lo leí por su sentido", linea_dudosa: "No estoy seguro de qué es esta línea",
    cantidad_no_numeracion: "Este número es una cantidad, no la numeración", numeracion_no_seguida: "La numeración no va seguida",
    dinero_fuera_de_sitio: "Hay un monto donde no van montos", dos_precios: "Hay dos precios distintos",
    codigo_no_nec: "Este código no es del NEC: va tal cual", clausula_ya_en_plantilla: "Esta cláusula parece de las que la plantilla ya trae",
    lengua_mezclada: "Esta línea está en otro idioma que el resto", detalle_sin_renglon: "Este detalle no tiene renglón encima"
  };
  function avisosDeLectura(lectura, L, avisos_app) {
    const out = [];
    if (!lectura || typeof lectura !== "object") return out;
    const hasOwn = (o, k) => typeof k === "string" && Object.prototype.hasOwnProperty.call(o, k);
    const lineas = (L && Array.isArray(L.lineas)) ? L.lineas : null;
    const N = lineas ? lineas.length : 0;
    const lineaOk = n => Number.isInteger(n) && n >= 1 && (!lineas || n <= N);
    const limpia = n => lineas ? limpiarLinea(lineas[n - 1] || "").limpia : "";
    const ia = o => Object.assign({ auto: false, origen: "ia" }, o);
    const dejar = l => ia({ tipo: "dejar_asi", etiqueta: "Déjalo así", linea: l });
    (Array.isArray(lectura.avisos) ? lectura.avisos : []).forEach(a => {
      if (!a || typeof a !== "object" || !TIPOS_AVISO.includes(a.tipo)) return;
      const ls = (Array.isArray(a.lineas) ? a.lineas : []).filter(lineaOk);
      if (!ls.length) return;
      const cita = a.cita ? String(a.cita).trim() : "";
      if (cita && lineas && !ls.some(n => citaEnLinea(limpia(n), cita).ok)) return;   // cita que no está en la línea: se tira
      const motivo = String(a.motivo || "").slice(0, 200);
      if (traeDineroEstricto(motivo) || traeDineroEstricto(cita)) return;              // el lector no escribe montos
      const l = ls[0], arreglos = [];
      const p = a.propuesta && typeof a.propuesta === "object" ? a.propuesta : null;
      if (p) {
        const vl = lineaOk(p.valor_l) ? p.valor_l : l;
        const vc = p.valor_cita ? String(p.valor_cita).trim() : "";
        const vcOk = !vc || !lineas || citaEnLinea(limpia(vl), vc).ok;
        if (p.accion === "quitar_linea") arreglos.push(ia({ tipo: "quitar_linea", etiqueta: "Quitar la línea", linea: vl }));
        else if (p.accion === "quitar_trozo" && vc && vcOk) arreglos.push(ia({ tipo: "quitar_trozo", etiqueta: `Quitar «${vc.slice(0, 30)}»`, linea: vl, valor: vc }));
        else if (p.accion === "cambiar_renglon" && Number.isInteger(p.renglon) && p.renglon >= 1) arreglos.push(ia({ tipo: "cambiar_renglon", etiqueta: `Apuntar al renglón ${p.renglon}`, linea: vl, valor: p.renglon }));
        else if (p.accion === "poner_condicion" && hasOwn(CLAVES_COND, p.clave) && vc && vcOk) arreglos.push(ia({ tipo: "cambiar_condicion", etiqueta: `Ponerlo en Condiciones (${CLAVES_COND[p.clave][0]})`, clave: p.clave, valor: vc }));
        else if (p.accion === "no_excluir" && p.clave) arreglos.push(ia({ tipo: "cambiar_condicion", etiqueta: "Quitar esa exclusión", clave: "no_excluir", valor: String(p.clave), anadir: true }));
        // «preguntar», «poner_dato» e «informar» no llevan botón de la app: la pantalla pregunta con la cita y Edgar contesta
      }
      arreglos.push(dejar(l));
      out.push({ tipo: a.tipo, nivel: a.certeza === "segura" ? "ambar" : "gris", certeza: a.certeza === "segura" ? "segura" : "probable",
                 linea: l, lineas: ls, cita: cita || null, origen: "ia", perdonable: true, motivo,
                 texto: `${TEXTOS_AVISO[a.tipo]} (línea ${l}${cita ? `: «${cita.slice(0, 80)}»` : ""}).${motivo ? " " + motivo : ""}`,
                 pregunta: p && p.accion === "preguntar" ? { clave: p.clave || null } : null, arreglos });
    });
    // lo que el lector quiso dejar fuera y la app no pudo confirmar sola: ámbar con botones, y mientras tanto se conserva
    (Array.isArray(lectura.sobrantes) ? lectura.sobrantes : []).forEach(s => {
      if (!s || !lineaOk(s.l) || !lineas) return;
      const hasta = lineaOk(s.l_hasta) && s.l_hasta >= s.l ? s.l_hasta : s.l;
      for (let n = s.l; n <= hasta; n++) {
        if (esSobranteConfirmada(lineas[n - 1])) continue;
        const t = limpia(n);
        out.push({ tipo: "sobrante_no_confirmada", nivel: "ambar", certeza: "probable", linea: n, lineas: [n], cita: t.slice(0, 80) || null, origen: "ia", perdonable: true,
                   motivo: String(s.porque || "no_se").slice(0, 40),
                   texto: `El lector quiso dejar fuera la línea ${n} «${t.slice(0, 60)}». La conservo donde las reglas la pusieron hasta que me digas qué es.`,
                   arreglos: [ia({ tipo: "es_renglon", etiqueta: "Es un renglón", linea: n }), ia({ tipo: "es_detalle_de", etiqueta: "Es detalle del renglón de arriba", linea: n }),
                              ia({ tipo: "quitar_linea", etiqueta: "Déjala fuera", linea: n }), dejar(n)] });
      }
    });
    // lo que el juez devolvió a su sitio porque el lector lo había puesto en otro (renglón, detalle, exclusión u opción)
    (Array.isArray(avisos_app) ? avisos_app : []).forEach(a => {
      if (!a || a.tipo !== "renglon_movido" || !lineaOk(a.l)) return;
      const t = lineas ? limpia(a.l) : String(a.texto || "");
      const que = ({ renglon: "un renglón del Alcance", detalle: "un detalle de un renglón", exclusion: "una exclusión", opcion: "una opción" })[a.papel] || "un renglón";
      out.push({ tipo: "renglon_movido", nivel: "ambar", certeza: "probable", linea: a.l, lineas: [a.l], cita: t.slice(0, 80) || null, origen: "ia", perdonable: true,
                 motivo: String(a.puesto || "").slice(0, 40),
                 texto: `El lector puso la línea ${a.l} «${t.slice(0, 60)}» en otro sitio (${a.puesto === "ninguna" ? "en ninguno" : a.puesto}); la dejo como ${que}, que es como la leen las reglas. Si de verdad no lo es, dímelo.`,
                 arreglos: [ia({ tipo: "quitar_linea", etiqueta: "Déjala fuera del contrato", linea: a.l }), ia({ tipo: "es_detalle_de", etiqueta: "Es detalle del renglón de arriba", linea: a.l }), dejar(a.l)] });
    });
    // primero lo ámbar, después lo gris; como mucho doce
    return out.sort((a, b) => (a.nivel === b.nivel ? 0 : a.nivel === "ambar" ? -1 : 1)).slice(0, 12);
  }

  const API = { leerAlcance, validarAlcance, cuentas, repartir, leerMonto, pareceDinero, hayDinero, pareceIngles, redactarDirecto,
                decidirInterruptores, prepararEncargo, validarSalida,
                rellenarPlantilla, aplicarSi, repetirFila, aplicarClausulas,
                barridoFinal, marcasEmparejadas, armarTodo, aplicarArreglo, arreglarTodo, leerPermiso, leerFirma, leerVence, DISPARADORES, ORDEN_9, dinero, centavos, norma,
                numerarClausulas, clasificarPropias, renumerarRefs, partirFases, juntarNombres,
                // v3.7: el juez y las pistas
                RX_DINERO_TAPAR, esMontoTapable, taparDinero, traeDineroEstricto, limpiarLinea, hojaParaElLector, citaEnLinea,
                verificarLectura, pistasDe, guardarPistas, alinearLectura, rareza, lecturaDeReglas, claveDeLinea, TIPOS_AVISO, paraLaNube,
                // tanda 1: los avisos del lector para la pantalla y las reglas nuevas
                avisosDeLectura, esSobranteConfirmada, siNo, minus, normalizarTipoTrabajo, CLAVES_COND, CLAVES_DATOS, MATRIZ_LEGAL, SEC_DE_ROL };
  if (typeof module !== "undefined" && module.exports) module.exports = API;
  raiz.Alcance = API;
})(typeof globalThis !== "undefined" ? globalThis : this);
