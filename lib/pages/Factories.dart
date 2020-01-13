import 'package:ff/blocs/FactoryBloc.dart';
import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/components/itemCard.dart';
import 'package:ff/models/Factory.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/ImageSelector.dart';
import 'package:flutter/material.dart';
import 'package:giffy_dialog/giffy_dialog.dart';
import 'package:intl/intl.dart';
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
    // print("UPDATE?");
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
                        return DetailsScreen(
                          body: new BodyDetails(
                            tablet: tablet,
                            index: index,
                            data: snapshot.data,
                            userData: widget.userId,
                          ),
                        );
                      },
                      nullItems: Center(child: CircularProgressIndicator()),
                      emptyItems: Center(child: Text("No Items Found")),
                      slivers: <Widget>[
                        SliverAppBar(
                          title: Text("Your Factories"),
                        ),
                      ],
                      floatingActionButton: FloatingActionButton(
                        child: Icon(Icons.add),
                        tooltip: "Buy new Factory",
                        onPressed: () {
                          showModalBottomSheet(
                              context: context,
                              builder: (BuildContext bc) {
                                List<ListTile> starterFactories = snapshot.data
                                    .where((fact) => fact.level == 1)
                                    .map(
                                      (fact) => ListTile(
                                          leading: ImageSelector.getImage(
                                              fact.name, 1),
                                          title: Text(fact.name),
                                          trailing: RaisedButton(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Text(fact.price.toString()),
                                                ImageSelector.getIcon('gold-s')
                                              ],
                                            ),
                                            onPressed: () {
                                              sl.get<FactoryBloc>().buyFactorie(
                                                    widget.userId,
                                                    fact.id,
                                                  );
                                            },
                                          ),
                                          onTap: () => {}),
                                    )
                                    .toList();

                                return Container(
                                  child: new Wrap(
                                    children: <Widget>[...starterFactories],
                                  ),
                                );
                              });
                        },
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

_listItem(context, snapshot, index, playerFsnapshot, widget) {
  Factory _factory = snapshot.data[index];
  bool hasData = false;
  List<Widget> factories = [];
  PlayerFactory _playerFactory;
  //print(playerFsnapshot.data[0].amount);
  if (playerFsnapshot.data.length != 0) {
    _playerFactory = playerFsnapshot.data
        .firstWhere((pf) => pf.factoryId == _factory.id, orElse: () => null);
    if (_playerFactory != null) {
      hasData = true;

      for (int i = 0; i < _playerFactory.amount; i++) {
        factories.add(
          ListTile(
            leading: ImageSelector.getImage(_factory.name, _factory.level),
            title: Text('${_factory.name}'),
            subtitle: Text('''${_factory.goldPerDay} gold/h'''),
            isThreeLine: false,
            trailing: RaisedButton(
                child: Text("Work"),
                onPressed: () {
                  sl.get<FactoryBloc>().workFactory(widget.userId, _factory.id);
                }),
          ),
        );
      }
    }
  }

  return hasData
      ? Column(
          children: <Widget>[...factories],
        )
      : null;
}

class BodyDetails extends StatelessWidget {
  final bool tablet;
  final int index;
  final List<Factory> data;
  final String userData;
  BodyDetails(
      {Key key, this.tablet, this.index, this.data, @required this.userData})
      : super(key: key);

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
                  padding: const EdgeInsets.all(30.0),
                  child: Container(
                    child: ImageSelector.getImage('any', 1),
                  ),
                ),
                Container(
                  height: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Text(
                            "Name:    ",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text("${data[index].name}")
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Text("Level:",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          if (data[index].level != null)
                            ..._renderLvls(data[index].level)
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Text("Price:    ",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text("${data[index].price} "),
                          ImageSelector.getIcon('gold-s')
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              thickness: 2,
              indent: 20,
              endIndent: 20,
              color: Colors.black26,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50, right: 50, top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  ItemCard(
                    text: "${toBeginningOfSentenceCase(data[index].product)}s",
                    amount: "+${data[index].productAmount}",
                    img: data[index].product,
                  ),
                  ItemCard(
                    text: "Gold",
                    amount: "+${data[index].goldPerDay}/day",
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Container(
                width: 200,
                child: RaisedButton(
                  color: Colors.blue,
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (_) => NetworkGiffyDialog(
                              image: Image.network(
                                "https://techcrunch.com/wp-content/uploads/2015/08/safe_image.gif",
                                fit: BoxFit.cover,
                              ),
                              entryAnimation: EntryAnimation.TOP_LEFT,
                              title: Text(
                                'Upgrading Factory',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.w600),
                              ),
                              description: Text(
                                'Should have mini itemCards with new numbers, or info missing resourses, Picture of next lvl factory',
                                textAlign: TextAlign.center,
                              ),
                              onOkButtonPressed: () async {
                                String response = await sl
                                    .get<FactoryBloc>()
                                    .upgradeFactory(userData, data[index].id);
                                print(response);
                                Navigator.of(context).pop();
                              },
                            ));
                  },
                  child: Text("UPGRADE"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

List<Widget> _renderLvls(int lvl) {
  List<Widget> starList = new List(5);
  starList.fillRange(
      0,
      lvl,
      Icon(
        Icons.star,
        color: Colors.black54,
      ));
  return starList
      .map((item) => item == null ? Icon(Icons.star_border) : item)
      .toList();
}
