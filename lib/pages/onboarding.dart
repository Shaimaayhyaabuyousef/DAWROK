import 'package:flutter/material.dart';

// Route names registered in main.dart
const String kSignInRoute = 'login';
const String kSignUpRoute = 'login'; // change to 'signup' once that page exists

const Color kPrimary = Color(0xFF0EA5FF);
const Color kDark = Color(0xFF1E2235);

class _OnboardingItem {
  final String image;
  final String title;
  final String desc;

  const _OnboardingItem({
    required this.image,
    required this.title,
    required this.desc,
  });
}

const List<_OnboardingItem> _items = [
  _OnboardingItem(
    image: 'assets/images/onboarding_1.png',
    title: 'No more long queues',
    desc:
        'Skip the hours in crowds. Dawrok organizes the service so you receive it safely.',
  ),
  _OnboardingItem(
    image: 'assets/images/onboarding_2.png',
    title: 'Book your appointment easily',
    desc:
        'Choose the service and center, pick a time that suits you, and get your digital ticket in seconds.',
  ),
  _OnboardingItem(
    image: 'assets/images/onboarding_3.png',
    title: 'Track your turn live',
    desc:
        'A secure QR ticket that works offline, with an instant alert when your turn is near.',
  ),
];

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(String route) => Navigator.pushReplacementNamed(context, route);

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _items.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Swipeable pages
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _OnboardingPage(item: _items[i]),
                ),

                // Skip button
                if (!isLast)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    child: TextButton(
                      onPressed: () => _go(kSignInRoute),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
              ],
            ),
          ),

          // Page indicators
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? kDark : kPrimary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // Buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _go(kSignInRoute),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _go(kSignUpRoute),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingItem item;
  const _OnboardingPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: SizedBox(
            width: double.infinity,
            child: Image.asset(
              item.image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: kPrimary.withValues(alpha: 0.12),
                child: const Icon(Icons.image_outlined, size: 64, color: kPrimary),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.desc,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}