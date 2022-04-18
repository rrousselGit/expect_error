The `expect_error` package is a testing library inspired by Typescript's
`// @expect-error`, designed to help package authors to test compilation errors.

## Usage

`expect_error` exposes a `compiles` matcher, which can be used within unit tests.

A simple example would be:

```dart
// test/my_test.dart
import 'package:expect_error/expect_error.dart';
import 'package:test/test.dart';

void main() async {
  final library = await Library.parseFromStacktrace();

  test('String is not assignable to int', () async {
    await expectLater(library.withCode('''
// expect-error: INVALID_ASSIGNMENT
int value = "string";
'''), compiles);
  });
}
```

This example tests that the code:

```dart
int value = "string";
```

emits the compilation error "INVALID_ASSIGNMENT".

### FAQ: Why use a comment in the code block instead of a matcher?

You may wonder why:

```dart
await expectLater(library.withCode('''
// expect-error: INVALID_ASSIGNMENT
int value = "string";
'''), compiles);
```

is preferrable to:

```dart
await expectLater(library.withCode('''
int value = "string";
'''), throwsCompilationError('INVALID_ASSIGNMENT'));
```

The reason why `expect_error` relies on a comment is because a comment
doesn't simply communicate what the error is, but also **where** that error is.  
When using `// expect-error: x`, only the next line is allowed to emit the
compilation error.

As such, if we do:

```dart
await expectLater(library.withCode('''
void main() {
  // expect-error: INVALID_ASSIGNMENT
  print('a');
  int value = "string";
}
'''), compiles);
```

Then this test will fail. Because while the code block indeed contains an
`INVALID_ASSIGMENT` error, the error isn't on the `print` but instead on
the `int value = 'string'`.

To fix out test, we would have to move the comment on the line before the error:

```dart
await expectLater(library.withCode('''
void main() {
  print('a');
  // expect-error: INVALID_ASSIGNMENT
  int value = "string";
}
'''), compiles);
```

### Specifying multiple error codes at the same time.

It is possible for `expect-error` to specify multiple codes at once by separating
them with a `,`:

```dart
await expectLater(library.withCode(r'''
String fn(int a) => '';

// expect-error: NOT_ENOUGH_POSITIONAL_ARGUMENTS, INVALID_ASSIGNMENT
int a = fn();
'''), compiles);
```

### Importing files/packages in code blocks

It is possible to use `import` directives to import dart code within code blocks:

```dart
await expectLater(library.withCode(r'''
import 'package:riverpod/riverpod.dart';

final provider = Provider<int>((ref) {
  // expect-error: INVALID_ASSIGNMENT
  return 'string';
});
'''), compiles);
```

The imports available within our code blocks are dependent on that `library` variable.
When we do:

```dart
void main() async {
  final library = await Library.parseFromStacktrace();

  test('...', () async {
    await expectLater(library.withCode(...), compiles);
  });
}
```

that `library` variable we created tells `expect_error` what imports
the tested code block can use.

In particular, `Library.parseFromStacktrace()` makes our tested code behave as if
it was defined in a separate file within the same folder our test file.

As such, the following code is valid too:

```dart
import 'package:expect_error/expect_error.dart';
import 'package:test/test.dart';

// our test file can use relative import to import another file
import 'relative.dart';

void main() async {
  final library = await Library.parseFromStacktrace();

  test('...', () async {
    await expectLater(library.withCode('''
// our tested code can also import the same file
import 'relative.dart';
'''), compiles);
  });
}
```

## Flutter support

Unfortunately, since `expect_error` is built on top of the [analyzer](https://pub.dev/packages/analyzer)
package, it means that a package cannot both depend on Flutter and `expect_error` at
the same time.

As such, to use `expect_error` to test compilation errors when interacting with
Flutter, a workaround is necessary.  
The solution is to move your tests that depends on Flutter in a separate package
used only for test purpose, with no dependency on Flutter.

As example, consider a package `my_package` that depends on Flutter, which exposes a
`MyWidget` class:

```dart
// my_package/lib/my_widget.dart
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({Key? key, required String parameter}) : super(key: key);

  ...
}
```

To test this `MyWidget` class, rather than adding our test
within the `my_package/test` folder, we could create a new Dart project
such that our folder architecture looks like:

```
my_package
  puspec.yaml
  lib
    my_widget.dart
  expect_error_test
    pubspec.yaml
    test
      my_widget_test.dart
```

This `expect_error_test` app would depend on `expect_error`:

```yaml
name: expect_error_test
---
dev_dependencies:
  expect_error: ...
```

Then, within `expect_error_test/test/my_widget_test`, we could do:

```dart
void main() {
  final flutterLibrary = await Library.custom(
    packageName: 'my_package', // the name of the package that contains this code block
    packageRoot: '..', // the path to the root of this package
    path: 'test/my_test.dart', // where the codeblock is located within the package
  );

  await expectLater(flutterLibrary.withCode(r'''
import 'package:my_package/my_widget.dart';

void main() {
  // expect-error: MISSING_REQUIRED_ARGUMENT
  MyWidget();
}
'''), compiles);
}
```

Notice how rather than `Library.parseFromStacktrace()` we used `Library.custom(...)`.

By doing so, rather than assuming that our code block is within the same
folder as our test, we were able to make it behave as if our code block was
within `my_package`.

This way, our tests using `expect_error` are correctly able to import Flutter code.

## Sponsors

<p align="center">
  <a href="https://raw.githubusercontent.com/rrousselGit/freezed/master/sponsorkit/sponsors.svg">
    <img src='https://raw.githubusercontent.com/rrousselGit/freezed/master/sponsorkit/sponsors.svg'/>
  </a>
</p>
