# Deploy to Cloud Run WITHOUT gcloud CLI

You can deploy your MCP server to Google Cloud Run without installing the gcloud CLI locally. Here are three methods:

## 🌐 Method 1: Cloud Shell (Recommended)

**Cloud Shell** is a free, browser-based terminal with gcloud CLI pre-installed. This is the easiest method!

### Step 1: Open Cloud Shell

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click the **Cloud Shell** icon (>_) in the top-right corner
3. A terminal will open at the bottom of your browser

### Step 2: Upload Your Files

In Cloud Shell terminal:

```bash
# Clone your repository (if it's on GitHub)
git clone https://github.com/YOUR_USERNAME/agentforce-mcp-demo.git
cd agentforce-mcp-demo

# OR upload files manually:
# 1. Click the "More" (⋮) menu in Cloud Shell
# 2. Select "Upload"
# 3. Upload: credentials.json, token.json, and your project files
```

### Step 3: Upload Credentials

Since `credentials.json` and `token.json` aren't in git, upload them separately:

```bash
# In Cloud Shell, click "Upload" button
# Upload credentials.json and token.json to the project directory

# Verify files are uploaded
ls -la credentials.json token.json
```

### Step 4: Deploy

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Run the deployment script
chmod +x deploy.sh
./deploy.sh YOUR_PROJECT_ID us-central1
```

That's it! Cloud Shell has everything pre-configured.

---

## 🖥️ Method 2: Google Cloud Console UI

Deploy entirely through the web interface - no terminal needed!

### Step 1: Create Container Image

You'll need to build your Docker image first. Options:

**Option A: Use Cloud Shell to build only**
```bash
# In Cloud Shell
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/google-docs-mcp
```

**Option B: Build locally with Docker**
```bash
# If you have Docker installed locally
docker build -t gcr.io/YOUR_PROJECT_ID/google-docs-mcp .
docker push gcr.io/YOUR_PROJECT_ID/google-docs-mcp
```

### Step 2: Create Secrets via Console

1. Go to [Secret Manager](https://console.cloud.google.com/security/secret-manager)
2. Click **"CREATE SECRET"**
3. Create first secret:
   - Name: `google-docs-credentials`
   - Secret value: Paste contents of `credentials.json`
   - Click **"CREATE SECRET"**
4. Create second secret:
   - Name: `google-docs-token`
   - Secret value: Paste contents of `token.json`
   - Click **"CREATE SECRET"**

### Step 3: Deploy via Console

1. Go to [Cloud Run](https://console.cloud.google.com/run)
2. Click **"CREATE SERVICE"**
3. Configure:
   - **Container image URL**: `gcr.io/YOUR_PROJECT_ID/google-docs-mcp`
   - **Service name**: `google-docs-mcp`
   - **Region**: `us-central1` (or your choice)
   - **Authentication**: Allow unauthenticated invocations
   
4. Click **"CONTAINER, VARIABLES & SECRETS, CONNECTIONS, SECURITY"**
   
5. Go to **"VARIABLES & SECRETS"** tab:
   - Click **"REFERENCE A SECRET"**
   - Secret: `google-docs-credentials`
   - Reference method: "Exposed as environment variable"
   - Name: `GOOGLE_CREDENTIALS`
   - Click **"DONE"**
   
   - Click **"REFERENCE A SECRET"** again
   - Secret: `google-docs-token`
   - Reference method: "Exposed as environment variable"
   - Name: `GOOGLE_TOKEN`
   - Click **"DONE"**

6. Configure **"CONTAINER"** tab:
   - Port: `8080`
   - Memory: `512 MiB`
   - CPU: `1`
   - Request timeout: `300` seconds
   - Maximum requests per container: `80`

7. Click **"CREATE"**

Your service will deploy in 1-2 minutes!

---

## 🤖 Method 3: GitHub Actions (Automated)

Set up automatic deployments on every git push - no manual deployment needed!

### Step 1: Set Up Workload Identity Federation

This allows GitHub Actions to authenticate with Google Cloud without storing credentials.

1. Go to [IAM & Admin > Workload Identity Federation](https://console.cloud.google.com/iam-admin/workload-identity-pools)
2. Follow Google's guide: [Setting up Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)

### Step 2: Add Secrets to GitHub

In your GitHub repository:

1. Go to **Settings > Secrets and variables > Actions**
2. Add these secrets:
   - `GCP_PROJECT_ID`: Your Google Cloud project ID
   - `GCP_SA_KEY`: Service account key JSON (if not using Workload Identity)
   - `GOOGLE_CREDENTIALS`: Contents of `credentials.json`
   - `GOOGLE_TOKEN`: Contents of `token.json`

### Step 3: Create GitHub Actions Workflow

Create `.github/workflows/deploy-cloudrun.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  SERVICE_NAME: google-docs-mcp
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          export_default_credentials: true
      
      - name: Create secrets in Secret Manager
        run: |
          # Create credentials secret
          echo '${{ secrets.GOOGLE_CREDENTIALS }}' | gcloud secrets create google-docs-credentials \
            --data-file=- --replication-policy=automatic || \
          echo '${{ secrets.GOOGLE_CREDENTIALS }}' | gcloud secrets versions add google-docs-credentials \
            --data-file=-
          
          # Create token secret
          echo '${{ secrets.GOOGLE_TOKEN }}' | gcloud secrets create google-docs-token \
            --data-file=- --replication-policy=automatic || \
          echo '${{ secrets.GOOGLE_TOKEN }}' | gcloud secrets versions add google-docs-token \
            --data-file=-
      
      - name: Build and push container
        run: |
          gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy $SERVICE_NAME \
            --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
            --platform managed \
            --region $REGION \
            --allow-unauthenticated \
            --port 8080 \
            --memory 512Mi \
            --cpu 1 \
            --timeout 300 \
            --max-instances 10 \
            --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest"
      
      - name: Show service URL
        run: |
          gcloud run services describe $SERVICE_NAME \
            --region $REGION \
            --format 'value(status.url)'
```

Now every push to `main` branch will automatically deploy!

---

## 📊 Comparison

| Method | Difficulty | Speed | Best For |
|--------|-----------|-------|----------|
| **Cloud Shell** | ⭐ Easy | 🚀 Fast (5 min) | One-time deployment, testing |
| **Console UI** | ⭐⭐ Medium | 🐢 Slow (15 min) | Visual learners, one-time setup |
| **GitHub Actions** | ⭐⭐⭐ Advanced | ⚡ Automatic | Continuous deployment, teams |

---

## 🎯 Recommended Approach

**For most users: Use Cloud Shell (Method 1)**

Why?
- ✅ No local installation required
- ✅ gcloud CLI pre-installed and authenticated
- ✅ Free to use
- ✅ Same commands as local deployment
- ✅ Can use the deploy.sh script as-is

---

## 📝 Step-by-Step: Cloud Shell Deployment

Here's the complete walkthrough using Cloud Shell:

### 1. Open Cloud Shell

Go to https://console.cloud.google.com and click the terminal icon (>_)

### 2. Upload Your Project

```bash
# If your code is on GitHub
git clone https://github.com/YOUR_USERNAME/agentforce-mcp-demo.git
cd agentforce-mcp-demo

# If not, create directory and upload files
mkdir agentforce-mcp-demo
cd agentforce-mcp-demo
```

### 3. Upload Credentials

Click "Upload" in Cloud Shell menu:
- Upload `credentials.json`
- Upload `token.json`

Or create them manually:
```bash
# Create credentials.json
cat > credentials.json << 'EOF'
{paste your credentials JSON here}
EOF

# Create token.json
cat > token.json << 'EOF'
{paste your token JSON here}
EOF
```

### 4. Install Dependencies

```bash
npm install
```

### 5. Complete server-http.ts

```bash
# Copy all tools from server.ts to server-http.ts
# Use the Cloud Shell editor:
cloudshell edit src/server-http.ts

# Or use vim/nano if you prefer
```

### 6. Build

```bash
npm run build
```

### 7. Deploy

```bash
# Set your project
export PROJECT_ID=$(gcloud config get-value project)

# Make scripts executable
chmod +x deploy.sh prepare-cloudrun.sh

# Run deployment
./deploy.sh $PROJECT_ID us-central1
```

### 8. Test

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe google-docs-mcp \
  --region us-central1 \
  --format 'value(status.url)')

# Test health endpoint
curl $SERVICE_URL/health

# View logs
gcloud run services logs read google-docs-mcp --region us-central1 --limit 20
```

---

## 🔑 Cloud Shell Tips

### Persist Files

Cloud Shell resets after inactivity. To persist files:

```bash
# Store files in $HOME (persistent)
cp credentials.json token.json $HOME/

# Or commit to git (but don't commit credentials!)
git add .
git commit -m "Add deployment files"
git push
```

### Reconnect After Timeout

If Cloud Shell disconnects:

```bash
cd agentforce-mcp-demo  # or your project directory
# Continue from where you left off
```

### Edit Files

```bash
# Use built-in editor
cloudshell edit src/server-http.ts

# Or vim
vim src/server-http.ts

# Or nano
nano src/server-http.ts
```

### Download Files

```bash
# Download logs or other files to your computer
cloudshell download filename.txt
```

---

## 🚨 Common Issues

### Issue: "Project not set"

```bash
# List available projects
gcloud projects list

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Issue: "Permission denied on upload"

Upload to your home directory first:
```bash
cd ~
# Upload files here
mv credentials.json token.json ~/agentforce-mcp-demo/
```

### Issue: "Session timed out"

Cloud Shell times out after 20 minutes of inactivity:
- Files in $HOME are preserved
- Just reconnect and `cd` back to your directory

### Issue: "Cannot find credentials.json"

```bash
# Check current directory
pwd

# List files
ls -la

# Navigate to correct directory
cd ~/agentforce-mcp-demo
```

---

## 💡 Pro Tips

### Use Cloud Shell Editor

Cloud Shell has a built-in VS Code-like editor:
```bash
cloudshell edit .
```

### Transfer Files from Local Machine

```bash
# Upload via Cloud Shell UI
# Click "⋮" > "Upload"

# Or use gcloud from local machine (if you decide to install it later)
gcloud cloud-shell scp local-file.txt cloudshell:~/destination/
```

### Boost Cloud Shell

For complex builds, boost Cloud Shell performance:
```bash
cloudshell boost
# Increases CPU/memory temporarily
```

### Use Cloud Shell as Code Editor

Open Cloud Shell Editor (full IDE):
- Go to https://ide.cloud.google.com
- Full VS Code experience in browser
- Integrated terminal with gcloud CLI

---

## ✅ Success Checklist

After deployment via Cloud Shell:

- [ ] Service deployed successfully
- [ ] Health endpoint returns "OK"
- [ ] Secrets are accessible (check logs)
- [ ] Service URL is accessible
- [ ] No errors in Cloud Run logs
- [ ] MCP tools work correctly

---

## 📚 Additional Resources

- [Cloud Shell Documentation](https://cloud.google.com/shell/docs)
- [Cloud Run Console UI](https://cloud.google.com/run/docs/deploying#console)
- [Secret Manager in Console](https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets)
- [GitHub Actions for Cloud Run](https://cloud.google.com/community/tutorials/cicd-cloud-run-github-actions)

---

## 🎉 You're Ready!

**Recommended: Start with Cloud Shell**
1. Open https://console.cloud.google.com
2. Click the terminal icon (>_)
3. Follow the "Step-by-Step: Cloud Shell Deployment" section above
4. You'll be deployed in ~10 minutes!

No local gcloud CLI installation required! 🚀

