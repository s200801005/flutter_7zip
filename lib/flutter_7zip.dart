import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'src/flutter_7zip_bindings_generated.dart';

const String _libName = 'flutter_7zip';

/// The dynamic library in which the symbols for [Flutter7zipBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final Flutter7zipBindings _bindings = Flutter7zipBindings(_dylib);

final _nativeFreeDataFunc = _dylib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('freeReadData');

class SZArchive {
  final Pointer<Void> _archive;

  SZArchive._(this._archive);

  final _pointers = <Pointer>[];

  void dispose() {
    _bindings.closeArchive(_archive);
    for (var p in _pointers) {
      malloc.free(p);
    }
  }

  int get numFiles => _bindings.getArchiveFileCount(_archive);

  ArchiveFile getFile(int index) {
    final cFile = _bindings.getArchiveFile(_archive, index);
    final name = cFile.name.cast<Utf16>().toDartString();
    final size = cFile.size;
    final crc32 = cFile.crc32;
    final isDirectory = cFile.is_dir == 1;
    var time = DateTime(0);
    if (cFile.cTime != 0) {
      time = DateTime.fromMillisecondsSinceEpoch(cFile.cTime * 1000);
    } else if (cFile.ntfsTime != 0) {
      time = DateTime.utc(1601, 1, 1).add(Duration(microseconds: cFile.ntfsTime ~/ 10));
    }
    _bindings.freeArchiveFile(cFile);
    return ArchiveFile(name, size, crc32, time, isDirectory);
  }

  Uint8List extractFile(int index) {
    var archive = getFile(index);
    var data = _bindings.readArchiveFile(_archive, index).cast<Uint8>();
    if (data == nullptr) {
      throw Exception('Failed to read file from archive.');
    }
    return data.asTypedList(archive.size, finalizer: _nativeFreeDataFunc);
  }

  void extractToFile(int index, String path) {
    var p = path.toNativeUtf8();
    final status = _bindings.extractArchiveToFile(_archive, index, p.cast());
    malloc.free(p);
    if (status != ArchiveStatus.kArchiveOK) {
      throw Exception('Failed to extract file to $path.');
    }
  }

  static SZArchive open(String path) {
    var p = path.toNativeUtf8();
    final archive = _bindings.openArchive(p.cast());
    var status = _bindings.checkArchiveStatus(archive);
    if (status != ArchiveStatus.kArchiveOK) {
      malloc.free(p);
      throw Exception('Failed to open archive.');
    }
    var a = SZArchive._(archive);
    a._pointers.add(p);
    return a;
  }
}

class ArchiveFile {
  final String name;
  final int size;
  final int crc32;
  final DateTime time;
  final bool isDirectory;

  const ArchiveFile(this.name, this.size, this.crc32, this.time, this.isDirectory);
}