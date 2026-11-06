import 'package:flutter/material.dart';
import 'package:fin_track/app_licenses.dart';
import 'package:fin_track/authentication/account_access_help.dart';

/// Visible authorship credit, separate from the signed-in user's identity.
class CreatorCredit extends StatelessWidget {
  const CreatorCredit({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      children: [
        const Icon(Icons.draw_outlined, size: 20, color: Color(0xFF33691E)),
        const SizedBox(height: 6),
        const Text(
          'Created by Vishal Nakum',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        TextButton(
          onPressed: () {
            registerAppLicenses();
            showAboutDialog(
              context: context,
              applicationName: 'FinTrack',
              applicationLegalese: 'Created by Vishal Nakum',
              children: const [Text('Support: ${AccountAccessHelp.supportEmail}')],
            );
          },
          child: const Text('About FinTrack & licenses'),
        ),
      ],
    ),
  );
}
