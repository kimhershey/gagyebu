import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'model_file_store.dart';

/// 이 플랫폼에서는 모델 파일을 둘 수 있다.
const bool modelFileStoreAvailable = true;

/// [baseDirectory]가 주는 폴더(앱 지원 폴더) 아래 `models/`에 두는 저장소.
ModelFileStore createModelFileStore(Future<String> Function() baseDirectory) =>
    IoModelFileStore(baseDirectory);

/// 기기의 파일 시스템에 두는 저장소.
class IoModelFileStore implements ModelFileStore {
  IoModelFileStore(this._baseDirectory);

  final Future<String> Function() _baseDirectory;

  Future<Directory> _directory() async {
    final directory = Directory(p.join(await _baseDirectory(), 'models'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String> pathFor(String fileName) async =>
      // 이름만 쓴다. 경로를 벗어나는 이름('../')이 들어와도 models/ 안에 둔다.
      p.join((await _directory()).path, p.basename(fileName));

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<int> length(String path) async {
    final file = File(path);
    return await file.exists() ? await file.length() : 0;
  }

  @override
  Future<ModelFileSink> openWrite(String path, {required bool append}) async =>
      _IoSink(
        await File(path).open(mode: append ? FileMode.append : FileMode.write),
      );

  @override
  Future<String> sha256Of(String path) =>
      // 1GB가 넘는 파일이다. 화면이 멈추지 않게 다른 격리 영역에서 계산한다.
      Isolate.run(() async {
        final digest = await sha256.bind(File(path).openRead()).first;
        return digest.toString();
      });

  @override
  Future<void> rename(String from, String to) async {
    final target = File(to);
    if (await target.exists()) await target.delete();
    await File(from).rename(to);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<int?> freeSpace() async {
    try {
      final directory = (await _directory()).path;
      if (Platform.isWindows) {
        final drive = p.rootPrefix(directory).replaceAll(RegExp(r'[:\\/]'), '');
        if (!RegExp(r'^[A-Za-z]$').hasMatch(drive)) return null;
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "(Get-PSDrive -Name '$drive').Free",
        ]);
        if (result.exitCode != 0) return null;
        return int.tryParse('${result.stdout}'.trim());
      }
      // Android · Linux: df의 마지막 줄 넷째 칸이 남은 공간(KB)이다.
      final result = await Process.run('df', ['-k', directory]);
      if (result.exitCode != 0) return null;
      return parseDfAvailable('${result.stdout}');
    } on Object {
      // 명령이 없거나 막혀 있다. 알 수 없는 것으로 둔다.
      return null;
    }
  }
}

/// `df -k`의 출력에서 남은 공간(바이트)을 읽는다. 읽지 못하면 null.
int? parseDfAvailable(String output) {
  final lines = output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  final columns = lines.last.split(RegExp(r'\s+'));
  // 장치 이름이 길면 줄이 나뉘어 칸이 하나 준다. 뒤에서부터 센다:
  // … 1K-blocks Used Available Use% Mounted
  if (columns.length < 5) return null;
  final available = int.tryParse(columns[columns.length - 3]);
  return available == null ? null : available * 1024;
}

class _IoSink implements ModelFileSink {
  _IoSink(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> add(List<int> bytes) => _file.writeFrom(bytes);

  @override
  Future<void> close() async {
    await _file.flush();
    await _file.close();
  }
}
