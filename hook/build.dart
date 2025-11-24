import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final os = input.config.code.targetOS;

    if (os == OS.android) {
      print('Android detected, skipping native compilation using MethodChannel');
      return;
    }

    final context = path.Context(
      style: Platform.isWindows ? path.Style.windows : path.Style.posix,
    );
    final packageRoot = Platform.isWindows
        ? input.packageRoot.path.substring(1)
        : input.packageRoot.path;

    final srcDir = context.join(packageRoot, 'src', 'rtmidi');

    final sources = [
      context.join(srcDir, 'RtMidi.cpp'),
      context.join(srcDir, 'rtmidi_c.c'),
    ];

    final defines = <String, String?>{};    

    switch (os) {
      case OS.linux:
        defines['__LINUX_ALSA__'] = null;
        break;
      case OS.windows:
        defines['__WINDOWS_MM__'] = null;
        defines['RTMIDI_EXPORT'] = null;
        break;
      case OS.macOS:
      case OS.iOS:
        defines['__MACOSX_CORE__'] = null;
        break;
      default:
    }

    final libraries = <String>[];
    if (os == OS.linux) libraries.add('asound');
    if (os == OS.windows) libraries.add('winmm');

    final flags = <String>[
      if (os == OS.windows) ...[
        '/std:c++17',
        '/EHsc',
        '/GR',
        '/D_CRT_SECURE_NO_WARNINGS',
      ] else ...[
        '-std=c++17',
        '-fexceptions',
        '-frtti',
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
    );

    await builder.run(input: input, output: output);
  });
}
