// 웹 빌드에 필요한 파일 두 개를 web/ 아래에 준비한다.
//
//   web/drift_worker.js  drift 패키지에 들어 있는 웹 워커를 복사한다.
//   web/sqlite3.wasm     sqlite3 패키지의 GitHub 릴리스에서 내려받는다.
//
// 두 파일은 pubspec.lock에 고정된 패키지 버전에 맞춰야 하므로 저장소에 넣지 않고
// 빌드 전에 이 스크립트로 만든다.
//
//   dart run tool/prepare_web_assets.dart
//   dart run tool/prepare_web_assets.dart --sqlite3-wasm=/path/to/sqlite3.wasm
//
// --sqlite3-wasm: 내려받는 대신 로컬 파일을 쓴다(GitHub에 닿지 않는 환경용).
// --force:        이미 있어도 다시 만든다.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final localWasm = args
      .where((a) => a.startsWith('--sqlite3-wasm='))
      .map((a) => a.substring('--sqlite3-wasm='.length))
      .firstOrNull;

  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    stderr.writeln('먼저 `flutter pub get`을 실행해야 한다.');
    exit(2);
  }
  final packages =
      (jsonDecode(configFile.readAsStringSync()) as Map)['packages'] as List;
  Uri rootOf(String name) {
    final entry = packages.cast<Map>().firstWhere((p) => p['name'] == name);
    // 끝에 '/'가 있어야 그 아래 경로로 풀린다.
    var text = entry['rootUri'] as String;
    if (!text.endsWith('/')) text = '$text/';
    final root = Uri.parse(text);
    return root.isAbsolute ? root : configFile.absolute.uri.resolveUri(root);
  }

  Directory('web').createSync(recursive: true);

  // 1) drift 웹 워커
  final workerSource = File.fromUri(rootOf('drift').resolve('drift_worker.js'));
  final workerTarget = File('web/drift_worker.js');
  if (!workerSource.existsSync()) {
    stderr.writeln('drift 패키지에 drift_worker.js가 없다: ${workerSource.path}');
    exit(1);
  }
  workerSource.copySync(workerTarget.path);
  stdout.writeln('web/drift_worker.js ← ${workerSource.path}');

  // 2) SQLite WebAssembly
  final wasmTarget = File('web/sqlite3.wasm');
  if (localWasm != null) {
    File(localWasm).copySync(wasmTarget.path);
    stdout.writeln('web/sqlite3.wasm ← $localWasm');
  } else if (wasmTarget.existsSync() && !force) {
    stdout.writeln('web/sqlite3.wasm 이미 있음(다시 받으려면 --force)');
  } else {
    final version = RegExp(r'sqlite3-(\d+\.\d+\.\d+[^/]*)/$')
        .firstMatch(rootOf('sqlite3').path)
        ?.group(1);
    if (version == null) {
      stderr.writeln('sqlite3 패키지 버전을 알 수 없다.');
      exit(1);
    }
    final url = Uri.parse(
      'https://github.com/simolus3/sqlite3.dart/releases/download/'
      'sqlite3-$version/sqlite3.wasm',
    );
    stdout.writeln('내려받는 중: $url');
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != 200) {
        stderr.writeln(
          '내려받지 못했다(HTTP ${response.statusCode}). '
          '--sqlite3-wasm=<파일>로 로컬 파일을 줄 수 있다.',
        );
        exit(1);
      }
      await response.pipe(wasmTarget.openWrite());
    } finally {
      client.close();
    }
  }

  // WebAssembly 파일이 맞는지 확인한다(\0asm).
  final head = wasmTarget.openSync().readSync(4);
  if (head.length < 4 ||
      head[0] != 0x00 ||
      head[1] != 0x61 ||
      head[2] != 0x73 ||
      head[3] != 0x6d) {
    stderr.writeln('web/sqlite3.wasm이 WebAssembly 파일이 아니다.');
    exit(1);
  }
  stdout.writeln('web/sqlite3.wasm ${wasmTarget.lengthSync()}바이트');
}
