/* ==========================================================================
   Enlace Enfermero — Mis turnos
   Donde el profesional acepta o rechaza lo que la agencia le propone y marca
   su entrada y salida (CLAUDE.md 8.7).

   Es la pantalla que cierra el ciclo: sin ella el admin propone y del otro
   lado no hay nadie que pueda responder.
   ========================================================================== */

let filtroTurnos = 'todos';

const FILTROS_TURNOS = [
  { id: 'todos',     nombre: 'Todos' },
  { id: 'propuesta', nombre: 'Por responder' },
  { id: 'aceptada',  nombre: 'Aceptados' },
  { id: 'en_curso',  nombre: 'En curso' }
];

async function cargarMisTurnos() {
  const zona = document.getElementById('listaTurnos');
  if (!zona) return;

  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(
    db.rpc('panel_enfermero_turnos', { p_grupo: 'activos', p_limite: 100 })
  );

  if (error) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta',
      titulo: 'No pudimos cargar tus turnos',
      texto: error
    })}</div>`;
    return;
  }

  const todos = datos || [];
  pintarFiltrosTurnos(todos);

  const visibles = filtroTurnos === 'todos'
    ? todos
    : todos.filter(t => t.estatus === filtroTurnos);

  if (!visibles.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'calendario',
      titulo: filtroTurnos === 'todos'
        ? 'No tienes turnos activos'
        : 'Nada en este filtro',
      texto: filtroTurnos === 'todos'
        ? 'Cuando la agencia te proponga un turno lo verás aquí. Ten tu ' +
          'disponibilidad al día para que te consideren primero.'
        : 'Prueba con otro filtro.',
      boton: filtroTurnos === 'todos'
        ? { texto: 'Marcar mi disponibilidad', href: 'disponibilidad.html' }
        : null
    })}</div>`;
    return;
  }

  // detalle:true porque aqui sí hay espacio para los procedimientos, y son
  // justo lo que le permite decidir si acepta el turno.
  zona.innerHTML = `<div class="lista-turnos">
    ${visibles.map(t => tarjetaTurno(t, { acciones: true, detalle: true })).join('')}
  </div>`;

  activarAccionesTurno(zona, cargarMisTurnos);
}

/** Los filtros llevan el conteo: un filtro vacío se ve y no se pica. */
function pintarFiltrosTurnos(turnos) {
  const zona = document.getElementById('filtros');
  if (!zona) return;

  const conteo = (id) => id === 'todos'
    ? turnos.length
    : turnos.filter(t => t.estatus === id).length;

  zona.innerHTML = FILTROS_TURNOS.map(f => {
    const n = conteo(f.id);
    return `
      <button type="button"
              class="filtro${filtroTurnos === f.id ? ' activo' : ''}${n === 0 ? ' vacio' : ''}"
              data-filtro="${f.id}" ${filtroTurnos === f.id ? 'aria-pressed="true"' : ''}>
        ${esc(f.nombre)} <span class="filtro-conteo">${n}</span>
      </button>`;
  }).join('');

  zona.querySelectorAll('[data-filtro]').forEach(b => {
    b.addEventListener('click', () => {
      filtroTurnos = b.dataset.filtro;
      actualizarURL({ estatus: filtroTurnos === 'todos' ? null : filtroTurnos });
      cargarMisTurnos();
    });
  });
}

function iniciarMisTurnos() {
  // Permite llegar desde una alerta del panel con el filtro puesto
  const desdeURL = paramURL('estatus');
  if (desdeURL && FILTROS_TURNOS.some(f => f.id === desdeURL)) filtroTurnos = desdeURL;

  cargarMisTurnos();
}
