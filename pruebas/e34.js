// E34 · El SIGNO del dinero en la hoja de alcance (22-23/09).
// La auditoría de Mariners encontró que un deduct «-$12,500» se leía como
// CARGO y pasaba la validación sin un solo aviso: con eso se firma un contrato
// $25.000 equivocado. Aquí queda fijado qué es un descuento y qué no.
// Sin navegador: alcance.js se carga igual en Node.
const A = require("../js/alcance.js");

const casos = [
  // [texto de la hoja, centavos esperados, por qué]
  ["$12,500.00", 1250000, "cargo normal"],
  ["-$12,500.00", -1250000, "menos pegado al $ = descuento"],
  ["−$12,500.00", -1250000, "menos tipográfico pegado"],
  ["− $12,500.00", -1250000, "menos tipográfico con espacio: así lo escribe el portal"],
  ["($12,500.00)", -1250000, "forma contable entre paréntesis"],
  ["( $12,500.00 )", -1250000, "paréntesis con espacios"],
  ["Option B (deduct): -$4,200.00", -420000, "deduct escrito en la línea"],
  ["ADD - extra receptacles - $3,400", 340000, "guion SEPARADOR: sigue siendo un añadido"],
  ["Remove 2 lights - $350.00", 35000, "guion separador con espacios no es signo"],
  ["– $3,000", 300000, "raya con espacio = separador, no signo"],
];

let ok = 0;
for (const [texto, esperado, porque] of casos) {
  const d = A.hayDinero(texto);
  const m = d ? A.leerMonto(d.trozo) : null;
  const sale = m ? m.centavos : null;
  if (sale === esperado) ok++;
  else console.log(`✗ ${JSON.stringify(texto)} → ${sale}, esperaba ${esperado} (${porque})`);
}
console.log(`${ok}/${casos.length} ok`);
process.exit(ok === casos.length ? 0 : 1);
