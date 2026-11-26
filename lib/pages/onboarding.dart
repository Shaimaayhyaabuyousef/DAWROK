import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_project/l10n/app_language.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _controller = PageController();
  int _page = 0;
  static const _titles = [
    'No More Waiting in Endless Lines',
    'Book your appointment easily',
    'No More Waiting in Endless Lines',
  ];
  static const _descriptions = [
    'Chaotic queues waste hours and strip dignity. We replace crowded waiting with organized digital time slots.',
    'Choose the service and center, pick a time that suits you, and get your digital ticket in seconds.',
    'Present your ticket at the counter and receive service in less than two minutes—with complete transparency.',
  ];
  static const _blue = Color(0xff03a9f4);
  void _move(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, layout) {
            final heroHeight = layout.maxHeight * .6185;
            return PageView.builder(
              controller: _controller,
              itemCount: 3,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const [
                              Color(0xfffff6ee),
                              Color(0xffeff6fe),
                              Color(0xfff1faf2),
                            ][i],
                            child: Image.asset(
                              'assets/images/onboarding_${i + 1}.png',
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                          SafeArea(
                            bottom: false,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 0),
                                child: Row(
                                  children: [
                                    if (i > 0)
                                      IconButton(
                                        tooltip: tr('Back'),
                                        onPressed: () => _move(i - 1),
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new,
                                          color: Colors.black,
                                        ),
                                      ),
                                    if (i == 0) const _LanguageSwitch(),
                                    const Spacer(),
                                    if (i < 2)
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pushReplacementNamed(
                                              context,
                                              'login',
                                            ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                        ),
                                        child: Text(tr('Skip')),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        label: tr('Page ${i + 1} of 3'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (j) => GestureDetector(
                              onTap: () => _move(j),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 8,
                                ),
                                child: Container(
                                  width: j == _page ? 23 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: j == _page
                                        ? const Color(0xff202020)
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 8, 0),
                      child: Text(
                        tr(_titles[i]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(21, 24, 12, 0),
                      child: Text(
                        tr(_descriptions[i]),
                        style: const TextStyle(
                          fontSize: 17.5,
                          height: 1.48,
                          color: Color(0xff757575),
                        ),
                      ),
                    ),
                    if (i == 2)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(24, 26, 24, 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                        context,
                                        'login',
                                      ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _blue,
                                    side: const BorderSide(color: _blue),
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    tr('Signin'),
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                        context,
                                        'signup',
                                      ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    tr('Signup'),
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// English / العربية switch on the first onboarding page. Arabic turns the
/// whole app right-to-left; the choice is remembered on this device.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8, end: 4),
              child: Icon(Icons.language_rounded, size: 18, color: Color(0xFF2196F3)),
            ),
            _option('en', 'EN'),
            _option('ar', 'عربي'),
          ],
        ),
      ),
    );
  }

  Widget _option(String code, String label) {
    final selected = AppLanguage.locale.value.languageCode == code;
    return Semantics(
      button: true,
      selected: selected,
      label: code == 'en' ? 'English' : 'العربية',
      child: GestureDetector(
        onTap: () => AppLanguage.set(code),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2196F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF475870),
            ),
          ),
        ),
      ),
    );
  }
}
