/* ==========================================================================
   Enlace Enfermero — Historial del profesional
   Los turnos ya cerrados: completados, rechazados y los que no cubrió.
   Es su hoja de servicio, y de paso el respaldo de lo que se le paga.
   ========================================================================== */

async function iniciarHistorial() {
  const zonaKpis  = document.getElementById('kpisHistorial');
  const zonaLista = document.getElementById('listaHistorial');

  const { datos, error } = await consultar(
    db.rpc('panel_enfermero_turnos', { p_grupo: 'historial', p_limite: 200 })
  );

  if (error) {
    zonaKpis.innerHTML = '';
    zonaLista.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar tu historial', texto: error
    })}</div>`;
    return;
  }

  const turnos = datos || [];
  pintarResumenHistorial(turnos);

  if (!turnos.length) {
    zonaLista.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'check',
      titulo: 'Todavía no cierras ningún turno',
      texto: 'Cuando termines tu primer turno aparecerá aquí, con la ' +
             'calificación que te haya dado el cliente.'
    })}</div>`;
    return;
  }

  zonaLista.innerHTML = `<div class="lista-turnos">
    ${turnos.map(t => tarjetaTurno(t, { detalle: false })).join('')}
  </div>`;
}

/**
 * Cuatro números que resumen su trayectoria.
 * El de confiabilidad es el que más le conviene cuidar: la agencia lo mira
 * para decidir a quién propone primero (regla 10.9).
 */
function pintarResumenHistorial(turnos) {
  const zona = document.getElementById('kpisHistorial');
  if (!zona) return;

  const completados = turnos.filter(t => t.estatus === 'completada');
  const fallados    = turnos.filter(t => t.estatus === 'no_asistio');
  const calificados = completados.filter(t => t.calificacion);

  const promedio = calificados.length
    ? (calificados.reduce((s, t) => s + Number(t.calificacion), 0) / calificados.length)
    : 0;

  // Solo cuentan los turnos que llegó a aceptar: rechazar una propuesta a
  // tiempo es justo lo que se le pide, no una falta.
  const comprometidos = completados.length + fallados.length;
  const cumplimiento  = comprometidos
    ? Math.round((completados.length / comprometidos) * 100)
    : 100;

  const total = completados.reduce((s, t) => s + Number(t.tarifa_enfermero || 0), 0);

  const tarjetas = [
    { icono: 'check',    valor: completados.length,        etiqueta: 'Turnos completados' },
    { icono: 'dinero',   valor: monedaCorta(total),        etiqueta: 'Ganado en total' },
    { icono: 'estrella', valor: promedio ? promedio.toFixed(1) : '—',
      etiqueta: 'Promedio recibido',
      nota: calificados.length ? `${calificados.length} calificaciones` : 'Sin calificar aún' },
    { icono: 'escudo',   valor: `${cumplimiento}%`,        etiqueta: 'Turnos cumplidos',
      alerta: cumplimiento < 90,
      nota: fallados.length ? `${fallados.length} sin asistir` : 'Sin faltas' }
  ];

  zona.innerHTML = tarjetas.map(t => `
    <div class="tarjeta kpi${t.alerta ? ' kpi-alerta' : ''}">
      <span class="kpi-icono">${icono(t.icono, 20)}</span>
      <span class="kpi-valor">${esc(String(t.valor))}</span>
      <span class="kpi-etiqueta">${esc(t.etiqueta)}</span>
      ${t.nota ? `<span class="kpi-cambio">${esc(t.nota)}</span>` : ''}
    </div>`).join('');
}
