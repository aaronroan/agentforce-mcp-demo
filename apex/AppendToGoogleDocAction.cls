/**
 * Agentforce Action: Append to Google Doc
 * Invocable Apex class that adds text to a Google Document
 */
public class AppendToGoogleDocAction {
    
    @InvocableMethod(
        label='Append to Google Doc'
        description='Adds text to the end of a Google Document'
        category='Google Docs MCP'
    )
    public static List<Response> appendToDocument(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Build arguments for MCP tool
                Map<String, Object> args = new Map<String, Object>{
                    'documentId' => req.documentId,
                    'text' => req.text
                };
                
                // Call MCP server
                Map<String, Object> mcpResponse = GoogleDocsMCPService.callTool('appendToGoogleDoc', args);
                
                // Check for errors
                if (GoogleDocsMCPService.isError(mcpResponse)) {
                    res.isSuccess = false;
                    res.errorMessage = 'Failed to append to document';
                } else {
                    res.isSuccess = true;
                    res.message = GoogleDocsMCPService.extractTextContent(mcpResponse);
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug('Error appending to Google Doc: ' + e.getMessage());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    // Input wrapper
    public class Request {
        @InvocableVariable(label='Document ID' description='The Google Document ID' required=true)
        public String documentId;
        
        @InvocableVariable(label='Text' description='Text to append to the document' required=true)
        public String text;
    }
    
    // Output wrapper
    public class Response {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Response message')
        public String message;
        
        @InvocableVariable(label='Error Message' description='Error message if failed')
        public String errorMessage;
    }
}






