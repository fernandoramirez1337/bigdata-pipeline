#!/bin/bash
###############################################################################
# Build Script for Flink Streaming Jobs
###############################################################################

set -e

echo "Building Flink Streaming Jobs..."

cd "$(dirname "$0")/flink-jobs"

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Maven is not installed. Installing..."
    sudo yum install -y maven
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
