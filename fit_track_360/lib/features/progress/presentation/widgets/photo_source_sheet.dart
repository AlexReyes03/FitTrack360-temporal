import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/tokens/app_colors.dart';

/// Hoja «Cámara / Galería» para elegir el origen de una foto de progreso.
/// Devuelve `null` si se cierra sin elegir.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.bgMid,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text(
                'Cámara',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text(
                'Galería',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
}
