// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentRecord {

 String get id; String get saleId; String get method; Money get amount; String? get referenceNote; String get status;
/// Create a copy of PaymentRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentRecordCopyWith<PaymentRecord> get copyWith => _$PaymentRecordCopyWithImpl<PaymentRecord>(this as PaymentRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.method, method) || other.method == method)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.referenceNote, referenceNote) || other.referenceNote == referenceNote)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,saleId,method,amount,referenceNote,status);

@override
String toString() {
  return 'PaymentRecord(id: $id, saleId: $saleId, method: $method, amount: $amount, referenceNote: $referenceNote, status: $status)';
}


}

/// @nodoc
abstract mixin class $PaymentRecordCopyWith<$Res>  {
  factory $PaymentRecordCopyWith(PaymentRecord value, $Res Function(PaymentRecord) _then) = _$PaymentRecordCopyWithImpl;
@useResult
$Res call({
 String id, String saleId, String method, Money amount, String? referenceNote, String status
});




}
/// @nodoc
class _$PaymentRecordCopyWithImpl<$Res>
    implements $PaymentRecordCopyWith<$Res> {
  _$PaymentRecordCopyWithImpl(this._self, this._then);

  final PaymentRecord _self;
  final $Res Function(PaymentRecord) _then;

/// Create a copy of PaymentRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? saleId = null,Object? method = null,Object? amount = null,Object? referenceNote = freezed,Object? status = null,}) {
  return _then(PaymentRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,saleId: null == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,referenceNote: freezed == referenceNote ? _self.referenceNote : referenceNote // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentRecord].
extension PaymentRecordPatterns on PaymentRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentRecord value)  $default,){
final _that = this;
switch (_that) {
case _PaymentRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentRecord value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String saleId,  String method,  Money amount,  String? referenceNote,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentRecord() when $default != null:
return $default(_that.id,_that.saleId,_that.method,_that.amount,_that.referenceNote,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String saleId,  String method,  Money amount,  String? referenceNote,  String status)  $default,) {final _that = this;
switch (_that) {
case _PaymentRecord():
return $default(_that.id,_that.saleId,_that.method,_that.amount,_that.referenceNote,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String saleId,  String method,  Money amount,  String? referenceNote,  String status)?  $default,) {final _that = this;
switch (_that) {
case _PaymentRecord() when $default != null:
return $default(_that.id,_that.saleId,_that.method,_that.amount,_that.referenceNote,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentRecord extends PaymentRecord {
  const _PaymentRecord({required this.id, required this.saleId, required this.method, required this.amount, this.referenceNote, required this.status}): super._();
  

@override final  String id;
@override final  String saleId;
@override final  String method;
@override final  Money amount;
@override final  String? referenceNote;
@override final  String status;

/// Create a copy of PaymentRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentRecordCopyWith<_PaymentRecord> get copyWith => __$PaymentRecordCopyWithImpl<_PaymentRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.method, method) || other.method == method)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.referenceNote, referenceNote) || other.referenceNote == referenceNote)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,saleId,method,amount,referenceNote,status);

@override
String toString() {
  return 'PaymentRecord(id: $id, saleId: $saleId, method: $method, amount: $amount, referenceNote: $referenceNote, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PaymentRecordCopyWith<$Res> implements $PaymentRecordCopyWith<$Res> {
  factory _$PaymentRecordCopyWith(_PaymentRecord value, $Res Function(_PaymentRecord) _then) = __$PaymentRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String saleId, String method, Money amount, String? referenceNote, String status
});




}
/// @nodoc
class __$PaymentRecordCopyWithImpl<$Res>
    implements _$PaymentRecordCopyWith<$Res> {
  __$PaymentRecordCopyWithImpl(this._self, this._then);

  final _PaymentRecord _self;
  final $Res Function(_PaymentRecord) _then;

/// Create a copy of PaymentRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? saleId = null,Object? method = null,Object? amount = null,Object? referenceNote = freezed,Object? status = null,}) {
  return _then(_PaymentRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,saleId: null == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,referenceNote: freezed == referenceNote ? _self.referenceNote : referenceNote // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
