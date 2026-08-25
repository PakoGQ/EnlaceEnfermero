/* ==========================================================================
   Enlace Enfermero — Panel del profesional
   Pantalla de inicio: proximos turnos, ganancias, calificacion, alertas de
   documentos y avance del perfil (CLAUDE.md 8.7).

   Todo sale de tres funciones de la base (sql/11-paneles.sql) que ya filtran
   por auth.uid(). Aqui no se pide nada por enfermero_id: si se pudiera, se
   podria pedir el de otro.
   ========================================================================== */

/* ==========================================================================
   INDICADORES
   ========================================================================== */

const KPIS_ENFERMERO = [
  { clave: 'propuestas_pendientes', titulo: 'Por responder',
    icono: 'inbox',  alertaSi: v => v > 0 },
  { clave: 'turnos_proximos',       titulo: 'Turnos aceptados',
    icono: 'calendario' },
  // `dinero: true` lo pinta en verde: es el numero por el que el profesional
  // abre la aplicacion (CLAUDE.md 3.4).
  { clave: 'ganancias_mes',         titulo: 'Ganado este mes',
    icono: 'dinero', moneda: true, dinero: true, comparar: 'ganancias_mes_anterior' },
  { clave: 'calificacion',          titulo: 'Tu calificación',
    icono: 'estrella', decimal: true }
];

/** Pinta los cuatro indicadores y el encabezado con el estado del perfil. */
function pintarResumen(datos) {
  const zona = document.getElementById('kpis');
  if (!zona) return;

  zona.innerHTML = KPIS_ENFERMERO.map((k, i) => {
    const valor = datos[k.clave] ?? 0;

    let texto;
    if (k.moneda)       texto = monedaCorta(valor);
    else if (k.decimal) texto = Number(valor) > 0 ? Number(valor).toFixed(1) : '—';
    else                texto = new Intl.NumberFormat('es-MX').format(valor);

    // El comparativo solo dice algo si el mes pasado hubo trabajo
    let cambio = '';
    if (k.comparar && Number(datos[k.comparar]) > 0) {
      const anterior = Number(datos[k.comparar]);
      const pct  = Math.round(((Number(valor) - anterior) / anterior) * 100);
      const sube = pct >= 0;
      cambio = `<span class="kpi-cambio ${sube ? 'sube' : 'baja'}">
        ${sube ? '▲' : '▼'} ${Math.abs(pct)}% vs mes pasado</span>`;
    }

    // La calificacion se acompana del total de servicios que la sostienen
    if (k.decimal && datos.total_servicios > 0) {
      cambio = `<span class="kpi-cambio">${datos.total_servicios} servicios</span>`;
    }

    const tono = k.alertaSi?.(valor) ? ' kpi-alerta' : (k.dinero ? ' kpi-dinero' : '');

    return `
      <div class="tarjeta kpi entra entra-${Math.min(i + 1, 6)}${tono}">
        <span class="kpi-icono">${icono(k.icono, 20)}</span>
        <span class="kpi-valor">${esc(texto)}</span>
        <span class="kpi-etiqueta">${esc(k.titulo)}</span>
        ${cambio}
      </div>`;
  }).join('');

  pintarEstadoPerfil(datos);
  pintarAvancePerfil(datos.perfil, datos);
}

/**
 * Linea de estado bajo el saludo: folio, verificacion y visibilidad.
 * Es lo primero que el profesional quiere saber: si ya lo pueden contratar.
 */
function pintarEstadoPerfil(datos) {
  const zona = document.getElementById('estadoPerfil');
  if (!zona) return;

  const verif = ESTATUS_VERIFICACION[datos.estatus_verificacion]
             || { nombre: datos.estatus_verificacion, clase: 'badge-gris' };

  // Verificado y publicado no son lo mismo: se puede estar verificado y fuera
  // del catalogo, por ejemplo tras vencerse un documento (regla 10.3).
  const visible = datos.publicado
    ? '<span class="badge badge-exito">Visible en el catálogo</span>'
    : '<span class="badge badge-gris">Fuera del catálogo</span>';

  zona.innerHTML = `
    <span class="badge badge-azul">${esc(datos.folio || '')}</span>
    <span class="badge ${verif.clase}">${esc(verif.nombre)}</span>
    ${visible}
    ${datos.disponible_inmediato
      ? '<span class="badge badge-cyan">Disponible de inmediato</span>' : ''}`;
}

/** Barra de avance del perfil, con lo que falta por llenar. */
function pintarAvancePerfil(perfil, datos) {
  const zona = document.getElementById('avancePerfil');
  if (!zona || !perfil) return;

  const pct       = perfil.pct ?? 0;
  const faltantes = perfil.faltantes || [];
  const completo  = pct >= 100;

  zona.innerHTML = `
    <div class="tarjeta-cabecera">
      <div>
        <h3>Tu perfil</h3>
        <p class="texto-sm txt-secundario">
          ${completo
            ? 'Está completo. Así te ven los clientes.'
            : 'Entre más completo, más veces te proponen para un turno.'}
        </p>
      </div>
      <strong class="avance-pct">${pct}%</strong>
    </div>

    <div class="avance-barra" role="progressbar" aria-valuenow="${pct}"
         aria-valuemin="0" aria-valuemax="100"
         aria-label="Avance de tu perfil">
      <div class="avance-relleno${completo ? ' completo' : ''}" style="width:${pct}%"></div>
    </div>
    <p class="texto-sm txt-secundario">${perfil.hechos} de ${perfil.total} datos capturados</p>

    ${faltantes.length ? `
      <div class="faltantes">
        ${icono('alerta', 16)}
        <span>Te falta: ${faltantes.map(f => esc(f)).join(', ')}.</span>
      </div>` : ''}

    <div class="expediente-acciones">
      <a href="perfil.html" class="btn btn-secundario btn-sm btn-bloque">
        ${completo ? 'Revisar mi perfil' : 'Completar mi perfil'}
      </a>
    </div>`;
}

/* ==========================================================================
   ALERTAS
   Solo se muestra lo que tiene algo pendiente: una lista llena de ceros
   ensena a ignorarla.
   ========================================================================== */

const ALERTAS_ENFERMERO = [
  // Solo los obligatorios sacan el perfil del catálogo (regla 10.3). Decirle a
  // alguien que está fuera cuando sigue publicado destruye la confianza en el
  // panel, así que los vencidos se cuentan por separado y se redactan distinto.
  { clave: 'vencidos_obligatorios', nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'documento obligatorio vencido' : 'documentos obligatorios vencidos'}`,
    detalle: 'Mientras siga vencido, tu perfil no aparece en el catálogo.',
    href: 'documentos.html' },

  { clave: 'documentos_vencidos', nivel: 'alerta',
    texto: (n, datos) => {
      const opcionales = n - (datos.vencidos_obligatorios || 0);
      return `${opcionales} ${opcionales === 1 ? 'certificación vencida' : 'certificaciones vencidas'}`;
    },
    detalle: 'Sigues en el catálogo, pero no podemos proponerte turnos que la exijan.',
    href: 'documentos.html',
    // Si todos los vencidos son obligatorios, ya lo dijo la alerta de arriba
    soloSi: (resumen, datos) => datos.documentos_vencidos > (datos.vencidos_obligatorios || 0) },

  { clave: 'documentos_rechazados', nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'documento rechazado' : 'documentos rechazados'}`,
    detalle: 'Revisa el motivo y vuelve a subirlo.',
    href: 'documentos.html' },

  { clave: 'sin_cerrar', nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'turno sin cerrar' : 'turnos sin cerrar'}`,
    detalle: 'Sin la salida registrada, el turno no entra al corte de pago.',
    href: 'asignaciones.html' },

  { clave: 'propuestas_urgentes', nivel: 'alerta',
    texto: n => `${n} ${n === 1 ? 'propuesta urgente' : 'propuestas urgentes'}`,
    detalle: 'El turno es pronto o la agencia lleva más de un día esperándote.',
    href: 'asignaciones.html' },

  { clave: 'documentos_por_vencer', nivel: 'alerta',
    texto: n => `${n} ${n === 1 ? 'documento vence' : 'documentos vencen'} en menos de 30 días`,
    detalle: 'Renuévalo antes de que caduque y evita salir del catálogo.',
    href: 'documentos.html' },

  { clave: 'obligatorios_faltantes', nivel: 'alerta',
    texto: n => `Falta ${n} ${n === 1 ? 'documento obligatorio' : 'documentos obligatorios'}`,
    detalle: 'Sin ellos no podemos verificar tu perfil ni proponerte turnos.',
    href: 'documentos.html',
    // Si la agencia ya te verifico, dio el expediente por bueno: seguir
    // pidiendo papeles que ella misma acepto solo confunde.
    soloSi: resumen => resumen.estatus_verificacion !== 'verificado' },

  { clave: 'documentos_en_revision', nivel: 'info',
    texto: n => `${n} ${n === 1 ? 'documento en revisión' : 'documentos en revisión'}`,
    detalle: 'Lo revisamos en 24 a 48 horas. No tienes que hacer nada.',
    href: 'documentos.html' }
];

function pintarAlertas(alertas, resumen) {
  const zona = document.getElementById('alertas');
  if (!zona) return;

  const activas = ALERTAS_ENFERMERO.filter(a =>
    (alertas[a.clave] ?? 0) > 0 && (!a.soloSi || a.soloSi(resumen, alertas))
  );

  if (!activas.length) {
    zona.innerHTML = `
      <div class="alerta-panel alerta-ok">
        ${icono('check', 20)}
        <div><strong>Todo en orden</strong>
        <span>No tienes documentos por renovar ni pendientes con la agencia.</span></div>
      </div>`;
    return;
  }

  const orden = { error: 0, alerta: 1, info: 2 };
  activas.sort((a, b) => orden[a.nivel] - orden[b.nivel]);

  zona.innerHTML = activas.map(a => {
    const n = alertas[a.clave];
    return `
      <a href="${a.href}" class="alerta-panel alerta-${a.nivel}">
        ${icono(a.nivel === 'info' ? 'reloj' : 'alerta', 20)}
        <div>
          <strong>${esc(a.texto(n, alertas))}</strong>
          <span>${esc(a.detalle)}</span>
        </div>
        <span class="alerta-flecha">${icono('flechaDer', 18)}</span>
      </a>`;
  }).join('');
}

/* ==========================================================================
   PROXIMOS TURNOS
   La tarjeta y los ayudantes de fecha viven en enfermero-comun.js, porque las
   comparten Inicio, Mis turnos e Historial.
   ========================================================================== */

function pintarProximos(turnos) {
  const zona = document.getElementById('proximosTurnos');
  if (!zona) return;

  if (!turnos.length) {
    zona.innerHTML = estadoVacio({
      icono: 'calendario',
      titulo: 'No tienes turnos programados',
      texto: 'Cuando la agencia te proponga un turno, aparecerá aquí. ' +
             'Mantén tu disponibilidad al día para que te consideren primero.'
    });
    return;
  }

  zona.innerHTML = `<div class="lista-turnos">${turnos.map(t => tarjetaTurno(t)).join('')}</div>`;
}

/* ==========================================================================
   ARRANQUE
   ========================================================================== */

async function iniciarPanelEnfermero() {
  const zonaKpis = document.getElementById('kpis');

  const [resumen, alertas, proximos] = await Promise.all([
    consultar(db.rpc('panel_enfermero_resumen')),
    consultar(db.rpc('panel_enfermero_alertas')),
    consultar(db.rpc('panel_enfermero_proximos', { p_limite: 6 }))
  ]);

  if (resumen.error || !resumen.datos) {
    if (zonaKpis) {
      zonaKpis.innerHTML = `<div class="tarjeta kpis-ancho-total">
        ${estadoVacio({
          icono: 'alerta',
          titulo: 'No pudimos cargar tu panel',
          texto: resumen.error || 'Vuelve a cargar la página en un momento.'
        })}</div>`;
    }
    return;
  }

  pintarResumen(resumen.datos);

  if (!alertas.error && alertas.datos) pintarAlertas(alertas.datos, resumen.datos);
  pintarProximos(proximos.error ? [] : (proximos.datos || []));

  // El saludo lleva el nombre de la ficha profesional, que es el que aparece
  // en el catalogo, y no el de la cuenta.
  const saludo = document.getElementById('saludo');
  if (saludo && resumen.datos.nombre) {
    saludo.textContent = `¡Hola, ${resumen.datos.nombre.split(' ')[0]}!`;
  }
}
