import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/components/button_widget.dart';
import 'package:chat_app/components/textfield_widget.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  // CONTROLLERS
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confPassController = TextEditingController();

  final void Function()? onTap;
  
  RegisterPage({super.key, this.onTap});

  // REGISTER METHOD
  void register(BuildContext context) async {
    final _authService = AuthService();

    // Check if passwords match
    if (_passController.text != _confPassController.text) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Passwords do not match!")
        )
      );
      return;
    }

    // Check if username is empty
    if (_usernameController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Username cannot be empty")
        )
      );
      return;
    }

    try {
      // Check if username is available
      bool isAvailable = await _authService.isUsernameAvailable(_usernameController.text);
      
      if (!isAvailable) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Username is already taken")
          )
        );
        return;
      }
      
      // Create user with email, password and username
      await _authService.signUp(
        _emailController.text,
        _passController.text,
        _usernameController.text,
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(e.toString())
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //logo
              Icon(
                Icons.message,
                size: 60,
                color: Theme.of(context).colorScheme.primary
              ),

              const SizedBox(height: 50),

              //welcome back message
              Text(
                "Let's create an account for you.",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                )
              ),

              const SizedBox(height: 25),

              //email textfield
              TextfieldWidget(
                hintText: "Email",
                hideText: false,
                controller: _emailController,
              ),

              const SizedBox(height: 10),
              
              //username textfield
              TextfieldWidget(
                hintText: "Username",
                hideText: false,
                controller: _usernameController,
              ),

              const SizedBox(height: 10),

              //pw textfield
              TextfieldWidget(
                hintText: "Password",
                hideText: true,
                controller: _passController,
              ),

              const SizedBox(height: 10),

              //confirm pw textfield
              TextfieldWidget(
                hintText: "Confirm Password",
                hideText: true,
                controller: _confPassController,
              ),

              const SizedBox(height: 25),

              //register button
              ButtonWidget(
                text: "Register",
                onTap: () => register(context),
              ),
              
              const SizedBox(height: 25),

              //login now
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      "Login now!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary
                      ),
                    ),
                  ),
                ],
              ),
            ]
          ),
        )
      )
    );
  }
}