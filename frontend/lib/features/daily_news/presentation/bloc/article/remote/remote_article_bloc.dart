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
    on<RefreshArticles>(onGetArticles);
  }

  void onGetArticles(RemoteArticlesEvent event, Emitter<RemoteArticlesState> emit) async {
    print('🎭 BLOC: Ejecutando onGetArticles...');
    print('📩 Evento recibido: ${event.runtimeType}');
    
    // ✅ DETERMINAR SI ES RECARGA FORZADA
    final forceRefresh = event is RefreshArticles;
    print('🔄 BLOC: forceRefresh = $forceRefresh');
    
    try {
      // ✅ CORRECCIÓN CRÍTICA: Pasar el parámetro forceRefresh
      final dataState = await _getArticleUseCase.call(params: forceRefresh);
      
      print('📊 BLOC: UseCase completado (forceRefresh: $forceRefresh)');
      print('📊 BLOC: Resultado tipo: ${dataState.runtimeType}');

      if (dataState is DataSuccess) {
        if (dataState.data != null) {
          print('✅ BLOC: ${dataState.data!.length} artículos cargados');
          emit(RemoteArticlesDone(dataState.data!));
        } else {
          emit(const RemoteArticlesDone([]));
        }
      } 
      
      else if (dataState is DataFailed) {
        print('❌ BLOC: DataFailed recibido');
        emit(RemoteArticlesError(
          dataState.error ?? DioException(
            requestOptions: RequestOptions(path: '/articles'),
            error: 'Error desconocido en DataFailed',
            type: DioExceptionType.unknown,
          )
        ));
      }
      
    } catch (e) {
      print('💥 BLOC: Excepción: $e');
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