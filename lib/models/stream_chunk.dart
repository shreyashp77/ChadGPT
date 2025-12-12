/// Represents a chunk of data from the streaming API response
class StreamChunk {
  final String? content;
  final int? promptTokens;
  final int? completionTokens;
  final bool isDone;

  StreamChunk({
    this.content,
    this.promptTokens,
    this.completionTokens,
    this.isDone = false,
  });

  /// Whether this chunk contains token usage information
  bool get hasUsage => promptTokens != null || completionTokens != null;
}
