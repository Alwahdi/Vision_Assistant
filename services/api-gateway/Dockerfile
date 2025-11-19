# Vision Assistant - API Gateway
FROM node:18-alpine AS base

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Install dependencies first (for better caching)
FROM base AS dependencies

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev --no-fund --no-audit && npm cache clean --force

# Development stage
FROM dependencies AS development

# Install dev dependencies for development
RUN npm install --no-fund --no-audit && npm cache clean --force

# Copy source code
COPY src/ ./src/

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Start application in development mode
CMD ["dumb-init", "npm", "run", "dev"]

# Production stage
FROM base AS production

# Copy dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copy source code
COPY src/ ./src/
COPY package*.json ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["dumb-init", "npm", "start"]