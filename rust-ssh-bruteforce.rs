use std::fs::File;
use std::io::{self, BufRead};
use std::net::TcpStream;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;
use structopt::StructOpt;

#[derive(StructOpt)]
struct Config {
    #[structopt(short, long)]
    host: String,
    
    #[structopt(short, long, default_value = "22")]
    port: u16,
    
    #[structopt(short, long)]
    user: String,
    
    #[structopt(short, long)]
    wordlist: String,
    
    #[structopt(short, long, default_value = "4")]
    threads: usize,
    
    #[structopt(short, long, default_value = "10")]
    timeout: u64,
}

fn try_ssh_login(host: &str, port: u16, username: &str, password: &str, timeout: u64) -> bool {
    let addr = format!("{}:{}", host, port);
    
    match TcpStream::connect_timeout(&addr.parse().unwrap(), Duration::from_secs(timeout)) {
        Ok(mut stream) => {
            // Simple SSH protocol check
            let mut buffer = [0; 1024];
            match stream.read(&mut buffer) {
                Ok(_) => {
                    // In a real implementation, you'd use an SSH library
                    // This is a simplified version
                    let response = String::from_utf8_lossy(&buffer);
                    if response.contains("SSH") {
                        return true; // Simplified for demo
                    }
                }
                Err(_) => return false,
            }
        }
        Err(_) => return false,
    }
    
    false
}

fn worker(config: Config, passwords: Vec<String>, sender: mpsc::Sender<String>) {
    for password in passwords {
        if try_ssh_login(&config.host, config.port, &config.user, &password, config.timeout) {
            sender.send(format!("[SUCCESS] {}:{}", config.user, password)).unwrap();
            return;
        }
    }
}

fn main() -> io::Result<()> {
    let config = Config::from_args();
    
    let file = File::open(&config.wordlist)?;
    let reader = io::BufReader::new(file);
    let passwords: Vec<String> = reader.lines().filter_map(Result::ok).collect();
    
    let (sender, receiver) = mpsc::channel();
    let chunk_size = passwords.len() / config.threads;
    
    let mut handles = vec![];
    
    for i in 0..config.threads {
        let start = i * chunk_size;
        let end = if i == config.threads - 1 {
            passwords.len()
        } else {
            (i + 1) * chunk_size
        };
        
        let chunk = passwords[start..end].to_vec();
        let sender = sender.clone();
        let config = config.clone();
        
        let handle = thread::spawn(move || {
            worker(config, chunk, sender);
        });
        
        handles.push(handle);
    }
    
    drop(sender);
    
    for result in receiver {
        println!("{}", result);
        std::process::exit(0);
    }
    
    for handle in handles {
        handle.join().unwrap();
    }
    
    println!("No valid credentials found");
    Ok(())
}
