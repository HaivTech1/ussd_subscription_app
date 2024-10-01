import 'package:flutter/material.dart';
import 'services/api_service.dart';

class CreateCodeDialerScreen extends StatefulWidget {
  @override
  _CreateCodeDialerScreenState createState() => _CreateCodeDialerScreenState();
}

class _CreateCodeDialerScreenState extends State<CreateCodeDialerScreen> {
  String serviceType = 'data'; // Default service type
  String selectedNetwork = ''; // To hold the selected network
  String selectedType = ''; // To hold the selected type
  String selectedPlan = ''; // To hold the selected plan
  String code = ''; // USSD code
  String pin = ''; // PIN input

  List<Map<String, dynamic>> networks =
      []; // List of networks fetched from the API

  final TextEditingController _networkController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // List of service types
  final List<String> serviceTypes = ['data', 'airtime'];

  @override
  void initState() {
    super.initState();
    fetchNetworks(); // Fetch networks when the screen initializes
  }

  Future<void> fetchNetworks() async {
    final apiService = ApiService();
    networks = await apiService.fetchNetworks();
    setState(() {
      if (networks.isNotEmpty) {
        selectedNetwork =
            networks[0]['name']; // Set default network if available
        _networkController.text =
            selectedNetwork; // Populate the network text field
      }
    });
  }

  Future<void> _saveDialerCode() async {
   if (serviceType.isEmpty ||
        selectedNetwork.isEmpty ||
        selectedType.isEmpty ||
        (selectedType == 'data' &&
            selectedPlan
                .isEmpty) || 
        code.isEmpty ||
        pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all fields!'),
      ));
      return;
    }

    final inputs = {
      'network': selectedNetwork,
      'type': selectedType,
      'plan': selectedPlan,
      'code': code, // Include the USSD code
    };

    final apiService = ApiService();
    List<Map<String, dynamic>> updatedDialers =
        await apiService.addDialer(inputs);

    if (updatedDialers.isNotEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dialer code saved successfully!'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('This dialer code already exists!'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Code Dialer',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                'Create a New Dialer Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Please fill in the details below to create a new dialer code.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),

              // Dropdown for service type selection
              DropdownButtonFormField<String>(
                value: serviceType,
                decoration: InputDecoration(
                  labelText: 'Service Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                items: serviceTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    serviceType = newValue!;
                    fetchNetworks(); // Fetch networks again based on selected service type
                  });
                },
              ),
              SizedBox(height: 12),

              // Text field for network input
              TextField(
                controller: _networkController,
                decoration: InputDecoration(
                  labelText: 'Network',
                  prefixIcon: Icon(Icons.network_cell),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  selectedNetwork = value; // Update selected network
                },
              ),
              SizedBox(height: 12),

              // Text field for type input
              TextField(
                controller: _typeController,
                decoration: InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  selectedType = value; // Update selected type
                },
              ),
              SizedBox(height: 12),

              // Text field for plan input
              TextField(
                controller: _planController,
                decoration: InputDecoration(
                  labelText: 'Plan',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  selectedPlan = value; // Update selected plan
                },
              ),
              SizedBox(height: 12),

              // TextField for USSD code
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'USSD Code',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  code = value; // Update the code state variable
                },
              ),
              SizedBox(height: 12),

              // TextField for entering PIN
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'Enter Pin',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                obscureText: true,
                onChanged: (value) {
                  pin = value; // Update the pin state variable
                },
              ),
              SizedBox(height: 20),

              // Save Dialer Code Button
              ElevatedButton(
                onPressed: _saveDialerCode,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor: Colors.blue
                ),
                child: Text(
                  'Save Dialer Code',
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
