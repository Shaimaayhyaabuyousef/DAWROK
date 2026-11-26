import 'package:flutter/material.dart';
import 'package:first_project/l10n/app_language.dart';

class CitizenBottomNav extends StatelessWidget {
  const CitizenBottomNav({
    super.key,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  final int selected;
  final ValueChanged<int> onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'My Queue', 'Profile'];
    const icons = [
      Icons.home_outlined,
      Icons.tune_rounded,
      Icons.person_outline,
    ];
    const activeIcons = [
      Icons.home_rounded,
      Icons.tune_rounded,
      Icons.person_rounded,
    ];
    final blue = dark ? const Color(0xff75c9ff) : const Color(0xff008edd);
    return Material(
      color: dark ? const Color(0xff172437) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(
          color: dark ? const Color(0xff34445a) : const Color(0xffeff3f6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: List.generate(labels.length, (i) {
              final active = i == selected;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: labels[i],
                  excludeSemantics: true,
                  onTap: () => onTap(i),
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 52,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? (dark
                                      ? const Color(0xff25455b)
                                      : const Color(0xffe5f6ff))
                                : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active ? activeIcons[i] : icons[i],
                                size: 21,
                                color: blue,
                              ),
                              if (active) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    tr(labels[i]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: blue),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
