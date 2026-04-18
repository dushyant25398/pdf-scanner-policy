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
import 'package:flutter_document_scanner/flutter_document_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'ocr_result_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
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

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode themeMode;

  const HomeScreen(
      {super.key, required this.onThemeChanged, required this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ImagePicker _picker = ImagePicker();
  List<File> pdfFiles = [];
  final List<String> _scannedImagePaths = [];
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};
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

  @override
  void initState() {
    super.initState();
    loadPdfPaths();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadScanCount();
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
    if (selectedIndexes.isEmpty) {
      if (pdfFiles.isNotEmpty) {
        selectedIndexes.add(0);
      } else {
        return;
      }
    }
    
    // In a real app, we'd extract the first page of the PDF as an image for OCR.
    // For now, since we already have the OCR logic for Uint8List, we'll inform the user.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OCR for existing PDFs coming soon! 🚀 Try it immediately after scanning a new document.")),
    );
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

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
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
        debugPrint("Opening scanner flow. Images so far: ${_scannedImagePaths.length}");
        
        // 1. Open Document Scanner and capture image
        final dynamic action = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (scannerContext) => Scaffold(
              body: DocumentScanner(
                generalStyles: const GeneralStyles(
                  hideDefaultDialogs: true,
                ),
                onSave: (Uint8List imageBytes) async {
                  // 2. Process & SAVE TO DISK immediately
                  final compressed = await _compressImage(imageBytes);
                  final tempDir = await getTemporaryDirectory();
                  final file = File('${tempDir.path}/scan_${DateTime.now().microsecondsSinceEpoch}.jpg');
                  await file.writeAsBytes(compressed);
                  
                  if (!mounted) return;
                  setState(() {
                    _scannedImagePaths.add(file.path);
                  });

                  // TRANSITION TO PREVIEW
                  if (scannerContext.mounted) {
                    final previewAction = await Navigator.of(scannerContext).push(
                      MaterialPageRoute(
                        builder: (context) => ScanPreviewScreen(
                          allImagePaths: List.from(_scannedImagePaths),
                          initialPage: _scannedImagePaths.length - 1,
                        ),
                      ),
                    );
                    
                    if (scannerContext.mounted) {
                      Navigator.of(scannerContext).pop(previewAction);
                    }
                  }
                },
              ),
            ),
          ),
        );

        if (!mounted) break;

        if (action == null) {
          _clearTempImages();
          break;
        }

        // 4. Handle Preview Actions
        if (action == 'add_more') {
          if (!mounted) break;
          // IMPORTANT: Add a slight delay and ensure the scanner has time to dispose 
          // before reopening to prevent "Camera in use" or UI freezes on some devices.
          await Future.delayed(const Duration(milliseconds: 500));
          continue; 
        } else if (action == 'save_pdf') {
          await _generatePDF(context);
          break;
        } else if (action.toString().startsWith('ocr_')) {
          int pageIndex = int.parse(action.toString().split('_')[1]);
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

  // _openPreview is no longer needed with the direct navigation from onSave
  // but we can keep it as a fallback or remove it. Let's remove to clean up.

  Future<Uint8List> _compressImage(Uint8List list) async {
    // Quality 85 is the "Sweet Spot" for professional PDF scanners:
    // It keeps text razor sharp but reduces file size by ~80%.
    // We also set a minWidth/Height to avoid unnecessary 4K+ processing which slows down PDF generation.
    return await FlutterImageCompress.compressWithList(
      list,
      quality: 85,
      minWidth: 1600, 
      minHeight: 2000,
    );
  }

  void _clearTempImages() {
    for (var path in _scannedImagePaths) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    _scannedImagePaths.clear();
  }

  Future<void> _generatePDF(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      for (var path in _scannedImagePaths) {
        final imgBytes = await File(path).readAsBytes();
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (!context.mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final selectedFiles = result.paths.map((path) => File(path!)).toList();
      
      final dynamic mergedFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MergePreviewScreen(pdfs: selectedFiles),
        ),
      );

      if (mergedFile != null && mergedFile is File) {
        isSelectionMode = false;
        selectedIndexes.clear();
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
  }

  Future<void> mergeSelectedPDFs(BuildContext context) async {
    if (!_isLoggedIn) {
      _showPremiumDialog(
        title: "Merge PDF",
        message: "Merging multiple documents is a premium feature. Login to unlock! 🚀",
      );
      return;
    }
    final selectedFiles = <File>[];
    for (var index in selectedIndexes) {
      selectedFiles.add(pdfFiles[index]);
    }

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
      isSelectionMode = false;
      selectedIndexes.clear();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFF2563EB), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isLoggedIn ? "Welcome back," : "Hello,", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    Text(
                      _isLoggedIn ? FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? "User" : "Guest User",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                if (!_isLoggedIn)
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text("Login"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const Text("QUICK ACTIONS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Scan New Document",
              subtitle: "Capture & convert to PDF",
              icon: Icons.camera_alt,
              color: Colors.blue.withValues(alpha: 0.3),
              onTap: () => _scanDocument(context),
            ),
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Create PDF from Images",
              subtitle: "Pick multiple from gallery",
              icon: Icons.photo_library,
              color: Colors.green.withValues(alpha: 0.3),
              onTap: () => _pickMultipleImages(context),
            ),
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Import & Merge PDFs",
              subtitle: "Combine external files",
              icon: Icons.file_open,
              color: Colors.orange.withValues(alpha: 0.3),
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
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Edit & Sign PDF",
              subtitle: "Annotate & sign documents",
              icon: Icons.edit_document,
              color: Colors.purple.withValues(alpha: 0.3),
              isLocked: !_isLoggedIn,
              onTap: () {
                if (!_isLoggedIn) {
                  _showPremiumDialog(
                    title: "Edit & Sign",
                    message: "Unlock professional editing and digital signatures. Login to continue! 🚀",
                  );
                } else {
                  setState(() => _selectedIndex = 1);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a PDF from 'Recent' to edit")));
                  }
                }
              },
            ),
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Cloud Sync & Backup",
              subtitle: "Secure your documents",
              icon: Icons.cloud_done,
              color: Colors.teal.withValues(alpha: 0.3),
              isLocked: !_isLoggedIn,
              onTap: () {
                if (!_isLoggedIn) {
                  _showPremiumDialog(
                    title: "Cloud Sync",
                    message: "Backup your documents to the cloud and access them anywhere. Login to unlock! 🚀",
                  );
                } else {
                  cloudService.syncToCloud(pdfFiles);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing documents to cloud... ☁️")));
                  }
                }
              },
            ),
            const SizedBox(height: 15),
            _buildGlassMenuCard(
              title: "Extract Text (OCR)",
              subtitle: "Convert scans to text",
              icon: Icons.text_snippet,
              color: Colors.indigo.withValues(alpha: 0.3),
              isLocked: !_isLoggedIn,
              onTap: () {
                if (!_isLoggedIn) {
                  _showPremiumDialog(
                    title: "Unlock OCR",
                    message: "Text extraction (OCR) is a premium feature. Login to unlock! 🚀",
                  );
                } else {
                  if (pdfFiles.isNotEmpty) {
                    _extractTextFromSelected(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No documents to extract text from 📂. Scan one first!")),
                    );
                  }
                }
              },
              isNew: true,
            ),
          ],
        ),
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

  Widget _recentUI() {
    if (_isLoadingPdfs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pdfFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded, size: 100, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text("No documents yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            const Text("No documents yet.\nScan to create your first PDF",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: pdfFiles.length,
      itemBuilder: (context, index) {
        final file = pdfFiles[index];
        final isSelected = selectedIndexes.contains(index);
        final stats = file.statSync();
        final size = (stats.size / 1024).toStringAsFixed(1);

        return Card(
          elevation: isSelected ? 8 : 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
          child: ListTile(
            leading: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val!) {
                          selectedIndexes.add(index);
                        } else {
                          selectedIndexes.remove(index);
                          if (selectedIndexes.isEmpty) isSelectionMode = false;
                        }
                      });
                    },
                  )
                : const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Row(
              children: [
                Expanded(child: Text(file.path.split(Platform.pathSeparator).last, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (_isLoggedIn)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('pdfs')
                        .doc(file.path.split(Platform.pathSeparator).last)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        return const Icon(Icons.cloud_done, color: Colors.blue, size: 16);
                      }
                      return const Icon(Icons.cloud_queue, color: Colors.grey, size: 16);
                    },
                  ),
              ],
            ),
            subtitle: Text("$size KB • ${stats.modified.day}/${stats.modified.month}"),
            trailing: isSelectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: "View",
                        onPressed: () {
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
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        tooltip: "Edit",
                        onPressed: () async {
                          if (!_isLoggedIn) {
                            _showPremiumDialog(
                              title: "Premium Feature",
                              message: "Editing and Signing is reserved for premium users. Login to unlock! 🚀",
                            );
                            return;
                          }
                          if (!mounted) return;
                          final dynamic result = await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => EditPdfScreen(imageFile: file))
                          );
                          if (result != null && result is File && mounted) {
                            await StorageService.saveDocumentPath(result.path);
                            await loadPdfPaths();
                            _showInterstitialAd();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.green),
                        tooltip: "Share",
                        onPressed: () => Share.shareXFiles([XFile(file.path)]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Delete",
                        onPressed: () async {
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
                            if (_isLoggedIn) {
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
                        },
                      ),
                    ],
                  ),
            onLongPress: () {
              setState(() {
                isSelectionMode = true;
                selectedIndexes.add(index);
              });
            },
            onTap: () async {
              if (isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    selectedIndexes.remove(index);
                    if (selectedIndexes.isEmpty) isSelectionMode = false;
                  } else {
                    selectedIndexes.add(index);
                  }
                });
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          isSelectionMode ? "${selectedIndexes.length} Selected" : "PDF Scanner Pro",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isSelectionMode)
            IconButton(icon: const Icon(Icons.merge_type), onPressed: () => mergeSelectedPDFs(context))
          else ...[
            IconButton(icon: const Icon(Icons.sort_by_alpha), onPressed: sortByName),
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
      body: Column(
        children: [
          Expanded(child: _selectedIndex == 0 ? _homeUI() : (_selectedIndex == 1 ? const DocumentsScreen() : _recentUI())),
          if (_isAdLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? (isSelectionMode
              ? FloatingActionButton.extended(
                  onPressed: () => mergeSelectedPDFs(context),
                  icon: const Icon(Icons.merge_type),
                  label: const Text("Merge Selected"),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                )
              : FloatingActionButton.extended(
                  onPressed: () => _scanDocument(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Scan New"),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ))
          : null,
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
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> pdfList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    final files = await StorageService.getAllPdfs();
    if (mounted) {
      setState(() {
        pdfList = files;
        isLoading = false;
      });
    }
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

    if (pdfList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              "No documents yet.\nScan to create your first PDF",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPdfs,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: pdfList.length,
        itemBuilder: (context, index) {
          final file = pdfList[index];
          final stats = file.statSync();
          final size = (stats.size / 1024).toStringAsFixed(1);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.path.split(Platform.pathSeparator).last,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (FirebaseAuth.instance.currentUser != null)
                    const Icon(Icons.cloud_queue, color: Colors.grey, size: 16),
                ],
              ),
              subtitle: Text("$size KB • ${stats.modified.day}/${stats.modified.month}/${stats.modified.year}"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text(file.path.split(Platform.pathSeparator).last)),
                      body: SfPdfViewer.file(file),
                    ),
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    onPressed: () => Share.shareXFiles([XFile(file.path)]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(file),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleButton({super.key, required this.child, required this.onTap});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
