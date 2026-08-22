/* ==========================================================================
   Enlace Enfermero — Mis solicitudes (cliente)
   Seguimiento con línea de tiempo del estatus (CLAUDE.md 8.8).

   Lo que el cliente quiere saber es una sola cosa: «¿ya tengo a alguien?».
   Por eso cada tarjeta lleva la cobertura al frente y el detalle abre la
   línea de tiempo con el personal ya asignado.
   ========================================================================== */

let grupoSolicitudes = 'activas';

const GRUPOS_SOLICITUD = [
  { id: 'activas',   nombre: 'En curso' },
  { id: 'historial', nombre: 'Cerradas' },
  { id: 'todas',     nombre: 'Todas' }
];

async function cargarSolicitudesCliente() {
  const zona = document.getElementById('listaSolicitudes');
  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(
    db.rpc('panel_cliente_solicitudes', { p_grupo: grupoSolicitudes, p_limite: 100 })
  );

  if (error) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar tus solicitudes', texto: error
    })}</div>`;
    return;
  }

  pintarGruposSolicitud();

  const lista = datos || [];
  if (!lista.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'inbox',
      titulo: grupoSolicitudes === 'activas'
        ? 'No tienes servicios en curso'
        : 'Nada en este filtro',
      texto: grupoSolicitudes === 'activas'
        ? 'Cuando nos pidas personal, aquí sigues el avance paso a paso.'
        : 'Prueba con otro filtro.',
      boton: grupoSolicitudes === 'activas'
        ? { texto: 'Solicitar personal', href: 'solicitar.html' } : null
    })}</div>`;
    return;
  }

  zona.innerHTML = `<div class="lista-solicitudes">
    ${lista.map(tarjetaSolicitud).join('')}
  </div>`;

  zona.querySelectorAll('[data-detalle]').forEach(b =>
    b.addEventListener('click', () => abrirDetalleSolicitud(b.dataset.detalle)));
}

function pintarGruposSolicitud() {
  const zona = document.getElementById('filtros');
  zona.innerHTML = GRUPOS_SOLICITUD.map(g => `
    <button type="button" class="filtro${grupoSolicitudes === g.id ? ' activo' : ''}"
            data-grupo="${g.id}">${esc(g.nombre)}</button>`).join('');

  zona.querySelectorAll('[data-grupo]').forEach(b =>
    b.addEventListener('click', () => {
      grupoSolicitudes = b.dataset.grupo;
      cargarSolicitudesCliente();
    }));
}

function tarjetaSolicitud(s) {
  const est = ESTATUS_SOLICITUD[s.estatus] || { nombre: s.estatus, clase: 'badge-gris' };
  const necesarios = (s.cantidad || 1);
  const completa   = s.turnos_cubiertos > 0 && s.turnos_cubiertos >= necesarios;

  return `
    <article class="solicitud${s.urgente ? ' urgente' : ''}">
      <div class="solicitud-top">
        <div>
          <span class="solicitud-folio">${esc(s.folio)}</span>
          <strong>${esc(etiqueta(TIPOS_SERVICIO, s.tipo_servicio))}</strong>
        </div>
        <span class="badge ${est.clase}">${esc(est.nombre)}</span>
      </div>

      <div class="solicitud-datos">
        <span>${icono('calendario', 15)} Desde ${esc(fechaCorta(s.fecha_inicio))}</span>
        <span>${icono('reloj', 15)} ${esc(etiqueta(TURNOS, s.turno) || 'Turno por definir')}</span>
        <span>${icono('ubicacion', 15)} ${esc(etiqueta(MUNICIPIOS, s.municipio) || s.municipio || '')}</span>
        <span>${icono('usuarios', 15)} ${necesarios} ${necesarios === 1 ? 'persona' : 'personas'}</span>
      </div>

      <div class="solicitud-pie">
        <span class="solicitud-cobertura ${completa ? 'completa' : 'incompleta'}">
          ${s.turnos_cubiertos > 0
            ? `${s.turnos_cubiertos} ${s.turnos_cubiertos === 1 ? 'turno cubierto' : 'turnos cubiertos'}`
            : 'Buscando personal'}
        </span>
        <button type="button" class="btn btn-secundario btn-sm" data-detalle="${esc(s.id)}">
          Ver seguimiento
        </button>
      </div>
    </article>`;
}

/** Panel lateral con la línea de tiempo y el personal asignado. */
async function abrirDetalleSolicitud(id) {
  const panel = document.getElementById('detalleSolicitud');
  panel.classList.add('abierto');
  panel.setAttribute('aria-hidden', 'false');
  panel.innerHTML = '<div class="detalle-cuerpo"><div class="spinner"></div></div>';

  let velo = document.getElementById('veloDetalle');
  if (!velo) {
    velo = document.createElement('div');
    velo.id = 'veloDetalle';
    velo.className = 'velo-detalle';
    document.body.appendChild(velo);
  }
  velo.classList.add('abierto');

  const cerrar = () => {
    panel.classList.remove('abierto');
    panel.setAttribute('aria-hidden', 'true');
    velo.classList.remove('abierto');
  };
  velo.onclick = cerrar;

  const { datos: d, error } = await consultar(
    db.rpc('panel_cliente_solicitud_detalle', { p_id: id })
  );

  if (error || !d) {
    panel.innerHTML = `<div class="detalle-cuerpo">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos abrir el seguimiento', texto: error || ''
    })}</div>`;
    return;
  }

  panel.innerHTML = `
    <header class="detalle-cabecera">
      <div>
        <span class="solicitud-folio">${esc(d.folio)}</span>
        <h2>${esc(etiqueta(TIPOS_SERVICIO, d.tipo_servicio))}</h2>
      </div>
      <button type="button" class="btn-icono" id="btnCerrarDetalle" aria-label="Cerrar">
        ${icono('cerrar', 20)}
      </button>
    </header>

    <div class="detalle-cuerpo">
      ${d.cancelada ? `
        <div class="alerta-panel alerta-error">
          ${icono('alerta', 20)}
          <div><strong>Servicio cancelado</strong>
          <span>Si fue un error, escríbenos y lo reactivamos.</span></div>
        </div>` : `
        <div class="detalle-bloque">
          <h3>En qué va</h3>
          <ol class="linea-tiempo">
            ${(d.pasos || []).map(p => `
              <li class="paso-tiempo${p.hecho ? ' hecho' : ''}${p.actual ? ' actual' : ''}">
                <span class="paso-marca" aria-hidden="true">${p.hecho ? icono('check', 14) : ''}</span>
                <div>
                  <strong>${esc(p.titulo)}</strong>
                  <span>${esc(p.detalle)}</span>
                </div>
              </li>`).join('')}
          </ol>
        </div>`}

      <div class="detalle-bloque">
        <h3>Qué pediste</h3>
        <dl class="detalle-datos">
          <div><dt>Nivel</dt><dd>${esc(etiqueta(NIVELES, d.nivel_requerido) || 'Cualquiera')}</dd></div>
          <div><dt>Atención</dt><dd>${esc(etiqueta(NIVELES_ATENCION, d.nivel_atencion) || '—')}</dd></div>
          <div><dt>Lugar</dt><dd>${esc(etiqueta(ENTORNOS, d.entorno) || '—')}</dd></div>
          <div><dt>Municipio</dt><dd>${esc(etiqueta(MUNICIPIOS, d.municipio) || d.municipio || '—')}</dd></div>
          <div><dt>Inicio</dt><dd>${esc(fechaCorta(d.fecha_inicio))}</dd></div>
          <div><dt>Turno</dt><dd>${esc(etiqueta(TURNOS, d.turno) || '—')}</dd></div>
        </dl>

        ${(d.procedimientos || []).length ? `
          <h4>Procedimientos</h4>
          <div class="ts-chips">
            ${d.procedimientos.map(p => `<span class="chip">${esc(etiqueta(PROCEDIMIENTOS, p))}</span>`).join('')}
          </div>` : ''}

        ${d.descripcion ? `<p class="detalle-descripcion">${esc(d.descripcion)}</p>` : ''}
      </div>

      <div class="detalle-bloque">
        <h3>Quién lo cubre <span class="conteo-inline">${(d.personal || []).length}</span></h3>
        ${(d.personal || []).length
          ? `<div class="lista-turnos">
              ${d.personal.map(p => `
                <article class="turno">
                  ${bloqueFechaCliente(p.fecha)}
                  <div class="turno-cuerpo">
                    <div class="turno-top">
                      <span class="badge ${(ESTATUS_ASIGNACION[p.estatus] || {}).clase || 'badge-gris'}">
                        ${esc((ESTATUS_ASIGNACION[p.estatus] || {}).nombre || p.estatus)}
                      </span>
                      <span class="turno-cuando">${esc(hora(p.hora_inicio))} a ${esc(hora(p.hora_fin))}</span>
                    </div>
                    ${fichaProfesional(p)}
                  </div>
                </article>`).join('')}
             </div>`
          : `<p class="txt-secundario texto-sm">
               Todavía no hay nadie confirmado. En cuanto el personal acepte, aparece aquí
               con su perfil.
             </p>`}
      </div>

      <p class="nota-bloqueada">
        ${icono('candado', 15)}
        La coordinación con el personal pasa siempre por la agencia. Si necesitas
        un cambio, escríbenos y nosotros lo resolvemos.
      </p>
    </div>`;

  document.getElementById('btnCerrarDetalle').addEventListener('click', cerrar);
}

function iniciarSolicitudesCliente() {
  cargarSolicitudesCliente();
}
