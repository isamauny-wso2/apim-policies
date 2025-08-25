# WSO2 APIM Policy Deployment Guide

This guide explains how to build and deploy WSO2 API Manager mediation policies for AI-related guardrails and content validation.

## Overview

This repository contains automated scripts to:
1. **Build all policies** - Compile and package all mediation policies as OSGi bundles
2. **Install policies** - Install policies to WSO2 APIM via REST API

## Prerequisites

- **Java 11** - Required for compilation
- **Maven 3.6+** - Build system
- **WSO2 API Manager 4.5 with latest patch (14)** - Target deployment environment
- **jq** - JSON processing (install via `brew install jq` on macOS)
- **curl** - HTTP client (usually pre-installed)
- **unzip** - Archive extraction (usually pre-installed)

## Quick Start

1. **Build all policies:**
   ```bash
   ./build-all-policies.sh
   ```

2. **Install policies to WSO2 APIM:**
   ```bash
   export ADMIN_PASS=your-admin-password
   ./install-policies.sh
   ```

## Script Details

### 1. Build Script (`build-all-policies.sh`)

Compiles and packages all mediation policies in the repository.

**Usage:**
```bash
./build-all-policies.sh [OPTIONS]
```

**Options:**
- `--clean` - Clean all target directories before building
- `--help` - Show usage information

**What it does:**
- Discovers all policy directories under `mediation/ai/*/universal-gw/*/`
- Runs `mvn clean package` for each policy
- Generates OSGi bundles (`.jar` files)
- Creates distribution archives (`.zip` files)
- Copies all artifacts to `build-output/` directory

**Output:**
- Individual policy JARs: `build-output/*.jar`
- Dropins folder bundle: `build-output/apim-policies-dropins.zip` 
- Lib folder bundle: `build-output/apim-policies-lib.zip`
- Build log: `build-output/build.log`

**Installation of JAR files**
- Stop the server
- Unzip apim-policies-dropins.zip and copy the JARs to /repository/components/dropins
- Unzip apim-policies-lib.zip and copy the JARs to /repository/components/lib
- Restart the server

### 2. Installation Script (`install-policies.sh`)

Deploys policies to WSO2 API Manager via REST API.

**Usage:**
```bash
./install-policies.sh [OPTIONS]
```

**Authentication Options:**

**Option 1: Environment Variable (Recommended for CI/CD)**
```bash
export ADMIN_PASS=your-password
./install-policies.sh
```

**Option 2: Password File (Most Secure)**
```bash
echo 'your-password' > ~/.wso2-admin-pass
chmod 600 ~/.wso2-admin-pass
export ADMIN_PASS_FILE=~/.wso2-admin-pass
./install-policies.sh
```

**Option 3: Interactive Prompt (Default)**
```bash
./install-policies.sh
# Will prompt for password securely
```

**Configuration Options:**
```bash
export APIM_HOST=your-apim-host        # Default: localhost
export APIM_PORT=9443                   # Default: 9443  
export ADMIN_USER=custom-admin-user     # Default: admin
```

**Changing Default Admin User:**

The default admin username is `admin`. To use a different admin user:

```bash
# Set custom admin username
export ADMIN_USER=your-admin-username
export ADMIN_PASS=your-admin-password
./install-policies.sh
```

Or combine with other authentication methods:
```bash
# Using password file with custom admin user
export ADMIN_USER=superadmin
echo 'superadmin-password' > ~/.wso2-admin-pass
chmod 600 ~/.wso2-admin-pass
export ADMIN_PASS_FILE=~/.wso2-admin-pass
./install-policies.sh
```

**What it does:**
- Authenticates with WSO2 APIM using OAuth2
- Discovers policy distribution ZIP files
- Extracts policy definitions and artifact templates
- Deploys each policy via Publisher REST API
- Handles duplicate policies gracefully
- Provides detailed logging and error reporting

**Features:**
- ✅ Automatic OAuth2 token management
- ✅ Secure password handling (no command-line exposure)
- ✅ Configurable admin username (defaults to `admin`)
- ✅ Handles existing policies (shows warnings, continues)
- ✅ Detailed progress reporting
- ✅ Complete installation logging
- ✅ Error recovery and reporting

## Available Policies

The repository contains 12 AI-related mediation policies:
- **Content Length Guardrail** - Validates content length limits
- **Word Count Guardrail** - Validates word count limits  
- **Sentence Count Guardrail** - Validates sentence count limits
- **JSON Schema Guardrail** - Enforces JSON schema compliance
- **Regex Guardrail** - Validates content against regex patterns
- **URL Guardrail** - Validates and checks URLs in content
- **AWS Bedrock Guardrail** - AWS Bedrock content safety
- **Azure Content Safety** - Azure Content Moderation service
- **Semantic Prompt Guard** - Semantic similarity validation
- **PII Masking (Regex)** - Masks personally identifiable information
- **Prompt Decorator** - Dynamically decorates prompts
- **Prompt Template** - Template-based prompt transformation

## Deployment Workflow

### Development Workflow
```bash
# 1. Make code changes
# 2. Build updated policies
./build-all-policies.sh --clean

# 3. Deploy to development environment
export ADMIN_USER=dev-admin
export ADMIN_PASS=dev-password
export APIM_HOST=apim-dev.company.com
./install-policies.sh
```

### Production Deployment
```bash
# 1. Build production-ready artifacts
./build-all-policies.sh --clean

# 2. Deploy to production (using secure password file)
export ADMIN_USER=prod-admin
echo 'prod-password' > ~/.wso2-admin-pass-prod
chmod 600 ~/.wso2-admin-pass-prod
export ADMIN_PASS_FILE=~/.wso2-admin-pass-prod
export APIM_HOST=apim.company.com
export APIM_PORT=9443
./install-policies.sh
```

## Troubleshooting

### Build Issues

**Problem: Maven compilation failures**
```bash
# Check Java version
java -version  # Should be 11

# Clean and rebuild
./build-all-policies.sh --clean
```

**Problem: Missing dependencies**
```bash
# Check Maven repositories in pom.xml files
# Ensure WSO2 repositories are accessible
```

### Installation Issues

**Problem: Authentication failures (HTTP 401)**
- Verify admin credentials (username and password)
- Check if custom ADMIN_USER is set correctly
- Check APIM_HOST and APIM_PORT settings
- Ensure WSO2 APIM is running and accessible

**Problem: Connection issues**
```bash
# Test connectivity
curl -k https://your-apim-host:9443/services/Version

# Check DNS resolution
nslookup your-apim-host
```

**Problem: Policy deployment failures (HTTP 400)**
- Check policy definition JSON syntax
- Verify artifact template format
- Review installation logs: `build-output/install.log`

**Problem: Existing policies**
- The script handles existing policies automatically
- Shows warnings but continues installation
- Existing policies are not overwritten

### Debugging

**Enable detailed logging:**
```bash
# Installation logs are automatically saved to:
tail -f build-output/install.log

# Build logs:
tail -f build-output/build.log
```

**Manual policy verification:**
- Visit WSO2 APIM Publisher: `https://your-apim-host:9443/publisher`
- Navigate to: Policies → Operation Policies
- Verify deployed policies appear in the list

## File Structure

```
apim-policies/
├── build-all-policies.sh          # Build automation script
├── install-policies.sh            # Deployment automation script  
├── build-output/                  # Generated artifacts
│   ├── *.jar                     # Individual policy bundles
│   ├── apim-policies-dropins.zip # Combined dropins bundle
│   ├── apim-policies-lib.zip     # Library dependencies
│   ├── build.log                 # Build log
│   ├── install.log               # Installation log
│   └── policy-extracts/          # Extracted policy definitions
├── mediation/ai/                 # Source code
│   ├── policy-name/
│   │   └── universal-gw/
│   │       ├── resources/        # Policy definitions
│   │       │   ├── policy-definition.json
│   │       │   └── artifact.j2
│   │       └── policy-name/      # Maven project
│   │           ├── pom.xml
│   │           └── src/main/java/
└── DEPLOY.md                     # This documentation
```

## Security Notes

- **Never commit passwords** to version control
- Use password files with restricted permissions (`chmod 600`)
- Environment variables are safer than command-line arguments
- OAuth2 tokens are automatically managed and not exposed
- All authentication is performed over HTTPS
- Default admin user is `admin` - change via `ADMIN_USER` environment variable

## CI/CD Integration

**GitHub Actions Example:**
```yaml
- name: Build Policies
  run: ./build-all-policies.sh --clean

- name: Deploy to Staging
  env:
    ADMIN_USER: staging-admin
    ADMIN_PASS: ${{ secrets.WSO2_ADMIN_PASS }}
    APIM_HOST: apim-staging.company.com
  run: ./install-policies.sh
```

**Jenkins Example:**
```groovy
stage('Deploy Policies') {
    environment {
        ADMIN_USER = 'jenkins-deploy'
        ADMIN_PASS = credentials('wso2-admin-password')
        APIM_HOST = 'apim.company.com'
    }
    steps {
        sh './build-all-policies.sh --clean'
        sh './install-policies.sh'
    }
}
```

---

For issues or questions, check the logs in `build-output/` or refer to the WSO2 API Manager documentation.