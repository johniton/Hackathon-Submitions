import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/counsellor/data/counsellor_service.dart';

class CareerCounsellorChatPage extends StatefulWidget {
  const CareerCounsellorChatPage({super.key});

  @override
  State<CareerCounsellorChatPage> createState() => _CareerCounsellorChatPageState();
}

class _CareerCounsellorChatPageState extends State<CareerCounsellorChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'system',
      'content': "You are Hustlr's AI Career Counsellor. You are an expert career coach, helping candidates with resume advice, interview prep, skill gaps, and job market trends. Be concise, encouraging, and use markdown formatting."
    },
    {
      'role': 'assistant',
      'content': "Hi there! I'm your AI Career Counsellor. I can help you analyze your resume, prepare for interviews, or suggest roadmap adjustments. How can I help you today?"
    }
  ];
  bool _isLoading = false;

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await CounsellorService.sendMessage(_messages);
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '**Error**: Could not fetch response. Please try again later.'});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Skip the system prompt when displaying
    final displayMessages = _messages.where((m) => m['role'] != 'system').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(LucideIcons.bot, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(child: Text('AI Career Counsellor')),
        ]),
        actions: [
          IconButton(icon: const Icon(LucideIcons.moreVertical), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: displayMessages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayMessages.length) {
                return _buildTypingIndicator(isDark);
              }
              final msg = displayMessages[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _chatBubble(
                  context: context,
                  text: msg['content'] ?? '',
                  isAI: msg['role'] == 'assistant',
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
        // Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.backgroundDark : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey : AppColors.primary, 
                    shape: BoxShape.circle
                  ),
                  child: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(LucideIcons.bot, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: const SizedBox(
            width: 40,
            height: 20,
            child: Center(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatBubble({required BuildContext context, required String text, required bool isAI, required bool isDark}) {
    return Row(
      mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAI) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(LucideIcons.bot, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAI ? (isDark ? AppColors.surfaceDark : Colors.white) : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isAI ? 4 : 16),
                bottomRight: Radius.circular(isAI ? 16 : 4),
              ),
              border: isAI ? Border.all(color: isDark ? Colors.white10 : Colors.black12) : null,
            ),
            child: isAI 
              ? MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight, fontSize: 14, height: 1.5),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
          ),
        ),
        if (!isAI) const SizedBox(width: 32),
      ],
    );
  }
}
