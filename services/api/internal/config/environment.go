package config

import (
	"fmt"
	"net/mail"
	"os"
	"strconv"
	"strings"
)

func isMailbox(value string) bool {
	address, err := mail.ParseAddress(value)
	return err == nil && address.Name == "" && address.Address == value
}

func readPort(key string, fallback int) (string, error) {
	value, err := readInt(key, fallback, 1, 65535)
	if err != nil {
		return "", err
	}
	return strconv.Itoa(value), nil
}

func readInt32(key string, fallback, minimum, maximum int32) (int32, error) {
	value, err := readInt(key, int(fallback), int(minimum), int(maximum))
	return int32(value), err
}

func readInt(key string, fallback, minimum, maximum int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < minimum || value > maximum {
		return 0, fmt.Errorf("%s must be between %d and %d", key, minimum, maximum)
	}
	return value, nil
}

func readBool(key string, fallback bool) (bool, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		return false, fmt.Errorf("%s must be a boolean: %w", key, err)
	}
	return value, nil
}
