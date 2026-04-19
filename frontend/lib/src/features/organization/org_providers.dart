import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';
import 'package:dio/dio.dart';

// --- Branches Provider ---
final branchesProvider = AsyncNotifierProvider<BranchesNotifier, List<BranchModel>>(
  BranchesNotifier.new,
);

class BranchesNotifier extends AsyncNotifier<List<BranchModel>> {
  @override
  Future<List<BranchModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/branches/');
    final List<dynamic> data = response.data;
    return data.map((json) => BranchModel.fromJson(json)).toList();
  }

  Future<void> addBranch(String name, {String? abbreviation}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/admin/branches/', data: {
        'name': name,
        'abbreviation': abbreviation,
      });
      return build();
    });
  }

  Future<void> updateBranch(int id, String name, {String? abbreviation}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.put('/admin/branches/$id', data: {
        'name': name,
        'abbreviation': abbreviation,
      });
      return build();
    });
  }


  Future<void> deleteBranch(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/branches/$id');
    ref.invalidateSelf();
  }
}

// --- Groups Provider ---
final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/groups/');
    final List<dynamic> data = response.data;
    return data.map((json) => GroupModel.fromJson(json)).toList();
  }

  Future<int> addGroup(String name, {
    String? description,
    String? program,
    int? batch,
    int? branchId,
  }) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.post('/admin/groups/', data: {
      'name': name,
      if (description != null) 'description': description,
      if (program != null) 'program': program,
      if (batch != null) 'batch': batch,
      if (branchId != null) 'branch_id': branchId,
    });
    ref.invalidateSelf();
    return response.data['group_id'];
  }

  Future<void> updateGroup(int id, String name, {
    String? description,
    String? program,
    int? batch,
    int? branchId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.put('/admin/groups/$id', data: {
        'name': name,
        'description': description,
        'program': program,
        'batch': batch,
        'branch_id': branchId,
      });
      return build();
    });
  }

  Future<void> deleteGroup(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/groups/$id');
    ref.invalidateSelf();
  }
}

// --- Students Provider ---
final studentsProvider = AsyncNotifierProvider<StudentsNotifier, List<StudentModel>>(
  StudentsNotifier.new,
);

class StudentsNotifier extends AsyncNotifier<List<StudentModel>> {
  @override
  Future<List<StudentModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/students/');
    final List<dynamic> data = response.data;
    return data.map((json) => StudentModel.fromJson(json)).toList();
  }

  Future<void> addStudent({
    required String rollNumber,
    required String name,
    required int branchId,
    int? batch,
    String? email,
    String program = 'B.Tech',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/admin/students/', data: {
        'student_id': rollNumber,
        'name': name,
        'branch_id': branchId,
        'batch': batch,
        'email': email,
        'program': program,
      });
      return build();
    });
  }

  Future<void> updateStudent({
    required String rollNumber,
    required String name,
    required int branchId,
    int? batch,
    String? email,
    String program = 'B.Tech',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.put('/admin/students/$rollNumber', data: {
        'name': name,
        'branch_id': branchId,
        'batch': batch,
        'email': email,
        'program': program,
      });
      return build();
    });
  }

  Future<void> deleteStudent(String rollNumber) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/students/$rollNumber');
    ref.invalidateSelf();
  }

  Future<Map<String, dynamic>> previewImport(List<int> bytes, String fileName) async {
    final api = ref.read(apiServiceProvider);
    
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await api.post('/admin/students/bulk-upload/preview', data: formData);
    return response.data;
  }

  Future<String> confirmImport(List<Map<String, dynamic>> students) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.post('/admin/students/bulk-upload/confirm', data: students);
    ref.invalidateSelf();
    return response.data['message'];
  }

  Future<void> bulkDeleteStudents(List<String> rollNumbers) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/admin/students/bulk-delete', data: {'student_ids': rollNumbers});
      return build();
    });
  }

  Future<void> bulkUpdateStudents({
    required List<String> rollNumbers,
    int? branchId,
    int? batch,
    String? program,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/admin/students/bulk-update', data: {
        'student_ids': rollNumbers,
        if (branchId != null) 'branch_id': branchId,
        if (batch != null) 'batch': batch,
        if (program != null) 'program': program,
      });
      return build();
    });
  }
}

// --- Student Search Provider ---
final studentSearchProvider = FutureProvider.family<List<StudentModel>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final api = ref.read(apiServiceProvider);
  final response = await api.get('/admin/students/search', queryParameters: {'q': query});
  final List<dynamic> data = response.data;
  return data.map((json) => StudentModel.fromJson(json)).toList();
});

// --- Group Members List Provider ---
final groupMembersProvider = FutureProvider.family<List<StudentModel>, int>((ref, groupId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/admin/groups/$groupId/students');
  final List<dynamic> data = response.data;
  return data.map((json) => StudentModel.fromJson(json)).toList();
});

// --- Group Membership Actions Controller ---
class GroupMembershipController {
  final Ref ref;
  GroupMembershipController(this.ref);

  Future<void> addStudent(int groupId, String rollNumber) async {
    final api = ref.read(apiServiceProvider);
    await api.post('/admin/group-students/', data: {
      'group_id': groupId,
      'student_id': rollNumber,
    });
    ref.invalidate(groupMembersProvider(groupId));
    ref.invalidate(groupsProvider);
  }

  Future<void> bulkAdd({required int targetGroupId, required List<String> studentIds}) async {
    final api = ref.read(apiServiceProvider);
    await api.post('/admin/group-students/bulk-add', data: {
      'target_group_id': targetGroupId,
      'student_ids': studentIds,
    });
    ref.invalidate(groupMembersProvider(targetGroupId));
    ref.invalidate(groupsProvider);
  }

  Future<void> bulkRemove({required int targetGroupId, required List<String> studentIds}) async {
    final api = ref.read(apiServiceProvider);
    await api.post('/admin/group-students/bulk-remove', data: {
      'target_group_id': targetGroupId,
      'student_ids': studentIds,
    });
    ref.invalidate(groupMembersProvider(targetGroupId));
    ref.invalidate(groupsProvider);
  }

  Future<void> removeStudent(int groupId, String rollNumber) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/group-students/$groupId/$rollNumber');
    ref.invalidate(groupMembersProvider(groupId));
    ref.invalidate(groupsProvider);
  }
}

final groupMembershipControllerProvider = Provider((ref) => GroupMembershipController(ref));
