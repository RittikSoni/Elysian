import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ReusableButtonVariant { primary, secondary, outline, text }

/// A reusable button component with multiple visual variants
/// and customizable properties.
///
/// Supports primary, secondary, outline, and text styles.
class ReusableButton extends StatefulWidget {
  const ReusableButton({
    super.key,
    required this.onTap,
    this.label,
    this.variant = ReusableButtonVariant.primary,
    this.leading,
    this.trailing,
    this.disabled = false,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.borderRadius = 20.0,
    this.blurSigma = 10.0,
    this.onTapScale = 0.95,
    this.splashColor,
  });

  /// Button text
  final String? label;

  /// Tap callback
  final VoidCallback onTap;

  /// Visual variant
  final ReusableButtonVariant variant;

  /// Optional widget before the label
  final Widget? leading;

  /// Optional widget after the label
  final Widget? trailing;

  /// Disabled state
  ///
  /// Defaults to `false`.
  final bool disabled;

  /// Show loading spinner
  ///
  /// Defaults to `false`.
  final bool loading;

  /// Hit padding
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 20, vertical: 12)`.
  final EdgeInsetsGeometry padding;

  /// Border Corner radius
  ///
  /// Defaults to `20.0`.
  final double borderRadius;

  /// Backdrop blur sigma
  ///
  /// Defaults to `10.0`.
  final double blurSigma;

  /// Scale factor on press
  ///
  /// Defaults to `0.95`.
  final double onTapScale;

  /// Ripple splash color override
  final Color? splashColor;

  @override
  State<ReusableButton> createState() => _ReusableButtonState();
}

class _ReusableButtonState extends State<ReusableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.disabled || widget.loading;

    List<Color> gradientColors;
    Color borderColor;
    Color textColor;

    switch (widget.variant) {
      case ReusableButtonVariant.primary:
        gradientColors = isDisabled
            ? [
                Colors.grey.shade700.withValues(alpha: 0.4),
                Colors.grey.shade800.withValues(alpha: 0.4),
              ]
            : [
                const Color(0xFF00F5A0).withValues(alpha: 0.25),
                const Color(0xFF00D9F5).withValues(alpha: 0.25),

                const Color(0xFF5D3FD3).withValues(alpha: 0.30),
              ];
        borderColor = Colors.white.withValues(alpha: 0.25);
        textColor = Colors.white;
        break;

      case ReusableButtonVariant.secondary:
        gradientColors = isDisabled
            ? [
                Colors.grey.shade700.withValues(alpha: 0.3),
                Colors.grey.shade800.withValues(alpha: 0.3),
              ]
            : [
                Colors.pinkAccent.withValues(alpha: 0.3),
                const Color(0xFF8E2DE2).withValues(alpha: 0.3),
                const Color(0xFF4A00E0).withValues(alpha: 0.3),
              ];
        borderColor = Colors.white.withValues(alpha: 0.20);
        textColor = Colors.white;
        break;

      case ReusableButtonVariant.outline:
        gradientColors = [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.25),
        ];
        borderColor = Colors.white;
        textColor = Colors.black;
        break;

      case ReusableButtonVariant.text:
        gradientColors = [Colors.transparent, Colors.transparent];
        borderColor = Colors.transparent;
        textColor = Colors.black;
        break;
    }

    // Build the inner content (icon + label or spinner)
    Widget childContent = widget.loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 8),
              ],
              if (widget.label != null)
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              if (widget.trailing != null) ...[
                if (widget.label != null) const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: widget.splashColor,
        highlightColor: Colors.transparent,
        onHighlightChanged: (down) => setState(() => _pressed = down),
        child: Transform.scale(
          scale: _pressed ? widget.onTapScale : 1.0,
          alignment: Alignment.center,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: widget.variant == ReusableButtonVariant.text
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: Center(child: childContent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
