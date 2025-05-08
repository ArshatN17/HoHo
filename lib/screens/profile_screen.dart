import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/event_provider.dart';
import '../models/user_model.dart';
import '../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    Key? key,
    required this.userId,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String? _error;
  int _createdEventsCount = 0;
  int _attendingEventsCount = 0;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadEventCounts();
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If userId changed, reload profile
    if (oldWidget.userId != widget.userId) {
      _loadProfile();
      _loadEventCounts();
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('ProfileScreen: Loading profile for ${widget.userId}');
      await Provider.of<ProfileProvider>(context, listen: false)
          .loadUserProfile(widget.userId);
      print('ProfileScreen: Profile loaded successfully');
    } catch (e) {
      print('ProfileScreen: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadEventCounts() async {
    if (!mounted) return;
    
    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      await eventProvider.refreshEvents();
      
      if (!mounted) return;
      
      // Get count of events created by this user
      setState(() {
        _createdEventsCount = profileProvider.userProfile?.createdEvents.length ?? 0;
        _attendingEventsCount = eventProvider.events
            .where((event) => event.attendees?.contains(widget.userId) ?? false)
            .length;
      });
    } catch (e) {
      print('Error loading event counts: $e');
    }
  }

  // Add a refresh method that can be called from the UI
  Future<void> _refreshProfile() async {
    await _loadProfile();
    await _loadEventCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: widget.isCurrentUser
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _navigateToEditProfile(context),
                ),
                // Add refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshProfile,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            if (_isLoading || profileProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final userProfile = profileProvider.userProfile;
            if (userProfile == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Failed to load profile. The user profile might not exist.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfileImage(userProfile),
                  const SizedBox(height: 16),
                  Text(
                    userProfile.getFullName(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userProfile.email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // User statistics cards
                  _buildStatisticsCards(userProfile),
                  const SizedBox(height: 24),
                  
                  // Bio section
                  _buildInfoCard(
                    icon: Icons.description,
                    title: 'Bio',
                    content: userProfile.bio != null && userProfile.bio!.isNotEmpty
                        ? userProfile.bio!
                        : 'No bio provided',
                  ),
                  const SizedBox(height: 16),
                  
                  // Account info
                  _buildAccountInfoCard(userProfile),
                  const SizedBox(height: 16),
                  
                  // Edit profile button (if current user)
                  if (widget.isCurrentUser)
                    ElevatedButton(
                      onPressed: () => _navigateToEditProfile(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildProfileImage(UserModel userProfile) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            image: userProfile.photoURL != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(userProfile.photoURL!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (userProfile.photoURL == null)
              ? const Icon(Icons.person, size: 60, color: Colors.grey)
              : null,
        ),
        if (widget.isCurrentUser)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
              tooltip: 'Edit profile',
              onPressed: () => _navigateToEditProfile(context),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStatisticsCards(UserModel userProfile) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.event,
            value: _createdEventsCount.toString(),
            label: 'Created',
          ),
        ),
        Expanded(
          child: _buildStatCard(
            icon: Icons.groups,
            value: _attendingEventsCount.toString(),
            label: 'Attending',
          ),
        ),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            value: _calculateDaysSinceJoined(userProfile.createdAt),
            label: 'Member',
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccountInfoCard(UserModel userProfile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Account Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.email, 'Email', userProfile.email),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Joined', _formatDateTime(userProfile.createdAt)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Last Active', _formatDateTime(userProfile.lastActive)),
            if (userProfile.isAdmin) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.security, 'Role', 'Administrator'),
            ]
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToEditProfile(BuildContext context) async {
    // Navigate to edit profile and wait for result
    final wasUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
    
    // If profile was updated, refresh the profile data
    if (wasUpdated == true) {
      _loadProfile();
      _loadEventCounts();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
  
  String _calculateDaysSinceJoined(DateTime joinDate) {
    final difference = DateTime.now().difference(joinDate);
    return '${difference.inDays}d';
  }
} 