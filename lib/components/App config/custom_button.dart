import 'package:flutter/material.dart';
import '../app_color.dart';

enum ButtonVariant { primary, secondary, outline, danger, ghost }
enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Widget? child;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.child,
  });

  const CustomButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.child,
  }) : variant = ButtonVariant.outline;

  const CustomButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.child,
  }) : variant = ButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final height = _getHeight();
    final textStyle = _getTextStyle(context);
    final padding = _getPadding();

    if (variant == ButtonVariant.outline) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: onPressed == null ? Colors.grey : AppColors.primary,
              width: 1.5,
            ),
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _buildContent(textStyle, AppColors.primary),
        ),
      );
    }

    if (variant == ButtonVariant.ghost) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _buildContent(textStyle, AppColors.primary),
        ),
      );
    }

    final gradient = _getGradient();

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed == null ? null : gradient,
              color: onPressed == null ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              alignment: Alignment.center,
              padding: padding,
              child: _buildContent(
                textStyle,
                onPressed == null ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(TextStyle style, Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == ButtonVariant.outline ? AppColors.primary : Colors.white,
          ),
        ),
      );
    }

    if (child != null) return child!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Text(label, style: style.copyWith(color: color)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: 18, color: color),
        ],
      ],
    );
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.small: return 40;
      case ButtonSize.medium: return 52;
      case ButtonSize.large: return 60;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.small: return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium: return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case ButtonSize.large: return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge!;
    switch (size) {
      case ButtonSize.small: return base.copyWith(fontSize: 13);
      case ButtonSize.medium: return base.copyWith(fontSize: 15);
      case ButtonSize.large: return base.copyWith(fontSize: 16);
    }
  }

  LinearGradient _getGradient() {
    switch (variant) {
      case ButtonVariant.danger:
        return const LinearGradient(
          colors: [Color(0xFFFF6B6B), AppColors.danger],
        );
      case ButtonVariant.secondary:
        return const LinearGradient(
          colors: [AppColors.secondary, Color(0xFF0EB8D8)],
        );
      default:
        return AppColors.primaryGradient;
    }
  }
}