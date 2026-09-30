part of './../../on_process_camera.dart';

class InputImageModel {
  InputImageModel({
    required this.filePath,
    required this.bytes,
    required this.bitmapData,
    required this.type,
    required this.metadata,
    required this.rotation,
  });

  /// The file path to the image.
  final String? filePath;

  /// The bytes of the image.
  final Uint8List? bytes;

  /// Raw bitmap pixel data.
  final Uint8List? bitmapData;

  /// The type of image.
  final InputImageType type;

  /// The image data when creating an image of type = [InputImageType.bytes].
  final InputImageMetadata? metadata;

  /// The rotation degrees for bitmap images.
  final int? rotation;

  static InputImageModel _fromInputImage(InputImage inputImage) {
    return InputImageModel(
      filePath: inputImage.filePath,
      bytes: inputImage.bytes,
      bitmapData: inputImage.bitmapData,
      type: inputImage.type,
      metadata: inputImage.metadata,
      rotation: inputImage.rotation,
    );
  }
}
