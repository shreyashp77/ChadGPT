import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service for extracting text from documents (PDF, TXT, MD)
class DocumentService {
  // Singleton pattern
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  /// Supported file extensions
  static const List<String> supportedExtensions = ['pdf', 'txt', 'md'];

  /// Maximum characters to extract (to prevent context overflow)
  static const int maxCharacters = 50000;

  /// Check if a file extension is supported
  bool isSupported(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Extract text from a file based on its extension
  Future<String> extractText(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final ext = filePath.split('.').last.toLowerCase();

    String text;
    switch (ext) {
      case 'pdf':
        text = await _extractFromPdf(file);
        break;
      case 'txt':
      case 'md':
        text = await _extractFromTextFile(file);
        break;
      default:
        throw Exception('Unsupported file type: $ext');
    }

    // Truncate if too long
    if (text.length > maxCharacters) {
      text = '${text.substring(0, maxCharacters)}\n\n[Document truncated - showing first $maxCharacters characters]';
    }

    return text.trim();
  }

  /// Extract text from PDF using Syncfusion
  Future<String> _extractFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      final StringBuffer textBuffer = StringBuffer();
      
      // Extract text from each page
      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final extractor = PdfTextExtractor(document);
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.isNotEmpty) {
          textBuffer.writeln(pageText);
          textBuffer.writeln(); // Add space between pages
        }
      }
      
      document.dispose();
      return textBuffer.toString();
    } catch (e) {
      throw Exception('Failed to extract PDF text: $e');
    }
  }

  /// Extract text from plain text files (TXT, MD)
  Future<String> _extractFromTextFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read text file: $e');
    }
  }

  /// Get filename from path
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Estimate token count (rough approximation: ~4 chars per token)
  int estimateTokenCount(String text) {
    return (text.length / 4).ceil();
  }
}
