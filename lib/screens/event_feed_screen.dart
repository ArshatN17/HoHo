import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';
import '../screens/event_detail_screen.dart';
import '../screens/create_event_screen.dart';
import '../widgets/loading_indicator.dart';

class EventFeedScreen extends StatefulWidget {
  const EventFeedScreen({Key? key}) : super(key: key);

  @override
  State<EventFeedScreen> createState() => _EventFeedScreenState();
}

class _EventFeedScreenState extends State<EventFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isFilterExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _initData();
    _scrollController.addListener(_scrollListener);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !eventProvider.isLoading && 
        !eventProvider.isLoadingMore &&
        eventProvider.hasMoreEvents) {
      eventProvider.loadMoreEvents();
    }
  }
  
  Future<void> _initData() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    // Load initial events
    await eventProvider.refreshEvents();
    // Load filter options
    await eventProvider.loadFilterOptions();
  }
  
  Future<void> _refreshData() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.refreshEvents();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Feed'),
        actions: [
          IconButton(
            icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            tooltip: 'Filter events',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
            tooltip: 'Search events',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEventScreen(),
            ),
          ).then((_) {
            // Refresh events when returning from create screen
            _refreshData();
          });
        },
        tooltip: 'Create Event',
        icon: const Icon(Icons.add),
        label: const Text("Create Event"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Consumer<EventProvider>(
          builder: (context, eventProvider, child) {
            if (eventProvider.isLoading && eventProvider.events.isEmpty) {
              return const Center(child: LoadingIndicator());
            }
            
            if (eventProvider.events.isEmpty && !eventProvider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No events found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try changing your filters or check back later',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        eventProvider.clearFilters();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Clear filters'),
                    ),
                  ],
                ),
              );
            }
            
            return Column(
              children: [
                // Filter section
                if (_isFilterExpanded) _buildFilterSection(eventProvider),
                
                // Event list
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: eventProvider.events.length + 1, // +1 for loading indicator
                        itemBuilder: (context, index) {
                          if (index == eventProvider.events.length) {
                            return eventProvider.isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : eventProvider.hasMoreEvents
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(child: Text('Pull to load more')),
                                      )
                                    : const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(child: Text('No more events')),
                                      );
                          }
                          
                          final event = eventProvider.events[index];
                          return _buildEventCard(context, event);
                        },
                      ),
                      
                      // Show loading indicator during refresh
                      if (eventProvider.isLoading && !eventProvider.isLoadingMore)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildFilterSection(EventProvider eventProvider) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range filters
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date'),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: eventProvider.startDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          eventProvider.startDate = date;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              eventProvider.startDate != null
                                  ? dateFormat.format(eventProvider.startDate!)
                                  : 'Select',
                              style: TextStyle(
                                color: eventProvider.startDate != null
                                    ? Theme.of(context).textTheme.bodyLarge?.color
                                    : Colors.grey,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Date'),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: eventProvider.endDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          eventProvider.endDate = date;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              eventProvider.endDate != null
                                  ? dateFormat.format(eventProvider.endDate!)
                                  : 'Select',
                              style: TextStyle(
                                color: eventProvider.endDate != null
                                    ? Theme.of(context).textTheme.bodyLarge?.color
                                    : Colors.grey,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Location filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Location'),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<String?>(
                      value: eventProvider.location,
                      hint: const Text('All locations'),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (String? newValue) {
                        eventProvider.location = newValue;
                      },
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All locations'),
                        ),
                        ...eventProvider.availableLocations.map((location) {
                          return DropdownMenuItem<String?>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Tags filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags'),
              const SizedBox(height: 4),
              if (eventProvider.availableTags.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text(
                    'No tags available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eventProvider.availableTags.map((tag) {
                    final isSelected = eventProvider.tagFilter?.contains(tag) ?? false;
                    return FilterChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).chipTheme.labelStyle?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          eventProvider.addTagToFilter(tag);
                        } else {
                          eventProvider.removeTagFromFilter(tag);
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      elevation: isSelected ? 2 : 0,
                      pressElevation: 4,
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Upcoming only toggle
          SwitchListTile(
            title: const Text('Upcoming events only'),
            value: eventProvider.onlyUpcoming,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: (value) {
              eventProvider.onlyUpcoming = value;
            },
          ),
          
          // Clear filters button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                eventProvider.clearFilters();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear all filters'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventCard(BuildContext context, EventModel event) {
    final dateFormat = DateFormat('E, MMM d, yyyy • h:mm a');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(eventId: event.id),
            ),
          ).then((_) {
            // Refresh data when returning from event details
            _refreshData();
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            if (event.imageUrl != null)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Icon(
                  Icons.event,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              
            // Event details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and date
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateFormat.format(event.date),
                          style: TextStyle(
                            color: event.isPast
                                ? Colors.red
                                : event.isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[600],
                            fontWeight: event.isToday ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Tags
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: event.tags.map((tag) {
                        return Chip(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).chipTheme.labelStyle?.color,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                        );
                      }).toList(),
                    ),
                  ],
                  
                  // Info row
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Attendees
                      Row(
                        children: [
                          const Icon(Icons.people, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${event.attendees.length}${event.maxAttendees > 0 ? '/${event.maxAttendees}' : ''}',
                            style: TextStyle(
                              color: event.isFull ? Colors.red : Colors.grey[600],
                              fontWeight: event.isFull ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                      
                      // Status indicator
                      if (event.isPast)
                        Chip(
                          label: const Text('Past', style: TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        )
                      else if (event.isToday)
                        Chip(
                          label: const Text('Today', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        )
                      else if (event.isFull)
                        const Chip(
                          label: Text('Full', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                          labelPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to show search dialog
  void _showSearchDialog(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Events'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Enter event name, tag or location',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _performSearch(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text.trim();
              if (query.isNotEmpty) {
                Navigator.of(context).pop();
                _performSearch(query);
              }
            },
            child: const Text('SEARCH'),
          ),
        ],
      ),
    );
  }
  
  // Function to perform the search
  Future<void> _performSearch(String query) async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await eventProvider.searchEvents(query);
      
      // Close the loading indicator
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (eventProvider.events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No events found for "$query"')),
        );
      }
    } catch (e) {
      // Close the loading indicator
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    }
  }
} 