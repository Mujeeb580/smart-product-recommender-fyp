import 'dart:ui';

import 'package:flutter/material.dart';

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
                        onPhones: () => _runScrape(mode: 'phones', label: 'Scrape Phones'),
                        onLaptops: () => _runScrape(mode: 'laptops', label: 'Scrape Laptops'),
                        onAll: () => _runScrape(mode: 'all', label: 'Scrape All'),
                        onNewPhones: () => _runScrape(mode: 'new_phones', label: 'Scrape New Phones'),
                        onNewLaptops: () => _runScrape(mode: 'new_laptops', label: 'Scrape New Laptops'),
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
                        onSearch: () => _loadData(query: _searchController.text),
                      ),
                      Expanded(
                        child: _ProductTable(products: _products),
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
                    _ScrapeButton(label: 'Scrape Phones', onTap: onPhones, enabled: !isRunning),
                    _ScrapeButton(label: 'Scrape Laptops', onTap: onLaptops, enabled: !isRunning),
                    _ScrapeButton(label: 'Scrape All', onTap: onAll, enabled: !isRunning),
                    _ScrapeButton(label: 'Scrape New Phones', onTap: onNewPhones, enabled: !isRunning),
                    _ScrapeButton(label: 'Scrape New Laptops', onTap: onNewLaptops, enabled: !isRunning),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isRunning)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    if (isRunning) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  )
                else
                  ...history.map((item) {
                    final status = (item['status'] ?? '').toString();
                    final statusColor = status == 'success' ? const Color(0xFF91F2B3) : const Color(0xFFFFB3B3);
                    final dt = item['time'] is DateTime ? item['time'] as DateTime : DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['label']}  •  Saved ${item['saved']}  •  Updated ${item['updated']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(dt),
                            style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
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

  const _ScrapeButton({required this.label, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D3A58),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  const _Header({required this.onBack, required this.onRefresh});

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
                    .map((name) => DropdownMenuItem(value: name, child: Text(name)))
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

  const _ProductTable({required this.products});

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
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.2)),
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  title: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${p.brand} | ${p.category}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                  trailing: Text(
                    'Rs ${p.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
