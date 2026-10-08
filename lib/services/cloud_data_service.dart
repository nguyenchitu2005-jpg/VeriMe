import 'package:cloud_firestore/cloud_firestore.dart';

import '../face/face_math.dart';

/// Dữ liệu tài khoản lưu trên Firebase để dùng lại trên máy khác.
///
/// Hiện lưu vector khuôn mặt: `users/{uid} = {faceEmbedding: [512 số], faceUpdatedAt}`.
/// Chỉ chủ tài khoản đọc/ghi được (xem firestore.rules). Không lưu ảnh khuôn mặt.
///
/// Vân tay KHÔNG lưu lên mạng được: Android giữ dữ liệu vân tay trong phần cứng bảo mật
/// của từng máy và không cho ứng dụng đọc, nên mỗi máy phải bật vân tay riêng.
abstract class CloudDataService {
  /// Vector khuôn mặt đã lưu trong tài khoản; null nếu chưa có.
  Future<List<double>?> loadFaceEmbedding(String uid);

  Future<void> saveFaceEmbedding(String uid, List<double> embedding);

  Future<void> deleteFaceEmbedding(String uid);
}

/// Cài đặt bằng Cloud Firestore.
class FirestoreCloudDataService extends CloudDataService {
  FirestoreCloudDataService([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<List<double>?> loadFaceEmbedding(String uid) async {
    final snap = await _user(uid).get().timeout(const Duration(seconds: 8));
    final list = snap.data()?['faceEmbedding'] as List?;
    final embedding = list?.map((e) => (e as num).toDouble()).toList();
    // Vector của model cũ (khác số chiều) không dùng được: coi như chưa có, máy này đăng ký
    // lại thì bản mới sẽ ghi đè lên.
    return embedding != null && isCurrentFaceEmbedding(embedding)
        ? embedding
        : null;
  }

  @override
  Future<void> saveFaceEmbedding(String uid, List<double> embedding) =>
      _user(uid).set({
        'faceEmbedding': embedding,
        'faceUpdatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteFaceEmbedding(String uid) => _user(uid).delete();
}
