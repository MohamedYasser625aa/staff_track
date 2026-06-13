import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DeductionScreen extends StatefulWidget {
  const DeductionScreen({super.key});

  @override
  State<DeductionScreen> createState() => _DeductionScreenState();
}

class _DeductionScreenState extends State<DeductionScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  String? currentUserId;
  String? currentUserRole;
  String? currentUserName;
  String? currentUserProjectId;
  
  // لإضافة خصم جديد
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _selectedEmployeeId = '';
  List<Map<String, dynamic>> _employees = [];
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
    _loadEmployees();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        currentUserRole = data['role'];
        currentUserName = data['name'] ?? 'مستخدم';
        currentUserProjectId = data['projectId'];
      }
    }
    setState(() {});
  }
  
  Future<void> _loadEmployees() async {
    try {
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true);
      
      // المشرف يشوف الموظفين اللي في مشروعه فقط
      if (currentUserRole == 'manager' && currentUserProjectId != null) {
        query = query.where('projectId', isEqualTo: currentUserProjectId);
      }
      
      final snapshot = await query.get();
      _employees = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'بدون اسم',
          'email': data['email'] ?? '',
        };
      }).toList();
      setState(() {});
    } catch (e) {
      print("Error loading employees: $e");
    }
  }
  
  Future<void> _submitDeduction() async {
    if (_selectedEmployeeId.isEmpty) {
      _showError('❌ من فضلك اختر الموظف');
      return;
    }
    
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('❌ من فضلك أدخل مبلغ صحيح (أكبر من 0)');
      return;
    }
    
    if (_reasonController.text.trim().isEmpty) {
      _showError('❌ من فضلك اكتب سبب الخصم');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final employeeDoc = await _firestore.collection('users').doc(_selectedEmployeeId).get();
      final employeeName = (employeeDoc.data() as Map<String, dynamic>)['name'] ?? 'موظف';
      
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      await _firestore.collection('deductions').add({
        'employeeId': _selectedEmployeeId,
        'employeeName': employeeName,
        'amount': amount,
        'reason': _reasonController.text.trim(),
        'month': monthKey,
        'date': now.toIso8601String(),
        'status': 'pending', // pending, approved_by_admin, rejected_by_admin
        'createdBy': currentUserId,
        'createdByName': currentUserName,
        'createdByRole': currentUserRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      _amountController.clear();
      _reasonController.clear();
      setState(() => _selectedEmployeeId = '');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال طلب الخصم للمراجعة'), backgroundColor: Colors.green),
      );
      
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
    
    setState(() => _isSubmitting = false);
  }
  
  Future<void> _approveDeduction(String deductionId) async {
    try {
      await _firestore.collection('deductions').doc(deductionId).update({
        'status': 'approved',
        'approvedBy': currentUserId,
        'approvedByName': currentUserName,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الموافقة على الخصم'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
  }
  
  Future<void> _rejectDeduction(String deductionId) async {
    try {
      await _firestore.collection('deductions').doc(deductionId).update({
        'status': 'rejected',
        'rejectedBy': currentUserId,
        'rejectedByName': currentUserName,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ تم رفض الخصم'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return '⏳ قيد المراجعة';
      case 'approved': return '✅ معتمد';
      case 'rejected': return '❌ مرفوض';
      default: return '📋 غير معروف';
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || currentUserRole == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('إدارة الخصومات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2196F3),
          unselectedLabelColor: const Color(0xFF999999),
          indicatorColor: const Color(0xFF2196F3),
          tabs: const [
            Tab(text: '➕ إضافة خصم', icon: Icon(Icons.add_box)),
            Tab(text: '📋 قائمة الخصومات', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddDeductionTab(),
          _buildDeductionsListTab(),
        ],
      ),
    );
  }
  
  Widget _buildAddDeductionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اختيار الموظف
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر الموظف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId.isEmpty ? null : _selectedEmployeeId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF2196F3)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  hint: const Text('اختر موظف...'),
                  items: _employees.map<DropdownMenuItem<String>>((emp) {
                    return DropdownMenuItem<String>(
                      value: emp['id'] as String,
                      child: Text(emp['name'] as String),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedEmployeeId = value!),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // المبلغ والسبب
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildTextField(
                  controller: _amountController,
                  label: 'المبلغ (ج.م)',
                  hint: 'مثال: 500',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                _buildDivider(),
                _buildTextField(
                  controller: _reasonController,
                  label: 'سبب الخصم',
                  hint: 'اكتب سبب الخصم بالتفصيل...',
                  icon: Icons.description,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitDeduction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال طلب خصم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // تنبيه للمشرفين
          if (currentUserRole == 'manager')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظة: سيتم إرسال طلب الخصم إلى المدير للموافقة عليه قبل التنفيذ.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDeductionsListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildDeductionsQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        var deductions = snapshot.data!.docs;
        
        // للمشرف: يشوف خصومات موظفيه فقط
        if (currentUserRole == 'manager' && currentUserProjectId != null) {
          final employeeIds = _employees.map((e) => e['id']).toList();
          deductions = deductions.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return employeeIds.contains(data['employeeId']);
          }).toList();
        }
        
        if (deductions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt, size: 64, color: Color(0xFFCCCCCC)),
                SizedBox(height: 16),
                Text('لا توجد خصومات'),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deductions.length,
          itemBuilder: (context, index) {
            final doc = deductions[index];
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final status = data['status'] ?? 'pending';
            final statusColor = _getStatusColor(status);
            final statusText = _getStatusText(status);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.receipt, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['employeeName'] ?? 'موظف',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    data['reason'] ?? 'بدون سبب',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${data['amount']} ج.م',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE94560)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('بواسطة: ${data['createdByName'] ?? 'غير معروف'}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const Spacer(),
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              data['createdAt'] != null
                                  ? DateFormat('yyyy-MM-dd').format((data['createdAt'] as Timestamp).toDate())
                                  : 'تاريخ غير معروف',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        
                        // أزرار الموافقة (للمدير فقط)
                        if (currentUserRole == 'admin' && status == 'pending')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approveDeduction(id),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('موافقة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectDeduction(id),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('رفض'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Query _buildDeductionsQuery() {
    return _firestore
        .collection('deductions')
        .orderBy('createdAt', descending: true);
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: const Color(0xFF999999)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() => Container(height: 1, color: const Color(0xFFF0F0F0));
}