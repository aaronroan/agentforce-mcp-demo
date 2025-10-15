#!/bin/bash

# Deployment script for Google Cloud Run
# Usage: ./deploy.sh [PROJECT_ID] [REGION]

set -e

# Configuration
PROJECT_ID=${1:-"your-project-id"}
REGION=${2:-"us-central1"}
SERVICE_NAME="google-docs-mcp"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Deploying Google Docs MCP Server to Cloud Run"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service: $SERVICE_NAME"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI is not installed"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "❌ Error: Not authenticated with gcloud"
    echo "Run: gcloud auth login"
    exit 1
fi

# Set the project
echo "📦 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Check if credentials.json exists
if [ ! -f "credentials.json" ]; then
    echo "❌ Error: credentials.json not found"
    echo "Please place your Google OAuth credentials.json in the project root"
    exit 1
fi

# Check if token.json exists
if [ ! -f "token.json" ]; then
    echo "⚠️  Warning: token.json not found"
    echo "You need to run the server locally first to generate token.json"
    echo "Run: npm run build && node dist/server.js"
    exit 1
fi

# Create secrets in Secret Manager
echo "🔐 Creating secrets..."

# Check if secrets already exist, if not create them
if ! gcloud secrets describe google-docs-credentials --project=$PROJECT_ID &> /dev/null; then
    echo "Creating google-docs-credentials secret..."
    gcloud secrets create google-docs-credentials \
        --replication-policy="automatic" \
        --project=$PROJECT_ID
fi

if ! gcloud secrets describe google-docs-token --project=$PROJECT_ID &> /dev/null; then
    echo "Creating google-docs-token secret..."
    gcloud secrets create google-docs-token \
        --replication-policy="automatic" \
        --project=$PROJECT_ID
fi

# Update secret versions with current files
echo "📝 Updating secret versions..."
gcloud secrets versions add google-docs-credentials \
    --data-file=credentials.json \
    --project=$PROJECT_ID

gcloud secrets versions add google-docs-token \
    --data-file=token.json \
    --project=$PROJECT_ID

# Build the container image
echo "🏗️  Building container image..."
gcloud builds submit --tag $IMAGE_NAME --project=$PROJECT_ID

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest" \
    --project=$PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)' --project=$PROJECT_ID)

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Service URL: $SERVICE_URL"
echo "SSE Endpoint: $SERVICE_URL/sse"
echo ""
echo "Test your deployment:"
echo "curl $SERVICE_URL/health"
echo ""
echo "View logs:"
echo "gcloud run services logs read $SERVICE_NAME --region $REGION --project $PROJECT_ID"

