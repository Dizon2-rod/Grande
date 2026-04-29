import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  final String orderNumber;
  final Map<String, dynamic> order;

  const ProofOfDeliveryScreen({super.key, required this.orderNumber, required this.order});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final List<File> _photos = [];
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _recipientName;
  bool _acceptedConditions = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 photos allowed')));
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _photos.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitProof() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take at least one photo')));
      return;
    }

    if (_recipientName == null || _recipientName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter recipient name')));
      return;
    }

    if (!_acceptedConditions) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm delivery conditions')));
      return;
    }

    setState(() => _submitting = true);

    try {
      // Upload first photo as proof
      final res = await ApiService.uploadFile(
        '/api/orders/${widget.orderNumber}/proof-of-delivery',
        _photos.first,
        'proof_photo',
        {
          'recipient_name': _recipientName ?? '',
          'notes': _notesCtrl.text,
          'photos_count': _photos.length.toString(),
        },
      );

      setState(() => _submitting = false);

      if (res['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Proof Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Delivery confirmation received', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Done', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Confirm Receipt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Provide proof that the order has been delivered', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        Text('Order: ${widget.orderNumber}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Photo Evidence Section
            const Text('Photo Evidence', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Take photos of the delivered items', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 12),

            // Photo Grid
            if (_photos.isEmpty)
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 2),
                    color: AppTheme.surface,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: AppTheme.primary),
                      SizedBox(height: 12),
                      Text('Tap to take photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('(Minimum 1, Maximum 3)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length + (_photos.length < 3 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _photos.length) {
                          return GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border, width: 2),
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, color: AppTheme.primary),
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_photos[index], fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _photos.removeAt(index)),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${_photos.length}/3 photos', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            const SizedBox(height: 24),

            // Recipient Info Section
            const Text('Recipient Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),

            TextField(
              onChanged: (value) => setState(() => _recipientName = value),
              decoration: InputDecoration(
                hintText: 'Recipient Name',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Additional Notes (optional)',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),

            // Conditions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acceptedConditions,
                    onChanged: (value) => setState(() => _acceptedConditions = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('I confirm that:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('• Items have been delivered intact', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Text('• Recipient has acknowledged receipt', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            GradientButton(
              label: 'Submit Proof of Delivery',
              onPressed: _submitting ? null : _submitProof,
              loading: _submitting,
            ),
            const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
