import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_user_screen.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'إدارة الموظفين',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: '🔍 بحث عن موظف...',
                        prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      icon: const Icon(Icons.filter_list, color: Color(0xFF3B82F6)),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الكل')),
                        DropdownMenuItem(value: 'active', child: Text('نشط')),
                        DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                      ],
                      onChanged: (value) => setState(() => _filterStatus = value!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // قائمة الموظفين
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', whereIn: ['employee', 'manager'])
                  .snapshots(),
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
                
                // فلترة حسب الحالة
                if (_filterStatus == 'active') {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isActive'] == true;
                  }).toList();
                } else if (_filterStatus == 'inactive') {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isActive'] == false;
                  }).toList();
                }
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 16),
                        Text('لا يوجد موظفين', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String id = doc.id;
                    final String name = data['name'] ?? 'بدون اسم';
                    final String email = data['email'] ?? 'بدون بريد';
                    final String role = data['role'] ?? 'employee';
                    final bool isActive = data['isActive'] ?? true;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: isActive ? null : Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isActive
                                  ? (role == 'manager' 
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.1))
                                  : Colors.grey.withValues(alpha: 0.1),
                              child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive 
                                      ? (role == 'manager' ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            if (!isActive)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.block, size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive ? const Color(0xFF1E293B) : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: role == 'manager'
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                    : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role == 'manager' ? 'مشرف' : 'موظف',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: role == 'manager' ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFF64748B) : Colors.grey.shade500),
                            ),
                            if (!isActive)
                              const Text(
                                '⚠️ الحساب معطل',
                                style: TextStyle(fontSize: 10, color: Colors.orange),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر تعديل - ✅ تم إصلاح الأيقونة
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditUserScreen(
                                      userId: id,
                                      userName: name,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {});
                                }
                              },
                            ),
                            // زر تفعيل/تعطيل
                            IconButton(
                              icon: Icon(
                                isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                color: isActive ? Colors.red : Colors.green,
                              ),
                              onPressed: () async {
                                await _firestore.collection('users').doc(id).update({
                                  'isActive': !isActive,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isActive ? '❌ تم تعطيل الحساب' : '✅ تم تفعيل الحساب'),
                                    backgroundColor: isActive ? Colors.red : Colors.green,
                                  ),
                                );
                              },
                            ),
                          ],
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