import 'package:uuid/uuid.dart';

import '../local/tables/roles_table.dart';
import 'shop_archive.dart';

/// Adapter for the original PHP NexaPOS schema. Unknown business tables block
/// migration so a partial copy cannot be mistaken for a full transfer.
class LegacyPosMapper {
  final String source;
  final int utcOffsetHours;
  LegacyPosMapper(this.source, {this.utcOffsetHours = 3});
  String id(String table, Object value) =>
      const Uuid().v5(Namespace.url.value, '$source/$table/$value');

  static int money(Object? value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch('$value');
    if (match == null) {
      throw FormatException('Unsupported currency amount: $value');
    }
    final amount =
        int.parse(match[2]!) * 100 +
        int.parse((match[3] ?? '').padRight(2, '0'));
    return match[1] == '-' ? -amount : amount;
  }

  int integer(Object? value) {
    final result = int.tryParse('$value');
    if (result == null) throw FormatException('Unsupported quantity: $value');
    return result;
  }

  String timestamp(Object? value) {
    if (value == null) {
      throw const FormatException(
        'Source is missing a required transaction timestamp.',
      );
    }
    final text = value.toString().replaceFirst(' ', 'T');
    final hasZone =
        text.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(text);
    final parsed = DateTime.tryParse(hasZone ? text : '${text}Z');
    if (parsed == null) {
      throw FormatException('Invalid source timestamp: $value');
    }
    return (hasZone
            ? parsed.toUtc()
            : parsed.subtract(Duration(hours: utcOffsetHours)))
        .toIso8601String();
  }

  ShopArchive convert(Map<String, dynamic> raw) {
    final input = Map<String, dynamic>.from(raw['tables'] as Map);
    const supported = {
      'roles',
      'users',
      'categories',
      'products',
      'sales',
      'sale_items',
      'stock_movements',
      'expenses',
      'mpesa_payments',
      'paystack_payments',
      'business_settings',
    };
    for (final entry in input.entries) {
      if (!supported.contains(entry.key) && (entry.value as List).isNotEmpty) {
        throw FormatException(
          'Unsupported source table: ${entry.key}. Migration stopped without changing data.',
        );
      }
    }
    List<Map<String, dynamic>> rows(String t) => (input[t] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    for (final required in ['users', 'products', 'sales', 'sale_items']) {
      if (input[required] is! List) {
        throw FormatException(
          'This is not a supported NexaPOS database: missing $required.',
        );
      }
    }
    final output = {for (final t in archiveTables) t: <Map<String, dynamic>>[]};
    const epoch = '1970-01-01T00:00:00.000Z';
    Map<String, dynamic> base(
      String t,
      Map<String, dynamic> row, {
      String? createdAt,
    }) => {
      'id': id(t, row['id'] ?? (throw FormatException('Missing ID in $t.'))),
      'created_at':
          createdAt ??
          (row['created_at'] == null ? epoch : timestamp(row['created_at'])),
      'updated_at': row['updated_at'] == null
          ? (createdAt ??
                (row['created_at'] == null
                    ? epoch
                    : timestamp(row['created_at'])))
          : timestamp(row['updated_at']),
      'deleted_at': row['deleted_at'] == null
          ? null
          : timestamp(row['deleted_at']),
      'local_rev': 0,
      'created_by_device_id': 'legacy',
    };
    final roles = <Object?, String>{};
    for (final row in rows('roles')) {
      roles[row['id'].toString()] = switch (row['name']) {
        'admin' => RoleIds.admin,
        'manager' => RoleIds.manager,
        'cashier' => RoleIds.cashier,
        _ => throw FormatException('Unsupported source role: ${row['name']}'),
      };
    }
    for (final role in [
      ('admin', RoleIds.admin),
      ('manager', RoleIds.manager),
      ('cashier', RoleIds.cashier),
    ]) {
      output['roles']!.add({
        ...base('roles', {'id': role.$1}),
        'id': role.$2,
        'name': role.$1,
        'description': null,
      });
    }
    for (final row in rows('users')) {
      final role = roles[row['role_id'].toString()];
      if (role == null) {
        throw const FormatException('Source user has an unknown role.');
      }
      output['users']!.add({
        ...base('users', row),
        'role_id': role,
        'name': row['name'],
        'username': 'legacy_${id('users', row['id']!)}',
        'email': row['email'],
        'phone': row['phone'],
        'password_hash': '',
        'status': 'disabled',
      });
    }
    final categories = <String, String>{};
    void category(String name) {
      if (categories.containsKey(name)) return;
      final key = id('category-name', name);
      categories[name] = key;
      output['categories']!.add({
        ...base('categories', {'id': name}),
        'id': key,
        'name': name,
        'status': 'active',
      });
    }

    for (final row in rows('categories')) {
      category(row['name'] as String);
    }
    for (final row in rows('products')) {
      final name = (row['category'] as String?)?.trim();
      final categoryName = name == null || name.isEmpty
          ? 'Uncategorized'
          : name;
      category(categoryName);
      output['products']!.add({
        ...base('products', row),
        'sku': row['sku'],
        'name': row['name'],
        'category_id': categories[categoryName],
        'image_path': null,
        'retail_price_cents': money(row['retail_price']),
        'wholesale_price_cents': money(row['wholesale_price']),
        'cost_price_cents': money(row['cost_price']),
        'stock_qty': integer(row['stock_qty']),
        'reorder_level': integer(row['reorder_level'] ?? 0),
        'status': row['status'] ?? 'active',
      });
    }
    final saleTimes = <String, String>{};
    for (final row in rows('sales')) {
      final time = timestamp(row['created_at']);
      saleTimes[row['id'].toString()] = time;
      output['sales']!.add({
        ...base('sales', row, createdAt: time),
        'sale_number': row['sale_number'],
        'user_id': id('users', row['user_id']!),
        'customer_name': row['customer_name'],
        'customer_phone': row['customer_phone'],
        'sale_type': row['sale_type'],
        'payment_method': row['payment_method'],
        'subtotal_cents': money(row['subtotal']),
        'discount_cents': money(row['discount'] ?? 0),
        'total_cents': money(row['total']),
        'status': row['status'],
      });
    }
    for (final row in rows('sale_items')) {
      output['sale_items']!.add({
        ...base(
          'sale_items',
          row,
          createdAt: saleTimes[row['sale_id'].toString()],
        ),
        'sale_id': id('sales', row['sale_id']!),
        'product_id': row['product_id'] == null
            ? null
            : id('products', row['product_id']!),
        'item_name': row['item_name'],
        'quantity': integer(row['quantity']),
        'unit_price_cents': money(row['unit_price']),
        'cost_price_cents': money(row['cost_price']),
        'line_total_cents': money(row['line_total']),
      });
    }
    for (final row in rows('expenses')) {
      output['expenses']!.add({
        ...base('expenses', row),
        'user_id': row['user_id'] == null ? null : id('users', row['user_id']!),
        'expense_date': row['expense_date'],
        'title': row['title'],
        'amount_cents': money(row['amount']),
        'note': row['note'],
      });
    }
    for (final row in rows('stock_movements')) {
      output['stock_movements']!.add({
        ...base('stock_movements', row),
        'product_id': id('products', row['product_id']!),
        'user_id': row['user_id'] == null ? null : id('users', row['user_id']!),
        'movement_type': row['movement_type'],
        'quantity': integer(row['quantity']),
        'note': row['note'],
      });
    }
    // Older PHP product creation could omit opening movements. Preserve its
    // displayed stock with a separately identified migration adjustment.
    for (final product in output['products']!) {
      final recorded = output['stock_movements']!
          .where(
            (m) => m['product_id'] == product['id'] && m['deleted_at'] == null,
          )
          .fold<int>(0, (sum, m) => sum + (m['quantity'] as int));
      final difference = (product['stock_qty'] as int) - recorded;
      if (difference != 0) {
        output['stock_movements']!.add({
          ...base('opening-stock', {
            'id': product['id'],
          }, createdAt: product['created_at'] as String),
          'product_id': product['id'],
          'user_id': null,
          'movement_type': 'adjustment',
          'quantity': difference,
          'note': 'Legacy migration: reconcile source opening balance',
        });
      }
    }
    for (final table in ['mpesa_payments', 'paystack_payments']) {
      for (final row in rows(table)) {
        output['payment_records']!.add({
          ...base(table, row, createdAt: saleTimes[row['sale_id'].toString()]),
          'sale_id': id('sales', row['sale_id']!),
          'method': table == 'mpesa_payments' ? 'mpesa' : 'paystack',
          'amount_cents': money(row['amount']),
          'reference_note': row['mpesa_receipt_number'] ?? row['reference'],
          'status': row['status'] ?? 'pending',
        });
      }
    }
    if (rows('business_settings').isNotEmpty) {
      throw const FormatException(
        'This source has database-based business settings and needs an updated adapter.',
      );
    }
    return ShopArchive(
      output,
      source: source,
      notes: [
        'Reports are rebuilt from the imported sales, line items, costs and expenses.',
        'Historical staff remain disabled. Existing NexaPOS administrator access is preserved.',
        'Product images and gateway credentials are not migrated from the PHP installation.',
        'Legacy timestamps use UTC${utcOffsetHours >= 0 ? '+' : ''}$utcOffsetHours.',
        'Opening-stock adjustments preserve the source inventory balance.',
      ],
    );
  }
}
