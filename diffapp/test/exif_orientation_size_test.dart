import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/image_metadata.dart';

// Helper to build a minimal JPEG with APP1 Exif orientation and SOF0 size.
List<int> buildJpegWithExif({
  required int width,
  required int height,
  required int orientation, // 1..8
}) {
  final bytes = <int>[];
  // SOI
  bytes.addAll([0xFF, 0xD8]);

  // APP1 Exif segment
  final tiff = <int>[];
  // TIFF header: little-endian (II), 42, IFD0 offset=8
  tiff.addAll([0x49, 0x49]);
  tiff.addAll([0x2A, 0x00]);
  tiff.addAll([0x08, 0x00, 0x00, 0x00]);
  // IFD0: 1 entry
  tiff.addAll([0x01, 0x00]);
  // Entry: tag=0x0112 (Orientation), type=SHORT(3), count=1, value=orientation
  tiff.addAll([0x12, 0x01]); // tag
  tiff.addAll([0x03, 0x00]); // type SHORT
  tiff.addAll([0x01, 0x00, 0x00, 0x00]); // count=1
  // value (2 bytes) + pad
  tiff.addAll([orientation & 0xFF, (orientation >> 8) & 0xFF, 0x00, 0x00]);
  // next IFD offset = 0
  tiff.addAll([0x00, 0x00, 0x00, 0x00]);

  final exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
  final app1DataLen = exifHeader.length + tiff.length; // not including length field itself
  final app1Len = app1DataLen + 2; // JPEG length includes the two length bytes
  bytes.addAll([0xFF, 0xE1, (app1Len >> 8) & 0xFF, app1Len & 0xFF]);
  bytes.addAll(exifHeader);
  bytes.addAll(tiff);

  // SOF0 segment with size
  final sofData = <int>[];
  sofData.add(0x08); // precision
  sofData.addAll([(height >> 8) & 0xFF, height & 0xFF]);
  sofData.addAll([(width >> 8) & 0xFF, width & 0xFF]);
  sofData.add(0x01); // 1 component
  sofData.addAll([0x01, 0x11, 0x00]); // component spec
  final sofLen = sofData.length + 2;
  bytes.addAll([0xFF, 0xC0, (sofLen >> 8) & 0xFF, sofLen & 0xFF]);
  bytes.addAll(sofData);

  // EOI (not strictly necessary for our parser but keep it tidy)
  bytes.addAll([0xFF, 0xD9]);
  return bytes;
}

void main() {
  test('JPEG Exif Orientation 6 swaps width/height', () async {
    final tmp = await File('${Directory.systemTemp.path}/exif_o6.jpg').create();
    final w = 4032;
    final h = 3024;
    final data = buildJpegWithExif(width: w, height: h, orientation: 6);
    await tmp.writeAsBytes(data, flush: true);

    final dims = await readImageSizeFastConsideringExif(tmp.path);
    expect(dims.$1, h);
    expect(dims.$2, w);

    await tmp.delete();
  });

  test('JPEG Exif Orientation 1 keeps width/height', () async {
    final tmp = await File('${Directory.systemTemp.path}/exif_o1.jpg').create();
    final w = 4032;
    final h = 3024;
    final data = buildJpegWithExif(width: w, height: h, orientation: 1);
    await tmp.writeAsBytes(data, flush: true);

    final dims = await readImageSizeFastConsideringExif(tmp.path);
    expect(dims.$1, w);
    expect(dims.$2, h);

    await tmp.delete();
  });
}

