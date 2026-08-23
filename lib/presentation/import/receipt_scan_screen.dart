import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/receipt_analyzer.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_success.dart';
import '../widgets/folio_background.dart';
import '../widgets/premium_surface.dart';

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

enum _ReceiptStage { choose, analyzing, review, saved }

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen>
    with WidgetsBindingObserver {
  final picker.ImagePicker _picker = picker.ImagePicker();
  final ReceiptAnalyzer _analyzer = MlKitReceiptAnalyzer();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  camera.CameraController? _camera;
  _ReceiptStage _stage = _ReceiptStage.choose;
  String? _imagePath;
  ReceiptAnalysis? _analysis;
  String _category = 'Market';
  bool _cameraLoading = true;
  bool _captureBusy = false;
  bool _torchEnabled = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage != _ReceiptStage.choose) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });

    try {
      final List<camera.CameraDescription> cameras = await camera.availableCameras();
      if (cameras.isEmpty) {
        throw camera.CameraException('noCamera', 'Bu cihazda kullanılabilir kamera bulunamadı.');
      }
      final camera.CameraDescription selected = cameras.firstWhere(
        (camera.CameraDescription item) => item.lensDirection == camera.CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera.CameraController controller = camera.CameraController(
        selected,
        camera.ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: camera.ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(camera.FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final camera.CameraController? previous = _camera;
      _camera = controller;
      if (previous != null) await previous.dispose();
      setState(() {
        _cameraLoading = false;
        _cameraError = null;
      });
    } on camera.CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraError = switch (error.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            'Kamera izni kapalı. Ayarlardan Folio için kamera erişimine izin verebilirsin.',
          _ => 'Kamera başlatılamadı. Galeriden fiş seçebilir veya sistem kamerasını kullanabilirsin.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraError = 'Kamera başlatılamadı. Galeriden fiş seçebilirsin.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final camera.CameraController? controller = _camera;
    _camera = null;
    _torchEnabled = false;
    if (controller != null) await controller.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final camera.CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized || _captureBusy) return;
    setState(() => _captureBusy = true);
    try {
      final camera.XFile photo = await controller.takePicture();
      if (_torchEnabled) {
        await controller.setFlashMode(camera.FlashMode.off);
        _torchEnabled = false;
      }
      await _analyzePath(photo.path);
    } on camera.CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf çekilemedi. Tekrar deneyebilirsin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _captureBusy = false);
    }
  }

  Future<void> _pickGallery() async {
    final picker.XFile? image = await _picker.pickImage(
      source: picker.ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2800,
    );
    if (image == null || !mounted) return;
    await _analyzePath(image.path);
  }

  Future<void> _fallbackSystemCamera() async {
    final picker.XFile? image = await _picker.pickImage(
      source: picker.ImageSource.camera,
      imageQuality: 92,
      maxWidth: 2800,
    );
    if (image == null || !mounted) return;
    await _analyzePath(image.path);
  }

  Future<void> _analyzePath(String path) async {
    if (!mounted) return;
    setState(() {
      _imagePath = path;
      _stage = _ReceiptStage.analyzing;
    });
    await _disposeCamera();

    try {
      final ReceiptAnalysis result = await _analyzer.analyze(path);
      if (!mounted) return;
      _merchantController.text = result.merchant;
      _amountController.text = result.amount > 0
          ? result.amount.toStringAsFixed(2).replaceAll('.', ',')
          : '';
      setState(() {
        _analysis = result;
        _category = AppConstants.categories.contains(result.category) ? result.category : 'Diğer';
        _stage = _ReceiptStage.review;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analysis = ReceiptAnalysis(
          merchant: 'Bilinmeyen mağaza',
          amount: 0,
          date: DateTime.now(),
          category: 'Diğer',
          confidence: 0.45,
          rawText: '',
        );
        _merchantController.text = '';
        _amountController.text = '';
        _category = 'Diğer';
        _stage = _ReceiptStage.review;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiş tam okunamadı. Alanları elle tamamlayabilirsin.')),
      );
    }
  }

  Future<void> _toggleTorch() async {
    final camera.CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final bool next = !_torchEnabled;
      await controller.setFlashMode(next ? camera.FlashMode.torch : camera.FlashMode.off);
      if (mounted) setState(() => _torchEnabled = next);
    } on camera.CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu cihazda sürekli flaş kullanılamıyor.')),
        );
      }
    }
  }

  Future<void> _save() async {
    final double? amount = Formatters.parseMoneyInput(_amountController.text);
    if (amount == null || amount <= 0 || _merchantController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mağaza ve tutarı kontrol et.')),
      );
      return;
    }
    const Uuid uuid = Uuid();
    await ref.read(walletProvider.notifier).addTransaction(
          TransactionRecord(
            id: uuid.v4(),
            title: _merchantController.text.trim(),
            merchant: _merchantController.text.trim(),
            category: _category,
            amount: amount,
            date: _analysis?.date ?? DateTime.now(),
            type: TransactionType.expense,
            source: TransactionSource.receipt,
            paymentLabel: AppConstants.defaultPaymentLabel,
          ),
        );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _stage = _ReceiptStage.saved);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _stage == _ReceiptStage.choose ? const Color(0xFF070708) : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: switch (_stage) {
          _ReceiptStage.choose => _choose(context),
          _ReceiptStage.analyzing => FolioBackground(child: SafeArea(child: _analyzing(context))),
          _ReceiptStage.review => FolioBackground(child: SafeArea(child: _review(context))),
          _ReceiptStage.saved => FolioBackground(child: SafeArea(child: _saved(context))),
        },
      ),
    );
  }

  Widget _choose(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Stack(
      key: const ValueKey<String>('choose'),
      fit: StackFit.expand,
      children: <Widget>[
        _cameraLayer(),
        const _CameraShade(),
        CustomPaint(painter: const _ScannerFramePainter(color: Colors.white)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Kapat',
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    Text(
                      'Fiş tara',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    _GlassIconButton(
                      icon: _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      tooltip: 'Flaş',
                      onPressed: _camera == null ? null : _toggleTorch,
                    ),
                  ],
                ),
                const Spacer(),
                if (_cameraError == null)
                  Text(
                    'Fişin tamamını çerçevenin içinde tut.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                    ),
                    child: Text(
                      _cameraError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: _CameraSecondaryAction(
                          icon: Icons.photo_library_outlined,
                          label: 'Galeri',
                          onTap: _pickGallery,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cameraError == null && !_cameraLoading ? _capture : null,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        scale: _captureBusy ? 0.92 : 1,
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cameraLoading || _cameraError != null
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white,
                            ),
                            child: _captureBusy
                                ? const Padding(
                                    padding: EdgeInsets.all(17),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: _CameraSecondaryAction(
                          icon: Icons.camera_alt_outlined,
                          label: 'Sistem',
                          onTap: _cameraError == null ? null : _fallbackSystemCamera,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: media.padding.bottom > 0 ? 6 : 2),
                Text(
                  'Görüntü cihazında işlenir.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.52),
                        letterSpacing: 0.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraLayer() {
    final camera.CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: const Color(0xFF101012),
        alignment: Alignment.center,
        child: _cameraLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(
                Icons.receipt_long_outlined,
                size: 62,
                color: Colors.white.withValues(alpha: 0.28),
              ),
      );
    }
    final Size? preview = controller.value.previewSize;
    if (preview == null) return camera.CameraPreview(controller);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: camera.CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _analyzing(BuildContext context) {
    return Center(
      key: const ValueKey<String>('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: PremiumSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.82, end: 1),
              duration: const Duration(milliseconds: 680),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double value, Widget? child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.document_scanner_outlined, color: Theme.of(context).colorScheme.onSurface, size: 28),
              ),
            ),
            const SizedBox(height: 26),
            Text('Fiş inceleniyor', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Mağaza, tutar ve tarihi cihazında okuyorum.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            const _ScanStep(label: 'Mağaza bulunuyor', delay: 0),
            const _ScanStep(label: 'Tutar okunuyor', delay: 1),
            const _ScanStep(label: 'Tarih kontrol ediliyor', delay: 2),
            const _ScanStep(label: 'Kategori belirleniyor', delay: 3),
          ],
        ),
        ),
      ),
    );
  }

  Widget _review(BuildContext context) {
    final ReceiptAnalysis analysis = _analysis!;
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey<String>('review'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
              const Spacer(),
              Text('Fiş sonucu', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _stage = _ReceiptStage.choose;
                    _analysis = null;
                    _imagePath = null;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Tekrar tara',
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 176,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.file(File(_imagePath!), fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(99)),
                              child: Text('%${(analysis.confidence * 100).round()} güven', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Text('TUTAR', style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.left,
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 52, letterSpacing: -2.2),
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    suffixText: ' ₺',
                    suffixStyle: theme.textTheme.displayMedium?.copyWith(fontSize: 27, letterSpacing: -0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(child: _ReceiptMeta(label: 'Tarih', value: Formatters.fullDate(analysis.date), icon: Icons.calendar_today_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReceiptMeta(label: 'Kaynak', value: 'Fiş OCR', icon: Icons.document_scanner_outlined)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('İşlem bilgileri', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text('MAĞAZA', style: theme.textTheme.labelMedium),
                const SizedBox(height: 9),
                TextField(controller: _merchantController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Mağaza')),
                const SizedBox(height: 20),
                Text('KATEGORİ', style: theme.textTheme.labelMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppConstants.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final String category = AppConstants.categories[index];
                      final bool selected = category == _category;
                      final Color tone = AppColors.category(category);
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = category),
                        side: BorderSide(color: selected ? tone.withValues(alpha: 0.30) : theme.dividerColor.withValues(alpha: 0.55)),
                        selectedColor: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10),
                        backgroundColor: AppColors.elevated(theme.brightness),
                        labelStyle: theme.textTheme.labelLarge?.copyWith(color: selected ? tone : theme.colorScheme.onSurface),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Harcamaya ekle'))),
          const SizedBox(height: 10),
          Center(child: Text('Görüntü ve metin cihazında işlenir.', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _saved(BuildContext context) {
    return Center(
      key: const ValueKey<String>('saved'),
      child: FolioSuccess(
        title: 'Harcamaya eklendi',
        body: '${Formatters.month(DateTime.now())} görünümün güncellendi.',
      ),
    );
  }
}

class _ReceiptMeta extends StatelessWidget {
  const _ReceiptMeta({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: AppColors.soft(theme.brightness), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.muted(theme.brightness)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          ])),
        ],
      ),
    );
  }
}

class _CameraShade extends StatelessWidget {
  const _CameraShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const <double>[0, 0.22, 0.62, 1],
            colors: <Color>[
              Colors.black.withValues(alpha: 0.54),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.68),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      color: Colors.white,
      style: IconButton.styleFrom(
        minimumSize: const Size(46, 46),
        backgroundColor: Colors.black.withValues(alpha: 0.24),
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.12),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.36),
      ),
    );
  }
}

class _CameraSecondaryAction extends StatelessWidget {
  const _CameraSecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: onTap == null ? 0.28 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanStep extends StatefulWidget {
  const _ScanStep({required this.label, required this.delay});
  final String label;
  final int delay;

  @override
  State<_ScanStep> createState() => _ScanStepState();
}

class _ScanStepState extends State<_ScanStep> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 260 + widget.delay * 260), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _done
                ? const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey<bool>(true),
                    color: AppColors.sage,
                    size: 18,
                  )
                : const SizedBox(
                    key: ValueKey<bool>(false),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
          ),
          const SizedBox(width: 12),
          Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: size.width * 0.76,
      height: size.height * 0.52,
    );
    final Paint glow = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double segment = 40;
    final Path path = Path()
      ..moveTo(rect.left, rect.top + segment)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + segment, rect.top)
      ..moveTo(rect.right - segment, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + segment)
      ..moveTo(rect.right, rect.bottom - segment)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - segment, rect.bottom)
      ..moveTo(rect.left + segment, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - segment);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) => oldDelegate.color != color;
}
