import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../providers/expense_provider.dart';
import '../utils/app_constants.dart';

class ExportService {
  // Currency formatting helper
  static String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  // Export to PDF with detailed information
  static Future<String> exportToPdf(
    Group group,
    List<Expense> expenses,
    ExpenseProvider provider,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // Use provider methods for calculations
    final totalExpenses = await provider.getTotalExpenses(group.id);
    final actualExpenses = await provider.getNormalExpenses(group.id);

    // Get balances and financial data for each member
    final memberBalances = <String, Map<String, double>>{};
    for (var member in group.members) {
      final paid = await provider.getPersonTotalPaid(group.id, member.id);
      final owed = await provider.getPersonTotalOwed(group.id, member.id);
      final balance = await provider.getPersonBalance(group.id, member.id);

      memberBalances[member.id] = {
        'paid': paid,
        'owed': owed,
        'balance': balance,
      };
    }

    // Get settlement suggestions from provider
    final settlements = await provider.calculateBalances(group.id);

    // Define modern lighter colors
    const primaryColor = PdfColor.fromInt(0xFF009688); // Teal
    const accentColor = PdfColor.fromInt(0xFF4DB6AC); // Lighter teal
    const lightGray = PdfColor.fromInt(0xFFFAFAFA); // Very light gray

    // Common generation date and version info
    final generationDate = DateFormat('MMM dd, yyyy').format(DateTime.now());
    final generationTime = DateFormat('hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 60, 32, 50),
        header: (context) => _buildPageHeader(
          generationDate,
          generationTime,
          context.pageNumber,
          context.pagesCount,
        ),
        footer: (context) => _buildPageFooter(context.pageNumber),
        build: (pw.Context context) {
          return [
            // Merged Modern Header - App Name + Group Info
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [primaryColor, accentColor],
                ),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // App branding at top
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${AppConstants.appName} - EXPENSE REPORT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.Text(
                        'v${AppConstants.appVersion}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white.shade(0.7),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.white.shade(0.3), height: 1),
                  pw.SizedBox(height: 12),
                  // Group info below
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              group.name.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            if (group.description != null) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                group.description!,
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Generated',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white.shade(0.7),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            DateFormat('MMM dd, yyyy').format(DateTime.now()),
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            timeFormat.format(DateTime.now()),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Financial Summary Cards with lighter colors
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                  'Total Expenses',
                  _formatCurrency(totalExpenses),
                  '${actualExpenses.length} transactions',
                  const PdfColor.fromInt(0xFFB2DFDB), // Very light teal
                  primaryColor, // Text color
                ),
                pw.SizedBox(width: 12),
                _buildSummaryCard(
                  'Group Members',
                  '${group.members.length}',
                  'Active participants',
                  const PdfColor.fromInt(0xFFE0F2F1), // Even lighter teal
                  accentColor, // Text color
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Member Balances Section
            _buildSectionHeader('Member Balances', primaryColor),
            pw.SizedBox(height: 12),

            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(color: PdfColors.grey200),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: lightGray),
                    children: [
                      _buildTableHeader('Member'),
                      _buildTableHeader('Total Paid'),
                      _buildTableHeader('Total Owed'),
                      _buildTableHeader('Balance'),
                    ],
                  ),
                  // Data rows
                  ...group.members.map((member) {
                    final memberData = memberBalances[member.id]!;
                    final paid = memberData['paid']!;
                    final owed = memberData['owed']!;
                    final balance = memberData['balance']!;

                    return pw.TableRow(
                      children: [
                        _buildTableCell(member.name, bold: true),
                        _buildTableCell(_formatCurrency(paid)),
                        _buildTableCell(_formatCurrency(owed)),
                        _buildTableCell(
                          balance >= 0
                              ? '+${_formatCurrency(balance.abs())}'
                              : '-${_formatCurrency(balance.abs())}',
                          color: balance >= 0 ? PdfColors.green : PdfColors.red,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Settlement Summary
            _buildSectionHeader('Settlement Summary', primaryColor),
            pw.SizedBox(height: 12),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _buildSettlementSuggestions(group, settlements),
              ),
            ),

            pw.SizedBox(height: 24),

            // Detailed Expenses
            _buildSectionHeader('Detailed Expenses', primaryColor),
            pw.SizedBox(height: 12),

            // Show ALL expenses (including settlements) but mark them differently
            ...expenses.map((expense) => _buildExpenseCard(
                  expense,
                  dateFormat,
                  group,
                )),
          ];
        },
      ),
    );

    // Save PDF
    final output = await getApplicationDocumentsDirectory();
    final fileName =
        '${group.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // Build modern page header with app info
  static pw.Widget _buildPageHeader(
    String date,
    String time,
    int pageNumber,
    int totalPages,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFAFAFA),
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: App name and version
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF009688),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'v${AppConstants.appVersion}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          // Right: Generation date and page number
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Generated: $date $time',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Page $pageNumber of $totalPages',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build modern page footer
  static pw.Widget _buildPageFooter(int pageNumber) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColor.fromInt(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          '${AppConstants.appName} - Smart Group Expense Manager',
          style: const pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey500,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryCard(
    String label,
    String value,
    String subtitle,
    PdfColor backgroundColor,
    PdfColor textColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: backgroundColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
            color: textColor,
            width: 1,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8,
                color: textColor,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              subtitle,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 6, bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: color, width: 3),
        ),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static List<pw.Widget> _buildSettlementSuggestions(
    Group group,
    Map<String, Map<String, double>> settlements,
  ) {
    final suggestions = <pw.Widget>[];

    // Check if there are any settlements needed
    bool hasSettlements = false;
    for (var debtor in settlements.values) {
      if (debtor.isNotEmpty) {
        hasSettlements = true;
        break;
      }
    }

    if (!hasSettlements) {
      return [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFE8F5E9),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: PdfColors.green,
              width: 2,
            ),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    'OK',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'All balances are settled!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // Build settlement suggestions from provider's optimized calculations
    int count = 0;
    for (var debtorEntry in settlements.entries) {
      final debtorId = debtorEntry.key;
      final debtorName = group.members
          .firstWhere((m) => m.id == debtorId, orElse: () => Person(id: '', name: 'Unknown'))
          .name;

      for (var creditorEntry in debtorEntry.value.entries) {
        final creditorId = creditorEntry.key;
        final amount = creditorEntry.value;

        if (amount <= 0.01) continue;

        final creditorName = group.members
            .firstWhere((m) => m.id == creditorId, orElse: () => Person(id: '', name: 'Unknown'))
            .name;

        count++;
        suggestions.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF009688),
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '$count',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Text(
                    '$debtorName pays ${_formatCurrency(amount)} to $creditorName',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return suggestions;
  }

  static pw.Widget _buildExpenseCard(
    Expense expense,
    DateFormat dateFormat,
    Group group,
  ) {
    // Different styling for settlements
    final isSettlement = expense.isSettlement;
    final cardColor = isSettlement ? const PdfColor.fromInt(0xFFFFF8E1) : PdfColors.white;
    final borderColor = isSettlement ? const PdfColor.fromInt(0xFFFFB300) : PdfColors.grey300;
    final amountColor = isSettlement ? const PdfColor.fromInt(0xFFFF6F00) : const PdfColor.fromInt(0xFF009688);

    return pw.Wrap(
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor),
            borderRadius: pw.BorderRadius.circular(4),
            color: cardColor,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header row with description and amount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              expense.description,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (isSettlement) ...[
                              pw.SizedBox(width: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xFFFF6F00),
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  'SETTLEMENT',
                                  style: pw.TextStyle(
                                    fontSize: 5,
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          children: [
                            pw.Text(
                              dateFormat.format(expense.date),
                              style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.grey700,
                              ),
                            ),
                            if (expense.category != null && !isSettlement) ...[
                              pw.SizedBox(width: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xFFE0F2F1),
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  expense.category!,
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: const PdfColor.fromInt(0xFF00796B),
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    _formatCurrency(expense.amount),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey200, height: 1),
              pw.SizedBox(height: 4),

              // Payment details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Paid By:',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        ...expense.payers.map((payer) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 0.5),
                              child: pw.Text(
                                '${payer.person.name}: ${_formatCurrency(payer.amount)}',
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            )),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Split:',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        ...expense.splits.entries.map((entry) {
                          final person = group.members.firstWhere(
                            (m) => m.id == entry.key,
                            orElse: () => Person(id: '', name: 'Unknown'),
                          );
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 0.5),
                            child: pw.Text(
                              '${person.name}: ${_formatCurrency(entry.value)}',
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              // Notes if present
              if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFFF9C4),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Note: ',
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          expense.notes!,
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Export to Excel with detailed information
  static Future<String> exportToExcel(
    Group group,
    List<Expense> expenses,
    ExpenseProvider provider,
  ) async {
    final excel = Excel.createExcel();

    // Use provider methods for calculations
    final totalExpenses = await provider.getTotalExpenses(group.id);

    // Get balances for each member
    final memberBalances = <String, Map<String, double>>{};
    for (var member in group.members) {
      final paid = await provider.getPersonTotalPaid(group.id, member.id);
      final owed = await provider.getPersonTotalOwed(group.id, member.id);
      final balance = await provider.getPersonBalance(group.id, member.id);

      memberBalances[member.id] = {
        'paid': paid,
        'owed': owed,
        'balance': balance,
      };
    }

    // Define styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.fromHexString('#009688'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#009688'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final subHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E0F2F1'),
      fontColorHex: ExcelColor.fromHexString('#00796B'),
    );

    final positiveStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#2E7D32'),
      bold: true,
    );

    final negativeStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#C62828'),
      bold: true,
    );

    // ===== SUMMARY SHEET =====
    final summarySheet = excel['Summary'];

    // Title
    var cell = summarySheet.cell(CellIndex.indexByString('A1'));
    cell.value = TextCellValue('GROUP EXPENSE REPORT');
    cell.cellStyle = titleStyle;
    summarySheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('D1'),
    );

    // Group info
    summarySheet.cell(CellIndex.indexByString('A3')).value =
        TextCellValue('Group Name:');
    summarySheet.cell(CellIndex.indexByString('B3')).value =
        TextCellValue(group.name);
    summarySheet.cell(CellIndex.indexByString('B3')).cellStyle =
        CellStyle(bold: true);

    if (group.description != null) {
      summarySheet.cell(CellIndex.indexByString('A4')).value =
          TextCellValue('Description:');
      summarySheet.cell(CellIndex.indexByString('B4')).value =
          TextCellValue(group.description!);
    }

    summarySheet.cell(CellIndex.indexByString('A5')).value =
        TextCellValue('Export Date:');
    summarySheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(
      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );

    // Financial summary
    int row = 7;
    cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = TextCellValue('FINANCIAL SUMMARY');
    cell.cellStyle = subHeaderStyle;
    summarySheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );

    row += 2;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('Total Expenses:');
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        IntCellValue(expenses.length);

    row++;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('Total Amount:');
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        DoubleCellValue(totalExpenses);
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle =
        CellStyle(bold: true);

    row++;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('Group Members:');
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        IntCellValue(group.members.length);

    // Member balances
    row += 3;
    cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = TextCellValue('MEMBER BALANCES');
    cell.cellStyle = subHeaderStyle;
    summarySheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );

    row += 1;
    final balanceHeaders = ['Member', 'Total Paid', 'Total Owed', 'Balance'];
    for (var i = 0; i < balanceHeaders.length; i++) {
      cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
      cell.value = TextCellValue(balanceHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    row++;
    for (var member in group.members) {
      final memberData = memberBalances[member.id]!;
      final paid = memberData['paid']!;
      final owed = memberData['owed']!;
      final balance = memberData['balance']!;

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(member.name);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(paid);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(owed);

      cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      cell.value = DoubleCellValue(balance);
      cell.cellStyle = balance >= 0 ? positiveStyle : negativeStyle;

      row++;
    }

    // Set column widths for summary sheet
    summarySheet.setColumnWidth(0, 20);
    summarySheet.setColumnWidth(1, 15);
    summarySheet.setColumnWidth(2, 15);
    summarySheet.setColumnWidth(3, 15);

    // ===== DETAILED EXPENSES SHEET =====
    final expensesSheet = excel['Detailed Expenses'];

    // Headers
    final expenseHeaders = [
      'Date',
      'Description',
      'Category',
      'Total Amount',
      'Paid By',
      'Amount Paid',
      'Participants',
      'Split Details',
      'Notes',
    ];

    for (var i = 0; i < expenseHeaders.length; i++) {
      cell = expensesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(expenseHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd');
    int expenseRow = 1;
    for (final expense in expenses) {
      final paidByText = expense.payers.map((p) => p.person.name).join(', ');
      final paidAmounts =
          expense.payers.map((p) => '\$${p.amount.toStringAsFixed(2)}').join(', ');
      final participants = expense.participants.map((p) => p.name).join(', ');
      final splitDetails = expense.splits.entries.map((e) {
        final person = group.members.firstWhere(
          (m) => m.id == e.key,
          orElse: () => Person(id: '', name: 'Unknown'),
        );
        return '${person.name}: \$${e.value.toStringAsFixed(2)}';
      }).join(', ');

      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: expenseRow))
          .value = TextCellValue(dateFormat.format(expense.date));
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: expenseRow))
          .value = TextCellValue(expense.description);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: expenseRow))
          .value = TextCellValue(expense.category ?? '');
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: expenseRow))
          .value = DoubleCellValue(expense.amount);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: expenseRow))
          .value = TextCellValue(paidByText);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: expenseRow))
          .value = TextCellValue(paidAmounts);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: expenseRow))
          .value = TextCellValue(participants);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: expenseRow))
          .value = TextCellValue(splitDetails);
      expensesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: expenseRow))
          .value = TextCellValue(expense.notes ?? '');

      expenseRow++;
    }

    // Set column widths for expenses sheet
    expensesSheet.setColumnWidth(0, 12);
    expensesSheet.setColumnWidth(1, 25);
    expensesSheet.setColumnWidth(2, 15);
    expensesSheet.setColumnWidth(3, 12);
    expensesSheet.setColumnWidth(4, 20);
    expensesSheet.setColumnWidth(5, 15);
    expensesSheet.setColumnWidth(6, 25);
    expensesSheet.setColumnWidth(7, 30);
    expensesSheet.setColumnWidth(8, 30);

    // Remove default sheet
    excel.delete('Sheet1');

    // Save Excel
    final output = await getApplicationDocumentsDirectory();
    final fileName =
        '${group.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.save();
    final file = File('${output.path}/$fileName');

    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }

    return file.path;
  }
}
