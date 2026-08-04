import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../l10n/generated/app_localizations.dart';

class SSLWebViewScreen extends StatefulWidget {
  final String url;
  final String successUrl;
  final String failUrl;
  final String cancelUrl;

  const SSLWebViewScreen({
    super.key,
    required this.url,
    required this.successUrl,
    required this.failUrl,
    required this.cancelUrl,
  });

  @override
  State<SSLWebViewScreen> createState() => _SSLWebViewScreenState();
}

class _SSLWebViewScreenState extends State<SSLWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint("Loading URL in WebView: ${widget.url}");
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(widget.successUrl)) {
              Navigator.of(context).pop("VALID");
              return NavigationDecision.prevent;
            } else if (request.url.startsWith(widget.failUrl)) {
              Navigator.of(context).pop("FAILED");
              return NavigationDecision.prevent;
            } else if (request.url.startsWith(widget.cancelUrl)) {
              Navigator.of(context).pop("CANCELLED");
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).securePayment),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop("CANCELLED"),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
