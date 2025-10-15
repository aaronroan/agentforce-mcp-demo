# Google Docs MCP Server - Cloud Run Edition

This repository contains an MCP (Model Context Protocol) server for Google Docs and Google Drive, with **dual deployment modes**:

1. **Local Mode**: Runs as a stdio-based MCP server for Claude Desktop (original functionality)
2. **Cloud Run Mode**: Runs as an HTTP/SSE server for web-based deployment

## 🎯 What's New: Cloud Run Support

This fork adds Cloud Run deployment capabilities, allowing you to:

- ☁️ Deploy your MCP server to Google Cloud Run
- 🌐 Access via HTTP/SSE instead of stdio
- 📈 Scale automatically based on demand
- 🔒 Secure credentials via Google Secret Manager
- 💰 Pay only for what you use (starts at ~$1-5/month)

## 🚀 Quick Start

### For Local Development (Claude Desktop)

Follow the original [README.md](README.md) instructions - nothing has changed!

### For Cloud Run Deployment

Choose your experience level:

**🚄 Express Track** (15 minutes):
1. Read [QUICKSTART_CLOUDRUN.md](QUICKSTART_CLOUDRUN.md)
2. Run `./deploy.sh YOUR_PROJECT_ID`
3. Your server is live!

**🌐 No CLI Track** (browser-based):
1. Read [DEPLOY_WITHOUT_CLI.md](DEPLOY_WITHOUT_CLI.md)
2. Use Cloud Shell or Console UI
3. Deploy without installing gcloud CLI locally!

**📚 Detailed Track** (30-45 minutes):
1. Read [CLOUD_RUN_DEPLOYMENT.md](CLOUD_RUN_DEPLOYMENT.md) for comprehensive guide
2. Review [SETUP_NOTES.md](SETUP_NOTES.md) for architecture details
3. Manual deployment with full control

## 📁 Project Structure

```
agentforce-mcp-demo/
├── src/
│   ├── server.ts              # Original stdio-based server (Claude Desktop)
│   ├── server-http.ts         # New HTTP/SSE server (Cloud Run)
│   ├── auth.ts                # Original file-based auth
│   ├── auth-cloudrun.ts       # Enhanced auth (files + env vars)
│   ├── googleDocsApiHelpers.ts
│   └── types.ts
├── dist/                      # Compiled JavaScript
├── Dockerfile                 # Container definition for Cloud Run
├── .dockerignore             # Files to exclude from container
├── .gcloudignore             # Files to exclude from Cloud Build
├── cloudbuild.yaml           # Automated CI/CD configuration
├── deploy.sh                 # One-command deployment script
├── README.md                 # Original README (local development)
├── README_CLOUDRUN.md        # This file (Cloud Run overview)
├── QUICKSTART_CLOUDRUN.md    # Quick 15-minute deployment guide
├── CLOUD_RUN_DEPLOYMENT.md   # Comprehensive deployment documentation
└── SETUP_NOTES.md            # Architecture notes and troubleshooting
```

## 🔄 Deployment Modes Comparison

| Feature | Local (stdio) | Cloud Run (SSE) |
|---------|--------------|-----------------|
| **Communication** | stdin/stdout | HTTP/SSE |
| **Client** | Claude Desktop | Any MCP client |
| **Authentication** | File-based | Secret Manager |
| **Scaling** | Single instance | Auto-scaling |
| **Cost** | Free (local) | ~$1-5/month |
| **Setup Time** | 10 minutes | 15 minutes |
| **Access** | Local only | Internet-wide |
| **Updates** | Manual restart | Automatic rollout |

## 🛠️ Prerequisites

### For Local Development
- Node.js 18+
- Google OAuth credentials
- Claude Desktop (optional)

### For Cloud Run Deployment
All of the above, plus:
- Google Cloud project with billing
- `gcloud` CLI installed
- Docker (optional, for local testing)

## 📚 Documentation Index

Choose the guide that matches your needs:

1. **[README.md](README.md)** - Original setup for Claude Desktop (local)
2. **[QUICKSTART_CLOUDRUN.md](QUICKSTART_CLOUDRUN.md)** - Fast Cloud Run deployment (15 min)
3. **[CLOUD_RUN_DEPLOYMENT.md](CLOUD_RUN_DEPLOYMENT.md)** - Complete Cloud Run guide
4. **[SETUP_NOTES.md](SETUP_NOTES.md)** - Architecture and troubleshooting
5. **[SAMPLE_TASKS.md](SAMPLE_TASKS.md)** - Example tasks and use cases

## 🌟 Features

Both deployment modes support the full feature set:

### Document Operations
- ✅ Read documents (text, JSON, markdown)
- ✅ Append and insert text
- ✅ Delete content ranges
- ✅ Format text (bold, italic, colors, fonts)
- ✅ Format paragraphs (alignment, spacing, headings)

### Document Structure
- ✅ Insert tables
- ✅ Insert page breaks
- ✅ Insert images (URL or local file)
- ✅ Automatic list formatting

### Comments
- ✅ List all comments
- ✅ Add new comments
- ✅ Reply to comments
- ✅ Resolve/delete comments

### Drive Management
- ✅ List and search documents
- ✅ Create folders
- ✅ Move, copy, rename files
- ✅ Get document metadata
- ✅ Create documents from templates

## 🔐 Security

### Local Mode
- Credentials stored in `credentials.json` and `token.json`
- Files excluded from git via `.gitignore`

### Cloud Run Mode
- Credentials stored in Google Secret Manager
- Encrypted at rest and in transit
- Injected as environment variables at runtime
- Never stored in container images or git

## 💻 Development Commands

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run locally (stdio mode)
npm run start

# Run locally (HTTP mode)
npm run start:http

# Development mode with auto-reload
npm run dev          # stdio mode
npm run dev:http     # HTTP mode

# Run tests
npm test
```

## 🚀 Deployment Commands

```bash
# Quick deployment to Cloud Run
./deploy.sh YOUR_PROJECT_ID us-central1

# Build Docker image locally
docker build -t google-docs-mcp .

# Test Docker image locally
docker run -p 8080:8080 \
  -e GOOGLE_CREDENTIALS="$(cat credentials.json)" \
  -e GOOGLE_TOKEN="$(cat token.json)" \
  google-docs-mcp

# Manual Cloud Run deployment
gcloud builds submit --tag gcr.io/PROJECT_ID/google-docs-mcp
gcloud run deploy google-docs-mcp --image gcr.io/PROJECT_ID/google-docs-mcp
```

## 📊 Monitoring & Logs

### Local Mode
```bash
# Logs printed to stderr
node dist/server.js
```

### Cloud Run Mode
```bash
# View recent logs
gcloud run services logs read google-docs-mcp --region us-central1 --limit 50

# Stream logs in real-time
gcloud run services logs tail google-docs-mcp --region us-central1

# View in Cloud Console
# https://console.cloud.google.com/run
```

## 🧪 Testing

### Test Local Server
```bash
npm run build
node dist/server.js
# Use with Claude Desktop
```

### Test HTTP Server Locally
```bash
npm run build
npm run start:http
# curl http://localhost:8080/health
```

### Test Cloud Run Deployment
```bash
SERVICE_URL=$(gcloud run services describe google-docs-mcp --region us-central1 --format 'value(status.url)')
curl $SERVICE_URL/health
curl $SERVICE_URL/sse
```

## 💰 Cost Management

### Cloud Run Pricing
- CPU: ~$0.000024/vCPU-second
- Memory: ~$0.0000025/GiB-second  
- Requests: $0.40/million
- **Free tier**: 2M requests/month

### Typical Monthly Costs
- **Light usage** (10K requests): Free tier
- **Moderate** (100K requests): $1-3
- **Heavy** (1M requests): $5-15

### Cost Optimization
```bash
# Set max instances
gcloud run deploy google-docs-mcp --max-instances 5

# Use minimum memory
gcloud run deploy google-docs-mcp --memory 512Mi

# Enable CPU throttling
gcloud run deploy google-docs-mcp --cpu-throttling
```

## 🔧 Configuration

### Environment Variables (Cloud Run)
- `PORT`: HTTP server port (set by Cloud Run)
- `GOOGLE_CREDENTIALS`: OAuth credentials JSON
- `GOOGLE_TOKEN`: OAuth token JSON
- `NODE_ENV`: Set to "production"

### Cloud Run Settings
Configured in `deploy.sh` or manually:
- Memory: 512Mi (configurable)
- CPU: 1 (configurable)
- Timeout: 300 seconds
- Max instances: 10
- Concurrency: 80 (default)

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📝 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- Original MCP server: [google-docs-mcp](https://github.com/a-bonus/google-docs-mcp)
- FastMCP library: [fastmcp](https://github.com/jlowin/fastmcp)
- Model Context Protocol: [modelcontextprotocol.io](https://modelcontextprotocol.io/)

## 🐛 Troubleshooting

**Issue**: Can't decide which mode to use?
- Use **Local Mode** if you only need Claude Desktop integration
- Use **Cloud Run Mode** if you need web access or multiple clients

**Issue**: Deployment fails?
- Check [SETUP_NOTES.md](SETUP_NOTES.md) troubleshooting section
- Verify credentials are valid
- Ensure all tools are copied to `server-http.ts`

**Issue**: High costs?
- Review actual usage in Cloud Console
- Reduce max instances
- Enable CPU throttling
- Consider min-instances=0 for development

## 📧 Support

- 📖 Check documentation in this repo
- 🐛 [Open an issue](https://github.com/a-bonus/google-docs-mcp/issues)
- 💬 Discussion forum (if available)

---

**Ready to get started?**

- 🏠 Local development → [README.md](README.md)
- ☁️ Cloud Run deployment → [QUICKSTART_CLOUDRUN.md](QUICKSTART_CLOUDRUN.md)
- 📚 Full documentation → [CLOUD_RUN_DEPLOYMENT.md](CLOUD_RUN_DEPLOYMENT.md)

Happy coding! 🚀

