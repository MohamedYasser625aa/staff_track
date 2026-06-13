import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'employee'; // employee, manager, admin
  String _selectedProject = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  List<Map<String, dynamic>> _projects = [];
  
  @override
  void initState() {
    super.initState();
    _loadProjects();
  }
  
  Future<void> _loadProjects() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('projects')
          .where('isActive', isEqualTo: true)
          .get();
      
      setState(() {
        _projects = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'] ?? 'مشروع بدون اسم',
          };
        }).toList();
      });
    } catch (e) {
      print("❌ Error loading projects: $e");
    }
  }
  
  Future<void> _addUser() async {
    // التحقق من الحقول
    if (_nameController.text.trim().isEmpty) {
      _showError('❌ من فضلك أدخل اسم الموظف');
      return;
    }
    
    if (_emailController.text.trim().isEmpty) {
      _showError('❌ من فضلك أدخل البريد الإلكتروني');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showError('❌ كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('❌ كلمة المرور غير متطابقة');
      return;
    }
    
    // ✅ التعديل هنا: الموظف والمشرف لازم يختاروا مشروع
    if ((_selectedRole == 'employee' || _selectedRole == 'manager') && _selectedProject.isEmpty && _projects.isNotEmpty) {
      _showError('❌ من فضلك اختر المشروع');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 1️⃣ إنشاء المستخدم في Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      
      String uid = userCredential.user!.uid;
      
      // 2️⃣ حفظ بيانات المستخدم في Firestore
      // ✅ التعديل هنا: الموظف والمشرف ياخدوا projectId
      String? projectId;
      if (_selectedRole == 'employee' || _selectedRole == 'manager') {
        projectId = _selectedProject;
      }
      
      Map<String, dynamic> userData = {
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'projectId': projectId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser!.uid,
      };
      
      await _firestore.collection('users').doc(uid).set(userData);
      
      // 3️⃣ رسالة نجاح
      String roleName = _selectedRole == 'admin' ? 'مدير' : (_selectedRole == 'manager' ? 'مشرف' : 'موظف');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم إضافة $roleName بنجاح'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // تنظيف الحقول
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _selectedRole = 'employee';
          _selectedProject = '';
        });
      }
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError('❌ هذا البريد الإلكتروني مستخدم بالفعل');
      } else if (e.code == 'invalid-email') {
        _showError('❌ البريد الإلكتروني غير صالح');
      } else {
        _showError('❌ خطأ: ${e.message}');
      }
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // ✅ تحديد إذا كان يحتاج اختيار مشروع (موظف أو مشرف)
    bool needsProject = _selectedRole == 'employee' || _selectedRole == 'manager';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'إضافة موظف جديد',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة المعلومات
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'أدخل اسم الموظف',
                    icon: Icons.person_outline,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    hint: 'example@company.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: '05xxxxxxxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildDivider(),
                  _buildPasswordField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    obscure: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  _buildDivider(),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'تأكيد كلمة المرور',
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  _buildDivider(),
                  
                  // اختيار الصلاحية
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الصلاحية',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRoleCard(
                                title: 'موظف',
                                icon: Icons.work_outline,
                                isSelected: _selectedRole == 'employee',
                                onTap: () => setState(() => _selectedRole = 'employee'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRoleCard(
                                title: 'مشرف',
                                icon: Icons.manage_accounts,
                                isSelected: _selectedRole == 'manager',
                                onTap: () => setState(() => _selectedRole = 'manager'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRoleCard(
                                title: 'مدير',
                                icon: Icons.admin_panel_settings,
                                isSelected: _selectedRole == 'admin',
                                onTap: () => setState(() => _selectedRole = 'admin'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // ✅ اختيار المشروع (للموظف أو المشرف)
                  if (needsProject) ...[
                    _buildDivider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedRole == 'manager' ? 'المشروع المسؤول عنه' : 'المشروع / موقع العمل',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                hint: Text(_selectedRole == 'manager' ? 'اختر المشروع المسؤول عنه' : 'اختر المشروع'),
                                value: _selectedProject.isEmpty ? null : _selectedProject,
                                items: [
                                  ..._projects.map((project) {
                                    return DropdownMenuItem(
                                      value: project['id'],
                                      child: Text(project['name']),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedProject = value!);
                                },
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                          if (_projects.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '⚠️ لا توجد مشاريع مسجلة. قم بإضافة مشروع أولاً',
                                style: TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // زر الإضافة
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إضافة موظف',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: const Color(0xFF999999)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: '********',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF999999)),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF999999),
                ),
                onPressed: onToggle,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF999999),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(height: 1, color: const Color(0xFFF0F0F0));
  }
}