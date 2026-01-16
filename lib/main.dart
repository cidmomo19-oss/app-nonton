import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// ⚙️ KONFIGURASI API (WAJIB GANTI)
// ==========================================
// Masukkan Link Worker API Lu (Worker ke-2 yang khusus JSON)
const String API_URL = "https://redstream-api.cidmomo1000.workers.dev/api"; 
const String APP_NAME = "CintaBokep";

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
        scaffoldBackgroundColor: const Color(0xFF000000), // Hitam Pekat
        primaryColor: const Color(0xFFFF0000), // Merah
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF0000),
          secondary: Color(0xFFB71C1C),
          surface: Color(0xFF111111),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF050505).withOpacity(0.9),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.roboto(
            color: const Color(0xFFFF0000),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
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
// 🏠 HOME SCREEN (GRID MEPET 4PX)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List videos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  Future<void> fetchVideos() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/home'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            videos = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(APP_NAME),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: VideoSearchDelegate());
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: fetchVideos,
              color: Colors.red,
              child: GridView.builder(
                padding: const EdgeInsets.all(6), // Padding Luar
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 16 / 12, // Rasio biar judul muat
                  crossAxisSpacing: 6, // Jarak Mepet Kanan-Kiri
                  mainAxisSpacing: 6,  // Jarak Mepet Atas-Bawah
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return VideoCard(video: videos[index]);
                },
              ),
            ),
    );
  }
}

// ==========================================
// 📦 KOMPONEN KARTU VIDEO (4PX RADIUS)
// ==========================================
class VideoCard extends StatelessWidget {
  final Map video;
  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WatchScreen(videoId: video['id'].toString())),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          // 🔥 RADIUS 4PX SESUAI REQUEST 🔥
          borderRadius: BorderRadius.circular(4), 
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    // 🔥 RADIUS 4PX ATAS 🔥
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: CachedNetworkImage(
                      imageUrl: video['poster'] ?? "",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                video['title'] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white, // Judul Putih
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📺 HALAMAN NONTON (NO BANNER)
// ==========================================
class WatchScreen extends StatefulWidget {
  final String videoId;
  const WatchScreen({super.key, required this.videoId});
  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  Map? videoData;
  List relatedVideos = [];
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
            relatedVideos = data['related'] ?? [];
            isLoading = false;
          });
          
          _webController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0xFF000000))
            ..setNavigationDelegate(NavigationDelegate(
              onNavigationRequest: (request) => NavigationDecision.navigate,
            ))
            ..loadRequest(Uri.parse(videoData!['iframe_url']));
            
          setState(() { playerReady = true; });
        }
      }
    } catch (e) { print(e); }
  }

  Future<void> _launchDownload() async {
    if (videoData == null) return;
    final Uri url = Uri.parse(videoData!['download_url']);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka link")));
    }
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => ReportModal(videoId: widget.videoId, videoTitle: videoData!['title']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PLAYER
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          playerReady ? WebViewWidget(controller: _webController) : Container(color: Colors.black),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoData!['title'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(4)),
                                child: Text(videoData!['category'] ?? "Umum", style: const TextStyle(color: Colors.red, fontSize: 11)),
                              ),
                              const SizedBox(width: 10),
                              Text(videoData!['created_at'].toString().split(" ")[0], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const Spacer(),
                              // TOMBOL LAPOR DI KANAN
                              GestureDetector(
                                onTap: _showReportDialog,
                                child: const Row(
                                  children: [
                                    Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text("Lapor / Request", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // TOMBOL DOWNLOAD
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              onPressed: _launchDownload,
                              icon: const Icon(Icons.download, color: Colors.white),
                              label: const Text("DOWNLOAD VIDEO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC0000),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFF222222)),

                    // REKOMENDASI
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: const Text("Rekomendasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 16 / 12,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: relatedVideos.length,
                      itemBuilder: (context, index) => VideoCard(video: relatedVideos[index]),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}

// ==========================================
// 🔍 FITUR PENCARIAN (SEARCH)
// ==========================================
class VideoSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF111111)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _SearchResults(query: query);
  @override
  Widget buildSuggestions(BuildContext context) => Container();
}

class _SearchResults extends StatefulWidget {
  final String query;
  const _SearchResults({required this.query});
  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  List results = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    search();
  }

  Future<void> search() async {
    try {
      final res = await http.get(Uri.parse('$API_URL/search?q=${widget.query}'));
      if (res.statusCode == 200) {
        setState(() {
          results = json.decode(res.body)['data'];
          loading = false;
        });
      }
    } catch (e) { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Colors.red));
    if (results.isEmpty) return const Center(child: Text("Tidak ditemukan", style: TextStyle(color: Colors.white)));
    
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) => VideoCard(video: results[index]),
    );
  }
}

// ==========================================
// 🚩 REPORT MODAL (NATIVE)
// ==========================================
class ReportModal extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  const ReportModal({super.key, required this.videoId, required this.videoTitle});

  @override
  State<ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<ReportModal> {
  String reason = "Video Mati";
  final TextEditingController _detailsController = TextEditingController();

  Future<void> _submit() async {
    try {
      await http.post(
        Uri.parse('$API_URL/report'),
        body: {
          'id': widget.videoId,
          'title': widget.videoTitle,
          'reason': reason,
          'details': _detailsController.text,
        },
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan terkirim!")));
    } catch (e) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Lapor / Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          _buildRadio("Video Mati / Blank"),
          _buildRadio("Link Download Rusak"),
          _buildRadio("Lainnya / Request Video"),
          if (reason.contains("Lainnya"))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _detailsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Jelaskan detail...",
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF222222),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("KIRIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRadio(String val) {
    return GestureDetector(
      onTap: () => setState(() => reason = val),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          border: Border.all(color: reason == val ? Colors.red : Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              reason == val ? Icons.radio_button_checked : Icons.radio_button_off,
              color: reason == val ? Colors.red : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(val, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
