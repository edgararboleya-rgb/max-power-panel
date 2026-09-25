// ============================================================
// Max Power — Dos idiomas (ES por defecto / EN con el botón 🌐)
// La interfaz se traduce; lo que escribe el equipo (nombres,
// notas, pendientes) se queda tal cual — es contenido, no botones.
// Funciona sin tocar el resto del código: un observador traduce
// todo lo que la app pinta, usando este diccionario.
// ============================================================

(function () {
  "use strict";

  const idioma = localStorage.getItem("mxp_idioma") || "es";

  // Botón del membrete: muestra el idioma AL QUE cambias
  const btn = document.getElementById("btn-idioma");
  if (btn) {
    btn.textContent = idioma === "en" ? "ES" : "EN";
    btn.addEventListener("click", () => {
      localStorage.setItem("mxp_idioma", idioma === "en" ? "es" : "en");
      location.reload();
    });
  }
  if (idioma !== "en") return; // en español no hay nada que hacer

  // ---------- Diccionario ES → EN ----------
  const D = {
    // Portada
    "Usuario": "Username", "Contraseña": "Password", "Entrar": "Sign in",
    "Entrando…": "Signing in…", "Usuario o contraseña incorrectos.": "Wrong username or password.",
    "Power done right the first time.": "Power done right the first time.",
    "¿No puedes entrar?": "Can't sign in?",
    "Pídele a Edgar que te cambie la contraseña.": "Ask Edgar to reset your password.",
    // Membrete y navegación
    "Salir": "Log out", "Panel de proyectos": "Projects panel", "Categorías": "Categories",
    "+ Nuevo proyecto": "+ New project", "Cargando…": "Loading…",
    "Reportar mis horas": "Report my hours", "Calendario": "Calendar",
    "Materiales": "Materials", "Gastos": "Expenses",
    "Proyectos Comerciales": "Commercial Projects", "Proyectos Residenciales": "Residential Projects",
    "Servicios": "Services", "Compras y arranque": "Purchases & kickoff",
    "Solo dueño": "Owner only", "Control de gastos": "Expense control",
    "Reporte diario": "Daily report", "Mis horas": "My hours", "Programación": "Schedule",
    // Estados y etapas
    "Enviado": "Sent", "Aprobado": "Approved", "En ejecución": "In progress",
    "En pausa": "On hold", "Completado": "Completed",
    "No aprobado": "Not approved",
    "Checklist": "Checklist",
    "Trabajo por hacer": "Work to do",
    "✅ Abrir el checklist": "✅ Open the checklist",
    "✅ Abrir el checklist completo": "✅ Open the full checklist",
    "✅ Nada urgente ahora mismo": "✅ Nothing urgent right now",
    "🔴 Es urgente — frena el trabajo": "🔴 It's urgent — blocks the work",
    "Urgente": "Urgent",
    "Intermedio": "In between",
    "Puede esperar": "Can wait",
    "🟡 Intermedio": "🟡 In between",
    "🔴 Urgente": "🔴 Urgent",
    "⚪ Puede esperar": "⚪ Can wait",
    "Categoría": "Category",
    "Categoría de la tarea": "Task category",
    "Descripción": "Description",
    "+ Agregar una nueva": "+ Add a new one",
    "Agregar ✓": "Add ✓",
    "por hacer": "to do",
    "✅ al día": "✅ all caught up",
    "sin tareas": "no tasks",
    "📂 Ver la ficha del proyecto": "📂 Open the project file",
    "Marcar completada": "Mark completed",
    "Devolver a pendiente": "Reopen",
    "Corregir el texto": "Fix the text",
    "📌 Generales (sin proyecto)": "📌 General (no project)",
    "💬 Mensajes": "💬 Messages",
    "Mensajes para el equipo de obra": "Messages for the field crew",
    "Corregir horas o notas": "Fix hours or notes",
    "Eliminar reporte": "Delete report",
    "✓ Dar permiso": "✓ Grant permission",
    "Darle permiso": "Grant permission",
    "Sin reportes en los últimos 14 días.": "No reports in the last 14 days.",
    "Pendientes que reportó (se manejan en el ✅ Checklist):": "Issues they reported (managed in the ✅ Checklist):",
    "Mensajes del equipo": "Team messages",
    "Equipo Max Power": "Max Power team",
    "Mensajes para todo el equipo": "Messages for the whole team",
    "Mensaje privado — solo lo ven ustedes dos": "Private message — only you two can see it",
    "Escribe un mensaje…": "Type a message…",
    "🔒 privado": "🔒 private",
    "Todavía no hay mensajes — escribe el primero.": "No messages yet — write the first one.",
    "Conversaciones": "Conversations",
    "Cargando…": "Loading…",
    "Nada pendiente por aquí. 👌": "Nothing pending here. 👌",
    "Sin tareas todavía — agrega la primera.": "No tasks yet — add the first one.",
    "No salieron — fuera de las estadísticas": "Didn't land — excluded from the stats",
    "Obras activas con fases en curso": "Active jobs with phases underway",
    "Aceptados, pendientes de arrancar": "Accepted, waiting to start",
    "Propuestas esperando respuesta": "Proposals awaiting response",
    "Detenidos temporalmente": "Temporarily on hold",
    "Terminados y cerrados": "Finished and closed",
    // Inicio
    "📅 Hoy en Max Power": "📅 Today at Max Power",
    "HOY": "TODAY", "MAÑANA": "TOMORROW",
    "Nada programado para hoy ni mañana.": "Nothing scheduled for today or tomorrow.",
    "⚠ Avisos": "⚠ Alerts",
    "⏱ Reporte de horas del equipo": "⏱ Team hours report",
    "reportó hoy ✓": "reported today ✓", "reportó ayer ✓": "reported yesterday ✓",
    "sin reportes todavía": "no reports yet",
    "Ver calendario →": "See calendar →", "✓ Resuelto": "✓ Resolved",
    // Resumen del dueño
    "Proyectos activos": "Active projects", "Contratado activo": "Active contracted",
    "Cobrado a la fecha": "Collected to date", "Por cobrar": "Outstanding",
    "Facturas sin pagar": "Unpaid invoices",
    // Lista y ficha
    "Buscar proyecto, cliente o dirección…": "Search project, client or address…",
    "No hay proyectos aquí.": "No projects here.",
    "Ver proyecto completo": "View full project",
    "Situación": "Status", "Próxima acción": "Next action",
    "Fase de obra": "Job phase", "Servicio": "Service", "Horas — plan vs. real": "Hours — plan vs. actual",
    "Desglose del contrato": "Contract breakdown", "Hitos de pago": "Payment milestones",
    "Rentabilidad y gastos": "Profit & expenses", "Ayuda externa (por día o por ajuste)": "Outside help (daily or lump sum)",
    "Permisos e inspecciones": "Permits & inspections", "Fotos de obra": "Job photos",
    "Documentos en Drive": "Documents in Drive", "Facturas (QuickBooks)": "Invoices (QuickBooks)",
    "Acciones": "Actions", "Contrato": "Contract", "Cobrado": "Collected", "Falta": "Remaining",
    "Alcance del trabajo — ¿qué se dijo que se iba a hacer?": "Scope of work — what was promised?",
    "🚀 Arranque — lo que falta para empezar": "🚀 Kickoff — what's missing to start",
    "Ver en Materiales ›": "See in Materials ›",
    "Margen real": "Real margin", "Mano de obra": "Labor", "Materiales comprados": "Materials purchased",
    "Ayuda externa": "Outside help", "completado ·": "complete ·",
    "✓ Marcar aprobado": "✓ Mark approved", "▶ Iniciar ejecución": "▶ Start work",
    "Fase siguiente ▶": "Next phase ▶", "◀ Fase anterior": "◀ Previous phase",
    "⏸ Pausar": "⏸ Pause", "✓ Marcar completado": "✓ Mark completed",
    "▶ Reanudar ejecución": "▶ Resume work", "↩ Reabrir (a ejecución)": "↩ Reopen (to in-progress)",
    "🗑 Eliminar proyecto…": "🗑 Delete project…",
    // Materiales
    "Todos los proyectos": "All projects", "Ver": "View",
    "Nada pendiente de comprar. 👌": "Nothing left to buy. 👌",
    "Sin gestiones pendientes.": "No pending tasks.",
    "Sin recibos todavía.": "No receipts yet.", "Sin fotos todavía.": "No photos yet.",
    "🧾 Compras y recibos": "🧾 Purchases & receipts", "🛒 Registrar compra": "🛒 Log a purchase",
    "📷 Con foto del recibo": "📷 With receipt photo", "✍️ Sin recibo — anotar a mano": "✍️ No receipt — enter by hand",
    "¿Dónde se compró?": "Where was it bought?", "¿Qué se compró? (los materiales)": "What was bought? (the materials)",
    "✓ Registrar la compra": "✓ Log the purchase", "Edgar le pone el total después con el ✎.": "Edgar adds the total later with ✎.",
    "⬆ Subir recibo": "⬆ Upload receipt", "POR LEER": "TO READ", "LEÍDO": "READ", "CONCILIADO ✓": "RECONCILED ✓",
    "+ Agregar gestión": "+ Add task", "+ Agregar material": "+ Add material",
    "Agregar material": "Add material", "Agregar a la lista": "Add to list",
    "Comprados recientes": "Recently purchased", "✓ Comprado": "✓ Purchased", "✓ Hecha": "✓ Done",
    "Proyecto": "Project", "Cantidad (opcional)": "Quantity (optional)", "Cantidad": "Quantity",
    "🔴 Pendientes de obra que suenan a material": "🔴 Site issues that sound like materials",
    "→ Pasar a la lista": "→ Move to list",
    "Gestión (qué hay que hacer)": "Task (what needs doing)",
    "Foto del recibo (cámara o galería)": "Receipt photo (camera or gallery)",
    "📸 Agregar foto o video": "📸 Add photo or video", "Foto o video corto (cámara o galería)": "Photo or short video (camera or gallery)",
    "⬆ Subir foto": "⬆ Upload photo", "⬆ Subir video": "⬆ Upload video",
    "Nota (opcional)": "Note (optional)", "Proveedor (opcional)": "Vendor (optional)",
    "Guardar cambios": "Save changes", "🗑 Eliminar": "🗑 Delete", "Guardar": "Save",
    // Horas
    "Fecha": "Date", "Horas trabajadas": "Hours worked", "Horas": "Hours",
    "Fase / tipo de trabajo": "Phase / type of work", "Notas (qué se hizo)": "Notes (what was done)",
    "✓ Guardar mi reporte": "✓ Save my report",
    "Mis reportes (toca ✎ para corregir)": "My reports (tap ✎ to fix)",
    "Notas (aquí puedes agregar lo que te faltó)": "Notes (add what you missed here)",
    // Calendario
    "Lun": "Mon", "Mar": "Tue", "Mié": "Wed", "Jue": "Thu", "Vie": "Fri", "Sáb": "Sat", "Dom": "Sun",
    "Agregar a este día": "Add to this day", "Hora (opcional)": "Time (optional)",
    "Tipo": "Type", "Descripción": "Description", "Evento / visita": "Event / visit",
    "⚠ Pendiente / bloqueo": "⚠ Issue / blocker",
    "Nada programado este día.": "Nothing scheduled this day.",
    "Hoy": "Today", "Con trabajo": "Has work", "Sin programar": "Unscheduled",
    "Pendiente sin resolver": "Unresolved issue",
    // Gastos
    "💲 Costos del equipo": "💲 Team costs", "Guardar costos": "Save costs",
    "👥 Equipo": "👥 Team", "Marcar inactivo": "Mark inactive", "Reactivar": "Reactivate",
    "Presupuesto de materiales ($)": "Materials budget ($)", "💾 Guardar": "💾 Save",
    "No hay proyectos activos.": "No active projects.",
    "Total por cobrar": "Total outstanding", "Precio total del contrato": "Total contract price",
    // Pie
    "FL EC LICENSE #EC13016045": "FL EC LICENSE #EC13016045"
  };

  // Frases con números o partes variables
  const REGLAS = [
    [/^Por comprar \((\d+)\)$/, "To buy ($1)"],
    [/^🚀 Gestiones de arranque \((\d+)\)$/, "🚀 Kickoff tasks ($1)"],
    [/^(\d+) activos · (\d+) en ejecución$/, "$1 active · $2 in progress"],
    [/^(.+) contratado activo$/, "$1 active contracted"],
    [/^quedan ([\d.]+) h$/, "$1 h left"],
    [/^de ([\d.]+) h estimadas$/, "of $1 estimated h"],
    [/^(\d+)% cobrado$/, "$1% collected"],
    [/^(\d+) de (\d+) puntos$/, "$1 of $2 items"],
    [/^🔧 Avance de obra:$/, "🔧 Job progress:"],
    [/^hace (\d+) días$/, "$1 days ago"],
    [/^Vale hasta (\d{4}-\d{2}-\d{2})$/, "Valid until $1"],
    [/^Venció el (\d{4}-\d{2}-\d{2})$/, "Expired on $1"],
    [/^Venció el (\d{4}-\d{2}-\d{2}) · no se puede firmar$/, "Expired on $1 · cannot be signed"],
    [/^Venció el (\d{4}-\d{2}-\d{2}): el cliente ya no puede firmarlo con estos precios$/, "Expired on $1: the client can no longer sign it at these prices"],
    [/^Cambiar hasta cuándo vale \((\d{4}-\d{2}-\d{2})\)$/, "Change validity date ($1)"],
    [/^hace (\d+) días sin reportar$/, "$1 days without reporting"],
    [/^material(es)? por comprar — toca para ver la lista$/, "material$1 to buy — tap to see the list"],
    [/para arrancar$/, s => s
      .replace("materiales", "materials").replace("material", "material")
      .replace("gestiones", "tasks").replace("gestión", "task")
      .replace(" y ", " and ").replace("para arrancar", "to start")],
    [/^➡ Próximo cobro:$/, "➡ Next collection:"],
    [/^(\d+) por hacer/, "$1 to do"],
    [/^🔴 Lo urgente ahora \((\d+)\)$/, "🔴 Urgent right now ($1)"],
    [/ · toca para ver sus reportes$/, " · tap to see their reports"]
  ];

  Object.assign(D, {
    "¿Con quién es el trato?": "Who is the deal with?", "Cómo es el trato": "Type of deal",
    "Directo — con el cliente": "Direct — with the client",
    "Solo referido — el dueño firma y paga": "Referral only — the owner signs and pays",
    "Contrato con el contratista — le facturamos a él": "Contract with the contractor — we bill them",
    "Cliente final (dueño de la propiedad)": "End client (property owner)",
    "Correo del cliente (opcional)": "Client email (optional)", "Teléfono del cliente (opcional)": "Client phone (optional)",
    "Correo del cliente": "Client email", "Teléfono del cliente": "Client phone",
    "Quién coordina esta obra por parte del contratista (opcional)": "Contractor's coordinator for this job (optional)"
  });
  // ---------- Ficha v2 (P179): tablero + pestañas + hojas ----------
  Object.assign(D, {
    // Pestañas y tablero
    "Resumen": "Summary", "Obra": "Job", "Dinero": "Money", "Cliente": "Client", "Archivos": "Files",
    "Foto": "Photo", "Agregar": "Add", "Ir": "Go", "🧭 Ir": "🧭 Go", "Abrir en el mapa": "Open in maps",
    "Secciones de la obra": "Job sections",
    "Marcar aprobado": "Mark approved", "Iniciar ejecución": "Start work",
    "Marcar completado": "Mark completed", "Reanudar ejecución": "Resume work",
    "Pausar": "Pause", "Reabrir (a ejecución)": "Reopen (to in-progress)",
    "Escribir el alcance": "Write the scope", "Deshacer": "Undo", "Fase devuelta ✓": "Phase restored ✓",
    "Estimando": "Estimating",
    "Cotizándose — todavía sin precio enviado": "Being estimated — no price sent yet",
    // Fases
    "Inicio / Movilización": "Start / Mobilization", "Rough-in": "Rough-in",
    "Inspección de rough": "Rough inspection", "Trim / Terminación": "Trim / Finish",
    "Inspección final": "Final inspection",
    // Resumen
    "Qué toca ahora": "What's next", "Próximos días de trabajo": "Upcoming work days",
    "📅 Próximos días de trabajo": "📅 Upcoming work days", "Arranque": "Kickoff",
    // Obra
    "Alcance del trabajo": "Scope of work", "Corregir": "Edit", "Sin bloque": "No block",
    "no cuenta para el avance": "not counted in progress",
    "Pendientes de obra": "Job issues", "Checklist de la obra ›": "Job checklist ›",
    "Checklist de la obra": "Job checklist", "Sin pendientes de obra.": "No job issues.",
    "Contrato y cambios (SOW / CO)": "Contract and changes (SOW / CO)",
    "Sin inspecciones anotadas todavía.": "No inspections logged yet.",
    "Programada": "Scheduled", "Pasó": "Passed", "Falló": "Failed", "falló": "failed",
    "Resultado": "Result", "Categoría": "Category", "Renglón": "Item", "Opciones": "Options",
    "Corregir el texto": "Edit the text", "Bloque del portal": "Portal block",
    "Eliminar": "Delete", "Eliminar inspección": "Delete inspection",
    "Inspección guardada ✓": "Inspection saved ✓", "Inspección pasada ✓": "Inspection passed ✓",
    "Inspección eliminada ✓": "Inspection deleted ✓", "Inspección final aprobada": "Final inspection approved",
    // Dinero
    "Facturas": "Invoices", "Por cobrar": "Outstanding", "Marcar cobrada": "Mark paid",
    "Total facturado": "Total invoiced", "(sin la #1110, que es personal)": "(excluding #1110, personal)",
    "Facturar": "Invoice", "Ya cobré": "Paid", "Ya cobré sin factura": "Paid without invoice",
    "Release": "Release", "Release del pago": "Payment release", "Facturando…": "Invoicing…",
    "Rentabilidad": "Profitability", "Crea la factura con las reglas de la casa": "Creates the invoice with the house rules",
    "Factura sin cobrar": "Unpaid invoice", "Próximo cobro": "Next payment",
    "Cobrado no cuadra": "Collected doesn't match", "El cliente decide": "Client decides",
    // Cliente
    "Qué ve el cliente": "What the client sees", "Ve el dinero:": "Sees money:",
    "Acceso completo:": "Full access:", "SÍ": "YES", "NO": "NO",
    "Última visita:": "Last visit:", "(hora de Florida)": "(Florida time)",
    "¿Qué ve exactamente?": "What exactly do they see?", "Compartir y avisar": "Share and notify",
    "Email del cliente:": "Client email:", "sin anotar": "not set",
    "Dónde vamos": "Where we are", "📣 Dónde vamos": "📣 Where we are",
    "Cambiar el resumen": "Edit the summary", "Escribir el resumen": "Write the summary",
    "Decisiones del cliente": "Client decisions", "Decisión del cliente": "Client decision",
    "Sin decisiones pendientes del cliente.": "No pending client decisions.",
    "Marcar decidida": "Mark decided", "Contratista": "Contractor",
    "Solo coordinan": "Coordination only", "Le facturamos a ellos": "We bill them",
    "Notice to Owner (opcional) · sin anotar": "Notice to Owner (optional) · not logged",
    "Mándalo solo si crees que el cobro puede complicarse; el plazo es de 45 días desde el primer día de trabajo.":
      "Send it only if you think payment may get complicated; the deadline is 45 days from the first day of work.",
    "Anotar envío": "Log sent", "Cambiar contratista o coordinador": "Change contractor or coordinator",
    "Asignar un contratista": "Assign a contractor", "Obra directa: sin contratista.": "Direct job: no contractor.",
    "Cada vez que lo abrieron desde el portal, en hora de Florida": "Each time it was opened from the portal, in Florida time",
    // Compartir
    "Copiar el link del cliente": "Copy the client link", "Corregir el email del cliente": "Edit the client email",
    "Enlace a esta obra": "Link to this job", "Enlace a todas sus obras": "Link to all their jobs",
    "Avisar al contratista": "Notify the contractor", "Regenerar la llave del cliente": "Regenerate the client key",
    "El link viejo deja de funcionar": "The old link stops working",
    "Pasó la inspección": "Inspection passed", "Se emitió una factura": "An invoice was issued",
    "Licencia y seguros al día": "License and insurance up to date",
    "Hay un contrato esperando su firma": "A contract is waiting for their signature",
    // Archivos y documentos
    "Documentos": "Documents", "RFIs": "RFIs", "Oculto": "Hidden", "Lo ve": "Visible",
    "Lo ve (luz verde)": "Visible (green light)", "Pide firma": "Signature requested",
    "Pide aprobación": "Approval requested", "Firmado · falta tu firma": "Signed · your signature missing",
    "Firmaste tú · falta el cliente": "You signed · client missing", "Firmado por los dos": "Signed by both",
    "Aprobó": "Approved", "Enseñar al cliente": "Show to client", "Ocultar al cliente": "Hide from client",
    "Pedir firma": "Request signature", "Quitar la firma pedida": "Remove signature request",
    "Pedir aprobación": "Request approval", "Quitar la aprobación pedida": "Remove approval request",
    "Firmar yo (Edgar Arboleya)": "Sign myself (Edgar Arboleya)",
    "Ponerle fecha de validez": "Set a validity date", "Renovar la fecha de validez": "Renew the validity date",
    "¿Hasta qué día puede firmarlo el cliente con estos precios?": "Until what day can the client sign it at these prices?",
    "Después de ese día el portal no le deja firmar y le pide el precio al día.": "After that day the portal won't let them sign and asks for an updated price.",
    "Ya venció: con una fecha nueva el cliente vuelve a poder firmarlo. Revisa antes que los precios sigan valiendo.": "It expired: with a new date the client can sign it again. Check first that the prices still hold.",
    "Enseñársela al cliente": "Show it to the client", "El cliente la ve · ocultársela": "Client sees it · hide it",
    "Corregir la nota": "Edit the note", "Abrir el original": "Open the original",
    "El cliente ve todas las fotos (luz verde)": "The client sees all photos (green light)",
    "Luz verde encendida: el cliente ve todos los documentos.": "Green light on: the client sees all documents.",
    "Luz verde encendida: el cliente ve todos los documentos, fotos y videos de esta obra.":
      "Green light on: the client sees all documents, photos and videos of this job.",
    // Hojas
    "Cancelar": "Cancel", "Cerrar": "Close", "Siguiente paso": "Next step", "Otras acciones": "Other actions",
    "Cambiar a otro estado": "Change to another status", "Zona de peligro": "Danger zone",
    "Eliminar esta obra…": "Delete this job…",
    "Borra la obra con todo lo suyo. Antes baja una copia y pide escribir ELIMINAR.":
      "Deletes the job and everything in it. It downloads a copy first and asks you to type ELIMINAR.",
    "Agregar a esta obra": "Add to this job", "Foto o video con nota": "Photo or video with a note",
    "De la galería, un video corto o con descripción. La cámara del tablero sube solo fotos, sin nota.":
      "From the gallery, a short video or with a description. The dashboard camera uploads photos only, without a note.",
    "Pendiente de obra": "Job issue", "Se anota en la Checklist de esta obra": "It goes on this job's checklist",
    "Inspección": "Inspection", "Documento o RFI": "Document or RFI", "Trabajo externo": "Outside work",
    "Fases de la obra": "Job phases",
    "Abre la cámara y sube la foto a esta obra (sin nota)": "Opens the camera and uploads the photo to this job (no note)",
    "Opciones del renglón": "Item options",
    // Lista
    "Abrir la obra ›": "Open job ›", "Abrir la obra": "Open job",
    "Se actualizó la pantalla: vuelve a elegir el archivo.": "The screen refreshed: pick the file again.",
    // Renglones de la ficha (tanda 2)
    "Todavía no hay renglones. Nacen solos al armar el contrato en «Escribir el alcance».":
      "No items yet. They are created when you build the contract in «Write the scope».",
    "Video": "Video", "El cliente la ve": "The client sees it", "PRÓXIMO": "NEXT",
    "Agregar foto o video": "Add photo or video", "dinero personal: no cuenta en la obra": "personal money: not counted in the job",
    "Sin trabajos externos anotados.": "No outside work logged.",
    "Este proyecto no tiene documentos todavía.": "This job has no documents yet.",
    "Guardar inspección": "Save inspection", "Guardar documento": "Save document",
    "la necesitamos antes del": "we need it before",
    // Arreglos de la revisión de la ficha
    "le facturamos a ellos": "we bill them", "solo coordinan": "coordination only",
    "Cobrando…": "Collecting…", "Firmado": "Signed", "Firmaste tú": "You signed",
    "Firmado · falta la firma de Edgar": "Signed · Edgar's signature missing",
    "faltan recibos": "receipts missing",
    "Ese hito ya se está facturando: espera a que termine.": "That milestone is already being invoiced: wait until it finishes.",
    "Ese hito ya se está guardando: espera a que termine.": "That milestone is already being saved: wait until it finishes.",
    "Esa factura ya se está guardando: espera a que termine.": "That invoice is already being saved: wait until it finishes.",
    "No encuentro a ese contratista en la lista: cámbialo en «Cambiar contratista o coordinador».":
      "I can't find that contractor in the list: change it in «Change contractor or coordinator».",
    "Solo Edgar puede firmar en su nombre.": "Only Edgar can sign in his name."
  });

  // Solo traduce "Pasar a …" / "Volver a …" cuando lo de detrás es una fase o un estado
  // conocido: hay otros botones que empiezan igual ("Volver a la hoja") y no son esto.
  const conocido = (s, prefijo, en) => {
    const resto = s.slice(prefijo.length);
    return D[resto] !== undefined ? en + D[resto] : s;
  };
  const ESTADO_ES = /^(Estimando|Enviado|Aprobado|En ejecución|En pausa|Completado|No aprobado) · /;
  REGLAS.push(
    [/^Pasar a (.+)$/, s => conocido(s, "Pasar a ", "Move to ")],
    [/^Volver a (.+)$/, s => conocido(s, "Volver a ", "Back to ")],
    [/^Fase: (.+) ✓$/, s => { const f = s.slice(6, -2); return D[f] !== undefined ? "Phase: " + D[f] + " ✓" : s; }],
    [/^fase (\d+) de (\d+)$/, "phase $1 of $2"],
    [/^(\d+) de (\d+) · (\d+)%$/, "$1 of $2 · $3%"],
    [/^(\d+) de (\d+)$/, "$1 of $2"],
    [/^(\d+) pendientes? · (\d+) urgentes?$/, "$1 open · $2 urgent"],
    [/^(\d+) pendientes?$/, "$1 open"],
    [/^(\d+) urgentes?$/, "$1 urgent"],
    [/^Alcance (\d+)%$/, "Scope $1%"],
    [/^(\d+) por comprar$/, "$1 to buy"],
    [/^(\d+) gesti(ón|ones)$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " task" : " tasks"); }],
    // "Inspección rough" → "rough inspection"; los avisos que empiezan igual llevan ✓, — o ":" y no entran
    [/^Inspección ([^✓—:]+)$/, "$1 inspection"],
    [/^(\d+) facturas sin cobrar$/, "$1 unpaid invoices"],
    [/^Hechos \((\d+)\)$/, "Done ($1)"], [/^Resueltos \((\d+)\)$/, "Resolved ($1)"],
    [/^Cobradas \((\d+)\)$/, "Paid ($1)"], [/^Cobrados \((\d+)\)$/, "Collected ($1)"],
    [/^Ver las (\d+)$/, "See all $1"], [/^Ver (\d+) más$/, "See $1 more"],
    [/^Últimos reportes \((\d+)\)$/, "Latest reports ($1)"],
    [/^Pendientes de obra \((\d+)\)$/, "Job issues ($1)"], [/^Fotos de obra \((\d+)\)$/, "Job photos ($1)"],
    [/^margen (-?\d+)%$/, "margin $1%"],
    [/^Cobrado (\d+)% · falta (.+)$/, "Collected $1% · $2 left"],
    [/^Cobrado (\d+)%$/, "Collected $1%"],
    [/^falta (-?\$.+)$/, "$1 left"],
    [/^\(?abonó (.+) de ([^)]+)\)?$/, s => s.replace(/abonó (.+) de ([^)]+)/, "paid $1 of $2")],
    [/^vía (.+)$/, s => "via " + s.slice(4)
      .replace(/\(contrato con ellos\)$/, "(contract with them)").replace(/\(referido\)$/, "(referral)")
      .replace(/ \+ directo$/, " + direct")],
    [/^¿Qué le aviso a (.+)\?$/, "What should I tell $1?"],
    [/^Factura #(\S+) sin cobrar · (.+)$/, "Invoice #$1 unpaid · $2"],
    [/^Email del cliente: (.+)$/, "Client email: $1"],
    [/^Notice to Owner mandado el (.+)$/, "Notice to Owner sent on $1"],
    // "Rough-in 2/5" de la tarjeta de la lista
    [/^(.+) (\d+)\/(\d+)$/, s => { const m = s.match(/^(.+) (\d+)\/(\d+)$/); return D[m[1]] !== undefined ? D[m[1]] + " " + m[2] + "/" + m[3] : s; }],
    // Subtítulo de la hoja Estado: "En ejecución · Rough-in · Origen: …"
    [ESTADO_ES, s => s.split(" · ").map(p => D[p] !== undefined ? D[p] : p.replace(/^Origen: /, "Source: ")).join(" · ")],
    // La historia de un documento (hoja del botón de estado)
    [/^Firmó (.+) · (.+)$/, "Signed by $1 · $2"],
    [/^Contrafirmado (.+)$/, "Countersigned $1"],
    [/^Aprobó (.+)$/, "Approved $1"],
    [/^Visto (.+)$/, "Seen $1"],
    [/^El (cliente|contratista) lo abrió (\d+) (vez|veces) · última (.+) \(hora de Florida\)$/, s => {
      const m = s.match(/^El (cliente|contratista) lo abrió (\d+) (vez|veces) · última (.+) \(hora de Florida\)$/);
      return `The ${m[1] === "cliente" ? "client" : "contractor"} opened it ${m[2]} ${m[2] === "1" ? "time" : "times"} · last ${m[4]} (Florida time)`;
    }]
  );
  function traducirTexto(t) {
    const limpio = t.trim();
    if (!limpio) return t;
    if (D[limpio] !== undefined) return t.replace(limpio, D[limpio]);
    for (const [re, out] of REGLAS) {
      if (re.test(limpio)) {
        const traducido = typeof out === "function" ? out(limpio) : limpio.replace(re, out);
        return t.replace(limpio, traducido);
      }
    }
    return t;
  }

  function traducirNodo(raiz) {
    // Lo marcado data-no-i18n es CONTENIDO del usuario (chat) — no se traduce
    const walker = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT, {
      acceptNode: n => (n.parentElement && n.parentElement.closest("[data-no-i18n]"))
        ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
    });
    let n;
    while ((n = walker.nextNode())) {
      const nuevo = traducirTexto(n.nodeValue);
      if (nuevo !== n.nodeValue) n.nodeValue = nuevo;
    }
    // Los atributos que se leen o se oyen (placeholder, title, aria-label), también
    // en el propio nodo que se acaba de pintar, no solo en sus hijos
    const SEL_ATTR = "[placeholder], [title], [aria-label]";
    const conAttr = raiz.querySelectorAll ? Array.from(raiz.querySelectorAll(SEL_ATTR)) : [];
    if (raiz.matches && raiz.matches(SEL_ATTR)) conAttr.push(raiz);
    conAttr.forEach(el => {
      if (el.placeholder && D[el.placeholder]) el.placeholder = D[el.placeholder];
      if (el.title && D[el.title]) el.title = D[el.title];
      const aria = el.getAttribute("aria-label");
      if (aria && D[aria]) el.setAttribute("aria-label", D[aria]);
    });
  }

  // Traducción inicial + observador: todo lo que la app pinte se traduce solo
  traducirNodo(document.body);
  new MutationObserver(muts => {
    for (const m of muts) {
      m.addedNodes.forEach(nodo => {
        if (nodo.nodeType === 1) traducirNodo(nodo);
        else if (nodo.nodeType === 3) {
          const nuevo = traducirTexto(nodo.nodeValue);
          if (nuevo !== nodo.nodeValue) nodo.nodeValue = nuevo;
        }
      });
    }
  }).observe(document.body, { childList: true, subtree: true });
})();
