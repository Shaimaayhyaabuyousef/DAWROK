import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _blue = Color(0xFF008FD4);
const _ink = Color(0xFF182235);
const _body = Color(0xFF52627B);
const _border = Color(0xFFE3EBF4);

/// Public product information, shared by every account role.
class WhoWeAreScreen extends StatelessWidget {
  const WhoWeAreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 24,
        ),
      ),
      title: const Text(
        'Who are we?',
        style: TextStyle(
          color: Color(0xFF64B9FA),
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 9, 24, 32),
            children: [
              Center(
                child: SvgPicture.asset(
                  'assets/images/about_logo.svg',
                  width: 116,
                  height: 116,
                  semanticsLabel: 'DAWROK smart queue logo',
                ),
              ),
              const SizedBox(height: 15),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.ltr,
                children: [
                  Text(
                    'دَوْرَك',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.25,
                      color: Color(0xFF002272),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.circle, size: 8, color: Color(0xFF007B6C)),
                ],
              ),
              const Text(
                'DAWROK • Smart Queue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7C7D8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              const _PurposeCard(
                title: 'OUR MISSION',
                subtitle: 'Equitable Queue & Dispensing Dignity',
                icon: Icons.my_location_outlined,
                highlighted: true,
                body: 'Dorak transforms fragmented humanitarian queues into digital, transparent, and fair distribution flows. We safeguard citizen dignity by eradicating chaotic crowding and guaranteeing verified relief delivery.',
              ),
              const SizedBox(height: 16),
              const _PurposeCard(
                title: 'OUR VISION',
                subtitle: 'Digital Coordination Everywhere',
                icon: Icons.visibility_outlined,
                body: 'A seamless humanitarian logistics ecosystem where beneficiaries access aid instantly with minimal wait times, fully backed by real-time inventory tracking and community verification.',
              ),
              const SizedBox(height: 17),
              const Text(
                'Core Values & Principles',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 17),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Keep the three reference cards together on phones; allow large text
                  // to wrap into full-width cards rather than clipping their labels.
                  final stacked =
                      MediaQuery.textScalerOf(context).scale(13) > 19 ||
                      constraints.maxWidth < 290;
                  const cards = [
                    _ValueCard(
                      label: 'Transparency',
                      icon: Icons.shield_outlined,
                    ),
                    _ValueCard(
                      label: 'Dignity',
                      icon: Icons.favorite_border,
                      color: Color(0xFF00A884),
                      background: Color(0xFFD0FBE9),
                    ),
                    _ValueCard(label: 'Speed', icon: Icons.bolt_outlined),
                  ];
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: card,
                          ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PurposeCard extends StatelessWidget {
  final String title, subtitle, body;
  final IconData icon;
  final bool highlighted;
  const _PurposeCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    this.highlighted = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlighted ? const Color(0xFFDDF2FF) : _border,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0603A9F4),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDF2FF)),
              ),
              child: Icon(icon, size: 20, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            color: _body,
            fontSize: 12,
            height: 1.5,
            letterSpacing: .1,
          ),
        ),
      ],
    ),
  );
}

class _ValueCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, background;
  const _ValueCard({
    required this.label,
    required this.icon,
    this.color = _blue,
    this.background = const Color(0xFFE0F3FF),
  });
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 63),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF7FAFD)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D182235),
          blurRadius: 2,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: background,
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
