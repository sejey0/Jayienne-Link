import 'dart:math';

class InviteCodeGenerator {
  InviteCodeGenerator._();

  // Safe charset: no ambiguous characters (0/O, 1/I/L)
  static const String _charset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;

  static final _random = Random.secure();

  static String generate() {
    return List.generate(
      _codeLength,
      (_) => _charset[_random.nextInt(_charset.length)],
    ).join();
  }
}
