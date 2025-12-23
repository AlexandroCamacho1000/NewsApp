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
  bool _recoveryAttempted = false;

  ArticleRepositoryImpl({
    required this.firestore,
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  Future<void> _recoverLostContent() async {
    if (_recoveryAttempted) return;
    
    print('\n🔧🔧🔧 INICIANDO RECUPERACIÓN DE CONTENIDO PERDIDO 🔧🔧🔧');
    
    try {
      // Buscar artículos que NO tienen campo 'content' o lo tienen vacío
      final snapshot = await firestore
          .collection('articles')
          .where('content', whereIn: [null, ''])
          .get(GetOptions(source: Source.server));
      
      print('📄 Artículos sin contenido encontrados: ${snapshot.docs.length}');
      
      if (snapshot.docs.isEmpty) {
        print('✅ Todos los artículos tienen contenido. No se requiere recuperación.');
        _recoveryAttempted = true;
        return;
      }
      
      int recoveredCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('\n🔍 Analizando artículo ${doc.id}: "${data['title']?.toString()?.substring(0, min(30, data['title']?.toString()?.length ?? 0))}..."');
        
        // Lista de posibles campos donde podría estar el contenido
        final possibleContentFields = [
          ' content', // Campo con espacio
          '_obsolete_content_with_space',
          '_backup_content_with_space', 
          '_moved_from_content',
          'contenido',
          'body',
          'text',
          'article_content',
          'article_body',
          'description',
          'descripcion',
          'main_content',
          'full_content',
          'story',
          'articulo'
        ];
        
        String? recoveredContent;
        String? sourceField;
        
        // Buscar en todos los campos posibles
        for (var field in possibleContentFields) {
          if (data.containsKey(field) && 
              data[field] != null && 
              data[field].toString().trim().isNotEmpty) {
            
            recoveredContent = data[field].toString().trim();
            sourceField = field;
            break;
          }
        }
        
        // También buscar en cualquier campo que contenga "content" en el nombre
        if (recoveredContent == null) {
          for (var key in data.keys) {
            if (key.toLowerCase().contains('content') && 
                data[key] != null && 
                data[key].toString().trim().isNotEmpty) {
              
              recoveredContent = data[key].toString().trim();
              sourceField = key;
              break;
            }
          }
        }
        
        // Buscar el campo de texto más largo
        if (recoveredContent == null) {
          String? longestText;
          String? longestField;
          
          for (var entry in data.entries) {
            if (entry.value is String && (entry.value as String).length > 100) {
              if (longestText == null || (entry.value as String).length > longestText.length) {
                longestText = entry.value as String;
                longestField = entry.key;
              }
            }
          }
          
          if (longestText != null) {
            recoveredContent = longestText;
            sourceField = longestField;
          }
        }
        
        if (recoveredContent != null && recoveredContent.isNotEmpty) {
          print('   ✅ Contenido recuperado de "$sourceField" (${recoveredContent.length} caracteres)');
          
          final updateData = {
            'content': recoveredContent,
            '_recovered_at': FieldValue.serverTimestamp(),
            '_recovered_from': sourceField,
          };
          
          try {
            await doc.reference.update(updateData);
            recoveredCount++;
            print('   💾 Contenido restaurado en Firestore');
          } catch (e) {
            print('   ⚠️ Error al guardar contenido recuperado: $e');
          }
        } else {
          print('   ❌ No se pudo encontrar contenido para recuperar');
          print('   📋 Campos disponibles: ${data.keys.join(', ')}');
          
          // Crear contenido de emergencia
          final emergencyContent = """
Este artículo perdió su contenido original. 
Título: ${data['title'] ?? 'Sin título'}
Autor: ${data['author'] ?? 'Desconocido'}
Fecha: ${data['createdAt'] ?? 'Fecha no disponible'}

Lamentamos las molestias. El contenido se está recuperando.
""";
          
          final updateData = {
            'content': emergencyContent,
            '_emergency_content': true,
            '_recovery_attempted': FieldValue.serverTimestamp(),
          };
          
          try {
            await doc.reference.update(updateData);
            recoveredCount++;
            print('   ⚠️ Contenido de emergencia creado');
          } catch (e) {
            print('   💥 Error crítico al crear contenido de emergencia: $e');
          }
        }
      }
      
      print('\n🎉🎉🎉 RESUMEN DE RECUPERACIÓN 🎉🎉🎉');
      print('   • Artículos procesados: ${snapshot.docs.length}');
      print('   • Contenidos recuperados: $recoveredCount');
      
    } catch (e) {
      print('❌ ERROR en recuperación: $e');
    } finally {
      _recoveryAttempted = true;
    }
  }

  Future<void> _safeCleanDuplicateContentFields() async {
    if (_hasCleaned) return;
    
    print('\n🧹🧹🧹 LIMPIEZA SEGURA DE CAMPOS DUPLICADOS 🧹🧹🧹');
    print('⚠️  ESTA VERSIÓN NO ELIMINARÁ NINGÚN CONTENIDO ⚠️');
    
    try {
      final snapshot = await firestore
          .collection('articles')
          .get(GetOptions(source: Source.server));
      
      print('📚 Total documentos en colección: ${snapshot.docs.length}');
      
      int cleanedCount = 0;
      int backupCreatedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool needsUpdate = false;
        final updateData = <String, dynamic>{};
        
        print('\n📄 Documento: ${doc.id}');
        print('   📝 Título: ${data['title']?.toString()?.substring(0, min(40, data['title']?.toString()?.length ?? 0))}...');
        
        // CASO 1: Campo ' content' (con espacio al inicio)
        if (data.containsKey(' content')) {
          print('   🔍 Encontrado campo " content"');
          
          final contentWithSpace = data[' content']?.toString()?.trim() ?? '';
          
          // Verificar si el campo 'content' (sin espacio) existe y tiene valor
          final hasValidContent = data.containsKey('content') && 
              data['content'] != null && 
              data['content'].toString().trim().isNotEmpty;
          
          if (!hasValidContent && contentWithSpace.isNotEmpty) {
            // Caso A: No hay 'content' válido, pero sí hay ' content' con valor
            print('   ✅ Copiando " content" a "content" (${contentWithSpace.length} chars)');
            updateData['content'] = contentWithSpace;
            updateData['_original_content_with_space_backup'] = contentWithSpace;
            backupCreatedCount++;
            needsUpdate = true;
          } else if (hasValidContent && contentWithSpace.isNotEmpty) {
            // Caso B: Ambos campos tienen contenido
              final existingContent = data['content'].toString().trim();
            print('   ℹ️  Ambos campos tienen contenido:');
            print('      • "content": ${existingContent.length} caracteres');
            print('      • " content": ${contentWithSpace.length} caracteres');
            
            // Verificar si son diferentes
            if (existingContent != contentWithSpace) {
              print('   💾 Guardando " content" como respaldo');
              updateData['_backup_content_with_space'] = contentWithSpace;
              backupCreatedCount++;
              needsUpdate = true;
            }
          }
          
          // NUNCA eliminar el campo ' content'
          print('   📌 Campo " content" preservado');
        }
        
        // CASO 2: Detectar otros campos duplicados (case-insensitive)
        final lowerCaseFields = <String, List<String>>{};
        
        for (var key in data.keys) {
          final lowerKey = key.trim().toLowerCase();
          if (!lowerCaseFields.containsKey(lowerKey)) {
            lowerCaseFields[lowerKey] = [];
          }
          lowerCaseFields[lowerKey]!.add(key);
        }
        
        // Procesar campos duplicados
        for (var entry in lowerCaseFields.entries) {
          if (entry.value.length > 1) {
            print('   🔍 Campo duplicado detectado: "${entry.key}" → ${entry.value}');
            
            // Encontrar el campo "correcto" (el que no tiene espacio al inicio)
            String? correctField;
            String? backupField;
            
            for (var field in entry.value) {
              if (!field.startsWith(' ')) {
                correctField = field;
              } else {
                backupField = field;
              }
            }
            
            if (correctField != null && backupField != null) {
              // Asegurar que el campo correcto tenga el mejor valor
              final correctValue = data[correctField];
              final backupValue = data[backupField];
              
              if ((correctValue == null || 
                   correctValue.toString().trim().isEmpty) && 
                  backupValue != null && 
                  backupValue.toString().trim().isNotEmpty) {
                
                // El campo correcto está vacío pero el de respaldo tiene valor
                print('   🔄 Copiando valor de "$backupField" a "$correctField"');
                updateData[correctField] = backupValue.toString().trim();
                updateData['_backup_' + backupField.replaceAll(' ', '_')] = backupValue;
                backupCreatedCount++;
                needsUpdate = true;
              } else if (correctValue != null && backupValue != null) {
                // Ambos tienen valor, guardar respaldo
                print('   💾 Guardando "$backupField" como respaldo');
                updateData['_backup_' + backupField.replaceAll(' ', '_')] = backupValue;
                backupCreatedCount++;
                needsUpdate = true;
              }
            }
          }
        }
        
        // Verificar que el campo 'content' existe
        if (!data.containsKey('content') || 
            data['content'] == null || 
            data['content'].toString().trim().isEmpty) {
          
          print('   ⚠️  Campo "content" faltante o vacío');
          
          // Buscar cualquier campo que pueda contener el contenido
          String? potentialContent;
          String? sourceField;
          
          for (var key in data.keys) {
            if ((key.toLowerCase().contains('content') || 
                 key.toLowerCase().contains('body') || 
                 key.toLowerCase().contains('text')) &&
                data[key] != null && 
                data[key].toString().trim().isNotEmpty) {
              
              final candidate = data[key].toString().trim();
              if (candidate.length > 50) { // Debe ser un contenido real
                potentialContent = candidate;
                sourceField = key;
                break;
              }
            }
          }
          
          if (potentialContent != null) {
            print('   ✅ Usando "$sourceField" como contenido (${potentialContent.length} chars)');
            updateData['content'] = potentialContent;
            updateData['_content_source'] = sourceField;
            needsUpdate = true;
          }
        }
        
        if (needsUpdate) {
          try {
            print('   💾 Guardando cambios...');
            await doc.reference.update(updateData);
            cleanedCount++;
            print('   ✅ Documento actualizado exitosamente');
            
            // Mostrar resumen de cambios
            print('   📋 Cambios aplicados:');
            updateData.forEach((key, value) {
              if (value is String && value.length > 50) {
                print('      • $key: String(${value.length} caracteres)');
              } else {
                print('      • $key: $value');
              }
            });
            
          } catch (e) {
            print('   ❌ Error actualizando documento: $e');
            print('   📋 UpdateData: $updateData');
          }
        } else {
          print('   ✅ Documento OK - Sin cambios necesarios');
        }
      }
      
      print('\n' + '=' * 50);
      print('🎉 RESUMEN DE LIMPIEZA SEGURA 🎉');
      print('=' * 50);
      print('📊 Documentos procesados: ${snapshot.docs.length}');
      print('✅ Documentos actualizados: $cleanedCount');
      print('💾 Respaldos creados: $backupCreatedCount');
      print('⚠️  NINGÚN CONTENIDO FUE ELIMINADO');
      print('=' * 50);
      
    } catch (e) {
      print('❌❌❌ ERROR CRÍTICO en limpieza: $e');
      print('⚠️  La limpieza se detuvo por seguridad');
    } finally {
      _hasCleaned = true;
    }
  }

  @override
  Future<DataState<List<ArticleEntity>>> getNewsArticles({bool forceRefresh = false}) async {
    print('\n🚀🚀🚀 OBTENIENDO ARTÍCULOS - VERSIÓN DIAGNÓSTICO COMPLETO 🚀🚀🚀');
    print('   • forceRefresh: $forceRefresh');
    print('   • _hasCleaned: $_hasCleaned');
    print('   • _recoveryAttempted: $_recoveryAttempted');
    
    // PASO 1: Recuperar contenido perdido primero
    if (!_recoveryAttempted) {
      await _recoverLostContent();
    }
    
    // PASO 2: Limpieza segura (solo una vez)
    if (!_hasCleaned) {
      await _safeCleanDuplicateContentFields();
    }
    
    try {
      final GetOptions options = GetOptions(
        source: forceRefresh ? Source.server : Source.cache,
      );
      
      print('\n📊 Obteniendo datos desde: ${options.source}');
      
      // 🔥 DIAGNÓSTICO 1: Obtener TODOS los artículos (sin filtro)
      print('\n🔍 DIAGNÓSTICO 1 - TODOS LOS ARTÍCULOS (SIN FILTRO):');
      final allSnapshot = await firestore
          .collection('articles')
          .get(GetOptions(source: Source.server));
      
      print('📚 Total documentos en Firestore: ${allSnapshot.docs.length}');
      
      List<String> allArticleIds = [];
      for (final doc in allSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title']?.toString() ?? 'Sin título';
        final published = data['published'];
        final publishedType = published?.runtimeType.toString() ?? 'NULL';
        
        print('   • ${doc.id}: "$title"');
        print('      - published: $published ($publishedType)');
        print('      - campos: ${data.keys.join(', ')}');
        
        allArticleIds.add(doc.id);
        
        if (doc.id == 'article1') {
          print('      🎯 ¡ARTICLE1 ENCONTRADO EN TODOS LOS DOCUMENTOS!');
          print('      • content: "${data['content']}"');
          print('      • thumbnailURL: "${data['thumbnailURL']}"');
        }
      }
      
      print('\n📋 LISTA COMPLETA DE IDs: ${allArticleIds.join(', ')}');
      
      // 🔥 DIAGNÓSTICO 2: Buscar con filtro published=true
      print('\n🔍 DIAGNÓSTICO 2 - BUSCANDO CON FILTRO published=true:');
      final snapshot = await firestore
          .collection('articles')
          .where('published', isEqualTo: true)
          .get(options);
      
      print('📚 ${snapshot.docs.length} artículos encontrados CON FILTRO');
      
      List<String> filteredArticleIds = [];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        filteredArticleIds.add(doc.id);
        
        print('   • ${doc.id}: "${data['title']}"');
        
        if (doc.id == 'article1') {
          print('      🎯 ¡ARTICLE1 ENCONTRADO EN FILTRADOS!');
        }
      }
      
      print('\n📋 IDs con filtro: ${filteredArticleIds.join(', ')}');
      
      // 🔥 DIAGNÓSTICO 3: Comparar listas
      print('\n🔍 DIAGNÓSTICO 3 - COMPARANDO LISTAS:');
      final missingIds = allArticleIds.where((id) => !filteredArticleIds.contains(id)).toList();
      
      if (missingIds.isNotEmpty) {
        print('❌ ARTÍCULOS FALTANTES EN FILTRO: ${missingIds.join(', ')}');
        
        for (var missingId in missingIds) {
          print('\n🔍 ANALIZANDO ARTÍCULO FALTANTE: $missingId');
          final missingDoc = await firestore.collection('articles').doc(missingId).get();
          
          if (missingDoc.exists) {
            final missingData = missingDoc.data() as Map<String, dynamic>;
            print('   • published: ${missingData['published']} (${missingData['published']?.runtimeType})');
            print('   • título: "${missingData['title']}"');
            
            // Verificar si es article1
            if (missingId == 'article1') {
              print('   ⚠️  ¡ARTICLE1 ESTÁ FALTANDO PERO DEBERÍA APARECER!');
              print('   🔄 El valor de published es: ${missingData['published']}');
              print('   🔍 ¿Es igual a true?: ${missingData['published'] == true}');
              print('   🔍 ¿Es boolean?: ${missingData['published'] is bool}');
            }
          }
        }
      } else {
        print('✅ TODOS los artículos aparecen en el filtro');
      }
      
      // 🔥 SOLUCIÓN CORREGIDA: Determinar qué documentos usar
      List<QueryDocumentSnapshot> finalDocs;
      
      if (!filteredArticleIds.contains('article1')) {
        print('\n⚠️  ARTICLE1 NO APARECE. USANDO FILTRO FLEXIBLE...');
        
        // Obtener todos y filtrar localmente con lógica flexible
        final allArticles = await firestore
            .collection('articles')
            .get(options);
        
        finalDocs = allArticles.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final published = data['published'];
          
          // Aceptar varios formatos de "true"
          return published == true || 
                 published == 'true' || 
                 published == 1 ||
                 published == '1' ||
                 published?.toString().toLowerCase() == 'true';
        }).toList();
        
        print('📚 Con filtro flexible: ${finalDocs.length} artículos');
      } else {
        // Usar los documentos filtrados originalmente
        finalDocs = snapshot.docs;
      }
      
      print('\n🔍 VERIFICANDO ESTRUCTURA DE DOCUMENTOS');
      int validContentCount = 0;
      int missingContentCount = 0;
      
      for (final doc in finalDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final hasContent = data.containsKey('content') && 
                          data['content'] != null && 
                          data['content'].toString().trim().isNotEmpty;
        
        if (hasContent) {
          final content = data['content'].toString().trim();
          print('   ✅ ${doc.id}: "content" encontrado (${content.length} chars)');
          validContentCount++;
        } else {
          print('   ❌ ${doc.id}: "content" FALTANTE o VACÍO');
          print('      📋 Campos disponibles: ${data.keys.where((k) => k.toLowerCase().contains('content')).join(', ')}');
          missingContentCount++;
        }
        
        // Detalle específico para article1
        if (doc.id == 'article1') {
          print('      🎯 ARTICLE1 DETALLES:');
          print('      • Título: ${data['title']}');
          print('      • Contenido: "${data['content']}"');
          print('      • thumbnailURL: "${data['thumbnailURL']}"');
          print('      • published: ${data['published']} (${data['published']?.runtimeType})');
        }
      }
      
      print('\n📊 RESUMEN DE CONTENIDOS:');
      print('   • Con contenido válido: $validContentCount');
      print('   • Sin contenido: $missingContentCount');
      print('   • Total artículos procesados: ${finalDocs.length}');
      
      // PASO 3: Procesar artículos
      final articles = <ArticleEntity>[];
      
      for (final doc in finalDocs) {
        try {
          final article = await _createArticleWithAuthor(doc);
          articles.add(article);
          print('   ✅ Artículo procesado: "${article.title?.substring(0, min(30, article.title?.length ?? 0))}..."');
        } catch (e) {
          print('⚠️  Error procesando artículo ${doc.id}: $e');
          
          try {
            final fallbackArticle = await _createFallbackArticle(doc);
            articles.add(fallbackArticle);
            print('   🔄 Usando versión de respaldo');
          } catch (e2) {
            print('❌ Fallback también falló: $e2');
          }
        }
      }
      
      print('\n✅✅✅ PROCESO COMPLETADO ✅✅✅');
      print('   • Total artículos obtenidos: ${articles.length}');
      print('   • IDs obtenidos: ${articles.map((a) => a.id).where((id) => id != null).join(', ')}');
      
      return DataSuccess(articles);
      
    } catch (e) {
      print('💥💥💥 ERROR FATAL en getNewsArticles: $e');
      return DataFailed(DioException(
        requestOptions: RequestOptions(path: '/articles'),
        error: 'Error: $e',
        type: DioExceptionType.connectionError,
      ));
    }
  }

  String _getContent(Map<String, dynamic> data) {
    print('   🔍 Buscando contenido...');
    
    // PRIMERO: Campo 'content' normal (sin espacio)
    if (data.containsKey('content') && 
        data['content'] != null && 
        data['content'].toString().trim().isNotEmpty) {
      
      final content = data['content'].toString().trim();
      print('      ✅ Encontrado en "content": ${content.length} caracteres');
      return content;
    }
    
    // SEGUNDO: Campos de respaldo
    final backupFields = [
      '_backup_content_with_space',
      '_original_content_with_space_backup',
      '_content_source',
      ' content'
    ];
    
    for (var field in backupFields) {
      if (data.containsKey(field) && 
          data[field] != null && 
          data[field].toString().trim().isNotEmpty) {
        
        final content = data[field].toString().trim();
        print('      🔄 Encontrado en "$field": ${content.length} caracteres');
        return content;
      }
    }
    
    // TERCERO: Otros campos posibles
    final otherFields = [
      'body', 'text', 'article_content', 'contenido',
      'description', 'descripcion', 'main_content'
    ];
    
    for (var field in otherFields) {
      if (data.containsKey(field) && 
          data[field] != null && 
          data[field].toString().trim().isNotEmpty) {
        
        final content = data[field].toString().trim();
        print('      📝 Encontrado en "$field": ${content.length} caracteres');
        return content;
      }
    }
    
    // CUARTO: Buscar cualquier campo largo
    String? longestText;
    for (var entry in data.entries) {
      if (entry.value is String && (entry.value as String).length > 100) {
        if (longestText == null || (entry.value as String).length > longestText.length) {
          longestText = entry.value as String;
          print('      🔎 Campo largo encontrado: "${entry.key}" (${longestText.length} chars)');
        }
      }
    }
    
    if (longestText != null) {
      return longestText;
    }
    
    print('      ⚠️  No se encontró contenido adecuado');
    return '[Contenido no disponible]';
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
        print('   ⚠️  Error obteniendo autor: $e');
      }
    } else {
      authorName = data['author']?.toString()?.trim() ?? 'Anónimo';
    }
    
    final content = _getContent(data);
    
    return ArticleEntity(
      id: doc.id,
      author: authorName,
      title: title,
      description: content.isNotEmpty 
          ? content.substring(0, min(150, content.length)) + (content.length > 150 ? '...' : '')
          : '',
      url: '',
      urlToImage: _getFallbackImage(title),
      publishedAt: _getPublishedAt(data),
      content: content,
      published: data['published'] as bool? ?? true, // ✅ AGREGADO: Campo published
    );
  }

  @override
  Future<void> saveArticle(ArticleEntity article) async {
    try {
      print('💾 GUARDANDO artículo nuevo: "${article.title}"');
      
      // Validar contenido
      if (article.content == null || article.content!.trim().isEmpty) {
        throw Exception('El artículo debe tener contenido');
      }
      
      final articleData = <String, dynamic>{
        'title': article.title?.trim() ?? 'Sin título',
        'content': article.content!.trim(), // CONTENIDO PRINCIPAL
        'author': article.author?.trim() ?? 'Anónimo',
        'excerpt': article.content!.length > 150 
            ? article.content!.substring(0, 150) + '...'
            : article.content!,
        'thumbnailURL': (article.urlToImage?.isNotEmpty ?? false)
            ? article.urlToImage!
            : _getFallbackImage(article.title ?? ''),
        'authorId': 'utJbxTZ7ezTot9wVOTAh',
        'published': article.published ?? true, // ✅ USANDO el campo published del artículo
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_version': 2, // Marcar como nueva versión
        '_content_verified': true,
      };
      
      print('📝 Datos a guardar:');
      print('   • Título: ${articleData['title']}');
      print('   • Autor: ${articleData['author']}');
      print('   • Contenido: ${articleData['content'].toString().length} caracteres');
      print('   • Published: ${articleData['published']}'); // ✅ Mostrando el valor de published
      
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

  @override
  Future<void> updateArticle(ArticleEntity article) async {
    try {
      print('\n✏️✏️✏️ ACTUALIZANDO ARTÍCULO ✏️✏️✏️');
      print('   Artículo ID: ${article.id}');
      print('   Título: "${article.title}"');
      print('   Contenido length: ${article.content?.length ?? 0}');
      print('   Published: ${article.published}'); // ✅ Mostrando el valor de published
      
      if (article.id == null) {
        throw Exception('❌ El artículo no tiene ID válido');
      }
      
      final articleId = article.id.toString();
      
      // VALIDAR CONTENIDO
      if (article.content == null || article.content!.trim().isEmpty) {
        throw Exception('❌ No se puede actualizar con contenido vacío');
      }
      
      print('   🔍 Buscando documento con ID: $articleId');
      
      final docRef = firestore.collection('articles').doc(articleId);
      final snapshot = await docRef.get();
      
      if (!snapshot.exists) {
        print('   ⚠️  Documento no encontrado');
        
        // Buscar por título como respaldo
        final querySnapshot = await firestore
            .collection('articles')
            .where('title', isEqualTo: article.title)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isEmpty) {
          throw Exception('No se encontró artículo para actualizar');
        }
        
        final foundDoc = querySnapshot.docs.first;
        print('   ✅ Encontrado por título. ID real: ${foundDoc.id}');
        
        return await _updateDocument(foundDoc.reference, article);
      }
      
      print('   ✅ Documento encontrado!');
      await _updateDocument(docRef, article);
      
    } catch (e) {
      print('❌❌❌ ERROR en updateArticle: $e');
      rethrow;
    }
  }

  Future<void> _updateDocument(DocumentReference docRef, ArticleEntity article) async {
    try {
      // Crear datos de actualización
      final updateData = <String, dynamic>{
        'title': article.title?.trim() ?? '',
        'author': article.author?.trim() ?? 'Anónimo',
        'content': article.content!.trim(), // CONTENIDO GARANTIZADO
        'published': article.published ?? true, // ✅ ACTUALIZANDO el campo published
        'updatedAt': FieldValue.serverTimestamp(),
        '_last_updated_by': 'repository',
        '_update_timestamp': FieldValue.serverTimestamp(),
      };
      
      // Si hay imagen, actualizarla también con verificación de null safety
      if (article.urlToImage != null && article.urlToImage!.isNotEmpty) {
        updateData['thumbnailURL'] = article.urlToImage!;
      }
      
      print('\n📝 ACTUALIZANDO DOCUMENTO ${docRef.id}:');
      print('   • Título: "${updateData['title']}"');
      print('   • Autor: "${updateData['author']}"');
      print('   • Contenido: ${(updateData['content'] as String).length} caracteres');
      print('   • Published: ${updateData['published']}'); // ✅ Mostrando el valor de published
      
      // Mostrar preview del contenido
      final contentPreview = (updateData['content'] as String).length > 100 
          ? (updateData['content'] as String).substring(0, 100) + '...' 
          : updateData['content'] as String;
      print('   • Preview: "$contentPreview"');
      
      // Actualizar documento
      await docRef.update(updateData);
      print('✅✅✅ DOCUMENTO ACTUALIZADO EXITOSAMENTE');
      
      // Verificar que se guardó correctamente
      final verification = await docRef.get();
      final verifiedData = verification.data() as Map<String, dynamic>;
      
      print('\n🔍 VERIFICACIÓN POST-ACTUALIZACIÓN:');
      print('   • ¿Tiene "content"?: ${verifiedData.containsKey('content')}');
      print('   • ¿Tiene "published"?: ${verifiedData.containsKey('published')}');
      if (verifiedData.containsKey('content')) {
        final savedContent = verifiedData['content'].toString();
        print('   • Longitud guardada: ${savedContent.length} caracteres');
        print('   • Coincide con enviado?: ${savedContent == updateData['content']}');
      }
      if (verifiedData.containsKey('published')) {
        print('   • Published guardado: ${verifiedData['published']}');
      }
      print('   • Última actualización: ${verifiedData['updatedAt']}');
      
    } catch (e) {
      print('❌ ERROR en _updateDocument: $e');
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
          'role': 'author',
        });
        print('👤 Autor creado: $authorName');
      }
    } catch (e) {
      print('⚠️  Error con autor: $e');
    }
  }

  Future<ArticleEntity> _createArticleWithAuthor(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString()?.trim() ?? 'Sin título';
    
    print('\n📰 Procesando: "$title"');
    print('   📋 ID: ${doc.id}');
    print('   🏷️  published value: ${data['published']} (${data['published']?.runtimeType})');
    
    // Obtener contenido PRINCIPAL
    final content = _getContent(data);
    
    // Obtener imagen
    String imageUrl = _getFallbackImage(title);
    final rawThumbnail = data['thumbnailURL'];
    
    if (rawThumbnail != null && rawThumbnail is String && rawThumbnail.trim().isNotEmpty) {
      final gsUrl = rawThumbnail.trim();
      
      if (gsUrl.startsWith('gs://')) {
        try {
          imageUrl = await _getRealImageUrlFromGsUrl(gsUrl);
          print('   🖼️  Imagen de Firebase Storage');
        } catch (e) {
          print('   ⚠️  Error con imagen Firebase: $e');
        }
      } else if (gsUrl.startsWith('http')) {
        imageUrl = gsUrl;
        print('   🖼️  URL directa HTTP');
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
        print('   ⚠️  Error obteniendo autor: $e');
      }
    } else {
      authorName = data['author']?.toString()?.trim() ?? 'Anónimo';
    }
    
    print('   👤 Autor: $authorName');
    print('   📝 Contenido: ${content.length} caracteres');
    
    return ArticleEntity(
      id: doc.id,
      author: authorName,
      title: title,
      description: content.isNotEmpty 
          ? content.substring(0, min(150, content.length)) + (content.length > 150 ? '...' : '')
          : '',
      url: '',
      urlToImage: imageUrl,
      publishedAt: _getPublishedAt(data),
      content: content,
      published: _parsePublishedValue(data['published']), // ✅ AGREGADO: Campo published
    );
  }

  // ✅ NUEVO MÉTODO: Parsear valor de published
  bool? _parsePublishedValue(dynamic publishedValue) {
    if (publishedValue == null) return null;
    
    if (publishedValue is bool) {
      return publishedValue;
    } else if (publishedValue is String) {
      return publishedValue.toLowerCase() == 'true';
    } else if (publishedValue is int) {
      return publishedValue == 1;
    }
    
    return null;
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
      // Intentar con publishedAt primero
      if (data['publishedAt'] != null) {
        if (data['publishedAt'] is Timestamp) {
          return (data['publishedAt'] as Timestamp).toDate().toIso8601String();
        } else if (data['publishedAt'] is String) {
          return data['publishedAt'] as String;
        }
      }
      
      // Luego con createdAt
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        return (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      
      // Finalmente con updatedAt
      if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
        return (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }
    } catch (e) {
      print('⚠️  Error parseando fecha: $e');
    }
    
    // Fecha actual como último recurso
    return DateTime.now().toIso8601String();
  }

  @override
  Future<List<ArticleEntity>> getSavedArticles() async => [];

  @override
  Future<void> removeArticle(ArticleEntity article) async {}
}