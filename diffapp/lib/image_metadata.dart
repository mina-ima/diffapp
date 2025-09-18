import 'dart:async';
import 'dart:io';

/// 画像ファイル（PNG/JPEG）から素早く寸法を取得する。
/// - JPEG の場合は Exif の Orientation を考慮し、回転（5,6,7,8）なら縦横を入れ替える。
/// - 対応拡張: PNG, JPEG（その他は例外を投げずフォールバックしない）
Future<(int, int)> readImageSizeFastConsideringExif(String path) async {
  final file = File(path);
  final raf = await file.open();
  try {
    // Read first bytes for signature
    final sig = await raf.read(32);
    // PNG signature
    if (sig.length >= 24 &&
        sig[0] == 0x89 &&
        sig[1] == 0x50 && // P
        sig[2] == 0x4E && // N
        sig[3] == 0x47 && // G
        sig[4] == 0x0D &&
        sig[5] == 0x0A &&
        sig[6] == 0x1A &&
        sig[7] == 0x0A) {
      final w = (sig[16] << 24) | (sig[17] << 16) | (sig[18] << 8) | sig[19];
      final h = (sig[20] << 24) | (sig[21] << 16) | (sig[22] << 8) | sig[23];
      return (w, h);
    }

    // JPEG
    if (sig.length >= 2 && sig[0] == 0xFF && sig[1] == 0xD8) {
      // Iterate segments to find APP1 Exif and SOF with size
      await raf.setPosition(2);
      int? width;
      int? height;
      int orientation = 1; // default

      // helper to read 2 bytes big-endian
      Future<int> readBE16() async {
        final b0 = await raf.readByte();
        final b1 = await raf.readByte();
        return (b0 << 8) | b1;
      }

      // Parse up to a reasonable number of segments
      for (int i = 0; i < 2000; i++) {
        // Find marker: 0xFF followed by non-0xFF
        int byte = await raf.readByte();
        while (byte == 0xFF) {
          byte = await raf.readByte();
        }
        final marker = byte;
        final segLen = await readBE16();
        if (segLen < 2) break;

        final segStart = await raf.position();

        // APP1 (Exif)
        if (marker == 0xE1) {
          // Read header to check "Exif\0\0"
          final hdr = await raf.read(6);
          if (hdr.length == 6 &&
              hdr[0] == 0x45 && // E
              hdr[1] == 0x78 && // x
              hdr[2] == 0x69 && // i
              hdr[3] == 0x66 && // f
              hdr[4] == 0x00 &&
              hdr[5] == 0x00) {
            // TIFF header starts here
            final tiffStart = await raf.position();
            // Byte order
            final bo = await raf.read(2);
            final littleEndian = (bo.length == 2 && bo[0] == 0x49 && bo[1] == 0x49);

            int read16(List<int> b) => littleEndian
                ? (b[0] | (b[1] << 8))
                : ((b[0] << 8) | b[1]);
            int read32(List<int> b) => littleEndian
                ? (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24))
                : ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]);

            // 42 constant
            final fortyTwo = await raf.read(2);
            if (fortyTwo.length == 2) {
              // IFD0 offset
              final oBytes = await raf.read(4);
              if (oBytes.length == 4) {
                final ifd0Offset = read32(oBytes);
                // Move to IFD0
                await raf.setPosition(tiffStart + ifd0Offset);
                final cntBytes = await raf.read(2);
                if (cntBytes.length == 2) {
                  final entryCount = read16(cntBytes);
                  for (int e = 0; e < entryCount; e++) {
                    final entry = await raf.read(12);
                    if (entry.length < 12) break;
                    final tag = read16([entry[0], entry[1]]);
                    if (tag == 0x0112) {
                      // Orientation: type SHORT(3), count 1 expected
                      // value is in valueOffset for SHORT count=1 (lower 2 bytes)
                      orientation = littleEndian
                          ? (entry[8] | (entry[9] << 8))
                          : ((entry[8] << 8) | entry[9]);
                      // Found; we can stop scanning IFD entries
                      break;
                    }
                  }
                }
              }
            }
          }
          // Move to end of APP1 segment
          await raf.setPosition(segStart + segLen - 2);
        }

        // SOF markers with size info
        const sofMarkers = {
          0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF
        };
        if (sofMarkers.contains(marker)) {
          // Precision(1) + Height(2) + Width(2)
          final data = await raf.read(5);
          if (data.length == 5) {
            final h = (data[1] << 8) | data[2];
            final w = (data[3] << 8) | data[4];
            width = w;
            height = h;
          }
          // Move to end of segment
          await raf.setPosition(segStart + segLen - 2);
        }

        // If both found, we can stop parsing early
        if (width != null && height != null) {
          break;
        }
      }

      if (width != null && height != null) {
        final rotated = (orientation >= 5 && orientation <= 8);
        return rotated ? (height!, width!) : (width!, height!);
      }
    }

    // Unknown format or failed to parse; fallback to full decode via dart:ui is intentionally避ける
    // このユーティリティは軽量取得専用なので、失敗時は例外を投げて呼び出し側で対処させる。
    throw StateError('Unsupported image format or failed to parse: $path');
  } finally {
    await raf.close();
  }
}

