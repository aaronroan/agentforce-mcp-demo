// src/auth-cloudrun.ts
// Enhanced auth for Cloud Run that supports both file-based and environment variable credentials
import { google } from 'googleapis';
import { OAuth2Client } from 'google-auth-library';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as readline from 'readline/promises';
import { fileURLToPath } from 'url';

// --- Calculate paths relative to this script file (ESM way) ---
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRootDir = path.resolve(__dirname, '..');

const TOKEN_PATH = path.join(projectRootDir, 'token.json');
const CREDENTIALS_PATH = path.join(projectRootDir, 'credentials.json');
// --- End of path calculation ---

const SCOPES = [
  'https://www.googleapis.com/auth/documents',
  'https://www.googleapis.com/auth/drive'
];

/**
 * Loads credentials from environment variables (Cloud Run secrets)
 * or falls back to file-based credentials
 */
async function loadCredentialsFromEnvOrFile(): Promise<{ credentials: any; token: any } | null> {
  // First, try loading from environment variables (Cloud Run)
  if (process.env.GOOGLE_CREDENTIALS && process.env.GOOGLE_TOKEN) {
    try {
      console.error('Loading credentials from environment variables...');
      const credentials = JSON.parse(process.env.GOOGLE_CREDENTIALS);
      const token = JSON.parse(process.env.GOOGLE_TOKEN);
      return { credentials, token };
    } catch (err) {
      console.error('Failed to parse credentials from environment:', err);
    }
  }

  // Fall back to file-based credentials (local development)
  try {
    console.error('Loading credentials from files...');
    const credContent = await fs.readFile(CREDENTIALS_PATH);
    const tokenContent = await fs.readFile(TOKEN_PATH);
    const credentials = JSON.parse(credContent.toString());
    const token = JSON.parse(tokenContent.toString());
    return { credentials, token };
  } catch (err) {
    console.error('Failed to load credentials from files:', err);
    return null;
  }
}

async function loadSavedCredentialsIfExist(): Promise<OAuth2Client | null> {
  try {
    const data = await loadCredentialsFromEnvOrFile();
    if (!data) return null;

    const { credentials, token } = data;
    const key = credentials.installed || credentials.web;
    if (!key) {
      console.error("Could not find client secrets in credentials.");
      return null;
    }

    const { client_id, client_secret, redirect_uris } = key;
    const client = new google.auth.OAuth2(
      client_id,
      client_secret,
      redirect_uris?.[0] || 'urn:ietf:wg:oauth:2.0:oob'
    );
    client.setCredentials(token);
    
    // Test the credentials by getting token info
    try {
      await client.getTokenInfo(client.credentials.access_token!);
      console.error('Credentials validated successfully.');
    } catch (err) {
      console.error('Token might be expired, attempting refresh...');
      // The library will automatically refresh the token on next API call
    }
    
    return client;
  } catch (err) {
    console.error('Error loading saved credentials:', err);
    return null;
  }
}

async function loadClientSecrets() {
  const data = await loadCredentialsFromEnvOrFile();
  if (!data) {
    throw new Error('Could not load credentials from environment or files.');
  }

  const keys = data.credentials;
  const key = keys.installed || keys.web;
  if (!key) throw new Error("Could not find client secrets in credentials.");
  
  return {
    client_id: key.client_id,
    client_secret: key.client_secret,
    redirect_uris: key.redirect_uris || ['http://localhost:3000/'],
    client_type: keys.web ? 'web' : 'installed'
  };
}

async function saveCredentials(client: OAuth2Client): Promise<void> {
  // Only save to file in local development (not in Cloud Run)
  if (process.env.GOOGLE_CREDENTIALS) {
    console.error('Running in Cloud Run mode, not saving credentials to file.');
    return;
  }

  try {
    const { client_secret, client_id } = await loadClientSecrets();
    const payload = JSON.stringify({
      type: 'authorized_user',
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: client.credentials.refresh_token,
    });
    await fs.writeFile(TOKEN_PATH, payload);
    console.error('Token stored to', TOKEN_PATH);
  } catch (err) {
    console.error('Failed to save credentials:', err);
  }
}

async function authenticate(): Promise<OAuth2Client> {
  // This should only run in local development
  if (process.env.GOOGLE_CREDENTIALS) {
    throw new Error('Cannot run interactive authentication in Cloud Run environment.');
  }

  const { client_secret, client_id, redirect_uris, client_type } = await loadClientSecrets();
  const redirectUri = client_type === 'web' ? redirect_uris[0] : 'urn:ietf:wg:oauth:2.0:oob';
  console.error(`DEBUG: Using redirect URI: ${redirectUri}`);
  console.error(`DEBUG: Client type: ${client_type}`);
  const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirectUri);

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  const authorizeUrl = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES.join(' '),
  });

  console.error('DEBUG: Generated auth URL:', authorizeUrl);
  console.error('Authorize this app by visiting this url:', authorizeUrl);
  const code = await rl.question('Enter the code from that page here: ');
  rl.close();

  try {
    const { tokens } = await oAuth2Client.getToken(code);
    oAuth2Client.setCredentials(tokens);
    if (tokens.refresh_token) {
      await saveCredentials(oAuth2Client);
    } else {
      console.error("Did not receive refresh token. Token might expire.");
    }
    console.error('Authentication successful!');
    return oAuth2Client;
  } catch (err) {
    console.error('Error retrieving access token', err);
    throw new Error('Authentication failed');
  }
}

export async function authorize(): Promise<OAuth2Client> {
  // Check if running in Cloud Run
  const isCloudRun = !!process.env.GOOGLE_CREDENTIALS;
  console.error(`Running in ${isCloudRun ? 'Cloud Run' : 'local'} mode.`);

  let client = await loadSavedCredentialsIfExist();
  if (client) {
    console.error('Using saved credentials.');
    return client;
  }

  if (isCloudRun) {
    throw new Error('No valid credentials found in Cloud Run environment. Please check Secret Manager configuration.');
  }

  console.error('Starting authentication flow...');
  client = await authenticate();
  return client;
}

