// ignore_for_file: avoid_print

part of './../../../on_process_camera.dart';

/// Prints a styled debug log in the console, optionally pretty-printing JSON.
///
/// This method only logs in **debug mode** (`kDebugMode == true`). It supports:
/// - Colored output using ANSI codes
/// - Optional bold and underline styling
/// - Pretty-printed output for `Map`, `List`, and valid JSON strings
/// - Optional heading with divider lines
///
/// ---
///
/// ### Parameters:
///
/// - [message] *(dynamic)*: Any value to be logged. Maps, Lists, or valid JSON
/// strings are printed as formatted JSON.
/// - [heading] *(String)*: Optional title for the log section.
/// - [color] *(DevPrintColorEnum?)*: ANSI color for the log output.
/// - [isBold] *(bool)*: If `true`, applies bold formatting.
/// - [isUnderline] *(bool)*: If `true`, underlines the output.
///
/// ---
///
/// ### Example:
///
/// ```dart
/// devPrint(
///   {'name': 'Panna', 'role': 'Flutter Dev'},
///   heading: '👨‍💻 Profile',
///   color: DevPrintColorEnum.green,
///   isBold: true,
/// );
/// ```
///
/// ---
///
/// ### Output:
/// ```
/// [Log] - ----------------------------------------------------------------
/// 👨‍💻 Profile
/// [Log] - {
/// [Log] -   "name": "Panna",
/// [Log] -   "role": "Flutter Dev"
/// [Log] - }
/// [Log] - ----------------------------------------------------------------
/// ```

// void devPrint(
//   dynamic message, {
//   String heading = '',
//   bool isBold = false,
//   bool isUnderline = false,
//   PrintStateType printStateType = PrintStateType.normal,
// }) {
//   _devPrint(
//     message,
//     heading: heading,
//     color: _DevPrintColorEnum.magenta,
//     isBold: isBold,
//     isUnderline: isUnderline,
//     printStateType: printStateType,
//   );
// }

void _devPrint(
  dynamic message, {
  String heading = '',
  _DevPrintColorEnum? color,
  bool isBold = false,
  bool isUnderline = false,
  PrintStateType printStateType = PrintStateType.normal,
}) {
  if (!kDebugMode) return;

  const String resetColor = '\x1B[0m';
  final String bold = isBold ? '\x1B[1m' : '';
  final String underline = isUnderline ? '\x1B[4m' : '';
  final String logPrefix =
      '${_DevPrintColorEnum.white.code}[OnCamera] - $resetColor';

  try {
    // Try to format message as pretty JSON
    String message_;
    // if (message is Map || message is List) {
    //   message_ = const JsonEncoder.withIndent('  ').convert(message);
    // } else {
    //   try {
    //     final dynamic parsed = json.decode(message.toString());
    //     message_ = const JsonEncoder.withIndent('  ').convert(parsed);
    //   } catch (_) {
    //     message_ = message.toString().trim();
    //   }
    // }

    try {
      if (message is Map || message is List) {
        message_ = const JsonEncoder.withIndent('  ').convert(
          // ignore: avoid_dynamic_calls
          message.map((dynamic key, Object? value) {
            try {
              json.encode(value);
              return MapEntry<dynamic, Object?>(key, value);
            } catch (_) {
              return MapEntry<dynamic, Object?>(key, value.toString());
            }
          }),
        );
      } else {
        try {
          final dynamic parsed = json.decode(message.toString());
          message_ = const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          message_ = message.toString().trim();
        }
      }
    } catch (e) {
      rethrow;
    }

    final List<String> stringList = message_.split('\n');

    // Get terminal width or default
    int count = 100;
    try {
      count = stdout.terminalColumns;
    } catch (_) {}

    final String coloredPrefix =
        '$logPrefix$bold$underline${color?.code ?? ''}';
    String dividerLine = '';
    bool printDash = stringList.length > 1 || heading.isNotEmpty;
    if (printStateType != PrintStateType.normal) printDash = true;

    bool showThisSection;

    //! -------------------------------------------- Print heading if applicable
    showThisSection =
        printStateType == PrintStateType.normal ||
        printStateType == PrintStateType.heading;
    if (showThisSection && printDash) {
      int length = count - heading.length - 1;
      if (length < 0) length = 0;
      dividerLine = '-' * length;
      print(
        '''$coloredPrefix$dividerLine ${_DevPrintColorEnum.yellow.code}$heading$resetColor''',
      );
    }

    //! ---------------------------------------------------- Print message lines
    // showThisSection = printStateType == PrintStateType.normal ||
    //     printStateType == PrintStateType.result;

    for (final String line in stringList) {
      if (line.isEmpty) continue;

      // const int maxChunk = 800; // Safe for IDEs, below debugPrint's 1024
      // int start = 0;

      // while (start < line.length) {
      //   final end =
      //       min(start + maxChunk, line.length);
      //   final chunk = line.substring(start, end);
      //   debugPrint('${start != 0 ? '' : coloredPrefix}$chunk$resetColor');
      //   start = end;
      // }

      // Logger().log(Level.info, '$coloredPrefix$line$resetColor');

      String printMessage = '$coloredPrefix$line$resetColor';

      print(printMessage);

      // stdout.write('$coloredPrefix$line$resetColor');
    }

    //! ----------------------------------------------------- Print closing line
    showThisSection =
        printStateType == PrintStateType.normal ||
        printStateType == PrintStateType.ending;
    if (showThisSection && printDash) {
      dividerLine = '-' * count;
      print('$coloredPrefix$dividerLine$resetColor');
    }
  } catch (e) {
    print(
      '$logPrefix${_DevPrintColorEnum.red.code}Error(devPrint): $e$resetColor',
    );
  }
}

enum PrintStateType {
  /// Normal will give full result with heading, data, ending
  normal,

  /// Will give only heading
  heading,

  /// Will give only ending
  ending,

  /// Will give only result
  result,
}

/// Enum representing ANSI escape codes for coloring and formatting console
/// output.
///
/// Each value of [_DevPrintColorEnum] corresponds to a specific ANSI escape
/// code that can be used to format text with colors in supported terminals.
enum _DevPrintColorEnum {
  /// 🔴 Sets the text color to red. `ERROR`
  red('\x1B[31m'),

  /// 🟢 Sets the text color to green. `SUCCESSFUL`
  green('\x1B[32m'),

  /// 🟡 Sets the text color to yellow. `WARNING`
  yellow('\x1B[33m'),

  /// 🔵 Sets the text color to blue.
  // ignore: unused_field
  blue('\x1B[34m'),

  /// 🟣 Sets the text color to magenta.
  magenta('\x1B[35m'),

  /// ⚫ Sets the text color to black.
  black('\x1B[30m'),

  /// ⚪ Sets the text color to white.
  white('\x1B[37m');

  /// Constructor to associate an ANSI escape code with the enum value.
  ///
  /// Each enum value has a [code] property containing the escape code string.
  const _DevPrintColorEnum(this.code);

  /// The ANSI escape code for this color or style.
  final String code;
}
