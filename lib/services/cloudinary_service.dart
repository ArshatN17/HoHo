import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  // Replace with your actual Cloudinary credentials
  // For the free version of the app, we use unsigned uploads with a preset
  // which is more secure than including API Key and Secret in the app
  static const String cloudName = 'doj8ghylu';
  static const String uploadPreset = 'ml_default'; // Use 'ml_default' or create a custom unsigned upload preset
  
  // Create a CloudinaryPublic instance for unsigned uploads
  final CloudinaryPublic _cloudinary = CloudinaryPublic(cloudName, uploadPreset);

  // Upload image to Cloudinary
  Future<String?> uploadImage(File imageFile, String folder, String userId) async {
    try {
      print('CloudinaryService: Starting upload to Cloudinary');

      // Check file exists and is readable
      if (!await imageFile.exists()) {
        print('CloudinaryService: File does not exist: ${imageFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();
      print('CloudinaryService: File size: ${fileSize} bytes');

      if (fileSize == 0) {
        print('CloudinaryService: File is empty');
        return null;
      }
      
      // Create a custom resource type and folder for better organization
      print('CloudinaryService: Uploading to Cloudinary with cloud name: $cloudName and preset: $uploadPreset');
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
          context: {'user_id': userId}, // Add metadata for reference
          tags: ['profile', 'user_$userId'],
        ),
      );
      
      print('CloudinaryService: Upload successful. URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('CloudinaryService: Error uploading image: $e');
      return null;
    }
  }
  
  // This method can be used to transform images if needed
  String getTransformedUrl(String originalUrl, {
    int width = 200,
    int height = 200,
    bool crop = true,
  }) {
    try {
      // Check if it's a Cloudinary URL
      if (!originalUrl.contains('cloudinary.com')) {
        return originalUrl;
      }
      
      // Create a transformed URL with the specified parameters
      final Uri uri = Uri.parse(originalUrl);
      final pathSegments = List<String>.from(uri.pathSegments);
      
      // Find the upload segment to insert transformations after
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex != -1 && uploadIndex < pathSegments.length - 1) {
        // Insert transformations
        final transformation = crop
            ? 'c_fill,g_face,h_$height,w_$width'  // Crop and focus on face
            : 'h_$height,w_$width';  // Just resize
        
        pathSegments.insert(uploadIndex + 1, transformation);
        
        // Rebuild the URL
        final newUri = uri.replace(pathSegments: pathSegments);
        return newUri.toString();
      }
      
      return originalUrl;
    } catch (e) {
      print('CloudinaryService: Error transforming URL: $e');
      return originalUrl;
    }
  }
} 