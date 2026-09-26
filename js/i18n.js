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
    "Nada programado.": "Nothing scheduled.", "ver el calendario": "see the calendar",
    "¿Eliminar esta tarea?": "Delete this task?",
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
    // Solo la cola «— N materiales y N gestiones para arrancar»: el nombre de la obra no se toca
    [/^(.+) — ((?:\d+ material(?:es)?)?(?: y )?(?:\d+ gesti(?:ón|ones))?) para arrancar$/, s => {
      const m = s.match(/^(.+) — ((?:\d+ material(?:es)?)?(?: y )?(?:\d+ gesti(?:ón|ones))?) para arrancar$/);
      return m[1] + " — " + m[2].replace(/materiales/, "materials").replace(/gestiones/, "tasks").replace(/gestión/, "task").replace(" y ", " and ") + " to start";
    }],
    [/^➡ Próximo cobro:$/, "➡ Next collection:"],
    [/^(\d+) por hacer/, "$1 to do"],
    [/^🔴 Lo urgente ahora \((\d+)\)$/, "🔴 Urgent right now ($1)"]
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
    [/^Inspección ([^✓—:/]+)$/, "$1 inspection"],
    [/^(\d+) facturas sin cobrar$/, "$1 unpaid invoices"],
    [/^Hechos \((\d+)\)$/, "Done ($1)"], [/^Resueltos \((\d+)\)$/, "Resolved ($1)"],
    [/^Cobradas \((\d+)\)$/, "Collected ($1)"], [/^Cobrados \((\d+)\)$/, "Collected ($1)"],
    [/^Ver las (\d+)$/, "See all $1"], [/^Ver (\d+) más$/, "See $1 more"],
    [/^Últimos reportes \((\d+)\)$/, "Latest reports ($1)"],
    [/^Pendientes de obra \((\d+)\)$/, "Open job items ($1)"], [/^Fotos de obra \((\d+)\)$/, "Job photos ($1)"],
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
    [/^Contrafirmado (\d.*)$/, "Countersigned $1"],
    [/^Aprobó (\d.*)$/, "Approved $1"],
    [/^Visto (\d.*)$/, "Viewed $1"],
    [/^El (cliente|contratista) lo abrió (\d+) (vez|veces) · última (.+) \(hora de Florida\)$/, s => {
      const m = s.match(/^El (cliente|contratista) lo abrió (\d+) (vez|veces) · última (.+) \(hora de Florida\)$/);
      return `The ${m[1] === "cliente" ? "client" : "contractor"} opened it ${m[2]} ${m[2] === "1" ? "time" : "times"} · last ${m[4]} (Florida time)`;
    }]
  );
  // ---------- La pantalla «Hoy» del equipo de campo («Cobre y luz», tanda 2) ----------
  Object.assign(D, {
    "Ahora": "Now", "Alcance del día": "Today's scope", "Cómo llegar": "Directions",
    "Horas reportadas": "Hours reported", "Hoy no tienes visita programada": "No visit scheduled for you today",
    "Tareas de hoy": "Today's tasks", "Ver todo el checklist": "See the full checklist",
    "Nada pendiente en esta obra.": "Nothing open on this job.", "Nada urgente ahora mismo.": "Nothing urgent right now.",
    "Marcar hecha": "Mark done", "Regla del día": "Rule of the day",
    "Fotos de hoy": "Today's photos", "Tomar": "Take", "Todavía no hay fotos de hoy": "No photos yet today",
    "Foto de hoy": "Today's photo",
    "Nota para Edgar": "Note for Edgar", "Ej.: faltó un breaker de 20 A": "E.g.: we're short a 20 A breaker",
    "Enviar": "Send", "Enviado a Edgar ✓": "Sent to Edgar ✓",
    "Proyectos": "Projects", "Chat": "Chat", "Menú de abajo": "Bottom menu",
    // Las 14 reglas del día, en inglés de obra
    "Antes de tocar un conductor, pruébalo con el tester aunque el breaker esté abajo. El tester manda, no la memoria.":
      "Before you touch a conductor, test it with the tester even if the breaker is off. Trust the tester, not your memory.",
    "Breaker abajo y con candado o cinta con tu nombre. Nadie lo sube sin preguntarte.":
      "Breaker off and locked out or taped with your name. Nobody flips it back on without asking you.",
    "Al panel abierto no se le da la espalda: cierra la tapa si te alejas, aunque sea un minuto.":
      "Never turn your back on an open panel: close the cover if you step away, even for a minute.",
    "Guantes y lentes para cortar, pelar y taladrar. Los ojos no se reponen.":
      "Gloves and safety glasses to cut, strip and drill. You don't get new eyes.",
    "Escalera en piso firme y con los dos pies dentro. Nada de subirse al último escalón.":
      "Ladder on solid ground and both feet inside the rails. Never stand on the top step.",
    "GFCI en baños, toda la cocina, garaje, exterior, laundry y a menos de 6 pies de cualquier fregadero.":
      "GFCI in bathrooms, the whole kitchen, garage, outdoors, laundry and within 6 feet of any sink.",
    "Las varillas de tierra van a 6 pies o más una de otra, y el cable a las varillas nunca más grueso que #6.":
      "Ground rods go 6 feet or more apart, and the wire to the rods never needs to be bigger than #6.",
    "Cargador EV: breaker al 125 % de la carga. 48 A pide breaker de 60 A y #6 THHN en tubería, no Romex.":
      "EV charger: breaker at 125% of the load. 48 A needs a 60 A breaker and #6 THHN in conduit, not Romex.",
    "Delante del panel: 36 pulgadas de fondo libres y 30 de ancho. Ahí no se guarda nada.":
      "In front of the panel: 36 inches deep and 30 inches wide kept clear. Nothing gets stored there.",
    "Zanja de PVC a 18 pulgadas; cable directo (UF) a 24. Fotos antes de tapar.":
      "PVC trench at 18 inches; direct-burial cable (UF) at 24. Photos before you backfill.",
    "Caja llena no se fuerza: cuenta los cables (#12 = 2.25 in³ cada uno, el dispositivo cuenta doble).":
      "Don't force a full box: count the wires (#12 = 2.25 in³ each, the device counts double).",
    "Aprieta los terminales al torque que dice el equipo. Un tornillo flojo es un incendio lento.":
      "Torque the terminals to the value on the equipment. A loose screw is a slow fire.",
    "Cada breaker con su nombre en el directorio, escrito a mano y legible. El siguiente que abra el panel te lo agradece.":
      "Every breaker labeled in the directory, handwritten and legible. The next person who opens the panel will thank you.",
    "Foto de todo lo que se va a tapar: paredes, zanjas, cielos. La foto es la prueba de tu trabajo.":
      "Photograph everything before it gets covered: walls, trenches, ceilings. The photo is proof of your work."
  });
  REGLAS.push(
    [/^Hola, (.+)$/, "Hi, $1"],
    [/^(\d+) visitas? hoy$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " visit today" : " visits today"); }],
    [/^(\d+) tareas?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " task" : " tasks"); }],
    [/^(\d+) fotos? hoy$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " photo today" : " photos today"); }],
    [/^Reportaste ([\d.]+) h en (.+)$/, "You reported $1 h at $2"],
    [/^Después: (.+)$/, "Later: $1"],
    [/^La próxima: (.+)$/, "Next: $1"],
    [/^Panel del proyecto · (\d+)\/(\d+) encendidos$/, "Project panel · $1/$2 on"]
  );
  // ---------- Cabecera limpia, botón flotante y «Hoy» del dueño (25-sep) ----------
  Object.assign(D, {
    // El avatar y la hoja «Perfil»
    "Perfil": "Profile", "Dueño": "Owner", "Equipo de campo": "Field crew", "Licencia": "License",
    "Cambiar la app a español": "Switch the app to Spanish", "Cambiar la app a inglés": "Switch the app to English",
    "Toca para comprobarla": "Tap to check it", "Cambiar de usuario": "Switch user",
    // El botón flotante
    "Asistente y chat": "Assistant and chat", "Preguntarle al asistente": "Ask the assistant",
    "Te contesta y te anota lo que le digas": "It answers and writes down what you tell it",
    "Chat del equipo": "Team chat", "Los mensajes del grupo y los privados": "Group and private messages",
    // Los resúmenes del inicio
    "urgentes": "urgent", "urgente": "urgent", "avisos": "alerts", "aviso": "alert",
    "Ocultar": "Hide", "Nada urgente ahora": "Nothing urgent now",
    "El más viejo es de hoy": "The oldest is from today",
    "Abrir el checklist completo": "Open the full checklist",
    // Las tareas
    "vía Claude": "via Claude", "Tarea eliminada": "Task deleted", "La tarea volvió ✓": "The task is back ✓"
  });
  REGLAS.push(
    [/^Chat del equipo — (\S+) sin leer$/, "Team chat — $1 unread"],
    [/^Versión (\S+)$/, "Version $1"],
    [/^El más viejo lleva (\d+) días?$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `The oldest has been waiting ${n} ${n === 1 ? "day" : "days"}`; }],
    // Los tipos de aviso, en palabras (el número va delante)
    [/^(\d+) propuestas?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " proposal" : " proposals"); }],
    [/^(\d+) de labor$/, "$1 on labor"],
    [/^(\d+) de materiales$/, "$1 on materials"],
    [/^(\d+) facturas? viejas?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " old invoice" : " old invoices"); }],
    [/^(\d+) obras? sin cobrar$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " job not collected" : " jobs not collected"); }],
    [/^(\d+) sin contrato$/, "$1 without a contract"],
    [/^(\d+) para arrancar$/, "$1 to kick off"]
  );
  // ---------- Opción A: Hoy · Proyectos · Más (25-sep) ----------
  Object.assign(D, {
    // La barra de abajo y el lateral
    "Más": "More",
    // Hoy del dueño
    "Vence esta semana": "Due this week", "Nada vence esta semana.": "Nothing is due this week.",
    "hoy": "today", "Propuesta": "Proposal", "Licencia y seguros": "License and insurance",
    "Reporte de horas del equipo": "Team hours report", "Horas de esta semana": "Hours this week",
    // Proyectos
    "Elegir la obra": "Choose the job", "Abrir la ficha completa": "Open the full job file",
    "Levantamiento": "Site survey", "Estimador": "Estimator",
    "Sin tareas todavía": "No tasks yet", "Nada por comprar": "Nothing to buy",
    "próxima:": "next:", "Sin fecha programada": "Nothing scheduled",
    "Contar en la casa": "Count on site", "Sus estimados": "Its estimates",
    "Todas las obras": "All jobs",
    "No hay obras en marcha ahora. En «Todos los proyectos» están todas.": "No jobs in progress right now. «All projects» has every one.",
    "Solo:": "Only:", "Quitar el filtro": "Remove the filter",
    "Esta obra todavía no tiene estimados.": "This job has no estimates yet.",
    // Más
    "Calendario completo": "Full calendar", "Asistente": "Assistant", "Idioma": "Language"
  });
  REGLAS.push(
    [/^venció el (\d+)$/, "expired on the $1"],
    [/^(\d+) de (\d+) hechos$/, "$1 of $2 done"],
    [/^(\d+) por comprar$/, "$1 to buy"],
    [/^(\d+) documentos?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " document" : " documents"); }],
    [/^(\d+) fotos?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " photo" : " photos"); }],
    [/^(\d+) en total$/, "$1 in total"],
    [/^(\d+) levantamientos?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " site survey" : " site surveys"); }],
    [/^(\d+) recibos?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " receipt" : " receipts"); }],
    [/^(\d+) estimados?$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " estimate" : " estimates"); }],
    [/^Estimados de esta obra \((\d+)\)$/, "Estimates for this job ($1)"]
  );
  // ---------- Diccionario completo (26-sep): toda la app, trozo a trozo ----------
  // · parte-I
  // ---------- Trozo I (26-sep): index.html · db.js · alcance.js (pantalla) · repaso del diccionario viejo ----------
    Object.assign(D, {
      // ===== Correcciones a lo viejo (mismas claves, traducción arreglada) =====
      "Intermedio": "Medium", "🟡 Intermedio": "🟡 Medium",
      "Corregir horas o notas": "Edit hours or notes",
      "Mis reportes (toca ✎ para corregir)": "My reports (tap ✎ to edit)",
      "Salir": "Sign out",
      "Proyectos Comerciales": "Commercial projects", "Proyectos Residenciales": "Residential projects",
      "Pendientes que reportó (se manejan en el ✅ Checklist):": "Open items they reported (handled in the ✅ Checklist):",
      "📂 Ver la ficha del proyecto": "📂 Open the job file",
      "No salieron — fuera de las estadísticas": "Not won — left out of the stats",
      "Contratado activo": "Active contract value",
      "Margen real": "Actual margin",
      "↩ Reabrir (a ejecución)": "↩ Reopen (back to in progress)", "Reabrir (a ejecución)": "Reopen (back to in progress)",
      "🔴 Pendientes de obra que suenan a material": "🔴 Open job items that sound like materials",
      "⚠ Pendiente / bloqueo": "⚠ Open item / blocker",
      "Con trabajo": "Work scheduled", "Pendiente sin resolver": "Unresolved open item",
      "Pendientes de obra": "Open job items", "Sin pendientes de obra.": "No open job items.",
      "Pendiente de obra": "Open job item",
      "POR LEER": "UNREAD",
      "Rentabilidad y gastos": "Profitability & expenses",
      "Contrato y cambios (SOW / CO)": "Contract and change orders (SOW / CO)",
      "Marcar cobrada": "Mark collected", "Ya cobré": "Already collected", "Ya cobré sin factura": "Collected without an invoice",
      "Próximo cobro": "Next collection",
      "Crea la factura con las reglas de la casa": "Creates the invoice with our billing rules",
      "Ve el dinero:": "Sees the money:",
      "Anotar envío": "Log as sent",
      "Firmado · falta tu firma": "Signed · waiting on your signature",
      "Firmaste tú · falta el cliente": "You signed · waiting on the client",
      "Firmado · falta la firma de Edgar": "Signed · waiting on Edgar's signature",
      "Firmar yo (Edgar Arboleya)": "Sign it myself (Edgar Arboleya)",
      "Fase devuelta ✓": "Phase moved back ✓",
      "la necesitamos antes del": "we need it by",
      "Ej.: faltó un breaker de 20 A": "E.g. we're short a 20 A breaker",
      "Sus estimados": "Estimates", "Sin fecha programada": "No date scheduled",
      // Comillas «» → “” (tono del pliego)
      "Todavía no hay renglones. Nacen solos al armar el contrato en «Escribir el alcance».":
        "No items yet. They're created when you build the contract in “Write the scope”.",
      "No hay obras en marcha ahora. En «Todos los proyectos» están todas.":
        "No jobs in progress right now. “All projects” has every one.",
      "No encuentro a ese contratista en la lista: cámbialo en «Cambiar contratista o coordinador».":
        "I can't find that contractor in the list: change it in “Change contractor or coordinator”.",
      // Arreglos de reglas viejas que se tapan con una clave exacta (la clave manda sobre las reglas)
      "materiales por comprar — toca para ver la lista": "materials to buy — tap to see the list",
      "material por comprar — toca para ver la lista": "material to buy — tap to see the list",
      "toca para ver sus reportes": "tap to see their reports",
  
      // ===== index.html =====
      "Max Power — Proyectos": "Max Power — Projects",
      "Versión de la app": "App version", "Versión de la app — toca para comprobarla": "App version — tap to check it",
      "Logo Max Power": "Max Power logo", "Menú": "Menu", "Volver": "Back", "Crear un proyecto nuevo": "Create a new project",
      "Mes anterior": "Previous month", "Mes siguiente": "Next month",
      // Fases del reporte de horas (el valor que se guarda sigue en español)
      "Demolición": "Demolition", "Panel / Servicio": "Panel / Service",
      "Inspección / Correcciones": "Inspection / Corrections",
      "Ej: terminé los recessed del living": "E.g. finished the recessed lights in the living room",
      "¿Fue trabajo de un Change Order? (toca la flechita y elígelo)": "Was it change order work? (tap the arrow and pick it)",
      "Contrato base": "Base contract",
      "¿Quedó algún pendiente? (faltó material, circuito sin tirar…)": "Any open items left? (missing material, circuit not pulled…)",
      "Ej: faltó cable 14/2 — circuito del pasillo sin tirar": "E.g. short on 14/2 wire — hallway circuit not pulled",
      "Tu reporte se guarda directo en el sistema y Edgar lo ve al instante.": "Your report is saved straight to the system and Edgar sees it right away.",
      "Datos en vivo": "Live data",
      "base de datos en la nube · finanzas conciliadas con QuickBooks": "cloud database · finances reconciled with QuickBooks",
      // Ventana «Nuevo Proyecto»
      "Nuevo Proyecto": "New project", "Nombre del proyecto *": "Project name *",
      "Ej: Casa García — Remodelación": "E.g. García house — Remodel",
      "Residencial": "Residential", "Comercial": "Commercial",
      "Etapa inicial": "Starting stage", "Estimando (todavía sin propuesta)": "Estimating (no proposal yet)",
      "Ej: Juan García": "E.g. Juan García", "para la propuesta y el portal": "for the proposal and the portal",
      "Ej: (813) 555-0100": "E.g. (813) 555-0100", "Dirección": "Address",
      "Ej: 123 Main St, Tampa, FL": "E.g. 123 Main St, Tampa, FL",
      "Valor del contrato ($)": "Contract value ($)", "lo pone el alcance": "set by the scope",
      "Nº de propuesta / SOW": "Proposal / SOW no.",
      "El precio y el número de propuesta no hace falta escribirlos: salen solos cuando armes el alcance. Solo llénalos si el SOW ya existe de antes.":
        "You don't need to type the price or the proposal number: they fill in on their own when you build the scope. Only fill them in if the SOW already exists.",
      "Notas": "Notes", "Situación actual del proyecto": "Current project status",
      "El proyecto se guarda en la nube y lo ve todo el equipo al instante.": "The project is saved in the cloud and the whole team sees it right away.",
      "Crear proyecto": "Create project",
      // Días y meses sueltos que aún salen en español (nodo que es solo eso)
      "lun": "Mon", "mar": "Tue", "mié": "Wed", "jue": "Thu", "vie": "Fri", "sáb": "Sat", "dom": "Sun",
      "enero": "January", "febrero": "February", "marzo": "March", "abril": "April", "mayo": "May", "junio": "June",
      "julio": "July", "agosto": "August", "septiembre": "September", "octubre": "October", "noviembre": "November", "diciembre": "December",
      "Enero": "January", "Febrero": "February", "Marzo": "March", "Abril": "April", "Mayo": "May", "Junio": "June",
      "Julio": "July", "Agosto": "August", "Septiembre": "September", "Octubre": "October", "Noviembre": "November", "Diciembre": "December",
  
      // ===== db.js — errores que ve la persona (enCristiano y los throw) =====
      "Error de autenticación": "Sign-in error", "Sin sesión": "Not signed in",
      "A la base todavía le falta el último SQL. Pégalo en Supabase (SQL Editor → pegar → Run) y vuelve a intentarlo.":
        "The database is still missing the latest SQL. Paste it in Supabase (SQL Editor → paste → Run) and try again.",
      "El modo ⚡ Rápido todavía no está dado de alta en la base. A la base todavía le falta el último SQL. Pégalo en Supabase (SQL Editor → pegar → Run) y vuelve a intentarlo.":
        "The ⚡ Quick mode isn't set up in the database yet. The database is still missing the latest SQL. Paste it in Supabase (SQL Editor → paste → Run) and try again.",
      "Un reporte de horas va de más de 0 hasta 16 horas.": "An hours report must be more than 0 and no more than 16 hours.",
      "La retención no puede ser negativa ni llevar más de dos decimales.": "The retainage can't be negative or have more than two decimals.",
      "La base no aceptó uno de los datos porque se sale de lo permitido. A la base todavía le falta el último SQL. Pégalo en Supabase (SQL Editor → pegar → Run) y vuelve a intentarlo.":
        "The database rejected one of the values because it's outside what's allowed. The database is still missing the latest SQL. Paste it in Supabase (SQL Editor → paste → Run) and try again.",
      "Eso ya estaba guardado; no se apuntó dos veces.": "That was already saved; it wasn't logged twice.",
      "Eso apunta a algo que ya no existe (un proyecto o un hito borrado).": "That points to something that no longer exists (a deleted project or milestone).",
      "Falta un dato obligatorio para poder guardar.": "A required field is missing, so it can't be saved.",
      "Tu usuario no tiene permiso para hacer eso.": "Your user doesn't have permission to do that.",
      "Uno de los números no es válido.": "One of the numbers isn't valid.",
      "Se venció la sesión. Vuelve a entrar.": "Your session expired. Sign in again.",
      "Sin señal: el asistente no contestó a tiempo": "No signal: the assistant didn't answer in time",
      "Sin señal: no pude hablar con el asistente": "No signal: I couldn't reach the assistant",
      "Esta parte del asistente todavía no está subida a la nube": "This part of the assistant isn't uploaded to the cloud yet",
      "El asistente tardó demasiado": "The assistant took too long",
      "El asistente falló en la nube; vuelve a intentarlo en un minuto": "The assistant failed in the cloud; try again in a minute",
      "No encuentro la plantilla oficial en la app": "I can't find the official template in the app",
      "No se pudo guardar en el catálogo: falta el permiso de edición en la base.": "Couldn't save to the catalog: the database is missing edit permission.",
      "No se pudo conectar con el asistente": "Couldn't connect to the assistant",
      "El pedido llevaba un monto (no se mandó)": "The request had a dollar amount in it (it wasn't sent)",
      "El cartero de email todavía no está subido a la nube": "The email sender isn't uploaded to the cloud yet",
      "Al cartero le falta su llave (RESEND_API_KEY) en la nube": "The email sender is missing its key (RESEND_API_KEY) in the cloud",
      "El proyecto no tiene email del cliente": "The project has no client email",
      "Este proyecto no tiene portal del cliente todavía": "This project doesn't have a client portal yet",
      "Ese contratista no está en la libreta": "That contractor isn't in the contact book",
      "Ese contratista está apagado; enciéndelo antes de invitarlo": "That contractor is turned off; turn them on before inviting them",
      "A ese contratista le tienes los avisos apagados": "You have notifications turned off for that contractor",
      "Esa obra no es de ese contratista": "That job doesn't belong to that contractor",
      "Esa obra la paga el dueño: al contratista no se le manda nada de dinero": "The homeowner pays for that job: no money info goes to the contractor",
      "Falta decir de qué obra es el aviso": "The alert doesn't say which job it's for",
      "Esto solo lo puede usar el dueño": "Only the owner can use this",
      "Por confirmar": "To be confirmed",
      "El contrato está en el portal, pero el email no salió": "The contract is in the portal, but the email didn't go out",
  
      // ===== alcance.js — lo que ve Edgar en «Escribir el alcance» =====
      // Preguntas y errores de la hoja
      "¿Quién es el cliente (quien paga y firma)?": "Who is the client (the one who pays and signs)?",
      "¿Cuál es la dirección de la obra?": "What's the job address?",
      "La obra está en zona de inundación (la hoja habla del certificado de elevación / FBC 1612). ¿Qué zona FEMA y qué BFE dice el certificado? Escríbelo así: AE, BFE 11.0 / 12.0 ft NAVD 88, EC 12/23/2014, LAG 6.7 ft":
        "The job is in a flood zone (the sheet mentions the elevation certificate / FBC 1612). What FEMA zone and BFE does the certificate show? Write it like this: AE, BFE 11.0 / 12.0 ft NAVD 88, EC 12/23/2014, LAG 6.7 ft",
      "Quitar esa línea": "Remove that line", "Quitar la pregunta": "Remove the question",
      "Aquí el chat dejó algo por contestar": "The chat left something unanswered here",
      "La sección Alcance está vacía. Sin ella no hay contrato.": "The Scope section is empty. Without it there's no contract.",
      "Falta el precio base en Precio.": "The base price is missing in Price.",
      "Escribir el precio": "Write the price",
      "Poner ese disparador en el hito 2": "Use that trigger on milestone 2",
      "Contrato con el contratista: firma solo el contratista (representante autorizado). El dueño de la propiedad queda como referencia (Homeowner) y firma el Layout Approval de la sección 8, no el SOW.":
        "Contract with the contractor: only the contractor signs (authorized representative). The property owner stays as a reference (Homeowner) and signs the Layout Approval in section 8, not the SOW.",
      "Sí, firman las dos": "Yes, both sign", "No, es un solo firmante": "No, there's only one signer",
      "Sí": "Yes", "Otra": "Other",
      "¿Cómo se cobra?": "How do we bill it?",
      "El primer pago es el depósito y no puede ser 0%.": "The first payment is the deposit and can't be 0%.",
      "Los pagos van en porcentajes enteros.": "Payments go in whole percentages.",
      "¿Tienes fotos o documentación del panel?": "Do you have photos or documentation of the panel?",
      "Sí las tengo": "Yes, I have them", "No las tengo": "No, I don't",
      "¿Este trabajo extiende o modifica circuitos que ya existen?": "Does this work extend or modify existing circuits?",
      "Dijiste que no tienes fotos del panel: escribe en «Falta» qué te faltó al cotizar.":
        "You said you don't have panel photos: write under “Missing” what you were missing when you estimated.",
      "Escribirlo": "Write it",
      "Poner «sin fotos ni documentación del panel»": "Write “Sin fotos ni documentación del panel” (no panel photos or docs)",
      "Caben hasta cuatro opciones.": "Up to four options fit.",
      "Elegir el renglón": "Pick the item",
      "240V necesita tres datos: equipo, renglón y calibre. Ejemplo: «estufa, renglón 2, hasta #8».":
        "240V needs three things: equipment, item and wire size. Example: “estufa, renglón 2, hasta #8” (range, item 2, up to #8).",
      "Calibre máximo (#8, #6…)": "Max wire size (#8, #6…)",
      "Sí, quítala": "Yes, remove it", "No, déjala": "No, keep it",
      "Quitar la línea entera": "Remove the whole line", "Eso no es dinero, déjalo": "That's not money, leave it",
      "Hay dos precios. Solo va uno: el precio base sin opciones.": "There are two prices. Only one goes in: the base price without options.",
      "Quitar este segundo precio": "Remove this second price",
      "No entiendo el precio. Escríbelo así: 16,498.24": "I don't understand the price. Write it like this: 16,498.24",
      "Quitar esta línea": "Remove this line", "Quitar la línea": "Remove the line",
      "El párrafo de la sección 1 llama «Contractor» a otra empresa; en el contrato «Contractor» es Max Power. La sección 1 la armo yo con lo que sé, y ese párrafo queda de referencia.":
        "The section 1 paragraph calls another company “Contractor”; in the contract, “Contractor” is Max Power. I build section 1 myself with what I know, and that paragraph stays as a reference.",
      "Quitarlo, ya lo trae la plantilla": "Remove it, the template already has it",
      "Es un renglón, déjalo": "It's an item, keep it",
      "Este detalle no tiene renglón encima. Ponle un título al renglón.": "This detail has no item above it. Give the item a title.",
      "Convertirlo en renglón": "Turn it into an item",
      "Este detalle no tiene opción encima.": "This detail has no option above it.",
      "Ponerle precio": "Add a price", "Quitar esta opción": "Remove this option",
      "Sí, ese es el precio": "Yes, that's the price", "No, lo corrijo": "No, I'll fix it",
      "Dejarlo escrito así en la hoja": "Write it that way in the sheet",
      "Numerarlos seguidos en la hoja": "Number them in order in the sheet",
      // Errores de los arreglos (salen en un aviso rojo)
      "esa línea ya no existe": "that line no longer exists", "escribe la respuesta": "write the answer",
      "no encuentro la línea del hito": "I can't find the milestone line",
      "escribe el precio así: 1,850.00": "write the price like this: 1,850.00",
      "escribe el precio así: 16,498.24": "write the price like this: 16,498.24",
      "escribe el calibre: #8, #6…": "write the wire size: #8, #6…", "elige el renglón": "pick the item",
      "escribe qué te faltó": "write what you were missing", "esa línea es el propio renglón": "that line is the item itself",
      "escribe el valor": "write the value", "no sé qué condición cambiar": "I don't know which condition to change",
      "no sé hacer ese arreglo": "I don't know how to make that fix",
      // Los avisos del lector inteligente (botones)
      "Déjalo así": "Leave it as is", "Es un renglón": "It's an item",
      "Es detalle del renglón de arriba": "It's a detail of the item above", "Déjala fuera": "Leave it out",
      "Déjala fuera del contrato": "Leave it out of the contract", "No es eso: déjala fuera": "That's not it: leave it out",
      "Quitar esa exclusión": "Remove that exclusion",
      // Lo que devuelve el asistente y el último candado antes de bajar el PDF
      "El asistente escribió algo que no puede escribir. Se descarta y se vuelve a redactar solo esto.":
        "The assistant wrote something it isn't allowed to write. It's discarded and only this part gets rewritten.",
      "Este texto no dice de qué línea sale.": "This text doesn't say which line it comes from.",
      "Quedó una marca de la plantilla sin resolver.": "A template marker was left unresolved.",
      "Quedó algo marcado como FALTA.": "Something is still marked FALTA (missing).",
      // Por qué va cada cláusula (el title de las fichas de cláusulas)
      "porque pusiste «Fotos del panel: no»": "because you wrote “Panel photos: no”",
      "porque pusiste «Circuitos existentes: sí»": "because you wrote “Existing circuits: yes”",
      "porque pusiste «240V»": "because you wrote “240V”", "porque pusiste «Reubicar»": "because you wrote “Relocate”",
      "porque pusiste «Isla»": "because you wrote “Island”", "porque pusiste «Abrir»": "because you wrote “Openings”",
      "porque las lámparas las pone el cliente": "because the client supplies the fixtures",
      "porque las lámparas las pones tú": "because you supply the fixtures",
      "porque hay excavación o trabajo bajo losa": "because there's excavation or under-slab work",
      "porque entregas planos": "because you're providing drawings",
      "porque el depósito pasa del 10% del precio": "because the deposit is over 10% of the price",
      "porque el contrato es con un contratista (GC)": "because the contract is with a contractor (GC)",
      "porque el contrato es con un contratista (GC): el Notice to Owner y los releases": "because the contract is with a contractor (GC): the Notice to Owner and the releases",
      "porque el contrato es con un contratista: no corren los tres días del consumidor": "because the contract is with a contractor: the consumer's three-day cancellation doesn't apply",
      "porque la propiedad es comercial: no es una venta a un consumidor (F.S. 501.021), no corren los tres días":
        "because the property is commercial: it isn't a consumer sale (F.S. 501.021), so the three days don't apply",
      "va siempre": "always included"
    });
  
    REGLAS.push(...(() => {
      // Traduce un trozo (el mensaje de error de dentro, una etiqueta…) con el mismo diccionario y reglas.
      // Si no lo conoce, lo deja como está.
      const tr = s => {
        if (Object.prototype.hasOwnProperty.call(D, s)) return D[s];
        for (const [re, out] of REGLAS) {
          if (!re.test(s)) continue;
          const r = typeof out === "function" ? out(s) : s.replace(re, out);
          if (r !== null && r !== undefined && r !== s) return r;
        }
        return s;
      };
      const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const comillas = s => String(s).replace(/«/g, "“").replace(/»/g, "”");
      const pl = (n, uno, varios) => Number(n) === 1 ? uno : varios;
  
      // «No se pudo guardar: <error de la base>» → el prefijo y el error, los dos en inglés
      const PREFIJO = {
        "No se pudo": "Couldn't do it", "No se pudo guardar": "Couldn't save", "No se pudo crear": "Couldn't create",
        "No se pudo corregir": "Couldn't edit", "No se pudo agregar": "Couldn't add", "No se pudo añadir": "Couldn't add",
        "No se pudo subir": "Couldn't upload", "No se pudo subir la foto": "Couldn't upload the photo",
        "No se pudo subir el recibo": "Couldn't upload the receipt", "No se pudo enviar": "Couldn't send",
        "No se pudo cambiar": "Couldn't change", "No se pudo anular": "Couldn't void", "No se pudo anotar": "Couldn't log it",
        "No se pudo registrar": "Couldn't log it", "No se pudo resolver": "Couldn't resolve", "No se pudo quitar": "Couldn't remove",
        "No se pudo pasar": "Couldn't move", "No se pudo pasar al estimado": "Couldn't move it to the estimate",
        "No se pudo guardar el alcance": "Couldn't save the scope", "No se pudo convertir": "Couldn't convert",
        "No se pudo congelar": "Couldn't freeze", "No se pudo conectar": "Couldn't connect",
        "No se pudo cargar el estimador": "Couldn't load the estimator", "No se pudo asignar": "Couldn't assign",
        "No se pudo aplicar": "Couldn't apply", "No se pudo activar": "Couldn't turn on", "No se pudo abrir": "Couldn't open",
        "No se pudo eliminar": "Couldn't delete", "No se pudo mandar el correo": "Couldn't send the email",
        "No se pudo bajar la copia de la obra, así que no se borró nada": "Couldn't download the job's backup copy, so nothing was deleted",
        "No salió el aviso": "The notification didn't go out", "No salió el correo": "The email didn't go out",
        "No pude sacar el enlace": "I couldn't get the link", "No pude preparar el texto": "I couldn't prepare the text",
        "No pude preparar el email": "I couldn't prepare the email", "No pude guardarlo en el proyecto": "I couldn't save it to the project",
        "No pude guardar en el proyecto": "I couldn't save to the project",
        "Error cargando los datos": "Error loading the data", "Error actualizando": "Error updating",
        "El servidor no contestó bien": "The server didn't respond properly",
        "El contrato quedó guardado, pero la ficha no se cuadró": "The contract was saved, but the job file didn't update",
        "El contrato está en el portal, pero el email no salió": "The contract is in the portal, but the email didn't go out",
        "Sin señal": "No signal", "El servicio de correo lo rechazó": "The email service rejected it"
      };
      const rePrefijo = new RegExp("^(" + Object.keys(PREFIJO).sort((a, b) => b.length - a.length).map(esc).join("|") + "): ([\\s\\S]+)$");
  
      // Los avisos del lector inteligente: «<tipo> (línea 12: «cita»). motivo»
      const AVISO = {
        "La hoja trae dos veces la misma sección": "The sheet has the same section twice",
        "Este párrafo está repetido": "This paragraph is repeated", "Este renglón parece repetido": "This item looks repeated",
        "Este cierre (pruebas, inspección, limpieza) ya lo trae la plantilla": "The template already has this closeout (testing, inspection, cleanup)",
        "Esta línea remite a una cláusula que no está en la hoja": "This line refers to a clause that isn't in the sheet",
        "El número que dice no cuadra con lo que lista": "The number it gives doesn't match what it lists",
        "Esta línea parece de otro tipo de trabajo": "This line looks like it's from another kind of job",
        "Esta exclusión choca con algo que el Alcance sí incluye": "This exclusion conflicts with something the Scope does include",
        "Parece una propiedad comercial": "It looks like a commercial property",
        "Parece un contrato con un contratista": "It looks like a contract with a contractor",
        "El cliente es una empresa: hace falta saber quién firma": "The client is a company: we need to know who signs",
        "Este dato parece pendiente de confirmar": "This detail looks like it still needs confirming",
        "La hoja dice en prosa algo que va en Condiciones": "The sheet says in prose something that belongs in Conditions",
        "Esta condición apunta a un renglón": "This condition points to an item",
        "Este título lo leí por su sentido": "I read this heading by its meaning",
        "No estoy seguro de qué es esta línea": "I'm not sure what this line is",
        "Este número es una cantidad, no la numeración": "This number is a quantity, not the numbering",
        "La numeración no va seguida": "The numbering isn't in order",
        "Hay un monto donde no van montos": "There's an amount where amounts don't go",
        "Hay dos precios distintos": "There are two different prices",
        "Este código no es del NEC: va tal cual": "This code isn't from the NEC: it goes in as is",
        "Esta cláusula parece de las que la plantilla ya trae": "This clause looks like one the template already has",
        "Esta línea está en otro idioma que el resto": "This line is in a different language from the rest",
        "Este detalle no tiene renglón encima": "This detail has no item above it"
      };
      const reAviso = new RegExp("^(" + Object.keys(AVISO).map(esc).join("|") + ") \\(línea (\\d+)(?:: «([\\s\\S]*)»)?\\)\\.(?: ([\\s\\S]+))?$");
  
      // Qué papel tiene una línea (avisos del lector)
      const PAPEL = {
        "un renglón del Alcance": "a Scope item", "un detalle de un renglón": "a detail of an item", "un detalle": "a detail",
        "una exclusión": "an exclusion", "una opción": "an option", "el precio del contrato": "the contract price",
        "una fila de pagos": "a payment row", "una condición de pago": "a payment condition", "un dato de cabecera": "a header field",
        "una condición": "a condition", "una cláusula propia de la hoja": "a clause of the sheet's own", "una cláusula propia": "a custom clause",
        "un título de sección": "a section heading", "texto de la hoja": "sheet text", "un encabezado de grupo": "a group heading",
        "un grupo": "a group", "código": "code", "un detalle de opción": "an option detail", "una nota de pagos": "a payments note",
        "un renglón": "an item", "nada": "nothing"
      };
      // Dónde vio el dinero / nombres de secciones de la hoja
      const DONDE = { "esta línea": "this line", "el Alcance": "the Scope", "No incluye": "Not included", "Condiciones": "Conditions" };
      // Las condiciones (su primer nombre, el que sale en el botón)
      const COND = {
        "fotos del panel": "panel photos", "circuitos existentes": "existing circuits", "240v": "240v", "reubicar": "relocate",
        "isla": "island", "abrir": "openings", "fixtures del cliente": "client fixtures", "fixtures nuestros": "our fixtures",
        "excavacion": "excavation", "listo antes del rough": "ready before rough", "acceso": "access", "fases": "phases",
        "areas": "work areas", "no tocamos": "off limits", "no excluir": "do not exclude", "tipo de trabajo": "work type"
      };
      const ETIQ_240 = { "240V": "240V", "Reubicar": "Relocate", "Isla": "Island", "Abrir": "Openings" };
  
      // Lo que la app cuenta que arregló en la hoja: «línea 12: quité «…»»
      const HECHO_LINEA = [
        [/^solo tenía el precio \((.+)\); la quité$/, m => `it only had the price (${m[1]}); I removed it`],
        [/^quité la pregunta del chat \(la línea quedaba vacía\)$/, () => "I removed the chat's question (the line was left empty)"],
        [/^quité la pregunta del chat y dejé «(.*)»$/, m => `I removed the chat's question and kept “${m[1]}”`],
        [/^tú dices «(.*)» — de acuerdo, la dejo como está$/, m => `you say “${m[1]}” — OK, I'm leaving it as is`],
        [/^apuntado, «(.*)» se queda como está$/, m => `noted, “${m[1]}” stays as is`],
        [/^quité «(.*)» y sus (\d+) detalles$/, m => `I removed “${m[1]}” and its ${m[2]} ${pl(m[2], "detail", "details")}`],
        [/^quité «(.*)»$/, m => `I removed “${m[1]}”`],
        [/^quité (.+) y dejé «(.*)»$/, m => `I removed ${m[1]} and kept “${m[2]}”`],
        [/^puse tu respuesta «(.*)»$/, m => `I put in your answer “${m[1]}”`],
        [/^lo convertí en renglón con título$/, () => "I turned it into an item with a title"],
        [/^le puse (\$[\d,]+\.\d{2})$/, m => `I gave it ${m[1]}`],
        [/^añadí «hasta #(\S+)»$/, m => `I added “hasta #${m[1]}” (up to #${m[1]})`],
        [/^ahora apunta al renglón (\d+)$/, m => `it now points to item ${m[1]}`],
        [/^ahora es un renglón del Alcance$/, () => "it's now a Scope item"],
        [/^la llevé al Alcance como renglón \(«(.*)»\)$/, m => `I moved it to the Scope as an item (“${m[1]}”)`],
        [/^ahora es detalle del renglón de arriba$/, () => "it's now a detail of the item above"],
        [/^ahora es detalle del renglón (\d+) \(«(.*)»\)$/, m => `it's now a detail of item ${m[1]} (“${m[2]}”)`],
        [/^«(.*)» ahora dice «(.*)»$/, m => `“${m[1]}” now says “${m[2]}”`],
        [/^«(.*)» → «(.*)»$/, m => `“${m[1]}” → “${m[2]}”`]
      ];
  
      return [
        // ----- db.js -----
        [rePrefijo, s => { const m = s.match(rePrefijo); return PREFIJO[m[1]] + ": " + tr(m[2]); }],
        [/^No hay conexión con el asistente ahora mismo\. ([\s\S]+)$/, s => "The assistant can't be reached right now. " + tr(s.replace(/^No hay conexión con el asistente ahora mismo\. /, ""))],
        [/^Error (\d{3}) en (\S+)$/, "Error $1 on $2"],
        [/^No se pudo subir la foto \((\d+)\)$/, "Couldn't upload the photo ($1)"],
        [/^No se pudo subir el documento \((\d+)\)$/, "Couldn't upload the document ($1)"],
        [/^No se pudo subir la miniatura \((\d+)\)$/, "Couldn't upload the thumbnail ($1)"],
        [/^No se pudieron cargar las imágenes \((\d+)\)$/, "Couldn't load the images ($1)"],
        [/^El asistente no respondió \((\d+)\)$/, "The assistant didn't respond ($1)"],
        [/^No se pudo bajar la plantilla \((\d+)\)$/, "Couldn't download the template ($1)"],
        [/^La IA no dio un reparto que cumpla tus reglas(: [\s\S]+)?$/, "The AI didn't give a split that meets your rules$1"],
        [/^La IA no contestó \((\S+)\)$/, "The AI didn't answer ($1)"],
        // Fecha corta de las facturas (db.js la escribe «17 sep»)
        [/^(\d{1,2}) (ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)$/, s => {
          const [d, m] = s.split(" ");
          const EN = { ene: "Jan", feb: "Feb", mar: "Mar", abr: "Apr", may: "May", jun: "Jun", jul: "Jul", ago: "Aug", sep: "Sep", oct: "Oct", nov: "Nov", dic: "Dec" };
          return EN[m] + " " + d;
        }],
  
        // ----- alcance.js: preguntas y avisos con partes variables -----
        [/^La obra está en zona (\S+) pero no encuentro el BFE del certificado de elevación\. Escríbelo así: (.+)$/,
          "The job is in zone $1 but I can't find the BFE on the elevation certificate. Write it like this: $2"],
        [/^Contrato con (.+): en el papel el cliente es (.+) \(paga y firma\) y (.+) queda como dueño de la propiedad \(Homeowner\)\.$/,
          "Contract with $1: on paper the client is $2 (pays and signs) and $3 stays as the property owner (Homeowner)."],
        [/^Esto no es un rough-in de interior: hay trabajo bajo tierra \/ bonding antes\. El pago 2 dice «(.*)»; lo natural es «(.+)» \(los montos no cambian\)\. Si prefieres un hito aparte al aprobar el bonding \(40\/30\/20\/10\), escríbelo en Pagos\.$/,
          "This isn't an interior rough-in: there's underground / bonding work first. Payment 2 says “$1”; the natural trigger is “$2” (the amounts don't change). If you'd rather have a separate milestone when the bonding is approved (40/30/20/10), write it in Payments."],
        [/^"(.+)" ¿son dos personas que firman las dos\?$/, "\"$1\" — are these two people who both sign?"],
        [/^¿La jurisdicción del permiso es (.*)\?$/, "Is the permit jurisdiction $1?"],
        [/^Los pagos suman (\d+)%\. Tienen que sumar 100 exacto\.$/, "The payments add up to $1%. They have to add up to exactly 100."],
        [/^(240V|Reubicar|Isla|Abrir) dice renglón (\d+) pero solo hay (\d+) renglones en el Alcance\.$/, s => {
          const m = s.match(/^(240V|Reubicar|Isla|Abrir) dice renglón (\d+) pero solo hay (\d+) renglones en el Alcance\.$/);
          return `${ETIQ_240[m[1]]} says item ${m[2]} but there ${m[3] === "1" ? "is only 1 item" : `are only ${m[3]} items`} in the Scope.`;
        }],
        [/^Tu alcance habla de (\S+) y la sección 3 lo sigue excluyendo\. ¿Quito esa exclusión\?$/, "Your scope mentions $1 and section 3 still excludes it. Should I remove that exclusion?"],
        [/^Hay un precio \((.+)\) en (esta línea|el Alcance|No incluye|Condiciones)\. El dinero solo va en Precio, Pagos y Opciones\.$/, s => {
          const m = s.match(/^Hay un precio \((.+)\) en (esta línea|el Alcance|No incluye|Condiciones)\. /);
          return `There's a price (${m[1]}) in ${DONDE[m[2]]}. Money only goes in Price, Payments and Options.`;
        }],
        [/^Vi «(.+)» en (esta línea|el Alcance|No incluye|Condiciones) y me pareció un precio\. Si es una medida, una cantidad o un año, dímelo y lo dejo como está\.$/, s => {
          const m = s.match(/^Vi «(.+)» en (esta línea|el Alcance|No incluye|Condiciones) y me pareció/);
          return `I saw “${m[1]}” in ${DONDE[m[2]]} and it looked like a price. If it's a measurement, a quantity or a year, tell me and I'll leave it as is.`;
        }],
        [/^Quitar (.+) y dejar el texto$/, "Remove $1 and keep the text"],
        [/^¿El precio es (\$[\d,.]+) o (\$[\d,.]+)\?$/, s => { const m = s.match(/^¿El precio es (\S+) o (\S+)\?$/); return `Is the price ${m[1]} or ${m[2]}?`; }],
        [/^En Price hay otro monto \((.+)\) además del precio\. Lo dejo fuera del contrato\.$/, "There's another amount ($1) in Price besides the price. I'm leaving it out of the contract."],
        [/^"(.+)" no es un título que conozca\. ¿Querías decir "(.+)"\?$/, "\"$1\" isn't a heading I know. Did you mean \"$2\"?"],
        [/^No sé dónde poner "(.+)"\. Parece un comentario del chat\.$/, "I don't know where to put \"$1\". It looks like a chat comment."],
        [/^No sé dónde poner "(.+)" dentro de Condiciones\.$/, "I don't know where to put \"$1\" in Conditions."],
        [/^Cambiar a "(.+)"$/, "Change to \"$1\""],
        [/^No conozco "(.+)"\. ¿Querías decir "(.+)"\?$/, "I don't know \"$1\". Did you mean \"$2\"?"],
        [/^No conozco el dato "(.+)"\.$/, "I don't know the field \"$1\"."],
        [/^El lector dice que «(.+)» es el cierre del trabajo \(pruebas y entrega\), que la plantilla ya trae como último punto\. Lo dejo como renglón; si sobra, quítalo\.$/,
          "The reader says “$1” is the job closeout (testing and handover), which the template already has as its last point. I'm keeping it as an item; if it's extra, remove it."],
        [/^«(.+)» ya lo trae la plantilla como último punto del alcance; no lo repito\.$/, "The template already has “$1” as the last point of the scope; I won't repeat it."],
        [/^Esto está en el Alcance pero no es un renglón: «([\s\S]+)»\. Lo dejo fuera\.$/, "This is in the Scope but it isn't an item: “$1”. I'm leaving it out."],
        [/^La opción "(.+)" no tiene precio\. Los añadidos van con monto, o no van\.$/, "Option \"$1\" has no price. Add-ons go in with an amount, or not at all."],
        [/^¿La opción "(.+)" cuesta (\$[\d,.]+) o (\$[\d,.]+)\?$/, s => { const m = s.match(/^¿La opción "(.+)" cuesta (\S+) o (\S+)\?$/); return `Does option "${m[1]}" cost ${m[2]} or ${m[3]}?`; }],
        [/^¿La opción "(.+)" cuesta (\$[\d,.]+)\? Parece poco\.$/, s => { const m = s.match(/^¿La opción "(.+)" cuesta (\S+)\? Parece poco\.$/); return `Does option "${m[1]}" cost ${m[2]}? That seems low.`; }],
        [/^En Código no entendí «(.+)» como artículo; lo dejo fuera\.$/, "In Code I didn't understand “$1” as an article; I'm leaving it out."],
        [/^Quitar "(.+)"$/, "Remove \"$1\""],
        [/^Quitar «(.+)»$/, "Remove “$1”"],
        [/^En No incluye venían (\d+) exclusiones que la plantilla ya trae \(permiso, fixtures, drywall…\); las quité para no repetirlas\.$/, s => {
          const n = s.match(/\d+/)[0];
          return `Not included had ${n} ${pl(n, "exclusion", "exclusions")} the template already has (permit, fixtures, drywall…); ${pl(n, "I removed it so it isn't repeated", "I removed them so they aren't repeated")}.`;
        }],
        [/^Del archivo solo se usan las secciones 1 a 6\. Me salté (.+): eso lo pone la plantilla del contrato con su texto legal\.$/, s => {
          const m = s.match(/^Del archivo solo se usan las secciones 1 a 6\. Me salté (.+): eso lo pone/);
          return `Only sections 1 to 6 of the file are used. I skipped ${comillas(m[1])}: the contract template adds that with its legal text.`;
        }],
        [/^Hito 2: esto no es un rough-in de interior \(hay trabajo bajo tierra \/ bonding antes\), así que lo puse «(.+)»\. Los montos no cambian\. Si lo quieres de otra manera, escríbelo en Pagos y así se queda\.$/,
          "Milestone 2: this isn't an interior rough-in (there's underground / bonding work first), so I set it to “$1”. The amounts don't change. If you want it another way, write it in Payments and it'll stay that way."],
        [/^De las secciones 7 y 9 de la hoja quité (\d+) puntos? que la plantilla ya trae \((.+)\); lo demás va al contrato tal cual\.$/, s => {
          const m = s.match(/^De las secciones 7 y 9 de la hoja quité (\d+) puntos? que la plantilla ya trae \((.+)\); lo demás/);
          return `From sections 7 and 9 of the sheet I removed ${m[1]} ${pl(m[1], "point", "points")} the template already has (${comillas(m[2])}); the rest goes into the contract as is.`;
        }],
        [/^Los renglones del Alcance venían numerados (.+); los tomo en el orden en que están \(1 a (\d+)\) y el contrato los numera solo\. Tu hoja no cambia\.$/,
          "The Scope items came numbered $1; I take them in the order they're in (1 to $2) and the contract numbers them itself. Your sheet doesn't change."],
        [/^no hay renglón (\d+) en el Alcance$/, "there's no item $1 in the Scope"],
  
        // ----- alcance.js: lo que la app cuenta que arregló -----
        [/^línea (\d+): (.+)$/, s => {
          const m = s.match(/^línea (\d+): ([\s\S]+)$/);
          for (const [re, f] of HECHO_LINEA) { const k = m[2].match(re); if (k) return `line ${m[1]}: ${f(k)}`; }
          return s;
        }],
        [/^puse el disparador del hito 2: (.+)$/, "I set the milestone 2 trigger: $1"],
        [/^Precio: (\$[\d,]+\.\d{2})( · rellené (\d+) pagos en blanco \(([\d/]+)\))?$/, s => {
          const m = s.match(/^Precio: (\S+)(?: · rellené (\d+) pagos en blanco \(([\d/]+)\))?$/);
          return `Price: ${m[1]}` + (m[2] ? ` · filled in ${m[2]} blank ${pl(m[2], "payment", "payments")} (${m[3]})` : "");
        }],
        [/^Pagos: (\d{1,3}(?:\/\d{1,3})+)$/, "Payments: $1"],
        [/^Falta: «(.*)»$/, "Missing: “$1”"],
        [/^numeré los (\d+) renglones seguidos$/, "I numbered the $1 items in order"],
        [/^escribí «(.+)» en Condiciones$/, "I wrote “$1” in Conditions"],
        [/^escribí «(.+)» en la hoja$/, "I wrote “$1” in the sheet"],
        [/^([\s\S]+) \(los montos no cambian\)$/, s => {
          const dentro = s.slice(0, -" (los montos no cambian)".length), r = tr(dentro);
          return r === dentro ? s : r + " (the amounts don't change)";
        }],
  
        // ----- alcance.js: los avisos del lector inteligente -----
        [reAviso, s => {
          const m = s.match(reAviso);
          return `${AVISO[m[1]]} (line ${m[2]}${m[3] !== undefined ? `: “${m[3]}”` : ""}).${m[4] ? " " + m[4] : ""}`;
        }],
        [/^Apuntar al renglón (\d+)$/, "Point to item $1"],
        [/^Ponerlo en Condiciones \((.+)\)$/, s => { const k = s.slice("Ponerlo en Condiciones (".length, -1); return `Put it in Conditions (${COND[k] || k})`; }],
        [/^El lector quiso dejar fuera la línea (\d+) «([\s\S]*)»\. La conservo donde las reglas la pusieron hasta que me digas qué es\.$/,
          "The reader wanted to leave out line $1 “$2”. I'm keeping it where the rules put it until you tell me what it is."],
        [/^El lector puso la línea (\d+) «([\s\S]*)» en otro sitio \((.+)\); la dejo como (.+), que es como la leen las reglas\.( El dinero no lo mueve el lector\.| Si de verdad no lo es, dímelo\.)$/, s => {
          const m = s.match(/^El lector puso la línea (\d+) «([\s\S]*)» en otro sitio \((.+)\); la dejo como (.+), que es como la leen las reglas\.( El dinero no lo mueve el lector\.| Si de verdad no lo es, dímelo\.)$/);
          const puesto = m[3] === "en ninguno" ? "nowhere" : m[3];
          const cola = /dinero/.test(m[5]) ? " The reader doesn't move money." : " If it really isn't, tell me.";
          return `The reader put line ${m[1]} “${m[2]}” somewhere else (${puesto}); I'm keeping it as ${PAPEL[m[4]] || m[4]}, which is how the rules read it.${cola}`;
        }],
        [/^El lector leyó la línea (\d+) «([\s\S]*)» como (.+); las reglas la tenían como (texto de la hoja|nada)\. Si no lo es, quítala\.$/, s => {
          const m = s.match(/^El lector leyó la línea (\d+) «([\s\S]*)» como (.+); las reglas la tenían como (texto de la hoja|nada)\. Si no lo es, quítala\.$/);
          return `The reader read line ${m[1]} “${m[2]}” as ${PAPEL[m[3]] || m[3]}; the rules had it as ${PAPEL[m[4]]}. If it isn't, remove it.`;
        }],
        [/^El lector cree que el precio del contrato está en la línea (\d+) «([\s\S]*)»\. El precio no lo pone el lector: escríbelo tú en «Precio:»\.$/,
          "The reader thinks the contract price is on line $1 “$2”. The reader doesn't set the price: write it yourself in “Price:”."],
        [/^El lector quiso añadir como opción con precio la línea (\d+) «([\s\S]*)»\. Las opciones con precio las escribes tú en Opciones\.$/,
          "The reader wanted to add line $1 “$2” as a priced option. You write priced options yourself in Options."],
        [/^El lector quiso tomar la línea (\d+) «([\s\S]*)» como fila de pagos\. Los pagos los escribes tú en Pagos\.$/,
          "The reader wanted to take line $1 “$2” as a payment row. You write the payments yourself in Payments."],
        [/^… y (\d+) avisos más del lector que no caben aquí\. Las líneas están todas en la hoja, tal como las leen las reglas\.$/,
          "… and $1 more reader alerts that don't fit here. All the lines are in the sheet, as the rules read them."],
  
        // ----- alcance.js: lo que devuelve el asistente y el último candado -----
        [/^En «(.+)» hay un \$ o una marca que no puede ir en el contrato\.$/, s => `In “${s.slice(4, s.indexOf("» hay un $"))}” there's a $ or a marker that can't go in the contract.`],
        [/^El asistente devolvió (\d+) renglones y tú escribiste (\d+)\. Se descarta\.$/, "The assistant returned $1 items and you wrote $2. It's discarded."],
        [/^Devolvió (\d+) opciones y hay (\d+)\.$/, "It returned $1 options and there are $2."],
        [/^Devolvió (\d+) exclusiones y en tu hoja hay (\d+)\. Se descarta\.$/, "It returned $1 exclusions and your sheet has $2. It's discarded."],
        [/^Quedaron huecos sin llenar: (.+)$/, "Blanks left unfilled: $1"],
        [/^El contrato tiene (\$\s?[\d,]+(?:\.\d{2})?), que no lo calculé yo\.$/, s => `The contract has ${s.match(/\$\s?[\d,]+(?:\.\d{2})?/)[0]}, which I didn't calculate.`],
        [/^porque la hoja trae condiciones propias de este trabajo: (.*)$/, "because the sheet has conditions specific to this job: $1"]
      ];
    })());
  // · parte-A
  // ---------- Trozo A: js/app.js líneas 1–2245 (entrada, sin señal, menú, perfil, «Hoy» del dueño y del campo,
    // licencia y seguros, guía del código, contratistas, jurisdicciones, avisos push, inspecciones de la semana,
    // resumen del mes, urgentes, avisos del dueño, horas del equipo, categorías y resumen) ----------
    Object.assign(D, {
      // Roles y versión
      "Campo": "Field",
      // Sin señal (franja de arriba y pantalla entera)
      "📶 Sin señal — estás viendo los datos de": "📶 No signal — you're seeing the data from",
      "Sin señal — estás viendo los datos de": "No signal — you're seeing the data from",
      "(sin fotos). Lo que apuntes se manda cuando vuelva.": "(without photos). Whatever you log is sent when the signal comes back.",
      ". Lo que apuntes se manda cuando vuelva.": ". Whatever you log is sent when the signal comes back.",
      "Reintentar": "Retry", "Sin señal": "No signal",
      "No se pudo conectar. Tu sesión sigue guardada — no hace falta volver a entrar.":
        "Couldn't connect. You're still signed in — no need to sign in again.",
      "📶 Sin señal: sigues viendo la copia del teléfono.": "📶 No signal: you're still seeing the copy saved on the phone.",
      "Tu cuenta no tiene perfil asignado. Avísale a Edgar.": "Your account has no profile assigned. Let Edgar know.",
      // Licencia y seguros de la empresa
      "sin archivo todavía": "no file yet", "Cambiar el PDF o la fecha": "Change the PDF or the date",
      "Vence": "Expires", "PDF nuevo": "New PDF",
      "déjalo vacío si solo cambias la fecha": "leave it empty if you're only changing the date",
      "Falta alguno de los tres papeles de la empresa (licencia, Workers' Comp, Liability). Dímelo y lo vuelvo a poner.":
        "One of the company's three documents is missing (license, Workers' Comp, Liability). Tell me and I'll put it back.",
      "Sin documentos todavía.": "No documents yet.",
      "No se pudieron cargar los documentos de la empresa — revisa la señal.": "Couldn't load the company documents — check your signal.",
      "¿Eliminar este documento de la empresa?": "Delete this company document?",
      "Documento eliminado ✓": "Document deleted ✓",
      "Subiendo…": "Uploading…", "Guardando…": "Saving…",
      "Papel actualizado ✓ — el equipo y los portales ya ven el nuevo": "Document updated ✓ — the team and the portals now see the new one",
      "Fecha guardada ✓": "Date saved ✓",
      // Guía del código eléctrico (NEC 2023)
      "Código eléctrico — guía de campo (NEC 2023)": "Electrical code — field guide (NEC 2023)",
      "Los números que se usan en la obra, con su artículo al lado. El texto oficial se confirma en":
        "The numbers used on the job, with their article next to them. The official text is confirmed in",
      "(Florida: FBC 8ª edición, base NEC 2023). Detectores de humo: FBC-R R314 / NFPA 72, no NEC. Para un caso raro o una discusión con un inspector: pregúntale a Claude y te da el artículo exacto con la frase textual.":
        "(Florida: FBC 8th edition, based on NEC 2023). Smoke detectors: FBC-R R314 / NFPA 72, not NEC. For an unusual case or a discussion with an inspector: ask Claude and it gives you the exact article with the verbatim text.",
      "Cable Romex (NM) — amperaje máximo": "Romex cable (NM) — max ampacity",
      "THHN en tubería — amperaje (75°C)": "THHN in conduit — ampacity (75°C)",
      "Servicio o feeder de vivienda — calibre": "Dwelling service or feeder — wire size",
      "Zanjas — profundidad mínima": "Trenches — minimum depth",
      "Tierra — varillas y calibres": "Grounding — rods and wire sizes",
      "Cargadores EV — breaker y cable": "EV chargers — breaker and wire",
      "GFCI en vivienda (NEC 2023)": "GFCI in dwellings (NEC 2023)",
      "Tomacorrientes — distancias": "Receptacles — spacing",
      "Frente al panel — espacio libre": "In front of the panel — working space",
      "Box fill — pulgadas cúbicas por cable": "Box fill — cubic inches per wire",
      "NEC 310.16 (col. 60°C)": "NEC 310.16 (60°C column)", "NEC 300.5 (tabla)": "NEC 300.5 (table)",
      "NEC Art. 625 (carga continua ×125%)": "NEC Art. 625 (continuous load ×125%)",
      "#4 cobre · #2 aluminio": "#4 copper · #2 aluminum", "#2 cobre · #1/0 aluminio": "#2 copper · #1/0 aluminum",
      "#1 cobre · #2/0 aluminio": "#1 copper · #2/0 aluminum", "#2/0 cobre · #4/0 aluminio": "#2/0 copper · #4/0 aluminum",
      "Cable directo (UF)": "Direct-burial cable (UF)", "Tubería metálica rígida": "Rigid metal conduit",
      "Bajo driveway de vivienda": "Under a dwelling driveway", "Circuito 120V 20A con GFCI": "120V 20A circuit with GFCI",
      "Varillas": "Rods",
      "2 de 8 ft (salvo que UNA mida <25Ω) · sepáralas 6 ft o más": "2 × 8 ft (unless ONE measures <25Ω) · space them 6 ft or more apart",
      "Cable a las varillas (GEC)": "Wire to the rods (GEC)",
      "nunca se exige más grueso que #6 cobre": "never required larger than #6 copper",
      "Tierra del equipo (EGC)": "Equipment ground (EGC)",
      "Cargador de 32 A": "32 A charger", "Cargador de 40 A": "40 A charger", "Cargador de 48 A": "48 A charger",
      "breaker 60 A · #6 THHN en tubería (Romex #6 NO llega)": "breaker 60 A · #6 THHN in conduit (Romex #6 is NOT enough)",
      "Receptáculo 14-50R": "14-50R receptacle", "lleva GFCI (NEC 2023)": "needs GFCI (NEC 2023)",
      "Va en": "Required in",
      "baños · TODA la cocina · garaje · exterior · sótano · laundry · a 6 ft de cualquier fregadero":
        "bathrooms · the WHOLE kitchen · garage · outdoors · basement · laundry · within 6 ft of any sink",
      "casi todos los circuitos 120V 15/20A de vivienda (cuartos, salas, cocina, laundry)":
        "almost every 120V 15/20A dwelling circuit (bedrooms, living rooms, kitchen, laundry)",
      "Paredes": "Walls", "ninguna a más de 6 ft de una toma (cada 12 ft)": "no point more than 6 ft from a receptacle (one every 12 ft)",
      "todo tramo de 12\" o más lleva toma · ninguna a más de 24\"": "every section 12\" or wider gets a receptacle · no point more than 24\" away",
      "Baño": "Bathroom", "a máximo 3 ft del lavamanos · circuito de 20 A dedicado": "within 3 ft of the basin · dedicated 20 A circuit",
      "Fondo": "Depth", "Ancho": "Width", "Alto libre": "Headroom", "Breaker más alto": "Highest breaker",
      "máx 6 ft 7 in del piso": "max 6 ft 7 in above the floor",
      "Dispositivo (toma/switch)": "Device (receptacle/switch)", "cuenta DOBLE": "counts DOUBLE",
      "Tierras": "Grounds", "todas juntas = 1 (la mayor)": "all together = 1 (the largest)",
      "Caja 4\" sq × 2-1/8\"": "4\" sq box × 2-1/8\"",
      // Contratistas (GC) y su portal
      "Contratistas (GC) y su portal": "Contractors (GC) and their portal",
      "Cada empresa tiene": "Each company has", "una sola llave": "a single key",
      "para todas sus obras contigo. Con el enlace ven calendario, inspecciones, fotos, documentos, y la licencia y los seguros de Max Power. La facturación solo la ven en las obras donde el contrato es con ellos.":
        "for all their jobs with you. With the link they see the calendar, inspections, photos, documents, and Max Power's license and insurance. They only see billing on jobs where the contract is with them.",
      "sin email — ponlo antes de invitar": "no email — add it before inviting",
      "Copiar el enlace de su portal": "Copy their portal link", "Anotar o corregir el email": "Add or fix the email",
      "Mandarle la invitación a su portal": "Send them the invitation to their portal",
      "Regenerar la llave (el enlace viejo deja de servir)": "Regenerate the key (the old link stops working)",
      "Enlace del contratista copiado ✓": "Contractor link copied ✓",
      "Copia el enlace del contratista:": "Copy the contractor's link:",
      "Email del contratista (ahí le llega la invitación a su portal):": "Contractor email (the portal invitation goes there):",
      "Email guardado ✓": "Email saved ✓", "Primero ponle el email con el lapicito ✎": "First add the email with the pencil ✎",
      "¿Regenerar la llave? El enlace viejo deja de funcionar y hay que mandarle el nuevo.":
        "Regenerate the key? The old link stops working and you'll have to send them the new one.",
      "Llave nueva ✓ — copia el enlace otra vez": "New key ✓ — copy the link again",
      // Permisos por jurisdicción
      "Permisos por jurisdicción": "Permits by jurisdiction",
      "Cómo se saca el permiso en cada condado donde trabajamos. Dime lo que aprendas en cada uno y lo voy anotando.":
        "How to pull the permit in each county we work in. Tell me what you learn in each one and I'll keep notes.",
      // Avisos push en este teléfono
      "Este teléfono todavía no recibe avisos de la app.": "This phone isn't getting app notifications yet.",
      "Activar notificaciones": "Turn on notifications",
      "Aquí te llegan los 🔴 urgentes, los mensajes del chat y el permiso para corregir tus horas.":
        "This is how you get the 🔴 urgent items, chat messages and the OK to fix your hours.",
      "En iPhone, primero pon la app en la pantalla de inicio:": "On iPhone, first add the app to your Home Screen:",
      "Abajo en Safari, toca el botón": "At the bottom of Safari, tap the", "Compartir": "Share",
      "(el cuadrito con la flecha hacia arriba).": "button (the little square with the arrow pointing up).",
      "Baja y toca": "Scroll down and tap", "«Agregar a pantalla de inicio»": "“Add to Home Screen”", ", y luego": ", then",
      "Cierra Safari y abre la app desde el": "Close Safari and open the app from the", "icono del rayo": "lightning-bolt icon",
      "Ahí te vuelve a salir esta pantalla: toca": "This screen will come up again: tap",
      "Encender los avisos": "Turn on notifications",
      "Los avisos están bloqueados en este teléfono.": "Notifications are blocked on this phone.",
      "Para abrirlos:": "To unblock them:",
      "Ajustes → Notificaciones → Max Power →": "Settings → Notifications → Max Power →",
      "Permitir notificaciones": "Allow Notifications",
      "deja el dedo sobre el icono de la app → Información de la app → Notificaciones →":
        "press and hold the app icon → App info → Notifications →",
      "Permitir": "Allow", "Después vuelve a abrir la app.": "Then open the app again.",
      "Toca el botón y, cuando el teléfono pregunte, di": "Tap the button and, when the phone asks, choose",
      "Enciende los avisos en este teléfono": "Turn on notifications on this phone",
      "Ahora no": "Not now", "Entendido": "Got it",
      "Sin permiso — se puede activar después desde Ajustes del teléfono": "No permission — you can turn it on later in the phone's Settings",
      "🔔 Notificaciones activadas en este teléfono ✓": "🔔 Notifications turned on for this phone ✓",
      // Los próximos días (inicio del dueño)
      "Los próximos días": "The next few days", "Tomar una foto de esta obra": "Take a photo of this job",
      // Inspecciones de la semana
      "Inspecciones de la semana": "This week's inspections",
      "pasó": "passed", "sin resultado": "no result", "programada": "scheduled",
      // Resumen del mes
      "Resumen del mes": "Month summary", "Facturado": "Invoiced", "Facturas cobradas": "Invoices collected",
      "Horas del equipo": "Team hours", "Inspecciones pasadas": "Inspections passed", "Trabajos completados": "Jobs completed",
      "Cobrado = facturas con fecha de cobro en el mes (según QuickBooks). Facturado = facturas emitidas en el mes.":
        "Collected = invoices with a payment date in the month (per QuickBooks). Invoiced = invoices issued in the month.",
      // Horas de la semana
      "Un punto (·) es un día de semana ya pasado sin horas reportadas.": "A dot (·) is a past weekday with no hours reported.",
      // Corregir un pendiente
      "Corrige el texto del pendiente:": "Fix the open item's text:", "Pendiente corregido ✓": "Open item fixed ✓",
      // Horas del equipo (campo y dueño)
      "Tus horas de hoy": "Your hours today", "Ya reportaste hoy. Gracias.": "You already reported today. Thanks.",
      "Todavía no reportaste tus horas de hoy": "You haven't reported today's hours yet",
      "Repórtalas antes de irte — después se olvidan.": "Report them before you leave — later you'll forget.",
      "Pide permiso para corregir este reporte": "Asking permission to fix this report",
      "Permiso dado — esperando su corrección": "Permission given — waiting for their fix",
      "Esta semana": "This week", "Semana pasada": "Last week",
      "nunca ha abierto la app": "has never opened the app", "no le llegan los avisos": "not getting notifications",
      "toca para ver sus reportes": "tap to see their reports",
      "Permiso dado ✓ — le llegó el aviso al teléfono": "Permission given ✓ — the notification reached their phone",
      "Un reporte va de más de 0 hasta 16 horas — no se cambió nada.": "A report must be more than 0 and up to 16 hours — nothing was changed.",
      "¿Quieres MOVER este reporte a OTRO proyecto?": "Do you want to MOVE this report to ANOTHER project?",
      "Aceptar = elegir el proyecto correcto.": "OK = choose the right project.",
      "Cancelar = dejarlo donde está.": "Cancel = leave it where it is.",
      "Aceptar": "OK",
      "¿A qué proyecto va este reporte?": "Which project does this report go to?",
      "No se movió nada.": "Nothing was moved.",
      "Contrato (sin change order)": "Contract (no change order)",
      "¿Estas horas van al contrato o a un change order?": "Do these hours go to the contract or to a change order?",
      "Reporte corregido y movido de proyecto ✓": "Report fixed and moved to another project ✓",
      "Reporte corregido ✓": "Report fixed ✓",
      "¿Eliminar este reporte de horas?": "Delete this hours report?", "Reporte eliminado ✓": "Report deleted ✓",
      // Categorías y resumen del dueño
      "Todavía no hay proyectos": "No projects yet",
      "Firmado activo": "Active signed", "Propuesto sin firmar": "Proposed, not signed"
    });
    // El resto del error (lo que dice la base) se traduce aparte si el diccionario lo tiene
    REGLAS.push(
      [/^Esta app es la versión (\S+)\. Si te dije un número mayor, cierra la app del todo y vuelve a abrirla: se actualiza sola\.$/,
        "This app is version $1. If I told you a higher number, close the app completely and open it again: it updates itself."],
      [/^No se pudo conectar: (.+)$/, s => s.replace(/^No se pudo conectar: (.+)$/, (m, x) => "Couldn't connect: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^El servidor no contestó bien: (.+)$/, s => s.replace(/^El servidor no contestó bien: (.+)$/, (m, x) => "The server didn't answer properly: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^Error cargando los datos: (.+)$/, s => s.replace(/^Error cargando los datos: (.+)$/, (m, x) => "Error loading the data: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^Error actualizando: (.+)$/, s => s.replace(/^Error actualizando: (.+)$/, (m, x) => "Error refreshing: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^No se pudo: (.+)$/, s => s.replace(/^No se pudo: (.+)$/, (m, x) => "Couldn't do it: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^No salió el correo: (.+)$/, s => s.replace(/^No salió el correo: (.+)$/, (m, x) => "The email didn't go out: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^No se pudo activar: (.+)$/, s => s.replace(/^No se pudo activar: (.+)$/, (m, x) => "Couldn't turn them on: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^No se pudo enviar: (.+)$/, s => s.replace(/^No se pudo enviar: (.+)$/, (m, x) => "Couldn't send: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      [/^No se pudo corregir: (.+)$/, s => s.replace(/^No se pudo corregir: (.+)$/, (m, x) => "Couldn't fix it: " + (window.MXP_I18N ? window.MXP_I18N.traducir(x) : x))],
      // Nota de una inspección en el calendario
      [/^Jurisdicción: (.+)$/, "Jurisdiction: $1"],
      // Contratistas: invitar a su portal
      [/^¿Mandarle a (.+) \((\S+@\S+)\) la invitación a su portal\?$/, "Send $1 ($2) the invitation to their portal?"],
      [/^Invitación enviada a (\S+@\S+) ✓$/, "Invitation sent to $1 ✓"],
      // Licencia y seguros: el chip de vencimiento
      [/^VENCIDO (\d{4}-\d{2}-\d{2})$/, "EXPIRED $1"],
      [/^vence en (-?\d+) días$/, s => { const n = parseInt(s.slice(9), 10); return n === 0 ? "expires today" : `expires in ${n} ${n === 1 ? "day" : "days"}`; }],
      [/^vence (\d{4}-\d{2}-\d{2})$/, "expires $1"],
      // Contratistas: «Wisdom · (apagado)», «3 obras · 2 con contrato · Kevin», el email y las visitas
      [/^(.+) · \(apagado\)$/, "$1 · (off)"],
      [/^(\d+) obras?(?: · (\d+) con contrato)?(?: · (.+))?$/, s => {
        const m = s.match(/^(\d+) obras?(?: · (\d+) con contrato)?(?: · (.+))?$/);
        const n = Number(m[1]);
        return `${n} ${n === 1 ? "job" : "jobs"}${m[2] ? ` · ${m[2]} with a contract` : ""}${m[3] ? ` · ${m[3]}` : ""}`;
      }],
      [/^(?:✉️? )?(\S+@\S+|sin email — ponlo antes de invitar)(?: · invitado el (\S+))?(?: · (?:👀 )?entró el ([^·]+?))?(?: ·)?$/, s => {
        const m = s.match(/^(✉️? )?(\S+@\S+|sin email — ponlo antes de invitar)(?: · invitado el (\S+))?(?: · (?:👀 )?entró el ([^·]+?))?( ·)?$/);
        if (!m[3] && !m[4] && !/^sin email/.test(m[2])) return s;
        return (m[1] || "") + (/^sin email/.test(m[2]) ? "no email — add it before inviting" : m[2]) +
          (m[3] ? ` · invited on ${m[3]}` : "") + (m[4] ? ` · 👀 opened it on ${m[4]}` : "") + (m[5] || "");
      }],
      [/^(?:👀 )?entró el (\d{4}-\d{2}-\d{2}(?: \d{1,2}:\d{2})?)$/, s => s.replace(/entró el /, "opened it on ")],
      // Los próximos días: «2 más después del fri 2 ·»
      [/^(\d+) más después del (\S+ \d+)(?: ·)?$/, s => {
        const m = s.match(/^(\d+) más después del (\S+) (\d+)( ·)?$/);
        return `${m[1]} more after ${m[2].charAt(0).toUpperCase() + m[2].slice(1)} ${m[3]}${m[4] || ""}`;
      }],
      // Inspección sin tipo: «Inspección — Casa Dicke»
      [/^Inspección — (.+)$/, "Inspection — $1"],
      // Avisos del dueño (cada línea de la lista)
      [/^(\d+) materiale?s? generale?s? por comprar$/, s => { const n = parseInt(s, 10); return `${n} general ${n === 1 ? "material" : "materials"} to buy`; }],
      [/^(.+) está TERMINADO y quedan (\S+) sin cobrar$/, "$1 is FINISHED and $2 is still not collected"],
      [/^(.+) está aprobado SIN monto de contrato — ponle el precio para poder facturar$/, "$1 is approved WITHOUT a contract amount — add the price so you can invoice"],
      [/^Factura #(\S+) de (.+) lleva (\d+) días sin pagar \((\S+)(?: de (\S+))?\)$/, s => {
        const m = s.match(/^Factura #(\S+) de (.+) lleva (\d+) días sin pagar \((\S+)(?: de (\S+))?\)$/);
        return `Invoice #${m[1]} for ${m[2]} has been unpaid for ${m[3]} days (${m[4]}${m[5] ? ` of ${m[5]}` : ""})`;
      }],
      [/^(.+): la propuesta VENCIÓ hace (\d+) días? \(valía hasta (\S+)\) — renuévala desde la ficha o márcala no aprobada$/, s => {
        const m = s.match(/^(.+): la propuesta VENCIÓ hace (\d+) días? \(valía hasta (\S+)\) — /);
        return `${m[1]}: the proposal EXPIRED ${m[2]} ${m[2] === "1" ? "day" : "days"} ago (valid until ${m[3]}) — renew it from the job file or mark it not approved`;
      }],
      [/^(.+): la propuesta vence (HOY|en \d+ días?) \((\S+)\) — llama al cliente antes$/, s => {
        const m = s.match(/^(.+): la propuesta vence (HOY|en (\d+) días?) \((\S+)\) — /);
        const cuando = m[2] === "HOY" ? "TODAY" : `in ${m[3]} ${m[3] === "1" ? "day" : "days"}`;
        return `${m[1]}: the proposal expires ${cuando} (${m[4]}) — call the client first`;
      }],
      [/^(.+): propuesta sin respuesta hace (\d+) días? — llama o escribe al cliente, o márcala no aprobada$/, s => {
        const m = s.match(/^(.+): propuesta sin respuesta hace (\d+) días? — /);
        return `${m[1]}: no answer on the proposal for ${m[2]} ${m[2] === "1" ? "day" : "days"} — call or text the client, or mark it not approved`;
      }],
      [/^(.+): ([\d.]+)h trabajadas de ([\d.]+)h estimadas — se está comiendo el margen$/, "$1: $2h worked of $3h estimated — it's eating the margin"],
      [/^(.+): el labor va al (\d+)% de lo estimado \(([\d.]+)h de ([\d.]+)h\) — vigílalo$/, "$1: labor is at $2% of the estimate ($3h of $4h) — keep an eye on it"],
      [/^(.+): materiales PASADOS del presupuesto — (\S+) de (\S+)$/, "$1: materials OVER budget — $2 of $3"],
      [/^(.+): materiales al (\d+)% del presupuesto \((\S+) de (\S+)\)$/, "$1: materials at $2% of budget ($3 of $4)"],
      // Capacidad del equipo: «📊 Próximos 7 días: Jian 3 días · Osbel 1 día · 2 eventos sin asignar»
      [/^(?:📊 )?Próximos 7 días: (.+)$/, s => {
        const i = s.indexOf("Próximos 7 días: ");
        const partes = s.slice(i + 17).split(" · ").map(p => {
          if (p === "nadie agendado") return "nobody scheduled";
          let m = p.match(/^(\d+) eventos? sin asignar$/);
          if (m) return `${m[1]} unassigned ${m[1] === "1" ? "event" : "events"}`;
          m = p.match(/^(.+) (\d+) días?$/);
          if (m) return `${m[1]} ${m[2]} ${m[2] === "1" ? "day" : "days"}`;
          return p;
        });
        return s.slice(0, i) + "Next 7 days: " + partes.join(" · ");
      }],
      // La línea de cada persona en «Reporte de horas del equipo» (todas sus piezas, en cualquier orden)
      [/^(?:· )?(?:sin reportes todavía|reportó hoy ✓|reportó ayer ✓|hace \d+ días(?: sin reportar)?|📱 en la app: \S+|📱 nunca ha abierto la app|📱 no abre la app hace \d+ días \(\S+\)|🔔 avisos en (?:su teléfono|\d+ teléfonos)|🔕 no le llegan los avisos|toca para ver sus reportes)(?: · (?:sin reportes todavía|reportó hoy ✓|reportó ayer ✓|hace \d+ días(?: sin reportar)?|📱 en la app: \S+|📱 nunca ha abierto la app|📱 no abre la app hace \d+ días \(\S+\)|🔔 avisos en (?:su teléfono|\d+ teléfonos)|🔕 no le llegan los avisos|toca para ver sus reportes))*(?: ·)?$/, s => {
        const ini = s.startsWith("· ") ? "· " : "", fin = / ·$/.test(s) ? " ·" : "";
        const cuerpo = s.slice(ini.length, s.length - fin.length);
        const pieza = p => {
          let m;
          if (p === "sin reportes todavía") return "no reports yet";
          if (p === "reportó hoy ✓") return "reported today ✓";
          if (p === "reportó ayer ✓") return "reported yesterday ✓";
          if ((m = p.match(/^hace (\d+) días sin reportar$/))) return `${m[1]} days without reporting`;
          if ((m = p.match(/^hace (\d+) días$/))) return `${m[1]} days ago`;
          if ((m = p.match(/^📱 en la app: (\S+)$/))) return `📱 last opened: ${m[1]}`;
          if (p === "📱 nunca ha abierto la app") return "📱 has never opened the app";
          if ((m = p.match(/^📱 no abre la app hace (\d+) días \((\S+)\)$/))) return `📱 hasn't opened the app in ${m[1]} days (${m[2]})`;
          if (p === "🔔 avisos en su teléfono") return "🔔 notifications on their phone";
          if ((m = p.match(/^🔔 avisos en (\d+) teléfonos$/))) return `🔔 notifications on ${m[1]} phones`;
          if (p === "🔕 no le llegan los avisos") return "🔕 not getting notifications";
          if (p === "toca para ver sus reportes") return "tap to see their reports";
          return p;
        };
        return ini + cuerpo.split(" · ").map(pieza).join(" · ") + fin;
      }],
      [/^(?:📱 )?no abre la app hace (\d+) días \((\S+)\)$/, s => s.replace(/no abre la app hace (\d+) días \((\S+)\)/, "hasn't opened the app in $1 days ($2)")],
      // Categorías y resumen del dueño (el campo ve $•••)
      [/^(\$[\d,.]+|\$•••|—) firmado$/, "$1 signed"],
      [/^(\$[\d,.]+|\$•••|—) propuesto$/, "$1 proposed"],
      [/^Propuesto sin firmar \((\d+)\)$/, "Proposed, not signed ($1)"],
      [/^Facturado sin pagar \((\d+)\)$/, "Invoiced, not paid ($1)"]
    );
  // · parte-B
  // ---------- Parte B: app.js 2208–4478 (resumen, «Proyectos», «Más», lista, horas,
    // hitos, release, rentabilidad, checklist, chat, asistente, ayuda externa,
    // facturas, estado, trato, contratista, franja de dinero, tablero, señales) ----------
    Object.assign(D, {
      // Resumen del dueño
      "Firmado activo": "Active signed",
      "Propuesto sin firmar": "Proposed, not signed",
      "Facturado sin pagar": "Invoiced, unpaid",
      // Desglose del contrato y facturas (cabeceras de tabla)
      "Alcance": "Scope", "Monto": "Amount", "Estado": "Status", "Nº": "No.", "PAGADA": "PAID",
      // Hitos de pago
      "ningún hito de pago": "no payment milestones",
      ". Así no se puede facturar con el botón Facturar ni avisa cuando toca cobrar. Cópialos del SOW (normalmente 35/45/20 o 50/50).":
        ". Without them you can't invoice with the Invoice button, and the app won't remind you when it's time to collect. Copy them from the SOW (usually 35/45/20 or 50/50).",
      "Waiver and Release of Lien de este pago (F.S. 713.20)": "Waiver and Release of Lien for this payment (F.S. 713.20)",
      "Ya entró el dinero de este hito — marcarlo COBRADO": "The money for this milestone came in — mark it COLLECTED",
      "facturado, sin pagar": "invoiced, unpaid",
      // Release of Lien (preguntas y avisos)
      "¿Es el ÚLTIMO pago de la obra?": "Is this the LAST payment on the job?",
      "Aceptar = release FINAL (713.20(5)).": "OK = FINAL release (713.20(5)).",
      "Cancelar = release de pago parcial (713.20(4)).": "Cancel = progress payment release (713.20(4)).",
      "¿A nombre de quién está la propiedad?": "Whose name is the property in?",
      "El formulario de la ley (713.20) pide el nombre del dueño, y no es la empresa que te paga.":
        "The statutory form (713.20) asks for the owner's name, and that's not the company paying you.",
      "Sin el nombre del dueño no se puede armar el release": "The release can't be prepared without the owner's name",
      "El navegador bloqueó la ventana. Permite ventanas emergentes y vuelve a tocar.":
        "The browser blocked the window. Allow pop-ups and tap again.",
      "Elige «Guardar como PDF»; después súbelo a los documentos de la obra":
        "Choose “Save as PDF”; then upload it to the job's documents",
      // Rentabilidad
      "Define el costo por hora del equipo en": "Set the team's hourly cost in",
      "📊 Gastos → 💲 Costos del equipo": "📊 Expenses → 💲 Team costs",
      "y aquí verás la ganancia real de este proyecto.": "and you'll see this project's real profit here.",
      "Todavía no hay horas ni compras registradas en este proyecto.": "No hours or purchases logged on this project yet.",
      "Sale de las horas reportadas × el costo de cada trabajador, más los materiales comprados con precio. El presupuesto de materiales se define en 📊 Gastos.":
        "It comes from reported hours × each worker's cost, plus materials bought with a price. The materials budget is set in 📊 Expenses.",
      // Checklist (corrige «In between»)
      "Intermedio": "Medium", "🟡 Intermedio": "🟡 Medium",
      "Bloque en que sale en el portal del cliente": "Block it shows under in the client portal",
      "Ej: arreglar el layout de las luces": "E.g.: fix the lighting layout",
      "Tarea agregada ✓": "Task added ✓", "Tarea completada ✓": "Task completed ✓",
      "Tarea devuelta a pendiente": "Task reopened", "Tarea corregida ✓": "Task fixed ✓",
      "🔴 Urgente — sale en el inicio y avisa al equipo": "🔴 Urgent — shows on the home screen and alerts the team",
      "Corrige el texto de la tarea": "Fix the task text",
      "¿En qué bloque sale este punto en el portal del cliente?": "Which block should this item show under in the client portal?",
      "(Déjalo vacío para que salga en la lista de siempre.)": "(Leave it empty to show it in the regular list.)",
      "El punto vuelve a la lista de siempre": "The item goes back to the regular list",
      // Chat del equipo
      "No se pudo cargar el chat — revisa la señal.": "Couldn't load the chat — check your signal.",
      "Reintentar": "Retry", "Grupo Max Power": "Max Power group", "Privado": "Private",
      // Asistente
      "Asistente de Max Power": "Max Power assistant", "ve todo": "sees everything", "sin dinero": "no money",
      "Pregúntale por tus proyectos, el dinero, las horas o el calendario. También puedes dictarle para que guarde gastos, horas o materiales.":
        "Ask it about your projects, the money, hours or the calendar. You can also dictate to it so it saves expenses, hours or materials.",
      "Pregúntale cómo hacer algo en la app, o dile tus horas y el material que falta para que él lo anote. De dinero no sabe nada — eso lo lleva Edgar.":
        "Ask it how to do something in the app, or tell it your hours and the material you're missing so it writes them down. It knows nothing about money — Edgar handles that.",
      "Escríbele abajo. Está para ayudarte.": "Type below. It's here to help you.",
      "pensando": "thinking", "pensando…": "thinking…",
      "Escribe tu pregunta…": "Type your question…",
      "Empezar de nuevo": "Start over",
      "¿Borrar esta conversación y empezar de nuevo?": "Delete this conversation and start over?",
      "Todavía no me han conectado la llave del asistente. Edgar tiene que ponerla en Supabase (ANTHROPIC_API_KEY).":
        "The assistant's key isn't connected yet. Edgar has to set it in Supabase (ANTHROPIC_API_KEY).",
      "No pude contestar eso. Inténtalo otra vez en un momento.": "I couldn't answer that. Try again in a moment.",
      // Las preguntas de ejemplo (el botón manda al asistente el texto que se ve)
      "¿Cómo va el dinero de Mirabella?": "How's the money on Mirabella?",
      "¿Qué facturas llevan más días sin cobrar?": "Which invoices have gone unpaid the longest?",
      "¿Qué se me está olvidando esta semana?": "What am I forgetting this week?",
      "¿Cómo reporto mis horas de un Change Order?": "How do I report my hours for a change order?",
      "¿Qué tengo agendado esta semana?": "What do I have scheduled this week?",
      "¿Qué calibre lleva un breaker de 50 amperes?": "What wire size goes on a 50 amp breaker?",
      // Ayuda externa
      "AJUSTE": "LUMP SUM", "Anular": "Void",
      "Anular (dice por qué): el costo pasa a 0 y queda el rastro": "Void (asks why): the cost goes to 0 and the record stays",
      "Anotar trabajo externo": "Log outside work",
      "Ayudante de tu nómina (opcional — usa su tarifa sola)": "Helper on your payroll (optional — uses their rate automatically)",
      "Escribir libre": "Type it in",
      "Quién / qué hizo": "Who / what they did",
      "Ej: Pedro — ayudante, demolición 2 días": "E.g.: Pedro — helper, demolition 2 days",
      "Por ajuste (precio cerrado)": "Lump sum (fixed price)", "Por horas / por día": "By the hour / by the day",
      "Horas (si fue por horas)": "Hours (if paid by the hour)", "Costo total ($)": "Total cost ($)",
      "Esto entra como gasto del proyecto y se resta del margen. El trabajador NO necesita cuenta en la app.":
        "This goes in as a project expense and comes off the margin. The worker does NOT need an account in the app.",
      // Facturas de la obra
      "borrador: todavía no se emitió": "draft: not issued yet",
      "Marcarla como COBRADA — es dinero personal: no se suma a lo cobrado de la obra":
        "Mark it PAID — it's personal money: not added to the job's collected amount",
      "Marcarla como COBRADA — es lo que cuadra el dinero de la app con el banco":
        "Mark it PAID — this is what keeps the app's money matched with the bank",
      // Estado
      "Cambiar estado": "Change status",
      "Sale de las obras en ejecución. Si fue sin querer, se reabre desde el estado.":
        "It leaves the jobs in progress. If it was a mistake, reopen it from the status.",
      // ¿Con quién es el trato? · Contratista
      "Directo": "Direct",
      "Ej: Kevin Haseney — sale en el contrato junto al contacto de la empresa":
        "E.g.: Kevin Haseney — appears on the contract next to the company contact",
      "Pega el SQL de contratistas y aquí podrás decir de qué empresa es esta obra.":
        "Paste the contractors SQL and you'll be able to say here which company this job belongs to.",
      "Notice to Owner mandado el": "Notice to Owner sent on",
      "¿De qué contratista es esta obra?": "Which contractor is this job for?",
      "ninguno (trabajo directo)": "none (direct work)",
      "¿Cómo participan?": "How are they involved?",
      "Solo coordinan — la paga el dueño (NO ven dinero)": "Coordination only — the owner pays (they do NOT see money)",
      "Es el cliente — le facturamos a ellos (SÍ ven el dinero)": "They're the client — we bill them (they DO see the money)",
      "Esta obra es de": "This job belongs to",
      "de esta obra": "for this job", "ningún monto": "no amounts", ", y no firman.": ", and they don't sign.",
      // Sumar a lo cobrado
      "(Si ese dinero ya estaba contado, dile que NO.)": "(If that money was already counted, answer NO.)"
    });
  
    // Estados de la obra tal como los pinta la app (para las frases con estado dentro)
    const ESTADO_EN_B = { "Estimando": "Estimating", "Enviado": "Sent", "Aprobado": "Approved", "En ejecución": "In progress",
      "En pausa": "On hold", "Completado": "Completed", "No aprobado": "Not approved" };
    // El error que va detrás de «No se pudo…»: se traduce si el diccionario lo conoce
    const trB = x => (D[x] !== undefined ? D[x] : x);
    const MES_ES_B = { ene: "Jan", feb: "Feb", mar: "Mar", abr: "Apr", may: "May", jun: "Jun",
      jul: "Jul", ago: "Aug", sep: "Sep", oct: "Oct", nov: "Nov", dic: "Dec" };
    REGLAS.push(
      // Resumen del dueño
      [/^Propuesto sin firmar \((\d+)\)$/, "Proposed, not signed ($1)"],
      [/^Facturado sin pagar \((\d+)\)$/, "Invoiced, unpaid ($1)"],
      // Hitos
      [/^(⚠ )?Este proyecto tiene contrato de (\S+) pero$/, "$1This project has a $2 contract but"],
      [/^(.+) · facturado, sin pagar$/, "$1 · invoiced, unpaid"],
      [/^(⚠ )?Los hitos suman (\S+) y el contrato dice (\S+) — (faltan|sobran) (\S+)( por repartir)?\. Compáralo con el SOW firmado: manda el SOW\.$/,
        s => { const m = s.match(/^(⚠ )?Los hitos suman (\S+) y el contrato dice (\S+) — (faltan|sobran) (\S+?)( por repartir)?\. Compáralo/);
          return `${m[1] || ""}The milestones add up to ${m[2]} and the contract says ${m[3]} — ${m[5]} ${m[4] === "faltan" ? "still to assign" : "too much"}. Check it against the signed SOW: the SOW rules.`; }],
      // Gastos y rentabilidad
      [/^(\d+)% del presupuesto \((\S+)\)$/, "$1% of budget ($2)"],
      [/^Mano de obra \((\S+) h\)$/, "Labor ($1 h)"],
      [/^(⚠ )?Este margen todavía no es real: (.+)\. Mientras falten compras por cargar, el margen sale más alto de lo que es\.$/, s => {
        const m = s.match(/^(⚠ )?Este margen todavía no es real: (.+)\. Mientras falten/);
        const parte = t => {
          const r = t.match(/^solo hay recibos por el (\d+)% del material presupuestado \((\S+) de (\S+)\)$/);
          if (r) return `there are receipts for only ${r[1]}% of the budgeted material (${r[2]} of ${r[3]})`;
          if (t === "no hay ni una compra de material cargada") return "not a single material purchase has been entered";
          if (t === "no hay horas reportadas") return "no hours have been reported";
          return t;
        };
        return `${m[1] || ""}This margin isn't real yet: ${m[2].split(" y ").map(parte).join(" and ")}. Until the missing purchases are entered, the margin shows higher than it really is.`;
      }],
      // Checklist
      [/^No se pudo: (.+)$/, s => "Couldn't do it: " + trB(s.replace(/^No se pudo: /, ""))],
      [/^Categoría: (🔴|🟡|⚪) (Urgente|Intermedio|Puede esperar)$/, s => {
        const m = s.match(/^Categoría: (\S+) (.+)$/);
        return `Category: ${m[1]} ${{ "Urgente": "Urgent", "Intermedio": "Medium", "Puede esperar": "Can wait" }[m[2]]}`; }],
      [/^Bloques de esta obra: (.+)$/, "Blocks on this job: $1"],
      [/^🏷 Bloque: (.+)$/, "🏷 Block: $1"],
      // Chat
      [/^Tú: (.+)$/, "You: $1"],
      [/^No se pudo enviar: (.+)$/, s => "Couldn't send: " + trB(s.replace(/^No se pudo enviar: /, ""))],
      // Asistente
      [/^No hay conexión con el asistente ahora mismo\.( .*)?$/, "No connection to the assistant right now.$1"],
      // Arranque
      [/^gestión pendiente · (.+)$/, "pending task · $1"],
      // Ayuda externa: los ejemplos numéricos de los campos
      [/^Ej: (\d[\d.,]*)$/, "E.g.: $1"],
      // Facturas: la fecha corta que llega en español desde db.js («17 sep»)
      [/^(\d{1,2}) (ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)$/, s => { const m = s.split(" "); return MES_ES_B[m[1]] + " " + m[0]; }],
      [/^Anuladas con nota de crédito \(no se cobran ni suman\): (.+)$/, s =>
        "Voided with a credit memo (not collected or counted): " + s.replace(/^Anuladas con nota de crédito \(no se cobran ni suman\): /, "")
          .replace(/ (\d{1,2}) (ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic) · /g, (x, d, mm) => ` ${MES_ES_B[mm]} ${d} · `)],
      // Estado de la obra
      [/^¿Marcar «(.+)» como COMPLETADA\?$/, "Mark “$1” as COMPLETED?"],
      [/^¿Pasar «(.+)» a (Estimando|Enviado|Aprobado|En ejecución|En pausa|Completado|No aprobado)\?$/, s => {
        const m = s.match(/^¿Pasar «(.+)» a (Estimando|Enviado|Aprobado|En ejecución|En pausa|Completado|No aprobado)\?$/);
        return `Move “${m[1]}” to ${ESTADO_EN_B[m[2]]}?`; }],
      [/^Estado: (Estimando|Enviado|Aprobado|En ejecución|En pausa|Completado|No aprobado) ✓$/, s =>
        "Status: " + ESTADO_EN_B[s.slice(8, -2)] + " ✓"],
      [/^No se pudo cambiar: (.+)$/, s => "Couldn't change it: " + trB(s.replace(/^No se pudo cambiar: /, ""))],
      // Contratista: la frase que sigue al nombre (con o sin el contacto entre paréntesis)
      [/^(\(.+\))?\. El contrato es con ellos: en su portal ven los hitos, lo facturado y lo cobrado$/,
        "$1. The contract is with them: in their portal they see the milestones, what's invoiced and what's collected"],
      [/^(\(.+\))?\. La obra la paga el dueño de la casa: ellos ven calendario, inspecciones, fotos y documentos, pero$/,
        "$1. The homeowner pays for the job: they see the calendar, inspections, photos and documents, but"],
      // Sumar a lo cobrado (confirmar, línea por línea)
      [/^¿Le sumo (\S+) de (la factura #\S+|el hito ".*") a lo cobrado del proyecto\?$/, s => {
        const m = s.match(/^¿Le sumo (\S+) de (la factura #\S+|el hito ".*") a lo cobrado del proyecto\?$/);
        const que = m[2].replace(/^la factura /, "invoice ").replace(/^el hito /, "milestone ");
        return `Add ${m[1]} from ${que} to the project's collected amount?`; }],
      [/^Cobrado ahora: (\S+)$/, "Collected now: $1"],
      [/^Quedaría en: (\S+)$/, "It would become: $1"],
      // «Cobrado» no cuadra con las facturas
      [/^(⚠ )?"Cobrado" dice (\S+) pero las facturas ya marcadas cobradas suman (\S+) — faltan (\S+) por contar\.$/,
        "$1\"Collected\" says $2 but the invoices already marked paid add up to $3 — $4 still to be counted."],
      [/^(⚠ )?"Cobrado" dice (\S+) y todas las facturas de este proyecto juntas suman (\S+) — sobran (\S+) sin ninguna factura detrás\.$/,
        "$1\"Collected\" says $2 and all this project's invoices together add up to $3 — $4 extra with no invoice behind it."]
    );
  // · parte-C
  // ---------- Trozo C (app.js 4421–6647): señales, hojas, ficha (documentos, cliente,
    // inspecciones, fotos), sus botones y avisos, ventanas de la app, proyecto nuevo ----------
    Object.assign(D, {
      // Correcciones a traducciones viejas (la prioridad del checklist sale en la hoja de la ficha)
      "Intermedio": "Medium", "🟡 Intermedio": "🟡 Medium",
      // Señales y hojas
      "Inspección Servicio / Panel": "Service / panel inspection", "Inspección Otra": "Other inspection",
      // Documentos
      "Tu firma se pone sola cuando firme el cliente": "Your signature is added automatically when the client signs",
      "Documento": "Document", "Título": "Title", "Ej: SOW firmado": "E.g.: signed SOW",
      "Archivo PDF (recomendado — vive en la app, sin permisos de Drive)": "PDF file (recommended — it lives in the app, no Drive permissions needed)",
      "… o pega un enlace de Drive": "… or paste a Drive link",
      // Cliente: qué ve y dónde vamos
      "El cliente todavía no ha abierto su portal.": "The client hasn't opened their portal yet.",
      "Luz verde encendida": "Green light on",
      "el cliente ve TODOS los documentos —contratos y Change Orders incluidos—, todas las fotos y todos los videos, estén marcados o no. Lo que subas a este proyecto se le publica solo. El dinero solo sale si prendes «Ve el dinero» — pensado para clientes directos, no para trabajos vía contratista.":
        "the client sees ALL documents —contracts and change orders included—, all photos and all videos, marked or not. Anything you upload to this project is published to them automatically. Money only shows if you turn on «Sees money» — meant for direct clients, not for jobs through a contractor.",
      "El cliente ve: etapa, checklist con su %, inspecciones, próximos días de trabajo y los documentos que le enseñes. Los RFI salen siempre; los CONTRATOS nunca salen (tienen precios) a menos que tú los marques. El dinero solo sale si prendes «Ve el dinero» — pensado para clientes directos, no para trabajos vía contratista.":
        "The client sees: stage, checklist with its %, inspections, upcoming work days and the documents you show them. RFIs always show; CONTRACTS never show (they have prices) unless you mark them. Money only shows if you turn on «Sees money» — meant for direct clients, not for jobs through a contractor.",
      "El cliente SÍ ve su contrato, pagos y facturas — toca para ocultarlos": "The client DOES see their contract, payments and invoices — tap to hide them",
      "El cliente NO ve dinero — toca para mostrarle su contrato, pagos y facturas": "The client does NOT see money — tap to show them their contract, payments and invoices",
      "Luz verde: el cliente ve TODOS los documentos, fotos y videos — toca para volver al modo uno-a-uno": "Green light: the client sees ALL documents, photos and videos — tap to go back to one-by-one mode",
      "Toca para darle luz verde: verá TODOS los documentos (contratos y CO), fotos y videos sin marcarlos uno a uno": "Tap to give them the green light: they'll see ALL documents (contracts and COs), photos and videos without marking them one by one",
      "Sin escribir. El cliente no ve esta tarjeta hasta que digas en qué va la obra.": "Not written yet. The client won't see this card until you say where the job stands.",
      "Corre el SQL del portal para crearle la llave a este proyecto.": "Run the portal SQL to create this project's key.",
      // Decisiones del cliente
      "Qué necesita decidir el cliente": "What the client needs to decide",
      "Ej: elegir el fixture del comedor": "E.g.: pick the dining room fixture",
      "Para cuándo (opcional)": "By when (optional)", "+ Agregar decisión": "+ Add decision",
      "¿Eliminar esta decisión?": "Delete this decision?",
      "Decisión agregada ✓ — el cliente la verá en su portal": "Decision added ✓ — the client will see it in their portal",
      "Decisión marcada ✓": "Decision marked ✓", "Decisión eliminada ✓": "Decision deleted ✓",
      // Eliminar la obra (la palabra ELIMINAR se queda: es la que hay que escribir)
      "Se borran también sus finanzas, hitos, facturas, horas del equipo, fotos, documentos y pendientes. Esto NO se puede deshacer.":
        "Its finances, milestones, invoices, crew hours, photos, documents and open items are deleted too. This can NOT be undone.",
      "Si es lo que quieres, escribe ELIMINAR (en mayúsculas):": "If that's what you want, type ELIMINAR (in capitals):",
      "No se eliminó nada — no escribiste ELIMINAR.": "Nothing was deleted — you didn't type ELIMINAR.",
      "¿La marco Completado ahora?": "Should I mark it Completed now?",
      // Inspecciones
      "Servicio / Panel": "Service / Panel", "Otra": "Other",
      "Fecha (si ya está programada)": "Date (if already scheduled)", "Nº de permiso": "Permit #",
      "Ej: ELE2026-01234": "E.g.: ELE2026-01234", "Jurisdicción": "Jurisdiction", "Ej: City of Tampa": "E.g.: City of Tampa",
      "Notas (opcional)": "Notes (optional)", "Ej: llamar al inspector antes de las 8am": "E.g.: call the inspector before 8am",
      "Inspección guardada ✓ — ya aparece en el calendario": "Inspection saved ✓ — it's on the calendar now",
      "Inspección fallida anotada — programa la reinspección.": "Failed inspection logged — schedule the reinspection.",
      "Resultado actualizado ✓": "Result updated ✓",
      "Úsalo solo si se anotó por error. Esto no se puede deshacer.": "Only use this if it was logged by mistake. This can't be undone.",
      // Fotos
      "Foto de obra": "Job photo", "Ej: rough del segundo piso terminado": "E.g.: second-floor rough finished",
      "No se pudo procesar": "Couldn't process it",
      "Descripción de la foto (o video):": "Photo (or video) description:", "Descripción corregida ✓": "Description updated ✓",
      "👁 El cliente ahora VE esta foto": "👁 The client now SEES this photo", "🚫 Foto oculta para el cliente": "🚫 Photo hidden from the client",
      "Subiendo…": "Uploading…", "Subiendo la foto…": "Uploading the photo…", "Subido ✓": "Uploaded ✓",
      "Ese video es muy grande. Grábalo CORTO, como una inspección virtual (30-45 segundos, máx. 25 MB).":
        "That video is too big. Record it SHORT, like a virtual inspection (30-45 seconds, max. 25 MB).",
      "📶 Sin señal — la foto quedó guardada en el teléfono y se sube sola cuando vuelva la señal.":
        "📶 No signal — the photo was saved on the phone and uploads by itself when the signal comes back.",
      "No se pudieron cargar las fotos — revisa la señal y vuelve a entrar al proyecto.": "Couldn't load the photos — check the signal and open the project again.",
      "No se pudieron cargar los documentos — revisa la señal.": "Couldn't load the documents — check the signal.",
      // Botones de la ficha: email, resumen, portal, contratista
      "Email del cliente (para mandarle su copia firmada y avisos):": "Client email (to send them their signed copy and notices):",
      "✉️ Email del cliente guardado": "✉️ Client email saved",
      "En dos o tres frases, ¿en qué va la obra y qué falta del lado del cliente?": "In two or three sentences, where does the job stand and what's still needed from the client?",
      "(Sin montos: esto lo lee el cliente arriba de todo. Déjalo vacío para quitar la tarjeta.)": "(No amounts: the client reads this at the very top. Leave it empty to remove the card.)",
      "📣 El cliente ya ve en qué va la obra": "📣 The client now sees where the job stands",
      "Se quitó el resumen del portal": "The portal summary was removed",
      "Link del cliente copiado ✓ — pégalo en WhatsApp": "Client link copied ✓ — paste it in WhatsApp",
      "Copia el link del cliente:": "Copy the client link:", "Copia el enlace:": "Copy the link:",
      "🟢 ¿Darle a este cliente ACCESO COMPLETO a su proyecto?": "🟢 Give this client FULL ACCESS to their project?",
      "Verá TODOS los documentos (contratos y change orders incluidos, con sus precios) y TODAS las fotos y videos — sin tener que marcarlos uno a uno.":
        "They'll see ALL documents (contracts and change orders included, with their prices) and ALL photos and videos — without marking them one by one.",
      "Las horas del equipo y las compras de materiales NUNCA salen en el portal.": "Crew hours and material purchases NEVER show in the portal.",
      "Solo para clientes directos.": "Only for direct clients.",
      "🟢 Luz verde — el cliente ve todo su proyecto": "🟢 Green light — the client sees their whole project",
      "De vuelta al modo uno-a-uno (solo lo marcado con 👁)": "Back to one-by-one mode (only what's marked with 👁)",
      "¿Mostrarle a este cliente su contrato, pagos y facturas en el portal?": "Show this client their contract, payments and invoices in the portal?",
      "Solo para proyectos donde tratas DIRECTO con el cliente. Si el trabajo va a través de un contratista (Wisdom u otro), déjalo apagado.":
        "Only for projects where you deal DIRECTLY with the client. If the work goes through a contractor (Wisdom or another), leave it off.",
      "💵 El cliente ahora VE su contrato y pagos": "💵 The client now SEES their contract and payments",
      "El dinero quedó oculto para el cliente": "Money is now hidden from the client",
      "Enlace del contratista copiado ✓ — ve todas sus obras": "Contractor link copied ✓ — it shows all their jobs",
      "El contratista no tiene email. Ponlo en Licencia y seguros ✎": "The contractor has no email. Add it in License and insurance ✎",
      "Esta obra la paga el dueño: el contratista no factura ni firma aquí": "The homeowner pays for this job: the contractor doesn't invoice or sign here",
      "¿Cómo mandaste el Notice to Owner? (certificado, servicio, en mano…)": "How did you send the Notice to Owner? (certified mail, process server, by hand…)",
      "Notice to Owner anotado ✓": "Notice to Owner logged ✓",
      "Dos cosas cambian:": "Two things change:",
      "En su portal verán los hitos, lo facturado y lo cobrado de esta obra.": "In their portal they'll see this job's milestones, what's invoiced and what's collected.",
      "El contrato saldrá SIN el aviso de la ley de gravámenes y SIN los tres días para cancelar (esos dos son solo para un dueño de casa).":
        "The contract will go out WITHOUT the lien law notice and WITHOUT the three-day right to cancel (those two are only for a homeowner).",
      "Si quien firma es el dueño de la casa, elige «Solo coordinan».": "If the homeowner is the one signing, choose «Coordination only».",
      "Contratista guardado ✓": "Contractor saved ✓", "Obra directa ✓": "Direct job ✓",
      "¿Regenerar la llave? El link viejo dejará de funcionar y tendrás que mandarle el nuevo al cliente.":
        "Regenerate the key? The old link will stop working and you'll have to send the new one to the client.",
      "Llave nueva ✓ — copia el link otra vez": "New key ✓ — copy the link again",
      // Documentos: enseñar, firma, aprobación, contrafirma
      "👁 El cliente ahora VE este documento — OJO: en Drive debe estar compartido como 'cualquiera con el enlace' para que pueda abrirlo":
        "👁 The client now SEES this document — HEADS UP: in Drive it must be shared as 'anyone with the link' so they can open it",
      "🚫 Documento oculto para el cliente": "🚫 Document hidden from the client",
      "Petición de firma quitada": "Signature request removed",
      "Tu firma saldrá en el certificado junto a la del cliente. ¿Firmar?": "Your signature will appear on the certificate next to the client's. Sign?",
      "✒️ Contrafirmado — tu firma saldrá en el certificado": "✒️ Countersigned — your signature will appear on the certificate",
      "✍️ El cliente verá el botón de aprobar": "✍️ The client will see the approve button",
      "Aprobación quitada": "Approval removed",
      "Ponle el archivo PDF o pega el enlace de Drive.": "Attach the PDF file or paste the Drive link.",
      "Ese PDF pasa de 20 MB — comprímelo o usa el enlace de Drive.": "That PDF is over 20 MB — compress it or use the Drive link.",
      "RFI guardado ✓": "RFI saved ✓", "Documento guardado ✓": "Document saved ✓",
      // Facturas, hitos y QuickBooks
      "Es dinero personal: solo se marca pagada, no se suma a lo cobrado de la obra.": "It's personal money: it's only marked paid, not added to the job's collected amount.",
      "✓ Factura marcada cobrada": "✓ Invoice marked paid",
      "QB directo aún no conectado — texto copiado ✓, pégalo en la factura": "Direct QB not connected yet — text copied ✓, paste it into the invoice",
      "Cópialo y pégalo en QuickBooks:": "Copy it and paste it into QuickBooks:",
      "Este proyecto no tiene email de cobro. ¿Crear la factura en QuickBooks SIN mandarla? (después la mandas desde QuickBooks)":
        "This project has no billing email. Create the invoice in QuickBooks WITHOUT sending it? (you can send it later from QuickBooks)",
      "QuickBooks no encontró el cliente de esta obra: créalo primero en QuickBooks y vuelve a tocar Facturar.":
        "QuickBooks didn't find this job's client: create it first in QuickBooks and tap Invoice again.",
      "¿Cuál de estos clientes de QuickBooks es el de esta obra?": "Which of these QuickBooks customers is this job's client?",
      "💵 Hito marcado cobrado ✓": "💵 Milestone marked collected ✓",
      // Arranque y trabajo externo
      "Gestión hecha ✓": "Task done ✓",
      "Trabajo externo anotado ✓ — ya cuenta como gasto del proyecto": "Outside work logged ✓ — it now counts as a project expense",
      "¿Por qué se anula este trabajo externo? — no se borra: su costo pasa a 0 y queda el rastro":
        "Why is this outside work being voided? — it isn't deleted: its cost goes to 0 and the record stays",
      "Hace falta decir por qué.": "You need to say why.",
      "Trabajo externo anulado ✓ — ya no cuenta como gasto": "Outside work voided ✓ — it no longer counts as an expense",
      // Completar
      "Sale de las obras en ejecución. Si fue sin querer, se reabre desde el estado.": "It leaves the jobs in progress. If it was a mistake, reopen it from the status.",
      // Las ventanas de la app (confirmar, pedir un dato, alertar)
      "Aceptar": "OK", "Entendido": "Got it", "Respuesta": "Answer",
      // Proyecto nuevo
      "El monto del contrato no es un número válido — revísalo.": "The contract amount isn't a valid number — check it.",
      "Proyecto creado ✓ — ahora toca «Escribir el alcance»": "Project created ✓ — next up: «Write the scope»",
      "Proyecto creado ✓": "Project created ✓",
      // Los textos que la app guarda por defecto en un proyecto nuevo (salen tal cual en la ficha)
      "Por confirmar": "To be confirmed", "Por definir": "To be defined",
      "Proyecto creado desde el panel": "Project created from the panel",
      "Definir la próxima acción.": "Set the next action."
    });
    REGLAS.push(
      // «No se pudo…: <error>» — el error (de enCristiano) se traduce si está en el diccionario
      [/^(No se pudo|No se pudo cambiar|No se pudo guardar|No se pudo subir|No se pudo anotar|No se pudo anular|No se pudo crear|No salió el aviso|QuickBooks dijo): ([\s\S]+)$/, s => {
        const m = s.match(/^(No se pudo|No se pudo cambiar|No se pudo guardar|No se pudo subir|No se pudo anotar|No se pudo anular|No se pudo crear|No salió el aviso|QuickBooks dijo): ([\s\S]+)$/);
        const pre = { "No se pudo": "That didn't work", "No se pudo cambiar": "Could not change it", "No se pudo guardar": "Could not save",
          "No se pudo subir": "Could not upload", "No se pudo anotar": "Could not log it", "No se pudo anular": "Could not void it",
          "No se pudo crear": "Could not create it", "No salió el aviso": "The notification didn't go out", "QuickBooks dijo": "QuickBooks said" }[m[1]];
        return pre + ": " + (D[m[2]] !== undefined ? D[m[2]] : m[2]);
      }],
      [/^No se pudo bajar la copia de la obra, así que no se borró nada: ([\s\S]+)$/, s => {
        const e = s.replace(/^No se pudo bajar la copia de la obra, así que no se borró nada: /, "");
        return "Couldn't download the job's copy, so nothing was deleted: " + (D[e] !== undefined ? D[e] : e);
      }],
      // La cabecera de la ficha: «Proyectos Residenciales · En ejecución»
      [/^(Proyectos Comerciales|Proyectos Residenciales|Servicios) · (.+)$/, s => s.split(" · ").map(x => D[x] !== undefined ? D[x] : x).join(" · ")],
      // Detalle de una inspección: «17 Sep 2026 · Permiso ELE2026-01234 · City of Tampa · notas»
      [/^((?:\d{1,2} [A-Za-z]{3} \d{4} · )?)Permiso (\S*\d\S*)((?: · .*)?)$/, "$1Permit $2$3"],
      // Facturas y hitos
      [/^¿Se cobró la factura #(\S+) \((.+)\)\?$/, "Was invoice #$1 ($2) paid?"],
      [/^¿Ya entró el dinero de "(.+)" \((.+)\)\?$/, "Did the money for \"$1\" ($2) come in?"],
      [/^¿Crear esta factura en QuickBooks y MANDARLA ahora a (.+)\?$/, "Create this invoice in QuickBooks and SEND it now to $1?"],
      [/^Cliente (\d+)$/, "Customer $1"],
      [/^Factura (#\S+ )?creada y mandada a (.+) ✓$/, "Invoice $1created and sent to $2 ✓"],
      [/^Factura (#\S+ )?creada en QuickBooks ✓ — sin mandar: mándala desde la app de QuickBooks o la computadora$/,
        "Invoice $1created in QuickBooks ✓ — not sent: send it from the QuickBooks app or the computer"],
      [/^Factura (#\S+ )?creada en QuickBooks ✓ \(sin mandar\)$/, "Invoice $1created in QuickBooks ✓ (not sent)"],
      [/^Inspección pasada ✓ — recuerda facturar: (\S+) \((.+)\)$/, "Inspection passed ✓ — remember to invoice: $1 ($2)"],
      // Eliminar la obra
      [/^Vas a ELIMINAR "(.+)" para siempre\.$/, "You are about to DELETE \"$1\" forever."],
      [/^Se bajó la copia "(copia-[^"]+\.json)"\. ¿Borrar ya "(.+)"\?$/, "The copy \"$1\" was downloaded. Delete \"$2\" now?"],
      [/^"(.+)" eliminado\.$/, "\"$1\" deleted."],
      [/^"(.+)" marcada Completado ✓$/, "\"$1\" marked Completed ✓"],
      [/^¿Marcar «(.+)» como COMPLETADA\?$/, "Mark «$1» as COMPLETED?"],
      // Portal del cliente y del contratista
      [/^Copiado ✓ — ojo: es la llave de (.+)\. Quien la tenga entra también a sus otras obras, así que mándasela solo a ellos\.$/, s => {
        const n = s.match(/^Copiado ✓ — ojo: es la llave de (.+)\. Quien/)[1];
        return `Copied ✓ — careful: it's ${n === "la empresa" ? "the company" : n}'s key. Whoever has it can also get into their other jobs, so send it only to them.`;
      }],
      [/^Aviso enviado a (.+) ✓$/, "Notification sent to $1 ✓"],
      [/^Vas a decir que el contrato de esta obra es con (.+)\.$/, s => {
        const n = s.match(/^Vas a decir que el contrato de esta obra es con (.+)\.$/)[1];
        return `You're saying this job's contract is with ${n === "esa empresa" ? "that company" : n}.`;
      }],
      [/^El cliente verá 'Revisar y firmar' en su portal(?: \(vale hasta (\S+)\))?$/, s => {
        const f = (s.match(/\(vale hasta (\S+)\)$/) || [])[1];
        return "The client will see 'Review and sign' in their portal" + (f ? ` (valid until ${f})` : "");
      }],
      [/^Vale hasta (\d{4}-\d{2}-\d{2}) ✓$/, "Valid until $1 ✓"],
      [/^Vas a firmar "(.+)" como:$/, "You are about to sign \"$1\" as:"],
      // Inspecciones
      [/^¿Eliminar la inspección (.+)\?$/, s => {
        const t = s.slice("¿Eliminar la inspección ".length, -1);
        return `Delete the ${D[t] !== undefined ? D[t] : t} inspection?`;
      }],
      // Fotos y archivos
      [/^Subiendo (\d+) de (\d+)…$/, "Uploading $1 of $2…"],
      [/^Subiendo (\d+) fotos…$/, "Uploading $1 photos…"],
      [/^Sin señal — (\d+) fotos quedaron guardadas en el teléfono y se suben solas cuando vuelva la señal\.$/,
        "No signal — $1 photos were saved on the phone and upload by themselves when the signal comes back."],
      [/^(\d+) archivos subidos ✓$/, "$1 files uploaded ✓"],
      [/^(\d+) de (\d+) subidos ✓ — los demás se quedaron, inténtalo otra vez\.$/, "$1 of $2 uploaded ✓ — the rest didn't go through, try again."],
      [/^(\d+) (?:foto no cargó|fotos no cargaron) — vuelve a entrar al proyecto en un momento\.$/, s => {
        const n = parseInt(s, 10);
        return `${n} ${n === 1 ? "photo didn't" : "photos didn't"} load — open the project again in a moment.`;
      }],
      [/^(?:(\d+) fotos subidas|Foto subida) a (.+) ✓$/, s => {
        const m = s.match(/^(?:(\d+) fotos subidas|Foto subida) a (.+) ✓$/);
        return (m[1] ? `${m[1]} photos uploaded` : "Photo uploaded") + ` to ${m[2]} ✓`;
      }]
    );
  // · parte-D
  // ---------- Parte D · app.js 6631–8842: horas, cola sin señal, materiales y recibos, control de gastos, arranque del estimador ----------
  Object.assign(D, {
    // Mis horas: la flechita de Change Order y el ✎ de cada reporte
    "Contrato base (sin SOW subido aún)": "Base contract (no SOW uploaded yet)",
    "Otro (escribirlo)": "Other (type it in)",
    "Corregir o eliminar": "Edit or delete",
    "Change Order (opcional — vacío = contrato normal)": "Change order (optional — blank = regular contract)",
    "Ej: CO #1": "E.g.: CO #1",
    // Fases guardadas en los reportes (el valor viejo que se vuelve a enseñar)
    "Movilización": "Mobilization", "Demolición": "Demolition",
    "Panel / Servicio": "Panel / Service", "Inspección / Correcciones": "Inspection / Corrections",
    // Avisos de horas
    "⏳ Ya le pediste permiso a Edgar — te avisamos al teléfono cuando apruebe":
      "⏳ You already asked Edgar for permission — we'll notify your phone when he approves",
    "Para corregir este reporte necesitas el permiso de Edgar. ¿Se lo pedimos ahora?":
      "To edit this report you need Edgar's permission. Should we ask him now?",
    "Permiso pedido ✓ — a Edgar le llegó el aviso al teléfono": "Permission requested ✓ — Edgar got the alert on his phone",
    "Reporte corregido ✓": "Report corrected ✓",
    "¿Eliminar este reporte de horas?": "Delete this hours report?",
    "Úsalo solo si se reportó por error.": "Use it only if it was reported by mistake.",
    "Reporte eliminado ✓": "Report deleted ✓",
    "¿De cuál Change Order fue el trabajo? (Ej: CO #2)": "Which change order was the work for? (E.g.: CO #2)",
    "Horas y pendiente guardados ✓ (el pendiente queda en rojo)": "Hours and open item saved ✓ (the open item stays red)",
    "Horas guardadas ✓": "Hours saved ✓",
    "📶 Sin señal — tu reporte quedó guardado en el teléfono y se manda solo cuando vuelva la señal.":
      "📶 No signal — your report was saved on the phone and sends itself when the signal comes back.",
    "Ese reporte ya estaba guardado ✓": "That report was already saved ✓",
    "Se mandó el reporte que estaba esperando señal ✓": "Sent the report that was waiting for signal ✓",
    // La cola general sin señal
    "📶 Sin señal — quedó guardado en el teléfono y se manda solo cuando vuelva la señal.":
      "📶 No signal — it was saved on the phone and sends itself when the signal comes back.",
    "Se mandó 1 cosa que estaba esperando señal ✓": "Sent 1 item that was waiting for signal ✓",
  
    // Materiales
    "General (no es de un proyecto)": "General (not for a project)",
    "Modificar o eliminar": "Edit or delete",
    "Material (corrige el nombre si te equivocaste)": "Material (fix the name if you got it wrong)",
    "Proyecto (cámbialo si era de otro)": "Project (change it if it belonged to another one)",
    "Precio pagado ($) — para el control de gastos": "Price paid ($) — for expense control",
    "Ej: 45.99": "E.g.: 45.99",
    "📤 Enviar al supply": "📤 Send to the supply house",
    "Ej: rentar la zanjadora": "E.g.: rent the trencher",
    "Compra": "Purchase", "🛒 Compra": "🛒 Purchase",
    "Devolución (resta del gasto)": "Return (subtracts from the expense)",
    "↩ Devolución (resta del gasto)": "↩ Return (subtracts from the expense)",
    "Ej: Home Depot, CES, Ferguson…": "E.g.: Home Depot, CES, Ferguson…",
    "Ej: 3 rollos 12/2, caja de breakers, 10 straps": "E.g.: 3 rolls of 12/2, box of breakers, 10 straps",
    "Ej: 128.40": "E.g.: 128.40",
    "¿Es de un Change Order? (opcional)": "Is it for a change order? (optional)",
    "Tipo de ticket": "Ticket type",
    "Total ($) — o déjalo vacío y la rutina lo lee de la foto": "Total ($) — or leave it blank and the routine reads it from the photo",
    "Ej: 342.18": "E.g.: 342.18", "Ej: Home Depot": "E.g.: Home Depot",
    "Ej: compra del rough": "E.g.: rough-in purchase",
    "Ponles la foto del recibo con 📷 o el proyecto con 📌.": "Add the receipt photo with 📷 or the project with 📌.",
    "Ponles la foto del recibo con": "Add the receipt photo with", "o el proyecto con": "or the project with",
    "Últimas compras": "Latest purchases",
    "Lista rápida — varios de un golpe": "Quick list — several at once",
    "📝 Lista rápida — varios de un golpe": "📝 Quick list — several at once",
    "Mejor de uno en uno": "One at a time instead", "✏ Mejor de uno en uno": "✏ One at a time instead",
    "Ej: cable 14/2": "E.g.: 14/2 cable", "Ej: 2 rollos": "E.g.: 2 rolls",
    "Proyecto (para toda la lista)": "Project (for the whole list)",
    "Un material por línea — la cantidad va al final, después de una coma":
      "One material per line — the quantity goes at the end, after a comma",
    "Importar nota (.txt)": "Import note (.txt)",
    "Agregar toda la lista": "Add the whole list",
    // Recibos: estados, botones y títulos
    "FALTA FOTO 📷": "NO PHOTO 📷", "FALTA FOTO": "NO PHOTO", "ANULADO": "VOIDED",
    "↩ DEVOLUCIÓN": "↩ RETURN", "DEVOLUCIÓN": "RETURN",
    "Recibo": "Receipt", "⚠ Sin proyecto": "⚠ No project", "Sin proyecto": "No project",
    "Asignarle proyecto a esta compra": "Assign a project to this purchase",
    "Corregir total, proveedor o descripción": "Edit total, vendor or description",
    "Cambiar la foto del recibo": "Change the receipt photo",
    "Ponerle la foto del recibo": "Add the receipt photo",
    "Volver a contarlo (dice por qué)": "Count it again (say why)",
    "Volver a contar": "Count again",
    "Anular (dice por qué): no se borra, sale de las cuentas": "Void (say why): it isn't deleted, it's taken out of the totals",
    "Anular": "Void",
    "Subiendo…": "Uploading…",
    // Avisos y preguntas de materiales y recibos
    "Material agregado ✓": "Material added ✓",
    "Nota importada ✓ — revísala, elige el proyecto y dale a Agregar": "Note imported ✓ — review it, pick the project and tap Add",
    "Lista copiada ✓ — pégala en el texto o correo al supply": "List copied ✓ — paste it into the text or email to the supply house",
    "¿Cuánto costó? (solo el número, ej: 45.99)": "How much did it cost? (just the number, e.g.: 45.99)",
    "Déjalo vacío si no quieres anotar el precio ahora — lo puedes poner después con el ✎.":
      "Leave it blank if you don't want to enter the price now — you can add it later with ✎.",
    "Ese precio no se entendió — solo el número, ej: 45.99": "Couldn't read that price — just the number, e.g.: 45.99",
    "Marcado como comprado ✓": "Marked as purchased ✓",
    "Material corregido ✓": "Material corrected ✓",
    "¿Eliminar este material de la lista?": "Delete this material from the list?",
    "Úsalo si se anotó por error o su trabajo ya no existe.": "Use it if it was added by mistake or its job no longer exists.",
    "Material eliminado ✓": "Material deleted ✓",
    "Pasado a la lista de compras ✓ (el pendiente sigue rojo hasta resolverse en obra)":
      "Moved to the shopping list ✓ (the open item stays red until it's resolved on site)",
    "Gestión anotada ✓": "Task added ✓", "Gestión hecha ✓": "Task done ✓",
    "¿Eliminar esta gestión?": "Delete this task?", "Gestión eliminada ✓": "Task deleted ✓",
    "Compra registrada ✓ — Edgar le pone el total con el ✎": "Purchase logged ✓ — Edgar adds the total with ✎",
    "Recibo subido ✓ — la rutina le pondrá el total al leerlo (12pm/6pm)":
      "Receipt uploaded ✓ — the routine will add the total when it reads it (12pm/6pm)",
    "Total del recibo (solo el número, ej: 342.18).": "Receipt total (just the number, e.g.: 342.18).",
    "DEVOLUCIÓN va con signo menos (ej: -45.99).": "A RETURN goes with a minus sign (e.g.: -45.99).",
    "Déjalo igual para no cambiarlo:": "Leave it as is to keep it:",
    "¿Dónde se compró? (proveedor):": "Where was it bought? (vendor):",
    "Descripción (qué se compró / nota):": "Description (what was bought / note):",
    "Ese total no se entendió — no se cambió nada": "Couldn't read that total — nothing was changed",
    "Recibo corregido ✓": "Receipt corrected ✓",
    "Foto del recibo guardada ✓": "Receipt photo saved ✓",
    "No hay proyectos activos para asignar.": "There are no active projects to assign.",
    "¿A qué proyecto va esta compra?": "Which project is this purchase for?",
    "Escribe el número:": "Type the number:",
    "Número inválido.": "Invalid number.",
    "Hace falta decir por qué.": "You need to say why.",
    "¿Por qué se anula este recibo? (repetido, devuelto, no era de la empresa…) — no se borra: queda como rastro y deja de sumar":
      "Why is this receipt being voided? (duplicate, returned, not a company purchase…) — it isn't deleted: it stays on record and stops counting",
    "Recibo anulado ✓ — ya no suma": "Receipt voided ✓ — it no longer counts",
    "¿Por qué vuelve a contar este recibo?": "Why does this receipt count again?",
    "Recibo de vuelta ✓ — vuelve a sumar": "Receipt restored ✓ — it counts again",
    "No se pudieron cargar las fotos de los recibos — revisa la señal.": "Couldn't load the receipt photos — check your signal.",
  
    // Control de gastos
    "sin horas estimadas para comparar": "no estimated hours to compare",
    "sin horas registradas": "no hours logged",
    "sin horas registradas · define 💲 Costos del equipo": "no hours logged · set up 💲 Team costs",
    "sin presupuesto de materiales — ponlo aquí abajo": "no materials budget — enter it below",
    "Ej: 2500": "E.g.: 2500", "Ej: 35": "E.g.: 35", "Ej: Pedro": "E.g.: Pedro", "Ej: 50": "E.g.: 50",
    "Campo": "Field crew",
    "(toca para abrir — solo se ajusta cuando cambia un salario)": "(tap to open — only changes when a wage changes)",
    "El costo completo por hora para la empresa (salario + taxes + seguro). Con esto cada proyecto calcula su rentabilidad solo.":
      "The full hourly cost to the company (wage + taxes + insurance). With this, each project works out its own profitability.",
    "Ayudantes externos": "Outside helpers", "🧰 Ayudantes externos": "🧰 Outside helpers",
    "(gente puntual con tarifa — sin cuenta en la app, solo tú los ves)": "(occasional people with a rate — no app account, only you see them)",
    "sin trabajos anotados todavía": "no work logged yet",
    "Cambiar tarifa": "Change rate", "Inactivo": "Deactivate",
    "Sin ayudantes todavía — agrega el primero aquí abajo.": "No helpers yet — add the first one below.",
    "Nombre del ayudante": "Helper name", "Tarifa por hora ($)": "Hourly rate ($)",
    "Luego le anotas sus horas en cada proyecto (ficha → Ayuda externa): eliges su nombre, pones las horas y el costo se calcula solo con esta tarifa.":
      "Then you log their hours on each project (job file → Outside help): pick their name, enter the hours and the cost is worked out with this rate.",
    "Agregar ayudante": "Add helper", "+ Agregar ayudante": "+ Add helper",
    "(marcar inactivo al que se va — su historia queda)": "(mark whoever leaves as inactive — their history stays)",
    "Para": "To", "agregar": "add",
    "un trabajador nuevo con acceso a la app, pídeselo a Claude — te da los 3 pasos del panel de Supabase (2 minutos). Si es alguien puntual sin acceso, usa \"Ayuda externa\" en el proyecto o la nómina de":
      "a new worker with app access, ask Claude — it gives you the 3 steps in the Supabase panel (2 minutes). If it's an occasional helper without access, use \"Outside help\" on the project or the list of",
    "aquí arriba.": "up here.",
    "Costos guardados ✓ — la rentabilidad ya usa los números nuevos": "Costs saved ✓ — profitability now uses the new numbers",
    "¿Marcar a esta persona como inactiva?": "Mark this person as inactive?",
    "Desaparece de las listas y semáforos, pero sus horas e historia quedan intactas. Se puede reactivar cuando quieras.":
      "They disappear from the lists and status lights, but their hours and history stay intact. You can reactivate them anytime.",
    "Reactivado ✓": "Reactivated ✓", "Marcado como inactivo ✓ (su historia queda)": "Marked as inactive ✓ (their history stays)",
    "Ayudante agregado ✓ — ya puedes anotarle horas en cualquier proyecto": "Helper added ✓ — you can now log their hours on any project",
    "Esa tarifa no se entendió": "Couldn't read that rate",
    "Tarifa actualizada ✓ (los trabajos ya anotados no cambian)": "Rate updated ✓ (work already logged doesn't change)",
    "Ayudante inactivo ✓ (su historia queda)": "Helper deactivated ✓ (their history stays)",
    "Ayudante reactivado ✓": "Helper reactivated ✓",
    "Ese monto no se entendió": "Couldn't read that amount",
    "Presupuesto guardado ✓": "Budget saved ✓",
  
    // El estimador: arranque
    "Cargando el estimador…": "Loading the estimator…",
    "No se pudo cargar el estimador — revisa la señal.": "Couldn't load the estimator — check your signal.",
    "Reintentar": "Retry",
    "Max Power (mío)": "Max Power (mine)", "MXP MEP — con Roger": "MXP MEP — with Roger",
    // Desglose de los beneficios (labor burden)
    "FICA (Social Security 6,2 % + Medicare 1,45 %)": "FICA (Social Security 6.2% + Medicare 1.45%)",
    "FUTA federal (sobre los primeros $7.000)": "Federal FUTA (on the first $7,000)",
    "Paro de Florida (sobre los primeros $7.000)": "Florida reemployment tax (on the first $7,000)",
    "Workers comp — eléctrico, código 5190": "Workers comp — electrical, code 5190",
    "Responsabilidad civil (GL)": "General liability (GL)",
    "Vacaciones y feriados": "Vacation and holidays",
    "Seguro médico": "Health insurance",
    "Herramienta, uniformes, formación": "Tools, uniforms, training",
    // Por qué un renglón vale $0 (chip, motivo y selector)
    "POR COTIZAR": "TO BE QUOTED", "COTIZADO": "QUOTED", "SOLO LABOR": "LABOR ONLY", "TARIFA": "RATE",
    "FALTA PRECIO": "NO PRICE", "¿QUIÉN LO PONE?": "WHO SUPPLIES IT?", "SIN CATÁLOGO": "NOT IN CATALOG",
    "REFERENCIA": "REFERENCE", "¿$0?": "$0?",
    "material por cotizar": "material to be quoted",
    "la cotización ya está en el precio": "the quote is already in the price",
    "material del cliente": "client's material",
    "no lleva material": "no material",
    "la tecleas por trabajo": "you type it in per job",
    "sin precio en el catálogo": "no price in the catalog",
    "nadie ha dicho por qué va en cero": "nobody has said why it's zero",
    "este nombre no está en el catálogo": "this name isn't in the catalog",
    "precio de referencia TUYO: la cuota del supply sigue pendiente": "YOUR reference price: the supply house quote is still pending",
    "revísalo": "check it",
    "¿por qué $0?": "why $0?",
    "Lo cotiza el supply house": "The supply house quotes it",
    "Lo pone el cliente": "The client supplies it",
    "Solo mano de obra": "Labor only",
    "Falta el precio — lo pongo ahora": "Price missing — I'll enter it now",
    "Es una tarifa que tecleo por trabajo": "It's a rate I type in per job",
    "Ya lo cotizé: toda esta sección está en el precio": "Already quoted: this whole section is in the price",
    // Cómo va sujeto el tubo
    "Pared o losa — one-hole strap + tapcon": "Wall or slab — one-hole strap + tapcon",
    "Power strap (dos tornillos)": "Power strap (two screws)",
    "Metal deck / estructura — tornillo autorroscante": "Metal deck / structure — self-drilling screw",
    "Unistrut / trapecio colgado": "Unistrut / hung trapeze",
    "Ceiling tile — colgador de T-bar": "Ceiling tile — T-bar hanger",
    // Las reglas de consumibles automáticos
    "Acoples": "Couplings", "Conectores": "Connectors", "Cajas de paso": "Pull boxes", "Tapas ciegas": "Blank covers",
    "Tornillo a metal": "Metal screws", "Colgador de T-bar": "T-bar hangers",
    "Unistrut (pies)": "Unistrut (ft)", "All-thread 1/4 (pies)": "1/4 all-thread (ft)",
    "Tuercas 1/4": "1/4 nuts", "Arandelas 1/4": "1/4 washers", "Anclas 1/4": "1/4 anchors",
    "Grasa de alambrar": "Wire-pulling lube", "Libreta de números": "Wire marker book",
    // Horas de proyecto propuestas
    "el trato es con un contratista: si el permiso lo saca el GC, NO lo marques (regla de la casa)":
      "the deal is with a contractor: if the GC pulls the permit, DON'T check it (house rule)",
    "por proyecto — ponlo tú": "per project — you enter it",
    "No encuentro breakers en el estimado: las horas de terminar y rotular circuitos salen en 0 — pon tú el número de circuitos.":
      "I can't find breakers in the estimate: the hours to terminate and label circuits come out as 0 — enter the number of circuits yourself.",
    // Familias de luminarias
    "Cleanroom / sellada": "Cleanroom / sealed", "Unidad de emergencia": "Emergency unit",
    "Downlight / recessed redondo": "Downlight / round recessed", "Strip / wrap / lineal": "Strip / wrap / linear",
    "Precio tuyo": "Your price"
  });
  
  REGLAS.push(
    // La flechita de Change Order del reporte de horas
    [/^📄 Contrato — (.+)$/, "📄 Contract — $1"],
    // Historial de horas: «fecha · fase · notas» — solo se traduce la fase; las notas son de la gente
    [/^(\d{4}-\d{2}-\d{2}) · (Movilización|Demolición|Panel \/ Servicio|Inspección \/ Correcciones)( · [\s\S]*)?$/, s => {
      const m = s.match(/^(\d{4}-\d{2}-\d{2}) · (Movilización|Demolición|Panel \/ Servicio|Inspección \/ Correcciones)( · [\s\S]*)?$/);
      const F = { "Movilización": "Mobilization", "Demolición": "Demolition", "Panel / Servicio": "Panel / Service", "Inspección / Correcciones": "Inspection / Corrections" };
      return m[1] + " · " + F[m[2]] + (m[3] || "");
    }],
    // Lo que esperaba señal
    [/^Se mandaron (\d+) reportes que estaban esperando señal ✓$/, "Sent $1 reports that were waiting for signal ✓"],
    [/^Se mandaron (\d+) cosas que estaban esperando señal ✓$/, "Sent $1 items that were waiting for signal ✓"],
    // Materiales y recibos
    [/^(\d+) materiales agregados ✓$/, s => { const n = parseInt(s, 10); return n + (n === 1 ? " material added ✓" : " materials added ✓"); }],
    [/^Comprado ✓ — (\S+) anotado al proyecto$/, "Purchased ✓ — $1 added to the project"],
    [/^Compra registrada ✓ — (\S+) anotado al proyecto$/, "Purchase logged ✓ — $1 added to the project"],
    [/^Recibo subido ✓ — (\S+) anotado al proyecto$/, "Receipt uploaded ✓ — $1 added to the project"],
    [/^Compra asignada a (.+) ✓$/, "Purchase assigned to $1 ✓"],
    [/^Por completar \((\d+)\) — compras dictadas por voz$/, "To complete ($1) — purchases dictated by voice"],
    // Renglón del recibo sin obra: «⚠ Sin proyecto · Jian 2026-08-19» (el nombre y la fecha se quedan)
    [/^(⚠ ?)?Sin proyecto · (.+)$/, s => s.replace(/Sin proyecto · /, "No project · ")],
    [/^Ej: ([\d.,]+)$/, "E.g.: $1"],
    // Control de gastos
    [/^Mano de obra \(([\d.,]+) h\)$/, "Labor ($1 h)"],
    [/^(.+) — costo por hora \(\$\)$/, "$1 — cost per hour ($)"],
    [/^lleva (\$[\d,.]+|\$•••|\S+) pagado en proyectos$/, "$1 paid on projects so far"],
    [/^(Campo|License Holder|sin trabajos anotados todavía|lleva (\S+) pagado en proyectos) · INACTIVO$/, s => {
      const p = s.slice(0, -" · INACTIVO".length);
      const m = p.match(/^lleva (\S+) pagado en proyectos$/);
      const t = m ? m[1] + " paid on projects so far" : (D[p] !== undefined ? D[p] : p);
      return t + " · INACTIVE";
    }],
    [/^Tarifa por hora de (.+) \(\$\):$/, "Hourly rate for $1 ($):"],
    // Estimador
    [/^MXP MEP — con Roger \((\d+)\)$/, "MXP MEP — with Roger ($1)"],
    // Chip del $0 sin confirmar («?») y el de referencia con su precio
    [/^(POR COTIZAR|COTIZADO|BY OWNER|SOLO LABOR|TARIFA|FALTA PRECIO|¿QUIÉN LO PONE\?|SIN CATÁLOGO) \?$/, s => {
      const k = s.slice(0, -2); return (D[k] !== undefined ? D[k] : k) + " ?";
    }],
    [/^REFERENCIA (\$[\d,.]+|\$•••)$/, "REFERENCE $1"],
    // Familia de luminaria con su precio o su marca: «Cleanroom / sellada · $550», «… ✎», «… · $0»
    [/^(Cleanroom \/ sellada|Unidad de emergencia|Downlight \/ recessed redondo|Strip \/ wrap \/ lineal)( [✎·].*)$/, s => {
      const m = s.match(/^(Cleanroom \/ sellada|Unidad de emergencia|Downlight \/ recessed redondo|Strip \/ wrap \/ lineal)( [✎·].*)$/);
      return D[m[1]] + m[2];
    }],
    // Aviso de una regla de consumibles que no encontró su pieza
    [/^(.+): no encuentro «(.+?)» en el catálogo — esa regla no corrió(\. Lo más parecido es «(.+)», que NO es lo que pide esta regla: o das de alta la pieza buena, o cambia arriba cómo va sujeto el tubo)?$/, s => {
      const m = s.match(/^(.+): no encuentro «(.+?)» en el catálogo — esa regla no corrió(\. Lo más parecido es «(.+)», que NO es lo que pide esta regla: o das de alta la pieza buena, o cambia arriba cómo va sujeto el tubo)?$/);
      const nom = D[m[1]] !== undefined ? D[m[1]] : m[1];
      return nom + ": I can't find «" + m[2] + "» in the catalog — that rule didn't run"
        + (m[3] ? ". The closest is «" + m[4] + "», which is NOT what this rule asks for: either add the right part, or change above how the conduit is supported" : "");
    }],
    [/^«(.+)» no está en el catálogo — corre docs\/sql\/e27\.sql$/, "«$1» isn't in the catalog — run docs/sql/e27.sql"],
    // De dónde sale cada hora propuesta (solas o con «· 0.5 h cada uno» detrás)
    [/^(\d+) breaker\(s\) LISTADOS en el estimado — si el trabajo tiene más circuitos que breakers comprados, cámbialo( · [\d.]+ h cada uno)?$/, s => s
      .replace(/ breaker\(s\) LISTADOS en el estimado — si el trabajo tiene más circuitos que breakers comprados, cámbialo/, " breaker(s) LISTED in the estimate — if the job has more circuits than breakers purchased, change it")
      .replace(/ h cada uno$/, " h each")],
    [/^SUPUESTO: (\d+) dispositivo\(s\) \+ (\d+) luminaria\(s\) nuevas( · [\d.]+ h cada uno)?$/, s => s
      .replace(/^SUPUESTO: (\d+) dispositivo\(s\) \+ (\d+) luminaria\(s\) nuevas/, "ASSUMED: $1 new device(s) + $2 new fixture(s)")
      .replace(/ h cada uno$/, " h each")],
    [/^(\d+) dimmer\(s\) y sensor\(es\)( · [\d.]+ h cada uno)?$/, s => s
      .replace(/ dimmer\(s\) y sensor\(es\)/, " dimmer(s) and sensor(s)").replace(/ h cada uno$/, " h each")],
    [/^(el trato es con un contratista: si el permiso lo saca el GC, NO lo marques \(regla de la casa\)|por proyecto — ponlo tú) · ([\d.]+) h cada uno$/, s => {
      const i = s.lastIndexOf(" · "); const p = s.slice(0, i);
      return D[p] + s.slice(i).replace(/ h cada uno$/, " h each");
    }],
    // De qué regla salió un consumible automático: «regla: Acoples — 10 por 100 ft de 1/2"»,
    // también dentro del renglón «12 E · regla: … · ya venían 4 en las recetas · motivo»
    [/^(?:[\d.,]+ [^·]*· )?regla: .+? — [\d.,]+ por .+$/, s => s.split(" · ").map(seg => {
      let m = seg.match(/^regla: (.+?) — ([\d.,]+) por (.+)$/);
      if (m) {
        const nom = D[m[1]] !== undefined ? D[m[1]] : m[1];
        const por = m[3]
          .replace(/^100 ft de conductor$/, "100 ft of conductor")
          .replace(/^100 ft de (.+)$/, "100 ft of $1")
          .replace(/^caja( \(.+\))?$/, "box$1")
          .replace(/^trapecio, uno cada (\d+) ft$/, "trapeze, one every $1 ft")
          .replace(/^grapa$/, "strap");
        return "rule: " + nom + " — " + m[2] + " per " + por;
      }
      m = seg.match(/^ya venían ([\d.,]+) en las recetas$/);
      if (m) return m[1] + " already in the recipes";
      return D[seg] !== undefined ? D[seg] : seg;
    }).join(" · ")],
    // Los «No se pudo …: motivo» de esta parte (el motivo se traduce si está en el diccionario)
    [/^No se pudo (agregar|corregir|guardar|pasar|anotar|registrar|asignar|anular|subir el recibo|subir la foto|cargar el estimador): ([\s\S]+)$/, s => {
      const m = s.match(/^No se pudo (agregar|corregir|guardar|pasar|anotar|registrar|asignar|anular|subir el recibo|subir la foto|cargar el estimador): ([\s\S]+)$/);
      const V = { "agregar": "add", "corregir": "correct", "guardar": "save", "pasar": "move", "anotar": "log", "registrar": "log",
        "asignar": "assign", "anular": "void", "subir el recibo": "upload the receipt", "subir la foto": "upload the photo",
        "cargar el estimador": "load the estimator" };
      return "Couldn't " + V[m[1]] + ": " + (D[m[2]] !== undefined ? D[m[2]] : m[2]);
    }],
    [/^No se pudo: ([\s\S]+)$/, s => { const r = s.slice("No se pudo: ".length); return "Couldn't do it: " + (D[r] !== undefined ? D[r] : r); }]
  );
  // · parte-E
  // ---------- Parte E · app.js 8841–11151: cuotas y luminarias, fórmula, historial y benchmarks, importar precios, resultado, pagos (IA), datos y adjuntos del estimado, lista del estimador, auditoría del catálogo, aviso de renglones sin material, horas y material a mano, ⚡ rápido ----------
  // Lo que va al cliente (textoPropuesta, textoPropuestaMEP, textoResumenMEP, textoTakeoff) se pinta en <textarea>:
  // el motor no lo toca y aquí no se traduce.
  const trE = x => (D[x] !== undefined ? D[x] : x);
  Object.assign(D, {
    // Tipos de una línea a mano (select + chips)
    "Material tuyo": "Your material", "Cotización del proveedor": "Supplier quote",
    "Logística — viajes, hotel, per diem": "Logistics — travel, hotel, per diem",
    "Allowance — precio provisional": "Allowance — provisional price", "Subcontrato": "Subcontract",
    "COTIZACIÓN": "QUOTE", "LOGÍSTICA": "LOGISTICS", "SUBCONTRATO": "SUBCONTRACT",
    "¿Qué es esta línea? Cambia cómo paga en la fórmula": "What is this line? It changes how it's priced in the formula",
    // Resultado de un estimado (E11)
    "Ganado": "Won", "Perdido": "Lost", "Sin respuesta": "No response", "Descartado": "Dropped",
    "GANADO": "WON", "PERDIDO": "LOST", "SIN RESPUESTA": "NO RESPONSE", "DESCARTADO": "DROPPED",
    "Precio — había otro más barato": "Price — someone else was cheaper",
    "Plazo — no llegábamos a la fecha": "Schedule — we couldn't make the date",
    "Alcance — pedían algo que no hacemos": "Scope — they wanted something we don't do",
    "Relación — ya tenían electricista": "Relationship — they already had an electrician",
    "No calificamos — fianza, seguro, tamaño": "We didn't qualify — bond, insurance, size",
    "Otro": "Other",
    "Hasta 1.500 sqft": "Up to 1,500 sqft", "1.500 – 5.000 sqft": "1,500 – 5,000 sqft",
    "5.000 – 20.000 sqft": "5,000 – 20,000 sqft", "Más de 20.000 sqft": "Over 20,000 sqft",
    "Vas por encima de lo que sueles cobrar": "You're above what you usually charge",
    "Vas por debajo de lo que sueles cobrar": "You're below what you usually charge",
    "Este sale a": "This one comes out to", "de diferencia.": "difference.",
    "No tiene por qué estar mal: hay trabajos que valen el doble por buenas razones. Solo que lo veas antes de mandarlo.":
      "It's not necessarily wrong: some jobs are worth double for good reasons. Just take a look before you send it.",
    "¿Cómo acabó?": "How did it turn out?", "Pies cuadrados del trabajo": "Job square footage",
    "Ej: 2200": "E.g. 2200", "Sale a": "Comes out to", "(con el número que ofertaste).": "(with the number you bid).",
    "Sin esto no hay $/sqft, y sin $/sqft el historial no compara nada. Se puede poner ahora aunque el trabajo sea viejo.":
      "Without this there's no $/sqft, and without $/sqft the history can't compare anything. You can enter it now even if the job is old.",
    "todavía sin contestar": "no answer yet", "¿Por qué se perdió?": "Why was it lost?", "sin decir": "not stated",
    "¿Cuánto ofertó el que ganó?": "How much did the winner bid?",
    "Si se llega a saber. Es el dato que más calibra: dice de cuánto estabas lejos, no solo que perdiste.":
      "If you find out. It's the best calibration data: it tells you how far off you were, not just that you lost.",
    "p. ej. 20000": "e.g. 20000", "Nota": "Note", "lo que quieras recordar de este": "anything you want to remember about this one",
    "Guardado con": "Saved at",
    "Sin pies cuadrados": "No square footage", "Vuelve a estar sin contestar": "Back to no answer",
    // Pagos del contrato (la IA decide el reparto)
    "el de la propuesta que ya se armó": "the one from the proposal already built",
    "lo decidió la IA": "the AI decided it",
    "regla de respaldo: la IA todavía no lo decidió": "backup rule: the AI hasn't decided yet",
    "Lo decidió la IA.": "The AI decided it.",
    "Que la IA lo vuelva a decidir": "Have the AI decide again", "Que la IA decida el reparto": "Have the AI decide the split",
    "La IA está decidiendo…": "The AI is deciding…",
    "Tus reglas: el depósito cubre los materiales y nunca pasa del 50 %. A la IA no le llega ningún monto.":
      "Your rules: the deposit covers the materials and never goes over 50 %. The AI never sees any amount.",
    "La IA dio un reparto que no cumple tus reglas": "The AI gave a split that breaks your rules",
    "Pago único al completar": "Single payment on completion",
    "Al firmar / movilizar": "On signing / mobilization", "Al pasar inspección de rough": "On passing rough inspection",
    "Trim-out terminado (equipos y terminaciones)": "Trim-out complete (equipment and finishes)",
    "Según avance de la obra": "Per job progress", "Al pasar inspección final": "On passing final inspection",
    "Al completar y pasar inspección": "On completion and passed inspection", "Al terminar el trabajo": "When the work is finished",
    "Lo libera el contratante al cierre (final pay application)": "Released by the contractor at closeout (final pay application)",
    // Datos del trabajo
    "Datos del trabajo": "Job details",
    "Quién nos contrata (cliente / contratante)": "Who hires us (client / contractor)",
    "Dueño final de la obra": "Final owner of the job", "Dirección de la obra": "Job address",
    "p. ej. Integrated Systems, el GC": "e.g. Integrated Systems, the GC", "p. ej. Baptist Health": "e.g. Baptist Health",
    "p. ej. 91500 Overseas Hwy, Tavernier FL": "e.g. 91500 Overseas Hwy, Tavernier FL",
    "Retención del contratante (%)": "Contractor retainage (%)",
    "Lo que guarda de cada pago hasta el cierre. Vacío = sin retención.": "What they hold from each payment until closeout. Empty = no retainage.",
    "p. ej. 10": "e.g. 10",
    "Falta pegar docs/sql/e36-datos-del-trabajo.sql en Supabase: sin él no se guarda":
      "docs/sql/e36-datos-del-trabajo.sql still has to be pasted into Supabase: without it this isn't saved",
    "Contratante guardado ✓": "Contractor saved ✓", "Dueño guardado ✓": "Owner saved ✓", "Dirección guardada ✓": "Address saved ✓",
    "La retención va de 0 a 20 %": "Retainage goes from 0 to 20 %", "Sin retención ✓": "No retainage ✓",
    // Adjuntos del estimado
    "Documento": "Document", "enlace": "link", "Quitar": "Remove",
    "Sin adjuntos: el set de planos, las cuotas del supply, el estimado de Claude…": "No attachments: the plan set, supplier quotes, Claude's estimate…",
    "Qué es": "What it is", "p. ej. Cuota CED 23/09, Set de planos E-series": "e.g. CED quote 09/23, E-series plan set",
    "o enlace de Drive": "or Drive link", "Adjuntar": "Attach",
    "Al convertir en proyecto pasan solos a los documentos del proyecto.": "When it's converted to a project they move to the project's documents on their own.",
    "Falta pegar docs/sql/e36-datos-del-trabajo.sql en Supabase: sin él no se guardan los adjuntos":
      "docs/sql/e36-datos-del-trabajo.sql still has to be pasted into Supabase: without it attachments aren't saved",
    "No se pudo abrir": "Couldn't open it", "Adjunto quitado ✓": "Attachment removed ✓",
    "Elige el PDF o pega el enlace": "Pick the PDF or paste the link",
    "Ese PDF pasa de 20 MB — usa el enlace de Drive": "That PDF is over 20 MB — use the Drive link",
    "Subiendo…": "Uploading…", "Guardando…": "Saving…", "Adjuntado ✓": "Attached ✓",
    // Historial (E11)
    "no tienen guardado el número con que se ofertaron, así que salen": "don't have the number they were bid at saved, so they show",
    "recalculados con los precios de hoy": "recalculated with today's prices",
    ". Márcalos como ganado o perdido y se les guarda el suyo.": ". Mark them won or lost and their own number gets saved.",
    "Ninguno tiene pies cuadrados": "None has square footage",
    ", así que todavía no hay $/sqft que comparar — que es para lo que sirve esto. Ábrelos y ponlos en «¿Cómo acabó?»: vale aunque el trabajo sea de hace meses.":
      ", so there's no $/sqft to compare yet — which is what this is for. Open them and enter it in «How did it turn out?»: it works even if the job is months old.",
    "Ganados": "Won", "Perdidos": "Lost", "Sin contestar": "No answer", "todavía ninguno": "none yet",
    "ninguno con sqft": "none with sqft", "Tamaño": "Size", "ganas": "win rate",
    "Mediana, no media: un trabajo raro no debe mover la referencia. Donde pone «—» es que":
      "Median, not average: one odd job shouldn't move the reference. Where it shows «—»",
    "no hay tres con los que comparar": "there aren't three to compare against",
    "un porcentaje sacado de una oferta no dice nada.": "a percentage taken from a single bid tells you nothing.",
    // Precios del catálogo (E12)
    "Pega aquí el CSV del proveedor (Descripción y Precio; también vale Horas). Se casa contra tu catálogo y te enseño qué cambiaría":
      "Paste the supplier's CSV here (Description and Price; Hours works too). It's matched against your catalog and I'll show you what would change",
    "no se escribe nada hasta que lo apruebes": "nothing is written until you approve it",
    "¿Adónde van estos precios?": "Where do these prices go?",
    "A MIS precios — es lo que yo pago (cotiza con ellos)": "To MY prices — what I pay (quotes use them)",
    "Solo de referencia — RSMeans, NECA, una lista ajena": "Reference only — RSMeans, NECA, someone else's list",
    "¿De dónde salen?": "Where are they from?", "Ver qué cambiaría": "See what would change",
    "Ítem": "Item", "Tuyo": "Yours", "Referencia": "Reference", "Dif.": "Diff.", "Nuevo": "New",
    "La referencia es para comparar, nunca para cotizar: las bases compradas (RSMeans, NECA) son de uso interno y no salen en ninguna propuesta.":
      "The reference is for comparing, never for quoting: purchased databases (RSMeans, NECA) are for internal use and never go into a proposal.",
    "Ese archivo no trae filas: hace falta una cabecera y al menos una línea.": "That file has no rows: it needs a header and at least one line.",
    "No encuentro la columna del artículo. Debería llamarse Item, Descripción, Producto o parecido.":
      "I can't find the item column. It should be called Item, Description, Product or similar.",
    "No encuentro ni precio ni horas. Debería haber una columna Precio, Price, Cost… o Horas.":
      "I can't find a price or hours. There should be a Price, Cost… or Hours column.",
    "repetido en el CSV": "repeated in the CSV", "estaba a $0": "was at $0", "a propósito": "on purpose",
    "casó con tu catálogo": "matched your catalog", "casaron con tu catálogo": "matched your catalog",
    "cambia": "changes", "cambian": "change", "sin pareja": "unmatched",
    "estaba a $0 a propósito": "was at $0 on purpose", "estaban a $0 a propósito": "were at $0 on purpose",
    "Marcar todos": "Select all", "Desmarcar todos": "Deselect all",
    "Nada que cambiar: lo que llegó ya estaba igual.": "Nothing to change: what came in was already the same.",
    "Estos NO se tocan. Si alguno es tuyo con otro nombre, créale un alias o el ítem y vuelve a importar.":
      "These are NOT touched. If one is yours under another name, create an alias or the item and import again.",
    "Aplicando…": "Applying…", "Pega antes el CSV del proveedor": "Paste the supplier's CSV first",
    // Lista del estimador
    "CONVERTIDO ✓": "CONVERTED ✓", "CONGELADO": "FROZEN", "BORRADOR": "DRAFT",
    "Lo que daría hoy con los precios vivos": "What it would come to today with live prices",
    "Levantamiento en sitio": "On-site survey",
    "Estás en la casa: cuenta lo que ves y la app arma el estimado sola.": "You're at the house: count what you see and the app builds the estimate for you.",
    "Nuevo estimado": "New estimate", "¿Cómo vas a estimar este trabajo?": "How will you estimate this job?",
    "Rápido — horas y material, como el Excel": "Quick — hours and material, like the Excel",
    "Por planos (takeoff de Bluebeam)": "From plans (Bluebeam takeoff)",
    "Remodelación (levantamiento, por ensambles)": "Remodel (site survey, by assemblies)",
    "Servicio (rápido, plantillas)": "Service (quick, templates)",
    "¿De quién es este trabajo?": "Whose job is this?",
    "Max Power (mío)": "Max Power (mine)", "MXP MEP — con Roger": "MXP MEP — with Roger",
    "Los de MXP MEP salen aparte y solo dan el número: no crean proyecto ni propuesta.":
      "MXP MEP jobs are kept separate and only give the number: they don't create a project or a proposal.",
    "¿Para qué proyecto es?": "Which project is it for?", "Proyecto nuevo": "New project",
    "Elige uno si es un trabajo añadido a un proyecto que ya tienes (un extra, un service que crece). Si no, es un proyecto nuevo.":
      "Pick one if this is work added to a project you already have (an extra, a service call that grows). If not, it's a new project.",
    "Nombre del trabajo": "Job name", "Ej: Casa García — Rewire": "E.g. García house — Rewire", "Ej: Juan García": "E.g. Juan García",
    "Residencial": "Residential", "Comercial": "Commercial",
    "para la propuesta y el portal": "for the proposal and the portal", "Ej: (813) 555-0100": "E.g. (813) 555-0100",
    "Sq Ft (opcional)": "Sq ft (optional)", "Escenario": "Scenario", "Crear estimado": "Create estimate",
    "Todavía no hay estimados. Crea el primero arriba.": "No estimates yet. Create the first one above.",
    "Estos no son tuyos: solo dan el número. No crean proyecto ni propuesta.":
      "These aren't yours: they only give the number. They don't create a project or a proposal.",
    "Estimado creado ✓ — pon las horas y el material": "Estimate created ✓ — enter the hours and material",
    "Estimado creado ✓ — busca ítems del catálogo y ponles cantidad": "Estimate created ✓ — find catalog items and give them quantities",
    "¿Eliminar este estimado con todos sus ítems?": "Delete this estimate with all its items?",
    "Estimado eliminado ✓": "Estimate deleted ✓",
    // Aviso antes de mandar el bid (renglones sin material)
    "Si el supply viene más caro, la diferencia la pones tú.": "If the supplier comes in higher, you cover the difference.",
    "Aceptar = seguir así.": "OK = keep it as is.",
    "Cancelar = volver y revisarlas.": "Cancel = go back and review them.",
    "Cancelar = volver y revisarlos.": "Cancel = go back and review them.",
    "El precio NO los incluye": "The price does NOT include them",
    "El cliente va a leer que incluye materiales y estos renglones no lo llevan.":
      "The client will read that materials are included, and these lines don't have any.",
    // Horas y material a mano / ⚡ rápido
    "Editar": "Edit", "Horas y material a mano": "Hours and material by hand",
    "Lo que pongas aquí": "What you enter here", "se suma": "is added",
    "a los ensambles e ítems de arriba. Sirve para un service: las horas que calculas tú y el material como lo compras.":
      "to the assemblies and items above. Good for a service call: the hours you figure and the material as you buy it.",
    "Horas a mano": "Hours by hand", "Ej: 4": "E.g. 4", "Factor de productividad": "Productivity factor",
    "Meses de obra": "Job length (months)",
    "Solo para obras largas: a partir de aquí se calcula la escalación de salarios y material. Vacío = no se aplica.":
      "Only for long jobs: this is what wage and material escalation is figured from. Empty = not applied.",
    "Agregar línea": "Add line",
    "Sin líneas todavía: un total, o varias (breaker, caja, cable…).": "No lines yet: one total, or several (breaker, box, wire…).",
    "LOGÍSTICA, ALLOWANCE y SUBCONTRATO no son material: no pagan sales tax, ni misceláneas, ni markup, ni escalación, y no inflan la hora cargada. Sí llevan overhead y profit.":
      "LOGISTICS, ALLOWANCE and SUBCONTRACT aren't material: they don't pay sales tax, misc., markup or escalation, and they don't inflate the loaded hour. They do carry overhead and profit.",
    "Horas y material": "Hours and material", "Horas de todo el trabajo": "Hours for the whole job", "Ej: 90": "E.g. 90",
    "Pon el material: un total, o varias líneas (breakers, cable, luminarias…).": "Enter the material: one total, or several lines (breakers, wire, fixtures…).",
    "Este trabajo usa las tarifas de MXP MEP, no las tuyas. Se cambian en ⚙ Escenarios, en la lista de estimados. Si cambias cualquier número de abajo, este estimado pasa a":
      "This job uses MXP MEP's rates, not yours. They're changed in ⚙ Scenarios, in the estimate list. If you change any number below, this estimate becomes",
    "Toca A, B o C para usar ese escenario tal cual. Si cambias cualquier número de abajo, este estimado pasa a":
      "Tap A, B or C to use that scenario as is. If you change any number below, this estimate becomes",
    "(los escenarios no se tocan; para eso está ⚙ Escenarios en la lista).": "(the scenarios aren't touched; that's what ⚙ Scenarios in the list is for).",
    "Cuadrilla — quién trabaja y qué parte de las horas": "Crew — who works and what share of the hours",
    "Rol": "Role", "Quitar rol": "Remove role", "Agregar rol": "Add role", "Tarifa mezclada": "Blended rate",
    "Beneficios sobre el labor (%)": "Benefits on labor (%)",
    "Markup de materiales (%) — opcional": "Materials markup (%) — optional",
    "Overhead ($ por hora) — fijo por ahora": "Overhead ($ per hour) — fixed for now",
    "Los escenarios lado a lado": "Scenarios side by side", "$/h cargado": "Loaded $/h",
    "El $/h cargado es el precio final dividido entre las horas: lo que cobras por cada hora con todo adentro.":
      "The loaded $/h is the final price divided by the hours: what you charge for each hour with everything in.",
    // Auditoría del catálogo (AUDITORIA_E9G): las notas salen en la tarjeta mientras falte aplicarlas
    "un conector mayor": "a larger connector",
    "Las horas están arrastradas del PVC de 6\" (0,09): la escalera GRS va 4\"=0,15 y 5\"=0,20, así que el 6\" sigue con +0,05.":
      "The hours were carried over from 6\" PVC (0.09): the GRS ladder goes 4\"=0.15 and 5\"=0.20, so 6\" continues at +0.05.",
    "Único peldaño al revés de la escalera de locknuts (el de 3/4\" pide 0,02 y este 0,05).":
      "The only step out of order in the locknut ladder (3/4\" takes 0.02 and this one 0.05).",
    "Horas por pie rotas: restaura el 1,3× sobre el flex metálico que la familia respeta hasta 1-1/4\" (flex 1-1/2\" = 0,05).":
      "Broken hours per foot: restores the 1.3× over metal flex that the family keeps up to 1-1/4\" (flex 1-1/2\" = 0.05).",
    "Horas por pie rotas: el 0,25 es exactamente la hora del CONECTOR de flex de 2\" (por pieza) pegada en la fila del tubo (por pie); flex 2\" = 0,06/ft.":
      "Broken hours per foot: 0.25 is exactly the hour of the 2\" flex CONNECTOR (per piece) pasted into the conduit row (per foot); flex 2\" = 0.06/ft.",
    "Horas por pie rotas: el 0,30 es la hora del CONECTOR de flex de 2-1/2\" copiada en el tubo; flex 2-1/2\" = 0,08/ft.":
      "Broken hours per foot: 0.30 is the hour of the 2-1/2\" flex CONNECTOR copied into the conduit; flex 2-1/2\" = 0.08/ft.",
    "Horas por pie rotas: el 0,35 es la hora del CONECTOR de flex de 3\" copiada en el tubo; flex 3\" = 0,10/ft.":
      "Broken hours per foot: 0.35 is the hour of the 3\" flex CONNECTOR copied into the conduit; flex 3\" = 0.10/ft.",
    "Horas por pie rotas: 0,5 h por pie es más que instalar un pie de cualquier cosa del catálogo; 0,16 continúa la curva 0,065 / 0,08 / 0,10 / 0,13.":
      "Broken hours per foot: 0.5 h per foot is more than installing a foot of anything in the catalog; 0.16 continues the curve 0.065 / 0.08 / 0.10 / 0.13.",
    "Fila combo (caja + tapa de dispositivo, dos piezas de fundición) a $0.":
      "Combo row (box + device cover, two cast pieces) at $0.",
    "Combo a $0 cuando sus piezas suman $7,088 + $6,51 = $13,598, y ese precio exacto está en la obra de Stuart (GUIA-3-PROYECTOS línea 125).":
      "Combo at $0 when its pieces add up to $7.088 + $6.51 = $13.598, and that exact price is on the Stuart job (GUIA-3-PROYECTOS line 125).",
    "Typo de una celda: NEMA-1 y NEMA-3R llevan horas idénticas en las cinco medidas (1,2 / 1,4 / 1,8 / 2,0 / 2,5) salvo esta, que perdió el 4.":
      "One-cell typo: NEMA-1 and NEMA-3R carry identical hours in all five sizes (1.2 / 1.4 / 1.8 / 2.0 / 2.5) except this one, which lost the 4.",
    "La tapa del G4000 es lineal como su base (que está en LF): el precio $1,932 y las 0,03 h ya están por pie (58% de la base, proporción normal).":
      "The G4000 cover is linear like its base (which is in LF): the $1.932 price and the 0.03 h are already per foot (58% of the base, a normal ratio).",
    "Mismo caso que la tapa: el separador va la misma longitud que la base y su precio ($0,84) es por pie.":
      "Same case as the cover: the divider runs the same length as the base and its price ($0.84) is per foot.",
    "El Excel original de Edgar traía 'PUSH BUTTON Start/Stop' a 2 h; al recargar se renombró y quedó a 0,5 h (solo colgar la caja).":
      "Edgar's original Excel had 'PUSH BUTTON Start/Stop' at 2 h; on reload it was renamed and ended up at 0.5 h (just hanging the box).",
    "TU COTIZACIÓN UM (oct-2025).": "YOUR UM QUOTE (Oct-2025).",
    "TU EXCEL: MLF.": "YOUR EXCEL: MLF.",
    "Edgar pagó $99,99 la unidad en Stuart (8 unidades, GUIA-3-PROYECTOS línea 167) y el catálogo dice $59: precio de hace años.":
      "Edgar paid $99.99 each on Stuart (8 units, GUIA-3-PROYECTOS line 167) and the catalog says $59: a price from years ago.",
    "Edgar pagó $137,99 en Stuart y el catálogo dice $88.": "Edgar paid $137.99 on Stuart and the catalog says $88.",
    "0,008 h son 29 segundos por tapa: decimal corrido.": "0.008 h is 29 seconds per cover: misplaced decimal.",
    "Misma tapa sin WP, mismo 0,008 arrastrado.": "Same cover without WP, same 0.008 carried over.",
    "1,3 h por un switch es el doble del punto completo de receptáculo.": "1.3 h for a switch is double a complete receptacle point.",
    "Va con el THREE POLE: mismo +1,00 h de contaminación (1,25 = 0,25 + 1,00).":
      "Goes with the THREE POLE: the same +1.00 h carried in (1.25 = 0.25 + 1.00).",
    "Un TR se instala igual que el dúplex normal (0,3 h): mismos tornillos, mismos hilos, el obturador va dentro.":
      "A TR installs just like a regular duplex (0.3 h): same screws, same wires, the shutter is inside.",
    "Horas: 0,5 como el resto de USB.": "Hours: 0.5 like the rest of the USB ones.",
    "TU EXCEL: E · $32,06 · 0,6 h; al cargar quedó EA · $24 · 0,4.": "YOUR EXCEL: E · $32.06 · 0.6 h; on load it ended up EA · $24 · 0.4.",
    "Etiqueta MLF con precio y horas por pie ($0,15 / 0,15 h): las únicas dos MLF sub-dólar del catálogo son esta y CAT6.":
      "Labeled MLF with price and hours per foot ($0.15 / 0.15 h): the only two sub-dollar MLF items in the catalog are this one and CAT6.",
    "TU EXCEL: CAT6 CABLE · FT · $0,45 · 0,025 h/ft = $450 y 25 h por MLF.": "YOUR EXCEL: CAT6 CABLE · FT · $0.45 · 0.025 h/ft = $450 and 25 h per MLF.",
    "0,05 h/ft son 50 h por mil pies, casi el doble del MC armado.": "0.05 h/ft is 50 h per thousand feet, almost double armored MC.",
    "TU EXCEL: E · 0,2 h.": "YOUR EXCEL: E · 0.2 h.",
    "Arrancar cable a 0,03 h/ft son 30 h/MLF, cinco veces lo que cuesta instalarlo.":
      "Pulling out wire at 0.03 h/ft is 30 h/MLF, five times what it costs to install it.",
    "Demoler tubo a 0,05 h/ft cuesta más que instalar EMT de 1-1/4\" nuevo.": "Demolishing conduit at 0.05 h/ft costs more than installing new 1-1/4\" EMT.",
    "Tu Excel lo tiene en MLF a 20 h por mil pies, o sea 0,02 h/ft.": "Your Excel has it in MLF at 20 h per thousand feet, i.e. 0.02 h/ft.",
    "Es tu número: en Stuart cotizaste 100 cajas '4\"X 4\" X 2 1/8\" DEEP COMBO BOX' (la misma pieza) a $1,04 y 0,25 h, y a mano cobras 0,25 h por la caja 4x4":
      "It's your number: on Stuart you quoted 100 boxes '4\"X 4\" X 2 1/8\" DEEP COMBO BOX' (the same part) at $1.04 and 0.25 h, and by hand you charge 0.25 h for the 4x4 box"
  });
  REGLAS.push(
    // Importar precios: la cabecera que llegó (línea aparte del error)
    [/^Cabecera que llegó: (.+)$/, "Header received: $1"],
    // «¿Cómo acabó?» — el aviso de fuera de rango
    [/^; tus (\d+) ganados de (.+) van a$/, s => {
      const m = s.match(/^; tus (\d+) ganados de (.+) van a$/);
      const t = trE(m[2]);
      return `; your ${m[1]} won ${m[1] === "1" ? "job" : "jobs"} in the ${t.charAt(0).toLowerCase() + t.slice(1)} range ${m[1] === "1" ? "runs" : "run"} at`;
    }],
    [/^de mediana \(de (\S+) a (\S+)\)\. Eso es un$/, "median (from $1 to $2). That's a"],
    [/^Al marcarlo se guarda el número de hoy \((\S+)\) como el que ofertaste\. Después ya no se mueve\.$/,
      "Marking it saves today's number ($1) as the one you bid. After that it doesn't move."],
    [/^([\s\S]*?)Ese es el número que va al historial, no el de hoy\.$/, "$1That's the number that goes into the history, not today's."],
    [/^Marcado como (ganado|perdido|sin respuesta|descartado) ✓$/, s => {
      const k = s.replace(/^Marcado como /, "").replace(/ ✓$/, "");
      return "Marked as " + { ganado: "won", perdido: "lost", "sin respuesta": "no response", descartado: "dropped" }[k] + " ✓";
    }],
    [/^Ibas un (-?\d+) % por encima del que ganó$/, "You were $1 % above the winner"],
    // 💵 Pagos del contrato
    [/^Pagos del contrato · ([\d /.]+)$/, "Contract payments · $1"],
    [/^El de la propuesta que ya se armó \(([\d/.]+)\)\.$/, "The one from the proposal already built ($1)."],
    [/^Milestone (\d+) — ([\d.]+)%(?: (depósito|rough|trim|final))? · (.+?)(:?)$/, s => {
      const m = s.match(/^Milestone (\d+) — ([\d.]+)%(?: (depósito|rough|trim|final))? · (.+?)(:?)$/);
      const que = m[3] ? " " + (m[3] === "depósito" ? "deposit" : m[3]) : "";
      return `Milestone ${m[1]} — ${m[2]}%${que} · ${trE(m[4])}${m[5]}`;
    }],
    [/^Retainage — ([\d.]+)% retenido · Lo libera el contratante al cierre \(final pay application\)(:?)$/,
      "Retainage — $1% withheld · Released by the contractor at closeout (final pay application)$2"],
    [/^Pago único al completar · Al terminar el trabajo(:?)$/, "Single payment on completion · When the work is finished$1"],
    [/^Reparto decidido ✓ — ([\d /]+)$/, "Split decided ✓ — $1"],
    // Datos del trabajo y adjuntos
    [/^Retención ([\d.]+) % ✓ — cada pago sale sin ella y se cobra al cierre$/,
      "Retainage $1 % ✓ — each payment goes out without it and it's collected at closeout"],
    [/^Adjuntos del estimado \((\d+)\)$/, "Estimate attachments ($1)"],
    [/^enlace · (\S+)$/, "link · $1"],
    [/^No se pudo abrir: (.+)$/, s => "Couldn't open it: " + trE(s.replace(/^No se pudo abrir: /, ""))],
    [/^No se pudo subir: (.+) — prueba con el enlace de Drive$/, s =>
      "Couldn't upload: " + trE(s.replace(/^No se pudo subir: /, "").replace(/ — prueba con el enlace de Drive$/, "")) + " — try the Drive link"],
    // 📈 Historial
    [/^Historial — (\d+) estimados?(?: · ganas (\d+) % de los (\d+) que se decidieron)?$/, s => {
      const m = s.match(/^Historial — (\d+) estimados?(?: · ganas (\d+) % de los (\d+) que se decidieron)?$/);
      return `History — ${m[1]} ${m[1] === "1" ? "estimate" : "estimates"}` +
        (m[2] ? ` · you win ${m[2]} % of the ${m[3]} that were decided` : "");
    }],
    [/^\(mediana de (\d+)\)$/, "(median of $1)"],
    [/^solo (\d+) con sqft — todavía no es una referencia$/, "only $1 with sqft — not a reference yet"],
    [/^De los perdidos en que supiste el número del otro \((\d+)\), ibas de media un$/,
      "Of the lost ones where you learned the other bid ($1), on average you were"],
    [/^por encima; el peor, (-?\d+) %\.$/, "above; the worst, $1 %."],
    [/^Por qué se perdieron: (.+)$/, s => {
      const nom = { "Precio": "Price", "Plazo": "Schedule", "Alcance": "Scope", "Relación": "Relationship", "No calificamos": "Didn't qualify", "Otro": "Other" };
      return "Why they were lost: " + s.replace(/^Por qué se perdieron: /, "").split(" · ")
        .map(p => { const m = p.match(/^(.+) \((\d+)\)$/); return m && nom[m[1]] ? `${nom[m[1]]} (${m[2]})` : p; }).join(" · ");
    }],
    // 🏷️ Precios del catálogo
    [/^Precios del catálogo — (\d+) ítems(?: · (\d+) con referencia)?$/, s => {
      const m = s.match(/^Precios del catálogo — (\d+) ítems(?: · (\d+) con referencia)?$/);
      return `Catalog prices — ${m[1]} items` + (m[2] ? ` · ${m[2]} with a reference` : "");
    }],
    [/^(\d+) (ítem no tiene|ítems no tienen) fecha de precio: no hay forma de saber si son de este año o de hace tres\. Al importar se les pone\.$/, s => {
      const n = parseInt(s, 10);
      return `${n} ${n === 1 ? "item has" : "items have"} no price date: there's no way to know if they're from this year or three years ago. Importing sets it.`;
    }],
    [/^Tuyo vs referencia — (\d+) se separan más del 15 %$/, "Yours vs reference — $1 differ by more than 15 %"],
    [/^y (\d+) más\.$/, "and $1 more."],
    [/^por (alias|código)$/, s => s === "por alias" ? "by alias" : "by code"],
    [/^\((.+)\): ponerle precio fijo cambia cómo se cotiza$/, "($1): a fixed price changes how it's quoted"],
    [/^(cambia|cambian|sin pareja) · (\d+) sin número$/, s => {
      const m = s.match(/^(cambia|cambian|sin pareja) · (\d+) sin número$/);
      return `${trE(m[1])} · ${m[2]} without a number`;
    }],
    [/^Aplicar (\d+) cambios?( a la referencia)?$/, s => {
      const m = s.match(/^Aplicar (\d+) cambios?( a la referencia)?$/);
      return `Apply ${m[1]} ${m[1] === "1" ? "change" : "changes"}${m[2] ? " to the reference" : ""}`;
    }],
    [/^Sin pareja en tu catálogo \((\d+)\)$/, "Unmatched in your catalog ($1)"],
    [/^¿Aplicar (\d+) cambios? (a los precios de REFERENCIA|a TUS precios)\?$/, s => {
      const m = s.match(/^¿Aplicar (\d+) cambios? (a los precios de REFERENCIA|a TUS precios)\?$/);
      return `Apply ${m[1]} ${m[1] === "1" ? "change" : "changes"} ${m[2] === "a TUS precios" ? "to YOUR prices" : "to the REFERENCE prices"}?`;
    }],
    [/^OJO: (\d+) estaban? a \$0 a propósito \((.+)\)\. Ponerles precio fijo cambia cómo se cotizan\.$/, s => {
      const m = s.match(/^OJO: (\d+) estaban? a \$0 a propósito \((.+)\)\. Ponerles precio fijo cambia cómo se cotizan\.$/);
      return `CAREFUL: ${m[1]} ${m[1] === "1" ? "was" : "were"} at $0 on purpose (${m[2]}). A fixed price changes how they're quoted.`;
    }],
    [/^(\d+) aplicados · (\d+) fallaron — (.+)$/, "$1 applied · $2 failed — $3"],
    [/^(\d+) precios? actualizados? ✓$/, s => { const n = parseInt(s, 10); return `${n} ${n === 1 ? "price" : "prices"} updated ✓`; }],
    // Lista del estimador: «cliente · vía X (contrato con ellos) · 2200 sqft · escenario B ·»
    [/^(.*?)(^|· )escenario ([A-Za-z0-9]+)( ·)?$/, s => s
      .replace(/(^|· )escenario ([A-Za-z0-9]+)( ·)?$/, "$1scenario $2$3")
      .replace(/(^|· )vía (.+?) \(contrato con ellos\)/, "$1via $2 (contract with them)")
      .replace(/(^|· )vía (.+?) \(referido\)/, "$1via $2 (referral)")],
    [/^añadido a (.+)$/, "added to $1"],
    [/^hoy (\$[\d,.]+|\$•••)$/, "today $1"],
    [/^(.+) \(completado\)$/, "$1 (completed)"],
    [/^Mis estimados \((\d+)\)$/, "My estimates ($1)"],
    [/^MXP MEP — con Roger \((\d+)\)$/, "MXP MEP — with Roger ($1)"],
    // El aviso antes de mandar el bid (confirmar, línea por línea)
    [/^(\d+) (luminaria va|luminarias van) a TU PRECIO DE REFERENCIA \((\S+)\), no a cuota del supply: ese dinero SÍ está en el precio, pero la cuota de verdad todavía no ha llegado\.$/, s => {
      const m = s.match(/^(\d+) (luminaria va|luminarias van) a TU PRECIO DE REFERENCIA \((\S+)\)/);
      return `${m[1]} ${m[1] === "1" ? "fixture goes" : "fixtures go"} at YOUR REFERENCE PRICE (${m[3]}), not a supplier quote: that money IS in the price, but the real quote hasn't come in yet.`;
    }],
    [/^Este estimado lleva (\d+) (renglón|renglones) sin material\.$/, s => {
      const n = parseInt(s.replace(/^\D+/, ""), 10);
      return `This estimate has ${n} ${n === 1 ? "line" : "lines"} with no material.`;
    }],
    [/^(• )?(.+) — (\d+) (renglón|renglones), ([\d.]+) h$/, s => {
      const m = s.match(/^(• )?(.+) — (\d+) (renglón|renglones), ([\d.]+) h$/);
      const sec = { "SIN CATÁLOGO": "NOT IN CATALOG", "SIN SECCIÓN": "NO SECTION" }[m[2]] || m[2];
      return `${m[1] || ""}${sec} — ${m[3]} ${m[3] === "1" ? "line" : "lines"}, ${m[5]} h`;
    }],
    [/^Y (\d+) dice\(n\) "by owner" porque lo supuso la app: mientras no lo confirmes, NO sale en la propuesta\.$/,
      "And $1 say \"by owner\" because the app assumed it: until you confirm it, it does NOT go on the proposal."],
    // Horas y material a mano / ⚡ rápido
    [/^Material a mano — (\S+)( · (\S+) en cotizaciones)?( · (\S+) en logística, allowances y subs)?$/, s => {
      const m = s.match(/^Material a mano — (\S+)( · (\S+) en cotizaciones)?( · (\S+) en logística, allowances y subs)?$/);
      return `Material by hand — ${m[1]}` + (m[2] ? ` · ${m[3]} in quotes` : "") + (m[4] ? ` · ${m[5]} in logistics, allowances and subs` : "");
    }],
    [/^Lo marcado como COTIZACIÓN no paga el (\d+) % de misceláneas: ese porcentaje es tape, wirenuts y fijación, y un switchgear que llega en camión no los consume\.$/,
      "Lines marked QUOTE don't pay the $1 % misc.: that percentage is tape, wirenuts and fastening, and a switchgear that arrives on a truck doesn't use any."],
    [/^Al material se le suma el ([\d.]+%) de misceláneas y el ([\d.]+%) de tax\. El markup es opcional, abajo\.$/,
      "Material gets $1 misc. and $2 tax added. Markup is optional, below."],
    [/^Suma: ([\d.]+)% (✓|— tiene que dar 100%)$/, s => s
      .replace(/^Suma: /, "Total: ").replace("— tiene que dar 100%", "— it has to add up to 100%")]
  );
  // · parte-F
  // ============ Parte F · app.js 11043–13300 (estimador: rápido, escenarios, consumibles,
    // horas del proyecto, auditoría del catálogo, luminarias, editor del estimado; calendario) ============
  
    // ---------- F1 · Estimado rápido y escenarios A/B/C ----------
    Object.assign(D, {
      "Editar": "Edit", "Quitar": "Remove", "Rol": "Role", "Quitar rol": "Remove role",
      "Horas y material": "Hours and material",
      "Horas de todo el trabajo": "Hours for the whole job",
      "Ej: 90": "E.g.: 90",
      "Factor de productividad": "Productivity factor",
      "Meses de obra": "Job length (months)",
      "Solo para obras largas: a partir de aquí se calcula la escalación de salarios y material. Vacío = no se aplica.":
        "Only for long jobs: wage and material escalation is calculated from this. Empty = not applied.",
      "+ Agregar línea": "+ Add line",
      "Pon el material: un total, o varias líneas (breakers, cable, luminarias…).":
        "Enter the material: one total, or several lines (breakers, wire, light fixtures…).",
      "Escenario": "Scenario",
      "Este trabajo usa las tarifas de MXP MEP, no las tuyas. Se cambian en ⚙ Escenarios, en la lista de estimados. Si cambias cualquier número de abajo, este estimado pasa a":
        "This job uses MXP MEP's rates, not yours. They're changed in ⚙ Scenarios, in the estimates list. If you change any number below, this estimate becomes",
      "Toca A, B o C para usar ese escenario tal cual. Si cambias cualquier número de abajo, este estimado pasa a":
        "Tap A, B or C to use that scenario as is. If you change any number below, this estimate becomes",
      "(los escenarios no se tocan; para eso está ⚙ Escenarios en la lista).":
        "(the scenarios aren't touched; that's what ⚙ Scenarios in the list is for).",
      "Cuadrilla — quién trabaja y qué parte de las horas": "Crew — who works and what share of the hours",
      "+ Agregar rol": "+ Add role",
      "Tarifa mezclada": "Blended rate",
      "Beneficios sobre el labor (%)": "Benefits on labor (%)",
      "Markup de materiales (%) — opcional": "Materials markup (%) — optional",
      "Overhead ($ por hora) — fijo por ahora": "Overhead ($ per hour) — fixed for now",
      "Los escenarios lado a lado": "Scenarios side by side",
      "$/h cargado": "Loaded $/h",
      "El $/h cargado es el precio final dividido entre las horas: lo que cobras por cada hora con todo adentro.":
        "Loaded $/h is the final price divided by the hours: what you charge for each hour with everything included.",
      // Avisos y preguntas del estimado rápido
      "Sin escalación ✓": "No escalation ✓",
      "¿Qué material? (o escribe 'Material' para un total)": "What material? (or type 'Material' for a total)",
      "Monto no válido": "Invalid amount",
      "Material agregado ✓": "Material added ✓",
      "Monto (sin tax)": "Amount (before tax)",
      "Material corregido ✓": "Material updated ✓",
      "Línea quitada ✓": "Line removed ✓",
      "Marcado como cotización ✓ — ya no paga misceláneas": "Marked as a quote ✓ — no longer pays misc.",
      "Vuelve a ser material tuyo ✓": "Back to your own material ✓",
      "Nombre del rol nuevo (Ej: Apprentice)": "New role name (e.g. Apprentice)",
      "Rol agregado — ahora reparte los % para que sumen 100": "Role added — now split the % so they add up to 100",
      "Rol quitado — revisa que los % sumen 100": "Role removed — check that the % add up to 100",
      // ⚙ Escenarios
      "Escenarios — tarifas y cuadrilla": "Scenarios — rates and crew",
      "Estos números son los de la casa: cada estimado nuevo arranca con ellos. Cámbialos cuando cambie tu gente o tus costos.":
        "These are the house numbers: every new estimate starts with them. Change them when your people or your costs change.",
      "Nombre": "Name",
      "Los trabajos con Roger. Cuadrilla más grande, otro overhead y el sales tax de su condado: Orange es 6.5 %, Hillsborough 7.5 %.":
        "Jobs with Roger. Bigger crew, different overhead and the sales tax of their county: Orange is 6.5%, Hillsborough 7.5%.",
      "Beneficios (%)": "Benefits (%)",
      "Sale de sumar el desglose de abajo": "It's the sum of the breakdown below",
      "Overhead ($/hora)": "Overhead ($/hour)",
      "…o % del costo": "…or % of cost",
      "vacío": "empty",
      "Overhead por": "Overhead by",
      "porcentaje del costo directo": "percentage of direct cost",
      "hora-hombre": "man-hour",
      ": tus gastos generales repartidos entre tus horas. Si quieres el otro método, escribe un % aquí al lado y este se apaga.":
        ": your overhead spread across your hours. If you want the other method, type a % in the box next to it and this one turns off.",
      "Lo que te cuesta un empleado POR ENCIMA de su salario. El total de arriba sale de sumar esto, así que se puede auditar: o cubre, o te lo estás comiendo en cada hora.":
        "What an employee costs you ON TOP of their wage. The total above is the sum of these, so it can be audited: either it covers it, or you're eating it on every hour.",
      "· ley": "· law",
      "FICA es ley federal. El workers comp de electricista en Florida (código 5190) está en 2,97 % en 2026; si tu póliza dice otra cosa, pon la tuya. El seguro médico viene en 0: si lo das, es el que más pesa.":
        "FICA is federal law. Workers' comp for electricians in Florida (code 5190) is 2.97% in 2026; if your policy says otherwise, enter yours. Health insurance starts at 0: if you offer it, it's the heaviest one.",
      // Los renglones del desglose de beneficios (BENEF_BASE, línea ~8216: se pintan en esta tarjeta)
      "FICA (Social Security 6,2 % + Medicare 1,45 %)": "FICA (Social Security 6.2% + Medicare 1.45%)",
      "FUTA federal (sobre los primeros $7.000)": "Federal FUTA (on the first $7,000)",
      "Paro de Florida (sobre los primeros $7.000)": "Florida unemployment (on the first $7,000)",
      "Workers comp — eléctrico, código 5190": "Workers' comp — electrical, code 5190",
      "Responsabilidad civil (GL)": "General liability (GL)",
      "Vacaciones y feriados": "Vacation and holidays",
      "Seguro médico": "Health insurance",
      "Herramienta, uniformes, formación": "Tools, uniforms, training",
      "Rol nuevo": "New role",
      // Propuestas guardadas de un estimado
      "FIRMADA ✓": "SIGNED ✓", "VENCIDA": "EXPIRED", "PROPUESTA": "PROPOSAL",
      "sin fecha de validez": "no validity date",
      "Preparar cierre": "Prepare closing",
      // Tarjeta que falla
      "⚠ Una tarjeta nueva falló": "⚠ A new card failed"
    });
    REGLAS.push(
      [/^Al material se le suma el (\S+) de misceláneas y el (\S+) de tax\. El markup es opcional, abajo\.$/,
        "Material gets $1 misc. and $2 sales tax added. Markup is optional, below."],
      [/^Suma: (-?[\d.]+)% ✓$/, "Total: $1% ✓"],
      [/^Suma: (-?[\d.]+)% — tiene que dar 100%$/, "Total: $1% — it has to be 100%"],
      [/^Obra de ([\d.]+) (mes|meses) ✓ — se calcula la escalación$/, s => {
        const n = s.match(/^Obra de ([\d.]+)/)[1];
        return `${n}-month job ✓ — escalation is calculated`; }],
      [/^¿Cuánto cuesta "(.*)"\? \(sin tax\)$/, 'How much does "$1" cost? (before tax)'],
      [/^Marcado como (LOGÍSTICA|ALLOWANCE|SUBCONTRATO) ✓ — sin tax, misceláneas ni escalación$/, s => {
        const t = { "LOGÍSTICA": "LOGISTICS", "ALLOWANCE": "ALLOWANCE", "SUBCONTRATO": "SUBCONTRACT" }[s.match(/como (\S+) ✓/)[1]];
        return `Marked as ${t} ✓ — no sales tax, misc. or escalation`; }],
      [/^Escenario ([A-Z]|MEP) ✓$/, "Scenario $1 ✓"],
      [/^Tarifa por hora de (.+) \(\$\):?$/, "Hourly rate for $1 ($):"],
      [/^: ([\d.]+) % sobre mano de obra \+ material\. Es el método del Excel de Miami y el que sirve cuando la oficina y los camiones no los pones tú\. NECA sitúa el 14–16 % en operaciones bien llevadas; el Excel usaba 10 %\.$/,
        ": $1% on labor + material. It's the Miami Excel method, and the one that works when the office and the trucks aren't on you. NECA puts well-run operations at 14–16%; the Excel used 10%."],
      [/^¿De qué se compone ese ([\d.,]+) % de beneficios\?$/, "What makes up that $1% of benefits?"],
      [/^💾 Guardar ([A-Z]|MEP)$/, "💾 Save $1"],
      [/^Guardar ([A-Z]|MEP)$/, "Save $1"],
      [/^Los % de la cuadrilla suman (-?[\d.]+)% — tienen que dar 100%$/, "The crew % add up to $1% — they have to be 100%"],
      [/^Escenario ([A-Z]|MEP) guardado ✓ — vale para los estimados nuevos$/, "Scenario $1 saved ✓ — applies to new estimates"],
      [/^(\d+) opci(ón|ones)( · [A-Z/]+)?$/, s => {
        const m = s.match(/^(\d+) opci(?:ón|ones)( · [A-Z/]+)?$/);
        return `${m[1]} ${m[1] === "1" ? "option" : "options"}${m[2] || ""}`; }],
      [/^vale hasta (\S+)$/, "valid until $1"],
      [/^(.+) — el resto del estimado sigue bien\. Dímelo y lo arreglo\.$/, "$1 — the rest of the estimate is fine. Tell me and I'll fix it."]
    );
  
    // ---------- F2 · Consumibles automáticos, horas del proyecto, auditoría del catálogo ----------
    Object.assign(D, {
      // Nombres de las reglas de consumibles (CONS_REGLAS, línea ~8407) y de los soportes (SOPORTES, ~8386)
      "Acoples": "Couplings", "Conectores": "Connectors", "Cajas de paso": "Pull boxes", "Tapas ciegas": "Blank covers",
      "Tornillo a metal": "Metal screws", "Colgador de T-bar": "T-bar hangers",
      "Unistrut (pies)": "Unistrut (ft)", "All-thread 1/4 (pies)": "All-thread 1/4 (ft)", "Tuercas 1/4": "1/4 nuts",
      "Arandelas 1/4": "1/4 washers", "Anclas 1/4": "1/4 anchors", "Grasa de alambrar": "Wire-pulling lube",
      "Libreta de números": "Wire marker book",
      "Pared o losa — one-hole strap + tapcon": "Wall or slab — one-hole strap + tapcon",
      "Power strap (dos tornillos)": "Power strap (two screws)",
      "Metal deck / estructura — tornillo autorroscante": "Metal deck / structure — self-drilling screw",
      "Unistrut / trapecio colgado": "Unistrut / hung trapeze",
      "Ceiling tile — colgador de T-bar": "Ceiling tile — T-bar hanger",
      // La tarjeta de consumibles
      "TUYO": "YOURS",
      "Cuántos por cada unidad de la cuenta": "How many per counting unit",
      "Un trapecio cada cuántos pies de tubo": "One trapeze every how many feet of conduit",
      "Consumibles automáticos — la tabla que manda": "Automatic consumables — the table in charge",
      "con el": "with",
      "Merma de tubería (%)": "Conduit waste (%)",
      "Merma de cable (%)": "Wire waste (%)",
      "Guardar la tabla": "Save the table",
      "Volver a los números de arranque": "Back to the starting numbers",
      "Valen para todos los estimados y se guardan una sola vez. Solo se guarda lo que cambies: si mañana corrijo un número de arranque, el tuyo sigue mandando y el resto se actualiza solo.":
        "They apply to all estimates and are saved once. Only what you change is saved: if I fix a starting number tomorrow, yours still rules and the rest updates on its own.",
      "Tabla guardada — todo vuelve a los números de arranque": "Table saved — everything goes back to the starting numbers",
      "¿Volver a los números de arranque? Se pierden los tuyos.": "Go back to the starting numbers? Yours will be lost.",
      "Tabla de consumibles a los números de arranque": "Consumables table back to the starting numbers",
      // Horas del proyecto
      "Marca lo que quieras añadir al estimado": "Check what you want to add to the estimate",
      "SUPUESTO": "ASSUMPTION", "SUPUESTOS": "ASSUMPTIONS",
      "Horas del proyecto — lo que no es instalar una pieza": "Project hours — what isn't installing a device",
      "Terminar circuitos en el panel, demoler, rotular, poner en marcha los 0-10V, cerrar. En Nicklaus esto eran":
        "Terminating circuits at the panel, demo, labeling, commissioning the 0-10V, close-out. On Nicklaus this was",
      "70 horas": "70 hours",
      "que no estaban en el borrador. Los números salen de lo que ya tiene el estimado; los":
        "that weren't in the draft. The numbers come from what the estimate already has; the",
      "son de arranque — cámbialos y entonces márcalos.": "are starting values — change them and then check them.",
      "Se añaden como renglones normales: después se cambian o se borran como cualquier otro.":
        "They're added as regular lines: afterwards you change or delete them like any other.",
      "No marcaste ninguna": "You didn't check any",
      "No encuentro breakers en el estimado: las horas de terminar y rotular circuitos salen en 0 — pon tú el número de circuitos.":
        "I can't find breakers in the estimate: the hours to terminate and label circuits come out as 0 — enter the number of circuits yourself.",
      // Auditoría del catálogo
      "Al emparejar el takeoff, la app mira": "When matching the takeoff, the app looks at",
      "código → alias → nombre": "code → alias → name",
      ": el alias va ANTES que el nombre exacto. Estos se llaman igual que una fila tuya pero mandan a otra pieza, así que esa otra es la que entra al estimado y tu fila no llega a mirarse. Si lo pusiste a propósito, déjalo; si no, bórralo en Materiales → Alias.":
        ": the alias comes BEFORE the exact name. These have the same name as one of your rows but point to another part, so that other part is what goes into the estimate and your row never gets looked at. If you did it on purpose, leave it; if not, delete it in Materials → Alias.",
      "tapa": "hides",
      "cuentas": "you count",
      "— que ni siquiera está en el catálogo": "— which isn't even in the catalog",
      "Cuando una receta busca una pieza se queda con": "When a recipe looks for a part it takes",
      "la primera": "the first one",
      "que encuentra, y el orden en que llegan del servidor no está garantizado. Mientras las gemelas valgan lo mismo da igual.":
        "it finds, and the order they come from the server isn't guaranteed. As long as the twins cost the same it doesn't matter.",
      "El día que corrijas una con el precio del supply, la receta puede seguir cobrando la otra":
        "The day you fix one with the supply price, the recipe may keep charging the other",
      "y no te lo va a decir nadie. Bórrale la de más en Materiales → Catálogo.":
        "and nobody is going to tell you. Delete the extra one in Materials → Catalog.",
      "y NO valen lo mismo": "and they DON'T cost the same",
      "El conector NM de ½\" es de 14/2 y 12/2: por ahí no pasa un cable más grueso. En la obra hay que ir a buscar el bueno y en el bid está el barato.":
        "The ½\" NM connector is for 14/2 and 12/2: a bigger cable won't fit through it. On the job someone has to go get the right one, and the bid has the cheap one.",
      "(está en tu catálogo: cámbialo en la receta)": "(it's in your catalog: change it in the recipe)",
      "esa pieza no está en tu catálogo": "that part isn't in your catalog",
      ": hay que darla de alta con su precio": ": it has to be added with its price",
      "La auditoría del 16/09 encontró horas copiadas de otra familia, unidades rotas y precios de tus propias facturas.":
        "The 09/16 audit found hours copied from another family, broken units and prices from your own invoices.",
      "ya están en tu catálogo, y": "are already in your catalog, and",
      "ya están en tu catálogo. Estas": "are already in your catalog. These",
      "los cambiaste tú a otro número (esos no se tocan). Estas": "you changed to another number yourself (those aren't touched). These",
      "siguen con el valor viejo — y": "still have the old value — and",
      "siguen con el valor viejo.": "still have the old value.",
      "está en ESTE estimado.": "is in THIS estimate.",
      "están en ESTE estimado.": "are in THIS estimate.",
      "EN ESTE BID": "IN THIS BID", "catálogo": "catalog",
      "Esto se arregla en la base, no aquí: copia el SQL y pégalo en Supabase. Cada sentencia lleva el valor de hoy como condición, así que si ya lo cambiaste no hace nada.":
        "This gets fixed in the database, not here: copy the SQL and paste it in Supabase. Each statement carries today's value as a condition, so if you already changed it, it does nothing.",
      "Ver el SQL": "See the SQL"
    });
    REGLAS.push(
      // «por cada 100 ft de tubo, por talla de tubo · siempre · aquí puso» (tarjeta de consumibles)
      [/^por cada (100 ft de tubo|caja del estimado|trapecio|grapa que puso la tabla|100 ft de conductor)(, por talla de tubo)? · (siempre|solo la parte del tubo en trapecio|solo con «[^»]+»)( — no entra en este trabajo| · aquí puso| · aquí no hizo falta comprar ninguno: las recetas ya traían| · aquí no puso nada)$/, s => {
        const m = s.match(/^por cada (100 ft de tubo|caja del estimado|trapecio|grapa que puso la tabla|100 ft de conductor)(, por talla de tubo)? · (siempre|solo la parte del tubo en trapecio|solo con «([^»]+)»)(.*)$/);
        const cuenta = { "100 ft de tubo": "per 100 ft of conduit", "caja del estimado": "per box in the estimate",
          "trapecio": "per trapeze", "grapa que puso la tabla": "per strap the table added",
          "100 ft de conductor": "per 100 ft of conductor" }[m[1]];
        const cond = m[3] === "siempre" ? "always" : m[3] === "solo la parte del tubo en trapecio" ? "only the conduit on trapeze"
          : `only with «${D[m[4]] !== undefined ? D[m[4]] : m[4]}»`;
        const fin = { " — no entra en este trabajo": " — doesn't apply to this job", " · aquí puso": " · here it added",
          " · aquí no hizo falta comprar ninguno: las recetas ya traían": " · none needed here: the recipes already had",
          " · aquí no puso nada": " · added nothing here" }[m[5]];
        return cuenta + (m[2] ? ", by conduit size" : "") + " · " + cond + fin; }],
      [/^Los (\d+) números que convierten lo que mediste en fittings\. Este trabajo va$/,
        "The $1 numbers that turn what you measured into fittings. This job is"],
      [/^(del tubo en trapecio )?\(se cambia arriba\)\. Las reglas que no entran con ese soporte salen en gris\.( Ahora mismo generan)?$/, s =>
        (s.startsWith("del tubo") ? "of the conduit on trapeze " : "") + "(changed above). Rules that don't apply to that support show in gray."
        + (/generan$/.test(s) ? " Right now they generate" : "")],
      [/^en (\d+) renglón\(es\) AUTO\.$/, s => { const n = s.match(/\d+/)[0]; return `in ${n} AUTO ${n === "1" ? "line" : "lines"}.`; }],
      [/^Ver y cambiar los (\d+) números$/, "See and change the $1 numbers"],
      [/^Tabla guardada — (\d+) número\(s\) tuyos mandan sobre los de arranque$/, s => {
        const n = s.match(/\d+/)[0]; return `Table saved — ${n} of your own ${n === "1" ? "numbers overrides" : "numbers override"} the starting ones`; }],
      [/^✓ Tabla guardada — (\d+) número\(s\) tuyos mandan sobre los de arranque$/, s => {
        const n = s.match(/\d+/)[0]; return `✓ Table saved — ${n} of your own ${n === "1" ? "numbers overrides" : "numbers override"} the starting ones`; }],
      // El renglón AUTO: «12 E · regla: Acoples — 10 por 100 ft de 3/4" EMT · ya venían 5 en las recetas»
      [/^([\d.]+) (\S+ )?· regla: .+ — [\d.]+ por /, s => s
        .replace(/· regla: (.+?) — ([\d.]+) por /, (x, nom, n) => `· rule: ${D[nom] !== undefined ? D[nom] : nom} — ${n} per `)
        .replace(/per 100 ft de conductor/, "per 100 ft of conductor").replace(/per 100 ft de /, "per 100 ft of ")
        .replace(/per caja/, "per box").replace(/per trapecio, uno cada ([\d.]+) ft/, "per trapeze, one every $1 ft")
        .replace(/per grapa/, "per strap")
        .replace(/ · ya venían ([\d.]+) en las recetas/, " · $1 already came in the recipes")
        .replace(/ · material por cotizar$/, " · material to be quoted").replace(/ · sin precio en el catálogo$/, " · no price in the catalog")
        .replace(/ · nadie ha dicho por qué va en cero$/, " · nobody has said why it's at zero")
        .replace(/ · este nombre no está en el catálogo$/, " · this name isn't in the catalog")
        .replace(/ · no lleva material$/, " · no material").replace(/ · material del cliente$/, " · client's material")
        .replace(/ · revísalo$/, " · check it")],
      // Los avisos de la tabla de consumibles (vienen de autosConsumibles, ~8547)
      [/^(.+): no encuentro «(.+?)» en el catálogo — esa regla no corrió(\. Lo más parecido es «(.+)», que NO es lo que pide esta regla: o das de alta la pieza buena, o cambia arriba cómo va sujeto el tubo)?$/, s => {
        const m = s.match(/^([⚠•] )?(.+?): no encuentro «(.+?)» en el catálogo — esa regla no corrió(?:\. Lo más parecido es «(.+)», que NO es lo que pide esta regla: o das de alta la pieza buena, o cambia arriba cómo va sujeto el tubo)?$/);
        if (!m) return s;
        m.shift(); const pre = m.shift() || "";
        m.unshift(null);
        const nom = D[m[1]] !== undefined ? D[m[1]] : m[1];
        return `${pre}${nom}: I can't find «${m[2]}» in the catalog — that rule didn't run`
          + (m[3] ? `. The closest is «${m[3]}», which is NOT what this rule asks for: either add the right part, or change above how the conduit is supported` : ""); }],
      // Horas del proyecto
      [/^YA ESTÁ · ([\d.]+)$/, "ALREADY IN · $1"],
      [/^YA ESTÁ CON ([\d.]+)$/, "ALREADY IN WITH $1"],
      [/^(.+) · ([\d.]+) h cada uno$/, s => {
        const m = s.match(/^(.+) · ([\d.]+) h cada uno$/);
        const de = m[1]
          .replace(/^el trato es con un contratista: si el permiso lo saca el GC, NO lo marques \(regla de la casa\)$/,
            "the deal is with a contractor: if the GC pulls the permit, DON'T check it (house rule)")
          .replace(/^(\d+) breaker\(s\) LISTADOS en el estimado — si el trabajo tiene más circuitos que breakers comprados, cámbialo$/,
            "$1 breaker(s) LISTED in the estimate — if the job has more circuits than breakers bought, change it")
          .replace(/^SUPUESTO: (\d+) dispositivo\(s\) \+ (\d+) luminaria\(s\) nuevas$/, "ASSUMPTION: $1 new device(s) + $2 fixture(s)")
          .replace(/^(\d+) dimmer\(s\) y sensor\(es\)$/, "$1 dimmer(s) and sensor(s)")
          .replace(/^por proyecto — ponlo tú$/, "per project — you set it");
        return `${de} · ${m[2]} h each`; }],
      [/^➕ Añadir al estimado lo marcado( \(([\d.]+) h\))?$/, s => "➕ Add the checked ones to the estimate" + (s.match(/ \([\d.]+ h\)$/) || [""])[0]],
      [/^✓ (\d+) renglón\(es\) de horas añadido\(s\)( y (\d+) actualizado\(s\))?$/, s => {
        const m = s.match(/^✓ (\d+) renglón\(es\) de horas añadido\(s\)(?: y (\d+) actualizado\(s\))?$/);
        return `✓ ${m[1]} hour ${m[1] === "1" ? "line" : "lines"} added` + (m[2] ? ` and ${m[2]} updated` : ""); }],
      [/^«(.+)» no está en el catálogo — corre docs\/sql\/e27\.sql$/, "«$1» isn't in the catalog — run docs/sql/e27.sql"],
      // Auditoría del catálogo
      [/^↪ (\d+) alias que TAPA\(N\) una fila de tu catálogo$/, s => {
        const n = s.match(/\d+/)[0]; return n === "1" ? "↪ 1 alias HIDES a row of your catalog" : `↪ ${n} aliases HIDE a row of your catalog`; }],
      [/^\((\S+) · ([\d.]+) h · (\$[\d,.]+|\$•••)\) y entra$/, "($1 · $2 h · $3) but in goes"],
      [/^⚇ (\d+) fila\(s\) del catálogo con el MISMO nombre$/, s => {
        const n = s.match(/\d+/)[0]; return `⚇ ${n} catalog ${n === "1" ? "row" : "rows"} with the SAME name`; }],
      [/^(\d+) veces$/, "$1 times"],
      [/^: (.+) — el número cambia según cuál coja$/, ": $1 — the number changes depending on which one it picks"],
      [/^las (\d+) valen (\S+)( y ([\d.]+) h)?: hoy da igual cuál coja, pero deja una sola$/, s => {
        const m = s.match(/^las (\d+) valen (\S+)(?: y ([\d.]+) h)?:/);
        return `${m[1] === "2" ? "both" : "all " + m[1]} cost ${m[2]}${m[3] ? ` and ${m[3]} h` : ""}: today it doesn't matter which one it picks, but keep only one`; }],
      [/^🔌 (\d+) receta\(s\) con un conector que no le cabe al cable$/, s => {
        const n = s.match(/\d+/)[0]; return `🔌 ${n} ${n === "1" ? "recipe" : "recipes"} with a connector the cable doesn't fit`; }],
      [/^lleva (.+) con cable #(\S+) · hace falta$/, "uses $1 with #$2 cable · needs"],
      [/^🧾 La auditoría del catálogo: faltan (\d+) de (\d+)$/, "🧾 Catalog audit: $1 of $2 missing"],
      // «horas: 0.5 →» / «· precio: 12 →» (lo viejo → lo nuevo de la auditoría)
      [/^(· )?(horas|precio|unidad|código|codigo): (.*) →$/, s => {
        const m = s.match(/^(· )?(horas|precio|unidad|código|codigo): (.*) →$/);
        const k = { horas: "hours", precio: "price", unidad: "unit", "código": "code", codigo: "code" }[m[2]];
        return `${m[1] || ""}${k}: ${m[3]} →`; }],
      [/^…y (\d+) más\.$/, "…and $1 more."],
      [/^📋 Copiar el SQL de las (\d+) que faltan$/, "📋 Copy the SQL for the $1 missing"],
      [/^No se pudo guardar: (.+)$/, "Couldn't save: $1"],
      [/^No se pudo: (.+)$/, "It didn't work: $1"]
    );
  
    // ---------- F3 · Luminarias que cotiza el supply (referencia y cuota) ----------
    Object.assign(D, {
      // Familias (LUZ_FAMILIAS, línea ~8699: se pintan en esta tarjeta)
      "Cleanroom / sellada": "Cleanroom / sealed", "Unidad de emergencia": "Emergency unit",
      "Downlight / recessed redondo": "Downlight / round recessed", "Strip / wrap / lineal": "Strip / wrap / linear",
      "Un precio mío para este modelo…": "My own price for this model…",
      "$ por unidad": "$ per unit",
      "SIN FAMILIA": "NO FAMILY",
      "Este estimado ya no es un borrador, pero lo que ves aquí se vuelve a calcular con los precios de":
        "This estimate is no longer a draft, but what you see here is recalculated with prices as of",
      ": si cambias un precio de referencia o le enseñas una familia a un modelo, esta pantalla se mueve. El número que se mandó quedó guardado aparte al cerrarlo.":
        ": if you change a reference price or teach a model its family, this screen moves. The number that was sent was saved separately when it was closed.",
      "Tú no pones la luz: pones la mano. Mientras llega la cuota estos renglones valen":
        "You don't supply the fixtures: you supply the labor. Until the quote arrives these lines are worth",
      "y el bid sale corto. Aquí eliges: usar un": "and the bid comes out short. Here you choose: use a",
      "precio de referencia tuyo": "reference price of your own",
      "para tener una cifra, o pegar la": "to have a number, or paste the",
      "cuota de verdad": "real quote",
      "cuando llegue. Nunca salen precios de internet.": "when it arrives. Prices never come from the internet.",
      "elige su familia": "pick its family",
      "en el desplegable de su fila (o dale un precio tuyo). Lo que elijas me lo aprendo para todos tus estimados.":
        "in its row's dropdown (or give it your own price). Whatever you pick, I learn it for all your estimates.",
      "Usar precios de": "Use", "referencia": "reference",
      "en este estimado mientras llega la cuota": "prices on this estimate until the quote arrives",
      "Está": "It's", "encendido": "on", "apagado": "off",
      "REFERENCIA": "REFERENCE",
      ". La cuota sigue pendiente y el aviso de salida lo va a decir.": ". The quote is still pending and the exit check will say so.",
      ": los renglones valen $0 y el bid no incluye la luminaria.": ": the lines are worth $0 and the bid doesn't include the fixtures.",
      "Valen para": "They apply to", "todos": "all",
      "tus estimados. Si uno quedó mal, olvídalo y vuelve a lo automático.": "your estimates. If one is wrong, forget it and it goes back to automatic.",
      "olvidar": "forget",
      "Precios de referencia por familia (los tuyos)": "Reference prices by family (yours)",
      "Guardar los precios": "Save the prices",
      "Valen para todos los estimados. Los de arranque son los que pusiste en el bid de Nicklaus.":
        "They apply to all estimates. The starting ones are the ones you used in the Nicklaus bid.",
      "Pegar la cuota del supply (CED, CES…)": "Paste the supply quote (CED, CES…)",
      "Copia las líneas de la cuota y pégalas tal cual. Busco cada modelo y su precio unitario. Si pegas las dos cuotas,":
        "Copy the quote lines and paste them as they are. I look for each model and its unit price. If you paste both quotes,",
      "me quedo con la más cara": "I keep the more expensive one",
      "Leer la cuota": "Read the quote",
      // Lo que se leyó de la cuota
      "La cuota trae flete": "The quote includes freight",
      "Añadirlo al estimado": "Add it to the estimate",
      "No reconocí ningún modelo de los que esperan cuota. No encontré líneas con precio: revisa que se copiaran los números.":
        "I didn't recognize any of the models waiting for a quote. I found no lines with a price: check that the numbers were copied.",
      "sube": "goes up",
      "la línea trae UN solo importe": "the line has only ONE amount",
      "Nada que cambiar: lo que ya tenías es igual o más caro que esta cuota.":
        "Nothing to change: what you already had is the same or more expensive than this quote.",
      "Ese modelo ya no estaba guardado": "That model wasn't saved anymore",
      "Precios de referencia guardados": "Reference prices saved"
    });
    REGLAS.push(
      // «Automático — Troffer / panel 2x2» / «Automático — no la reconozco»
      [/^Automático — (.+)$/, s => { const f = s.slice(13);
        return "Automatic — " + (f === "no la reconozco" ? "I don't recognize it" : (D[f] !== undefined ? D[f] : f)); }],
      // Opción del desplegable y chip: «Cleanroom / sellada · $550.00», «Downlight / recessed redondo ✎ · $0»
      [/^(Cleanroom \/ sellada|Unidad de emergencia|Downlight \/ recessed redondo|Strip \/ wrap \/ lineal)( ✎)?( · (\$[\d,.]+|\$•••))?( · ¿(\$[\d,.]+|\$•••)\?)?$/, s => {
        const m = s.match(/^(.+?)(( ✎)?( · (\$[\d,.]+|\$•••))?( · ¿(\$[\d,.]+|\$•••)\?)?)$/);
        return D[m[1]] + m[2].replace(/¿(\S+)\?/, "$1?"); }],
      // La línea de cada luminaria pendiente: «12 E × $220.00 de referencia»…
      [/^([\d.]+) (\S+) × (\$[\d,.]+|\$•••) (tuyos|de la familia que elegiste|de referencia)$/, s => {
        const m = s.match(/^([\d.]+) (\S+) × (\S+) (.+)$/);
        const t = { "tuyos": "yours", "de la familia que elegiste": "from the family you picked", "de referencia": "reference" }[m[4]];
        return `${m[1]} ${m[2]} × ${m[3]} ${t}`; }],
      [/^([\d.]+) (\S+) · ⚠ (\$[\d,.]+|\$•••) por unidad no es el precio de una luminaria: revísalo, este renglón NO entra al bid$/,
        "$1 $2 · ⚠ $3 per unit isn't the price of a light fixture: check it, this line is NOT in the bid"],
      [/^([\d.]+) (\S+) · esa familia está a \$0 aquí abajo: ponle precio o dale uno propio a este modelo$/,
        "$1 $2 · that family is at $0 down below: give it a price or give this model its own"],
      [/^([\d.]+) (\S+) · elige su familia aquí abajo, o pega la cuota$/, "$1 $2 · pick its family below, or paste the quote"],
      [/^🔦 Luminarias que cotiza el supply \((\d+)\)$/, "🔦 Fixtures quoted by the supply house ($1)"],
      [/^⚠ (\d+) renglón\(es\) sin precio de referencia:?$/, s => {
        const n = s.match(/\d+/)[0]; return `⚠ ${n} ${n === "1" ? "line" : "lines"} without a reference price:`; }],
      [/^: esos (\S+) entran al bid por donde entran las cotizaciones \(con su markup, sin misceláneas\) y cada renglón se ve marcado$/,
        ": those $1 go into the bid the same way quotes do (with their markup, no misc.) and each line shows marked"],
      [/^Lo que me enseñaste \((\d+) modelo\(s\)\)$/, s => {
        const n = s.match(/\d+/)[0]; return `What you taught me (${n} ${n === "1" ? "model" : "models"})`; }],
      // Vista previa de la cuota
      [/^\((.*)\)\. Ya está en el estimado\.$/, "($1). It's already in the estimate."],
      [/^No reconocí ningún modelo de los que esperan cuota\. Leí (\d+) línea\(s\) con precio pero ninguna se parece a los modelos del estimado\.$/,
        "I didn't recognize any of the models waiting for a quote. I read $1 line(s) with a price but none looks like the estimate's models."],
      [/^cuota: /, s => s.replace(/^cuota: /, "quote: ")
        .replace(/ · había otra a (\$[\d,.]+|\$•••): me quedo con la más cara/, " · there was another one at $1: I keep the more expensive one")
        .replace(/ · ya tenías una a (\$[\d,.]+|\$•••), MÁS CARA: esta no se pone/, " · you already had one at $1, MORE EXPENSIVE: this one isn't used")
        .replace(/ · ⚠ este renglón no se puede editar \(viene de una receta\)$/, " · ⚠ this line can't be edited (it comes from a recipe)")],
      [/^desde la cuota que ya tenías \((\$[\d,.]+|\$•••)\): la más cara manda/, s => s
        .replace(/^desde la cuota que ya tenías \((\S+)\): la más cara manda/, "from the quote you already had ($1): the more expensive one rules")
        .replace(/ · ⚠ este renglón no se puede editar \(viene de una receta\)$/, " · ⚠ this line can't be edited (it comes from a recipe)")],
      [/^: lo tomo como precio de CADA UNA\. Si es el total, cada una sale a (\$[\d,.]+|\$•••) — corrígelo con el lápiz de precio del renglón/, s => s
        .replace(/^: lo tomo como precio de CADA UNA\. Si es el total, cada una sale a (\S+) — corrígelo con el lápiz de precio del renglón/,
          ": I take it as the price of EACH ONE. If it's the total, each one comes to $1 — fix it with the line's price pencil")
        .replace(/ · ⚠ este renglón no se puede editar \(viene de una receta\)$/, " · ⚠ this line can't be edited (it comes from a recipe)")],
      [/^Sin cuota todavía: (.+)$/, "No quote yet: $1"],
      [/^(\d+) línea\(s\) de la cuota no casan con nada del estimado \(otro material, o el modelo está escrito distinto\)\.$/, s => {
        const n = s.match(/\d+/)[0];
        return `${n} quote ${n === "1" ? "line doesn't" : "lines don't"} match anything in the estimate (other material, or the model is written differently).`; }],
      [/^✓ Poner esos (\d+) precio\(s\) en el estimado$/, s => {
        const n = s.match(/\d+/)[0]; return `✓ Put ${n === "1" ? "that price" : `those ${n} prices`} in the estimate`; }],
      [/^🚚 Flete de (\$[\d,.]+|\$•••) añadido al estimado ✓$/, "🚚 Freight of $1 added to the estimate ✓"],
      [/^✓ (\d+) precio\(s\) de la cuota puestos en el estimado$/, s => {
        const n = s.match(/\d+/)[0]; return `✓ ${n} quote ${n === "1" ? "price" : "prices"} put in the estimate`; }],
      // «✓ «MODELO» vale $X de referencia — me lo aprendo · ojo: 2 estimado(s) más usan referencia…»
      [/^✓ «(.+)» (vale (\$[\d,.]+|\$•••) de referencia — me lo aprendo|es (.+) — me lo aprendo para todos los estimados|vuelve a lo automático)( · ojo: (\d+) estimado\(s\) más usan referencia y su número se recalcula)?$/, s => {
        let r = s
          .replace(/» vale (\S+) de referencia — me lo aprendo/, "» is worth $1 as reference — I'll remember it")
          .replace(/» es (.+?) — me lo aprendo para todos los estimados/, (x, f) => `» is ${D[f] !== undefined ? D[f] : f} — I'll remember it for all estimates`)
          .replace(/» vuelve a lo automático/, "» goes back to automatic");
        return r.replace(/ · ojo: (\d+) estimado\(s\) más usan referencia y su número se recalcula$/, (x, n) =>
          ` · careful: ${n} more ${n === "1" ? "estimate uses" : "estimates use"} reference prices and ${n === "1" ? "its" : "their"} number gets recalculated`); }],
      [/^✓ Precios de referencia guardados · (\d+) en blanco: esas familias se quedan con el precio de arranque$/,
        "✓ Reference prices saved · $1 left blank: those families keep the starting price"]
    );
  
    // ---------- F4 · Editor del estimado: renglones, ensambles, avisos y resumen ----------
    Object.assign(D, {
      "Por planos": "From plans", "Remodelación": "Remodel", "Rápido": "Quick",
      "¿Por qué va en $0?": "Why is it at $0?",
      "Cambiar cantidad": "Change quantity",
      "Cambiar el precio en ESTE estimado (el catálogo no se toca)": "Change the price on THIS estimate (the catalog isn't touched)",
      "punto completo": "full point",
      "sin tubo ni cable": "without conduit or wire",
      "— esos los mediste tú en el plano y entran por su lado": "— you measured those on the plan and they go in separately",
      "por circuito": "per circuit",
      "✎ pies": "✎ ft",
      "Escribe la cantidad directa": "Type the quantity directly",
      "Lo que más usas": "What you use most",
      "se llena solo con tu historial": "fills in on its own from your history",
      "Ver menos": "See less",
      // Aviso de renglones a $0
      "El labor cuenta; el material no. Dilo en el selector de cada renglón.": "Labor counts; material doesn't. Say why in each line's selector.",
      // Aviso del overhead
      "El overhead por hora": "Overhead per hour",
      "Tus gastos generales son": "Your overhead expenses are",
      ". Repartidos entre las": ". Spread across the",
      "que pusiste, salen": "you entered, that comes to",
      ". Con las horas apuntadas en la app (": ". With the hours logged in the app (",
      ". Los escenarios usan": ". The scenarios use",
      ", que supone": ", which assumes",
      "Este número todavía no es de fiar.": "This number isn't reliable yet.",
      "Se apuntan menos horas de las que se trabajan. Mientras el equipo no reporte todo, escribe tú abajo las horas facturables que de verdad hacen al mes entre todos.":
        "Fewer hours get logged than get worked. Until the team reports everything, enter below the billable hours everyone actually does in a month.",
      "Horas facturables al mes": "Billable hours per month",
      "Ej: 280": "E.g.: 280",
      "Guardar y recalcular": "Save and recalculate",
      // Cabecera del estimado
      "BORRADOR": "DRAFT", "CONGELADO": "FROZEN", "CONVERTIDO": "CONVERTED",
      "Este número se ha movido desde que lo congelaste.": "This number has moved since you froze it.",
      ". Con los precios y las familias de HOY sale": ". With TODAY's prices and families it comes to",
      "El que ofertaste es el congelado: eso es lo que usa el historial y la propuesta guardada. Si vas a comparar número a número, compara contra el congelado.":
        "What you bid is the frozen one: that's what the history and the saved proposal use. If you're comparing number by number, compare against the frozen one.",
      "Cableado del trabajo (para los conectores automáticos)": "Job wiring (for the automatic connectors)",
      "Mixto": "Mixed",
      "EMT / tubería (THHN) — sin conectores de cable": "EMT / conduit (THHN) — no cable connectors",
      "Cómo va sujeto el tubo (decide la fijación automática)": "How the conduit is supported (sets the automatic fastening)",
      "Parte del tubo que va en trapecio (%)": "Share of the conduit on trapeze (%)",
      "Takeoff de Bluebeam": "Bluebeam takeoff",
      "En Bluebeam: Markups List → Export → CSV. Abre el archivo, copia todo y pégalo aquí.":
        "In Bluebeam: Markups List → Export → CSV. Open the file, copy everything and paste it here.",
      "Analizar": "Analyze",
      "Ensambles — cuenta como piensas": "Assemblies — count the way you think",
      "Los ensambles se siembran al correr el SQL v2.": "Assemblies are seeded when the v2 SQL runs.",
      "Ej: recessed, breaker gfci, 12/2…": "E.g.: recessed, breaker gfci, 12/2…",
      "Crear ítem nuevo en el catálogo": "Create a new catalog item",
      "Reglas de consumibles que no corrieron": "Consumable rules that didn't run",
      "Da de alta esos ítems en el catálogo (docs/sql/e25) y saldrán solos.": "Add those items to the catalog (docs/sql/e25) and they'll show up on their own.",
      "Agrega ensambles, pega el takeoff o busca en el catálogo.": "Add assemblies, paste the takeoff or search the catalog.",
      // Resumen — fórmula
      "Resumen — fórmula Max Power": "Summary — Max Power formula",
      "toca ✎ para jugar con los números": "tap ✎ to play with the numbers",
      "Material (ítems)": "Material (items)", "Material (ítems + automáticos)": "Material (items + automatic)",
      "+ Agregar markup de materiales": "+ Add materials markup",
      "+ Logística, allowances y subcontratos (sin tax ni escalación)": "+ Logistics, allowances and subcontracts (no sales tax or escalation)",
      "PRECIO DE LA PROPUESTA": "PROPOSAL PRICE",
      // Los nombres de cada número del resumen (se usan al tocar ✎)
      "Misceláneas — % del material": "Misc. — % of material",
      "Sales tax — % del material": "Sales tax — % of material",
      "Markup de materiales — % sobre el material con tax": "Materials markup — % on material with tax",
      "Beneficios — % sobre el labor": "Benefits — % on labor",
      "Escalación — subida anual de salarios y material": "Escalation — yearly rise in wages and material",
      "Overhead — % sobre mano de obra + material, sin lo que llega cotizado": "Overhead — % on labor + material, excluding what comes quoted",
      "Overhead — $ por hora-hombre": "Overhead — $ per man-hour",
      "Profit — % sobre costo + overhead": "Profit — % on cost + overhead",
      "Validez de la propuesta — días (con el cobre moviéndose, que sea corta)": "Proposal validity — days (with copper moving, keep it short)",
      // Acciones
      "Trabajo": "Job",
      "(con Roger): usa las tarifas de MXP MEP. Al cliente va la": "(with Roger): it uses MXP MEP's rates. The client gets the",
      "propuesta lump sum": "lump-sum proposal",
      "a nombre de": "in the name of",
      "(sin overhead, profit ni hora cargada).": "(no overhead, profit or loaded hour).",
      "Congélalo": "Freeze it",
      "antes de mandarla: así el número que ofertaste queda guardado aunque cambien los escenarios.":
        "before sending it: that way the number you bid stays saved even if the scenarios change.",
      "Propuesta lump sum para el cliente": "Lump-sum proposal for the client",
      "Resumen interno (con overhead y profit — NO se manda)": "Internal summary (with overhead and profit — NOT sent)",
      "Ver el takeoff para copiar": "View the takeoff to copy",
      "Congelar": "Freeze",
      "Volver a borrador": "Back to draft",
      "Convertir en proyecto (si se gana)": "Convert to a project (if won)",
      "Pasarlo a Max Power": "Move it to Max Power",
      "Generar propuesta": "Generate proposal"
    });
    REGLAS.push(
      // El motivo de un renglón a $0: «12 E material por cotizar · 2.5 h»
      [/^([\d.]+) (\S+ )?(material por cotizar|la cotización ya está en el precio|material del cliente|no lleva material|la tecleas por trabajo|sin precio en el catálogo|nadie ha dicho por qué va en cero|este nombre no está en el catálogo|precio de referencia TUYO: la cuota del supply sigue pendiente|revísalo) · ([\d.]+) h$/, s => {
        const m = s.match(/^([\d.]+) (\S+ )?(.+) · ([\d.]+) h$/);
        const t = { "material por cotizar": "material to be quoted", "la cotización ya está en el precio": "the quote is already in the price",
          "material del cliente": "client's material", "no lleva material": "no material", "la tecleas por trabajo": "you type it per job",
          "sin precio en el catálogo": "no price in the catalog", "nadie ha dicho por qué va en cero": "nobody has said why it's at zero",
          "este nombre no está en el catálogo": "this name isn't in the catalog",
          "precio de referencia TUYO: la cuota del supply sigue pendiente": "YOUR reference price: the supply quote is still pending",
          "revísalo": "check it" }[m[3]];
        return `${m[1]} ${m[2] || ""}${t} · ${m[4]} h`; }],
      [/^— de: (.+)$/, "— from: $1"],
      [/^por unidad \(escenario ([A-Z]|MEP)\)$/, "per unit (scenario $1)"],
      [/^([\d.]+) ft medidos$/, "$1 ft measured"],
      [/^📏 (\S+) ft \(de la receta\) por circuito$/, "📏 $1 ft (from the recipe) per circuit"],
      [/^usado (\d+) (vez|veces) · (.*) · (\$[\d,.]+|\$•••)$/, s => {
        const m = s.match(/^usado (\d+) (?:vez|veces) · (.*) · (\S+)$/);
        return `used ${m[1]} ${m[1] === "1" ? "time" : "times"} · ${m[2]} · ${m[3]}`; }],
      [/^Ver más \((\d+) más\)$/, "See more ($1 more)"],
      // Aviso de renglones sin material
      [/^📦 (\d+) (renglón entra|renglones entran) sin material$/, s => {
        const n = s.match(/\d+/)[0]; return `📦 ${n} ${n === "1" ? "line goes in" : "lines go in"} without material`; }],
      [/^— ([\d.]+) h SÍ están en el precio$/, "— $1 h ARE in the price"],
      [/^· (.+) — (\d+) (renglón|renglones), ([\d.]+) h( ·)?$/, s => {
        const m = s.match(/^· (.+) — (\d+) (?:renglón|renglones), ([\d.]+) h( ·)?$/);
        const sec = { "SIN CATÁLOGO": "NOT IN CATALOG", "AUTOMÁTICOS": "AUTOMATIC", "SIN SECCIÓN": "NO SECTION" }[m[1]] || m[1];
        return `· ${sec} — ${m[2]} ${m[2] === "1" ? "line" : "lines"}, ${m[3]} h${m[4] || ""}`; }],
      [/^(\d+) sin precio de verdad$/, "$1 without a real price"],
      // Aviso del overhead
      [/^(\$[\d,.]+|\$•••) al mes$/, "$1 a month"],
      [/^(\$[\d,.]+|\$•••) por hora$/, "$1 per hour"],
      [/^([\d.]+) horas al mes$/, "$1 hours a month"],
      [/^([\d.]+) al mes$/, "$1 a month"],
      [/^([\d.]+) horas facturables al mes$/, "$1 billable hours a month"],
      [/^, de (\d+) (mes cerrado|meses cerrados)\), saldrían$/, s => {
        const n = s.match(/\d+/)[0]; return `, from ${n} closed ${n === "1" ? "month" : "months"}), it would come to`; }],
      [/^Solo hay (\d+) (mes cerrado|meses cerrados) con horas apuntadas\. Mientras el equipo no reporte todo, escribe tú abajo las horas facturables que de verdad hacen al mes entre todos\.$/, s => {
        const n = s.match(/\d+/)[0];
        return `There ${n === "1" ? "is only 1 closed month" : `are only ${n} closed months`} with logged hours. Until the team reports everything, enter below the billable hours everyone actually does in a month.`; }],
      [/^Poner (\$[\d,.]+|\$•••) en los tres escenarios$/, "Put $1 in all three scenarios"],
      // Cabecera: «Cliente · vía Empresa (contrato con ellos) · 1200 sqft»
      [/^(.*)· vía (.+) \((contrato con ellos|referido)\)((?: · [\d.,]+ sqft)?)$/, s => {
        const m = s.match(/^(.*)· vía (.+) \((contrato con ellos|referido)\)((?: · [\d.,]+ sqft)?)$/);
        return `${m[1]}· via ${m[2]} (${m[3] === "referido" ? "referral" : "contract with them"})${m[4]}`; }],
      [/^Congelado el (\S*):$/, "Frozen on $1:"],
      [/^🔎 Buscar en el catálogo \((\d+)\)$/, "🔎 Search the catalog ($1)"],
      [/^Ítems \((\d+)( \+ (\d+) automáticos)?\)$/, s => {
        const m = s.match(/^Ítems \((\d+)(?: \+ (\d+) automáticos)?\)$/);
        return `Items (${m[1]}${m[2] ? ` + ${m[2]} automatic` : ""})`; }],
      // Filas del resumen
      [/^Material \((\d+) líneas?\)$/, s => { const n = s.match(/\d+/)[0]; return `Material (${n} ${n === "1" ? "line" : "lines"})`; }],
      [/^\+ Merma \(cables ([\d.]+)% · tubería ([\d.]+)%\)$/, "+ Waste (wire $1% · conduit $2%)"],
      [/^\+ Misceláneas \(([\d.]+)%( ✏| — tape, wirenuts, fijación)\)$/, s => {
        const m = s.match(/\(([\d.]+)%( ✏| — tape, wirenuts, fijación)\)$/);
        return `+ Misc. (${m[1]}%${m[2] === " ✏" ? " ✏" : " — tape, wire nuts, fastening"})`; }],
      [/^\+ Markup de materiales \(([\d.]+)%\) ✏$/, "+ Materials markup ($1%) ✏"],
      [/^Horas de TODO el trabajo \(([\d.]+) × factor ([\d.]+)\)$/, "Hours for the WHOLE job ($1 × factor $2)"],
      [/^Labor \(([\d.]+) h × (\$[\d,.]+|\$•••) cuadrilla\)$/, "Labor ($1 h × $2 crew)"],
      [/^\+ Beneficios sobre el labor \(([\d.]+)%( ✏)?\)$/, "+ Benefits on labor ($1%$2)"],
      [/^\+ Escalación \(([\d.]+) meses de obra · ([\d.]+)% al año\)$/, "+ Escalation ($1 months of work · $2% a year)"],
      [/^\+ Overhead \(([\d.]+)% del costo directo(, sin las cotizaciones)?( ✏)?\)$/, s => {
        const m = s.match(/\(([\d.]+)% del costo directo(, sin las cotizaciones)?( ✏)?\)$/);
        return `+ Overhead (${m[1]}% of direct cost${m[2] ? ", excluding quotes" : ""}${m[3] || ""})`; }],
      [/^Propuesta válida por (\d+) días( ✏| ✓)?$/, "Proposal valid for $1 days$2"],
      [/^(\$[\d,.]+|\$•••) por sq ft$/, "$1 per sq ft"]
    );
  
    // ---------- F5 · Acciones del estimado, estimado convertido, lápices de la fórmula, overhead ----------
    Object.assign(D, {
      "Incluir al proyecto": "Add to the project",
      "Convertir en proyecto": "Convert to a project",
      "Armar propuesta para el cliente": "Build the proposal for the client",
      "Pasarlo a MXP MEP": "Move it to MXP MEP",
      "Este estimado ya está incluido en su proyecto": "This estimate is already included in its project",
      "Este estimado ya está convertido en proyecto": "This estimate has already been converted to a project",
      "Este número no está congelado.": "This number isn't frozen.",
      "Se convirtió antes de que se guardara la foto, así que hoy se vuelve a calcular con los precios vivos: si mañana cambia un precio o unas horas del catálogo, el número de este trabajo — que ya vendiste — cambia solo, y el historial compara peras con manzanas.":
        "It was converted before the snapshot was saved, so today it's recalculated with live prices: if a catalog price or hours change tomorrow, this job's number — which you already sold — changes by itself, and the history compares apples to oranges.",
      "Congelar este número": "Freeze this number",
      "Terminado — ir al inicio": "Done — go to the home screen",
      "Ver el proyecto": "View the project",
      "A partir de ahí no vuelve a moverse aunque cambien los precios del catálogo, y el historial lo usa tal cual.":
        "From then on it won't move even if catalog prices change, and the history uses it as is.",
      "¿Lo congelo?": "Freeze it?",
      "Escribe el % (0 = quitarlo · vacío = volver al valor del escenario)": "Type the % (0 = remove it · empty = back to the scenario value)",
      "Escribe el monto en $ (0 = quitarlo · vacío = volver al valor del escenario)": "Type the amount in $ (0 = remove it · empty = back to the scenario value)",
      "Valor no válido": "Invalid value",
      "Los días van de 1 a 365": "Days go from 1 to 365",
      "De vuelta al valor del escenario ✓": "Back to the scenario value ✓",
      "Fórmula ajustada ✓": "Formula adjusted ✓",
      "Falta pegar el SQL docs/sql/e34-validez.sql en Supabase: sin él no se guardan los días":
        "The SQL docs/sql/e34-validez.sql still has to be pasted in Supabase: without it the days aren't saved",
      "No se pudo guardar: corre docs/sql/e27.sql (falta la columna usa_luz_ref)":
        "Couldn't save: run docs/sql/e27.sql (the usa_luz_ref column is missing)",
      "SQL copiado — pégalo en Supabase": "SQL copied — paste it in Supabase",
      "Copia el texto del cuadro de abajo": "Copy the text from the box below",
      "Pon el precio por unidad de esa luminaria (mayor que 0), o déjalo en blanco para volver a lo automático.":
        "Enter that fixture's unit price (greater than 0), or leave it blank to go back to automatic.",
      "Pon las horas facturables de todo el equipo en un mes (entre 40 y 2000).":
        "Enter the whole team's billable hours in a month (between 40 and 2000).",
      "Afecta a TODAS las ofertas nuevas. ¿Seguro?": "It affects ALL new bids. Are you sure?"
    });
    REGLAS.push(
      [/^Congélalo con el número de hoy: (\$[\d,.]+|\$•••) · (\d+) h · (\$[\d,.]+|\$•••) de material\.$/, "Freeze it with today's number: $1 · $2 h · $3 of material."],
      [/^Número congelado el (\S*):$/, "Number frozen on $1:"],
      [/^Se guarda (\$[\d,.]+|\$•••) como el número de este trabajo\.$/, "$1 will be saved as this job's number."],
      [/^Número congelado: (\$[\d,.]+|\$•••) ✓$/, "Number frozen: $1 ✓"],
      [/^Escribe los días \(vacío = volver a (\d+)\):?$/, "Type the days (empty = back to $1):"],
      [/^Guardado: (\d+) horas al mes → (\$[\d,.]+|\$•••) por hora de overhead ✓$/, "Saved: $1 hours a month → $2 per hour of overhead ✓"],
      [/^Esto cambia el overhead de (\$[\d,.]+|\$•••) a (\$[\d,.]+|\$•••) por hora en los tres escenarios\.$/, "This changes the overhead from $1 to $2 per hour in all three scenarios."],
      [/^Este estimado pasaría de (\$[\d,.]+|\$•••) a (\$[\d,.]+|\$•••)\.$/, "This estimate would go from $1 to $2."],
      [/^Overhead puesto en (\$[\d,.]+|\$•••) por hora en los tres escenarios ✓$/, "Overhead set to $1 per hour in all three scenarios ✓"]
    );
  
    // ---------- F6 · Ensambles, catálogo, renglones, $0, MEP, propuesta, congelar y convertir ----------
    Object.assign(D, {
      "¿Cuántos pies de corrida hasta el panel?": "How many feet of run to the panel?",
      "Pies de cable medidos hasta el panel": "Feet of cable measured to the panel",
      "cant.": "qty.",
      "Ponle la cantidad": "Enter the quantity",
      "Nada con ese nombre — prueba otra palabra o crea el ítem nuevo aquí abajo.": "Nothing by that name — try another word or create the new item below.",
      "Nombre del ítem nuevo (como quieres verlo en el catálogo)": "Name of the new item (as you want to see it in the catalog)",
      "Precio por unidad ($)": "Price per unit ($)",
      "Horas de labor por unidad (ej: 0.5)": "Labor hours per unit (e.g. 0.5)",
      "Unidad (E, LF, MLF…)": "Unit (E, LF, MLF…)",
      "Precio u horas no válidos": "Invalid price or hours",
      "Ítem creado en el catálogo ✓ — búscalo y agrégalo": "Item created in the catalog ✓ — search for it and add it",
      "Nueva cantidad": "New quantity",
      "Cantidad no válida": "Invalid quantity",
      "El catálogo no cambia.": "The catalog doesn't change.",
      "Precio no válido": "Invalid price",
      "Ese renglón no tiene sección: dímelo renglón por renglón": "That line has no section: tell me line by line",
      "Ese nombre no está en el catálogo: corrígelo primero": "That name isn't in the catalog: fix it first",
      "Déjalo vacío si todavía no lo sabes": "Leave it empty if you don't know it yet",
      "Este ítem vive dentro de un ENSAMBLE, y los ensambles leen el precio vivo: los estimados congelados o convertidos que lo usen SE VAN A MOVER.":
        "This item lives inside an ASSEMBLY, and assemblies read the live price: frozen or converted estimates that use it WILL MOVE.",
      "Aceptar = ponerlo igual.": "OK = set it anyway.",
      "BY OWNER ✓ — va escrito en el «no incluye» de la propuesta": "BY OWNER ✓ — it's written in the proposal's «not included»",
      "Anotado en el catálogo ✓ — no te vuelve a preguntar": "Noted in the catalog ✓ — it won't ask you again",
      // Pasar a MXP MEP / volver
      "Deja de ser tuyo: sale de tu lista, y la app solo te dará el número. No se borra nada.":
        "It stops being yours: it leaves your list, and the app will only give you the number. Nothing is deleted.",
      "Pasado a MXP MEP ✓ — con sus tarifas": "Moved to MXP MEP ✓ — with its rates",
      "Pasado a MXP MEP ✓": "Moved to MXP MEP ✓",
      "Vuelve a ser tuyo ✓ — con tus tarifas": "It's yours again ✓ — with your rates",
      // Propuesta y takeoff para copiar
      "Resumen INTERNO de MXP MEP — lleva el margen: no se manda al cliente": "INTERNAL MXP MEP summary — it shows the margin: not sent to the client",
      "Propuesta lista para copiar": "Proposal ready to copy",
      "Copiar": "Copy",
      "Propuesta copiada ✓": "Proposal copied ✓",
      "SIN CONGELAR": "NOT FROZEN",
      "Todavía es un borrador: si la mandas, congélalo para que el número quede guardado.": "It's still a draft: if you send it, freeze it so the number stays saved.",
      "Se puede editar aquí antes de copiar (el alcance sobre todo). Lo que cambies aquí no se guarda.":
        "You can edit it here before copying (the scope especially). What you change here isn't saved.",
      "Takeoff copiado ✓ — pégalo en Excel": "Takeoff copied ✓ — paste it in Excel",
      "Congelado a cambios de renglón, pero el NÚMERO no quedó guardado: a la base le faltan las columnas de la foto. Corre max-power-panel/docs/sql/e11-resultado.sql y vuelve a congelar.":
        "Frozen to line changes, but the NUMBER wasn't saved: the database is missing the snapshot columns. Run max-power-panel/docs/sql/e11-resultado.sql and freeze again.",
      "Listo ✓": "Done ✓",
      // Convertir
      "La IA está decidiendo el reparto de los pagos…": "The AI is deciding how to split the payments…",
      "Pagos: los de la propuesta.": "Payments: the ones in the proposal.",
      "Pagos: los decidió la IA.": "Payments: decided by the AI.",
      "Pagos: regla de respaldo.": "Payments: fallback rule."
    });
    REGLAS.push(
      [/^\(el tubo y el cable salen de ahí; deja vacío para usar los (\S+) ft de la receta\)$/, "(the conduit and wire come from that; leave empty to use the recipe's $1 ft)"],
      [/^\(Deja vacío para volver al promedio de (\S+) ft\)$/, "(Leave empty to go back to the $1 ft average)"],
      [/^([\d.]+) × (.+) agregado ✓$/, "$1 × $2 added ✓"],
      [/^No se pudo (agregar|crear|quitar|añadir|convertir|congelar|aplicar|resolver): (.+)$/, s => {
        const m = s.match(/^No se pudo (\S+): (.+)$/);
        const v = { agregar: "add", crear: "create", quitar: "remove", "añadir": "add", convertir: "convert", congelar: "freeze", aplicar: "apply", resolver: "resolve" }[m[1]];
        return `Couldn't ${v}: ${m[2]}`; }],
      [/^(\d+) resultados?$/, s => { const n = s.match(/\d+/)[0]; return `${n} ${n === "1" ? "result" : "results"}`; }],
      [/^Precio unitario de «(.*)» en ESTE estimado \(sin tax\)\.$/, "Unit price of «$1» on THIS estimate (before tax)."],
      [/^Precio (\$[\d,.]+|\$•••) en este estimado ✓ — el catálogo sigue igual$/, "Price $1 on this estimate ✓ — the catalog stays the same"],
      [/^(.+) cotizado ✓ — esos renglones ya no avisan en este trabajo$/, "$1 quoted ✓ — those lines won't warn on this job anymore"],
      [/^Precio por unidad de (.+) \(\$\)\.$/, "Price per unit of $1 ($)."],
      [/^Vas a poner (\$[\d,.]+|\$•••) a "(.*)" en el catálogo\.$/, 'You\'re going to set "$2" to $1 in the catalog.'],
      [/^¿Pasar "(.*)" a MXP MEP\?$/, 'Move "$1" to MXP MEP?'],
      [/^📄 Propuesta de (.+) para el cliente — lump sum, sin desglose$/, "📄 $1 proposal for the client — lump sum, no breakdown"],
      [/^📋 Takeoff para copiar — (\d+) renglones \(pégalo en Excel: cada columna cae en su celda\)$/, s => {
        const n = s.match(/— (\d+)/)[1];
        return `📋 Takeoff to copy — ${n} ${n === "1" ? "line" : "lines"} (paste it in Excel: each column lands in its cell)`; }],
      [/^Estimado congelado 🔒 — (\$[\d,.]+|\$•••) guardado; si los precios cambian, te digo cuánto se movió$/,
        "Estimate frozen 🔒 — $1 saved; if prices change, I'll tell you how much it moved"],
      [/^¿Añadir "(.*)" al proyecto "(.*)"\?$/, 'Add "$1" to the project "$2"?'],
      [/^Sube el contrato en (\$[\d,.]+|\$•••)( \(el número congelado\))?, suma ([\d.]+) h y el material, y crea un hito de pago único por el añadido\.$/, s => {
        const m = s.match(/en (\S+)( \(el número congelado\))?, suma ([\d.]+) h/);
        return `It raises the contract by ${m[1]}${m[2] ? " (the frozen number)" : ""}, adds ${m[3]} h and the material, and creates a single payment milestone for the add-on.`; }],
      [/^Añadido al proyecto ✓ — contrato ahora (\$[\d,.]+|\$•••)$/, "Added to the project ✓ — contract now $1"],
      [/^¿Convierto con la regla de respaldo \((.+)\)\?$/, "Convert with the fallback rule ($1)?"],
      [/^¿Convertir "(.*)" en proyecto\?$/, 'Convert "$1" to a project?'],
      [/^Se crea con contrato (\$[\d,.]+|\$•••)( \(el número congelado\))?, horas estimadas, presupuesto de materiales, (un pago único al terminar|\d+ pagos \([\d. /]+\))( \+ la retención del [\d.]+ % al cierre)? y su alcance por puntos\.$/, s => {
        const m = s.match(/^Se crea con contrato (\S+)( \(el número congelado\))?, horas estimadas, presupuesto de materiales, (un pago único al terminar|(\d+) pagos \(([\d. /]+)\))( \+ la retención del ([\d.]+) % al cierre)? y su alcance/);
        const pagos = m[4] ? `${m[4]} payments (${m[5]})` : "a single payment at the end";
        return `It's created with the contract at ${m[1]}${m[2] ? " (the frozen number)" : ""}, estimated hours, materials budget, ${pagos}${m[6] ? ` + the ${m[7]}% retainage at close-out` : ""} and its scope by items.`; }],
      [/^⚠ (\d+) adjunto\(s\) no pasaron al proyecto: súbelos allí a mano$/, s => {
        const n = s.match(/\d+/)[0];
        return `⚠ ${n} ${n === "1" ? "attachment didn't" : "attachments didn't"} carry over to the project: upload ${n === "1" ? "it" : "them"} there by hand`; }],
      [/^Proyecto creado ✓ — contrato (\$[\d,.]+|\$•••) con hitos, presupuestos y alcance$/, "Project created ✓ — contract $1 with milestones, budgets and scope"]
    );
  
    // ---------- F7 · Vista previa del takeoff de Bluebeam ----------
    Object.assign(D, {
      "SIN MAPEO": "NOT MAPPED",
      "— elige qué hacer —": "— choose what to do —",
      "Crear como ítem nuevo": "Create as a new item",
      "Omitir esta línea": "Skip this line",
      "No encontré líneas — revisa que pegaste el CSV completo con encabezados.": "I found no lines — check that you pasted the full CSV with headers.",
      "Aplicar al estimado": "Apply to the estimate"
    });
    REGLAS.push(
      [/^→ (.+) · ([\d.]+) (\S+ )?\(por (nombre|alias|código)\)$/, s => {
        const m = s.match(/^(.+)\(por (nombre|alias|código)\)$/);
        return m[1] + "(by " + { nombre: "name", alias: "alias", "código": "code" }[m[2]] + ")"; }],
      [/^(.+) — cant\. (\S+)$/, "$1 — qty. $2"],
      [/^Precio por unidad de "(.*)" \(\$\):?$/, 'Price per unit of "$1" ($):'],
      [/^Horas por unidad de "(.*)":?$/, 'Hours per unit of "$1":'],
      [/^Takeoff aplicado ✓ — (\d+) líneas al estimado(, (\d+) mapeos aprendidos)?(, (\d+) omitidas)?$/, s => {
        const m = s.match(/^Takeoff aplicado ✓ — (\d+) líneas al estimado(?:, (\d+) mapeos aprendidos)?(?:, (\d+) omitidas)?$/);
        const pl = (n, a, b) => `${n} ${n === "1" ? a : b}`;
        return `Takeoff applied ✓ — ${pl(m[1], "line", "lines")} to the estimate`
          + (m[2] ? `, ${pl(m[2], "mapping", "mappings")} learned` : "") + (m[3] ? `, ${m[3]} skipped` : ""); }]
    );
  
    // ---------- F8 · Calendario: celdas, panel del día y formulario ----------
    Object.assign(D, {
      "Se hizo — cerrar este día": "Done — close this day",
      "No se hizo — cancelarlo": "Not done — cancel it",
      "Volver a dejarlo abierto": "Reopen it",
      "Eliminar este evento": "Delete this event",
      "Proyecto / trabajo": "Project / job",
      "— General (no es de un proyecto) —": "— General (not for a project) —",
      "Ej: inspección de rough / faltó cable 14/2": "E.g.: rough inspection / short on 14/2 wire",
      "✓ Día cerrado como HECHO": "✓ Day closed as DONE",
      "✗ Día marcado como que NO se hizo": "✗ Day marked as NOT done",
      "↩ Vuelve a estar abierto": "↩ It's open again",
      "¿Eliminar este evento del calendario?": "Delete this event from the calendar?",
      "Evento eliminado ✓": "Event deleted ✓",
      "Pendiente resuelto ✓": "Open item resolved ✓",
      "Pendiente guardado ✓ (en rojo hasta resolverse)": "Open item saved ✓ (in red until resolved)",
      "Evento guardado ✓": "Event saved ✓"
    });
    REGLAS.push(
      [/^\+(\d+) más$/, "+$1 more"],
      // El título del evento es contenido; solo se traduce la marca que le pone el código
      [/^(.+) \(cancelado\)$/, "$1 (canceled)"],
      // La nota que el código pone al crear un evento («Agregado por Edgar Arboleya»)
      [/^Agregado por ([A-ZÁÉÍÓÚÑ][\wáéíóúñ]*(?: [A-ZÁÉÍÓÚÑ][\wáéíóúñ]*)?)$/, "Added by $1"]
    );
  // · parte-G
  // ---------- Parte G: app.js 13261–15482 · calendario (formulario del día), armar propuesta,
  // preparar cierre (plantilla SOW) y «Escribir el alcance» (la hoja · la revisión · el contrato) ----------
  Object.assign(D, {
    // Calendario: el formulario del día y sus avisos
    "Proyecto / trabajo": "Project / job",
    "— General (no es de un proyecto) —": "— General (not for a project) —",
    "Ej: inspección de rough / faltó cable 14/2": "E.g.: rough inspection / short on 14/2 wire",
    "✓ Día cerrado como HECHO": "✓ Day closed as DONE",
    "✗ Día marcado como que NO se hizo": "✗ Day marked as NOT done",
    "↩ Vuelve a estar abierto": "↩ Open again",
    "Listo ✓": "Done ✓",
    "¿Eliminar este evento del calendario?": "Delete this event from the calendar?",
    "Evento eliminado ✓": "Event deleted ✓",
    "Pendiente resuelto ✓": "Open item resolved ✓",
    "Pendiente guardado ✓ (en rojo hasta resolverse)": "Open item saved ✓ (shows in red until resolved)",
    "Evento guardado ✓": "Event saved ✓",
  
    // Armar propuesta
    "No encuentro ese estimado": "I can't find that estimate",
    "Armar propuesta": "Build proposal",
    "Material a mano": "Manual material",
    "Lo esencial": "The essentials", "Fuera": "Out",
    "La que recomiendas": "The one you recommend",
    "cuadra al centavo ✓": "adds up to the cent ✓",
    "no cuadra": "doesn't add up",
    "Reparte las partidas en bloques.": "Split the line items into blocks.",
    "es lo esencial;": "is the essentials;",
    "añade los extras 1;": "adds extras 1;",
    "añade los extras 2. Lo que pongas en": "adds extras 2. Whatever you put in",
    "se queda fuera de todas.": "is left out of all of them.",
    "Este estimado no tiene partidas.": "This estimate has no line items.",
    "Cómo se paga": "How it's paid",
    "editable, no es camisa de fuerza": "editable, not set in stone",
    "La IA está decidiendo el reparto… mientras, va la regla de respaldo.": "The AI is deciding the payment split… meanwhile, the fallback rule applies.",
    "− pago": "− payment", "＋ pago": "＋ payment",
    "Las opciones que verá el cliente": "The options the client will see",
    "La obra y el cliente": "The job and the client",
    "Trato": "Deal",
    "directo con el cliente": "direct with the client",
    "¿A qué proyecto pertenece?": "Which project does it belong to?",
    "— elige el proyecto —": "— choose the project —",
    "para mandarle la copia": "to send them the copy",
    "para mandarle el enlace": "to send them the link",
    "La propuesta vale": "The proposal is valid for",
    "Guardar la propuesta": "Save the proposal",
    "Se guarda con las opciones congeladas: si después retocas el estimado, esta propuesta no se mueve.":
      "It's saved with the options frozen: if you tweak the estimate later, this proposal won't change.",
    "Los pagos tienen que sumar 100%": "The payments must add up to 100%",
    "Elige a qué proyecto pertenece": "Choose which project it belongs to",
    "La opción A no puede quedar vacía": "Option A can't be empty",
    "Guardando…": "Saving…",
  
    // Preparar cierre (la plantilla del SOW)
    "No encuentro esa propuesta": "I can't find that proposal",
    "Preparar cierre": "Prepare closing",
    "Esto llena los huecos de tu plantilla. El texto del alcance y las condiciones los escribes tú como siempre.":
      "This fills in the blanks of your template. You write the scope text and the terms yourself, as always.",
    "Plantilla guardada en este teléfono.": "Template saved on this phone.",
    "Cambiar": "Change",
    "Falta la plantilla": "Template missing",
    "Elige una vez el archivo": "Pick (just once) the file",
    ". Se guarda en este teléfono y no hace falta volver a buscarlo.": ". It's saved on this phone and you won't need to look for it again.",
    "Quién firma": "Who signs",
    "Cliente (quien paga y firma)": "Client (who pays and signs)",
    "Ej: Heather & Lee": "E.g.: Heather & Lee",
    "Segundo firmante": "Second signer",
    "déjalo vacío si solo firma uno": "leave it blank if only one person signs",
    "El otro dueño de la casa": "The other homeowner",
    "Atención / contacto": "Attention / contact",
    "Dueño de la casa": "Homeowner",
    "solo si NO es el cliente": "only if NOT the client",
    "Nombre del proyecto (en inglés)": "Project name (in English)",
    "Jurisdicción (ciudad)": "Jurisdiction (city)",
    "Ej: St. Petersburg": "E.g.: St. Petersburg",
    "Qué va como contrato base": "What goes in as the base contract",
    "Lo que elijas es el": "Whatever you pick is the",
    "del contrato. Las demás salen como opciones que el cliente puede añadir.": "of the contract. The others go out as options the client can add.",
    "Total del contrato": "Contract total",
    "Armar el contrato": "Build the contract",
    "Te baja el HTML con los huecos llenos. Lo terminas de escribir, lo pasas a PDF con WeasyPrint y lo subes al proyecto.":
      "It downloads the HTML with the blanks filled in. You finish writing it, convert it to PDF with WeasyPrint and upload it to the project.",
    "Ese archivo no parece la plantilla del SOW": "That file doesn't look like the SOW template",
    "No cupo en el teléfono. Borra fotos o usa otro navegador.": "It didn't fit on the phone. Delete some photos or use another browser.",
    "Plantilla guardada ✓ — no hace falta volver a buscarla": "Template saved ✓ — no need to look for it again",
    "¿Quitar la plantilla guardada y elegir otra?": "Remove the saved template and pick another one?",
    "Esa propuesta no tiene opciones": "That proposal has no options",
    "Bajado": "Downloaded",
    "No quedó ningún hueco de redacción.": "No drafting blanks left.",
    "Este contrato es con una empresa:": "This contract is with a company:",
    "lleva los tres días para cancelar ni el formulario de cancelación.": "three-day right to cancel and no cancellation form.",
    "Propiedad comercial": "Commercial property",
    "lleva el aviso de gravámenes ni los tres días para cancelar (son solo de un dueño de casa).":
      "lien-law notice and no three-day right to cancel (those only apply to a homeowner).",
    "Si el cliente firmara hoy, podría cancelar hasta la medianoche del": "If the client signed today, they could cancel until midnight on",
    "(tres días hábiles, contando el sábado). El formulario de cancelación con la fecha exacta lo genera el portal al firmar. Los feriados los confirma el abogado.":
      "(three business days, counting Saturday). The portal generates the cancellation form with the exact date at signing. The lawyer confirms holidays.",
    "Contrato armado ✓ — revísalo y pásalo a PDF": "Contract built ✓ — review it and convert it to PDF",
  
    // Escribir el alcance: fichas, variantes y avisos
    "La hoja": "The sheet", "Revisión": "Review",
    "No encuentro ese proyecto": "I can't find that project",
    "Sin nombre todavía": "No name yet",
    "Otro alcance": "Another scope", "del mismo proyecto": "for the same project",
    "Alcance nuevo. Pega la hoja y guárdalo: quedará como otra variante de este proyecto.":
      "New scope. Paste the sheet and save it: it'll be another version of this project.",
    "Modo de prueba: no llamo al asistente": "Test mode: I'm not calling the assistant",
    "El asistente está mirando tu hoja… (suele tardar de 30 s a 2 min; puedes seguir)":
      "The assistant is reading your sheet… (it usually takes 30 s to 2 min; you can keep going)",
    "Llévame a ese renglón": "Take me to that line",
    "y": "and",
    "Precio y pagos: leídos de la": "Price and payments: read from",
    "Precio y pagos: leídos de ninguna línea y la línea": "Price and payments: read from no line and line",
    "Precio y pagos: leídos de ninguna línea y las líneas": "Price and payments: read from no line and lines",
    "y la línea": "and line", "y las líneas": "and lines",
    "Cómo leí tu hoja": "How I read your sheet",
    // Las preguntas de hechos del asistente
    "¿Es propiedad comercial? Si lo es, el contrato sale SIN el aviso de la ley de gravámenes (713.015), SIN los tres días para cancelar y SIN la 9.16 del depósito. Si no contestas, se queda como vivienda, que protege más.":
      "Is it commercial property? If so, the contract goes out WITHOUT the lien-law notice (713.015), WITHOUT the three-day right to cancel and WITHOUT the 9.16 deposit clause. If you don't answer, it stays as a home, which protects more.",
    "Sí, comercial": "Yes, commercial", "No, es una vivienda": "No, it's a home",
    "Sí, con un contratista": "Yes, with a contractor", "No, directo con el dueño": "No, direct with the owner",
    "¿Este documento va con firma o es solo un alcance ligero? Sin firma el contrato sale sin garantía, sin límite de responsabilidad, sin cancelación y sin ninguna cláusula de la sección 9.":
      "Does this document need a signature, or is it just a light scope? Without a signature the contract goes out with no warranty, no limit of liability, no cancellation and none of the section 9 clauses.",
    "Con firma": "With signature", "Solo alcance": "Scope only",
    "Leo que el permiso lo saca el cliente (o su contratista). Si es así, el contrato no cobra el permiso y lo dice claro.":
      "I read that the client (or their contractor) pulls the permit. If so, the contract doesn't charge for the permit and says so clearly.",
    "Leo que este trabajo no lleva permiso. Si es así, el contrato lo dice y no lo cobra.":
      "I read that this job doesn't need a permit. If so, the contract says so and doesn't charge for it.",
    "Sí, lo saca el cliente": "Yes, the client pulls it", "Sí, sin permiso": "Yes, no permit",
    "No, lo sacamos nosotros": "No, we pull it",
    "¿Este trabajo es de servicio exterior (poste, bomba, pozo) o dentro de una vivienda? Si es exterior, el contrato deja de excluir gabinetes, drywall y aparatos, y no lleva la cláusula de los breakers AFCI.":
      "Is this job an exterior service (pole, pump, well) or inside a home? If it's exterior, the contract stops excluding cabinets, drywall and appliances, and leaves out the AFCI breaker clause.",
    "¿Este trabajo es dentro de una vivienda o servicio exterior? Si es dentro de una vivienda, se quedan las exclusiones de gabinetes, drywall y aparatos, y la cláusula de los breakers AFCI.":
      "Is this job inside a home or an exterior service? If it's inside a home, the cabinet, drywall and appliance exclusions stay, along with the AFCI breaker clause.",
    "Exterior (servicio)": "Exterior (service)", "Vivienda interior": "Home interior", "Las dos cosas": "Both",
    "¿El dueño de la propiedad es este? Hace falta para el Notice to Owner y para la fila Homeowner del contrato.":
      "Is this the property owner? It's needed for the Notice to Owner and for the Homeowner row of the contract.",
    "Sí, ese es el dueño": "Yes, that's the owner",
    "¿Firma también esta segunda persona? Si firma, sale en el contrato y en el portal como segundo firmante.":
      "Does this second person sign too? If so, they appear in the contract and in the portal as second signer.",
    "Sí, firman las dos": "Yes, both sign",
    "Guardarlo también en la ficha del proyecto (propiedad comercial)": "Also save it in the job file (commercial property)",
    "Guardarlo también en la ficha del proyecto (el contrato es con el contratista)": "Also save it in the job file (the contract is with the contractor)",
    "Guardado en la ficha del proyecto ✓": "Saved in the job file ✓",
    // Ficha 1: la hoja
    "Pega aquí el alcance como te salga: dictado, un SOW viejo, o la hoja con sus títulos. Toca":
      "Paste the scope here however it comes out: dictated, an old SOW, or the sheet with its headings. Tap",
    "Leer": "Read",
    ": la app la lee al instante con sus reglas y saca el dinero con sus propias cuentas; después el asistente la mira por su cuenta y te dice lo que vio. Puedes seguir trabajando mientras tanto.":
      ": the app reads it instantly with its rules and works out the money with its own math; then the assistant looks it over on its own and tells you what it saw. You can keep working meanwhile.",
    "También puedes arrastrar el archivo encima del cuadro.": "You can also drag the file onto the box.",
    "Importar un archivo": "Import a file",
    "Copiar el formato en blanco": "Copy the blank format",
    "Reacomodar el texto (lo reescribe)": "Rearrange the text (rewrites it)",
    "Ojo: reacomodar reescribe tu hoja entera. Léela después.": "Heads up: rearranging rewrites your whole sheet. Read it afterward.",
    "Leer con el asistente": "Read with the assistant",
    "siempre": "always", "solo cuando la hoja viene rara": "only when the sheet looks odd", "nunca": "never",
    "Cuando toques «Leer», aquí sale lo que la app entendió.": "When you tap «Read», what the app understood shows up here.",
    "escríbelo": "write it",
    "No, escribir otro precio": "No, enter another price",
    "o explícame por qué está bien así (ej.: es el año de la casa)": "or tell me why it's fine as is (e.g.: it's the year the house was built)",
    "Déjalo así": "Leave it as is",
    "Es un renglón": "It's a line item", "Es detalle del renglón de arriba": "It's a detail of the item above", "Déjala": "Leave it",
    "IA": "AI",
    "Arreglado": "Fixed",
    "Lo que ya me explicaste (lo respeto)": "What you already explained to me (I respect it)",
    "Hay que arreglar esto antes de seguir": "This needs fixing before you continue",
    "Arreglar todo lo que pueda solo": "Fix everything I can on my own",
    "Esto no me cuadra del todo (no te frena)": "Something here doesn't quite add up (it won't stop you)",
    "ver el que queda": "see the one left",
    "Lo que dejé fuera o ya trae la plantilla — no tienes que hacer nada": "What I left out or the template already has — nothing for you to do",
    "Contéstame esto": "Answer me this",
    "tu respuesta": "your answer", "Poner la respuesta": "Enter the answer",
    // «Lo que entendí»
    "Lo que entendí": "What I understood",
    "contrato con una empresa (GC)": "contract with a company (GC)", "directo con el dueño": "direct with the owner",
    "Documento": "Document", "propuesta con firma": "proposal with signature", "alcance ligero": "light scope",
    "Permiso": "Permit", "lo sacamos nosotros": "we pull it", "lo saca el cliente": "the client pulls it", "no hace falta": "not needed",
    "Ciudad": "City", "Vale": "Valid",
    "Tipo de trabajo": "Type of work",
    "servicio exterior": "exterior service", "dentro de una vivienda": "inside a home", "obra nueva": "new construction",
    "por planos": "from plans", "trabajo corto": "short job", "las dos cosas": "both",
    "lo dice la": "stated on",
    "renglón": "item", "renglones": "items",
    "exclusión propia": "own exclusion", "exclusiones propias": "own exclusions",
    "Precio base": "Base price",
    "Si el cliente lo toma todo": "If the client takes everything",
    "El cliente puede tomar los añadidos que quiera, sueltos o juntos. Los pagos se recalculan sobre lo que acepte.":
      "The client can take any add-ons they want, one by one or together. Payments are recalculated on what they accept.",
    "Ojo — propiedad comercial": "Heads up — commercial property",
    "sale": "it goes out", "SIN": "WITHOUT",
    "el aviso de la ley de gravámenes (713.015 es solo para viviendas de hasta 4 unidades),": "the lien-law notice (713.015 only applies to homes of up to 4 units),",
    "los tres días para cancelar (501.021 es solo para consumidores) y": "the three-day right to cancel (501.021 only applies to consumers) and",
    "la 9.16 del depósito (489.126 es solo residencial). El cliente puede cancelar por escrito pagando lo hecho. Si en realidad es una casa, pon «Property: residential» en la hoja.":
      "the 9.16 deposit clause (489.126 is residential only). The client can cancel in writing by paying for work done. If it's actually a house, put «Property: residential» on the sheet.",
    "Ojo — este contrato es entre dos empresas": "Heads up — this contract is between two companies",
    "el aviso de la ley de gravámenes y": "the lien-law notice and",
    "los tres días para cancelar (esos dos son solo de un dueño de casa), y con la retención, el Notice to Owner y las liberaciones de gravamen. Si quien va a firmar es el dueño de la casa, cambia la obra a «Solo coordinan» en la ficha del proyecto antes de armar el contrato.":
      "the three-day right to cancel (those two only apply to a homeowner), and with retainage, the Notice to Owner and lien releases. If the person signing is the homeowner, switch the job to «Coordination only» in the job file before building the contract.",
    "Ajustado a este trabajo": "Tailored to this job",
    "Cláusulas que van a salir": "Clauses that will be included",
    "va siempre": "always included",
    "Solo salen las cláusulas que van siempre.": "Only the always-included clauses go in.",
    "Pasarlo a inglés con el asistente": "Translate it to English with the assistant",
    "Usarlo tal cual": "Use it as is",
    "Revisar y armar": "Review and build",
    "Guardar los cambios": "Save the changes",
    "Guardar este alcance": "Save this scope",
    "Esto no está todo en inglés y el contrato sale en inglés. Lo normal es pedirle al chat el alcance ya en inglés e importarlo; si no, el asistente lo pasa.":
      "This isn't all in English and the contract goes out in English. Usually you ask the chat for the scope already in English and import it; otherwise, the assistant translates it.",
    // Los nombres de las cláusulas (chips)
    "garantía": "warranty", "cosas existentes": "existing conditions", "panel sin fotos": "panel without photos",
    "breakers AFCI": "AFCI breakers", "estado del sitio": "site conditions", "reúso del 240V": "240V reuse",
    "reubicar": "relocation", "isla": "island", "ediciones del alcance": "scope edits",
    "aberturas": "openings", "lámparas del cliente": "client's light fixtures", "lámparas nuestras": "our light fixtures",
    "excavación": "excavation", "planos del permiso": "permit drawings",
    "correcciones del inspector al sistema existente": "inspector corrections to the existing system",
    "órdenes de cambio": "change orders", "retención": "retainage",
    "Notice to Owner y liberaciones de gravamen": "Notice to Owner and lien releases",
    "límite de responsabilidad": "limit of liability", "seguro": "insurance", "depósito y arranque": "deposit and start",
    "cancelación después de los 3 días": "cancellation after the 3 days", "cancelación (sin los 3 días)": "cancellation (without the 3 days)",
    "condiciones propias de este trabajo": "terms specific to this job",
    // Ficha 2: la revisión
    "Todavía no hay nada que revisar. Vuelve a la hoja y toca «Revisar y armar».": "Nothing to review yet. Go back to the sheet and tap «Review and build».",
    "Esto es lo que va al contrato, trozo a trozo, tal como lo escribiste. Si cambias algo aquí, se guarda tal cual; si prefieres, vuelve a la hoja y corrígelo allí.":
      "This is what goes into the contract, piece by piece, just as you wrote it. If you change something here, it's saved as is; if you prefer, go back to the sheet and fix it there.",
    "A la izquierda lo que tú escribiste, a la derecha el inglés que sale al cliente. Cámbialo si hace falta: lo que corrijas se guarda tal cual.":
      "On the left, what you wrote; on the right, the English that goes to the client. Change it if needed: whatever you fix is saved as is.",
    "Nombre del trabajo": "Job name", "De qué va": "What it's about", "Cambia": "Changes",
    "Resumen del precio": "Price summary", "Áreas": "Areas", "No tocamos": "We don't touch",
    "Listo antes del rough": "Ready before rough-in", "Fases": "Phases", "Acceso": "Access",
    "Fixtures del cliente": "Client fixtures", "Fixtures nuestros": "Our fixtures", "Aberturas": "Openings",
    "El asistente tiene dudas": "The assistant has questions",
    "Te avisa de esto": "It flags this",
    "Volver a la hoja": "Back to the sheet",
    "Redactar de nuevo": "Draft again",
    // Ficha 3: el contrato
    "Toca «Armar el contrato» en la revisión.": "Tap «Build the contract» in the review.",
    "Contrato armado": "Contract built",
    "No lo bajé: hay algo que revisar.": "I didn't download it: something needs checking.",
    "Pasó el repaso: no quedó ningún hueco y cada monto del papel es uno de los que calculé yo.":
      "It passed the check: no blanks left, and every amount on the paper is one I calculated.",
    "La sección 9 quedó así": "Section 9 ended up like this",
    "Contrato con una empresa:": "Contract with a company:",
    "lleva los tres días para cancelar ni el formulario de cancelación, y el certificado de la firma dirá a nombre de qué empresa se firmó.":
      "three-day right to cancel and no cancellation form, and the signature certificate will say which company signed.",
    "lleva el aviso de gravámenes ni los tres días para cancelar ni el formulario de cancelación. Puedes pedir material y el permiso en cuanto firme.":
      "lien-law notice, no three-day right to cancel and no cancellation form. You can order material and pull the permit as soon as they sign.",
    "(tres días hábiles, contando el sábado). El formulario con la fecha exacta lo genera el portal al firmar.":
      "(three business days, counting Saturday). The portal generates the form with the exact date at signing.",
    "Imprimir a PDF": "Print to PDF",
    "Bajar el contrato (.html)": "Download the contract (.html)",
    "Guardar en la propuesta": "Save to the proposal",
    "Ya está en el portal del cliente ✓": "It's already in the client portal ✓",
    "Mandar por email": "Send by email", "Mandar por texto": "Send by text", "Copiar el enlace": "Copy the link",
    "Esta obra la firma": "This job is signed by",
    ", no un dueño de casa: el enlace y la invitación van a su portal de contratista. Email:":
      ", not a homeowner: the link and the invitation go to their contractor portal. Email:",
    ", no un dueño de casa: el enlace y la invitación van a su portal de contratista. No tiene email anotado: al tocar «Mandar por email» te lo pido y lo guardo.":
      ", not a homeowner: the link and the invitation go to their contractor portal. They have no email on file: when you tap «Send by email» I'll ask you for it and save it.",
    ". Se abre tu correo (o tus mensajes) con el texto y el enlace ya escritos; solo tienes que darle a enviar.":
      ". Your email (or your messages) opens with the text and the link already written; you just have to hit send.",
    "El proyecto no tiene email del cliente: al tocar «Mandar por email» te lo pido y lo guardo. Se abre tu correo (o tus mensajes) con el texto y el enlace ya escritos; solo tienes que darle a enviar.":
      "The project has no client email: when you tap «Send by email» I'll ask you for it and save it. Your email (or your messages) opens with the text and the link already written; you just have to hit send.",
    "Terminado — mandar la invitación e ir al proyecto": "Done — send the invitation and go to the project",
    "Si cambiaste algo y quieres subir otra versión, dímelo: hay que retirar la anterior primero para que el cliente no vea dos.":
      "If you changed something and want to upload another version, tell me: the previous one has to be withdrawn first so the client doesn't see two.",
    "Mandárselo al cliente": "Send it to the client",
    "1) Toca": "1) Tap",
    ": se abre el contrato con la ventana de imprimir. Elige": ": the contract opens with the print window. Choose",
    "Guardar como PDF": "Save as PDF",
    "(marca «Background graphics» si te lo ofrece) y guárdalo. 2) Toca": "(check «Background graphics» if it's offered) and save it. 2) Tap",
    "Subir el PDF al portal": "Upload the PDF to the portal",
    "y elige ese archivo: queda enlazado a este alcance y le sale al cliente en su portal para elegirlo y firmarlo.":
      "and pick that file: it gets linked to this scope and shows up in the client's portal to choose and sign.",
    "Guarda primero el alcance.": "Save the scope first.",
    // Los avisos de los botones
    "Formato copiado ✓ — pégalo en Notas": "Format copied ✓ — paste it into Notes",
    "Te lo puse en el cuadro": "I put it in the box for you",
    "Apagado: leeré solo con las reglas": "Off: I'll read with the rules only",
    "Solo llamaré al asistente cuando la hoja venga rara": "I'll only call the assistant when the sheet looks odd",
    "Llamaré al asistente cada vez que leas una hoja nueva": "I'll call the assistant every time you read a new sheet",
    "No había nada que pudiera arreglar solo": "There was nothing I could fix on my own",
    "Se pierden las correcciones que hiciste a mano. ¿Sigo?": "The corrections you made by hand will be lost. Continue?",
    "Se abre tu correo con el mensaje listo: dale a enviar": "Your email opens with the message ready: hit send",
    "Se abren tus mensajes con el texto listo": "Your messages open with the text ready",
    "Se abren tus mensajes: pon el número del cliente": "Your messages open: enter the client's number",
    "Email del cliente para mandarle la invitación al portal:": "Client email to send the portal invitation to:",
    "Mandando la invitación…": "Sending the invitation…",
    "Listo ✓ — el contrato está en el portal del contratista": "Done ✓ — the contract is in the contractor's portal",
    "Listo ✓ — el contrato está en el portal del cliente": "Done ✓ — the contract is in the client's portal",
    "El contrato está en el portal, pero el email no salió": "The contract is in the portal, but the email didn't go out",
    "Puedes mandarle el enlace con «Mandar por email» o «Copiar el enlace».": "You can send them the link with «Send by email» or «Copy the link».",
    "Enlace copiado ✓ — pégaselo al cliente": "Link copied ✓ — paste it to the client",
    "Ese archivo no es de texto. Guárdalo como .txt o .md y vuelve a intentarlo.": "That file isn't text. Save it as .txt or .md and try again.",
    "Ese archivo es muy grande para una hoja de alcance": "That file is too big for a scope sheet",
    "El archivo está vacío": "The file is empty",
    "Ya hay algo escrito en el cuadro. ¿Lo reemplazo con el archivo?": "There's already something written in the box. Replace it with the file?",
    "No pude abrir ese archivo": "I couldn't open that file"
  });
  
  REGLAS.push(
    // Avisos con el error detrás
    [/^No se pudo: (.+)$/, "It didn't work: $1"],
    [/^No se pudo resolver: (.+)$/, "Couldn't resolve it: $1"],
    [/^No se pudo guardar: (.+)$/, "Couldn't save: $1"],
    [/^No pude guardarlo en el proyecto: (.+)$/, "I couldn't save it to the project: $1"],
    [/^No pude guardar en el proyecto: (.+)$/, "I couldn't save to the project: $1"],
    [/^No pude preparar el email: (.+)$/, "I couldn't prepare the email: $1"],
    [/^No pude preparar el texto: (.+)$/, "I couldn't prepare the text: $1"],
    [/^No pude sacar el enlace: (.+)$/, "I couldn't get the link: $1"],
    [/^(.+) — va la regla de respaldo$/, "$1 — using the fallback rule"],
    // Calendario: la nota que la app le pone al evento
    [/^Agregado por (\S.{0,40})$/, "Added by $1"],
    // Armar propuesta
    [/^IA · ([\d.]+(?: \/ [\d.]+)+)$/, "AI · $1"],
    [/^a mano · (-?\$[\d,.]+|\$•••)(?: · (cotización|logística|allowance|subcontrato))?$/, s => {
      const m = s.match(/^a mano · (-?\$[\d,.]+|\$•••)(?: · (cotización|logística|allowance|subcontrato))?$/);
      const T = { "cotización": "vendor quote", "logística": "logistics", "allowance": "allowance", "subcontrato": "subcontract" };
      return "manual · " + m[1] + (m[2] ? " · " + T[m[2]] : "");
    }],
    [/^hoy aparta (-?\$[\d,.]+|\$•••)$/, "$1 today to reserve"],
    [/^([\d.]+)% · (-?\$[\d,.]+|\$•••) \(depósito\)$/, "$1% · $2 (deposit)"],
    [/^(\d+) partidas?( · además de lo anterior)?$/, s => {
      const m = s.match(/^(\d+) partidas?( · además de lo anterior)?$/); const n = +m[1];
      return n + (n === 1 ? " line item" : " line items") + (m[2] ? " · on top of the previous one" : "");
    }],
    [/^Lo decidió la IA: (.+)$/, "The AI decided: $1"],
    [/^Pago (\d+)( \(depósito\))?( — [\d.]+%)?( \(depósito\))?$/, s => s
      .replace(/^Pago /, "Payment ").replace(/ \(depósito\)/g, " (deposit)")],
    [/^Suman ([\d.]+)%( ✓)?$/, "Total $1%$2"],
    [/^Suman ([\d.]+)% — tienen que sumar 100$/, "Total $1% — must add up to 100"],
    // «Trato: …» — lo que va detrás del nombre del contratista
    [/^(?:· cliente (.+?))?\.(?: (El contrato saldrá a nombre del contratista, sin las páginas de dueño de casa\.|El contratista coordina; el dueño firma y paga\.))?$/, s => {
      const m = s.match(/^(?:· cliente (.+?))?\.(?: (El contrato saldrá a nombre del contratista, sin las páginas de dueño de casa\.|El contratista coordina; el dueño firma y paga\.))?$/);
      const T = { "El contrato saldrá a nombre del contratista, sin las páginas de dueño de casa.": "The contract will be in the contractor's name, without the homeowner pages.",
                  "El contratista coordina; el dueño firma y paga.": "The contractor coordinates; the owner signs and pays." };
      return (m[1] ? "· client " + m[1] : "") + "." + (m[2] ? " " + T[m[2]] : "");
    }],
    [/^(\d+) días$/, "$1 days"],
    [/^Propuesta guardada con (\d+) opci(ón|ones) ✓$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `Proposal saved with ${n} ${n === 1 ? "option" : "options"} ✓`; }],
    // Preparar cierre
    [/^Opción ([A-H]) — (.+)$/, "Option $1 — $2"],
    [/^El depósito es el ([\d.]+)% \(más del 10%\): el contrato lleva la cláusula 9\.16 con los plazos de permiso y arranque que exige la ley\.$/,
      "The deposit is $1% (over 10%): the contract includes clause 9.16 with the permit and start deadlines the law requires."],
    [/^· propuesta (\S+) · vale hasta (.+)$/, "· proposal $1 · valid until $2"],
    [/^Te falta escribir (\d+) huecos?$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `You still need to fill in ${n} ${n === 1 ? "blank" : "blanks"}`; }],
    // Escribir el alcance: variantes
    [/^(borrador|enviada|FIRMADA|vencida|cambio pedido|no elegida|ELEGIDA por el cliente)( · -?\$[\d,.]+)?$/, s => {
      const m = s.match(/^(borrador|enviada|FIRMADA|vencida|cambio pedido|no elegida|ELEGIDA por el cliente)( · -?\$[\d,.]+)?$/);
      const T = { "borrador": "draft", "enviada": "sent", "FIRMADA": "SIGNED", "vencida": "expired", "cambio pedido": "change requested",
                  "no elegida": "not chosen", "ELEGIDA por el cliente": "CHOSEN by the client" };
      return T[m[1]] + (m[2] || "");
    }],
    [/^Este proyecto tiene (\d+) alcances\. Estás en el que está marcado; toca otro para verlo entero\.$/,
      "This project has $1 scopes. You're on the highlighted one; tap another to see it in full."],
    // «Volver a leer…» — OJO: hoy no llega aquí (la regla general «Volver a …» se lo come antes; ver notas-G)
    [/^Volver a leer con inteligencia \((≈ \d+ ¢)\)$/, "Read again with AI ($1)"],
    // Cómo leí tu hoja
    [/^línea (\d+)$/, "line $1"],
    [/^(hoja de la casa|SOW de los nuestros|SOW hecho para un contratista|texto suelto|hoja mezclada|hoja) ?(en inglés|en español|con partes en inglés y en español)?\.$/, s => {
      const m = s.match(/^(hoja de la casa|SOW de los nuestros|SOW hecho para un contratista|texto suelto|hoja mezclada|hoja) ?(en inglés|en español|con partes en inglés y en español)?\.$/);
      const F = { "hoja de la casa": "House-format sheet", "SOW de los nuestros": "One of our SOWs", "SOW hecho para un contratista": "SOW made for a contractor",
                  "texto suelto": "Loose text", "hoja mezclada": "Mixed sheet", "hoja": "Sheet" };
      const I = { "en inglés": "in English", "en español": "in Spanish", "con partes en inglés y en español": "with parts in English and Spanish" };
      return F[m[1]] + (m[2] ? " " + I[m[2]] : "") + ".";
    }],
    [/^Cabecera: (\d+) datos?\.$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `Header: ${n} ${n === 1 ? "field" : "fields"}.`; }],
    [/^Alcance: (\d+) (renglón|renglones)(?: en (\d+) (?:grupo|grupos) — (.*)|\.)$/, s => {
      const m = s.match(/^Alcance: (\d+) (renglón|renglones)(?: en (\d+) (?:grupo|grupos) — (.*)|\.)$/);
      const n = +m[1], it = n === 1 ? "item" : "items";
      if (m[3] === undefined) return `Scope: ${n} ${it}.`;
      const g = +m[3];
      return `Scope: ${n} ${it} in ${g} ${g === 1 ? "group" : "groups"} — ${m[4]}`;
    }],
    [/^No incluye: (\d+) propias?(?: · (\d+) que la plantilla ya trae)?\.$/, s => {
      const m = s.match(/^No incluye: (\d+) propias?(?: · (\d+) que la plantilla ya trae)?\.$/);
      return `Exclusions: ${m[1]} of your own` + (m[2] ? ` · ${m[2]} already in the template` : "") + ".";
    }],
    [/^Cronograma, antes de empezar y condiciones propias de tu hoja: (\d+)\.$/, "Schedule, before-you-start and your sheet's own terms: $1."],
    [/^Lo que dejé fuera: (\d+) líneas? \(membrete, rayas, firmas\)\.$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `What I left out: ${n} ${n === 1 ? "line" : "lines"} (letterhead, rules, signatures).`; }],
    [/^Leído con: reglas · asistente \((ya la tenía leída de antes \(0 ¢\)|\S+ ¢|sin apuntar el costo)( · [^)]+)?\)\.$/, s => {
      const m = s.match(/^Leído con: reglas · asistente \((ya la tenía leída de antes \(0 ¢\)|\S+ ¢|sin apuntar el costo)( · [^)]+)?\)\.$/);
      const c = m[1] === "sin apuntar el costo" ? "cost not recorded" : /^ya la tenía/.test(m[1]) ? "I already had it read from before (0 ¢)" : m[1];
      return `Read with: rules · assistant (${c}${m[2] || ""}).`;
    }],
    [/^Tiré (\d+) (pieza que no cuadraba|piezas que no cuadraban) con tu hoja; esas líneas las leí con las reglas\.$/, s => {
      const n = parseInt(s.replace(/\D+/g, " ").trim(), 10);
      return `I threw out ${n} ${n === 1 ? "piece that didn't match" : "pieces that didn't match"} your sheet; I read those lines with the rules.`;
    }],
    // Las preguntas de hechos con nombre dentro
    [/^Parece un contrato con un contratista(?: \((.+)\))?\. Si lo es, el contrato entra con retención, Notice to Owner y liberaciones de gravamen, firma solo el contratista, y sale sin el aviso de gravámenes ni los tres días del consumidor\.$/, s => {
      const m = s.match(/^Parece un contrato con un contratista(?: \((.+)\))?\./);
      return `It looks like a contract with a contractor${m[1] ? " (" + m[1] + ")" : ""}. If so, the contract comes with retainage, Notice to Owner and lien releases, only the contractor signs, and it goes out without the lien-law notice or the consumer's three days.`;
    }],
    [/^Sí, con (.+)$/, "Yes, with $1"],
    [/^escribí «(.+)» en la hoja$/, "I wrote «$1» on the sheet"],
    // Ficha 1: la hoja
    [/^Sí, usar el del estimado (\S+): (\$[\d,.]+)$/, "Yes, use the one from estimate $1: $2"],
    [/^La línea (\d+) es nueva desde que el asistente leyó la hoja; mientras tanto la leo con las reglas\. ¿Qué es\?$/,
      "Line $1 is new since the assistant read the sheet; meanwhile I'm reading it with the rules. What is it?"],
    [/^(.+) El estimado (\S+) de este proyecto da (\$[\d,.]+)\. ¿Apruebas ese precio\?$/, s => {
      const m = s.match(/^(.+) El estimado (\S+) de este proyecto da (\$[\d,.]+)\. ¿Apruebas ese precio\?$/);
      const antes = Object.prototype.hasOwnProperty.call(D, m[1]) ? D[m[1]] : m[1];
      return `${antes} The estimate ${m[2]} for this project comes to ${m[3]}. Do you approve that price?`;
    }],
    [/^ver los (\d+) restantes$/, "see the $1 remaining"],
    // «Lo que entendí»
    [/^(\d+) días? \(hasta (.+)\)$/, s => { const m = s.match(/^(\d+) días? \(hasta (.+)\)$/); return `${m[1]} ${m[1] === "1" ? "day" : "days"} (until ${m[2]})`; }],
    [/^Asistente: (.+)$/, s => {
      const partes = s.slice("Asistente: ".length).split(" · ");
      const en = partes.map(p => {
        if (p === "esta hoja ya la tenía leída de antes (0 ¢)") return "I already had this sheet read from before (0 ¢)";
        let m = p.match(/^(\S+) ¢ esta lectura$/); if (m) return `${m[1]} ¢ this read`;
        m = p.match(/^este mes (\$[\d,.]+) de (\$[\d,.]+)$/); if (m) return `this month ${m[1]} of ${m[2]}`;
        return null;
      });
      return en.every(x => x !== null) ? "Assistant: " + en.join(" · ") : s;
    }],
    [/^ojo, ya vas por el ([\d.]+) % del mes$/, "heads up, you're already at $1% of the monthly cap"],
    [/^\((\d+) detalles?\)$/, s => { const n = parseInt(s.slice(1), 10); return `(${n} ${n === 1 ? "detail" : "details"})`; }],
    [/^Añadido ([A-Z]) — detalles$/, "Add-on $1 — details"],
    [/^Añadido ([A-Z]) — (.+)$/, "Add-on $1 — $2"],
    // «Ajustado a este trabajo:» — frases fijas con títulos de la hoja dentro
    [/^(No van estas exclusiones genéricas|De la hoja entran a la sección 9|Al cronograma \(sección 7\) entran|La sección 8 es la de la hoja|A los pagos \(sección 6\) entran)/, s => {
      const EX = { "trabajo de panel": "panel work", "arc-fault": "arc-fault", "luces de gabinete": "cabinet lights", "drywall y parches": "drywall and patching",
                   "low-voltage": "low-voltage", "aparatos y gas": "appliances and gas", "correcciones del inspector": "inspector corrections", "fuera de las áreas": "outside the areas" };
      return s
        .replace(/No van estas exclusiones genéricas porque no cuadran con este alcance: ([^.]*)\./, (x, l) =>
          "These generic exclusions are left out because they don't fit this scope: " + l.split(", ").map(k => EX[k] || k).join(", ") + ".")
        .replace("De la hoja entran a la sección 9 sus condiciones propias: ", "The sheet's own terms go into section 9: ")
        .replace("Al cronograma (sección 7) entran: ", "Going into the schedule (section 7): ")
        .replace(/La sección 8 es la de la hoja \((\d+) puntos\), no la de aprobación de layout\./, "Section 8 is the sheet's ($1 points), not the layout-approval one.")
        .replace("A los pagos (sección 6) entran: ", "Going into the payments (section 6): ");
    }],
    [/^Por qué: (.+)$/, "Why: $1"],
    // Ficha 2: la revisión
    [/^Renglón (\d+) — título$/, "Item $1 — title"],
    [/^Renglón (\d+) — detalles$/, "Item $1 — details"],
    [/^No incluye (\d+)$/, "Exclusion $1"],
    // Ficha 3: el contrato
    [/^9\.(\d+) (.+)$/, s => { const m = s.match(/^9\.(\d+) (.+)$/); return Object.prototype.hasOwnProperty.call(D, m[2]) ? `9.${m[1]} ${D[m[2]]}` : s; }],
    [/^(.+) está subido y esperando la firma\. Mándale el enlace al cliente: desde la ficha del proyecto, o con el botón de abajo\.$/, s => {
      const t = s.match(/^(.+) está subido/)[1];
      return `${t === "El contrato" ? "The contract" : t} is uploaded and waiting for signature. Send the client the link: from the job file, or with the button below.`;
    }],
    [/^Al tocar «Terminado», la app le manda sola al cliente el email de invitación a su portal \(con el enlace y las opciones que haya\) desde info@mxpes\.com, y lo apunta en el proyecto\.(?: Ya se le mandó una el (\S+); si tocas otra vez, se le manda de nuevo\.)?$/, s => {
      const m = s.match(/Ya se le mandó una el (\S+);/);
      return "When you tap «Done», the app automatically sends the client the invitation email to their portal (with the link and any options) from info@mxpes.com, and logs it in the project." +
        (m ? ` One was already sent on ${m[1]}; if you tap again, it's sent again.` : "");
    }],
    // Los avisos de los botones
    [/^Arreglé (\d+) cosas? ✓$/, s => { const n = parseInt(s.replace(/\D+/g, " ").trim(), 10); return `I fixed ${n} ${n === 1 ? "thing" : "things"} ✓`; }],
    [/^Email de (.+) para mandarle la invitación a su portal:$/, "$1's email to send the invitation to their portal:"],
    [/^Invitación enviada a (\S+) ✓$/, "Invitation sent to $1 ✓"],
    [/^El enlace del cliente: (https?:\/\/\S+)$/, "The client link: $1"],
    [/^Cargado «(.+)» ✓ — ahora toca Leer$/, "Loaded «$1» ✓ — now tap Read"],
    [/^Guardé en el proyecto: ((?:dirección|email|teléfono|cliente)(?:, (?:dirección|email|teléfono|cliente))*) ✓$/, s => {
      const T = { "dirección": "address", "email": "email", "teléfono": "phone", "cliente": "client" };
      const l = s.match(/^Guardé en el proyecto: (.+) ✓$/)[1].split(", ").map(x => T[x]);
      return "Saved to the project: " + l.join(", ") + " ✓";
    }]
  );
  // «Volver a leer con inteligencia (≈ N ¢)»: la regla general «Volver a …» de i18n.js se lo come antes que
  // cualquier regla de aquí (devuelve el texto tal cual), así que va por el diccionario: 0–99 ¢ (ver notas-G).
  Object.assign(D, Object.fromEntries(Array.from({ length: 100 }, (_, c) =>
    [`Volver a leer con inteligencia (≈ ${c} ¢)`, `Read again with AI (≈ ${c} ¢)`])));
  // · parte-H
  // ---------- Trozo H: app.js 15471–final · el lector del alcance, armar/subir el contrato y el levantamiento ----------
  Object.assign(D, {
    // --- El alcance: lo que dice la línea gris y los avisos del lector con inteligencia ---
    "La lectura del asistente no casa con esta hoja; me quedo con las reglas": "The assistant's reading doesn't match this sheet; I'm sticking with the rules",
    "Pega primero la hoja": "Paste the sheet first",
    "No pude leer esta hoja; revísala y vuelve a tocar Leer": "I couldn't read this sheet; check it and tap Read again",
    "Leído ✓ — revisa el dinero y redacta": "Read ✓ — check the money and write it up",
    "El asistente ya está mirando esta hoja": "The assistant is already looking at this sheet",
    "Sin señal: leí con las reglas de siempre; cuando vuelva, toca Leer otra vez": "No signal: I read it with the usual rules; when it's back, tap Read again",
    "Llegó la lectura inteligente; para usarla vuelve a la hoja y toca Leer": "The smart reading arrived; to use it, go back to the sheet and tap Read",
    "El asistente terminó de leer tu hoja ✓": "The assistant finished reading your sheet ✓",
    "No pude hablar con el asistente": "I couldn't reach the assistant",
    "El asistente escribió un monto donde no van montos; no acepto esa lectura: me quedo con las reglas": "The assistant wrote an amount where amounts don't go; I won't accept that reading: I'm sticking with the rules",
    "El asistente devolvió algo que no cuadra con tu hoja; me quedo con las reglas": "The assistant returned something that doesn't match your sheet; I'm sticking with the rules",
    "Con la lectura del asistente la hoja se lee distinto: vuelve a tocar «Usarlo tal cual» (o «Pasarlo a inglés») antes de armar":
      "With the assistant's reading the sheet reads differently: tap “Use it as is” (or “Translate to English”) again before building",
    "La hoja cambió mucho: toca Leer para volver a leerla": "The sheet changed a lot: tap Read to read it again",
    // Reacomodar y redactar
    "Pega primero el texto": "Paste the text first",
    "Ordenando…": "Reorganizing…",
    "Hay dinero en la hoja que no supe tapar; no la mando al asistente. Quítalo y vuelve a intentarlo": "There's money on the sheet I couldn't cover; I won't send it to the assistant. Remove it and try again",
    "El asistente no devolvió la hoja": "The assistant didn't return the sheet",
    "El asistente me devolvió la hoja con los montos cambiados de sitio; no la toco. Ordénala a mano o quítale el precio y vuelve a intentarlo":
      "The assistant returned the sheet with the amounts moved around; I'm not touching it. Reorganize it by hand or remove the price and try again",
    "Ordenado ✓ — míralo antes de seguir": "Reorganized ✓ — look it over before you continue",
    "Arregla primero lo que está en rojo": "Fix what's in red first",
    "Hay dinero en el texto que va al asistente. No lo mando.": "There's money in the text going to the assistant. I won't send it.",
    "Redactando… no cierres": "Writing… don't close",
    "El asistente no devolvió la redacción": "The assistant didn't return the write-up",
    "Redactar en inglés": "Write it in English",
    "Redactado ✓ — revísalo trozo a trozo": "Written ✓ — review it section by section",
    "El asistente todavía está mirando tu hoja (suele tardar menos de 2 minutos).": "The assistant is still looking at your sheet (it usually takes less than 2 minutes).",
    "Aceptar: lo espero.": "OK: I'll wait for it.",
    "Cancelar: sigo sin él.": "Cancel: I'll go on without it.",
    "Espero al asistente; en cuanto llegue, vuelve a tocar": "Waiting for the assistant; as soon as it's done, tap again",
    "Listo ✓ — revísalo y arma el contrato": "Done ✓ — review it and build the contract",
    "La lectura del asistente arrastraba una línea que no va en el contrato; para este paso usé las reglas": "The assistant's reading dragged in a line that doesn't go in the contract; for this step I used the rules",
    // Los errores del cerebro, en llano
    "Esto solo lo puede usar el dueño": "Only the owner can use this",
    "Al asistente le falta su llave en la nube": "The assistant is missing its key in the cloud",
    "Hay dinero en el texto que iba al asistente; no se mandó": "There was money in the text going to the assistant; it wasn't sent",
    "El asistente metió un monto que no estaba en tu texto. No lo acepto": "The assistant added an amount that wasn't in your text. I won't accept it",
    "El asistente no devolvió nada útil. Vuelve a intentarlo": "The assistant didn't return anything useful. Try again",
    "No hay texto que mandar": "There's no text to send",
    "Se me escapó un monto sin tapar; no mandé la hoja. Leí con las reglas de siempre": "An amount slipped through uncovered; I didn't send the sheet. I read it with the usual rules",
    "La hoja llegó vacía al asistente; leí con las reglas de siempre": "The sheet reached the assistant empty; I read it with the usual rules",
    "La hoja cambió mientras la mandaba; toca Leer otra vez": "The sheet changed while I was sending it; tap Read again",
    "Falta pegar el SQL del lector en la base; sigo con las reglas": "The reader's SQL still needs to be pasted into the database; I'm going on with the rules",
    "El asistente escribió un monto donde no van montos; me quedo con las reglas": "The assistant wrote an amount where amounts don't go; I'm sticking with the rules",
    "El asistente está ocupado; leí con las reglas. Prueba en un minuto": "The assistant is busy; I read it with the rules. Try in a minute",
    "El asistente tardó demasiado; me quedo con la lectura de siempre": "The assistant took too long; I'm sticking with the usual reading",
    "El asistente no quiso leer esta hoja; sigo con las reglas": "The assistant wouldn't read this sheet; I'm going on with the rules",
    "La hoja es muy larga para leerla de una vez; leí con las reglas de siempre": "The sheet is too long to read in one go; I read it with the usual rules",
    "No encuentro esa lectura; toca Leer otra vez": "I can't find that reading; tap Read again",
    "El asistente falló; vuelve a intentarlo en un minuto": "The assistant failed; try again in a minute",
    // Armar, imprimir, bajar, subir y guardar el contrato
    "La hoja cambió después de redactar. Toca Leer y después Directo (o Redactar) antes de armar.":
      "The sheet changed after it was written up. Tap Read and then “Use it as is” (or “Translate to English”) before building.",
    "vuelve a tocar Directo o Redactar antes de armar": "tap “Use it as is” or “Translate to English” again before building",
    "no cuadra con tu hoja": "it doesn't match your sheet",
    "Bajando la plantilla…": "Downloading the template…",
    "La plantilla de la app tiene una marca coja": "The app's template has a broken marker",
    "Armado, pero hay algo que revisar": "Built, but there's something to check",
    "Contrato armado ✓": "Contract built ✓",
    "El navegador bloqueó la ventana. Permite ventanas emergentes para la app y vuelve a tocar.": "The browser blocked the window. Allow pop-ups for the app and tap again.",
    "Elige «Guardar como PDF» y guárdalo; después súbelo al portal": "Choose “Save as PDF” and save it; then upload it to the portal",
    "Bajado ✓ — pásalo a PDF y súbelo al portal": "Downloaded ✓ — turn it into a PDF and upload it to the portal",
    "Guarda primero el alcance": "Save the scope first",
    "Subiendo…": "Uploading…",
    "Subido ✓ — el enlace del cliente quedó copiado": "Uploaded ✓ — the client link was copied",
    "En su portal ya sale primero, marcado NUEVO.": "It already shows first in their portal, marked NEW.",
    "Falta subir el correo v6 en la nube para este aviso; el contrato ya está en su portal, marcado NUEVO": "Email v6 still has to be uploaded to the cloud for this notice; the contract is already in their portal, marked NEW",
    "Este alcance ya tiene su contrato en el portal esperando firma. No hace falta subirlo otra vez.": "This scope already has its contract in the portal waiting for a signature. No need to upload it again.",
    "Subir el PDF al portal": "Upload the PDF to the portal",
    "Guardando…": "Saving…",
    "Guardado en la propuesta ✓": "Saved to the proposal ✓",
    "Guardar en la propuesta": "Save to the proposal",
  
    // --- El levantamiento en sitio ---
    "Levantamientos": "Site surveys",
    "Empezar un levantamiento": "Start a site survey",
    "Seis fichas: la casa, el panel, los cuartos, lo que se ve, cuatro medidas y el resumen. Se guarda solo, aunque no haya señal.":
      "Six tabs: the house, the panel, the rooms, what you see, four measurements and the summary. It saves by itself, even without signal.",
    "Todavía no hay ninguno.": "None yet.",
    "CONVERTIDO ✓": "CONVERTED ✓", "ABIERTO": "OPEN",
    "¿Eliminar este levantamiento con todos sus cuartos?": "Delete this site survey with all its rooms?",
    "Levantamiento eliminado ✓": "Site survey deleted ✓",
    // Las fichas y la barra de pasos
    "La casa": "The house", "Cuartos": "Rooms", "Se ve": "Conditions", "Medidas": "Measurements",
    "Sin señal — se está guardando en el teléfono": "No signal — saving on the phone",
    "Atrás": "Back", "Siguiente →": "Next →",
    // Ficha 1 · La casa
    "Nombre del trabajo": "Job name", "Ej: Casa García — Rewire": "E.g. García house — Rewire",
    "Ej: Juan García": "E.g. Juan García", "Dirección": "Address", "Calle, ciudad": "Street, city",
    "Pies cuadrados": "Square feet", "Ej: 1800": "E.g. 1800",
    "Residencial": "Residential", "Comercial": "Commercial",
    "Se guarda solo. Puedes salir y volver cuando quieras.": "It saves by itself. You can leave and come back anytime.",
    // Ficha 2 · El panel
    "El panel": "The panel",
    "No se puede reutilizar: no se consiguen breakers para él. La cotización tiene que llevar panel nuevo.":
      "It can't be reused: breakers for it can't be found. The quote has to include a new panel.",
    "Te dejé puestas": "I already put in",
    "9 horas": "9 hours",
    "(demoler el viejo y montar el nuevo) más": "(tear out the old one and install the new one) plus",
    "media hora por cada circuito": "half an hour for each circuit",
    "que haya que reconectar — ahora mismo": "that has to be reconnected — right now",
    "Lo que falta es el precio del panel. Ponlo tú": "What's missing is the panel price. Enter it yourself",
    "El panel está lleno": "The panel is full",
    "El precio del sub-panel": "The sub-panel price",
    "Marca": "Brand", "No se lee": "Can't read it",
    "Amperaje": "Amperage", "No se sabe": "Unknown",
    "Espacios que tiene": "Total spaces", "Espacios libres": "Free spaces",
    "lo que ves, no lo que hay que calcular": "what you see, not what you'd have to figure out",
    "Combo con medidor": "Meter combo",
    "Acometida": "Service entrance", "Aérea": "Overhead", "Subterránea": "Underground",
    "Dónde está": "Location", "Garaje": "Garage", "Pasillo": "Hallway", "Lavandería": "Laundry", "Otro": "Other",
    "¿Cabe pararse delante?": "Room to stand in front?",
    "36″ de fondo, artículo 110.26": "36″ deep, article 110.26",
    "Sí": "Yes", "No — sin espacio": "No — no clearance",
    "¿Hay directorio de circuitos?": "Is there a circuit directory?", "A medias": "Partly",
    "No lo pude abrir — ¿por qué?": "I couldn't open it — why?",
    "Déjalo vacío si sí lo abriste": "Leave it empty if you did open it",
    "Si escribes algo aquí, sale como bandera roja y como línea de «no incluye».":
      "If you write something here, it shows up as a red flag and as a “not included” line.",
    // Ficha 3 · Los cuartos
    "Quitar": "Remove",
    "Todavía no hay cuartos. Añade el primero abajo.": "No rooms yet. Add the first one below.",
    "＋ Añadir cuarto": "＋ Add room",
    "Cada clase trae puestos los contadores que casi siempre hacen falta. Lo que sobre se quita.":
      "Each room type comes with the counters you almost always need. Remove what you don't.",
    "Todos los cuartos": "All rooms", "Quitar este contador": "Remove this counter",
    "＋ otra cosa": "＋ something else",
    "Nota del cuarto": "Room note", "Lo que haga falta recordar": "Anything you need to remember",
    "Contado ✓ — tocar para reabrir": "Counted ✓ — tap to reopen", "Cuarto contado": "Room counted",
    "pies": "ft",
    // Las clases de cuarto
    "Cocina": "Kitchen", "Baño": "Bathroom", "Recámara": "Bedroom", "Sala / comedor": "Living / dining",
    "Pasillo / lavandería": "Hallway / laundry",
    // Lo que se cuenta
    "Tomas": "Receptacles", "Tomas GFCI": "GFCI receptacles", "GFCI de intemperie": "Weather-resistant GFCI",
    "Toma 240V estufa": "240V range receptacle", "Toma 240V secadora": "240V dryer receptacle",
    "Interruptores": "Switches", "De tres vías": "3-way switches", "Empotradas": "Recessed lights",
    "Colgantes": "Pendants", "Luz de techo": "Ceiling light", "Ventilador de techo": "Ceiling fan",
    "Sconce de pared": "Wall sconce", "Luz de vanidad": "Vanity light", "Reflector exterior": "Outdoor flood light",
    "Extractor de baño": "Bath exhaust fan", "Bajo gabinete": "Under-cabinet", "Tira LED": "LED strip",
    "Detector de humo": "Smoke detector", "Detector humo/CO": "Smoke/CO detector", "Toma de datos": "Data jack",
    "Sensor de movimiento": "Motion sensor", "Dimmer Caséta": "Caséta dimmer", "Switch Caséta": "Caséta switch",
    "Pico Caséta": "Caséta Pico", "Hub Caséta": "Caséta hub",
    // NUEVA / CAMBIAR / SE QUEDA / QUITAR y su ayuda (title)
    "NUEVA": "NEW", "CAMBIAR": "REPLACE", "SE QUEDA": "STAYS", "QUITAR": "REMOVE",
    "no existe, se pone desde cero": "doesn't exist, installed from scratch",
    "existe y se reemplaza (la demolición va dentro)": "exists and gets replaced (demo included)",
    "existe y no se toca — cero horas, pero queda apuntado": "exists and isn't touched — zero hours, but it's noted",
    "se retira y no se repone": "removed and not replaced",
    // Ficha 4 · Lo que se ve
    "Lo que se ve": "What you see",
    "Trabajo que antes no existía": "Work that didn't exist before",
    "Rastrear circuitos se apagó solo: al reconectar el panel nuevo ya se identifica cada circuito.":
      "Circuit tracing turned itself off: reconnecting the new panel already identifies each circuit.",
    "Rastrear circuitos": "Trace circuits", "solo los que toca el trabajo": "only the ones the work touches",
    "Empalmes viejos o cajas sin tapa": "Old splices or boxes without covers",
    "Ninguno": "None", "Pocos (3)": "A few (3)", "Bastantes (8)": "Quite a few (8)", "Muchos (15)": "Many (15)",
    "Aberturas en pared o techo": "Wall or ceiling openings",
    "Sacar cable viejo": "Remove old wire", "Nada": "None", "50 pies": "50 ft",
    "Sacar tubería vieja": "Remove old conduit",
    "¿Hay que tocar el medidor?": "Does the meter need work?",
    "Falta el precio de la base del medidor": "The meter base price is missing",
    "Ponlo tú": "Enter it yourself",
    "Viajes a corregir trabajo de otro": "Trips to fix someone else's work",
    "Viajes de escombro": "Debris haul trips",
    "Luminarias que se botan y no se reponen": "Fixtures removed and not replaced",
    "Permiso": "Permit", "Sí, lo sacamos": "Yes, we pull it", "No hace falta": "Not needed", "Lo saca el GC": "The GC pulls it",
    "Lo que hace que el mismo trabajo tarde más": "What makes the same work take longer",
    "Pared de yeso sobre listones": "Plaster-on-lath walls",
    "Pared o techo de bloque": "Block wall or ceiling",
    "Ático de gatear o lleno de aislamiento": "Crawl-only attic or full of insulation",
    "Crawl space bajo": "Low crawl space",
    "Techo de más de 10 pies": "Ceiling over 10 feet",
    "Hay que dejar la casa operando cada noche": "The house has to be left working every night",
    "Factor ahora mismo": "Factor right now",
    "(el mayor más la mitad de los demás, con tope 1.30).": "(the largest plus half of the rest, capped at 1.30).",
    "Banderas rojas": "Red flags",
    "cero horas: van al bloque «no incluye»": "zero hours: they go in the “not included” block",
    // Las banderas rojas (también salen en la lista «No incluye» del resumen)
    "Casa anterior a 1978 (plomo)": "House built before 1978 (lead)",
    "Casa anterior a 1985 (asbesto)": "House built before 1985 (asbestos)",
    "Hay trabajo de la compañía eléctrica": "Utility company work needed",
    "Servicio trifásico o de más de 400 A": "Three-phase service or over 400 A",
    "Humedad o madera podrida donde va el panel": "Moisture or rotten wood where the panel goes",
    "El panel no se pudo abrir": "The panel couldn't be opened",
    "Panel en closet o sin espacio delante": "Panel in a closet or without clearance in front",
    "Reglas de asociación de vecinos": "HOA rules",
    "Sin acceso al ático o al crawl space": "No access to the attic or crawl space",
    "Techo de teja o metal": "Tile or metal roof",
    // Ficha 5 · Las medidas
    "Las medidas": "Measurements", "Alto del techo": "Ceiling height",
    "¿Alguna corrida se pasa de 100 pies?": "Does any run go over 100 feet?",
    "Pies de más": "Extra feet", "De qué calibre": "Wire size",
    "El cable del circuito ya viene dentro de la partida del circuito. Aquí solo va lo que":
      "The circuit's wire is already included in the circuit's line item. Only put here what goes",
    "pasa": "over", "de los 100 pies.": "100 feet.",
    "Del panel al medidor": "Panel to meter",
    // Ficha 6 · El resumen
    "El resumen": "Summary", "Le falta un precio": "A price is missing",
    "partidas": "line items", "horas": "hours",
    "Todavía no hay nada contado.": "Nothing counted yet.", "Todavía no hay nada contado": "Nothing counted yet",
    "Circuitos": "Circuits", "No incluye": "Not included", "Circuitos nuevos": "New circuits",
    "Iluminación 15A": "Lighting 15A", "Tomas 20A": "Receptacles 20A", "Tomas 20A con AFCI/GFCI": "Receptacles 20A with AFCI/GFCI",
    "Secadora 30A": "Dryer 30A", "Estufa 50A": "Range 50A", "Aire 30A": "A/C 30A", "Calentador 30A": "Water heater 30A",
    "Pasar al estimado →": "Send to the estimate →",
    "Se crea el estimado con todos estos renglones. Lo que añadas a mano después no se toca al reconvertir.":
      "The estimate is created with all these line items. Anything you add by hand later isn't touched when you convert again.",
    "Añadir al alcance de un proyecto": "Add to a project's scope",
    "Necesita señal para poner precio. Lo apuntado no se pierde.": "It needs signal to price it. What you've logged isn't lost.",
    "Pasando…": "Sending…",
    // Al alcance de un proyecto
    "No hay proyectos abiertos donde ponerlo": "There are no open projects to put it in",
    "¿A qué proyecto le pongo el alcance?": "Which project should I add the scope to?",
    "Ese número no es de la lista": "That number isn't on the list",
    "Todo eso ya estaba en el alcance de ese proyecto": "All of that was already in that project's scope"
  });
  
  REGLAS.push(...(() => {
    // La cola de un aviso («No se pudo subir: …») es un mensaje de la app (enCristiano u otro trozo):
    // se traduce con el mismo motor si se puede; si no, se queda como vino.
    const cola = t => {
      try { if (typeof traducirLimpio === "function") { const r = traducirLimpio(t); if (r !== null && r !== undefined) return r; } } catch (e) { /* se queda */ }
      return D[t] !== undefined ? D[t] : t;
    };
    const pl = (n, uno, varios) => (Number(n) === 1 ? uno : varios);
    const esc = s => s.replace(/[.*+?^${}()|[\]\\\/]/g, c => "\\" + c);
  
    // Lo contado de cada cuarto en el resumen: «3 tomas, 2 interruptores (cambiar)» (etiqueta en minúsculas)
    const CONT = {
      "tomas": ["receptacle", "receptacles"], "tomas gfci": ["GFCI receptacle", "GFCI receptacles"],
      "gfci de intemperie": ["weather-resistant GFCI", "weather-resistant GFCIs"],
      "toma 240v estufa": ["240V range receptacle", "240V range receptacles"],
      "toma 240v secadora": ["240V dryer receptacle", "240V dryer receptacles"],
      "interruptores": ["switch", "switches"], "de tres vías": ["3-way switch", "3-way switches"],
      "dimmers": ["dimmer", "dimmers"], "empotradas": ["recessed light", "recessed lights"],
      "colgantes": ["pendant", "pendants"], "luz de techo": ["ceiling light", "ceiling lights"],
      "ventilador de techo": ["ceiling fan", "ceiling fans"], "sconce de pared": ["wall sconce", "wall sconces"],
      "luz de vanidad": ["vanity light", "vanity lights"], "reflector exterior": ["outdoor flood light", "outdoor flood lights"],
      "extractor de baño": ["bath exhaust fan", "bath exhaust fans"],
      "bajo gabinete": ["ft of under-cabinet lighting", "ft of under-cabinet lighting"],
      "tira led": ["ft of LED strip", "ft of LED strip"],
      "detector de humo": ["smoke detector", "smoke detectors"], "detector humo/co": ["smoke/CO detector", "smoke/CO detectors"],
      "toma de datos": ["data jack", "data jacks"], "sensor de movimiento": ["motion sensor", "motion sensors"],
      "dimmer caséta": ["Caséta dimmer", "Caséta dimmers"], "switch caséta": ["Caséta switch", "Caséta switches"],
      "pico caséta": ["Caséta Pico", "Caséta Picos"], "hub caséta": ["Caséta hub", "Caséta hubs"]
    };
    const ACC = { "cambiar": "replace", "se queda": "stays", "quitar": "remove" };
    const contAlt = Object.keys(CONT).sort((a, b) => b.length - a.length).map(esc).join("|");
    const unCont = `\\d+ (?:${contAlt})(?: \\((?:cambiar|se queda|quitar)\\))?`;
    const RE_CONT = new RegExp(`^${unCont}(?:, ${unCont})*${"$"}`);
    const RE_CONT1 = new RegExp(`^(\\d+) (${contAlt})(?: \\((cambiar|se queda|quitar)\\))?${"$"}`);
    const trCont = s => s.split(", ").map(p => {
      const m = p.match(RE_CONT1); if (!m) return p;
      return m[1] + " " + CONT[m[2]][Number(m[1]) === 1 ? 0 : 1] + (m[3] ? " (" + ACC[m[3]] + ")" : "");
    }).join(", ");
  
    // Los circuitos nuevos del resumen: «2 × Tomas 20A, 1 × Estufa 50A»
    const CIRC = { "Iluminación 15A": "Lighting 15A", "Tomas 20A": "Receptacles 20A", "Tomas 20A con AFCI/GFCI": "Receptacles 20A with AFCI/GFCI",
      "Secadora 30A": "Dryer 30A", "Estufa 50A": "Range 50A", "Aire 30A": "A/C 30A", "Calentador 30A": "Water heater 30A" };
    const circAlt = Object.keys(CIRC).sort((a, b) => b.length - a.length).map(esc).join("|");
    const RE_CIRC = new RegExp(`^\\d+ × (?:${circAlt})(?:, \\d+ × (?:${circAlt}))*${"$"}`);
    const RE_CIRC1 = new RegExp(`^(\\d+) × (${circAlt})${"$"}`);
  
    // Los nombres de cuarto que pone la app («Cocina», «Baño 2») y las clases
    const CLASE = { "Cocina": "Kitchen", "Baño": "Bathroom", "Recámara": "Bedroom", "Sala / comedor": "Living / dining",
      "Pasillo / lavandería": "Hallway / laundry", "Exterior": "Exterior", "Garaje": "Garage", "Otro": "Other" };
    const claseAlt = Object.keys(CLASE).map(esc).join("|");
  
    // Lo que la app puso sola en «Lo que se ve»
    const AUTO1 = "Panel condenado — panel nuevo de 200A y \\d+ reconexiones|Panel lleno — sub-panel de 100A|Casa habitada — protección en \\d+ cuartos";
    const trAuto = p => {
      let m;
      if ((m = p.match(/^Panel condenado — panel nuevo de 200A y (\d+) reconexiones$/))) return `Condemned panel — new 200A panel and ${m[1]} ${pl(m[1], "reconnection", "reconnections")}`;
      if (p === "Panel lleno — sub-panel de 100A") return "Full panel — 100A sub-panel";
      if ((m = p.match(/^Casa habitada — protección en (\d+) cuartos$/))) return `Occupied house — protection in ${m[1]} ${pl(m[1], "room", "rooms")}`;
      return p;
    };
  
    // Los precios que la app no se inventa («le falta el panel nuevo de 200A y la base del medidor»)
    const FALTA = { "el panel nuevo de 200A": "the new 200A panel", "el sub-panel de 100A": "the 100A sub-panel", "la base del medidor": "the meter base" };
    const faltaAlt = `(?:${Object.keys(FALTA).map(esc).join("|")})`;
    const faltaLista = `(${faltaAlt}(?: y ${faltaAlt})*)`;
    const trFalta = s => s.split(" y ").map(x => FALTA[x] || x).join(" and ");
  
    // «Tomé del proyecto: dirección (…) · email (…)»
    const TOME = { "cliente": "client", "homeowner": "homeowner", "atención": "attention", "email": "email", "teléfono": "phone", "dirección": "address" };
  
    return [
      // --- El alcance ---
      [/^La hoja es muy larga para el asistente(?: \((\d+) líneas\))?: leí con las reglas de siempre$/, s => {
        const m = s.match(/\((\d+) líneas\)/);
        return "The sheet is too long for the assistant" + (m ? ` (${m[1]} ${pl(m[1], "line", "lines")})` : "") + ": I read it with the usual rules";
      }],
      [/^Hay (\d+) líneas nuevas que el asistente no vio: toca Leer$/, s => {
        const n = s.match(/\d+/)[0];
        return `There ${pl(n, "is", "are")} ${n} new ${pl(n, "line", "lines")} the assistant didn't see: tap Read`;
      }],
      [/^Ordenado ✓ — míralo antes de seguir; (\d+) cosas no supo colocarlas$/, s => {
        const n = s.match(/; (\d+) cosas/)[1];
        return `Reorganized ✓ — look it over before you continue; ${n} ${pl(n, "thing", "things")} it couldn't place`;
      }],
      [/^El asistente escribió algo prohibido en (\d+) trozos?; míralos en rojo$/, s => {
        const n = s.match(/\d+/)[0];
        return `The assistant wrote something forbidden in ${n} ${pl(n, "section", "sections")}; see ${pl(n, "it", "them")} in red`;
      }],
      [/^El asistente devolvió algo que no puedo usar: (.+)$/, s => "The assistant returned something I can't use: " + cola(s.slice("El asistente devolvió algo que no puedo usar: ".length))],
      [/^El asistente metió un monto que no estaba en tu texto\. No lo acepto: (.+)$/, "The assistant added an amount that wasn't in your text. I won't accept it: $1"],
      [/^Se me escapó un monto en la línea (\d+) sin tapar; no lo mandé\. Leí con las reglas de siempre$/, "An amount on line $1 slipped through uncovered; I didn't send it. I read it with the usual rules"],
      [/^El asistente ya gastó lo del mes \((\S+) de (\S+)\); sigo con las reglas$/, "The assistant already used up this month's budget ($1 of $2); I'm going on with the rules"],
      [/^Tomé del proyecto: (.+)$/, s => "Taken from the project: " + s.slice("Tomé del proyecto: ".length).split(" · ")
        .map(p => p.replace(/^(cliente|homeowner|atención|email|teléfono|dirección) \(/, (m, k) => TOME[k] + " (")).join(" · ")],
      [/^(.+) \(los montos no cambian\)$/, s => cola(s.slice(0, -" (los montos no cambian)".length)) + " (the amounts don't change)"],
      [/^Ojo: la ficha tiene (\d+) hitos? ya facturado o cobrado; no los toqué\. Revisa que cuadren con el contrato\.$/, s => {
        const n = s.match(/\d+/)[0];
        return `Heads up: the job file has ${n} ${pl(n, "milestone", "milestones")} already invoiced or collected; I didn't touch ${pl(n, "it", "them")}. Check that ${pl(n, "it matches", "they match")} the contract.`;
      }],
      [/^Ficha cuadrada con el contrato ✓ — (\d+) pagos \(([\d/]+)\) y contrato (\S+)$/, "Job file matched to the contract ✓ — $1 payments ($2) and contract $3"],
      [/^El inglés que hay no cuadra con lo que ahora dice la hoja: (.+)$/, s => "The English there doesn't match what the sheet says now: " + cola(s.slice("El inglés que hay no cuadra con lo que ahora dice la hoja: ".length))],
      [/^Subido ✓ — el enlace del cliente: (\S+)$/, "Uploaded ✓ — the client link: $1"],
      [/^¿Le aviso a (.+) por correo \(([^()]*)\) que hay un contrato nuevo esperando su firma\?$/, "Should I email $1 ($2) that a new contract is waiting for their signature?"],
      [/^Aviso enviado a (\S+) ✓$/, "Notice sent to $1 ✓"],
      [/^No salió el aviso: (.+)$/, s => "The notice didn't go out: " + cola(s.slice("No salió el aviso: ".length))],
      [/^No se pudo subir: (.+)$/, s => "Could not upload: " + cola(s.slice("No se pudo subir: ".length))],
      [/^El contrato quedó guardado, pero la ficha no se cuadró: (.+)$/, s => "The contract was saved, but the job file couldn't be synced: " + cola(s.slice("El contrato quedó guardado, pero la ficha no se cuadró: ".length))],
      [/^Guardado ✓ — este proyecto tiene (\d+) alcances$/, "Saved ✓ — this project has $1 scopes"],
      [/^No se pudo guardar: (.+)$/, s => "Could not save: " + cola(s.slice("No se pudo guardar: ".length))],
  
      // --- El levantamiento ---
      [/^Mis levantamientos \((\d+)\)$/, "My site surveys ($1)"],
      [/^Levantamiento (\d{1,2}\/\d{1,2}\/\d{4})$/, "Site survey $1"],
      [/^(.+) · (\d+) cuartos?$/, s => {
        const m = s.match(/^(.+) · (\d+) cuartos?$/);
        return (m[1] === "sin cliente" ? "no client" : m[1]) + ` · ${m[2]} ${pl(m[2], "room", "rooms")}`;
      }],
      [/^Panel (.+) — condenado$/, "$1 panel — condemned"],
      [/^Con (\d+) espacios libres no caben los circuitos nuevos: hace falta un sub-panel de 100A\.$/, s => {
        const n = s.match(/\d+/)[0];
        return `With ${n} free ${pl(n, "space", "spaces")} the new circuits don't fit: a 100A sub-panel is needed.`;
      }],
      [/^Los cuartos \((\d+)\)$/, "Rooms ($1)"],
      [new RegExp(`^(${claseAlt}) (\\d+)${"$"}`), s => { const m = s.match(/^(.+) (\d+)$/); return CLASE[m[1]] + " " + m[2]; }],
      [/^(.+) · (\d+) cosas contadas$/, s => {
        const m = s.match(/^(.+) · (\d+) cosas contadas$/);
        return (D[m[1]] !== undefined ? D[m[1]] : m[1]) + ` · ${m[2]} ${pl(m[2], "item", "items")} counted`;
      }],
      [/^(.+) · sin contar$/, s => { const k = s.slice(0, -" · sin contar".length); return (D[k] !== undefined ? D[k] : k) + " · not counted"; }],
      [/^¿Quitar «(.+)» con todo lo contado\?$/, "Remove “$1” and everything counted in it?"],
      [new RegExp(`^(?:✓ )?Puesto solo: (?:${AUTO1})(?: · (?:${AUTO1}))*${"$"}`), s => {
        const i = s.indexOf("Puesto solo: ");
        return s.slice(0, i) + "Set automatically: " + s.slice(i + "Puesto solo: ".length).split(" · ").map(trAuto).join(" · ");
      }],
      [RE_CONT, trCont],
      [RE_CIRC, s => s.split(", ").map(p => { const m = p.match(RE_CIRC1); return m ? m[1] + " × " + CIRC[m[2]] : p; }).join(", ")],
      [/^El panel no se pudo abrir: (.+)$/, "The panel couldn't be opened: $1"],
      [/^Faltó contar: (.+)$/, "Not counted: $1"],
      [new RegExp(`^Falta ${faltaLista}\\. Puedes convertir igual: el estimado sale marcado\\.${"$"}`), s => {
        const m = s.match(new RegExp(`^Falta ${faltaLista}\\.`));
        return `Missing ${trFalta(m[1])}. You can convert anyway: the estimate comes out flagged.`;
      }],
      [new RegExp(`^Estimado listo con (\\d+) renglones — le falta ${faltaLista}${"$"}`), s => {
        const m = s.match(new RegExp(`^Estimado listo con (\\d+) renglones — le falta ${faltaLista}${"$"}`));
        return `Estimate ready with ${m[1]} ${pl(m[1], "line item", "line items")} — missing ${trFalta(m[2])}`;
      }],
      [/^Estimado listo con (\d+) renglones ✓$/, s => { const n = s.match(/\d+/)[0]; return `Estimate ready with ${n} ${pl(n, "line item", "line items")} ✓`; }],
      [/^No se pudo pasar al estimado: (.+)$/, s => "Could not send it to the estimate: " + cola(s.slice("No se pudo pasar al estimado: ".length))],
      [/^Se van a añadir (\d+) puntos al alcance de (.+)\. ¿Sigo\?$/, s => {
        const m = s.match(/^Se van a añadir (\d+) puntos al alcance de (.+)\. ¿Sigo\?$/);
        return `I'm about to add ${m[1]} ${pl(m[1], "item", "items")} to the scope of ${m[2]}. Go ahead?`;
      }],
      [/^(\d+) puntos añadidos al alcance de (.+) ✓$/, s => {
        const m = s.match(/^(\d+) puntos añadidos al alcance de (.+) ✓$/);
        return `${m[1]} ${pl(m[1], "item", "items")} added to the scope of ${m[2]} ✓`;
      }],
      [/^No se pudo guardar el alcance: (.+)$/, s => "Could not save the scope: " + cola(s.slice("No se pudo guardar el alcance: ".length))]
    ];
  })());
  // ---------- Remates del recorrido (26-sep) ----------
  Object.assign(D, {
    "Al completar": "On completion", "Al firmar el contrato": "On contract signing"
  });
  REGLAS.push(
    [/^Permiso — ([A-Z0-9][\w-]*\d[\w-]*)$/, "Permit — $1"],
    [/^Milestone (\d+) — (\d+)% depósito$/, "Milestone $1 — $2% deposit"],
    // El asistente con trabajos largos y la demolición en una sola familia (v239–v240, MXP Planos)
    [/^Sigo trabajando \((\d+)\)…( .*)?$/, s => s.replace(/^Sigo trabajando \((\d+)\)…/, "Still working ($1)…")],
    [/^SUPUESTO: uno viejo por cada uno de los (\d+) dispositivo\(s\) nuevos \(receptáculos y switches llevan las mismas horas\)$/,
      "ASSUMPTION: one old one for each of the $1 new device(s) (receptacles and switches take the same hours)"],
    [/^SUPUESTO: una vieja por cada una de las (\d+) luminaria\(s\) nuevas$/, "ASSUMPTION: one old one for each of the $1 new fixture(s)"],
    [/^OJO, DEMOLICIÓN DOBLE: el estimado tiene (\d+) de «DEMOLICIÓN DE DISPOSITIVO O LUMINARIA» y además (\d+) de «DEMO - …» \(Receptacles \/ Switches \/ Light Fixtures\)\. Son la misma demolición: quita una de las dos\.$/,
      "WATCH OUT, DOUBLE DEMOLITION: the estimate has $1 of “DEMOLICIÓN DE DISPOSITIVO O LUMINARIA” and also $2 of “DEMO - …” (Receptacles / Switches / Light Fixtures). It's the same demolition: remove one of the two."]
  );
  Object.assign(D, { "pensando… (con lo difícil puede tardar unos minutos)": "thinking… (hard questions can take a few minutes)" });
  // ---------- El motor ----------
  // Cada texto de la pantalla se busca en el diccionario tal como se ve: con los
  // espacios y saltos de línea juntados en uno solo. Si no está, se prueba sin el
  // adorno de delante (emoji, viñeta, «+», «—») y sin los dos puntos o el «·» del
  // final, y el adorno se le vuelve a poner. Lo que no se encuentra se queda igual.
  const normal = s => s.replace(/\s+/g, " ").trim();
  const ADORNO_INI = /^[\s -⯿⸀-⹿　-〿️‍\u{1F000}-\u{1FAFF}•·—–\-+*#…→←↑↓✓✔✕✗×]+/u;
  const ADORNO_FIN = /[\s:·—–…]+$/u;
  function buscar(s) {
    if (Object.prototype.hasOwnProperty.call(D, s)) return D[s];
    // Una regla que casa pero no sabe traducir (devuelve null o el mismo texto) deja paso a la siguiente
    for (const [re, out] of REGLAS) {
      if (!re.test(s)) continue;
      const r = typeof out === "function" ? out(s) : s.replace(re, out);
      if (r !== null && r !== undefined && r !== s) return r;
    }
    return null;
  }
  const memoria = new Map();
  function traducirLimpio(limpio) {
    if (memoria.has(limpio)) return memoria.get(limpio);
    let r = buscar(limpio);
    if (r === null) {
      const ini = (limpio.match(ADORNO_INI) || [""])[0];
      const fin = (limpio.slice(ini.length).match(ADORNO_FIN) || [""])[0];
      const nucleo = limpio.slice(ini.length, limpio.length - fin.length);
      if (nucleo && (ini || fin) && /[a-záéíóúñ]/i.test(nucleo)) {
        const rn = buscar(nucleo);
        if (rn !== null) r = ini + rn + fin;
      }
    }
    if (memoria.size > 20000) memoria.clear();
    memoria.set(limpio, r);
    return r;
  }
  function traducirTexto(t) {
    if (!t || !/[a-záéíóúñ¿¡]/i.test(t)) return t;
    const limpio = normal(t);
    const r = traducirLimpio(limpio);
    if (r === null || r === limpio) return t;
    // Se respetan los espacios de los bordes: separan este texto del de al lado
    return (/^\s/.test(t) ? " " : "") + r + (/\s$/.test(t) ? " " : "");
  }
  // Un mensaje de varias líneas (los avisos de confirmar): línea por línea
  const traducirMensaje = m => typeof m === "string" ? m.split("\n").map(traducirTexto).join("\n") : m;

  // Lo marcado data-no-i18n es CONTENIDO del usuario — no se traduce. Tampoco lo
  // que se está escribiendo (textarea, campos editables).
  const PROTEGIDO = "[data-no-i18n], script, style, textarea, [contenteditable=''], [contenteditable='true']";
  const protegido = el => !el || !!el.closest(PROTEGIDO);
  const ATRS = ["placeholder", "title", "aria-label", "alt", "label"];
  // Los atributos sí se traducen en un textarea (su placeholder es de la app, no de la persona)
  function traducirAtributos(el) {
    if (!el || el.closest("[data-no-i18n]")) return;
    for (const a of ATRS) {
      const v = el.getAttribute(a);
      if (v) { const n = traducirTexto(v); if (n !== v) el.setAttribute(a, n); }
    }
    if (el.tagName === "INPUT" && /^(button|submit|reset)$/i.test(el.type) && el.value) {
      const n = traducirTexto(el.value); if (n !== el.value) el.value = n;
    }
  }
  function traducirTextoNodo(n) {
    if (protegido(n.parentElement)) return;
    const nuevo = traducirTexto(n.nodeValue);
    if (nuevo !== n.nodeValue) n.nodeValue = nuevo;
  }
  function traducirNodo(raiz) {
    if (raiz.nodeType === 3) return traducirTextoNodo(raiz);
    if (raiz.nodeType !== 1 || raiz.closest("[data-no-i18n]")) return;
    const walker = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) traducirTextoNodo(n);
    const SEL_ATTR = "[placeholder], [title], [aria-label], [alt], optgroup[label], option[label], input[type=button], input[type=submit]";
    const conAttr = Array.from(raiz.querySelectorAll(SEL_ATTR));
    if (raiz.matches(SEL_ATTR)) conAttr.push(raiz);
    conAttr.forEach(traducirAtributos);
  }

  // Los avisos del navegador (confirmar, alertar, preguntar) también
  const c0 = window.confirm, a0 = window.alert, p0 = window.prompt;
  window.confirm = m => c0.call(window, traducirMensaje(m));
  window.alert = m => a0.call(window, traducirMensaje(m));
  window.prompt = (m, v) => p0.call(window, traducirMensaje(m), v);
  // Para las pruebas: el motor a la vista (solo en inglés)
  window.MXP_I18N = { traducir: traducirTexto, D, REGLAS };

  // Traducción inicial + observador: todo lo que la app pinte o cambie se traduce solo
  traducirNodo(document.body);
  if (document.title) document.title = traducirTexto(document.title);
  new MutationObserver(muts => {
    for (const m of muts) {
      if (m.type === "childList") m.addedNodes.forEach(traducirNodo);
      else if (m.type === "characterData") traducirTextoNodo(m.target);
      else if (m.type === "attributes") traducirAtributos(m.target);
    }
  }).observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATRS });
})();
