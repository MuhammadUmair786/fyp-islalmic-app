import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';

class TasbeehCounterScreen extends StatefulWidget {
  final Map<String, dynamic> zikar;
  final int index;
  final Function(int) onUpdate;

  const TasbeehCounterScreen({
    super.key,
    required this.zikar,
    required this.index,
    required this.onUpdate
  });

  @override
  State<TasbeehCounterScreen> createState() => _TasbeehCounterScreenState();
}

class _TasbeehCounterScreenState extends State<TasbeehCounterScreen> {
  late int _counter;

  @override
  void initState() {
    super.initState();
    _counter = widget.zikar['count'];
  }

  void _increment() async {
    if (_counter >= widget.zikar['goal']) {
      return;
    }

    setState(() {
      _counter++;
    });
    widget.onUpdate(_counter);

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 60);
    }

    if (_counter == widget.zikar['goal']) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }
      _showSuccessDialog();
    }
  }

  void _reset() {
    setState(() {
      _counter = 0;
    });
    widget.onUpdate(0);
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
        title: Center(child: Text("MashAllah! ❤️", style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryLight))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 60),
            const SizedBox(height: 10),
            Text(
              "Aapne ${widget.zikar['name']} ka target poora kar liya!",
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, 
                foregroundColor: isDark ? AppTheme.primaryDark : Colors.white
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Alhamdulillah"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isGoalReached = _counter >= widget.zikar['goal'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.zikar['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _reset,
            tooltip: "Reset Counter",
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _increment,
              child: Container(color: Colors.transparent),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isGoalReached ? "Goal Reached! Click Reset to start again." : "Target: ${widget.zikar['goal']}",
                    style: TextStyle(
                      fontSize: 18, 
                      color: isGoalReached ? AppTheme.accentGreen : (isDark ? Colors.white38 : Colors.grey), 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGoalReached 
                        ? AppTheme.accentGreen.withAlpha(20) 
                        : (isDark ? Colors.white.withAlpha(10) : AppTheme.primaryLight.withAlpha(10)),
                      border: Border.all(
                        color: isGoalReached ? AppTheme.accentGreen : (isDark ? AppTheme.accentGreen : AppTheme.primaryLight), 
                        width: 8
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: (isGoalReached ? AppTheme.accentGreen : AppTheme.primaryLight).withAlpha(30),
                            blurRadius: 20,
                            spreadRadius: 5
                        )
                      ],
                    ),
                    child: Center(
                      child: Text("$_counter",
                          style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              color: isGoalReached ? AppTheme.accentGreen : (isDark ? Colors.white : AppTheme.primaryLight)
                          )),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    isGoalReached ? "COMPLETED" : "TAP ANYWHERE TO COUNT",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isGoalReached ? AppTheme.accentGreen : (isDark ? Colors.white38 : Colors.grey)
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