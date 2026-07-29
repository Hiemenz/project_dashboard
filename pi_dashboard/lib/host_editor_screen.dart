import 'package:flutter/material.dart';

import 'models.dart';

class HostEditorScreen extends StatefulWidget {
  final PiHost? existing;
  const HostEditorScreen({super.key, this.existing});

  @override
  State<HostEditorScreen> createState() => _HostEditorScreenState();
}

class _HostEditorScreenState extends State<HostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _baseUrl = TextEditingController(
      text: widget.existing?.baseUrl ?? 'http://100.',
    );
    _token = TextEditingController(text: widget.existing?.token ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _token.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.of(context).pop(
      PiHost(
        id: id,
        name: _name.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        token: _token.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Pi' : 'Edit Pi'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                labelText: 'Agent URL',
                hintText: 'http://100.x.x.x:8765',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return 'Invalid URL';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _token,
              decoration: const InputDecoration(labelText: 'Auth token'),
              obscureText: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Tip: use the Tailscale IP of the Pi (100.x.x.x) so this '
              'works from anywhere without opening ports.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
