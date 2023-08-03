// taken from https://github.com/dart-lang/test/blob/master/pkgs/test_api/test/utils.dart

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/group_entry.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/metadata.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/state.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_core/src/runner/engine.dart';
import 'package:test_core/src/runner/plugin/environment.dart';
import 'package:test_core/src/runner/runner_suite.dart';
import 'package:test_core/src/runner/suite.dart';

/// A dummy suite platform to use for testing suites.
final suitePlatform = SuitePlatform(Runtime.vm);

// The last state change detected via [expectStates].
State? lastState;

/// Returns a matcher that matches a callback or Future that throws a
/// [TestFailure] with the given [message].
///
/// [message] can be a string or a [Matcher].
Matcher throwsTestFailure(Object? message) => throwsA(isTestFailure(message));

/// Returns a matcher that matches a [TestFailure] with the given [message].
///
/// [message] can be a string or a [Matcher].
Matcher isTestFailure(Object? message) => const TypeMatcher<TestFailure>()
    .having((e) => e.message, 'message', message);

/// Returns a local [LiveTest] that runs [body].
LiveTest createTest(dynamic Function() body) {
  final test = LocalTest('test', Metadata(chainStackTraces: true), body);
  final suite = Suite(Group.root([test]), suitePlatform);
  return test.load(suite);
}

/// Runs [body] as a test.
///
/// Once it completes, returns the [LiveTest] used to run it.
Future<LiveTest> runTestBody(dynamic Function() body) async {
  final liveTest = createTest(body);
  await liveTest.run();
  return liveTest;
}

/// Asserts that [liveTest] has completed and passed.
///
/// If the test had any errors, they're surfaced nicely into the outer test.
void expectTestPassed(LiveTest liveTest) {
  // Since the test is expected to pass, we forward any current or future errors
  // to the outer test, because they're definitely unexpected.
  for (final error in liveTest.errors) {
    registerException(error.error, error.stackTrace);
  }
  liveTest.onError.listen((error) {
    registerException(error.error, error.stackTrace);
  });

  expect(liveTest.state.status, equals(Status.complete));
  expect(liveTest.state.result, equals(Result.success));
}

/// Asserts that [liveTest] failed with a single [TestFailure] whose message
/// matches [message].
void expectTestFailed(LiveTest liveTest, Object? message) {
  expect(liveTest.state.status, equals(Status.complete));
  expect(liveTest.state.result, equals(Result.failure));
  expect(liveTest.errors, hasLength(1));
  expect(liveTest.errors.first.error, isTestFailure(message));
}

/// Assert that the [test] callback causes a test to block until [stopBlocking]
/// is called at some later time.
///
/// [stopBlocking] is passed the return value of [test].
Future<void> expectTestBlocks(
  Object? Function() test,
  dynamic Function(dynamic) stopBlocking,
) async {
  late LiveTest liveTest;
  late Future<void> future;
  liveTest = createTest(() {
    final value = test();
    // ignore: avoid_types_on_closure_parameters
    future = pumpEventQueue().then((Object? _) {
      expect(liveTest.state.status, equals(Status.running));
      stopBlocking(value);
    });
  });

  await liveTest.run();
  expectTestPassed(liveTest);
  // Ensure that the outer test doesn't complete until the inner future
  // completes.
  return future;
}

/// Runs [body] with a declarer, runs all the declared tests, and asserts that
/// they pass.
///
/// This is typically used to run multiple tests where later tests make
/// assertions about the results of previous ones.
Future<void> expectTestsPass(void Function() body) async {
  final engine = declareEngine(body);
  final success = await engine.run();

  engine.liveTests.forEach(expectTestPassed);

  expect(success, isTrue);
}

/// Runs [body] with a declarer and returns the declared entries.
List<GroupEntry> declare(void Function() body) {
  final declarer = Declarer()..declare(body);
  return declarer.build().entries;
}

/// Runs [body] with a declarer and returns an engine that runs those tests.
Engine declareEngine(void Function() body, {bool runSkipped = false}) {
  final declarer = Declarer()..declare(body);
  return Engine.withSuites([
    RunnerSuite(
        const PluginEnvironment(),
        SuiteConfiguration.runSkipped(runSkipped),
        declarer.build(),
        suitePlatform)
  ]);
}
