import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:hustlr/config.dart';

Future<void> main() async {
  // Initialize Supabase with placeholders, just to access client
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  final _db = Supabase.instance.client;

  try {
    final userId = '5b56558b-b885-413f-8e43-1ec5a34dc4e2'; // Assuming this user from previous context

    final asInitiator = await _db
        .from('swap_matches')
        .select('''
          id, teaching_skill, learning_skill, match_score, status, created_at,
          peer:skill_swap_users!swap_matches_peer_id_fkey(
            user_id, name, avatar_initials, city,
            skills_to_offer, skills_wanted, rating, sessions_completed
          )
        ''')
        .eq('user_id', userId)
        .eq('status', 'active');
        
    print('As initiator:');
    print(jsonEncode(asInitiator));

    final asReceiver = await _db
        .from('swap_matches')
        .select('''
          id, teaching_skill, learning_skill, match_score, status, created_at,
          peer:skill_swap_users!swap_matches_user_id_fkey(
            user_id, name, avatar_initials, city,
            skills_to_offer, skills_wanted, rating, sessions_completed
          )
        ''')
        .eq('peer_id', userId)
        .eq('status', 'active');
        
    print('As receiver:');
    print(jsonEncode(asReceiver));
    
  } catch (e) {
    print('Error: \$e');
  }
}
