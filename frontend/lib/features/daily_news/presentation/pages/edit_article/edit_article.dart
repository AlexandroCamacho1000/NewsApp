import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/article.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/article/remote/remote_article_bloc.dart';
import '../../bloc/article/remote/remote_article_event.dart';

class EditArticlePage extends StatefulWidget {
  final ArticleEntity article;
  
  const EditArticlePage({
    Key? key,
    required this.article,
  }) : super(key: key);

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _authorController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    print('🔍 DIAGNÓSTICO - EditArticlePage recibió:');
    print('   ID: ${widget.article.id}');
    print('   Título: ${widget.article.title}');
    print('   Autor: ${widget.article.author}');
    print('   Descripción: ${widget.article.description}');
    print('   Contenido: ${widget.article.content}');
    print('   Contenido length: ${widget.article.content?.length ?? 0}');
    
    String contenidoFinal = widget.article.content ?? '';
    
    if ((contenidoFinal.isEmpty || contenidoFinal == 'null') && 
        widget.article.description != null) {
      contenidoFinal = widget.article.description!;
      print('⚠️  Usando descripción como contenido: $contenidoFinal');
    }
    
    _titleController = TextEditingController(text: widget.article.title ?? '');
    _contentController = TextEditingController(text: contenidoFinal);
    _authorController = TextEditingController(text: widget.article.author ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('💾 BUSCANDO ARTÍCULO EN FIRESTORE...');
      print('   Título original: "${widget.article.title}"');
      print('   Autor original: "${widget.article.author}"');
      print('   ID numérico: ${widget.article.id}');
      
      QuerySnapshot querySnapshot;
      DocumentReference? docRef;
      String? foundDocId;
      
      if (widget.article.title != null && widget.article.title!.isNotEmpty) {
        print('🔍 Buscando por título: "${widget.article.title}"');
        
        querySnapshot = await FirebaseFirestore.instance
            .collection('articles')
            .where('title', isEqualTo: widget.article.title)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          docRef = querySnapshot.docs.first.reference;
          foundDocId = querySnapshot.docs.first.id;
          print('✅ ENCONTRADO por título! ID del documento: $foundDocId');
        } else {
          print('⚠️  No encontrado por título, intentando con ID...');
        }
      }
      
      if (docRef == null && widget.article.id != null) {
        final possibleIds = [
          widget.article.id.toString(),
          'article${widget.article.id}',
          if (widget.article.id is int) 
            (widget.article.id as int).toString(),
        ];
        
        for (final testId in possibleIds) {
          print('🔍 Probando ID: $testId');
          final testRef = FirebaseFirestore.instance.collection('articles').doc(testId);
          final testSnapshot = await testRef.get();
          
          if (testSnapshot.exists) {
            docRef = testRef;
            foundDocId = testId;
            print('✅ ENCONTRADO con ID: $foundDocId');
            break;
          }
        }
      }
      
      if (docRef == null && widget.article.author != null && widget.article.author!.isNotEmpty) {
        print('🔍 Buscando por autor: "${widget.article.author}"');
        
        querySnapshot = await FirebaseFirestore.instance
            .collection('articles')
            .where('author', isEqualTo: widget.article.author)
            .limit(5)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          for (final doc in querySnapshot.docs) {
            final docTitle = doc['title'] as String?;
            if (docTitle != null && docTitle.contains(widget.article.title ?? '')) {
              docRef = doc.reference;
              foundDocId = doc.id;
              print('✅ ENCONTRADO por autor y título similar! ID: $foundDocId');
              break;
            }
          }
          
          if (docRef == null && querySnapshot.docs.isNotEmpty) {
            docRef = querySnapshot.docs.first.reference;
            foundDocId = querySnapshot.docs.first.id;
            print('⚠️  Tomando el primer documento del autor. ID: $foundDocId');
          }
        }
      }
      
      if (docRef == null) {
        throw Exception('''
❌ NO SE PUDO ENCONTRAR EL ARTÍCULO EN FIRESTORE

Posibles causas:
1. El artículo no existe en Firestore
2. Los datos no coinciden (título/autor diferentes)
3. Problema de conexión con Firestore

Datos buscados:
• Título: "${widget.article.title}"
• Autor: "${widget.article.author}"
• ID local: ${widget.article.id}

Verifica en Firebase Console que el artículo exista.
''');
      }
      
      print('🎯 DOCUMENTO ENCONTRADO - ID: $foundDocId');
      await _updateDocument(docRef);
      
    } catch (e) {
      print('❌❌❌ ERROR AL BUSCAR/GUARDAR: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString().substring(0, 100)}...'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDocument(DocumentReference docRef) async {
    final updateData = {
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      ' content': _contentController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    print('📝 ACTUALIZANDO DOCUMENTO...');
    print('   Nuevo título: ${updateData['title']}');
    print('   Nuevo autor: ${updateData['author']}');
    
    final contentValue = updateData[' content'];
    if (contentValue is String) {
      print('   Nuevo contenido: ${contentValue.length} caracteres');
    }
    
    await docRef.update(updateData);
    
    print('✅✅✅ CAMBIOS GUARDADOS EXITOSAMENTE en Firestore');
    print('   Documento actualizado: ${docRef.id}');
    print('   Fecha de actualización: ${DateTime.now()}');
    
    // ✅✅✅ SOLUCIÓN DEFINITIVA: FORZAR DELAY Y RECARGA
    if (context.mounted) {
      print('🔄 EDIT_ARTICLE: Esperando 2 segundos para que Firestore se actualice...');
      
      // 1. ESPERAR que Firestore propague los cambios
      await Future.delayed(const Duration(seconds: 2));
      
      print('🔄 EDIT_ARTICLE: Disparando RefreshArticles...');
      
      // 2. AGREGAR LOGS EXTRA para diagnosticar
      final bloc = context.read<RemoteArticlesBloc>();
      print('   ✅ Bloc disponible: ${bloc != null}');
      
      // 3. DISPARAR el evento MÚLTIPLES veces
      bloc.add(RefreshArticles());
      print('   ✅ RefreshArticles enviado (1ra vez)');
      
      // 4. Esperar un poco y disparar de nuevo
      await Future.delayed(const Duration(milliseconds: 500));
      bloc.add(RefreshArticles());
      print('   ✅ RefreshArticles enviado (2da vez)');
      
      // 5. También disparar GetArticles por si acaso
      await Future.delayed(const Duration(milliseconds: 300));
      bloc.add(GetArticles());
      print('   ✅ GetArticles enviado (3ra vez)');
      
      print('✅ EDIT_ARTICLE: Todos los eventos enviados');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Artículo actualizado. Recargando lista...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Esperar antes de regresar
    await Future.delayed(const Duration(seconds: 1));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDITAR ARTÍCULO'),
        backgroundColor: Colors.deepOrange,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveChanges,
                  tooltip: 'Guardar en Firestore',
                ),
        ],
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Título:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: 'Escribe el título...',
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Autor:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _authorController,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: 'Nombre del autor...',
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                const Text(
                  'Contenido:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _contentController.text.isEmpty ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_contentController.text.length} caracteres',
                    style: TextStyle(
                      fontSize: 12,
                      color: _contentController.text.isEmpty ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Escribe el contenido del artículo aquí...',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  minimumSize: const Size(250, 50),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text('Buscando y Guardando...', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      )
                    : const Text(
                        'BUSCAR Y GUARDAR EN FIRESTORE',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Información del artículo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Text('ID local: ${widget.article.id ?? "No disponible"}', style: const TextStyle(fontSize: 12)),
                  Text('Tipo ID: ${widget.article.id.runtimeType}', style: const TextStyle(fontSize: 12)),
                  Text('Título original: "${widget.article.title}"', style: const TextStyle(fontSize: 12)),
                  Text('Autor original: "${widget.article.author}"', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 5),
                  const Text(
                    '⚠️  Este formulario buscará automáticamente el artículo en Firestore usando el título.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}