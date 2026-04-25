import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CloudService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> uploadPdf(File file, {String folder = 'Uncategorized'}) async {
    if (currentUser == null) return null;

    try {
      String fileName = file.path.split(Platform.pathSeparator).last;
      Reference ref = _storage
          .ref()
          .child('users/${currentUser!.uid}/pdfs/$fileName');
      
      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();
      
      await _saveMetadata(fileName, downloadUrl, folder: folder);
      
      return downloadUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  Future<void> _saveMetadata(String name, String url, {String folder = 'Uncategorized'}) async {
    if (currentUser == null) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('pdfs')
        .doc(name) 
        .set({
      'name': name,
      'url': url,
      'folder': folder,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMetadata(String name, {String? folder}) async {
    if (currentUser == null) return;
    
    Map<String, dynamic> data = {};
    if (folder != null) data['folder'] = folder;
    
    if (data.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('pdfs')
        .doc(name)
        .update(data);
  }

  Stream<QuerySnapshot> getCloudPdfsStream() {
    if (currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('pdfs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> syncToCloud(List<File> files) async {
    if (currentUser == null) return;
    for (var file in files) {
      await uploadPdf(file);
    }
  }

  Future<void> deleteFromCloud(String fileName) async {
    if (currentUser == null) return;

    try {
      // Delete from Storage
      await _storage
          .ref()
          .child('users/${currentUser!.uid}/pdfs/$fileName')
          .delete();
      
      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('pdfs')
          .doc(fileName)
          .delete();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }
}
