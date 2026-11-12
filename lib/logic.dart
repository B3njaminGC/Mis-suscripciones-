// Lógica pura: fechas, montos y sugerencias. Sin Flutter, así se puede probar con flutter test.

enum Frecuencia { mensual, anual }

const meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String nombreMes(int m) => meses[m - 1];

class Cargo {
  final String id;
  final double monto;
  final Frecuencia frecuencia;
  final int dia; // 1..31
  final int mes; // 1..12, usado solo en anuales
  final DateTime? ultimoUso;
  final bool casiNoLoUso;

  const Cargo({
    required this.id,
    required this.monto,
    required this.frecuencia,
    required this.dia,
    this.mes = 1,
    this.ultimoUso,
    this.casiNoLoUso = false,
  });

  double get montoMensual =>
      frecuencia == Frecuencia.anual ? monto / 12 : monto;

  Map<String, dynamic> toJson() => {
        'id': id,
        'monto': monto,
        'frecuencia': frecuencia.name,
        'dia': dia,
        'mes': mes,
        'ultimoUso': ultimoUso?.toIso8601String(),
        'casiNoLoUso': casiNoLoUso,
      };

  factory Cargo.fromJson(Map<String, dynamic> j) => Cargo(
        id: j['id'] as String,
        monto: (j['monto'] as num).toDouble(),
        frecuencia: Frecuencia.values.byName(j['frecuencia'] as String),
        dia: j['dia'] as int,
        mes: (j['mes'] as int?) ?? 1,
        ultimoUso: j['ultimoUso'] == null
            ? null
            : DateTime.parse(j['ultimoUso'] as String),
        casiNoLoUso: (j['casiNoLoUso'] as bool?) ?? false,
      );
}

class Servicio {
  final String id;
  final String nombre;
  final String categoria;
  final List<Cargo> cargos; // al menos uno

  const Servicio({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.cargos,
  });

  double get montoMensual =>
      cargos.fold<double>(0.0, (a, c) => a + c.montoMensual);

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'cargos': cargos.map((c) => c.toJson()).toList(),
      };

  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        categoria: j['categoria'] as String,
        cargos: (j['cargos'] as List)
            .map((c) => Cargo.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class Sugerencia {
  final String titulo;
  final String detalle;
  final bool cancelar;

  const Sugerencia(this.titulo, this.detalle, {this.cancelar = false});
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

// Día d del mes m del año y, ajustado al último día si el mes es más corto.
DateTime _clampDia(int y, int m, int d) {
  final ultimo = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d > ultimo ? ultimo : d);
}

DateTime proximoCobro(Cargo c, DateTime hoy) {
  final t = soloFecha(hoy);
  if (c.frecuencia == Frecuencia.anual) {
    for (var y = t.year; y <= t.year + 1; y++) {
      final d = _clampDia(y, c.mes, c.dia);
      if (!d.isBefore(t)) return d;
    }
  } else {
    for (var i = 0; i <= 1; i++) {
      final d = _clampDia(t.year, t.month + i, c.dia);
      if (!d.isBefore(t)) return d;
    }
  }
  return t; // no se alcanza, pero Dart exige un retorno
}

int? diasSinUso(Cargo c, DateTime hoy) {
  final u = c.ultimoUso;
  if (u == null) return null;
  return soloFecha(hoy).difference(soloFecha(u)).inDays;
}

// Formato argentino: 1234567 -> $1.234.567
String formatearPesos(double n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final restante = s.length - i;
    buf.write(s[i]);
    if (restante > 1 && restante % 3 == 1) buf.write('.');
  }
  return '\$${buf.toString()}';
}

List<Sugerencia> generarSugerencias(List<Servicio> servicios, DateTime hoy) {
  final out = <Sugerencia>[];
  var ahorro = 0.0;

  for (final s in servicios) {
    final motivos = <String>{};
    for (final c in s.cargos) {
      if (c.casiNoLoUso) motivos.add('Marcaste que casi no lo usás');
      final ds = diasSinUso(c, hoy);
      if (ds != null && ds > 60) motivos.add('no lo usás hace $ds días');
    }
    if (motivos.isNotEmpty) {
      ahorro += s.montoMensual;
      out.add(Sugerencia(
        'Podrías cancelar ${s.nombre}',
        '${formatearPesos(s.montoMensual)} por mes · ${motivos.join('; ')}',
        cancelar: true,
      ));
    }
  }

  final porCategoria = <String, List<String>>{};
  for (final s in servicios) {
    porCategoria.putIfAbsent(s.categoria, () => []).add(s.nombre);
  }
  porCategoria.forEach((cat, nombres) {
    if (cat != 'Otra' && nombres.length > 1) {
      out.add(Sugerencia(
        'Tenés ${nombres.length} en $cat',
        '${nombres.join(', ')}. ¿Las necesitás todas?',
      ));
    }
  });

  final total = servicios.fold<double>(0.0, (a, s) => a + s.montoMensual);
  if (servicios.length >= 2 && total > 0) {
    final top = servicios.reduce(
        (a, b) => b.montoMensual > a.montoMensual ? b : a);
    final pct = (top.montoMensual / total * 100).round();
    if (pct >= 30) {
      out.add(Sugerencia(
        '${top.nombre} pesa el $pct% de tu gasto',
        'Revisarla primero tiene el mayor impacto.',
      ));
    }
  }

  if (ahorro > 0) {
    out.add(Sugerencia(
      'Ahorro posible: ${formatearPesos(ahorro)} por mes',
      'Son ${formatearPesos(ahorro * 12)} al año si cancelás las sugeridas.',
    ));
  }
  return out;
}
