import 'package:flutter/material.dart';

import '../Helpers/Funcs.dart';


class IconSelectorScreen extends StatefulWidget {
  const IconSelectorScreen({super.key});

  @override
  State<IconSelectorScreen> createState() => _IconSelectorScreenState();
}

class _IconSelectorScreenState extends State<IconSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, IconData> _filteredIcons = {};
  String? _selectedIconName;

  @override
  void initState() {
    super.initState();
    _filteredIcons = Map.from(Func.allIcons);
  }

  void _filterIcons(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredIcons = Map.from(Func.allIcons);
      } else {
        _filteredIcons = Map.fromEntries(
          Func.allIcons.entries.where((entry) => entry.key.toLowerCase().contains(query.toLowerCase())),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select an Icon'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Icons',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterIcons,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _filteredIcons.length,
              itemBuilder: (context, index) {
                final iconName = _filteredIcons.keys.elementAt(index);
                final iconData = _filteredIcons.values.elementAt(index);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIconName = iconName;
                    });
                  },
                  child: Card(
                    color: _selectedIconName ==  iconName ? Colors.white12 : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 4,
                      children: [
                        Icon(iconData, size: 30),
                        Text(
                          iconName,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIconName != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pop(context, _selectedIconName); // Return selected icon name
              },
              tooltip: 'Confirm Selection',
              child: Icon(Icons.check),
            )
          : null,
    );
  }
}
