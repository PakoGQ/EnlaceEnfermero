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


/* ==========================================================================
   PIEZAS GRAFICAS

   Un numero solo dice CUANTO. La linea dice si va subiendo, y el anillo dice
   que tan cerca esta del tope: son la pregunta que de verdad se hace quien
   vive de turnos. Se dibujan con SVG en linea, sin librerias (regla 4).
   ========================================================================== */

/** Linea de tendencia de los ultimos meses. */
function chispita(serie) {
  const v = (serie || []).map(Number);
  if (v.length < 2) return '';

  const alto = 46, ancho = 150;
  const max = Math.max(...v, 1);
  const puntos = v.map((n, i) => {
    const x = (i / (v.length - 1)) * ancho;
    const y = alto - (n / max) * (alto - 8) - 4;
    return `${x.toFixed(1)} ${y.toFixed(1)}`;
  });

  const linea = 'M' + puntos.join(' L');
  const area  = `${linea} L${ancho} ${alto} L0 ${alto} Z`;
  const [ux, uy] = puntos[puntos.length - 1].split(' ');

  return `
    <svg class="chispita" width="${ancho}" height="${alto}" viewBox="0 0 ${ancho} ${alto}"
         fill="none" aria-hidden="true">
      <path d="${area}" fill="rgba(255,255,255,.22)"></path>
      <path class="chispita-linea" d="${linea}" stroke="rgba(255,255,255,.95)"
            stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"></path>
      <circle class="chispita-punta" cx="${ux}" cy="${uy}" r="4" fill="#FFFFFF"></circle>
    </svg>`;
}

/** Anillo de progreso, para una calificacion sobre 5. */
function anillo(valor, max = 5) {
  const r = 26, circ = 2 * Math.PI * r;
  const pct = Math.min(Number(valor) / max, 1);

  return `
    <div class="anillo">
      <svg width="64" height="64" viewBox="0 0 64 64" aria-hidden="true">
        <circle cx="32" cy="32" r="${r}" stroke="var(--gris-100)" stroke-width="6" fill="none"></circle>
        <circle class="anillo-arco" cx="32" cy="32" r="${r}" stroke="#F5B544" stroke-width="6"
                fill="none" stroke-linecap="round"
                stroke-dasharray="${circ.toFixed(1)}"
                style="--arco: ${(circ * (1 - pct)).toFixed(1)}"
                transform="rotate(-90 32 32)"></circle>
      </svg>
      <span class="anillo-valor">${esc(Number(valor) > 0 ? Number(valor).toFixed(1) : '—')}</span>
    </div>`;
}

/** Pinta los indicadores y el encabezado con el estado del perfil. */
function pintarResumen(datos) {
  const zona = document.getElementById('kpis');
  if (!zona) return;

  const porResponder = Number(datos.propuestas_pendientes) || 0;
  const ganado       = Number(datos.ganancias_mes) || 0;
  const anterior     = Number(datos.ganancias_mes_anterior) || 0;

  let cambio = '';
  if (anterior > 0) {
    const pct  = Math.round(((ganado - anterior) / anterior) * 100);
    const sube = pct >= 0;
    cambio = `<span class="kpi-cambio ${sube ? 'sube' : 'baja'}">
      ${sube ? '▲' : '▼'} ${Math.abs(pct)}% vs mes pasado</span>`;
  }

  zona.innerHTML = `
    <div class="tarjeta kpi entra entra-1${porResponder ? ' kpi-alerta' : ''}">
      ${porResponder ? '<span class="brillo"></span>' : ''}
      <span class="kpi-icono">${icono('inbox', 20)}</span>
      ${porResponder ? '<span class="kpi-sello">Urge</span>' : ''}
      <span class="kpi-valor">${porResponder}</span>
      <span class="kpi-etiqueta">Por responder</span>
    </div>

    <div class="tarjeta kpi entra entra-2">
      <span class="kpi-icono">${icono('calendario', 20)}</span>
      <span class="kpi-valor">${Number(datos.turnos_proximos) || 0}</span>
      <span class="kpi-etiqueta">Turnos aceptados</span>
    </div>

    <div class="tarjeta kpi kpi-dinero kpi-ancho entra entra-3">
      <div class="kpi-dinero-cuerpo">
        <div>
          <span class="kpi-etiqueta">Ganado este mes</span>
          <span class="kpi-valor">${esc(monedaCorta(ganado))}</span>
          ${cambio}
        </div>
        ${chispita(datos.serie_ganancias)}
      </div>
    </div>

    <div class="tarjeta kpi kpi-ancho kpi-calificacion entra entra-4">
      ${anillo(datos.calificacion)}
      <div>
        <span class="kpi-titulo">Tu calificación</span>
        <span class="kpi-etiqueta">${Number(datos.total_servicios) || 0} servicios completados</span>
      </div>
    </div>`;

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
  //
  // El punto late solo cuando esta publicado, porque es lo unico que esta
  // ocurriendo AHORA: hay clientes que en este momento pueden encontrarlo. Si
  // late siempre, deja de significar algo (CLAUDE.md 3.4).
  const visible = datos.publicado
    ? '<span class="badge badge-exito"><span class="punto-vivo"></span>Visible en el catálogo</span>'
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
