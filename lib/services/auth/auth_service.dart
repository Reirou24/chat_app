import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  //INSTANCE OF AUTH
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  //SIGN IN
  Future<UserCredential> signInWithEmailPass(String email, String password) async {
    try {
      UserCredential userCredential = 
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

      DocumentSnapshot userDoc =
        await _firestore.collection("Users").doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        await _firestore.collection("Users").doc(userCredential.user!.uid).set(
          {
            "uid": userCredential.user!.uid,
            "email": email,
          }
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  //SIGN UP
  Future<UserCredential> signUpWithEmailPass(String email, String password) async {
    try {
      //CREATE USER
      UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: email, 
          password: password
        );
 
      //SAVE USER
      await _firestore.collection("Users").doc(userCredential.user!.uid).set(
        {
          "uid": userCredential.user!.uid,
          "email": email,
        }
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  //SIGN OUT
  Future<void> signOut() async {
    return await _auth.signOut();
  }
}