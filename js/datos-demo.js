/* ==========================================================================
   Enlace Enfermero — Datos de demostracion
   Copia exacta de sql/05-seed.sql, exportada desde la base de datos.

   Se usa UNICAMENTE cuando  aun no tiene las credenciales de
   Supabase, para poder revisar el sitio publico antes de conectar la base.
   En cuanto se capturen las credenciales, todas las paginas leen de Supabase
   y este archivo deja de cargarse.

   AL PASAR A PRODUCCION: quitar la etiqueta <script> de este archivo en las
   paginas publicas y borrarlo.
   ========================================================================== */

const DATOS_DEMO = {

  enfermeros: [
    {
      "id": "94559b74-3f01-43f8-b72e-830e6d1ce1f7",
      "folio": "EE-00003",
      "nombre_completo": "Claudia Ivette Sandoval Ríos",
      "nivel": "especialista",
      "anios_experiencia": 11,
      "especialidades": [
        "neonatologia",
        "pediatria",
        "materno_infantil"
      ],
      "certificaciones": [
        "bls",
        "pals",
        "nrp"
      ],
      "idiomas": [
        "Español",
        "Inglés"
      ],
      "bio": "Especialista en neonatología con once años en cuneros y terapia intensiva neonatal. Certificada en reanimación neonatal. Acompaño a las familias en el cuidado del recién nacido con paciencia y comunicación clara.",
      "foto_url": null,
      "zonas_cobertura": [
        "zapopan",
        "guadalajara"
      ],
      "disponible_inmediato": false,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 5.0,
      "total_servicios": 71,
      "cedula_verificada": true
    },
    {
      "id": "9f9da79f-49be-43e4-bf28-8762d9eaefcf",
      "folio": "EE-00001",
      "nombre_completo": "María Fernanda Ruiz Delgado",
      "nivel": "especialista",
      "anios_experiencia": 12,
      "especialidades": [
        "uci",
        "urgencias"
      ],
      "certificaciones": [
        "bls",
        "acls",
        "via_aerea",
        "ventilacion"
      ],
      "idiomas": [
        "Español",
        "Inglés"
      ],
      "bio": "Especialista en cuidados intensivos con doce años en unidades de tercer nivel. Manejo de ventilación mecánica, monitoreo hemodinámico y atención de paciente crítico. Acostumbrada a trabajar bajo presión y a coordinarme con el equipo médico tratante.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "zapopan",
        "tlaquepaque"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.9,
      "total_servicios": 87,
      "cedula_verificada": true
    },
    {
      "id": "c741f37a-05b1-4960-955c-67e452aeb032",
      "folio": "EE-00008",
      "nombre_completo": "Verónica Alejandra Núñez Salas",
      "nivel": "licenciado",
      "anios_experiencia": 10,
      "especialidades": [
        "oncologia",
        "paliativos",
        "medicina_interna"
      ],
      "certificaciones": [
        "bls",
        "cateteres",
        "medicamentos_iv"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Licenciada en enfermería con diez años en el área oncológica. Manejo de catéteres centrales, administración de quimioterapia bajo indicación médica y control de efectos adversos. Trato cercano con el paciente y su familia.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "zapopan",
        "tlaquepaque"
      ],
      "disponible_inmediato": false,
      "acepta_domicilio": true,
      "acepta_nocturno": false,
      "calificacion_promedio": 4.9,
      "total_servicios": 66,
      "cedula_verificada": true
    },
    {
      "id": "5162378b-1bb1-4eb9-a416-f35d22a09117",
      "folio": "EE-00005",
      "nombre_completo": "Ana Lucía Gutiérrez Mora",
      "nivel": "licenciado",
      "anios_experiencia": 8,
      "especialidades": [
        "geriatria",
        "paliativos",
        "rehabilitacion"
      ],
      "certificaciones": [
        "bls",
        "medicamentos_iv",
        "muestras"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Licenciada en enfermería enfocada en el adulto mayor. Ocho años acompañando pacientes en casa: control de medicamentos, movilización, prevención de caídas y cuidados paliativos. Creo en el trato digno y en mantener informada a la familia.",
      "foto_url": null,
      "zonas_cobertura": [
        "zapopan",
        "guadalajara",
        "tlajomulco"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": false,
      "calificacion_promedio": 4.9,
      "total_servicios": 58,
      "cedula_verificada": true
    },
    {
      "id": "64309ed3-e11d-4a34-b138-8445749fad40",
      "folio": "EE-00012",
      "nombre_completo": "Rosa Elena Villalobos Chávez",
      "nivel": "cuidador",
      "anios_experiencia": 9,
      "especialidades": [
        "geriatria",
        "paliativos"
      ],
      "certificaciones": [
        "bls"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Cuidadora de adulto mayor con nueve años de experiencia en domicilio. Especializada en pacientes con demencia y movilidad reducida. Manejo rutinas de estimulación, aseo y compañía. Referencias comprobables.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "zapopan",
        "tlajomulco",
        "ixtlahuacan"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.9,
      "total_servicios": 52,
      "cedula_verificada": false
    },
    {
      "id": "1ef00750-340b-4c64-9798-a54d6a2cc190",
      "folio": "EE-00006",
      "nombre_completo": "Diana Patricia Ochoa Reynoso",
      "nivel": "especialista",
      "anios_experiencia": 14,
      "especialidades": [
        "quirofano",
        "postoperatorio"
      ],
      "certificaciones": [
        "bls",
        "acls",
        "via_aerea"
      ],
      "idiomas": [
        "Español",
        "Inglés"
      ],
      "bio": "Enfermera instrumentista con catorce años en quirófano. Experiencia en cirugía general, traumatología y laparoscopía. Conozco los protocolos de asepsia y el manejo de instrumental especializado.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "zapopan"
      ],
      "disponible_inmediato": false,
      "acepta_domicilio": false,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.8,
      "total_servicios": 93,
      "cedula_verificada": true
    },
    {
      "id": "43664a41-47b7-4274-ae91-22a863df520d",
      "folio": "EE-00002",
      "nombre_completo": "Jorge Alberto Medina Vargas",
      "nivel": "licenciado",
      "anios_experiencia": 9,
      "especialidades": [
        "urgencias",
        "cardiologia",
        "medicina_interna"
      ],
      "certificaciones": [
        "bls",
        "acls",
        "medicamentos_iv"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Licenciado en enfermería con nueve años en servicio de urgencias. Experiencia en triage, estabilización de paciente cardiológico y manejo de accesos vasculares. Disponible para turnos nocturnos y cobertura de fines de semana.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "tlaquepaque",
        "tonala"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.8,
      "total_servicios": 64,
      "cedula_verificada": true
    },
    {
      "id": "9850f506-87d0-453d-9653-aac87653233b",
      "folio": "EE-00010",
      "nombre_completo": "Gabriela Montserrat Estrada Lomelí",
      "nivel": "general",
      "anios_experiencia": 7,
      "especialidades": [
        "materno_infantil",
        "pediatria",
        "general"
      ],
      "certificaciones": [
        "bls",
        "pals",
        "muestras"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Enfermera general con siete años en atención materno-infantil. Apoyo en control prenatal, lactancia y cuidado del recién nacido en domicilio. Comunicación clara y paciente con las mamás primerizas.",
      "foto_url": null,
      "zonas_cobertura": [
        "zapopan",
        "tlajomulco",
        "guadalajara"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": false,
      "calificacion_promedio": 4.8,
      "total_servicios": 45,
      "cedula_verificada": true
    },
    {
      "id": "8469695f-97ec-4189-83a1-e5aa82d6a4d1",
      "folio": "EE-00009",
      "nombre_completo": "José Antonio Ramírez Padilla",
      "nivel": "especialista",
      "anios_experiencia": 13,
      "especialidades": [
        "nefrologia",
        "medicina_interna"
      ],
      "certificaciones": [
        "bls",
        "acls",
        "cateteres"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Especialista en nefrología con trece años en unidades de hemodiálisis. Manejo de accesos vasculares, control de balance hídrico y seguimiento del paciente renal crónico. Experiencia en hemodiálisis domiciliaria.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "tonala",
        "el_salto",
        "zapotlanejo"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.7,
      "total_servicios": 79,
      "cedula_verificada": true
    },
    {
      "id": "4bb43427-94ad-4e1d-8ac3-0ee41fd2d060",
      "folio": "EE-00004",
      "nombre_completo": "Ricardo Emmanuel Ponce Aguilar",
      "nivel": "general",
      "anios_experiencia": 6,
      "especialidades": [
        "medicina_interna",
        "heridas",
        "postoperatorio"
      ],
      "certificaciones": [
        "bls",
        "heridas_avanzadas",
        "cateteres"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Enfermero general con seis años de experiencia hospitalaria. Especializado en curación de heridas complejas, manejo de estomas y cuidado postoperatorio. Trabajo con protocolo y llevo registro puntual de la evolución del paciente.",
      "foto_url": null,
      "zonas_cobertura": [
        "guadalajara",
        "tlaquepaque",
        "el_salto"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": false,
      "calificacion_promedio": 4.7,
      "total_servicios": 42,
      "cedula_verificada": true
    },
    {
      "id": "58713dbb-e250-46b4-ac0e-68eb3cfea3bf",
      "folio": "EE-00007",
      "nombre_completo": "Luis Ángel Barajas Cortés",
      "nivel": "tecnico",
      "anios_experiencia": 4,
      "especialidades": [
        "general",
        "postoperatorio"
      ],
      "certificaciones": [
        "bls",
        "muestras"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Técnico en enfermería con cuatro años de experiencia en hospitalización y recuperación postquirúrgica. Apoyo en signos vitales, higiene, movilización y toma de muestras. Puntual y con buena disposición para aprender.",
      "foto_url": null,
      "zonas_cobertura": [
        "tlaquepaque",
        "tonala",
        "guadalajara"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.6,
      "total_servicios": 28,
      "cedula_verificada": false
    },
    {
      "id": "a1ae3308-3e84-4434-8b82-3fb8fbeb8ad2",
      "folio": "EE-00011",
      "nombre_completo": "Fernando Iván Cárdenas Sepúlveda",
      "nivel": "auxiliar",
      "anios_experiencia": 3,
      "especialidades": [
        "general",
        "geriatria"
      ],
      "certificaciones": [
        "bls"
      ],
      "idiomas": [
        "Español"
      ],
      "bio": "Auxiliar de enfermería con tres años de experiencia en asilos y cuidado domiciliario. Apoyo en higiene, alimentación asistida, movilización y acompañamiento. Responsable y con muy buena disposición.",
      "foto_url": null,
      "zonas_cobertura": [
        "tlaquepaque",
        "tonala",
        "el_salto",
        "juanacatlan"
      ],
      "disponible_inmediato": true,
      "acepta_domicilio": true,
      "acepta_nocturno": true,
      "calificacion_promedio": 4.5,
      "total_servicios": 19,
      "cedula_verificada": false
    }
  ],

  evaluaciones: [
    {
      "cliente": "Hospital San Rafael",
      "comentario": "Llegó puntual las tres noches y manejó al paciente en ventilación sin un solo contratiempo. El médico tratante quedó muy conforme. La volveremos a solicitar.",
      "enfermero_id": "9f9da79f-49be-43e4-bf28-8762d9eaefcf",
      "enfermero_nivel": "especialista",
      "enfermero_nombre": "María Fernanda Ruiz Delgado",
      "calificacion_general": 5
    },
    {
      "cliente": "Hospital San Rafael",
      "comentario": "Cuidó a mi mamá durante seis semanas. Además de su trabajo, nos explicaba todo con mucha paciencia. La familia entera quedó agradecida.",
      "enfermero_id": "5162378b-1bb1-4eb9-a416-f35d22a09117",
      "enfermero_nivel": "licenciado",
      "enfermero_nombre": "Ana Lucía Gutiérrez Mora",
      "calificacion_general": 5
    },
    {
      "cliente": "Hospital San Rafael",
      "comentario": "Instrumentista de primer nivel. Se integró al equipo de quirófano desde el primer día y conocía perfectamente los protocolos.",
      "enfermero_id": "1ef00750-340b-4c64-9798-a54d6a2cc190",
      "enfermero_nivel": "especialista",
      "enfermero_nombre": "Diana Patricia Ochoa Reynoso",
      "calificacion_general": 5
    }
  ],

  /* Disponibilidad de los proximos 14 dias, con el mismo patron del seed:
     se omite un dia de cada tres, distinto para cada perfil. */
  disponibilidad(enfermeroId, dias = 14) {
    const perfil = this.enfermeros.find(e => e.id === enfermeroId);
    if (!perfil) return [];

    const turnos = ['matutino', 'vespertino', 'nocturno'];
    const salida = [];
    const hoy = new Date();

    for (let i = 0; i < dias; i++) {
      const fecha = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() + i);
      if ((fecha.getDate() + perfil.nombre_completo.length) % 3 === 0) continue;

      for (const turno of turnos) {
        if (turno === 'nocturno' && !perfil.acepta_nocturno) continue;
        salida.push({ fecha, turno, disponible: true });
      }
    }
    return salida;
  }
};
