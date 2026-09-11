import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            const Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            const Text(
              'Smart Queue Assistant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Active Context Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Token: $token',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'OPD Assistant Only',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.sender == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF0284C7) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: isUser
                          ? []
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 14,
                        height: 1.4,
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
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  label: Text(query, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  onPressed: () => _handleSend(query),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about your queue...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        fillColor: const Color(0xFFF1F5F9),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}
