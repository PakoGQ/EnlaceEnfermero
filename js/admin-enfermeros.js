/* ==========================================================================
   Enlace Enfermero — Cartera de personal (panel de la agencia)
   Alta, edición, verificación y publicación (CLAUDE.md 8.6).
   ========================================================================== */

const cartera = { filas: [], filtro: null, texto: '' };

const COLUMNAS_ENFERMERO = [
  { titulo: 'Profesional', valor: e => `
      <div class="celda-persona">
        <span class="avatar-mini">${esc(iniciales(e.nombre_completo))}</span>
        <div>
          <strong>${esc(e.nombre_completo)}</strong>
          <span class="texto-xs txt-tenue">${esc(e.folio || 'sin folio')} · ${esc(etiqueta(NIVELES, e.nivel))}</span>
        </div>
      </div>`,
    crudo: e => e.nombre_completo },
  { titulo: 'Experiencia', clase: 'num', valor: e => `${e.anios_experiencia} años`,
    crudo: e => e.anios_experiencia },
  { titulo: 'Zonas', valor: e => (e.zonas_cobertura || []).length
      ? `<span class="texto-xs">${esc(e.zonas_cobertura.map(z => etiqueta(MUNICIPIOS, z)).join(', '))}</span>`
      : '<span class="txt-tenue">—</span>',
    crudo: e => (e.zonas_cobertura || []).join(' / ') },
  { titulo: 'Calificación', clase: 'num', valor: e => e.calificacion_promedio
      ? `★ ${Number(e.calificacion_promedio).toFixed(1)} <span class="texto-xs txt-tenue">(${e.total_servicios})</span>`
      : '<span class="txt-tenue">sin evaluar</span>',
    crudo: e => e.calificacion_promedio || '' },
  { titulo: 'Turnos del mes', clase: 'num', valor: e => e.turnos_mes, crudo: e => e.turnos_mes },
  { titulo: 'Documentos', valor: e => {
      const partes = [];
      if (e.docs_vencidos > 0)   partes.push(`<span class="badge badge-error">${e.docs_vencidos} vencidos</span>`);
      if (e.docs_pendientes > 0) partes.push(`<span class="badge badge-alerta">${e.docs_pendientes} por revisar</span>`);
      return partes.length ? partes.join(' ') : '<span class="badge badge-exito">Al día</span>';
    },
    crudo: e => `${e.docs_pendientes} pendientes, ${e.docs_vencidos} vencidos` },
  { titulo: 'Estado', valor: e => `${badge(ESTATUS_VERIFICACION, e.estatus_verificacion)}
      ${e.publicado ? '<span class="badge badge-exito">Publicado</span>' : ''}`,
    crudo: e => `${e.estatus_verificacion}${e.publicado ? ' / publicado' : ''}` },
  { titulo: '', clase: 'acciones', valor: e => `
      <a href="documentos.html?enfermero=${encodeURIComponent(e.id)}" class="btn btn-fantasma btn-sm">Expediente</a>
      <button type="button" class="btn btn-secundario btn-sm" data-editar="${esc(e.id)}">Editar</button>`,
    crudo: () => '' }
];

async function cargarCartera() {
  const { datos, error } = await consultar(db.rpc('enfermeros_admin', {
    p_texto: cartera.texto || null,
    p_estatus: cartera.filtro || null,
    p_publicado: null
  }));

  if (error) {
    document.getElementById('tabla').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar la cartera', texto: error });
    return;
  }

  cartera.filas = datos || [];
  pintarTabla('tabla', cartera.filas, COLUMNAS_ENFERMERO, {
    icono: 'usuarios',
    titulo: 'Sin personal con estos filtros',
    texto: 'Da de alta a alguien o cambia el filtro.'
  });

  document.getElementById('resumen').innerHTML = `
    <span>${cartera.filas.length} perfiles</span>
    <span>${cartera.filas.filter(e => e.publicado).length} en el catálogo</span>
    <span>${cartera.filas.filter(e => e.disponible_inmediato).length} disponibles ya</span>`;

  document.querySelectorAll('[data-editar]').forEach(b =>
    b.addEventListener('click', () => editarEnfermero(b.dataset.editar)));
}

function camposEnfermero() {
  return [
    { nombre: 'nombre_completo', etiqueta: 'Nombre completo', requerido: true },
    { nombre: 'nivel', etiqueta: 'Nivel', tipo: 'select', requerido: true, opciones: NIVELES },
    { nombre: 'anios_experiencia', etiqueta: 'Años de experiencia', tipo: 'number', min: 0 },
    { nombre: 'cedula_profesional', etiqueta: 'Cédula profesional',
      nota: 'Se valida contra el Registro Nacional de Profesionistas.' },
    { nombre: 'institucion_egreso', etiqueta: 'Institución de egreso' },
    { nombre: 'especialidades', etiqueta: 'Especialidades', tipo: 'checks', opciones: ESPECIALIDADES },
    { nombre: 'certificaciones', etiqueta: 'Certificaciones', tipo: 'checks', opciones: CERTIFICACIONES },
    { nombre: 'zonas_cobertura', etiqueta: 'Zonas de cobertura', tipo: 'checks', opciones: MUNICIPIOS },
    { nombre: 'bio', etiqueta: 'Descripción pública', tipo: 'textarea',
      nota: 'Máximo 600 caracteres. Es lo que ve el cliente.' },
    { nombre: 'tarifa_turno_8',  etiqueta: 'Tarifa turno 8 h',  tipo: 'number', min: 0, paso: 50 },
    { nombre: 'tarifa_turno_12', etiqueta: 'Tarifa turno 12 h', tipo: 'number', min: 0, paso: 50 },
    { nombre: 'tarifa_turno_24', etiqueta: 'Tarifa turno 24 h', tipo: 'number', min: 0, paso: 50,
      nota: 'Son tarifas de referencia para cotizar, no precios fijos.' },
    { nombre: 'disponible_inmediato', etiqueta: 'Disponible de inmediato', tipo: 'checkbox' },
    { nombre: 'acepta_domicilio', etiqueta: 'Atiende a domicilio', tipo: 'checkbox' },
    { nombre: 'acepta_nocturno',  etiqueta: 'Acepta turno nocturno', tipo: 'checkbox' },
    { nombre: 'acepta_foraneo',   etiqueta: 'Acepta servicios foráneos', tipo: 'checkbox' },
    { nombre: 'notas_internas', etiqueta: 'Notas internas', tipo: 'textarea',
      nota: 'Solo las ve la agencia. Nunca se muestran al cliente ni al profesional.' }
  ];
}

function nuevoEnfermero() {
  abrirFormulario({
    titulo: 'Dar de alta personal',
    textoGuardar: 'Crear perfil',
    campos: camposEnfermero(),
    valores: { acepta_domicilio: true },
    alGuardar: guardarEnfermero
  });
}

async function editarEnfermero(id) {
  const { datos, error } = await consultar(db.rpc('expediente_enfermero', { p_id: id }));
  if (error) { toast(error, 'error'); return; }

  abrirFormulario({
    titulo: `Editar — ${datos.enfermero.nombre_completo}`,
    campos: camposEnfermero(),
    valores: { ...datos.enfermero, id },
    alGuardar: (d) => guardarEnfermero({ ...d, id })
  });
}

async function guardarEnfermero(d) {
  if (!d.nombre_completo?.trim()) { toast('El nombre es obligatorio.', 'error'); return false; }
  if (!d.nivel) { toast('Elige el nivel.', 'error'); return false; }
  if (d.bio && d.bio.length > 600) { toast('La descripción no puede pasar de 600 caracteres.', 'error'); return false; }

  const { error } = await consultar(db.rpc('guardar_enfermero', { p_datos: d }));
  if (error) { toast(error, 'error'); return false; }

  toast(d.id ? 'Perfil actualizado.' : 'Perfil creado. Ahora sube sus documentos para verificarlo.',
        'exito', 3500);
  cargarCartera();
}

function iniciarEnfermeros() {
  pintarFiltros('filtros', [
    { id: '', texto: 'Todos' },
    { id: 'pendiente',   texto: 'Pendientes' },
    { id: 'en_revision', texto: 'En revisión' },
    { id: 'verificado',  texto: 'Verificados' },
    { id: 'rechazado',   texto: 'Rechazados' }
  ], '', (v) => { cartera.filtro = v || null; cargarCartera(); });

  document.getElementById('buscar').addEventListener('input', retardar(() => {
    cartera.texto = document.getElementById('buscar').value.trim();
    cargarCartera();
  }, 350));

  document.getElementById('btnNuevo').addEventListener('click', nuevoEnfermero);
  document.getElementById('btnExportar').addEventListener('click', () =>
    exportarCSV('personal', cartera.filas, COLUMNAS_ENFERMERO.filter(c => c.titulo)));

  const estatus = paramURL('estatus');
  if (estatus) cartera.filtro = estatus;

  cargarCartera();
}
