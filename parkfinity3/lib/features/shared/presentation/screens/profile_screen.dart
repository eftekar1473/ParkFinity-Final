import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/data/repositories/storage_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _uploadDocument(String column) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final user = ref.read(authStateChangesProvider).value?.session?.user;
      if (user == null) throw Exception('Not logged in');

      final storageRepo = ref.read(storageRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      // Upload to storage
      final imageUrl = await storageRepo.uploadImage(File(image.path), 'documents', user.id);
      
      // Update database profile
      await authRepo.updateDocumentUrl(column, imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload document: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isUploading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Profile Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.deepPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Ahmed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('ahmed@example.com', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              SizedBox(width: 8),
                              Text('4.8 Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Settings List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 8),
                          child: Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        _buildListTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () {},
                        ),
                        _buildListTile(
                          icon: Icons.directions_car_outlined,
                          title: 'My Vehicles',
                          onTap: () {
                            context.push('/rider/profile/vehicles');
                          },
                        ),
                        _buildListTile(
                          icon: Icons.history,
                          title: 'Booking History',
                          onTap: () {
                            context.push('/rider/profile/history');
                          },
                        ),
                        _buildListTile(
                          icon: Icons.badge_outlined,
                          title: 'Upload NID',
                          onTap: () => _uploadDocument('nid_url'),
                        ),
                        _buildListTile(
                          icon: Icons.card_membership_outlined,
                          title: 'Upload Driving License',
                          onTap: () => _uploadDocument('driving_license_url'),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 8),
                          child: Text('Support & About', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        _buildListTile(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          onTap: () {},
                        ),
                        _buildListTile(
                          icon: Icons.policy_outlined,
                          title: 'Privacy Policy',
                          onTap: () {},
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Log Out Button
                        ListTile(
                          onTap: () {
                            ref.read(authControllerProvider.notifier).signOut();
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.logout, color: Colors.red),
                          ),
                          title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
