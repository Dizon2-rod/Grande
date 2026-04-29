import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class ImprovedAddProductScreen extends StatefulWidget {
  const ImprovedAddProductScreen({super.key});
  
  @override
  State<ImprovedAddProductScreen> createState() => _ImprovedAddProductScreenState();
}

class _ImprovedAddProductScreenState extends State<ImprovedAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  bool _loading = false;
  bool _flashSale = false;
  final List<File> _images = [];
  final _picker = ImagePicker();
  String? _sellerCategory; // Store seller's registered category
  bool _showShoeSizes = false;
  
  // Variants
  final List<String> _clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _shoeSizes = ['35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];
  final List<String> _sizes = [];
  final _sizeCtrl = TextEditingController();
  
  // Colors with hex codes for swatches
  final List<Map<String, dynamic>> _presetColors = [
    {'name': 'Black', 'hex': '#000000'},
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Red', 'hex': '#FF0000'},
    {'name': 'Blue', 'hex': '#0000FF'},
    {'name': 'Green', 'hex': '#008000'},
    {'name': 'Yellow', 'hex': '#FFFF00'},
    {'name': 'Pink', 'hex': '#FFC0CB'},
    {'name': 'Purple', 'hex': '#800080'},
    {'name': 'Gray', 'hex': '#808080'},
    {'name': 'Brown', 'hex': '#A52A2A'},
    {'name': 'Beige', 'hex': '#F5F5DC'},
    {'name': 'Navy', 'hex': '#000080'},
  ];
  final List<String> _colors = [];
  final _colorCtrl = TextEditingController();
  final Map<String, int> _variantStocks = {};

  @override
  void initState() {
    super.initState();
    _loadSellerCategory();
  }

  Future<void> _loadSellerCategory() async {
    try {
      final res = await ApiService.get('/api/seller/category');
      if (res['success'] == true && res['categories'] != null && res['categories'].isNotEmpty) {
        setState(() {
          _sellerCategory = res['categories'][0];
          _updateSizeSelectionMode();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load category: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _updateSizeSelectionMode() {
    final category = (_sellerCategory ?? '').toLowerCase();
    setState(() {
      _showShoeSizes = category.contains('shoe') || category.contains('footwear') || category.contains('sneaker') || category.contains('boot');
    });
  }

  void _toggleSize(String size) {
    if (_sizes.contains(size)) {
      _removeSize(size);
      return;
    }
    setState(() {
      _sizes.add(size);
      _updateVariants();
    });
  }

  void _togglePresetColor(String colorName) {
    if (_colors.contains(colorName)) {
      _removeColor(colorName);
      return;
    }
    setState(() {
      _colors.add(colorName);
      _updateVariants();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
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
    final newStocks = <String, int>{};
    for (var size in _sizes) {
      for (var color in _colors) {
        final key = '$size||$color';
        newStocks[key] = _variantStocks[key] ?? 0;
      }
    }
    setState(() {
      _variantStocks
        ..clear()
        ..addAll(newStocks);
    });
  }

  void _updateVariantStock(String key, int stock) {
    setState(() {
      _variantStocks[key] = stock;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      if (_sizes.isEmpty || _colors.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one size and one color'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }

      if (_images.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one product image'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }

      if (_sellerCategory == null || _sellerCategory!.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to determine product category'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }

      final variantPrice = double.tryParse(_priceCtrl.text) ?? 0;
      final variantDiscountPrice = _discountPriceCtrl.text.isNotEmpty
          ? double.tryParse(_discountPriceCtrl.text)
          : null;

      final sizeColorData = <String, Map<String, dynamic>>{};
      var computedTotalStock = 0;
      _variantStocks.forEach((key, stock) {
          final parts = key.split('||');
        final size = parts[0];
        final color = parts[1];

        sizeColorData.putIfAbsent(size, () => {});
        sizeColorData[size]![color] = {
          'name': color,
          'stock': stock,
          'price': variantPrice,
          'discount_price': variantDiscountPrice,
        };
        computedTotalStock += stock;
      });

      if (sizeColorData.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please configure at least one variant with stock'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }

      final fields = <String, String>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _sellerCategory ?? '',
        'total_stock': computedTotalStock.toString(),
        'is_flash_sale': _flashSale ? '1' : '0',
        'size_color_data': jsonEncode(sizeColorData),
      };

      if (_flashSale && variantDiscountPrice != null) {
        fields['discount_price'] = variantDiscountPrice.toString();
      }

      print('[ADD PRODUCT] Submitting product:');
      print('[ADD PRODUCT] Name: ${fields['name']}');
      print('[ADD PRODUCT] Category: ${fields['category']}');
      print('[ADD PRODUCT] Total Stock: ${fields['total_stock']}');
      print('[ADD PRODUCT] Size Color Data: ${fields['size_color_data']}');
      print('[ADD PRODUCT] Images: ${_images.length}');

      final res = await ApiService.multipartPostFiles(
        '/api/products',
        fields,
        {'default_images[]': _images},
      );

      print('[ADD PRODUCT] Response: $res');
      
      if (res['success'] == true) {
        setState(() => _loading = false);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added! Pending admin approval.'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to add product'), backgroundColor: AppTheme.error),
          );
        }
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
        title: const Text('Add Product'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        loading: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Images
                Row(
                  children: [
                    const Icon(Icons.image_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Product Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_images.isEmpty) ...[
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.solid),
                        color: AppTheme.surface,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add_photo_alternate, size: 32, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 12),
                          const Text('Add Product Images', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Tap to upload', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _images.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _images.length) {
                        return GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.solid),
                              color: AppTheme.surface,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, size: 32, color: AppTheme.primary),
                                const SizedBox(height: 4),
                                const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                              image: DecorationImage(image: FileImage(_images[index]), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
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
                  ],
                ),
                const SizedBox(height: 14),
                
                // Flash Sale
                SwitchListTile(
                  value: _flashSale,
                  onChanged: (v) => setState(() => _flashSale = v),
                  title: const Text('Request Flash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Admin will review your request', style: TextStyle(fontSize: 12)),
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
                      Row(
                        children: [
                          const Icon(Icons.straighten, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Product Variants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Sizes
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Add Size (e.g., S, M, L)',
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: (_showShoeSizes ? _shoeSizes : _clothingSizes).map((size) {
                    final selected = _sizes.contains(size);
                    return FilterChip(
                      label: Text(
                        size,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      selected: selected,
                      selectedColor: AppTheme.primary,
                      checkmarkColor: Colors.white,
                      backgroundColor: AppTheme.surface,
                      side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: selected ? 2 : 1,
                      ),
                      onSelected: (_) => _toggleSize(size),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
                if (_sizes.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                        label: 'Add Color (e.g., Red, Blue)',
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
                const SizedBox(height: 10),
                
                // Preset Colors Grid
                const Text('Quick Add Colors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _presetColors.length,
                  itemBuilder: (context, index) {
                    final color = _presetColors[index];
                    final selected = _colors.contains(color['name']);
                    return GestureDetector(
                      onTap: () => _togglePresetColor(color['name']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? AppTheme.primary : AppTheme.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(int.parse(color['hex'].replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: color['name'] == 'White' 
                                    ? Border.all(color: Colors.grey, width: 1)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                color['name'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  color: selected ? AppTheme.primary : AppTheme.textDark,
                                ),
                              ),
                            ),
                            if (selected)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_colors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Selected Colors:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((c) {
                      final colorData = _presetColors.firstWhere((pc) => pc['name'] == c, orElse: () => {'name': c, 'hex': '#CCCCCC'});
                      return Chip(
                        avatar: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(int.parse(colorData['hex'].replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: c == 'White' ? Border.all(color: Colors.grey, width: 1) : null,
                          ),
                        ),
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeColor(c),
                        backgroundColor: AppTheme.surface,
                        side: BorderSide(color: AppTheme.border),
                      );
                    }).toList(),
                  ),
                ],
                
                // Variant Matrix
                if (_variantStocks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Variant Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._variantStocks.entries.map((entry) {
                    final parts = entry.key.split('||');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Size: ${parts[0]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('Color: ${parts[1]}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                onChanged: (v) => _updateVariantStock(entry.key, int.tryParse(v) ?? 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Add Product',
                  icon: Icons.add_circle_outline,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
