class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    }
    
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    
    return null;
  }
  
  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }
  
  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }
  
  // Username validation
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (value.length > 20) {
      return 'Username must be less than 20 characters';
    }
    
    // Username should only contain alphanumeric characters and underscores
    final usernameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegExp.hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    return null;
  }
  
  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Name can be empty
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }
  
  // Required name validation (for required fields)
  static String? validateRequiredName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }
  
  // Event title validation
  static String? validateEventTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an event title';
    }
    
    if (value.length < 3) {
      return 'Title must be at least 3 characters';
    }
    
    if (value.length > 50) {
      return 'Title must be less than 50 characters';
    }
    
    return null;
  }
  
  // Event description validation
  static String? validateEventDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an event description';
    }
    
    if (value.length < 10) {
      return 'Description must be at least 10 characters';
    }
    
    return null;
  }
  
  // Location validation
  static String? validateLocation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a location';
    }
    
    if (value.length < 3) {
      return 'Location must be at least 3 characters';
    }
    
    return null;
  }
  
  // Attendee limit validation
  static String? validateAttendeeLimit(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Can be empty (unlimited)
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    
    if (number < 0) {
      return 'Attendee limit cannot be negative';
    }
    
    return null;
  }
}