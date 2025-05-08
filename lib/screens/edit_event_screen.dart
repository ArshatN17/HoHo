import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../utils/validators.dart';
import '../utils/image_helper.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;
  
  const EditEventScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  
  // Event state
  EventModel? _event;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _eventTime = TimeOfDay.now();
  List<String> _tags = [];
  String _tagInput = '';
  File? _selectedImage;
  int _reminderMinutes = 60;
  bool _isUploading = false;
  bool _imageChanged = false;
  bool _isLoading = true;
  String? _existingImageUrl;
  late int _maxAttendees;
  
  // Reminder time options
  final List<Map<String, dynamic>> _reminderOptions = [
    {'label': '15 minutes before', 'value': 15},
    {'label': '30 minutes before', 'value': 30},
    {'label': '1 hour before', 'value': 60},
    {'label': '2 hours before', 'value': 120},
    {'label': '1 day before', 'value': 1440},
  ];
  
  @override
  void initState() {
    super.initState();
    // Initialize default values
    _tags = [];
    _maxAttendees = 0;
    _reminderMinutes = 60;
    _loadEventData();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEventData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final event = await eventProvider.getEvent(widget.eventId);
      
      if (event != null) {
        // Initialize controllers with existing data
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _locationController.text = event.location;
        _maxAttendeesController.text = event.maxAttendees > 0 ? event.maxAttendees.toString() : '';
        
        // Initialize date and time
        _eventDate = event.date;
        _eventTime = TimeOfDay(hour: event.date.hour, minute: event.date.minute);
        
        // Initialize other fields
        _tags = List.from(event.tags);
        _existingImageUrl = event.imageUrl;
        _maxAttendees = event.maxAttendees;
        _reminderMinutes = event.reminderMinutes;
      } else {
        // Handle event not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event not found')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final File? pickedImage = await ImageHelper.pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
        aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
      );
      
      if (pickedImage != null) {
        setState(() {
          _selectedImage = pickedImage;
          _imageChanged = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (picked != null && picked != _eventDate) {
      setState(() {
        _eventDate = picked;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _eventTime,
    );
    
    if (picked != null && picked != _eventTime) {
      setState(() {
        _eventTime = picked;
      });
    }
  }
  
  void _addTag() {
    if (_tagInput.isNotEmpty) {
      final newTag = _tagInput.trim();
      if (!_tags.contains(newTag)) {
        setState(() {
          _tags.add(newTag);
          _tagInput = '';
        });
      }
    }
  }
  
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }
  
  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Convert time and date to DateTime
      final eventDateTime = DateTime(
        _eventDate.year,
        _eventDate.month,
        _eventDate.day,
        _eventTime.hour,
        _eventTime.minute,
      );
      
      // Parse max attendees (0 means unlimited)
      final maxAttendees = _maxAttendeesController.text.isEmpty
          ? 0
          : int.parse(_maxAttendeesController.text);
      
      final success = await eventProvider.updateEvent(
        eventId: widget.eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: eventDateTime,
        location: _locationController.text.trim(),
        tags: _tags,
        imageFile: _imageChanged ? _selectedImage : null, // Only upload if image changed
        maxAttendees: maxAttendees,
        reminderMinutes: _reminderMinutes,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update event: ${eventProvider.error}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Event')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        actions: [
          TextButton.icon(
            onPressed: _isUploading ? null : _updateEvent,
            icon: const Icon(Icons.check),
            label: const Text('SAVE'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            image: _imageChanged && _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : _existingImageUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(_existingImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: _imageChanged == false && _existingImageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Add Event Image'),
                                  ],
                                )
                              : Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    if (_imageChanged || _existingImageUrl != null)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, size: 16),
                                            color: Colors.white,
                                            onPressed: _pickImage,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: Validators.validateEventTitle,
                    ),
                    const SizedBox(height: 16),
                    
                    // Date and Time
                    Row(
                      children: [
                        // Date Picker
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(dateFormat.format(_eventDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Time Picker
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(_eventTime.format(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Location
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: Validators.validateLocation,
                    ),
                    const SizedBox(height: 16),
                    
                    // Max Attendees
                    TextFormField(
                      controller: _maxAttendeesController,
                      decoration: const InputDecoration(
                        labelText: 'Max Attendees (leave empty for unlimited)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      keyboardType: TextInputType.number,
                      validator: Validators.validateAttendeeLimit,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: Validators.validateEventDescription,
                    ),
                    const SizedBox(height: 16),
                    
                    // Tags
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Add a tag...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _tagInput = value;
                            },
                            onFieldSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Display selected tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeTag(tag),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Reminder time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reminder Time',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          value: _reminderMinutes,
                          items: _reminderOptions.map((option) {
                            return DropdownMenuItem<int>(
                              value: option['value'],
                              child: Text(option['label']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _reminderMinutes = value ?? 60;
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attendees will be reminded before the event starts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _updateEvent,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(_isUploading ? 'Updating Event...' : 'Update Event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 