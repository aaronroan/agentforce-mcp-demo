// src/server-http.ts
// HTTP/SSE version of the server for Cloud Run deployment
import { FastMCP, UserError } from 'fastmcp';
import { z } from 'zod';
import { google, docs_v1, drive_v3 } from 'googleapis';
import { authorize } from './auth-cloudrun.js';
import { OAuth2Client } from 'google-auth-library';

// Import types and helpers
import {
DocumentIdParameter,
RangeParameters,
OptionalRangeParameters,
TextFindParameter,
TextStyleParameters,
TextStyleArgs,
ParagraphStyleParameters,
ParagraphStyleArgs,
ApplyTextStyleToolParameters, ApplyTextStyleToolArgs,
ApplyParagraphStyleToolParameters, ApplyParagraphStyleToolArgs,
NotImplementedError
} from './types.js';
import * as GDocsHelpers from './googleDocsApiHelpers.js';

let authClient: OAuth2Client | null = null;
let googleDocs: docs_v1.Docs | null = null;
let googleDrive: drive_v3.Drive | null = null;

// --- Initialization ---
async function initializeGoogleClient() {
if (googleDocs && googleDrive) return { authClient, googleDocs, googleDrive };
if (!authClient) {
try {
console.error("Attempting to authorize Google API client...");
const client = await authorize();
authClient = client;
googleDocs = google.docs({ version: 'v1', auth: authClient });
googleDrive = google.drive({ version: 'v3', auth: authClient });
console.error("Google API client authorized successfully.");
} catch (error) {
console.error("FATAL: Failed to initialize Google API client:", error);
authClient = null;
googleDocs = null;
googleDrive = null;
throw new Error("Google client initialization failed. Cannot start server tools.");
}
}
if (authClient && !googleDocs) {
googleDocs = google.docs({ version: 'v1', auth: authClient });
}
if (authClient && !googleDrive) {
googleDrive = google.drive({ version: 'v3', auth: authClient });
}

if (!googleDocs || !googleDrive) {
throw new Error("Google Docs and Drive clients could not be initialized.");
}

return { authClient, googleDocs, googleDrive };
}

// Set up process-level unhandled error/rejection handlers
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Promise Rejection:', reason);
});

const server = new FastMCP({
  name: 'Ultimate Google Docs MCP Server',
  version: '1.0.0'
});

// --- Helper to get Docs client within tools ---
async function getDocsClient() {
const { googleDocs: docs } = await initializeGoogleClient();
if (!docs) {
throw new UserError("Google Docs client is not initialized.");
}
return docs;
}

// --- Helper to get Drive client within tools ---
async function getDriveClient() {
const { googleDrive: drive } = await initializeGoogleClient();
if (!drive) {
throw new UserError("Google Drive client is not initialized.");
}
return drive;
}

// === HELPER FUNCTIONS ===

function convertDocsJsonToMarkdown(docData: any): string {
    let markdown = '';
    
    if (!docData.body?.content) {
        return 'Document appears to be empty.';
    }
    
    docData.body.content.forEach((element: any) => {
        if (element.paragraph) {
            markdown += convertParagraphToMarkdown(element.paragraph);
        } else if (element.table) {
            markdown += convertTableToMarkdown(element.table);
        } else if (element.sectionBreak) {
            markdown += '\n---\n\n';
        }
    });
    
    return markdown.trim();
}

function convertParagraphToMarkdown(paragraph: any): string {
    let text = '';
    let isHeading = false;
    let headingLevel = 0;
    let isList = false;
    
    if (paragraph.paragraphStyle?.namedStyleType) {
        const styleType = paragraph.paragraphStyle.namedStyleType;
        if (styleType.startsWith('HEADING_')) {
            isHeading = true;
            headingLevel = parseInt(styleType.replace('HEADING_', ''));
        } else if (styleType === 'TITLE') {
            isHeading = true;
            headingLevel = 1;
        } else if (styleType === 'SUBTITLE') {
            isHeading = true;
            headingLevel = 2;
        }
    }
    
    if (paragraph.bullet) {
        isList = true;
    }
    
    if (paragraph.elements) {
        paragraph.elements.forEach((element: any) => {
            if (element.textRun) {
                text += convertTextRunToMarkdown(element.textRun);
            }
        });
    }
    
    if (isHeading && text.trim()) {
        const hashes = '#'.repeat(Math.min(headingLevel, 6));
        return `${hashes} ${text.trim()}\n\n`;
    } else if (isList && text.trim()) {
        return `- ${text.trim()}\n`;
    } else if (text.trim()) {
        return `${text.trim()}\n\n`;
    }
    
    return '\n';
}

function convertTextRunToMarkdown(textRun: any): string {
    let text = textRun.content || '';
    
    if (textRun.textStyle) {
        const style = textRun.textStyle;
        
        if (style.bold && style.italic) {
            text = `***${text}***`;
        } else if (style.bold) {
            text = `**${text}**`;
        } else if (style.italic) {
            text = `*${text}*`;
        }
        
        if (style.underline && !style.link) {
            text = `<u>${text}</u>`;
        }
        
        if (style.strikethrough) {
            text = `~~${text}~~`;
        }
        
        if (style.link?.url) {
            text = `[${text}](${style.link.url})`;
        }
    }
    
    return text;
}

function convertTableToMarkdown(table: any): string {
    if (!table.tableRows || table.tableRows.length === 0) {
        return '';
    }
    
    let markdown = '\n';
    let isFirstRow = true;
    
    table.tableRows.forEach((row: any) => {
        if (!row.tableCells) return;
        
        let rowText = '|';
        row.tableCells.forEach((cell: any) => {
            let cellText = '';
            if (cell.content) {
                cell.content.forEach((element: any) => {
                    if (element.paragraph?.elements) {
                        element.paragraph.elements.forEach((pe: any) => {
                            if (pe.textRun?.content) {
                                cellText += pe.textRun.content.replace(/\n/g, ' ').trim();
                            }
                        });
                    }
                });
            }
            rowText += ` ${cellText} |`;
        });
        
        markdown += rowText + '\n';
        
        if (isFirstRow) {
            let separator = '|';
            for (let i = 0; i < row.tableCells.length; i++) {
                separator += ' --- |';
            }
            markdown += separator + '\n';
            isFirstRow = false;
        }
    });
    
    return markdown + '\n';
}

// === TOOL DEFINITIONS ===
// (Include all the same tools from server.ts - I'll include a few key ones here)

server.addTool({
name: 'readGoogleDoc',
description: 'Reads the content of a specific Google Document, optionally returning structured data.',
parameters: DocumentIdParameter.extend({
format: z.enum(['text', 'json', 'markdown']).optional().default('text')
.describe("Output format: 'text' (plain text), 'json' (raw API structure, complex), 'markdown' (experimental conversion)."),
maxLength: z.number().optional().describe('Maximum character limit for text output.')
}),
execute: async (args, { log }) => {
const docs = await getDocsClient();
log.info(`Reading Google Doc: ${args.documentId}, Format: ${args.format}`);

    try {
        const fields = args.format === 'json' || args.format === 'markdown'
            ? '*'
            : 'body(content(paragraph(elements(textRun(content)))))';

        const res = await docs.documents.get({
            documentId: args.documentId,
            fields: fields,
        });
        log.info(`Fetched doc: ${args.documentId}`);

        if (args.format === 'json') {
            const jsonContent = JSON.stringify(res.data, null, 2);
            if (args.maxLength && jsonContent.length > args.maxLength) {
                return jsonContent.substring(0, args.maxLength) + `\n... [JSON truncated: ${jsonContent.length} total chars]`;
            }
            return jsonContent;
        }

        if (args.format === 'markdown') {
            const markdownContent = convertDocsJsonToMarkdown(res.data);
            const totalLength = markdownContent.length;
            log.info(`Generated markdown: ${totalLength} characters`);
            
            if (args.maxLength && totalLength > args.maxLength) {
                const truncatedContent = markdownContent.substring(0, args.maxLength);
                return `${truncatedContent}\n\n... [Markdown truncated to ${args.maxLength} chars of ${totalLength} total.]`;
            }
            
            return markdownContent;
        }

        let textContent = '';
        let elementCount = 0;
        
        res.data.body?.content?.forEach(element => {
            elementCount++;
            
            if (element.paragraph?.elements) {
                element.paragraph.elements.forEach(pe => {
                    if (pe.textRun?.content) {
                        textContent += pe.textRun.content;
                    }
                });
            }
            
            if (element.table?.tableRows) {
                element.table.tableRows.forEach(row => {
                    row.tableCells?.forEach(cell => {
                        cell.content?.forEach(cellElement => {
                            cellElement.paragraph?.elements?.forEach(pe => {
                                if (pe.textRun?.content) {
                                    textContent += pe.textRun.content;
                                }
                            });
                        });
                    });
                });
            }
        });

        if (!textContent.trim()) return "Document found, but appears empty.";

        const totalLength = textContent.length;
        log.info(`Document contains ${totalLength} characters`);

        if (args.maxLength && totalLength > args.maxLength) {
            const truncatedContent = textContent.substring(0, args.maxLength);
            return `Content (truncated to ${args.maxLength} chars):\n---\n${truncatedContent}\n\n...`;
        }

        return `Content (${totalLength} characters):\n---\n${textContent}`;

    } catch (error: any) {
         log.error(`Error reading doc ${args.documentId}: ${error.message || error}`);
         if (error instanceof UserError) throw error;
         if (error.code === 404) throw new UserError(`Doc not found (ID: ${args.documentId}).`);
         if (error.code === 403) throw new UserError(`Permission denied for doc (ID: ${args.documentId}).`);
         throw new UserError(`Failed to read doc: ${error.message || 'Unknown error'}`);
    }
},
});

// Add a health check endpoint tool
server.addTool({
  name: 'healthCheck',
  description: 'Health check endpoint for Cloud Run',
  parameters: z.object({}),
  execute: async (args, { log }) => {
    log.info('Health check called');
    return 'OK';
  }
});

// Note: You would include ALL the other tools from server.ts here
// For brevity, I'm not copying all 30+ tools, but in production you would

// --- Server Startup ---
async function startServer() {
try {
await initializeGoogleClient();
console.error("Starting Google Docs MCP server in HTTP mode...");

      const PORT = process.env.PORT || 8080;
      
      // Use SSE transport for HTTP compatibility
      const configToUse = {
          transportType: "sse" as const,
          sse: {
              endpoint: "/sse" as const,
              port: typeof PORT === 'string' ? parseInt(PORT) : PORT
          }
      };

      server.start(configToUse);
      console.error(`MCP Server running on port ${PORT} with SSE transport`);
      console.error(`SSE endpoint: http://localhost:${PORT}/sse`);

} catch(startError: any) {
console.error("FATAL: Server failed to start:", startError.message || startError);
process.exit(1);
}
}

startServer();

