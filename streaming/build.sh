#!/bin/bash
###############################################################################
# Build Script for Flink Streaming Jobs
###############################################################################

set -e

echo "Building Flink Streaming Jobs..."

cd "$(dirname "$0")/flink-jobs"

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven is not installed."
    echo ""
    echo "Please install Maven first:"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "  brew install maven"
    elif command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        echo "  sudo apt-get install maven"
    elif command -v yum &> /dev/null; then
        # RedHat/CentOS/Amazon Linux
        echo "  sudo yum install -y maven"
    elif command -v dnf &> /dev/null; then
        # Fedora/Amazon Linux 2023
        echo "  sudo dnf install -y maven"
    else
        echo "  Visit: https://maven.apache.org/install.html"
    fi
    echo ""
    exit 1
fi

# Clean and package
mvn clean package -DskipTests

# Check if build was successful
if [ -f "target/taxi-streaming-jobs-1.0-SNAPSHOT.jar" ]; then
    echo "Build successful!"
    echo "JAR location: target/taxi-streaming-jobs-1.0-SNAPSHOT.jar"
    ls -lh target/*.jar
else
    echo "Build failed!"
    exit 1
fi

echo ""
echo "To deploy the job:"
echo "  flink run target/taxi-streaming-jobs-1.0-SNAPSHOT.jar"
