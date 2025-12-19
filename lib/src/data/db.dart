/// Minimal compile-only DB shim for desktop build.
/// Replace with real sqflite implementation later.
class AppDb {
  static Future<AppDb> open() async => AppDb();

  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return <Map<String, Object?>>[];
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    Object? conflictAlgorithm,
  }) async {
    return 1;
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    Object? conflictAlgorithm,
  }) async {
    return 1;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return 1;
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return <Map<String, Object?>>[];
  }
}
