# Quick Start: Deploy to Google Cloud Run

This guide gets your Google Docs MCP server running on Cloud Run in under 15 minutes.

## Prerequisites

- ✅ Google Cloud project with billing enabled
- ✅ `gcloud` CLI installed and authenticated (or use Cloud Shell - see [DEPLOY_WITHOUT_CLI.md](DEPLOY_WITHOUT_CLI.md))
- ✅ `credentials.json` (Google OAuth credentials)
- ✅ `token.json` (generated from first local run)

> 💡 **Don't want to install gcloud CLI?** Check out [DEPLOY_WITHOUT_CLI.md](DEPLOY_WITHOUT_CLI.md) for browser-based deployment options!

## 🚀 5-Step Deployment

### Step 1: Clone and Setup (if not done already)

```bash
cd /path/to/agentforce-mcp-demo
npm install
npm run build
```

### Step 2: Generate token.json (if not already done)

```bash
# Run once locally to authenticate and generate token.json
node dist/server.js
# Follow the OAuth flow in your browser
```

### Step 3: Complete the HTTP Server

⚠️ **Important**: The `src/server-http.ts` file needs all tools copied from `src/server.ts`

**Option A - Quick copy** (copy all tools manually):
```bash
# Open both files and copy all tool definitions from server.ts to server-http.ts
# See SETUP_NOTES.md for details
```

**Option B - Use the prepared skeleton**:
The current `server-http.ts` has the basic structure. You'll need to add all remaining tools.

### Step 4: Update the import in server-http.ts

```typescript
// Change this line in src/server-http.ts:
import { authorize } from './auth-cloudrun.js';  // instead of './auth.js'
```

### Step 5: Deploy to Cloud Run

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Run the deployment script
./deploy.sh $PROJECT_ID us-central1
```

The script will:
1. Enable required APIs
2. Create secrets in Secret Manager
3. Build container image
4. Deploy to Cloud Run
5. Output your service URL

## ⚡ Alternative: Manual Deployment

If you prefer step-by-step control:

```bash
# 1. Enable APIs
gcloud services enable cloudbuild.googleapis.com run.googleapis.com secretmanager.googleapis.com

# 2. Create secrets
gcloud secrets create google-docs-credentials --replication-policy="automatic"
gcloud secrets create google-docs-token --replication-policy="automatic"
gcloud secrets versions add google-docs-credentials --data-file=credentials.json
gcloud secrets versions add google-docs-token --data-file=token.json

# 3. Build image
gcloud builds submit --tag gcr.io/$PROJECT_ID/google-docs-mcp

# 4. Deploy
gcloud run deploy google-docs-mcp \
  --image gcr.io/$PROJECT_ID/google-docs-mcp \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest"
```

## ✅ Verify Deployment

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe google-docs-mcp --region us-central1 --format 'value(status.url)')

# Test health endpoint
curl $SERVICE_URL/health

# Check SSE endpoint
curl $SERVICE_URL/sse

# View logs
gcloud run services logs read google-docs-mcp --region us-central1 --limit 20
```

## 🎯 Use Your MCP Server

Your server is now accessible via SSE at:
```
https://YOUR-SERVICE-URL.run.app/sse
```

Configure your MCP client with this endpoint to start using the tools!

## 📊 Monitor Your Service

```bash
# View service details
gcloud run services describe google-docs-mcp --region us-central1

# Stream logs in real-time
gcloud run services logs tail google-docs-mcp --region us-central1

# Check metrics in Cloud Console
# Go to: Cloud Run > google-docs-mcp > Metrics
```

## 💰 Estimated Costs

With moderate usage (100,000 requests/month):
- **~$1-5/month** total
- Includes CPU, memory, and request costs
- First 2 million requests/month are free tier

## 🔧 Troubleshooting

### Build fails
```bash
# Check Docker/Cloud Build logs
gcloud builds list --limit 5
gcloud builds log [BUILD_ID]
```

### Deployment fails
```bash
# Check service status
gcloud run services describe google-docs-mcp --region us-central1

# Verify secrets
gcloud secrets list
gcloud secrets versions access latest --secret google-docs-credentials | head -c 50
```

### Server won't start
```bash
# Check logs for errors
gcloud run services logs read google-docs-mcp --region us-central1 --limit 50

# Common issues:
# - Missing tools in server-http.ts
# - Wrong import for auth module
# - Invalid secrets format
```

## 🔐 Security Notes

- Credentials are stored in Secret Manager (encrypted)
- Secrets are injected at runtime (not in container image)
- Service is currently `--allow-unauthenticated` for testing
- For production, add authentication:
  ```bash
  gcloud run deploy google-docs-mcp --no-allow-unauthenticated
  ```

## 📚 Next Steps

- [ ] Complete all tool definitions in `server-http.ts`
- [ ] Test all MCP tools via SSE endpoint
- [ ] Set up authentication for production use
- [ ] Configure custom domain (optional)
- [ ] Set up CI/CD with Cloud Build triggers
- [ ] Monitor costs after a week of usage

## 📖 Full Documentation

- [Complete Deployment Guide](CLOUD_RUN_DEPLOYMENT.md)
- [Setup Notes & Troubleshooting](SETUP_NOTES.md)
- [Main README](README.md)

## 🆘 Need Help?

- Check [SETUP_NOTES.md](SETUP_NOTES.md) for detailed troubleshooting
- Review [Cloud Run logs](https://console.cloud.google.com/run)
- Verify secrets in [Secret Manager](https://console.cloud.google.com/security/secret-manager)
- Check [Cloud Build history](https://console.cloud.google.com/cloud-build/builds)

---

**Ready to deploy?** Run `./deploy.sh YOUR_PROJECT_ID` and you'll be live in minutes! 🚀

