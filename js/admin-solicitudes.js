/* ==========================================================================
   Enlace Enfermero — Solicitudes (panel de la agencia)
   Tablero por estatus y panel de detalle con sugerencia de personal.
   ========================================================================== */

const COLUMNAS = [
  { estatus: 'nueva',             titulo: 'Nuevas',      ayuda: 'Sin revisar' },
  { estatus: 'en_busqueda',       titulo: 'En búsqueda', ayuda: 'Buscando personal' },
  { estatus: 'propuesta_enviada', titulo: 'Propuestas',  ayuda: 'Esperando respuesta' },
  { estatus: 'confirmada',        titulo: 'Confirmadas', ayuda: 'Personal aceptado' },
  { estatus: 'en_curso',          titulo: 'En curso',    ayuda: 'Servicio activo' },
  { estatus: 'completada',        titulo: 'Completadas', ayuda: 'Cerradas' }
];

const tablero = { solicitudes: [], abierta: null };

/* ==========================================================================
   TABLERO
   ========================================================================== */

async function cargarTablero() {
  const zona = document.getElementById('tablero');
  const { datos, error } = await consultar(db.rpc('solicitudes_tablero'));

  if (error) {
    zona.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar el tablero', texto: error });
    return;
  }

  tablero.solicitudes = datos || [];
  pintarTablero();
}

function pintarTablero() {
  const zona = document.getElementById('tablero');

  zona.innerHTML = COLUMNAS.map(col => {
    const items = tablero.solicitudes.filter(s => s.estatus === col.estatus);
    return `
      <section class="columna" data-estatus="${col.estatus}" aria-label="${esc(col.titulo)}">
        <header class="columna-cabecera">
          <div>
            <h2>${esc(col.titulo)}</h2>
            <span>${esc(col.ayuda)}</span>
          </div>
          <span class="columna-conteo">${items.length}</span>
        </header>
        <div class="columna-cuerpo" data-zona="${col.estatus}">
          ${items.length
            ? items.map(tarjetaSolicitud).join('')
            : '<p class="columna-vacia">Nada por aquí</p>'}
        </div>
      </section>`;
  }).join('');

  activarArrastre();

  zona.querySelectorAll('[data-abrir]').forEach(el =>
    el.addEventListener('click', () => abrirSolicitud(el.dataset.abrir)));
}

function tarjetaSolicitud(s) {
  const espera = s.horas_esperando;
  const tarde = espera > 24 && ['nueva', 'en_busqueda'].includes(s.estatus);
  const faltan = s.cantidad - Number(s.aceptados);
  const cerrada = ['completada', 'cancelada'].includes(s.estatus);

  return `
    <article class="tarjeta-solicitud${s.urgente ? ' urgente' : ''}"
             draggable="true" data-id="${esc(s.id)}" data-abrir="${esc(s.id)}"
             tabindex="0" role="button" aria-label="Abrir ${esc(s.folio)}">
      <div class="ts-cabecera">
        <strong>${esc(s.folio)}</strong>
        ${s.urgente ? '<span class="badge badge-error">Urgente</span>' : ''}
      </div>

      <p class="ts-cliente">${esc(s.cliente)}</p>

      <div class="ts-datos">
        <span>${icono('calendario', 14)}${esc(fechaCorta(s.fecha_inicio))}</span>
        <span>${icono('ubicacion', 14)}${esc(etiqueta(MUNICIPIOS, s.municipio))}</span>
      </div>

      <div class="ts-chips">
        ${s.nivel_requerido ? `<span class="chip chip-neutro">${esc(etiqueta(NIVELES, s.nivel_requerido))}</span>` : ''}
        ${s.nivel_atencion ? `<span class="chip">${esc(etiqueta(NIVELES_ATENCION, s.nivel_atencion))}</span>` : ''}
      </div>

      <div class="ts-pie">
        ${cerrada
          // En una solicitud cerrada, "cubierto" no dice nada: puede tener
          // decenas de turnos con una sola persona por turno. Interesa
          // cuantos turnos se sirvieron.
          ? `<span class="ts-cobertura completa">
               ${s.asignados} turno${Number(s.asignados) === 1 ? '' : 's'}
             </span>`
          : `<span class="ts-cobertura ${faltan > 0 ? 'incompleta' : 'completa'}">
               ${Math.min(s.aceptados, s.cantidad)}/${s.cantidad} cubierto${s.cantidad > 1 ? 's' : ''}
             </span>`}
        <span class="ts-espera ${tarde ? 'tarde' : ''}">
          ${cerrada ? esc(fechaCorta(s.fecha_inicio)) : horasLegibles(espera)}
        </span>
      </div>
    </article>`;
}

/* ==========================================================================
   ARRASTRE
   Con alternativa por teclado: arrastrar no es accesible por si solo.
   ========================================================================== */

function activarArrastre() {
  let arrastrando = null;

  document.querySelectorAll('.tarjeta-solicitud').forEach(t => {
    t.addEventListener('dragstart', (e) => {
      arrastrando = t.dataset.id;
      t.classList.add('arrastrando');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', t.dataset.id);
    });
    t.addEventListener('dragend', () => {
      arrastrando = null;
      t.classList.remove('arrastrando');
      document.querySelectorAll('.columna-cuerpo').forEach(c => c.classList.remove('encima'));
    });
    // Enter o espacio abren la solicitud, donde se puede cambiar el estatus
    t.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        abrirSolicitud(t.dataset.id);
      }
    });
  });

  document.querySelectorAll('.columna-cuerpo').forEach(zona => {
    zona.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      zona.classList.add('encima');
    });
    zona.addEventListener('dragleave', () => zona.classList.remove('encima'));
    zona.addEventListener('drop', async (e) => {
      e.preventDefault();
      zona.classList.remove('encima');
      const id = e.dataTransfer.getData('text/plain') || arrastrando;
      if (id) await moverSolicitud(id, zona.dataset.zona);
    });
  });
}

async function moverSolicitud(id, nuevoEstatus) {
  const solicitud = tablero.solicitudes.find(s => s.id === id);
  if (!solicitud || solicitud.estatus === nuevoEstatus) return;

  const anterior = solicitud.estatus;
  // Se mueve en pantalla de inmediato y se revierte si la base la rechaza
  solicitud.estatus = nuevoEstatus;
  pintarTablero();

  const { error } = await consultar(
    db.rpc('cambiar_estatus_solicitud', { p_id: id, p_estatus: nuevoEstatus })
  );

  if (error) {
    solicitud.estatus = anterior;
    pintarTablero();
    toast(error, 'error');
    return;
  }

  toast(`${solicitud.folio} pasó a ${etiqueta(ESTATUS_SOLICITUD, nuevoEstatus).toLowerCase()}.`, 'exito', 2500);
}

/* ==========================================================================
   DETALLE
   ========================================================================== */

async function abrirSolicitud(id) {
  const panel = document.getElementById('panelDetalle');
  const velo  = document.getElementById('veloDetalle');

  panel.classList.add('abierto');
  velo.classList.add('abierto');
  document.body.style.overflow = 'hidden';
  panel.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(db.rpc('detalle_solicitud', { p_id: id }));

  if (error) {
    panel.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos abrirla', texto: error });
    return;
  }

  tablero.abierta = datos;
  pintarDetalle(datos);
  cargarSugerencias(id);
}

function cerrarDetalle() {
  document.getElementById('panelDetalle').classList.remove('abierto');
  document.getElementById('veloDetalle').classList.remove('abierto');
  document.body.style.overflow = '';
  tablero.abierta = null;
}

function pintarDetalle({ solicitud: s, cliente, asignaciones }) {
  const panel = document.getElementById('panelDetalle');
  const lista = (arr, cat) => (arr || []).length
    ? arr.map(i => `<span class="chip">${esc(etiqueta(cat, i))}</span>`).join('')
    : '<span class="txt-tenue texto-sm">Sin especificar</span>';

  panel.innerHTML = `
    <header class="detalle-cabecera">
      <div>
        <span class="texto-xs txt-secundario">${esc(fechaHora(s.created_at))}</span>
        <h2>${esc(s.folio)} ${s.urgente ? '<span class="badge badge-error">Urgente</span>' : ''}</h2>
        ${badge(ESTATUS_SOLICITUD, s.estatus)}
      </div>
      <button type="button" class="btn-icono" id="btnCerrarDetalle" aria-label="Cerrar">
        ${icono('cerrar', 20)}
      </button>
    </header>

    <div class="detalle-cuerpo">

      <section class="detalle-bloque">
        <h3>Quién solicita</h3>
        <p class="detalle-cliente">
          <strong>${esc(cliente?.razon_social || cliente?.nombre_contacto || s.contacto_nombre || 'Sin nombre')}</strong>
          ${cliente?.tipo ? `<span class="chip chip-neutro">${esc(etiqueta(TIPOS_CLIENTE, cliente.tipo))}</span>` : ''}
        </p>
        <div class="detalle-contacto">
          ${(cliente?.telefono || s.contacto_telefono)
            ? `<a href="tel:${esc(cliente?.telefono || s.contacto_telefono)}">
                 ${icono('telefono', 15)}${esc(telefonoLegible(cliente?.telefono || s.contacto_telefono))}</a>`
            : ''}
          ${(cliente?.email || s.contacto_email)
            ? `<a href="mailto:${esc(cliente?.email || s.contacto_email)}">
                 ${icono('correo', 15)}${esc(cliente?.email || s.contacto_email)}</a>`
            : ''}
        </div>
      </section>

      <section class="detalle-bloque">
        <h3>Qué necesita</h3>
        <dl class="detalle-datos">
          <div><dt>Servicio</dt><dd>${esc(etiqueta(TIPOS_SERVICIO, s.tipo_servicio))}</dd></div>
          <div><dt>Entorno</dt><dd>${esc(etiqueta(ENTORNOS, s.entorno))}</dd></div>
          <div><dt>Paciente</dt><dd>${esc(etiqueta(TIPOS_PACIENTE, s.tipo_paciente))}</dd></div>
          <div><dt>Nivel de atención</dt><dd>${esc(etiqueta(NIVELES_ATENCION, s.nivel_atencion))}</dd></div>
          <div><dt>Nivel pedido</dt><dd>${esc(etiqueta(NIVELES, s.nivel_requerido)) || 'Cualquiera'}</dd></div>
          <div><dt>Personas</dt><dd>${esc(s.cantidad_enfermeros)}</dd></div>
          <div><dt>Inicia</dt><dd>${esc(fechaLarga(s.fecha_inicio))}</dd></div>
          <div><dt>Turno</dt><dd>${esc(etiqueta(TURNOS, s.turno)) || 'Por definir'}</dd></div>
          <div><dt>Zona</dt><dd>${esc(etiqueta(MUNICIPIOS, s.municipio))}</dd></div>
        </dl>

        <h4>Procedimientos</h4>
        <div class="chips-linea">${lista(s.procedimientos, PROCEDIMIENTOS)}</div>

        ${s.especialidad_requerida?.length ? `
          <h4>Especialidades pedidas</h4>
          <div class="chips-linea">${lista(s.especialidad_requerida, ESPECIALIDADES)}</div>` : ''}

        ${s.descripcion_paciente ? `
          <h4>Lo que nos contaron</h4>
          <p class="detalle-descripcion">${esc(s.descripcion_paciente)}</p>` : ''}
      </section>

      <section class="detalle-bloque">
        <h3>Cotización</h3>
        <p class="texto-sm txt-secundario">
          Lo que se le factura al cliente por turno. Del total, el ${Math.round(CONFIG.PORCENTAJE_ENFERMERO * 100)}%
          va al profesional y el ${Math.round(CONFIG.COMISION_AGENCIA * 100)}% queda como comisión.
        </p>
        <form class="fila-cotizar" id="formCotizar">
          <div class="campo">
            <label for="inpTarifa" class="solo-lectores">Tarifa al cliente</label>
            <input type="number" id="inpTarifa" min="0" step="50"
                   value="${s.tarifa_ofrecida_cliente ?? ''}" placeholder="0.00">
          </div>
          <button type="submit" class="btn btn-secundario">Guardar</button>
        </form>
        <div class="reparto-vista" id="repartoVista"></div>
      </section>

      <section class="detalle-bloque">
        <h3>Personal propuesto <span class="conteo-inline">${asignaciones.length}</span></h3>
        <div id="listaAsignaciones">${pintarAsignaciones(asignaciones)}</div>
      </section>

      <section class="detalle-bloque">
        <h3>A quién sugerimos</h3>
        <p class="texto-sm txt-secundario">
          Ordenados por qué tan bien encajan con lo que pidió el cliente.
        </p>
        <div id="sugerencias"><div class="spinner"></div></div>
      </section>

    </div>`;

  document.getElementById('btnCerrarDetalle').addEventListener('click', cerrarDetalle);
  document.getElementById('formCotizar').addEventListener('submit', guardarCotizacion);
  document.getElementById('inpTarifa').addEventListener('input', mostrarReparto);
  mostrarReparto();
}

/** Muestra en vivo cómo se reparte la tarifa capturada. */
function mostrarReparto() {
  const zona = document.getElementById('repartoVista');
  const valor = Number(document.getElementById('inpTarifa')?.value) || 0;
  if (!zona) return;

  if (!valor) {
    zona.innerHTML = '<p class="texto-sm txt-tenue">Captura la tarifa para ver el reparto.</p>';
    return;
  }

  const r = repartir(valor);
  zona.innerHTML = `
    <div class="reparto-barra">
      <div class="reparto-parte enfermero" style="flex:${CONFIG.PORCENTAJE_ENFERMERO}">
        <span>Profesional</span><strong>${moneda(r.enfermero)}</strong>
      </div>
      <div class="reparto-parte agencia" style="flex:${CONFIG.COMISION_AGENCIA}">
        <span>Agencia</span><strong>${moneda(r.agencia)}</strong>
      </div>
    </div>`;
}

async function guardarCotizacion(e) {
  e.preventDefault();
  const campo = document.getElementById('inpTarifa');
  const valor = Number(campo.value);

  if (!valor || valor <= 0) {
    toast('Captura un monto mayor a cero.', 'error');
    return;
  }

  const { error } = await consultar(
    db.rpc('cotizar_solicitud', { p_id: tablero.abierta.solicitud.id, p_tarifa: valor })
  );

  if (error) { toast(error, 'error'); return; }

  tablero.abierta.solicitud.tarifa_ofrecida_cliente = valor;
  toast('Cotización guardada.', 'exito', 2500);
}

function pintarAsignaciones(asignaciones) {
  if (!asignaciones.length) {
    return '<p class="texto-sm txt-tenue">Todavía no se ha propuesto a nadie.</p>';
  }

  return `<div class="lista-asignaciones">${asignaciones.map(a => `
    <div class="asignacion-fila">
      <div class="asignacion-persona">
        <span class="avatar-mini">${esc(iniciales(a.enfermero.nombre_completo))}</span>
        <div>
          <strong>${esc(a.enfermero.nombre_completo)}</strong>
          <span class="texto-xs txt-secundario">
            ${esc(fechaCorta(a.fecha))} · ${esc(etiqueta(TURNOS, a.turno).split(' (')[0])}
            · ${moneda(a.tarifa_enfermero)}
          </span>
        </div>
      </div>
      <div class="asignacion-estado">
        ${badge(ESTATUS_ASIGNACION, a.estatus)}
        ${a.motivo_rechazo ? `<span class="texto-xs txt-error">${esc(a.motivo_rechazo)}</span>` : ''}
      </div>
    </div>`).join('')}</div>`;
}

/* ==========================================================================
   SUGERENCIAS
   ========================================================================== */

async function cargarSugerencias(solicitudId) {
  const zona = document.getElementById('sugerencias');
  if (!zona) return;

  const { datos, error } = await consultar(
    db.rpc('sugerir_enfermeros', { p_solicitud_id: solicitudId, p_limite: 10 })
  );

  if (error) {
    zona.innerHTML = `<p class="texto-sm txt-error">${esc(error)}</p>`;
    return;
  }
  if (!datos.length) {
    zona.innerHTML = estadoVacio({
      icono: 'buscar',
      titulo: 'Nadie encaja con este perfil',
      texto: 'Prueba bajando el nivel requerido, o da de alta personal que cubra esa zona.'
    });
    return;
  }

  zona.innerHTML = datos.map(c => {
    // Contra el maximo alcanzable para esta solicitud, no contra el mejor de la
    // lista: si al mejor candidato le faltan certificaciones, no debe salir 100%.
    const ajuste = Math.min(100, Math.round((c.puntuacion / (c.puntuacion_maxima || 111)) * 100));
    const clase = c.ya_ocupado ? 'ocupado' : ajuste >= 75 ? 'alto' : ajuste >= 45 ? 'medio' : 'bajo';

    return `
      <article class="sugerencia ${clase}">
        <div class="sugerencia-top">
          <span class="avatar-mini">${esc(iniciales(c.nombre_completo))}</span>
          <div class="sugerencia-datos">
            <strong>${esc(c.nombre_completo)}</strong>
            <span class="texto-xs txt-secundario">
              ${esc(etiqueta(NIVELES, c.nivel))} · ${c.anios_experiencia} años
              ${c.calificacion_promedio ? ' · ★ ' + Number(c.calificacion_promedio).toFixed(1) : ''}
            </span>
          </div>
          <div class="sugerencia-ajuste" title="Qué tan bien encaja">
            <span class="ajuste-numero">${ajuste}%</span>
            <span class="ajuste-etiqueta">encaje</span>
          </div>
        </div>

        <ul class="sugerencia-motivos">
          ${(c.motivos || []).map(m => {
            const negativo = /falta|Fuera|ocupado|Ya tiene/i.test(m);
            return `<li class="${negativo ? 'contra' : 'favor'}">
              ${icono(negativo ? 'cerrar' : 'check', 13)}${esc(m)}</li>`;
          }).join('')}
        </ul>

        <div class="sugerencia-pie">
          <a href="../perfil.html?id=${encodeURIComponent(c.id)}" target="_blank"
             rel="noopener" class="btn btn-fantasma btn-sm">Ver perfil</a>
          <button type="button" class="btn btn-primario btn-sm"
                  data-proponer="${esc(c.id)}" ${c.ya_ocupado ? 'disabled' : ''}>
            ${c.ya_ocupado ? 'Ocupado ese día' : 'Proponer'}
          </button>
        </div>
      </article>`;
  }).join('');

  zona.querySelectorAll('[data-proponer]').forEach(b =>
    b.addEventListener('click', () => proponer(b.dataset.proponer, b)));
}

async function proponer(enfermeroId, boton) {
  const solicitudId = tablero.abierta?.solicitud?.id;
  if (!solicitudId) return;

  boton.classList.add('cargando');
  boton.disabled = true;

  const { error } = await consultar(
    db.rpc('proponer_asignacion', {
      p_solicitud_id: solicitudId,
      p_enfermero_id: enfermeroId
    })
  );

  boton.classList.remove('cargando');

  if (error) {
    boton.disabled = false;
    toast(error, 'error');
    return;
  }

  toast('Propuesta enviada.', 'exito', 2500);
  await abrirSolicitud(solicitudId);   // refresca detalle y sugerencias
  cargarTablero();
}

/* ==========================================================================
   ARRANQUE
   ========================================================================== */

function iniciarSolicitudesAdmin() {
  cargarTablero();

  document.getElementById('veloDetalle').addEventListener('click', cerrarDetalle);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && document.getElementById('panelDetalle').classList.contains('abierto')) {
      cerrarDetalle();
    }
  });

  // Si se llega con ?id=, se abre esa solicitud directo
  const id = paramURL('id');
  if (id) abrirSolicitud(id);
}
