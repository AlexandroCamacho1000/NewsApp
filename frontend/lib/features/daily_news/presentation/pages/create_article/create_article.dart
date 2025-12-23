// lib/features/daily_news/presentation/pages/create_article/create_article.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// IMPORTAR ESTOS NUEVOS
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/repository/article_repository_impl.dart';

class CreateArticlePage extends StatefulWidget {
  const CreateArticlePage({Key? key}) : super(key: key);

  @override
  State<CreateArticlePage> createState() => _CreateArticlePageState();
}

class _CreateArticlePageState extends State<CreateArticlePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();
  
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // Función para seleccionar imagen
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Función para subir imagen a Firebase Storage
  Future<String?> _uploadImage(String articleId) async {
    if (_selectedImage == null) return null;
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('media/articles/$articleId/thumbnail.jpg');
      
      await storageRef.putFile(_selectedImage!);
      final downloadURL = await storageRef.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error subiendo imagen: $e');
      return null;
    }
  }

  // FUNCIÓN CORREGIDA: Sin getIt, instanciando directamente
  Future<void> _saveArticle() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Generar un ID temporal para la imagen
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      // 2. Subir imagen si existe
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(tempId);
        print('🖼️ Imagen subida: $imageUrl');
      }
      
      // 3. Usar URL por defecto si no hay imagen
      imageUrl ??= 'https://picsum.photos/1200/630';
      
      // 4. Crear la entidad ArticleEntity - ⭐⭐ CORREGIDO: id: null en lugar de 0
      final article = ArticleEntity(
        id: null, // ⭐⭐ CORREGIDO: Cambiar de 0 a null
        author: _authorController.text.isNotEmpty 
            ? _authorController.text 
            : 'Anónimo',
        title: _titleController.text,
        description: _generateExcerpt(_contentController.text),
        url: '',
        urlToImage: imageUrl,
        publishedAt: DateTime.now().toIso8601String(),
        content: _contentController.text,
      );
      
      // 5. ✅ CREAR REPOSITORIO DIRECTAMENTE (sin getIt)
      final repository = ArticleRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );
      
      await repository.saveArticle(article);
      
      print('✅ Artículo guardado usando repositorio');
      
      // 6. Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Artículo publicado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // 7. Esperar y regresar
      await Future.delayed(const Duration(milliseconds: 1000));
      Navigator.pop(context);
      
    } catch (e) {
      print('❌ Error al guardar artículo: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Función auxiliar para generar excerpt
  String _generateExcerpt(String content, {int length = 150}) {
    if (content.length <= length) return content;
    return '${content.substring(0, length)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear Nuevo Artículo',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _saveArticle,
              child: const Text(
                'Publicar',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Título del artículo',
                  hintText: 'Escribe un título atractivo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.title, color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un título';
                  }
                  if (value.length < 5) {
                    return 'El título debe tener al menos 5 caracteres';
                  }
                  return null;
                },
                maxLength: 200,
              ),
              const SizedBox(height: 20),

              // Selector de imagen
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Toca para seleccionar una imagen',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Recomendado: 1200x630px',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Contenido
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: 'Contenido',
                  hintText: 'Escribe el contenido completo de tu artículo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontSize: 15, height: 1.5),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor escribe el contenido';
                  }
                  if (value.length < 50) {
                    return 'El contenido debe tener al menos 50 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Autor
              TextFormField(
                controller: _authorController,
                decoration: InputDecoration(
                  labelText: 'Tu nombre (autor)',
                  hintText: 'Cómo quieres que te identifiquen',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.person, color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Botón de publicar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveArticle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        )
                      : const Text(
                          'Publicar Artículo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}