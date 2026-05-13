import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voteguard/services/ai_service.dart';
import 'dart:io';

class ResultsEntryScreen extends StatefulWidget {
  const ResultsEntryScreen({super.key});

  @override
  State<ResultsEntryScreen> createState() => _ResultsEntryScreenState();
}

class _ResultsEntryScreenState extends State<ResultsEntryScreen> {
  int _currentStep = 0;
  File? _ec8aImage;
  final _picker = ImagePicker();
  bool _isProcessingAI = false;

  // Party Votes (Mock Data for UI)
  final Map<String, TextEditingController> _partyVotes = {
    'APC': TextEditingController(),
    'LP': TextEditingController(),
    'PDP': TextEditingController(),
    'NNPP': TextEditingController(),
  };

  // Ballot Statistics
  final _votersInRegister = TextEditingController();
  final _accreditedVoters = TextEditingController();
  final _ballotsIssued = TextEditingController();
  final _unusedBallots = TextEditingController();
  final _spoiledBallots = TextEditingController();
  final _rejectedBallots = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _ec8aImage = File(pickedFile.path);
        _isProcessingAI = true;
      });

      // Process with AI
      final aiService = context.read<AIService>();
      final results = await aiService.processEC8A(_ec8aImage!);

      if (results != null) {
        setState(() {
          // Fill party votes
          results.forEach((key, value) {
            if (_partyVotes.containsKey(key)) {
              _partyVotes[key]!.text = value.toString();
            }
          });

          // Fill stats (mapping flexible JSON keys to controllers)
          _votersInRegister.text = (results['voters_in_register'] ?? results['Voters in Register'] ?? '').toString();
          _accreditedVoters.text = (results['accredited_voters'] ?? results['Accredited Voters'] ?? '').toString();
          _ballotsIssued.text = (results['ballots_issued'] ?? results['Ballots Issued'] ?? '').toString();
          _unusedBallots.text = (results['unused_ballots'] ?? results['Unused Ballots'] ?? '').toString();
          _spoiledBallots.text = (results['spoiled_ballots'] ?? results['Spoiled Ballots'] ?? '').toString();
          _rejectedBallots.text = (results['rejected_ballots'] ?? results['Rejected Ballots'] ?? '').toString();
        });
      }

      setState(() {
        _isProcessingAI = false;
        _currentStep = 1; // Move to verification step
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit PU Results'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          _buildStepImageCapture(),
          _buildStepPartyVotes(),
          _buildStepBallotStats(),
        ],
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentStep == 2 ? _submitResults : details.onStepContinue,
                    child: Text(_currentStep == 2 ? 'Final Submission' : 'Next Step'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Step _buildStepImageCapture() {
    return Step(
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      title: const Text('EC8A'),
      content: Column(
        children: [
          if (_ec8aImage == null)
            _buildUploadPlaceholder()
          else
            _buildImagePreview(),
          const SizedBox(height: 24),
          Text(
            'Ensure the EC8A sheet is clear and well-lit for AI processing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
      ),
      child: _isProcessingAI
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 24),
                Text(
                  'Gemini AI is analyzing the EC8A sheet...',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.camera, color: AppColors.accent, size: 48),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  child: const Text('Take Photo of EC8A'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  child: const Text('Upload from Gallery'),
                ),
              ],
            ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.file(_ec8aImage!, height: 300, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: CircleAvatar(
              backgroundColor: AppColors.error,
              child: Icon(LucideIcons.x, color: Colors.white, size: 16),
            ),
            onPressed: () => setState(() => _ec8aImage = null),
          ),
        ),
      ],
    );
  }

  Step _buildStepPartyVotes() {
    return Step(
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      title: const Text('Votes'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify AI-parsed results against the physical sheet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ..._partyVotes.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Step _buildStepBallotStats() {
    return Step(
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      title: const Text('Stats'),
      content: Column(
        children: [
          _buildStatField('Voters in Register', _votersInRegister),
          _buildStatField('Accredited Voters', _accreditedVoters),
          _buildStatField('Ballots Issued', _ballotsIssued),
          _buildStatField('Unused Ballots', _unusedBallots),
          _buildStatField('Spoiled Ballots', _spoiledBallots),
          _buildStatField('Rejected Ballots', _rejectedBallots),
        ],
      ),
    );
  }

  Widget _buildStatField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  void _submitResults() {
    // TODO: Implement submission logic with biometrics and Firestore
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ready for Submission?'),
        content: const Text('This will lock the results for this Polling Unit and require biometric sign-off.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Review')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to dashboard
            },
            child: const Text('Sign & Submit'),
          ),
        ],
      ),
    );
  }
}
