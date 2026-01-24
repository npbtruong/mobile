import 'package:flutter/material.dart';

class CreateProductPage extends StatelessWidget {
  const CreateProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
        ),
        title: const Text('Tạo sản phẩm'),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'CreateProductPage (đang phát triển)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
