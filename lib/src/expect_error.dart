import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:build_test/build_test.dart';
import 'package:collection/collection.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as _path;
import 'package:pubspec/pubspec.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/expect.dart';
import 'package:test/test.dart';

/// The representation of a dart file within a dart package
class Library {
  /// The representation of a dart file within a dart package
  Library({
    required this.packageName,
    required this.path,
    this.packageConfig,
  });

  /// Resolve a [Library] defined in a separate package, obtaining [packageConfig]
  /// from that package's package_config.json.
  static Future<Library> custom({
    required String packageName,
    required String path,
    required String packageRoot,
  }) async {
    final packageRootUri =
        Uri.parse('file://${Directory(packageRoot).absolute.path}')
            .normalizePath();

    final packageConfigString = File(
      _path.join(packageRoot, '.dart_tool', 'package_config.json'),
    ).readAsStringSync();

    final packageConfig = PackageConfig.parseString(
      packageConfigString,
      packageRootUri,
    );

    final tempTestFilePath = _path.join(packageRoot, path);

    return Library(
      packageName: packageName,
      path: _path.normalize(tempTestFilePath),
      packageConfig: packageConfig,
    );
  }

  /// Decode the [StackTrace] to try and extract informations about the current
  /// library.
  ///
  /// This should only be used within the "main" of a test file.
  static Future<Library> parseFromStacktrace() async {
    const testFilePath = '___temporary_test____.dart';

    final pubSpec = await PubSpec.load(Directory.current);

    // Relying on the Stacktrace to obtain the current test file name
    final stacktrace = Trace.from(StackTrace.current);
    final mainFrame = stacktrace.frames
        .lastWhereOrNull((element) => element.uri.isScheme('FILE'));

    if (mainFrame == null || pubSpec.name == null) {
      throw StateError('Failed to determine the current test file location');
    }

    final tempTestFilePath = _path.join(
      Directory.fromUri(Uri.parse(mainFrame.library)).parent.path,
      testFilePath,
    );

    return Library(
      packageName: pubSpec.name!,
      path: _path.normalize(tempTestFilePath),
      // packageConfig: null, // use package definition from the current Isolate
    );
  }

  /// The name of the package that this library belongs to.
  final String packageName;

  /// The absolute path to a dart file.
  final String path;

  /// The package configuration for this library.
  final PackageConfig? packageConfig;

  /// Creates an instance of [Code] from a raw string, to be used by [compiles].
  Code withCode(String code) => Code(code: code, library: this);
}

/// The representation of the source code for a dart file
class Code {
  /// The representation of the source code for a dart file
  Code({required this.code, required this.library});

  /// The file content
  final String code;

  /// Metadatas about the file
  final Library library;
}

/// Analyze a [Code] instance and verify that it has no error.
///
/// If the code contains comments under the form of `// expect-error: ERROR_CODE`,
/// [compiles] will expect that the very next line of code has an error with
/// the matching code.
///
/// If an `// expect-error` is added, but the next line doesn't have an error
/// with the matching code, the expectation will fail.
/// If the code has an error without a matching `// expect-error` on the previous
/// line, the expectation will also fail.
/// Otherwise, the expectation will pass.
///
///
/// A common usage would be:
///
/// ```dart
/// import 'package:expect_error/src/expect_error.dart';
/// import 'package:test/test.dart';
///
/// Future<void> main() async {
///   final library = await Library.parseFromStacktrace();
///
///   test('String is not assignable to int', () async {
///     await expectLater(library.withCode('''
/// class Counter {
///   int count = 0;
/// }
///
/// void main() {
///   final counter = Counter();
///   // expect-error: INVALID_ASSIGNMENT
///   counter.count = 'string';
/// }
/// '''), compiles);
///   });
/// }
/// ```
final compiles = _CompileMatcher();

class _CompileMatcher extends Matcher {
  @override
  Description describe(Description description) =>
      description.add('Dart code that compiles');

  @override
  bool matches(covariant Code source, Map matchState) {
    expectLater(_compile(source), completes);
    return true;
  }
}

class _ExpectErrorCode {
  _ExpectErrorCode(this.code, {required this.startOffset});

  final String code;
  final int startOffset;
  bool visited = false;
}

Future<void> _compile(Code code) async {
  final source = '''
library main;
${code.code}''';

  final expectedErrorRegex =
      RegExp(r'\/\/ ?expect-error:(.+)$', multiLine: true);

  final expectErrorCodes = expectedErrorRegex
      .allMatches(source)
      .map((match) {
        return match
            .group(1)!
            .split(',')
            .map((e) => _ExpectErrorCode(e.trim(), startOffset: match.start));
      })
      .flattened
      .toList();

  bool verifyAnalysisError(AnalysisError error) {
    final sourceBeforeError =
        error.source.contents.data.substring(0, error.offset);

    final previousLineRegex = RegExp(r'([^\n]*)\n.*?$');
    final previousLine = previousLineRegex.firstMatch(sourceBeforeError)!;
    final previousLineRange =
        SourceRange(previousLine.start, previousLine.group(1)!.length);

    for (final code in expectErrorCodes) {
      if (previousLineRange.contains(code.startOffset) &&
          code.code == error.errorCode.name) {
        code.visited = true;
        return true;
      }
    }

    return false;
  }

  final main = await resolveSources(
    {'${code.library.packageName}|${code.library.path}': source},
    (r) => r.findLibraryByName('main'),
    packageConfig: code.library.packageConfig,
  );

  final errorResult = await main!.session.getErrors(
    '/${code.library.packageName}/${code.library.path}',
  ) as ErrorsResult;
  final criticalErrors = errorResult.errors
      .where((element) => element.severity == Severity.error)
      .toList();

  for (final error in criticalErrors) {
    if (!verifyAnalysisError(error)) {
      fail(
        'No expect-error found for code ${error.errorCode.name} '
        'but an error was found: ${error.message}',
      );
    }
  }

  for (final expectError in expectErrorCodes) {
    if (!expectError.visited) {
      fail(
        'Expected error with code ${expectError.code} but none were found',
      );
    }
  }
}
