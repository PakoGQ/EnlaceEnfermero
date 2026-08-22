/* ==========================================================================
   Enlace Enfermero — Piezas compartidas del panel del cliente

   REGLA QUE MANDA EN TODO ESTE PANEL (regla 10.8):
   al cliente se le muestra QUIÉN cubre su turno, nunca CÓMO contactarlo.
   Las funciones de la base ya devuelven sólo columnas seguras; aquí no hay
   que pintar nada que no venga de ellas.
   ========================================================================== */

/** Ficha de un profesional, sin un solo dato de contacto. */
function fichaProfesional(p, { extra = '' } = {}) {
  const nivel = etiqueta(NIVELES, p.nivel);
  const esp   = (p.especialidades || []).slice(0, 3);

  return `
    <div class="profesional">
      ${p.foto_url
        ? `<img src="${esc(p.foto_url)}" alt="" class="profesional-foto" loading="lazy">`
        : `<span class="profesional-foto profesional-inicial" aria-hidden="true">${esc(iniciales(p.nombre))}</span>`}

      <div class="profesional-datos">
        <strong>${esc(p.nombre)}</strong>
        <span class="profesional-nivel">${esc(nivel)}</span>
        <div class="profesional-meta">
          ${p.calificacion ? estrellas(p.calificacion) : ''}
          ${p.anios_experiencia ? `<span>${p.anios_experiencia} años de experiencia</span>` : ''}
        </div>
        ${esp.length ? `<div class="profesional-chips">
          ${esp.map(e => `<span class="chip">${esc(etiqueta(ESPECIALIDADES, e))}</span>`).join('')}
        </div>` : ''}
      </div>

      ${extra}
    </div>`;
}

/** Estrellas para capturar una calificación de 1 a 5. */
function selectorEstrellas(nombre, etiquetaTexto, ayuda = '') {
  return `
    <fieldset class="calif-grupo">
      <legend>${esc(etiquetaTexto)}</legend>
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
      <div class="calif-estrellas" data-calif="${nombre}">
        ${[1, 2, 3, 4, 5].map(n => `
          <label class="calif-estrella">
            <input type="radio" name="${nombre}" value="${n}" required>
            <span aria-label="${n} de 5">${icono('estrella', 26)}</span>
          </label>`).join('')}
      </div>
    </fieldset>`;
}

/**
 * Enciende las estrellas hasta la elegida.
 * El CSS no puede pintar "hacia atrás" —el input vive dentro del label, así
 * que el selector de hermanos no alcanza—, de modo que el valor se refleja en
 * un data-valor del contenedor, igual que hace el medidor de contraseña.
 */
function activarEstrellas(raiz = document) {
  raiz.querySelectorAll('.calif-estrellas[data-calif]').forEach(grupo => {
    grupo.addEventListener('change', () => {
      const elegido = grupo.querySelector('input:checked');
      if (elegido) grupo.dataset.valor = elegido.value;
    });
  });
}

/** Día y mes en grande, igual que en el panel del profesional. */
function bloqueFechaCliente(iso) {
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

/** Cuánto falta, en palabras. */
function cuandoEsCliente(iso) {
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
