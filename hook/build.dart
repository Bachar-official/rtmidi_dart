// hook/build.dart
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final context = path.Context(
        style: Platform.isWindows ? path.Style.windows : path.Style.posix);
    final packageRoot = Platform.isWindows
        ? input.packageRoot.path.substring(1)
        : input.packageRoot.path;
    print('PACKAGE ROOT IS $packageRoot');
    final srcDir = context.join(packageRoot, 'src', 'rtmidi');

    final sources = [
      context.join(srcDir, 'RtMidi.cpp'),
      context.join(srcDir, 'rtmidi_c.c'),
    ];

    final defines = <String, String?>{};

    final os = input.config.code.targetOS;
    if (os == OS.linux) {
      defines['__LINUX_ALSA__'] = null;
    } else if (os == OS.windows) {
      defines['__WINDOWS_MM__'] = null;
      defines['RTMIDI_EXPORT'] = null;
    } else if (os == OS.android) {
      defines['__ANDROID__'] = null;
      defines['__RTMIDI_AMIDI__'] = null;
    } else if (os == OS.macOS) {
      defines['__MACOSX_CORE__'] = null;
    }

    final libraries = <String>[];
    if (os == OS.linux) {
      libraries.add('asound');
    } else if (os == OS.windows) {
      libraries.add('winmm');
    }

    final flags = <String>[
  if (input.config.code.targetOS == OS.windows) ...[
    '/std:c++17',
    '/EHsc',
    '/GR',
    '/D_CRT_SECURE_NO_WARNINGS',
  ] else ...[
    '-std=c++17',
    '-fexceptions',
    '-frtti',
    if (input.config.code.targetOS != OS.android) ...[
      '-static-libgcc',
      '-static-libstdc++',
    ],
    if (input.config.code.targetOS == OS.android) ...[
      '-static-libgcc',
      '-lc++_static',      // ← Статическая линковка libc++ на Android
    ],
  ],
];

    final builder = CBuilder.library(
      name: 'rtmidi',
      assetName: 'package:rtmidi_dart/rtmidi', // ← это и есть ID asset
      sources: sources,
      includes: [srcDir],
      defines: defines,
      language: Language.cpp,
      flags: flags,
      libraries: libraries,
    );

    // ← Это всё! CBuilder сам соберёт и зарегистрирует asset
    await builder.run(input: input, output: output);
    // Больше ничего добавлять не нужно!
  });
}
