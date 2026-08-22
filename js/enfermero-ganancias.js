/* ==========================================================================
   Enlace Enfermero — Ganancias del profesional
   Agregado por quincena, que es como corta la agencia. Si el panel sumara por
   mes, el profesional no podría cuadrar lo que recibe con lo que ve aquí.

   Todo lo que se muestra es `tarifa_enfermero`: su 60%. Lo que la agencia
   factura al cliente no aparece por ningún lado (CLAUDE.md 15.2).
   ========================================================================== */

async function iniciarGanancias() {
  const zonaKpis = document.getElementById('kpisGanancias');
  const zonaQuin = document.getElementById('listaQuincenas');

  const { datos, error } = await consultar(db.rpc('mis_ganancias'));

  if (error || !datos) {
    zonaKpis.innerHTML = '';
    zonaQuin.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta',
      titulo: 'No pudimos cargar tus ganancias',
      texto: error || 'Vuelve a cargar la página en un momento.'
    })}</div>`;
    return;
  }

  pintarKpisGanancias(datos);
  pintarQuincenas(datos.quincenas || []);
}

function pintarKpisGanancias(d) {
  const tarjetas = [
    { icono: 'dinero',     valor: monedaCorta(d.total_periodo),
      etiqueta: 'Ganado en 6 meses', nota: `${d.turnos_periodo} turnos` },
    { icono: 'calendario', valor: monedaCorta(d.comprometido),
      etiqueta: 'Ya agendado',       nota: 'Turnos aceptados por venir' },
    { icono: 'maletin',    valor: monedaCorta(d.promedio_turno),
      etiqueta: 'Promedio por turno' },
    { icono: 'check',      valor: String(d.turnos_periodo),
      etiqueta: 'Turnos cobrados' }
  ];

  document.getElementById('kpisGanancias').innerHTML = tarjetas.map(t => `
    <div class="tarjeta kpi">
      <span class="kpi-icono">${icono(t.icono, 20)}</span>
      <span class="kpi-valor">${esc(String(t.valor))}</span>
      <span class="kpi-etiqueta">${esc(t.etiqueta)}</span>
      ${t.nota ? `<span class="kpi-cambio">${esc(t.nota)}</span>` : ''}
    </div>`).join('');
}

function pintarQuincenas(quincenas) {
  const zona = document.getElementById('listaQuincenas');

  if (!quincenas.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'dinero',
      titulo: 'Todavía no hay nada que cobrar',
      texto: 'En cuanto cierres tu primer turno aparecerá aquí el corte que le ' +
             'corresponde.'
    })}</div>`;
    return;
  }

  // La barra compara cada quincena contra la mejor, para ver la tendencia sin
  // necesidad de una gráfica.
  const mayor = Math.max(...quincenas.map(q => Number(q.monto)));

  zona.innerHTML = `<div class="lista-quincenas">
    ${quincenas.map(q => {
      const monto = Number(q.monto);
      const ancho = mayor > 0 ? Math.round((monto / mayor) * 100) : 0;
      // El nombre del mes se arma aquí y no en la base: así siempre sale en
      // español, sin depender del locale del servidor.
      const mes = new Intl.DateTimeFormat('es-MX', { month: 'long', year: 'numeric' })
        .format(aFecha(q.inicio)).replace(/^\w/, c => c.toUpperCase());
      const etiquetaQ = `${mes} · ${q.mitad === 1 ? '1ª' : '2ª'} quincena`;

      return `
        <article class="quincena">
          <div class="quincena-top">
            <div>
              <strong>${esc(etiquetaQ)}</strong>
              <span class="quincena-rango">
                ${esc(fechaCorta(q.inicio))} al ${esc(fechaCorta(q.fin))} ·
                ${q.turnos} ${q.turnos === 1 ? 'turno' : 'turnos'}
              </span>
            </div>
            <span class="quincena-monto">${esc(moneda(monto))}</span>
          </div>
          <div class="barra-pista">
            <div class="barra-valor" style="width:${ancho}%"></div>
          </div>
        </article>`;
    }).join('')}
  </div>

  <p class="nota-corte">
    ${icono('alerta', 15)}
    Estos montos son lo que te corresponde por turnos ya completados. La fecha
    en que se depositan la define la agencia; si algo no cuadra, escríbenos
    antes de que cierre el corte.
  </p>`;
}
