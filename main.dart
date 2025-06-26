import 'package:flutter/material.dart';
import 'sadang_detail_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedBottomIndex = 0;

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 120.0, left: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hey, Elmo!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Where are you climbing today?',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SearchInputField(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 0.0),
                    child: SizedBox(
                      width: screenWidth * 1,
                      child: const TabBar(
                        isScrollable: true,
                        labelColor: Colors.green,
                        unselectedLabelColor: Colors.white30,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold),
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(width: 0.5, color: Colors.green),
                        ),
                        indicatorSize: TabBarIndicatorSize.label,
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.only(right: 30, left: 0),
                        tabs: [
                          Tab(text: 'Locations'),
                          Tab(text: 'Popular'),
                          Tab(text: 'Offline Media'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    color: Colors.black,
                    thickness: 0.5,
                    height: 10,
                  ),

                  // 탭바 바로 아래 Locations / See all Row 추가 (여기서 바로 띄움)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Locations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'See all',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SizedBox(
                    height: 270, // 세로 박스 3개에 적당한 높이 (조절 가능)
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _locationBox(context, 'The Climb - Sadang', 'assets/images/sadang.jpg'),
                          const SizedBox(height: 12),
                          _locationBox(context, 'The Climb - gangnam', 'assets/images/gangnam.jpg'),
                          const SizedBox(height: 12),
                          _locationBox(context, 'Bishop Climbing gym', 'assets/images/bishop.png'),
                        ],
                      ),
                    ),
                  ),
                ),

                // 아래 나머지 영역을 탭바뷰가 차지하도록 Expanded
                Expanded(
                  child: TabBarView(
                    children: [
                      // Locations 탭 내용 (위에서 이미 제목을 보여줬으니 빈 컨테이너로 둬도 됨)
                      Container(
                        color: Colors.transparent,
                        // 여기에 Locations 탭 세부 내용 추가 가능
                      ),

                        // Popular 탭 (임시 빈 화면)
                        Container(),

                        // Offline Media 탭 (임시 빈 화면)
                        Container(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 좌측 상단 바위 로고
            const Positioned(
              top: 40,
              left: 20,
              child: Icon(
                Icons.terrain,
                color: Colors.white,
                size: 28,
              ),
            ),
            // 우측 상단 알림 + 채팅 아이콘
            const Positioned(
              top: 40,
              right: 20,
              child: Row(
                children: [
                  Icon(Icons.notifications_none, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Icon(Icons.forum_rounded, color: Colors.white, size: 26),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          currentIndex: _selectedBottomIndex,
          onTap: _onBottomNavTap,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.white30,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_activity_outlined),
              activeIcon: Icon(Icons.local_activity),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

}

class SearchInputField extends StatelessWidget {
  const SearchInputField({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const TextField(
        autofocus: false,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: 'Climbs, locations and people...',
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

Widget _locationBox(BuildContext context, String title, String imagePath) {
  return GestureDetector(
    onTap: () {
      if (title == 'The Climb - Sadang') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SadangDetailPage()),
        );
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 26, 25, 25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Image.asset(
              imagePath,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '5k followers | 12k ascent',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
