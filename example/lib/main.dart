// A small runnable demo of [ThaiAddressPicker]: pick a province → district →
// subdistrict and watch the live [ThaiAddressSelection] (including the
// auto-filled postcode) update beneath the picker.
import 'package:flutter/material.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() => runApp(const ExampleApp());

/// The example application root.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'thai_provinces_flutter example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

/// A screen with a [ThaiAddressPicker] and a live read-out of the selection.
class HomePage extends StatefulWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Own a controller so we can drive it from buttons and clear it.
  final ThaiAddressController _controller = ThaiAddressController();
  ThaiAddressSelection _selection = ThaiAddressSelection.empty;
  ThaiAddressLanguage _language = ThaiAddressLanguage.thai;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thai Address Picker'),
        actions: [
          IconButton(
            tooltip: 'Toggle TH/EN',
            icon: const Icon(Icons.translate),
            onPressed: () => setState(() {
              _language = _language == ThaiAddressLanguage.thai
                  ? ThaiAddressLanguage.english
                  : ThaiAddressLanguage.thai;
            }),
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: _controller.clear,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThaiAddressPicker(
              controller: _controller,
              language: _language,
              onChanged: (sel) => setState(() => _selection = sel),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selection',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Province: ${_selection.province?.nameTh ?? '-'}'),
                    Text('District: ${_selection.district?.nameTh ?? '-'}'),
                    Text(
                        'Subdistrict: ${_selection.subdistrict?.nameTh ?? '-'}'),
                    Text('Postcode: ${_selection.postcode ?? '-'}'),
                    Text('Complete: ${_selection.isComplete}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
