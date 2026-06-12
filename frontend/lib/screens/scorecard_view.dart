import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class ScorecardView extends StatefulWidget {
  final bool isNepali;
  const ScorecardView({super.key, required this.isNepali});

  @override
  State<ScorecardView> createState() => _ScorecardViewState();
}

class _ScorecardViewState extends State<ScorecardView> {
  List<Map<String, dynamic>> _scorecards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScorecards();
  }

  Future<void> _loadScorecards() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final list = await firebaseService.fetchInstitutionalScorecards();
    
    // Sort descending by risk score
    list.sort((a, b) => (b['risk_score'] ?? 0).compareTo(a['risk_score'] ?? 0));

    if (mounted) {
      setState(() {
        _scorecards = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Card 1: Scorecard meters
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isNepali ? "📊 कार्यालय स्कोरकार्ड" : "📊 Institutional Scorecard",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () {
                        setState(() => _loading = true);
                        _loadScorecards();
                      },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_scorecards.isEmpty)
                  const Text("No scorecard records available.", style: TextStyle(color: Colors.white38))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _scorecards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final card = _scorecards[index];
                      final name = widget.isNepali ? (card['name_np'] ?? card['institution']) : card['institution'];
                      final score = card['risk_score'] ?? 0;
                      final count = card['total_reports'] ?? 0;
                      final level = card['risk_level'] ?? "Low";
                      
                      Color accentColor = const Color(0xFF10B981);
                      if (score >= 80) {
                        accentColor = const Color(0xFFEF4444);
                      } else if (score >= 60) {
                        accentColor = const Color(0xFFF59E0B);
                      } else if (score >= 35) {
                        accentColor = const Color(0xFF06B6D4);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, py: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  border: Border.all(color: accentColor.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$level",
                                  style: TextStyle(fontSize: 9, color: accentColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: score / 100.0,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$count reports submitted",
                                style: const TextStyle(fontSize: 10, color: Colors.white38),
                              ),
                              Text(
                                "Risk Score: $score",
                                style: const TextStyle(fontSize: 10, color: Colors.white38),
                              ),
                            ],
                          )
                        ],
                      );
                    },
                  )
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Card 2: Live disclosures
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNepali ? "📢 भर्खरै गरिएका अज्ञात खुलासाहरू" : "📢 Live Anonymous Disclosures",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                // Active disclosures list
                _buildDisclosureItem(
                  "Malpot (Land Revenue)",
                  "Kathmandu",
                  "Bribe demanded for land registration mutated service. Officer asked for Rs. 5000 in mutated desk 3.",
                  "2 hrs ago",
                  12,
                ),
                const SizedBox(height: 12),
                _buildDisclosureItem(
                  "Yatayat (Transport Office)",
                  "Lalitpur",
                  "Licensing trial checker asking Rs. 15000 bribe to pass a failed candidate on bike trials.",
                  "4 hrs ago",
                  34,
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDisclosureItem(String dept, String district, String details, String timeAgo, int votes) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$dept ($district)",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
              ),
              Text(timeAgo, style: const TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 6),
          Text(details, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("Verified", style: TextStyle(fontSize: 8, color: Color(0xFFFECACA))),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.thumb_up, size: 10),
                label: Text("$votes"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
