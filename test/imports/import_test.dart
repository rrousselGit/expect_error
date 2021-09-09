import 'package:expect_error/expect_error.dart';
import 'package:test/test.dart';

import '../utils.dart';

Future<void> main() async {
  final library = await Library.parseFromStacktrace();

  test('can use relative imports based on the file location', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
import 'counter.dart';

void main() {
  final counter = Counter();
}
'''), compiles);
    });

    expectTestPassed(liveTest);
  });

  test('can manually specify the file path', () async {
    final library = Library(
      packageName: 'expect_error',
      path: 'test/foo.dart',
    );

    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
import 'imports/counter.dart';

void main() {
  final counter = Counter();
}
'''), compiles);
    });

    expectTestPassed(liveTest);
  });
}
