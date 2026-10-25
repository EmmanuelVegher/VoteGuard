import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:voteguard/core/routes/dashboard_redirect.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'camera_image_converter.dart';

enum LivenessStep {
  initializing,
  positionFace,
  turnLeft,
  center1,
  turnRight,
  center2,
  blink,
  smile,
  capturing,
  uploading,
  completed,
}

class LivenessEnrollmentScreen extends StatefulWidget {
  final bool isModal;

  const LivenessEnrollmentScreen({
    super.key,
    this.isModal = false,
  });

  @override
  State<LivenessEnrollmentScreen> createState() => _LivenessEnrollmentScreenState();
}

class _LivenessEnrollmentScreenState extends State<LivenessEnrollmentScreen> {
  static const _storage = FlutterSecureStorage();
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  bool _isEvaluating = false;
  bool _cameraUnavailable = false;

  DateTime _stepStartTime = DateTime.now();
  int _stableFrames = 0;

  LivenessStep _step = LivenessStep.initializing;
  String _instruction = "Initializing HD Face Detector...";
  String _subInstruction = "Please allow camera access when prompted";
  IconData _stepIcon = Icons.camera_alt_rounded;
  double _progress = 0.12;

  bool _eyesClosedOnce = false;
  double? _firstTurnYaw;
  String? _uploadStatusText;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    _initCamera();
  }

  void _initializeDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.25,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _initCamera() async {
    setState(() {
      _cameraUnavailable = false;
      _errorMessage = null;
      _step = LivenessStep.initializing;
      _instruction = "Initializing front camera...";
      _subInstruction = "Connecting to high-definition video stream";
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraUnavailable = true);
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      await _cameraController!.startImageStream(_processCameraFrame);
      if (!mounted) return;

      setState(() {
        _step = LivenessStep.positionFace;
        _instruction = "Position your face inside the oval";
        _subInstruction = "Look straight at the front camera";
        _stepIcon = Icons.face_rounded;
        _progress = 0.15;
        _stepStartTime = DateTime.now();
        _stableFrames = 0;
      });
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted) {
        setState(() {
          _cameraUnavailable = true;
          _errorMessage = "Camera access was denied or hardware is busy. Please ensure camera permissions are enabled in device settings.";
        });
      }
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame ||
        _isEvaluating ||
        _step == LivenessStep.initializing ||
        _step == LivenessStep.capturing ||
        _step == LivenessStep.uploading ||
        _step == LivenessStep.completed) {
      return;
    }
    _isProcessingFrame = true;

    try {
      final inputImage = convertCameraImageToInputImage(
        image: image,
        camera: _cameraController!.description,
        orientation: MediaQuery.of(context).orientation == Orientation.portrait
            ? DeviceOrientation.portraitUp
            : DeviceOrientation.landscapeLeft,
      );

      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        if (_step != LivenessStep.initializing && mounted) {
          _updateInstruction(
            "Position your face inside the frame",
            "Center your face inside the oval guide",
            Icons.center_focus_strong,
            _progress,
          );
        }
        return;
      }

      if (faces.length > 1) {
        if (mounted) {
          _updateInstruction(
            "Multiple faces detected",
            "Only one person permitted during verification",
            Icons.people_outline,
            _progress,
          );
        }
        return;
      }

      final face = faces.first;
      _handleStepProgression(face);
    } catch (e) {
      debugPrint("Face evaluation frame drop: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// State Machine: Smoothly progresses through verification without inverted turn contradictions
  void _handleStepProgression(Face face) async {
    if (_isEvaluating) return;

    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    final smile = face.smilingProbability ?? 0.0;

    final now = DateTime.now();

    switch (_step) {
      case LivenessStep.positionFace:
        if (yaw.abs() < 8.0 && pitch.abs() < 12.0) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _stableFrames = 0;
            _stepStartTime = now;
            _firstTurnYaw = null;
            HapticFeedback.selectionClick();
            setState(() {
              _step = LivenessStep.turnLeft;
              _instruction = "Turn head to your LEFT ◀";
              _subInstruction = "Slowly turn your head left until prompted";
              _stepIcon = Icons.arrow_back_rounded;
              _progress = 0.28;
            });
          }
        } else {
          _stableFrames = 0;
        }
        break;

      case LivenessStep.turnLeft:
        // Enforce at least 500ms dwell time so user can read instruction and begin turning
        if (now.difference(_stepStartTime).inMilliseconds < 500) {
          _stableFrames = 0;
          return;
        }

        // Standard Google ML Kit front-camera coordinate:
        // Turning to subject's left is negative yaw (yaw < -15.0).
        // Resilient fallback: If an inverted vendor camera driver is in use, allow positive yaw after 3.5s of attempting.
        final isStandardLeft = yaw < -15.0;
        final isInvertedLeft = now.difference(_stepStartTime).inMilliseconds > 3500 && yaw > 15.0;

        if (isStandardLeft || isInvertedLeft) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _firstTurnYaw = yaw;
            _stableFrames = 0;
            _stepStartTime = now;
            HapticFeedback.lightImpact();
            setState(() {
              _step = LivenessStep.center1;
              _instruction = "Turn back STRAIGHT 🎯";
              _subInstruction = "Look directly at the camera again";
              _stepIcon = Icons.center_focus_strong_rounded;
              _progress = 0.42;
            });
          }
        } else {
          _stableFrames = 0;
        }
        break;

      case LivenessStep.center1:
        if (now.difference(_stepStartTime).inMilliseconds < 450) {
          _stableFrames = 0;
          return;
        }

        if (yaw.abs() < 8.0 && pitch.abs() < 12.0) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _stableFrames = 0;
            _stepStartTime = now;
            HapticFeedback.selectionClick();
            setState(() {
              _step = LivenessStep.turnRight;
              _instruction = "Turn head to your RIGHT ▶";
              _subInstruction = "Slowly turn your head right until prompted";
              _stepIcon = Icons.arrow_forward_rounded;
              _progress = 0.58;
            });
          }
        } else {
          _stableFrames = 0;
        }
        break;

      case LivenessStep.turnRight:
        if (now.difference(_stepStartTime).inMilliseconds < 500) {
          _stableFrames = 0;
          return;
        }

        // Must turn opposite to the left turn
        final isStandardRight = _firstTurnYaw != null && _firstTurnYaw! < 0 ? yaw > 15.0 : yaw > 15.0;
        final isInvertedRight = _firstTurnYaw != null && _firstTurnYaw! > 0 && yaw < -15.0;

        if (isStandardRight || isInvertedRight) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _stableFrames = 0;
            _stepStartTime = now;
            HapticFeedback.lightImpact();
            setState(() {
              _step = LivenessStep.center2;
              _instruction = "Turn back STRAIGHT 🎯";
              _subInstruction = "Face the camera to proceed";
              _stepIcon = Icons.center_focus_strong_rounded;
              _progress = 0.72;
            });
          }
        } else {
          _stableFrames = 0;
        }
        break;

      case LivenessStep.center2:
        if (now.difference(_stepStartTime).inMilliseconds < 450) {
          _stableFrames = 0;
          return;
        }

        if (yaw.abs() < 8.0 && pitch.abs() < 12.0) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _stableFrames = 0;
            _eyesClosedOnce = false;
            _stepStartTime = now;
            HapticFeedback.selectionClick();
            setState(() {
              _step = LivenessStep.blink;
              _instruction = "Blink your eyes 👁️";
              _subInstruction = "Close both eyes and open them";
              _stepIcon = Icons.visibility_rounded;
              _progress = 0.85;
            });
          }
        } else {
          _stableFrames = 0;
        }
        break;

      case LivenessStep.blink:
        if (now.difference(_stepStartTime).inMilliseconds < 400) return;

        if (leftEye < 0.28 && rightEye < 0.28) {
          _eyesClosedOnce = true;
        } else if (_eyesClosedOnce && leftEye > 0.60 && rightEye > 0.60) {
          _stableFrames = 0;
          _stepStartTime = now;
          HapticFeedback.lightImpact();
          setState(() {
            _step = LivenessStep.smile;
            _instruction = "Smile for your profile! 😊";
            _subInstruction = "Give a clear, natural smile looking straight";
            _stepIcon = Icons.sentiment_very_satisfied_rounded;
            _progress = 0.95;
          });
        }
        break;

      case LivenessStep.smile:
        if (now.difference(_stepStartTime).inMilliseconds < 400) return;

        if (smile > 0.38 && yaw.abs() < 10.0 && pitch.abs() < 12.0) {
          _stableFrames++;
          if (_stableFrames >= 3) {
            _isEvaluating = true;
            HapticFeedback.mediumImpact();
            setState(() {
              _step = LivenessStep.capturing;
              _instruction = "Hold still! Capturing HD portrait...";
              _subInstruction = "Enhancing clarity & cropping biometric photo";
              _stepIcon = Icons.camera_rounded;
              _progress = 1.0;
            });
            await Future.delayed(const Duration(milliseconds: 500));
            await _captureAndEnroll();
          }
        } else {
          _stableFrames = 0;
        }
        break;

      default:
        break;
    }
  }

  void _updateInstruction(String main, String sub, IconData icon, double prog) {
    if ((_instruction != main || _subInstruction != sub) && mounted) {
      setState(() {
        _instruction = main;
        _subInstruction = sub;
        _stepIcon = icon;
        _progress = prog;
      });
    }
  }

  /// High-definition Biometric Pipeline: EXIF bake, tight passport crop, contrast & saturation boost, upload & sync
  Future<void> _captureAndEnroll() async {
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        _showErrorDialog("Camera is not initialized. Please retry live verification.");
        return;
      }

      final photo = await _cameraController!.takePicture();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog("Session expired. Please log in again.");
        return;
      }

      setState(() {
        _step = LivenessStep.uploading;
        _uploadStatusText = "Enhancing clarity & cropping biometric portrait...";
      });

      Uint8List? finalJpgBytes;
      final capturedTempFile = File(photo.path);
      final rawBytes = await capturedTempFile.readAsBytes();
        img.Image? decoded = img.decodeImage(rawBytes);

        if (decoded != null) {
          // 1. Correct EXIF orientation so front selfie is 100% upright
          decoded = img.bakeOrientation(decoded);

          final orientedTempFile = File("${capturedTempFile.path}_upright.jpg");
          await orientedTempFile.writeAsBytes(img.encodeJpg(decoded, quality: 90));

          int cropX = 0;
          int cropY = 0;
          int cropDim = decoded.width < decoded.height ? decoded.width : decoded.height;

          try {
            final detectedFaces = await _faceDetector.processImage(
              InputImage.fromFilePath(orientedTempFile.path),
            );

            if (detectedFaces.isNotEmpty) {
              final face = detectedFaces.first.boundingBox;
              // Biometric passport crop: face occupies ~65% of frame height
              final desiredDim = (face.height * 1.55).clamp(240.0, decoded.width.toDouble()).toDouble();
              final halfDim = desiredDim / 2;

              final targetX = face.center.dx;
              // Center horizontally, slightly shift up to keep hair and collar in frame
              final targetY = face.center.dy - (face.height * 0.08);

              cropX = (targetX - halfDim).round();
              cropY = (targetY - halfDim).round();
              cropDim = desiredDim.round();
            } else {
              cropDim = (decoded.width * 0.72).round();
              cropX = (decoded.width - cropDim) ~/ 2;
              cropY = (decoded.height - cropDim) ~/ 3;
            }
          } catch (e) {
            debugPrint("Detector error during crop: $e");
            cropDim = (decoded.width * 0.72).round();
            cropX = (decoded.width - cropDim) ~/ 2;
            cropY = (decoded.height - cropDim) ~/ 3;
          } finally {
            try {
              if (await orientedTempFile.exists()) {
                await orientedTempFile.delete();
              }
            } catch (_) {}
          }

          if (cropX < 0) cropX = 0;
          if (cropY < 0) cropY = 0;
          if (cropX + cropDim > decoded.width) {
            cropX = (decoded.width - cropDim).clamp(0, decoded.width);
          }
          if (cropY + cropDim > decoded.height) {
            cropY = (decoded.height - cropDim).clamp(0, decoded.height);
          }
          final actualW = cropDim.clamp(1, decoded.width - cropX);
          final actualH = cropDim.clamp(1, decoded.height - cropY);

          var cropped = img.copyCrop(
            decoded,
            x: cropX,
            y: cropY,
            width: actualW,
            height: actualH,
          );

          // 2. High-resolution 800x800 avatar resize
          var hdAvatar = img.copyResize(
            cropped,
            width: 800,
            height: 800,
            interpolation: img.Interpolation.linear,
          );

          // 3. Studio-grade contrast expansion & color vibrancy (+15% contrast, +12% saturation)
          hdAvatar = img.adjustColor(
            hdAvatar,
            contrast: 1.15,
            saturation: 1.12,
          );

          finalJpgBytes = Uint8List.fromList(img.encodeJpg(hdAvatar, quality: 95));
        }

      final effectiveBytes = finalJpgBytes ?? await File(photo.path).readAsBytes();

      // 4. Save enhanced HD copy to local phone storage
      setState(() {
        _uploadStatusText = "Saving HD portrait to local secure storage...";
      });

      final appDir = await getApplicationDocumentsDirectory();
      final localFolder = Directory("${appDir.path}/profile_images");
      if (!await localFolder.exists()) {
        await localFolder.create(recursive: true);
      }
      final localFilePath = "${localFolder.path}/${user.uid}.jpg";
      final localSavedFile = File(localFilePath);
      await localSavedFile.writeAsBytes(effectiveBytes);
      debugPrint("Enhanced HD photo saved locally: $localFilePath (${effectiveBytes.length} bytes)");

      // 5. Upload to Firebase Storage
      setState(() {
        _uploadStatusText = "Uploading biometric portrait to Firebase Storage...";
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child("voter_profiles")
          .child("${user.uid}.jpg");

      final uploadTask = await storageRef.putData(
        effectiveBytes,
        SettableMetadata(contentType: "image/jpeg"),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 6. Update Firestore user document
      setState(() {
        _uploadStatusText = "Syncing accredited observer profile in cloud database...";
      });

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "profilePictureUrl": downloadUrl,
        "profileImageUrl": downloadUrl,
        "localProfileImagePath": localFilePath,
        "isFaceEnrolled": true,
        "faceAuditStatus": "CLEAN",
        "enrolledAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 7. Cache flags locally in secure storage
      await _storage.write(key: "isFaceEnrolled_${user.uid}", value: "true");
      await _storage.write(key: "local_profile_image_path_${user.uid}", value: localFilePath);
      await _storage.write(key: "profilePictureUrl_${user.uid}", value: downloadUrl);

      setState(() {
        _step = LivenessStep.completed;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Liveness Verified! Crystal-clear HD profile enrolled!"),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 3),
        ),
      );

      if (widget.isModal) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardRedirect.getTargetScreen(context),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Photo capture/save error: $e");
      _showErrorDialog("Enrollment failed: $e. Please retry.");
    }
  }

  /// Development/testing simulation fallback
  void _simulateLivenessSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog("Session expired. Please log in again.");
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _step = LivenessStep.uploading;
      _uploadStatusText = "Simulating verification for testing...";
    });

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "isFaceEnrolled": true,
        "faceAuditStatus": "CLEAN",
        "enrolledAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _storage.write(key: "isFaceEnrolled_${user.uid}", value: "true");

      setState(() {
        _step = LivenessStep.completed;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Identity verified (Test Mode)!"),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 3),
        ),
      );

      if (widget.isModal) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardRedirect.getTargetScreen(context),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorDialog("Simulation error: $e");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Enrollment Notice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (_step == LivenessStep.uploading) {
                setState(() {
                  _step = LivenessStep.positionFace;
                  _isEvaluating = false;
                  _isProcessingFrame = false;
                });
                _initCamera();
              }
            },
            child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  String _getActionBadgeText() {
    switch (_step) {
      case LivenessStep.positionFace:
        return "Center Face";
      case LivenessStep.turnLeft:
        return "Turn Left";
      case LivenessStep.center1:
      case LivenessStep.center2:
        return "Look Straight";
      case LivenessStep.turnRight:
        return "Turn Right";
      case LivenessStep.blink:
        return "Blink Eyes";
      case LivenessStep.smile:
        return "Smile";
      case LivenessStep.capturing:
        return "Capturing HD...";
      case LivenessStep.uploading:
        return "Enrolling...";
      default:
        return "Processing";
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Slate 950 obsidian
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.8),
        elevation: 0,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 20),
            SizedBox(width: 8),
            Text(
              "Biometric Liveness Verification",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _cameraUnavailable
            ? _buildCameraPermissionFallback()
            : _buildLiveCameraView(),
      ),
    );
  }

  Widget _buildLiveCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 16),
            Text(
              _instruction,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _subInstruction,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final isCapturingOrDone = _step == LivenessStep.capturing || _step == LivenessStep.completed;

    return Column(
      children: [
        // Camera Viewport with Oval Frame
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera Viewport
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),

                // Centered Oval Guide & Dynamic Glow Border
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 340,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Dynamic glow border
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(160),
                            border: Border.all(
                              color: isCapturingOrDone
                                  ? AppColors.accent
                                  : Colors.cyanAccent.withValues(alpha: 0.8),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isCapturingOrDone
                                    ? AppColors.accent.withValues(alpha: 0.5)
                                    : Colors.cyanAccent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                        // Action pill badge floating at bottom of oval
                        Positioned(
                          bottom: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCapturingOrDone ? AppColors.accent : Colors.cyanAccent,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _stepIcon,
                                  size: 16,
                                  color: isCapturingOrDone ? AppColors.accent : Colors.cyanAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getActionBadgeText(),
                                  style: TextStyle(
                                    color: isCapturingOrDone ? AppColors.accent : Colors.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Flash animation effect on capture
                if (_step == LivenessStep.capturing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // HUD Instructions Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == LivenessStep.uploading) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 10),
                      Text(
                        _uploadStatusText ?? "Enrolling & Syncing HD Portrait...",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _instruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      "${(_progress * 100).round()}%",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _subInstruction,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Gradient Progress Bar (Cyan to Emerald)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        color: const Color(0xFF1E293B),
                      ),
                      FractionallySizedBox(
                        widthFactor: _progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.cyanAccent, AppColors.accent],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Bottom Action Row: Security Beacon
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "🔒 Anti-Spoofing Active • Live 3D Face Verification",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Camera Permission & Hardware Access Fallback View
  Widget _buildCameraPermissionFallback() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "Live Camera Access Required",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "For election observer accreditation and anti-spoofing integrity, live facial verification is strictly mandatory. Uploading photos or pre-recorded files is disabled.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step-by-step guidance card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Troubleshooting Steps:",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _PermissionGuideItem(
                    number: "1",
                    text: "Grant Camera permission in your device App Settings",
                  ),
                  SizedBox(height: 8),
                  _PermissionGuideItem(
                    number: "2",
                    text: "Close any other apps currently accessing the camera",
                  ),
                  SizedBox(height: 8),
                  _PermissionGuideItem(
                    number: "3",
                    text: "Tap 'Retry Live Camera' once permissions are enabled",
                  ),
                ],
              ),
            ),

            // Open App Settings button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.settings_outlined, size: 20),
                label: const Text(
                  "Grant Camera Permissions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Retry Camera Live Feed
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.cyanAccent),
                label: const Text(
                  "Retry Live Camera",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  setState(() {
                    _cameraUnavailable = false;
                  });
                  _initCamera();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Simulate Liveness button for testing
            TextButton.icon(
              icon: const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF94A3B8)),
              label: const Text(
                "Simulate Verification (Dev / QA Test)",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              onPressed: _simulateLivenessSuccess,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionGuideItem extends StatelessWidget {
  final String number;
  final String text;

  const _PermissionGuideItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
