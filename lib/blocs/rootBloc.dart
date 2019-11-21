import 'package:ff/blocs/FactoryBloc.dart';
import 'package:ff/blocs/UserBloc.dart';
import 'package:get_it/get_it.dart';

GetIt sl = GetIt.instance;

void setUpLocators() {
  sl.registerSingleton<FactoryBloc>(FactoryBloc());
  sl.registerSingleton<LoginBloc>(LoginBloc());
}
