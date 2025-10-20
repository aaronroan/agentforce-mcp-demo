public class GoogleDocsMCPHandler {
    
    public static final String MCP_ENDPOINT = 'https://google-docs-mcp-rest-403993907509.us-central1.run.app';
    public static final String PROJECT_ID = 'ehc-aroan-17eb34';
    
    /**
     * Calls a Google Docs MCP tool and returns the response WITH AUTHENTICATION.
     * @param toolName The name of the MCP tool to call (e.g., 'readGoogleDoc', 'createDocument')
     * @param arguments JSON string with tool arguments (e.g., '{"documentId":"1abc","title":"My Doc"}')
     * @return The response text from the MCP server, or an error message.
     */
    public static String callMCPTool(String toolName, String arguments) {
        String responseStr = 'Error calling MCP tool. Please try again.';
        
        try {
            // Get access token for authentication
            String accessToken = getAccessToken();
            if (String.isBlank(accessToken)) {
                return 'Failed to get access token. Check GoogleJSON static resource.';
            }
            System.debug('Got access token: ' + accessToken.substring(0, 20) + '...');
            
            // Parse arguments JSON
            Map<String, Object> argsMap = new Map<String, Object>();
            if (String.isNotBlank(arguments)) {
                argsMap = (Map<String, Object>) JSON.deserializeUntyped(arguments);
            }
            
            // Build HTTP request
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(MCP_ENDPOINT + '/api/mcp/call');
            req.setMethod('POST');
            req.setTimeout(30000);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('X-Goog-User-Project', PROJECT_ID);
            
            // Build request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('toolName', toolName);
            requestBody.put('arguments', argsMap);
            req.setBody(JSON.serialize(requestBody));
            
            // Send request
            HttpResponse res = http.send(req);
            System.debug('MCP Response Status: ' + res.getStatusCode());
            System.debug('MCP Response Body: ' + res.getBody());
            
            // Parse response - format is { success: true, data: "result" }
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Check for success
                if (responseMap.containsKey('success') && Boolean.valueOf(responseMap.get('success'))) {
                    if (responseMap.containsKey('data')) {
                        responseStr = String.valueOf(responseMap.get('data'));
                    } else {
                        responseStr = 'Success but no data returned';
                    }
                } else {
                    // Error response format: { success: false, error: "message" }
                    if (responseMap.containsKey('error')) {
                        responseStr = 'MCP Error: ' + responseMap.get('error');
                    } else {
                        responseStr = 'Unknown error from MCP server';
                    }
                }
            } else {
                // For errors, try to parse the error details from response body
                try {
                    Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (errorMap.containsKey('error')) {
                        responseStr = 'HTTP ' + res.getStatusCode() + ': ' + errorMap.get('error');
                    } else {
                        responseStr = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
                    }
                } catch (Exception parseError) {
                    responseStr = 'HTTP Error ' + res.getStatusCode() + ': ' + res.getStatus() + ' - ' + res.getBody();
                }
                System.debug('Error response: ' + res.getBody());
            }
            
        } catch (Exception e) {
            responseStr = 'Exception: ' + e.getMessage();
            System.debug('Exception calling MCP tool: ' + e.getMessage());
        }
        
        return responseStr;
    }
    
    /**
     * Convenience method to read a Google Doc
     */
    public static String readGoogleDoc(String documentId, String format) {
        String args = '{"documentId":"' + documentId + '"';
        if (String.isNotBlank(format)) {
            args += ',"format":"' + format + '"';
        }
        args += '}';
        return callMCPTool('readGoogleDoc', args);
    }
    
    /**
     * Convenience method to create a Google Doc
     */
    public static String createGoogleDoc(String title) {
        String args = '{"title":"' + title + '"}';
        return callMCPTool('createDocument', args);
    }
    
    /**
     * Convenience method to append text to a Google Doc
     */
    public static String appendToGoogleDoc(String documentId, String text) {
        String args = '{"documentId":"' + documentId + '","text":"' + text.replace('"', '\\"') + '"}';
        return callMCPTool('appendToGoogleDoc', args);
    }
    
    /**
     * Convenience method to search Google Docs
     */
    public static String searchGoogleDocs(String query) {
        String args = '{"query":"' + query.replace('"', '\\"') + '"}';
        return callMCPTool('searchGoogleDocs', args);
    }
    
    /**
     * Retrieves an ID token for Cloud Run IAM authentication.
     * Uses the same GoogleJSON static resource as Vertex Agent.
     */
    public static String getAccessToken() {
        try {
            StaticResource objSR = [SELECT Body FROM StaticResource WHERE Name = 'GoogleJSON' LIMIT 1];
            String serviceAccountJson = objSR.Body.toString();
            
            Map<String, Object> serviceAccount = (Map<String, Object>) JSON.deserializeUntyped(serviceAccountJson);
            String clientEmail = (String) serviceAccount.get('client_email');
            String privateKey = (String) serviceAccount.get('private_key');
            
            // For Cloud Run IAM, generate JWT with target_audience
            String jwt = generateIdTokenJwt(clientEmail, privateKey, MCP_ENDPOINT);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://oauth2.googleapis.com/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + EncodingUtil.urlEncode(jwt, 'UTF-8'));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) responseMap.get('id_token');
            } else {
                System.debug('Error getting ID token: ' + res.getStatusCode() + ' ' + res.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('Exception in getAccessToken: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Generates a JWT for ID token request (Cloud Run IAM).
     */
    private static String generateIdTokenJwt(String clientEmail, String privateKey, String targetAudience) {
        try {
            Long now = System.now().getTime() / 1000;
            Map<String, Object> payload = new Map<String, Object>{
                'iss' => clientEmail,
                'sub' => clientEmail,
                'aud' => 'https://oauth2.googleapis.com/token',
                'target_audience' => targetAudience,
                'exp' => now + 3600,
                'iat' => now
            };
            
            String header = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(new Map<String, String>{'alg' => 'RS256', 'typ' => 'JWT'})));
            String encodedPayload = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(payload)));
            String unsignedToken = header + '.' + encodedPayload;
            
            Blob keyBlob = EncodingUtil.base64Decode(
                privateKey.replaceAll('-----BEGIN PRIVATE KEY-----', '')
                          .replaceAll('-----END PRIVATE KEY-----', '')
                          .replaceAll('\n', '')
            );
            Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(unsignedToken), keyBlob);
            String encodedSignature = EncodingUtil.base64Encode(signature);
            
            return unsignedToken + '.' + encodedSignature;
        } catch (Exception e) {
            System.debug('Exception in generateIdTokenJwt: ' + e.getMessage());
            return null;
        }
    }
}

