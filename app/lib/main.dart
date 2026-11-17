import 'package:material_ui/material_ui.dart';

import 'app/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  runApp(const Bootstrap());
}
