import 'package:flutter/material.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';

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

      final nfcUrl = data['nfc_url']?.toString();
      final nfcInstructions = data['nfc_instructions']?.toString();
      if ((nfcUrl != null && nfcUrl.isNotEmpty) ||
          (nfcInstructions != null && nfcInstructions.isNotEmpty)) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('NFC'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nfcUrl != null && nfcUrl.isNotEmpty) ...[
                    const Text('nfc_url:'),
                    SelectableText(nfcUrl),
                    const SizedBox(height: 12),
                  ],
                  if (nfcInstructions != null && nfcInstructions.isNotEmpty) ...[
                    const Text('nfc_instructions:'),
                    Text(nfcInstructions),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      }
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
