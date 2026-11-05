# Documento de permisos — FitTrack360

> **Estado:** borrador (semana 8). Se completa hacia la semana 14 (H6).
> **Fuente de columnas:** enunciado del proyecto integrador, sección 4.5.
> **Reglas que aplican a cada fila:** enunciado, sección 4.2 (mínimo privilegio, solicitud en contexto, tres estados, degradación funcional, servicios del sistema, textos en español, datos y privacidad, transparencia en uso, prueba en dispositivo físico para P1 y P2).

## Capacidades elegidas

| Tipo | Capacidades | Puntos |
| --- | --- | --- |
| Base obligatoria | P1, P2, P3 | No suma |
| Optativas anunciadas | O1 (2) + O5 (2) + O7 (1) + O10 (1) | **6** (mínimo para equipo de 6) |

Las optativas se pueden cambiar solo hasta H3 y avisándolo en el PR de este documento.

## Tabla de permisos

| Capacidad | Permiso Android (tipo) | Clave iOS | Historia de usuario | Momento de la solicitud | Si se niega | Dato, finalidad y retención | Evidencia (3 estados) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **P1** Cámara / galería | Ninguno declarado: `image_picker` abre la cámara con el intent del sistema y la galería con el selector de fotos (Android 13+). **Sin** permisos de almacenamiento. Si algún plugin agrega `CAMERA` al manifiesto fusionado, pasa a ser de ejecución y se manejan sus tres estados | `NSCameraUsageDescription` · `NSPhotoLibraryUsageDescription` | Como usuario quiero tomar o elegir una foto de mi progreso corporal o de mi comida para comparar mi avance con el tiempo. | Al tocar «Agregar foto» en Progreso o en el registro de una comida, después de una pantalla previa que explica el uso. | Puede elegir una foto de la galería en lugar de la cámara, o guardar el registro sin foto. | Foto reducida antes de subir (`maxWidth` / `imageQuality`); se asocia solo a ese registro de progreso o comida; se sube a la nube con acceso solo del dueño y el servidor elimina EXIF/GPS. Se conserva mientras exista el registro; se borra al eliminar el registro o la cuenta. | Pendiente (dispositivo físico) |
| **P2** Ubicación en primer plano | `ACCESS_COARSE_LOCATION` (ejecución). Sin `ACCESS_FINE_LOCATION` | `NSLocationWhenInUseUsageDescription` | Como usuario quiero registrar en qué gimnasio o zona entrené al cerrar mi sesión para ver dónde entreno más. | Al tocar «Agregar ubicación» al cerrar una sesión de entrenamiento. | Elige la zona de una lista manual. Si el GPS está apagado se avisa y se ofrece la misma lista. | Coordenadas aproximadas; ubicar la sesión de entrenamiento; se guardan solo en esa sesión y se borran con ella o con la cuenta. | Pendiente (dispositivo físico) |
| **P3** Notificaciones | `POST_NOTIFICATIONS` (ejecución, Android 13+). Sin `SCHEDULE_EXACT_ALARM` (programación inexacta) | Solicitud de autorización en ejecución | Como usuario quiero un recordatorio para entrenar o registrar mi comida y no perder la constancia. | Al activar el recordatorio en Ajustes, con explicación previa. | La app sigue funcionando; el recordatorio se muestra dentro de la app al abrirla. Si las notificaciones están apagadas en el sistema, se informa y se ofrece abrir ajustes. | Hora del recordatorio y preferencia activado/desactivado; programar el aviso local; se conserva hasta que el usuario la cambie o borre la cuenta. Interruptor en Ajustes para desactivarla. | Pendiente |
| **O1** Biometría | `USE_BIOMETRIC` (instalación) | `NSFaceIDUsageDescription` | Como usuario quiero desbloquear mi sesión o confirmar una acción sensible (por ejemplo, borrar mi cuenta) con mi huella o rostro para proteger mis datos. | Al activar «Desbloqueo con biometría» en Ajustes o al confirmar la acción sensible. | Usa su contraseña como alternativa. Si el dispositivo no tiene biometría, la opción se oculta. | Ningún dato biométrico sale del dispositivo; la app solo recibe éxito o fallo del sistema. Se guarda la preferencia activado/desactivado hasta que el usuario la cambie. | Pendiente |
| **O5** Pasos del día | `ACTIVITY_RECOGNITION` (ejecución) | `NSMotionUsageDescription` | Como usuario quiero ver mis pasos del día en el resumen del Home junto con mi entrenamiento y mis macros. | Al tocar «Mostrar mis pasos» en el Home, con explicación previa. | El resumen del Home se muestra sin la tarjeta de pasos; se puede activar después desde Ajustes. | Conteo de pasos del día; mostrarlo en el resumen diario. Si se sube a la nube y cuánto se conserva: **por definir con el equipo**. | Pendiente |
| **O7** Contacto y mensaje | Sin permiso: selector de contactos del sistema. **Sin** `READ_CONTACTS` ni `CALL_PHONE` | Sin clave (selector del sistema) | Como usuario quiero enviar mi progreso a un amigo o entrenador por WhatsApp o SMS para que me acompañe. | Al tocar «Enviar a un contacto» en Progreso o Home. | Puede escribir el número a mano o usar «Compartir» (O10). | El número elegido se usa solo para abrir `https://wa.me/` o `sms:`; no se guarda ni se sube. El usuario confirma el envío en la app del sistema. | Pendiente |
| **O10** Compartir | Sin permisos | Sin clave | Como usuario quiero compartir el resumen de mi sesión o de mi día con la hoja de compartir del sistema. | Al tocar «Compartir resumen». | No aplica (no hay permiso que negar). | Texto o imagen del resumen generado en el momento; no se guarda una copia extra. | Pendiente |

## Permisos que no usamos (sección 4.4)

| Permiso o práctica | Motivo |
| --- | --- |
| `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Prohibidos; P1 usa el selector de fotos del sistema |
| `READ_CONTACTS` | Prohibido; O7 usa el selector de contactos del sistema |
| `READ_SMS`, `SEND_SMS`, `READ_CALL_LOG`, `CALL_PHONE` | Prohibidos; O7 abre `sms:` o `wa.me` y el usuario confirma |
| `ACCESS_FINE_LOCATION` | No se justifica: la zona del gimnasio basta con ubicación aproximada |
| `ACCESS_BACKGROUND_LOCATION` | No elegimos O12 |
| `SCHEDULE_EXACT_ALARM` | El recordatorio usa programación inexacta |
| IDFA / App Tracking Transparency, SDK de anuncios | Prohibidos; no se usan |

## Paquetes

Las versiones se verifican en pub.dev **al integrar cada paquete** (versión vigente, publisher verificado, soporte Android e iOS) y se registran aquí.

| Capacidad | Paquete | Versión | Publisher verificado | Android / iOS |
| --- | --- | --- | --- | --- |
| P1 | `image_picker` | 1.2.4 | Sí (flutter.dev) | Android / iOS |
| P2 | `geolocator` | Pendiente | Pendiente | Pendiente |
| P3 | `flutter_local_notifications` + `timezone` | Pendiente | Pendiente | Pendiente |
| Tres estados | `permission_handler` | 13.0.2 | Sí (baseflow.com) | Android / iOS |
| O1 | `local_auth` | Pendiente | Pendiente | Pendiente |
| O5 | `pedometer` | Pendiente | Pendiente | Pendiente |
| O7 | `url_launcher` + selector de contacto del sistema | Pendiente | Pendiente | Pendiente |
| O10 | `share_plus` | Pendiente | Pendiente | Pendiente |

## Pendientes antes de H6

- [ ] Capturas de los tres estados (concedido, denegado, denegado permanentemente) por permiso.
- [ ] Prueba en dispositivo físico de P1 y P2.
- [ ] Revisar el `AndroidManifest.xml` fusionado del APK de release y el `Info.plist`.
- [ ] Textos de propósito finales en `Info.plist` y en las pantallas previas.
- [ ] Definir si los pasos (O5) se suben a la nube y su retención.
- [ ] Llenar la tabla de paquetes.
