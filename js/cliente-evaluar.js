/* ==========================================================================
   Enlace Enfermero — Evaluar un servicio (cliente)
   Tres criterios más comentario, sobre turnos completados (CLAUDE.md 8.8).

   La calificación general no se pide: se calcula como promedio de los tres
   criterios. Pedirla por separado invita a contradecirse ("todo 5 pero
   general 3") y ensucia el promedio que sostiene el catálogo.

   El plazo son 15 días (regla 10.7). Los vencidos se muestran igual, marcados,
   para que no parezca que se perdieron sin explicación.
   ========================================================================== */

async function iniciarEvaluar() {
  cargarEvaluables();
}

async function cargarEvaluables() {
  const zona = document.getElementById('listaEvaluables');
  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(db.rpc('panel_cliente_evaluables'));

  if (error) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar los turnos', texto: error
    })}</div>`;
    return;
  }

  const lista = datos || [];
  const vigentes = lista.filter(t => !t.vencida);
  const vencidos = lista.filter(t => t.vencida);

  if (!lista.length) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'check',
      titulo: 'No tienes nada por evaluar',
      texto: 'Cuando termine un turno tendrás 15 días para calificarlo. ' +
             'Tus evaluaciones son lo que sostiene la calificación del personal.'
    })}</div>`;
    return;
  }

  zona.innerHTML = `
    ${vigentes.length ? `
      <section class="bloque-panel">
        <h2 class="titulo-bloque">Por evaluar <span class="conteo-inline">${vigentes.length}</span></h2>
        <div class="lista-turnos">${vigentes.map(filaEvaluable).join('')}</div>
      </section>` : ''}

    ${vencidos.length ? `
      <section class="bloque-panel">
        <h2 class="titulo-bloque">Fuera de plazo</h2>
        <p class="txt-secundario texto-sm mb-bloque">
          Pasaron más de 15 días desde que terminó el turno, así que ya no se
          pueden calificar.
        </p>
        <div class="lista-turnos">${vencidos.map(filaEvaluable).join('')}</div>
      </section>` : ''}`;

  zona.querySelectorAll('[data-evaluar]').forEach(b =>
    b.addEventListener('click', () => {
      const t = lista.find(x => x.asignacion_id === b.dataset.evaluar);
      if (t) abrirEvaluacion(t);
    }));
}

function filaEvaluable(t) {
  const urgente = !t.vencida && t.dias_restantes <= 3;

  return `
    <article class="turno${t.vencida ? ' turno-vencido' : ''}">
      ${bloqueFechaCliente(t.fecha)}

      <div class="turno-cuerpo">
        <div class="turno-top">
          <span class="badge badge-gris">${esc(t.folio)}</span>
          ${t.vencida
            ? '<span class="turno-cuando txt-error">Plazo vencido</span>'
            : `<span class="turno-cuando${urgente ? ' txt-error' : ''}">
                 ${t.dias_restantes === 1 ? 'Queda 1 día' : `Quedan ${t.dias_restantes} días`}
               </span>`}
        </div>

        <strong class="turno-titulo">${esc(etiqueta(TURNOS, t.turno))}</strong>

        ${fichaProfesional({
          nombre: t.nombre, nivel: t.nivel, foto_url: t.foto_url,
          especialidades: []
        })}

        ${t.vencida ? '' : `
          <div class="turno-acciones">
            <button type="button" class="btn btn-primario btn-sm"
                    data-evaluar="${esc(t.asignacion_id)}">
              ${icono('estrella', 16)} Calificar
            </button>
          </div>`}
      </div>
    </article>`;
}

/** Modal con los tres criterios. */
function abrirEvaluacion(t) {
  let modal = document.getElementById('modalEvaluacion');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'modalEvaluacion';
    modal.className = 'modal-velo';
    document.body.appendChild(modal);
  }

  modal.innerHTML = `
    <div class="modal modal-ancho">
      <header class="modal-cabecera">
        <h3>Calificar el turno</h3>
        <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">
          ${icono('cerrar', 20)}
        </button>
      </header>

      <form id="formEvaluacion">
        <div class="modal-cuerpo">
          <p class="txt-secundario texto-sm">
            ${esc(t.nombre)} · ${esc(etiqueta(TURNOS, t.turno))} del
            ${esc(fechaCorta(t.fecha))}
          </p>

          ${selectorEstrellas('puntualidad', 'Puntualidad',
            '¿Llegó a tiempo y cumplió el horario?')}
          ${selectorEstrellas('trato', 'Trato',
            '¿Cómo trató al paciente y a la familia?')}
          ${selectorEstrellas('competencia', 'Competencia técnica',
            '¿Resolvió lo que el cuidado exigía?')}

          <div class="campo">
            <label for="comentario">Comentario (opcional)</label>
            <textarea id="comentario" name="comentario" rows="3" maxlength="500"
              placeholder="Lo que quieras destacar o señalar."></textarea>
          </div>

          <label class="check">
            <input type="checkbox" name="publica" checked>
            <span>Permitir que se muestre en el perfil público del profesional</span>
          </label>
        </div>

        <footer class="modal-pie">
          <button type="button" class="btn btn-secundario" data-cerrar>Cancelar</button>
          <button type="submit" class="btn btn-primario" id="btnEnviarEval">
            Enviar calificación
          </button>
        </footer>
      </form>
    </div>`;

  modal.classList.add('abierto');
  activarEstrellas(modal);

  const cerrar = () => { modal.classList.remove('abierto'); modal.innerHTML = ''; };
  modal.querySelectorAll('[data-cerrar]').forEach(b => b.addEventListener('click', cerrar));
  modal.addEventListener('click', e => { if (e.target === modal) cerrar(); });

  document.getElementById('formEvaluacion').addEventListener('submit', async (e) => {
    e.preventDefault();
    const form  = e.target;
    const boton = document.getElementById('btnEnviarEval');

    const leer = (n) => Number(form.querySelector(`[name="${n}"]:checked`)?.value || 0);
    const p = leer('puntualidad'), tr = leer('trato'), c = leer('competencia');

    if (!p || !tr || !c) {
      toast('Califica los tres criterios.', 'error');
      return;
    }

    boton.classList.add('cargando');
    boton.disabled = true;

    const { datos, error } = await consultar(db.rpc('guardar_evaluacion', {
      p_asignacion:  t.asignacion_id,
      p_puntualidad: p,
      p_trato:       tr,
      p_competencia: c,
      p_comentario:  form.querySelector('[name="comentario"]').value || null,
      p_publica:     form.querySelector('[name="publica"]').checked
    }));

    boton.classList.remove('cargando');
    boton.disabled = false;

    if (error) return toast(error, 'error');

    toast(datos?.mensaje || 'Gracias por tu evaluación.', 'exito');
    cerrar();
    cargarEvaluables();
  });
}
