import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'firebase_config.dart';
import 'pages/add_child_page.dart';
import 'pages/home_page.dart';
import 'pages/inicio_page.dart';
import 'pages/login_page.dart';
import 'pages/mi_perfil_page.dart';
import 'pages/player_dashboard_page.dart';
import 'services/api_service.dart';
import 'services/curp_service.dart';
import 'services/push_notification_service.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfig.options);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();
    final api = ApiService(
      apiUrl: AppConfig.apiUrl,
      apiCal: AppConfig.apiCal,
      apiCdb: AppConfig.apiCdb,
      token: AppConfig.apiToken,
    );
    final storage = StorageService();
    final curpService = CurpService(api);
    final pushService = PushNotificationService(
      apiService: api,
      storageService: storage,
      navigatorKey: navigatorKey,
    );
    final socketService = SocketService();

    return MaterialApp(
      title: 'user_tp',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      navigatorKey: navigatorKey,
      initialRoute: LoginPage.route,
      routes: {
        LoginPage.route: (_) => LoginPage(api: api, storage: storage),
        HomePage.route: (_) => HomePage(
              api: api,
              storage: storage,
              pushService: pushService,
              socketService: socketService,
            ),
        InicioPage.route: (_) => HomePage(
              api: api,
              storage: storage,
              pushService: pushService,
              socketService: socketService,
            ),
        MiPerfilPage.route: (_) => HomePage(
              api: api,
              storage: storage,
              pushService: pushService,
              socketService: socketService,
            ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AddChildPage.route) {
          final args = (settings.arguments as Map<String, dynamic>?) ?? {};
          return MaterialPageRoute(
            builder: (_) => AddChildPage(
              api: api,
              curpService: curpService,
              parentId: args['parentId']?.toString() ?? '',
              prefillCurp: args['prefillCurp']?.toString(),
              initialChild: args['child'] is Map
                  ? Map<String, dynamic>.from(args['child'] as Map)
                  : null,
            ),
          );
        }
        if (settings.name == PlayerDashboardPage.route) {
          final args = (settings.arguments as Map<String, dynamic>?) ?? {};
          return MaterialPageRoute(
            builder: (_) => PlayerDashboardPage(
              api: api,
              storage: storage,
              socketService: socketService,
              playerId: args['playerId']?.toString() ?? '',
              playerName: args['playerName']?.toString() ?? 'Perfil',
              autoOpenRequests: args['verSolicitudes']?.toString() == 'true',
            ),
          );
        }
        return null;
      },
    );
  }
}
