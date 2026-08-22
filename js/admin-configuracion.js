/* ==========================================================================
   Enlace Enfermero — Configuración (panel de la agencia)
   Reparto, datos de contacto, tarifas de referencia y catálogos.
   ========================================================================== */

const conf = { datos: {} };

async function cargarConfiguracion() {
  const { datos, error } = await consultar(db.rpc('leer_configuracion'));

  if (error) {
    document.getElementById('contenido').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar la configuración', texto: error });
    return;
  }

  conf.datos = datos || {};
  pintarConfiguracion();
}

function pintarConfiguracion() {
  const reparto = conf.datos.reparto?.valor || { enfermero: 0.60, agencia: 0.40 };
  const agencia = conf.datos.agencia?.valor || {};
  const tarifas = conf.datos.tarifas_referencia?.valor || {};
  const recomp  = conf.datos.recompensas_referido?.valor || {};

  document.getElementById('contenido').innerHTML = `

    <section class="tarjeta bloque-config">
      <div class="tarjeta-cabecera">
        <div>
          <h3>Reparto de cada servicio</h3>
          <p class="texto-sm txt-secundario">
            Cómo se divide lo que paga el cliente. Los dos porcentajes deben sumar 100%.
          </p>
        </div>
      </div>

      <form id="formReparto" class="form-config">
        <div class="campos-fila">
          <div class="campo">
            <label for="pctEnfermero">Al profesional (%)</label>
            <input type="number" id="pctEnfermero" min="0" max="100" step="1"
                   value="${Math.round(reparto.enfermero * 100)}">
          </div>
          <div class="campo">
            <label for="pctAgencia">A la agencia (%)</label>
            <input type="number" id="pctAgencia" min="0" max="100" step="1"
                   value="${Math.round(reparto.agencia * 100)}">
          </div>
        </div>
        <div class="reparto-vista" id="vistaReparto"></div>
        <button type="submit" class="btn btn-primario">Guardar reparto</button>
      </form>
    </section>

    <section class="tarjeta bloque-config">
      <div class="tarjeta-cabecera">
        <div>
          <h3>Datos de la agencia</h3>
          <p class="texto-sm txt-secundario">Es lo que ve el público en el sitio.</p>
        </div>
      </div>

      <form id="formAgencia" class="form-config">
        <div class="campo">
          <label for="agNombre">Nombre comercial</label>
          <input type="text" id="agNombre" value="${esc(agencia.nombre || '')}">
        </div>
        <div class="campos-fila">
          <div class="campo">
            <label for="agWhatsapp">WhatsApp</label>
            <input type="tel" id="agWhatsapp" value="${esc(agencia.whatsapp || '')}"
                   placeholder="523312345678">
            <span class="ayuda">Con lada del país, sin espacios ni signos.</span>
          </div>
          <div class="campo">
            <label for="agEmail">Correo</label>
            <input type="email" id="agEmail" value="${esc(agencia.email || '')}">
          </div>
        </div>
        <div class="campo">
          <label for="agCiudad">Ciudad base</label>
          <input type="text" id="agCiudad" value="${esc(agencia.ciudad || '')}">
        </div>
        <button type="submit" class="btn btn-primario">Guardar datos</button>
      </form>
    </section>

    <section class="tarjeta bloque-config">
      <div class="tarjeta-cabecera">
        <div>
          <h3>Tarifas de referencia</h3>
          <p class="texto-sm txt-secundario">
            Punto de partida para cotizar, por nivel. <strong>No es un tabulador cerrado</strong>:
            cada servicio se cotiza según el paciente, los procedimientos y el entorno.
          </p>
        </div>
      </div>

      <form id="formTarifas" class="form-config">
        <div class="tabla-contenedor">
          <table class="tabla">
            <thead>
              <tr><th>Nivel</th><th>Turno 8 h</th><th>Turno 12 h</th><th>Turno 24 h</th></tr>
            </thead>
            <tbody>
              ${NIVELES.map(n => `
                <tr>
                  <td>${esc(n.nombre)}</td>
                  ${['8', '12', '24'].map(h => `
                    <td><input type="number" min="0" step="50" class="entrada entrada-mini"
                        data-nivel="${n.id}" data-turno="${h}"
                        value="${esc(tarifas[n.id]?.['t' + h] ?? '')}" placeholder="—"></td>`).join('')}
                </tr>`).join('')}
            </tbody>
          </table>
        </div>
        <button type="submit" class="btn btn-primario">Guardar tarifas</button>
      </form>
    </section>

    <section class="tarjeta bloque-config">
      <div class="tarjeta-cabecera">
        <div>
          <h3>Programa de referidos</h3>
          <p class="texto-sm txt-secundario">
            Se acredita cuando el referido completa su primer servicio pagado.
          </p>
        </div>
      </div>

      <form id="formRecompensas" class="form-config">
        <div class="campos-fila">
          <div class="campo">
            <label for="recEnfermero">Enfermero refiere enfermero (MXN)</label>
            <input type="number" id="recEnfermero" min="0" step="50" value="${esc(recomp.enfermero ?? 300)}">
          </div>
          <div class="campo">
            <label for="recCliente">Cliente refiere cliente (% descuento)</label>
            <input type="number" id="recCliente" min="0" max="100" step="1"
                   value="${Math.round((recomp.cliente_descuento ?? 0.10) * 100)}">
          </div>
        </div>
        <button type="submit" class="btn btn-primario">Guardar recompensas</button>
      </form>
    </section>

    <section class="tarjeta bloque-config">
      <div class="tarjeta-cabecera"><h3>Catálogos</h3></div>
      <p class="texto-sm txt-secundario">
        Especialidades, certificaciones, municipios y niveles viven en
        <code>js/config.js</code>. Cambiarlos ahí afecta a todo el sitio a la vez.
        No se editan desde aquí porque sus identificadores ya están guardados en
        los perfiles y las solicitudes: renombrarlos sin migrar rompería los datos.
      </p>
      <dl class="detalle-datos">
        <div><dt>Especialidades</dt><dd>${ESPECIALIDADES.length}</dd></div>
        <div><dt>Certificaciones</dt><dd>${CERTIFICACIONES.length}</dd></div>
        <div><dt>Municipios</dt><dd>${MUNICIPIOS.length}</dd></div>
        <div><dt>Procedimientos</dt><dd>${PROCEDIMIENTOS.length}</dd></div>
      </dl>
    </section>`;

  conectarFormularios();
  mostrarVistaReparto();
}

function mostrarVistaReparto() {
  const enf = Number(document.getElementById('pctEnfermero').value) || 0;
  const ag  = Number(document.getElementById('pctAgencia').value) || 0;
  const zona = document.getElementById('vistaReparto');
  const suma = enf + ag;

  if (suma !== 100) {
    zona.innerHTML = `<p class="texto-sm txt-error">
      Los porcentajes suman ${suma}%. Tienen que sumar exactamente 100%.</p>`;
    return;
  }

  // Ejemplo con un monto redondo, para que se vea el efecto real
  const ejemplo = 2000;
  zona.innerHTML = `
    <p class="texto-sm txt-secundario">Sobre un servicio de ${moneda(ejemplo)}:</p>
    <div class="reparto-barra">
      <div class="reparto-parte enfermero" style="flex:${enf}">
        <span>Profesional</span><strong>${moneda(ejemplo * enf / 100)}</strong>
      </div>
      <div class="reparto-parte agencia" style="flex:${ag}">
        <span>Agencia</span><strong>${moneda(ejemplo * ag / 100)}</strong>
      </div>
    </div>`;
}

function conectarFormularios() {
  ['pctEnfermero', 'pctAgencia'].forEach(id =>
    document.getElementById(id).addEventListener('input', () => {
      // Al mover uno, el otro se ajusta para que siempre sumen 100
      const otro = id === 'pctEnfermero' ? 'pctAgencia' : 'pctEnfermero';
      const v = Number(document.getElementById(id).value);
      if (v >= 0 && v <= 100) document.getElementById(otro).value = 100 - v;
      mostrarVistaReparto();
    }));

  document.getElementById('formReparto').addEventListener('submit', async (e) => {
    e.preventDefault();
    const enf = Number(document.getElementById('pctEnfermero').value);
    const ag  = Number(document.getElementById('pctAgencia').value);

    if (enf + ag !== 100) { toast('Los porcentajes deben sumar 100%.', 'error'); return; }
    if (!confirm(`El reparto quedará en ${enf}% para el profesional y ${ag}% para la agencia.\n\n` +
                 'Aplica a los servicios nuevos; los ya registrados no cambian. ¿Continuar?')) return;

    await guardar('reparto', { enfermero: enf / 100, agencia: ag / 100 },
      'Reparto actualizado. Actualiza también CONFIG en js/config.js para que el sitio público lo refleje.');
  });

  document.getElementById('formAgencia').addEventListener('submit', async (e) => {
    e.preventDefault();
    const correo = document.getElementById('agEmail').value.trim();
    if (correo && !validar.email(correo)) { toast('Revisa el correo.', 'error'); return; }

    await guardar('agencia', {
      nombre:   document.getElementById('agNombre').value.trim(),
      whatsapp: soloDigitos(document.getElementById('agWhatsapp').value),
      email:    correo,
      ciudad:   document.getElementById('agCiudad').value.trim()
    }, 'Datos guardados.');
  });

  document.getElementById('formTarifas').addEventListener('submit', async (e) => {
    e.preventDefault();
    const tarifas = {};
    document.querySelectorAll('[data-nivel]').forEach(i => {
      const v = Number(i.value);
      if (!v) return;
      tarifas[i.dataset.nivel] = tarifas[i.dataset.nivel] || {};
      tarifas[i.dataset.nivel]['t' + i.dataset.turno] = v;
    });
    await guardar('tarifas_referencia', tarifas, 'Tarifas de referencia guardadas.');
  });

  document.getElementById('formRecompensas').addEventListener('submit', async (e) => {
    e.preventDefault();
    await guardar('recompensas_referido', {
      enfermero: Number(document.getElementById('recEnfermero').value) || 0,
      cliente_descuento: (Number(document.getElementById('recCliente').value) || 0) / 100
    }, 'Recompensas guardadas.');
  });
}

async function guardar(clave, valor, mensaje) {
  const { error } = await consultar(db.rpc('guardar_configuracion', { p_clave: clave, p_valor: valor }));
  if (error) { toast(error, 'error'); return; }
  toast(mensaje, 'exito', 4000);
  cargarConfiguracion();
}

function iniciarConfiguracion() {
  cargarConfiguracion();
}
