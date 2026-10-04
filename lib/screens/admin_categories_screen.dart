import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/api_provider.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure we have the latest categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(
        context,
        listen: false,
      ).fetchMemories(); // This triggers internal fetch of categories
    });
  }

  Future<void> _addCategory(String name) async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${api.baseUrl}/admin/expense_categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.currentSessionToken}',
        },
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        // Trigger a fresh fetch
        await api.fetchMemories();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Category added')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    setState(() => isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('${api.baseUrl}/admin/expense_categories/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.currentSessionToken}',
        },
      );
      if (response.statusCode == 200) {
        await api.fetchMemories();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Category deleted')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _editCategory(int id, String newName) async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    setState(() => isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('${api.baseUrl}/admin/expense_categories/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.currentSessionToken}',
        },
        body: jsonEncode({'name': newName}),
      );
      if (response.statusCode == 200) {
        await api.fetchMemories();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Category updated')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Default Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  _addCategory(text);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(int id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Default Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && text != currentName) {
                  Navigator.pop(context);
                  _editCategory(id, text);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Default Categories'),
        backgroundColor: Colors.deepPurple.shade100,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Consumer<ApiProvider>(
        builder: (context, api, child) {
          final defaultCategories = api.expenseCategories
              .where((c) => c['user_id'] == null)
              .toList();

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (defaultCategories.isEmpty) {
            return const Center(child: Text("No default categories found."));
          }

          return ListView.builder(
            itemCount: defaultCategories.length,
            itemBuilder: (context, index) {
              final cat = defaultCategories[index];
              return ListTile(
                leading: const Icon(Icons.category),
                title: Text(cat['name'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        if (cat['id'] != null) {
                          _showEditDialog(cat['id'], cat['name'] ?? '');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        if (cat['id'] != null) {
                          _deleteCategory(cat['id']);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cannot delete this placeholder category',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
