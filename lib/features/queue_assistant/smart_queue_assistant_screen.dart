import 'dart:ui';

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/glass.dart';
import '../queue/queue_provider.dart';

class SmartQueueAssistantScreen extends StatefulWidget {
  const SmartQueueAssistantScreen({required this.provider, super.key});
  final QueueProvider provider;

  @override
  State<SmartQueueAssistantScreen> createState() => _SmartQueueAssistantScreenState();
}

class _SmartQueueAssistantScreenState extends State<SmartQueueAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  late final Map<String, List<({String sender, String text})>> _messagesByLang;
  bool _sending = false;
  String _selectedLanguage = 'en'; // 'en', 'ta', 'si'

  String _getWelcomeMessage(String lang) {
    if (lang == 'ta') {
      return 'வணக்கம்! 👋 நான் உங்கள் SmartOPD உதவியாளர். உங்கள் நேரடி டோக்கன், காத்திருப்பு நேரம் அல்லது மருத்துவர் பற்றி எதையும் கேளுங்கள்.';
    } else if (lang == 'si') {
      return 'ආයුබෝවන්! 👋 මම ඔබේ SmartOPD සහායකයා. ඔබේ ටෝකන් අංකය, බලා සිටින වේලාව හෝ පෝලිම ගැන ඕනෑම දෙයක් අසන්න.';
    } else {
      return 'Hello! I am your Smart Queue Assistant. Ask me anything about your current OPD token, queue position, or estimated wait time.';
    }
  }

  List<({String sender, String text})> get _currentMessages =>
      _messagesByLang[_selectedLanguage] ??= [
        (sender: 'assistant', text: _getWelcomeMessage(_selectedLanguage))
      ];

  final Map<String, List<String>> _quickQueriesMap = {
    'en': [
      'What is my token?',
      'How many patients ahead?',
      'What is the current token?',
      'How long do I need to wait?',
      'Is the doctor delayed?',
    ],
    'ta': [
      'எனது டோக்கன் என்ன?',
      'முன்னாடி எத்தனை பேர்?',
      'இப்போது எந்த டோக்கன் போகிறது?',
      'எவ்வளவு நேரம் காத்திருக்க வேண்டும்?',
      'டாக்டர் லேட்டா?',
    ],
    'si': [
      'මගේ ටෝකන් අංකය කුමක්ද?',
      'ඉදිරියෙන් කී දෙනෙක් ඉන්නවද?',
      'දැනට යන ටෝකනය කුමක්ද?',
      'කොපමණ වේලාවක් බලා සිටිය යුතුද?',
      'වෛද්‍යවරයා ප්‍රමාදද?',
    ],
  };

  String get _inputHint {
    switch (_selectedLanguage) {
      case 'ta':
        return 'உங்கள் வரிசை பற்றி கேளுங்கள்...';
      case 'si':
        return 'ඔබේ පෝලිම ගැන අසන්න...';
      default:
        return 'Ask about your queue...';
    }
  }

  void _changeLanguage(String lang) {
    if (_selectedLanguage == lang) return;
    setState(() {
      _selectedLanguage = lang;
    });
    _scrollToBottom();
  }

  @override
  void initState() {
    super.initState();
    _messagesByLang = {
      'en': [(sender: 'assistant', text: _getWelcomeMessage('en'))],
      'ta': [(sender: 'assistant', text: _getWelcomeMessage('ta'))],
      'si': [(sender: 'assistant', text: _getWelcomeMessage('si'))],
    };
  }

  final ScrollController _scrollController = ScrollController();

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (presetText == null) _controller.clear();

    setState(() {
      _currentMessages.add((sender: 'user', text: text));
      _sending = true;
    });

    _scrollToBottom();

    try {
      final reply = await widget.provider.queueService.askQueueAssistant(
        text,
        language: _selectedLanguage,
      );
      setState(() {
        _currentMessages.add((sender: 'assistant', text: reply));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _currentMessages.add((sender: 'assistant', text: 'Error connecting to queue assistant. Please try again.'));
      });
      _scrollToBottom();
    } finally {
      setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.provider.activeQueueData;
    final token = queue?['tokenNumber'] as String? ?? 'N/A';
    final currentQueries = _quickQueriesMap[_selectedLanguage] ?? _quickQueriesMap['en']!;

    return GlassScaffold(
      titleWidget: const Row(
        children: [
          Icon(Icons.smart_toy_rounded, color: AppTheme.teal),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Smart Queue Assistant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navy),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.navy),
          tooltip: 'Reset Chat',
          onPressed: () {
            setState(() {
              _currentMessages.clear();
              _currentMessages.add((sender: 'assistant', text: _getWelcomeMessage(_selectedLanguage)));
            });
          },
        ),
      ],
      body: Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: Column(
          children: [
            // Active Context Header
            GlassHeroSurface(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              radius: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Active Token: $token',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.mint.withValues(alpha: 0.45)),
                    ),
                    child: const Text(
                      'OPD Assistant Only',
                      style: TextStyle(color: AppTheme.mint, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Language Selector Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 16, color: AppTheme.teal),
                  const SizedBox(width: 6),
                  const Text(
                    'Language:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _langChip('en', 'English'),
                          const SizedBox(width: 6),
                          _langChip('ta', 'தமிழ்'),
                          const SizedBox(width: 6),
                          _langChip('si', 'සිංහල'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _currentMessages.length,
                itemBuilder: (context, index) {
                  final m = _currentMessages[index];
                  final isUser = m.sender == 'user';
                  final maxWidth = MediaQuery.of(context).size.width * 0.78;

                  if (isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.teal.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          m.text,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: GlassSurface(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        radius: 20,
                        child: Text(
                          m.text,
                          style: const TextStyle(color: AppTheme.navy, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick Query Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: currentQueries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final query = currentQueries[index];
                  return ActionChip(
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    side: const BorderSide(color: AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    label: Text(query, style: const TextStyle(fontSize: 12, color: AppTheme.navy)),
                    onPressed: () => _handleSend(query),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Input field on a frosted bar
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0x8CFFFFFF),
                    border: Border(top: BorderSide(color: AppTheme.glassBorder)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: AppTheme.navy),
                              decoration: InputDecoration(
                                hintText: _inputHint,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                fillColor: Colors.white.withValues(alpha: 0.55),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppTheme.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppTheme.glassBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppTheme.teal, width: 1.4),
                                ),
                              ),
                              onSubmitted: (_) => _handleSend(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: _sending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                            onPressed: () => _handleSend(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langChip(String code, String label) {
    final isSelected = _selectedLanguage == code;
    return InkWell(
      onTap: () => _changeLanguage(code),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.teal : AppTheme.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.teal.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.navy,
          ),
        ),
      ),
    );
  }
}
