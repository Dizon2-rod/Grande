import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  
  const EditProductScreen({super.key, required this.product});
  
  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _discountPriceCtrl;
  bool _loading = false;
  bool _flashSale = false;
  List<File> _images = [];
  List<String> _existingImages = [];
  final _picker = ImagePicker();
  
  // Variants
  List<String> _sizes = [];
  List<String> _colors = [];
  final _sizeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  Map<String, Map<String, dynamic>> _variants = {};

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p['name'] ?? '');
    _descCtrl = TextEditingController(text: p['description'] ?? '');
    _priceCtrl = TextEditingController(text: (p['price'] ?? 0).toString());
    _stockCtrl = TextEditingController(text: (p['total_stock'] ?? 0).toString());
    _categoryCtrl = TextEditingController(text: p['category'] ?? '');
    _discountPriceCtrl = TextEditingController(text: (p['discount_price'] ?? '').toString());
    _flashSale = (p['is_flash_sale'] as int? ?? 0) == 1;
    
    // Load existing images
    if (p['images'] != null && p['images'] is List) {
      _existingImages = (p['images'] as List).map((img) => img['image_url'].toString()).toList();
    } else if (p['image_url'] != null) {
      _existingImages = [p['image_url'].toString()];
    }
    
    // Load variants if available
    if (p['variants'] != null && p['variants'] is List) {
      final variants = p['variants'] as List;
      for (var v in variants) {
        final size = v['size'] ?? '';
        final color = v['color'] ?? '';
        if (size.isNotEmpty && !_sizes.contains(size)) _sizes.add(size);
        if (color.isNotEmpty && !_colors.contains(color)) _colors.add(color);
        final key = '$size-$color';
        _variants[key] = {
          'stock': v['stock'] ?? 0,
          'sku': v['sku'] ?? '',
        };
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    _discountPriceCtrl.dispose();
    _sizeCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _addSize() {
    if (_sizeCtrl.text.isNotEmpty && !_sizes.contains(_sizeCtrl.text)) {
      setState(() {
        _sizes.add(_sizeCtrl.text);
        _sizeCtrl.clear();
        _updateVariants();
      });
    }
  }

  void _addColor() {
    if (_colorCtrl.text.isNotEmpty && !_colors.contains(_colorCtrl.text)) {
      setState(() {
        _colors.add(_colorCtrl.text);
        _colorCtrl.clear();
        _updateVariants();
      });
    }
  }

  void _removeSize(String size) {
    setState(() {
      _sizes.remove(size);
      _updateVariants();
    });
  }

  void _removeColor(String color) {
    setState(() {
      _colors.remove(color);
      _updateVariants();
    });
  }

  void _updateVariants() {
    final newVariants = <String, Map<String, dynamic>>{};
    for (var size in _sizes) {
      for (var color in _colors) {
        final key = '$size-$color';
        newVariants[key] = _variants[key] ?? {'stock': 0, 'sku': ''};
      }
    }
    setState(() => _variants = newVariants);
  }

  void _updateVariantStock(String key, int stock) {
    setState(() {
      _variants[key] = {..._variants[key]!, 'stock': stock};
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      // Prepare product data
      final productData = {
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'total_stock': int.tryParse(_stockCtrl.text) ?? 0,
        'category': _categoryCtrl.text,
        'is_flash_sale': _flashSale ? 1 : 0,
        'discount_price': _discountPriceCtrl.text.isNotEmpty ? double.tryParse(_discountPriceCtrl.text) : null,
      };
      
      // Add variants if any
      if (_variants.isNotEmpty) {
        final variantsList = [];
        _variants.forEach((key, value) {
          final parts = key.split('-');
          variantsList.add({
            'size': parts[0],
            'color': parts[1],
            'stock': value['stock'],
            'sku': value['sku'],
          });
        });
        productData['variants'] = variantsList;
      }
      
      // Update product
      final res = await ApiService.put('/api/products/${widget.product['id']}', productData);
      
      // Upload new images if any
      if (_images.isNotEmpty) {
        for (var image in _images) {
          await ApiService.uploadFile(
            '/api/products/${widget.product['id']}/images',
            image,
            'image',
            {},
          );
        }
      }
      
      setState(() => _loading = false);
      
      if (!mounted) return;
      
      if (res['success'] == true || res['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to update product'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        loading: _loading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Images
                const Text('Product Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                
                // Existing Images
                if (_existingImages.isNotEmpty) ...[
                  const Text('Current Images:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImages.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                              image: DecorationImage(
                                image: NetworkImage(ApiService.imageUrl(_existingImages[i])),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(i),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // New Images
                if (_images.isNotEmpty) ...[
                  const Text('New Images:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                              image: DecorationImage(image: FileImage(_images[i]), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Images'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
                const SizedBox(height: 20),
                
                // Product Details
                AppTextField(
                  label: 'Product Name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.inventory_2_outlined,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Description',
                  controller: _descCtrl,
                  maxLines: 3,
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Price (₱)',
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.attach_money,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Stock',
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.numbers,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Category',
                  controller: _categoryCtrl,
                  prefixIcon: Icons.category_outlined,
                ),
                const SizedBox(height: 14),
                
                // Flash Sale
                SwitchListTile(
                  value: _flashSale,
                  onChanged: (v) => setState(() => _flashSale = v),
                  title: const Text('Flash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
                  activeThumbColor: AppTheme.primary,
                  tileColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                
                if (_flashSale) ...[
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Discount Price (₱)',
                    controller: _discountPriceCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.local_offer,
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Variants Section
                const Text('Product Variants (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                
                // Sizes
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Add Size',
                        controller: _sizeCtrl,
                        prefixIcon: Icons.straighten,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addSize,
                      icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                    ),
                  ],
                ),
                if (_sizes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _sizes.map((s) => Chip(
                      label: Text(s),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSize(s),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                
                // Colors
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Add Color',
                        controller: _colorCtrl,
                        prefixIcon: Icons.palette,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addColor,
                      icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                    ),
                  ],
                ),
                if (_colors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((c) => Chip(
                      label: Text(c),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeColor(c),
                    )).toList(),
                  ),
                ],
                
                // Variant Matrix
                if (_variants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Variant Stock:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._variants.entries.map((entry) {
                    final parts = entry.key.split('-');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${parts[0]} - ${parts[1]}', style: const TextStyle(fontSize: 13)),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Stock',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              controller: TextEditingController(text: entry.value['stock'].toString())
                                ..selection = TextSelection.collapsed(offset: entry.value['stock'].toString().length),
                              onChanged: (v) => _updateVariantStock(entry.key, int.tryParse(v) ?? 0),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Update Product',
                  icon: Icons.save,
                  onPressed: _submit,
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
