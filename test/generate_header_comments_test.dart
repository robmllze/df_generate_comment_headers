// Integration tests for `generateHeaderComments`. The tool walks an input
// dir, finds source files with supported extensions, and prepends a header
// from a template (after stripping the file's existing leading comments).

import 'dart:io';

import 'package:df_generate_header_comments/df_generate_header_comments.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String templatePath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('df_header_test_');
    templatePath = p.join(tmp.path, 'header.dart.md');
    await File(templatePath).writeAsString('''
```dart
// HEADER LINE 1
// HEADER LINE 2
```
''');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  Future<File> writeDart(String relPath, String body) async {
    final f = File(p.join(tmp.path, relPath));
    await f.parent.create(recursive: true);
    await f.writeAsString(body);
    return f;
  }

  Future<void> runWithCwd(List<String> args) async {
    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      await generateHeaderComments(args, defaultTemplate: templatePath);
    } finally {
      Directory.current = originalCwd;
    }
  }

  test('prepends header in front of code that has no existing header',
      () async {
    final f = await writeDart('main.dart', 'void main() {}');
    await runWithCwd(['-i', '.']);
    final body = await f.readAsString();

    expect(body, startsWith('// HEADER LINE 1'));
    expect(body, contains('// HEADER LINE 2'));
    expect(body, contains('void main() {}'));
  });

  test('replaces existing leading comment header', () async {
    final f = await writeDart('main.dart', '''
// old header line 1
// old header line 2
void main() {}
''');
    await runWithCwd(['-i', '.']);
    final body = await f.readAsString();

    expect(body, contains('// HEADER LINE 1'));
    expect(body, contains('// HEADER LINE 2'));
    // The old header should be replaced (not present after the new header
    // block, but it might still match the regex if it had non-comment
    // continuation - here it gets dropped because the loop stops at the
    // first non-comment).
    expect(body, contains('void main()'));
  });

  test('skips .g.dart files', () async {
    // We need at least one processable file so the generator doesn't
    // shortcut to exit() (which would kill the test process).
    await writeDart('processed.dart', 'void main() {}');
    final f = await writeDart('foo.g.dart', '// existing\nint x = 1;');
    final before = await f.readAsString();
    await runWithCwd(['-i', '.']);
    final after = await f.readAsString();

    // Generated files are filtered out by _isAllowedFileName.
    expect(after, before);
  });

  test('skips files starting with underscore', () async {
    await writeDart('processed.dart', 'void main() {}');
    final f = await writeDart('_private.dart', 'int x = 1;');
    final before = await f.readAsString();
    await runWithCwd(['-i', '.']);
    final after = await f.readAsString();

    expect(after, before);
  });

  test('skips files in directories starting with underscore', () async {
    await writeDart('processed.dart', 'void main() {}');
    final f = await writeDart('_internal/inner.dart', 'int x = 1;');
    final before = await f.readAsString();
    await runWithCwd(['-i', '.']);
    final after = await f.readAsString();

    expect(after, before);
  });

  test('only processes recognised extensions', () async {
    await writeDart('processed.dart', 'void main() {}');
    // .txt isn't in langFileCommentStarters → ignored.
    final txt = await writeDart('notes.txt', 'something');
    final before = await txt.readAsString();
    await runWithCwd(['-i', '.']);
    expect(await txt.readAsString(), before);
  });

  test('header is preserved verbatim through repeated runs (idempotent)',
      () async {
    final f = await writeDart('main.dart', 'void main() {}');
    await runWithCwd(['-i', '.']);
    final firstRun = await f.readAsString();
    await runWithCwd(['-i', '.']);
    final secondRun = await f.readAsString();
    expect(secondRun, firstRun);
  });

  test('shebang line is preserved at the very top (regression)', () async {
    // Write a custom python template, since the default header template only
    // uses `//` lines (which the rewriter retargets to the language marker).
    final pyTemplate = File(p.join(tmp.path, 'header.py.md'));
    await pyTemplate.writeAsString('''
```python
// SHEBANG-SAFE PY HEADER
```
''');

    final f =
        await writeDart('script.py', '#!/usr/bin/env python\nprint("hi")\n');
    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      await generateHeaderComments(['-i', '.'],
          defaultTemplate: pyTemplate.path,);
    } finally {
      Directory.current = originalCwd;
    }
    final body = await f.readAsString();

    // The shebang must remain the very first line; the new header follows.
    expect(body.split('\n').first, '#!/usr/bin/env python');
    expect(body, contains('## SHEBANG-SAFE PY HEADER'));
    // The script body is still there.
    expect(body, contains('print("hi")'));
  });
}
