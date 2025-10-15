#!/bin/bash
# Quick fix script for Cloud Build deployment issues

set -e

PROJECT_ID="ehc-aroan-17eb34"

echo "🔧 Fixing Cloud Build deployment for project: $PROJECT_ID"
echo ""

# 1. Enable required APIs
echo "📡 Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  secretmanager.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  --project=$PROJECT_ID

echo "✅ APIs enabled"
echo ""

# 2. Get project number
echo "🔍 Getting project number..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
echo "   Project Number: $PROJECT_NUMBER"
echo ""

# 3. Grant IAM permissions to Cloud Build
echo "🔐 Granting IAM permissions to Cloud Build service account..."

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/run.admin" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

echo "✅ IAM permissions granted"
echo ""

# 4. Check if secrets exist
echo "🔒 Checking secrets..."
if gcloud secrets describe google-docs-credentials --project=$PROJECT_ID &> /dev/null; then
    echo "   ✅ google-docs-credentials exists"
else
    echo "   ❌ google-docs-credentials NOT FOUND"
    echo "   Creating secret..."
    gcloud secrets create google-docs-credentials \
      --replication-policy="automatic" \
      --project=$PROJECT_ID
    echo "   ⚠️  You need to add the secret value:"
    echo "   gcloud secrets versions add google-docs-credentials --data-file=credentials.json --project=$PROJECT_ID"
fi

if gcloud secrets describe google-docs-token --project=$PROJECT_ID &> /dev/null; then
    echo "   ✅ google-docs-token exists"
else
    echo "   ❌ google-docs-token NOT FOUND"
    echo "   Creating secret..."
    gcloud secrets create google-docs-token \
      --replication-policy="automatic" \
      --project=$PROJECT_ID
    echo "   ⚠️  You need to add the secret value:"
    echo "   gcloud secrets versions add google-docs-token --data-file=token.json --project=$PROJECT_ID"
fi

echo ""

# 5. Summary
echo "📋 Summary:"
echo ""
gcloud secrets list --project=$PROJECT_ID
echo ""

echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. If secrets are empty, upload credentials:"
echo "   gcloud secrets versions add google-docs-credentials --data-file=credentials.json --project=$PROJECT_ID"
echo "   gcloud secrets versions add google-docs-token --data-file=token.json --project=$PROJECT_ID"
echo ""
echo "2. Retry your Cloud Build trigger or run:"
echo "   gcloud builds submit --config=cloudbuild.yaml --project=$PROJECT_ID"
echo ""
echo "3. Or deploy manually first:"
echo "   ./deploy.sh $PROJECT_ID us-central1"

