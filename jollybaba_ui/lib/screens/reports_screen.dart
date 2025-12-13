// lib/screens/reports_screen.dart
// Reports section with sidebar navigation - Premium UI with stats, filters, shimmer

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls hide Border;
import 'dart:html' as html show AnchorElement, Blob, Url;

import '../services/ticket_service.dart';
import '../services/khatabook_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';
import 'excel_view_screen.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// New premium widgets
import '../widgets/report_stat_card.dart';
import '../widgets/shimmer_table.dart';
import '../widgets/date_range_filter.dart';
import '../widgets/report_detail_drawer.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/download_button.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Data for tickets report
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _loading = false;
  
  // Ticket filters
  String _technicianFilter = 'ALL';
  String _statusFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  List<String> _technicians = [];
  
  // Khatabook data
  List<Map<String, dynamic>> _khatabook = [];
  List<Map<String, dynamic>> _filteredKhatabook = [];
  bool _khatabookLoading = false;
  String _khataStatusFilter = 'ALL';
  final TextEditingController _khataSearchController = TextEditingController();
  
  // Khatabook edit mode state
  bool _khataEditMode = false;
  int? _editingKhataRow;
  int? _editingKhataCol;
  final TextEditingController _khataEditController = TextEditingController();
  final FocusNode _khataEditFocusNode = FocusNode();
  final Map<String, Map<String, dynamic>> _editedKhataRows = {}; // keyed by unique id
  bool _hasUnsavedKhataChanges = false;
  
  // Customers data
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _customersLoading = false;
  final TextEditingController _customerSearchController = TextEditingController();
  
  // Date range filters
  DateTime? _ticketDateStart;
  DateTime? _ticketDateEnd;
  DatePreset _ticketDatePreset = DatePreset.all;
  
  DateTime? _khataDateStart;
  DateTime? _khataDateEnd;
  DatePreset _khataDatePreset = DatePreset.all;
  
  DateTime? _customerDateStart;
  DateTime? _customerDateEnd;
  DatePreset _customerDatePreset = DatePreset.all;
  
  // Download button keys for animation control
  final GlobalKey<AnimatedDownloadButtonState> _ticketDownloadKey = GlobalKey();
  final GlobalKey<AnimatedDownloadButtonState> _khataDownloadKey = GlobalKey();
  final GlobalKey<AnimatedDownloadButtonState> _customerDownloadKey = GlobalKey();
  
  // Inventory count for badge
  int _inventoryCount = 0;


  // Unified Green Theme
  static const Color _primaryColor = Color(0xFF6D5DF6);
  static const Color _primaryDark = Color(0xFF0A5C38);
  static const Color _borderColor = Color(0xFFE0E6ED);
  static const Color _headerBg = Color(0xFFF0F4F8);

  final List<_ReportTab> _tabs = const [
    _ReportTab(
      title: 'Inventory',
      icon: Icons.inventory_2_rounded,
      description: 'Excel View - Edit & Download',
    ),
    _ReportTab(
      title: 'Tickets',
      icon: Icons.confirmation_number_rounded,
      description: 'All repair tickets',
    ),
    _ReportTab(
      title: 'Khatabook',
      icon: Icons.menu_book_rounded,
      description: 'Credits & settlements',
    ),
    _ReportTab(
      title: 'Customers',
      icon: Icons.people_alt_rounded,
      description: 'All customers unified',
    ),
  ];

  // Tickets table columns
  final List<Map<String, dynamic>> _ticketColumns = [
    {'key': 'id', 'label': 'ID', 'width': 60.0},
    {'key': 'created_at', 'label': 'DATE', 'width': 100.0},
    {'key': 'customer_name', 'label': 'CUSTOMER', 'width': 130.0},
    {'key': 'mobile_number', 'label': 'PHONE', 'width': 110.0},
    {'key': 'device_model', 'label': 'DEVICE', 'width': 140.0},
    {'key': 'issue_description', 'label': 'ISSUE', 'width': 180.0},
    {'key': 'status', 'label': 'STATUS', 'width': 100.0},
    {'key': 'assigned_technician', 'label': 'ASSIGNED TO', 'width': 120.0},
    {'key': 'estimated_cost', 'label': 'EST. COST', 'width': 95.0},
  ];
  
  // Khatabook table columns
  final List<Map<String, dynamic>> _khataColumns = [
    {'key': 'entryDate', 'label': 'DATE', 'width': 100.0},
    {'key': 'name', 'label': 'NAME', 'width': 140.0},
    {'key': 'mobile', 'label': 'MOBILE', 'width': 115.0},
    {'key': 'amount', 'label': 'AMOUNT', 'width': 100.0},
    {'key': 'paid', 'label': 'PAID', 'width': 100.0},
    {'key': 'remaining', 'label': 'REMAINING', 'width': 100.0},
    {'key': 'status', 'label': 'STATUS', 'width': 90.0},
    {'key': 'description', 'label': 'DESCRIPTION', 'width': 180.0},
  ];
  
  // Customers table columns
  final List<Map<String, dynamic>> _customerColumns = [
    {'key': 'name', 'label': 'NAME', 'width': 150.0},
    {'key': 'phone', 'label': 'PHONE', 'width': 120.0},
    {'key': 'ticketCount', 'label': 'TICKETS', 'width': 80.0},
    {'key': 'purchaseCount', 'label': 'PURCHASES', 'width': 95.0},
    {'key': 'totalSpent', 'label': 'TOTAL SPENT', 'width': 110.0},
    {'key': 'khataCount', 'label': 'KHATA', 'width': 70.0},
    {'key': 'source', 'label': 'SOURCE', 'width': 130.0},
    {'key': 'lastActivity', 'label': 'LAST ACTIVITY', 'width': 110.0},
  ];

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _loadKhatabook();
    _loadCustomers();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _searchController.dispose();
    _khataSearchController.dispose();
    _customerSearchController.dispose();
    _khataEditController.dispose();
    _khataEditFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      final ticketsRaw = await TicketService.fetchTickets(page: 1, perPage: 500);
      _tickets = ticketsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      
      // Extract unique technicians
      final techSet = <String>{};
      for (final t in _tickets) {
        final tech = t['assigned_technician']?.toString().trim() ?? '';
        if (tech.isNotEmpty) techSet.add(tech);
      }
      _technicians = techSet.toList()..sort();
      
      _applyFilters();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading tickets: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_tickets);
    
    // Filter by date range
    if (_ticketDateStart != null && _ticketDateEnd != null) {
      result = result.where((t) {
        final rawDate = t['created_at'] ?? t['createdAt'];
        if (rawDate == null) return true;
        try {
          final dt = DateTime.parse(rawDate.toString());
          return dt.isAfter(_ticketDateStart!.subtract(const Duration(days: 1))) &&
                 dt.isBefore(_ticketDateEnd!.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }
    
    // Filter by technician
    if (_technicianFilter != 'ALL') {
      result = result.where((t) {
        final tech = t['assigned_technician']?.toString().trim() ?? '';
        return tech.toLowerCase() == _technicianFilter.toLowerCase();
      }).toList();
    }
    
    // Filter by status
    if (_statusFilter != 'ALL') {
      result = result.where((t) {
        final status = t['status']?.toString().toLowerCase() ?? '';
        return status == _statusFilter.toLowerCase();
      }).toList();
    }
    
    // Search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((t) {
        final customer = t['customer_name']?.toString().toLowerCase() ?? '';
        final phone = t['mobile_number']?.toString() ?? '';
        final device = t['device_model']?.toString().toLowerCase() ?? '';
        final issue = t['issue_description']?.toString().toLowerCase() ?? '';
        return customer.contains(query) || phone.contains(query) || 
               device.contains(query) || issue.contains(query);
      }).toList();
    }
    
    setState(() => _filteredTickets = result);
  }
  
  Future<void> _loadKhatabook() async {
    setState(() => _khatabookLoading = true);
    try {
      // Use same data source as Khatabook screen - inventory SOLD items + manual entries
      final soldFuture = http.get(
        Uri.parse('${AppConfig.baseUrl}/api/inventory').replace(queryParameters: {
          'status': 'SOLD',
          'sort': 'date',
          'order': 'desc',
        }),
        headers: await _getAuthHeaders(),
      );
      final manualFuture = KhatabookService.listEntries();
      
      final soldResp = await soldFuture;
      final manualRaw = await manualFuture;
      
      List<Map<String, dynamic>> entries = [];
      
      if (soldResp.statusCode == 200) {
        final data = jsonDecode(soldResp.body);
        final items = (data['items'] as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        
        // Add inventory items with parsed paid values
        for (final item in items) {
          final total = _getKhataTotal(item);
          final paid = _getKhataPaid(item);
          final remaining = (total - paid).clamp(0.0, double.infinity);
          
          entries.add({
            'entryDate': item['sell_date'] ?? item['sellDate'] ?? item['created_at'],
            'name': item['customer_name'] ?? item['customer'] ?? '-',
            'mobile': item['customer_mobile'] ?? item['mobile'] ?? '-',
            'amount': total,
            'paid': paid,
            'remaining': remaining,
            'description': item['model'] ?? item['remarks'] ?? '-',
            'is_inventory': true,
            'sr_no': item['sr_no'],
          });
        }
      }
      
      // Add manual khatabook entries
      for (final entry in manualRaw) {
        final amount = (entry['amount'] as num?)?.toDouble() ?? (entry['manual_amount'] as num?)?.toDouble() ?? 0;
        final paid = (entry['paid'] as num?)?.toDouble() ?? (entry['manual_paid'] as num?)?.toDouble() ?? 0;
        entries.add({
          'entryDate': entry['entryDate'] ?? entry['entry_date'] ?? entry['created_at'],
          'name': entry['name'] ?? '-',
          'mobile': entry['mobile'] ?? '-',
          'amount': amount,
          'paid': paid,
          'remaining': (amount - paid).clamp(0.0, double.infinity),
          'description': entry['description'] ?? entry['manual_description'] ?? '-',
          'is_manual': true,
        });
      }
      
      _khatabook = entries;
      _applyKhataFilters();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading khatabook: $e');
    } finally {
      if (mounted) setState(() => _khatabookLoading = false);
    }
  }
  
  // Helper to get auth headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService().getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }
  
  // Parse total amount (matches Khatabook screen logic)
  double _getKhataTotal(Map<String, dynamic> r) {
    if (r['is_manual'] == true || r.containsKey('manual_amount')) {
      final amount = r['manual_amount'];
      if (amount is num) return amount.toDouble();
      return double.tryParse((amount ?? '').toString()) ?? 0.0;
    }
    final total = r['sell_amount'];
    if (total is num) return total.toDouble();
    return double.tryParse((total ?? '').toString().replaceAll(',', '')) ?? 0.0;
  }
  
  // Parse paid amount from remarks (matches Khatabook screen logic)
  double _getKhataPaid(Map<String, dynamic> r) {
    if (r['is_manual'] == true || r.containsKey('manual_paid')) {
      final paid = r['manual_paid'];
      if (paid is num) return paid.toDouble();
      return double.tryParse((paid ?? '').toString()) ?? 0.0;
    }
    final remarks = (r['remarks'] ?? '').toString();
    final regex = RegExp(r'Paid\s*:?.*?₹?\s*([0-9][0-9,]*(?:\.[0-9]+)?)', caseSensitive: false);
    final matches = regex.allMatches(remarks).toList();
    if (matches.isEmpty) return 0.0;
    final last = matches.last.group(1) ?? '0';
    return double.tryParse(last.replaceAll(',', '')) ?? 0.0;
  }
  
  // Khatabook editing functions
  void _toggleKhataEditMode() {
    if (_khataEditMode && _hasUnsavedKhataChanges) {
      // Ask to save before exiting
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Do you want to save them?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _khataEditMode = false;
                  _editedKhataRows.clear();
                  _hasUnsavedKhataChanges = false;
                  _editingKhataRow = null;
                  _editingKhataCol = null;
                });
              },
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveKhataChanges();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _khataEditMode = !_khataEditMode;
        if (!_khataEditMode) {
          _editingKhataRow = null;
          _editingKhataCol = null;
        }
      });
    }
  }
  
  String _getKhataRowId(Map<String, dynamic> row) {
    if (row['is_manual'] == true) {
      return 'manual_${row['id'] ?? row['manual_id'] ?? ''}';
    }
    return 'inv_${row['sr_no'] ?? ''}';
  }
  
  bool _isKhataColEditable(String key, Map<String, dynamic> row) {
    // Paid is always editable
    if (key == 'paid') return true;
    // For manual entries, more fields are editable
    if (row['is_manual'] == true) {
      return ['name', 'mobile', 'amount', 'description'].contains(key);
    }
    return false;
  }
  
  void _onKhataCellTap(int rowIdx, int colIdx) {
    if (!_khataEditMode) return;
    
    final col = _khataColumns[colIdx];
    final key = col['key'] as String;
    final row = _filteredKhatabook[rowIdx];
    
    // Check if column is editable for this row type
    if (!_isKhataColEditable(key, row)) return;
    
    setState(() {
      _editingKhataRow = rowIdx;
      _editingKhataCol = colIdx;
    });
    
    // Populate editor with current value
    final currentValue = row[key]?.toString() ?? '';
    _khataEditController.text = currentValue;
    
    Future.delayed(const Duration(milliseconds: 50), () {
      _khataEditFocusNode.requestFocus();
      _khataEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _khataEditController.text.length,
      );
    });
  }
  
  void _onKhataCellEditComplete(int rowIdx, int colIdx) {
    final col = _khataColumns[colIdx];
    final key = col['key'] as String;
    final row = _filteredKhatabook[rowIdx];
    final rowId = _getKhataRowId(row);
    
    // Parse value based on column type
    dynamic val;
    if (['amount', 'paid'].contains(key)) {
      val = double.tryParse(_khataEditController.text.replaceAll('₹', '').replaceAll(',', '')) ?? 0.0;
    } else {
      val = _khataEditController.text.trim();
    }
    
    // Update local data
    _filteredKhatabook[rowIdx][key] = val;
    
    // Track edit
    _editedKhataRows.putIfAbsent(rowId, () => Map<String, dynamic>.from(row));
    _editedKhataRows[rowId]![key] = val;
    
    // Recalculate remaining if paid changed
    if (key == 'paid') {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final newPaid = val is num ? val.toDouble() : 0.0;
      _filteredKhatabook[rowIdx]['remaining'] = (amount - newPaid).clamp(0.0, double.infinity);
    }
    
    setState(() {
      _hasUnsavedKhataChanges = true;
      _editingKhataRow = null;
      _editingKhataCol = null;
    });
  }
  
  Future<void> _saveKhataChanges() async {
    if (_editedKhataRows.isEmpty) return;
    
    Get.showSnackbar(const GetSnackBar(
      message: 'Saving changes...',
      showProgressIndicator: true,
      isDismissible: false,
      duration: Duration(minutes: 1),
    ));
    
    int successCount = 0;
    int errorCount = 0;
    
    for (final entry in _editedKhataRows.entries) {
      final rowId = entry.key;
      final changes = entry.value;
      
      try {
        if (rowId.startsWith('manual_')) {
          // Update manual khatabook entry
          final idStr = rowId.replaceFirst('manual_', '');
          final id = int.tryParse(idStr);
          if (id != null) {
            await KhatabookService.updateEntry(id, {
              if (changes.containsKey('name')) 'name': changes['name'],
              if (changes.containsKey('mobile')) 'mobile': changes['mobile'],
              if (changes.containsKey('amount')) 'amount': changes['amount'],
              if (changes.containsKey('paid')) 'paid': changes['paid'],
              if (changes.containsKey('description')) 'description': changes['description'],
            });
            successCount++;
          }
        } else {
          // Update inventory item remarks for paid amount
          final srNo = int.tryParse(rowId.replaceFirst('inv_', ''));
          if (srNo != null && changes.containsKey('paid')) {
            final paid = changes['paid'] as double;
            // Get current remarks and append/update paid
            final currentRemarks = changes['remarks']?.toString() ?? '';
            final newRemarks = _updateRemarksWithPaid(currentRemarks, paid);
            await InventoryService.updateRemarks(srNo, newRemarks);
            successCount++;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error saving khata row $rowId: $e');
        errorCount++;
      }
    }
    
    Get.closeAllSnackbars();
    
    if (errorCount == 0) {
      Get.snackbar('Saved', '$successCount entries updated successfully',
        backgroundColor: Colors.green.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
      setState(() {
        _editedKhataRows.clear();
        _hasUnsavedKhataChanges = false;
        _khataEditMode = false;
      });
      // Reload to get fresh data
      _loadKhatabook();
    } else {
      Get.snackbar('Partial Save', '$successCount saved, $errorCount failed',
        backgroundColor: Colors.orange.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  String _updateRemarksWithPaid(String currentRemarks, double paid) {
    final paidStr = 'Paid: ₹${paid.toStringAsFixed(0)}';
    // Check if there's already a Paid entry and update it
    final regex = RegExp(r'Paid\s*:\s*₹?\s*[0-9,]+', caseSensitive: false);
    if (regex.hasMatch(currentRemarks)) {
      return currentRemarks.replaceAll(regex, paidStr);
    }
    // Otherwise append
    return currentRemarks.isEmpty ? paidStr : '$currentRemarks | $paidStr';
  }
  
  void _applyKhataFilters() {
    List<Map<String, dynamic>> result = List.from(_khatabook);
    
    // Filter by date range
    if (_khataDateStart != null && _khataDateEnd != null) {
      result = result.where((e) {
        final rawDate = e['entryDate'] ?? e['entry_date'];
        if (rawDate == null) return true;
        try {
          final dt = DateTime.parse(rawDate.toString());
          return dt.isAfter(_khataDateStart!.subtract(const Duration(days: 1))) &&
                 dt.isBefore(_khataDateEnd!.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }
    
    // Filter by status (Settled/Pending)
    if (_khataStatusFilter != 'ALL') {
      result = result.where((e) {
        final amount = (e['amount'] as num?)?.toDouble() ?? 0;
        final paid = (e['paid'] as num?)?.toDouble() ?? 0;
        final remaining = amount - paid;
        final status = remaining <= 0 ? 'Settled' : 'Pending';
        return status.toLowerCase() == _khataStatusFilter.toLowerCase();
      }).toList();
    }
    
    // Search filter
    final query = _khataSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((e) {
        final name = e['name']?.toString().toLowerCase() ?? '';
        final mobile = e['mobile']?.toString() ?? '';
        final desc = e['description']?.toString().toLowerCase() ?? '';
        return name.contains(query) || mobile.contains(query) || desc.contains(query);
      }).toList();
    }
    
    setState(() => _filteredKhatabook = result);
  }
  
  Future<void> _loadCustomers() async {
    setState(() => _customersLoading = true);
    try {
      // Get auth headers like KhatabookService does
      final token = await AuthService().getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      
      final url = '${AppConfig.baseUrl}/api/customers/all';
      if (kDebugMode) debugPrint('Loading customers from: $url');
      
      final response = await http.get(Uri.parse(url), headers: headers);
      if (kDebugMode) debugPrint('Customers response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _customers = (data['customers'] as List? ?? []).cast<Map<String, dynamic>>();
        if (kDebugMode) debugPrint('Loaded ${_customers.length} customers');
        _applyCustomerFilters();
      } else {
        if (kDebugMode) debugPrint('Customers API error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading customers: $e');
    } finally {
      if (mounted) setState(() => _customersLoading = false);
    }
  }
  
  void _applyCustomerFilters() {
    List<Map<String, dynamic>> result = List.from(_customers);
    
    // Search filter
    final query = _customerSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((c) {
        final name = c['name']?.toString().toLowerCase() ?? '';
        final phone = c['phone']?.toString() ?? '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
    
    setState(() => _filteredCustomers = result);
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Reports',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 17 : 19,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      endDrawer: isMobile ? _buildDrawer() : null,
      body: Row(
        children: [
          // Sidebar for tablet/desktop
          if (!isMobile) _buildSidebar(false),
          
          // Divider
          if (!isMobile)
            Container(width: 1, color: _borderColor),
          
          // Main content area
          Expanded(child: _buildReportContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDrawer) {
    return Container(
      width: isDrawer ? double.infinity : 240,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDrawer)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Reports',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'SELECT REPORT',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          ...List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = _selectedIndex == index;
            
            // Get count for badge
            String? badgeText;
            if (index == 0 && _inventoryCount > 0) {
              badgeText = _inventoryCount.toString();
            } else if (index == 1 && _tickets.isNotEmpty) {
              badgeText = _tickets.length.toString();
            } else if (index == 2 && _khatabook.isNotEmpty) {
              badgeText = _khatabook.length.toString();
            } else if (index == 3 && _customers.isNotEmpty) {
              badgeText = _customers.length.toString();
            }
            
            return InkWell(
              onTap: () {
                setState(() => _selectedIndex = index);
                if (isDrawer) Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primaryColor.withOpacity(0.25) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Left accent bar for selected
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryColor.withOpacity(0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        tab.icon,
                        color: isSelected ? _primaryColor : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? _primaryColor : const Color(0xFF2A2E45),
                            ),
                          ),
                          Text(
                            tab.description,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge with count
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryColor : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ).animate(delay: (index * 80).ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.1, curve: Curves.easeOut);
          }),
          
          const Spacer(),
          
          // Footer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click to view reports',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: _buildSidebar(true),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedIndex) {
      case 0:
        // Use the full ExcelViewScreen embedded
        return const ExcelViewScreen(embedded: true);
      case 1:
        return _buildTicketsReport();
      case 2:
        return _buildKhatabookReport();
      case 3:
        return _buildCustomersReport();
      default:
        return const Center(child: Text('Select a report'));
    }
  }

  Widget _buildTicketsReport() {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;
    
    // Show shimmer loading
    if (_loading) {
      return const ShimmerTable(rowCount: 10, columnCount: 5, showStats: true);
    }
    
    return Column(
      children: [
        // Date filter row
        _buildDateFilterRow(
          preset: _ticketDatePreset,
          onChanged: (start, end, preset) {
            setState(() {
              _ticketDateStart = start;
              _ticketDateEnd = end;
              _ticketDatePreset = preset;
            });
            _applyFilters();
          },
        ),
        
        // Filter bar
        _buildTicketFilters(),
        
        // Data table
        Expanded(
          child: _buildDataTable(
            title: 'Tickets Report',
            subtitle: '${_filteredTickets.length} of ${_tickets.length} tickets',
            columns: _ticketColumns,
            data: _filteredTickets,
            getCellValue: _getTicketCellValue,
            onRefresh: _loadTickets,
            onDownload: _downloadTicketsExcel,
            downloadKey: _ticketDownloadKey,
            onRowTap: (row) => ReportDetailDrawer.showAsBottomSheet(
              context, data: row, type: 'ticket', primaryColor: _primaryColor,
            ),
          ),
        ),
      ],
    );
  }
  
  // Format large numbers compactly
  String _formatCompact(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
  
  // Build date filter row
  Widget _buildDateFilterRow({
    required DatePreset preset,
    required Function(DateTime?, DateTime?, DatePreset) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            'Date:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DateRangeFilter(
                initialPreset: preset,
                primaryColor: _primaryColor,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }
  
  Widget _buildTicketFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: 200,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _primaryColor),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
          
          // Technician filter
          _filterDropdown(
            label: 'Technician',
            value: _technicianFilter,
            items: ['ALL', ..._technicians],
            onChanged: (v) {
              _technicianFilter = v ?? 'ALL';
              _applyFilters();
            },
          ),
          
          // Status filter
          _filterDropdown(
            label: 'Status',
            value: _statusFilter,
            items: ['ALL', 'Pending', 'Repaired', 'Delivered', 'Cancelled'],
            onChanged: (v) {
              _statusFilter = v ?? 'ALL';
              _applyFilters();
            },
          ),
          
          // Clear filters
          if (_technicianFilter != 'ALL' || _statusFilter != 'ALL' || _searchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _technicianFilter = 'ALL';
                _statusFilter = 'ALL';
                _searchController.clear();
                _applyFilters();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('Clear', style: GoogleFonts.poppins(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
  
  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(
              item == 'ALL' ? '$label: All' : item,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          )).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2A2E45)),
        ),
      ),
    );
  }
  
  Widget _buildKhatabookReport() {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;
    
    // Show shimmer loading
    if (_khatabookLoading) {
      return const ShimmerTable(rowCount: 10, columnCount: 5, showStats: true);
    }
    
    return Column(
      children: [
        // Edit mode toolbar
        _buildKhataEditToolbar(),
        
        // Date filter row
        _buildDateFilterRow(
          preset: _khataDatePreset,
          onChanged: (start, end, preset) {
            setState(() {
              _khataDateStart = start;
              _khataDateEnd = end;
              _khataDatePreset = preset;
            });
            _applyKhataFilters();
          },
        ),
        
        // Filter bar
        _buildKhataFilters(),
        
        // Data table - editable version
        Expanded(
          child: _buildEditableKhataTable(),
        ),
      ],
    );
  }
  
  Widget _buildKhataEditToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _khataEditMode ? Colors.amber.shade50 : Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          // Edit mode toggle
          ElevatedButton.icon(
            onPressed: _toggleKhataEditMode,
            icon: Icon(_khataEditMode ? Icons.close : Icons.edit, size: 18),
            label: Text(_khataEditMode ? 'Exit Edit' : 'Edit Mode', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _khataEditMode ? Colors.grey.shade700 : _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          
          if (_khataEditMode) ...[
            const SizedBox(width: 12),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _hasUnsavedKhataChanges ? _saveKhataChanges : null,
              icon: const Icon(Icons.save, size: 18),
              label: Text('Save (${_editedKhataRows.length})', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Discard button
            TextButton.icon(
              onPressed: _hasUnsavedKhataChanges ? () {
                setState(() {
                  _editedKhataRows.clear();
                  _hasUnsavedKhataChanges = false;
                });
                _loadKhatabook(); // Reload original data
              } : null,
              icon: const Icon(Icons.undo, size: 18),
              label: Text('Discard', style: GoogleFonts.poppins()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
              ),
            ),
          ],
          
          const Spacer(),
          
          // Hint text
          if (_khataEditMode)
            Text(
              'Click cells to edit • Paid field editable for all entries',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            
          // Download button
          if (!_khataEditMode)
            AnimatedDownloadButton(
              key: _khataDownloadKey,
              onPressed: _downloadKhatabookExcel,
              primaryColor: _primaryColor,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
  
  Widget _buildEditableKhataTable() {
    if (_filteredKhatabook.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No entries found', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadKhatabook,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    final totalWidth = _khataColumns.fold<double>(0, (sum, c) => sum + (c['width'] as double));
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth + 50, // Extra for row numbers
        child: Column(
          children: [
            // Header row
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: _headerBg,
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(
                children: [
                  // Row number header
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text('#', style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                  ..._khataColumns.map((col) => Container(
                    width: col['width'] as double,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(col['label'] as String, style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  )),
                ],
              ),
            ),
            
            // Data rows
            Expanded(
              child: ListView.builder(
                itemCount: _filteredKhatabook.length,
                itemBuilder: (context, rowIdx) => _buildEditableKhataRow(rowIdx),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEditableKhataRow(int rowIdx) {
    final row = _filteredKhatabook[rowIdx];
    final rowId = _getKhataRowId(row);
    final isEdited = _editedKhataRows.containsKey(rowId);
    final isManual = row['is_manual'] == true;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isEdited ? Colors.amber.shade50 : (rowIdx.isEven ? Colors.white : _headerBg),
        border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Row number
          Container(
            width: 50,
            alignment: Alignment.center,
            child: Text('${rowIdx + 1}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ),
          // Data cells
          ..._khataColumns.asMap().entries.map((entry) {
            final colIdx = entry.key;
            final col = entry.value;
            final key = col['key'] as String;
            final isEditing = _editingKhataRow == rowIdx && _editingKhataCol == colIdx;
            final isEditable = _khataEditMode && _isKhataColEditable(key, row);
            
            final value = _getKhataCellValue(row, key);
            
            // Status column special styling
            Widget? specialWidget;
            if (key == 'status') {
              final isSettled = value == 'Settled';
              specialWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSettled ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(value, style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600, 
                  color: isSettled ? Colors.green.shade700 : Colors.orange.shade700)),
              );
            }
            
            return GestureDetector(
              onTap: isEditable ? () => _onKhataCellTap(rowIdx, colIdx) : null,
              child: Container(
                width: col['width'] as double,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: isEditable && _khataEditMode 
                    ? Border.all(color: _primaryColor.withOpacity(0.3), width: 1)
                    : null,
                  color: isEditing ? Colors.blue.shade50 : null,
                ),
                child: isEditing
                  ? TextField(
                      controller: _khataEditController,
                      focusNode: _khataEditFocusNode,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _onKhataCellEditComplete(rowIdx, colIdx),
                      onEditingComplete: () => _onKhataCellEditComplete(rowIdx, colIdx),
                    )
                  : specialWidget ?? Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 12, 
                        color: isEditable && _khataEditMode ? _primaryColor : Colors.black87,
                        decoration: isEditable && _khataEditMode ? TextDecoration.underline : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildKhataFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: 200,
            height: 38,
            child: TextField(
              controller: _khataSearchController,
              onChanged: (_) => _applyKhataFilters(),
              decoration: InputDecoration(
                hintText: 'Search name/mobile...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _primaryColor),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
          
          // Status filter
          _filterDropdown(
            label: 'Status',
            value: _khataStatusFilter,
            items: ['ALL', 'Pending', 'Settled'],
            onChanged: (v) {
              _khataStatusFilter = v ?? 'ALL';
              _applyKhataFilters();
            },
          ),
          
          // Clear filters
          if (_khataStatusFilter != 'ALL' || _khataSearchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _khataStatusFilter = 'ALL';
                _khataSearchController.clear();
                _applyKhataFilters();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('Clear', style: GoogleFonts.poppins(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
  
  String _getKhataCellValue(Map<String, dynamic> row, String key) {
    switch (key) {
      case 'entryDate':
        final raw = row['entryDate'] ?? row['entry_date'] ?? '';
        if (raw is String && raw.isNotEmpty) {
          try {
            final dt = DateTime.parse(raw);
            return DateFormat('dd/MM/yy').format(dt);
          } catch (_) {}
        }
        return '-';
      case 'amount':
      case 'paid':
        final v = row[key];
        if (v == null) return '₹0';
        return '₹${(v as num).toStringAsFixed(0)}';
      case 'remaining':
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final paid = (row['paid'] as num?)?.toDouble() ?? 0;
        final remaining = amount - paid;
        return '₹${remaining.toStringAsFixed(0)}';
      case 'status':
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final paid = (row['paid'] as num?)?.toDouble() ?? 0;
        return (amount - paid) <= 0 ? 'Settled' : 'Pending';
      default:
        return (row[key] ?? '-').toString();
    }
  }
  
  void _downloadKhatabookExcel() {
    if (_filteredKhatabook.isEmpty) {
      Get.snackbar('No Data', 'No entries to download', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Khatabook'];
      excel.delete('Sheet1');
      
      // Style for header - use green theme
      final headerStyle = xls.CellStyle(
        backgroundColorHex: xls.ExcelColor.fromHexString('#0D7C4A'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
      );
      
      // Headers
      final headers = ['#', 'Date', 'Name', 'Mobile', 'Amount', 'Paid', 'Remaining', 'Status', 'Description'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Data rows
      for (var i = 0; i < _filteredKhatabook.length; i++) {
        final row = _filteredKhatabook[i];
        final rowIdx = i + 1;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final paid = (row['paid'] as num?)?.toDouble() ?? 0;
        final remaining = amount - paid;
        
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = xls.IntCellValue(i + 1);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xls.TextCellValue(_getKhataCellValue(row, 'entryDate'));
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xls.TextCellValue(row['name']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xls.TextCellValue(row['mobile']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xls.DoubleCellValue(amount);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xls.DoubleCellValue(paid);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = xls.DoubleCellValue(remaining);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value = xls.TextCellValue(remaining <= 0 ? 'Settled' : 'Pending');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xls.TextCellValue(row['description']?.toString() ?? '-');
      }
      
      // Set column widths
      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 12);
      sheet.setColumnWidth(2, 20);
      sheet.setColumnWidth(3, 14);
      sheet.setColumnWidth(4, 12);
      sheet.setColumnWidth(5, 12);
      sheet.setColumnWidth(6, 12);
      sheet.setColumnWidth(7, 10);
      sheet.setColumnWidth(8, 30);
      
      // Download
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        html.AnchorElement()
          ..href = url
          ..download = 'Khatabook_Report_$dateStr.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        
        Get.snackbar('Downloaded', 'Khatabook Excel exported successfully', 
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Khatabook Excel download error: $e');
      Get.snackbar('Error', 'Failed to download Excel', snackPosition: SnackPosition.BOTTOM);
    }
  }
  
  Widget _buildCustomersReport() {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;
    
    // Show shimmer loading
    if (_customersLoading) {
      return const ShimmerTable(rowCount: 10, columnCount: 5, showStats: true);
    }
    
    return Column(
      children: [
        // Filter bar
        _buildCustomerFilters(),
        
        // Data table
        Expanded(
          child: _buildDataTable(
            title: 'Customers Report',
            subtitle: '${_filteredCustomers.length} of ${_customers.length} customers',
            columns: _customerColumns,
            data: _filteredCustomers,
            getCellValue: _getCustomerCellValue,
            onRefresh: _loadCustomers,
            onDownload: _downloadCustomersExcel,
            downloadKey: _customerDownloadKey,
            onRowTap: (row) => ReportDetailDrawer.showAsBottomSheet(
              context, data: row, type: 'customer', primaryColor: _primaryColor,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCustomerFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: 250,
            height: 38,
            child: TextField(
              controller: _customerSearchController,
              onChanged: (_) => _applyCustomerFilters(),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _primaryColor),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
          
          // Clear filters
          if (_customerSearchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _customerSearchController.clear();
                _applyCustomerFilters();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('Clear', style: GoogleFonts.poppins(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
  
  String _getCustomerCellValue(Map<String, dynamic> row, String key) {
    switch (key) {
      case 'name':
        return row['name']?.toString() ?? '-';
      case 'phone':
        return row['phone']?.toString().isNotEmpty == true ? row['phone'].toString() : '-';
      case 'ticketCount':
        final v = row['ticketCount'] as int? ?? 0;
        return v > 0 ? v.toString() : '-';
      case 'purchaseCount':
        final v = row['purchaseCount'] as int? ?? 0;
        return v > 0 ? v.toString() : '-';
      case 'totalSpent':
        final v = (row['totalSpent'] as num?)?.toDouble() ?? 0;
        return v > 0 ? '₹${v.toStringAsFixed(0)}' : '-';
      case 'khataCount':
        final v = row['khataCount'] as int? ?? 0;
        return v > 0 ? v.toString() : '-';
      case 'source':
        final sources = row['source'] as List<dynamic>? ?? [];
        return sources.isNotEmpty ? sources.join(', ') : '-';
      case 'lastActivity':
        final raw = row['lastActivity']?.toString() ?? '';
        if (raw.isNotEmpty) {
          try {
            final dt = DateTime.parse(raw);
            return DateFormat('dd/MM/yy').format(dt);
          } catch (_) {}
        }
        return '-';
      default:
        return (row[key] ?? '-').toString();
    }
  }
  
  void _downloadCustomersExcel() {
    if (_filteredCustomers.isEmpty) {
      Get.snackbar('No Data', 'No customers to download', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Customers'];
      excel.delete('Sheet1');
      
      // Style for header - use green theme
      final headerStyle = xls.CellStyle(
        backgroundColorHex: xls.ExcelColor.fromHexString('#0D7C4A'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
      );
      
      // Headers
      final headers = ['#', 'Name', 'Phone', 'Tickets', 'Purchases', 'Total Spent', 'Khata Entries', 'Source', 'Last Activity'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Data rows
      for (var i = 0; i < _filteredCustomers.length; i++) {
        final row = _filteredCustomers[i];
        final rowIdx = i + 1;
        final sources = (row['source'] as List<dynamic>? ?? []).join(', ');
        
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = xls.IntCellValue(i + 1);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xls.TextCellValue(row['name']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xls.TextCellValue(row['phone']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xls.IntCellValue(row['ticketCount'] as int? ?? 0);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xls.IntCellValue(row['purchaseCount'] as int? ?? 0);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xls.DoubleCellValue((row['totalSpent'] as num?)?.toDouble() ?? 0);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = xls.IntCellValue(row['khataCount'] as int? ?? 0);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value = xls.TextCellValue(sources.isNotEmpty ? sources : '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xls.TextCellValue(_getCustomerCellValue(row, 'lastActivity'));
      }
      
      // Set column widths
      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 24);
      sheet.setColumnWidth(2, 14);
      sheet.setColumnWidth(3, 10);
      sheet.setColumnWidth(4, 12);
      sheet.setColumnWidth(5, 14);
      sheet.setColumnWidth(6, 12);
      sheet.setColumnWidth(7, 20);
      sheet.setColumnWidth(8, 14);
      
      // Download
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        html.AnchorElement()
          ..href = url
          ..download = 'Customers_Report_$dateStr.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        
        Get.snackbar('Downloaded', 'Customers Excel exported successfully', 
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Customers Excel download error: $e');
      Get.snackbar('Error', 'Failed to download Excel', snackPosition: SnackPosition.BOTTOM);
    }
  }
  
  void _downloadTicketsExcel() {
    if (_filteredTickets.isEmpty) {
      Get.snackbar('No Data', 'No tickets to download', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Tickets'];
      excel.delete('Sheet1');
      
      // Style for header - use green theme
      final headerStyle = xls.CellStyle(
        backgroundColorHex: xls.ExcelColor.fromHexString('#0D7C4A'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
      );
      
      // Headers
      final headers = ['#', 'Date', 'Customer', 'Phone', 'Device', 'Issue', 'Status', 'Assigned To', 'Est. Cost'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Data rows
      for (var i = 0; i < _filteredTickets.length; i++) {
        final row = _filteredTickets[i];
        final rowIdx = i + 1;
        
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = xls.IntCellValue(i + 1);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xls.TextCellValue(_getTicketCellValue(row, 'created_at'));
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xls.TextCellValue(row['customer_name']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xls.TextCellValue(row['mobile_number']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xls.TextCellValue(row['device_model']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xls.TextCellValue(row['issue_description']?.toString() ?? '-');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = xls.TextCellValue(_toTitleCase(row['status']?.toString() ?? 'Pending'));
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value = xls.TextCellValue(row['assigned_technician']?.toString() ?? '-');
        
        final cost = row['estimated_cost'];
        if (cost != null && cost.toString().isNotEmpty) {
          final numCost = double.tryParse(cost.toString()) ?? 0;
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xls.DoubleCellValue(numCost);
        } else {
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xls.TextCellValue('-');
        }
      }
      
      // Set column widths
      sheet.setColumnWidth(0, 8);
      sheet.setColumnWidth(1, 12);
      sheet.setColumnWidth(2, 20);
      sheet.setColumnWidth(3, 14);
      sheet.setColumnWidth(4, 20);
      sheet.setColumnWidth(5, 30);
      sheet.setColumnWidth(6, 12);
      sheet.setColumnWidth(7, 18);
      sheet.setColumnWidth(8, 12);
      
      // Download
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        html.AnchorElement()
          ..href = url
          ..download = 'Tickets_Report_$dateStr.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        
        Get.snackbar('Downloaded', 'Tickets Excel exported successfully', 
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Excel download error: $e');
      Get.snackbar('Error', 'Failed to download Excel', snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _getTicketCellValue(Map<String, dynamic> row, String key) {
    switch (key) {
      case 'created_at':
        final raw = row['created_at'] ?? row['createdAt'] ?? '';
        if (raw is String && raw.isNotEmpty) {
          try {
            final dt = DateTime.parse(raw);
            return DateFormat('dd/MM/yy').format(dt);
          } catch (_) {}
        }
        return raw.toString();
      case 'estimated_cost':
        final v = row[key];
        if (v == null || v.toString().isEmpty) return '-';
        return '₹${v.toString()}';
      case 'status':
        return _toTitleCase(row['status']?.toString() ?? 'Pending');
      default:
        return (row[key] ?? '-').toString();
    }
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Widget _buildDataTable({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> columns,
    required List<Map<String, dynamic>> data,
    required String Function(Map<String, dynamic>, String) getCellValue,
    required VoidCallback onRefresh,
    VoidCallback? onDownload,
    GlobalKey<AnimatedDownloadButtonState>? downloadKey,
    void Function(Map<String, dynamic> row)? onRowTap,
  }) {
    final totalWidth = columns.fold<double>(0, (sum, c) => sum + (c['width'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _borderColor)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2A2E45),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (onDownload != null && downloadKey != null)
                AnimatedDownloadButton(
                  key: downloadKey,
                  onPressed: () async {
                    onDownload();
                    // Simulate completion after download
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      downloadKey.currentState?.onSuccess();
                    });
                  },
                  label: 'Excel',
                  primaryColor: _primaryColor,
                  icon: Icons.file_download_outlined,
                )
              else if (onDownload != null)
                IconButton(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  color: _primaryColor,
                  tooltip: 'Download Excel',
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                color: _primaryColor,
                tooltip: 'Refresh',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          size: 56,
                          color: _primaryColor.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No data found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or date range',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('Refresh Data', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalController,
                  child: SizedBox(
                    width: totalWidth + 50,
                    child: Column(
                      children: [
                        // Column headers
                        Container(
                          color: _headerBg,
                          child: Row(
                            children: [
                              // Row number header
                              Container(
                                width: 50,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: _borderColor),
                                    bottom: BorderSide(color: _borderColor),
                                  ),
                                ),
                                child: Text(
                                  '#',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              ...columns.map((col) => Container(
                                width: col['width'] as double,
                                height: 40,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: _borderColor),
                                    bottom: BorderSide(color: _borderColor),
                                  ),
                                ),
                                child: Text(
                                  col['label'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                            ],
                          ),
                        ),

                        // Data rows
                        Expanded(
                          child: ListView.builder(
                            controller: _verticalController,
                            itemCount: data.length,
                            itemBuilder: (context, rowIndex) {
                              final row = data[rowIndex];
                              final isEven = rowIndex.isEven;
                              
                              return InkWell(
                                onTap: onRowTap != null ? () => onRowTap(row) : null,
                                hoverColor: _primaryColor.withOpacity(0.04),
                                splashColor: _primaryColor.withOpacity(0.08),
                                child: Container(
                                  color: isEven ? Colors.white : _headerBg.withOpacity(0.5),
                                  child: Row(
                                    children: [
                                    // Row number
                                    Container(
                                      width: 50,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _headerBg.withOpacity(0.7),
                                        border: Border(
                                          right: BorderSide(color: _borderColor),
                                          bottom: BorderSide(color: _borderColor.withOpacity(0.5)),
                                        ),
                                      ),
                                      child: Text(
                                        '${rowIndex + 1}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    ...columns.map((col) {
                                      final key = col['key'] as String;
                                      final value = getCellValue(row, key);
                                      
                                      // Status styling
                                      Color? statusColor;
                                      if (key == 'status') {
                                        final s = value.toLowerCase();
                                        if (s == 'pending') statusColor = Colors.orange;
                                        else if (s == 'repaired') statusColor = Colors.blue;
                                        else if (s == 'delivered') statusColor = Colors.green;
                                        else if (s == 'cancelled') statusColor = Colors.red;
                                      }
                                      
                                      return Container(
                                        width: col['width'] as double,
                                        height: 36,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(color: _borderColor.withOpacity(0.5)),
                                            bottom: BorderSide(color: _borderColor.withOpacity(0.5)),
                                          ),
                                        ),
                                        child: statusColor != null
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  value,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                value,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: const Color(0xFF2A2E45),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReportTab {
  final String title;
  final IconData icon;
  final String description;

  const _ReportTab({
    required this.title,
    required this.icon,
    required this.description,
  });
}
