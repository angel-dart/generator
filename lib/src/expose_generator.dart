import 'package:analyzer/dart/element/element.dart';
import 'package:angel_framework/angel_framework.dart' hide Parameter;
import 'package:angel_framework/angel_framework.dart' as angel show Parameter;
import 'package:angel_serialize_generator/angel_serialize_generator.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:code_builder/code_builder.dart';
import 'package:source_gen/source_gen.dart';

class ExposeGenerator extends GeneratorForAnnotation<Expose> {
  const ExposeGenerator();

  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw 'The @Expose(...) generator only supports classes.';
    }

    var classElement = element as ClassElement;
    var path = annotation.read('path').stringValue;
    var lib = Library((b) {
      b.body.add(Class((b) {
        b
          ..name = '_Angel' + classElement.name + 'Mixin'
          ..abstract = true
          ..implements.add(refer('Controller'))
          ..methods.add((Method((b) {
            b
              ..name = 'applyRoutes'
              ..modifier = MethodModifier.async
              ..requiredParameters.addAll([
                Parameter((b) => b..name = 'router'),
                Parameter((b) => b..name = 'reflector')
              ])
              ..body = Block((b) {
                // Initialization. Get the path as a constant string,
                // so we can more readably write this:
                var pathAsConstant = literalString(path).accept(DartEmitter());
                b.statements.addAll([
                  Code('var routable = Routable();'),
                  Code('router.mount($pathAsConstant, routable);'),
                ]);

                // Mount the user's routes, if any.
                b.statements.add(Code('await configureRoutes(routable);'));

                // Mount the auto routes.
                // TODO: Get route parameters?
                for (var method in classElement.methods) {
                  var expose =
                      TypeChecker.fromRuntime(Expose).firstAnnotationOf(method);
                  if (expose == null) continue;

                  // Compute an expression like:
                  // routable.addRoute(
                  //    <method>,
                  //    <path>
                  //    handleContained(this.<name>, InjectionRequest(...))
                  // );
                  var rdr = ConstantReader(expose);
                  var args = <Expression>[
                    literalString(rdr.read('method').stringValue),
                    literalString(rdr.read('path').stringValue),
                    refer('handleContained').call([
                      refer('this').property(method.name),
                      generateInjectionRequest(method),
                    ])
                  ];
                  b.statements.add(refer('routable')
                      .property('addRoute')
                      .call(args)
                      .statement);
                }

                // Return the class name
                b.addExpression(literalString(classElement.name).returned);
              });
          })));

        // We also need to have prototypes of all applicable functions.
        for (var method in classElement.methods) {
          var expose =
              TypeChecker.fromRuntime(Expose).firstAnnotationOf(method);
          if (expose == null) continue;
          b.methods.add(Method((b) {
            var requiredParams =
                method.parameters.where((p) => p.isRequiredPositional);
            var optionalParams = method.parameters.where((p) => p.isOptional);

            Parameter _param(ParameterElement p) {
              return Parameter((b) => b
                ..name = p.name
                ..named = p.isNamed
                ..type = convertTypeReference(p.type));
            }

            b
              ..name = method.name
              ..returns = convertTypeReference(method.returnType)
              ..requiredParameters.addAll(requiredParams.map(_param))
              ..optionalParameters.addAll(optionalParams.map(_param));
          }));
        }
      }));
    });

    return lib.accept(DartEmitter()).toString();
  }

  Expression generateInjectionRequest(MethodElement method) {
    var requiredInjections =
        method.parameters.where((p) => p.isRequiredPositional).map((p) {
      return literalList([
        literalString(p.name),
        convertTypeReference(p.type),
      ]);
    });

    var namedInjections = method.parameters.where((p) => p.isNamed).map((p) {
      return MapEntry(p.name, convertTypeReference(p.type));
    });

    var parameterInjections =
        method.parameters.fold<List<MapEntry>>(<MapEntry>[], (out, p) {
      var ann = TypeChecker.fromRuntime(angel.Parameter).firstAnnotationOf(p);
      if (ann == null) {
        return out;
      } else {
        var cr = ConstantReader(ann);

        Expression _get(String name) {
          var rdr = cr.peek(name);
          if (rdr == null) {
            return null;
          } else {
            // Parameters in Expose are always constant, so no need
            // trying to revive RegExp.
            //
            // if (TypeChecker.fromRuntime(RegExp)
            //     .isAssignableFromType(rdr.objectValue.type)) {
            //   return refer('RegExp').newInstance([
            //     literal(rdr.read('pattern').stringValue),
            //   ]);
            // }
            return convertObject(rdr.objectValue);
          }
        }

        var data = {
          'cookie': cr.peek('cookie')?.stringValue,
          'query': cr.peek('query')?.stringValue,
          'header': cr.peek('header')?.stringValue,
          'session': cr.peek('session')?.stringValue,
          'required': cr.peek('required')?.boolValue,
          'match': _get('match'),
          'defaultValue': _get('defaultValue'),
        };

        var obj = refer('Parameter').newInstance(
            [],
            Map.fromEntries(data.entries.where((e) => e.value != null).map((e) {
              var value = e.value;
              if (value is Expression) {
                return MapEntry(e.key, value);
              } else {
                return MapEntry(e.key, literal(value));
              }
            })));
        return out
          ..add(
            MapEntry(
              p.name,
              obj,
            ),
          );
      }
    });

    return refer('InjectionRequest').newInstanceNamed('constant', [], {
      'required': literalList(requiredInjections),
      'named': literalMap(Map.fromEntries(namedInjections)),
      'parameters': literalMap(Map.fromEntries(parameterInjections)),
      // TODO: 'optional': literalList(optionalInjections),
    });
  }
}
