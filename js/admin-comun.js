/* ==========================================================================
   Enlace Enfermero — Piezas compartidas del panel de la agencia
   Tablas, filtros, modales de formulario y exportación a CSV.
   ========================================================================== */

/**
 * Pinta una tabla a partir de una definicion de columnas.
 * @param {string} destino id del contenedor
 * @param {array}  filas   datos
 * @param {array}  columnas [{titulo, valor(fila), clase, ancho}]
 * @param {object} vacio    {icono, titulo, texto} si no hay filas
 */
function pintarTabla(destino, filas, columnas, vacio = {}) {
  const zona = document.getElementById(destino);
  if (!zona) return;

  if (!filas.length) {
    zona.innerHTML = estadoVacio({
      icono: vacio.icono || 'inbox',
      titulo: vacio.titulo || 'Nada por aquí',
      texto: vacio.texto || 'No hay registros con estos filtros.'
    });
    return;
  }

  zona.innerHTML = `
    <div class="tabla-contenedor">
      <table class="tabla">
        <thead><tr>${columnas.map(c =>
          `<th ${c.ancho ? `style="width:${c.ancho}"` : ''} class="${c.clase || ''}">${esc(c.titulo)}</th>`
        ).join('')}</tr></thead>
        <tbody>
          ${filas.map(f => `<tr>${columnas.map(c =>
            `<td class="${c.clase || ''}">${c.valor(f)}</td>`).join('')}</tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

/**
 * Descarga los datos como CSV.
 * Se antepone el BOM para que Excel en Windows respete los acentos, que si no
 * salen como "MarÃ­a".
 */
function exportarCSV(nombre, filas, columnas) {
  if (!filas.length) {
    toast('No hay nada que exportar.', 'info');
    return;
  }

  const escapar = (v) => {
    const t = v === null || v === undefined ? '' : String(v);
    return /[",;\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t;
  };

  const lineas = [
    columnas.map(c => escapar(c.titulo)).join(','),
    ...filas.map(f => columnas.map(c => escapar(c.crudo(f))).join(','))
  ];

  const blob = new Blob(['﻿' + lineas.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${nombre}-${hoyISO()}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);

  toast(`Se descargaron ${filas.length} registros.`, 'exito', 2500);
}

/** Barra de filtros con botones. Devuelve el valor elegido por callback. */
function pintarFiltros(destino, opciones, activo, alCambiar) {
  const zona = document.getElementById(destino);
  if (!zona) return;

  zona.className = 'filtros-barra';
  zona.innerHTML = opciones.map(o => `
    <button type="button" class="filtro ${o.id === activo ? 'activo' : ''}" data-valor="${esc(o.id)}">
      ${esc(o.texto)}${o.conteo !== undefined ? ` <span class="filtro-conteo">${o.conteo}</span>` : ''}
    </button>`).join('');

  zona.querySelectorAll('[data-valor]').forEach(b =>
    b.addEventListener('click', () => {
      zona.querySelectorAll('.filtro').forEach(x => x.classList.remove('activo'));
      b.classList.add('activo');
      alCambiar(b.dataset.valor);
    }));
}

/* ==========================================================================
   MODAL DE FORMULARIO
   ========================================================================== */

/**
 * Abre un modal con campos y devuelve los datos al guardar.
 * @param {object} opciones {titulo, campos[], valores, alGuardar}
 */
function abrirFormulario({ titulo, campos, valores = {}, textoGuardar = 'Guardar', alGuardar }) {
  let modal = document.getElementById('modalFormulario');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'modalFormulario';
    modal.className = 'modal-velo';
    document.body.appendChild(modal);
  }

  const control = (c) => {
    const v = valores[c.nombre] ?? c.valor ?? '';
    switch (c.tipo) {
      case 'select':
        return `<select id="f_${c.nombre}" name="${c.nombre}" ${c.requerido ? 'required' : ''}>
          ${c.vacio !== false ? `<option value="">${esc(c.vacio || 'Selecciona')}</option>` : ''}
          ${c.opciones.map(o => `<option value="${esc(o.id)}" ${String(v) === String(o.id) ? 'selected' : ''}>
            ${esc(o.nombre)}</option>`).join('')}
        </select>`;
      case 'textarea':
        return `<textarea id="f_${c.nombre}" name="${c.nombre}" ${c.requerido ? 'required' : ''}
          placeholder="${esc(c.ayuda || '')}">${esc(v)}</textarea>`;
      case 'checkbox':
        return `<label class="check">
          <input type="checkbox" id="f_${c.nombre}" name="${c.nombre}" ${v ? 'checked' : ''}>
          <span>${esc(c.etiqueta)}</span></label>`;
      case 'checks':
        return `<div class="lista-checks lista-checks-corta">
          ${c.opciones.map(o => `<label class="check">
            <input type="checkbox" name="${c.nombre}" value="${esc(o.id)}"
              ${(Array.isArray(v) && v.includes(o.id)) ? 'checked' : ''}>
            <span>${esc(o.nombre)}</span></label>`).join('')}
        </div>`;
      default:
        return `<input type="${c.tipo || 'text'}" id="f_${c.nombre}" name="${c.nombre}"
          value="${esc(v)}" ${c.requerido ? 'required' : ''}
          ${c.min !== undefined ? `min="${c.min}"` : ''} ${c.paso ? `step="${c.paso}"` : ''}
          placeholder="${esc(c.ayuda || '')}">`;
    }
  };

  modal.innerHTML = `
    <div class="modal modal-ancho">
      <header class="modal-cabecera">
        <h3>${esc(titulo)}</h3>
        <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono('cerrar', 20)}</button>
      </header>
      <form id="formModal">
        <div class="modal-cuerpo">
          ${campos.map(c => `
            <div class="campo ${c.ancho === 'medio' ? 'campo-medio' : ''}">
              ${c.tipo === 'checkbox' ? '' :
                `<label for="f_${c.nombre}">${esc(c.etiqueta)}
                  ${c.requerido ? '<span class="requerido">*</span>' : ''}</label>`}
              ${control(c)}
              ${c.nota ? `<span class="ayuda">${esc(c.nota)}</span>` : ''}
            </div>`).join('')}
        </div>
        <footer class="modal-pie">
          <button type="button" class="btn btn-secundario" data-cerrar>Cancelar</button>
          <button type="submit" class="btn btn-primario" id="btnGuardarModal">${esc(textoGuardar)}</button>
        </footer>
      </form>
    </div>`;

  modal.classList.add('abierto');

  const cerrar = () => {
    modal.classList.remove('abierto');
    modal.innerHTML = '';
  };

  modal.querySelectorAll('[data-cerrar]').forEach(b => b.addEventListener('click', cerrar));
  modal.addEventListener('click', (e) => { if (e.target === modal) cerrar(); });

  document.getElementById('formModal').addEventListener('submit', async (e) => {
    e.preventDefault();
    const boton = document.getElementById('btnGuardarModal');
    const datos = {};

    campos.forEach(c => {
      if (c.tipo === 'checks') {
        datos[c.nombre] = [...modal.querySelectorAll(`[name="${c.nombre}"]:checked`)].map(i => i.value);
      } else if (c.tipo === 'checkbox') {
        datos[c.nombre] = modal.querySelector(`[name="${c.nombre}"]`).checked;
      } else {
        datos[c.nombre] = modal.querySelector(`[name="${c.nombre}"]`).value;
      }
    });

    boton.classList.add('cargando');
    boton.disabled = true;
    const ok = await alGuardar(datos);
    boton.classList.remove('cargando');
    boton.disabled = false;

    if (ok !== false) cerrar();
  });

  return { cerrar };
}

/* ==========================================================================
   PERIODOS
   ========================================================================== */

/** Quincenas del mes, que es como corta la agencia. */
function quincenaActual() {
  const hoy = new Date();
  const dia = hoy.getDate();
  const anio = hoy.getFullYear();
  const mes = hoy.getMonth();

  const fmt = (d) => {
    const m = String(d.getMonth() + 1).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${String(d.getDate()).padStart(2, '0')}`;
  };

  return dia <= 15
    ? { desde: fmt(new Date(anio, mes, 1)),  hasta: fmt(new Date(anio, mes, 15)) }
    : { desde: fmt(new Date(anio, mes, 16)), hasta: fmt(new Date(anio, mes + 1, 0)) };
}

function mesActual() {
  const hoy = new Date();
  const fmt = (d) => {
    const m = String(d.getMonth() + 1).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${String(d.getDate()).padStart(2, '0')}`;
  };
  return {
    desde: fmt(new Date(hoy.getFullYear(), hoy.getMonth(), 1)),
    hasta: fmt(new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0))
  };
}
