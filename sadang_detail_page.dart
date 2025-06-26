import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';
import 'solution_page.dart';

// Main SadangDetailPage (unchanged from your working code)
class SadangDetailPage extends StatefulWidget {
  const SadangDetailPage({super.key});

  @override
  State<SadangDetailPage> createState() => _SadangDetailPageState();
}

class _SadangDetailPageState extends State<SadangDetailPage> {
  int selectedIndex = 0;
  XFile? selectedImage;

  Uint8List? imageBytes; // 서버에서 받은 결과 이미지 바이트
  List<Map<String, dynamic>> holdRects = [];
  Set<int> selectedIndices = {};

  final List<Map<String, String>> tabs = [
    {'image': 'assets/images/for_you.jpg', 'label': 'For you'},
    {'image': 'assets/images/classics.jpg', 'label': 'Classics'},
    {'image': 'assets/images/populars.png', 'label': 'Popular'},
    {'image': 'assets/images/favorites.jpg', 'label': 'Favorites'},
  ];

  final List<String> gridImages = [
    'assets/images/post1.jpg',
    'assets/images/post2.jpg',
    'assets/images/post3.jpg',
    'assets/images/post4.jpg',
    'assets/images/post5.jpg',
    'assets/images/post6.jpg',
    'assets/images/post7.jpg',
    'assets/images/post8.jpg',
    'assets/images/post9.jpg',
    'assets/images/post10.jpg',
    'assets/images/post11.jpg',
  ];

  double imageOriginalWidth = 1.0;
  double imageOriginalHeight = 1.0;

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      selectedImage = image;
      imageBytes = null; // 초기화
      holdRects.clear();
      selectedIndices.clear();
    });

    try {
      final bytes = await image.readAsBytes();

      final uri = Uri.parse('http://192.168.123.103:5000/upload'); // 서버 주소
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: image.name),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final decoded = jsonDecode(respStr);

        imageOriginalWidth = decoded['image_size']['width'].toDouble();
        imageOriginalHeight = decoded['image_size']['height'].toDouble();

        final imgResponse =
            await http.get(Uri.parse('http://192.168.123.103:5000/results/result.jpg'));

        setState(() {
          imageBytes = imgResponse.bodyBytes;
          holdRects = List<Map<String, dynamic>>.from(decoded['boxes']);
          selectedIndices.clear();
        });

        // 팝업 띄우기
        _showImageDialog(
          context: context,
          imageBytes: imageBytes,
          imageOriginalWidth: imageOriginalWidth,
          imageOriginalHeight: imageOriginalHeight,
          holdRects: holdRects,
          selectedIndices: selectedIndices,
          onSelectionChanged: (updated) {
            setState(() {
              selectedIndices = updated;
            });
          },
        );
      } else {
        // Handle server error for upload
        print('Image upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Handle network or parsing errors
      print('Error picking or uploading image: $e');
    }
  }

  
  void _showImageDialog({
    required BuildContext context,
    required Uint8List? imageBytes,
    required double imageOriginalWidth,
    required double imageOriginalHeight,
    required List<Map<String, dynamic>> holdRects,
    required Set<int> selectedIndices,
    required void Function(Set<int>) onSelectionChanged,
  }) {
  Set<int> tempSelected = {...selectedIndices};

  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final displayedWidth = screenWidth * 0.9; // 90% 너비
  final aspectRatio = imageOriginalHeight == 0 ? 1.0 : imageOriginalWidth / imageOriginalHeight;
  final displayedHeight = displayedWidth / aspectRatio;

  final buttonHeight = 56.0; // 버튼 높이 (패딩 포함 예상)
  final spaceBetween = 24.0; // 이미지와 버튼 사이 간격

  final scaleX = displayedWidth / imageOriginalWidth;
  final scaleY = displayedHeight / imageOriginalHeight;

  // 이미지와 버튼 전체 높이
  final totalHeight = displayedHeight + spaceBetween + buttonHeight;

  // 화면 세로 중앙에 전체 묶음이 위치하도록 계산
  final startTop = (screenHeight - totalHeight) / 2;

  showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'ImageDialog',
  barrierColor: Colors.black.withOpacity(0.8),
  pageBuilder: (context, animation1, animation2) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: startTop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: displayedWidth,
                  height: displayedHeight,
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          imageBytes!,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (PointerDownEvent event) {
                            final localX = event.localPosition.dx;
                            final localY = event.localPosition.dy;

                            final overlappingBoxes = holdRects.asMap().entries.where((entry) {
                              final rect = entry.value;
                              final double x = rect['x1'] * scaleX;
                              final double y = rect['y1'] * scaleY;
                              final double w = (rect['x2'] - rect['x1']) * scaleX;
                              final double h = (rect['y2'] - rect['y1']) * scaleY;

                              return localX >= x &&
                                  localX <= x + w &&
                                  localY >= y &&
                                  localY <= y + h;
                            }).toList();
                            if (overlappingBoxes.isNotEmpty) {
                              overlappingBoxes.sort((a, b) {
                                final r1 = a.value;
                                final r2 = b.value;
                                final aArea = (r1['x2'] - r1['x1']) * (r1['y2'] - r1['y1']);
                                final bArea = (r2['x2'] - r2['x1']) * (r2['y2'] - r2['y1']);
                                return aArea.compareTo(bArea);
                              });

                              final selectedIdx = overlappingBoxes.first.key;
                              if (tempSelected.contains(selectedIdx)) {
                                tempSelected.remove(selectedIdx);
                              } else {
                                tempSelected.add(selectedIdx);
                              }
                              (context as Element).markNeedsBuild();
                            }
                          },
                        ),
                      ),
                      ...holdRects.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final rect = entry.value;

                        final double x = rect['x1'] * scaleX;
                        final double y = rect['y1'] * scaleY;
                        final double w = (rect['x2'] - rect['x1']) * scaleX;
                        final double h = (rect['y2'] - rect['y1']) * scaleY;

                        final bool selected = tempSelected.contains(idx);

                        return Positioned(
                          left: x,
                          top: y,
                          width: w,
                          height: h,
                          child: GestureDetector(
                            onTap: () {
                              if (tempSelected.contains(idx)) {
                                tempSelected.remove(idx);
                              } else {
                                tempSelected.add(idx);
                              }
                              (context as Element).markNeedsBuild();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected ? Colors.red : Colors.green,
                                  width: 2,
                                ),
                                color: selected ? Colors.red.withOpacity(0.3) : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: startTop + displayedHeight + spaceBetween,
              left: 16,
              right: 16,
              // GestureDetector의 child가 여기서 시작해야 합니다.
              child: GestureDetector(
                onTap: () async {
                  final List<Map<String, dynamic>> selectedBoxes = tempSelected.map((index) {
                    return holdRects[index];
                  }).toList();

                  final response = await http.post(
                    Uri.parse('http://192.168.123.103:5000/compare'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'image': base64Encode(imageBytes!),
                      'boxes': selectedBoxes,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final results = jsonDecode(response.body)['results'];

                    Navigator.of(context).pop(); // 현재 다이얼로그 닫기

                    /*Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerPage(
                          videoFilenames: videoFileNames,
                          initialIndex: 0,
                        ),
                      ),
                    );*/

                    // 5. SolutionPage로 이동합니다. 이때 유사도 결과(results)를 넘겨줍니다.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SolutionPage(results: results),
                      ),
                    );
                  }
                },
                // 여기가 GestureDetector의 child입니다.
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFa8e6cf),
                        Color(0xFF00c853),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Text(
                    'Next Step',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ), // <-- 여기 괄호가 닫혀야 합니다.
            ) // <-- Positioned 위젯의 닫는 괄호
          ],
        ),
      ),
    );
  },
);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WillPopScope(
            onWillPop: () async {
              FocusScope.of(context).unfocus();
              return true;
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/images/sadang_background.jpg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 250,
                          ),
                          Container(
                            width: double.infinity,
                            height: 250,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                                stops: [0.6, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 20,
                      child: IconButton(
                        icon:
                            const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const Positioned(
                      top: 40,
                      right: 20,
                      child: Icon(Icons.more_vert, color: Colors.white, size: 28),
                    ),
                    Positioned(
                      top: 180,
                      left: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'The Climb - Sadang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.verified, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: List.generate(tabs.length, (index) {
                          final item = tabs[index];
                          final isSelected = index == selectedIndex;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            isSelected ? Colors.green : Colors.grey,
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        item['image']!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['label']!,
                                    style:
                                        const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 8, right: 8, bottom: 80),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: gridImages.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            gridImages[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFa8e6cf),
                      Color(0xFF00c853),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Text(
                  'Image upload for Any Solutions!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

