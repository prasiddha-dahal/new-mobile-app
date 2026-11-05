/// A grep over the swept source for English that never reaches the ARB files.
///
/// The other tests check that a screen *changes* when the language does. This
/// one checks the opposite direction: that no new literal is added to a screen
/// that has already been swept. A widget test only catches a literal on a
/// screen it happens to pump; this catches one anywhere under `lib/`.
///
/// It is deliberately narrow. It looks only at the places a literal is almost
/// always copy — `Text('…')` and the handful of named arguments that feed one
/// — and it ignores everything that is not a sentence: route paths, wire
/// values, font names, glyphs, format strings. A test that flagged those would
/// be turned off within a week, and a test that is off catches nothing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything swept. All of `lib/` is in scope now; the list is a list rather
/// than a blanket so that adding a new directory is a deliberate act.
const _sweptDirectories = [
  'lib/core',
  'lib/features',
];

/// Files inside those directories that are deliberately not swept.
///
/// Empty, and worth keeping that way: the last entry was the dead prototype
/// bottom bar, which was deleted rather than exempted a second time.
const _exemptFiles = <String>{};

/// The escape hatch, for a literal that is genuinely data.
///
/// Put `// l10n:value` at the end of the line. It is deliberately explicit
/// and greppable: the places that need it are lists whose entries are *keys*
/// resolved to a label at render time, and a contact detail that is a real
/// address rather than a sentence. Anything else with this marker on it is
/// somebody opting out of the sweep, and `git grep` will find them.
const _valueMarker = '// l10n:value';

/// A literal inside one of these is a value, not copy.
///
/// `Semantics(identifier:)` names a node for a test rather than a reader;
/// `fontFamily`, `debugLabel` and the rest are never spoken aloud.
final _valueArguments = RegExp(
  r'(fontFamily|debugLabel|identifier|restorationId|semanticsIdentifier|'
  r'wireValue|endpoint|route|path|name):\s*$',
);

/// A quoted string, either kind, captured as `body`.
const _quoted = r"""(['"])(?<body>(?:[^'"\\]|\\.)+)\1""";

/// Named arguments whose value is shown to a reader.
const _copyArguments =
    'hintText|labelText|helperText|errorText|title|description|message|'
    'tooltip|semanticLabel|label|subtitle|detail|body|successMessage|meta';

/// Constructors whose first positional argument is shown to a reader.
const _copyConstructors = r'Text|AppButton\.text|FieldLabel|_Label';

/// Where a literal is copy often enough to be worth checking.
final _copyPatterns = <RegExp>[
  RegExp('\\b(?:$_copyConstructors)\\(\\s*$_quoted'),
  RegExp('\\b(?:$_copyArguments):\\s*$_quoted'),
];

/// Strings that look like sentences but are not.
bool _isCopy(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  // A route, a wire value, a JSON key, a font name, a glyph, a number.
  if (trimmed.startsWith('/')) return false;
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(trimmed)) return false;
  if (RegExp(r'^[a-z][a-zA-Z0-9_]*$').hasMatch(trimmed)) return false;
  if (RegExp(r'^[^A-Za-z]*$').hasMatch(trimmed)) return false;
  // Interpolation only — `'$name'` is a value the caller supplied.
  if (RegExp(r'^\$[{a-zA-Z]').hasMatch(trimmed) &&
      !RegExp(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}').hasMatch(trimmed)) {
    return false;
  }
  // Needs at least one run of letters that could be a word.
  return RegExp(r'[A-Za-z]{3,}').hasMatch(trimmed);
}

void main() {
  test('no swept file renders a hardcoded English literal', () {
    final offenders = <String>[];

    for (final dir in _sweptDirectories) {
      final directory = Directory(dir);
      expect(
        directory.existsSync(),
        isTrue,
        reason: '$dir is in the swept list but does not exist',
      );

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = entity.path.replaceAll(r'\', '/');
        if (relative.endsWith('.g.dart') ||
            relative.endsWith('.freezed.dart')) {
          continue;
        }
        if (_exemptFiles.any(relative.endsWith)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final code = line.trimLeft();
          if (code.startsWith('//')) continue;
          if (line.contains(_valueMarker)) continue;
          // A named argument whose value is on the next line: look at what
          // introduced it before deciding.
          final previous = i == 0 ? '' : lines[i - 1].trimRight();
          if (_valueArguments.hasMatch(previous)) continue;

          for (final pattern in _copyPatterns) {
            for (final match in pattern.allMatches(line)) {
              final body = match.namedGroup('body')!;
              if (!_isCopy(body)) continue;
              offenders.add('$relative:${i + 1}  $body');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These read as English copy but never pass through the ARB files, '
          'so a Nepali reader sees them in English:\n  '
          '${offenders.join('\n  ')}\n'
          'Move each into lib/l10n/app_en.arb and app_ne.arb, or — if it is '
          'genuinely not copy — give the literal a name this test recognises '
          'as a value.',
    );
  });
}
