import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convert Firestore document to AppUser
  AppUser _documentToUser(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: data['id'] ?? doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      profileImage: data['profileImage'],
      phone: data['phone'],
      location: data['location'],
      skills: List<String>.from(data['skills'] ?? []),
      userType: data['userType'] ?? 'job_seeker',
      bio: data['bio'] ?? '', // Added bio field
    );
  }

  // Get current user data
  Future<AppUser?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return _documentToUser(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Stream for current user data
  Stream<AppUser?> get currentUserStream {
    return FirebaseAuth.instance.authStateChanges().asyncMap((user) {
      if (user == null) return null;
      return getCurrentUser();
    });
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(userId).update(updates);
  }

  // Search users
  Stream<List<AppUser>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_documentToUser).toList());
  }
}