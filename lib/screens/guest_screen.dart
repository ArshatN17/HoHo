import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';
import '../widgets/event_list_item.dart';
import 'auth_screen.dart';
import 'event_detail_screen.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({Key? key}) : super(key: key);

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  bool _isLoading = true;
  List<String> _locations = [];
  List<String> _tags = [];
  String? _selectedLocation;
  String? _selectedTag;
  bool _onlyUpcoming = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadFilterOptions();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Only load public events for guests
      await eventProvider.loadEvents(
        onlyPublic: true,
        onlyUpcoming: _onlyUpcoming,
        location: _selectedLocation,
        tagFilter: _selectedTag != null ? [_selectedTag!] : null,
      );
    } catch (e) {
      print('Error loading events: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.loadFilterOptions();
      if (mounted) {
        setState(() {
          _locations = eventProvider.locations;
          _tags = eventProvider.tags;
        });
      }
    } catch (e) {
      print('Error loading filter options: $e');
    }
  }

  void _applyFilters() {
    _loadEvents();
  }

  void _resetFilters() {
    setState(() {
      _selectedLocation = null;
      _selectedTag = null;
      _onlyUpcoming = true;
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () => _showLoginPrompt(context),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildLoginBar(),
    );
  }

  Widget _buildBody() {
    final eventProvider = Provider.of<EventProvider>(context);
    final events = eventProvider.events;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No events found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try changing your filters or check back later',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetFilters,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventListItem(
              event: event,
              onTap: () => _navigateToEventDetail(event),
              showAttendButton: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginBar() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sign in to join events and interact with other users',
              style: TextStyle(fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => _navigateToAuth(),
            child: const Text('SIGN IN'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Events'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location'),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    hint: const Text('Select location'),
                    value: _selectedLocation,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All locations'),
                      ),
                      ..._locations.map((location) => DropdownMenuItem<String>(
                        value: location,
                        child: Text(location),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedLocation = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Tag'),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    hint: const Text('Select tag'),
                    value: _selectedTag,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All tags'),
                      ),
                      ..._tags.map((tag) => DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedTag = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Only upcoming events'),
                    value: _onlyUpcoming,
                    onChanged: (value) {
                      setDialogState(() {
                        _onlyUpcoming = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetFilters();
                },
                child: const Text('RESET'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _applyFilters();
                },
                child: const Text('APPLY'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text(
          'To join events, comment, and interact with other users, you need to create an account or sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CONTINUE BROWSING'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAuth();
            },
            child: const Text('SIGN IN'),
          ),
        ],
      ),
    );
  }

  void _navigateToEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          eventId: event.id,
          isGuestMode: true,
        ),
      ),
    );
  }

  void _navigateToAuth() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // First exit guest mode
    authProvider.exitGuestMode().then((_) {
      // Then navigate to auth screen after guest mode is exited
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    });
  }
} 