/* ==========================================================================
   Enlace Enfermero — Reportes (panel de la agencia)
   Métricas por periodo, ranking y exportación (CLAUDE.md 8.6).
   ========================================================================== */

const rep = { desde: '', hasta: '', datos: null };

async function cargarReporte() {
  const zona = document.getElementById('contenido');
  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(
    db.rpc('reporte_periodo', { p_desde: rep.desde, p_hasta: rep.hasta })
  );

  if (error) {
    zona.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos generar el reporte', texto: error });
    return;
  }

  rep.datos = datos;
  pintarReporte(datos);
}

function pintarReporte(d) {
  const r = d.resumen;
  const s = d.solicitudes;
  const margen = Number(r.ingresos) > 0
    ? Math.round((Number(r.comision) / Number(r.ingresos)) * 100) : 0;

  document.getElementById('contenido').innerHTML = `
    <section class="kpis kpis-reporte">
      ${[
        ['Turnos completados', new Intl.NumberFormat('es-MX').format(r.turnos_completados), 'check'],
        ['Ingresos',           monedaCorta(r.ingresos),  'dinero'],
        ['Pagado al personal', monedaCorta(r.pagado),    'usuarios'],
        ['Comisión',           monedaCorta(r.comision),  'maletin'],
        ['Margen real',        margen + '%',             'filtro'],
        ['Profesionales activos', r.enfermeros_activos,  'escudo']
      ].map(([t, v, ic]) => `
        <div class="tarjeta kpi">
          <span class="kpi-icono">${icono(ic, 20)}</span>
          <span class="kpi-valor">${esc(v)}</span>
          <span class="kpi-etiqueta">${esc(t)}</span>
        </div>`).join('')}
    </section>

    <div class="panel-columnas">
      <section class="tarjeta">
        <div class="tarjeta-cabecera"><h3>Solicitudes del periodo</h3></div>
        <dl class="detalle-datos">
          <div><dt>Recibidas</dt><dd>${s.recibidas}</dd></div>
          <div><dt>Cubiertas</dt><dd>${s.cubiertas}</dd></div>
          <div><dt>Canceladas</dt><dd>${s.canceladas}</dd></div>
          <div><dt>Tasa de cobertura</dt>
            <dd class="${Number(s.tasa_cobertura) < 70 ? 'txt-error' : 'txt-exito'}">
              <strong>${s.tasa_cobertura}%</strong></dd></div>
        </dl>
        ${r.inasistencias > 0 || r.turnos_cancelados > 0 ? `
          <div class="aviso-incidencias">
            ${r.inasistencias} inasistencia${r.inasistencias === 1 ? '' : 's'} ·
            ${r.turnos_cancelados} cancelación${r.turnos_cancelados === 1 ? '' : 'es'}
          </div>` : ''}
      </section>

      <section class="tarjeta">
        <div class="tarjeta-cabecera"><h3>Por municipio</h3></div>
        ${(d.por_municipio || []).length
          ? `<div class="barras-municipio">
              ${d.por_municipio.map(m => {
                const max = Math.max(...d.por_municipio.map(x => Number(x.turnos)));
                return `
                  <div class="barra-fila">
                    <span class="barra-etiqueta">${esc(etiqueta(MUNICIPIOS, m.municipio))}</span>
                    <div class="barra-pista">
                      <div class="barra-valor" style="width:${(Number(m.turnos) / max) * 100}%"></div>
                    </div>
                    <span class="barra-numero">${m.turnos}</span>
                  </div>`;
              }).join('')}
            </div>`
          : '<p class="texto-sm txt-tenue">Sin turnos en el periodo.</p>'}
      </section>
    </div>

    <section class="bloque-panel">
      <div class="tarjeta-cabecera">
        <h2 class="titulo-bloque">Ranking de profesionales</h2>
      </div>
      <div id="tablaRanking"></div>
    </section>`;

  pintarTabla('tablaRanking', d.ranking || [], COLUMNAS_RANKING, {
    icono: 'usuarios',
    titulo: 'Sin turnos completados en el periodo',
    texto: 'Cambia las fechas para ver otro rango.'
  });
}

const COLUMNAS_RANKING = [
  { titulo: '#', clase: 'num', valor: (r, i) => '', crudo: () => '' },
  { titulo: 'Profesional', valor: r => `<strong>${esc(r.nombre)}</strong>
      <span class="texto-xs txt-tenue">${esc(r.folio)} · ${esc(etiqueta(NIVELES, r.nivel))}</span>`,
    crudo: r => r.nombre },
  { titulo: 'Turnos', clase: 'num', valor: r => r.turnos, crudo: r => r.turnos },
  { titulo: 'Calificación', clase: 'num', valor: r => r.calificacion
      ? `★ ${Number(r.calificacion).toFixed(1)}` : '<span class="txt-tenue">—</span>',
    crudo: r => r.calificacion || '' },
  { titulo: 'Pagado', clase: 'num', valor: r => moneda(r.pagado), crudo: r => r.pagado },
  { titulo: 'Comisión generada', clase: 'num', valor: r => `<strong>${moneda(r.comision)}</strong>`,
    crudo: r => r.comision }
];

function iniciarReportes() {
  const m = mesActual();
  rep.desde = m.desde;
  rep.hasta = m.hasta;
  document.getElementById('desde').value = m.desde;
  document.getElementById('hasta').value = m.hasta;

  ['desde', 'hasta'].forEach(id =>
    document.getElementById(id).addEventListener('change', () => {
      rep[id] = document.getElementById(id).value;
      cargarReporte();
    }));

  document.getElementById('btnMes').addEventListener('click', () => {
    const m2 = mesActual();
    rep.desde = m2.desde; rep.hasta = m2.hasta;
    document.getElementById('desde').value = m2.desde;
    document.getElementById('hasta').value = m2.hasta;
    cargarReporte();
  });

  document.getElementById('btnExportar').addEventListener('click', () => {
    if (!rep.datos?.ranking?.length) { toast('No hay datos que exportar.', 'info'); return; }
    exportarCSV('reporte', rep.datos.ranking, COLUMNAS_RANKING.filter(c => c.titulo && c.titulo !== '#'));
  });

  cargarReporte();
}
