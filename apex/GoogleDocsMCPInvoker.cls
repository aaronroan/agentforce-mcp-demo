public class GoogleDocsMCPInvoker {
    
    // Request wrapper to pass in parameters from the Flow/Agentforce
    public class Request {
        @InvocableVariable(label='Tool Name' description='MCP tool to call (e.g., readGoogleDoc, createDocument)')
        public String toolName;
        
        @InvocableVariable(label='Arguments' description='JSON string with tool arguments (e.g., {"documentId":"1abc","title":"My Doc"})')
        public String arguments;
    }
    
    // Response wrapper to hold the returned response
    public class Response {
        @InvocableVariable(label='Response Message' description='Response received from Google Docs MCP')
        public String responseMessage;
    }
    
    /**
     * Invocable method to call Google Docs MCP tools.
     * @param requests List of MCP tool calls to make.
     * @return List of responses received from the MCP server.
     */
    @InvocableMethod(label='Call Google Docs MCP' description='Call a Google Docs MCP tool and receive the response')
    public static List<Response> callMCPTool(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            res.responseMessage = GoogleDocsMCPHandler.callMCPTool(req.toolName, req.arguments);
            responses.add(res);
        }
        return responses;
    }
}






