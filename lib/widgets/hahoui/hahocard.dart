import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class HahoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isActive;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? elevation;
  final double? borderRadius;
  
  const HahoCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.isActive = false,
    this.backgroundColor,
    this.onTap,
    this.elevation,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardBorderRadius = borderRadius != null 
        ? BorderRadius.circular(borderRadius!) 
        : AppTheme.defaultBorderRadius;
    
    final card = Card(
      elevation: elevation ?? AppTheme.cardElevation,
      color: backgroundColor ?? AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: cardBorderRadius,
        side: isActive 
            ? BorderSide(color: AppTheme.primaryCoral, width: 1.5) 
            : BorderSide.none,
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: cardBorderRadius,
        child: card,
      );
    }
    
    return card;
  }
} 