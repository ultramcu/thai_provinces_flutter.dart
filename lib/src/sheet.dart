import 'package:flutter/material.dart';

import 'controller.dart';
import 'language.dart';
import 'picker.dart';
import 'selection.dart';

/// Opens a modal bottom sheet containing a cascading Thai address picker,
/// seeded from [initial], and resolves to the chosen [ThaiAddressSelection]
/// when the user confirms — or `null` when they cancel or dismiss the sheet
/// (so a cancelled edit leaves the caller's state untouched).
///
/// [language] drives the picker labels; [title] and [confirmLabel] override the
/// sheet's heading and confirm-button text (each falls back to a localized
/// default). Built on stock `showModalBottomSheet`; no extra dependencies.
/// Implemented by the sheet dev.
Future<ThaiAddressSelection?> showThaiAddressSheet(
  BuildContext context, {
  ThaiAddressSelection? initial,
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
  String? title,
  String? confirmLabel,
}) async {
  final isThai = language == ThaiAddressLanguage.thai;
  final heading = title ?? (isThai ? 'เลือกที่อยู่' : 'Select address');
  final confirmText = confirmLabel ?? (isThai ? 'ยืนยัน' : 'Confirm');

  // A staging controller seeded from [initial], so edits inside the sheet do
  // NOT mutate the caller's state until the user confirms. Disposed after the
  // sheet closes (in the finally below), regardless of how it closed.
  final staging = ThaiAddressController(
    initial: initial ?? ThaiAddressSelection.empty,
  );

  try {
    // Dismissing or backing out yields `null`; confirm pops the staging value.
    return await showModalBottomSheet<ThaiAddressSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        // Handle the keyboard inset so long content/keyboard fit on screen.
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  heading,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ThaiAddressPicker(controller: staging, language: language),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, staging.value),
                  child: Text(confirmText),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    staging.dispose();
  }
}
