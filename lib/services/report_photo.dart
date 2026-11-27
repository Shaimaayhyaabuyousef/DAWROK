import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Re-encode to strip metadata and bound Firestore payload size on Spark.
Uint8List compressReportPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null)
    throw StateError('Choose a supported JPEG or PNG photo.');
  var picture = img.bakeOrientation(decoded);
  if (picture.width > 900 || picture.height > 900) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? 900 : null,
      height: picture.height > picture.width ? 900 : null,
    );
  }
  final clean = img.Image(width: picture.width, height: picture.height);
  img.compositeImage(clean, picture);
  picture = clean;
  for (final quality in [75, 55, 35]) {
    final encoded = Uint8List.fromList(
      img.encodeJpg(picture, quality: quality),
    );
    if (encoded.length <= 200000) return encoded;
  }
  picture = img.copyResize(
    picture,
    width: picture.width >= picture.height ? 500 : null,
    height: picture.height > picture.width ? 500 : null,
  );
  final encoded = Uint8List.fromList(img.encodeJpg(picture, quality: 35));
  if (encoded.length > 200000)
    throw StateError('This photo is too large. Choose a smaller photo.');
  return encoded;
}

Future<Uint8List?> pickReportPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1000,
    maxHeight: 1000,
    imageQuality: 80,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  if (await file.length() > 10000000)
    throw StateError('Choose a photo smaller than 10 MB.');
  return compute(compressReportPhoto, await file.readAsBytes());
}
