// lib/components/validators.dart

typedef Validator = String? Function(String? value);

class FieldValidators {
  /// 非空校验
  /// [fieldName] 用于在提示语中显示该字段名称，可选
  static Validator nonEmpty({String fieldName = '该字段'}) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName 不能为空';
      }
      return null;
    };
  }
}
