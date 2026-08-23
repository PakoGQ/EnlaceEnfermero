/* ==========================================================================
   Enlace Enfermero — Asignaciones (panel de la agencia)
   Seguimiento de turnos, asistencia e incidencias (CLAUDE.md 8.6).
   ========================================================================== */

const asign = { filas: [], filtro: '', desde: '', hasta: '' };

const COLUMNAS_ASIGNACION = [
  { titulo: 'Fecha',    valor: a => `<strong>${esc(fechaCorta(a.fecha))}</strong>
      <span class="texto-xs txt-tenue">${esc(hora(a.hora_inicio))} - ${esc(hora(a.hora_fin))}</span>`,
    crudo: a => a.fecha },
  { titulo: 'Profesional', valor: a => `${esc(a.enfermero)}
      <span class="texto-xs txt-tenue">${esc(a.folio_enfermero || '')} · ${esc(etiqueta(NIVELES, a.nivel))}</span>`,
    crudo: a => a.enfermero },
  { titulo: 'Cliente',  valor: a => `${esc(a.cliente)}
      <span class="texto-xs txt-tenue">${esc(a.folio_solicitud)}</span>`,
    crudo: a => a.cliente },
  { titulo: 'Turno',    valor: a => esc(etiqueta(TURNOS, a.turno).split(' (')[0]),
    crudo: a => a.turno },
  { titulo: 'Cliente paga', clase: 'num', valor: a => moneda(a.tarifa_cliente),
    crudo: a => a.tarifa_cliente },
  { titulo: 'Al profesional', clase: 'num', valor: a => moneda(a.tarifa_enfermero),
    crudo: a => a.tarifa_enfermero },
  { titulo: 'Comisión', clase: 'num', valor: a => `<strong>${moneda(a.comision_agencia)}</strong>`,
    crudo: a => a.comision_agencia },
  { titulo: 'Estatus',  valor: a => badge(ESTATUS_ASIGNACION, a.estatus) + marcaAsistencia(a),
    crudo: a => etiqueta(ESTATUS_ASIGNACION, a.estatus) },
  { titulo: '', clase: 'acciones', valor: a => botonesAsignacion(a), crudo: () => '' }
];

function marcaAsistencia(a) {
  if (!a.checkin_at) return '';
  return `<span class="texto-xs txt-tenue">Entró ${esc(hora(new Date(a.checkin_at).toTimeString().slice(0,8)))}
    ${a.checkout_at ? '· salió ' + esc(hora(new Date(a.checkout_at).toTimeString().slice(0,8))) : ''}</span>`;
}

function botonesAsignacion(a) {
  if (a.estatus === 'aceptada') {
    return `<button type="button" class="btn btn-exito btn-sm" data-entrada="${esc(a.id)}">Registrar entrada</button>`;
  }
  if (a.estatus === 'en_curso') {
    return `<button type="button" class="btn btn-primario btn-sm" data-salida="${esc(a.id)}">Registrar salida</button>`;
  }
  if (a.estatus === 'propuesta') {
    return `<button type="button" class="btn btn-secundario btn-sm" data-incidencia="${esc(a.id)}">Cancelar</button>`;
  }
  if (['completada', 'no_asistio', 'cancelada', 'rechazada'].includes(a.estatus)) {
    if (!a.motivo_rechazo) return '';

    // El motivo se muestra completo, no escondido en un `title`. Cuando el
    // profesional rechaza un turno desde su panel, ese texto es justo lo que el
    // coordinador necesita para reasignar con criterio; en un tooltip no se ve
    // en celular y en escritorio hay que adivinar que hay algo que leer.
    const rechazoDelProfesional = a.estatus === 'rechazada';
    return `
      <span class="motivo-asignacion ${rechazoDelProfesional ? 'motivo-rechazo' : 'motivo-incidencia'}">
        <strong>${rechazoDelProfesional ? 'No pudo:' : 'Incidencia:'}</strong>
        ${esc(a.motivo_rechazo)}
      </span>`;
  }
  return `<button type="button" class="btn btn-fantasma btn-sm" data-incidencia="${esc(a.id)}">Incidencia</button>`;
}

async function cargarAsignaciones() {
  const { datos, error } = await consultar(db.rpc('asignaciones_lista', {
    p_estatus: asign.filtro || null,
    p_desde: asign.desde || null,
    p_hasta: asign.hasta || null
  }));

  if (error) {
    document.getElementById('tabla').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar', texto: error });
    return;
  }

  asign.filas = datos || [];
  pintarTabla('tabla', asign.filas, COLUMNAS_ASIGNACION, {
    icono: 'calendario',
    titulo: 'Sin turnos con estos filtros',
    texto: 'Las asignaciones se crean al proponer personal desde una solicitud.'
  });

  // Totales del periodo mostrado
  const completadas = asign.filas.filter(a => a.estatus === 'completada');
  document.getElementById('resumen').innerHTML = `
    <span>${asign.filas.length} turnos</span>
    <span>Facturado <strong>${monedaCorta(completadas.reduce((s,a) => s + Number(a.tarifa_cliente), 0))}</strong></span>
    <span>Comisión <strong>${monedaCorta(completadas.reduce((s,a) => s + Number(a.comision_agencia), 0))}</strong></span>`;

  document.querySelectorAll('[data-entrada]').forEach(b =>
    b.addEventListener('click', () => asistencia(b.dataset.entrada, 'entrada')));
  document.querySelectorAll('[data-salida]').forEach(b =>
    b.addEventListener('click', () => asistencia(b.dataset.salida, 'salida')));
  document.querySelectorAll('[data-incidencia]').forEach(b =>
    b.addEventListener('click', () => registrarIncidencia(b.dataset.incidencia)));
}

async function asistencia(id, accion) {
  const { error } = await consultar(db.rpc('registrar_asistencia', { p_id: id, p_accion: accion }));
  if (error) { toast(error, 'error'); return; }
  toast(accion === 'entrada' ? 'Entrada registrada.' : 'Turno completado.', 'exito', 2500);
  cargarAsignaciones();
}

function registrarIncidencia(id) {
  const a = asign.filas.find(x => x.id === id);
  abrirFormulario({
    titulo: `Incidencia — ${a?.enfermero || ''}`,
    textoGuardar: 'Registrar',
    campos: [
      { nombre: 'estatus', etiqueta: '¿Qué pasó?', tipo: 'select', requerido: true,
        vacio: 'Selecciona',
        opciones: [
          { id: 'no_asistio', nombre: 'No se presentó' },
          { id: 'cancelada',  nombre: 'Se canceló el turno' },
          { id: 'rechazada',  nombre: 'El profesional rechazó la propuesta' }
        ] },
      { nombre: 'motivo', etiqueta: 'Motivo', tipo: 'textarea', requerido: true,
        nota: 'Queda en el historial de confiabilidad del profesional (regla 10.9).' }
    ],
    alGuardar: async (d) => {
      if (!d.motivo.trim()) { toast('Escribe el motivo.', 'error'); return false; }
      const { error } = await consultar(db.rpc('responder_asignacion_admin', {
        p_id: id, p_estatus: d.estatus, p_motivo: d.motivo
      }));
      if (error) { toast(error, 'error'); return false; }
      toast('Incidencia registrada.', 'info', 2500);
      cargarAsignaciones();
    }
  });
}

function iniciarAsignaciones() {
  const p = mesActual();
  asign.desde = p.desde;
  asign.hasta = p.hasta;
  document.getElementById('desde').value = p.desde;
  document.getElementById('hasta').value = p.hasta;

  // El filtro de la URL se lee ANTES de pintar los chips. Al reves, se llegaba
  // desde una alerta del panel con la lista ya filtrada pero con "Todos"
  // resaltado, y parecia que se estaban viendo todos los turnos.
  const estatus = paramURL('estatus');
  if (estatus) asign.filtro = estatus;

  pintarFiltros('filtros', [
    { id: '', texto: 'Todos' },
    { id: 'propuesta',  texto: 'Propuestas' },
    { id: 'aceptada',   texto: 'Aceptadas' },
    { id: 'en_curso',   texto: 'En curso' },
    { id: 'completada', texto: 'Completadas' },
    // Desde la Fase 3 el profesional rechaza desde su panel y deja un motivo,
    // asi que los rechazos dejaron de ser una rareza: merecen su propio filtro.
    { id: 'rechazada',  texto: 'Rechazadas' },
    { id: 'no_asistio', texto: 'Incidencias' }
  ], asign.filtro || '', (v) => { asign.filtro = v; cargarAsignaciones(); });

  ['desde', 'hasta'].forEach(id =>
    document.getElementById(id).addEventListener('change', () => {
      asign[id] = document.getElementById(id).value;
      cargarAsignaciones();
    }));

  document.getElementById('btnExportar').addEventListener('click', () =>
    exportarCSV('asignaciones', asign.filas, COLUMNAS_ASIGNACION.filter(c => c.titulo)));

  cargarAsignaciones();
}
