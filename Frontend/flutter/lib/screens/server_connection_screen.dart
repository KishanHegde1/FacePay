import 'package:flutter/material.dart';
import '../ui/design.dart';

/// A server delay keeps the saved login intact and never grants offline access.
class ServerConnectionScreen extends StatelessWidget {
  const ServerConnectionScreen({super.key, this.waiting = true, this.onRetry});
  final bool waiting;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FacePayLogo(size: 44),
                    ),
                    const SizedBox(height: 36),
                    if (waiting)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        Icons.cloud_outlined,
                        size: 40,
                        color: AppPalette.of(context).primary,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      waiting
                          ? 'Connecting to the server'
                          : 'The server is taking a little longer',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        waiting
                            ? 'Please wait a moment while we connect. The server may take about a minute to respond.'
                            : 'Please check your internet connection and try again in a moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.of(context).muted,
                          height: 1.6,
                        ),
                      ),
                    ),
                    if (!waiting) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
