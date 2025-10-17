# Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /

# Copy package files
COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /
COPY --from=deps /node_modules ./node_modules
COPY . .

# Build client and server together (based on your package.json scripts)
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copy built applications - adjust paths based on your actual build output
COPY --from=builder /dist ./dist
COPY --from=builder /server/dist ./server/dist

# Copy package.json and node_modules
COPY --from=builder /package.json ./
COPY --from=builder /node_modules ./node_modules

# Copy shared schema and other necessary files
COPY --from=builder /shared ./shared
COPY --from=builder /tailwind.config.ts ./
COPY --from=builder /tsconfig.json ./
COPY --from=builder /vite.config.ts ./

# Create non-root user and set permissions
RUN chown -R nextjs:nodejs /

USER nextjs

EXPOSE 3000 5000

CMD ["node", "server/dist/index.js"]