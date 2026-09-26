// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CartItem {

 String? get productId; String get name; Money get unitPrice; Money get costPrice; int get quantity; Money? get retailPrice; Money? get wholesalePrice;
/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CartItemCopyWith<CartItem> get copyWith => _$CartItemCopyWithImpl<CartItem>(this as CartItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CartItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CartItem&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&(identical(other.costPrice, _this.costPrice) || other.costPrice == _this.costPrice)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.retailPrice, _this.retailPrice) || other.retailPrice == _this.retailPrice)&&(identical(other.wholesalePrice, _this.wholesalePrice) || other.wholesalePrice == _this.wholesalePrice));
}


@override
int get hashCode {
  final _this = this as CartItem;
  return Object.hash(runtimeType,_this.productId,_this.name,_this.unitPrice,_this.costPrice,_this.quantity,_this.retailPrice,_this.wholesalePrice);
}

@override
String toString() {
  final _this = this as CartItem;
  return 'CartItem(productId: ${_this.productId}, name: ${_this.name}, unitPrice: ${_this.unitPrice}, costPrice: ${_this.costPrice}, quantity: ${_this.quantity}, retailPrice: ${_this.retailPrice}, wholesalePrice: ${_this.wholesalePrice})';
}


}

/// @nodoc
abstract mixin class $CartItemCopyWith<$Res>  {
  factory $CartItemCopyWith(CartItem value, $Res Function(CartItem) _then) = _$CartItemCopyWithImpl;
@useResult
$Res call({
 String? productId, String name, Money unitPrice, Money costPrice, int quantity, Money? retailPrice, Money? wholesalePrice
});




}
/// @nodoc
class _$CartItemCopyWithImpl<$Res>
    implements $CartItemCopyWith<$Res> {
  _$CartItemCopyWithImpl(this._self, this._then);

  final CartItem _self;
  final $Res Function(CartItem) _then;

/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = freezed,Object? name = null,Object? unitPrice = null,Object? costPrice = null,Object? quantity = null,Object? retailPrice = freezed,Object? wholesalePrice = freezed,}) {
  return _then(CartItem(
productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as Money,costPrice: null == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as Money,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,retailPrice: freezed == retailPrice ? _self.retailPrice : retailPrice // ignore: cast_nullable_to_non_nullable
as Money?,wholesalePrice: freezed == wholesalePrice ? _self.wholesalePrice : wholesalePrice // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}

}


/// Adds pattern-matching-related methods to [CartItem].
extension CartItemPatterns on CartItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CartItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CartItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CartItem value)  $default,){
final _that = this;
switch (_that) {
case _CartItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CartItem value)?  $default,){
final _that = this;
switch (_that) {
case _CartItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? productId,  String name,  Money unitPrice,  Money costPrice,  int quantity,  Money? retailPrice,  Money? wholesalePrice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CartItem() when $default != null:
return $default(_that.productId,_that.name,_that.unitPrice,_that.costPrice,_that.quantity,_that.retailPrice,_that.wholesalePrice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? productId,  String name,  Money unitPrice,  Money costPrice,  int quantity,  Money? retailPrice,  Money? wholesalePrice)  $default,) {final _that = this;
switch (_that) {
case _CartItem():
return $default(_that.productId,_that.name,_that.unitPrice,_that.costPrice,_that.quantity,_that.retailPrice,_that.wholesalePrice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? productId,  String name,  Money unitPrice,  Money costPrice,  int quantity,  Money? retailPrice,  Money? wholesalePrice)?  $default,) {final _that = this;
switch (_that) {
case _CartItem() when $default != null:
return $default(_that.productId,_that.name,_that.unitPrice,_that.costPrice,_that.quantity,_that.retailPrice,_that.wholesalePrice);case _:
  return null;

}
}

}

/// @nodoc


class _CartItem extends CartItem {
  const _CartItem({this.productId, required this.name, required this.unitPrice, required this.costPrice, required this.quantity, this.retailPrice, this.wholesalePrice}): super._();
  

@override final  String? productId;
@override final  String name;
@override final  Money unitPrice;
@override final  Money costPrice;
@override final  int quantity;
@override final  Money? retailPrice;
@override final  Money? wholesalePrice;

/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CartItemCopyWith<_CartItem> get copyWith => __$CartItemCopyWithImpl<_CartItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CartItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.retailPrice, retailPrice) || other.retailPrice == retailPrice)&&(identical(other.wholesalePrice, wholesalePrice) || other.wholesalePrice == wholesalePrice));
}


@override
int get hashCode {
    return Object.hash(runtimeType,productId,name,unitPrice,costPrice,quantity,retailPrice,wholesalePrice);
}

@override
String toString() {
    return 'CartItem(productId: $productId, name: $name, unitPrice: $unitPrice, costPrice: $costPrice, quantity: $quantity, retailPrice: $retailPrice, wholesalePrice: $wholesalePrice)';
}


}

/// @nodoc
abstract mixin class _$CartItemCopyWith<$Res> implements $CartItemCopyWith<$Res> {
  factory _$CartItemCopyWith(_CartItem value, $Res Function(_CartItem) _then) = __$CartItemCopyWithImpl;
@override @useResult
$Res call({
 String? productId, String name, Money unitPrice, Money costPrice, int quantity, Money? retailPrice, Money? wholesalePrice
});




}
/// @nodoc
class __$CartItemCopyWithImpl<$Res>
    implements _$CartItemCopyWith<$Res> {
  __$CartItemCopyWithImpl(this._self, this._then);

  final _CartItem _self;
  final $Res Function(_CartItem) _then;

/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = freezed,Object? name = null,Object? unitPrice = null,Object? costPrice = null,Object? quantity = null,Object? retailPrice = freezed,Object? wholesalePrice = freezed,}) {
  return _then(_CartItem(
productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as Money,costPrice: null == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as Money,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,retailPrice: freezed == retailPrice ? _self.retailPrice : retailPrice // ignore: cast_nullable_to_non_nullable
as Money?,wholesalePrice: freezed == wholesalePrice ? _self.wholesalePrice : wholesalePrice // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}


}

// dart format on
