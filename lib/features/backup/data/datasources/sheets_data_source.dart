import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:pixel_pocket/features/backup/data/datasources/google_auth_client.dart';

const backupFileName = 'Pixel Pocket Backup';
const backupTabs = [
  'Transactions',
  'Categories',
  'SalaryPeriods',
  'Accounts',
  'Metadata',
];

class SheetsDataSource {
  SheetsDataSource(this._auth);

  final GoogleAuthClient _auth;

  Future<String> findOrCreateSpreadsheet() async {
    final client = _auth.authedClient();
    try {
      final driveApi = drive.DriveApi(client);
      final result = await driveApi.files.list(
        q:
            "name = '$backupFileName' and "
            "mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );
      final files = result.files ?? [];
      if (files.isNotEmpty && files.first.id != null) {
        return files.first.id!;
      }
      final sheetsApi = sheets.SheetsApi(client);
      final created = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: backupFileName),
          sheets: [
            for (final t in backupTabs)
              sheets.Sheet(properties: sheets.SheetProperties(title: t)),
          ],
        ),
      );
      return created.spreadsheetId!;
    } finally {
      client.close();
    }
  }

  Future<void> writeTab(
    String spreadsheetId,
    String tab,
    List<List<Object?>> valuesWithHeader,
  ) async {
    final client = _auth.authedClient();
    try {
      final api = sheets.SheetsApi(client);
      await api.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        spreadsheetId,
        tab,
      );
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: valuesWithHeader),
        spreadsheetId,
        '$tab!A1',
        valueInputOption: 'RAW',
      );
    } finally {
      client.close();
    }
  }

  Future<List<List<Object?>>> readTab(String spreadsheetId, String tab) async {
    final client = _auth.authedClient();
    try {
      final api = sheets.SheetsApi(client);
      final range = await api.spreadsheets.values.get(spreadsheetId, tab);
      return range.values ?? [];
    } finally {
      client.close();
    }
  }

  Future<List<String>> tabTitles(String spreadsheetId) async {
    final client = _auth.authedClient();
    try {
      final api = sheets.SheetsApi(client);
      final spreadsheet = await api.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets.properties.title',
      );
      return (spreadsheet.sheets ?? const <sheets.Sheet>[])
          .map((s) => s.properties?.title)
          .whereType<String>()
          .toList();
    } finally {
      client.close();
    }
  }

  Future<void> ensureTab(String spreadsheetId, String tab) async {
    if ((await tabTitles(spreadsheetId)).contains(tab)) return;
    final client = _auth.authedClient();
    try {
      await sheets.SheetsApi(client).spreadsheets.batchUpdate(
            sheets.BatchUpdateSpreadsheetRequest(
              requests: [
                sheets.Request(
                  addSheet: sheets.AddSheetRequest(
                    properties: sheets.SheetProperties(title: tab),
                  ),
                ),
              ],
            ),
            spreadsheetId,
          );
    } finally {
      client.close();
    }
  }

  Future<List<List<Object?>>> readTabIfExists(
    String spreadsheetId,
    String tab,
  ) async {
    if (!(await tabTitles(spreadsheetId)).contains(tab)) return const [];
    return readTab(spreadsheetId, tab);
  }
}

final sheetsDataSourceProvider = Provider<SheetsDataSource>(
  (ref) => SheetsDataSource(ref.watch(googleAuthClientProvider)),
);
