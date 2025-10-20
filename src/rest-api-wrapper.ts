// src/rest-api-wrapper.ts
// REST API wrapper for MCP server to integrate with Salesforce Agentforce
import express from 'express';
import cors from 'cors';
import { authorize } from './auth-cloudrun.js';
import { google, docs_v1, drive_v3 } from 'googleapis';
import { OAuth2Client } from 'google-auth-library';

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Google API client
let authClient: OAuth2Client | null = null;
let googleDocs: docs_v1.Docs | null = null;
let googleDrive: drive_v3.Drive | null = null;

async function initializeGoogleClient() {
  if (googleDocs && googleDrive) return { authClient, googleDocs, googleDrive };
  
  try {
    console.error("Initializing Google API client...");
    authClient = await authorize();
    googleDocs = google.docs({ version: 'v1', auth: authClient });
    googleDrive = google.drive({ version: 'v3', auth: authClient });
    console.error("Google API client initialized successfully.");
    return { authClient, googleDocs, googleDrive };
  } catch (error) {
    console.error("Failed to initialize Google API client:", error);
    throw error;
  }
}

// Tool implementations (simplified for REST API)
async function getRecentGoogleDocs(args: any) {
  try {
    const { maxResults = 10, daysBack = 30 } = args;
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysBack);
    
    const response = await googleDrive!.files.list({
      q: `mimeType='application/vnd.google-apps.document' and modifiedTime >= '${cutoffDate.toISOString()}'`,
      orderBy: 'modifiedTime desc',
      pageSize: maxResults,
      fields: 'files(id,name,modifiedTime,owners,webViewLink)'
    });
    
    const docs = response.data.files || [];
    const formattedDocs = docs.map((doc, index) => {
      const modifiedTime = new Date(doc.modifiedTime || '');
      const owner = doc.owners?.[0]?.displayName || 'Unknown';
      
      return `${index + 1}. **${doc.name}**\n   ID: ${doc.id}\n   Last Modified: ${modifiedTime.toLocaleString()} by ${owner}\n   Link: ${doc.webViewLink}`;
    }).join('\n\n');
    
    return `Recently modified Google Document(s) (last ${daysBack} days):\n\n${formattedDocs}`;
  } catch (error: any) {
    throw new Error(`Failed to get recent docs: ${error.message}`);
  }
}

async function readGoogleDoc(args: any) {
  try {
    const { documentId, maxLength } = args;
    const doc = await googleDocs!.documents.get({ documentId });
    
    let textContent = '';
    doc.data.body?.content?.forEach((element: any) => {
      if (element.paragraph) {
        element.paragraph.elements?.forEach((pe: any) => {
          if (pe.textRun) {
            textContent += pe.textRun.content;
          }
        });
      }
    });
    
    if (maxLength && textContent.length > maxLength) {
      textContent = textContent.substring(0, maxLength) + '...';
    }
    
    return `Document Content:\n---\n${textContent}`;
  } catch (error: any) {
    throw new Error(`Failed to read document: ${error.message}`);
  }
}

async function searchGoogleDocs(args: any) {
  try {
    const { searchQuery, maxResults = 10 } = args;
    
    const response = await googleDrive!.files.list({
      q: `mimeType='application/vnd.google-apps.document' and (name contains '${searchQuery}' or fullText contains '${searchQuery}')`,
      pageSize: maxResults,
      fields: 'files(id,name,modifiedTime,owners,webViewLink)'
    });
    
    const docs = response.data.files || [];
    const formattedDocs = docs.map((doc, index) => {
      const modifiedTime = new Date(doc.modifiedTime || '');
      const owner = doc.owners?.[0]?.displayName || 'Unknown';
      
      return `${index + 1}. **${doc.name}**\n   ID: ${doc.id}\n   Last Modified: ${modifiedTime.toLocaleString()} by ${owner}\n   Link: ${doc.webViewLink}`;
    }).join('\n\n');
    
    return `Search results for "${searchQuery}":\n\n${formattedDocs}`;
  } catch (error: any) {
    throw new Error(`Failed to search documents: ${error.message}`);
  }
}

async function createDocument(args: any) {
  try {
    const { title } = args;
    
    if (!title) {
      throw new Error('title is required');
    }
    
    const response = await googleDocs!.documents.create({
      requestBody: {
        title: title
      }
    });
    
    const docId = response.data.documentId;
    const docTitle = response.data.title;
    
    return `Created document: "${docTitle}"\nDocument ID: ${docId}\nView: https://docs.google.com/document/d/${docId}/edit`;
  } catch (error: any) {
    throw new Error(`Failed to create document: ${error.message}`);
  }
}

// Available tools registry
const tools = {
  getRecentGoogleDocs: {
    name: 'getRecentGoogleDocs',
    description: 'Gets the most recently modified Google Documents',
    execute: getRecentGoogleDocs
  },
  readGoogleDoc: {
    name: 'readGoogleDoc',
    description: 'Reads the content of a specific Google Document',
    execute: readGoogleDoc
  },
  searchGoogleDocs: {
    name: 'searchGoogleDocs',
    description: 'Searches for Google Documents by name or content',
    execute: searchGoogleDocs
  },
  createDocument: {
    name: 'createDocument',
    description: 'Creates a new Google Document',
    execute: createDocument
  }
};

// REST API Endpoints

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Get recent Google Docs
app.post('/api/docs/recent', async (req, res) => {
  try {
    await initializeGoogleClient();
    const result = await getRecentGoogleDocs(req.body);
    res.json({ success: true, data: result });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Read Google Doc
app.post('/api/docs/read', async (req, res) => {
  try {
    await initializeGoogleClient();
    const result = await readGoogleDoc(req.body);
    res.json({ success: true, data: result });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Search Google Docs
app.post('/api/docs/search', async (req, res) => {
  try {
    await initializeGoogleClient();
    const result = await searchGoogleDocs(req.body);
    res.json({ success: true, data: result });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Generic MCP tool call endpoint
app.post('/api/mcp/call', async (req, res) => {
  try {
    console.log('Received request:', JSON.stringify(req.body));
    const { toolName, arguments: toolArgs } = req.body;
    
    if (!toolName) {
      return res.status(400).json({ success: false, error: 'toolName is required' });
    }
    
    const tool = tools[toolName as keyof typeof tools];
    if (!tool) {
      return res.status(404).json({ success: false, error: `Tool '${toolName}' not found` });
    }
    
    console.log(`Calling tool: ${toolName} with args:`, JSON.stringify(toolArgs));
    await initializeGoogleClient();
    const result = await tool.execute(toolArgs || {});
    console.log(`Tool ${toolName} result:`, result);
    res.json({ success: true, data: result });
  } catch (error: any) {
    console.error(`Error executing tool ${req.body.toolName}:`, error);
    res.status(500).json({ success: false, error: error.message, stack: error.stack });
  }
});

// List available tools
app.get('/api/mcp/tools', async (req, res) => {
  try {
    const toolList = Object.values(tools).map(tool => ({
      name: tool.name,
      description: tool.description
    }));
    res.json({ success: true, tools: toolList });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Start server
async function startServer() {
  try {
    await initializeGoogleClient();
    console.error(`Starting REST API wrapper on port ${PORT}...`);
    
    app.listen(PORT, () => {
      console.error(`REST API wrapper running on port ${PORT}`);
      console.error(`Health check: http://localhost:${PORT}/health`);
      console.error(`API endpoints:`);
      console.error(`  POST /api/docs/recent - Get recent Google Docs`);
      console.error(`  POST /api/docs/read - Read a Google Doc`);
      console.error(`  POST /api/docs/search - Search Google Docs`);
      console.error(`  POST /api/mcp/call - Generic MCP tool call`);
      console.error(`  GET /api/mcp/tools - List available tools`);
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

startServer();
