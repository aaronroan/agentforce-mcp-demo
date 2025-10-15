# Deploying Google Docs MCP Server to Google Cloud Run

This guide walks you through deploying your Google Docs MCP server as a Cloud Run service.

## 🏗️ Architecture

The Cloud Run deployment uses a different architecture than the local version:

- **Local Version** (`server.ts`): Uses **stdio** transport for communication with Claude Desktop
- **Cloud Run Version** (`server-http.ts`): Uses **SSE (Server-Sent Events)** over HTTP for web-based communication

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Google Cloud Project** with billing enabled
2. **gcloud CLI** installed and configured
   - Install from: https://cloud.google.com/sdk/docs/install
   - Run: `gcloud auth login`
3. **Google OAuth Credentials** (`credentials.json` file)
4. **Google OAuth Token** (`token.json` file)
   - Generate by running locally: `npm run build && node dist/server.js`
5. **Docker** (optional, for local testing)

## 🚀 Quick Deployment

### Step 1: Prepare Your Credentials

Make sure you have both files in your project root:
- `credentials.json` - Your Google OAuth2 client credentials
- `token.json` - Your authorized token (generated from first-time auth)

### Step 2: Set Your Project ID

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"  # or your preferred region
```

### Step 3: Run the Deployment Script

```bash
./deploy.sh $PROJECT_ID $REGION
```

The script will:
1. ✅ Enable required Google Cloud APIs
2. 🔐 Create secrets in Secret Manager for credentials
3. 🏗️  Build the container image
4. 🚀 Deploy to Cloud Run
5. 📋 Output your service URL

## 📝 Manual Deployment Steps

If you prefer manual deployment or need more control:

### 1. Enable Required APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 2. Create Secrets

```bash
# Create secrets for credentials
gcloud secrets create google-docs-credentials \
    --replication-policy="automatic"

gcloud secrets create google-docs-token \
    --replication-policy="automatic"

# Add secret versions
gcloud secrets versions add google-docs-credentials \
    --data-file=credentials.json

gcloud secrets versions add google-docs-token \
    --data-file=token.json
```

### 3. Build Container Image

```bash
gcloud builds submit --tag gcr.io/$PROJECT_ID/google-docs-mcp
```

### 4. Deploy to Cloud Run

```bash
gcloud run deploy google-docs-mcp \
    --image gcr.io/$PROJECT_ID/google-docs-mcp \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest"
```

## 🔧 Configuration Options

### Environment Variables

The server-http.ts uses these environment variables:

- `PORT` - Server port (default: 8080, set by Cloud Run)
- `GOOGLE_CREDENTIALS` - Injected from Secret Manager
- `GOOGLE_TOKEN` - Injected from Secret Manager

### Cloud Run Settings

Adjust these based on your needs:

- `--memory` - Memory allocation (256Mi, 512Mi, 1Gi, 2Gi, 4Gi)
- `--cpu` - CPU allocation (1, 2, 4)
- `--timeout` - Request timeout in seconds (max 3600)
- `--max-instances` - Maximum concurrent instances
- `--min-instances` - Keep instances warm (costs more)

### Scaling Configuration

For production workloads, consider:

```bash
gcloud run deploy google-docs-mcp \
    --min-instances 1 \
    --max-instances 100 \
    --concurrency 80 \
    --cpu-throttling
```

## 🧪 Testing Your Deployment

### Health Check

```bash
curl https://your-service-url/health
```

### Test SSE Endpoint

```bash
curl https://your-service-url/sse
```

### View Logs

```bash
gcloud run services logs read google-docs-mcp \
    --region $REGION \
    --limit 50
```

### Tail Logs (Real-time)

```bash
gcloud run services logs tail google-docs-mcp \
    --region $REGION
```

## 🔐 Security Considerations

### 1. Authentication

Currently, the service is deployed with `--allow-unauthenticated`. For production:

```bash
# Deploy with authentication required
gcloud run deploy google-docs-mcp \
    --no-allow-unauthenticated \
    ...

# Add IAM binding for specific users
gcloud run services add-iam-policy-binding google-docs-mcp \
    --region $REGION \
    --member "user:email@example.com" \
    --role "roles/run.invoker"
```

### 2. Secret Management

Secrets are stored in Google Secret Manager and injected at runtime. Never commit:
- `credentials.json`
- `token.json`
- Any files containing sensitive data

### 3. Token Refresh

Google OAuth tokens expire. The server handles refresh automatically using the refresh token stored in `token.json`. Ensure your credentials have offline access enabled.

## 💰 Cost Estimation

Cloud Run pricing (as of 2024):

- **CPU**: ~$0.00002400/vCPU-second
- **Memory**: ~$0.00000250/GiB-second
- **Requests**: $0.40/million requests
- **Free Tier**: 2 million requests/month, 360,000 GiB-seconds of memory, 180,000 vCPU-seconds

Example monthly cost for moderate usage:
- 100,000 requests
- Average 200ms response time
- 512Mi memory, 1 CPU
- **Estimated**: $1-5/month

Use the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) for detailed estimates.

## 🔄 Updating Your Deployment

### Update Code

```bash
# Make changes to src/server-http.ts
npm run build

# Rebuild and redeploy
gcloud builds submit --tag gcr.io/$PROJECT_ID/google-docs-mcp
gcloud run deploy google-docs-mcp --image gcr.io/$PROJECT_ID/google-docs-mcp
```

### Update Secrets

```bash
# Update credentials
gcloud secrets versions add google-docs-credentials \
    --data-file=credentials.json

# Update token
gcloud secrets versions add google-docs-token \
    --data-file=token.json

# Cloud Run will automatically use the latest version
```

## 🐛 Troubleshooting

### Container Fails to Start

```bash
# Check logs
gcloud run services logs read google-docs-mcp --region $REGION --limit 100

# Common issues:
# - Secrets not mounted correctly
# - Invalid credentials.json format
# - Port mismatch (ensure server listens on PORT env var)
```

### Authentication Errors

```bash
# Verify secrets exist
gcloud secrets list

# Check secret versions
gcloud secrets versions list google-docs-credentials
gcloud secrets versions list google-docs-token

# Test locally with secrets
gcloud secrets versions access latest --secret google-docs-credentials > test-creds.json
```

### High Latency

```bash
# Check metrics
gcloud run services describe google-docs-mcp --region $REGION

# Consider:
# - Increase --min-instances to keep containers warm
# - Increase CPU/memory allocation
# - Enable CPU boost for startup
```

### Out of Memory

```bash
# Increase memory allocation
gcloud run deploy google-docs-mcp \
    --memory 1Gi \
    --image gcr.io/$PROJECT_ID/google-docs-mcp
```

## 📊 Monitoring

### View Service Details

```bash
gcloud run services describe google-docs-mcp --region $REGION
```

### Set Up Alerts

```bash
# Install monitoring if not already enabled
gcloud services enable monitoring.googleapis.com

# Create alert for error rate
gcloud alpha monitoring policies create \
    --notification-channels=CHANNEL_ID \
    --display-name="Cloud Run Error Rate" \
    --condition-display-name="Error rate > 5%" \
    ...
```

### View Metrics in Console

1. Go to [Cloud Console](https://console.cloud.google.com)
2. Navigate to Cloud Run > Your Service
3. Click "METRICS" tab
4. View:
   - Request count
   - Request latency
   - Container instance count
   - CPU/Memory utilization

## 🌐 Using with MCP Clients

Once deployed, your MCP server is accessible via SSE at:

```
https://your-service-url/sse
```

### Configure Claude Desktop (Web Version)

If using a web-based MCP client that supports HTTP/SSE:

```json
{
  "mcpServers": {
    "google-docs-mcp": {
      "url": "https://your-service-url/sse",
      "transport": "sse"
    }
  }
}
```

### Using with Custom Clients

```javascript
const eventSource = new EventSource('https://your-service-url/sse');

eventSource.onmessage = (event) => {
  console.log('Received:', event.data);
};
```

## 🔗 CI/CD Integration

### Using Cloud Build Triggers

Create a trigger for automatic deployment on git push:

```bash
gcloud builds triggers create github \
    --repo-name=google-docs-mcp \
    --repo-owner=YOUR_GITHUB_USERNAME \
    --branch-pattern="^main$" \
    --build-config=cloudbuild.yaml
```

The included `cloudbuild.yaml` handles:
1. Building the container
2. Pushing to Container Registry
3. Deploying to Cloud Run
4. Injecting secrets

## 📚 Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Secret Manager Best Practices](https://cloud.google.com/secret-manager/docs/best-practices)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
- [FastMCP Documentation](https://github.com/jlowin/fastmcp)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)

## 🆘 Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review Cloud Run logs: `gcloud run services logs read google-docs-mcp`
3. Verify secrets are correctly configured
4. Test locally first with Docker
5. Open an issue on the [GitHub repository](https://github.com/a-bonus/google-docs-mcp)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

