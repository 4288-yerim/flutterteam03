class NicknameValidator {
  const NicknameValidator._();

  static const int minLength = 2;
  static const int maxLength = 12;
  static final RegExp _allowedPattern = RegExp(r'^[가-힣a-zA-Z0-9]+$');

  static String normalize(String? value) => value?.trim() ?? '';

  static String? validate(String? value) {
    final String nickname = normalize(value);

    if (nickname.isEmpty) {
      return '닉네임을 입력해 주세요.';
    }
    if (nickname.length < minLength || nickname.length > maxLength) {
      return '닉네임은 $minLength~$maxLength자로 입력해 주세요.';
    }
    if (!_allowedPattern.hasMatch(nickname)) {
      return '닉네임은 한글, 영문, 숫자만 사용할 수 있어요.';
    }

    return null;
  }
}
