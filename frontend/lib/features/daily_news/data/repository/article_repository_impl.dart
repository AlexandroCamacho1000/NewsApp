import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleRepositoryImpl implements ArticleRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  ArticleRepositoryImpl({
    required this.firestore,
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  @override
  Future<DataState<List<ArticleEntity>>> getNewsArticles() async {
    print('🚀 OBTENIENDO ARTÍCULOS CON AUTORES');
    
    try {
      final snapshot = await firestore.collection('articles').get();
      print('📚 ${snapshot.docs.length} artículos encontrados');
      
      final articles = <ArticleEntity>[];
      
      for (final doc in snapshot.docs) {
        try {
          final article = await _createArticleWithAuthor(doc);
          articles.add(article);
        } catch (e) {
          print('⚠️ Error procesando artículo ${doc.id}: $e');
        }
      }
      
      print('\n🎉 ${articles.length} artículos procesados exitosamente');
      return DataSuccess(articles);
      
    } catch (e) {
      print('💥 ERROR CRÍTICO: $e');
      return DataFailed(DioException(
        requestOptions: RequestOptions(path: '/articles'),
        error: 'Error: $e',
        type: DioExceptionType.connectionError,
      ));
    }
  }

  @override
  Future<void> saveArticle(ArticleEntity article) async {
    try {
      print('💾 Guardando artículo en Firestore: "${article.title}"');
      
      // 1. Datos en EXACTA estructura de article1 (con null-safety)
      final articleData = {
        'title': article.title ?? 'Sin título',
        'content': article.content ?? '',
        'excerpt': (article.description?.isNotEmpty ?? false)
            ? article.description!
            : _generateExcerpt(article.content ?? ''),
        'thumbnailURL': (article.urlToImage?.isNotEmpty ?? false)
            ? article.urlToImage!
            : _getFallbackImage(article.title ?? ''),
        'authorId': 'utJbxTZ7ezTot9wVOTAh', // ← Mismo ID que article1
        'published': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 Datos a guardar:');
      articleData.forEach((key, value) {
        print('   $key: $value');
      });
      
      // 2. Guardar con .add() (como article1, article2, article3)
      final docRef = await firestore
          .collection('articles')
          .add(articleData);
      
      print('✅ Artículo guardado con ID: ${docRef.id}');
      print('📍 Ruta: articles/${docRef.id}');
      
      // 3. También guardar el autor en colección users si no existe
      await _ensureAuthorExists('utJbxTZ7ezTot9wVOTAh', article.author ?? 'Anónimo');
      
    } catch (e) {
      print('❌ ERROR en saveArticle: $e');
      rethrow;
    }
  }

  Future<void> _ensureAuthorExists(String authorId, String authorName) async {
    try {
      final userRef = firestore.collection('users').doc(authorId);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        await userRef.set({
          'name': authorName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('👤 Autor creado en users: $authorName');
      } else {
        print('👤 Autor ya existe: $authorName');
      }
    } catch (e) {
      print('⚠️ Error creando autor: $e');
    }
  }

  Future<ArticleEntity> _createArticleWithAuthor(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('\n📰 Procesando: "$title"');
    
    // 1. Obtener imagen
    final gsUrl = data['thumbnailURL']?.toString()?.trim() ?? 
                  data[' thumbnailURL']?.toString()?.trim() ?? '';
    
    String imageUrl = '';
    if (gsUrl.isNotEmpty) {
      imageUrl = await _getRealImageUrlFromGsUrl(gsUrl);
    } else {
      print('   ! No hay imagen en DB, usando por defecto');
      imageUrl = _getFallbackImage(title);
    }
    
    // 2. Obtener NOMBRE DEL AUTOR
    String authorName = 'Anónimo';
    final authorId = data['authorId']?.toString();
    
    if (authorId != null && authorId.isNotEmpty) {
      try {
        print('   🔍 Buscando autor ID: $authorId');
        final userDoc = await firestore
            .collection('users')
            .doc(authorId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          authorName = userData['name']?.toString()?.trim() ?? 'Anónimo';
          print('   ✅ Autor encontrado: $authorName');
        } else {
          print('   ⚠️ Autor no encontrado en Firestore');
        }
      } catch (e) {
        print('   ❌ Error obteniendo autor: $e');
      }
    } else {
      print('   ℹ️ No hay authorId en el artículo');
    }
    
    print('   👤 Autor final: $authorName');
    print('   🖼️ Imagen: ${imageUrl.substring(0, min(60, imageUrl.length))}...');
    
    return ArticleEntity(
      id: doc.id.hashCode,
      author: authorName,
      title: title,
      description: data['excerpt']?.toString()?.trim() ?? '',
      url: '',
      urlToImage: imageUrl,
      publishedAt: _getPublishedAt(data),
      content: data['content']?.toString()?.trim() ?? '',
    );
  }

  Future<String> _getRealImageUrlFromGsUrl(String gsUrl) async {
    try {
      final storageRef = storage.refFromURL(gsUrl);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('   ❌ Error obteniendo imagen: $e');
      rethrow;
    }
  }

  String _generateExcerpt(String content, {int length = 150}) {
    if (content.length <= length) return content;
    return '${content.substring(0, length)}...';
  }

  String _getFallbackImage(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('christmas') || lowerTitle.contains('navidad')) {
      return 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&h=600&fit=crop';
    } 
    else if (lowerTitle.contains('cat') || lowerTitle.contains('gato')) {
      return 'https://images.unsplash.com/photo-1514888286974-6d03bde4ba42?w=800&h=600&fit=crop';
    }
    else {
      return 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800&h=600&fit=crop';
    }
  }

  String _getPublishedAt(Map<String, dynamic> data) {
    try {
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        return (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
    } catch (e) {
      print('⚠️ Error parseando fecha: $e');
    }
    
    return DateTime.now().toIso8601String();
  }

  @override
  Future<List<ArticleEntity>> getSavedArticles() async => [];

  @override
  Future<void> removeArticle(ArticleEntity article) async {}
}