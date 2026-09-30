part of './../../../on_process_camera.dart';

extension CameraImageExtension on CameraImage {
  /// Converts [CameraImage] in YUV420_888 format to NV21 byte array.
  Uint8List get toNV21 {
    if (format.group == ImageFormatGroup.nv21) return __toNv21Byte;
    return __yuv420888ToNv21Byte;
  }

  /// Converts [CameraImage] to [InputImage] for Google MLKit
  InputImage toInputImage(InputImageRotation rotation) {
    // iOS streams single-plane BGRA8888, which ML Kit accepts as-is
    if (format.group == ImageFormatGroup.bgra8888) {
      final Plane plane = planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    final Uint8List nv21Bytes = toNV21;

    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width, // now consistent
      ),
    );
  }

  Uint8List get __yuv420888ToNv21Byte {
    final int width = this.width;
    final int height = this.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;

    final Uint8List nv21Bytes = Uint8List(ySize + uvSize);

    // ---- Y Plane ----
    final Uint8List yBuffer = planes[0].bytes;
    int srcIndex = 0;
    int dstIndex = 0;

    for (int row = 0; row < height; row++) {
      int rowLength = width;
      nv21Bytes.setRange(
        dstIndex,
        dstIndex + rowLength,
        yBuffer.sublist(srcIndex, srcIndex + rowLength),
      );
      srcIndex += planes[0].bytesPerRow;
      dstIndex += width;
    }

    // ---- UV Planes ----
    final Uint8List uBuffer = planes[1].bytes;
    final Uint8List vBuffer = planes[2].bytes;

    final int uvRowStride = planes[1].bytesPerRow;
    final int uvPixelStride = planes[1].bytesPerPixel ?? 1;

    int uvHeight = height ~/ 2;
    int uvWidth = width ~/ 2;
    int nv21Index = ySize;

    for (int row = 0; row < uvHeight; row++) {
      int uRowStart = row * uvRowStride;
      int vRowStart = row * planes[2].bytesPerRow;

      for (int col = 0; col < uvWidth; col++) {
        int uIndex = uRowStart + col * uvPixelStride;
        int vIndex = vRowStart + col * (planes[2].bytesPerPixel ?? 1);

        // NV21 = VU interleaved
        nv21Bytes[nv21Index++] = vBuffer[vIndex];
        nv21Bytes[nv21Index++] = uBuffer[uIndex];
      }
    }

    return nv21Bytes;
  }

  Uint8List get __toNv21Byte {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final Uint8List bytes = allBytes.done().buffer.asUint8List();

    return bytes;
  }

  image_package.Image get _decodeYUV420SP {
    final int width_ = width.toInt();
    final int height_ = height.toInt();

    Uint8List yuv420sp = planes.first.bytes;

    final image_package.Image outImg = image_package.Image(
      width: width_,
      height: height_,
    );

    final int frameSize = width_ * height_;

    for (int j = 0, yp = 0; j < height_; j++) {
      int uvp = frameSize + (j >> 1) * width_, u = 0, v = 0;
      for (int i = 0; i < width_; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }
        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0) {
          r = 0;
        } else if (r > 262143) {
          r = 262143;
        }
        if (g < 0) {
          g = 0;
        } else if (g > 262143) {
          g = 262143;
        }
        if (b < 0) {
          b = 0;
        } else if (b > 262143) {
          b = 262143;
        }

        outImg.setPixelRgb(
          i,
          j,
          ((r << 6) & 0xff0000) >> 16,
          ((g >> 2) & 0xff00) >> 8,
          (b >> 10) & 0xff,
        );
      }
    }
    return outImg;
  }

  image_package.Image? get _convertYUV420toImageColor {
    try {
      final int w = width;
      final int h = height;

      final int uvRowStride = planes[1].bytesPerRow;
      final int uvPixelStride = planes[1].bytesPerPixel ?? 1;

      final image_package.Image imgBuffer = image_package.Image(
        width: w,
        height: h,
      );

      for (int y = 0; y < h; y++) {
        final int uvRow = uvRowStride * (y >> 1);
        for (int x = 0; x < w; x++) {
          final int uvIndex = uvRow + (x >> 1) * uvPixelStride;

          final int yp = planes[0].bytes[y * planes[0].bytesPerRow + x];

          final int up = planes[1].bytes[uvIndex];
          final int vp = planes[2].bytes[uvIndex];

          // Convert YUV -> RGB
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          imgBuffer.setPixelRgb(x, y, r, g, b);
        }
      }

      return imgBuffer;
    } catch (e) {
      _devPrint('YUV420 conversion failed: $e');
      return null;
    }
  }

  /// Core conversion — CameraImage → image package Image (RGB)
  image_package.Image? get _cameraImageToImage {
    try {
      if (format.group == ImageFormatGroup.nv21) {
        return _decodeYUV420SP;
      } else if (format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420toImageColor;
      } else if (format.group == ImageFormatGroup.bgra8888) {
        return image_package.Image.fromBytes(
          width: width,
          height: height,
          bytes: planes[0].bytes.buffer,
          order: image_package.ChannelOrder.bgra,
        );
      }
      return null;
    } catch (e) {
      _devPrint('CameraImage conversion failed: $e');
      return null;
    }
  }
}
