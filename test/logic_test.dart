import 'package:flutter_test/flutter_test.dart';
import 'package:mis_suscripciones/logic.dart';

void main() {
  test('mensual en un mes corto ajusta al último día', () {
    final c = Cargo(id: '1', monto: 1000, frecuencia: Frecuencia.mensual, dia: 31);
    expect(proximoCobro(c, DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
  });

  test('si ya pasó el día del mes, cobra el mes siguiente', () {
    final c = Cargo(id: '1', monto: 1000, frecuencia: Frecuencia.mensual, dia: 5);
    expect(proximoCobro(c, DateTime(2026, 3, 10)), DateTime(2026, 4, 5));
  });

  test('anual cobra el año siguiente si la fecha ya pasó', () {
    final c = Cargo(
        id: '1', monto: 12000, frecuencia: Frecuencia.anual, dia: 1, mes: 3);
    expect(proximoCobro(c, DateTime(2026, 4, 1)), DateTime(2027, 3, 1));
  });

  test('el monto mensual de un cargo anual es monto / 12', () {
    final c = Cargo(id: '1', monto: 12000, frecuencia: Frecuencia.anual, dia: 1);
    expect(c.montoMensual, 1000);
  });

  test('formato de pesos con separador de miles', () {
    expect(formatearPesos(1234567), '\$1.234.567');
    expect(formatearPesos(999), '\$999');
  });

  test('sugiere cancelar lo marcado como casi no usado', () {
    final s = Servicio(
      id: 'a',
      nombre: 'Gym',
      categoria: 'Gimnasio',
      cargos: [
        Cargo(id: '1', monto: 5000, frecuencia: Frecuencia.mensual, dia: 1, casiNoLoUso: true),
      ],
    );
    final sug = generarSugerencias([s], DateTime(2026, 5, 1));
    expect(sug.any((x) => x.cancelar && x.titulo.contains('Gym')), isTrue);
  });
}
