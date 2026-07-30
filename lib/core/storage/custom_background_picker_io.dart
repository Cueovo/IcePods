import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CustomBackgroundPicker {
  CustomBackgroundPicker({
    ImagePicker? imagePicker,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final ImagePicker _imagePicker;
  final Future<Directory> Function() _applicationSupportDirectory;

  bool get isSupported => true;

  Future<String?> pickImage() async {
    final source = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 90,
    );
    if (source == null) {
      return null;
    }
    final directory = await _backgroundDirectory();
    final extension = _extensionFor(source.path);
    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      'background-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
    return target.path;
  }

  Future<bool> exists(String path) async {
    if (path.isEmpty) {
      return false;
    }
    return File(path).exists();
  }

  Future<void> deleteImage(String path) async {
    if (path.isEmpty) {
      return;
    }
    final directory = await _backgroundDirectory();
    final file = File(path).absolute;
    final prefix = '${directory.absolute.path}${Platform.pathSeparator}';
    if (!file.path.startsWith(prefix) || !await file.exists()) {
      return;
    }
    await file.delete();
  }

  Future<Directory> _backgroundDirectory() async {
    final root = await _applicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}backgrounds',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extensionFor(String path) {
    final match = RegExp(r'\.([a-zA-Z0-9]{1,8})$').firstMatch(path);
    return match == null ? '.jpg' : '.${match.group(1)!.toLowerCase()}';
  }
}
