# Agentforce Quick Start - Invocable Apex

## 🎯 What You Need

Since **Agentforce requires Invocable Apex classes** to call external services, I've created a complete set of ready-to-deploy Apex classes.

**Your MCP Server**: `https://google-docs-mcp-403993907509.us-central1.run.app`

---

## 🚀 5-Minute Setup

### Step 1: Enable Remote Site Settings (1 min)

1. Go to **Setup** → Search for "Remote Site Settings"
2. Click **New Remote Site**
3. Enter:
   - **Name**: `GoogleDocsMCP`
   - **URL**: `https://google-docs-mcp-403993907509.us-central1.run.app`
   - **Active**: ✅ Checked
4. Click **Save**

### Step 2: Deploy Apex Classes (2 min)

**Option A: Using Salesforce CLI (Recommended)**

```bash
cd /Users/kathy.lau/Downloads/Github/agentforce-mcp-demo
sfdx force:source:deploy -p apex/ -u YOUR_ORG_ALIAS
```

**Option B: Using VS Code**
1. Open VS Code with Salesforce Extensions
2. Right-click on `apex/` folder
3. Select "Deploy Source to Org"

**Option C: Manual (Developer Console)**
1. Open Developer Console
2. Create each class manually from the `apex/` folder files

### Step 3: Verify Deployment (30 sec)

In Developer Console, run:

```apex
// Test the base service
ReadGoogleDocAction.Request req = new ReadGoogleDocAction.Request();
req.documentId = 'YOUR_TEST_DOC_ID';
req.format = 'text';

List<ReadGoogleDocAction.Request> requests = new List<ReadGoogleDocAction.Request>{req};
List<ReadGoogleDocAction.Response> responses = ReadGoogleDocAction.readDocument(requests);

System.debug('Success: ' + responses[0].isSuccess);
```

### Step 4: Configure in Agentforce (2 min)

1. Go to **Setup** → **Agentforce** → **Actions**
2. Click **New Action**
3. Select **Apex Action**
4. Choose from these Invocable methods:
   - ✅ **Read Google Doc**
   - ✅ **Create Google Doc**
   - ✅ **Append to Google Doc**
   - ✅ **Search Google Docs**
   - ✅ **Apply Text Style**
5. Save and add to your agent

### Step 5: Test It! (30 sec)

In Agentforce, try:
```
"Create a new document called 'Test Document'"
```

Expected: Agent calls `CreateGoogleDocAction` and creates the document ✅

---

## 📦 What's Included

### 6 Apex Classes:

| File | Purpose |
|------|---------|
| `GoogleDocsMCPService.cls` | Base HTTP client for MCP communication |
| `ReadGoogleDocAction.cls` | Read document content |
| `CreateGoogleDocAction.cls` | Create new documents |
| `AppendToGoogleDocAction.cls` | Add text to documents |
| `SearchGoogleDocsAction.cls` | Search for documents |
| `ApplyTextStyleAction.cls` | Format text (bold, italic, colors) |

All classes are fully documented and ready to use!

---

## 🎯 Available Actions

### 1. **Read Google Doc**
```
Input: documentId, format (text/json/markdown)
Output: content, isSuccess, errorMessage
```

**Example Agentforce prompt:**
```
"Read the document with ID 1abc123xyz"
```

### 2. **Create Google Doc**
```
Input: title, folderId (optional)
Output: documentId, isSuccess, message, errorMessage
```

**Example Agentforce prompt:**
```
"Create a new document called 'Meeting Notes'"
```

### 3. **Append to Google Doc**
```
Input: documentId, text
Output: isSuccess, message, errorMessage
```

**Example Agentforce prompt:**
```
"Add 'Action items: 1. Review budget' to document 1abc123xyz"
```

### 4. **Search Google Docs**
```
Input: query, maxResults (optional)
Output: results, isSuccess, errorMessage
```

**Example Agentforce prompt:**
```
"Find all documents about Q4 planning"
```

### 5. **Apply Text Style**
```
Input: documentId, startIndex, endIndex, bold, italic, underline, foregroundColor, fontSize
Output: isSuccess, message, errorMessage
```

**Example Agentforce prompt:**
```
"Make the title in document 1abc123xyz bold"
```

---

## 🧪 Testing Commands

### Test in Developer Console:

```apex
// Test Create Document
CreateGoogleDocAction.Request req = new CreateGoogleDocAction.Request();
req.title = 'Test Document';
List<CreateGoogleDocAction.Request> requests = new List<CreateGoogleDocAction.Request>{req};
List<CreateGoogleDocAction.Response> responses = CreateGoogleDocAction.createDocument(requests);
System.debug('Document ID: ' + responses[0].documentId);

// Test Search
SearchGoogleDocsAction.Request searchReq = new SearchGoogleDocsAction.Request();
searchReq.query = 'meeting notes';
searchReq.maxResults = 5;
List<SearchGoogleDocsAction.Request> searchRequests = new List<SearchGoogleDocsAction.Request>{searchReq};
List<SearchGoogleDocsAction.Response> searchResponses = SearchGoogleDocsAction.searchDocuments(searchRequests);
System.debug('Results: ' + searchResponses[0].results);
```

---

## 🔧 Quick Troubleshooting

### ❌ "Unauthorized endpoint"
**Fix**: Check Remote Site Settings → Make sure URL is exact match

### ❌ "Method does not exist"
**Fix**: Refresh org → Verify classes deployed successfully

### ❌ "Callout failed"
**Fix**: Test MCP server is running:
```bash
curl https://google-docs-mcp-403993907509.us-central1.run.app/health
```

### ❌ "Action doesn't appear in Agentforce"
**Fix**: 
1. Verify `@InvocableMethod` annotation exists
2. Check class status is Active
3. Refresh Agentforce UI

---

## 📚 Documentation

For complete setup guide, see:
- **[AGENTFORCE_APEX_SETUP.md](AGENTFORCE_APEX_SETUP.md)** - Complete deployment guide
- **[README.md](README.md)** - MCP server documentation
- **[SAMPLE_TASKS.md](SAMPLE_TASKS.md)** - 15 example use cases

---

## 🎓 Example Workflows

### Workflow 1: Create & Write
```
User: "Create a meeting notes document and add today's agenda"

Agentforce Actions:
1. CreateGoogleDocAction → Get document ID
2. AppendToGoogleDocAction → Add agenda content
```

### Workflow 2: Search & Summarize
```
User: "Find Q4 planning docs and create a summary"

Agentforce Actions:
1. SearchGoogleDocsAction → Find documents
2. ReadGoogleDocAction → Read each document
3. CreateGoogleDocAction → Create summary doc
4. AppendToGoogleDocAction → Add summary content
```

### Workflow 3: Format Document
```
User: "Make all headings in my document bold and blue"

Agentforce Actions:
1. ReadGoogleDocAction → Analyze structure
2. ApplyTextStyleAction → Format each heading
```

---

## ⚡ Deployment Checklist

- [ ] Remote Site Settings enabled
- [ ] All 6 Apex classes deployed
- [ ] Classes tested in Developer Console
- [ ] Actions configured in Agentforce
- [ ] Actions added to your agent
- [ ] End-to-end test completed

---

## 🚀 Ready to Go!

1. ✅ Enable Remote Site Settings
2. ✅ Deploy Apex classes
3. ✅ Configure Agentforce actions
4. ✅ Test with your agent

**Total time: ~5-10 minutes**

---

**Need help?** See [AGENTFORCE_APEX_SETUP.md](AGENTFORCE_APEX_SETUP.md) for detailed instructions!






