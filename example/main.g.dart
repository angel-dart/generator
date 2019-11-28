// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// ExposeGenerator
// **************************************************************************

abstract class _AngelMyControllerMixin implements Controller {
  applyRoutes(router, reflector) async {
    var routable = Routable();
    router.mount('/my', routable);
    await configureRoutes(routable);
    routable.addRoute(
        'GET',
        '/name',
        handleContained(
            this.name,
            InjectionRequest.constant(required: [
              ['value', MyName]
            ], named: {}, parameters: {})));
    return 'MyController';
  }

  String name(MyName value);
}
