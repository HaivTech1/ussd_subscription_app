import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_data/sim_data.dart';
import 'package:ussd_subscription_app/services/api_service.dart';
import 'setting.dart';
import 'dart:async';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String orderUrl = '';
  String planUrl = '';
  String _orderMethod = 'manual';
  final TextEditingController _orderUrlController = TextEditingController();
  final TextEditingController _planUrlController = TextEditingController();

  List<SimCard> _simCards = [];
  List _plans = [];

  int _selectedSimIndex = 0;
  String _statusMessage = '';
  TabController? _tabController;
  String _ussdCode = '';

  @override
  void initState() {
    super.initState();
    _getSimCards();
    _loadOrderUrl();
    _loadOrderMethod();
    _loadPlanUrl();
    _loadDefaultSim();
  }

  @override
  void dispose() {
    _orderUrlController.dispose();
    _planUrlController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderUrl() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedUrl = prefs.getString('orderUrl');
      if (savedUrl != null) {
        setState(() {
          orderUrl = savedUrl;
          _orderUrlController.text = orderUrl;
        });
      }
    } catch (e) {
      print("Error loading order URL: $e");
    }
  }

  Future<void> _loadPlanUrl() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedUrl = prefs.getString('planUrl');
      if (savedUrl != null) {
        setState(() {
          planUrl = savedUrl;
          _planUrlController.text = planUrl;
        });
      }
    } catch (e) {
      print("Error loading URL: $e");
    }
  }

  Future<void> _loadDefaultSim() async {
    int? index = await _apiService.retrieveSelectedSimIndex();
    setState(() {
      _selectedSimIndex = index;
    });
  }

  Future<void> _loadPlans(String name) async {
    try {
      var response = await _apiService.fetchPlans(name);
      _plans = response;
    } catch (e) {
      print("Error fetching plans: $e");
    }
  }

  Future<void> _loadOrderMethod() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedMethod = prefs.getString('orderMethod');
      setState(() {
        _orderMethod = savedMethod ?? 'manual';
      });
    } catch (e) {
      print("Error loading order method: $e");
    }
  }

  Future<void> _saveData() async {
    String newUrl = _orderUrlController.text;
    String planUrlText = _planUrlController.text;

    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a valid URL!'),
      ));
      return;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('orderUrl', newUrl);
      await prefs.setString('planUrl', planUrlText);

      setState(() {
        orderUrl = newUrl;
        planUrl = planUrlText;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data saved successfully!'),
      ));
    } catch (e) {
      print("Error saving data: $e");
    }
  }

  Future<void> _saveOrderMethod(String method) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('orderMethod', method);
      setState(() {
        _orderMethod = method;
      });
    } catch (e) {
      print("Error saving order method: $e");
    }
  }

  Future<void> _saveSelectedPlan(
      SimCard simCard, List<String> selectedDataTypes) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'sim_data_${simCard.slotIndex}', selectedDataTypes);
      print(
          "Data types saved for SIM ${simCard.carrierName}: $selectedDataTypes");
    } catch (e) {
      print("Error saving selected plans: $e");
    }
  }

  Future<List<String>> _getSelectedPlans(SimCard simCard) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('sim_data_${simCard.slotIndex}') ?? [];
    } catch (e) {
      print("Error getting selected plans: $e");
      return [];
    }
  }

  Future<void> _getSimCards() async {
    try {
      SimData simData = await SimDataPlugin.getSimData();
      if (simData.cards.isNotEmpty) {
        setState(() {
          _simCards = simData.cards;
          _ussdCode =
              _simCards[0].carrierName!.contains('MTN') ? '*310#' : '*320#';
          _tabController = TabController(length: _simCards.length, vsync: this);
        });
        String? simName = _simCards[0].carrierName;
        _loadPlans(simName);
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

  void _updateSimSelected(bool selected, SimCard simCard, int index) async {
    if (selected) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('defaultSim', index);

      setState(() {
        _selectedSimIndex = index;
      });

      await _loadPlans(simCard.carrierName);

      _showSimSettingsDialog(simCard);
    }
  }

  void _showSimSettingsDialog(SimCard simCard) async {
    List<String> _selectedDataTypes = await _getSelectedPlans(simCard);
    List<String> planNames = [];
    for (var plan in _plans) {
      if (plan['name'] != null) {
        planNames.add(plan['name']);
      }
    }
    List<String> dataTypes = planNames;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('SIM Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Carrier Name: ${simCard.carrierName}',
                    style: TextStyle(fontSize: 16)),
                Text('Subscription ID: ${simCard.subscriptionId}',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                MultiSelectDialogField(
                  items: dataTypes
                      .map((type) => MultiSelectItem(type, type))
                      .toList(),
                  title: Text(
                    "Whitelist plans to Sim",
                    style: TextStyle(fontSize: 16),
                  ),
                  selectedColor: Colors.blue,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey),
                  ),
                  buttonIcon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                  buttonText: Text("Select Plans",
                      style: TextStyle(fontSize: 16, color: Colors.black)),
                  initialValue: _selectedDataTypes,
                  onConfirm: (values) {
                    _selectedDataTypes = values.cast<String>();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveSelectedPlan(simCard, _selectedDataTypes);
                Navigator.of(context).pop();
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
          Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Device Sim Slot',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
                              label: Text(
                                  _simCards[index].carrierName ?? 'SIM $index'),
                              selected: _selectedSimIndex == index,
                              backgroundColor: Colors.grey[300],
                              selectedColor: Colors.blue,
                              onSelected: (selected) {
                                _updateSimSelected(
                                    selected, _simCards[index], index);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),
            Text('Set Order Method', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: _orderMethod,
              items: <String>['automatic', 'manual']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.capitalize()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _saveOrderMethod(newValue);
                }
              },
            ),
            SizedBox(height: 5),
            TextField(
              controller: _orderUrlController,
              decoration: InputDecoration(
                labelText: 'Order URL',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _planUrlController,
              decoration: InputDecoration(
                labelText: 'Data Plan URL',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                    backgroundColor: Colors.blue
              ),
              child: Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension method to capitalize the first letter of the string
extension StringCasingExtension on String {
  String capitalize() {
    return this.isEmpty ? this : this[0].toUpperCase() + this.substring(1);
  }
}
