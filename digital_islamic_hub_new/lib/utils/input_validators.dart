class InputValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static String sanitize(String? value) => (value ?? '').trim();

  static String sanitizeEmail(String? value) => sanitize(value).toLowerCase();

  static bool isValidEmail(String email) => _emailRegex.hasMatch(email);

  static String? email(String? value) {
    final email = sanitizeEmail(value);
    if (email.isEmpty) return 'Email is required';
    if (!isValidEmail(email)) return 'Enter a valid email address';
    return null;
  }

  static String? requiredName(String? value) {
    final name = sanitize(value);
    if (name.isEmpty) return 'Full name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    if (!RegExp(r"^[a-zA-Z\s.'\-]+$").hasMatch(name)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  static String? password(String? value, {bool requireStrength = false}) {
    final password = value ?? '';
    if (password.trim().isEmpty) return 'Password is required';
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!requireStrength) return null;

    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      return 'Password must contain letters';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain numbers';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}
