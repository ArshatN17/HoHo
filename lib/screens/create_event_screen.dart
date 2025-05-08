import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/event_provider.dart';
import '../utils/validators.dart';
import '../utils/image_helper.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({Key? key}) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  
  File? _selectedImage;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _eventTime = TimeOfDay.now();
  String _tagInput = '';
  List<String> _tags = [];
  int _reminderMinutes = 60;
  bool _isUploading = false;
  bool _imageChanged = false;
  
  // Reminder options in minutes
  final List<Map<String, dynamic>> _reminderOptions = [
    {'label': '15 minutes before', 'value': 15},
    {'label': '30 minutes before', 'value': 30},
    {'label': '1 hour before', 'value': 60},
    {'label': '2 hours before', 'value': 120},
    {'label': '1 day before', 'value': 1440},
    {'label': '2 days before', 'value': 2880},
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
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
    if (_tagInput != null && _tagInput!.isNotEmpty) {
      final newTag = _tagInput!.trim();
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
  
  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Get combined date and time
      final eventDateTime = DateTime(
        _eventDate.year,
        _eventDate.month,
        _eventDate.day,
        _eventTime.hour,
        _eventTime.minute,
      );
      
      // Parse max attendees
      int? maxAttendees;
      if (_maxAttendeesController.text.isNotEmpty) {
        maxAttendees = int.tryParse(_maxAttendeesController.text.trim());
      }
      
      // Create the event
      final eventId = await eventProvider.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: eventDateTime,
        location: _locationController.text.trim(),
        tags: _tags,
        imageFile: _selectedImage,
        maxAttendees: maxAttendees ?? 0,
        reminderMinutes: _reminderMinutes,
      );
      
      if (eventId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar(eventProvider.error ?? 'Failed to create event');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating event: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        actions: [
          TextButton.icon(
            onPressed: _isUploading ? null : _createEvent,
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
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Add Event Image'),
                                  ],
                                )
                              : null,
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
                        onPressed: _isUploading ? null : _createEvent,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(_isUploading ? 'Creating Event...' : 'Create Event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 