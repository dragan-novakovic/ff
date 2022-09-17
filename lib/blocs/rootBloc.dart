import 'package:ff/blocs/UserBloc.dart';
import 'package:get_it/get_it.dart';

GetIt getIt = GetIt.instance;

void setUpLocators() {
  getIt.registerSingleton<LoginBloc>(LoginBloc());
}
