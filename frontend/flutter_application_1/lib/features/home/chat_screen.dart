import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/chat_message_model.dart';
import '../../models/product_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/glassy_shine.dart';
import '../products/product_list_screen.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const ChatScreen({super.key, this.onBackPressed});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  List<ProductModel>? _recommendedProducts;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // Add initial greeting
    setState(() {
      _messages = [
        ChatMessageModel(
          message:
              'Hello! 👋 I\'m your AI product assistant. Tell me what you\'re looking for in a smartphone, and I\'ll recommend the best options for you!',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(
        ChatMessageModel(
          message: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      // Call chat service
      final response = await _chatService.sendMessage(message);
      final botReply = response['reply'] as String;
      final products = response['products'] as List<ProductModel>;

      // Add bot message
      setState(() {
        _messages.add(
          ChatMessageModel(
            message: botReply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _recommendedProducts = products;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      // Error handling
      setState(() {
        _messages.add(
          ChatMessageModel(
            message: 'Sorry, something went wrong. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToProducts() {
    if (_recommendedProducts != null && _recommendedProducts!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductListScreen(
            initialProducts: _recommendedProducts,
            title: 'Recommended Products',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF93C5FD)];

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final maxWidth = isDesktop ? 800.0 : double.infinity;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 30.0 : 20.0);
    final titleFontSize = isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 16, horizontalPadding, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (widget.onBackPressed != null) {
                                  widget.onBackPressed!();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const _GlassIconButton(
                                icon: Icons.arrow_back_rounded,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'AI Product Assistant',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: titleFontSize,
                                      ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _initializeChat();
                                  _recommendedProducts = null;
                                });
                              },
                              child: const _GlassIconButton(
                                icon: Icons.refresh_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chat Messages and Products in SingleChildScrollView
                      Expanded(
                        child: _GlassSection(
                          margin: EdgeInsets.fromLTRB(
                              horizontalPadding, 8, horizontalPadding, 8),
                          padding: EdgeInsets.symmetric(
                            vertical: isDesktop ? 16 : 12,
                            horizontal: isDesktop ? 20 : 12,
                          ),
                          child: _messages.isEmpty
                              ? const LoadingWidget(message: 'Loading...')
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      // Chat Messages
                                      ...List.generate(
                                        _messages.length,
                                        (index) => ChatBubble(
                                          message: _messages[index],
                                        ),
                                      ),

                                      // Recommended Products Preview
                                      if (_recommendedProducts != null &&
                                          _recommendedProducts!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Recommended Products',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          isDesktop ? 16 : 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        _navigateToProducts,
                                                    child: Text(
                                                      'See All',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize:
                                                            isDesktop ? 14 : 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                  height: isDesktop ? 12 : 8),
                                              SizedBox(
                                                height: isDesktop
                                                    ? 200
                                                    : (isTablet ? 180 : 160),
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount:
                                                      _recommendedProducts!
                                                          .length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final product =
                                                        _recommendedProducts![
                                                            index];
                                                    return GestureDetector(
                                                      onTap: () {
                                                        Navigator.of(context)
                                                            .push(
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                ProductListScreen(
                                                              initialProducts:
                                                                  _recommendedProducts,
                                                              title:
                                                                  'Recommended Products',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: _GlassProductCard(
                                                        product: product,
                                                        isDesktop: isDesktop,
                                                        isTablet: isTablet,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                  height: isDesktop ? 16 : 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(
                                                        sigmaX: 10, sigmaY: 10),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: TextButton.icon(
                                                        onPressed:
                                                            _navigateToProducts,
                                                        icon: Icon(
                                                          Icons
                                                              .shopping_bag_outlined,
                                                          color: Colors.white,
                                                          size: isDesktop
                                                              ? 22
                                                              : 20,
                                                        ),
                                                        label: Text(
                                                          'View All Recommendations',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: isDesktop
                                                                ? 16
                                                                : 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ),

                      // Loading Indicator
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LoadingWidget(message: 'AI is thinking...'),
                        ),

                      // Input Area
                      _GlassSection(
                        margin: EdgeInsets.fromLTRB(
                            horizontalPadding, 0, horizontalPadding, 20),
                        padding: EdgeInsets.all(isDesktop ? 20 : 16),
                        child: Column(
                          children: [
                            if (_messages.length == 1)
                              Column(
                                children: [
                                  Text(
                                    'Try asking about:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: isDesktop ? 12 : 8),
                                  Wrap(
                                    spacing: isDesktop ? 12 : 8,
                                    runSpacing: isDesktop ? 12 : 8,
                                    children: [
                                      _GlassQuickActionButton(
                                        label: 'Budget phones',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Show me budget smartphones';
                                          _sendMessage();
                                        },
                                      ),
                                      _GlassQuickActionButton(
                                        label: 'Flagship phones',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Best flagship phones';
                                          _sendMessage();
                                        },
                                      ),
                                      _GlassQuickActionButton(
                                        label: 'Gaming phones',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Best phones for gaming';
                                          _sendMessage();
                                        },
                                      ),
                                      _GlassQuickActionButton(
                                        label: 'Camera phones',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Phones with great cameras';
                                          _sendMessage();
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isDesktop ? 16 : 12),
                                  Divider(color: Colors.white.withOpacity(0.2)),
                                  SizedBox(height: isDesktop ? 16 : 12),
                                ],
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    enabled: !_isLoading,
                                    style: TextStyle(
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      fontSize: isDesktop ? 16 : 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Describe what you\'re looking for...',
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.black.withOpacity(0.5),
                                        fontSize: isDesktop ? 16 : 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.25),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.25),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 24 : 20,
                                        vertical: isDesktop ? 16 : 12,
                                      ),
                                    ),
                                    maxLines: null,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 12 : 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed:
                                            _isLoading ? null : _sendMessage,
                                        icon: Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: isDesktop ? 24 : 20,
                                        ),
                                        padding:
                                            EdgeInsets.all(isDesktop ? 14 : 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const GlassyShine(opacity: 0.1),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _GlassQuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDesktop;

  const _GlassQuickActionButton({
    required this.label,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const _GlassSection({
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;

  const _GlassIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _GlassProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isDesktop;
  final bool isTablet;

  const _GlassProductCard({
    required this.product,
    this.isDesktop = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = isDesktop ? 180.0 : (isTablet ? 160.0 : 140.0);

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: isDesktop ? 16 : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: product.image.isEmpty
                      ? Container(color: Colors.white.withOpacity(0.1))
                      : product.image.startsWith('http')
                          ? Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.white.withOpacity(0.1),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withOpacity(0.1),
                                );
                              },
                            )
                          : Image.asset(
                              product.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withOpacity(0.1),
                                );
                              },
                            ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                    padding: EdgeInsets.all(isDesktop ? 10 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 13 : 12,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 3 : 2),
                        Text(
                          'PKR ${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isDesktop ? 11 : 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
