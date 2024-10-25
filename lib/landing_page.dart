import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For session management
import 'monitor.dart'; // Import the monitor page
import 'engage.dart'; // Import the engage page
import 'dart:async'; // For timing session expiration

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _currentIndex = 0; // Track the currently selected tab

  @override
  void initState() {
    super.initState();
    _checkSession(); // Check session upon landing
  }

  Future<void> _checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signup');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('APMA'),
          backgroundColor: const Color(0xFF00C853),
          automaticallyImplyLeading: false, // Hides the back button
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: IndexedStack(
            index: _currentIndex,
            children: [
              // Home Page (Current Content)
              Column(
                children: [
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 1,
                      childAspectRatio: 2.0,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MonitorPage()),
                            );
                          },
                          child: Card(
                            color: const Color.fromARGB(255, 144, 248, 187),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.monitor, size: 40, color: Colors.white),
                                  SizedBox(height: 10),
                                  Text(
                                    'Monitor Animals',
                                    style: TextStyle(color: Colors.white, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            // Add a Reports page navigation if needed
                          },
                          child: Card(
                            color: const Color.fromARGB(255, 148, 240, 186),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.analytics, size: 40, color: Colors.white),
                                  SizedBox(height: 10),
                                  Text(
                                    'Get Reports',
                                    style: TextStyle(color: Colors.white, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EngagePage()),
                            );
                          },
                          child: Card(
                            color: const Color.fromARGB(255, 159, 234, 191),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.group, size: 40, color: Colors.white),
                                  SizedBox(height: 10),
                                  Text(
                                    'Engage Experts',
                                    style: TextStyle(color: Colors.white, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Search Page Placeholder
              Center(child: Text('Search Page')),
              // Profile Page Placeholder
              Center(child: Text('Profile Page')),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Function to log in a user and set a session for 2 months
Future<void> logInUserForTwoMonths() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isLoggedIn', true);
  final loginTime = DateTime.now();
  await prefs.setString('loginTime', loginTime.toIso8601String());
  final expirationTime = loginTime.add(const Duration(days: 60));
  await prefs.setString('expirationTime', expirationTime.toIso8601String());
}

// Function to check session expiration and log out if needed
Future<void> checkSessionExpiration() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? expirationTimeString = prefs.getString('expirationTime');
  if (expirationTimeString != null) {
    DateTime expirationTime = DateTime.parse(expirationTimeString);
    if (DateTime.now().isAfter(expirationTime)) {
      await prefs.setBool('isLoggedIn', false);
    }
  }
}
