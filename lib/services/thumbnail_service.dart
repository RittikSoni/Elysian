import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ThumbnailService {
  /// Saves a local image file and returns its path
  static Future<String?> saveThumbnail(File imageFile, String linkId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory(path.join(appDir.path, 'thumbnails'));
      
      // Create thumbnails directory if it doesn't exist
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }
      
      // Generate unique filename
      final extension = path.extension(imageFile.path);
      final fileName = '$linkId$extension';
      final savedFile = File(path.join(thumbnailsDir.path, fileName));
      
      // Copy the file
      await imageFile.copy(savedFile.path);
      
      return savedFile.path;
    } catch (e) {
      print('Error saving thumbnail: $e');
      return null;
    }
  }

  /// Deletes a thumbnail file
  static Future<void> deleteThumbnail(String? thumbnailPath) async {
    if (thumbnailPath == null || thumbnailPath.isEmpty) return;
    
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting thumbnail: $e');
    }
  }

  /// Gets the thumbnail file if it exists
  static Future<File?> getThumbnailFile(String? thumbnailPath) async {
    if (thumbnailPath == null || thumbnailPath.isEmpty) return null;
    
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Error getting thumbnail file: $e');
    }
    return null;
  }
}

