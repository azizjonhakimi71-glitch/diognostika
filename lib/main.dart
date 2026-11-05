import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const int kPort = 8765;

String _mime(String p) {
  final e = p.split('.').last.toLowerCase();
  const m = {
    'html': 'text/html; charset=utf-8',
    'js': 'application/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'json': 'application/json',
  };
  return m[e] ?? 'application/octet-stream';
}

Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, kPort, shared: true);
  server.listen((req) async {
    var path = Uri.decodeComponent(req.uri.path);
    if (path == '/' || path.isEmpty) path = '/index.html';
    try {
      final data = await rootBundle.load('assets/www$path');
      req.response.headers.contentType = ContentType.parse(_mime(path));
      req.response.headers.add('Cache-Control', 'no-cache');
      req.response.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      req.response.statusCode = 404;
    }
    await req.response.close();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0B0F17),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0B0F17),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await startServer();
  runApp(const RadiScanApp());
}

class RadiScanApp extends StatelessWidget {
  const RadiScanApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RadiScan AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const WebShell(),
      );
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _c;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0F17))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onNavigationRequest: (r) {
          final h = Uri.parse(r.url).host;
          return (h == '127.0.0.1' || h == 'localhost')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse('http://127.0.0.1:$kPort/index.html'));
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          await _c.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _c),
            if (_progress < 1)
              LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  color: const Color(0xFF5EEAD4),
                  backgroundColor: Colors.transparent),
          ]),
        ),
      ),
    );
  }
}