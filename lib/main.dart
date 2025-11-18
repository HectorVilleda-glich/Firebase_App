import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_config.dart';
import 'firestone_service.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notas con Firebase',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),

      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          return const NotesPage();
        },
      ),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _controller = TextEditingController();
  String _selectedCategory = 'Personal';
  final FirestoneService _service = FirestoneService();

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _service.addNote(text, _selectedCategory);
    _controller.clear();
  }

  Future<void> _editNote(String id, String oldText, String oldCategory) async {
    final ctrl = TextEditingController(text: oldText);
    String selectedCategory = oldCategory;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar nota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Texto')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: const [
                DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                DropdownMenuItem(value: 'Trabajo', child: Text('Trabajo')),
                DropdownMenuItem(value: 'Estudio', child: Text('Estudio')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (v) => selectedCategory = v!,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'text': ctrl.text.trim(),
              'category': selectedCategory,
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null || result['text']!.isEmpty) return;
    await _service.updateNote(id, result['text']!, result['category']!);
  }

  Future<void> _deleteNote(String id) async {
    await _service.deleteNote(id);
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d/$mo/$y $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas con Firebase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Escribe una nota...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: const [
                      DropdownMenuItem(
                          value: 'Personal', child: Text('Personal')),
                      DropdownMenuItem(
                          value: 'Trabajo', child: Text('Trabajo')),
                      DropdownMenuItem(
                          value: 'Estudio', child: Text('Estudio')),
                      DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                    ],
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _addNote, child: const Text('Agregar')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.getNotesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notes = snapshot.data!.docs;
                if (notes.isEmpty) {
                  return const Center(child: Text('Sin notas aún'));
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final doc = notes[i];
                    final text = doc['text'];
                    final category = doc['category'];
                    final createdAt = doc['createdAt'] as Timestamp;

                    return ListTile(
                      title: Text(text,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Categoría: $category\nCreado: ${_formatDate(createdAt)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      onTap: () => _editNote(doc.id, text, category),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteNote(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
