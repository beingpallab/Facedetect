import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'face_detector_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FaceSmileApp());
}

class FaceSmileApp extends StatelessWidget {
  const FaceSmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection & Smile Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  ui.Image? _decodedImage;
  List<Face> _faces = [];
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();

  // ML Kit Face Detector with smile classification enabled
  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Enables smile & eye open probability
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  // Handle picking image from device gallery
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isProcessing = true;
        _faces = [];
        _decodedImage = null;
      });

      await _processImage(_selectedImage!);
    }
  }

  // Process image for face detection & smile classification
  Future<void> _processImage(File imageFile) async {
    try {
      // Decode image for CustomPainter calculations
      final bytes = await imageFile.readAsBytes();
      final ui.Image decoded = await decodeImageFromList(bytes);

      // Convert to InputImage for ML Kit
      final inputImage = InputImage.fromFile(imageFile);

      // Run ML Kit Face Detection
      final List<Face> detectedFaces = await _faceDetector.processImage(inputImage);

      setState(() {
        _decodedImage = decoded;
        _faces = detectedFaces;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    }
  }

  // Calculate smiling analytics
  int get _totalFaces => _faces.length;

  int get _smilingFacesCount {
    return _faces.where((face) {
      final double prob = face.smilingProbability ?? 0.0;
      return prob >= 0.70; // 70% threshold rule
    }).length;
  }

  double get _smilingPercentage {
    if (_totalFaces == 0) return 0.0;
    return (_smilingFacesCount / _totalFaces) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Detection & Smile Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload / Pick Action Button
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickImage,
              icon: Icon(_selectedImage == null ? Icons.add_photo_alternate : Icons.refresh),
              label: Text(
                _selectedImage == null ? 'Upload Image from Gallery' : 'Choose Another Image',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Main Display Area (Image Preview + Overlay / Loader)
            if (_isProcessing)
              const ContainerCard(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Analyzing faces and smiles...'),
                    ],
                  ),
                ),
              )
            else if (_selectedImage != null && _decodedImage != null) ...[
              // Image Preview with Bounding Box Painter
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double aspect = _decodedImage!.width / _decodedImage!.height;
                    return AspectRatio(
                      aspectRatio: aspect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          CustomPaint(
                            painter: FaceDetectorPainter(
                              faces: _faces,
                              image: _decodedImage!,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Summary Analytics Cards
              Row(
                children: [
                  Expanded(
                    child: AnalyticsCard(
                      title: 'Total Faces',
                      value: '$_totalFaces',
                      icon: Icons.people_alt,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsCard(
                      title: 'Smiling %',
                      value: '${_smilingPercentage.toStringAsFixed(1)}%',
                      icon: Icons.sentiment_very_satisfied,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Individual Face Details Section
              const Text(
                'Individual Face Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_faces.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No faces detected in this image.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _faces.length,
                  itemBuilder: (context, index) {
                    final face = _faces[index];
                    final double smileProb = face.smilingProbability ?? 0.0;
                    final bool isSmiling = smileProb >= 0.70;
                    final int smilePercent = (smileProb * 100).round();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSmiling ? Colors.green.shade100 : Colors.grey.shade200,
                          child: Icon(
                            isSmiling ? Icons.sentiment_satisfied_alt : Icons.sentiment_neutral,
                            color: isSmiling ? Colors.green : Colors.grey,
                          ),
                        ),
                        title: Text(
                          'Face ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Smile Probability: $smilePercent%'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSmiling ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSmiling ? Colors.green : Colors.orange,
                            ),
                          ),
                          child: Text(
                            isSmiling ? 'Smiling' : 'Not Smiling',
                            style: TextStyle(
                              color: isSmiling ? Colors.green.shade800 : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // Placeholder State before initial upload
              Card(
                elevation: 0,
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.face_retouching_natural, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No image uploaded yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Reusable Helper Widget for Analytics Stats Cards
class AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerCard extends StatelessWidget {
  final Widget child;
  const ContainerCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}