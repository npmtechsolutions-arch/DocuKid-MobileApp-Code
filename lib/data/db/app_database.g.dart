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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    operations,
    operationInputs,
    operationOutputs,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OperationsTableTableManager get operations =>
      $$OperationsTableTableManager(_db, _db.operations);
  $$OperationInputsTableTableManager get operationInputs =>
      $$OperationInputsTableTableManager(_db, _db.operationInputs);
  $$OperationOutputsTableTableManager get operationOutputs =>
      $$OperationOutputsTableTableManager(_db, _db.operationOutputs);
}
