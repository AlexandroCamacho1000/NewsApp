import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';

class GetArticleUseCase implements UseCase<DataState<List<ArticleEntity>>, bool> { // ← Cambia void por bool
  
  final ArticleRepository _articleRepository;

  GetArticleUseCase(this._articleRepository);
  
  @override
  Future<DataState<List<ArticleEntity>>> call({bool? params}) async { // ← Recibir parámetro
    print('🎯 USECASE: Obteniendo artículos (forceRefresh: ${params ?? false})');
    
    // Si params es null, usar false por defecto
    final forceRefresh = params ?? false;
    
    return await _articleRepository.getNewsArticles(forceRefresh: forceRefresh);
  }
}