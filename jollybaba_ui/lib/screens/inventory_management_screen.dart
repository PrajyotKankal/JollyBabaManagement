// lib/screens/inventory_management_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls hide Border;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/inventory_sidebar.dart';
import '../widgets/inventory_stats_header.dart';
import '../widgets/pill_nav_bar.dart';
import '../widgets/web_barcode_scanner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class InventoryManagementScreen extends StatefulWidget {
  final int? initialIndex; // allow external navigation to open specific tab (e.g., List)
  const InventoryManagementScreen({super.key, this.initialIndex});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _DayEntriesCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Color accent;
  final String emptyText;
  final String Function(Map<String, dynamic>) valueBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  const _DayEntriesCard({required this.title, required this.items, required this.accent, required this.emptyText, required this.valueBuilder, required this.subtitleBuilder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.12)),
                alignment: Alignment.center,
                child: Icon(Icons.event_note, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: accent))),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText, style: GoogleFonts.poppins(color: Colors.black54))
          else
            Column(
              children: items.map((item) {
                final model = (item['model'] ?? '').toString();
                final variant = (item['variant_gb_color'] ?? '').toString();
                final imei = (item['imei'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.18)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.isEmpty ? '—' : model,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5, color: const Color(0xFF2F2B43)),
                            ),
                            if (variant.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(variant, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black54)),
                              ),
                            if (imei.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(imei, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45)),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(subtitleBuilder(item), style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(valueBuilder(item), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: accent)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

}

int _clampReportDay(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1) return 1;
  if (day > lastDay) return lastDay;
  return day;
}

class _ReportsPage extends StatelessWidget {
  final String period; // 'Day' or 'Month' or 'Year'
  final int year;
  final int month; // 1-12
  final int day; // 1-31
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(DateTime from, DateTime to) onExportRange;
  const _ReportsPage({required this.period, required this.year, required this.month, required this.day, required this.onPeriodChanged, required this.onYearChanged, required this.onMonthChanged, required this.onDayChanged, required this.items, required this.onExportRange});

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try { return DateFormat('yyyy-MM-dd').parseStrict(s); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    DateTime from;
    DateTime to;
    if (period == 'Year') {
      from = DateTime(year, 1, 1);
      to = DateTime(year, 12, 31);
    } else if (period == 'Day') {
      final safeDay = math.min(day, DateTime(year, month + 1, 0).day);
      final target = DateTime(year, month, safeDay);
      from = DateTime(target.year, target.month, target.day);
      to = from;
    } else {
      from = DateTime(year, month, 1);
      to = DateTime(year, month + 1, 0);
    }

    // Aggregate
    double totalAddedCost = 0;
    double totalSoldSale = 0;
    double totalSoldPurchase = 0;
    int addedCount = 0;
    int soldCount = 0;

    final filtered = items.where((e) {
      final d = _parseDate(e['date']);
      if (d == null) return false;
      if (period == 'Day') {
        return d.year == from.year && d.month == from.month && d.day == from.day;
      }
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();

    for (final e in filtered) {
      final p = (e['purchase_amount'] is num) ? (e['purchase_amount'] as num).toDouble() : double.tryParse(e['purchase_amount']?.toString() ?? '') ?? 0.0;
      totalAddedCost += p;
      addedCount++;
    }

    for (final e in items) {
      final sd = _parseDate(e['sell_date']);
      if (sd == null) continue;
      final within = period == 'Day'
          ? (sd.year == from.year && sd.month == from.month && sd.day == from.day)
          : (!sd.isBefore(from) && !sd.isAfter(to));
      if (within) {
        final s = (e['sell_amount'] is num) ? (e['sell_amount'] as num).toDouble() : double.tryParse(e['sell_amount']?.toString() ?? '') ?? 0.0;
        totalSoldSale += s;
        final purchaseForSold = (e['purchase_amount'] is num)
            ? (e['purchase_amount'] as num).toDouble()
            : double.tryParse(e['purchase_amount']?.toString() ?? '') ?? 0.0;
        totalSoldPurchase += purchaseForSold;
        soldCount++;
      }
    }
    final profit = totalSoldSale - totalSoldPurchase;

    final List<Map<String, dynamic>> dayAddedItems = period == 'Day'
        ? filtered
        : const [];
    final List<Map<String, dynamic>> daySoldItems = period == 'Day'
        ? items.where((e) {
            final sd = _parseDate(e['sell_date']);
            return sd != null && sd.year == from.year && sd.month == from.month && sd.day == from.day;
          }).toList()
        : const [];

    // Weekly buckets
    Map<DateTime, List<Map<String, dynamic>>> byWeek = {};
    if (period != 'Day') {
      for (final e in filtered) {
        final d = _parseDate(e['date']);
        if (d == null) continue;
        final startOfWeek = d.subtract(Duration(days: d.weekday - 1)); // Mon
        final key = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        byWeek.putIfAbsent(key, () => []).add(e);
      }
    }
    final weeks = byWeek.keys.toList()..sort();

    return _PageWrapper(
      title: 'Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header with period controls
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6F5DE7), const Color(0xFF9076F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: const Color(0xFF6F5DE7).withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;
                final chips = Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Day'),
                    selected: period == 'Day',
                    onSelected: (_) => onPeriodChanged('Day'),
                    selectedColor: Colors.white,
                    labelStyle: TextStyle(color: period == 'Day' ? const Color(0xFF6F5DE7) : Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.14),
                  ),
                  ChoiceChip(
                    label: const Text('Month'),
                    selected: period == 'Month',
                    onSelected: (_) => onPeriodChanged('Month'),
                    selectedColor: Colors.white,
                    labelStyle: TextStyle(color: period == 'Month' ? const Color(0xFF6F5DE7) : Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.14),
                  ),
                  ChoiceChip(
                    label: const Text('Year'),
                    selected: period == 'Year',
                    onSelected: (_) => onPeriodChanged('Year'),
                    selectedColor: Colors.white,
                    labelStyle: TextStyle(color: period == 'Year' ? const Color(0xFF6F5DE7) : Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.14),
                  ),
                ]);
                final exportButton = FilledButton.tonalIcon(
                  onPressed: () => onExportRange(from, to),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF4527A0),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
                if (isCompact) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    chips,
                    const SizedBox(height: 12),
                    exportButton,
                  ]);
                }
                return Row(children: [
                  chips,
                  const Spacer(),
                  exportButton,
                ]);
              }),
              const SizedBox(height: 12),
              Row(children: [
                IconButton(
                  onPressed: () {
                    if (period == 'Year') {
                      onYearChanged(year - 1);
                    } else if (period == 'Day') {
                      final prev = from.subtract(const Duration(days: 1));
                      onYearChanged(prev.year);
                      onMonthChanged(prev.month);
                      onDayChanged(prev.day);
                    } else {
                      int m = month - 1; int y = year; if (m < 1) { m = 12; y--; }
                      onYearChanged(y); onMonthChanged(m);
                    }
                  },
                  style: ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.12))),
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      period == 'Year'
                          ? year.toString()
                          : period == 'Day'
                              ? DateFormat('dd MMM yyyy').format(from)
                              : DateFormat('MMMM yyyy').format(DateTime(year, month, 1)),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period == 'Day'
                          ? 'Daily snapshot'
                          : '${DateFormat('dd MMM').format(from)} - ${DateFormat('dd MMM').format(to)}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    if (period == 'Year') {
                      onYearChanged(year + 1);
                    } else if (period == 'Day') {
                      final next = from.add(const Duration(days: 1));
                      onYearChanged(next.year);
                      onMonthChanged(next.month);
                      onDayChanged(next.day);
                    } else {
                      int m = month + 1; int y = year; if (m > 12) { m = 1; y++; }
                      onYearChanged(y); onMonthChanged(m);
                    }
                  },
                  style: ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.12))),
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          // Soft stat cards
          Wrap(spacing: 12, runSpacing: 12, children: [
            _miniStat('Added', addedCount.toString(), Icons.add_box, const Color(0xFFF3F1FF), const Color(0xFF5C4DD8), const Color(0xFFE4E0FF)),
            _miniStat('Sold', soldCount.toString(), Icons.sell, const Color(0xFFFFF1F6), const Color(0xFFB23F84), const Color(0xFFFFE0EC)),
            _miniStat('Added Cost', '₹${totalAddedCost.toStringAsFixed(2)}', Icons.shopping_bag, const Color(0xFFF9F5FF), const Color(0xFF6C4CCB), const Color(0xFFECE2FF)),
            _miniStat('Sold Purchase', '₹${totalSoldPurchase.toStringAsFixed(2)}', Icons.inventory, const Color(0xFFFFF4ED), const Color(0xFFB45F39), const Color(0xFFFFE3D3)),
            _miniStat('Sold Sale', '₹${totalSoldSale.toStringAsFixed(2)}', Icons.attach_money, const Color(0xFFF2FFF5), const Color(0xFF2E7D32), const Color(0xFFD3F6DA)),
            _miniStat('Profit', '₹${profit.toStringAsFixed(2)}', Icons.trending_up, const Color(0xFFFFF6FE), const Color(0xFF7B1FA2), const Color(0xFFF6E3FF)),
          ]),
          const SizedBox(height: 12),
          if (period == 'Day') ...[
            _DayEntriesCard(
              title: 'Added on ${DateFormat('dd MMM').format(from)}',
              emptyText: 'No stock added on this day',
              items: dayAddedItems,
              accent: const Color(0xFF6F5DE7),
              valueBuilder: (item) {
                final p = (item['purchase_amount'] is num)
                    ? (item['purchase_amount'] as num).toDouble()
                    : double.tryParse(item['purchase_amount']?.toString() ?? '') ?? 0.0;
                return '₹${p.toStringAsFixed(2)}';
              },
              subtitleBuilder: (item) => 'IMEI: ${(item['imei'] ?? '').toString()}',
            ),
            const SizedBox(height: 12),
            _DayEntriesCard(
              title: 'Sold on ${DateFormat('dd MMM').format(from)}',
              emptyText: 'No sales recorded on this day',
              items: daySoldItems,
              accent: const Color(0xFFB23F84),
              valueBuilder: (item) {
                final s = (item['sell_amount'] is num)
                    ? (item['sell_amount'] as num).toDouble()
                    : double.tryParse(item['sell_amount']?.toString() ?? '') ?? 0.0;
                return s > 0 ? '₹${s.toStringAsFixed(2)}' : '—';
              },
              subtitleBuilder: (item) {
                final purchased = (item['purchase_amount'] is num)
                    ? (item['purchase_amount'] as num).toDouble()
                    : double.tryParse(item['purchase_amount']?.toString() ?? '') ?? 0.0;
                final profitVal = ((item['sell_amount'] is num)
                        ? (item['sell_amount'] as num).toDouble()
                        : double.tryParse(item['sell_amount']?.toString() ?? '') ?? 0.0) - purchased;
                final profitLabel = profitVal >= 0 ? 'Profit' : 'Loss';
                return 'Buy: ₹${purchased.toStringAsFixed(2)}  •  $profitLabel: ₹${profitVal.abs().toStringAsFixed(2)}';
              },
            ),
          ] else ...[
            // Weeks
            for (final start in weeks) ...[
              _weekCard(start, byWeek[start]!, items),
              const SizedBox(height: 10),
            ],
            if (weeks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No data for selected period'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color bg, Color fg, Color border) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: border.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: fg.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))]),
          child: Icon(icon, color: fg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: fg, fontSize: 17)),
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: fg.withOpacity(0.75))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _weekCard(DateTime start, List<Map<String, dynamic>> weekItems, List<Map<String, dynamic>> all) {
    final end = start.add(const Duration(days: 6));
    // Compute sold in this week (by sell_date)
    int sold = 0; double sellAmt = 0;
    for (final e in all) {
      final sd = _parseDate(e['sell_date']);
      if (sd != null && !sd.isBefore(start) && !sd.isAfter(end)) {
        sold++;
        sellAmt += (e['sell_amount'] is num) ? (e['sell_amount'] as num).toDouble() : double.tryParse(e['sell_amount']?.toString() ?? '') ?? 0.0;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E0FF)),
        boxShadow: [BoxShadow(color: const Color(0xFF6F5DE7).withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF1EEFF), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Week ${DateFormat('w').format(start)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: const Color(0xFF4527A0))), Text('${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6F5DE7)))])),
            Row(children: [
              _StatusPill(text: 'Added ${weekItems.length}', bg: const Color(0xFFEDE9FF), fg: const Color(0xFF5C4DD8)),
              const SizedBox(width: 6),
              _StatusPill(text: 'Sold $sold', bg: const Color(0xFFFFEAF5), fg: const Color(0xFFB23F84)),
            ])
          ]),
        ),
        const SizedBox(height: 10),
        for (final e in weekItems) _dayRow(e),
        if (weekItems.isEmpty) const Text('No additions this week', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: Text('Week sale: ₹${sellAmt.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _dayRow(Map<String, dynamic> e) {
    final d = _parseDate(e['date']);
    final label = d != null ? DateFormat('dd EEE').format(d) : '-';
    final purchase = (e['purchase_amount'] is num) ? (e['purchase_amount'] as num).toDouble() : double.tryParse(e['purchase_amount']?.toString() ?? '') ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(10)), child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(e['model'] ?? '').toString()} • ${(e['variant_gb_color'] ?? '').toString()}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)), Text('IMEI: ${(e['imei'] ?? '').toString()}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87))])),
        const SizedBox(width: 12),
        Text('₹${purchase.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _AmountBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final IconData icon;
  const _AmountBadge({required this.label, required this.value, required this.bg, required this.fg, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: bg.withOpacity(0.6))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, color: fg.withOpacity(0.9))),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

extension _InventoryListSearch on _InventoryManagementScreenState {
  void _onListQueryChanged(String v) {
    _listDebounce?.cancel();
    _listDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _listQuery = v.trim();
      });
    });
  }
}

class _ChipTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _ChipTile({required this.label, required this.value, this.icon});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E6EF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: Colors.black54), const SizedBox(width: 8)],
            Flexible(child: Text(value.isEmpty ? '-' : value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    ]);
  }
}

class _SellPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController imeiCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController customerCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController remarksCtrl;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onLookup;
  final VoidCallback onScanImei;
  final VoidCallback? onSendWhatsapp;
  final bool whatsappEnabled;
  final bool markSoldEnabled;
  final Map<String, dynamic>? selected;
  final String lookupMode;
  final ValueChanged<String> onChangeLookupMode;
  final String paymentMode; // 'CASH' or 'CREDIT'
  final ValueChanged<String> onChangePaymentMode;
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> customerSuggestions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<Map<String, dynamic>> onPickSuggestion;
  final ValueChanged<Map<String, dynamic>> onPickCustomerSuggestion;
  final VoidCallback onDismissSuggestions;
  // slider state
  final int step;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool canProceed;
  const _SellPage({required this.formKey, required this.imeiCtrl, required this.dateCtrl, required this.amountCtrl, required this.paidCtrl, required this.customerCtrl, required this.mobileCtrl, required this.addressCtrl, required this.remarksCtrl, required this.onPickDate, required this.onSubmit, required this.onLookup, required this.onScanImei, this.onSendWhatsapp, required this.whatsappEnabled, required this.markSoldEnabled, required this.selected, required this.lookupMode, required this.onChangeLookupMode, required this.paymentMode, required this.onChangePaymentMode, required this.suggestions, required this.customerSuggestions, required this.onSearchChanged, required this.onCustomerChanged, required this.onPickSuggestion, required this.onPickCustomerSuggestion, required this.onDismissSuggestions, required this.step, required this.onBack, required this.onNext, required this.canProceed});
  @override
  Widget build(BuildContext context) {
    return _PageWrapper(
      title: 'Sell',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset + 12),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
            // Steps content
            if (step == 0) ...[
              // Row 1: Customer info (2 fields)
              Row(children: [
                Expanded(child: _field('Customer Name', customerCtrl, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null, onChanged: onCustomerChanged, onTap: onDismissSuggestions)),
                const SizedBox(width: 10),
                Expanded(child: _field('Mobile Number', mobileCtrl, keyboardType: TextInputType.phone, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null, onTap: onDismissSuggestions)),
              ]),
              if (customerSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3E6EF)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customerSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final suggestion = customerSuggestions[idx];
                      final name = (suggestion['name'] ?? '').toString();
                      final phone = (suggestion['phone'] ?? '').toString();
                      final address = (suggestion['address'] ?? '').toString();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF6D5DF6).withOpacity(0.12),
                          child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: const TextStyle(color: Color(0xFF6D5DF6), fontWeight: FontWeight.w600)),
                        ),
                        title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (phone.isNotEmpty) Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                          if (address.isNotEmpty) Text(address, style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45)),
                        ]),
                        onTap: () => onPickCustomerSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              // Row 2: Lookup (2 fields)
              Row(children: [
                DropdownButton<String>(
                  value: lookupMode,
                  items: const [DropdownMenuItem(value: 'IMEI', child: Text('IMEI')), DropdownMenuItem(value: 'SR', child: Text('SR No.')), DropdownMenuItem(value: 'MODEL', child: Text('Model'))],
                  onChanged: (v) {
                    if (v != null) {
                      onDismissSuggestions();
                      onChangeLookupMode(v);
                    }
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'Search',
                    imeiCtrl,
                    onChanged: onSearchChanged,
                    suffix: IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      tooltip: 'Scan IMEI',
                      onPressed: onScanImei,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(height: 42, child: ElevatedButton.icon(onPressed: onLookup, icon: const Icon(Icons.search), label: const Text('Lookup'))),
              ]),
              if (suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 6),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: const Color(0xFFE3E6EF)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text('${r['model'] ?? ''} • ${r['variant_gb_color'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('SR: ${r['sr_no']} • IMEI: ${r['imei']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => onPickSuggestion(r),
                      );
                    },
                  ),
                ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${(selected!['model'] ?? '').toString()} • ${(selected!['variant_gb_color'] ?? '').toString()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IMEI: ${(selected!['imei'] ?? '').toString()} • Purchase: ₹${((selected!['purchase_amount'] is num) ? (selected!['purchase_amount'] as num).toDouble() : double.tryParse((selected!['purchase_amount'] ?? '').toString()) ?? 0).toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              ],
            ] else ...[
              Row(children: [
                Expanded(child: _field('Sell Date', dateCtrl, readOnly: true, onTap: () {
                  onDismissSuggestions();
                  onPickDate();
                }, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                const SizedBox(width: 10),
                Expanded(child: _field('Sell Amount', amountCtrl, keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter amount' : null, onTap: onDismissSuggestions)),
              ]),
              _field('Customer Address (optional)', addressCtrl, onTap: onDismissSuggestions),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Payment Mode', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: [
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: paymentMode == 'CASH',
                        onSelected: (_) {
                          onDismissSuggestions();
                          onChangePaymentMode('CASH');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Credit'),
                        selected: paymentMode == 'CREDIT',
                        onSelected: (_) {
                          onDismissSuggestions();
                          onChangePaymentMode('CREDIT');
                        },
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(child: _field('Amount Paid (optional)', paidCtrl, keyboardType: TextInputType.number, onTap: onDismissSuggestions)),
              ]),
              _field('Remarks (optional)', remarksCtrl, onTap: onDismissSuggestions),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF6C63FF), Color(0xFF8E7BFF)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: markSoldEnabled ? onSubmit : null,
                    icon: const Icon(Icons.sell, color: Colors.white),
                    label: Text('Mark SOLD', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(140, 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // WhatsApp button directly below Mark SOLD, disabled initially, enabled after sale
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF20BD5F), Color(0xFF128C7E)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: (whatsappEnabled && onSendWhatsapp != null) ? onSendWhatsapp : null,
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                    label: Text('Send WhatsApp Message', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(200, 44),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onBack != null && step > 0) TextButton(onPressed: onBack, child: Text('← Back', style: GoogleFonts.poppins())),
                const Spacer(),
                if (onNext != null && step < 1)
                  Opacity(
                    opacity: canProceed ? 1 : 0.6,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF6C63FF), Color(0xFF8E7BFF)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: canProceed ? onNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(120, 44),
                        ),
                        child: Text('Next →', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      );
        },
      ),
    );
  }
}

Widget _readOnlyRow(String l1, String v1, String l2, String v2) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(children: [
      Expanded(child: _readOnlyTile(l1, v1)),
      const SizedBox(width: 10),
      Expanded(child: _readOnlyTile(l2, v2)),
    ]),
  );
}

Widget _readOnlyTile(String label, String value) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13)),
    ),
  ]);
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _StatusPill({required this.text, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _StatusToggleChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;
  const _StatusToggleChip({required this.label, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: selected ? const Color(0xFF6D5DF6).withOpacity(0.14) : Colors.grey.shade200,
      labelStyle: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF6D5DF6) : Colors.black87),
      side: BorderSide(color: selected ? const Color(0xFF6D5DF6) : Colors.grey.shade300),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ListPage extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> allItems; // For stats calculation
  final Map<String, dynamic> visibleIndex;
  final Future<void> Function(Map<String, dynamic> row) onSellQuick;
  final Future<void> Function(Map<String, dynamic> row) onMakeAvailable;
  final Future<void> Function(int srNo, String initial) onEditRemarks;
  final void Function(Map<String, dynamic> row) onOpenInfo;
  final void Function(Map<String, dynamic> row) onEditItem;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final bool isTechnician;
  final Set<int> quickSellBusy;
  final Set<int> makeAvailableBusy;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  // Sort
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSortChanged;
  // Pull-to-refresh
  final Future<void> Function() onRefresh;
  const _ListPage({
    required this.loading,
    required this.items,
    required this.allItems,
    required this.visibleIndex,
    required this.onSellQuick,
    required this.onMakeAvailable,
    required this.onEditRemarks,
    required this.onOpenInfo,
    required this.onEditItem,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.isTechnician,
    required this.quickSellBusy,
    required this.makeAvailableBusy,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.sortField,
    required this.sortAscending,
    required this.onSortChanged,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _PageWrapper(
        title: 'Inventory List',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasQuery = searchCtrl.text.trim().isNotEmpty;

    // Calculate stats
    final availableCount = allItems.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'AVAILABLE').length;
    final soldCount = allItems.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'SOLD').length;
    double totalRevenue = 0;
    double totalProfit = 0;
    for (final e in allItems) {
      if ((e['status'] ?? '').toString().toUpperCase() == 'SOLD') {
        final sell = (e['sell_amount'] is num) ? (e['sell_amount'] as num).toDouble() : double.tryParse(e['sell_amount']?.toString() ?? '') ?? 0;
        final purchase = (e['purchase_amount'] is num) ? (e['purchase_amount'] as num).toDouble() : double.tryParse(e['purchase_amount']?.toString() ?? '') ?? 0;
        totalRevenue += sell;
        totalProfit += (sell - purchase);
      }
    }
    
    return _PageWrapper(
      title: 'Inventory List',
      child: Column(
        children: [
          // Stats header (desktop only)
          if (MediaQuery.of(context).size.width >= 900 && !isTechnician)
            InventoryStatsHeader(
              totalItems: allItems.length,
              availableCount: availableCount,
              soldCount: soldCount,
              totalRevenue: totalRevenue,
              totalProfit: totalProfit,
              showFinancials: !isTechnician,
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Filter by status', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      _StatusToggleChip(
                        label: 'All',
                        value: 'ALL',
                        groupValue: statusFilter,
                        onChanged: onStatusFilterChanged,
                      ),
                      _StatusToggleChip(
                        label: 'Available',
                        value: 'AVAILABLE',
                        groupValue: statusFilter,
                        onChanged: onStatusFilterChanged,
                      ),
                      _StatusToggleChip(
                        label: 'Sold',
                        value: 'SOLD',
                        groupValue: statusFilter,
                        onChanged: onStatusFilterChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by Model, IMEI, Variant, Customer',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8F9FF),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Sort chips row
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Sort by:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip('SR #', 'sr_no'),
                        const SizedBox(width: 6),
                        _buildSortChip('Model', 'model'),
                        const SizedBox(width: 6),
                        _buildSortChip('Date', 'date'),
                        const SizedBox(width: 6),
                        _buildSortChip('Status', 'status'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3E6EF)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hasQuery ? Icons.search_off_rounded : Icons.inventory_2_outlined, size: 40, color: Colors.black45),
                  const SizedBox(height: 12),
                  Text(
                    hasQuery ? 'No mobiles match your search.' : 'No inventory items found.',
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  if (hasQuery) ...[
                    const SizedBox(height: 4),
                    Text('Try a different keyword or clear the filter.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45)),
                  ],
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                        final r = items[i];
                        final status = (r['status'] ?? '').toString();
                        final srNo = r['sr_no'] as int;
                        final idx = visibleIndex['$srNo']?.toString() ?? '';
                        final available = status == 'AVAILABLE';
                        final isSold = status == 'SOLD';

                        Color statusBg = available ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
                        Color statusFg = available ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
                        Color avatarBg = available ? Colors.teal.withOpacity(0.1) : Colors.deepPurple.withOpacity(0.1);
                        Color avatarFg = available ? Colors.teal : Colors.deepPurple;

                    final total = (r['sell_amount'] is num) ? (r['sell_amount'] as num).toDouble() : double.tryParse(r['sell_amount']?.toString() ?? '') ?? 0.0;
                    final remarks = (r['remarks'] ?? '').toString();
                    final paidMatch = RegExp(r'Paid:\s*₹?([0-9]+(?:\.[0-9]+)?)').firstMatch(remarks);
                    final paid = paidMatch != null ? double.tryParse(paidMatch.group(1)!) ?? 0.0 : 0.0;
                    final remaining = (total - paid).clamp(0, double.infinity);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onOpenInfo(r),
                        hoverColor: const Color(0xFF6D5DF6).withOpacity(0.04),
                        splashColor: const Color(0xFF6D5DF6).withOpacity(0.08),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8EAF2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0,6))],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(radius: 18, backgroundColor: avatarBg, foregroundColor: avatarFg, child: Text(available ? (idx.isEmpty ? '-' : idx) : 'S')),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${r['brand'] ?? '-'} • ${r['model'] ?? ''}',
                                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    (r['variant_gb_color'] ?? '').toString(),
                                                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _StatusPill(text: status, bg: statusBg, fg: statusFg),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          const Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text('IMEI: ${r['imei'] ?? ''}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        ]),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          const Icon(Icons.event, size: 14, color: Colors.black45),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(isTechnician ? 'Date: ${r['date'] ?? ''}' : 'Date: ${r['date'] ?? ''} • Vendor: ${r['vendor_purchase'] ?? ''}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black54))),
                                        ]),
                                        if (!available && !isTechnician) ...[
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.receipt_long, size: 14, color: Colors.black45),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text('Total: ₹${total.toStringAsFixed(2)} • Paid: ₹${paid.toStringAsFixed(2)} • Remaining: ₹${remaining.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black54))),
                                          ]),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (available && !isTechnician) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: quickSellBusy.contains(srNo) ? null : () => onSellQuick(r),
                                    icon: const Icon(Icons.sell_rounded),
                                    label: const Text('Sell'),
                                  ),
                                ),
                              ] else if (isSold && !isTechnician) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: makeAvailableBusy.contains(srNo) ? null : () => onMakeAvailable(r),
                                    icon: const Icon(Icons.undo_rounded),
                                    label: const Text('Make Available'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                  ],
                ),
    );
  }
  
  Widget _buildSortChip(String label, String field) {
    final isSelected = sortField == field;
    return GestureDetector(
      onTap: () => onSortChanged(field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6D5DF6).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6D5DF6).withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6D5DF6) : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 12,
                color: const Color(0xFF6D5DF6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddStockPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController dateCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController imeiCtrl;
  final TextEditingController variantCtrl;
  final TextEditingController detailsCtrl;
  final TextEditingController vendorCtrl;
  final TextEditingController purchaseCtrl;
  final TextEditingController remarksCtrl;
  final TextEditingController vendorPhoneCtrl;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onImport;
  final VoidCallback onScanImei;
  final bool showPurchaseField;
  final List<Map<String, dynamic>> vendorSuggestions;
  final ValueChanged<String> onVendorChanged;
  final ValueChanged<Map<String, dynamic>> onPickVendorSuggestion;
  final VoidCallback onDismissVendorSuggestions;
  const _AddStockPage({required this.formKey, required this.dateCtrl, required this.brandCtrl, required this.modelCtrl, required this.imeiCtrl, required this.variantCtrl, required this.detailsCtrl, required this.vendorCtrl, required this.purchaseCtrl, required this.remarksCtrl, required this.vendorPhoneCtrl, required this.onPickDate, required this.onSubmit, required this.onImport, required this.onScanImei, this.showPurchaseField = true, required this.vendorSuggestions, required this.onVendorChanged, required this.onPickVendorSuggestion, required this.onDismissVendorSuggestions});
  @override
  Widget build(BuildContext context) {
    return _PageWrapper(
      title: 'Add New Mobile',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import Excel/CSV'),
              ),
            ),
            Row(children: [
              Expanded(child: _field('Purchase Date', dateCtrl, readOnly: true, onTap: () {
                onDismissVendorSuggestions();
                onPickDate();
              }, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
              const SizedBox(width: 10),
              Expanded(child: _field('Brand', brandCtrl, onTap: onDismissVendorSuggestions)),
            ]),
            Row(children: [
              Expanded(child: _field('Model Name', modelCtrl, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null, onTap: onDismissVendorSuggestions)),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Live IMEI validation
                    final imei = imeiCtrl.text.replaceAll(RegExp(r'\D'), '');
                    final isValid = imei.length == 15;
                    final hasContent = imei.isNotEmpty;
                    return _field(
                      'IMEI',
                      imeiCtrl,
                      onTap: onDismissVendorSuggestions,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasContent)
                            Icon(
                              isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: isValid ? const Color(0xFF6D5DF6) : Colors.orange,
                              size: 20,
                            ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined),
                            tooltip: 'Scan IMEI',
                            onPressed: onScanImei,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ]),
            _field('Variant', variantCtrl, onTap: onDismissVendorSuggestions),
            _field('Details (optional)', detailsCtrl, onTap: onDismissVendorSuggestions),
            Row(children: [
              Expanded(child: _field('Remarks', remarksCtrl, onTap: onDismissVendorSuggestions)),
              const SizedBox(width: 10),
              Expanded(child: _field('Vendor', vendorCtrl, onChanged: onVendorChanged)),
            ]),
            if (vendorSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E6EF)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vendorSuggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final suggestion = vendorSuggestions[idx];
                    final name = (suggestion['name'] ?? '').toString();
                    final phone = (suggestion['phone'] ?? '').toString();
                    final total = suggestion['total'];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4C84FF).withOpacity(0.12),
                        child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: const TextStyle(color: Color(0xFF4C84FF), fontWeight: FontWeight.w600)),
                      ),
                      title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (phone.isNotEmpty) Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                        if (total is int && total > 1) Text('$total purchases', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45)),
                      ]),
                      onTap: () => onPickVendorSuggestion(suggestion),
                    );
                  },
                ),
              ),
            Row(children: [
              Expanded(child: _field('Purchase Amount', purchaseCtrl, keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter amount' : null, onTap: onDismissVendorSuggestions)),
              const SizedBox(width: 10),
              Expanded(child: _field('Vendor Number', vendorPhoneCtrl, keyboardType: TextInputType.phone, onTap: onDismissVendorSuggestions)),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: onSubmit, icon: const Icon(Icons.save), label: const Text('Save'))),
          ],
        ),
      ),
    );
  }
}

Widget _field(String label, TextEditingController controller, {bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType, String? Function(String?)? validator, ValueChanged<String>? onChanged, Widget? suffix}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: GoogleFonts.poppins(color: Colors.black87),
        decoration: InputDecoration(
          isDense: true,
          hintText: label,
          hintStyle: GoogleFonts.poppins(color: Colors.black45),
          filled: true,
          fillColor: const Color(0xFFF8F9FF),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE3E6EF), width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D5DF6), width: 1.5)),
          suffixIcon: suffix,
        ),
      )
    ]),
  );
}

class _ScannerOverlayPainter extends CustomPainter {
  final ui.Rect boxRect;
  _ScannerOverlayPainter(this.boxRect);

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.35);
    final background = Path()..addRect(ui.Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(ui.RRect.fromRectAndRadius(boxRect, const Radius.circular(18)));
    final overlayPath = Path.combine(PathOperation.difference, background, cutout);
    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF6D5DF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(ui.RRect.fromRectAndRadius(boxRect, const Radius.circular(18)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => oldDelegate.boxRect != boxRect;
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  int _navIndex = 1; // default to Sell tab
  bool _sidebarCollapsed = false; // For collapsible sidebar
  bool _isTechnician = false;
  bool _sellWhatsappEnabled = false; // becomes true after successful sale
  DateTime? _sellWhatsappCooldownUntil; // cooldown timer
  String? _lastSoldCustomer;
  String? _lastSoldPhone;
  String? _lastSoldModel;
  String? _lastSoldBrand;
  String? _lastSoldVariant;
  bool _canSubmitSell = true;
  final Set<int> _quickSellBusy = <int>{};
  final Set<int> _makeAvailableBusy = <int>{};
  String? _lastSoldImei;
  double? _lastSoldAmount;
  String? _lastSoldDate;
  MobileScannerController? _scannerController;
  bool _isScanning = false;

  // Data
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _visibleIndex = {};
  // Reports state
  String _reportPeriod = 'Month'; // Day | Month | Year
  int _reportYear = DateTime.now().year;
  int _reportMonth = DateTime.now().month; // 1-12
  int _reportDay = DateTime.now().day;
  // List search
  final _listSearchCtrl = TextEditingController();
  String _listQuery = '';
  Timer? _listDebounce;
  // Filters
  final _brandFilterCtrl = TextEditingController();
  String _brandFilter = '';
  String _statusFilter = 'ALL';
  // Sort state
  String _sortField = 'sr_no'; // sr_no, model, date, status
  bool _sortAscending = false; // false = newest first

  // Add form
  final _addFormKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _variantCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _purchaseCtrl = TextEditingController();
  final _vendorPhoneCtrl = TextEditingController();
  List<Map<String, dynamic>> _vendorSuggestions = [];
  Timer? _vendorDebounce;

  // Sell form (page)
  final _sellImeiCtrl = TextEditingController();
  final _sellDateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _sellAmountCtrl = TextEditingController();
  final _sellPaidCtrl = TextEditingController();
  final _sellCustomerCtrl = TextEditingController();
  final _sellMobileCtrl = TextEditingController();
  final _sellAddressCtrl = TextEditingController();
  final _sellRemarksCtrl = TextEditingController();
  final _sellFormKey = GlobalKey<FormState>();
  Map<String, dynamic>? _sellSelected; // selected AVAILABLE item after lookup
  String _lookupMode = 'IMEI';
  List<Map<String, dynamic>> _sellTypeahead = [];
  List<Map<String, dynamic>> _customerSuggestions = [];
  Timer? _sellDebounce;
  Timer? _customerDebounce;
  String _paymentMode = 'CASH';
  int _sellStep = 0; // 0: customer + lookup, 1: amounts + payment

  bool _canProceedSellStep() {
    if (_sellStep == 0) {
      final hasCust = _sellCustomerCtrl.text.trim().isNotEmpty && _sellMobileCtrl.text.trim().isNotEmpty;
      final hasSelectionOrQuery = _sellSelected != null || _sellImeiCtrl.text.trim().isNotEmpty;
      return hasCust && hasSelectionOrQuery;
    }
    // step 1
    final amt = double.tryParse(_sellAmountCtrl.text.trim());
    return _sellDateCtrl.text.trim().isNotEmpty && amt != null && amt > 0;
  }

  void _resetSellForm() {
    _sellImeiCtrl.clear();
    _sellDateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _sellAmountCtrl.clear();
    _sellPaidCtrl.clear();
    _sellCustomerCtrl.clear();
    _sellMobileCtrl.clear();
    _sellAddressCtrl.clear();
    _sellRemarksCtrl.clear();
    _sellSelected = null;
    _sellTypeahead = [];
    _customerSuggestions = [];
    _lookupMode = 'IMEI';
    _paymentMode = 'CASH';
    _sellStep = 0;
    _sellWhatsappEnabled = false; // reset button to disabled on new form
    _sellWhatsappCooldownUntil = null;
    _lastSoldCustomer = null;
    _lastSoldPhone = null;
    _lastSoldModel = null;
    _lastSoldBrand = null;
    _lastSoldVariant = null;
    _lastSoldImei = null;
    _lastSoldAmount = null;
    _lastSoldDate = null;
    _canSubmitSell = true;
  }

  void _clearSellInputsPostSuccess() {
    _sellImeiCtrl.clear();
    _sellDateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _sellAmountCtrl.clear();
    _sellPaidCtrl.clear();
    _sellCustomerCtrl.clear();
    _sellMobileCtrl.clear();
    _sellAddressCtrl.clear();
    _sellRemarksCtrl.clear();
    _sellSelected = null;
    _sellTypeahead = [];
    _customerSuggestions = [];
    _lookupMode = 'IMEI';
    _sellStep = 1; // stay on payment step so WhatsApp button remains visible
    _canSubmitSell = false;
  }

  void _dismissSellSuggestions() {
    if (_sellTypeahead.isEmpty && _customerSuggestions.isEmpty) return;
    setState(() {
      _sellTypeahead = [];
      _customerSuggestions = [];
    });
  }

  void _dismissVendorSuggestions() {
    if (_vendorSuggestions.isEmpty) return;
    setState(() {
      _vendorSuggestions = [];
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _sellDebounce?.cancel();
    _customerDebounce?.cancel();
    _vendorDebounce?.cancel();
    _listDebounce?.cancel();
    super.dispose();
  }

  bool _isSellWhatsappCoolingDown() {
    if (_sellWhatsappCooldownUntil == null) return false;
    return DateTime.now().isBefore(_sellWhatsappCooldownUntil!);
  }

  void _startSellWhatsappCooldown() {
    _sellWhatsappCooldownUntil = DateTime.now().add(const Duration(seconds: 5));
    if (mounted) setState(() {});
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _sendSellWhatsapp({String? phone, String? customer, String? model}) async {
    final targetPhone = (phone ?? _lastSoldPhone ?? _sellMobileCtrl.text).trim();
    if (targetPhone.isEmpty) {
      Get.snackbar('WhatsApp', 'Customer phone number is required to send a WhatsApp message.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_isSellWhatsappCoolingDown()) return;

    final rawName = (customer ?? _lastSoldCustomer ?? _sellCustomerCtrl.text).trim();
    final rawModel = (model ?? _lastSoldModel ?? _sellSelected?['model']?.toString() ?? '').trim();
    final name = rawName.isEmpty ? 'there' : rawName;
    final device = rawModel.isEmpty ? 'your device' : rawModel;
    final brand = (_lastSoldBrand ?? _sellSelected?['brand']?.toString() ?? '').trim();
    final variant = (_lastSoldVariant ?? _sellSelected?['variant_gb_color']?.toString() ?? '').trim();
    final imei = (_lastSoldImei ?? _sellSelected?['imei']?.toString() ?? '').trim();
    final sellAmount = _lastSoldAmount ?? double.tryParse(_sellAmountCtrl.text.trim());
    final amountStr = sellAmount == null || sellAmount <= 0 ? '—' : sellAmount.toStringAsFixed(2);
    final sellDateStr = (_lastSoldDate ?? _sellDateCtrl.text.trim()).isEmpty ? DateFormat('dd MMM yyyy').format(DateTime.now()) : _lastSoldDate!;

    String _joinParts(List<String> parts) => parts.where((p) => p.trim().isNotEmpty).join(' ').trim();
    final brandModel = _joinParts([brand, device]);
    final modelVariant = _joinParts([device, variant]);

    final buffer = StringBuffer()
      ..writeln('Hello $name,  ')
      ..writeln('Thank you for purchasing the ${brandModel.isEmpty ? device : brandModel} from JollyBaba! 🎉  ')
      ..writeln()
      ..writeln('Your device details:  ')
      ..writeln('📱 Model: ${modelVariant.isEmpty ? device : modelVariant}  ')
      ..writeln('🧾 IMEI: ${imei.isEmpty ? '—' : imei}  ')
      ..writeln('💰 Amount: ₹$amountStr  ')
      ..writeln('🗓️ Date: $sellDateStr  ')
      ..writeln()
      ..writeln('We appreciate your trust. For any support or warranty help, just message us here — we’re always happy to assist! 😊  ')
      ..writeln()
      ..write('– Team JollyBaba ');

    final msg = buffer.toString();

    final encoded = Uri.encodeComponent(msg);
    final digits = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = digits.length == 10 ? '91$digits' : digits;
    final uri = Uri.parse('https://wa.me/$normalized?text=$encoded');

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        _startSellWhatsappCooldown();
        Get.snackbar('WhatsApp', 'WhatsApp message prepared for $name.', snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('WhatsApp', 'Could not open WhatsApp.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('WhatsApp', 'Could not open WhatsApp.', snackPosition: SnackPosition.BOTTOM);
    }
  }
  void _onCustomerNameChanged(String value) {
    _customerDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() => _customerSuggestions = []);
      return;
    }
    _customerDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await InventoryService.searchCustomers(trimmed);
        if (!mounted) return;
        setState(() {
          _customerSuggestions = results;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _customerSuggestions = []);
      }
    });
  }

  void _pickCustomerSuggestion(Map<String, dynamic> suggestion) {
    final name = (suggestion['name'] ?? '').toString();
    final phone = (suggestion['phone'] ?? '').toString();
    final address = (suggestion['address'] ?? '').toString();
    setState(() {
      _sellCustomerCtrl.text = name;
      if (phone.isNotEmpty) {
        _sellMobileCtrl.text = phone;
      }
      if (address.isNotEmpty) {
        _sellAddressCtrl.text = address;
      }
      _customerSuggestions = [];
    });
  }

  Future<void> _openSellDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(ctx).size.width < 700 ? MediaQuery.of(ctx).size.width * 0.96 : 560,
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: _SellPage(
              formKey: _sellFormKey,
              imeiCtrl: _sellImeiCtrl,
              dateCtrl: _sellDateCtrl,
              amountCtrl: _sellAmountCtrl,
              paidCtrl: _sellPaidCtrl,
              customerCtrl: _sellCustomerCtrl,
              mobileCtrl: _sellMobileCtrl,
              addressCtrl: _sellAddressCtrl,
              remarksCtrl: _sellRemarksCtrl,
              onPickDate: () => _pickDate(_sellDateCtrl),
              onSubmit: () async { await _sellFromPage(); Navigator.of(ctx).maybePop(); _resetSellForm(); },
              onLookup: _sellLookupByImei,
              onScanImei: _startImeiScan,
              onSendWhatsapp: () => _sendSellWhatsapp(),
              whatsappEnabled: _sellWhatsappEnabled && !_isSellWhatsappCoolingDown(),
              markSoldEnabled: _canSubmitSell,
              selected: _sellSelected,
              lookupMode: _lookupMode,
              onChangeLookupMode: (v) => setState(() => _lookupMode = v),
              paymentMode: _paymentMode,
              onChangePaymentMode: (v) => setState(() => _paymentMode = v),
              suggestions: _sellTypeahead,
              customerSuggestions: _customerSuggestions,
              onSearchChanged: _onSellQueryChanged,
              onCustomerChanged: _onCustomerNameChanged,
              onPickSuggestion: (m) {
                setState(() {
                  _sellSelected = m;
                  _sellImeiCtrl.text = (m['imei'] ?? '').toString();
                  _sellTypeahead = [];
                  _canSubmitSell = true;
                });
              },
              onPickCustomerSuggestion: _pickCustomerSuggestion,
              onDismissSuggestions: _dismissSellSuggestions,
              step: _sellStep,
              onBack: _sellStep > 0
                  ? () => setState(() {
                        _sellStep--;
                        _canSubmitSell = true;
                      })
                  : null,
              onNext: _sellStep < 1
                  ? () => setState(() {
                        _sellStep++;
                        _canSubmitSell = true;
                      })
                  : null,
              canProceed: _canProceedSellStep(),
            ),
          ),
        );
      },
    );
    _resetSellForm();
  }

  void _startImeiScan({TextEditingController? targetController, bool triggerSellLookup = true}) {
    if (_isScanning) return;
    
    // On web, use WebBarcodeScanner with html5-qrcode
    if (kIsWeb) {
      setState(() => _isScanning = true);
      WebBarcodeScanner.showScanner(
        onSuccess: (String code) {
          final normalized = code.replaceAll(RegExp(r'[^0-9]'), '');
          if (_isValidImeiLength(normalized)) {
            _applyScannedImei(normalized, controller: targetController, triggerSellLookup: triggerSellLookup);
          } else {
            Get.snackbar(
              'IMEI Scan',
              'Detected code is not a valid IMEI (needs 14-16 digits).',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
          if (mounted) setState(() => _isScanning = false);
        },
        onError: (String error) {
          Get.snackbar(
            'Scanner Error',
            error,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent.withOpacity(0.9),
            colorText: Colors.white,
          );
          if (mounted) setState(() => _isScanning = false);
        },
      );
      return;
    }
    
    // Mobile: use MobileScanner
    final detectionHits = <String, int>{};
    var invalidShown = false;
    const defaultHitThreshold = 2;
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.qrCode,
        BarcodeFormat.pdf417,
      ],
    );
    setState(() => _isScanning = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetCtx) {
        final controller = _scannerController!;
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final boxWidth = width * 0.78;
              final boxHeight = height * 0.28;
              final leftPx = (width - boxWidth) / 2;
              final topPx = (height - boxHeight) / 2;
              // Provide scan window in widget coordinates; MobileScanner normalizes internally
              final scanWindow = ui.Rect.fromLTWH(
                leftPx,
                topPx,
                boxWidth,
                boxHeight,
              );
              final overlayRect = ui.Rect.fromLTWH(leftPx, topPx, boxWidth, boxHeight);

              controller.start();

              return Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    fit: BoxFit.cover,
                    scanWindow: scanWindow,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final rawValue = barcode.rawValue?.trim();
                        if (rawValue == null || rawValue.isEmpty) {
                          continue;
                        }
                        final normalized = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
                        if (!_isValidImeiLength(normalized)) {
                          if (!invalidShown) {
                            invalidShown = true;
                            Get.snackbar('IMEI Scan', 'Detected code is not a valid IMEI (needs 14-16 digits).', snackPosition: SnackPosition.BOTTOM);
                          }
                          continue;
                        }
                        if (!_passesImeiChecksumIfPresent(normalized)) {
                          if (!invalidShown) {
                            invalidShown = true;
                            Get.snackbar('IMEI Scan', 'Scanned code failed IMEI checksum. Please rescan.', snackPosition: SnackPosition.BOTTOM);
                          }
                          continue;
                        }
                        final requiredHits = normalized.length == 15 ? 1 : defaultHitThreshold;
                        final hits = (detectionHits[normalized] ?? 0) + 1;
                        detectionHits[normalized] = hits;
                        if (hits >= requiredHits) {
                          Navigator.of(sheetCtx).maybePop();
                          _applyScannedImei(
                            normalized,
                            controller: targetController,
                            triggerSellLookup: triggerSellLookup,
                          );
                          return;
                        }
                      }
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(overlayRect),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(sheetCtx).maybePop(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: math.max(24, height * 0.08), left: 24, right: 24),
                      child: Text(
                        'Align the IMEI barcode within the frame and hold steady for confirmation',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ValueListenableBuilder<TorchState>(
                            valueListenable: controller.torchState,
                            builder: (_, state, __) {
                              final isOn = state == TorchState.on;
                              return IconButton(
                                icon: Icon(isOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                                tooltip: isOn ? 'Turn off flash' : 'Turn on flash',
                                onPressed: () => controller.toggleTorch(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        _scannerController?.stop();
        setState(() => _isScanning = false);
      }
    });
  }

  bool _isValidImeiLength(String normalizedDigits) {
    return normalizedDigits.length >= 14 && normalizedDigits.length <= 16;
  }

  bool _passesImeiChecksumIfPresent(String digits) {
    if (digits.length != 15) {
      return true;
    }
    int sum = 0;
    for (int i = 0; i < 14; i++) {
      int d = int.parse(digits[i]);
      if (i.isOdd) {
        int doubled = d * 2;
        if (doubled > 9) doubled -= 9;
        sum += doubled;
      } else {
        sum += d;
      }
    }
    final expectedCheck = (10 - (sum % 10)) % 10;
    final actualCheck = int.parse(digits[14]);
    return expectedCheck == actualCheck;
  }

  void _applyScannedImei(String value, {TextEditingController? controller, bool triggerSellLookup = true}) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return;
    final targetCtrl = controller ?? _sellImeiCtrl;
    setState(() {
      targetCtrl.text = normalized;
      if (identical(targetCtrl, _sellImeiCtrl)) {
        _lookupMode = 'IMEI';
        _sellSelected = null;
        _sellTypeahead = [];
      }
    });
    _scannerController?.stop();
    if (triggerSellLookup && identical(targetCtrl, _sellImeiCtrl)) {
      _sellLookupByImei();
    }
  }

  @override
  void initState() {
    super.initState();
    _initRoleAndLoad();
  }

  Future<void> _initRoleAndLoad() async {
    try {
      final user = await AuthService().getStoredUser();
      final role = (user?['role'] ?? '').toString().toLowerCase();
      final isTech = role == 'technician' || role == 'tech';
      setState(() {
        _isTechnician = isTech;
        // If caller requested an initial tab, honor it; else technicians land on List by default
        _navIndex = widget.initialIndex ?? (isTech ? 2 : _navIndex);
      });
    } catch (_) {
      // ignore
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await InventoryService.listItems(sort: 'date', order: 'desc', brand: _brandFilter.isEmpty ? null : _brandFilter);
      final items = (resp['items'] as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      final vis = (resp['visibleIndex'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      setState(() {
        _items = items;
        _visibleIndex = vis;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      Get.snackbar('Inventory', 'Failed to load inventory', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _importStockFromFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.single;
      final name = (file.name).toLowerCase();
      final bytes = file.bytes;
      if (bytes == null) {
        Get.snackbar('Import', 'Could not read file bytes', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      List<Map<String, dynamic>> rows = [];
      List<String> headers = [];

      if (name.endsWith('.csv')) {
        final csvStr = utf8.decode(bytes);
        final table = const CsvToListConverter(eol: '\n').convert(csvStr);
        if (table.isEmpty) {
          Get.snackbar('Import', 'CSV is empty', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        headers = table.first.map((e) => e.toString()).toList();
        for (int i = 1; i < table.length; i++) {
          final row = table[i];
          final m = <String, dynamic>{};
          for (int c = 0; c < headers.length && c < row.length; c++) {
            m[headers[c]] = row[c];
          }
          rows.add(m);
        }
      } else {
        final excel = xls.Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) {
          Get.snackbar('Import', 'Excel has no sheets', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        final sheet = excel.tables.values.first!;
        if (sheet.maxRows == 0) {
          Get.snackbar('Import', 'Excel sheet is empty', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        headers = sheet.rows.first.map((c) => (c?.value ?? '').toString()).toList();
        for (int r = 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          final m = <String, dynamic>{};
          for (int c = 0; c < headers.length && c < row.length; c++) {
            m[headers[c]] = row[c]?.value;
          }
          rows.add(m);
        }
      }

      String norm(String s) => s.trim().toLowerCase();
      List<String> h = headers.map((e) => norm(e)).toList();
      Map<String, List<String>> aliases = {
        'purchase date': ['purchase date', 'date', 'buy date'],
        'model name': ['model name', 'model'],
        'imei': ['imei', 'imei1'],
        'brand': ['brand'],
        'variant': ['variant', 'variant gb/color', 'gb/color'],
        'details': ['details', 'description', 'info'],
        'remarks': ['remarks', 'note', 'notes'],
        'vendor': ['vendor', 'vendor name', 'seller'],
        'purchase amount': ['purchase amount', 'amount', 'price', 'cost'],
        'vendor number': ['vendor number', 'vendor no', 'vendor phone', 'phone'],
      };
      Map<String, String> headerMap = {};
      for (final entry in aliases.entries) {
        for (final a in entry.value) {
          final i = h.indexOf(norm(a));
          if (i != -1) {
            headerMap[entry.key] = headers[i];
            break;
          }
        }
      }

      int ok = 0, fail = 0;
      for (final r in rows) {
        try {
          String date = (headerMap['purchase date'] != null ? r[headerMap['purchase date']!] : '')?.toString() ?? '';
          if (date.isNotEmpty) {
            try {
              final d = DateTime.tryParse(date) ?? DateFormat('dd/MM/yyyy').parse(date);
              date = DateFormat('yyyy-MM-dd').format(d);
            } catch (_) {}
          } else {
            date = DateFormat('yyyy-MM-dd').format(DateTime.now());
          }
          final model = (headerMap['model name'] != null ? r[headerMap['model name']!] : '')?.toString() ?? '';
          final imei = (headerMap['imei'] != null ? r[headerMap['imei']!] : '')?.toString() ?? '';
          final brand = ((headerMap['brand'] != null ? r[headerMap['brand']!] : '')?.toString() ?? '').trim();
          final variant = (headerMap['variant'] != null ? r[headerMap['variant']!] : '')?.toString() ?? '';
          final details = (headerMap['details'] != null ? r[headerMap['details']!] : '')?.toString() ?? '';
          final remarks = (headerMap['remarks'] != null ? r[headerMap['remarks']!] : '')?.toString() ?? '';
          final vendor = (headerMap['vendor'] != null ? r[headerMap['vendor']!] : '')?.toString() ?? '';
          final vendorNo = (headerMap['vendor number'] != null ? r[headerMap['vendor number']!] : '')?.toString() ?? '';
          final purchaseStr = (headerMap['purchase amount'] != null ? r[headerMap['purchase amount']!] : '')?.toString() ?? '';
          final parsed = double.tryParse(purchaseStr.replaceAll(',', '').trim()) ?? 0.0;
          final amount = _isTechnician ? 0.0 : parsed;

          if (model.isEmpty || imei.isEmpty) {
            fail++;
            continue;
          }

          final payload = {
            'date': date,
            'brand': brand.isEmpty ? '-' : brand,
            'model': model,
            'imei': imei,
            'variantGbColor': variant,
            'vendorPurchase': vendor,
            'purchaseAmount': amount,
            'remarks': [
              if (details.isNotEmpty) 'Details: $details',
              if (vendorNo.isNotEmpty) 'Vendor No: $vendorNo',
              if (remarks.isNotEmpty) remarks,
            ].join(' | '),
          };

          final rCreate = await InventoryService.createItem(payload);
          if (rCreate['success'] == true) {
            ok++;
          } else {
            fail++;
          }
        } catch (_) {
          fail++;
        }
      }

      await _load();
      Get.snackbar('Import finished', 'Imported: $ok  Failed: $fail', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
    } catch (e) {
      Get.snackbar('Import', 'Failed: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _onSellQueryChanged(String _) {
    _sellDebounce?.cancel();
    _sellDebounce = Timer(const Duration(milliseconds: 250), () async {
      final q = _sellImeiCtrl.text.trim();
      if (q.isEmpty) {
        setState(() => _sellTypeahead = []);
        return;
      }
      try {
        if (_lookupMode == 'SR') {
          final resp = await InventoryService.listItems(status: 'AVAILABLE');
          final list = (resp['items'] as List? ?? [])
              .cast<Map>()
              .map((e) => e.cast<String, dynamic>())
              .where((r) => (r['sr_no']?.toString() ?? '').startsWith(q))
              .take(10)
              .toList();
          setState(() => _sellTypeahead = list);
        } else {
          final resp = await InventoryService.listItems(q: q, status: 'AVAILABLE');
          final list = (resp['items'] as List? ?? [])
              .cast<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(10)
              .toList();
          setState(() => _sellTypeahead = list);
        }
      } catch (_) {
        setState(() => _sellTypeahead = []);
      }
    });
  }

  Future<void> _createStock() async {
    if (!_addFormKey.currentState!.validate()) return;
    try {
      final payload = {
        'date': _dateCtrl.text.trim(),
        'brand': _brandCtrl.text.trim().isEmpty ? '-' : _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'imei': _imeiCtrl.text.trim(),
        'variantGbColor': _variantCtrl.text.trim(),
        'details': _detailsCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        'vendorPurchase': _vendorCtrl.text.trim(),
        'vendorPhone': _vendorPhoneCtrl.text.trim(),
        'purchaseAmount': double.tryParse(_purchaseCtrl.text.trim()) ?? 0,
      };
      final r = await InventoryService.createItem(payload);
      if (r['success'] == true) {
        setState(() {
          _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
          _brandCtrl.clear();
          _modelCtrl.clear();
          _imeiCtrl.clear();
          _variantCtrl.clear();
          _detailsCtrl.clear();
          _remarksCtrl.clear();
          _vendorCtrl.clear();
          _purchaseCtrl.clear();
          _vendorPhoneCtrl.clear();
          _vendorSuggestions = [];
        });
        await _load();
        setState(() => _navIndex = 2);
      } else {
        Get.snackbar('Error', 'Create failed', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Create', 'Failed: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _onVendorChanged(String value) {
    _vendorDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() => _vendorSuggestions = []);
      return;
    }
    _vendorDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await InventoryService.searchVendors(trimmed);
        if (!mounted) return;
        setState(() {
          _vendorSuggestions = results;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _vendorSuggestions = []);
      }
    });
  }

  void _pickVendorSuggestion(Map<String, dynamic> suggestion) {
    final name = (suggestion['name'] ?? '').toString();
    final phone = (suggestion['phone'] ?? '').toString();
    setState(() {
      _vendorCtrl.text = name;
      if (phone.isNotEmpty) {
        _vendorPhoneCtrl.text = phone;
      }
      _vendorSuggestions = [];
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int? _srNoFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _handleQuickSell(Map<String, dynamic> row) async {
    final srNo = _srNoFrom(row['sr_no']);
    if (srNo == null) {
      Get.snackbar('Inventory', 'Invalid SR number', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_quickSellBusy.contains(srNo)) return;

    var confirmed = false;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Mark as Sold?',
        message: 'Are you sure you want to mark this mobile as Sold?',
        icon: Icons.sell_rounded,
        iconColor: Colors.indigo,
        confirmText: 'Yes, Mark as Sold',
        cancelText: 'Cancel',
        onConfirm: () => confirmed = true,
        onCancel: () {},
      ),
    );

    if (!confirmed) return;
    await _performQuickSell(srNo, row);
  }

  Future<void> _performQuickSell(int srNo, Map<String, dynamic> row) async {
    if (_quickSellBusy.contains(srNo)) return;
    setState(() => _quickSellBusy.add(srNo));
    try {
      final now = DateTime.now();
      final sellDate = DateFormat('yyyy-MM-dd').format(now);
      double sellAmount = _toDouble(row['sell_amount']);
      if (sellAmount <= 0) sellAmount = _toDouble(row['purchase_amount']);
      if (sellAmount < 0) sellAmount = 0;

      final existingRemarks = (row['remarks'] ?? '').toString().trim();
      final quickNote = 'Quick sold on ${DateFormat('dd MMM yyyy').format(now)}';
      final remarks = [if (existingRemarks.isNotEmpty) existingRemarks, quickNote]
          .join(existingRemarks.isNotEmpty ? ' | ' : '');

      final payload = {
        'sellDate': sellDate,
        'sellAmount': sellAmount,
        'customerName': (row['customer_name'] ?? '').toString(),
        'mobileNumber': (row['mobile_number'] ?? '').toString(),
        'remarks': remarks,
      };

      final res = await InventoryService.sellItem(srNo, payload);
      if (res['success'] == true) {
        await _load();
        Get.snackbar('Inventory', 'Mobile marked as Sold ✅', snackPosition: SnackPosition.BOTTOM);
      } else {
        throw Exception('SELL_FAILED');
      }
    } catch (e) {
      debugPrint('Quick sell failed: $e');
      Get.snackbar('Inventory', 'Failed to mark as sold', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _quickSellBusy.remove(srNo));
    }
  }

  Future<void> _handleMakeAvailable(Map<String, dynamic> row) async {
    final srNo = _srNoFrom(row['sr_no']);
    if (srNo == null) {
      Get.snackbar('Inventory', 'Invalid SR number', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_makeAvailableBusy.contains(srNo)) return;

    final customer = (row['customer_name'] ?? '').toString().trim();
    final phone = (row['mobile_number'] ?? '').toString().trim();
    final sellDate = (row['sell_date'] ?? '').toString().trim();
    final sellAmount = _toDouble(row['sell_amount']);
    final remarks = (row['remarks'] ?? '').toString().trim();

    final details = <String>[
      if (customer.isNotEmpty) 'Customer: $customer',
      if (phone.isNotEmpty) 'Mobile: $phone',
      if (sellDate.isNotEmpty) 'Sold on: $sellDate',
      if (sellAmount > 0) 'Sale Amount: ₹${sellAmount.toStringAsFixed(2)}',
      if (remarks.isNotEmpty) 'Remarks: $remarks',
    ].join('\n');

    var confirmed = false;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Make Available again?',
        message: [
          if (details.isNotEmpty) details,
          'This will delete the KhataBook entry and mark the mobile AVAILABLE.',
          'Continue?',
        ].join('\n\n'),
        icon: Icons.undo_rounded,
        iconColor: Colors.indigo,
        confirmText: 'Yes, make available',
        cancelText: 'Keep Sold',
        onConfirm: () => confirmed = true,
        onCancel: () {},
      ),
    );

    if (!confirmed) return;
    await _performMakeAvailable(srNo);
  }

  Future<void> _performMakeAvailable(int srNo) async {
    if (_makeAvailableBusy.contains(srNo)) return;
    setState(() => _makeAvailableBusy.add(srNo));
    try {
      final res = await InventoryService.makeAvailable(srNo);
      if (res['success'] == true) {
        await _load();
        Get.snackbar('Inventory', 'Mobile marked as AVAILABLE again ✅', snackPosition: SnackPosition.BOTTOM);
      } else {
        throw Exception('MAKE_AVAILABLE_FAILED');
      }
    } catch (e) {
      debugPrint('Make available failed: $e');
      Get.snackbar('Inventory', 'Failed to mark as available', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _makeAvailableBusy.remove(srNo));
    }
  }

  Future<void> _sellFromPage() async {
    if (!_sellFormKey.currentState!.validate()) return;
    try {
      // Use selected if present, otherwise try lookup now
      Map<String, dynamic>? row = _sellSelected;
      if (row == null) {
        final imei = _sellImeiCtrl.text.trim();
        final resp = await InventoryService.listItems(q: imei, status: 'AVAILABLE');
        final list = (resp['items'] as List? ?? []);
        if (list.isEmpty) {
          Get.snackbar('Sell', 'No AVAILABLE item found for this IMEI', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        row = (list.first as Map).cast<String, dynamic>();
      }
      final srNo = row['sr_no'] as int;
      final totalAmt = double.tryParse(_sellAmountCtrl.text.trim()) ?? 0;
      final paidAmt = double.tryParse(_sellPaidCtrl.text.trim()) ?? 0;
      final remaining = (totalAmt - paidAmt).clamp(0, double.infinity);
      final payload = {
        'sellDate': _sellDateCtrl.text.trim(),
        'sellAmount': totalAmt,
        'customerName': _sellCustomerCtrl.text.trim(),
        'mobileNumber': _sellMobileCtrl.text.trim(),
        'customerAddress': _sellAddressCtrl.text.trim(),
        'remarks': [
          if (_sellRemarksCtrl.text.trim().isNotEmpty) _sellRemarksCtrl.text.trim(),
          if (paidAmt > 0) 'Paid: ₹${paidAmt.toStringAsFixed(2)} (${_paymentMode})',
          if (totalAmt > 0) 'Remaining: ₹${remaining.toStringAsFixed(2)}',
        ].join(' | '),
      };
      final r = await InventoryService.sellItem(srNo, payload);
      if (r['success'] == true) {
        Get.snackbar('Success', 'Marked as SOLD', snackPosition: SnackPosition.BOTTOM);
        final soldCustomer = payload['customerName'];
        final soldPhone = payload['mobileNumber'];
        final soldModel = (row['model'] ?? '').toString();
        final soldBrand = (row['brand'] ?? '').toString();
        final soldVariant = (row['variant_gb_color'] ?? '').toString();
        final soldImei = (row['imei'] ?? '').toString();
        await _load();
        setState(() {
          _sellWhatsappEnabled = true;
          final customerStr = (soldCustomer ?? '').toString().trim();
          final phoneStr = (soldPhone ?? '').toString().trim();
          _lastSoldCustomer = customerStr.isEmpty ? null : customerStr;
          _lastSoldPhone = phoneStr.isEmpty ? null : phoneStr;
          _lastSoldModel = soldModel;
          _lastSoldBrand = soldBrand;
          _lastSoldVariant = soldVariant;
          _lastSoldImei = soldImei.isEmpty ? null : soldImei;
          _lastSoldAmount = totalAmt > 0 ? totalAmt : null;
          _lastSoldDate = payload['sellDate']?.toString().isNotEmpty == true
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(payload['sellDate'].toString()))
              : DateFormat('dd MMM yyyy').format(DateTime.now());
          _clearSellInputsPostSuccess();
        });
        _paymentMode = 'CASH';
      } else {
        Get.snackbar('Error', 'Sell failed', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Sell failed', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _sellLookupByImei() async {
    final query = _sellImeiCtrl.text.trim();
    if (query.isEmpty) {
      Get.snackbar('Sell', 'Enter a value to lookup', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      if (_lookupMode == 'IMEI' || _lookupMode == 'MODEL') {
        final resp = await InventoryService.listItems(q: query, status: 'AVAILABLE');
        final list = (resp['items'] as List? ?? []);
        if (list.isEmpty) {
          setState(() => _sellSelected = null);
          Get.snackbar('Sell', 'No AVAILABLE item found', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        if (list.length == 1) {
          final m = (list.first as Map).cast<String, dynamic>();
          setState(() {
            _sellSelected = m;
            _sellImeiCtrl.text = (m['imei'] ?? '').toString();
          });
        } else {
          final picked = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            builder: (ctx) {
              final results = list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
              return SafeArea(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return ListTile(
                      title: Text('${r['model'] ?? ''} • ${r['variant_gb_color'] ?? ''}'),
                      subtitle: Text('SR: ${r['sr_no']} • IMEI: ${r['imei']}'),
                      onTap: () => Navigator.pop(ctx, r),
                    );
                  },
                ),
              );
            },
          );
          if (picked != null) {
            setState(() {
              _sellSelected = picked;
              _sellImeiCtrl.text = (picked['imei'] ?? '').toString();
            });
          }
        }
      } else if (_lookupMode == 'SR') {
        final sr = int.tryParse(query);
        if (sr == null) {
          Get.snackbar('Sell', 'Enter numeric SR No.', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        final resp = await InventoryService.listItems(status: 'AVAILABLE');
        final list = (resp['items'] as List? ?? []);
        final found = list.cast<Map>().map((e)=> e.cast<String,dynamic>()).firstWhere(
          (r) => (r['sr_no'] is int ? r['sr_no'] : int.tryParse(r['sr_no']?.toString() ?? '')) == sr,
          orElse: () => {},
        );
        if (found.isEmpty) {
          setState(() => _sellSelected = null);
          Get.snackbar('Sell', 'SR No. not found', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        setState(() {
          _sellSelected = found;
          _sellImeiCtrl.text = (found['imei'] ?? '').toString();
        });
      }
    } catch (_) {
      Get.snackbar('Sell', 'Lookup failed', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _editRemarks(int srNo, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Remarks'),
        content: TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Remarks')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (text == null) return;
    try {
      await InventoryService.updateRemarks(srNo, text);
      await _load();
    } catch (_) {
      Get.snackbar('Error', 'Failed to update remarks', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _pickDate(TextEditingController target) async {
    final now = DateTime.now();
    final initial = _tryParseDate(target.text) ?? now;
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(now.year + 2), initialDate: initial);
    if (picked != null) target.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  DateTime? _tryParseDate(String s) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool showRail = width >= 900;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: showRail ? null : _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          // Refresh button (mobile only, on List page)
          if (!showRail && _navIndex == 2)
            IconButton(
              tooltip: 'Refresh',
              icon: _loading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _load,
            ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final uri = InventoryService.exportCsvUrl();
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                Get.snackbar('Export', 'Could not open CSV link', snackPosition: SnackPosition.BOTTOM);
              }
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Get.back(),
        ),
      ),
      body: Row(
        children: [
          if (showRail)
            InventorySidebar(
              selectedIndex: _navIndex,
              onItemSelected: (index) {
                if (_navIndex == 1 && index != 1) _resetSellForm();
                setState(() => _navIndex = index);
              },
              showReports: !_isTechnician,
              isCollapsed: _sidebarCollapsed,
              onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildPage(_navIndex),
            ),
          ),
        ],
      ),
      // Premium pill navigation bar
      bottomNavigationBar: showRail ? null : PillNavBar(
        selectedIndex: _navIndex - 1, // Convert 1-based to 0-based index
        onItemSelected: (index) {
          final newIndex = index + 1; // Convert back to 1-based
          if (_navIndex == 1 && newIndex != 1) _resetSellForm();
          setState(() => _navIndex = newIndex);
        },
        items: [
          const PillNavItem(icon: Icons.sell_rounded, label: 'Sell'),
          const PillNavItem(icon: Icons.table_rows_rounded, label: 'List'),
          const PillNavItem(icon: Icons.add_box_rounded, label: 'Add'),
          if (!_isTechnician)
            const PillNavItem(icon: Icons.insights_rounded, label: 'Reports'),
        ],
      ),
    );
  }


  Future<void> _showItemInfo(Map<String, dynamic> row) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final status = (row['status'] ?? '').toString();
        final isSold = status == 'SOLD';
        final total = (row['sell_amount'] is num) ? (row['sell_amount'] as num).toDouble() : double.tryParse(row['sell_amount']?.toString() ?? '') ?? 0.0;
        final available = status == 'AVAILABLE';
        final statusBg = available ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
        final statusFg = available ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
        final purchase = (row['purchase_amount'] is num) ? (row['purchase_amount'] as num).toDouble() : double.tryParse(row['purchase_amount']?.toString() ?? '') ?? 0.0;
        final remarksText = (row['remarks'] ?? '').toString();
        final paidMatch = RegExp(r'Paid:\s*₹?([0-9]+(?:\.[0-9]+)?)').firstMatch(remarksText);
        final paid = paidMatch != null ? double.tryParse(paidMatch.group(1)!) ?? 0.0 : 0.0;
        final remaining = (total - paid).clamp(0, double.infinity);
        final profit = (isSold ? (total - purchase) : 0.0);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.indigo.shade500, Colors.deepPurple.shade400]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.smartphone),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(row['model'] ?? '').toString()} • ${(row['variant_gb_color'] ?? '').toString()}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text('SR: ${row['sr_no']} • IMEI: ${(row['imei'] ?? '').toString()}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white.withOpacity(0.9))),
                            ],
                          ),
                        ),
                        _StatusPill(text: status, bg: Colors.white.withOpacity(0.2), fg: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Amount badges
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (!_isTechnician)
                      _AmountBadge(label: 'Purchase', value: '₹${purchase.toStringAsFixed(2)}', bg: const Color(0xFFEFF3FF), fg: const Color(0xFF3A4ED5), icon: Icons.shopping_bag),
                    if (isSold)
                      _AmountBadge(label: 'Sell', value: '₹${total.toStringAsFixed(2)}', bg: const Color(0xFFE8F5E9), fg: const Color(0xFF2E7D32), icon: Icons.sell_rounded),
                    if (isSold && !_isTechnician)
                      _AmountBadge(label: 'Profit', value: '₹${profit.toStringAsFixed(2)}', bg: const Color(0xFFFFF3E0), fg: const Color(0xFFEF6C00), icon: Icons.trending_up),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ChipTile(label: 'Date', value: (row['date'] ?? '').toString(), icon: Icons.event)),
                      const SizedBox(width: 10),
                      Expanded(child: _ChipTile(label: 'Vendor', value: (row['vendor_purchase'] ?? '').toString(), icon: Icons.store)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ChipTile(label: 'Brand', value: (row['brand'] ?? '-').toString(), icon: Icons.business_center)),
                      if ((row['variant_gb_color'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _ChipTile(label: 'Variant', value: (row['variant_gb_color'] ?? '').toString(), icon: Icons.category_outlined)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isTechnician)
                    Row(children: [
                      Expanded(child: _ChipTile(label: 'Purchase', value: ((row['purchase_amount'] is num) ? (row['purchase_amount'] as num).toDouble() : 0.0).toString(), icon: Icons.payments_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: _ChipTile(label: 'Details', value: (row['details'] ?? '-').toString(), icon: Icons.info_outline)),
                    ])
                  else
                    Row(children: [
                      Expanded(child: _ChipTile(label: 'Details', value: (row['details'] ?? '-').toString(), icon: Icons.info_outline)),
                    ]),
                  const SizedBox(height: 12),
                  if (!_isTechnician)
                    _readOnlyTile('Remarks', (row['remarks'] ?? '').toString()),
                  if (isSold) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _ChipTile(label: 'Customer', value: (row['customer_name'] ?? '').toString(), icon: Icons.person_outline)),
                      const SizedBox(width: 10),
                      Expanded(child: _ChipTile(label: 'Mobile', value: (row['mobile_number'] ?? '').toString(), icon: Icons.phone_iphone)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _ChipTile(label: 'Sell Date', value: (row['sell_date'] ?? '').toString(), icon: Icons.today)),
                      const SizedBox(width: 10),
                      Expanded(child: _ChipTile(label: 'Sell Amount', value: total.toStringAsFixed(2), icon: Icons.attach_money)),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () { Clipboard.setData(ClipboardData(text: (row['imei'] ?? '').toString())); Get.snackbar('Copied', 'IMEI copied', snackPosition: SnackPosition.BOTTOM); },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy IMEI'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () { Clipboard.setData(ClipboardData(text: (row['sr_no'] ?? '').toString())); Get.snackbar('Copied', 'SR number copied', snackPosition: SnackPosition.BOTTOM); },
                        icon: const Icon(Icons.numbers),
                        label: const Text('Copy SR'),
                      ),
                      if ((row['mobile_number'] ?? '').toString().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () async { final tel = Uri.parse('tel:${(row['mobile_number'] ?? '').toString()}'); try { await launchUrl(tel); } catch (_) {} },
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      if (!_isTechnician)
                        FilledButton.icon(onPressed: () { Navigator.of(ctx).pop(); _openEditSheet(row); }, icon: const Icon(Icons.edit), label: const Text('Edit')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditSheet(Map<String, dynamic> row) async {
    final srNo = row['sr_no'] is int ? row['sr_no'] as int : int.tryParse(row['sr_no']?.toString() ?? '');
    if (srNo == null) return;
    final dateCtrl = TextEditingController(text: (row['date'] ?? '').toString());
    final brandCtrl = TextEditingController(text: (row['brand'] ?? '-').toString());
    final modelCtrl = TextEditingController(text: (row['model'] ?? '').toString());
    final imeiCtrl = TextEditingController(text: (row['imei'] ?? '').toString());
    final variantCtrl = TextEditingController(text: (row['variant_gb_color'] ?? '').toString());
    final vendorCtrl = TextEditingController(text: (row['vendor_purchase'] ?? '').toString());
    final purchaseCtrl = TextEditingController(text: (row['purchase_amount'] is num) ? (row['purchase_amount']).toString() : (row['purchase_amount']?.toString() ?? ''));
    final remarksCtrl = TextEditingController(text: (row['remarks'] ?? '').toString());
    final customerCtrl = TextEditingController(text: (row['customer_name'] ?? '').toString());
    final mobileCtrl = TextEditingController(text: (row['mobile_number'] ?? '').toString());
    final sellDateCtrl = TextEditingController(text: (row['sell_date'] ?? '').toString());
    final sellAmtCtrl = TextEditingController(text: (row['sell_amount'] is num) ? (row['sell_amount']).toString() : (row['sell_amount']?.toString() ?? ''));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final isSold = (row['status'] ?? '') == 'SOLD';
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottom + 12),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit Item • SR: $srNo', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 8),
                Row(children: [ Expanded(child: _field('Date', dateCtrl, readOnly: true, onTap: () => _pickDate(dateCtrl))), const SizedBox(width: 10), Expanded(child: _field('Brand', brandCtrl)), ]),
                Row(children: [ Expanded(child: _field('Model', modelCtrl)), const SizedBox(width: 10), Expanded(child: _field('IMEI', imeiCtrl)), ]),
                Row(children: [ Expanded(child: _field('Variant', variantCtrl)), const SizedBox(width: 10), Expanded(child: _field('Vendor', vendorCtrl)), ]),
                Row(children: [ Expanded(child: _field('Purchase Amount', purchaseCtrl, keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field('Remarks', remarksCtrl)), ]),
                if (isSold) ...[
                  const SizedBox(height: 6),
                  Row(children: [ Expanded(child: _field('Customer Name', customerCtrl)), const SizedBox(width: 10), Expanded(child: _field('Mobile Number', mobileCtrl, keyboardType: TextInputType.phone)), ]),
                  Row(children: [ Expanded(child: _field('Sell Date', sellDateCtrl, readOnly: true, onTap: () => _pickDate(sellDateCtrl))), const SizedBox(width: 10), Expanded(child: _field('Sell Amount', sellAmtCtrl, keyboardType: TextInputType.number)), ]),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    onPressed: () async {
                      final fields = <String, dynamic>{};
                      String s(dynamic v) => (v ?? '').toString();
                      double? d(dynamic v) => double.tryParse((v ?? '').toString());
                      if (s(dateCtrl.text) != s(row['date'])) fields['date'] = dateCtrl.text.trim();
                      if (s(brandCtrl.text) != s(row['brand'])) fields['brand'] = brandCtrl.text.trim();
                      if (s(modelCtrl.text) != s(row['model'])) fields['model'] = modelCtrl.text.trim();
                      if (s(imeiCtrl.text) != s(row['imei'])) fields['imei'] = imeiCtrl.text.trim();
                      if (s(variantCtrl.text) != s(row['variant_gb_color'])) fields['variantGbColor'] = variantCtrl.text.trim();
                      if (s(vendorCtrl.text) != s(row['vendor_purchase'])) fields['vendorPurchase'] = vendorCtrl.text.trim();
                      final purchNew = d(purchaseCtrl.text);
                      final purchOld = (row['purchase_amount'] is num) ? (row['purchase_amount'] as num).toDouble() : double.tryParse(s(row['purchase_amount']));
                      if (purchNew != null && purchNew != purchOld) fields['purchaseAmount'] = purchNew;
                      if (s(remarksCtrl.text) != s(row['remarks'])) fields['remarks'] = remarksCtrl.text.trim();
                      if (isSold) {
                        if (s(customerCtrl.text) != s(row['customer_name'])) fields['customerName'] = customerCtrl.text.trim();
                        if (s(mobileCtrl.text) != s(row['mobile_number'])) fields['mobileNumber'] = mobileCtrl.text.trim();
                        if (s(sellDateCtrl.text) != s(row['sell_date'])) fields['sellDate'] = sellDateCtrl.text.trim();
                        final sellNew = d(sellAmtCtrl.text);
                        final sellOld = (row['sell_amount'] is num) ? (row['sell_amount'] as num).toDouble() : double.tryParse(s(row['sell_amount']));
                        if (sellNew != null && sellNew != sellOld) fields['sellAmount'] = sellNew;
                      }
                      if (fields.isEmpty) { Get.snackbar('Edit', 'No changes to save', snackPosition: SnackPosition.BOTTOM); return; }
                      try {
                        final res = await InventoryService.updateItem(srNo, fields);
                        if (res['success'] == true) {
                          Get.snackbar('Edit', 'Saved', snackPosition: SnackPosition.BOTTOM);
                          await _load();
                          if (mounted) setState(() {});
                          Navigator.pop(ctx);
                        } else {
                          Get.snackbar('Edit', 'Update failed', snackPosition: SnackPosition.BOTTOM);
                        }
                      } catch (e) {
                        Get.snackbar('Edit', 'Error saving changes: ${e.toString()}', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
                      }
                    },
                  ),
                )
                ,
                const SizedBox(height: 10),
                if (isSold)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(220, 44),
                      ),
                      label: const Text('Send WhatsApp Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        final name = (customerCtrl.text.trim().isEmpty ? (row['customer_name']?.toString() ?? '') : customerCtrl.text.trim());
                        final phone = (mobileCtrl.text.trim().isEmpty ? (row['mobile_number']?.toString() ?? '') : mobileCtrl.text.trim());
                        final model = (row['model']?.toString() ?? '');
                        _sendSellWhatsapp(
                          phone: phone,
                          customer: name.isEmpty ? 'there' : name,
                          model: model.isEmpty ? 'your device' : model,
                        );
                      },
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 1:
        return _SellPage(
          formKey: _sellFormKey,
          imeiCtrl: _sellImeiCtrl,
          dateCtrl: _sellDateCtrl,
          amountCtrl: _sellAmountCtrl,
          paidCtrl: _sellPaidCtrl,
          customerCtrl: _sellCustomerCtrl,
          mobileCtrl: _sellMobileCtrl,
          addressCtrl: _sellAddressCtrl,
          remarksCtrl: _sellRemarksCtrl,
          onPickDate: () => _pickDate(_sellDateCtrl),
          onSubmit: _sellFromPage,
          onLookup: _sellLookupByImei,
          onScanImei: _startImeiScan,
          onSendWhatsapp: () => _sendSellWhatsapp(),
          whatsappEnabled: _sellWhatsappEnabled && !_isSellWhatsappCoolingDown(),
          markSoldEnabled: _canSubmitSell,
          selected: _sellSelected,
          lookupMode: _lookupMode,
          onChangeLookupMode: (v) => setState(() => _lookupMode = v),
          paymentMode: _paymentMode,
          onChangePaymentMode: (v) => setState(() => _paymentMode = v),
          suggestions: _sellTypeahead,
          customerSuggestions: _customerSuggestions,
          onSearchChanged: _onSellQueryChanged,
          onCustomerChanged: _onCustomerNameChanged,
          onPickSuggestion: (m) {
            setState(() {
              _sellSelected = m;
              _sellImeiCtrl.text = (m['imei'] ?? '').toString();
              _sellTypeahead = [];
              _canSubmitSell = true;
            });
          },
          onPickCustomerSuggestion: _pickCustomerSuggestion,
          onDismissSuggestions: _dismissSellSuggestions,
          step: _sellStep,
          onBack: _sellStep > 0
              ? () => setState(() {
                    _sellStep--;
                  })
              : null,
          onNext: _sellStep < 1
              ? () => setState(() {
                    _sellStep++;
                    _canSubmitSell = true;
                  })
              : null,
          canProceed: _canProceedSellStep(),
        );
      case 2:
        // Apply client-side filtering by availability status, then search query
        final q = _listQuery.toLowerCase();
        final status = _statusFilter;
        final filteredByStatus = status == 'ALL'
            ? _items
            : _items.where((e) => (e['status'] ?? '').toString().toUpperCase() == status).toList();
        final filtered = q.isEmpty
            ? filteredByStatus
            : filteredByStatus.where((e) {
                String s(dynamic v) => (v ?? '').toString().toLowerCase();
                return s(e['model']).contains(q) || s(e['imei']).contains(q) || s(e['variant_gb_color']).contains(q) || s(e['customer_name']).contains(q);
              }).toList();
        
        // Apply sorting
        final sorted = List<Map<String, dynamic>>.from(filtered);
        sorted.sort((a, b) {
          dynamic aVal, bVal;
          switch (_sortField) {
            case 'model':
              aVal = (a['model'] ?? '').toString().toLowerCase();
              bVal = (b['model'] ?? '').toString().toLowerCase();
              break;
            case 'date':
              aVal = a['date']?.toString() ?? '';
              bVal = b['date']?.toString() ?? '';
              break;
            case 'status':
              aVal = (a['status'] ?? '').toString();
              bVal = (b['status'] ?? '').toString();
              break;
            default: // sr_no
              aVal = a['sr_no'] is int ? a['sr_no'] : int.tryParse(a['sr_no']?.toString() ?? '0') ?? 0;
              bVal = b['sr_no'] is int ? b['sr_no'] : int.tryParse(b['sr_no']?.toString() ?? '0') ?? 0;
          }
          final cmp = Comparable.compare(aVal as Comparable, bVal as Comparable);
          return _sortAscending ? cmp : -cmp;
        });
        
        return _ListPage(
          loading: _loading,
          items: sorted,
          allItems: _items,
          visibleIndex: _visibleIndex,
          onSellQuick: (row) => _handleQuickSell(row),
          onMakeAvailable: (row) => _handleMakeAvailable(row),
          onEditRemarks: (srNo, initial) => _editRemarks(srNo, initial),
          onOpenInfo: (row) => _showItemInfo(row),
          onEditItem: (row) => _openEditSheet(row),
          searchCtrl: _listSearchCtrl,
          onSearchChanged: _onListQueryChanged,
          isTechnician: _isTechnician,
          quickSellBusy: _quickSellBusy,
          makeAvailableBusy: _makeAvailableBusy,
          statusFilter: _statusFilter,
          onStatusFilterChanged: (value) => setState(() => _statusFilter = value),
          sortField: _sortField,
          sortAscending: _sortAscending,
          onSortChanged: (field) {
            setState(() {
              if (_sortField == field) {
                _sortAscending = !_sortAscending;
              } else {
                _sortField = field;
                _sortAscending = true;
              }
            });
          },
          onRefresh: _load,
        );
      case 3:
        return _AddStockPage(
          formKey: _addFormKey,
          dateCtrl: _dateCtrl,
          brandCtrl: _brandCtrl,
          modelCtrl: _modelCtrl,
          imeiCtrl: _imeiCtrl,
          variantCtrl: _variantCtrl,
          detailsCtrl: _detailsCtrl,
          vendorCtrl: _vendorCtrl,
          purchaseCtrl: _purchaseCtrl,
          remarksCtrl: _remarksCtrl,
          vendorPhoneCtrl: _vendorPhoneCtrl,
          onPickDate: () => _pickDate(_dateCtrl),
          onSubmit: _createStock,
          onImport: _importStockFromFile,
          onScanImei: () => _startImeiScan(targetController: _imeiCtrl, triggerSellLookup: false),
          showPurchaseField: !_isTechnician,
          vendorSuggestions: _vendorSuggestions,
          onVendorChanged: _onVendorChanged,
          onPickVendorSuggestion: _pickVendorSuggestion,
          onDismissVendorSuggestions: _dismissVendorSuggestions,
        );
      case 4:
        return _ReportsPage(
          period: _reportPeriod,
          year: _reportYear,
          month: _reportMonth,
          day: _reportDay,
          onPeriodChanged: (v) => setState(() {
                _reportPeriod = v;
                _reportDay = _clampReportDay(_reportYear, _reportMonth, _reportDay);
              }),
          onYearChanged: (v) => setState(() {
                _reportYear = v;
                _reportDay = _clampReportDay(_reportYear, _reportMonth, _reportDay);
              }),
          onMonthChanged: (v) => setState(() {
                _reportMonth = v;
                _reportDay = _clampReportDay(_reportYear, _reportMonth, _reportDay);
              }),
          onDayChanged: (v) => setState(() {
                _reportDay = _clampReportDay(_reportYear, _reportMonth, v);
              }),
          items: _items,
          onExportRange: (from, to) async {
            final base = InventoryService.exportCsvUrl();
            final uri = base.replace(queryParameters: {
              ...base.queryParameters,
              'from': DateFormat('yyyy-MM-dd').format(from),
              'to': DateFormat('yyyy-MM-dd').format(to),
            });
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              Get.snackbar('Export', 'Could not open export link', snackPosition: SnackPosition.BOTTOM);
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium header with gradient
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6D5DF6), const Color(0xFF6D5DF6).withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D5DF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Stock Management',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Nav items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _drawerItem(Icons.sell_rounded, 'Sell', 1, 'Record a sale'),
                    const SizedBox(height: 6),
                    _drawerItem(Icons.table_rows_rounded, 'List', 2, 'View all items'),
                    const SizedBox(height: 6),
                    _drawerItem(Icons.add_box_rounded, 'Add Stock', 3, 'Add new item'),
                    if (!_isTechnician) ...[
                      const SizedBox(height: 6),
                      _drawerItem(Icons.insights_rounded, 'Reports', 4, 'Analytics'),
                    ],
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Footer
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      'JollyBaba v1.0.0',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, int index, String subtitle) {
    final selected = _navIndex == index;
    return Material(
      color: selected ? const Color(0xFF6D5DF6).withOpacity(0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          setState(() => _navIndex = index);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFF6D5DF6).withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6D5DF6).withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? const Color(0xFF6D5DF6) : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? const Color(0xFF6D5DF6) : Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF6D5DF6),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _PageWrapper({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomInset + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6D5DF6).withOpacity(0.08),
                            const Color(0xFF6D5DF6).withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6D5DF6).withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D5DF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconForTitle(title),
                              color: const Color(0xFF6D5DF6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            title, 
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, 
                              fontSize: isDesktop ? 18 : 16,
                              color: const Color(0xFF1E2343),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04), 
                            blurRadius: 12, 
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'sell': return Icons.sell_rounded;
      case 'inventory list': return Icons.table_rows_rounded;
      case 'add new mobile': return Icons.add_box_rounded;
      case 'reports': return Icons.insights_rounded;
      default: return Icons.settings;
    }
  }
}
