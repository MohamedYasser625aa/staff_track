import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // بيانات المستخدم
  String userId = "";
  String userName = "";
  String userEmail = "";
  String userPhone = "";
  String userRole = "";
  String department = "";
  String position = "";
  String hireDate = "";
  double salary = 0;
  double vacationBalance = 0;
  String address = "";
  String emergencyContact = "";
  String profileImageUrl = "";

  bool isLoading = true;
  bool isUploading = false;

  // controllers للتعديل
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyController = TextEditingController();

  // تغيير كلمة المرور
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // إعدادات التطبيق
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'ar';
  final String _appVersion = '1.0.0';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      userId = user.uid;
      userEmail = user.email ?? '';

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        userName = data['name'] ?? 'مستخدم';
        userPhone = data['phone'] ?? '';
        userRole = data['role'] ?? 'employee';
        department = data['department'] ?? 'غير محدد';
        position = data['position'] ?? 'موظف';
        hireDate = data['hireDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
        salary = (data['salary'] ?? 0).toDouble();
        vacationBalance = (data['vacationBalance'] ?? 21).toDouble();
        address = data['address'] ?? '';
        emergencyContact = data['emergencyContact'] ?? '';
        profileImageUrl = data['profileImage'] ?? '';

        _nameController.text = userName;
        _phoneController.text = userPhone;
        _addressController.text = address;
        _emergencyController.text = emergencyContact;
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Error loading profile: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAppSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = data['notifications'] ?? true;
          _selectedLanguage = data['language'] ?? 'ar';
          _darkMode = data['darkMode'] ?? false;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  Future<void> _saveAppSettings() async {
    try {
      await _firestore.collection('settings').doc(userId).set({
        'notifications': _notificationsEnabled,
        'language': _selectedLanguage,
        'darkMode': _darkMode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _showSuccessDialog('تم حفظ الإعدادات بنجاح');
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }

  // ==================== رفع الصورة ====================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadImage(File(image.path));
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ في اختيار الصورة: $e');
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => isUploading = true);

    try {
      String fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('profile_images/$fileName');

      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(userId).update({
        'profileImage': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        profileImageUrl = downloadUrl;
      });

      _showSuccessDialog('تم تحديث الصورة بنجاح');
    } catch (e) {
      _showErrorDialog('حدث خطأ في رفع الصورة: $e');
    }

    setState(() => isUploading = false);
  }

  Future<void> _deleteImage() async {
    if (profileImageUrl.isEmpty) {
      _showErrorDialog('لا توجد صورة لحذفها');
      return;
    }

    setState(() => isUploading = true);

    try {
      await _firestore.collection('users').doc(userId).update({
        'profileImage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        profileImageUrl = '';
      });

      _showSuccessDialog('تم حذف الصورة بنجاح');
    } catch (e) {
      _showErrorDialog('حدث خطأ في حذف الصورة: $e');
    }

    setState(() => isUploading = false);
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر صورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPickerOption(icon: Icons.camera_alt, label: 'تصوير', onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                }),
                _buildPickerOption(icon: Icons.photo_library, label: 'المعرض', onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                }),
                if (profileImageUrl.isNotEmpty)
                  _buildPickerOption(icon: Icons.delete, label: 'حذف', color: Colors.red, onTap: () {
                    Navigator.pop(context);
                    _deleteImage();
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  // ==================== تحديث البيانات حسب الصلاحية ====================

  Future<void> _updatePersonalInfo() async {
    if (_nameController.text.isEmpty) {
      _showErrorDialog('الاسم مطلوب');
      return;
    }

    setState(() => isLoading = true);

    try {
      Map<String, dynamic> updateData = {
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // الادمن والمشرف فقط يمكنهم تغيير الاسم ورقم الهاتف
      if (userRole == 'admin' || userRole == 'manager') {
        updateData['name'] = _nameController.text.trim();
        updateData['phone'] = _phoneController.text.trim();
      } else {
        // الموظف العادي لا يمكنه تغيير الاسم ورقم الهاتف
        _showErrorDialog('لا يمكنك تغيير الاسم ورقم الهاتف، تواصل مع المدير');
        setState(() => isLoading = false);
        return;
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      setState(() {
        userName = _nameController.text.trim();
        userPhone = _phoneController.text.trim();
        address = _addressController.text.trim();
        emergencyContact = _emergencyController.text.trim();
      });

      _showSuccessDialog('تم تحديث البيانات بنجاح');
      Navigator.pop(context);
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty) {
      _showErrorDialog('الرجاء إدخال كلمة المرور الحالية');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorDialog('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorDialog('كلمة المرور الجديدة غير متطابقة');
      return;
    }

    setState(() => isLoading = true);

    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      _showSuccessDialog('تم تغيير كلمة المرور بنجاح');

      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      Navigator.pop(context);
    } catch (e) {
      if (e.toString().contains('wrong-password')) {
        _showErrorDialog('كلمة المرور الحالية غير صحيحة');
      } else {
        _showErrorDialog('حدث خطأ: $e');
      }
    }

    setState(() => isLoading = false);
  }

  // ==================== حوارات التعديل ====================

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل البيانات الشخصية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userRole == 'admin' || userRole == 'manager') ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم كاملاً'),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.right,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(userName),
                      const SizedBox(height: 8),
                      const Text('رقم الهاتف', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(userPhone.isEmpty ? 'غير مدخل' : userPhone),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('لا يمكنك تغيير الاسم ورقم الهاتف، تواصل مع المدير',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
                maxLines: 2,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emergencyController,
                decoration: const InputDecoration(labelText: 'رقم الطوارئ'),
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: _updatePersonalInfo, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('الإعدادات'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('الإشعارات'),
                  subtitle: const Text('استلام إشعارات التطبيق'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setStateDialog(() {
                      _notificationsEnabled = value;
                    });
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                  activeThumbColor: const Color(0xFF2196F3),
                ),
                const Divider(),
                ListTile(
                  title: const Text('اللغة'),
                  subtitle: Text(_selectedLanguage == 'ar' ? 'العربية' : 'English'),
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    items: const [
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        _selectedLanguage = value!;
                      });
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('الوضع الليلي'),
                  subtitle: const Text('تغيير مظهر التطبيق'),
                  value: _darkMode,
                  onChanged: (value) {
                    setStateDialog(() {
                      _darkMode = value;
                    });
                    setState(() {
                      _darkMode = value;
                    });
                  },
                  activeThumbColor: const Color(0xFF2196F3),
                ),
                const Divider(),
                ListTile(
                  title: const Text('إصدار التطبيق'),
                  subtitle: Text('الإصدار $_appVersion'),
                  trailing: const Icon(Icons.info_outline),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await _saveAppSettings();
                Navigator.pop(context);
              },
              child: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
                obscureText: true,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                obscureText: true,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة'),
                obscureText: true,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: _changePassword, child: const Text('تغيير')),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getRoleText() {
    switch (userRole) {
      case 'admin': return 'مدير النظام 👑';
      case 'manager': return 'مشرف 👔';
      default: return 'موظف 👤';
    }
  }

  Color _getRoleColor() {
    switch (userRole) {
      case 'admin': return const Color(0xFFE94560);
      case 'manager': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('البروفايل الشخصي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF3B82F6)),
            onPressed: _showSettingsDialog,
            tooltip: 'الإعدادات',
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF1E293B)),
            onPressed: _showEditDialog,
            tooltip: 'تعديل البيانات',
          ),
        ],
      ),
      body: isLoading || isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    const Text('جاري رفع الصورة...'),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileImage(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRoleColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_getRoleText(), style: TextStyle(color: _getRoleColor(), fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  _buildEmploymentCard(),
                  const SizedBox(height: 20),
                  _buildEmergencyCard(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _showImagePickerDialog,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Stack(
          children: [
            ClipOval(
              child: profileImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, size: 60, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: Color(0xFF1A1A2E), size: 22),
              SizedBox(width: 8),
              Text('المعلومات الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.person, 'الاسم', userName),
          _buildInfoRow(Icons.email, 'البريد الإلكتروني', userEmail),
          _buildInfoRow(Icons.phone, 'رقم الهاتف', userPhone.isEmpty ? 'غير مدخل' : userPhone),
          _buildInfoRow(Icons.location_on, 'العنوان', address.isEmpty ? 'غير مدخل' : address),
        ],
      ),
    );
  }

  Widget _buildEmploymentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.work, color: Color(0xFF1A1A2E), size: 22),
              SizedBox(width: 8),
              Text('المعلومات الوظيفية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.business, 'القسم', department),
          _buildInfoRow(Icons.work_history, 'الوظيفة', position),
          _buildInfoRow(Icons.attach_money, 'الراتب', '${salary.toStringAsFixed(2)} جنيه'),
          _buildInfoRow(Icons.beach_access, 'رصيد الإجازات', '${vacationBalance.toStringAsFixed(1)} يوم'),
          _buildInfoRow(Icons.calendar_today, 'تاريخ التعيين', _formatDate(hireDate)),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('جهات الاتصال للطوارئ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.contact_phone, 'رقم الطوارئ', emergencyContact.isEmpty ? 'غير مدخل' : emergencyContact),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showChangePasswordDialog,
            icon: const Icon(Icons.lock_outline),
            label: const Text('تغيير كلمة المرور'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showEditDialog,
            icon: const Icon(Icons.edit),
            label: const Text('تعديل البيانات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '----';
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}