// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BusinessSettings {

 String get businessName; String? get address; String? get phone; String? get receiptFooter; String get currency; int get paperWidthMm;
/// Create a copy of BusinessSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessSettingsCopyWith<BusinessSettings> get copyWith => _$BusinessSettingsCopyWithImpl<BusinessSettings>(this as BusinessSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessSettings&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.receiptFooter, receiptFooter) || other.receiptFooter == receiptFooter)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.paperWidthMm, paperWidthMm) || other.paperWidthMm == paperWidthMm));
}


@override
int get hashCode => Object.hash(runtimeType,businessName,address,phone,receiptFooter,currency,paperWidthMm);

@override
String toString() {
  return 'BusinessSettings(businessName: $businessName, address: $address, phone: $phone, receiptFooter: $receiptFooter, currency: $currency, paperWidthMm: $paperWidthMm)';
}


}

/// @nodoc
abstract mixin class $BusinessSettingsCopyWith<$Res>  {
  factory $BusinessSettingsCopyWith(BusinessSettings value, $Res Function(BusinessSettings) _then) = _$BusinessSettingsCopyWithImpl;
@useResult
$Res call({
 String businessName, String? address, String? phone, String? receiptFooter, String currency, int paperWidthMm
});




}
/// @nodoc
class _$BusinessSettingsCopyWithImpl<$Res>
    implements $BusinessSettingsCopyWith<$Res> {
  _$BusinessSettingsCopyWithImpl(this._self, this._then);

  final BusinessSettings _self;
  final $Res Function(BusinessSettings) _then;

/// Create a copy of BusinessSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? businessName = null,Object? address = freezed,Object? phone = freezed,Object? receiptFooter = freezed,Object? currency = null,Object? paperWidthMm = null,}) {
  return _then(BusinessSettings(
businessName: null == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,receiptFooter: freezed == receiptFooter ? _self.receiptFooter : receiptFooter // ignore: cast_nullable_to_non_nullable
as String?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,paperWidthMm: null == paperWidthMm ? _self.paperWidthMm : paperWidthMm // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessSettings].
extension BusinessSettingsPatterns on BusinessSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessSettings value)  $default,){
final _that = this;
switch (_that) {
case _BusinessSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessSettings value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String businessName,  String? address,  String? phone,  String? receiptFooter,  String currency,  int paperWidthMm)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessSettings() when $default != null:
return $default(_that.businessName,_that.address,_that.phone,_that.receiptFooter,_that.currency,_that.paperWidthMm);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String businessName,  String? address,  String? phone,  String? receiptFooter,  String currency,  int paperWidthMm)  $default,) {final _that = this;
switch (_that) {
case _BusinessSettings():
return $default(_that.businessName,_that.address,_that.phone,_that.receiptFooter,_that.currency,_that.paperWidthMm);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String businessName,  String? address,  String? phone,  String? receiptFooter,  String currency,  int paperWidthMm)?  $default,) {final _that = this;
switch (_that) {
case _BusinessSettings() when $default != null:
return $default(_that.businessName,_that.address,_that.phone,_that.receiptFooter,_that.currency,_that.paperWidthMm);case _:
  return null;

}
}

}

/// @nodoc


class _BusinessSettings extends BusinessSettings {
  const _BusinessSettings({required this.businessName, this.address, this.phone, this.receiptFooter, required this.currency, required this.paperWidthMm}): super._();
  

@override final  String businessName;
@override final  String? address;
@override final  String? phone;
@override final  String? receiptFooter;
@override final  String currency;
@override final  int paperWidthMm;

/// Create a copy of BusinessSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessSettingsCopyWith<_BusinessSettings> get copyWith => __$BusinessSettingsCopyWithImpl<_BusinessSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessSettings&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.receiptFooter, receiptFooter) || other.receiptFooter == receiptFooter)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.paperWidthMm, paperWidthMm) || other.paperWidthMm == paperWidthMm));
}


@override
int get hashCode => Object.hash(runtimeType,businessName,address,phone,receiptFooter,currency,paperWidthMm);

@override
String toString() {
  return 'BusinessSettings(businessName: $businessName, address: $address, phone: $phone, receiptFooter: $receiptFooter, currency: $currency, paperWidthMm: $paperWidthMm)';
}


}

/// @nodoc
abstract mixin class _$BusinessSettingsCopyWith<$Res> implements $BusinessSettingsCopyWith<$Res> {
  factory _$BusinessSettingsCopyWith(_BusinessSettings value, $Res Function(_BusinessSettings) _then) = __$BusinessSettingsCopyWithImpl;
@override @useResult
$Res call({
 String businessName, String? address, String? phone, String? receiptFooter, String currency, int paperWidthMm
});




}
/// @nodoc
class __$BusinessSettingsCopyWithImpl<$Res>
    implements _$BusinessSettingsCopyWith<$Res> {
  __$BusinessSettingsCopyWithImpl(this._self, this._then);

  final _BusinessSettings _self;
  final $Res Function(_BusinessSettings) _then;

/// Create a copy of BusinessSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? businessName = null,Object? address = freezed,Object? phone = freezed,Object? receiptFooter = freezed,Object? currency = null,Object? paperWidthMm = null,}) {
  return _then(_BusinessSettings(
businessName: null == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,receiptFooter: freezed == receiptFooter ? _self.receiptFooter : receiptFooter // ignore: cast_nullable_to_non_nullable
as String?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,paperWidthMm: null == paperWidthMm ? _self.paperWidthMm : paperWidthMm // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
