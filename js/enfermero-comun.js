/* ==========================================================================
   Enlace Enfermero — Piezas compartidas del panel del profesional
   La tarjeta de turno se pinta igual en Inicio, en Mis turnos y en Historial,
   asi que vive aqui y no en cada pantalla.
   ========================================================================== */

/** Dia y mes en grande, para leer la tarjeta de un vistazo. */
function bloqueFecha(iso) {
  const f = aFecha(iso);
  if (!f) return '';
  const dia = new Intl.DateTimeFormat('es-MX', { weekday: 'short' }).format(f);
  const mes = new Intl.DateTimeFormat('es-MX', { month: 'short' }).format(f);
  return `
    <div class="turno-fecha" aria-hidden="true">
      <span class="turno-dia-sem">${esc(dia.replace('.', ''))}</span>
      <strong>${f.getDate()}</strong>
      <span class="turno-mes">${esc(mes.replace('.', ''))}</span>
    </div>`;
}

/** Cuanto falta, en palabras. Es lo que de verdad se quiere saber. */
function cuandoEs(iso) {
  const f = aFecha(iso);
  if (!f) return '';
  const hoy  = new Date(); hoy.setHours(0, 0, 0, 0);
  const dias = Math.round((f - hoy) / 86400000);

  if (dias === 0)  return 'Hoy';
  if (dias === 1)  return 'Mañana';
  if (dias === -1) return 'Ayer';
  if (dias > 1 && dias < 7)   return `En ${dias} días`;
  if (dias < -1 && dias > -7) return `Hace ${Math.abs(dias)} días`;
  return fechaCorta(iso);
}

/**
 * Botones disponibles segun el estatus del turno.
 * Las transiciones permitidas las impone la base (proteger_campos_asignacion);
 * aqui solo se decide cual ofrecer para no enseñar un boton que va a fallar.
 */
function accionesTurno(t) {
  const hoy = hoyISO();

  if (t.estatus === 'propuesta') {
    return `
      <div class="turno-acciones">
        <button type="button" class="btn btn-exito btn-sm" data-accion="aceptar" data-id="${esc(t.id)}">
          ${icono('check', 16)} Aceptar
        </button>
        <button type="button" class="btn btn-secundario btn-sm" data-accion="rechazar" data-id="${esc(t.id)}">
          No puedo
        </button>
      </div>`;
  }

  // La entrada se abre el mismo dia; antes, la base la rechaza
  if (t.estatus === 'aceptada' && t.fecha <= hoy) {
    return `
      <div class="turno-acciones">
        <button type="button" class="btn btn-primario btn-sm" data-accion="entrada" data-id="${esc(t.id)}">
          ${icono('reloj', 16)} Marcar entrada
        </button>
      </div>`;
  }

  if (t.estatus === 'en_curso') {
    return `
      <div class="turno-acciones">
        <button type="button" class="btn btn-primario btn-sm" data-accion="salida" data-id="${esc(t.id)}">
          ${icono('check', 16)} Marcar salida
        </button>
      </div>`;
  }

  return '';
}

/**
 * Tarjeta de un turno.
 * @param {object} t     renglon de panel_enfermero_turnos / _proximos
 * @param {object} opciones {acciones: bool, detalle: bool}
 */
function tarjetaTurno(t, { acciones = false, detalle = false } = {}) {
  const est   = ESTATUS_ASIGNACION[t.estatus] || { nombre: t.estatus, clase: 'badge-gris' };
  const turno = etiqueta(TURNOS, t.turno);
  const muni  = etiqueta(MUNICIPIOS, t.municipio) || t.municipio || '';
  const esPropuesta = t.estatus === 'propuesta';

  // La direccion solo llega de la base cuando el turno ya fue aceptado
  // (regla 10.8). Mientras es propuesta se muestra nada mas el municipio, y la
  // aclaracion va en su propio renglon: intercalada rompe la linea del dato.
  const lugar = t.direccion ? `${esc(t.direccion)}, ${esc(muni)}` : esc(muni);
  const notaLugar = (!t.direccion && esPropuesta)
    ? '<span class="turno-nota">La dirección exacta se muestra al aceptar.</span>'
    : '';

  // Lo que va a tener que hacer en el turno: es lo que le permite decidir si
  // acepta. Solo se despliega donde hay espacio para leerlo.
  const procs = (detalle && Array.isArray(t.procedimientos) && t.procedimientos.length)
    ? `<div class="turno-chips">
         ${t.procedimientos.map(p => `<span class="chip chip-neutro">${esc(etiqueta(PROCEDIMIENTOS, p))}</span>`).join('')}
       </div>`
    : '';

  const atencion = (detalle && t.nivel_atencion)
    ? `<span>${icono('escudo', 15)} ${esc(etiqueta(NIVELES_ATENCION, t.nivel_atencion))}</span>`
    : '';

  const marcas = [];
  if (t.checkin_at)  marcas.push(`Entrada ${esc(hora(t.checkin_at.slice(11, 16)))}`);
  if (t.checkout_at) marcas.push(`Salida ${esc(hora(t.checkout_at.slice(11, 16)))}`);
  const asistencia = marcas.length
    ? `<span class="turno-asistencia">${marcas.join(' · ')}</span>` : '';

  const rechazo = t.motivo_rechazo
    ? `<p class="turno-motivo">Motivo: ${esc(t.motivo_rechazo)}</p>` : '';

  const calif = t.calificacion
    ? `<span class="turno-calif">${estrellas(t.calificacion)}</span>` : '';

  return `
    <article class="turno${esPropuesta ? ' turno-propuesta' : ''}">
      ${bloqueFecha(t.fecha)}

      <div class="turno-cuerpo">
        <div class="turno-top">
          <span class="badge ${est.clase}">${esc(est.nombre)}</span>
          <span class="turno-cuando">${esc(cuandoEs(t.fecha))}</span>
        </div>

        <strong class="turno-titulo">${esc(turno || t.turno)}</strong>

        <div class="turno-datos">
          <span>${icono('reloj', 15)} ${esc(hora(t.hora_inicio))} a ${esc(hora(t.hora_fin))}</span>
          <span>${icono('ubicacion', 15)} ${lugar}</span>
          <span>${icono('maletin', 15)} ${esc(etiqueta(TIPOS_SERVICIO, t.tipo_servicio) || '')}</span>
          ${atencion}
          ${notaLugar}
        </div>

        ${procs}
        ${rechazo}

        <div class="turno-pie">
          <span class="turno-pago">${esc(moneda(t.tarifa_enfermero))}</span>
          ${calif}
          ${asistencia}
          ${esPropuesta && !acciones ? '<span class="turno-espera">Espera tu respuesta</span>' : ''}
        </div>

        ${acciones ? accionesTurno(t) : ''}
      </div>
    </article>`;
}

/**
 * Conecta los botones de una lista de turnos con la base.
 * @param {HTMLElement} zona  contenedor de las tarjetas
 * @param {Function} alTerminar  se llama tras cada cambio para repintar
 */
function activarAccionesTurno(zona, alTerminar) {
  zona.querySelectorAll('[data-accion]').forEach(boton => {
    boton.addEventListener('click', async () => {
      const { accion, id } = boton.dataset;

      // Rechazar exige motivo: la base lo pide y la agencia lo necesita para
      // reasignar con criterio.
      if (accion === 'rechazar') return pedirMotivoRechazo(id, alTerminar);

      const confirmaciones = {
        aceptar: '¿Confirmas que puedes cubrir este turno?',
        entrada: '¿Registrar tu entrada ahora?',
        salida:  '¿Registrar tu salida y dar el turno por terminado?'
      };
      if (!confirm(confirmaciones[accion])) return;

      boton.classList.add('cargando');
      boton.disabled = true;

      const llamada = accion === 'aceptar'
        ? db.rpc('responder_propuesta', { p_asignacion: id, p_acepta: true })
        : db.rpc('registrar_mi_asistencia', { p_asignacion: id, p_tipo: accion });

      const { datos, error } = await consultar(llamada);

      boton.classList.remove('cargando');
      boton.disabled = false;

      if (error) return toast(error, 'error');
      toast(datos?.mensaje || 'Listo.', 'exito');
      alTerminar();
    });
  });
}

/** Modal para capturar por que no puede cubrir el turno. */
function pedirMotivoRechazo(id, alTerminar) {
  abrirFormulario({
    titulo: 'No puedo cubrir este turno',
    textoGuardar: 'Enviar',
    campos: [{
      nombre: 'motivo', etiqueta: '¿Por qué?', tipo: 'select', requerido: true,
      opciones: [
        { id: 'Ya tengo otro compromiso ese día', nombre: 'Ya tengo otro compromiso ese día' },
        { id: 'La zona me queda muy lejos',       nombre: 'La zona me queda muy lejos' },
        { id: 'No es mi área de experiencia',     nombre: 'No es mi área de experiencia' },
        { id: 'El horario no me funciona',        nombre: 'El horario no me funciona' },
        { id: 'Por motivos personales',           nombre: 'Por motivos personales' }
      ],
      nota: 'La agencia lo necesita para buscar a alguien más cuanto antes.'
    }],
    alGuardar: async ({ motivo }) => {
      const { datos, error } = await consultar(
        db.rpc('responder_propuesta',
               { p_asignacion: id, p_acepta: false, p_motivo: motivo })
      );
      if (error) { toast(error, 'error'); return false; }
      toast(datos?.mensaje || 'Turno rechazado.', 'info');
      alTerminar();
    }
  });
}
