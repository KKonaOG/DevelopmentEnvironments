import 'dart:io';
import 'package:args/args.dart';
import 'package:usedc/usedc.dart';

const REPO_URL = "https://github.com/KKonaOG/DevelopmentEnvironments.git";

void main(List<String> arguments) {
  if (!Platform.isLinux && !Platform.isWindows) {
    print("Support is only currently available (loosely) for Linux and Windows.");
    exit(1);
  }

  final mainArgParser = ArgParser();
  final pushArgParser = mainArgParser.addCommand("push");
  final pullArgParser = mainArgParser.addCommand("pull");

  mainArgParser
    ..addFlag("setup", help: "Sets up this executable to perform work and adds it to the PATH", negatable: false)
    ..addFlag("open", abbr: "o", help: 'Open the Devcontainer in the current working directory', negatable: false)
    ..addFlag("list", help: "List available Devcontainers", negatable: false)
    ..addFlag("sync", help: 'Syncs the local Devcontainer repository with the one stored in git', negatable: false)
    ..addFlag("help", abbr: "h", help: "Displays the help for the UseDC command", negatable: false);

  pullArgParser
    ..addFlag("force", help: "Forces the pull operation to overwrite file in the local working directory.", negatable: false)
    ..addOption("name", help: "The name of the Devcontainer to pull from the Devcontainer Repository.", mandatory: true);

  pushArgParser
    ..addFlag("force", help: "Forces the push operation to overwrite file in the local working directory.", negatable: false)
    ..addOption("name", help: "The name of the Devcontainer to push from the Devcontainer Repository.", mandatory: true);

  final mainArguments = mainArgParser.parse(arguments);

  if (mainArguments["setup"]) {
    print("Checking for Git installation...");

    // Check if Git is installed
    ProcessResult gitCheck = Process.runSync('git', ['--version']);
    if (gitCheck.exitCode != 0) {
      print("Error: Git is not installed. Please install Git and try again.");
      exit(1);
    }

    print("Git is installed. Proceeding to pull the repository...");

    String? homeDir = Platform.isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
    String targetDir = '$homeDir/.DevelopmentEnvironments';

    ProcessResult gitClone = Process.runSync('git', ['clone', REPO_URL, targetDir]);
    if (gitClone.exitCode != 0) {
      print("Git failed to clone the repository.");
      print(gitClone.stderr);
      exit(1);
    }

    print("Development Environments succesfully cloned to $targetDir");
    


    String devContainerRepo = '$targetDir/Devcontainers';
    String scriptDir = Directory(Platform.script.toFilePath(windows: Platform.isWindows)).parent.path;

    // You can also recommend updating the user's shell configuration (e.g., ~/.bashrc)
    print("================ SUCCESS ================ ");
    print("================ Linux ================ ");
    print("Please add the following lines to your shell config file (e.g., ~/.bashrc, ~/.zshrc):");
    print('export DEVCONTAINER_REPOSITORY=$devContainerRepo');
    print('export PATH=\$PATH:$scriptDir');
    print("================ Windows ================ ");
    print("Please add the add the path to your user environment variables. You can do this manually, or use the following Powershell command: ");
    print('Set-ItemProperty -Path "HKCU:\\Environment" -Name "DEVCONTAINER_REPOSITORY" -Value "$devContainerRepo"');

    return;
  }

  if (mainArguments["help"]) {
    print(mainArgParser.usage);
    print("Pull (i.e: usedc pull [options]): ");
    print(pullArgParser.usage);
    print("Push (i.e usedc push [options]): ");
    print(pushArgParser.usage);
  }

  if (mainArguments["list"]) {
    List<String> names = getNames();
    print(names);
    return;
  }

  if (mainArguments["sync"]) {
    doSync();
    return;
  }


  bool noCommand = mainArguments.command == null;
  bool isPull = mainArguments.command != null && mainArguments.command!.name == "pull";
  bool isPush = mainArguments.command != null && mainArguments.command!.name == "push";

  if (mainArguments["open"] && isPush) {
    print("You cannot push and open at the same time. Did you mean to pull and open?");
  }

  if (mainArguments["open"] && (isPull || noCommand)) {
    doPull(mainArguments.command!["name"], mainArguments.command!["force"]);
    doOpen();
  }

  if (!mainArguments["open"] && isPull) {
    doPull(mainArguments.command!["name"], mainArguments.command!["force"]);
  }

  if (isPush) {
    doPush(mainArguments.command!["name"], mainArguments.command!["force"]);
  }
}

bool doOpen() {
  // Run the command devcontainer --open in the current directory

  // Verify a .devcontainer folder exits in current location
  String targetDirectory = "${Directory.current.path}/.devcontainer";

  // Check if .devcontainers exists
  if (!Directory(targetDirectory).existsSync()) {
      print("There is no devcontainer to open in the current directory. Try UseDC --pull [NAME]");
      return false;
  }

  ProcessResult devcontainerOpen = Process.runSync("devcontainer", ["--open"]);
  if (devcontainerOpen.exitCode != 0) {
    print("Error: Issue running devcontainer --open");
    print(devcontainerOpen.stderr);
    return false;
  }

  return true;
}

bool doPull(String name, bool force) {
  String devContainerRepo = getRepositoryLocation();
  final List<String> names = getNames();

  if (!names.contains(name)) {
    print("$name is not a valid container name.");
    return false;
  }

  Directory sourceDirectory = Directory(devContainerRepo + name);
  Directory targetDirectory = Directory("${Directory.current.path}/.devcontainer");

  // Check if .devcontainers exists
  if (targetDirectory.existsSync() && force == false) {
      print("Devcontainer directory already exists, please use --force to allow an overwrite of the existing folder.");
      return false;
  } else {
    targetDirectory.createSync(recursive: true);
  }

  // Copy the folder: devContainerRepo/name to target_directory/.devcontainer
  doCopy(sourceDirectory, targetDirectory);
  return true;
}

bool doPush(String name, bool force) {
  String devContainerRepo = getRepositoryLocation();
  final List<String> names = getNames();

  if (names.contains(name) && force == false) {
    print("$name already exists. Use --force to overwrite the Devcontainer in the devcontainer repository.");
    return false;
  }

  Directory sourceDirectory= Directory("${Directory.current.path}/.devcontainer");
  Directory targetDirectory = Directory(devContainerRepo + name);

  // Check if .devcontainers exists
  if (!sourceDirectory.existsSync()) {
      print("There is no devcontainer in the current directory.");
      return false;
  }


  // Wipe existing DevcontainerRepo container
  if (targetDirectory.existsSync()) {
    targetDirectory.deleteSync(recursive: true);
    targetDirectory.createSync(recursive: true);
  }

  // Copy source_directory to target_directory
  doCopy(sourceDirectory, targetDirectory);
  return true;
}

bool doSync() {
  String devContainerRepo = getRepositoryLocation();

  // Check if there are modified, created, or deleted files according to git
  ProcessResult gitChanged = Process.runSync("git", ["-C", devContainerRepo, "ls-files", "-o", "-m", "-d"]);
  if (gitChanged.exitCode != 0) {
    print("Issue obtaining list of changed files from git");
    print(gitChanged.stderr);
    return false;
  }

  if (gitChanged.stdout.length == 0) {
    print("No local changes detected");
  } else {
    print("Local repo modified, commiting changes to the repository and pushing to git.");
    print("Changes: ");
    print(gitChanged.stdout);

    ProcessResult gitAdd = Process.runSync("git", ["-C", devContainerRepo, "add", "."]);
    if (gitAdd.exitCode != 0) {
      print("Could not add changed repository files to a commit. Aborting sync!");
      print(gitAdd.stderr);
      return false;
    }

    ProcessResult gitCommit = Process.runSync("git", ["-C", devContainerRepo, "commit", "-m 'UseDC Sync'"]);
    if (gitCommit.exitCode != 0) {
      print("Could not commit repository files. Aborting sync!");
      print(gitCommit.stderr);
      return false;
    }
  }

  // Run Git Push
  print("Pushing any pending changes...");
  ProcessResult gitPush = Process.runSync("git", ["-C", devContainerRepo, "push"]);
  if (gitPush.exitCode != 0) {
    print("Could not push to git. The repository is now in an unstable state. Please resolve manually.");
    print(gitPush.stderr);
    return false;
  }


  // Run Git Pull
  print("Pulling any pending changes...");
  ProcessResult gitPull = Process.runSync("git", ["-C", devContainerRepo, "push"]);
  if (gitPull.exitCode != 0) {
    print("Could not pull from git. The repository is now in an unstable state. Please resolve manually.");
    print(gitPull.stderr);
    return false;
  }

  print("Sync Complete!");
  return true;
}