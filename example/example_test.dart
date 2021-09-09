import 'package:expect_error/src/expect_error.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final library = await Library.parseFromStacktrace();

  test('String is not assignable to int', () async {
    await expectLater(library.withCode('''
import 'counter.dart';

void main() {
  final counter = Counter();
  // expect-error: INVALID_ASSIGNMENT
  counter.count = 'string';
}
'''), compiles);
  });
}
