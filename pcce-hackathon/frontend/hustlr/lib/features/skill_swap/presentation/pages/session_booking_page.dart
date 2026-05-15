import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';
import 'package:hustlr/features/skill_swap/data/google_calendar_service.dart';

// ─── Embeddable Body for Tabs ────────────────────────────────────────────────

class SkillSwapBookingBody extends StatefulWidget {
  const SkillSwapBookingBody({super.key});
  @override
  State<SkillSwapBookingBody> createState() => _SkillSwapBookingBodyState();
}

class _SkillSwapBookingBodyState extends State<SkillSwapBookingBody> {
  SwapMatch? _selectedMatch;

  @override
  Widget build(BuildContext context) {
    return Consumer<SkillSwapProvider>(
      builder: (context, prov, _) {
        if (prov.activeSwaps.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.calendarX2, size: 48, color: AppColors.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text('No Active Swaps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Connect with a peer in Find Matches to book a session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            ]),
          );
        }

        // Auto-select first match if none selected or if selected is no longer active
        if (_selectedMatch == null || !prov.activeSwaps.any((m) => m.id == _selectedMatch!.id)) {
          _selectedMatch = prov.activeSwaps.first;
        }

        return Column(children: [
          // Match Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1060).withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.05),
              border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
            ),
            child: Row(children: [
              const Text('Booking with: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondaryLight)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SwapMatch>(
                    value: _selectedMatch,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                    items: prov.activeSwaps.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMatch = val);
                    },
                  ),
                ),
              ),
            ]),
          ),
          // Scrollable Form
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BookingFormContent(match: _selectedMatch!, prov: prov),
          )),
        ]);
      },
    );
  }
}

// ─── Standalone Page Wrapper ──────────────────────────────────────────────────

class SessionBookingPage extends StatelessWidget {
  final SwapMatch? match;
  final SkillSwapProvider? prov;
  const SessionBookingPage({super.key, this.match, this.prov});

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book a Session')),
        body: const SkillSwapBookingBody(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: BookingFormContent(match: match!, prov: prov, isStandalone: true),
      ),
    );
  }
}

// ─── Shared Form Content ──────────────────────────────────────────────────────

class BookingFormContent extends StatefulWidget {
  final SwapMatch match;
  final SkillSwapProvider? prov;
  final bool isStandalone;
  const BookingFormContent({super.key, required this.match, this.prov, this.isStandalone = false});

  @override
  State<BookingFormContent> createState() => _BookingFormContentState();
}

class _BookingFormContentState extends State<BookingFormContent> {
  int _selectedDay = 0;
  int _selectedSlot = 0;
  int _duration = 60;
  SessionMode _mode = SessionMode.video;
  bool _booking = false;

  static const _slots = ['10:00 AM', '11:30 AM', '2:00 PM', '4:00 PM', '6:30 PM'];
  static final _now = DateTime.now();
  static final _nextDays = List.generate(7, (i) => _now.add(Duration(days: i + 1)));
  static final _dayLabels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  
  String _dayName(DateTime d) => _dayLabels[d.weekday - 1];
  String _dayNum(DateTime d) => d.day.toString();
  SwapMatch get _match => widget.match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Partner card
      GlassCard(padding: const EdgeInsets.all(16), borderRadius: 14,
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(_match.peer.avatar,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_match.peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Teaching: ${_match.learningSkill}',
              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            Row(children: [
              const Icon(LucideIcons.star, size: 13, color: AppColors.warning),
              const SizedBox(width: 4),
              Text('${_match.peer.rating} · ${_match.peer.sessionsCompleted} sessions',
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ]),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(LucideIcons.arrowLeftRight, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('You teach ${_match.teachingSkill} · You learn ${_match.learningSkill}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
        ])),
      const SizedBox(height: 24),
      // Date picker
      Text('Pick a Date', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      SizedBox(height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _nextDays.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final sel = i == _selectedDay;
            final day = _nextDays[i];
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedDay = i); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), width: 52,
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.primaryGradient : null,
                  color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12)),
                  boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_dayName(day), style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppColors.textSecondaryLight)),
                  Text(_dayNum(day), style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : null)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),
      Text('Available Slots', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10,
        children: List.generate(_slots.length, (i) {
          final sel = i == _selectedSlot;
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedSlot = i); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: sel ? AppColors.tealGradient : null,
                color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12))),
              child: Text(_slots[i], style: TextStyle(fontWeight: FontWeight.w600, color: sel ? Colors.white : null, fontSize: 13)),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      Text('Session Mode', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _modeOption(LucideIcons.video, 'Video Call', 'Jitsi Meet link generated', SessionMode.video, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _modeOption(LucideIcons.messageCircle, 'Chat Only', 'Text-based session', SessionMode.chat, isDark)),
      ]),
      const SizedBox(height: 24),
      Text('Duration', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _durationChip('30 min', 30, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _durationChip('45 min', 45, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _durationChip('60 min', 60, isDark)),
      ]),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: _booking ? null : _confirmBooking,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Center(child: _booking
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Confirm Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        ),
      ),
      const SizedBox(height: 12),
      Center(child: Text('A Meet link will be generated and added to your session log.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight.withValues(alpha: 0.7)))),
      const SizedBox(height: 20),
    ]);
  }

  Widget _modeOption(IconData icon, String label, String sub, SessionMode mode, bool isDark) {
    final sel = _mode == mode;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _mode = mode); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12))),
        child: Column(children: [
          Icon(icon, color: sel ? Colors.white : AppColors.textSecondaryLight, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: sel ? Colors.white : null)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: sel ? Colors.white70 : AppColors.textSecondaryLight)),
        ]),
      ),
    );
  }

  Widget _durationChip(String label, int mins, bool isDark) {
    final sel = _duration == mins;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _duration = mins); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.tealGradient : null,
          color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12))),
        child: Center(child: Text(label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: sel ? Colors.white : null))),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => _booking = true);
    HapticFeedback.mediumImpact();

    final selectedDate = _nextDays[_selectedDay];
    final slotStr = _slots[_selectedSlot];
    final isPM = slotStr.contains('PM');
    final hourPart = int.parse(slotStr.split(':')[0]);
    final minPart  = int.parse(slotStr.split(':')[1].substring(0, 2));
    final hour = hourPart == 12 ? (isPM ? 12 : 0) : hourPart + (isPM ? 12 : 0);
    final sessionStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour, minPart);

    String? meetLink;
    if (_mode == SessionMode.video) {
      meetLink = GoogleCalendarService.instance.generateVideoCallLink();
    }

    await GoogleCalendarService.instance.createEvent(
      title: 'Skill Swap: ${_match.teachingSkill} ↔ ${_match.learningSkill}',
      startTime: sessionStart,
      durationMinutes: _duration,
      description: 'Skill Swap with ${_match.peer.name}.\nYou teach: ${_match.teachingSkill}\nYou learn: ${_match.learningSkill}',
    );

    if (widget.prov != null) {
      try {
        await widget.prov!.bookSession(
          match: _match,
          scheduledAt: sessionStart,
          durationMinutes: _duration,
          mode: _mode,
          topic: '${_match.teachingSkill} & ${_match.learningSkill} Exchange',
          meetLink: meetLink,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _booking = false);
    _showConfirmationDialog(meetLink ?? '');
  }

  void _showConfirmationDialog(String meetLink) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 32)),
          const SizedBox(height: 16),
          const Text('Session Booked! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('${_dayName(_nextDays[_selectedDay])} ${_dayNum(_nextDays[_selectedDay])} at ${_slots[_selectedSlot]}',
            style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          if (_mode == SessionMode.video && meetLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.video, size: 14, color: AppColors.info),
                  SizedBox(width: 6),
                  Text('Meet Link Ready', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(meetLink, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          const Text('Added to Google Calendar & your Session Log.',
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12), textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (widget.isStandalone) {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // standalone page
                } else {
                  Navigator.pop(context); // dialog
                  // Note: Could optionally swap to the sessions tab here if we had tab controller
                }
              },
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            )),
        ],
      ),
    );
  }
}

