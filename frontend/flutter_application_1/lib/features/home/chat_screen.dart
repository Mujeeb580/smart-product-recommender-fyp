import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../models/chat_message_model.dart';
import '../../models/product_model.dart';
import '../../core/price_formatter.dart';
import '../../services/chat_service.dart';
import '../../services/theme_provider.dart';
import '../../services/recommendation_preferences_service.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final RecommendationPreferencesService _preferencesService =
      RecommendationPreferencesService();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  List<ProductModel>? _recommendedProducts;
  String? _lastSentMessage;
  RecommendationPreferences _preferences = const RecommendationPreferences();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final value = await _preferencesService.load();
    if (!mounted) return;
    setState(() => _preferences = value);
  }

  void _initializeChat() {
    _chatService.startNewSession();
    // Add initial greeting
    setState(() {
      _messages = [
        ChatMessageModel(
          message:
              'Hi! 👋 I\'m your AI shopping assistant. Tell me your budget and what matters most, and I\'ll help you find the right phone or laptop.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
      _recommendedProducts = null;
      _lastSentMessage = null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isLoading || _isTranscribing) return;
    if (kIsWeb) {
      _showVoiceMessage(
          'Voice input is currently available in the mobile app.');
      return;
    }

    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _isTranscribing = path != null;
        });
        if (path == null) {
          _showVoiceMessage('No recording was captured. Please try again.');
          return;
        }

        final transcript = await _chatService.transcribeAudio(path);
        if (!mounted) return;
        setState(() {
          _isTranscribing = false;
          _messageController.text = transcript;
        });
        if (_preferences.voiceAutoSend) {
          await _sendMessage();
        } else {
          _showVoiceMessage('Transcript ready. Review it, then tap send.');
        }
        return;
      }

      if (!await _audioRecorder.hasPermission()) {
        _showVoiceMessage('Microphone permission is required for voice input.');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() => _isRecording = true);
      _showVoiceMessage('Listening… Tap the red microphone to stop and send.');
    } catch (e) {
      if (!mounted) return;
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      _showVoiceMessage(e.toString());
    }
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendMessage() async {
    if (_isLoading) return;
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
      // Hide products from the previous answer while this query is pending.
      _recommendedProducts = null;
      _messageController.clear();
      _lastSentMessage = message;
    });

    _scrollToBottom();

    try {
      // Call chat service
      final response = await _chatService.sendMessage(message);
      final botReply = response['reply'] as String;
      final products = response['products'] as List<ProductModel>;

      if (!mounted) return;
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
      if (!mounted) return;
      final errMsg = e.toString();
      // Error handling: show error message and allow retry
      setState(() {
        _messages.add(
          ChatMessageModel(
            message: 'Sorry, something went wrong.\nError: $errMsg',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();

      // Show SnackBar with retry action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errMsg'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (_lastSentMessage != null && _lastSentMessage!.isNotEmpty) {
                _messageController.text = _lastSentMessage!;
                _sendMessage();
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _askAboutProduct(ProductModel product) async {
    if (_isLoading) return;
    final message = 'Tell me about ${product.name}';

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
      // The recommendation area should belong only to the pending answer.
      _recommendedProducts = null;
      _lastSentMessage = message;
    });

    _scrollToBottom();

    try {
      final response =
          await _chatService.sendMessage(message, product: product);
      final botReply = response['reply'] as String;
      final products = response['products'] as List<ProductModel>;

      if (!mounted) return;
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
      if (!mounted) return;
      final errMsg = e.toString();
      setState(() {
        _messages.add(
          ChatMessageModel(
            message: 'Sorry, something went wrong.\nError: $errMsg',
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
    final gradientColors = context.watch<ThemeProvider>().currentGradient;

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final maxWidth = isDesktop ? 980.0 : double.infinity;
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
            Positioned(
              top: -100,
              right: -80,
              child: _AmbientOrb(
                size: isDesktop ? 360 : 250,
                color: const Color(0xFF38BDF8),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -100,
              child: _AmbientOrb(
                size: isDesktop ? 300 : 220,
                color: const Color(0xFF14B8A6),
              ),
            ),
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: isDesktop ? 46 : 40,
                                      height: isDesktop ? 46 : 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFF0E7490),
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'FYNDO Assistant',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: titleFontSize,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF86EFAC),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Online - Phones & laptops',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.78),
                                                  fontSize:
                                                      isDesktop ? 12 : 10.5,
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
                            GestureDetector(
                              onTap: _initializeChat,
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
                                                    return Stack(
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () {
                                                            Navigator.of(
                                                                    context)
                                                                .push(
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        ProductListScreen(
                                                                  initialProducts:
                                                                      _recommendedProducts,
                                                                  title:
                                                                      'Recommended Products',
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          child:
                                                              _GlassProductCard(
                                                            product: product,
                                                            isDesktop:
                                                                isDesktop,
                                                            isTablet: isTablet,
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 6,
                                                          right: 6,
                                                          child: ClipOval(
                                                            child: Material(
                                                              color: Colors
                                                                  .black38,
                                                              child: InkWell(
                                                                onTap: () =>
                                                                    _askAboutProduct(
                                                                        product),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          6.0),
                                                                  child: Icon(
                                                                    Icons
                                                                        .question_mark_rounded,
                                                                    color: Colors
                                                                        .white,
                                                                    size:
                                                                        isDesktop
                                                                            ? 18
                                                                            : 16,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                          child: _ThinkingIndicator(),
                        ),

                      // Input Area
                      _GlassSection(
                        margin: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          widget.onBackPressed != null ? 92 : 20,
                        ),
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
                                        label: 'Best value',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Show me the best value phone or laptop under my budget';
                                          _sendMessage();
                                        },
                                      ),
                                      if (_preferences.hasRecommendationDetails)
                                        _GlassQuickActionButton(
                                          label: 'Use my preferences',
                                          isDesktop: isDesktop,
                                          onTap: () {
                                            _messageController.text =
                                                _preferences
                                                    .toRecommendationQuery();
                                            _sendMessage();
                                          },
                                        ),
                                      _GlassQuickActionButton(
                                        label: 'Work laptop',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Recommend a reliable laptop for work and study';
                                          _sendMessage();
                                        },
                                      ),
                                      _GlassQuickActionButton(
                                        label: 'Gaming setup',
                                        isDesktop: isDesktop,
                                        onTap: () {
                                          _messageController.text =
                                              'Recommend the best gaming phone or laptop';
                                          _sendMessage();
                                        },
                                      ),
                                      _GlassQuickActionButton(
                                        label: 'Great camera',
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
                                    enabled: !_isLoading &&
                                        !_isRecording &&
                                        !_isTranscribing,
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
                                            ? Colors.white
                                                .withValues(alpha: 0.58)
                                            : const Color(0xFF486581),
                                        fontSize: isDesktop ? 16 : 14,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.white
                                              .withValues(alpha: 0.94),
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
                                          color: Color(0xFF67E8F9),
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 24 : 20,
                                        vertical: isDesktop ? 16 : 12,
                                      ),
                                    ),
                                    cursorColor: isDark
                                        ? Colors.white
                                        : const Color(0xFF0E7490),
                                    maxLines: null,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 12 : 8),
                                if (!kIsWeb) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? const Color(0xFFDC2626)
                                          : Colors.white
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _isRecording
                                            ? const Color(0xFFFCA5A5)
                                            : Colors.white
                                                .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: _isRecording
                                          ? 'Stop and send voice message'
                                          : 'Start voice input',
                                      onPressed: (_isLoading || _isTranscribing)
                                          ? null
                                          : _toggleVoiceInput,
                                      icon: _isTranscribing
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              _isRecording
                                                  ? Icons.stop_rounded
                                                  : Icons.mic_rounded,
                                              color: Colors.white,
                                              size: isDesktop ? 24 : 20,
                                            ),
                                      padding: EdgeInsets.all(
                                        isDesktop ? 14 : 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isDesktop ? 12 : 8),
                                ],
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF14B8A6),
                                            Color(0xFF0284C7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: (_isLoading ||
                                                _isRecording ||
                                                _isTranscribing)
                                            ? null
                                            : _sendMessage,
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
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF67E8F9),
            ),
          ),
          SizedBox(width: 9),
          Text(
            'Finding the best matches...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.prefer,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
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
                          formatPkr(product.price),
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
