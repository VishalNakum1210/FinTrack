import 'package:flutter/material.dart';

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
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
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
                  color: isSelected ? const Color(0xFFDCEDC8) : Colors.transparent,
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
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
              "By creating an account, registering your mobile number, or using the FinTrack mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, you must discontinue use and delete your account.",
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
              "You are responsible for maintaining the confidentiality of your login credentials. Each account is bound to a single 10-digit mobile number. You agree to notify us immediately of any unauthorized use of your account.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.calculate_outlined,
          iconBg: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF7B1FA2),
          title: "4. User-Entered Records & Calculations",
          content:
              "All income, expense, and friend ledger amounts are inputted voluntarily by the user. FinTrack does not execute bank transfers, settle monetary debts directly, or verify financial transactions with external banking institutions. Any financial reconciliation between friends remains the sole responsibility of the individuals involved.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.delete_forever_rounded,
          iconBg: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFE11D48),
          title: "5. Account Termination & Data Deletion",
          content:
              "You retain the absolute right to delete your FinTrack account at any time through the Profile screen. Account deletion irreversibly purges your personal profile, all recorded expenses, and friend ledger history from our active database.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.warning_amber_rounded,
          iconBg: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFE11D48),
          title: "6. Accidental Deletion & No Fault / Liability Disclaimer",
          content:
              "FinTrack is provided strictly on an 'AS-IS' and 'AS-AVAILABLE' basis. If any transaction, expense record, friend ledger history, or account is deleted accidentally—whether through user mistake, accidental button press, device loss, factory reset, clearing app storage, uninstallation, or technical failure—FinTrack and its developers shall NOT be held responsible, liable, or at fault for any lost data or associated financial disputes. Users are strongly advised to regularly export and save PDF statements as personal offline backups.",
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
              "We collect information necessary to deliver core application functionality:\n• 10-digit Phone Number (used as your unique account identifier)\n• Display Name & Optional Email Address\n• Self-reported expense and income records (amounts, dates, categories, descriptions)\n• Friend names & phone numbers added to your shared ledger.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.cloud_done_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          title: "2. Cloud Storage & Data Security",
          content:
              "User data is stored securely using Google Firebase Realtime Database and Firebase Authentication. Communication between your device and our database is encrypted in transit using industry-standard TLS/SSL encryption.",
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
              "Session tokens on your device are cryptographically signed using HMAC-SHA256 and stored within Android Keystore / iOS Keychain (Flutter Secure Storage) to prevent unauthorized local tampering.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.picture_as_pdf_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          title: "5. Data Portability (PDF Statements)",
          content:
              "You maintain full ownership of your financial records. You can export complete, un-redacted monthly statements and friend ledgers in PDF format at any time directly from the app.",
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
              "The developer and FinTrack assume zero liability for any accidental loss or deletion of transactions, ledger entries, or account credentials. You acknowledge that you are solely responsible for verifying your records and backing up necessary financial statements.",
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.mail_outline_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: _darkGreen,
          title: "5. Contact & Legal Inquiries",
          content:
              "For inquiries regarding these terms, privacy practices, or data deletion verification, please contact our support team at support@fintrack.app or submit a ticket through the in-app Feedback screen.",
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
              "FinTrack v2.2.0 • Privacy-First Architecture • Updated Sep 2026",
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
