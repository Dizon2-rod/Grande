import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class ProductReviewScreen extends StatefulWidget {
  final int productId;
  final String productName;
  const ProductReviewScreen({super.key, required this.productId, required this.productName});

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/products/${widget.productId}/reviews');
    if (mounted) {
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(res['reviews'] ?? []);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadReviews,
              child: _showForm
                  ? _buildReviewForm()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reviews stats
                          if (_reviews.isNotEmpty) ...[
                            _buildReviewStats(),
                            const SizedBox(height: 24),
                            const Text('Customer Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                          ],

                          // Reviews list
                          if (_reviews.isEmpty)
                            const EmptyState(
                              icon: Icons.rate_review_outlined,
                              title: 'No reviews yet',
                              subtitle: 'Be the first to review this product',
                            )
                          else
                            ...(_reviews).map((review) => _buildReviewCard(review)),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => setState(() => _showForm = true),
            )
          : null,
    );
  }

  Widget _buildReviewStats() {
    if (_reviews.isEmpty) return const SizedBox.shrink();
    
    final avgRating = (_reviews.fold<double>(0, (sum, r) => sum + (r['rating'] as num)) / _reviews.length);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${avgRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) => Icon(i < avgRating.round() ? Icons.star : Icons.star_border, color: AppTheme.primary, size: 16)),
              ),
              const SizedBox(height: 4),
              Text('${_reviews.length} reviews', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const Spacer(),
          ...(Map<int, int>.fromIterable([5, 4, 3, 2, 1], value: (r) => _reviews.where((x) => (x['rating'] as num).toInt() == r as int).length)).entries.map((e) {
            final count = e.value;
            final percentage = _reviews.isNotEmpty ? (count / _reviews.length) * 100 : 0;
            return Column(
              children: [
                Row(
                  children: [
                    Text('${e.key}★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 60,
                        height: 8,
                        color: AppTheme.border,
                        child: FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
                child: Center(child: Text((review['reviewer_name'] ?? 'R')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['reviewer_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(review['created_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(i < (review['rating'] as num).toInt() ? Icons.star : Icons.star_border, color: AppTheme.primary, size: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Text(review['comment'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          if ((review['images'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review['images'] as List).length,
                itemBuilder: (_, i) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.border),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(ApiService.imageUrl(review['images'][i]), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewForm() {
    return SafeArea(
      child: _ReviewFormWidget(
        productId: widget.productId,
        productName: widget.productName,
        onSubmitted: () {
          setState(() => _showForm = false);
          _loadReviews();
        },
        onCancel: () => setState(() => _showForm = false),
      ),
    );
  }
}

// ─── Review Form ──────────────────────────────────────────────────────────
class _ReviewFormWidget extends StatefulWidget {
  final int productId;
  final String productName;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  const _ReviewFormWidget({
    required this.productId,
    required this.productName,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  State<_ReviewFormWidget> createState() => _ReviewFormWidgetState();
}

class _ReviewFormWidgetState extends State<_ReviewFormWidget> {
  int _rating = 5;
  final _titleCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final List<File> _images = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
    if (mounted) {
      setState(() {
        _images.addAll(pickedFiles.map((f) => File(f.path)));
      });
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _commentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_images.isEmpty) {
        final res = await ApiService.post('/api/products/${widget.productId}/reviews', {
          'rating': _rating,
          'title': _titleCtrl.text,
          'comment': _commentCtrl.text,
        });
        setState(() => _submitting = false);
        if (res['success'] == true) {
          widget.onSubmitted();
        }
      } else {
        // Upload with images
        final res = await ApiService.uploadFile(
          '/api/products/${widget.productId}/reviews',
          _images.first,
          'image',
          {
            'rating': _rating.toString(),
            'title': _titleCtrl.text,
            'comment': _commentCtrl.text,
          },
        );
        setState(() => _submitting = false);
        if (res['success'] == true) {
          widget.onSubmitted();
        }
      }
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share Your Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${widget.productName} - Help other customers decide', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 24),

          // Rating
          const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Title
          const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: 'Summarize your experience',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Comment
          const Text('Comment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share details about your experience',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Images
          const Text('Photos (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          if (_images.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length + 1,
                itemBuilder: (_, i) {
                  if (i == _images.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border, width: 2)),
                        child: const Icon(Icons.add_a_photo_outlined, color: AppTheme.textMuted),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_images[i], fit: BoxFit.cover)),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border, width: 2)),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppTheme.textMuted, size: 24),
                    SizedBox(height: 8),
                    Text('Add photos', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'Submit Review',
                  onPressed: _submitting ? null : _submit,
                  loading: _submitting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
