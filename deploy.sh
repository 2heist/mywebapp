#!/bin/bash
set -e

echo "Pulling latest Docker image..."
sudo docker pull ghcr.io/2heist/mywebapp:latest

echo "Disabling old Socket Activation from Lab 1..."
sudo systemctl stop mywebapp.socket || true
sudo systemctl disable mywebapp.socket || true
sudo systemctl stop mywebapp.service || true

echo "Installing Lab 3 systemd service..."
sudo cp mywebapp.service /etc/systemd/system/mywebapp.service
sudo systemctl daemon-reload

echo "Starting Docker container service..."
sudo systemctl enable mywebapp.service
sudo systemctl restart mywebapp.service

echo "Verifying deployment..."
sleep 5 

if curl -sSf http://127.0.0.1:5299 > /dev/null; then
    echo "Verification SUCCESS: Application is running and responding!"
    exit 0
else
    echo "Verification FAILED: Application crashed or not responding on port 5299!"
    exit 1
fi

