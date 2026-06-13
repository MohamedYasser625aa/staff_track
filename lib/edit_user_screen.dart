import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const EditUserScreen({super.key, required this.userId, required this.userName});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String _selectedRole = 'employee';
  String _selectedProject = '';
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _userData;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadUserData(),
      _loadProjects(),
    ]);
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('users').doc(widget.userId).get();
    if (doc.exists) {
      _userData = doc.data() as Map<String, dynamic>;
      _nameController.text = _userData?['name'] ?? '';
      _phoneController.text = _userData?['phone'] ?? '';
      _emailController.text = _userData?['email'] ?? '';
      _selectedRole = _userData?['role'] ?? 'employee';
      _selectedProject = _userData?['projectId'] ?? '';
    }
  }
  
  Future<void> _loadProjects() async {
    final snapshot = await _firestore
        .collection('projects')
        .where('isActive', isEqualTo: true)
        .get();
    
    _projects = snapshot.docs.map((doc) {
      return {'id': doc.id, 'name': doc['name'] ?? 'مشروع بدون اسم'};
    }).toList();
    setState(() {});
  }
  
  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('❌ من فضلك أدخل الاسم');
      return;
    }
    
    if (_emailController.text.trim().isEmpty) {
      _showError('❌ من فضلك أدخل البريد الإلكتروني');
      return;
    }
    
    if ((_selectedRole == 'employee' || _selectedRole == 'manager') && _selectedProject.isEmpty && _projects.isNotEmpty) {
      _showError('❌ من فضلك اختر المشروع');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'projectId': (_selectedRole == 'employee' || _selectedRole == 'manager') ? _selectedProject : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث بيانات الموظف بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
    
    setState(() => _isSaving = false);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(
          'تعديل بيانات ${widget.userName}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // بطاقة المعلومات الشخصية
                  _buildSectionHeader('المعلومات الشخصية', Icons.person_outline),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _buildCardDecoration(),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'الاسم الكامل',
                          hint: 'أدخل الاسم الكامل',
                          icon: Icons.person_outline,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          hint: 'example@company.com',
                          icon: Icons.email_outlined,
                          enabled: false, // البريد الإلكتروني غير قابل للتعديل (لأنه مرتبط بـ Auth)
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          hint: '05xxxxxxxx',
                          icon: Icons.phone_outlined,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // بطاقة الصلاحية والمشروع
                  _buildSectionHeader('الصلاحية والمشروع', Icons.admin_panel_settings),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _buildCardDecoration(),
                    child: Column(
                      children: [
                        _buildRoleDropdown(),
                        _buildDivider(),
                        if (_selectedRole == 'employee' || _selectedRole == 'manager')
                          _buildProjectDropdown(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // زر الحفظ الرئيسي
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // تنبيه
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظة: لا يمكن تغيير البريد الإلكتروني لأنه مرتبط بحساب تسجيل الدخول.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
  
  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFFF8FAFF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleDropdown() {
    final Map<String, Map<String, dynamic>> roleOptions = {
      'employee': {'icon': Icons.work_outline, 'title': 'موظف', 'color': const Color(0xFF3B82F6)},
      'manager': {'icon': Icons.manage_accounts, 'title': 'مشرف', 'color': const Color(0xFF8B5CF6)},
      'admin': {'icon': Icons.admin_panel_settings, 'title': 'مدير', 'color': const Color(0xFFEF4444)},
    };
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الصلاحية',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: roleOptions.keys.map((role) {
              final isSelected = _selectedRole == role;
              final option = roleOptions[role]!;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = role),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? option['color'].withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? option['color'] : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(option['icon'], color: isSelected ? option['color'] : const Color(0xFF94A3B8), size: 24),
                        const SizedBox(height: 4),
                        Text(
                          option['title'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? option['color'] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProjectDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedRole == 'manager' ? 'المشروع المسؤول عنه' : 'المشروع',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProject.isEmpty ? null : _selectedProject,
                hint: const Text('اختر المشروع', style: TextStyle(color: Color(0xFF94A3B8))),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3B82F6)),
                items: [
                  ..._projects.map((p) {
                    return DropdownMenuItem(
                      value: p['id'],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(p['name'], style: const TextStyle(fontSize: 14)),
                      ),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _selectedProject = value!),
              ),
            ),
          ),
          if (_projects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ لا توجد مشاريع مسجلة. قم بإضافة مشروع أولاً',
                style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(height: 1, color: const Color(0xFFF1F5F9));
  }
}