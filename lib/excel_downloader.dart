import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class ExcelDownloader {
  final Dio dio = Dio();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        final result = await Permission.storage.request();
        if (result.isGranted) {
          return true;
        }
        // For Android 11 and above
        if (await Permission.manageExternalStorage.isDenied) {
          final result = await Permission.manageExternalStorage.request();
          return result.isGranted;
        }
        return false;
      }
    }
    return true;
  }

  Future<String?> downloadExcel() async {
    try {
      if (!await _checkPermissions()) {
        throw Exception('Storage permissions are required');
      }

      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'users_export_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';

      final response = await dio.get(
        'https://rushel.site/api/users/export',
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          headers: {
            'Accept':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(response.data);

      _showNotification('Download Complete', 'File saved to Downloads folder');
      return filePath;
    } catch (e) {
      _showNotification('Download Failed', e.toString());
      throw Exception('Download failed: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'downloads_channel', 'Downloads',
        channelDescription: 'Download notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true);

    const platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics);
  }
}
