import 'package:ussd_service/ussd_service.dart';
import 'package:ussd_advanced/ussd_advanced.dart';

class UssdHandler {
  Future<String> dialUssd(String code, int subscriptionId) async {
    try {
      String responseMessage = await UssdService.makeRequest(
        subscriptionId,
        code,
      );
      return responseMessage;
    } catch (e) {
      print('USSD Error: $e');
      if (e is Exception) {
        return 'Error ${e.toString()}';
      } else {
        return 'Error occurred while dialing USSD';
      }
    }
  }

  Future<String?> dialSingleSessionUssd(String code, int subscriptionId) async {
    try {
      String? responseMessage = await UssdAdvanced.sendAdvancedUssd(
        code: code,
        subscriptionId: subscriptionId,
      );
      return responseMessage;
    } catch (e) {
      print('USSD Error: $e');
      return 'Error occurred while dialing USSD';
    }
  }

 Future<String?> dialMultiSessionUssd(
      String code, int subscriptionId, List<String> inputs) async {
    try {
      // Start the multi-session USSD by dialing the initial code
      String? initialResponse = await UssdAdvanced.multisessionUssd(
          code: code, subscriptionId: subscriptionId);
      print("Initial Response: $initialResponse");

      // Wait a moment before sending inputs
      await Future.delayed(Duration(seconds: 2));

      // Loop through the inputs and send them step by step
      String? response = initialResponse;
      for (String input in inputs) {
        response = await UssdAdvanced.sendMessage(input);
        print("Response after input '$input': $response");

        // Wait a moment after each input
        await Future.delayed(Duration(seconds: 2));
      }

      // Cancel the session when all inputs are sent
      await UssdAdvanced.cancelSession();
      return response ?? 'No response received';
    } catch (e) {
      print('USSD Error: $e');
      return 'Error occurred: $e';
    }
  }

  Future<String?> sendMessage(String message) async {
    try {
      String? responseMessage = await UssdAdvanced.sendMessage(message);
      return responseMessage;
    } catch (e) {
      print('USSD Error: $e');
      return 'Error occurred while sending message';
    }
  }

  Future<void> cancelSession() async {
    try {
      await UssdAdvanced.cancelSession();
    } catch (e) {
      print('USSD Error: $e');
    }
  }
}
