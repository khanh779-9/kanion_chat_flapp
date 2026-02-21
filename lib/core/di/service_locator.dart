import 'package:supabase_flutter/supabase_flutter.dart';

// Service Locator đơn giản
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late SupabaseClient supabase;

  void initialize(SupabaseClient client) {
    supabase = client;
  }
}

final sl = ServiceLocator();
