import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../models/product_model.dart';
import '../../services/admin_service.dart';

enum _AdminView { products, users }

class AdminPortalScreen extends StatefulWidget {
  final AdminService? adminService;

  const AdminPortalScreen({super.key, this.adminService});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  late final AdminService _adminService;
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
  List<Map<String, dynamic>> _users = [];
  _AdminView _selectedView = _AdminView.products;

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? AdminService();
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
        _adminService.getUsers(),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _collections = results[1] as List<Map<String, dynamic>>;
        _products = results[2] as List<ProductModel>;
        _users = results[3] as List<Map<String, dynamic>>;
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
      final errors = response['errors'] ?? 0;
      setState(() {
        _scrapeStatus =
            '$label done. Saved: $saved, Updated: $updated, Errors: $errors';
        _scrapeHistory.insert(0, {
          'label': label,
          'mode': mode,
          'saved': saved,
          'updated': updated,
          'errors': errors,
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
        final sourceCollection =
            existingProduct.collection ?? _selectedCollection;
        await _adminService.updateProduct(
            sourceCollection, existingProduct.id, data);
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

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final uid = user['uid']?.toString() ?? '';
    final email = user['email']?.toString() ?? 'this user';
    if (uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
          'Permanently delete $email? This user will no longer be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _adminService.deleteUser(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email deleted')),
      );
      await _loadData(query: _searchController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete user: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _adminService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
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
                onLogout: _logout,
                onRefresh: () => _loadData(query: _searchController.text),
                onAddProduct: _selectedView == _AdminView.products
                    ? () => _openProductEditor()
                    : null,
              ),
              if (_isLoading)
                const Expanded(
                  child: _AdminStatusState(
                    message: 'Loading Firestore data...',
                    isLoading: true,
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: _AdminStatusState(
                    message: _error!,
                    onRetry: _loadData,
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showingProducts =
                          _selectedView == _AdminView.products;
                      final preferredHeight = showingProducts ? 330.0 : 145.0;
                      final compactHeight = constraints.maxHeight *
                          (showingProducts ? 0.62 : 0.35);
                      final controlsHeight =
                          constraints.maxHeight < preferredHeight + 180
                              ? compactHeight
                              : preferredHeight;

                      return Column(
                        children: [
                          SizedBox(
                            height: controlsHeight,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _OverviewCards(overview: _overview),
                                  _AdminViewSelector(
                                    selected: _selectedView,
                                    onChanged: (view) =>
                                        setState(() => _selectedView = view),
                                  ),
                                  if (showingProducts) ...[
                                    _ScrapePanel(
                                      isRunning: _isScrapeRunning,
                                      status: _scrapeStatus,
                                      onPhones: () => _runScrape(
                                          mode: 'phones',
                                          label: 'Scrape Phones'),
                                      onLaptops: () => _runScrape(
                                          mode: 'laptops',
                                          label: 'Scrape Laptops'),
                                      onAll: () => _runScrape(
                                          mode: 'all', label: 'Scrape All'),
                                      onNewPhones: () => _runScrape(
                                          mode: 'new_phones',
                                          label: 'Scrape New Phones'),
                                      onNewLaptops: () => _runScrape(
                                          mode: 'new_laptops',
                                          label: 'Scrape New Laptops'),
                                    ),
                                    _ScrapeHistoryCard(
                                      history: _scrapeHistory,
                                    ),
                                    _FilterRow(
                                      selectedCollection: _selectedCollection,
                                      collections: _collections,
                                      searchController: _searchController,
                                      onCollectionChanged: (value) {
                                        setState(
                                          () => _selectedCollection = value,
                                        );
                                        _loadData(
                                          query: _searchController.text,
                                        );
                                      },
                                      onSearch: () => _loadData(
                                        query: _searchController.text,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: showingProducts
                                ? _ProductTable(
                                    products: _products,
                                    onEdit: (product) => _openProductEditor(
                                      product: product,
                                    ),
                                    onDelete: _deleteProduct,
                                  )
                                : _UserTable(
                                    users: _users,
                                    onDelete: _deleteUser,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatusState extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onRetry;

  const _AdminStatusState({
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
    this.isLoading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 8 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 48
                  ? constraints.maxWidth - (compact ? 16 : 48)
                  : 0,
              minHeight: constraints.maxHeight > (compact ? 16 : 48)
                  ? constraints.maxHeight - (compact ? 16 : 48)
                  : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: compact ? 28 : 38,
                    height: compact ? 28 : 38,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: compact ? 34 : 58,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                SizedBox(height: compact ? 6 : 14),
                if (title != null) ...[
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 15 : 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 7),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: compact ? 12 : 14,
                  ),
                ),
                if (onRetry != null) ...[
                  SizedBox(height: compact ? 6 : 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ScrapeButton(
                          label: 'Scrape Phones',
                          onTap: onPhones,
                          enabled: !isRunning),
                      const SizedBox(width: 8),
                      _ScrapeButton(
                          label: 'Scrape Laptops',
                          onTap: onLaptops,
                          enabled: !isRunning),
                      const SizedBox(width: 8),
                      _ScrapeButton(
                          label: 'Scrape All',
                          onTap: onAll,
                          enabled: !isRunning),
                      const SizedBox(width: 8),
                      _ScrapeButton(
                          label: 'Scrape New Phones',
                          onTap: onNewPhones,
                          enabled: !isRunning),
                      const SizedBox(width: 8),
                      _ScrapeButton(
                          label: 'Scrape New Laptops',
                          onTap: onNewLaptops,
                          enabled: !isRunning),
                    ],
                  ),
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
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12),
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
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12),
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
                              '${item['label']}  •  Saved ${item['saved']}  •  Updated ${item['updated']}  •  Errors ${item['errors'] ?? 0}',
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
                                color: Colors.white.withValues(alpha: 0.82),
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
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final VoidCallback? onAddProduct;

  const _Header({
    required this.onLogout,
    required this.onRefresh,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.logout, onTap: onLogout),
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
          if (onAddProduct != null) ...[
            _GlassIconButton(icon: Icons.add, onTap: onAddProduct!),
            const SizedBox(width: 8),
          ],
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
      ('Users', overview['users'] ?? 0),
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = cards[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 132,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.$1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
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
          );
        },
      ),
    );
  }
}

class _AdminViewSelector extends StatelessWidget {
  final _AdminView selected;
  final ValueChanged<_AdminView> onChanged;

  const _AdminViewSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<_AdminView>(
        segments: const [
          ButtonSegment(
            value: _AdminView.products,
            icon: Icon(Icons.inventory_2_outlined),
            label: Text('Products'),
          ),
          ButtonSegment(
            value: _AdminView.users,
            icon: Icon(Icons.people_outline),
            label: Text('Users'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF052A44)
                : Colors.white,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
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
                key: ValueKey(selectedCollection),
                initialValue: selectedCollection,
                dropdownColor: const Color(0xFF0D3A58),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Color(0xFF123F5B),
                ),
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                items: names
                    .map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: const Color(0xFF123F5B),
                  hintText: 'Search name, brand, category',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                  prefixIconColor: Colors.white,
                ),
                cursorColor: Colors.white,
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
      return const _AdminStatusState(
        title: 'No Products',
        message: 'No rows found for this filter.',
        icon: Icons.inventory_2_outlined,
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
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withValues(alpha: 0.24)),
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
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

class _UserTable extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _UserTable({required this.users, required this.onDelete});

  String _dateLabel(dynamic milliseconds) {
    final value = milliseconds is num
        ? milliseconds.toInt()
        : int.tryParse(milliseconds?.toString() ?? '');
    if (value == null) return 'Unknown date';
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _AdminStatusState(
        title: 'No Users',
        message: 'No Firebase Authentication users were found.',
        icon: Icons.people_outline,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.white.withValues(alpha: 0.18)),
            itemBuilder: (context, index) {
              final user = users[index];
              final email = user['email']?.toString() ?? '';
              final name = user['display_name']?.toString() ?? '';
              final disabled = user['disabled'] == true;
              final providers = (user['providers'] as List?)
                      ?.map((provider) => provider.toString())
                      .join(', ') ??
                  'password';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: disabled
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.18),
                  child: Icon(
                    disabled ? Icons.person_off : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  name.isNotEmpty ? name : (email.isNotEmpty ? email : 'User'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${name.isNotEmpty ? '$email | ' : ''}$providers | Joined ${_dateLabel(user['created_at'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                trailing: IconButton(
                  tooltip: 'Delete user',
                  onPressed: () => onDelete(user),
                  icon:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                ),
              );
            },
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
            color: const Color(0xFF123F5B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
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
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
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
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
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
                    _buildTextField('Collection', null,
                        isDropdown: true,
                        dropdownValues: widget.availableCollections),
                    _buildTextField('Name *', _nameController),
                    _buildTextField('Brand *', _brandController),
                    _buildTextField('Price', _priceController,
                        keyboardType: TextInputType.number),
                    _buildTextField(
                      'Image URL',
                      _imageController,
                      onChanged: () => setState(() {}),
                    ),
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
                    _buildTextField('Category', _categoryController),
                    _buildTextField('Description', _descriptionController,
                        maxLines: 3),
                    _buildTextField('URL', _urlController),
                    _buildTextField('Source', _sourceController),
                    const Divider(color: Colors.white24),
                    const Text(
                      'Specifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField('RAM', _ramController),
                    _buildTextField('Storage', _storageController),
                    _buildTextField('Processor', _processorController),
                    _buildTextField('GPU', _gpuController),
                    _buildTextField('Battery', _batteryController),
                    _buildTextField('Camera', _cameraController),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.product == null ? 'Create' : 'Update',
                        ),
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
    TextEditingController? controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isDropdown = false,
    List<String> dropdownValues = const [],
    VoidCallback? onChanged,
  }) {
    if (isDropdown) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: ValueKey(_selectedCollection),
          initialValue: _selectedCollection,
          dropdownColor: const Color(0xFF0D3A58),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.35),
              ),
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
        controller: controller,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
          ),
          filled: true,
          fillColor: const Color(0xFF0D3A58),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.35),
            ),
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
