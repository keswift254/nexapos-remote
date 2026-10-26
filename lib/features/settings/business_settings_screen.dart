import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/printing/thermal_printer_service.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/services/business_settings_service.dart';
import '../../domain/services/theme_settings.dart';

part 'business_settings_screen.g.dart';

@riverpod
Future<BusinessSettings> currentBusinessSettings(Ref ref) {
  return ref.watch(businessSettingsServiceProvider).get();
}

/// No PHP page to port here - business_settings backs what used to be
/// PHP's file-based config/config.php 'receipt' section (see
/// business_settings_table.dart), which a phone has no config file to
/// hand-edit, so this screen is new rather than ported.
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _footerController = TextEditingController();
  final _currencyController = TextEditingController();
  final _printerIpController = TextEditingController();
  final _windowsPrinterNameController = TextEditingController();
  int _paperWidthMm = 58;
  bool _submitting = false;
  bool _prefilled = false;
  bool _savingPrinterIp = false;
  bool _testPrinting = false;
  bool _findingNetworkPrinters = false;
  PrinterConnectionType _connectionType = PrinterConnectionType.network;
  List<String> _availableWindowsPrinters = const [];
  List<String> _networkPrinters = const [];

  @override
  void initState() {
    super.initState();
    final printerService = ref.read(thermalPrinterServiceProvider);
    printerService.loadIpAddress().then((ip) {
      if (mounted) setState(() => _printerIpController.text = ip);
    });
    printerService.loadWindowsPrinterName().then((name) {
      if (mounted) setState(() => _windowsPrinterNameController.text = name);
    });
    printerService.loadConnectionType().then((type) {
      if (mounted) setState(() => _connectionType = type);
    });
    if (Platform.isWindows) {
      _availableWindowsPrinters = printerService.listWindowsPrinters();
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _currencyController.dispose();
    _printerIpController.dispose();
    _windowsPrinterNameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePrinterIp() async {
    if (_printerIpController.text.trim().isEmpty) {
      _showMessage('Enter or select a printer IP address first.');
      return;
    }
    setState(() => _savingPrinterIp = true);
    try {
      final service = ref.read(thermalPrinterServiceProvider);
      await service.saveConnectionType(PrinterConnectionType.network);
      await service.saveIpAddress(_printerIpController.text);
      if (mounted) {
        setState(() => _connectionType = PrinterConnectionType.network);
      }
      _showMessage('Printer address saved.');
    } finally {
      if (mounted) setState(() => _savingPrinterIp = false);
    }
  }

  Future<void> _findNetworkPrinters() async {
    setState(() => _findingNetworkPrinters = true);
    try {
      final addresses = await ref
          .read(thermalPrinterServiceProvider)
          .discoverNetworkPrinters();
      if (!mounted) return;
      setState(() => _networkPrinters = addresses);
      if (addresses.isEmpty) {
        _showMessage(
          'No direct-IP printers found on this LAN. For a printer connected to another PC, use Windows printer (USB or shared).',
        );
      }
    } catch (error) {
      _showMessage('Could not search this LAN: $error');
    } finally {
      if (mounted) setState(() => _findingNetworkPrinters = false);
    }
  }

  Future<void> _saveWindowsPrinter() async {
    setState(() => _savingPrinterIp = true);
    try {
      final service = ref.read(thermalPrinterServiceProvider);
      await service.saveConnectionType(PrinterConnectionType.windowsUsb);
      await service.saveWindowsPrinterName(_windowsPrinterNameController.text);
      if (mounted) {
        setState(() => _connectionType = PrinterConnectionType.windowsUsb);
      }
      _showMessage('Printer saved.');
    } finally {
      if (mounted) setState(() => _savingPrinterIp = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testPrinting = true);
    try {
      await ref
          .read(thermalPrinterServiceProvider)
          .printTestPage(_paperWidthMm);
      _showMessage('Test page sent to the printer.');
    } catch (e) {
      _showMessage('$e');
    } finally {
      if (mounted) setState(() => _testPrinting = false);
    }
  }

  void _prefillFrom(BusinessSettings settings) {
    if (_prefilled) return;
    _prefilled = true;
    _businessNameController.text = settings.businessName;
    _addressController.text = settings.address ?? '';
    _phoneController.text = settings.phone ?? '';
    _footerController.text = settings.receiptFooter ?? '';
    _currencyController.text = settings.currency;
    _paperWidthMm = settings.paperWidthMm;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final result = await ref
        .read(businessSettingsServiceProvider)
        .update(
          businessName: _businessNameController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          receiptFooter: _footerController.text,
          currency: _currencyController.text,
          paperWidthMm: _paperWidthMm,
        );

    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      ok: (_) {
        ref.invalidate(currentBusinessSettingsProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved.')));
      },
      failure: (message) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message))),
    );
  }

  String? _requiredValidator(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(currentBusinessSettingsProvider);
    final themeMode = ref.watch(themeSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Business, Receipts & Themes')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (settings) {
          _prefillFrom(settings);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ThemeMode>(
                  key: ValueKey(themeMode),
                  initialValue: themeMode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Use system setting'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeSettingsProvider.notifier).setMode(mode);
                    }
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'Shown on printed receipts.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _footerController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt footer message (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Currency code (e.g. KES)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 16),
                Text(
                  'Receipt paper width',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('58mm'),
                      selected: _paperWidthMm == 58,
                      onSelected: (_) => setState(() => _paperWidthMm = 58),
                    ),
                    ChoiceChip(
                      label: const Text('80mm'),
                      selected: _paperWidthMm == 80,
                      onSelected: (_) => setState(() => _paperWidthMm = 80),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal printer',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This device only - a shop with several counters sets this separately on each one.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (Platform.isWindows) ...[
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Network (IP address)'),
                                selected:
                                    _connectionType ==
                                    PrinterConnectionType.network,
                                onSelected: (_) => setState(
                                  () => _connectionType =
                                      PrinterConnectionType.network,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text(
                                  'Windows printer (USB or shared)',
                                ),
                                selected:
                                    _connectionType ==
                                    PrinterConnectionType.windowsUsb,
                                onSelected: (_) => setState(
                                  () => _connectionType =
                                      PrinterConnectionType.windowsUsb,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_connectionType ==
                            PrinterConnectionType.windowsUsb) ...[
                          Text(
                            'Install or connect the printer in Windows first, including printers shared from another PC. Then pick it below.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (_availableWindowsPrinters.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _availableWindowsPrinters.contains(
                                    _windowsPrinterNameController.text,
                                  )
                                  ? _windowsPrinterNameController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Printer',
                              ),
                              items: [
                                for (final name in _availableWindowsPrinters)
                                  DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () => _windowsPrinterNameController.text =
                                    value ?? '',
                              ),
                            )
                          else
                            TextField(
                              controller: _windowsPrinterNameController,
                              decoration: const InputDecoration(
                                labelText: 'Printer name',
                                helperText: 'No installed printers were found automatically - type the exact name from Windows\' printer list.',
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _availableWindowsPrinters = ref
                                  .read(thermalPrinterServiceProvider)
                                  .listWindowsPrinters(),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Windows printers'),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _savingPrinterIp
                                    ? null
                                    : _saveWindowsPrinter,
                                child: _savingPrinterIp
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save printer'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _testPrinting ? null : _testPrint,
                                icon: _testPrinting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.print_outlined),
                                label: const Text('Test print'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'For a printer with its own Ethernet/Wi-Fi IP and raw port 9100. If it is plugged into another PC, choose Windows printer (USB or shared) instead.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _printerIpController,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP address',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          if (_networkPrinters.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _networkPrinters.contains(
                                    _printerIpController.text,
                                  )
                                  ? _printerIpController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Printers found on this LAN',
                              ),
                              items: [
                                for (final ip in _networkPrinters)
                                  DropdownMenuItem(value: ip, child: Text(ip)),
                              ],
                              onChanged: (ip) => setState(
                                () => _printerIpController.text = ip ?? '',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _findingNetworkPrinters
                                    ? null
                                    : _findNetworkPrinters,
                                icon: _findingNetworkPrinters
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                                label: const Text('Find network printers'),
                              ),
                              OutlinedButton(
                                onPressed: _savingPrinterIp
                                    ? null
                                    : _savePrinterIp,
                                child: _savingPrinterIp
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save address'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _testPrinting ? null : _testPrint,
                                icon: _testPrinting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.print_outlined),
                                label: const Text('Test print'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
