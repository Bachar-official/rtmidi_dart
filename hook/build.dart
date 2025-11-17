// hook/build.dart
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  Logger.root.level = Level.ALL;
  hierarchicalLoggingEnabled = true;

  await build(args, (input, output) async {
    final logger = Logger('rtmidi_build');
    logger.level = Level.ALL;

    final packageRoot = input.packageRoot.path;
    final srcDir = path.join(packageRoot, 'src', 'rtmidi');

    // === 1. ffigen ===
    logger.info('Generating bindings...');
    final configPath = path.join(packageRoot, 'ffigen.yaml');
    final ffigenResult = await Process.run('dart', [
      'run', 'ffigen', '--config', configPath,
    ]);
    if (ffigenResult.exitCode != 0) {
      logger.severe('ffigen failed: ${ffigenResult.stderr}');
      throw Exception('ffigen failed');
    }

    // === 2. Compilation ===
    logger.info('Compiling RtMidi...');

    final sources = [
      path.join(srcDir, 'RtMidi.cpp'),
      path.join(srcDir, 'rtmidi_c.cpp'),
    ];

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

    final cBuilder = CBuilder.library(
      name: 'librtmidi',
      assetName: 'librtmidi',
      sources: sources,
      includes: [srcDir],
      defines: defines,
    );

    await cBuilder.run(input: input, output: output, logger: logger);

    // === 3. Copy to workdir (for dart run) ===
    final buildDir = Directory.current;
    final targetFile = File(path.join(buildDir.path, 'librtmidi.so'));
    final sourceFile = File(path.join(packageRoot, '.dart_tool', 'native_assets', 'current', 'librtmidi.so'));

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      logger.info('librtmidi.so copied to ${targetFile.path}');
    }

    logger.info('RtMidi ready for dart run');
  });
}