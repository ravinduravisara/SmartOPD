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
  final List<({String sender, String text})> _messages = [];
  bool _sending = false;

  final List<String> _quickQueries = [
    'What is my token?',
    'How many patients ahead?',
    'What is the current token?',
    'How long do I need to wait?',
    'When should I return?',
    'Is the doctor delayed?'
  ];

  @override
  void initState() {
    super.initState();
    _messages.add((
      sender: 'assistant',
      text: 'Hello! I am your Smart Queue Assistant. Ask me anything about your current OPD token, queue position, or estimated wait time.'
    ));
  }

  final ScrollController _scrollController = ScrollController();

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (presetText == null) _controller.clear();

    setState(() {
      _messages.add((sender: 'user', text: text));
      _sending = true;
    });

    _scrollToBottom();

    try {
      final reply = await widget.provider.queueService.askQueueAssistant(text);
      setState(() {
        _messages.add((sender: 'assistant', text: reply));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add((sender: 'assistant', text: 'Error connecting to queue assistant. Please try again.'));
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
      body: Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: Column(
          children: [
            // Active Context Header
            GlassHeroSurface(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
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
                itemCount: _quickQueries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final query = _quickQueries[index];
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
                                hintText: 'Ask about your queue...',
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
}
