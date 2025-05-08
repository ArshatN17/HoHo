import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/validators.dart';
import '../utils/image_helper.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  
  File? _selectedImage;
  bool _isUploading = false;
  bool _imageChanged = false;
  UserRole? _userRole;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isUploading = true;
    });
    
    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user != null) {
        print('EditProfileScreen: Loading profile for user ${authProvider.user!.uid}');
        await profileProvider.loadUserProfile(authProvider.user!.uid);
        _setInitialValues();
        print('EditProfileScreen: Profile loaded successfully');
      } else {
        print('EditProfileScreen: No authenticated user found');
        _showErrorSnackBar('No authenticated user found');
      }
    } catch (e) {
      print('EditProfileScreen: Error loading user data: $e');
      _showErrorSnackBar('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  void _setInitialValues() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final userProfile = profileProvider.userProfile;
    
    if (userProfile != null) {
      setState(() {
        _displayNameController.text = userProfile.displayName ?? '';
        _firstNameController.text = userProfile.firstName ?? '';
        _lastNameController.text = userProfile.lastName ?? '';
        _bioController.text = userProfile.bio ?? '';
        _userRole = userProfile.role;
      });
    }
  }
  
  Future<void> _pickImage() async {
    try {
      // Use our ImageHelper to pick and crop the image
      final File? croppedImage = await ImageHelper.pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
      );
      
      if (croppedImage != null) {
        setState(() {
          _selectedImage = croppedImage;
          _imageChanged = true;
        });
        print('EditProfileScreen: Image picked and cropped successfully');
      }
    } catch (e) {
      print('EditProfileScreen: Error picking/cropping image: $e');
      _showErrorSnackBar('Failed to process image: ${e.toString()}');
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }
      
      final userId = authProvider.user!.uid;
      bool success = true;
      
      // Upload new profile image if selected
      if (_imageChanged && _selectedImage != null) {
        print('EditProfileScreen: Uploading new profile image');
        success = await profileProvider.uploadProfileImage(userId, _selectedImage!);
        if (!success) {
          setState(() {
            _isUploading = false;
          });
          _showErrorSnackBar(profileProvider.error ?? 'Failed to upload profile image. Please check your internet connection and try again.');
          return;
        }
      }
      
      // Update profile information
      print('EditProfileScreen: Updating profile information');
      success = await profileProvider.updateUserProfile(
        userId: userId,
        displayName: _displayNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      
      if (success) {
        if (mounted) {
          print('EditProfileScreen: Profile updated successfully');
          
          // Принудительно еще раз загружаем профиль, чтобы гарантировать актуальность данных
          await profileProvider.clearCache();
          await profileProvider.loadUserProfile(userId);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          
          // Небольшая задержка перед возвратом, чтобы обеспечить обновление интерфейса
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Make sure to pass true back to indicate profile was updated
          Navigator.pop(context, true);
        }
      } else {
        _showErrorSnackBar(profileProvider.error ?? 'Failed to update profile');
      }
    } catch (e) {
      print('EditProfileScreen: Error saving profile: $e');
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userProfile = profileProvider.userProfile;
    final bool isAdmin = userProfile?.isAdmin ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _saveProfile,
          ),
        ],
      ),
      body: profileProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileImage(userProfile?.photoURL),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                        hintText: 'Leave empty to use first and last name',
                      ),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Show role info (admin only can change)
                    if (isAdmin) 
                      _buildRoleSelector()
                    else
                      ListTile(
                        title: const Text('Account Type'),
                        subtitle: Text(_formatRole(userProfile?.role)),
                        leading: const Icon(Icons.security),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Created events count (if applicable)
                    if (userProfile != null && userProfile.createdEvents.isNotEmpty)
                      ListTile(
                        title: const Text('Created Events'),
                        subtitle: Text('${userProfile.createdEvents.length} events'),
                        leading: const Icon(Icons.event),
                      ),
                    
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator()
                          : const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  String _formatRole(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.user:
        return 'Regular User';
      case UserRole.guest:
        return 'Guest';
      default:
        return 'User';
    }
  }
  
  Widget _buildRoleSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<UserRole>(
              title: const Text('Regular User'),
              value: UserRole.user,
              groupValue: _userRole,
              onChanged: (UserRole? value) {
                setState(() {
                  _userRole = value;
                });
              },
            ),
            RadioListTile<UserRole>(
              title: const Text('Administrator'),
              value: UserRole.admin,
              groupValue: _userRole,
              onChanged: (UserRole? value) {
                setState(() {
                  _userRole = value;
                });
              },
            ),
            RadioListTile<UserRole>(
              title: const Text('Guest'),
              value: UserRole.guest,
              groupValue: _userRole,
              onChanged: (UserRole? value) {
                setState(() {
                  _userRole = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileImage(String? photoURL) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : (photoURL != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(photoURL),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: (_selectedImage == null && photoURL == null)
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            tooltip: 'Pick and crop image',
            onPressed: _pickImage,
          ),
        ),
      ],
    );
  }
} 