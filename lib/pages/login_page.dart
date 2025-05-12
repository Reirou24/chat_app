import 'package:chat_app/components/button_widget.dart';
import 'package:chat_app/components/textfield_widget.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  //FOR EMAIL AND PW CONTROLLERS
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  final void Function()? onTap;

  LoginPage({super.key, this.onTap});

  //LOGIN METHOD
  void login() {

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

            const SizedBox(height: 25),

            //login button

            ButtonWidget(
              text: "Login",
              onTap: login,
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