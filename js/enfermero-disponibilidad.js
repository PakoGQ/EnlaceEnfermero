/* ==========================================================================
   Enlace Enfermero — Mi disponibilidad
   Calendario mensual: se toca un día y se marcan los turnos que puede cubrir.

   Es la pantalla que más rinde de todo el panel. El motor de match
   (sugerir_enfermeros) cruza nivel, zona, especialidad y disponibilidad en la
   fecha: si nadie marca nada, ese motor trabaja a ciegas y el coordinador
   acaba llamando uno por uno de todas formas.
   ========================================================================== */

let mesVisible = new Date();
let fichaDisp  = null;
let marcas     = {};   // 'YYYY-MM-DD' -> Set de turnos disponibles

/* Postgres numera los días con 0 = domingo; el calendario arranca en lunes. */
const DIAS_CABECERA = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

async function iniciarDisponibilidad() {
  const { datos, error } = await consultar(db.rpc('mi_enfermero_id'));
  if (error || !datos) {
    document.getElementById('calendario').innerHTML = estadoVacio({
      icono: 'alerta',
      titulo: 'No encontramos tu perfil',
      texto: 'Tu cuenta no está ligada a un perfil profesional. Escríbenos.'
    });
    return;
  }
  fichaDisp = datos;

  document.getElementById('mesAnterior')
    .addEventListener('click', () => moverMes(-1));
  document.getElementById('mesSiguiente')
    .addEventListener('click', () => moverMes(1));
  document.getElementById('btnPlantilla')
    .addEventListener('click', abrirPlantilla);

  cargarMes();
}

function moverMes(delta) {
  mesVisible = new Date(mesVisible.getFullYear(), mesVisible.getMonth() + delta, 1);
  cargarMes();
}

async function cargarMes() {
  const zona = document.getElementById('calendario');
  zona.innerHTML = '<div class="spinner"></div>';

  const anio = mesVisible.getFullYear();
  const mes  = mesVisible.getMonth();
  const primero = new Date(anio, mes, 1);
  const ultimo  = new Date(anio, mes + 1, 0);

  document.getElementById('tituloMes').textContent =
    new Intl.DateTimeFormat('es-MX', { month: 'long', year: 'numeric' })
      .format(primero).replace(/^\w/, c => c.toUpperCase());

  // El filtro por enfermero_id es obligatorio: la tabla también tiene una
  // policy pública que deja ver la disponibilidad de los perfiles publicados,
  // así que sin filtrar entrarían turnos de otras personas al calendario.
  const { datos, error } = await consultar(
    db.from('disponibilidad')
      .select('fecha, turno, disponible')
      .eq('enfermero_id', fichaDisp)
      .gte('fecha', iso(primero))
      .lte('fecha', iso(ultimo))
  );

  if (error) {
    zona.innerHTML = estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar tu calendario', texto: error
    });
    return;
  }

  marcas = {};
  (datos || []).forEach(d => {
    if (!d.disponible) return;
    (marcas[d.fecha] = marcas[d.fecha] || new Set()).add(d.turno);
  });

  pintarCalendario(anio, mes, ultimo.getDate());
}

function iso(f) {
  return `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`;
}

function pintarCalendario(anio, mes, diasDelMes) {
  // getDay() da 0 para domingo; se recorre para que la semana empiece en lunes
  const primerDia = (new Date(anio, mes, 1).getDay() + 6) % 7;
  const hoy = hoyISO();

  const celdas = [];
  for (let i = 0; i < primerDia; i++) celdas.push('<div class="dia-vacio"></div>');

  for (let d = 1; d <= diasDelMes; d++) {
    const fecha = `${anio}-${String(mes + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const turnos = marcas[fecha];
    const n = turnos ? turnos.size : 0;
    const pasado = fecha < hoy;

    celdas.push(`
      <button type="button"
              class="dia${n ? ' con-turnos' : ''}${fecha === hoy ? ' es-hoy' : ''}${pasado ? ' pasado' : ''}"
              data-fecha="${fecha}" ${pasado ? 'disabled' : ''}
              aria-label="${d} — ${n ? n + ' turnos disponibles' : 'sin marcar'}">
        <span class="dia-num">${d}</span>
        ${n ? `<span class="dia-conteo">${n}</span>` : ''}
      </button>`);
  }

  document.getElementById('calendario').innerHTML = `
    <div class="cal-cabecera" aria-hidden="true">
      ${DIAS_CABECERA.map(d => `<span>${d}</span>`).join('')}
    </div>
    <div class="cal-rejilla">${celdas.join('')}</div>
    <p class="cal-pie">
      ${icono('reloj', 15)}
      Toca un día para marcar los turnos que puedes cubrir. Los días pasados
      no se editan.
    </p>`;

  document.querySelectorAll('.dia[data-fecha]').forEach(b =>
    b.addEventListener('click', () => abrirDia(b.dataset.fecha)));
}

/** Hoja de un día: los seis turnos como casillas. */
function abrirDia(fecha) {
  const actuales = marcas[fecha] || new Set();

  abrirFormulario({
    titulo: fechaLarga(fecha),
    textoGuardar: 'Guardar el día',
    campos: [{
      nombre: 'turnos', etiqueta: '¿Qué turnos puedes cubrir?', tipo: 'checks',
      opciones: TURNOS,
      valor: [...actuales],
      nota: 'Desmarca todo para dejar el día libre.'
    }],
    valores: { turnos: [...actuales] },
    alGuardar: async ({ turnos }) => {
      const elegidos = new Set(turnos);

      // Se escribe una fila por turno con su bandera: así queda constancia de
      // que dijo "no puedo" y no simplemente que nunca contestó.
      const filas = TURNOS.map(t => ({
        enfermero_id: fichaDisp,
        fecha,
        turno: t.id,
        disponible: elegidos.has(t.id)
      }));

      const { error } = await consultar(
        db.from('disponibilidad')
          .upsert(filas, { onConflict: 'enfermero_id,fecha,turno' })
      );

      if (error) { toast(error, 'error'); return false; }

      toast(elegidos.size
        ? `${elegidos.size} ${elegidos.size === 1 ? 'turno marcado' : 'turnos marcados'}.`
        : 'Día marcado como no disponible.', 'exito');
      cargarMes();
    }
  });
}

/** Plantilla semanal: lo que casi todo el mundo necesita en realidad. */
function abrirPlantilla() {
  const hoy = new Date();
  const enDosMeses = new Date(hoy.getFullYear(), hoy.getMonth() + 2, hoy.getDate());

  abrirFormulario({
    titulo: 'Aplicar plantilla semanal',
    textoGuardar: 'Aplicar',
    campos: [
      { nombre: 'dias', etiqueta: '¿Qué días de la semana?', tipo: 'checks',
        opciones: [
          { id: '1', nombre: 'Lunes' },    { id: '2', nombre: 'Martes' },
          { id: '3', nombre: 'Miércoles' },{ id: '4', nombre: 'Jueves' },
          { id: '5', nombre: 'Viernes' },  { id: '6', nombre: 'Sábado' },
          { id: '0', nombre: 'Domingo' }
        ] },
      { nombre: 'turnos', etiqueta: '¿Qué turnos?', tipo: 'checks', opciones: TURNOS },
      { nombre: 'desde', etiqueta: 'Desde', tipo: 'date', ancho: 'medio',
        valor: hoyISO() },
      { nombre: 'hasta', etiqueta: 'Hasta', tipo: 'date', ancho: 'medio',
        valor: iso(enDosMeses),
        nota: 'Máximo 6 meses hacia adelante.' }
    ],
    alGuardar: async (v) => {
      if (!v.dias.length || !v.turnos.length) {
        toast('Elige al menos un día y un turno.', 'error');
        return false;
      }

      const { datos, error } = await consultar(
        db.rpc('aplicar_plantilla_disponibilidad', {
          p_desde: v.desde,
          p_hasta: v.hasta,
          p_dias: v.dias.map(Number),
          p_turnos: v.turnos,
          p_disponible: true
        })
      );

      if (error) { toast(error, 'error'); return false; }
      toast(datos?.mensaje || 'Plantilla aplicada.', 'exito');
      cargarMes();
    }
  });
}
