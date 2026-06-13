import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManageRequestsScreen extends StatefulWidget {
  const ManageRequestsScreen({super.key});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String? currentUserId;
  String? currentUserRole;
  String? currentUserName;
  String? currentUserProjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  // الموافقة على الطلب (من المشرف أو الادمن)
  Future<void> _approveRequest(String requestId, Map<String, dynamic> currentData) async {
    String currentStatus = currentData['status'] ?? 'pending';
    String newStatus = '';
    String decisionDate = DateTime.now().toIso8601String();

    if (currentUserRole == 'manager') {
      // المشرف يوافق
      newStatus = 'approved_by_manager';
      await _firestore.collection('requests').doc(requestId).update({
        'status': newStatus,
        'managerId': currentUserId,
        'managerName': currentUserName,
        'managerDecisionDate': decisionDate,
        'managerComment': 'تمت الموافقة من قبل المشرف',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (currentUserRole == 'admin') {
      // الادمن يوافق
      if (currentStatus == 'approved_by_manager') {
        // تمت موافقة المشرف مسبقاً -> الطلب مقبول بالكامل
        newStatus = 'approved';
        await _firestore.collection('requests').doc(requestId).update({
          'status': newStatus,
          'adminId': currentUserId,
          'adminName': currentUserName,
          'adminDecisionDate': decisionDate,
          'adminComment': 'تمت الموافقة من قبل المدير',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // إرسال إشعار للموظف (يمكن إضافة إشعارات Firebase لاحقاً)
        _sendNotification(currentData['employeeId'], '✅ تم قبول طلبك');
      } else {
        // الادمن يوافق مباشرة (دون موافقة المشرف)
        newStatus = 'approved';
        await _firestore.collection('requests').doc(requestId).update({
          'status': newStatus,
          'adminId': currentUserId,
          'adminName': currentUserName,
          'adminDecisionDate': decisionDate,
          'adminComment': 'تمت الموافقة من قبل المدير',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _sendNotification(currentData['employeeId'], '✅ تم قبول طلبك');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم قبول الطلب'), backgroundColor: Colors.green),
      );
    }
  }

  // رفض الطلب
  Future<void> _rejectRequest(String requestId, Map<String, dynamic> currentData) async {
    String newStatus = '';
    String decisionDate = DateTime.now().toIso8601String();

    if (currentUserRole == 'manager') {
      newStatus = 'rejected_by_manager';
      await _firestore.collection('requests').doc(requestId).update({
        'status': newStatus,
        'managerId': currentUserId,
        'managerName': currentUserName,
        'managerDecisionDate': decisionDate,
        'managerComment': 'تم الرفض من قبل المشرف',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _sendNotification(currentData['employeeId'], '❌ تم رفض طلبك من قبل المشرف');
    } else if (currentUserRole == 'admin') {
      newStatus = 'rejected';
      await _firestore.collection('requests').doc(requestId).update({
        'status': newStatus,
        'adminId': currentUserId,
        'adminName': currentUserName,
        'adminDecisionDate': decisionDate,
        'adminComment': 'تم الرفض من قبل المدير',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _sendNotification(currentData['employeeId'], '❌ تم رفض طلبك من قبل المدير');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ تم رفض الطلب'), backgroundColor: Colors.orange),
      );
    }
  }

  void _sendNotification(String employeeId, String message) {
    // هنا هنضيف إشعارات Firebase لاحقاً
    print("🔔 إشعار للموظف $employeeId: $message");
  }

  // الحصول على حالة الطلب كنص ملون
  Map<String, dynamic> _getRequestStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'text': '⏳ قيد الانتظار', 'color': Colors.orange, 'bgColor': Colors.orange.withValues(alpha: 0.1)};
      case 'approved_by_manager':
        return {'text': '✅ موافقة مشرف', 'color': Colors.blue, 'bgColor': Colors.blue.withValues(alpha: 0.1)};
      case 'approved':
        return {'text': '✅ مقبول', 'color': Colors.green, 'bgColor': Colors.green.withValues(alpha: 0.1)};
      case 'rejected_by_manager':
        return {'text': '❌ مرفوض (مشرف)', 'color': Colors.red, 'bgColor': Colors.red.withValues(alpha: 0.1)};
      case 'rejected':
        return {'text': '❌ مرفوض', 'color': Colors.red, 'bgColor': Colors.red.withValues(alpha: 0.1)};
      default:
        return {'text': '📋 قيد الانتظار', 'color': Colors.grey, 'bgColor': Colors.grey.withValues(alpha: 0.1)};
    }
  }

  // بناء استعلام الطلبات حسب الدور
  Query _getRequestsQuery() {
    Query query = _firestore.collection('requests').orderBy('createdAt', descending: true);
    
    if (currentUserRole == 'manager' && currentUserProjectId != null) {
      // المشرف يشوف طلبات الموظفين اللي في نفس مشروعه فقط
      // نحتاج نجلب الموظفين اللي projectId = currentUserProjectId
      // سنستخدم where in النارنجي
      return _firestore
          .collection('requests')
          .orderBy('createdAt', descending: true);
    }
    
    return query;
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
        title: const Text(
          'إدارة الطلبات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
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
            Tab(text: '🕒 قيد الانتظار', icon: Icon(Icons.pending_actions)),
            Tab(text: '📋 جميع الطلبات', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingRequestsTab(),
          _buildAllRequestsTab(),
        ],
      ),
    );
  }

  // 📋 علامة تبويب الطلبات المعلقة
  Widget _buildPendingRequestsTab() {
    Query query = _firestore
        .collection('requests')
        .where('status', whereIn: ['pending', 'approved_by_manager'])
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var requests = snapshot.data!.docs;

        // فلترة للمشرف (الموظفين اللي تحت إدارته فقط)
        if (currentUserRole == 'manager' && currentUserProjectId != null) {
          // هنعمل فلترة جانبية للمشرف
          requests = requests.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['projectId'] == currentUserProjectId;
          }).toList();
        }

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Color(0xFFCCCCCC)),
                SizedBox(height: 16),
                Text('لا توجد طلبات معلقة'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final status = data['status'] ?? 'pending';
            final statusInfo = _getRequestStatusInfo(status);

            return _buildRequestCard(
              id: id,
              data: data,
              statusInfo: statusInfo,
              showActions: status == 'pending' || (currentUserRole == 'admin' && status == 'approved_by_manager'),
            );
          },
        );
      },
    );
  }

  // 📋 علامة تبويب جميع الطلبات
  Widget _buildAllRequestsTab() {
    Query query = _firestore
        .collection('requests')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var requests = snapshot.data!.docs;

        // فلترة للمشرف
        if (currentUserRole == 'manager' && currentUserProjectId != null) {
          requests = requests.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['projectId'] == currentUserProjectId;
          }).toList();
        }

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Color(0xFFCCCCCC)),
                SizedBox(height: 16),
                Text('لا توجد طلبات'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final status = data['status'] ?? 'pending';
            final statusInfo = _getRequestStatusInfo(status);

            return _buildRequestCard(
              id: id,
              data: data,
              statusInfo: statusInfo,
              showActions: false,
            );
          },
        );
      },
    );
  }

  // بطاقة الطلب
  Widget _buildRequestCard({
    required String id,
    required Map<String, dynamic> data,
    required Map<String, dynamic> statusInfo,
    required bool showActions,
  }) {
    final type = data['type'] ?? 'leave';
    final typeText = type == 'leave' ? '📅 إجازة' : '⏰ تأخير';
    final typeIcon = type == 'leave' ? Icons.beach_access : Icons.access_time;
    final typeColor = type == 'leave' ? const Color(0xFF2196F3) : const Color(0xFFFF9800);
    
    final employeeName = data['employeeName'] ?? 'موظف';
    final reason = data['reason'] ?? '';
    final startDate = data['startDate'] != null 
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['startDate']))
        : 'غير محدد';
    final endDate = data['endDate'] != null 
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['endDate']))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo['bgColor'],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo['text'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusInfo['color'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // التاريخ
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF999999)),
                    const SizedBox(width: 8),
                    Text(
                      '📅 التاريخ: $startDate${endDate != null ? ' → $endDate' : ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // السبب
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'السبب:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                      ),
                    ],
                  ),
                ),
                
                // قرار المشرف
                if (data['managerName'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'قرار المشرف: ${data['managerName']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              if (data['managerDecisionDate'] != null)
                                Text(
                                  '📅 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data['managerDecisionDate']))}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          data['status'] == 'approved_by_manager' ? Icons.check_circle : Icons.cancel,
                          color: data['status'] == 'approved_by_manager' ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // قرار الادمن
                if (data['adminName'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'قرار المدير: ${data['adminName']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              if (data['adminDecisionDate'] != null)
                                Text(
                                  '📅 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data['adminDecisionDate']))}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          data['status'] == 'approved' ? Icons.check_circle : Icons.cancel,
                          color: data['status'] == 'approved' ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Actions (أزرار الموافقة والرفض)
          if (showActions)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(id, data),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('موافقة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(id, data),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}