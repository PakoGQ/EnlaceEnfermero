/* ==========================================================================
   Enlace Enfermero — Cartera de clientes (panel de la agencia)
   ========================================================================== */

const clientes = { filas: [], texto: '' };

const COLUMNAS_CLIENTE = [
  { titulo: 'Cliente', valor: c => `
      <strong>${esc(c.razon_social || c.nombre_contacto)}</strong>
      <span class="texto-xs txt-tenue">${esc(etiqueta(TIPOS_CLIENTE, c.tipo))}
        ${c.razon_social ? '· ' + esc(c.nombre_contacto) : ''}</span>`,
    crudo: c => c.razon_social || c.nombre_contacto },
  { titulo: 'Contacto', valor: c => `
      ${c.telefono ? `<a href="tel:${esc(c.telefono)}">${esc(telefonoLegible(c.telefono))}</a>` : ''}
      ${c.email ? `<span class="texto-xs txt-tenue">${esc(c.email)}</span>` : ''}`,
    crudo: c => `${c.telefono || ''} ${c.email || ''}`.trim() },
  { titulo: 'Zona', valor: c => esc(etiqueta(MUNICIPIOS, c.municipio) || '—'),
    crudo: c => c.municipio || '' },
  { titulo: 'Solicitudes', clase: 'num', valor: c => c.solicitudes, crudo: c => c.solicitudes },
  { titulo: 'Turnos', clase: 'num', valor: c => c.turnos, crudo: c => c.turnos },
  { titulo: 'Facturado', clase: 'num', valor: c => `<strong>${monedaCorta(c.facturado)}</strong>`,
    crudo: c => c.facturado },
  { titulo: 'Factura', valor: c => c.requiere_factura
      ? `<span class="badge badge-azul">CFDI</span>${c.rfc ? `<span class="texto-xs txt-tenue">${esc(c.rfc)}</span>` : '<span class="texto-xs txt-error">falta RFC</span>'}`
      : '<span class="txt-tenue">No</span>',
    crudo: c => c.requiere_factura ? (c.rfc || 'sin RFC') : 'no' },
  { titulo: '', clase: 'acciones', valor: c => `
      <a href="solicitudes.html" class="btn btn-fantasma btn-sm">Solicitudes</a>
      <button type="button" class="btn btn-secundario btn-sm" data-editar="${esc(c.id)}">Editar</button>`,
    crudo: () => '' }
];

async function cargarClientes() {
  const { datos, error } = await consultar(db.rpc('clientes_admin', { p_texto: clientes.texto || null }));

  if (error) {
    document.getElementById('tabla').innerHTML =
      estadoVacio({ icono: 'alerta', titulo: 'No pudimos cargar', texto: error });
    return;
  }

  clientes.filas = datos || [];
  pintarTabla('tabla', clientes.filas, COLUMNAS_CLIENTE, {
    icono: 'hospital',
    titulo: 'Sin clientes todavía',
    texto: 'Los clientes se crean al registrarse o cuando los das de alta aquí.'
  });

  document.getElementById('resumen').innerHTML = `
    <span>${clientes.filas.length} clientes</span>
    <span>${clientes.filas.filter(c => c.tiene_cuenta).length} con cuenta</span>
    <span>Facturado <strong>${monedaCorta(clientes.filas.reduce((s, c) => s + Number(c.facturado), 0))}</strong></span>`;

  document.querySelectorAll('[data-editar]').forEach(b =>
    b.addEventListener('click', () => editarCliente(b.dataset.editar)));
}

function camposCliente() {
  return [
    { nombre: 'tipo', etiqueta: 'Tipo de cliente', tipo: 'select', requerido: true, opciones: TIPOS_CLIENTE },
    { nombre: 'razon_social', etiqueta: 'Razón social',
      nota: 'Para instituciones. Los particulares pueden dejarlo vacío.' },
    { nombre: 'nombre_contacto', etiqueta: 'Nombre de contacto', requerido: true },
    { nombre: 'telefono', etiqueta: 'Teléfono', tipo: 'tel' },
    { nombre: 'email', etiqueta: 'Correo', tipo: 'email' },
    { nombre: 'municipio', etiqueta: 'Municipio', tipo: 'select', opciones: MUNICIPIOS },
    { nombre: 'direccion', etiqueta: 'Dirección' },
    { nombre: 'colonia', etiqueta: 'Colonia' },
    { nombre: 'cp', etiqueta: 'Código postal' },
    { nombre: 'requiere_factura', etiqueta: 'Requiere factura (CFDI 4.0)', tipo: 'checkbox' },
    { nombre: 'rfc', etiqueta: 'RFC', nota: 'Necesario si pide factura.' },
    { nombre: 'notas', etiqueta: 'Notas internas', tipo: 'textarea' }
  ];
}

function nuevoCliente() {
  abrirFormulario({
    titulo: 'Dar de alta cliente',
    textoGuardar: 'Crear',
    campos: camposCliente(),
    alGuardar: guardarCliente
  });
}

function editarCliente(id) {
  const c = clientes.filas.find(x => x.id === id);
  abrirFormulario({
    titulo: `Editar — ${c.razon_social || c.nombre_contacto}`,
    campos: camposCliente(),
    valores: { ...c },
    alGuardar: (d) => guardarCliente({ ...d, id })
  });
}

async function guardarCliente(d) {
  if (!d.nombre_contacto?.trim()) { toast('El nombre de contacto es obligatorio.', 'error'); return false; }
  if (d.requiere_factura && !d.rfc?.trim()) {
    toast('Si requiere factura hace falta el RFC.', 'error'); return false;
  }
  if (d.rfc && !validar.rfc(d.rfc)) { toast('Revisa el RFC, no tiene el formato correcto.', 'error'); return false; }
  if (d.email && !validar.email(d.email)) { toast('Revisa el correo.', 'error'); return false; }

  if (d.telefono) d.telefono = normalizarTelefono(d.telefono);

  const { error } = await consultar(db.rpc('guardar_cliente', { p_datos: d }));
  if (error) { toast(error, 'error'); return false; }

  toast(d.id ? 'Cliente actualizado.' : 'Cliente creado.', 'exito', 2500);
  cargarClientes();
}

function iniciarClientes() {
  document.getElementById('buscar').addEventListener('input', retardar(() => {
    clientes.texto = document.getElementById('buscar').value.trim();
    cargarClientes();
  }, 350));

  document.getElementById('btnNuevo').addEventListener('click', nuevoCliente);
  document.getElementById('btnExportar').addEventListener('click', () =>
    exportarCSV('clientes', clientes.filas, COLUMNAS_CLIENTE.filter(c => c.titulo)));

  cargarClientes();
}
