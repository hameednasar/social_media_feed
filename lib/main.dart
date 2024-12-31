import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabase {
  Future<List<Map<String, dynamic>>> readData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('posts') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  Future<void> writeData(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('posts', jsonEncode(data));
  }

  Future<void> addPost(Map<String, dynamic> post) async {
    final data = await readData();
    data.add(post);
    await writeData(data);
  }

  Future<void> updatePost(int index, Map<String, dynamic> updatedPost) async {
    final data = await readData();
    data[index] = updatedPost;
    await writeData(data);
  }

  Future<void> deletePost(int index) async {
    final data = await readData();
    data.removeAt(index);
    await writeData(data);
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FeedScreen(),
    );
  }
}

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final LocalDatabase db = LocalDatabase();
  List<Map<String, dynamic>> posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final data = await db.readData();
    setState(() {
      posts = data;
    });
  }

  Future<void> _deletePost(int index) async {
    await db.deletePost(index);
    _loadPosts();
  }

  Future<void> _downloadImage(String imagePath) async {
    // Simulate a download and show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Image downloaded: $imagePath")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Social Media Feed"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UploadScreen()),
              ).then((value) => _loadPosts());
            },
          ),
        ],
      ),
      body: posts.isEmpty
          ? Center(child: Text("No posts available."))
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  child: ListTile(
                    leading: post['imagePath'] != null
                        ? GestureDetector(
                            onLongPress: () =>
                                _downloadImage(post['imagePath']),
                            child: Image.file(File(post['imagePath'])),
                          )
                        : null,
                    title: Text(post['title']),
                    subtitle: Text(post['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UploadScreen(
                                  isEditing: true,
                                  post: post,
                                  index: index,
                                ),
                              ),
                            ).then((value) => _loadPosts());
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deletePost(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? post;
  final int? index;

  UploadScreen({this.isEditing = false, this.post, this.index});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final LocalDatabase db = LocalDatabase();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.post != null) {
      titleController.text = widget.post!['title'];
      descriptionController.text = widget.post!['description'];
      selectedImage = widget.post!['imagePath'] != null
          ? File(widget.post!['imagePath'])
          : null;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _savePost() async {
    final newPost = {
      'title': titleController.text,
      'description': descriptionController.text,
      'imagePath': selectedImage?.path,
    };

    if (widget.isEditing) {
      await db.updatePost(widget.index!, newPost);
    } else {
      await db.addPost(newPost);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? "Edit Post" : "New Post")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 10),
            selectedImage != null
                ? Image.file(selectedImage!)
                : Text("No image selected."),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text("Pick Image"),
            ),
            ElevatedButton(
              onPressed: _savePost,
              child: Text(widget.isEditing ? "Update Post" : "Save Post"),
            ),
          ],
        ),
      ),
    );
  }
}
