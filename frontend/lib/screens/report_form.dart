import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class ReportForm extends StatefulWidget {
  final bool isNepali;
  final bool isExpanded;
  const ReportForm({super.key, required this.isNepali, this.isExpanded = true});

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  int _currentStep = 0;
  
  // Form values
  String? _selectedInstitution;
  String? _selectedDistrict;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bribeController = TextEditingController();
  
  bool _isAnonymous = true;
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  final List<String> _institutions = [
    "Malpot (Land Revenue)",
    "Yatayat (Transport Management)",
    "Nepal Police Office",
    "Customs Department",
    "Internal Revenue Office"
  ];

  final List<String> _districts = [
    "Kathmandu",
    "Lalitpur",
    "Bhaktapur",
    "Kaski",
    "Chitwan",
    "Rupandehi",
    "Morang",
    "Jhapa"
  ];

  @override
  void dispose() {
    _descController.dispose();
    _bribeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedInstitution == null || _selectedDistrict == null || _descController.text.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isNepali ? "कृपया सबै घटना विवरणहरू भर्नुहोस् (कमतिमा १० अक्षर)।" : "Please complete Step 1 details (Min 10 characters description)."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }
    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    setState(() {
      _currentStep--;
    });
  }

  Future<void> _submitReport() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    // Call service to run through ML TF-IDF spam filters and write results
    final result = await firebaseService.submitReport(
      institution: _selectedInstitution!,
      district: _selectedDistrict!,
      description: _descController.text,
      bribeAmount: double.tryParse(_bribeController.text) ?? 0.0,
      latitude: 27.7007, // Default mock latitude
      longitude: 85.3001, // Default mock longitude
    );

    setState(() {
      _isLoading = false;
      _isSuccess = result["success"] == true;
      if (result["success"] == true) {
        if (result["is_duplicate"] == true) {
          _feedbackMessage = widget.isNepali 
              ? "चेतावनी: प्रणालीले पहिले दर्ता भएको उजुरीसँग ${(result['similarity_score'] * 100).toStringAsFixed(0)}% समानता फेला पारेको छ। यो उजुरी ब्लक गरिएको हुन सक्छ।"
              : "Duplicate alert: Neural check detected ${(result['similarity_score'] * 100).toStringAsFixed(0)}% text similarity. Report logged for verification review.";
        } else {
          _feedbackMessage = widget.isNepali
              ? "दर्ता सफल भयो! एआई विश्वसनीयता सूचक: ${result['confidence']}. " + (result['escalated'] ? "🚨 CIAA मा कारवाही अघि बढाइयो!" : "")
              : "Report live! AI Confidence score: ${result['confidence']}. " + (result['escalated'] ? "🚨 Escalated to CIAA automatically!" : "");
        }
      } else {
        _feedbackMessage = result["message"] ?? "Submission pipeline failed.";
      }
    });

    // Reset Form if fully successful
    if (_isSuccess && result["is_duplicate"] != true) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _currentStep = 0;
            _selectedInstitution = null;
            _selectedDistrict = null;
            _descController.clear();
            _bribeController.clear();
            _feedbackMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isNepali ? "🕵️ अज्ञात उजुरी विजार्ड" : "🕵️ Anonymous Report Wizard",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Stepper indicator
            Row(
              children: [
                _buildStepCircle(0, "1"),
                _buildStepDivider(),
                _buildStepCircle(1, "2"),
                _buildStepDivider(),
                _buildStepCircle(2, "3"),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        widget.isNepali ? "एआई स्पाम र नक्कल जाँच चल्दैछ..." : "Running spam-filter neural TF-IDF checks...",
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              )
            else if (_feedbackMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess 
                      ? const Color(0xFF10B981).withOpacity(0.1) 
                      : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                child: Text(
                  _feedbackMessage!,
                  style: TextStyle(
                    color: _isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              widget.isExpanded
                  ? Expanded(
                      child: SingleChildScrollView(
                        child: IndexedStack(
                          index: _currentStep,
                          children: [
                            _buildStep1(),
                            _buildStep2(),
                            _buildStep3(),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: IndexedStack(
                        index: _currentStep,
                        children: [
                          _buildStep1(),
                          _buildStep2(),
                          _buildStep3(),
                        ],
                      ),
                    ),

            if (!_isLoading && _feedbackMessage == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    ElevatedButton(
                      onPressed: _prevStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                      child: Text(widget.isNepali ? "पछाडि" : "Back"),
                    )
                  else
                    const SizedBox(),
                  
                  ElevatedButton(
                    onPressed: _currentStep == 2 ? _submitReport : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStep == 2 
                          ? Theme.of(context).colorScheme.error 
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      _currentStep == 2 
                          ? (widget.isNepali ? "उजुरी दर्ता गर्नुहोस्" : "Submit Disclosure") 
                          : (widget.isNepali ? "अर्को चरण" : "Next"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(int stepIndex, String label) {
    final isActive = _currentStep >= stepIndex;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.05),
        boxShadow: isActive ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8)] : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepDivider() {
    return const Expanded(
      child: Divider(
        color: Colors.white12,
        thickness: 2,
        indent: 8,
        endIndent: 8,
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isNepali ? "कार्यालय र स्थान विवरण:" : "Office & Incident Specifics",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedInstitution,
          decoration: InputDecoration(
            labelText: widget.isNepali ? "लक्षित सरकारी कार्यालय" : "Target Government Department",
            border: const OutlineInputBorder(),
          ),
          items: _institutions.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (val) => setState(() => _selectedInstitution = val),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          decoration: InputDecoration(
            labelText: widget.isNepali ? "घटना भएको जिल्ला" : "District of Incident",
            border: const OutlineInputBorder(),
          ),
          items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (val) => setState(() => _selectedDistrict = val),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: widget.isNepali ? "भ्रष्टाचारको विवरण (कम्तिमा १० अक्षर)" : "Allegation Details (Min 10 characters)",
            hintText: widget.isNepali ? "घटना खुलाउनुहोस्: कसले, किन, र कहिले घुस माग्यो..." : "Describe what happened: who requested it, why, when...",
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isNepali ? "रकम र प्रमाणहरू:" : "Financials & Physical Evidence",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bribeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.isNepali ? "घुस रकम (रु.)" : "Bribe Amount (NRs.)",
            prefixText: "Rs. ",
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Icon(Icons.attach_file, size: 36, color: Colors.white30),
              const SizedBox(height: 8),
              Text(widget.isNepali ? "प्रमाणहरू अपलोड गर्नुहोस्" : "Upload Supporting Evidence"),
              Text(
                widget.isNepali ? "तस्विर वा भिडियोहरू (१० एमबी भन्दा कम)" : "Images or video clips under 10MB",
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isNepali ? "स्थान ट्याग र अज्ञात सुरक्षा पुष्टि:" : "Incident Location Tag & Anonymity Confirm",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
        ),
        const SizedBox(height: 16),
        Text(
          widget.isNepali 
              ? "तपाईंको रिपोर्टलाई भू-ट्याग गर्न नक्सामा क्लिक गरी पिन तान्न सक्नुहुन्छ।"
              : "To tag the location of the allegation, click on the live dashboard map to drop a pin.",
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _isAnonymous,
          title: Text(widget.isNepali ? "१००% सुरक्षित अज्ञात उजुरी दर्ता" : "Maintain 100% Cryptographic Anonymity"),
          subtitle: Text(
            widget.isNepali 
                ? "हाम्रो प्रणालीले तपाईको पहिचान, इमेल, वा ब्राउजर रेकर्ड सुरक्षित रूपमा नष्ट गर्छ।" 
                : "Firebase Anonymous Auth silently generates a session without tracking any local identity parameters.",
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          onChanged: (val) => setState(() => _isAnonymous = val ?? true),
        ),
      ],
    );
  }
}
