import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/lnurl_input.dart';

class _CameraOption {
  final CameraFacing facing;
  final CameraLensType lens;
  final String label;

  const _CameraOption(this.facing, this.lens, this.label);

  @override
  bool operator ==(Object other) =>
      other is _CameraOption && other.facing == facing && other.lens == lens;

  @override
  int get hashCode => Object.hash(facing, lens);
}

/// Full-screen QR scanner. Pops with the LNURL (lowercase bech32) it finds.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  _CameraOption? _selected;
  bool _done = false;
  bool _unsupportedCode = false;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      final lnurl = extractLnurl(raw);
      if (lnurl != null) {
        _done = true;
        Navigator.pop(context, lnurl);
        return;
      }
    }

    setState(() => _unsupportedCode = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _unsupportedCode = false);
    });
  }

  Future<List<_CameraOption>> _loadCameraOptions() async {
    final options = <_CameraOption>[];

    for (final (facing, name) in [
      (CameraFacing.back, 'Back'),
      (CameraFacing.front, 'Front'),
    ]) {
      Set<CameraLensType> lenses;
      try {
        lenses = await _controller.getSupportedLenses(facing: facing);
      } catch (_) {
        continue;
      }
      if (lenses.isEmpty) continue;

      final specific = lenses.where((l) => l != CameraLensType.any).toList()
        ..sort((a, b) => a.rawValue.compareTo(b.rawValue));

      if (specific.length < 2) {
        options.add(_CameraOption(facing, CameraLensType.any, '$name camera'));
      } else {
        for (final lens in specific) {
          final lensName = switch (lens) {
            CameraLensType.wide => 'Wide',
            CameraLensType.zoom => 'Zoom',
            _ => 'Main',
          };
          options.add(_CameraOption(facing, lens, '$name · $lensName'));
        }
      }
    }

    return options;
  }

  _CameraOption? _currentOption(List<_CameraOption> options) {
    if (_selected != null && options.contains(_selected)) return _selected;
    final facing = _controller.value.cameraDirection;
    for (final o in options) {
      if (o.facing == facing) return o;
    }
    return null;
  }

  Future<void> _showCameraPicker() async {
    final options = await _loadCameraOptions();
    if (!mounted) return;

    if (options.length < 2) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No other cameras available')),
        );
      return;
    }

    final current = _currentOption(options);
    final choice = await showModalBottomSheet<_CameraOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose camera',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option.facing == CameraFacing.front
                      ? Icons.camera_front_outlined
                      : Icons.camera_rear_outlined,
                ),
                title: Text(option.label),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );

    if (choice == null || choice == current || !mounted) return;

    try {
      await _controller.switchCamera(
        SelectCamera(facingDirection: choice.facing, lensType: choice.lens),
      );
      if (mounted) setState(() => _selected = choice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't switch camera")));
    }
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final theme = Theme.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                denied ? 'Camera access denied' : "Couldn't start the camera",
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Allow camera access for Flare in your system settings '
                          'to scan QR codes.'
                    : error.errorDetails?.message ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final side = constraints.biggest.shortestSide * 0.7;

    return Stack(
      children: [
        Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _unsupportedCode
                    ? theme.colorScheme.error
                    : Colors.white,
                width: 4,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_unsupportedCode),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _unsupportedCode
                        ? theme.colorScheme.errorContainer
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _unsupportedCode
                        ? "That isn't an LNURL-auth code"
                        : 'Point the camera at a login QR code',
                    style: TextStyle(
                      color: _unsupportedCode
                          ? theme.colorScheme.onErrorContainer
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR code'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isRunning || (state.availableCameras ?? 2) < 2) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Switch camera',
                icon: const Icon(Icons.cameraswitch_outlined),
                onPressed: _showCameraPicker,
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn flashlight off' : 'Turn flashlight on',
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: _buildError,
        overlayBuilder: _buildOverlay,
      ),
    );
  }
}
