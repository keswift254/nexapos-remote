// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Product {

 String get id; String get sku; String get name; String get categoryId; String? get imagePath; Money get retailPrice; Money get wholesalePrice; Money get costPrice; int get stockQty; int get reorderLevel; String get status;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.id, id) || other.id == id)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.retailPrice, retailPrice) || other.retailPrice == retailPrice)&&(identical(other.wholesalePrice, wholesalePrice) || other.wholesalePrice == wholesalePrice)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.stockQty, stockQty) || other.stockQty == stockQty)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,sku,name,categoryId,imagePath,retailPrice,wholesalePrice,costPrice,stockQty,reorderLevel,status);

@override
String toString() {
  return 'Product(id: $id, sku: $sku, name: $name, categoryId: $categoryId, imagePath: $imagePath, retailPrice: $retailPrice, wholesalePrice: $wholesalePrice, costPrice: $costPrice, stockQty: $stockQty, reorderLevel: $reorderLevel, status: $status)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
 String id, String sku, String name, String categoryId, String? imagePath, Money retailPrice, Money wholesalePrice, Money costPrice, int stockQty, int reorderLevel, String status
});




}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sku = null,Object? name = null,Object? categoryId = null,Object? imagePath = freezed,Object? retailPrice = null,Object? wholesalePrice = null,Object? costPrice = null,Object? stockQty = null,Object? reorderLevel = null,Object? status = null,}) {
  return _then(Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sku: null == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,retailPrice: null == retailPrice ? _self.retailPrice : retailPrice // ignore: cast_nullable_to_non_nullable
as Money,wholesalePrice: null == wholesalePrice ? _self.wholesalePrice : wholesalePrice // ignore: cast_nullable_to_non_nullable
as Money,costPrice: null == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as Money,stockQty: null == stockQty ? _self.stockQty : stockQty // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: null == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sku,  String name,  String categoryId,  String? imagePath,  Money retailPrice,  Money wholesalePrice,  Money costPrice,  int stockQty,  int reorderLevel,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.sku,_that.name,_that.categoryId,_that.imagePath,_that.retailPrice,_that.wholesalePrice,_that.costPrice,_that.stockQty,_that.reorderLevel,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sku,  String name,  String categoryId,  String? imagePath,  Money retailPrice,  Money wholesalePrice,  Money costPrice,  int stockQty,  int reorderLevel,  String status)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.id,_that.sku,_that.name,_that.categoryId,_that.imagePath,_that.retailPrice,_that.wholesalePrice,_that.costPrice,_that.stockQty,_that.reorderLevel,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sku,  String name,  String categoryId,  String? imagePath,  Money retailPrice,  Money wholesalePrice,  Money costPrice,  int stockQty,  int reorderLevel,  String status)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.sku,_that.name,_that.categoryId,_that.imagePath,_that.retailPrice,_that.wholesalePrice,_that.costPrice,_that.stockQty,_that.reorderLevel,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _Product extends Product {
  const _Product({required this.id, required this.sku, required this.name, required this.categoryId, this.imagePath, required this.retailPrice, required this.wholesalePrice, required this.costPrice, required this.stockQty, required this.reorderLevel, required this.status}): super._();
  

@override final  String id;
@override final  String sku;
@override final  String name;
@override final  String categoryId;
@override final  String? imagePath;
@override final  Money retailPrice;
@override final  Money wholesalePrice;
@override final  Money costPrice;
@override final  int stockQty;
@override final  int reorderLevel;
@override final  String status;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.id, id) || other.id == id)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.retailPrice, retailPrice) || other.retailPrice == retailPrice)&&(identical(other.wholesalePrice, wholesalePrice) || other.wholesalePrice == wholesalePrice)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.stockQty, stockQty) || other.stockQty == stockQty)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,sku,name,categoryId,imagePath,retailPrice,wholesalePrice,costPrice,stockQty,reorderLevel,status);

@override
String toString() {
  return 'Product(id: $id, sku: $sku, name: $name, categoryId: $categoryId, imagePath: $imagePath, retailPrice: $retailPrice, wholesalePrice: $wholesalePrice, costPrice: $costPrice, stockQty: $stockQty, reorderLevel: $reorderLevel, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
 String id, String sku, String name, String categoryId, String? imagePath, Money retailPrice, Money wholesalePrice, Money costPrice, int stockQty, int reorderLevel, String status
});




}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sku = null,Object? name = null,Object? categoryId = null,Object? imagePath = freezed,Object? retailPrice = null,Object? wholesalePrice = null,Object? costPrice = null,Object? stockQty = null,Object? reorderLevel = null,Object? status = null,}) {
  return _then(_Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sku: null == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,retailPrice: null == retailPrice ? _self.retailPrice : retailPrice // ignore: cast_nullable_to_non_nullable
as Money,wholesalePrice: null == wholesalePrice ? _self.wholesalePrice : wholesalePrice // ignore: cast_nullable_to_non_nullable
as Money,costPrice: null == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as Money,stockQty: null == stockQty ? _self.stockQty : stockQty // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: null == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
