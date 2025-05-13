import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  //INSTANCE OF AUTH
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //SIGN IN
  Future<UserCredential> signInWithEmailPass(String email, String password) async {
    try {
      UserCredential userCredential = 
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  //SIGN UP
  Future<UserCredential> signUpWithEmailPass(String email, String password) async {
    try {
      UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: email, 
          password: password
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