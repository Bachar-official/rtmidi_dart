// hook/build.dart
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageRoot = input.packageRoot.path;
    final srcDir = path.join(packageRoot, 'src', 'rtmidi');

    // Опционально: ffigen (можно запускать отдельно, но если хочешь каждый раз — ок)
    // final ffigenResult = await Process.run(
    //   'dart',
    //   ['run', 'ffigen', '--config', path.join(packageRoot, 'ffigen.yaml')],
    // );
    // if (ffigenResult.exitCode != 0) {
    //   throw Exception('ffigen failed');
    // }

    final sources = [
      path.join(srcDir, 'RtMidi.cpp'),
      path.join(srcDir, 'rtmidi_c.cpp'),
    ];

    final defines = <String, String?>{};

    final os = input.config.code.targetOS;
    if (os == OS.linux) {
      defines['__LINUX_ALSA__'] = null;
    } else if (os == OS.windows) {
      defines['__WINDOWS_MM__'] = null;
    } else if (os == OS.android) {
      defines['__ANDROID__'] = null;
      defines['__RTMIDI_AMIDI__'] = null;
    } else if (os == OS.macOS) {
      defines['__MACOSX_CORE__'] = null;
    }

    final builder = CBuilder.library(
      name: 'rtmidi',
      assetName: 'package:rtmidi_dart/rtmidi',  // ← это и есть ID asset
      sources: sources,
      includes: [srcDir],
      defines: defines,
      language: Language.cpp,
      flags: ['-std=c++17', '-fexceptions', '-frtti'],
    );

    // ← Это всё! CBuilder сам соберёт и зарегистрирует asset
    await builder.run(input: input, output: output);
    // Больше ничего добавлять не нужно!
  });
}