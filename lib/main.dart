// Full updated code with ONLY the requested features added
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TheGuildApp());
}

class TheGuildApp extends StatelessWidget {
  const TheGuildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Guild',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const SplashScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ========== MODELS ==========

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? profileImage;
  final String? phone;
  final String? location;
  final List<String> skills;
  final String userType;
  final String? bio; // <<<< ADDED bio field
  final Timestamp? createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.profileImage,
    this.phone,
    this.location,
    this.skills = const [],
    required this.userType,
    this.bio, // <<<<
    this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('User data for ${doc.id}: $data');
    return AppUser(
      id: data['id'] ?? doc.id,
      email: data['email'] ?? 'No email',
      name: data['name'] ?? 'User',
      profileImage: data['profileImage'],
      phone: data['phone'],
      location: data['location'],
      skills: List<String>.from(data['skills'] ?? []),
      userType: data['userType'] ?? 'job_seeker',
      bio: data['bio'], // <<<<
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'phone': phone,
      'location': location,
      'skills': skills,
      'userType': userType,
      'bio': bio, // <<<<
      'createdAt': createdAt,
    };
  }
}

// ========== FIXED JOB MODEL - MATCHES YOUR FIRESTORE DATA ==========
class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String description;
  final String jobType;
  final String postedBy;
  final Timestamp createdAt;
  final Map<String, dynamic> salaryRange;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.description,
    required this.jobType,
    required this.postedBy,
    required this.createdAt,
    required this.salaryRange,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Job data for ${doc.id}: $data');
    return Job(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      company: data['company'] ?? 'No Company',
      location: data['location'] ?? 'Remote',
      description: data['description'] ?? 'No description available',
      jobType: data['jobType'] ?? 'Full-Time',
      postedBy: data['postedBy'] ?? 'Unknown',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      salaryRange: data['salaryRange'] ?? {'min': '0', 'max': '0'},
    );
  }

  // Helper method to format salary for display
  String get formattedSalary {
    final min = salaryRange['min'] ?? '0';
    final max = salaryRange['max'] ?? '0';
    return 'R$min - R$max';
  }
}

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userImage;
  final String content;
  final Timestamp timestamp;
  final int likes;
  final List<String> likedBy; // <<<< track who liked
  final List<Comment> comments;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [], // <<<<
    this.comments = const [],
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Post data for ${doc.id}: $data');
    List<Comment> commentsList = [];
    if (data['comments'] != null) {
      try {
        commentsList = List<Map<String, dynamic>>.from(data['comments'] ?? [])
            .map((commentData) => Comment.fromMap(commentData))
            .toList();
      } catch (e) {
        print('Error parsing comments: $e');
      }
    }
    return Post(
      id: doc.id,
      userId: data['userId'] ?? 'unknown',
      userName: data['userName'] ?? 'Unknown User',
      userImage: data['userImage'],
      content: data['content'] ?? 'No content',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likes: (data['likes'] ?? 0).toInt(),
      likedBy: List<String>.from(data['likedBy'] ?? []), // <<<<
      comments: commentsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
      'likedBy': likedBy, // <<<<
      'comments': comments.map((comment) => comment.toMap()).toList(),
    };
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final Timestamp timestamp;
  final int likes;
  final List<String> likedBy; // <<<<
  final List<Reply> replies; // <<<<

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.replies = const [],
  });

  factory Comment.fromMap(Map<String, dynamic> data) {
    List<Reply> repliesList = [];
    if (data['replies'] != null) {
      try {
        repliesList = List<Map<String, dynamic>>.from(data['replies'] ?? [])
            .map((r) => Reply.fromMap(r))
            .toList();
      } catch (e) {
        print('Error parsing replies: $e');
      }
    }
    return Comment(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: data['userId'] ?? 'unknown',
      userName: data['userName'] ?? 'Unknown User',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likes: (data['likes'] ?? 0).toInt(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replies: repliesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
      'likedBy': likedBy,
      'replies': replies.map((r) => r.toMap()).toList(),
    };
  }
}

class Reply {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final Timestamp timestamp;

  Reply({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
  });

  factory Reply.fromMap(Map<String, dynamic> data) {
    return Reply(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: data['userId'] ?? 'unknown',
      userName: data['userName'] ?? 'Unknown User',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
    };
  }
}

// ========== GROUP MODEL ==========
class Group {
  final String id;
  final String name;
  final String description;
  final String category; // 'guild' or 'business'
  final String? logoUrl;
  final Color color;
  final int memberCount;
  final String location;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.logoUrl,
    required this.color,
    required this.memberCount,
    required this.location,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Group data for ${doc.id}: $data');
    return Group(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      description: data['description'] ?? 'No description',
      category: data['category'] ?? 'guild',
      logoUrl: data['logoUrl'],
      color: _stringToColor(data['color'] ?? 'blue'),
      memberCount: (data['memberCount'] ?? 0).toInt(),
      location: data['location'] ?? 'Unknown',
    );
  }

  static Color _stringToColor(String color) {
    switch (color.toLowerCase()) {
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      default: return Colors.blue;
    }
  }
}

// ========== GIG MODEL ==========
class Gig {
  final String id;
  final String title;
  final String description;
  final String providerName;
  final String? providerImage;
  final double price;
  final String category;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final List<String> tags;

  Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.providerName,
    this.providerImage,
    required this.price,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.deliveryTime,
    this.tags = const [],
  });

  factory Gig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Gig data for ${doc.id}: $data');
    return Gig(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? 'No description',
      providerName: data['providerName'] ?? 'Unknown Provider',
      providerImage: data['providerImage'],
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'General',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: (data['reviewCount'] ?? 0).toInt(),
      deliveryTime: data['deliveryTime'] ?? 'Not specified',
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}

// ========== MARKETPLACE ITEM MODEL ==========
class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String sellerName;
  final String? sellerImage;
  final String category;
  final List<String> images;
  final String condition;
  final String location;
  final Timestamp postedDate;

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.sellerName,
    this.sellerImage,
    required this.category,
    required this.images,
    required this.condition,
    required this.location,
    required this.postedDate,
  });

  factory MarketplaceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Marketplace data for ${doc.id}: $data');
    return MarketplaceItem(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? 'No description',
      price: (data['price'] ?? 0.0).toDouble(),
      sellerName: data['sellerName'] ?? 'Unknown Seller',
      sellerImage: data['sellerImage'],
      category: data['category'] ?? 'General',
      images: List<String>.from(data['images'] ?? []),
      condition: data['condition'] ?? 'Unknown',
      location: data['location'] ?? 'Unknown',
      postedDate: data['postedDate'] ?? Timestamp.now(),
    );
  }
}

// ========== CONVERSATION MODEL ==========
class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final String lastMessageSender;
  final bool hasUnread;

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.hasUnread,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    print('Conversation data for ${doc.id}: $data');
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      lastMessageSender: data['lastMessageSender'] ?? '',
      hasUnread: data['hasUnread'] ?? false,
    );
  }
}

// ========== FIREBASE AUTHENTICATION SERVICE ==========
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Sign up with email and password
  Future<String?> signUp(String email, String password, String name, String userType) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'id': result.user!.uid,
        'email': email.trim(),
        'name': name,
        'userType': userType,
        'bio': '', // <<<<
        'createdAt': FieldValue.serverTimestamp(),
        'profileImage': '',
        'phone': '',
        'location': '',
        'skills': [],
      });
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<String?> updateProfile(Map<String, dynamic> updates) async {
    try {
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update(updates);
        return null;
      }
      return 'No user logged in';
    } catch (e) {
      return 'Failed to update profile';
    }
  }

  // Password reset
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Error message helper
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed';
    }
  }
}

// ========== FIRESTORE SERVICE ==========
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Stream<AppUser?> getCurrentUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<AppUser?> getCurrentUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      print('User document $userId does not exist');
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(userId).update(updates);
  }

  // Posts - More flexible parsing
  Stream<List<Post>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Found ${snapshot.docs.length} posts');
      return snapshot.docs.map((doc) {
        try {
          return Post.fromFirestore(doc);
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
          // Return a default post if parsing fails
          return Post(
            id: doc.id,
            userId: 'unknown',
            userName: 'Unknown User',
            content: 'Error loading post',
            timestamp: Timestamp.now(),
            likes: 0,
            likedBy: [],
            comments: [],
          );
        }
      }).toList();
    });
  }

  Future<void> addPost(Post post) async {
    try {
      await _firestore.collection('posts').doc(post.id).set(post.toMap());
    } catch (e) {
      print('Error adding post: $e');
      rethrow;
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return;

      final likedBy = List<String>.from((doc.data() as Map<String, dynamic>)['likedBy'] ?? []);
      if (likedBy.contains(userId)) {
        // Unlike
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        // Like
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      print('Error liking post: $e');
    }
  }

  Future<void> addComment(String postId, Comment comment) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([comment.toMap()]),
      });
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> likeComment(String postId, String commentId, String userId) async {
    try {
      DocumentSnapshot postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      List<dynamic> comments = List<dynamic>.from((postDoc.data() as Map<String, dynamic>)['comments'] ?? []);
      bool found = false;
      for (var i = 0; i < comments.length; i++) {
        Map<String, dynamic> c = comments[i] as Map<String, dynamic>;
        if (c['id'] == commentId) {
          List<String> likedBy = List<String>.from(c['likedBy'] ?? []);
          if (likedBy.contains(userId)) {
            likedBy.remove(userId);
            c['likes'] = (c['likes'] as int) - 1;
          } else {
            likedBy.add(userId);
            c['likes'] = (c['likes'] as int) + 1;
          }
          c['likedBy'] = likedBy;
          comments[i] = c;
          found = true;
          break;
        }
      }
      if (found) {
        await _firestore.collection('posts').doc(postId).update({'comments': comments});
      }
    } catch (e) {
      print('Error liking comment: $e');
    }
  }

  Future<void> replyToComment(String postId, String commentId, Reply reply) async {
    try {
      DocumentSnapshot postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      List<dynamic> comments = List<dynamic>.from((postDoc.data() as Map<String, dynamic>)['comments'] ?? []);
      bool found = false;
      for (var i = 0; i < comments.length; i++) {
        Map<String, dynamic> c = comments[i] as Map<String, dynamic>;
        if (c['id'] == commentId) {
          List<dynamic> replies = List<dynamic>.from(c['replies'] ?? []);
          replies.add(reply.toMap());
          c['replies'] = replies;
          comments[i] = c;
          found = true;
          break;
        }
      }
      if (found) {
        await _firestore.collection('posts').doc(postId).update({'comments': comments});
      }
    } catch (e) {
      print('Error replying to comment: $e');
    }
  }

  // ========== FIXED JOBS STREAM - MATCHES YOUR FIRESTORE DATA ==========
  Stream<List<Job>> getJobs() {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Found ${snapshot.docs.length} jobs');
      return snapshot.docs.map((doc) {
        try {
          return Job.fromFirestore(doc);
        } catch (e) {
          print('Error parsing job ${doc.id}: $e');
          // Return a default job if parsing fails
          return Job(
            id: doc.id,
            title: 'Job Title',
            company: 'Company',
            location: 'Location',
            description: 'Job description',
            jobType: 'Full-Time',
            postedBy: 'Unknown',
            createdAt: Timestamp.now(),
            salaryRange: {'min': '0', 'max': '0'},
          );
        }
      }).toList();
    });
  }

  // Groups
  Stream<List<Group>> getGroups() {
    return _firestore
        .collection('groups')
        .snapshots()
        .map((snapshot) {
      print('Found ${snapshot.docs.length} groups');
      return snapshot.docs.map((doc) {
        try {
          return Group.fromFirestore(doc);
        } catch (e) {
          print('Error parsing group ${doc.id}: $e');
          return Group(
            id: doc.id,
            name: 'Group',
            description: 'Group description',
            category: 'guild',
            color: Colors.blue,
            memberCount: 0,
            location: 'Location',
          );
        }
      }).toList();
    });
  }

  // Gigs
  Stream<List<Gig>> getGigs() {
    return _firestore
        .collection('gigs')
        .snapshots()
        .map((snapshot) {
      print('Found ${snapshot.docs.length} gigs');
      return snapshot.docs.map((doc) {
        try {
          return Gig.fromFirestore(doc);
        } catch (e) {
          print('Error parsing gig ${doc.id}: $e');
          return Gig(
            id: doc.id,
            title: 'Gig Title',
            description: 'Gig description',
            providerName: 'Provider',
            price: 0.0,
            category: 'General',
            rating: 0.0,
            reviewCount: 0,
            deliveryTime: 'Not specified',
            tags: [],
          );
        }
      }).toList();
    });
  }

  // Marketplace Items
  Stream<List<MarketplaceItem>> getMarketplaceItems() {
    return _firestore
        .collection('marketplace')
        .orderBy('postedDate', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Found ${snapshot.docs.length} marketplace items');
      return snapshot.docs.map((doc) {
        try {
          return MarketplaceItem.fromFirestore(doc);
        } catch (e) {
          print('Error parsing marketplace item ${doc.id}: $e');
          return MarketplaceItem(
            id: doc.id,
            title: 'Item',
            description: 'Item description',
            price: 0.0,
            sellerName: 'Seller',
            category: 'General',
            images: [],
            condition: 'Unknown',
            location: 'Unknown',
            postedDate: Timestamp.now(),
          );
        }
      }).toList();
    });
  }

  // Conversations - FIXED: Added error handling for index issues
// In FirestoreService class - Update the getConversations method:
Stream<List<Conversation>> getConversations(String userId) {
  print('FirestoreService: Getting conversations for user: $userId');
  
  return _firestore
      .collection('conversations')
      .where('participants', arrayContains: userId)
      .snapshots()
      .handleError((error) {
        print('FirestoreService: Stream error: $error');
        throw error; // Re-throw to let the UI handle it
      })
      .map((snapshot) {
        print('FirestoreService: Raw snapshot with ${snapshot.docs.length} documents');
        
        final conversations = snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            print('FirestoreService: Processing conversation ${doc.id}: $data');
            return Conversation.fromFirestore(doc);
          } catch (e) {
            print('FirestoreService: Error parsing conversation ${doc.id}: $e');
            // Return a default conversation instead of throwing
            return Conversation(
              id: doc.id,
              participants: [],
              lastMessage: 'Error loading message',
              lastMessageTime: Timestamp.now(),
              lastMessageSender: '',
              hasUnread: false,
            );
          }
        }).toList();
        
        // Sort by lastMessageTime locally
        conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        
        print('FirestoreService: Returning ${conversations.length} conversations');
        return conversations;
      });
}

  Future<void> sendMessage(String conversationId, String message, String senderId) async {
    final messageData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderId': senderId,
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderId,
      'hasUnread': true,
    });
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);
  }

  Future<void> createConversation(List<String> participants) async {
    final conversationId = participants.join('_');
    await _firestore.collection('conversations').doc(conversationId).set({
      'participants': participants,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': '',
      'hasUnread': false,
    });
  }
}

// ========== UPDATED DATA SERVICE ==========
class DataService {
  static final FirebaseAuthService _authService = FirebaseAuthService();
  static final FirestoreService _firestoreService = FirestoreService();

  static Future<AppUser?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await _firestoreService.getCurrentUser(user.uid);
  }

  static Future<String?> signIn(String email, String password) async {
    return await _authService.signIn(email, password);
  }

  static Future<String?> signUp(String email, String password, String name, String userType) async {
    return await _authService.signUp(email, password, name, userType);
  }

  static Future<String?> resetPassword(String email) async {
    return await _authService.resetPassword(email);
  }

  static Future<void> signOut() async {
    await _authService.signOut();
  }

  // Firestore data streams
  static Stream<List<Job>> getJobs() => _firestoreService.getJobs();
  static Stream<List<Post>> getPosts() => _firestoreService.getPosts();
  static Stream<List<Group>> getGroups() => _firestoreService.getGroups();
  static Stream<List<Gig>> getGigs() => _firestoreService.getGigs();
  static Stream<List<MarketplaceItem>> getMarketplaceItems() => _firestoreService.getMarketplaceItems();
  static Stream<List<Conversation>> getConversations(String userId) => _firestoreService.getConversations(userId);

  // Post interactions
  static Future<void> likePost(String postId, String userId) async {
    await _firestoreService.likePost(postId, userId);
  }

  static Future<void> addComment(String postId, Comment comment) async {
    await _firestoreService.addComment(postId, comment);
  }

  static Future<void> likeComment(String postId, String commentId, String userId) async {
    await _firestoreService.likeComment(postId, commentId, userId);
  }

  static Future<void> replyToComment(String postId, String commentId, Reply reply) async {
    await _firestoreService.replyToComment(postId, commentId, reply);
  }

  static Future<void> addPost(Post post) async {
    await _firestoreService.addPost(post);
  }

  // Messaging
  static Future<void> sendMessage(String conversationId, String message, String senderId) async {
    await _firestoreService.sendMessage(conversationId, message, senderId);
  }

  static Future<void> createConversation(List<String> participants) async {
    await _firestoreService.createConversation(participants);
  }

  static Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.updateUserProfile(user.uid, updates);
    }
  }
}

// ========== ENHANCED ANIMATED SPLASH SCREEN ==========
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.3, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    _colorAnimation = ColorTween(
      begin: Colors.blue.shade50,
      end: Colors.white,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0),
    ));
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5),
      ),
    );
    _particleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8),
      ),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () {
      // Check if user is already logged in
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context,
          fadeInRoute(const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          fadeInRoute(const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _colorAnimation.value,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: Stack(
              children: [
                ..._buildParticles(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade400, Colors.blue.shade200],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                                      stops: const [0.5, 1.0],
                                    ).createShader(bounds),
                                    child: const Icon(
                                      Icons.work_history,
                                      color: Colors.white,
                                      size: 70,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(35),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Column(
                          children: [
                            Text(
                              'The Guild',
                              style: GoogleFonts.roboto(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                                  ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'Jobs & Entrepreneurs Community',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final particles = <Widget>[];
    for (int i = 0; i < 8; i++) {
      particles.add(
        Positioned(
          left: (i * 100) % MediaQuery.of(context).size.width,
          top: (i * 80) % MediaQuery.of(context).size.height,
          child: ScaleTransition(
            scale: _particleAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    return particles;
  }
}

PageRouteBuilder<T> fadeInRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 1200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

PageRouteBuilder<T> slideInRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 800),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

// ========== ENHANCED LOGIN SCREEN ==========
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _backgroundColorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.7, curve: Curves.easeOut)),
    );
    _backgroundColorAnimation = ColorTween(
      begin: Colors.blue.shade50,
      end: Colors.white,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0),
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (!_isLogin && _nameController.text.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    String? error;
    if (_isLogin) {
      error = await DataService.signIn(_emailController.text, _passwordController.text);
    } else {
      error = await DataService.signUp(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
        'job_seeker',
      );
    }
    setState(() {
      _isLoading = false;
    });
    if (error == null) {
      // Success - navigate to home screen
      Navigator.pushReplacement(
        context,
        slideInRoute(const HomeScreen()),
      );
    } else {
      _showError(error);
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    String? error = await DataService.resetPassword(_emailController.text);
    setState(() {
      _isLoading = false;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset email sent!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      _showError(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _controller.reset();
      _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundColorAnimation.value,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildAnimatedBackButton(),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                _buildEnhancedLogo(),
                                const SizedBox(height: 24),
                                Text(
                                  _isLogin ? 'Welcome Back!' : 'Join The Guild',
                                  style: GoogleFonts.roboto(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    foreground: Paint()
                                      ..shader = LinearGradient(
                                        colors: [Colors.blue.shade800, Colors.blue.shade600],
                                      ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isLogin
                                      ? 'Sign in to continue your journey'
                                      : 'Create your account to get started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildEnhancedForm(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBackButton() {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
    );
  }

  Widget _buildEnhancedLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400, Colors.blue.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.8)],
                stops: const [0.5, 1.0],
              ).createShader(bounds),
              child: const Icon(
                Icons.work_history,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        children: [
          if (!_isLogin) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: _buildEnhancedTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildEnhancedTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email,
          ),
          const SizedBox(height: 20),
          _buildEnhancedTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock,
            isPassword: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot password?', style: TextStyle(color: Colors.blue)),
            ),
          ),
          const SizedBox(height: 16),
          _buildEnhancedSubmitButton(),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSocialButtons(),
          const SizedBox(height: 28),
          _buildToggleAuthText(),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildEnhancedSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey.shade400, Colors.grey.shade300]
                : [Colors.blue.shade600, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _isLoading ? null : _submitForm,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _isLoading ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLogin ? Icons.login : Icons.person_add,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            text: 'Google',
            color: Colors.red.shade50,
            textColor: Colors.red.shade600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.facebook,
            text: 'Facebook',
            color: Colors.blue.shade50,
            textColor: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleAuthText() {
    return Center(
      child: GestureDetector(
        onTap: _toggleMode,
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
            ),
            children: [
              TextSpan(
                text: _isLogin
                    ? "Don't have an account? "
                    : "Already have an account? ",
              ),
              TextSpan(
                text: _isLogin ? "Sign Up" : "Sign In",
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== ENHANCED HOME SCREEN ==========
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final List<Widget> _screens = [
    const GuildScreen(),
    const JobsScreen(),
    Container(), // Placeholder for FAB
    const InboxScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        fadeInRoute(const CreateOptionsScreen()),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
      _slideController.reset();
      _slideController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _screens[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: _buildEnhancedBottomNav(),
      floatingActionButton: _buildEnhancedFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildEnhancedBottomNav() {
    return Container(
      height: 85 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.home, 'Home'),
                _buildNavItem(1, Icons.work, 'Jobs'),
                const SizedBox(width: 60),
                _buildNavItem(3, Icons.chat, 'Inbox'),
                _buildNavItem(4, Icons.person, 'Profile'),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFAB() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}

// ========== CREATE OPTIONS FULL SCREEN - COMPLETELY REDESIGNED ==========
class CreateOptionsScreen extends StatelessWidget {
  const CreateOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create New',
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like to create?',
              style: GoogleFonts.roboto(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an option to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                children: [
                  _buildCreateOption(
                    icon: Icons.edit,
                    title: 'Post',
                    subtitle: 'Share with community',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        fadeInRoute(EnhancedCreatePostScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCreateOption(
                    icon: Icons.work,
                    title: 'Kazi Gig',
                    subtitle: 'Find local gigs',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        fadeInRoute(KaziGigsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCreateOption(
                    icon: Icons.store,
                    title: 'Marketplace',
                    subtitle: 'Sell items locally',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        fadeInRoute(MarketplaceScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCreateOption(
                    icon: Icons.group_add,
                    title: 'Group',
                    subtitle: 'Create community',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        fadeInRoute(GroupsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Communities',
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Group>>(
          stream: DataService.getGroups(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final groups = snapshot.data ?? [];
            if (groups.isEmpty) {
              return const Center(child: Text('No groups available.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: group.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: group.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(group.logoUrl!, fit: BoxFit.cover),
                              )
                            : Center(
                                child: Text(
                                  group.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: group.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.group, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${group.memberCount} members • ${group.location}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: group.category == 'guild'
                                        ? Colors.blue.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    group.category == 'guild' ? 'Guild' : 'Business',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: group.category == 'guild'
                                          ? Colors.blue.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCommunityScreen()),
          );
        },
        backgroundColor: Colors.blue.shade600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Community',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ========== CREATE COMMUNITY SCREEN ==========
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'guild';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // TODO: Implement your DataService.createGroup method
        // await DataService.createGroup(
        //   name: _nameController.text.trim(),
        //   description: _descriptionController.text.trim(),
        //   category: _selectedCategory,
        // );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Community created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating community: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Community',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Your Community',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect with like-minded people',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Community Name
                Text(
                  'Community Name',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Cape Town Developers',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a community name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Community Description
                Text(
                  'Description',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tell people what your community is about...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.trim().length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Category Selection
                Text(
                  'Category',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'guild';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedCategory == 'guild'
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCategory == 'guild'
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.groups,
                                color: _selectedCategory == 'guild'
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Guild',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedCategory == 'guild'
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'business';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedCategory == 'business'
                                ? Colors.orange.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCategory == 'business'
                                  ? Colors.orange.shade600
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.business,
                                color: _selectedCategory == 'business'
                                    ? Colors.orange.shade600
                                    : Colors.grey.shade600,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Business',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedCategory == 'business'
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createCommunity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Create Community',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== MODIFIED GUILD SCREEN - REMOVED GROUPS ==========
class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() async {
    final user = await DataService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _currentUser?.name ?? 'User';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'The Guild',
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.grey.shade700),
            onPressed: () {
              Navigator.push(
                context,
                fadeInRoute(const EnhancedCreatePostScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$userName!',
                              style: GoogleFonts.roboto(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              _currentUser?.profileImage ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.grey.shade400,
                                    size: 30,
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ready for your next opportunity?',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explore jobs matched to your skills',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Community Posts',
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'See all',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            StreamBuilder<List<Post>>(
              stream: DataService.getPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  print('Error loading posts: ${snapshot.error}');
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading posts: ${snapshot.error}'),
                    ),
                  );
                }
                final posts = snapshot.data ?? [];
                print('Loaded ${posts.length} posts');
                if (posts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No posts yet. Be the first to post!'),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return PostCard(post: posts[index]);
                    },
                    childCount: posts.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// ========== KAZI GIGS SCREEN ==========
class KaziGigsScreen extends StatelessWidget {
  const KaziGigsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Kazi Gigs',
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey.shade700),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Jobs in Your Kazi',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find local opportunities and gigs in your township',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Gig>>(
                stream: DataService.getGigs(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final gigs = snapshot.data!;
                  if (gigs.isEmpty) {
                    return const Center(child: Text('No gigs available.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: gigs.length,
                    itemBuilder: (context, index) {
                      final gig = gigs[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: Image.network(
                                    gig.providerImage ?? 'https://via.placeholder.com/50',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(gig.providerName,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            gig.rating.toString(),
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          Text(' (${gig.reviewCount})',
                                              style: TextStyle(color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'R${gig.price}',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(gig.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 8),
                            Text(gig.description,
                                style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: gig.tags
                                  .map((tag) => Chip(
                                        label: Text(tag),
                                        backgroundColor: Colors.blue.shade50,
                                        labelStyle: TextStyle(color: Colors.blue.shade700),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Delivery: ${gig.deliveryTime}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Order Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== MARKETPLACE SCREEN ==========
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  void _openSellFlow(BuildContext context) {
    // Option 1: Show a bottom sheet (no route needed)
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Start Selling',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'List your item in under 2 minutes and connect with buyers in your community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close bottom sheet
                  // Navigate to your existing Sell screen
                  Navigator.pushNamed(context, '/sell');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Create New Listing', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Browse Items', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          'Marketplace',
          style: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _openSellFlow(context),
            icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<MarketplaceItem>>(
          stream: DataService.getMarketplaceItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Failed to load items\n${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No items for sale yet',
                      style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Be the first to list something amazing!',
                      style: TextStyle(color: Colors.grey, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _MarketplaceItemCard(item: item);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MarketplaceItemCard extends StatelessWidget {
  final MarketplaceItem item;

  const _MarketplaceItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Optional: Navigate to item detail
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FadeInImage(
                  placeholder: const AssetImage('assets/placeholder.png'), // optional
                  image: NetworkImage(
                    item.images.isNotEmpty
                        ? item.images.first.trim()
                        : 'https://via.placeholder.com/400',
                  ),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.location,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.condition,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== ENHANCED POST CARD ==========
class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canMessage = currentUser?.uid != widget.post.userId;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            widget.post.userImage ?? 'https://via.placeholder.com/150',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimeAgo(widget.post.timestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canMessage)
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          onPressed: () async {
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            if (currentUserId != null) {
                              await DataService.createConversation([currentUserId, widget.post.userId]);
                              Navigator.push(
                                context,
                                fadeInRoute(const InboxScreen()),
                              );
                            }
                          },
                        )
                      else
                        Icon(
                          Icons.more_horiz,
                          color: Colors.grey.shade400,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.post.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildReactionButton(
                        icon: widget.post.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        count: widget.post.likes,
                        color: widget.post.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                            ? Colors.red
                            : Colors.grey.shade500,
                        onTap: () {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            DataService.likePost(widget.post.id, user.uid);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildReactionButton(
                        icon: Icons.chat_bubble_outline,
                        count: widget.post.comments.length,
                        onTap: () => _showComments(context),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.share,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(post: widget.post),
    );
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }
}

// ========== ENHANCED CREATE POST SCREEN ==========
class EnhancedCreatePostScreen extends StatefulWidget {
  const EnhancedCreatePostScreen({super.key});

  @override
  State<EnhancedCreatePostScreen> createState() => _EnhancedCreatePostScreenState();
}

class _EnhancedCreatePostScreenState extends State<EnhancedCreatePostScreen>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.7)),
    );
    _controller.forward();
    _loadCurrentUser();
  }

  void _loadCurrentUser() async {
    final user = await DataService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter some content'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final user = _currentUser;
    if (user == null) return;
    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id,
      userName: user.name,
      userImage: user.profileImage,
      content: _contentController.text,
      timestamp: Timestamp.now(),
      likes: 0,
      likedBy: [],
      comments: [],
    );
    await DataService.addPost(newPost);
    _controller.reverse().then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Post published successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _currentUser?.name ?? 'User';
    final userImage = _currentUser?.profileImage ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Publish'),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                userImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Public',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: "What's on your mind? Share your thoughts, opportunities, or questions with the community...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildAddButton(Icons.photo_library, 'Photo'),
                          const SizedBox(width: 16),
                          _buildAddButton(Icons.video_library, 'Video'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.public, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  'Public',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
// ========== REMOTE JOB MODEL FOR REMOTIVE API ==========
class RemoteJob {
  final int id;
  final String title;
  final String company;
  final String location;
  final String jobType;
  final String description;
  final String salary;
  final String url;
  final DateTime publishedAt;

  RemoteJob({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.jobType,
    required this.description,
    required this.salary,
    required this.url,
    required this.publishedAt,
  });

  String get formattedSalary => salary.isNotEmpty ? salary : 'Salary not specified';

  factory RemoteJob.fromJson(Map<String, dynamic> json) {
    return RemoteJob(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'No Title',
      company: json['company_name'] ?? 'Unknown Company',
      location: json['candidate_required_location'] ?? 'Remote',
      jobType: json['job_type'] ?? 'Full-time',
      description: _cleanDescription(json['description'] ?? 'No description available'),
      salary: json['salary'] ?? '',
      url: json['url'] ?? '',
      publishedAt: DateTime.parse(json['publication_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  static String _cleanDescription(String description) {
    String cleanText = description.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    if (cleanText.length > 200) {
      cleanText = cleanText.substring(0, 200) + '...';
    }
    
    return cleanText;
  }
}

// ========== REMOTE JOB SERVICE FOR REMOTIVE API ==========
class RemoteJobService {
  static Future<List<RemoteJob>> getRemoteJobs() async {
    try {
      final response = await http.get(
        Uri.parse('https://remotive.com/api/remote-jobs?limit=50'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> jobsJson = data['jobs'] ?? [];
        
        List<RemoteJob> jobs = jobsJson.map((json) => RemoteJob.fromJson(json)).toList();
        
        jobs = jobs.where((job) => job.url.isNotEmpty).toList();
        
        print('Successfully loaded ${jobs.length} jobs from Remotive API');
        return jobs;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load jobs: ${response.statusCode}');
      }
    } catch (e) {
      print('Network Error: $e');
      throw Exception('Failed to load jobs: $e');
    }
  }
}

// ========== REMOTE JOB CARD FOR REMOTIVE API ==========
class RemoteJobCard extends StatelessWidget {
  final RemoteJob job;
  const RemoteJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    job.company.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getJobTypeColor(job.jobType),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            job.jobType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getJobTypeTextColor(job.jobType),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            job.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                job.formattedSalary,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: job.salary.isNotEmpty ? Colors.black87 : Colors.grey,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _applyForJob(context, job);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getJobTypeColor(String jobType) {
    final type = jobType.toLowerCase();
    if (type.contains('full')) {
      return Colors.green.shade100;
    } else if (type.contains('part')) {
      return Colors.blue.shade100;
    } else if (type.contains('contract')) {
      return Colors.orange.shade100;
    } else if (type.contains('remote')) {
      return Colors.purple.shade100;
    } else {
      return Colors.grey.shade100;
    }
  }

  Color _getJobTypeTextColor(String jobType) {
    final type = jobType.toLowerCase();
    if (type.contains('full')) {
      return Colors.green.shade700;
    } else if (type.contains('part')) {
      return Colors.blue.shade700;
    } else if (type.contains('contract')) {
      return Colors.orange.shade700;
    } else if (type.contains('remote')) {
      return Colors.purple.shade700;
    } else {
      return Colors.grey.shade700;
    }
  }

Future<void> _applyForJob(BuildContext context, RemoteJob job) async {
  try {
    // Clean and validate URL
    String urlString = job.url.trim();
    
    // Ensure URL has a scheme
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    
    print('Attempting to launch URL: $urlString'); // Debug log
    
    final uri = Uri.parse(urlString);
    
    // Launch directly without checking canLaunchUrl
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    
    print('Launch result: $launched'); // Debug log
    
    if (!launched) {
      throw Exception('Failed to launch URL');
    }
  } catch (e) {
    print('URL Launch Error: $e'); // Debug log
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Could not open job application'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Copy URL',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: job.url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('URL copied to clipboard!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }
}

  void _showJobDetails(BuildContext context, RemoteJob job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        job.company.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.company,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Job Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    job.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildDetailItem(Icons.location_on, job.location),
                  const SizedBox(width: 16),
                  _buildDetailItem(Icons.work, job.jobType),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDetailItem(Icons.attach_money, job.formattedSalary),
                  const SizedBox(width: 16),
                  _buildDetailItem(Icons.schedule, 'Posted ${_formatTimeAgo(job.publishedAt)}'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyForJob(context, job);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }
}

// ========== UPDATED JOBS SCREEN WITH REMOTIVE API ==========
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Your Dream Job',
                      style: GoogleFonts.roboto(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Remote opportunities from Remotive API',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            FutureBuilder<List<RemoteJob>>(
              future: RemoteJobService.getRemoteJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  print('Error loading jobs: ${snapshot.error}');
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load jobs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your connection and try again',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const JobsScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final jobs = snapshot.data ?? [];
                print('Loaded ${jobs.length} jobs');
                if (jobs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No jobs available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for new opportunities',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return RemoteJobCard(job: jobs[index]);
                    },
                    childCount: jobs.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ========== REMOTE JOB CARD FOR REMOTIVE API ==========

// ========== FULLY IMPLEMENTED INBOX SCREEN WITH CHAT ==========
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (currentUserId.isEmpty) {
      return _buildNoUserState(context);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: GoogleFonts.roboto(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your conversations',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            StreamBuilder<List<Conversation>>(
              stream: DataService.getConversations(currentUserId),
              builder: (context, snapshot) {
                return _buildConversationsList(context, snapshot, currentUserId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUserState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view messages',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(BuildContext context, AsyncSnapshot<List<Conversation>> snapshot, String currentUserId) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final conversations = snapshot.data ?? [];

    if (conversations.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.chat_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation by messaging someone from their post!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final conv = conversations[index];
          final otherParticipantId = conv.participants
              .firstWhere((id) => id != currentUserId, orElse: () => '');
          
          return FutureBuilder<AppUser?>(
            future: _getUser(otherParticipantId),
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              return _buildConversationItem(
                context: context,
                conversation: conv,
                userName: user?.name ?? 'Unknown User',
                userImage: user?.profileImage,
                otherUserId: otherParticipantId,
              );
            },
          );
        },
        childCount: conversations.length,
      ),
    );
  }

  Widget _buildConversationItem({
    required BuildContext context,
    required Conversation conversation,
    required String userName,
    required String? userImage,
    required String otherUserId,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              otherUserId: otherUserId,
              otherUserName: userName,
              otherUserImage: userImage,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: conversation.hasUnread ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipOval(
                child: userImage != null && userImage.isNotEmpty
                    ? Image.network(
                        userImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar(userName);
                        },
                      )
                    : _buildDefaultAvatar(userName),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage.isNotEmpty 
                        ? conversation.lastMessage 
                        : 'Start a conversation...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: conversation.hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMessageTime(conversation.lastMessageTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                if (conversation.hasUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String userName) {
    return Container(
      color: Colors.blue.shade100,
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Future<AppUser?> _getUser(String userId) async {
    if (userId.isEmpty) return null;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatMessageTime(Timestamp timestamp) {
    try {
      final time = timestamp.toDate();
      final now = DateTime.now();
      
      if (time.day == now.day && time.month == now.month && time.year == now.year) {
        return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        return '${time.month}/${time.day}';
      }
    } catch (e) {
      return '';
    }
  }
}

// ========== CHAT SCREEN FOR MESSAGING ==========
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _markAsRead();
  }

  void _markAsRead() async {
    if (_currentUserId != null) {
      await _firestore.collection('conversations').doc(widget.conversationId).update({
        'hasUnread': false,
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await DataService.sendMessage(widget.conversationId, message, _currentUserId!);
      // Scroll to bottom when new message is sent
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
      // Restore the message if sending failed
      _messageController.text = message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipOval(
                child: widget.otherUserImage != null && widget.otherUserImage!.isNotEmpty
                    ? Image.network(
                        widget.otherUserImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar(widget.otherUserName);
                        },
                      )
                    : _buildDefaultAvatar(widget.otherUserName),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('users').doc(widget.otherUserId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final status = userData?['isOnline'] == true ? 'Online' : 'Offline';
                      return Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      );
                    }
                    return Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send the first message to start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _currentUserId;
                    
                    return _buildMessageBubble(
                      message: message['content'] ?? '',
                      isMe: isMe,
                      timestamp: message['timestamp'] as Timestamp? ?? Timestamp.now(),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMe,
    required Timestamp timestamp,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 50),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue.shade600 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _messageController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _sendMessage,
                        )
                      : null,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_messageController.text.isEmpty)
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String userName) {
    return Container(
      color: Colors.blue.shade100,
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    try {
      final time = timestamp.toDate();
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
// ========== FULLY IMPLEMENTED PROFILE SCREEN ==========
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = await DataService.getCurrentUser();
    if (user != null) {
      _bioController.text = user.bio ?? '';
      _skillsController.text = user.skills.join(', ');
    }
    setState(() {
      _user = user;
    });
  }

  void _toggleEdit() {
    setState(() {
      _editing = !_editing;
    });
  }

  void _saveProfile() async {
    final skills = _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    await DataService.updateUserProfile({
      'bio': _bioController.text.trim(),
      'skills': skills,
    });
    _loadUserData();
    _toggleEdit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    ClipOval(
                      child: user.profileImage != null && user.profileImage!.isNotEmpty
                          ? Image.network(
                              user.profileImage!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color: Colors.white.withOpacity(0.3),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          user.location ?? 'Location not set',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'About',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_editing)
                          TextButton(
                            onPressed: _toggleEdit,
                            child: const Text('Edit', style: TextStyle(color: Colors.blue)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_editing)
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Tell us about yourself...',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      Text(
                        user.bio?.isNotEmpty == true
                            ? user.bio!
                            : 'Passionate developer and entrepreneur building solutions for Africa\'s future.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Skills',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_editing)
                          TextButton(
                            onPressed: _saveProfile,
                            child: const Text('Save', style: TextStyle(color: Colors.green)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_editing)
                      TextField(
                        controller: _skillsController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Flutter, AI, Cloud',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (user.skills.isEmpty
                                ? ['Flutter', 'Dart', 'AI', 'Cloud']
                                : user.skills)
                            .map((skill) => Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    skill,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 32),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            DataService.signOut().then((_) {
                              Navigator.pushReplacement(
                                context,
                                fadeInRoute(const LoginScreen()),
                              );
                            });
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== ENHANCED COMMENTS BOTTOM SHEET WITH REPLY FEATURES ==========
class CommentsBottomSheet extends StatefulWidget {
  final Post post;
  const CommentsBottomSheet({super.key, required this.post});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  AppUser? _currentUser;
  bool _isSubmitting = false;
  String? _replyingToCommentId;
  String? _replyingToUserName;
  Map<String, bool> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
    _loadCurrentUser();
  }

  void _loadCurrentUser() async {
    final user = await DataService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _currentUser == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        content: _commentController.text.trim(),
        timestamp: Timestamp.now(),
        likes: 0,
        likedBy: [],
        replies: [],
      );
      await DataService.addComment(widget.post.id, newComment);
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comment added!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to add comment'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty || _currentUser == null || _replyingToCommentId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final reply = Reply(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        content: _replyController.text.trim(),
        timestamp: Timestamp.now(),
      );
      await DataService.replyToComment(widget.post.id, _replyingToCommentId!, reply);
      _replyController.clear();
      
      // Auto-expand replies after adding a new one
      setState(() {
        _expandedReplies[_replyingToCommentId!] = true;
      });
      
      _replyingToCommentId = null;
      _replyingToUserName = null;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reply added!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      print('Error replying: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to add reply'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _replyController.clear();
    });
  }

  void _toggleReplies(String commentId) {
    setState(() {
      _expandedReplies[commentId] = !(_expandedReplies[commentId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).padding.bottom;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                
                // Comments List
                Expanded(
                  child: StreamBuilder<List<Post>>(
                    stream: DataService.getPosts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final posts = snapshot.data ?? [];
                      final currentPost = posts.firstWhere(
                        (post) => post.id == widget.post.id,
                        orElse: () => widget.post,
                      );
                      final comments = currentPost.comments;
                      
                      if (comments.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Be the first to comment!',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return FadeTransition(
                            opacity: _opacityAnimation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.5, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _controller,
                                curve: Interval(0.1 * index, 1.0, curve: Curves.easeOut),
                              )),
                              child: _buildCommentItem(comment),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Comment/Reply Input Section with proper padding to avoid navigation buttons
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16, 
                    12, 
                    16, 
                    bottomPadding > 0 ? bottomPadding + 12 : safePadding + 16
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingToCommentId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Replying to ${_replyingToUserName ?? 'comment'}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _cancelReply,
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: _replyingToCommentId != null ? _replyController : _commentController,
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: _replyingToCommentId != null ? 'Write a reply...' : 'Add a comment...',
                                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: (_replyingToCommentId != null 
                                    ? _replyController.text.isNotEmpty 
                                    : _commentController.text.isNotEmpty)
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: (_replyingToCommentId != null 
                                    ? _replyController.text.isNotEmpty 
                                    : _commentController.text.isNotEmpty) && !_isSubmitting
                                    ? (_replyingToCommentId != null ? _submitReply : _submitComment)
                                    : null,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final isExpanded = _expandedReplies[comment.id] ?? false;
    final hasReplies = comment.replies.isNotEmpty;
    final replyCount = comment.replies.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Comment
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment Header with User Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        comment.userName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTimeAgo(comment.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Like Button
                    GestureDetector(
                      onTap: () {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          DataService.likeComment(widget.post.id, comment.id, user.uid);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                              ? Colors.blue.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 14,
                              color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                            ),
                            if (comment.likes > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                comment.likes.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Comment Content
                const SizedBox(height: 10),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                
                // Reply Button and Reply Count
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToCommentId = comment.id;
                          _replyingToUserName = comment.userName;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasReplies) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 12,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Replies Section
          if (hasReplies) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show first reply or all replies if expanded
                  if (!isExpanded) ...[
                    _buildReplyItem(comment.replies.first),
                    if (replyCount > 1) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _toggleReplies(comment.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View ${replyCount - 1} more ${replyCount - 1 == 1 ? 'reply' : 'replies'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Show all replies
                    ...comment.replies.map((reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildReplyItem(reply),
                    )),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _toggleReplies(comment.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Show less',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyItem(Reply reply) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  reply.userName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reply.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatTimeAgo(reply.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.content,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    return '${(difference.inDays / 30).floor()}mo ago';
  }
}