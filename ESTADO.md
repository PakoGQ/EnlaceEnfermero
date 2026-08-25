# Estado del proyecto — Enlace Enfermero

> Documento de continuidad. Léelo junto con `CLAUDE.md`, que es la especificación
> maestra. Aquí está **qué se construyó, cómo funciona y qué falta**.
>
> Última actualización: 24 de agosto de 2026

---

## ⇢ EMPIEZA AQUÍ: lo que sigue

**La tarea abierta es de diseño, no de funcionalidad.** El código funciona
completo; lo que Paco quiere es que el sitio se vea distinto.

### El encargo, en sus palabras

> «Se me hizo muy soft el cambio, yo me esperaba ver más animaciones, colores,
> todas las páginas más vivas. Se ve prácticamente igual.»
>
> Y después, ya con la segunda pasada aplicada:
>
> «Lo sigo viendo casi igual, quiero que tenga más el aspecto de los paneles.»

**Lo primero que hay que aclararle:** «el aspecto de los paneles» admite dos
lecturas y cambia por completo el trabajo.

1. Que **el sitio público** (11 pantallas) se parezca a **los tres paneles
   privados**, que sí recibieron el tratamiento fuerte —degradados, indicadores
   de colores, línea de tendencia, anillo de progreso—. Esta es la lectura más
   probable: los paneles se transformaron mucho más que el público.
2. Que **todo** se parezca a las maquetas del lienzo de diseño.

Pregúntaselo en una línea antes de empezar. No lo asumas.

### Por qué sigue viéndose parecido: el diagnóstico honesto

Se hicieron dos pasadas y las dos cambiaron **superficies**: color, sombra,
radio, degradado, movimiento. Ninguna tocó la **estructura**.

Todas las pantallas siguen siendo el mismo esqueleto:

```
encabezado  →  rejilla de tarjetas  →  lista  →  lista
```

Mientras ese esqueleto no cambie, cualquier ajuste de color se va a sentir
tibio, porque el ojo reconoce la composición antes que la paleta. **Si el
objetivo es que se sienta otro producto, hay que rediseñar la composición**, no
subirle el volumen a los tokens:

- Layouts asimétricos en vez de rejillas de dos columnas iguales.
- Piezas que se traslapen y rompan la retícula.
- Una pieza dominante por pantalla, mucho más grande que el resto.
- Secciones que no empiecen todas con un título del mismo tamaño.

Eso es trabajo **pantalla por pantalla**, no de tokens, y conviene decírselo
antes de empezar para que sepa lo que está pidiendo.

### Lo que ya está agotado

No vuelvas a proponer esto, ya se hizo y no resolvió la queja:

- Subir saturación y meter degradados a las superficies.
- Sombras con tinte y radios más grandes.
- Animaciones de entrada, latidos, brillos y elevación al pasar el cursor.

---

## Resumen en una línea

**Fases 0 a 3 completas.** Los tres paneles funcionan y el ciclo de negocio
corre de punta a punta: el cliente solicita → la agencia cotiza y propone → el
profesional acepta → cubre el turno y marca entrada y salida → el cliente evalúa
→ se factura. Las 35 pantallas existen y están verificadas.

**Nada de esto está bloqueado por código.** Lo abierto es (a) el rediseño visual
de arriba, (b) hospedar la base cuando Paco lo decida, y (c) la Fase 4, que por
especificación no se toca hasta tener clientes reales.

| Fase | Alcance | Estado |
|---|---|---|
| 0 | Cimientos: estructura, tokens, SQL base | **Completada** |
| 1 | Sitio público: catálogo, perfiles, formularios | **Completada** |
| 2 | Autenticación y panel de la agencia | **Completada** |
| 3 | Paneles de enfermero y cliente | **Completada** |
| 4 | Automatización, WhatsApp y agente IA | No iniciada |

---

## Cómo levantar el entorno

Tres comandos, en este orden:

```bash
colima start
```
```bash
supabase start
```
```bash
python3 servidor.py
```

Sitio en `http://localhost:8000`. Studio de la base en `http://127.0.0.1:54323`.
Correos de prueba en `http://127.0.0.1:54324`.

Para detener: `supabase stop` y `colima stop`.

### Cuentas de prueba (contraseña `prueba1234`)

| Correo | Rol | Entra a |
|---|---|---|
| `admin@enlace.test` | admin | `/admin` (11 pantallas) |
| `coordinador@enlace.test` | coordinador | `/admin` sin Pagos, Reportes ni Configuración |
| `enfermero@enlace.test` | enfermero | `/panel` (ligado al perfil EE-00001) |
| `cliente@enlace.test` | cliente | `/cliente` |

En `login.html` aparece un recuadro ámbar con las cuatro cuentas; un clic las
llena. Solo se muestra en `localhost`.

### Scripts de mantenimiento

| Script | Para qué |
|---|---|
| `bash aplicar-esquema.sh` | Borra y reconstruye la base local desde `sql/`, y actualiza la llave en `js/config.js` |
| `bash crear-usuarios-prueba.sh` | Recrea las cuatro cuentas (hay que correrlo después de cada `aplicar-esquema.sh`) |
| `bash subir-documentos-prueba.sh` | Sube los PDF de prueba al bucket privado para que el visor funcione |
| `bash sql/generar-instalador.sh` | Regenera `sql/00-instalar.sql` tras tocar cualquier script |
| `sql/98-usuarios-prueba.sql` | Prepara las 4 cuentas en un proyecto **hospedado** (los scripts `.sh` solo hablan con el Supabase local) |

> Los datos del seed usan fechas relativas al momento de instalación. Si tras unos
> días el panel muestra números raros ("0 solicitudes hoy"), corre
> `aplicar-esquema.sh` y vuelven a ser frescas.

---

## Identidad visual — dirección «Pulso»

Elegida el 23 de agosto de 2026 tras comparar tres propuestas en un lienzo de
diseño. Sustituye al planteamiento original, que resultó plano: todo pesaba
igual, así que nada resaltaba y cada pantalla se leía como una lista.

Las cuatro reglas están en `CLAUDE.md` §3 y los tokens en `css/variables.css`.
En corto:

1. **Jerarquía por color**, no por tamaño. Naranja urge, verde es dinero, cyan
   informa, blanco es el resto.
2. **Profundidad real**: degradados en las piezas protagonistas, sombras con
   tinte de color, y superficies que se encabalgan.
3. **Una sola pieza protagonista por pantalla** — la única con degradado.
4. **La pantalla entra**: bloques escalonados al cargar, y lo que está vivo
   late. Todo respeta `prefers-reduced-motion`.

**Estado del despliegue: completo.** Las **35 pantallas** llevan la dirección.

- **Los tres paneles (24):** encabezado con degradado y encabalgamiento,
  indicadores por tono, alertas con riel de color y la tarjeta de turno como
  pieza protagonista.
- **El sitio público (11):** hero con el degradado de marca y manchas radiales,
  barra de confianza encabalgada, tarjeta de enfermero con anillo degradado y
  lavado de esquina, iconos de servicio con un tono cada uno, y la sección de
  verificación —el argumento de venta más fuerte— con profundidad.

Como el tratamiento vive en los tokens y en el chrome compartido, una pantalla
nueva nace ya con el estilo: no hay que aplicarlo a mano.

---

### Qué se hizo en cada pasada, con precisión

Para no repetir trabajo ni volver a proponer lo ya hecho.

**Pasada 1 — el sistema y los tres paneles** (commit `73762a3`)

- `CLAUDE.md` §3 reescrito primero, antes del código.
- `css/variables.css`: sombras con tinte, degradados de marca, radios 20 y 24,
  `--fondo-panel`, curvas `--trans-suave` y `--entrada`.
- `css/componentes.css`: utilidades de movimiento (`.entra`, `.punto-vivo`,
  `.brillo`, `.eleva`) con su bloque `prefers-reduced-motion`.
- `css/panel.css`: encabezado con degradado y encabalgamiento de 40px,
  indicadores por tono, alertas con riel degradado, turno propuesto como pieza
  protagonista.

**Pasada 2 — el sitio público** (commit `e7abf16`)

- `.tarjeta` pierde el borde gris de 1px y sube a radio 20.
- `.tarjeta-enfermero`: radio 24, anillo degradado en la foto, lavado de
  esquina. *(Primer intento fallido: una franja recta arriba, que el radio de
  24px corta en diagonal y deja como repisa.)*
- `css/publico.css`: hero al token de marca con manchas radiales, barra de
  confianza a radio 24 con sombra azul, un tono por icono de servicio, sección
  de verificación con profundidad, FAQ sin la línea gris.
- `css/base.css`: `.aparece` a la curva de Pulso y `.aparece-serie` para
  escalonar rejillas.

**Pasada 3 — subir el volumen** (commit `5a8c0b5`)

Motivada por «se me hizo muy soft». La causa real: en la pasada 1 escribí el CSS
de `.brillo` y `.punto-vivo` y **nunca los conecté**, y dejé fuera el sparkline
y el anillo que sí estaban en la maqueta aprobada.

- `panel_enfermero_resumen()` devuelve `serie_ganancias` (últimos 6 meses).
- `js/panel-enfermero.js`: los indicadores se arman a mano, no desde una tabla
  de configuración, porque cada uno tiene su pieza gráfica. Funciones
  `chispita()` (línea de tendencia SVG) y `anillo()` (progreso).
- Sello «Urge» y barrido de brillo en el indicador de propuestas.
- El badge de «visible en el catálogo» late, y sólo si está publicado.
- `css/publico.css`: manchas del hero que respiran, sello que late, métricas con
  número en degradado, servicios que encienden color, chips que crecen.
- `CLAUDE.md` §3.4 gana el cuarto uso del movimiento —el dato que se dibuja— y
  la regla de contención: **el movimiento se gana**.

### El lienzo con las tres direcciones

https://claude.ai/code/artifact/7e296b49-732e-4f83-8bf7-427c7981169c

Cuatro artboards de la misma pantalla (Inicio del enfermero, ancho de celular):
la actual como referencia, más **A · Pulso** (la elegida), **B · Turno
Nocturno** (tema oscuro) y **C · Cuidado** (editorial cálido). Cada uno con su
nota de argumentos y contras.

Los archivos fuente viven en `diseno/` (`Main.dc.html`, `Pulso.dc.html`,
`Nocturno.dc.html`, `Cuidado.dc.html`, `canvas.json`). **Si hay que rehacer o
ampliar el lienzo, se edita ahí y se vuelve a sembrar** — nunca se edita el
`.html` ya generado.

Vale la pena releer la maqueta de Pulso antes de seguir: sigue habiendo cosas
en ella que no llegaron al código, como la tarjeta de turno con los botones
Aceptar / cerrar en el pie y los chips en vidrio.

---

## Dónde está publicado

**https://pakogq.github.io/EnlaceEnfermero/** — GitHub Pages, rama `main`, raíz.
El despliegue es automático con cada push.

`js/config.js` detecta el entorno solo con `ES_LOCAL`: en `localhost` apunta al
Supabase de Docker y en cualquier otro dominio a las credenciales de producción.
Por eso subir el repositorio nunca publica la configuración local.

**Hasta que se capturen las credenciales de un proyecto hospedado, en línea sólo
funciona el sitio público**, y con los datos de `datos-demo.js`. El login y los
tres paneles necesitan una base real: ver `docs/conectar-supabase.md`.

---

## Decisiones de negocio ya tomadas

Están registradas en `CLAUDE.md` §15. Resumen:

1. **El enfermero es freelance** — prestador de servicios profesionales
   independiente. No hay relación laboral, IMSS ni prestaciones.
2. **Reparto 60/40** — el cliente paga a la agencia; la agencia paga al
   profesional el 60% y retiene el 40%. Implementado en la base con
   `pago_enfermero()` / `cobro_cliente()` y un trigger que lo aplica solo.
3. **Dos caminos de solicitud** — el cliente puede elegir uno o varios perfiles
   del catálogo, o describir su necesidad para que la agencia le proponga.
   El contrato es siempre con la agencia.
4. **Sin cuota de inscripción** al personal.
5. **Sin tabulador de precios.** Cada servicio se cotiza según tipo de paciente,
   entorno, nivel de atención, procedimientos, turno, zona y cantidad. Por eso
   el formulario captura esas variables estructuradas.

### Pendientes de decidir

1. **¿Cuándo cobra la agencia al cliente?** Anticipo, contra entrega o corte.
   Hace falta para cerrar el módulo de pagos.
2. **Comprobación fiscal del pago al freelance** — factura del profesional o
   retención. Consultar con contador.
3. **Dominio y correo corporativo.**
4. **Datos legales de la agencia** (razón social, domicilio fiscal, RFC) para
   completar el aviso de privacidad y los términos.
5. **¿El coordinador debe ver los pagos?** Hoy no los ve (decisión conservadora,
   no especificada en `CLAUDE.md`). A nivel de base `es_staff()` sí lo incluye:
   si se quiere bloquear del todo, hay que ajustar RLS.

---

## Arquitectura

Sin frameworks ni build step. HTML + CSS + JS vanilla, y Supabase por CDN.

### Archivos JavaScript

| Archivo | Responsabilidad |
|---|---|
| `config.js` | Credenciales y catálogos. Distingue local de producción con `ES_LOCAL` |
| `supabase.js` | Cliente, traducción de errores y `diagnostico()` |
| `utils.js` | Formato MXN y fechas, validaciones mexicanas, toasts, `repartir()` |
| `componentes.js` | Header, footer, iconos SVG, tarjeta de enfermero |
| `publico.js` | Catálogo, perfil, formularios multipaso, selección múltiple |
| `datos-demo.js` | Respaldo sin Supabase. **Borrar antes de producción** |
| `auth.js` | Login, registro, recuperación, guardia de rutas por rol |
| `panel.js` | Estructura compartida de los tres paneles |
| `admin-comun.js` | Tablas, filtros, modales de formulario, exportación CSV |
| `panel-admin.js` | Dashboard de la agencia: KPIs, alertas, gráfica Canvas |
| `panel-enfermero.js` | Inicio del profesional: KPIs, alertas, turnos, avance de perfil |
| `enfermero-comun.js` | Tarjeta de turno y sus acciones, compartidas por tres pantallas |
| `enfermero-turnos.js` | Mis turnos: aceptar, rechazar, entrada y salida |
| `enfermero-disponibilidad.js` | Calendario mensual y plantilla semanal |
| `enfermero-documentos.js` | Expediente: subir y renovar, con URL firmada |
| `enfermero-perfil.js` | Edición del perfil profesional |
| `enfermero-historial.js` | Turnos cerrados y hoja de servicio |
| `enfermero-ganancias.js` | Ingresos por quincena |
| `cliente-comun.js` | Ficha de profesional sin datos de contacto, selector de estrellas |
| `cliente-inicio.js` | Resumen, alertas y próximos turnos del cliente |
| `cliente-solicitudes.js` | Seguimiento con línea de tiempo |
| `cliente-personal.js` | Quién ha trabajado con él y "solicitar de nuevo" |
| `cliente-evaluar.js` | Evaluación de 3 criterios |
| `cliente-facturacion.js` | Cobros por periodo |
| `cliente-solicitar.js` | Precarga del formulario público dentro del panel |
| `admin-solicitudes.js` | Tablero kanban y motor de match |
| `admin-documentos.js` | Bandeja de verificación y visor |
| `admin-asignaciones.js` | Seguimiento de turnos y asistencia |
| `admin-enfermeros.js` | Cartera de personal |
| `admin-clientes.js` | Cartera de clientes |
| `admin-calendario.js` | Vista mensual |
| `admin-pagos.js` | Cortes y registro de pagos |
| `admin-reportes.js` | Métricas y ranking |
| `admin-referidos.js` | Programa de referidos |
| `admin-configuracion.js` | Reparto, datos, tarifas de referencia |

### Base de datos

Los scripts se ejecutan en orden. `sql/00-instalar.sql` los une todos envueltos
en una transacción: si algo falla, no se aplica nada.

| Script | Contenido |
|---|---|
| `01-schema.sql` | 15 tablas, tipos enumerados, índices |
| `02-rls.sql` | Políticas, GRANT explícitos, buckets de Storage |
| `03-funciones.sql` | Folios, reparto, traslapes, bitácora, triggers de protección |
| `04-vistas.sql` | `enfermeros_publico` y vistas de reportes |
| `05-seed.sql` | 12 perfiles ficticios y operación de ejemplo |
| `06-dashboard.sql` | KPIs, alertas, series |
| `07-solicitudes.sql` | Tablero, detalle y **motor de sugerencia** |
| `08-documentos.sql` | Verificación documental |
| `09-operacion.sql` | Asignaciones, calendario, enfermeros, clientes |
| `10-finanzas.sql` | Pagos, reportes, referidos, configuración |
| `11-paneles.sql` | Paneles del enfermero y del cliente: todo lo que consumen sus pantallas |
| `99-pruebas.sql` | **62 verificaciones.** Hace rollback, no deja datos |

---

## Conceptos que cuestan trabajo y conviene entender antes de tocar

### 1. RLS y GRANT son capas distintas

RLS decide **qué filas** ve un rol; GRANT decide si puede **tocar la tabla**.
Sin GRANT, PostgREST responde `permission denied` antes de evaluar las policies.

Esto ya costó un bug grave: las políticas estaban bien pero faltaban los
permisos, y **ningún formulario público funcionaba**. Las pruebas lo tapaban
porque otorgaban permisos a mano antes de correr.

### 2. `es_staff()` contra `es_staff_estricto()`

- **`es_staff()`** — para usar en *policies*. Reconoce como internos a los roles
  que no son `anon` ni `authenticated`, porque ahí `current_user` sí es el rol
  real del llamante.
- **`es_staff_estricto()`** — para usar **dentro de funciones `SECURITY DEFINER`**.
  Ahí `current_user` es el propietario, así que `es_staff()` daría por bueno a
  cualquier usuario con sesión.

Confundirlas ya causó que un enfermero pudiera ver los ingresos de la agencia.
**Toda función nueva `SECURITY DEFINER` debe usar la estricta.**

### 3. Las altas públicas van por función, no por INSERT

`crear_solicitud()` y `registrar_enfermero()` reciben los formularios públicos.
Devuelven el folio sin que el sitio necesite permiso de **leer** esas tablas, e
ignoran los campos reservados al admin aunque vengan en el JSON.

### 4. Cambiar el tipo de retorno de una función

`CREATE OR REPLACE` no lo permite. Por eso `06` a `10` empiezan con
`DROP FUNCTION IF EXISTS`.

### 5. En los paneles privados el filtro va al revés

En `06` a `10` cada función pregunta *«¿quien llama **es** de la agencia?»* con
`es_staff_estricto()`. En `11-paneles.sql` la pregunta es la contraria:
*«¿quien llama tiene ficha propia?»*, vía `mi_enfermero_id()`.

Dos consecuencias que no son obvias:

- Un **admin recibe error** al llamar `panel_enfermero_resumen()`. No es un bug:
  para ver a un profesional tiene sus propias funciones en `09-operacion.sql`.
- Ninguna función del panel **recibe un id como parámetro**. Si lo recibiera, se
  le podría pasar el de otro. El único ayudante que sí lo recibe,
  `perfil_completo_pct()`, no es `security definer` y **no tiene permiso de
  ejecución**: solo lo llaman las funciones de arriba.

### 6. Dos policies que se miran entre sí recursan

La de `solicitudes` consultaba `asignaciones` y la de `asignaciones` consultaba
`solicitudes`. Cada subconsulta disparaba el RLS de la otra tabla, que disparaba
el de la primera, y Postgres cortaba con
`infinite recursion detected in policy`.

**El efecto era que ni el enfermero ni el cliente podían leer ninguna de las dos
tablas.** No se había notado porque el staff se salva: su policy evalúa
`es_staff()` y corta antes, y el sitio público no lee esas tablas.

Se rompió sacando el cruce a funciones `security definer`
(`tengo_asignacion_en()` y `solicitud_es_de_mi_cliente()`): adentro corren como
propietario, el RLS de la otra tabla no se evalúa y el ciclo se cierra. Siguen
filtrando por `auth.uid()`, así que no aflojan nada.

**Regla para lo que viene:** cualquier policy nueva que consulte otra tabla con
RLS tiene que hacerlo por función `security definer`, no con un `exists` directo.

### 7. Hay TRES capas de permisos, no dos

RLS filtra **filas**, GRANT abre la **tabla**, y varias reglas del negocio son
de **columna**. Ninguna de las dos primeras puede expresarlas.

La policy que le deja a un enfermero ver sus asignaciones le entregaba la fila
completa, incluida `comision_agencia`: sabía exactamente cuánto se queda la
agencia en cada turno. Al cliente le pasaba lo mismo al revés, con
`tarifa_enfermero`. Los dos son el argumento perfecto para saltarse a la agencia
y contratarse directo, que es justo lo que el modelo no puede permitir.

Se cerró en `02-rls.sql` con permisos por columna. **Ojo con el orden:** un
`revoke select (columna)` no hace nada si el rol conserva el `select` de la
tabla completa; Postgres entiende que el permiso de tabla ya cubre todo. Hay que
quitar primero el de tabla y después otorgar la lista de columnas permitidas.

Lo que se cierra es la puerta de atrás —abrir la consola y consultar la tabla—,
no las pantallas: todas leen por funciones `security definer`, que corren como
propietario y no pasan por esta capa.

### 8. El vencimiento no es un evento

Un documento caduca por el paso del tiempo, no porque alguien haga algo, así que
ningún trigger se entera. Si la regla 10.3 dependiera de un proceso programado,
entre que la cédula caduca y que ese proceso corre el perfil se seguiría
ofreciendo como verificado.

Por eso el catálogo lo evalúa **al momento de consultar**:
`tiene_obligatorio_vencido()` se llama desde la vista `enfermeros_publico` y
desde `enfermero_es_publico()`. La regla se cumple sola.

`marcar_documentos_vencidos()` es otra cosa: pone al corriente el **estado
guardado** (`documentos.estatus` y la bandera `publicado`), que es lo que la
agencia lee en su panel. Corre al entrar a cualquier pantalla de la agencia,
desde `iniciarPanel()` en `js/panel.js` — ahí y no en cada pantalla, porque si
no basta que una lo olvide para que muestre datos rancios.

**Solo los documentos obligatorios despublican.** Un BLS caducado no saca a
nadie del catálogo; nada más le cierra la puerta a los turnos que lo exijan.

### 9. El cliente nunca toca la tabla `enfermeros`

Su RLS no le abre ni una fila, y es a propósito. Todo lo que el cliente ve de un
profesional —nombre, folio, nivel, foto, calificación, experiencia y
especialidades— sale de las funciones de `11-paneles.sql`, que seleccionan esas
columnas y ninguna más.

No es una precaución abstracta: si el cliente obtiene el teléfono del
profesional, lo contrata directo y la agencia se queda sin comisión
(`CLAUDE.md` §6 y regla 10.8). Por eso también el detalle de una solicitud sólo
muestra al personal que **ya aceptó**: mientras es una propuesta, el profesional
todavía puede rechazarla y el cliente no tendría por qué haber sabido su nombre.

`99-pruebas.sql` comprueba las dos cosas: que el detalle no traiga contacto ni
tarifas, y que la tabla siga cerrada.

### 10. El motor de match

`sugerir_enfermeros(solicitud_id)` cruza nivel (jerárquico: un especialista
cubre un puesto de auxiliar, no al revés), zona, disponibilidad en la fecha,
especialidades y **procedimientos contra certificaciones**
(`certificacion_requerida()` mapea cuál respalda cuál). Devuelve puntuación,
motivos en texto y el máximo alcanzable, para que el porcentaje de encaje sea
absoluto y no relativo al mejor de la lista.

---

## Reglas de negocio que la base hace cumplir

No dependen de la interfaz. Verificadas en `99-pruebas.sql`:

- Un enfermero **no puede autoverificarse**, publicarse, fijarse tarifa ni
  escribir notas internas.
- **No se puede verificar** a alguien con documentos obligatorios sin aprobar.
  Los obligatorios cambian según el nivel (regla 10.2).
- **No se puede rechazar un documento sin motivo**, ni aprobar uno vencido.
- Rechazar un documento obligatorio **despublica el perfil** automáticamente.
- **No hay turnos encimados**, incluidos los nocturnos que cruzan medianoche.
- La **comisión nunca es negativa**.
- El cliente **no fija su propia tarifa** al solicitar.
- **No se puede confirmar** una solicitud sin personal que haya aceptado.
- **No se puede proponer** sin haber cotizado.
- El **catálogo público no expone** cédula completa, teléfono, tarifas ni notas
  internas: sale de una vista, no de la tabla.
- El **reparto tiene que sumar 100%**.

---

## Estado por pantalla

### Público (Fase 1) — completo
`index.html` `enfermeros.html` `perfil.html` `solicitar.html` `unete.html`
`servicios.html` `nosotros.html` `contacto.html` `aviso-privacidad.html`
`terminos.html` `404.html`

### Acceso (Fase 2) — completo
`login.html` `registro.html` `recuperar.html`

### Panel de la agencia (Fase 2) — completo
`index.html` (dashboard) `solicitudes.html` (kanban + match) `documentos.html`
(verificación) `asignaciones.html` `calendario.html` `enfermeros.html`
`clientes.html` `pagos.html`\* `reportes.html`\* `referidos.html`
`configuracion.html`\*

\* Solo rol admin.

### Panel del enfermero (Fase 3) — **completo**
Las 7 pantallas funcionan: `index.html` (inicio) `asignaciones.html` (mis turnos)
`disponibilidad.html` `documentos.html` `perfil.html` `historial.html`
`ganancias.html`. Todas contra `sql/11-paneles.sql`.

### Panel del cliente (Fase 3) — **completo**
Las 6 pantallas funcionan: `index.html` `solicitar.html` `solicitudes.html`
`personal.html` `evaluar.html` `facturacion.html`.

`solicitar.html` **reutiliza el formulario del sitio público**, no una copia:
mismo markup, misma lógica de `publico.js`, sólo con los datos de contacto
precargados. Así no hay dos formularios que se desincronicen al primer cambio
de negocio.

---

## Qué falta hacer

### 1. Rediseño visual — la tarea viva

Está descrita al principio del documento. Es lo único en lo que Paco quiere
trabajar ahora mismo.

### 2. Hospedar la base — cuando él lo diga

**No proponerlo hasta que el diseño esté cerrado.** Decisión suya del 23 de
agosto: primero prueba y ajusta apariencia en local, y hasta que la mayoría esté
lista se contrata Supabase Pro, para no pagar durante semanas de iteración.

Su cuenta ya tiene **2 proyectos gratuitos activos (Vaxti y Doncellas), que
necesita como están**, y ese es el límite. Crear uno nuevo exige pausar alguno o
subir a Pro.

Cuando llegue el momento, el camino está probado: `sql/00-instalar.sql`, las 4
cuentas a mano en Authentication, y `sql/98-usuarios-prueba.sql`. Ver
`docs/conectar-supabase.md`.

### 3. Una decisión de producto pendiente

**¿El registro por `unete.html` debe crear cuenta siempre?** Hoy 12 de los 13
perfiles del catálogo no tienen cuenta, así que no pueden entrar a `/panel`. El
panel del enfermero sólo rinde si la gente lo usa. Alternativa: invitar por
correo después de verificar.

### Fase 4 — Automatización e IA

No iniciar hasta que las fases 1-3 estén validadas en producción con clientes
reales (`CLAUDE.md` §9). Lo que toca: escenarios de Make.com, WhatsApp Business
API, programa de referidos con deep links y el agente conversacional.

Dos cosas que la Fase 3 dejó listas para engancharse ahí:
- `alertar_documentos_por_vencer()` ya existe y nadie la consume todavía.
- Nada despublica un perfil cuando un documento caduca solo (ver cabos sueltos).

### Antes de salir a producción

1. **Contratar Supabase Pro** (~$25 USD/mes). El plan gratuito **se pausa tras
   7 días de inactividad** y no tiene backups: no sirve para operar.
   Sugerencia: subir a Pro la organización **Buscadoc**, que está vacía, y dejar
   Vaxti y Doncellas en sus organizaciones gratuitas.
2. **Instalar**: pegar `sql/00-instalar.sql` completo en el SQL Editor, luego
   `sql/99-pruebas.sql` para verificar. Omitir `05-seed.sql` si no se quieren
   los 12 perfiles ficticios.
3. **Capturar credenciales** en `js/config.js`, en la rama de producción.
   Solo la llave `anon public`; **nunca** la `service_role`.
4. **Autorizar URLs** en Authentication → URL Configuration.
5. **Borrar `js/datos-demo.js`** y quitar su `<script>` de las páginas públicas.
6. **Completar los textos legales** — los marcadores amarillos de
   `aviso-privacidad.html` y `terminos.html`, y revisión de un abogado.
7. **Capturar WhatsApp y correo reales** en configuración y en `config.js`.

### Cabos sueltos detectados (22 de agosto)

Los dos primeros —la fuga de datos de contacto y del margen, y la despublicación
por vencimiento— **ya se cerraron** el mismo día; ver los conceptos 7 y 8 de
arriba. Queda uno:

1. **`diagnostico()` da un falso positivo dentro de un panel.** Su prueba 5
   asume que no hay sesión, así que al correrlo desde `/panel` marca *«GRAVE: la
   tabla enfermeros es legible sin sesión»* cuando en realidad el enfermero está
   leyendo su propia fila, que es justo lo que debe pasar. Verificado con `curl`
   como `anon`: la tabla responde `permission denied`. Conviene que la función
   avise que se corra desde una página pública, o que compruebe la sesión antes.

### Riesgos anotados

- **Reclasificación laboral.** Si la agencia impone tarifas, horarios y
  exclusividad, una autoridad puede considerar que hay relación de trabajo pese
  al contrato de servicios. Conviene que un abogado laboral revise el contrato
  individual antes del primero.
- **Storage se queda corto en el plan gratuito.** ~10 MB de documentos por
  profesional; con 1 GB se llega a unos 100 perfiles.

---

## Cómo trabaja Paco

Contexto que no está en el código y se pierde al cambiar de conversación.

- **Una cosa a la vez, y la valida él.** Es regla suya y está en `CLAUDE.md` §0.
  Espera que le digas qué abrir y qué debe ver. No encadenes tres features y se
  las entregues juntas.
- **Prueba en el navegador, no en tu cabeza.** Varios bugs de esta sesión sólo
  aparecieron al abrir la pantalla: el sello que se estiraba, la barra de
  filtros partida por el degradado, la franja de la tarjeta cortada por el
  radio. Ninguno se veía en el código.
- **Dice lo que piensa, sin adornos.** «Se ve prácticamente igual» y «no me
  gustan nada» son la clase de comentario que da. No lo suavices ni te
  defiendas: casi siempre tiene razón y lo que quiere es que lo arregles.
- **Le importa el costo.** Decidió no pagar hosting mientras itera. No le
  propongas gastar sin necesidad.
- **Escribe en español mexicano**, y todo el proyecto está así: interfaz,
  comentarios, mensajes de error, nombres de tabla y columna sin acentos.

### Cómo probar sin romper nada

- Los datos del seed usan fechas relativas al momento de instalación. Si algo se
  ve raro —«0 solicitudes hoy», turnos que ya pasaron— corre `aplicar-esquema.sh`
  y después **siempre** `crear-usuarios-prueba.sh` y `subir-documentos-prueba.sh`.
- Tras tocar cualquier `sql/*.sql`, `bash sql/generar-instalador.sh`.
- Antes de dar algo por terminado: `sql/99-pruebas.sql` debe salir en **62 OK**,
  y la pantalla debe verse bien a **390, 768 y 1440px** sin errores de consola.
- **El scroll programático no funciona en el panel del navegador de Claude
  Code.** `window.scrollTo` y `scrollIntoView` no mueven la página. Para ver la
  parte baja de una pantalla, agranda el alto de la ventana o esconde con JS los
  bloques de arriba. Perdí un rato creyendo que los contadores estaban rotos
  cuando lo que pasaba es que nunca entraban en pantalla.

---

## Verificación

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f sql/99-pruebas.sql
```

**62 comprobaciones, todas deben decir `OK`.** Cubren folios, reparto 60/40,
traslapes, permisos del sitio público, aislamiento de datos sensibles y acceso
al panel. No dejan datos.

Y en el navegador, con la consola abierta (F12):

```javascript
diagnostico()
```

Revisa seis cosas, incluida que la llave sea la `anon` y que la tabla
`enfermeros` **no** sea legible en público.
