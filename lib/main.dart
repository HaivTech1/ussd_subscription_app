import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:sim_data/sim_data.dart';
import 'services/api_service.dart';
import 'services/ussd_service.dart';
import 'create_code_dialer.dart';
import 'dialer_code_list_screen.dart';
import 'setting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Manual Order Operator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SubscriptionScreen(),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final UssdHandler _ussdHandler = UssdHandler();
  String _statusMessage = '';
  List<SimCard> _simCards = [];
  TabController? _tabController;
  int _selectedSimIndex = 0;
  String _ussdCode = '';
  List<dynamic> _orders = []; // List to hold fetched orders
  List<dynamic> _codeDialers = []; // List to hold fetched code dialers
  bool _isLoading = false; // For loading spinner
  bool _isAutomatic = false;
  Timer? _automaticTimer; // Timer for automatic processing
  String _orderType = 'data';
  String _orderMethod = 'manual';

  @override
  void initState() {
    super.initState();
    _getSimCards();
    _fetchOrders(); // Fetch orders on initialization
    _fetchCodeDialers(); // Fetch code dialers on initialization
    _loadOrderMethod();
    _loadDefaultSim();
  }

  @override
  void dispose() {
    _automaticTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderMethod() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? method = prefs.getString('orderMethod');

    setState(() {
      _orderMethod = method ?? 'manual';
      _isAutomatic = _orderMethod == 'automatic';
    });
  }

  Future<void> _loadDefaultSim() async {
    int? index = await _apiService.retrieveSelectedSimIndex();
    setState(() {
      _selectedSimIndex = index;
    });
  }

  Future<void> _checkPermissions() async {
    if (await Permission.phone.request().isGranted) {
    } else {
      openAppSettings();
    }
  }

  Future<void> _setAutomaticProcessing(bool isAutomatic) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('automaticProcessing', isAutomatic);
  }

  void _startAutomaticProcessing() {
    _automaticTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      var pendingOrder = _orders.firstWhere(
        (order) => order['status'].toLowerCase() == 'success',
        orElse: () => null,
      );

      if (pendingOrder != null) {
        setState(() {
          _isLoading = true;
        });

        print(pendingOrder);
        _processSubscription(pendingOrder);

        setState(() {
          _isLoading = false;
          pendingOrder['status'] = 'processing';
        });
      } else {
        print("No pending orders at the moment");
      }
    });
  }

  void _stopAutomaticProcessing() {
    _automaticTimer?.cancel();
  }

  void _copyCodeAndShowModal(
      BuildContext context, String code, Map<String, dynamic> order) {
    // Copy the code to the clipboard
    Clipboard.setData(ClipboardData(text: code));

    // Show a modal with the code pre-filled in an input field
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Send Order Manually', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: TextEditingController(text: code),
            decoration: InputDecoration(
              labelText: 'USSD Code',
            ),
          ),
          actions: [
            // Add a Cancel button
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Add a Send button
            TextButton(
              child: Text('Send'),
              onPressed: () {
                Navigator.of(context).pop();
                _processSubscription(order);
              },
            ),
          ],
        );
      },
    );

    // Show a snackbar to confirm the copy action
    if (code.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code copied: $code')),
      );
    }
  }

  void updateModal(BuildContext context, String orderId, Function onUpdate,
      Function onCancel) {
    String? selectedStatus;
    List<String> statuses = ['success', 'pending', 'failed'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: statuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedStatus = value;
                },
                decoration: InputDecoration(
                  labelText: 'Select Status',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                onCancel();
                Navigator.of(context).pop(); // Close modal
              },
            ),
            TextButton(
              child: Text('Update'),
              onPressed: () async {
                if (selectedStatus != null) {
                  try {
                    // Call the onUpdate function with the selected status
                    onUpdate(selectedStatus);

                    // Wait for the API service to update the order status
                    var response = await _apiService.updateOrderStatus(
                        orderId!, selectedStatus!);

                    if (response.success) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Order status updated successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'There was an error updating the order status')),
                      );
                    }
                  } catch (e) {
                    // Handle any errors during the update process
                    print('Error updating status: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update order status')),
                    );
                  }
                } else {
                  // Handle the case where no status is selected
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a status')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _copyNumber(String code) {
    print(code);
    Clipboard.setData(ClipboardData(text: code));

    if (code.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code copied: $code')),
      );
    }
  }

  Future<void> _toggleOrderMethod(String method) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('orderMethod', method); // Save the method

    setState(() {
      _orderMethod = method; // Update the local state with the new method
      if (_orderMethod == 'automatic') {
        _startAutomaticProcessing(); // Start processing if the method is automatic
      } else {
        _stopAutomaticProcessing(); // Stop processing if it's manual
      }
    });
  }

  Future<void> requestCallPhonePermission() async {
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus == PermissionStatus.denied) {
      print('Permission denied');
    } else if (permissionStatus == PermissionStatus.granted) {
      print('Permission granted');
    }
  }

  Future<void> _getSimCards() async {
    try {
      SimData simData = await SimDataPlugin.getSimData();
      if (simData.cards.isNotEmpty) {
        setState(() {
          _simCards = simData.cards; // Store fetched SIM cards
          _ussdCode = _simCards[0].carrierName!.contains('MTN')
              ? '*310#'
              : '*320#'; // Adjust USSD code based on SIM card
          _tabController = TabController(length: _simCards.length, vsync: this);
        });
      } else {
        setState(() {
          _statusMessage = 'No SIM cards found';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching SIM cards: $e';
      });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    var orders = await _apiService.fetchOrder(_orderType);

    if (orders != null) {
      // If orders is a map with a list under 'data'
      if (orders is Map<String, dynamic> && orders['data'] != null) {
        setState(() {
          _orders = (orders['data'] as List<dynamic>).cast<dynamic>();
          _isLoading = false; // Stop loading
        });
      } else if (orders is List<dynamic>) {
        // If orders is directly a list
        setState(() {
          _orders = orders; // Store fetched orders
          _isLoading = false; // Stop loading
        });
      } else {
        // Handle unexpected data structure
        setState(() {
          _statusMessage = 'Unexpected data structure';
          _isLoading = false; // Stop loading
        });
      }
    } else {
      setState(() {
        _statusMessage = 'Failed to fetch orders';
        _isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _fetchCodeDialers() async {
    var dialers = await _apiService.fetchDialers();
    if (dialers != null) {
      setState(() {
        _codeDialers = (dialers as List<dynamic>).cast<dynamic>();
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to fetch code dialers';
      });
    }
  }

  void _processSubscription(Map<String, dynamic> orderData) async {
    setState(() {
      _isLoading = true; 
    });

    List<String>? data = await _apiService.getSimPlans(_selectedSimIndex);
    String? orderPlan = orderData['plan'];

    if (data != null && orderPlan != null && data.contains(orderPlan)) {
      await _handleUssdDial(orderData);
    } else if (data == null ||
        (orderPlan != null && !data.contains(orderPlan))) {
      _showToast(
          'Order plan is not in the whitelisted sim order list', Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUssdDial(Map<String, dynamic> orderData) async {
    final codeDialer = _getCodeDialer(_codeDialers, orderData);

    if (codeDialer != null) {
      String response =
          await _ussdHandler.dialUssd(codeDialer, _selectedSimIndex);
      print('Raw response: $response'); 

      _processUssdResponse(response, orderData);
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'There is no code dialer set for this network and type yet!';
        _showToast(_statusMessage, Colors.red);
      });
    }
  }

  void _processUssdResponse(String response, Map<String, dynamic> orderData) {
    List<String> errorMessages = [
      "sorry, your balance is too low for this transaction. kindly fund your wallet and retry.",
      "sorry,your balance is too low for this transaction.",
      "platformexception(ussd_plugin_ussd_execution_failure, ussd_return_failure, null, null)"
    ];

    String trimmedResponse = response.toLowerCase().trim();
    bool hasError =
        errorMessages.any((error) => trimmedResponse.contains(error));

    setState(() {
      _isLoading = false;

      if (hasError) {
        orderData['status'] = "failed";
        _statusMessage = trimmedResponse;
        _showToast(_statusMessage, Colors.red);
      } else {
        orderData['status'] = 'completed';
        _statusMessage = trimmedResponse;
        _showToast(_statusMessage, Colors.green);
        _orders.remove(orderData); 
      }
    });
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM, // Position of the toast
      timeInSecForIosWeb: 1, // Duration for iOS
      backgroundColor: color, // Background color of the toast
      textColor: Colors.white, // Text color of the toast
      fontSize: 16.0, // Font size of the toast
    );
  }

  String? _getCodeDialer(
      List<dynamic> codeDialers, Map<String, dynamic> orderData) {
    final normalizedNetwork = orderData['network']?.toLowerCase().trim() ?? "";
    final normalizedType = orderData['data_type']?.toLowerCase().trim() ?? "";
    final normalizedPlan = orderData['plan']?.toLowerCase().trim() ?? "";
    final normalizedServiceType = orderData['type']?.toLowerCase().trim() ?? "";

    final dialer = codeDialers.firstWhere(
      (dialer) {
        final dialerNetwork = dialer['network']?.toLowerCase().trim() ?? "";
        final dialerType = dialer['type']?.toLowerCase().trim() ?? "";
        final dialerPlan = dialer['plan']?.toLowerCase().trim() ?? "";

        // Check if it's airtime and don't require a plan
        if (normalizedServiceType == "airtime") {
          return dialerNetwork == normalizedNetwork &&
              dialerType == normalizedType;
        }

        // Check for data with plan
        return dialerNetwork == normalizedNetwork &&
            dialerType == normalizedType &&
            dialerPlan == normalizedPlan;
      },
      orElse: () => null,
    );

    if (dialer != null) {
      String code =
          dialer['code'].replaceAll("{number}", orderData['phone_number']);
      code = code.replaceAll("{pin}", dialer['pin'] ?? "");

      if (normalizedServiceType == "airtime") {
        final amount = orderData['amount']?.toString() ?? "";
        code = code.replaceAll("{amount}", amount);
      }

      return code;
    }
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.yellow;
      case 'unsuccessful':
        return Colors.red;
      case 'failed':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Order Operator', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        actions: [
          Row(
            mainAxisSize:
                MainAxisSize.min, 
            children: [
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _isAutomatic,
                  onChanged: (bool newValue) {
                    _toggleOrderMethod(newValue ? 'automatic' : 'manual');
                    setState(() {
                      _isAutomatic = newValue;
                    });
                  },
                  activeColor: Colors.white,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.shade400,
                  activeTrackColor: Colors.tealAccent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    10.0), // Adjust the padding value as needed
                child: Text(
                  _isAutomatic ? 'Automatic' : 'Manual',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),

        ],
      ),
      body: SafeArea(
        child: Stack(
          // Use Stack to overlay the loader
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _simCards.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2.0),
                                child: ChoiceChip(
                                  label: Text(_simCards[index].carrierName ??
                                      'SIM $index'),
                                  selected: _selectedSimIndex == index,
                                  backgroundColor: Colors.grey[300], 
                                  selectedColor: Colors.blue,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedSimIndex =
                                          selected ? index : _selectedSimIndex;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('Data'),
                            selected: _orderType == 'data',
                            backgroundColor: Colors.grey[300],
                            selectedColor: Colors.blue,
                            onSelected: (selected) {
                              setState(() {
                                _orderType = 'data';
                                _fetchOrders();
                              });
                            },
                          ),
                          SizedBox(width: 10),
                          ChoiceChip(
                            label: Text('Airtime'),
                            selected: _orderType == 'airtime',
                            backgroundColor: Colors.grey[300],
                            selectedColor: Colors.blue,
                            onSelected: (selected) {
                              setState(() {
                                _orderType = 'airtime';
                                _fetchOrders();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _simCards.isNotEmpty
                      ? RefreshIndicator(
                          onRefresh: _refreshData,
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: ListView.builder(
                              itemCount: _orders.length,
                              itemBuilder: (context, orderIndex) {
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 1),
                                  child: ListTile(
                                    title: Text(
                                      _orderType == 'data'
                                          ? '${_orders[orderIndex]['data_type']} ${_orders[orderIndex]['plan'] ?? 'No Plan Available'}'
                                          : '${_orders[orderIndex]['data_type'] ?? 'Unknown Data Type'} - ₦${_orders[orderIndex]['amount'] ?? 'N/A'}',
                                      style: TextStyle(
                                          fontSize:
                                              12), 
                                    ),
                                    subtitle: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                '${_orders[orderIndex]['phone_number'] ?? 'Unknown Number'}\n',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '${_orders[orderIndex]['status'] ?? 'Unknown Status'}',
                                            style: TextStyle(
                                              color: _getStatusColor(
                                                  _orders[orderIndex]
                                                          ['status'] ??
                                                      ''),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: FittedBox(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.send, size: 18),
                                            color: Colors.blue,
                                            onPressed: () {
                                              _processSubscription(
                                                  _orders[orderIndex]);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.dialpad, size: 18),
                                            color: Colors.green,
                                            onPressed: () async {
                                              String? code = _getCodeDialer(
                                                      _codeDialers,
                                                      _orders[orderIndex]) ??
                                                  'No code available';
                                              _copyCodeAndShowModal(context,
                                                  code, _orders[orderIndex]);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.copy, size: 18),
                                            color: Colors.green,
                                            onPressed: () async {
                                              _copyNumber(_orders[orderIndex]
                                                  ['phone_number']);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit, size: 18),
                                            color: Colors.orange,
                                            onPressed: () {
                                              updateModal(
                                                context,
                                                _orders[orderIndex]['id']
                                                    .toString(),
                                                (newStatus) {
                                                  setState(() {
                                                    _orders[orderIndex]
                                                        ['status'] = newStatus;
                                                  });
                                                },
                                                () {
                                                  // Handle the Cancel action if needed
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            'No SIM cards found',
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ),
                ),
              ],
            ),

            // Overlay loader
            if (_isLoading)
              Positioned.fill(
                // Makes the overlay fill the entire screen
                child: Container(
                  color: Colors.black54, // Optional: to dim the background
                  child: Center(
                    child: SizedBox(
                      width: 50, // Set the desired width
                      height: 50, // Set the desired height
                      child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 1.0),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
     floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'create',
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateCodeDialerScreen(),
                ),
              );
            },
            child: Icon(Icons.add),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'list',
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DialerCodeListScreen(),
                ),
              );
            },
            child: Icon(Icons.list),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'setting',
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingScreen(),
                ),
              );
            },
            child: Icon(Icons.settings),
          ),
        ],
      ),

    );
  }


// Method to refresh data
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true; 
    });

    await _getSimCards();
    await _fetchOrders();
    await _fetchCodeDialers(); 
    await _loadOrderMethod();
    await _loadDefaultSim();

    setState(() {
      _isLoading = false; 
    });
  }
}
