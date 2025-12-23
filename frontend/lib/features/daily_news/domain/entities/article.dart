import 'package:equatable/equatable.dart';

class ArticleEntity extends Equatable{
  final String? id;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final String? publishedAt;
  final String? content;
  final bool? published; // ✅ AÑADE ESTA LÍNEA

  const ArticleEntity({
    this.id,
    this.author,
    this.title,
    this.description,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
    this.published, // ✅ AÑADE ESTE PARÁMETRO
  });

  @override
  List<Object?> get props {
    return [
      id,
      author,
      title,
      description,
      url,
      urlToImage,
      publishedAt,
      content,
      published, // ✅ INCLÚYELO EN LOS PROPS
    ];
  }
}