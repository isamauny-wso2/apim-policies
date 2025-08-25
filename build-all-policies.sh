#!/bin/bash

# Build All Policies Script
# This script builds all WSO2 APIM mediation policies and collects their JARs in a central location

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Java 11 path (configurable)
JAVA_11_HOME="${JAVA_11_HOME:-/opt/homebrew/Cellar/openjdk@11/11.0.27/libexec/openjdk.jdk/Contents/Home}"

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
BUILD_OUTPUT_DIR="$PROJECT_ROOT/build-output"
BUILD_LOG="$BUILD_OUTPUT_DIR/build.log"

# Shared log function - displays colors on screen, writes clean text to log
log() {
    local color="$1"
    local message="$2"
    local log_prefix="$3"
    
    # Display colored message to screen
    echo -e "${color}${message}${NC}"
    
    # Write clean message to log file
    echo "${log_prefix}${message}" >> "$BUILD_LOG"
}

# Convenience functions for different log levels
log_info() {
    log "" "$1" "[INFO] "
}

log_success() {
    log "$GREEN" "$1" "[SUCCESS] "
}

log_warning() {
    log "$YELLOW" "$1" "[WARNING] "
}

log_error() {
    log "$RED" "$1" "[ERROR] "
}

log_header() {
    log "$BLUE" "$1" "[HEADER] "
}

# Create build output directory first (needed for log file)
mkdir -p "$BUILD_OUTPUT_DIR"
rm -rf "$BUILD_OUTPUT_DIR"/*  # Clean previous builds

# Initialize log file
echo "WSO2 APIM Policies - Build All Script" > "$BUILD_LOG"
echo "====================================" >> "$BUILD_LOG"
echo "Build started at: $(date)" >> "$BUILD_LOG"
echo "" >> "$BUILD_LOG"

log_header "WSO2 APIM Policies - Build All Script"
echo "============================================"
log_info "Project root: $PROJECT_ROOT"
log_info "Build output: $BUILD_OUTPUT_DIR"
log_info "Java 11 home: $JAVA_11_HOME"
echo ""

# Verify Java 11 installation
if [ ! -d "$JAVA_11_HOME" ]; then
    log_error "Java 11 not found at: $JAVA_11_HOME"
    log_info "Please set JAVA_11_HOME environment variable to your Java 11 installation path"
    log_info "Example: export JAVA_11_HOME=/path/to/your/java11"
    exit 1
fi

# Set JAVA_HOME for Maven
export JAVA_HOME="$JAVA_11_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# Verify Java version
JAVA_VERSION=$("$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
log_info "Using Java version: $JAVA_VERSION"

if [[ ! "$JAVA_VERSION" =~ ^11\. ]]; then
    log_warning "Expected Java 11, but found $JAVA_VERSION"
fi

echo ""

# Define all policy directories relative to project root
POLICY_DIRS=(
    "mediation/ai/aws-bedrock-guardrail/universal-gw/aws-bedrock-guardrail"
    "mediation/ai/azure-content-safety-guardrail/universal-gw/azure-content-safety-guardrail"
    "mediation/ai/content-length-guardrail/universal-gw/content-length-guardrail"
    "mediation/ai/json-schema-guardrail/universal-gw/json-schema-guardrail"
    "mediation/ai/pii-masking-regex/universal-gw/pii-masking-regex"
    "mediation/ai/prompt-decorator/universal-gw/prompt-decorator"
    "mediation/ai/prompt-template/universal-gw/prompt-template"
    "mediation/ai/regex-guardrail/universal-gw/regex-guardrail"
    "mediation/ai/semantic-prompt-guard/universal-gw/semantic-prompt-guard"
    "mediation/ai/sentence-count-guardrail/universal-gw/sentence-count-guardrail"
    "mediation/ai/url-guardrail/universal-gw/url-guardrail"
    "mediation/ai/word-count-guardrail/universal-gw/word-count-guardrail"
)

# Build statistics
TOTAL_POLICIES=${#POLICY_DIRS[@]}
SUCCESSFUL_BUILDS=0
FAILED_BUILDS=0

log_info "Building $TOTAL_POLICIES policies..."
echo ""

# Build each policy
for POLICY_DIR in "${POLICY_DIRS[@]}"; do
    POLICY_PATH="$PROJECT_ROOT/$POLICY_DIR"
    POLICY_NAME=$(basename "$POLICY_DIR")
    
    log_header "Building: $POLICY_NAME"
    log_info "Path: $POLICY_PATH"
    
    if [ ! -d "$POLICY_PATH" ]; then
        log_error "Policy directory not found: $POLICY_PATH"
        ((FAILED_BUILDS++))
        continue
    fi
    
    if [ ! -f "$POLICY_PATH/pom.xml" ]; then
        log_error "pom.xml not found in: $POLICY_PATH"
        ((FAILED_BUILDS++))
        continue
    fi
    
    # Build the policy
    cd "$POLICY_PATH"
    
    if mvn clean package -q >> "$BUILD_LOG" 2>&1; then
        log_success "✓ Build successful"
        
        # Find and copy JAR files
        TARGET_DIR="$POLICY_PATH/target"
        if [ -d "$TARGET_DIR" ]; then
            # Copy main JAR (excluding sources and javadoc JARs)
            find "$TARGET_DIR" -name "*.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | while read jar_file; do
                if [ -f "$jar_file" ]; then
                    jar_basename=$(basename "$jar_file")
                    cp "$jar_file" "$BUILD_OUTPUT_DIR/"
                    log_info "  → Copied: $jar_basename"
                fi
            done
        else
            log_warning "  No target directory found"
        fi
        
        ((SUCCESSFUL_BUILDS++))
    else
        log_error "✗ Build failed"
        log_info "  Check build.log for details"
        ((FAILED_BUILDS++))
    fi
    
    echo ""
done

# Return to project root
cd "$PROJECT_ROOT"

# Build summary
echo "============================================"
log_header "Build Summary:"
log_info "Total policies: $TOTAL_POLICIES"

if [ $FAILED_BUILDS -gt 0 ]; then
    log_success "Successful: $SUCCESSFUL_BUILDS"
    log_error "Failed: $FAILED_BUILDS"
else
    log_success "Successful: $SUCCESSFUL_BUILDS"
    log_success "Failed: $FAILED_BUILDS"
fi

echo ""
log_info "Built artifacts are available in: $BUILD_OUTPUT_DIR"

# Create deployment ZIP packages
echo ""
log_header "Creating deployment packages..."

if [ -d "$BUILD_OUTPUT_DIR" ] && [ "$(ls -A "$BUILD_OUTPUT_DIR" 2>/dev/null | grep -E '\.jar$')" ]; then
    cd "$BUILD_OUTPUT_DIR"
    
    # Define policies for dropins deployment
    DROPINS_POLICIES=(
        "aws-bedrock-guardrail"
        "azure-content-safety-guardrail"
        "pii-masking-regex"
        "semantic-prompt-guard"
    )
    
    # Define policies for lib deployment  
    LIB_POLICIES=(
        "content-length-guardrail"
        "json-schema-guardrail"
        "regex-guardrail"
        "sentence-count-guardrail"
        "word-count-guardrail"
        "prompt-decorator"
        "prompt-template"
        "url-guardrail"
    )
    
    # Create dropins ZIP
    DROPINS_ZIP="$BUILD_OUTPUT_DIR/apim-policies-dropins.zip"
    DROPINS_JARS=()
    
    for policy in "${DROPINS_POLICIES[@]}"; do
        jar_file=$(ls *${policy}*.jar 2>/dev/null | head -1)
        if [ -n "$jar_file" ]; then
            DROPINS_JARS+=("$jar_file")
        fi
    done
    
    if [ ${#DROPINS_JARS[@]} -gt 0 ]; then
        if zip -q "$DROPINS_ZIP" "${DROPINS_JARS[@]}"; then
            log_success "Created dropins package: apim-policies-dropins.zip (${#DROPINS_JARS[@]} policies)"
            
            # Show dropins contents
            log_info "Dropins package contents:"
            for jar in "${DROPINS_JARS[@]}"; do
                echo "  - $jar"
                echo "  - $jar" >> "$BUILD_LOG"
            done
            
            # Show dropins package size
            DROPINS_SIZE=$(ls -lh "$DROPINS_ZIP" | awk '{print $5}')
            log_info "Dropins package size: $DROPINS_SIZE"
        else
            log_error "Failed to create dropins package"
        fi
    else
        log_warning "No dropins policies found"
    fi
    
    echo ""
    
    # Create lib ZIP
    LIB_ZIP="$BUILD_OUTPUT_DIR/apim-policies-lib.zip"
    LIB_JARS=()
    
    for policy in "${LIB_POLICIES[@]}"; do
        jar_file=$(ls *${policy}*.jar 2>/dev/null | head -1)
        if [ -n "$jar_file" ]; then
            LIB_JARS+=("$jar_file")
        fi
    done
    
    if [ ${#LIB_JARS[@]} -gt 0 ]; then
        if zip -q "$LIB_ZIP" "${LIB_JARS[@]}"; then
            log_success "Created lib package: apim-policies-lib.zip (${#LIB_JARS[@]} policies)"
            
            # Show lib contents
            log_info "Lib package contents:"
            for jar in "${LIB_JARS[@]}"; do
                echo "  - $jar"
                echo "  - $jar" >> "$BUILD_LOG"
            done
            
            # Show lib package size
            LIB_SIZE=$(ls -lh "$LIB_ZIP" | awk '{print $5}')
            log_info "Lib package size: $LIB_SIZE"
        else
            log_error "Failed to create lib package"
        fi
    else
        log_warning "No lib policies found"
    fi
    
    cd "$PROJECT_ROOT"
else
    log_warning "No JAR files found to package"
fi

# List built artifacts
echo ""
log_info "Built artifacts:"
if [ -d "$BUILD_OUTPUT_DIR" ] && [ "$(ls -A "$BUILD_OUTPUT_DIR" 2>/dev/null | grep -E '\.jar$')" ]; then
    ls -la "$BUILD_OUTPUT_DIR"/*.jar 2>/dev/null | while read -r line; do
        echo "  $line"
        echo "  $line" >> "$BUILD_LOG"
    done
else
    log_warning "No artifacts found"
fi

echo ""
log_info "Full build log available at: $BUILD_LOG"

# Usage information
echo ""
log_info "To use a custom Java 11 path, set JAVA_11_HOME before running:"
log_info "  export JAVA_11_HOME=/path/to/your/java11"
log_info "  ./build-all-policies.sh"
echo ""
log_info "To deploy to WSO2, use:"
log_info "  # For policies requiring dropins deployment:"
log_info "  scp build-output/apim-policies-dropins.zip user@wso2-server:/path/to/deployment/"
log_info "  # For policies requiring lib deployment:"
log_info "  scp build-output/apim-policies-lib.zip user@wso2-server:/path/to/deployment/"

# Final build completion timestamp
echo "" >> "$BUILD_LOG"
echo "Build completed at: $(date)" >> "$BUILD_LOG"

# Exit with error code if any builds failed
if [ $FAILED_BUILDS -gt 0 ]; then
    exit 1
else
    log_success "All policies built successfully!"
    exit 0
fi