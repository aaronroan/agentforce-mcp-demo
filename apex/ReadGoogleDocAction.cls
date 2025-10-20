/**
 * Agentforce Action: Read Google Doc
 * Invocable Apex class that reads content from a Google Document
 */
public class ReadGoogleDocAction {
    
    @InvocableMethod(
        label='Read Google Doc'
        description='Reads content from a Google Document'
        category='Google Docs MCP'
    )
    public static List<Response> readDocument(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Build arguments for MCP tool
                Map<String, Object> args = new Map<String, Object>{
                    'documentId' => req.documentId
                };
                
                // Add optional format parameter
                if (String.isNotBlank(req.format)) {
                    args.put('format', req.format);
                }
                
                // Call MCP server
                Map<String, Object> mcpResponse = GoogleDocsMCPService.callTool('readGoogleDoc', args);
                
                // Check for errors
                if (GoogleDocsMCPService.isError(mcpResponse)) {
                    res.isSuccess = false;
                    res.errorMessage = 'Failed to read document';
                } else {
                    res.isSuccess = true;
                    res.content = GoogleDocsMCPService.extractTextContent(mcpResponse);
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug('Error reading Google Doc: ' + e.getMessage());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    // Input wrapper
    public class Request {
        @InvocableVariable(label='Document ID' description='The Google Document ID' required=true)
        public String documentId;
        
        @InvocableVariable(label='Format' description='Output format: text, json, or markdown')
        public String format;
    }
    
    // Output wrapper
    public class Response {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Content' description='The document content')
        public String content;
        
        @InvocableVariable(label='Error Message' description='Error message if failed')
        public String errorMessage;
    }
}


