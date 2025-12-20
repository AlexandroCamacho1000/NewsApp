import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';

class RemoteArticlesBloc extends Bloc<RemoteArticlesEvent, RemoteArticlesState> {
  
  final GetArticleUseCase _getArticleUseCase;
  
  RemoteArticlesBloc(this._getArticleUseCase) : super(const RemoteArticlesLoading()) {
    on<GetArticles>(onGetArticles);
  }

  void onGetArticles(GetArticles event, Emitter<RemoteArticlesState> emit) async {
    print('🎭 Bloc: Ejecutando onGetArticles...');
    
    try {
      final dataState = await _getArticleUseCase();
      print('📊 Bloc: Resultado: $dataState');

      if (dataState is DataSuccess) {
        // ✅ CORREGIDO: Verificar null antes de usar !
        if (dataState.data != null) {
          emit(RemoteArticlesDone(dataState.data!));
        } else {
          emit(const RemoteArticlesDone([]));
        }
      } 
      
      else if (dataState is DataFailed) {
        print('❌ Bloc: DataFailed recibido');
        // ✅ CORREGIDO: Usar DioException, no String
        emit(RemoteArticlesError(
          dataState.error ?? DioException(
            requestOptions: RequestOptions(path: '/articles'),
            error: 'Error desconocido en DataFailed',
            type: DioExceptionType.unknown,
          )
        ));
      }
      
    } catch (e) {
      print('💥 Bloc: Excepción: $e');
      // ✅ CORREGIDO: Convertir cualquier excepción a DioException
      emit(RemoteArticlesError(
        DioException(
          requestOptions: RequestOptions(path: '/articles'),
          error: e.toString(),
          type: DioExceptionType.unknown,
        )
      ));
    }
  }
}