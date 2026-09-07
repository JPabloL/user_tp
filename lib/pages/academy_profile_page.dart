import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../models/academy_profile_models.dart';
import '../services/academy_profile_route.dart';
import '../services/api_service.dart';
import '../services/toast_service.dart';
import '../utils/academy_profile_view_data.dart';
import '../utils/navigation_helpers.dart';
import '../widgets/academy_profile/academy_profile_hero.dart';
import '../widgets/academy_profile/academy_profile_layout.dart';
import '../widgets/academy_profile/academy_profile_skeleton.dart';
import '../widgets/academy_profile/academy_profile_states.dart';
import '../widgets/academy_profile/academy_profile_summary_tab.dart';
import '../widgets/academy_profile/academy_profile_trajectory_tab.dart';

class AcademyProfilePage extends StatefulWidget {
  const AcademyProfilePage({
    super.key,
    required this.api,
    this.academyId,
    this.sourceTournamentId,
  });

  static const String route = AcademyProfileRoute.baseRoute;

  final ApiService api;
  final String? academyId;
  final String? sourceTournamentId;

  @override
  State<AcademyProfilePage> createState() => _AcademyProfilePageState();
}

class _AcademyProfilePageState extends State<AcademyProfilePage>
    with SingleTickerProviderStateMixin {
  String? _academyId;
  String? _sourceTournamentId;
  bool _isInitialLoading = true;
  bool _isRetrying = false;
  bool _isRefreshing = false;
  String? _initialErrorMessage;
  AcademyProfileViewData? _viewData;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_academyId != null) return;

    final resolved = AcademyProfileRoute.resolve(
      routeName: ModalRoute.of(context)?.settings.name,
      arguments: ModalRoute.of(context)?.settings.arguments is Map
          ? Map<String, dynamic>.from(
              ModalRoute.of(context)!.settings.arguments as Map,
            )
          : null,
    );

    _academyId = widget.academyId?.trim().isNotEmpty == true
        ? widget.academyId!.trim()
        : resolved.academyId.trim();

    _sourceTournamentId = widget.sourceTournamentId?.trim().isNotEmpty == true
        ? widget.sourceTournamentId!.trim()
        : resolved.sourceTournamentId;

    if (_academyId == null || _academyId!.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _initialErrorMessage = 'ID de academia no válido';
      });
      return;
    }

    _loadProfile();
  }

  Future<void> _loadProfile({bool isRetry = false, bool isRefresh = false}) async {
    if (_academyId == null || _academyId!.isEmpty) return;

    final hadData = _viewData != null;

    setState(() {
      if (isRefresh && hadData) {
        _isRefreshing = true;
      } else if (isRetry) {
        _isRetrying = true;
      } else if (!hadData) {
        _isInitialLoading = true;
      }
      if (!isRefresh) {
        _initialErrorMessage = null;
      }
    });

    try {
      final response = await widget.api.getAcademyPublicProfile(_academyId!);
      final status = (response['status'] ?? '').toString().trim().toLowerCase();

      if (status != 'ok') {
        final message = (response['message'] ?? 'No se pudo cargar el perfil')
            .toString();
        setState(() {
          _isInitialLoading = false;
          _isRetrying = false;
          _isRefreshing = false;
          if (hadData) {
            ToastService.show(
              'No pudimos actualizar la información.',
              isError: true,
            );
          } else {
            _viewData = null;
            _initialErrorMessage = message;
          }
        });
        return;
      }

      final contextData = AcademyProfileContext.fromJson(response);
      setState(() {
        _viewData = AcademyProfileViewData(contextData);
        _isInitialLoading = false;
        _isRetrying = false;
        _isRefreshing = false;
        _initialErrorMessage = null;
      });
    } catch (_) {
      setState(() {
        _isInitialLoading = false;
        _isRetrying = false;
        _isRefreshing = false;
        if (hadData) {
          ToastService.show(
            'No pudimos actualizar la información.',
            isError: true,
          );
        } else {
          _viewData = null;
          _initialErrorMessage =
              'No pudimos obtener la información en este momento.';
        }
      });
    }
  }

  Future<void> _onRefresh() => _loadProfile(isRefresh: true);

  Widget _buildBackButton() {
    return Semantics(
      button: true,
      label: 'Volver',
      child: SizedBox(
        width: AcademyProfileLayout.minTouchTarget,
        height: AcademyProfileLayout.minTouchTarget,
        child: IconButton(
          onPressed: () => popOrGoHome(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Volver',
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppTheme.brandTeal,
      indicatorWeight: 3,
      labelColor: AppTheme.brandTeal,
      unselectedLabelColor: Colors.white54,
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      tabs: const [
        Tab(text: 'RESUMEN'),
        Tab(text: 'TRAYECTORIA'),
      ],
    );
  }

  SliverAppBar _buildHeroSliver(AcademyProfileViewData viewData, double heroHeight) {
    return SliverAppBar(
      expandedHeight: heroHeight,
      pinned: true,
      backgroundColor: AppTheme.navyPrimary,
      automaticallyImplyLeading: false,
      leading: _buildBackButton(),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: AcademyProfileHero(
          academy: viewData.context.academy,
          summary: viewData.context.summary,
        ),
      ),
      bottom: _buildTabBar(),
    );
  }

  Widget _buildContentBody(AcademyProfileViewData viewData, double heroHeight) {
    return RefreshIndicator(
      color: AppTheme.brandTeal,
      backgroundColor: AppTheme.navySurface,
      onRefresh: _onRefresh,
      child: NestedScrollView(
        key: ValueKey<String>('academy_nested_${viewData.academyId}'),
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: _buildHeroSliver(viewData, heroHeight),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AcademyProfileSummaryTab(
              key: ValueKey<String>('summary_${viewData.academyId}'),
              viewData: viewData,
              sourceTournamentId: _sourceTournamentId,
              tabController: _tabController,
              tabIndex: 0,
            ),
            AcademyProfileTrajectoryTab(
              key: ValueKey<String>('trajectory_${viewData.academyId}'),
              viewData: viewData,
              tabController: _tabController,
              tabIndex: 1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = AcademyProfileLayout.heroExpandedHeight(context);

    if (_isInitialLoading && _viewData == null) {
      return Scaffold(
        backgroundColor: AppTheme.navyPrimary,
        appBar: AppBar(
          backgroundColor: AppTheme.navyPrimary,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _buildBackButton(),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AcademyProfileSkeleton(heroHeight: heroHeight),
        ),
      );
    }

    if (_viewData == null) {
      return Scaffold(
        backgroundColor: AppTheme.navyPrimary,
        appBar: AppBar(
          backgroundColor: AppTheme.navyPrimary,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _buildBackButton(),
        ),
        body: AcademyProfileErrorState(
          message: _initialErrorMessage ??
              'No pudimos obtener la información en este momento.',
          onRetry: () => _loadProfile(isRetry: true),
          isRetrying: _isRetrying,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.navyPrimary,
      body: Stack(
        children: [
          AcademyProfileLayout.constrainContent(
            child: _buildContentBody(_viewData!, heroHeight),
          ),
          if (_isRefreshing)
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              left: 0,
              right: 0,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.brandTeal,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}
