import 'dart:ui';

import 'package:flutter/material.dart';

class AppPopupDialog extends StatefulWidget {
  const AppPopupDialog({
    super.key,
    required this.title,
    required this.message,
    required this.allowOptOut,
  });

  final String title;
  final String message;
  final bool allowOptOut;

  @override
  State<AppPopupDialog> createState() => _AppPopupDialogState();
}

class _AppPopupDialogState extends State<AppPopupDialog>
    with SingleTickerProviderStateMixin {
  static const int _visibleLineLimit = 10;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _arrowAnimation;
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _arrowAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _arrowAnimation.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    final atBottom = notification.metrics.extentAfter <= 2;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    const messageStyle = TextStyle(
      color: Color(0xFFC0C9CD),
      fontSize: 14,
      height: 1.55,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 17),
            decoration: BoxDecoration(
              color: const Color(0xE61B252B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.23)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE629363D), Color(0xD9162028)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF4F7F6),
                    fontSize: 19,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textPainter = TextPainter(
                      text: TextSpan(text: widget.message, style: messageStyle),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    );
                    textPainter.layout(maxWidth: constraints.maxWidth);
                    final lineMetrics = textPainter.computeLineMetrics();
                    final hasOverflow = lineMetrics.length > _visibleLineLimit;
                    final lineHeight = hasOverflow
                        ? lineMetrics.first.height
                        : 0.0;
                    textPainter.dispose();

                    if (!hasOverflow) {
                      return Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: messageStyle,
                      );
                    }

                    return SizedBox(
                      height: lineHeight * _visibleLineLimit,
                      child: Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              _onScroll(notification);
                              return false;
                            },
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: messageStyle,
                              ),
                            ),
                          ),
                          if (!_atBottom)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: 28,
                                  alignment: Alignment.bottomCenter,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00182027),
                                        Color(0xEB182027),
                                      ],
                                    ),
                                  ),
                                  child: FadeTransition(
                                    opacity: Tween<double>(
                                      begin: 0.6,
                                      end: 1,
                                    ).animate(_arrowAnimation),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Color(0xFF9BE9CB),
                                      size: 23,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE3E9E9),
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.allowOptOut ? 'Not now' : 'Close'),
                  ),
                ),
                if (widget.allowOptOut) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      "Don't show again on this device",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFB8C6C3), fontSize: 12),
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
}
