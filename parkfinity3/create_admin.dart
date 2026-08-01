import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient('https://rkqduzjkkyplceipydir.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrcWR1empra3lwbGNlaXB5ZGlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MDU0ODUsImV4cCI6MjEwMTA4MTQ4NX0.9w6oWvbwhjLteKkgGgDg7v79HGsAQ5ZI_QsV-G1izF0');
  
  try {
    print('Trying to sign in...');
    var res = await supabase.auth.signInWithPassword(
      email: 'superadmin@parkfinity.com',
      password: 'adminpassword123',
    );
    
    final userId = res.user?.id;
    if (userId == null) {
        print("Failed to get user ID");
        exit(1);
    }
    print('User signed in: $userId');
    
    print('Updating profile role to Admin...');
    await supabase
      .from('profiles')
      .update({'role': 'Admin'})
      .eq('id', userId);
      
    print('Profile updated to Admin successfully!');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
