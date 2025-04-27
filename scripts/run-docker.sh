#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is installed
check_docker() {
  echo -e "${BLUE}Checking if Docker is installed...${NC}"
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker and try again.${NC}"
    return 1
  fi
  echo -e "${GREEN}Docker is installed.${NC}"
  return 0
}

# Check if Docker Compose is installed
check_docker_compose() {
  echo -e "${BLUE}Checking if Docker Compose is available...${NC}"
  if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose V2 not detected. Checking for docker-compose...${NC}"
    if ! command -v docker-compose &> /dev/null; then
      echo -e "${RED}Docker Compose is not installed. Please install Docker Compose and try again.${NC}"
      return 1
    else
      echo -e "${YELLOW}Using legacy docker-compose. Consider upgrading to Docker Compose V2.${NC}"
      COMPOSE_CMD="docker-compose"
    fi
  else
    echo -e "${GREEN}Docker Compose V2 is available.${NC}"
    COMPOSE_CMD="docker compose"
  fi
  return 0
}

# Build Docker images
build() {
  echo -e "${BLUE}Building Docker images...${NC}"
  $COMPOSE_CMD build
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Docker images. Exiting.${NC}"
    return 1
  fi
  echo -e "${GREEN}Docker images built successfully.${NC}"
  return 0
}

# Start the Arvo OS server
start_server() {
  echo -e "${BLUE}Starting Arvo OS server...${NC}"
  $COMPOSE_CMD up -d arvoos-server
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start Arvo OS server. Exiting.${NC}"
    return 1
  fi

  echo -e "${BLUE}Waiting for Arvo OS server to be ready...${NC}"
  attempt=0
  max_attempts=30
  while [ $attempt -lt $max_attempts ]; do
    if $COMPOSE_CMD ps arvoos-server | grep -q "(healthy)"; then
      echo -e "${GREEN}Arvo OS server is ready!${NC}"
      return 0
    fi
    echo -e "${YELLOW}Waiting for server to be ready... (${attempt}/${max_attempts})${NC}"
    sleep 5
    attempt=$((attempt+1))
  done

  echo -e "${RED}Timed out waiting for Arvo OS server to be ready. Check logs with 'docker compose logs arvoos-server'${NC}"
  return 1
}

# Start the Arvo OS CLI
start_cli() {
  echo -e "${BLUE}Starting Arvo OS CLI...${NC}"
  $COMPOSE_CMD run --rm arvoos-cli
  return $?
}

# Start both server and CLI
start_all() {
  echo -e "${BLUE}Starting Arvo OS (server and CLI)...${NC}"
  $COMPOSE_CMD up
  return $?
}

# Stop all containers
stop() {
  echo -e "${BLUE}Stopping Arvo OS...${NC}"
  $COMPOSE_CMD down
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to stop Arvo OS. Exiting.${NC}"
    return 1
  fi
  echo -e "${GREEN}Arvo OS stopped successfully.${NC}"
  return 0
}

# Show logs
logs() {
  service=$1
  if [ -z "$service" ]; then
    echo -e "${BLUE}Showing logs for all services...${NC}"
    $COMPOSE_CMD logs --follow
  else
    echo -e "${BLUE}Showing logs for $service...${NC}"
    $COMPOSE_CMD logs --follow $service
  fi
  return $?
}

# Show help
show_help() {
  echo -e "${BLUE}Arvo OS Docker Helper Script${NC}"
  echo -e "Usage: $0 [command]"
  echo -e ""
  echo -e "Commands:"
  echo -e "  ${GREEN}build${NC}       Build Docker images"
  echo -e "  ${GREEN}server${NC}      Start the Arvo OS server"
  echo -e "  ${GREEN}cli${NC}         Start the Arvo OS CLI (requires server to be running)"
  echo -e "  ${GREEN}start${NC}       Start both server and CLI"
  echo -e "  ${GREEN}stop${NC}        Stop all containers"
  echo -e "  ${GREEN}logs${NC}        Show logs (usage: $0 logs [service])"
  echo -e "  ${GREEN}help${NC}        Show this help message"
  echo -e ""
  echo -e "Examples:"
  echo -e "  $0 build       # Build Docker images"
  echo -e "  $0 server      # Start the Arvo OS server"
  echo -e "  $0 cli         # Start the Arvo OS CLI"
  echo -e "  $0 start       # Start both server and CLI"
  echo -e "  $0 stop        # Stop all containers"
  echo -e "  $0 logs        # Show logs for all services"
  echo -e "  $0 logs server # Show logs for the server only"
}

# Verify Docker setup
verify_setup() {
  echo -e "${BLUE}Verifying Docker setup...${NC}"
  if [ -f "./scripts/verify-docker-setup.sh" ]; then
    ./scripts/verify-docker-setup.sh
    return $?
  else
    echo -e "${YELLOW}Warning: Verification script not found. Skipping detailed verification.${NC}"
    return 0
  fi
}

# Main function
main() {
  COMPOSE_CMD="docker compose"

  check_docker
  if [ $? -ne 0 ]; then
    exit 1
  fi

  check_docker_compose
  if [ $? -ne 0 ]; then
    exit 1
  fi

  if [ "$1" != "help" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
    verify_setup
    if [ $? -ne 0 ]; then
      echo -e "${RED}Docker setup verification failed. Please fix the issues and try again.${NC}"
      exit 1
    fi
  fi

  case "$1" in
    build)
      build
      ;;
    server)
      start_server
      ;;
    cli)
      start_cli
      ;;
    start)
      start_all
      ;;
    stop)
      stop
      ;;
    logs)
      logs $2
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${YELLOW}No command specified. Showing help:${NC}"
      show_help
      ;;
  esac

  exit $?
}

chmod +x "$0"
main "$@"
