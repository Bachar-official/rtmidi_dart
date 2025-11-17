// hook/build.dart
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  // Включаем логирование
  Logger.root.level = Level.ALL;
  hierarchicalLoggingEnabled = true;

  await build(args, (input, output) async {
    final logger = Logger('rtmidi_build');
    logger.level = Level.ALL;

    final packageRoot = input.packageRoot.path;
    final srcDir = path.join(packageRoot, 'src', 'rtmidi');

    // ==========================
    // 1. Генерация FFI binding
    // ==========================
    logger.info('Generating bindings...');
    final configPath = path.join(packageRoot, 'ffigen.yaml');
    final ffigenResult = await Process.run('dart', [
      'run',
      'ffigen',
      '--config',
      configPath,
    ]);
    if (ffigenResult.exitCode != 0) {
      logger.severe('ffigen failed: ${ffigenResult.stderr}');
      throw Exception('ffigen failed');
    }

    // ==========================
    // 2. Компиляция C/C++ кода
    // ==========================
    logger.info('Compiling RtMidi...');

    final sources = [
      path.join(srcDir, 'RtMidi.cpp'),
      path.join(srcDir, 'rtmidi_c.cpp'),
    ];

    // Определяем макросы по платформе
    final defines = <String, String?>{'RTMIDI_BUILD': null};
    if (Platform.isWindows) {
      defines['__WINDOWS_MM__'] = null;
      defines['__RTMIDI_WINMM__'] = null;
    } else if (Platform.isLinux) {
      defines['__LINUX_ALSA__'] = null;
      defines['__RTMIDI_ALSA__'] = null;
    } else if (Platform.isAndroid) {
      defines['__ANDROID__'] = null;
      defines['__RTMIDI_AMIDI__'] = null;
    }

    // Создаем библиотеку
    final cBuilder = CBuilder.library(
      name: 'librtmidi',
      assetName: 'librtmidi',
      sources: sources,
      includes: [srcDir],
      defines: defines,
    );

    // Запускаем компиляцию — новый API автоматически кладет .so в output
    await cBuilder.run(input: input, output: output, logger: logger);

    logger.info('RtMidi built successfully! You can now use the plugin in Flutter.');
  });
}
