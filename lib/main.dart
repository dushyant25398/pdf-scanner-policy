import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/cloud_service.dart';
import 'login_screen.dart';
import 'edit_pdf_screen.dart';
import 'scan_preview_screen.dart';
import 'image_preview_screen.dart';
import 'merge_preview_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'services/storage_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:edge_detection/edge_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'ocr_result_screen.dart';
import 'document_picker_screen.dart';
import 'qr_scanner_screen.dart';
import 'compression_screen.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/scale_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await MobileAds.instance.initialize();
    await Hive.initFlutter();
    await Hive.openBox('pdfBox');
  } catch (e) {
    debugPrint("Initialization failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Premium PDF Scanner',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF64748B),
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8),
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: const Color(0xFF1E293B),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return HomeScreen(
              onThemeChanged: toggleTheme,
              themeMode: _themeMode,
            );
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => HomeScreen(
              onThemeChanged: toggleTheme,
              themeMode: _themeMode,
            ),
      },
    );
  }
}


Widget _buildBentoCard({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  bool isLarge = false,
  bool isLocked = false,
  bool isNew = false,
}) {
  return ScaleButton(
    onTap: onTap,
    child: Container(
      height: 130, // Consistently 130
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (isNew)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isLocked)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.lock_outline_rounded,
                  size: 18, color: Colors.grey.shade400),
            ),
        ],
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode themeMode;

  const HomeScreen(
      {super.key, required this.onThemeChanged, required this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final ImagePicker _picker = ImagePicker();
  List<File> pdfFiles = [];
  final List<String> _scannedImagePaths = [];
  bool isSelectionMode = false;
  Set<String> selectedPaths = {};
  bool _isProcessingScan = false;
  bool _isLoadingPdfs = false;
  
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;

  int _scanCount = 0;
  int _actionCount = 0;
  final int _maxGuestScans = 3;

  final CloudService cloudService = CloudService();

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  final ScrollController _homeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadPdfPaths();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadScanCount();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _homeScrollController.addListener(() {
      if (_homeScrollController.offset > 50 && _blinkController.isAnimating) {
        _blinkController.stop();
        setState(() {}); // Trigger rebuild to hide the arrow
      } else if (_homeScrollController.offset <= 50 && !_blinkController.isAnimating) {
        _blinkController.repeat(reverse: true);
        setState(() {}); // Trigger rebuild to show the arrow
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _blinkController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: "ca-app-pub-3940256099942544/5224354917", // Test ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("Rewarded Ad Loaded successfully.");
          _rewardedAd = ad;
          _isRewardedReady = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint("Rewarded Ad Failed to Load: $error");
          _isRewardedReady = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void _showRewardedAd(VoidCallback onRewardEarned) {
    if (_isRewardedReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) => debugPrint("Rewarded Ad Showed."),
        onAdDismissedFullScreenContent: (ad) {
          debugPrint("Rewarded Ad Dismissed.");
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint("Rewarded Ad Failed to Show: $error");
          ad.dispose();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        debugPrint("User earned reward: ${reward.amount} ${reward.type}");
        onRewardEarned();
      });
      _isRewardedReady = false;
      _rewardedAd = null;
    } else {
      debugPrint("Rewarded Ad not ready yet. Attempting to load...");
      _loadRewardedAd();
    }
  }


  Future<void> _loadScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scanCount = prefs.getInt('scan_count') ?? 0;
    });
  }

  Future<void> _incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scanCount++;
    });
    await prefs.setInt('scan_count', _scanCount);
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {});
    } catch (e) {
      debugPrint("Login Error: $e");
    }
  }

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  Future<void> _extractTextFromSelected(BuildContext context) async {
    if (pdfFiles.isEmpty && selectedPaths.isEmpty) return;
    
    File file;
    if (selectedPaths.isNotEmpty) {
      file = File(selectedPaths.first);
    } else {
      file = pdfFiles.first;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Processing all pages...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      final document = await pdfx.PdfDocument.openFile(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      StringBuffer fullText = StringBuffer();

      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 90,
        );
        
        if (pageImage != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/ocr_page_$i.jpg');
          await tempFile.writeAsBytes(pageImage.bytes);
          
          final inputImage = InputImage.fromFile(tempFile);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          
          fullText.writeln("--- Page $i ---");
          fullText.writeln(recognizedText.text);
          fullText.writeln();
          
          if (tempFile.existsSync()) await tempFile.delete();
        }
        await page.close();
      }
      
      await document.close();
      await textRecognizer.close();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OcrResultScreen(text: fullText.toString()),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("OCR extraction error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to extract text: $e")),
        );
      }
    }
  }

  Future<void> _performOCR(Uint8List imageBytes) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_temp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFile(tempFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      await textRecognizer.close();
      if (tempFile.existsSync()) await tempFile.delete();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OcrResultScreen(text: recognizedText.text),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("OCR Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OCR failed: $e")),
        );
      }
    }
  }

  void _showPremiumDialog({required String title, required String message, bool showAdOption = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 8),
            const Text("🚀"),
          ],
        ),
        content:        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text("Premium Benefits:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _buildBenefitRow(Icons.check_circle, "Unlimited Document Scans"),
            _buildBenefitRow(Icons.check_circle, "Merge & Organize PDFs"),
            _buildBenefitRow(Icons.check_circle, "Advanced PDF Editing & Signing"),
            _buildBenefitRow(Icons.check_circle, "Cloud Backup & Sync"),
            _buildBenefitRow(Icons.check_circle, "Ad-Free Experience"),
            if (showAdOption) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRewardedAd(() async {
                    setState(() {
                      _scanCount--; // Grant 1 extra scan
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('scan_count', _scanCount);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reward Earned: 1 Extra Scan Granted! 🎁")));
                  });
                },
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("Watch Video (+1 Scan)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _signInWithGoogle();
            },
            icon: const Icon(Icons.login),
            label: const Text("Continue with Google"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: "ca-app-pub-8899181087292094/6949058517", // Production ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("Banner Ad Loaded successfully.");
          setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("Banner Ad Failed to Load: $error");
          ad.dispose();
          _isAdLoaded = false;
        },
        onAdOpened: (ad) => debugPrint("Banner Ad Opened."),
        onAdClosed: (ad) => debugPrint("Banner Ad Closed."),
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: "ca-app-pub-8899181087292094/2326241043", // Production ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("Interstitial Ad Loaded successfully.");
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint("Interstitial Ad Failed to Load: $error");
          _isInterstitialReady = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) => debugPrint("Interstitial Ad Showed."),
        onAdDismissedFullScreenContent: (ad) {
          debugPrint("Interstitial Ad Dismissed.");
          ad.dispose();
          _loadInterstitialAd(); // Reload after showing
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint("Interstitial Ad Failed to Show: $error");
          ad.dispose();
          _loadInterstitialAd(); // Reload after failed show
        },
      );
      _interstitialAd!.show();
      _isInterstitialReady = false;
      _interstitialAd = null;
    } else {
      debugPrint("Interstitial Ad not ready yet. Attempting to load...");
      _loadInterstitialAd(); // Try to load if not ready
    }
  }

  Future<Uint8List> _compressImage(Uint8List list) async {
    return await FlutterImageCompress.compressWithList(
      list,
      minHeight: 1920,
      minWidth: 1080,
      quality: 80,
    );
  }

  void _clearTempImages() {
    for (var path in _scannedImagePaths) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    setState(() {
      _scannedImagePaths.clear();
    });
  }

  Future<void> savePdfPaths() async {
    // We are now using Hive for persistence
  }

  Future<void> loadPdfPaths() async {
    setState(() => _isLoadingPdfs = true);
    try {
      final files = await StorageService.getAllPdfs();
      if (mounted) {
        setState(() {
          pdfFiles = files;
          sortByDate();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPdfs = false);
      }
    }
  }



  Future<void> _scanDocument(BuildContext context) async {
    if (_isProcessingScan) return;

    if (!_isLoggedIn && _scanCount >= _maxGuestScans) {
      _showPremiumDialog(
        title: "Limit Reached",
        message: "Guest limit reached! Login with Google for unlimited scans or watch a video to get one more.",
        showAdOption: true,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isProcessingScan = true;
      _scannedImagePaths.clear();
    });

    try {
      while (mounted) {
        final tempDir = await getTemporaryDirectory();
        final String savePath = '${tempDir.path}/scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
        
        // Use EdgeDetection for auto-crop and perspective fix
        bool success = await EdgeDetection.detectEdge(
          savePath,
          canUseGallery: true,
          androidScanTitle: 'Scanning',
        );

        if (!success || !mounted) {
          if (_scannedImagePaths.isEmpty) break;
          // If we already have images, don't just break, maybe user just canceled the "add more"
          break; 
        }

        setState(() {
          _scannedImagePaths.add(savePath);
        });

        // Show professional preview with filters
        final dynamic action = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanPreviewScreen(
              allImagePaths: List.from(_scannedImagePaths),
              initialPage: _scannedImagePaths.length - 1,
            ),
          ),
        );

        if (!mounted) break;

        final actionName = action is Map ? action['action'] : action;
        final ScanFilter filterType = action is Map ? action['filter'] : ScanFilter.natural;

        if (actionName == 'add_more') {
          await Future.delayed(const Duration(milliseconds: 500));
          continue; 
        } else if (actionName == 'save_pdf') {
          await _generatePDF(context, filter: filterType);
          break;
        } else if (actionName.toString().startsWith('ocr_')) {
          int pageIndex = int.parse(actionName.toString().split('_')[1]);
          final imageBytes = await File(_scannedImagePaths[pageIndex]).readAsBytes();
          await _performOCR(imageBytes);
          _clearTempImages();
          break;
        } else {
          _clearTempImages();
          break;
        }
      }
    } catch (e) {
      debugPrint("Scan error: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    }
  }

  Future<void> _generatePDF(BuildContext context, {ScanFilter filter = ScanFilter.natural}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      for (var path in _scannedImagePaths) {
        Uint8List imgBytes = await File(path).readAsBytes();
        
        // Apply actual image processing for filters
        if (filter != ScanFilter.natural) {
          final decodedImage = img.decodeImage(imgBytes);
          if (decodedImage != null) {
            img.Image processed;
            switch (filter) {
              case ScanFilter.document:
                processed = img.grayscale(decodedImage);
                processed = img.adjustColor(processed, contrast: 1.5, brightness: 0.9);
                break;
              case ScanFilter.gray:
                processed = img.grayscale(decodedImage);
                break;
              case ScanFilter.eco:
                processed = img.adjustColor(decodedImage, contrast: 1.2, brightness: 1.1);
                break;
              default:
                processed = decodedImage;
            }
            imgBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
          }
        } else {
          imgBytes = await _compressImage(imgBytes);
        }

        final image = pw.MemoryImage(imgBytes);
        pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Image(image))));
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      final fileName = await _showFileNameDialog(context);
      if (fileName == null || fileName.trim().isEmpty) {
        _clearTempImages();
        return;
      }

      final folder = await StorageService.getPdfDirectory();
      final file = File("${folder.path}/$fileName.pdf");
      await file.writeAsBytes(await pdf.save());

      _clearTempImages();
      
      await StorageService.saveDocumentPath(file.path);
      await loadPdfPaths();

      // Auto-sync for logged in users
      if (_isLoggedIn) {
        cloudService.uploadPdf(file);
      }

      await _incrementScanCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved to Documents 📂")),
        );
        // Show interstitial ad after PDF is successfully created
        _showInterstitialAd();
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error generating PDF: $e");
    }
  }

  Future<void> _pickMultipleImages(BuildContext context) async {
    if (!_isLoggedIn && _scanCount >= _maxGuestScans) {
      _showPremiumDialog(
        title: "Limit Reached",
        message: "Guest limit reached! Login with Google to import more images or watch a video to get one more.",
        showAdOption: true,
      );
      return;
    }
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      if (!mounted) return;
      final dynamic result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewScreen(images: images),
        ),
      );

      if (result != null && result is File) {
        await StorageService.saveDocumentPath(result.path);
        await loadPdfPaths();
        
        // Auto-sync for logged in users
        if (_isLoggedIn) {
          cloudService.uploadPdf(result);
        }

        await _incrementScanCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Created Successfully ✅")));
          _showInterstitialAd();
        }
      }
    }
  }

  Future<void> _pickAndMergePDFs(BuildContext context) async {
    if (!_isLoggedIn) {
      _showPremiumDialog(
        title: "Import & Merge",
        message: "Importing and merging external PDFs is a premium feature. Login to unlock! 🚀",
      );
      return;
    }

    // Modern selection: Allow choosing from Recent or Device
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Merge Documents", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildActionItem(
              context,
              icon: Icons.history_rounded,
              title: "Select from Recent",
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                   _selectedIndex = 2; // Go to Recent tab
                   isSelectionMode = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select PDFs from the list to merge")));
              },
            ),
            _buildActionItem(
              context,
              icon: Icons.phone_android_rounded,
              title: "Import from Device",
              color: Colors.orange,
              onTap: () async {
                Navigator.pop(context);
                _importAndMerge(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importAndMerge(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (!context.mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final selectedFiles = result.paths.map((path) => File(path!)).toList();
      _openMergePreview(context, selectedFiles);
    }
  }

  void _openMergePreview(BuildContext context, List<File> files) async {
    final dynamic mergedFile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MergePreviewScreen(pdfs: files),
      ),
    );

    if (mergedFile != null && mergedFile is File) {
      setState(() {
        isSelectionMode = false;
        selectedPaths.clear();
      });
      await StorageService.saveDocumentPath(mergedFile.path);
      await loadPdfPaths();

      if (_isLoggedIn) {
        cloudService.uploadPdf(mergedFile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDFs Merged Successfully ✅")));
        _showInterstitialAd();
      }
    }
  }

  Future<void> mergeSelectedPDFs(BuildContext context) async {
    if (!_isLoggedIn) {
      _showPremiumDialog(
        title: "Merge PDF",
        message: "Merging multiple documents is a premium feature. Login to unlock! 🚀",
      );
      return;
    }
    
    final selectedFiles = selectedPaths.map((path) => File(path)).toList();

    if (selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 2 PDFs to merge")));
      return;
    }

    if (!mounted) return;
    final dynamic mergedFile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MergePreviewScreen(pdfs: selectedFiles),
      ),
    );

    if (mergedFile != null && mergedFile is File) {
      setState(() {
        isSelectionMode = false;
        selectedPaths.clear();
      });
      await StorageService.saveDocumentPath(mergedFile.path);
      await loadPdfPaths();

      if (_isLoggedIn) {
        cloudService.uploadPdf(mergedFile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDFs Merged Successfully ✅")));
        _showInterstitialAd();
      }
    }
  }

  void _bulkMoveToFolder(BuildContext context) async {
    if (selectedPaths.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Move Selected to Folder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...["Uncategorized", "Work", "Personal", "Legal", "Medical", "Receipts"].map((folder) => ListTile(
              leading: const Icon(Icons.folder_outlined, color: Color(0xFF4F46E5)),
              title: Text(folder),
              onTap: () async {
                for (var path in selectedPaths) {
                  await StorageService.updateDocumentFolder(path, folder);
                }
                if (mounted) {
                  setState(() {
                    isSelectionMode = false;
                    selectedPaths.clear();
                  });
                  Navigator.pop(context);
                  await loadPdfPaths();
                  // Force a UI refresh for the Documents screen if it's currently being shown
                  // by reloading paths and rebuilding.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Moved items to $folder")),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<String?> _showFileNameDialog(BuildContext context, {String? initial}) async {
    TextEditingController controller = TextEditingController(text: initial ?? "scan_${DateTime.now().millisecondsSinceEpoch}");
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save PDF"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "File name", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("Save")),
        ],
      ),
    );
  }

  String _currentLanguage = "English";
  final List<Map<String, String>> _languages = [
    {"name": "English", "code": "en", "flag": "🇺🇸"},
    {"name": "Spanish", "code": "es", "flag": "🇪🇸"},
    {"name": "French", "code": "fr", "flag": "🇫🇷"},
    {"name": "German", "code": "de", "flag": "🇩🇪"},
    {"name": "Hindi", "code": "hi", "flag": "🇮🇳"},
  ];

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Language", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final lang = _languages[index];
              final isSelected = _currentLanguage == lang['name'];
              return ListTile(
                leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                title: Text(lang['name']!, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4F46E5) : null,
                )),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5)) : null,
                onTap: () {
                  setState(() {
                    _currentLanguage = lang['name']!;
                  });
                  Navigator.pop(context);
                  // Trigger UI rebuild or localization change here if using a localization package
                  // For now, we force a rebuild of the entire app to reflect changes if necessary
                  (context as Element).markNeedsBuild(); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Language changed to ${_currentLanguage}")),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void sortByName() {
    setState(() {
      pdfFiles.sort((a, b) => a.path.split(Platform.pathSeparator).last.toLowerCase().compareTo(b.path.split(Platform.pathSeparator).last.toLowerCase()));
    });
  }

  void sortByDate() {
    setState(() {
      pdfFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    });
  }

  Widget _homeUI() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _homeScrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPremiumHeader(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Quick Actions",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 20),
                      _buildBentoGrid(),
                    ],
                  ),
                ),
                _buildRecentSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLoggedIn ? "Welcome back," : "Hello,",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isLoggedIn ? user?.displayName?.split(' ').first ?? "User" : "Guest User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (!_isLoggedIn)
                TextButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login, color: Colors.white, size: 18),
                  label: const Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ScaleButton(
            onTap: () {}, // Trigger Premium Flow
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Get Premium Access",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.5), size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid() {
    return Column(
      children: [
        _buildBentoCard(
          context: context,
          title: "Scan Document",
          subtitle: "Camera detection",
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFF6366F1),
          isLarge: true,
          onTap: () => _scanDocument(context),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "Images to PDF",
                subtitle: "Convert batch",
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _pickMultipleImages(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "Merge PDFs",
                subtitle: "Combine files",
                icon: Icons.merge_type_rounded,
                color: const Color(0xFFF59E0B),
                isLocked: !_isLoggedIn,
                onTap: () {
                  if (!_isLoggedIn) {
                    _showPremiumDialog(
                      title: "Unlock Merge",
                      message: "Merging multiple PDFs is a premium feature. Login to unlock! 🚀",
                    );
                  } else {
                    _pickAndMergePDFs(context);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "Edit & Sign",
                subtitle: "Add text/sig",
                icon: Icons.draw_rounded,
                color: const Color(0xFF8B5CF6),
                isLocked: !_isLoggedIn,
                onTap: () {
                  if (!_isLoggedIn) {
                    _showPremiumDialog(
                      title: "Edit & Sign",
                      message: "Unlock professional editing and digital signatures. Login to continue! 🚀",
                    );
                  } else {
                    // Navigate to picker logic (existing)
                    _navigateToPickerForEditing();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "Text (OCR)",
                subtitle: "Scan to text",
                icon: Icons.text_snippet_rounded,
                color: const Color(0xFFEC4899),
                isLocked: !_isLoggedIn,
                onTap: () {
                  if (!_isLoggedIn) {
                    _showPremiumDialog(
                      title: "OCR Feature",
                      message: "Extract text from images using AI. Login to unlock! 🚀",
                    );
                  } else {
                    _extractTextFromSelected(context);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "Compress PDF/Images",
                subtitle: "Reduce size",
                icon: Icons.compress_rounded,
                color: const Color(0xFF06B6D4),
                isNew: true,
                isLocked: !_isLoggedIn,
                onTap: () {
                  if (!_isLoggedIn) {
                    _showPremiumDialog(
                      title: "Compress PDF/Images",
                      message: "Unlock PDF and image compression feature. Login to continue! 🚀",
                    );
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CompressionScreen()));
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBentoCard(
                context: context,
                title: "QR Scanner",
                subtitle: "Scan codes",
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFFF43F5E),
                isNew: true,
                isLocked: !_isLoggedIn,
                onTap: () {
                  if (!_isLoggedIn) {
                    _showPremiumDialog(
                      title: "QR Scanner",
                      message: "Unlock QR and Barcode scanning. Login to continue! 🚀",
                    );
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen()));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToPickerForEditing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentPickerScreen(
          title: "Select PDF to Edit",
          onFileSelected: (file) async {
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );

            try {
              File fileToEdit = file;
              if (file.path.toLowerCase().endsWith('.pdf')) {
                final document = await pdfx.PdfDocument.openFile(file.path);
                final page = await document.getPage(1);
                final pageImage = await page.render(
                  width: page.width * 2,
                  height: page.height * 2,
                  format: pdfx.PdfPageImageFormat.jpeg,
                  quality: 100,
                );

                final tempDir = await getTemporaryDirectory();
                final tempFile = File(
                    '${tempDir.path}/edit_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
                await tempFile.writeAsBytes(pageImage!.bytes);

                fileToEdit = tempFile;
                await page.close();
                await document.close();
              }

              if (!mounted) return;
              Navigator.pop(context);

              final dynamic result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditPdfScreen(imageFile: fileToEdit)));

              if (result != null && result is File && mounted) {
                await StorageService.saveDocumentPath(result.path);
                await loadPdfPaths();
                _showInterstitialAd();
              }
            } catch (e) {
              if (mounted) Navigator.pop(context);
              debugPrint("Preparation error: $e");
            }
          },
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Documents",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                child: const Text("See All"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _recentUI(isHome: true),
        ],
      ),
    );
  }

  Widget _buildGlassMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isLocked = false,
    bool isNew = false,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2));

    return ScaleButton(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          if (isLocked)
            Positioned(
              right: 15,
              top: 15,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                child: const Icon(Icons.lock, color: Colors.white, size: 14),
              ),
            ),
          if (isNew)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentUI({bool isHome = false}) {
    if (_isLoadingPdfs) {
      return ListView.builder(
        shrinkWrap: isHome,
        padding: isHome ? EdgeInsets.zero : const EdgeInsets.all(10),
        itemCount: 3,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.2),
          highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (pdfFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 80,
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "No Documents Yet",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your scanned PDFs will appear here.\nStart by tapping 'Scan Document' above.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: isHome ? EdgeInsets.zero : const EdgeInsets.all(10),
      shrinkWrap: isHome,
      physics: isHome ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      itemCount: isHome ? (pdfFiles.length > 5 ? 5 : pdfFiles.length) : pdfFiles.length,
      itemBuilder: (context, index) {
        final file = pdfFiles[index];
        final isSelected = selectedPaths.contains(file.path);
        final stats = file.statSync();
        final size = (stats.size / 1024).toStringAsFixed(1);
        final fileName = file.path.split(Platform.pathSeparator).last;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ScaleButton(
            onTap: () async {
              if (isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    selectedPaths.remove(file.path);
                    if (selectedPaths.isEmpty) isSelectionMode = false;
                  } else {
                    selectedPaths.add(file.path);
                  }
                });
              } else {
                _viewPDF(file);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (val) {
                          setState(() {
                            if (val!) {
                              selectedPaths.add(file.path);
                            } else {
                              selectedPaths.remove(file.path);
                              if (selectedPaths.isEmpty) isSelectionMode = false;
                            }
                          });
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 24),
                      ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isLoggedIn)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('pdfs')
                            .doc(fileName)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final isSynced = snapshot.hasData && snapshot.data!.exists;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined,
                              key: ValueKey(isSynced),
                              color: isSynced ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.5),
                              size: 16,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "$size KB • ${stats.modified.day}/${stats.modified.month}/${stats.modified.year}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                trailing: isSelectionMode
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                        onPressed: () => _showDocumentActions(context, file, index),
                      ),
                onLongPress: () {
                  setState(() {
                    isSelectionMode = true;
                    selectedPaths.add(file.path);
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewPDF(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(file.path.split(Platform.pathSeparator).last),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => Share.shareXFiles([XFile(file.path)]),
              ),
            ],
          ),
          body: SfPdfViewer.file(file),
        ),
      ),
    );
  }

  void _showDocumentActions(BuildContext context, File file, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.path.split(Platform.pathSeparator).last,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "PDF Document • ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildActionItem(
                  context,
                  icon: Icons.visibility_rounded,
                  title: "View Document",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _viewPDF(file);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.edit_rounded,
                  title: "Edit & Sign",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _editAndSignDocument(file);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.drive_file_move_rounded,
                  title: "Move to Folder",
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveToFolderDialog(file);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.share_rounded,
                  title: "Share PDF",
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    Share.shareXFiles([XFile(file.path)]);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.download_rounded,
                  title: "Save to Device",
                  color: Colors.teal,
                  onTap: () async {
                    Navigator.pop(context);
                    await _saveToDevice(file);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: "Rename",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _renameDocument(file);
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.delete_outline_rounded,
                  title: "Delete",
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteDocument(file, index);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(File file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Move to Folder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...["Uncategorized", "Work", "Personal", "Legal", "Medical", "Receipts"].map((folder) => ListTile(
              leading: const Icon(Icons.folder_outlined, color: Color(0xFF4F46E5)),
              title: Text(folder),
              onTap: () async {
                await StorageService.updateDocumentFolder(file.path, folder);
                Navigator.pop(context);
                loadPdfPaths();
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: title == "Delete" ? Colors.red : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
    );
  }

  Future<void> _saveToDevice(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // For Android 11+, we typically use the Downloads folder or external storage
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
           downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception("Could not find downloads directory");
      }

      final String newPath = "${downloadsDir.path}/$fileName";
      final File newFile = File(newPath);
      
      await file.copy(newPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved to Downloads: $fileName"),
            action: SnackBarAction(label: "Open", onPressed: () {
               // Optional: open the file
            }),
          ),
        );
      }
    } catch (e) {
      if (Platform.isIOS) {
        await Share.shareXFiles([XFile(file.path)], subject: "Export PDF");
      } else {
        debugPrint("Save to device error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save: $e")),
          );
        }
      }
    }
  }

  Future<void> _editAndSignDocument(File file) async {
    if (!_isLoggedIn) {
      _showPremiumDialog(
        title: "Premium Feature",
        message: "Editing and Signing is reserved for premium users. Login to unlock! 🚀",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      File fileToEdit = file;
      if (file.path.toLowerCase().endsWith('.pdf')) {
        final document = await pdfx.PdfDocument.openFile(file.path);
        final page = await document.getPage(1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 100,
        );

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/edit_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(pageImage!.bytes);

        fileToEdit = tempFile;
        await page.close();
        await document.close();
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final dynamic result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditPdfScreen(imageFile: fileToEdit))
      );

      if (result != null && result is File && mounted) {
        await StorageService.saveDocumentPath(result.path);
        await loadPdfPaths();
        _showInterstitialAd();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Preparation error: $e");
    }
  }

  Future<void> _renameDocument(File file) async {
    String currentName = file.path.split(Platform.pathSeparator).last.replaceAll(".pdf", "");
    TextEditingController controller = TextEditingController(text: currentName);

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Document"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "New Name",
            suffixText: ".pdf",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Rename")),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        String newName = controller.text.trim();
        if (!newName.endsWith(".pdf")) newName += ".pdf";
        
        String newPath = file.parent.path + Platform.pathSeparator + newName;
        
        if (await File(newPath).exists()) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A file with this name already exists")));
           return;
        }

        await file.rename(newPath);
        
        // Update storage and UI
        await StorageService.removeDocumentPath(file.path);
        await StorageService.saveDocumentPath(newPath);
        await loadPdfPaths();
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renamed successfully")));
      } catch (e) {
        debugPrint("Rename error: $e");
      }
    }
  }

  Future<void> _deleteDocument(File file, int index) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete PDF?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      if (FirebaseAuth.instance.currentUser != null) {
        await cloudService.deleteFromCloud(file.path.split(Platform.pathSeparator).last);
      }

      await StorageService.removeDocumentPath(file.path);

      if (await file.exists()) {
        await file.delete();
      }

      setState(() => pdfFiles.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully 🗑️")));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          isSelectionMode ? "${selectedPaths.length} Selected" : "PDF Scanner Pro",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isSelectionMode) ...[
            IconButton(icon: const Icon(Icons.drive_file_move_rounded), onPressed: () => _bulkMoveToFolder(context)),
            IconButton(icon: const Icon(Icons.merge_type), onPressed: () => mergeSelectedPDFs(context))
          ] else ...[
            IconButton(icon: const Icon(Icons.translate_rounded), onPressed: _showLanguageDialog),
            IconButton(
                icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => widget.onThemeChanged(widget.themeMode != ThemeMode.dark)),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
          ]
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _selectedIndex == 0 ? _homeUI() : (_selectedIndex == 1 ? DocumentsScreen(
                isSelectionMode: isSelectionMode,
                selectedPaths: selectedPaths,
                onSelectionModeChanged: (val) => setState(() => isSelectionMode = val),
                onSelectionChanged: (val) => setState(() => selectedPaths = val),
              ) : _recentUI())),
              if (_isAdLoaded && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
          if (_selectedIndex == 0 && _blinkController.isAnimating)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: FadeTransition(
                  opacity: _blinkAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: "move_bulk",
                  onPressed: () => _bulkMoveToFolder(context),
                  icon: const Icon(Icons.drive_file_move),
                  label: const Text("Move"),
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: "merge_bulk",
                  onPressed: () => mergeSelectedPDFs(context),
                  icon: const Icon(Icons.merge_type),
                  label: const Text("Merge"),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ],
            )
          : (_selectedIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () => _scanDocument(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Scan New"),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                )
              : null),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2) {
              loadPdfPaths();
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Documents"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Recent"),
        ],
      ),
    );
  }
}

class DocumentsScreen extends StatefulWidget {
  final bool isSelectionMode;
  final Set<String> selectedPaths;
  final Function(bool) onSelectionModeChanged;
  final Function(Set<String>) onSelectionChanged;

  const DocumentsScreen({
    super.key,
    required this.isSelectionMode,
    required this.selectedPaths,
    required this.onSelectionModeChanged,
    required this.onSelectionChanged,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<File> pdfList = [];
  List<File> filteredList = [];
  Map<String, List<File>> groupedFiles = {};
  List<String> folders = ["Uncategorized", "Work", "Personal", "Legal", "Medical", "Receipts"];
  String selectedFolder = "All";
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final CloudService _cloudService = CloudService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPdfs();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredList = pdfList.where((file) {
        final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
        final matchesQuery = fileName.contains(query);
        
        if (selectedFolder == "All") return matchesQuery;
        
        // Use cached metadata
        return matchesQuery && _folderCache[file.path] == selectedFolder;
      }).toList();
    });
  }

  Map<String, String> _folderCache = {};

  Future<void> _loadPdfs() async {
    setState(() => isLoading = true);
    try {
      final files = await StorageService.getAllPdfs();
      
      // Pre-cache folders
      Map<String, String> cache = {};
      for (var file in files) {
        cache[file.path] = await StorageService.getDocumentFolder(file.path);
      }

      setState(() {
        pdfList = files;
        _folderCache = cache;
        filteredList = files;
        isLoading = false;
        _filterDocuments();
      });
    } catch (e) {
      debugPrint("Error loading PDFs: $e");
      setState(() => isLoading = false);
    }
  }

  void _createNewFolder() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("New Folder"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Folder Name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    if (!folders.contains(controller.text)) {
                      folders.add(controller.text);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  void _showMoveToFolderDialog(File file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Move to Folder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...folders.map((folder) => ListTile(
              leading: const Icon(Icons.folder_outlined, color: Color(0xFF4F46E5)),
              title: Text(folder),
              onTap: () async {
                await StorageService.updateDocumentFolder(file.path, folder);
                Navigator.pop(context);
                _loadPdfs();
              },
            )),
          ],
        ),
      ),
    );
  }


  void _confirmDelete(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete PDF"),
        content: const Text("Are you sure you want to delete this file?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (await file.exists()) {
                await file.delete();
                // Remove from SharedPreferences/Hive if necessary, 
                // for now simple removal from storage and reloading the list
                await StorageService.removeDocumentPath(file.path);
              }
              if (mounted) {
                Navigator.pop(context);
                _loadPdfs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Deleted successfully 🗑️")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(icon: Icon(Icons.phone_android), text: "Local"),
              Tab(icon: Icon(Icons.cloud_outlined), text: "Cloud"),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                hintText: "Search your documents...",
                hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4F46E5), size: 22),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18), 
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    ) 
                  : null,
                filled: true,
                fillColor: Theme.of(context).cardTheme.color,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLocalList(),
              _buildCloudList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLocalList() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFolderChip("All"),
              ...folders.map((f) => _buildFolderChip(f)),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  onPressed: _createNewFolder,
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredList.isEmpty ? _buildEmptyState() : _buildFileList(),
        ),
      ],
    );
  }

  Widget _buildFolderChip(String label) {
    bool isSelected = selectedFolder == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (val) {
          setState(() {
            selectedFolder = label;
          });
          _filterDocuments();
        },
        selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        checkmarkColor: const Color(0xFF4F46E5),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 80,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? "No documents in $selectedFolder"
                : "No results for \"${_searchController.text}\"",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return RefreshIndicator(
      onRefresh: _loadPdfs,
      color: const Color(0xFF4F46E5),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final file = filteredList[index];
          final stats = file.statSync();
          final size = (stats.size / 1024).toStringAsFixed(1);
          final fileName = file.path.split(Platform.pathSeparator).last;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScaleButton(
              onLongPress: () {
                widget.onSelectionModeChanged(true);
                final newSelection = Set<String>.from(widget.selectedPaths);
                newSelection.add(file.path);
                widget.onSelectionChanged(newSelection);
              },
              onTap: () {
                if (widget.isSelectionMode) {
                  final newSelection = Set<String>.from(widget.selectedPaths);
                  if (newSelection.contains(file.path)) {
                    newSelection.remove(file.path);
                    if (newSelection.isEmpty) widget.onSelectionModeChanged(false);
                  } else {
                    newSelection.add(file.path);
                  }
                  widget.onSelectionChanged(newSelection);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(fileName)),
                        body: SfPdfViewer.file(file),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.selectedPaths.contains(file.path)
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                      : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.selectedPaths.contains(file.path)
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: widget.isSelectionMode
                      ? Checkbox(
                          value: widget.selectedPaths.contains(file.path),
                          activeColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (val) {
                            final newSelection = Set<String>.from(widget.selectedPaths);
                            if (val == true) {
                              newSelection.add(file.path);
                            } else {
                              newSelection.remove(file.path);
                              if (newSelection.isEmpty) widget.onSelectionModeChanged(false);
                            }
                            widget.onSelectionChanged(newSelection);
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 24),
                        ),
                  title: Text(
                    fileName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _folderCache[file.path] ?? "Uncategorized",
                            style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$size KB • ${stats.modified.day}/${stats.modified.month}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  trailing: widget.isSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_rounded, color: Color(0xFF4F46E5), size: 20),
                              onPressed: () => Share.shareXFiles([XFile(file.path)]),
                            ),
                            IconButton(
                              icon: const Icon(Icons.drive_file_move_outlined, color: Color(0xFF64748B), size: 20),
                              onPressed: () => _showMoveToFolderDialog(file),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildCloudList() {
    if (FirebaseAuth.instance.currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Login to access Cloud Library", style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text("Go to Login"),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _cloudService.getCloudPdfsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No documents in the cloud ☁️", style: TextStyle(color: Colors.grey, fontSize: 18)),
          );
        }

        final cloudDocs = snapshot.data!.docs.where((doc) {
          final name = (doc.data() as Map<String, dynamic>)['name'] as String;
          return name.toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
          itemCount: cloudDocs.length,
          itemBuilder: (context, index) {
            final data = cloudDocs[index].data() as Map<String, dynamic>;
            final name = data['name'];
            final url = data['url'];
            
            bool isDownloaded = pdfList.any((file) => file.path.endsWith(name));

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.cloud_done, color: Colors.blue, size: 36),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Available in Cloud"),
                trailing: isDownloaded
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.download, color: Colors.blue),
                        onPressed: () => _downloadFromCloud(name, url),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadFromCloud(String name, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dio = await _downloadFile(url, name);
      if (dio != null) {
        await StorageService.saveDocumentPath(dio.path);
        await _loadPdfs();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name downloaded successfully! ✅")));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
      }
    }
  }

  Future<File?> _downloadFile(String url, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folder = Directory('${directory.path}/PDFScannerPro');
      if (!await folder.exists()) await folder.create(recursive: true);
      
      final filePath = '${folder.path}/$fileName';
      final file = File(filePath);

      final response = await HttpClient().getUrl(Uri.parse(url));
      final request = await response.close();
      await request.pipe(file.openWrite());
      
      return file;
    } catch (e) {
      debugPrint("Download error: $e");
      return null;
    }
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoggedIn)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null ? const Icon(Icons.person, size: 50) : null,
                )
              else
                const Icon(Icons.account_circle, size: 100, color: Colors.grey),
              
              const SizedBox(height: 20),
              Text(
                isLoggedIn ? user.displayName ?? "User" : "Guest User",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (isLoggedIn) Text(user.email ?? "", style: const TextStyle(color: Colors.grey)),
              
              const SizedBox(height: 40),
              if (!isLoggedIn)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  icon: const Icon(Icons.login),
                  label: const Text("Login with Google to Sync"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await GoogleSignIn().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
