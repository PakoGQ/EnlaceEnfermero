# Despliegue — Enlace Enfermero

Sigue el orden. Cada paso depende del anterior.

## 1. Repositorio en GitHub

```bash
git init
git add .
git commit -m "Fase 0: cimientos del proyecto"
git branch -M main
git remote add origin https://github.com/USUARIO/enlace-enfermero.git
git push -u origin main
```

## 2. Proyecto en Supabase

1. Crear proyecto en [supabase.com](https://supabase.com), región `us-west-1` o `us-east-1`.
2. Abrir **SQL Editor** y ejecutar en este orden, uno por uno:
   - `sql/01-schema.sql`
   - `sql/02-rls.sql`
   - `sql/03-funciones.sql`
   - `sql/04-vistas.sql`
3. Ir a **Storage** y crear tres buckets:

   | Bucket | Acceso | Contenido |
   |---|---|---|
   | `fotos` | Público | Fotos de perfil de enfermeros |
   | `documentos` | **Privado** | INE, cédula, título, comprobantes |
   | `comprobantes` | **Privado** | Comprobantes de pago |

   Las políticas de acceso a estos buckets ya vienen en `02-rls.sql`; los buckets
   deben existir antes de ejecutarlo.

4. Opcional: ejecutar `sql/05-seed.sql` para poblar el catálogo con 12 perfiles
   ficticios. No usarlo en producción con clientes reales.
5. Ejecutar `sql/99-pruebas.sql` para verificar la instalación. Comprueba
   folios, comisiones, el bloqueo de turnos encimados y que el catálogo público
   no exponga datos sensibles. Cada renglón del resultado debe decir `OK`.
   El script hace `rollback` al final: no deja datos.
6. Ir a **Settings → API** y copiar `Project URL` y la llave `anon public`.

> **Nunca** copies la llave `service_role` al frontend. Solo la `anon`.

## 3. Conectar el frontend

Editar `js/config.js`:

```javascript
SUPABASE_URL: 'https://xxxxxxxx.supabase.co',
SUPABASE_ANON_KEY: 'eyJhbGci...',
```

Mientras esos valores sigan en `TU-PROYECTO` / `TU_ANON_KEY`, el sitio navega
normalmente pero no consulta la base de datos: es el comportamiento esperado
durante la Fase 0.

## 4. GitHub Pages

1. **Settings → Pages → Source**: rama `main`, carpeta `/ (root)`.
2. Esperar el despliegue. Queda en `https://USUARIO.github.io/enlace-enfermero/`.

## 5. Dominio propio (opcional)

1. Verificar disponibilidad de `enlaceenfermero.mx`.
2. Crear archivo `CNAME` en la raíz con el dominio, sin `https://`.
3. En el proveedor de DNS, apuntar un registro `CNAME` a `USUARIO.github.io`.

## 6. URLs autorizadas en Supabase

**Authentication → URL Configuration**, agregar a *Site URL* y *Redirect URLs*:

- `https://USUARIO.github.io/enlace-enfermero/`
- `https://enlaceenfermero.mx` (cuando exista)
- `http://localhost:8000` (para desarrollo)

## 7. Servidor local

El sitio es HTML estático, pero necesita servirse por HTTP para que Supabase
funcione (no abrir con `file://`):

```bash
python3 -m http.server 8000
```

Luego abrir `http://localhost:8000`.
