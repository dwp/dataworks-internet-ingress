# dataworks-internet-ingress

## DataWorks AWS Internet Ingress

Provides common-good services for accessing the DataWorks environments over
the Internet.

## Overview

![Infrastructure](docs/internet-ingress.png)

## Internet Reverse Proxy Service

The Internet Reverse Proxy Service provides a mechanism for accessing web user
interfaces that are hosted within private subnets.

## SSH Bastion Service

The SSH Bastion Service provides SSH access to EC2 instances that are hosted
within private subnets. As a rule, direct access to EC2 instances should be via
AWS Systems Manager Session Manager (SSM). However, during an IT Health Check
(ITHC) it has proved useful to allow the testers on to hosts via SSH. As such,
the deployment of this service is guarded by `ssh_bastion_enabled` in
[locals.tf](locals.tf). That setting must only be set to `true` if, and only if, an ITHC is being performed. SSH access is restricted to certain trusted networks
via `ssh_bastion_whitelisted_ranges` in [locals.tf](locals.tf)
