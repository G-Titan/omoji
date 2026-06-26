// lib/main.dart

import 'dart:io';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/emoji%20map.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(450, 550),
    center: true,
    backgroundColor: Colors.transparent, // Crucial for letting desktop background show through blur
    skipTaskbar: true, 
    titleBarStyle: TitleBarStyle.hidden, 
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Set the Linux window icon here
    await windowManager.setIcon('lib/assets/imgs/app-logo.jpg');
    
    await windowManager.setAsFrameless();
    await windowManager.show(); 
    await windowManager.focus();
  });

  runApp(const OmojiApp());
}

class OmojiApp extends StatelessWidget {
  const OmojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const fallbackFonts = ['NotoColorEmoji'];

    return MaterialApp(
      title: 'Omoji',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent, // Let our glass canvas handle the background color
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamilyFallback: fallbackFonts,
        ),
        primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
          fontFamilyFallback: fallbackFonts,
        ),
      ),
      home: const OmojiHomeScreen(),
    );
  }
}

class OmojiHomeScreen extends StatefulWidget {
  const OmojiHomeScreen({super.key});

  @override
  State<OmojiHomeScreen> createState() => _OmojiHomeScreenState();
}

class _OmojiHomeScreenState extends State<OmojiHomeScreen> with WindowListener {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = "";
  
  // Track recently clicked emojis purely in runtime memory
  final List<String> _recentEmojis = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); 
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this); 
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    setState(() {
      _focusNode.requestFocus();
    });
  }

  @override
  void onWindowBlur() async {
    await windowManager.hide();
    _searchController.clear();
  }

  void _handleEmojiSelection(String emoji) async {
    await Clipboard.setData(ClipboardData(text: emoji));
    
    setState(() {
      _recentEmojis.remove(emoji); 
      _recentEmojis.insert(0, emoji); 
      if (_recentEmojis.length > 14) {
        _recentEmojis.removeLast(); 
      }
    });

    await windowManager.hide();
    _searchController.clear();

    await Future.delayed(const Duration(milliseconds: 150));
    
    try {
      await Process.run('wtype', [emoji]);
    } catch (e) {
      debugPrint("Wayland 'wtype' text injection tool error: $e");
    }
  }

  // --- New Feature: Close/Minimize Dialog ---
  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E), // Match the glassmorphism dark tone
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Exit Omoji', style: TextStyle(color: Colors.white)),
          content: Text(
            'Would you like to minimize the app to the background or close it completely?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await windowManager.hide(); // Or .minimize() if you prefer standard taskbar minimization
              },
              child: const Text('Minimize', style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await windowManager.close(); // Completely kill the process
              },
              child: const Text('Close', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Deep underlying glossy blur
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // Multi-stop glass gradient layout mimicking high-spec specular reflections
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E2E2E).withValues(alpha: 0.65), 
                  const Color(0xFF1A1A1A).withValues(alpha: 0.45), 
                  const Color(0xFF121212).withValues(alpha: 0.75), 
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), 
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- New Feature: Top Bar with Title, Settings, and Close ---
                  Row(
                    children: [
                      // App Title acts as an anchor for the top left
                      const Expanded(
                        child: Text(
                          'Omoji',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        color: Colors.white.withValues(alpha: 0.7),
                        splashRadius: 20,
                        onPressed: () {
                          // TODO: Implement settings screen/logic
                          debugPrint('Settings clicked');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white.withValues(alpha: 0.7),
                        splashRadius: 20,
                        onPressed: () => _showCloseDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // High contrast input surface matching the acrylic paneling look
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search emojis...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.withValues(alpha: 0.6), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView(
                      children: [
                        // Show "Recently Used" row at the top only when search is empty and items exist
                        if (_searchQuery.isEmpty && _recentEmojis.isNotEmpty)
                          _buildRecentEmojisSection(),
                        ..._buildEmojiSections(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard grid containing frequently used symbols
  Widget _buildRecentEmojisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.history, size: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Recently Used', 
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 55,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _recentEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _recentEmojis[index];
            return InkWell(
              onTap: () => _handleEmojiSelection(emoji),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(color: Colors.white10),
        ),
      ],
    );
  }

  List<Widget> _buildEmojiSections() {
    List<Widget> sections = [];
    
    fullEmojiData.forEach((category, emojis) {
      final filteredEmojis = emojis.where((e) {
        return e['name']!.contains(_searchQuery) || e['char']!.contains(_searchQuery);
      }).toList();

      if (filteredEmojis.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
            child: Text(
              category, 
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.bold)
            ),
          ),
        );

        sections.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 55,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: filteredEmojis.length,
            itemBuilder: (context, index) {
              final emoji = filteredEmojis[index];
              return InkWell(
                onTap: () => _handleEmojiSelection(emoji['char']!),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    // Inner glossy card layer: transparent background tile
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji['char']!, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        );
      }
    });
    return sections;
  }
}