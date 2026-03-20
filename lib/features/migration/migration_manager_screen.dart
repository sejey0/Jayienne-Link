import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../utils/firebase_data_exporter.dart';
import '../../utils/supabase_data_importer.dart';

/// Migration manager screen for transferring data from Firebase to Supabase
/// Provides a UI for exporting, importing, and tracking migration progress
class MigrationManagerScreen extends StatefulWidget {
  const MigrationManagerScreen({super.key});

  @override
  State<MigrationManagerScreen> createState() => _MigrationManagerScreenState();
}

class _MigrationManagerScreenState extends State<MigrationManagerScreen> {
  final FirebaseDataExporter _exporter = FirebaseDataExporter();
  final SupabaseDataImporter _importer = SupabaseDataImporter();

  bool _isExporting = false;
  bool _isImporting = false;
  String? _exportedData;
  Map<String, int>? _firebaseStats;
  Map<String, int>? _importResults;

  @override
  void initState() {
    super.initState();
    _loadFirebaseStats();
  }

  Future<void> _loadFirebaseStats() async {
    try {
      final stats = await _exporter.getMigrationStats();
      setState(() => _firebaseStats = stats);
    } catch (e) {
      debugPrint('Error loading Firebase stats: $e');
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _exportedData = null;
    });

    try {
      final jsonData = await _exporter.exportToJson();
      setState(() {
        _exportedData = jsonData;
        _isExporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    if (_exportedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please export data first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm before importing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Import'),
        content: const Text(
          'This will import all Firebase data into Supabase. '
          'Make sure you have set up your Supabase project and '
          'run the migration SQL script.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isImporting = true;
      _importResults = null;
    });

    try {
      final results = await _importer.importFromJson(_exportedData!);
      setState(() {
        _importResults = results;
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data imported successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Verify import
        await _verifyImport();
      }
    } catch (e) {
      setState(() => _isImporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Import failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _verifyImport() async {
    try {
      final stats = await _importer.verifyImport();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Import Verification'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supabase database statistics:'),
                  const SizedBox(height: 8),
                  Text('Users: ${stats['users_count'] ?? 'N/A'}'),
                  Text('Couples: ${stats['couples_count'] ?? 'N/A'}'),
                  Text('Locations: ${stats['locations_count'] ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Your data has been successfully migrated to Supabase!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verifying import: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase → Supabase Migration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Migration Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('1. Export your Firebase data'),
                    const Text(
                        '2. Set up Supabase and run migration SQL script'),
                    const Text('3. Import data to Supabase'),
                    const Text('4. Verify the migration'),
                    const SizedBox(height: 12),
                    const Text(
                      '⚠️ Note: This will NOT delete your Firebase data. '
                      'Your Firebase data remains as a backup.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Firebase Statistics
            if (_firebaseStats != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Firebase Data Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow('Users', _firebaseStats!['users'] ?? 0),
                      _buildStatRow('Couples', _firebaseStats!['couples'] ?? 0),
                      _buildStatRow(
                          'Invite Codes', _firebaseStats!['invite_codes'] ?? 0),
                      _buildStatRow(
                          'Locations', _firebaseStats!['locations'] ?? 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Export Button
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportData,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExporting
                  ? 'Exporting...'
                  : 'Step 1: Export Firebase Data'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            // Export Status
            if (_exportedData != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✅ Data Exported',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Size: ${(_exportedData!.length / 1024).toStringAsFixed(2)} KB',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Import Button
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _importData,
                icon: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isImporting
                    ? 'Importing...'
                    : 'Step 3: Import to Supabase'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Import Results
            if (_importResults != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 12),
                          Text(
                            '✅ Import Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                          'Users Imported', _importResults!['users'] ?? 0),
                      _buildStatRow(
                          'Couples Imported', _importResults!['couples'] ?? 0),
                      _buildStatRow('Invite Codes Imported',
                          _importResults!['invite_codes'] ?? 0),
                      _buildStatRow('Locations Imported',
                          _importResults!['locations'] ?? 0),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tips
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue),
                        SizedBox(width: 12),
                        Text(
                          '💡 Pro Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('• Your Firebase data is NOT deleted'),
                    const Text('• Run the migration during low-traffic hours'),
                    const Text('• Verify the import before switching users'),
                    const Text('• Keep Firebase active as a backup'),
                    const Text('• Test the Supabase integration thoroughly'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
