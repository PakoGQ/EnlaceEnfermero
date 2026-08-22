/* ==========================================================================
   Enlace Enfermero — Calendario de turnos (panel de la agencia)
   Vista mensual, color por estatus (CLAUDE.md 8.6).
   ========================================================================== */

const cal = { anio: new Date().getFullYear(), mes: new Date().getMonth() + 1, dias: [] };

const COLOR_ESTATUS = {
  propuesta:  'propuesta',
  aceptada:   'aceptada',
  en_curso:   'curso',
  completada: 'completada',
  no_asistio: 'incidencia',
  cancelada:  'incidencia',
  rechazada:  'incidencia'
};

async function cargarCalendario() {
  const { datos, error } = await consultar(
    db.rpc('calendario_mes', { p_anio: cal.anio, p_mes: cal.mes })
  );

  if (error) {
    document.getElementById('calendario').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar el calendario', texto: error });
    return;
  }

  cal.dias = datos || [];
  pintarCalendario();
}

function pintarCalendario() {
  const zona = document.getElementById('calendario');
  const primero = new Date(cal.anio, cal.mes - 1, 1);
  // La semana en México empieza en lunes; getDay() cuenta desde domingo
  const desfase = (primero.getDay() + 6) % 7;

  document.getElementById('tituloMes').textContent =
    new Intl.DateTimeFormat('es-MX', { month: 'long', year: 'numeric' })
      .format(primero).replace(/^\w/, c => c.toUpperCase());

  const totales = cal.dias.reduce((acc, d) => {
    acc.turnos += Number(d.total);
    acc.completados += Number(d.completadas);
    acc.incidencias += Number(d.incidencias);
    return acc;
  }, { turnos: 0, completados: 0, incidencias: 0 });

  document.getElementById('resumen').innerHTML = `
    <span>${totales.turnos} turnos</span>
    <span>${totales.completados} completados</span>
    ${totales.incidencias ? `<span class="txt-error">${totales.incidencias} con incidencia</span>` : ''}`;

  const hoy = hoyISO();

  zona.innerHTML = `
    <div class="calendario">
      ${['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'].map(d =>
        `<div class="cal-encabezado">${d}</div>`).join('')}
      ${Array.from({ length: desfase }, () => '<div class="cal-dia vacio"></div>').join('')}
      ${cal.dias.map(d => {
        const fecha = String(d.fecha);
        const esHoy = fecha === hoy;
        const detalle = d.detalle || [];
        return `
          <div class="cal-dia ${esHoy ? 'hoy' : ''} ${Number(d.total) ? 'con-turnos' : ''}"
               ${Number(d.total) ? `data-dia="${esc(fecha)}" role="button" tabindex="0"` : ''}>
            <span class="cal-numero">${aFecha(fecha).getDate()}</span>
            ${Number(d.total) ? `
              <div class="cal-puntos">
                ${detalle.slice(0, 4).map(t =>
                  `<span class="cal-punto ${COLOR_ESTATUS[t.estatus] || ''}"
                         title="${esc(t.enfermero)} · ${esc(etiqueta(TURNOS, t.turno).split(' (')[0])}"></span>`
                ).join('')}
                ${detalle.length > 4 ? `<span class="cal-mas">+${detalle.length - 4}</span>` : ''}
              </div>` : ''}
          </div>`;
      }).join('')}
    </div>

    <div class="cal-leyenda">
      ${[['propuesta','Propuesta'], ['aceptada','Aceptada'], ['curso','En curso'],
         ['completada','Completada'], ['incidencia','Incidencia']]
        .map(([c, t]) => `<span><i class="cal-punto ${c}"></i>${t}</span>`).join('')}
    </div>`;

  zona.querySelectorAll('[data-dia]').forEach(d => {
    const abrir = () => abrirDia(d.dataset.dia);
    d.addEventListener('click', abrir);
    d.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); abrir(); }
    });
  });
}

function abrirDia(fecha) {
  const dia = cal.dias.find(d => String(d.fecha) === fecha);
  if (!dia) return;

  const panel = document.getElementById('panelDetalle');
  panel.classList.add('abierto');
  document.getElementById('veloDetalle').classList.add('abierto');
  document.body.style.overflow = 'hidden';

  panel.innerHTML = `
    <header class="detalle-cabecera">
      <div>
        <h2>${esc(fechaLarga(fecha))}</h2>
        <span class="texto-sm txt-secundario">${dia.total} turno${Number(dia.total) === 1 ? '' : 's'}</span>
      </div>
      <button type="button" class="btn-icono" id="btnCerrarDia" aria-label="Cerrar">${icono('cerrar', 20)}</button>
    </header>
    <div class="detalle-cuerpo">
      <div class="lista-asignaciones">
        ${(dia.detalle || []).map(t => `
          <div class="asignacion-fila">
            <div class="asignacion-persona">
              <span class="avatar-mini">${esc(iniciales(t.enfermero))}</span>
              <div>
                <strong>${esc(t.enfermero)}</strong>
                <span class="texto-xs txt-secundario">
                  ${esc(etiqueta(TURNOS, t.turno).split(' (')[0])} · ${esc(t.cliente)}
                </span>
              </div>
            </div>
            ${badge(ESTATUS_ASIGNACION, t.estatus)}
          </div>`).join('')}
      </div>
      <a href="asignaciones.html?desde=${esc(fecha)}" class="btn btn-secundario btn-bloque"
         style="margin-top:var(--e5)">Ver en asignaciones</a>
    </div>`;

  document.getElementById('btnCerrarDia').addEventListener('click', cerrarDia);
}

function cerrarDia() {
  document.getElementById('panelDetalle').classList.remove('abierto');
  document.getElementById('veloDetalle').classList.remove('abierto');
  document.body.style.overflow = '';
}

function moverMes(delta) {
  const d = new Date(cal.anio, cal.mes - 1 + delta, 1);
  cal.anio = d.getFullYear();
  cal.mes = d.getMonth() + 1;
  cargarCalendario();
}

function iniciarCalendario() {
  document.getElementById('mesAnterior').addEventListener('click', () => moverMes(-1));
  document.getElementById('mesSiguiente').addEventListener('click', () => moverMes(1));
  document.getElementById('btnHoy').addEventListener('click', () => {
    cal.anio = new Date().getFullYear();
    cal.mes = new Date().getMonth() + 1;
    cargarCalendario();
  });
  document.getElementById('veloDetalle').addEventListener('click', cerrarDia);
  cargarCalendario();
}
