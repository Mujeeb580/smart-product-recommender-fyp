import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "home",
      theme: ThemeData(useMaterial3: true),
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
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Top Search Header ====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.fromARGB(255, 30, 34, 241), Color(0xFFDB2777)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Hello User,",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "What are you looking for?",
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search electronics...",
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.mic,
                            color: Color.fromARGB(255, 2, 1, 3),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== Categories =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Categories",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _categoryCard(
                  icon: Icons.phone_android,
                  title: "Mobiles",
                  subtitle: "250+ models",
                  color: Colors.blue,
                ),
                _categoryCard(
                  icon: Icons.laptop_mac,
                  title: "Laptops",
                  subtitle: "180+ models",
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ===== Quick Filters =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Quick Filters",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _filterChip(
                  icon: Icons.attach_money,
                  label: "Budget",
                  color: Colors.green,
                ),
                _filterChip(
                  icon: Icons.local_offer,
                  label: "Brand",
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===== AI Recommendations =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAFBF1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB8E3CB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          "AI Recommendations",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Get personalized suggestions based on your preferences",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          "View Recommendations",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // ===== Bottom Navigation =====
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ==== Category Card Widget ====
Widget _categoryCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Container(
    width: 150,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    ),
  );
}

// ==== Filter Chip Widget ====
Widget _filterChip({
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
