import 'dart:convert';

/// Decodes statement bytes into text without silently corrupting Turkish
/// characters.
///
/// Banks export CSV in whatever encoding their backend defaults to. UTF-8 is
/// the common case, but Windows-1254 (Turkish) is still widespread. Decoding a
/// Windows-1254 file as UTF-8 turns `AÇIKLAMA` into `A?IKLAMA`, which makes
/// column detection fail — so the encoding is detected instead of assumed.
abstract final class TextDecoder {
  /// Characters for Windows-1254 bytes 0x80-0x9F. From 0xA0 upwards the code
  /// page matches Latin-1 except for the six Turkish letters handled below.
  static const String _cp1254Upper =
      '€�‚ƒ„…†‡'
      'ˆ‰Š‹Œ���'
      '�‘’“”•–—'
      '˜™š›œ��Ÿ';

  static String decode(List<int> bytes) {
    if (bytes.isEmpty) return '';

    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return _tryUtf8(bytes.sublist(3)) ?? _decodeCp1254(bytes.sublist(3));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    return _tryUtf8(bytes) ?? _decodeCp1254(bytes);
  }

  static String? _tryUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  static String _decodeCp1254(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.writeCharCode(_cp1254CodeUnit(byte & 0xFF));
    }
    return buffer.toString();
  }

  static int _cp1254CodeUnit(int byte) {
    if (byte < 0x80) return byte;
    if (byte < 0xA0) return _cp1254Upper.codeUnitAt(byte - 0x80);
    return switch (byte) {
      0xD0 => 0x011E, // Ğ
      0xDD => 0x0130, // İ
      0xDE => 0x015E, // Ş
      0xF0 => 0x011F, // ğ
      0xFD => 0x0131, // ı
      0xFE => 0x015F, // ş
      _ => byte, // identical to Latin-1
    };
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int unit = littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1];
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }
}
