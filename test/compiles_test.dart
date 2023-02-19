import 'package:expect_error/src/expect_error.dart';
import 'package:test/test.dart';
import 'package:test_api/src/backend/state.dart';

import 'utils.dart';

Future<void> main() async {
  final library = await Library.parseFromStacktrace();

  test('supports flutter through a Library pointing to a separate package',
      () async {
    final flutterLibrary = await Library.custom(
      packageName: 'example',
      path: 'lib/foo.dart',
      packageRoot: 'flutter_package',
    );

    final liveTest = await runTestBody(() async {
      await expectLater(flutterLibrary.withCode('''
import 'package:flutter/material.dart';
import 'widget.dart';

// expect-error: NON_ABSTRACT_CLASS_INHERITS_ABSTRACT_MEMBER
class Check extends StatelessWidget {
  const Check({Key? key}): super(key: key);
}

void main() {
  runApp(MyWidget());
}
'''), compiles);
    });

    expectTestPassed(liveTest);
  });

  test('supports relative path dependencies', () async {
    final library = await Library.custom(
      packageName: 'example',
      path: 'lib/foo.dart',
      packageRoot: 'flutter_package',
    );

    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
import 'package:expect_error/expect_error.dart';
'''), compiles);
    });

    expectTestPassed(liveTest);
  });

  test('can use relative imports based on the file location', () async {
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

  test('can ignore compilation error with matching expect-error', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error: INVALID_ASSIGNMENT
  int a = '42';
}
'''), compiles);
    });

    expectTestPassed(liveTest);
  });

  test(
      'can catch multiple errors on the same line at once by separating codes with a comma',
      () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
String fn(int a) => '';
void main() {
  // expect-error: NOT_ENOUGH_POSITIONAL_ARGUMENTS, INVALID_ASSIGNMENT
  int a = fn();
}
'''), compiles);
    });

    expectTestPassed(liveTest);

    final liveTest2 = await runTestBody(() async {
      await expectLater(library.withCode('''
String fn(int a) => '';
void main() {
  // expect-error: NOT_ENOUGH_POSITIONAL_ARGUMENTS,INVALID_ASSIGNMENT
  int a = fn();
}
'''), compiles);
    });

    expectTestPassed(liveTest2);
  });

  test('throws on compilation error if the error is not on the very next line',
      () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error: INVALID_ASSIGNMENT
  int b = '21';
  int a = '42';
}
'''), compiles);
    });

    expectTestFailed(
      liveTest,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );
  });

  test('throws on compilation error with no matching code', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
String fn(int a) => '';
void main() {
  // expect-error: NOT_ENOUGH_POSITIONAL_ARGUMENTS
  int a = fn();
}
'''), compiles);
    });

    expectTestFailed(
      liveTest,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );
  });

  test('expect-error with no code fails on compilation error', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error:
  int a = '42';
}
'''), compiles);
    });

    expectTestFailed(
      liveTest,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );

    final liveTest2 = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error
  int a = '42';
}
'''), compiles);
    });

    expectTestFailed(
      liveTest2,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );

    final liveTest3 = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error:
  int a = '42';
}
'''), compiles);
    });

    expectTestFailed(
      liveTest3,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );
  });

  test('throws on compilation error', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  int a = 'str';
}
'''), compiles);
    });
    expectTestFailed(
      liveTest,
      'No expect-error found for code INVALID_ASSIGNMENT but an error was found: '
      "A value of type 'String' can't be assigned to a variable of type 'int'.",
    );
  });

  test('throws when expect-error is specified but no matching error are found',
      () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('''
void main() {
  // expect-error: INVALID_ASSIGNMENT
  int a = 42;
}
'''), compiles);
    });

    expectTestFailed(
      liveTest,
      'Expected error with code INVALID_ASSIGNMENT but none were found',
    );
  });

  test('both tests succeed', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode(''), compiles);
      await expectLater(library.withCode(''), compiles);
    });

    expectTestPassed(liveTest);
  });
  test('first test succeeds, second fails', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode(''), compiles);
      await expectLater(library.withCode('NoSuchType? test;'), compiles);
    });

    expectTestFailed(
      liveTest,
      "No expect-error found for code UNDEFINED_CLASS but an error was found: Undefined class 'NoSuchType'.",
    );
  });
  test('first test fails, second succeeds', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('NoSuchType? test;'), compiles);
      await expectLater(library.withCode(''), compiles);
    });

    expectTestFailed(
      liveTest,
      "No expect-error found for code UNDEFINED_CLASS but an error was found: Undefined class 'NoSuchType'.",
    );
  });
  test('both test fail', () async {
    final liveTest = await runTestBody(() async {
      await expectLater(library.withCode('NoSuchType? test;'), compiles);
      await expectLater(library.withCode('NoSuchType? test;'), compiles);
    });

    expect(liveTest.state.status, equals(Status.complete));
    expect(liveTest.state.result, equals(Result.failure));
    expect(liveTest.errors, hasLength(2));
    expect(
        liveTest.errors.first.error,
        isTestFailure(
            "No expect-error found for code UNDEFINED_CLASS but an error was found: Undefined class 'NoSuchType'."));
    expect(
        liveTest.errors[1].error,
        isTestFailure(
            "No expect-error found for code UNDEFINED_CLASS but an error was found: Undefined class 'NoSuchType'."));
  });
}
