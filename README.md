# aws-iacm-ec2-baseline

This repository contains a minimal, opinionated AWS EC2 deployment written in Terraform.

## Purpose
- Demonstrate Harness IaCM workspace usage
- Serve as a clean reference architecture
- Enable IaC scanning with tfsec and Checkov
- Illustrate state separation via multiple workspaces

## Characteristics
- Single-file Terraform configuration
- Idempotent and repeatable
- Non-production, disposable infrastructure
- Explicitly designed for policy evaluation

## Intended Usage
- Local Terraform experimentation
- Harness IaCM workspaces (separate state per workspace)
- Security and compliance scanning demos

## Notes
- No shared remote state by default
- Each workspace manages its own Terraform state
- Infrastructure instances are intentionally identical across states
