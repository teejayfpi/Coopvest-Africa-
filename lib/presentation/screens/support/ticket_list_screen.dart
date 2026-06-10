import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import 'ticket_detail_screen.dart';

/// Ticket List Screen
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  String? _errorMessage;
  String _selectedStatus = '';
  
  final List<Map<String, String>> _statusFilters = [
    {'value': '', 'label': 'All'},
    {'value': 'open', 'label': 'Open'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'resolved', 'label': 'Resolved'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final params = <String, dynamic>{};
      if (_selectedStatus.isNotEmpty) params['status'] = _selectedStatus;
      final response = await ApiClient().getDio().get('/tickets', queryParameters: params);
      if (response.data['success'] == true && mounted) {
        setState(() { _tickets = response.data['tickets'] ?? []; });
      } else {
        setState(() { _errorMessage = response.data['error'] ?? 'Failed to load tickets'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to load tickets. Please try again.'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('My Tickets', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: CoopvestColors.primary), onPressed: () => Navigator.of(context).pushNamed('/create-ticket')),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: context.cardBackground, border: Border(bottom: BorderSide(color: context.dividerColor))),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((filter) {
                  final isSelected = _selectedStatus == filter['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() { _selectedStatus = selected ? filter['value']! : ''; });
                        _loadTickets();
                      },
                      selectedColor: CoopvestColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : context.textPrimary),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
                : _errorMessage != null
                    ? _buildErrorView()
                    : _tickets.isEmpty
                        ? _buildEmptyView()
                        : _buildTicketList(),
          ),
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
          ElevatedButton(onPressed: _loadTickets, style: ElevatedButton.styleFrom(backgroundColor: CoopvestColors.primary), child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: context.textSecondary),
          const SizedBox(height: 24),
          Text('No Tickets Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () => Navigator.of(context).pushNamed('/create-ticket'), style: ElevatedButton.styleFrom(backgroundColor: CoopvestColors.primary), child: const Text('Create Ticket')),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: CoopvestColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => TicketDetailScreen(ticketId: ticket['id'] ?? ticket['ticketId']))),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dividerColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ticket['ticketId'] ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(ticket['status']?.toUpperCase() ?? '', style: const TextStyle(color: CoopvestColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(ticket['subject'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  const SizedBox(height: 4),
                  Text(ticket['category'] ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
