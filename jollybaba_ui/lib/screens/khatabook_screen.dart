// lib/screens/khatabook_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/inventory_service.dart';
import '../services/khatabook_service.dart';

class _CustomerGroup {
  const _CustomerGroup({
    required this.name,
    required this.displayMobile,
    required this.normalizedMobile,
    required this.entries,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalRemaining,
  });

  final String name;
  final String displayMobile;
  final String normalizedMobile;
  final List<Map<String, dynamic>> entries;
  final double totalAmount;
  final double totalPaid;
  final double totalRemaining;

  int get count => entries.length;
  bool get allSettled => totalRemaining <= 0.0001;
}

class _GroupData {
  _GroupData({required this.key, required this.normalizedMobile});

  final String key;
  final String normalizedMobile;
  String displayMobile = '';
  String? fallbackName;
  String? primaryName;
  final List<Map<String, dynamic>> entries = [];
  final Map<String, int> nameCounts = {};
  final Map<String, DateTime> latestByName = {};
  double totalAmount = 0;
  double totalPaid = 0;
  double totalRemaining = 0;

  String _resolveName() {
    final candidate = primaryName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    if (nameCounts.isEmpty) {
      final fallback = fallbackName?.trim();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      if (displayMobile.isNotEmpty) return displayMobile;
      return 'Unknown';
    }
    int maxCount = 0;
    final List<String> candidates = [];
    nameCounts.forEach((name, count) {
      if (count > maxCount) {
        maxCount = count;
        candidates
          ..clear()
          ..add(name);
      } else if (count == maxCount) {
        candidates.add(name);
      }
    });
    if (candidates.length == 1) return candidates.first;
    candidates.sort((a, b) {
      final aDate = latestByName[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = latestByName[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return candidates.first;
  }

  _CustomerGroup build() {
    return _CustomerGroup(
      name: _resolveName(),
      displayMobile: displayMobile,
      normalizedMobile: normalizedMobile,
      entries: List<Map<String, dynamic>>.from(entries),
      totalAmount: totalAmount,
      totalPaid: totalPaid,
      totalRemaining: totalRemaining,
    );
  }
}

class KhatabookScreen extends StatefulWidget {
  const KhatabookScreen({super.key});
  @override
  State<KhatabookScreen> createState() => _KhatabookScreenState();
}

class _KhatabookScreenState extends State<KhatabookScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _sold = [];
  List<Map<String, dynamic>> _manualEntries = [];
  final TextEditingController _queryCtrl = TextEditingController();
  bool _onlyCredit = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<_CustomerGroup> _buildCustomerGroups(List<Map<String, dynamic>> entries) {
    final Map<String, _GroupData> groups = {};
    int orphanCounter = 0;

    for (final row in entries) {
      final nameRaw = _custName(row).trim();
      final mobileRaw = _custMobile(row).trim();
      final normalizedMobile = _normalizeMobile(mobileRaw);
      final entryDate = _entryDate(row);
      final total = _getTotal(row);
      final paidRaw = _getPaid(row);
      final cappedPaid = paidRaw > total
          ? total
          : (paidRaw < 0
              ? 0.0
              : paidRaw);
      final remaining = total - cappedPaid;
      final safeRemaining = remaining < 0 ? 0.0 : remaining;

      String key;
      _GroupData group;

      if (normalizedMobile.isNotEmpty) {
        key = 'M:$normalizedMobile';
        group = groups.putIfAbsent(key, () => _GroupData(key: key, normalizedMobile: normalizedMobile));
        if (mobileRaw.isNotEmpty) {
          group.displayMobile = mobileRaw;
        }
      } else {
        key = 'N:${orphanCounter++}';
        group = groups.putIfAbsent(key, () => _GroupData(key: key, normalizedMobile: ''));
        if (group.fallbackName == null && nameRaw.isNotEmpty) {
          group.fallbackName = nameRaw;
        }
        if (mobileRaw.isNotEmpty) {
          group.displayMobile = mobileRaw;
        }
      }

      if (group.fallbackName == null && nameRaw.isNotEmpty) {
        group.fallbackName = nameRaw;
      }
      if (nameRaw.isNotEmpty && (group.primaryName == null || group.primaryName!.isEmpty)) {
        group.primaryName = nameRaw;
      }

      group.entries.add(row);
      if (nameRaw.isNotEmpty) {
        group.nameCounts[nameRaw] = (group.nameCounts[nameRaw] ?? 0) + 1;
        final existing = group.latestByName[nameRaw];
        if (existing == null || entryDate.isAfter(existing)) {
          group.latestByName[nameRaw] = entryDate;
        }
      }

      if (group.displayMobile.isEmpty && mobileRaw.isNotEmpty) {
        group.displayMobile = mobileRaw;
      }

      group.totalAmount += total;
      group.totalPaid += cappedPaid;
      group.totalRemaining += safeRemaining;
    }

    return groups.values.map((g) => g.build()).toList();
  }

  String _custName(Map<String, dynamic> r) => (r['customer_name'] ?? r['customerName'] ?? r['manual_name'] ?? r['name'] ?? '').toString();
  String _custMobile(Map<String, dynamic> r) => (r['mobile_number'] ?? r['mobileNumber'] ?? r['manual_mobile'] ?? r['customer_mobile'] ?? '').toString();

  List<Map<String, dynamic>> get _allEntries {
    final linkedManualIds = _sold
        .map((item) => _manualId(item['khatabook_entry_id'] ?? item['khatabookEntryId']))
        .whereType<int>()
        .toSet();

    final filteredManuals = _manualEntries
        .where((entry) => !linkedManualIds.contains(_manualId(entry['manual_id'])))
        .toList();

    final combined = <Map<String, dynamic>>[...filteredManuals, ..._sold];
    combined.sort((a, b) => _entryDate(b).compareTo(_entryDate(a)));
    return combined;
  }

  bool _isManual(Map<String, dynamic> r) =>
      r['is_manual'] == true || r.containsKey('manual_id') || r.containsKey('manual_amount');

  String _normalizeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 5 ? digits : '';
  }

  double _parseNumber(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value == null) return fallback;
    return double.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> _manualFromApi(Map<String, dynamic> row) {
    final entryDateRaw = row['entryDate'] ?? row['entry_date'];
    String manualDate;
    if (entryDateRaw is DateTime) {
      manualDate = entryDateRaw.toIso8601String();
    } else if (entryDateRaw is String && entryDateRaw.isNotEmpty) {
      manualDate = entryDateRaw;
    } else {
      manualDate = DateTime.now().toIso8601String();
    }

    return <String, dynamic>{
      'manual_id': row['id'],
      'manual_name': (row['name'] ?? '').toString(),
      'manual_mobile': (row['mobile'] ?? '').toString(),
      'manual_amount': _parseNumber(row['amount']),
      'manual_paid': _parseNumber(row['paid']),
      'manual_description': (row['description'] ?? '').toString(),
      'manual_note': (row['note'] ?? '').toString(),
      'manual_date': manualDate,
      'is_manual': true,
    };
  }

  Map<String, dynamic> _manualPayloadFromLocal(Map<String, dynamic> entry) {
    final amount = _parseNumber(entry['manual_amount']);
    final paid = _parseNumber(entry['manual_paid']);
    final date = entry['manual_date'];
    String entryDate;
    if (date is DateTime) {
      entryDate = date.toIso8601String();
    } else if (date is String && date.isNotEmpty) {
      entryDate = date;
    } else {
      entryDate = DateTime.now().toIso8601String();
    }

    return {
      'name': (entry['manual_name'] ?? '').toString(),
      'mobile': (entry['manual_mobile'] ?? '').toString(),
      'amount': amount,
      'paid': paid,
      'description': (entry['manual_description'] ?? '').toString(),
      'note': (entry['manual_note'] ?? '').toString(),
      'entryDate': entryDate,
    };
  }

  int? _manualId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  void _replaceManualEntry(Map<String, dynamic> entry) {
    final id = _manualId(entry['manual_id']);
    if (id == null) return;
    setState(() {
      final list = [..._manualEntries];
      final idx = list.indexWhere((e) => _manualId(e['manual_id']) == id);
      if (idx >= 0) {
        list[idx] = entry;
      } else {
        list.add(entry);
      }
      _manualEntries = list;
    });
  }

  void _removeManualEntry(dynamic manualId) {
    final id = _manualId(manualId);
    if (id == null) return;
    setState(() {
      _manualEntries = _manualEntries.where((e) => _manualId(e['manual_id']) != id).toList();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final soldFuture = InventoryService.listItems(status: 'SOLD', sort: 'date', order: 'desc');
      final manualFuture = KhatabookService.listEntries();

      final resp = await soldFuture;
      final manualRaw = await manualFuture;

      final items = (resp['items'] as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      final linkedManualIds = items
          .map((item) => _manualId(item['khatabook_entry_id'] ?? item['khatabookEntryId']))
          .whereType<int>()
          .toSet();

      final manualEntries = manualRaw
          .map(_manualFromApi)
          .where((entry) => !linkedManualIds.contains(_manualId(entry['manual_id'])))
          .toList();
      setState(() {
        _sold = items;
        _manualEntries = manualEntries;
        _loading = false;
      });
    } catch (err) {
      setState(() => _loading = false);
      Get.snackbar('Khatabook', 'Failed to load data', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Khatabook load failed: $err');
    }
  }

  Future<void> _downloadExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final uri = KhatabookService.exportExcelUrl();
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Unable to open download link');
      }
      if (mounted) {
        Get.snackbar(
          'Khatabook',
          'Opening Excel download in browser…',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (err) {
      debugPrint('Khatabook export failed: $err');
      if (mounted) {
        Get.snackbar('Khatabook', 'Failed to export Excel: ${err.toString()}', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      } else {
        _exporting = false;
      }
    }
  }

  double _getPaid(Map<String, dynamic> r) {
    if (_isManual(r)) {
      final paid = r['manual_paid'];
      if (paid is num) return paid.toDouble();
      final s = (paid ?? '').toString().trim();
      return double.tryParse(s) ?? 0.0;
    }
    final remarks = (r['remarks'] ?? '').toString();
    final regex = RegExp(r'Paid\s*:?.*?₹?\s*([0-9][0-9,]*(?:\.[0-9]+)?)', caseSensitive: false);
    final matches = regex.allMatches(remarks).toList();
    if (matches.isEmpty) return 0.0;
    final last = matches.last.group(1) ?? '0';
    final normalized = last.replaceAll(',', '');
    return double.tryParse(normalized) ?? 0.0;
  }

  double _getTotal(Map<String, dynamic> r) {
    if (_isManual(r)) {
      final amount = r['manual_amount'];
      if (amount is num) return amount.toDouble();
      final s = (amount ?? '').toString().trim();
      return double.tryParse(s) ?? 0.0;
    }
    final total = r['sell_amount'];
    if (total is num) return total.toDouble();
    final s = (total ?? '').toString().replaceAll(',', '');
    return double.tryParse(s) ?? 0.0;
  }

  DateTime _entryDate(Map<String, dynamic> r) {
    if (_isManual(r)) {
      final raw = r['manual_date'];
      if (raw is DateTime) return raw;
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }
    final candidates = [
      r['sold_at'],
      r['soldAt'],
      r['sold_date'],
      r['date'],
      r['created_at'],
      r['createdAt'],
    ];
    for (final value in candidates) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return DateTime.now();
  }

  Future<Map<String, dynamic>?> _fetchBySr(int sr) async {
    try {
      // Try precise search by q first
      final resp = await InventoryService.listItems(q: sr.toString(), status: 'SOLD');
      final list = (resp['items'] as List? ?? [])
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      for (final r in list) {
        final v = r['sr_no'];
        final asInt = v is int ? v : int.tryParse(v?.toString() ?? '');
        if (asInt == sr) return r;
      }
      // Fallback: fetch sold list without q
      final resp2 = await InventoryService.listItems(status: 'SOLD');
      final list2 = (resp2['items'] as List? ?? [])
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      for (final r in list2) {
        final v = r['sr_no'];
        final asInt = v is int ? v : int.tryParse(v?.toString() ?? '');
        if (asInt == sr) return r;
      }
    } catch (_) {}
    return null;
  }

  String _updatedRemarks(String old, {required double newPaid, required double remainingAdd, String? note}) {
    // Replace Paid: ... and Remaining: ... tokens; keep other text
    String remarks = old;
    // Aggressively strip any previous Paid/Remaining tokens (with/without colon, currency, commas, and optional notes)
    remarks = remarks.replaceAll(RegExp(r'Paid\s*:?.*?₹?\s*[0-9][0-9,]*(?:\.[0-9]+)?(?:\s*\([^)]*\))?', caseSensitive: false), '');
    remarks = remarks.replaceAll(RegExp(r'Remaining\s*:?.*?₹?\s*[0-9][0-9,]*(?:\.[0-9]+)?', caseSensitive: false), '');
    remarks = remarks.replaceAll(RegExp(r'\s*\|\s*\|\s*'), ' | ');
    remarks = remarks.trim();
    if (remarks.endsWith('|')) remarks = remarks.substring(0, remarks.length - 1).trim();
    final parts = <String>[
      if (remarks.isNotEmpty) remarks,
      'Paid: ₹${newPaid.toStringAsFixed(2)}',
      'Remaining: ₹${remainingAdd.toStringAsFixed(2)}',
      if (note != null && note.trim().isNotEmpty) 'Payment: +₹${note.trim()}',
    ];
    return parts.where((e) => e.isNotEmpty).join(' | ');
  }

  Future<void> _addPayment(Map<String, dynamic> row) async {
    if (_isManual(row)) {
      await _showManualPaymentDialog(row);
      return;
    }

    final srNo = row['sr_no'] as int;
    // fetch fresh row to avoid stale remarks during repeated updates
    final fresh = await _fetchBySr(srNo) ?? row;
    final total = _getTotal(fresh);
    final paid = _getPaid(fresh);
    final remaining = (total - paid).clamp(0, double.infinity);

    final amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: ₹${total.toStringAsFixed(2)} • Paid: ₹${paid.toStringAsFixed(2)} • Remaining: ₹${remaining.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount received'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    final add = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (add <= 0) {
      Get.snackbar('Payment', 'Enter valid amount', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    double newPaid = paid + add;
    if (newPaid >= total - 0.0001) newPaid = total; // snap to fully paid
    final newRemaining = ((total - newPaid).clamp(0, double.infinity) as num).toDouble();
    final oldRemarks = (fresh['remarks'] ?? '').toString();
    final newRemarks = _updatedRemarks(oldRemarks, newPaid: newPaid, remainingAdd: newRemaining, note: noteCtrl.text);

    try {
      final r = await InventoryService.updateRemarks(srNo, newRemarks);
      if (r['success'] == true) {
        Get.snackbar('Payment', 'Updated successfully', snackPosition: SnackPosition.BOTTOM);
        // Optimistic update: reflect new remarks immediately
        setState(() {
          _sold = _sold.map((e) {
            final v = e['sr_no'];
            final id = v is int ? v : int.tryParse(v?.toString() ?? '');
            if (id == srNo) {
              final copy = Map<String, dynamic>.from(e);
              copy['remarks'] = newRemarks;
              return copy;
            }
            return e;
          }).toList();
        });
        await _load();
      } else {
        Get.snackbar('Payment', 'Update failed', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Payment', 'Update failed', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openCustomerPopup(_CustomerGroup group) async {
    final theme = Theme.of(context);
    final rows = group.entries;
    final total = group.totalAmount;
    final paid = group.totalPaid;
    final remaining = group.totalRemaining;
    final NumberFormat currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    String amountText(double value) => currency.format(value);

    Widget buildSummaryPill(String label, double value, {Color? color}) {
      final resolved = color ?? theme.colorScheme.primary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: resolved.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: resolved.withOpacity(0.8))),
            const SizedBox(height: 4),
            Text(amountText(value), style: theme.textTheme.titleMedium?.copyWith(color: resolved, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    Widget buildManualCard(BuildContext ctx, Map<String, dynamic> entry) {
      final total = _getTotal(entry);
      final paid = _getPaid(entry);
      final remaining = ((total - paid).clamp(0, double.infinity) as num).toDouble();
      final settled = remaining <= 0.0001;
      final note = (entry['manual_description'] ?? entry['manual_note'] ?? '').toString().trim();
      final date = DateFormat('dd MMM yyyy').format(_entryDate(entry));
      final actions = <Widget>[
        if (!settled)
          OutlinedButton.icon(
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('Add payment'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _showManualPaymentDialog(entry);
            },
          ),
        if (!settled)
          OutlinedButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark settled'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _markManualEntrySettled(entry);
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit'),
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _editManualEntry(entry);
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: ctx,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Delete entry?'),
                content: const Text('This manual entry will be removed permanently.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirm == true) {
              Navigator.of(ctx).pop();
              _deleteManualEntry(entry['manual_id']);
            }
          },
        ),
      ];

      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Manual', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                  ),
                  const Spacer(),
                  Text(date, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(note, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Amount: ${amountText(total)}', style: theme.textTheme.bodyMedium),
                  Text('Paid: ${amountText(paid)}', style: theme.textTheme.bodyMedium),
                  Text('Remaining: ${amountText(remaining)}', style: theme.textTheme.bodyMedium?.copyWith(color: settled ? theme.colorScheme.tertiary : theme.colorScheme.error)),
                ],
              ),
              const SizedBox(height: 14),
              if (settled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Settled', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
            ],
          ),
        ),
      );
    }

    Widget buildInventoryCard(BuildContext ctx, Map<String, dynamic> entry) {
      final total = _getTotal(entry);
      final paid = _getPaid(entry);
      final remaining = ((total - paid).clamp(0, double.infinity) as num).toDouble();
      final settled = remaining <= 0.0001;
      final String model = (entry['model'] ?? 'Unknown').toString();
      final String variant = (entry['variant_gb_color'] ?? '').toString();
      final String imei = (entry['imei'] ?? '').toString();
      final int? srNo = (entry['sr_no'] is int)
          ? entry['sr_no'] as int
          : int.tryParse(entry['sr_no']?.toString() ?? '');

      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (variant.isNotEmpty)
                          Text(variant, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  if (settled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Settled', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                      child: Text('Due: ${amountText(remaining)}', style: const TextStyle(color: Color(0xFFEF6C00), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (srNo != null) Text('SR no: $srNo', style: theme.textTheme.bodyMedium),
                  if (imei.isNotEmpty) Text('IMEI: $imei', style: theme.textTheme.bodyMedium),
                  Text('Total: ${amountText(total)}', style: theme.textTheme.bodyMedium),
                  Text('Paid: ${amountText(paid)}', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 14),
              if (!settled)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add_card),
                      label: const Text('Add payment'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _addPayment(entry);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark settled'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final fresh = await _fetchBySr(srNo ?? 0) ?? entry;
                        final totalNow = _getTotal(fresh);
                        final newRemaining = 0.0;
                        final newRemarks = _updatedRemarks((fresh['remarks'] ?? '').toString(), newPaid: totalNow, remainingAdd: newRemaining, note: 'settlement ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
                        try {
                          if (srNo != null) {
                            final res = await InventoryService.updateRemarks(srNo, newRemarks);
                            if (res['success'] == true) {
                              Get.snackbar('Payment', 'Settled', snackPosition: SnackPosition.BOTTOM);
                              setState(() {
                                _sold = _sold.map((e) {
                                  final v = e['sr_no'];
                                  final id = v is int ? v : int.tryParse(v?.toString() ?? '');
                                  if (id == srNo) {
                                    final copy = Map<String, dynamic>.from(e);
                                    copy['remarks'] = newRemarks;
                                    return copy;
                                  }
                                  return e;
                                }).toList();
                              });
                              await _load();
                            }
                          }
                        } catch (_) {
                          Get.snackbar('Payment', 'Failed', snackPosition: SnackPosition.BOTTOM);
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxHeight = media.size.height * 0.85;
        return GestureDetector(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      height: 5,
                      width: 48,
                      decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text((group.name.isNotEmpty ? group.name[0] : '?').toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.name.isEmpty ? 'Unknown customer' : group.name,
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                if (group.displayMobile.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Text(group.displayMobile, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Text('${group.count} entr${group.count == 1 ? 'y' : 'ies'}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(child: Text('No transactions yet', style: theme.textTheme.bodyMedium))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              itemBuilder: (ctx2, index) {
                                final entry = rows[index];
                                return _isManual(entry) ? buildManualCard(ctx, entry) : buildInventoryCard(ctx, entry);
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemCount: rows.length,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _allEntries;
    final totalSales = entries.fold<double>(0.0, (s, r) => s + _getTotal(r));
    final totalCollected = entries.fold<double>(0.0, (s, r) {
      final t = _getTotal(r);
      final p = _getPaid(r);
      final capped = p > t ? t : (p < 0 ? 0.0 : p);
      return s + capped;
    });
    final totalRemaining = entries.fold<double>(0.0, (s, r) {
      final t = _getTotal(r);
      final p = _getPaid(r);
      final rem = t - p;
      return s + (rem < 0 ? 0.0 : rem);
    });

    final q = _queryCtrl.text.trim().toLowerCase();
    final filtered = entries.where((r) {
      if (_onlyCredit) {
        final rem = ((_getTotal(r) - _getPaid(r)).clamp(0, double.infinity) as num).toDouble();
        if (rem <= 0) return false;
      }
      if (q.isEmpty) return true;
      final name = _custName(r).toLowerCase();
      final mobile = _custMobile(r).toLowerCase();
      final model = (r['model'] ?? '').toString().toLowerCase();
      final manualDesc = (r['manual_description'] ?? '').toString().toLowerCase();
      final note = (r['manual_note'] ?? r['remarks'] ?? '').toString().toLowerCase();
      return name.contains(q) || mobile.contains(q) || model.contains(q) || manualDesc.contains(q) || note.contains(q);
    }).toList();
    final customerGroups = _buildCustomerGroups(filtered);

    return Scaffold(
      appBar: AppBar(title: Text('Khatabook', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _queryCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by customer, mobile or model',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Only credit'),
                      selected: _onlyCredit,
                      onSelected: (v) => setState(() => _onlyCredit = v),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Download all transactions',
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _exporting ? null : _downloadExcel,
                        icon: _exporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Icon(Icons.file_download_outlined, size: 18),
                        label: Text(_exporting ? 'Preparing…' : 'Export Excel'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF22C1C3)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stat('Total Sales', totalSales),
                        _stat('Collected', totalCollected),
                        _stat('Outstanding', totalRemaining),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...customerGroups.map((group) {
                    final name = group.name;
                    final mobile = group.displayMobile;
                    final rows = group.entries;
                    final totalRem = group.totalRemaining;
                    final count = group.count;
                    final allSettled = group.allSettled;
                    return InkWell(
                      onTap: () => _openCustomerPopup(group),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))],
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE8ECFF),
                            child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Color(0xFF3F51B5))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name.isEmpty ? 'Unknown' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (mobile.isNotEmpty) Text(mobile, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (allSettled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                                child: const Text('Settled', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 12)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                                child: Text('₹${totalRem.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF6C00), fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            const SizedBox(height: 4),
                            Text('$count items', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ]),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: Colors.black38),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddManualEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
    );
  }

  Widget _stat(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _openAddManualEntry() async {
    final created = await _showManualEntryForm();
    if (created == null) return;
    try {
      final payload = _manualPayloadFromLocal(created);
      final apiEntry = await KhatabookService.createEntry(payload);
      _replaceManualEntry(_manualFromApi(apiEntry));
      Get.snackbar('Khatabook', 'Entry added', snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar('Khatabook', 'Failed to add entry', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Create manual entry failed: $err');
    }
  }

  Future<void> _editManualEntry(Map<String, dynamic> entry) async {
    final updated = await _showManualEntryForm(initial: entry);
    if (updated == null) return;
    final id = _manualId(updated['manual_id'] ?? entry['manual_id']);
    if (id == null) {
      Get.snackbar('Khatabook', 'Invalid entry id', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final payload = _manualPayloadFromLocal(updated);
      final apiEntry = await KhatabookService.updateEntry(id, payload);
      _replaceManualEntry(_manualFromApi(apiEntry));
      Get.snackbar('Khatabook', 'Entry updated', snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar('Khatabook', 'Failed to update entry', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Update manual entry failed: $err');
    }
  }

  Future<void> _deleteManualEntry(dynamic manualId) async {
    final id = _manualId(manualId);
    if (id == null) {
      Get.snackbar('Khatabook', 'Invalid entry id', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await KhatabookService.deleteEntry(id);
      _removeManualEntry(id);
      Get.snackbar('Khatabook', 'Entry deleted', snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar('Khatabook', 'Failed to delete entry', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Delete manual entry failed: $err');
    }
  }

  Future<Map<String, dynamic>?> _showManualEntryForm({Map<String, dynamic>? initial}) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: (initial?['manual_name'] ?? '').toString());
    final mobileCtrl = TextEditingController(text: (initial?['manual_mobile'] ?? '').toString());
    final amountCtrl = TextEditingController(text: initial != null ? _getTotal(initial).toStringAsFixed(0) : '');
    final paidCtrl = TextEditingController(text: initial != null ? _getPaid(initial).toStringAsFixed(0) : '0');
    final descCtrl = TextEditingController(text: (initial?['manual_description'] ?? '').toString());
    final noteCtrl = TextEditingController(text: (initial?['manual_note'] ?? '').toString());
    DateTime selectedDate = _entryDate(initial ?? {'manual_date': DateTime.now().toIso8601String()});

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(initial == null ? 'New entry' : 'Edit entry', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Customer name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total amount'),
                        validator: (v) {
                          final value = double.tryParse((v ?? '').trim());
                          if (value == null || value <= 0) return 'Enter valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: paidCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount received'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description / Item'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 20),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2015),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: const Text('Change date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountCtrl.text.trim());
                            final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                            if (paid > amount) {
                              Get.snackbar('Validation', 'Paid amount cannot exceed total', snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            Navigator.of(ctx).pop({
                              'manual_id': initial?['manual_id'] ?? DateTime.now().millisecondsSinceEpoch,
                              'manual_name': nameCtrl.text.trim(),
                              'manual_mobile': mobileCtrl.text.trim(),
                              'manual_amount': amount,
                              'manual_paid': paid,
                              'manual_description': descCtrl.text.trim(),
                              'manual_note': noteCtrl.text.trim(),
                              'manual_date': selectedDate.toIso8601String(),
                              'is_manual': true,
                            });
                          },
                          child: Text(initial == null ? 'Add entry' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    return result;
  }

  Future<void> _showManualPaymentDialog(Map<String, dynamic> entry) async {
    final total = _getTotal(entry);
    final paid = _getPaid(entry);
    final remaining = ((total - paid).clamp(0, double.infinity) as num).toDouble();
    final amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: (entry['manual_note'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ₹${total.toStringAsFixed(2)}'),
            Text('Received: ₹${paid.toStringAsFixed(2)}'),
            Text('Remaining: ₹${remaining.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New payment'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    final addition = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (addition <= 0) {
      Get.snackbar('Payment', 'Enter valid amount', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final newPaid = (paid + addition).clamp(0, total);
    final remainingAfter = total - newPaid;

    final id = _manualId(entry['manual_id']);
    if (id == null) {
      Get.snackbar('Payment', 'Invalid entry id', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final payload = {
      'paid': newPaid,
      'note': noteCtrl.text.trim(),
      'description': entry['manual_description'],
      'amount': total,
    };

    try {
      final apiEntry = await KhatabookService.updateEntry(id, payload);
      _replaceManualEntry(_manualFromApi(apiEntry));
      Get.snackbar('Payment', remainingAfter <= 0 ? 'Marked as settled' : 'Payment recorded', snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar('Payment', 'Failed to update payment', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Manual payment update failed: $err');
    }
  }

  Future<void> _markManualEntrySettled(Map<String, dynamic> entry) async {
    final total = _getTotal(entry);
    final id = _manualId(entry['manual_id']);
    if (id == null) {
      Get.snackbar('Khatabook', 'Invalid entry id', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final apiEntry = await KhatabookService.updateEntry(id, {
        'paid': total,
        'amount': total,
        'note': entry['manual_note'],
        'description': entry['manual_description'],
      });
      _replaceManualEntry(_manualFromApi(apiEntry));
      Get.snackbar('Khatabook', 'Marked as settled', snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar('Khatabook', 'Failed to mark settled', snackPosition: SnackPosition.BOTTOM);
      debugPrint('Manual settle failed: $err');
    }
  }
}
