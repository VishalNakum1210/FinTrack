import 'package:flutter/material.dart';

/// Existing account identifiers must not be migrated by an APK update alone.
class AccountAccessHelp {
  static const supportEmail = String.fromEnvironment(
    'FINTRACK_SUPPORT_EMAIL',
    defaultValue: 'daku.9705@gmail.com',
  );
  static const registrationNotice =
      'Your phone number is an account ID; it is not verified by SMS. '
      'Keep your password safe: profile email cannot reset it.';

  static String get contactInstructions => supportEmail.isEmpty
      ? 'Contact the person who supplied this app using the same channel. '
            'Signed-in users can also use Profile > Feedback.'
      : 'Contact $supportEmail or, while signed in, use Profile > Feedback.';

  static Future<void> showPasswordHelp(
    BuildContext context,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Password recovery'),
      content: SingleChildScrollView(
        child: Text(
          'This version signs in with an account ID and password. '
          'It does not verify phone ownership by SMS. '
          'The email in your profile is contact information and cannot receive '
          'a password-reset link.\n\n'
          '$contactInstructions\n\n'
          'An administrator must verify account ownership through a trusted '
          'process before helping. Knowing a phone number or profile email '
          'is not proof of ownership. Never share your password. '
          'Recovery is not guaranteed, so keep private exports of important records.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
