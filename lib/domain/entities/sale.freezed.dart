// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Sale {

 String get id; String get saleNumber; String get userId; String get customerName; String? get customerPhone; String get saleType; String get paymentMethod; Money get subtotal; Money get discount; Money get total; String get status; DateTime get createdAt;
/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleCopyWith<Sale> get copyWith => _$SaleCopyWithImpl<Sale>(this as Sale, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sale&&(identical(other.id, id) || other.id == id)&&(identical(other.saleNumber, saleNumber) || other.saleNumber == saleNumber)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.saleType, saleType) || other.saleType == saleType)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,saleNumber,userId,customerName,customerPhone,saleType,paymentMethod,subtotal,discount,total,status,createdAt);

@override
String toString() {
  return 'Sale(id: $id, saleNumber: $saleNumber, userId: $userId, customerName: $customerName, customerPhone: $customerPhone, saleType: $saleType, paymentMethod: $paymentMethod, subtotal: $subtotal, discount: $discount, total: $total, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SaleCopyWith<$Res>  {
  factory $SaleCopyWith(Sale value, $Res Function(Sale) _then) = _$SaleCopyWithImpl;
@useResult
$Res call({
 String id, String saleNumber, String userId, String customerName, String? customerPhone, String saleType, String paymentMethod, Money subtotal, Money discount, Money total, String status, DateTime createdAt
});




}
/// @nodoc
class _$SaleCopyWithImpl<$Res>
    implements $SaleCopyWith<$Res> {
  _$SaleCopyWithImpl(this._self, this._then);

  final Sale _self;
  final $Res Function(Sale) _then;

/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? saleNumber = null,Object? userId = null,Object? customerName = null,Object? customerPhone = freezed,Object? saleType = null,Object? paymentMethod = null,Object? subtotal = null,Object? discount = null,Object? total = null,Object? status = null,Object? createdAt = null,}) {
  return _then(Sale(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,saleNumber: null == saleNumber ? _self.saleNumber : saleNumber // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,saleType: null == saleType ? _self.saleType : saleType // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as Money,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Money,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as Money,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Sale].
extension SalePatterns on Sale {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sale value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sale() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sale value)  $default,){
final _that = this;
switch (_that) {
case _Sale():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sale value)?  $default,){
final _that = this;
switch (_that) {
case _Sale() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String saleNumber,  String userId,  String customerName,  String? customerPhone,  String saleType,  String paymentMethod,  Money subtotal,  Money discount,  Money total,  String status,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sale() when $default != null:
return $default(_that.id,_that.saleNumber,_that.userId,_that.customerName,_that.customerPhone,_that.saleType,_that.paymentMethod,_that.subtotal,_that.discount,_that.total,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String saleNumber,  String userId,  String customerName,  String? customerPhone,  String saleType,  String paymentMethod,  Money subtotal,  Money discount,  Money total,  String status,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Sale():
return $default(_that.id,_that.saleNumber,_that.userId,_that.customerName,_that.customerPhone,_that.saleType,_that.paymentMethod,_that.subtotal,_that.discount,_that.total,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String saleNumber,  String userId,  String customerName,  String? customerPhone,  String saleType,  String paymentMethod,  Money subtotal,  Money discount,  Money total,  String status,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Sale() when $default != null:
return $default(_that.id,_that.saleNumber,_that.userId,_that.customerName,_that.customerPhone,_that.saleType,_that.paymentMethod,_that.subtotal,_that.discount,_that.total,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Sale extends Sale {
  const _Sale({required this.id, required this.saleNumber, required this.userId, required this.customerName, this.customerPhone, required this.saleType, required this.paymentMethod, required this.subtotal, required this.discount, required this.total, required this.status, required this.createdAt}): super._();
  

@override final  String id;
@override final  String saleNumber;
@override final  String userId;
@override final  String customerName;
@override final  String? customerPhone;
@override final  String saleType;
@override final  String paymentMethod;
@override final  Money subtotal;
@override final  Money discount;
@override final  Money total;
@override final  String status;
@override final  DateTime createdAt;

/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleCopyWith<_Sale> get copyWith => __$SaleCopyWithImpl<_Sale>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sale&&(identical(other.id, id) || other.id == id)&&(identical(other.saleNumber, saleNumber) || other.saleNumber == saleNumber)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.saleType, saleType) || other.saleType == saleType)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,saleNumber,userId,customerName,customerPhone,saleType,paymentMethod,subtotal,discount,total,status,createdAt);

@override
String toString() {
  return 'Sale(id: $id, saleNumber: $saleNumber, userId: $userId, customerName: $customerName, customerPhone: $customerPhone, saleType: $saleType, paymentMethod: $paymentMethod, subtotal: $subtotal, discount: $discount, total: $total, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SaleCopyWith<$Res> implements $SaleCopyWith<$Res> {
  factory _$SaleCopyWith(_Sale value, $Res Function(_Sale) _then) = __$SaleCopyWithImpl;
@override @useResult
$Res call({
 String id, String saleNumber, String userId, String customerName, String? customerPhone, String saleType, String paymentMethod, Money subtotal, Money discount, Money total, String status, DateTime createdAt
});




}
/// @nodoc
class __$SaleCopyWithImpl<$Res>
    implements _$SaleCopyWith<$Res> {
  __$SaleCopyWithImpl(this._self, this._then);

  final _Sale _self;
  final $Res Function(_Sale) _then;

/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? saleNumber = null,Object? userId = null,Object? customerName = null,Object? customerPhone = freezed,Object? saleType = null,Object? paymentMethod = null,Object? subtotal = null,Object? discount = null,Object? total = null,Object? status = null,Object? createdAt = null,}) {
  return _then(_Sale(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,saleNumber: null == saleNumber ? _self.saleNumber : saleNumber // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,saleType: null == saleType ? _self.saleType : saleType // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as Money,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Money,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as Money,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
