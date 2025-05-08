import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  
  // Pick image from gallery
  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
    bool multiImage = false,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('ImageHelper: Error picking image: $e');
      return null;
    }
  }
  
  // Crop image with a customizable UI
  static Future<File?> cropImage({
    required File imageFile,
    CropAspectRatio? aspectRatio,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: aspectRatio,
        compressQuality: compressQuality,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: uiSettings ?? [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            minimumAspectRatio: 1.0,
            rectX: 0.0,
            rectY: 0.0,
            rectWidth: 1.0,
            rectHeight: 1.0,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );
      
      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      print('ImageHelper: Error cropping image: $e');
      return null;
    }
  }
  
  // Pick and crop image in one step with BuildContext for web
  static Future<File?> pickAndCropImage({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    CropAspectRatio? aspectRatio,
  }) async {
    try {
      // First pick the image
      final File? pickedFile = await pickImage(source: source);
      
      if (pickedFile != null) {
        // Create UI settings with context for web
        final uiSettings = [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            minimumAspectRatio: 1.0,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
          WebUiSettings(
            context: context,
          ),
        ];
        
        // Then crop it
        return await cropImage(
          imageFile: pickedFile,
          aspectRatio: aspectRatio,
          uiSettings: uiSettings,
        );
      }
      return null;
    } catch (e) {
      print('ImageHelper: Error in pickAndCropImage: $e');
      return null;
    }
  }
} 