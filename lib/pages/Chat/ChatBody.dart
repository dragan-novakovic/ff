import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';

class ChatBody extends StatefulWidget {
  const ChatBody({super.key});

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(
          "BBM STYLE https://www.cnet.com/a/img/resize/a2e77e9c09ad7a1dd9efd6fdce33fedc4bba2bfc/hub/2013/10/29/f0e38d92-6797-11e3-846b-14feb5ca9861/BBM_DRIOD_IOS_CHATS.png?auto=webp&width=768"),
    );
  }
}
