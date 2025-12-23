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
    
    print('\n🔍🔍🔍 EDITARTICLE - INICIANDO 🔍🔍🔍');
    print('   ID del artículo: ${widget.article.id}');
    print('   Tipo de ID: ${widget.article.id.runtimeType}');
    print('   Título: "${widget.article.title}"');
    print('   Autor: "${widget.article.author}"');
    print('   Contenido length: ${widget.article.content?.length ?? 0}');
    print('   Descripción length: ${widget.article.description?.length ?? 0}');
    
    String contenidoFinal = widget.article.content ?? '';
    
    if ((contenidoFinal.isEmpty || contenidoFinal == 'null') && 
        widget.article.description != null) {
      contenidoFinal = widget.article.description!;
      print('   ⚠️ Usando descripción como contenido: ${contenidoFinal.length} caracteres');
    }
    
    _titleController = TextEditingController(text: widget.article.title ?? '');
    _contentController = TextEditingController(text: contenidoFinal);
    _authorController = TextEditingController(text: widget.article.author ?? '');
    
    print('✅ EditArticle inicializado correctamente');
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
      print('\n💾💾💾 INICIANDO GUARDADO DE CAMBIOS 💾💾💾');
      print('   Título editado: "${_titleController.text}"');
      print('   Autor editado: "${_authorController.text}"');
      print('   Contenido editado: ${_contentController.text.length} caracteres');
      print('   ID del artículo: ${widget.article.id}');
      
      if (widget.article.id == null || widget.article.id.toString().isEmpty) {
        throw Exception('❌ El artículo no tiene ID válido');
      }
      
      final articleId = widget.article.id.toString();
      print('   🔍 Buscando documento con ID: $articleId');
      
      QuerySnapshot querySnapshot;
      DocumentReference? docRef;
      String? foundDocId;
      
      if (articleId.isNotEmpty) {
        print('   🎯 Intentando búsqueda por ID directo: $articleId');
        
        final directRef = FirebaseFirestore.instance.collection('articles').doc(articleId);
        final directSnapshot = await directRef.get();
        
        if (directSnapshot.exists) {
          docRef = directRef;
          foundDocId = articleId;
          print('   ✅✅✅ ENCONTRADO POR ID DIRECTO!');
        } else {
          print('   ⚠️ No encontrado por ID directo');
        }
      }
      
      if (docRef == null) {
        final title = _titleController.text.trim();
        if (title.isNotEmpty) {
          print('   🔍 Buscando por título: "$title"');
          
          querySnapshot = await FirebaseFirestore.instance
              .collection('articles')
              .where('title', isEqualTo: title)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            docRef = querySnapshot.docs.first.reference;
            foundDocId = querySnapshot.docs.first.id;
            print('   ✅ Encontrado por título! ID: $foundDocId');
          } else {
            print('   ⚠️ No encontrado por título');
          }
        }
      }
      
      if (docRef == null && widget.article.title != null) {
        final originalTitle = widget.article.title!.trim();
        if (originalTitle.isNotEmpty) {
          print('   🔍 Buscando por título original: "$originalTitle"');
          
          querySnapshot = await FirebaseFirestore.instance
              .collection('articles')
              .where('title', isEqualTo: originalTitle)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            docRef = querySnapshot.docs.first.reference;
            foundDocId = querySnapshot.docs.first.id;
            print('   ✅ Encontrado por título original! ID: $foundDocId');
          }
        }
      }
      
      if (docRef == null) {
        throw Exception('''
❌ NO SE PUDO ENCONTRAR EL ARTÍCULO EN FIRESTORE

ID buscado: ${widget.article.id}
Título buscado: "${_titleController.text}"
Título original: "${widget.article.title}"

Verifica en Firebase Console que el artículo exista.
''');
      }
      
      print('🎯🎯🎯 DOCUMENTO ENCONTRADO - ID: $foundDocId');
      await _updateDocument(docRef);
      
    } catch (e) {
      print('❌❌❌ ERROR AL BUSCAR/GUARDAR: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDocument(DocumentReference docRef) async {
    try {
      final updateData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'content': _contentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('\n📝📝📝 ACTUALIZANDO DOCUMENTO EN FIRESTORE 📝📝📝');
      print('   Document ID: ${docRef.id}');
      print('   Nuevo título: "${updateData['title']}"');
      print('   Nuevo autor: "${updateData['author']}"');
      print('   Nuevo contenido: ${updateData['content'] is String ? 
            (updateData['content'] as String).length.toString() + " caracteres" : "null"}');
      
      if (updateData['content'] is String) {
        final content = updateData['content'] as String;
        if (content.isNotEmpty) {
          final preview = content.length > 100 
              ? content.substring(0, 100) + '...' 
              : content;
          print('   Preview: "$preview"');
        }
      }
      
      await docRef.update(updateData);
      
      print('✅✅✅ CAMBIOS GUARDADOS EXITOSAMENTE en Firestore');
      print('   Documento actualizado: ${docRef.id}');
      print('   Fecha de actualización: ${DateTime.now()}');
      
      final updatedSnapshot = await docRef.get();
      final updatedData = updatedSnapshot.data() as Map<String, dynamic>;
      
      print('🔍 VERIFICACIÓN POST-ACTUALIZACIÓN:');
      print('   • Campos: ${updatedData.keys.join(', ')}');
      print('   • Valor de "content": ${updatedData['content'] is String ? 
            'String (${(updatedData['content'] as String).length} chars)' : 
            updatedData['content']}');
      
      if (context.mounted) {
        print('🔄 EDIT_ARTICLE: Disparando RefreshArticles...');
        
        final bloc = context.read<RemoteArticlesBloc>();
        
        bloc.add(RefreshArticles());
        print('   ✅ RefreshArticles enviado (1ra vez)');
        
        await Future.delayed(const Duration(milliseconds: 300));
        bloc.add(RefreshArticles());
        print('   ✅ RefreshArticles enviado (2da vez)');
        
        await Future.delayed(const Duration(milliseconds: 300));
        bloc.add(GetArticles());
        print('   ✅ GetArticles enviado (3ra vez)');
        
        print('✅ Todos los eventos enviados para refrescar');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Artículo actualizado. Recargando lista...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('❌❌❌ ERROR AL ACTUALIZAR DOCUMENTO: $e');
      rethrow;
    }
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
                    alignLabelWithHint: true, // ⭐⭐ CORREGIDO: Hit → Hint
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
                        'GUARDAR CAMBIOS EN FIRESTORE',
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