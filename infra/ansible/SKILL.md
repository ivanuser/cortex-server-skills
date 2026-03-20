# Ansible — Configuration Management & Automation

> Install, configure, and manage Ansible for automating server provisioning, configuration, and deployments. Covers inventory, playbooks, roles, vault, ad-hoc commands, and Galaxy.

## Safety Rules

- Always use `--check` (dry run) before applying changes to production.
- Use `--diff` to see what will change before applying.
- Never store passwords or secrets in plaintext — use `ansible-vault`.
- Test playbooks in staging before production.
- Use `--limit` to target specific hosts when running against large inventories.
- Be careful with `become: true` — it runs as root on target machines.

## Quick Reference

```bash
# Install (pip — recommended, latest version)
pip3 install ansible

# Install (Ubuntu/Debian PPA)
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt update && sudo apt install -y ansible

# Install (RHEL/Rocky)
sudo dnf install -y ansible-core

# Version check
ansible --version
ansible-playbook --version

# Quick connectivity test
ansible all -m ping -i inventory.ini
ansible all -m ping -i inventory.ini -u deploy --ask-pass

# Run ad-hoc command
ansible all -m shell -a "uptime" -i inventory.ini
ansible webservers -m shell -a "df -h" -i inventory.ini

# Run playbook
ansible-playbook playbook.yml -i inventory.ini
ansible-playbook playbook.yml -i inventory.ini --check --diff   # Dry run
ansible-playbook playbook.yml -i inventory.ini --limit webserver1
```

## Inventory

### INI Format — `inventory.ini`

```ini
[webservers]
web1 ansible_host=10.0.0.1
web2 ansible_host=10.0.0.2
web3 ansible_host=10.0.0.3 ansible_port=2222

[dbservers]
db1 ansible_host=10.0.0.10
db2 ansible_host=10.0.0.11

[loadbalancers]
lb1 ansible_host=10.0.0.20

# Group of groups
[production:children]
webservers
dbservers
loadbalancers

# Group variables
[webservers:vars]
ansible_user=deploy
ansible_python_interpreter=/usr/bin/python3
http_port=8080

[all:vars]
ansible_ssh_private_key_file=~/.ssh/deploy_key
```

### YAML Format — `inventory.yml`

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.0.1
        web2:
          ansible_host: 10.0.0.2
      vars:
        http_port: 8080
    dbservers:
      hosts:
        db1:
          ansible_host: 10.0.0.10
    production:
      children:
        webservers:
        dbservers:
```

```bash
# List inventory
ansible-inventory -i inventory.ini --list
ansible-inventory -i inventory.ini --graph

# Dynamic inventory (scripts or plugins)
ansible-playbook playbook.yml -i aws_ec2.yml
```

## Ad-Hoc Commands

```bash
# Ping all hosts
ansible all -m ping -i inventory.ini

# Run shell command
ansible webservers -m shell -a "systemctl status nginx" -i inventory.ini

# Copy file
ansible webservers -m copy -a "src=./nginx.conf dest=/etc/nginx/nginx.conf" -i inventory.ini --become

# Install package
ansible webservers -m apt -a "name=nginx state=present update_cache=yes" -i inventory.ini --become

# Manage service
ansible webservers -m service -a "name=nginx state=restarted" -i inventory.ini --become

# Gather facts
ansible web1 -m setup -i inventory.ini
ansible web1 -m setup -a "filter=ansible_os_family" -i inventory.ini

# Create user
ansible all -m user -a "name=deploy state=present shell=/bin/bash" -i inventory.ini --become

# File operations
ansible all -m file -a "path=/opt/app state=directory mode=0755 owner=deploy" -i inventory.ini --become

# Reboot
ansible all -m reboot -a "reboot_timeout=300" -i inventory.ini --become

# Run with elevated privileges
ansible all -m shell -a "cat /etc/shadow" -i inventory.ini --become --become-method=sudo
```

## Playbooks

### Basic Playbook — `playbook.yml`

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: true
  vars:
    http_port: 80
    app_user: deploy

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Copy nginx config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/sites-available/default
        mode: '0644'
      notify: Restart nginx

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: true

    - name: Create app directory
      file:
        path: /opt/app
        state: directory
        owner: "{{ app_user }}"
        mode: '0755'

    - name: Deploy application
      copy:
        src: files/app/
        dest: /opt/app/
        owner: "{{ app_user }}"
      notify: Restart app

  handlers:
    - name: Restart nginx
      service:
        name: nginx
        state: restarted

    - name: Restart app
      systemd:
        name: myapp
        state: restarted
```

### Conditionals, Loops & Blocks

```yaml
tasks:
  # Conditionals
  - name: Install on Debian
    apt: name=nginx state=present
    when: ansible_os_family == "Debian"

  - name: Install on RedHat
    dnf: name=nginx state=present
    when: ansible_os_family == "RedHat"

  # Loops
  - name: Install packages
    apt:
      name: "{{ item }}"
      state: present
    loop:
      - nginx
      - postgresql
      - redis-server

  - name: Create users
    user:
      name: "{{ item.name }}"
      groups: "{{ item.groups }}"
      state: present
    loop:
      - { name: deploy, groups: sudo }
      - { name: appuser, groups: www-data }

  # Blocks (try/rescue/always)
  - name: Handle deployment
    block:
      - name: Deploy code
        git:
          repo: https://github.com/org/app.git
          dest: /opt/app
          version: "{{ app_version }}"

      - name: Run migrations
        command: /opt/app/migrate.sh

    rescue:
      - name: Rollback on failure
        command: /opt/app/rollback.sh

    always:
      - name: Notify team
        debug:
          msg: "Deployment attempt completed"

  # Register output
  - name: Check disk space
    command: df -h /
    register: disk_result

  - name: Warn if disk full
    debug:
      msg: "Disk space low!"
    when: "'90%' in disk_result.stdout"
```

## Roles

```bash
# Create role structure
ansible-galaxy role init roles/webserver

# Role structure:
# roles/webserver/
# ├── defaults/main.yml     # Default variables (lowest priority)
# ├── files/                 # Static files to copy
# ├── handlers/main.yml      # Handlers
# ├── meta/main.yml          # Role metadata/dependencies
# ├── tasks/main.yml         # Main task list
# ├── templates/             # Jinja2 templates
# └── vars/main.yml          # Variables (high priority)
```

### Using Roles in Playbooks

```yaml
---
- name: Configure servers
  hosts: webservers
  become: true
  roles:
    - common
    - webserver
    - { role: database, when: "'dbservers' in group_names" }
    - role: app
      vars:
        app_port: 3000
```

## Ansible Vault

```bash
# Create encrypted file
ansible-vault create secrets.yml

# Encrypt existing file
ansible-vault encrypt vars/production.yml

# Decrypt file
ansible-vault decrypt vars/production.yml

# View encrypted file
ansible-vault view secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Encrypt a string
ansible-vault encrypt_string 'my_secret_password' --name 'db_password'

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

# Rekey (change vault password)
ansible-vault rekey secrets.yml
```

### Using Vault in Playbooks

```yaml
# vars/secrets.yml (encrypted)
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...encrypted data...

# playbook.yml
- hosts: dbservers
  vars_files:
    - vars/secrets.yml
  tasks:
    - name: Configure database
      postgresql_user:
        name: app
        password: "{{ db_password }}"
```

## Ansible Galaxy

```bash
# Install role from Galaxy
ansible-galaxy role install geerlingguy.docker
ansible-galaxy role install geerlingguy.nginx

# Install from requirements file
ansible-galaxy install -r requirements.yml

# requirements.yml
# roles:
#   - name: geerlingguy.docker
#     version: 7.0.0
#   - name: geerlingguy.nginx
#   - src: https://github.com/org/ansible-role-app
#     version: main

# Install collection
ansible-galaxy collection install community.general
ansible-galaxy collection install amazon.aws

# List installed
ansible-galaxy role list
ansible-galaxy collection list

# Search Galaxy
ansible-galaxy role search nginx
ansible-galaxy role info geerlingguy.nginx
```

## Configuration

### `ansible.cfg`

```ini
[defaults]
inventory = inventory.ini
remote_user = deploy
private_key_file = ~/.ssh/deploy_key
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
forks = 20
timeout = 30

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

## Troubleshooting

```bash
# Verbose output (more v's = more detail)
ansible-playbook playbook.yml -v       # Verbose
ansible-playbook playbook.yml -vvv     # Very verbose (SSH debug)
ansible-playbook playbook.yml -vvvv    # Connection debugging

# Dry run
ansible-playbook playbook.yml --check --diff

# List tasks without running
ansible-playbook playbook.yml --list-tasks

# List hosts without running
ansible-playbook playbook.yml --list-hosts

# Start at specific task
ansible-playbook playbook.yml --start-at-task="Deploy application"

# Step through tasks one at a time
ansible-playbook playbook.yml --step

# SSH connection issues
ansible web1 -m ping -vvvv            # Debug SSH
ssh -o StrictHostKeyChecking=no deploy@10.0.0.1  # Test manual SSH

# Python interpreter issues
ansible web1 -m setup -a "filter=ansible_python_interpreter"
# Override: ansible_python_interpreter=/usr/bin/python3

# Syntax check
ansible-playbook playbook.yml --syntax-check

# Lint playbooks
pip3 install ansible-lint
ansible-lint playbook.yml
```
