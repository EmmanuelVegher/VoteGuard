import "package:image/image.dart" as img;
void main() {
  final image = img.Image(width: 100, height: 100);
  final cropped = img.copyCrop(image, x: 10, y: 10, width: 50, height: 50);
  final resized = img.copyResize(cropped, width: 200, height: 200);
  final oriented = img.bakeOrientation(resized);
  final jpg = img.encodeJpg(oriented, quality: 95);
  print("Image API check passed, jpg length: ${jpg.length}");
}
