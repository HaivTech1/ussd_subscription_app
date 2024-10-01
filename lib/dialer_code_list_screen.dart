import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'edit_dialer_code.dart'; 
import 'create_code_dialer.dart'; 

class DialerCodeListScreen extends StatefulWidget {
  @override
  _DialerCodeListScreenState createState() => _DialerCodeListScreenState();
}

class _DialerCodeListScreenState extends State<DialerCodeListScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _dialerCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDialerCodes();
  }

  Future<void> _fetchDialerCodes() async {
    try {
      var codes = await _apiService.fetchDialers();
      setState(() {
        _dialerCodes = codes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDialerCode(String id, int index) async {
    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      await _apiService.deleteDialer(id);
      setState(() {
        _dialerCodes.removeAt(index);
      });
    }
  }

  Future<void> _editDialerCode(Map<String, dynamic> dialer) async {
    bool? isUpdated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDialerCodeScreen(dialer: dialer),
      ),
    );

    if (isUpdated == true) {
      // Re-fetch the dialer codes to reflect the changes
      _fetchDialerCodes();
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirm Deletion'),
              content:
                  Text('Are you sure you want to delete this dialer code?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> _confirmDeleteAllDialers() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirm Delete All'),
              content:
                  Text('Are you sure you want to delete all dialer codes?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Delete All'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dialer Codes',  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () async {
              bool confirm = await _confirmDeleteAllDialers();
              if (confirm) {
                await _apiService.deleteAllDialers();
                setState(() {
                  _dialerCodes.clear();
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _dialerCodes.isNotEmpty
              ? ListView.builder(
                  itemCount: _dialerCodes.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      elevation: 4,
                      child: ListTile(
                        title: Text(
                          '${_dialerCodes[index]['code']}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            Text('${_dialerCodes[index]['type']} - ${_dialerCodes[index]['plan']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange, size: 18),
                              onPressed: () =>
                                  _editDialerCode(_dialerCodes[index]),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => _deleteDialerCode(
                                  _dialerCodes[index]['id'], index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Center(child: Text('No dialer codes found')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create',
        backgroundColor: Colors.blue,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateCodeDialerScreen(),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
