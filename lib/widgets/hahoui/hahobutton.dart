import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

enum HahoButtonType {
  primary,
  secondary,
  outline,
  text,
}

class HahoButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final HahoButtonType buttonType;
  final bool isFullWidth;
  final IconData? icon;
  final bool isLoading;
  final bool disabled;

  const HahoButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.buttonType = HahoButtonType.primary,
    this.isFullWidth = false,
    this.icon,
    this.isLoading = false,
    this.disabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final innerChild = _buildButtonContent();

    switch (buttonType) {
      case HahoButtonType.primary:
        return ElevatedButton(
          onPressed: (disabled || isLoading) ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryCoral,
            foregroundColor: AppTheme.white,
            disabledBackgroundColor: AppTheme.primaryCoral.withOpacity(0.5),
            disabledForegroundColor: AppTheme.white.withOpacity(0.7),
            minimumSize: isFullWidth 
                ? const Size(double.infinity, 56) 
                : const Size(120, 56),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonBorderRadius,
            ),
          ),
          child: innerChild,
        );
      
      case HahoButtonType.secondary:
        return ElevatedButton(
          onPressed: (disabled || isLoading) ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.softGreen,
            foregroundColor: AppTheme.white,
            disabledBackgroundColor: AppTheme.softGreen.withOpacity(0.5),
            disabledForegroundColor: AppTheme.white.withOpacity(0.7),
            minimumSize: isFullWidth 
                ? const Size(double.infinity, 56) 
                : const Size(120, 56),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonBorderRadius,
            ),
          ),
          child: innerChild,
        );
      
      case HahoButtonType.outline:
        return OutlinedButton(
          onPressed: (disabled || isLoading) ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryCoral,
            side: BorderSide(
              color: disabled 
                  ? AppTheme.primaryCoral.withOpacity(0.5) 
                  : AppTheme.primaryCoral,
              width: 1.5,
            ),
            minimumSize: isFullWidth 
                ? const Size(double.infinity, 56) 
                : const Size(120, 56),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonBorderRadius,
            ),
          ),
          child: innerChild,
        );
      
      case HahoButtonType.text:
        return TextButton(
          onPressed: (disabled || isLoading) ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.softGreen,
            minimumSize: const Size(80, 48),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: innerChild,
        );
    }
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            buttonType == HahoButtonType.outline 
                ? AppTheme.primaryCoral 
                : AppTheme.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
} 