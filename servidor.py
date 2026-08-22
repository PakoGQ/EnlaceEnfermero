#!/usr/bin/env python3
"""
Servidor de desarrollo de Enlace Enfermero.

Sirve el sitio sin cache, para que los cambios en CSS y JS se vean al recargar
sin tener que forzar el navegador. Solo es una herramienta local: GitHub Pages
sirve los archivos por su cuenta y este archivo no interviene en produccion.

    python3 servidor.py [puerto]
"""

import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler


class SinCache(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Expires', '0')
        super().end_headers()

    def log_message(self, formato, *args):
        # Solo se reportan los errores; las peticiones correctas hacen ruido
        if args and str(args[1]).startswith(('4', '5')):
            super().log_message(formato, *args)


if __name__ == '__main__':
    puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f'Enlace Enfermero  ->  http://localhost:{puerto}')
    print('Ctrl+C para detener.')
    try:
        HTTPServer(('', puerto), SinCache).serve_forever()
    except KeyboardInterrupt:
        print('\nServidor detenido.')
