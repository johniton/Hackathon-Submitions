import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://mbuavrnqifoqtmywmteu.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1idWF2cm5xaWZvcXRteXdtdGV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3Mzg0MDAsImV4cCI6MjA5NDMxNDQwMH0._Y4uDlyCMhqYOeGdNlU11HGqFHRr5HfaQgBiZRfogCk';
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  print("Testing RPC...");
  try {
    final callerId = 'ee7ae6d3-f442-4e93-990c-8b879fa309e1'; // user 1
    final response = await client.rpc('find_skill_matches', params: {'p_user_id': callerId});
    print("Raw rows for $callerId:");
    print(response);
    
    final callerId2 = '5b56558b-b885-413f-8e43-1ec5a34dc4e2'; // user 2
    final response2 = await client.rpc('find_skill_matches', params: {'p_user_id': callerId2});
    print("Raw rows for $callerId2:");
    print(response2);
  } catch (e) {
    print("Error: $e");
  }
}
