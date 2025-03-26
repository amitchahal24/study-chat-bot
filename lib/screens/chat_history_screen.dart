import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  final String userId;
  const ChatHistoryScreen({super.key, required this.userId});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final List<Map<String, String>> _chats = [];
  List<Map<String, String>> _filteredChats = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredChats = List.from(_chats);
    _searchController.addListener(_onSearchChanged);
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final chats = await ApiService.get('chats/${widget.userId}');
      setState(() {
        _chats.clear();
        _chats.addAll(chats);
        _filteredChats = List.from(_chats);
      });
      final responseData = jsonDecode(chats[0]);
      print(responseData);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load chats: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats =
          _chats.where((chat) {
            final name = chat['name']!.toLowerCase();
            final date = chat['date']!.toLowerCase();
            return name.contains(query) || date.contains(query);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    PreferredSize? bottomAppBar;
    if (_isSearchBarVisible) {
      bottomAppBar = PreferredSize(
        preferredSize: const Size.fromHeight(48.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by name or date',
            ),
          ),
        ),
      );
    } else {
      bottomAppBar = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
              });
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(onPressed: () {}, icon: Icon(Icons.add)),
        ],
        bottom: bottomAppBar,
      ),
      body: ListView.builder(
        itemCount: _filteredChats.length,
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          return ListTile(
            title: Text(chat['name']!),
            subtitle: Text(chat['date']!),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _chats.removeAt(index);
                });
              },
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}

class ChatSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, String>> chats;
  ChatSearchDelegate({required this.chats});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, '');
      },
      icon: Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Text('');
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Text('');
  }
}