/**
 * Agentforce Action: Create Google Doc
 * Invocable Apex class that creates a new Google Document
 */
public class CreateGoogleDocAction {
    
    @InvocableMethod(
        label='Create Google Doc'
        description='Creates a new Google Document'
        category='Google Docs MCP'
    )
    public static List<Response> createDocument(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Build arguments for MCP tool
                Map<String, Object> args = new Map<String, Object>{
                    'title' => req.title
                };
                
                // Add optional folder ID
                if (String.isNotBlank(req.folderId)) {
                    args.put('folderId', req.folderId);
                }
                
                // Call MCP server
                Map<String, Object> mcpResponse = GoogleDocsMCPService.callTool('createDocument', args);
                
                // Check for errors
                if (GoogleDocsMCPService.isError(mcpResponse)) {
                    res.isSuccess = false;
                    res.errorMessage = 'Failed to create document';
                } else {
                    res.isSuccess = true;
                    String responseText = GoogleDocsMCPService.extractTextContent(mcpResponse);
                    
                    // Parse document ID from response
                    // Response format: "Created document with ID: 1abc123xyz"
                    if (responseText != null && responseText.contains('ID:')) {
                        res.documentId = responseText.substringAfter('ID:').trim();
                    }
                    res.message = responseText;
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug('Error creating Google Doc: ' + e.getMessage());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    // Input wrapper
    public class Request {
        @InvocableVariable(label='Title' description='Title for the new document' required=true)
        public String title;
        
        @InvocableVariable(label='Folder ID' description='Parent folder ID (optional)')
        public String folderId;
    }
    
    // Output wrapper
    public class Response {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Document ID' description='The created document ID')
        public String documentId;
        
        @InvocableVariable(label='Message' description='Response message')
        public String message;
        
        @InvocableVariable(label='Error Message' description='Error message if failed')
        public String errorMessage;
    }
}






