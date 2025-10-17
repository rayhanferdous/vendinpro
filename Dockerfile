# Dockerfile
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat curl  # Use curl instead of wget
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build both client and server
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copy built applications
COPY --from=builder /app/dist ./dist                    # React client
COPY --from=builder /app/server/dist ./server/dist      # Express server
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/shared ./shared                # Schema files

USER nextjs

EXPOSE 3000 5000

# Health check for Express server
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# Start Express server (which will serve React in production)
CMD ["node", "server/dist/index.js"]