// ignore_for_file: public_member_api_docs, sort_constructors_first
// reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:apma/monitor.dart';

class Reports extends StatefulWidget {
  const Reports({super.key, required List records});

  @override
  _ReportsState createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  String _selectedSpecies = 'All';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<AnimalRecord> _filterRecords(List<AnimalRecord> records) {
    if (_selectedSpecies == 'All') return records;
    return records.where((r) => r.species == _selectedSpecies).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedSpecies = value);
            },
            itemBuilder: (BuildContext context) {
              final species = ['All', ...YOLO_CLASSES];
              return species.map((String species) {
                return PopupMenuItem<String>(
                  value: species,
                  child: Text(species),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('animalReports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No reports found"));
          }

          final allRecords = snapshot.data!.docs.map((doc) {
            return AnimalRecord.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();

          final filteredRecords = _filterRecords(allRecords);

          return ListView.builder(
            itemCount: filteredRecords.length,
            itemBuilder: (context, index) {
              final record = filteredRecords[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(record.id.substring(0, 1)),
                  ),
                  title: Text('${record.species} (ID: ${record.id})'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Health: ${record.healthStatus}'),
                      Text('Detected: ${record.detectedAt.toString().split('.')[0]}'),
                      Text('Confidence: ${(record.confidence * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditDialog(context, record),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, AnimalRecord record) async {
    String notes = record.notes;
    String? healthStatus = record.healthStatus;

    if (!['Healthy', 'Needs Attention', 'Critical'].contains(healthStatus)) {
      healthStatus = 'Healthy';
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${record.species} ${record.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: healthStatus,
                  items: ['Healthy', 'Needs Attention', 'Critical']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) => healthStatus = value!,
                  decoration: const InputDecoration(labelText: 'Health Status'),
                ),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onChanged: (value) => notes = value,
                  controller: TextEditingController(text: notes),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateRecord(record.id, healthStatus!, notes);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateRecord(String id, String healthStatus, String notes) async {
    try {
      // Check if the document exists before attempting an update
      final docRef = _firestore.collection('animalReports').doc(id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception("Document with ID $id does not exist in Firestore.");
      }

      // Proceed with the update if document exists
      await docRef.update({
        'healthStatus': healthStatus,
        'notes': notes,
      });
      print("Record updated successfully");

      // Provide user feedback on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Failed to update record: $e");

      // Provide user feedback on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class AnimalRecord {
  final String id;
  final String species;
  final DateTime detectedAt;
  final double confidence;
  final String healthStatus;
  final String notes;
  final Map<String, double> boundingBox;

  AnimalRecord({
    required this.id,
    required this.species,
    required this.detectedAt,
    required this.confidence,
    required this.healthStatus,
    required this.notes,
    required this.boundingBox,
  });

  factory AnimalRecord.fromMap(Map<String, dynamic> map) {
    return AnimalRecord(
      id: map['id'] ?? 'unknown',
      species: map['species'] ?? 'unknown species',
      detectedAt: DateTime.tryParse(map['detectedAt'] ?? '') ?? DateTime.now(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      healthStatus: map['healthStatus'] ?? 'unknown',
      notes: map['notes'] ?? '',
      boundingBox: Map<String, double>.from(map['boundingBox'] ?? {}),
    );
  }
}
