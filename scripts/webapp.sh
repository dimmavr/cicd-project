#!/bin/bash
PORT=8000
MESSAGE="Hello from app-node - webapp v4 FULL DEPLOY"
echo "Starting webapp on port ${PORT}..."
while true; do
    RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n${MESSAGE}\r\n"
    printf "${RESPONSE}" | nc -N -l "${PORT}"
done
