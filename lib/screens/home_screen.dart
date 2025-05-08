import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:social_app/screens/profile_screen.dart';
import 'package:social_app/screens/event_feed_screen.dart';
import 'package:social_app/screens/notification_settings_screen.dart';
import 'package:social_app/screens/create_event_screen.dart';
import 'package:social_app/screens/admin_panel_screen.dart';
import 'package:social_app/services/profile_service.dart';
import 'package:social_app/widgets/profile_avatar.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/event_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _userProfile;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
      
      // Добавляем слушатель для ProfileProvider, чтобы обновлять данные пользователя
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.addListener(_updateUserProfile);
    });
  }

  @override
  void dispose() {
    // Удаляем слушатель при уничтожении виджета
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.removeListener(_updateUserProfile);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if user data needs to be refreshed
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    if (authProvider.user != null && 
        (profileProvider.userProfile == null || 
         profileProvider.userProfile?.uid != authProvider.user!.uid)) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);

      if (authProvider.user != null) {
        print('HomeScreen: Loading profile for user ${authProvider.user!.uid}');
        await profileProvider.loadUserProfile(authProvider.user!.uid);
        if (!mounted) return;
        
        setState(() {
          _userProfile = profileProvider.userProfile;
        });
        
        // Preload events and filter options
        await eventProvider.refreshEvents();
        await eventProvider.loadFilterOptions();
        print('HomeScreen: Profile and events loaded successfully');
      }
    } catch (e) {
      print('HomeScreen: Error loading user profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Обновляем локальные данные пользователя при изменениях в ProfileProvider
  void _updateUserProfile() {
    if (!mounted) return;
    
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (profileProvider.userProfile != null) {
      setState(() {
        _userProfile = profileProvider.userProfile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: true); // Listen to changes
    final user = authProvider.user;
    
    // Get the latest user profile data
    _userProfile = profileProvider.userProfile ?? _userProfile;
    
    // Define the tabs
    final List<Widget> _pages = [
      _buildHomeContent(user),
      const EventFeedScreen(),
      ProfileScreen(
        userId: user?.uid ?? '',
        isCurrentUser: true,
      ),
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('HaHo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await authProvider.logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error logging out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      drawer: Builder(
        builder: (context) {
          // Используем consumer для обновления только drawer при изменении данных
          return Consumer<ProfileProvider>(
            builder: (context, profileProvider, _) {
              final currentProfile = profileProvider.userProfile ?? _userProfile;
              
              return Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserAccountsDrawerHeader(
                      accountName: Text(currentProfile?.getFullName() ?? 'User'),
                      accountEmail: Text(user?.email ?? ''),
                      currentAccountPicture: ProfileAvatar(
                        imageUrl: currentProfile?.photoURL,
                        radius: 30,
                        onTap: () => _navigateToProfile(context, user?.uid ?? ''),
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('Home'),
                      selected: _selectedIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        _onItemTapped(0);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('Event Feed'),
                      selected: _selectedIndex == 1,
                      onTap: () {
                        Navigator.pop(context);
                        _onItemTapped(1);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Profile'),
                      selected: _selectedIndex == 2,
                      onTap: () {
                        Navigator.pop(context);
                        _onItemTapped(2);
                      },
                    ),
                    if (currentProfile?.isAdmin == true)
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Admin Panel'),
                        onTap: () {
                          Navigator.pop(context); // Close the drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminPanelScreen(),
                            ),
                          );
                        },
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.notifications_active),
                      title: const Text('Notification Settings'),
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.exit_to_app),
                      title: const Text('Logout'),
                      onTap: () async {
                        Navigator.pop(context); // Close the drawer
                        try {
                          await authProvider.logout();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error logging out: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
  
  Widget _buildHomeContent(User? user) {
    final eventProvider = Provider.of<EventProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final currentProfile = profileProvider.userProfile ?? _userProfile;
    final upcomingEvents = eventProvider.events.take(3).toList();
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserProfile();
        await Provider.of<EventProvider>(context, listen: false).refreshEvents();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User welcome card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    ProfileAvatar(
                      imageUrl: currentProfile?.photoURL,
                      radius: 30,
                      onTap: () => _navigateToProfile(context, user?.uid ?? ''),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            currentProfile?.getFullName() ?? 'User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _navigateToProfile(context, user?.uid ?? ''),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick actions section
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.event,
                  label: 'Explore',
                  onTap: () => _onItemTapped(1),
                ),
                _buildActionButton(
                  context,
                  icon: Icons.add_circle,
                  label: 'Create',
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => const CreateEventScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () => _navigateToProfile(context, user?.uid ?? ''),
                ),
                _buildActionButton(
                  context,
                  icon: Icons.notifications,
                  label: 'Alerts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Upcoming events section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                TextButton(
                  onPressed: () => _onItemTapped(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            eventProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : upcomingEvents.isEmpty
                    ? _buildEmptyEventsCard()
                    : Column(
                        children: upcomingEvents
                            .map((event) => _buildEventCard(context, event))
                            .toList(),
                      ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyEventsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No upcoming events',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new event or browse the event feed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => const CreateEventScreen(),
                  ),
                );
              },
              child: const Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventCard(BuildContext context, dynamic event) {
    // Format the date
    final date = event.date;
    final dateString = date != null 
        ? '${date.day}/${date.month}/${date.year}'
        : 'No date';
        
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.event,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          event.title ?? 'Untitled Event',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  dateString,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${event.attendees?.length ?? 0} attending',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: () {
          // Navigate to event details
          _onItemTapped(1);
        },
      ),
    );
  }
  
  void _navigateToProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    
    print('HomeScreen: Navigating to profile for user $userId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: userId,
          isCurrentUser: true,
        ),
      ),
    ).then((_) {
      // Refresh user profile when returning from profile screen
      print('HomeScreen: Returned from profile screen, refreshing data');
      _loadUserProfile();
    });
  }
} 