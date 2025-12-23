// lib/features/daily_news/data/models/article.dart
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';

class ArticleModel extends ArticleEntity {
  final String? id;
  
  const ArticleModel({
    this.id,
    String? author,
    String? title,
    String? description,
    String? url,
    String? urlToImage,
    String? publishedAt,  // publishedAt ES STRING
    String? content,
    bool? published,      // ✅ AÑADIDO: published ES BOOL
  }): super(
    id: id,
    author: author,
    title: title,
    description: description,
    url: url,
    urlToImage: urlToImage,
    publishedAt: publishedAt,  // String
    content: content,
    published: published,      // ✅ PASANDO EL NUEVO CAMPO BOOL
  );

  // Si tienes factory fromJson y toJson, asegúrate de manejar ambos campos:
  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id']?.toString(),
      author: json['author']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString(),
      urlToImage: json['urlToImage']?.toString(),
      publishedAt: json['publishedAt']?.toString(),
      content: json['content']?.toString(),
      published: json['published'] as bool?,  // ✅ MANEJANDO published
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'title': title,
      'description': description,
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt,
      'content': content,
      'published': published,  // ✅ INCLUYENDO published
    };
  }
}