import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DeleteUserScreen extends StatefulWidget {
  const DeleteUserScreen({super.key});

  @override
  State<DeleteUserScreen> createState() => _DeleteUserScreenState();
}

class _DeleteUserScreenState extends State<DeleteUserScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  String _searchQuery = '';
  bool _isLoading = false;
  
  // دالة حذف المستخدم نهائياً
  Future<void> _deleteUserPermanently(String uid, String name, String email) async {
    setState(() => _isLoading = true);
    
    try {
      // استدعاء Cloud Function لحذف المستخدم
      final HttpsCallable callable = _functions.httpsCallable('deleteUserPermanently');
      final result = await callable.call({'uid': uid});
      
      if (result.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حذف الموظف نهائياً بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showError('❌ فشل حذف الموظف');
      }
      
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _confirmDelete(BuildContext context, String uid, String name, String email, bool isActive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الحذف النهائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل أنت متأكد من حذف الموظف "$name" نهائياً؟'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ سيتم حذف الحساب بالكامل وجميع بياناته، ولن يتمكن من تسجيل الدخول مرة أخرى!',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => _deleteUserPermanently(uid, name, email),
            child: const Text('حذف نهائي', style: TextStyle(color: Color(0xFFE94560))),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('حذف موظف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: '🔍 بحث عن موظف...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF999999)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          
          // ✅ قائمة الموظفين (النشطين والغير نشطين)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', whereIn: ['employee', 'manager'])
                  .snapshots(), // ✅ بدون شرط isActive
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var users = snapshot.data!.docs;
                
                // فلترة حسب البحث
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toLowerCase() ?? '';
                    final email = data['email']?.toLowerCase() ?? '';
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 16),
                        Text('لا يوجد موظفين'),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String uid = doc.id;
                    final String name = data['name'] ?? 'بدون اسم';
                    final String email = data['email'] ?? 'بدون بريد';
                    final String role = data['role'] ?? 'employee';
                    final bool isActive = data['isActive'] ?? true;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: isActive ? null : Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isActive 
                              ? const Color(0xFF2196F3).withOpacity(0.1)
                              : Colors.grey.withOpacity(0.2),
                          child: Text(
                            name.isNotEmpty ? name[0] : '?',
                            style: TextStyle(
                              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'محظور',
                                  style: TextStyle(fontSize: 10, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email, style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFF666666) : Colors.grey.shade500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: role == 'manager' ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role == 'manager' ? '👔 مشرف' : '👤 موظف',
                                style: TextStyle(fontSize: 10, color: role == 'manager' ? Colors.purple : Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFE94560)),
                          onPressed: () => _confirmDelete(context, uid, name, email, isActive),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}