import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/scale_button.dart';
import 'services/storage_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly (Most Popular)

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Monthly',
      'price': '\$4.99',
      'period': '/ month',
      'description': 'Basic flexibility',
      'color': Colors.blue,
    },
    {
      'title': 'Yearly',
      'price': '\$29.99',
      'period': '/ year',
      'description': 'Best Value - 50% Off',
      'isPopular': true,
      'color': const Color(0xFF4F46E5),
    },
    {
      'title': 'Lifetime',
      'price': '\$59.99',
      'period': 'once',
      'description': 'One-time payment',
      'color': Colors.amber.shade700,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        "GO PREMIUM",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "Unlock all professional features",
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureSection(),
                  const SizedBox(height: 32),
                  Text(
                    "Select a Plan",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_plans.length, (index) => _buildPlanCard(index)),
                  const SizedBox(height: 32),
                  _buildSubscribeButton(),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Recurring billing. Cancel anytime.",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection() {
    final features = [
      {'icon': Icons.block_rounded, 'text': 'No Ads - Zero Distractions'},
      {'icon': Icons.cloud_upload_rounded, 'text': 'Unlimited Cloud Storage'},
      {'icon': Icons.text_fields_rounded, 'text': 'Advanced OCR (Text Extraction)'},
      {'icon': Icons.merge_type_rounded, 'text': 'Merge & Edit Unlimited PDFs'},
      {'icon': Icons.lock_outline_rounded, 'text': 'Password Protection'},
      {'icon': Icons.verified_rounded, 'text': 'HD Quality Scanning'},
    ];

    return Column(
        children: features.map((feature) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(feature['icon'] as IconData, color: const Color(0xFF4F46E5), size: 18),
            ),
            const SizedBox(width: 16),
            Text(
              feature['text'] as String,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isSelected = _selectedPlanIndex == index;
    final isPopular = plan['isPopular'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ScaleButton(
        onTap: () => setState(() => _selectedPlanIndex = index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.2),
              width: 2,
            ),
            color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.05) : Colors.white,
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF4F46E5) : null,
                          ),
                        ),
                        if (isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "BEST VALUE",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                    Text(
                      plan['description'],
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan['price'],
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF4F46E5) : null,
                    ),
                  ),
                  Text(
                    plan['period'],
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return ScaleButton(
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Simulate payment processing
        await Future.delayed(const Duration(seconds: 2));
        await StorageService.setPremium(true);

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Premium Activated! Welcome to the Pro Club 🚀"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "CONTINUE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
