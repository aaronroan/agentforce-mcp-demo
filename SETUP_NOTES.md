# Setup Notes for Cloud Run Deployment

## Important: Complete server-http.ts

The `src/server-http.ts` file currently contains only a **skeleton implementation** with a few sample tools. Before deploying to Cloud Run, you need to copy all tool definitions from `src/server.ts` to `src/server-http.ts`.

### Quick Steps to Complete server-http.ts

1. Open `src/server.ts` and `src/server-http.ts` side by side
2. Copy all tool definitions from `server.ts` starting after line 373 (after the `readGoogleDoc` tool)
3. Paste them into `server-http.ts` before the `startServer()` function
4. The tools to copy include:
   - `appendToGoogleDoc`
   - `insertText`
   - `deleteRange`
   - `applyTextStyle`
   - `applyParagraphStyle`
   - `insertTable`
   - `editTableCell`
   - `insertPageBreak`
   - `insertImageFromUrl`
   - `insertLocalImage`
   - `fixListFormatting`
   - All comment tools (`listComments`, `getComment`, `addComment`, etc.)
   - All Drive tools (`listGoogleDocs`, `searchGoogleDocs`, etc.)
   - All folder and file management tools

5. Update the import in `server-http.ts` to use `auth-cloudrun.ts`:
   ```typescript
   import { authorize } from './auth-cloudrun.js';
   ```

### Alternative: Refactor to Share Tools

A better long-term approach would be to:

1. Create a shared `tools.ts` file that exports all tool definitions
2. Import and use these tools in both `server.ts` and `server-http.ts`
3. This eliminates code duplication and makes maintenance easier

Example structure:
```typescript
// src/tools.ts
export function registerAllTools(server: FastMCP, getDocsClient, getDriveClient) {
  server.addTool({
    name: 'readGoogleDoc',
    // ... tool definition
  });
  
  server.addTool({
    name: 'appendToGoogleDoc',
    // ... tool definition
  });
  
  // ... all other tools
}

// src/server-http.ts
import { registerAllTools } from './tools.js';

// ... initialization code

registerAllTools(server, getDocsClient, getDriveClient);
```

## Authentication Configuration

The project now includes two authentication modules:

- **`auth.ts`**: Original file-based auth for local development
- **`auth-cloudrun.ts`**: Enhanced auth that supports both files and environment variables

The `auth-cloudrun.ts` module:
- Checks for `GOOGLE_CREDENTIALS` and `GOOGLE_TOKEN` environment variables first (Cloud Run)
- Falls back to `credentials.json` and `token.json` files (local development)
- Prevents interactive authentication in Cloud Run
- Automatically handles token refresh

## Environment Variables in Cloud Run

When deployed to Cloud Run, the following secrets are injected as environment variables:

- `GOOGLE_CREDENTIALS`: Contents of your `credentials.json` file
- `GOOGLE_TOKEN`: Contents of your `token.json` file
- `PORT`: Port number for the HTTP server (set by Cloud Run, default 8080)

These are configured in:
- `deploy.sh` script via `--set-secrets` flag
- `cloudbuild.yaml` in the deploy step

## Testing Locally Before Deployment

### Test with File-Based Auth (Current Setup)

```bash
npm run build
npm run start:http
```

### Test with Environment Variables (Simulating Cloud Run)

```bash
# Export secrets as environment variables
export GOOGLE_CREDENTIALS=$(cat credentials.json)
export GOOGLE_TOKEN=$(cat token.json)
export PORT=8080

# Run the server
npm run build
npm run start:http
```

### Test with Docker

```bash
# Build the image
docker build -t google-docs-mcp .

# Run with secrets from files
docker run -p 8080:8080 \
  -e GOOGLE_CREDENTIALS="$(cat credentials.json)" \
  -e GOOGLE_TOKEN="$(cat token.json)" \
  google-docs-mcp

# Test the endpoints
curl http://localhost:8080/health
curl http://localhost:8080/sse
```

## Pre-Deployment Checklist

Before running `./deploy.sh`, ensure:

- [ ] `credentials.json` exists and is valid
- [ ] `token.json` exists (run `node dist/server.js` once locally to generate)
- [ ] All tools are copied to `server-http.ts`
- [ ] `server-http.ts` imports from `auth-cloudrun.ts`
- [ ] You have a GCP project with billing enabled
- [ ] `gcloud` CLI is installed and authenticated
- [ ] You've tested locally with both file-based and env-var authentication
- [ ] You've updated the `PROJECT_ID` in the deploy command

## Deployment Command

```bash
# Simple deployment
./deploy.sh your-project-id us-central1

# Or manual deployment
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/google-docs-mcp
gcloud run deploy google-docs-mcp --image gcr.io/YOUR_PROJECT_ID/google-docs-mcp
```

## Post-Deployment Verification

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe google-docs-mcp \
  --region us-central1 \
  --format 'value(status.url)')

# Test health endpoint
curl $SERVICE_URL/health

# View logs
gcloud run services logs read google-docs-mcp --region us-central1 --limit 50

# Check if secrets are mounted
gcloud run services describe google-docs-mcp --region us-central1 \
  --format 'value(spec.template.spec.containers[0].env)'
```

## Troubleshooting Common Issues

### Issue: "Google client initialization failed"

**Cause**: Secrets not properly injected or invalid JSON in secrets

**Solution**:
```bash
# Verify secrets exist
gcloud secrets list

# Check secret content (first few characters)
gcloud secrets versions access latest --secret google-docs-credentials | head -c 100

# Update secrets if needed
gcloud secrets versions add google-docs-credentials --data-file=credentials.json
gcloud secrets versions add google-docs-token --data-file=token.json
```

### Issue: Container fails to start

**Cause**: Missing import or incomplete server-http.ts

**Solution**:
- Ensure all tools are copied from server.ts
- Check that auth-cloudrun.ts is properly imported
- Review Cloud Run logs for specific error messages

### Issue: "Port 8080 not listening"

**Cause**: Server not using the PORT environment variable

**Solution**:
- Verify server-http.ts reads `process.env.PORT`
- Check that port is passed correctly to FastMCP SSE configuration

### Issue: High memory usage or OOM

**Cause**: Memory limit too low for processing large documents

**Solution**:
```bash
gcloud run deploy google-docs-mcp --memory 1Gi
```

## Cost Optimization Tips

1. **Use minimum instances judiciously**: Each warm instance costs ~$1-2/month
2. **Set concurrency appropriately**: Default 80 is good for most cases
3. **Enable CPU throttling**: Reduces costs when idle
4. **Monitor usage**: Use Cloud Console to track actual usage
5. **Consider Cloud Run Jobs**: If you have batch processing needs

## Security Best Practices

1. **Never commit secrets**: `.gitignore` already includes `credentials.json` and `token.json`
2. **Use Secret Manager**: Secrets are encrypted at rest and in transit
3. **Rotate tokens**: Periodically regenerate OAuth tokens
4. **Enable VPC**: For production, consider using VPC Service Controls
5. **Implement authentication**: Don't leave `--allow-unauthenticated` in production
6. **Monitor access logs**: Set up Cloud Logging alerts for suspicious activity

## Next Steps

After successful deployment:

1. Test all MCP tools via the SSE endpoint
2. Set up monitoring and alerting
3. Configure CI/CD with Cloud Build triggers
4. Implement proper authentication for production use
5. Consider setting up a custom domain
6. Review and optimize costs after a few days of usage

## Additional Resources

- [FastMCP SSE Transport Documentation](https://github.com/jlowin/fastmcp)
- [Cloud Run Secrets Guide](https://cloud.google.com/run/docs/configuring/secrets)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)

