import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/expose_generator.dart';

Builder exposeGenerator(_) {
  return SharedPartBuilder([ExposeGenerator()], 'angel_expose');
}
