import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double radius;
  final Color backgroundColor;

  const AppLogo({
    super.key,
    this.radius = 50,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: const AssetImage('assets/images/islamic_logo.png'),
    );
  }
}
