import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// ⚙️ SETTING API
// ==========================================
// Masukkan Link Worker API Lu (yang ada /api di belakangnya)
const String API_URL = "https://redstream-api.namalu.workers.dev/api"; 
const String APP_NAME = "CintaBokep"; // Nama Baru

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFFFF0000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF0000),
          secondary: Color(0xFFB71C1C),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF050505),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.bangers( // Font agak nakal/komik dikit
            color: const Color(0xFFFF0000),
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// 🏠 HOME SCREEN (NATIVE)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List videos = [];
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  Future<void> fetchVideos() async {
    setState(() { isLoading = true; isError = false; });
    try {
      final response = await http.get(Uri.parse('$API_URL/home'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            videos = data['data'];
            isLoading = false;
          });
        } else {
          setState(() { isError = true; isLoading = false; });
        }
      } else {
        setState(() { isError = true; isLoading = false; });
      }
    } catch (e) {
      setState(() { isError = true; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(APP_NAME),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchVideos,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.signal_wifi_bad, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      const Text("Gagal memuat data"),
                      TextButton(
                        onPressed: fetchVideos,
                        child: const Text("Refresh", style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4), // Mepet dikit
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 16 / 11,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WatchScreen(videoId: video['id'].toString()),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Poster Full
                          CachedNetworkImage(
                            imageUrl: video['poster'] ?? "",
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[900]),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                          ),
                          // Gradient Hitam di Bawah (Biar judul kebaca)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 50,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          // Judul di atas gambar
                          Positioned(
                            bottom: 5, left: 5, right: 5,
                            child: Text(
                              video['title'] ?? "",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ==========================================
// 📺 WATCH SCREEN (ABYSS FRIENDLY)
// ==========================================
class WatchScreen extends StatefulWidget {
  final String videoId;
  const WatchScreen({super.key, required this.videoId});
  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  Map? videoData;
  bool isLoading = true;
  late final WebViewController _webController;
  bool playerReady = false;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/video/${widget.videoId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            videoData = data['data'];
            isLoading = false;
          });
          
          // SETUP PLAYER ABYSS (TANPA BLOKIR IKLAN)
          // Biar player jalan normal
          _webController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0xFF000000))
            ..loadRequest(Uri.parse(videoData!['iframe_url']));
            
          setState(() { playerReady = true; });
        }
      }
    } catch (e) { print(e); }
  }

  // BUKA BROWSER UNTUK OUO/GOFILE (AMAN DARI LIMIT WORKER)
  Future<void> _launchDownload() async {
    if (videoData == null) return;
    final Uri url = Uri.parse(videoData!['download_url']);
    
    // Mode: LaunchMode.externalApplication
    // Ini akan melempar link ke Chrome/Browser bawaan HP
    // User akan melewati Ouo.io di browser mereka sendiri
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka browser")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SafeArea(
              child: Column(
                children: [
                  // PLAYER
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        playerReady 
                          ? WebViewWidget(controller: _webController)
                          : Container(color: Colors.black),
                        // Tombol Back
                        Positioned(
                          top: 10, left: 10,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // INFO
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoData!['title'],
                            style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF222222),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red)
                                ),
                                child: Text(videoData!['category'] ?? "Viral", style: const TextStyle(fontSize: 12, color: Colors.red)),
                              ),
                              const Spacer(),
                              const Text("Server: Abyss", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // TOMBOL DOWNLOAD (Browser)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _launchDownload,
                              icon: const Icon(Icons.open_in_browser, color: Colors.white),
                              label: const Text("BUKA LINK DOWNLOAD (BROWSER)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC0000),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              "Link akan dibuka di Browser HP (Lewati Ouo.io)",
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
