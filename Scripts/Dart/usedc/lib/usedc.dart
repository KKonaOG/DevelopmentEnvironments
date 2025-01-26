import 'dart:io';

bool isConfigured() {
  String? devContainerRepo = Platform.environment['DEVCONTAINER_REPOSITORY'];
  if (devContainerRepo == null) {
    return false;
  }

  return true;
}

String getRepositoryLocation() {
  if (!isConfigured()) {
    throw("UseDC needs to be setup. Please run UseDC --setup");
  }

  String devContainerRepo = Platform.environment['DEVCONTAINER_REPOSITORY']!;
  if (!devContainerRepo.endsWith("/")) {
    devContainerRepo = "$devContainerRepo/";
  }

  return devContainerRepo;
}


List<String> getNames() {
    String? devContainerRepo = Platform.environment['DEVCONTAINER_REPOSITORY'];
    if (devContainerRepo == null) {
      print("UseDC has not been setup for this machine. Please run usedc --setup");
      return [];
    }

    Directory devContainerDir = Directory(devContainerRepo);
    if (!devContainerDir.existsSync()) {
      print("Error: Container Directory does not exist!");
      return [];
    }


  final files = devContainerDir.listSync(recursive: true).whereType<File>().where((element) => element.uri.pathSegments.last == "devcontainer.json").toList();
  final List<String> names = [];
  
    for (var element in files) {
      String name = element.uri.path;
      
      // Remove $DEVCONTAINER_REPOSITORY
      // Remove devcontainer.json

      name = name.replaceFirst(devContainerRepo, '');
      name = name.replaceFirst('devcontainer.json', '');

      if (name.endsWith("/")) {
        name = name.substring(0, name.length-1);
      }

      if (name.startsWith("/")) {
        name = name.substring(1, name.length);
      }

      names.add(name);
    }

    return names;
}

bool doCopy(Directory sourceDirectory, Directory targetDirectory) {
  if (sourceDirectory.existsSync()) {
    sourceDirectory.listSync(recursive: true).forEach((entity) {
      final targetPath = targetDirectory.path + entity.uri.path.replaceFirst(sourceDirectory.path, '');
      final targetEntity = FileSystemEntity.isDirectorySync(entity.path) ? Directory(targetPath) : File(targetPath);
      if (entity is Directory) {
        (targetEntity as Directory).createSync(recursive: true);
      }
      if (entity is File) {
        (targetEntity as File).createSync(recursive: true);
        entity.copySync(targetPath);
      }
    });

    return true;
  } else {
    throw("Source Location does not exist");
  }
}