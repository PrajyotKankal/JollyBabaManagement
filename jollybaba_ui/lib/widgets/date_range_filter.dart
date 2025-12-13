// lib/widgets/date_range_filter.dart
// Premium date range filter widget with presets

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum DatePreset { today, week, month, year, custom, all }

class DateRangeFilter extends StatefulWidget {
  final Function(DateTime? start, DateTime? end, DatePreset preset) onChanged;
  final DatePreset initialPreset;
  final Color primaryColor;

  const DateRangeFilter({
    super.key,
    required this.onChanged,
    this.initialPreset = DatePreset.all,
    this.primaryColor = const Color(0xFF6D5DF6),
  });

  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  late DatePreset _selectedPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset;
  }

  void _selectPreset(DatePreset preset) {
    setState(() => _selectedPreset = preset);
    
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case DatePreset.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DatePreset.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = now;
        break;
      case DatePreset.month:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case DatePreset.year:
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      case DatePreset.custom:
        _showDateRangePicker();
        return;
      case DatePreset.all:
        start = null;
        end = null;
        break;
    }

    widget.onChanged(start, end, preset);
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF2A2E45),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _selectedPreset = DatePreset.custom;
      });
      widget.onChanged(picked.start, picked.end, DatePreset.custom);
    }
  }

  String _formatDateRange() {
    if (_customStart == null || _customEnd == null) return 'Custom';
    final format = DateFormat('dd MMM');
    return '${format.format(_customStart!)} - ${format.format(_customEnd!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _presetChip('All', DatePreset.all, Icons.all_inclusive_rounded),
        _presetChip('Today', DatePreset.today, Icons.today_rounded),
        _presetChip('Week', DatePreset.week, Icons.date_range_rounded),
        _presetChip('Month', DatePreset.month, Icons.calendar_month_rounded),
        _presetChip('Year', DatePreset.year, Icons.calendar_today_rounded),
        _customChip(),
      ],
    );
  }

  Widget _presetChip(String label, DatePreset preset, IconData icon) {
    final isSelected = _selectedPreset == preset;
    return InkWell(
      onTap: () => _selectPreset(preset),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customChip() {
    final isSelected = _selectedPreset == DatePreset.custom;
    return InkWell(
      onTap: () => _selectPreset(DatePreset.custom),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_calendar_rounded,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              isSelected && _customStart != null ? _formatDateRange() : 'Custom',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
