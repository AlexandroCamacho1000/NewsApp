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

  // ⭐ URLs CONFIABLES - USANDO 'static final' EN VEZ DE 'static const'
  static final _catImageUrl = 'https://picsum.photos/1200/630?random=cat&t=${DateTime.now().millisecondsSinceEpoch}';
  static final _christmasImageUrl = 'https://picsum.photos/1200/630?random=christmas&t=${DateTime.now().millisecondsSinceEpoch}';
  static final _dogImageUrl = 'https://picsum.photos/1200/630?random=dog&t=${DateTime.now().millisecondsSinceEpoch}';
  static final _defaultImageUrl = 'https://picsum.photos/1200/630?t=${DateTime.now().millisecondsSinceEpoch}';

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
      
      // ⭐⭐ DEBUG EXTREMO: VERIFICAR DATOS REALES DE FIRESTORE
      print('\n🔍🔍🔍 DEBUG EXTREMO - DATOS CRUDOS DE FIRESTORE 🔍🔍🔍');
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('\n📄 DOCUMENTO: ${doc.id}');
        print('   🔑 TODAS LAS LLAVES: ${data.keys.toList()}');
        print('   📍 ¿Tiene thumbnailURL?: ${data.containsKey('thumbnailURL')}');
        
        if (data.containsKey('thumbnailURL')) {
          final value = data['thumbnailURL'];
          print('   💾 Valor thumbnailURL: "$value"');
          print('   📏 Longitud: ${value.toString().length}');
          print('   🏷️  Tipo: ${value.runtimeType}');
          print('   🔍 ¿Es null?: ${value == null}');
          print('   🔍 ¿Es string vacío?: ${value.toString().isEmpty}');
        } else {
          print('   ❌ NO TIENE thumbnailURL!');
        }
        
        // Mostrar TODOS los valores para article3
        if (doc.id == 'article3') {
          print('   🎯 ARTICLE3 - DATOS COMPLETOS:');
          data.forEach((key, value) {
            print('      "$key": "$value" (Tipo: ${value.runtimeType})');
          });
          
          // COMPARAR CON ARTICLE1
          final article1Doc = snapshot.docs.firstWhere((d) => d.id == 'article1');
          final article1Data = article1Doc.data() as Map<String, dynamic>;
          print('   🔄 COMPARACIÓN CON ARTICLE1:');
          print('      article1 thumbnailURL: "${article1Data['thumbnailURL']}"');
        }
        
        print('   ---');
      }
      print('🔍🔍🔍 FIN DEBUG EXTREMO 🔍🔍🔍\n');
      
      // ⭐ DEBUG CRÍTICO: Mostrar todos los documentos
      print('📋 LISTA COMPLETA DE DOCUMENTOS:');
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('   • ID: ${doc.id}');
        print('     Título: ${data['title'] ?? "Sin título"}');
        print('     thumbnailURL: ${data['thumbnailURL'] ?? "Vacío"}');
        print('     ---');
      }
      
      final articles = <ArticleEntity>[];
      
      for (final doc in snapshot.docs) {
        try {
          final article = await _createArticleWithAuthor(doc);
          articles.add(article);
          print('   ✅ Artículo "${article.title}" agregado a la lista');
        } catch (e) {
          print('⚠️ Error procesando artículo ${doc.id}: $e');
          // ⭐ INTENTA CREAR ARTÍCULO CON IMAGEN POR DEFECTO
          try {
            final fallbackArticle = await _createFallbackArticle(doc);
            articles.add(fallbackArticle);
            print('   🔄 Artículo creado con imagen por defecto');
          } catch (e2) {
            print('❌ No se pudo crear artículo de respaldo: $e2');
          }
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

  // ⭐ NUEVA FUNCIÓN: Crear artículo con imagen por defecto
  Future<ArticleEntity> _createFallbackArticle(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('\n🔄 Creando artículo de respaldo: "$title"');
    
    // Obtener NOMBRE DEL AUTOR
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
        }
      } catch (e) {
        print('   ❌ Error obteniendo autor: $e');
      }
    }
    
    return ArticleEntity(
      id: doc.id.hashCode,
      author: authorName,
      title: title,
      description: data['excerpt']?.toString()?.trim() ?? '',
      url: '',
      urlToImage: _getFallbackImage(title),
      publishedAt: _getPublishedAt(data),
      content: data['content']?.toString()?.trim() ?? '',
    );
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

  // ⭐⭐ FUNCIÓN COMPLETAMENTE CORREGIDA
  Future<ArticleEntity> _createArticleWithAuthor(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('\n📰 Procesando: "$title" (ID: ${doc.id})');
    
    // ⭐⭐ CORRECCIÓN CRÍTICA: Manejo correcto del thumbnailURL
    final rawThumbnail = data['thumbnailURL'];
    String imageUrl = '';
    
    // DEBUG DETALLADO
    print('   🔍 Valor CRUDO thumbnailURL: "$rawThumbnail" (Tipo: ${rawThumbnail?.runtimeType})');
    
    if (rawThumbnail != null && rawThumbnail is String) {
      final gsUrl = rawThumbnail.trim();
      print('   🔍 Valor RECORTADO: "$gsUrl" (Longitud: ${gsUrl.length})');
      
      // ⭐⭐ CORRECCIÓN: Verificar si NO es "Vacío" o vacío real
      final isVacio = gsUrl.toLowerCase() == 'vacío' || 
                      gsUrl.toLowerCase() == 'vacio' ||
                      gsUrl == 'Vacío' ||
                      gsUrl.isEmpty;
      
      if (!isVacio && gsUrl.isNotEmpty) {
        if (gsUrl.startsWith('gs://')) {
          try {
            print('   🔗 Procesando Firebase Storage URL...');
            imageUrl = await _getRealImageUrlFromGsUrl(gsUrl);
            print('   ✅ URL Firebase obtenida');
          } catch (e) {
            print('   ⚠️ Error con Firebase Storage: $e');
            print('   🔄 Usando fallback...');
            imageUrl = _getFallbackImage(title);
          }
        } else if (gsUrl.startsWith('http')) {
          print('   🌐 Usando URL normal...');
          imageUrl = gsUrl;
        } else {
          print('   ⚠️ Formato desconocido: "$gsUrl"');
          print('   🔄 Usando fallback...');
          imageUrl = _getFallbackImage(title);
        }
      } else {
        print('   ⚠️ Valor es "Vacío", vacío o inválido');
        print('   🔄 Usando imagen por defecto');
        imageUrl = _getFallbackImage(title);
      }
    } else {
      print('   ⚠️ thumbnailURL es null o no es String');
      print('   🔄 Usando imagen por defecto');
      imageUrl = _getFallbackImage(title);
    }
    
    // DEBUG EXTRA: Mostrar URL completa
    print('   📸 URL final imagen: ${imageUrl.substring(0, min(80, imageUrl.length))}...');
    
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
    
    // ⭐ RESUMEN FINAL PARA DEBUG
    print('   📊 RESUMEN FINAL artículo "$title":');
    print('   • Imagen URL: $imageUrl');
    print('   • Longitud: ${imageUrl.length} caracteres');
    print('   • Comienza con https?: ${imageUrl.startsWith('https://')}');
    print('   • Es picsum.photos?: ${imageUrl.contains('picsum.photos')}');
    print('   ---');
    
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

  // ⭐ FUNCIÓN CORREGIDA: Mejor manejo de errores
  Future<String> _getRealImageUrlFromGsUrl(String gsUrl) async {
    try {
      // Verificar que sea una URL válida de Firebase Storage
      if (!gsUrl.startsWith('gs://')) {
        throw Exception('URL no es de Firebase Storage: $gsUrl');
      }
      
      final storageRef = storage.refFromURL(gsUrl);
      final downloadUrl = await storageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('   ❌ Error Firebase Storage: $e');
      rethrow;
    }
  }

  String _generateExcerpt(String content, {int length = 150}) {
    if (content.length <= length) return content;
    return '${content.substring(0, length)}...';
  }

  // ⭐⭐ FUNCIÓN MEJORADA: URLs con timestamp único
  String _getFallbackImage(String title) {
    final lowerTitle = title.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    if (lowerTitle.contains('christmas') || lowerTitle.contains('navidad')) {
      return 'https://picsum.photos/1200/630?random=christmas&t=$timestamp';
    } 
    else if (lowerTitle.contains('cat') || lowerTitle.contains('gato')) {
      return 'https://picsum.photos/1200/630?random=cat&t=$timestamp';
    }
    else if (lowerTitle.contains('dog') || lowerTitle.contains('perro')) {
      return 'https://picsum.photos/1200/630?random=dog&t=$timestamp';
    }
    else {
      return 'https://picsum.photos/1200/630?t=$timestamp';
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