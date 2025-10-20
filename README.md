# Google Docs MCP Server for Salesforce Agentforce

![Demo Animation](assets/google.docs.mcp.1.gif)

Connect your Salesforce Agentforce agents to Google Docs and Google Drive through the Model Context Protocol (MCP)!

> 🚀 **Quick Start:** See [AGENTFORCE_QUICKSTART.md](AGENTFORCE_QUICKSTART.md) for a 5-minute setup guide
> 
> 📁 **Cloud Deployment:** Check out [README_CLOUDRUN.md](README_CLOUDRUN.md) for Google Cloud Run deployment

## Overview

This repository provides a complete MCP (Model Context Protocol) server that enables Salesforce Agentforce agents to interact with Google Docs and Google Drive. The server acts as a bridge between Agentforce's Invocable Apex actions and the Google Workspace APIs.

**Architecture:**
```
Salesforce Agentforce → GoogleDocsMCPInvoker (Apex) → GoogleDocsMCPHandler → 
MCP Server (Cloud Run) → Google Workspace APIs
```

---

## Features

- **Document Operations:** Read, create, append, insert, delete, and search documents
- **Formatting:** Apply text styling (bold, italic, colors) and paragraph formatting
- **Structure:** Create tables, insert images, add page breaks
- **Comments:** List, add, reply, resolve, and delete comments
- **Drive Management:** List, search, move, copy, rename files and folders

---

## Prerequisites

- **Salesforce Org** with Agentforce enabled
- **Google Cloud Project** with billing enabled and service account credentials
- **Node.js 18+** and npm
- **gcloud CLI** (for Cloud Run deployment)

---

## Quick Start

### 1. Deploy the MCP Server to Google Cloud Run

```bash
# Clone this repository
git clone https://github.com/aaronroan/agentforce-mcp-demo.git
cd agentforce-mcp-demo

# Deploy to Cloud Run
./deploy.sh YOUR_PROJECT_ID us-central1
```

See [README_CLOUDRUN.md](README_CLOUDRUN.md) for detailed deployment instructions.

### 2. Set Up Google Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable **Google Docs API** and **Google Drive API**
3. Create a Service Account with appropriate permissions
4. Download the service account JSON key
5. Upload it to Salesforce as a Static Resource named `GoogleJSON`

### 3. Configure Salesforce

#### Enable Remote Site Settings

1. Setup → **Remote Site Settings** → **New Remote Site**
2. Configure:
   - **Name:** `GoogleDocsMCP`
   - **URL:** `https://google-docs-mcp-rest-403993907509.us-central1.run.app`
   - **Active:** ✅ Checked

#### Deploy Apex Classes

Deploy the two Apex classes to your Salesforce org:

```bash
sfdx force:source:deploy -p apex/ -u YOUR_ORG_ALIAS
```

Or use VS Code with Salesforce Extensions to deploy the `apex/` folder.

#### Add Action to Agentforce

1. Setup → **Agentforce** → **Actions** → **New Action** → **Apex Action**
2. Select: **`GoogleDocsMCPInvoker.callMCPTool`**
3. Configure the action inputs:
   - **Tool Name** - The MCP tool to call (e.g., `readGoogleDoc`, `createDocument`)
   - **Arguments** - JSON string with tool arguments
4. Add the action to your Agentforce agent

**📚 Full setup guide:** [AGENTFORCE_QUICKSTART.md](AGENTFORCE_QUICKSTART.md)

---

## Apex Classes

This repo includes **two Apex classes** in the `apex/` folder:

### `GoogleDocsMCPInvoker.cls`
**The Invocable action** that Agentforce calls. Contains the `@InvocableMethod` that accepts:
- `toolName` - Name of the MCP tool to call (e.g., `readGoogleDoc`, `createDocument`)
- `arguments` - JSON string with tool parameters

Returns a `Response` object with `responseMessage` containing the MCP server result.

### `GoogleDocsMCPHandler.cls`
**The handler class** that:
- Authenticates with Google Cloud Run using service account credentials from `GoogleJSON` static resource
- Makes authenticated HTTP callouts to the MCP server endpoint
- Parses and returns responses from the MCP server
- Includes convenience methods: `readGoogleDoc()`, `createGoogleDoc()`, `appendToGoogleDoc()`, `searchGoogleDocs()`

---

## Available MCP Tools

You can call any of these tools through the `MCPAgentInvoker` action:

| Tool Name | Purpose | Example Arguments |
|-----------|---------|-------------------|
| `readGoogleDoc` | Read document content | `{"documentId":"1abc...xyz"}` |
| `createDocument` | Create new document | `{"title":"My Document"}` |
| `appendToGoogleDoc` | Add text to document | `{"documentId":"1abc","text":"Hello"}` |
| `searchGoogleDocs` | Search for documents | `{"query":"Q4 planning"}` |
| `applyTextStyle` | Format text | `{"documentId":"1abc","startIndex":1,"endIndex":10,"bold":true}` |
| `insertTable` | Create table | `{"documentId":"1abc","rows":3,"columns":4}` |
| `listGoogleDocs` | List documents | `{"maxResults":10}` |

---

## Usage Example

**User prompt to Agentforce:**
> "Find all documents about Q4 planning and create a summary document"

**Agent workflow:**
1. Calls `GoogleDocsMCPInvoker` with:
   - toolName: `searchGoogleDocs`
   - arguments: `{"query":"Q4 planning"}`
2. Calls `GoogleDocsMCPInvoker` for each document with:
   - toolName: `readGoogleDoc`
   - arguments: `{"documentId":"..."}`
3. AI generates summary
4. Calls `GoogleDocsMCPInvoker` with:
   - toolName: `createDocument`
   - arguments: `{"title":"Q4 Planning Summary"}`
5. Calls `GoogleDocsMCPInvoker` with:
   - toolName: `appendToGoogleDoc`
   - arguments: `{"documentId":"...","text":"Summary content..."}`

---

## Project Structure

```
agentforce-mcp-demo/
├── apex/
│   ├── GoogleDocsMCPInvoker.cls         # Invocable action for Agentforce
│   ├── GoogleDocsMCPHandler.cls         # Handler with authentication
│   ├── *.cls-meta.xml                   # Salesforce metadata files
│   └── package.xml                      # Package manifest
├── src/                                  # TypeScript MCP server source
├── Dockerfile                            # Container definition
├── cloudbuild.yaml                       # Cloud Build config
├── deploy.sh                             # Deployment script
├── README.md                             # This file
├── README_CLOUDRUN.md                    # Cloud Run deployment guide
└── AGENTFORCE_QUICKSTART.md              # Quick setup guide
```

---

## Troubleshooting

**"Unauthorized endpoint" in Salesforce:**
- Verify Remote Site Settings includes your exact Cloud Run URL

**"Failed to get access token":**
- Ensure `GoogleJSON` static resource exists with valid service account JSON
- Verify service account has necessary permissions

**"Callout failed":**
- Test MCP server: `curl https://your-url/health`
- Check Cloud Run logs: `gcloud run services logs read google-docs-mcp`

**"Action doesn't appear in Agentforce":**
- Verify `MCPAgentInvoker.cls` is deployed with `@InvocableMethod` annotation
- Refresh Agentforce UI

---

## Resources

- **[Agentforce Quick Start](AGENTFORCE_QUICKSTART.md)** - 5-minute setup
- **[Cloud Run Deployment](README_CLOUDRUN.md)** - Deployment guide
- **[Model Context Protocol](https://modelcontextprotocol.io/)** - MCP spec
- **[Google Docs API](https://developers.google.com/docs/api)** - Official docs

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Ready to get started?** → [AGENTFORCE_QUICKSTART.md](AGENTFORCE_QUICKSTART.md)
