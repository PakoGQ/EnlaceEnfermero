/* ==========================================================================
   Enlace Enfermero — Verificación documental (panel de la agencia)
   Bandeja de revisión, visor de archivos y publicación de perfiles.
   ========================================================================== */

const bandeja = { documentos: [], filtro: 'pendiente', expediente: null };

const FILTROS = [
  { id: 'pendiente',   texto: 'Por revisar' },
  { id: 'en_revision', texto: 'En revisión' },
  { id: 'vencido',     texto: 'Vencidos' },
  { id: 'rechazado',   texto: 'Rechazados' },
  { id: 'verificado',  texto: 'Aprobados' },
  { id: '',            texto: 'Todos' }
];

/* ==========================================================================
   BANDEJA
   ========================================================================== */

async function cargarBandeja() {
  const zona = document.getElementById('listaDocumentos');
  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(
    db.rpc('documentos_bandeja', { p_estatus: bandeja.filtro || null })
  );

  if (error) {
    zona.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar la bandeja', texto: error });
    return;
  }

  bandeja.documentos = datos || [];
  pintarBandeja();
  pintarConteos();
}

async function pintarConteos() {
  // Un solo viaje: se cuentan todos y se reparten por estatus
  const { datos } = await consultar(db.rpc('documentos_bandeja', { p_estatus: null }));
  if (!datos) return;

  const porEstatus = datos.reduce((acc, d) => {
    acc[d.estatus] = (acc[d.estatus] || 0) + 1;
    return acc;
  }, {});

  document.querySelectorAll('[data-filtro]').forEach(b => {
    const id = b.dataset.filtro;
    const n = id ? (porEstatus[id] || 0) : datos.length;
    const marca = b.querySelector('.filtro-conteo');
    if (marca) marca.textContent = n;
    b.classList.toggle('vacio', n === 0);
  });
}

function pintarBandeja() {
  const zona = document.getElementById('listaDocumentos');

  if (!bandeja.documentos.length) {
    const etiquetaFiltro = FILTROS.find(f => f.id === bandeja.filtro)?.texto.toLowerCase() || '';
    zona.innerHTML = estadoVacio({
      icono: 'check',
      titulo: bandeja.filtro === 'pendiente' ? 'Nada por revisar' : `Sin documentos ${etiquetaFiltro}`,
      texto: bandeja.filtro === 'pendiente'
        ? 'Cuando alguien suba documentos aparecerán aquí para su revisión.'
        : 'Prueba con otro filtro.'
    });
    return;
  }

  // Se agrupan por profesional: se revisa un expediente, no documentos sueltos
  const porEnfermero = new Map();
  bandeja.documentos.forEach(d => {
    if (!porEnfermero.has(d.enfermero_id)) {
      porEnfermero.set(d.enfermero_id, { enfermero: d, docs: [] });
    }
    porEnfermero.get(d.enfermero_id).docs.push(d);
  });

  zona.innerHTML = [...porEnfermero.values()].map(({ enfermero: e, docs }) => `
    <article class="grupo-documentos">
      <header class="grupo-cabecera">
        <div class="grupo-persona">
          <span class="avatar-mini">${esc(iniciales(e.nombre_completo))}</span>
          <div>
            <strong>${esc(e.nombre_completo)}</strong>
            <span class="texto-xs txt-secundario">
              ${esc(e.folio || 'sin folio')} · ${esc(etiqueta(NIVELES, e.nivel))}
            </span>
          </div>
        </div>
        <button type="button" class="btn btn-secundario btn-sm"
                data-expediente="${esc(e.enfermero_id)}">Ver expediente</button>
      </header>

      <div class="grupo-lista">
        ${docs.map(filaDocumento).join('')}
      </div>
    </article>`).join('');

  zona.querySelectorAll('[data-expediente]').forEach(b =>
    b.addEventListener('click', () => abrirExpediente(b.dataset.expediente)));
  zona.querySelectorAll('[data-ver-doc]').forEach(b =>
    b.addEventListener('click', () => abrirVisor(b.dataset.verDoc)));
}

function filaDocumento(d) {
  const vence = d.dias_para_vencer;
  let avisoVigencia = '';

  if (vence !== null && vence !== undefined) {
    if (vence < 0) {
      avisoVigencia = `<span class="vigencia vencida">Venció hace ${Math.abs(vence)} días</span>`;
    } else if (vence <= 30) {
      avisoVigencia = `<span class="vigencia proxima">Vence en ${vence} días</span>`;
    } else {
      avisoVigencia = `<span class="vigencia">Vigente hasta ${esc(fechaCorta(d.fecha_vencimiento))}</span>`;
    }
  }

  return `
    <div class="fila-documento" data-doc="${esc(d.id)}">
      <span class="doc-icono">${icono('documento', 18)}</span>

      <div class="doc-datos">
        <strong>
          ${esc(etiqueta(TIPOS_DOCUMENTO, d.tipo))}
          ${d.obligatorio ? '<span class="marca-obligatorio" title="Obligatorio para su nivel">*</span>' : ''}
        </strong>
        <span class="texto-xs txt-secundario">
          Subido ${horasLegibles(d.subido_hace)} atrás
          ${d.revisado_por ? ' · revisó ' + esc(d.revisado_por) : ''}
        </span>
        ${avisoVigencia}
        ${d.motivo_rechazo ? `<span class="doc-motivo">${esc(d.motivo_rechazo)}</span>` : ''}
      </div>

      <div class="doc-acciones">
        ${badge(ESTATUS_VERIFICACION, d.estatus)}
        <button type="button" class="btn btn-fantasma btn-sm" data-ver-doc="${esc(d.id)}">Abrir</button>
      </div>
    </div>`;
}

/* ==========================================================================
   VISOR
   Los archivos viven en un bucket privado: hay que pedir una URL firmada,
   que caduca sola. Nunca se expone la ruta directa (CLAUDE.md 6).
   ========================================================================== */

async function abrirVisor(documentoId) {
  const doc = bandeja.documentos.find(d => d.id === documentoId)
           || bandeja.expediente?.documentos.find(d => d.id === documentoId);
  if (!doc) return;

  const modal = document.getElementById('modalVisor');
  modal.classList.add('abierto');

  const cuerpo = document.getElementById('visorCuerpo');
  cuerpo.innerHTML = '<div class="spinner"></div>';

  document.getElementById('visorTitulo').textContent =
    etiqueta(TIPOS_DOCUMENTO, doc.tipo);
  document.getElementById('visorSubtitulo').textContent =
    doc.nombre_completo || bandeja.expediente?.enfermero?.nombre_completo || '';

  // El bucket puede venir incluido en la ruta guardada
  const ruta = String(doc.archivo_url || '').replace(/^documentos\//, '');
  const { data, error } = await db.storage.from('documentos').createSignedUrl(ruta, 300);

  if (error || !data?.signedUrl) {
    cuerpo.innerHTML = `
      <div class="visor-sin-archivo">
        ${icono('documento', 40)}
        <h4>No se pudo abrir el archivo</h4>
        <p>${esc(error?.message || 'El archivo no está en el almacenamiento.')}</p>
        <p class="texto-xs txt-tenue">Ruta registrada: ${esc(doc.archivo_url || 'ninguna')}</p>
      </div>`;
  } else {
    const esImagen = /\.(jpe?g|png|webp)$/i.test(ruta);
    cuerpo.innerHTML = esImagen
      ? `<img src="${esc(data.signedUrl)}" alt="Documento" class="visor-imagen">`
      : `<iframe src="${esc(data.signedUrl)}" class="visor-marco" title="Documento"></iframe>`;
  }

  pintarAccionesVisor(doc);
}

function pintarAccionesVisor(doc) {
  const pie = document.getElementById('visorPie');
  const yaResuelto = ['verificado', 'rechazado'].includes(doc.estatus);

  pie.innerHTML = `
    <div class="visor-estado">
      ${badge(ESTATUS_VERIFICACION, doc.estatus)}
      ${doc.fecha_vencimiento
        ? `<span class="texto-xs txt-secundario">Vence ${esc(fechaCorta(doc.fecha_vencimiento))}</span>`
        : ''}
    </div>
    <div class="visor-botones">
      <button type="button" class="btn btn-peligro" data-rechazar="${esc(doc.id)}">Rechazar</button>
      <button type="button" class="btn btn-exito" data-aprobar="${esc(doc.id)}"
              ${doc.dias_para_vencer !== null && doc.dias_para_vencer < 0 ? 'disabled title="Está vencido"' : ''}>
        Aprobar
      </button>
    </div>
    ${yaResuelto ? '<p class="texto-xs txt-tenue">Ya fue revisado; puedes cambiar la decisión.</p>' : ''}`;

  pie.querySelector('[data-aprobar]')?.addEventListener('click', () => revisar(doc.id, true));
  pie.querySelector('[data-rechazar]')?.addEventListener('click', () => pedirMotivo(doc.id));
}

function cerrarVisor() {
  document.getElementById('modalVisor').classList.remove('abierto');
  document.getElementById('visorCuerpo').innerHTML = '';
}

/* ==========================================================================
   REVISAR
   ========================================================================== */

/** Un rechazo sin explicación deja al candidato sin saber qué corregir. */
function pedirMotivo(documentoId) {
  const cuerpo = document.getElementById('visorPie');
  cuerpo.innerHTML = `
    <form class="form-rechazo" id="formRechazo">
      <label for="motivoRechazo">¿Por qué se rechaza?</label>
      <textarea id="motivoRechazo" required rows="2"
        placeholder="Ejemplo: la identificación está borrosa, vuelve a escanearla completa."></textarea>
      <div class="visor-botones">
        <button type="button" class="btn btn-fantasma" id="btnCancelarRechazo">Cancelar</button>
        <button type="submit" class="btn btn-peligro">Rechazar documento</button>
      </div>
      <ul class="motivos-rapidos">
        ${['Imagen borrosa o ilegible', 'El documento está incompleto',
           'No corresponde al tipo solicitado', 'Está vencido']
          .map(m => `<li><button type="button" data-motivo="${esc(m)}">${esc(m)}</button></li>`).join('')}
      </ul>
    </form>`;

  const campo = document.getElementById('motivoRechazo');
  campo.focus();

  cuerpo.querySelectorAll('[data-motivo]').forEach(b =>
    b.addEventListener('click', () => { campo.value = b.dataset.motivo; campo.focus(); }));

  document.getElementById('btnCancelarRechazo').addEventListener('click', () => {
    const doc = bandeja.documentos.find(d => d.id === documentoId)
             || bandeja.expediente?.documentos.find(d => d.id === documentoId);
    pintarAccionesVisor(doc);
  });

  document.getElementById('formRechazo').addEventListener('submit', (e) => {
    e.preventDefault();
    if (!campo.value.trim()) {
      toast('Escribe el motivo del rechazo.', 'error');
      return;
    }
    revisar(documentoId, false, campo.value.trim());
  });
}

async function revisar(documentoId, aprobado, motivo = null) {
  const { datos, error } = await consultar(
    db.rpc('revisar_documento', {
      p_id: documentoId, p_aprobado: aprobado, p_motivo: motivo
    })
  );

  if (error) { toast(error, 'error'); return; }

  toast(aprobado ? 'Documento aprobado.' : 'Documento rechazado.',
        aprobado ? 'exito' : 'info', 2500);

  cerrarVisor();
  bandeja.expediente = datos;

  // Si el expediente quedó completo, se ofrece publicar sin dar más vueltas
  if (aprobado && datos?.puede_verificarse &&
      datos.enfermero?.estatus_verificacion !== 'verificado') {
    ofrecerVerificacion(datos);
  } else if (document.getElementById('panelExpediente').classList.contains('abierto')) {
    pintarExpediente(datos);
  }

  cargarBandeja();
}

function ofrecerVerificacion(exp) {
  const e = exp.enfermero;
  const modal = document.getElementById('modalVerificar');
  modal.classList.add('abierto');
  document.getElementById('verificarCuerpo').innerHTML = `
    <div class="verificar-icono">${icono('escudo', 34)}</div>
    <h3>El expediente de ${esc(e.nombre_completo)} está completo</h3>
    <p>Entregó y tiene aprobados todos los documentos que exige su nivel
       (${esc(etiqueta(NIVELES, e.nivel))}). Puedes marcarlo como verificado
       y publicarlo en el catálogo.</p>
    <div class="verificar-acciones">
      <button type="button" class="btn btn-fantasma" id="btnAhoraNo">Ahora no</button>
      <button type="button" class="btn btn-secundario" id="btnSoloVerificar">Verificar sin publicar</button>
      <button type="button" class="btn btn-primario" id="btnVerificarPublicar">Verificar y publicar</button>
    </div>`;

  document.getElementById('btnAhoraNo').addEventListener('click', cerrarVerificar);
  document.getElementById('btnSoloVerificar').addEventListener('click', () => verificar(e.id, false));
  document.getElementById('btnVerificarPublicar').addEventListener('click', () => verificar(e.id, true));
}

function cerrarVerificar() {
  document.getElementById('modalVerificar').classList.remove('abierto');
  // Se vacia para que no queden botones de una decision ya tomada
  document.getElementById('verificarCuerpo').innerHTML = '';
}

async function verificar(enfermeroId, publicar) {
  const { datos, error } = await consultar(
    db.rpc('verificar_enfermero', { p_id: enfermeroId, p_publicar: publicar })
  );

  if (error) { toast(error, 'error'); return; }

  cerrarVerificar();
  toast(publicar ? 'Perfil verificado y publicado en el catálogo.' : 'Perfil verificado.',
        'exito', 3500);

  bandeja.expediente = datos;
  if (document.getElementById('panelExpediente').classList.contains('abierto')) {
    pintarExpediente(datos);
  }
  cargarBandeja();
}

/* ==========================================================================
   EXPEDIENTE
   ========================================================================== */

async function abrirExpediente(enfermeroId) {
  const panel = document.getElementById('panelExpediente');
  panel.classList.add('abierto');
  document.getElementById('veloExpediente').classList.add('abierto');
  document.body.style.overflow = 'hidden';
  panel.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(db.rpc('expediente_enfermero', { p_id: enfermeroId }));

  if (error) {
    panel.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos abrir el expediente', texto: error });
    return;
  }

  bandeja.expediente = datos;
  pintarExpediente(datos);
}

function cerrarExpediente() {
  document.getElementById('panelExpediente').classList.remove('abierto');
  document.getElementById('veloExpediente').classList.remove('abierto');
  document.body.style.overflow = '';
}

function pintarExpediente(exp) {
  const e = exp.enfermero;
  const panel = document.getElementById('panelExpediente');
  const obligatorios = exp.obligatorios || [];
  const faltantes = exp.faltantes || [];
  const listos = obligatorios.length - faltantes.length;
  const avance = obligatorios.length ? Math.round((listos / obligatorios.length) * 100) : 0;

  panel.innerHTML = `
    <header class="detalle-cabecera">
      <div>
        <h2>${esc(e.nombre_completo)}</h2>
        <span class="texto-sm txt-secundario">
          ${esc(e.folio || 'sin folio')} · ${esc(etiqueta(NIVELES, e.nivel))}
        </span>
        <div class="flex gap-2 envuelve" style="margin-top:var(--e2)">
          ${badge(ESTATUS_VERIFICACION, e.estatus_verificacion)}
          ${e.publicado
            ? '<span class="badge badge-exito">En el catálogo</span>'
            : '<span class="badge badge-gris">Sin publicar</span>'}
        </div>
      </div>
      <button type="button" class="btn-icono" id="btnCerrarExpediente" aria-label="Cerrar">
        ${icono('cerrar', 20)}
      </button>
    </header>

    <div class="detalle-cuerpo">

      <section class="detalle-bloque">
        <h3>Avance de la verificación</h3>
        <div class="avance-barra">
          <div class="avance-relleno ${avance === 100 ? 'completo' : ''}" style="width:${avance}%"></div>
        </div>
        <p class="texto-sm txt-secundario">
          ${listos} de ${obligatorios.length} documentos obligatorios aprobados
          ${exp.tiene_vencidos ? ' · <span class="txt-error">tiene documentos vencidos</span>' : ''}
        </p>

        ${faltantes.length ? `
          <div class="faltantes">
            <strong>Falta aprobar:</strong>
            ${faltantes.map(t => `<span class="chip chip-neutro">${esc(etiqueta(TIPOS_DOCUMENTO, t))}</span>`).join('')}
          </div>` : ''}

        <div class="expediente-acciones">
          ${exp.puede_verificarse && !exp.tiene_vencidos && e.estatus_verificacion !== 'verificado'
            ? `<button type="button" class="btn btn-primario btn-bloque" data-verificar="${esc(e.id)}">
                 Verificar y publicar
               </button>`
            : ''}
          ${e.publicado
            ? `<button type="button" class="btn btn-secundario btn-bloque" data-despublicar="${esc(e.id)}">
                 Quitar del catálogo
               </button>`
            : ''}
          <a href="../perfil.html?id=${encodeURIComponent(e.id)}" target="_blank" rel="noopener"
             class="btn btn-fantasma btn-bloque btn-sm">Ver como lo ve el cliente</a>
        </div>
      </section>

      <section class="detalle-bloque">
        <h3>Documentos <span class="conteo-inline">${exp.documentos.length}</span></h3>
        ${exp.documentos.length
          ? `<div class="grupo-lista">${exp.documentos.map(d => filaDocumento({
               ...d,
               subido_hace: 0,
               dias_para_vencer: d.fecha_vencimiento
                 ? Math.round((new Date(d.fecha_vencimiento) - new Date()) / 86400000)
                 : null
             })).join('')}</div>`
          : '<p class="texto-sm txt-tenue">Todavía no ha subido nada.</p>'}
      </section>

      <section class="detalle-bloque">
        <h3>Datos del perfil</h3>
        <dl class="detalle-datos">
          <div><dt>Experiencia</dt><dd>${esc(e.anios_experiencia)} años</dd></div>
          <div>
            <dt>Cédula</dt>
            <dd>${e.cedula_profesional
              ? esc(e.cedula_profesional)
              : (NIVELES_CON_CEDULA.includes(e.nivel)
                  // Su nivel la exige: que no este capturada es un pendiente,
                  // no un "no aplica"
                  ? '<span class="txt-error">Falta capturarla</span>'
                  : '<span class="txt-tenue">No aplica a su nivel</span>')}</dd>
          </div>
          <div><dt>Institución</dt><dd>${esc(e.institucion_egreso || '—')}</dd></div>
          <div><dt>Servicios</dt><dd>${esc(e.total_servicios || 0)}</dd></div>
        </dl>
        <h4>Especialidades</h4>
        <div class="chips-linea">
          ${(e.especialidades || []).length
            ? e.especialidades.map(i => `<span class="chip">${esc(etiqueta(ESPECIALIDADES, i))}</span>`).join('')
            : '<span class="txt-tenue texto-sm">Sin declarar</span>'}
        </div>
        <h4>Certificaciones</h4>
        <div class="chips-linea">
          ${(e.certificaciones || []).length
            ? e.certificaciones.map(i => `<span class="chip chip-neutro">${esc(etiqueta(CERTIFICACIONES, i))}</span>`).join('')
            : '<span class="txt-tenue texto-sm">Sin declarar</span>'}
        </div>
      </section>

    </div>`;

  document.getElementById('btnCerrarExpediente').addEventListener('click', cerrarExpediente);
  panel.querySelectorAll('[data-ver-doc]').forEach(b =>
    b.addEventListener('click', () => abrirVisor(b.dataset.verDoc)));
  panel.querySelector('[data-verificar]')?.addEventListener('click', (ev) =>
    verificar(ev.target.dataset.verificar, true));
  panel.querySelector('[data-despublicar]')?.addEventListener('click', (ev) =>
    despublicar(ev.target.dataset.despublicar));
}

async function despublicar(enfermeroId) {
  const motivo = prompt('¿Por qué se quita del catálogo? (queda en notas internas)');
  if (motivo === null) return;

  const { error } = await consultar(
    db.rpc('despublicar_enfermero', { p_id: enfermeroId, p_motivo: motivo })
  );
  if (error) { toast(error, 'error'); return; }

  toast('El perfil salió del catálogo.', 'info', 2500);
  abrirExpediente(enfermeroId);
  cargarBandeja();
}

/* ==========================================================================
   ARRANQUE
   ========================================================================== */

function iniciarDocumentos() {
  const zonaFiltros = document.getElementById('filtros');
  zonaFiltros.innerHTML = FILTROS.map(f => `
    <button type="button" class="filtro ${f.id === bandeja.filtro ? 'activo' : ''}"
            data-filtro="${f.id}">
      ${esc(f.texto)} <span class="filtro-conteo">0</span>
    </button>`).join('');

  zonaFiltros.querySelectorAll('[data-filtro]').forEach(b =>
    b.addEventListener('click', () => {
      bandeja.filtro = b.dataset.filtro;
      zonaFiltros.querySelectorAll('.filtro').forEach(x => x.classList.remove('activo'));
      b.classList.add('activo');
      cargarBandeja();
    }));

  document.getElementById('veloExpediente').addEventListener('click', cerrarExpediente);
  document.getElementById('visorCerrar').addEventListener('click', cerrarVisor);
  document.getElementById('modalVisor').addEventListener('click', (e) => {
    if (e.target.id === 'modalVisor') cerrarVisor();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (document.getElementById('modalVisor').classList.contains('abierto')) cerrarVisor();
    else if (document.getElementById('modalVerificar').classList.contains('abierto')) cerrarVerificar();
    else if (document.getElementById('panelExpediente').classList.contains('abierto')) cerrarExpediente();
  });

  const id = paramURL('enfermero');
  if (id) abrirExpediente(id);

  const estatus = paramURL('estatus');
  if (estatus) bandeja.filtro = estatus;
  if (paramURL('por_vencer')) bandeja.filtro = '';

  cargarBandeja();
}
