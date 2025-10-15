# Troubleshooting Cloud Build Deployment

## Common Cloud Build Errors

### Error: "step exited with non-zero status: 1"

This generic error means a Cloud Build step failed. Here's how to debug:

## 🔍 Step 1: View Detailed Logs

### Via Cloud Console
1. Go to [Cloud Build History](https://console.cloud.google.com/cloud-build/builds?project=ehc-aroan-17eb34)
2. Click on the failed build
3. Look at the logs for step 2 (Cloud Run deployment)
4. The actual error will be in the expanded logs

### Via gcloud CLI
```bash
# List recent builds
gcloud builds list --project=ehc-aroan-17eb34 --limit=5

# Get logs for specific build
gcloud builds log BUILD_ID --project=ehc-aroan-17eb34
```

## 🛠️ Common Issues & Fixes

### Issue 1: Secrets Don't Exist

**Error in logs:** `Secret [google-docs-credentials] not found` or `Secret [google-docs-token] not found`

**Fix:**
```bash
# Check if secrets exist
gcloud secrets list --project=ehc-aroan-17eb34

# If missing, create them (you need credentials.json and token.json files)
gcloud secrets create google-docs-credentials \
  --replication-policy="automatic" \
  --project=ehc-aroan-17eb34

gcloud secrets create google-docs-token \
  --replication-policy="automatic" \
  --project=ehc-aroan-17eb34

# Add secret values
gcloud secrets versions add google-docs-credentials \
  --data-file=credentials.json \
  --project=ehc-aroan-17eb34

gcloud secrets versions add google-docs-token \
  --data-file=token.json \
  --project=ehc-aroan-17eb34
```

### Issue 2: Cloud Build Lacks IAM Permissions

**Error in logs:** `Permission denied` or `does not have permission to access secret`

**Fix:**
```bash
# Get your project number
PROJECT_NUMBER=$(gcloud projects describe ehc-aroan-17eb34 --format='value(projectNumber)')

echo "Project Number: $PROJECT_NUMBER"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding ehc-aroan-17eb34 \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Grant Cloud Run Admin access
gcloud projects add-iam-policy-binding ehc-aroan-17eb34 \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/run.admin"

# Grant Service Account User role
gcloud projects add-iam-policy-binding ehc-aroan-17eb34 \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Grant IAM Admin (if needed for setting up service accounts)
gcloud projects add-iam-policy-binding ehc-aroan-17eb34 \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"
```

### Issue 3: Cloud Run API Not Enabled

**Error in logs:** `Cloud Run API has not been used in project` or `API not enabled`

**Fix:**
```bash
# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  secretmanager.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  --project=ehc-aroan-17eb34
```

### Issue 4: Using --set-secrets Instead of --update-secrets

The `--set-secrets` flag only works on first deployment. For updates, use `--update-secrets`.

**Fix:** Use the simplified cloudbuild.yaml:
```yaml
# Use this in the deploy step
- '--update-secrets=GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest'
```

Or create service first manually, then use Cloud Build.

### Issue 5: Wrong Image Name in cloudbuild.yaml

**Error in logs:** `The user-provided container failed to start and listen on the port`

**Fix:** Ensure the image name matches between build and deploy steps.

## 📋 Complete Setup Checklist

Run these commands in order:

```bash
PROJECT_ID="ehc-aroan-17eb34"

# 1. Enable APIs
echo "Enabling APIs..."
gcloud services enable \
  run.googleapis.com \
  secretmanager.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  --project=$PROJECT_ID

# 2. Get project number
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
echo "Project Number: $PROJECT_NUMBER"

# 3. Grant permissions to Cloud Build service account
echo "Granting permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# 4. Create secrets (if not exists)
echo "Creating secrets..."
gcloud secrets create google-docs-credentials \
  --replication-policy="automatic" \
  --project=$PROJECT_ID 2>/dev/null || echo "Secret already exists"

gcloud secrets create google-docs-token \
  --replication-policy="automatic" \
  --project=$PROJECT_ID 2>/dev/null || echo "Secret already exists"

# 5. Upload secret values (you need these files!)
echo "Uploading secret values..."
gcloud secrets versions add google-docs-credentials \
  --data-file=credentials.json \
  --project=$PROJECT_ID

gcloud secrets versions add google-docs-token \
  --data-file=token.json \
  --project=$PROJECT_ID

# 6. Verify secrets
echo "Verifying secrets..."
gcloud secrets list --project=$PROJECT_ID

echo ""
echo "✅ Setup complete! Now trigger your Cloud Build."
```

## 🚀 Alternative: Manual Deployment First

If Cloud Build keeps failing, deploy manually first, then use Cloud Build for updates:

```bash
PROJECT_ID="ehc-aroan-17eb34"

# 1. Build and push image
gcloud builds submit \
  --tag gcr.io/$PROJECT_ID/google-docs-mcp \
  --project=$PROJECT_ID

# 2. Deploy to Cloud Run manually
gcloud run deploy google-docs-mcp \
  --image gcr.io/$PROJECT_ID/google-docs-mcp:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 10 \
  --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest" \
  --project=$PROJECT_ID

# 3. Now Cloud Build updates will work
```

## 📊 Debug Commands

### Check Build Status
```bash
gcloud builds list --project=ehc-aroan-17eb34 --limit=10
```

### View Specific Build Log
```bash
# Replace BUILD_ID with actual ID from error
gcloud builds log BUILD_ID --project=ehc-aroan-17eb34
```

### Check IAM Permissions
```bash
gcloud projects get-iam-policy ehc-aroan-17eb34 \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:*cloudbuild*"
```

### Verify Secrets
```bash
gcloud secrets list --project=ehc-aroan-17eb34
gcloud secrets versions list google-docs-credentials --project=ehc-aroan-17eb34
gcloud secrets versions list google-docs-token --project=ehc-aroan-17eb34
```

### Test Cloud Run Service
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe google-docs-mcp \
  --region us-central1 \
  --project=ehc-aroan-17eb34 \
  --format 'value(status.url)')

# Test endpoint
curl $SERVICE_URL/health
```

## 🔗 Useful Links

- [Cloud Build Console](https://console.cloud.google.com/cloud-build/builds?project=ehc-aroan-17eb34)
- [Cloud Run Console](https://console.cloud.google.com/run?project=ehc-aroan-17eb34)
- [Secret Manager Console](https://console.cloud.google.com/security/secret-manager?project=ehc-aroan-17eb34)
- [IAM Console](https://console.cloud.google.com/iam-admin/iam?project=ehc-aroan-17eb34)

## 💡 Pro Tips

1. **Use Cloud Shell** - It has all tools pre-installed and authenticated
2. **Check logs first** - The detailed error is in the build logs
3. **Test locally** - Use `docker build` locally to catch build errors early
4. **Start simple** - Deploy manually first, then automate with Cloud Build
5. **Check quotas** - Some GCP quotas can cause silent failures

## 🆘 Still Having Issues?

1. Share the full build log from Cloud Console
2. Run the "Complete Setup Checklist" above
3. Try the "Manual Deployment First" approach
4. Check if your `credentials.json` and `token.json` are valid

