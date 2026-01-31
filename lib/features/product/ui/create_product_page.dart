import 'package:flutter/material.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/nfc_service.dart';

class CreateProductPage extends StatefulWidget {
  const CreateProductPage({super.key});

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _describeController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _pickedImage;
  bool _isSubmitting = false;
  Map<String, dynamic>? _lastSuccessResponse;

  @override
  void dispose() {
    _describeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (image == null) return;

      setState(() {
        _pickedImage = image;
        _lastSuccessResponse = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Không thể chọn ảnh: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final describe = _describeController.text.trim();

    if (_pickedImage == null) {
      _showMessage('Vui lòng chọn ảnh');
      return;
    }
    if (describe.isEmpty) {
      _showMessage('Vui lòng nhập mô tả');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        throw 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final imageFile = File(_pickedImage!.path);
      final formData = FormData.fromMap({
        'describe': describe,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: _pickedImage!.name,
        ),
      });

      final response = await dio.post<Map<String, dynamic>>(
        'products',
        data: formData,
      );

      final data = response.data;
      if (data == null) {
        throw 'Phản hồi từ máy chủ không hợp lệ';
      }

      if (!mounted) return;
      setState(() {
        _lastSuccessResponse = data;
        _pickedImage = null;
        _describeController.clear();
      });

      _showMessage(data['message']?.toString() ?? 'Tạo sản phẩm thành công');

      // STEP 1: Check if nfc_url exists
      final nfcUrl = data['nfc_url']?.toString();
      final tagId = data['product']?['tag_id']?.toString();

      if (nfcUrl == null || nfcUrl.isEmpty) {
        _showMessage('Lỗi: nfc_url không tồn tại trong phản hồi');
        return;
      }

      // STEP 2: Write NFC tag
      await _writeNfcTag(nfcUrl, tagId);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message =
          (data is Map && data['message'] != null) ? data['message'].toString() : null;
      _showMessage(message ?? 'Không thể kết nối đến máy chủ');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// STEP 2: Write NFC tag with the nfc_url
  Future<void> _writeNfcTag(String nfcUrl, String? tagId) async {
    // Check platform support
    if (!NfcService.isPlatformSupported()) {
      _showMessage('NFC không được hỗ trợ trên nền tảng này');
      return;
    }

    // Check NFC availability
    final isAvailable = await NfcService.isNfcAvailable();
    if (!isAvailable) {
      _showMessage('NFC không khả dụng. Vui lòng bật NFC trong cài đặt.');
      return;
    }

    // Show NFC write dialog
    if (!mounted) return;
    final writeSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NfcWriteDialog(nfcUrl: nfcUrl),
    );

    if (!mounted) return;
    if (writeSuccess == true && tagId != null && tagId.isNotEmpty) {
      // STEP 3: Confirm NFC write to server
      await _confirmNfcWritten(tagId);
    }
  }

  /// STEP 3: Confirm NFC write success to server
  Future<void> _confirmNfcWritten(String tagId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _showMessage('Phiên đăng nhập đã hết hạn');
        return;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.put<Map<String, dynamic>>(
        ApiConstants.productNfcWritten(tagId),
      );

      if (!mounted) return;

      final message = response.data?['message']?.toString() ?? 
          'Xác nhận ghi NFC thành công';
      _showMessage(message);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null) 
          ? data['message'].toString() 
          : 'Không thể xác nhận ghi NFC với máy chủ';
      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Lỗi xác nhận NFC: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _pickedImage?.path;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
        ),
        title: const Text('Tạo sản phẩm'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.03),
                  ),
                  alignment: Alignment.center,
                  child: imagePath == null
                      ? const Text('Chưa có ảnh')
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose from Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _describeController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Describe',
                    hintText: 'Nhập mô tả sản phẩm',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: const Text('Create Product'),
                ),
                if (_lastSuccessResponse != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Last response (success):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastSuccessResponse.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            if (_isSubmitting) ...[
              const ModalBarrier(dismissible: false, color: Colors.black45),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog for NFC write operation with status feedback
class _NfcWriteDialog extends StatefulWidget {
  final String nfcUrl;

  const _NfcWriteDialog({required this.nfcUrl});

  @override
  State<_NfcWriteDialog> createState() => _NfcWriteDialogState();
}

class _NfcWriteDialogState extends State<_NfcWriteDialog> {
  String _status = 'Đưa thiết bị lại gần thẻ NFC...';
  bool _isWriting = true;
  bool _writeSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startNfcWrite();
  }

  @override
  void dispose() {
    // Cancel NFC session if dialog is dismissed
    if (_isWriting) {
      NfcService.cancelSession();
    }
    super.dispose();
  }

  Future<void> _startNfcWrite() async {
    try {
      await NfcService.writeUrlToTag(
        widget.nfcUrl,
        onStatusUpdate: (message) {
          if (mounted) {
            setState(() => _status = message);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isWriting = false;
        _writeSuccess = true;
        _status = 'Ghi NFC thành công!';
      });

      // Auto-close after success
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWriting = false;
        _writeSuccess = false;
        _errorMessage = e.toString();
        _status = 'Ghi NFC thất bại';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isWriting = true;
      _writeSuccess = false;
      _errorMessage = null;
      _status = 'Đưa thiết bị lại gần thẻ NFC...';
    });
    await _startNfcWrite();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _writeSuccess 
                ? Icons.check_circle 
                : (_errorMessage != null ? Icons.error : Icons.nfc),
            color: _writeSuccess 
                ? Colors.green 
                : (_errorMessage != null ? Colors.red : Colors.blue),
          ),
          const SizedBox(width: 8),
          const Text('Ghi NFC'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isWriting) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _writeSuccess 
                  ? Colors.green 
                  : (_errorMessage != null ? Colors.red : null),
              fontWeight: _writeSuccess || _errorMessage != null 
                  ? FontWeight.w600 
                  : null,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'URL: ${widget.nfcUrl}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (_errorMessage != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _retry,
            child: const Text('Thử lại'),
          ),
        ] else if (_isWriting) ...[
          TextButton(
            onPressed: () {
              NfcService.cancelSession();
              Navigator.of(context).pop(false);
            },
            child: const Text('Hủy'),
          ),
        ],
      ],
    );
  }
}
