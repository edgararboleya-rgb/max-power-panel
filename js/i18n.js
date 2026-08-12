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
    "Fase de obra": "Job phase", "Horas — plan vs. real": "Hours — plan vs. actual",
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
    "📷 Recibos de compras": "📷 Purchase receipts", "📷 Importar recibo": "📷 Import receipt",
    "⬆ Subir recibo": "⬆ Upload receipt", "POR LEER": "TO READ", "LEÍDO": "READ", "CONCILIADO ✓": "RECONCILED ✓",
    "+ Agregar gestión": "+ Add task", "+ Agregar material": "+ Add material",
    "Agregar material": "Add material", "Agregar a la lista": "Add to list",
    "Comprados recientes": "Recently purchased", "✓ Comprado": "✓ Purchased", "✓ Hecha": "✓ Done",
    "Proyecto": "Project", "Cantidad (opcional)": "Quantity (optional)", "Cantidad": "Quantity",
    "🔴 Pendientes de obra que suenan a material": "🔴 Site issues that sound like materials",
    "→ Pasar a la lista": "→ Move to list",
    "Gestión (qué hay que hacer)": "Task (what needs doing)",
    "Foto del recibo (cámara o galería)": "Receipt photo (camera or gallery)",
    "Nota (opcional)": "Note (optional)", "Proveedor (opcional)": "Vendor (optional)",
    "Guardar cambios": "Save changes", "🗑 Eliminar": "🗑 Delete", "Guardar": "Save",
    // Horas
    "Fecha": "Date", "Horas trabajadas": "Hours worked", "Horas": "Hours",
    "Fase / tipo de trabajo": "Phase / type of work", "Notas (qué se hizo)": "Notes (what was done)",
    "✓ Guardar mi reporte": "✓ Save my report",
    "Mis reportes (toca ✎ para corregir)": "My reports (tap ✎ to fix)",
    "Notas (aquí puedes agregar lo que te faltó)": "Notes (add what you missed here)",
    // Calendario
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
    [/^hace (\d+) días sin reportar$/, "$1 days without reporting"],
    [/^material(es)? por comprar — toca para ver la lista$/, "material$1 to buy — tap to see the list"],
    [/para arrancar$/, s => s
      .replace("materiales", "materials").replace("material", "material")
      .replace("gestiones", "tasks").replace("gestión", "task")
      .replace(" y ", " and ").replace("para arrancar", "to start")],
    [/^➡ Próximo cobro:$/, "➡ Next collection:"]
  ];

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
    const walker = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) {
      const nuevo = traducirTexto(n.nodeValue);
      if (nuevo !== n.nodeValue) n.nodeValue = nuevo;
    }
    const conAttr = raiz.querySelectorAll ? raiz.querySelectorAll("[placeholder], [title]") : [];
    conAttr.forEach(el => {
      if (el.placeholder && D[el.placeholder]) el.placeholder = D[el.placeholder];
      if (el.title && D[el.title]) el.title = D[el.title];
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
