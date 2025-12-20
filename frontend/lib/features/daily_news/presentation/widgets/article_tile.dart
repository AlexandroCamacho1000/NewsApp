import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/article.dart';

// ⭐⭐ LOGGING PROFESIONAL PARA DEBUG
import 'dart:developer';

void _logImageDebug(String title, String? url, String event) {
  debugPrint('🖼️ [IMAGE_DEBUG] $event');
  debugPrint('   📍 Artículo: $title');
  debugPrint('   🔗 URL: ${url ?? "null"}');
  debugPrint('   📅 Timestamp: ${DateTime.now().toIso8601String()}');
  debugPrint('   ---');
}

class ArticleWidget extends StatelessWidget {
  final ArticleEntity? article;
  final bool? isRemovable;
  final void Function(ArticleEntity article)? onRemove;
  final void Function(ArticleEntity article)? onArticlePressed;

  const ArticleWidget({
    Key? key,
    this.article,
    this.onArticlePressed,
    this.isRemovable = false,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
            start: 14, end: 14, bottom: 7, top: 7),
        height: MediaQuery.of(context).size.width / 2.2,
        child: Row(
          children: [
            _buildImage(context),
            _buildTitleAndDescription(),
            _buildRemovableArea(),
          ],
        ),
      ),
    );
  }

  // ⭐⭐ FUNCIÓN COMPLETAMENTE CORREGIDA CON LOGGING
  Widget _buildImage(BuildContext context) {
    final articleTitle = article?.title ?? 'Sin título';
    final imageUrl = article?.urlToImage;
    
    // ✅ Logging profesional
    _logImageDebug(articleTitle, imageUrl, 'Iniciando carga');
    
    if (imageUrl == null || imageUrl.isEmpty) {
      _logImageDebug(articleTitle, imageUrl, 'URL vacía - Mostrando placeholder');
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: double.maxFinite,
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
          ),
        ),
      );
    }

    _logImageDebug(articleTitle, imageUrl, 'Configurando CachedNetworkImage');
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) {
        _logImageDebug(articleTitle, imageUrl, '✅ Imagen cargada exitosamente');
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              height: double.maxFinite,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                image: DecorationImage(
                  image: imageProvider, 
                  fit: BoxFit.cover
                ),
              ),
            ),
          ),
        );
      },
      progressIndicatorBuilder: (context, url, downloadProgress) {
        final progress = downloadProgress.progress ?? 0;
        _logImageDebug(articleTitle, url, '⏳ Cargando... ${(progress * 100).toStringAsFixed(0)}%');
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              height: double.maxFinite,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ),
        );
      },
      errorWidget: (context, url, error) {
        _logImageDebug(articleTitle, url, '❌ ERROR - ${error.toString()}');
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              height: double.maxFinite,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
            ),
          ),
        );
      },
      // ⭐⭐ CONFIGURACIONES PROFESIONALES
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      maxHeightDiskCache: 500,
      maxWidthDiskCache: 500,
      memCacheHeight: 500,
      memCacheWidth: 500,
      useOldImageOnUrlChange: true,
    );
  }

  Widget _buildTitleAndDescription() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              article!.title ?? 'Sin título',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Butler',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),

            // Autor
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      article!.author ?? 'Anónimo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Descripción
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  article!.description ?? 'Sin descripción',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            // Fecha - ✅ FORMATO MEJORADO
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateBeautifully(article!.publishedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO MÉTODO: Formatea la fecha de manera elegante
  String _formatDateBeautifully(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Hoy';
    }
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // Si es hoy
      if (date.year == now.year && 
          date.month == now.month && 
          date.day == now.day) {
        return 'Hoy';
      }
      
      // Si es ayer
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (date.year == yesterday.year && 
          date.month == yesterday.month && 
          date.day == yesterday.day) {
        return 'Ayer';
      }
      
      // Si es en los últimos 7 días
      if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} días';
      }
      
      // Si es este año
      if (date.year == now.year) {
        return DateFormat('d MMM', 'es_ES').format(date);
      }
      
      // Formato completo
      return DateFormat('d MMM yyyy', 'es_ES').format(date);
      
    } catch (e) {
      if (dateString != null && dateString.length >= 10) {
        return dateString.substring(0, 10);
      }
      return 'Fecha';
    }
  }

  Widget _buildRemovableArea() {
    if (isRemovable!) {
      return GestureDetector(
        onTap: _onRemove,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.remove_circle_outline, color: Colors.red),
        ),
      );
    }
    return Container();
  }

  void _onTap() {
    if (onArticlePressed != null) {
      onArticlePressed!(article!);
    }
  }

  void _onRemove() {
    if (onRemove != null) {
      onRemove!(article!);
    }
  }
}