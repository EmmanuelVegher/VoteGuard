import 'dart:io';
import 'dart:math' as math;
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
import 'package:voteguard/services/biometric_deduplication_service.dart';
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
  DateTime? _lastInferenceTime;
  DateTime? _stateHoldStartTime;
  bool _isLaggingDevice = false;
  int _warmupFrames = 0;
  final List<int> _inferenceDurations = [];

  LivenessStep _step = LivenessStep.initializing;
  String _instruction = "Initializing HD Face Detector...";
  String _subInstruction = "Please allow camera access when prompted";
  IconData _stepIcon = Icons.camera_alt_rounded;
  double _progress = 0.12;

  bool _eyesClosedOnce = false;
  double? _firstTurnYaw;
  int _lastImageWidth = 0;
  int _lastImageHeight = 0;
  String? _uploadStatusText;
  String? _errorMessage;

  // Real-time Eyeglasses & Bare-Chest/Nudity Compliance State (1GB RAM zero-allocation detector)
  DateTime? _lastComplianceTime;
  int _glassesStrikes = 0;
  int _nudityStrikes = 0;
  String? _complianceWarningTitle;
  String? _complianceWarningDetail;
  bool _isFaceFittedInCircle = false;
  String _faceFitHint = "Fit your face inside the round circle";

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
      _subInstruction = "Connecting to video stream";
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
        ResolutionPreset.medium, // 480p preview for smooth ML Kit processing on low-end devices
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
        _instruction = "Fit your face inside the round circle";
        _subInstruction = "Make sure your entire face fills the circle";
        _stepIcon = Icons.face_rounded;
        _progress = 0.15;
        _stepStartTime = DateTime.now();
        _stateHoldStartTime = null;
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

    final now = DateTime.now();
    // Adaptive Inference Throttling: 125ms (~8 FPS) on 1GB RAM / lagging phones, 80ms (~12.5 FPS) on standard phones
    final minIntervalMs = _isLaggingDevice ? 125 : 80;
    if (_lastInferenceTime != null && now.difference(_lastInferenceTime!).inMilliseconds < minIntervalMs) {
      return;
    }
    _lastInferenceTime = now;
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

      final stopwatch = Stopwatch()..start();
      final faces = await _faceDetector.processImage(inputImage);
      stopwatch.stop();

      // Lag detector: skip first 8 warmup frames before evaluating sustained lag
      _warmupFrames++;
      if (_warmupFrames > 8) {
        final durationMs = stopwatch.elapsedMilliseconds;
        _inferenceDurations.add(durationMs);
        if (_inferenceDurations.length > 6) {
          _inferenceDurations.removeAt(0);
          final avgMs = _inferenceDurations.reduce((a, b) => a + b) / _inferenceDurations.length;
          if (avgMs > 260 && !_isLaggingDevice && mounted) {
            setState(() {
              _isLaggingDevice = true;
            });
          }
        }
      }

      if (faces.isEmpty) {
        _stateHoldStartTime = null;
        if (_step != LivenessStep.initializing && mounted) {
          if (_isFaceFittedInCircle) {
            setState(() {
              _isFaceFittedInCircle = false;
              _faceFitHint = "Fit your face inside the round circle";
            });
          }
          _updateInstruction(
            "Fit your face inside the round circle",
            "Center your entire face inside the circular guide",
            Icons.center_focus_strong,
            _progress,
          );
        }
        return;
      }

      if (faces.length > 1) {
        _stateHoldStartTime = null;
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
      final rot = _cameraController!.description.sensorOrientation;
      final isRotated90or270 = rot == 90 || rot == 270;
      _lastImageWidth = isRotated90or270 ? image.height : image.width;
      _lastImageHeight = isRotated90or270 ? image.width : image.height;

      // Real-time Eyeglasses & Bare-Chest/Nudity Check (throttled to ~3.8 FPS / 260ms, zero heap allocation)
      final yawAbs = (face.headEulerAngleY ?? 0.0).abs();
      if (yawAbs < 16.0 &&
          (_lastComplianceTime == null ||
              now.difference(_lastComplianceTime!).inMilliseconds >= 260)) {
        _lastComplianceTime = now;
        final compliance = _checkStreamGlassesAndAttire(image, face, rot);
        if (compliance.bareChestOrNude) {
          _nudityStrikes = (_nudityStrikes + 1).clamp(0, 4);
        } else {
          _nudityStrikes = 0;
        }

        if (compliance.wearingGlasses) {
          _glassesStrikes = (_glassesStrikes + 1).clamp(0, 4);
        } else {
          _glassesStrikes = 0;
        }

        if (_nudityStrikes >= 2) {
          _stateHoldStartTime = null;
          if (mounted) {
            setState(() {
              _complianceWarningTitle = "Proper Attire Required (No Bare Chest / Nudity)";
              _complianceWarningDetail =
                  "Bare chest or nudity detected. Please wear a shirt or proper clothing covering your chest and shoulders to continue the liveness check.";
              _instruction = "Proper Attire Required 👕";
              _subInstruction = "Please wear clothing covering your chest and shoulders";
              _stepIcon = Icons.checkroom_rounded;
            });
          }
          return;
        } else if (_glassesStrikes >= 2) {
          _stateHoldStartTime = null;
          if (mounted) {
            setState(() {
              _complianceWarningTitle = "Please Remove Your Eyeglasses";
              _complianceWarningDetail =
                  "Eyeglasses or sunglasses detected. Please take off your glasses so your eyes are clearly visible during the liveness check.";
              _instruction = "Please Remove Eyeglasses 👓";
              _subInstruction = "Take off your glasses to continue biometric verification";
              _stepIcon = Icons.visibility_off_rounded;
            });
          }
          return;
        } else if (_complianceWarningTitle != null &&
            _nudityStrikes == 0 &&
            _glassesStrikes == 0) {
          if (mounted) {
            final restored = _getStepInstructionCopy(_step);
            setState(() {
              _complianceWarningTitle = null;
              _complianceWarningDetail = null;
              _instruction = restored.title;
              _subInstruction = restored.sub;
              _stepIcon = restored.icon;
            });
          }
        }
      }

      if (_complianceWarningTitle != null) {
        _stateHoldStartTime = null;
        return;
      }

      _handleStepProgression(face);
    } catch (e) {
      debugPrint("Face evaluation frame drop: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// State Machine: Time-based dwell progression & adaptive thresholds for slow devices
  void _handleStepProgression(Face face) async {
    if (_isEvaluating) return;

    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    final smile = face.smilingProbability ?? 0.0;

    final now = DateTime.now();

    final holdMs = _isLaggingDevice ? 380 : 550;
    final yawLimit = _isLaggingDevice ? 12.0 : 8.0;
    final pitchLimit = _isLaggingDevice ? 16.0 : 12.0;
    final turnYawThreshold = _isLaggingDevice ? 10.0 : 15.0;

    switch (_step) {
      case LivenessStep.positionFace:
        // Ensure entire face fits and fills the centered round facial circle
        final box = face.boundingBox;
        final frameW = _lastImageWidth > 0 ? _lastImageWidth.toDouble() : 0.0;
        final frameH = _lastImageHeight > 0 ? _lastImageHeight.toDouble() : 0.0;
        bool fitsCircle = true;
        String fitMessage = "✓ Face Properly Fitted in Circle";
        if (frameW > 0 && frameH > 0) {
          final cx = box.center.dx / frameW;
          final cy = box.center.dy / frameH;
          final fhRatio = box.height / frameH;
          final dist = math.sqrt((cx - 0.5) * (cx - 0.5) + (cy - 0.45) * (cy - 0.45));
          final edgesIn = box.left >= frameW * 0.04 &&
              box.right <= frameW * 0.96 &&
              box.top >= frameH * 0.04 &&
              box.bottom <= frameH * 0.96;
          final minRatio = _isLaggingDevice ? 0.20 : 0.23;
          if (!edgesIn || dist > (_isLaggingDevice ? 0.26 : 0.22)) {
            fitsCircle = false;
            fitMessage = "Center your entire face inside the circle";
          } else if (fhRatio < minRatio) {
            fitsCircle = false;
            fitMessage = "Move closer so your face fills the circle";
          } else if (fhRatio > 0.80) {
            fitsCircle = false;
            fitMessage = "Move slightly back to fit inside the circle";
          }
        }
        if (_isFaceFittedInCircle != fitsCircle || _faceFitHint != fitMessage) {
          if (mounted) {
            setState(() {
              _isFaceFittedInCircle = fitsCircle;
              _faceFitHint = fitMessage;
            });
          }
        }
        if (!fitsCircle) {
          _stateHoldStartTime = null;
          _updateInstruction(
            fitMessage,
            "Make sure your entire face (forehead to chin) fits inside the round circle",
            Icons.center_focus_strong,
            _progress,
          );
          break;
        }
        if (yaw.abs() < yawLimit && pitch.abs() < pitchLimit) {
          _stateHoldStartTime ??= now;
          final elapsed = now.difference(_stateHoldStartTime!).inMilliseconds;
          if (elapsed >= holdMs) {
            _stateHoldStartTime = null;
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
          _stateHoldStartTime = null;
        }
        break;

      case LivenessStep.turnLeft:
        if (now.difference(_stepStartTime).inMilliseconds < (_isLaggingDevice ? 250 : 450)) {
          return;
        }

        // Standard Google ML Kit front-camera coordinate:
        // Turning to subject's left is negative yaw (yaw < -turnYawThreshold).
        final isStandardLeft = yaw < -turnYawThreshold;
        final isInvertedLeft = now.difference(_stepStartTime).inMilliseconds > 2500 && yaw > turnYawThreshold;

        if (isStandardLeft || isInvertedLeft) {
          _stateHoldStartTime ??= now;
          if (now.difference(_stateHoldStartTime!).inMilliseconds >= (_isLaggingDevice ? 180 : 300)) {
            _firstTurnYaw = yaw;
            _stateHoldStartTime = null;
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
          _stateHoldStartTime = null;
        }
        break;

      case LivenessStep.center1:
        if (now.difference(_stepStartTime).inMilliseconds < (_isLaggingDevice ? 250 : 400)) {
          return;
        }

        if (yaw.abs() < yawLimit && pitch.abs() < pitchLimit) {
          _stateHoldStartTime ??= now;
          if (now.difference(_stateHoldStartTime!).inMilliseconds >= holdMs) {
            _stateHoldStartTime = null;
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
          _stateHoldStartTime = null;
        }
        break;

      case LivenessStep.turnRight:
        if (now.difference(_stepStartTime).inMilliseconds < (_isLaggingDevice ? 250 : 450)) {
          return;
        }

        // Must turn opposite to the left turn
        final isStandardRight = _firstTurnYaw != null && _firstTurnYaw! < 0 ? yaw > turnYawThreshold : yaw > turnYawThreshold;
        final isInvertedRight = _firstTurnYaw != null && _firstTurnYaw! > 0 && yaw < -turnYawThreshold;

        if (isStandardRight || isInvertedRight) {
          _stateHoldStartTime ??= now;
          if (now.difference(_stateHoldStartTime!).inMilliseconds >= (_isLaggingDevice ? 180 : 300)) {
            _stateHoldStartTime = null;
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
          _stateHoldStartTime = null;
        }
        break;

      case LivenessStep.center2:
        if (now.difference(_stepStartTime).inMilliseconds < (_isLaggingDevice ? 250 : 400)) {
          return;
        }

        if (yaw.abs() < yawLimit && pitch.abs() < pitchLimit) {
          _stateHoldStartTime ??= now;
          if (now.difference(_stateHoldStartTime!).inMilliseconds >= holdMs) {
            _stateHoldStartTime = null;
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
          _stateHoldStartTime = null;
        }
        break;

      case LivenessStep.blink:
        if (now.difference(_stepStartTime).inMilliseconds < 300) return;

        if (leftEye < 0.32 && rightEye < 0.32) {
          _eyesClosedOnce = true;
        } else if (_eyesClosedOnce && leftEye > 0.55 && rightEye > 0.55) {
          _stateHoldStartTime = null;
          _stepStartTime = now;
          HapticFeedback.lightImpact();
          setState(() {
            _step = LivenessStep.smile;
            _instruction = "Smile for your profile! 😊";
            _subInstruction = "Give a clear, natural smile looking straight";
            _stepIcon = Icons.sentiment_very_satisfied_rounded;
            _progress = 0.95;
          });
          return;
        }

        // Adaptive slow-device fallback for blink:
        // On slow devices (or if user struggles for > 3.0s), allow natural smile or steady face
        final timeOnBlink = now.difference(_stepStartTime).inMilliseconds;
        if (_isLaggingDevice || timeOnBlink > 3000) {
          if (smile > 0.25 || (yaw.abs() < yawLimit && timeOnBlink > 4000)) {
            _stateHoldStartTime = null;
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
        }
        break;

      case LivenessStep.smile:
        if (now.difference(_stepStartTime).inMilliseconds < 300) return;

        final smileThreshold = _isLaggingDevice ? 0.25 : 0.38;
        if (smile > smileThreshold && yaw.abs() < (yawLimit + 2) && pitch.abs() < pitchLimit) {
          _stateHoldStartTime ??= now;
          if (now.difference(_stateHoldStartTime!).inMilliseconds >= (_isLaggingDevice ? 200 : 350)) {
            _isEvaluating = true;
            _stateHoldStartTime = null;
            HapticFeedback.mediumImpact();
            setState(() {
              _step = LivenessStep.capturing;
              _instruction = "Hold still! Capturing HD portrait...";
              _subInstruction = "Enhancing clarity & cropping biometric photo";
              _stepIcon = Icons.camera_rounded;
              _progress = 1.0;
            });
            await Future.delayed(const Duration(milliseconds: 400));
            await _captureAndEnroll();
          }
        } else {
          _stateHoldStartTime = null;
        }
        break;

      default:
        break;
    }
  }

  Future<void> _handleManualInstantCapture() async {
    if (_isEvaluating ||
        _step == LivenessStep.capturing ||
        _step == LivenessStep.uploading ||
        _step == LivenessStep.completed) {
      return;
    }
    _isEvaluating = true;
    HapticFeedback.mediumImpact();
    setState(() {
      _step = LivenessStep.capturing;
      _instruction = "Hold still! Capturing portrait...";
      _subInstruction = "Processing official observer photo";
      _stepIcon = Icons.camera_rounded;
      _progress = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    await _captureAndEnroll();
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

  ({String title, String sub, IconData icon}) _getStepInstructionCopy(LivenessStep step) {
    switch (step) {
      case LivenessStep.positionFace:
        return (
          title: "Position your face inside the oval",
          sub: "Look straight at the front camera",
          icon: Icons.face_rounded,
        );
      case LivenessStep.turnLeft:
        return (
          title: "Turn head to your LEFT ◀",
          sub: "Slowly turn your head left until prompted",
          icon: Icons.arrow_back_rounded,
        );
      case LivenessStep.center1:
        return (
          title: "Turn back STRAIGHT 🎯",
          sub: "Look directly at the camera again",
          icon: Icons.center_focus_strong_rounded,
        );
      case LivenessStep.turnRight:
        return (
          title: "Turn head to your RIGHT ▶",
          sub: "Slowly turn your head right until prompted",
          icon: Icons.arrow_forward_rounded,
        );
      case LivenessStep.center2:
        return (
          title: "Turn back STRAIGHT 🎯",
          sub: "Face the camera to proceed",
          icon: Icons.center_focus_strong_rounded,
        );
      case LivenessStep.blink:
        return (
          title: "Blink your eyes 👁️",
          sub: "Close both eyes and open them",
          icon: Icons.visibility_rounded,
        );
      case LivenessStep.smile:
        return (
          title: "Smile for your profile! 😊",
          sub: "Give a clear, natural smile looking straight",
          icon: Icons.sentiment_very_satisfied_rounded,
        );
      default:
        return (
          title: "Position your face inside the oval",
          sub: "Look straight at the front camera",
          icon: Icons.face_rounded,
        );
    }
  }

  /// Zero-allocation (<0.15ms) live CameraImage stream check for Eyeglasses & Bare-Chest/Nudity.
  /// Samples sparse YCbCr pixels directly in-place from NV21 (Android) or BGRA8888 (iOS) planes.
  /// Safe for 1GB RAM devices: allocates 0 image buffers on the heap.
  ({bool wearingGlasses, bool bareChestOrNude}) _checkStreamGlassesAndAttire(
    CameraImage image,
    Face face,
    int sensorRotation,
  ) {
    final isRot90or270 = sensorRotation == 90 || sensorRotation == 270;
    final upW = (isRot90or270 ? image.height : image.width).toDouble();
    final upH = (isRot90or270 ? image.width : image.height).toDouble();
    if (upW <= 0 || upH <= 0 || image.planes.isEmpty) {
      return (wearingGlasses: false, bareChestOrNude: false);
    }

    final rawW = image.width;
    final rawH = image.height;
    final plane0 = image.planes[0];
    final bytes0 = plane0.bytes;
    final rowStride0 = plane0.bytesPerRow;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888 ||
        (image.planes.length == 1 && rowStride0 >= rawW * 4);
    final hasNv21Chroma = !isBgra && image.planes.length >= 2;
    final bytes1 = hasNv21Chroma ? image.planes[1].bytes : null;
    final rowStride1 = hasNv21Chroma ? image.planes[1].bytesPerRow : 0;
    final pixelStride1 = hasNv21Chroma ? (image.planes[1].bytesPerPixel ?? 2) : 2;

    // Map normalized upright coordinate (nx, ny in 0..1) to sensor coordinate (rx, ry) and return (Y, Cb, Cr)
    ({double y, double cb, double cr}) sampleYCbCr(double nx, double ny) {
      final cnx = nx.clamp(0.0, 0.999);
      final cny = ny.clamp(0.0, 0.999);
      int rx;
      int ry;
      if (sensorRotation == 270) {
        rx = ((1.0 - cny) * (rawW - 1)).round();
        ry = (cnx * (rawH - 1)).round();
      } else if (sensorRotation == 90) {
        rx = (cny * (rawW - 1)).round();
        ry = ((1.0 - cnx) * (rawH - 1)).round();
      } else if (sensorRotation == 180) {
        rx = ((1.0 - cnx) * (rawW - 1)).round();
        ry = ((1.0 - cny) * (rawH - 1)).round();
      } else {
        rx = (cnx * (rawW - 1)).round();
        ry = (cny * (rawH - 1)).round();
      }
      rx = rx.clamp(0, rawW - 1);
      ry = ry.clamp(0, rawH - 1);

      if (isBgra) {
        final idx = ry * rowStride0 + rx * 4;
        if (idx + 2 >= bytes0.length) return (y: 128.0, cb: 128.0, cr: 128.0);
        final b = bytes0[idx].toDouble();
        final g = bytes0[idx + 1].toDouble();
        final r = bytes0[idx + 2].toDouble();
        final y = 0.299 * r + 0.587 * g + 0.114 * b;
        final cb = 128.0 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final cr = 128.0 + 0.5 * r - 0.418688 * g - 0.081312 * b;
        return (y: y, cb: cb, cr: cr);
      } else {
        final yIdx = ry * rowStride0 + rx;
        final yVal = yIdx < bytes0.length ? bytes0[yIdx].toDouble() : 128.0;
        double cbVal = 128.0;
        double crVal = 128.0;
        if (bytes1 != null) {
          final uvRow = ry >> 1;
          final uvCol = rx >> 1;
          final uvIdx = uvRow * rowStride1 + uvCol * pixelStride1;
          if (uvIdx + 1 < bytes1.length) {
            // NV21 plane[1] stores V (Cr) followed by U (Cb)
            crVal = bytes1[uvIdx].toDouble();
            cbVal = bytes1[uvIdx + 1].toDouble();
          }
        }
        return (y: yVal, cb: cbVal, cr: crVal);
      }
    }

    final box = face.boundingBox;
    final fx = (box.left / upW).clamp(0.02, 0.98);
    final fy = (box.top / upH).clamp(0.02, 0.98);
    final fw = (box.width / upW).clamp(0.10, 0.95);
    final fh = (box.height / upH).clamp(0.10, 0.95);

    // 1. Calibrate user's live facial skin signature from hairless upper cheeks and forehead (avoids beard)
    final skinPoints = <({double x, double y})>[
      (x: fx + 0.24 * fw, y: fy + 0.56 * fh),
      (x: fx + 0.30 * fw, y: fy + 0.54 * fh),
      (x: fx + 0.76 * fw, y: fy + 0.56 * fh),
      (x: fx + 0.70 * fw, y: fy + 0.54 * fh),
      (x: fx + 0.50 * fw, y: fy + 0.16 * fh),
      (x: fx + 0.50 * fw, y: fy + 0.22 * fh),
    ];

    double skinYSum = 0, skinCbSum = 0, skinCrSum = 0, cheekGradSum = 0;
    for (final pt in skinPoints) {
      final p = sampleYCbCr(pt.x, pt.y);
      final pDown = sampleYCbCr(pt.x, pt.y + 0.015);
      skinYSum += p.y;
      skinCbSum += p.cb;
      skinCrSum += p.cr;
      cheekGradSum += (p.y - pDown.y).abs();
    }
    final skinY = skinYSum / skinPoints.length;
    final skinCb = skinCbSum / skinPoints.length;
    final skinCr = skinCrSum / skinPoints.length;
    final baselineCheekGrad = math.max(3.5, cheekGradSum / skinPoints.length);

    ({double lumDev, double chromaDev}) measureBandAnomaly(
      double x0, double y0, double x1, double y1, int steps,
    ) {
      final top = sampleYCbCr(x0, y0);
      final bot = sampleYCbCr(x1, y1);
      double maxLum = 0.0, maxChroma = 0.0;
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        final p = sampleYCbCr(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
        final expY = top.y + (bot.y - top.y) * t;
        final expCb = top.cb + (bot.cb - top.cb) * t;
        final expCr = top.cr + (bot.cr - top.cr) * t;
        final lDev = (p.y - expY).abs();
        final cDev = math.sqrt((p.cb - expCb) * (p.cb - expCb) + (p.cr - expCr) * (p.cr - expCr)) + lDev * 0.45;
        if (lDev > maxLum) maxLum = lDev;
        if (cDev > maxChroma) maxChroma = cDev;
      }
      return (lumDev: maxLum, chromaDev: maxChroma);
    }

    // 2. Eyeglasses & Sunglasses Check (bilateral + band anomaly so bare eyes & shadows never false-trigger)
    ({double avgY, double maxY, double glareRatio, double darkRatio}) analyzeEye(double eyeCx) {
      double sum = 0, maxY = 0;
      int cnt = 0, glare = 0, dark = 0;
      final eyeCy = fy + 0.39 * fh;
      for (int sy = -1; sy <= 1; sy++) {
        for (int sx = -2; sx <= 2; sx++) {
          final p = sampleYCbCr(eyeCx + sx * 0.025 * fw, eyeCy + sy * 0.015 * fh);
          sum += p.y;
          if (p.y > maxY) maxY = p.y;
          cnt++;
          if (p.y > math.min(242.0, skinY + 72.0) &&
              (p.cb - 128.0).abs() < 12.0 &&
              (p.cr - 128.0).abs() < 12.0) {
            glare++;
          }
          if (skinY > 42.0 && p.y < skinY * 0.28) {
            dark++;
          }
        }
      }
      return (
        avgY: cnt > 0 ? sum / cnt : skinY,
        maxY: maxY,
        glareRatio: cnt > 0 ? glare / cnt : 0.0,
        darkRatio: cnt > 0 ? dark / cnt : 0.0,
      );
    }

    final lEye = analyzeEye(fx + 0.31 * fw);
    final rEye = analyzeEye(fx + 0.69 * fw);

    final isSunglasses = skinY > 42.0 &&
        lEye.avgY < skinY * 0.30 &&
        rEye.avgY < skinY * 0.30 &&
        lEye.maxY < skinY * 0.56 &&
        rEye.maxY < skinY * 0.56 &&
        lEye.darkRatio >= 0.72 &&
        rEye.darkRatio >= 0.72;

    int bridgeColsHit = 0;
    for (final bx in [fx + 0.47 * fw, fx + 0.50 * fw, fx + 0.53 * fw]) {
      final band = measureBandAnomaly(bx, fy + 0.28 * fh, bx, fy + 0.46 * fh, 5);
      if (band.lumDev >= math.max(18.0, baselineCheekGrad * 2.8) && band.chromaDev >= 22.0) {
        bridgeColsHit++;
      }
    }

    bool checkCheekRim(double rx) {
      final band = measureBandAnomaly(rx, fy + 0.46 * fh, rx, fy + 0.57 * fh, 5);
      return band.lumDev >= math.max(16.0, baselineCheekGrad * 2.5) && band.chromaDev >= 18.0;
    }

    final leftRim = checkCheekRim(fx + 0.30 * fw);
    final rightRim = checkCheekRim(fx + 0.70 * fw);
    final bilateralGlare = lEye.glareRatio >= 0.12 && rEye.glareRatio >= 0.12;
    final hasEyeglassFrame = bridgeColsHit >= 2 && ((leftRim && rightRim) || bilateralGlare);
    final wearingGlasses = isSunglasses || hasEyeglassFrame;

    // 3. Bare-Chest / Shirtless / Nudity Check (clean cheek-chroma calibration, works with beards & overhead lighting)
    bool bareChestOrNude = false;
    final chinY = fy + fh;
    final centerX = fx + 0.50 * fw;

    if (chinY < 0.88 && fh > 0.12 && fw > 0.10) {
      bool isSkinPixel(double nx, double ny) {
        if (nx < 0.03 || nx > 0.97 || ny < 0.03 || ny > 0.98) return false;
        final p = sampleYCbCr(nx, ny);
        final chromaDist = math.sqrt(
          (p.cb - skinCb) * (p.cb - skinCb) + (p.cr - skinCr) * (p.cr - skinCr),
        );
        final validSkinChroma = p.cr >= 129.0 &&
            p.cr <= 185.0 &&
            p.cb >= 74.0 &&
            p.cb <= 136.0 &&
            p.cr > p.cb + 5.0 &&
            p.y > math.max(24.0, skinY * 0.45) &&
            p.y < math.min(246.0, skinY * 2.1);
        return validSkinChroma && chromaDist <= 18.0;
      }

      ({double ratio, int total}) sampleTorsoZone(
        double x0,
        double x1,
        double y0,
        double y1,
      ) {
        int hits = 0;
        int total = 0;
        for (int sy = 0; sy <= 3; sy++) {
          final ny = y0 + (y1 - y0) * (sy / 3.0);
          if (ny > 0.97 || ny <= chinY + 0.10 * fh) continue;
          for (int sx = 0; sx <= 3; sx++) {
            final nx = x0 + (x1 - x0) * (sx / 3.0);
            if (nx < 0.03 || nx > 0.97) continue;
            total++;
            if (isSkinPixel(nx, ny)) hits++;
          }
        }
        return (ratio: total > 0 ? hits / total : 0.0, total: total);
      }

      final topTorsoY = chinY + 0.14 * fh;
      final botTorsoY = math.min(0.97, chinY + 0.65 * fh);

      if (botTorsoY - topTorsoY >= 0.06) {
        final leftShoulder = sampleTorsoZone(
          centerX - 0.68 * fw,
          centerX - 0.18 * fw,
          topTorsoY,
          botTorsoY,
        );
        final rightShoulder = sampleTorsoZone(
          centerX + 0.18 * fw,
          centerX + 0.68 * fw,
          topTorsoY,
          botTorsoY,
        );
        final lowerChest = sampleTorsoZone(
          centerX - 0.24 * fw,
          centerX + 0.24 * fw,
          chinY + 0.20 * fh,
          math.min(0.97, chinY + 0.72 * fh),
        );

        final shoulderAvg = (leftShoulder.ratio + rightShoulder.ratio) / 2.0;
        if (leftShoulder.total >= 6 &&
            rightShoulder.total >= 6 &&
            leftShoulder.ratio >= 0.56 &&
            rightShoulder.ratio >= 0.56 &&
            (lowerChest.total < 3 ? shoulderAvg >= 0.65 : (lowerChest.ratio >= 0.50 || shoulderAvg >= 0.72))) {
          bareChestOrNude = true;
        }
      }
    }

    return (wearingGlasses: wearingGlasses, bareChestOrNude: bareChestOrNude);
  }

  /// Capture-time verification on decoded upright image for Eyeglasses & Bare-Chest/Nudity.
  String? _validateDecodedImageGlassesAndAttire(img.Image decoded, Face detected) {
    final upW = decoded.width.toDouble();
    final upH = decoded.height.toDouble();
    if (upW <= 0 || upH <= 0) return null;

    ({double y, double cb, double cr, double r, double g}) samplePx(double nx, double ny) {
      final ix = (nx.clamp(0.0, 0.999) * (decoded.width - 1)).round();
      final iy = (ny.clamp(0.0, 0.999) * (decoded.height - 1)).round();
      final px = decoded.getPixel(ix, iy);
      final r = px.r.toDouble();
      final g = px.g.toDouble();
      final b = px.b.toDouble();
      final y = 0.299 * r + 0.587 * g + 0.114 * b;
      final cb = 128.0 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      final cr = 128.0 + 0.5 * r - 0.418688 * g - 0.081312 * b;
      return (y: y, cb: cb, cr: cr, r: r, g: g);
    }

    final box = detected.boundingBox;
    final fx = (box.left / upW).clamp(0.02, 0.98);
    final fy = (box.top / upH).clamp(0.02, 0.98);
    final fw = (box.width / upW).clamp(0.10, 0.95);
    final fh = (box.height / upH).clamp(0.10, 0.95);

    final skinPoints = <({double x, double y})>[
      (x: fx + 0.24 * fw, y: fy + 0.56 * fh),
      (x: fx + 0.30 * fw, y: fy + 0.54 * fh),
      (x: fx + 0.76 * fw, y: fy + 0.56 * fh),
      (x: fx + 0.70 * fw, y: fy + 0.54 * fh),
      (x: fx + 0.50 * fw, y: fy + 0.16 * fh),
      (x: fx + 0.50 * fw, y: fy + 0.22 * fh),
    ];

    double skinYSum = 0, skinCbSum = 0, skinCrSum = 0, cheekGradSum = 0;
    for (final pt in skinPoints) {
      final p = samplePx(pt.x, pt.y);
      final pDown = samplePx(pt.x, pt.y + 0.015);
      skinYSum += p.y;
      skinCbSum += p.cb;
      skinCrSum += p.cr;
      cheekGradSum += (p.y - pDown.y).abs();
    }
    final skinY = skinYSum / skinPoints.length;
    final skinCb = skinCbSum / skinPoints.length;
    final skinCr = skinCrSum / skinPoints.length;
    final baselineCheekGrad = math.max(3.5, cheekGradSum / skinPoints.length);

    ({double lumDev, double chromaDev}) measureBandAnomaly(
      double x0, double y0, double x1, double y1, int steps,
    ) {
      final top = samplePx(x0, y0);
      final bot = samplePx(x1, y1);
      double maxLum = 0.0, maxChroma = 0.0;
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        final p = samplePx(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
        final expY = top.y + (bot.y - top.y) * t;
        final expCb = top.cb + (bot.cb - top.cb) * t;
        final expCr = top.cr + (bot.cr - top.cr) * t;
        final lDev = (p.y - expY).abs();
        final cDev = math.sqrt((p.cb - expCb) * (p.cb - expCb) + (p.cr - expCr) * (p.cr - expCr)) + lDev * 0.45;
        if (lDev > maxLum) maxLum = lDev;
        if (cDev > maxChroma) maxChroma = cDev;
      }
      return (lumDev: maxLum, chromaDev: maxChroma);
    }

    // Check bare chest / nudity first
    final chinY = fy + fh;
    final centerX = fx + 0.50 * fw;
    if (chinY < 0.88 && fh > 0.12 && fw > 0.10) {
      bool isSkinPixel(double nx, double ny) {
        if (nx < 0.03 || nx > 0.97 || ny < 0.03 || ny > 0.98) return false;
        final p = samplePx(nx, ny);
        final chromaDist = math.sqrt(
          (p.cb - skinCb) * (p.cb - skinCb) + (p.cr - skinCr) * (p.cr - skinCr),
        );
        final validSkinChroma = p.cr >= 129.0 &&
            p.cr <= 185.0 &&
            p.cb >= 74.0 &&
            p.cb <= 136.0 &&
            p.cr > p.cb + 5.0 &&
            p.r >= p.g * 0.88 &&
            p.y > math.max(24.0, skinY * 0.45) &&
            p.y < math.min(246.0, skinY * 2.1);
        return validSkinChroma && chromaDist <= 18.0;
      }

      ({double ratio, int total}) sampleZone(double x0, double x1, double y0, double y1) {
        int hits = 0, total = 0;
        for (int sy = 0; sy <= 3; sy++) {
          final ny = y0 + (y1 - y0) * (sy / 3.0);
          if (ny > 0.97 || ny <= chinY + 0.10 * fh) continue;
          for (int sx = 0; sx <= 3; sx++) {
            final nx = x0 + (x1 - x0) * (sx / 3.0);
            if (nx < 0.03 || nx > 0.97) continue;
            total++;
            if (isSkinPixel(nx, ny)) hits++;
          }
        }
        return (ratio: total > 0 ? hits / total : 0.0, total: total);
      }

      final topTorsoY = chinY + 0.14 * fh;
      final botTorsoY = math.min(0.97, chinY + 0.65 * fh);
      if (botTorsoY - topTorsoY >= 0.06) {
        final leftShoulder = sampleZone(centerX - 0.68 * fw, centerX - 0.18 * fw, topTorsoY, botTorsoY);
        final rightShoulder = sampleZone(centerX + 0.18 * fw, centerX + 0.68 * fw, topTorsoY, botTorsoY);
        final lowerChest = sampleZone(
          centerX - 0.24 * fw,
          centerX + 0.24 * fw,
          chinY + 0.20 * fh,
          math.min(0.97, chinY + 0.72 * fh),
        );

        final shoulderAvg = (leftShoulder.ratio + rightShoulder.ratio) / 2.0;
        if (leftShoulder.total >= 6 &&
            rightShoulder.total >= 6 &&
            leftShoulder.ratio >= 0.56 &&
            rightShoulder.ratio >= 0.56 &&
            (lowerChest.total < 3 ? shoulderAvg >= 0.65 : (lowerChest.ratio >= 0.50 || shoulderAvg >= 0.72))) {
          return "Bare chest or nudity detected. Please wear a shirt or proper clothing covering your chest and shoulders before capturing your observer profile photo.";
        }
      }
    }

    // Check eyeglasses / sunglasses (bilateral + band anomaly)
    ({double avgY, double maxY, double glareRatio, double darkRatio}) analyzeEye(double eyeCx) {
      double sum = 0, maxY = 0;
      int cnt = 0, glare = 0, dark = 0;
      final eyeCy = fy + 0.39 * fh;
      for (int sy = -1; sy <= 1; sy++) {
        for (int sx = -2; sx <= 2; sx++) {
          final p = samplePx(eyeCx + sx * 0.025 * fw, eyeCy + sy * 0.015 * fh);
          sum += p.y;
          if (p.y > maxY) maxY = p.y;
          cnt++;
          if (p.y > math.min(242.0, skinY + 72.0) &&
              (p.cb - 128.0).abs() < 12.0 &&
              (p.cr - 128.0).abs() < 12.0) {
            glare++;
          }
          if (skinY > 42.0 && p.y < skinY * 0.28) {
            dark++;
          }
        }
      }
      return (
        avgY: cnt > 0 ? sum / cnt : skinY,
        maxY: maxY,
        glareRatio: cnt > 0 ? glare / cnt : 0.0,
        darkRatio: cnt > 0 ? dark / cnt : 0.0,
      );
    }

    final lEye = analyzeEye(fx + 0.31 * fw);
    final rEye = analyzeEye(fx + 0.69 * fw);

    final isSunglasses = skinY > 42.0 &&
        lEye.avgY < skinY * 0.30 &&
        rEye.avgY < skinY * 0.30 &&
        lEye.maxY < skinY * 0.56 &&
        rEye.maxY < skinY * 0.56 &&
        lEye.darkRatio >= 0.72 &&
        rEye.darkRatio >= 0.72;

    int bridgeColsHit = 0;
    for (final bx in [fx + 0.47 * fw, fx + 0.50 * fw, fx + 0.53 * fw]) {
      final band = measureBandAnomaly(bx, fy + 0.28 * fh, bx, fy + 0.46 * fh, 5);
      if (band.lumDev >= math.max(18.0, baselineCheekGrad * 2.8) && band.chromaDev >= 22.0) {
        bridgeColsHit++;
      }
    }

    bool checkCheekRim(double rx) {
      final band = measureBandAnomaly(rx, fy + 0.46 * fh, rx, fy + 0.57 * fh, 5);
      return band.lumDev >= math.max(16.0, baselineCheekGrad * 2.5) && band.chromaDev >= 18.0;
    }

    final leftRim = checkCheekRim(fx + 0.30 * fw);
    final rightRim = checkCheekRim(fx + 0.70 * fw);
    final bilateralGlare = lEye.glareRatio >= 0.12 && rEye.glareRatio >= 0.12;
    final hasEyeglassFrame = bridgeColsHit >= 2 && ((leftRim && rightRim) || bilateralGlare);

    if (isSunglasses || hasEyeglassFrame) {
      return "Eyeglasses or sunglasses detected. Please remove your glasses so your eyes are clearly visible and retry.";
    }

    return null;
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

      // Free Flutter's memory image cache before decoding still photo (prevents OOM on 1GB RAM phones)
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}

      Uint8List? finalJpgBytes;
      img.Image? enrolledFaceImage;
      final capturedTempFile = File(photo.path);
      final rawBytes = await capturedTempFile.readAsBytes();
        img.Image? decoded = img.decodeImage(rawBytes);

        if (decoded != null) {
          // 1. Correct EXIF orientation so front selfie is 100% upright
          decoded = img.bakeOrientation(decoded);

          // 1b. Memory cap for 1GB RAM phones: downscale oversized sensor captures (>1080px) immediately
          if (decoded.width > 1080 || decoded.height > 1080) {
            decoded = decoded.width >= decoded.height
                ? img.copyResize(decoded, width: 1080, interpolation: img.Interpolation.linear)
                : img.copyResize(decoded, height: 1080, interpolation: img.Interpolation.linear);
          }

          final orientedTempFile = File("${capturedTempFile.path}_upright.jpg");
          await orientedTempFile.writeAsBytes(img.encodeJpg(decoded, quality: 88));

          int cropX = 0;
          int cropY = 0;
          final minSide = decoded.width < decoded.height ? decoded.width : decoded.height;
          int cropDim = minSide;

          // Guard against blank/all-black camera frames before processing
          {
            int totalLum = 0;
            int maxCh = 0;
            int samples = 0;
            final stepX = (decoded.width / 24).ceil().clamp(1, decoded.width);
            final stepY = (decoded.height / 24).ceil().clamp(1, decoded.height);
            for (int sy = 0; sy < decoded.height; sy += stepY) {
              for (int sx = 0; sx < decoded.width; sx += stepX) {
                final px = decoded.getPixel(sx, sy);
                final r = px.r.toInt();
                final g = px.g.toInt();
                final b = px.b.toInt();
                totalLum += ((0.299 * r) + (0.587 * g) + (0.114 * b)).round();
                if (r > maxCh) maxCh = r;
                if (g > maxCh) maxCh = g;
                if (b > maxCh) maxCh = b;
                samples++;
              }
            }
            final avgLum = samples > 0 ? totalLum / samples : 0.0;
            if (avgLum < 6.0 && maxCh < 18) {
              try {
                if (await orientedTempFile.exists()) {
                  await orientedTempFile.delete();
                }
              } catch (_) {}
              _showErrorDialog(
                "Captured photo was blank or too dark. Please ensure good lighting and uncover your front camera, then retry.",
              );
              return;
            }
          }

          String? validationError;
          try {
            final detectedFaces = await _faceDetector.processImage(
              InputImage.fromFilePath(orientedTempFile.path),
            );

            if (detectedFaces.isEmpty) {
              validationError =
                  "No full face was detected in the captured photo. Please hold the phone at eye level with your entire face inside the oval and retry.";
            } else {
              final detected = detectedFaces.first;
              final face = detected.boundingBox;
              final yawAngle = (detected.headEulerAngleY ?? 0.0).abs();
              final pitchAngle = (detected.headEulerAngleX ?? 0.0).abs();
              final isClipped = face.left < decoded.width * 0.03 ||
                  face.right > decoded.width * 0.97 ||
                  face.top < decoded.height * 0.03 ||
                  face.bottom > decoded.height * 0.97;
              final isTooSmall = face.height < decoded.height * 0.20;

              if (isClipped || isTooSmall || yawAngle > 20 || pitchAngle > 20) {
                validationError =
                    "Your face did not fully fit inside the round facial circle. Please move closer and center your full face (forehead to chin) inside the round circle and retry.";
              } else {
                // Verify eyeglasses and attire (bare chest / nudity) on the captured portrait
                final complianceErr = _validateDecodedImageGlassesAndAttire(decoded, detected);
                if (complianceErr != null) {
                  validationError = complianceErr;
                } else {
                  // Full-head passport crop: includes entire head, hair, chin, and collar
                  final desiredDim = (face.height * 1.95)
                      .clamp(240.0, minSide.toDouble())
                      .toDouble();
                  final halfDim = desiredDim / 2;

                  final targetX = face.center.dx;
                  final targetY = face.center.dy - (face.height * 0.05);

                  cropX = (targetX - halfDim).round();
                  cropY = (targetY - halfDim).round();
                  cropDim = desiredDim.round();
                }
              }
            }
          } catch (e) {
            debugPrint("Detector error during crop: $e");
            validationError =
                "Could not verify a clear full face in the captured photo. Please retry.";
          } finally {
            try {
              if (await orientedTempFile.exists()) {
                await orientedTempFile.delete();
              }
            } catch (_) {}
          }

          if (validationError != null) {
            _showErrorDialog(validationError);
            return;
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

          // 2. Adaptive avatar resize: 640x640 on 1GB RAM / lagging devices, 800x800 on standard devices
          final outDim = _isLaggingDevice ? 640 : 800;
          var hdAvatar = img.copyResize(
            cropped,
            width: outDim,
            height: outDim,
            interpolation: img.Interpolation.linear,
          );

          // 3. Studio-grade contrast expansion & color vibrancy (+15% contrast, +12% saturation)
          hdAvatar = img.adjustColor(
            hdAvatar,
            contrast: 1.15,
            saturation: 1.12,
          );

          enrolledFaceImage = hdAvatar;
          finalJpgBytes = Uint8List.fromList(img.encodeJpg(hdAvatar, quality: 92));
        }

      final effectiveBytes = finalJpgBytes ?? await File(photo.path).readAsBytes();
      try {
        if (await capturedTempFile.exists()) {
          await capturedTempFile.delete();
        }
      } catch (_) {}

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
        _uploadStatusText = "Uploading biometric portrait to Database Storage...";
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

      // 6. Biometric Deduplication Audit against all enrolled observers (reuses enrolledFaceImage to avoid duplicate decode on 1GB RAM devices)
      setState(() {
        _uploadStatusText = "Analyzing facial biometrics & checking for duplicate accounts...";
      });

      final faceForEmbedding = enrolledFaceImage ?? img.decodeImage(effectiveBytes)!;
      final auditResult = await BiometricDeduplicationService().auditAndEnrollFace(
        user: user,
        faceImage: faceForEmbedding,
        effectiveBytes: effectiveBytes,
        downloadUrl: downloadUrl,
        localFilePath: localFilePath,
      );

      // 7. Cache flags locally in secure storage
      await _storage.write(key: "isFaceEnrolled_${user.uid}", value: "true");
      await _storage.write(key: "local_profile_image_path_${user.uid}", value: localFilePath);
      await _storage.write(key: "profilePictureUrl_${user.uid}", value: downloadUrl);

      setState(() {
        _step = LivenessStep.completed;
      });

      if (!mounted) return;

      if (auditResult.isDuplicate) {
        // Show advisory alert explaining the biometric match and potential duplicate notice
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Potential Duplicate Account",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Our biometric system detected that this facial portrait has a potential similarity match with an existing registered observer account. Your reporting access remains enabled.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "POTENTIAL MATCH DETAILS",
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      _buildConflictRow("Name:", auditResult.matchedName ?? "Observer"),
                      const SizedBox(height: 4),
                      _buildConflictRow("Email:", auditResult.matchedEmail ?? "N/A"),
                      if (auditResult.matchedRole != null && auditResult.matchedRole!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildConflictRow("Role:", auditResult.matchedRole!.toUpperCase()),
                      ],
                      const SizedBox(height: 4),
                      _buildConflictRow("Match Confidence:", "${(auditResult.similarity * 100).toStringAsFixed(1)}%"),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "This record has been logged for administrative audit. As an accredited observer, you may proceed to your polling unit dashboard.",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CONTINUE TO DASHBOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✨ Liveness Verified! Unique observer profile enrolled!"),
            backgroundColor: AppColors.accent,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (!mounted) return;
      if (auditResult.isDuplicate) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardRedirect.getTargetScreen(context),
          ),
          (route) => false,
        );
      } else if (widget.isModal) {
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

  Widget _buildConflictRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
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
    final previewSize = _cameraController!.value.previewSize;
    final previewW = previewSize != null ? previewSize.height : 480.0;
    final previewH = previewSize != null ? previewSize.width : 640.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final circleDiameter = math.min(screenW * 0.82, screenH * 0.48).clamp(240.0, 360.0);
        final circleCenterY = (screenH - 180).clamp(circleDiameter * 0.6, screenH * 0.44);
        final ringColor = isCapturingOrDone
            ? AppColors.accent
            : (_isFaceFittedInCircle ? Colors.cyanAccent : Colors.amberAccent);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-Screen Edge-to-Edge Live Camera Feed
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: previewW,
                    height: previewH,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),

            // 2. Darkened Surround with Round Facial Circle Cutout & Ring Border
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CircularFaceCutoutPainter(
                    center: Offset(screenW / 2, circleCenterY),
                    radius: circleDiameter / 2,
                    borderColor: ringColor,
                  ),
                ),
              ),
            ),

            // 3. Top Face-Fit Status Pill & Bottom Action Pill on the Round Facial Circle
            Positioned(
              left: (screenW - circleDiameter) / 2,
              top: circleCenterY - circleDiameter / 2,
              width: circleDiameter,
              height: circleDiameter,
              child: IgnorePointer(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Top Face-Fit Status Pill
                    Positioned(
                      top: -14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isFaceFittedInCircle
                              ? const Color(0xFF065F46)
                              : const Color(0xFF78350F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isFaceFittedInCircle ? AppColors.accent : Colors.amberAccent,
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          _faceFitHint,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Action Pill Badge floating on the circle bottom
                    Positioned(
                      bottom: -14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ringColor,
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
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
                              color: ringColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getActionBadgeText(),
                              style: const TextStyle(
                                color: Colors.white,
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

            // 4. Flash animation effect on capture
            if (_step == LivenessStep.capturing)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),

            // 5. Real-time Eyeglasses / Bare-Chest Warning Banner Overlay at Top
            if (_complianceWarningTitle != null)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _complianceWarningTitle!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (_complianceWarningDetail != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                _complianceWarningDetail!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 6. Floating Bottom HUD & Action Controls over Full-Screen Camera
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                "${(_progress * 100).round()}%",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _subInstruction,
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF991B1B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 14, color: Colors.amberAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),

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

                  if (!isCapturingOrDone && _step != LivenessStep.uploading) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _handleManualInstantCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFF0D9488).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "CAPTURE PHOTO & VERIFY NOW",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Row(
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
                      const SizedBox(width: 6),
                      const Text(
                        "🔒 Anti-Spoofing Active • Full-Screen Circular Face Fit",
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
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

class _CircularFaceCutoutPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color borderColor;

  const _CircularFaceCutoutPainter({
    required this.center,
    required this.radius,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final overlayPaint = Paint()
      ..color = const Color(0xFF020617).withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // Outer glow ring
    final glowPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0;
    canvas.drawCircle(center, radius, glowPaint);

    // Primary circular border
    final ringPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner subtle guide circle
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius - 10, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularFaceCutoutPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.borderColor != borderColor;
  }
}
