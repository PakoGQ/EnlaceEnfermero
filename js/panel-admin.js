/* ==========================================================================
   Enlace Enfermero — Panel de la agencia
   Indicadores, alertas, grafica de turnos y ultimas solicitudes (CLAUDE.md 8.6).
   ========================================================================== */

/* ==========================================================================
   INDICADORES
   ========================================================================== */

const KPIS = [
  { clave: 'solicitudes_nuevas_hoy',     titulo: 'Solicitudes hoy',    icono: 'inbox',      href: 'solicitudes.html' },
  { clave: 'turnos_por_cubrir',          titulo: 'Por cubrir',         icono: 'alerta',     href: 'solicitudes.html?estatus=en_busqueda', alertaSi: v => v > 0 },
  { clave: 'turnos_en_curso',            titulo: 'En curso ahora',     icono: 'reloj',      href: 'asignaciones.html?estatus=en_curso' },
  { clave: 'enfermeros_disponibles_hoy', titulo: 'Disponibles hoy',    icono: 'usuarios',   href: 'enfermeros.html?disponible=1' },
  { clave: 'ingresos_mes',               titulo: 'Ingresos del mes',   icono: 'dinero',     href: 'reportes.html', moneda: true },
  // La comision es el numero del negocio: va en verde (CLAUDE.md 3.4)
  { clave: 'comision_mes',               titulo: 'Comisión del mes',   icono: 'maletin',    href: 'reportes.html', moneda: true, dinero: true, comparar: 'comision_mes_anterior' }
];

async function cargarKpis() {
  const zona = document.getElementById('kpis');
  if (!zona) return;

  const { datos, error } = await consultar(db.rpc('kpis_dashboard'));

  if (error || !datos) {
    zona.innerHTML = `<div class="tarjeta" style="grid-column:1/-1">
      ${estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar los indicadores',
                      texto: error || 'Intenta recargar la página.' })}</div>`;
    return;
  }

  zona.innerHTML = KPIS.map((k, i) => {
    const valor = datos[k.clave] ?? 0;
    const texto = k.moneda ? monedaCorta(valor) : new Intl.NumberFormat('es-MX').format(valor);
    const tono = k.alertaSi?.(valor) ? ' kpi-alerta' : (k.dinero ? ' kpi-dinero' : '');

    // Comparativo contra el periodo anterior, cuando aplica
    let cambio = '';
    if (k.comparar && datos[k.comparar] > 0) {
      const anterior = Number(datos[k.comparar]);
      const pct = Math.round(((Number(valor) - anterior) / anterior) * 100);
      const sube = pct >= 0;
      cambio = `<span class="kpi-cambio ${sube ? 'sube' : 'baja'}">
        ${sube ? '▲' : '▼'} ${Math.abs(pct)}% vs mes anterior</span>`;
    }

    return `
      <a href="${k.href}" class="tarjeta kpi entra entra-${Math.min(i + 1, 6)}${tono}">
        <span class="kpi-icono">${icono(k.icono, 20)}</span>
        <span class="kpi-valor">${esc(texto)}</span>
        <span class="kpi-etiqueta">${esc(k.titulo)}</span>
        ${cambio}
      </a>`;
  }).join('');
}

/* ==========================================================================
   ALERTAS
   Solo se muestran las que tienen algo pendiente: una bandeja llena de ceros
   entrena al coordinador a ignorarla.
   ========================================================================== */

const ALERTAS = [
  // Solo los obligatorios despublican (regla 10.3). Decir lo contrario sobre un
  // BLS caducado manda al coordinador a "arreglar" un perfil que esta bien.
  { clave: 'vencidos_obligatorios',   nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'documento obligatorio vencido' : 'documentos obligatorios vencidos'}`,
    detalle: 'Esos perfiles ya salieron del catálogo hasta que se renueven.',
    href: 'documentos.html?estatus=vencido' },

  { clave: 'documentos_vencidos',     nivel: 'alerta',
    texto: (n, datos) => {
      const opcionales = n - (datos.vencidos_obligatorios || 0);
      return `${opcionales} ${opcionales === 1 ? 'certificación vencida' : 'certificaciones vencidas'}`;
    },
    detalle: 'El perfil sigue publicado, pero ya no califica para turnos que la exijan.',
    href: 'documentos.html?estatus=vencido',
    soloSi: datos => datos.documentos_vencidos > (datos.vencidos_obligatorios || 0) },

  { clave: 'solicitudes_sin_cubrir',   nivel: 'error',
    texto: n => `${n} ${n === 1 ? 'solicitud sin cubrir' : 'solicitudes sin cubrir'} hace más de 24 h`,
    detalle: 'Cada hora que pasa el cliente busca en otro lado.',
    href: 'solicitudes.html?estatus=en_busqueda' },

  { clave: 'propuestas_sin_respuesta', nivel: 'alerta',
    texto: n => `${n} ${n === 1 ? 'propuesta sin respuesta' : 'propuestas sin respuesta'}`,
    detalle: 'Llevan más de 12 horas esperando al profesional.',
    href: 'asignaciones.html?estatus=propuesta' },

  { clave: 'documentos_por_vencer',    nivel: 'alerta',
    texto: n => `${n} ${n === 1 ? 'documento vence' : 'documentos vencen'} en los próximos 30 días`,
    detalle: 'Conviene pedir la renovación antes de que caduquen.',
    href: 'documentos.html?por_vencer=1' },

  { clave: 'documentos_por_revisar',   nivel: 'info',
    texto: n => `${n} ${n === 1 ? 'documento esperando' : 'documentos esperando'} revisión`,
    detalle: 'Nadie se publica hasta que se aprueben.',
    href: 'documentos.html?estatus=pendiente' },

  { clave: 'verificaciones_pendientes', nivel: 'info',
    texto: n => `${n} ${n === 1 ? 'perfil pendiente' : 'perfiles pendientes'} de verificación`,
    detalle: 'Prometemos resolver en 24 a 48 horas.',
    href: 'enfermeros.html?estatus=pendiente' }
];

async function cargarAlertas() {
  const zona = document.getElementById('alertas');
  if (!zona) return;

  const { datos, error } = await consultar(db.rpc('alertas_dashboard'));
  if (error || !datos) return;

  const activas = ALERTAS.filter(a =>
    (datos[a.clave] ?? 0) > 0 && (!a.soloSi || a.soloSi(datos))
  );

  if (!activas.length) {
    zona.innerHTML = `
      <div class="alerta-panel alerta-ok">
        ${icono('check', 20)}
        <div><strong>Todo al día</strong>
        <span>No hay documentos vencidos, solicitudes sin cubrir ni verificaciones pendientes.</span></div>
      </div>`;
    return;
  }

  // Lo urgente primero
  const orden = { error: 0, alerta: 1, info: 2 };
  activas.sort((a, b) => orden[a.nivel] - orden[b.nivel]);

  zona.innerHTML = activas.map(a => {
    const n = datos[a.clave];
    return `
      <a href="${a.href}" class="alerta-panel alerta-${a.nivel}">
        ${icono(a.nivel === 'info' ? 'inbox' : 'alerta', 20)}
        <div>
          <strong>${esc(a.texto(n, datos))}</strong>
          <span>${esc(a.detalle)}</span>
        </div>
        ${icono('flechaDer', 18, 'alerta-flecha')}
      </a>`;
  }).join('');
}

/* ==========================================================================
   GRAFICA DE TURNOS POR SEMANA
   Canvas nativo, sin librerias (CLAUDE.md 8.6 y regla 4).
   ========================================================================== */

async function cargarGrafica() {
  const lienzo = document.getElementById('graficaTurnos');
  if (!lienzo) return;

  const { datos, error } = await consultar(db.rpc('turnos_por_semana', { p_semanas: 8 }));
  if (error || !datos?.length) {
    lienzo.closest('.tarjeta').innerHTML = estadoVacio({
      icono: 'maletin', titulo: 'Sin turnos registrados',
      texto: 'La gráfica aparece en cuanto se completen los primeros servicios.'
    });
    return;
  }

  // Resumen numerico junto al titulo
  const total = datos.reduce((s, d) => s + Number(d.completados), 0);
  const comision = datos.reduce((s, d) => s + Number(d.comision), 0);
  const resumen = document.getElementById('graficaResumen');
  if (resumen) {
    resumen.textContent = `${total} turnos completados · ${monedaCorta(comision)} de comisión`;
  }

  dibujarBarras(lienzo, datos);
  // Se redibuja al cambiar el tamano de la ventana
  window.addEventListener('resize', retardar(() => dibujarBarras(lienzo, datos), 200));
}

/**
 * Elige una escala con numeros redondos. Sin esto el eje muestra valores como
 * 3.75 o 11.25, que nadie usaria para leer una grafica.
 * @returns {{tope:number, paso:number}}
 */
function escalaLimpia(maximo, divisionesDeseadas = 4) {
  const crudo = maximo / divisionesDeseadas;
  const magnitud = Math.pow(10, Math.floor(Math.log10(crudo)));
  const normalizado = crudo / magnitud;

  // Pasos que la gente lee de un vistazo: 1, 2, 5 y sus multiplos de 10
  const paso = (normalizado <= 1 ? 1
              : normalizado <= 2 ? 2
              : normalizado <= 5 ? 5
              : 10) * magnitud;

  return { tope: Math.ceil(maximo / paso) * paso, paso };
}

/**
 * Dibuja las barras en el canvas, ajustando a la densidad de pixeles de la
 * pantalla para que no se vea borroso en retina.
 */
function dibujarBarras(lienzo, datos) {
  const contenedor = lienzo.parentElement;
  const ancho = contenedor.clientWidth;
  const alto = 240;
  const dpr = window.devicePixelRatio || 1;

  lienzo.width = ancho * dpr;
  lienzo.height = alto * dpr;
  lienzo.style.width = ancho + 'px';
  lienzo.style.height = alto + 'px';

  const ctx = lienzo.getContext('2d');
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, ancho, alto);

  const estilo = getComputedStyle(document.documentElement);
  const color = (nombre) => estilo.getPropertyValue(nombre).trim();

  const margen = { arriba: 16, derecha: 8, abajo: 34, izquierda: 38 };
  const anchoUtil = ancho - margen.izquierda - margen.derecha;
  const altoUtil  = alto - margen.arriba - margen.abajo;

  const maximo = Math.max(1, ...datos.map(d => Number(d.completados)));
  const { tope, paso: pasoEscala } = escalaLimpia(maximo);
  const lineas = tope / pasoEscala;

  ctx.font = '11px Inter, system-ui, sans-serif';
  ctx.textBaseline = 'middle';

  // Rejilla horizontal con su escala
  for (let i = 0; i <= lineas; i++) {
    const valor = pasoEscala * i;
    const y = margen.arriba + altoUtil - (altoUtil / lineas) * i;

    ctx.strokeStyle = color('--gris-200');
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(margen.izquierda, y + .5);
    ctx.lineTo(ancho - margen.derecha, y + .5);
    ctx.stroke();

    ctx.fillStyle = color('--gris-400');
    ctx.textAlign = 'right';
    ctx.fillText(valor, margen.izquierda - 8, y);
  }

  // Barras
  const columna = anchoUtil / datos.length;
  const anchoBarra = Math.min(46, columna * .62);

  datos.forEach((d, i) => {
    const valor = Number(d.completados);
    const altura = (valor / tope) * altoUtil;
    const x = margen.izquierda + columna * i + (columna - anchoBarra) / 2;
    const y = margen.arriba + altoUtil - altura;

    if (altura > 0) {
      const degradado = ctx.createLinearGradient(0, y, 0, margen.arriba + altoUtil);
      degradado.addColorStop(0, color('--azul-600'));
      degradado.addColorStop(1, color('--azul-400'));
      ctx.fillStyle = degradado;

      const radio = Math.min(6, anchoBarra / 2, altura);
      ctx.beginPath();
      ctx.roundRect(x, y, anchoBarra, altura, [radio, radio, 0, 0]);
      ctx.fill();

      ctx.fillStyle = color('--azul-900');
      ctx.textAlign = 'center';
      ctx.font = '600 11px Inter, system-ui, sans-serif';
      ctx.fillText(valor, x + anchoBarra / 2, y - 9);
    }

    // Etiqueta de la semana
    const fecha = aFecha(d.semana);
    ctx.fillStyle = color('--gris-600');
    ctx.textAlign = 'center';
    ctx.font = '11px Inter, system-ui, sans-serif';
    ctx.fillText(
      new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'short' }).format(fecha),
      x + anchoBarra / 2, alto - margen.abajo / 2 + 2
    );
  });
}

/* ==========================================================================
   ULTIMAS SOLICITUDES
   ========================================================================== */

async function cargarUltimasSolicitudes() {
  const zona = document.getElementById('tablaSolicitudes');
  if (!zona) return;

  const { datos, error } = await consultar(db.rpc('ultimas_solicitudes', { p_limite: 10 }));

  if (error) {
    zona.innerHTML = estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar las solicitudes', texto: error });
    return;
  }
  if (!datos.length) {
    zona.innerHTML = estadoVacio({
      icono: 'inbox', titulo: 'Todavía no hay solicitudes',
      texto: 'Cuando entre la primera por el sitio o por WhatsApp, aparecerá aquí.'
    });
    return;
  }

  zona.innerHTML = `
    <div class="tabla-contenedor">
      <table class="tabla">
        <thead>
          <tr>
            <th>Folio</th><th>Cliente</th><th>Servicio</th><th>Inicia</th>
            <th>Espera</th><th>Estatus</th><th></th>
          </tr>
        </thead>
        <tbody>
          ${datos.map(s => `
            <tr>
              <td>
                <strong>${esc(s.folio)}</strong>
                ${s.urgente ? '<span class="badge badge-error">Urgente</span>' : ''}
              </td>
              <td>${esc(s.cliente)}</td>
              <td>
                ${esc(etiqueta(TIPOS_SERVICIO, s.tipo_servicio))}
                <span class="texto-xs txt-tenue">
                  ${s.cantidad > 1 ? s.cantidad + ' personas · ' : ''}${esc(etiqueta(MUNICIPIOS, s.municipio))}
                </span>
              </td>
              <td>${esc(fechaCorta(s.fecha_inicio))}</td>
              <td class="${s.horas_esperando > 24 && ['nueva','en_busqueda'].includes(s.estatus) ? 'txt-error' : ''}">
                ${horasLegibles(s.horas_esperando)}
              </td>
              <td>${badge(ESTATUS_SOLICITUD, s.estatus)}</td>
              <td class="acciones">
                <a href="solicitudes.html?id=${encodeURIComponent(s.id)}"
                   class="btn btn-secundario btn-sm">Abrir</a>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

/** 2 -> "2 h", 38 -> "1 d 14 h" */
function horasLegibles(horas) {
  const h = Number(horas) || 0;
  if (h < 1) return 'recién';
  if (h < 24) return `${h} h`;
  const dias = Math.floor(h / 24);
  const resto = h % 24;
  return `${dias} d${resto ? ' ' + resto + ' h' : ''}`;
}

/* ==========================================================================
   ARRANQUE
   ========================================================================== */

// La revision de vencimientos vive en iniciarPanel() (js/panel.js): corre al
// entrar a cualquier pantalla de la agencia, no solo a esta.
function iniciarDashboard() {
  cargarKpis();
  cargarAlertas();
  cargarGrafica();
  cargarUltimasSolicitudes();
}
