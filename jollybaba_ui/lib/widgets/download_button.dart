// lib/widgets/download_button.dart
// Animated download button with progress indicator

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum DownloadState { idle, downloading, success, error }

class AnimatedDownloadButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final Color primaryColor;
  final IconData icon;

  const AnimatedDownloadButton({
    super.key,
    required this.onPressed,
    this.label = 'Download',
    this.primaryColor = const Color(0xFF6D5DF6),
    this.icon = Icons.download_rounded,
  });

  @override
  State<AnimatedDownloadButton> createState() => AnimatedDownloadButtonState();
}

class AnimatedDownloadButtonState extends State<AnimatedDownloadButton>
    with TickerProviderStateMixin {
  DownloadState _state = DownloadState.idle;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  /// Call this to start the download animation
  void startDownload() {
    setState(() => _state = DownloadState.downloading);
    _progressController.forward();
  }

  /// Call this when download completes successfully
  void onSuccess() {
    setState(() => _state = DownloadState.success);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _state = DownloadState.idle);
        _progressController.reset();
      }
    });
  }

  /// Call this when download fails
  void onError() {
    setState(() => _state = DownloadState.error);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _state = DownloadState.idle);
        _progressController.reset();
      }
    });
  }

  void _handleTap() {
    if (_state != DownloadState.idle) return;
    startDownload();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _state == DownloadState.idle ? _handleTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
              horizontal: _state == DownloadState.idle ? 16 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getBorderColor(),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(),
                if (_state == DownloadState.idle) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (_state) {
      case DownloadState.idle:
        return Icon(widget.icon, color: widget.primaryColor, size: 20);
      
      case DownloadState.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  CircularProgressIndicator(
                    value: _progressAnimation.value,
                    strokeWidth: 2.5,
                    backgroundColor: widget.primaryColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(widget.primaryColor),
                  ),
                ],
              );
            },
          ),
        );
      
      case DownloadState.success:
        return Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 20,
        ).animate().scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
          duration: 500.ms,
        );
      
      case DownloadState.error:
        return Icon(
          Icons.error_rounded,
          color: Colors.red,
          size: 20,
        ).animate().shake(duration: 500.ms);
    }
  }

  Color _getBackgroundColor() {
    switch (_state) {
      case DownloadState.idle:
        return widget.primaryColor.withOpacity(0.08);
      case DownloadState.downloading:
        return widget.primaryColor.withOpacity(0.05);
      case DownloadState.success:
        return Colors.green.withOpacity(0.1);
      case DownloadState.error:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getBorderColor() {
    switch (_state) {
      case DownloadState.idle:
        return widget.primaryColor.withOpacity(0.2);
      case DownloadState.downloading:
        return widget.primaryColor.withOpacity(0.3);
      case DownloadState.success:
        return Colors.green.withOpacity(0.3);
      case DownloadState.error:
        return Colors.red.withOpacity(0.3);
    }
  }
}
