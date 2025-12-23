import 'package:dio/dio.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart'; // ✅ IMPORT CORRECTO

class GetArticleUseCase implements UseCase<DataState<List<ArticleEntity>>, bool> {
  final ArticleRepository _articleRepository;

  GetArticleUseCase(this._articleRepository);
  
  @override
  Future<DataState<List<ArticleEntity>>> call({bool? params}) async {
    try {
      final result = await _articleRepository.getNewsArticles(
        forceRefresh: params ?? false,
      );
      return result;
    } catch (e) {
      return DataFailed(
        DioException(
          requestOptions: RequestOptions(path: '/articles'),
          error: e.toString(),
          type: DioExceptionType.connectionError,
        )
      );
    }
  }
}