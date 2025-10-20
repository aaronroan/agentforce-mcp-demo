/**
 * Agentforce Action: Search Google Docs
 * Invocable Apex class that searches for Google Documents
 */
public class SearchGoogleDocsAction {
    
    @InvocableMethod(
        label='Search Google Docs'
        description='Searches for Google Documents by query'
        category='Google Docs MCP'
    )
    public static List<Response> searchDocuments(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Build arguments for MCP tool
                Map<String, Object> args = new Map<String, Object>{
                    'query' => req.query
                };
                
                // Add optional maxResults
                if (req.maxResults != null && req.maxResults > 0) {
                    args.put('maxResults', req.maxResults);
                }
                
                // Call MCP server
                Map<String, Object> mcpResponse = GoogleDocsMCPService.callTool('searchGoogleDocs', args);
                
                // Check for errors
                if (GoogleDocsMCPService.isError(mcpResponse)) {
                    res.isSuccess = false;
                    res.errorMessage = 'Failed to search documents';
                } else {
                    res.isSuccess = true;
                    res.results = GoogleDocsMCPService.extractTextContent(mcpResponse);
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug('Error searching Google Docs: ' + e.getMessage());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    // Input wrapper
    public class Request {
        @InvocableVariable(label='Search Query' description='Search query string' required=true)
        public String query;
        
        @InvocableVariable(label='Max Results' description='Maximum number of results to return')
        public Integer maxResults;
    }
    
    // Output wrapper
    public class Response {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Results' description='Search results')
        public String results;
        
        @InvocableVariable(label='Error Message' description='Error message if failed')
        public String errorMessage;
    }
}






