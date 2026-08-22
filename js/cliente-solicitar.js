/* ==========================================================================
   Enlace Enfermero — Nueva solicitud desde el panel del cliente

   El formulario es EL MISMO del sitio público: mismo markup, misma lógica de
   publico.js. Aquí sólo se precargan los datos de contacto que ya conocemos y
   se marca el origen, para no mantener dos formularios que se van a
   desincronizar al primer cambio de negocio.

   La solicitud queda ligada a su ficha sola: crear_solicitud() toma el
   cliente de auth.uid(), no del formulario.
   ========================================================================== */

async function iniciarSolicitudCliente(perfil) {
  // Marca el canal antes de arrancar: publico.js lo lee al enviar. Sin esto
  // toda solicitud quedaba como 'landing' y la agencia no podia distinguir
  // al cliente que ya tiene cuenta del prospecto que llega por primera vez.
  window.ORIGEN_SOLICITUD = 'panel_cliente';

  // Arranca el formulario público tal cual
  iniciarSolicitud();

  // El paso 4 pide datos de contacto que ya tenemos: se llenan y se explica
  // por qué están ahí, en vez de hacer que los reescriba.
  const { datos: cliente } = await consultar(
    db.from('clientes')
      .select('razon_social, nombre_contacto, telefono, email, tipo, municipio, direccion')
      .limit(1)
      .maybeSingle()
  );

  const poner = (id, valor) => {
    const campo = document.getElementById(id);
    if (campo && valor) campo.value = valor;
  };

  poner('sNombre',   cliente?.nombre_contacto || `${perfil.nombre} ${perfil.apellidos || ''}`.trim());
  poner('sTelefono', cliente?.telefono || perfil.telefono);
  poner('sEmail',    cliente?.email || perfil.email);
  poner('sMunicipio', cliente?.municipio);

  const tipo = document.getElementById('sTipoCliente');
  if (tipo && cliente?.tipo) tipo.value = cliente.tipo;

  avisarDatosPrecargados();
}

/** Nota en el paso de contacto: los datos vienen de su cuenta. */
function avisarDatosPrecargados() {
  const paso4 = document.querySelector('[data-paso="4"]');
  if (!paso4 || document.getElementById('avisoPrecarga')) return;

  const aviso = document.createElement('p');
  aviso.id = 'avisoPrecarga';
  aviso.className = 'nota-bloqueada';
  aviso.innerHTML = `${icono('check', 15)}
    Llenamos estos datos con los de tu cuenta. Cámbialos si el contacto de este
    servicio es otra persona.`;

  const titulo = paso4.querySelector('h2');
  if (titulo) titulo.insertAdjacentElement('afterend', aviso);
}
