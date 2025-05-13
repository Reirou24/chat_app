import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/components/button_widget.dart';
import 'package:chat_app/components/textfield_widget.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  //FOR EMAIL/USERNAME AND PW CONTROLLERS
  final TextEditingController _emailUsernameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  final void Function()? onTap;

  LoginPage({super.key, this.onTap});

  //LOGIN METHOD
  void login(BuildContext context) async {
    //get auth service
    final authService = AuthService();

    try {
      await authService.signIn(
        _emailUsernameController.text,
        _passController.text,
      );
    }
    catch (e) {
      showDialog(context: context, builder: (context) => AlertDialog(
        title: Text(e.toString())
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
              "Welcome back! You've been missed.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              )
            ),

            const SizedBox(height: 25),

            //email/username textfield
            TextfieldWidget(
              hintText: "Email or Username",
              hideText: false,
              controller: _emailUsernameController,
            ),

            const SizedBox(height: 10),

            //pw textfield
            TextfieldWidget(
              hintText: "Password",
              hideText: true,
              controller: _passController,
            ),

            const SizedBox(height: 25),

            //login button
            ButtonWidget(
              text: "Login",
              onTap: () => login(context),
            ),
            
            const SizedBox(height: 25),

            //register now
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Not a member? ",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    "Register now!",
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