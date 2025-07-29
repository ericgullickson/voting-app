#!/usr/bin/env python3

import paramiko
import sys
import getpass
import os

def main():
    services = ["Vote", "Results", "Redis", "Worker", "Database"]
    ips = {}
    
    print("Enter IP addresses for each service:")
    for service in services:
        ip = input(f"{service}: ").strip()
        if not ip:
            print(f"Error: IP address for {service} cannot be empty")
            sys.exit(1)
        ips[service] = ip
    
    username = input("SSH Username: ").strip()
    if not username:
        print("Error: Username cannot be empty")
        sys.exit(1)
    
    ssh_key_path = input("SSH Private Key Path (press Enter to auto-detect): ").strip()
    if not ssh_key_path:
        default_keys = ["~/.ssh/id_ed25519", "~/.ssh/id_rsa"]
        ssh_key_path = None
        for key_path in default_keys:
            expanded_path = os.path.expanduser(key_path)
            if os.path.exists(expanded_path):
                ssh_key_path = expanded_path
                print(f"Found SSH key: {ssh_key_path}")
                break
    else:
        ssh_key_path = os.path.expanduser(ssh_key_path)
    
    password = None
    if not ssh_key_path or not os.path.exists(ssh_key_path):
        if ssh_key_path:
            print(f"SSH key not found at {ssh_key_path}")
        else:
            print("No SSH keys found in ~/.ssh/")
        password = getpass.getpass("SSH Password: ")
    
    for service, ip in ips.items():
        hostname = service.lower()
        print(f"\nConnecting to {ip} ({service})...")
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            if ssh_key_path and os.path.exists(ssh_key_path):
                print(f"Attempting SSH key authentication using {ssh_key_path}")
                try:
                    ssh.connect(ip, username=username, key_filename=ssh_key_path, timeout=30)
                except paramiko.AuthenticationException:
                    print("SSH key authentication failed, falling back to password")
                    if password is None:
                        password = getpass.getpass("SSH Password: ")
                    ssh.connect(ip, username=username, password=password, timeout=30)
            else:
                ssh.connect(ip, username=username, password=password, timeout=30)
            
            print(f"Setting hostname to '{hostname}'...")
            stdin, stdout, stderr = ssh.exec_command(f'sudo hostnamectl set-hostname {hostname}')
            stderr_output = stderr.read().decode()
            if stderr_output:
                print(f"Warning: {stderr_output}")
            
            print(f"Updating .env file with IP addresses...")
            env_content = f"""DB={ips['Database']}
WORKER={ips['Worker']}
VOTE={ips['Vote']}
RESULT={ips['Results']}
REDIS={ips['Redis']}
OPTION_A=Hi-C
OPTION_B=Tang
"""
            stdin, stdout, stderr = ssh.exec_command(f'cat > /home/nutanix/voting-app/.env << "EOF"\n{env_content}EOF')
            stderr_output = stderr.read().decode()
            if stderr_output:
                print(f"Warning updating .env: {stderr_output}")
            
            print(f"Running docker compose for {hostname}...")
            compose_cmd = f'cd /home/nutanix/voting-app/ && docker compose --file ./docker-compose.{hostname}.yml up -d'
            stdin, stdout, stderr = ssh.exec_command(compose_cmd)
            
            stdout_output = stdout.read().decode()
            stderr_output = stderr.read().decode()
            
            if stdout_output:
                print(f"Output: {stdout_output}")
            if stderr_output:
                print(f"Error: {stderr_output}")
            
            ssh.close()
            print(f"Completed setup for {service} ({ip})")
            
        except Exception as e:
            print(f"Failed to connect to {ip} ({service}): {str(e)}")
            continue

if __name__ == "__main__":
    main()