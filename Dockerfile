FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force
RUN npm install -D typescript

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build:rest

# Clean up
RUN npm prune --production && \
    rm -rf src/ tsconfig.json

# Create non-root user
RUN useradd -m -u 1001 mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the REST API server
CMD ["node", "dist/rest-api-wrapper.js"]
