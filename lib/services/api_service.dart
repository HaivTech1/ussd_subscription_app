import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateOrderResponse {
  final bool success;
  final String message;

  UpdateOrderResponse({required this.success, required this.message});
}

class ApiService {
  // final String baseUrl = 'https://app.megateq.net/api/v1';

  Future<String?> retrieveOrderUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('orderUrl');

    if (url != null) {
      return url;
    } else {
      return null;
    }
  }


  Future<String?> retrievePlanUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('planUrl');

    if (url != null) {
      return url;
    } else {
      return null;
    }
  }

  Future<String> retrieveOrderMethod() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String method =
        prefs.getString('orderMethod') ?? 'manual'; 
    return method;
  }

  Future<int> retrieveSelectedSimIndex() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int index =
        prefs.getInt('defaultSim') ?? 1;
    return index;
  }

  // Fetch order from API using the retrieved Order URL
  Future<dynamic> fetchOrder(String orderType) async {
    try {
      String? orderUrl = await retrieveOrderUrl(); 
      if (orderUrl != null) {
        final completeUrl = orderUrl.replaceAll('{type}', orderType);
        final response = await http.get(Uri.parse(completeUrl));
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Failed to load order');
        }
      } else {
        print('Order URL is null. Cannot fetch orders.');
        return null;
      }
    } catch (e) {
      print(e);
      return null; // Return null on error
    }
  }

  Future<dynamic> fetchPlans(String name) async {
    try {
      String? planUrl = await retrievePlanUrl();
      if (planUrl != null) {
        final completeUrl = planUrl.replaceAll('{network}', name);
        final response = await http.get(Uri.parse(completeUrl));
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Failed to load order');
        }
      } else {
        print('Order URL is null. Cannot fetch orders.');
        return null;
      }
    } catch (e) {
      print(e);
      return null; // Return null on error
    }
  }

  // Update order status via API
  Future<UpdateOrderResponse> updateOrderStatus(
      String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse(
            'https://app.megateq.net/api/v1/update/manual/transaction/$orderId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'status': status}),
      );

      // You can process the response here and create a meaningful object
      if (response.statusCode == 200) {
        // Parse the response body if it's in JSON format
        final data = jsonDecode(response.body);
        // Assuming the API sends a message in the response
        return UpdateOrderResponse(success: true, message: data['message']);
      } else {
        // Handle the case where the response is not 200
        return UpdateOrderResponse(
            success: false,
            message: 'Failed to update: ${response.reasonPhrase}');
      }
    } catch (e) {
      print(e);
      return UpdateOrderResponse(success: false, message: 'Error occurred: $e');
    }
  }

  // Fetch code dialers from local storage
  Future<List<Map<String, dynamic>>> fetchDialers() async {
    final prefs = await SharedPreferences.getInstance();
    String? dialersString = prefs.getString('code_dialers');
    if (dialersString != null) {
      List<dynamic> dialers = jsonDecode(dialersString);
      return dialers.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  // Add new code dialer to local storage
  Future<List<Map<String, dynamic>>> addDialer(
      Map<String, dynamic> inputs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> existingDialers = await fetchDialers();

      bool isDuplicate = existingDialers.any((d) =>
          d['network'] == inputs['network'] &&
          d['type'] == inputs['type'] &&
          d['plan'] == inputs['plan']);

      if (isDuplicate) {
        return existingDialers;
      }

      String id = DateTime.now().millisecondsSinceEpoch.toString();
      Map<String, dynamic> newData = {'id': id, ...inputs};

      existingDialers.add(newData);
      await prefs.setString('code_dialers', jsonEncode(existingDialers));

      return existingDialers;
    } catch (e) {
      print("Error adding dialer: $e");
      return [];
    }
  }

  // Delete a code dialer by ID
  Future<List<Map<String, dynamic>>> deleteDialer(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> existingDialers = await fetchDialers();

      existingDialers.removeWhere((d) => d['id'] == id);

      await prefs.setString('code_dialers', jsonEncode(existingDialers));

      return existingDialers;
    } catch (e) {
      print("Error deleting dialer: $e");
      return [];
    }
  }

  // Delete all code dialers from local storage
  Future<void> deleteAllDialers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_dialers', '[]');
  }

  // Update an existing code dialer
  Future<void> updateDialer(Map<String, dynamic> updatedDialer) async {
    List<Map<String, dynamic>> existingDialers = await fetchDialers();
    int index =
        existingDialers.indexWhere((d) => d['id'] == updatedDialer['id']);

    if (index != -1) {
      existingDialers[index] = {...existingDialers[index], ...updatedDialer};
      await setDialers(existingDialers);
    }
  }

  // Set the code dialers manually
  Future<void> setDialers(List<Map<String, dynamic>> dialers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_dialers', jsonEncode(dialers));
  }

  Future<List<Map<String, dynamic>>> fetchNetworks() async {
    final response = await http
        .get(Uri.parse('https://app.megateq.net/services/all/networks'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status']) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to load networks');
      }
    } else {
      throw Exception('Failed to load networks');
    }
  }

  Future<List<String>?> getSimPlans(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList('sim_data_$index');

    if (data != null) {
      return data;
    } else {
      return null;
    }
  }
}
