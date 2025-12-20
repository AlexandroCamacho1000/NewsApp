import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../domain/entities/article.dart';

abstract class RemoteArticlesState extends Equatable {
  final List<ArticleEntity>? articles;
  final DioError? error;
  
  const RemoteArticlesState({this.articles, this.error});
  
  // ✅ CORREGIDO: Cambia Object a Object? y quita los !
  @override
  List<Object?> get props => [articles, error];
}

class RemoteArticlesLoading extends RemoteArticlesState {
  const RemoteArticlesLoading();
  
  // Opcional: Agrega toString para debugging
  @override
  String toString() => 'RemoteArticlesLoading';
}

class RemoteArticlesDone extends RemoteArticlesState {
  const RemoteArticlesDone(List<ArticleEntity> article) : super(articles: article);
  
  @override
  String toString() => 'RemoteArticlesDone(articles: ${articles?.length ?? 0})';
}

class RemoteArticlesError extends RemoteArticlesState {
  const RemoteArticlesError(DioError error) : super(error: error);
  
  @override
  String toString() => 'RemoteArticlesError(error: $error)';
}