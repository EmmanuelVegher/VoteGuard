import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';
import 'package:voteguard/features/auth/ui/login_screen.dart';
import 'package:voteguard/features/observer/ui/election_gallery_screen.dart';
import 'package:voteguard/features/admin/ui/situation_room_screen.dart';

class DashboardRedirect extends StatelessWidget {
  const DashboardRedirect({super.key});

  static Widget getTargetScreen(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    
    if (authState.status != AuthStatus.authenticated) {
      return const LoginScreen();
    }
    
    final role = authState.role?.toUpperCase();
    const observerRoles = [
      'OBSERVER',
      'ADMIN',
      'SUPER_ADMIN',
      'DIOCESAN_DIRECTOR',
      'DIOCESAN_PROJECT_MANAGER',
      'DIOCESAN_COORDINATOR',
      'PROVINCIAL_DIRECTOR',
      'PROVINCIAL_PROJECT_MANAGER',
      'PROVINCIAL_SECRETARY'
    ];
    
    if (role != null && observerRoles.contains(role)) {
      return const ElectionGalleryScreen();
    }
    
    return const SituationRoomScreen();
  }

  @override
  Widget build(BuildContext context) {
    return getTargetScreen(context);
  }
}
