import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final context = path.Context(
      style: Platform.isWindows ? path.Style.windows : path.Style.posix,
    );
    final packageRoot = Platform.isWindows
        ? input.packageRoot.path.substring(1) // убираем ведущий '/'
        : input.packageRoot.path;

    final srcDir = context.join(packageRoot, 'src', 'rtmidi');

    final sources = [
      context.join(srcDir, 'RtMidi.cpp'),
      context.join(srcDir, 'rtmidi_c.c'),
    ];

    final defines = <String, String?>{};
    final os = input.config.code.targetOS;

    switch (os) {
      case OS.linux:
        defines['__LINUX_ALSA__'] = null;
      case OS.windows:
        defines['__WINDOWS_MM__'] = null;
        defines['RTMIDI_EXPORT'] = null;
      case OS.android:
        defines['__ANDROID__'] = null;
        defines['__RTMIDI_AMIDI__'] = null;
      case OS.macOS:
      case OS.iOS:
        defines['__MACOSX_CORE__'] = null;
      default:
    }

    final libraries = <String>[];
    if (os == OS.linux) libraries.add('asound');
    if (os == OS.windows) libraries.add('winmm');

    // Флаги — красиво и по уму
    final flags = <String>[
      if (os == OS.windows) ...[
        '/std:c++17',
        '/EHsc',                    // exceptions
        '/GR',                      // RTTI
        '/D_CRT_SECURE_NO_WARNINGS',
      ] else ...[
        '-std=c++17',
        if (os != OS.android) ...[
          '-fexceptions',
          '-frtti',
          '-static-libgcc',
          '-static-libstdc++',
        ] else ...[
          // Android — чисто, без зависимостей
          '-fno-rtti',
          '-fno-exceptions',
          '-static-libgcc',
          '-lc++_static',           // ← ВСЁ, БОЛЬШЕ НИЧЕГО НЕ НУЖНО
          '-Wl,--gc-sections',
        ],
      ],
    ];

    final builder = CBuilder.library(
      name: 'rtmidi',
      assetName: 'package:rtmidi_dart/rtmidi',
      sources: sources,
      includes: [srcDir],
      defines: defines,
      language: Language.cpp,
      flags: flags,
      libraries: libraries,
      cppLinkStdLib: os == OS.android ? 'static' : 'dynamic',
    );

    await builder.run(input: input, output: output);
  });
}