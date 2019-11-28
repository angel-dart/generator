// `dart2native` -o demo example/main.dart
// ./demo

import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:angel_generator/annotations.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:pretty_logging/pretty_logging.dart';
part 'main.g.dart';

main() async {
  Logger.root.onRecord.listen(prettyLog);

  var app = Angel(logger: Logger('angel_generator'));
  var http = AngelHttp(app);

  // Inject the singleton, of course. Otherwise, the server will break,
  // because the container will fall back to attempting reflection.
  app.container.registerSingleton(MyName('Bob Smith'));

  // Since we don't have reflection, call configureServer directly.
  await MyController().configureServer(app);

  // Or, in a group:
  await app.groupAsync('/api/v1', (router) async {
    await MyController().applyRoutes(router, app.container.reflector);
  });

  // Print all routes on fallback.
  app.fallback((req, res) {
    res.contentType = MediaType('text', 'plain');
    app.dumpTree(callback: res.writeln);
  });

  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}');
}

class MyName {
  final String name;

  MyName(this.name);
}

@Expose('/my')
class MyController extends Controller with _AngelMyControllerMixin {
  @Expose('/name')
  String name(@singleton MyName value) => value.name;
}
