#!/bin/bash
# Script to get detailed Cloud Build logs

PROJECT_ID="ehc-aroan-17eb34"
BUILD_ID="522fbef0-8985-4622-9f67-55602ce098cd"

echo "Fetching detailed logs for build $BUILD_ID..."
echo ""

gcloud builds log $BUILD_ID --project=$PROJECT_ID

