import 'package:flutter/material.dart';
import 'report_form.dart';
import 'heatmap_view.dart';
import 'scorecard_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNepali = false;
  String _layoutMode = 'desktop'; // Default to desktop view as requested

  void _toggleLanguage() {
    setState(() {
      _isNepali = !_isNepali;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = _layoutMode == 'desktop' || (_layoutMode == 'auto' && width > 1100);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF08070D).withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              "🔍 ",
              style: TextStyle(fontSize: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? "खुलासा" : "KHULASAA",
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  _isNepali ? "सत्य बोल्नुहोस्। सुरक्षित रहनुहोस्।" : "Speak the Truth. Stay Hidden.",
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Premium Layout Override Dropdown
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _layoutMode,
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Icon(Icons.devices, size: 14, color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF16141F),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _layoutMode = newValue;
                      });
                    }
                  },
                  items: <String>['auto', 'desktop', 'mobile'].map<DropdownMenuItem<String>>((String value) {
                    String label = value == 'auto' 
                        ? (_isNepali ? 'एआई स्वतः' : 'Auto')
                        : value == 'desktop'
                            ? (_isNepali ? 'डेस्कटप' : 'Desktop')
                            : (_isNepali ? 'मोबाइल' : 'Mobile');
                    IconData icon = value == 'auto'
                        ? Icons.brightness_auto
                        : value == 'desktop'
                            ? Icons.desktop_windows
                            : Icons.phone_android;
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 13, color: const Color(0xFF06B6D4)),
                          const SizedBox(width: 6),
                          Text(label),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _toggleLanguage,
              icon: const Icon(Icons.language, size: 16),
              label: Text(_isNepali ? "English" : "🇳🇵 नेपाली"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Mesh glow circles
          Positioned(
            top: -200,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withOpacity(0.04),
              ),
            ),
          ),
          
          // Main layout content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isDesktop 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Anonymous wizard form (isExpanded: true to fill height properly)
                      Expanded(
                        flex: 3,
                        child: ReportForm(isNepali: _isNepali, isExpanded: true),
                      ),
                      const SizedBox(width: 16),
                      
                      // Column 2: Live Heatmap view
                      const Expanded(
                        flex: 5,
                        child: HeatmapView(),
                      ),
                      const SizedBox(width: 16),
                      
                      // Column 3: Live feeds & Scorecard meters (SingleChildScrollView to prevent vertical overflow)
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: ScorecardView(isNepali: _isNepali),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Column layout for mobile view (isExpanded: false to prevent height-constraint layout crash)
                        ReportForm(isNepali: _isNepali, isExpanded: false),
                        const SizedBox(height: 16),
                        const SizedBox(
                          height: 400,
                          child: HeatmapView(),
                        ),
                        const SizedBox(height: 16),
                        ScorecardView(isNepali: _isNepali),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
