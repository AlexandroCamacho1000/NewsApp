import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart'; // Importar para formatear fechas
import '../../../../../injection_container.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart';

class ArticleDetailsView extends HookWidget {
  final ArticleEntity? article;

  const ArticleDetailsView({Key? key, this.article}) : super(key: key);

  // Función para formatear la fecha de manera elegante
  String _formatPublishedDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Fecha no disponible';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // Formato español para días de la semana
      final Map<int, String> weekdays = {
        1: 'Lunes',
        2: 'Martes',
        3: 'Miércoles',
        4: 'Jueves',
        5: 'Viernes',
        6: 'Sábado',
        7: 'Domingo',
      };
      
      // Formato español para meses
      final Map<int, String> months = {
        1: 'Enero',
        2: 'Febrero',
        3: 'Marzo',
        4: 'Abril',
        5: 'Mayo',
        6: 'Junio',
        7: 'Julio',
        8: 'Agosto',
        9: 'Septiembre',
        10: 'Octubre',
        11: 'Noviembre',
        12: 'Diciembre',
      };
      
      // Si es hoy
      if (difference.inDays == 0) {
        final hour = DateFormat('HH:mm').format(date);
        return 'Hoy a las $hour';
      }
      
      // Si es ayer
      if (difference.inDays == 1) {
        final hour = DateFormat('HH:mm').format(date);
        return 'Ayer a las $hour';
      }
      
      // Si es esta semana (últimos 7 días)
      if (difference.inDays < 7) {
        final weekday = weekdays[date.weekday] ?? DateFormat('EEEE').format(date);
        final hour = DateFormat('HH:mm').format(date);
        return '$weekday a las $hour';
      }
      
      // Si es este año
      if (date.year == now.year) {
        final month = months[date.month] ?? DateFormat('MMMM').format(date);
        final day = date.day;
        final hour = DateFormat('HH:mm').format(date);
        return '$day de $month a las $hour';
      }
      
      // Formato completo
      final month = months[date.month] ?? DateFormat('MMMM').format(date);
      final day = date.day;
      final year = date.year;
      final hour = DateFormat('HH:mm').format(date);
      return '$day de $month de $year a las $hour';
    } catch (e) {
      // Si hay error en el parseo, devolver el string original
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LocalArticleBloc>(),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onBackButtonTapped(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Ionicons.chevron_back, color: Colors.black87, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildArticleTitleAndDate(),
          _buildArticleImage(),
          _buildArticleDescription(),
        ],
      ),
    );
  }

  Widget _buildArticleTitleAndDate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha formateada (lo moví arriba para mejor visibilidad)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Ionicons.time_outline,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatPublishedDate(article!.publishedAt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Título
          Text(
            article!.title!,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Información del autor si existe
          if (article!.author != null && article!.author!.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Ionicons.person,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    article!.author!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildArticleImage() {
    return Container(
      width: double.maxFinite,
      height: 280,
      margin: const EdgeInsets.only(top: 14),
      child: Image.network(
        article!.urlToImage!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Ionicons.image_outline,
                size: 60,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción
          if (article!.description != null && article!.description!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article!.description!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          
          // Contenido
          if (article!.content != null && article!.content!.isNotEmpty)
            Text(
              article!.content!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.7,
              ),
            ),
          
          const SizedBox(height: 30),
          
          // Separador decorativo
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          
          const SizedBox(height: 20),
          
          // Información adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fecha nuevamente (para referencia)
              Row(
                children: [
                  Icon(
                    Ionicons.calendar_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatPublishedDate(article!.publishedAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              // Compartir
              IconButton(
                onPressed: () {
                  // TODO: Implementar compartir
                },
                icon: Icon(
                  Ionicons.share_social_outline,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Builder(
      builder: (context) => FloatingActionButton(
        onPressed: () => _onFloatingActionButtonPressed(context),
        backgroundColor: Colors.blue[600],
        child: const Icon(Ionicons.bookmark, color: Colors.white),
      ),
    );
  }

  void _onBackButtonTapped(BuildContext context) {
    Navigator.pop(context);
  }

  void _onFloatingActionButtonPressed(BuildContext context) {
    BlocProvider.of<LocalArticleBloc>(context).add(SaveArticle(article!));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[600],
        content: Row(
          children: [
            const Icon(Ionicons.checkmark_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Artículo guardado en favoritos',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}