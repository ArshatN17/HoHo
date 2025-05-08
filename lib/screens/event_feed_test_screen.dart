import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';

class EventFeedTestScreen extends StatefulWidget {
  const EventFeedTestScreen({Key? key}) : super(key: key);

  @override
  State<EventFeedTestScreen> createState() => _EventFeedTestScreenState();
}

class _EventFeedTestScreenState extends State<EventFeedTestScreen> {
  // Test variables
  String? _selectedLocation;
  List<String> _selectedTags = [];
  bool _onlyUpcoming = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Test results
  List<EventModel> _events = [];
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }
  
  Future<void> _loadFilterOptions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.loadFilterOptions();
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
  
  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _events = [];
      _error = null;
    });
    
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Apply filters
      eventProvider.onlyUpcoming = _onlyUpcoming;
      eventProvider.startDate = _startDate;
      eventProvider.endDate = _endDate;
      eventProvider.location = _selectedLocation;
      eventProvider.tagFilter = _selectedTags.isEmpty ? null : _selectedTags;
      
      // Refresh events (this should apply the filters)
      await eventProvider.refreshEvents();
      
      // Get the filtered results
      setState(() {
        _events = List.from(eventProvider.events);
      });
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
    final eventProvider = Provider.of<EventProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Feed Test'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test description
                  const Text(
                    'Test Event Feed Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Apply filters and run test to check if the event list updates correctly',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(height: 32),
                  
                  // Test controls
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location filter
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedLocation,
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
                    onChanged: (value) {
                      setState(() {
                        _selectedLocation = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Tags filter
                  const Text('Tags'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eventProvider.availableTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
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
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Colors.white,
                        elevation: isSelected ? 2 : 0,
                        pressElevation: 4,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date range filter
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text: _startDate != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                : '',
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text: _endDate != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : '',
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Only upcoming filter
                  SwitchListTile(
                    title: const Text('Only Upcoming Events'),
                    value: _onlyUpcoming,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _onlyUpcoming = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Run test button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _runTest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Run Test'),
                    ),
                  ),
                  const Divider(height: 32),
                  
                  // Test results
                  const Text(
                    'Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_error!),
                        ],
                      ),
                    )
                  else if (_events.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('No events match the current filters or the test has not been run yet.'),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found ${_events.length} events',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(event.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Location: ${event.location}'),
                                    Text('Date: ${event.formattedDate}'),
                                    if (event.tags.isNotEmpty)
                                      Text('Tags: ${event.tags.join(", ")}'),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
} 