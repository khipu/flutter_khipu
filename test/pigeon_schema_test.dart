import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El esquema de Pigeon es la única fuente de la forma del canal, y hay dos
/// propiedades suyas que ningún test de comportamiento puede defender.
///
/// La primera es la codificación del vacío que fijó el PR #18. Pigeon
/// serializa una lista posicional, no un mapa, así que no hay clave que
/// omitir: el requisito se cumple por construcción en cuanto los tres campos
/// sean nullable. Lo único que podría romperlo es que alguien los vuelva
/// obligatorios en el esquema, y eso es lo que este test mira.
///
/// La segunda es el caso `unknown` de KhipuResultStatus. Quitarlo no rompe
/// ninguna prueba: rompe en producción, el día que el servidor emita un valor
/// nuevo.
void main() {
  final String schema = File('pigeons/khipu_api.dart').readAsStringSync();

  test('los tres campos opcionales de KhipuResult siguen siendo nullable', () {
    for (final String field in <String>[
      'exitUrl',
      'failureReason',
      'continueUrl',
    ]) {
      expect(
        schema,
        contains('String? $field;'),
        reason: 'El PR #18 fijó que los tres opcionales viajan siempre. Con '
            'Pigeon eso se cumple con que sean nullable: $field dejó de serlo.',
      );
    }
  });

  test('KhipuResultStatus conserva el caso unknown', () {
    expect(schema, contains('enum KhipuResultStatus'));
    expect(
      schema,
      contains('unknown,'),
      reason: 'Sin unknown, un valor nuevo del servidor rompe la '
          'decodificación del mensaje entero.',
    );
  });

  test('los cinco valores que el SDK puede emitir están cubiertos', () {
    // Medidos sobre el bytecode de KhipuActivityKt en khipu-client-android
    // 2.28.5: OK, ERROR, WARNING, CONTINUE, USER_CANCELED. `mustContinue`
    // es CONTINUE renombrado, porque `continue` es reservada en los tres
    // lenguajes que Pigeon genera.
    for (final String c in <String>[
      'ok,',
      'error,',
      'warning,',
      'mustContinue,',
      'userCanceled,',
    ]) {
      expect(schema, contains(c));
    }
  });
}
