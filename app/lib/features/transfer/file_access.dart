/// 파일을 고르고 저장하는 일. 화면은 제공자만 보고, 시험에서는 가짜로 바꿔 끼운다.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 사용자가 고른 파일.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// 고른 파일이 너무 클 때 던진다.
class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

/// 가져올 파일의 크기 한도. 2,000건짜리 CSV는 1MB를 넘지 않는다.
const maxImportFileBytes = 20 * 1024 * 1024;

/// CSV 파일을 고르게 한다. 고르지 않았으면 null. 너무 크면 [FileTooLargeException].
typedef FilePicker = Future<PickedFile?> Function();

/// 파일을 저장한다. 저장한 곳을 사용자에게 보일 말로 돌려준다(웹은 내려받기).
/// 사용자가 그만뒀으면 null.
typedef FileSaver = Future<String?> Function({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
});

final filePickerProvider = Provider<FilePicker>((ref) => pickCsvFile);

final fileSaverProvider = Provider<FileSaver>((ref) => saveExportFile);

Future<PickedFile?> pickCsvFile() async {
  const group = XTypeGroup(
    label: 'CSV',
    extensions: ['csv', 'txt'],
    mimeTypes: ['text/csv', 'text/comma-separated-values', 'text/plain'],
    uniformTypeIdentifiers: [
      'public.comma-separated-values-text',
      'public.plain-text',
    ],
  );
  final file = await openFile(acceptedTypeGroups: const [group]);
  if (file == null) return null;
  if (await file.length() > maxImportFileBytes) {
    throw const FileTooLargeException();
  }
  return PickedFile(name: file.name, bytes: await file.readAsBytes());
}

Future<String?> saveExportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final file = XFile.fromData(bytes, name: fileName, mimeType: mimeType);
  if (kIsWeb) {
    // 브라우저가 내려받기로 처리한다. 경로는 쓰이지 않는다.
    await file.saveTo(fileName);
    return '브라우저의 내려받기 폴더';
  }
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    // 휴대폰에는 저장할 곳을 묻는 창이 없다. 앱의 내려받기 폴더에 둔다.
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, fileName);
    await file.saveTo(path);
    return path;
  }
  final extension = p.extension(fileName).replaceFirst('.', '');
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
    ],
  );
  if (location == null) return null;
  await file.saveTo(location.path);
  return location.path;
}
