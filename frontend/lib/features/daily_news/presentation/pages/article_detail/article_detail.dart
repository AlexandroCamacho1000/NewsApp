import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import '../../../../../injection_container.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart';
import '../edit_article/edit_article.dart';

class ArticleDetailsView extends HookWidget {
  final ArticleEntity? article;
  const ArticleDetailsView({Key? key, this.article}) : super(key: key);

  String _formatPublishedDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Fecha no disponible';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        final hour = DateFormat('HH:mm').format(date);
        return 'Hoy a las $hour';
      }
      if (difference.inDays == 1) {
        final hour = DateFormat('HH:mm').format(date);
        return 'Ayer a las $hour';
      }
      if (difference.inDays < 7) {
        final weekday = DateFormat('EEEE', 'es').format(date);
        final hour = DateFormat('HH:mm').format(date);
        return '$weekday a las $hour';
      }
      if (date.year == now.year) {
        final month = DateFormat('MMMM', 'es').format(date);
        final day = date.day;
        final hour = DateFormat('HH:mm').format(date);
        return '$day de $month a las $hour';
      }
      final month = DateFormat('MMMM', 'es').format(date);
      final day = date.day;
      final year = date.year;
      final hour = DateFormat('HH:mm').format(date);
      return '$day de $month de $year a las $hour';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LocalArticleBloc>(),
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildBody(context),
        floatingActionButton: _buildFloatingActionButton(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Ionicons.chevron_back, color: Colors.black87, size: 24),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _onEditButtonPressed(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Ionicons.create_outline, color: Colors.orange, size: 22),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildArticleTitleAndDate(),
          _buildArticleImage(),
          _buildArticleDescription(context),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Ionicons.time_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  _formatPublishedDate(article!.publishedAt),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            article!.title!,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87, height: 1.3),
          ),
          const SizedBox(height: 16),
          if (article!.author != null && article!.author!.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(18)),
                  child: Icon(Ionicons.person, size: 18, color: Colors.grey[600]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(article!.author!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
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
            child: Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.grey[200], child: const Center(child: Icon(Ionicons.image_outline, size: 60, color: Colors.grey)));
        },
      ),
    );
  }

  Widget _buildArticleDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article!.description != null && article!.description!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article!.description!, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.6)),
                const SizedBox(height: 24),
              ],
            ),
          if (article!.content != null && article!.content!.isNotEmpty)
            Text(article!.content!, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.7)),
          const SizedBox(height: 30),
          Container(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _onEditButtonPressed(context),
                icon: const Icon(Ionicons.create_outline, size: 18),
                label: const Text('Editar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[50],
                  foregroundColor: Colors.orange[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartir'), duration: Duration(seconds: 2)));
                },
                icon: const Icon(Ionicons.share_social_outline, size: 18),
                label: const Text('Compartir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        BlocProvider.of<LocalArticleBloc>(context).add(SaveArticle(article!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[600],
            content: Row(
              children: [
                const Icon(Ionicons.checkmark_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('Artículo guardado', style: TextStyle(color: Colors.white)),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      },
      backgroundColor: Colors.blue[600],
      child: const Icon(Ionicons.bookmark, color: Colors.white),
    );
  }

  // ⭐⭐ FUNCIÓN PARA EDITAR ARTÍCULO - VERSIÓN CORREGIDA
  void _onEditButtonPressed(BuildContext context) {
    print('🚀 Navegando a EditArticlePage...');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditArticlePage(
          article: article!,
        ),
      ),
    );
  }
}