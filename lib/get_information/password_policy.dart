/// Firebase Auth stores and verifies passwords. This validates new passwords
/// locally; configure the matching Firebase server policy before deployment.
bool isPasswordStrong(String password) {
  if (password.length < 12 || password.length > 128) return false;
  final letters = RegExp(r'\p{L}', unicode: true).hasMatch(password);
  final digitOrSymbol =
      RegExp(r'[^\p{L}\s]', unicode: true).hasMatch(password);
  return letters && digitOrSymbol;
}
