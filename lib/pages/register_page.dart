import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/components/button_widget.dart';
import 'package:chat_app/components/textfield_widget.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {  //FOR EMAIL AND PW CONTROLLERS
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confPassController = TextEditingController();

  final void Function()? onTap;
  
  RegisterPage({super.key, this.onTap});

  // REGISTER METHOD
  void register(BuildContext context) async {
    final _authService = AuthService();

    if (_passController.text == _confPassController.text) {
      try {
        _authService.signUpWithEmailPass(
          _emailController.text,
          _passController.text,
        );
      } catch (e) {
        showDialog(context: context, builder: (context) => AlertDialog(
        title: Text(e.toString())
      ));
      }
    } else {
      showDialog(context: context, builder: (context) => AlertDialog(
        title: Text("Passwords do not match!")
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
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

            //pw textfield
            TextfieldWidget(
              hintText: "Password",
              hideText: true,
              controller: _passController,
            ),

            const SizedBox(height: 10),

            //pw textfield
            TextfieldWidget(
              hintText: "Confirm Password",
              hideText: true,
              controller: _confPassController,
            ),

            const SizedBox(height: 25),

            //login button

            ButtonWidget(
              text: "Register",
              onTap: () => register(context),
            ),
            
            const SizedBox(height: 25),

            //register now
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
        )
      )
        
    );
  }
}