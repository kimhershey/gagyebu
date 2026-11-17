// 앱에 들어가는 패키지의 라이선스가 허용 목록 안에 있는지 확인한다.
//
// 이 프로젝트는 소스 공개 의무가 없는 허용형 라이선스만 쓴다
// (MIT · BSD · Apache-2.0 · ISC · Zlib · 퍼블릭 도메인). GPL · LGPL · AGPL · MPL · EPL 등
// 카피레프트와 비상업 · 소스 공개형 라이선스가 나오면 실패한다.
//
//   dart run tool/check_licenses.dart            # 앱에 들어가는 패키지만
//   dart run tool/check_licenses.dart --all      # 개발 도구까지
//
// 대상은 pubspec의 dependencies에서 닿는 패키지다. 빌드 도구(dev_dependencies)는
// 앱에 들어가지 않으므로 기본으로는 보지 않는다.
import 'dart:convert';
import 'dart:io';

/// 패키지가 아닌 구성 요소. 사람이 확인해 여기에 적는다.
const extraComponents = <String, String>{
  'SQLite (sqlite3 패키지가 함께 넣는 네이티브 라이브러리 · sqlite3.wasm)': 'Public Domain',
  'Pretendard 글꼴 (assets/fonts)': 'OFL-1.1',
  'Material Icons 글꼴 (Flutter SDK)': 'Apache-2.0',
  'CanvasKit · Skia (Flutter 웹 엔진)': 'BSD-3-Clause',
};

const allowed = {
  'MIT',
  'BSD-3-Clause',
  'BSD-2-Clause',
  'Apache-2.0',
  'ISC',
  'Zlib',
  'Unlicense',
  'Public Domain',
  'OFL-1.1',
};

/// 라이선스 본문에서 종류를 알아낸다. 여러 라이선스가 함께 들어 있으면 모두 돌려준다.
Set<String> classify(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ');
  final found = <String>{};
  bool has(String s) => t.contains(s);

  // 금지: 카피레프트와 소스 공개형
  if (has('GNU AFFERO GENERAL PUBLIC LICENSE')) found.add('AGPL');
  if (has('GNU LESSER GENERAL PUBLIC LICENSE')) found.add('LGPL');
  if (has('GNU GENERAL PUBLIC LICENSE') &&
      !found.contains('LGPL') &&
      !found.contains('AGPL')) {
    found.add('GPL');
  }
  if (has('Mozilla Public License')) found.add('MPL');
  if (has('Eclipse Public License')) found.add('EPL');
  if (has('European Union Public Licence')) found.add('EUPL');
  if (has('Server Side Public License')) found.add('SSPL');
  if (has('Business Source License')) found.add('BUSL');
  if (has('Commons Clause')) found.add('Commons-Clause');
  if (RegExp('NonCommercial|Non-Commercial').hasMatch(t)) {
    found.add('NonCommercial');
  }

  // 허용
  if (has('Apache License') && has('Version 2.0')) found.add('Apache-2.0');
  if (has('Permission is hereby granted, free of charge')) found.add('MIT');
  if (has('Redistribution and use in source and binary forms')) {
    found.add(
      RegExp('Neither the name|may not be used to endorse').hasMatch(t)
          ? 'BSD-3-Clause'
          : 'BSD-2-Clause',
    );
  }
  if (has(
    'Permission to use, copy, modify, and/or distribute this software for any purpose',
  )) {
    found.add('ISC');
  }
  if (has(
        'This software is provided \'as-is\', without any express or implied warranty',
      ) ||
      has(
        'This software is provided "as-is", without any express or implied warranty',
      )) {
    found.add('Zlib');
  }
  if (has(
    'This is free and unencumbered software released into the public domain',
  )) {
    found.add('Unlicense');
  }
  return found;
}

Future<void> main(List<String> args) async {
  final all = args.contains('--all');

  final deps = await Process.run('dart', ['pub', 'deps', '--json']);
  if (deps.exitCode != 0) {
    stderr.writeln(deps.stderr);
    exit(2);
  }
  final graph = jsonDecode(deps.stdout as String) as Map<String, dynamic>;
  final packages = {
    for (final p in (graph['packages'] as List).cast<Map<String, dynamic>>())
      p['name'] as String: p,
  };
  final rootName = graph['root'] as String;

  // 앱에 들어가는 패키지: 루트의 직접 의존성에서 닿는 것 모두
  final included = <String>{};
  if (all) {
    included.addAll(packages.keys);
  } else {
    final queue = <String>[
      for (final p in packages.values)
        if (p['kind'] == 'direct') p['name'] as String,
    ];
    while (queue.isNotEmpty) {
      final name = queue.removeLast();
      if (!included.add(name)) continue;
      final dependencies =
          (packages[name]?['dependencies'] as List?) ?? const [];
      queue.addAll(dependencies.cast<String>());
    }
  }
  included.remove(rootName);

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final roots = <String, Directory>{};
  for (final p in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    var uri = p['rootUri'] as String;
    if (!uri.endsWith('/')) uri = '$uri/';
    final parsed = Uri.parse(uri);
    final resolved = parsed.isAbsolute
        ? parsed
        : File('.dart_tool/package_config.json').absolute.uri
              .resolveUri(parsed);
    roots[p['name'] as String] = Directory.fromUri(resolved);
  }

  final rows = <(String, String, String, bool)>[];
  for (final name in included.toList()..sort()) {
    final info = packages[name]!;
    final version = info['version'] as String? ?? '';
    final dir = roots[name];
    File? licenseFile;
    if (dir != null && dir.existsSync()) {
      for (final candidate in const [
        'LICENSE',
        'LICENSE.md',
        'LICENSE.txt',
        'LICENCE',
        'COPYING',
      ]) {
        final f = File('${dir.path}/$candidate');
        if (f.existsSync()) {
          licenseFile = f;
          break;
        }
      }
    }
    String label;
    bool ok;
    if (licenseFile == null) {
      if (info['source'] == 'sdk') {
        // Flutter SDK에 들어 있는 패키지는 SDK의 라이선스(BSD-3-Clause)를 따른다.
        label = 'BSD-3-Clause (Flutter SDK)';
        ok = true;
      } else {
        label = '라이선스 파일 없음';
        ok = false;
      }
    } else {
      final kinds = classify(licenseFile.readAsStringSync());
      label = kinds.isEmpty ? '알 수 없음' : (kinds.toList()..sort()).join(' + ');
      ok = kinds.isNotEmpty && kinds.every(allowed.contains);
    }
    rows.add((name, version, label, ok));
  }

  stdout.writeln('패키지 ${rows.length}개 (${all ? '개발 도구 포함' : '앱에 들어가는 것'})');
  for (final (name, version, label, ok) in rows) {
    stdout.writeln(
      '${ok ? '  ok ' : ' FAIL'}  ${name.padRight(34)} ${version.padRight(12)} $label',
    );
  }
  stdout.writeln('\n패키지가 아닌 구성 요소(사람이 확인)');
  extraComponents.forEach((name, license) {
    stdout.writeln('  ok   $name: $license');
  });

  final failures = rows.where((r) => !r.$4).toList();
  if (failures.isNotEmpty) {
    stderr.writeln('\n허용 목록 밖의 라이선스가 ${failures.length}개 있다:');
    for (final (name, version, label, _) in failures) {
      stderr.writeln('  $name $version: $label');
    }
    exit(1);
  }
  stdout.writeln('\n모두 허용 목록 안에 있다.');
}
