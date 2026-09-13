import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_client.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Fetch all memories the moment the screen loads
    _fetchAllMemories();
  }

  // --- FETCH ALL MEMORIES ---
  Future<void> _fetchAllMemories() async {
    setState(() {
      _isLoading = true; // Turn the loading state on for the progress bar
      _errorMessage = '';
    });

    try {
      final apiUrl = await ApiClient().getWorkingUrl();
      final response = await http.get(Uri.parse('$apiUrl/memories')).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['results'] ?? [];
          if (_searchResults.isEmpty) {
            _errorMessage = 'No memories found. Go record some!';
          }
        });
      } else {
        setState(() => _errorMessage = 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Backend not reachable.');
    } finally {
      setState(() => _isLoading = false); // Turn off the progress bar
    }
  }

  // --- SEMANTIC SEARCH FILTER ---
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    // If the user cleared the search box, just show all memories again
    if (query.isEmpty) {
      return _fetchAllMemories();
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      final apiUrl = await ApiClient().getWorkingUrl();
      final response = await http.get(
        Uri.parse('$apiUrl/search?q=${Uri.encodeComponent(query)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['results'] ?? [];
          if (_searchResults.isEmpty) {
            _errorMessage = 'No matching memories found.';
          }
        });
      } else {
        setState(() => _errorMessage = 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Backend not reachable.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- DELETE FUNCTION ---
  Future<void> _deleteMemory(dynamic id, int index) async {
    try {
      final apiUrl = await ApiClient().getWorkingUrl();
      final response = await http.delete(Uri.parse('$apiUrl/memory/$id'));
      
      if (response.statusCode == 200) {
        setState(() => _searchResults.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory deleted!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend not reachable.')));
    }
  }

  // --- EDIT FUNCTION ---
  Future<void> _editMemory(dynamic id, int index, String currentText) async {
    TextEditingController editController = TextEditingController(text: currentText);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Memory'),
          content: TextField(
            controller: editController,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != currentText) {
                  Navigator.pop(context);
                  try {
                    final apiUrl = await ApiClient().getWorkingUrl();
                    final response = await http.put(
                      Uri.parse('$apiUrl/memory/$id'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'text': newText}),
                    );
                    if (response.statusCode == 200) {
                      setState(() => _searchResults[index]['raw_text'] = newText);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory updated!')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update.')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // --- OPTIONS MENU ---
  void _showOptions(dynamic id, int index, String currentText) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Memory'),
                onTap: () {
                  Navigator.pop(context);
                  _editMemory(id, index, currentText);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Memory'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMemory(id, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          
          // --- SEARCH BAR ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search past memories...',
                    prefixIcon: const Icon(Icons.search),
                    // Clear button that triggers a reset
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchAllMemories(); // Reload the full list
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _performSearch,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Search'),
              ),
            ],
          ),
          
          // --- THIN LOADING BAR ---
          const SizedBox(height: 10),
          if (_isLoading) 
            const LinearProgressIndicator(), // Sleek, thin loading line
          const SizedBox(height: 10),

          // --- RESULTS AREA ---
          if (_errorMessage.isNotEmpty)
            Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  final memoryId = item['id'];
                  final rawText = item['raw_text'] ?? 'Unknown Memory';
                  
                  // Only show similarity score if it exists (i.e., during a search)
                  final similarityScore = item['similarity'];
                  final subtitleText = similarityScore != null 
                    ? 'Similarity: ${(similarityScore * 100).toStringAsFixed(1)}%' 
                    : 'Saved Memory';
                  
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(rawText),
                      subtitle: Text(
                        subtitleText, 
                        style: TextStyle(color: similarityScore != null ? Colors.green : Colors.grey)
                      ),
                      leading: const CircleAvatar(child: Icon(Icons.memory)),
                      trailing: const Icon(Icons.more_vert),
                      onTap: () => _showOptions(memoryId, index, rawText),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}