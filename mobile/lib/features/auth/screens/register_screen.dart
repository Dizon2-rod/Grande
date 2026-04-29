import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

class _PsgcOption {
  final String code;
  final String name;

  const _PsgcOption({
    required this.code,
    required this.name,
  });
}

class _RoleAddressState {
  List<_PsgcOption> regions = [];
  List<_PsgcOption> provinces = [];
  List<_PsgcOption> cities = [];
  List<_PsgcOption> barangays = [];

  String? regionCode;
  String? regionName;
  String? provinceCode;
  String? provinceName;
  String? cityCode;
  String? cityName;
  String? barangayCode;
  String? barangayName;

  bool loadingRegions = false;
  bool loadingProvinces = false;
  bool loadingCities = false;
  bool loadingBarangays = false;

  bool get isComplete =>
      regionCode != null &&
      provinceCode != null &&
      cityCode != null &&
      barangayCode != null;

  void clearRegionDependentData() {
    provinces = [];
    cities = [];
    barangays = [];
    provinceCode = null;
    provinceName = null;
    cityCode = null;
    cityName = null;
    barangayCode = null;
    barangayName = null;
  }

  void clearProvinceDependentData() {
    cities = [];
    barangays = [];
    cityCode = null;
    cityName = null;
    barangayCode = null;
    barangayName = null;
  }

  void clearCityDependentData() {
    barangays = [];
    barangayCode = null;
    barangayName = null;
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _psgcRegionsUrl = 'https://psgc.gitlab.io/api/regions/';

  final _formKey = GlobalKey<FormState>();
  final PageController _rolePageController = PageController(initialPage: 0);

  // Shared top fields (match web layout)
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Buyer fields
  final _buyerPasswordCtrl = TextEditingController();
  final _buyerConfirmPasswordCtrl = TextEditingController();
  final _buyerPhoneCtrl = TextEditingController();
  final _buyerStreetCtrl = TextEditingController();
  final _buyerPostalCtrl = TextEditingController();

  // Seller fields
  final _sellerPasswordCtrl = TextEditingController();
  final _sellerConfirmPasswordCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _businessDescCtrl = TextEditingController();
  final _businessEmailCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _sellerStreetCtrl = TextEditingController();
  final _sellerPostalCtrl = TextEditingController();

  // Rider fields
  final _riderPasswordCtrl = TextEditingController();
  final _riderConfirmPasswordCtrl = TextEditingController();
  final _riderPhoneCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _licenseExpiryCtrl = TextEditingController();
  final _vehicleMakeModelCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _riderStreetCtrl = TextEditingController();
  final _riderPostalCtrl = TextEditingController();

  final Map<String, _RoleAddressState> _addressStates = {
    'buyer': _RoleAddressState(),
    'seller': _RoleAddressState(),
    'rider': _RoleAddressState(),
  };

  String _role = 'buyer';
  int _roleStepIndex = 0;

  // Shared meta
  String? _suffix;
  DateTime? _birthday;

  // Role-specific picks/selections
  String? _buyerGender;
  String? _sellerGender;
  String? _riderGender;
  String? _sellerCategory;
  String? _riderVehicleType;
  bool _acceptedTerms = false;

  // Buyer docs
  File? _buyerIdFront;
  File? _buyerIdBack;

  // Seller docs
  File? _sellerIdFront;
  File? _sellerIdBack;
  File? _sellerBusinessRegDoc;
  File? _sellerTaxRegDoc;
  File? _sellerBusinessPermitDoc;

  // Rider docs
  File? _riderLicenseFront;
  File? _riderLicenseBack;
  File? _riderOrDoc;
  File? _riderCrDoc;

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final RegExp _phoneRegex = RegExp(r'^09\d{9}$');
  final RegExp _postalRegex = RegExp(r'^\d{4}$');
  final RegExp _passwordUpper = RegExp(r'[A-Z]');
  final RegExp _passwordLower = RegExp(r'[a-z]');
  final RegExp _passwordDigit = RegExp(r'\d');
  final RegExp _passwordSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  List<TextEditingController> get _allControllers => [
        _firstNameCtrl,
        _middleNameCtrl,
        _lastNameCtrl,
        _emailCtrl,
        _buyerPasswordCtrl,
        _buyerConfirmPasswordCtrl,
        _buyerPhoneCtrl,
        _buyerStreetCtrl,
        _buyerPostalCtrl,
        _sellerPasswordCtrl,
        _sellerConfirmPasswordCtrl,
        _businessNameCtrl,
        _businessDescCtrl,
        _businessEmailCtrl,
        _businessPhoneCtrl,
        _websiteCtrl,
        _sellerStreetCtrl,
        _sellerPostalCtrl,
        _riderPasswordCtrl,
        _riderConfirmPasswordCtrl,
        _riderPhoneCtrl,
        _licenseNumberCtrl,
        _licenseExpiryCtrl,
        _vehicleMakeModelCtrl,
        _experienceCtrl,
        _riderStreetCtrl,
        _riderPostalCtrl,
      ];

  @override
  void initState() {
    super.initState();
    for (final controller in _allControllers) {
      controller.addListener(_onFormChanged);
    }
    _ensureRegionsLoaded('buyer');
  }

  @override
  void dispose() {
    for (final controller in _allControllers) {
      controller.removeListener(_onFormChanged);
      controller.dispose();
    }
    _rolePageController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }


  void _showSnack(String message, {Color bg = AppTheme.error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }

  bool _hasText(TextEditingController controller) => controller.text.trim().isNotEmpty;

  bool _isEmailValid(String value) => _emailRegex.hasMatch(value.trim());

  bool _isPhoneValid(String value) => _phoneRegex.hasMatch(value.trim());

  bool _isPostalCodeValid(String value) => _postalRegex.hasMatch(value.trim());

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        _passwordUpper.hasMatch(value) &&
        _passwordLower.hasMatch(value) &&
        _passwordDigit.hasMatch(value) &&
        _passwordSpecial.hasMatch(value);
  }

  bool get _isIdentityValid =>
      _hasText(_firstNameCtrl) &&
      _hasText(_lastNameCtrl) &&
      _isEmailValid(_emailCtrl.text);

  List<String> get _stepTitles {
    if (_role == 'seller') {
      return const ['Personal Info', 'Business Info', 'Business Address'];
    }
    return const ['Personal Info', 'Vehicle & License', 'Address'];
  }

  bool _isSellerStepValid(int step) {
    final address = _addressStates['seller']!;
    switch (step) {
      case 0:
        return _isIdentityValid &&
            _sellerGender != null &&
            _isStrongPassword(_sellerPasswordCtrl.text) &&
            _sellerConfirmPasswordCtrl.text == _sellerPasswordCtrl.text &&
            _sellerIdFront != null &&
            _sellerIdBack != null;
      case 1:
        return _hasText(_businessNameCtrl) &&
            _hasText(_businessDescCtrl) &&
            _isEmailValid(_businessEmailCtrl.text) &&
            _hasText(_businessPhoneCtrl) &&
            _sellerBusinessRegDoc != null &&
            _sellerTaxRegDoc != null &&
            _sellerBusinessPermitDoc != null &&
            _sellerCategory != null;
      case 2:
        return address.isComplete && _hasText(_sellerStreetCtrl);
      default:
        return false;
    }
  }

  bool _isRiderStepValid(int step) {
    final address = _addressStates['rider']!;
    switch (step) {
      case 0:
        return _isIdentityValid &&
            _riderGender != null &&
            _isStrongPassword(_riderPasswordCtrl.text) &&
            _riderConfirmPasswordCtrl.text == _riderPasswordCtrl.text &&
            _isPhoneValid(_riderPhoneCtrl.text) &&
            _riderLicenseFront != null &&
            _riderLicenseBack != null &&
            _hasText(_licenseNumberCtrl);
      case 1:
        return _riderVehicleType != null && _riderOrDoc != null && _riderCrDoc != null;
      case 2:
        return address.isComplete && _hasText(_riderStreetCtrl) && _hasText(_experienceCtrl);
      default:
        return false;
    }
  }

  bool get _isCurrentRoleStepValid {
    if (_role == 'seller') {
      return _isSellerStepValid(_roleStepIndex);
    }
    if (_role == 'rider') {
      return _isRiderStepValid(_roleStepIndex);
    }
    return false;
  }

  bool get _isBuyerFormValid {
    final address = _addressStates['buyer']!;
    return _isIdentityValid &&
        _buyerGender != null &&
        _isStrongPassword(_buyerPasswordCtrl.text) &&
        _buyerConfirmPasswordCtrl.text == _buyerPasswordCtrl.text &&
        _isPhoneValid(_buyerPhoneCtrl.text) &&
        address.isComplete &&
        _hasText(_buyerStreetCtrl) &&
        _isPostalCodeValid(_buyerPostalCtrl.text) &&
        _buyerIdFront != null &&
        _buyerIdBack != null &&
        _acceptedTerms;
  }

  void _setRole(String role) {
    if (_role == role) return;
    setState(() {
      _role = role;
      _roleStepIndex = 0;
    });
    if (_rolePageController.hasClients) {
      _rolePageController.jumpToPage(0);
    }
    _ensureRegionsLoaded(role);
  }

  Future<void> _goToStep(int nextStep) async {
    if (nextStep < 0 || nextStep > 2) return;
    setState(() => _roleStepIndex = nextStep);
    if (_rolePageController.hasClients) {
      await _rolePageController.animateToPage(
        nextStep,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickDocument(String fieldKey) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return;
    }

    final file = File(result.files.first.path!);
    final fileSize = await file.length();
    if (fileSize > 5 * 1024 * 1024) {
      _showSnack('File size must be 5MB or less.');
      return;
    }

    setState(() {
      switch (fieldKey) {
        case 'buyerIdFront':
          _buyerIdFront = file;
          break;
        case 'buyerIdBack':
          _buyerIdBack = file;
          break;
        case 'sellerIdFront':
          _sellerIdFront = file;
          break;
        case 'sellerIdBack':
          _sellerIdBack = file;
          break;
        case 'sellerBusinessReg':
          _sellerBusinessRegDoc = file;
          break;
        case 'sellerTaxReg':
          _sellerTaxRegDoc = file;
          break;
        case 'sellerBusinessPermit':
          _sellerBusinessPermitDoc = file;
          break;
        case 'riderLicenseFront':
          _riderLicenseFront = file;
          break;
        case 'riderLicenseBack':
          _riderLicenseBack = file;
          break;
        case 'riderOrDoc':
          _riderOrDoc = file;
          break;
        case 'riderCrDoc':
          _riderCrDoc = file;
          break;
      }
    });
  }

  _PsgcOption? _findOption(List<_PsgcOption> options, String? code) {
    if (code == null) return null;
    for (final option in options) {
      if (option.code == code) {
        return option;
      }
    }
    return null;
  }

  Future<List<_PsgcOption>> _fetchPsgcOptions(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('PSGC request failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid PSGC response');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => _PsgcOption(
            code: (json['code'] ?? '').toString(),
            name: (json['name'] ?? '').toString(),
          ),
        )
        .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  Future<void> _ensureRegionsLoaded(String roleKey) async {
    final state = _addressStates[roleKey]!;
    if (state.loadingRegions || state.regions.isNotEmpty) return;

    setState(() => state.loadingRegions = true);
    try {
      state.regions = await _fetchPsgcOptions(_psgcRegionsUrl);
    } catch (_) {
      _showSnack('Failed to load regions. Check your connection.');
    } finally {
      if (mounted) {
        setState(() => state.loadingRegions = false);
      }
    }
  }

  Future<void> _loadProvinces(String roleKey, String regionCode) async {
    final state = _addressStates[roleKey]!;
    setState(() => state.loadingProvinces = true);
    try {
      state.provinces = await _fetchPsgcOptions(
        'https://psgc.gitlab.io/api/regions/$regionCode/provinces/',
      );
    } catch (_) {
      _showSnack('Failed to load provinces.');
    } finally {
      if (mounted) {
        setState(() => state.loadingProvinces = false);
      }
    }
  }

  Future<void> _loadCities(String roleKey, String provinceCode) async {
    final state = _addressStates[roleKey]!;
    setState(() => state.loadingCities = true);
    try {
      state.cities = await _fetchPsgcOptions(
        'https://psgc.gitlab.io/api/provinces/$provinceCode/cities-municipalities/',
      );
    } catch (_) {
      _showSnack('Failed to load cities/municipalities.');
    } finally {
      if (mounted) {
        setState(() => state.loadingCities = false);
      }
    }
  }

  Future<void> _loadBarangays(String roleKey, String cityCode) async {
    final state = _addressStates[roleKey]!;
    setState(() => state.loadingBarangays = true);
    try {
      state.barangays = await _fetchPsgcOptions(
        'https://psgc.gitlab.io/api/cities-municipalities/$cityCode/barangays/',
      );
    } catch (_) {
      _showSnack('Failed to load barangays.');
    } finally {
      if (mounted) {
        setState(() => state.loadingBarangays = false);
      }
    }
  }

  Future<void> _onRegionChanged(String roleKey, String? regionCode) async {
    final state = _addressStates[roleKey]!;
    final selected = _findOption(state.regions, regionCode);
    setState(() {
      state.regionCode = selected?.code;
      state.regionName = selected?.name;
      state.clearRegionDependentData();
    });
    if (selected != null) {
      await _loadProvinces(roleKey, selected.code);
    }
  }

  Future<void> _onProvinceChanged(String roleKey, String? provinceCode) async {
    final state = _addressStates[roleKey]!;
    final selected = _findOption(state.provinces, provinceCode);
    setState(() {
      state.provinceCode = selected?.code;
      state.provinceName = selected?.name;
      state.clearProvinceDependentData();
    });
    if (selected != null) {
      await _loadCities(roleKey, selected.code);
    }
  }

  Future<void> _onCityChanged(String roleKey, String? cityCode) async {
    final state = _addressStates[roleKey]!;
    final selected = _findOption(state.cities, cityCode);
    setState(() {
      state.cityCode = selected?.code;
      state.cityName = selected?.name;
      state.clearCityDependentData();
    });
    if (selected != null) {
      await _loadBarangays(roleKey, selected.code);
    }
  }

  void _onBarangayChanged(String roleKey, String? barangayCode) {
    final state = _addressStates[roleKey]!;
    final selected = _findOption(state.barangays, barangayCode);
    setState(() {
      state.barangayCode = selected?.code;
      state.barangayName = selected?.name;
    });
  }

  String _composeAddress({
    required _RoleAddressState addressState,
    required String street,
    required String postalCode,
  }) {
    final parts = <String>[
      if (street.trim().isNotEmpty) street.trim(),
      if ((addressState.barangayName ?? '').isNotEmpty) addressState.barangayName!,
      if ((addressState.cityName ?? '').isNotEmpty) addressState.cityName!,
      if ((addressState.provinceName ?? '').isNotEmpty) addressState.provinceName!,
      if ((addressState.regionName ?? '').isNotEmpty) addressState.regionName!,
      if (postalCode.trim().isNotEmpty) postalCode.trim(),
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> _buildCommonPayload({
    required String role,
    required String password,
    required String confirmPassword,
    required String? gender,
    required String phone,
    required _RoleAddressState addressState,
    required String street,
    required String postalCode,
  }) {
    final nameParts = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
      if ((_suffix ?? '').trim().isNotEmpty) _suffix!.trim(),
    ];
    final fullName = nameParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final fullAddress = _composeAddress(
      addressState: addressState,
      street: street,
      postalCode: postalCode,
    );

    final payload = <String, dynamic>{
      'firstName': _firstNameCtrl.text.trim(),
      'middleName': _middleNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'name': fullName,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'password': password,
      'confirm_password': confirmPassword,
      'confirmPassword': confirmPassword,
      'role': role,
      'gender': gender,
      'phone': phone.trim(),
      if ((_suffix ?? '').trim().isNotEmpty) 'suffix': _suffix!.trim(),
      if (_birthday != null) 'birthday': _birthday!.toIso8601String().split('T').first,
      'region': addressState.regionName,
      'region_code': addressState.regionCode,
      'province': addressState.provinceName,
      'province_code': addressState.provinceCode,
      'city': addressState.cityName,
      'city_code': addressState.cityCode,
      'barangay': addressState.barangayName,
      'barangay_code': addressState.barangayCode,
      'street': street.trim(),
      'postalCode': postalCode.trim(),
      'address': fullAddress,
    };

    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  Future<void> _submitBuyer() async {
    if (!_isBuyerFormValid) {
      _showSnack('Please complete all required buyer fields.');
      return;
    }

    final address = _addressStates['buyer']!;
    final payload = _buildCommonPayload(
      role: 'buyer',
      password: _buyerPasswordCtrl.text,
      confirmPassword: _buyerConfirmPasswordCtrl.text,
      gender: _buyerGender,
      phone: _buyerPhoneCtrl.text,
      addressState: address,
      street: _buyerStreetCtrl.text,
      postalCode: _buyerPostalCtrl.text,
    );

    final files = <String, File>{
      'id_front': _buyerIdFront!,
      'id_back': _buyerIdBack!,
    };

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerWithFiles(payload, files);
    if (!mounted) return;
    if (ok) {
      _showSuccessDialog();
    } else {
      _showSnack(auth.error ?? 'Registration failed');
    }
  }

  Future<void> _submitSeller() async {
    if (!_isSellerStepValid(2)) {
      _showSnack('Please complete all required seller fields.');
      return;
    }

    final address = _addressStates['seller']!;
    final payload = _buildCommonPayload(
      role: 'seller',
      password: _sellerPasswordCtrl.text,
      confirmPassword: _sellerConfirmPasswordCtrl.text,
      gender: _sellerGender,
      // Web seller form reads phone from shared buyer phone field if present; keep optional.
      phone: _buyerPhoneCtrl.text,
      addressState: address,
      street: _sellerStreetCtrl.text,
      postalCode: _sellerPostalCtrl.text,
    );

    payload.addAll({
      'businessName': _businessNameCtrl.text.trim(),
      'businessDescription': _businessDescCtrl.text.trim(),
      'businessEmail': _businessEmailCtrl.text.trim(),
      'businessPhone': _businessPhoneCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'categories[]': _sellerCategory!,
    });

    final files = <String, File>{
      'id_front': _sellerIdFront!,
      'id_back': _sellerIdBack!,
      'business_registration_doc': _sellerBusinessRegDoc!,
      'tax_registration_doc': _sellerTaxRegDoc!,
      'business_permit_doc': _sellerBusinessPermitDoc!,
    };

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerWithFiles(payload, files);
    if (!mounted) return;
    if (ok) {
      _showSuccessDialog();
    } else {
      _showSnack(auth.error ?? 'Registration failed');
    }
  }

  Future<void> _submitRider() async {
    if (!_isRiderStepValid(2)) {
      _showSnack('Please complete all required rider fields.');
      return;
    }

    final address = _addressStates['rider']!;
    final payload = _buildCommonPayload(
      role: 'rider',
      password: _riderPasswordCtrl.text,
      confirmPassword: _riderConfirmPasswordCtrl.text,
      gender: _riderGender,
      phone: _riderPhoneCtrl.text,
      addressState: address,
      street: _riderStreetCtrl.text,
      postalCode: _riderPostalCtrl.text,
    );

    payload.addAll({
      'licenseNumber': _licenseNumberCtrl.text.trim(),
      'licenseExpiry': _licenseExpiryCtrl.text.trim(),
      'vehicleType': _riderVehicleType!,
      'vehicleMakeModel': _vehicleMakeModelCtrl.text.trim(),
      'experienceDescription': _experienceCtrl.text.trim(),
    });

    final files = <String, File>{
      'license_front': _riderLicenseFront!,
      'license_back': _riderLicenseBack!,
      // keep compatibility with backend fallback in web flow
      'license_document': _riderLicenseFront!,
      'or_document': _riderOrDoc!,
      'cr_document': _riderCrDoc!,
    };

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerWithFiles(payload, files);
    if (!mounted) return;
    if (ok) {
      _showSuccessDialog();
    } else {
      _showSnack(auth.error ?? 'Registration failed');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registration Submitted'),
        content: const Text(
          'Your account is pending admin approval. You will receive an email notification about the decision.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon, String desc) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => _setRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: selected
                    ? AppTheme.brandGradient
                    : const LinearGradient(colors: [Color(0xFFE5E7EB), Color(0xFFE5E7EB)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? Colors.white : AppTheme.textMuted, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? AppTheme.primary : AppTheme.textDark,
                    ),
                  ),
                  Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadCard({
    required String label,
    required String fieldKey,
    required File? file,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (required) const Text(' *', style: TextStyle(color: AppTheme.error)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickDocument(fieldKey),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: file != null ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: file != null ? AppTheme.success : AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Icons.check_circle : Icons.upload_file,
                  color: file != null ? AppTheme.success : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file != null ? 'Uploaded: ${file.path.split('\\').last}' : 'Tap to upload (JPG, PNG, PDF; max 5MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: file != null ? AppTheme.success : AppTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector({
    required String title,
    required String? selected,
    required ValueChanged<String> onChanged,
  }) {
    final options = [
      ('male', 'Male', Icons.male),
      ('female', 'Female', Icons.female),
      ('other', 'Other', Icons.transgender),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = selected == option.$1;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(option.$3, size: 16, color: active ? Colors.white : AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(option.$2),
                ],
              ),
              selected: active,
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: active ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onChanged(option.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPsgcDropdown({
    required String label,
    required String placeholder,
    required IconData icon,
    required List<_PsgcOption> options,
    required String? selectedCode,
    required ValueChanged<String?> onChanged,
    required bool enabled,
    required bool isLoading,
  }) {
    final normalizedValue = options.any((opt) => opt.code == selectedCode) ? selectedCode : null;
    return DropdownButtonFormField<String>(
      initialValue: normalizedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surface,
      ),
      hint: Text(isLoading ? 'Loading...' : placeholder),
      items: options
          .map((option) => DropdownMenuItem<String>(value: option.code, child: Text(option.name)))
          .toList(),
      onChanged: (!enabled || isLoading) ? null : onChanged,
    );
  }

  Widget _buildAddressSection({
    required String roleKey,
    required TextEditingController streetController,
    required TextEditingController postalController,
    required bool postalRequired,
    required String title,
    required String subtitle,
  }) {
    final addressState = _addressStates[roleKey]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 14),
          _buildPsgcDropdown(
            label: 'Region',
            placeholder: 'Select Region',
            icon: Icons.map_outlined,
            options: addressState.regions,
            selectedCode: addressState.regionCode,
            onChanged: (value) => _onRegionChanged(roleKey, value),
            enabled: addressState.regions.isNotEmpty,
            isLoading: addressState.loadingRegions,
          ),
          const SizedBox(height: 12),
          _buildPsgcDropdown(
            label: 'Province',
            placeholder: 'Select Province',
            icon: Icons.account_balance_outlined,
            options: addressState.provinces,
            selectedCode: addressState.provinceCode,
            onChanged: (value) => _onProvinceChanged(roleKey, value),
            enabled: addressState.regionCode != null && addressState.provinces.isNotEmpty,
            isLoading: addressState.loadingProvinces,
          ),
          const SizedBox(height: 12),
          _buildPsgcDropdown(
            label: 'City / Municipality',
            placeholder: 'Select City',
            icon: Icons.location_city_outlined,
            options: addressState.cities,
            selectedCode: addressState.cityCode,
            onChanged: (value) => _onCityChanged(roleKey, value),
            enabled: addressState.provinceCode != null && addressState.cities.isNotEmpty,
            isLoading: addressState.loadingCities,
          ),
          const SizedBox(height: 12),
          _buildPsgcDropdown(
            label: 'Barangay',
            placeholder: 'Select Barangay',
            icon: Icons.home_work_outlined,
            options: addressState.barangays,
            selectedCode: addressState.barangayCode,
            onChanged: (value) => _onBarangayChanged(roleKey, value),
            enabled: addressState.cityCode != null && addressState.barangays.isNotEmpty,
            isLoading: addressState.loadingBarangays,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Street Address',
            hint: 'House/Unit, Building, Street, Landmark',
            controller: streetController,
            prefixIcon: Icons.route_outlined,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: postalRequired ? 'Postal Code (Required)' : 'Postal Code (Optional)',
            hint: 'e.g. 1000',
            controller: postalController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.local_post_office_outlined,
            onChanged: (_) => setState(() {}),
          ),
          if (postalRequired && !_isPostalCodeValid(postalController.text) && postalController.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Postal code must be exactly 4 digits',
                style: TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              if (isNarrow) {
                return Column(
                  children: [
                    AppTextField(
                      label: 'First Name',
                      controller: _firstNameCtrl,
                      prefixIcon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      label: 'Last Name',
                      controller: _lastNameCtrl,
                      prefixIcon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'First Name',
                      controller: _firstNameCtrl,
                      prefixIcon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Last Name',
                      controller: _lastNameCtrl,
                      prefixIcon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'Middle Name (Optional)',
                  controller: _middleNameCtrl,
                  prefixIcon: Icons.person_outline,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _suffix,
                  decoration: InputDecoration(
                    labelText: 'Suffix',
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textMuted, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'Jr.', child: Text('Jr.')),
                    DropdownMenuItem(value: 'Sr.', child: Text('Sr.')),
                    DropdownMenuItem(value: 'II', child: Text('II')),
                    DropdownMenuItem(value: 'III', child: Text('III')),
                    DropdownMenuItem(value: 'IV', child: Text('IV')),
                    DropdownMenuItem(value: 'V', child: Text('V')),
                  ],
                  onChanged: (value) => setState(() => _suffix = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Email Address',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            onChanged: (_) => setState(() {}),
          ),
          if (_emailCtrl.text.isNotEmpty && !_isEmailValid(_emailCtrl.text))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Please enter a valid email address', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('I want to join as', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _buildRoleCard('buyer', 'Buyer', Icons.shopping_cart_outlined, 'Shop products and place orders'),
        const SizedBox(height: 8),
        _buildRoleCard('seller', 'Seller', Icons.store_outlined, 'Sell products and manage your shop'),
        const SizedBox(height: 8),
        _buildRoleCard('rider', 'Rider', Icons.delivery_dining_outlined, 'Deliver orders and earn'),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final titles = _stepTitles;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${_roleStepIndex + 1} of ${titles.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(titles.length, (index) {
              final isActive = index == _roleStepIndex;
              final isDone = index < _roleStepIndex;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppTheme.success
                            : isActive
                                ? AppTheme.primary
                                : AppTheme.border,
                      ),
                      child: Center(
                        child: Text(
                          isDone ? '✓' : '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (index < titles.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: isDone ? AppTheme.success : AppTheme.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            titles[_roleStepIndex],
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStepActionRow({
    required bool loading,
    required bool canProceed,
    required bool isLastStep,
    required VoidCallback onProceed,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _roleStepIndex == 0 ? null : () => _goToStep(_roleStepIndex - 1),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientButton(
            label: isLastStep ? 'Submit Registration' : 'Continue',
            icon: isLastStep ? Icons.check_circle_outline : Icons.arrow_forward,
            loading: loading,
            onPressed: canProceed ? onProceed : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPageShell({
    required Widget content,
    required Widget actions,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIdentitySection(),
          const SizedBox(height: 12),
          _buildRoleSection(),
          const SizedBox(height: 12),
          _buildStepIndicator(),
          const SizedBox(height: 12),
          content,
          const SizedBox(height: 18),
          actions,
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSellerStep1Page(AuthProvider auth) {
    return _buildPageShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 1: Personal Information', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Password',
            controller: _sellerPasswordCtrl,
            obscure: true,
            prefixIcon: Icons.lock_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Confirm Password',
            controller: _sellerConfirmPasswordCtrl,
            obscure: true,
            prefixIcon: Icons.lock_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (_sellerPasswordCtrl.text.isNotEmpty && !_isStrongPassword(_sellerPasswordCtrl.text))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Password does not meet complexity requirements', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
          if (_sellerConfirmPasswordCtrl.text.isNotEmpty &&
              _sellerConfirmPasswordCtrl.text != _sellerPasswordCtrl.text)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Passwords do not match', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          _buildGenderSelector(
            title: 'Gender *',
            selected: _sellerGender,
            onChanged: (value) => setState(() => _sellerGender = value),
          ),
          const SizedBox(height: 12),
          const Text('ID Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _buildDocumentUploadCard(
            label: 'Government ID - Front Side',
            fieldKey: 'sellerIdFront',
            file: _sellerIdFront,
          ),
          const SizedBox(height: 10),
          _buildDocumentUploadCard(
            label: 'Government ID - Back Side',
            fieldKey: 'sellerIdBack',
            file: _sellerIdBack,
          ),
        ],
      ),
      actions: _buildStepActionRow(
        loading: false,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: false,
        onProceed: () => _goToStep(1),
      ),
    );
  }

  Widget _buildSellerStep2Page(AuthProvider auth) {
    return _buildPageShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 2: Business Information', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Shop Name',
            controller: _businessNameCtrl,
            prefixIcon: Icons.storefront_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Short Description',
            controller: _businessDescCtrl,
            prefixIcon: Icons.description_outlined,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          const Text('Business Documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _buildDocumentUploadCard(
            label: 'Business Registration',
            fieldKey: 'sellerBusinessReg',
            file: _sellerBusinessRegDoc,
          ),
          const SizedBox(height: 10),
          _buildDocumentUploadCard(
            label: 'Tax Registration',
            fieldKey: 'sellerTaxReg',
            file: _sellerTaxRegDoc,
          ),
          const SizedBox(height: 10),
          _buildDocumentUploadCard(
            label: 'Business Permit',
            fieldKey: 'sellerBusinessPermit',
            file: _sellerBusinessPermitDoc,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Business Email',
            controller: _businessEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            onChanged: (_) => setState(() {}),
          ),
          if (_businessEmailCtrl.text.isNotEmpty && !_isEmailValid(_businessEmailCtrl.text))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Please enter a valid business email', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Business Phone',
            controller: _businessPhoneCtrl,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Website / Social Media (Optional)',
            controller: _websiteCtrl,
            keyboardType: TextInputType.url,
            prefixIcon: Icons.language_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sellerCategory,
            decoration: InputDecoration(
              labelText: 'Primary Product Category',
              prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.textMuted, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
            items: const [
              DropdownMenuItem(value: 'Dresses & Skirts', child: Text('Dresses & Skirts')),
              DropdownMenuItem(value: 'Tops & Blouses', child: Text('Tops & Blouses')),
              DropdownMenuItem(value: 'Activewear & Yoga Pants', child: Text('Activewear & Yoga Pants')),
              DropdownMenuItem(value: 'Lingerie & Sleepwear', child: Text('Lingerie & Sleepwear')),
              DropdownMenuItem(value: 'Jackets & Coats', child: Text('Jackets & Coats')),
              DropdownMenuItem(value: 'Shoes & Accessories', child: Text('Shoes & Accessories')),
            ],
            onChanged: (value) => setState(() => _sellerCategory = value),
          ),
        ],
      ),
      actions: _buildStepActionRow(
        loading: false,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: false,
        onProceed: () => _goToStep(2),
      ),
    );
  }

  Widget _buildSellerStep3Page(AuthProvider auth) {
    return _buildPageShell(
      content: _buildAddressSection(
        roleKey: 'seller',
        streetController: _sellerStreetCtrl,
        postalController: _sellerPostalCtrl,
        postalRequired: false,
        title: 'Step 3: Business Address',
        subtitle: 'Select exact PSGC region, province, city/municipality, and barangay.',
      ),
      actions: _buildStepActionRow(
        loading: auth.loading,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: true,
        onProceed: _submitSeller,
      ),
    );
  }

  Widget _buildRiderStep1Page(AuthProvider auth) {
    return _buildPageShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 1: Personal Information', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Password',
            controller: _riderPasswordCtrl,
            obscure: true,
            prefixIcon: Icons.lock_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Confirm Password',
            controller: _riderConfirmPasswordCtrl,
            obscure: true,
            prefixIcon: Icons.lock_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_riderPasswordCtrl.text.isNotEmpty && !_isStrongPassword(_riderPasswordCtrl.text))
            const Text('Password does not meet complexity requirements', style: TextStyle(color: AppTheme.error, fontSize: 12)),
          if (_riderConfirmPasswordCtrl.text.isNotEmpty &&
              _riderConfirmPasswordCtrl.text != _riderPasswordCtrl.text)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Passwords do not match', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Phone Number (09XXXXXXXXX)',
            controller: _riderPhoneCtrl,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            onChanged: (_) => setState(() {}),
          ),
          if (_riderPhoneCtrl.text.isNotEmpty && !_isPhoneValid(_riderPhoneCtrl.text))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Phone must follow 09XXXXXXXXX format', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          _buildGenderSelector(
            title: 'Gender *',
            selected: _riderGender,
            onChanged: (value) => setState(() => _riderGender = value),
          ),
          const SizedBox(height: 12),
          _buildDocumentUploadCard(
            label: "Driver's License - Front Side",
            fieldKey: 'riderLicenseFront',
            file: _riderLicenseFront,
          ),
          const SizedBox(height: 10),
          _buildDocumentUploadCard(
            label: "Driver's License - Back Side",
            fieldKey: 'riderLicenseBack',
            file: _riderLicenseBack,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: "Driver's License Number",
            controller: _licenseNumberCtrl,
            prefixIcon: Icons.badge_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final today = DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: today.add(const Duration(days: 365)),
                firstDate: today,
                lastDate: DateTime(today.year + 20),
              );
              if (date != null) {
                _licenseExpiryCtrl.text =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                setState(() {});
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'License Expiry Date (Optional)',
                prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.surface,
              ),
              child: Text(
                _licenseExpiryCtrl.text.isEmpty ? 'Select expiry date' : _licenseExpiryCtrl.text,
                style: TextStyle(color: _licenseExpiryCtrl.text.isEmpty ? AppTheme.textMuted : AppTheme.textDark),
              ),
            ),
          ),
        ],
      ),
      actions: _buildStepActionRow(
        loading: false,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: false,
        onProceed: () => _goToStep(1),
      ),
    );
  }

  Widget _buildRiderStep2Page(AuthProvider auth) {
    return _buildPageShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 2: Vehicle & License', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _riderVehicleType,
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              prefixIcon: const Icon(Icons.two_wheeler_outlined, color: AppTheme.textMuted, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
            items: const [
              DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
              DropdownMenuItem(value: 'Car', child: Text('Car')),
              DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
              DropdownMenuItem(value: 'Van', child: Text('Van')),
            ],
            onChanged: (value) => setState(() => _riderVehicleType = value),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Vehicle Make and Model (Optional)',
            controller: _vehicleMakeModelCtrl,
            prefixIcon: Icons.directions_car_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildDocumentUploadCard(
            label: 'Official Receipt (OR)',
            fieldKey: 'riderOrDoc',
            file: _riderOrDoc,
          ),
          const SizedBox(height: 10),
          _buildDocumentUploadCard(
            label: 'Certificate of Registration (CR)',
            fieldKey: 'riderCrDoc',
            file: _riderCrDoc,
          ),
        ],
      ),
      actions: _buildStepActionRow(
        loading: false,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: false,
        onProceed: () => _goToStep(2),
      ),
    );
  }

  Widget _buildRiderStep3Page(AuthProvider auth) {
    return _buildPageShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddressSection(
            roleKey: 'rider',
            streetController: _riderStreetCtrl,
            postalController: _riderPostalCtrl,
            postalRequired: false,
            title: 'Step 3: Address',
            subtitle: 'Select exact PSGC location and complete your rider address.',
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Delivery Experience',
            hint: 'Tell us about your delivery experience and service area.',
            controller: _experienceCtrl,
            prefixIcon: Icons.description_outlined,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: _buildStepActionRow(
        loading: auth.loading,
        canProceed: _isCurrentRoleStepValid,
        isLastStep: true,
        onProceed: _submitRider,
      ),
    );
  }

  Widget _buildSellerRiderFlow(AuthProvider auth) {
    final pages = _role == 'seller'
        ? [
            _buildSellerStep1Page(auth),
            _buildSellerStep2Page(auth),
            _buildSellerStep3Page(auth),
          ]
        : [
            _buildRiderStep1Page(auth),
            _buildRiderStep2Page(auth),
            _buildRiderStep3Page(auth),
          ];

    return Expanded(
      child: PageView(
        controller: _rolePageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
    );
  }

  Widget _buildBuyerFlow(AuthProvider auth) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIdentitySection(),
            const SizedBox(height: 12),
            _buildRoleSection(),
            const SizedBox(height: 12),
            const Text('Buyer Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _buildGenderSelector(
              title: 'Gender *',
              selected: _buyerGender,
              onChanged: (value) => setState(() => _buyerGender = value),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Password',
              controller: _buyerPasswordCtrl,
              obscure: true,
              prefixIcon: Icons.lock_outline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Confirm Password',
              controller: _buyerConfirmPasswordCtrl,
              obscure: true,
              prefixIcon: Icons.lock_outline,
              onChanged: (_) => setState(() {}),
            ),
            if (_buyerPasswordCtrl.text.isNotEmpty && !_isStrongPassword(_buyerPasswordCtrl.text))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Password must include uppercase, lowercase, number, and special character (8+ chars).',
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ),
            if (_buyerConfirmPasswordCtrl.text.isNotEmpty &&
                _buyerConfirmPasswordCtrl.text != _buyerPasswordCtrl.text)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Passwords do not match', style: TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Phone Number (09XXXXXXXXX)',
              controller: _buyerPhoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              onChanged: (_) => setState(() {}),
            ),
            if (_buyerPhoneCtrl.text.isNotEmpty && !_isPhoneValid(_buyerPhoneCtrl.text))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Phone must follow 09XXXXXXXXX format', style: TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final today = DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate: _birthday ?? DateTime(today.year - 18, today.month, today.day),
                  firstDate: DateTime(1900),
                  lastDate: today,
                );
                if (date != null) {
                  setState(() => _birthday = date);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Birthday (Optional)',
                  prefixIcon: const Icon(Icons.cake_outlined, color: AppTheme.textMuted, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
                child: Text(
                  _birthday == null
                      ? 'Select birthday'
                      : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(color: _birthday == null ? AppTheme.textMuted : AppTheme.textDark),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAddressSection(
              roleKey: 'buyer',
              streetController: _buyerStreetCtrl,
              postalController: _buyerPostalCtrl,
              postalRequired: true,
              title: 'Address Information',
              subtitle: 'Select region → province → city/municipality → barangay (PSGC cascading).',
            ),
            const SizedBox(height: 12),
            _buildDocumentUploadCard(
              label: 'Government ID - Front Side',
              fieldKey: 'buyerIdFront',
              file: _buyerIdFront,
            ),
            const SizedBox(height: 10),
            _buildDocumentUploadCard(
              label: 'Government ID - Back Side',
              fieldKey: 'buyerIdBack',
              file: _buyerIdBack,
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
              title: const Text(
                'I agree to the Terms of Service and Privacy Policy',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            GradientButton(
              label: 'Create Account',
              icon: Icons.check_circle_outline,
              loading: auth.loading,
              onPressed: _isBuyerFormValid ? _submitBuyer : null,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account will be pending admin approval after registration.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_role == 'buyer') _buildBuyerFlow(auth) else _buildSellerRiderFlow(auth),
            ],
          ),
        ),
      ),
    );
  }
}
