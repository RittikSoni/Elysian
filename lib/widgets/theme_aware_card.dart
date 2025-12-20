import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:elysian/providers/providers.dart';
import 'package:provider/provider.dart';

/// A card widget that automatically applies glass effects in liquid glass mode
/// and regular card styling in other modes
class ThemeAwareCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final double? elevation;
  final Border? border;

  const ThemeAwareCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.elevation,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final isLiquidGlass = appState.themeType == AppThemeType.liquidGlass;
        final theme = Theme.of(context);
        final liquidGlass = theme.extension<LiquidGlassTheme>();

        if (isLiquidGlass) {
          // Apply glass effect
          final blur = liquidGlass?.blurIntensity ?? 15.0;
          final opacity = liquidGlass?.glassOpacity ?? 0.18;
          final borderOpacity = liquidGlass?.borderOpacity ?? 0.25;

          return Container(
            margin: margin,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              border:
                  border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: borderOpacity),
                    width: 1.5,
                  ),
            ),
            child: ClipRRect(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: color ?? Colors.white.withValues(alpha: opacity),
                    borderRadius: borderRadius ?? BorderRadius.circular(20),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        } else {
          // Regular card
          return Card(
            margin: margin ?? EdgeInsets.zero,
            elevation: elevation ?? 2,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              side: border != null
                  ? BorderSide(
                      color: border!.top.color,
                      width: border!.top.width,
                    )
                  : BorderSide.none,
            ),
            color: color ?? theme.cardColor,
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          );
        }
      },
    );
  }
}

/// A container widget that applies glass effects conditionally
class ThemeAwareContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;

  const ThemeAwareContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.width,
    this.height,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final isLiquidGlass = appState.themeType == AppThemeType.liquidGlass;
        final theme = Theme.of(context);
        final liquidGlass = theme.extension<LiquidGlassTheme>();

        if (isLiquidGlass && decoration == null) {
          // Apply glass effect
          final blur = liquidGlass?.blurIntensity ?? 15.0;
          final opacity = liquidGlass?.glassOpacity ?? 0.18;
          final borderOpacity = liquidGlass?.borderOpacity ?? 0.25;

          return Container(
            width: width,
            height: height,
            margin: margin,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderOpacity),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: color ?? Colors.white.withValues(alpha: opacity),
                    borderRadius: borderRadius ?? BorderRadius.circular(20),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        } else {
          // Regular container
          return Container(
            width: width,
            height: height,
            margin: margin,
            padding: padding,
            decoration:
                decoration ??
                BoxDecoration(
                  color: color ?? theme.cardColor,
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
            child: child,
          );
        }
      },
    );
  }
}
