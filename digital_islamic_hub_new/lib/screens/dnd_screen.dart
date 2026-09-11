import 'package:flutter/material.dart';
import 'package:digital_islamic_hub_new/services/dnd_service.dart';

class DndScreen extends StatefulWidget {
  const DndScreen({super.key});

  @override
  State<DndScreen> createState() => _DndScreenState();
}

class _DndScreenState extends State<DndScreen> {
  bool isDnd = false;

  Future<void> toggleDnd(bool value) async {
    bool success;

    if (value) {
      success = await DndService.enableDnd();
    } else {
      success = await DndService.disableDnd();
    }

    if (success) {
      if (mounted) {
        setState(() {
          isDnd = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? "DND Enabled" : "DND Disabled"),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please allow DND permission first."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Do Not Disturb"),
      ),
      body: Center(
        child: SwitchListTile(
          title: const Text("Enable DND"),
          subtitle: const Text("Silence all notifications"),
          value: isDnd,
          onChanged: (bool value) => toggleDnd(value),
        ),
      ),
    );
  }
}
