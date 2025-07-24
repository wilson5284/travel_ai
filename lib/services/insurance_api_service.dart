// In lib/services/insurance_api_service.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class InsuranceApiService {
  static Future<Map<String, dynamic>> getInsuranceSuggestions({
    required String destination,
    required int durationDays,
    String activities = '', // Optional activities
  }) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        // Make sure you use the key from api_constants.dart if you're managing it there.
        // For direct debugging:
        apiKey: 'AIzaSyATwBN9CJBt5fl9BNJ8k3WahI2HF8CY94g', // Your Gemini API key here
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );

      // <--- UNCOMMENT THIS ENTIRE PROMPT BLOCK BELOW --->
      String prompt = '''
      As a travel insurance advisor, provide detailed suggestions for travel insurance based on the following trip details.
      
      Include suggestions for common types of travel insurance policies (e.g., single-trip, annual multi-trip, adventure sports, comprehensive) and mention general categories of providers (e.g., major international insurers, local agencies, credit card benefits) or well-known examples of travel insurance providers if relevant to their trip, but always emphasize that this is for informational purposes only.
      
      **Crucial Disclaimer:** The final suggestion in the list MUST be a clear warning/disclaimer stating: "Please Note: These suggestions are AI-generated for informational purposes only and do not constitute financial or legal advice. Insurance needs are highly individual. Always consult a licensed insurance professional, thoroughly read policy documents, and compare multiple options before making a purchase. Prices and coverage vary significantly."
      
      Trip Details:
      - Destination: $destination
      - Duration: $durationDays days
      ${activities.isNotEmpty ? '- Planned Activities: $activities' : ''}
      
      Please provide the suggestions in a JSON format with a single key 'insurance_suggestions' which contains a list of strings.
      
      Example of desired JSON output:
      {
        "insurance_suggestions": [
          "For a trip of $durationDays days to $destination, a single-trip comprehensive policy is usually recommended, covering medical emergencies, trip cancellation, and lost luggage.",
          "If you travel frequently, consider an annual multi-trip policy from major international insurers like Allianz, AIG, or World Nomads, which might be more cost-effective.",
          "Since you mentioned activities like '$activities', ensure your policy includes an adventure sports rider, often available through specialized insurers.",
          "Check benefits from your credit card providers (e.g., Visa, Mastercard) as some premium cards offer basic travel insurance which might supplement a dedicated policy.",
          "Please Note: These suggestions are AI-generated for informational purposes only and do not constitute financial or legal advice. Insurance needs are highly individual. Always consult a licensed insurance professional, thoroughly read policy documents, and compare multiple options before making a purchase. Prices and coverage vary significantly."
        ]
      }
      ''';
      // <--- END UNCOMMENTED BLOCK --->

      print('Sending prompt to Gemini: $prompt'); // <--- This print will now show the actual prompt
      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      print('Received response from Gemini: $responseText');

      final jsonPattern = RegExp(r'\{[\s\S]*\}');
      final match = jsonPattern.firstMatch(responseText);

      if (match == null) {
        print('JSON pattern not found in response.'); // <--- ADD THIS
        return {'error': 'Failed to parse API response from Gemini. It did not return a valid JSON format. Raw response: $responseText'};
      }

      final Map<String, dynamic> suggestionsData = json.decode(match.group(0)!);
      print('Parsed JSON data: $suggestionsData'); // <--- ADD THIS

      if (!suggestionsData.containsKey('insurance_suggestions') || !(suggestionsData['insurance_suggestions'] is List)) {
        print('JSON structure invalid: missing "insurance_suggestions" list.'); // <--- ADD THIS
        return {'error': 'Invalid JSON structure from Gemini: missing "insurance_suggestions" list. Raw: $responseText'};
      }

      return suggestionsData;
    } catch (e) {
      print('Error in getInsuranceSuggestions: $e'); // This print is already there
      return {'error': 'An error occurred while fetching insurance suggestions: $e'};
    }
  }
}