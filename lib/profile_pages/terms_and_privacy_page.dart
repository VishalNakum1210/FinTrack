import 'package:flutter/material.dart';
import 'package:fin_track/widgets/creator_credit.dart';
import 'package:fin_track/authentication/account_access_help.dart';

class TermsAndPrivacyPage extends StatefulWidget {
  final int initialTabIndex;
  const TermsAndPrivacyPage({super.key, this.initialTabIndex = 0});

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  late int _selectedTab;

  final List<String> _tabs = const [
    "Terms of Service",
    "Privacy Policy",
    "Disclaimers",
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Curved Header
            _buildHeader(),

            // 2. Main Content Card
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Segmented Tabs
                    _buildSegmentedTabs(),

                    const SizedBox(height: 16),

                    // Active Tab Content
                    if (_selectedTab == 0)
                      _buildTermsContent()
                    else if (_selectedTab == 1)
                      _buildPrivacyContent()
                    else
                      _buildDisclaimersContent(),

                    const SizedBox(height: 20),

                    // Trust Pill
                    _buildTrustBadge(),

                    const CreatorCredit(),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER
  // ===========================================================================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _darkGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Terms & Privacy Policy",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Legal disclaimers & user data rights",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. SEGMENTED TABS
  // ===========================================================================
  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFDCEDC8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: const Color(0xFFA5D6A7), width: 1)
                      : Border.all(color: Colors.transparent),
                ),
                child: Center(
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected ? _darkGreen : _textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // 3. TERMS OF SERVICE CONTENT
  // ===========================================================================
  Widget _buildTermsContent() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.handshake_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: _darkGreen,
          title: "1. Acceptance of Terms",
          content:
              "FinTrack is created by Vishal Nakum. By creating an account or using the application, you agree to these terms and acknowledge the Privacy Policy. If you do not agree, do not create an account or use the service. Existing users can export their records and request account deletion.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.account_balance_wallet_rounded,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          title: "2. Scope of Service",
          content:
              "FinTrack provides personal financial tracking, categorized budget insights, split-bill mathematics, and personal friend debt/credit ledger recording. FinTrack is an informational utility designed to help users record self-reported expenditures.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.lock_outline_rounded,
          iconBg: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFD97706),
          title: "3. User Account & Authentication",
          content:
              "You are responsible for keeping your password safe. Your 10-digit phone number is an account identifier, not proof of phone ownership; this version does not verify it by SMS. Profile email is contact information and cannot reset your password. Administrator-assisted recovery requires independent ownership verification and is not guaranteed.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.calculate_outlined,
          iconBg: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF7B1FA2),
          title: "4. User-Entered Records & Calculations",
          content:
              "All income, expense, and friend ledger amounts are inputted voluntarily by the user. Ledger nets reflect your recorded income and personal expense shares, not verified cash in hand or bank balances. FinTrack does not execute bank transfers, settle monetary debts directly, or verify financial transactions with external banking institutions. Any financial reconciliation between friends remains the sole responsibility of the individuals involved.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.delete_forever_rounded,
          iconBg: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFE11D48),
          title: "5. Account Termination & Data Deletion",
          content:
              "You can delete your FinTrack account through the Profile screen after confirming your password. The app removes financial history, feedback, and profile contact details before deleting the authentication account. A minimal ownership/deletion marker retains the account identifier and UID to support safe retries and prevent orphaned-history reuse; it can be replaced when that identifier is registered again after cleanup. If authentication deletion fails, retry from Profile when connected.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.warning_amber_rounded,
          iconBg: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFE11D48),
          title: "6. Service Availability & Your Rights",
          content:
              "We aim to keep FinTrack reliable, but availability, uninterrupted synchronization and recovery of lost records cannot be guaranteed. Check important amounts against original records and export private copies before deleting data. Nothing in these terms excludes rights or liabilities that applicable law does not allow to be excluded. Material changes to these terms will be disclosed through an app update or notice.",
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. PRIVACY POLICY CONTENT
  // ===========================================================================
  Widget _buildPrivacyContent() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.shield_outlined,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: _darkGreen,
          title: "1. Information We Collect",
          content:
              "FinTrack, created by Vishal Nakum, collects data you enter to operate your account and ledger: your name, phone account ID, email, optional profile address, income/expense records, friend names and numbers, split/trip records, and feedback (message, rating, type and contact email). Registration currently requires an email, but it is not verified or used for password recovery. Friend details are entered manually; the app does not read your phone contacts. Enter only information you have permission to use.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.cloud_done_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          title: "2. Cloud Storage & Data Security",
          content:
              "Google Firebase Authentication processes account credentials and manages authentication. Firebase Realtime Database stores profile, ledger, trip and feedback records so you can access and synchronize them. Firebase also processes technical connection information needed to provide these services. App-to-Firebase traffic uses TLS. UID-based database rules restrict account access; this is not end-to-end encryption. The developer and authorized service operators may access data for support, security and service operation.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.block_rounded,
          iconBg: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFDC2626),
          title: "3. Zero Advertising & No Data Selling",
          content:
              "We believe personal finances are private. We DO NOT sell, rent, monetize, or disclose your financial records, phone numbers, or ledger logs to third-party advertisers or data brokers.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.vpn_key_rounded,
          iconBg: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFB45309),
          title: "4. Local Session Protection",
          content:
              "Firebase Authentication manages your sign-in session. Profile metadata is cached using Flutter Secure Storage, and local metadata alone never grants access to cloud data. Financial data may also be cached by Firebase for offline access; protect your device and exported statements.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.picture_as_pdf_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          title: "5. Data Portability (PDF Statements)",
          content:
              "You can export available records as PDF, CSV or JSON using the system print/share tools. Exports are unencrypted files; share them only with intended recipients. JSON is an archive, not an in-app restore feature. Deleting an account cannot recall exports you have already saved or shared.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.history_rounded,
          iconBg: const Color(0xFFF1F5F9),
          iconColor: _darkGreen,
          title: '6. Retention & Account Deletion',
          content:
              'Account records are retained while the account is in use. Profile > Delete Account removes your financial roots, feedback and profile contact details before deleting Firebase Authentication credentials. A minimal phone account ID, UID and deletion marker remain for security and safe deletion retries, with no automatic expiry currently implemented; the marker can be replaced after clean re-registration. If deletion fails, reconnect and retry or contact support. Your local exports and records entered independently by other users are not erased by deleting your account. Provider backup/log retention is subject to the configured Firebase services; contact support with a specific retention or deletion request.',
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.mail_outline,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: _darkGreen,
          title: '7. Contact & Privacy Choices',
          content:
              'For access, correction, account deletion or privacy questions, email ${AccountAccessHelp.supportEmail}. You can edit profile details, export available records and delete your account in Profile. The current app has no advertising SDK or analytics product integrated. We do not sell financial data. System share destinations receive only the files you choose to share. Privacy changes will be disclosed through an app update or notice.',
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. DISCLAIMERS & SECURITY CONTENT
  // ===========================================================================
  Widget _buildDisclaimersContent() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.account_balance_outlined,
          iconBg: const Color(0xFFFFEDD5),
          iconColor: const Color(0xFFEA580C),
          title: "1. Not a Banking / Financial Institution",
          content:
              "FinTrack is an independent digital notebook and personal budget utility. FinTrack is NOT a bank, payment service provider, digital wallet, or non-banking financial company (NBFC). The app does not hold funds, accept deposits, or execute monetary payments.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.insights_rounded,
          iconBg: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF7C3AED),
          title: "2. No Professional Financial Advice",
          content:
              "The financial health score, category summaries, and monthly spending insights provided in the app are computed algorithmically from self-reported data for educational purposes only. They do not constitute certified financial, tax, or investment advice.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.wifi_off_rounded,
          iconBg: const Color(0xFFF1F5F9),
          iconColor: const Color(0xFF475569),
          title: "3. Offline Sync Disclaimer",
          content:
              "FinTrack offers offline capability; entries created while disconnected are queued locally and synchronized once network access is restored. Users should ensure regular connectivity to prevent sync divergence.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.report_problem_outlined,
          iconBg: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFE11D48),
          title: "4. No Liability for Lost Data or User Deletion Errors",
          content:
              "Check important records and keep private exports before account deletion, device changes or clearing storage. Service or device failures may cause unavailable or lost records. These limitations do not remove rights or liabilities that cannot legally be excluded.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.mail_outline_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: _darkGreen,
          title: "5. Contact & Legal Inquiries",
          content:
              "For questions about privacy, account access, or data deletion: ${AccountAccessHelp.contactInstructions}",
        ),
      ],
    );
  }

  // ===========================================================================
  // HELPER SECTION CARD
  // ===========================================================================
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: _textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TRUST BADGE
  // ===========================================================================
  Widget _buildTrustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: _darkGreen),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              "FinTrack • Terms & Privacy • Updated 31 Oct 2026",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
