# === BUILDER STAGE ===
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Define Build Arguments for Next.js build process
ARG OPENAI_API_KEY
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_AUTH_GITHUB

# 2. Set environment variables from ARGs for the build (Next.js requires NEXT_PUBLIC_ vars for client-side)
ENV OPENAI_API_KEY=$OPENAI_API_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_AUTH_GITHUB=$NEXT_PUBLIC_AUTH_GITHUB

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source code and run the build (Requires output: "standalone" in next.config.js)
COPY . .
RUN npm run build

# === RUNNER STAGE ===
FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Consolidate user/group creation
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
