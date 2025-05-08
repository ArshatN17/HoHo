import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cloudinary_service.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final VoidCallback? onTap;
  static final CloudinaryService _cloudinaryService = CloudinaryService();

  const ProfileAvatar({
    Key? key,
    this.imageUrl,
    this.radius = 20,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Transform the Cloudinary URL if it exists
    final optimizedImageUrl = imageUrl != null 
        ? _cloudinaryService.getTransformedUrl(
            imageUrl!, 
            width: (radius * 2).round(),
            height: (radius * 2).round(),
            crop: true,
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        backgroundImage: optimizedImageUrl != null
            ? CachedNetworkImageProvider(optimizedImageUrl)
            : null,
        child: imageUrl == null
            ? Icon(
                Icons.person,
                size: radius,
                color: Colors.grey[600],
              )
            : null,
      ),
    );
  }
} 