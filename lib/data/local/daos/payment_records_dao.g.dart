// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_records_dao.dart';

// ignore_for_file: type=lint
mixin _$PaymentRecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $SalesTable get sales => attachedDatabase.sales;
  $PaymentRecordsTable get paymentRecords => attachedDatabase.paymentRecords;
  PaymentRecordsDaoManager get managers => PaymentRecordsDaoManager(this);
}

class PaymentRecordsDaoManager {
  final _$PaymentRecordsDaoMixin _db;
  PaymentRecordsDaoManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$PaymentRecordsTableTableManager get paymentRecords =>
      $$PaymentRecordsTableTableManager(
        _db.attachedDatabase,
        _db.paymentRecords,
      );
}
