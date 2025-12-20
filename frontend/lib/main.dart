import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:news_app_clean_architecture/config/routes/routes.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/home/daily_news.dart';
import 'config/theme/app_themes.dart';
import 'features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔧 ==================== INICIANDO APP ====================');
  
  try {
    print('1️⃣  Inicializando Firebase...');
    await Firebase.initializeApp();
    print('✅  Firebase inicializado CORRECTAMENTE');
  } catch (e) {
    print('❌  ERROR CRÍTICO en Firebase: $e');
    
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('ERROR DE FIREBASE', style: TextStyle(fontSize: 20, color: Colors.red)),
              const SizedBox(height: 20),
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const Text('Revisa la consola para detalles'),
            ],
          ),
        ),
      ),
    ));
    return;
  }
  
  try {
    print('2️⃣  Inicializando dependencias...');
    await initializeDependencies();
    print('✅  Dependencias inicializadas');
  } catch (e) {
    print('❌  ERROR en dependencias: $e');
  }
  
  print('3️⃣  Todo listo. Ejecutando MyApp...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RemoteArticlesBloc>(
      create: (context) {
        print('🎭  Creando RemoteArticlesBloc...');
        final bloc = sl<RemoteArticlesBloc>();
        
        // Solo imprimir el estado genérico
        bloc.stream.listen((state) {
          print('📱  [Bloc State] $state');
        });
        
        return bloc;
      },
      
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme(),
        onGenerateRoute: AppRoutes.onGenerateRoutes,
        home: const DailyNews(),
        
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Ruta no encontrada: ${settings.name}')),
          ),
        ),
      ),
    );
  }
}