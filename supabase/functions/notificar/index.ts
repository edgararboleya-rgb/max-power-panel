// ============================================================
// NOTIFICACIONES AL TELÉFONO — el "cartero" (VERSIÓN 4 — sin secretos
// escritos en el código)
//
// Dónde se pega (2 minutos):
//   Supabase → Edge Functions → notificar (la que ya existe)
//   → abrir el editor de código, borrar TODO y pegar este archivo
//   → Deploy (la opción de JWT sigue apagada, no hay que tocarla)
//
// ANTES de desplegar, en Supabase → Edge Functions → notificar → Secrets
// tienen que existir (ver docs/sql/e37b-cartero-rotar-preparar.sql):
//   MXP_SECRETO_CARTERO           el secreto que manda la base (fn_cartero)
//   MXP_SECRETO_CARTERO_ANTERIOR  el de antes, SOLO mientras dura el cambio
//   VAPID_PRIVADA                 la clave privada con la que se firman los
//                                 avisos (la que antes iba escrita aquí)
// Si falta alguno obligatorio, contesta 500 y no manda nada: mejor un
// aviso que no sale que una puerta abierta.
//
// Nuevo en v4:
//   - Los dos secretos salen de la configuración, no del código. Quien lea
//     este archivo (está en un repositorio público) no se lleva nada.
//   - Acepta el secreto nuevo y, durante el cambio, el anterior; cada vez
//     que alguien usa el anterior deja una línea en el log diciendo quién,
//     para saber cuándo se puede borrar.
//   - La comparación del secreto es de tiempo constante.
// De v2 sigue: "para" (avisar SOLO a esa persona — mensajes privados) y
// "excepto" (avisar a todos MENOS al que escribió).
//
// Qué hace: recibe el aviso (de la base de datos o de la rutina de la
// mañana), busca los teléfonos registrados y les manda la notificación
// firmada. Las suscripciones muertas se limpian solas.
// ============================================================
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

// La pública no es secreta: es la misma que usa js/app.js para suscribir
// el teléfono.
const VAPID_PUBLICA = "BFz8YFTrRLK43nXpdA1bRjOks94y4Z2kNGWHiLn3Y9D1FYM12sJt6Zn1DODXLJaLpiGzxZRgn-1mzBJr43pWlD8";
const VAPID_PRIVADA = Deno.env.get("VAPID_PRIVADA") ?? "";
const SECRETO = Deno.env.get("MXP_SECRETO_CARTERO") ?? "";
const SECRETO_ANTERIOR = Deno.env.get("MXP_SECRETO_CARTERO_ANTERIOR") ?? "";

let vapidListo = false;

// Compara sin delatar por el tiempo cuántos caracteres acertó quien prueba.
function igual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req: Request) => {
  if (!VAPID_PRIVADA || SECRETO.length < 16) {
    console.error("notificar: faltan los secretos VAPID_PRIVADA o MXP_SECRETO_CARTERO (Edge Functions → notificar → Secrets)");
    return new Response("falta configurar", { status: 500 });
  }
  const recibido = req.headers.get("x-mxp-secreto") ?? "";
  const esNuevo = igual(recibido, SECRETO);
  const esAnterior = !esNuevo && SECRETO_ANTERIOR.length >= 16 && igual(recibido, SECRETO_ANTERIOR);
  if (!esNuevo && !esAnterior) {
    return new Response("no autorizado", { status: 401 });
  }
  if (esAnterior) {
    console.warn(`notificar: llamada con el secreto ANTERIOR desde "${req.headers.get("user-agent") ?? "?"}" — cámbiala antes de borrar MXP_SECRETO_CARTERO_ANTERIOR`);
  }
  if (!vapidListo) {
    webpush.setVapidDetails("mailto:info@mxpes.com", VAPID_PUBLICA, VAPID_PRIVADA);
    vapidListo = true;
  }

  let carga: Record<string, unknown> = {};
  try { carga = await req.json(); } catch { /* cuerpo vacío */ }

  // Entrada directa {titulo, cuerpo} o disparador de la base {table, record}
  let titulo = carga.titulo as string | undefined;
  let cuerpo = carga.cuerpo as string | undefined;
  const record = carga.record as Record<string, unknown> | undefined;
  if (!titulo && record) {
    if (carga.table === "pendientes") {
      titulo = "🔴 Pendiente nuevo del equipo";
      cuerpo = String(record.descripcion || "").slice(0, 160);
    } else if (carga.table === "horas") {
      titulo = "⏱ Reporte de horas del equipo";
      cuerpo = `${record.horas} h · ${record.fase || ""} · ${record.fecha || ""}`.slice(0, 160);
    } else {
      return Response.json({ ignorado: true });
    }
  }
  if (!titulo) return new Response("sin contenido", { status: 400 });

  // El cartero corre DENTRO de Supabase: usa las llaves internas del
  // servidor (nunca salen de aquí) para leer los teléfonos registrados.
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  // Filtro del chat: "para" = solo esa persona · "excepto" = todos menos esa
  let consulta = sb.from("push_suscripciones").select("*");
  const para = carga.para as string | null | undefined;
  const excepto = carga.excepto as string | null | undefined;
  if (para) consulta = consulta.eq("usuario_id", para);
  else if (excepto) consulta = consulta.neq("usuario_id", excepto);
  const { data: subs, error } = await consulta;
  if (error) return Response.json({ error: error.message }, { status: 500 });

  let enviadas = 0, eliminadas = 0, fallos = 0;
  for (const s of subs ?? []) {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({ titulo, cuerpo: cuerpo || "" }),
      );
      enviadas++;
    } catch (e) {
      const st = (e as { statusCode?: number }).statusCode;
      if (st === 404 || st === 410) {
        // Ese teléfono ya no existe (app borrada): se limpia solo
        await sb.from("push_suscripciones").delete().eq("id", s.id);
        eliminadas++;
      } else fallos++;
    }
  }
  return Response.json({ enviadas, eliminadas, fallos });
});
