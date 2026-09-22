import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  static const String owner = 'AmshuBelbase';
  static const String repo = 'Katch';
  
  static Future<bool> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      if (packageInfo.buildNumber.isNotEmpty) {
        currentVersion += '.${packageInfo.buildNumber}';
      }

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
          String? apkUrl;
          if (data['assets'] != null) {
            for (var asset in data['assets']) {
              if (asset['name'] != null && asset['name'].toString().endsWith('.apk')) {
                apkUrl = asset['browser_download_url'];
                break;
              }
            }
          }

          if (apkUrl != null) {
            // 4. Show Update Dialog
            if (context.mounted) {
              _showUpdateDialog(context, latestVersion, releaseNotes, apkUrl);
              return true; // Update available, blocked.
            }
          } else {
             // Fallback to github url if no APK asset is found
             String? releaseUrl = data['html_url'];
             if (releaseUrl != null && context.mounted) {
                 _showUpdateDialog(context, latestVersion, releaseNotes, releaseUrl, isDirectApk: false);
                 return true;
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

  static void _showUpdateDialog(BuildContext context, String version, String notes, String downloadUrl, {bool isDirectApk = true}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        version: version,
        notes: notes,
        downloadUrl: downloadUrl,
        isDirectApk: isDirectApk,
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String version;
  final String notes;
  final String downloadUrl;
  final bool isDirectApk;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.notes,
    required this.downloadUrl,
    this.isDirectApk = true,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _startUpdate() async {
    if (!widget.isDirectApk) {
       // Fallback logic, should rarely happen if GitHub has an APK asset
       // We'd ideally launch url here, but we removed url_launcher.
       // Let's just handle it gracefully.
       setState(() {
         _statusMessage = 'Could not find a direct APK to download.';
       });
       return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Requesting permissions...';
      _progress = 0.0;
    });

    var status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
       setState(() {
          _isDownloading = false;
          _statusMessage = 'Permission denied to install packages.';
       });
       return;
    }

    setState(() {
      _statusMessage = 'Downloading update...';
    });

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Could not access storage.';
        });
        return;
      }

      final savePath = '${dir.path}/update_v${widget.version}.apk';
      final file = File(savePath);

      if (await file.exists()) {
        await file.delete();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download failed (HTTP ${response.statusCode})';
        });
        return;
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          setState(() {
            _progress = downloadedBytes / contentLength;
          });
        }
      }
      await sink.close();
      client.close();

      setState(() {
        _statusMessage = 'Download complete. Installing...';
      });

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        setState(() {
           _isDownloading = false;
           _statusMessage = 'Failed to open APK: ${result.message}';
        });
      } else {
        // App should be closing to install, but just in case
        setState(() {
           _isDownloading = false;
           _statusMessage = 'Please complete the installation.';
        });
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Error: $e';
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                  const SizedBox(height: 10),
                  Text('${(_progress * 100).toStringAsFixed(1)}% - $_statusMessage', style: const TextStyle(fontSize: 12)),
                ],
              )
            else if (_statusMessage.isNotEmpty)
              Text(_statusMessage, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))
            else
              const Text(
                'A new version is available. It will be downloaded and you will be prompted to install it.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey),
              )
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
           ElevatedButton(
             onPressed: _startUpdate,
             child: const Text('Download & Install'),
           ),
      ],
    );
  }
}
