import 'package:flutter/material.dart';

class ConfirmLoginPage extends StatelessWidget {
  final String domain;
  final String action;

  const ConfirmLoginPage({
    super.key,
    required this.domain,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final actionText = switch (action) {
      'register' => 'register an account at',
      'link' => 'link your account at',
      'auth' => 'authenticate with',
      _ => 'sign in to',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm LNURL-auth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("You're about to $actionText $domain"),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}