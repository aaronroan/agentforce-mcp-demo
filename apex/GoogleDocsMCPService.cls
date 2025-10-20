/**
 * Google Docs MCP Service - Base HTTP Client
 * Handles HTTP communication with the Google Docs MCP server
 */
public class GoogleDocsMCPService {
    
    // MCP Server endpoint
    private static final String MCP_ENDPOINT = 'https://google-docs-mcp-403993907509.us-central1.run.app';
    
    /**
     * Call an MCP tool
     * @param toolName Name of the tool to call
     * @param toolArguments Arguments for the tool
     * @return Response from the MCP server
     */
    public static Map<String, Object> callTool(String toolName, Map<String, Object> toolArguments) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(MCP_ENDPOINT + '/mcp/tools/call');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000); // 30 second timeout
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'toolName' => toolName,
            'arguments' => toolArguments
        };
        req.setBody(JSON.serialize(requestBody));
        
        // Make the callout
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Parse response
        if (res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new CalloutException('MCP Server Error: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }
    
    /**
     * Extract text content from MCP response
     */
    public static String extractTextContent(Map<String, Object> response) {
        if (response.containsKey('content')) {
            List<Object> contentList = (List<Object>) response.get('content');
            if (!contentList.isEmpty()) {
                Map<String, Object> firstContent = (Map<String, Object>) contentList[0];
                return (String) firstContent.get('text');
            }
        }
        return null;
    }
    
    /**
     * Check if response is an error
     */
    public static Boolean isError(Map<String, Object> response) {
        return response.containsKey('isError') && 
               Boolean.valueOf(response.get('isError'));
    }
}


