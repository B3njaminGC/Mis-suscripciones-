import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';

void main() => runApp(const MisSuscripcionesApp());

class MisSuscripcionesApp extends StatelessWidget {
  const MisSuscripcionesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mis suscripciones',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4F4FD1),
          useMaterial3: true,
        ),
        home: const InicioPage(),
      );
}

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  static const _clave = 'servicios-v1';
  List<Servicio> _servicios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clave);
    final lista = raw == null
        ? <Servicio>[]
        : (jsonDecode(raw) as List)
            .map((e) => Servicio.fromJson(e as Map<String, dynamic>))
            .toList();
    if (!mounted) return;
    setState(() {
      _servicios = lista;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _clave, jsonEncode(_servicios.map((s) => s.toJson()).toList()));
  }

  Future<void> _nuevoOEditar([Servicio? existente]) async {
    final resultado = await Navigator.push<Servicio>(
      context,
      MaterialPageRoute(builder: (_) => FormServicioPage(inicial: existente)),
    );
    if (resultado == null) return;
    setState(() {
      _servicios = existente == null
          ? [..._servicios, resultado]
          : _servicios
              .map((s) => s.id == existente.id ? resultado : s)
              .toList();
    });
    await _guardar();
  }

  Future<void> _eliminar(Servicio s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar ${s.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _servicios = _servicios.where((x) => x.id != s.id).toList());
    await _guardar();
  }

  DateTime _proxServicio(Servicio s, DateTime hoy) => s.cargos
      .map((c) => proximoCobro(c, hoy))
      .reduce((a, b) => a.isBefore(b) ? a : b);

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final hoySolo = soloFecha(hoy);
    final ordenados = [..._servicios]
      ..sort((a, b) => _proxServicio(a, hoy).compareTo(_proxServicio(b, hoy)));
    final total = _servicios.fold<double>(0.0, (a, s) => a + s.montoMensual);
    final semana = _servicios.fold<double>(
      0.0,
      (a, s) =>
          a +
          s.cargos
              .where((c) => proximoCobro(c, hoy).difference(hoySolo).inDays <= 7)
              .fold<double>(0.0, (x, c) => x + c.monto),
    );
    final sugs = generarSugerencias(_servicios, hoy);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis suscripciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevoOEditar(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Row(children: [
                  Expanded(child: _Stat('Gasto mensual', formatearPesos(total))),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('Anual estimado', formatearPesos(total * 12))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _Stat('Próximos 7 días', formatearPesos(semana))),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('Servicios', '${_servicios.length}')),
                ]),
                _titulo('Próximos cobros'),
                if (ordenados.isEmpty)
                  const _Vacio()
                else
                  ...ordenados.map((s) => _tarjetaServicio(s, hoy)),
                _titulo('Sugerencias'),
                if (sugs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Sin sugerencias por ahora.'),
                  )
                else
                  ...sugs.map(_tarjetaSug),
              ],
            ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _tarjetaServicio(Servicio s, DateTime hoy) {
    final prox = _proxServicio(s, hoy);
    final dias = prox.difference(soloFecha(hoy)).inDays;
    final txt = dias == 0 ? 'Hoy' : dias == 1 ? 'Mañana' : 'en $dias días';
    return Card(
      child: ListTile(
        title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.categoria} · $txt'),
        trailing: Text(formatearPesos(s.montoMensual),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => _nuevoOEditar(s),
        onLongPress: () => _eliminar(s),
      ),
    );
  }

  Widget _tarjetaSug(Sugerencia s) => Card(
        color: s.cancelar ? Theme.of(context).colorScheme.errorContainer : null,
        child: ListTile(
          leading: Icon(s.cancelar ? Icons.cancel_outlined : Icons.lightbulb_outline),
          title: Text(s.titulo),
          subtitle: Text(s.detalle),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _Stat(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(valor, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no cargaste suscripciones. Tocá "Agregar" para empezar.',
          textAlign: TextAlign.center,
        ),
      );
}

class FormServicioPage extends StatefulWidget {
  final Servicio? inicial;
  const FormServicioPage({super.key, this.inicial});

  @override
  State<FormServicioPage> createState() => _FormServicioPageState();
}

class _FormServicioPageState extends State<FormServicioPage> {
  static const categorias = [
    'Streaming', 'Música', 'Software', 'Almacenamiento',
    'Gimnasio', 'Celular e internet', 'Otra',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late String _categoria;
  late List<Cargo> _cargos;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nombre = TextEditingController(text: i?.nombre ?? '');
    _categoria = i?.categoria ?? categorias.first;
    _cargos = List.of(i?.cargos ?? <Cargo>[]);
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _editarCargo([Cargo? existente]) async {
    final c = await showDialog<Cargo>(
      context: context,
      builder: (_) => _CargoDialog(inicial: existente),
    );
    if (c == null) return;
    setState(() {
      _cargos = existente == null
          ? [..._cargos, c]
          : _cargos.map((x) => x.id == existente.id ? c : x).toList();
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_cargos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agregá al menos un cargo')));
      return;
    }
    Navigator.pop(
      context,
      Servicio(
        id: widget.inicial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: _nombre.text.trim(),
        categoria: _categoria,
        cargos: _cargos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inicial == null ? 'Nueva suscripción' : 'Editar'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Poné un nombre' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in categorias)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _categoria = v ?? _categoria),
            ),
            const SizedBox(height: 20),
            Text('Cargos', style: Theme.of(context).textTheme.titleMedium),
            for (final c in _cargos)
              Card(
                child: ListTile(
                  title: Text(formatearPesos(c.monto) +
                      (c.frecuencia == Frecuencia.anual ? ' por año' : ' por mes')),
                  subtitle: Text('Día ${c.dia}' +
                      (c.frecuencia == Frecuencia.anual
                          ? ' de ${nombreMes(c.mes)}'
                          : '')),
                  onTap: () => _editarCargo(c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(
                        () => _cargos = _cargos.where((x) => x.id != c.id).toList()),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _editarCargo(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar cargo'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}

class _CargoDialog extends StatefulWidget {
  final Cargo? inicial;
  const _CargoDialog({this.inicial});

  @override
  State<_CargoDialog> createState() => _CargoDialogState();
}

class _CargoDialogState extends State<_CargoDialog> {
  late final TextEditingController _monto;
  late final TextEditingController _dia;
  late Frecuencia _frec;
  late int _mes;
  late bool _casi;
  late DateTime? _ultimo;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _monto = TextEditingController(text: i == null ? '' : i.monto.toStringAsFixed(0));
    _dia = TextEditingController(text: i == null ? '' : '${i.dia}');
    _frec = i?.frecuencia ?? Frecuencia.mensual;
    _mes = i?.mes ?? DateTime.now().month;
    _casi = i?.casiNoLoUso ?? false;
    _ultimo = i?.ultimoUso;
  }

  @override
  void dispose() {
    _monto.dispose();
    _dia.dispose();
    super.dispose();
  }

  void _aceptar() {
    final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
    final dia = int.tryParse(_dia.text);
    if (monto == null || monto < 0 || dia == null || dia < 1 || dia > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisá el monto y el día (1 a 31)')));
      return;
    }
    Navigator.pop(
      context,
      Cargo(
        id: widget.inicial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        monto: monto,
        frecuencia: _frec,
        dia: dia,
        mes: _mes,
        ultimoUso: _ultimo,
        casiNoLoUso: _casi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cargo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _monto,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto en pesos'),
            ),
            TextField(
              controller: _dia,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Día de cobro (1 a 31)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Frecuencia>(
              value: _frec,
              decoration: const InputDecoration(labelText: 'Periodicidad'),
              items: const [
                DropdownMenuItem(value: Frecuencia.mensual, child: Text('Mensual')),
                DropdownMenuItem(value: Frecuencia.anual, child: Text('Anual')),
              ],
              onChanged: (v) => setState(() => _frec = v ?? _frec),
            ),
            if (_frec == Frecuencia.anual) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _mes,
                decoration: const InputDecoration(labelText: 'Mes de cobro'),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text(nombreMes(m))),
                ],
                onChanged: (v) => setState(() => _mes = v ?? _mes),
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_ultimo == null
                  ? 'Última vez que lo usaste: sin dato'
                  : 'Última vez: ${_ultimo!.day}/${_ultimo!.month}/${_ultimo!.year}'),
              trailing: TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _ultimo ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _ultimo = d);
                },
                child: const Text('Elegir'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Casi no lo uso'),
              value: _casi,
              onChanged: (v) => setState(() => _casi = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Aceptar')),
      ],
    );
  }
}
