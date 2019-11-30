import 'package:ff/blocs/FactoryBloc.dart';
import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/Factory.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/ImageSelector.dart';
import 'package:flutter/material.dart';
import 'package:giffy_dialog/giffy_dialog.dart';
import 'package:responsive_scaffold/responsive_scaffold.dart';

class FactoriesPage extends StatefulWidget {
  FactoriesPage({@required this.userId});
  final String userId;
  @override
  _FactoriesPageState createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  var _scaffoldKey = new GlobalKey<ScaffoldState>();
  FactoryBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = sl.get<FactoryBloc>();
    bloc.getAll();
    bloc.getUserFactories(widget.userId);
  }

  @override
  void didUpdateWidget(FactoriesPage oldWidget) {
    print("UPDATE?");
    bloc.getUserFactories(widget.userId);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Factory>>(
        stream: bloc.factories,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return StreamBuilder<List<PlayerFactory>>(
                stream: bloc.playerFactories,
                builder: (context, playerFsnapshot) {
                  if (playerFsnapshot.hasData) {
                    return ResponsiveListScaffold.builder(
                      scaffoldKey: _scaffoldKey,
                      detailBuilder:
                          (BuildContext context, int index, bool tablet) {
                        return _factoryDetails(tablet, index, snapshot);
                      },
                      nullItems: Center(child: CircularProgressIndicator()),
                      emptyItems: Center(child: Text("No Items Found")),
                      slivers: <Widget>[
                        SliverAppBar(
                          title: Text("Factories"),
                        ),
                      ],
                      floatingActionButton: FloatingActionButton(
                        child: Icon(Icons.add),
                        tooltip: "Buy new Factory",
                        onPressed: () {},
                      ),
                      itemCount: snapshot.data.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _listItem(
                            context, snapshot, index, playerFsnapshot, widget);
                      },
                    );
                  }
                  return Center(child: CircularProgressIndicator());
                });
          }
          return Center(child: CircularProgressIndicator());
        });
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }
}

_factoryDetails(tablet, index, snapshot) => DetailsScreen(
      body: new BodyDetails(tablet: tablet, index: index, data: snapshot.data),
    );

_listItem(context, snapshot, index, playerFsnapshot, widget) {
  Factory _factory = snapshot.data[index];
  bool hasData = false;
  PlayerFactory _playerFactory;
  print(playerFsnapshot.data[0].amount);
  if (playerFsnapshot.data.length != 0) {
    _playerFactory = playerFsnapshot.data
        .firstWhere((pf) => pf.factoryId == _factory.id, orElse: () => null);
    if (_playerFactory != null) {
      hasData = true;
    }
  }

  return hasData
      ? ListTile(
          leading: ImageSelector.getImage(_factory.name, _factory.level),
          title: Text('${_factory.name}'),
          subtitle: Text('''${_factory.goldPerDay} gold/h
Amount: ${_playerFactory.amount}'''),
          isThreeLine: true,
          trailing: RaisedButton(
              child: Text("Work"),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) => NetworkGiffyDialog(
                          image: Image.network(
                            "https://raw.githubusercontent.com/Shashank02051997/FancyGifDialog-Android/master/GIF's/gif14.gif",
                            fit: BoxFit.cover,
                          ),
                          entryAnimation: EntryAnimation.TOP_LEFT,
                          title: Text(
                            'Granny Eating Chocolate',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22.0, fontWeight: FontWeight.w600),
                          ),
                          description: Text(
                            'This is a granny eating chocolate dialog box. This library helps you easily create fancy giffy dialog.',
                            textAlign: TextAlign.center,
                          ),
                          onOkButtonPressed: () {
                            sl
                                .get<FactoryBloc>()
                                .buyFactorie(widget.userId, _factory.id);
                            Navigator.of(context).pop();
                          },
                        ));
              }),
        )
      : null;
}

class BodyDetails extends StatelessWidget {
  final bool tablet;
  final int index;
  final List<Factory> data;
  BodyDetails({Key key, this.tablet, this.index, this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title: Text("Factory Details"),
        automaticallyImplyLeading: !tablet,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              if (!tablet) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0.0,
        child: Container(
          child: IconButton(
            icon: Icon(Icons.share),
            onPressed: () {},
          ),
        ),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Container(
                    child: ImageSelector.getImage('any', 1),
                  ),
                ),
                Container(
                  height: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Center(
                        child: Text("Name: ${data[index].name}"),
                      ),
                      Center(
                        child: Text("Price: 222 gold"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50, right: 50, top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Text("Weapons"),
                      ImageSelector.getIcon('weapon'),
                      Text("+5")
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      Text("Gold"),
                      ImageSelector.getIcon('gold-l'),
                      Text("+5")
                    ],
                  ),
                ],
              ),
            ),
            RaisedButton(
              onPressed: () {},
              child: Text("UPGRADE"),
            )
          ],
        ),
      ),
    );
  }
}
