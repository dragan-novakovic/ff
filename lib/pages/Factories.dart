import 'package:ff/blocs/FactoryBloc.dart';
import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/Factory.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
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
                        return DetailsScreen(
                          body: new BodyDetails(
                              tablet: tablet,
                              index: index,
                              data: snapshot.data),
                        );
                      },
                      nullItems: Center(child: CircularProgressIndicator()),
                      emptyItems: Center(child: Text("No Items Found")),
                      slivers: <Widget>[
                        SliverAppBar(
                          title: Text("Factories"),
                        ),
                      ],
                      itemCount: snapshot.data.length,
                      itemBuilder: (BuildContext context, int index) {
                        Factory _factory = snapshot.data[index];
                        bool hasData = false;
                        PlayerFactory _playerFactory;
                        print(playerFsnapshot.data[0].amount);
                        if (playerFsnapshot.data.length != 0) {
                          _playerFactory = playerFsnapshot.data.firstWhere(
                              (pf) => pf.factoryId == _factory.id,
                              orElse: () => null);
                          if (_playerFactory != null) {
                            hasData = true;
                          }
                        }

                        return ListTile(
                          leading: Text(
                              'No: ${hasData ? _playerFactory.amount : 0}'),
                          title: Text('${_factory.name}'),
                          subtitle: Text('${_factory.goldPerDay}'),
                          trailing: IconButton(
                            icon: Icon(Icons.add_box),
                            tooltip: 'Increase volume by 10',
                            onPressed: () {
                              sl
                                  .get<FactoryBloc>()
                                  .buyFactorie(widget.userId, _factory.id);
                            },
                          ),
                        );
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
        title: Text("Details"),
        automaticallyImplyLeading: !tablet,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {},
          ),
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
        child: Center(
          child: Text("Item: ${data[index].name}"),
        ),
      ),
    );
  }
}
