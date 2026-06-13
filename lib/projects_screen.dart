import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Controllers
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  
  // Location
  LatLng? _selectedLocation;
  MapController? _mapController;
  bool _isAddingProject = false;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;
  
  // Tab Controller
  late TabController _tabController;
  
  // Constants
  static const LatLng _defaultLocation = LatLng(30.0444, 31.2357); // Cairo
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedLocation = _defaultLocation;
    _mapController = MapController();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _projectNameController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
  
  // 🔍 البحث عن موقع
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&accept-language=ar'),
        headers: {'User-Agent': 'StaffTrackApp/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchResults = data;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        _showError('❌ خطأ في البحث');
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _showError('❌ خطأ: $e');
    }
  }
  
  // ✅ اختيار موقع من نتائج البحث
  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final placeName = result['display_name'];
    
    setState(() {
      _selectedLocation = LatLng(lat, lon);
      _showSearchResults = false;
      _searchController.text = placeName;
      _searchResults = [];
    });
    
    _mapController?.move(_selectedLocation!, 15);
    _addressController.text = placeName;
    _latitudeController.text = lat.toStringAsFixed(6);
    _longitudeController.text = lon.toStringAsFixed(6);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم تحديد: $placeName'), backgroundColor: Colors.green),
    );
  }
  
  // 📍 تحديث الموقع من الإحداثيات
  void _updateLocationFromCoordinates() {
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();
    
    if (latText.isEmpty || lngText.isEmpty) {
      _showError('❌ من فضلك أدخل خط العرض وخط الطول');
      return;
    }
    
    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    
    if (lat == null || lng == null) {
      _showError('❌ الإحداثيات غير صالحة');
      return;
    }
    
    setState(() {
      _selectedLocation = LatLng(lat, lng);
    });
    
    _mapController?.move(_selectedLocation!, 15);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم تحديث الموقع'), backgroundColor: Colors.green),
    );
  }
  
  Future<void> _addProject() async {
    if (_projectNameController.text.trim().isEmpty) {
      _showError('❌ من فضلك أدخل اسم المشروع');
      return;
    }
    
    if (_selectedLocation == null) {
      _showError('❌ من فضلك حدد موقع المشروع');
      return;
    }
    
    setState(() => _isAddingProject = true);
    
    try {
      Map<String, dynamic> projectData = {
        'name': _projectNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser!.uid,
      };
      
      await _firestore.collection('projects').add(projectData);
      
      _projectNameController.clear();
      _addressController.clear();
      _searchController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _selectedLocation = _defaultLocation;
        _searchResults = [];
        _showSearchResults = false;
      });
      _mapController?.move(_defaultLocation, 15);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة المشروع بنجاح'), backgroundColor: Colors.green),
        );
      }
      
    } catch (e) {
      _showError('❌ خطأ: $e');
    }
    
    setState(() => _isAddingProject = false);
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('المشاريع والمواقع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
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
            Tab(text: 'إضافة مشروع'),
            Tab(text: 'قائمة المشاريع'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddProjectTab(),
          _buildProjectsListTab(),
        ],
      ),
    );
  }
  
  Widget _buildAddProjectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 حقل البحث
          Container(
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
                      const Text('🔍 البحث عن موقع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'اكتب اسم مدينة، شارع، أو مكان...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF999999)),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2)),
                        ),
                        onChanged: _searchLocation,
                      ),
                      
                      if (_showSearchResults && _searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              final name = result['display_name'] ?? 'بدون اسم';
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on, color: Color(0xFF2196F3), size: 20),
                                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 📍 إدخال الإحداثيات
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📍 أو أدخل الإحداثيات يدوياً', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latitudeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'خط العرض (Latitude)',
                            prefixIcon: Icon(Icons.map, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _longitudeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'خط الطول (Longitude)',
                            prefixIcon: Icon(Icons.map, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.my_location, color: Color(0xFF2196F3)),
                        onPressed: _updateLocationFromCoordinates,
                        tooltip: 'تحديث الموقع',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // نموذج إضافة مشروع
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildTextField(controller: _projectNameController, label: 'اسم المشروع', hint: 'مثال: المشروع الأول - المعادي', icon: Icons.business),
                _buildDivider(),
                _buildTextField(controller: _addressController, label: 'العنوان', hint: 'العنوان التفصيلي للمشروع', icon: Icons.location_on),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 🗺️ الخريطة
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('🗺️ معاينة الموقع على الخريطة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                ),
                SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation ?? _defaultLocation,
                        initialZoom: 15,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLocation = point;
                          });
                          _latitudeController.text = point.latitude.toStringAsFixed(6);
                          _longitudeController.text = point.longitude.toStringAsFixed(6);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.staff_track.app',
                        ),
                        if (_selectedLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 80,
                                height: 80,
                                point: _selectedLocation!,
                                child: const Icon(Icons.location_on, color: Color(0xFFE94560), size: 40),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedLocation != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF2196F3), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الإحداثيات: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isAddingProject ? null : _addProject,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isAddingProject
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إضافة مشروع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ قائمة المشاريع
  Widget _buildProjectsListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('خطأ: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final projects = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isActive'] == true;
        }).toList();
        
        if (projects.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business, size: 64, color: Color(0xFFCCCCCC)),
                SizedBox(height: 16),
                Text('لا توجد مشاريع مسجلة'),
                SizedBox(height: 8),
                Text('اضغط على تبويب "إضافة مشروع" لإضافة مشروع جديد'),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final doc = projects[index];
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final String name = data['name'] ?? 'بدون اسم';
            final String address = data['address'] ?? 'بدون عنوان';
            final double? lat = data['latitude']?.toDouble();
            final double? lng = data['longitude']?.toDouble();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.business, color: Color(0xFF2196F3)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(address, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    if (lat != null && lng != null) ...[
                      const SizedBox(height: 2),
                      Text('📍 ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFE94560)),
                  onPressed: () => _confirmDeleteProject(id, name),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  void _confirmDeleteProject(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المشروع "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => _deleteProject(id),
            child: const Text('حذف', style: TextStyle(color: Color(0xFFE94560))),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteProject(String id) async {
    try {
      await _firestore.collection('projects').doc(id).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حذف المشروع'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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