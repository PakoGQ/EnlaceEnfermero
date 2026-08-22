/* ==========================================================================
   Enlace Enfermero — Personal que ha trabajado con el cliente
   Con la opción de volver a solicitar a quien ya conoce (CLAUDE.md 8.8).

   Que el cliente pueda pedir a la misma persona es bueno para todos: para el
   paciente, que no vuelve a empezar; para el profesional, que encadena turnos;
   y para la agencia, que cierra más rápido. Lo que no puede es contactarlo
   directo, así que "solicitar de nuevo" abre una solicitud, no un teléfono.
   ========================================================================== */

async function iniciarPersonalCliente() {
  const zona = document.getElementById('listaPersonal');

  const { datos, error } = await consultar(db.rpc('panel_cliente_personal'));

  if (error) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar tu personal', texto: error
    })}</div>`;
    return;
  }

  const lista = datos || [];
  if (!lista.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'usuarios',
      titulo: 'Todavía nadie ha cubierto un turno contigo',
      texto: 'Cuando confirmemos tu primer servicio, aquí queda el registro de ' +
             'quién trabajó contigo para que puedas volver a pedirlo.',
      boton: { texto: 'Solicitar personal', href: 'solicitar.html' }
    })}</div>`;
    return;
  }

  const activos = lista.filter(p => p.activo_ahora);
  const previos = lista.filter(p => !p.activo_ahora);

  zona.innerHTML = `
    ${activos.length ? bloquePersonal('Trabajando contigo ahora', activos) : ''}
    ${previos.length ? bloquePersonal('Han trabajado contigo', previos) : ''}`;

  zona.querySelectorAll('[data-solicitar]').forEach(b =>
    b.addEventListener('click', () => {
      // Se preselecciona el profesional en el formulario, igual que hace el
      // catálogo público con ?enfermero=
      window.location.href = `solicitar.html?enfermero=${encodeURIComponent(b.dataset.solicitar)}`;
    }));
}

function bloquePersonal(titulo, gente) {
  return `
    <section class="bloque-panel">
      <h2 class="titulo-bloque">${esc(titulo)} <span class="conteo-inline">${gente.length}</span></h2>
      <div class="rejilla-personal">
        ${gente.map(tarjetaPersonal).join('')}
      </div>
    </section>`;
}

function tarjetaPersonal(p) {
  return `
    <article class="tarjeta tarjeta-personal">
      ${fichaProfesional({ ...p, nombre: p.nombre })}

      <div class="personal-historial">
        <span>${p.turnos_contigo} ${p.turnos_contigo === 1 ? 'turno contigo' : 'turnos contigo'}</span>
        <span>Último: ${esc(fechaCorta(p.ultimo_turno))}</span>
      </div>

      <button type="button" class="btn btn-secundario btn-sm btn-bloque"
              data-solicitar="${esc(p.enfermero_id)}">
        Solicitar de nuevo
      </button>
    </article>`;
}
