part of './../../../on_process_camera.dart';

extension DoubleCalculation on double {
  __Fraction _aspectRatioToFraction({int precision = 10000}) {
    // Handle edge cases
    if (isNaN || isInfinite) throw ArgumentError('Invalid aspect ratio');

    // Convert to fraction by multiplying by precision
    int numerator = (this * precision).round();
    int denominator = precision;

    // Reduce to minimal fraction using GCD
    int divisor = __gcd(numerator, denominator);
    numerator ~/= divisor;
    denominator ~/= divisor;

    return __Fraction(numerator, denominator);
  }
}

// [_aspectRatioToFraction] helper function to calculate GCD
int __gcd(int a, int b) {
  a = a.abs();
  b = b.abs();
  while (b != 0) {
    int temp = b;
    b = a % b;
    a = temp;
  }
  return a;
}

// [_aspectRatioToFraction] helper class to hold fraction data
class __Fraction {
  __Fraction(this.numerator, this.denominator);
  final int numerator;
  final int denominator;

  @override
  String toString() => '$numerator:$denominator';
}
