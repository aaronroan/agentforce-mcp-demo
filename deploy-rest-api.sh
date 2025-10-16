#!/bin/bash

# Deploy REST API wrapper with Google Cloud API Gateway
# This creates a REST API that wraps the MCP server for Salesforce integration

set -e

# Configuration
PROJECT_ID="ehc-aroan-17eb34"
REGION="us-central1"
SERVICE_NAME="google-docs-mcp-rest"
API_NAME="google-docs-mcp-api"
API_CONFIG_ID="google-docs-mcp-config"
API_GATEWAY_ID="google-docs-mcp-gateway"

echo "🚀 Deploying Google Docs MCP REST API with API Gateway"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Set project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "📋 Enabling required APIs..."
gcloud services enable run.googleapis.com
gcloud services enable apigateway.googleapis.com
gcloud services enable servicecontrol.googleapis.com
gcloud services enable secretmanager.googleapis.com

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build the REST API wrapper
echo "🏗️  Building REST API wrapper..."
npm run build:rest

# Create secrets if they don't exist
echo "🔐 Ensuring secrets exist..."
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
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

# Create a custom Dockerfile for the REST API
cat > Dockerfile << 'EOF'
FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force
RUN npm install -D typescript

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build:rest

# Clean up
RUN npm prune --production && \
    rm -rf src/ tsconfig.json

# Create non-root user
RUN useradd -m -u 1001 mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the REST API server
CMD ["node", "dist/rest-api-wrapper.js"]
EOF

gcloud builds submit --tag $IMAGE_NAME --project=$PROJECT_ID

# Deploy to Cloud Run
echo "🚀 Deploying REST API to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 1Gi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --set-secrets "GOOGLE_CREDENTIALS=google-docs-credentials:latest,GOOGLE_TOKEN=google-docs-token:latest" \
    --project=$PROJECT_ID

# Get the Cloud Run service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)")
echo "✅ Cloud Run service deployed at: $SERVICE_URL"

# Create API Gateway configuration
echo "🌐 Creating API Gateway configuration..."
# Extract hostname from URL
HOSTNAME=$(echo $SERVICE_URL | sed 's|https://||')
cat > api-config.yaml << EOF
swagger: "2.0"
info:
  title: Google Docs MCP REST API
  description: REST API wrapper for Google Docs MCP server
  version: 1.0.0
host: $HOSTNAME
schemes:
  - https
securityDefinitions:
  oauth2:
    type: oauth2
    flow: clientCredentials
    tokenUrl: https://oauth2.googleapis.com/token
    scopes:
      google-docs-mcp: Access Google Docs MCP API
security:
  - oauth2: [google-docs-mcp]
paths:
  /health:
    get:
      summary: Health check endpoint
      operationId: healthCheck
      responses:
        200:
          description: Service is healthy
  /api/docs/recent:
    post:
      summary: Get recent Google Docs
      operationId: getRecentDocs
      security:
        - oauth2: [google-docs-mcp]
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
            properties:
              maxResults:
                type: integer
                minimum: 1
                maximum: 50
                default: 10
              daysBack:
                type: integer
                minimum: 1
                maximum: 365
                default: 30
      responses:
        200:
          description: Recent Google Docs retrieved successfully
  /api/docs/read:
    post:
      summary: Read Google Doc content
      operationId: readDoc
      security:
        - oauth2: [google-docs-mcp]
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
            properties:
              documentId:
                type: string
                description: The ID of the Google Document
              maxLength:
                type: integer
                description: Maximum character limit for text output
            required:
              - documentId
      responses:
        200:
          description: Document content retrieved successfully
  /api/docs/search:
    post:
      summary: Search Google Docs
      operationId: searchDocs
      security:
        - oauth2: [google-docs-mcp]
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
            properties:
              searchQuery:
                type: string
                description: Search term to find in document names or content
              maxResults:
                type: integer
                minimum: 1
                maximum: 50
                default: 10
            required:
              - searchQuery
      responses:
        200:
          description: Search results retrieved successfully
  /api/mcp/call:
    post:
      summary: Generic MCP tool call
      operationId: mcpCall
      security:
        - oauth2: [google-docs-mcp]
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
            properties:
              toolName:
                type: string
                description: Name of the MCP tool to call
              arguments:
                type: object
                description: Arguments to pass to the tool
            required:
              - toolName
      responses:
        200:
          description: Tool executed successfully
  /api/mcp/tools:
    get:
      summary: List available MCP tools
      operationId: listTools
      security:
        - oauth2: [google-docs-mcp]
      responses:
        200:
          description: Tools listed successfully
EOF

# Create API Gateway
echo "🌐 Creating API Gateway..."
gcloud api-gateway api-configs create $API_CONFIG_ID \
    --api=$API_NAME \
    --openapi-spec=api-config.yaml \
    --project=$PROJECT_ID \
    --backend-auth-service-account=403993907509-compute@developer.gserviceaccount.com

# Create API Gateway
gcloud api-gateway gateways create $API_GATEWAY_ID \
    --api=$API_NAME \
    --api-config=$API_CONFIG_ID \
    --location=$REGION \
    --project=$PROJECT_ID

# Get the API Gateway URL
API_GATEWAY_URL=$(gcloud api-gateway gateways describe $API_GATEWAY_ID --location=$REGION --project=$PROJECT_ID --format="value(defaultHostname)")
echo "✅ API Gateway deployed at: https://$API_GATEWAY_URL"

# Grant necessary permissions
echo "🔑 Setting up permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:403993907509-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Test the API
echo "🧪 Testing the API..."
echo "Health check: https://$API_GATEWAY_URL/health"
echo "Recent docs: https://$API_GATEWAY_URL/api/docs/recent"
echo "Search docs: https://$API_GATEWAY_URL/api/docs/search"
echo "List tools: https://$API_GATEWAY_URL/api/mcp/tools"

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📋 Next steps for Salesforce integration:"
echo "1. Create a Named Credential in Salesforce with OAuth 2.0"
echo "2. Use the API Gateway URL: https://$API_GATEWAY_URL"
echo "3. Configure the OAuth 2.0 flow for client credentials"
echo "4. Test the integration with Agentforce"
echo ""
echo "🔗 API Documentation: https://$API_GATEWAY_URL"
echo "🔗 Cloud Run Service: $SERVICE_URL"
echo "🔗 API Gateway: https://$API_GATEWAY_URL"
