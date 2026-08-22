/* ==========================================================================
   Enlace Enfermero — Programa de referidos (panel de la agencia)
   La recompensa se acredita al completarse el primer servicio del referido,
   nunca al registrarse (CLAUDE.md 5.2).
   ========================================================================== */

const refs = { filas: [] };

const COLUMNAS_REFERIDO = [
  { titulo: 'Código', valor: r => `<strong>${esc(r.codigo)}</strong>`, crudo: r => r.codigo },
  { titulo: 'Quién refirió', valor: r => `${esc(r.referidor || 'Sin nombre')}
      <span class="texto-xs txt-tenue">${esc(r.referidor_rol || '')}</span>`,
    crudo: r => r.referidor },
  { titulo: 'A quién', valor: r => `${esc(r.referido || 'Aún sin registrarse')}
      <span class="texto-xs txt-tenue">${esc(r.tipo_referido || '')}</span>`,
    crudo: r => r.referido },
  { titulo: 'Servicios del referido', clase: 'num', valor: r => r.servicios_referido,
    crudo: r => r.servicios_referido },
  { titulo: 'Estatus', valor: r => {
      const mapa = {
        registrado: { nombre: 'Registrado', clase: 'badge-gris' },
        validado:   { nombre: 'Validado',   clase: 'badge-exito' },
        pagado:     { nombre: 'Pagado',     clase: 'badge-azul' }
      };
      return badge(mapa, r.estatus);
    },
    crudo: r => r.estatus },
  { titulo: 'Recompensa', clase: 'num', valor: r => Number(r.recompensa_monto) > 0
      ? moneda(r.recompensa_monto) : '<span class="txt-tenue">—</span>',
    crudo: r => r.recompensa_monto },
  { titulo: 'Alta', valor: r => esc(fechaCorta(r.created_at)), crudo: r => r.created_at }
];

async function cargarReferidos() {
  const { datos, error } = await consultar(db.rpc('referidos_lista'));

  if (error) {
    document.getElementById('tabla').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar', texto: error });
    return;
  }

  refs.filas = datos || [];
  pintarTabla('tabla', refs.filas, COLUMNAS_REFERIDO, {
    icono: 'escudo',
    titulo: 'Todavía no hay referidos',
    texto: 'Cada usuario recibe su código al registrarse. El programa se activa en la Fase 4 con los enlaces de WhatsApp.'
  });

  const porValidar = refs.filas.filter(r => r.estatus === 'registrado' && Number(r.servicios_referido) > 0);
  document.getElementById('resumen').innerHTML = `
    <span>${refs.filas.length} referidos</span>
    <span>${refs.filas.filter(r => r.estatus === 'pagado').length} recompensas pagadas</span>
    ${porValidar.length ? `<span class="txt-error">${porValidar.length} listos para acreditar</span>` : ''}`;
}

function iniciarReferidos() {
  document.getElementById('btnExportar').addEventListener('click', () =>
    exportarCSV('referidos', refs.filas, COLUMNAS_REFERIDO));
  cargarReferidos();
}
