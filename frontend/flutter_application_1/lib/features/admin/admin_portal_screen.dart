import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../models/product_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/loading_widget.dart' as loading_widgets;

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCollection = 'products';
  bool _isLoading = true;
  bool _isScrapeRunning = false;
  String? _error;
  String _scrapeStatus = 'Scraper idle';
  final List<Map<String, dynamic>> _scrapeHistory = [];

  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _collections = [];
  List<ProductModel> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({String? query}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getOverview(),
        _adminService.getCollections(),
        _adminService.getProducts(
          collection: _selectedCollection,
          query: query,
          limit: 250,
        ),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _collections = results[1] as List<Map<String, dynamic>>;
        _products = results[2] as List<ProductModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runScrape({required String mode, required String label}) async {
    if (_isScrapeRunning) return;

    setState(() {
      _isScrapeRunning = true;
      _scrapeStatus = 'Verifying Firestore...';
    });

    try {
      await _adminService.verifyFirestoreConnection();
      setState(() {
        _scrapeStatus = 'Running $label...';
      });

      final response = await _adminService.runScraper(mode: mode);
      final saved = response['saved'] ?? 0;
      final updated = response['updated'] ?? 0;
      setState(() {
        _scrapeStatus = '$label done. Saved: $saved, Updated: $updated';
        _scrapeHistory.insert(0, {
          'label': label,
          'mode': mode,
          'saved': saved,
          'updated': updated,
          'status': 'success',
          'time': DateTime.now(),
        });
        if (_scrapeHistory.length > 8) {
          _scrapeHistory.removeLast();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scrapeStatus)),
        );
      }

      await _loadData(query: _searchController.text);
    } catch (e) {
      setState(() {
        _scrapeStatus = 'Scrape failed: $e';
        _scrapeHistory.insert(0, {
          'label': label,
          'mode': mode,
          'saved': 0,
          'updated': 0,
          'status': 'failed',
          'time': DateTime.now(),
        });
        if (_scrapeHistory.length > 8) {
          _scrapeHistory.removeLast();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scrapeStatus)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScrapeRunning = false;
        });
      }
    }
  }

  void _openProductEditor({ProductModel? product}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProductEditorSheet(
          product: product,
          collection: _selectedCollection,
          availableCollections:
              _collections.map((c) => c['name'].toString()).toList(),
        );
      },
    );

    if (result != null && mounted) {
      await _saveProduct(result, product);
    }
  }

  Future<void> _saveProduct(
      Map<String, dynamic> data, ProductModel? existingProduct) async {
    try {
      if (existingProduct == null) {
        await _adminService.createProduct(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product created successfully')),
          );
        }
      } else {
        final collection = data['collection'] ?? _selectedCollection;
        await _adminService.updateProduct(collection, existingProduct.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully')),
          );
        }
      }
      await _loadData(query: _searchController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _adminService.deleteProduct(product.collection, product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
        await _loadData(query: _searchController.text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF052A44), Color(0xFF0D3A58), Color(0xFF146C94)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                onBack: () => Navigator.pop(context),
                onRefresh: () => _loadData(query: _searchController.text),
                onAddProduct: () => _openProductEditor(),
              ),
              if (_isLoading)
                const Expanded(
                  child: loading_widgets.LoadingWidget(
                    message: 'Loading Firestore data...',
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: loading_widgets.ErrorWidget(
                    message: _error!,
                    onRetry: _loadData,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      _OverviewCards(overview: _overview),
                      _ScrapePanel(
                        isRunning: _isScrapeRunning,
                        status: _scrapeStatus,
                        onPhones: () =>
                            _runScrape(mode: 'phones', label: 'Scrape Phones'),
                        onLaptops: () => _runScrape(
                            mode: 'laptops', label: 'Scrape Laptops'),
                        onAll: () =>
                            _runScrape(mode: 'all', label: 'Scrape All'),
                        onNewPhones: () => _runScrape(
                            mode: 'new_phones', label: 'Scrape New Phones'),
                        onNewLaptops: () => _runScrape(
                            mode: 'new_laptops', label: 'Scrape New Laptops'),
                      ),
                      _ScrapeHistoryCard(history: _scrapeHistory),
                      _FilterRow(
                        selectedCollection: _selectedCollection,
                        collections: _collections,
                        searchController: _searchController,
                        onCollectionChanged: (value) {
                          setState(() => _selectedCollection = value);
                          _loadData(query: _searchController.text);
                        },
                        onSearch: () =>
                            _loadData(query: _searchController.text),
                      ),
                      Expanded(
                        child: _ProductTable(
                          products: _products,
                          onEdit: (product) => _openProductEditor(product: product),
                          onDelete: _deleteProduct,
                        ),
                      ),
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

class _ScrapePanel extends StatelessWidget {
  final bool isRunning;
  final String status;
  final VoidCallback onPhones;
  final VoidCallback onLaptops;
  final VoidCallback onAll;
  final VoidCallback onNewPhones;
  final VoidCallback onNewLaptops;

  const _ScrapePanel({
    required this.isRunning,
    required this.status,
    required this.onPhones,
    required this.onLaptops,
    required this.onAll,
    required this.onNewPhones,
    required this.onNewLaptops,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Developer Scraper Controls',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ScrapeButton(
                        label: 'Scrape Phones',
                        onTap: onPhones,
                        enabled: !isRunning),
                    _ScrapeButton(
                        label: 'Scrape Laptops',
                        onTap: onLaptops,
                        enabled: !isRunning),
                    _ScrapeButton(
                        label: 'Scrape All', onTap: onAll, enabled: !isRunning),
                    _ScrapeButton(
                        label: 'Scrape New Phones',
                        onTap: onNewPhones,
                        enabled: !isRunning),
                    _ScrapeButton(
                        label: 'Scrape New Laptops',
                        onTap: onNewLaptops,
                        enabled: !isRunning),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isRunning)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    if (isRunning) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrapeHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _ScrapeHistoryCard({required this.history});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Scrape Runs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  Text(
                    'No runs yet. Use any scrape button to start.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                  )
                else
                  ...history.map((item) {
                    final status = (item['status'] ?? '').toString();
                    final statusColor = status == 'success'
                        ? const Color(0xFF91F2B3)
                        : const Color(0xFFFFB3B3);
                    final dt = item['time'] is DateTime
                        ? item['time'] as DateTime
                        : DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['label']}  •  Saved ${item['saved']}  •  Updated ${item['updated']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(dt),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrapeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _ScrapeButton(
      {required this.label, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D3A58),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onAddProduct;

  const _Header({
    required this.onBack,
    required this.onRefresh,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Admin Portal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          _GlassIconButton(icon: Icons.add, onTap: onAddProduct),
          const SizedBox(width: 8),
          _GlassIconButton(icon: Icons.refresh, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final Map<String, dynamic> overview;

  const _OverviewCards({required this.overview});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Total', overview['total'] ?? 0),
      ('Products', overview['products'] ?? 0),
      ('Phones', overview['phones'] ?? 0),
      ('Laptops', overview['laptops'] ?? 0),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map(
              (entry) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$1,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.$2.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selectedCollection;
  final List<Map<String, dynamic>> collections;
  final TextEditingController searchController;
  final ValueChanged<String> onCollectionChanged;
  final VoidCallback onSearch;

  const _FilterRow({
    required this.selectedCollection,
    required this.collections,
    required this.searchController,
    required this.onCollectionChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final names = collections
        .map((c) => (c['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
    if (!names.contains(selectedCollection) && names.isNotEmpty) {
      onCollectionChanged(names.first);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _GlassInput(
              child: DropdownButtonFormField<String>(
                value: selectedCollection,
                dropdownColor: const Color(0xFF0D3A58),
                decoration: const InputDecoration(border: InputBorder.none),
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                items: names
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onCollectionChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _GlassInput(
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search name, brand, category',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _GlassIconButton(icon: Icons.search, onTap: onSearch),
        ],
      ),
    );
  }
}

class _ProductTable extends StatelessWidget {
  final List<ProductModel> products;
  final Function(ProductModel? product) onEdit;
  final Function(ProductModel product) onDelete;

  const _ProductTable({
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const loading_widgets.EmptyStateWidget(
        title: 'No Products',
        subtitle: 'No rows found for this filter.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withOpacity(0.2)),
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  title: Text(
                    p.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${p.brand} | ${p.category}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rs ${p.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.white, size: 18),
                        onPressed: () => onEdit(p),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                        onPressed: () => onDelete(p),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassInput extends StatelessWidget {
  final Widget child;

  const _GlassInput({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.28)),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ProductEditorSheet extends StatefulWidget {
  final ProductModel? product;
  final String collection;
  final List<String> availableCollections;

  const _ProductEditorSheet({
    required this.product,
    required this.collection,
    required this.availableCollections,
  });

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _imageController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _urlController;
  late TextEditingController _sourceController;
  late TextEditingController _ramController;
  late TextEditingController _storageController;
  late TextEditingController _processorController;
  late TextEditingController _gpuController;
  late TextEditingController _batteryController;
  late TextEditingController _cameraController;
  late String _selectedCollection;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _imageController = TextEditingController(text: p?.image ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _urlController = TextEditingController(text: p?.url ?? '');
    _sourceController = TextEditingController(text: p?.source ?? '');
    _ramController = TextEditingController(text: p?.ram ?? '');
    _storageController = TextEditingController(text: p?.storage ?? '');
    _processorController = TextEditingController(text: p?.processor ?? '');
    _gpuController = TextEditingController(text: p?.gpu ?? '');
    _batteryController = TextEditingController(text: p?.battery ?? '');
    _cameraController = TextEditingController(text: p?.camera ?? '');
    _selectedCollection = p?.collection ?? widget.collection;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _sourceController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    _processorController.dispose();
    _gpuController.dispose();
    _batteryController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _submit() {
    final data = {
      'collection': _selectedCollection,
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'image': _imageController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'url': _urlController.text.trim(),
      'source': _sourceController.text.trim(),
      'ram': _ramController.text.trim(),
      'storage': _storageController.text.trim(),
      'processor': _processorController.text.trim(),
      'gpu': _gpuController.text.trim(),
      'battery': _batteryController.text.trim(),
      'camera': _cameraController.text.trim(),
    };
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF052A44),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Product Editor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _buildTextField('Collection', _selectedCollection, (value) {
                      _selectedCollection = value;
                    },
                        isDropdown: true,
                        dropdownValues: widget.availableCollections),
                    _buildTextField('Name *', _nameController.text,
                        (v) => _nameController.text = v),
                    _buildTextField('Brand *', _brandController.text,
                        (v) => _brandController.text = v),
                    _buildTextField('Price', _priceController.text,
                        (v) => _priceController.text = v,
                        keyboardType: TextInputType.number),
                    _buildTextField('Image URL', _imageController.text,
                        (v) => _imageController.text = v),
                    if (_imageController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageController.text,
                            height: 100,
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                              WebHtmlElementStrategy.prefer,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey,
                              child: const Center(
                                child: Text('Image not found',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    _buildTextField('Category', _categoryController.text,
                        (v) => _categoryController.text = v),
                    _buildTextField('Description', _descriptionController.text,
                        (v) => _descriptionController.text = v,
                        maxLines: 3),
                    _buildTextField('URL', _urlController.text,
                        (v) => _urlController.text = v),
                    _buildTextField('Source', _sourceController.text,
                        (v) => _sourceController.text = v),
                    const Divider(color: Colors.white24),
                    const Text(
                      'Specifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField('RAM', _ramController.text,
                        (v) => _ramController.text = v),
                    _buildTextField('Storage', _storageController.text,
                        (v) => _storageController.text = v),
                    _buildTextField('Processor', _processorController.text,
                        (v) => _processorController.text = v),
                    _buildTextField('GPU', _gpuController.text,
                        (v) => _gpuController.text = v),
                    _buildTextField('Battery', _batteryController.text,
                        (v) => _batteryController.text = v),
                    _buildTextField('Camera', _cameraController.text,
                        (v) => _cameraController.text = v),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                widget.product == null ? 'Create' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    String initialValue,
    ValueChanged<String> onChanged, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isDropdown = false,
    List<String> dropdownValues = const [],
  }) {
    if (isDropdown) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: _selectedCollection,
          dropdownColor: const Color(0xFF0D3A58),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          items: dropdownValues
              .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCollection = value);
            }
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
