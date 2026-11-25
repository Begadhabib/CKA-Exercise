#!/bin/bash
echo "Preparing the incident environment, please wait..."
while [ ! -f /tmp/.scenario-ready ]; do sleep 2; done
echo "Environment ready. Good luck, engineer."
