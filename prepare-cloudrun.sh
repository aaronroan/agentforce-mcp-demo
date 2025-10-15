#!/bin/bash

# Preparation script for Cloud Run deployment
# This script helps ensure everything is ready before deploying

set -e

echo "🔍 Checking Cloud Run deployment prerequisites..."
echo ""

# Check if credentials.json exists
if [ ! -f "credentials.json" ]; then
    echo "❌ Error: credentials.json not found"
    echo "   Please place your Google OAuth credentials.json in the project root"
    exit 1
else
    echo "✅ credentials.json found"
fi

# Check if token.json exists
if [ ! -f "token.json" ]; then
    echo "❌ Error: token.json not found"
    echo "   You need to run the server locally first to generate token.json"
    echo "   Run: npm run build && node dist/server.js"
    exit 1
else
    echo "✅ token.json found"
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI is not installed"
    echo "   Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
else
    echo "✅ gcloud CLI installed"
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "❌ Error: Not authenticated with gcloud"
    echo "   Run: gcloud auth login"
    exit 1
else
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo "✅ gcloud authenticated as: $ACCOUNT"
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "⚠️  Warning: node_modules not found"
    echo "   Installing dependencies..."
    npm install
else
    echo "✅ node_modules found"
fi

# Check if dist directory exists
if [ ! -d "dist" ]; then
    echo "⚠️  Warning: dist directory not found"
    echo "   Building TypeScript..."
    npm run build
else
    echo "✅ dist directory found"
fi

# Check if server-http.ts has been updated with auth-cloudrun
if grep -q "auth-cloudrun" src/server-http.ts; then
    echo "✅ server-http.ts uses auth-cloudrun"
else
    echo "⚠️  Warning: server-http.ts may not be using auth-cloudrun"
    echo "   Make sure to import from './auth-cloudrun.js'"
fi

# Count tools in server.ts vs server-http.ts
SERVER_TOOLS=$(grep -c "server.addTool" src/server.ts || echo "0")
HTTP_TOOLS=$(grep -c "server.addTool" src/server-http.ts || echo "0")

echo ""
echo "📊 Tool count comparison:"
echo "   server.ts (stdio): $SERVER_TOOLS tools"
echo "   server-http.ts (Cloud Run): $HTTP_TOOLS tools"

if [ "$HTTP_TOOLS" -lt "$SERVER_TOOLS" ]; then
    echo ""
    echo "⚠️  WARNING: server-http.ts has fewer tools than server.ts"
    echo "   You need to copy all tool definitions from server.ts to server-http.ts"
    echo "   See SETUP_NOTES.md for instructions"
    echo ""
    echo "   Missing approximately $((SERVER_TOOLS - HTTP_TOOLS)) tools"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Test building the project
echo ""
echo "🔨 Testing build..."
if npm run build 2>&1 | grep -q "error"; then
    echo "❌ Build failed. Please fix TypeScript errors first."
    exit 1
else
    echo "✅ Build successful"
fi

# Final checklist
echo ""
echo "📋 Pre-deployment checklist:"
echo "   ✅ credentials.json exists"
echo "   ✅ token.json exists"
echo "   ✅ gcloud CLI installed and authenticated"
echo "   ✅ Dependencies installed"
echo "   ✅ Project builds successfully"

if [ "$HTTP_TOOLS" -lt "$SERVER_TOOLS" ]; then
    echo "   ⚠️  server-http.ts may be incomplete"
else
    echo "   ✅ server-http.ts appears complete"
fi

echo ""
echo "✨ Ready for deployment!"
echo ""
echo "Next steps:"
echo "1. Set your project ID: export PROJECT_ID='your-gcp-project-id'"
echo "2. Run deployment: ./deploy.sh \$PROJECT_ID us-central1"
echo ""
echo "Or follow the manual steps in CLOUD_RUN_DEPLOYMENT.md"

