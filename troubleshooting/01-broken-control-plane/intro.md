# 🐉 Broken Control Plane

A Kubernetes cluster is experiencing multiple failures.

Your task is to investigate the incident and restore the cluster to a healthy state.

You have administrative access to the node.

## Your Mission

You are not told what is broken.

Investigate the symptoms, identify the root causes, and recover the cluster.

You may need to use both Kubernetes and Linux troubleshooting techniques.

Think before changing anything.

## Rules

Do NOT:

- reset the cluster
- reboot the node
- reinstall Kubernetes
- delete `/etc/kubernetes`
- delete etcd data
- delete the application namespace
- delete workloads just to bypass the problem

Use normal Kubernetes and Linux troubleshooting techniques.

## Resources

If you are unfamiliar with a concept involved in this incident, use the official Kubernetes documentation before looking at the solution.

The goal is troubleshooting, not memorizing commands.

Good luck. 🐉