import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';

/// Ticket Detail Screen
class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({Key? key, required this.ticketId}) : super(key: key);

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _isLoading = true;
  bool _isReplying = false;
  Map<String, dynamic>? _ticket;
  List<dynamic> _messages = [];
  String? _errorMessage;
  final TextEditingController _replyController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadTicketDetails());
  }

  @override
  void dispose() {
    _replyController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTicketDetails() async {
    try {
      final response = await ApiClient().getDio().get('/tickets/${widget.ticketId}');
      if (response.data['success'] == true && mounted) {
        setState(() { _ticket = response.data['ticket']; _messages = response.data['messages'] ?? []; _isLoading = false; });
      } else {
        setState(() { _errorMessage = response.data['error'] ?? 'Failed to load ticket'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to load ticket. Please try again.'; _isLoading = false; });
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _isReplying = true);
    try {
      final response = await ApiClient().getDio().post('/tickets/${widget.ticketId}/messages', data: {'content': _replyController.text.trim()});
      if (response.data['success'] == true) { _replyController.clear(); _loadTicketDetails(); }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send reply'), backgroundColor: CoopvestColors.error));
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Ticket Details', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
          : _errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildTicketHeader(context),
                    Expanded(child: _buildMessagesList(context)),
                    _buildReplyInput(context),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: CoopvestColors.error),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: CoopvestColors.error)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadTicketDetails, style: ElevatedButton.styleFrom(backgroundColor: CoopvestColors.primary), child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTicketHeader(BuildContext context) {
    if (_ticket == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(_ticket!['status']?.toUpperCase() ?? '', style: const TextStyle(color: CoopvestColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(_ticket!['category'] ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_ticket!['title'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['senderType'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? CoopvestColors.primary : context.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: isUser ? null : Border.all(color: context.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg['content'] ?? '', style: TextStyle(color: isUser ? Colors.white : context.textPrimary)),
                const SizedBox(height: 4),
                Text(DateFormat('h:mm a').format(DateTime.parse(msg['createdAt'])), style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : context.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardBackground, border: Border(top: BorderSide(color: context.dividerColor))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(hintText: 'Type your reply...', hintStyle: TextStyle(color: context.textSecondary), border: InputBorder.none),
              style: TextStyle(color: context.textPrimary),
            ),
          ),
          IconButton(icon: Icon(Icons.send, color: CoopvestColors.primary), onPressed: _isReplying ? null : _sendReply),
        ],
      ),
    );
  }
}
