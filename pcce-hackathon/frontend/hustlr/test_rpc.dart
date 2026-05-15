import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/config.dart';

void main() async {
  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseAnonKey);
  
  final db = Supabase.instance.client;
  print("Testing RPC...");
  try {
    final callerId = 'ee7ae6d3-f442-4e93-990c-8b879fa309e1'; // user 1
    final rows = await db.rpc('find_skill_matches', params: {'p_user_id': callerId});
    print("Raw rows:");
    print(rows);
  } catch (e) {
    print("Error: $e");
  }
}
