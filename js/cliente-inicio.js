/* ==========================================================================
   Enlace Enfermero — Inicio del cliente
   Servicios activos, próximo turno y quién está asignado (CLAUDE.md 8.8).
   ========================================================================== */

const KPIS_CLIENTE = [
  { clave: 'solicitudes_activas',  titulo: 'Servicios activos', icono: 'inbox',
    href: 'solicitudes.html' },
  { clave: 'turnos_programados',   titulo: 'Turnos agendados',  icono: 'calendario',
    href: 'solicitudes.html' },
  { clave: 'gasto_mes',            titulo: 'Facturado este mes', icono: 'dinero',
    href: 'facturacion.html', moneda: true, dinero: true },
  { clave: 'personal_distinto',    titulo: 'Personal asignado', icono: 'usuarios',
    href: 'personal.html' }
];

const ALERTAS_CLIENTE = [
  { clave: 'pagos_vencidos', nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'cobro vencido' : 'cobros vencidos'}`,
    detalle: 'Regulariza el pago para no interrumpir el servicio.',
    href: 'facturacion.html' },

  { clave: 'solicitudes_sin_cubrir', nivel: 'alerta',
    texto: n => `${n} ${n === 1 ? 'solicitud lleva' : 'solicitudes llevan'} más de 24 h sin cubrir`,
    detalle: 'Estamos en ello. Si urge, escríbenos por WhatsApp.',
    href: 'solicitudes.html' },

  { clave: 'por_evaluar', nivel: 'info',
    texto: n => `${n} ${n === 1 ? 'turno' : 'turnos'} por evaluar`,
    detalle: 'Tienes 15 días desde que termina cada turno.',
    href: 'evaluar.html' }
];

async function iniciarInicioCliente() {
  document.querySelectorAll('[data-icono]').forEach(el => {
    el.innerHTML = icono(el.dataset.icono, 20);
  });

  const [resumen, solicitudes] = await Promise.all([
    consultar(db.rpc('panel_cliente_resumen')),
    consultar(db.rpc('panel_cliente_solicitudes', { p_grupo: 'activas', p_limite: 20 }))
  ]);

  if (resumen.error || !resumen.datos) {
    document.getElementById('kpis').innerHTML = `
      <div class="tarjeta kpis-ancho-total">${estadoVacio({
        icono: 'alerta',
        titulo: 'No pudimos cargar tu cuenta',
        texto: resumen.error || 'Vuelve a cargar la página en un momento.'
      })}</div>`;
    return;
  }

  const d = resumen.datos;

  document.getElementById('saludo').textContent = d.razon_social
    ? `Hola, ${d.razon_social}`
    : '¡Hola!';

  pintarKpisCliente(d);
  pintarAlertasCliente(d);
  await pintarProximosCliente(solicitudes.error ? [] : (solicitudes.datos || []));
}

function pintarKpisCliente(d) {
  document.getElementById('kpis').innerHTML = KPIS_CLIENTE.map((k, i) => {
    const valor = d[k.clave] ?? 0;
    const texto = k.moneda
      ? monedaCorta(valor)
      : new Intl.NumberFormat('es-MX').format(valor);

    return `
      <a href="${k.href}" class="tarjeta kpi entra entra-${i + 1}${k.dinero ? ' kpi-dinero' : ''}">
        <span class="kpi-icono">${icono(k.icono, 20)}</span>
        <span class="kpi-valor">${esc(texto)}</span>
        <span class="kpi-etiqueta">${esc(k.titulo)}</span>
      </a>`;
  }).join('');
}

function pintarAlertasCliente(d) {
  const zona = document.getElementById('alertas');
  const activas = ALERTAS_CLIENTE.filter(a => (d[a.clave] ?? 0) > 0);

  if (!activas.length) {
    zona.innerHTML = `
      <div class="alerta-panel alerta-ok">
        ${icono('check', 20)}
        <div><strong>Todo en orden</strong>
        <span>No tienes cobros vencidos ni servicios sin atender.</span></div>
      </div>`;
    return;
  }

  const orden = { error: 0, alerta: 1, info: 2 };
  activas.sort((a, b) => orden[a.nivel] - orden[b.nivel]);

  zona.innerHTML = activas.map(a => `
    <a href="${a.href}" class="alerta-panel alerta-${a.nivel}">
      ${icono(a.nivel === 'info' ? 'estrella' : 'alerta', 20)}
      <div>
        <strong>${esc(a.texto(d[a.clave]))}</strong>
        <span>${esc(a.detalle)}</span>
      </div>
      <span class="alerta-flecha">${icono('flechaDer', 18)}</span>
    </a>`).join('');
}

/**
 * Próximos turnos con quién los cubre.
 * Hay que pedir el detalle de cada solicitud activa porque es ahí donde vive
 * el personal asignado; se piden en paralelo y se aplanan.
 */
async function pintarProximosCliente(solicitudes) {
  const zona = document.getElementById('proximosTurnos');

  const conPersonal = solicitudes.filter(s =>
    ['confirmada', 'en_curso'].includes(s.estatus));

  if (!conPersonal.length) {
    zona.innerHTML = estadoVacio({
      icono: 'calendario',
      titulo: 'Todavía no hay turnos agendados',
      texto: solicitudes.length
        ? 'Estamos buscando al personal para tus solicitudes abiertas. Te avisamos en cuanto tengamos propuesta.'
        : 'Cuando nos pidas personal y confirmemos el servicio, aquí verás quién llega y cuándo.',
      boton: solicitudes.length ? null
        : { texto: 'Solicitar personal', href: 'solicitar.html' }
    });
    return;
  }

  const detalles = await Promise.all(conPersonal.map(s =>
    consultar(db.rpc('panel_cliente_solicitud_detalle', { p_id: s.id }))));

  const hoy = hoyISO();
  const turnos = detalles
    .filter(r => !r.error && r.datos)
    .flatMap(r => (r.datos.personal || []).map(p => ({ ...p, folio: r.datos.folio })))
    .filter(t => t.fecha >= hoy && ['aceptada', 'en_curso'].includes(t.estatus))
    .sort((a, b) => a.fecha.localeCompare(b.fecha) || a.hora_inicio.localeCompare(b.hora_inicio))
    .slice(0, 6);

  if (!turnos.length) {
    zona.innerHTML = estadoVacio({
      icono: 'calendario',
      titulo: 'Sin turnos próximos',
      texto: 'Tus servicios confirmados ya no tienen turnos por delante.'
    });
    return;
  }

  zona.innerHTML = `<div class="lista-turnos">
    ${turnos.map(t => `
      <article class="turno">
        ${bloqueFechaCliente(t.fecha)}
        <div class="turno-cuerpo">
          <div class="turno-top">
            <span class="badge ${(ESTATUS_ASIGNACION[t.estatus] || {}).clase || 'badge-gris'}">
              ${esc((ESTATUS_ASIGNACION[t.estatus] || {}).nombre || t.estatus)}
            </span>
            <span class="turno-cuando">${esc(cuandoEsCliente(t.fecha))}</span>
          </div>
          <strong class="turno-titulo">${esc(etiqueta(TURNOS, t.turno))}</strong>
          <div class="turno-datos">
            <span>${icono('reloj', 15)} ${esc(hora(t.hora_inicio))} a ${esc(hora(t.hora_fin))}</span>
            <span>${icono('documento', 15)} ${esc(t.folio)}</span>
          </div>
          ${fichaProfesional(t)}
        </div>
      </article>`).join('')}
  </div>`;
}
