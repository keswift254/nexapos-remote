// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RolesTable extends Roles with TableInfo<$RolesTable, Role> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    name,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Role> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Role map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Role(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $RolesTable createAlias(String alias) {
    return $RolesTable(attachedDatabase, alias);
  }
}

class Role extends DataClass implements Insertable<Role> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String name;
  final String? description;
  const Role({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.name,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory Role.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Role(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
    };
  }

  Role copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? name,
    Value<String?> description = const Value.absent(),
  }) => Role(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
  );
  Role copyWithCompanion(RolesCompanion data) {
    return Role(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Role(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    name,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.name == this.name &&
          other.description == this.description);
}

class RolesCompanion extends UpdateCompanion<Role> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> rowid;
  const RolesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RolesCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       name = Value(name);
  static Insertable<Role> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RolesCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? rowid,
  }) {
    return RolesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      name: name ?? this.name,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    roleId,
    name,
    username,
    email,
    passwordHash,
    phone,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String roleId;
  final String name;
  final String username;
  final String? email;
  final String passwordHash;
  final String? phone;
  final String status;
  const User({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.roleId,
    required this.name,
    required this.username,
    this.email,
    required this.passwordHash,
    this.phone,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['role_id'] = Variable<String>(roleId);
    map['name'] = Variable<String>(name);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['password_hash'] = Variable<String>(passwordHash);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      roleId: Value(roleId),
      name: Value(name),
      username: Value(username),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      passwordHash: Value(passwordHash),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      status: Value(status),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      roleId: serializer.fromJson<String>(json['roleId']),
      name: serializer.fromJson<String>(json['name']),
      username: serializer.fromJson<String>(json['username']),
      email: serializer.fromJson<String?>(json['email']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      phone: serializer.fromJson<String?>(json['phone']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'roleId': serializer.toJson<String>(roleId),
      'name': serializer.toJson<String>(name),
      'username': serializer.toJson<String>(username),
      'email': serializer.toJson<String?>(email),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'phone': serializer.toJson<String?>(phone),
      'status': serializer.toJson<String>(status),
    };
  }

  User copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? roleId,
    String? name,
    String? username,
    Value<String?> email = const Value.absent(),
    String? passwordHash,
    Value<String?> phone = const Value.absent(),
    String? status,
  }) => User(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    roleId: roleId ?? this.roleId,
    name: name ?? this.name,
    username: username ?? this.username,
    email: email.present ? email.value : this.email,
    passwordHash: passwordHash ?? this.passwordHash,
    phone: phone.present ? phone.value : this.phone,
    status: status ?? this.status,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      name: data.name.present ? data.name.value : this.name,
      username: data.username.present ? data.username.value : this.username,
      email: data.email.present ? data.email.value : this.email,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      phone: data.phone.present ? data.phone.value : this.phone,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('username: $username, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('phone: $phone, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    roleId,
    name,
    username,
    email,
    passwordHash,
    phone,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.roleId == this.roleId &&
          other.name == this.name &&
          other.username == this.username &&
          other.email == this.email &&
          other.passwordHash == this.passwordHash &&
          other.phone == this.phone &&
          other.status == this.status);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> roleId;
  final Value<String> name;
  final Value<String> username;
  final Value<String?> email;
  final Value<String> passwordHash;
  final Value<String?> phone;
  final Value<String> status;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.roleId = const Value.absent(),
    this.name = const Value.absent(),
    this.username = const Value.absent(),
    this.email = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.phone = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String roleId,
    required String name,
    required String username,
    this.email = const Value.absent(),
    required String passwordHash,
    this.phone = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       roleId = Value(roleId),
       name = Value(name),
       username = Value(username),
       passwordHash = Value(passwordHash);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? roleId,
    Expression<String>? name,
    Expression<String>? username,
    Expression<String>? email,
    Expression<String>? passwordHash,
    Expression<String>? phone,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (roleId != null) 'role_id': roleId,
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (phone != null) 'phone': phone,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? roleId,
    Value<String>? name,
    Value<String>? username,
    Value<String?>? email,
    Value<String>? passwordHash,
    Value<String?>? phone,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      roleId: roleId ?? this.roleId,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('username: $username, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('phone: $phone, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    name,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String name;
  final String status;
  const Category({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.name,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      name: Value(name),
      status: Value(status),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
    };
  }

  Category copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? name,
    String? status,
  }) => Category(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    name: name ?? this.name,
    status: status ?? this.status,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('name: $name, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    name,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.name == this.name &&
          other.status == this.status);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> name;
  final Value<String> status;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? name,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      name: name ?? this.name,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retailPriceCentsMeta = const VerificationMeta(
    'retailPriceCents',
  );
  @override
  late final GeneratedColumn<int> retailPriceCents = GeneratedColumn<int>(
    'retail_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wholesalePriceCentsMeta =
      const VerificationMeta('wholesalePriceCents');
  @override
  late final GeneratedColumn<int> wholesalePriceCents = GeneratedColumn<int>(
    'wholesale_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costPriceCentsMeta = const VerificationMeta(
    'costPriceCents',
  );
  @override
  late final GeneratedColumn<int> costPriceCents = GeneratedColumn<int>(
    'cost_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockQtyMeta = const VerificationMeta(
    'stockQty',
  );
  @override
  late final GeneratedColumn<int> stockQty = GeneratedColumn<int>(
    'stock_qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reorderLevelMeta = const VerificationMeta(
    'reorderLevel',
  );
  @override
  late final GeneratedColumn<int> reorderLevel = GeneratedColumn<int>(
    'reorder_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    sku,
    name,
    categoryId,
    imagePath,
    retailPriceCents,
    wholesalePriceCents,
    costPriceCents,
    stockQty,
    reorderLevel,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    } else if (isInserting) {
      context.missing(_skuMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('retail_price_cents')) {
      context.handle(
        _retailPriceCentsMeta,
        retailPriceCents.isAcceptableOrUnknown(
          data['retail_price_cents']!,
          _retailPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retailPriceCentsMeta);
    }
    if (data.containsKey('wholesale_price_cents')) {
      context.handle(
        _wholesalePriceCentsMeta,
        wholesalePriceCents.isAcceptableOrUnknown(
          data['wholesale_price_cents']!,
          _wholesalePriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wholesalePriceCentsMeta);
    }
    if (data.containsKey('cost_price_cents')) {
      context.handle(
        _costPriceCentsMeta,
        costPriceCents.isAcceptableOrUnknown(
          data['cost_price_cents']!,
          _costPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_costPriceCentsMeta);
    }
    if (data.containsKey('stock_qty')) {
      context.handle(
        _stockQtyMeta,
        stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta),
      );
    }
    if (data.containsKey('reorder_level')) {
      context.handle(
        _reorderLevelMeta,
        reorderLevel.isAcceptableOrUnknown(
          data['reorder_level']!,
          _reorderLevelMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      retailPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retail_price_cents'],
      )!,
      wholesalePriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wholesale_price_cents'],
      )!,
      costPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_price_cents'],
      )!,
      stockQty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_qty'],
      )!,
      reorderLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reorder_level'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String sku;
  final String name;
  final String categoryId;
  final String? imagePath;
  final int retailPriceCents;
  final int wholesalePriceCents;
  final int costPriceCents;
  final int stockQty;
  final int reorderLevel;
  final String status;
  const Product({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.sku,
    required this.name,
    required this.categoryId,
    this.imagePath,
    required this.retailPriceCents,
    required this.wholesalePriceCents,
    required this.costPriceCents,
    required this.stockQty,
    required this.reorderLevel,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['sku'] = Variable<String>(sku);
    map['name'] = Variable<String>(name);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['retail_price_cents'] = Variable<int>(retailPriceCents);
    map['wholesale_price_cents'] = Variable<int>(wholesalePriceCents);
    map['cost_price_cents'] = Variable<int>(costPriceCents);
    map['stock_qty'] = Variable<int>(stockQty);
    map['reorder_level'] = Variable<int>(reorderLevel);
    map['status'] = Variable<String>(status);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      sku: Value(sku),
      name: Value(name),
      categoryId: Value(categoryId),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      retailPriceCents: Value(retailPriceCents),
      wholesalePriceCents: Value(wholesalePriceCents),
      costPriceCents: Value(costPriceCents),
      stockQty: Value(stockQty),
      reorderLevel: Value(reorderLevel),
      status: Value(status),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      sku: serializer.fromJson<String>(json['sku']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      retailPriceCents: serializer.fromJson<int>(json['retailPriceCents']),
      wholesalePriceCents: serializer.fromJson<int>(
        json['wholesalePriceCents'],
      ),
      costPriceCents: serializer.fromJson<int>(json['costPriceCents']),
      stockQty: serializer.fromJson<int>(json['stockQty']),
      reorderLevel: serializer.fromJson<int>(json['reorderLevel']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'sku': serializer.toJson<String>(sku),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String>(categoryId),
      'imagePath': serializer.toJson<String?>(imagePath),
      'retailPriceCents': serializer.toJson<int>(retailPriceCents),
      'wholesalePriceCents': serializer.toJson<int>(wholesalePriceCents),
      'costPriceCents': serializer.toJson<int>(costPriceCents),
      'stockQty': serializer.toJson<int>(stockQty),
      'reorderLevel': serializer.toJson<int>(reorderLevel),
      'status': serializer.toJson<String>(status),
    };
  }

  Product copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? sku,
    String? name,
    String? categoryId,
    Value<String?> imagePath = const Value.absent(),
    int? retailPriceCents,
    int? wholesalePriceCents,
    int? costPriceCents,
    int? stockQty,
    int? reorderLevel,
    String? status,
  }) => Product(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    sku: sku ?? this.sku,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    retailPriceCents: retailPriceCents ?? this.retailPriceCents,
    wholesalePriceCents: wholesalePriceCents ?? this.wholesalePriceCents,
    costPriceCents: costPriceCents ?? this.costPriceCents,
    stockQty: stockQty ?? this.stockQty,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    status: status ?? this.status,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      sku: data.sku.present ? data.sku.value : this.sku,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      retailPriceCents: data.retailPriceCents.present
          ? data.retailPriceCents.value
          : this.retailPriceCents,
      wholesalePriceCents: data.wholesalePriceCents.present
          ? data.wholesalePriceCents.value
          : this.wholesalePriceCents,
      costPriceCents: data.costPriceCents.present
          ? data.costPriceCents.value
          : this.costPriceCents,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      reorderLevel: data.reorderLevel.present
          ? data.reorderLevel.value
          : this.reorderLevel,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('imagePath: $imagePath, ')
          ..write('retailPriceCents: $retailPriceCents, ')
          ..write('wholesalePriceCents: $wholesalePriceCents, ')
          ..write('costPriceCents: $costPriceCents, ')
          ..write('stockQty: $stockQty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    sku,
    name,
    categoryId,
    imagePath,
    retailPriceCents,
    wholesalePriceCents,
    costPriceCents,
    stockQty,
    reorderLevel,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.sku == this.sku &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.imagePath == this.imagePath &&
          other.retailPriceCents == this.retailPriceCents &&
          other.wholesalePriceCents == this.wholesalePriceCents &&
          other.costPriceCents == this.costPriceCents &&
          other.stockQty == this.stockQty &&
          other.reorderLevel == this.reorderLevel &&
          other.status == this.status);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> sku;
  final Value<String> name;
  final Value<String> categoryId;
  final Value<String?> imagePath;
  final Value<int> retailPriceCents;
  final Value<int> wholesalePriceCents;
  final Value<int> costPriceCents;
  final Value<int> stockQty;
  final Value<int> reorderLevel;
  final Value<String> status;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.sku = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.retailPriceCents = const Value.absent(),
    this.wholesalePriceCents = const Value.absent(),
    this.costPriceCents = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String sku,
    required String name,
    required String categoryId,
    this.imagePath = const Value.absent(),
    required int retailPriceCents,
    required int wholesalePriceCents,
    required int costPriceCents,
    this.stockQty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       sku = Value(sku),
       name = Value(name),
       categoryId = Value(categoryId),
       retailPriceCents = Value(retailPriceCents),
       wholesalePriceCents = Value(wholesalePriceCents),
       costPriceCents = Value(costPriceCents);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? sku,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? imagePath,
    Expression<int>? retailPriceCents,
    Expression<int>? wholesalePriceCents,
    Expression<int>? costPriceCents,
    Expression<int>? stockQty,
    Expression<int>? reorderLevel,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (sku != null) 'sku': sku,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (imagePath != null) 'image_path': imagePath,
      if (retailPriceCents != null) 'retail_price_cents': retailPriceCents,
      if (wholesalePriceCents != null)
        'wholesale_price_cents': wholesalePriceCents,
      if (costPriceCents != null) 'cost_price_cents': costPriceCents,
      if (stockQty != null) 'stock_qty': stockQty,
      if (reorderLevel != null) 'reorder_level': reorderLevel,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? sku,
    Value<String>? name,
    Value<String>? categoryId,
    Value<String?>? imagePath,
    Value<int>? retailPriceCents,
    Value<int>? wholesalePriceCents,
    Value<int>? costPriceCents,
    Value<int>? stockQty,
    Value<int>? reorderLevel,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      imagePath: imagePath ?? this.imagePath,
      retailPriceCents: retailPriceCents ?? this.retailPriceCents,
      wholesalePriceCents: wholesalePriceCents ?? this.wholesalePriceCents,
      costPriceCents: costPriceCents ?? this.costPriceCents,
      stockQty: stockQty ?? this.stockQty,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (retailPriceCents.present) {
      map['retail_price_cents'] = Variable<int>(retailPriceCents.value);
    }
    if (wholesalePriceCents.present) {
      map['wholesale_price_cents'] = Variable<int>(wholesalePriceCents.value);
    }
    if (costPriceCents.present) {
      map['cost_price_cents'] = Variable<int>(costPriceCents.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<int>(stockQty.value);
    }
    if (reorderLevel.present) {
      map['reorder_level'] = Variable<int>(reorderLevel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('imagePath: $imagePath, ')
          ..write('retailPriceCents: $retailPriceCents, ')
          ..write('wholesalePriceCents: $wholesalePriceCents, ')
          ..write('costPriceCents: $costPriceCents, ')
          ..write('stockQty: $stockQty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _saleNumberMeta = const VerificationMeta(
    'saleNumber',
  );
  @override
  late final GeneratedColumn<String> saleNumber = GeneratedColumn<String>(
    'sale_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saleTypeMeta = const VerificationMeta(
    'saleType',
  );
  @override
  late final GeneratedColumn<String> saleType = GeneratedColumn<String>(
    'sale_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalCentsMeta = const VerificationMeta(
    'subtotalCents',
  );
  @override
  late final GeneratedColumn<int> subtotalCents = GeneratedColumn<int>(
    'subtotal_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountCentsMeta = const VerificationMeta(
    'discountCents',
  );
  @override
  late final GeneratedColumn<int> discountCents = GeneratedColumn<int>(
    'discount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalCentsMeta = const VerificationMeta(
    'totalCents',
  );
  @override
  late final GeneratedColumn<int> totalCents = GeneratedColumn<int>(
    'total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleNumber,
    userId,
    customerName,
    customerPhone,
    saleType,
    paymentMethod,
    subtotalCents,
    discountCents,
    totalCents,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('sale_number')) {
      context.handle(
        _saleNumberMeta,
        saleNumber.isAcceptableOrUnknown(data['sale_number']!, _saleNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_saleNumberMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('sale_type')) {
      context.handle(
        _saleTypeMeta,
        saleType.isAcceptableOrUnknown(data['sale_type']!, _saleTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_saleTypeMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('subtotal_cents')) {
      context.handle(
        _subtotalCentsMeta,
        subtotalCents.isAcceptableOrUnknown(
          data['subtotal_cents']!,
          _subtotalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subtotalCentsMeta);
    }
    if (data.containsKey('discount_cents')) {
      context.handle(
        _discountCentsMeta,
        discountCents.isAcceptableOrUnknown(
          data['discount_cents']!,
          _discountCentsMeta,
        ),
      );
    }
    if (data.containsKey('total_cents')) {
      context.handle(
        _totalCentsMeta,
        totalCents.isAcceptableOrUnknown(data['total_cents']!, _totalCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCentsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      saleNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_number'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      saleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_type'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      subtotalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal_cents'],
      )!,
      discountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_cents'],
      )!,
      totalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cents'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String saleNumber;
  final String userId;
  final String? customerName;
  final String? customerPhone;
  final String saleType;
  final String paymentMethod;
  final int subtotalCents;
  final int discountCents;
  final int totalCents;
  final String status;
  const Sale({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.saleNumber,
    required this.userId,
    this.customerName,
    this.customerPhone,
    required this.saleType,
    required this.paymentMethod,
    required this.subtotalCents,
    required this.discountCents,
    required this.totalCents,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['sale_number'] = Variable<String>(saleNumber);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['sale_type'] = Variable<String>(saleType);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['subtotal_cents'] = Variable<int>(subtotalCents);
    map['discount_cents'] = Variable<int>(discountCents);
    map['total_cents'] = Variable<int>(totalCents);
    map['status'] = Variable<String>(status);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      saleNumber: Value(saleNumber),
      userId: Value(userId),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      saleType: Value(saleType),
      paymentMethod: Value(paymentMethod),
      subtotalCents: Value(subtotalCents),
      discountCents: Value(discountCents),
      totalCents: Value(totalCents),
      status: Value(status),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      saleNumber: serializer.fromJson<String>(json['saleNumber']),
      userId: serializer.fromJson<String>(json['userId']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      saleType: serializer.fromJson<String>(json['saleType']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      subtotalCents: serializer.fromJson<int>(json['subtotalCents']),
      discountCents: serializer.fromJson<int>(json['discountCents']),
      totalCents: serializer.fromJson<int>(json['totalCents']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'saleNumber': serializer.toJson<String>(saleNumber),
      'userId': serializer.toJson<String>(userId),
      'customerName': serializer.toJson<String?>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'saleType': serializer.toJson<String>(saleType),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'subtotalCents': serializer.toJson<int>(subtotalCents),
      'discountCents': serializer.toJson<int>(discountCents),
      'totalCents': serializer.toJson<int>(totalCents),
      'status': serializer.toJson<String>(status),
    };
  }

  Sale copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? saleNumber,
    String? userId,
    Value<String?> customerName = const Value.absent(),
    Value<String?> customerPhone = const Value.absent(),
    String? saleType,
    String? paymentMethod,
    int? subtotalCents,
    int? discountCents,
    int? totalCents,
    String? status,
  }) => Sale(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    saleNumber: saleNumber ?? this.saleNumber,
    userId: userId ?? this.userId,
    customerName: customerName.present ? customerName.value : this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    saleType: saleType ?? this.saleType,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    subtotalCents: subtotalCents ?? this.subtotalCents,
    discountCents: discountCents ?? this.discountCents,
    totalCents: totalCents ?? this.totalCents,
    status: status ?? this.status,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      saleNumber: data.saleNumber.present
          ? data.saleNumber.value
          : this.saleNumber,
      userId: data.userId.present ? data.userId.value : this.userId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      saleType: data.saleType.present ? data.saleType.value : this.saleType,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      subtotalCents: data.subtotalCents.present
          ? data.subtotalCents.value
          : this.subtotalCents,
      discountCents: data.discountCents.present
          ? data.discountCents.value
          : this.discountCents,
      totalCents: data.totalCents.present
          ? data.totalCents.value
          : this.totalCents,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('userId: $userId, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('saleType: $saleType, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('discountCents: $discountCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleNumber,
    userId,
    customerName,
    customerPhone,
    saleType,
    paymentMethod,
    subtotalCents,
    discountCents,
    totalCents,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.saleNumber == this.saleNumber &&
          other.userId == this.userId &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.saleType == this.saleType &&
          other.paymentMethod == this.paymentMethod &&
          other.subtotalCents == this.subtotalCents &&
          other.discountCents == this.discountCents &&
          other.totalCents == this.totalCents &&
          other.status == this.status);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> saleNumber;
  final Value<String> userId;
  final Value<String?> customerName;
  final Value<String?> customerPhone;
  final Value<String> saleType;
  final Value<String> paymentMethod;
  final Value<int> subtotalCents;
  final Value<int> discountCents;
  final Value<int> totalCents;
  final Value<String> status;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.saleNumber = const Value.absent(),
    this.userId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.saleType = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.subtotalCents = const Value.absent(),
    this.discountCents = const Value.absent(),
    this.totalCents = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String saleNumber,
    required String userId,
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    required String saleType,
    required String paymentMethod,
    required int subtotalCents,
    this.discountCents = const Value.absent(),
    required int totalCents,
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       saleNumber = Value(saleNumber),
       userId = Value(userId),
       saleType = Value(saleType),
       paymentMethod = Value(paymentMethod),
       subtotalCents = Value(subtotalCents),
       totalCents = Value(totalCents),
       status = Value(status);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? saleNumber,
    Expression<String>? userId,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? saleType,
    Expression<String>? paymentMethod,
    Expression<int>? subtotalCents,
    Expression<int>? discountCents,
    Expression<int>? totalCents,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (saleNumber != null) 'sale_number': saleNumber,
      if (userId != null) 'user_id': userId,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (saleType != null) 'sale_type': saleType,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (subtotalCents != null) 'subtotal_cents': subtotalCents,
      if (discountCents != null) 'discount_cents': discountCents,
      if (totalCents != null) 'total_cents': totalCents,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? saleNumber,
    Value<String>? userId,
    Value<String?>? customerName,
    Value<String?>? customerPhone,
    Value<String>? saleType,
    Value<String>? paymentMethod,
    Value<int>? subtotalCents,
    Value<int>? discountCents,
    Value<int>? totalCents,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      saleNumber: saleNumber ?? this.saleNumber,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      saleType: saleType ?? this.saleType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      discountCents: discountCents ?? this.discountCents,
      totalCents: totalCents ?? this.totalCents,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (saleNumber.present) {
      map['sale_number'] = Variable<String>(saleNumber.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (saleType.present) {
      map['sale_type'] = Variable<String>(saleType.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (subtotalCents.present) {
      map['subtotal_cents'] = Variable<int>(subtotalCents.value);
    }
    if (discountCents.present) {
      map['discount_cents'] = Variable<int>(discountCents.value);
    }
    if (totalCents.present) {
      map['total_cents'] = Variable<int>(totalCents.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('userId: $userId, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('saleType: $saleType, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('discountCents: $discountCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SaleItemsTable extends SaleItems
    with TableInfo<$SaleItemsTable, SaleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id)',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _itemNameMeta = const VerificationMeta(
    'itemName',
  );
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
    'item_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceCentsMeta = const VerificationMeta(
    'unitPriceCents',
  );
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
    'unit_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costPriceCentsMeta = const VerificationMeta(
    'costPriceCents',
  );
  @override
  late final GeneratedColumn<int> costPriceCents = GeneratedColumn<int>(
    'cost_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineTotalCentsMeta = const VerificationMeta(
    'lineTotalCents',
  );
  @override
  late final GeneratedColumn<int> lineTotalCents = GeneratedColumn<int>(
    'line_total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleId,
    productId,
    itemName,
    quantity,
    unitPriceCents,
    costPriceCents,
    lineTotalCents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SaleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('item_name')) {
      context.handle(
        _itemNameMeta,
        itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta),
      );
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
        _unitPriceCentsMeta,
        unitPriceCents.isAcceptableOrUnknown(
          data['unit_price_cents']!,
          _unitPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceCentsMeta);
    }
    if (data.containsKey('cost_price_cents')) {
      context.handle(
        _costPriceCentsMeta,
        costPriceCents.isAcceptableOrUnknown(
          data['cost_price_cents']!,
          _costPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_costPriceCentsMeta);
    }
    if (data.containsKey('line_total_cents')) {
      context.handle(
        _lineTotalCentsMeta,
        lineTotalCents.isAcceptableOrUnknown(
          data['line_total_cents']!,
          _lineTotalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lineTotalCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      itemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unitPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_cents'],
      )!,
      costPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_price_cents'],
      )!,
      lineTotalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_total_cents'],
      )!,
    );
  }

  @override
  $SaleItemsTable createAlias(String alias) {
    return $SaleItemsTable(attachedDatabase, alias);
  }
}

class SaleItem extends DataClass implements Insertable<SaleItem> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String saleId;
  final String? productId;
  final String itemName;
  final int quantity;
  final int unitPriceCents;
  final int costPriceCents;
  final int lineTotalCents;
  const SaleItem({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.saleId,
    this.productId,
    required this.itemName,
    required this.quantity,
    required this.unitPriceCents,
    required this.costPriceCents,
    required this.lineTotalCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['sale_id'] = Variable<String>(saleId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['item_name'] = Variable<String>(itemName);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price_cents'] = Variable<int>(unitPriceCents);
    map['cost_price_cents'] = Variable<int>(costPriceCents);
    map['line_total_cents'] = Variable<int>(lineTotalCents);
    return map;
  }

  SaleItemsCompanion toCompanion(bool nullToAbsent) {
    return SaleItemsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      saleId: Value(saleId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      itemName: Value(itemName),
      quantity: Value(quantity),
      unitPriceCents: Value(unitPriceCents),
      costPriceCents: Value(costPriceCents),
      lineTotalCents: Value(lineTotalCents),
    );
  }

  factory SaleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleItem(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      saleId: serializer.fromJson<String>(json['saleId']),
      productId: serializer.fromJson<String?>(json['productId']),
      itemName: serializer.fromJson<String>(json['itemName']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPriceCents: serializer.fromJson<int>(json['unitPriceCents']),
      costPriceCents: serializer.fromJson<int>(json['costPriceCents']),
      lineTotalCents: serializer.fromJson<int>(json['lineTotalCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'saleId': serializer.toJson<String>(saleId),
      'productId': serializer.toJson<String?>(productId),
      'itemName': serializer.toJson<String>(itemName),
      'quantity': serializer.toJson<int>(quantity),
      'unitPriceCents': serializer.toJson<int>(unitPriceCents),
      'costPriceCents': serializer.toJson<int>(costPriceCents),
      'lineTotalCents': serializer.toJson<int>(lineTotalCents),
    };
  }

  SaleItem copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? saleId,
    Value<String?> productId = const Value.absent(),
    String? itemName,
    int? quantity,
    int? unitPriceCents,
    int? costPriceCents,
    int? lineTotalCents,
  }) => SaleItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    saleId: saleId ?? this.saleId,
    productId: productId.present ? productId.value : this.productId,
    itemName: itemName ?? this.itemName,
    quantity: quantity ?? this.quantity,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    costPriceCents: costPriceCents ?? this.costPriceCents,
    lineTotalCents: lineTotalCents ?? this.lineTotalCents,
  );
  SaleItem copyWithCompanion(SaleItemsCompanion data) {
    return SaleItem(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
      costPriceCents: data.costPriceCents.present
          ? data.costPriceCents.value
          : this.costPriceCents,
      lineTotalCents: data.lineTotalCents.present
          ? data.lineTotalCents.value
          : this.lineTotalCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleItem(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('itemName: $itemName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('costPriceCents: $costPriceCents, ')
          ..write('lineTotalCents: $lineTotalCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleId,
    productId,
    itemName,
    quantity,
    unitPriceCents,
    costPriceCents,
    lineTotalCents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleItem &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.saleId == this.saleId &&
          other.productId == this.productId &&
          other.itemName == this.itemName &&
          other.quantity == this.quantity &&
          other.unitPriceCents == this.unitPriceCents &&
          other.costPriceCents == this.costPriceCents &&
          other.lineTotalCents == this.lineTotalCents);
}

class SaleItemsCompanion extends UpdateCompanion<SaleItem> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> saleId;
  final Value<String?> productId;
  final Value<String> itemName;
  final Value<int> quantity;
  final Value<int> unitPriceCents;
  final Value<int> costPriceCents;
  final Value<int> lineTotalCents;
  final Value<int> rowid;
  const SaleItemsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.saleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.itemName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.costPriceCents = const Value.absent(),
    this.lineTotalCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleItemsCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String saleId,
    this.productId = const Value.absent(),
    required String itemName,
    required int quantity,
    required int unitPriceCents,
    required int costPriceCents,
    required int lineTotalCents,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       saleId = Value(saleId),
       itemName = Value(itemName),
       quantity = Value(quantity),
       unitPriceCents = Value(unitPriceCents),
       costPriceCents = Value(costPriceCents),
       lineTotalCents = Value(lineTotalCents);
  static Insertable<SaleItem> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? saleId,
    Expression<String>? productId,
    Expression<String>? itemName,
    Expression<int>? quantity,
    Expression<int>? unitPriceCents,
    Expression<int>? costPriceCents,
    Expression<int>? lineTotalCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (saleId != null) 'sale_id': saleId,
      if (productId != null) 'product_id': productId,
      if (itemName != null) 'item_name': itemName,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (costPriceCents != null) 'cost_price_cents': costPriceCents,
      if (lineTotalCents != null) 'line_total_cents': lineTotalCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? saleId,
    Value<String?>? productId,
    Value<String>? itemName,
    Value<int>? quantity,
    Value<int>? unitPriceCents,
    Value<int>? costPriceCents,
    Value<int>? lineTotalCents,
    Value<int>? rowid,
  }) {
    return SaleItemsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      costPriceCents: costPriceCents ?? this.costPriceCents,
      lineTotalCents: lineTotalCents ?? this.lineTotalCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    if (costPriceCents.present) {
      map['cost_price_cents'] = Variable<int>(costPriceCents.value);
    }
    if (lineTotalCents.present) {
      map['line_total_cents'] = Variable<int>(lineTotalCents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('itemName: $itemName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('costPriceCents: $costPriceCents, ')
          ..write('lineTotalCents: $lineTotalCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _expenseDateMeta = const VerificationMeta(
    'expenseDate',
  );
  @override
  late final GeneratedColumn<String> expenseDate = GeneratedColumn<String>(
    'expense_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    userId,
    expenseDate,
    title,
    amountCents,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('expense_date')) {
      context.handle(
        _expenseDateMeta,
        expenseDate.isAcceptableOrUnknown(
          data['expense_date']!,
          _expenseDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expenseDateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      expenseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class Expense extends DataClass implements Insertable<Expense> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String? userId;
  final String expenseDate;
  final String title;
  final int amountCents;
  final String? note;
  const Expense({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    this.userId,
    required this.expenseDate,
    required this.title,
    required this.amountCents,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['expense_date'] = Variable<String>(expenseDate);
    map['title'] = Variable<String>(title);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      expenseDate: Value(expenseDate),
      title: Value(title),
      amountCents: Value(amountCents),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      userId: serializer.fromJson<String?>(json['userId']),
      expenseDate: serializer.fromJson<String>(json['expenseDate']),
      title: serializer.fromJson<String>(json['title']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'userId': serializer.toJson<String?>(userId),
      'expenseDate': serializer.toJson<String>(expenseDate),
      'title': serializer.toJson<String>(title),
      'amountCents': serializer.toJson<int>(amountCents),
      'note': serializer.toJson<String?>(note),
    };
  }

  Expense copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    Value<String?> userId = const Value.absent(),
    String? expenseDate,
    String? title,
    int? amountCents,
    Value<String?> note = const Value.absent(),
  }) => Expense(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    userId: userId.present ? userId.value : this.userId,
    expenseDate: expenseDate ?? this.expenseDate,
    title: title ?? this.title,
    amountCents: amountCents ?? this.amountCents,
    note: note.present ? note.value : this.note,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      userId: data.userId.present ? data.userId.value : this.userId,
      expenseDate: data.expenseDate.present
          ? data.expenseDate.value
          : this.expenseDate,
      title: data.title.present ? data.title.value : this.title,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('userId: $userId, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('title: $title, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    userId,
    expenseDate,
    title,
    amountCents,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.userId == this.userId &&
          other.expenseDate == this.expenseDate &&
          other.title == this.title &&
          other.amountCents == this.amountCents &&
          other.note == this.note);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String?> userId;
  final Value<String> expenseDate;
  final Value<String> title;
  final Value<int> amountCents;
  final Value<String?> note;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.userId = const Value.absent(),
    this.expenseDate = const Value.absent(),
    this.title = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    this.userId = const Value.absent(),
    required String expenseDate,
    required String title,
    required int amountCents,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       expenseDate = Value(expenseDate),
       title = Value(title),
       amountCents = Value(amountCents);
  static Insertable<Expense> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? userId,
    Expression<String>? expenseDate,
    Expression<String>? title,
    Expression<int>? amountCents,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (userId != null) 'user_id': userId,
      if (expenseDate != null) 'expense_date': expenseDate,
      if (title != null) 'title': title,
      if (amountCents != null) 'amount_cents': amountCents,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String?>? userId,
    Value<String>? expenseDate,
    Value<String>? title,
    Value<int>? amountCents,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      userId: userId ?? this.userId,
      expenseDate: expenseDate ?? this.expenseDate,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (expenseDate.present) {
      map['expense_date'] = Variable<String>(expenseDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('userId: $userId, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('title: $title, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _movementTypeMeta = const VerificationMeta(
    'movementType',
  );
  @override
  late final GeneratedColumn<String> movementType = GeneratedColumn<String>(
    'movement_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    productId,
    userId,
    movementType,
    quantity,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('movement_type')) {
      context.handle(
        _movementTypeMeta,
        movementType.isAcceptableOrUnknown(
          data['movement_type']!,
          _movementTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_movementTypeMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      movementType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement_type'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }
}

class StockMovement extends DataClass implements Insertable<StockMovement> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String productId;
  final String? userId;
  final String movementType;
  final int quantity;
  final String? note;
  const StockMovement({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.productId,
    this.userId,
    required this.movementType,
    required this.quantity,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['product_id'] = Variable<String>(productId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['movement_type'] = Variable<String>(movementType);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      productId: Value(productId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      movementType: Value(movementType),
      quantity: Value(quantity),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory StockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovement(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      productId: serializer.fromJson<String>(json['productId']),
      userId: serializer.fromJson<String?>(json['userId']),
      movementType: serializer.fromJson<String>(json['movementType']),
      quantity: serializer.fromJson<int>(json['quantity']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'productId': serializer.toJson<String>(productId),
      'userId': serializer.toJson<String?>(userId),
      'movementType': serializer.toJson<String>(movementType),
      'quantity': serializer.toJson<int>(quantity),
      'note': serializer.toJson<String?>(note),
    };
  }

  StockMovement copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? productId,
    Value<String?> userId = const Value.absent(),
    String? movementType,
    int? quantity,
    Value<String?> note = const Value.absent(),
  }) => StockMovement(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    productId: productId ?? this.productId,
    userId: userId.present ? userId.value : this.userId,
    movementType: movementType ?? this.movementType,
    quantity: quantity ?? this.quantity,
    note: note.present ? note.value : this.note,
  );
  StockMovement copyWithCompanion(StockMovementsCompanion data) {
    return StockMovement(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      productId: data.productId.present ? data.productId.value : this.productId,
      userId: data.userId.present ? data.userId.value : this.userId,
      movementType: data.movementType.present
          ? data.movementType.value
          : this.movementType,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovement(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('productId: $productId, ')
          ..write('userId: $userId, ')
          ..write('movementType: $movementType, ')
          ..write('quantity: $quantity, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    productId,
    userId,
    movementType,
    quantity,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovement &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.productId == this.productId &&
          other.userId == this.userId &&
          other.movementType == this.movementType &&
          other.quantity == this.quantity &&
          other.note == this.note);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovement> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> productId;
  final Value<String?> userId;
  final Value<String> movementType;
  final Value<int> quantity;
  final Value<String?> note;
  final Value<int> rowid;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.productId = const Value.absent(),
    this.userId = const Value.absent(),
    this.movementType = const Value.absent(),
    this.quantity = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String productId,
    this.userId = const Value.absent(),
    required String movementType,
    required int quantity,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       productId = Value(productId),
       movementType = Value(movementType),
       quantity = Value(quantity);
  static Insertable<StockMovement> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? productId,
    Expression<String>? userId,
    Expression<String>? movementType,
    Expression<int>? quantity,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (productId != null) 'product_id': productId,
      if (userId != null) 'user_id': userId,
      if (movementType != null) 'movement_type': movementType,
      if (quantity != null) 'quantity': quantity,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? productId,
    Value<String?>? userId,
    Value<String>? movementType,
    Value<int>? quantity,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      movementType: movementType ?? this.movementType,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (movementType.present) {
      map['movement_type'] = Variable<String>(movementType.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('productId: $productId, ')
          ..write('userId: $userId, ')
          ..write('movementType: $movementType, ')
          ..write('quantity: $quantity, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentRecordsTable extends PaymentRecords
    with TableInfo<$PaymentRecordsTable, PaymentRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id)',
    ),
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceNoteMeta = const VerificationMeta(
    'referenceNote',
  );
  @override
  late final GeneratedColumn<String> referenceNote = GeneratedColumn<String>(
    'reference_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('paid'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleId,
    method,
    amountCents,
    referenceNote,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payment_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('reference_note')) {
      context.handle(
        _referenceNoteMeta,
        referenceNote.isAcceptableOrUnknown(
          data['reference_note']!,
          _referenceNoteMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      referenceNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_note'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $PaymentRecordsTable createAlias(String alias) {
    return $PaymentRecordsTable(attachedDatabase, alias);
  }
}

class PaymentRecord extends DataClass implements Insertable<PaymentRecord> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String saleId;
  final String method;
  final int amountCents;
  final String? referenceNote;
  final String status;
  const PaymentRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.saleId,
    required this.method,
    required this.amountCents,
    this.referenceNote,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['sale_id'] = Variable<String>(saleId);
    map['method'] = Variable<String>(method);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || referenceNote != null) {
      map['reference_note'] = Variable<String>(referenceNote);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  PaymentRecordsCompanion toCompanion(bool nullToAbsent) {
    return PaymentRecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      saleId: Value(saleId),
      method: Value(method),
      amountCents: Value(amountCents),
      referenceNote: referenceNote == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNote),
      status: Value(status),
    );
  }

  factory PaymentRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      saleId: serializer.fromJson<String>(json['saleId']),
      method: serializer.fromJson<String>(json['method']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      referenceNote: serializer.fromJson<String?>(json['referenceNote']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'saleId': serializer.toJson<String>(saleId),
      'method': serializer.toJson<String>(method),
      'amountCents': serializer.toJson<int>(amountCents),
      'referenceNote': serializer.toJson<String?>(referenceNote),
      'status': serializer.toJson<String>(status),
    };
  }

  PaymentRecord copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? saleId,
    String? method,
    int? amountCents,
    Value<String?> referenceNote = const Value.absent(),
    String? status,
  }) => PaymentRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    saleId: saleId ?? this.saleId,
    method: method ?? this.method,
    amountCents: amountCents ?? this.amountCents,
    referenceNote: referenceNote.present
        ? referenceNote.value
        : this.referenceNote,
    status: status ?? this.status,
  );
  PaymentRecord copyWithCompanion(PaymentRecordsCompanion data) {
    return PaymentRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      method: data.method.present ? data.method.value : this.method,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      referenceNote: data.referenceNote.present
          ? data.referenceNote.value
          : this.referenceNote,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('amountCents: $amountCents, ')
          ..write('referenceNote: $referenceNote, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    saleId,
    method,
    amountCents,
    referenceNote,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.saleId == this.saleId &&
          other.method == this.method &&
          other.amountCents == this.amountCents &&
          other.referenceNote == this.referenceNote &&
          other.status == this.status);
}

class PaymentRecordsCompanion extends UpdateCompanion<PaymentRecord> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> saleId;
  final Value<String> method;
  final Value<int> amountCents;
  final Value<String?> referenceNote;
  final Value<String> status;
  final Value<int> rowid;
  const PaymentRecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.saleId = const Value.absent(),
    this.method = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.referenceNote = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentRecordsCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String saleId,
    required String method,
    required int amountCents,
    this.referenceNote = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       saleId = Value(saleId),
       method = Value(method),
       amountCents = Value(amountCents);
  static Insertable<PaymentRecord> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? saleId,
    Expression<String>? method,
    Expression<int>? amountCents,
    Expression<String>? referenceNote,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (saleId != null) 'sale_id': saleId,
      if (method != null) 'method': method,
      if (amountCents != null) 'amount_cents': amountCents,
      if (referenceNote != null) 'reference_note': referenceNote,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? saleId,
    Value<String>? method,
    Value<int>? amountCents,
    Value<String?>? referenceNote,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return PaymentRecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      saleId: saleId ?? this.saleId,
      method: method ?? this.method,
      amountCents: amountCents ?? this.amountCents,
      referenceNote: referenceNote ?? this.referenceNote,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (referenceNote.present) {
      map['reference_note'] = Variable<String>(referenceNote.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('amountCents: $amountCents, ')
          ..write('referenceNote: $referenceNote, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BusinessSettingsTable extends BusinessSettings
    with TableInfo<$BusinessSettingsTable, BusinessSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevMeta = const VerificationMeta(
    'localRev',
  );
  @override
  late final GeneratedColumn<int> localRev = GeneratedColumn<int>(
    'local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _businessNameMeta = const VerificationMeta(
    'businessName',
  );
  @override
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
    'business_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptFooterMeta = const VerificationMeta(
    'receiptFooter',
  );
  @override
  late final GeneratedColumn<String> receiptFooter = GeneratedColumn<String>(
    'receipt_footer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('KES'),
  );
  static const VerificationMeta _paperWidthMmMeta = const VerificationMeta(
    'paperWidthMm',
  );
  @override
  late final GeneratedColumn<int> paperWidthMm = GeneratedColumn<int>(
    'paper_width_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(58),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    businessName,
    address,
    phone,
    receiptFooter,
    currency,
    paperWidthMm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_rev')) {
      context.handle(
        _localRevMeta,
        localRev.isAcceptableOrUnknown(data['local_rev']!, _localRevMeta),
      );
    } else if (isInserting) {
      context.missing(_localRevMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('business_name')) {
      context.handle(
        _businessNameMeta,
        businessName.isAcceptableOrUnknown(
          data['business_name']!,
          _businessNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessNameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('receipt_footer')) {
      context.handle(
        _receiptFooterMeta,
        receiptFooter.isAcceptableOrUnknown(
          data['receipt_footer']!,
          _receiptFooterMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('paper_width_mm')) {
      context.handle(
        _paperWidthMmMeta,
        paperWidthMm.isAcceptableOrUnknown(
          data['paper_width_mm']!,
          _paperWidthMmMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      localRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_rev'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      businessName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      receiptFooter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_footer'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      paperWidthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paper_width_mm'],
      )!,
    );
  }

  @override
  $BusinessSettingsTable createAlias(String alias) {
    return $BusinessSettingsTable(attachedDatabase, alias);
  }
}

class BusinessSetting extends DataClass implements Insertable<BusinessSetting> {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int localRev;
  final String createdByDeviceId;
  final String syncState;
  final String businessName;
  final String? address;
  final String? phone;
  final String? receiptFooter;
  final String currency;
  final int paperWidthMm;
  const BusinessSetting({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRev,
    required this.createdByDeviceId,
    required this.syncState,
    required this.businessName,
    this.address,
    this.phone,
    this.receiptFooter,
    required this.currency,
    required this.paperWidthMm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['local_rev'] = Variable<int>(localRev);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['sync_state'] = Variable<String>(syncState);
    map['business_name'] = Variable<String>(businessName);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || receiptFooter != null) {
      map['receipt_footer'] = Variable<String>(receiptFooter);
    }
    map['currency'] = Variable<String>(currency);
    map['paper_width_mm'] = Variable<int>(paperWidthMm);
    return map;
  }

  BusinessSettingsCompanion toCompanion(bool nullToAbsent) {
    return BusinessSettingsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRev: Value(localRev),
      createdByDeviceId: Value(createdByDeviceId),
      syncState: Value(syncState),
      businessName: Value(businessName),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      receiptFooter: receiptFooter == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptFooter),
      currency: Value(currency),
      paperWidthMm: Value(paperWidthMm),
    );
  }

  factory BusinessSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessSetting(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      localRev: serializer.fromJson<int>(json['localRev']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      syncState: serializer.fromJson<String>(json['syncState']),
      businessName: serializer.fromJson<String>(json['businessName']),
      address: serializer.fromJson<String?>(json['address']),
      phone: serializer.fromJson<String?>(json['phone']),
      receiptFooter: serializer.fromJson<String?>(json['receiptFooter']),
      currency: serializer.fromJson<String>(json['currency']),
      paperWidthMm: serializer.fromJson<int>(json['paperWidthMm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'localRev': serializer.toJson<int>(localRev),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'syncState': serializer.toJson<String>(syncState),
      'businessName': serializer.toJson<String>(businessName),
      'address': serializer.toJson<String?>(address),
      'phone': serializer.toJson<String?>(phone),
      'receiptFooter': serializer.toJson<String?>(receiptFooter),
      'currency': serializer.toJson<String>(currency),
      'paperWidthMm': serializer.toJson<int>(paperWidthMm),
    };
  }

  BusinessSetting copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? localRev,
    String? createdByDeviceId,
    String? syncState,
    String? businessName,
    Value<String?> address = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> receiptFooter = const Value.absent(),
    String? currency,
    int? paperWidthMm,
  }) => BusinessSetting(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRev: localRev ?? this.localRev,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    syncState: syncState ?? this.syncState,
    businessName: businessName ?? this.businessName,
    address: address.present ? address.value : this.address,
    phone: phone.present ? phone.value : this.phone,
    receiptFooter: receiptFooter.present
        ? receiptFooter.value
        : this.receiptFooter,
    currency: currency ?? this.currency,
    paperWidthMm: paperWidthMm ?? this.paperWidthMm,
  );
  BusinessSetting copyWithCompanion(BusinessSettingsCompanion data) {
    return BusinessSetting(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRev: data.localRev.present ? data.localRev.value : this.localRev,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      receiptFooter: data.receiptFooter.present
          ? data.receiptFooter.value
          : this.receiptFooter,
      currency: data.currency.present ? data.currency.value : this.currency,
      paperWidthMm: data.paperWidthMm.present
          ? data.paperWidthMm.value
          : this.paperWidthMm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSetting(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('businessName: $businessName, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('currency: $currency, ')
          ..write('paperWidthMm: $paperWidthMm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    localRev,
    createdByDeviceId,
    syncState,
    businessName,
    address,
    phone,
    receiptFooter,
    currency,
    paperWidthMm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessSetting &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRev == this.localRev &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.syncState == this.syncState &&
          other.businessName == this.businessName &&
          other.address == this.address &&
          other.phone == this.phone &&
          other.receiptFooter == this.receiptFooter &&
          other.currency == this.currency &&
          other.paperWidthMm == this.paperWidthMm);
}

class BusinessSettingsCompanion extends UpdateCompanion<BusinessSetting> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> localRev;
  final Value<String> createdByDeviceId;
  final Value<String> syncState;
  final Value<String> businessName;
  final Value<String?> address;
  final Value<String?> phone;
  final Value<String?> receiptFooter;
  final Value<String> currency;
  final Value<int> paperWidthMm;
  final Value<int> rowid;
  const BusinessSettingsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRev = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.businessName = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.currency = const Value.absent(),
    this.paperWidthMm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BusinessSettingsCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required int localRev,
    required String createdByDeviceId,
    this.syncState = const Value.absent(),
    required String businessName,
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.currency = const Value.absent(),
    this.paperWidthMm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       localRev = Value(localRev),
       createdByDeviceId = Value(createdByDeviceId),
       businessName = Value(businessName);
  static Insertable<BusinessSetting> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? localRev,
    Expression<String>? createdByDeviceId,
    Expression<String>? syncState,
    Expression<String>? businessName,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<String>? receiptFooter,
    Expression<String>? currency,
    Expression<int>? paperWidthMm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRev != null) 'local_rev': localRev,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (syncState != null) 'sync_state': syncState,
      if (businessName != null) 'business_name': businessName,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (receiptFooter != null) 'receipt_footer': receiptFooter,
      if (currency != null) 'currency': currency,
      if (paperWidthMm != null) 'paper_width_mm': paperWidthMm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BusinessSettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? localRev,
    Value<String>? createdByDeviceId,
    Value<String>? syncState,
    Value<String>? businessName,
    Value<String?>? address,
    Value<String?>? phone,
    Value<String?>? receiptFooter,
    Value<String>? currency,
    Value<int>? paperWidthMm,
    Value<int>? rowid,
  }) {
    return BusinessSettingsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRev: localRev ?? this.localRev,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      syncState: syncState ?? this.syncState,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currency: currency ?? this.currency,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (localRev.present) {
      map['local_rev'] = Variable<int>(localRev.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (receiptFooter.present) {
      map['receipt_footer'] = Variable<String>(receiptFooter.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (paperWidthMm.present) {
      map['paper_width_mm'] = Variable<int>(paperWidthMm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSettingsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRev: $localRev, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('syncState: $syncState, ')
          ..write('businessName: $businessName, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('currency: $currency, ')
          ..write('paperWidthMm: $paperWidthMm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceMetaTable extends DeviceMeta
    with TableInfo<$DeviceMetaTable, DeviceMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceLabelMeta = const VerificationMeta(
    'deviceLabel',
  );
  @override
  late final GeneratedColumn<String> deviceLabel = GeneratedColumn<String>(
    'device_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registrationSecretMeta =
      const VerificationMeta('registrationSecret');
  @override
  late final GeneratedColumn<String> registrationSecret =
      GeneratedColumn<String>(
        'registration_secret',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _nextLocalRevMeta = const VerificationMeta(
    'nextLocalRev',
  );
  @override
  late final GeneratedColumn<int> nextLocalRev = GeneratedColumn<int>(
    'next_local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastPushedLocalRevMeta =
      const VerificationMeta('lastPushedLocalRev');
  @override
  late final GeneratedColumn<int> lastPushedLocalRev = GeneratedColumn<int>(
    'last_pushed_local_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPulledChangeIdMeta =
      const VerificationMeta('lastPulledChangeId');
  @override
  late final GeneratedColumn<int> lastPulledChangeId = GeneratedColumn<int>(
    'last_pulled_change_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    deviceLabel,
    registrationSecret,
    nextLocalRev,
    lastPushedLocalRev,
    lastPulledChangeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('device_label')) {
      context.handle(
        _deviceLabelMeta,
        deviceLabel.isAcceptableOrUnknown(
          data['device_label']!,
          _deviceLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceLabelMeta);
    }
    if (data.containsKey('registration_secret')) {
      context.handle(
        _registrationSecretMeta,
        registrationSecret.isAcceptableOrUnknown(
          data['registration_secret']!,
          _registrationSecretMeta,
        ),
      );
    }
    if (data.containsKey('next_local_rev')) {
      context.handle(
        _nextLocalRevMeta,
        nextLocalRev.isAcceptableOrUnknown(
          data['next_local_rev']!,
          _nextLocalRevMeta,
        ),
      );
    }
    if (data.containsKey('last_pushed_local_rev')) {
      context.handle(
        _lastPushedLocalRevMeta,
        lastPushedLocalRev.isAcceptableOrUnknown(
          data['last_pushed_local_rev']!,
          _lastPushedLocalRevMeta,
        ),
      );
    }
    if (data.containsKey('last_pulled_change_id')) {
      context.handle(
        _lastPulledChangeIdMeta,
        lastPulledChangeId.isAcceptableOrUnknown(
          data['last_pulled_change_id']!,
          _lastPulledChangeIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceMetaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deviceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_label'],
      )!,
      registrationSecret: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_secret'],
      )!,
      nextLocalRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_local_rev'],
      )!,
      lastPushedLocalRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pushed_local_rev'],
      )!,
      lastPulledChangeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_change_id'],
      )!,
    );
  }

  @override
  $DeviceMetaTable createAlias(String alias) {
    return $DeviceMetaTable(attachedDatabase, alias);
  }
}

class DeviceMetaData extends DataClass implements Insertable<DeviceMetaData> {
  final String id;
  final String deviceId;
  final String deviceLabel;

  /// Generated once, alongside deviceId, and sent to nexapos_platform's
  /// register_device on every attempt (first and any retry) - proves
  /// this retry is genuinely the same caller as the original
  /// registration, since deviceId alone isn't secret (see
  /// nexapos_platform's clients.registration_secret_hash schema
  /// comment for the full story). Empty string, not null, for installs
  /// that predate this column - functionally equivalent, since any
  /// device that old is long past its 10-minute registration grace
  /// window anyway and will never need this again regardless.
  final String registrationSecret;
  final int nextLocalRev;

  /// The highest local_rev this device has successfully pushed to
  /// nexapos_platform - a single value, not one per table, since
  /// [nextLocalRev] is already one counter shared across every table.
  final int lastPushedLocalRev;

  /// The highest sync_changes.id this device has successfully pulled
  /// and applied - a server-assigned cursor, unrelated to local_rev.
  final int lastPulledChangeId;
  const DeviceMetaData({
    required this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.registrationSecret,
    required this.nextLocalRev,
    required this.lastPushedLocalRev,
    required this.lastPulledChangeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['device_label'] = Variable<String>(deviceLabel);
    map['registration_secret'] = Variable<String>(registrationSecret);
    map['next_local_rev'] = Variable<int>(nextLocalRev);
    map['last_pushed_local_rev'] = Variable<int>(lastPushedLocalRev);
    map['last_pulled_change_id'] = Variable<int>(lastPulledChangeId);
    return map;
  }

  DeviceMetaCompanion toCompanion(bool nullToAbsent) {
    return DeviceMetaCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      deviceLabel: Value(deviceLabel),
      registrationSecret: Value(registrationSecret),
      nextLocalRev: Value(nextLocalRev),
      lastPushedLocalRev: Value(lastPushedLocalRev),
      lastPulledChangeId: Value(lastPulledChangeId),
    );
  }

  factory DeviceMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceMetaData(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deviceLabel: serializer.fromJson<String>(json['deviceLabel']),
      registrationSecret: serializer.fromJson<String>(
        json['registrationSecret'],
      ),
      nextLocalRev: serializer.fromJson<int>(json['nextLocalRev']),
      lastPushedLocalRev: serializer.fromJson<int>(json['lastPushedLocalRev']),
      lastPulledChangeId: serializer.fromJson<int>(json['lastPulledChangeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'deviceLabel': serializer.toJson<String>(deviceLabel),
      'registrationSecret': serializer.toJson<String>(registrationSecret),
      'nextLocalRev': serializer.toJson<int>(nextLocalRev),
      'lastPushedLocalRev': serializer.toJson<int>(lastPushedLocalRev),
      'lastPulledChangeId': serializer.toJson<int>(lastPulledChangeId),
    };
  }

  DeviceMetaData copyWith({
    String? id,
    String? deviceId,
    String? deviceLabel,
    String? registrationSecret,
    int? nextLocalRev,
    int? lastPushedLocalRev,
    int? lastPulledChangeId,
  }) => DeviceMetaData(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    deviceLabel: deviceLabel ?? this.deviceLabel,
    registrationSecret: registrationSecret ?? this.registrationSecret,
    nextLocalRev: nextLocalRev ?? this.nextLocalRev,
    lastPushedLocalRev: lastPushedLocalRev ?? this.lastPushedLocalRev,
    lastPulledChangeId: lastPulledChangeId ?? this.lastPulledChangeId,
  );
  DeviceMetaData copyWithCompanion(DeviceMetaCompanion data) {
    return DeviceMetaData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deviceLabel: data.deviceLabel.present
          ? data.deviceLabel.value
          : this.deviceLabel,
      registrationSecret: data.registrationSecret.present
          ? data.registrationSecret.value
          : this.registrationSecret,
      nextLocalRev: data.nextLocalRev.present
          ? data.nextLocalRev.value
          : this.nextLocalRev,
      lastPushedLocalRev: data.lastPushedLocalRev.present
          ? data.lastPushedLocalRev.value
          : this.lastPushedLocalRev,
      lastPulledChangeId: data.lastPulledChangeId.present
          ? data.lastPulledChangeId.value
          : this.lastPulledChangeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceMetaData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('registrationSecret: $registrationSecret, ')
          ..write('nextLocalRev: $nextLocalRev, ')
          ..write('lastPushedLocalRev: $lastPushedLocalRev, ')
          ..write('lastPulledChangeId: $lastPulledChangeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    deviceLabel,
    registrationSecret,
    nextLocalRev,
    lastPushedLocalRev,
    lastPulledChangeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceMetaData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.deviceLabel == this.deviceLabel &&
          other.registrationSecret == this.registrationSecret &&
          other.nextLocalRev == this.nextLocalRev &&
          other.lastPushedLocalRev == this.lastPushedLocalRev &&
          other.lastPulledChangeId == this.lastPulledChangeId);
}

class DeviceMetaCompanion extends UpdateCompanion<DeviceMetaData> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> deviceLabel;
  final Value<String> registrationSecret;
  final Value<int> nextLocalRev;
  final Value<int> lastPushedLocalRev;
  final Value<int> lastPulledChangeId;
  final Value<int> rowid;
  const DeviceMetaCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    this.registrationSecret = const Value.absent(),
    this.nextLocalRev = const Value.absent(),
    this.lastPushedLocalRev = const Value.absent(),
    this.lastPulledChangeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceMetaCompanion.insert({
    required String id,
    required String deviceId,
    required String deviceLabel,
    this.registrationSecret = const Value.absent(),
    this.nextLocalRev = const Value.absent(),
    this.lastPushedLocalRev = const Value.absent(),
    this.lastPulledChangeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       deviceLabel = Value(deviceLabel);
  static Insertable<DeviceMetaData> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? deviceLabel,
    Expression<String>? registrationSecret,
    Expression<int>? nextLocalRev,
    Expression<int>? lastPushedLocalRev,
    Expression<int>? lastPulledChangeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (registrationSecret != null) 'registration_secret': registrationSecret,
      if (nextLocalRev != null) 'next_local_rev': nextLocalRev,
      if (lastPushedLocalRev != null)
        'last_pushed_local_rev': lastPushedLocalRev,
      if (lastPulledChangeId != null)
        'last_pulled_change_id': lastPulledChangeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceMetaCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? deviceLabel,
    Value<String>? registrationSecret,
    Value<int>? nextLocalRev,
    Value<int>? lastPushedLocalRev,
    Value<int>? lastPulledChangeId,
    Value<int>? rowid,
  }) {
    return DeviceMetaCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      registrationSecret: registrationSecret ?? this.registrationSecret,
      nextLocalRev: nextLocalRev ?? this.nextLocalRev,
      lastPushedLocalRev: lastPushedLocalRev ?? this.lastPushedLocalRev,
      lastPulledChangeId: lastPulledChangeId ?? this.lastPulledChangeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deviceLabel.present) {
      map['device_label'] = Variable<String>(deviceLabel.value);
    }
    if (registrationSecret.present) {
      map['registration_secret'] = Variable<String>(registrationSecret.value);
    }
    if (nextLocalRev.present) {
      map['next_local_rev'] = Variable<int>(nextLocalRev.value);
    }
    if (lastPushedLocalRev.present) {
      map['last_pushed_local_rev'] = Variable<int>(lastPushedLocalRev.value);
    }
    if (lastPulledChangeId.present) {
      map['last_pulled_change_id'] = Variable<int>(lastPulledChangeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceMetaCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('registrationSecret: $registrationSecret, ')
          ..write('nextLocalRev: $nextLocalRev, ')
          ..write('lastPushedLocalRev: $lastPushedLocalRev, ')
          ..write('lastPulledChangeId: $lastPulledChangeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleItemsTable saleItems = $SaleItemsTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  late final $PaymentRecordsTable paymentRecords = $PaymentRecordsTable(this);
  late final $BusinessSettingsTable businessSettings = $BusinessSettingsTable(
    this,
  );
  late final $DeviceMetaTable deviceMeta = $DeviceMetaTable(this);
  late final UsersDao usersDao = UsersDao(this as AppDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final ProductsDao productsDao = ProductsDao(this as AppDatabase);
  late final StockMovementsDao stockMovementsDao = StockMovementsDao(
    this as AppDatabase,
  );
  late final SalesDao salesDao = SalesDao(this as AppDatabase);
  late final SaleItemsDao saleItemsDao = SaleItemsDao(this as AppDatabase);
  late final PaymentRecordsDao paymentRecordsDao = PaymentRecordsDao(
    this as AppDatabase,
  );
  late final BusinessSettingsDao businessSettingsDao = BusinessSettingsDao(
    this as AppDatabase,
  );
  late final ReportsDao reportsDao = ReportsDao(this as AppDatabase);
  late final ExpensesDao expensesDao = ExpensesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    roles,
    users,
    categories,
    products,
    sales,
    saleItems,
    expenses,
    stockMovements,
    paymentRecords,
    businessSettings,
    deviceMeta,
  ];
}

typedef $$RolesTableCreateCompanionBuilder = RolesCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String name,
  Value<String?> description,
  Value<int> rowid,
});
typedef $$RolesTableUpdateCompanionBuilder = RolesCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> name,
  Value<String?> description,
  Value<int> rowid,
});

final class $$RolesTableReferences
    extends BaseReferences<_$AppDatabase, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UsersTable, List<User>> _usersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.users,
    aliasName: 'roles__id__users__role_id',
  );

  $$UsersTableProcessedTableManager get usersRefs {
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_usersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RolesTableFilterComposer extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> usersRefs(
    Expression<bool> Function($$UsersTableFilterComposer f) f,
  ) {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableOrderingComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  Expression<T> usersRefs<T extends Object>(
    Expression<T> Function($$UsersTableAnnotationComposer a) f,
  ) {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RolesTable,
          Role,
          $$RolesTableFilterComposer,
          $$RolesTableOrderingComposer,
          $$RolesTableAnnotationComposer,
          $$RolesTableCreateCompanionBuilder,
          $$RolesTableUpdateCompanionBuilder,
          (Role, $$RolesTableReferences),
          Role,
          PrefetchHooks Function({bool usersRefs})
        > {
  $$RolesTableTableManager(_$AppDatabase db, $RolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RolesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                name: name,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RolesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                name: name,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RolesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({usersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (usersRefs) db.users],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (usersRefs)
                    await $_getPrefetchedData<Role, $RolesTable, User>(
                      currentTable: table,
                      referencedTable: $$RolesTableReferences._usersRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RolesTableReferences(db, table, p0).usersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RolesTable,
      Role,
      $$RolesTableFilterComposer,
      $$RolesTableOrderingComposer,
      $$RolesTableAnnotationComposer,
      $$RolesTableCreateCompanionBuilder,
      $$RolesTableUpdateCompanionBuilder,
      (Role, $$RolesTableReferences),
      Role,
      PrefetchHooks Function({bool usersRefs})
    >;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String roleId,
  required String name,
  required String username,
  Value<String?> email,
  required String passwordHash,
  Value<String?> phone,
  Value<String> status,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> roleId,
  Value<String> name,
  Value<String> username,
  Value<String?> email,
  Value<String> passwordHash,
  Value<String?> phone,
  Value<String> status,
  Value<int> rowid,
});

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('users__role_id__roles__id');

  $$RolesTableProcessedTableManager get roleId {
    final $_column = $_itemColumn<String>('role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SalesTable, List<Sale>> _salesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sales,
    aliasName: 'users__id__sales__user_id',
  );

  $$SalesTableProcessedTableManager get salesRefs {
    final manager = $$SalesTableTableManager(
      $_db,
      $_db.sales,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_salesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'users__id__expenses__user_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovement>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'users__id__stock_movements__user_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> salesRefs(
    Expression<bool> Function($$SalesTableFilterComposer f) f,
  ) {
    final $$SalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableFilterComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> salesRefs<T extends Object>(
    Expression<T> Function($$SalesTableAnnotationComposer a) f,
  ) {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableAnnotationComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({
            bool roleId,
            bool salesRefs,
            bool expensesRefs,
            bool stockMovementsRefs,
          })
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> roleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                roleId: roleId,
                name: name,
                username: username,
                email: email,
                passwordHash: passwordHash,
                phone: phone,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String roleId,
                required String name,
                required String username,
                Value<String?> email = const Value.absent(),
                required String passwordHash,
                Value<String?> phone = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                roleId: roleId,
                name: name,
                username: username,
                email: email,
                passwordHash: passwordHash,
                phone: phone,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roleId = false,
                salesRefs = false,
                expensesRefs = false,
                stockMovementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (salesRefs) db.sales,
                    if (expensesRefs) db.expenses,
                    if (stockMovementsRefs) db.stockMovements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (roleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.roleId,
                            referencedTable: $$UsersTableReferences
                                ._roleIdTable(db),
                            referencedColumn: $$UsersTableReferences
                                ._roleIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (salesRefs)
                        await $_getPrefetchedData<User, $UsersTable, Sale>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._salesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(db, table, p0).salesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expensesRefs)
                        await $_getPrefetchedData<User, $UsersTable, Expense>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          StockMovement
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({
        bool roleId,
        bool salesRefs,
        bool expensesRefs,
        bool stockMovementsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String name,
  Value<String> status,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> name,
  Value<String> status,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductsTable, List<Product>> _productsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.products,
    aliasName: 'categories__id__products__category_id',
  );

  $$ProductsTableProcessedTableManager get productsRefs {
    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_productsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> productsRefs(
    Expression<bool> Function($$ProductsTableFilterComposer f) f,
  ) {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> productsRefs<T extends Object>(
    Expression<T> Function($$ProductsTableAnnotationComposer a) f,
  ) {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool productsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                name: name,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String name,
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                name: name,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (productsRefs) db.products],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (productsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Product
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._productsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).productsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool productsRefs})
    >;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String sku,
  required String name,
  required String categoryId,
  Value<String?> imagePath,
  required int retailPriceCents,
  required int wholesalePriceCents,
  required int costPriceCents,
  Value<int> stockQty,
  Value<int> reorderLevel,
  Value<String> status,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> sku,
  Value<String> name,
  Value<String> categoryId,
  Value<String?> imagePath,
  Value<int> retailPriceCents,
  Value<int> wholesalePriceCents,
  Value<int> costPriceCents,
  Value<int> stockQty,
  Value<int> reorderLevel,
  Value<String> status,
  Value<int> rowid,
});

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('products__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SaleItemsTable, List<SaleItem>>
  _saleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.saleItems,
    aliasName: 'products__id__sale_items__product_id',
  );

  $$SaleItemsTableProcessedTableManager get saleItemsRefs {
    final manager = $$SaleItemsTableTableManager(
      $_db,
      $_db.saleItems,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovement>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'products__id__stock_movements__product_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retailPriceCents => $composableBuilder(
    column: $table.retailPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wholesalePriceCents => $composableBuilder(
    column: $table.wholesalePriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> saleItemsRefs(
    Expression<bool> Function($$SaleItemsTableFilterComposer f) f,
  ) {
    final $$SaleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableFilterComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retailPriceCents => $composableBuilder(
    column: $table.retailPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wholesalePriceCents => $composableBuilder(
    column: $table.wholesalePriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get retailPriceCents => $composableBuilder(
    column: $table.retailPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wholesalePriceCents => $composableBuilder(
    column: $table.wholesalePriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<int> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> saleItemsRefs<T extends Object>(
    Expression<T> Function($$SaleItemsTableAnnotationComposer a) f,
  ) {
    final $$SaleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, $$ProductsTableReferences),
          Product,
          PrefetchHooks Function({
            bool categoryId,
            bool saleItemsRefs,
            bool stockMovementsRefs,
          })
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> sku = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<int> retailPriceCents = const Value.absent(),
                Value<int> wholesalePriceCents = const Value.absent(),
                Value<int> costPriceCents = const Value.absent(),
                Value<int> stockQty = const Value.absent(),
                Value<int> reorderLevel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                sku: sku,
                name: name,
                categoryId: categoryId,
                imagePath: imagePath,
                retailPriceCents: retailPriceCents,
                wholesalePriceCents: wholesalePriceCents,
                costPriceCents: costPriceCents,
                stockQty: stockQty,
                reorderLevel: reorderLevel,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String sku,
                required String name,
                required String categoryId,
                Value<String?> imagePath = const Value.absent(),
                required int retailPriceCents,
                required int wholesalePriceCents,
                required int costPriceCents,
                Value<int> stockQty = const Value.absent(),
                Value<int> reorderLevel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                sku: sku,
                name: name,
                categoryId: categoryId,
                imagePath: imagePath,
                retailPriceCents: retailPriceCents,
                wholesalePriceCents: wholesalePriceCents,
                costPriceCents: costPriceCents,
                stockQty: stockQty,
                reorderLevel: reorderLevel,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                saleItemsRefs = false,
                stockMovementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (saleItemsRefs) db.saleItems,
                    if (stockMovementsRefs) db.stockMovements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$ProductsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$ProductsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (saleItemsRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          SaleItem
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._saleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).saleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          StockMovement
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, $$ProductsTableReferences),
      Product,
      PrefetchHooks Function({
        bool categoryId,
        bool saleItemsRefs,
        bool stockMovementsRefs,
      })
    >;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String saleNumber,
  required String userId,
  Value<String?> customerName,
  Value<String?> customerPhone,
  required String saleType,
  required String paymentMethod,
  required int subtotalCents,
  Value<int> discountCents,
  required int totalCents,
  required String status,
  Value<int> rowid,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> saleNumber,
  Value<String> userId,
  Value<String?> customerName,
  Value<String?> customerPhone,
  Value<String> saleType,
  Value<String> paymentMethod,
  Value<int> subtotalCents,
  Value<int> discountCents,
  Value<int> totalCents,
  Value<String> status,
  Value<int> rowid,
});

final class $$SalesTableReferences
    extends BaseReferences<_$AppDatabase, $SalesTable, Sale> {
  $$SalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('sales__user_id__users__id');

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SaleItemsTable, List<SaleItem>>
  _saleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.saleItems,
    aliasName: 'sales__id__sale_items__sale_id',
  );

  $$SaleItemsTableProcessedTableManager get saleItemsRefs {
    final manager = $$SaleItemsTableTableManager(
      $_db,
      $_db.saleItems,
    ).filter((f) => f.saleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentRecordsTable, List<PaymentRecord>>
  _paymentRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.paymentRecords,
    aliasName: 'sales__id__payment_records__sale_id',
  );

  $$PaymentRecordsTableProcessedTableManager get paymentRecordsRefs {
    final manager = $$PaymentRecordsTableTableManager(
      $_db,
      $_db.paymentRecords,
    ).filter((f) => f.saleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleType => $composableBuilder(
    column: $table.saleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> saleItemsRefs(
    Expression<bool> Function($$SaleItemsTableFilterComposer f) f,
  ) {
    final $$SaleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableFilterComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentRecordsRefs(
    Expression<bool> Function($$PaymentRecordsTableFilterComposer f) f,
  ) {
    final $$PaymentRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentRecords,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentRecordsTableFilterComposer(
            $db: $db,
            $table: $db.paymentRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleType => $composableBuilder(
    column: $table.saleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saleType =>
      $composableBuilder(column: $table.saleType, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> saleItemsRefs<T extends Object>(
    Expression<T> Function($$SaleItemsTableAnnotationComposer a) f,
  ) {
    final $$SaleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentRecordsRefs<T extends Object>(
    Expression<T> Function($$PaymentRecordsTableAnnotationComposer a) f,
  ) {
    final $$PaymentRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentRecords,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.paymentRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, $$SalesTableReferences),
          Sale,
          PrefetchHooks Function({
            bool userId,
            bool saleItemsRefs,
            bool paymentRecordsRefs,
          })
        > {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> saleNumber = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<String> saleType = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<int> subtotalCents = const Value.absent(),
                Value<int> discountCents = const Value.absent(),
                Value<int> totalCents = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleNumber: saleNumber,
                userId: userId,
                customerName: customerName,
                customerPhone: customerPhone,
                saleType: saleType,
                paymentMethod: paymentMethod,
                subtotalCents: subtotalCents,
                discountCents: discountCents,
                totalCents: totalCents,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String saleNumber,
                required String userId,
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                required String saleType,
                required String paymentMethod,
                required int subtotalCents,
                Value<int> discountCents = const Value.absent(),
                required int totalCents,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleNumber: saleNumber,
                userId: userId,
                customerName: customerName,
                customerPhone: customerPhone,
                saleType: saleType,
                paymentMethod: paymentMethod,
                subtotalCents: subtotalCents,
                discountCents: discountCents,
                totalCents: totalCents,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SalesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userId = false,
                saleItemsRefs = false,
                paymentRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (saleItemsRefs) db.saleItems,
                    if (paymentRecordsRefs) db.paymentRecords,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.userId,
                            referencedTable: $$SalesTableReferences
                                ._userIdTable(db),
                            referencedColumn: $$SalesTableReferences
                                ._userIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (saleItemsRefs)
                        await $_getPrefetchedData<Sale, $SalesTable, SaleItem>(
                          currentTable: table,
                          referencedTable: $$SalesTableReferences
                              ._saleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SalesTableReferences(
                                db,
                                table,
                                p0,
                              ).saleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.saleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentRecordsRefs)
                        await $_getPrefetchedData<
                          Sale,
                          $SalesTable,
                          PaymentRecord
                        >(
                          currentTable: table,
                          referencedTable: $$SalesTableReferences
                              ._paymentRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SalesTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.saleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, $$SalesTableReferences),
      Sale,
      PrefetchHooks Function({
        bool userId,
        bool saleItemsRefs,
        bool paymentRecordsRefs,
      })
    >;
typedef $$SaleItemsTableCreateCompanionBuilder = SaleItemsCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  required String saleId,
  Value<String?> productId,
  required String itemName,
  required int quantity,
  required int unitPriceCents,
  required int costPriceCents,
  required int lineTotalCents,
  Value<int> rowid,
});
typedef $$SaleItemsTableUpdateCompanionBuilder = SaleItemsCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String> saleId,
  Value<String?> productId,
  Value<String> itemName,
  Value<int> quantity,
  Value<int> unitPriceCents,
  Value<int> costPriceCents,
  Value<int> lineTotalCents,
  Value<int> rowid,
});

final class $$SaleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SaleItemsTable, SaleItem> {
  $$SaleItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleIdTable(_$AppDatabase db) =>
      db.sales.createAlias('sale_items__sale_id__sales__id');

  $$SalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<String>('sale_id')!;

    final manager = $$SalesTableTableManager(
      $_db,
      $_db.sales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('sale_items__product_id__products__id');

  $$ProductsTableProcessedTableManager? get productId {
    final $_column = $_itemColumn<String>('product_id');
    if ($_column == null) return null;
    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SaleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => ColumnFilters(column),
  );

  $$SalesTableFilterComposer get saleId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableFilterComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => ColumnOrderings(column),
  );

  $$SalesTableOrderingComposer get saleId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableOrderingComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costPriceCents => $composableBuilder(
    column: $table.costPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => column,
  );

  $$SalesTableAnnotationComposer get saleId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableAnnotationComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SaleItemsTable,
          SaleItem,
          $$SaleItemsTableFilterComposer,
          $$SaleItemsTableOrderingComposer,
          $$SaleItemsTableAnnotationComposer,
          $$SaleItemsTableCreateCompanionBuilder,
          $$SaleItemsTableUpdateCompanionBuilder,
          (SaleItem, $$SaleItemsTableReferences),
          SaleItem,
          PrefetchHooks Function({bool saleId, bool productId})
        > {
  $$SaleItemsTableTableManager(_$AppDatabase db, $SaleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> itemName = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> unitPriceCents = const Value.absent(),
                Value<int> costPriceCents = const Value.absent(),
                Value<int> lineTotalCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SaleItemsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleId: saleId,
                productId: productId,
                itemName: itemName,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                costPriceCents: costPriceCents,
                lineTotalCents: lineTotalCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String saleId,
                Value<String?> productId = const Value.absent(),
                required String itemName,
                required int quantity,
                required int unitPriceCents,
                required int costPriceCents,
                required int lineTotalCents,
                Value<int> rowid = const Value.absent(),
              }) => SaleItemsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleId: saleId,
                productId: productId,
                itemName: itemName,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                costPriceCents: costPriceCents,
                lineTotalCents: lineTotalCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SaleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false, productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (saleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.saleId,
                        referencedTable: $$SaleItemsTableReferences
                            ._saleIdTable(db),
                        referencedColumn: $$SaleItemsTableReferences
                            ._saleIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $$SaleItemsTableReferences
                            ._productIdTable(db),
                        referencedColumn: $$SaleItemsTableReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SaleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SaleItemsTable,
      SaleItem,
      $$SaleItemsTableFilterComposer,
      $$SaleItemsTableOrderingComposer,
      $$SaleItemsTableAnnotationComposer,
      $$SaleItemsTableCreateCompanionBuilder,
      $$SaleItemsTableUpdateCompanionBuilder,
      (SaleItem, $$SaleItemsTableReferences),
      SaleItem,
      PrefetchHooks Function({bool saleId, bool productId})
    >;
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required String createdAt,
  required String updatedAt,
  Value<String?> deletedAt,
  required int localRev,
  required String createdByDeviceId,
  Value<String> syncState,
  Value<String?> userId,
  required String expenseDate,
  required String title,
  required int amountCents,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> deletedAt,
  Value<int> localRev,
  Value<String> createdByDeviceId,
  Value<String> syncState,
  Value<String?> userId,
  Value<String> expenseDate,
  Value<String> title,
  Value<int> amountCents,
  Value<String?> note,
  Value<int> rowid,
});

final class $$ExpensesTableReferences
    extends BaseReferences<_$AppDatabase, $ExpensesTable, Expense> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('expenses__user_id__users__id');

  $$UsersTableProcessedTableManager? get userId {
    final $_column = $_itemColumn<String>('user_id');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, $$ExpensesTableReferences),
          Expense,
          PrefetchHooks Function({bool userId})
        > {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> expenseDate = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                userId: userId,
                expenseDate: expenseDate,
                title: title,
                amountCents: amountCents,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                required String expenseDate,
                required String title,
                required int amountCents,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                userId: userId,
                expenseDate: expenseDate,
                title: title,
                amountCents: amountCents,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExpensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.userId,
                        referencedTable: $$ExpensesTableReferences._userIdTable(
                          db,
                        ),
                        referencedColumn: $$ExpensesTableReferences
                            ._userIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, $$ExpensesTableReferences),
      Expense,
      PrefetchHooks Function({bool userId})
    >;
typedef $$StockMovementsTableCreateCompanionBuilder =
    StockMovementsCompanion Function({
      required String id,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      required int localRev,
      required String createdByDeviceId,
      Value<String> syncState,
      required String productId,
      Value<String?> userId,
      required String movementType,
      required int quantity,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$StockMovementsTableUpdateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<String> id,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> localRev,
      Value<String> createdByDeviceId,
      Value<String> syncState,
      Value<String> productId,
      Value<String?> userId,
      Value<String> movementType,
      Value<int> quantity,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$StockMovementsTableReferences
    extends BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovement> {
  $$StockMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('stock_movements__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('stock_movements__user_id__users__id');

  $$UsersTableProcessedTableManager? get userId {
    final $_column = $_itemColumn<String>('user_id');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockMovementsTable,
          StockMovement,
          $$StockMovementsTableFilterComposer,
          $$StockMovementsTableOrderingComposer,
          $$StockMovementsTableAnnotationComposer,
          $$StockMovementsTableCreateCompanionBuilder,
          $$StockMovementsTableUpdateCompanionBuilder,
          (StockMovement, $$StockMovementsTableReferences),
          StockMovement,
          PrefetchHooks Function({bool productId, bool userId})
        > {
  $$StockMovementsTableTableManager(
    _$AppDatabase db,
    $StockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> movementType = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockMovementsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                productId: productId,
                userId: userId,
                movementType: movementType,
                quantity: quantity,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String productId,
                Value<String?> userId = const Value.absent(),
                required String movementType,
                required int quantity,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockMovementsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                productId: productId,
                userId: userId,
                movementType: movementType,
                quantity: quantity,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false, userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $$StockMovementsTableReferences
                            ._productIdTable(db),
                        referencedColumn: $$StockMovementsTableReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (userId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.userId,
                        referencedTable: $$StockMovementsTableReferences
                            ._userIdTable(db),
                        referencedColumn: $$StockMovementsTableReferences
                            ._userIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockMovementsTable,
      StockMovement,
      $$StockMovementsTableFilterComposer,
      $$StockMovementsTableOrderingComposer,
      $$StockMovementsTableAnnotationComposer,
      $$StockMovementsTableCreateCompanionBuilder,
      $$StockMovementsTableUpdateCompanionBuilder,
      (StockMovement, $$StockMovementsTableReferences),
      StockMovement,
      PrefetchHooks Function({bool productId, bool userId})
    >;
typedef $$PaymentRecordsTableCreateCompanionBuilder =
    PaymentRecordsCompanion Function({
      required String id,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      required int localRev,
      required String createdByDeviceId,
      Value<String> syncState,
      required String saleId,
      required String method,
      required int amountCents,
      Value<String?> referenceNote,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$PaymentRecordsTableUpdateCompanionBuilder =
    PaymentRecordsCompanion Function({
      Value<String> id,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> localRev,
      Value<String> createdByDeviceId,
      Value<String> syncState,
      Value<String> saleId,
      Value<String> method,
      Value<int> amountCents,
      Value<String?> referenceNote,
      Value<String> status,
      Value<int> rowid,
    });

final class $$PaymentRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $PaymentRecordsTable, PaymentRecord> {
  $$PaymentRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SalesTable _saleIdTable(_$AppDatabase db) =>
      db.sales.createAlias('payment_records__sale_id__sales__id');

  $$SalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<String>('sale_id')!;

    final manager = $$SalesTableTableManager(
      $_db,
      $_db.sales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentRecordsTable> {
  $$PaymentRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceNote => $composableBuilder(
    column: $table.referenceNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$SalesTableFilterComposer get saleId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableFilterComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentRecordsTable> {
  $$PaymentRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceNote => $composableBuilder(
    column: $table.referenceNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$SalesTableOrderingComposer get saleId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableOrderingComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentRecordsTable> {
  $$PaymentRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceNote => $composableBuilder(
    column: $table.referenceNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$SalesTableAnnotationComposer get saleId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableAnnotationComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentRecordsTable,
          PaymentRecord,
          $$PaymentRecordsTableFilterComposer,
          $$PaymentRecordsTableOrderingComposer,
          $$PaymentRecordsTableAnnotationComposer,
          $$PaymentRecordsTableCreateCompanionBuilder,
          $$PaymentRecordsTableUpdateCompanionBuilder,
          (PaymentRecord, $$PaymentRecordsTableReferences),
          PaymentRecord,
          PrefetchHooks Function({bool saleId})
        > {
  $$PaymentRecordsTableTableManager(
    _$AppDatabase db,
    $PaymentRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String?> referenceNote = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentRecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleId: saleId,
                method: method,
                amountCents: amountCents,
                referenceNote: referenceNote,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String saleId,
                required String method,
                required int amountCents,
                Value<String?> referenceNote = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentRecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                saleId: saleId,
                method: method,
                amountCents: amountCents,
                referenceNote: referenceNote,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PaymentRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (saleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.saleId,
                        referencedTable: $$PaymentRecordsTableReferences
                            ._saleIdTable(db),
                        referencedColumn: $$PaymentRecordsTableReferences
                            ._saleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PaymentRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentRecordsTable,
      PaymentRecord,
      $$PaymentRecordsTableFilterComposer,
      $$PaymentRecordsTableOrderingComposer,
      $$PaymentRecordsTableAnnotationComposer,
      $$PaymentRecordsTableCreateCompanionBuilder,
      $$PaymentRecordsTableUpdateCompanionBuilder,
      (PaymentRecord, $$PaymentRecordsTableReferences),
      PaymentRecord,
      PrefetchHooks Function({bool saleId})
    >;
typedef $$BusinessSettingsTableCreateCompanionBuilder =
    BusinessSettingsCompanion Function({
      required String id,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      required int localRev,
      required String createdByDeviceId,
      Value<String> syncState,
      required String businessName,
      Value<String?> address,
      Value<String?> phone,
      Value<String?> receiptFooter,
      Value<String> currency,
      Value<int> paperWidthMm,
      Value<int> rowid,
    });
typedef $$BusinessSettingsTableUpdateCompanionBuilder =
    BusinessSettingsCompanion Function({
      Value<String> id,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> localRev,
      Value<String> createdByDeviceId,
      Value<String> syncState,
      Value<String> businessName,
      Value<String?> address,
      Value<String?> phone,
      Value<String?> receiptFooter,
      Value<String> currency,
      Value<int> paperWidthMm,
      Value<int> rowid,
    });

class $$BusinessSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paperWidthMm => $composableBuilder(
    column: $table.paperWidthMm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BusinessSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRev => $composableBuilder(
    column: $table.localRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paperWidthMm => $composableBuilder(
    column: $table.paperWidthMm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRev =>
      $composableBuilder(column: $table.localRev, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get paperWidthMm => $composableBuilder(
    column: $table.paperWidthMm,
    builder: (column) => column,
  );
}

class $$BusinessSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BusinessSettingsTable,
          BusinessSetting,
          $$BusinessSettingsTableFilterComposer,
          $$BusinessSettingsTableOrderingComposer,
          $$BusinessSettingsTableAnnotationComposer,
          $$BusinessSettingsTableCreateCompanionBuilder,
          $$BusinessSettingsTableUpdateCompanionBuilder,
          (
            BusinessSetting,
            BaseReferences<
              _$AppDatabase,
              $BusinessSettingsTable,
              BusinessSetting
            >,
          ),
          BusinessSetting,
          PrefetchHooks Function()
        > {
  $$BusinessSettingsTableTableManager(
    _$AppDatabase db,
    $BusinessSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> localRev = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> businessName = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> paperWidthMm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessSettingsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                businessName: businessName,
                address: address,
                phone: phone,
                receiptFooter: receiptFooter,
                currency: currency,
                paperWidthMm: paperWidthMm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required int localRev,
                required String createdByDeviceId,
                Value<String> syncState = const Value.absent(),
                required String businessName,
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> paperWidthMm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessSettingsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRev: localRev,
                createdByDeviceId: createdByDeviceId,
                syncState: syncState,
                businessName: businessName,
                address: address,
                phone: phone,
                receiptFooter: receiptFooter,
                currency: currency,
                paperWidthMm: paperWidthMm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BusinessSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BusinessSettingsTable,
      BusinessSetting,
      $$BusinessSettingsTableFilterComposer,
      $$BusinessSettingsTableOrderingComposer,
      $$BusinessSettingsTableAnnotationComposer,
      $$BusinessSettingsTableCreateCompanionBuilder,
      $$BusinessSettingsTableUpdateCompanionBuilder,
      (
        BusinessSetting,
        BaseReferences<_$AppDatabase, $BusinessSettingsTable, BusinessSetting>,
      ),
      BusinessSetting,
      PrefetchHooks Function()
    >;
typedef $$DeviceMetaTableCreateCompanionBuilder = DeviceMetaCompanion Function({
  required String id,
  required String deviceId,
  required String deviceLabel,
  Value<String> registrationSecret,
  Value<int> nextLocalRev,
  Value<int> lastPushedLocalRev,
  Value<int> lastPulledChangeId,
  Value<int> rowid,
});
typedef $$DeviceMetaTableUpdateCompanionBuilder = DeviceMetaCompanion Function({
  Value<String> id,
  Value<String> deviceId,
  Value<String> deviceLabel,
  Value<String> registrationSecret,
  Value<int> nextLocalRev,
  Value<int> lastPushedLocalRev,
  Value<int> lastPulledChangeId,
  Value<int> rowid,
});

class $$DeviceMetaTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceMetaTable> {
  $$DeviceMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrationSecret => $composableBuilder(
    column: $table.registrationSecret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextLocalRev => $composableBuilder(
    column: $table.nextLocalRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPushedLocalRev => $composableBuilder(
    column: $table.lastPushedLocalRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledChangeId => $composableBuilder(
    column: $table.lastPulledChangeId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceMetaTable> {
  $$DeviceMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrationSecret => $composableBuilder(
    column: $table.registrationSecret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextLocalRev => $composableBuilder(
    column: $table.nextLocalRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPushedLocalRev => $composableBuilder(
    column: $table.lastPushedLocalRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledChangeId => $composableBuilder(
    column: $table.lastPulledChangeId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceMetaTable> {
  $$DeviceMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registrationSecret => $composableBuilder(
    column: $table.registrationSecret,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextLocalRev => $composableBuilder(
    column: $table.nextLocalRev,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPushedLocalRev => $composableBuilder(
    column: $table.lastPushedLocalRev,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPulledChangeId => $composableBuilder(
    column: $table.lastPulledChangeId,
    builder: (column) => column,
  );
}

class $$DeviceMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceMetaTable,
          DeviceMetaData,
          $$DeviceMetaTableFilterComposer,
          $$DeviceMetaTableOrderingComposer,
          $$DeviceMetaTableAnnotationComposer,
          $$DeviceMetaTableCreateCompanionBuilder,
          $$DeviceMetaTableUpdateCompanionBuilder,
          (
            DeviceMetaData,
            BaseReferences<_$AppDatabase, $DeviceMetaTable, DeviceMetaData>,
          ),
          DeviceMetaData,
          PrefetchHooks Function()
        > {
  $$DeviceMetaTableTableManager(_$AppDatabase db, $DeviceMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> deviceLabel = const Value.absent(),
                Value<String> registrationSecret = const Value.absent(),
                Value<int> nextLocalRev = const Value.absent(),
                Value<int> lastPushedLocalRev = const Value.absent(),
                Value<int> lastPulledChangeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceMetaCompanion(
                id: id,
                deviceId: deviceId,
                deviceLabel: deviceLabel,
                registrationSecret: registrationSecret,
                nextLocalRev: nextLocalRev,
                lastPushedLocalRev: lastPushedLocalRev,
                lastPulledChangeId: lastPulledChangeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String deviceLabel,
                Value<String> registrationSecret = const Value.absent(),
                Value<int> nextLocalRev = const Value.absent(),
                Value<int> lastPushedLocalRev = const Value.absent(),
                Value<int> lastPulledChangeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceMetaCompanion.insert(
                id: id,
                deviceId: deviceId,
                deviceLabel: deviceLabel,
                registrationSecret: registrationSecret,
                nextLocalRev: nextLocalRev,
                lastPushedLocalRev: lastPushedLocalRev,
                lastPulledChangeId: lastPulledChangeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceMetaTable,
      DeviceMetaData,
      $$DeviceMetaTableFilterComposer,
      $$DeviceMetaTableOrderingComposer,
      $$DeviceMetaTableAnnotationComposer,
      $$DeviceMetaTableCreateCompanionBuilder,
      $$DeviceMetaTableUpdateCompanionBuilder,
      (
        DeviceMetaData,
        BaseReferences<_$AppDatabase, $DeviceMetaTable, DeviceMetaData>,
      ),
      DeviceMetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db, _db.saleItems);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(_db, _db.stockMovements);
  $$PaymentRecordsTableTableManager get paymentRecords =>
      $$PaymentRecordsTableTableManager(_db, _db.paymentRecords);
  $$BusinessSettingsTableTableManager get businessSettings =>
      $$BusinessSettingsTableTableManager(_db, _db.businessSettings);
  $$DeviceMetaTableTableManager get deviceMeta =>
      $$DeviceMetaTableTableManager(_db, _db.deviceMeta);
}
