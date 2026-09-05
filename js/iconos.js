// ============================================================================
// ICONOS DE LÍNEA — el remate del rediseño (v96): fuera los emojis.
//
// La app pinta muchas pantallas con emojis en los botones y los títulos.
// En vez de tocar cada línea (y romper las traducciones, que van por texto),
// este observador cambia cada emoji conocido por un icono de línea SVG en el
// momento en que se pinta. Corre DESPUÉS del traductor (i18n.js), así las
// llaves del diccionario siguen casando con el texto original.
//
// Reglas: solo se cambian los emojis de la tabla; el ✓ de los avisos se
// queda como texto; dentro de <option>, <textarea>, <title> y el contenido
// del usuario (data-no-i18n) no se mete nada — ahí el emoji simplemente se
// quita para que no desentone.
// ============================================================================
(function () {
  "use strict";
  const P = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const punto = (color) => `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="6.5" fill="${color}"/></svg>`;

  const I = {
    lapiz:     P('<path d="M4 20h4l10.5-10.5a2.1 2.1 0 0 0-3-3L5 17z"/><path d="M13.5 6.5l3 3"/>'),
    basura:    P('<path d="M4 7h16"/><path d="M9.5 7V4.5h5V7"/><path d="M6.5 7l.8 12a1.5 1.5 0 0 0 1.5 1.4h6.4a1.5 1.5 0 0 0 1.5-1.4l.8-12"/><path d="M10 11v6M14 11v6"/>'),
    alerta:    P('<path d="M12 3.5 21 19H3z"/><path d="M12 9.5v4.5M12 17h.01"/>'),
    doc:       P('<path d="M7 3h7l5 5v13H7z"/><path d="M14 3v5h5"/><path d="M9.5 13h5M9.5 16.5h5"/>'),
    lista:     P('<rect x="4" y="4" width="16" height="17" rx="2.5"/><path d="M9 3v3M15 3v3"/><path d="M8 11h8M8 15h5"/>'),
    carpeta:   P('<path d="M3 7a2 2 0 0 1 2-2h4.5l2 2.5H19a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'),
    ojo:       P('<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>'),
    ojoNo:     P('<path d="M3 3l18 18"/><path d="M10 6c.6-.2 1.3-.3 2-.3 6 0 9.5 6.3 9.5 6.3a17 17 0 0 1-3 3.6"/><path d="M6.4 6.6A16 16 0 0 0 2.5 12S6 18.3 12 18.3c1.4 0 2.7-.3 3.8-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>'),
    dolar:     P('<circle cx="12" cy="12" r="9"/><path d="M12 6.5v11"/><path d="M14.8 9.2a2.8 2.3 0 0 0-2.8-1.7c-1.6 0-2.8.8-2.8 2s1.2 1.8 2.8 2.2 2.8 1 2.8 2.3-1.2 2-2.8 2a2.9 2.4 0 0 1-2.9-1.8"/>'),
    recibo:    P('<path d="M6 3h12v18l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5L6 21z"/><path d="M9 8h6M9 11.5h6M9 15h4"/>'),
    okCirc:    P('<circle cx="12" cy="12" r="9"/><path d="m8 12.5 2.6 2.6L16.5 9"/>'),
    cuadro:    P('<rect x="4" y="4" width="16" height="16" rx="3"/>'),
    circulo:   P('<circle cx="12" cy="12" r="7"/>'),
    carrito:   P('<path d="M3 4h2l2.4 11.5A2 2 0 0 0 9.4 17h8.2a2 2 0 0 0 2-1.6L21 8H6"/><circle cx="10" cy="20.5" r="1.3"/><circle cx="17" cy="20.5" r="1.3"/>'),
    subir:     P('<path d="M12 16V4"/><path d="m7 9 5-5 5 5"/><path d="M4 20h16"/>'),
    llave:     P('<path d="M14.5 5.5a4 4 0 0 0-5 5.3L3.5 16.8v3.7h3.7l6-6a4 4 0 0 0 5.3-5l-2.6 2.6-2.5-.7-.7-2.5z"/>'),
    deshacer:  P('<path d="M4 10h10a5 5 0 0 1 0 10H9"/><path d="m8 6-4 4 4 4"/>'),
    rayo:      P('<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>'),
    pin:       P('<path d="M12 21s6-5.6 6-11a6 6 0 0 0-12 0c0 5.4 6 11 6 11z"/><circle cx="12" cy="10" r="2.2"/>'),
    chincheta: P('<path d="M9 4h6l-.7 6.5L17 13v2H7v-2l2.7-2.5z"/><path d="M12 15v6"/>'),
    pluma:     P('<path d="M4 20c4-1 7-3 10-7l6-6-3-3-6 6c-4 3-6 6-7 10z"/><path d="M13 8l3 3"/>'),
    camara:    P('<path d="M4 8h3.5l1.5-2.5h6L16.5 8H20a1.5 1.5 0 0 1 1.5 1.5V19a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 19V9.5A1.5 1.5 0 0 1 4 8z"/><circle cx="12" cy="14" r="3.5"/>'),
    cohete:    P('<path d="M14.5 3.5c3 .5 5.5 3 6 6-2 4-6 7-10 8.5L6 13.5C7.5 9.5 10.5 5.5 14.5 3.5z"/><path d="M6 13.5 3 16l2 1 1 2 2.5-3"/><circle cx="14.5" cy="9.5" r="1.4"/>'),
    persona:   P('<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>'),
    personas:  P('<circle cx="9" cy="8.5" r="3.2"/><path d="M2.8 20a6.2 6.2 0 0 1 12.4 0"/><path d="M15.5 5.5a3.2 3.2 0 0 1 0 6.2"/><path d="M17 14.2a6.2 6.2 0 0 1 4.2 5.8"/>'),
    casa:      P('<path d="M3 11 12 4l9 7"/><path d="M5 10v10h5v-6h4v6h5V10"/>'),
    calendario:P('<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/>'),
    grafica:   P('<path d="M4 20V10M10 20V4M16 20v-9M21 20H3"/>'),
    candado:   P('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>'),
    candadoAb: P('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 7.6-1.7"/>'),
    chispa:    P('<path d="M11 4.5c.5 3.4 2.1 5 5.5 5.5-3.4.5-5 2.1-5.5 5.5-.5-3.4-2.1-5-5.5-5.5 3.4-.5 5-2.1 5.5-5.5z"/><path d="M18 13.5c.3 1.9 1.1 2.7 3 3-1.9.3-2.7 1.1-3 3-.3-1.9-1.1-2.7-3-3 1.9-.3 2.7-1.1 3-3z"/>'),
    play:      P('<path d="M7 4.5v15l12-7.5z"/>'),
    atras:     P('<path d="M17 4.5v15l-12-7.5z"/>'),
    pausa:     P('<path d="M8 5v14M16 5v14"/>'),
    iman:      P('<path d="M6 4v8a6 6 0 0 0 12 0V4"/><path d="M6 4h4v8M14 4h4v8"/>'),
    equis:     P('<path d="M6 6l12 12M18 6 6 18"/>'),
    mas:       P('<path d="M12 5v14M5 12h14"/>'),
    ajustes:   P('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'),
    edificio:  P('<path d="M4 21V5.5L12 3l8 2.5V21"/><path d="M9 21v-4h6v4"/><path d="M8 9h2M14 9h2M8 13h2M14 13h2"/>'),
    senal:     P('<path d="M2.5 9.5a14 14 0 0 1 19 0"/><path d="M5.8 13a9.5 9.5 0 0 1 12.4 0"/><path d="M9 16.4a5 5 0 0 1 6 0"/><path d="M12 20h.01"/>'),
    globo:     P('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
    campana:   P('<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>'),
    pulgar:    P('<path d="M7 11v9H3.5v-9z"/><path d="M7 11l4-7.5a2 2 0 0 1 3.5 1.5L13.5 9H19a2 2 0 0 1 2 2.4l-1.5 6.5A2.5 2.5 0 0 1 17 20H7"/>'),
    enviar:    P('<path d="M21 3 3 10.5l7.5 2.5L13 21z"/>'),
    correo:    P('<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="m3.5 7 8.5 6 8.5-6"/>'),
    mano:      P('<path d="M8 12.5V6a1.5 1.5 0 0 1 3 0v5"/><path d="M11 10.5V4.5a1.5 1.5 0 0 1 3 0v6"/><path d="M14 10.5V6a1.5 1.5 0 0 1 3 0v6"/><path d="M17 12a1.5 1.5 0 0 1 3 0v3.5A6.5 6.5 0 0 1 13.5 22h-1a6.5 6.5 0 0 1-5.5-3l-3-4.5a1.5 1.5 0 0 1 2.4-1.8L8 15"/>'),
    bandeja:   P('<path d="M3 13h5l1.5 2.5h5L16 13h5"/><path d="M3 13v6a1.5 1.5 0 0 0 1.5 1.5h15A1.5 1.5 0 0 0 21 19v-6"/><path d="M12 3v8"/><path d="m8.5 7.5 3.5 3.5 3.5-3.5"/>'),
    guardar:   P('<path d="M5 3h11l3 3v15H5z"/><path d="M8 3v5h7V3"/><path d="M8 21v-6h8v6"/>'),
    caja:      P('<path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5 12 12l9-4.5M12 12v9"/>'),
    estrella:  P('<path d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1.1 5.9L12 16.9l-5.3 2.8 1.1-5.9-4.3-4.1 5.9-.8z"/>'),
    regla:     P('<path d="m3 16.5 13.5-13.5 4.5 4.5L7.5 21z"/><path d="m7 12.5 2 2M10 9.5l2 2M13 6.5l2 2"/>'),
    lupa:      P('<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>'),
    libro:     P('<path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v17H6.5A2.5 2.5 0 0 0 4 21.5z"/><path d="M4 19a2.5 2.5 0 0 1 2.5-2.5H20"/>'),
    telefono:  P('<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>'),
    movil:     P('<rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M11 18.5h2"/>'),
    flecha:    P('<path d="M4 12h16"/><path d="m13 5 7 7-7 7"/>'),
    chat:      P('<path d="M21 11.5a7.5 7.5 0 0 1-7.5 7.5H6.2L3 21.5l.9-4.6A7.5 7.5 0 1 1 21 11.5z"/>'),
    escoba:    P('<path d="M14 3 8.5 12"/><path d="M8.5 12 4 20h8l2.5-8z"/><path d="M6 16h8"/>'),
    enlace:    P('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7L11.5 6.8"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1.5-1.5"/>'),
    ciclo:     P('<path d="M20 12a8 8 0 0 1-14.5 4.7"/><path d="M4 12a8 8 0 0 1 14.5-4.7"/><path d="M18.5 3v4.5H14M5.5 21v-4.5H10"/>'),
    pieza:     P('<path d="M10 3.5a2 2 0 0 1 4 0V6h3.5a1.5 1.5 0 0 1 1.5 1.5V11h-2.5a2 2 0 0 0 0 4H19v3.5a1.5 1.5 0 0 1-1.5 1.5H14v-2.5a2 2 0 0 0-4 0V20H6.5A1.5 1.5 0 0 1 5 18.5V15h2.5a2 2 0 0 0 0-4H5V7.5A1.5 1.5 0 0 1 6.5 6H10z"/>'),
    diana:     P('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.3"/>'),
    enchufe:   P('<path d="M9 3v5M15 3v5"/><path d="M6 8h12v3a6 6 0 0 1-12 0z"/><path d="M12 17v4"/>'),
    fuego:     P('<path d="M12 3c1 3 4 4.5 4 8.5A4 4 0 0 1 12 21a4 4 0 0 1-4-9.5c0 2 1 3 2 3.5-1-4 1-6 2-12z"/>'),
    coche:     P('<path d="M5 13.5 6.6 9a2 2 0 0 1 1.9-1.4h7a2 2 0 0 1 1.9 1.4l1.6 4.5"/><rect x="3.5" y="13.5" width="17" height="4.5" rx="1.6"/><circle cx="7.8" cy="20" r="1.3"/><circle cx="16.2" cy="20" r="1.3"/>'),
    tierra:    P('<circle cx="12" cy="12" r="9"/><path d="M3.5 10c3 1.5 5 0 7 1.5s1 4 3.5 4.5 4-1 4.5-3"/>'),
    pala:      P('<path d="m4 20 8.5-8.5"/><path d="M12.5 11.5 15 9l3.5 3.5-2.5 2.5"/><path d="M15 9l4-4"/>'),
    toma:      P('<rect x="5.5" y="3.5" width="13" height="17" rx="3.5"/><path d="M9.8 9v2.6M14.2 9v2.6"/><path d="M12 16.2v.01"/>'),
    archivo:   P('<rect x="4" y="4" width="16" height="16" rx="2.5"/><path d="M4 10h16M4 15h16"/>'),
    hilo:      P('<path d="M4 6c3-3 6 3 9 0s6 3 7 0"/><path d="M4 12c3-3 6 3 9 0s6 3 7 0"/><path d="M4 18c3-3 6 3 9 0s6 3 7 0"/>'),
    check:     P('<path d="m5 12.5 4.5 4.5L19 7"/>'),
    rojo: punto("#E5484D"), ambar: punto("#F2B705"), verde: punto("#2FB56B"), gris: punto("#B9C7D3"),
  };

  // emoji → icono. Varios emojis pueden ir al mismo icono.
  const MAPA = {
    "✎": "lapiz", "✏": "lapiz", "🗑": "basura", "⚠": "alerta", "📄": "doc", "📋": "lista", "📝": "lista",
    "📂": "carpeta", "👁": "ojo", "👀": "ojo", "🚫": "ojoNo", "🔴": "rojo", "🟡": "ambar", "🟢": "verde",
    "⚪": "gris", "💵": "dolar", "💲": "dolar", "🧾": "recibo", "✅": "okCirc", "✔": "okCirc", "⬜": "cuadro",
    "○": "circulo", "🛒": "carrito", "⬆": "subir", "📤": "subir", "🔧": "llave", "↩": "deshacer", "♻": "ciclo",
    "⚡": "rayo", "📌": "chincheta", "✍": "pluma", "🖊": "pluma", "✒": "pluma", "📷": "camara", "📸": "camara",
    "🚀": "cohete", "👤": "persona", "👥": "personas", "🏠": "casa", "📅": "calendario", "📊": "grafica",
    "🔒": "candado", "🔓": "candadoAb", "🤖": "chispa", "▶": "play", "◀": "atras", "⏸": "pausa", "📍": "pin",
    "🧲": "iman", "✗": "equis", "✕": "equis", "➕": "mas", "⚙": "ajustes", "🏛": "edificio", "📶": "senal",
    "🌐": "globo", "🔔": "campana", "👌": "pulgar", "➤": "enviar", "✉": "correo", "🛋": "mano", "📥": "bandeja",
    "💾": "guardar", "🧰": "caja", "📦": "caja", "⭐": "estrella", "★": "estrella", "📐": "regla", "📏": "regla",
    "🔎": "lupa", "📖": "libro", "☎": "telefono", "📱": "movil", "➡": "flecha", "💬": "chat", "🧹": "escoba",
    "🔗": "enlace", "🧩": "pieza", "🎯": "diana", "🔌": "enchufe", "🔥": "fuego", "🚗": "coche", "🌍": "tierra",
    "⛏": "pala", "🔲": "toma", "🗄": "archivo", "🧵": "hilo"
  };
  const CLAVES = Object.keys(MAPA).sort((a, b) => b.length - a.length);
  // el emoji puede venir con el selector de presentación (️) o un espacio detrás
  const RE = new RegExp("(" + CLAVES.map(k => k.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|") + ")️?", "g");
  const SIN_SVG = new Set(["OPTION", "TEXTAREA", "TITLE", "SCRIPT", "STYLE", "INPUT"]);

  function cambiar(nodo) {
    const txt = nodo.nodeValue;
    if (!txt || !RE.test(txt)) return;
    RE.lastIndex = 0;
    const padre = nodo.parentElement;
    if (!padre) return;
    if (padre.closest("[data-no-i18n], .burbuja-texto, .chat-texto")) return;   // lo que escribe la gente, tal cual
    if (SIN_SVG.has(padre.tagName)) { nodo.nodeValue = txt.replace(RE, "").replace(/^\s+/, ""); return; }
    const frag = document.createDocumentFragment();
    let ultimo = 0, m;
    RE.lastIndex = 0;
    while ((m = RE.exec(txt))) {
      if (m.index > ultimo) frag.appendChild(document.createTextNode(txt.slice(ultimo, m.index)));
      const s = document.createElement("span");
      s.className = "ico ico-" + MAPA[m[1]];
      s.setAttribute("aria-hidden", "true");
      s.innerHTML = I[MAPA[m[1]]];
      frag.appendChild(s);
      ultimo = m.index + m[0].length;
    }
    if (ultimo < txt.length) frag.appendChild(document.createTextNode(txt.slice(ultimo)));
    padre.replaceChild(frag, nodo);
  }
  function recorrer(raiz) {
    if (raiz.nodeType === 3) { cambiar(raiz); return; }
    if (raiz.nodeType !== 1) return;
    const w = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
    const lista = [];
    let n; while ((n = w.nextNode())) lista.push(n);
    lista.forEach(cambiar);
  }
  recorrer(document.body);
  new MutationObserver(muts => {
    for (const m of muts) {
      if (m.type === "characterData") cambiar(m.target);
      m.addedNodes.forEach(recorrer);
    }
  }).observe(document.body, { childList: true, subtree: true, characterData: true });
})();
