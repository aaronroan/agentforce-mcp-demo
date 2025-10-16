#!/bin/bash

# Simple API Gateway deployment without OAuth
# This creates a basic API Gateway for the REST API

set -e

PROJECT_ID="ehc-aroan-17eb34"
REGION="us-central1"
API_NAME="google-docs-mcp-api"
API_CONFIG_ID="google-docs-mcp-config-v2"
API_GATEWAY_ID="google-docs-mcp-gateway-v2"

echo "🌐 Creating simple API Gateway configuration..."

# Get the Cloud Run service URL
SERVICE_URL=$(gcloud run services describe google-docs-mcp-rest --region=$REGION --project=$PROJECT_ID --format="value(status.url)")
HOSTNAME=$(echo $SERVICE_URL | sed 's|https://||')

echo "Service URL: $SERVICE_URL"
echo "Hostname: $HOSTNAME"

# Create a simple API Gateway configuration without OAuth
cat > api-config-simple.yaml << EOF
swagger: "2.0"
info:
  title: Google Docs MCP REST API
  description: REST API wrapper for Google Docs MCP server
  version: 1.0.0
host: $HOSTNAME
schemes:
  - https
x-google-endpoints:
  - name: $HOSTNAME
    target: $SERVICE_URL
paths:
  /health:
    get:
      summary: Health check endpoint
      operationId: healthCheck
      responses:
        200:
          description: Service is healthy
          schema:
            type: object
            properties:
              status:
                type: string
                example: "OK"
              timestamp:
                type: string
                format: date-time
  /api/docs/recent:
    post:
      summary: Get recent Google Docs
      operationId: getRecentDocs
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
          schema:
            type: object
            properties:
              success:
                type: boolean
                example: true
              data:
                type: string
                description: Formatted list of recent documents
        500:
          description: Internal server error
  /api/docs/read:
    post:
      summary: Read Google Doc content
      operationId: readDoc
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
          schema:
            type: object
            properties:
              success:
                type: boolean
                example: true
              data:
                type: string
                description: Document content
        500:
          description: Internal server error
  /api/docs/search:
    post:
      summary: Search Google Docs
      operationId: searchDocs
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
          schema:
            type: object
            properties:
              success:
                type: boolean
                example: true
              data:
                type: string
                description: Formatted search results
        500:
          description: Internal server error
  /api/mcp/call:
    post:
      summary: Generic MCP tool call
      operationId: mcpCall
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
          schema:
            type: object
            properties:
              success:
                type: boolean
                example: true
              data:
                type: string
                description: Tool execution result
        500:
          description: Internal server error
  /api/mcp/tools:
    get:
      summary: List available MCP tools
      operationId: listTools
      responses:
        200:
          description: Tools listed successfully
          schema:
            type: object
            properties:
              success:
                type: boolean
                example: true
              tools:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    description:
                      type: string
        500:
          description: Internal server error
EOF

# Create API Gateway
echo "🌐 Creating API Gateway..."
gcloud api-gateway api-configs create $API_CONFIG_ID \
    --api=$API_NAME \
    --openapi-spec=api-config-simple.yaml \
    --project=$PROJECT_ID

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

# Test the API Gateway
echo "🧪 Testing the API Gateway..."
echo "Health check: https://$API_GATEWAY_URL/health"
echo "Recent docs: https://$API_GATEWAY_URL/api/docs/recent"
echo "Search docs: https://$API_GATEWAY_URL/api/docs/search"
echo "List tools: https://$API_GATEWAY_URL/api/mcp/tools"

echo ""
echo "🎉 API Gateway deployment complete!"
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
