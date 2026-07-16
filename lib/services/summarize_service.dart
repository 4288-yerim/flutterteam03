import 'package:dio/dio.dart';

class SummarizeService {
  final Dio _dio = Dio();
  final String baseUrl = "http://[탄력적 IP]:8000"; // 본인 탄력적 IP로 교체

  Future<Map<String, dynamic>> summarizeDocument(String filePath) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        "$baseUrl/summarize",
        data: formData,
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception("요약 요청 실패: ${e.message}");
    }
  }
}