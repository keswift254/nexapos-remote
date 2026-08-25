// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CartState {

 List<CartItem> get items; String get saleType; Money get discount; String get customerName; String get customerPhone; String get paymentMethod; String get referenceNote;
/// Create a copy of CartState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CartStateCopyWith<CartState> get copyWith => _$CartStateCopyWithImpl<CartState>(this as CartState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CartState&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.saleType, saleType) || other.saleType == saleType)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.referenceNote, referenceNote) || other.referenceNote == referenceNote));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),saleType,discount,customerName,customerPhone,paymentMethod,referenceNote);

@override
String toString() {
  return 'CartState(items: $items, saleType: $saleType, discount: $discount, customerName: $customerName, customerPhone: $customerPhone, paymentMethod: $paymentMethod, referenceNote: $referenceNote)';
}


}

/// @nodoc
abstract mixin class $CartStateCopyWith<$Res>  {
  factory $CartStateCopyWith(CartState value, $Res Function(CartState) _then) = _$CartStateCopyWithImpl;
@useResult
$Res call({
 List<CartItem> items, String saleType, Money discount, String customerName, String customerPhone, String paymentMethod, String referenceNote
});




}
/// @nodoc
class _$CartStateCopyWithImpl<$Res>
    implements $CartStateCopyWith<$Res> {
  _$CartStateCopyWithImpl(this._self, this._then);

  final CartState _self;
  final $Res Function(CartState) _then;

/// Create a copy of CartState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? saleType = null,Object? discount = null,Object? customerName = null,Object? customerPhone = null,Object? paymentMethod = null,Object? referenceNote = null,}) {
  return _then(CartState(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CartItem>,saleType: null == saleType ? _self.saleType : saleType // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Money,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: null == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,referenceNote: null == referenceNote ? _self.referenceNote : referenceNote // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CartState].
extension CartStatePatterns on CartState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CartState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CartState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CartState value)  $default,){
final _that = this;
switch (_that) {
case _CartState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CartState value)?  $default,){
final _that = this;
switch (_that) {
case _CartState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CartItem> items,  String saleType,  Money discount,  String customerName,  String customerPhone,  String paymentMethod,  String referenceNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CartState() when $default != null:
return $default(_that.items,_that.saleType,_that.discount,_that.customerName,_that.customerPhone,_that.paymentMethod,_that.referenceNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CartItem> items,  String saleType,  Money discount,  String customerName,  String customerPhone,  String paymentMethod,  String referenceNote)  $default,) {final _that = this;
switch (_that) {
case _CartState():
return $default(_that.items,_that.saleType,_that.discount,_that.customerName,_that.customerPhone,_that.paymentMethod,_that.referenceNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CartItem> items,  String saleType,  Money discount,  String customerName,  String customerPhone,  String paymentMethod,  String referenceNote)?  $default,) {final _that = this;
switch (_that) {
case _CartState() when $default != null:
return $default(_that.items,_that.saleType,_that.discount,_that.customerName,_that.customerPhone,_that.paymentMethod,_that.referenceNote);case _:
  return null;

}
}

}

/// @nodoc


class _CartState extends CartState {
  const _CartState({ List<CartItem> items = const [], this.saleType = 'retail', this.discount = const Money.zero(), this.customerName = '', this.customerPhone = '', this.paymentMethod = 'cash', this.referenceNote = ''}): _items = items,super._();
  

 final  List<CartItem> _items;
@override@JsonKey() List<CartItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  String saleType;
@override@JsonKey() final  Money discount;
@override@JsonKey() final  String customerName;
@override@JsonKey() final  String customerPhone;
@override@JsonKey() final  String paymentMethod;
@override@JsonKey() final  String referenceNote;

/// Create a copy of CartState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CartStateCopyWith<_CartState> get copyWith => __$CartStateCopyWithImpl<_CartState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CartState&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.saleType, saleType) || other.saleType == saleType)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.referenceNote, referenceNote) || other.referenceNote == referenceNote));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),saleType,discount,customerName,customerPhone,paymentMethod,referenceNote);

@override
String toString() {
  return 'CartState(items: $items, saleType: $saleType, discount: $discount, customerName: $customerName, customerPhone: $customerPhone, paymentMethod: $paymentMethod, referenceNote: $referenceNote)';
}


}

/// @nodoc
abstract mixin class _$CartStateCopyWith<$Res> implements $CartStateCopyWith<$Res> {
  factory _$CartStateCopyWith(_CartState value, $Res Function(_CartState) _then) = __$CartStateCopyWithImpl;
@override @useResult
$Res call({
 List<CartItem> items, String saleType, Money discount, String customerName, String customerPhone, String paymentMethod, String referenceNote
});




}
/// @nodoc
class __$CartStateCopyWithImpl<$Res>
    implements _$CartStateCopyWith<$Res> {
  __$CartStateCopyWithImpl(this._self, this._then);

  final _CartState _self;
  final $Res Function(_CartState) _then;

/// Create a copy of CartState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? saleType = null,Object? discount = null,Object? customerName = null,Object? customerPhone = null,Object? paymentMethod = null,Object? referenceNote = null,}) {
  return _then(_CartState(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CartItem>,saleType: null == saleType ? _self.saleType : saleType // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Money,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: null == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,referenceNote: null == referenceNote ? _self.referenceNote : referenceNote // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
