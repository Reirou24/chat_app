import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  //INSTANCE OF AUTH
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // CHECK IF USERNAME EXISTS
  Future<bool> isUsernameAvailable(String username) async {
    try {
      // Query the 'Users' collection where username equals the provided username
      QuerySnapshot result = await _firestore
          .collection("Users")
          .where("username", isEqualTo: username)
          .get();

      // If no documents found, username is available (return true)
      return result.docs.isEmpty;
    } catch (e) {
      throw Exception("Error checking username availability");
    }
  }

  // SIGN IN WITH EMAIL OR USERNAME
  Future<UserCredential> signIn(String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername;
      
      // Check if input is a username rather than an email
      if (!emailOrUsername.contains('@')) {
        // Lookup the email associated with this username
        QuerySnapshot userQuery = await _firestore
            .collection("Users")
            .where("username", isEqualTo: emailOrUsername)
            .limit(1)
            .get();
        
        if (userQuery.docs.isEmpty) {
          throw Exception("user-not-found");
        }
        
        // Get the email from the document
        email = userQuery.docs.first.get("email");
      }

      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // SIGN UP WITH EMAIL, PASSWORD AND USERNAME
  Future<UserCredential> signUp(String email, String password, String username) async {
    try {
      // Check if username is available
      bool isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception("username-already-in-use");
      }
      
      // CREATE USER
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // SAVE USER WITH USERNAME
      await _firestore.collection("Users").doc(userCredential.user!.uid).set({
        "uid": userCredential.user!.uid,
        "email": email,
        "username": username,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    return await _auth.signOut();
  }
}