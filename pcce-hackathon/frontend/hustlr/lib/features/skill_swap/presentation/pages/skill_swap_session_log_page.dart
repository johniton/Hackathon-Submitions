import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/app_session.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/session_rating_page.dart';

/// Embeddable body \u2014 reads SkillSwapProvider from its ancestors (no own provider).
/// Use this inside SkillSwapPage tabs.
class SkillSwapSessionLogBody extends StatefulWidget {
  const SkillSwapSessionLogBody({super.key});
  @override
  State<SkillSwapSessionLogBody> createState() => _SkillSwapSessionLogBodyState();
}

class _SkillSwapSessionLogBodyState extends State<SkillSwapSessionLogBody> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer<SkillSwapProvider>(builder: (context, prov, _) {
      final sessions = prov.sessions;
      final displayed = _filter == 'Upcoming'
          ? sessions.where((s) => s.isUpcoming).toList()
          : _filter == 'Past'
              ? sessions.where((s) => s.isPast).toList()
              : sessions;
      return _buildBody(context, prov, displayed);
    });
  }

  Widget _buildBody(BuildContext context, SkillSwapProvider prov, List<SwapSession> displayed) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: ['All', 'Upcoming', 'Past'].map((f) {
          final selected = _filter == f;
          return Padding(padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _filter = f); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.primaryGradient : null,
                  color: selected ? null : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondaryLight)),
              ),
            ));
        }).toList()),
      ),
      if (prov.loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else
        Expanded(child: displayed.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.calendarX2, size: 48, color: AppColors.textSecondaryLight.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(_filter == 'All' ? 'No sessions yet' : 'No $_filter sessions',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Book a session from an active swap.', textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ]))
          : RefreshIndicator(
              onRefresh: prov.refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _SessionCard(session: displayed[i], prov: prov, onRated: () => setState(() {})),
              ))),
    ]);
  }
}

class SkillSwapSessionLogPage extends StatefulWidget {
  const SkillSwapSessionLogPage({super.key});
  @override
  State<SkillSwapSessionLogPage> createState() => _SkillSwapSessionLogPageState();
}

class _SkillSwapSessionLogPageState extends State<SkillSwapSessionLogPage> {
  String _filter = 'All';
  late SkillSwapProvider _prov;
  bool _ownProvider = false;

  @override
  void initState() {
    super.initState();
    // Try to inherit provider from dashboard; if not, create one.
    final existing = context.read<SkillSwapProvider?>();
    if (existing != null) {
      _prov = existing;
    } else {
      _prov = SkillSwapProvider();
      final s = AppSession.instance;
      _prov.init(userId: s.userId ?? '', name: s.userName ?? 'User', avatarInitials: s.avatarInitials ?? 'U');
      _ownProvider = true;
    }
  }

  @override
  void dispose() {
    if (_ownProvider) _prov.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _prov,
      child: Consumer<SkillSwapProvider>(
        builder: (context, prov, _) {

          final sessions = prov.sessions;
          final upcoming = sessions.where((s) => s.isUpcoming).toList();
          final past = sessions.where((s) => s.isPast).toList();
          final needsRating = sessions.where((s) => s.needsRating).toList();
          final displayed = _filter == 'Upcoming' ? upcoming : _filter == 'Past' ? past : sessions;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Session Log'),
              actions: needsRating.isNotEmpty ? [
                Padding(padding: const EdgeInsets.only(right: 12),
                  child: Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4))),
                    child: Text('${needsRating.length} to rate',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                  ))),
              ] : null,
            ),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: ['All', 'Upcoming', 'Past'].map((f) {
                  final selected = _filter == f;
                  return Padding(padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setState(() => _filter = f); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: selected ? AppColors.primaryGradient : null,
                          color: selected ? null : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondaryLight)),
                      ),
                    ));
                }).toList()),
              ),
              if (prov.loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: displayed.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.calendarX2, size: 48, color: AppColors.textSecondaryLight.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('No sessions here yet.', style: TextStyle(color: AppColors.textSecondaryLight)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: prov.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayed.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SessionCard(session: displayed[i], prov: prov, onRated: () => setState(() {})),
                          ),
                        ),
                      ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SwapSession session;
  final VoidCallback onRated;
  final SkillSwapProvider prov;
  const _SessionCard({required this.session, required this.onRated, required this.prov});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUpcoming = session.isUpcoming;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                (isUpcoming ? AppColors.primary : AppColors.textSecondaryLight)
                    .withValues(alpha: 0.12),
            child: Text(session.peer.avatar,
                style: TextStyle(
                    color: isUpcoming
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.peer.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(session.topicCovered,
                  style: const TextStyle(
                      color: AppColors.textSecondaryLight, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          _StatusChip(session: session),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Meta row
        Row(children: [
          _meta(LucideIcons.calendar,
              _formatDate(session.scheduledAt), isDark),
          const SizedBox(width: 16),
          _meta(LucideIcons.clock, '${session.durationMinutes} min', isDark),
          const SizedBox(width: 16),
          _meta(
              session.mode == SessionMode.video
                  ? LucideIcons.video
                  : LucideIcons.messageCircle,
              session.mode == SessionMode.video ? 'Video' : 'Chat',
              isDark),
        ]),

        // Meet link for upcoming sessions
        if (isUpcoming && session.meetLink != null && session.meetLink!.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse(session.meetLink!);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open link: ${session.meetLink}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.video,
                    size: 14, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(session.meetLink!,
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const Icon(LucideIcons.externalLink,
                    size: 12, color: AppColors.info),
              ]),
            ),
          ),
        ],

        // Peer rating display
        if (session.peerRating != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(LucideIcons.star,
                size: 13, color: AppColors.warning),
            const SizedBox(width: 6),
            Text('Peer rated you: ${session.peerRating}/5',
                style: const TextStyle(
                    color: AppColors.textSecondaryLight, fontSize: 12)),
          ]),
        ],

        // Rate button for past sessions
        if (session.needsRating) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SessionRatingPage(session: session)),
              );
              onRated();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.star, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Rate this Session',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
              ),
            ),
          ),
        ],

        // Skip / dispute buttons for upcoming sessions
        if (isUpcoming) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSkipDispute(context, 'skip'),
                icon: const Icon(LucideIcons.skipForward,
                    size: 14,
                    color: AppColors.textSecondaryLight),
                label: const Text('Skip',
                    style: TextStyle(
                        color: AppColors.textSecondaryLight, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.textSecondaryLight.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSkipDispute(context, 'dispute'),
                icon: const Icon(LucideIcons.flag,
                    size: 14, color: AppColors.error),
                label: const Text('Dispute',
                    style:
                        TextStyle(color: AppColors.error, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _meta(IconData icon, String text, bool isDark) {
    return Row(children: [
      Icon(icon, size: 13, color: AppColors.textSecondaryLight),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(
              color: AppColors.textSecondaryLight, fontSize: 11)),
    ]);
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $h:$m $ampm';
  }

  void _showSkipDispute(BuildContext context, String type) {
    // TODO: POST /api/skill-swap/skip or /dispute { sessionId: session.id }
    final isDispute = type == 'dispute';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isDispute ? 'Report Issue' : 'Skip Session?'),
        content: Text(isDispute
            ? 'Report that your partner ${session.peer.name} has been inactive or unresponsive. Our team will review.'
            : 'Are you sure you want to skip this session? This will notify your partner.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isDispute ? AppColors.error : AppColors.warning),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isDispute ? 'Dispute filed.' : 'Session skipped.'),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Text(isDispute ? 'Report' : 'Skip',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final SwapSession session;
  const _StatusChip({required this.session});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = session.isUpcoming;
    final needsRating = session.needsRating;

    if (isUpcoming) {
      return _chip('Upcoming', AppColors.info);
    } else if (needsRating) {
      return _chip('Rate Now', AppColors.warning);
    } else if (session.attendance == AttendanceStatus.attended) {
      return _chip('Done', AppColors.success);
    } else if (session.attendance == AttendanceStatus.missed) {
      return _chip('Missed', AppColors.error);
    }
    return const SizedBox.shrink();
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
