// ============================================================
// pdf.ts — LA FACTURA EN PDF (f10, c11). Pinta el documento que el cliente
// recibe, en inglés, desde el CONTENIDO CONGELADO de c11 (fn_emision_documento:
// contenido) y de nada más: el número, las fechas, a quién, la obra, las
// líneas, la retención descontada, el total a pagar, el «How to pay» y, si lo
// hay, el enlace de pago por cuenta de banco (ACH) con su código QR.
//
// Es PURO: no habla con la red ni con la base, no lee el entorno ni el reloj.
// Recibe las librerías (pdf-lib y, si está, qrcode) desde fuera, para que el
// mismo archivo corra en Supabase (Deno: npm:pdf-lib) y en las pruebas sin
// Deno (Node 22 quita los tipos; pruebas/conta/facturas-e2e.mjs le pasa las
// suyas). Con el mismo contenido, el mismo enlace y el mismo membrete, sale el
// MISMO archivo, byte a byte (las fechas del PDF son la fecha de la factura):
// su sha256 no cambia si se vuelve a pintar.
//
// Dinero: los montos llegan como TEXTO de dos decimales («1111.11») y aquí
// solo se escriben con sus comas («$1,111.11»): nada se suma ni se redondea en
// JavaScript (la base calcula; el PDF enseña). Lo único que se calcula es el
// ancho de la barrita del «% facturado», que es un porcentaje, no dinero.
//
// Diseño: docs/conta/f10-factura-vista-previa.html («Cobre y luz»: navy, el
// cable de cobre bajo el membrete, las cajas de cielo, la banda noche del
// «Amount due» con la cifra en cian, el pie con el degradado). Letra:
// Helvetica (la estándar del PDF: no se incrusta nada y pesa poco); sus
// cifras tienen todas el mismo ancho, así que las columnas cuadran. Lo que
// Helvetica no sabe escribir (fuera de WinAnsi) se cambia por lo más parecido
// («−» → «-», «→» → «->») y, si no hay parecido, por «?».
// ============================================================

// deno-lint-ignore-file no-explicit-any
type Json = Record<string, any>;

export const PDF_VERSION = "facturas-pdf 2026-11-12.3";

export interface Librerias {
  PDFLib: any;          // el módulo de pdf-lib (1.17.x)
  QRCode?: any;         // el módulo de qrcode (1.5.x); sin él, sin código QR
}
export interface OpcionesPdf {
  pago?: { url: string; monto?: unknown } | null;   // el enlace de pago (solo cuenta de banco) y lo que cobra (el libro)
  logo?: Uint8Array | null;        // el PNG del membrete (assets/lockup.png); sin él, el nombre en letra
  huella?: string | null;          // la huella del contenido (va en las palabras clave del PDF)
}

// ---- los colores de «Cobre y luz» (css/styles.css) ----
const hex = (lib: any, h: string) => {
  const n = parseInt(h.slice(1), 16);
  return lib.rgb(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255);
};
const C = {
  navy: "#1B3C8C", blue: "#2A5BD7", cyan: "#22E8E0", lime: "#8CF06A", yellow: "#EFE22E",
  ink: "#0B2036", ink2: "#4D6A83", line: "#CFE0EE", sky1: "#F6FCFF", sky3: "#DCEEF7",
  night: "#071A2E", teal: "#0D7D92", cuLight: "#E3A06A", cuDeep: "#B86A2E", cuDark: "#8F4F1F", white: "#FFFFFF",
};

// ---- la hoja: Letter, en puntos ----
const ANCHO = 612, ALTO = 792;
const MI = 43.2, MD = 43.2;            // márgenes izquierdo y derecho (0.6 in)
const ARRIBA = 36;                      // margen de arriba (0.5 in)
const PIE = 62;                         // lo que ocupa el pie (desde abajo)
const UTIL = ANCHO - MI - MD;

// ---- lo que el cliente cita al pagar (lo mismo en el PDF, el correo y la vista previa de la pantalla) ----
// Una factura: «Please reference invoice MXP-2027-0001.». La de la retención: las facturas cuya retención reclama
// («Please reference invoices MXP-2027-0002 and MXP-2027-0003.»), que es lo que el cliente tiene en sus libros. Sin número
// (un borrador), nada.
export function listaEn(xs: string[]): string {
  return xs.length <= 1 ? (xs[0] ?? "") : `${xs.slice(0, -1).join(", ")} and ${xs[xs.length - 1]}`;
}
export function referenciaEn(c: Json): string {
  const refs = Array.isArray(c.referencias) ? c.referencias.map((x: unknown) => String(x ?? "").trim()).filter(Boolean) : [];
  if (c.forma === "retencion" && refs.length) return `Please reference invoice${refs.length > 1 ? "s" : ""} ${listaEn(refs)}.`;
  return c.numero ? `Please reference invoice ${c.numero}.` : "";
}

// ---- textos: lo que Helvetica sabe escribir ----
const PARECIDOS: Record<string, string> = {
  "−": "-", "‐": "-", "‑": "-", "‒": "-", "→": "->", "←": "<-", "≤": "<=", "≥": ">=",
  " ": " ", " ": " ", " ": " ", " ": " ", "\t": " ", "✓": "", "✔": "", "­": "",
  "′": "'", "″": "\"", "⁄": "/", "×": "x",
};
function saneador(fuente: any) {
  const cache = new Map<string, string>();
  return (s: unknown): string => {
    const t = String(s ?? "").normalize("NFC");
    let out = "";
    for (const ch of t) {
      let r = cache.get(ch);
      if (r === undefined) {
        if (ch in PARECIDOS) r = PARECIDOS[ch];
        else {
          try { fuente.encodeText(ch); r = ch; } catch {
            // una letra con acento que WinAnsi no tiene: sin el acento; si no, «?»
            const base = ch.normalize("NFD").replace(/[̀-ͯ]/g, "");
            try { fuente.encodeText(base); r = base || "?"; } catch { r = "?"; }
          }
        }
        cache.set(ch, r);
      }
      out += r;
    }
    return out;
  };
}

// ---- dinero y fechas, escritos (sin hacer cuentas) ----
// «1234.5» → «$1,234.50»; «-50.00» → «-$50.00»; con más de dos decimales, los deja («12.3456»)
export function usd(v: unknown): string {
  const t = String(v ?? "").trim();
  const m = /^(-)?(\d+)(?:\.(\d+))?$/.exec(t);
  if (!m) return t;
  const ent = m[2].replace(/^0+(?=\d)/, "").replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  let dec = (m[3] ?? "").replace(/0+$/, "");
  if (dec.length < 2) dec = (dec + "00").slice(0, 2);
  return `${m[1] ? "-" : ""}$${ent}.${dec}`;
}
const MESES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
export function dia(iso: unknown): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso ?? ""));
  return m ? `${MESES[Number(m[2]) - 1]} ${Number(m[3])}, ${m[1]}` : String(iso ?? "");
}
// la cantidad como se lee: «8», «2.5»
const cantidad = (v: unknown) => String(v ?? "").replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "");
// el % del contrato para la barrita (0–100), solo para dibujar
const pctBarra = (v: unknown) => { const n = Number(v); return Number.isFinite(n) ? Math.max(0, Math.min(100, n)) : 0; };

// Lo que dice la factura según su forma, debajo del número
export function subtitulo(c: Json): string {
  const ord = Number(c.ordinal);
  if (c.forma === "retencion") return "Retainage release";
  if (c.forma === "tm") return "Time & materials";
  if (c.hito && c.hito.es_deposito) return "Deposit";
  return Number.isFinite(ord) && ord > 0 ? `Progress billing #${ord}` : "Progress billing";
}
// Los términos en una frase
export function terminosTexto(c: Json): string {
  const t = c.terminos || {};
  const dias = Number(t.dias);
  const base = !dias ? "Payment is due on receipt." : `Payment is due within ${dias} days of the invoice date (by ${dia(c.vence)}).`;
  return [base, t.texto].filter(Boolean).join(" ");
}

export async function pintarFactura(libs: Librerias, contenido: Json, op: OpcionesPdf = {}): Promise<Uint8Array> {
  const L = libs.PDFLib;
  if (!L || typeof L.PDFDocument?.create !== "function") throw new Error("pintarFactura: falta pdf-lib.");
  const c = contenido || {};
  if (c.v !== 1) throw new Error(`pintarFactura: no sé pintar el contenido v${c.v} (sé el v1).`);
  const col = (k: keyof typeof C) => hex(L, C[k]);
  const empresa: Json = c.empresa || {};
  const cliente: Json = c.cliente || {};
  const obra: Json = c.obra || {};
  const tot: Json = c.totales || {};
  const numero = String(c.numero ?? "");

  const doc = await L.PDFDocument.create({ updateMetadata: false });
  const R = await doc.embedFont(L.StandardFonts.Helvetica);
  const B = await doc.embedFont(L.StandardFonts.HelveticaBold);
  const sR = saneador(R), sB = saneador(B);
  const san = (f: any, s: unknown) => (f === B ? sB : sR)(s);

  // metadatos: fijos para el mismo contenido (la fecha es la de la factura, a mediodía UTC)
  const fechaDoc = /^\d{4}-\d{2}-\d{2}$/.test(String(c.fecha)) ? new Date(`${c.fecha}T12:00:00Z`) : new Date(0);
  doc.setTitle(sR(`Invoice ${numero}`));
  doc.setAuthor(sR(empresa.nombre || ""));
  doc.setSubject(sR(`Invoice ${numero}${obra.nombre ? " · " + obra.nombre : ""}`));
  doc.setCreator("Max Power Panel");
  doc.setProducer(PDF_VERSION);
  doc.setLanguage("en-US");
  doc.setCreationDate(fechaDoc);
  doc.setModificationDate(fechaDoc);
  if (op.huella) doc.setKeywords([`c11:${op.huella}`]);

  // ---- medir y partir texto ----
  const ancho = (f: any, s: string, t: number) => f.widthOfTextAtSize(s, t);
  function partir(f: any, texto: unknown, t: number, max: number): string[] {
    const salida: string[] = [];
    for (const parrafo of san(f, texto).split(/\r?\n/)) {
      const palabras = parrafo.split(/ +/).filter((p) => p !== "");
      if (!palabras.length) { salida.push(""); continue; }
      let linea = "";
      for (let p of palabras) {
        // una palabra que no cabe sola (una URL larga): se parte por letras
        while (ancho(f, p, t) > max) {
          let i = p.length;
          while (i > 1 && ancho(f, (linea ? linea + " " : "") + p.slice(0, i), t) > max) i--;
          if (i <= 1 && linea) { salida.push(linea); linea = ""; continue; }
          salida.push((linea ? linea + " " : "") + p.slice(0, Math.max(1, i)));
          linea = ""; p = p.slice(Math.max(1, i));
        }
        const prueba = linea ? `${linea} ${p}` : p;
        if (ancho(f, prueba, t) <= max) linea = prueba;
        else { salida.push(linea); linea = p; }
      }
      salida.push(linea);
    }
    return salida;
  }

  // ---- páginas ----
  const paginas: any[] = [];
  let pg: any = null;
  let y = 0;
  const nueva = () => {
    pg = doc.addPage([ANCHO, ALTO]);
    paginas.push(pg);
    pg.drawRectangle({ x: 0, y: ALTO - 4, width: ANCHO, height: 4, color: col("navy") });
    y = ALTO - ARRIBA;
  };
  const texto = (s: string, x: number, yy: number, f: any, t: number, k: keyof typeof C = "ink") =>
    pg.drawText(s, { x, y: yy, size: t, font: f, color: col(k) });
  const derecha = (s: string, xd: number, yy: number, f: any, t: number, k: keyof typeof C = "ink") =>
    texto(s, xd - ancho(f, s, t), yy, f, t, k);
  // un rectángulo de esquinas redondas (x, y = la esquina de abajo a la izquierda)
  const caja = (x: number, yAbajo: number, w: number, h: number, r: number, fondo: keyof typeof C | null, borde: keyof typeof C | null, bw = 0.75) => {
    const ruta = `M ${r} 0 L ${w - r} 0 Q ${w} 0 ${w} ${r} L ${w} ${h - r} Q ${w} ${h} ${w - r} ${h} L ${r} ${h} Q 0 ${h} 0 ${h - r} L 0 ${r} Q 0 0 ${r} 0 Z`;
    pg.drawSvgPath(ruta, { x, y: yAbajo + h, color: fondo ? col(fondo) : undefined, borderColor: borde ? col(borde) : undefined, borderWidth: borde ? bw : 0 });
  };
  // un degradado (a tiras finas): el cable de cobre y la raya del pie
  const degradado = (x: number, yy: number, w: number, h: number, paradas: string[]) => {
    const n = 90, rgb = paradas.map((p) => { const v = parseInt(p.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; });
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1) * (rgb.length - 1), a = Math.min(Math.floor(t), rgb.length - 2), f = t - a;
      const m = [0, 1, 2].map((k) => (rgb[a][k] + (rgb[a + 1][k] - rgb[a][k]) * f) / 255);
      pg.drawRectangle({ x: x + (w * i) / n, y: yy, width: w / n + 0.4, height: h, color: L.rgb(m[0], m[1], m[2]) });
    }
  };
  const etiqueta = (s: string, x: number, yy: number) => texto(s.toUpperCase(), x, yy, B, 7.2, "cuDark");

  // ================= EL MEMBRETE =================
  nueva();
  const anchoIzq = UTIL * 0.56;
  let yIzq = y;
  if (op.logo && op.logo.length) {
    try {
      const img = await doc.embedPng(op.logo);
      const w = 172, h = (img.height / img.width) * w;
      pg.drawImage(img, { x: MI, y: yIzq - h, width: w, height: h });
      yIzq -= h + 6;
    } catch { op = { ...op, logo: null }; }
  }
  if (!op.logo || !op.logo.length) {
    for (const l of partir(B, empresa.nombre || "", 17, anchoIzq)) { texto(l, MI, yIzq - 15, B, 17, "navy"); yIzq -= 20; }
    yIzq -= 4;
  }
  const datos1 = empresa.licencia ? `Licensed Electrical Contractor · ${empresa.licencia}` : "";
  const datos2 = [empresa.direccion, empresa.telefono, empresa.correo].filter((x) => x && String(x).trim()).join(" · ");
  for (const l of [...(datos1 ? partir(R, datos1, 8, anchoIzq) : []), ...(datos2 ? partir(R, datos2, 8, anchoIzq) : [])]) {
    texto(l, MI, yIzq - 8, R, 8, "ink2"); yIzq -= 11;
  }
  // a la derecha: INVOICE, el número, las fechas, qué factura es
  const xd = ANCHO - MD;
  let yDer = y;
  derecha("INVOICE", xd, yDer - 24, B, 26, "navy"); yDer -= 30;
  if (numero) { derecha(sB(`No. ${numero}`), xd, yDer - 13, B, 12.5, "ink"); yDer -= 19; }
  const vence = Number(c.terminos?.dias) ? `Due ${dia(c.vence)} (${c.terminos?.etiqueta || ""})` : "Due on receipt";
  derecha(sR(`Date ${dia(c.fecha)}  ·  ${vence}`), xd, yDer - 9, R, 8.6, "ink2"); yDer -= 13;
  derecha(sR(subtitulo(c)), xd, yDer - 9, B, 8.6, "teal"); yDer -= 13;
  y = Math.min(yIzq, yDer) - 6;
  degradado(MI, y - 3, UTIL, 2.6, [C.cuLight, C.cuDeep, C.cuDark]);
  y -= 16;

  // ================= LAS TRES CAJAS =================
  const gap = 9, w1 = (UTIL - 2 * gap) * 1.2 / 3.4, w3 = (UTIL - 2 * gap) * 1 / 3.4, w2 = w1;
  const pad = 9;
  const cajaTxt = (lineas: Array<[string, any, number, keyof typeof C]>, w: number) => {
    const out: Array<[string, any, number, keyof typeof C]> = [];
    for (const [s, f, t, k] of lineas) for (const l of partir(f, s, t, w - 2 * pad)) out.push([l, f, t, k]);
    return out;
  };
  const att = cliente.atencion ? `Attn: ${cliente.atencion}` : "";
  const c1 = cajaTxt([
    [cliente.nombre || "", B, 9.6, "ink"], ...(att ? [[att, R, 8.6, "ink"] as [string, any, number, keyof typeof C]] : []),
    ...(cliente.direccion ? [[cliente.direccion, R, 8.6, "ink"] as [string, any, number, keyof typeof C]] : []),
    ...(cliente.correo ? [[cliente.correo, R, 8.6, "ink2"] as [string, any, number, keyof typeof C]] : []),
  ], w1);
  const c2 = cajaTxt([
    [obra.nombre || "", B, 9.6, "ink"],
    ...(obra.direccion ? [[obra.direccion, R, 8.6, "ink"] as [string, any, number, keyof typeof C]] : []),
    ...(obra.ref ? [[`Ref. ${obra.ref}`, R, 8.6, "ink2"] as [string, any, number, keyof typeof C]] : []),
    ...(c.hito && c.hito.titulo ? [[`Milestone: ${c.hito.titulo}`, R, 8.6, "ink2"] as [string, any, number, keyof typeof C]] : []),
  ], w2);
  const k = c.contrato;
  const filasK: Array<[string, string, boolean]> = k ? [
    ["Contract amount", usd(k.monto), false], ["Billed before", usd(k.facturado_antes), false],
    ["This invoice", usd(k.esta), false], ["Billed to date", usd(k.facturado_con_esta), true],
  ] : [["Terms", c.terminos?.etiqueta || "", false], ["Due", Number(c.terminos?.dias) ? dia(c.vence) : "On receipt", false]];
  const alto = (ls: Array<unknown>) => ls.length * 12;
  const hCajas = Math.max(alto(c1), alto(c2), filasK.length * 12 + (k ? 14 : 0)) + 2 * pad + 13;
  const yCaja = y - hCajas;
  const cajas = [{ x: MI, w: w1, t: "Bill to", ls: c1 }, { x: MI + w1 + gap, w: w2, t: "Project", ls: c2 }];
  for (const cx of cajas) {
    caja(cx.x, yCaja, cx.w, hCajas, 9, "sky1", "line");
    etiqueta(cx.t, cx.x + pad, y - pad - 6);
    let yy = y - pad - 19;
    for (const [s, f, t, kk] of cx.ls) { texto(s, cx.x + pad, yy, f, t, kk); yy -= 12; }
  }
  const x3 = MI + w1 + w2 + 2 * gap;
  caja(x3, yCaja, w3, hCajas, 9, "sky1", "line");
  etiqueta(k ? "Contract status" : "Invoice terms", x3 + pad, y - pad - 6);
  {
    let yy = y - pad - 19;
    for (const [a, b, fuerte] of filasK) {
      const f = fuerte ? B : R;
      texto(sR(a), x3 + pad, yy, f, 8.6, "ink");
      derecha(sR(b), x3 + w3 - pad, yy, f, 8.6, "ink");
      yy -= 12;
    }
    if (k) {
      const pista = w3 - 2 * pad - 30, xb = x3 + pad;
      caja(xb, yy - 2, pista, 5.5, 2.75, "sky3", null);
      const lleno = (pista * pctBarra(k.pct)) / 100;
      if (lleno > 0.5) {
        // la barra con el degradado de la casa, recortada a lo facturado
        const tiras = 40;
        const paradas = [C.navy, C.blue, C.cyan, C.lime, C.yellow].map((p) => { const v = parseInt(p.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; });
        for (let i = 0; i < tiras; i++) {
          const xx = (pista * i) / tiras;
          if (xx >= lleno) break;
          const t = (i / (tiras - 1)) * 4, a = Math.min(Math.floor(t), 3), f = t - a;
          const m = [0, 1, 2].map((q) => (paradas[a][q] + (paradas[a + 1][q] - paradas[a][q]) * f) / 255);
          pg.drawRectangle({ x: xb + xx, y: yy - 2, width: Math.min(pista / tiras + 0.4, lleno - xx), height: 5.5, color: L.rgb(m[0], m[1], m[2]) });
        }
      }
      derecha(sR(`${String(k.pct ?? "")}%`), x3 + w3 - pad, yy - 2, B, 8.2, "ink");
    }
  }
  y = yCaja - 16;

  // ================= LAS LÍNEAS =================
  const tm = c.forma === "tm";
  const xImp = xd, xRate = xd - 86, xQty = xd - 168;
  const anchoDesc = (tm ? xQty - 46 : xd - 120) - MI;
  const cabeceraTabla = () => {
    texto("DESCRIPTION", MI + 4, y - 9, B, 7.2, "ink2");
    if (tm) { derecha("QTY", xQty, y - 9, B, 7.2, "ink2"); derecha("RATE", xRate, y - 9, B, 7.2, "ink2"); }
    derecha("AMOUNT", xImp - 4, y - 9, B, 7.2, "ink2");
    pg.drawRectangle({ x: MI, y: y - 15, width: UTIL, height: 1.5, color: col("navy") });
    y -= 22;
  };
  const sigueEnOtra = () => {
    nueva();
    texto(sR(`Invoice ${numero} (continued)`), MI, y - 10, B, 9, "ink2");
    y -= 24;
    cabeceraTabla();
  };
  cabeceraTabla();
  for (const l of Array.isArray(c.lineas) ? c.lineas : []) {
    const d1 = partir(B, l.descripcion || "", 9.4, anchoDesc);
    const d2 = l.detalle ? partir(R, l.detalle, 8.2, anchoDesc) : [];
    const h = d1.length * 11.5 + d2.length * 10.5 + 9;
    if (y - h < PIE + 24) sigueEnOtra();
    let yy = y - 9;
    for (const s of d1) { texto(s, MI + 4, yy, B, 9.4, "ink"); yy -= 11.5; }
    for (const s of d2) { texto(s, MI + 4, yy + 1, R, 8.2, "ink2"); yy -= 10.5; }
    if (tm) {
      derecha(sR(`${cantidad(l.cantidad)}${l.unidad ? " " + l.unidad : ""}`), xQty, y - 9, R, 9.4, "ink");
      derecha(sR(usd(l.precio)), xRate, y - 9, R, 9.4, "ink");
    }
    derecha(sR(usd(l.importe)), xImp - 4, y - 9, R, 9.4, "ink");
    y -= h;
    pg.drawRectangle({ x: MI, y: y + 3, width: UTIL, height: 0.6, color: col("line") });
  }
  y -= 8;

  // ================= HOW TO PAY Y LOS TOTALES =================
  const wTot = UTIL * 0.43, xTot = xd - wTot, wPago = UTIL - wTot - 18;
  // lo que cobra el enlace (lo que el libro dice que se debe hoy). Si ya entró algún pago, es menos que lo que pide la
  // factura: entonces lo grande (la banda) es «Balance due today» con lo que cobra el enlace —lo mismo que dice el enlace
  // y lo que Stripe va a cobrar— y lo de la factura queda encima como «Invoice amount due». Comparar dos textos no es sumar.
  const cobra = op.pago && op.pago.url && op.pago.monto != null && String(op.pago.monto).trim() !== "" ? usd(op.pago.monto) : null;
  const saldoHoy = !!cobra && cobra !== usd(tot.a_pagar);
  const filasT: Array<[string, string, keyof typeof C]> = [];
  const esRet = c.forma === "retencion";
  filasT.push([esRet ? "Retainage released" : "Subtotal", usd(tot.subtotal), "ink2"]);
  const hayRet = !esRet && /[1-9]/.test(String(tot.retencion ?? ""));
  if (hayRet) filasT.push([`Less retainage held (${tot.retencion_pct}%)`, `-${usd(tot.retencion)}`, "cuDark"]);
  if (!esRet && /[1-9]/.test(String(tot.retenido_a_la_fecha ?? ""))) filasT.push(["Retainage held to date", usd(tot.retenido_a_la_fecha), "ink2"]);
  if (saldoHoy) filasT.push(["Invoice amount due", usd(tot.a_pagar), "ink"]);
  const hTot = filasT.length * 21 + 30;
  // el bloque de pagar: el texto de la casa, el enlace y el QR
  const qrLado = op.pago && libs.QRCode ? 66 : 0;
  const wTxtPago = wPago - (qrLado ? qrLado + 10 : 0);
  const pagoLineas: Array<[string, any, number, keyof typeof C, string?]> = [];
  for (const s of partir(R, c.como_pagar || "", 8.6, wTxtPago)) pagoLineas.push([s, R, 8.6, "ink"]);
  if (op.pago && op.pago.url) {
    // el cliente ve EXACTAMENTE lo que Stripe le va a cobrar (y es lo mismo que dice la banda)
    pagoLineas.push(["", R, 4, "ink"]);
    for (const s of partir(B, cobra ? `Pay ${cobra} online by bank transfer (ACH):` : "Pay online by bank transfer (ACH):", 8.6, wTxtPago)) pagoLineas.push([s, B, 8.6, "ink"]);
    for (const s of partir(R, op.pago.url, 8.2, wTxtPago)) pagoLineas.push([s, R, 8.2, "blue", op.pago.url]);
    if (saldoHoy) {
      for (const s of partir(R, `That is the balance due today: payments already received are deducted.`, 8.2, wTxtPago)) pagoLineas.push([s, R, 8.2, "ink2"]);
    }
    // lo que la base le dice al cliente del pago en línea (c11: «Online payment is by bank account (ACH) only.»): solo con el
    // enlace impreso, que es cuando hay pago en línea en ESTE papel. La tarjeta no se le ofrece (decisión del 12-nov: se enciende
    // cuando los cobros en línea sepan registrar el recargo; hasta entonces aquí no hay ninguna línea de tarjeta)
    if (c.pago_en_linea && c.pago_en_linea.texto) {
      for (const s of partir(R, c.pago_en_linea.texto, 8.2, wTxtPago)) pagoLineas.push([s, R, 8.2, "ink2"]);
    }
  }
  // lo que el cliente cita al pagar: su número; en la de la retención (que no es una factura del libro), los números de las
  // facturas cuya retención reclama (contenido.referencias)
  const cita = referenciaEn(c);
  if (cita) for (const s of partir(R, cita, 8.2, wTxtPago)) pagoLineas.push([s, R, 8.2, "ink2"]);
  const hPago = 14 + pagoLineas.reduce((a, l) => a + (l[2] < 6 ? 4 : 11.5), 0);
  const hBloque = Math.max(hTot, hPago, qrLado + 16);
  if (y - hBloque < PIE + 10) { nueva(); }
  // los totales
  caja(xTot, y - hTot, wTot, hTot, 9, null, "line");
  let yt = y;
  for (const [a, b, kk] of filasT) {
    texto(sR(a), xTot + 10, yt - 14, R, 9.2, kk);
    derecha(sR(b), xd - 10, yt - 14, R, 9.2, kk === "cuDark" ? "cuDark" : "ink");
    yt -= 21;
    pg.drawRectangle({ x: xTot, y: yt, width: wTot, height: 0.6, color: col("line") });
  }
  caja(xTot, y - hTot, wTot, 30, 9, "night", null);
  pg.drawRectangle({ x: xTot, y: y - hTot + 22, width: wTot, height: 8, color: col("night") });
  texto(saldoHoy ? "Balance due today" : "Amount due", xTot + 10, y - hTot + 10.5, B, 12, "white");
  derecha(sR(saldoHoy && cobra ? cobra : usd(tot.a_pagar)), xd - 10, y - hTot + 10.5, B, 12.5, "cyan");
  // how to pay
  etiqueta("How to pay", MI, y - 7);
  let yp = y - 21;
  const anotaciones: any[] = [];
  for (const [s, f, t, kk, url] of pagoLineas) {
    if (t < 6) { yp -= 4; continue; }
    texto(s, MI, yp, f, t, kk);
    if (url) {
      const w = ancho(f, s, t);
      pg.drawRectangle({ x: MI, y: yp - 1.4, width: w, height: 0.5, color: col("blue") });
      anotaciones.push({ pg, rect: [MI, yp - 2, MI + w, yp + t], url });
    }
    yp -= 11.5;
  }
  if (qrLado && op.pago) {
    try {
      const q = libs.QRCode.create(op.pago.url, { errorCorrectionLevel: "M" });
      const n = q.modules.size, celda = (qrLado - 8) / n;
      const xq = MI + wPago - qrLado, yq = y - 6 - qrLado;
      caja(xq, yq, qrLado, qrLado, 6, "white", "navy", 1.2);
      for (let r = 0; r < n; r++) {
        let ini = -1;
        for (let cc = 0; cc <= n; cc++) {
          const oscuro = cc < n && q.modules.get(r, cc);
          if (oscuro && ini < 0) ini = cc;
          if (!oscuro && ini >= 0) {
            pg.drawRectangle({ x: xq + 4 + ini * celda, y: yq + qrLado - 4 - (r + 1) * celda, width: (cc - ini) * celda + 0.05, height: celda + 0.05, color: col("ink") });
            ini = -1;
          }
        }
      }
      texto("Scan to pay", xq + (qrLado - ancho(R, "Scan to pay", 6.8)) / 2, yq - 9, R, 6.8, "ink2");
      anotaciones.push({ pg, rect: [xq, yq, xq + qrLado, yq + qrLado], url: op.pago.url });
    } catch { /* sin QR: el enlace escrito basta */ }
  }
  y -= hBloque + 16;

  // ================= NOTAS Y TÉRMINOS =================
  const wCol = (UTIL - 18) / 2;
  const notas = c.notas ? partir(R, c.notas, 8.4, wCol) : [];
  const term = partir(R, terminosTexto(c), 8.4, wCol);
  const hNot = 14 + Math.max(notas.length, term.length) * 11;
  if (y - hNot < PIE + 6) nueva();
  if (notas.length) {
    etiqueta("Notes", MI, y - 7);
    let yy = y - 20; for (const s of notas) { texto(s, MI, yy, R, 8.4, "ink2"); yy -= 11; }
  }
  const xTerm = notas.length ? MI + wCol + 18 : MI;
  etiqueta("Terms", xTerm, y - 7);
  { let yy = y - 20; for (const s of term) { texto(s, xTerm, yy, R, 8.4, "ink2"); yy -= 11; } }

  // ================= EL PIE (en cada hoja) =================
  const pieIzq = sR([empresa.nombre, empresa.web, empresa.licencia].filter((x) => x && String(x).trim()).join(" · "));
  paginas.forEach((p, i) => {
    pg = p;
    degradado(MI, 44, UTIL, 2.6, [C.navy, C.blue, C.cyan, C.lime, C.yellow]);
    const der = sR(`Thank you for your business · Invoice ${numero} · page ${i + 1} of ${paginas.length}`);
    const wDer = ancho(R, der, 7.8);
    let izq = pieIzq;
    while (izq && ancho(B, izq, 7.8) > UTIL - wDer - 14) izq = izq.slice(0, -2) + "…";
    texto(izq, MI, 30, B, 7.8, "navy");
    derecha(der, xd, 30, R, 7.8, "ink2");
  });

  // los enlaces que se pueden tocar
  for (const a of anotaciones) {
    const ann = doc.context.register(doc.context.obj({
      Type: "Annot", Subtype: "Link", Rect: a.rect, Border: [0, 0, 0],
      A: { Type: "Action", S: "URI", URI: L.PDFString.of(a.url) },
    }));
    const prev = a.pg.node.lookup(L.PDFName.of("Annots"));
    if (prev && typeof prev.push === "function") prev.push(ann);
    else a.pg.node.set(L.PDFName.of("Annots"), doc.context.obj([ann]));
  }

  return await doc.save({ useObjectStreams: false });
}
