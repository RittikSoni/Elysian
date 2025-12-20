import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:elysian/services/storage_service.dart';

/// Service for exporting and importing data with custom file format
/// Uses .elysian extension and basic obfuscation to prevent easy access
class ExportImportService {
  static const String _fileExtension = '.elysian';
  static const String _magicHeader = 'ELYSIAN_DATA_V1'; // Magic header to verify file
  static const String _obfuscationKey = 'ElysianExport2024!'; // Simple obfuscation key

  /// Export data to a custom .elysian file
  static Future<String?> exportToFile() async {
    try {
      // Get export data
      final jsonData = await StorageService.exportData();
      
      // Create file content with magic header and obfuscated data
      final fileContent = _createFileContent(jsonData);
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'elysian_export_$timestamp$_fileExtension';
      final filePath = '${tempDir.path}/$fileName';
      
      // Write file
      final file = File(filePath);
      await file.writeAsBytes(fileContent);
      
      debugPrint('Export file created: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error exporting to file: $e');
      return null;
    }
  }

  /// Share the exported file
  static Future<bool> shareExportedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Export file does not exist: $filePath');
        return false;
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'Elysian Data Export');
      return true;
    } catch (e) {
      debugPrint('Error sharing file: $e');
      return false;
    }
  }

  /// Import data from a .elysian file
  static Future<ImportResult> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          error: 'File does not exist',
        );
      }

      // Read file bytes
      final fileBytes = await file.readAsBytes();
      
      // Verify and extract data
      final jsonData = _extractFileContent(fileBytes);
      if (jsonData == null) {
        return ImportResult(
          success: false,
          error: 'Invalid file format. This is not a valid Elysian export file.',
        );
      }

      // Import data
      await StorageService.importData(jsonData);
      
      return ImportResult(
        success: true,
        message: 'Data imported successfully!',
      );
    } catch (e) {
      debugPrint('Error importing from file: $e');
      return ImportResult(
        success: false,
        error: 'Error importing data: $e',
      );
    }
  }

  /// Create file content with magic header and obfuscation
  static Uint8List _createFileContent(String jsonData) {
    // Convert JSON to bytes
    final jsonBytes = utf8.encode(jsonData);
    
    // Apply simple obfuscation (XOR cipher)
    final obfuscatedBytes = _obfuscateData(jsonBytes);
    
    // Create file content: [magic header][data length][obfuscated data]
    final magicBytes = utf8.encode(_magicHeader);
    final lengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, obfuscatedBytes.length, Endian.big);
    
    // Combine all parts
    final fileContent = Uint8List(magicBytes.length + 4 + obfuscatedBytes.length);
    var offset = 0;
    fileContent.setRange(offset, offset + magicBytes.length, magicBytes);
    offset += magicBytes.length;
    fileContent.setRange(offset, offset + 4, lengthBytes);
    offset += 4;
    fileContent.setRange(offset, offset + obfuscatedBytes.length, obfuscatedBytes);
    
    return fileContent;
  }

  /// Extract and deobfuscate data from file content
  static String? _extractFileContent(Uint8List fileBytes) {
    try {
      // Check minimum size
      if (fileBytes.length < _magicHeader.length + 4) {
        return null;
      }

      // Verify magic header
      final magicBytes = utf8.encode(_magicHeader);
      final headerBytes = fileBytes.sublist(0, magicBytes.length);
      if (!_bytesEqual(headerBytes, magicBytes)) {
        debugPrint('Invalid magic header');
        return null;
      }

      // Read data length
      final lengthOffset = magicBytes.length;
      final dataLength = fileBytes.buffer.asByteData().getUint32(lengthOffset, Endian.big);
      
      // Check if file is large enough
      if (fileBytes.length < lengthOffset + 4 + dataLength) {
        debugPrint('File too small for declared data length');
        return null;
      }

      // Extract obfuscated data
      final dataOffset = lengthOffset + 4;
      final obfuscatedBytes = fileBytes.sublist(dataOffset, dataOffset + dataLength);
      
      // Deobfuscate data
      final jsonBytes = _deobfuscateData(obfuscatedBytes);
      
      // Convert back to string
      return utf8.decode(jsonBytes);
    } catch (e) {
      debugPrint('Error extracting file content: $e');
      return null;
    }
  }

  /// Simple XOR obfuscation
  static Uint8List _obfuscateData(Uint8List data) {
    final keyBytes = utf8.encode(_obfuscationKey);
    final result = Uint8List(data.length);
    
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return result;
  }

  /// Deobfuscate data (XOR is symmetric)
  static Uint8List _deobfuscateData(Uint8List data) {
    return _obfuscateData(data); // XOR is symmetric
  }

  /// Compare two byte arrays
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Get file extension
  static String get fileExtension => _fileExtension;

  /// Check if file is a valid Elysian export file
  static Future<bool> isValidElysianFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final fileBytes = await file.readAsBytes();
      return _extractFileContent(fileBytes) != null;
    } catch (e) {
      return false;
    }
  }

  /// Export a single list to a file
  static Future<String?> exportListToFile(String listId) async {
    try {
      // Get list export data
      final jsonData = await StorageService.exportListForSharing(listId);
      
      // Create file content with magic header and obfuscated data
      final fileContent = _createFileContent(jsonData);
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'elysian_list_$timestamp$_fileExtension';
      final filePath = '${tempDir.path}/$fileName';
      
      // Write file
      final file = File(filePath);
      await file.writeAsBytes(fileContent);
      
      debugPrint('List export file created: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error exporting list to file: $e');
      return null;
    }
  }

  /// Share a list file
  static Future<bool> shareListFile(String filePath, String listName) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('List export file does not exist: $filePath');
        return false;
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'Elysian List: $listName');
      return true;
    } catch (e) {
      debugPrint('Error sharing list file: $e');
      return false;
    }
  }

  /// Import a list from a file
  static Future<ImportResult> importListFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          error: 'File does not exist',
        );
      }

      // Read file bytes
      final fileBytes = await file.readAsBytes();
      
      // Verify and extract data
      final jsonData = _extractFileContent(fileBytes);
      if (jsonData == null) {
        return ImportResult(
          success: false,
          error: 'Invalid file format. This is not a valid Elysian list file.',
        );
      }

      // Parse and validate it's a list file
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      if (data['type'] != 'elysian_list') {
        return ImportResult(
          success: false,
          error: 'Invalid file format. This is not a valid Elysian list file.',
        );
      }

      // Import list
      final importedList = await StorageService.importSharedList(jsonData);
      
      return ImportResult(
        success: true,
        message: 'List "${importedList.name}" imported successfully!',
      );
    } catch (e) {
      debugPrint('Error importing list from file: $e');
      return ImportResult(
        success: false,
        error: 'Error importing list: $e',
      );
    }
  }
}

/// Result of import operation
class ImportResult {
  final bool success;
  final String? message;
  final String? error;

  ImportResult({
    required this.success,
    this.message,
    this.error,
  });
}

