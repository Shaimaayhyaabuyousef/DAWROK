import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'intro_art.dart';

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
                          if (i == 1)
                            Image.asset(
                              'assets/images/onboarding_2.png',
                              fit: BoxFit.cover,
                            )
                          else
                            ColoredBox(
                              color: i == 0
                                  ? const Color(0xfffff7ee)
                                  : const Color(0xfff1faf2),
                              child: CustomPaint(painter: IntroArt(i == 2)),
                            ),
                          SafeArea(
                            bottom: false,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 6, 0),
                                child: Row(
                                  children: [
                                    if (i > 0)
                                      IconButton(
                                        tooltip: 'Back',
                                        onPressed: () => _move(i - 1),
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new,
                                          color: Colors.black,
                                        ),
                                      ),
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
                                        child: const Text('Skip'),
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
                        label: 'Page ${i + 1} of 3',
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
                      padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
                      child: Text(
                        _titles[i],
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
                      padding: const EdgeInsets.fromLTRB(21, 24, 12, 0),
                      child: Text(
                        _descriptions[i],
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
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
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
                                  child: const Text(
                                    'Signin',
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
                                  child: const Text(
                                    'Signup',
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
