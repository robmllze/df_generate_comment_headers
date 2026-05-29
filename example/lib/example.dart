// The use of this source code is governed by the LICENSE file located in this
// project's root directory.

import 'package:df_generate_header_comments/df_generate_header_comments.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main(List<String> args) async {
  await generateHeaderComments(args, defaultTemplate: 'v1.dart.md');
}
