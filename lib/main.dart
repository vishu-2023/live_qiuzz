// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() async {
  runApp(const MyApp());
}

// ---------------------- ROOT APP WITH THEME ----------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.dark;
  bool showIntro = true;
  void toggleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    defaultSystemUIOverlayStyle();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFFB433),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB433),
            foregroundColor: Colors.black,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFFB433),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.black,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB433),
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: showIntro
          ? IntroScreen(
              onDone: () => setState(() => showIntro = false),
            )
          : HomePage(toggleTheme: toggleTheme, isDark: _mode == ThemeMode.dark),
    );
  }
}

// ---------------------- HOME PAGE ----------------------

class HomePage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  const HomePage({super.key, required this.toggleTheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🧠 Local Quiz"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz, size: 100),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Host Quiz (Host)"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPage()),
              ),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.group),
              label: const Text("Join Quiz (Player)"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientPage()),
              ),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------ ADMIN -------------------------

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  ServerSocket? server;
  List<Socket> clients = [];
  final messageController = TextEditingController();
  String log = '';
  String localIp = 'Loading...';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    startServer();
  }

  Future<void> startServer() async {
    final ip = await getLocalIp();
    setState(() => localIp = ip);

    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 3000);
      server!.listen((client) {
        clients.add(client);
        logMessage("Client connected: ${client.remoteAddress.address}");
        client.listen((data) {
          final msg = String.fromCharCodes(data);
          logMessage("Answer from ${client.remoteAddress.address}: $msg");
        });
      });
      logMessage("Server started on $localIp:3000");
    } catch (e) {
      logMessage("Error: $e");
    }

    setState(() => loading = false);
  }

  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return 'No IP found';
  }

  void sendMessage() {
    final msg = messageController.text.trim();
    if (msg.isEmpty) return;
    for (var client in clients) {
      client.write(msg);
    }
    logMessage("Sent: $msg");
    messageController.clear();
  }

  void logMessage(String msg) {
    setState(() {
      log = "$msg\n$log";
    });
  }

  @override
  void dispose() {
    server?.close();
    for (var c in clients) {
      c.close();
    }
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("👑 Host")),
      body: loading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFFFFB433)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: ListTile(
                      title: Text("Your IP: $localIp"),
                      subtitle: const Text("Scan below QR to join"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: localIp,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: "Send question or message",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(log, style: const TextStyle(fontFamily: 'Courier')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ------------------------ CLIENT -------------------------

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  final nameController = TextEditingController();
  final ipController = TextEditingController();
  final answerController = TextEditingController();
  Socket? socket;
  String msg = '';
  bool isLoading = false;

  void connect(String ip) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter your name first")));
      return;
    }

    setState(() => isLoading = true);
    try {
      socket = await Socket.connect(ip, 3000);
      socket!.write("[$name] joined the quiz.");
      socket!.listen((data) {
        final serverMsg = String.fromCharCodes(data);
        setState(() => msg = serverMsg);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Connected")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
    }
    setState(() => isLoading = false);
  }

  void sendAnswer() {
    final name = nameController.text.trim();
    if (socket != null && answerController.text.isNotEmpty && name.isNotEmpty) {
      socket!.write("[$name]: ${answerController.text.trim()}");
      answerController.clear();
    }
  }

  void scanQRCode() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter your name first")));
      return;
    }

    await Permission.camera.request();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRViewExample(onScanned: (scannedIp) {
          ipController.text = scannedIp;
          connect(scannedIp);
        }),
      ),
    );
  }

  @override
  void dispose() {
    socket?.close();
    nameController.dispose();
    ipController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🙋 Player")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: "Enter your name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                hintText: "Enter host IP",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: scanQRCode,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            isLoading
                ? const SpinKitThreeBounce(color: Color(0xFFFFB433), size: 24)
                : ElevatedButton(
                    onPressed: () => connect(ipController.text.trim()),
                    child: const Text("Connect"),
                  ),
            const SizedBox(height: 20),
            Text(msg.isNotEmpty ? "📢 $msg" : "Waiting for message...",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                labelText: "Your Answer",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: sendAnswer, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }
}

// ------------------------ QR SCANNER -------------------------

class QRViewExample extends StatelessWidget {
  final Function(String) onScanned;
  const QRViewExample({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey(debugLabel: 'QR');

    return Scaffold(
      appBar: AppBar(title: const Text("📷 Scan QR")),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (controller) {
          controller.scannedDataStream.listen((scanData) {
            controller.dispose();
            Navigator.pop(context);
            onScanned(scanData.code ?? '');
          });
        },
      ),
    );
  }
}
// ---------------------- INTRO SLIDES ----------------------

class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      'title': '📡 Host Quiz',
      'desc': 'Admin hosts the quiz and shares IP via QR code.',
    },
    {
      'title': '📲 Join Quiz',
      'desc': 'Playerr scan the QR or enter IP manually to join.',
    },
    {
      'title': '🧠 Play',
      'desc': 'Player answer questions, admin sees all responses!',
    },
    {
      'title': '🌐 Connection',
      'desc': "Ensure all devices are on the same Wi-Fi network for smooth communication."
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => currentPage = index),
                itemCount: slides.length,
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slides[i]['title']!,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          slides[i]['desc']!,
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  margin: const EdgeInsets.all(4),
                  width: currentPage == i ? 12 : 8,
                  height: currentPage == i ? 12 : 8,
                  decoration: BoxDecoration(
                    color: currentPage == i ? Theme.of(context).primaryColor : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton(
                onPressed: widget.onDone,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(currentPage == slides.length - 1 ? "Start Quiz" : "Skip"),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

void defaultSystemUIOverlayStyle() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}
