# Estado del proyecto — Enlace Enfermero

> Documento de continuidad. Léelo junto con `CLAUDE.md`, que es la especificación
> maestra. Aquí está **qué se construyó, cómo funciona y qué falta**.
>
> Última actualización: 22 de agosto de 2026

---

## Resumen en una línea

Fases 0, 1 y 2 completas y verificadas. El sitio público captura solicitudes y
registros; la agencia opera el negocio completo desde su panel. Falta la Fase 3
(paneles de enfermero y cliente) y migrar de Supabase local a producción.

| Fase | Alcance | Estado |
|---|---|---|
| 0 | Cimientos: estructura, tokens, SQL base | **Completada** |
| 1 | Sitio público: catálogo, perfiles, formularios | **Completada** |
| 2 | Autenticación y panel de la agencia | **Completada** |
| 3 | Paneles de enfermero y cliente | **Pendiente** |
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

> Los datos del seed usan fechas relativas al momento de instalación. Si tras unos
> días el panel muestra números raros ("0 solicitudes hoy"), corre
> `aplicar-esquema.sh` y vuelven a ser frescas.

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
| `panel-admin.js` | Dashboard: KPIs, alertas, gráfica Canvas |
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
| `99-pruebas.sql` | **28 verificaciones.** Hace rollback, no deja datos |

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

### 5. El motor de match

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

### Panel del enfermero (Fase 3) — **pendiente**
`panel/index.html` existe con la navegación puesta y el contenido en blanco.
Faltan: inicio, perfil, documentos, disponibilidad, asignaciones, historial,
ganancias.

### Panel del cliente (Fase 3) — **pendiente**
`cliente/index.html` igual. Faltan: inicio, nueva solicitud, solicitudes,
personal, evaluar, facturación.

---

## Qué falta hacer

### Fase 3 — Paneles de enfermero y cliente

**Enfermero** (`/panel`, guardia `['enfermero']`):
- **Inicio** — próximos turnos, ganancias del mes, calificación, alertas de
  documentos por vencer, porcentaje de perfil completo.
- **Perfil** — edición de todo salvo verificación, publicación y tarifas
  (el trigger `proteger_campos_enfermero` ya lo impide en la base).
- **Documentos** — subir y renovar. **Ojo:** la política de Storage exige que
  la ruta sea `<enfermero_id>/<archivo>`.
- **Disponibilidad** — calendario mensual con clic para marcar turnos y
  plantilla semanal repetible.
- **Asignaciones** — aceptar o rechazar con motivo, y check-in/check-out. Las
  transiciones permitidas ya están en `proteger_campos_asignacion`:
  `propuesta → aceptada|rechazada`, `aceptada → en_curso`, `en_curso → completada`.
- **Historial y Ganancias** — agregado por quincena con estatus de pago.

**Cliente** (`/cliente`, guardia `['cliente']`):
- **Inicio** — servicios activos, próximo turno, personal asignado.
- **Nueva solicitud** — el mismo formulario, precargado con sus datos.
- **Solicitudes** — seguimiento con línea de tiempo.
- **Personal** — quién está o estuvo asignado, con "solicitar de nuevo".
- **Evaluar** — 4 criterios más comentario. Solo sobre asignaciones
  `completada` y dentro de 15 días; la policy ya lo restringe.
- **Facturación** — historial y descarga de comprobantes.

Faltan funciones SQL para estos paneles (algo como `11-paneles.sql`), siempre
con `es_staff_estricto()` invertido: cada quien ve solo lo suyo.

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

### Riesgos anotados

- **Reclasificación laboral.** Si la agencia impone tarifas, horarios y
  exclusividad, una autoridad puede considerar que hay relación de trabajo pese
  al contrato de servicios. Conviene que un abogado laboral revise el contrato
  individual antes del primero.
- **Storage se queda corto en el plan gratuito.** ~10 MB de documentos por
  profesional; con 1 GB se llega a unos 100 perfiles.

---

## Verificación

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f sql/99-pruebas.sql
```

**28 comprobaciones, todas deben decir `OK`.** Cubren folios, reparto 60/40,
traslapes, permisos del sitio público, aislamiento de datos sensibles y acceso
al panel. No dejan datos.

Y en el navegador, con la consola abierta (F12):

```javascript
diagnostico()
```

Revisa seis cosas, incluida que la llave sea la `anon` y que la tabla
`enfermeros` **no** sea legible en público.
