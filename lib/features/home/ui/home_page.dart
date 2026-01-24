import 'package:flutter/material.dart';
import '../../../app.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../product/ui/create_product_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  final List<_ProductItem> _products = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 0;
  int _lastPage = 1;
  String? _nextPageUrl;
  int? _totalItems;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = InheritedAuthController.of(context);
    _apiService.onUnauthorized = () {
      authController.logout();
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? get _nextPageFromApi {
    final url = _nextPageUrl;
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final pageStr = uri.queryParameters['page'];
      return int.tryParse(pageStr ?? '');
    } catch (_) {
      return null;
    }
  }

  bool get _hasMorePages {
    // Prefer API-provided next_page_url.
    if ((_nextPageUrl?.isNotEmpty ?? false) && _nextPageFromApi != null) {
      return true;
    }

    // Fallback to page counters if API omits next_page_url.
    return _currentPage < _lastPage;
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _fetchProductsPage(1);
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(result.items);
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
        _nextPageUrl = result.nextPageUrl;
        _totalItems = result.totalItems;
        _isInitialLoading = false;
      });

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadNextPageIfAvailable() async {
    if (_isInitialLoading || _isLoadingMore) return;
    if (!_hasMorePages) return;

    final nextPage = _nextPageFromApi ?? (_currentPage + 1);
    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final result = await _fetchProductsPage(nextPage);
      if (!mounted) return;
      setState(() {
        _products.addAll(result.items);
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
        _nextPageUrl = result.nextPageUrl;
        _totalItems = result.totalItems;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<_ProductsPageResult> _fetchProductsPage(int page) async {
    final response = await _apiService.get('products?page=$page');

    final currentPage = (response['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (response['last_page'] as num?)?.toInt() ?? currentPage;
    final nextPageUrl = response['next_page_url'] as String?;
    final totalItems = (response['total'] as num?)?.toInt();

    final rawItems = (response['data'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(_ProductItem.fromJson)
        .toList();

    return _ProductsPageResult(
      currentPage: currentPage,
      lastPage: lastPage,
      nextPageUrl: nextPageUrl,
      totalItems: totalItems,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = InheritedAuthController.of(context);
    final user = authController.user;

    final showBottomLoader = _isLoadingMore;
    final hasMore = _hasMorePages;
    final hasNoMoreData = !_isInitialLoading && !_isLoadingMore && !hasMore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authController.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Tên', value: user['name'] ?? '-'),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Email', value: user['email'] ?? '-'),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateProductPage(),
                                ),
                              );
                              if (!context.mounted) return;
                              await _loadFirstPage();
                            },
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('Upload'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!_isInitialLoading && _errorMessage == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đang hiển thị ${_products.length}/${_totalItems ?? '-'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      'Trang $_currentPage/$_lastPage',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _ErrorState(
                      message: _errorMessage!,
                      onRetry: _loadFirstPage,
                    )
                  : _products.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadFirstPage,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _products.length + 1,
                        itemBuilder: (context, index) {
                          if (index < _products.length) {
                            return _ProductTile(item: _products[index]);
                          }

                          if (showBottomLoader) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (hasMore) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _loadNextPageIfAvailable,
                                  child: const Text('Tải thêm'),
                                ),
                              ),
                            );
                          }

                          if (hasNoMoreData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('Không còn dữ liệu')),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsPageResult {
  final int currentPage;
  final int lastPage;
  final String? nextPageUrl;
  final int? totalItems;
  final List<_ProductItem> items;

  const _ProductsPageResult({
    required this.currentPage,
    required this.lastPage,
    required this.nextPageUrl,
    required this.totalItems,
    required this.items,
  });
}

class _ProductItem {
  final int id;
  final String tagId;
  final String imageUrl;
  final String description;

  const _ProductItem({
    required this.id,
    required this.tagId,
    required this.imageUrl,
    required this.description,
  });

  factory _ProductItem.fromJson(Map<String, dynamic> json) {
    return _ProductItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tagId: (json['tag_id'] as String?) ?? '-',
      imageUrl: (json['image_url'] as String?) ?? '',
      description: (json['describe'] as String?) ?? '-',
    );
  }

  String get fullImageUrl {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return '${ApiConstants.host}$imageUrl';
  }
}

class _ProductTile extends StatelessWidget {
  final _ProductItem item;

  const _ProductTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey.shade200,
                  child: item.fullImageUrl.isEmpty
                      ? const Icon(Icons.image_not_supported)
                      : Image.network(
                          item.fullImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image);
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Tag: ${item.tagId}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('Không có sản phẩm'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
