// lib/screens/excel_view_screen.dart
// Admin-only Excel View - Premium Google Sheets style

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls hide Border;
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';
import '../utils/excel_download_stub.dart' if (dart.library.html) '../utils/excel_download_web.dart';

class ExcelViewScreen extends StatefulWidget {
  final bool embedded;
  
  const ExcelViewScreen({super.key, this.embedded = false});

  @override
  State<ExcelViewScreen> createState() => _ExcelViewScreenState();
}

class _ExcelViewScreenState extends State<ExcelViewScreen> {
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = false;
  bool _isEditMode = false;
  
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL';
  Timer? _searchDebounce;
  
  final Map<int, Map<String, dynamic>> _editedRows = {};
  final List<Map<String, dynamic>> _newRows = [];
  bool _hasUnsavedChanges = false;
  int? _hoveredRow;
  int? _editingRow;
  int? _editingCol;
  final TextEditingController _cellEditController = TextEditingController();
  final FocusNode _cellFocusNode = FocusNode();
  
  // Multi-cell selection
  final Set<String> _selectedCells = {}; // Format: "row,col"
  int? _selectionAnchorRow;
  int? _selectionAnchorCol;

  static const Color _primaryGreen = Color(0xFF6D5DF6);
  static const Color _headerBg = Color(0xFFF0F4F8);
  static const Color _borderColor = Color(0xFFE0E6ED);

  final List<Map<String, dynamic>> _columns = [
    {'key': 'date', 'label': 'P. DATE', 'width': 100.0},
    {'key': 'brand', 'label': 'BRAND', 'width': 100.0},
    {'key': 'model', 'label': 'MODEL NAME', 'width': 150.0},
    {'key': 'imei', 'label': 'IMEI NUMBER', 'width': 145.0},
    {'key': 'variant_gb_color', 'label': 'VARIANT', 'width': 105.0},
    {'key': 'vendor_purchase', 'label': 'VENDOR', 'width': 115.0},
    {'key': 'vendor_phone', 'label': 'V CONTACT', 'width': 105.0},
    {'key': 'status', 'label': 'STATUS', 'width': 90.0},
    {'key': 'customer_name', 'label': 'CUSTOMER', 'width': 120.0},
    {'key': 'purchase_amount', 'label': 'P. PRICE', 'width': 95.0, 'numeric': true},
    {'key': 'sell_amount', 'label': 'S. PRICE', 'width': 95.0, 'numeric': true},
    {'key': 'profit', 'label': 'PROFIT', 'width': 100.0, 'calculated': true},
  ];

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _frozenColController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _horizontalController.addListener(() {
      if (_headerHorizontalController.hasClients) _headerHorizontalController.jumpTo(_horizontalController.offset);
    });
    _verticalController.addListener(() {
      if (_frozenColController.hasClients) _frozenColController.jumpTo(_verticalController.offset);
    });
    // Auto-save cell when focus is lost (clicking elsewhere)
    _cellFocusNode.addListener(() {
      if (!_cellFocusNode.hasFocus && _editingRow != null && _editingCol != null) {
        _onCellEditComplete(_editingRow!, _editingCol!, _editingRow! >= _filteredItems.length);
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _headerHorizontalController.dispose();
    _frozenColController.dispose();
    _searchController.dispose();
    _cellEditController.dispose();
    _cellFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);
    try {
      final result = await InventoryService.listItems();
      final list = result['items'] as List<dynamic>? ?? [];
      setState(() {
        _inventoryItems = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _applyFilters();
        _newRows.clear();
        _editedRows.clear();
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      Get.snackbar('Error', '$e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();
    _filteredItems = _inventoryItems.where((item) {
      if (_statusFilter != 'ALL' && (item['status'] ?? 'AVAILABLE') != _statusFilter) return false;
      if (q.isNotEmpty) {
        final s = [item['model'], item['imei'], item['vendor_purchase']].map((e) => e?.toString().toLowerCase() ?? '').join(' ');
        if (!s.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => setState(() => _applyFilters()));
  }

  Map<String, double> get _totals {
    double p = 0, s = 0, profit = 0;
    int availableCount = 0;
    double availableStockValue = 0;
    for (final item in [..._filteredItems, ..._newRows]) {
      final status = (item['status'] ?? 'AVAILABLE').toString();
      // Count available stock
      if (status == 'AVAILABLE') {
        availableCount++;
        availableStockValue += _parseNum(item['purchase_amount']);
      }
      // Only count profit for SOLD items
      if (status == 'SOLD') {
        final purchase = _parseNum(item['purchase_amount']);
        final sell = _parseNum(item['sell_amount']);
        p += purchase;
        s += sell;
        profit += (sell - purchase);
      }
    }
    return {
      'purchase': p, 
      'sell': s, 
      'profit': profit, 
      'availableCount': availableCount.toDouble(),
      'availableStockValue': availableStockValue,
    };
  }

  void _toggleEditMode() {
    if (_isEditMode && _hasUnsavedChanges) {
      Get.defaultDialog(
        title: 'Unsaved Changes', middleText: 'Discard?',
        textCancel: 'Cancel', textConfirm: 'Discard', confirmTextColor: Colors.white,
        onConfirm: () { Get.back(); setState(() => _isEditMode = false); _loadInventory(); },
      );
    } else {
      setState(() { _isEditMode = !_isEditMode; _editingRow = null; _editingCol = null; });
    }
  }

  void _addNewRow() {
    if (!_isEditMode) return;
    setState(() {
      _newRows.add({
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'model': '', 'imei': '', 'variant_gb_color': '', 'vendor_purchase': '',
        'vendor_phone': '', 'status': 'AVAILABLE', 'customer_name': '', 'purchase_amount': 0, 'sell_amount': 0,
      });
      _hasUnsavedChanges = true;
    });
  }

  void _showBatchEditDialog() {
    final controller = TextEditingController();
    Get.defaultDialog(
      title: 'Edit ${_selectedCells.length} Cells',
      titleStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
      content: Column(
        children: [
          Text('Enter value to apply to all selected cells:', style: GoogleFonts.inter(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Enter value...',
            ),
            onSubmitted: (_) => _applyBatchEdit(controller.text),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () => _applyBatchEdit(controller.text),
        style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
        child: Text('Apply to ${_selectedCells.length} cells', style: const TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
    );
  }

  void _applyBatchEdit(String value) {
    Get.back();
    for (final cellKey in _selectedCells) {
      final parts = cellKey.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      final col = _columns[c];
      final key = col['key'] as String;
      final val = col['numeric'] == true ? (double.tryParse(value) ?? 0) : value.trim();
      final isNew = r >= _filteredItems.length;
      
      if (isNew) {
        _newRows[r - _filteredItems.length][key] = val;
      } else {
        final item = _filteredItems[r];
        final srNo = item['sr_no'] as int? ?? 0;
        _editedRows.putIfAbsent(srNo, () => {})[key] = val;
        _filteredItems[r][key] = val;
      }
    }
    setState(() {
      _hasUnsavedChanges = true;
      _selectedCells.clear();
    });
    Get.snackbar('Applied', 'Value applied to ${_selectedCells.length} cells', snackPosition: SnackPosition.BOTTOM);
  }

  void _onCellTap(int rowIdx, int colIdx, bool isNew, {bool isShift = false, bool isCtrl = false}) {
    if (!_isEditMode || _columns[colIdx]['calculated'] == true) return;
    
    final cellKey = '$rowIdx,$colIdx';
    
    if (isShift && _selectionAnchorRow != null && _selectionAnchorCol != null) {
      // Shift+Click: Select range from anchor to current cell
      final minRow = _selectionAnchorRow! < rowIdx ? _selectionAnchorRow! : rowIdx;
      final maxRow = _selectionAnchorRow! > rowIdx ? _selectionAnchorRow! : rowIdx;
      final minCol = _selectionAnchorCol! < colIdx ? _selectionAnchorCol! : colIdx;
      final maxCol = _selectionAnchorCol! > colIdx ? _selectionAnchorCol! : colIdx;
      
      _selectedCells.clear();
      for (int r = minRow; r <= maxRow; r++) {
        for (int c = minCol; c <= maxCol; c++) {
          if (_columns[c]['calculated'] != true) {
            _selectedCells.add('$r,$c');
          }
        }
      }
      setState(() {});
    } else if (isCtrl) {
      // Ctrl+Click: Toggle cell in selection
      setState(() {
        if (_selectedCells.contains(cellKey)) {
          _selectedCells.remove(cellKey);
        } else {
          _selectedCells.add(cellKey);
        }
        if (_selectedCells.isEmpty) {
          _selectionAnchorRow = null;
          _selectionAnchorCol = null;
        } else {
          _selectionAnchorRow = rowIdx;
          _selectionAnchorCol = colIdx;
        }
      });
    } else {
      // Normal click: Add/toggle cell in selection
      setState(() {
        if (_selectedCells.contains(cellKey)) {
          // Clicking selected cell again -> edit it
          _editingRow = rowIdx;
          _editingCol = colIdx;
        } else {
          // Add new cell to selection
          _selectedCells.add(cellKey);
          _selectionAnchorRow = rowIdx;
          _selectionAnchorCol = colIdx;
        }
      });
      
      // If editing, populate the field
      if (_editingRow == rowIdx && _editingCol == colIdx) {
        final item = isNew ? _newRows[rowIdx - _filteredItems.length] : _filteredItems[rowIdx];
        _cellEditController.text = item[_columns[colIdx]['key']]?.toString() ?? '';
        Future.delayed(const Duration(milliseconds: 50), () {
          _cellFocusNode.requestFocus();
          _cellEditController.selection = TextSelection(baseOffset: 0, extentOffset: _cellEditController.text.length);
        });
      }
    }
  }

  void _onCellEditComplete(int rowIdx, int colIdx, bool isNew) {
    final col = _columns[colIdx];
    final key = col['key'] as String;
    final val = col['numeric'] == true ? (double.tryParse(_cellEditController.text) ?? 0) : _cellEditController.text.trim();
    
    // Only edit the single cell being edited (batch edit uses _applyBatchEdit via dialog)
    if (isNew) {
      _newRows[rowIdx - _filteredItems.length][key] = val;
    } else {
      final item = _filteredItems[rowIdx];
      final srNo = item['sr_no'] as int? ?? 0;
      _editedRows.putIfAbsent(srNo, () => {})[key] = val;
      _filteredItems[rowIdx][key] = val;
    }
    setState(() { _hasUnsavedChanges = true; _editingRow = null; _editingCol = null; });
  }

  // Convert snake_case keys to camelCase for API
  static final Map<String, String> _keyToApi = {
    'date': 'date',
    'brand': 'brand',
    'model': 'model',
    'imei': 'imei',
    'variant_gb_color': 'variantGbColor',
    'vendor_purchase': 'vendorPurchase',
    'vendor_phone': 'vendorPhone',
    'purchase_amount': 'purchaseAmount',
    'sell_amount': 'sellAmount',
    'status': 'status',
    'customer_name': 'customerName',
    'remarks': 'remarks',
  };

  Map<String, dynamic> _convertKeysForApi(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final apiKey = _keyToApi[entry.key] ?? entry.key;
      result[apiKey] = entry.value;
    }
    return result;
  }

  Future<void> _saveChanges() async {
    if (!_hasUnsavedChanges) return;
    setState(() => _loading = true);
    int ok = 0, fail = 0;
    for (final e in _editedRows.entries) {
      try { 
        final apiData = _convertKeysForApi(e.value);
        await InventoryService.updateItem(e.key, apiData); 
        ok++; 
      } catch (_) { fail++; }
    }
    for (final row in _newRows) {
      if ((row['imei'] ?? '').toString().isEmpty) continue;
      try { 
        final apiData = _convertKeysForApi(row);
        await InventoryService.createItem(apiData); 
        ok++; 
      } catch (_) { fail++; }
    }
    Get.snackbar(fail == 0 ? '✓ Saved' : '⚠ Partial', '$ok saved${fail > 0 ? ', $fail failed' : ''}',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: fail == 0 ? _primaryGreen : Colors.orange, colorText: Colors.white);
    _editedRows.clear(); _newRows.clear();
    setState(() { _hasUnsavedChanges = false; _isEditMode = false; });
    _loadInventory();
  }

  void _showDownloadDialog() {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    String exportOption = 'current'; // 'all', 'current', 'custom'
    
    Get.defaultDialog(
      title: 'Download Excel',
      titleStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose export range:', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 16),
              
              // All Data option
              RadioListTile<String>(
                title: Text('All Data', style: GoogleFonts.inter()),
                subtitle: Text('${_filteredItems.length} items', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                value: 'all',
                groupValue: exportOption,
                onChanged: (v) => setDialogState(() => exportOption = v!),
                dense: true,
                activeColor: _primaryGreen,
              ),
              
              // Current Month option
              RadioListTile<String>(
                title: Text('Current Month', style: GoogleFonts.inter()),
                subtitle: Text('${DateFormat('MMMM yyyy').format(DateTime.now())}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                value: 'current',
                groupValue: exportOption,
                onChanged: (v) => setDialogState(() => exportOption = v!),
                dense: true,
                activeColor: _primaryGreen,
              ),
              
              // Custom Month option
              RadioListTile<String>(
                title: Text('Select Month', style: GoogleFonts.inter()),
                value: 'custom',
                groupValue: exportOption,
                onChanged: (v) => setDialogState(() => exportOption = v!),
                dense: true,
                activeColor: _primaryGreen,
              ),
              
              if (exportOption == 'custom') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Month dropdown
                    DropdownButton<int>(
                      value: selectedMonth,
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(DateFormat('MMMM').format(DateTime(2000, i + 1))),
                      )),
                      onChanged: (v) => setDialogState(() => selectedMonth = v!),
                    ),
                    const SizedBox(width: 16),
                    // Year dropdown
                    DropdownButton<int>(
                      value: selectedYear,
                      items: List.generate(5, (i) => DropdownMenuItem(
                        value: DateTime.now().year - i,
                        child: Text('${DateTime.now().year - i}'),
                      )),
                      onChanged: (v) => setDialogState(() => selectedYear = v!),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
      confirm: ElevatedButton.icon(
        onPressed: () {
          Get.back();
          if (exportOption == 'all') {
            _downloadExcel(null, null);
          } else if (exportOption == 'current') {
            _downloadExcel(DateTime.now().month, DateTime.now().year);
          } else {
            _downloadExcel(selectedMonth, selectedYear);
          }
        },
        icon: const Icon(Icons.download, color: Colors.white, size: 18),
        label: const Text('Download', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }

  Future<void> _downloadExcel(int? filterMonth, int? filterYear) async {
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['JollyBaba Inventory'];
      
      
      // Header style - Bold, larger appearance, light background, centered
      final headerStyle = xls.CellStyle(
        bold: true,
        fontSize: 11,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#1F2937'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // Index/SR column style - Bold
      final indexStyle = xls.CellStyle(
        bold: true,
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#F3F4F6'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // Text style - Left aligned
      final textStyle = xls.CellStyle(
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        horizontalAlign: xls.HorizontalAlign.Left,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // Number style - Right aligned
      final numberStyle = xls.CellStyle(
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        horizontalAlign: xls.HorizontalAlign.Right,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // Status style - Center aligned
      final statusStyle = xls.CellStyle(
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // SOLD row style - Light green background
      final soldTextStyle = xls.CellStyle(
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#D1FAE5'),
        horizontalAlign: xls.HorizontalAlign.Left,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      final soldNumberStyle = xls.CellStyle(
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#D1FAE5'),
        horizontalAlign: xls.HorizontalAlign.Right,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      final soldIndexStyle = xls.CellStyle(
        bold: true,
        fontSize: 10,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#D1FAE5'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      // Add SR NO column + all other columns
      final headers = ['#', 'P. DATE', 'BRAND', 'MODEL NAME', 'IMEI NUMBER', 'VARIANT', 'VENDOR', 'V CONTACT', 'STATUS', 'CUSTOMER', 'P. PRICE', 'S. PRICE', 'PROFIT'];
      
      // Filter items by month if specified
      List<Map<String, dynamic>> exportItems = _filteredItems;
      String monthLabel = '';
      if (filterMonth != null && filterYear != null) {
        exportItems = _filteredItems.where((item) {
          final dateStr = item['date']?.toString() ?? '';
          if (dateStr.isEmpty) return false;
          try {
            final date = DateTime.parse(dateStr);
            return date.month == filterMonth && date.year == filterYear;
          } catch (_) {
            return false;
          }
        }).toList();
        monthLabel = '_${DateFormat('MMM_yyyy').format(DateTime(filterYear, filterMonth))}';
      }
      
      if (exportItems.isEmpty) {
        Get.snackbar('No Data', 'No items found for selected month', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      
      // Calculate max widths for auto-fit (start with header lengths)
      List<int> maxWidths = headers.map((h) => h.length + 2).toList();
      
      // Check data to find max widths
      for (final item in exportItems) {
        maxWidths[0] = 5; // # column fixed width
        maxWidths[1] = maxWidths[1] > 12 ? maxWidths[1] : 12; // Date
        maxWidths[2] = _maxLen(maxWidths[2], item['brand']?.toString());
        maxWidths[3] = _maxLen(maxWidths[3], item['model']?.toString());
        maxWidths[4] = _maxLen(maxWidths[4], item['imei']?.toString());
        maxWidths[5] = _maxLen(maxWidths[5], item['variant_gb_color']?.toString());
        maxWidths[6] = _maxLen(maxWidths[6], item['vendor_purchase']?.toString());
        maxWidths[7] = _maxLen(maxWidths[7], item['vendor_phone']?.toString());
        maxWidths[8] = 12; // Status fixed
        maxWidths[9] = _maxLen(maxWidths[9], item['customer_name']?.toString()); // Customer
        maxWidths[10] = 12; // P. Price
        maxWidths[11] = 12; // S. Price
        maxWidths[12] = 12; // Profit
      }
      
      // Set column widths (capped at 40)
      for (var i = 0; i < maxWidths.length; i++) {
        sheet.setColumnWidth(i, (maxWidths[i] > 40 ? 40 : maxWidths[i]).toDouble());
      }
      
      // Header row
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Set row height for header (taller)
      sheet.setRowHeight(0, 25);
      
      // Data rows
      for (var r = 0; r < exportItems.length; r++) {
        final item = exportItems[r];
        final isSold = (item['status'] ?? 'AVAILABLE') == 'SOLD';
        
        // Set consistent row height
        sheet.setRowHeight(r + 1, 20);
        
        // SR NO column (bold index)
        final srCell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1));
        srCell.value = xls.IntCellValue(r + 1);
        srCell.cellStyle = isSold ? soldIndexStyle : indexStyle;
        
        // P. DATE - left align
        _setCell(sheet, 1, r + 1, item['date']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // BRAND - left align
        _setCell(sheet, 2, r + 1, item['brand']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // MODEL NAME - left align
        _setCell(sheet, 3, r + 1, item['model']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // IMEI - left align
        _setCell(sheet, 4, r + 1, item['imei']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // VARIANT - center align
        _setCell(sheet, 5, r + 1, item['variant_gb_color']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // VENDOR - left align
        _setCell(sheet, 6, r + 1, item['vendor_purchase']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // V CONTACT - left align
        _setCell(sheet, 7, r + 1, item['vendor_phone']?.toString() ?? '', isSold ? soldTextStyle : textStyle);
        
        // STATUS - center align
        _setCell(sheet, 8, r + 1, (item['status'] ?? 'AVAILABLE').toString(), isSold ? soldTextStyle : statusStyle);
        
        // CUSTOMER - left align (only for sold items)
        _setCell(sheet, 9, r + 1, isSold ? (item['customer_name']?.toString() ?? '') : '', isSold ? soldTextStyle : textStyle);
        
        // P. PRICE - right align, number
        _setNumCell(sheet, 10, r + 1, _parseNum(item['purchase_amount']), isSold ? soldNumberStyle : numberStyle);
        
        // S. PRICE - right align, number
        _setNumCell(sheet, 11, r + 1, _parseNum(item['sell_amount']), isSold ? soldNumberStyle : numberStyle);
        
        // PROFIT - right align, number
        final profit = _parseNum(item['sell_amount']) - _parseNum(item['purchase_amount']);
        _setNumCell(sheet, 12, r + 1, profit, isSold ? soldNumberStyle : numberStyle);
      }
      
      // Totals row
      final totalRow = exportItems.length + 1;
      final totalStyle = xls.CellStyle(
        bold: true,
        fontSize: 11,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#1F2937'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xls.HorizontalAlign.Right,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      final totalLabelStyle = xls.CellStyle(
        bold: true,
        fontSize: 11,
        fontFamily: xls.getFontFamily(xls.FontFamily.Calibri),
        backgroundColorHex: xls.ExcelColor.fromHexString('#1F2937'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xls.HorizontalAlign.Left,
        verticalAlign: xls.VerticalAlign.Center,
      );
      
      sheet.setRowHeight(totalRow, 25);
      
      // Set totals label
      final totalsLabelCell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow));
      totalsLabelCell.value = xls.TextCellValue('TOTALS');
      totalsLabelCell.cellStyle = totalLabelStyle;
      
      // Empty cells with dark background (up to CUSTOMER column)
      for (var i = 1; i <= 9; i++) {
        final emptyCell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: totalRow));
        emptyCell.value = xls.TextCellValue('');
        emptyCell.cellStyle = totalStyle;
      }
      
      // Calculate totals from exported items (not global _totals)
      double totalPurchase = 0, totalSell = 0, totalProfit = 0;
      for (final item in exportItems) {
        if ((item['status'] ?? 'AVAILABLE') == 'SOLD') {
          final p = _parseNum(item['purchase_amount']);
          final s = _parseNum(item['sell_amount']);
          totalPurchase += p;
          totalSell += s;
          totalProfit += (s - p);
        }
      }
      _setNumCell(sheet, 10, totalRow, totalPurchase, totalStyle);
      _setNumCell(sheet, 11, totalRow, totalSell, totalStyle);
      _setNumCell(sheet, 12, totalRow, totalProfit, totalStyle);
      
      excel.delete('Sheet1');
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel');
      if (kIsWeb) {
        await downloadExcelBytes(Uint8List.fromList(bytes), 'JollyBaba_Inventory$monthLabel.xlsx');
        Get.snackbar('Downloaded', '${exportItems.length} items exported', snackPosition: SnackPosition.BOTTOM, backgroundColor: _primaryGreen, colorText: Colors.white);
      } else {
        Get.snackbar('Not Supported', 'Excel download is only available on web', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) { Get.snackbar('Error', '$e', snackPosition: SnackPosition.BOTTOM); }
  }
  
  int _maxLen(int current, String? val) => val != null && val.length + 2 > current ? val.length + 2 : current;
  
  void _setCell(xls.Sheet sheet, int col, int row, String value, xls.CellStyle style) {
    final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = xls.TextCellValue(value);
    cell.cellStyle = style;
  }
  
  void _setNumCell(xls.Sheet sheet, int col, int row, double value, xls.CellStyle style) {
    final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = xls.DoubleCellValue(value);
    cell.cellStyle = style;
  }

  double _parseNum(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  String _colLetter(int i) { String r = ''; while (i >= 0) { r = String.fromCharCode(65 + (i % 26)) + r; i = (i ~/ 26) - 1; } return r; }
  String _currency(double v) => '₹${NumberFormat('#,##,###').format(v.round())}';

  @override
  Widget build(BuildContext context) {
    // When embedded, return just the content without Scaffold
    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            _buildEmbeddedToolbar(),
            _buildSearchBar(),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: _primaryGreen)) : _buildSpreadsheet()),
            _buildTotalsBar(),
          ],
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildToolbar(),
          _buildSearchBar(),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: _primaryGreen)) : _buildSpreadsheet()),
          _buildTotalsBar(),
        ],
      ),
    );
  }
  
  Widget _buildEmbeddedToolbar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_rounded, color: _primaryGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_filteredItems.length + _newRows.length} items${_hasUnsavedChanges ? ' • Unsaved' : ''}',
              style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          _embeddedBtn(_isEditMode ? Icons.visibility : Icons.edit, _isEditMode ? 'View' : 'Edit', _toggleEditMode),
          if (_isEditMode) ...[
            const SizedBox(width: 6),
            _embeddedBtn(Icons.save, 'Save', _hasUnsavedChanges ? _saveChanges : null, primary: true),
            if (_selectedCells.length > 1) ...[
              const SizedBox(width: 6),
              _embeddedBtn(Icons.edit_note, 'Edit ${_selectedCells.length}', _showBatchEditDialog, primary: true),
            ],
          ],
          const SizedBox(width: 6),
          IconButton(onPressed: _showDownloadDialog, icon: Icon(Icons.download, color: _primaryGreen, size: 20), tooltip: 'Download Excel'),
          IconButton(onPressed: _loadInventory, icon: Icon(Icons.refresh, color: Colors.grey.shade600, size: 20), tooltip: 'Refresh'),
        ],
      ),
    );
  }
  
  Widget _embeddedBtn(IconData icon, String label, VoidCallback? onTap, {bool primary = false}) {
    return Material(
      color: primary ? _primaryGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: primary ? Colors.white : (onTap == null ? Colors.grey : _primaryGreen)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: primary ? Colors.white : (onTap == null ? Colors.grey : _primaryGreen))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_primaryGreen, Color(0xFF0A5C38)]),
      ),
      child: Row(
        children: [
          IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JollyBaba Inventory', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${_filteredItems.length + _newRows.length} items${_hasUnsavedChanges ? ' • Unsaved' : ''}', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _toolBtn(_isEditMode ? Icons.visibility : Icons.edit, _isEditMode ? 'View' : 'Edit', _toggleEditMode, outlined: true),
          if (_isEditMode) ...[
            const SizedBox(width: 8),
            _toolBtn(Icons.save, 'Save', _hasUnsavedChanges ? _saveChanges : null, filled: true),
            if (_selectedCells.length > 1) ...[
              const SizedBox(width: 8),
              _toolBtn(Icons.edit_note, 'Edit ${_selectedCells.length}', _showBatchEditDialog, filled: true),
              const SizedBox(width: 4),
              IconButton(onPressed: () => setState(() => _selectedCells.clear()), icon: const Icon(Icons.clear, color: Colors.white70, size: 20), tooltip: 'Clear Selection'),
            ],
          ],
          const SizedBox(width: 8),
          IconButton(onPressed: _showDownloadDialog, icon: const Icon(Icons.download, color: Colors.white), tooltip: 'Download Excel'),
          IconButton(onPressed: _loadInventory, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback? onTap, {bool outlined = false, bool filled = false}) {
    return Material(
      color: filled ? (onTap != null ? Colors.green.shade600 : Colors.grey) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: outlined ? BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(8)) : null,
          child: Row(children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search model, IMEI, vendor...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: _headerBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: _headerBg, borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'AVAILABLE', child: Text('🔵 Available')),
                  DropdownMenuItem(value: 'SOLD', child: Text('🟢 Sold')),
                ],
                onChanged: (v) => setState(() { _statusFilter = v ?? 'ALL'; _applyFilters(); }),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSpreadsheet() {
    const rowH = 36.0, headerH = 44.0, numW = 50.0;
    final all = [..._filteredItems, ..._newRows];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - numW - 32;
        final fixedTotalWidth = _columns.fold<double>(0, (s, c) => s + (c['width'] as double));
        final scale = availableWidth > fixedTotalWidth ? availableWidth / fixedTotalWidth : 1.0;
        final allCols = _columns.map((c) => {...c, 'width': (c['width'] as double) * scale}).toList();

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned(left: numW, top: 0, right: 0, bottom: 0,
                  child: Column(children: [
                    SizedBox(height: headerH,
                      child: SingleChildScrollView(controller: _headerHorizontalController, scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(),
                        child: Row(children: allCols.asMap().entries.map((e) => _scrollHeader(e.key, e.value, headerH)).toList()),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(controller: _horizontalController, scrollDirection: Axis.horizontal,
                        child: SizedBox(width: allCols.fold<double>(0, (s, c) => s + (c['width'] as double)),
                          child: ListView.builder(controller: _verticalController, itemCount: all.length + (_isEditMode ? 1 : 0),
                            itemBuilder: (_, i) => i == all.length ? _addRowScroll(rowH, allCols) : _scrollRow(i, rowH, all, allCols),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(left: 0, top: 0, bottom: 0, width: numW,
                  child: Container(color: Colors.white,
                    child: Column(children: [
                      Container(height: headerH, decoration: BoxDecoration(color: _headerBg, border: Border(bottom: BorderSide(color: _borderColor, width: 2), right: BorderSide(color: _borderColor))), alignment: Alignment.center,
                        child: Text('#', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: ListView.builder(controller: _frozenColController, physics: const NeverScrollableScrollPhysics(), itemCount: all.length + (_isEditMode ? 1 : 0),
                          itemBuilder: (_, i) => Container(height: rowH,
                            decoration: BoxDecoration(color: i == all.length ? const Color(0xFFE3F2FD) : (i.isEven ? Colors.white : _headerBg), border: Border(bottom: BorderSide(color: _borderColor, width: 0.5), right: BorderSide(color: _borderColor))),
                            alignment: Alignment.center,
                            child: i == all.length ? const Icon(Icons.add, size: 18, color: Colors.blue) : Text('${i + 1}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _scrollHeader(int colIdx, Map<String, dynamic> col, double h) {
    // First column (colIdx 0) has no left border to avoid gap after row numbers
    final border = colIdx == 0
        ? Border(bottom: BorderSide(color: _borderColor, width: 2))
        : Border(bottom: BorderSide(color: _borderColor, width: 2), left: BorderSide(color: _borderColor, width: 0.5));
    return Container(
      width: col['width'] as double, height: h,
      decoration: BoxDecoration(color: _headerBg, border: border),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_colLetter(colIdx), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        Text(col['label'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _scrollRow(int i, double h, List<Map<String, dynamic>> all, List<Map<String, dynamic>> cols) {
    final isNew = i >= _filteredItems.length;
    final item = all[i];
    final edited = !isNew && _editedRows.containsKey(item['sr_no']);
    final status = (item['status'] ?? 'AVAILABLE').toString();
    final isSold = status == 'SOLD';
    final hovered = _hoveredRow == i;
    final bg = isNew ? const Color(0xFFFFF8E1) : edited ? const Color(0xFFFFF3E0) : hovered ? const Color(0xFFE3F2FD) : isSold ? const Color(0xFFE8F5E9) : (i.isEven ? Colors.white : _headerBg);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = i),
      onExit: (_) => setState(() => _hoveredRow = null),
      child: Container(
        height: h,
        decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
        child: Row(
          children: cols.asMap().entries.map((e) {
            final colIdx = e.key;  // Fixed: was e.key + 1 when P.DATE was frozen
            final col = e.value;
            final key = col['key'] as String;
            final isEditing = _editingRow == i && _editingCol == colIdx && _isEditMode;
            String value = '';
            Color? textColor;
            Widget? child;

            if (col['calculated'] == true && key == 'profit') {
              final profit = _parseNum(item['sell_amount']) - _parseNum(item['purchase_amount']);
              value = profit == 0 ? '—' : '${profit > 0 ? '+' : ''}₹${profit.abs().toStringAsFixed(0)}';
              textColor = profit > 0 ? Colors.green.shade700 : profit < 0 ? Colors.red.shade700 : Colors.grey;
            } else if (key == 'status') {
              child = _statusBadge(status);
              value = status;
            } else if (col['numeric'] == true) {
              final n = _parseNum(item[key]);
              value = n > 0 ? '₹${n.toStringAsFixed(0)}' : '—';
            } else {
              value = item[key]?.toString() ?? '';
              if (value.isEmpty) value = '—';
            }

            final isSelected = _selectedCells.contains('$i,$colIdx');
            
            return GestureDetector(
              onTapDown: (details) {
                final isShift = HardwareKeyboard.instance.isShiftPressed;
                final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
                _onCellTap(i, colIdx, isNew, isShift: isShift, isCtrl: isCtrl);
              },
              child: Container(
                width: col['width'] as double, height: h,
                decoration: BoxDecoration(
                  color: isEditing ? const Color(0xFFE3F2FD) : isSelected ? const Color(0xFFBBDEFB) : null,
                  border: colIdx == 0 ? null : Border(left: BorderSide(color: _borderColor, width: 0.5)),
                ),
                alignment: col['numeric'] == true || col['calculated'] == true ? Alignment.centerRight : Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: isEditing ? _cellEditor() : child ?? Text(value, style: GoogleFonts.inter(fontSize: 12, color: value == '—' ? Colors.grey : textColor ?? Colors.black87), overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _cellEditor() => TextField(
    controller: _cellEditController, focusNode: _cellFocusNode, style: GoogleFonts.inter(fontSize: 12),
    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
    onSubmitted: (_) => _onCellEditComplete(_editingRow!, _editingCol!, _editingRow! >= _filteredItems.length),
  );

  Widget _statusBadge(String s) {
    final sold = s == 'SOLD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: sold ? Colors.green.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(s, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: sold ? Colors.green.shade800 : Colors.blue.shade800)),
    );
  }

  Widget _addRowScroll(double h, List<Map<String, dynamic>> cols) {
    return GestureDetector(
      onTap: _addNewRow,
      child: Container(
        height: h, color: const Color(0xFFE3F2FD), alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Add new row', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildTotalsBar() {
    final t = _totals;
    final availableValue = t['availableStockValue']!;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
            child: Text('TOTALS', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 24),
          _totalItem('Purchase', t['purchase']!, Colors.white),
          const SizedBox(width: 24),
          _totalItem('Sell', t['sell']!, Colors.white),
          const SizedBox(width: 24),
          _totalItem('Profit', t['profit']!, t['profit']! >= 0 ? Colors.green.shade400 : Colors.red.shade400),
          const SizedBox(width: 24),
          _totalItem('Stock', availableValue, Colors.blue.shade300),
          const Spacer(),
          Text('${_filteredItems.length} of ${_inventoryItems.length}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _totalItem(String lbl, double v, Color c) => Row(children: [
    Text('$lbl: ', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
    Text(_currency(v), style: GoogleFonts.inter(color: c, fontSize: 14, fontWeight: FontWeight.w600)),
  ]);
}
