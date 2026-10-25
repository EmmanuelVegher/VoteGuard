import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

InputImage? convertCameraImageToInputImage({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation orientation,
}) {
  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final imageRotation = InputImageRotationValue.fromRawValue(
    camera.sensorOrientation,
  );
  if (imageRotation == null) return null;

  final imageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
  if (imageFormat == null) return null;

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: imageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}
