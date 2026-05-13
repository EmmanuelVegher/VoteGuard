import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Violence';
  String _selectedSeverity = 'Medium';
  List<File> _attachments = [];
  Position? _currentPosition;
  bool _isLocating = false;

  final List<String> _categories = [
    'Violence',
    'Logistics Delay',
    'Ballot Snatching',
    'Malpractice',
    'Technical Failure',
    'Others'
  ];

  final List<Map<String, dynamic>> _severityLevels = [
    {'label': 'Low', 'color': Colors.blue},
    {'label': 'Medium', 'color': Colors.amber},
    {'label': 'High', 'color': Colors.orange},
    {'label': 'Critical', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Location Error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _addAttachment() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _attachments.add(File(pickedFile.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Incident Category'),
            const SizedBox(height: 12),
            _buildCategoryDropdown(),
            const SizedBox(height: 32),
            _buildSectionTitle('Severity Level'),
            const SizedBox(height: 16),
            _buildSeveritySelector(),
            const SizedBox(height: 32),
            _buildSectionTitle('Description'),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Provide details about the incident...',
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Media Attachments'),
            const SizedBox(height: 16),
            _buildAttachmentsList(),
            const SizedBox(height: 32),
            _buildLocationStatus(),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedSeverity == 'Critical' ? AppColors.error : AppColors.accent,
              ),
              child: const Text('Submit Incident Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          items: _categories.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCategory = val!),
        ),
      ),
    );
  }

  Widget _buildSeveritySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _severityLevels.map((level) {
        bool isSelected = _selectedSeverity == level['label'];
        return GestureDetector(
          onTap: () => setState(() => _selectedSeverity = level['label']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? level['color'] : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.white.withOpacity(0.5) : Colors.transparent,
              ),
            ),
            child: Text(
              level['label'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentsList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length + 1,
        itemBuilder: (context, index) {
          if (index == _attachments.length) {
            return GestureDetector(
              onTap: _addAttachment,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Icon(LucideIcons.plus, color: AppColors.accent),
              ),
            );
          }
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(_attachments[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.mapPin,
            color: _currentPosition != null ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GPS Timestamping', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _isLocating
                      ? 'Capturing coordinates...'
                      : _currentPosition != null
                          ? 'Location Secured (${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})'
                          : 'Location services disabled',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isLocating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
        ],
      ),
    );
  }

  void _submitReport() {
    // TODO: Implement report submission to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident Report Submitted Successfully')),
    );
    Navigator.pop(context);
  }
}
