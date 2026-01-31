import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcService {
  /// Checks if NFC is available on the device
  static Future<bool> isNfcAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      debugPrint('NFC availability check failed: $e');
      return false;
    }
  }

  /// Writes a URL to an NFC tag as NDEF URI record
  /// Returns true if successful, throws exception on failure
  static Future<bool> writeUrlToTag(
    String url, {
    required void Function(String message) onStatusUpdate,
  }) async {
    // Check NFC availability
    final isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      throw NfcException('NFC không khả dụng trên thiết bị này');
    }

    bool writeSuccess = false;
    String? errorMsg;

    try {
      onStatusUpdate('Đưa thiết bị lại gần thẻ NFC...');

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            // Get Ndef instance from tag
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              throw NfcException('Thẻ NFC không hỗ trợ NDEF');
            }

            if (!ndef.isWritable) {
              throw NfcException('Thẻ NFC không thể ghi');
            }

            // Create NDEF message with URI record
            final uriRecord = _createUriRecord(url);
            final ndefMessage = NdefMessage(records: [uriRecord]);

            // Check if tag has enough capacity
            final messageSize = ndefMessage.byteLength;
            if (ndef.maxSize < messageSize) {
              throw NfcException(
                'Thẻ NFC không đủ dung lượng ($messageSize/${ndef.maxSize} bytes)',
              );
            }

            onStatusUpdate('Đang ghi dữ liệu vào thẻ NFC...');

            // Write to tag
            await ndef.write(message: ndefMessage);

            writeSuccess = true;
            onStatusUpdate('Ghi NFC thành công!');

            // Stop session after successful write
            await NfcManager.instance.stopSession();
          } catch (e) {
            errorMsg = e.toString();
            await NfcManager.instance.stopSession();
            if (e is NfcException) rethrow;
            throw NfcException('Lỗi ghi NFC: $e');
          }
        },
      );

      // Wait for the write operation with timeout
      final stopwatch = Stopwatch()..start();
      const timeout = Duration(seconds: 30);

      while (!writeSuccess && errorMsg == null && stopwatch.elapsed < timeout) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (errorMsg != null) {
        throw NfcException(errorMsg!);
      }

      if (!writeSuccess) {
        await NfcManager.instance.stopSession();
        throw NfcException('Hết thời gian chờ ghi NFC');
      }

      return true;
    } catch (e) {
      // Ensure session is stopped
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}

      if (e is NfcException) rethrow;
      throw NfcException('Lỗi NFC: $e');
    }
  }

  /// Creates an NDEF URI record for the given URL
  static NdefRecord _createUriRecord(String url) {
    // URI prefix codes as per NDEF spec
    const prefixes = <int, String>{
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
      0x05: 'tel:',
      0x06: 'mailto:',
    };

    int prefixCode = 0x00; // No prefix
    String uriBody = url;

    for (final entry in prefixes.entries) {
      if (url.startsWith(entry.value)) {
        prefixCode = entry.key;
        uriBody = url.substring(entry.value.length);
        break;
      }
    }

    // Build payload: prefix code + URI body
    final uriBytes = Uint8List.fromList(uriBody.codeUnits);
    final payload = Uint8List(1 + uriBytes.length);
    payload[0] = prefixCode;
    payload.setRange(1, payload.length, uriBytes);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // 'U' for URI
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  /// Cancels any ongoing NFC session
  static Future<void> cancelSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Check if current platform supports NFC
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isIOS;
  }
}

/// Custom exception for NFC-related errors
class NfcException implements Exception {
  final String message;
  NfcException(this.message);

  @override
  String toString() => message;
}
