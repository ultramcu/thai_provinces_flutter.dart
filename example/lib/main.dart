// A polished gallery for the `thai_provinces_flutter` package.
//
// Every demo on every tab is wired to ONE shared [ThaiAddressController]. A
// persistent "Current selection" panel reads that single controller, so
// picking a province in the cascading picker, typing in the autocomplete
// field, or entering a postcode all drive — and reflect in — the same state.
// This proves the widgets interoperate with zero state-management lock-in.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';
// Use `show` so the re-exported Province/District/Subdistrict symbols don't
// clash with the ones thai_provinces_flutter already re-exports.
import 'package:thai_provinces_geo/thai_provinces_geo.dart' show reverseGeocode;

void main() => runApp(const ExampleApp());

/// Root of the gallery application.
class ExampleApp extends StatefulWidget {
  /// Creates the example gallery app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // The ONE shared controller every demo binds to. Owned here at the top so it
  // outlives tab switches and stays the single source of truth.
  final ThaiAddressController _controller = ThaiAddressController();

  // A Thai → English → bilingual toggle that flows into every demo's `language:`.
  ThaiAddressLanguage _language = ThaiAddressLanguage.thai;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleLanguage() {
    setState(() {
      _language =
          ThaiAddressLanguage.values[(_language.index + 1) %
              ThaiAddressLanguage.values.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'thai_provinces_flutter gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: GalleryHome(
        controller: _controller,
        language: _language,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }
}

/// The gallery scaffold: a tabbed catalogue of every form-factor plus a
/// persistent live readout of the shared selection.
class GalleryHome extends StatelessWidget {
  /// Creates the gallery home.
  const GalleryHome({
    super.key,
    required this.controller,
    required this.language,
    required this.onToggleLanguage,
  });

  /// The single shared controller every demo binds to.
  final ThaiAddressController controller;

  /// The active display language for all demos.
  final ThaiAddressLanguage language;

  /// Flips the TH/EN language for the whole gallery.
  final VoidCallback onToggleLanguage;

  bool get _isThai => language == ThaiAddressLanguage.thai;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('thai_provinces_flutter'),
        actions: [
          TextButton.icon(
            onPressed: onToggleLanguage,
            icon: const Icon(Icons.translate),
            label: Text(switch (language) {
              ThaiAddressLanguage.thai => 'TH',
              ThaiAddressLanguage.english => 'EN',
              ThaiAddressLanguage.bilingual => 'TH+EN',
            }),
          ),
          IconButton(
            tooltip: 'Clear selection',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: controller.clear,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // A single scrolling list of demo Cards. Every form-factor is mounted at
      // once (so they all bind to the ONE shared controller simultaneously),
      // and the live readout is pinned. Responsive: the readout sits in a
      // sticky right rail on wide screens (web/desktop) and inline at the top
      // on narrow screens (mobile).
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          final readout = _SelectionPanel(
            controller: controller,
            language: language,
          );

          final demos = <Widget>[
            _DemoCard(
              index: 1,
              title: _isThai ? 'ตัวเลือกแบบลำดับชั้น' : 'Cascading picker',
              description:
                  'ThaiAddressPicker — three dependent dropdowns '
                  '(province → district → subdistrict) plus an auto-filled '
                  'postcode field.',
              child: ThaiAddressPicker(
                controller: controller,
                language: language,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            _DemoCard(
              index: 2,
              title: _isThai ? 'ค้นหาแบบพิมพ์ทันที' : 'Type-ahead autocomplete',
              description:
                  'ThaiAddressAutocompleteField — type a province, district, '
                  'subdistrict, or postcode and pick a single fully-resolved '
                  'match.',
              child: ThaiAddressAutocompleteField(
                controller: controller,
                language: language,
                maxOptions: 12,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  hintText:
                      _isThai
                          ? 'พิมพ์ตำบล/อำเภอ/จังหวัด/รหัสไปรษณีย์'
                          : 'Type a subdistrict / district / province / postcode',
                ),
              ),
            ),
            _DemoCard(
              index: 3,
              title: _isThai ? 'เริ่มจากรหัสไปรษณีย์' : 'Postcode-first',
              description:
                  'ThaiPostcodeField — enter a 5-digit postcode; when it maps '
                  'to several subdistricts an inline chooser lets the user '
                  'disambiguate.',
              child: ThaiPostcodeField(
                controller: controller,
                language: language,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                ),
              ),
            ),
            _DemoCard(
              index: 4,
              title: _isThai ? 'เติมค่าเริ่มต้น + รีเซ็ต' : 'Prefill + reset',
              description:
                  'controller.setFromCodes(...) drives the shared selection '
                  'programmatically. Tap a city to prefill, or Reset to clear '
                  'every demo at once.',
              child: _PrefillControls(controller: controller, isThai: _isThai),
            ),
            _DemoCard(
              index: 5,
              title: _isThai ? 'ผสานกับฟอร์ม' : 'Form integration',
              description:
                  'ThaiAddressFormField inside a Form. The validator requires '
                  'a complete address; Submit runs validate() then save(). It '
                  'shares the same controller, so the other demos pre-fill it.',
              child: _FormDemo(controller: controller, language: language),
            ),
            _DemoCard(
              index: 6,
              title: _isThai ? 'ปรับแต่งสไตล์' : 'Styled passthrough',
              description:
                  'The same ThaiAddressPicker with the direct styling '
                  'passthrough: a teal dropdownColor, a rounded borderRadius, a '
                  'bold selected-item style and a custom expand icon — no '
                  'fieldBuilder needed.',
              child: ThaiAddressPicker(
                controller: controller,
                language: language,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                dropdownColor: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                style: const TextStyle(fontWeight: FontWeight.w600),
                icon: const Icon(Icons.expand_more),
                menuMaxHeight: 320,
              ),
            ),
            _DemoCard(
              index: 7,
              title: _isThai ? 'ฟิลด์แบบ bottom-sheet' : 'Bottom-sheet field',
              description:
                  'ThaiAddressSheetField — a compact one-line summary that '
                  'opens a modal bottom-sheet picker on tap; confirm commits, '
                  'cancel leaves the selection untouched. Great for dense '
                  'checkout forms.',
              child: ThaiAddressSheetField(
                controller: controller,
                language: language,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            _DemoCard(
              index: 8,
              title: _isThai ? 'ฟิลด์ค้นหาเต็มจอ' : 'Full-screen search field',
              description:
                  'ThaiAddressSearchField — tap to open a full-screen, '
                  'search-as-you-type picker; pick a ranked result and it '
                  'commits to the shared controller.',
              child: ThaiAddressSearchField(
                controller: controller,
                language: language,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            _DemoCard(
              index: 9,
              title: _isThai ? 'แผนที่ปักหมุด' : 'Map pin picker',
              description:
                  'Tap anywhere on the map; the point is reverse-geocoded '
                  '(offline, via thai_provinces_geo) to the nearest Thai '
                  'subdistrict and committed to the SAME shared controller — so '
                  'the readout and every other demo update in sync.',
              child: _MapPickerDemo(controller: controller, language: language),
            ),
          ];

          // A Column inside a SingleChildScrollView mounts every demo eagerly
          // (unlike a lazy ListView), so all form-factors are bound to the one
          // shared controller from first frame — proving interoperation.
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: demos,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: readout,
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [readout, const SizedBox(height: 16), ...demos],
            ),
          );
        },
      ),
    );
  }
}

/// A uniform card wrapper for one labelled demo, with a leading index badge.
class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.index,
    required this.title,
    required this.description,
    required this.child,
  });

  final int index;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          '$index',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Demo (4): programmatic prefill/reset of the shared controller.
class _PrefillControls extends StatelessWidget {
  const _PrefillControls({required this.controller, required this.isThai});

  final ThaiAddressController controller;
  final bool isThai;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => controller.setFromCodes(subdistrictCode: 100101),
          icon: const Icon(Icons.location_city),
          label: Text(isThai ? 'พระนคร กรุงเทพฯ' : 'Bangkok'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => controller.setFromCodes(subdistrictCode: 500101),
          icon: const Icon(Icons.terrain),
          label: Text(isThai ? 'เมืองเชียงใหม่' : 'Chiang Mai'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => controller.setFromCodes(subdistrictCode: 830101),
          icon: const Icon(Icons.beach_access),
          label: Text(isThai ? 'เมืองภูเก็ต' : 'Phuket'),
        ),
        OutlinedButton.icon(
          onPressed: controller.clear,
          icon: const Icon(Icons.restart_alt),
          label: Text(isThai ? 'รีเซ็ต' : 'Reset'),
        ),
      ],
    );
  }
}

/// Demo (5): a [Form] with [ThaiAddressFormField] + validator + Submit.
class _FormDemo extends StatefulWidget {
  const _FormDemo({required this.controller, required this.language});

  final ThaiAddressController controller;
  final ThaiAddressLanguage language;

  @override
  State<_FormDemo> createState() => _FormDemoState();
}

class _FormDemoState extends State<_FormDemo> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ThaiAddressSelection? _saved;

  bool get _isThai => widget.language == ThaiAddressLanguage.thai;

  void _submit() {
    final form = _formKey.currentState!;
    if (form.validate()) {
      form.save();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isThai ? 'บันทึกที่อยู่แล้ว' : 'Address saved'),
        ),
      );
    } else {
      setState(() => _saved = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThaiAddressFormField(
            controller: widget.controller,
            language: widget.language,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            validator: (selection) {
              if (selection == null || !selection.isComplete) {
                return _isThai
                    ? 'กรุณาเลือกที่อยู่ให้ครบทุกระดับ'
                    : 'Please select a complete address.';
              }
              return null;
            },
            onSaved: (selection) => setState(() => _saved = selection),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: Text(_isThai ? 'ส่ง' : 'Submit'),
          ),
          if (_saved != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${_isThai ? 'บันทึก' : 'Saved'}: '
                  '${const JsonEncoder.withIndent('  ').convert(_saved!.toJson())}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Demo (9): a tap-to-pick map. Tapping reverse-geocodes the point to the
/// nearest Thai subdistrict (offline) and drives the shared controller.
class _MapPickerDemo extends StatefulWidget {
  const _MapPickerDemo({required this.controller, required this.language});

  final ThaiAddressController controller;
  final ThaiAddressLanguage language;

  @override
  State<_MapPickerDemo> createState() => _MapPickerDemoState();
}

class _MapPickerDemoState extends State<_MapPickerDemo> {
  // The last tapped point, used to draw the pin. Null until the first tap.
  LatLng? _pin;

  // An inline status line: either the matched address or a "no match" hint.
  String? _status;
  bool _matched = false;

  bool get _isThai => widget.language == ThaiAddressLanguage.thai;

  void _handleTap(TapPosition _, LatLng point) {
    // Offline reverse-geocode, bounded to 20 km so an ocean/border tap that is
    // nowhere near a Thai subdistrict resolves to null instead of mis-filling.
    final sub = reverseGeocode(point.latitude, point.longitude, maxKm: 20);

    if (sub == null) {
      // Too far / off-map: never crash, never mis-fill. Leave controller as-is.
      setState(() {
        _pin = point;
        _matched = false;
        _status =
            _isThai
                ? 'ไม่พบพื้นที่ใกล้จุดนี้'
                : 'No subdistrict near this point';
      });
      return;
    }

    // Found a subdistrict: drop the pin and commit to the SHARED controller.
    // This notifies every other demo + the readout panel.
    widget.controller.setFromCodes(subdistrictCode: sub.code);

    final selection = widget.controller.value;
    setState(() {
      _pin = point;
      _matched = true;
      _status =
          selection.isEmpty
              ? (_isThai ? sub.nameTh : sub.nameEn)
              : selection.format(language: widget.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              key: const ValueKey('map-pin-map'),
              options: MapOptions(
                initialCenter: const LatLng(13.7563, 100.5018),
                initialZoom: 5.5,
                minZoom: 4,
                maxZoom: 18,
                onTap: _handleTap,
                // Keep interaction simple and robust inside a scroll view:
                // pan + pinch/scroll-zoom, no rotation.
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.drag |
                      InteractiveFlag.flingAnimation |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.scrollWheelZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.ultramcu.thai_provinces_flutter.example',
                ),
                if (_pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color:
                              _matched
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              _pin == null
                  ? Icons.touch_app_outlined
                  : (_matched ? Icons.place : Icons.not_listed_location),
              size: 20,
              color:
                  _pin == null
                      ? theme.colorScheme.onSurfaceVariant
                      : (_matched
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _status ??
                    (_isThai
                        ? 'แตะบนแผนที่เพื่อค้นหาตำบลที่ใกล้ที่สุด'
                        : 'Tap the map to find the nearest subdistrict'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      _pin != null && !_matched
                          ? theme.colorScheme.error
                          : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The persistent live readout, bound to the single shared controller via a
/// [ValueListenableBuilder] — no setState plumbing across demos.
class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({required this.controller, required this.language});

  final ThaiAddressController controller;
  final ThaiAddressLanguage language;

  bool get _isThai => language == ThaiAddressLanguage.thai;

  String _name(String? th, String? en) {
    final value = _isThai ? th : en;
    return (value == null || value.isEmpty) ? '—' : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<ThaiAddressSelection>(
      valueListenable: controller,
      builder: (context, selection, _) {
        final json = const JsonEncoder.withIndent(
          '  ',
        ).convert(selection.toJson());
        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.my_location, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isThai ? 'ที่อยู่ปัจจุบัน' : 'Current selection',
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        selection.isComplete
                            ? (_isThai ? 'ครบถ้วน' : 'Complete')
                            : (_isThai ? 'ยังไม่ครบ' : 'Incomplete'),
                      ),
                      backgroundColor:
                          selection.isComplete
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.errorContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 24),
                _row(
                  context,
                  _isThai ? 'จังหวัด' : 'Province',
                  _name(selection.province?.nameTh, selection.province?.nameEn),
                ),
                _row(
                  context,
                  _isThai ? 'อำเภอ/เขต' : 'District',
                  _name(selection.district?.nameTh, selection.district?.nameEn),
                ),
                _row(
                  context,
                  _isThai ? 'ตำบล/แขวง' : 'Subdistrict',
                  _name(
                    selection.subdistrict?.nameTh,
                    selection.subdistrict?.nameEn,
                  ),
                ),
                _row(
                  context,
                  _isThai ? 'รหัสไปรษณีย์' : 'Postcode',
                  selection.postcode?.toString() ?? '—',
                ),
                const SizedBox(height: 12),
                _row(
                  context,
                  'format()',
                  selection.isEmpty
                      ? '—'
                      : selection.format(language: language),
                ),
                const SizedBox(height: 16),
                Text(
                  'toJson()',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
