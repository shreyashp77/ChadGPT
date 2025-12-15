/// Status of a local model download/state
enum LocalModelStatus { 
  notDownloaded, 
  downloading, 
  downloaded, 
  loading,
  loaded,
  error 
}

/// Represents a GGUF model that can be downloaded from Hugging Face
/// and run locally on the device
class LocalModel {
  final String id;              // Unique identifier (HF model ID + filename)
  final String repoId;          // Hugging Face repo ID (e.g., "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF")
  final String name;            // Display name
  final String filename;        // GGUF file name (e.g., "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")
  final int sizeBytes;          // File size in bytes
  final String downloadUrl;     // Direct download URL
  String? localPath;            // Path after download
  LocalModelStatus status;
  double downloadProgress;      // 0.0 to 1.0
  
  // Model metadata
  final int? parameters;        // Number of parameters (e.g., 1100000000 for 1.1B)
  final String? quantization;   // Quantization type (e.g., "Q4_K_M")
  final String? description;    // Short description
  final DateTime? createdAt;    // When the model was added to local DB

  LocalModel({
    required this.id,
    required this.repoId,
    required this.name,
    required this.filename,
    required this.sizeBytes,
    required this.downloadUrl,
    this.localPath,
    this.status = LocalModelStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.parameters,
    this.quantization,
    this.description,
    this.createdAt,
  });

  /// Human-readable size string (e.g., "638 MB")
  String get sizeString {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Human-readable parameter count (e.g., "1.1B")
  String get parametersString {
    if (parameters == null) return 'Unknown';
    if (parameters! < 1000000) return '${(parameters! / 1000).toStringAsFixed(0)}K';
    if (parameters! < 1000000000) return '${(parameters! / 1000000).toStringAsFixed(1)}M';
    return '${(parameters! / 1000000000).toStringAsFixed(1)}B';
  }

  /// Status display string
  String get statusString {
    switch (status) {
      case LocalModelStatus.notDownloaded:
        return 'Not Downloaded';
      case LocalModelStatus.downloading:
        return 'Downloading ${(downloadProgress * 100).toStringAsFixed(0)}%';
      case LocalModelStatus.downloaded:
        return 'Ready';
      case LocalModelStatus.loading:
        return 'Loading...';
      case LocalModelStatus.loaded:
        return 'Active';
      case LocalModelStatus.error:
        return 'Error';
    }
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'repo_id': repoId,
      'name': name,
      'filename': filename,
      'size_bytes': sizeBytes,
      'download_url': downloadUrl,
      'local_path': localPath,
      'status': status.name,
      'parameters': parameters,
      'quantization': quantization,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Create from database Map
  factory LocalModel.fromMap(Map<String, dynamic> map) {
    return LocalModel(
      id: map['id'] as String,
      repoId: map['repo_id'] as String,
      name: map['name'] as String,
      filename: map['filename'] as String,
      sizeBytes: map['size_bytes'] as int,
      downloadUrl: map['download_url'] as String,
      localPath: map['local_path'] as String?,
      status: LocalModelStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LocalModelStatus.notDownloaded,
      ),
      parameters: map['parameters'] as int?,
      quantization: map['quantization'] as String?,
      description: map['description'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Create a copy with updated fields
  LocalModel copyWith({
    String? id,
    String? repoId,
    String? name,
    String? filename,
    int? sizeBytes,
    String? downloadUrl,
    String? localPath,
    LocalModelStatus? status,
    double? downloadProgress,
    int? parameters,
    String? quantization,
    String? description,
    DateTime? createdAt,
  }) {
    return LocalModel(
      id: id ?? this.id,
      repoId: repoId ?? this.repoId,
      name: name ?? this.name,
      filename: filename ?? this.filename,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      parameters: parameters ?? this.parameters,
      quantization: quantization ?? this.quantization,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'LocalModel(id: $id, name: $name, size: $sizeString, status: $statusString)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
