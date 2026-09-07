import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'firebase_config.dart';
import 'pages/academy_profile_page.dart';
import 'pages/add_child_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/home_page.dart';
import 'pages/inicio_page.dart';
import 'pages/join_team_page.dart';
import 'pages/login_page.dart';
import 'pages/mi_perfil_page.dart';
import 'pages/player_dashboard_page.dart';
import 'pages/match_detail.dart';
import 'pages/player_stat_detail_page.dart';
import 'services/tournament_detail_route.dart';
import 'pages/tournament_detail_page.dart';
import 'pages/torneos_page.dart';
import 'services/academy_profile_route.dart';
import 'services/api_service.dart';
import 'services/curp_service.dart';
import 'services/join_team_link.dart';
import 'services/match_detail_route.dart';
import 'services/player_dashboard_route.dart';
import 'services/push_notification_service.dart'
    show PushNotificationService, firebaseMessagingBackgroundHandler;
import 'services/pwa_update_service.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';
import 'services/toast_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final ApiService appApi = ApiService(
  apiUrl: AppConfig.apiUrl,
  apiCal: AppConfig.apiCal,
  apiCdb: AppConfig.apiCdb,
  token: AppConfig.apiToken,
);
final StorageService appStorage = StorageService();
final CurpService appCurpService = CurpService(appApi);
final SocketService appSocketService = SocketService();
final PushNotificationService appPushService = PushNotificationService(
  apiService: appApi,
  storageService: appStorage,
  navigatorKey: appNavigatorKey,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  await initializeDateFormatting('es_ES', null);
  await Firebase.initializeApp(options: FirebaseConfig.options);
  // En Web/PWA el segundo plano lo maneja firebase-messaging-sw.js, no este handler.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  if (kIsWeb) {
    usePathUrlStrategy();
    initPwaUpdateBridge();
  }
  runApp(const MyApp());
}

Route<dynamic>? _buildRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  if (JoinTeamLink.isJoinTeamRoute(name)) {
    final token = JoinTeamLink.initialToken(
      routeArguments: settings.arguments,
      routeName: name,
    );
    return MaterialPageRoute(
      builder: (_) => JoinTeamPage(
        api: appApi,
        storage: appStorage,
        teamToken: token,
      ),
      settings: RouteSettings(name: JoinTeamPage.route, arguments: settings.arguments),
    );
  }

  if (name == '/' || name == LoginPage.route) {
    return MaterialPageRoute(
      builder: (_) => LoginPage(api: appApi, storage: appStorage),
      settings: const RouteSettings(name: LoginPage.route),
    );
  }

  if (name == EmailVerificationPage.route) {
    return MaterialPageRoute(
      builder: (_) => EmailVerificationPage(api: appApi, storage: appStorage),
      settings: settings,
    );
  }

  if (name == HomePage.route ||
      name == InicioPage.route ||
      name == MiPerfilPage.route) {
    return MaterialPageRoute(
      builder: (_) => HomePage(
        api: appApi,
        storage: appStorage,
        pushService: appPushService,
        socketService: appSocketService,
        curpService: appCurpService,
      ),
      settings: settings,
    );
  }

  if (name == AddChildPage.route) {
    final args = (settings.arguments as Map<String, dynamic>?) ?? {};
    return MaterialPageRoute(
      builder: (_) => AddChildPage(
        api: appApi,
        curpService: appCurpService,
        parentId: args['parentId']?.toString() ?? '',
        prefillCurp: args['prefillCurp']?.toString(),
        initialChild: args['child'] is Map
            ? Map<String, dynamic>.from(args['child'] as Map)
            : null,
        parentName: args['parentName']?.toString(),
        parentCurp: args['parentCurp']?.toString(),
        parentApPa: args['parentApPa']?.toString(),
        parentApMa: args['parentApMa']?.toString(),
        isSelfRegister: args['isSelfRegister'] == true,
      ),
      settings: settings,
    );
  }

  if (PlayerDashboardRoute.matches(name)) {
    final resolved = PlayerDashboardRoute.resolve(
      routeName: name,
      arguments: settings.arguments is Map
          ? Map<String, dynamic>.from(settings.arguments as Map)
          : null,
    );
    return MaterialPageRoute(
      builder: (_) => PlayerDashboardPage(
        api: appApi,
        storage: appStorage,
        socketService: appSocketService,
        playerId: resolved.playerId,
        playerName: resolved.playerName,
        autoOpenRequests: resolved.autoOpenRequests,
        initialTab: resolved.initialTab,
        viewOnly: resolved.viewOnly,
        playerRelation: resolved.playerRelation,
        canManage: resolved.canManage,
      ),
      settings: RouteSettings(
        name: resolved.canonicalName,
        arguments: resolved.toArguments(),
      ),
    );
  }

  if (MatchDetailRoute.matches(name)) {
    final resolved = MatchDetailRoute.resolve(
      routeName: name,
      arguments: settings.arguments,
    );
    return MaterialPageRoute(
      builder: (_) => MatchDetailPage(
        api: appApi,
        socketService: appSocketService,
      ),
      settings: RouteSettings(
        name: resolved.canonicalName,
        arguments: resolved.toRouteArgs(),
      ),
    );
  }

  if (name == PlayerStatDetailPage.route || name == '/player_stat_detail') {
    return MaterialPageRoute(
      builder: (_) => PlayerStatDetailPage(api: appApi),
      settings: settings,
    );
  }

  if (name == TorneosPage.route) {
    return MaterialPageRoute(
      builder: (_) => TorneosPage(api: appApi),
      settings: settings,
    );
  }

  if (TournamentDetailRoute.matches(name)) {
    final tournamentKey = TournamentDetailRoute.keyFromRoute(name);
    if (tournamentKey == null || tournamentKey.isEmpty) {
      return null;
    }
    final args = settings.arguments is Map
        ? Map<String, dynamic>.from(settings.arguments as Map)
        : <String, dynamic>{};
    return MaterialPageRoute(
      builder: (_) => TournamentDetailPage(
        api: appApi,
        tournamentClave: tournamentKey,
      ),
      settings: RouteSettings(
        name: settings.name,
        arguments: {
          ...args,
          if (args['clave'] == null && args['id'] == null) 'id': tournamentKey,
          if (args['clave'] == null) 'clave': tournamentKey,
        },
      ),
    );
  }

  if (AcademyProfileRoute.matches(name)) {
    final resolved = AcademyProfileRoute.resolve(
      routeName: name,
      arguments: settings.arguments is Map
          ? Map<String, dynamic>.from(settings.arguments as Map)
          : null,
    );
    if (resolved.academyId.isEmpty) {
      return null;
    }
    return MaterialPageRoute(
      builder: (_) => AcademyProfilePage(
        api: appApi,
        academyId: resolved.academyId,
        sourceTournamentId: resolved.sourceTournamentId,
      ),
      settings: RouteSettings(
        name: resolved.canonicalName,
        arguments: resolved.toArguments(),
      ),
    );
  }

  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'user_tp',
      theme: AppTheme.themeData,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: ToastService.rootMessengerKey,
      onGenerateInitialRoutes: (String initialRouteName) {
        final route = _buildRoute(RouteSettings(name: initialRouteName)) ??
            _buildRoute(const RouteSettings(name: LoginPage.route))!;
        return [route];
      },
      onGenerateRoute: _buildRoute,
      onUnknownRoute: (settings) =>
          _buildRoute(const RouteSettings(name: LoginPage.route))!,
    );
  }
}
