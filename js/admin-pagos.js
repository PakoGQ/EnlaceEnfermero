/* ==========================================================================
   Enlace Enfermero — Pagos (panel de la agencia)
   Cobros al cliente y pagos al personal, por corte quincenal (CLAUDE.md 8.6).
   ========================================================================== */

const pagos = { pestana: 'personal', desde: '', hasta: '', filas: [] };

const COLUMNAS_CORTE = [
  { titulo: 'Profesional', valor: r => `
      <div class="celda-persona">
        <span class="avatar-mini">${esc(iniciales(r.nombre))}</span>
        <div><strong>${esc(r.nombre)}</strong>
          <span class="texto-xs txt-tenue">${esc(r.folio)} · ${esc(etiqueta(NIVELES, r.nivel))}</span></div>
      </div>`,
    crudo: r => r.nombre },
  { titulo: 'Turnos', clase: 'num', valor: r => r.turnos, crudo: r => r.turnos },
  { titulo: 'Facturado al cliente', clase: 'num', valor: r => moneda(r.facturado), crudo: r => r.facturado },
  { titulo: 'Le toca', clase: 'num', valor: r => `<strong>${moneda(r.total_pagar)}</strong>`, crudo: r => r.total_pagar },
  { titulo: 'Comisión', clase: 'num', valor: r => moneda(r.comision), crudo: r => r.comision },
  { titulo: 'Ya pagado', clase: 'num', valor: r => Number(r.ya_pagado) > 0
      ? moneda(r.ya_pagado) : '<span class="txt-tenue">—</span>', crudo: r => r.ya_pagado },
  { titulo: 'Pendiente', clase: 'num', valor: r => Number(r.pendiente) > 0
      ? `<strong class="txt-error">${moneda(r.pendiente)}</strong>`
      : '<span class="badge badge-exito">Al corriente</span>',
    crudo: r => r.pendiente },
  { titulo: '', clase: 'acciones', valor: r => Number(r.pendiente) > 0
      ? `<button type="button" class="btn btn-primario btn-sm"
           data-pagar="${esc(r.enfermero_id)}" data-monto="${r.pendiente}"
           data-nombre="${esc(r.nombre)}">Registrar pago</button>` : '',
    crudo: () => '' }
];

const COLUMNAS_COBRO = [
  { titulo: 'Cliente', valor: r => `<strong>${esc(r.cliente)}</strong>
      <span class="texto-xs txt-tenue">${esc(etiqueta(TIPOS_CLIENTE, r.tipo))}</span>`,
    crudo: r => r.cliente },
  { titulo: 'Turnos', clase: 'num', valor: r => r.turnos, crudo: r => r.turnos },
  { titulo: 'Por cobrar', clase: 'num', valor: r => `<strong>${moneda(r.total_cobrar)}</strong>`,
    crudo: r => r.total_cobrar },
  { titulo: 'Ya cobrado', clase: 'num', valor: r => Number(r.ya_cobrado) > 0
      ? moneda(r.ya_cobrado) : '<span class="txt-tenue">—</span>', crudo: r => r.ya_cobrado },
  { titulo: 'Pendiente', clase: 'num', valor: r => Number(r.pendiente) > 0
      ? `<strong class="txt-error">${moneda(r.pendiente)}</strong>`
      : '<span class="badge badge-exito">Cobrado</span>',
    crudo: r => r.pendiente },
  { titulo: 'Factura', valor: r => r.requiere_factura
      ? '<span class="badge badge-azul">CFDI</span>' : '<span class="txt-tenue">No</span>',
    crudo: r => r.requiere_factura ? 'si' : 'no' }
];

async function cargarPagos() {
  const zona = document.getElementById('tabla');
  zona.innerHTML = '<div class="spinner"></div>';

  const fn = pagos.pestana === 'personal' ? 'corte_enfermeros' : 'cobros_clientes';
  const { datos, error } = await consultar(
    db.rpc(fn, { p_desde: pagos.desde, p_hasta: pagos.hasta })
  );

  if (error) {
    zona.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar el corte', texto: error });
    return;
  }

  pagos.filas = datos || [];
  const columnas = pagos.pestana === 'personal' ? COLUMNAS_CORTE : COLUMNAS_COBRO;

  pintarTabla('tabla', pagos.filas, columnas, {
    icono: 'dinero',
    titulo: 'Sin movimientos en este periodo',
    texto: 'Solo aparecen los turnos completados dentro de las fechas elegidas.'
  });

  const campo = pagos.pestana === 'personal' ? 'total_pagar' : 'total_cobrar';
  const total = pagos.filas.reduce((s, r) => s + Number(r[campo]), 0);
  const pendiente = pagos.filas.reduce((s, r) => s + Number(r.pendiente), 0);

  document.getElementById('resumen').innerHTML = `
    <span>${pagos.filas.length} ${pagos.pestana === 'personal' ? 'profesionales' : 'clientes'}</span>
    <span>Total <strong>${monedaCorta(total)}</strong></span>
    <span class="${pendiente > 0 ? 'txt-error' : ''}">Pendiente <strong>${monedaCorta(pendiente)}</strong></span>`;

  document.querySelectorAll('[data-pagar]').forEach(b =>
    b.addEventListener('click', () => registrarPagoA(b.dataset.pagar, b.dataset.monto, b.dataset.nombre)));
}

function registrarPagoA(referenciaId, monto, nombre) {
  abrirFormulario({
    titulo: `Pago a ${nombre}`,
    textoGuardar: 'Registrar pago',
    campos: [
      { nombre: 'monto', etiqueta: 'Monto', tipo: 'number', requerido: true, min: 0, paso: 0.01,
        valor: monto, nota: `Periodo del ${fechaCorta(pagos.desde)} al ${fechaCorta(pagos.hasta)}.` },
      { nombre: 'metodo', etiqueta: 'Método', tipo: 'select', vacio: 'Selecciona',
        opciones: [
          { id: 'transferencia', nombre: 'Transferencia' },
          { id: 'efectivo',      nombre: 'Efectivo' },
          { id: 'deposito',      nombre: 'Depósito' },
          { id: 'otro',          nombre: 'Otro' }
        ] },
      { nombre: 'fecha_pago', etiqueta: 'Fecha del pago', tipo: 'date', valor: hoyISO() },
      { nombre: 'notas', etiqueta: 'Notas', tipo: 'textarea',
        nota: 'Referencia de la transferencia, folio de factura del profesional, etc.' }
    ],
    alGuardar: async (d) => {
      const { error } = await consultar(db.rpc('registrar_pago', {
        p_datos: {
          tipo: 'pago_enfermero',
          referencia_id: referenciaId,
          periodo_inicio: pagos.desde,
          periodo_fin: pagos.hasta,
          monto: d.monto,
          metodo: d.metodo,
          fecha_pago: d.fecha_pago,
          notas: d.notas,
          estatus: 'pagado'
        }
      }));
      if (error) { toast(error, 'error'); return false; }
      toast('Pago registrado.', 'exito', 2500);
      cargarPagos();
    }
  });
}

function iniciarPagos() {
  const q = quincenaActual();
  pagos.desde = q.desde;
  pagos.hasta = q.hasta;
  document.getElementById('desde').value = q.desde;
  document.getElementById('hasta').value = q.hasta;

  pintarFiltros('filtros', [
    { id: 'personal', texto: 'Pagos al personal' },
    { id: 'clientes', texto: 'Cobros a clientes' }
  ], 'personal', (v) => { pagos.pestana = v; cargarPagos(); });

  ['desde', 'hasta'].forEach(id =>
    document.getElementById(id).addEventListener('change', () => {
      pagos[id] = document.getElementById(id).value;
      cargarPagos();
    }));

  document.getElementById('btnQuincena').addEventListener('click', () => {
    const q2 = quincenaActual();
    pagos.desde = q2.desde; pagos.hasta = q2.hasta;
    document.getElementById('desde').value = q2.desde;
    document.getElementById('hasta').value = q2.hasta;
    cargarPagos();
  });

  document.getElementById('btnExportar').addEventListener('click', () =>
    exportarCSV(pagos.pestana === 'personal' ? 'corte-personal' : 'cobros-clientes',
      pagos.filas,
      (pagos.pestana === 'personal' ? COLUMNAS_CORTE : COLUMNAS_COBRO).filter(c => c.titulo)));

  cargarPagos();
}
