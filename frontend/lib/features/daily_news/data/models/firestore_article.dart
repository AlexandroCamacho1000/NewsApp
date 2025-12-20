// lib/features/daily_news/data/models/firestore_article.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';

class FirestoreArticle {
  final String id;
  final String title;
  final String content;
  final String excerpt;
  final String thumbnailURL;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool published;

  FirestoreArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.thumbnailURL,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    required this.published,
  });

  factory FirestoreArticle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FirestoreArticle(
      id: doc.id,
      title: data['title'] ?? 'Sin título',
      content: data['content'] ?? '',
      excerpt: data['excerpt'] ?? '',
      thumbnailURL: data['thumbnailURL'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      published: data['published'] ?? false,
    );
  }

  ArticleEntity toEntity() {
    return ArticleEntity(
      id: id.hashCode, // O generar un ID diferente
      author: authorId, // Convertir authorId → author
      title: title,
      description: excerpt, // excerpt → description
      url: '', // Dejar vacío o poner URL del artículo
      urlToImage: thumbnailURL, // thumbnailURL → urlToImage
      publishedAt: createdAt.toIso8601String(),
      content: content,
    );
  }
}