import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/User.dart';

class TextBoxBody extends StatelessWidget {
  const TextBoxBody({super.key});

  @override
  Widget build(BuildContext context) {
    MessageBloc _messageBloc = Provider.of<MessageBloc>(context);
    return StreamBuilder<List<Message>>(
        stream: _messageBloc.messages,
        builder: (context, AsyncSnapshot<List<Message>> snapshot) {
          if (snapshot.hasError) {
            return Text("ERR: " + snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasData) {
            return Container(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 209, 209, 209)),
              child: CustomScrollView(
                slivers: [
                  SliverList(
                      delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                    return TextBox(message: snapshot.data![index]);
                  }, childCount: snapshot.data?.length))
                ],
              ),
            );
          }

          return Center(
            child: CircularProgressIndicator(),
          );
        });
  }
}

// Widget TextBox(List<Message> messagesList, int index) {}
// ignore: must_be_immutable
class TextBox extends StatelessWidget {
  final Message message;
  TextBox({super.key, required Message this.message});
  @override
  Widget build(BuildContext context) {
    LoginBloc _userBloc = Provider.of<LoginBloc>(context);

    return StreamBuilder<User>(
        stream: _userBloc.userData,
        builder: (context, AsyncSnapshot<User> snapshot) {
          if (snapshot.hasData) {
            print(snapshot.data);
            //! Add message TIMESTAMP
            bool isOther = snapshot.data?.uid == message.fromId;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: FractionallySizedBox(
                alignment:
                    isOther ? Alignment.centerLeft : Alignment.centerRight,
                widthFactor: 0.8,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                      color: Color.fromARGB(255, 242, 242, 242),
                      borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 16, 8, 16),
                    child: isOther
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      child: ClipRRect(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(
                                                  2.0)), //add border radius here
                                          child: Image(
                                              image: AssetImage(
                                                  'assets/images/avatar.png'))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          8.0, 0, 0, 0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "John Doe", //message.fromId
                                            style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          Text(message.content)
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                Text("10:14")
                              ])
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "John Doe", //message.fromId
                                      style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(message.content)
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 0, 20, 0),
                                    child: Text("10:14"),
                                  ),
                                  Container(
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(
                                                2.0)), //add border radius here
                                        child: Image(
                                            image: AssetImage(
                                                'assets/images/avatar.png'))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          }
          return Text('Loading');
        });
  }
}
