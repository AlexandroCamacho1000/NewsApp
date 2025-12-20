import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';

import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';
import '../create_article/create_article.dart'; // ⭐⭐ 1. AÑADE ESTE IMPORT

class DailyNews extends StatefulWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  _DailyNewsState createState() => _DailyNewsState();
}

class _DailyNewsState extends State<DailyNews> {
  @override
  void initState() {
    super.initState();
    print('🏠 DailyNews: initState()');
    
    Future.microtask(() {
      print('🔄 Disparando GetArticles...');
      final bloc = context.read<RemoteArticlesBloc>();
      if (bloc.state is! RemoteArticlesDone) {
        bloc.add(const GetArticles());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage();
  }

  AppBar _buildAppbar(BuildContext context) {
    return AppBar(
      title: const Text('Daily News', style: TextStyle(color: Colors.black)),
      actions: [
        GestureDetector(
          onTap: () => _onShowSavedArticlesViewTapped(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.bookmark, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildPage() {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, state) {
        print('📱 BlocBuilder - Estado: $state');
        
        if (state is RemoteArticlesLoading) {
          return Scaffold(
              appBar: _buildAppbar(context),
              body: const Center(child: CupertinoActivityIndicator()));
        }
        
        if (state is RemoteArticlesError) {
          return Scaffold(
              appBar: _buildAppbar(context),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 50, color: Colors.red),
                    const SizedBox(height: 10),
                    Text('Error: ${state.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        context.read<RemoteArticlesBloc>().add(const GetArticles());
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ));
        }
        
        if (state is RemoteArticlesDone) {
          return _buildArticlesPage(context, state.articles ?? []);
        }
        
        return Scaffold(
          appBar: _buildAppbar(context),
          body: const Center(child: CupertinoActivityIndicator()),
        );
      },
    );
  }

  Widget _buildArticlesPage(BuildContext context, List<ArticleEntity> articles) {
    print('✅ DailyNews: Mostrando ${articles.length} artículos');
    
    if (articles.isEmpty) {
      return Scaffold(
        appBar: _buildAppbar(context),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text('No hay artículos disponibles',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 10),
              Text('Intenta agregar nuevos artículos',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        // ⭐⭐ AÑADE TAMBIÉN EL BOTÓN AQUÍ (opcional)
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateArticlePage(),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      );
    }
    
    List<Widget> articleWidgets = [];
    for (var article in articles) {
      articleWidgets.add(ArticleWidget(
        article: article,
        onArticlePressed: (article) => _onArticlePressed(context, article),
      ));
    }

    return Scaffold(
      appBar: _buildAppbar(context),
      body: ListView(
        children: articleWidgets,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push( // ⭐⭐ 2. CAMBIA ESTA LÍNEA
            context,
            MaterialPageRoute(
              builder: (context) => const CreateArticlePage(), // ⭐⭐ 3. Y ESTA
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onArticlePressed(BuildContext context, ArticleEntity article) {
    Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
  }

  void _onShowSavedArticlesViewTapped(BuildContext context) {
    Navigator.pushNamed(context, '/SavedArticles');
  }
}