# Java — OpenJDK Runtime & Build Tools

> Install OpenJDK, configure JAVA_HOME, manage builds with Maven and Gradle, set up Tomcat, and deploy Spring Boot applications.

## Safety Rules

- Always set `JAVA_HOME` before running build tools — Maven and Gradle depend on it.
- Use LTS versions in production (21, 17, 11) — avoid non-LTS for server workloads.
- Never run application servers (Tomcat, Spring Boot) as root.
- Pin dependency versions in `pom.xml` / `build.gradle` — avoid `LATEST` or `RELEASE`.
- Rotate and protect keystores — never commit `.jks` or `.p12` files.

## Quick Reference

```bash
# Check version
java --version
javac --version

# Check JAVA_HOME
echo $JAVA_HOME

# Run a JAR
java -jar app.jar

# Maven build
mvn clean package

# Gradle build
./gradlew build

# List installed Java versions (Debian/Ubuntu)
update-alternatives --list java
```

## Installation

### Install OpenJDK on Debian/Ubuntu

```bash
# Install default JDK (usually latest LTS)
sudo apt update && sudo apt install -y default-jdk

# Install specific version
sudo apt install -y openjdk-21-jdk
sudo apt install -y openjdk-17-jdk
sudo apt install -y openjdk-11-jdk

# Install JRE only (no compiler)
sudo apt install -y openjdk-21-jre
```

### Install OpenJDK on RHEL/Rocky/Alma

```bash
sudo dnf install -y java-21-openjdk java-21-openjdk-devel
sudo dnf install -y java-17-openjdk java-17-openjdk-devel
```

### Install Eclipse Temurin (Adoptium — recommended for production)

```bash
# Debian/Ubuntu
sudo apt install -y wget apt-transport-https gpg
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update && sudo apt install -y temurin-21-jdk
```

### Switch between Java versions

```bash
# Debian/Ubuntu
sudo update-alternatives --config java
sudo update-alternatives --config javac

# Or set manually
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

### Configure JAVA_HOME

```bash
# Find Java location
readlink -f $(which java) | sed 's|/bin/java||'

# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
EOF
source ~/.bashrc

# Verify
echo $JAVA_HOME
java --version
```

## Maven — Build & Dependency Management

### Install Maven

```bash
# Debian/Ubuntu
sudo apt install -y maven

# Or download latest
MVN_VERSION=3.9.9
wget "https://dlcdn.apache.org/maven/maven-3/${MVN_VERSION}/binaries/apache-maven-${MVN_VERSION}-bin.tar.gz"
sudo tar -C /opt -xzf "apache-maven-${MVN_VERSION}-bin.tar.gz"
sudo ln -s "/opt/apache-maven-${MVN_VERSION}/bin/mvn" /usr/local/bin/mvn
rm "apache-maven-${MVN_VERSION}-bin.tar.gz"
mvn --version
```

### Maven commands

```bash
# Create a new project from archetype
mvn archetype:generate \
  -DgroupId=com.example \
  -DartifactId=my-app \
  -DarchetypeArtifactId=maven-archetype-quickstart \
  -DinteractiveMode=false

# Build lifecycle
mvn clean                 # Remove target/
mvn compile               # Compile source
mvn test                  # Run tests
mvn package               # Create JAR/WAR
mvn install               # Install to local repo (~/.m2)
mvn clean package         # Clean + package (most common)

# Skip tests
mvn clean package -DskipTests

# Run with specific profile
mvn clean package -P production

# Dependency management
mvn dependency:tree                # Show dependency tree
mvn dependency:resolve             # Download all dependencies
mvn versions:display-dependency-updates   # Check for updates

# Run Spring Boot
mvn spring-boot:run

# Generate project documentation
mvn site
```

### Example `pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>my-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>3.3.4</version>
        </dependency>
    </dependencies>
</project>
```

## Gradle — Build Tool

### Install Gradle

```bash
# Using SDKMAN (recommended)
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle

# Or download manually
GRADLE_VERSION=8.11
wget "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
sudo unzip -d /opt/gradle "gradle-${GRADLE_VERSION}-bin.zip"
sudo ln -s "/opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle
rm "gradle-${GRADLE_VERSION}-bin.zip"
gradle --version
```

### Gradle commands

```bash
# Initialize a project
gradle init --type java-application

# Build lifecycle (use wrapper when available)
./gradlew build              # Compile + test + package
./gradlew clean build        # Clean first
./gradlew test               # Run tests only
./gradlew jar                # Create JAR
./gradlew bootRun            # Spring Boot run

# Skip tests
./gradlew build -x test

# Show dependencies
./gradlew dependencies
./gradlew dependencies --configuration runtimeClasspath

# Refresh dependencies
./gradlew build --refresh-dependencies

# List tasks
./gradlew tasks

# Generate Gradle wrapper (pin version)
gradle wrapper --gradle-version 8.11
```

### Example `build.gradle` (Groovy DSL)

```groovy
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.3.4'
    id 'io.spring.dependency-management' version '1.1.6'
}

group = 'com.example'
version = '1.0.0'

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

tasks.named('test') {
    useJUnitPlatform()
}
```

## Tomcat — Servlet Container

### Install Tomcat

```bash
# Create tomcat user
sudo useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat

# Download and extract
TOMCAT_VERSION=10.1.34
wget "https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
sudo tar -C /opt/tomcat --strip-components=1 -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
sudo chown -R tomcat:tomcat /opt/tomcat
rm "apache-tomcat-${TOMCAT_VERSION}.tar.gz"

# Set permissions
sudo chmod +x /opt/tomcat/bin/*.sh
```

### Tomcat systemd service

```ini
# /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx2048M -server -XX:+UseParallelGC"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tomcat
sudo systemctl status tomcat
# Default port: 8080
```

### Deploy a WAR to Tomcat

```bash
# Build WAR
mvn clean package

# Deploy
sudo cp target/my-app.war /opt/tomcat/webapps/
sudo chown tomcat:tomcat /opt/tomcat/webapps/my-app.war

# Check deployment
curl http://localhost:8080/my-app/
```

## Spring Boot — Standalone Deployment

### Build and run

```bash
# Build fat JAR
mvn clean package -DskipTests
# or
./gradlew build -x test

# Run directly
java -jar target/my-app-1.0.0.jar

# Run with custom properties
java -jar target/my-app-1.0.0.jar --server.port=9090
java -jar target/my-app-1.0.0.jar --spring.profiles.active=production

# Run with JVM options
java -Xms256m -Xmx1024m -jar target/my-app-1.0.0.jar
```

### Spring Boot systemd service

```ini
# /etc/systemd/system/spring-app.service
[Unit]
Description=Spring Boot Application
After=network.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/spring-app
ExecStart=/usr/bin/java -Xms256m -Xmx1024m -jar /opt/spring-app/app.jar --spring.profiles.active=production
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now spring-app
sudo journalctl -u spring-app -f
```

## JVM Tuning

```bash
# Common production flags
java -Xms512m -Xmx2g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/var/log/java/ \
  -Djava.security.egd=file:/dev/urandom \
  -jar app.jar

# Check running JVM processes
jps -v

# Monitor heap usage
jstat -gc $(pgrep -f app.jar) 5s

# Thread dump (for debugging hangs)
jstack $(pgrep -f app.jar)

# Heap dump
jmap -dump:format=b,file=heap.hprof $(pgrep -f app.jar)
```

## Troubleshooting

```bash
# JAVA_HOME not set
readlink -f $(which java) | sed 's|/bin/java||'
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Wrong Java version
java --version
update-alternatives --config java

# Maven: dependency resolution failures
mvn dependency:purge-local-repository
rm -rf ~/.m2/repository
mvn clean install

# Gradle: build cache issues
./gradlew clean build --no-build-cache
rm -rf ~/.gradle/caches

# Port already in use
lsof -i :8080
kill -9 $(lsof -t -i :8080)

# OutOfMemoryError
# Increase heap: -Xmx2g
# Check for leaks: jmap -dump + Eclipse MAT

# Slow startup
java -XX:+PrintCompilation -jar app.jar   # JIT compilation log
```
