/* ==========================================================================
   Enlace Enfermero — Facturación del cliente
   Sus cobros por periodo y el estatus de cada uno (CLAUDE.md 8.8).

   Aquí sólo aparece `tarifa_cliente`: lo que se le factura. Cómo se reparte
   ese monto entre la agencia y el profesional no es asunto suyo, y exponerlo
   sería regalarle el margen a quien va a negociar el precio.
   ========================================================================== */

async function iniciarFacturacion() {
  const { datos, error } = await consultar(db.rpc('panel_cliente_facturacion'));

  if (error || !datos) {
    document.getElementById('kpisFactura').innerHTML = '';
    document.getElementById('listaCobros').innerHTML = `
      <div class="tarjeta">${estadoVacio({
        icono: 'alerta',
        titulo: 'No pudimos cargar tu facturación',
        texto: error || 'Vuelve a cargar la página en un momento.'
      })}</div>`;
    return;
  }

  pintarKpisFactura(datos);
  pintarCobros(datos.cobros || []);
}

function pintarKpisFactura(d) {
  const pendiente = Number(d.total_pendiente);

  const tarjetas = [
    { icono: 'check',  valor: monedaCorta(d.total_pagado),
      etiqueta: 'Pagado' },
    { icono: 'dinero', valor: monedaCorta(pendiente),
      etiqueta: 'Por pagar', alerta: pendiente > 0 }
  ];

  document.getElementById('kpisFactura').innerHTML = tarjetas.map(t => `
    <div class="tarjeta kpi${t.alerta ? ' kpi-alerta' : ''}">
      <span class="kpi-icono">${icono(t.icono, 20)}</span>
      <span class="kpi-valor">${esc(String(t.valor))}</span>
      <span class="kpi-etiqueta">${esc(t.etiqueta)}</span>
    </div>`).join('');
}

function pintarCobros(cobros) {
  const zona = document.getElementById('listaCobros');

  if (!cobros.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'documento',
      titulo: 'Todavía no hay cobros',
      texto: 'Cuando cerremos el primer periodo de servicio verás aquí el ' +
             'detalle de lo facturado y su estatus.'
    })}</div>`;
    return;
  }

  zona.innerHTML = `<div class="lista-quincenas">
    ${cobros.map(tarjetaCobro).join('')}
  </div>

  <p class="nota-corte">
    ${icono('alerta', 15)}
    ¿Algo no cuadra? Escríbenos antes de la fecha de pago y lo revisamos
    contigo, turno por turno.
  </p>`;
}

function tarjetaCobro(c) {
  const est = ESTATUS_PAGO[c.estatus] || { nombre: c.estatus, clase: 'badge-gris' };
  const vencido = c.estatus === 'vencido';

  return `
    <article class="quincena${vencido ? ' quincena-vencida' : ''}">
      <div class="quincena-top">
        <div>
          <strong>${esc(fechaCorta(c.periodo_inicio))} al ${esc(fechaCorta(c.periodo_fin))}</strong>
          <span class="quincena-rango">
            ${esc(c.folio)} · ${c.turnos} ${c.turnos === 1 ? 'turno' : 'turnos'}
          </span>
        </div>
        <div class="cobro-derecha">
          <span class="quincena-monto">${esc(moneda(c.monto))}</span>
          <span class="badge ${est.clase}">${esc(est.nombre)}</span>
        </div>
      </div>

      <div class="cobro-detalle">
        ${c.fecha_pago
          ? `<span>${icono('check', 14)} Pagado el ${esc(fechaCorta(c.fecha_pago))}${c.metodo ? ` por ${esc(c.metodo)}` : ''}</span>`
          : ''}
        ${c.notas ? `<span class="${vencido ? 'txt-error' : 'txt-secundario'}">${esc(c.notas)}</span>` : ''}
        ${c.comprobante_url
          ? `<a href="${esc(c.comprobante_url)}" target="_blank" rel="noopener"
                class="btn btn-fantasma btn-sm">${icono('documento', 15)} Comprobante</a>`
          : ''}
      </div>
    </article>`;
}
