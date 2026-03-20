# Jenkins — CI/CD Automation Server

> Install, configure, and manage Jenkins for continuous integration and deployment. Covers pipelines, Jenkinsfile, plugins, credentials, agents, and backup.

## Safety Rules

- Change the default admin password immediately after install.
- Don't expose Jenkins to the internet without HTTPS and authentication.
- Restrict script approval carefully — Groovy scripts have full system access.
- Keep Jenkins and plugins updated — security vulnerabilities are common.
- Use credentials manager — never hardcode secrets in Jenkinsfiles.
- Limit agent permissions — agents can execute arbitrary code.

## Quick Reference

```bash
# Install (Ubuntu/Debian — LTS)
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y jenkins

# Prerequisites: Java 17+
sudo apt install -y fontconfig openjdk-17-jre

# Install (RHEL/Rocky)
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins java-17-openjdk

# Install via Docker
docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Service management
sudo systemctl enable --now jenkins
sudo systemctl status jenkins
sudo systemctl restart jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Web UI: http://localhost:8080
```

## Configuration

### `/etc/default/jenkins` (Debian) or `/etc/sysconfig/jenkins` (RHEL)

```bash
# Java options
JAVA_OPTS="-Djava.awt.headless=true -Xmx2048m -Xms512m"

# Jenkins options
JENKINS_PORT=8080
JENKINS_LISTEN_ADDRESS=0.0.0.0

# Run behind reverse proxy
JENKINS_OPTS="--prefix=/jenkins"
```

### Reverse Proxy (nginx)

```nginx
server {
    listen 80;
    server_name jenkins.example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (required for agents)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 90s;
    }
}
```

## Pipelines — Jenkinsfile

### Declarative Pipeline

```groovy
// Jenkinsfile (Declarative)
pipeline {
    agent any

    environment {
        APP_NAME = 'myapp'
        DEPLOY_ENV = 'staging'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Test') {
            steps {
                sh 'npm test'
            }
            post {
                always {
                    junit 'test-results/**/*.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    docker.build("${APP_NAME}:${BUILD_NUMBER}")
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'deploy-creds',
                        usernameVariable: 'USER', passwordVariable: 'PASS')
                ]) {
                    sh './deploy.sh ${DEPLOY_ENV}'
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: '#builds', color: 'good',
                message: "Build #${BUILD_NUMBER} succeeded")
        }
        failure {
            slackSend(channel: '#builds', color: 'danger',
                message: "Build #${BUILD_NUMBER} failed")
        }
        always {
            cleanWs()
        }
    }
}
```

### Scripted Pipeline

```groovy
// Jenkinsfile (Scripted)
node {
    try {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh 'make build'
        }

        stage('Test') {
            sh 'make test'
        }

        if (env.BRANCH_NAME == 'main') {
            stage('Deploy') {
                withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
                    sh "curl -H 'Authorization: ${API_KEY}' https://deploy.example.com/trigger"
                }
            }
        }
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        cleanWs()
    }
}
```

### Multi-Branch & Parameters

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'VERSION', defaultValue: 'latest', description: 'Version to deploy')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip test stage')
    }

    stages {
        stage('Test') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                sh 'npm test'
            }
        }

        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    expression { params.ENVIRONMENT == 'production' }
                }
            }
            input {
                message "Deploy to production?"
                ok "Yes, deploy!"
            }
            steps {
                sh "deploy.sh ${params.VERSION} ${params.ENVIRONMENT}"
            }
        }
    }
}
```

## Credentials

```bash
# Via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ create-credentials-by-xml system::system::_ <<'EOF'
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>deploy-creds</id>
  <username>deploy</username>
  <password>secret</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
```

### Using Credentials in Pipeline

```groovy
// Username/password
withCredentials([usernamePassword(credentialsId: 'docker-hub',
    usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
    sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
}

// Secret text
withCredentials([string(credentialsId: 'api-token', variable: 'TOKEN')]) {
    sh 'curl -H "Authorization: Bearer $TOKEN" https://api.example.com'
}

// SSH key
withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key',
    keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
    sh 'ssh -i $SSH_KEY $SSH_USER@server.example.com "deploy.sh"'
}

// File credential
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
    sh 'kubectl get pods'
}
```

## Agents

### SSH Agent

```groovy
pipeline {
    agent {
        label 'linux'
    }
    // Or specific node:
    // agent { node { label 'docker-builder' } }
    stages { ... }
}
```

### Docker Agent

```groovy
pipeline {
    agent {
        docker {
            image 'node:20'
            args '-v /tmp:/tmp'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'node --version'
                sh 'npm ci && npm run build'
            }
        }
    }
}
```

### Kubernetes Agent

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: node
                    image: node:20
                    command: ['sleep', '99d']
                  - name: docker
                    image: docker:dind
                    securityContext:
                      privileged: true
            '''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('node') {
                    sh 'npm ci && npm run build'
                }
            }
        }
    }
}
```

## Plugins (Essential)

```bash
# Install via CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin \
  git workflow-aggregator docker-workflow blueocean \
  credentials-binding pipeline-stage-view \
  slack email-ext junit

# Popular plugins:
# Git                    — Git integration
# Pipeline               — Pipeline as code
# Blue Ocean             — Modern UI
# Docker Pipeline        — Docker agent support
# Kubernetes             — K8s agent support
# Credentials Binding    — Use credentials in pipelines
# Slack Notification     — Slack alerts
# Email Extension        — Advanced email notifications
# JUnit                  — Test result reporting
# SonarQube Scanner      — Code quality
# Artifactory            — Artifact management
# LDAP/SAML              — Enterprise auth
```

## Backup & Restore

```bash
# Jenkins home directory (contains everything)
# Debian: /var/lib/jenkins
# Docker: /var/jenkins_home

# Backup essentials
tar czf jenkins_backup_$(date +%Y%m%d).tar.gz \
  /var/lib/jenkins/config.xml \
  /var/lib/jenkins/credentials.xml \
  /var/lib/jenkins/secrets/ \
  /var/lib/jenkins/users/ \
  /var/lib/jenkins/jobs/ \
  /var/lib/jenkins/plugins/ \
  /var/lib/jenkins/nodes/

# Full backup
tar czf jenkins_full_$(date +%Y%m%d).tar.gz /var/lib/jenkins/ \
  --exclude='*/builds/*/archive' \
  --exclude='*/workspace'

# Restore
sudo systemctl stop jenkins
sudo tar xzf jenkins_backup_20260320.tar.gz -C /
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo systemctl start jenkins

# Thin backup plugin (scheduled backups from UI)
# Install: Manage Jenkins → Plugins → ThinBackup
```

## Jenkins CLI

```bash
# Download CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# List jobs
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:token list-jobs

# Trigger build
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:token build myproject

# Safe restart
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:token safe-restart

# Run Groovy script
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:token groovy = <<'EOF'
Jenkins.instance.getAllItems(Job).each { println it.name }
EOF
```

## Troubleshooting

```bash
# Jenkins won't start
sudo journalctl -u jenkins --no-pager -n 50
sudo cat /var/log/jenkins/jenkins.log | tail -100

# Out of memory
# Increase heap in JAVA_OPTS: -Xmx4096m

# Plugin issues (blank page, errors)
# Disable plugin: rename .jpi to .jpi.disabled in /var/lib/jenkins/plugins/
# Or use safe mode: http://localhost:8080/safeRestart

# Build queue stuck
# Manage Jenkins → Script Console:
# Jenkins.instance.queue.clear()

# Reset admin password
# Stop Jenkins, edit /var/lib/jenkins/config.xml
# Set <useSecurity>false</useSecurity>
# Restart, reconfigure security, set new password

# Disk space
du -sh /var/lib/jenkins/jobs/*/builds/ | sort -h | tail -20
# Configure build rotation in job settings

# Slow UI
# Increase heap, reduce build history, disable unused plugins
```
