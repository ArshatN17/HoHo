import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_indicator.dart';
import '../services/notification_service.dart';
import '../services/event_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Verify admin access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccess();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Check if the current user has admin access
  Future<void> _checkAdminAccess() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;
    
    if (!isAdmin) {
      // If not admin, go back to previous screen
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have admin privileges')),
      );
    }
  }

  // Set a user as admin
  Future<void> _setUserAsAdmin(String userId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.setUserAsAdmin(userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User is now an admin')),
        );
      } else {
        setState(() {
          _error = authProvider.error ?? 'Failed to set user as admin';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Remove admin privileges from a user
  Future<void> _removeAdminRole(String userId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.removeAdminRole(userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin role removed')),
        );
      } else {
        setState(() {
          _error = authProvider.error ?? 'Failed to remove admin role';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Content', icon: Icon(Icons.article)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.red.shade100,
                    width: double.infinity,
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUsersTab(),
                      _buildContentTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Users management tab
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        final users = snapshot.data!.docs;
        
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userModel = UserModel.fromMap({
              ...userData,
              'uid': users[index].id,
            });
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: userModel.photoURL != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(userModel.photoURL!),
                      )
                    : CircleAvatar(
                        child: Text(userModel.getFullName().substring(0, 1)),
                      ),
                title: Text(userModel.getFullName()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userModel.email),
                    Text('Role: ${userModel.role.toString().split('.').last}'),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'make_admin') {
                      await _setUserAsAdmin(userModel.uid);
                    } else if (value == 'remove_admin') {
                      await _removeAdminRole(userModel.uid);
                    }
                  },
                  itemBuilder: (context) => [
                    if (userModel.role != UserRole.admin)
                      const PopupMenuItem(
                        value: 'make_admin',
                        child: Text('Make Admin'),
                      ),
                    if (userModel.role == UserRole.admin)
                      const PopupMenuItem(
                        value: 'remove_admin',
                        child: Text('Remove Admin Role'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Content management tab
  Widget _buildContentTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.construction, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Content Management',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Here you will be able to manage and moderate all content in the app.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            // Future implementation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Content management coming soon!'),
              ),
            );
          },
          child: const Text('View All Content'),
        ),
      ],
    );
  }

  // App settings tab
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Settings Header
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'App Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          
          // Notification Testing Section
          _buildNotificationTestingSection(),
          
          const Divider(height: 40),
          
          // App Configuration
          const Text(
            'Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Configure app-wide settings and parameters.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Future implementation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings management coming soon!'),
                        ),
                      );
                    },
                    child: const Text('Configure App Settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Notification testing section
  Widget _buildNotificationTestingSection() {
    final eventService = EventService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Notification Testing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Test event notifications to verify they are working correctly.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').limit(5).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final users = snapshot.data!.docs;
                if (users.isEmpty) {
                  return const Text('No users found');
                }
                
                // User selection dropdown
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Send test notification to yourself
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Send Test Notification to Yourself'),
                      onPressed: () async {
                        if (authProvider.user != null) {
                          setState(() {
                            _isLoading = true;
                          });
                          
                          // Store context before async operation
                          final scaffoldContext = context;
                          
                          final success = await eventService.testEventReminderNotification(
                            userId: authProvider.user!.uid,
                            eventTitle: 'Admin Test Event',
                          );
                          
                          setState(() {
                            _isLoading = false;
                          });
                          
                          // Use the stored context reference
                          if (mounted) {
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Test notification sent successfully!'
                                      : 'Failed to send test notification',
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Send test notification to selected user
                    const Text('Or send to a specific user:'),
                    const SizedBox(height: 8),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData = users[index].data() as Map<String, dynamic>;
                        final userModel = UserModel.fromMap({
                          ...userData,
                          'uid': users[index].id,
                        });
                        
                        return ListTile(
                          leading: userModel.photoURL != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(userModel.photoURL!),
                                )
                              : CircleAvatar(
                                  child: Text(userModel.getFullName().substring(0, 1)),
                                ),
                          title: Text(userModel.getFullName()),
                          subtitle: Text(userModel.email),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                              });
                              
                              // Store context before async operation
                              final scaffoldContext = context;
                              
                              final success = await eventService.testEventReminderNotification(
                                userId: userModel.uid,
                                eventTitle: 'Admin Test Event for ${userModel.getFullName()}',
                              );
                              
                              setState(() {
                                _isLoading = false;
                              });
                              
                              // Use the stored context reference
                              if (mounted) {
                                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Test notification sent to ${userModel.getFullName()}'
                                          : 'Failed to send test notification',
                                    ),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('Send'),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 