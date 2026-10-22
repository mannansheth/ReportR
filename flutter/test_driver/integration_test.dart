import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final output = Directory('build/phone-validation');
      await output.create(recursive: true);
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
