import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UI Helper class for common UI components and spacing
class UIHelper {
  // Colors
  static const Color primaryColor = Color(0xFF3498DB);
  static const Color secondaryColor = Color(0xFF2ECC71);
  static const Color accentColor = Color(0xFFF39C12);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color errorColor = Colors.red;
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF39C12);
  static const Color textDarkColor = Color(0xFF2D3436);
  static const Color textLightColor = Color(0xFF636E72);

  // Spacing
  static const double smallSpace = 8.0;
  static const double mediumSpace = 16.0;
  static const double largeSpace = 24.0;
  static const double extraLargeSpace = 32.0;

  // Border radius
  static final BorderRadius smallRadius = BorderRadius.circular(8.0);
  static final BorderRadius mediumRadius = BorderRadius.circular(12.0);
  static final BorderRadius largeRadius = BorderRadius.circular(16.0);
  static final BorderRadius roundedRadius = BorderRadius.circular(50.0);

  // Shadows
  static List<BoxShadow> get lightShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // Vertical spacing
  static Widget verticalSpace(double height) => SizedBox(height: height);
  static Widget get verticalSpaceSmall => verticalSpace(smallSpace);
  static Widget get verticalSpaceMedium => verticalSpace(mediumSpace);
  static Widget get verticalSpaceLarge => verticalSpace(largeSpace);

  // Horizontal spacing
  static Widget horizontalSpace(double width) => SizedBox(width: width);
  static Widget get horizontalSpaceSmall => horizontalSpace(smallSpace);
  static Widget get horizontalSpaceMedium => horizontalSpace(mediumSpace);
  static Widget get horizontalSpaceLarge => horizontalSpace(largeSpace);

  // Common button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(
          horizontal: largeSpace,
          vertical: mediumSpace,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(
          horizontal: largeSpace,
          vertical: mediumSpace,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      );

  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(
          horizontal: largeSpace,
          vertical: mediumSpace,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
        side: const BorderSide(color: primaryColor, width: 1.5),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      );

  // Custom card widget
  static Widget customCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    double? elevation,
    BorderRadius? borderRadius,
  }) {
    return Card(
      elevation: elevation ?? 2,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? largeRadius,
      ),
      color: color ?? Colors.white,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(mediumSpace),
        child: child,
      ),
    );
  }

  // App bar
  static AppBar customAppBar({
    required String title,
    List<Widget>? actions,
    bool centerTitle = true,
    Color? backgroundColor,
    double elevation = 0,
    Widget? leading,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? primaryColor,
      elevation: elevation,
      actions: actions,
      leading: leading,
      bottom: bottom,
    );
  }

  // Custom TextFormField
  static Widget customTextField({
    String? labelText,
    String? hintText,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    Widget? prefixIcon,
    Widget? suffixIcon,
    FocusNode? focusNode,
    bool enabled = true,
    int? maxLines = 1,
    TextInputAction? textInputAction,
    Function()? onEditingComplete,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      focusNode: focusNode,
      enabled: enabled,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: textDarkColor,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      ),
    );
  }

  // Loading indicator
  static Widget loadingIndicator({Color? color, double size = 36.0}) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color ?? primaryColor,
          strokeWidth: 3.0,
        ),
      ),
    );
  }

  // Error text
  static Widget errorText(String message) {
    return Text(
      message,
      style: GoogleFonts.poppins(
        color: errorColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  // Success text
  static Widget successText(String message) {
    return Text(
      message,
      style: GoogleFonts.poppins(
        color: successColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  // Custom divider
  static Widget customDivider({
    double thickness = 1,
    double indent = 20,
    double endIndent = 20,
  }) {
    return Divider(
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: Colors.grey.shade300,
    );
  }
}
