import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Typography and icons from the facility and employee mobile frames.
class WorkspaceStyle extends StatelessWidget {
  final Widget child;
  const WorkspaceStyle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Inter'),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
      ),
      child: child,
    );
  }
}

class WorkspaceIcon extends StatelessWidget {
  final String asset;
  final Color? color;
  const WorkspaceIcon(this.asset, {super.key, this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/workspace/$asset.svg',
    excludeFromSemantics: true,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}
