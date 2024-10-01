import 'package:flutter/material.dart';
import 'services/api_service.dart';

class EditDialerCodeScreen extends StatefulWidget {
  final Map<String, dynamic> dialer;

  EditDialerCodeScreen({required this.dialer});

  @override
  _EditDialerCodeScreenState createState() => _EditDialerCodeScreenState();
}

class _EditDialerCodeScreenState extends State<EditDialerCodeScreen> {
  final ApiService _apiService = ApiService();
  late TextEditingController _codeController;
  late TextEditingController _networkController;
  late TextEditingController _planController; // New field
  late TextEditingController _typeController; // New field
  late TextEditingController _pinController; // New PIN field

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.dialer['code']);
    _networkController = TextEditingController(text: widget.dialer['network']);
    _planController = TextEditingController(
        text: widget.dialer['plan']); // Initialize new field
    _typeController = TextEditingController(
        text: widget.dialer['type']); // Initialize new field
    _pinController = TextEditingController(
        text: widget.dialer['pin']); // Initialize new PIN field
  }

  @override
  void dispose() {
    _codeController.dispose();
    _networkController.dispose();
    _planController.dispose(); // Dispose new field
    _typeController.dispose(); // Dispose new field
    _pinController.dispose(); // Dispose new PIN field
    super.dispose();
  }

  Future<void> _updateDialerCode() async {
    Map<String, dynamic> updatedDialer = {
      'id': widget.dialer['id'],
      'code': _codeController.text,
      'network': _networkController.text,
      'plan': _planController.text, // Include new field
      'type': _typeController.text, // Include new field
      'pin': _pinController.text, // Include PIN field
    };

    await _apiService.updateDialer(updatedDialer);
    Navigator.pop(context, true); // Return true to indicate a successful update
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Dialer Code', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit the Dialer Code Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Please fill in the details below to update the dialer code.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),

              // TextField for Dialer Code
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Dialer Code',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // TextField for Network
              TextField(
                controller: _networkController,
                decoration: InputDecoration(
                  labelText: 'Network',
                  prefixIcon: Icon(Icons.network_cell),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // TextField for Type
              TextField(
                controller: _typeController, // New field input
                decoration: InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // TextField for Plan
              TextField(
                controller: _planController, // New field input
                decoration: InputDecoration(
                  labelText: 'Plan',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // TextField for PIN
              TextField(
                controller: _pinController, // New PIN field
                decoration: InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                obscureText: true, // To hide PIN input
              ),
              SizedBox(height: 20),

              // Save Changes Button
              ElevatedButton(
                onPressed: _updateDialerCode,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor: Colors.blue
                ),
                child: Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
