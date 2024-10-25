import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality

class EngagePage extends StatelessWidget {
  final List<VeterinaryExpert> experts = [
    VeterinaryExpert(name: 'Dr. Johnson', phone: '+23767567890', area: 'Bamenda'),
    VeterinaryExpert(name: 'Dr. Robert Wilson', phone: '+23767654321', area: 'Santa'),
    VeterinaryExpert(name: 'Dr. Emily Davis', phone: '+23769334455', area: 'Kumbo'),
    VeterinaryExpert(name: 'Dr. James Miller', phone: '+2373445566', area: 'Limbe'),
    VeterinaryExpert(name: 'Dr. Olivia Brown', phone: '+23766456677', area: 'Tiko'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veterinary Experts'),
        backgroundColor: const Color.fromARGB(255, 159, 234, 191), // Green color for the app bar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: experts.length,
          itemBuilder: (context, index) {
            final expert = experts[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expert.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Area of Operation: ${expert.area}'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phone: ${expert.phone}'),
                        ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: expert.phone)); // Copy to clipboard
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${expert.phone} copied to clipboard!'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 159, 234, 191), // Green button
                          ),
                          child: const Text('Contact'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class VeterinaryExpert {
  final String name;
  final String phone;
  final String area;

  VeterinaryExpert({required this.name, required this.phone, required this.area});
}
