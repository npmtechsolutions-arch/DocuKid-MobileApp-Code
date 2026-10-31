// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OperationsTable extends Operations
    with TableInfo<$OperationsTable, OperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolMeta = const VerificationMeta('tool');
  @override
  late final GeneratedColumn<String> tool = GeneratedColumn<String>(
    'tool',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inputCountMeta = const VerificationMeta(
    'inputCount',
  );
  @override
  late final GeneratedColumn<int> inputCount = GeneratedColumn<int>(
    'input_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTotalBytesMeta = const VerificationMeta(
    'inputTotalBytes',
  );
  @override
  late final GeneratedColumn<int> inputTotalBytes = GeneratedColumn<int>(
    'input_total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputNameMeta = const VerificationMeta(
    'outputName',
  );
  @override
  late final GeneratedColumn<String> outputName = GeneratedColumn<String>(
    'output_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputMimeMeta = const VerificationMeta(
    'outputMime',
  );
  @override
  late final GeneratedColumn<String> outputMime = GeneratedColumn<String>(
    'output_mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputBytesMeta = const VerificationMeta(
    'outputBytes',
  );
  @override
  late final GeneratedColumn<int> outputBytes = GeneratedColumn<int>(
    'output_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputRelPathMeta = const VerificationMeta(
    'outputRelPath',
  );
  @override
  late final GeneratedColumn<String> outputRelPath = GeneratedColumn<String>(
    'output_rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputMetaJsonMeta = const VerificationMeta(
    'outputMetaJson',
  );
  @override
  late final GeneratedColumn<String> outputMetaJson = GeneratedColumn<String>(
    'output_meta_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedExternallyMeta = const VerificationMeta(
    'savedExternally',
  );
  @override
  late final GeneratedColumn<bool> savedExternally = GeneratedColumn<bool>(
    'saved_externally',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("saved_externally" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _outputDeletedAtMeta = const VerificationMeta(
    'outputDeletedAt',
  );
  @override
  late final GeneratedColumn<int> outputDeletedAt = GeneratedColumn<int>(
    'output_deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputCountMeta = const VerificationMeta(
    'outputCount',
  );
  @override
  late final GeneratedColumn<int> outputCount = GeneratedColumn<int>(
    'output_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _failedCountMeta = const VerificationMeta(
    'failedCount',
  );
  @override
  late final GeneratedColumn<int> failedCount = GeneratedColumn<int>(
    'failed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _zipRelPathMeta = const VerificationMeta(
    'zipRelPath',
  );
  @override
  late final GeneratedColumn<String> zipRelPath = GeneratedColumn<String>(
    'zip_rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tool,
    status,
    errorCode,
    createdAt,
    finishedAt,
    durationMs,
    inputCount,
    inputTotalBytes,
    outputName,
    outputMime,
    outputBytes,
    outputRelPath,
    outputMetaJson,
    optionsJson,
    savedExternally,
    outputDeletedAt,
    outputCount,
    failedCount,
    zipRelPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tool')) {
      context.handle(
        _toolMeta,
        tool.isAcceptableOrUnknown(data['tool']!, _toolMeta),
      );
    } else if (isInserting) {
      context.missing(_toolMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('input_count')) {
      context.handle(
        _inputCountMeta,
        inputCount.isAcceptableOrUnknown(data['input_count']!, _inputCountMeta),
      );
    } else if (isInserting) {
      context.missing(_inputCountMeta);
    }
    if (data.containsKey('input_total_bytes')) {
      context.handle(
        _inputTotalBytesMeta,
        inputTotalBytes.isAcceptableOrUnknown(
          data['input_total_bytes']!,
          _inputTotalBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputTotalBytesMeta);
    }
    if (data.containsKey('output_name')) {
      context.handle(
        _outputNameMeta,
        outputName.isAcceptableOrUnknown(data['output_name']!, _outputNameMeta),
      );
    }
    if (data.containsKey('output_mime')) {
      context.handle(
        _outputMimeMeta,
        outputMime.isAcceptableOrUnknown(data['output_mime']!, _outputMimeMeta),
      );
    }
    if (data.containsKey('output_bytes')) {
      context.handle(
        _outputBytesMeta,
        outputBytes.isAcceptableOrUnknown(
          data['output_bytes']!,
          _outputBytesMeta,
        ),
      );
    }
    if (data.containsKey('output_rel_path')) {
      context.handle(
        _outputRelPathMeta,
        outputRelPath.isAcceptableOrUnknown(
          data['output_rel_path']!,
          _outputRelPathMeta,
        ),
      );
    }
    if (data.containsKey('output_meta_json')) {
      context.handle(
        _outputMetaJsonMeta,
        outputMetaJson.isAcceptableOrUnknown(
          data['output_meta_json']!,
          _outputMetaJsonMeta,
        ),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('saved_externally')) {
      context.handle(
        _savedExternallyMeta,
        savedExternally.isAcceptableOrUnknown(
          data['saved_externally']!,
          _savedExternallyMeta,
        ),
      );
    }
    if (data.containsKey('output_deleted_at')) {
      context.handle(
        _outputDeletedAtMeta,
        outputDeletedAt.isAcceptableOrUnknown(
          data['output_deleted_at']!,
          _outputDeletedAtMeta,
        ),
      );
    }
    if (data.containsKey('output_count')) {
      context.handle(
        _outputCountMeta,
        outputCount.isAcceptableOrUnknown(
          data['output_count']!,
          _outputCountMeta,
        ),
      );
    }
    if (data.containsKey('failed_count')) {
      context.handle(
        _failedCountMeta,
        failedCount.isAcceptableOrUnknown(
          data['failed_count']!,
          _failedCountMeta,
        ),
      );
    }
    if (data.containsKey('zip_rel_path')) {
      context.handle(
        _zipRelPathMeta,
        zipRelPath.isAcceptableOrUnknown(
          data['zip_rel_path']!,
          _zipRelPathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tool: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      inputCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_count'],
      )!,
      inputTotalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_total_bytes'],
      )!,
      outputName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_name'],
      ),
      outputMime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_mime'],
      ),
      outputBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_bytes'],
      ),
      outputRelPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_rel_path'],
      ),
      outputMetaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_meta_json'],
      ),
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      ),
      savedExternally: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}saved_externally'],
      )!,
      outputDeletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_deleted_at'],
      ),
      outputCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_count'],
      )!,
      failedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_count'],
      )!,
      zipRelPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zip_rel_path'],
      ),
    );
  }

  @override
  $OperationsTable createAlias(String alias) {
    return $OperationsTable(attachedDatabase, alias);
  }
}

class OperationRow extends DataClass implements Insertable<OperationRow> {
  final String id;
  final String tool;
  final String status;
  final String? errorCode;
  final int createdAt;
  final int? finishedAt;
  final int? durationMs;
  final int inputCount;
  final int inputTotalBytes;
  final String? outputName;
  final String? outputMime;
  final int? outputBytes;
  final String? outputRelPath;
  final String? outputMetaJson;
  final String? optionsJson;
  final bool savedExternally;
  final int? outputDeletedAt;
  final int outputCount;
  final int failedCount;
  final String? zipRelPath;
  const OperationRow({
    required this.id,
    required this.tool,
    required this.status,
    this.errorCode,
    required this.createdAt,
    this.finishedAt,
    this.durationMs,
    required this.inputCount,
    required this.inputTotalBytes,
    this.outputName,
    this.outputMime,
    this.outputBytes,
    this.outputRelPath,
    this.outputMetaJson,
    this.optionsJson,
    required this.savedExternally,
    this.outputDeletedAt,
    required this.outputCount,
    required this.failedCount,
    this.zipRelPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tool'] = Variable<String>(tool);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['input_count'] = Variable<int>(inputCount);
    map['input_total_bytes'] = Variable<int>(inputTotalBytes);
    if (!nullToAbsent || outputName != null) {
      map['output_name'] = Variable<String>(outputName);
    }
    if (!nullToAbsent || outputMime != null) {
      map['output_mime'] = Variable<String>(outputMime);
    }
    if (!nullToAbsent || outputBytes != null) {
      map['output_bytes'] = Variable<int>(outputBytes);
    }
    if (!nullToAbsent || outputRelPath != null) {
      map['output_rel_path'] = Variable<String>(outputRelPath);
    }
    if (!nullToAbsent || outputMetaJson != null) {
      map['output_meta_json'] = Variable<String>(outputMetaJson);
    }
    if (!nullToAbsent || optionsJson != null) {
      map['options_json'] = Variable<String>(optionsJson);
    }
    map['saved_externally'] = Variable<bool>(savedExternally);
    if (!nullToAbsent || outputDeletedAt != null) {
      map['output_deleted_at'] = Variable<int>(outputDeletedAt);
    }
    map['output_count'] = Variable<int>(outputCount);
    map['failed_count'] = Variable<int>(failedCount);
    if (!nullToAbsent || zipRelPath != null) {
      map['zip_rel_path'] = Variable<String>(zipRelPath);
    }
    return map;
  }

  OperationsCompanion toCompanion(bool nullToAbsent) {
    return OperationsCompanion(
      id: Value(id),
      tool: Value(tool),
      status: Value(status),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      inputCount: Value(inputCount),
      inputTotalBytes: Value(inputTotalBytes),
      outputName: outputName == null && nullToAbsent
          ? const Value.absent()
          : Value(outputName),
      outputMime: outputMime == null && nullToAbsent
          ? const Value.absent()
          : Value(outputMime),
      outputBytes: outputBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(outputBytes),
      outputRelPath: outputRelPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputRelPath),
      outputMetaJson: outputMetaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(outputMetaJson),
      optionsJson: optionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(optionsJson),
      savedExternally: Value(savedExternally),
      outputDeletedAt: outputDeletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(outputDeletedAt),
      outputCount: Value(outputCount),
      failedCount: Value(failedCount),
      zipRelPath: zipRelPath == null && nullToAbsent
          ? const Value.absent()
          : Value(zipRelPath),
    );
  }

  factory OperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationRow(
      id: serializer.fromJson<String>(json['id']),
      tool: serializer.fromJson<String>(json['tool']),
      status: serializer.fromJson<String>(json['status']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      inputCount: serializer.fromJson<int>(json['inputCount']),
      inputTotalBytes: serializer.fromJson<int>(json['inputTotalBytes']),
      outputName: serializer.fromJson<String?>(json['outputName']),
      outputMime: serializer.fromJson<String?>(json['outputMime']),
      outputBytes: serializer.fromJson<int?>(json['outputBytes']),
      outputRelPath: serializer.fromJson<String?>(json['outputRelPath']),
      outputMetaJson: serializer.fromJson<String?>(json['outputMetaJson']),
      optionsJson: serializer.fromJson<String?>(json['optionsJson']),
      savedExternally: serializer.fromJson<bool>(json['savedExternally']),
      outputDeletedAt: serializer.fromJson<int?>(json['outputDeletedAt']),
      outputCount: serializer.fromJson<int>(json['outputCount']),
      failedCount: serializer.fromJson<int>(json['failedCount']),
      zipRelPath: serializer.fromJson<String?>(json['zipRelPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tool': serializer.toJson<String>(tool),
      'status': serializer.toJson<String>(status),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<int>(createdAt),
      'finishedAt': serializer.toJson<int?>(finishedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'inputCount': serializer.toJson<int>(inputCount),
      'inputTotalBytes': serializer.toJson<int>(inputTotalBytes),
      'outputName': serializer.toJson<String?>(outputName),
      'outputMime': serializer.toJson<String?>(outputMime),
      'outputBytes': serializer.toJson<int?>(outputBytes),
      'outputRelPath': serializer.toJson<String?>(outputRelPath),
      'outputMetaJson': serializer.toJson<String?>(outputMetaJson),
      'optionsJson': serializer.toJson<String?>(optionsJson),
      'savedExternally': serializer.toJson<bool>(savedExternally),
      'outputDeletedAt': serializer.toJson<int?>(outputDeletedAt),
      'outputCount': serializer.toJson<int>(outputCount),
      'failedCount': serializer.toJson<int>(failedCount),
      'zipRelPath': serializer.toJson<String?>(zipRelPath),
    };
  }

  OperationRow copyWith({
    String? id,
    String? tool,
    String? status,
    Value<String?> errorCode = const Value.absent(),
    int? createdAt,
    Value<int?> finishedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? inputCount,
    int? inputTotalBytes,
    Value<String?> outputName = const Value.absent(),
    Value<String?> outputMime = const Value.absent(),
    Value<int?> outputBytes = const Value.absent(),
    Value<String?> outputRelPath = const Value.absent(),
    Value<String?> outputMetaJson = const Value.absent(),
    Value<String?> optionsJson = const Value.absent(),
    bool? savedExternally,
    Value<int?> outputDeletedAt = const Value.absent(),
    int? outputCount,
    int? failedCount,
    Value<String?> zipRelPath = const Value.absent(),
  }) => OperationRow(
    id: id ?? this.id,
    tool: tool ?? this.tool,
    status: status ?? this.status,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    inputCount: inputCount ?? this.inputCount,
    inputTotalBytes: inputTotalBytes ?? this.inputTotalBytes,
    outputName: outputName.present ? outputName.value : this.outputName,
    outputMime: outputMime.present ? outputMime.value : this.outputMime,
    outputBytes: outputBytes.present ? outputBytes.value : this.outputBytes,
    outputRelPath: outputRelPath.present
        ? outputRelPath.value
        : this.outputRelPath,
    outputMetaJson: outputMetaJson.present
        ? outputMetaJson.value
        : this.outputMetaJson,
    optionsJson: optionsJson.present ? optionsJson.value : this.optionsJson,
    savedExternally: savedExternally ?? this.savedExternally,
    outputDeletedAt: outputDeletedAt.present
        ? outputDeletedAt.value
        : this.outputDeletedAt,
    outputCount: outputCount ?? this.outputCount,
    failedCount: failedCount ?? this.failedCount,
    zipRelPath: zipRelPath.present ? zipRelPath.value : this.zipRelPath,
  );
  OperationRow copyWithCompanion(OperationsCompanion data) {
    return OperationRow(
      id: data.id.present ? data.id.value : this.id,
      tool: data.tool.present ? data.tool.value : this.tool,
      status: data.status.present ? data.status.value : this.status,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      inputCount: data.inputCount.present
          ? data.inputCount.value
          : this.inputCount,
      inputTotalBytes: data.inputTotalBytes.present
          ? data.inputTotalBytes.value
          : this.inputTotalBytes,
      outputName: data.outputName.present
          ? data.outputName.value
          : this.outputName,
      outputMime: data.outputMime.present
          ? data.outputMime.value
          : this.outputMime,
      outputBytes: data.outputBytes.present
          ? data.outputBytes.value
          : this.outputBytes,
      outputRelPath: data.outputRelPath.present
          ? data.outputRelPath.value
          : this.outputRelPath,
      outputMetaJson: data.outputMetaJson.present
          ? data.outputMetaJson.value
          : this.outputMetaJson,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      savedExternally: data.savedExternally.present
          ? data.savedExternally.value
          : this.savedExternally,
      outputDeletedAt: data.outputDeletedAt.present
          ? data.outputDeletedAt.value
          : this.outputDeletedAt,
      outputCount: data.outputCount.present
          ? data.outputCount.value
          : this.outputCount,
      failedCount: data.failedCount.present
          ? data.failedCount.value
          : this.failedCount,
      zipRelPath: data.zipRelPath.present
          ? data.zipRelPath.value
          : this.zipRelPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationRow(')
          ..write('id: $id, ')
          ..write('tool: $tool, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('inputCount: $inputCount, ')
          ..write('inputTotalBytes: $inputTotalBytes, ')
          ..write('outputName: $outputName, ')
          ..write('outputMime: $outputMime, ')
          ..write('outputBytes: $outputBytes, ')
          ..write('outputRelPath: $outputRelPath, ')
          ..write('outputMetaJson: $outputMetaJson, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('savedExternally: $savedExternally, ')
          ..write('outputDeletedAt: $outputDeletedAt, ')
          ..write('outputCount: $outputCount, ')
          ..write('failedCount: $failedCount, ')
          ..write('zipRelPath: $zipRelPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tool,
    status,
    errorCode,
    createdAt,
    finishedAt,
    durationMs,
    inputCount,
    inputTotalBytes,
    outputName,
    outputMime,
    outputBytes,
    outputRelPath,
    outputMetaJson,
    optionsJson,
    savedExternally,
    outputDeletedAt,
    outputCount,
    failedCount,
    zipRelPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationRow &&
          other.id == this.id &&
          other.tool == this.tool &&
          other.status == this.status &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.finishedAt == this.finishedAt &&
          other.durationMs == this.durationMs &&
          other.inputCount == this.inputCount &&
          other.inputTotalBytes == this.inputTotalBytes &&
          other.outputName == this.outputName &&
          other.outputMime == this.outputMime &&
          other.outputBytes == this.outputBytes &&
          other.outputRelPath == this.outputRelPath &&
          other.outputMetaJson == this.outputMetaJson &&
          other.optionsJson == this.optionsJson &&
          other.savedExternally == this.savedExternally &&
          other.outputDeletedAt == this.outputDeletedAt &&
          other.outputCount == this.outputCount &&
          other.failedCount == this.failedCount &&
          other.zipRelPath == this.zipRelPath);
}

class OperationsCompanion extends UpdateCompanion<OperationRow> {
  final Value<String> id;
  final Value<String> tool;
  final Value<String> status;
  final Value<String?> errorCode;
  final Value<int> createdAt;
  final Value<int?> finishedAt;
  final Value<int?> durationMs;
  final Value<int> inputCount;
  final Value<int> inputTotalBytes;
  final Value<String?> outputName;
  final Value<String?> outputMime;
  final Value<int?> outputBytes;
  final Value<String?> outputRelPath;
  final Value<String?> outputMetaJson;
  final Value<String?> optionsJson;
  final Value<bool> savedExternally;
  final Value<int?> outputDeletedAt;
  final Value<int> outputCount;
  final Value<int> failedCount;
  final Value<String?> zipRelPath;
  final Value<int> rowid;
  const OperationsCompanion({
    this.id = const Value.absent(),
    this.tool = const Value.absent(),
    this.status = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.inputCount = const Value.absent(),
    this.inputTotalBytes = const Value.absent(),
    this.outputName = const Value.absent(),
    this.outputMime = const Value.absent(),
    this.outputBytes = const Value.absent(),
    this.outputRelPath = const Value.absent(),
    this.outputMetaJson = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.savedExternally = const Value.absent(),
    this.outputDeletedAt = const Value.absent(),
    this.outputCount = const Value.absent(),
    this.failedCount = const Value.absent(),
    this.zipRelPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationsCompanion.insert({
    required String id,
    required String tool,
    required String status,
    this.errorCode = const Value.absent(),
    required int createdAt,
    this.finishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int inputCount,
    required int inputTotalBytes,
    this.outputName = const Value.absent(),
    this.outputMime = const Value.absent(),
    this.outputBytes = const Value.absent(),
    this.outputRelPath = const Value.absent(),
    this.outputMetaJson = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.savedExternally = const Value.absent(),
    this.outputDeletedAt = const Value.absent(),
    this.outputCount = const Value.absent(),
    this.failedCount = const Value.absent(),
    this.zipRelPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tool = Value(tool),
       status = Value(status),
       createdAt = Value(createdAt),
       inputCount = Value(inputCount),
       inputTotalBytes = Value(inputTotalBytes);
  static Insertable<OperationRow> custom({
    Expression<String>? id,
    Expression<String>? tool,
    Expression<String>? status,
    Expression<String>? errorCode,
    Expression<int>? createdAt,
    Expression<int>? finishedAt,
    Expression<int>? durationMs,
    Expression<int>? inputCount,
    Expression<int>? inputTotalBytes,
    Expression<String>? outputName,
    Expression<String>? outputMime,
    Expression<int>? outputBytes,
    Expression<String>? outputRelPath,
    Expression<String>? outputMetaJson,
    Expression<String>? optionsJson,
    Expression<bool>? savedExternally,
    Expression<int>? outputDeletedAt,
    Expression<int>? outputCount,
    Expression<int>? failedCount,
    Expression<String>? zipRelPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tool != null) 'tool': tool,
      if (status != null) 'status': status,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (inputCount != null) 'input_count': inputCount,
      if (inputTotalBytes != null) 'input_total_bytes': inputTotalBytes,
      if (outputName != null) 'output_name': outputName,
      if (outputMime != null) 'output_mime': outputMime,
      if (outputBytes != null) 'output_bytes': outputBytes,
      if (outputRelPath != null) 'output_rel_path': outputRelPath,
      if (outputMetaJson != null) 'output_meta_json': outputMetaJson,
      if (optionsJson != null) 'options_json': optionsJson,
      if (savedExternally != null) 'saved_externally': savedExternally,
      if (outputDeletedAt != null) 'output_deleted_at': outputDeletedAt,
      if (outputCount != null) 'output_count': outputCount,
      if (failedCount != null) 'failed_count': failedCount,
      if (zipRelPath != null) 'zip_rel_path': zipRelPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? tool,
    Value<String>? status,
    Value<String?>? errorCode,
    Value<int>? createdAt,
    Value<int?>? finishedAt,
    Value<int?>? durationMs,
    Value<int>? inputCount,
    Value<int>? inputTotalBytes,
    Value<String?>? outputName,
    Value<String?>? outputMime,
    Value<int?>? outputBytes,
    Value<String?>? outputRelPath,
    Value<String?>? outputMetaJson,
    Value<String?>? optionsJson,
    Value<bool>? savedExternally,
    Value<int?>? outputDeletedAt,
    Value<int>? outputCount,
    Value<int>? failedCount,
    Value<String?>? zipRelPath,
    Value<int>? rowid,
  }) {
    return OperationsCompanion(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
      durationMs: durationMs ?? this.durationMs,
      inputCount: inputCount ?? this.inputCount,
      inputTotalBytes: inputTotalBytes ?? this.inputTotalBytes,
      outputName: outputName ?? this.outputName,
      outputMime: outputMime ?? this.outputMime,
      outputBytes: outputBytes ?? this.outputBytes,
      outputRelPath: outputRelPath ?? this.outputRelPath,
      outputMetaJson: outputMetaJson ?? this.outputMetaJson,
      optionsJson: optionsJson ?? this.optionsJson,
      savedExternally: savedExternally ?? this.savedExternally,
      outputDeletedAt: outputDeletedAt ?? this.outputDeletedAt,
      outputCount: outputCount ?? this.outputCount,
      failedCount: failedCount ?? this.failedCount,
      zipRelPath: zipRelPath ?? this.zipRelPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tool.present) {
      map['tool'] = Variable<String>(tool.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (inputCount.present) {
      map['input_count'] = Variable<int>(inputCount.value);
    }
    if (inputTotalBytes.present) {
      map['input_total_bytes'] = Variable<int>(inputTotalBytes.value);
    }
    if (outputName.present) {
      map['output_name'] = Variable<String>(outputName.value);
    }
    if (outputMime.present) {
      map['output_mime'] = Variable<String>(outputMime.value);
    }
    if (outputBytes.present) {
      map['output_bytes'] = Variable<int>(outputBytes.value);
    }
    if (outputRelPath.present) {
      map['output_rel_path'] = Variable<String>(outputRelPath.value);
    }
    if (outputMetaJson.present) {
      map['output_meta_json'] = Variable<String>(outputMetaJson.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (savedExternally.present) {
      map['saved_externally'] = Variable<bool>(savedExternally.value);
    }
    if (outputDeletedAt.present) {
      map['output_deleted_at'] = Variable<int>(outputDeletedAt.value);
    }
    if (outputCount.present) {
      map['output_count'] = Variable<int>(outputCount.value);
    }
    if (failedCount.present) {
      map['failed_count'] = Variable<int>(failedCount.value);
    }
    if (zipRelPath.present) {
      map['zip_rel_path'] = Variable<String>(zipRelPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsCompanion(')
          ..write('id: $id, ')
          ..write('tool: $tool, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('inputCount: $inputCount, ')
          ..write('inputTotalBytes: $inputTotalBytes, ')
          ..write('outputName: $outputName, ')
          ..write('outputMime: $outputMime, ')
          ..write('outputBytes: $outputBytes, ')
          ..write('outputRelPath: $outputRelPath, ')
          ..write('outputMetaJson: $outputMetaJson, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('savedExternally: $savedExternally, ')
          ..write('outputDeletedAt: $outputDeletedAt, ')
          ..write('outputCount: $outputCount, ')
          ..write('failedCount: $failedCount, ')
          ..write('zipRelPath: $zipRelPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationInputsTable extends OperationInputs
    with TableInfo<$OperationInputsTable, OperationInputRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationInputsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES operations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    position,
    displayName,
    mime,
    sizeBytes,
    metaJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_inputs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationInputRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId, position};
  @override
  OperationInputRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationInputRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      ),
    );
  }

  @override
  $OperationInputsTable createAlias(String alias) {
    return $OperationInputsTable(attachedDatabase, alias);
  }
}

class OperationInputRow extends DataClass
    implements Insertable<OperationInputRow> {
  final String operationId;
  final int position;
  final String displayName;
  final String mime;
  final int sizeBytes;
  final String? metaJson;
  const OperationInputRow({
    required this.operationId,
    required this.position,
    required this.displayName,
    required this.mime,
    required this.sizeBytes,
    this.metaJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['position'] = Variable<int>(position);
    map['display_name'] = Variable<String>(displayName);
    map['mime'] = Variable<String>(mime);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || metaJson != null) {
      map['meta_json'] = Variable<String>(metaJson);
    }
    return map;
  }

  OperationInputsCompanion toCompanion(bool nullToAbsent) {
    return OperationInputsCompanion(
      operationId: Value(operationId),
      position: Value(position),
      displayName: Value(displayName),
      mime: Value(mime),
      sizeBytes: Value(sizeBytes),
      metaJson: metaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metaJson),
    );
  }

  factory OperationInputRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationInputRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      position: serializer.fromJson<int>(json['position']),
      displayName: serializer.fromJson<String>(json['displayName']),
      mime: serializer.fromJson<String>(json['mime']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      metaJson: serializer.fromJson<String?>(json['metaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'position': serializer.toJson<int>(position),
      'displayName': serializer.toJson<String>(displayName),
      'mime': serializer.toJson<String>(mime),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'metaJson': serializer.toJson<String?>(metaJson),
    };
  }

  OperationInputRow copyWith({
    String? operationId,
    int? position,
    String? displayName,
    String? mime,
    int? sizeBytes,
    Value<String?> metaJson = const Value.absent(),
  }) => OperationInputRow(
    operationId: operationId ?? this.operationId,
    position: position ?? this.position,
    displayName: displayName ?? this.displayName,
    mime: mime ?? this.mime,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    metaJson: metaJson.present ? metaJson.value : this.metaJson,
  );
  OperationInputRow copyWithCompanion(OperationInputsCompanion data) {
    return OperationInputRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      position: data.position.present ? data.position.value : this.position,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      mime: data.mime.present ? data.mime.value : this.mime,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationInputRow(')
          ..write('operationId: $operationId, ')
          ..write('position: $position, ')
          ..write('displayName: $displayName, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('metaJson: $metaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    position,
    displayName,
    mime,
    sizeBytes,
    metaJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationInputRow &&
          other.operationId == this.operationId &&
          other.position == this.position &&
          other.displayName == this.displayName &&
          other.mime == this.mime &&
          other.sizeBytes == this.sizeBytes &&
          other.metaJson == this.metaJson);
}

class OperationInputsCompanion extends UpdateCompanion<OperationInputRow> {
  final Value<String> operationId;
  final Value<int> position;
  final Value<String> displayName;
  final Value<String> mime;
  final Value<int> sizeBytes;
  final Value<String?> metaJson;
  final Value<int> rowid;
  const OperationInputsCompanion({
    this.operationId = const Value.absent(),
    this.position = const Value.absent(),
    this.displayName = const Value.absent(),
    this.mime = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationInputsCompanion.insert({
    required String operationId,
    required int position,
    required String displayName,
    required String mime,
    required int sizeBytes,
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       position = Value(position),
       displayName = Value(displayName),
       mime = Value(mime),
       sizeBytes = Value(sizeBytes);
  static Insertable<OperationInputRow> custom({
    Expression<String>? operationId,
    Expression<int>? position,
    Expression<String>? displayName,
    Expression<String>? mime,
    Expression<int>? sizeBytes,
    Expression<String>? metaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (position != null) 'position': position,
      if (displayName != null) 'display_name': displayName,
      if (mime != null) 'mime': mime,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (metaJson != null) 'meta_json': metaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationInputsCompanion copyWith({
    Value<String>? operationId,
    Value<int>? position,
    Value<String>? displayName,
    Value<String>? mime,
    Value<int>? sizeBytes,
    Value<String?>? metaJson,
    Value<int>? rowid,
  }) {
    return OperationInputsCompanion(
      operationId: operationId ?? this.operationId,
      position: position ?? this.position,
      displayName: displayName ?? this.displayName,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      metaJson: metaJson ?? this.metaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationInputsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('position: $position, ')
          ..write('displayName: $displayName, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('metaJson: $metaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationOutputsTable extends OperationOutputs
    with TableInfo<$OperationOutputsTable, OperationOutputRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationOutputsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES operations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beforeBytesMeta = const VerificationMeta(
    'beforeBytes',
  );
  @override
  late final GeneratedColumn<int> beforeBytes = GeneratedColumn<int>(
    'before_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    position,
    displayName,
    relPath,
    sizeBytes,
    beforeBytes,
    errorCode,
    metaJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_outputs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationOutputRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('before_bytes')) {
      context.handle(
        _beforeBytesMeta,
        beforeBytes.isAcceptableOrUnknown(
          data['before_bytes']!,
          _beforeBytesMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId, position};
  @override
  OperationOutputRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationOutputRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      beforeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}before_bytes'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      ),
    );
  }

  @override
  $OperationOutputsTable createAlias(String alias) {
    return $OperationOutputsTable(attachedDatabase, alias);
  }
}

class OperationOutputRow extends DataClass
    implements Insertable<OperationOutputRow> {
  final String operationId;
  final int position;
  final String displayName;
  final String? relPath;
  final int? sizeBytes;
  final int? beforeBytes;
  final String? errorCode;
  final String? metaJson;
  const OperationOutputRow({
    required this.operationId,
    required this.position,
    required this.displayName,
    this.relPath,
    this.sizeBytes,
    this.beforeBytes,
    this.errorCode,
    this.metaJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['position'] = Variable<int>(position);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || relPath != null) {
      map['rel_path'] = Variable<String>(relPath);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || beforeBytes != null) {
      map['before_bytes'] = Variable<int>(beforeBytes);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || metaJson != null) {
      map['meta_json'] = Variable<String>(metaJson);
    }
    return map;
  }

  OperationOutputsCompanion toCompanion(bool nullToAbsent) {
    return OperationOutputsCompanion(
      operationId: Value(operationId),
      position: Value(position),
      displayName: Value(displayName),
      relPath: relPath == null && nullToAbsent
          ? const Value.absent()
          : Value(relPath),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      beforeBytes: beforeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeBytes),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      metaJson: metaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metaJson),
    );
  }

  factory OperationOutputRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationOutputRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      position: serializer.fromJson<int>(json['position']),
      displayName: serializer.fromJson<String>(json['displayName']),
      relPath: serializer.fromJson<String?>(json['relPath']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      beforeBytes: serializer.fromJson<int?>(json['beforeBytes']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      metaJson: serializer.fromJson<String?>(json['metaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'position': serializer.toJson<int>(position),
      'displayName': serializer.toJson<String>(displayName),
      'relPath': serializer.toJson<String?>(relPath),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'beforeBytes': serializer.toJson<int?>(beforeBytes),
      'errorCode': serializer.toJson<String?>(errorCode),
      'metaJson': serializer.toJson<String?>(metaJson),
    };
  }

  OperationOutputRow copyWith({
    String? operationId,
    int? position,
    String? displayName,
    Value<String?> relPath = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> beforeBytes = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> metaJson = const Value.absent(),
  }) => OperationOutputRow(
    operationId: operationId ?? this.operationId,
    position: position ?? this.position,
    displayName: displayName ?? this.displayName,
    relPath: relPath.present ? relPath.value : this.relPath,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    beforeBytes: beforeBytes.present ? beforeBytes.value : this.beforeBytes,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    metaJson: metaJson.present ? metaJson.value : this.metaJson,
  );
  OperationOutputRow copyWithCompanion(OperationOutputsCompanion data) {
    return OperationOutputRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      position: data.position.present ? data.position.value : this.position,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      beforeBytes: data.beforeBytes.present
          ? data.beforeBytes.value
          : this.beforeBytes,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationOutputRow(')
          ..write('operationId: $operationId, ')
          ..write('position: $position, ')
          ..write('displayName: $displayName, ')
          ..write('relPath: $relPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('beforeBytes: $beforeBytes, ')
          ..write('errorCode: $errorCode, ')
          ..write('metaJson: $metaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    position,
    displayName,
    relPath,
    sizeBytes,
    beforeBytes,
    errorCode,
    metaJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationOutputRow &&
          other.operationId == this.operationId &&
          other.position == this.position &&
          other.displayName == this.displayName &&
          other.relPath == this.relPath &&
          other.sizeBytes == this.sizeBytes &&
          other.beforeBytes == this.beforeBytes &&
          other.errorCode == this.errorCode &&
          other.metaJson == this.metaJson);
}

class OperationOutputsCompanion extends UpdateCompanion<OperationOutputRow> {
  final Value<String> operationId;
  final Value<int> position;
  final Value<String> displayName;
  final Value<String?> relPath;
  final Value<int?> sizeBytes;
  final Value<int?> beforeBytes;
  final Value<String?> errorCode;
  final Value<String?> metaJson;
  final Value<int> rowid;
  const OperationOutputsCompanion({
    this.operationId = const Value.absent(),
    this.position = const Value.absent(),
    this.displayName = const Value.absent(),
    this.relPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.beforeBytes = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationOutputsCompanion.insert({
    required String operationId,
    required int position,
    required String displayName,
    this.relPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.beforeBytes = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       position = Value(position),
       displayName = Value(displayName);
  static Insertable<OperationOutputRow> custom({
    Expression<String>? operationId,
    Expression<int>? position,
    Expression<String>? displayName,
    Expression<String>? relPath,
    Expression<int>? sizeBytes,
    Expression<int>? beforeBytes,
    Expression<String>? errorCode,
    Expression<String>? metaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (position != null) 'position': position,
      if (displayName != null) 'display_name': displayName,
      if (relPath != null) 'rel_path': relPath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (beforeBytes != null) 'before_bytes': beforeBytes,
      if (errorCode != null) 'error_code': errorCode,
      if (metaJson != null) 'meta_json': metaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationOutputsCompanion copyWith({
    Value<String>? operationId,
    Value<int>? position,
    Value<String>? displayName,
    Value<String?>? relPath,
    Value<int?>? sizeBytes,
    Value<int?>? beforeBytes,
    Value<String?>? errorCode,
    Value<String?>? metaJson,
    Value<int>? rowid,
  }) {
    return OperationOutputsCompanion(
      operationId: operationId ?? this.operationId,
      position: position ?? this.position,
      displayName: displayName ?? this.displayName,
      relPath: relPath ?? this.relPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      beforeBytes: beforeBytes ?? this.beforeBytes,
      errorCode: errorCode ?? this.errorCode,
      metaJson: metaJson ?? this.metaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (beforeBytes.present) {
      map['before_bytes'] = Variable<int>(beforeBytes.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationOutputsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('position: $position, ')
          ..write('displayName: $displayName, ')
          ..write('relPath: $relPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('beforeBytes: $beforeBytes, ')
          ..write('errorCode: $errorCode, ')
          ..write('metaJson: $metaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _depthMeta = const VerificationMeta('depth');
  @override
  late final GeneratedColumn<int> depth = GeneratedColumn<int>(
    'depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    name,
    depth,
    createdAt,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
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
    if (data.containsKey('depth')) {
      context.handle(
        _depthMeta,
        depth.isAcceptableOrUnknown(data['depth']!, _depthMeta),
      );
    } else if (isInserting) {
      context.missing(_depthMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      depth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depth'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolderRow extends DataClass
    implements Insertable<LibraryFolderRow> {
  final String id;
  final String? parentId;
  final String name;
  final int depth;
  final int createdAt;
  final int sortIndex;
  const LibraryFolderRow({
    required this.id,
    this.parentId,
    required this.name,
    required this.depth,
    required this.createdAt,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['depth'] = Variable<int>(depth);
    map['created_at'] = Variable<int>(createdAt);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      depth: Value(depth),
      createdAt: Value(createdAt),
      sortIndex: Value(sortIndex),
    );
  }

  factory LibraryFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolderRow(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      depth: serializer.fromJson<int>(json['depth']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'depth': serializer.toJson<int>(depth),
      'createdAt': serializer.toJson<int>(createdAt),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  LibraryFolderRow copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? depth,
    int? createdAt,
    int? sortIndex,
  }) => LibraryFolderRow(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    depth: depth ?? this.depth,
    createdAt: createdAt ?? this.createdAt,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  LibraryFolderRow copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolderRow(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      depth: data.depth.present ? data.depth.value : this.depth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolderRow(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('depth: $depth, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, parentId, name, depth, createdAt, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolderRow &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.depth == this.depth &&
          other.createdAt == this.createdAt &&
          other.sortIndex == this.sortIndex);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolderRow> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> depth;
  final Value<int> createdAt;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const LibraryFoldersCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.depth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required int depth,
    required int createdAt,
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       depth = Value(depth),
       createdAt = Value(createdAt);
  static Insertable<LibraryFolderRow> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? depth,
    Expression<int>? createdAt,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (depth != null) 'depth': depth,
      if (createdAt != null) 'created_at': createdAt,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? depth,
    Value<int>? createdAt,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return LibraryFoldersCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(depth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('depth: $depth, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryDocumentsTable extends LibraryDocuments
    with TableInfo<$LibraryDocumentsTable, LibraryDocRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id)',
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
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceToolMeta = const VerificationMeta(
    'sourceTool',
  );
  @override
  late final GeneratedColumn<String> sourceTool = GeneratedColumn<String>(
    'source_tool',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<int> openedAt = GeneratedColumn<int>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<int> expiryDate = GeneratedColumn<int>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderOffsetsMeta = const VerificationMeta(
    'reminderOffsets',
  );
  @override
  late final GeneratedColumn<String> reminderOffsets = GeneratedColumn<String>(
    'reminder_offsets',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _reminderMinuteOfDayMeta =
      const VerificationMeta('reminderMinuteOfDay');
  @override
  late final GeneratedColumn<int> reminderMinuteOfDay = GeneratedColumn<int>(
    'reminder_minute_of_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _indexStateMeta = const VerificationMeta(
    'indexState',
  );
  @override
  late final GeneratedColumn<String> indexState = GeneratedColumn<String>(
    'index_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _indexedAtMeta = const VerificationMeta(
    'indexedAt',
  );
  @override
  late final GeneratedColumn<int> indexedAt = GeneratedColumn<int>(
    'indexed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    name,
    relPath,
    mime,
    sizeBytes,
    pageCount,
    width,
    height,
    sha256,
    source,
    sourceTool,
    addedAt,
    openedAt,
    starred,
    notes,
    expiryDate,
    reminderOffsets,
    reminderMinuteOfDay,
    indexState,
    indexedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryDocRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
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
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_tool')) {
      context.handle(
        _sourceToolMeta,
        sourceTool.isAcceptableOrUnknown(data['source_tool']!, _sourceToolMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('reminder_offsets')) {
      context.handle(
        _reminderOffsetsMeta,
        reminderOffsets.isAcceptableOrUnknown(
          data['reminder_offsets']!,
          _reminderOffsetsMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minute_of_day')) {
      context.handle(
        _reminderMinuteOfDayMeta,
        reminderMinuteOfDay.isAcceptableOrUnknown(
          data['reminder_minute_of_day']!,
          _reminderMinuteOfDayMeta,
        ),
      );
    }
    if (data.containsKey('index_state')) {
      context.handle(
        _indexStateMeta,
        indexState.isAcceptableOrUnknown(data['index_state']!, _indexStateMeta),
      );
    }
    if (data.containsKey('indexed_at')) {
      context.handle(
        _indexedAtMeta,
        indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryDocRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryDocRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceTool: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_tool'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at'],
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expiry_date'],
      ),
      reminderOffsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_offsets'],
      )!,
      reminderMinuteOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minute_of_day'],
      ),
      indexState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}index_state'],
      )!,
      indexedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}indexed_at'],
      ),
    );
  }

  @override
  $LibraryDocumentsTable createAlias(String alias) {
    return $LibraryDocumentsTable(attachedDatabase, alias);
  }
}

class LibraryDocRow extends DataClass implements Insertable<LibraryDocRow> {
  final String id;
  final String? folderId;
  final String name;
  final String relPath;
  final String mime;
  final int sizeBytes;
  final int? pageCount;
  final int? width;
  final int? height;
  final String sha256;
  final String source;
  final String? sourceTool;
  final int addedAt;
  final int? openedAt;
  final bool starred;
  final String notes;
  final int? expiryDate;
  final String reminderOffsets;
  final int? reminderMinuteOfDay;
  final String indexState;
  final int? indexedAt;
  const LibraryDocRow({
    required this.id,
    this.folderId,
    required this.name,
    required this.relPath,
    required this.mime,
    required this.sizeBytes,
    this.pageCount,
    this.width,
    this.height,
    required this.sha256,
    required this.source,
    this.sourceTool,
    required this.addedAt,
    this.openedAt,
    required this.starred,
    required this.notes,
    this.expiryDate,
    required this.reminderOffsets,
    this.reminderMinuteOfDay,
    required this.indexState,
    this.indexedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['name'] = Variable<String>(name);
    map['rel_path'] = Variable<String>(relPath);
    map['mime'] = Variable<String>(mime);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['sha256'] = Variable<String>(sha256);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceTool != null) {
      map['source_tool'] = Variable<String>(sourceTool);
    }
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<int>(openedAt);
    }
    map['starred'] = Variable<bool>(starred);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<int>(expiryDate);
    }
    map['reminder_offsets'] = Variable<String>(reminderOffsets);
    if (!nullToAbsent || reminderMinuteOfDay != null) {
      map['reminder_minute_of_day'] = Variable<int>(reminderMinuteOfDay);
    }
    map['index_state'] = Variable<String>(indexState);
    if (!nullToAbsent || indexedAt != null) {
      map['indexed_at'] = Variable<int>(indexedAt);
    }
    return map;
  }

  LibraryDocumentsCompanion toCompanion(bool nullToAbsent) {
    return LibraryDocumentsCompanion(
      id: Value(id),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      name: Value(name),
      relPath: Value(relPath),
      mime: Value(mime),
      sizeBytes: Value(sizeBytes),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      sha256: Value(sha256),
      source: Value(source),
      sourceTool: sourceTool == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTool),
      addedAt: Value(addedAt),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
      starred: Value(starred),
      notes: Value(notes),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      reminderOffsets: Value(reminderOffsets),
      reminderMinuteOfDay: reminderMinuteOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinuteOfDay),
      indexState: Value(indexState),
      indexedAt: indexedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(indexedAt),
    );
  }

  factory LibraryDocRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryDocRow(
      id: serializer.fromJson<String>(json['id']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      name: serializer.fromJson<String>(json['name']),
      relPath: serializer.fromJson<String>(json['relPath']),
      mime: serializer.fromJson<String>(json['mime']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sha256: serializer.fromJson<String>(json['sha256']),
      source: serializer.fromJson<String>(json['source']),
      sourceTool: serializer.fromJson<String?>(json['sourceTool']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      openedAt: serializer.fromJson<int?>(json['openedAt']),
      starred: serializer.fromJson<bool>(json['starred']),
      notes: serializer.fromJson<String>(json['notes']),
      expiryDate: serializer.fromJson<int?>(json['expiryDate']),
      reminderOffsets: serializer.fromJson<String>(json['reminderOffsets']),
      reminderMinuteOfDay: serializer.fromJson<int?>(
        json['reminderMinuteOfDay'],
      ),
      indexState: serializer.fromJson<String>(json['indexState']),
      indexedAt: serializer.fromJson<int?>(json['indexedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'folderId': serializer.toJson<String?>(folderId),
      'name': serializer.toJson<String>(name),
      'relPath': serializer.toJson<String>(relPath),
      'mime': serializer.toJson<String>(mime),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'pageCount': serializer.toJson<int?>(pageCount),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sha256': serializer.toJson<String>(sha256),
      'source': serializer.toJson<String>(source),
      'sourceTool': serializer.toJson<String?>(sourceTool),
      'addedAt': serializer.toJson<int>(addedAt),
      'openedAt': serializer.toJson<int?>(openedAt),
      'starred': serializer.toJson<bool>(starred),
      'notes': serializer.toJson<String>(notes),
      'expiryDate': serializer.toJson<int?>(expiryDate),
      'reminderOffsets': serializer.toJson<String>(reminderOffsets),
      'reminderMinuteOfDay': serializer.toJson<int?>(reminderMinuteOfDay),
      'indexState': serializer.toJson<String>(indexState),
      'indexedAt': serializer.toJson<int?>(indexedAt),
    };
  }

  LibraryDocRow copyWith({
    String? id,
    Value<String?> folderId = const Value.absent(),
    String? name,
    String? relPath,
    String? mime,
    int? sizeBytes,
    Value<int?> pageCount = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    String? sha256,
    String? source,
    Value<String?> sourceTool = const Value.absent(),
    int? addedAt,
    Value<int?> openedAt = const Value.absent(),
    bool? starred,
    String? notes,
    Value<int?> expiryDate = const Value.absent(),
    String? reminderOffsets,
    Value<int?> reminderMinuteOfDay = const Value.absent(),
    String? indexState,
    Value<int?> indexedAt = const Value.absent(),
  }) => LibraryDocRow(
    id: id ?? this.id,
    folderId: folderId.present ? folderId.value : this.folderId,
    name: name ?? this.name,
    relPath: relPath ?? this.relPath,
    mime: mime ?? this.mime,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    sha256: sha256 ?? this.sha256,
    source: source ?? this.source,
    sourceTool: sourceTool.present ? sourceTool.value : this.sourceTool,
    addedAt: addedAt ?? this.addedAt,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    starred: starred ?? this.starred,
    notes: notes ?? this.notes,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    reminderOffsets: reminderOffsets ?? this.reminderOffsets,
    reminderMinuteOfDay: reminderMinuteOfDay.present
        ? reminderMinuteOfDay.value
        : this.reminderMinuteOfDay,
    indexState: indexState ?? this.indexState,
    indexedAt: indexedAt.present ? indexedAt.value : this.indexedAt,
  );
  LibraryDocRow copyWithCompanion(LibraryDocumentsCompanion data) {
    return LibraryDocRow(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      name: data.name.present ? data.name.value : this.name,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      mime: data.mime.present ? data.mime.value : this.mime,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      source: data.source.present ? data.source.value : this.source,
      sourceTool: data.sourceTool.present
          ? data.sourceTool.value
          : this.sourceTool,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      starred: data.starred.present ? data.starred.value : this.starred,
      notes: data.notes.present ? data.notes.value : this.notes,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      reminderOffsets: data.reminderOffsets.present
          ? data.reminderOffsets.value
          : this.reminderOffsets,
      reminderMinuteOfDay: data.reminderMinuteOfDay.present
          ? data.reminderMinuteOfDay.value
          : this.reminderMinuteOfDay,
      indexState: data.indexState.present
          ? data.indexState.value
          : this.indexState,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryDocRow(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256, ')
          ..write('source: $source, ')
          ..write('sourceTool: $sourceTool, ')
          ..write('addedAt: $addedAt, ')
          ..write('openedAt: $openedAt, ')
          ..write('starred: $starred, ')
          ..write('notes: $notes, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('reminderOffsets: $reminderOffsets, ')
          ..write('reminderMinuteOfDay: $reminderMinuteOfDay, ')
          ..write('indexState: $indexState, ')
          ..write('indexedAt: $indexedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    folderId,
    name,
    relPath,
    mime,
    sizeBytes,
    pageCount,
    width,
    height,
    sha256,
    source,
    sourceTool,
    addedAt,
    openedAt,
    starred,
    notes,
    expiryDate,
    reminderOffsets,
    reminderMinuteOfDay,
    indexState,
    indexedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryDocRow &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.name == this.name &&
          other.relPath == this.relPath &&
          other.mime == this.mime &&
          other.sizeBytes == this.sizeBytes &&
          other.pageCount == this.pageCount &&
          other.width == this.width &&
          other.height == this.height &&
          other.sha256 == this.sha256 &&
          other.source == this.source &&
          other.sourceTool == this.sourceTool &&
          other.addedAt == this.addedAt &&
          other.openedAt == this.openedAt &&
          other.starred == this.starred &&
          other.notes == this.notes &&
          other.expiryDate == this.expiryDate &&
          other.reminderOffsets == this.reminderOffsets &&
          other.reminderMinuteOfDay == this.reminderMinuteOfDay &&
          other.indexState == this.indexState &&
          other.indexedAt == this.indexedAt);
}

class LibraryDocumentsCompanion extends UpdateCompanion<LibraryDocRow> {
  final Value<String> id;
  final Value<String?> folderId;
  final Value<String> name;
  final Value<String> relPath;
  final Value<String> mime;
  final Value<int> sizeBytes;
  final Value<int?> pageCount;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String> sha256;
  final Value<String> source;
  final Value<String?> sourceTool;
  final Value<int> addedAt;
  final Value<int?> openedAt;
  final Value<bool> starred;
  final Value<String> notes;
  final Value<int?> expiryDate;
  final Value<String> reminderOffsets;
  final Value<int?> reminderMinuteOfDay;
  final Value<String> indexState;
  final Value<int?> indexedAt;
  final Value<int> rowid;
  const LibraryDocumentsCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.relPath = const Value.absent(),
    this.mime = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceTool = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.starred = const Value.absent(),
    this.notes = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.reminderOffsets = const Value.absent(),
    this.reminderMinuteOfDay = const Value.absent(),
    this.indexState = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryDocumentsCompanion.insert({
    required String id,
    this.folderId = const Value.absent(),
    required String name,
    required String relPath,
    required String mime,
    required int sizeBytes,
    this.pageCount = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required String sha256,
    required String source,
    this.sourceTool = const Value.absent(),
    required int addedAt,
    this.openedAt = const Value.absent(),
    this.starred = const Value.absent(),
    this.notes = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.reminderOffsets = const Value.absent(),
    this.reminderMinuteOfDay = const Value.absent(),
    this.indexState = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       relPath = Value(relPath),
       mime = Value(mime),
       sizeBytes = Value(sizeBytes),
       sha256 = Value(sha256),
       source = Value(source),
       addedAt = Value(addedAt);
  static Insertable<LibraryDocRow> custom({
    Expression<String>? id,
    Expression<String>? folderId,
    Expression<String>? name,
    Expression<String>? relPath,
    Expression<String>? mime,
    Expression<int>? sizeBytes,
    Expression<int>? pageCount,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? sha256,
    Expression<String>? source,
    Expression<String>? sourceTool,
    Expression<int>? addedAt,
    Expression<int>? openedAt,
    Expression<bool>? starred,
    Expression<String>? notes,
    Expression<int>? expiryDate,
    Expression<String>? reminderOffsets,
    Expression<int>? reminderMinuteOfDay,
    Expression<String>? indexState,
    Expression<int>? indexedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (name != null) 'name': name,
      if (relPath != null) 'rel_path': relPath,
      if (mime != null) 'mime': mime,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (pageCount != null) 'page_count': pageCount,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sha256 != null) 'sha256': sha256,
      if (source != null) 'source': source,
      if (sourceTool != null) 'source_tool': sourceTool,
      if (addedAt != null) 'added_at': addedAt,
      if (openedAt != null) 'opened_at': openedAt,
      if (starred != null) 'starred': starred,
      if (notes != null) 'notes': notes,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (reminderOffsets != null) 'reminder_offsets': reminderOffsets,
      if (reminderMinuteOfDay != null)
        'reminder_minute_of_day': reminderMinuteOfDay,
      if (indexState != null) 'index_state': indexState,
      if (indexedAt != null) 'indexed_at': indexedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? folderId,
    Value<String>? name,
    Value<String>? relPath,
    Value<String>? mime,
    Value<int>? sizeBytes,
    Value<int?>? pageCount,
    Value<int?>? width,
    Value<int?>? height,
    Value<String>? sha256,
    Value<String>? source,
    Value<String?>? sourceTool,
    Value<int>? addedAt,
    Value<int?>? openedAt,
    Value<bool>? starred,
    Value<String>? notes,
    Value<int?>? expiryDate,
    Value<String>? reminderOffsets,
    Value<int?>? reminderMinuteOfDay,
    Value<String>? indexState,
    Value<int?>? indexedAt,
    Value<int>? rowid,
  }) {
    return LibraryDocumentsCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      relPath: relPath ?? this.relPath,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pageCount: pageCount ?? this.pageCount,
      width: width ?? this.width,
      height: height ?? this.height,
      sha256: sha256 ?? this.sha256,
      source: source ?? this.source,
      sourceTool: sourceTool ?? this.sourceTool,
      addedAt: addedAt ?? this.addedAt,
      openedAt: openedAt ?? this.openedAt,
      starred: starred ?? this.starred,
      notes: notes ?? this.notes,
      expiryDate: expiryDate ?? this.expiryDate,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      reminderMinuteOfDay: reminderMinuteOfDay ?? this.reminderMinuteOfDay,
      indexState: indexState ?? this.indexState,
      indexedAt: indexedAt ?? this.indexedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceTool.present) {
      map['source_tool'] = Variable<String>(sourceTool.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<int>(openedAt.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<int>(expiryDate.value);
    }
    if (reminderOffsets.present) {
      map['reminder_offsets'] = Variable<String>(reminderOffsets.value);
    }
    if (reminderMinuteOfDay.present) {
      map['reminder_minute_of_day'] = Variable<int>(reminderMinuteOfDay.value);
    }
    if (indexState.present) {
      map['index_state'] = Variable<String>(indexState.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<int>(indexedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256, ')
          ..write('source: $source, ')
          ..write('sourceTool: $sourceTool, ')
          ..write('addedAt: $addedAt, ')
          ..write('openedAt: $openedAt, ')
          ..write('starred: $starred, ')
          ..write('notes: $notes, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('reminderOffsets: $reminderOffsets, ')
          ..write('reminderMinuteOfDay: $reminderMinuteOfDay, ')
          ..write('indexState: $indexState, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryTagsTable extends LibraryTags
    with TableInfo<$LibraryTagsTable, LibraryTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _docIdMeta = const VerificationMeta('docId');
  @override
  late final GeneratedColumn<String> docId = GeneratedColumn<String>(
    'doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [docId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('doc_id')) {
      context.handle(
        _docIdMeta,
        docId.isAcceptableOrUnknown(data['doc_id']!, _docIdMeta),
      );
    } else if (isInserting) {
      context.missing(_docIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {docId, tag};
  @override
  LibraryTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTagRow(
      docId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $LibraryTagsTable createAlias(String alias) {
    return $LibraryTagsTable(attachedDatabase, alias);
  }
}

class LibraryTagRow extends DataClass implements Insertable<LibraryTagRow> {
  final String docId;
  final String tag;
  const LibraryTagRow({required this.docId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['doc_id'] = Variable<String>(docId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  LibraryTagsCompanion toCompanion(bool nullToAbsent) {
    return LibraryTagsCompanion(docId: Value(docId), tag: Value(tag));
  }

  factory LibraryTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTagRow(
      docId: serializer.fromJson<String>(json['docId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'docId': serializer.toJson<String>(docId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  LibraryTagRow copyWith({String? docId, String? tag}) =>
      LibraryTagRow(docId: docId ?? this.docId, tag: tag ?? this.tag);
  LibraryTagRow copyWithCompanion(LibraryTagsCompanion data) {
    return LibraryTagRow(
      docId: data.docId.present ? data.docId.value : this.docId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTagRow(')
          ..write('docId: $docId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(docId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTagRow &&
          other.docId == this.docId &&
          other.tag == this.tag);
}

class LibraryTagsCompanion extends UpdateCompanion<LibraryTagRow> {
  final Value<String> docId;
  final Value<String> tag;
  final Value<int> rowid;
  const LibraryTagsCompanion({
    this.docId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryTagsCompanion.insert({
    required String docId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : docId = Value(docId),
       tag = Value(tag);
  static Insertable<LibraryTagRow> custom({
    Expression<String>? docId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (docId != null) 'doc_id': docId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryTagsCompanion copyWith({
    Value<String>? docId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return LibraryTagsCompanion(
      docId: docId ?? this.docId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (docId.present) {
      map['doc_id'] = Variable<String>(docId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTagsCompanion(')
          ..write('docId: $docId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OperationsTable operations = $OperationsTable(this);
  late final $OperationInputsTable operationInputs = $OperationInputsTable(
    this,
  );
  late final $OperationOutputsTable operationOutputs = $OperationOutputsTable(
    this,
  );
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $LibraryDocumentsTable libraryDocuments = $LibraryDocumentsTable(
    this,
  );
  late final $LibraryTagsTable libraryTags = $LibraryTagsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    operations,
    operationInputs,
    operationOutputs,
    libraryFolders,
    libraryDocuments,
    libraryTags,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'operations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('operation_inputs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'operations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('operation_outputs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$OperationsTableCreateCompanionBuilder =
    OperationsCompanion Function({
      required String id,
      required String tool,
      required String status,
      Value<String?> errorCode,
      required int createdAt,
      Value<int?> finishedAt,
      Value<int?> durationMs,
      required int inputCount,
      required int inputTotalBytes,
      Value<String?> outputName,
      Value<String?> outputMime,
      Value<int?> outputBytes,
      Value<String?> outputRelPath,
      Value<String?> outputMetaJson,
      Value<String?> optionsJson,
      Value<bool> savedExternally,
      Value<int?> outputDeletedAt,
      Value<int> outputCount,
      Value<int> failedCount,
      Value<String?> zipRelPath,
      Value<int> rowid,
    });
typedef $$OperationsTableUpdateCompanionBuilder =
    OperationsCompanion Function({
      Value<String> id,
      Value<String> tool,
      Value<String> status,
      Value<String?> errorCode,
      Value<int> createdAt,
      Value<int?> finishedAt,
      Value<int?> durationMs,
      Value<int> inputCount,
      Value<int> inputTotalBytes,
      Value<String?> outputName,
      Value<String?> outputMime,
      Value<int?> outputBytes,
      Value<String?> outputRelPath,
      Value<String?> outputMetaJson,
      Value<String?> optionsJson,
      Value<bool> savedExternally,
      Value<int?> outputDeletedAt,
      Value<int> outputCount,
      Value<int> failedCount,
      Value<String?> zipRelPath,
      Value<int> rowid,
    });

final class $$OperationsTableReferences
    extends BaseReferences<_$AppDatabase, $OperationsTable, OperationRow> {
  $$OperationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OperationInputsTable, List<OperationInputRow>>
  _operationInputsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.operationInputs,
    aliasName: 'operations__id__operation_inputs__operation_id',
  );

  $$OperationInputsTableProcessedTableManager get operationInputsRefs {
    final manager = $$OperationInputsTableTableManager(
      $_db,
      $_db.operationInputs,
    ).filter((f) => f.operationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _operationInputsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OperationOutputsTable, List<OperationOutputRow>>
  _operationOutputsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.operationOutputs,
    aliasName: 'operations__id__operation_outputs__operation_id',
  );

  $$OperationOutputsTableProcessedTableManager get operationOutputsRefs {
    final manager = $$OperationOutputsTableTableManager(
      $_db,
      $_db.operationOutputs,
    ).filter((f) => f.operationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _operationOutputsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OperationsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationsTable> {
  $$OperationsTableFilterComposer({
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

  ColumnFilters<String> get tool => $composableBuilder(
    column: $table.tool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputCount => $composableBuilder(
    column: $table.inputCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTotalBytes => $composableBuilder(
    column: $table.inputTotalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputName => $composableBuilder(
    column: $table.outputName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputMime => $composableBuilder(
    column: $table.outputMime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputBytes => $composableBuilder(
    column: $table.outputBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputMetaJson => $composableBuilder(
    column: $table.outputMetaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get savedExternally => $composableBuilder(
    column: $table.savedExternally,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputDeletedAt => $composableBuilder(
    column: $table.outputDeletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputCount => $composableBuilder(
    column: $table.outputCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zipRelPath => $composableBuilder(
    column: $table.zipRelPath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> operationInputsRefs(
    Expression<bool> Function($$OperationInputsTableFilterComposer f) f,
  ) {
    final $$OperationInputsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationInputs,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationInputsTableFilterComposer(
            $db: $db,
            $table: $db.operationInputs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> operationOutputsRefs(
    Expression<bool> Function($$OperationOutputsTableFilterComposer f) f,
  ) {
    final $$OperationOutputsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationOutputs,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationOutputsTableFilterComposer(
            $db: $db,
            $table: $db.operationOutputs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationsTable> {
  $$OperationsTableOrderingComposer({
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

  ColumnOrderings<String> get tool => $composableBuilder(
    column: $table.tool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputCount => $composableBuilder(
    column: $table.inputCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTotalBytes => $composableBuilder(
    column: $table.inputTotalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputName => $composableBuilder(
    column: $table.outputName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputMime => $composableBuilder(
    column: $table.outputMime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputBytes => $composableBuilder(
    column: $table.outputBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputMetaJson => $composableBuilder(
    column: $table.outputMetaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get savedExternally => $composableBuilder(
    column: $table.savedExternally,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputDeletedAt => $composableBuilder(
    column: $table.outputDeletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputCount => $composableBuilder(
    column: $table.outputCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zipRelPath => $composableBuilder(
    column: $table.zipRelPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationsTable> {
  $$OperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tool =>
      $composableBuilder(column: $table.tool, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputCount => $composableBuilder(
    column: $table.inputCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTotalBytes => $composableBuilder(
    column: $table.inputTotalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputName => $composableBuilder(
    column: $table.outputName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputMime => $composableBuilder(
    column: $table.outputMime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputBytes => $composableBuilder(
    column: $table.outputBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputMetaJson => $composableBuilder(
    column: $table.outputMetaJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get savedExternally => $composableBuilder(
    column: $table.savedExternally,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputDeletedAt => $composableBuilder(
    column: $table.outputDeletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputCount => $composableBuilder(
    column: $table.outputCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zipRelPath => $composableBuilder(
    column: $table.zipRelPath,
    builder: (column) => column,
  );

  Expression<T> operationInputsRefs<T extends Object>(
    Expression<T> Function($$OperationInputsTableAnnotationComposer a) f,
  ) {
    final $$OperationInputsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationInputs,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationInputsTableAnnotationComposer(
            $db: $db,
            $table: $db.operationInputs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> operationOutputsRefs<T extends Object>(
    Expression<T> Function($$OperationOutputsTableAnnotationComposer a) f,
  ) {
    final $$OperationOutputsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationOutputs,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationOutputsTableAnnotationComposer(
            $db: $db,
            $table: $db.operationOutputs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationsTable,
          OperationRow,
          $$OperationsTableFilterComposer,
          $$OperationsTableOrderingComposer,
          $$OperationsTableAnnotationComposer,
          $$OperationsTableCreateCompanionBuilder,
          $$OperationsTableUpdateCompanionBuilder,
          (OperationRow, $$OperationsTableReferences),
          OperationRow,
          PrefetchHooks Function({
            bool operationInputsRefs,
            bool operationOutputsRefs,
          })
        > {
  $$OperationsTableTableManager(_$AppDatabase db, $OperationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tool = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> inputCount = const Value.absent(),
                Value<int> inputTotalBytes = const Value.absent(),
                Value<String?> outputName = const Value.absent(),
                Value<String?> outputMime = const Value.absent(),
                Value<int?> outputBytes = const Value.absent(),
                Value<String?> outputRelPath = const Value.absent(),
                Value<String?> outputMetaJson = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
                Value<bool> savedExternally = const Value.absent(),
                Value<int?> outputDeletedAt = const Value.absent(),
                Value<int> outputCount = const Value.absent(),
                Value<int> failedCount = const Value.absent(),
                Value<String?> zipRelPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion(
                id: id,
                tool: tool,
                status: status,
                errorCode: errorCode,
                createdAt: createdAt,
                finishedAt: finishedAt,
                durationMs: durationMs,
                inputCount: inputCount,
                inputTotalBytes: inputTotalBytes,
                outputName: outputName,
                outputMime: outputMime,
                outputBytes: outputBytes,
                outputRelPath: outputRelPath,
                outputMetaJson: outputMetaJson,
                optionsJson: optionsJson,
                savedExternally: savedExternally,
                outputDeletedAt: outputDeletedAt,
                outputCount: outputCount,
                failedCount: failedCount,
                zipRelPath: zipRelPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tool,
                required String status,
                Value<String?> errorCode = const Value.absent(),
                required int createdAt,
                Value<int?> finishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int inputCount,
                required int inputTotalBytes,
                Value<String?> outputName = const Value.absent(),
                Value<String?> outputMime = const Value.absent(),
                Value<int?> outputBytes = const Value.absent(),
                Value<String?> outputRelPath = const Value.absent(),
                Value<String?> outputMetaJson = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
                Value<bool> savedExternally = const Value.absent(),
                Value<int?> outputDeletedAt = const Value.absent(),
                Value<int> outputCount = const Value.absent(),
                Value<int> failedCount = const Value.absent(),
                Value<String?> zipRelPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion.insert(
                id: id,
                tool: tool,
                status: status,
                errorCode: errorCode,
                createdAt: createdAt,
                finishedAt: finishedAt,
                durationMs: durationMs,
                inputCount: inputCount,
                inputTotalBytes: inputTotalBytes,
                outputName: outputName,
                outputMime: outputMime,
                outputBytes: outputBytes,
                outputRelPath: outputRelPath,
                outputMetaJson: outputMetaJson,
                optionsJson: optionsJson,
                savedExternally: savedExternally,
                outputDeletedAt: outputDeletedAt,
                outputCount: outputCount,
                failedCount: failedCount,
                zipRelPath: zipRelPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OperationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({operationInputsRefs = false, operationOutputsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (operationInputsRefs) db.operationInputs,
                    if (operationOutputsRefs) db.operationOutputs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (operationInputsRefs)
                        await $_getPrefetchedData<
                          OperationRow,
                          $OperationsTable,
                          OperationInputRow
                        >(
                          currentTable: table,
                          referencedTable: $$OperationsTableReferences
                              ._operationInputsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OperationsTableReferences(
                                db,
                                table,
                                p0,
                              ).operationInputsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.operationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (operationOutputsRefs)
                        await $_getPrefetchedData<
                          OperationRow,
                          $OperationsTable,
                          OperationOutputRow
                        >(
                          currentTable: table,
                          referencedTable: $$OperationsTableReferences
                              ._operationOutputsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OperationsTableReferences(
                                db,
                                table,
                                p0,
                              ).operationOutputsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.operationId == item.id,
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

typedef $$OperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationsTable,
      OperationRow,
      $$OperationsTableFilterComposer,
      $$OperationsTableOrderingComposer,
      $$OperationsTableAnnotationComposer,
      $$OperationsTableCreateCompanionBuilder,
      $$OperationsTableUpdateCompanionBuilder,
      (OperationRow, $$OperationsTableReferences),
      OperationRow,
      PrefetchHooks Function({
        bool operationInputsRefs,
        bool operationOutputsRefs,
      })
    >;
typedef $$OperationInputsTableCreateCompanionBuilder =
    OperationInputsCompanion Function({
      required String operationId,
      required int position,
      required String displayName,
      required String mime,
      required int sizeBytes,
      Value<String?> metaJson,
      Value<int> rowid,
    });
typedef $$OperationInputsTableUpdateCompanionBuilder =
    OperationInputsCompanion Function({
      Value<String> operationId,
      Value<int> position,
      Value<String> displayName,
      Value<String> mime,
      Value<int> sizeBytes,
      Value<String?> metaJson,
      Value<int> rowid,
    });

final class $$OperationInputsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OperationInputsTable,
          OperationInputRow
        > {
  $$OperationInputsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $OperationsTable _operationIdTable(_$AppDatabase db) => db.operations
      .createAlias('operation_inputs__operation_id__operations__id');

  $$OperationsTableProcessedTableManager get operationId {
    final $_column = $_itemColumn<String>('operation_id')!;

    final manager = $$OperationsTableTableManager(
      $_db,
      $_db.operations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OperationInputsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationInputsTable> {
  $$OperationInputsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  $$OperationsTableFilterComposer get operationId {
    final $$OperationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationInputsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationInputsTable> {
  $$OperationInputsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$OperationsTableOrderingComposer get operationId {
    final $$OperationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationInputsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationInputsTable> {
  $$OperationInputsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  $$OperationsTableAnnotationComposer get operationId {
    final $$OperationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationInputsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationInputsTable,
          OperationInputRow,
          $$OperationInputsTableFilterComposer,
          $$OperationInputsTableOrderingComposer,
          $$OperationInputsTableAnnotationComposer,
          $$OperationInputsTableCreateCompanionBuilder,
          $$OperationInputsTableUpdateCompanionBuilder,
          (OperationInputRow, $$OperationInputsTableReferences),
          OperationInputRow,
          PrefetchHooks Function({bool operationId})
        > {
  $$OperationInputsTableTableManager(
    _$AppDatabase db,
    $OperationInputsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationInputsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationInputsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationInputsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationInputsCompanion(
                operationId: operationId,
                position: position,
                displayName: displayName,
                mime: mime,
                sizeBytes: sizeBytes,
                metaJson: metaJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required int position,
                required String displayName,
                required String mime,
                required int sizeBytes,
                Value<String?> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationInputsCompanion.insert(
                operationId: operationId,
                position: position,
                displayName: displayName,
                mime: mime,
                sizeBytes: sizeBytes,
                metaJson: metaJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OperationInputsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({operationId = false}) {
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
                    if (operationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.operationId,
                                referencedTable:
                                    $$OperationInputsTableReferences
                                        ._operationIdTable(db),
                                referencedColumn:
                                    $$OperationInputsTableReferences
                                        ._operationIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$OperationInputsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationInputsTable,
      OperationInputRow,
      $$OperationInputsTableFilterComposer,
      $$OperationInputsTableOrderingComposer,
      $$OperationInputsTableAnnotationComposer,
      $$OperationInputsTableCreateCompanionBuilder,
      $$OperationInputsTableUpdateCompanionBuilder,
      (OperationInputRow, $$OperationInputsTableReferences),
      OperationInputRow,
      PrefetchHooks Function({bool operationId})
    >;
typedef $$OperationOutputsTableCreateCompanionBuilder =
    OperationOutputsCompanion Function({
      required String operationId,
      required int position,
      required String displayName,
      Value<String?> relPath,
      Value<int?> sizeBytes,
      Value<int?> beforeBytes,
      Value<String?> errorCode,
      Value<String?> metaJson,
      Value<int> rowid,
    });
typedef $$OperationOutputsTableUpdateCompanionBuilder =
    OperationOutputsCompanion Function({
      Value<String> operationId,
      Value<int> position,
      Value<String> displayName,
      Value<String?> relPath,
      Value<int?> sizeBytes,
      Value<int?> beforeBytes,
      Value<String?> errorCode,
      Value<String?> metaJson,
      Value<int> rowid,
    });

final class $$OperationOutputsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OperationOutputsTable,
          OperationOutputRow
        > {
  $$OperationOutputsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $OperationsTable _operationIdTable(_$AppDatabase db) => db.operations
      .createAlias('operation_outputs__operation_id__operations__id');

  $$OperationsTableProcessedTableManager get operationId {
    final $_column = $_itemColumn<String>('operation_id')!;

    final manager = $$OperationsTableTableManager(
      $_db,
      $_db.operations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OperationOutputsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationOutputsTable> {
  $$OperationOutputsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beforeBytes => $composableBuilder(
    column: $table.beforeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  $$OperationsTableFilterComposer get operationId {
    final $$OperationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationOutputsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationOutputsTable> {
  $$OperationOutputsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beforeBytes => $composableBuilder(
    column: $table.beforeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$OperationsTableOrderingComposer get operationId {
    final $$OperationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationOutputsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationOutputsTable> {
  $$OperationOutputsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get beforeBytes => $composableBuilder(
    column: $table.beforeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  $$OperationsTableAnnotationComposer get operationId {
    final $$OperationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationOutputsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationOutputsTable,
          OperationOutputRow,
          $$OperationOutputsTableFilterComposer,
          $$OperationOutputsTableOrderingComposer,
          $$OperationOutputsTableAnnotationComposer,
          $$OperationOutputsTableCreateCompanionBuilder,
          $$OperationOutputsTableUpdateCompanionBuilder,
          (OperationOutputRow, $$OperationOutputsTableReferences),
          OperationOutputRow,
          PrefetchHooks Function({bool operationId})
        > {
  $$OperationOutputsTableTableManager(
    _$AppDatabase db,
    $OperationOutputsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationOutputsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationOutputsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationOutputsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> relPath = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> beforeBytes = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationOutputsCompanion(
                operationId: operationId,
                position: position,
                displayName: displayName,
                relPath: relPath,
                sizeBytes: sizeBytes,
                beforeBytes: beforeBytes,
                errorCode: errorCode,
                metaJson: metaJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required int position,
                required String displayName,
                Value<String?> relPath = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> beforeBytes = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationOutputsCompanion.insert(
                operationId: operationId,
                position: position,
                displayName: displayName,
                relPath: relPath,
                sizeBytes: sizeBytes,
                beforeBytes: beforeBytes,
                errorCode: errorCode,
                metaJson: metaJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OperationOutputsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({operationId = false}) {
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
                    if (operationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.operationId,
                                referencedTable:
                                    $$OperationOutputsTableReferences
                                        ._operationIdTable(db),
                                referencedColumn:
                                    $$OperationOutputsTableReferences
                                        ._operationIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$OperationOutputsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationOutputsTable,
      OperationOutputRow,
      $$OperationOutputsTableFilterComposer,
      $$OperationOutputsTableOrderingComposer,
      $$OperationOutputsTableAnnotationComposer,
      $$OperationOutputsTableCreateCompanionBuilder,
      $$OperationOutputsTableUpdateCompanionBuilder,
      (OperationOutputRow, $$OperationOutputsTableReferences),
      OperationOutputRow,
      PrefetchHooks Function({bool operationId})
    >;
typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      required int depth,
      required int createdAt,
      Value<int> sortIndex,
      Value<int> rowid,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<int> depth,
      Value<int> createdAt,
      Value<int> sortIndex,
      Value<int> rowid,
    });

final class $$LibraryFoldersTableReferences
    extends
        BaseReferences<_$AppDatabase, $LibraryFoldersTable, LibraryFolderRow> {
  $$LibraryFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryFoldersTable _parentIdTable(_$AppDatabase db) => db
      .libraryFolders
      .createAlias('library_folders__parent_id__library_folders__id');

  $$LibraryFoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryDocumentsTable, List<LibraryDocRow>>
  _libraryDocumentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryDocuments,
    aliasName: 'library_folders__id__library_documents__folder_id',
  );

  $$LibraryDocumentsTableProcessedTableManager get libraryDocumentsRefs {
    final manager = $$LibraryDocumentsTableTableManager(
      $_db,
      $_db.libraryDocuments,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get parentId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryDocumentsRefs(
    Expression<bool> Function($$LibraryDocumentsTableFilterComposer f) f,
  ) {
    final $$LibraryDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryDocuments,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.libraryDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get parentId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$LibraryFoldersTableAnnotationComposer get parentId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryDocumentsRefs<T extends Object>(
    Expression<T> Function($$LibraryDocumentsTableAnnotationComposer a) f,
  ) {
    final $$LibraryDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryDocuments,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryFoldersTable,
          LibraryFolderRow,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (LibraryFolderRow, $$LibraryFoldersTableReferences),
          LibraryFolderRow,
          PrefetchHooks Function({bool parentId, bool libraryDocumentsRefs})
        > {
  $$LibraryFoldersTableTableManager(
    _$AppDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> depth = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion(
                id: id,
                parentId: parentId,
                name: name,
                depth: depth,
                createdAt: createdAt,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required int depth,
                required int createdAt,
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                depth: depth,
                createdAt: createdAt,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({parentId = false, libraryDocumentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryDocumentsRefs) db.libraryDocuments,
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
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable:
                                        $$LibraryFoldersTableReferences
                                            ._parentIdTable(db),
                                    referencedColumn:
                                        $$LibraryFoldersTableReferences
                                            ._parentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryDocumentsRefs)
                        await $_getPrefetchedData<
                          LibraryFolderRow,
                          $LibraryFoldersTable,
                          LibraryDocRow
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryFoldersTableReferences
                              ._libraryDocumentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryFoldersTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryDocumentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderId == item.id,
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

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryFoldersTable,
      LibraryFolderRow,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (LibraryFolderRow, $$LibraryFoldersTableReferences),
      LibraryFolderRow,
      PrefetchHooks Function({bool parentId, bool libraryDocumentsRefs})
    >;
typedef $$LibraryDocumentsTableCreateCompanionBuilder =
    LibraryDocumentsCompanion Function({
      required String id,
      Value<String?> folderId,
      required String name,
      required String relPath,
      required String mime,
      required int sizeBytes,
      Value<int?> pageCount,
      Value<int?> width,
      Value<int?> height,
      required String sha256,
      required String source,
      Value<String?> sourceTool,
      required int addedAt,
      Value<int?> openedAt,
      Value<bool> starred,
      Value<String> notes,
      Value<int?> expiryDate,
      Value<String> reminderOffsets,
      Value<int?> reminderMinuteOfDay,
      Value<String> indexState,
      Value<int?> indexedAt,
      Value<int> rowid,
    });
typedef $$LibraryDocumentsTableUpdateCompanionBuilder =
    LibraryDocumentsCompanion Function({
      Value<String> id,
      Value<String?> folderId,
      Value<String> name,
      Value<String> relPath,
      Value<String> mime,
      Value<int> sizeBytes,
      Value<int?> pageCount,
      Value<int?> width,
      Value<int?> height,
      Value<String> sha256,
      Value<String> source,
      Value<String?> sourceTool,
      Value<int> addedAt,
      Value<int?> openedAt,
      Value<bool> starred,
      Value<String> notes,
      Value<int?> expiryDate,
      Value<String> reminderOffsets,
      Value<int?> reminderMinuteOfDay,
      Value<String> indexState,
      Value<int?> indexedAt,
      Value<int> rowid,
    });

final class $$LibraryDocumentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LibraryDocumentsTable, LibraryDocRow> {
  $$LibraryDocumentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryFoldersTable _folderIdTable(_$AppDatabase db) => db
      .libraryFolders
      .createAlias('library_documents__folder_id__library_folders__id');

  $$LibraryFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryTagsTable, List<LibraryTagRow>>
  _libraryTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryTags,
    aliasName: 'library_documents__id__library_tags__doc_id',
  );

  $$LibraryTagsTableProcessedTableManager get libraryTagsRefs {
    final manager = $$LibraryTagsTableTableManager(
      $_db,
      $_db.libraryTags,
    ).filter((f) => f.docId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryDocumentsTable> {
  $$LibraryDocumentsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTool => $composableBuilder(
    column: $table.sourceTool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get folderId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryTagsRefs(
    Expression<bool> Function($$LibraryTagsTableFilterComposer f) f,
  ) {
    final $$LibraryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTags,
      getReferencedColumn: (t) => t.docId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTagsTableFilterComposer(
            $db: $db,
            $table: $db.libraryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryDocumentsTable> {
  $$LibraryDocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTool => $composableBuilder(
    column: $table.sourceTool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get folderId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryDocumentsTable> {
  $$LibraryDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceTool => $composableBuilder(
    column: $table.sourceTool,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  $$LibraryFoldersTableAnnotationComposer get folderId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryTagsRefs<T extends Object>(
    Expression<T> Function($$LibraryTagsTableAnnotationComposer a) f,
  ) {
    final $$LibraryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTags,
      getReferencedColumn: (t) => t.docId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryDocumentsTable,
          LibraryDocRow,
          $$LibraryDocumentsTableFilterComposer,
          $$LibraryDocumentsTableOrderingComposer,
          $$LibraryDocumentsTableAnnotationComposer,
          $$LibraryDocumentsTableCreateCompanionBuilder,
          $$LibraryDocumentsTableUpdateCompanionBuilder,
          (LibraryDocRow, $$LibraryDocumentsTableReferences),
          LibraryDocRow,
          PrefetchHooks Function({bool folderId, bool libraryTagsRefs})
        > {
  $$LibraryDocumentsTableTableManager(
    _$AppDatabase db,
    $LibraryDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceTool = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int?> openedAt = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int?> expiryDate = const Value.absent(),
                Value<String> reminderOffsets = const Value.absent(),
                Value<int?> reminderMinuteOfDay = const Value.absent(),
                Value<String> indexState = const Value.absent(),
                Value<int?> indexedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryDocumentsCompanion(
                id: id,
                folderId: folderId,
                name: name,
                relPath: relPath,
                mime: mime,
                sizeBytes: sizeBytes,
                pageCount: pageCount,
                width: width,
                height: height,
                sha256: sha256,
                source: source,
                sourceTool: sourceTool,
                addedAt: addedAt,
                openedAt: openedAt,
                starred: starred,
                notes: notes,
                expiryDate: expiryDate,
                reminderOffsets: reminderOffsets,
                reminderMinuteOfDay: reminderMinuteOfDay,
                indexState: indexState,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> folderId = const Value.absent(),
                required String name,
                required String relPath,
                required String mime,
                required int sizeBytes,
                Value<int?> pageCount = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required String sha256,
                required String source,
                Value<String?> sourceTool = const Value.absent(),
                required int addedAt,
                Value<int?> openedAt = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int?> expiryDate = const Value.absent(),
                Value<String> reminderOffsets = const Value.absent(),
                Value<int?> reminderMinuteOfDay = const Value.absent(),
                Value<String> indexState = const Value.absent(),
                Value<int?> indexedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryDocumentsCompanion.insert(
                id: id,
                folderId: folderId,
                name: name,
                relPath: relPath,
                mime: mime,
                sizeBytes: sizeBytes,
                pageCount: pageCount,
                width: width,
                height: height,
                sha256: sha256,
                source: source,
                sourceTool: sourceTool,
                addedAt: addedAt,
                openedAt: openedAt,
                starred: starred,
                notes: notes,
                expiryDate: expiryDate,
                reminderOffsets: reminderOffsets,
                reminderMinuteOfDay: reminderMinuteOfDay,
                indexState: indexState,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryDocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, libraryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (libraryTagsRefs) db.libraryTags],
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
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable:
                                    $$LibraryDocumentsTableReferences
                                        ._folderIdTable(db),
                                referencedColumn:
                                    $$LibraryDocumentsTableReferences
                                        ._folderIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (libraryTagsRefs)
                    await $_getPrefetchedData<
                      LibraryDocRow,
                      $LibraryDocumentsTable,
                      LibraryTagRow
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryDocumentsTableReferences
                          ._libraryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryDocumentsTableReferences(
                            db,
                            table,
                            p0,
                          ).libraryTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.docId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryDocumentsTable,
      LibraryDocRow,
      $$LibraryDocumentsTableFilterComposer,
      $$LibraryDocumentsTableOrderingComposer,
      $$LibraryDocumentsTableAnnotationComposer,
      $$LibraryDocumentsTableCreateCompanionBuilder,
      $$LibraryDocumentsTableUpdateCompanionBuilder,
      (LibraryDocRow, $$LibraryDocumentsTableReferences),
      LibraryDocRow,
      PrefetchHooks Function({bool folderId, bool libraryTagsRefs})
    >;
typedef $$LibraryTagsTableCreateCompanionBuilder =
    LibraryTagsCompanion Function({
      required String docId,
      required String tag,
      Value<int> rowid,
    });
typedef $$LibraryTagsTableUpdateCompanionBuilder =
    LibraryTagsCompanion Function({
      Value<String> docId,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$LibraryTagsTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryTagsTable, LibraryTagRow> {
  $$LibraryTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryDocumentsTable _docIdTable(_$AppDatabase db) => db
      .libraryDocuments
      .createAlias('library_tags__doc_id__library_documents__id');

  $$LibraryDocumentsTableProcessedTableManager get docId {
    final $_column = $_itemColumn<String>('doc_id')!;

    final manager = $$LibraryDocumentsTableTableManager(
      $_db,
      $_db.libraryDocuments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_docIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibraryTagsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryTagsTable> {
  $$LibraryTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryDocumentsTableFilterComposer get docId {
    final $$LibraryDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.docId,
      referencedTable: $db.libraryDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.libraryDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryTagsTable> {
  $$LibraryTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryDocumentsTableOrderingComposer get docId {
    final $$LibraryDocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.docId,
      referencedTable: $db.libraryDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryDocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryTagsTable> {
  $$LibraryTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$LibraryDocumentsTableAnnotationComposer get docId {
    final $$LibraryDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.docId,
      referencedTable: $db.libraryDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryTagsTable,
          LibraryTagRow,
          $$LibraryTagsTableFilterComposer,
          $$LibraryTagsTableOrderingComposer,
          $$LibraryTagsTableAnnotationComposer,
          $$LibraryTagsTableCreateCompanionBuilder,
          $$LibraryTagsTableUpdateCompanionBuilder,
          (LibraryTagRow, $$LibraryTagsTableReferences),
          LibraryTagRow,
          PrefetchHooks Function({bool docId})
        > {
  $$LibraryTagsTableTableManager(_$AppDatabase db, $LibraryTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> docId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTagsCompanion(docId: docId, tag: tag, rowid: rowid),
          createCompanionCallback:
              ({
                required String docId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => LibraryTagsCompanion.insert(
                docId: docId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({docId = false}) {
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
                    if (docId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.docId,
                                referencedTable: $$LibraryTagsTableReferences
                                    ._docIdTable(db),
                                referencedColumn: $$LibraryTagsTableReferences
                                    ._docIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$LibraryTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryTagsTable,
      LibraryTagRow,
      $$LibraryTagsTableFilterComposer,
      $$LibraryTagsTableOrderingComposer,
      $$LibraryTagsTableAnnotationComposer,
      $$LibraryTagsTableCreateCompanionBuilder,
      $$LibraryTagsTableUpdateCompanionBuilder,
      (LibraryTagRow, $$LibraryTagsTableReferences),
      LibraryTagRow,
      PrefetchHooks Function({bool docId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OperationsTableTableManager get operations =>
      $$OperationsTableTableManager(_db, _db.operations);
  $$OperationInputsTableTableManager get operationInputs =>
      $$OperationInputsTableTableManager(_db, _db.operationInputs);
  $$OperationOutputsTableTableManager get operationOutputs =>
      $$OperationOutputsTableTableManager(_db, _db.operationOutputs);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$LibraryDocumentsTableTableManager get libraryDocuments =>
      $$LibraryDocumentsTableTableManager(_db, _db.libraryDocuments);
  $$LibraryTagsTableTableManager get libraryTags =>
      $$LibraryTagsTableTableManager(_db, _db.libraryTags);
}
