import '../core/network/api_client.dart';
import '../models/prediction.dart';

class PredictionService {
  const PredictionService(this._client);
  final ApiClient _client;

  Future<List<Prediction>> detectIssues({
    required String base64Image,
    required String mimeType,
  }) async {
    final response = await _client.postJsonValue('api/getPredictions', {
      'base64Image': base64Image,
      'mimeType': mimeType,
    });
    if (response is Map && response['success'] == false) {
      throw PredictionException(
        response['message']?.toString() ?? 'Prediction service failed.',
        code: response['code']?.toString(),
      );
    }
    return Prediction.parseList(response);
  }
}

class PredictionException implements Exception {
  const PredictionException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}