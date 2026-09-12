# Resumen ejecutivo del proyecto

## Objetivo

La aplicación permite gestionar boletas de compra chilenas a través de un flujo completo de carga, extracción automática de datos, validación manual y almacenamiento seguro.

## Problema que resuelve

Las boletas normalmente requieren revisión manual para extraer datos clave como comercio, RUT, fecha, folio y monto total. Este proceso puede ser lento, repetitivo y propenso a errores.

La solución automatiza esa extracción con IA multimodal y deja al usuario una revisión final rápida para confirmar la información antes de guardar.

## Arquitectura general

- Frontend: Rails + Turbo + Stimulus + Importmap
- Backend: Ruby on Rails 8
- Base de datos: PostgreSQL
- Procesamiento asíncrono: Solid Queue
- Almacenamiento de archivos: Active Storage con Cloudflare R2
- OCR/IA: Gemini API multimodal

## Flujo principal

1. El usuario sube una boleta en PDF o imagen.
2. La app guarda el archivo y crea un registro asociado.
3. Un job en segundo plano procesa el documento con Gemini.
4. La IA devuelve un JSON estructurado con los datos extraídos.
5. El sistema marca la boleta como pendiente o fallida según la calidad de la extracción.
6. El usuario revisa el contenido precargado y guarda la información final.
7. El comprobante queda disponible en el listado de registros validados.



## Estado actual

El proyecto está funcionando como una base sólida para un sistema de OCR de comprobantes, con la lógica principal implementada y lista para continuar mejorando de forma modular y escalable.
