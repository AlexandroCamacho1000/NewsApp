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
  bool _hasCleaned = false;

  ArticleRepositoryImpl({
    required this.firestore,
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  // ⭐⭐ CORREGIDO: Método optimizado para limpiar duplicados
  Future<void> _cleanDuplicateContentFields() async {
    print('\n🧹 INICIANDO LIMPIEZA DE CAMPOS DUPLICADOS 🧹');
    
    try {
      final snapshot = await firestore
          .collection('articles')
          .get(GetOptions(source: Source.server));
      
      int cleanedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool needsUpdate = false;
        final updateData = <String, dynamic>{};
        
        // 1. Verificar si hay ' content' (con espacio)
        if (data.containsKey(' content')) {
          print('   📄 ${doc.id}: Encontrado campo " content"');
          
          // 2. Decidir qué valor mantener
          String? contentToKeep;
          
          // Prioridad: 'content' (sin espacio) si tiene valor
          if (data.containsKey('content') && 
              data['content'] != null && 
              data['content'].toString().trim().isNotEmpty) {
            contentToKeep = data['content'].toString().trim();
            print('      ✅ Manteniendo valor de "content"');
          } 
          // Si no, usar el valor de ' content'
          else if (data[' content'] != null && 
                   data[' content'].toString().trim().isNotEmpty) {
            contentToKeep = data[' content'].toString().trim();
            print('      🔄 Usando valor de " content" para "content"');
          }
          
          // 3. Preparar actualización
          if (contentToKeep != null && contentToKeep.isNotEmpty) {
            updateData['content'] = contentToKeep;
            updateData[' content'] = FieldValue.delete();
            needsUpdate = true;
          }
        }
        
        // 4. Eliminar otros posibles duplicados
        final seenKeys = <String>{};
        for (var key in data.keys) {
          final normalizedKey = key.trim().toLowerCase();
          if (seenKeys.contains(normalizedKey)) {
            print('      🚫 Eliminando duplicado de "$key"');
            updateData[key] = FieldValue.delete();
            needsUpdate = true;
          }
          seenKeys.add(normalizedKey);
        }
        
        // 5. Aplicar actualización si es necesario
        if (needsUpdate) {
          try {
            await doc.reference.update(updateData);
            cleanedCount++;
            print('      ✅ Documento actualizado');
          } catch (e) {
            print('      ⚠️ Error actualizando: $e');
          }
        }
      }
      
      print('\n🎉 Total documentos procesados: ${snapshot.docs.length}');
      print('✅ Documentos corregidos: $cleanedCount');
      
    } catch (e) {
      print('❌ Error en limpieza: $e');
    }
  }

  @override
  Future<DataState<List<ArticleEntity>>> getNewsArticles({bool forceRefresh = false}) async {
    print('🚀 OBTENIENDO ARTÍCULOS (forceRefresh: $forceRefresh)');
    
    // ⭐⭐ Ejecutar limpieza solo una vez al iniciar
    if (!_hasCleaned) {
      await _cleanDuplicateContentFields();
      _hasCleaned = true;
    }
    
    try {
      final GetOptions options = GetOptions(
        source: forceRefresh ? Source.server : Source.cache,
      );
      
      print('📊 Fuente de datos: ${options.source}');
      
      final snapshot = await firestore
          .collection('articles')
          .get(options);
      
      print('📚 ${snapshot.docs.length} artículos encontrados');
      
      // ⭐⭐ Debug mejorado
      print('\n🔍 VERIFICANDO ESTRUCTURA DE DOCUMENTOS');
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final contentFields = data.keys.where((k) => k.contains('content')).toList();
        if (contentFields.isNotEmpty) {
          print('   📄 ${doc.id}: $contentFields');
        }
      }
      
      final articles = <ArticleEntity>[];
      
      for (final doc in snapshot.docs) {
        try {
          final article = await _createArticleWithAuthor(doc);
          articles.add(article);
        } catch (e) {
          print('⚠️ Error con artículo ${doc.id}: $e');
          try {
            final fallbackArticle = await _createFallbackArticle(doc);
            articles.add(fallbackArticle);
          } catch (e2) {
            print('❌ Fallback también falló: $e2');
          }
        }
      }
      
      print('\n✅ ${articles.length} artículos procesados correctamente');
      return DataSuccess(articles);
      
    } catch (e) {
      print('💥 ERROR: $e');
      return DataFailed(DioException(
        requestOptions: RequestOptions(path: '/articles'),
        error: 'Error: $e',
        type: DioExceptionType.connectionError,
      ));
    }
  }

  // ⭐⭐ CORREGIDO: Método mejorado para obtener contenido
  String _getContent(Map<String, dynamic> data) {
    // Prioridad 1: 'content' (sin espacio)
    if (data.containsKey('content') && 
        data['content'] != null && 
        data['content'].toString().trim().isNotEmpty) {
      return data['content'].toString().trim();
    }
    
    // Prioridad 2: ' content' (con espacio)
    if (data.containsKey(' content') && 
        data[' content'] != null && 
        data[' content'].toString().trim().isNotEmpty) {
      return data[' content'].toString().trim();
    }
    
    // Prioridad 3: Buscar cualquier campo con texto largo
    for (var entry in data.entries) {
      if (entry.value is String && (entry.value as String).length > 100) {
        return entry.value as String;
      }
    }
    
    return '';
  }

  Future<ArticleEntity> _createFallbackArticle(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('🔄 Creando artículo de respaldo: "$title"');
    
    String authorName = 'Anónimo';
    final authorId = data['authorId']?.toString();
    
    if (authorId != null && authorId.isNotEmpty) {
      try {
        final userDoc = await firestore
            .collection('users')
            .doc(authorId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          authorName = userData['name']?.toString()?.trim() ?? 'Anónimo';
        }
      } catch (e) {
        print('   ⚠️ Error obteniendo autor: $e');
      }
    }
    
    final content = _getContent(data);
    
    return ArticleEntity(
      id: doc.id.hashCode,
      author: authorName,
      title: title,
      description: content.isNotEmpty 
          ? content.substring(0, min(150, content.length)) + (content.length > 150 ? '...' : '')
          : '',
      url: '',
      urlToImage: _getFallbackImage(title),
      publishedAt: _getPublishedAt(data),
      content: content,
    );
  }

  @override
  Future<void> saveArticle(ArticleEntity article) async {
    try {
      print('💾 GUARDANDO artículo: "${article.title}"');
      
      // ⭐⭐ SOLO guardar 'content' (campo único y limpio)
      final articleData = {
        'title': article.title ?? 'Sin título',
        'content': article.content?.trim() ?? '',  // ⭐ CAMPO ÚNICO
        'excerpt': article.content?.isNotEmpty ?? false
            ? (article.content!.length > 150 
                ? article.content!.substring(0, 150) + '...'
                : article.content!)
            : '',
        'thumbnailURL': (article.urlToImage?.isNotEmpty ?? false)
            ? article.urlToImage!
            : _getFallbackImage(article.title ?? ''),
        'authorId': 'utJbxTZ7ezTot9wVOTAh',
        'published': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 Datos a guardar:');
      print('   • Título: ${articleData['title']}');
      
      // ⭐⭐ CORRECCIÓN: Convertir a String antes de usar substring
      final contentForLog = articleData['content']?.toString() ?? '';
      if (contentForLog.isNotEmpty) {
        final preview = contentForLog.length > 50 
            ? '${contentForLog.substring(0, 50)}...' 
            : contentForLog;
        print('   • Contenido: $preview');
      }
      
      // ⭐⭐ USAR add() para crear nuevo documento
      final docRef = await firestore
          .collection('articles')
          .add(articleData);
      
      print('✅ Artículo creado con ID: ${docRef.id}');
      
      await _ensureAuthorExists('utJbxTZ7ezTot9wVOTAh', article.author ?? 'Anónimo');
      
    } catch (e) {
      print('❌ ERROR en saveArticle: $e');
      rethrow;
    }
  }

  // ⭐⭐ CORREGIDO: Método updateArticle usando set() con merge
  @override
  Future<void> updateArticle(ArticleEntity article) async {
    try {
      print('✏️ ACTUALIZANDO artículo: "${article.title}"');
      
      // Buscar documento por título (o por ID si lo tienes)
      final querySnapshot = await firestore
          .collection('articles')
          .where('title', isEqualTo: article.title)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print('⚠️ Artículo no encontrado. Creando nuevo...');
        await saveArticle(article);
        return;
      }
      
      final docId = querySnapshot.docs.first.id;
      
      // ⭐⭐ SOLUCIÓN CLAVE: Usar set() con merge: true
      final articleData = {
        'title': article.title ?? 'Sin título',
        'content': article.content?.trim() ?? '',  // Este campo SOBREESCRIBIRÁ cualquier duplicado
        'excerpt': article.content?.isNotEmpty ?? false
            ? (article.content!.length > 150 
                ? article.content!.substring(0, 150) + '...'
                : article.content!)
            : '',
        'thumbnailURL': (article.urlToImage?.isNotEmpty ?? false)
            ? article.urlToImage!
            : _getFallbackImage(article.title ?? ''),
        'authorId': 'utJbxTZ7ezTot9wVOTAh',
        'published': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 Datos de actualización:');
      print('   • Usando set() con merge: true');
      print('   • Esto SOBREESCRIBIRÁ "content" sin crear duplicados');
      
      // ⭐⭐ LÍNEA CRÍTICA CORREGIDA
      await firestore
          .collection('articles')
          .doc(docId)
          .set(articleData, SetOptions(merge: true));  // ⭐ merge: true es esencial
      
      print('✅ Artículo actualizado correctamente: $docId');
      
      // ⭐⭐ OPCIONAL: Limpiar cualquier campo ' content' residual
      try {
        await firestore
            .collection('articles')
            .doc(docId)
            .update({' content': FieldValue.delete()});
        print('   🧹 Campo " content" eliminado (si existía)');
      } catch (e) {
        // No es crítico si falla
      }
      
    } catch (e) {
      print('❌ ERROR en updateArticle: $e');
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
        print('👤 Autor creado: $authorName');
      }
    } catch (e) {
      print('⚠️ Error con autor: $e');
    }
  }

  Future<ArticleEntity> _createArticleWithAuthor(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('\n📰 Procesando: "$title" (ID: ${doc.id})');
    
    // Procesar imagen
    String imageUrl = _getFallbackImage(title);
    final rawThumbnail = data['thumbnailURL'];
    
    if (rawThumbnail != null && rawThumbnail is String && rawThumbnail.trim().isNotEmpty) {
      final gsUrl = rawThumbnail.trim();
      
      if (gsUrl.startsWith('gs://')) {
        try {
          imageUrl = await _getRealImageUrlFromGsUrl(gsUrl);
        } catch (e) {
          print('   ⚠️ Error con Firebase Storage: $e');
        }
      } else if (gsUrl.startsWith('http')) {
        imageUrl = gsUrl;
      }
    }
    
    // Obtener autor
    String authorName = 'Anónimo';
    final authorId = data['authorId']?.toString();
    
    if (authorId != null && authorId.isNotEmpty) {
      try {
        final userDoc = await firestore
            .collection('users')
            .doc(authorId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          authorName = userData['name']?.toString()?.trim() ?? 'Anónimo';
        }
      } catch (e) {
        print('   ⚠️ Error obteniendo autor: $e');
      }
    }
    
    // Obtener contenido
    final content = _getContent(data);
    
    return ArticleEntity(
      id: doc.id.hashCode,
      author: authorName,
      title: title,
      description: content.isNotEmpty 
          ? content.substring(0, min(150, content.length)) + (content.length > 150 ? '...' : '')
          : '',
      url: '',
      urlToImage: imageUrl,
      publishedAt: _getPublishedAt(data),
      content: content,
    );
  }

  Future<String> _getRealImageUrlFromGsUrl(String gsUrl) async {
    try {
      final storageRef = storage.refFromURL(gsUrl);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('❌ Error Firebase Storage: $e');
      rethrow;
    }
  }

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