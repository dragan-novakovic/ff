// import 'package:ff/components/itemCard.dart';
// import 'package:flutter/material.dart';

// import 'package:responsive_scaffold/responsive_scaffold.dart';

// class MissionsPage extends StatefulWidget {
//   @override
//   _MissionsState createState() => _MissionsState();
// }

// class _MissionsState extends State<MissionsPage> {
//   var _scaffoldKey = new GlobalKey<ScaffoldState>();

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: ResponsiveListScaffold.builder(
//         scaffoldKey: _scaffoldKey,
//         detailBuilder: (BuildContext context, int index, bool tablet) {
//           return _detailScreen(tablet, context, index);
//         },
//         nullItems: Center(child: CircularProgressIndicator()),
//         emptyItems: Center(child: Text("No Items Found")),
//         slivers: <Widget>[
//           SliverAppBar(
//             title: Text("Missions"),
//           ),
//         ],
//         itemCount: 3,
//         itemBuilder: (BuildContext context, int index) {
//           return index == 0
//               ? MissionItem()
//               : ListTile(
//                   leading: Icon(Icons.check_circle),
//                   title: Text("Campign $index"),
//                   subtitle: Text("Reqirments:\n 10x Weapons 10 Food 10 Energy"),
//                   isThreeLine: true,
//                   trailing: ElevatedButton(
//                     onPressed: () {},
//                     child: Text("Battle"),
//                   ),
//                 );
//         },
//         bottomNavigationBar: BottomAppBar(
//           elevation: 0.0,
//           child: Container(
//             child: IconButton(
//               icon: Icon(Icons.share),
//               onPressed: () {},
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// _detailScreen(tablet, context, index) => DetailsScreen(
//       // appBar: AppBar(
//       //   elevation: 0.0,
//       //   title: Text("Details"),
//       //   actions: [
//       //     IconButton(
//       //       icon: Icon(Icons.share),
//       //       onPressed: () {},
//       //     ),
//       //     IconButton(
//       //       icon: Icon(Icons.delete),
//       //       onPressed: () {
//       //         if (!tablet) Navigator.of(context).pop();
//       //       },
//       //     ),
//       //   ],
//       // ),
//       body: Scaffold(
//         appBar: AppBar(
//           elevation: 0.0,
//           title: Text("Details"),
//           automaticallyImplyLeading: !tablet,
//           actions: [
//             IconButton(
//               icon: Icon(Icons.share),
//               onPressed: () {},
//             ),
//             IconButton(
//               icon: Icon(Icons.delete),
//               onPressed: () {
//                 if (!tablet) Navigator.of(context).pop();
//               },
//             ),
//           ],
//         ),
//         bottomNavigationBar: BottomAppBar(
//           elevation: 0.0,
//           child: Container(
//             child: IconButton(
//               icon: Icon(Icons.close),
//               onPressed: () {},
//             ),
//           ),
//         ),
//         body: Container(
//           child: Center(
//             child: Text("Item: $index"),
//           ),
//         ),
//       ),
//     );

// class MissionItem extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return (Container(
//       height: 120,
//       margin: EdgeInsets.only(left: 8, right: 8, top: 10),
//       decoration:
//           BoxDecoration(border: Border.all(width: 1, color: Colors.black54)),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: <Widget>[
//           Column(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: <Widget>[
//               Text(
//                 "Campign 1",
//                 style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 1),
//               ),
//               Row(
//                 children: <Widget>[
//                   Text("Requirments:    "),
//                   ItemCard(
//                     height: 40,
//                     mini: true,
//                     amount: "50",
//                     img: "food",
//                   ),
//                   ItemCard(
//                     height: 40,
//                     mini: true,
//                     amount: "50",
//                     img: "weapon",
//                   ),
//                   ItemCard(
//                     height: 40,
//                     mini: true,
//                     amount: "50",
//                     img: "exp",
//                   ),
//                   ItemCard(
//                     height: 40,
//                     mini: true,
//                     amount: "50",
//                     img: "energy",
//                   )
//                 ],
//               )
//             ],
//           ),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: <Widget>[
//               Container(
//                 width: 80,
//                 height: 50,
//                 margin: EdgeInsets.only(right: 10),
//                 child: ElevatedButton(
//                   onPressed: () {},
//                   child: Text("Battle"),
//                 ),
//               ),
//             ],
//           )
//         ],
//       ),
//     ));
//   }
// }
