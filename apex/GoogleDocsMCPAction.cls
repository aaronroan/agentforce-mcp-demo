/**
 * Google Docs MCP Action - Universal Invocable Apex
 * Single class for Agentforce to call any MCP tool
 * 
 * MCP Server: https://google-docs-mcp-rest-403993907509.us-central1.run.app/
 */
public class GoogleDocsMCPAction {
    
    // MCP Server endpoint
    private static final String MCP_ENDPOINT = 'https://google-docs-mcp-rest-403993907509.us-central1.run.app';
    
    /**
     * Call any MCP tool from Agentforce
     * 
     * Usage in Agentforce:
     * - Tool Name: readGoogleDoc, createDocument, appendToGoogleDoc, etc.
     * - Arguments: JSON string with tool-specific parameters
     * 
     * Example:
     * toolName = 'readGoogleDoc'
     * arguments = '{"documentId":"1abc123xyz","format":"text"}'
     */
    @InvocableMethod(
        label='Call Google Docs MCP'
        description='Calls any Google Docs MCP tool with specified arguments'
        category='Google Docs'
    )
    public static List<Response> callMCPTool(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Validate inputs
                if (String.isBlank(req.toolName)) {
                    res.success = false;
                    res.error = 'Tool name is required';
                    responses.add(res);
                    continue;
                }
                
                // Parse arguments JSON
                Map<String, Object> argsMap = new Map<String, Object>();
                if (String.isNotBlank(req.arguments)) {
                    argsMap = (Map<String, Object>) JSON.deserializeUntyped(req.arguments);
                }
                
                // Make HTTP callout to MCP server
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(MCP_ENDPOINT + '/mcp/tools/call');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setTimeout(30000); // 30 seconds
                
                // Build request body
                Map<String, Object> requestBody = new Map<String, Object>{
                    'toolName' => req.toolName,
                    'arguments' => argsMap
                };
                httpReq.setBody(JSON.serialize(requestBody));
                
                // Send request
                Http http = new Http();
                HttpResponse httpRes = http.send(httpReq);
                
                // Process response
                if (httpRes.getStatusCode() == 200) {
                    Map<String, Object> mcpResponse = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    
                    res.success = true;
                    res.rawResponse = httpRes.getBody();
                    
                    // Extract text content if available
                    if (mcpResponse.containsKey('content')) {
                        List<Object> contentList = (List<Object>) mcpResponse.get('content');
                        if (!contentList.isEmpty()) {
                            Map<String, Object> firstContent = (Map<String, Object>) contentList[0];
                            if (firstContent.containsKey('text')) {
                                res.content = (String) firstContent.get('text');
                            }
                        }
                    }
                    
                    // Check for errors
                    if (mcpResponse.containsKey('isError') && Boolean.valueOf(mcpResponse.get('isError'))) {
                        res.success = false;
                        res.error = res.content != null ? res.content : 'MCP tool returned an error';
                    }
                    
                } else {
                    res.success = false;
                    res.error = 'HTTP ' + httpRes.getStatusCode() + ': ' + httpRes.getStatus();
                    res.rawResponse = httpRes.getBody();
                }
                
            } catch (Exception e) {
                res.success = false;
                res.error = e.getTypeName() + ': ' + e.getMessage();
                System.debug('Error calling MCP tool: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
            
            responses.add(res);
        }
        
        return responses;
    }
    
    /**
     * Input parameters for Agentforce
     */
    public class Request {
        @InvocableVariable(
            label='Tool Name' 
            description='MCP tool to call (e.g., readGoogleDoc, createDocument, appendToGoogleDoc)' 
            required=true
        )
        public String toolName;
        
        @InvocableVariable(
            label='Arguments' 
            description='JSON string with tool arguments (e.g., {"documentId":"1abc","text":"Hello"})' 
            required=false
        )
        public String arguments;
    }
    
    /**
     * Output for Agentforce
     */
    public class Response {
        @InvocableVariable(
            label='Success' 
            description='True if the operation succeeded'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='Content' 
            description='Extracted text content from the response'
        )
        public String content;
        
        @InvocableVariable(
            label='Raw Response' 
            description='Full JSON response from MCP server'
        )
        public String rawResponse;
        
        @InvocableVariable(
            label='Error' 
            description='Error message if the operation failed'
        )
        public String error;
    }
}






