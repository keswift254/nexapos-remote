// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paystack_credentials.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaystackCredentials {

 String get baseUrl; String get apiKey; String get currency; String get defaultEmail;
/// Create a copy of PaystackCredentials
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaystackCredentialsCopyWith<PaystackCredentials> get copyWith => _$PaystackCredentialsCopyWithImpl<PaystackCredentials>(this as PaystackCredentials, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaystackCredentials&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.defaultEmail, defaultEmail) || other.defaultEmail == defaultEmail));
}


@override
int get hashCode => Object.hash(runtimeType,baseUrl,apiKey,currency,defaultEmail);

@override
String toString() {
  return 'PaystackCredentials(baseUrl: $baseUrl, apiKey: $apiKey, currency: $currency, defaultEmail: $defaultEmail)';
}


}

/// @nodoc
abstract mixin class $PaystackCredentialsCopyWith<$Res>  {
  factory $PaystackCredentialsCopyWith(PaystackCredentials value, $Res Function(PaystackCredentials) _then) = _$PaystackCredentialsCopyWithImpl;
@useResult
$Res call({
 String baseUrl, String apiKey, String currency, String defaultEmail
});




}
/// @nodoc
class _$PaystackCredentialsCopyWithImpl<$Res>
    implements $PaystackCredentialsCopyWith<$Res> {
  _$PaystackCredentialsCopyWithImpl(this._self, this._then);

  final PaystackCredentials _self;
  final $Res Function(PaystackCredentials) _then;

/// Create a copy of PaystackCredentials
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseUrl = null,Object? apiKey = null,Object? currency = null,Object? defaultEmail = null,}) {
  return _then(PaystackCredentials(
baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,defaultEmail: null == defaultEmail ? _self.defaultEmail : defaultEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaystackCredentials].
extension PaystackCredentialsPatterns on PaystackCredentials {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaystackCredentials value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaystackCredentials() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaystackCredentials value)  $default,){
final _that = this;
switch (_that) {
case _PaystackCredentials():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaystackCredentials value)?  $default,){
final _that = this;
switch (_that) {
case _PaystackCredentials() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String baseUrl,  String apiKey,  String currency,  String defaultEmail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaystackCredentials() when $default != null:
return $default(_that.baseUrl,_that.apiKey,_that.currency,_that.defaultEmail);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String baseUrl,  String apiKey,  String currency,  String defaultEmail)  $default,) {final _that = this;
switch (_that) {
case _PaystackCredentials():
return $default(_that.baseUrl,_that.apiKey,_that.currency,_that.defaultEmail);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String baseUrl,  String apiKey,  String currency,  String defaultEmail)?  $default,) {final _that = this;
switch (_that) {
case _PaystackCredentials() when $default != null:
return $default(_that.baseUrl,_that.apiKey,_that.currency,_that.defaultEmail);case _:
  return null;

}
}

}

/// @nodoc


class _PaystackCredentials extends PaystackCredentials {
  const _PaystackCredentials({required this.baseUrl, required this.apiKey, required this.currency, required this.defaultEmail}): super._();
  

@override final  String baseUrl;
@override final  String apiKey;
@override final  String currency;
@override final  String defaultEmail;

/// Create a copy of PaystackCredentials
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaystackCredentialsCopyWith<_PaystackCredentials> get copyWith => __$PaystackCredentialsCopyWithImpl<_PaystackCredentials>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaystackCredentials&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.defaultEmail, defaultEmail) || other.defaultEmail == defaultEmail));
}


@override
int get hashCode => Object.hash(runtimeType,baseUrl,apiKey,currency,defaultEmail);

@override
String toString() {
  return 'PaystackCredentials(baseUrl: $baseUrl, apiKey: $apiKey, currency: $currency, defaultEmail: $defaultEmail)';
}


}

/// @nodoc
abstract mixin class _$PaystackCredentialsCopyWith<$Res> implements $PaystackCredentialsCopyWith<$Res> {
  factory _$PaystackCredentialsCopyWith(_PaystackCredentials value, $Res Function(_PaystackCredentials) _then) = __$PaystackCredentialsCopyWithImpl;
@override @useResult
$Res call({
 String baseUrl, String apiKey, String currency, String defaultEmail
});




}
/// @nodoc
class __$PaystackCredentialsCopyWithImpl<$Res>
    implements _$PaystackCredentialsCopyWith<$Res> {
  __$PaystackCredentialsCopyWithImpl(this._self, this._then);

  final _PaystackCredentials _self;
  final $Res Function(_PaystackCredentials) _then;

/// Create a copy of PaystackCredentials
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseUrl = null,Object? apiKey = null,Object? currency = null,Object? defaultEmail = null,}) {
  return _then(_PaystackCredentials(
baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,defaultEmail: null == defaultEmail ? _self.defaultEmail : defaultEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
