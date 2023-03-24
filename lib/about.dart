import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class About extends StatelessWidget {
  const About({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('about'),),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 14,),
              const Text('This app was invented and developed for you', textAlign: TextAlign.center,),
              const SizedBox(height: 12,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('by Volodymyr Prykhozhenko', textAlign: TextAlign.center),
                  const SizedBox(width: 10,),
                  Image.asset('assets/ukraine.png')
                ],
              ),
              const SizedBox(height: 12,),
              Image.asset('assets/v1.jpg', height: 309,),
              const SizedBox(height: 10,),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Send your feedback and suggestions to', textAlign: TextAlign.center),
              ),
              GestureDetector(
                onTap: (){
                  launchUrl(Uri.parse('mailto:vprihogenko@gmail.com'));
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('my email: vprihogenko@gmail.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 14,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Regards and peaceful skies.",
                   style: TextStyle(height: 1.5 ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
