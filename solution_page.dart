// lib/solution_page.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SolutionPage extends StatelessWidget {
  final List<dynamic> results; // 유사도 결과 리스트 (서버에서 받은 그대로)

  const SolutionPage({super.key, required this.results});

  // 동영상 썸네일 URL을 생성하는 함수
  String _getVideoThumbnailUrl(String? filename) {
    if (filename == null || filename.isEmpty) {
      return ''; // 유효하지 않은 경우 빈 문자열 반환
    }
    // 가정: 썸네일은 static 폴더에 'filename.jpg' 형식으로 존재하거나
    // 비디오 서버에서 직접 썸네일을 제공할 수 있음
    // 현재는 비디오 경로와 동일한 서버에서 'static/' 프리픽스를 사용한다고 가정
    return 'http://192.168.123.103:5000/thum/${filename.split('.').first}.png';
  }

  // 동영상 파일 URL을 생성하는 함수
  String _getVideoUrl(String? filename) {
    if (filename == null || filename.isEmpty) {
      return '';
    }
    return 'http://192.168.123.103:5000/video/$filename';
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> displayResults = List.from(results);
    while (displayResults.length < 9) {
      displayResults.add(null); // 9개 미만이면 null로 채워서 빈칸 처리
    }
    final List<dynamic> nineItems = displayResults.take(9).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Column 내부 위젯들을 중앙 정렬 (수평)
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Align(
              alignment: Alignment.center,
              child: Column( // "Solutions for you!" 텍스트와 "Just click it"을 함께 묶기 위해 Column 추가
                mainAxisSize: MainAxisSize.min, // 필요한 만큼만 공간 차지
                children: [
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFFa8e6cf),
                          Color(0xFF00c853),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'Solutions for you!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24), // 두 텍스트 사이의 간격 조절
                  const Text(
                    'Just click it',
                    style: TextStyle(
                      color: Colors.white, // 하얀색 텍스트
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      // fontWeight: FontWeight.bold, // 필요하다면 굵게
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 0), // Solutions for you! + Just click it 텍스트와 그리드 사이의 간격

          Spacer(),

          Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container( // 그리드 전체를 감싸는 테두리 Container
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // 테두리 모서리 둥글게
                    gradient: const LinearGradient( // 테두리 그라디언트
                      colors: [
                        Color(0xFFa8e6cf),
                        Color(0xFF00c853),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    // 그라디언트 테두리 두께 조절 (Border.all 대신 BoxShadow 사용)
                    boxShadow: [
                      BoxShadow(
                        color: Colors.transparent, // 실제 그림자는 아님
                        spreadRadius: 2, // 테두리 두께
                        blurRadius: 0,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                  child: ClipRRect( // 테두리 밖으로 그리드 내용이 넘어가지 않도록 클리핑
                    borderRadius: BorderRadius.circular(10), // 테두리보다 살짝 작게 (내부 간격)
                    child: Container(
                      color: Colors.black, // 그리드 배경색 (테두리 안쪽)
                      padding: const EdgeInsets.all(2), // 테두리와 그리드 사이의 간격
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(), // 그리드 뷰 내부 스크롤 방지
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final item = nineItems[index];
                          final videoFilename = item?["video"] as String?;
                          final thumFilename = item?["filename"] as String?;

                          final thumbnailUrl = _getVideoThumbnailUrl(thumFilename);

                          if (videoFilename == null || videoFilename.isEmpty) {
                            return Container(
                              color: Colors.black,
                              child: Center(
                                child: Text(
                                  'No Video',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                ),
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(
                                    videoFilename: videoFilename,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnailUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('썸네일 로드 실패: $thumbnailUrl, 에러: $error');
                                  return Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Text(
                                        'Load Failed',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
          Spacer(),
        ],
        ),
        );
      
  }

}

class VideoPlayerPage extends StatefulWidget {
  final String videoFilename; // 단일 동영상 파일 이름만 받습니다.

  const VideoPlayerPage({
    super.key,
    required this.videoFilename,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    final videoUrl = 'http://192.168.123.103:5000/video/${widget.videoFilename}';
    print('재생할 비디오 URL: $videoUrl');

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // 초기화 완료 후 바로 재생
      _controller.play();
      // 루프 재생 (선택 사항)
      _controller.setLooping(true);
      setState(() {}); // UI 업데이트
    }).catchError((error) {
      print('비디오 컨트롤러 초기화 오류: $error');
      // 에러 처리: 사용자에게 메시지 표시 등
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 배경색 검정
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 투명 AppBar
        elevation: 0, // 그림자 제거
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(); // 비디오 페이지 닫기
          },
        ),
      ),
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // 비디오 컨트롤러가 초기화되었다면 비디오를 표시
            if (_controller.value.isInitialized) {
              return Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              );
            } else {
              // 초기화는 완료되었으나 유효하지 않은 경우 (예: 파일 없음)
              return const Center(
                child: Text('비디오를 로드할 수 없습니다.', style: TextStyle(color: Colors.white)),
              );
            }
          } else if (snapshot.hasError) {
            // 초기화 중 오류 발생
            return Center(
              child: Text(
                '비디오 로드 중 오류 발생: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else {
            // 비디오 컨트롤러 초기화 중
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
      // 비디오 컨트롤 버튼 (재생/일시정지) 추가
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        backgroundColor: Colors.black,
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // 버튼 중앙 하단에 배치
    );
  }
}