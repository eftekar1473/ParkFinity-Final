// One-off CLI utility to bootstrap the admin account. Run with `dart run setup_admin.dart`.
// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  
  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );

  print('Signing up admin (with role metadata)...');
  try {
    final res = await supabase.auth.signUp(
      email: 'admin@parkfinity.com',
      password: 'adminpassword123',
      data: {'role': 'Admin', 'full_name': 'Super Admin'},
    );
    print('User signed up: ${res.user?.id}');
    print('Role in metadata: ${res.user?.userMetadata?['role']}');
  } catch (e) {
    print('Error: $e');
  }
}
