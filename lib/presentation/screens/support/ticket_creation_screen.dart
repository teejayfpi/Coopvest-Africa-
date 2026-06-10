import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Ticket Creation Screen
class TicketCreationScreen extends ConsumerStatefulWidget {
  final String? preselectedCategory;
  const TicketCreationScreen({Key? key, this.preselectedCategory}) : super(key: key);

  @override
  ConsumerState<TicketCreationScreen> createState() => _TicketCreationScreenState();
}

class _TicketCreationScreenState extends ConsumerState<TicketCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String _selectedCategory = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<Map<String, String>> _categories = [
    {'value': 'loan_issue', 'title': 'Loan Issue'},
    {'value': 'guarantor_consent', 'title': 'Guarantor Consent'},
    {'value': 'account_kyc', 'title': 'Account / KYC'},
    {'value': 'technical_bug', 'title': 'Technical Bug'},
    {'value': 'other', 'title': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    if (widget.preselectedCategory != null) _selectedCategory = widget.preselectedCategory!;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory.isEmpty) { setState(() => _errorMessage = 'Please select a category'); return; }
    setState(() { _isSubmitting = true; _errorMessage = null; });
    try {
      final response = await ApiClient().getDio().post('/tickets', data: {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
      });
      if (response.data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket created successfully!'), backgroundColor: CoopvestColors.primary));
        Navigator.of(context).pushReplacementNamed('/tickets');
      } else {
        setState(() => _errorMessage = response.data['error'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create ticket. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Create Ticket', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: CoopvestColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [const Icon(Icons.error_outline, color: CoopvestColors.error), const SizedBox(width: 12), Expanded(child: Text(_errorMessage!, style: const TextStyle(color: CoopvestColors.error)))]),
                  ),
                Text('Category *', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category['value'];
                    return ChoiceChip(
                      label: Text(category['title']!),
                      selected: isSelected,
                      onSelected: (selected) => setState(() { _selectedCategory = category['value']!; _errorMessage = null; }),
                      selectedColor: CoopvestColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : context.textPrimary),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                AppTextField(label: 'Subject *', hint: 'Brief summary of the issue', controller: _titleController, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 20),
                AppTextField(label: 'Description *', hint: 'Provide details about your issue', controller: _descriptionController, maxLines: 5, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 32),
                PrimaryButton(label: 'Submit Ticket', onPressed: _submitTicket, isLoading: _isSubmitting, width: double.infinity),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
