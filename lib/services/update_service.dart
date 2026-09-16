import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  static const String owner = 'AmshuBelbase';
  static const String repo = 'Katch';
  
  static Future<bool> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Fetch latest release from GitHub API
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestTag = data['tag_name']; 
        String releaseNotes = data['body'] ?? 'No release notes provided.';
        
        // Strip 'v' from tag if present for easy comparison
        String latestVersion = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

        // 3. Compare versions
        if (_isUpdateAvailable(currentVersion, latestVersion)) {
          
          // Find the APK asset download URL
          String? apkUrl;
          for (var asset in data['assets']) {
            if (asset['name'] == 'katch.apk' || asset['name'].endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl != null) {
            // 4. Show Update Dialog
            if (context.mounted) {
              _showUpdateDialog(context, latestVersion, releaseNotes, apkUrl);
              return true; // Update available, blocked.
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return false; // No update required
  }

  // Simple version comparison logic
  static bool _isUpdateAvailable(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (i >= latestParts.length) return false;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  static void _showUpdateDialog(BuildContext context, String version, String notes, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        version: version,
        notes: notes,
        downloadUrl: downloadUrl,
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String version;
  final String notes;
  final String downloadUrl;

  const UpdateDialog({
    Key? key,
    required this.version,
    required this.notes,
    required this.downloadUrl,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  String _progress = '';
  OtaEvent? _currentEvent;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
    });

    try {
      OtaUpdate()
          .execute(
        widget.downloadUrl,
        destinationFilename: 'katch_update.apk',
      )
          .listen(
        (OtaEvent event) {
          setState(() {
            _currentEvent = event;
            if (event.status == OtaStatus.DOWNLOADING) {
              _progress = '${event.value}%';
            } else if (event.status == OtaStatus.INSTALLING) {
              _progress = 'Installing...';
            } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
              _progress = 'Storage permission required.';
              _isDownloading = false;
            } else if (event.status != OtaStatus.DOWNLOADING) {
              _isDownloading = false;
            }
          });
        },
        onError: (error) {
          setState(() {
            _isDownloading = false;
            _progress = 'Download failed: $error';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _progress = 'Failed to start download.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Available: v${widget.version}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Release Notes:\n${widget.notes}'),
            const SizedBox(height: 20),
            if (_isDownloading)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    'Status: ${_currentEvent?.status.toString().split('.').last ?? "DOWNLOADING"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_progress.isNotEmpty) Text(_progress),
                ],
              ),
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: const Text('Update Now'),
          ),
      ],
    );
  }
}
