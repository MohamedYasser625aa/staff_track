import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'employee_profile_screen.dart';
import 'attendance_report_screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  
  String managerId = "";
  String managerName = "";
  String managerEmail = "";
  String managerProjectId = "";
  
  int totalTeamMembers = 0;
  int presentToday = 0;
  int lateToday = 0;
  int absentToday = 0;
  int pendingRequests = 0;
  double attendanceRate = 0;
  
  bool isCheckedIn = false;
  String checkInTime = "";
  String checkOutTime = "";
  
  double workLatitude = 30.0444;
  double workLongitude = 31.2357;
  double allowedRadius = 100;
  String workLocationAddress = "جاري التحميل...";
  
  List<Map<String, dynamic>> teamMembers = [];
  List<Map<String, dynamic>> todayAttendance = [];
  
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadManagerData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadManagerData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;
      
      managerId = user.uid;
      managerEmail = user.email ?? '';
      
      final doc = await _firestore.collection('users').doc(managerId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        managerName = data['name'] ?? 'مشرف';
        managerProjectId = data['projectId'] ?? '';
        
        await _loadWorkLocation();
        await _loadTeamMembers();
        await _loadTodayStats();
        await _loadManagerAttendance();
        await _loadPendingRequests();
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadWorkLocation() async {
    try {
      if (managerProjectId.isEmpty) {
        workLocationAddress = 'لم يتم تحديد موقع العمل بعد';
        return;
      }
      
      final projectDoc = await _firestore.collection('projects').doc(managerProjectId).get();
      
      if (projectDoc.exists) {
        final data = projectDoc.data() as Map<String, dynamic>;
        workLatitude = (data['latitude'] ?? 30.0444).toDouble();
        workLongitude = (data['longitude'] ?? 31.2357).toDouble();
        allowedRadius = (data['radius'] ?? 100).toDouble();
        workLocationAddress = data['address'] ?? data['name'] ?? 'موقع العمل';
      }
    } catch (e) {}
  }
  
  Future<void> _loadTeamMembers() async {
    try {
      QuerySnapshot snapshot;
      
      if (managerProjectId.isNotEmpty) {
        snapshot = await _firestore
            .collection('users')
            .where('projectId', isEqualTo: managerProjectId)
            .where('isActive', isEqualTo: true)
            .get();
      } else {
        snapshot = await _firestore
            .collection('users')
            .where('isActive', isEqualTo: true)
            .get();
      }
      
      teamMembers = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'بدون اسم',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'role': data['role'] ?? 'employee',
          'salary': data['salary'] ?? 3000,
          'vacationBalance': data['vacationBalance'] ?? 21,
        };
      }).toList();
      
      totalTeamMembers = teamMembers.length;
    } catch (e) {}
  }
  
  Future<void> _loadTodayStats() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      int present = 0;
      int late = 0;
      List<Map<String, dynamic>> attendanceList = [];
      
      for (var member in teamMembers) {
        final doc = await _firestore
            .collection('attendance')
            .doc('${member['id']}_$today')
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'absent';
          final checkIn = data['checkInTime'] ?? '--:--';
          
          if (status == 'present') present++;
          else if (status == 'late') late++;
          
          attendanceList.add({
            'id': member['id'],
            'name': member['name'],
            'status': status,
            'checkInTime': checkIn,
          });
        } else {
          attendanceList.add({
            'id': member['id'],
            'name': member['name'],
            'status': 'absent',
            'checkInTime': '--:--',
          });
        }
      }
      
      presentToday = present;
      lateToday = late;
      absentToday = totalTeamMembers - (present + late);
      if (absentToday < 0) absentToday = 0;
      
      attendanceRate = totalTeamMembers > 0 ? ((present + late) / totalTeamMembers * 100) : 0;
      todayAttendance = attendanceList;
    } catch (e) {}
  }
  
  Future<void> _loadManagerAttendance() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await _firestore.collection('attendance').doc('${managerId}_$today').get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          isCheckedIn = data['checkInTime'] != null;
          checkInTime = data['checkInTime'] ?? '';
          checkOutTime = data['checkOutTime'] ?? '';
        });
      }
    } catch (e) {}
  }
  
  Future<void> _loadPendingRequests() async {
    try {
      final snapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .get();
      pendingRequests = snapshot.docs.length;
    } catch (e) {
      pendingRequests = 0;
    }
  }
  
  Future<LocationResult> _checkLocation() async {
    LocationResult result = LocationResult();
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          result.message = 'مطلوب إذن الوصول للموقع';
          return result;
        }
      }
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distance = Geolocator.distanceBetween(position.latitude, position.longitude, workLatitude, workLongitude);
      
      result.distance = distance;
      result.isWithinRange = distance <= allowedRadius;
      result.message = result.isWithinRange ? 'أنت داخل النطاق المسموح' : 'أنت بعيد عن موقع العمل';
      return result;
    } catch (e) {
      result.message = 'خطأ في تحديد الموقع';
      return result;
    }
  }
  
  Future<void> _checkIn() async {
    final locationResult = await _checkLocation();
    if (!locationResult.isWithinRange) {
      _showErrorDialog('❌ لا يمكن تسجيل الحضور\nالمسافة: ${locationResult.distance.toStringAsFixed(0)} متر\nالمسافة المسموحة: ${allowedRadius.toStringAsFixed(0)} متر');
      return;
    }
    
    if (isCheckedIn) {
      _showErrorDialog('تم تسجيل الحضور مسبقاً اليوم');
      return;
    }
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('hh:mm a').format(now);
      final onTimeLimit = DateTime(now.year, now.month, now.day, 9, 0);
      String status = now.isBefore(onTimeLimit) ? 'present' : 'late';
      
      await _firestore.collection('attendance').doc('${managerId}_$today').set({
        'employeeId': managerId,
        'employeeName': managerName,
        'date': today,
        'checkInTime': time,
        'timestamp': Timestamp.fromDate(now),
        'status': status,
        'location': workLocationAddress,
      });
      
      setState(() {
        isCheckedIn = true;
        checkInTime = time;
      });
      
      _showSuccessDialog(status == 'present' ? '✅ تم تسجيل الحضور بنجاح' : '⚠️ تم تسجيل الحضور (متأخر)');
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }
  
  Future<void> _checkOut() async {
    if (!isCheckedIn) {
      _showErrorDialog('لم يتم تسجيل الحضور بعد');
      return;
    }
    
    final locationResult = await _checkLocation();
    if (!locationResult.isWithinRange) {
      _showErrorDialog('❌ لا يمكن تسجيل الانصراف\n${locationResult.message}');
      return;
    }
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('hh:mm a').format(now);
      
      await _firestore.collection('attendance').doc('${managerId}_$today').update({
        'checkOutTime': time,
        'checkOutTimestamp': Timestamp.fromDate(now),
      });
      
      setState(() {
        isCheckedIn = false;
        checkOutTime = time;
      });
      
      _showSuccessDialog('✅ تم تسجيل الانصراف بنجاح');
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }
  
  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }
  
  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
  
  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'manager': return 'مشرف';
      case 'assistant_manager': return 'مساعد مشرف';
      case 'technician': return 'فني';
      case 'worker': return 'عامل';
      default: return 'موظف';
    }
  }
  
  void _showAddTaskDialog() {
    if (teamMembers.isEmpty) {
      _showErrorDialog('❌ لا يوجد موظفين في فريقك');
      return;
    }
    
    final taskNameController = TextEditingController();
    final taskDetailsController = TextEditingController();
    String selectedEmployeeId = '';
    String priority = 'medium';
    DateTime? dueDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('📋 إضافة مهمة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskNameController,
                    decoration: const InputDecoration(labelText: '📌 اسم المهمة', prefixIcon: Icon(Icons.task), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taskDetailsController,
                    decoration: const InputDecoration(labelText: '📝 تفاصيل المهمة', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '👤 الموظف المسند إليه'),
                    items: teamMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text('${member['name']} (${_getRoleName(member['role'])})'),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedEmployeeId = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: '⚡ الأولوية', prefixIcon: Icon(Icons.priority_high)),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('🟢 منخفضة')),
                      DropdownMenuItem(value: 'medium', child: Text('🟠 متوسطة')),
                      DropdownMenuItem(value: 'high', child: Text('🔴 عالية')),
                    ],
                    onChanged: (value) => setStateDialog(() => priority = value!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setStateDialog(() => dueDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Text(dueDate != null ? '📅 ${DateFormat('yyyy-MM-dd').format(dueDate!)}' : '📅 اختر تاريخ التسليم'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('❌ إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (taskNameController.text.isEmpty) { _showErrorDialog('❌ أدخل اسم المهمة'); return; }
                  if (selectedEmployeeId.isEmpty) { _showErrorDialog('❌ اختر الموظف'); return; }
                  
                  final employee = teamMembers.firstWhere((m) => m['id'].toString() == selectedEmployeeId);
                  
                  await _firestore.collection('tasks').add({
                    'title': taskNameController.text,
                    'description': taskDetailsController.text,
                    'assignedTo': employee['id'],
                    'assignedToName': employee['name'],
                    'assignedBy': managerId,
                    'assignedByName': managerName,
                    'priority': priority,
                    'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
                    'status': 'pending',
                    'createdAt': Timestamp.now(),
                  });
                  
                  Navigator.pop(context);
                  _showSuccessDialog('✅ تم إضافة المهمة للموظف ${employee['name']}');
                },
                child: const Text('📤 إضافة مهمة'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showUpdateRoleDialog(Map<String, dynamic> employee) {
    String selectedRole = employee['role'] ?? 'employee';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('🔄 تحديث دور الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الموظف: ${employee['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'اختر الدور', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('👤 موظف')),
                    DropdownMenuItem(value: 'assistant_manager', child: Text('👨‍💼 مساعد مشرف')),
                    DropdownMenuItem(value: 'technician', child: Text('🔧 فني')),
                    DropdownMenuItem(value: 'worker', child: Text('🛠️ عامل')),
                  ],
                  onChanged: (value) => setStateDialog(() => selectedRole = value!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('❌ إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('users').doc(employee['id']).update({
                    'role': selectedRole,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  _showSuccessDialog('✅ تم تحديث دور ${employee['name']} إلى ${_getRoleName(selectedRole)}');
                  await _loadTeamMembers();
                },
                child: const Text('💾 حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showAddVacationDialog() {
    if (teamMembers.isEmpty) {
      _showErrorDialog('❌ لا يوجد موظفين في فريقك');
      return;
    }
    
    String selectedEmployeeId = '';
    double days = 0;
    String reason = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('🏖️ إضافة إجازة للموظف', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '👤 اختر الموظف'),
                    items: teamMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(member['name'].toString()),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedEmployeeId = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => days = double.tryParse(value) ?? 0,
                    decoration: const InputDecoration(labelText: '📅 عدد أيام الإجازة', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => reason = value,
                    decoration: const InputDecoration(labelText: '📝 السبب', prefixIcon: Icon(Icons.note), border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('❌ إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedEmployeeId.isEmpty) { _showErrorDialog('❌ اختر الموظف أولاً'); return; }
                  if (days <= 0) { _showErrorDialog('❌ أدخل عدد أيام صحيح'); return; }
                  
                  final employee = teamMembers.firstWhere((m) => m['id'].toString() == selectedEmployeeId);
                  double newBalance = (employee['vacationBalance'] ?? 21) - days;
                  if (newBalance < 0) { _showErrorDialog('❌ رصيد الإجازات غير كافٍ'); return; }
                  
                  await _firestore.collection('users').doc(employee['id']).update({
                    'vacationBalance': newBalance,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  
                  await _firestore.collection('requests').add({
                    'type': 'إجازة',
                    'employeeId': employee['id'],
                    'employeeName': employee['name'],
                    'days': days,
                    'reason': reason,
                    'approvedBy': managerId,
                    'status': 'approved',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  Navigator.pop(context);
                  _showSuccessDialog('✅ تم إضافة ${days.toStringAsFixed(1)} يوم إجازة لـ ${employee['name']}');
                  await _loadTeamMembers();
                },
                child: const Text('📤 إضافة إجازة'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showAddBonusDialog() {
    if (teamMembers.isEmpty) {
      _showErrorDialog('❌ لا يوجد موظفين في فريقك');
      return;
    }
    
    String selectedEmployeeId = '';
    double amount = 0;
    String reason = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('🎁 إضافة حافز / كفاءة', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '👤 اختر الموظف'),
                    items: teamMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(member['name'].toString()),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedEmployeeId = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => amount = double.tryParse(value) ?? 0,
                    decoration: const InputDecoration(labelText: '💰 قيمة الحافز (جنيه)', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => reason = value,
                    decoration: const InputDecoration(labelText: '📝 سبب الكفاءة', prefixIcon: Icon(Icons.star), border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('❌ إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedEmployeeId.isEmpty) { _showErrorDialog('❌ اختر الموظف أولاً'); return; }
                  if (amount <= 0) { _showErrorDialog('❌ أدخل قيمة صحيحة'); return; }
                  
                  final employee = teamMembers.firstWhere((m) => m['id'].toString() == selectedEmployeeId);
                  
                  await _firestore.collection('deductions').add({
                    'employeeId': employee['id'],
                    'employeeName': employee['name'],
                    'amount': -amount,
                    'reason': '🎁 كفاءة: $reason',
                    'type': 'bonus',
                    'date': Timestamp.now(),
                    'month': DateTime.now().month,
                    'year': DateTime.now().year,
                    'approvedBy': managerId,
                  });
                  
                  _showSuccessDialog('✅ تم إضافة ${amount.toStringAsFixed(2)} جنيه كفاءة لـ ${employee['name']}');
                  Navigator.pop(context);
                },
                child: const Text('🎁 إضافة كفاءة'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showDeductionDialog() {
    if (teamMembers.isEmpty) {
      _showErrorDialog('❌ لا يوجد موظفين في فريقك');
      return;
    }
    
    String selectedEmployeeId = '';
    double amount = 0;
    String reason = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('💰 خصم من الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '👤 اختر الموظف'),
                    items: teamMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(member['name'].toString()),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedEmployeeId = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => amount = double.tryParse(value) ?? 0,
                    decoration: const InputDecoration(labelText: '💰 قيمة الخصم (جنيه)', prefixIcon: Icon(Icons.remove_circle), border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => reason = value,
                    decoration: const InputDecoration(labelText: '📝 سبب الخصم', prefixIcon: Icon(Icons.warning), border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('❌ إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedEmployeeId.isEmpty) { _showErrorDialog('❌ اختر الموظف أولاً'); return; }
                  if (amount <= 0) { _showErrorDialog('❌ أدخل قيمة صحيحة'); return; }
                  
                  final employee = teamMembers.firstWhere((m) => m['id'].toString() == selectedEmployeeId);
                  
                  await _firestore.collection('deductions').add({
                    'employeeId': employee['id'],
                    'employeeName': employee['name'],
                    'amount': amount,
                    'reason': reason,
                    'type': 'deduction',
                    'date': Timestamp.now(),
                    'month': DateTime.now().month,
                    'year': DateTime.now().year,
                    'approvedBy': managerId,
                  });
                  
                  _showSuccessDialog('✅ تم خصم ${amount.toStringAsFixed(2)} جنيه من ${employee['name']}');
                  Navigator.pop(context);
                },
                child: const Text('💰 خصم'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('👨‍💼 لوحة المشرف', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeProfileScreen()))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            _loadTeamMembers();
            _loadTodayStats();
            _loadManagerAttendance();
            _loadPendingRequests();
          }),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '👥 فريقي', icon: Icon(Icons.people)),
            Tab(text: '📋 المهام', icon: Icon(Icons.task)),
            Tab(text: '📋 الطلبات', icon: Icon(Icons.pending_actions)),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyTeamTab(),
          _buildTasksTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }
  
  Widget _buildMyTeamTab() {
    if (teamMembers.isEmpty && !isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد موظفين في فريقك', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTeamMembers();
        await _loadTodayStats();
      },
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('👥', '$totalTeamMembers', 'الفريق'),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildStatItem('✅', '$presentToday', 'حاضر'),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildStatItem('⏰', '$lateToday', 'متأخر'),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildStatItem('❌', '$absentToday', 'غائب'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionCard('📋 مهمة', Icons.task, const Color(0xFF2196F3), _showAddTaskDialog),
                      _buildActionCard('🏖️ إجازة', Icons.beach_access, const Color(0xFF9C27B0), _showAddVacationDialog),
                      _buildActionCard('🎁 كفاءة', Icons.star, const Color(0xFFFF9800), _showAddBonusDialog),
                      _buildActionCard('💰 خصم', Icons.remove_circle, Colors.red, _showDeductionDialog),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                    child: Column(
                      children: [
                        const Padding(padding: EdgeInsets.all(16), child: Row(
                          children: [
                            Text('👥 أعضاء الفريق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Spacer(),
                            Text('الحضور اليوم', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )),
                        const Divider(height: 0),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: teamMembers.length,
                          itemBuilder: (context, index) {
                            final member = teamMembers[index];
                            final attendance = todayAttendance.firstWhere(
                              (a) => a['id'] == member['id'],
                              orElse: () => {'status': 'absent', 'checkInTime': '--:--'},
                            );
                            final status = attendance['status'];
                            Color statusColor = status == 'present' ? Colors.green : (status == 'late' ? Colors.orange : Colors.red);
                            String statusText = status == 'present' ? 'حاضر' : (status == 'late' ? 'متأخر' : 'غائب');
                            
                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withOpacity(0.1),
                                    child: Text(member['name'][0], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('🎖️ ${_getRoleName(member['role'])} | 💰 ${member['salary']} ج.م'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.admin_panel_settings, size: 18, color: Colors.blue),
                                        onPressed: () => _showUpdateRoleDialog(member),
                                        tooltip: 'تغيير الدور',
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor)),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showEmployeeDetails(member),
                                ),
                                if (index != teamMembers.length - 1) const Divider(height: 0, indent: 70),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tasks').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final tasks = snapshot.data!.docs;
        
        if (tasks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('📭 لا توجد مهام', style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('اضغط على زر "مهمة" لإضافة مهمة جديدة', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final data = tasks[index].data() as Map<String, dynamic>;
            final priority = data['priority'] ?? 'medium';
            final status = data['status'] ?? 'pending';
            
            Color priorityColor;
            IconData priorityIcon;
            if (priority == 'high') {
              priorityColor = Colors.red;
              priorityIcon = Icons.priority_high;
            } else if (priority == 'medium') {
              priorityColor = Colors.orange;
              priorityIcon = Icons.trending_flat;
            } else {
              priorityColor = Colors.green;
              priorityIcon = Icons.trending_down;
            }
            
            Color statusColor = status == 'completed' ? Colors.green : Colors.orange;
            String statusText = status == 'completed' ? 'مكتملة' : 'قيد التنفيذ';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: priorityColor.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(priorityIcon, color: priorityColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['title'] ?? 'بدون عنوان',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('👤 لـ: ${data['assignedToName']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (data['description'] != null && data['description'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(data['description'], style: const TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (data['dueDate'] != null)
                        Text('📅 تسليم: ${DateFormat('dd/MM/yyyy').format((data['dueDate'] as Timestamp).toDate())}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('📅 ${DateFormat('dd/MM HH:mm').format((data['createdAt'] as Timestamp).toDate())}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('requests').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final requests = snapshot.data!.docs;
        
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('📭 لا توجد طلبات', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            
            Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
            String statusText = status == 'approved' ? 'موافق' : (status == 'rejected' ? 'مرفوض' : 'قيد الانتظار');
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(data['type'] == 'إجازة' ? Icons.beach_access : Icons.attach_money, color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(child: Text(data['type'] ?? 'طلب', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
                      ),
                    ],
                  ),
                  if (data['reason'] != null) Text(data['reason'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format((data['createdAt'] as Timestamp).toDate()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatItem(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
  
  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showEmployeeDetails(Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E), borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: Text(employee['name'][0], style: const TextStyle(color: Colors.white, fontSize: 24))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employee['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(employee['email'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDetailRow(Icons.phone, '📱 رقم الهاتف', employee['phone'] ?? 'غير مسجل'),
                    _buildDetailRow(Icons.attach_money, '💰 الراتب', '${employee['salary']} جنيه'),
                    _buildDetailRow(Icons.beach_access, '🏖️ رصيد الإجازات', '${employee['vacationBalance']} يوم'),
                    _buildDetailRow(Icons.admin_panel_settings, '🎖️ الدور', _getRoleName(employee['role'])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 22),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF16213E), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
              child: Column(
                children: [
                  CircleAvatar(radius: 45, backgroundColor: Colors.white.withOpacity(0.1), child: const Icon(Icons.manage_accounts, size: 50, color: Colors.white)),
                  const SizedBox(height: 15),
                  Text(managerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('👨‍💼 مشرف', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 14)),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.dashboard, '📊 الرئيسية', true, () => _tabController.animateTo(0)),
            _buildDrawerItem(Icons.people, '👥 فريقي', false, () => _tabController.animateTo(0)),
            _buildDrawerItem(Icons.task, '📋 المهام', false, () => _tabController.animateTo(1)),
            _buildDrawerItem(Icons.beach_access, '🏖️ إجازة', false, _showAddVacationDialog),
            _buildDrawerItem(Icons.star, '🎁 كفاءة', false, _showAddBonusDialog),
            _buildDrawerItem(Icons.remove_circle, '💰 خصم', false, _showDeductionDialog),
            _buildDrawerItem(Icons.pending_actions, '📋 الطلبات', false, () => _tabController.animateTo(2)),
            _buildDrawerItem(Icons.assessment, '📈 التقارير', false, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen()));
            }),
            _buildDrawerItem(Icons.person, '👤 بروفايلي', false, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeProfileScreen()));
            }),
            const Spacer(),
            const Divider(color: Colors.white24),
            _buildDrawerItem(Icons.logout, '🚪 تسجيل خروج', false, () async {
              await _auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem(IconData icon, String title, bool isActive, VoidCallback? onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : (isActive ? const Color(0xFF8B5CF6) : Colors.white70), size: 26),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : (isActive ? const Color(0xFF8B5CF6) : Colors.white), fontSize: 15)),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}

class LocationResult {
  bool isWithinRange = false;
  double distance = 0;
  String message = "";
}