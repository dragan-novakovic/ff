import 'package:intl/intl.dart';

class Utils {
  static number(int value) {
    return NumberFormat.decimalPattern('en_US').format(value);
  }
}
