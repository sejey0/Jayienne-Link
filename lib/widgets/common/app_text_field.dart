import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Unified romantic text input field matched to the Sign-In / Login styling.
/// Suppresses all inner Flutter Theme borders and provides a single, clean outer container border.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool? isDark;
  final TextStyle? style;
  final TextStyle? hintStyle;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.contentPadding,
    this.isDark,
    this.style,
    this.hintStyle,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _effectiveFocusNode;
  bool _isInternalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _effectiveFocusNode = FocusNode();
      _isInternalFocusNode = true;
    } else {
      _effectiveFocusNode = widget.focusNode!;
    }
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null && _isInternalFocusNode) {
        _effectiveFocusNode.dispose();
      } else {
        oldWidget.focusNode?.removeListener(_handleFocusChange);
      }

      if (widget.focusNode == null) {
        _effectiveFocusNode = FocusNode();
        _isInternalFocusNode = true;
      } else {
        _effectiveFocusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      }
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (_isInternalFocusNode) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null && widget.labelText!.isNotEmpty) ...[
          Text(
            widget.labelText!.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: dark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        FormField<String>(
          validator: widget.validator != null
              ? (_) => widget.validator!(widget.controller?.text)
              : null,
          builder: (FormFieldState<String> state) {
            final hasError = state.hasError;

            Color effectiveBorderColor;
            double effectiveBorderWidth;

            if (hasError) {
              effectiveBorderColor = AppColors.error;
              effectiveBorderWidth = 1.3;
            } else if (_isFocused) {
              effectiveBorderColor = const Color(0xFFFF758C);
              effectiveBorderWidth = 1.4;
            } else {
              effectiveBorderColor = widget.borderColor ??
                  (dark
                      ? const Color(0xFFFF758C).withValues(alpha: 0.3)
                      : const Color(0xFFFF758C).withValues(alpha: 0.25));
              effectiveBorderWidth = 1.2;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ??
                        (dark ? const Color(0xFF1E162B) : Colors.white),
                    borderRadius: effectiveRadius,
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: effectiveBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFocused
                            ? const Color(0xFFFF758C).withValues(alpha: dark ? 0.18 : 0.08)
                            : Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                        blurRadius: _isFocused ? 12 : 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: widget.controller,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onChanged: (val) {
                      if (hasError) state.validate();
                      widget.onChanged?.call(val);
                    },
                    onFieldSubmitted: widget.onFieldSubmitted,
                    enabled: widget.enabled,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    minLines: widget.minLines,
                    autofocus: widget.autofocus,
                    focusNode: _effectiveFocusNode,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: widget.inputFormatters,
                    style: widget.style ??
                        TextStyle(
                          color: dark ? Colors.white : AppColors.deepCharcoal,
                          fontSize: 14,
                        ),
                    cursorColor: const Color(0xFFFF758C),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: widget.hintText,
                      hintStyle: widget.hintStyle ??
                          TextStyle(
                            color: dark ? Colors.white38 : Colors.grey.shade500,
                            fontSize: 13.5,
                          ),
                      prefixIcon: widget.prefixWidget ??
                          (widget.prefixIcon != null
                              ? Icon(
                                  widget.prefixIcon,
                                  color: const Color(0xFFFF758C),
                                  size: 20,
                                )
                              : null),
                      suffixIcon: widget.suffixIcon,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: widget.contentPadding ??
                          EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: (widget.maxLines > 1 || (widget.minLines != null && widget.minLines! > 1)) ? 14 : 14,
                          ),
                    ),
                  ),
                ),
                if (hasError && state.errorText != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      state.errorText!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
