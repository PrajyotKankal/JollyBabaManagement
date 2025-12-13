// lib/widgets/shimmer_table.dart
// Premium shimmer loading placeholder for data tables

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShimmerTable extends StatelessWidget {
  final int rowCount;
  final int columnCount;
  final double rowHeight;
  final bool showStats;

  const ShimmerTable({
    super.key,
    this.rowCount = 8,
    this.columnCount = 5,
    this.rowHeight = 44,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats cards shimmer
        if (showStats)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(4, (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _ShimmerStatCard(delay: i * 50),
                ),
              )),
            ),
          ),
        
        // Filter bar shimmer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _shimmerBox(200, 38, 8),
              const SizedBox(width: 12),
              _shimmerBox(120, 38, 8),
              const SizedBox(width: 12),
              _shimmerBox(100, 38, 8),
            ],
          ),
        ),
        
        // Header row shimmer
        Container(
          height: 44,
          color: const Color(0xFFF0F4F8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(columnCount, (i) => Expanded(
              flex: i == 0 ? 1 : 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _shimmerBox(double.infinity, 14, 4),
              ),
            )),
          ),
        ),
        
        // Data rows shimmer
        Expanded(
          child: ListView.builder(
            itemCount: rowCount,
            itemBuilder: (context, index) => _ShimmerRow(
              height: rowHeight,
              columnCount: columnCount,
              delay: index * 30,
              isEven: index.isEven,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _shimmerBox(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: Colors.grey.shade100);
  }
}

class _ShimmerStatCard extends StatelessWidget {
  final int delay;

  const _ShimmerStatCard({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Spacer(),
              Container(
                width: 50,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 80,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 60,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ).animate(delay: delay.ms, onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: Colors.grey.shade100);
  }
}

class _ShimmerRow extends StatelessWidget {
  final double height;
  final int columnCount;
  final int delay;
  final bool isEven;

  const _ShimmerRow({
    required this.height,
    required this.columnCount,
    this.delay = 0,
    this.isEven = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: isEven ? Colors.white : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(columnCount, (i) {
          final widthFactors = [0.4, 0.7, 0.6, 0.5, 0.65];
          final widthFactor = widthFactors[i % widthFactors.length];
          return Expanded(
            flex: i == 0 ? 1 : 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widthFactor,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ).animate(delay: delay.ms, onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: Colors.grey.shade100);
  }
}

/// Simple shimmer for any widget
class ShimmerWidget extends StatelessWidget {
  final Widget child;
  final int delay;

  const ShimmerWidget({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child.animate(delay: delay.ms, onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: Colors.grey.shade100);
  }
}
