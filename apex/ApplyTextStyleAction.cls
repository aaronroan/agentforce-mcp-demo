/**
 * Agentforce Action: Apply Text Style
 * Invocable Apex class that applies formatting to text in a Google Document
 */
public class ApplyTextStyleAction {
    
    @InvocableMethod(
        label='Apply Text Style'
        description='Applies formatting (bold, italic, color) to text in a Google Document'
        category='Google Docs MCP'
    )
    public static List<Response> applyStyle(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Build arguments for MCP tool
                Map<String, Object> args = new Map<String, Object>{
                    'documentId' => req.documentId,
                    'startIndex' => req.startIndex,
                    'endIndex' => req.endIndex
                };
                
                // Add optional styling parameters
                if (req.bold != null) {
                    args.put('bold', req.bold);
                }
                if (req.italic != null) {
                    args.put('italic', req.italic);
                }
                if (req.underline != null) {
                    args.put('underline', req.underline);
                }
                if (String.isNotBlank(req.foregroundColor)) {
                    args.put('foregroundColor', req.foregroundColor);
                }
                if (req.fontSize != null && req.fontSize > 0) {
                    args.put('fontSize', req.fontSize);
                }
                
                // Call MCP server
                Map<String, Object> mcpResponse = GoogleDocsMCPService.callTool('applyTextStyle', args);
                
                // Check for errors
                if (GoogleDocsMCPService.isError(mcpResponse)) {
                    res.isSuccess = false;
                    res.errorMessage = 'Failed to apply text style';
                } else {
                    res.isSuccess = true;
                    res.message = GoogleDocsMCPService.extractTextContent(mcpResponse);
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug('Error applying text style: ' + e.getMessage());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    // Input wrapper
    public class Request {
        @InvocableVariable(label='Document ID' description='The Google Document ID' required=true)
        public String documentId;
        
        @InvocableVariable(label='Start Index' description='Start position of text' required=true)
        public Integer startIndex;
        
        @InvocableVariable(label='End Index' description='End position of text' required=true)
        public Integer endIndex;
        
        @InvocableVariable(label='Bold' description='Make text bold')
        public Boolean bold;
        
        @InvocableVariable(label='Italic' description='Make text italic')
        public Boolean italic;
        
        @InvocableVariable(label='Underline' description='Underline text')
        public Boolean underline;
        
        @InvocableVariable(label='Color' description='Text color (hex code like #FF0000)')
        public String foregroundColor;
        
        @InvocableVariable(label='Font Size' description='Font size in points')
        public Integer fontSize;
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






