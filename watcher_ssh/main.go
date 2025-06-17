package main

import (
	"bufio"
	"encoding/csv"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"

	"github.com/fsnotify/fsnotify"
)

type Status string

const (
	NotConnected      Status = "未接続        "
	PublicKeyAccepted Status = "公開鍵認証    "
	PasswordAccepted  Status = "パスワード認証"
	Failed            Status = "認証失敗      "
)

func loadUserStatusFromCSV(csvPath string) (map[string]Status, error) {
	file, err := os.Open(csvPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open CSV file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.FieldsPerRecord = -1 // Allow variable number of fields

	userStatus := make(map[string]Status)

	for {
		record, err := reader.Read()
		if err != nil {
			if err.Error() == "EOF" {
				break
			}
			continue // Skip invalid lines
		}

		if len(record) > 0 && record[0] != "" {
			userID := strings.TrimSpace(record[0])
			// Add both password and key entries for each user
			userStatus[userID+"pass"] = NotConnected
			userStatus[userID+"key"] = NotConnected
		}
	}

	return userStatus, nil
}

func main() {
	filePath := "/watcher-ssh/ssh-logs/auth.log"
	csvPath := "/watcher-ssh/ssh-server/data/students.csv"

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		fmt.Println(err)
		return
	}
	defer watcher.Close()

	userStatus, err := loadUserStatusFromCSV(csvPath)
	if err != nil {
		fmt.Printf("Error loading users from CSV: %v\n", err)
		return
	}

	var mutex sync.Mutex

	searchInFile(filePath, userStatus, &mutex)

	done := make(chan bool)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				if event.Op&fsnotify.Write == fsnotify.Write {
					searchInFile(filePath, userStatus, &mutex)
					printTable(userStatus, &mutex)
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				fmt.Println("error:", err)
			}
		}
	}()

	err = watcher.Add(filePath)
	if err != nil {
		fmt.Println(err)
		return
	}

	printTable(userStatus, &mutex)
	<-done
}

func searchInFile(filePath string, userStatus map[string]Status, mutex *sync.Mutex) {
	file, err := os.Open(filePath)
	if err != nil {
		fmt.Println("error opening file:", err)
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		userName := searchUserNameIP(line)
		if userName == "" {
			continue
		}

		if _, ok := userStatus[userName]; !ok {
			continue
		}

		if strings.Contains(line, "Accepted password") {
			mutex.Lock()
			userStatus[userName] = PasswordAccepted
			mutex.Unlock()
		}

		if strings.Contains(line, "Accepted publickey") {
			mutex.Lock()
			userStatus[userName] = PublicKeyAccepted
			mutex.Unlock()
		}

		if strings.Contains(line, "Failed") || (strings.Contains(line, "[preauth]") && strings.Contains(line, "Connection closed")) {
			mutex.Lock()
			userStatus[userName] = Failed
			mutex.Unlock()
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Println("error scanning file:", err)
	}
}

func searchUserNameIP(line string) string {
	userNamePattern := regexp.MustCompile(`(\d{3}\w\d{4}\w{3,4}|\d{8}\w{3,4})`)
	// userNamePattern := regexp.MustCompile(`(\d{8}\w{3,4})`)
	// ipAddrPattern := regexp.MustCompile(`from(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

	userNameMatch := userNamePattern.FindStringSubmatch(line)
	// ipAddrMatch := ipAddrPattern.FindStringSubmatch(line)

	if len(userNameMatch) > 1 {
		return userNameMatch[1]
	}
	return ""
}

func printTable(userStatus map[string]Status, mutex *sync.Mutex) {
	mutex.Lock()
	defer mutex.Unlock()

	var userList []string
	for user := range userStatus {
		userList = append(userList, user)
	}
	sort.Strings(userList)

	numColumns := 5
	numRows := (len(userList) + numColumns - 1) / numColumns
	width := 12

	fmt.Print("\033[H\033[2J")

	for row := 0; row < numRows; row++ {
		for col := 0; col < numColumns; col++ {
			index := row + col*numRows
			if index < len(userList) {
				user := userList[index]
				status := userStatus[user]
				user = strings.Replace(user, "key", "key ", 1)
				// user = strings.Replace(user, "pass", "", 1)
				text := fmt.Sprintf(("%s : %s"), user, status)
				switch status {
				case NotConnected:
					fmt.Printf("| %-*s |", width, text)
				case PublicKeyAccepted:
					fmt.Printf("\033[42m| %-*s |\033[0m", width, text)
				case PasswordAccepted:
					fmt.Printf("\033[42m| %-*s |\033[0m", width, text)
				case Failed:
					fmt.Printf("\033[41m| %-*s |\033[0m", width, text)
				default:
					fmt.Printf("\033[47m| %-*s |\033[0m", width, text)
				}
			}
		}
		fmt.Println()
	}
}
